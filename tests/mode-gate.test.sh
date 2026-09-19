#!/usr/bin/env bash
# mode-gate.test.sh — spec 001 slice A, fecha PO-1 e PO-2.
#
#   bash tests/mode-gate.test.sh              casos de decisão (PO-1)
#   bash tests/mode-gate.test.sh --degraded   casos degradados: nenhum pode bloquear (PO-2)

set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

GATE="./scripts/mode-gate.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
PASS=0; FAIL=0

ok_field() { printf '%s' "$1" | python3 -c 'import json,sys; print(str(json.load(sys.stdin)["ok"]).lower())' 2>/dev/null; }

check() { # $1=nome  $2=esperado(true|false)  $3=saida
  local got; got="$(ok_field "$3")"
  if [ "$got" = "$2" ]; then
    PASS=$((PASS+1)); printf '  ok   %s\n' "$1"
  else
    FAIL=$((FAIL+1)); printf '  FAIL %s — esperado ok=%s, veio ok=%s\n       %s\n' "$1" "$2" "${got:-<vazio>}" "$3"
  fi
}

mk_state() { # $1=arquivo  $2=mode  $3=spec_dir  $4=loaded(1|0)
  local gates='"quality_gates": {"index_loaded_at": "2026-09-19T10:00:00Z"}'
  [ "$4" = "0" ] && gates='"quality_gates": {}'
  cat > "$1" <<JSON
{"project": "t", $gates,
 "session": {"mode": "$2", "status": "$2", "spec_dir": "$3"}}
JSON
}

if [ "${1:-}" = "--degraded" ]; then
  echo "PO-2 — degradados nunca bloqueiam:"

  check "state.json ausente" true "$($GATE --state "$TMP/nao-existe.json" --skill devflow-code)"

  printf 'isto nao e json {{{' > "$TMP/bad.json"
  check "JSON malformado" true "$($GATE --state "$TMP/bad.json" --skill devflow-code)"

  printf '{"session":{"mode":"coding","campo_desconhecido":42},"quality_gates":{"index_loaded_at":"x"}}' > "$TMP/unknown.json"
  check "campo desconhecido" true "$($GATE --state "$TMP/unknown.json" --skill devflow-code)"

  printf '' > "$TMP/empty.json"
  check "state vazio" true "$($GATE --state "$TMP/empty.json" --skill devflow-code)"

  printf '[1,2,3]' > "$TMP/arr.json"
  check "JSON que nao e objeto" true "$($GATE --state "$TMP/arr.json" --skill devflow-code)"

  mk_state "$TMP/ok.json" coding "" 1
  check "skill desconhecida" true "$($GATE --state "$TMP/ok.json" --skill devflow-inexistente)"

  mk_state "$TMP/ok2.json" coding "" 1
  check "kill switch MODE_GATE=0" true "$(MODE_GATE=0 $GATE --state "$TMP/ok2.json" --skill devflow-spec --to specifying)"
else
  echo "PO-1 — decisões:"

  mk_state "$TMP/happy.json" coding "" 1
  check "caso feliz: coding + devflow-code" true "$($GATE --state "$TMP/happy.json" --skill devflow-code --to coding)"

  mk_state "$TMP/nb.json" coding "" 0
  check "violação: bootstrap não rodou" false "$($GATE --state "$TMP/nb.json" --skill devflow-code --to coding)"

  mk_state "$TMP/mm.json" coding "" 1
  check "violação: skill não cobre o modo alvo" false "$($GATE --state "$TMP/mm.json" --skill devflow-spec --to coding)"

  mk_state "$TMP/mm2.json" coding "" 1
  check "violação: skill incoerente com o modo corrente (sem --to)" false "$($GATE --state "$TMP/mm2.json" --skill devflow-spec)"

  mk_state "$TMP/tr.json" coding "" 1
  check "transição legítima concedida pelo operador (coding → specifying)" true "$($GATE --state "$TMP/tr.json" --skill devflow-spec --to specifying)"

  mk_state "$TMP/sd.json" planning "plans/specs/nao-existe" 1
  check "violação: spec_dir inexistente" false "$($GATE --state "$TMP/sd.json" --skill devflow-plan --to planning)"

  SPEC="$TMP/spec"; mkdir -p "$SPEC"
  printf 'ac: x\nstatus: [ ] open\n' > "$SPEC/spec.md"
  mk_state "$TMP/po.json" coding "$SPEC" 1
  check "violação: PO aberta em coding" false "$($GATE --state "$TMP/po.json" --skill devflow-code --to coding)"

  printf 'ac: x\nstatus: [x] done\n' > "$SPEC/spec.md"
  check "PO fechada: passa" true "$($GATE --state "$TMP/po.json" --skill devflow-code --to coding)"

  mk_state "$TMP/core.json" distillation "" 1
  check "núcleo /devflow opera em qualquer modo" true "$($GATE --state "$TMP/core.json" --skill devflow --to distillation)"

  check "stdin em vez de --state" true "$(cat "$TMP/happy.json" | $GATE --skill devflow-code --to coding)"
fi

printf '\n%d passaram, %d falharam\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
