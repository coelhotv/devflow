# DEVFLOW — Combined Workflow Guide

> How to use `/devflow coding` + `/deliver-sprint` and `/devflow reviewing` + `/check-review`
> together to extract maximum value from both skill layers.
>
> Reference project: **meus-remedios** (React/Node, DEVFLOW-migrated, 106 rules, 93 APs, 16 contracts)

---

## The Mental Model

Each skill pair has a clear division of labor:

| Layer | Skill | Responsibility |
|-------|-------|---------------|
| **Memory + Governance** | DEVFLOW | Rules, contracts, ADRs, anti-patterns, journal, quality gate enforcement |
| **Delivery Mechanics** | deliver-sprint | Branch, commits, PR creation, GitHub workflow, documentation |
| **Memory + Governance** | DEVFLOW | Review findings → memory sync, trigger_count, new AP proposals |
| **PR Review Mechanics** | check-review | Fetch AI comments, classify, fix, reply inline, approval gate |

DEVFLOW is the brain — it enforces what the team has learned.
The sub-skills are the hands — they execute the operational steps efficiently.

**The wrong way:** invoke deliver-sprint or check-review directly without DEVFLOW context.
The agent will lack rules, contracts, and anti-patterns — making the same mistakes already documented.

**The right way:** DEVFLOW opens and closes every session. Sub-skills execute in the middle.

---

## Flow 1 — Feature Delivery: `/devflow coding` + `/deliver-sprint`

### Sequence Diagram

```
Human                    DEVFLOW (coding)              deliver-sprint
  │                           │                              │
  ├─ /devflow coding ─────────►                              │
  │  "feat: <goal>"           │                              │
  │                     Phase 0: Bootstrap                   │
  │                     ─ read state.json                    │
  │                     ─ load rules.json (filtered)         │
  │                     ─ load anti-patterns.json (filtered) │
  │                     ─ load knowledge.json (filtered)     │
  │                     ─ load _detail/ for relevant entries │
  │                     ─ write index_loaded_at to state.json│
  │                           │                              │
  │                      C1: Pre-Code Checklist              │
  │                     ─ verify target files exist          │
  │                     ─ verify path aliases                │
  │                     ─ identify relevant contracts        │
  │                     ─ confirm spec in plans/             │
  │                           │                              │
  │                      C2: Contract Gateway                │
  │                     ─ grep contracts.json for each file  │
  │             [breaking?]───┤                              │
  │◄── HALT: draft ADR ───────┤ (human resolves)            │
  │                     [non-breaking]                       │
  │                     [C2 GATE fires — always]             │
  │◄── summary + STOP ────────┤                              │
  │    (await go-ahead)       │                              │
  │                           │                              │
  ├─ /deliver-sprint ─────────┼─────────────────────────────►
  │  OR "go" (DEVFLOW runs C3)│                              │
  │                           │   DEVFLOW_ACTIVE=true        │
  │                           │   rules/APs/contracts loaded │
  │                           │                              │
  │                           │    Step 0.5: create branch   │
  │                           │    Step 1: exploration       │
  │                           │    (guided by loaded rules)  │
  │                           │    Step 2: implementation    │
  │                           │    (C3 layer order enforced) │
  │                           │    Step 3: quality gates     │
  │                           │    (C4 commands from         │
  │                           │     state.json/knowledge)    │
  │                           │    Step 4.1: SKIP .memory/   │
  │                           │    (DEVFLOW handles memory)  │
  │                           │    Step 5: PR creation       │
  │                           │    Step 6: await approval    │
  │                           │    Step 7.3: emit C5 signal  │
  │                           │◄── "deliver-sprint complete" │
  │                           │                              │
  │                      C5: Post-Code Protocol              │
  │                     ─ new rule? → rules.json + detail    │
  │                     ─ new AP? → anti-patterns.json       │
  │                     ─ contract changed? → contracts.json │
  │                     ─ ADR finalized? → decisions.json    │
  │                     ─ append to events.jsonl             │
  │                     ─ write journal YYYY-WWW.jsonl       │
  │                     ─ update state.json                  │
  │                     ─ check distillation threshold       │
  │◄── DEVFLOW response ──────┤                              │
```

---

### Step-by-Step Invocation

#### Invocação 1 — Abrir sessão DEVFLOW

