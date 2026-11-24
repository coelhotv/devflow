#!/usr/bin/env bash
# rc6-truncation-and-selector.test.sh — offline tests for @core 1.3.0 + ai-review hardening:
#   1. Turn-1 truncation guard aware of num_turns (no false positive on neon-high num_turns=2)
#   2. Prompt section ordering (CLAUDE.md/preamble -> DIFF -> FULL FILES)
#   3. Pass B agy escalation (gemini-4-neon-high, 10m) and explicit overrides
#   4. Visible selector fail-open (exit != 0 and exit 0 with fail-safe 056)
#   5. Default RC6_MAX_CHUNKS=8
#
# Usage: bash tests/rc6-truncation-and-selector.test.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/scripts/ai-review.sh"
T="$(mktemp -d)"
trap '[ -n "${KEEP_T:-}" ] || rm -rf "$T"' EXIT
pass=0; fail=0
ok()   { echo "  ok   $1"; pass=$((pass+1)); }
bad()  { echo "  FALHA  $1"; fail=$((fail+1)); }

# --- isolated PATH: git/python3/bc/node + fake agy (no claude, no real LLM) --
BIN="$T/bin"; mkdir -p "$BIN"
for b in git python3 bc; do ln -s "$(command -v "$b")" "$BIN/$b"; done
NODE_BIN="$(command -v node || true)"
[ -n "$NODE_BIN" ] || { echo "node required for selector test" >&2; exit 2; }
ln -s "$NODE_BIN" "$BIN/node"
ISOPATH="$BIN:/usr/bin:/bin"

cat > "$T/fake-agy" <<'SH'
#!/usr/bin/env bash
if [ "${1:-}" = --help ]; then
  echo "usage: agy [--sandbox] [--json-schema] [--output-format] [--disable-slash-commands]"; exit 0
fi
model=""; timeout=""; prompt=""; prev=""
for a in "$@"; do
  case "$prev" in
    --model) model="$a" ;;
    --print-timeout) timeout="$a" ;;
    -p) prompt="$a" ;;
  esac
  prev="$a"
done
n="$(cat "$FAKE_DIR/agy.n" 2>/dev/null || echo 0)"; n=$((n+1)); echo "$n" > "$FAKE_DIR/agy.n"
printf '%s' "$prompt" > "$FAKE_DIR/prompt_${n}.txt"
printf 'model=%s timeout=%s\n' "$model" "$timeout" >> "$FAKE_DIR/agy.calls"
case "${FAKE_AGY_USAGE_MODE:-t1_safe}" in
  t1_safe)
    printf '{"status":"SUCCESS","num_turns":1,"structured_output":{"summary":"fake safe","findings":[]},"usage":{"input_tokens":65192,"output_tokens":1089,"thinking_tokens":1018,"cache_read_tokens":0}}\n' ;;
  t1_trunc)
    printf '{"status":"SUCCESS","num_turns":1,"structured_output":{"summary":"fake t1 trunc","findings":[]},"usage":{"input_tokens":79636,"output_tokens":1262,"thinking_tokens":1200,"cache_read_tokens":0}}\n' ;;
  t2_neon_high_safe)
    printf '{"status":"SUCCESS","num_turns":2,"structured_output":{"summary":"fake neon high","findings":[]},"usage":{"input_tokens":97785,"output_tokens":35775,"thinking_tokens":32218,"cache_read_tokens":63812}}\n' ;;
  t2_hydrogen_trunc)
    printf '{"status":"SUCCESS","num_turns":2,"structured_output":{"summary":"fake hydrogen trunc","findings":[]},"usage":{"input_tokens":83324,"output_tokens":949,"thinking_tokens":817,"cache_read_tokens":78286}}\n' ;;
esac
SH
chmod +x "$T/fake-agy"
ln -s "$T/fake-agy" "$BIN/agy"

# --- fake selector scripts ---------------------------------------------------
cat > "$T/sel_ok.mjs" <<'JS'
console.log("## R-901 — Fake rule\nBody line of fake rule.");
JS
cat > "$T/sel_fail_err.mjs" <<'JS'
console.error("Error [ERR_MODULE_NOT_FOUND]: Cannot find package 'js-yaml'");
process.exit(1);
JS
cat > "$T/sel_failsafe.mjs" <<'JS'
console.error("fail-safe 056 ativado");
console.log("mobile_and_platform");
JS

# --- repo fixture ------------------------------------------------------------
R="$T/repo"; mkdir -p "$R/src" "$R/.agent/memory"
git -C "$R" init -q
git -C "$R" config user.email rc6@fixture.local
git -C "$R" config user.name  rc6-fixture
printf '# CLAUDE\n\n## Regras Críticas\n- Always check timezone.\n' > "$R/CLAUDE.md"
printf '# RULES_INDEX\n\n- **[R-001]** fixture rule (`rules/data_and_schema/R-001.md`)\n' > "$R/.agent/memory/RULES_INDEX.md"
printf '# ANTI_PATTERNS_INDEX\n\n- **[AP-001]** fixture ap (`anti-patterns/react_and_ui/AP-001.md`)\n' > "$R/.agent/memory/ANTI_PATTERNS_INDEX.md"
printf 'export function run(d) {\n  return d;\n}\n' > "$R/src/app.js"
git -C "$R" add -A; git -C "$R" commit -qm base; git -C "$R" branch -M main
git -C "$R" checkout -qb feature
printf 'export function run(d) {\n  if (!d) return new Date();\n  return d;\n}\n' > "$R/src/app.js"
git -C "$R" add -A; git -C "$R" commit -qm feature

