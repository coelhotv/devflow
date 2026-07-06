#!/usr/bin/env bash
# ai-review.sh — DEVFLOW RC6 Independent AI Review
# -----------------------------------------------------------------------------
# Independent, fresh-context AI gate on a PR diff. Restores the "independent
# second opinion" property lost when the Gemini GitHub reviewer retires.
#
# Source of truth for the METHOD is SKILL.md §1533 "RC6 — Independent AI Review".
# The reviewer prompt below MIRRORS that section (CRITICAL checklist + RC6
# Extensions #6/#7/#8 + causation discipline + JSON schema). Keep them in sync.
#
# Independence by construction: this runs in a fresh process with NO access to
# the coding agent's chat/reasoning — only the diff + full files + rule catalogs.
#
# Engines (OAuth quota, $0 marginal): agy (Gemini 3.1) generalist; claude -p
# (Opus/Sonnet) for the domain-rule pass on migration/architectural PRs.
#
# Usage:
#   ai-review.sh [<PR#>] [--dry-run|--post] [--tier1|--tier2]
#     <PR#>       PR number. If omitted, resolved from the current branch.
#     --dry-run   (DEFAULT) print merged JSON to stdout. NO PR mutation, NO
#                 state/journal writes. Safe to run repeatedly.
#     --post      the "for real" run: publish inline comments to the PR AND
#                 update state.json.session.ai_review + journal. Opt-in only.
#     --tier1/2   force pass strategy; default is auto-detected from the diff.
#
# Exit: 0 clean or issues_found (non-blocking by design — human gate R-060 is
#       final). Fail-open: if all engines are unavailable, emits a warning JSON
#       and exits 0. STOP semantics (introduced critical/high) are the operator's
#       call, surfaced in the output, not enforced by exit code.
# -----------------------------------------------------------------------------
set -euo pipefail

MAIN_BRANCH="${RC6_MAIN:-main}"
MAX_FULLFILE_LINES="${RC6_FULLFILE_LINES:-20}"
TIER2_FILE_THRESHOLD="${RC6_TIER2_FILES:-8}"
MAX_FULLFILES="${RC6_MAX_FULLFILES:-14}"      # cap full-file attachments (migration PRs match ~everything)
CTX_BUDGET="${RC6_CTX_BUDGET:-150000}"        # byte budget for FULL-FILE attachments only (base ctx ~300KB;
                                              # keep total argv well under ARG_MAX ~1MB)
CODE_GLOBS=('*.js' '*.jsx' '*.ts' '*.tsx')

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git rev-parse --show-toplevel)"
CLAUDE_MD="$REPO_ROOT/CLAUDE.md"
RULES_IDX="$REPO_ROOT/.agent/memory/RULES_INDEX.md"
AP_IDX="$REPO_ROOT/.agent/memory/ANTI_PATTERNS_INDEX.md"

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

# ---- args -------------------------------------------------------------------
POST=0; PR=""; FORCE_TIER=""
for a in "$@"; do
  case "$a" in
    --post)     POST=1 ;;
    --dry-run)  POST=0 ;;
    --tier1)    FORCE_TIER=1 ;;
    --tier2)    FORCE_TIER=2 ;;
    [0-9]*)     PR="$a" ;;
    *) echo "usage: ai-review.sh [<PR#>] [--dry-run|--post] [--tier1|--tier2]" >&2; exit 2 ;;
  esac
done

log() { printf '\033[2m[rc6]\033[0m %s\n' "$*" >&2; }

command -v git >/dev/null || { echo "git required" >&2; exit 2; }
HAVE_AGY=0;    command -v agy    >/dev/null && HAVE_AGY=1
HAVE_CLAUDE=0; command -v claude >/dev/null && HAVE_CLAUDE=1
HAVE_GH=0;     command -v gh     >/dev/null && HAVE_GH=1

# ---- resolve PR (optional; not required for --dry-run) ----------------------
if [ -z "$PR" ] && [ "$HAVE_GH" = 1 ]; then
  PR="$(gh pr view --json number -q .number 2>/dev/null || true)"
fi

# ---- compute diff -----------------------------------------------------------
BASE="$(git merge-base HEAD "$MAIN_BRANCH")"
HEAD_SHA="$(git rev-parse HEAD)"
log "base=$BASE head=$HEAD_SHA pr=${PR:-<none>} post=$POST"

