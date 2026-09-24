#!/usr/bin/env bash
# engine-core.sh — funcoes agnosticas de motor, compartilhadas pelos clientes RC6 (001/slice F1).
#
# ENGINE_CORE_VERSION e um CONTRATO: o consumidor cita a versao que espera e falha alto se
# divergir. Sem isso, um core atualizado por baixo de um consumidor velho produz o pior modo
# de falha possivel — comportamento diferente, silencio total.
#
# O QUE MORA AQUI: tudo que nao sabe o que e um PR, um finding ou uma severidade.
#   log               — prefixo [rc6] em stderr
#   clamp_lines       — trunca linhas em $IDX_LINE_MAX caracteres (le a env do consumidor)
#   clamp_index       — alias legado de clamp_lines
#   run_bounded       — hang guard com preservacao de stdin (fd 3)
#   unwrap_structured — desembrulha envelope JSON de agy/claude
#   run_engine        — invoca agy|claude e valida saida nao-vazia
#   engine_err_hint   — 1a linha util do stderr do motor, para o log dizer POR QUE caiu
#   ab_counts         — conta severidades c/h/m/l de N arquivos de findings
#   ab_total          — soma "c/h/m/l"
#   probe_engines     — (1.1.0) detecta agy/claude e as flags que cada binario aceita
#   build_engine_args — (1.1.0) monta AGY_ARGS[]/CLAUDE_ARGS[] sem tools, sem slash, com schema
#   egress_scan       — (1.1.0) conta linhas com formato de PII real num arquivo
#   egress_guard      — (1.1.0) bloqueia (return 3) o envio a LLM externo se houver PII
#   fail_open         — (1.1.0) imprime o JSON de "revisao indisponivel" e sai 0
#   dur_secs / classify_engine_err / rc6_status_init / rc6_status / rc6_budget_left /
#   rc6_second_round_ok / run_engine_resilient — (1.2.0) resiliencia do motor (spec 003)
#
# O QUE NAO MORA AQUI: montagem de preambulo, selecao de arquivos, gate de reflexao,
# publicacao no PR, schema de review. Isso e dominio, nao motor.
# POR QUE probe/args/egress/fail-open SUBIRAM na 1.1.0 (001/F2): com dois consumidores, cada
# um com a sua copia, a primeira correcao de uma flag de SEGURANCA (--tools "",
# --disable-slash-commands) entraria num e nao no outro — e o no-core-shadowing nao pega
# bloco inline, so funcao. Controle de seguranca duplicado e controle que diverge.
#
# CONTRATO COM O CONSUMIDOR (o core LE estas variaveis, nunca as define):
#   WORKDIR        — dir temporario, ja criado         (run_engine, engine_err_hint)
#   IDX_LINE_MAX   — inteiro                           (clamp_lines)
#   AGY_SCHEMA / CLAUDE_SCHEMA / AGY_ARGS[] /
#   CLAUDE_ARGS[] / PASSB_TIMEOUT                      (run_engine)
#   AGY_TIMEOUT / RC6_AGY_MODEL                        (build_engine_args)
#   RC6_ENGINE_CLAUDE / RC6_ALLOW_SENSITIVE            (probe_engines / egress_guard; opcionais)
# ...e ESCREVE estas, que passam a ser globais do consumidor apos a chamada:
#   HAVE_AGY HAVE_CLAUDE AGY_SCHEMA AGY_NOSLASH CLAUDE_SCHEMA CLAUDE_NOSLASH CLAUDE_NOPERSIST
#                                                      (probe_engines)
#   AGY_ARGS[] CLAUDE_ARGS[]                           (build_engine_args)
#   ENGINE_LAST_* RC6_SPENT BREAKER_OPEN BREAKER_STREAK ENGINE_KILLED (run_engine_resilient)
# O core tambem NAO faz `set -euo pipefail`: quem define o modo de erro e o script principal.
# ⚠️ Por isso toda funcao que termina num teste (`[ X ] && ...`) fecha com `return 0`: sob o
# `set -e` do consumidor, um teste falso como ULTIMO comando vira o exit status da funcao e
# mata o script em silencio. E a classe do AC-1 da spec 001.
#
# Uso:  source "$(dirname "${BASH_SOURCE[0]}")/lib/engine-core.sh"

# shellcheck disable=SC2034  # lido pelo consumidor apos o source — este e o contrato
ENGINE_CORE_VERSION="1.2.0"


log() { printf '\033[2m[rc6]\033[0m %s\n' "$*" >&2; }

