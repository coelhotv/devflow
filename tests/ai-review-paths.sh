#!/usr/bin/env bash
# ai-review-paths.sh — caracteriza os caminhos do ai-review.sh que a baseline NAO exercita (001/F2).
#
# POR QUE ISTO EXISTE: a extracao da 1.1.0 do core move egress guard, fail-open, probe de
# engine e montagem de argv para scripts/lib/engine-core.sh. A tests/ai-review-baseline.sh
# e cega para os tres (analysis-F2.md §2): o fixture dela nao tem PII (egress so pelo ramo
# silencioso), o RC6_MEASURE sai antes do fail-open, e os binarios reais tem todas as flags
# (o probe nao loga nada). "Baseline identica" provaria so o caminho feliz.
#
# Cenarios (PATH isolado, SEM agy/claude reais — nenhuma chamada de LLM):
#   egress    diff com e-mail real numa linha `+`  -> exit 3 + mensagem
#   failopen  nenhum engine no PATH                -> JSON de indisponivel, exit 0
#   legacy    agy falso SEM --json-schema no help  -> log do probe + invocacao legada
#   schema    agy falso COM as flags               -> argv montado (sem o prompt) + review
#
# Uso:  bash tests/ai-review-paths.sh <arquivo-de-saida>
#       Rode ANTES e DEPOIS da extracao; `diff` entre as duas saidas deve sair VAZIO.
set -euo pipefail

OUT="${1:?uso: ai-review-paths.sh <arquivo-de-saida>}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/scripts/ai-review.sh"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

# --- bin isolado: so o que o script precisa, nunca agy/claude reais ----------
BIN="$T/bin"; mkdir -p "$BIN"
for b in git python3; do ln -s "$(command -v "$b")" "$BIN/$b"; done
ISOPATH="$BIN:/usr/bin:/bin"

# agy falso: --help conforme FAKE_AGY_HELP; loga o argv SEM o prompt; devolve envelope.
cat > "$T/fake-agy" <<'SH'
#!/usr/bin/env bash
if [ "${1:-}" = --help ]; then printf '%s\n' "$FAKE_AGY_HELP"; exit 0; fi
out=(); skip=0
for a in "$@"; do
  if [ "$skip" = 1 ]; then out+=("<PROMPT>"); skip=0; continue; fi
  [ "$a" = -p ] && skip=1
  out+=("$a")
done
printf 'AGY_ARGV: %s\n' "${out[*]}" >> "$FAKE_LOG"
if [ "${FAKE_AGY_SCHEMA:-1}" = 1 ]; then
  printf '{"status":"SUCCESS","structured_output":{"summary":"fake review","findings":[]}}\n'
else
  printf '{"summary":"fake review","findings":[]}\n'
fi
SH
chmod +x "$T/fake-agy"

mkrepo() { # $1=dir $2=conteudo novo de src/math.js
  local d="$1"
  mkdir -p "$d"
  git -C "$d" init -q
  git -C "$d" config user.email rc6@fixture.local
  git -C "$d" config user.name  rc6-fixture
  mkdir -p "$d/src" "$d/.agent/memory"
  printf '# RULES_INDEX\n' > "$d/.agent/memory/RULES_INDEX.md"
  printf '# ANTI_PATTERNS_INDEX\n' > "$d/.agent/memory/ANTI_PATTERNS_INDEX.md"
  printf 'export function add(a, b) {\n  return a + b;\n}\n' > "$d/src/math.js"
  git -C "$d" add -A; git -C "$d" commit -qm base; git -C "$d" branch -M main
  git -C "$d" checkout -qb feature
  printf '%s' "$2" > "$d/src/math.js"
  git -C "$d" add -A; git -C "$d" commit -qm feature
}

run() { # $1=nome $2=repo; env extra vem do chamador
  echo "===== $1"
  ( cd "$2" && PATH="$ISOPATH" RC6_MAIN=main RC6_SELECTOR=0 bash "$SCRIPT" --dry-run 2>&1 ) \
    || echo "EXIT=$?"
  if [ -f "$T/fake.log" ]; then cat "$T/fake.log"; rm -f "$T/fake.log"; fi
}

CLEAN=$'export function add(a, b) {\n  if (a == null) return b;\n  return a + b;\n}\n'
PII=$'export function add(a, b) {\n  // contato: joao.silva@gmail.com\n  return a + b;\n}\n'
mkrepo "$T/clean" "$CLEAN"
mkrepo "$T/pii"   "$PII"

{
  run egress   "$T/pii"
  run failopen "$T/clean"

  ln -sf "$T/fake-agy" "$BIN/agy"
  FAKE_LOG="$T/fake.log" FAKE_AGY_SCHEMA=0 \
    FAKE_AGY_HELP="usage: agy [--sandbox] [--print-timeout] [--model]" run legacy "$T/clean"
  FAKE_LOG="$T/fake.log" FAKE_AGY_SCHEMA=1 \
    FAKE_AGY_HELP="usage: agy [--sandbox] [--json-schema] [--output-format] [--disable-slash-commands]" \
    run schema "$T/clean"
} | sed -E \
      -e 's/[0-9a-f]{40}/<SHA>/g' \
      -e 's/"head": "[0-9a-f]{7,40}"/"head": "<SHA>"/g' \
      -e 's/(base|head)=[0-9a-f]{7,40}/\1=<SHA>/g' \
      -e 's#/(private/)?(var|tmp)/[A-Za-z0-9._/-]*#<TMP>#g' \
      -e 's/[0-9]{4}-[0-9]{2}-[0-9]{2}T?[0-9:.Z+-]*/<TS>/g' \
      -e 's/[0-9]+(\.[0-9]+)?s\b/<DUR>/g' \
      -e 's/\x1b\[[0-9;]*m//g' \
  > "$OUT"

echo "paths -> $OUT ($(wc -l < "$OUT" | tr -d ' ') linhas)"
