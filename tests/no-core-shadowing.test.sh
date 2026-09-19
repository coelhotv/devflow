#!/usr/bin/env bash
# no-core-shadowing.test.sh — nenhum consumidor redefine uma funcao do @core (001/PO-15).
#
# POR QUE ISTO E UM TESTE E NAO UMA CONVENCAO:
#   Redefinir localmente uma funcao que o core ja fornece nao quebra nada na hora — o bash
#   simplesmente usa a ultima definicao. O dano aparece depois, quando alguem corrige um bug
#   NO CORE e o consumidor continua rodando a copia velha. E o modo de falha que a extracao
#   do F1 existe para eliminar; sem este teste, a extracao volta sozinha ao ponto de partida.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CORE="$ROOT/scripts/lib/engine-core.sh"
fail=0; pass=0

[ -f "$CORE" ] || { echo "FALHA: core ausente em $CORE"; exit 1; }

# --- 1. o core declara versao ------------------------------------------------
if grep -qE '^ENGINE_CORE_VERSION="[0-9]+\.[0-9]+\.[0-9]+"' "$CORE"; then
  echo "  ok   core declara ENGINE_CORE_VERSION"; pass=$((pass+1))
else
  echo "  FALHA  core sem ENGINE_CORE_VERSION semantica"; fail=$((fail+1))
fi

# --- 2. funcoes exportadas pelo core -----------------------------------------
# bash 3.2 (macOS) nao tem mapfile — o resto do repo tambem o evita de proposito.
CORE_FUNCS=()
while IFS= read -r fn; do CORE_FUNCS+=("$fn"); done < <(grep -oE '^[a-z_]+\(\)' "$CORE" | tr -d '()' | sort -u)
[ "${#CORE_FUNCS[@]}" -gt 0 ] || { echo "FALHA: core nao define funcao nenhuma"; exit 1; }
echo "  info core exporta ${#CORE_FUNCS[@]} funcoes: ${CORE_FUNCS[*]}"

# --- 3. consumidores: quem da source no core ---------------------------------
CONSUMERS=()
while IFS= read -r c; do CONSUMERS+=("$c"); done < <(grep -rlE 'lib/engine-core\.sh' "$ROOT/scripts" --include='*.sh' | grep -v '/lib/' | sort)
[ "${#CONSUMERS[@]}" -gt 0 ] || { echo "FALHA: nenhum consumidor do core"; exit 1; }

for c in "${CONSUMERS[@]}"; do
  rel="${c#"$ROOT"/}"
  # 3a. cita a versao esperada
  if grep -qE 'ENGINE_CORE_EXPECTED="[0-9]+\.[0-9]+\.[0-9]+"' "$c"; then
    echo "  ok   $rel cita ENGINE_CORE_EXPECTED"; pass=$((pass+1))
  else
    echo "  FALHA  $rel da source no core sem citar a versao esperada"; fail=$((fail+1))
  fi
  # 3b. nao redefine nenhuma funcao do core
  for fn in "${CORE_FUNCS[@]}"; do
    if grep -qE "^${fn}\(\) *\{" "$c"; then
      echo "  FALHA  $rel REDEFINE $fn (ja vem do core)"; fail=$((fail+1))
    fi
  done
done
echo "  ok   nenhuma redefinicao encontrada em ${#CONSUMERS[@]} consumidor(es)"; pass=$((pass+1))

echo
echo "$pass passaram, $fail falharam"
[ "$fail" = 0 ]
