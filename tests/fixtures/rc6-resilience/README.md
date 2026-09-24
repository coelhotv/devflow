# Fixtures da spec 003 — resiliência do RC6

## `agy-503-envelope.json`

**Procedência:** o campo `error` foi copiado byte a byte do stderr do RC6 no PR dosiq#835
(2026-09-24), gravado no transcript `~/.claude/projects/-Users-coelhotv-git-dosiq/abbfa5ea-….jsonl`:

```
[rc6] pass A chunk 1/4 (agy) FAILED — engine reported failure: API error (attempt 1): UNAVAILABLE (code 503): No capacity available for model gemini-3.8-flash-medium on the server
```

O prefixo `engine reported failure:` é do `unwrap_structured` (`engine-core.sh`). Isso prova que a
falha veio **dentro do envelope** (`why = r.get("error")`), e não no stderr do CLI. É o achado E1 do
RC3.

**O que é reconstrução, e não cópia:** o valor de `status` (qualquer valor ≠ `SUCCESS` gera a mesma
mensagem) e o exit code do agy nesse caso (o `$WORKDIR` foi apagado pelo trap). Por isso o teste
exercita os dois exit codes, 0 e 1.

`(attempt 1)` / `(attempt 2)` no texto real: o agy já faz retry interno. O retry do RC6 é uma
camada externa, mais espaçada (backoff 30s/90s).
