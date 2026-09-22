#!/usr/bin/env bash
# setup.test.sh — PO-1, PO-2, PO-3 da spec 002 (setup-active-ledger).
#
# Roda scripts/setup.sh em diretorios descartaveis (mktemp -d), NUNCA em ~/.claude/skills real
# (FR-007): DEST e exportado para um tmp dir antes de cada chamada, e install-skills.sh (chamado
# pelo setup.sh no passo 5b) le esse DEST via ${DEST:-$HOME/.claude/skills}.
#
# Uso: bash tests/setup.test.sh
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SETUP="$ROOT/scripts/setup.sh"
pass=0; fail=0
ok()  { echo "  ok    $1"; pass=$((pass+1)); }
bad() { echo "  FALHA $1"; fail=$((fail+1)); }

run_setup() { # $1=project-path [extra args...]
  local proj="$1"; shift
  DEST="$T/skills-dest" bash "$SETUP" "$proj" "fixture-project" "unknown" "$@"
}

checksum_tree() { # $1=dir -> lista "relpath  sha256" ordenada
  find "$1" -type f | sort | while IFS= read -r f; do
    shasum -a 256 "$f" | awk -v f="${f#"$1"/}" '{print f"  "$1}'
  done
}

echo "== PO-1: rerun sobre um .agent/ existente preserva byte-a-byte"
T="$(mktemp -d)"; trap 'rm -rf "$T"' RETURN
PROJ="$T/proj1"; mkdir -p "$PROJ"
run_setup "$PROJ" >/dev/null 2>&1
# simula memoria acumulada: uma linha extra num INDEX + state.json com sessao real
printf '\n## Extra\n- R-999 linha adicionada por sessao anterior\n' >> "$PROJ/.agent/memory/RULES_INDEX.md"
python3 -c "
import json
p='$PROJ/.agent/state.json'
d=json.load(open(p))
d['session']['status']='reviewing'
d['session']['goal']='algo em andamento'
json.dump(d, open(p,'w'), indent=2)
"
before="$(checksum_tree "$PROJ/.agent")"
out="$(run_setup "$PROJ" 2>&1)"
after="$(checksum_tree "$PROJ/.agent")"
[ "$before" = "$after" ] && ok "checksums identicos apos rerun" || bad "rerun alterou arquivo(s) existente(s)"
echo "$out" | grep -qi "pulad\|skip\|existe" && ok "saida do setup diz o que foi pulado" || bad "setup nao reporta o que pulou: $out"
rm -rf "$T"

echo "== PO-1 guard: repo novo continua verde"
T="$(mktemp -d)"; trap 'rm -rf "$T"' RETURN
PROJ="$T/proj-novo"; mkdir -p "$PROJ"
run_setup "$PROJ" >/dev/null 2>&1
[ -f "$PROJ/.agent/state.json" ] && [ -f "$PROJ/.agent/memory/RULES_INDEX.md" ] && ok "repo novo cria tudo" || bad "repo novo incompleto"
rm -rf "$T"

echo "== PO-2: repo novo nasce com os dois ledgers vazios"
T="$(mktemp -d)"; trap 'rm -rf "$T"' RETURN
PROJ="$T/proj2"; mkdir -p "$PROJ"
run_setup "$PROJ" >/dev/null 2>&1
PF="$PROJ/.agent/memory/process-friction.jsonl"
AT="$PROJ/.agent/memory/attempts.jsonl"
[ -f "$PF" ] && [ -f "$AT" ] && ok "os 2 ledgers existem" || bad "ledger(s) ausente(s): $PF / $AT"
[ ! -s "$PF" ] && [ ! -s "$AT" ] && ok "os 2 ledgers estao vazios" || bad "ledger(s) nao-vazio(s) recem-criado(s)"

echo "== PO-2: relogio inativo antes do commit, data ISO depois"
git -C "$PROJ" init -q
git -C "$PROJ" -c user.email=t@t -c user.name=t log --diff-filter=A --format=%cI -- .agent/memory/process-friction.jsonl > "$T/before.txt" 2>/dev/null
[ ! -s "$T/before.txt" ] && ok "sem commit: relogio inativo (git log vazio)" || bad "relogio ja ativo sem commit: $(cat "$T/before.txt")"
git -C "$PROJ" add .agent/memory/process-friction.jsonl
git -C "$PROJ" -c user.email=t@t -c user.name=t commit -q -m "ledger ativo"
git -C "$PROJ" log --diff-filter=A --format=%cI -- .agent/memory/process-friction.jsonl > "$T/after.txt" 2>&1
[ -s "$T/after.txt" ] && grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T' "$T/after.txt" && ok "apos commit: devolve data ISO" || bad "sem data ISO apos commit: $(cat "$T/after.txt")"
rm -rf "$T"

