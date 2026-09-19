# 001 — Tasks

> **Retomada a frio:** leia a seção *Estado & próximo passo* do `spec.md` antes desta lista.
> **Feito:** slice A (T001–T006; T007 N/A) · slice B (T010–T014; MP-001 aprovada e aplicada).
> **Próximo:** slice E (T040) — depende de D ✅. Ou G, livre. PO-10 precisa de proposta nova (C1.5).
> PO-3..PO-6 seguem `[ ] open`: MANUAL, exigem projeto consumidor real (A-2).
> PO-3..PO-5 seguem `[ ] open`: são MANUAL e exigem projeto consumidor real (A-2).
> Legenda: `[x]` feita · `[~]` não aplicável, com motivo · `[ ]` pendente.

Uma task pertence a exatamente um slice. Ordem dos grupos = ordem da tabela de slices em `spec.md`.

---

## Slice A — `mode-gate.sh` · Tier 1 · ✅ CONCLUÍDO · PO-1 e PO-2 fechadas

- [x] T001 [US2] [PO-1] Escrever `scripts/mode-gate.sh` no molde do `reflect-gate.sh`
  * **Target**: `scripts/mode-gate.sh` (`[NEW]`)
  * **Mirror**: `scripts/reflect-gate.sh:1-25` (cabeçalho, invariante assimétrico, modos por env)
  * **Validate**: `bash -n scripts/mode-gate.sh && shellcheck scripts/mode-gate.sh`
- [x] T002 [US2] [PO-1] Implementar as 4 checagens: state.json lido · mode vs skill · PO aberta na transição · spec_dir existe
  * **Target**: `scripts/mode-gate.sh` (`[MODIFY]`)
  * **Validate**: `printf '%s' "$FIXTURE_OK" | ./scripts/mode-gate.sh`
- [x] T003 [US2] [PO-2] Implementar o fail-open assimétrico e documentá-lo no cabeçalho
  * **Target**: `scripts/mode-gate.sh` (`[MODIFY]`)
  * **Mirror**: `scripts/reflect-gate.sh:12-17`
  * **Validate**: `printf 'nao-json' | ./scripts/mode-gate.sh` → `ok=true` com marca
- [x] T004 [P] [US2] [PO-1][PO-2] Escrever `tests/mode-gate.test.sh` com caso feliz, violação e os 3 degradados
  * **Target**: `tests/mode-gate.test.sh` (`[NEW]`)
  * **Validate**: `bash tests/mode-gate.test.sh && bash tests/mode-gate.test.sh --degraded`
- [x] T005 [US2] [FR-003] Documentar os 3 níveis de acoplamento e provar que remover o nível 3 não muda comportamento
  * **Target**: `scripts/mode-gate.sh` (cabeçalho) + `references/DEVFLOW-REFERENCE.md` (`[MODIFY]`)
  * **Validate**: suíte do T004 verde sem nenhum hook instalado
- [x] T006 [C4] Fechar PO-1 e PO-2 colando evidência
- [~] T007 [C5] Journal + `events.jsonl` — **N/A neste repo**: `devflow/` não tem `.agent/` (A-1).
  Atrito registrado aqui: o teste do T004 nasceu com uma expectativa errada (tratava
  `devflow-spec --to specifying` como violação, quando é transição legítima concedida pelo
  operador). Corrigido no próprio slice; `kind: test_expectation_wrong`.

## Slice B — C-mode · Tier 2 · ▶ PRÓXIMO · depende: — · fecha PO-3..PO-5

- [x] T010 [PO-3] Draft de M1 → `mutations/B-M1-runner-detection.md` (origin proactive, assinatura de atrito, sunset)
- [x] T011 [PO-3] `devflow_mutation_proposal` **MP-001** emitida em `mutations/evolution_log.jsonl`
  (status `pending`; seções C1, C1.5, C3, C4 numa proposta só — INV-6: 1 em voo, sobra 1 para o slice C).
  INV-5 aplicado: M1 (C1) e F6 (C4) sem incidente real → **rebaixados a piloto** com critério de remoção.
