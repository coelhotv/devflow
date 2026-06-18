# Spec NNN — <feature name>  (goal-shaped, Tier 1 example)

Feature Directory: plans/specs/NNN-feature-name/
Created: YYYY-MM-DD · Status: specified · **Tier**: 1 · Input: <US source>

## Context
<Why, short. The problem and who has it.>

## US1 — <user story title> (P1)
Given <precondition>, When <action by authorized actor>, Then <observable outcome>.

```po PO-1
ac:     <acceptance criterion in one line — the WHAT>
proof:  <exact command that demonstrates it>          # e.g. pytest test/auth/approve_spec.py -k authz
expect: <positive signal observable in the output>    # e.g. 2 passed (authorized→200, unauthorized→403)
guard:  <anti-regression, Tier 1 = light>             # e.g. pytest test/auth/ → no test goes passed→failed
status: [ ] open
```

```po PO-2
ac:     <second criterion>
proof:  MANUAL — <observable action when no command fits>   # e.g. curl shows internal_comment field absent
expect: <what the action must show>
guard:  <light anti-regression for this area>
status: [ ] open
```

## Functional Requirements
- FR-1: <requirement>
- FR-2: <requirement>

## Success Criteria
- SC-1: 100% of ACs have a closed PO (status [x]) by end of C-mode
- SC-2: <other measurable success>

## Assumptions / Open Questions
- <assumption, or [NEEDS CLARIFICATION: ...]>

---

> **How this flows downstream**
> - `tasks.md`: each task links the PO(s) it closes — `- [ ] T001 [US1][PO-1] implement authz guard`
> - **C4**: run each PO's `proof`, paste output, confirm `expect`, run `guard`, flip `status: [x]`.
>   The turn does not close while any PO is `[ ] open`.
> - **RC5 Pass 0**: `rtk grep '```po'` → every PO `[x]`? each `[x]` has pasted evidence? MANUAL POs double-checked.
> - **Tier 2 regulated** adds `audit:` / `evidence:` fields to each PO block.