run() {
  local name="$1"; shift
  D="$T/$name"; mkdir -p "$D"
  : > "$D/agy.calls"
  ( cd "$R" && PATH="$ISOPATH" FAKE_DIR="$D" \
      RC6_MAIN=main RC6_ENGINE_CLAUDE=0 RC6_SKIP_PROBE=1 RC6_AB=0 RC6_REFLECT=0 RC6_JITTER=0 \
      RC6_STATUS_FILE="$D/status.jsonl" \
      bash "$SCRIPT" --dry-run --json-out="$D/out.json" "$@" > "$D/stdout.txt" 2> "$D/err.txt" ) || echo "EXIT=$?" >> "$D/err.txt"
}
j() { python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(eval(sys.argv[2], {"d": d}))' "$D/out.json" "$1" 2>/dev/null || echo "<erro>"; }
verdict() {
  python3 -c 'import re,sys
txt=re.sub(r"\x1b\[[0-9;]*m","",open(sys.argv[1]).read())
lines=[l for l in txt.splitlines() if "VERDICT " in l]
print(lines[-1] if lines else "")' "$D/err.txt"
}

echo "== 1 & 2. t1_safe + prompt order (preamble -> DIFF -> FULL FILES)"
RC6_SELECTOR=0 FAKE_AGY_USAGE_MODE=t1_safe run t1_safe
[ "$(j 'd["coverage"]["partial"]')" = False ] && ok "t1_safe: partial=False" || bad "t1_safe partial=$(j 'd["coverage"]["partial"]')"
[ "$(j 'd["coverage"]["truncated_chunks"]')" = 0 ] && ok "t1_safe: truncated_chunks=0" || bad "t1_safe truncated_chunks=$(j 'd["coverage"].get("truncated_chunks")')"
[ "$(j 'd["coverage"]["per_pass"]["A"]["truncated"]')" = "[]" ] && ok "t1_safe: per_pass.A.truncated=[]" || bad "t1_safe per_pass.truncated=$(j 'd["coverage"]["per_pass"]["A"].get("truncated")')"
V="$(verdict)"
case "$V" in
  *"VERDICT coverage=full A=1/1 reviewers_min=1"*) ok "t1_safe: VERDICT clean without truncated=" ;;
  *) bad "t1_safe VERDICT unexpected: $V" ;;
esac
grep -q 'thinking=1018' "$D/err.txt" && grep -q 'turns=1' "$D/err.txt" \
  && ok "t1_safe: telemetry logs thinking & turns" || bad "t1_safe missing thinking/turns telemetry"
python3 - "$D/prompt_1.txt" <<'PY' && ok "prompt order: PROJECT CRITICAL RULES < DIFF < FULL FILES" || bad "prompt order wrong"
import sys
p = open(sys.argv[1]).read()
i_pre = p.index("PROJECT CRITICAL RULES")
i_diff = p.index("===== DIFF")
i_full = p.index("===== FULL FILES")
assert i_pre < i_diff < i_full, (i_pre, i_diff, i_full)
PY

echo "== 3. t1_trunc (num_turns=1, input_tokens=79636)"
RC6_SELECTOR=0 FAKE_AGY_USAGE_MODE=t1_trunc run t1_trunc
[ "$(j 'd["coverage"]["partial"]')" = True ] && ok "t1_trunc: partial=True" || bad "t1_trunc partial=$(j 'd["coverage"].get("partial")')"
[ "$(j 'd["coverage"]["truncated_chunks"]')" = 1 ] && ok "t1_trunc: truncated_chunks=1" || bad "t1_trunc truncated_chunks=$(j 'd["coverage"].get("truncated_chunks")')"
[ "$(j 'd["coverage"]["per_pass"]["A"]["truncated"]')" = "[1]" ] && ok "t1_trunc: per_pass.A.truncated=[1]" || bad "t1_trunc per_pass.truncated=$(j 'd["coverage"]["per_pass"]["A"].get("truncated")')"
V="$(verdict)"
case "$V" in
  *"VERDICT coverage=partial"*"truncated=1"*) ok "t1_trunc: VERDICT surfaces truncated=1" ;;
  *) bad "t1_trunc VERDICT unexpected: $V" ;;
esac
grep -q '"truncated":true' "$D/status.jsonl" && ok "t1_trunc: status.jsonl records truncated:true" || bad "t1_trunc missing status truncated"
grep -q 'TRUNCATED=1' "$D/err.txt" && grep -q '⚠️TRUNCATED' "$D/err.txt" \
  && ok "t1_trunc: stderr logs TRUNCATED=1 and chunk warning" || bad "t1_trunc missing stderr warning"

echo "== 4. t2_neon_high_safe (num_turns=2, input=97785, cache_read=63812 -> zero false positive)"
RC6_SELECTOR=0 FAKE_AGY_USAGE_MODE=t2_neon_high_safe run t2_neon_high_safe
[ "$(j 'd["coverage"]["partial"]')" = False ] && ok "t2_neon_high_safe: partial=False" || bad "t2_neon_high_safe partial=$(j 'd["coverage"].get("partial")')"
[ "$(j 'd["coverage"]["truncated_chunks"]')" = 0 ] && ok "t2_neon_high_safe: truncated_chunks=0" || bad "t2_neon_high_safe truncated_chunks=$(j 'd["coverage"].get("truncated_chunks")')"
[ "$(j 'd["coverage"]["per_pass"]["A"]["truncated"]')" = "[]" ] && ok "t2_neon_high_safe: per_pass.A.truncated=[]" || bad "t2_neon_high_safe truncated=$(j 'd["coverage"]["per_pass"]["A"].get("truncated")')"
grep -q 'thinking=32218' "$D/err.txt" && grep -q 'turns=2' "$D/err.txt" \
  && ok "t2_neon_high_safe: telemetry logs thinking=32218 turns=2" || bad "t2_neon_high_safe missing telemetry"
if grep -q 'TRUNCATED=1' "$D/err.txt"; then bad "t2_neon_high_safe triggered false positive TRUNCATED=1"; else ok "t2_neon_high_safe: no false positive TRUNCATED=1"; fi

