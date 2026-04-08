# Wave 5 — Contract Registry: contracts.json + contracts_detail/

**Status:** pending
**Project:** meus-remedios
**Estimated effort:** 2h (1-2 sessions)
**Prerequisites:** Wave 4 complete (ADRs provide context for contract decisions)

## Goal

Map stable interfaces between features and services into a contract registry.

## Sources

- `docs/reference/SERVICES.md` — service APIs
- `docs/reference/HOOKS.md` — custom hook interfaces
- `docs/reference/SCHEMAS.md` — Zod schema contracts
- `src/shared/components/` — shared component props (grep for TypeScript interfaces)
- `src/services/api/` — API service function signatures

## Process Per Contract

1. Identify stable interface (function, hook, schema, shared component)
2. Grep codebase for all consumers: `grep -r "serviceName.methodName" src/`
3. Determine: is this interface stable? Would changing it break multiple callers?
4. Add entry to `contracts.json`
5. Create `contracts_detail/CON-NNN.md` with:
   - Full signature
   - All current consumers (with file paths from grep)
   - Breaking change definition
   - Migration guide template

## JSON Entry Format

```json
{
  "id": "CON-001",
  "name": "logService.createLog",
  "file": "src/services/api/logService.js",
  "consumers": ["StockService", "DashboardProvider", "TelegramBot"],
  "breaking_change_requires": "ADR + all consumer updates + migration",
  "status": "stable",
  "has_detail": true
}
```

## Known Contracts (identified in exploration)

- CON-001: `logService.createLog(data)`
- CON-002: `useCachedQuery(key, fetcher, options)`
- CON-003: `parseLocalDate()` from dateUtils
- CON-004: `stockSchema` (Zod) — database contract
- CON-005: `<Button>` component props
- CON-006: `adherenceService.getAdherence()`
- CON-007: `useTheme()` hook
- ... (15-25 total expected)

## Completion Criteria

- [ ] `contracts.json` has 15+ entries
- [ ] All entries have `contracts_detail/CON-NNN.md`
- [ ] Each detail file lists all consumers (grep-verified)
- [ ] `migration-status.json` updated: wave_5.status = "completed"

## Commit

```
git commit -m "feat(devflow/wave-5): create contract registry from service + hook documentation

- NNN contracts formalized in contracts.json + detail files"
```
