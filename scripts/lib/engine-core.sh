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
#
# O QUE NAO MORA AQUI: montagem de preambulo, selecao de arquivos, gate de reflexao,
# publicacao no PR, schema de review. Isso e dominio, nao motor.
#
# CONTRATO COM O CONSUMIDOR (o core LE estas variaveis, nunca as define):
#   WORKDIR        — dir temporario, ja criado         (run_engine, engine_err_hint)
#   IDX_LINE_MAX   — inteiro                           (clamp_lines)
#   AGY_SCHEMA / CLAUDE_SCHEMA / AGY_ARGS[] /
#   CLAUDE_ARGS[] / PASSB_TIMEOUT                      (run_engine)
# O core tambem NAO faz `set -euo pipefail`: quem define o modo de erro e o script principal.
#
# Uso:  source "$(dirname "${BASH_SOURCE[0]}")/lib/engine-core.sh"

# shellcheck disable=SC2034  # lido pelo consumidor apos o source — este e o contrato
ENGINE_CORE_VERSION="1.0.0"


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
  [ "$rc" -ge 124 ] && log "engine killed after ${secs}s wall-clock (hang guard)"
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
    # stdin closed (</dev/null): headless agy must never block waiting for input
    agy)
      if [ "$AGY_SCHEMA" = 1 ]; then
        agy "${AGY_ARGS[@]}" -p "$(cat "$pf")" \
          > "$raw" 2>"$WORKDIR/agy.err" < /dev/null || return 1
        local usage_agy
        usage_agy="$(unwrap_structured agy "$raw" "$out" 2>>"$WORKDIR/agy.err")" || return 1
        [ -n "$usage_agy" ] && log "  agy usage: $usage_agy"
      else
        agy "${AGY_ARGS[@]}" -p "$(cat "$pf")" \
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