echo "== 5. t2_hydrogen_trunc (num_turns=2, cache_read=78286 -> truncated)"
RC6_SELECTOR=0 FAKE_AGY_USAGE_MODE=t2_hydrogen_trunc run t2_hydrogen_trunc
[ "$(j 'd["coverage"]["partial"]')" = True ] && ok "t2_hydrogen_trunc: partial=True" || bad "t2_hydrogen_trunc partial=$(j 'd["coverage"].get("partial")')"
[ "$(j 'd["coverage"]["truncated_chunks"]')" = 1 ] && ok "t2_hydrogen_trunc: truncated_chunks=1" || bad "t2_hydrogen_trunc truncated_chunks=$(j 'd["coverage"].get("truncated_chunks")')"
[ "$(j 'd["coverage"]["per_pass"]["A"]["truncated"]')" = "[1]" ] && ok "t2_hydrogen_trunc: per_pass.A.truncated=[1]" || bad "t2_hydrogen_trunc truncated=$(j 'd["coverage"]["per_pass"]["A"].get("truncated")')"
grep -q '"truncated":true' "$D/status.jsonl" && ok "t2_hydrogen_trunc: status.jsonl records truncated:true" || bad "t2_hydrogen_trunc missing status truncated"

echo "== 6. Pass B agy escalation + overrides"
RC6_SELECTOR=0 FAKE_AGY_USAGE_MODE=t1_safe run passb_default --tier2
[ "$(sed -n 1p "$D/agy.calls")" = "model=gemini-4-neon-medium timeout=8m" ] \
  && ok "passb_default: Pass A uses neon-medium timeout=8m" || bad "passb_default Pass A: $(sed -n 1p "$D/agy.calls")"
[ "$(sed -n 2p "$D/agy.calls")" = "model=gemini-4-neon-high timeout=10m" ] \
  && ok "passb_default: Pass B uses neon-high timeout=10m" || bad "passb_default Pass B: $(sed -n 2p "$D/agy.calls")"

RC6_SELECTOR=0 RC6_AGY_PASSB_MODEL="" RC6_AGY_TIMEOUT=4m FAKE_AGY_USAGE_MODE=t1_safe run passb_override --tier2
[ "$(sed -n 1p "$D/agy.calls")" = "model=gemini-4-neon-medium timeout=4m" ] \
  && ok "passb_override: Pass A respects RC6_AGY_TIMEOUT=4m" || bad "passb_override Pass A: $(sed -n 1p "$D/agy.calls")"
[ "$(sed -n 2p "$D/agy.calls")" = "model=gemini-4-neon-medium timeout=4m" ] \
  && ok "passb_override: RC6_AGY_PASSB_MODEL='' inherits Pass A model and timeout=4m" || bad "passb_override Pass B: $(sed -n 2p "$D/agy.calls")"

echo "== 7. Visible selector fail-open"
RC6_SELECTOR=1 RC6_SELECTOR_SCRIPT="$T/sel_ok.mjs" FAKE_AGY_USAGE_MODE=t1_safe run sel_ok
[ "$(j 'd["coverage"]["selector"]["status"]')" = "ok" ] && [ "$(j 'd["coverage"]["selector"]["count"]')" = "1" ] \
  && ok "sel_ok: coverage.selector={status:ok, count:1}" || bad "sel_ok selector=$(j 'd["coverage"].get("selector")')"
V="$(verdict)"
case "$V" in
  *"selector=FAILED"*) bad "sel_ok VERDICT unexpectedly has selector=FAILED: $V" ;;
  *) ok "sel_ok: VERDICT omits selector=FAILED" ;;
esac
grep -q 'SELECTED MEMORIES' "$D/prompt_1.txt" && grep -q 'R-901' "$D/prompt_1.txt" \
  && ok "sel_ok: prompt contains SELECTED MEMORIES + R-901" || bad "sel_ok missing R-901 in prompt"

RC6_SELECTOR=1 RC6_SELECTOR_SCRIPT="$T/sel_fail_err.mjs" FAKE_AGY_USAGE_MODE=t1_safe run sel_fail_err
[ "$(j 'd["coverage"]["selector"]["status"]')" = "failed" ] \
  && ok "sel_fail_err: fails open with selector.status=failed" || bad "sel_fail_err status=$(j 'd["coverage"].get("selector")')"
case "$(j 'd["coverage"]["selector"].get("reason","")')" in
  *js-yaml*) ok "sel_fail_err: selector.reason preserves js-yaml stderr" ;;
  *) bad "sel_fail_err reason=$(j 'd["coverage"].get("selector")')" ;;
esac
V="$(verdict)"
case "$V" in
  *"selector=FAILED"*) ok "sel_fail_err: VERDICT surfaces selector=FAILED" ;;
  *) bad "sel_fail_err VERDICT missing selector=FAILED: $V" ;;
esac

RC6_SELECTOR=1 RC6_SELECTOR_SCRIPT="$T/sel_failsafe.mjs" FAKE_AGY_USAGE_MODE=t1_safe run sel_failsafe
[ "$(j 'd["coverage"]["selector"]["status"]')" = "failed" ] \
  && ok "sel_failsafe: exit 0 with fail-safe 056 sets selector.status=failed" || bad "sel_failsafe selector=$(j 'd["coverage"].get("selector")')"
case "$(j 'd["coverage"]["selector"].get("reason","")')" in
  *"fail-safe 056"*) ok "sel_failsafe: selector.reason preserves fail-safe 056" ;;
  *) bad "sel_failsafe reason=$(j 'd["coverage"].get("selector")')" ;;
esac
V="$(verdict)"
case "$V" in
  *"selector=FAILED"*) ok "sel_failsafe: VERDICT surfaces selector=FAILED" ;;
  *) bad "sel_failsafe VERDICT missing selector=FAILED: $V" ;;
