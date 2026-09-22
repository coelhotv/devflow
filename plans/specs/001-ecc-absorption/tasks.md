# 001 — Tasks

> **Retomada a frio:** leia a seção *Estado & próximo passo* do `spec.md` antes desta lista.
> **Feito:** slices **A–H — spec fechada**. POs fechadas: **11 de 23**; PO-21 `[!]`; as 11 restantes são
> MANUAL (A-2). Propostas: MP-001..MP-007 — todas aprovadas e aplicadas. DEVFLOW em **v3.0.0 (PILOTO)**.
> **Próximo:** fora deste repo — primeira sessão de C-mode num consumidor (dosiq). Aqui: PR do épico.
> **Repo:** branch `spec/001-ecc-absorption`, 17 commits à frente de `main`, árvore limpa, sem PR.
> `.agent/` agora existe mas é **INIT PARCIAL** — leia `.agent/README.md`.
> POs `[ ] open` que NÃO são pendência de trabalho: PO-3..PO-6, PO-8, PO-9, PO-11..PO-13 são
> MANUAL e exigem projeto consumidor real (A-2); o instrumento está pronto e anotado em cada bloco.
> Legenda: `[x]` feita · `[~]` não aplicável ou parcial, com motivo · `[ ]` pendente.

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

## Slice B — C-mode · Tier 2 · ✅ APLICADO (piloto v2.4) · PO-3..PO-5 `[ ] open` (MANUAL, A-2)

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

## Slice C — R-065 · Tier 1 · ✅ APLICADO (piloto v2.5) · PO-6 `[ ] open` (MANUAL, A-2) · depende: A

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

## Slice D — gramática do `po` · Tier 2 · ✅ APLICADO (piloto v2.6) · PO-7 ✅ · PO-8/9 MANUAL · PO-10 → E · depende: B

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

## Slice E — Spec & Plan · Tier 1 · ✅ CONCLUÍDO (piloto v2.7) · **PO-10 fechada** · PO-11..13 MANUAL · depende: D

> **Escopo ampliado em 2026-09-19** (decisão do operador): o E absorve a dívida da PO-10, deixada
> aberta pelo slice D. `uncertainty:` entrou na gramática do núcleo mas não no C1.5, e o C1.5 não
> estava entre as seções aprovadas na MP-003. Viaja na MESMA proposta do E — uma vaga de INV-6 em
> vez de duas, uma aprovação em vez de duas.

- [x] T040 [PO-11] Draft M3 → `mutations/E-M3-non-goals-invariants.md` (Non-Goals ≥2 + Invariants
  com a ressalva de promoção a CON-NNN; T1 e T2, não T0)
  * **Mirror**: o `spec.md` desta spec — as duas seções nasceram à mão, sem o S4 as exigir
- [x] T041 [PO-12] Draft M4 → `mutations/E-M4-pattern-grounding.md` (P2.5 entre P2 e P3, só Tier 2;
  célula vazia bloqueia o P3; Tier 1 herda via `Mirror:`)
- [x] T042 [PO-12] Draft M5 → `mutations/E-M5-task-grammar.md`. Achado: o C3 (MP-001, já no disco)
  manda rodar o `Validate:` da task e **ninguém era obrigado a escrevê-lo** — o M5 fecha uma
  dependência pendente, não é adição especulativa
- [x] T043 [PO-13] Draft M2 → `mutations/E-M2-pre-report-gate.md` (limiar >80%, prova (a)(b)(c) para
  HIGH/CRITICAL, zero findings válido). Suppressions **referenciada, não duplicada**; +2 linhas (teto)
- [x] T039 [PO-10] Draft do `uncertainty:` no **C1.5** do `devflow-code` (e a menção no C4):
  onde registrar ignorância sem fabricar conteúdo. **Entra na mesma proposta do T044.**
  * **Mirror**: a tabela canônica do núcleo já DEFINE o campo (`SKILL.md`) — aqui ele é USADO
  * **Guard**: o limite de 3 marcadores `[NEEDS CLARIFICATION]` do S4 permanece
  * **Validate**: `grep -n 'uncertainty:' skills/devflow-code/SKILL.md` deixa de sair vazio
  * Draft → `mutations/E-PO10-uncertainty-c15.md`. Baseline confirmada no disco 2026-09-20:
    o grep retorna **vazio** hoje (0 hits) — o GAP é real, não é falta de acesso.
    **INV-5 aplica-se à parte do C4** ⇒ rebaixada a piloto.
