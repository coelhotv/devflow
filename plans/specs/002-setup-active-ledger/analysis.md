# 002 — Artifact Coverage Analysis

Tier 1, risco justificado: idempotência em 6 blocos `cat >`, parsing de git log, dedup de `.gitignore`.
Escopo: spec.md ↔ tasks.md ↔ repo real (`scripts/setup.sh`, `tests/second-opinion.test.sh` como mirror).

## Evidence Table

| Spec claim | Real repo (file:line) | Verificado? | Nota |
|---|---|---|---|
| `cat >` sem checar existência em 6 pontos | `scripts/setup.sh:54,96,131,166,201,236` | ✅ | state.json(54) + 5 INDEX.md(96,131,166,201,236) |
| `.gitignore`: cria se falta, sem dup se existe | `scripts/setup.sh:271-283` | ✅ | branch `else` só ecoa aviso, nunca cria |
| Ledgers process-friction/attempts não são criados | `scripts/setup.sh` (grep completo) | ✅ | nenhuma menção a `*.jsonl` no script |
| Marco de início derivado do git (Q1=a) | `git log --diff-filter=A --format=%cI -- <path>` | ✅ | testado ao vivo neste repo: `.agent/memory/process-friction.jsonl` → `2026-09-21T10:39:16-03:00`; caminho não commitado → string vazia |
| Mirror de teste `tests/second-opinion.test.sh` | `tests/second-opinion.test.sh:1-134` | ✅ | padrão: PATH isolado, fixture em `mktemp -d`, `ok/bad`, `pass`/`fail` contam, exit = `[ "$fail" = 0 ]` |
| `--with-git-hook` deve instalar `mode-gate.sh` como hook local | `scripts/mode-gate.sh` existe, `scripts/setup.sh` não referencia hooks | ✅ | flag é 100% nova, sem código a reaproveitar além do path do script |
| CONTRACTS_INDEX/RULES_INDEX deste repo | `.agent/memory/` | ✅ | não existem — `.agent/` deste repo é parcial por decisão (Non-Goal 3); gate de contrato não se aplica |

## Obtainability (1b)

| Promessa | Granularidade necessária | Schema real permite? | Evidência |
|---|---|---|---|
| PO-2: "commitar ledger → devolve data ISO" | 1 comando git por ledger, sem estado extra | Sim | comando testado acima, funciona com git puro (INV-2 preservado) |
| PO-1: rerun não altera nenhum arquivo existente | comparação byte-a-byte antes/depois | Sim, mas exige guard em CADA `cat >` — 6 pontos, fácil esquecer 1 | ver Failure Modes |

## Condição de parada
Teto atingido por SATURAÇÃO: setup.sh (lido completo, 313 linhas), install-skills.sh (30 linhas relevantes),
second-opinion.test.sh (mirror, lido completo) — 3 arquivos de alta relevância, sem novas asserções após o 3º.
Nenhum arquivo ficou `deferred:`.

## Cross-file consistency
spec.md, tasks.md concordam: Q1 resolvida = (a) git-derived, tasks.md T003 cita isso explicitamente.
Sem contradição encontrada.

## Behavioral Failure Modes (funções NOVAS/ALTERADAS)

| Função/bloco | Input degenerado | Comportamento esperado | Coberto (teste)? |
|---|---|---|---|
| guard de idempotência por arquivo (T002) | arquivo já existe mas com conteúdo DIFERENTE do template atual (versão antiga) | pular e reportar — NUNCA sobrescrever (INV-1), mesmo se o conteúdo estiver desatualizado | PO-1 "rerun preserva" (checksum) |
| criação de ledgers (T003) | `.agent/memory/` não existe ainda (repo novíssimo, ordem de criação) | ledgers criados DEPOIS do `mkdir -p` da árvore — ordem importa | PO-2 "ledger ativo" |
| derivação de data via git (T003 aviso) | repo sem histórico git (`git log` falha ou script roda fora de um repo) | não abortar o setup; avisar "relógio inativo" sem crashar | novo caso a adicionar no T001 |
| `.gitignore` sem entrada `.agent/` mas COM outras entradas (parcial) | arquivo existe, só falta 1 das 3 linhas (`state.json` mas não `sessions/`) | completar SÓ o que falta, linha a linha, sem duplicar o que já está | PO-3 "com .gitignore parcial" |
| `.gitignore` já tem as 3 entradas, rodar de novo | idempotência do append | não duplicar nenhuma linha | PO-3 guard "rodar duas vezes não duplica" |
| `--with-git-hook` passado num repo sem `.git/hooks` gravável | diretório inexistente ou sem permissão | falhar com mensagem clara, não abortar o resto do setup | não coberto por PO explícita — MEDIUM, ver abaixo |

## Findings

- **MEDIUM**: `--with-git-hook` sem caso de teste degenerado (repo sem `.git/`, sem `.git/hooks/` gravável) no
  tasks.md. Não bloqueia C2 (FR-006 é a única PO implícita, sem `po` block dedicado — legado tier1 lazy backfill,
  aceitável pois T006 não tem PO própria na spec). Adicionar um caso best-effort em T001 durante a escrita do teste.
- **LOW**: spec não diz o que fazer se `git log --diff-filter=A` for chamado fora de um repositório git (setup
  rodando em diretório que nunca foi `git init`). Comportamento esperado (não crashar, ledger fica "inativo") é
  óbvio por INV-2 (shell puro) — registrado na tabela de failure modes acima, tratado como parte de T003/T001.

Nenhum CRITICAL/HIGH. Gate: prosseguir para C2.

## Uncertainty

- Nenhuma pendência sem resposta após a verificação acima.
