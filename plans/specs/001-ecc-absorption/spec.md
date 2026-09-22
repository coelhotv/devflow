# 001 — Absorção ECC → DEVFLOW

**Feature Directory:** `plans/specs/001-ecc-absorption/`
**Created:** 2026-09-19
**Status:** in-progress — slices A, B, C, D, E, F1 entregues; F2 é o próximo (G livre em paralelo)
**Tier:** 2
**Input:** garimpo de `/Users/coelhotv/git/Everything-Claude-Code` em duas rodadas
(`~/SKILLS/ecc-devflow-review-and-plan.md`, `~/SKILLS/ecc-devflow-mining-round2.md`)

---

## Context & Problem Statement

O DEVFLOW v2.3 evoluiu três vezes por fora do próprio protocolo de meta-evolução. Duas rodadas de
garimpo do ECC identificaram 8 lacunas instrucionais e 4 propostas estruturais que valem absorver.
Sem uma spec, isso vira um conjunto de edições soltas em arquivos de skill carregados em toda sessão —
exatamente o modo de falha que o DEVFLOW existe para evitar.

Esta spec é também o primeiro uso do DEVFLOW sobre si mesmo: o repositório não tinha `.agent/` nem
`plans/specs/`.

## Non-Goals (fora de escopo)

1. **Não** reescrever a divisão RC5/RC6. A separação autor-em-contexto vs. independente-em-contexto-frio
   é deliberada e foi confirmada na revisão — não é lacuna.
2. **Não** paralelizar a escrita de código (C3). "The filesystem is the orchestrator" é decisão de
   arquitetura; multi-agente ali compra contenção de arquivo, não qualidade.
3. **Não** introduzir rubricas numéricas de qualidade (escalas 1–10, confidence score). Rejeitado com
   base no próprio recuo do ECC em `commands/learn-eval.md:143-145`.
4. **Não** criar a skill `/devflow-aside`. Descartada: evidência fraca e `/btw` já cobre.
5. **Não** adotar hooks do Claude Code como substrato de enforcement — amarra o DEVFLOW a um cliente.

## System Invariants

Regras que nenhum slice pode violar. Quando uma virar contrato formal, promover a CON-NNN e referenciar.

- **INV-1 · R-065 permanece soberana.** Nenhuma mutação pode fazer o agente avançar de modo sozinho.
- **INV-2 · Portabilidade.** Todo enforcement novo roda em shell puro; nenhum comportamento pode
  depender de um cliente específico. Hook do Claude Code é açúcar opcional que só invoca o CLI.
- **INV-3 · Fail-open assimétrico.** Gate novo que não consegue decidir **deixa passar e marca**.
  Bloquear trabalho legítimo com carimbo de gate é o modo de falha inaceitável.
- **INV-4 · Nenhuma edição de prosa de skill fora do fluxo `devflow_mutation_proposal` + aprovação
  do operador (`DEVFLOW-META.md`).**
- **INV-5 · Mudança em C1/C4/Bootstrap exige incidente real** (`DEVFLOW-META.md:102`). Sem incidente,
  a mutação entra rebaixada a piloto com critério de remoção.
- **INV-6 · Máx. 2 propostas pendentes simultâneas** (`DEVFLOW-META.md:101`).

## Decisões transversais

### DT-1 · Regras de admissão (substituem o teto em LOC)
O recurso escasso não é linha; é o número de mecanismos distintos que um modelo fraco precisa segurar.
Toda mutação responde: **(a)** que mecanismo existente ela estende (criar novo exige justificar por que
nenhum serve); **(b)** o que ela aposenta, ou por que nada é aposentável; **(c)** pode ser script em
vez de prosa? Se pode, prosa é a escolha errada.

### DT-2 · Modo de evolução: esta spec é PROATIVA
O `DEVFLOW-META.md` é reativo (auto-heal: dor → ledger → 3 observações → proposta). Esta spec é
proativa: oportunidade minerada, **sem dor observada**. Risco dominante invertido — o pior caso não é
demorar, é construir maquinário que ninguém precisava (família AP-325). Controles compensatórios,
obrigatórios em toda proposta emitida por esta spec:

1. `origin: proactive` declarado na proposta e na linha de versão da skill.
2. **Assinatura de atrito prevista:** *"se isto importa, aparecerá `<kind>` em `process-friction.jsonl`
   em N sessões"*. Não apareceu ⇒ remover. O caminho proativo passa a **alimentar** o ledger reativo.
3. **Sunset por padrão:** reversível e expira, salvo promoção por observação real.
4. Nunca em C1/C4/Bootstrap sem incidente real (INV-5).

### DT-3 · Toda mutação nasce piloto com cláusula de falsificação
Exigência da v2.3 e compensação por DT-2. Nenhuma entra como regra consolidada nesta spec.

---

## User Stories

### US1 — O operador consegue rastrear o trabalho inteiro (P1)
Como operador do DEVFLOW, quero uma lista de slices com dependências e POs, para saber o que falta
sem reler dois relatórios de garimpo.

**Given** os relatórios das duas rodadas
**When** abro `spec.md` e `tasks.md`
**Then** cada achado está atribuído a exatamente um slice, com PO e critério de remoção.

### US2 — O controle de modo deixa de ser probabilístico (P1)
Como agente DEVFLOW rodando em qualquer cliente, quero que a transição de modo seja verificável por
script, para que a R-065 não dependa de eu lembrar dela.

**Given** um `state.json` e a skill carregada
**When** `scripts/mode-gate.sh` roda
**Then** devolve `{"ok":true}` ou `{"ok":false,"reason":…}`; e **na dúvida deixa passar marcando**.

### US3 — A evidência de uma PO passa a declarar a própria força (P2)
Como auditor no RC5 Pass 0, quero saber se a prova foi reconciliada, executada, lida ou inferida,
para distinguir demonstrado de afirmado.

**Given** um bloco `po` fechado
**When** o Pass 0 audita
**Then** a classe declarada em `evidence:` é confrontada com o que `proof:` prometia.

---

## Functional Requirements