# 🔴 Truncagem por CARACTERE, não por byte. `cut -c` (BSD, locale C) e `awk substr`
# cortam BYTES: numa linha em português o corte cai no meio de um multibyte e deixa
# um \xc3 órfão ("transação" -> "transa\xc3"). O preâmbulo inteiro vira UTF-8
# inválido e o `agy` REJEITA o payload em 0s, com status ERROR e stderr VAZIO —
# diagnosticado no PR dosiq#798, onde parecia falha de motor/quota/sandbox. O
# `claude` tolera, então a quebra só aparecia como "agy morreu" (Pass B cobria).
# `errors=replace` também blinda contra lixo já presente num índice.
clamp_lines() { # $1=file — trunca cada linha em $IDX_LINE_MAX CARACTERES
  python3 -c '
import sys
path, n = sys.argv[1], int(sys.argv[2])
with open(path, encoding="utf-8", errors="replace") as f:
    for line in f:
        sys.stdout.write(line.rstrip("\n")[:n] + "\n")
' "$1" "$IDX_LINE_MAX"
}

clamp_index() { clamp_lines "$1"; }

# ---- run an engine: $1=engine(agy|claude) $2=prompt-file $3=out-json --------
# SC-SEC1 / ADR-069 §16: the reviewer reads an UNTRUSTED diff, so it must run
# text->JSON with NO tool access (no shell/file-write/MCP). A prompt-injected
# diff can otherwise coerce execution.
#   claude: --tools "" disables all built-in tools; --strict-mcp-config with no
#           --mcp-config disables every MCP server. Prompt via STDIN (argv would
#           risk ARG_MAX on fat tier-2 contexts).
#   agy:    has no explicit no-tools flag (re-checked 2026-08-02); closest is
#           --sandbox (terminal restrictions) + --mode plan (no edits) +
#           --disable-slash-commands (1.1.9 made print mode expand slash commands
#           and skills — an untrusted diff must not reach that expander). Prompt
#           must be argv (-p requires an argument; no stdin support).
# Portable wall-clock bound (no `timeout`/`gtimeout` on macOS). Runs "$@" and kills
# it after $1 seconds. Guards against an engine that HANGS instead of erroring —
# critical for claude, which (unlike agy's --print-timeout) has no built-in cap and
# could otherwise wedge the whole RC6 while waiting on quota to free up.
run_bounded() {
  local secs="$1"; shift
  # 🔴 `cmd &` num script NÃO-INTERATIVO redireciona o stdin do filho para /dev/null
  # (POSIX: sem job control, background job herda /dev/null). Sem o `<&3` abaixo, o
  # `< "$pf"` que o chamador aplica a run_bounded é engolido e o claude recebe entrada
  # vazia -> "Input must be provided either through stdin or as a prompt argument when
  # using --print" -> pass B falha SEMPRE. Ficou invisível enquanto o agy esteve
  # saudável (o fallback cobria); só apareceu quando o agy caiu. Preservar o fd é o que
  # torna o hang-guard compatível com engine que lê prompt do stdin.
  exec 3<&0
  "$@" <&3 & local cmd_pid=$!
  exec 3<&-
  ( sleep "$secs"; kill -TERM "$cmd_pid" 2>/dev/null ) & local wd_pid=$!
  wait "$cmd_pid" 2>/dev/null; local rc=$?
  kill "$wd_pid" 2>/dev/null; wait "$wd_pid" 2>/dev/null
  # (1.2.0) ENGINE_KILLED: o classificador precisa saber que foi o guard, nao o motor, que
  # encerrou — o stderr de um processo morto por TERM nao diz nada.
  [ "$rc" -ge 124 ] && { ENGINE_KILLED=1; log "engine killed after ${secs}s wall-clock (hang guard)"; }
  return "$rc"
}

