---
name: devflow-distill
description: >-
  Comprime o journal, recomputa os contadores de ciclo de vida, revisa promoção/demoção por top-K e reconcilia os índices contra o state.json. Invocada pelo operador (`/devflow-distill`). Não auto-invocar: escolher o modo é do operador, não do agente (R-065).
compatibility: Designed for Claude Code (or similar products)
---

# Modo Distillation do DEVFLOW (D0–D6)

> ⚠️ **Ordem obrigatória.** Se você não leu o `.agent/state.json` nesta sessão, **invoque `/devflow` primeiro** — o núcleo carrega o bootstrap, o HARD STOP e a R-065. Esta skill é um modo do DEVFLOW, não um processo autônomo: ela **lê e escreve o `state.json`**, que é a única transição válida entre modos (contexto herdado não conta).

> Referências e scripts vivem na raiz do repositório da skill `devflow`:
> `~/SKILLS/devflow/references/` e `~/SKILLS/devflow/scripts/`.

<!-- devflow-split:distill:begin -->
## Mode: Distillation

**Purpose:** Compress journal entries, refresh the lifecycle counters, and review promotion/demotion within the project. (Cross-project export was RETIRED in 2026-09-04 — see D4.)

### D0 — State Transition to Distillation

Immediately update state.json:

```json
{
  "session": {
    "mode": "distillation",
    "status": "distilling",
    "goal": "compress and distill project memory"
  }
}
```

### D1 — Journal Compression
```
Read all journal/*.jsonl entries since state.json.memory.last_distillation
For each event:
  "new_rule" event → verify R-NNN exists in RULES_INDEX.md, add if missing
  "new_ap" event  → verify AP-NNN exists in ANTI_PATTERNS_INDEX.md, add if missing
  "new_fact" event → verify in KNOWLEDGE_INDEX.md, add if missing
  "new_adr" event → verify in DECISIONS_INDEX.md, add if missing
  "po_unstable" event → a PO that looped/failed repeatedly (weak model could not prove it).
    Capture the learning: this kind of AC is hard to prove-by-transcript at the chosen tier.
    Feed back into tiering (decompose the AC, raise the tier, or rewrite the `proof:` to be
    more directly observable) for future specs.
Write compressed archive: memory/journal/archive/YYYY-WXX-WYY.json
  {"period": "...", "sessions": N, "rules_added": [...], "aps_triggered": [...], "decisions_made": [...], "po_unstable": [...]}
```

### D2 — Rule Lifecycle Review
```
FIRST, refresh the lifecycle counters — the review below is worthless if it reads a frozen field.
`incident_count`/`last_referenced` are DERIVED from the project's own traces (git log, journal,
events, measurement files), not hand-maintained:
  1. Recompute:  the project's counter in read-only mode (dosiq: `recount-memory.mjs --report`)
  2. Write back: the project's frontmatter writer (dosiq:
                 `migrate-memory-frontmatter.mjs --lifecycle --apply`)
  3. Verify:     the diff touches ONLY the lifecycle lines, and the schema validator stays green
                 with those fields TYPED (untyped, a passthrough schema accepts garbage such as
                 the literal `None` and reports success — dosiq 2026-09-04: typing them exposed
                 104 files carrying exactly that)
If the project has no such producer, treat both fields as ABSENT and say so in the distillation
entry — do NOT read the stale number as if it were current. A counter nobody recomputes is worse
than no counter: it looks like evidence.

Read RULES_INDEX.md — for each entry where review_due < today:
  Grep recent journal entries for references to this R-NNN
  IF referenced recently (< 4 weeks ago) → extend review_due by 12 weeks
  IF not referenced (> 12 weeks) → evaluate lifecycle:
    universal + recurring → keep `active`, consider `warm -> cold` only if bootstrap value dropped
    contextual + still plausible → keep `active`, set `layer = cold`
    historical/wave-specific/no operational value → set `status = "archived"` and `layer = cold`

Read ANTI_PATTERNS_INDEX.md — for each entry where expiry_date < today:
  IF trigger_count == 0 since creation → flag as candidate for deprecation
  IF trigger_count > 0 → extend expiry_date by 52 weeks
```