- **FR-001** `spec.md` traz a tabela de slices como autoridade da ordem; todo `po` declara `slice:`.
- **FR-002** `scripts/mode-gate.sh` valida transição de modo sem LLM, em shell puro, com fail-open assimétrico.
- **FR-003** O gate é distribuído em 3 níveis de acoplamento; remover o nível 3 não altera comportamento.
- **FR-004** Bloco `po` ganha `boundary:`, `evidence:`, `uncertainty:` e o terceiro `status`.
- **FR-005** C-mode ganha caminho de falha: trio de aborto, ordenação por dependência, parada de busca no C1.5.
- **FR-006** R-065 ganha terminação mecânica e proibição do auto-consentimento.
- **FR-007** S4/P2.5/P3/RC5 recebem M2–M5 da 1ª rodada.
- **FR-008** Funções agnósticas do `ai-review.sh` passam a viver em `scripts/lib/engine-core.sh`, com equivalência provada.
- **FR-009** `scripts/second-opinion.sh` serve cerimônias e C1.5 Tier 2 sem tocar o caminho de PR.
- **FR-010** O protocolo de handoff é escolhido por comparação de formatos antes de virar texto no C5.
- **FR-011** `DEVFLOW-META.md` passa a prever evidência de corpus externo com controles compensatórios (DT-2).

## Success Criteria

- **SC-001** 100% dos ACs têm PO fechada (`status [x]`) ao fim do C-mode de cada slice.
- **SC-002** Nenhuma edição de prosa de skill ocorre fora de proposta aprovada (INV-4).
- **SC-003** Nunca mais de 2 propostas pendentes ao mesmo tempo (INV-6).
- **SC-004** Toda mutação desta spec carrega `origin: proactive`, assinatura de atrito prevista e sunset.
- **SC-005** `ai-review.sh` mantém comportamento byte-idêntico após a extração do `@core`.
  ⚠️ **Escopo precisado em 2026-09-21** (C5/4b): este SC vale para **a extração** (slice F1), não é
  um congelamento permanente do script. O conserto do AC-1, feito DEPOIS e em commit próprio,
  mudou comportamento de propósito — passou a sobreviver em repo sem `.agent/`. A redação original
  admitia a leitura "o `ai-review.sh` nunca mais muda", que nunca foi a intenção e teria proibido
  consertar um bug. A prova de não-regressão continua sendo a baseline, e ela seguiu
  `Files are identical` porque o fixture dela TEM `.agent/` — o caminho consertado não é o medido.

---

## Estado & próximo passo (leia primeiro numa sessão nova)

**Última sessão:** 2026-09-21 · **Slices A, B, C, D, E, F1 entregues** · **POs fechadas: 6 de 23**
(PO-1, PO-2, PO-7, **PO-10**, PO-14, PO-15) · **Propostas pendentes: 0** (INV-6: 2 vagas livres).
**Versão do DEVFLOW:** v2.3 → **v2.7.0 (PILOTO)** ao longo destes slices.

**Estado do repositório** (conferido no disco, 2026-09-21):

| | |
|---|---|
| Branch | `spec/001-ecc-absorption` — **11 commits à frente de `main`**, árvore limpa |
| PR | **nenhum aberto.** O épico inteiro vive no branch; a coluna PR da tabela de slices fica vazia até o épico virar PR (A-3) |
| Último commit | `bf1c893` — init parcial do `.agent/` + migração do ledger |
| Testes verdes | `mode-gate` 10/10 · `--degraded` 7/7 · `no-core-shadowing` 3/3 · `ai-review-no-agent` 3/3 · baseline `Files are identical` |
| `.agent/` | **EXISTE, mas é INIT PARCIAL** — leia `.agent/README.md` antes de concluir qualquer coisa a partir disso. A-1 e A-2 continuam de pé e nenhum relógio de sunset começou a correr |

### Como esta spec é executada (combinado com o operador — não redescubra)

1. **Branch ÚNICO para o épico inteiro:** `spec/001-ecc-absorption`. Um commit semântico por slice.
   `1 slice = 1 PR` é regra que o DEVFLOW impõe aos **clientes**, não a si mesmo (A-3).
2. **Todo slice que toca prosa de skill PARA no gate do operador** (INV-4). O ciclo é sempre:
   draft em `mutations/` → `devflow_mutation_proposal` no `mutations/evolution_log.jsonl`
   (`status: pending`) → **STOP** → operador aprova → aplicar → bump → commit.
   **Nunca** aplique sem a mensagem de aprovação. Aprovação é evento na conversa (v2.6, R-065).
3. **Toda mutação é `origin: proactive`** (DT-2): corpus externo, sem dor observada. Logo carrega
   assinatura de atrito prevista + sunset, e o **relógio do sunset só corre em projeto com ledger
   ativo** (A-1) — silêncio de um ledger que ninguém pode escrever não é evidência.
4. **PO MANUAL não fecha neste repo.** Exigem projeto consumidor real (A-2). Anote
   "instrumento pronto ≠ AC demonstrada" no bloco e siga. Nunca `[x]` sem evidência colada.
5. **`verify-split.sh` está APOSENTADO** — não use como gate (falha em HEAD limpo, por construção).
   ⚠️ Já foi citado por engano 3x (T014, T033, T044): se você o encontrar num `Validate:`, é a
   instrução que está velha, não o seu ambiente. Validação real:
   contagem de marcadores `devflow-split` + `tests/mode-gate.test.sh` (+ `--degraded`) +
   `tests/no-core-shadowing.test.sh` + `tests/ai-review-baseline.sh` + `tests/ai-review-no-agent.test.sh`.
   ⚠️ **Marcadores por arquivo, medidos no disco:** núcleo 8 · `devflow-code` 4 · `devflow-spec` 4 ·
   `devflow-plan` **2**. O `devflow-plan` **não tem bloco `qr`** — 2 é o número certo, não uma falta.
6. **Janela de tokens do Claude é o gargalo, não a do `agy`.** O operador liberou `agy -p` à
   vontade para leitura pesada, inventário e geração de prova. Guia de operação medido em
   `/Users/coelhotv/git/maestro/plans/OPERAR-MOTOR-EXTERNO.md`. **Saída de agente é dado, não
   evidência**: confira contra o disco antes de citar (ele já citou arquivos fora do corpus).