esac

echo "== 8. Default RC6_MAX_CHUNKS=8 vs RC6_MAX_CHUNKS=6"
R7="$T/repo7"; mkdir -p "$R7/src" "$R7/.agent/memory"
git -C "$R7" init -q
git -C "$R7" config user.email rc6@fixture.local
git -C "$R7" config user.name  rc6-fixture
printf '# RULES_INDEX\n' > "$R7/.agent/memory/RULES_INDEX.md"
printf '# ANTI_PATTERNS_INDEX\n' > "$R7/.agent/memory/ANTI_PATTERNS_INDEX.md"
for k in 1 2 3 4 5 6 7; do printf 'export const base%s = 0;\n' "$k" > "$R7/src/m$k.js"; done
git -C "$R7" add -A; git -C "$R7" commit -qm base; git -C "$R7" branch -M main
git -C "$R7" checkout -qb feature
for k in 1 2 3 4 5 6 7; do
  python3 -c 'import sys; k=sys.argv[1]; print("\n".join("export const v%s_%d = %d;" % (k,i,i) for i in range(1600)))' "$k" > "$R7/src/m$k.js"
done
git -C "$R7" add -A; git -C "$R7" commit -qm feature

OUT7_DEF="$(cd "$R7" && PATH="$ISOPATH" RC6_MEASURE=1 RC6_MAIN=main RC6_SELECTOR=0 RC6_CTX_TOTAL_MAX=40000 bash "$SCRIPT" 2>&1)"
OUT7_CAP6="$(cd "$R7" && PATH="$ISOPATH" RC6_MEASURE=1 RC6_MAIN=main RC6_SELECTOR=0 RC6_CTX_TOTAL_MAX=40000 RC6_MAX_CHUNKS=6 bash "$SCRIPT" 2>&1)"
if printf '%s' "$OUT7_DEF" | grep -q 'chunks=7' && ! printf '%s' "$OUT7_DEF" | grep -q 'PARTIAL COVERAGE'; then
  ok "max_chunks_default_8: keeps all 7 chunks with no PARTIAL COVERAGE"
else
  bad "max_chunks_default_8 failed: $OUT7_DEF"
fi
if printf '%s' "$OUT7_CAP6" | grep -q '7 chunks > cap 6 — PARTIAL COVERAGE'; then
  ok "max_chunks_cap_6: triggers PARTIAL COVERAGE on 7 chunks"
else
  bad "max_chunks_cap_6 failed: $OUT7_CAP6"
fi

echo "== 9. Per-chunk selector + DETAIL_FILES (A1 / RC6_CHUNK_SCOPE)"
R2="$T/repo2"; mkdir -p "$R2/src" "$R2/.agent/memory/rules"
git -C "$R2" init -q
git -C "$R2" config user.email rc6@fixture.local
git -C "$R2" config user.name  rc6-fixture
printf '# CLAUDE\n\n## Regras Críticas\n- Always check timezone.\n' > "$R2/CLAUDE.md"
printf '# RULES_INDEX\n\n- **[R-101]** alpha rule (`rules/data_and_schema/R-101.md`)\n- **[R-102]** beta rule (`rules/react_and_ui/R-102.md`)\n' > "$R2/.agent/memory/RULES_INDEX.md"
printf '# ANTI_PATTERNS_INDEX\n\n- **[AP-001]** fixture ap (`anti-patterns/react_and_ui/AP-001.md`)\n' > "$R2/.agent/memory/ANTI_PATTERNS_INDEX.md"
printf '# R-101\nDetail body for alpha rule R-101.\n' > "$R2/.agent/memory/rules/R-101.md"
printf '# R-102\nDetail body for beta rule R-102.\n' > "$R2/.agent/memory/rules/R-102.md"
printf 'export const a0 = 0;\n' > "$R2/src/a.js"
printf 'export const b0 = 0;\n' > "$R2/src/b.js"
git -C "$R2" add -A; git -C "$R2" commit -qm base; git -C "$R2" branch -M main
git -C "$R2" checkout -qb feature
python3 -c 'print("// R-101 ALPHA_TOKEN\n" + "\n".join("export const a_%d = %d;" % (i, i) for i in range(450)))' > "$R2/src/a.js"
python3 -c 'print("// R-102 BETA_TOKEN\n" + "\n".join("export const b_%d = %d;" % (i, i) for i in range(450)))' > "$R2/src/b.js"
git -C "$R2" add -A; git -C "$R2" commit -qm feature

cat > "$T/sel_chunk_aware.mjs" <<'JS'
import fs from 'node:fs';
const args = process.argv.slice(2);
const idx = args.indexOf('--diff-file');
const diffPath = idx >= 0 ? args[idx + 1] : '';
const txt = diffPath ? fs.readFileSync(diffPath, 'utf8') : '';
if (process.env.SEL_CALLS_LOG) fs.appendFileSync(process.env.SEL_CALLS_LOG, diffPath + '\n');
const out = [];
if (txt.includes('ALPHA_TOKEN')) {
  out.push('## R-101 — Alpha detail dup\nDup body should be deduped against chunk detail.');
  out.push('## R-911 — Alpha only\nSelected body for alpha chunk.');
}
if (txt.includes('BETA_TOKEN')) {
  out.push('## R-102 — Beta detail dup\nDup body should be deduped against chunk detail.');
  out.push('## R-912 — Beta only\nSelected body for beta chunk.');
}
console.log(out.join('\n\n'));
JS

cat > "$T/sel_fail_chunk2.mjs" <<'JS'
import fs from 'node:fs';
const args = process.argv.slice(2);
const idx = args.indexOf('--diff-file');
const txt = idx >= 0 ? fs.readFileSync(args[idx + 1], 'utf8') : '';
if (txt.includes('BETA_TOKEN')) {
  console.error('chunk2 boom');
  process.exit(1);
}
console.log('## R-911 — Alpha only\nSelected body for alpha chunk.');
JS