- [x] T012 [PO-4] Draft de F5 → `mutations/B-F5-stop-condition.md` (3 critérios + marcador `deferred`)
  * **Mirror**: `ECC agents/spec-miner.md:57-68`
- [x] T013 [PO-5] Draft de F6 → `mutations/B-F6-abort-trio.md` (trio de aborto + ordenação por dependência)
  * **Mirror**: `ECC commands/build-fix.md:26-28,40-46`
- [x] T014 MP-001 **aprovada pelo operador em 2026-09-19** e aplicada em `skills/devflow-code/SKILL.md`
  (C1, C1.5/`1c`, C3, C4 + 3 linhas na Quick Reference). Marcadores `devflow-split` intactos (4/4).
  Núcleo bumpado v2.3 → **v2.4.0 (PILOTO)**; linha no histórico do `DEVFLOW-META.md`;
  confirmação `MP-001-applied` append-only no `evolution_log.jsonl`.
  * **Validate (corrigido)**: `grep -c devflow-split` == 4 **+** `bash tests/mode-gate.test.sh` (10/10)
    **+** `--degraded` (7/7). ⚠️ O `Validate` original citava `scripts/verify-split.sh`, que está
    **APOSENTADO** desde 2026-09-05 (cabeçalho do próprio script: "NÃO É GATE") e já falhava em HEAD
    limpo antes desta edição — por construção, já que prova um evento histórico, não um invariante.
  * **Validate**: `bash scripts/verify-split.sh`
- [~] T015 [C4] PO-3..PO-5 **NÃO fecham neste repo** — são `MANUAL` e exigem um C1/C1.5/C4 rodado
  num projeto consumidor real (A-2). Fechar aqui seria `[x]` sem evidência: a violação exata que as
  POs existem para impedir. Permanecem `[ ] open`; a evidência vem da primeira sessão de C-mode no dosiq.
  [C5] linha da Quick Reference: **feita** no T014. Journal: N/A (sem `.agent/` — A-1).
  **Atrito registrado aqui** (`kind: instruction_describes_stale_reality`): o `Validate` do T014
  mandava rodar `scripts/verify-split.sh`, aposentado há duas semanas. `workaround`: validar por
  marcadores + suíte do slice A. Candidato a alimentar o ledger reativo quando `.agent/` existir.

## Slice C — R-065 · Tier 1 · depende: A · fecha PO-6

- [x] T020 [PO-6] Draft de F7 → `mutations/C-F7-mechanical-stop.md`
  * **Mirror**: `ECC commands/multi-plan.md:227,229`
- [x] T021 **MP-002** emitida (`status: pending`) — seção MODE CONTROL RULE do núcleo.
  INV-6: 1 em voo (MP-001 já aplicada), 1 vaga livre. INV-5 não se aplica (núcleo ≠ C1/C4/Bootstrap).
- [x] T022 MP-002 **aprovada pelo operador em 2026-09-19** e aplicada no `SKILL.md` do núcleo
  (MODE CONTROL RULE + 1 linha na Quick Reference). Bump **v2.4.0 → v2.5.0 (PILOTO)**;
  linha no histórico do `DEVFLOW-META.md`; confirmação `MP-002-applied` no `evolution_log.jsonl`.
  * **Validate**: marcadores `devflow-split` 8/8 · `mode-gate.test.sh` 10/10 · `--degraded` 7/7
  * **Validate**: `bash scripts/verify-split.sh && bash tests/mode-gate.test.sh`
- [~] T023 [C4] PO-6 **NÃO fecha neste repo** — `proof:` é MANUAL (provocar um STOP real e
  inspecionar o transcript), logo exige projeto consumidor (A-2). O `guard:` (mode-gate.sh verde)
  está satisfeito; o `proof:` não. Permanece `[ ] open`. [C5] journal: N/A (sem `.agent/` — A-1).

## Slice D — gramática do `po` · Tier 2 · depende: B · fecha PO-7..PO-10