```
/devflow coding "feat: add medication schedule export to PDF — meus-remedios"
```

O agente executa Phase 0 completo antes de qualquer ação. Output esperado:

```
DEVFLOW coding — meus-remedios — 2026-04-08

Goal
  feat: add medication schedule export to PDF
  Type: feature | Sprint: 2026-W15

Assess
  state.json: sprint 2026-W15, last distillation 2026-04-01
  Rules loaded: R-012 (PDF generation), R-034 (async service pattern),
                R-067 (error boundary), R-089 (GR-045 export contract)  [4 of 106]
  APs loaded:   AP-T01 (date parsing), AP-031 (memory leak in blob URL)  [2 of 93]
  Contracts:    CON-004 (MedicationService.getSchedule), CON-011 (ExportService)
  Knowledge:    topics: pdf-libs, file-download, blob-handling loaded

[C1 — Pre-Code Checklist]
  ✓ rules.json index loaded (R-012, R-034, R-067, R-089 relevant)
  ✓ anti-patterns.json loaded (AP-T01, AP-031 relevant)
  ✓ Target file: src/services/ExportService.ts → exists (1 result)
  ✓ No duplicates: count = 1
  ✓ Path alias: @services → src/services (confirmed via tsconfig.json)
  ✓ Contracts identified: CON-011 (ExportService)
  ⚠ No spec found for this task → proceeding to create plans/EXEC_SPEC_PDF_EXPORT.md

[C2 — Contract Gateway]
  CON-011: ExportService.generatePDF(options: ExportOptions): Promise<Blob>
  Planned change: additive (new optional field in ExportOptions) → NON-BREAKING

  ╔══ DEVFLOW C2 GATE ══════════════════════════════╗
  ║ Files to modify   : ExportService.ts,           ║
  ║                     ExportButton.tsx,           ║
  ║                     ExportOptions.ts            ║
  ║ Contracts touched : CON-011 (non-breaking)      ║
  ║ Rules to apply    : R-012, R-034, R-067         ║
  ║ Watch-for AP-NNN  : AP-031 (blob URL cleanup)   ║
  ║ C3 order          : schemas → services →        ║
  ║                     components → tests          ║
  ║ C4 quality gates  : npm run lint &&             ║
  ║                     npm run test -- Export      ║
  ╚═════════════════════════════════════════════════╝

  → Awaiting go-ahead.
      "go"             — DEVFLOW runs C3 → C4 → C5
      /deliver-sprint  — hand off; DEVFLOW resumes at C5
      "stop"           — abort, state preserved
```

#### Invocação 2 — Iniciar deliver-sprint

```
/deliver-sprint
```

O deliver-sprint detecta `DEVFLOW_ACTIVE=true` e adapta:

- **Step 0.1:** Detecta `.agent/DEVFLOW.md` → `DEVFLOW_ACTIVE=true`
- **Step 0.2:** Pula leitura de `.memory/` — contexto já carregado pelo DEVFLOW
- **Step 0.5:** Cria branch `feature/pdf-export`
- **Step 1:** Explora código **guiado pelas regras já carregadas** (R-012, R-034)
- **Step 2:** Implementa na ordem C3 (schemas → services → components → views → tests)
- **Step 3:** Roda quality gates definidos em `state.json`
  ```bash
  npm run lint && npm run test -- --testPathPattern=Export
  ```
- **Step 4.1:** Pula escrita em `.memory/` — anota internamente para C5 signal
- **Step 5:** Cria PR com template `references/PULL_REQUEST_TEMPLATE.md`
- **Step 6:** Hard stop — aguarda aprovação humana
- **Step 7.3:** Emite sinal C5:

```
Signal to DEVFLOW: "deliver-sprint complete — run C5"
Files changed: src/services/ExportService.ts, src/components/ExportButton.tsx,
               src/schemas/ExportOptions.ts, tests/ExportService.test.ts
New patterns found: yes — async blob URL cleanup pattern (prevent AP-031 variant)
New bugs/pitfalls hit: no
Contracts touched: CON-011 (additive change — new optional field exportLocale)
ADRs required: no
```

#### Invocação 3 — DEVFLOW C5 (dispara automaticamente)

DEVFLOW recebe o sinal e executa C5. Output esperado:

```
[C5 — Post-Code Protocol]
  ✓ New pattern: R-107 "Revoke blob URL in useEffect cleanup"
    → Added to rules.json + rules_detail/R-107.md
  ✓ CON-011 updated: exportLocale field added (non-breaking)
    → contracts.json updated + contracts_detail/CON-011.md updated
  ✓ Appended to events.jsonl: {event: "coding_complete", files: [...], rules_applied: ["R-012","R-034"]}
  ✓ Journal entry written: memory/journal/2026-W15.jsonl
  ✓ state.json: journal_entries_since_distillation = 7 (threshold: 10)
  → Distillation NOT triggered yet (3 entries away)

Record
  Rules:         R-107 added
  Anti-Patterns: AP-031 checked (not triggered — cleanup implemented correctly)
  ADRs:          none
  Contracts:     CON-011 updated (additive)
  Journal:       entry written to 2026-W15.jsonl

Next Session
  Distillation needed: no (7/10 entries)
  Pending human approvals: none
```

---

### Invocação tardia do /deliver-sprint (Late Invocation Protocol)

**Cenário:** No C2 Gate o usuário respondeu `"go"` — DEVFLOW executou C3 e C4 diretamente.
A implementação está pronta. Agora o usuário quer usar o /deliver-sprint para os
steps de Git/PR/merge (que DEVFLOW não faz).

Este é um fluxo válido, não um workaround. O deliver-sprint entra em **modo de finalização**
— pula os steps já cobertos e começa a partir do que ainda não foi feito:

```
/deliver-sprint
(implementação já completa — iniciar em modo de finalização)
```

| Step deliver-sprint | Ação no late invocation |
|--------------------|-----------------------|
| 0.1 Discovery      | SKIP — DEVFLOW já detectou contexto |
| 0.2 Read memory    | SKIP — DEVFLOW Bootstrap já fez isso |
| 0.3 PR template    | RUN — verificar se template existe |
| 0.4 To-do list     | RUN — criar lista com Steps restantes |
| 0.5 Create branch  | RUN se branch não existe ainda ⚠️ |
| 1 Exploration      | SKIP — DEVFLOW C1 já explorou |
| 2 Implementation   | SKIP — DEVFLOW C3/C4 já implementou |
| 3 Validation       | RUN — rodar lint + tests (confirmar C4 passou) |
| 4.1 Memory update  | SKIP — DEVFLOW C5 cuida disso |
| 4.2 Final commits  | RUN — revisar commits, garantir semântica |
| 5 Push + PR        | RUN — criar PR estruturado |
| 6 Merge            | RUN — aguardar aprovação humana |
| 7.3 DEVFLOW signal | RUN — emitir C5 signal |

> ⚠️ **Branch ausente é o risco mais alto no late invocation.** Se DEVFLOW rodou C3/C4
> direto em `main`, o deliver-sprint Step 0.5 deve criar o branch e mover os commits:
> ```bash
> git checkout -b feature/<slug>
> # commits já existem — só precisam estar no branch certo
> ```
> Verifique com `git branch` e `git log --oneline` antes do push.

---

### Anti-patterns de invocação (Fluxo 1)

| Anti-Pattern | Consequência | Correto |
|-------------|-------------|---------|
| Rodar `/deliver-sprint` direto sem `/devflow coding` | Nenhuma regra ou contrato carregado — agente navega cego | Sempre abrir DEVFLOW primeiro |
| Terminar o deliver-sprint e não esperar o C5 | Memória não atualizada — próximo agente não saberá da mudança | Aguardar DEVFLOW C5 completar antes de declarar sessão encerrada |
| Ignorar o HALT do C2 e continuar codando | Quebra de contrato sem ADR — viola CON-NNN sem rastro | Resolver ADR com humano antes de implementar |
| Abrir `/devflow coding` sem goal específico | Bootstrap sem filtro carrega regras irrelevantes — contexto inflado | Sempre passar goal descritivo e tipado |
| Invocar `/deliver-sprint` no late invocation sem checar branch | Cria PR a partir de `main` sem branch — histórico contaminado | Sempre verificar `git branch` antes do Step 0.5 |

---

## Flow 2 — Code Review: `/check-review` + `/devflow reviewing`

### Sequence Diagram

