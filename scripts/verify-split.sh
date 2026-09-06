#!/usr/bin/env bash
# verify-split.sh — prova que a quebra da SKILL.md em 7 skills foi MECANICA (078/PO-19, PO-23 guard).
#
# ⚠️ APOSENTADO em 2026-09-05 (078/T5.7a, decisao do PO). NAO E GATE — nao rode em C4/C5 nem em hook.
#
#   O que ele prova e um EVENTO, nao um invariante: que o commit cb40ce6 moveu as linhas da
#   SKILL.md sem reescrever nenhuma. Esse evento ja passou e a evidencia esta no PR #825; a ultima
#   execucao verde foi em 2026-09-05, contra a base 9a8267e, antes desta nota.
#
#   Mantido como GATE ele reprovaria TODA edicao legitima subsequente nas 7 skills — a primeira
#   delas e o passo do C5 deste mesmo slice (078/T5.7), que insere linhas em
#   skills/devflow-code/SKILL.md e o deixa vermelho por construcao. O desfecho previsivel de um
#   verificador permanentemente vermelho e alguem "consertar" afrouxando o verificador, que e a
#   familia do AP-325 — e um script afrouxado e pior que um script aposentado, porque continua
#   parecendo prova.
#
#   A alternativa considerada e recusada foi repontar a base para o commit da quebra e mante-lo
#   como guard anti-reescrita: exigiria distinguir linha MOVIDA de linha NOVA, o que nao e de graca
#   e nao foi orcado neste slice.
#
#   Para reproduzir a prova historica: `git stash` de qualquer trabalho e
#   `git checkout cb40ce6 && bash scripts/verify-split.sh`.
#
# Por que duas checagens e nao uma:
#   (a) o corpo 13-2096 e movido em blocos contiguos  -> diff ORDENADO tem de sair VAZIO;
#   (b) o Quick Reference (2097-2135) e DISTRIBUIDO   -> a ordem muda por construcao, entao
#       so um MULTISET das linhas de dados prova que nada sumiu nem foi trocado. Contagem
#       sozinha nao serve: 22 linhas trocadas por outras 22 passariam.
#
# Uso:  bash scripts/verify-split.sh [BASE_REF]
#       BASE_REF = commit que ainda tem a SKILL.md inteira (default: env BASE_REF ou 9a8267e).
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO"
BASE_REF="${1:-${BASE_REF:-9a8267e}}"

CORE_A_START=13    ; CORE_A_END=189
CORE_B_START=1947  ; CORE_B_END=2096
QR_START=2097      ; QR_END=2123   # titulo + cabecalho + 22 linhas de dados
TAIL_START=2124    ; TAIL_END=2135  # rodape (Reference files + historico) — volta INTEIRO para o nucleo

# Ordem ORIGINAL dos segmentos: id -> arquivo da skill
SEGMENTS=(
  "core-a:SKILL.md"
  "ideation:skills/devflow-ideation/SKILL.md"
  "spec:skills/devflow-spec/SKILL.md"
  "ceremony:skills/devflow-ceremony/SKILL.md"
  "plan:skills/devflow-plan/SKILL.md"
  "code:skills/devflow-code/SKILL.md"
  "distill:skills/devflow-distill/SKILL.md"
  "core-b:SKILL.md"
)
# rodape: segmento proprio, conferido por diff ORDENADO tambem — sem isto ele cairia
# no vao entre o corpo (para em 2096) e o multiset do QuickRef (so olha linha de tabela).
TAIL_SEG="tail:SKILL.md"
ALL_SKILLS=(SKILL.md skills/devflow-code/SKILL.md skills/devflow-ceremony/SKILL.md
            skills/devflow-ideation/SKILL.md skills/devflow-distill/SKILL.md
            skills/devflow-spec/SKILL.md skills/devflow-plan/SKILL.md)

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
fail() { echo "FALHOU: $*" >&2; exit 1; }

# --- base: a SKILL.md inteira, do commit anterior a quebra --------------------
git rev-parse --verify --quiet "${BASE_REF}^{commit}" >/dev/null \
  || fail "BASE_REF '$BASE_REF' nao resolve para commit. Sem base nao ha comparacao — nunca cair para a arvore de trabalho."
git show "${BASE_REF}:SKILL.md" > "$TMP/base.md" 2>/dev/null \
  || fail "SKILL.md ausente em $BASE_REF"
BASE_LINES=$(wc -l < "$TMP/base.md" | tr -d ' ')
[ "$BASE_LINES" -ge "$TAIL_END" ] \
  || fail "base tem $BASE_LINES linhas, esperado >= $TAIL_END — os intervalos do manifesto nao valem para esta base"

# --- pre-condicao: as 7 skills existem ---------------------------------------
missing=0
for f in "${ALL_SKILLS[@]}"; do
  [ -f "$f" ] || { echo "ausente: $f" >&2; missing=$((missing+1)); }