# Normalize an engine's structured envelope down to the bare review object.
# The two engines agree on the payload and disagree on the wrapper:
#   agy:    {"status":"SUCCESS", "structured_output":{...}, "response":"..."}
#   claude: [ ..., {"type":"result","subtype":"success","structured_output":{...}} ]
# Both converge on structured_output, so the merge step stops guessing the wire
# format. Non-zero exit on a FAILED or malformed envelope is the point: it makes
# run_engine report failure, which excludes the chunk from coverage instead of
# letting it count as reviewed while contributing nothing.
unwrap_structured() { # $1=engine $2=raw-envelope $3=out-json
  python3 - "$1" "$2" "$3" <<'PY'
import sys, json, re
eng, src, dst = sys.argv[1], sys.argv[2], sys.argv[3]
try:
    d = json.load(open(src))
except Exception as e:
    print("envelope is not JSON: %s" % e, file=sys.stderr); sys.exit(1)

if eng == "claude":
    events = d if isinstance(d, list) else [d]
    results = [x for x in events if isinstance(x, dict) and x.get("type") == "result"]
    if not results:
        print("no result event in claude envelope", file=sys.stderr); sys.exit(1)
    r = results[-1]
    ok = r.get("subtype") == "success" and not r.get("is_error")
    text = r.get("result")
    why = r.get("subtype") or r.get("stop_reason") or "unknown"
else:
    r = d if isinstance(d, dict) else {}
    ok = r.get("status") == "SUCCESS"
    text = r.get("response")
    why = r.get("error") or r.get("status") or "unknown"

if not ok:
    print("engine reported failure: %s" % why, file=sys.stderr); sys.exit(1)

obj = r.get("structured_output")
if not isinstance(obj, dict):
    # Schema not honored (engine ignored it, or answered with prose): recover from
    # the text field with the legacy fence-stripping heuristic before giving up.
    t = re.sub(r'^```(?:json)?\s*|\s*```$', '', (text or "").strip(), flags=re.S)
    try:
        obj = json.loads(t)
    except Exception:
        i, j = t.find('{'), t.rfind('}')
        obj = None
        if i >= 0 and j > i:
            try: obj = json.loads(t[i:j+1])
            except Exception: obj = None
if not isinstance(obj, dict) or "findings" not in obj:
    print("envelope carried no usable review object (no structured_output, unparseable text)",
          file=sys.stderr)
    sys.exit(1)
json.dump(obj, open(dst, "w"), ensure_ascii=False)

# Token accounting to STDOUT for the caller to log. The envelope is the only place
# it exists and $WORKDIR dies in the EXIT trap, so not surfacing it here loses it.
# Required by the 034-D measurement protocol v2 (`tok=` in the Nota column) and by
# the open question of whether input_tokens stops tracking payload bytes above the
# ~160KB budget — which would finally MEASURE the silent sampling of Achado
# 034-D.1 instead of inferring it from divergent runs (056/T038).
u = r.get("usage") or {}
if isinstance(u, dict) and u:
    ins = u.get("input_tokens", "?")
    outs = u.get("output_tokens", "?")
    cache = u.get("cache_read_tokens", u.get("cache_read_input_tokens"))
    bits = ["input=%s" % ins, "output=%s" % outs]
    if cache not in (None, ""): bits.append("cache_read=%s" % cache)
    cost = r.get("total_cost_usd")
    if cost not in (None, ""): bits.append("cost=$%.4f" % cost)
    print(" ".join(bits))
PY
}

run_engine() {
  local engine="$1" pf="$2" out="$3" raw="$3.raw"
  case "$engine" in
    # stdin closed (</dev/null): headless agy must never block waiting for input.
    # (1.2.0) run_bounded tambem no agy: o --print-timeout dele e do proprio CLI, e um CLI
    # travado (MCP pendurado, 2026-08-02) nao o honra. Guard = timeout do agy + folga.
    agy)
      local agy_cap=$(( $(dur_secs "$AGY_TIMEOUT") + ${RC6_HANG_GRACE:-30} ))
      if [ "$AGY_SCHEMA" = 1 ]; then
        # (1.2.0) exit != 0 NAO dispensa o envelope: o agy pode sair com erro E com o motivo
        # dentro dele ({"status":"ERROR","error":"...503..."}). Sem desembrulhar aqui, o texto
        # some e o classificador ve `fatal` onde havia `transient` (E1, segundo caminho).
        run_bounded "$agy_cap" agy "${AGY_ARGS[@]}" -p "$(cat "$pf")" \
          > "$raw" 2>"$WORKDIR/agy.err" < /dev/null \
          || { unwrap_structured agy "$raw" /dev/null >/dev/null 2>>"$WORKDIR/agy.err" || true; return 1; }
        local usage_agy
        usage_agy="$(unwrap_structured agy "$raw" "$out" 2>>"$WORKDIR/agy.err")" || return 1
        [ -n "$usage_agy" ] && log "  agy usage: $usage_agy"
      else
        run_bounded "$agy_cap" agy "${AGY_ARGS[@]}" -p "$(cat "$pf")" \
          > "$out" 2>"$WORKDIR/agy.err" < /dev/null || return 1
      fi ;;
    # Wrapped in run_bounded: a rate-limited claude that hangs is killed after
    # PASSB_TIMEOUT and treated as failed -> pass B falls back to agy (no wedge).
    claude)
      if [ "$CLAUDE_SCHEMA" = 1 ]; then
        run_bounded "$PASSB_TIMEOUT" claude "${CLAUDE_ARGS[@]}" -p \
          < "$pf" > "$raw" 2>"$WORKDIR/claude.err" || return 1
        local usage_claude
        usage_claude="$(unwrap_structured claude "$raw" "$out" 2>>"$WORKDIR/claude.err")" || return 1
        [ -n "$usage_claude" ] && log "  claude usage: $usage_claude"
      else
        run_bounded "$PASSB_TIMEOUT" claude "${CLAUDE_ARGS[@]}" -p \
          < "$pf" > "$out" 2>"$WORKDIR/claude.err" || return 1
      fi ;;
  esac
  # exit 0 with empty/whitespace output = engine degraded, not success
  [ -s "$out" ] && grep -q '[^[:space:]]' "$out"
}

