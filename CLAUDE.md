# DEVFLOW — Claude Code Context

> **Status: v1.0 — Production ready. meus-remedios migration complete (all 7 waves).**

## What this repo is

DEVFLOW is a Claude Code skill for autonomous software development agents. It provides persistent memory, goal alignment, contract-aware coding, and continuous learning — using the filesystem as the orchestrator.

```
/devflow [mode] "[goal]"
```

**Modes:** `planning` | `coding` | `reviewing` | `distillation`

Full architecture: `master_plan_devflow.md` | Quick reference: `README.md`

---

## Repo Structure

```
SKILLS/devflow/
├── DEVFLOW.md              ← The skill (symlinked into each project's .agent/)
├── README.md               ← User-facing docs
├── master_plan_devflow.md  ← Full architecture (read before major changes)
├── migration-status.json   ← Cross-project migration progress tracker
├── scripts/
│   └── setup.sh            ← Bootstrap .agent/ in any project
├── templates/
│   ├── state.json          ← Template for new projects
│   ├── genes.json          ← Default evolution genes
│   ├── rules.json          ← Empty index template
│   ├── anti-patterns.json  ← Empty index template
│   ├── decisions.json      ← Empty index template
│   ├── contracts.json      ← Empty index template
│   ├── knowledge.json      ← Empty index template
│   ├── schema-reference.md ← All format specs
│   └── examples/           ← Canonical detail file examples
│       ├── ADR-EXAMPLE.md
│       ├── CON-EXAMPLE.md
│       ├── AP-EXAMPLE.md
│       └── K-EXAMPLE.md
└── migration-guide/        ← Wave specs for onboarding existing projects
    ├── WAVE_0_SCAFFOLDING.md
    ├── WAVE_1A_RULES_1-50.md
    └── ... (through WAVE_7)
```

---

## Key Architectural Decisions

| Decision | Choice |
|----------|--------|
| Memory format | JSON indexes (always loaded) + Markdown detail on-demand |
| Loading strategy | Index-first → filter by tags/applies_to → load relevant `_detail/*.md` |
| Session loop | **Assess → Execute → Record** |
| Orchestrator | None — filesystem IS the orchestrator |
| Lock strategy | Optimistic lock via `sessions/.lock`; append-only files need no lock |
| Language | **English only** — all DEVFLOW files and generated artifacts |
| DEVFLOW.md in projects | **Symlink** to this repo's DEVFLOW.md — never copy |
| Skill integrations | `/deliver-sprint` (DEVFLOW wraps it); `/check-review` (DEVFLOW syncs findings) |

---

## Setting Up a New Project

```bash
bash /Users/coelhotv/SKILLS/devflow/scripts/setup.sh <project-path> <project-name> <stack-csv>
```

What `setup.sh` does:
1. Creates full `.agent/` directory tree
2. **Symlinks** `DEVFLOW.md` (not copied — always stays current)
3. Initializes `state.json`, `genes.json`, empty indexes
4. Imports 69 GR-NNN rules + 64 GAP-NNN anti-patterns from `~/.devflow/global_base/`
5. Updates `.gitignore` (excludes symlink + runtime files)

---

## Migrating an Existing Project

Use the wave-based migration guide in `migration-guide/`. Waves are independent and deliver value individually:

| Wave | What it migrates | Effort |
|------|-----------------|--------|
| 0 | Scaffolding | 15 min |
| 1 | Rules → rules.json + rules_detail/ | 2-3h |
| 2 | Anti-patterns → anti-patterns.json + detail/ | 2-3h |
| 3 | Knowledge → knowledge.json | 1h |
| 4 | ADR archaeology + journal migration | 4-5h |
| 5 | Contracts from SERVICES.md/HOOKS.md | 2h |
| 6 | Export universal knowledge to ~/.devflow/ | 1h |
| 7 | Validation | 1h |

Track progress in `migration-status.json`.

---

## Global Base (`~/.devflow/global_base/`)

Universal rules and anti-patterns shared across all projects:
- `universal_rules.json` — 69 GR-NNN rules (from meus-remedios, stack-universal)
- `universal_anti_patterns.json` — 64 GAP-NNN patterns
- Detail files in `rules_detail/` and `anti_patterns_detail/`

Every new project bootstrapped with `setup.sh` auto-imports the global base.

---

## Migrated Projects

| Project | Status | Rules | APs | ADRs | Contracts | Knowledge |
|---------|--------|-------|-----|------|-----------|-----------|
| meus-remedios | ✓ Complete | 106 | 93 | 25 | 16 | 70 facts |

---

## Adding Another Project

1. Run `setup.sh` on the new project
2. Populate `knowledge.json` with stack-specific facts
3. Run through migration waves if it's an existing project with existing memory
4. After maturing, run Wave 6 to export new universal patterns to `~/.devflow/global_base/`