git diff "$BASE"...HEAD --diff-filter=d -- "${CODE_GLOBS[@]}" > "$WORKDIR/diff.txt" || true
if [ ! -s "$WORKDIR/diff.txt" ]; then
  echo '{"summary":"No code changes (.js/.jsx/.ts/.tsx) vs base.","findings":[]}'
  exit 0
fi

CHANGED=()
while IFS= read -r _l; do [ -n "$_l" ] && CHANGED+=("$_l"); done \
  < <(git diff "$BASE"...HEAD --name-only --diff-filter=d -- "${CODE_GLOBS[@]}")
RENAMES="$(git diff --summary "$BASE"...HEAD | grep -c 'rename ' || true)"

# ---- tier detection ---------------------------------------------------------
TIER=1
if [ -n "$FORCE_TIER" ]; then
  TIER="$FORCE_TIER"
elif [ "${#CHANGED[@]}" -ge "$TIER2_FILE_THRESHOLD" ] || [ "$RENAMES" -gt 0 ]; then
  TIER=2   # large diff, or a migration/refactor (renames present)
fi
log "changed=${#CHANGED[@]} renames=$RENAMES -> tier=$TIER"

# ---- pick files that need FULL-FILE context (RC6 Extension: kill diff-only blind spot)
# A file gets its full content attached when its hunks touch control flow /
# arithmetic / date-time, or when it changed more than MAX_FULLFILE_LINES lines.
LOGIC_RE='setHours|setMinutes|getTime|parseISO|parseLocalDate|new Date|Date\(|Math\.|\bif\b|\breturn\b|=>|\.map\(|\.reduce\(|\.filter\(|\bfor\b|\bwhile\b|\?\?|&&|\|\||\btimezone\b|\btz\b'
# A dropped call argument is the highest-signal migration-regression risk
# (Extension #8) and needs FULL-file context to verify against the callee — rank
# those first, regardless of file size, then fill by smallest-first.
#
# IMPORTANT: parse the whole rename-paired diff (diff.txt), NOT a per-file
# `git diff -- <new-path>`. Scoping to only the renamed .tsx path drops the old
# .jsx from scope, so git can't pair the rename and emits the file as ADD-ONLY —
# which hides every removed line (and thus every dropped argument). The full diff
# keeps both paths in scope, so rename detection and the `-` lines survive.
TAB="$(printf '\t')"
# Parser lives in its own file — a heredoc nested inside a `while ... done < <(...)`
# process substitution is fragile in bash and leaks its body to the shell.
cat > "$WORKDIR/parse_cands.py" <<'PY'
import sys, re
# call with >=2 args on a line: foo(a, b). `.*` (not [^)]*) so nested-paren calls
# like formatLocalDate(parseISO(x), true) match. Call-specific, so it ignores JSX
# prop churn from RN renames.
DROP  = re.compile(r'[A-Za-z0-9_]+\(.*,.*\)')
LOGIC = re.compile(r'(setHours|setMinutes|getTime|parseISO|parseLocalDate|new Date|Date\(|Math\.|\bif\b|\breturn\b|=>|\.map\(|\.reduce\(|\.filter\(|\bfor\b|\bwhile\b|\?\?|&&|\|\||\btimezone\b|\btz\b)')
# NET dropped-arg signal: (removed multi-arg calls) - (added multi-arg calls).
# A pure reformat removes AND re-adds the same 2-arg call -> nets ~0 (denoises
# test-mock churn). A genuine drop foo(a, b) -> foo(a) removes a 2-arg call but
# the added line has no comma -> net > 0.
path=None; rem_ma=add_ma=changed=logic=0
def flush():
    if path:
        drops=max(0, rem_ma-add_ma)
        sys.stdout.write("%d\t%d\t%d\t%s\n" % (drops, changed, logic, path))
for line in open(sys.argv[1], errors='replace'):
    if line.startswith('diff --git'):
        flush(); path=None; rem_ma=add_ma=changed=logic=0
    elif line.startswith('+++ b/'):
        path=line[6:].rstrip('\n')
    elif line.startswith('+') and not line.startswith('+++'):
        changed+=1
        if LOGIC.search(line): logic=1
        if DROP.search(line): add_ma+=1
    elif line.startswith('-') and not line.startswith('---'):
        changed+=1
        if LOGIC.search(line): logic=1
        if DROP.search(line): rem_ma+=1
