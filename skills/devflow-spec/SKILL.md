---
name: devflow-spec
description: >-
  Converte intenção em especificação numerada: nome curto, numeração sequencial, classificação de Tier, spec.md com Proof Obligations e sincronia do índice de specs. Invocada pelo operador (`/devflow-spec`). Não auto-invocar: escolher o modo é do operador, não do agente (R-065).
compatibility: Designed for Claude Code (or similar products)
---

# Modo Specifying do DEVFLOW (S0–S6)

> ⚠️ **Ordem obrigatória.** Se você não leu o `.agent/state.json` nesta sessão, **invoque `/devflow` primeiro** — o núcleo carrega o bootstrap, o HARD STOP e a R-065. Esta skill é um modo do DEVFLOW, não um processo autônomo: ela **lê e escreve o `state.json`**, que é a única transição válida entre modos (contexto herdado não conta).

> Referências e scripts vivem na raiz do repositório da skill `devflow`:
> `~/SKILLS/devflow/references/` e `~/SKILLS/devflow/scripts/`.

<!-- devflow-split:spec:begin -->
## Mode: Specifying

**Purpose:** Convert product or development intent into a durable, numbered feature specification before technical planning.

### S0 — State Transition to Specifying

**⚠️ MANDATORY FIRST STEP — DO NOT SKIP**

Upon entering Specifying mode, **IMMEDIATELY** update state.json BEFORE proceeding to S1:

```json
{
  "session": {
    "mode": "specifying",
    "status": "specifying",
    "goal": "<feature description>",
    "goal_type": "feature"
  }
}
```

Checklist: Read current state.json → update mode/status/goal/goal_type → write to disk → verify write → proceed to S1.

### S1 — Short Name
```
Generate a concise short name from the feature description:
  - 2-4 words
  - kebab-case
  - action-noun when possible
  - preserve technical terms (OAuth, API, tz, PDF, etc.)
  - remove filler words

Examples:
  "Add user authentication" → user-auth
  "Fix payment processing timeout" → fix-payment-timeout
  "Create analytics dashboard" → analytics-dashboard
```

### S2 — Numbering
```
Feature specs live in `plans/specs/`.

Sequential numbering:
  1. Create `plans/specs/` if missing
  2. List directories matching `^[0-9]{3,}-`
  3. Extract numeric prefixes
  4. next = max(prefixes) + 1, or 001 if none exist
  5. Format with at least 3 digits; allow 1000+ naturally

Do NOT count legacy specs outside `plans/specs/`.
```

### S2.5 — Tier Classification (MANDATORY)
```
Classify the work using the Work Tiers table. Record session.tier in state.json.
  Tier 0 → do NOT enter Specifying. Tell the operator "Tier 0 — no spec needed;
           ready to code under C1-C5 directly." STOP.
  Tier 1 → create the dir but only spec.md (lite) + tasks.md (see S3/S4).
  Tier 2 → full dir + full bundle; consider slicing into sub-specs.
If the tier is ambiguous, ASK the operator before creating any artifact.
```

### S3 — Directory Creation (tier-aware)
```
Tier 1:
  plans/specs/NNN-feature-name/        # spec.md + tasks.md live here

Tier 2:
  plans/specs/NNN-feature-name/
  plans/specs/NNN-feature-name/checklists/
  plans/specs/NNN-feature-name/contracts/
```

### S4 — Feature Specification
```
Write `plans/specs/NNN-feature-name/spec.md`.

Header MUST include: Feature Directory, Created, Status, **Tier**, Input.

Tier 1 (lite) — keep it to one screen:
  - Context (why, short)
  - 1–3 User Stories (prioritized) each with Acceptance Scenarios (Given/When/Then)
  - For EACH acceptance criterion, emit a `po` block (see Proof Obligations).
    The Given/When/Then is already almost a test — the PO makes it executable
    and citable. Tier 1+: an AC without a PO is INVALID.
  - Functional Requirements (FR-###)
  - Success Criteria (SC-###) — include SC: "100% of ACs have a closed PO (status [x]) by end of C-mode"
  - Assumptions / Open Questions

Tier 2 (full) — also:
  - Edge Cases
  - Key Entities (when data is involved)
  - Explicit data-migration scenarios when a schema/enum/format changes (see Reality note below)
  - PO blocks are formal; regulated work adds `audit`/`evidence` fields (see Proof Obligations).

Specifying focuses on WHAT and WHY. Do NOT choose stack, files, APIs,
database tables, or implementation details here (those go in plan.md / C2).
The `proof:` command names the CHECK (e.g. "the auth test passes"), not the
implementation — naming a test file an AC must satisfy is WHAT, not HOW.

Use `[NEEDS CLARIFICATION: ...]` for any ambiguity that changes scope, UX,
security/privacy, ARCHITECTURE, DATA MODEL, or validation. Limit to 3 markers.
⚠️ A decision with architectural impact MUST be a [NEEDS CLARIFICATION] marker
resolved by the operator — NEVER a plausible guess. Guessing an architectural
default and discovering it wrong later is the most expensive failure mode (e.g.
the "derive liquid from concentration unit vs. is_liquid boolean + required data
migration" call must be a marker, not an assumption).
```

### S5 — State Update
```
Update .agent/state.json:
  session.status = "specified"
  session.spec_dir = "plans/specs/NNN-feature-name"
  session.spec = "plans/specs/NNN-feature-name/spec.md"
```

### S6 — Record & Completion
```
Append to .agent/sessions/events.jsonl:
  {"timestamp": "...", "event": "specifying_complete", "spec_dir": "...", "spec": "..."}

Write journal entry to .agent/memory/journal/YYYY-WWW.jsonl.
```

**SPECS INDEX SYNC (MANDATORY — do not skip):** if the specs directory has an index/README
(e.g. `plans/specs/README.md`), **register the new spec as a row there** (number, short name,
status, one-line note) in the same step that creates the spec. Any change under the specs
directory — **a new spec dir, or a status transition** — MUST be reflected in that index in the
SAME action that caused it; the index is the canonical status source and silently drifts when
creation/status updates skip it. (No index file → skip; this is conditional, not project-specific.)

STOP. Awaiting Planning mode invocation.

---

<!-- devflow-split:spec:end -->

<!-- devflow-split:qr:begin -->
## Quick Reference — Do / Do Not

> Recorte **deste modo**. A tabela completa do DEVFLOW está distribuída pelas 7 skills — o núcleo (`/devflow`) guarda as linhas transversais.

| DO | DO NOT |
|----|--------|
| Register/update the spec row in the specs index/README on creation AND every status change | Create a spec dir or change its status without updating the specs index (silent drift) |
<!-- devflow-split:qr:end -->
