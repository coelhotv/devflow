# Wave 1c — Rules Migration

**Status:** pending
**Project:** meus-remedios
**Source:** `meus-remedios/.memory/rules.md` ( R-101 to R-156)
**Estimated effort:** 2-3h (1-2 sessions)
**Prerequisites:** Previous wave complete

## Goal

Convert  R-101 to R-156 from monolithic `rules.md` to index + detail files.
Scope: R-101 through R-156

## Resume Protocol

1. Read `migration-status.json` → check Performance, design, UI/UX rules.rules_done
2. Run: `python3 -c "import json; print(len(json.load(open('meus-remedios/.agent/memory/rules.json'))),'rules done')`
3. Resume from next rule after last migrated

## Process

Follow identical process as Wave 1a (see WAVE_1A_RULES_1-50.md for full details).

## Completion Criteria

- [ ] `rules.json` has all entries through this wave's range
- [ ] `rules_detail/` has one file per rule in this range
- [ ] JSON valid
- [ ] state.json rules_count updated
- [ ] `migration-status.json` updated: Performance, design, UI/UX rules.status = "completed"

## Commit

```
git commit -m "feat(devflow/Performance, design, UI/UX rules): migrate  R-101 to R-156 to rules.json + detail files"
```
