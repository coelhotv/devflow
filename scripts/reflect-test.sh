#!/usr/bin/env bash
# reflect-test.sh — runner do corpus da spec 058 (gate de reflexão do RC6).
#
# É o TESTE DA SPEC, e existe antes do gate de propósito: o modo de falha inaceitável
# da 058 não é deixar passar um falso positivo, é REFUTAR UM ACHADO REAL — e isso é
# indetectável sem corpus.
#
#   reflect-test.sh --corpus                 roda os 7 fixtures, imprime tabela + veredito
#   reflect-test.sh --fixture fp-757         roda um fixture
#   reflect-test.sh --fixture fp-767 --json  imprime o JSON anotado pelo gate (p/ diff dos 3 modos)
#
# Contrato com o gate (implementado em T003-T008):
#   - lê na stdin um JSON no formato do $MERGED do ai-review.sh: {"summary":…, "findings":[…]}
#   - escreve na stdout o mesmo JSON, com `refuted` (bool) e `refutation` (string) nos findings
#   - respeita RC6_REFLECT: annotate (default) | drop | 0
#   Caminho do gate: $RC6_REFLECT_GATE (default: ./reflect-gate.sh, ao lado deste script)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIXTURES_DIR="${RC6_FIXTURES_DIR:-$SCRIPT_DIR/../fixtures/rc6}"
GATE="${RC6_REFLECT_GATE:-$SCRIPT_DIR/reflect-gate.sh}"

MODE=""
FIXTURE=""
AS_JSON=0

while [ $# -gt 0 ]; do
  case "$1" in
    --corpus)  MODE="corpus"; shift ;;
    --fixture) MODE="fixture"; FIXTURE="${2:-}"; shift 2 ;;
    --json)    AS_JSON=1; shift ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "reflect-test: argumento desconhecido: $1" >&2; exit 64 ;;
  esac
done

[ -n "$MODE" ] || { echo "reflect-test: use --corpus ou --fixture <id>" >&2; exit 64; }
[ -d "$FIXTURES_DIR" ] || { echo "reflect-test: fixtures não encontrados em $FIXTURES_DIR" >&2; exit 66; }

if [ ! -x "$GATE" ]; then
  echo "reflect-test: gate ausente ou não-executável: $GATE" >&2
  echo "  O runner existe antes do gate por desenho (T002 precede T003-T008)." >&2
  echo "  Enquanto o gate não existir isto é uma FALHA DE SETUP, não um corpus verde." >&2
  exit 69
fi

# Preflight: o corpus é do dosiq — os fixtures citam arquivos e tabelas DELE. Rodar
# contra outro repo faz todo verificador devolver UNAVAILABLE, e o corpus fica vermelho
# por motivo errado (alguém "conserta" o gate que estava certo).
REPO_ROOT="${RC6_REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
if [ ! -f "$REPO_ROOT/packages/core/src/utils/doseUnit.ts" ]; then
  echo "reflect-test: REPO_ROOT=$REPO_ROOT não parece ser o repo do dosiq." >&2
  echo "  Os fixtures citam arquivos e tabelas do dosiq; fora dele todo verificador" >&2
  echo "  devolve UNAVAILABLE e o corpus fica vermelho por motivo errado." >&2
  echo "  Rode de dentro do dosiq, ou exporte RC6_REPO_ROOT=/caminho/para/dosiq." >&2
  exit 78
fi
export RC6_REPO_ROOT="$REPO_ROOT"