run2() {
  local name="$1"; shift
  D="$T/$name"; mkdir -p "$D"
  : > "$D/agy.calls"; : > "$D/sel.calls"
  ( cd "$R2" && PATH="$ISOPATH" FAKE_DIR="$D" SEL_CALLS_LOG="$D/sel.calls" \
      RC6_MAIN=main RC6_ENGINE_CLAUDE=0 RC6_SKIP_PROBE=1 RC6_AB=0 RC6_REFLECT=0 RC6_JITTER=0 \
      RC6_CTX_TOTAL_MAX=40000 RC6_STATUS_FILE="$D/status.jsonl" \
      bash "$SCRIPT" --dry-run --json-out="$D/out.json" "$@" > "$D/stdout.txt" 2> "$D/err.txt" ) || echo "EXIT=$?" >> "$D/err.txt"
}

RC6_SELECTOR=1 RC6_SELECTOR_SCRIPT="$T/sel_chunk_aware.mjs" FAKE_AGY_USAGE_MODE=t1_safe run2 a1_per_chunk
[ "$(wc -l < "$D/sel.calls" | tr -d ' ')" = "2" ] \
  && ok "a1_per_chunk: selector invoked twice (once per chunk)" || bad "a1_per_chunk selector calls=$(wc -l < "$D/sel.calls" | tr -d ' ')"
grep -q 'DETAIL R-101.md' "$D/prompt_1.txt" && grep -q 'R-911' "$D/prompt_1.txt" \
  && ok "a1_per_chunk: chunk 1 has DETAIL R-101.md + selected R-911" || bad "a1_per_chunk chunk 1 missing R-101/R-911"
if grep -q 'DETAIL R-102.md' "$D/prompt_1.txt" || grep -q 'R-912' "$D/prompt_1.txt" || grep -q '^## R-101 ' "$D/prompt_1.txt"; then
  bad "a1_per_chunk: chunk 1 leaked chunk 2 memory or duplicated R-101 in SELECTED"
else
  ok "a1_per_chunk: chunk 1 isolated from chunk 2 and deduped R-101"
fi
grep -q 'DETAIL R-102.md' "$D/prompt_2.txt" && grep -q 'R-912' "$D/prompt_2.txt" \
  && ok "a1_per_chunk: chunk 2 has DETAIL R-102.md + selected R-912" || bad "a1_per_chunk chunk 2 missing R-102/R-912"
if grep -q 'DETAIL R-101.md' "$D/prompt_2.txt" || grep -q 'R-911' "$D/prompt_2.txt" || grep -q '^## R-102 ' "$D/prompt_2.txt"; then
  bad "a1_per_chunk: chunk 2 leaked chunk 1 memory or duplicated R-102 in SELECTED"
else
  ok "a1_per_chunk: chunk 2 isolated from chunk 1 and deduped R-102"
fi
[ "$(j '(d["coverage"]["selector"]["status"], d["coverage"]["selector"]["count"], d["coverage"]["selector"]["scope"], d["coverage"]["selector"]["chunks_ok"], d["coverage"]["selector"]["chunks_failed"])')" = "('ok', 2, 'per_chunk', 2, 0)" ] \
  && ok "a1_per_chunk: coverage.selector={ok, 2, per_chunk, 2/0}" || bad "a1_per_chunk selector=$(j 'd["coverage"].get("selector")')"

RC6_CHUNK_SCOPE=0 RC6_SELECTOR=1 RC6_SELECTOR_SCRIPT="$T/sel_chunk_aware.mjs" FAKE_AGY_USAGE_MODE=t1_safe run2 a1_legacy
[ "$(wc -l < "$D/sel.calls" | tr -d ' ')" = "1" ] \
  && ok "a1_legacy: RC6_CHUNK_SCOPE=0 invokes selector once globally" || bad "a1_legacy selector calls=$(wc -l < "$D/sel.calls" | tr -d ' ')"
grep -q 'DETAIL R-101.md' "$D/prompt_1.txt" && grep -q 'DETAIL R-102.md' "$D/prompt_1.txt" \
  && ok "a1_legacy: chunk 1 receives replicated global DETAIL R-101 + R-102" || bad "a1_legacy chunk 1 missing replicated global details"
[ "$(j 'd["coverage"]["selector"]["scope"]')" = "global" ] \
  && ok "a1_legacy: coverage.selector.scope=global" || bad "a1_legacy scope=$(j 'd["coverage"].get("selector")')"

RC6_SELECTOR=1 RC6_SELECTOR_SCRIPT="$T/sel_fail_chunk2.mjs" FAKE_AGY_USAGE_MODE=t1_safe run2 a1_partial_fail
[ "$(j '(d["coverage"]["selector"]["status"], d["coverage"]["selector"]["chunks_ok"], d["coverage"]["selector"]["chunks_failed"])')" = "('failed', 1, 1)" ] \
  && ok "a1_partial_fail: status=failed with chunks_ok=1 chunks_failed=1" || bad "a1_partial_fail selector=$(j 'd["coverage"].get("selector")')"
case "$(j 'd["coverage"]["selector"].get("reason","")')" in
  *"chunk2 boom"*) ok "a1_partial_fail: reason preserves chunk2 boom" ;;
  *) bad "a1_partial_fail reason=$(j 'd["coverage"].get("selector")')" ;;
esac
V="$(verdict)"
case "$V" in
  *"selector=FAILED"*) ok "a1_partial_fail: VERDICT surfaces selector=FAILED" ;;
  *) bad "a1_partial_fail VERDICT unexpected: $V" ;;