7. **Runners deste repo, resolvidos no C1 (não rechute):** não há `package.json`, `Makefile`,
   `Cargo.toml` nem `pyproject.toml`. `test:` as suítes de `tests/` · `lint:` `shellcheck` +
   `bash -n` · `typecheck:` **`NONE (ausente)`** · `build:` **`NONE (ausente)`**.
8. **O `.agent/` daqui é PARCIAL por decisão** (2026-09-21): só `process-friction.jsonl` e
   `attempts.jsonl`. Sem `state.json`, sem `*_INDEX.md`. Consequência prática para quem codar
   aqui: o C5 vai mandar cunhar um `AP-NNN` e **não há catálogo** — a lição vira teste, e o AP
   candidato fica anotado em prosa nomeando o MECANISMO. Já registrado como `no-slot` no ledger.

### Próximo passo exato

**Slice F2** — `scripts/second-opinion.sh` sobre o `@core` do F1, + os clientes (RC1–RC4 com F8,
C1.5 Tier 2). Tier 2, depende de C, D e F1 — **todos entregues**, logo está desbloqueado.
Ordem da tasks.md: T060 → T061 → T062 → T063 → T064.

**Livre, sem dependência:** slice **G** (estudo de formatos de handoff — Tier 1, só comparação e
decisão do operador; nenhuma edição no C5 antes da escolha).

ℹ️ O AC-1 (`ai-review.sh` morria em repo sem `ANTI_PATTERNS_INDEX.md`) foi **consertado em
2026-09-21**, antes do F2, e está coberto por `tests/ai-review-no-agent.test.sh`. Como o F2 mexe no
fail-open, essa suíte entra no conjunto de não-regressão do slice.

### Decisão pendente do operador

Nenhuma. (A última, o AC-1, foi decidida e resolvida em 2026-09-21 — ver *Achados colaterais*.)

### Onde está cada coisa

| Artefato | Caminho |
|---|---|
| Drafts e propostas | `plans/specs/001-ecc-absorption/mutations/` |
| Log de mutações | `mutations/evolution_log.jsonl` (MP-001..MP-003, todas `applied`) |
| Histórico versionado | `DEVFLOW-META.md`, tabela no fim |
| Relatórios de garimpo | `~/SKILLS/ecc-devflow-review-and-plan.md` e `~/SKILLS/ecc-devflow-mining-round2.md` — **`~/SKILLS` não é repo git**; leia do disco |
| Ledger de atrito | `.agent/memory/process-friction.jsonl` (5 linhas) — vocabulário FECHADO |
| Por que o `.agent/` é parcial | `.agent/README.md` — **leia antes de assumir que os relógios correm** |
| Suítes de teste | `tests/` — `mode-gate` · `no-core-shadowing` · `ai-review-baseline` · `ai-review-no-agent` |

### Entregue por slice

- **A** · `scripts/mode-gate.sh` + `tests/mode-gate.test.sh` (10/10, 7/7 degradados) + seção
  *Enforcement Substrate* no `references/DEVFLOW-REFERENCE.md`. PO-1, PO-2 ✅
- **B** · `devflow-code`: C1 resolve runners e proíbe `proof:` chutado · C1.5 ganha `1c` (parada:
  boundary/saturação/teto + `<!-- deferred: -->`) · C3 ordena erros por dependência · C4 ganha
  trio de aborto. PO-3..PO-5 abertas (MANUAL)
- **C** · núcleo: STOP mecânico (sem tool call após o STOP) + proibição do auto-consentimento.
  PO-6 aberta (MANUAL; o `guard:` já está satisfeito)
- **D** · gramática do `po`: `evidence_class` (T1+), `boundary` (T2), `uncertainty`/`red`
  (opcionais), `status: [!] unavailable`; Pass 0 ganha `3b` e `3c`. PO-7 ✅ · PO-8/9 MANUAL ·
  PO-10 → slice E
- **E** · `devflow-spec`: S4 exige `## Non-Goals` (≥2) e `## Invariants` · `devflow-plan`: P2.5
  Pattern Grounding (T2) + `Target`/`Mirror`/`Validate` nas tasks · `devflow-code`: Pre-Report Gate
  no RC5 Pass 1 (+2 Suppressions) e `uncertainty:` no C1.5 (`1d`) e no C4. MP-004 aprovada e
  aplicada; **v2.6.0 → v2.7.0 (PILOTO)**. **PO-10 ✅** · PO-11..PO-13 MANUAL (A-2)
- **Interlúdio (2026-09-21, fora da tabela de slices)** · conserto do **AC-1** (`|| true` nas duas
  guardas de `emit_wiki_block` + `tests/ai-review-no-agent.test.sh`, RED 0/3 → GREEN 3/3, baseline
  idêntica) · **init parcial do `.agent/`** (`process-friction.jsonl` com 5 linhas, `attempts.jsonl`
  vazio, `README.md` explicando o que NÃO está lá) · migração do atrito que morava em tabela
  markdown. **Não é slice e não fecha PO nenhuma** — é trabalho de manutenção que o épico
  descobriu, registrado aqui para não parecer que apareceu do nada no `git log`
- **F1** · `scripts/lib/engine-core.sh` (9 funções, `ENGINE_CORE_VERSION`) · `ai-review.sh`
  consome e valida a versão · `tests/ai-review-baseline.sh` (determinística) ·
  `tests/no-core-shadowing.test.sh`. **PO-14, PO-15 ✅**

### Atritos registrados — **MIGRADOS para o ledger em 2026-09-21**

Fonte de verdade agora é `.agent/memory/process-friction.jsonl` (5 linhas). Esta tabela era o
workaround de não haver ledger; virou histórico. ⚠️ Ao migrar, os `kind` foram traduzidos para o
**vocabulário fechado** que o C5/1c define (`unsatisfiable | no-slot | reinvented | contradiction |
stale`) — os nomes usados aqui (`test_expectation_wrong`, `gate_unsatisfiable`,
`instruction_describes_stale_reality`) eram livres, e vocabulário livre não se conta. Contar é o
ponto inteiro do mecanismo.

