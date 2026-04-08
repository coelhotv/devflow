# Wave 4 — ADR Archaeology + Journal Migration

**Status:** pending
**Project:** meus-remedios
**Estimated effort:** 4-5h (3-4 sessions)
**Prerequisites:** Wave 3 complete

## Goal

Two deliverables in one wave:
1. Surface implicit architectural decisions from multiple sources and formalize them as ADRs.
2. Migrate sprint journals to the DEVFLOW format (recent → JSONL, old → archive).

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

## Sub-Wave 4c: Journal Migration

### Strategy

| Age | Action |
|-----|--------|
| Recent (W12–W14, last ~6 weeks) | Convert to `journal/YYYY-WWW.jsonl` (one event per line) |
| Old (W08–W11) | Move as-is to `journal/archive/` (markdown preserved, not converted) |

### Journal files to convert (JSONL)

From `.memory/journal/`:
- `2026-W12.md`, `2026-W12-D0D3.md`, `2026-W12-P4.md`
- `2026-W13.md`, `2026-W13-WAVE*.md` (6 files)
- `2026-W14.md`, `2026-W14-WAVE*.md` (5 files)

### Journal files to archive (copy as-is)

- `archive-2026-W06-W07.md`
- `2026-W08.md`, `2026-W09.md`, `2026-W10.md`
- `2026-W11.md`, `2026-W11-M*.md`, `2026-W11-Sprint65.md`

### JSONL event format

Each significant item in the markdown journal becomes one line:

```jsonl
{"ts":"2026-04-06","type":"decision","ref":"ADR-011","summary":"InstallPrompt é sanctuary incondicional — sem seletor redesign","source":"journal/2026-W14.md"}
{"ts":"2026-04-06","type":"delivery","sprint":"S14.5","summary":"ChatWindow: Trash2/X Lucide, ConfirmDialog substituindo window.confirm()","files":["src/features/chatbot/components/ChatWindow.jsx"]}
{"ts":"2026-04-06","type":"rule_applied","ref":"R-042","summary":"LLM proibido de usar markdown nas respostas do chatbot"}
```

Allowed event types: `decision`, `delivery`, `bug_found`, `rule_applied`, `rule_added`, `rule_updated`, `observation`.

### Destination path

```
.agent/memory/journal/YYYY-WWW.jsonl     ← converted recent entries
.agent/memory/journal/archive/           ← old markdown files, unchanged
```

### Process per file

1. Read the markdown journal
2. Extract discrete events (one per decision, delivery, key observation)
3. Write as `.jsonl` — one JSON object per line, no trailing comma
4. If any event has an associated ADR candidate → add to `decisions.json` with `source` pointing to the journal

## Completion Criteria

**ADRs:**
- [ ] PRs mined: `migration-status.json` wave_4.prs_mined = true
- [ ] `decisions.json` has 20+ ADR entries
- [ ] All entries have `decisions_detail/ADR-NNN.md`
- [ ] Status set correctly (accepted/proposed)

**Journals:**
- [ ] Recent journals (W12–W14) converted to `.jsonl` in `.agent/memory/journal/`
- [ ] Old journals (W08–W11) copied to `.agent/memory/journal/archive/`
- [ ] Events with decision candidates cross-referenced in `decisions.json`

**Status:**
- [ ] `migration-status.json` updated: wave_4.status = "completed"

## Commit

```
git commit -m "feat(devflow/wave-4): ADR registry + journal migration

- NNN ADRs formalized in decisions.json + detail files
- Sources: N PRs mined, CLAUDE.md, journal entries
- Recent journals (W12-W14) converted to JSONL
- Old journals (W08-W11) archived as markdown"
```
