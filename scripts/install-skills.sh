#!/usr/bin/env bash
# install-skills.sh — liga as 6 sub-skills do DEVFLOW ao diretorio que o harness descobre.
#
# Por que existe: a descoberta de skills olha UM nivel abaixo de ~/.claude/skills/, e as
# sub-skills sao versionadas DENTRO do repo (skills/devflow-*/). Sub-skill aninhada nao e
# encontrada. Sem este passo, um clone limpo entrega 1 skill em vez de 7 — em silencio,
# que e a classe do AP-325. O symlink nao se versiona; por isso a instalacao e um passo.
#
# Uso:  bash scripts/install-skills.sh [--dry-run] [--dest DIR]
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="${DEST:-$HOME/.claude/skills}"
DRY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY=1 ;;
    --dest) DEST="$2"; shift ;;
    *) echo "flag desconhecida: $1" >&2; exit 2 ;;
  esac
  shift
done

SKILLS_DIR="$REPO/skills"
[ -d "$SKILLS_DIR" ] || { echo "FALHOU: $SKILLS_DIR nao existe — nada a instalar (antes da quebra, ESTE e o resultado esperado)" >&2; exit 1; }

found=0
for src in "$SKILLS_DIR"/devflow-*; do
  [ -d "$src" ] || continue
  [ -f "$src/SKILL.md" ] || { echo "FALHOU: $src sem SKILL.md" >&2; exit 1; }
  found=$((found+1))
done
[ "$found" -gt 0 ] || { echo "FALHOU: nenhuma sub-skill em $SKILLS_DIR" >&2; exit 1; }

mkdir -p "$DEST"

# PRE-FLIGHT: conferir TODOS os destinos antes de escrever QUALQUER um. Sem isto, um destino
# ruim no meio da lista deixa metade instalada e metade nao — estado parcial que o operador
# so descobre pela ausencia de uma skill.
for src in "$SKILLS_DIR"/devflow-*; do
  [ -d "$src" ] || continue
  link="$DEST/$(basename "$src")"
  if [ -L "$link" ]; then
    current="$(readlink "$link")"
    [ "$current" = "$src" ] || {
      echo "FALHOU (pre-flight): $link ja aponta para '$current' (esperado '$src')." >&2
      echo "        Remova ou aponte a mao — este script nao sobrescreve link de outra origem." >&2
      echo "        NADA foi instalado." >&2; exit 1; }
  elif [ -e "$link" ]; then
    echo "FALHOU (pre-flight): $link existe e NAO e symlink. Nao sera tocado." >&2
    echo "        NADA foi instalado." >&2; exit 1
  fi
done

ok=0; skipped=0
for src in "$SKILLS_DIR"/devflow-*; do
  [ -d "$src" ] || continue
  name="$(basename "$src")"
  link="$DEST/$name"

  if [ -L "$link" ]; then
    current="$(readlink "$link")"
    if [ "$current" = "$src" ]; then
      echo "ok (ja instalado)  $name"; skipped=$((skipped+1)); continue
    fi
    # Symlink de outra origem: NAO sobrescrever calado. Quem instalou pode ter tido motivo,
    # e apagar por conta propria e exatamente o silencio que este script existe para evitar.
    echo "FALHOU: $link ja aponta para '$current' (esperado '$src')." >&2
    echo "        Remova ou aponte a mao — este script nao sobrescreve link de outra origem." >&2
    exit 1
  elif [ -e "$link" ]; then
    # Diretorio/arquivo REAL: apagar seria irreversivel. Nunca.
    echo "FALHOU: $link existe e NAO e symlink. Nao sera tocado." >&2
    exit 1
  fi

  if [ "$DRY" = 1 ]; then
    echo "[dry-run] ln -s $src $link"
  else
    ln -s "$src" "$link"
    echo "instalado         $name"
  fi
  ok=$((ok+1))
done

echo "---"
echo "destino: $DEST"
echo "novos: $ok · ja existentes: $skipped · total de sub-skills no repo: $found"
[ "$DRY" = 1 ] && echo "(dry-run — nada foi escrito)"
exit 0
