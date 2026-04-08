# Wave 7 — Validation: Full Integration Test

**Status:** pending
**Project:** meus-remedios
**Estimated effort:** 1-2h (1 session)
**Prerequisites:** All previous waves complete

## Goal

Verify the complete DEVFLOW installation works end-to-end in a real session.

## Validation Checklist

### 1. Status Check
```
/devflow status
```
Expected:
- rules_count: 156
- anti_patterns_count: 100+
- decisions_count: 20+
- contracts_count: 15+
- No file read errors

### 2. Filtered Loading Test
Run: `/devflow coding "add optional field to React component"`
Verify:
- Only rules with tags ["react", "file-management"] are loaded into context
- Telegram-specific rules (R-030, R-031) are NOT loaded
- Context size is within budget

### 3. On-Demand Detail Test
Check that when a timezone-related goal is given:
- `rules.json` entry for R-020 is found (summary: timezone safety)
- `rules_detail/R-020.md` is loaded (full rationale + code example)

### 4. Contract Gateway Test
Attempt a simulated breaking change on CON-001 (logService.createLog):
- Add/remove a required parameter
Expected: DEVFLOW halts, drafts ADR-draft.md, asks for human approval

### 5. Journal + State Test
After any session:
- `journal/YYYY-WWW.jsonl` has a new line
- `state.json` has incremented `journal_entries_since_distillation`
- `sessions/events.jsonl` has session_start and session_end entries

### 6. Lock Test
Open two Claude Code windows.
In window 1: start a long coding session that acquires `.lock`
In window 2: attempt to write to `rules.json`
Expected: window 2 waits (or reports lock occupied)

### 7. Global Import Test
Run `setup.sh` on a new temp directory:
```bash
mkdir /tmp/test-project
bash setup.sh /tmp/test-project "test-project" "react,typescript"
```
Expected:
- `.agent/` structure created
- GR-NNN rules imported from `~/.devflow/global_base/`
- Output confirms import count

## Final Commit

```
git commit -m "feat(devflow/wave-7): validate full DEVFLOW installation on meus-remedios

- All 7 validation checks passed
- Ready for production use"
```

## Post-Validation

Update `CLAUDE.md` in meus-remedios:
- Remove "Legacy memory files in .memory/ remain authoritative during migration"
- Add "Migration complete. Primary memory: .agent/memory/"
