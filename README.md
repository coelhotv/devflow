# DEVFLOW — Autonomous Software Development Agent

> **The filesystem is the orchestrator.**

DEVFLOW is a skill for autonomous AI agents working on long-term software projects. It provides persistent memory, goal alignment, contract-aware coding, and continuous learning — without requiring a formal orchestrator.

Each agent session reads project state from files, acts, and deposits learnings back. The next session finds a richer state. Knowledge compounds over time.

---

## Core Concepts

| Concept | What it means |
|---------|--------------|
| **Assess → Execute → Record** | Every session follows this loop. Record is mandatory — a session that skips it consumed knowledge without contributing. |
| **Index-first memory** | Rules and knowledge stored as compact JSON indexes. Detail files loaded on-demand only for relevant entries. ~320 lines of context vs. 800+ with monolithic markdown. |
| **Filesystem as orchestrator** | No central coordinator needed. Agents share state through `.agent/` files. Locking protocol handles concurrent sessions. |
| **Contract gateway** | Breaking an interface contract requires an ADR before proceeding. Hard gate, not a suggestion. |
| **Meta-evolution** | The agent proposes changes to its own behavior (genes). Human approval required before applying. |

---

## Quick Start

### New project

```bash
bash /path/to/devflow/scripts/setup.sh ./my-project "my-project" "react,typescript,supabase"
```

This creates the full `.agent/` structure and imports universal rules from `~/.devflow/global_base/` if available.

### Existing project (manual onboarding)

See [ONBOARDING.md](docs/ONBOARDING.md) for step-by-step migration of existing memory (rules.md, anti-patterns.md, etc.) to the DEVFLOW format.

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
  DEVFLOW.md              ← The skill itself (copy to .agent/ in each project)
  README.md               ← This file
  templates/
    state.json            ← state.json template with placeholders
    genes.json            ← default gene values
    rules.json            ← empty index array
    schema-reference.md   ← Full schema docs for all index and detail files
  scripts/
    setup.sh              ← Automated project setup
  specs/
    WAVE_0_SCAFFOLDING.md      ← meus-remedios migration Wave 0
    WAVE_1A_RULES_1-50.md      ← meus-remedios migration Wave 1a
    WAVE_1B_RULES_51-100.md    ← meus-remedios migration Wave 1b
    WAVE_1C_RULES_101-156.md   ← meus-remedios migration Wave 1c
    WAVE_2A_AP_CODE.md         ← meus-remedios migration Wave 2a
    WAVE_2B_AP_PERF.md         ← meus-remedios migration Wave 2b
    WAVE_2C_AP_UX.md           ← meus-remedios migration Wave 2c
    WAVE_2D_AP_OTHER.md        ← meus-remedios migration Wave 2d
    WAVE_3_KNOWLEDGE.md        ← meus-remedios migration Wave 3
    WAVE_4_ADR_MINING.md       ← meus-remedios migration Wave 4
    WAVE_5_CONTRACTS.md        ← meus-remedios migration Wave 5
    WAVE_6_EXPORT_GLOBAL.md    ← meus-remedios migration Wave 6
    WAVE_7_VALIDATION.md       ← meus-remedios migration Wave 7
  migration-status.json   ← Progress tracker for meus-remedios migration
```

---

## Project Memory Structure

Each project using DEVFLOW gets a `.agent/` folder:

```
.agent/
  DEVFLOW.md                    ← skill (copied from this repo)
  state.json                    ← session state
  memory/
    rules.json                  ← R-NNN index (compact, always loaded)
    anti-patterns.json          ← AP-NNN index (compact, always loaded)
    contracts.json              ← CON-NNN interface contracts
    decisions.json              ← ADR-NNN architectural decisions
    knowledge.json              ← domain facts
    rules_detail/R-NNN.md       ← loaded on-demand
    anti-patterns_detail/AP-NNN.md
    contracts_detail/CON-NNN.md
    decisions_detail/ADR-NNN.md
    journal/YYYY-WWW.jsonl      ← append-only sprint events
    journal/archive/            ← distilled history
  evolution/
    genes.json                  ← behavior parameters
    evolution_log.jsonl         ← mutation history
  sessions/
    .lock                       ← optimistic write lock (not versioned)
    events.jsonl                ← session events (not versioned)
  synthesis/
    pending_export.json         ← rules ready for global base
```

**Versioned:** `memory/`, `evolution/`, `synthesis/`, `DEVFLOW.md`, `state.json`
**Not versioned:** `sessions/.lock`, `sessions/events.jsonl`

---

## Global Knowledge Base

After your first project matures, export universal knowledge to `~/.devflow/`:

```bash
/devflow export
```

Future projects bootstrap with this global knowledge:

```
~/.devflow/
  global_base/
    universal_rules.json         ← GR-NNN (stack-agnostic rules)
    universal_anti_patterns.json ← GAP-NNN (stack-agnostic APs)
    rules_detail/GR-NNN.md
    anti-patterns_detail/GAP-NNN.md
    index.json                   ← project registry
```

---

## Modes

| Mode | Command | Purpose |
|------|---------|---------|
| Planning | `/devflow planning "goal"` | Design, spec, ADR creation |
| Coding | `/devflow coding "task"` | Implement with memory constraints |
| Reviewing | `/devflow reviewing "PR #N"` | Analyze against rules + sync memory |
| Distillation | `/devflow distill` | Compress journal, lifecycle review, export prep |
| Status | `/devflow status` | Current state dashboard |
| Export | `/devflow export` | Promote knowledge to global base |

---

## Language

All DEVFLOW files are in **English** — for LLM compatibility across model families and future open-source collaboration.

Project domain content (business logic, UI text) may remain in the project's native language.

---

## License

MIT — use freely, contribute back if you improve it.
