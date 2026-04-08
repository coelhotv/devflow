# Wave 4 — ADR Archaeology: decisions.json + decisions_detail/

**Status:** pending
**Project:** meus-remedios
**Estimated effort:** 3-4h (2-3 sessions)
**Prerequisites:** Wave 3 complete

## Goal

Surface implicit architectural decisions from multiple sources and formalize them as ADRs.

## Sources (in order of richness)

1. **Merged PRs (GitHub)** — richest source: context, motivation, discussion
2. **`.memory/journal/`** — sprint decisions
3. **`CLAUDE.md`** — "Critical Rules" that embed decisions
4. **`docs/`** — architecture docs

## Sub-Wave 4a: PR Mining (run as Agent)

```bash
# List all merged PRs
gh pr list --repo <owner>/meus-remedios --state merged --limit 200 \
  --json number,title,body,mergedAt,labels \
  | python3 -c "
import json, sys
prs = json.load(sys.stdin)
for pr in prs:
    print(f'PR #{pr[\"number\"]}: {pr[\"title\"]} ({pr[\"mergedAt\"][:10]})')
    if pr['body']:
        print(f'  {pr[\"body\"][:200]}')
    print()
"
```

For each PR that shows evidence of a decision (mentions "decided", "because", "instead of", "alternative", architecture changes):
```bash
gh pr view <number> --json body,reviews,comments
```

Extract decision candidates → draft ADR-NNN entries.

## Sub-Wave 4b: CLAUDE.md + Docs Archaeology

Scan these files for decision statements:
- `CLAUDE.md` — each "Critical Rule" often hides an ADR
- `.memory/journal/` — search for "decidimos", "por que não", "alternativa"
- `docs/architecture/` — all files

## ADR Entry Format

```json
{
  "id": "ADR-001",
  "title": "Zod Enums in Portuguese",
  "status": "accepted",
  "date": "2026-02-07",
  "tags": ["zod", "i18n", "validation"],
  "supersedes": null,
  "superseded_by": null,
  "has_detail": true
}
```

## decisions_detail/ADR-NNN.md Format

See `templates/schema-reference.md` for full format.
Always include: Context, Options Considered, Decision, Consequences, Rollback, Source (PR link if available).

## Known ADRs to Create (identified in exploration)

- ADR-001: Zod enums use Portuguese values (matching DB constraints)
- ADR-002: No process.exit() in serverless functions
- ADR-003: Agent never self-merges (human approval + merge only)
- ADR-004: Vercel Hobby tier — max 12 serverless functions
- ADR-005: Zod schemas only in src/schemas/ (no scattered schemas)
- ADR-006: All views: lazy loading + Suspense + ViewSkeleton
- ADR-007: Semantic commits in Portuguese
- ADR-008: Feature-based architecture (not layer-based)
- ADR-009: Gemini Code Assist for automated review
- ADR-010: Dosage in pills (not mg) — max 100 per Zod constraint
- ... (30-50 total expected from PR mining)

## Completion Criteria

- [ ] PRs mined: `migration-status.json` wave_4.prs_mined = true
- [ ] `decisions.json` has 20+ ADR entries
- [ ] All entries have `decisions_detail/ADR-NNN.md`
- [ ] Status set correctly (accepted/proposed)
- [ ] `migration-status.json` updated: wave_4.status = "completed"

## Commit

```
git commit -m "feat(devflow/wave-4): create ADR registry from PR mining + CLAUDE.md archaeology

- NNN ADRs formalized in decisions.json + detail files
- Sources: N PRs mined, CLAUDE.md, journal entries"
```
