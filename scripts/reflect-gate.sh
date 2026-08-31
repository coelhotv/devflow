#!/usr/bin/env bash
# reflect-gate.sh — gate de reflexão determinístico do RC6 (spec 058).
#
# Lê na stdin o $MERGED do ai-review.sh ({"summary":…,"findings":[…]}) e devolve o
# mesmo JSON com `refuted` e `refutation` nos findings. Zero LLM, zero quota.
#
#   RC6_REFLECT=annotate  (default)  marca `refuted:true`, mantém o finding
#   RC6_REFLECT=drop                 remove o finding refutado
#   RC6_REFLECT=0                    desliga (passthrough puro)
#
# ⚠️ O INVARIANTE (FR-004). `refuted:true` exige CONTRA-PROVA POSITIVA: o verificador
# rodou, respondeu, e a resposta contradiz o finding. Qualquer outro desfecho — classe
# não reconhecida, verificador ausente, erro, timeout, credencial faltando, resultado
# ambíguo — deixa o finding PASSAR. O modo de falha inaceitável desta spec não é deixar
# passar um falso positivo (custa atenção); é refutar um achado verdadeiro (custa o bug
# em produção, com o carimbo do gate por cima). A assimetria é o produto.

set -uo pipefail

REFLECT_MODE="${RC6_REFLECT:-annotate}"
REFLECT_TIMEOUT="${RC6_REFLECT_TIMEOUT:-120}"
REPO_ROOT="${RC6_REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"

rlog() { printf 'reflect: %s\n' "$*" >&2; }   # FR-009

if [ "$REFLECT_MODE" = "0" ]; then
  rlog "desligado (RC6_REFLECT=0) — passthrough"
  cat
  exit 0
fi

# T010 unifica: quando o gate for sourced pelo ai-review.sh, o run_bounded de lá (que
# preserva o fd 3) já existe e esta definição não sobrescreve.
if ! declare -f run_bounded >/dev/null 2>&1; then
  run_bounded() {
    local secs="$1"; shift
    exec 3<&0
    "$@" <&3 & local cmd_pid=$!
    exec 3<&-
    ( sleep "$secs"; kill -TERM "$cmd_pid" 2>/dev/null ) & local wd_pid=$!
    wait "$cmd_pid" 2>/dev/null; local rc=$?
    kill "$wd_pid" 2>/dev/null; wait "$wd_pid" 2>/dev/null
    return "$rc"
  }
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/rc6-reflect.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
cat > "$WORK/in.json"

# ---- T003 — classificador determinístico -------------------------------------
# Casa `issue`+`causation` contra padrões de classe. Sem LLM, sem heurística de
# similaridade. Classe não reconhecida => vazio => nenhum verificador roda => passa.
# Casar DUAS classes é ambiguidade, não escolha: vira `?` e também passa (FR-004).
python3 - "$WORK/in.json" > "$WORK/classes.tsv" <<'PY'
import json, re, sys, unicodedata

def norm(s):
    s = unicodedata.normalize('NFD', s or '')
    s = ''.join(c for c in s if unicodedata.category(c) != 'Mn')
    return s.lower()

PATTERNS = {
    'compile': [
        r'\bts\d{4}\b',
        r'syntax error', r'invalid syntax', r'sintaxe invalida',
        r'nao compila', r'quebra o build', r'falha no build',
    ],
    'schema': [
        r'\b42703\b',
        r'coluna\s+\S+\s+nao existe', r'column\s+\S+\s+does not exist',
        r'nao existe (?:em|na tabela)', r'tabela inexistente', r'relation .* does not exist',
    ],
}

data = json.load(open(sys.argv[1], encoding='utf-8'))
for i, f in enumerate(data.get('findings', [])):
    text = norm((f.get('issue') or '') + ' ' + (f.get('causation') or ''))
    hits = [c for c, pats in PATTERNS.items() if any(re.search(p, text) for p in pats)]
    cls = hits[0] if len(hits) == 1 else ('?' if len(hits) > 1 else '')
    print('\t'.join([str(i), cls, f.get('file', '')]))
PY

# ---- verificadores -----------------------------------------------------------
# Contrato: recebem o arquivo TSV dos findings da sua classe (idx \t file) e escrevem
# em stdout `idx \t OUTCOME \t evidência`.
#   REFUTED       contra-prova positiva; é o ÚNICO desfecho que refuta
#   INCONCLUSIVE  verificador rodou e não contradisse
#   UNAVAILABLE   pré-requisito ausente (credencial, tsconfig, binário)
#   ERROR         verificador quebrou
#   TIMEOUT       estourou RC6_REFLECT_TIMEOUT
# Nenhum outcome além de REFUTED altera o finding.

