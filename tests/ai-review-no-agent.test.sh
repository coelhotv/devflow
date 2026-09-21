#!/usr/bin/env bash
# ai-review-no-agent.test.sh — o ai-review.sh SOBREVIVE num repo sem `.agent/` (AC-1, spec 001).
#
# POR QUE ISTO EXISTE (leia antes de "simplificar"):
#   `emit_wiki_block` terminava num `[ -f "$AP_IDX" ] && ...`. Guarda como ULTIMO comando de funcao
#   vira o exit status DA FUNCAO; sob `set -euo pipefail` (ai-review.sh:40) isso derrubava o script
#   inteiro com exit 1 MUDO quando `.agent/memory/ANTI_PATTERNS_INDEX.md` nao existia.
#
#   O defeito ficou invisivel por DOIS acasos simultaneos, e e por isso que este teste tem fixture
#   proprio em vez de reusar o da baseline:
#     (a) o consumidor real (dosiq) SEMPRE tem `.agent/` — nunca entrava no caminho;
#     (b) este repo saia antes, em "No code changes", por nao ter arquivo .js/.ts.
#   O fixture da baseline (PO-14) CRIA `.agent/memory/` de proposito, porque reproduz um consumidor
#   DEVFLOW normal. Logo ele NAO cobre este caso — precisa ser o espelho dele: mesmo diff real,
#   `.agent/` AUSENTE.
#
#   A classe do bug ja era CONHECIDA neste arquivo: ai-review.sh:1208 carrega um `|| true` com o
#   comentario explicando exatamente este mecanismo. O conserto foi entendido uma vez e nao foi
#   generalizado — por isso a defesa duravel e ESTE TESTE, nao a memoria de quem consertou.
set -uo pipefail

SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/scripts/ai-review.sh"
FIX="$(mktemp -d)"
trap 'rm -rf "$FIX"' EXIT
pass=0; fail=0
ok()   { printf '  ok   %s\n' "$1"; pass=$((pass+1)); }
bad()  { printf '  FAIL %s\n' "$1"; fail=$((fail+1)); }

# --- fixture: identico ao da baseline, MENOS o `.agent/` ---------------------
git -C "$FIX" init -q
git -C "$FIX" config user.email rc6@fixture.local
git -C "$FIX" config user.name  rc6-fixture
mkdir -p "$FIX/src"
printf 'export function add(a, b) {\n  return a + b;\n}\n' > "$FIX/src/math.js"
printf 'export const VERSION = "1.0.0";\n'                 > "$FIX/src/const.ts"
git -C "$FIX" add -A
git -C "$FIX" commit -qm base
git -C "$FIX" branch -M main
# A mudanca vai num BRANCH: o script compara HEAD contra a base. Com tudo em `main`,
# base == head, o diff sai vazio e o script encerra em "No code changes" ANTES de
# `emit_wiki_block` — passando como se estivesse consertado. Espelha a baseline (PO-14).
git -C "$FIX" checkout -qb feature
printf 'export function add(a, b) {\n  if (a == null) return b;\n  return a + b;\n}\n' > "$FIX/src/math.js"
printf 'export async function get(u) { return fetch(u); }\n'                              > "$FIX/src/net.js"
git -C "$FIX" add -A
git -C "$FIX" commit -qm feature

[ -e "$FIX/.agent" ] && { echo "fixture invalido: .agent existe"; exit 2; }

out="$(cd "$FIX" && RC6_MEASURE=1 RC6_MAIN=main bash "$SCRIPT" 2>&1)"; rc=$?

# 1. o script nao pode morrer por ausencia de .agent/
if [ "$rc" -eq 0 ]; then
  ok "repo sem .agent/: exit 0 (nao morre no emit_wiki_block)"
else
  bad "repo sem .agent/: exit $rc (esperado 0) — AC-1 regrediu"
  printf '%s\n' "$out" | sed 's/^/       | /'
fi

# 2. e tem de CHEGAR ao fim do trabalho, nao so sair limpo cedo demais.
#    Sem esta assercao, um `exit 0` prematuro passaria como conserto.
if printf '%s' "$out" | grep -q 'MEASURE: total payload'; then
  ok "chegou ao MEASURE final (montou o payload de verdade)"
else
  bad "nao alcancou o MEASURE final — saiu cedo, nao e conserto"
fi

# 3. ausencia de indice degrada, nao explode: o bloco WIKI sai vazio e o resto segue.
if printf '%s' "$out" | grep -q 'preamble .*B'; then
  ok "preambulo montado mesmo sem RULES/ANTI_PATTERNS_INDEX"
else
  bad "preambulo ausente — a degradacao nao e graciosa"
fi

printf '\n%d passaram, %d falharam\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
