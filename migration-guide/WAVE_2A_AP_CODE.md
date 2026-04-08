# Wave 2a — Anti-Patterns Migration: AP-001 to AP-A04 (Code Management)

**Status:** pending
**Project:** meus-remedios
**Source:** `meus-remedios/.memory/anti-patterns.md` (AP-001 to AP-A04)
**Estimated effort:** 1h (1 session)
**Prerequisites:** Wave 1c complete (all rules migrated)

## Goal

Convert AP-001 through AP-A04 (code management anti-patterns) to index + detail files.

## Process Per Anti-Pattern

For each AP-NNN:
1. Read from `.memory/anti-patterns.md`
2. Add entry to `anti-patterns.json`
3. Create `anti-patterns_detail/AP-NNN.md` with:
   - Problem description
   - Incorrect pattern (code example if available)
   - Correct pattern
   - Prevention strategy
   - Related rule (R-NNN)
   - Incidents count (from journal mentions)

## JSON Entry Format

```json
{
  "id": "AP-001",
  "title": "Editing Duplicate File",
  "summary": "Modifying a file without checking for duplicates first",
  "applies_to": ["all"],
  "tags": ["file-management", "safety"],
  "trigger_count": 5,
  "last_triggered": null,
  "expiry_date": "2027-04-01",
  "status": "active",
  "related_rule": "R-001",
  "has_detail": true
}
```

## Completion Criteria

- [ ] `anti-patterns.json` has AP-001 to AP-A04 entries
- [ ] `anti-patterns_detail/` has one file per AP in this range
- [ ] JSON valid
- [ ] `migration-status.json` updated: wave_2a.status = "completed"