### D2.5 — Memory Lifecycle Heuristics
```
Promotion to `hot`:
  - rule/AP prevents recurring regressions across multiple domains
  - guidance is operational without extra context
  - evidence exists in repeated incidents, reviews, or journal references

Demotion to `cold`:
  - guidance is still valid but only matters in narrow scopes
  - item depends on specific feature families, incidents, or historical architectures
  - bootstrap cost is higher than day-to-day value

Archival:
  - item is already `cold`
  - recurrence is near-zero and usefulness is mostly historical
  - content is tied to a retired wave, persona, experiment, or component lineage

Guardrails:
  - prefer `warm -> cold` before archiving
  - do not archive items that still protect active contracts, production incidents, or ongoing architectural risks
  - preserve IDs and detail files when archiving for traceability
```

### D3 — Promotion Assessment (top-K, in-project)
```
Promotion has a HARD CEILING, not a floor. Rank the memories by the refreshed `incident_count`
(D2) and take the top-K; the memory that leaves the list is DEMOTED BY THE SAME EVENT that
promotes the one entering. An absolute threshold is the wrong instrument and the number proves it:
on dosiq, `incident_count >= 3` would promote 311 of 611 memories (51% of the corpus), which is
the very inflation this step exists to prevent.

  1. Rank + cut:   the project's top-K (dosiq: `recount-memory.mjs --skills-layer --k 12`)
  2. Diff:         against the always-loaded file (dosiq:
                   `--skills-layer --k 12 --diff-against CLAUDE.md`) — SUBIR/DESCER in one report
  3. Budget check: the ceiling is the reviewer's MEASURED chunk budget, not a number from a paper
                   (dosiq: `--estimate-bytes --pr N`, which EXECUTES the reviewer in measure mode)
  4. Second door:  severity (dosiq: `--severity-candidates`) — for the bug that happened ONCE and
                   still has to be known. Objective criteria only, each backed by a quotable line
                   from the record itself; "this feels serious" is not a criterion.

The implied threshold at the cut is an OBSERVATION (record it with HEAD + date), never an
acceptance criterion: it MOVES on its own, because every session that cites rules changes the
counts (dosiq measured 32 → 34 within a single day).

Editing the always-loaded file is a HUMAN decision — this step produces the report, not the edit.
```

### D3.5 — Process Friction Assessment (promote the SKILL, not the memory)

```
D2/D3 refresh what the CODE taught. This step reads what the PROCESS taught:
`.agent/memory/process-friction.jsonl`, written one line at a time by C5/`1c`.

  1. Read the ledger; drop lines already `promoted`.
  2. Group by (skill, section). The `kind` field is a closed vocabulary precisely so this
     grouping is mechanical — never re-interpret free text into a category.
  3. BAR (from DEVFLOW-META.md): a group promotes at 3+ independent observations FROM ≥2 DISTINCT
     specs. Three lines from one spec is one problem seen three times, not a pattern — hold them.
  4. For a group that clears the bar, emit into evolution/evolution_log.jsonl:
       {"type":"devflow_mutation_proposal","section":"<skill · section>",
        "rationale":"<the 3+ lines, cited verbatim, with spec + date>",
        "draft":"<proposed text — REQUIRED; a proposal without a draft is a complaint>",
        "status":"pending"}
     Respect the META guardrail: at most 2 pending proposals at any time. Over the cap, keep the
     group with the most distinct specs and say the others are held.
  5. Mark the consumed lines `promoted: "<proposal id>"` — never delete them. The ledger is the
     evidence the bar was actually met.

⚠️ This step PROPOSES. It never edits the skill: applying a mutation needs the operator's command
and human approval (R-065), and that door stays exactly where DEVFLOW-META.md put it.

📅 FALSIFICATION (same clause as C5/`1c`): if the ledger holds fewer than 3 lines after 10 coding
sessions, detection is not fitting the flow — REMOVE the step instead of enforcing it. That is the
verdict D4 earned below, and this step is built to earn it too if the signal is not real.
```

### D4 — Global Export — **RETIRED (2026-09-04, dosiq spec 078 / ADR-097)**
```
The cross-project export step no longer runs, and `synthesis/pending_export.json` is no longer
produced. Evidence that retired it (measured 2026-09-04):
  - ~/.devflow/global_base = 616 KB, 133 .md (137 files), EVERY content file last written
    2026-04-08 — five months write-only (the only newer file is a .DS_Store, written by Finder)
  - ZERO read paths: no script in this skill ever reads it; the only references were prose in
    SKILL.md and README.md
A step that writes something nobody reads is not knowledge management — it is a gate reporting
success for an operation with no consumer (AP-325 family). D3 now promotes WITHIN the project,
where the always-loaded file is the actual consumer.

The directory is LEFT ON DISK for traceability; nothing is deleted. Reviving it requires the thing
it never had: a reader — plus a decision about how a rule from project A is validated in project B.
```

