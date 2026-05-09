---
id: R-XXX
title: [Concise rule title]
summary: "[One-line rule statement. Must be specific and actionable.]"
applies_to:
  - [scope: "all", "backend", "frontend", "tests", etc.]
tags:
  - [tag1]
  - [tag2]
incident_count: 0
last_referenced: null
review_due: [date YYYY-MM-DD, e.g. 2026-12-31]
status: active
layer: hot
pack: [optional: logical grouping, e.g. "date-time", "forms", "api"]
bootstrap_default: false
---

# R-XXX — [Rule Title]

## Rule

State the rule in 1-3 bullet points. Must be unambiguous and actionable.

Examples:
- ALWAYS use `parseLocalDate()` for date parsing
- NEVER use `new Date('YYYY-MM-DD')` — creates wrong day in GMT-3
- Validate all input params with Zod safeParse() before processing

## Why

Explain the root cause, incident history, or technical constraint that makes this rule necessary.

### Example Scenario
Describe a specific failure case if the rule is violated.

## Examples

### ✓ Correct
```javascript
// Code example following the rule
```

### ✗ Wrong
```javascript
// Code example violating the rule
```

## Applies To

List scopes: `all`, `backend`, `frontend`, `tests`, `api`, etc.

## Related

- Link to related rules
- Link to anti-patterns this prevents
- Link to decisions that led to this rule
