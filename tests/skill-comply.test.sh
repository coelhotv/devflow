#!/usr/bin/env bash
# skill-comply.test.sh — 001/slice H (PO-22). Sem rede: --measure e --classify.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
S=scripts/skill-comply.sh; SC=tests/fixtures/skill-comply/c5-7b; C=$SC/canned
pass=0; fail=0
ok()  { echo "  ✓ $1"; pass=$((pass+1)); }
bad() { echo "  ✗ $1"; fail=$((fail+1)); }
jq_() { python3 -c "import json,sys; d=json.load(sys.stdin); print(eval(sys.argv[1]))" "$1"; }

echo "== skill-comply"
m="$($S --skill skills/devflow-code/SKILL.md --from '### C5 — Post-Code Protocol' --to '### Integration with /deliver-sprint' --scenario $SC --measure)"
[ "$(echo "$m" | jq_ 'd["section_lines"] > 50 and "7b" in open("skills/devflow-code/SKILL.md").read()')" = True ] && ok "measure extrai a seção C5" || bad "measure: $m"
[ "$(echo "$m" | jq_ 'd["levels"]')" = "['supportive', 'neutral', 'competing']" ] && ok "3 níveis de rigor" || bad "níveis: $m"

r="$($S --scenario $SC --classify supportive=$C/full.txt neutral=$C/vague.txt competing=$C/oneliner.txt)"
[ "$(echo "$r" | jq_ 'd["levels"]["supportive"]["rate"]')" = 1.0 ] && ok "saída completa = 1.0" || bad "full: $r"
[ "$(echo "$r" | jq_ 'd["levels"]["neutral"]["steps"]')" = "{'demotion': 0.0, 'handoff': 1.0, 'reason_exact': 0.0}" ] && ok "motivo vago e formatDose em worked são reprovados" || bad "vague: $r"
[ "$(echo "$r" | jq_ 'd["levels"]["competing"]["rate"]')" = 0.0 ] && ok "resumo de uma linha = 0.0" || bad "oneliner: $r"
[ "$(echo "$r" | jq_ 'd["classifier"]')" = deterministic-regex ] && ok "classificador declarado determinístico" || bad "classifier"

$S --scenario /nonexistent >/dev/null 2>&1; [ $? = 2 ] && ok "cenário inválido → exit 2" || bad "exit de uso"
$S --scenario $SC --runs 0 >/dev/null 2>&1; [ $? = 2 ] && ok "--runs 0 → exit 2" || bad "--runs 0"
grep -q -- '--json-schema' <(sed -n '/^probe_engines$/,$p' $S) && bad "motor com schema" || ok "motor em texto livre (sem --json-schema)"
git diff --quiet -- skills/ && ok "guard PO-22: nenhuma skill alterada" || bad "skills alteradas"

echo; echo "$pass passaram, $fail falharam"; [ "$fail" = 0 ]