# Primeira linha útil do stderr do motor, para o log de falha dizer POR QUE caiu.
# Sem isto, "unavailable/failed" cobre indistintamente: binário ausente, quota
# estourada, hang morto pelo guard e erro de invocação — e o WORKDIR é apagado no
# EXIT, então a evidência morre junto. Diagnosticar exigia reexecutar o script com o
# trap desarmado (foi o que custou 3 runs no PR dosiq#782, onde a causa real era o
# stdin comido pelo `&` e nada no log apontava para lá).
engine_err_hint() { # $1=engine
  local ef="$WORKDIR/$1.err"
  [ -s "$ef" ] || { printf 'no stderr'; return; }
  grep -m1 '[^[:space:]]' "$ef" 2>/dev/null | cut -c1-160
}

# c/h/m/l counts across a set of engine outputs; "-" when nothing parsed.
ab_counts() {
  python3 - "$@" <<'PY'
import sys, json
sev = {"critical":0,"high":0,"medium":0,"low":0}
for p in sys.argv[1:]:
    try: d = json.load(open(p))
    except Exception: continue
    for f in (d.get("findings") or []):
        s = str(f.get("severity","")).lower()
        if s in sev: sev[s] += 1
print("%d/%d/%d/%d" % (sev["critical"],sev["high"],sev["medium"],sev["low"]))
PY
}

ab_total() { printf '%s' "$1" | tr '/' '+' | bc; }


# ---- (1.1.0) engine capability probe (no API call, no quota) ----------------
# Structured output (--output-format json + --json-schema) landed in agy 1.1.8
# and is present in claude 2.x. Feature-detect instead of assuming: an older
# binary would reject the flag and fail EVERY chunk, turning an enhancement into
# a total blackout. When absent we fall back to the legacy text invocation, which
# still works — just without the schema guarantees.
# Quota guard: claude is BOTH the pass-B domain engine AND the coder-agent engine,
# and it has a tighter 5h/weekly quota than agy's Gemini pool. Set RC6_ENGINE_CLAUDE=0
# when the claude quota is low to keep RC6 off it entirely — pass B then falls back to
# agy chunked (existing path), so tier2 keeps full coverage on the roomier engine.
# A ORDEM dos `log` abaixo e a mesma de antes da extracao: a baseline do ai-review.sh
# captura stderr e acusaria uma troca.
probe_engines() {
  HAVE_AGY=0;    command -v agy    >/dev/null && HAVE_AGY=1
  HAVE_CLAUDE=0; command -v claude >/dev/null && HAVE_CLAUDE=1
  [ "${RC6_ENGINE_CLAUDE:-1}" = 0 ] && { HAVE_CLAUDE=0; log "RC6_ENGINE_CLAUDE=0 — claude disabled; pass B will use agy"; }
  AGY_SCHEMA=0; AGY_NOSLASH=0; CLAUDE_SCHEMA=0; CLAUDE_NOSLASH=0; CLAUDE_NOPERSIST=0
  local help
  if [ "$HAVE_AGY" = 1 ]; then
    help="$(agy --help 2>&1 || true)"
    case "$help" in *--json-schema*)            AGY_SCHEMA=1 ;; esac
    case "$help" in *--disable-slash-commands*) AGY_NOSLASH=1 ;; esac
    [ "$AGY_SCHEMA" = 0 ] && log "agy sem --json-schema (pre-1.1.8) — usando invocação legada em texto"
  fi
  if [ "$HAVE_CLAUDE" = 1 ]; then
    help="$(claude --help 2>&1 || true)"
    case "$help" in *--json-schema*)            CLAUDE_SCHEMA=1 ;; esac
    case "$help" in *--disable-slash-commands*) CLAUDE_NOSLASH=1 ;; esac
    case "$help" in *--no-session-persistence*) CLAUDE_NOPERSIST=1 ;; esac
    [ "$CLAUDE_SCHEMA" = 0 ] && log "claude sem --json-schema — usando invocação legada em texto"
  fi
  return 0
}