- [x] T044 **MP-004 emitida, APROVADA pelo operador em 2026-09-21 e aplicada** no `evolution_log.jsonl`, 2026-09-20 —
  proposta **ÚNICA** com as 6 seções (S4 · P2.5 · P3 · RC5 Pass 1 · C1.5 · C4), fechando
  PO-10..PO-13. Aplicada em 3 arquivos + Quick Reference (spec e code); `MP-004-applied`
  append-only no `evolution_log.jsonl`. Bump **v2.6.0 → v2.7.0 (PILOTO)** no núcleo + linha no
  `DEVFLOW-META.md`. ⚠️ `devflow-plan` **não tem bloco `qr`** (2 marcadores, não 4) — por isso não
  ganhou linha de Quick Reference. Fato do disco, não omissão.
  ⚠️ **Correção de verdade (C5/4b):** esta linha dizia "propostas serializadas (2 em voo)" —
  contradizia o `spec.md`, que decidiu (2026-09-19) juntar o C1.5 na MESMA proposta do E,
  gastando uma vaga de INV-6 em vez de duas. O `spec.md` é a autoridade; a linha foi corrigida.
  ⚠️ O `Validate` original mandava rodar `scripts/verify-split.sh`, **APOSENTADO** desde
  2026-09-05 (mesmo atrito do T014, `kind: instruction_describes_stale_reality`).
  * **Validate (corrigido)**: marcadores `devflow-split` (4 em devflow-code, 8 no núcleo,
    2 em spec, 2 em plan) + `bash tests/mode-gate.test.sh` + `--degraded`
    + `bash tests/no-core-shadowing.test.sh`
- [~] T045 [C4] **PO-10 FECHADA** com evidência colada (`evidence_class: execution`): o grep do
  `proof:` saiu de **0 → 7 hits** em `skills/devflow-code/SKILL.md`; guard (`Limit to 3 markers`)
  intacto. **PO-11..PO-13 seguem `[ ] open`**: são MANUAL e exigem projeto consumidor real (A-2) —
  instrumento pronto e anotado bloco a bloco. O guard da PO-13 (Suppressions não duplicada) foi
  verificado e ESTÁ satisfeito. [C5] journal: N/A (sem `.agent/` — A-1).
  **Atrito registrado aqui** (`kind: instruction_describes_stale_reality`, **3ª ocorrência** —
  T014, T033 e agora T044): o `Validate` citava `verify-split.sh`, aposentado. Três ocorrências é
  a barra de mutação do META; vira proposta quando houver `.agent/` para escrever o ledger.

## Slice F1 — extração do `@core` · Tier 2 · ✅ CONCLUÍDO · PO-14 e PO-15 fechadas

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
  * **Validate**: `bash tests/ai-review-baseline.sh` antes/depois → `Files are identical`
    (redação original citava `--dry-run`, desqualificado na nota de método da PO-14; corrigido 2026-09-22)
- [x] T053 [PO-15] `tests/no-core-shadowing.test.sh` — 3/3. Descobre consumidores por grep (sem
  lista fixa), então o `second-opinion.sh` do F2 entra sob a mesma regra ao nascer
- [x] T054 [C4] **PO-14 e PO-15 fechadas com evidência colada.** [C5] journal: N/A (sem `.agent/` — A-1).
  Achado colateral **AC-1** registrado na spec: `ai-review.sh` morre em repo sem
  `ANTI_PATTERNS_INDEX.md` (`set -e` + `pipefail`). Não consertado aqui de propósito — violaria a PO-14.

## Interlúdio — manutenção descoberta pelo épico · 2026-09-21 · fecha PO nenhuma

> Não é slice: não estava na tabela e não tem PO. Fica registrado porque aparece no `git log` do
> branch e, sem isto, o próximo leitor não saberia de onde vieram dois commits entre E e F2.