| kind original (livre) | kind no ledger (fechado) | O quê |
|---|---|---|
| `test_expectation_wrong` | `unsatisfiable` | teste do slice A nasceu tratando transição legítima como violação |
| `instruction_describes_stale_reality` | `stale` | `Validate` do T014 mandava rodar `verify-split.sh`, aposentado |
| `gate_unsatisfiable` | `unsatisfiable` | `proof:` da PO-14 passava por construção (sem `.js` no repo, diff sempre vazio) |
| — (novo) | `stale` | **3ª ocorrência** da mesma classe no T044 |
| — (novo) | `no-slot` | o C5 manda cunhar AP e este repo não tem catálogo (AC-1) |

⚠️ **Nota para o slice H:** a barra do META pede *3+ observações de ≥2 specs distintas*. O `stale`
já tem **3 ocorrências**, mas **todas da spec 001** — bate em número, não em dispersão. Num repo
com uma spec só, a exigência de dispersão pode ser inatingível por construção. Isso é uma pergunta
para o H, não algo a afrouxar aqui.

## Tabela de slices — autoridade da ordem

| Slice | Status | Escopo | Tier | Depende de | POs | Arquivos | PR |
|---|---|---|---|---|---|---|---|
| **A** | ✅ done | `mode-gate.sh` em 3 níveis de acoplamento | 1 | — | PO-1, PO-2 | `scripts/mode-gate.sh`, `tests/` | — |
| **B** | ⚠️ aplicado (piloto) · POs MANUAL abertas | C-mode: M1 runner detection · F5 parada de busca (C1.5) · F6 trio de aborto (C3/C4) | 2 | — | PO-3, PO-4, PO-5 | `skills/devflow-code/SKILL.md` | — |
| **C** | ⚠️ aplicado (piloto) · PO-6 MANUAL aberta | R-065: F7 terminação mecânica + proibição do Y/N auto-respondido | 1 | A | PO-6 | `SKILL.md` | — |
| **D** | ⚠️ aplicado (piloto) · PO-7 ✅ · PO-8/9 MANUAL · **PO-10 transferida para E** | Gramática do `po`: F1 `boundary:` · F2 `evidence:` · F3 `status [!]` · F4 `uncertainty:` · M6 RED | 2 | B | PO-7..PO-10 | `SKILL.md`, `skills/devflow-code/`, `skills/devflow-spec/` | — |
| **E** | ✅ done — PO-10 fechada · PO-11..13 MANUAL | Spec & Plan: M3 Non-Goals · M4 Pattern Grounding · M5 task grammar · M2 pre-report gate · **+ `uncertainty:` no C1.5 (dívida da PO-10)** | 1 | D | **PO-10**, PO-11..PO-13 | `skills/devflow-spec/`, `skills/devflow-plan/`, `skills/devflow-code/` | — |
| **F1** | ✅ done — PO-14, PO-15 fechadas | Extração do `@core` — zero mudança de comportamento | 2 | — | PO-14, PO-15 | `scripts/lib/engine-core.sh`, `scripts/ai-review.sh` | — |
| **F2** | ▶ next | `second-opinion.sh` + clientes (RC1–RC4 com F8, C1.5 Tier 2) | 2 | C, D, F1 | PO-16..PO-19 | `scripts/second-opinion.sh`, `skills/devflow-code/`, `skills/devflow-ceremony/` | — |
| **G** | ⏳ todo (estudo pode começar já) | Handoff: estudo de formato → endurecimento do C5 | 1 | — | PO-20, PO-21 | `skills/devflow-code/` (C5) | — |
| **H** | ⏳ todo | Falsificação: medição de conformidade + caminho `external_corpus` no META | 1 | todos | PO-22, PO-23 | `DEVFLOW-META.md`, `scripts/` | — |

**Branch:** `spec/001-ecc-absorption` — **único para o épico inteiro** (decisão do operador, 2026-09-19;
renomeado de `spec/001-ecc-absorption-slice-a`). Um commit semântico por slice; não se abre branch por slice.
A coluna PR da tabela fica vazia enquanto o épico não for aberto como PR.

**Execução:** A → B → C → D → E → F1 → F2 → G (estudo em paralelo desde o início) → H.
F1 não emite proposta (não toca prosa) — pode correr a qualquer momento.
Por INV-6 (máx. 2 propostas em voo): o slice A fechou sem emitir nenhuma, então B e C podem abrir juntos;
D espera uma das duas fechar.

---

## Proof Obligations

```po PO-1
slice:  A
ac:     mode-gate.sh aprova uma transição de modo legítima e rejeita uma com PO aberta
proof:  bash tests/mode-gate.test.sh
expect: todos os casos passam; caso "PO aberta" retorna ok=false com reason
guard:  bash -n scripts/*.sh && shellcheck scripts/mode-gate.sh
status: [x] done
# evidencia 2026-09-19: "10 passaram, 0 falharam" (exit=0), incluindo
#   "violacao: PO aberta em coding" -> ok=false e "PO fechada: passa" -> ok=true.
#   guard: shellcheck limpo, bash -n ok.
```

```po PO-2
slice:  A
ac:     na dúvida o gate deixa passar marcando — arquivo ausente, JSON malformado e campo desconhecido nunca bloqueiam
proof:  bash tests/mode-gate.test.sh --degraded
expect: os três casos retornam ok=true com uma marca de degradação; nenhum retorna ok=false
guard:  nenhum caso de teste do PO-1 regride
status: [x] done
# evidencia 2026-09-19: "7 passaram, 0 falharam" (exit=0) — state ausente, JSON malformado,
#   campo desconhecido, state vazio, JSON nao-objeto, skill desconhecida, kill switch:
#   todos ok=true com marca DEGRADED:*. Nenhum ok=false.
#   guard: suite PO-1 reexecutada verde depois.
```