# ---- (1.1.0) engine argv: $1=schema-file ------------------------------------
# --disable-slash-commands: agy 1.1.9 made print mode EXPAND slash commands and
# skills, and the payload is UNTRUSTED text — the same reason SC-SEC1 already
# forbids tools. Note --json-schema makes claude expose a `StructuredOutput` tool
# despite --tools "": that is the delivery mechanism for the structured answer (no
# shell/file/MCP reach), so the SC-SEC1 property holds, but the `init` event will
# list one tool. Do not read that as a broken guard.
# --setting-sources "": do NOT load user/project settings (CLAUDE.md, skills,
# plugins). The engine's context is 100% the explicit prompt — cheaper per run
# (no duplicate project payload) AND stronger independence (SC-007).
build_engine_args() {
  local schema="$1"
  AGY_ARGS=(--sandbox --print-timeout "$AGY_TIMEOUT" --model "$RC6_AGY_MODEL")
  [ "$AGY_NOSLASH" = 1 ] && AGY_ARGS+=(--disable-slash-commands)
  [ "$AGY_SCHEMA"  = 1 ] && AGY_ARGS+=(--output-format json --json-schema "$schema")
  CLAUDE_ARGS=(--model sonnet --tools "" --strict-mcp-config --setting-sources "")
  [ "$CLAUDE_NOSLASH" = 1 ]   && CLAUDE_ARGS+=(--disable-slash-commands)
  [ "$CLAUDE_NOPERSIST" = 1 ] && CLAUDE_ARGS+=(--no-session-persistence)
  [ "$CLAUDE_SCHEMA" = 1 ]    && CLAUDE_ARGS+=(--output-format json --json-schema "$(cat "$schema")")
  return 0
}

# ---- (1.1.0) egress guard (SC-SEC5/T039) ------------------------------------
# O texto sai da maquina para um LLM externo. Num app de saude so fixtures SINTETICAS podem
# sair: procura formatos de PII real (e-mail, CPF, celular BR) e para, salvo override.
# Heuristica, nao prova: o override do operador e a responsabilizacao documentada.
#   $2=added  so linhas `+` (diff: o que ja estava na base nao e novidade do autor)
#   $2=all    arquivo inteiro (artefato do second-opinion: nao ha "adicionado")
egress_scan() { # $1=file $2=added|all -> contagem em stdout
  { if [ "$2" = added ]; then grep -E '^\+' "$1"; else cat "$1"; fi; } \
    | grep -EIv 'example\.(com|org)|@(test|dummy|fixture)\.|lorem' \
    | grep -oEc '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}|[0-9]{3}\.[0-9]{3}\.[0-9]{3}-[0-9]{2}|\(?[0-9]{2}\)?[[:space:]-]?9[0-9]{4}-[0-9]{4}' \
    || true
}

# $1=file $2=added|all $3=comando que o operador roda para inspecionar (vai na mensagem)
# return 3 = bloqueado. O CHAMADOR decide sair (`|| exit $?`): o core nao encerra processo alheio.
egress_guard() {
  local hits
  hits="$(egress_scan "$1" "$2")"
  if [ "${hits:-0}" -gt 0 ] && [ "${RC6_ALLOW_SENSITIVE:-0}" != 1 ]; then
    if [ "$2" = added ]; then   # texto do RC6 byte a byte — a baseline e o teste de egress o comparam
      echo "⛔ egress guard: $hits linha(s) adicionada(s) com formato de e-mail/CPF/telefone no diff." >&2
      echo "   Diffs vão a LLM externo (SC-SEC5) — só fixtures SINTÉTICAS podem sair." >&2
    else
      echo "⛔ egress guard: $hits linha(s) com formato de e-mail/CPF/telefone no artefato." >&2
      echo "   O artefato vai a LLM externo (SC-SEC5) — só dados SINTÉTICOS podem sair." >&2
    fi
    echo "   Inspecione: $3 | grep -nE '@|[0-9]{3}\\.[0-9]{3}'" >&2
    echo "   Se for sintético, re-rode com RC6_ALLOW_SENSITIVE=1." >&2
    return 3
  fi
  return 0
}