echo "== PO-2 guard: nenhum kind novo no process-friction.jsonl (vocabulario fechado)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' RETURN
PROJ="$T/proj2b"; mkdir -p "$PROJ"
run_setup "$PROJ" >/dev/null 2>&1
# vocabulario fechado do C5/1c: unsatisfiable|no-slot|reinvented|contradiction|stale.
# um marco de inicio NAO pode aparecer como linha kind=... dentro do ledger.
[ ! -s "$PROJ/.agent/memory/process-friction.jsonl" ] && ok "ledger continua vazio (nenhum kind injetado pelo setup)" || bad "setup escreveu conteudo no ledger"
rm -rf "$T"

echo "== PO-3: sem .gitignore -> cria com as entradas do DEVFLOW"
T="$(mktemp -d)"; trap 'rm -rf "$T"' RETURN
PROJ="$T/proj3a"; mkdir -p "$PROJ"
run_setup "$PROJ" >/dev/null 2>&1
[ -f "$PROJ/.gitignore" ] && ok ".gitignore criado" || bad ".gitignore nao foi criado"
git -C "$PROJ" init -q >/dev/null 2>&1
git -C "$PROJ" check-ignore -q .agent/state.json && git -C "$PROJ" check-ignore -q .agent/sessions/x && git -C "$PROJ" check-ignore -q .agent/evolution/x \
  && ok "state.json, sessions/, evolution/ ignorados" || bad "git check-ignore nao confirmou os 3 caminhos"
git -C "$PROJ" check-ignore -q .agent/memory/RULES_INDEX.md && bad "memory/ nao deveria ser ignorada" || ok "memory/ (indices) NAO e ignorada"
rm -rf "$T"

echo "== PO-3: com .gitignore parcial -> completa so o que falta, sem duplicar"
T="$(mktemp -d)"; trap 'rm -rf "$T"' RETURN
PROJ="$T/proj3b"; mkdir -p "$PROJ"
printf 'node_modules/\n.agent/state.json\n' > "$PROJ/.gitignore"
run_setup "$PROJ" >/dev/null 2>&1
git -C "$PROJ" init -q >/dev/null 2>&1
grep -c '^\.agent/state\.json$' "$PROJ/.gitignore" | grep -q '^1$' && ok "linha existente nao duplicou" || bad "state.json duplicado: $(grep -c '.agent/state.json' "$PROJ/.gitignore")"
git -C "$PROJ" check-ignore -q .agent/sessions/x && ok "sessions/ adicionada (faltava)" || bad "sessions/ nao foi completada"
git -C "$PROJ" check-ignore -q .agent/evolution/x && ok "evolution/ adicionada (faltava)" || bad "evolution/ nao foi completada"
rm -rf "$T"

echo "== PO-3 guard: rodar duas vezes nao duplica nenhuma linha"
T="$(mktemp -d)"; trap 'rm -rf "$T"' RETURN
PROJ="$T/proj3c"; mkdir -p "$PROJ"
run_setup "$PROJ" >/dev/null 2>&1
before_lines="$(sort "$PROJ/.gitignore")"
run_setup "$PROJ" >/dev/null 2>&1
after_lines="$(sort "$PROJ/.gitignore")"
[ "$before_lines" = "$after_lines" ] && ok "segunda rodada nao mudou o .gitignore" || bad ".gitignore mudou na segunda rodada"
rm -rf "$T"

echo "== FR-005: versao v3.0 e session.handoff:null no template"
T="$(mktemp -d)"; trap 'rm -rf "$T"' RETURN
PROJ="$T/proj5"; mkdir -p "$PROJ"
out="$(run_setup "$PROJ" 2>&1)"
echo "$out" | grep -q "v3\.0" && ok "banner anuncia v3.0" || bad "banner nao menciona v3.0: $out"
python3 -c "
import json,sys
d=json.load(open('$PROJ/.agent/state.json'))
assert d['schema_version'].startswith('3.0'), d['schema_version']
assert d['session']['handoff'] is None, d['session'].get('handoff')
" && ok "schema_version=3.0 e session.handoff=null" || bad "state.json fora do template v3.0"
rm -rf "$T"

echo "== FR-006: --with-git-hook instala mode-gate.sh como hook local"
T="$(mktemp -d)"; trap 'rm -rf "$T"' RETURN
PROJ="$T/proj6"; mkdir -p "$PROJ"
git -C "$PROJ" init -q
run_setup "$PROJ" --with-git-hook >/dev/null 2>&1
HOOK="$PROJ/.git/hooks/pre-commit"
[ -e "$HOOK" ] && ok "hook instalado com a flag" || bad "flag --with-git-hook nao instalou hook"
rm -rf "$T"

echo "== FR-006 guard: sem a flag, nada de hook muda"
T="$(mktemp -d)"; trap 'rm -rf "$T"' RETURN
PROJ="$T/proj6b"; mkdir -p "$PROJ"
git -C "$PROJ" init -q
run_setup "$PROJ" >/dev/null 2>&1
[ ! -e "$PROJ/.git/hooks/pre-commit" ] || [ -f "$PROJ/.git/hooks/pre-commit.sample" ] && ok "sem flag: nenhum hook novo instalado" || bad "hook apareceu sem a flag"
rm -rf "$T"

echo
echo "$pass passaram, $fail falharam"
[ "$fail" = 0 ]