done
[ "$missing" -eq 0 ] \
  || fail "$missing skill(s) ausente(s). Antes da quebra ESTE e o resultado esperado — o verificador nasce VERMELHO (familia do AP-325: gate que passa sem ter o que verificar nao e gate)."

# extrai o corpo movido, entre os marcadores do segmento
extract() { # $1=id  $2=arquivo
  awk -v id="$1" '
    $0 == "<!-- devflow-split:" id ":begin -->" { on=1; next }
    $0 == "<!-- devflow-split:" id ":end -->"   { on=0; next }
    on { print }
  ' "$2"
}

# --- (a) diff ORDENADO de 13-2096 --------------------------------------------
sed -n "${CORE_A_START},${CORE_B_END}p" "$TMP/base.md" > "$TMP/original.md"
: > "$TMP/uniao.md"
for seg in "${SEGMENTS[@]}"; do
  id="${seg%%:*}"; file="${seg#*:}"
  n=$(extract "$id" "$file" | wc -l | tr -d ' ')
  [ "$n" -gt 0 ] || fail "segmento '$id' vazio em $file — marcador ausente ou bloco nao movido"
  extract "$id" "$file" >> "$TMP/uniao.md"
done

if ! diff -u "$TMP/original.md" "$TMP/uniao.md" > "$TMP/diff.txt"; then
  echo "=== DIFF NAO VAZIO — a quebra deixou de ser mecanica. PARE. ==="
  head -60 "$TMP/diff.txt"
  fail "linha reescrita, perdida ou duplicada entre ${CORE_A_START}-${CORE_B_END}"
fi
echo "OK (a) corpo ${CORE_A_START}-${CORE_B_END}: diff VAZIO ($(wc -l < "$TMP/original.md" | tr -d ' ') linhas)"

# --- (a2) diff ORDENADO do rodape 2124-2135 ----------------------------------
sed -n "${TAIL_START},${TAIL_END}p" "$TMP/base.md" > "$TMP/tail_base.md"
extract "${TAIL_SEG%%:*}" "${TAIL_SEG#*:}" > "$TMP/tail_novo.md"
if ! diff -u "$TMP/tail_base.md" "$TMP/tail_novo.md" > "$TMP/tail_diff.txt"; then
  echo "=== rodape ${TAIL_START}-${TAIL_END} divergiu ==="; head -40 "$TMP/tail_diff.txt"
  fail "rodape perdido ou alterado — ele nao e linha de tabela, entao o multiset do QuickRef NAO o cobre"
fi
echo "OK (a2) rodape ${TAIL_START}-${TAIL_END}: diff VAZIO ($(wc -l < "$TMP/tail_base.md" | tr -d ' ') linhas)"

# --- (b) MULTISET do Quick Reference -----------------------------------------
# linhas de DADOS: descarta cabecalho e separador, que se duplicam de proposito em cada destino
# `grep` sem casamento devolve 1; com `set -e` isso mataria o script CALADO quando uma skill
# nao recebe nenhuma linha do Quick Reference (ideation/plan/distill nao recebem — e legitimo).
qr_data() { grep '^|' || true; }
qr_rows() { qr_data | { grep -vE '^\| *DO *\|' || true; } | { grep -vE '^\|[-: |]+\|$' || true; }; }
sed -n "${QR_START},${QR_END}p" "$TMP/base.md" | qr_rows | sort > "$TMP/qr_base.txt"
: > "$TMP/qr_novo.txt"
for f in "${ALL_SKILLS[@]}"; do extract qr "$f" | qr_rows >> "$TMP/qr_novo.txt"; done
sort -o "$TMP/qr_novo.txt" "$TMP/qr_novo.txt"

if ! diff -u "$TMP/qr_base.txt" "$TMP/qr_novo.txt" > "$TMP/qr_diff.txt"; then
  echo "=== Quick Reference: multiset DIFERENTE ==="
  head -40 "$TMP/qr_diff.txt"
  fail "linha do Do/Do-Not perdida, duplicada ou trocada na distribuicao"
fi
echo "OK (b) Quick Reference: multiset identico ($(wc -l < "$TMP/qr_base.txt" | tr -d ' ') linhas de dados)"

# --- guard do PO-19: contagem de blocos --------------------------------------
# um bloco movido para DENTRO de outro nao aparece no diff de linha; por isso a contagem e separada.
count_base() { sed -n "${CORE_A_START},${QR_END}p" "$TMP/base.md" | grep -c "$1" || true; }
count_new()  { for f in "${ALL_SKILLS[@]}"; do for id in core-a core-b ideation spec ceremony plan code distill qr tail; do extract "$id" "$f"; done; done | grep -c "$1" || true; }
for pat in '^### ' '^```po'; do
  b=$(count_base "$pat"); n=$(count_new "$pat")
  [ "$b" = "$n" ] || fail "contagem de '$pat' divergiu: base=$b uniao=$n"
  echo "OK guard: '$pat' base=$b uniao=$n"
done

echo "VERIFY-SPLIT OK — base $BASE_REF"