# ---- (1.2.0) resiliencia do motor (spec 003) ---------------------------------
# POR QUE: um 503 "no capacity" do pool do MODELO (dosiq#835) passa em minutos, mas o RC6
# rodava cada chunk uma vez so — 3 de 4 chunks perdidos por um pico. E o 503 chega DENTRO do
# envelope (status != SUCCESS, texto no campo `error`), nao no stderr do CLI: o classificador
# le o arquivo de erro da tentativa, onde o unwrap_structured tambem escreve (achado E1).
#
# Camadas, da mais barata a mais cara: classificar -> repetir so `transient`, com backoff ->
# modelo alternativo (outro pool de capacidade) -> segunda rodada no fim da fila (quem decide e
# o consumidor, com rc6_second_round_ok). Tudo sob UM orcamento de tempo extra por run.
#
# Env (todas opcionais):
#   RC6_RETRIES=2            tentativas extras por chamada; 0 desliga retry E segunda rodada
#   RC6_BACKOFF="30 90"      espera antes da tentativa extra N (a ultima se repete)
#   RC6_JITTER=1             soma ate +1/3 aleatorio a cada espera
#   RC6_RETRY_BUDGET=300     segundos extras no run inteiro (esperas + tentativas extras)
#   RC6_BREAKER=3            falhas `transient` seguidas que abrem o breaker
#   RC6_AGY_MODEL_FALLBACK   modelo alternativo do agy (vazio desliga)
#   RC6_STATUS_FILE          destino dos eventos JSONL (so com rc6_status_init)
# O camada de retry do agy e INTERNA tambem ("API error (attempt 2)" no texto real): por isso o
# backoff daqui e mais espacado que o dele — duas camadas curtas amplificam a carga no pool.

# Formato de duracao do agy (Go): "8m", "480s", "1h30m", ou so digitos. Valor ilegivel NAO pode
# chegar cru a um $(( )): sob o `set -e` do consumidor, erro aritmetico mata o script sem mensagem
# (RC5 2026-09-24, com RC6_AGY_TIMEOUT=1h). Ilegivel -> 480 (o default do agy), com aviso.
dur_secs() {
  local d="${1:-}" t=0 n
  while [[ "$d" =~ ^([0-9]+)([hms]?)(.*)$ ]]; do
    n=$((10#${BASH_REMATCH[1]}))
    case "${BASH_REMATCH[2]}" in h) t=$((t + n*3600)) ;; m) t=$((t + n*60)) ;; *) t=$((t + n)) ;; esac
    d="${BASH_REMATCH[3]}"
  done
  if [ -z "$d" ] && [ "$t" -gt 0 ]; then echo "$t"; return 0; fi
  log "duração ilegível '${1:-}' — usando 480s"
  echo 480
}

# $1=engine -> transient|timeout|quota|fatal em stdout. Le o erro DA TENTATIVA ($WORKDIR/$1.err,
# que recebe stderr do CLI + mensagem do unwrap) e ENGINE_KILLED (hang guard).
# quota vem antes de transient: repetir quota so gasta mais quota. Texto desconhecido = fatal
# (lado seguro: nao repete o que nao se entende).
classify_engine_err() {
  if [ "${ENGINE_KILLED:-0}" = 1 ]; then echo timeout; return 0; fi
  local e; e="$(cat "$WORKDIR/$1.err" 2>/dev/null || true)"
  case "$(printf '%s' "$e" | tr '[:upper:]' '[:lower:]')" in
    *resource_exhausted*|*"code 429"*|*quota*|*"rate limit"*|*ratelimit*) echo quota ;;
    *unavailable*|*"code 503"*|*"code 502"*|*"code 504"*|*"no capacity"*|*overloaded*|\
    *econnreset*|*econnrefused*|*etimedout*|*"socket hang up"*|*"network error"*|*temporarily*) echo transient ;;
    *"timed out"*|*timeout*|*deadline*) echo timeout ;;
    *) echo fatal ;;
  esac
  return 0
}

RC6_STATUS_PATH=""
# Abre o status file e ANUNCIA o caminho no stderr: quem nao definiu RC6_STATUS_FILE precisa
# saber onde acompanhar. Default FORA do $WORKDIR, que o trap apaga no fim.
rc6_status_init() {
  RC6_STATUS_PATH="${RC6_STATUS_FILE:-${TMPDIR:-/tmp}/rc6-status-$$.jsonl}"
  RC6_STATUS_PATH="${RC6_STATUS_PATH%/}"
  : > "$RC6_STATUS_PATH" 2>/dev/null || { log "status: indisponivel ($RC6_STATUS_PATH)"; RC6_STATUS_PATH=""; return 0; }
  log "status: $RC6_STATUS_PATH"
  return 0
}