flush()
PY
CANDS=()   # "priority<TAB>size<TAB>path"
while IFS="$TAB" read -r drops changed logic path; do
  [ -n "$path" ] || continue
  [ -f "$REPO_ROOT/$path" ] || continue
  if [ "$logic" = 1 ] || [ "$changed" -gt "$MAX_FULLFILE_LINES" ] || [ "$drops" -gt 0 ]; then
    sz="$(wc -c < "$REPO_ROOT/$path" | tr -d ' ')"
    CANDS+=("${drops}${TAB}${sz}${TAB}${path}")
  fi
done < <(python3 "$WORKDIR/parse_cands.py" "$WORKDIR/diff.txt")
# priority (dropped args/props) desc, then smallest-first; capped by count + budget
# (a 137-rename migration must not attach every file — blows ARG_MAX, drowns signal).
FULLFILES=(); acc=0
while IFS="$TAB" read -r prio sz f; do
  [ -n "$f" ] || continue
  [ "${#FULLFILES[@]}" -ge "$MAX_FULLFILES" ] && break
  acc=$((acc + sz)); [ "$acc" -gt "$CTX_BUDGET" ] && break
  FULLFILES+=("$f")
done < <(printf '%s\n' "${CANDS[@]:-}" | sort -t"$TAB" -k1,1nr -k2,2n)
log "full-file attach: ${#FULLFILES[@]}/${#CANDS[@]} candidate(s), ~${acc}B (drops-first)"
log "  files: ${FULLFILES[*]:-<none>}"

# ---- best-effort: load R-NNN/AP-NNN detail files whose ids appear in the diff
DETAIL_FILES=()
if [ -d "$REPO_ROOT/.agent/memory" ]; then
  IDS=()
  while IFS= read -r _l; do [ -n "$_l" ] && IDS+=("$_l"); done \
    < <(grep -Eoh 'A?P?R?-[0-9]{3}' "$WORKDIR/diff.txt" 2>/dev/null | sort -u || true)
  while IFS= read -r df; do DETAIL_FILES+=("$df"); done < <(
    for id in "${IDS[@]:-}"; do
      [ -n "$id" ] && find "$REPO_ROOT/.agent/memory" -name "${id}.md" 2>/dev/null
    done | sort -u)
fi

# ---- assemble shared context -----------------------------------------------
CTX="$WORKDIR/context.txt"
{
  echo "===== PROJECT CRITICAL RULES (CLAUDE.md — Regras Críticas hoisted; read FIRST) ====="
  if [ -f "$CLAUDE_MD" ]; then
    # hoist the "Regras Críticas" section to the top, then the rest of the file
    awk '/^## Regras Críticas/{f=1} f{print}' "$CLAUDE_MD"
    echo; echo "----- (rest of CLAUDE.md) -----"
    cat "$CLAUDE_MD"
  fi
  echo; echo "===== RULES_INDEX ====="; [ -f "$RULES_IDX" ] && cat "$RULES_IDX"
  echo; echo "===== ANTI_PATTERNS_INDEX ====="; [ -f "$AP_IDX" ] && cat "$AP_IDX"
  for df in "${DETAIL_FILES[@]:-}"; do
    [ -n "${df:-}" ] && [ -f "$df" ] && { echo; echo "===== DETAIL $(basename "$df") ====="; cat "$df"; }
  done
  echo; echo "===== FULL FILES (post-change content — audit unchanged lines too) ====="
  for f in "${FULLFILES[@]:-}"; do
    [ -n "${f:-}" ] && [ -f "$REPO_ROOT/$f" ] && { echo; echo "----- FILE $f -----"; cat "$REPO_ROOT/$f"; }
  done
  echo; echo "===== DIFF (code files vs $MAIN_BRANCH) ====="; cat "$WORKDIR/diff.txt"
} > "$CTX"
log "context bytes: $(wc -c < "$CTX")"

# ---- reviewer instruction (mirrors SKILL.md §1533) --------------------------
read -r -d '' RC6_INSTRUCTION <<'PROMPT' || true
You are an INDEPENDENT code auditor. You did NOT write this code and have NO
context beyond the diff + full files + rule catalogs provided. Do not invent
rules. Read the FULL files to audit unchanged lines adjacent to a change.

