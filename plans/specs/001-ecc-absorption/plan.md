# 001 — Plano técnico

**Tier:** 2 · **Spec:** `spec.md` (umbrella; a tabela de slices é a autoridade da ordem)

## Summary

Absorver 8 achados instrucionais e 4 propostas estruturais do ECC no DEVFLOW, entregues em 9 slices.
Nenhuma prosa de skill é editada fora do fluxo `devflow_mutation_proposal` + aprovação do operador.

## Technical Context (evidência verificada)

| Fato | Onde | Consequência |
|---|---|---|
| `ai-review.sh` tem 1754 linhas, com chunking, ranking de risco, egress guard, captura A/B, ancoragem de snippet | `scripts/ai-review.sh` | Generalizá-lo por dentro degrada especialização de 3 specs → extrair `@core` |
| MEASURE mode (`RC6_MEASURE=1`) já existe e para ANTES do engine | `scripts/ai-review.sh` | Dá prova de equivalência *reconciliation-grade* para F1 (`tests/ai-review-baseline.sh`). ⚠️ `--dry-run` **não** serve: ainda chama o engine — ver nota de método da PO-14 |
| `reflect-gate.sh` é bash, zero LLM, com invariante assimétrico no cabeçalho (:12-17) | `scripts/reflect-gate.sh` | É o molde do `mode-gate.sh` e a prova de que o substrato certo é script, não hook |
| RC6 já é multi-agente, contexto frio, flag-only, fail-open | `skills/devflow-code/SKILL.md:738-850` | A mecânica a generalizar já existe; F2 é cliente novo, não reinvenção |
| Máx. 2 propostas pendentes; C1/C4/Bootstrap exigem incidente real | `DEVFLOW-META.md:101-102` | Emissão serializada; slices B e D entram rebaixados a piloto quando faltar incidente |
| `agents/openai.yaml` existe | `agents/` | Empacotamento multi-vendor já é premissa → INV-2 |
| `emit_wiki_block` terminava num `[ -f ]` sob `set -euo pipefail` | `scripts/ai-review.sh:487-495` | **AC-1 — CONSERTADO em 2026-09-21** (`\|\| true` nas duas guardas). Descoberto ao montar a baseline do F1; era a 2ª ocorrência da classe já comentada em `:1208` |
| `.agent/` passou a existir, **parcial** | `.agent/README.md` | Ledger de atrito ativo; **nenhum** índice de memória e **nenhum** relógio de sunset. A-1 e A-2 intactos |

## Arquitetura

### Substrato de enforcement (3 níveis, INV-2)
```
nível 1  CLI / CI          scripts/mode-gate.sh          ← o contrato; portável
nível 2  git hook local    pre-commit, post-checkout     ← portável, invoca o nível 1
nível 3  hook do cliente   settings.json (opcional)      ← açúcar; só invoca o nível 1
```
Remover o nível 3 não pode alterar comportamento algum. É o teste do PO-2/FR-003.

### `@core` dos scripts de engine externo (slices F1/F2)
```
scripts/lib/engine-core.sh      ← probe de engine, run_engine/run_bounded/unwrap_structured,
                                  map_path_to_packs/packs_for_files/filtered_index,
                                  orçamento de preâmbulo, egress guard, merge/dedupe/render,
                                  chamada do reflect-gate, fail-open, captura A/B
   ├── scripts/ai-review.sh     ← + resolve PR/branch, diff, chunks, ranking, snippet anchoring,
   │                              comentário no PR, state.ai_review
   └── scripts/second-opinion.sh← + adaptadores por artefato (plan | analysis | spec)
```
Anti-drift: `engine-core.sh` declara versão; ambos os consumidores a citam; teste falha se uma função
do core for redefinida localmente (PO-15).

## Clarifications

- Q: teto de LOC como orçamento? → A: não; o orçamento é o que o DEVFLOW precisa. Substituído pelas
  regras de admissão (DT-1) — o escasso é número de mecanismos, não de linhas.
- Q: a adição no RC5 conflita com o RC6? → A: conflitava. A proposta de independência foi retirada;
  o RC6 já a implementa. Sobra só a calibração do autor (M2).
- Q: novo script ou generalizar o `ai-review.sh`? → A: nenhum dos dois — extrair `@core` (F1) e
  escrever o `second-opinion.sh` por cima (F2).
- Q: hooks são portáveis? → A: hook do Claude Code não é. O substrato é script + CI (INV-2).
- Q: esta spec cabe no protocolo de meta-evolução? → A: não como está — ele é reativo. Esta é proativa
  e carrega controles compensatórios (DT-2); o slice H formaliza o caminho.

## Riscos

| Risco | Mitigação |
|---|---|
| Inflar a gramática do `po` (4 campos novos) | Uma edição única no slice D, junto com o M6; blocos legados válidos sem backfill em massa |
| Extração do `@core` quebrar o revisor de PR | PO-14: baseline determinística via MEASURE mode (`tests/ai-review-baseline.sh`) byte-idêntica — **não** `--dry-run` |
| Mutação proativa virar passo morto (AP-325) | DT-2: assinatura de atrito prevista + sunset + remoção declarada |
| Estourar o limite de propostas pendentes | Emissão serializada; F1 não emite proposta |

## Quality Gates

- `bash -n` + `shellcheck` em todo script novo
- testes por slice conforme as POs
- nenhum slice fecha com PO `[ ] open` (RC5 Pass 0, recortado pelo `slice:`)
  ⚠️ **Exceto PO MANUAL**: exigem projeto consumidor (A-2) e ficam `[ ] open` com o instrumento
  anotado. Ler como "pendência de trabalho" é o erro — é pendência de ACESSO.

### Suítes vivas (estado em 2026-09-21)

| Suíte | Cobre | Verde |
|---|---|---|
| `tests/mode-gate.test.sh` (+ `--degraded`) | transição de modo e fail-open assimétrico | 10/10 · 7/7 |
| `tests/no-core-shadowing.test.sh` | nenhum consumidor redefine função do `@core` | 3/3 |
| `tests/ai-review-baseline.sh` | equivalência byte-a-byte do `ai-review.sh` (fixture **com** `.agent/`) | `Files are identical` |
| `tests/ai-review-no-agent.test.sh` | sobrevivência em repo **sem** `.agent/` (AC-1) | 3/3 |

`scripts/verify-split.sh` **não é gate** (aposentado). Marcadores `devflow-split` no disco:
núcleo 8 · `devflow-code` 4 · `devflow-spec` 4 · `devflow-plan` **2** (não tem bloco `qr`).

### Runners deste repo (resolução do C1, não rechutar)

Sem `package.json`/`Makefile`/`Cargo.toml`/`pyproject.toml`. `test:` suítes de `tests/` ·
`lint:` `shellcheck` + `bash -n` · `typecheck:` `NONE (ausente)` · `build:` `NONE (ausente)`.
