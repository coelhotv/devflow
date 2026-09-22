#!/usr/bin/env bash
# second-opinion.test.sh — PO-16, PO-17 e PO-19 da spec 001 (slice F2), sem nenhum LLM.
#
# Um `agy` FALSO no PATH devolve envelope enlatado e grava o prompt que recebeu. Isso exercita
# o caminho inteiro — probe, argv, run_engine, unwrap_structured, validacao de schema,
# cabecalho — de forma deterministica. Chamar o motor real aqui repetiria o defeito que a nota
# de metodo da PO-14 desqualificou: saida de LLM nao e prova reproduzivel.
#
# Uso:  bash tests/second-opinion.test.sh                  # tudo
#       bash tests/second-opinion.test.sh --egress --failopen   # so o que a PO-17 pede
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SO="$ROOT/scripts/second-opinion.sh"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
pass=0; fail=0
ok()   { echo "  ok   $1"; pass=$((pass+1)); }
bad()  { echo "  FALHA  $1"; fail=$((fail+1)); }

WANT_ALL=1; WANT_EGRESS=0; WANT_FAILOPEN=0
for a in "$@"; do
  case "$a" in
    --egress)   WANT_ALL=0; WANT_EGRESS=1 ;;
    --failopen) WANT_ALL=0; WANT_FAILOPEN=1 ;;
    *) echo "uso: second-opinion.test.sh [--egress] [--failopen]" >&2; exit 2 ;;
  esac
done

# --- PATH isolado: python3 + um agy/gh falsos; nunca os reais ---------------
BIN="$T/bin"; mkdir -p "$BIN"
ln -s "$(command -v python3)" "$BIN/python3"
ISOPATH="$BIN:/usr/bin:/bin"

cat > "$T/fake-agy" <<'SH'
#!/usr/bin/env bash
if [ "${1:-}" = --help ]; then echo "usage: agy [--json-schema] [--output-format] [--disable-slash-commands]"; exit 0; fi
prev=""; for a in "$@"; do [ "$prev" = -p ] && printf '%s' "$a" > "$FAKE_DIR/prompt.txt"; prev="$a"; done
echo call >> "$FAKE_DIR/agy.calls"
case "${FAKE_AGY_MODE:-ok}" in
  ok)      printf '{"status":"SUCCESS","structured_output":{"summary":"fake","findings":[{"section":"Plan","quote":"T060","severity":"medium","kind":"gap","issue":"x","suggestion":"y"}]}}\n' ;;
  offschema) printf '{"status":"SUCCESS","structured_output":{"summary":"fake","findings":[{"section":"Plan","severity":"urgent"}]}}\n' ;;
  fail)    echo "quota exhausted" >&2; exit 1 ;;
esac
SH
cat > "$T/fake-gh" <<'SH'
#!/usr/bin/env bash
echo "gh $*" >> "$FAKE_DIR/gh.calls"; exit 1
SH
chmod +x "$T/fake-agy" "$T/fake-gh"
ln -s "$T/fake-gh" "$BIN/gh"

# --- fixture de spec-dir --------------------------------------------------------
SD="$T/specs/999-fixture"; mkdir -p "$SD"
printf '# 999 — fixture\n\n## Non-Goals\n1. nada\n2. nada mais\n\nMARCA-SPEC\n' > "$SD/spec.md"
printf '# plano\n\nMARCA-PLAN — T060 escreve o script\n' > "$SD/plan.md"
printf '# tasks\n\n- [ ] T060\n' > "$SD/tasks.md"
printf '# analysis\n\nMARCA-ANALYSIS\n' > "$SD/analysis-F.md"

run() { # env via chamador; stdout -> $T/out.json, stderr -> $T/err.txt, exit -> $RC
  RC=0
  PATH="$ISOPATH" FAKE_DIR="$T" "$@" > "$T/out.json" 2> "$T/err.txt" || RC=$?
}
reset() { rm -f "$T/agy.calls" "$T/gh.calls" "$T/prompt.txt" "$BIN/agy"; }
jq_py() { python3 -c "import json,sys; d=json.load(open('$T/out.json')); print($1)"; }