esac
grep -q 'R-911' "$D/prompt_1.txt" \
  && ok "a1_partial_fail: chunk 1 still received R-911 (fail-open per chunk)" || bad "a1_partial_fail chunk 1 missing R-911"

BD_OUT="$(cd "$R2" && PATH="$ISOPATH" RC6_MAIN=main RC6_SELECTOR=1 RC6_SELECTOR_SCRIPT="$T/sel_chunk_aware.mjs" bash "$SCRIPT" --breakdown 2>&1)" && BD_RC=0 || BD_RC=$?
if [ "$BD_RC" = 0 ] && printf '%s' "$BD_OUT" | grep -q 'reconciliacao: 0B'; then
  ok "a1_breakdown: --breakdown exits 0 with reconciliacao: 0B"
else
  bad "a1_breakdown rc=$BD_RC out=$BD_OUT"
fi

cat > "$T/sel_format_probe.mjs" <<'JS'
import fs from 'node:fs';
if (process.env.SEL_ARGS_LOG) fs.appendFileSync(process.env.SEL_ARGS_LOG, process.argv.slice(2).join(' ') + '\n');
console.log('## R-911 — Format probe\nCard body.');
JS
SEL_ARGS_LOG="$T/a2_args.log" RC6_SELECTOR=1 RC6_SELECTOR_FORMAT=card RC6_SELECTOR_SCRIPT="$T/sel_format_probe.mjs" FAKE_AGY_USAGE_MODE=t1_safe run2 a2_format_card
grep -q -- '--format card' "$T/a2_args.log" \
  && ok "a2_format_card: RC6_SELECTOR_FORMAT=card passes --format card to selector" \
  || bad "a2_format_card args=$(cat "$T/a2_args.log" 2>/dev/null || true)"

echo "== 10. Adaptive effort routing by chunk risk (C2)"
R3="$T/repo3"; mkdir -p "$R3/packages/core/src" "$R3/src/components" "$R3/src/z/__tests__" "$R3/.agent/memory"
git -C "$R3" init -q
git -C "$R3" config user.email rc6@fixture.local
git -C "$R3" config user.name  rc6-fixture
printf '# CLAUDE\n\n## Regras Críticas\n- Always check timezone.\n' > "$R3/CLAUDE.md"
printf '# RULES_INDEX\n' > "$R3/.agent/memory/RULES_INDEX.md"
printf '# ANTI_PATTERNS_INDEX\n' > "$R3/.agent/memory/ANTI_PATTERNS_INDEX.md"
printf 'export const baseCore = 0;\n' > "$R3/packages/core/src/calc.ts"
printf 'export const baseUi = 0;\n' > "$R3/src/components/ui.js"
printf 'export const baseTest = 0;\n' > "$R3/src/z/__tests__/ui.test.js"
git -C "$R3" add -A; git -C "$R3" commit -qm base; git -C "$R3" branch -M main
git -C "$R3" checkout -qb feature
python3 -c 'print("export function calc(a) {\n  if (a > 0) return a + 1;\n  return 0;\n}\n" + "\n".join("export const c_%d = %d;" % (i, i) for i in range(450)))' > "$R3/packages/core/src/calc.ts"
python3 -c 'print("export function ui(x) {\n  return x ? 1 : 0;\n}\n" + "\n".join("export const u_%d = %d;" % (i, i) for i in range(450)))' > "$R3/src/components/ui.js"
python3 -c 'print("\n".join("export const t_%d = %d;" % (i, i) for i in range(450)))' > "$R3/src/z/__tests__/ui.test.js"
git -C "$R3" add -A; git -C "$R3" commit -qm feature

run3() {
  local name="$1"; shift
  D="$T/$name"; mkdir -p "$D"
  : > "$D/agy.calls"; : > "$D/claude.calls"
  ( cd "$R3" && PATH="${TEST_PATH:-$ISOPATH}" FAKE_DIR="$D" \
      RC6_MAIN=main RC6_ENGINE_CLAUDE="${TEST_CLAUDE:-0}" RC6_SKIP_PROBE=1 RC6_AB=0 RC6_REFLECT=0 RC6_JITTER=0 RC6_SELECTOR=0 \
      RC6_CTX_TOTAL_MAX=40000 RC6_STATUS_FILE="$D/status.jsonl" \
      bash "$SCRIPT" --dry-run --json-out="$D/out.json" "$@" > "$D/stdout.txt" 2> "$D/err.txt" ) || echo "EXIT=$?" >> "$D/err.txt"
}

FAKE_AGY_USAGE_MODE=t1_safe run3 c2_tier1
[ "$(sed -n 1p "$D/agy.calls")" = "model=gemini-4-neon-high timeout=10m" ] \
  && [ "$(sed -n 2p "$D/agy.calls")" = "model=gemini-4-neon-medium timeout=8m" ] \
  && [ "$(sed -n 3p "$D/agy.calls")" = "model=gemini-4-neon-medium timeout=8m" ] \
  && ok "c2_tier1: Pass A routes HOT->neon-high(10m) and NORMAL/COLD->neon-medium(8m)" \
  || bad "c2_tier1 calls=$(tr '\n' ';' < "$D/agy.calls")"
[ "$(j '(d["coverage"]["effort"]["mode"], d["coverage"]["effort"].get("pass_a_escalate_hot"), d["coverage"]["effort"]["hot"], d["coverage"]["effort"]["normal"], d["coverage"]["effort"]["cold"], d["coverage"]["effort"]["tiers"])')" = "('adaptive', True, 1, 1, 1, {'1': 'HOT', '2': 'NORMAL', '3': 'COLD'})" ] \
  && ok "c2_tier1: coverage.effort reports adaptive passA_hot=True 1/1/1 tiers" \
  || bad "c2_tier1 effort=$(j 'd["coverage"].get("effort")')"