# $1=state [$2=json extra, sem chaves externas: '"attempt":2,"class":"transient"']
# pass/chunk vem de RC6_STATUS_PASS / RC6_STATUS_CHUNK, que o consumidor define antes da chamada.
# Canal LATERAL: nunca stdout (o stdout do consumidor e o contrato JSON).
rc6_status() {
  [ -n "$RC6_STATUS_PATH" ] || return 0
  local extra="${2:-}"; [ -n "$extra" ] && extra=",$extra"
  printf '{"t":"%s","pass":"%s","chunk":"%s","state":"%s"%s}\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${RC6_STATUS_PASS:--}" "${RC6_STATUS_CHUNK:--}" "$1" "$extra" \
    >> "$RC6_STATUS_PATH" 2>/dev/null || true
  return 0
}

RC6_SPENT=0; BREAKER_STREAK=0; BREAKER_OPEN=0
rc6_budget_left() { echo $(( ${RC6_RETRY_BUDGET:-300} - RC6_SPENT )); }

# Cabe mais uma chamada numa SEGUNDA rodada? $1=classe da falha, $2=engine.
# transient: sobrou orcamento. timeout: sobra um timeout INTEIRO (senao estoura o teto — E2).
# quota/fatal: nunca. RC6_RETRIES=0 desliga (kill switch = comportamento anterior a 003).
rc6_second_round_ok() {
  [ "${RC6_RETRIES:-2}" -gt 0 ] || return 1
  local left; left="$(rc6_budget_left)"
  case "$1" in
    transient) [ "$left" -gt 0 ] ;;
    timeout)
      local cap
      if [ "$2" = agy ]; then cap="$(dur_secs "$AGY_TIMEOUT")"; else cap="${PASSB_TIMEOUT:-480}"; fi
      [ "$left" -ge "$cap" ] ;;
    *) return 1 ;;
  esac
}

# A tentativa $1 e tempo EXTRA? Toda tentativa alem da 1a, e TODA tentativa da segunda rodada
# (RC6_IN_ROUND2=1, ligado pelo consumidor): sem isso o orcamento nao via a segunda rodada.
_rc6_extra() { [ "$1" -gt 1 ] || [ "${RC6_IN_ROUND2:-0}" = 1 ]; }

_rc6_backoff() { # $1=numero da tentativa extra (1..) -> segundos
  local list="${RC6_BACKOFF:-30 90}" w="" x n=0
  for x in $list; do n=$((n+1)); w="$x"; [ "$n" -ge "$1" ] && break; done
  w="${w:-0}"
  if [ "${RC6_JITTER:-1}" = 1 ] && [ "$w" -gt 0 ]; then w=$(( w + RANDOM % (w / 3 + 1) )); fi
  echo "$w"
}

