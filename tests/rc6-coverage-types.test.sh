#!/usr/bin/env bash
# rc6-coverage-types.test.sh — MP-2026-10-11-RC6, sem nenhum LLM.
#
# 1. Arquivo de RISCO fora dos CODE_GLOBS (.sql/.swift/...) entra na cobertura como NÃO revisado,
#    por tipo, e torna o veredito `partial` (dosiq 098: PR de migração SQL saía coverage=full).
# 2. PR só com arquivo de risco não sai "limpo": coverage zero, partial=true.
# 3. O veredito vai para --json-out e o arquivo é JSON puro, mesmo com stderr no mesmo stream
#    (dosiq 082 D1 e 101 #878 quebraram fazendo parse do stdout misturado).
#
# Uso:  bash tests/rc6-coverage-types.test.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/scripts/ai-review.sh"
FIX503="$ROOT/tests/fixtures/rc6-resilience/agy-503-envelope.json"
T="$(mktemp -d)"
trap '[ -n "${KEEP_T:-}" ] || rm -rf "$T"' EXIT
pass=0; fail=0
ok()   { echo "  ok   $1"; pass=$((pass+1)); }
bad()  { echo "  FALHA  $1"; fail=$((fail+1)); }

# --- PATH isolado: git/python3 + agy/claude falsos; nunca os reais ----------
BIN="$T/bin"; mkdir -p "$BIN"
for b in git python3 bc; do ln -s "$(command -v "$b")" "$BIN/$b"; done
ISOPATH="$BIN:/usr/bin:/bin"

cat > "$T/fake-agy" <<'SH'
#!/usr/bin/env bash
if [ "${1:-}" = --help ]; then
  echo "usage: agy [--sandbox] [--json-schema] [--output-format] [--disable-slash-commands]"; exit 0
fi
model=""; prompt=""; prev=""
for a in "$@"; do
  [ "$prev" = --model ] && model="$a"
  [ "$prev" = -p ] && prompt="$a"
  prev="$a"
done
chunk="$(printf '%s' "$prompt" | grep -oE 'part [0-9]+/' | head -1 | tr -dc '0-9')"
if [ "$model" = "${FAKE_FB_MODEL:-gemini-3.7-flash-medium}" ]; then
  tok="${FAKE_AGY_FB:-ok}"
else
  n="$(cat "$FAKE_DIR/agy.n" 2>/dev/null || echo 0)"; n=$((n+1)); echo "$n" > "$FAKE_DIR/agy.n"
  tok="$(printf '%s,' "${FAKE_AGY_SCRIPT:-}" | cut -s -d, -f"$n")"
  [ -n "$tok" ] || tok="${FAKE_AGY_DEFAULT:-ok}"
fi
echo "model=$model chunk=${chunk:-?} tok=$tok" >> "$FAKE_DIR/agy.calls"
case "$tok" in
  ok)    printf '{"status":"SUCCESS","structured_output":{"summary":"fake A","findings":[]}}\n' ;;
  503)   cat "$FAKE_503" ;;                                    # envelope FAILED, exit 0 (formato real)
  503x)  cat "$FAKE_503"; exit 1 ;;                            # mesmo envelope, exit 1
  429)   echo "API error: RESOURCE_EXHAUSTED (code 429): quota exceeded" >&2; exit 1 ;;
  fatal) echo "error: unknown flag --bogus" >&2; exit 2 ;;
  hang)  sleep 30 ;;
esac
SH
cat > "$T/fake-claude" <<'SH'
#!/usr/bin/env bash
if [ "${1:-}" = --help ]; then
  echo "usage: claude [--json-schema] [--output-format] [--disable-slash-commands] [--no-session-persistence]"; exit 0
fi
cat > /dev/null
echo call >> "$FAKE_DIR/claude.calls"
case "${FAKE_CLAUDE:-ok}" in
  ok)   printf '[{"type":"result","subtype":"success","structured_output":{"summary":"fake B","findings":[]}}]\n' ;;
  fail) echo "claude down" >&2; exit 1 ;;
esac
SH
chmod +x "$T/fake-agy" "$T/fake-claude"
ln -s "$T/fake-agy" "$BIN/agy"
ln -s "$T/fake-claude" "$BIN/claude"

