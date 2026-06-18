# DEVFLOW — Autonomous Software Development Agent

> **The filesystem is the orchestrator.**
>
> **Status: v2.1 — Goal-shaped delivery (Proof Obligations), spec-first workflow, Markdown memory, constitution-aware bootstrap, index-first loading.**

DEVFLOW is a skill for autonomous AI agents working on long-term software projects. It provides persistent memory, goal alignment, numbered feature specs, durable task plans, contract-aware coding, and continuous learning without requiring a central orchestrator.

Each session reads project state from files, acts, and records outcomes back to disk. The next session finds a richer codebase and richer knowledge base.

**Canonical skill file:** `SKILL.md` is the source of truth. `DEVFLOW.md` is a symlink to `SKILL.md` for compatibility with existing project setups.

---

## Core Concepts

| Concept | What it means |
|---------|--------------|
| **Assess → Execute → Record** | Every session follows this loop. Record is mandatory; a session that skips it consumed knowledge without contributing. |
| **Spec-first delivery** | New feature work can start with `/devflow specifying`, producing `plans/specs/NNN-feature-name/spec.md` before technical planning. |
| **Goal-shaped / Proof Obligations** | Every acceptance criterion (Tier 1+) carries a `po` block making it verifiable-by-transcript (`proof`/`expect`/`guard`). C4 closes each PO by pasting evidence; RC5 audits demonstrated-vs-affirmed. Stops weak/cheap models from declaring "done" prematurely. Provider-agnostic distillation of the `/goal` concept. |
| **Index-first memory** | Rules, ADRs, contracts, anti-patterns, and knowledge are stored as Markdown by category. Index files provide fast lookup; detail files load on demand. |
| **Constitution-aware bootstrap** | If `.agent/constitution.md` exists, DEVFLOW loads it before memory indexes and treats conflicts as critical. |
| **Filesystem as orchestrator** | Agents coordinate through `.agent/`, `plans/specs/`, events, journal entries, locks, and durable task files. |
| **Contract gateway** | Breaking an interface contract requires an accepted ADR before proceeding. Hard gate, not suggestion. |
| **Artifact coverage analysis** | Coding mode runs C1.5 to check `spec.md > plan.md > tasks.md > contracts` before implementation. |
| **Meta-evolution** | The agent may propose behavior changes, but human approval is required before applying them. |

---

## Quick Start

### New project

```bash
bash /path/to/devflow/scripts/setup.sh ./my-project "my-project" "react,typescript,supabase"
```

This creates a `.agent/` structure with Markdown memory indexes, detail folders, state, genes, sessions, and synthesis files.

### Existing project

See [templates/README.md](templates/README.md) for onboarding rules, ADRs, contracts, anti-patterns, and knowledge.

For spec-first work, create or use:

```text
plans/specs/NNN-feature-name/
```

---

## Invocation

DEVFLOW modes:

```text
/devflow specifying "describe user-facing need"
/devflow planning "design implementation for current spec"
/devflow coding "implement current plan"
/devflow reviewing "PR #42"
/devflow distill
/devflow status
/devflow status --health
/devflow export
```

Mode control is strict:

- Bootstrap -> STOP
- Specifying -> STOP
- Planning -> STOP
- Coding C2 -> STOP
- Coding C5 -> STOP
- Reviewing -> STOP
- Distillation -> STOP

If your project uses `/deliver-sprint`, DEVFLOW wraps it:

- **Before** `/deliver-sprint`: DEVFLOW Bootstrap + C1/C1.5 + C2 Contract Gateway
- **During** `/deliver-sprint`: DEVFLOW rules/AP/contract constraints
- **After** `/deliver-sprint`: DEVFLOW C5 Post-Code Record

If your project uses `/check-review`, run it first, then sync findings with DEVFLOW:

- `/check-review` -> technical code review
- `/devflow reviewing` -> memory sync, rule lifecycle, new AP proposals

---

## Repository Structure

```text
devflow/
  SKILL.md                         ← canonical skill definition
  DEVFLOW.md                       ← symlink to SKILL.md
  README.md                        ← this file
  CLAUDE.md                        ← repository-local instructions
  DEVFLOW-META.md                  ← meta-evolution protocol

  references/
    DEVFLOW-REFERENCE.md           ← file map, genes, state machine
    *.md                           ← additional reference material

  plans/
    EXEC_SPEC_DEVFLOW_UPGRADE_PLAN.md
    EXEC_SPEC_DOSIQ_PLAN_MIGRATION_TO_DEVFLOW_V18.md

  templates/
    README.md
    state.json
    genes.json
    schema-reference.md
    examples/
      RULE_TEMPLATE.md
      ADR_TEMPLATE.md
      ANTI_PATTERN_TEMPLATE.md
      CONTRACT_TEMPLATE.md
      KNOWLEDGE_TEMPLATE.md

  scripts/
    setup.sh
```

---

## Project Structure (v1.8)

Each project using DEVFLOW gets a `.agent/` folder:

```text
.agent/
  DEVFLOW.md                       ← symlink to shared skill, where used
  state.json                       ← session state
  constitution.md                  ← optional project principles and constraints

  memory/
    RULES_INDEX.md
    ANTI_PATTERNS_INDEX.md
    DECISIONS_INDEX.md
    CONTRACTS_INDEX.md
    KNOWLEDGE_INDEX.md
    rules/<category>/R-NNN.md
    anti-patterns/<category>/AP-NNN.md
    decisions/<category>/ADR-NNN.md
    contracts/<category>/CON-NNN.md
    knowledge/<category>/K-NNN.md
    journal/YYYY-WWW.jsonl
    journal/archive/

  evolution/
    genes.json
    evolution_log.jsonl

  sessions/
    .lock                          ← optimistic write lock, not versioned
    events.jsonl                   ← append-only session events, not versioned

  synthesis/
    pending_export.json
```

Spec-first feature work lives outside `.agent/`:

```text
plans/
  specs/
    NNN-feature-name/
      spec.md                      ← WHAT/WHY, user stories, FRs, SCs
      plan.md                      ← technical plan and clarifications
      tasks.md                     ← durable task list mirrored into TodoWrite
      analysis.md                  ← C1.5 artifact coverage analysis
      checklists/
        requirements.md            ← requirements quality checklist
      contracts/
        *.md                       ← feature-local contracts, if needed
```

**Versioned:** `.agent/memory/`, `.agent/evolution/`, `.agent/synthesis/`, `.agent/constitution.md`, `.agent/state.json`, `plans/specs/`.

**Not versioned:** `.agent/sessions/.lock`, `.agent/sessions/events.jsonl`.

---

## Modes

| Mode | Command | Purpose |
|------|---------|---------|
| Specifying | `/devflow specifying "goal"` | Create numbered `plans/specs/NNN-feature-name/spec.md` focused on WHAT/WHY |
| Planning | `/devflow planning "goal"` | Clarify requirements, create plan/tasks, check ADR needs |
| Coding | `/devflow coding "task"` | Analyze artifacts, pass contract gateway, implement with memory constraints |
| Reviewing | `/devflow reviewing "PR #N"` | Analyze changes against rules/contracts/ADRs and sync memory |
| Distillation | `/devflow distill` | Compress journal, lifecycle review, reconcile indexes/counters |
| Status | `/devflow status` | Current state dashboard |
| Export | `/devflow export` | Promote reusable knowledge to global base |

---

## Memory Categories

| Category | Use for |
|----------|---------|
| **data_and_schema** | Database, schemas, APIs, data validation |
| **infra_and_deploy** | Infrastructure, CI/CD, deployments, environment |
| **mobile_and_platform** | Mobile-specific code, native platform behavior |
| **react_and_ui** | React components, hooks, UI patterns |
| **process_and_testing** | Testing, QA, delivery processes |

Projects may add categories when their `.agent/memory/*_INDEX.md` files and detail paths stay consistent.

---

## Memory Item Types

| Type | ID | Location | Index |
|------|----|----------|-------|
| Rule | `R-NNN` | `.agent/memory/rules/<category>/R-NNN.md` | `RULES_INDEX.md` |
| ADR | `ADR-NNN` | `.agent/memory/decisions/<category>/ADR-NNN.md` | `DECISIONS_INDEX.md` |
| Anti-pattern | `AP-NNN` | `.agent/memory/anti-patterns/<category>/AP-NNN.md` | `ANTI_PATTERNS_INDEX.md` |
| Contract | `CON-NNN` | `.agent/memory/contracts/<category>/CON-NNN.md` | `CONTRACTS_INDEX.md` |
| Knowledge | `K-NNN` | `.agent/memory/knowledge/<category>/K-NNN.md` | `KNOWLEDGE_INDEX.md` |

Each detail file uses YAML frontmatter plus Markdown body. See [templates/schema-reference.md](templates/schema-reference.md).

---

## Global Knowledge Base

DEVFLOW can maintain a shared knowledge base at `~/.devflow/global_base/`:

```text
~/.devflow/global_base/
  universal_rules.json
  universal_anti_patterns.json
  rules/
  anti-patterns/
```

New projects can import universal patterns. Mature projects can run `/devflow export` to promote general rules/APs for reuse.

---

## Language

DEVFLOW protocol files are in **English** for model compatibility.

Project domain content, UI copy, changelogs, and product docs may use the project's native language.

---

## How to Add Memory Items

1. Copy a template from `templates/examples/`.
2. Rename it to match the type ID (`R-NNN`, `ADR-NNN`, `AP-NNN`, `CON-NNN`, `K-NNN`).
3. Place it in the correct category subdirectory.
4. Fill required YAML frontmatter.
5. Update the relevant `*_INDEX.md`.
6. Use the lock protocol before editing shared index files.

See [templates/README.md](templates/README.md) for examples.

---

## License

MIT — use freely, contribute back if you improve it.
