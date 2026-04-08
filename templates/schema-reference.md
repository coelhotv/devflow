# DEVFLOW — Schema Reference

All index files live in `.agent/memory/`. They are compact JSON arrays — one object per entry.
Detail files live in the corresponding `*_detail/` subfolder as `X-NNN.md`.

---

## rules.json entry

```json
{
  "id": "R-001",
  "title": "Short descriptive title",
  "summary": "One line — what the rule requires",
  "applies_to": ["all | js | ts | react | vue | supabase | postgres | node | python | ..."],
  "tags": ["file-management | timezone | validation | performance | design | security | ..."],
  "incident_count": 0,
  "last_referenced": null,
  "review_due": "YYYY-MM-DD",
  "status": "active | in-review | deprecated",
  "has_detail": true
}
```

## rules_detail/R-NNN.md structure

```markdown
# R-NNN: <Title>

**Summary:** One line.

**Rationale:** Why this rule exists. What went wrong before it existed.

**How to apply:**
[Concrete steps or check]

**Example — correct:**
[code snippet]

**Example — incorrect:**
[code snippet]

**Related anti-pattern:** AP-NNN
**Related ADR:** ADR-NNN (if applicable)
```

---

## anti-patterns.json entry

```json
{
  "id": "AP-001",
  "title": "Short descriptive title",
  "summary": "One line — what NOT to do",
  "applies_to": ["all | js | ts | react | ..."],
  "tags": ["timezone | validation | performance | ux | security | ..."],
  "trigger_count": 0,
  "last_triggered": null,
  "expiry_date": "YYYY-MM-DD",
  "status": "active | deprecated",
  "related_rule": "R-NNN",
  "has_detail": true
}
```

## anti-patterns_detail/AP-NNN.md structure

```markdown
# AP-NNN: <Title>

**Summary:** What NOT to do — one line.

**Problem:**
[Why this is harmful. What breaks.]

**Incorrect pattern:**
[code or description]

**Correct pattern:**
[code or description]

**How to prevent:**
[Check or linting rule or test]

**Incidents:**
- YYYY-MM-DD: [brief description of incident]

**Related rule:** R-NNN
```

---

## contracts.json entry

```json
{
  "id": "CON-001",
  "name": "serviceName.methodName or hookName or SchemaName",
  "file": "src/path/to/file.js",
  "consumers": ["ServiceA", "ComponentB", "FeatureC"],
  "breaking_change_requires": "ADR + all consumer updates + migration",
  "status": "stable | in-review | deprecated",
  "has_detail": true
}
```

## contracts_detail/CON-NNN.md structure

```markdown
# CON-NNN: <Name>

**File:** `src/path/to/file.js`
**Status:** stable

## Interface

[Full signature / schema / props]

## Consumers

- ServiceA — how it uses this contract
- ComponentB — how it uses this contract

## Breaking Change Definition

A change is breaking if it:
- [condition 1]
- [condition 2]

Non-breaking (safe to do without ADR):
- Adding optional fields/parameters
- [other safe changes]

## Migration Guide

[Steps to follow when a breaking change is necessary]

## Related ADRs

- ADR-NNN: [why this contract was designed this way]
```

---

## decisions.json entry

```json
{
  "id": "ADR-001",
  "title": "Short decision title",
  "status": "proposed | accepted | superseded | deprecated",
  "date": "YYYY-MM-DD",
  "tags": ["architecture | validation | infra | ux | process | ..."],
  "supersedes": null,
  "superseded_by": null,
  "has_detail": true
}
```

## decisions_detail/ADR-NNN.md structure

```markdown
# ADR-NNN: <Title>

**Status:** accepted
**Date:** YYYY-MM-DD
**Tags:** architecture, validation

## Context

[What problem or situation prompted this decision.]

## Options Considered

1. **Option A** — [pros/cons]
2. **Option B** — [pros/cons]
3. **Option C (chosen)** — [pros/cons]

## Decision

[What was decided and why.]

## Consequences

**Positive:**
- [benefit 1]

**Negative / trade-offs:**
- [trade-off 1]

## Rollback

[How to undo this decision if needed.]

## Source

PR: #NNN (if applicable)
Journal: YYYY-WWW.jsonl (if applicable)
```

---

## knowledge.json entry

```json
{
  "topic": "timezone | supabase | zod | telegram | performance | ...",
  "fact": "The key fact in one sentence.",
  "correct": "What to do instead (optional — for 'never do X' facts).",
  "valid_for": ["supabase >= 2.0 | react 19 | all | ..."],
  "source": "R-NNN or ADR-NNN or 'external'"
}
```

---

## journal/YYYY-WWW.jsonl entries (append-only)

One JSON object per line. Common event types:

```jsonl
{"timestamp":"ISO","session":"sess_id","event":"session_start","mode":"coding","goal":"..."}
{"timestamp":"ISO","session":"sess_id","event":"task_complete","task":"...","rules_applied":["R-NNN"],"aps_triggered":[],"files_changed":["src/..."]}
{"timestamp":"ISO","session":"sess_id","event":"new_rule","rule_id":"R-NNN","summary":"..."}
{"timestamp":"ISO","session":"sess_id","event":"new_ap","ap_id":"AP-NNN","summary":"..."}
{"timestamp":"ISO","session":"sess_id","event":"new_adr","adr_id":"ADR-NNN","title":"...","status":"proposed"}
{"timestamp":"ISO","session":"sess_id","event":"contract_checked","contract_id":"CON-NNN","breaking":false}
{"timestamp":"ISO","session":"sess_id","event":"goal_drift","criterion":"...","reason":"..."}
{"timestamp":"ISO","session":"sess_id","event":"session_end","duration_min":42}
```

---

## sessions/events.jsonl entries (append-only, capped at 200)

Lighter than journal — session-level events only:

```jsonl
{"timestamp":"ISO","event":"session_start","session_id":"...","mode":"coding"}
{"timestamp":"ISO","event":"lock_acquired","file":"rules.json"}
{"timestamp":"ISO","event":"lock_released","file":"rules.json"}
{"timestamp":"ISO","event":"stale_lock_override","file":"rules.json","original_session":"..."}
{"timestamp":"ISO","event":"distillation_triggered","reason":"threshold"}
{"timestamp":"ISO","event":"session_end","rules_applied":2,"aps_triggered":0}
```