```po PO-3
slice:  B
ac:     C1 resolve os comandos reais de test/lint/typecheck antes de qualquer PO citar comando
proof:  MANUAL — rodar C1 num projeto não-npm e colar a resolução registrada
expect: os comandos registrados vêm de state.json/manifesto do projeto, não de chute
guard:  nenhuma PO da sessão cita comando fora dos resolvidos
status: [ ] open
# M1 aplicado em skills/devflow-code/SKILL.md (C1, bloco RUNNERS RESOLVIDOS) em 2026-09-19.
#   Evidencia pendente: proof e MANUAL e exige C1 rodado em projeto nao-npm real (A-2).
#   INSTRUMENTO PRONTO != AC DEMONSTRADA. Nao marcar [x] sem colar a evidencia.
```

```po PO-4
slice:  B
ac:     C1.5 declara por que parou de buscar e registra o que ficou por ler
proof:  MANUAL — executar um C1.5 Tier 2 e colar o critério de parada disparado
expect: um dos três critérios nomeado + marcador deferred quando sobrar arquivo
guard:  o PASS do C1.5 continua exigindo tabela de evidência populada
status: [ ] open
# F5 aplicado em skills/devflow-code/SKILL.md (C1.5, item 1c) em 2026-09-19.
#   Evidencia pendente: proof e MANUAL e exige um C1.5 Tier 2 real (A-2).
#   INSTRUMENTO PRONTO != AC DEMONSTRADA. Nao marcar [x] sem colar a evidencia.
```

```po PO-5
slice:  B
ac:     um loop de correção aborta por delta líquido, repetição idêntica ou reclassificação de escopo
proof:  MANUAL — provocar erro repetido e colar o aborto com a condição citada
expect: a sessão para e escala, citando qual das três condições disparou
guard:  o caminho feliz do C3/C4 não ganha passo novo
status: [ ] open
# F6 aplicado em skills/devflow-code/SKILL.md (C3 + C4, trio de aborto) em 2026-09-19.
#   Evidencia pendente: proof e MANUAL e exige um loop de correcao real (A-2).
#   INSTRUMENTO PRONTO != AC DEMONSTRADA. Nao marcar [x] sem colar a evidencia.
```

```po PO-6
slice:  C
ac:     ao parar num gate a resposta termina sem mais tool calls, e o agente nunca responde o próprio Y/N
proof:  MANUAL — provocar um STOP de modo e inspecionar o transcript
expect: nenhuma tool call após a linha de STOP; nenhuma auto-resposta a pergunta do operador
guard:  scripts/mode-gate.sh continua verde
status: [ ] open
# F7 aplicado em SKILL.md (MODE CONTROL RULE) em 2026-09-19. guard SATISFEITO:
#   mode-gate.test.sh 10/10 + --degraded 7/7 verdes. proof PENDENTE: e MANUAL e exige
#   provocar um STOP real e inspecionar o transcript num projeto consumidor (A-2).
#   INSTRUMENTO PRONTO != AC DEMONSTRADA. Nao marcar [x] sem colar o transcript.
```

```po PO-7
slice:  D
ac:     todo po de Tier **2** declara boundary (o que não vale fazer para chegar lá)
boundary: não vale satisfazer isto afrouxando a própria regra para "opcional em todo tier" —
          um campo que ninguém é obrigado a preencher não prova nada sobre o mecanismo
proof:  grep -c 'boundary:' nos blocos po tocados por esta sessão
expect: toda PO que esta sessão tocou (PO-7..PO-10) declara boundary
guard:  blocos po legados sem boundary não invalidam (backfill oportunista)
evidence_class: execution
status: [x] done
# CORRECAO DE VERDADE (C5/4b, 2026-09-19): a AC dizia "Tier 1+". O orcamento aprovado na MP-003
#   gateou `boundary` em **T2 apenas** — obrigar em T1 vira preenchimento ritual. A AC foi
#   corrigida no CORPO para refletir o que foi entregue, nao o que foi imaginado.
# evidencia 2026-09-19: grep -c 'boundary:' nos 4 blocos tocados -> 4/4.
#   Regra aplicada no disco: SKILL.md (tabela canonica, Required=T2) e
#   skills/devflow-spec/SKILL.md (S4: "Tier 2 exige `boundary:` no bloco").
```

```po PO-8
slice:  D
ac:     todo po declara a classe da evidência e o Pass 0 confronta com o proof
boundary: não vale fechar isto lendo o texto do Pass 0 e declarando que ele confronta —
          a AC é sobre o Pass 0 REJEITAR um caso incompatível, não sobre a instrução existir
proof:  MANUAL — fechar uma PO com evidence_class static-read cujo proof prometia execução
expect: o Pass 0 rejeita por incompatibilidade de classe
guard:  POs com classe compatível continuam fechando normalmente
status: [ ] open
# INSTRUMENTO PRONTO 2026-09-19: `evidence_class` na tabela canonica (SKILL.md), regra de
#   confronto no C4 e passo 3b no RC5 Pass 0. proof PENDENTE: e MANUAL e exige provocar a
#   rejeicao num projeto consumidor (A-2). Nao marcar [x] sem colar a rejeicao.
# NOTA: o campo mudou de nome para `evidence_class` (colisao com o `evidence` regulado).
```

```po PO-9
slice:  D
ac:     um check que não pôde rodar fecha como [!] unavailable com motivo, em vez de mentir ou travar
boundary: não vale usar [!] como escape para prova incômoda — [!] é "não pôde rodar",
          nunca "deu trabalho rodar". Um [!] sem motivo verificável é pior que um [ ] open
proof:  MANUAL — rodar C4 sem acesso ao recurso do proof e colar o bloco
expect: status [!] com motivo; RC5 Pass 0 enxerga e reporta o gate desarmado
guard:  [!] nunca conta como [x] em nenhuma contagem de SC
evidence_class: static-read (parcial — ver nota)
status: [ ] open
# INSTRUMENTO PRONTO 2026-09-19: terceiro valor na tabela canonica do nucleo, regra dura
#   ("[!] nunca conta como [x]"), passo 3c no Pass 0 e linha na Quick Reference do nucleo.
#   A parte GUARD da AC e estatica e esta satisfeita (a regra esta escrita e e inequivoca);
#   o proof e MANUAL e exige um C4 real sem acesso ao recurso (A-2).
```