- [x] T030 `po_unstable` está **VIVO** (`skills/devflow-distill/SKILL.md:42,47`) — o slice D integra,
  não absorve. Achado extra: **`evidence:` já existe** no núcleo (`SKILL.md:364`) com OUTRO
  significado (Tier 2 regulado). Colisão registrada na spec; **T031 bloqueada** até o operador
  escolher o nome. Inventário levantado via `agy -p` e conferido contra o disco.
- [x] T031 [PO-7..PO-10] Draft ÚNICO → `mutations/D-po-grammar.md`. Colisão resolvida pelo operador:
  **opção (a)** — campo novo é `evidence_class:`, o `evidence:` regulado fica intacto (zero backfill).
  Achado do próprio draft: o M6 traz um **5º** campo (`red:`), não contabilizado no T031 original.
  * **Mirror**: seção *Proof Obligations* do `SKILL.md` (tabela de campos)
- [x] T032 **MP-003** emitida (`status: pending`). INV-6: 1 em voo, 1 vaga. INV-5 aplica-se ao C4
  ⇒ essa parte entra rebaixada a piloto. Orçamento declarado no draft: nenhum campo novo é
  obrigatório em todo tier (bloco de 11 campos mataria a PO como formulário curto).
- [x] T033 MP-003 **aprovada em 2026-09-19** e aplicada: núcleo (tabela canônica + 3º status +
  Quick Reference) · `devflow-code` (C3/M6, C4, Pass 0 `3b`/`3c`, Quick Reference) ·
  `devflow-spec` (S4). Bump **v2.5.0 → v2.6.0 (PILOTO)**; histórico no META; `MP-003-applied` no log.
  Backfill oportunista aplicado só nas POs que esta sessão tocou (PO-7..PO-10), como a regra manda.
  * **Validate**: marcadores `devflow-split` (4 em devflow-code, 8 no núcleo) + `mode-gate.test.sh`
    + `no-core-shadowing.test.sh`. **NÃO** usar `verify-split.sh` (aposentado — ver T014)
- [~] T034 [C4] **PO-7 fechada** (`evidence_class: execution`, 4/4 blocos tocados com `boundary:`).
  **PO-8 e PO-9 abertas**: MANUAL, exigem projeto consumidor (A-2) — instrumento pronto e anotado.
  **PO-10 aberta por GAP REAL**, não por falta de acesso: `uncertainty:` entrou na gramática do
  núcleo mas **não** no C1.5/C4 do `devflow-code`, e o C1.5 **não estava** entre as seções aprovadas
  na MP-003 — editá-lo violaria a INV-4. Exige proposta nova; candidata a entrar junto do slice E.
  Correção de verdade (C5/4b): a AC da PO-7 dizia "Tier 1+" e foi corrigida para **T2**, que é o
  que o orçamento aprovado entregou. [C5] journal: N/A (sem `.agent/` — A-1).

## Slice E — Spec & Plan · Tier 1 · depende: D · fecha PO-11..PO-13

- [ ] T040 [PO-11] Draft M3 (Non-Goals + Invariantes no S4, com a ressalva CON-NNN)
- [ ] T041 [PO-12] Draft M4 (P2.5 Pattern Grounding, só Tier 2)
- [ ] T042 [PO-12] Draft M5 (task grammar `Target`/`Mirror`/`Validate` no P3)
- [ ] T043 [PO-13] Draft M2 (RC5 Pass 1: limiar >80%, prova para HIGH/CRITICAL, zero findings válido) — **sem duplicar Suppressions**
- [ ] T044 Emitir propostas serializadas (2 em voo) e aplicar após aprovação
  * **Validate**: `bash scripts/verify-split.sh`
- [ ] T045 [C4] Fechar PO-11..PO-13 · [C5] journal

## Slice F1 — extração do `@core` · Tier 2 · depende: — · fecha PO-14, PO-15

- [x] T050 [PO-14] Baseline determinística em `tests/ai-review-baseline.sh` (repo-fixture com diff
  `.js`/`.ts` real + `RC6_MEASURE=1`, que para ANTES do engine). O `proof:` original era
  não-determinístico e passava por construção — ver nota de método no bloco PO-14.
