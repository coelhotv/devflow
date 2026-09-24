#!/usr/bin/env bash
# rc6-resilience.test.sh — PO-1, PO-2 e PO-3 da spec 003, sem nenhum LLM.
#
# Um `agy` FALSO segue um ROTEIRO por chamada (FAKE_AGY_SCRIPT="503,503,ok"): cada chamada consome
# um token; esgotado o roteiro, vale FAKE_AGY_DEFAULT. Chamadas no modelo alternativo consomem
# FAKE_AGY_FB (padrao ok). O falso anota em agy.calls o modelo e o chunk ("part N/") de cada
# chamada, que e o que permite afirmar "nao repetiu NA HORA" e "chamou 1 vez so".
#
# O 503 usa o texto REAL do dosiq#835 (tests/fixtures/rc6-resilience/), entregue DENTRO do envelope
# com exit 0 — o formato em que ele de fato chegou (achado E1 do RC3). Fixture inventado com "503"
# no stderr e exit 1 daria teste verde sobre um classificador que nunca dispararia em producao.
#
# Uso:  bash tests/rc6-resilience.test.sh
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

# --- repo-fixture: 4 arquivos grandes -> 4 chunks (orcamento no piso de 30000B) ---
R="$T/repo"; mkdir -p "$R/src" "$R/.agent/memory"
git -C "$R" init -q
git -C "$R" config user.email rc6@fixture.local
git -C "$R" config user.name  rc6-fixture
printf '# RULES_INDEX\n' > "$R/.agent/memory/RULES_INDEX.md"
printf '# ANTI_PATTERNS_INDEX\n' > "$R/.agent/memory/ANTI_PATTERNS_INDEX.md"
for k in 1 2 3 4; do printf 'export const base%s = 0;\n' "$k" > "$R/src/m$k.js"; done
git -C "$R" add -A; git -C "$R" commit -qm base; git -C "$R" branch -M main
git -C "$R" checkout -qb feature
for k in 1 2 3 4; do
  python3 -c 'import sys; k=sys.argv[1]; print("\n".join("export const v%s_%d = %d;" % (k,i,i) for i in range(1600)))' "$k" > "$R/src/m$k.js"
done
git -C "$R" add -A; git -C "$R" commit -qm feature