```po PO-10
slice:  E   # transferida de D em 2026-09-19 — ver nota
ac:     o C1.5/C4 tem onde registrar ignorância sem fabricar conteúdo
boundary: não vale fechar isto apontando o campo na tabela do núcleo — a AC nomeia C1.5 e C4,
          que são onde o agente TEM a ignorância; a tabela é onde o campo é definido, não usado
proof:  rtk grep -n 'uncertainty:' skills/devflow-code/SKILL.md
expect: o campo existe e a instrução proíbe inventar quando ele é aplicável
guard:  o limite de 3 marcadores [NEEDS CLARIFICATION] do S4 permanece
evidence_class: execution
status: [x] done
# evidencia 2026-09-21 (MP-004 aplicada): `grep -n 'uncertainty:' skills/devflow-code/SKILL.md`
#   -> 7 hits (exit 0), ANTES era 0. C1.5 item `1d` nas linhas 219-229 (onde o agente TEM a
#   ignorancia) + C4 linhas 452-454 (ao fechar a PO) + linha 1045 na Quick Reference.
#   A instrucao PROIBE inventar: "e PROIBIDO transformar ignorancia em conteudo plausivel" (:222).
#   BOUNDARY RESPEITADO: nao fechei apontando a tabela do nucleo — as 7 linhas estao em
#   skills/devflow-code/SKILL.md, que e o arquivo que a AC nomeia (C1.5 e C4).
#   guard: `Limit to 3 markers` intacto em skills/devflow-spec/SKILL.md:141.
#   INV-5: a linha do C4 entrou REBAIXADA A PILOTO (sem incidente real).
# --- historico do gap (nao apagar) ---
# GAP REAL 2026-09-19, nao e falta de acesso: `uncertainty` entrou na gramatica do NUCLEO
#   (SKILL.md, tabela canonica), mas NAO no C1.5 nem no C4 do devflow-code — o grep do proof
#   retorna vazio hoje. A MP-003 aprovou as secoes Proof Obligations, C3, C4, Pass 0 e S4;
#   **C1.5 nao estava entre elas**, e editar fora do aprovado violaria a INV-4.
#   => Fica [ ] open e exige uma proposta nova (candidata a entrar junto do slice E, que ja
#      mexe no S4/P2.5). NAO e [!]: [!] e "nao pode rodar", isto e "nao foi implementado".
```

