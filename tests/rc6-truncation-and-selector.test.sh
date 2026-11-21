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

echo
echo "rc6-truncation-and-selector: $pass passaram, $fail falharam"
[ "$fail" = 0 ]