- [x] T051 `scripts/lib/engine-core.sh` (224 linhas, `ENGINE_CORE_VERSION=1.0.0`) com as 9 funções
  agnósticas, extraídas por script (casamento de chaves), nunca copiadas à mão
  * **Target**: `scripts/lib/engine-core.sh` (`[NEW]`)
  * **Mirror**: `scripts/ai-review.sh:89,301-369,546,909-1101,1167,1397-1479`
- [x] T052 `ai-review.sh` dá source no core e valida `ENGINE_CORE_EXPECTED` (1754 → 1583 linhas);
  versão divergente falha ALTO com exit 2, não em silêncio
  * **Target**: `scripts/ai-review.sh` (`[MODIFY]`)
  * **Validate**: `diff /tmp/before.txt <(./scripts/ai-review.sh --dry-run)`
- [x] T053 [PO-15] `tests/no-core-shadowing.test.sh` — 3/3. Descobre consumidores por grep (sem
  lista fixa), então o `second-opinion.sh` do F2 entra sob a mesma regra ao nascer
- [x] T054 [C4] **PO-14 e PO-15 fechadas com evidência colada.** [C5] journal: N/A (sem `.agent/` — A-1).
  Achado colateral **AC-1** registrado na spec: `ai-review.sh` morre em repo sem
  `ANTI_PATTERNS_INDEX.md` (`set -e` + `pipefail`). Não consertado aqui de propósito — violaria a PO-14.

## Slice F2 — `second-opinion.sh` · Tier 2 · depende: C, D, F1 · fecha PO-16..PO-19

- [ ] T060 [PO-16] Escrever `scripts/second-opinion.sh` sobre o core, com adaptadores `plan|analysis|spec`
  * **Mirror**: `scripts/ai-review.sh` (montagem de contexto e schema JSON estrito)
- [ ] T061 [PO-17] Provar egress guard e fail-open vindos do core, sem cópia local
- [ ] T062 [PO-18] Draft de F8 (posição-antes-da-leitura) em `skills/devflow-ceremony/`
  * **Mirror**: `ECC skills/council/SKILL.md:76-83`
- [ ] T063 [PO-19] Ligar C1.5 Tier 2 como cliente do script
- [ ] T064 [C4] Fechar PO-16..PO-19 · [C5] journal

## Slice G — handoff · Tier 1 · depende: — (estudo em paralelo) · fecha PO-20, PO-21

- [ ] T070 [PO-20] Comparar 4 formatos (journal · arquivo por sessão · `state.json` · `attempts.jsonl` estendido)
  pelos 3 critérios: é lido na sessão seguinte sem o operador pedir? sobrevive a compact? quem mantém?
- [ ] T071 [PO-20] Apresentar ao operador e registrar a escolha — **nenhuma edição no C5 antes disso**
- [ ] T072 [PO-21] Draft do endurecimento do C5 no formato escolhido (motivo exato + demoção do não-evidenciado)
  * **Mirror**: `ECC commands/save-session.md:101-110`
- [ ] T073 [C4] Fechar PO-20, PO-21 · [C5] journal

## Slice H — falsificação · Tier 1 · depende: todos · fecha PO-22, PO-23

- [ ] T080 [PO-22] Montar a medição de conformidade em 3 níveis de rigor (supportive/neutral/competing)
  * **Mirror**: `ECC skills/skill-comply/SKILL.md:12-17`
- [ ] T081 [PO-22] Medir as mutações dos slices B–G e reportar taxa por nível
- [ ] T082 [PO-23] Draft do caminho `external_corpus` no `DEVFLOW-META.md` (origin, assinatura de atrito, sunset)
  — **sem afrouxar** a barra reativa de 3+ observações / ≥2 specs
- [ ] T083 Aplicar o veredito de cada mutação: promover (observação real apareceu) ou REMOVER (não apareceu)
- [ ] T084 [C4] Fechar PO-22, PO-23 · [C5] journal + fechamento da spec no índice