CRITICAL checklist:
1. SQL & data safety: string interpolation in SQL, TOCTOU check-then-set that
   should be atomic, bypassing validations, N+1 queries.
2. Race conditions & concurrency: read-check-write without a uniqueness
   constraint, find-or-create without a unique index, non-atomic status
   transitions; unsafe HTML (dangerouslySetInnerHTML / v-html) on user data (XSS).
3. LLM output trust boundary: LLM-generated values written to DB / fetched /
   stored without validation, allowlist, or sanitization.
4. Shell injection / eval: shell=True + interpolation, os.system with variables,
   eval/exec on untrusted input.
5. Enum & value completeness: trace every new enum/union/status value through
   EVERY consumer (switch, filter, allowlist, default branch).

RC6 Extensions:
6. Language & Framework Footguns (NOT style — correctness):
   - ASI hazards: a line starting with '(' or '[' after a mock cast
     ((x as jest.Mock) / (x as unknown as Mock)) can merge with the prior line —
     require jest.mocked(x).
   - Floating promises (un-awaited async whose rejection is lost).
   - `as any` on an I/O / parse boundary (Supabase {data,error}, JSON.parse,
     network) — hides the AP-216 null-destructure crash class; want a typed guard.
   - Missing defensive default on a destructured prop later consumed via .length,
     index, or spread (function F({ doses }) then doses.length -> require doses=[]).
7. Domain Rule Conformance — for EACH changed hunk, map it against the project
   CRITICAL RULES and cite the rule id/name:
   - Datas/Timezone: new Date('YYYY-MM-DD') (UTC-midnight bug), or rebuilding a
     user-timezone schedule via setHours(...) on a device-local now() — must use
     parseLocalDate / parseISO on the absolute timestamp.
   - Zod: .optional() without .nullable(); Portuguese enum values; schema<->SQL sync.
   - Dosage: order validate->register->decrement; quantity_taken in pills not mg.
8. Migration / Refactor Audit — when the PR renames+edits (.js->.ts) or refactors:
   for each touched function compare OLD vs NEW semantics; flag ANY changed
   arithmetic/conditional/argument/default even if it "looks equivalent", and
   state whether runtime behavior is preserved. `a - b` vs a.getTime()-b.getTime()
   IS preserved; a dropped ARGUMENT is preserved ONLY if the callee provably
   ignores it — verify by reading the callee.

Verification of claims (anti-rationalization): if you claim "safe", cite the
line; never say "likely"/"probably" — verify or flag as unknown.

Causation discipline: before asserting "change X causes bug Y", read the
definition of every symbol in the changed expression and cite the exact line
proving the mechanism. If the callee ignores the changed argument, say so and
set introduced=false (pre-existing — present with OR without the diff). Do not
propose a fix that doesn't actually work.

Suppressions — DO NOT flag: pure style/consistency, "add a comment", harmless
redundancy, tighter-assertion nits, or ANYTHING already addressed in the diff.

OUTPUT: strict JSON only, no prose, no markdown fence. Schema:
{"summary":"one paragraph","findings":[{"file":"path","line":123,
"severity":"critical|high|medium|low","introduced":true,
"rule":"R-NNN | AP-NNN | checklist#6 | none",
"causation":"mechanism + the exact line/def that proves it",
"issue":"what is wrong","fix":"concrete fix"}]}
If clean, return findings: [].
PROMPT

# Pass B leans on domain/migration extensions with full-file context.
PASSB_FOCUS=$'\nFOCUS FOR THIS PASS: Extensions #7 (Domain Rule Conformance) and #8 (Migration/Refactor Audit). Use the FULL FILES to reason about unchanged lines around each change. Weight timezone/date-math and dropped-argument regressions highest.'

# ---- run an engine: $1=engine(agy|claude) $2=prompt-file $3=out-json --------
run_engine() {
  local engine="$1" pf="$2" out="$3"
  case "$engine" in
    agy) agy --model 'Gemini 3.5 Flash (High)' -p "$(cat "$pf")" > "$out" 2>"$WORKDIR/${engine}.err" || return 1 ;;
    claude) claude --permission-mode auto --model sonnet -p "$(cat "$pf")" > "$out" 2>"$WORKDIR/${engine}.err" || return 1 ;;
  esac
}