# Monta o payload no formato do $MERGED e roda o gate.
# Ecoa: <id>\t<expect>\t<class>\t<refuted_real>\t<tem_refutation>
run_one() {
  local file="$1"
  python3 - "$file" <<'PY' > /tmp/reflect-test-payload.$$.json
import json, sys
fx = json.load(open(sys.argv[1]))
json.dump({"summary": "corpus 058 — fixture %s" % fx["id"], "findings": [fx["finding"]]},
          sys.stdout, ensure_ascii=False)
PY
  local out rc
  out="$("$GATE" < /tmp/reflect-test-payload.$$.json 2>/tmp/reflect-test-stderr.$$)"
  rc=$?
  rm -f /tmp/reflect-test-payload.$$.json
  # O log do FR-009 é a única forma de distinguir "passou porque o verificador
  # contradisse" de "passou porque o verificador nem rodou". Engolir esse stderr
  # transforma degradação silenciosa em corpus vermelho sem causa — a doença que a
  # 056 documentou. Sempre encaminhar.
  sed 's/^/    gate: /' /tmp/reflect-test-stderr.$$ >&2
  rm -f /tmp/reflect-test-stderr.$$
  if [ $rc -ne 0 ]; then
    echo "reflect-test: gate saiu $rc no fixture $(basename "$file")" >&2
    return 1
  fi
  # --json normaliza a serializacao (indent fixo, chaves ordenadas) porque o PO-4 compara
  # os 3 modos por diff. O modo 0 e passthrough PURO — o gate desligado nao pode reescrever
  # o JSON — entao sem normalizar aqui o diff vira ruido de formatacao e esconde justamente
  # o que o PO-4 quer ver: refuted/refutation e nada mais.
  if [ "$AS_JSON" = "1" ]; then
    printf '%s' "$out" | python3 -c 'import json,sys; json.dump(json.load(sys.stdin), sys.stdout, ensure_ascii=False, indent=2, sort_keys=True); print()'
    return 0
  fi
  # 🔴 A saida do gate vai por ARQUIVO, nao por pipe: `python3 - <<'PY'` ja usa o stdin
  # para ler o proprio programa, entao um pipe para o mesmo processo chega vazio e o
  # json.load(sys.stdin) morre com "Expecting value: line 1 column 1".
  printf '%s' "$out" > /tmp/reflect-test-out.$$.json
  python3 - "$file" /tmp/reflect-test-out.$$.json <<'PY'
import json, sys
fx = json.load(open(sys.argv[1], encoding='utf-8'))
out = json.load(open(sys.argv[2], encoding='utf-8'))
fs = out.get("findings", [])
# modo drop remove o refutado: ausência do finding É o refuted.
if fs:
    refuted = bool(fs[0].get("refuted", False))
    refutation = fs[0].get("refutation") or ""
else:
    refuted, refutation = True, "(finding removido — modo drop)"
got = "refuted" if refuted else "passed"
ok = (got == fx["expect"])
# SC-003: refutação sem evidência citável é bug bloqueante.
if refuted and not refutation.strip():
    ok = False
    got += " SEM-EVIDENCIA"
print("\t".join([fx["id"], fx["kind"], str(fx.get("class")), fx["expect"], got, "OK" if ok else "FALHA"]))
PY
  local prc=$?
  rm -f /tmp/reflect-test-out.$$.json
  return $prc
}

if [ "$MODE" = "fixture" ]; then
  f="$FIXTURES_DIR/$FIXTURE.json"
  [ -f "$f" ] || { echo "reflect-test: fixture inexistente: $f" >&2; exit 66; }
  run_one "$f"
  exit $?
fi

# --corpus
echo "id           tipo  classe    esperado  obtido    veredito"
echo "-----------  ----  --------  --------  --------  --------"
rows=0; fails=0
for f in "$FIXTURES_DIR"/*.json; do
  line="$(run_one "$f")" || { fails=$((fails+1)); rows=$((rows+1)); continue; }
  printf '%s\n' "$line" | awk -F'\t' '{printf "%-13s%-6s%-10s%-10s%-10s%s\n", $1,$2,$3,$4,$5,$6}'
  rows=$((rows+1))
  case "$line" in *FALHA) fails=$((fails+1));; esac
done

echo
echo "fixtures: $rows · falhas: $fails"
if [ "$fails" -ne 0 ]; then
  echo "CORPUS VERMELHO — SC-001 (todo fp verificável refutado) ou SC-002 (nenhum real refutado) violado." >&2
  exit 1
fi
echo "CORPUS VERDE — SC-001 e SC-002 satisfeitos."