if [ "$WANT_ALL" = 1 ]; then
  echo "== PO-16: plan em processo frio -> JSON no schema, nenhum caminho de PR"
  reset; ln -s "$T/fake-agy" "$BIN/agy"
  run bash "$SO" --artifact plan --spec-dir "$SD"
  [ "$RC" = 0 ] && ok "exit 0" || bad "exit $RC ($(head -c 200 "$T/err.txt"))"
  [ "$(jq_py 'd["artifact"]')" = plan ] && ok "artifact=plan" || bad "artifact errado"
  [ "$(jq_py 'd["findings"][0]["kind"]')" = gap ] && ok "findings no schema atravessaram" || bad "findings perdidos"
  [ ! -f "$T/gh.calls" ] && ok "gh nunca chamado (sem caminho de PR)" || bad "gh chamado: $(cat "$T/gh.calls")"
  grep -q 'MARCA-PLAN' "$T/prompt.txt" && grep -q 'ARTIFACT UNDER REVIEW: plan.md' "$T/prompt.txt" \
    && ok "prompt julga o plan.md" || bad "plan.md nao e o alvo do prompt"
  grep -q 'REFERENCE (do NOT review; use only to confront): spec.md' "$T/prompt.txt" \
    && ok "spec.md entra so como referencia" || bad "spec.md fora do papel de referencia"

  echo "== PO-19: analysis -> findings, contexto frio no cabecalho"
  reset; ln -s "$T/fake-agy" "$BIN/agy"
  run bash "$SO" --artifact analysis --spec-dir "$SD" --file "$SD/analysis-F.md"
  [ "$RC" = 0 ] && [ "$(jq_py 'd["artifact"]')" = analysis ] && ok "artifact=analysis" || bad "analysis falhou (rc=$RC)"
  [ "$(jq_py 'd["context"]')" = cold ] && ok "cabecalho declara context=cold" || bad "sem context=cold"
  grep -q 'NO access to the conversation' "$T/prompt.txt" && ok "prompt afirma a independencia" || bad "prompt sem a clausula de independencia"
  run bash "$SO" --artifact analysis --spec-dir "$SD"
  [ "$RC" = 2 ] && ok "analysis sem --file = erro de uso (exit 2), nao fail-open" || bad "analysis sem --file deu rc=$RC"

  echo "== --measure: para ANTES do motor"
  reset; ln -s "$T/fake-agy" "$BIN/agy"
  run bash "$SO" --artifact spec --spec-dir "$SD" --measure
  [ "$RC" = 0 ] && [ "$(jq_py 'd["measure"]')" = True ] && ok "measure devolve contabilidade" || bad "measure rc=$RC"
  [ ! -f "$T/agy.calls" ] && ok "nenhuma chamada de motor no measure" || bad "measure chamou o motor"

  echo "== motor fora do schema nao vira opiniao valida"
  reset; ln -s "$T/fake-agy" "$BIN/agy"
  FAKE_AGY_MODE=offschema run bash "$SO" --artifact spec --spec-dir "$SD"
  grep -q 'unavailable' "$T/out.json" && ok "offschema -> fail-open, nao findings capengas" || bad "offschema aceito: $(cat "$T/out.json")"
fi

if [ "$WANT_ALL" = 1 ] || [ "$WANT_EGRESS" = 1 ]; then
  echo "== PO-17: egress guard vem do core"
  SDP="$T/specs/998-pii"; mkdir -p "$SDP"
  printf '# spec\n\npaciente: maria.souza@gmail.com\n' > "$SDP/spec.md"
  reset; ln -s "$T/fake-agy" "$BIN/agy"
  run bash "$SO" --artifact spec --spec-dir "$SDP"
  [ "$RC" = 3 ] && ok "PII no artefato -> exit 3" || bad "egress nao bloqueou (rc=$RC)"
  grep -q 'no artefato' "$T/err.txt" && ok "mensagem do modo artefato" || bad "mensagem errada: $(head -1 "$T/err.txt")"
  [ ! -f "$T/agy.calls" ] && ok "nada saiu para o motor" || bad "motor chamado apesar do egress"
  RC6_ALLOW_SENSITIVE=1 run bash "$SO" --artifact spec --spec-dir "$SDP" --measure
  [ "$RC" = 0 ] && ok "override RC6_ALLOW_SENSITIVE=1 e o mesmo do RC6" || bad "override ignorado (rc=$RC)"
  if grep -qE 'grep -oEc|9\[0-9\]\{4\}' "$SO"; then bad "second-opinion.sh tem COPIA LOCAL do regex de egress"
  else ok "nenhuma copia local do regex de egress"; fi
fi

if [ "$WANT_ALL" = 1 ] || [ "$WANT_FAILOPEN" = 1 ]; then
  echo "== PO-17: fail-open vem do core"
  reset   # sem agy nem claude no PATH
  run bash "$SO" --artifact spec --spec-dir "$SD"
  [ "$RC" = 0 ] && ok "nenhum motor -> exit 0" || bad "fail-open saiu com rc=$RC"
  python3 -c "import json;d=json.load(open('$T/out.json'));assert d['findings']==[] and 'unavailable' in d['summary']" 2>/dev/null \
    && ok "JSON de indisponivel valido" || bad "saida de fail-open invalida: $(cat "$T/out.json")"
  reset; ln -s "$T/fake-agy" "$BIN/agy"
  FAKE_AGY_MODE=fail run bash "$SO" --artifact spec --spec-dir "$SD"
  [ "$RC" = 0 ] && grep -q 'unavailable' "$T/out.json" && ok "motor que falha -> fail-open" || bad "motor falhando rc=$RC"
  grep -q 'quota exhausted' "$T/err.txt" && ok "log diz POR QUE caiu (engine_err_hint)" || bad "motivo da queda sumiu do log"
  if grep -qE "echo '\{\"summary\"" "$SO"; then bad "second-opinion.sh tem COPIA LOCAL do JSON de fail-open"
  else ok "nenhuma copia local do fail-open"; fi
fi

echo
echo "$pass passaram, $fail falharam"
[ "$fail" = 0 ]