build_prompt() { # $1=instruction-extra $2=outfile
  { printf '%s' "$RC6_INSTRUCTION"; printf '%s' "$1"; echo; echo; cat "$CTX"; } > "$2"
}

OUTS=(); ENGINES=()

# Pass A — agy generalist (CRITICAL + footguns)
build_prompt "" "$WORKDIR/promptA.txt"
if [ "$HAVE_AGY" = 1 ] && run_engine agy "$WORKDIR/promptA.txt" "$WORKDIR/outA.json"; then
  OUTS+=("$WORKDIR/outA.json"); ENGINES+=("agy")
  log "pass A (agy) ok"
else
  log "pass A (agy) unavailable/failed"
fi

# Pass B — domain-rule specialist on tier2 (prefer claude -p for reasoning)
if [ "$TIER" = 2 ]; then
  build_prompt "$PASSB_FOCUS" "$WORKDIR/promptB.txt"
  if [ "$HAVE_CLAUDE" = 1 ] && run_engine claude "$WORKDIR/promptB.txt" "$WORKDIR/outB.json"; then
    OUTS+=("$WORKDIR/outB.json"); ENGINES+=("claude")
    log "pass B (claude) ok"
  elif [ "$HAVE_AGY" = 1 ] && run_engine agy "$WORKDIR/promptB.txt" "$WORKDIR/outB.json"; then
    OUTS+=("$WORKDIR/outB.json"); ENGINES+=("agy")
    log "pass B (agy fallback) ok"
  else
    log "pass B unavailable — tier2 ran with pass A only"
  fi
fi

# ---- fail-open --------------------------------------------------------------
if [ "${#OUTS[@]}" = 0 ]; then
  echo '{"summary":"⚠️ AI review unavailable — human review mandatory (agy and claude both failed/absent).","findings":[]}'
  exit 0
fi

# ---- merge + dedupe + render (python) ---------------------------------------
ENGINE_LABEL="$(IFS=+; echo "${ENGINES[*]}")"
MERGED="$WORKDIR/merged.json"
python3 - "$MERGED" "$ENGINE_LABEL" "${OUTS[@]}" <<'PY'
import sys, json, re
out_path, engine_label = sys.argv[1], sys.argv[2]
paths = sys.argv[3:]

def extract(text):
    text = text.strip()
    text = re.sub(r'^```(?:json)?\s*|\s*```$', '', text, flags=re.S)
    try:
        return json.loads(text)
    except Exception:
        i, j = text.find('{'), text.rfind('}')
        if i >= 0 and j > i:
            try: return json.loads(text[i:j+1])
            except Exception: return None
    return None

sev_rank = {"critical":4,"high":3,"medium":2,"low":1}
summaries, merged = [], {}
for p in paths:
    try: raw = open(p).read()
    except Exception: continue
    obj = extract(raw)
    if not obj: continue
    if obj.get("summary"): summaries.append(obj["summary"])
    for f in obj.get("findings", []) or []:
        key = (f.get("file"), f.get("line"), (f.get("issue","")[:60]).lower())
        cur = merged.get(key)
        if cur is None or sev_rank.get(f.get("severity","low"),1) > sev_rank.get(cur.get("severity","low"),1):
            merged[key] = f

findings = sorted(merged.values(),
                  key=lambda f: (-sev_rank.get(f.get("severity","low"),1),
                                 not f.get("introduced", True)))
def cnt(sev, introduced=None):
    return sum(1 for f in findings
               if f.get("severity")==sev and (introduced is None or bool(f.get("introduced",True))==introduced))

result = {
    "engine": engine_label,
    "summary": " | ".join(summaries) if summaries else "(no summary)",
    "counts": {
        "critical": cnt("critical"), "high": cnt("high"),
        "medium": cnt("medium"), "low": cnt("low"),
        "introduced_critical": cnt("critical", True),
        "introduced_high": cnt("high", True),
    },
    "findings": findings,
}
json.dump(result, open(out_path,"w"), ensure_ascii=False, indent=2)
print(json.dumps(result, ensure_ascii=False, indent=2))
PY

# ---- dry-run stops here (no PR / state mutation) ----------------------------
if [ "$POST" = 0 ]; then
  log "dry-run: no PR comments, no state/journal writes"
  exit 0
fi

