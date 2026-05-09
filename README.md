# DEVFLOW — Autonomous Software Development Agent

> **The filesystem is the orchestrator.**
>
> **Status: v1.7 — Production ready. Markdown-based categorical memory. Index-first loading.**

DEVFLOW is a skill for autonomous AI agents working on long-term software projects. It provides persistent memory, goal alignment, contract-aware coding, and continuous learning — without requiring a formal orchestrator.

Each agent session reads project state from files, acts, and deposits learnings back. The next session finds a richer state. Knowledge compounds over time.

**Auto-load via symlink:** Agents automatically load DEVFLOW skill through `SKILL.md` symlink to `DEVFLOW.md`.

---

## Core Concepts

| Concept | What it means |
|---------|--------------|
| **Assess → Execute → Record** | Every session follows this loop. Record is mandatory — a session that skips it consumed knowledge without contributing. |
| **Index-first memory** | Rules, ADRs, contracts, anti-patterns, knowledge stored as Markdown by category. INDEX.md provides fast lookup. Details loaded on-demand. |
| **Categorical organization** | 5 categories: data_and_schema, infra_and_deploy, mobile_and_platform, react_and_ui, process_and_testing. Each memory type has full subcategory structure. |
| **Filesystem as orchestrator** | No central coordinator needed. Agents share state through `.agent/` files. Locking protocol handles concurrent sessions. |
| **Contract gateway** | Breaking an interface contract requires an ADR before proceeding. Hard gate, not a suggestion. |
| **Meta-evolution** | The agent proposes changes to its own behavior (genes). Human approval required before applying. |

---

## Quick Start

### New project

```bash
bash /path/to/devflow/scripts/setup.sh ./my-project "my-project" "react,typescript,supabase"
```

This creates the full `.agent/memory/` structure with 5 categories × 5 memory types + empty INDEX.md files.

### Existing project (manual onboarding)

See [templates/README.md](templates/README.md) for step-by-step guide to adding rules, ADRs, contracts, etc.

---

## Invocation

DEVFLOW is invoked as a Claude Code skill:

```
/devflow planning "design new authentication flow"
/devflow coding "implement OTP login"
/devflow reviewing "PR #42 OTP implementation"
/devflow distill
/devflow status
/devflow status --health
/devflow export
```

If your project uses `/deliver-sprint`, DEVFLOW wraps it:
- **Before** `/deliver-sprint`: DEVFLOW Bootstrap + Contract Gateway
- **During** `/deliver-sprint`: DEVFLOW rules/AP constraints
- **After** `/deliver-sprint`: DEVFLOW Post-Code Record phase

If your project uses `/check-review`, run it first, then sync findings with DEVFLOW:
- `/check-review` → technical code review
- `/devflow reviewing` → memory sync (rule lifecycle, new AP proposals)

---

## Repository Structure

```
devflow/
  DEVFLOW.md              ← The skill itself (symlinked to .agent/DEVFLOW.md in each project)
  SKILL.md                ← Symlink to DEVFLOW.md
  README.md               ← This file
  CLAUDE.md               ← Project instructions
  master_plan_devflow.md  ← Full architectural specification

  templates/
    README.md             ← Guide to creating memory items
    state.json            ← state.json template
    genes.json            ← default evolution genes
    examples/
      RULE_TEMPLATE.md           ← Copy to rules/category/R-NNN.md
      ADR_TEMPLATE.md            ← Copy to decisions/category/ADR-NNN.md
      ANTI_PATTERN_TEMPLATE.md   ← Copy to anti-patterns/category/AP-NNN.md
      CONTRACT_TEMPLATE.md       ← Copy to contracts/category/CON-NNN.md
      KNOWLEDGE_TEMPLATE.md      ← Copy to knowledge/category/K-NNN.md

  scripts/
    setup.sh              ← Bootstrap .agent/ in any new project
```

---

## Project Memory Structure (v1.7)

Each project using DEVFLOW gets a `.agent/` folder:

```
.agent/
  DEVFLOW.md                       ← skill (symlink)
  state.json                       ← session state
  memory/
    rules/
      data_and_schema/R-NNN.md
      infra_and_deploy/R-NNN.md
      mobile_and_platform/R-NNN.md
      react_and_ui/R-NNN.md
      process_and_testing/R-NNN.md
      RULES_INDEX.md               ← auto-maintained
    anti-patterns/
      data_and_schema/AP-NNN.md
      infra_and_deploy/AP-NNN.md
      mobile_and_platform/AP-NNN.md
      react_and_ui/AP-NNN.md
      process_and_testing/AP-NNN.md
      ANTI_PATTERNS_INDEX.md
    decisions/
      data_and_schema/ADR-NNN.md
      infra_and_deploy/ADR-NNN.md
      mobile_and_platform/ADR-NNN.md
      react_and_ui/ADR-NNN.md
      process_and_testing/ADR-NNN.md
      DECISIONS_INDEX.md
    contracts/
      data_and_schema/CON-NNN.md
      infra_and_deploy/CON-NNN.md
      mobile_and_platform/CON-NNN.md
      react_and_ui/CON-NNN.md
      process_and_testing/CON-NNN.md
      CONTRACTS_INDEX.md
    knowledge/
      data_and_schema/K-NNN.md
      infra_and_deploy/K-NNN.md
      mobile_and_platform/K-NNN.md
      react_and_ui/K-NNN.md
      process_and_testing/K-NNN.md
      KNOWLEDGE_INDEX.md
    journal/YYYY-WWW.md            ← append-only session logs
    journal/archive/               ← distilled history
  evolution/
    genes.json                     ← behavior parameters
    evolution_log.jsonl            ← mutation history
  sessions/
    .lock                          ← optimistic write lock (not versioned)
    events.jsonl                   ← session events (not versioned)
  synthesis/
    pending_export.json            ← items ready for global base
```

