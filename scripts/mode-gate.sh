#!/usr/bin/env bash
# mode-gate.sh — gate determinístico de controle de modo do DEVFLOW (spec 001, slice A).
#
# Verifica, sem LLM e sem quota, o que hoje só existe como prosa nas skills:
#   1. bootstrap  — o state.json foi lido nesta sessão (quality_gates.index_loaded_at)
#   2. coerência  — session.mode bate com a skill que o operador carregou
#   3. POs        — não há Proof Obligation `[ ] open` ao sair de coding/reviewing
#   4. artefato   — session.spec_dir existe no disco quando declarado
#
# Uso:
#   ./scripts/mode-gate.sh --state .agent/state.json --skill devflow-code --to coding
#   cat .agent/state.json | ./scripts/mode-gate.sh --skill devflow-plan --to planning
#
#   MODE_GATE=0   desliga (passthrough puro: sempre ok=true)
#
# ⚠️ O INVARIANTE. `ok:false` exige VIOLAÇÃO POSITIVA: a checagem rodou, respondeu, e a
# resposta contradiz a transição pedida. Qualquer outro desfecho — state.json ausente,
# JSON malformado, campo desconhecido, python3 indisponível, spec ilegível — resulta em
# `ok:true` com uma MARCA em `marks[]`. O modo de falha inaceitável deste gate não é
# deixar passar uma transição irregular (o operador ainda a vê no relatório); é bloquear
# trabalho legítimo com o carimbo de um gate que não conseguiu decidir. A assimetria é o
# produto — mesma regra do reflect-gate.sh (RC6/058).
#
# Três níveis de acoplamento (FR-003 — a portabilidade é o contrato):
#   1. CLI / CI        este script, invocado direto          ← o contrato; roda em qualquer shell
#   2. git hook local  pre-commit / post-checkout            ← portátil; invoca o nível 1
#   3. hook do cliente settings.json do Claude Code          ← açúcar opcional; SÓ invoca o nível 1
# O comportamento NUNCA pode depender do nível 3. Remover o hook não muda resultado algum —
# é o que `tests/mode-gate.test.sh` prova rodando sem nenhum hook instalado.
#
# Saída (stdout, sempre JSON):
#   {"ok":true|false,"reason":"…"|null,"marks":["DEGRADED:…"],"checks":{…}}
# Exit code: 0 sempre que ok=true (inclusive degradado); 1 apenas em violação positiva.

set -uo pipefail

STATE_PATH=""
SKILL=""
TO_MODE=""
STDIN_JSON=""

while [ $# -gt 0 ]; do
  case "$1" in
    --state) STATE_PATH="${2:-}"; shift 2 ;;
    --skill) SKILL="${2:-}"; shift 2 ;;
    --to)    TO_MODE="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,28p' "$0"; exit 0 ;;
    *) shift ;;
  esac
done

emit() { # $1=ok  $2=reason(or empty)  $3=marks csv  $4=checks json
  local ok="$1" reason="$2" marks="$3" checks="${4:-{\}}"
  local marks_json="[]" reason_json="null"
  if [ -n "$marks" ]; then
    marks_json="[$(printf '%s' "$marks" | awk -F'\034' '{for(i=1;i<=NF;i++){if($i!=""){printf "%s\"%s\"", (i>1?",":""), $i}}}')]"
  fi
  [ -n "$reason" ] && reason_json="\"$reason\""
  printf '{"ok":%s,"reason":%s,"marks":%s,"checks":%s}\n' "$ok" "$reason_json" "$marks_json" "$checks"
  [ "$ok" = "true" ] && exit 0
  exit 1
}

add_mark() { MARKS="${MARKS}${MARKS:+$'\034'}$1"; }

MARKS=""

# ---- kill switch ------------------------------------------------------------
if [ "${MODE_GATE:-1}" = "0" ]; then
  emit true "" "DEGRADED:disabled_by_env" '{"skipped":true}'
fi

# ---- dependência: python3 (fail-open) ---------------------------------------
if ! command -v python3 >/dev/null 2>&1; then
  emit true "" "DEGRADED:no_python3" '{"skipped":true}'
fi

# ---- carregar o state (fail-open em tudo) -----------------------------------
if [ -n "$STATE_PATH" ]; then
  if [ ! -f "$STATE_PATH" ]; then
    emit true "" "DEGRADED:state_file_missing" '{"skipped":true}'
  fi
  STDIN_JSON="$(cat "$STATE_PATH" 2>/dev/null)" || STDIN_JSON=""
elif [ ! -t 0 ]; then
  STDIN_JSON="$(cat 2>/dev/null)" || STDIN_JSON=""