# =============================================================================
# --post PATH ("for real"): publish inline to the PR + persist state/journal.
# Only reached with explicit --post. Never runs under the default dry-run.
# =============================================================================
[ -n "$PR" ]        || { echo "--post needs a PR number (none resolved)" >&2; exit 2; }
[ "$HAVE_GH" = 1 ]  || { echo "--post needs gh CLI" >&2; exit 2; }

log "posting RC6 review to PR #$PR"
python3 - "$MERGED" "$PR" "$HEAD_SHA" <<'PY'
import sys, json, subprocess
merged, pr, sha = json.load(open(sys.argv[1])), sys.argv[2], sys.argv[3]
sev_emoji = {"critical":"🟥","high":"🟧","medium":"🟨","low":"🟦"}
comments, orphan = [], []
for f in merged["findings"]:
    tag = "" if f.get("introduced", True) else " _(pre-existing — not introduced by this PR)_"
    body = (f"{sev_emoji.get(f.get('severity'),'⬜')} **{f.get('severity','?')}**{tag} "
            f"[{f.get('rule','none')}]\n\n{f.get('issue','')}\n\n"
            f"**Causation:** {f.get('causation','')}\n\n**Fix:** {f.get('fix','')}")
    if f.get("file") and f.get("line"):
        comments.append({"path": f["file"], "line": int(f["line"]), "side": "RIGHT", "body": body})
    else:
        orphan.append(body)

c = merged["counts"]
head = (f"## 🤖 RC6 — Independent AI Review (`{merged['engine']}`)\n\n"
        f"{merged['summary']}\n\n"
        f"**Introduced:** {c['introduced_critical']} critical · {c['introduced_high']} high "
        f"(total {c['critical']}c/{c['high']}h/{c['medium']}m/{c['low']}l). "
        f"Findings marked _pre-existing_ do not block this PR.\n")
if orphan:
    head += "\n### Un-anchorable findings\n" + "\n\n---\n\n".join(orphan)

payload = {"commit_id": sha, "event": "COMMENT", "body": head, "comments": comments}
# retry, dropping inline comments GitHub rejects (lines outside the diff)
while True:
    p = subprocess.run(["gh","api","repos/:owner/:repo/pulls/%s/reviews"%pr,
                        "--input","-"], input=json.dumps(payload), text=True,
                       capture_output=True)
    if p.returncode == 0:
        print("posted RC6 review to PR #%s (%d inline, %d orphan)" % (pr, len(payload["comments"]), len(orphan)))
        break
    err = p.stderr
    # GitHub reports the bad line; drop that comment and retry, else give up to a body-only review
    if payload["comments"]:
        payload["comments"] = payload["comments"][:-1]
        continue
    print("gh api failed:", err, file=sys.stderr); sys.exit(1)
PY

# persist state.json.session.ai_review + journal entry
python3 - "$MERGED" "$PR" "$REPO_ROOT" <<'PY'
import sys, json, os, datetime
merged, pr, root = json.load(open(sys.argv[1])), int(sys.argv[2]), sys.argv[3]
c = merged["counts"]
status = "issues_found" if (c["introduced_critical"] or c["introduced_high"]) else "clean"
sp = os.path.join(root, ".agent/state.json")
d = json.load(open(sp))
d.setdefault("session", {})["ai_review"] = {
    "engine": merged["engine"], "status": status, "pr": pr,
    "critical": c["critical"], "high": c["high"],
    "introduced_critical": c["introduced_critical"], "introduced_high": c["introduced_high"],
}
json.dump(d, open(sp,"w"), ensure_ascii=False, indent=2); open(sp,"a").write("\n")

sprint = d.get("sprint") or datetime.date.today().strftime("%Y-W%V")
jp = os.path.join(root, ".agent/memory/journal", f"{sprint}.jsonl")
os.makedirs(os.path.dirname(jp), exist_ok=True)
entry = {"session":"rc6","date":datetime.date.today().isoformat(),"type":"ai_review",
         "ceremony":"RC6","pr":pr,"engine":merged["engine"],"status":status,
         "summary": (merged["summary"][:500]),
         "counts": c}
with open(jp,"a") as f: f.write(json.dumps(entry, ensure_ascii=False)+"\n")
print("state.json + journal updated (status=%s)" % status)
PY

log "RC6 --post complete"
