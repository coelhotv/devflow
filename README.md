# DEVFLOW — Autonomous Software Development Agent

> **The filesystem is the orchestrator.**
>
> **Status: v1.0 — Production ready. meus-remedios migration complete (all 7 waves).**

DEVFLOW is a skill for autonomous AI agents working on long-term software projects. It provides persistent memory, goal alignment, contract-aware coding, and continuous learning — without requiring a formal orchestrator.

Each agent session reads project state from files, acts, and deposits learnings back. The next session finds a richer state. Knowledge compounds over time.

**Auto-load via symlink:** Agents automatically load DEVFLOW skill through `SKILL.md` symlink to `DEVFLOW.md`.

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
  DEVFLOW.md              ← The skill itself (symlinked to .agent/DEVFLOW.md in each project)
  SKILL.md                ← Symlink to DEVFLOW.md (auto-loads skill for agents)
  README.md               ← This file
  CLAUDE.md               ← Project instructions (v1.0 status, architecture decisions)
  master_plan_devflow.md  ← Full architectural specification

  templates/
    state.json            ← state.json template with placeholders
    genes.json            ← default evolution genes
    rules.json            ← empty index template
    anti-patterns.json    ← empty index template
    decisions.json        ← empty index template
    contracts.json        ← empty index template
    knowledge.json        ← empty index template
    schema-reference.md   ← Full schema docs for all index and detail files
    examples/
      R-EXAMPLE.md, AP-EXAMPLE.md, ADR-EXAMPLE.md, CON-EXAMPLE.md, K-EXAMPLE.md

  scripts/
    setup.sh              ← Bootstrap .agent/ in any new project (auto-imports global base)

  migration-guide/
    WAVE_0_SCAFFOLDING.md      ← Scaffolding (.agent/ structure)
    WAVE_1A_RULES_1-50.md      ← Rule 1-50 → rules.json
    WAVE_1B_RULES_51-100.md    ← Rule 51-100 → rules.json
    WAVE_1C_RULES_101-156.md   ← Rule 101-156 → rules.json
    WAVE_2A_AP_CODE.md         ← Anti-patterns (code) → anti-patterns.json
    WAVE_2B_AP_PERF.md         ← Anti-patterns (performance)
    WAVE_2C_AP_UX.md           ← Anti-patterns (UX)
    WAVE_2D_AP_OTHER.md        ← Anti-patterns (other)
    WAVE_3_KNOWLEDGE.md        ← Domain facts → knowledge.json
    WAVE_4_ADR_MINING.md       ← ADR archaeology → decisions.json
    WAVE_5_CONTRACTS.md        ← Interface contracts → contracts.json
    WAVE_6_EXPORT_GLOBAL.md    ← Export universal knowledge to ~/.devflow/
    WAVE_7_VALIDATION.md       ← Validation & completion
  
  migration-status.json   ← Progress tracker (meus-remedios: ✓ complete)
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

## Global Knowledge Base (Established)

DEVFLOW maintains a shared knowledge base at `~/.devflow/global_base/`:

```
~/.devflow/global_base/
  universal_rules.json         ← GR-NNN (69 stack-agnostic rules from meus-remedios)
  universal_anti_patterns.json ← GAP-NNN (64 stack-agnostic anti-patterns)
  rules_detail/GR-NNN.md
  anti-patterns_detail/GAP-NNN.md
  index.json                   ← project registry
```

**Bootstrap:** New projects created with `setup.sh` automatically import these 69+64 universal rules and anti-patterns, accelerating knowledge transfer across projects.

**Export:** After a project matures, run `/devflow export` to promote project-specific patterns to the global base for reuse across all future projects.

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

## Project Status & Deliverables

### meus-remedios Migration — Complete ✓

| Component | Status | Count |
|-----------|--------|-------|
| Rules | ✓ Complete | 106 rules (37 local + 69 global GR-NNN) |
| Anti-patterns | ✓ Complete | 93 patterns (29 local + 64 global GAP-NNN) |
| Decisions (ADRs) | ✓ Complete | 25 architectural decisions |
| Contracts | ✓ Complete | 16 interface contracts |
| Knowledge | ✓ Complete | 70 domain facts |
| Global Base | ✓ Exported | 69 universal rules + 64 universal APs |

### Recent Deliverables

- **Wave 7 (Validation)** — Full migration validation complete, zero gaps
- **Wave 6 (Export)** — 69 universal rules + 64 anti-patterns exported to `~/.devflow/global_base/`
- **Post-migration Cleanup** — Templates standardized, CLAUDE.md established, SKILL.md symlink created
- **v1.0 Release** — Production-ready skill with index-first memory, contract gateway, meta-evolution

---

## License

MIT — use freely, contribute back if you improve it.