# T005 — verificador de compile. Reusa a LISTA de programas do strict-island.sh
# (R-283/R-284), não o script: aquele é gate de ratchet do repo inteiro, este pergunta
# uma coisa só — "há diagnóstico NESTE arquivo?".
#   sem diagnóstico no arquivo citado => o finding ("não compila") está errado => REFUTED
#   com diagnóstico                    => o finding pode estar certo => INCONCLUSIVE
# Teto de custo (T010/FR-007): UM tsc por PROGRAMA por run, não um por finding.
_reflect_program_for() {
  case "$1" in
    api/*)         printf 'api/tsconfig.json' ;;
    server/*)      printf 'server/tsconfig.json' ;;
    apps/mobile/*) printf 'apps/mobile/tsconfig.json' ;;
    apps/web/*)    printf 'apps/web/tsconfig.json' ;;
    packages/*)    printf 'tsconfig.strict.json' ;;
    *)             printf '' ;;
  esac
}

verify_compile() {
  local batch="$1"
  command -v npx >/dev/null 2>&1 || {
    awk -F'\t' '{print $1"\tUNAVAILABLE\tnpx não encontrado no PATH"}' "$batch"; return 0; }

  # agrupa por programa
  local progs=""
  while IFS=$'\t' read -r idx file; do
    local prog; prog="$(_reflect_program_for "$file")"
    if [ -z "$prog" ]; then
      printf '%s\tUNAVAILABLE\tarquivo %s não mapeia para nenhum programa tsc conhecido\n' "$idx" "$file"
      continue
    fi
    if [ ! -f "$REPO_ROOT/$prog" ]; then
      printf '%s\tUNAVAILABLE\ttsconfig ausente: %s\n' "$idx" "$prog"
      continue
    fi
    printf '%s\t%s\t%s\n' "$idx" "$file" "$prog" >> "$WORK/compile.batch"
    case " $progs " in *" $prog "*) ;; *) progs="$progs $prog" ;; esac
  done < "$batch"
  [ -f "$WORK/compile.batch" ] || return 0

  local prog
  for prog in $progs; do
    local safe out rc
    safe="$(printf '%s' "$prog" | tr '/.' '__')"
    out="$WORK/tsc.$safe.txt"
    ( cd "$REPO_ROOT" && npx tsc -p "$prog" --noEmit ) > "$out" 2>&1
    rc=$?
    # rc != 0 com diagnósticos é o caso NORMAL (o programa tem erros); rc != 0 SEM
    # nenhuma linha ': error TS' é o tsc falhando em rodar — indecidível, não refuta.
    # 🔴 REFUTED de compile é "o tsc rodou este programa e não reclamou DESTE arquivo".
    # Duas coisas se parecem com isso e não são, e ambas produziriam refutação FALSA:
    #   (a) o tsc não rodou (config quebrada, npx resolvendo outro binário — visto ao
    #       vivo: `npx tsc` num repo sem tsc local imprime banner e sai 0);
    #   (b) o tsc parou ANTES de tipar (erro de configuração TS5xxx/TS6xxx, que vem sem
    #       âncora `arquivo(linha,coluna)`), então "nenhum diagnóstico no arquivo" só
    #       significa que nada foi analisado.
    # Exigir prova de que o programa foi realmente tipado é o que mantém a assimetria.
    local diags cfg_only
    diags="$(grep -cE ': error TS' "$out" | tr -d ' ')"
    [ -n "$diags" ] || diags=0
    if [ "$rc" -eq 0 ] && [ -s "$out" ]; then
      awk -F'\t' -v p="$prog" '$3==p {print $1"\tERROR\ttsc -p "p" saiu 0 mas escreveu saída — provavelmente não é o tsc (npx resolveu outro binário)"}' "$WORK/compile.batch"
      continue
    fi
    if [ "$rc" -ne 0 ] && [ "$diags" -eq 0 ]; then
      awk -F'\t' -v p="$prog" '$3==p {print $1"\tERROR\ttsc -p "p" falhou sem emitir diagnóstico"}' "$WORK/compile.batch"
      continue
    fi
    # diagnóstico sem âncora arquivo(linha,coluna) = erro de CONFIGURAÇÃO, não de tipo
    cfg_only=0
    if [ "$diags" -gt 0 ] && ! grep -qE '^[^ ].*\([0-9]+,[0-9]+\): error TS' "$out"; then cfg_only=1; fi
    if [ "$cfg_only" -eq 1 ]; then
      awk -F'\t' -v p="$prog" '$3==p {print $1"\tERROR\ttsc -p "p" só emitiu erro de configuração (sem âncora arquivo:linha); o programa não chegou a ser tipado"}' "$WORK/compile.batch"
      continue
    fi
    while IFS=$'\t' read -r idx file fprog; do
      [ "$fprog" = "$prog" ] || continue
      if grep -qE "^$(printf '%s' "$file" | sed 's/[].[^$*\/]/\\&/g')\(.*: error TS" "$out"; then
        printf '%s\tINCONCLUSIVE\ttsc -p %s reporta diagnóstico em %s; o finding pode estar certo\n' "$idx" "$prog" "$file"
      else
        printf '%s\tREFUTED\ttsc -p %s --noEmit: nenhum diagnóstico em %s (%s linhas de erro no programa, nenhuma neste arquivo)\n' \
          "$idx" "$prog" "$file" "$diags"
      fi
    done < "$WORK/compile.batch"
  done
}

# T006 — verificador de schema. Segue o gate de saída do R-295: o select EXECUTADO
# contra o PostgREST é a verdade, não o information_schema lido por tipo gerado.
#   HTTP 200  => o objeto EXISTE => o finding ("não existe") está errado => REFUTED
#   42703     => a coluna de fato não existe => o finding está CERTO => INCONCLUSIVE
#   42501     => grant faltando: não dá para saber => UNAVAILABLE (o finding passa)
#   PGRST205  => tabela inexistente: o finding pode estar certo => INCONCLUSIVE
verify_schema() {
  local batch="$1"
  local env_file="$REPO_ROOT/.env.local"
  local url="${SUPABASE_URL:-${VITE_SUPABASE_URL:-}}"
  local key="${SUPABASE_SERVICE_ROLE_KEY:-${VITE_SUPABASE_ANON_KEY:-}}"
  if [ -z "$url" ] || [ -z "$key" ]; then
    if [ -f "$env_file" ]; then
      # subshell: as credenciais não vazam para o ambiente do gate nem para o log
      url="${url:-$(set -a; . "$env_file" >/dev/null 2>&1; printf '%s' "${SUPABASE_URL:-${VITE_SUPABASE_URL:-}}")}"
      key="${key:-$(set -a; . "$env_file" >/dev/null 2>&1; printf '%s' "${SUPABASE_SERVICE_ROLE_KEY:-${VITE_SUPABASE_ANON_KEY:-}}")}"
    fi
  fi
  if [ -z "$url" ] || [ -z "$key" ]; then
    awk -F'\t' '{print $1"\tUNAVAILABLE\tsem credencial Supabase (SUPABASE_URL/KEY ausentes e .env.local não legível)"}' "$batch"
    return 0
  fi

  while IFS=$'\t' read -r idx _file; do
    # O par tabela.coluna sai do texto do finding. Ambíguo (nenhum par, ou pares
    # divergentes) NÃO é chute: é AMBIGUOUS e o finding passa.
    local pair
    pair="$(python3 - "$WORK/in.json" "$idx" <<'PYX'
import json, re, sys, unicodedata
d = json.load(open(sys.argv[1], encoding='utf-8'))
f = d['findings'][int(sys.argv[2])]
raw = (f.get('issue') or '') + ' ' + (f.get('causation') or '')
cands = set()
for t, c in re.findall(r'\b([a-z][a-z0-9_]{2,})\.([a-z][a-z0-9_]{2,})\b', raw):
    cands.add((t, c))
if not cands:
    # forma "coluna `X` não existe em `Y`"
    def norm(s):
        s = unicodedata.normalize('NFD', s)
        return ''.join(ch for ch in s if unicodedata.category(ch) != 'Mn').lower()
    m = re.search(r'`([a-z0-9_]+)`[^`]{0,40}(?:em|na tabela)\s+`([a-z0-9_]+)`', norm(raw))
    if m:
        cands.add((m.group(2), m.group(1)))
print('%s.%s' % cands.pop() if len(cands) == 1 else '')
PYX
)"
    if [ -z "$pair" ]; then
      printf '%s\tAMBIGUOUS\tnão foi possível extrair um único par tabela.coluna do texto\n' "$idx"
      continue
    fi
    local tbl="${pair%%.*}" col="${pair##*.}" code body
    body="$(curl -s -m 20 -w '\n%{http_code}' \
      "$url/rest/v1/$tbl?select=$col&limit=1" \
      -H "apikey: $key" -H "Authorization: Bearer $key" 2>/dev/null)"
    code="$(printf '%s' "$body" | tail -1)"
    body="$(printf '%s' "$body" | sed '$d' | head -c 200)"
    case "$code" in
      200) printf '%s\tREFUTED\tGET /rest/v1/%s?select=%s -> HTTP 200; o objeto EXISTE. Resposta: %s\n' "$idx" "$tbl" "$col" "$body" ;;
      400|404)
        case "$body" in
          *42703*)   printf '%s\tINCONCLUSIVE\t42703 confirma o finding: %s.%s não existe\n' "$idx" "$tbl" "$col" ;;
          *42501*)   printf '%s\tUNAVAILABLE\t42501 (grant): a credencial não enxerga %s; indecidível\n' "$idx" "$tbl" ;;
          *PGRST205*|*PGRST200*) printf '%s\tINCONCLUSIVE\t%s: objeto/relacionamento não resolvido\n' "$idx" "$code" ;;
          *)         printf '%s\tINCONCLUSIVE\tHTTP %s inesperado: %s\n' "$idx" "$code" "$body" ;;
        esac ;;
      000) printf '%s\tUNAVAILABLE\tsem resposta do PostgREST (rede/timeout do curl)\n' "$idx" ;;
      *)   printf '%s\tINCONCLUSIVE\tHTTP %s não interpretável: %s\n' "$idx" "$code" "$body" ;;
    esac
  done < "$batch"
}

# ---- T010 — teto de custo: 1 execução por verificador por run ----------------
: > "$WORK/verdicts.tsv"
for cls in compile schema; do
  awk -F'\t' -v c="$cls" '$2==c {print $1"\t"$3}' "$WORK/classes.tsv" > "$WORK/batch.$cls"
  [ -s "$WORK/batch.$cls" ] || continue
  n=$(wc -l < "$WORK/batch.$cls" | tr -d ' ')
  rlog "classe=$cls findings=$n — acionando verificador (1 execução)"
  if run_bounded "$REFLECT_TIMEOUT" "verify_$cls" "$WORK/batch.$cls" >> "$WORK/verdicts.tsv" 2>"$WORK/err.$cls"; then :; else
    rc=$?
    if [ "$rc" -ge 124 ]; then
      rlog "classe=$cls — TIMEOUT após ${REFLECT_TIMEOUT}s; findings PASSAM"
      awk -F'\t' -v t="$REFLECT_TIMEOUT" '{print $1"\tTIMEOUT\tverificador excedeu "t"s"}' "$WORK/batch.$cls" >> "$WORK/verdicts.tsv"
    else
      rlog "classe=$cls — verificador saiu $rc; findings PASSAM"
      awk -F'\t' -v r="$rc" '{print $1"\tERROR\tverificador saiu "r}' "$WORK/batch.$cls" >> "$WORK/verdicts.tsv"
    fi
  fi
done

# ---- T004 — núcleo assimétrico + T007 refutação citável ----------------------
python3 - "$WORK/in.json" "$WORK/classes.tsv" "$WORK/verdicts.tsv" "$REFLECT_MODE" <<'PY'
import json, sys

src, classes_f, verdicts_f, mode = sys.argv[1:5]
data = json.load(open(src, encoding='utf-8'))
findings = data.get('findings', [])

cls = {}
for line in open(classes_f, encoding='utf-8'):
    if not line.strip(): continue
    i, c, _ = (line.rstrip('\n').split('\t') + ['', ''])[:3]
    cls[int(i)] = c

verdict = {}
for line in open(verdicts_f, encoding='utf-8'):
    if not line.strip(): continue
    parts = line.rstrip('\n').split('\t')
    if len(parts) < 2: continue
    i, outcome = parts[0], parts[1]
    evidence = parts[2] if len(parts) > 2 else ''
    try: verdict[int(i)] = (outcome, evidence)
    except ValueError: continue

kept = []
for i, f in enumerate(findings):
    c = cls.get(i, '')
    outcome, evidence = verdict.get(i, ('NOT_RUN', ''))

    # 🔴 O invariante. Só REFUTED com evidência citável refuta. Refutação sem evidência
    # trocaria a alucinação do revisor pela do gate (T007/SC-003), então é tratada como
    # bug e o finding passa — não como refutação silenciosa.
    refuted = (outcome == 'REFUTED' and bool(evidence.strip()))

    why = {
        'NOT_RUN': 'classe não reconhecida' if not c else 'classe %s sem verificador' % c,
        'UNAVAILABLE': 'verificador indisponível',
        'INCONCLUSIVE': 'verificador não contradisse o finding',
        'ERROR': 'verificador falhou',
        'TIMEOUT': 'verificador estourou o tempo',
        'AMBIGUOUS': 'verificador não conseguiu isolar o alvo no texto do finding',
    }.get(outcome, '')
    if c == '?':
        why = 'classificação ambígua (mais de uma classe casou)'
    if outcome == 'REFUTED' and not refuted:
        why = 'REFUTED sem evidência citável — tratado como bug do gate, finding preservado'

    sys.stderr.write('reflect: finding[%d] %s classe=%s verificador=%s desfecho=%s -> %s\n' % (
        i, f.get('file', '?'), c or '-', c or '-', outcome,
        'REFUTADO' if refuted else 'passa (%s)' % (why or outcome)))

    if refuted:
        f['refuted'] = True
        f['refutation'] = evidence
        if mode == 'drop':
            continue
    else:
        f['refuted'] = False
    kept.append(f)

data['findings'] = kept
json.dump(data, sys.stdout, ensure_ascii=False, indent=2)
sys.stdout.write('\n')
PY
