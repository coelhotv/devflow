# DEVFLOW — Project Context for Claude Code

> **Status: Phase 0 complete. Ready for migration-status.json + GitHub remote + Wave 0.**

## What this repo is

DEVFLOW is a Claude Code skill for autonomous software development agents. It provides persistent memory, goal alignment, contract-aware coding, and continuous learning — using the filesystem as the orchestrator (no central coordinator needed).

Skill invocation: `/devflow [mode] "[goal]"`

Full architecture: see `master_plan_devflow.md` (comprehensive) or `README.md` (quick reference).

---

## Current Status (as of 2026-04-07)

### Phase 0 — DEVFLOW Repo: COMPLETE ✓

All core files created in this session:

| File | Status |
|------|--------|
| `DEVFLOW.md` | ✓ Complete skill template (English) |
| `README.md` | ✓ Full documentation |
| `templates/state.json` | ✓ With `{{PLACEHOLDERS}}` |
| `templates/genes.json` | ✓ Default gene values |
| `templates/rules.json` | ✓ Empty array `[]` |
| `templates/schema-reference.md` | ✓ Full schema docs |
| `scripts/setup.sh` | ✓ Automated project setup |
| `specs/WAVE_0_SCAFFOLDING.md` | ✓ |
| `specs/WAVE_1A_RULES_1-50.md` | ✓ Full spec |
| `specs/WAVE_1B_RULES_51-100.md` | ✓ |
| `specs/WAVE_1C_RULES_101-156.md` | ✓ |
| `specs/WAVE_2A_AP_CODE.md` | ✓ Full spec |
| `specs/WAVE_2B_AP_PERF.md` | ✓ |
| `specs/WAVE_2C_AP_UX.md` | ✓ |
| `specs/WAVE_2D_AP_OTHER.md` | ✓ |
| `specs/WAVE_3_KNOWLEDGE.md` | ✓ |
| `specs/WAVE_4_ADR_MINING.md` | ✓ Full spec (incl. PR mining) |
| `specs/WAVE_5_CONTRACTS.md` | ✓ |
| `specs/WAVE_6_EXPORT_GLOBAL.md` | ✓ |
| `specs/WAVE_7_VALIDATION.md` | ✓ |

### Immediate Next Steps

1. **Create `migration-status.json`** — wave progress tracker (see format below)
2. **Create GitHub remote** — `gh repo create coelhotv/devflow --public` + push
3. **Run Wave 0** — `bash scripts/setup.sh ~/git/meus-remedios "meus-remedios" "react,vite,supabase,typescript,node,telegram"` (open meus-remedios in VS Code for this)

---

## Key Architectural Decisions

These were settled in the design session — do not re-debate:

| Decision | Choice |
|----------|--------|
| Memory format | JSON indexes (always loaded) + Markdown detail on-demand |
| Loading strategy | Index-first → filter by tags/applies_to → load relevant `_detail/*.md` |
| Session loop | **Assess → Execute → Record** (ReAct adapted, no PKM vocabulary) |
| Orchestrator | None — filesystem IS the orchestrator |
| Lock strategy | Optimistic lock via `sessions/.lock`; append-only files need no lock |
| Language | **English only** — all DEVFLOW files, templates, specs, generated artifacts |
| Skill integrations | `/deliver-sprint` (DEVFLOW wraps it); `/check-review` (DEVFLOW reviewing syncs findings) |
| ADR archaeology | Mine merged PRs via `gh pr list --state merged --limit 200` |
| Repo location | `/Users/coelhotv/SKILLS/devflow` — dedicated repo |

---

## migration-status.json Format

Create at repo root: `/Users/coelhotv/SKILLS/devflow/migration-status.json`

```json
{
  "project": "meus-remedios",
  "last_updated": "2026-04-07",
  "waves": {
    "wave_0": { "status": "pending", "started": null, "completed": null, "notes": "" },
    "wave_1a": { "status": "pending", "started": null, "completed": null, "rules_done": 0, "rules_total": 50 },
    "wave_1b": { "status": "pending", "started": null, "completed": null, "rules_done": 0, "rules_total": 50 },
    "wave_1c": { "status": "pending", "started": null, "completed": null, "rules_done": 0, "rules_total": 56 },
    "wave_2a": { "status": "pending", "started": null, "completed": null, "aps_done": 0, "aps_total": 4 },
    "wave_2b": { "status": "pending", "started": null, "completed": null, "aps_done": 0, "aps_total": 21 },
    "wave_2c": { "status": "pending", "started": null, "completed": null, "aps_done": 0, "aps_total": 23 },
    "wave_2d": { "status": "pending", "started": null, "completed": null, "aps_done": 0, "aps_total": 7 },
    "wave_3": { "status": "pending", "started": null, "completed": null, "facts_done": 0 },
    "wave_4": { "status": "pending", "started": null, "completed": null, "prs_mined": false, "adrs_done": 0 },
    "wave_5": { "status": "pending", "started": null, "completed": null, "contracts_done": 0 },
    "wave_6": { "status": "pending", "started": null, "completed": null, "items_exported": 0 },
    "wave_7": { "status": "pending", "started": null, "completed": null }
  }
}
```

---

## Meus-Remedios Source Files for Migration

| Wave | Source files |
|------|-------------|
| 1 (Rules) | `meus-remedios/.memory/rules.md` |
| 2 (APs) | `meus-remedios/.memory/anti-patterns.md` |
| 3 (Knowledge) | `meus-remedios/.memory/knowledge.md` |
| 4 (ADRs) | `meus-remedios/CLAUDE.md`, `.memory/journal/`, `gh pr list --state merged --limit 200` |
| 5 (Contracts) | `meus-remedios/docs/reference/SERVICES.md`, `HOOKS.md`, `SCHEMAS.md`, `src/shared/` |

Project paths:
- Local: `/Users/coelhotv/Library/Mobile Documents/com~apple~CloudDocs/git/meus-remedios`
- Also: `/Users/coelhotv/git-icloud/meus-remedios`

---

## Wave Execution Protocol

Each wave is a self-contained session. At start:
1. Read `migration-status.json` → find current wave and progress
2. Read the wave spec from `specs/WAVE_*.md`
3. Verify current file state (don't trust status alone)
4. Resume from last processed entry

At end:
1. Update `migration-status.json` with real progress
2. Commit: `git commit -m "feat(wave-Nx): description"`
3. Push to GitHub

---

## File Reference

- `DEVFLOW.md` — the skill itself (copy this to `.agent/DEVFLOW.md` in each project)
- `README.md` — user-facing docs
- `master_plan_devflow.md` — full architecture plan (created in the design session)
- `templates/` — files for `scripts/setup.sh` to copy into new projects
- `scripts/setup.sh` — run this to bootstrap `.agent/` in any project
- `specs/` — one spec per migration wave
- `migration-status.json` — wave progress tracker (create this next)
