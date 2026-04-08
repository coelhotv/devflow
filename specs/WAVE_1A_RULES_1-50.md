# Wave 1a — Rules Migration: R-001 to R-050

**Status:** pending
**Project:** meus-remedios
**Source:** `meus-remedios/.memory/rules.md` (R-001 to R-050)
**Estimated effort:** 2-3h (1-2 sessions)
**Prerequisites:** Wave 0 complete

## Goal

Convert R-001 through R-050 from monolithic `rules.md` to:
- One entry per rule in `.agent/memory/rules.json`
- One detail file per rule in `.agent/memory/rules_detail/R-NNN.md`

## Resume Protocol

At session start:
1. Read `migration-status.json` → check wave_1a.rules_done
2. Run: `cat meus-remedios/.agent/memory/rules.json | python3 -c "import json,sys; data=json.load(sys.stdin); print(len(data), 'rules done')`
3. Identify last rule migrated → resume from next one
4. Read `meus-remedios/.memory/rules.md` section for remaining rules

## Process Per Rule

For each R-NNN in R-001 to R-050:

1. Read the rule text from `.memory/rules.md`
2. Extract: id, title, 1-line summary, applies_to (guess from context), tags
3. Add entry to `rules.json` (append to array)
4. Create `rules_detail/R-NNN.md` with:
   - Full rationale (from original rule text)
   - Code examples if present
   - `**Related anti-pattern:**` line (AP-NNN if cross-reference exists)
   - `**Related ADR:**` line if applicable

## Tags Reference

Use these tags consistently:
- `file-management` — file/import handling
- `timezone` — date/time operations
- `zod` — schema validation
- `react` — React patterns
- `performance` — performance constraints
- `telegram` — Telegram bot
- `supabase` — database operations
- `design` — UI/UX
- `testing` — test patterns
- `git` — git workflow
- `infra` — serverless, infra
- `process` — workflow/process rules

## applies_to Reference

- `"all"` — applies to entire codebase
- `"js"` / `"ts"` — JavaScript/TypeScript
- `"react"` — React components
- `"supabase"` — Supabase interactions
- `"telegram"` — Telegram bot code
- `"vercel"` — Vercel/serverless
- `"zod"` — Zod schemas

## JSON Entry Format

```json
{
  "id": "R-001",
  "title": "Duplicate File Check",
  "summary": "Verify no duplicate file exists before modifying any file",
  "applies_to": ["all"],
  "tags": ["file-management", "safety"],
  "incident_count": 3,
  "last_referenced": null,
  "review_due": "2026-10-01",
  "status": "active",
  "has_detail": true
}
```

## Progress Tracking

Update `migration-status.json` after each batch of 10 rules:
```json
"wave_1a": { "status": "in_progress", "rules_done": 10, "rules_total": 50 }
```

## Completion Criteria

- [ ] `rules.json` has 50 entries (R-001 to R-050)
- [ ] `rules_detail/` has 50 files (one per rule)
- [ ] All entries have valid JSON (validate: `python3 -c "import json; json.load(open('.agent/memory/rules.json'))"`)
- [ ] state.json memory.rules_count updated to 50
- [ ] `migration-status.json` updated: wave_1a.status = "completed"

## Commit

```
git commit -m "feat(devflow/wave-1a): migrate R-001 to R-050 to rules.json + detail files

- 50 rules converted to index + on-demand detail format
- Includes file-management, React, timezone, Zod, data rules"
```