# --- repo: base com 1 js; feature muda o js e adiciona 1 .sql e 1 .swift --------
mkrepo() {
  R="$T/$1"; mkdir -p "$R/src" "$R/.agent/memory"
  git -C "$R" init -q
  git -C "$R" config user.email rc6@fixture.local
  git -C "$R" config user.name  rc6-fixture
  printf '# RULES_INDEX\n' > "$R/.agent/memory/RULES_INDEX.md"
  printf '# ANTI_PATTERNS_INDEX\n' > "$R/.agent/memory/ANTI_PATTERNS_INDEX.md"
  printf 'export const a = 0;\n' > "$R/src/a.js"
  git -C "$R" add -A; git -C "$R" commit -qm base; git -C "$R" branch -M main
  git -C "$R" checkout -qb feature
}
run() {
  local name="$1"; shift
  D="$T/out-$name"; mkdir -p "$D"; : > "$D/agy.calls"; : > "$D/claude.calls"
  ( cd "$R" && PATH="$ISOPATH" FAKE_DIR="$D" FAKE_503="$FIX503" \
      RC6_MAIN=main RC6_SELECTOR=0 RC6_SKIP_PROBE=1 RC6_AB=0 RC6_REFLECT=0 RC6_JITTER=0 \
      RC6_STATUS_FILE="$D/status.jsonl" \
      bash "$SCRIPT" --dry-run --json-out="$D/verdict.json" "$@" > "$D/mixed.txt" 2>&1 ) || echo "EXIT=$?" >> "$D/mixed.txt"
}
j() { python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(eval(sys.argv[2], {"d": d}))' "$D/verdict.json" "$1" 2>/dev/null || echo "<erro>"; }

echo "== código + arquivos de risco fora dos globs"
mkrepo mixed
printf 'export const a = 1;\nexport const b = 2;\n' > "$R/src/a.js"
printf 'alter table t add column c int;\n' > "$R/m.sql"
printf 'let x = 1\n' > "$R/B.swift"
git -C "$R" add -A; git -C "$R" commit -qm feature
run mixed
[ -s "$D/verdict.json" ] && ok "--json-out gravado" || bad "--json-out ausente"
python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$D/verdict.json" 2>/dev/null \
  && ok "arquivo é JSON puro (stdout+stderr misturados não importam)" || bad "verdict.json não é JSON"
[ "$(j 'd["coverage"]["partial"]')" = True ] && ok "partial=true por tipo não revisado" \
  || bad "partial=$(j 'd["coverage"]["partial"]')"
[ "$(j 'sorted(d["coverage"]["not_reviewed_by_type"].items())')" = "[('sql', 1), ('swift', 1)]" ] \
  && ok "not_reviewed_by_type = sql:1, swift:1" || bad "by_type=$(j 'd["coverage"].get("not_reviewed_by_type")')"
[ "$(j 'd["coverage"]["chunks_reviewed"] == d["coverage"]["chunks_planned"]')" = True ] \
  && ok "chunks de código todos revisados (o parcial vem só do tipo)" || bad "chunks: $(j 'd["coverage"]')"
[ "$(j 'sorted(x["reason"] for x in d["coverage"]["not_reviewed_detail"])')" = "['type_not_reviewed', 'type_not_reviewed']" ] \
  && ok "detail com reason=type_not_reviewed" || bad "detail=$(j 'd["coverage"].get("not_reviewed_detail")')"

echo "== só código: segue full"
mkrepo jsonly
printf 'export const a = 1;\n' > "$R/src/a.js"
git -C "$R" add -A; git -C "$R" commit -qm feature
run jsonly
[ "$(j '(d["coverage"]["partial"], d["coverage"]["not_reviewed_by_type"])')" = "(False, {})" ] \
  && ok "sem arquivo de risco: partial=false, by_type vazio" || bad "jsonly: $(j 'd["coverage"]')"

echo "== só SQL: não é 'limpo'"
mkrepo sqlonly
printf 'drop table t;\n' > "$R/m.sql"
git -C "$R" add -A; git -C "$R" commit -qm feature
run sqlonly
[ "$(j '(d["coverage"]["partial"], d["coverage"]["chunks_reviewed"], d["coverage"]["not_reviewed_by_type"])')" = "(True, 0, {'sql': 1})" ] \
  && ok "só .sql: partial=true, 0 chunks, sql:1" || bad "sqlonly: $(j 'd.get("coverage")')"
[ "$(wc -l < "$D/agy.calls" | tr -d ' ')" = 0 ] && ok "nenhum motor chamado" || bad "motor chamado sem código"

echo
echo "rc6-coverage-types: $pass passaram, $fail falharam"
[ "$fail" = 0 ]
