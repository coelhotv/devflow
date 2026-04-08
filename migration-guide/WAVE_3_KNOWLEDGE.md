# Wave 3 — Knowledge Structuring: knowledge.md → knowledge.json

**Status:** pending
**Project:** meus-remedios
**Source:** `meus-remedios/.memory/knowledge.md`
**Estimated effort:** 1-2h (1 session)
**Prerequisites:** Wave 2d complete (all APs migrated)

## Goal

Convert `knowledge.md` from free-form markdown to a structured JSON array.
Each discrete fact becomes one entry in `knowledge.json`.

## Process

1. Read `meus-remedios/.memory/knowledge.md` in full
2. For each discrete fact, API spec, integration detail, or architecture note:
   - Extract topic, fact (1 sentence), correction (if "never do X" fact), valid_for, source
   - Add to `knowledge.json`
3. For facts with extensive code examples → create `knowledge_detail/K-NNN.md` instead of embedding in JSON

## JSON Entry Format

```json
{
  "topic": "timezone",
  "fact": "new Date('YYYY-MM-DD') parses as UTC midnight, causing off-by-one for non-UTC users",
  "correct": "Use parseLocalDate() from @/utils/dateUtils",
  "valid_for": ["js", "ts"],
  "source": "R-020"
}
```

## Completion Criteria

- [ ] `knowledge.json` covers all facts from `knowledge.md`
- [ ] Each entry has at minimum: topic, fact, valid_for, source
- [ ] JSON valid
- [ ] `migration-status.json` updated: wave_3.status = "completed"

## Commit

```
git commit -m "feat(devflow/wave-3): structure knowledge.md into knowledge.json"
```
