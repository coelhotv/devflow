---
name: devflow-plan
description: >-
  Desenha a solução antes de codar: análise de escopo, clarificação formal de requisitos, checagem de ADR, plan.md e tasks.md com PO ligada a cada tarefa. Invocada pelo operador (`/devflow-plan`). Não auto-invocar: escolher o modo é do operador, não do agente (R-065).
compatibility: Designed for Claude Code (or similar products)
---

# Modo Planning do DEVFLOW (P0–P4)

> ⚠️ **Ordem obrigatória.** Se você não leu o `.agent/state.json` nesta sessão, **invoque `/devflow` primeiro** — o núcleo carrega o bootstrap, o HARD STOP e a R-065. Esta skill é um modo do DEVFLOW, não um processo autônomo: ela **lê e escreve o `state.json`**, que é a única transição válida entre modos (contexto herdado não conta).

> Referências e scripts vivem na raiz do repositório da skill `devflow`:
> `~/SKILLS/devflow/references/` e `~/SKILLS/devflow/scripts/`.

<!-- devflow-split:plan:begin -->
## Mode: Planning

**Purpose:** Understand scope, design solution, create specs and ADRs.

### P0 — State Transition to Planning

**⚠️ MANDATORY FIRST STEP — DO NOT SKIP**

Upon entering Planning mode, **IMMEDIATELY** update state.json BEFORE proceeding to P1:

```json
{
  "session": {
    "mode": "planning",
    "status": "planning",
    "goal": "<goal title or description>",
    "goal_type": "<feature|fix|refactor|docs|chore>"
  }
}
```

Checklist: Read current state.json → update mode/status/goal/goal_type → write to disk → verify write → proceed to P1.

### P1 — Scope Analysis
```
If state.json has session.spec_dir:
  Read `spec.md` from that directory.
  Prepare to write `plan.md`, `tasks.md` and checklists there.
  `analysis.md` at Planning time is a SKELETON, not an authority: Planning has not touched the
  code yet, so it can only record what is already known and what is UNVERIFIED. Its header MUST
  say so. The binding Reality Check is the C1.5 of each coding session (`analysis-<slice>.md`).
  Writing `PASS` here is how a later slice inherits a verdict nobody computed for it.
Else:
  Read relevant legacy files in plans/ from session.spec or task context.

Read .agent/memory/DECISIONS_INDEX.md — filter for relevant ADRs (tags match goal).
Read .agent/memory/CONTRACTS_INDEX.md — identify interfaces in scope.
For relevant decisions and contracts: load their detail files.
```

### P1.5 — Formal Requirement Clarification
```
Before ADR check and technical planning, scan the active spec with this taxonomy:
  - Functional Scope & Behavior
  - Personas / User Roles
  - Domain & Data Model
  - Interaction & UX Flow
  - Non-Functional Requirements
  - Integration & External Dependencies
  - Edge Cases & Failure Handling
  - Constraints & Tradeoffs
  - Terminology & Consistency
  - Completion Signals

Ask at most 5 questions. Ask only when the answer materially changes
architecture, task breakdown, test design, UX behavior, contracts, or validation.
Do NOT ask what can be discovered from the repo.

Record each accepted answer in `plan.md` under:
  ## Clarifications
  - Q: <question> → A: <answer>

Create/update `checklists/requirements.md` in the spec directory when using the
v1.8 spec format. Checklist items are "unit tests for requirements writing":
they validate completeness, clarity, consistency, coverage, measurability, and
traceability. They do NOT test implementation behavior.
```

### P2 — ADR Check
```
For any significant architectural decision in scope:
  IF no ADR covers it → draft ADR-NNN in DECISIONS_INDEX.md (status: "proposed")
                      → create decisions/[category]/ADR-NNN.md with context and options
  IF ADR exists with status "accepted" → proceed
  IF ADR exists with status "proposed" → flag for human review before implementation
```

### P3 — Spec Creation (tier-aware)
```
Tier 1 (Standard): plan.md is OPTIONAL. If the approach is obvious from spec.md,
  skip plan.md and capture the design directly in the C2 gate (files, order, gates).
  Write plan.md only when a non-obvious design choice deserves a durable record.
  Do NOT create analysis.md / checklists/ for Tier 1 unless C1.5 surfaces a real risk.

Tier 2 (Epic): write the full technical plan to `plans/specs/NNN-feature-name/plan.md`:
  - Summary + Technical Context (cite REAL schema/code evidence: table cols, fn signatures,
    enum values — verified via find/grep/MCP, with file:line, NOT assumed)
  - Constitution Check
  - Architecture / Approach (incl. data-migration plan when a format/enum/schema changes)
  - Target Files table (canonical paths verified with find/grep; mark UNVERIFIED if not)
  - Contracts and ADRs
  - Risks + Quality Gates

For legacy workflows, write execution spec to plans/EXEC_SPEC_<GOAL>.md (scope, target files
verified, acceptance criteria, risk flags, gate commands).

Write `tasks.md` (both tiers). For a SLICED Tier 2 epic, group tasks under one heading per
slice, in the slice table's execution order, and state at the top of each group: the slice's
tier, the POs it closes, and what it depends on. A task belongs to exactly one slice.

Each task MUST:
  - Start with `- [ ] TNNN`
  - Use `[P]` only for independent parallel work
  - Use `[US1]`, `[US2]`, etc. when tied to a user story
  - Use `[C4]` for validation tasks
  - Use `[C5]` for record/memory/state tasks
  - Link the PO(s) it closes via `[PO-N]` (Tier 1+). A task with no linked PO has no
    end criterion — it is undone work. Plan the ORDER in which POs are demonstrated:
    which POs are checkpoints and when.
  - Cover every deliverable, acceptance criterion, quality gate, and C5 step
```

### P4 — State Update & Completion
```
Update .agent/state.json:
  session.goal = <goal title>
  session.goal_type = feature | fix | refactor | docs | chore
  session.status = "planned"
  session.plan = "plans/specs/NNN-feature-name/plan.md"       # if using v1.8 specs
  session.tasks = "plans/specs/NNN-feature-name/tasks.md"     # if using v1.8 specs

Append to .agent/sessions/events.jsonl:
  {"timestamp": "...", "event": "planning_complete", "spec": "plans/EXEC_SPEC_X.md"}

Write journal entry to .agent/memory/journal/YYYY-WWW.jsonl

Specs index sync: if a specs index/README exists, update the spec's status row
to `planned` in the SAME step (see S6 SPECS INDEX SYNC). Status transition without
index update = drift.
```

STOP. Awaiting Coding mode invocation.

---

<!-- devflow-split:plan:end -->