```
Human                  check-review              DEVFLOW (reviewing)
  │                        │                           │
  ├─ [PR aberto,           │                           │
  │   AI reviewer          │                           │
  │   comentou]            │                           │
  │                        │                           │
  ├─ /check-review ───────►│                           │
  │                  Step 1: Fetch all comments        │
  │                  Step 2: Classify by priority      │
  │                  Step 3: Evaluate                  │
  │                  ─ cross-check contracts.json      │
  │                  ─ cross-check rules.json          │
  │                  ─ cross-check anti-patterns.json  │
  │                  ─ record R-NNN/AP-NNN refs        │
  │                  Step 4: Apply fixes + commits     │
  │                  Step 5: Reply inline to threads   │
  │                  Step 6: Wait for re-review        │
  │                  Step 7: Check approval status     │
  │◄── "Ready for          │                           │
  │     human approval"    │                           │
  │                  Step 8: DEVFLOW Sync payload ────►│
  │                        │                           │
  │                        │                    R1: Load review context
  │                        │                    ─ (indexes already loaded
  │                        │                       from coding session or
  │                        │                       fresh bootstrap if new)
  │                        │                    R2: Violation scan
  │                        │                    ─ enhanced by Step 8 payload
  │                        │                    R3: Severity classification
  │                        │                    R4: Memory update
  │                        │                    ─ trigger_count++ for AP-NNN
  │                        │                    ─ propose new AP if "new"
  │                        │                    ─ append review_complete event
  │                        │                    ─ write journal entry
  │◄── Review output ──────┼───────────────────┤
```

---

### Step-by-Step Invocation

#### Contexto: PR aberto no meus-remedios, Gemini Code Assist comentou

#### Invocação 1 — Processar review do AI reviewer

```
/check-review
```

check-review executa Steps 1–7. No Step 3.2 (DEVFLOW mode), cruza com memória:

```
[Step 3.2 — DEVFLOW cross-check]
  contracts.json consulted:
    Comment #42 (file: src/services/MedicationService.ts:87) →
    matches CON-004 interface → suggestion is BREAKING → elevate to Decline
    Reason: "DEVFLOW CON-004 in effect — getSchedule() return type is contracted"

  rules.json consulted:
    Comment #38 (High — missing error handling) → covered by R-034 (async service pattern)
    Note for DEVFLOW sync: R-034 triggered (violation)

  anti-patterns.json consulted:
    Comment #51 (date parsing issue) → matches AP-T01 exactly
    Note for DEVFLOW sync: AP-T01 triggered
```

Output Step 8 (DEVFLOW Sync payload):

```
DEVFLOW SYNC — check-review complete
PR: #183

Violations found:
  - src/services/MedicationService.ts:87 — missing error handling on async call [R-034 violated]
  - src/components/DoseCard.tsx:23 — new Date('YYYY-MM-DD') usage [AP-T01 triggered]

Contracts touched:
  - CON-004 (getSchedule return type) — suggestion DECLINED, breaking change [contract defended]

Rules well-applied:
  - src/services/ExportService.ts:45 — blob cleanup in useEffect [R-107 applied]

New patterns proposed:
  - "Always validate medicationId before async lookup" — suggest AP-094 [new]

Applied fixes:
  - abc1234 — fix(medication): add error handling on getSchedule call
  - def5678 — fix(dose-card): use parseLocalDate instead of new Date()
```

#### Invocação 2 — Sincronizar findings com memória DEVFLOW

```
/devflow reviewing
```

DEVFLOW recebe o payload do check-review e executa R1–R5:

```
DEVFLOW reviewing — meus-remedios — 2026-04-08

Goal
  Sync PR #183 review findings with memory

Assess
  Loaded: rules.json (all indexes), anti-patterns.json (all indexes),
          contracts.json, decisions.json
  Check-review sync payload: received (2 violations, 1 contract defended,
                              1 rule well-applied, 1 new AP proposal)

Execute
  [R2 — Violation Scan]
  R-034 violation confirmed (MedicationService.ts:87) — error handling omitted
  AP-T01 triggered (DoseCard.tsx:23) — date parsing anti-pattern hit

  [R3 — Severity]
  R-034 violation: MEDIUM (rule omission, no incident yet, now fixed in PR)
  AP-T01 trigger: HIGH (known incident cost — off-by-one bugs in prod)

  [R4 — Memory Update]
  ✓ AP-T01 trigger_count: 7 → 8
  ✓ R-034: incident_count 0 → 1 (first confirmed violation)
  ✓ New AP-094 proposed: "Validate medicationId before async lookup"
    → Added to anti-patterns.json (status: "proposed")
    → Created anti-patterns_detail/AP-094.md
  ✓ R-107 positive signal: noted in journal (well-applied in this PR)
  ✓ Appended events.jsonl: {event: "review_complete", violations: ["R-034","AP-T01"],
                             compliant: ["R-107"], new_ap_proposals: ["AP-094"]}
  ✓ Journal entry written: 2026-W15.jsonl

Record
  Rules:         R-034 incident_count updated (0→1)
  Anti-Patterns: AP-T01 trigger_count updated (7→8); AP-094 proposed
  ADRs:          none
  Contracts:     CON-004 defended (no update needed)
  Journal:       entry written to 2026-W15.jsonl

Goal Alignment
  Criteria met:  memory sync complete, all violations accounted for
  Drift:         none

Next Session
  Distillation needed: no (8/10 entries — 2 away from threshold)
  Pending human approvals: AP-094 (proposed — needs validation before promoting)
```

---

### Anti-patterns de invocação (Fluxo 2)

| Anti-Pattern | Consequência | Correto |
|-------------|-------------|---------|
| Rodar `/devflow reviewing` sem `/check-review` antes | R2 faz scan manual sem os findings estruturados do AI reviewer — trabalho duplicado e incompleto | Sempre check-review primeiro |
| Rodar `/check-review` e encerrar sem `/devflow reviewing` | trigger_counts ficam defasados — memória não aprende com o PR | Sempre sincronizar com DEVFLOW reviewing depois |
| Rodar `/devflow reviewing` sem o sync payload do check-review | DEVFLOW faz scan genérico sem o mapeamento AP/R-NNN pré-feito — perde a riqueza do cruzamento | Passar o payload explicitamente na invocação |
| Rodar ambos mas em sessões separadas sem referência ao PR | DEVFLOW não sabe qual PR está revisando — scan sem escopo | Incluir `PR #NNN` na invocação do reviewing |

---

## Quick Reference — Fluxo Completo por Ciclo

### Ciclo de Entrega

```
1.  /devflow coding "feat: <goal>"
      → Bootstrap completo (Phase 0 + C1 + C2)
      → Se C2 bloquear: resolver ADR antes de continuar

2.  /deliver-sprint
      → Detecta DEVFLOW_ACTIVE=true
      → Steps 0.5 → 1 → 2 → 3 → 4.1 (sem .memory/) → 5 → 6 → 7.3
      → Emite C5 signal ao encerrar

3.  [DEVFLOW C5 — automático após Step 7.3]
      → Atualiza rules.json, anti-patterns.json, contracts.json
      → Journal + events.jsonl + state.json
      → Checa distillation threshold
```

### Ciclo de Review

```
4.  [PR aberto + AI reviewer comentou — aguardar 2-5 min]

5.  /check-review
      → Steps 1–7: fetch → classify (com cross-check DEVFLOW) → fix → reply → approval gate
      → Step 8: gera DEVFLOW Sync payload

6.  /devflow reviewing [com payload do Step 8]
      → R1–R5: scan → severity → memory update → journal
      → trigger_counts atualizados, novos APs propostos
```

### Quando disparar Distillation

```
7.  Se state.json: journal_entries_since_distillation >= 10:
      /devflow distill
        → Comprime journal, revisa lifecycle de regras, promove candidatos ao global base
```

---

## Regras de Ouro

1. **DEVFLOW abre toda sessão** — nenhum código sem Bootstrap
2. **deliver-sprint é o executor, DEVFLOW é o contexto** — nunca trocar os papéis
3. **check-review é o mecânico do PR, DEVFLOW é a memória do time** — sem sync, o aprendizado se perde
4. **C5 nunca é opcional** — sessão sem Record é sessão que consumiu sem contribuir
5. **O payload do Step 8 é o contrato entre check-review e DEVFLOW** — formalize-o sempre, mesmo que curto

---

*Última atualização: 2026-04-08*
*Aplicável a: meus-remedios e qualquer projeto com .agent/ inicializado via setup.sh*