- [x] TX01 Conserto do **AC-1** — `ai-review.sh` morria (exit 1 mudo) em repo sem
  `.agent/memory/ANTI_PATTERNS_INDEX.md`
  * **Target**: `scripts/ai-review.sh` (`[MODIFY]`) — `|| true` nas DUAS guardas de
    `emit_wiki_block` (:492 e :493) + `return 0` explícito
  * **Mirror**: `scripts/ai-review.sh:1208` — a MESMA classe já tinha sido consertada e comentada
    ali; foi a 2ª ocorrência de um conserto entendido uma vez e não generalizado
  * **Validate**: `bash tests/ai-review-no-agent.test.sh` (RED 0/3 → GREEN 3/3)
  * ⚠️ **O primeiro fixture passou por engano**: com tudo em `main`, `base == head`, o diff saía
    vazio e o script encerrava em "No code changes" ANTES do `emit_wiki_block`. Mesmo modo de
    falha que a PO-14 documentou. Por isso o teste assere 3 coisas — um `exit 0` prematuro não
    pode passar como conserto
- [x] TX02 `tests/ai-review-no-agent.test.sh` (`[NEW]`) — fixture espelho do da PO-14, com
  `.agent/` AUSENTE. O fixture da baseline o CRIA de propósito, logo não cobria este caso
  * **Validate**: `bash tests/ai-review-baseline.sh` antes/depois → `Files are identical`
- [~] TX03 **AP NÃO cunhado** — este repo não tem `ANTI_PATTERNS_INDEX.md`, por decisão
  (`.agent/README.md`). A defesa durável virou o TESTE. AP candidato anotado em prosa, nomeando o
  mecanismo: *"guarda `[ -f ]` como último comando de função sob `set -e`"*.
  Registrado no ledger como `kind: no-slot`
- [x] TX04 **Init parcial do `.agent/`** — `memory/process-friction.jsonl` (5 linhas),
  `memory/attempts.jsonl` (vazio), `README.md`. **Sem** `state.json`, **sem** `*_INDEX.md`
  * **Target**: `.agent/` (`[NEW]`)
  * **Validate**: `python3 -c "import json;[json.loads(l) for l in open('.agent/memory/process-friction.jsonl')]"`
- [x] TX05 Migração do atrito da tabela do `spec.md` para o ledger, traduzindo os `kind` para o
  **vocabulário fechado** do C5/1c. Achado da migração: `stale` tem 3 ocorrências mas **todas da
  spec 001** — bate a barra do META em número, não em dispersão. Pergunta registrada para o **H**

## Slice F2 — `second-opinion.sh` · Tier 2 · ✅ APLICADO (piloto v2.8) · PO-16/17 ✅ · PO-18/19 MANUAL

- [x] T060 [PO-16] Escrever `scripts/second-opinion.sh` sobre o core, com adaptadores `plan|analysis|spec`
  * **Mirror**: `scripts/ai-review.sh` (montagem de contexto e schema JSON estrito)
  * Sem `--dry-run` (sem efeito colateral a desligar); `--measure` para antes do motor (D-1).
    Schema próprio (`section/quote/severity/kind/issue/suggestion`), validado LOCALMENTE —
    motor fora do schema cai para o próximo / fail-open, nunca vira opinião capenga.
  * **Validate**: `bash tests/second-opinion.test.sh` → 23/23, com 5 mutações detectadas
- [x] T061 [PO-17] Provar egress guard e fail-open vindos do core, sem cópia local
  * Pré-requisito descoberto no C1.5: o core **não tinha** nenhum dos dois. Core **1.0.0 → 1.1.0**
    (+5 funções: `probe_engines`, `build_engine_args`, `egress_scan`, `egress_guard`, `fail_open`);
    probe e argv subiram junto (D-2: flag de segurança duplicada é a cópia que diverge).
  * `tests/ai-review-paths.sh` (`[NEW]`): caracteriza egress/failopen/legacy/schema — os 3 blocos
    que a baseline NÃO exercita (analysis-F2.md §2). Gravado com o core antigo (via `git stash`),
    comparado depois: `Files are identical` (96 linhas, argv do agy incluso)
  * **Validate**: baseline + `ai-review-paths.sh` idênticos · `second-opinion.test.sh --egress --failopen` 10/10