```po PO-11
slice:  E
ac:     toda spec nova traz Non-Goals com ao menos 2 itens e Invariants
proof:  MANUAL — criar uma spec Tier 1 de teste e inspecionar as seções
expect: ambas as seções presentes e específicas, não genéricas
guard:  Tier 0 continua sem spec
status: [ ] open
# INSTRUMENTO PRONTO 2026-09-21 (MP-004): S4 do `devflow-spec` exige `## Non-Goals` (>=2 itens,
#   cada um nomeando algo adjacente recusado) e `## Invariants` com a ressalva CON-NNN
#   (skills/devflow-spec/SKILL.md:105-113). `proof` e MANUAL: exige criar uma spec T1 de teste e
#   julgar se as secoes sairam especificas ou genericas — julgamento que so vale num projeto
#   consumidor real (A-2). INSTRUMENTO PRONTO != AC DEMONSTRADA. Nao marcar [x] sem colar as secoes.
```

```po PO-12
slice:  E
ac:     o P2.5 exige file:line real ou a string NENHUM PADRÃO EXISTENTE
proof:  MANUAL — rodar P2.5 Tier 2 e colar a tabela
expect: nenhuma célula vazia; convenções inventadas rejeitadas
guard:  Tier 1 não é obrigado a P2.5
status: [ ] open
# INSTRUMENTO PRONTO 2026-09-21 (MP-004): P2.5 criado em skills/devflow-plan/SKILL.md:93-118
#   (4 dimensoes, `file:line` obtido por grep NESTA sessao ou a string literal
#   `NENHUM PADRAO EXISTENTE`, celula vazia BLOQUEIA o P3) + M5 em :148-161 (`Target`/`Mirror`/
#   `Validate` no bloco `Each task MUST`), que e como o Tier 1 herda a ancoragem.
#   `proof` e MANUAL: exige rodar um P2.5 T2 num repo com codigo real (A-2).
#   INSTRUMENTO PRONTO != AC DEMONSTRADA. Nao marcar [x] sem colar a tabela preenchida.
```

```po PO-13
slice:  E
ac:     RC5 Pass 1 aceita zero findings como resultado válido e exige prova para HIGH/CRITICAL
proof:  MANUAL — revisar um diff limpo e colar a saída
expect: Pre-Landing Review: No issues found, sem achados fabricados
guard:  a lista de Suppressions não é duplicada em lugar nenhum
status: [ ] open
# INSTRUMENTO PRONTO 2026-09-21 (MP-004): Pre-Report Gate em skills/devflow-code/SKILL.md:742-763,
#   entre *Verification of Claims* e *Fix-First Protocol* — limiar ~80% como aposta verbal (nao
#   rubrica numerica: Non-Goal 3), prova (a)(b)(c) obrigatoria para HIGH/CRITICAL, e a autorizacao
#   explicita de que zero achados e resultado correto.
#   A PARTE GUARD DA AC ESTA SATISFEITA E FOI VERIFICADA: `grep -n 'Suppressions — DO NOT flag'`
#   -> 2 hits, e os dois sao legitimos: :766 e a REFERENCIA que o gate faz ("ver *Suppressions*,
#   abaixo") e :789 e o CABECALHO da secao, que continua unica. Uma unica lista, citada de um lugar
#   novo — o gate acrescenta 2 linhas (teto do garimpo) e nao a duplica.
#   (Corrigido em 2026-09-21: a primeira redacao desta nota dizia "1 ocorrencia", contando errado
#   por nao prever a propria linha de referencia. O numero certo e 2, e o guard segue satisfeito.) O `proof` e MANUAL: exige revisar um diff limpo real (A-2).
#   INSTRUMENTO PRONTO != AC DEMONSTRADA. Nao marcar [x] sem colar a saida da revisao.
```

```po PO-14
slice:  F1
ac:     ai-review.sh mantém saída byte-idêntica após a extração do @core
proof:  bash tests/ai-review-baseline.sh /tmp/before.txt  (antes) ; idem /tmp/after.txt (depois) ; diff
expect: diff vazio (exit 0)
guard:  a baseline é determinística — duas execuções seguidas produzem arquivos idênticos
evidence: reconciliation (execução real, saída colada)
status: [x] done
# evidencia 2026-09-19: diff before.txt after.txt -> "Files are identical" (exit 0), 14 linhas,
#   incluindo changed=3, tier=1, full-file attach 2/2 ~163B, preamble 395B,
#   "MEASURE: total payload across 1 chunk(s) = 1369B". Reconfirmado apos os ajustes de bash 3.2.
#   guard: 2 execucoes consecutivas da baseline -> "Files are identical".
#   shellcheck: nenhum achado NOVO de substancia — so SC1091 (source nao seguido estaticamente)
#   e SC2034 PASSB_TIMEOUT (agora consumido DENTRO do core; e o contrato documentado no cabecalho).
#
# NOTA DE METODO — o `proof:` original desta PO foi SUBSTITUIDO, e o motivo importa:
#   era `./scripts/ai-review.sh --dry-run > after.txt && diff before.txt after.txt`. Nao provava nada.
#   (a) --dry-run AINDA CHAMA O ENGINE (ai-review.sh:20) — saida de LLM nao e reproduzivel;
#   (b) este repo nao tem .js/.ts, entao o script saía em "No code changes" antes de montar
#       contexto: o diff daria VAZIO sempre, inclusive com o refactor quebrado. Gate que passa
#       por construcao e pior que gate nenhum.
#   Substituido por RC6_MEASURE=1 sobre um repo-fixture com diff real, que para antes do engine.
```

```po PO-15
slice:  F1
ac:     nenhuma função do @core é redefinida localmente em nenhum consumidor
proof:  bash tests/no-core-shadowing.test.sh
expect: zero redefinições encontradas
guard:  engine-core.sh declara versão e todo consumidor cita a que espera
evidence: execution (suite rodada, saida colada)
status: [x] done
# evidencia 2026-09-19: "3 passaram, 0 falharam" (exit=0).
#   core exporta 9 funcoes: ab_counts ab_total clamp_index clamp_lines engine_err_hint
#   log run_bounded run_engine unwrap_structured.
#   scripts/ai-review.sh cita ENGINE_CORE_EXPECTED="1.0.0"; zero redefinicoes.
#   guard: o teste FALHA se um consumidor der source sem citar versao — e a checagem 3a.
#
# ESCOPO HONESTO: hoje ha UM consumidor. O texto original dizia "ambos os consumidores"
#   supondo o second-opinion.sh, que so nasce no slice F2. O teste descobre consumidores por
#   grep (nao tem lista fixa), entao o segundo entra sob a mesma regra no dia em que existir.
```

```po PO-16
slice:  F2
ac:     second-opinion.sh avalia um plan.md em processo frio e devolve JSON no schema
proof:  ./scripts/second-opinion.sh --artifact plan --dry-run
expect: JSON válido contra o schema, sem nenhum caminho de PR exercitado
guard:  bash tests/ai-review-baseline.sh segue `Files are identical` e bash tests/ai-review-no-agent.test.sh segue 3/3
status: [ ] open
# guard CORRIGIDO 2026-09-22 (antes do F2 começar): citava `./scripts/ai-review.sh --dry-run`
#   idêntico ao PO-14 — o método que a nota da PO-14 já desqualificou (--dry-run chama o engine,
#   saída não-reproduzível). Trocado pelas duas suítes que de fato medem não-regressão.
```

```po PO-17
slice:  F2
ac:     o egress guard e o fail-open valem para o second-opinion sem duplicação de código
proof:  bash tests/second-opinion.test.sh --egress --failopen
expect: ambos os controles disparam a partir do @core
guard:  nenhuma cópia local de egress/fail-open no script novo
status: [ ] open
```

```po PO-18
slice:  F2
ac:     cada papel de cerimônia registra a posição própria antes de ler as demais
proof:  MANUAL — rodar RC1→RC3 e colar as três posições iniciais
expect: as posições estão datadas antes da síntese e divergem entre si quando cabe
guard:  a cerimônia continua parando no fim de cada RC (R-065)
status: [ ] open
```

```po PO-19
slice:  F2
ac:     C1.5 Tier 2 pode pedir segunda opinião independente sobre a análise
proof:  ./scripts/second-opinion.sh --artifact analysis --dry-run
expect: JSON com findings sobre a análise, contexto frio confirmado no cabeçalho
guard:  Tier 0 e Tier 1 não chamam o script
status: [ ] open
```

```po PO-20
slice:  G
ac:     existe uma comparação de formatos de handoff decidida pelo operador
proof:  MANUAL — apresentar a comparação e registrar a escolha
expect: os quatro formatos avaliados pelos três critérios; uma escolha registrada
guard:  nenhuma edição no C5 antes da escolha
status: [ ] open
```

```po PO-21
slice:  G
ac:     o C5 passa a exigir motivo exato da falha e demove o não-evidenciado
proof:  MANUAL — encerrar uma sessão com uma tentativa falha e colar o registro
expect: motivo exato presente; item sem evidência aparece como não-tentado
guard:  o journal e attempts.jsonl continuam append-only
status: [ ] open
```

```po PO-22
slice:  H
ac:     uma instrução nova é medida quanto a ser seguida sob prompt que não a apoia
proof:  MANUAL — rodar a medição nos três níveis de rigor e colar a taxa
expect: taxa de conformidade reportada por nível, incluindo o nível competing
guard:  a medição não altera nenhuma skill
status: [ ] open
```

```po PO-23
slice:  H
ac:     DEVFLOW-META.md passa a prever evidência de corpus externo com controles compensatórios
proof:  rtk grep -n 'proactive' DEVFLOW-META.md
expect: origin, assinatura de atrito prevista e sunset descritos
guard:  a barra reativa de 3+ observações / 2+ specs permanece intacta
status: [ ] open
```

---

## Achados colaterais (não previstos pela spec)

### AC-1 · ~~`ai-review.sh` morre em repo sem `.agent/memory/ANTI_PATTERNS_INDEX.md`~~ → **RESOLVIDO 2026-09-21**
Descoberto ao montar a baseline do F1. `emit_wiki_block` termina num `[ -f "$AP_IDX" ]` que
retorna 1 quando o arquivo não existe; a função é o elo esquerdo do pipeline que alimenta
`WIKI_BYTES="$(emit_wiki_block "" | wc -c | tr -d ' ')"`, e `set -o pipefail` + `set -e`
(linha 40) derrubam o script inteiro. Saída: exit 1 sem mensagem de erro.

**Por que nunca apareceu:** o consumidor real (dosiq) tem `.agent/`, e este repo sai antes, em
"No code changes". Dois acasos escondendo o mesmo defeito.

**Por que NÃO foi consertado no F1:** a PO-14 exige comportamento byte-idêntico antes e depois da
extração. Consertar um bug no mesmo slice destruiria a própria prova de equivalência — e um
refactor que muda comportamento "de leve" é exatamente o que a PO existe para impedir. O fixture da
baseline cria `.agent/memory/` (é o que um consumidor DEVFLOW tem) e o defeito fica registrado aqui.

**Decisão do operador (2026-09-21):** nem spec própria, nem F2 — **conserto Tier 0 em commit
isolado**, feito antes de retomar os slices. Motivo que mudou a recomendação original: a classe do
bug JÁ estava diagnosticada neste arquivo (`ai-review.sh:1208` carrega um `|| true` com o
comentário explicando o mesmo mecanismo). Não era bug novo — era a 2ª ocorrência de um conserto
entendido uma vez e não generalizado. Spec dir para 2 caracteres é o ritual que o DT-1 proíbe.

**Como foi consertado:** `|| true` nas DUAS guardas de `emit_wiki_block` (`:492` e `:493`) + um
`return 0` explícito. Blindar só a última convidaria a reintroduzir o bug ao reordenar o bloco.

**Evidência (RED → GREEN):** `tests/ai-review-no-agent.test.sh` — espelho do fixture da PO-14 com
`.agent/` AUSENTE. Antes: `0 passaram, 3 falharam`, `exit 1` mudo logo após a linha do `selector`.
Depois: `3 passaram, 0 falharam`. **Não-regressão:** `tests/ai-review-baseline.sh` antes/depois →
`Files are identical` (o fixture da baseline TEM `.agent/`, então o caminho consertado não é
exercitado ali — é exatamente por isso que o teste novo precisou de fixture próprio).

**O AP não foi cunhado:** este repo não tem `ANTI_PATTERNS_INDEX.md` — por decisão, não por
esquecimento (ver `.agent/README.md`). A defesa durável passa a ser o TESTE, não o catálogo. Se um
dia houver catálogo aqui, o candidato é: *"guarda `[ -f ]` como último comando de função sob
`set -e`"* — nomeando o mecanismo, nunca o arquivo.

## Assumptions & Open Questions

- **A-1** O repo `devflow` tem `.agent/` **parcial** desde 2026-09-21 (só `process-friction.jsonl`
  e `attempts.jsonl`; sem `state.json`, sem `*_INDEX.md` — ver `.agent/README.md`); esta spec vive
  em `plans/specs/`. Consequência que continua valendo: journal e catálogo de AP seguem N/A aqui, e
  nenhum relógio de sunset começou a correr. (Redação original, até 2026-09-21: "seguirá sem `.agent/`".)
- **A-2** Os slices B–H exigem projeto consumidor real (dosiq) para POs MANUAL.
- **A-3** `1 slice = 1 PR` é regra que o DEVFLOW **impõe aos seus clientes**, não que ele obedeça a
  si mesmo (decisão do operador, 2026-09-19). Aqui o artefato é texto de skill e shell — não há
  codebase de runtime, logo não há blast radius de deploy que justifique um PR por slice. O épico
  inteiro vive em `spec/001-ecc-absorption`, um commit semântico por slice. **Não é mutação:** a
  tabela de Work Tiers permanece como está, e nenhuma proposta é emitida por causa disto.
- **[NEEDS CLARIFICATION]** O formato de handoff do slice G — decisão do operador no PO-20.
- ~~**[NEEDS CLARIFICATION]** Se `po_unstable` está morto~~ → **RESOLVIDO (T030, 2026-09-19): está VIVO.**
  Mora em `skills/devflow-distill/SKILL.md:42,47` — evento que o distill captura quando uma PO
  repete/falha, realimentando a escolha de tier. O slice D **não o absorve nem o mata**: integra.
  Um `status [!] unavailable` (F3) é justamente um sinal que o distill deveria contar ao lado do
  `po_unstable`, e essa ligação precisa entrar no draft.
- ~~**[NEEDS CLARIFICATION]**~~ → **RESOLVIDO (a).** **Colisão de nome em `evidence:`.** O campo JÁ
  EXISTE no núcleo (`SKILL.md:364`), restrito a Tier 2 regulado, e significa *"onde a linha de
  auditoria aparece na saída do proof"*. O FR-004 quer `evidence:` com outro sentido — a **classe**
  da prova (reconciled / executed / static-read / inferred). Dois sentidos sob um nome é o modo de
  falha que o Pass 0 não consegue auditar. Três saídas, decisão do operador:
    (a) **ESCOLHIDA pelo operador em 2026-09-19** — o campo novo chama-se `evidence_class:` e o
        `evidence:` regulado fica intacto;
    (b) `evidence:` passa a ser a classe (geral, todo tier) e o regulado vira `audit_evidence:`;
    (c) fundir num só campo com duas partes (`evidence: executed — linha 42 do output`).
  Recomendo **(a)**: não toca em nada que já funciona e não exige backfill de bloco regulado.
