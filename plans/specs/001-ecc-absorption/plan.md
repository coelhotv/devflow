# 001 — Plano técnico

**Tier:** 2 · **Spec:** `spec.md` (umbrella; a tabela de slices é a autoridade da ordem)

## Summary

Absorver 8 achados instrucionais e 4 propostas estruturais do ECC no DEVFLOW, entregues em 9 slices.
Nenhuma prosa de skill é editada fora do fluxo `devflow_mutation_proposal` + aprovação do operador.

## Technical Context (evidência verificada)

| Fato | Onde | Consequência |
|---|---|---|
| `ai-review.sh` tem 1754 linhas, com chunking, ranking de risco, egress guard, captura A/B, ancoragem de snippet | `scripts/ai-review.sh` | Generalizá-lo por dentro degrada especialização de 3 specs → extrair `@core` |
| `--dry-run` (:1530) e MEASURE mode (:1111) já existem | `scripts/ai-review.sh` | Dá prova de equivalência *reconciliation-grade* para F1 |
| `reflect-gate.sh` é bash, zero LLM, com invariante assimétrico no cabeçalho (:12-17) | `scripts/reflect-gate.sh` | É o molde do `mode-gate.sh` e a prova de que o substrato certo é script, não hook |
| RC6 já é multi-agente, contexto frio, flag-only, fail-open | `skills/devflow-code/SKILL.md:738-850` | A mecânica a generalizar já existe; F2 é cliente novo, não reinvenção |
| Máx. 2 propostas pendentes; C1/C4/Bootstrap exigem incidente real | `DEVFLOW-META.md:101-102` | Emissão serializada; slices B e D entram rebaixados a piloto quando faltar incidente |
| `agents/openai.yaml` existe | `agents/` | Empacotamento multi-vendor já é premissa → INV-2 |

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
| Extração do `@core` quebrar o revisor de PR | PO-14: `--dry-run` byte-idêntico + MEASURE mode igual |
| Mutação proativa virar passo morto (AP-325) | DT-2: assinatura de atrito prevista + sunset + remoção declarada |
| Estourar o limite de propostas pendentes | Emissão serializada; F1 não emite proposta |

## Quality Gates

- `bash -n` + `shellcheck` em todo script novo
- testes por slice conforme as POs
- nenhum slice fecha com PO `[ ] open` (RC5 Pass 0, recortado pelo `slice:`)
