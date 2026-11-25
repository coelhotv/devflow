#!/usr/bin/env bash
# rc6-executive-and-tests.test.sh — Offline suite for executive_summary,
# mechanical test_coverage_alert, and Pass B optional spec injection.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/scripts/ai-review.sh"
T="$(mktemp -d)"
trap '[ -n "${KEEP_T:-}" ] || rm -rf "$T"' EXIT

pass=0; fail=0
ok()  { echo "  ok   $1"; pass=$((pass+1)); }
bad() { echo "  FAIL $1"; fail=$((fail+1)); }

BIN="$T/bin"; mkdir -p "$BIN"
for b in git python3 bc; do ln -s "$(command -v "$b")" "$BIN/$b"; done
ISOPATH="$BIN:/usr/bin:/bin"

cat > "$T/default-agy.json" <<'JSON'
{"status":"SUCCESS","structured_output":{"summary":"fake A","findings":[]}}
JSON
cat > "$T/default-claude.json" <<'JSON'
[{"type":"result","subtype":"success","structured_output":{"summary":"fake B","findings":[]}}]
JSON

cat > "$T/fake-agy" <<'SH'
#!/usr/bin/env bash
if [ "${1:-}" = --help ]; then
  echo "usage: agy [--sandbox] [--json-schema] [--output-format] [--disable-slash-commands]"; exit 0
fi
prompt=""; prev=""
for a in "$@"; do
  [ "$prev" = -p ] && prompt="$a"
  prev="$a"
done
[ -n "${FAKE_LOG_DIR:-}" ] && printf '%s' "$prompt" > "$FAKE_LOG_DIR/promptA.txt"
cat "${FAKE_AGY_FILE}"
SH

cat > "$T/fake-claude" <<'SH'
#!/usr/bin/env bash
if [ "${1:-}" = --help ]; then
  echo "usage: claude [--json-schema] [--output-format] [--disable-slash-commands] [--no-session-persistence]"; exit 0
fi
prompt="$(cat)"
[ -n "${FAKE_LOG_DIR:-}" ] && printf '%s' "$prompt" > "$FAKE_LOG_DIR/promptB.txt"
cat "${FAKE_CLAUDE_FILE}"
SH

cat > "$T/fake-gh" <<'SH'
#!/usr/bin/env bash
if [ "${1:-}" = "pr" ] && [ "${2:-}" = "view" ]; then
  echo "deadbeefdeadbeefdeadbeefdeadbeefdeadbeef"
  exit 0
fi
if [ "${1:-}" = "api" ]; then
  cat > "${FAKE_LOG_DIR:-/tmp}/gh_payload.json"
  echo '{"id":1}'
  exit 0
fi
exit 0
SH

chmod +x "$T/fake-agy" "$T/fake-claude" "$T/fake-gh"
ln -s "$T/fake-agy" "$BIN/agy"
ln -s "$T/fake-claude" "$BIN/claude"
ln -s "$T/fake-gh" "$BIN/gh"

mkrepo() {
  local name="$1" with_test="$2"
  local R="$T/$name"
  mkdir -p "$R/src/services" "$R/.agent/memory"
  git -C "$R" init -q
  git -C "$R" config user.email rc6@fixture.local
  git -C "$R" config user.name rc6-fixture
  printf '# RULES_INDEX\n' > "$R/.agent/memory/RULES_INDEX.md"
  printf '# ANTI_PATTERNS_INDEX\n' > "$R/.agent/memory/ANTI_PATTERNS_INDEX.md"
  printf 'export const calc = (x: number) => x;\n' > "$R/src/services/dose.ts"
  git -C "$R" add -A
  git -C "$R" commit -qm "base"
  git -C "$R" branch -M main
  git -C "$R" checkout -qb feat/test
  printf 'export const calc = (x: number) => x * 2;\n' > "$R/src/services/dose.ts"
  if [ "$with_test" = 1 ]; then
    printf 'test("calc", () => expect(2).toBe(2));\n' > "$R/src/services/dose.test.ts"
  fi
  git -C "$R" add -A
  git -C "$R" commit -qm "feat"
}

echo "[1/5] Tier 2 Pass B executive_summary precedence + --post render + test_coverage_alert"
mkrepo repo1 0
L1="$T/log1"; mkdir -p "$L1"
OUT1="$T/out1.json"
cat > "$T/agy1.json" <<'JSON'
{"status":"SUCCESS","structured_output":{"summary":"pass A","executive_summary":{"user_impact":"Impact A","product_risk":"low","risk_reason":"minor","verdict":"approve","manual_qa":[]},"findings":[]}}
JSON
cat > "$T/claude1.json" <<'JSON'
[{"type":"result","subtype":"success","structured_output":{"summary":"pass B","executive_summary":{"user_impact":"Altera calculo de dose.","product_risk":"high","risk_reason":"Regra critica sem teste","verdict":"approve_with_qa","manual_qa":["Validar dose de UI para mL"]},"findings":[]}}]
JSON
(
  cd "$T/repo1"
  PATH="$ISOPATH" FAKE_LOG_DIR="$L1" FAKE_AGY_FILE="$T/agy1.json" FAKE_CLAUDE_FILE="$T/claude1.json" \
    RC6_MAIN=main RC6_SELECTOR=0 RC6_REFLECT=0 RC6_AB=0 RC6_JITTER=0 \
    bash "$SCRIPT" 999 --tier2 --post --json-out="$OUT1" >/dev/null 2>&1
)
python3 - "$OUT1" "$L1/gh_payload.json" <<'PY' && ok "Tier 2 executive_summary + PR body + test_coverage_alert" || bad "Tier 2 executive_summary + PR body + test_coverage_alert"
import json, sys
m = json.load(open(sys.argv[1]))
p = json.load(open(sys.argv[2]))
es = m.get("executive_summary") or {}
assert es.get("verdict") == "approve_with_qa", es
assert es.get("product_risk") == "high", es
assert es.get("user_impact") == "Altera calculo de dose.", es
tca = m.get("test_coverage_alert") or {}
assert tca.get("total_critical") == 1, tca
assert "src/services/dose.ts" in tca.get("critical_files_without_tests", []), tca
body = p.get("body", "")
assert "### Resumo Executivo (Produto & Risco)" in body, body
assert "Aprovar com QA manual" in body, body
assert "Validar dose de UI para mL" in body, body
assert "Alerta de testes:" in body, body
PY