FAKE_AGY_USAGE_MODE=t1_safe run3 c2_tier2 --tier2
[ "$(sed -n 1p "$D/agy.calls")" = "model=gemini-4-neon-medium timeout=8m" ] \
  && [ "$(sed -n 2p "$D/agy.calls")" = "model=gemini-4-neon-medium timeout=8m" ] \
  && [ "$(sed -n 3p "$D/agy.calls")" = "model=gemini-4-neon-medium timeout=8m" ] \
  && [ "$(sed -n 4p "$D/agy.calls")" = "model=gemini-4-neon-high timeout=10m" ] \
  && [ "$(sed -n 5p "$D/agy.calls")" = "model=gemini-4-neon-high timeout=10m" ] \
  && [ "$(sed -n 6p "$D/agy.calls")" = "model=gemini-4-neon-medium timeout=8m" ] \
  && ok "c2_tier2: agy-only Pass A=med/med/med and Pass B=high/high/med (no duplicate HOT high)" \
  || bad "c2_tier2 calls=$(tr '\n' ';' < "$D/agy.calls")"
[ "$(j 'd["coverage"]["effort"].get("pass_a_escalate_hot")')" = "False" ] \
  && ok "c2_tier2: coverage.effort.pass_a_escalate_hot=False in Tier 2 agy-only" \
  || bad "c2_tier2 effort=$(j 'd["coverage"].get("effort")')"

mkdir -p "$T/bin_claude"
cat > "$T/bin_claude/claude" <<'SH'
#!/usr/bin/env bash
if [ "${1:-}" = --help ]; then
  echo "usage: claude [--json-schema] [--output-format] [--disable-slash-commands] [--no-session-persistence]"; exit 0
fi
cat > /dev/null
echo call >> "$FAKE_DIR/claude.calls"
printf '[{"type":"result","subtype":"success","structured_output":{"summary":"fake B","findings":[]}}]\n'
SH
chmod +x "$T/bin_claude/claude"

TEST_PATH="$T/bin_claude:$ISOPATH" TEST_CLAUDE=1 FAKE_AGY_USAGE_MODE=t1_safe run3 c2_tier2_claude --tier2
[ "$(wc -l < "$D/agy.calls" | tr -d ' ')" = 3 ] \
  && [ "$(sed -n 1p "$D/agy.calls")" = "model=gemini-4-neon-high timeout=10m" ] \
  && [ "$(sed -n 2p "$D/agy.calls")" = "model=gemini-4-neon-medium timeout=8m" ] \
  && [ "$(sed -n 3p "$D/agy.calls")" = "model=gemini-4-neon-medium timeout=8m" ] \
  && [ "$(wc -l < "$D/claude.calls" | tr -d ' ')" = 1 ] \
  && ok "c2_tier2_claude: Tier 2 + claude escalates Pass A HOT->neon-high(10m) and runs Pass B on claude" \
  || bad "c2_tier2_claude agy=$(tr '\n' ';' < "$D/agy.calls") claude=$(wc -l < "$D/claude.calls" | tr -d ' ')"
[ "$(j 'd["coverage"]["effort"].get("pass_a_escalate_hot")')" = "True" ] \
  && ok "c2_tier2_claude: coverage.effort.pass_a_escalate_hot=True" \
  || bad "c2_tier2_claude effort=$(j 'd["coverage"].get("effort")')"

RC6_ADAPTIVE_EFFORT=0 FAKE_AGY_USAGE_MODE=t1_safe run3 c2_fixed --tier2
[ "$(sed -n 1p "$D/agy.calls")" = "model=gemini-4-neon-medium timeout=8m" ] \
  && [ "$(sed -n 2p "$D/agy.calls")" = "model=gemini-4-neon-medium timeout=8m" ] \
  && [ "$(sed -n 3p "$D/agy.calls")" = "model=gemini-4-neon-medium timeout=8m" ] \
  && [ "$(sed -n 4p "$D/agy.calls")" = "model=gemini-4-neon-high timeout=10m" ] \
  && [ "$(sed -n 5p "$D/agy.calls")" = "model=gemini-4-neon-high timeout=10m" ] \
  && [ "$(sed -n 6p "$D/agy.calls")" = "model=gemini-4-neon-high timeout=10m" ] \
  && ok "c2_fixed: RC6_ADAPTIVE_EFFORT=0 keeps legacy uniform models" \
  || bad "c2_fixed calls=$(tr '\n' ';' < "$D/agy.calls")"
[ "$(j 'd["coverage"]["effort"]["mode"]')" = "fixed" ] \
  && ok "c2_fixed: coverage.effort.mode=fixed" || bad "c2_fixed effort=$(j 'd["coverage"].get("effort")')"

RC6_AGY_MODEL=gemini-4-neon-low FAKE_AGY_USAGE_MODE=t1_safe run3 c2_explicit_pin
[ "$(sed -n 1p "$D/agy.calls")" = "model=gemini-4-neon-low timeout=8m" ] \
  && [ "$(sed -n 2p "$D/agy.calls")" = "model=gemini-4-neon-low timeout=8m" ] \
  && [ "$(sed -n 3p "$D/agy.calls")" = "model=gemini-4-neon-low timeout=8m" ] \
  && ok "c2_explicit_pin: explicit RC6_AGY_MODEL disables auto escalation" \
  || bad "c2_explicit_pin calls=$(tr '\n' ';' < "$D/agy.calls")"
[ "$(j 'd["coverage"]["effort"]["mode"]')" = "fixed" ] \
  && ok "c2_explicit_pin: coverage.effort.mode=fixed" || bad "c2_explicit_pin effort=$(j 'd["coverage"].get("effort")')"

