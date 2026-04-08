# Wave 6 — Global Base Export: ~/.devflow/global_base/

**Status:** pending
**Project:** meus-remedios
**Estimated effort:** 1h (1 session)
**Prerequisites:** Waves 1-5 complete

## Goal

Identify universally applicable knowledge from meus-remedios and export to `~/.devflow/global_base/`.
This seeds the global knowledge base for all future projects.

## Universality Criteria

A rule or AP is universal if:
- `applies_to` contains `["js", "ts", "react", "supabase"]` (stack, not domain)
- Does NOT mention domain concepts: remédio, dose, paciente, medicamento, aderência, estoque, Telegram bot, Vercel Hobby limit, protocol_id
- Addresses a programming pattern that recurs across projects

## Process

1. Read `rules.json` — filter entries where:
   - `applies_to` has no domain-specific values
   - `tags` doesn't include domain tags (telegram, medical, stock)
   - The rule addresses a general JS/React/Supabase pattern

2. For each universal candidate: assign GR-NNN (GR = Global Rule)
3. Add to `~/.devflow/global_base/universal_rules.json`
4. Copy `rules_detail/R-NNN.md` to `~/.devflow/global_base/rules_detail/GR-NNN.md`
5. Repeat for anti-patterns (GAP-NNN)

6. Create/update `~/.devflow/global_base/index.json`:
```json
{
  "schema_version": "1.0",
  "projects": ["meus-remedios"],
  "last_updated": "YYYY-MM-DD",
  "universal_rules_count": N,
  "universal_aps_count": N
}
```

## Expected Universal Rules

- GR-001: Never `new Date('YYYY-MM-DD')` — timezone UTC off-by-one
- GR-002: Supabase nullable fields need `.nullable().optional()` not just `.optional()`
- GR-003: Zod enum values must match database CHECK constraint values exactly
- GR-004: Verify no duplicate file exists before modifying
- GR-005: Path aliases mandatory (no relative `../../` imports)
- ... (20-30 total expected)

## Expected Universal Anti-Patterns

- GAP-001: Never `process.exit()` in serverless functions
- GAP-002: Hardcoded CSS colors instead of design tokens
- GAP-003: Importing from relative path instead of alias
- ... (15-20 total expected)

## Completion Criteria

- [ ] `~/.devflow/global_base/` exists with valid JSON files
- [ ] `universal_rules.json` has 20+ GR-NNN entries
- [ ] `universal_anti_patterns.json` has 15+ GAP-NNN entries
- [ ] Detail files copied to global_base/*_detail/
- [ ] `index.json` updated
- [ ] New project test: run `setup.sh` on a temp dir — confirms global import works
- [ ] `migration-status.json` updated: wave_6.status = "completed"