fi

if [ -z "${STDIN_JSON//[[:space:]]/}" ]; then
  emit true "" "DEGRADED:state_empty" '{"skipped":true}'
fi

# ---- checagens 1,2,4 em python3 ---------------------------------------------
# Contrato do helper: imprime "VIOLATION <reason>" | "DEGRADED <mark>" | "OK <checks-json>"
GATE_OUT="$(printf '%s' "$STDIN_JSON" | SKILL="$SKILL" TO_MODE="$TO_MODE" python3 -c '
import json, os, sys

SKILL_MODES = {
    "devflow-ideation":  {"ideation"},
    "devflow-spec":      {"specifying"},
    "devflow-plan":      {"planning"},
    "devflow-code":      {"coding", "reviewing"},
    "devflow-ceremony":  {"ceremony"},
    "devflow-distill":   {"distillation"},
    "devflow":           None,  # nucleo: qualquer modo
}

try:
    state = json.loads(sys.stdin.read())
except Exception:
    print("DEGRADED state_unparseable"); sys.exit(0)
if not isinstance(state, dict):
    print("DEGRADED state_not_object"); sys.exit(0)

session = state.get("session")
if not isinstance(session, dict):
    print("DEGRADED no_session_object"); sys.exit(0)

skill = os.environ.get("SKILL", "")
to_mode = os.environ.get("TO_MODE", "")
mode = session.get("mode")
checks = {"mode": mode, "to": to_mode or None, "skill": skill or None}

# 1. bootstrap
gates = state.get("quality_gates")
if not isinstance(gates, dict) or not gates.get("index_loaded_at"):
    print("VIOLATION bootstrap_not_run: quality_gates.index_loaded_at ausente")
    sys.exit(0)
checks["index_loaded_at"] = gates.get("index_loaded_at")

# 2. coerencia skill <-> modo
if skill:
    allowed = SKILL_MODES.get(skill, "UNKNOWN")
    if allowed == "UNKNOWN":
        print("DEGRADED unknown_skill"); sys.exit(0)
    target = to_mode or mode
    if allowed is not None and target and target not in allowed:
        print("VIOLATION skill_mode_mismatch: %s nao opera no modo %s" % (skill, target))
        sys.exit(0)

# 4. spec_dir declarado existe
spec_dir = session.get("spec_dir")
if spec_dir:
    checks["spec_dir"] = spec_dir
    if not os.path.isdir(spec_dir):
        print("VIOLATION spec_dir_missing: %s" % spec_dir); sys.exit(0)

print("OK " + json.dumps(checks))
' 2>/dev/null)" || GATE_OUT=""

if [ -z "$GATE_OUT" ]; then
  emit true "" "DEGRADED:helper_failed" '{"skipped":true}'
fi

VERDICT="${GATE_OUT%% *}"
PAYLOAD="${GATE_OUT#* }"

case "$VERDICT" in
  VIOLATION) emit false "$PAYLOAD" "$MARKS" '{"decided":true}' ;;
  DEGRADED)  add_mark "DEGRADED:$PAYLOAD"; emit true "" "$MARKS" '{"skipped":true}' ;;
  OK)        CHECKS="$PAYLOAD" ;;
  *)         emit true "" "DEGRADED:helper_contract" '{"skipped":true}' ;;
esac

# ---- checagem 3: POs abertas ao sair de coding/reviewing --------------------
SPEC_DIR="$(printf '%s' "$CHECKS" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("spec_dir") or "")' 2>/dev/null)" || SPEC_DIR=""
CUR_MODE="$(printf '%s' "$CHECKS" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("mode") or "")' 2>/dev/null)" || CUR_MODE=""

case "$CUR_MODE" in
  coding|reviewing)
    if [ -z "$SPEC_DIR" ] || [ ! -d "$SPEC_DIR" ]; then
      add_mark "DEGRADED:po_scan_no_spec_dir"
    else
      OPEN_COUNT="$(grep -rc '^status:[[:space:]]*\[ \][[:space:]]*open' "$SPEC_DIR" 2>/dev/null | awk -F: '{s+=$NF} END {print s+0}')"
      if [ -z "$OPEN_COUNT" ]; then
        add_mark "DEGRADED:po_scan_failed"
      elif [ "$OPEN_COUNT" -gt 0 ]; then
        emit false "open_proof_obligations: $OPEN_COUNT PO ainda com status [ ] open em $SPEC_DIR" "$MARKS" '{"decided":true}'
      fi
    fi
    ;;
  *) : ;;
esac

emit true "" "$MARKS" "$CHECKS"
