#!/usr/bin/env bash
# skill-comply.sh — mede se uma instrucao de skill e SEGUIDA sob prompt que nao a apoia (001/slice H).
# -----------------------------------------------------------------------------
# Terceiro consumidor do @core (scripts/lib/engine-core.sh). Mirror: ECC skills/skill-comply/
# SKILL.md:12-17 (3 niveis de rigor: supportive -> neutral -> competing), com duas diferencas
# deliberadas:
#   - o classificador e DETERMINISTICO (regex por passo, em checks.json), nao um LLM. Um juiz
#     LLM mediria a instrucao com a mesma fraqueza que ela tenta medir.
#   - o motor roda em TEXTO LIVRE, nunca com --json-schema. Um schema com os campos esperados
#     faria o motor emiti-los por construcao: a taxa seria 100% e nao mediria nada.
#
# Cenario = diretorio com:
#   scenario.md              transcript SINTETICO da sessao (vai a LLM externo: egress guard)
#   level-supportive.txt     pedido que manda seguir a instrucao
#   level-neutral.txt        pedido que nao menciona a instrucao
#   level-competing.txt      pedido que empurra CONTRA a instrucao
#   checks.json              [{id, desc, all:[regex], none:[regex]}] aplicados na saida
#
# O QUE ELE NAO FAZ: nao edita skill nenhuma (guard da PO-22), nao toca state.json/PR.
# O contexto do motor e so a secao extraida da skill + o cenario + o pedido.
#
# Uso:
#   skill-comply.sh --skill <SKILL.md> --from '<linha inicial>' --to '<linha final>' \
#                   --scenario <dir> [--runs N] [--measure]
#     --from/--to   a secao medida vai da linha que CONTEM --from ate a anterior a --to
#     --measure     para ANTES do motor: imprime a contabilidade (JSON). Os testes usam isto.
#     --classify <nivel>=<arquivo> ...  so classifica saidas prontas (sem motor). Para testes.
#
# Exit: 0 relatorio (ou fail-open) · 2 uso · 3 egress guard.
# -----------------------------------------------------------------------------
set -euo pipefail

ENGINE_CORE_EXPECTED="1.1.0"
# shellcheck source=lib/engine-core.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/engine-core.sh"
if [ "${ENGINE_CORE_VERSION:-}" != "$ENGINE_CORE_EXPECTED" ]; then
  echo "skill-comply.sh: engine-core esperado $ENGINE_CORE_EXPECTED, encontrado ${ENGINE_CORE_VERSION:-<ausente>}" >&2
  exit 2
fi

usage() { sed -n '22,29p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }

SKILL="" FROM="" TO="" SCEN="" RUNS=1 MEASURE=0
CLASSIFY=()
while [ $# -gt 0 ]; do
  case "$1" in
    --skill) SKILL="${2:-}"; shift 2 ;;
    --from) FROM="${2:-}"; shift 2 ;;
    --to) TO="${2:-}"; shift 2 ;;
    --scenario) SCEN="${2:-}"; shift 2 ;;
    --runs) RUNS="${2:-}"; shift 2 ;;
    --measure) MEASURE=1; shift ;;
    --classify) shift; while [ $# -gt 0 ] && [ "${1#--}" = "$1" ]; do CLASSIFY+=("$1"); shift; done ;;
    *) usage ;;
  esac
done
[ -n "$SCEN" ] && [ -f "$SCEN/checks.json" ] || { echo "skill-comply.sh: --scenario sem checks.json" >&2; exit 2; }
case "$RUNS" in ''|*[!0-9]*|0) echo "skill-comply.sh: --runs precisa ser inteiro >= 1" >&2; exit 2 ;; esac

LEVELS=(supportive neutral competing)

# Classificador: saida -> {passo: bool}. Deterministico e sem rede.
classify() { # $1=checks.json $2=output-file -> JSON {"<id>": true|false}
  python3 - "$1" "$2" <<'PY'
import json, re, sys
checks = json.load(open(sys.argv[1])); out = open(sys.argv[2], encoding="utf-8", errors="replace").read()
res = {}
for c in checks:
    ok = all(re.search(p, out, re.S | re.I) for p in c.get("all", []))
    ok = ok and not any(re.search(p, out, re.S | re.I) for p in c.get("none", []))
    res[c["id"]] = ok
print(json.dumps(res))
PY
}

# Relatorio: linhas "nivel<TAB>json" em stdin -> taxa por nivel e por passo.
report() { # $1=engine
  python3 -c '
import json, sys
eng = sys.argv[1]; rows = {}
for line in sys.stdin:
    lvl, js = line.rstrip("\n").split("\t", 1)
    rows.setdefault(lvl, []).append(json.loads(js))
out = {"engine": eng, "context": "cold", "classifier": "deterministic-regex", "levels": {}}
for lvl in ("supportive", "neutral", "competing"):
    runs = rows.get(lvl, [])
    if not runs: continue
    steps = sorted(runs[0])
    per = {s: sum(r[s] for r in runs) / len(runs) for s in steps}
    tot = sum(sum(r.values()) for r in runs) / (len(runs) * len(steps))
    out["levels"][lvl] = {"runs": len(runs), "rate": round(tot, 3), "steps": per}
print(json.dumps(out, ensure_ascii=False, indent=2))
' "$1"
}

