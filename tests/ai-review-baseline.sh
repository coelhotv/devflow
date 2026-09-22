#!/usr/bin/env bash
# ai-review-baseline.sh — captura uma baseline DETERMINISTICA do ai-review.sh (001/PO-14).
#
# POR QUE ISTO EXISTE (leia antes de "simplificar"):
#   O proof: original da PO-14 era `./scripts/ai-review.sh --dry-run > after.txt && diff before after`.
#   Nao serve como prova de equivalencia, por duas razoes independentes:
#     (a) --dry-run AINDA CHAMA O ENGINE (cabecalho do ai-review.sh, linha 20). Saida de LLM nao e
#         reproduzivel: o diff acusaria mudanca onde nao houve, ou esconderia mudanca onde houve.
#     (b) neste repo nao existe arquivo .js/.ts, entao o script sai cedo com "No code changes" antes
#         de montar qualquer contexto. O diff daria vazio SEMPRE — inclusive se o refactor quebrasse
#         tudo. Um gate que passa por construcao e pior que nenhum gate.
#   A solucao e RC6_MEASURE=1, que PARA antes de qualquer chamada de engine e imprime a contabilidade
#   de bytes do payload montado, sobre um repo-fixture com diff .js/.ts real.
#
# Uso:  bash tests/ai-review-baseline.sh <arquivo-de-saida>
#       Rode ANTES e DEPOIS do refactor; `diff` entre as duas saidas deve sair VAZIO.
set -euo pipefail

OUT="${1:?uso: ai-review-baseline.sh <arquivo-de-saida>}"
SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/scripts/ai-review.sh"
FIX="$(mktemp -d)"
trap 'rm -rf "$FIX"' EXIT

# --- repo-fixture: base com 3 arquivos, HEAD alterando 2 e adicionando 1 -----
git -C "$FIX" init -q
git -C "$FIX" config user.email rc6@fixture.local
git -C "$FIX" config user.name  rc6-fixture
# .agent/memory/ NAO e decoracao do fixture: sem ANTI_PATTERNS_INDEX.md o ai-review.sh MORRE
# (emit_wiki_block termina num `[ -f ]` falso, e o elo esquerdo do pipeline de WIKI_BYTES, e
# `set -o pipefail` + `set -e` derrubam o script). Bug real, reportado a parte — o fixture
# reproduz um consumidor DEVFLOW normal, que sempre tem .agent/.
mkdir -p "$FIX/src" "$FIX/.agent/memory"
printf '# RULES_INDEX\n\n| id | title | status |\n|----|-------|--------|\n| R-001 | fixture rule | hot |\n' > "$FIX/.agent/memory/RULES_INDEX.md"
printf '# ANTI_PATTERNS_INDEX\n\n| id | title | status |\n|----|-------|--------|\n| AP-001 | fixture ap | hot |\n' > "$FIX/.agent/memory/ANTI_PATTERNS_INDEX.md"
printf 'export function add(a, b) {\n  return a + b;\n}\n'            > "$FIX/src/math.js"
printf 'export const VERSION = "1.0.0";\n'                            > "$FIX/src/const.ts"
printf 'export function noop() {}\n'                                  > "$FIX/src/untouched.js"
git -C "$FIX" add -A
git -C "$FIX" commit -qm base
git -C "$FIX" branch -M main
git -C "$FIX" checkout -qb feature
printf 'export function add(a, b) {\n  if (a == null) return b;\n  return a + b;\n}\n' > "$FIX/src/math.js"
printf 'export const VERSION = "1.1.0";\nexport const DEBUG = false;\n'                > "$FIX/src/const.ts"
printf 'export async function fetchAll(urls) {\n  return Promise.all(urls.map((u) => fetch(u)));\n}\n' > "$FIX/src/net.js"
git -C "$FIX" add -A
git -C "$FIX" commit -qm feature

# --- MEASURE: para antes do engine; so contabilidade de bytes ----------------
# RC6_MAIN fixa a base (sem gh, sem PR). Normalizamos o que varia por execucao
# (sha, tmpdir, tempo) — o que sobra e exatamente o que o refactor pode quebrar.
(
  cd "$FIX"
  # O exit code FAZ PARTE da baseline: se o refactor mudar o desfecho, o diff acusa.
  RC6_MEASURE=1 RC6_MAIN=main bash "$SCRIPT" --dry-run 2>&1 || echo "EXIT=$?"
) | sed -E \
      -e 's/[0-9a-f]{40}/<SHA>/g' \
      -e 's/"head": "[0-9a-f]{7,40}"/"head": "<SHA>"/g' \
      -e 's#/(var|tmp)/[A-Za-z0-9._/-]*#<TMP>#g' \
      -e 's/[0-9]{4}-[0-9]{2}-[0-9]{2}T?[0-9:]*/<TS>/g' \
      -e 's/\x1b\[[0-9;]*m//g' \
  > "$OUT"

echo "baseline -> $OUT ($(wc -l < "$OUT" | tr -d ' ') linhas)"