- [x] T062 [PO-18] Draft de F8 (posição-antes-da-leitura) em `skills/devflow-ceremony/`
  * **Mirror**: `ECC skills/council/SKILL.md:76-83`
  * Draft → `mutations/F2-F8-position-first.md`. Limite honesto no próprio draft: em sessão única
    isto é rastro de ancoragem, não independência — a voz independente é o passo 0b (script)
- [x] T063 [PO-19] Ligar C1.5 Tier 2 como cliente do script
  * Draft → `mutations/F2-C15-second-opinion.md` (item `1e`; Tier 0/1: não chame)
- [x] T063b **MP-005** emitida e **APROVADA pelo operador em 2026-09-22** ("novos modos lidos e
  aprovados"); aplicada em `devflow-ceremony` (passos 0/0b + RC-AUTO + QR) e `devflow-code`
  (C1.5 `1e` + QR). Bump **v2.7.0 → v2.8.0 (PILOTO)**; linha no META; `MP-005-applied` no log.
  * **Validate**: marcadores 8/4/4/4/2 · mode-gate 10/10 + 7/7 · no-core-shadowing 4/4 ·
    ai-review-no-agent 3/3 · second-opinion 23/23
- [~] T064 [C4] **PO-16 e PO-17 fechadas** (evidência colada). **PO-18 e PO-19 seguem `[ ] open`**:
  MANUAL, exigem projeto consumidor (A-2); guard de ambas satisfeito e anotado no bloco.
  [C5] journal: N/A (`.agent/` parcial, sem journal — A-1);
  atrito vai para `.agent/memory/process-friction.jsonl`
  * **Validate** (não-regressão): `tests/ai-review-baseline.sh` · `tests/ai-review-no-agent.test.sh`
    · `tests/no-core-shadowing.test.sh` (agora com 2 consumidores). **Não** `--dry-run`, **não** `verify-split.sh`

## Slice G — handoff · Tier 1 · ✅ DONE 2026-09-22 · fecha PO-20, PO-21

- [x] T070 [PO-20] Comparar 4 formatos (journal · arquivo por sessão · `state.json` · `attempts.jsonl` estendido)
  pelos 3 critérios: é lido na sessão seguinte sem o operador pedir? sobrevive a compact? quem mantém?
- [x] T071 [PO-20] Apresentar ao operador e registrar a escolha — **nenhuma edição no C5 antes disso**
  → 2026-09-22: **híbrido `state.json` + `attempts.jsonl`** (`handoff-study-G.md`)
- [x] T072 [PO-21] Draft do endurecimento do C5 no formato escolhido (motivo exato + demoção do não-evidenciado)
  * **Mirror**: `ECC commands/save-session.md:101-110`
- [x] T073 [C4] Fechar PO-20, PO-21 · [C5] journal
  → PO-20 `[x]`; PO-21 `[!]` (MANUAL, A-2). MP-006 aplicada, v2.9.0. Journal N/A (A-1)

## Slice H — falsificação · Tier 1 · ✅ DONE 2026-09-22 · depende: todos · fecha PO-22, PO-23

- [x] T080 [PO-22] Montar a medição de conformidade em 3 níveis de rigor (supportive/neutral/competing)
  * **Mirror**: `ECC skills/skill-comply/SKILL.md:12-17`
- [x] T081 [PO-22] Medir as mutações dos slices B–G e reportar taxa por nível
- [x] T082 [PO-23] Draft do caminho `external_corpus` no `DEVFLOW-META.md` (origin, assinatura de atrito, sunset)
  — **sem afrouxar** a barra reativa de 3+ observações / ≥2 specs
- [~] T083 Aplicar o veredito de cada mutação: promover (observação real apareceu) ou REMOVER (não apareceu)
  → 2026-09-22, decisão do operador: **sem veredito** — relógios não iniciados (A-1). Tabela em `falsification-H.md`
- [x] T084 [C4] Fechar PO-22, PO-23 · [C5] journal + fechamento da spec no índice
  → PO-22/23 `[x]`; MP-007 aplicada, **v3.0.0 (PILOTO)**; índice atualizado. Journal N/A (A-1)