echo "== 11. Graph chunking (B1), surgical callees (B2) & related-paths (A5)"
R4="$T/repo4"; mkdir -p "$R4/src" "$R4/.agent/memory"
git -C "$R4" init -q
git -C "$R4" config user.email rc6@fixture.local
git -C "$R4" config user.name  rc6-fixture
printf '# CLAUDE\n\n## Regras Críticas\n- Always validate dose.\n' > "$R4/CLAUDE.md"
printf '# RULES_INDEX\n' > "$R4/.agent/memory/RULES_INDEX.md"
printf '# ANTI_PATTERNS_INDEX\n' > "$R4/.agent/memory/ANTI_PATTERNS_INDEX.md"
cat > "$R4/src/untouched_callee.ts" <<'TS'
export function computeDose(mg: number, factor: number): number {
  if (factor <= 0) return 0;
  return mg * factor;
}
TS
cat > "$R4/src/z_helper.ts" <<'TS'
export function helperMult(x: number): number {
  return x * 2;
}
TS
cat > "$R4/src/a_entry.ts" <<'TS'
import { helperMult } from './z_helper';
export function entry(v: number) { return helperMult(v); }
TS
printf 'export const baseM = 0;\n' > "$R4/src/m_middle.ts"
git -C "$R4" add -A; git -C "$R4" commit -qm base; git -C "$R4" branch -M main
git -C "$R4" checkout -qb feature
cat > "$R4/src/a_entry.ts" <<'TS'
import { helperMult } from './z_helper';
import { computeDose } from './untouched_callee';
export function entry(v: number) {
  return computeDose(helperMult(v), 2);
}
TS
cat > "$R4/src/z_helper.ts" <<'TS'
export function helperMult(x: number): number {
  if (x < 0) return 0;
  return x * 2;
}
TS
python3 -c 'print("\n".join("export const z_pad_%d = \"zzzzzzzzzzzzzzzzzzzz_%d\";" % (i, i) for i in range(120)))' >> "$R4/src/z_helper.ts"
python3 -c 'print("\n".join("export const middle_pad_%d = \"mmmmmmmmmmmmmmmmmmmmmmmmmmmmmm_%d\";" % (i, i) for i in range(210)))' > "$R4/src/m_middle.ts"
git -C "$R4" add -A; git -C "$R4" commit -qm feature

cat > "$T/sel_rel_probe.mjs" <<'JS'
import fs from 'node:fs';
if (process.env.SEL_ARGS_LOG) fs.appendFileSync(process.env.SEL_ARGS_LOG, process.argv.slice(2).join(' ') + '\n');
console.log('## R-911 — Related probe\nBody.');
JS

run4() {
  local name="$1"; shift
  D="$T/$name"; mkdir -p "$D"
  : > "$D/agy.calls"; : > "$D/rel_args.log"
  ( cd "$R4" && PATH="$ISOPATH" FAKE_DIR="$D" SEL_ARGS_LOG="$D/rel_args.log" \
      RC6_MAIN=main RC6_ENGINE_CLAUDE=0 RC6_SKIP_PROBE=1 RC6_AB=0 RC6_REFLECT=0 RC6_JITTER=0 \
      RC6_SELECTOR=1 RC6_SELECTOR_SCRIPT="$T/sel_rel_probe.mjs" \
      RC6_CTX_TOTAL_MAX=36000 RC6_STATUS_FILE="$D/status.jsonl" \
      bash "$SCRIPT" --dry-run --json-out="$D/out.json" "$@" > "$D/stdout.txt" 2> "$D/err.txt" ) || echo "EXIT=$?" >> "$D/err.txt"
}

FAKE_AGY_USAGE_MODE=t1_safe run4 b1_b2_on
if grep -q '+++ b/src/a_entry.ts' "$D/prompt_1.txt" && grep -q '+++ b/src/z_helper.ts' "$D/prompt_1.txt"; then
  ok "b1_cohesion: a_entry.ts and imported z_helper.ts grouped in same chunk despite large m_middle.ts"
else
  bad "b1_cohesion: expected a_entry.ts + z_helper.ts in prompt_1.txt"
fi
if grep -q '===== EXTERNAL CALLEES' "$D/prompt_1.txt" && grep -q 'CALLEE src/untouched_callee.ts#computeDose' "$D/prompt_1.txt" && grep -q 'return mg \* factor;' "$D/prompt_1.txt"; then
  ok "b2_callees: untouched_callee.ts#computeDose sliced into prompt_1.txt"
else
  bad "b2_callees: computeDose callee missing from prompt_1.txt"
fi
if grep -q -- '--related-paths .*src/untouched_callee.ts' "$D/rel_args.log"; then
  ok "a5_related: --related-paths src/untouched_callee.ts propagated to selector"
else
  bad "a5_related: args=$(cat "$D/rel_args.log" 2>/dev/null || true)"
fi

RC6_GRAPH_CHUNK=0 RC6_CALLEES=0 RC6_SELECTOR_RELATED=0 FAKE_AGY_USAGE_MODE=t1_safe run4 b1_b2_off
if grep -q '+++ b/src/a_entry.ts' "$D/prompt_1.txt" && ! grep -q '+++ b/src/z_helper.ts' "$D/prompt_1.txt"; then
  ok "b1_off: RC6_GRAPH_CHUNK=0 restores alphabetical splitting"
else
  bad "b1_off: expected alphabetical split when RC6_GRAPH_CHUNK=0"
fi
if ! grep -q 'EXTERNAL CALLEES' "$D/prompt_1.txt" && ! grep -q -- '--related-paths' "$D/rel_args.log"; then
  ok "b2_a5_off: RC6_CALLEES=0 and RC6_SELECTOR_RELATED=0 disable callee injection and related-paths"
else
  bad "b2_a5_off: disabled flags still emitted callees or related-paths"
fi

echo
echo "rc6-truncation-and-selector: $pass passaram, $fail falharam"
[ "$fail" = 0 ]