# run <nome> [--tier2]; env de cenario vem do chamador. stdout/stderr/status separados.
run() {
  local name="$1"; shift
  D="$T/$name"; mkdir -p "$D"
  : > "$D/agy.calls"; : > "$D/claude.calls"
  ( cd "$R" && PATH="$ISOPATH" FAKE_DIR="$D" FAKE_503="$FIX503" \
      RC6_MAIN=main RC6_SELECTOR=0 RC6_SKIP_PROBE=1 RC6_AB=0 RC6_REFLECT=0 \
      RC6_CTX_TOTAL_MAX=40000 RC6_BACKOFF="${RC6_BACKOFF:-0 0}" RC6_JITTER=0 \
      RC6_STATUS_FILE="$D/status.jsonl" \
      bash "$SCRIPT" --dry-run "$@" > "$D/out.json" 2> "$D/err.txt" ) || echo "EXIT=$?" >> "$D/err.txt"
}
j() { python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(eval(sys.argv[2], {"d": d}))' "$D/out.json" "$1" 2>/dev/null || echo "<erro>"; }
calls() { wc -l < "$D/agy.calls" | tr -d ' '; }

echo "== PO-1 — cobertura por passe"
FAKE_AGY_SCRIPT="503,503,503,ok" FAKE_AGY_DEFAULT=503 RC6_RETRIES=0 RC6_AGY_MODEL_FALLBACK="" \
  run po1 --tier2
[ "$(j 'd["coverage"]["partial"]')" = True ] && ok "partial=true com 3/4 chunks falhando no pass A" \
  || bad "partial=$(j 'd["coverage"]["partial"]') (esperado True)"
[ "$(j 'd["coverage"]["chunks_reviewed"] < d["coverage"]["chunks_planned"]')" = True ] \
  && ok "chunks_reviewed < chunks_planned" || bad "chunks_reviewed=$(j 'd["coverage"]["chunks_reviewed"]')"
[ "$(j '(d["coverage"]["per_pass"]["A"]["ok"], d["coverage"]["per_pass"]["A"]["planned"])')" = "(1, 4)" ] \
  && ok "per_pass.A = 1/4" || bad "per_pass.A = $(j 'd["coverage"].get("per_pass")')"
[ "$(j 'sorted(set(f["class"] for f in d["coverage"]["per_pass"]["A"]["failed"])), len(d["coverage"]["per_pass"]["A"]["failed"])')" = "(['transient'], 3)" ] \
  && ok "per_pass.A.failed: 3 chunks, class=transient" || bad "failed = $(j 'd["coverage"]["per_pass"]["A"].get("failed")')"
[ "$(j '(d["coverage"]["independent_reviewers"]["min"], d["coverage"]["independent_reviewers"]["max"])')" = "(1, 2)" ] \
  && ok "independent_reviewers min=1 max=2" || bad "reviewers = $(j 'd["coverage"].get("independent_reviewers")')"

echo "== PO-1 guard — tudo ok, contrato aditivo"
run allok --tier2
[ "$(j '(d["coverage"]["partial"], d["coverage"]["independent_reviewers"]["min"])')" = "(False, 2)" ] \
  && ok "tudo ok: partial=false, reviewers.min=2" || bad "tudo ok: $(j 'd.get("coverage")')"
[ "$(j 'all(k in d["coverage"] for k in ("chunks_reviewed","chunks_planned","partial","not_reviewed"))')" = True ] \
  && ok "campos antigos de coverage presentes" || bad "contrato antigo quebrado: $(j 'list(d.get("coverage",{}))')"

echo "== PO-2 — retry, fallback, classes"
FAKE_AGY_SCRIPT="503,503,ok" RC6_RETRIES=2 run retry
[ "$(j '(d["coverage"]["per_pass"]["A"]["ok"], d["coverage"]["per_pass"]["A"]["retried"])')" = "(4, 1)" ] \
  && ok "503→503→ok: chunk recuperado, retried=1" || bad "503→503→ok: $(j 'd["coverage"].get("per_pass")')"

FAKE_AGY_SCRIPT="503x,ok" RC6_RETRIES=2 run retryx
[ "$(j 'd["coverage"]["per_pass"]["A"]["ok"]')" = 4 ] && ok "mesmo 503 com exit 1 tambem repete" \
  || bad "503x: $(j 'd["coverage"].get("per_pass")')"

FAKE_AGY_SCRIPT="503,503" RC6_RETRIES=1 run fallback
[ "$(j '(d["coverage"]["per_pass"]["A"]["ok"], d["coverage"]["per_pass"]["A"]["model_fallback"])')" = "(4, 1)" ] \
  && ok "503 persistente → ok no modelo alternativo" || bad "fallback: $(j 'd["coverage"].get("per_pass")')"
grep -q 'model=gemini-3.7-flash-medium' "$D/agy.calls" && ok "fallback chamou gemini-3.7-flash-medium" \
  || bad "modelo alternativo nao foi chamado"

FAKE_AGY_SCRIPT="429" RC6_RETRIES=2 run quota
[ "$(grep -c 'chunk=1 ' "$D/agy.calls")" = 1 ] && ok "429: chunk 1 chamado 1 vez so" \
  || bad "429 repetiu: $(grep 'chunk=1 ' "$D/agy.calls" | tr '\n' ';')"
[ "$(j '[f["class"] for f in d["coverage"]["per_pass"]["A"]["failed"]]')" = "['quota']" ] \
  && ok "429 classificado quota" || bad "429: $(j 'd["coverage"]["per_pass"]["A"].get("failed")')"

FAKE_AGY_SCRIPT="fatal" RC6_RETRIES=2 run fatal
[ "$(grep -c 'chunk=1 ' "$D/agy.calls")" = 1 ] && ok "fatal: chunk 1 chamado 1 vez so" \
  || bad "fatal repetiu"

FAKE_AGY_SCRIPT="503,503,503" RC6_RETRIES=2 RC6_AGY_MODEL_FALLBACK="" run breaker
[ "$(j '(d["coverage"]["per_pass"]["A"]["ok"], d["coverage"]["partial"])')" = "(4, False)" ] \
  && ok "3×503 abre o breaker e a segunda rodada recupera" || bad "breaker: $(j 'd.get("coverage")')"
[ "$(sed -n 4p "$D/agy.calls" | grep -o 'chunk=[0-9]*')" = chunk=2 ] \
  && ok "com o breaker aberto o chunk 1 NAO repete na hora (4a chamada = chunk 2)" \
  || bad "ordem pos-breaker: $(tr '\n' ';' < "$D/agy.calls")"
BREAKER_D="$D"

FAKE_AGY_SCRIPT="hang" RC6_RETRIES=2 RC6_AGY_TIMEOUT=1s RC6_HANG_GRACE=0 run timeout
[ "$(sed -n 2p "$D/agy.calls" | grep -o 'chunk=[0-9]*')" = chunk=2 ] \
  && ok "timeout nao repete na hora (2a chamada = chunk 2)" || bad "timeout: $(tr '\n' ';' < "$D/agy.calls")"
[ "$(j 'd["coverage"]["per_pass"]["A"]["ok"]')" = 4 ] && ok "timeout recuperado na segunda rodada" \
  || bad "timeout: $(j 'd["coverage"].get("per_pass")')"

FAKE_AGY_SCRIPT="hang" RC6_RETRIES=2 RC6_AGY_TIMEOUT=1s RC6_HANG_GRACE=0 RC6_RETRY_BUDGET=0 run timeout-nobudget
[ "$(j '[f["class"] for f in d["coverage"]["per_pass"]["A"]["failed"]]')" = "['timeout']" ] \
  && ok "timeout sem orcamento: nao repete, classe timeout" || bad "timeout/budget: $(j 'd["coverage"]["per_pass"]["A"].get("failed")')"

# 2 timeouts adiados, orcamento p/ UMA re-execucao: a 2a rodada tem de parar no 1o (RC5 2026-09-24:
# o orcamento era checado so no adiamento, e a 2a rodada rodava todos os adiados sem descontar).
FAKE_AGY_SCRIPT="hang,hang,ok,ok,hang,ok" RC6_RETRIES=2 RC6_AGY_TIMEOUT=1s RC6_HANG_GRACE=0 RC6_RETRY_BUDGET=1 \
  run timeout-budget2
[ "$(calls)" = 5 ] && ok "2a rodada respeita o orcamento: 5 chamadas, nao 6" || bad "chamadas=$(calls) (esperado 5)"
[ "$(j '[f["chunk"] for f in d["coverage"]["per_pass"]["A"]["failed"]]')" = "[1, 2]" ] \
  && ok "chunks 1 e 2 ficam como falha" || bad "timeout-budget2: $(j 'd["coverage"]["per_pass"]["A"].get("failed")')"

RC6_AGY_TIMEOUT=1h run durh
grep -q 'VERDICT coverage=full' "$D/err.txt" && ok "RC6_AGY_TIMEOUT=1h nao derruba o script" \
  || bad "1h: $(tail -2 "$D/err.txt" | tr '\n' ' ')"

echo "== PO-2 guard — RC6_RETRIES=0 e sem fallback = comportamento de hoje"
FAKE_AGY_SCRIPT="503" RC6_RETRIES=0 RC6_AGY_MODEL_FALLBACK="" run legacy
[ "$(calls)" = 4 ] && ok "1 chamada por chunk (4)" || bad "chamadas=$(calls) (esperado 4)"

echo "== PO-3 — status file, heartbeat, VERDICT"
D="$BREAKER_D"
python3 - "$D/status.jsonl" <<'PY' && ok "status file: toda linha e JSON com pass/chunk/state" || bad "status file invalido"
import json, sys
ls = [json.loads(l) for l in open(sys.argv[1]) if l.strip()]
assert ls and all({"pass","chunk","state"} <= set(l) for l in ls), ls
PY
for s in started retrying breaker_open deferred ok "done"; do
  grep -q "\"state\":\"$s\"" "$D/status.jsonl" && ok "status contem $s" || bad "status sem $s"
done
grep -q "status: $D/status.jsonl" "$D/err.txt" && ok "stderr anuncia o caminho do status file" \
  || bad "caminho do status nao anunciado"
FAKE_AGY_SCRIPT="503,ok" RC6_RETRIES=2 RC6_BACKOFF="1 1" run heartbeat
grep -q 'aguardando 1s' "$D/err.txt" && ok "heartbeat anuncia a espera do backoff" || bad "sem heartbeat"
D="$T/po1"
last="$(grep -v '^EXIT=' "$D/err.txt" | tail -1 | sed 's/\x1b\[[0-9;]*m//g')"
case "$last" in
  *"VERDICT coverage=partial A=1/4 B=4/4 reviewers_min=1"*) ok "VERDICT e a ultima linha e bate com o JSON" ;;
  *) bad "ultima linha do stderr: $last" ;;
esac
python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$D/out.json" 2>/dev/null \
  && ok "stdout segue sendo so o JSON" || bad "stdout nao e JSON puro"

echo
echo "rc6-resilience: $pass passaram, $fail falharam"
[ "$fail" = 0 ]