# $1=engine $2=prompt $3=out [$4=1 permite modelo alternativo] [$5=rotulo p/ arquivos de erro]
# Mesmo contrato de retorno do run_engine (0 = saida valida). Escreve, para o consumidor:
#   ENGINE_LAST_CLASS    ok|transient|timeout|quota|fatal
#   ENGINE_LAST_ATTEMPTS chamadas feitas (modelo alternativo incluso)
#   ENGINE_LAST_RETRIED  1 se houve tentativa extra no mesmo modelo
#   ENGINE_LAST_FALLBACK 1 se a saida valida veio do modelo alternativo
# Cada tentativa que falha deixa o proprio erro em $WORKDIR/<engine>.<rotulo>.<n>.err (FR-009):
# o $engine.err e reescrito a cada chamada, e a primeira falha e muitas vezes a que explica.
# O A/B do 056/PO-5 chama com $4=0: modelo alternativo no baseline mediria o modelo, nao o
# filtro (E3). O run_engine BRUTO continua exportado — esta funcao so o envolve.
run_engine_resilient() {
  local engine="$1" pf="$2" out="$3" allow_fb="${4:-0}" tag="${5:-call}"
  local max="${RC6_RETRIES:-2}" n=0 cls w t0
  ENGINE_LAST_CLASS=""; ENGINE_LAST_ATTEMPTS=0; ENGINE_LAST_RETRIED=0; ENGINE_LAST_FALLBACK=0
  [ "$BREAKER_OPEN" = 1 ] && max=0   # breaker aberto: uma tentativa, falhou -> segunda rodada
  rc6_status started "\"engine\":\"$engine\""
  while :; do
    n=$((n+1)); ENGINE_LAST_ATTEMPTS=$n; ENGINE_KILLED=0
    t0="$(date +%s)"
    if run_engine "$engine" "$pf" "$out"; then
      _rc6_extra "$n" && RC6_SPENT=$(( RC6_SPENT + $(date +%s) - t0 ))
      BREAKER_STREAK=0; ENGINE_LAST_CLASS=ok
      rc6_status ok "\"attempt\":$n"
      return 0
    fi
    _rc6_extra "$n" && RC6_SPENT=$(( RC6_SPENT + $(date +%s) - t0 ))
    cls="$(classify_engine_err "$engine")"; ENGINE_LAST_CLASS="$cls"
    cp "$WORKDIR/$engine.err" "$WORKDIR/$engine.$tag.$n.err" 2>/dev/null || true
    [ "$cls" = transient ] || break
    BREAKER_STREAK=$((BREAKER_STREAK+1))
    if [ "$BREAKER_STREAK" -ge "${RC6_BREAKER:-3}" ] && [ "$BREAKER_OPEN" = 0 ]; then
      BREAKER_OPEN=1
      log "⚡ breaker aberto: $BREAKER_STREAK falhas transient seguidas — sem retry imediato; pendentes vão para a segunda rodada"
      rc6_status breaker_open "\"streak\":$BREAKER_STREAK"
      return 1
    fi
    [ "$n" -gt "$max" ] && break
    w="$(_rc6_backoff "$n")"
    if [ $(( w + 1 )) -gt "$(rc6_budget_left)" ]; then
      log "orçamento de retry esgotado ($(rc6_budget_left)s restantes) — sem nova tentativa"
      break
    fi
    log "aguardando ${w}s (retry $n/$max, ${RC6_STATUS_PASS:-?} ${RC6_STATUS_CHUNK:-?}, orçamento $(rc6_budget_left)s) — $(engine_err_hint "$engine")"
    rc6_status retrying "\"attempt\":$((n+1)),\"class\":\"$cls\",\"wait_s\":$w,\"budget_left_s\":$(rc6_budget_left)"
    ENGINE_LAST_RETRIED=1
    sleep "$w"; RC6_SPENT=$(( RC6_SPENT + w ))
  done
  # Modelo alternativo: so para `transient` (capacidade do pool DAQUELE modelo) e so no agy.
  local fb="${RC6_AGY_MODEL_FALLBACK-gemini-3.7-flash-medium}"
  if [ "$cls" = transient ] && [ "$allow_fb" = 1 ] && [ "$engine" = agy ] && [ "$BREAKER_OPEN" = 0 ] \
     && [ -n "$fb" ] && [ "$fb" != "${RC6_AGY_MODEL:-}" ] && [ "$(rc6_budget_left)" -gt 0 ]; then
    rc6_status model_fallback "\"model\":\"$fb\""
    log "tentando modelo alternativo $fb (${RC6_STATUS_PASS:-?} ${RC6_STATUS_CHUNK:-?})"
    local saved=("${AGY_ARGS[@]}") k
    for k in "${!AGY_ARGS[@]}"; do
      [ "${AGY_ARGS[$k]}" = --model ] && AGY_ARGS[k+1]="$fb"
    done
    n=$((n+1)); ENGINE_LAST_ATTEMPTS=$n; ENGINE_KILLED=0; t0="$(date +%s)"
    if run_engine agy "$pf" "$out"; then
      AGY_ARGS=("${saved[@]}")
      RC6_SPENT=$(( RC6_SPENT + $(date +%s) - t0 ))
      BREAKER_STREAK=0; ENGINE_LAST_CLASS=ok; ENGINE_LAST_FALLBACK=1
      rc6_status ok "\"attempt\":$n,\"model\":\"$fb\""
      return 0
    fi
    AGY_ARGS=("${saved[@]}")
    RC6_SPENT=$(( RC6_SPENT + $(date +%s) - t0 ))
    cls="$(classify_engine_err agy)"; ENGINE_LAST_CLASS="$cls"
    cp "$WORKDIR/agy.err" "$WORKDIR/agy.$tag.$n.err" 2>/dev/null || true
  fi
  return 1
}

# ---- (1.1.0) fail-open ------------------------------------------------------
# Nenhum motor respondeu: a revisao NAO bloqueia, mas diz em voz alta que nao aconteceu.
# Esta e a unica funcao do core que encerra o processo — de proposito: o contrato de
# fail-open e "JSON valido no stdout + exit 0", e deixar o exit com o chamador e convidar
# a variante que imprime o aviso e segue adiante como se tivesse revisado.
fail_open() { # $1=summary
  python3 -c 'import json,sys; print(json.dumps({"summary":sys.argv[1],"findings":[]},ensure_ascii=False,separators=(",",":")))' "$1"
  exit 0
}