### D5 — Autonomous Self-Cleaning (Index Regenerator) — MANDATORY DEEP SCAN
```
D5 is MANDATORY in every distillation — NOT optional. State.json counters
drift silently across sessions when sessions add R-NNN/AP-NNN/ADR-NNN
without bumping state.json counters. Trust the INDEX.md files as the
single source of truth; reconcile state.json against them.

Steps (in order):

1. SCAN detail files vs index entries (per class):
   For each class in {rules, anti-patterns, decisions, contracts, knowledge}:
     a. List all files matching memory/<class>/<category>/<ID>.md
     b. List all entries in [CLASS]_INDEX.md (regex match on [R-NNN], [AP-NNN], etc.)
     c. Compute symmetric diff:
        - files_without_index_entry → ADD entry to index (one-liner with
          title from H1 of the detail file)
        - index_entries_without_file → MARK as archived (do NOT delete;
          preserve traceability) OR flag for human review if status was active

2. RECONCILE state.json counters against indexes:
   For each counter in state.json.memory:
     a. count = grep -cE '^- \*\*\[<PREFIX>-' [CLASS]_INDEX.md
     b. If state.json count != grep count → UPDATE state.json with grep count
     c. LOG the delta in the distillation journal entry (before/after/delta).
        Example: "rules_count: 182→183 (+1 reconciled from index)"

3. AUDIT contract drops (specific to D5 deep scan):
   If contracts_count decreased since last_distillation:
     a. Identify which CON-NNN files no longer exist (compare git log on
        memory/contracts/ vs current state)
     b. Document the removed CON-NNN in the distillation journal entry
     c. If removal was unintentional, flag for human review

4. EMIT reconciliation block in journal entry:
   {
     "type": "distillation",
     "reconciliation": {
       "before": {...counters from state.json read at D0...},
       "after":  {...counters from grep at end of D5...},
       "delta":  {...per-class delta with sign...},
       "interpretation": "...one-line per non-zero delta..."
     }
   }

DO NOT skip steps 2 and 4 to save time — silent counter drift is a
recurring bug detected in prior distills (PR #559 / AP-161).
```

### D6 — Distillation Complete & State Update
```
After D5 reconciliation, acquire lock → update state.json:
  memory.last_distillation = now (ISO timestamp)
  memory.journal_entries_since_distillation = 0
  memory.rules_count = count of active entries in RULES_INDEX.md (POST D5)
  memory.anti_patterns_count = count of active entries in ANTI_PATTERNS_INDEX.md (POST D5)
  memory.decisions_count = count entries in DECISIONS_INDEX.md (POST D5)
  memory.contracts_count = count entries in CONTRACTS_INDEX.md (POST D5)
  session.status = "distilled"
Release lock

Append to evolution/evolution_log.jsonl:
  {"timestamp": "...", "event": "distillation_complete", "rules_promoted": N, "aps_triggered": N,
   "friction_lines": N, "mutation_proposals": N}

Write journal entry to memory/journal/YYYY-WWW.jsonl with distillation summary
```

**SURFACE THE PROPOSALS IN THE CLOSING REPORT — this is the reader, and it is a person.**
Any `devflow_mutation_proposal` emitted at D3.5 MUST appear in the text the operator reads when
this mode ends: the section it affects, the 3+ citations, and the draft. Appending it to
`evolution_log.jsonl` and saying nothing does NOT count as surfacing.

> This requirement is not bureaucracy — it is what D4 died for. A step that writes something
> nobody reads is a gate reporting success for an operation with no consumer (AP-325 family), and
> `evolution_log.jsonl` is already in that state: 20 entries between 2026-04 and 2026-09, all of
> them `distillation_complete`, none ever read back. The operator, at the end of a distill, is a
> reader who actually acts. Land it there or do not build it.

STOP. Memory distilled, counters reset.

---

<!-- devflow-split:distill:end -->
