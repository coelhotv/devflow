# DEVFLOW — Schema Reference

DEVFLOW stores project memory in version-controlled files. The current architecture uses Markdown sparse indexes plus Markdown detail files with YAML frontmatter.

Do not use the legacy JSON-index architecture or legacy detail folders for new projects.

---

## `.agent/state.json`

`state.json` is the session checkpoint. Read it first. Update it last in every mode.

Required baseline:

```json
{
  "project": "project-name",
  "sprint": "YYYY-WWW",
  "session": {
    "mode": "bootstrap | specifying | planning | coding | reviewing | distillation",
    "status": "idle | specifying | specified | planning | planned | analysis | coding | completed | reviewing | reviewed | distilling | distilled",
    "goal": "current goal",
    "goal_type": "feature | fix | refactor | docs | chore"
  },
  "memory": {
    "last_distillation": "YYYY-MM-DDTHH:mm:ssZ",
    "journal_entries_since_distillation": 0,
    "rules_count": 0,
    "anti_patterns_count": 0,
    "decisions_count": 0,
    "contracts_count": 0,
    "distillation_due": false
  },
  "genes": {
    "memory_distillation_threshold": 15,
    "auto_promote_rule_after_incidents": 3
  },
  "quality_gates": {
    "index_loaded_at": null
  }
}
```

Optional v1.8 session fields for spec-first workflows:

```json
{
  "session": {
    "spec_dir": "plans/specs/NNN-feature-name",
    "spec": "plans/specs/NNN-feature-name/spec.md",
    "plan": "plans/specs/NNN-feature-name/plan.md",
    "tasks": "plans/specs/NNN-feature-name/tasks.md",
    "analysis": "plans/specs/NNN-feature-name/analysis.md",
    "linked_adrs": ["ADR-NNN"],
    "linked_contracts": ["CON-NNN"]
  }
}
```

Compatibility rule:

- If `session.spec_dir` exists, use the v1.8 spec directory.
- If only `session.spec` exists, treat it as a legacy spec path.

---

## `.agent/constitution.md`

Project-level governing principles and non-negotiable constraints live at:

```text
.agent/constitution.md
```

This file is not a memory index. It is project governance loaded during bootstrap before rules/APs.

Recommended structure:

```markdown
# <Project> Constitution

## Core Principles

### I. <Principle Name>
<MUST/SHOULD constraints and rationale>

## Delivery Constraints

## Quality Gates

## Governance

**Version**: 0.1.0 | **Ratified**: YYYY-MM-DD | **Last Amended**: YYYY-MM-DD
```

Precedence:

```text
constitution > accepted ADRs > contracts > rules/APs > plan/tasks
```

---

## Memory Index Files

All sparse indexes live in `.agent/memory/`:

```text
.agent/memory/RULES_INDEX.md
.agent/memory/ANTI_PATTERNS_INDEX.md
.agent/memory/DECISIONS_INDEX.md
.agent/memory/CONTRACTS_INDEX.md
.agent/memory/KNOWLEDGE_INDEX.md
```

Indexes are Markdown grouped by category. Entries should follow this shape:

```markdown
## Category Name (`category_slug`)
- **[R-001]** Short operational summary -> [`rules/category_slug/R-001.md`](./rules/category_slug/R-001.md)
```

Detail files live under category folders:

```text
.agent/memory/rules/<category>/R-NNN.md
.agent/memory/anti-patterns/<category>/AP-NNN.md
.agent/memory/decisions/<category>/ADR-NNN.md
.agent/memory/contracts/<category>/CON-NNN.md
.agent/memory/knowledge/<category>/K-NNN.md
```

Common frontmatter fields:

```yaml
---
id: R-NNN
title: Short descriptive title
summary: One-line operational summary
applies_to: [all]
tags: [process]
status: active
layer: hot
pack: process
bootstrap_default: true
---
```

Layer values:

- `hot`: universal guardrail loaded on bootstrap.
- `warm`: loaded when scope or pack matches.
- `cold`: retained for consultation, not normal bootstrap.
- `archived`: traceability only.

Status values:

- `active`
- `proposed`
- `accepted` (ADRs)
- `deprecated`
- `archived`

---

## Rule Detail Template

```markdown
---
id: R-NNN
title: <Title>
summary: <One-line rule>
applies_to: [all]
tags: [process]
status: active
layer: hot
pack: process
bootstrap_default: true
---

# R-NNN — <Title>

## Rule

<What must be done.>

## Rationale

<Why this exists.>

## Application

<Concrete steps.>

## Evidence

<Incident, PR, journal, or validation source.>
```

---

## Anti-Pattern Detail Template

```markdown
---
id: AP-NNN
title: <Title>
summary: <One-line anti-pattern>
applies_to: [all]
tags: [process]
status: active
layer: warm
pack: process
trigger_count: 0
---

# AP-NNN — <Title>

## Pattern

<What not to do.>

## Failure Mode

<What breaks.>

## Prevention

<How to avoid it.>

## Related Rules

- R-NNN
```

---

## Contract Detail Template

```markdown
---
id: CON-NNN
title: <Interface name>
status: stable
layer: warm
tags: [contract]
---

# CON-NNN — <Interface name>

## Interface

<Signature, schema, props, API, or data contract.>

## Consumers

- <Consumer> — <usage>

## Breaking Change Definition

A change is breaking if it:

- <condition>

## Non-Breaking Changes

- Adding optional fields.

## Migration Guide

<Required steps for breaking changes.>

## Related ADRs

- ADR-NNN
```

---

## ADR Detail Template

```markdown
---
id: ADR-NNN
title: <Decision title>
status: proposed
date: YYYY-MM-DD
tags: [architecture]
---

# ADR-NNN — <Decision title>

## Context

## Options Considered

## Decision

## Consequences

## Rollback
```

---

## Spec-First Plans

DEVFLOW v1.8 feature specs live outside `.agent/` and should be version-controlled with the project:

```text
plans/specs/NNN-feature-name/
  spec.md
  plan.md
  tasks.md
  analysis.md
  checklists/
    requirements.md
  contracts/
```

`spec.md` describes WHAT and WHY.

`plan.md` describes technical approach, target files, risks, contracts, quality gates, and clarifications.

`tasks.md` is durable task context. TodoWrite mirrors it during coding.

`analysis.md` is the C1.5 artifact coverage report.

`checklists/requirements.md` validates requirements quality, not implementation behavior.

---

## Append-Only Events

Journal entries:

```text
.agent/memory/journal/YYYY-WWW.jsonl
```

Session events:

```text
.agent/sessions/events.jsonl
```

Common events:

```jsonl
{"timestamp":"ISO","event":"specifying_complete","spec_dir":"plans/specs/001-example","spec":"plans/specs/001-example/spec.md"}
{"timestamp":"ISO","event":"planning_complete","spec":"plans/specs/001-example/spec.md","plan":"plans/specs/001-example/plan.md","tasks":"plans/specs/001-example/tasks.md"}
{"timestamp":"ISO","event":"coding_complete","files":["src/..."],"rules_applied":["R-NNN"],"aps_triggered":[]}
{"timestamp":"ISO","event":"review_complete","violations":[],"compliant":["R-NNN"]}
{"timestamp":"ISO","event":"distillation_complete","rules_promoted":0,"aps_triggered":0}
```