echo "[2/5] Tier 1 Pass A executive_summary consolidation + no test_coverage_alert when test changed"
mkrepo repo2 1
L2="$T/log2"; mkdir -p "$L2"
OUT2="$T/out2.json"
cat > "$T/agy2.json" <<'JSON'
{"status":"SUCCESS","structured_output":{"summary":"pass A1","executive_summary":{"user_impact":"Muda regra de dose","product_risk":"medium","risk_reason":"Edge case","verdict":"block","manual_qa":["Testar dose zero"]},"findings":[]}}
JSON
(
  cd "$T/repo2"
  PATH="$ISOPATH" FAKE_LOG_DIR="$L2" FAKE_AGY_FILE="$T/agy2.json" FAKE_CLAUDE_FILE="$T/default-claude.json" \
    RC6_MAIN=main RC6_SELECTOR=0 RC6_REFLECT=0 RC6_AB=0 RC6_JITTER=0 \
    bash "$SCRIPT" --tier1 --dry-run --json-out="$OUT2" >/dev/null 2>&1
)
python3 - "$OUT2" <<'PY' && ok "Tier 1 executive_summary + no alert when test present" || bad "Tier 1 executive_summary + no alert when test present"
import json, sys
m = json.load(open(sys.argv[1]))
es = m.get("executive_summary") or {}
assert es.get("verdict") == "block", es
assert es.get("product_risk") == "medium", es
assert "test_coverage_alert" not in m, m
PY

echo "[3/5] Backward compatibility when executive_summary omitted"
L3="$T/log3"; mkdir -p "$L3"
OUT3="$T/out3.json"
(
  cd "$T/repo2"
  PATH="$ISOPATH" FAKE_LOG_DIR="$L3" FAKE_AGY_FILE="$T/default-agy.json" FAKE_CLAUDE_FILE="$T/default-claude.json" \
    RC6_MAIN=main RC6_SELECTOR=0 RC6_REFLECT=0 RC6_AB=0 RC6_JITTER=0 \
    bash "$SCRIPT" 999 --tier2 --post --json-out="$OUT3" >/dev/null 2>&1
)
python3 - "$OUT3" "$L3/gh_payload.json" <<'PY' && ok "Backward compat without executive_summary" || bad "Backward compat without executive_summary"
import json, sys
m = json.load(open(sys.argv[1]))
p = json.load(open(sys.argv[2]))
assert "executive_summary" not in m, m
assert "### Resumo Executivo" not in p.get("body", ""), p.get("body", "")
PY

echo "[4/5] Optional RC6_SPEC_FILE injected into Pass B (capped 3000B) and NOT Pass A"
L4="$T/log4"; mkdir -p "$L4"
OUT4="$T/out4.json"
SPEC4="$T/spec.md"
python3 -c 'print("AC-1: Must preserve precision.\n" + ("X" * 4000))' > "$SPEC4"
(
  cd "$T/repo2"
  PATH="$ISOPATH" FAKE_LOG_DIR="$L4" FAKE_AGY_FILE="$T/default-agy.json" FAKE_CLAUDE_FILE="$T/default-claude.json" \
    RC6_SPEC_FILE="$SPEC4" RC6_MAIN=main RC6_SELECTOR=0 RC6_REFLECT=0 RC6_AB=0 RC6_JITTER=0 \
    bash "$SCRIPT" --tier2 --dry-run --json-out="$OUT4" >/dev/null 2>&1
)
python3 - "$L4/promptA.txt" "$L4/promptB.txt" <<'PY' && ok "Spec injected only in Pass B and capped <=3000B" || bad "Spec injected only in Pass B and capped <=3000B"
import sys
pa = open(sys.argv[1]).read()
pb = open(sys.argv[2]).read()
assert "SPEC / ACCEPTANCE CRITERIA" not in pa
assert "SPEC / ACCEPTANCE CRITERIA" in pb
sec = pb.split("===== SPEC / ACCEPTANCE CRITERIA (reference) =====")[-1]
assert "AC-1: Must preserve precision." in sec
assert len(sec.encode("utf-8")) <= 3010, len(sec)
PY

echo "[5/5] Missing RC6_SPEC_FILE fails open"
L5="$T/log5"; mkdir -p "$L5"
OUT5="$T/out5.json"
(
  cd "$T/repo2"
  PATH="$ISOPATH" FAKE_LOG_DIR="$L5" FAKE_AGY_FILE="$T/default-agy.json" FAKE_CLAUDE_FILE="$T/default-claude.json" \
    RC6_SPEC_FILE="$T/does-not-exist.md" RC6_MAIN=main RC6_SELECTOR=0 RC6_REFLECT=0 RC6_AB=0 RC6_JITTER=0 \
    bash "$SCRIPT" --tier2 --dry-run --json-out="$OUT5" >/dev/null 2>&1
) && ok "Missing RC6_SPEC_FILE fails open" || bad "Missing RC6_SPEC_FILE fails open"

echo ""
echo "Summary: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
