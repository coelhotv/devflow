# Wave 0 — Scaffolding: .agent/ Structure for meus-remedios

**Status:** pending
**Project:** meus-remedios
**Estimated effort:** 30-45 min (1 session)
**Prerequisites:** DEVFLOW.md written (Phase 0 complete)

## Goal

Create the full `.agent/` directory tree with all empty/initialized files.
No content migration yet — just structure.

## Resume Protocol

At session start:
1. Read `migration-status.json` → check wave_0.status
2. Verify `.agent/` exists: `ls meus-remedios/.agent/` 
3. If partially done, check which subdirectories exist and continue from there

## Steps

### 1. Run setup.sh

```bash
bash /Users/coelhotv/SKILLS/devflow/scripts/setup.sh \
  "/Users/coelhotv/Library/Mobile Documents/com~apple~CloudDocs/git/meus-remedios" \
  "meus-remedios" \
  "react,vite,supabase,typescript,vitest,framer-motion,telegram"
```

### 2. Verify structure

```bash
find meus-remedios/.agent -type f | sort
```

Expected output: 8 files minimum (DEVFLOW.md, state.json, 5 index JSONs, genes.json, evolution_log.jsonl, events.jsonl, pending_export.json)

### 3. Add note to CLAUDE.md

At the top of `meus-remedios/CLAUDE.md`, add:
```
> This project uses DEVFLOW. Primary agent context: `.agent/DEVFLOW.md`
> Legacy memory files in `.memory/` remain authoritative during migration.
```

### 4. Test /devflow status

Run `/devflow status` — should output:
- Project: meus-remedios
- Rules: 0 (will be populated in Wave 1)
- All other counts: 0
- No errors reading any file

## Completion Criteria

- [ ] `meus-remedios/.agent/` exists with full directory tree
- [ ] `state.json` has correct project metadata
- [ ] `/devflow status` returns valid output with zero counts
- [ ] CLAUDE.md has DEVFLOW reference at top
- [ ] `migration-status.json` updated: wave_0.status = "completed"

## Commit

```
git commit -m "feat(devflow): initialize .agent/ scaffolding for meus-remedios

- Created full .agent/ directory structure
- Initialized state.json, genes.json, all index files
- Added DEVFLOW.md reference to CLAUDE.md"
```