if [ "${#CLASSIFY[@]}" -gt 0 ]; then
  for kv in "${CLASSIFY[@]}"; do
    printf '%s\t%s\n' "${kv%%=*}" "$(classify "$SCEN/checks.json" "${kv#*=}")"
  done | report none
  exit 0
fi

[ -f "$SKILL" ] && [ -n "$FROM" ] && [ -n "$TO" ] || usage
for l in "${LEVELS[@]}"; do [ -f "$SCEN/level-$l.txt" ] || { echo "skill-comply.sh: falta level-$l.txt" >&2; exit 2; }; done

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT
SECTION="$WORKDIR/section.md"
awk -v a="$FROM" -v b="$TO" 'index($0,a){on=1} on&&index($0,b){exit} on' "$SKILL" > "$SECTION"
[ -s "$SECTION" ] || { echo "skill-comply.sh: secao vazia — '$FROM' nao encontrado em $SKILL" >&2; exit 2; }

egress_guard "$SCEN/scenario.md" all "cat $SCEN/scenario.md" || exit $?

build_prompt() { # $1=nivel $2=arquivo
  {
    echo "Você é um agente de código operando sob a skill abaixo. Siga-a."
    echo; echo "=== SKILL (seção em vigor) ==="; cat "$SECTION"
    echo; echo "=== SESSÃO ==="; cat "$SCEN/scenario.md"
    echo; echo "=== PEDIDO DO OPERADOR ==="; cat "$SCEN/level-$1.txt"
  } > "$2"
}

if [ "$MEASURE" = 1 ]; then
  build_prompt competing "$WORKDIR/p.md"
  python3 -c 'import json,sys; print(json.dumps({"section_lines": int(sys.argv[1]), "prompt_bytes": int(sys.argv[2]), "levels": ["supportive","neutral","competing"], "runs": int(sys.argv[3]), "checks": [c["id"] for c in json.load(open(sys.argv[4]))]}))' \
    "$(wc -l < "$SECTION" | tr -d ' ')" "$(wc -c < "$WORKDIR/p.md" | tr -d ' ')" "$RUNS" "$SCEN/checks.json"
  exit 0
fi

# shellcheck disable=SC2034  # lidas pelo core — contrato 1.1.0
PASSB_TIMEOUT="${RC6_PASSB_TIMEOUT:-480}"
# shellcheck disable=SC2034
AGY_TIMEOUT="${RC6_AGY_TIMEOUT:-8m}"
RC6_AGY_MODEL="${RC6_AGY_MODEL:-gemini-3.8-flash-medium}"
probe_engines
# Texto livre por decisao (ver cabecalho): schema tornaria a medicao tautologica.
# shellcheck disable=SC2034  # lidas pelo core (build_engine_args / run_engine)
AGY_SCHEMA=0
# shellcheck disable=SC2034
CLAUDE_SCHEMA=0
build_engine_args /dev/null

ENGINE=""
for eng in agy claude; do
  if [ "$eng" = agy ] && [ "$HAVE_AGY" = 1 ]; then ENGINE=agy; break; fi
  if [ "$eng" = claude ] && [ "$HAVE_CLAUDE" = 1 ]; then ENGINE=claude; break; fi
done
[ -n "$ENGINE" ] || fail_open "⚠️ skill-comply unavailable — agy and claude both absent; nothing was measured."

ROWS="$WORKDIR/rows.tsv"; : > "$ROWS"
for l in "${LEVELS[@]}"; do
  build_prompt "$l" "$WORKDIR/prompt-$l.md"
  for i in $(seq 1 "$RUNS"); do
    OUT="$WORKDIR/out-$l-$i.txt"
    if run_engine "$ENGINE" "$WORKDIR/prompt-$l.md" "$OUT"; then
      printf '%s\t%s\n' "$l" "$(classify "$SCEN/checks.json" "$OUT")" >> "$ROWS"
      [ -n "${SKILL_COMPLY_KEEP:-}" ] && cp "$OUT" "$SKILL_COMPLY_KEEP/out-$l-$i.txt"
    else
      log "skill-comply: $ENGINE falhou em $l#$i — $(engine_err_hint "$ENGINE")"
    fi
  done
done
[ -s "$ROWS" ] || fail_open "⚠️ skill-comply unavailable — every engine run failed; nothing was measured."
report "$ENGINE" < "$ROWS"