**Versioned:** `memory/`, `evolution/`, `synthesis/`, `DEVFLOW.md`, `state.json`
**Not versioned:** `sessions/.lock`, `sessions/events.jsonl`

---

## Categories (5)

Organize memory items by category to keep them semantically grouped:

| Category | Use for |
|----------|---------|
| **data_and_schema** | Database, Zod schemas, APIs, data validation |
| **infra_and_deploy** | Infrastructure, CI/CD, deployments, environment |
| **mobile_and_platform** | Mobile-specific code, platform features |
| **react_and_ui** | React components, hooks, UI patterns |
| **process_and_testing** | Testing, QA, development processes |

---

## Memory Item Types (5)

### Rules (R-NNN)
Coding rules and constraints.
- **Template:** `templates/examples/RULE_TEMPLATE.md`
- **Location:** `memory/rules/[category]/R-NNN.md`
- **Index:** `memory/RULES_INDEX.md`

### Architecture Decision Records (ADR-NNN)
Significant decisions about design, architecture, infrastructure.
- **Template:** `templates/examples/ADR_TEMPLATE.md`
- **Location:** `memory/decisions/[category]/ADR-NNN.md`
- **Index:** `memory/DECISIONS_INDEX.md`

### Anti-Patterns (AP-NNN)
Patterns to avoid, often paired with rules.
- **Template:** `templates/examples/ANTI_PATTERN_TEMPLATE.md`
- **Location:** `memory/anti-patterns/[category]/AP-NNN.md`
- **Index:** `memory/ANTI_PATTERNS_INDEX.md`

### Contracts (CON-NNN)
Service contracts, API specs, interface definitions.
- **Template:** `templates/examples/CONTRACT_TEMPLATE.md`
- **Location:** `memory/contracts/[category]/CON-NNN.md`
- **Index:** `memory/CONTRACTS_INDEX.md`

### Knowledge (K-NNN)
Reusable facts, technical information, constants.
- **Template:** `templates/examples/KNOWLEDGE_TEMPLATE.md`
- **Location:** `memory/knowledge/[category]/K-NNN.md`
- **Index:** `memory/KNOWLEDGE_INDEX.md`

---

## Global Knowledge Base (Shared)

DEVFLOW maintains a shared knowledge base at `~/.devflow/global_base/`:

```
~/.devflow/global_base/
  universal_rules.json         ← GR-NNN (stack-agnostic rules)
  universal_anti_patterns.json ← GAP-NNN (stack-agnostic anti-patterns)
  rules/
    [category]/GR-NNN.md
  anti-patterns/
    [category]/GAP-NNN.md
```

**Bootstrap:** New projects created with `setup.sh` automatically import these universal patterns, accelerating knowledge transfer.

**Export:** After a project matures, run `/devflow export` to promote project-specific patterns to the global base for reuse.

---

## Modes

| Mode | Command | Purpose |
|------|---------|---------|
| Planning | `/devflow planning "goal"` | Design, spec, ADR creation |
| Coding | `/devflow coding "task"` | Implement with memory constraints |
| Reviewing | `/devflow reviewing "PR #N"` | Analyze against rules + sync memory |
| Distillation | `/devflow distill` | Compress journal, lifecycle review |
| Status | `/devflow status` | Current state dashboard |
| Export | `/devflow export` | Promote knowledge to global base |

---

## Language

All DEVFLOW files are in **English** — for LLM compatibility across model families and future open-source collaboration.

Project domain content (business logic, UI text) may remain in the project's native language.

---

## How to Add Memory Items

1. Copy the appropriate template from `templates/examples/`
2. Rename to match the type ID (R-NNN, ADR-NNN, AP-NNN, CON-NNN, K-NNN)
3. Place in correct category subdirectory under the memory type
4. Fill in all required YAML frontmatter fields
5. Update the relevant INDEX.md file

See [templates/README.md](templates/README.md) for detailed examples.

---

## License

MIT — use freely, contribute back if you improve it.
