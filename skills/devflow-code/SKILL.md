---
name: devflow-code
description: >-
  Executa a entrega e a revisão pré-PR: checklist pré-código, gate de contrato, ordem de implementação, gates de qualidade, fechamento das Proof Obligations e o protocolo pós-código. Invocada pelo operador (`/devflow-code`). Não auto-invocar: escolher o modo é do operador, não do agente (R-065).
compatibility: Designed for Claude Code (or similar products)
---

# Modo Coding (C0–C5) e Reviewing (R0–R5, RC5/RC6) do DEVFLOW

> ⚠️ **Ordem obrigatória.** Se você não leu o `.agent/state.json` nesta sessão, **invoque `/devflow` primeiro** — o núcleo carrega o bootstrap, o HARD STOP e a R-065. Esta skill é um modo do DEVFLOW, não um processo autônomo: ela **lê e escreve o `state.json`**, que é a única transição válida entre modos (contexto herdado não conta).

> Referências e scripts vivem na raiz do repositório da skill `devflow`:
> `~/SKILLS/devflow/references/` e `~/SKILLS/devflow/scripts/`.

<!-- devflow-split:code:begin -->
## Mode: Coding

**Purpose:** Implement features following memory constraints and contracts.

### C0 — State Transition to Analysis

**⚠️ MANDATORY FIRST STEP — DO NOT SKIP**

Upon entering Coding mode, **IMMEDIATELY** update state.json BEFORE proceeding to C1:

```json
{
  "session": {
    "mode": "coding",
    "status": "analysis",
    "goal": "<from planning or user input>",
    "goal_type": "<feature|fix|refactor|docs|chore>"
  }
}
```

Checklist: Read current state.json → update mode/status/goal/goal_type → write to disk → verify write (check mtime changed) → proceed to C1.

### C1 — Pre-Code Checklist
```
Verify before writing any code (do not skip):
  [ ] BRANCH SYNC RITUAL — before creating a new branch OR spawning a sub-agent
      that touches files in shared packages (`packages/*`, `apps/*/src/features/*`):
        1. git fetch origin
        2. git status — confirm current branch is up-to-date with origin
        3. IF base branch (main/develop) drifted from local → git pull (or
           `git reset --hard origin/<base>` when local has no committed work)
        4. ONLY THEN create the new feature branch or spawn the sub-agent
      RATIONALE: an outdated local branch causes sub-agents to "port" files
      that already exist in origin, generating duplicates that explode at
      `git push` (lint clash, merge conflict). Cost: 15+ min reset hard per
      incident. Detected in retro Fase 2 (D7); documented as AP-169 in dosiq.
  [ ] RULES_INDEX.md loaded and relevant rules identified
  [ ] R-221 SQP loaded for any code-changing work
      Extract and record before implementation:
        - affected platform(s): Web/PWA, Mobile, Shared/Core, Backend/Infra
        - SemVer impact: patch, minor, major, or no-user-impact
        - version source(s) to update, if any
        - CHANGELOG.md [Unreleased] target section
        - store-note relevance for mobile changes
  [ ] ANTI_PATTERNS_INDEX.md loaded and relevant APs identified
  [ ] Target file exists: find src -name "*TargetFile*" (verify single result)
  [ ] No duplicate files: same find command, count == 1
  [ ] Path aliases confirmed (check vite.config.js / tsconfig.json / equivalent)
  [ ] Relevant contracts identified from CONTRACTS_INDEX.md
  [ ] Test framework confirmed per workspace: read package.json in the TARGET workspace
      (do not assume root framework applies — workspaces may differ, e.g. Jest vs Vitest)
      NEVER mix vi.fn()/jest.fn() or vitest/jest imports across workspaces.

  [ ] Spec exists in plans/ for this task (or created in P3) — AND read it COMPLETELY:
      ⚠️  Do NOT skim — read the entire spec from start to finish before proceeding.
      Extract and record ALL of the following before writing a single line of code:

        DELIVERABLES (core + peripheral):
          - List every file to create or modify, including schemas, migrations, contracts,
            test files, config changes, and documentation updates.
          - "Peripheral" items (new CON-NNN contracts, DB migrations, feature flags,
            route registrations) are as mandatory as core features — do not omit them.

          ⚠️ TARGET FILES COMPLETENESS CHECK (R-267) — when plan.md has a Target Files table:
            Before accepting the list as complete, validate both paths for every new/changed field:

            WRITE PATH (typically in Target Files):
              doseInstanceGenerator, repository, migration SQL — usually present in plan.md

            READ PATH (frequently missing from Target Files — source of silent bugs):
              1. Zod schema (packages/core or apps/*/src/schemas/) — `safeParse()` strips
                 unknown fields silently; field absent from schema = field never persisted (AP-214)
              2. All service `.select()` calls that fetch the entity — grep `from('<table>')` across
                 apps/ packages/ server/; a select without the field = always `undefined` downstream,
                 causing derived logic (e.g. `hasCriticalProtocol`) to produce wrong results (AP-215)
              3. Detail/edit screens — field saved but not displayed = confusing UX
              4. Migration SQL — field absent in DB = insert/update silently fails

            IF any read-path file is absent from plan.md Target Files:
              → ADD it before proceeding. Do NOT assume the plan is complete because the
                write-path looks correct. Lint and tests will NOT catch this class of error.

            RATIONALE: sprint-010 (`critical_alarm`) had a complete write-path spec but missed
            the Zod schema and two service selects from Target Files. Sub-agents implemented
            exactly what was listed — both gaps caused production bugs (AP-214, AP-215).

          ⚠️ MANDATORY CANONICAL PATH VERIFICATION — for EVERY file listed in deliverables:
            Step 1: Run `find . -name "*FileName*" -type f` to locate the actual file on disk.
            Step 2: If the spec names a function/enum/class, grep for its definition:
                    `grep -rn "function targetFn\|const targetEnum\|class TargetClass" .`
            Step 3: Distinguish DEFINITION from CALLER:
                    - The file that DEFINES a symbol is the correct target.
                    - The file that IMPORTS and CALLS it is NOT the target.
                    - Verifying the caller does NOT count as verifying the definition.
                    - If spec says "update X in file A" but grep shows X is defined in file B:
                      → file B is the correct target. Document the discrepancy before proceeding.
            Step 4: Record the canonical path for each deliverable BEFORE writing any code.
                    A deliverable with an unverified path is BLOCKED — do not proceed.

            RATIONALE: Specs written by humans frequently name the wrong file (caller vs.
            definition). Automated quality gates (lint, tests) will NOT detect this error
            because the code compiles correctly — the missing change simply silences output.
            Path verification is the only reliable method to catch this class of error.

        ACCEPTANCE CRITERIA / DoD:
          - Copy every DoD item and acceptance criterion verbatim into a checklist.
          - Each criterion must be verified at C4 before proceeding to C5.
          - If a criterion is untestable, flag [DEVFLOW: UNVERIFIABLE CRITERION] and
            ask the human how to verify it before proceeding.

        LEGACY SPEC — LAZY PO BACKFILL (pre-v2.1 specs without `po` blocks):
          - Do NOT proactively rewrite the whole spec. Migration is opportunistic, not big-bang
            (strangler fig — the same incremental principle RC3 prescribes for code).
          - Tier 0 legacy spec: never backfill.
          - Tier 1+ legacy spec: for ONLY the AC(s) this session's task actually touches,
            generate a `po` block before C2. AC outside this task's scope stay as-is (leave them
            marked `legacy — no PO`; do not derive proofs for AC nobody will re-execute now).
          - Rationale: a proof is worth writing only if it will be PAID at this session's C4.
            Token cost (your bottleneck) is spent on live work, not dead history.

        RISK FLAGS:
          - Note contracts to create/update, ADRs required, migrations needed.

      A spec read that misses any section is incomplete. Re-read until all sections
      are accounted for. Only proceed to C2 when the full extraction is done.
```

### C1.5 — Artifact Coverage Analysis (Tier 2 MANDATORY; Tier 1 only if risk; Tier 0 skip)

> **The hard-won lesson (liquid-meds 022/023/024, 2026-06):** an `analysis.md` that validates
> the spec's *narrative* instead of the *real repo* is worse than no analysis — it stamps "PASS /
> 100%" on top of critical bugs (an enum that didn't exist, a cap in the wrong file, an insert that
> bypassed the canonical RPC). The format is not the safety; **running it against the code is**.
> An analysis without code evidence is a self-fulfilling rubber stamp. This section is the gate
> that makes the artifact earn its place.

```
Run BEFORE C2 and BEFORE writing code. Tier 2: always. Tier 1: only when C1.5 spots a real risk
(then write a focused analysis.md for it). Tier 0: skip.

Inputs: spec.md, plan.md, tasks.md, checklists/requirements.md, contracts/ (if any),
  .agent/constitution.md, CONTRACTS_INDEX.md, DECISIONS_INDEX.md, rules/APs from bootstrap,
  AND THE REAL REPOSITORY (find / grep / MCP / Read — not memory, not the spec's own claims).

Write output to plans/specs/NNN-feature-name/analysis.md — or, when the epic is SLICED (see
  *Tier 2 is multi-slice* in the core), to analysis-<slice>.md, scoped to THIS slice's target
  files. A root analysis.md from Planning is a skeleton: re-verify against the repo, never
  inherit its PASS. An earlier slice probably moved what it validated.
```

**REALITY CHECK (the non-negotiable core of this gate):**
```
1. EVIDENCE TABLE — required, populated, no PASS without it. For every target file/symbol:
   | Spec claim | Real repo (file:line) | Verified? | Note |
   - "Verified?" = ✅ only after find/grep/Read confirmed it ON DISK. ❌ or UNVERIFIED blocks.
   - The file that DEFINES a symbol is the target, not a caller (re-confirm at C4).
   - Examples of claims that MUST be verified against the repo, not assumed:
       * an enum/CHECK includes a value the spec depends on (e.g. `dosage_unit` has `mg/ml`)
       * a cap/limit lives in the file the spec names (grep the actual `.max(...)`)
       * an RPC/function has the signature the plan calls (read its definition)
       * a column exists with the type/precision the plan assumes (information_schema/MCP)
       * a "new" helper/contract isn't already defined elsewhere (no duplication)

1b. OBTAINABILITY OF THE PROMISED OUTPUT — the table above proves a symbol EXISTS; it does NOT
   prove the deliverable can be PRODUCED. A plan can be 100% ✅ on every symbol it names and still
   promise an output the data cannot yield, because the gap is a capability nobody wrote down.
   For every FR / SC / PO of THIS slice that reads, joins, aggregates or reports data, answer:
   | Promise | Granularity/field it needs | Does the real schema yield it? | Evidence |
   - Is the promised output obtainable from the real schema, AT THE GRANULARITY PROMISED?
     (a per-occurrence alert needs a per-occurrence key: if the table only has a parent id, or
     one row covers N occurrences, the promise is not implementable as written)
   - Does the join the promise needs actually exist — FK, or a column to join ON?
   - Does absence of a row mean what the promise assumes? (early returns, swallowed inserts and
     deliberate skips all produce "no row" without meaning "did not happen")
   A promise that fails here is NOT a task to code: it is a DECISION to take back to the operator
   (approximate, or migrate the schema) and the FR/PO must be rewritten to promise what the chosen
   option delivers. Shipping the query anyway ships a number that answers a different question.

2. CROSS-FILE CONSISTENCY — spec.md ↔ plan.md ↔ tasks.md ↔ analysis.md must AGREE.
   Flag any contradiction (e.g. plan says "insert direct" while analysis says "via RPC").
   Contradiction between artifacts = HIGH at minimum.

3. DATA-MIGRATION COMPLETENESS — if a schema/enum/format/unit changes, there MUST be an
   explicit migration deliverable for existing rows (and a verification query). A format change
   without a data migration is a CRITICAL gap (legacy rows silently orphaned).

4. COVERAGE — every FR→task; every SC→C4 check; every P1/P2 story→independent test;
   every deliverable→task; every touched interface→CON-NNN (or new ADR if breaking).

5. BEHAVIORAL FAILURE MODES — required table for every NEW or CHANGED function/RPC/handler.
   Structure verification (items 1-4) proves a symbol EXISTS and matches the repo; it does NOT
   prove the symbol is ROBUST. An external reviewer catches the second class by instinct — encode
   it so the gate catches it without one. For each function, enumerate the degenerate inputs and
   the expected behavior BEFORE coding:
   | Input / condition | Degenerate value | Expected behavior | Covered (test)? |
   - every nullable arg → NULL
   - every divisor / denominator → 0 and NULL
   - quantities/amounts that round or truncate → 0 (silent no-op risk)
   - every optional JOIN/FK/lookup → missing row (e.g. parent id NULL)
   - every finite-domain field → out-of-set / wrong-case value (needs CHECK/enum guard)
   - boundaries → min / max / empty / negative
   - every monetary/ratio split (`total / n`) → cent-limit where rounding-up exceeds the total
     → truncate (floor), make the last slice absorb a non-negative residue (never a negative price)
   - every optional numeric form field with coercion (`z.coerce.number`) → empty string `''`
     (cleared field) → preprocess `'' => null`; coercion must NOT turn `''` into `0` and fail `.positive()`
   - every localized numeric string → decimal comma (`'1,0'`) → normalize `,`→`.` before `Number()`
     (else `NaN` breaks comparisons/plural)
   - language footguns → e.g. SQL 3-valued logic (`col != x` excludes NULL), float rounding,
     off-by-one. (Stack-specific checklist lives in a project rule, e.g. dosiq R-270 for DB+Zod.)
   A NEW function with an empty failure-mode table is suspect — re-derive it.
   Each row's "Covered?" MUST map to a negative-path test at C4 (not just happy-path).

   USE THE PROJECT'S OWN FAILURE-MODE MANAGEMENT IF IT HAS ONE: if the project maintains an
   internal catalog of failure modes / degenerate inputs / change-preflight (a dedicated rule,
   an AP catalog, a preflight template, a checklist), LOAD IT and treat it as the authoritative
   source for this table — extend the rows above with the project's documented modes rather than
   only the generic ones. This generic list is the floor when the project has no such catalog;
   the project's catalog is the ceiling when it does. (Same principle RC-SEC applies to security.)
```

**Honesty rules (anti-rubber-stamp):**
```
- NEVER write "PASS / 100% / perfeito / nenhum gap" unless the Evidence Table is fully ✅
  AND cross-file consistency holds. A confident PASS over unverified claims is a CRITICAL
  PROCESS FAILURE, not a pass.
- Prefer finding gaps. A first-pass analysis that finds zero gaps on a Tier 2 epic is
  suspect — re-run against the repo before declaring PASS.
- Record resolved gaps with IDs + the evidence that resolved them (don't delete history).
```

```
Severity:
  CRITICAL: constitution conflict; breaking contract w/o accepted ADR; missing task for a
            baseline FR; format/enum/schema change without data migration; target path
            unverified/wrong; cross-file contradiction on a core flow.
  HIGH: ambiguous security/perf requirement; acceptance criterion without verification;
        cap/limit/contract targeted at the wrong file; checklist blocker.
  MEDIUM: terminology drift; weak NFR coverage; task-ordering risk.
  LOW: wording/style/process.

Gate behavior:
  CRITICAL or HIGH present → STOP before C2, report `[DEVFLOW: ARTIFACT ANALYSIS BLOCKED]`.
  Only MEDIUM/LOW → continue to C2 with risks listed in analysis.md.
```

### C2 — Contract Gateway
```
For each file to be modified:
  Grep CONTRACTS_INDEX.md for the file name or its exports.
  IF a contract covers this interface:
    IF change is breaking → HALT
                         → Draft ADR-NNN in DECISIONS_INDEX.md (status: "proposed")
                         → Create decisions/[category]/ADR-NNN.md
                         → Report to human: "Breaking change on CON-NNN. ADR-NNN drafted. Awaiting approval."
                         → Do NOT proceed until ADR status = "accepted"
    IF change is non-breaking (additive, optional fields only) → continue to gate below

[CEREMONY COVERAGE CHECK — audit, do NOT auto-run anything (R-065 HITL invariant)]
This enforces ceremonies by *surfacing a gap*, never by executing them. Two triggers:

  A. TIER AUDIT (static): read state.json.session.ceremonies_run.
     - Tier 2 with zero ceremonies run → WARN: "Tier 2 with no engineering review — run /devflow eng-review before C3?"
     - Plan touches a security/data surface (auth, schema/migration, RLS/policy, grant, secret, PII,
       external input, privileged function) AND RC-SEC not in ceremonies_run → WARN: "Security surface
       touched, no security-review — run /devflow security-review?"
     - UI surface + no design-review, or dev-facing surface + no devex-review → WARN likewise.

  B. DIVERGENCE TRIGGER (dynamic — reality diverged from the plan): if, since the spec/ceremonies were done,
     any of these emerged → HALT and suggest re-running the matching ceremony before continuing:
       - Tier upgraded (e.g. a "small fix" revealed a needed migration → 1→2) → suggest eng-review (+ security-review if data).
       - A contract broke that the spec didn't anticipate → suggest eng-review on the contract change.
       - A new security/data surface appeared that wasn't in scope → suggest security-review.
       - Blast radius exceeded what the spec assumed (files/systems beyond plan) → suggest ceo-review/eng-review.

  Enforcement = mandatory STOP + suggestion; the operator decides whether to run the ceremony or proceed.
  Do NOT trigger on Tier 0/1 work proceeding as planned — that is bloat. Triggers fire on gap or divergence only.

[C2 GATE — always fires after contract check passes, breaking or non-breaking]
Output this summary, then STOP and await go-ahead:

  ╔══ DEVFLOW C2 GATE ══════════════════════════════╗
  ║ Tier              : [0 / 1 / 2] (slice's own)    ║
  ║ Spec dir          : [plans/specs/... or "none"]  ║
  ║ Slice             : [id + scope (FR/tasks), n/a] ║
  ║ Artifact analysis : [file · date · PASS/risks/BLOCKED] ║
  ║                     (a verdict from another slice is n/a, not PASS) ║
  ║ Reality check     : [evidence table ✅ / n/a]    ║
  ║ Files to modify   : [list of files]             ║
  ║ Contracts touched : [CON-NNN list or "none"]    ║
  ║ Rules to apply    : [top R-NNN relevant to task]║
  ║ Watch-for AP-NNN  : [top AP-NNN relevant]       ║
  ║ Ceremony coverage : [ok / gaps / divergence]    ║
  ║ Tasks source      : [tasks.md / TodoWrite only] ║
  ║ C3 order          : [brief implementation seq]  ║
  ║ C4 quality gates  : [lint / test / build cmds]  ║
  ╚═════════════════════════════════════════════════╝

  → Awaiting go-ahead. Options:

      "go" → Update state.json: session.status = "coding"
             IF tasks.md exists:
               - Read tasks.md as the durable task source
               - Mirror tasks into TodoWrite before writing code
               - Update tasks.md at persistent checkpoints
             ELSE:
               IMMEDIATELY create a TodoWrite task list before writing any code:
                 - One task per deliverable from the C1 spec extraction (core + peripheral)
                 - One task per acceptance criterion / DoD item to verify at C4
                 - One task per C4 quality gate (lint, test, build)
                 - One task per C5 post-code step (AP/R/ADR memory update, journal, state.json)
             Mark each task complete immediately when finished — never batch completions.
             TodoWrite is runtime context; tasks.md is durable context when present.
             Then DEVFLOW proceeds to C3 → C4 → C5

      /deliver-sprint → Update state.json: session.status = "coding"
                        Create TodoWrite task list from tasks.md when present; otherwise same
                        structure as "go" above.
                        Hand off C3/C4 to /deliver-sprint; DEVFLOW resumes at C5

      "stop" → Update state.json: session.status = "halted"
               Abort session, preserve all changes in state.json and git working tree
```

### C3 — Implementation Order
```
Follow this order when touching multiple layers:
  1. Schemas (src/schemas/ or equivalent) — define data contracts first
  2. Services (feature services, shared services) — business logic
  3. Components (feature components) — UI
  4. Views / pages — orchestration
  5. Tests — coverage
  6. Styles — isolated last

Apply all relevant R-NNN rules during implementation.
Check anti-patterns before each significant operation.
```

### C4 — Quality Gates
```
CRITICAL: Run lint BEFORE each git commit during C3 implementation, not only as a final gate.
  A commit with lint errors forces a fixup commit that pollutes git history and breaks CI.
  Sequence: implement → lint → fix lint → commit. Repeat per logical unit.

Run project-specific quality commands (from state.json or knowledge.json):
  Lint:   [project lint command]
  Tests:  [project test command for changed files]
  Build:  [project build command if applicable]

Verify R-221 SQP release evidence independently from lint/tests:
  - platform(s) identified
  - SemVer impact recorded
  - version source(s) updated when impact is not no-user-impact
  - CHANGELOG.md [Unreleased] updated in Portuguese
  - mobile store-note relevance recorded when Mobile is affected

CLOSE EVERY PROOF OBLIGATION (Tier 1+). For each `po` block of the task whose status is `[ ] open`:
  1. Run its `proof:` command (or perform the `MANUAL —` action).
  2. Paste the actual output into the transcript.
  3. Confirm the output shows `expect:`.
  4. Run the `guard:` check and confirm no regression at the tier's required level.
  5. ONLY THEN flip `status: [x] done`.
  The turn does NOT close while any PO is still `[ ] open`. `[x]` without pasted evidence is a
  protocol violation — it is the exact prematurely-"done" failure POs exist to prevent.
  MANUAL POs require concrete pasted evidence too (screenshot/curl/output), not just a claim.

Verify every acceptance criterion and DoD item extracted in C1 spec read.
All gates must pass AND all DoD items must be checked before proceeding to C5.

⚠️ DoD VERIFICATION IS MANDATORY AND INDEPENDENT FROM LINT/TESTS.
  "Tests pass and lint is clean" does NOT mean DoD is complete. Both conditions
  must be satisfied independently. Lint passing with a missing implementation is
  still a failed DoD.

  FILE-BY-FILE DoD VERIFICATION — for EACH file listed in spec deliverables:
    1. Open the file with the Read tool (not grep, not memory, not assumption).
    2. Locate the specific function, schema, enum, switch-case, or class from the spec.
    3. Confirm the change is present at the DEFINITION file (see C1 canonical path).
       Confirming the caller is NOT sufficient.
    4. Cite the exact line number and code excerpt that satisfies the criterion.
       Example: "targetEnum at line 12 now includes 'new_value' ✓"
    5. If the change is NOT present: HALT. Do not proceed to C5.
       Implement the missing change, re-run quality gates, then re-verify.

  WHY FILE-BY-FILE MATTERS:
    Silent failure patterns (try/catch returning {success:false}, enum rejection,
    missing case in switch) will NOT surface in lint or unit tests when mocks are used.
    The only way to confirm a change was made is to read the file and see it.
    "I checked the file and it looked OK" is not verification — cite the line.
```

### C5 — Post-Code Protocol (mandatory — do not skip)

Execute this checklist IN ORDER:

```
  [ ] 1. New bug found and fixed?
      → FIRST search for an EXISTING pattern of the same CLASS, then decide increment-vs-coin:
          a. Run the project's class search over the memory index (e.g. dosiq:
             `node scripts/recount-memory.mjs --find-similar "<one-line description of the bug>"`).
             No such tool in this project? Then `grep` the index for the words that name the
             MECHANISM, not the surface (search "gate reports success without running", not the
             file name).
          b. Vary the terms at least once. These searches match TERMS over title/summary/keywords —
             they are NOT semantic. Measured on dosiq 2026-09-04: the paraphrase
             "fixture written by the author carries the premise" did NOT return AP-346, the exact
             parent, coined the day before, because its title says "paired patterns" and not
             "fixture". NOT MATCHING IS THEREFORE NOT PROOF OF A NEW CLASS — it is a first pass.
          c. Matched? → INCREMENT: append a dated amendment to the existing AP (what THIS instance
             adds to the rule) + update its index line. Do NOT coin a sibling ID.
          d. No match after varying terms? → coin AP-NNN in ANTI_PATTERNS_INDEX.md +
             anti-patterns/[cat]/AP-NNN.md, checking the ID against the index ON DISK (AP-343).
      → The journal entry MUST record the TERMS used and the outcome (matched <ID> / no match).
        A new AP with no such line in the journal is a GATE VIOLATION, not an oversight: without
        the terms nobody can tell a real search from a claimed one — and "searched, found nothing"
        is exactly the shape of a step that never ran (AP-325 family).
      ⚠️ PREREQUISITE — the search is only as fresh as the compiled index. If the project keeps a
        compiled memory index, re-run its freshness gate (dosiq:
        `node scripts/compile-memory-index.mjs --check`; exit != 0 means recompile) and recompile
        BEFORE searching. Memory coined in THIS session is the most likely to match the next bug
        and is precisely what a stale index cannot see (R-289 class: the source moved, the derived
        artifact did not). Note that a legitimate gap remains after recompiling: entries with
        status archived/superseded are excluded BY DESIGN (dosiq 2026-09-04: 611 on disk, 573 in
        the index, the 38 being archived) — that difference is not staleness, do not "fix" it.
  [ ] 1b. SOMETHING TRIED, MEASURED AND REVERTED? → append an entry to the attempts ledger.
      This is the SYMMETRIC step to item 1: the protocol has a path for what WORKED (AP / R / ADR /
      CON) and, until now, none for "I tried it, I measured it, it did not work, I reverted it".
      Without it the next session re-implements the same rejected intervention under another name,
      measures it again, reverts it again — and no gate complains (measured on dosiq: the two
      rejected rankings of spec 060 produced ZERO AP and ZERO R, and lived only in a `state.json`
      note whose own header orders it deleted).
        a. One line per INTERVENTION (not per defect), with the NUMBER measured, the BASELINE it was
           measured against, the CAUSE it fell, the SHA (or an explicit `trace` when the revert never
           became a commit — declaring absent provenance beats inventing it), and `terms` written on
           purpose so someone else's search actually finds it. `verdict` also admits `accepted`:
           without the denominator of accepted attempts the rejection rate means nothing.
        b. If the project ships a ledger tool, use it (dosiq:
           `node scripts/attempts.mjs --add '<json>'`, then `--check`, whose exit code MUST be read
           WITHOUT a pipe). Otherwise append to `.agent/memory/attempts.jsonl` by hand.
        c. Write the entry in a commit SEPARATE from the intervention itself. An entry born in the
           same commit dies in that commit's `git revert` — the memory would roll back together with
           the code, which is exactly what this step exists to prevent.
      ⚠️ Where a gate can and cannot help: `--check` cross-references the `git log` reverts and
      fails on any that has no entry, so REVERTING BY COMMIT without registering is impossible. A
      revert done in the WORKING TREE, before any commit, leaves no trace in git — for that case
      this checklist step is the only mechanism. Declared limit, not an oversight.
  [ ] 2. New pattern discovered? → Add R-NNN to RULES_INDEX.md + rules/[cat]/R-NNN.md
  [ ] 3. Contract updated? → Update CONTRACTS_INDEX.md (CON-NNN) + contracts/[cat]/CON-NNN.md
  [ ] 4. Architectural decision made? → DECISIONS_INDEX.md ADR-NNN (status: "accepted") + detail file
  [ ] 4b. ARTIFACT TRUTH RECONCILIATION (Tier 1+) — what the implementation DISPROVED gets fixed
      where it is USED, in THIS commit. Implementation is the only thing that can refute a
      planning artifact; when it does, the artifact becomes a trap for whoever reads it next.
      ⚠️ An appendix of corrections with the body left contradicting it is NOT this step. It is
      worse than nothing: it forces the next reader to hold two versions and pick, and a
      "the appendix wins" note is a patch, not a design. The body is the canonical doc — fix it.
        a. Rewrite the premise AT ITS POINT OF USE: the FR/SC/PO in spec.md, the section in
           plan.md, the row in the Target Files table, the task in tasks.md. A requirement that
           became unachievable is REWRITTEN to promise what IS achievable, or marked blocked on a
           NAMED decision. It is never left asserting the impossible.
        b. Annotate the artifact that asserted it, IN PLACE, with the date — including a
           **ceremony finding**. Ceremony sections are append-only by design, so a refuted finding
           stays wrong forever unless the correction sits next to it. The dangerous case is the
           finding whose CONCLUSION was right and MECHANISM wrong: verifying the conclusion
           CONFIRMS it, so nobody re-derives the mechanism, and the fix lands on the wrong line.
        c. Keep a short record-of-corrections section: what was wrong or missing · how it was
           verified · where the correction now lives. Its header must say it is HISTORY, not the
           source of truth.
        d. Re-validate `checklists/requirements.md`: UN-CHECK every item that stopped being true
           and name why. An all-green checklist over a requirement that became unachievable
           asserts a review that did not happen (AP-325 class) — a stale ✅ outranks an open box
           in how much damage it does.
      A slice that refuted nothing writes nothing here. Silence is valid; a stale ✅ is not.
  [ ] 5. Acquire lock → update relevant index files → release lock (see Locking Protocol)

  [ ] 6. Append to events.jsonl:
      {timestamp, event: "coding_complete", files: [...], rules_applied: [...], aps_triggered: [...]}

  [ ] 7. Write journal entry to memory/journal/YYYY-WWW.jsonl
      Include R-221 SQP release log for code-changing work:
        - affected platform(s)
        - SemVer impact
        - old/new version(s), or no-user-impact justification
        - CHANGELOG.md entry summary
        - store-note relevance for mobile changes

  [ ] 8. UPDATE state.json (FINAL STEP — DO NOT SKIP):
      ✅ Set session.status = "completed"
      ✅ Increment memory.journal_entries_since_distillation
      ✅ Update quality_gates.index_loaded_at = now
      ✅ Write to disk and verify

  [ ] 9. IF journal_entries_since_distillation >= genes.memory_distillation_threshold
      → trigger Distillation Mode
```

### Integration with /deliver-sprint
```
BEFORE /deliver-sprint: run DEVFLOW Bootstrap (phases 0 + C1 + C2)
DURING /deliver-sprint: follow C3 + C4 as implementation constraints
AFTER /deliver-sprint:  run DEVFLOW C5 (Post-Code Protocol — memory update)

If /deliver-sprint is not available, follow C1-C5 directly.
```

---

## Mode: Reviewing

**Purpose:** Analyze code changes against memory constraints. Update memory with findings.

### R0 — State Transition to Reviewing

Immediately update state.json:

```json
{
  "session": {
    "mode": "reviewing",
    "status": "reviewing",
    "goal": "<PR number or branch name being reviewed>"
  }
}
```

### R1 — Load Review Context & RC5 Pre-Landing Code Review

**Context:** The Gemini Code Assist GitHub reviewer is being retired. RC5 absorbs its checklist and fix-first protocol as a local, pre-push ceremony to prevent regressions. The advantage: the agent that wrote the code already has the full context — no cold-start, no repo re-read. Review the diff only.

```
Load: RULES_INDEX.md, ANTI_PATTERNS_INDEX.md, CONTRACTS_INDEX.md, DECISIONS_INDEX.md
For rules/APs:
  - always include `hot`
  - include `warm` matching the PR scope, changed files, tags, and stack
  - exclude `cold` unless the review requires historical investigation
For rules/APs/contracts relevant to the PR scope: load their detail files
```

**RC5 Execution (Tier 1+ only; skip on Tier 0):**

Compute the diff against the base branch (`git diff $(git merge-base HEAD main)`) and run Pass 0 (PO audit) then the Pass 1 CRITICAL checklist. Pass 2 (Informational) remains reserved for a future version — do NOT run it even on Tier 2 (it was NOT enabled in v2.1).

RC5 is also invocable standalone: `/devflow code-review` (runs without requiring the full Reviewing mode cycle).

#### Pass 0 — Proof Obligation Audit (Tier 1+, run FIRST)

Before judging quality, verify the proofs exist. This is mechanical and cheap — a weak model can
do it without architectural judgment:

```
0. Establish the SCOPE first: the POs this slice OWNS (`slice:` field, or the slice's row in the
   spec's slice table). POs owned by a later slice are OUT of scope here — auditing them would
   reject every slice of every sliced epic, which is how a gate teaches the agent to skip it.
   Unsliced spec ⇒ scope is every PO.
1. `rtk grep '```po' <spec files>` → list the POs IN SCOPE.
2. For each in-scope PO: is status `[x] done`? If any is still `[ ] open`, the work is INCOMPLETE — reject, return to C4.
3. For each `[x]`: is there pasted evidence in the transcript showing `expect:`? A `[x]` with no
   evidence is "affirmed, not demonstrated" — treat as a critical finding, return to C4.
4. MANUAL POs: scrutinize harder — the evidence is human-judged, so confirm it actually shows the claim.
5. Confirm each PO's `guard:` ran and showed no regression at the tier level.
```

Only after every IN-SCOPE PO is demonstrated (not merely claimed) proceed to Pass 1 quality review.

#### Pass 1 — CRITICAL Checklist

> **Checklist is stack-agnostic BY DESIGN.** The bullets below name bug CLASSES with
> illustrative examples from various stacks — the examples teach the shape of the bug, they
> are NOT an allowlist of what to look for. Concrete, project-specific instances come from
> item 6 (Domain Rule Conformance), which materializes them from the PROJECT's own catalogs
> loaded in R1. Do not hardcode any single project's stack here.

**1. SQL & Data Safety:**
- String interpolation in SQL (even if values look numeric — use parameterized queries)
- TOCTOU races: check-then-set patterns that should be a single atomic conditional write
- Bypassing the project's validation/service layer for direct DB writes (e.g. Rails `update_column`, Prisma raw queries, calling the DB client directly from UI code when a service owns that table)
- N+1 queries: missing eager loading / batched fetch for associations used in loops/views

**2. Race Conditions & Concurrency:**
- Read-check-write without uniqueness constraint or duplicate key error handling
- find-or-create without unique DB index — concurrent calls can create duplicates
- Status transitions that don't use atomic `WHERE old_status = ? UPDATE SET new_status`
- Unsafe HTML rendering (`dangerouslySetInnerHTML`, `v-html`, `.html_safe`) on user-controlled data (XSS)

**3. LLM Output Trust Boundary:**
- LLM-generated values (emails, URLs, names) written to DB without format validation — add guards (`EMAIL_REGEXP`, `URI.parse`, `.strip`)
- Structured tool output (arrays, hashes) accepted without type/shape checks before database writes
- LLM-generated URLs fetched without allowlist — SSRF risk if URL points to internal network
- LLM output stored in knowledge bases without sanitization — stored prompt injection risk

**4. Shell Injection:**
- `subprocess.run()` / `Popen()` with `shell=True` AND f-string interpolation — use argument arrays
- `os.system()` with variable interpolation — replace with `subprocess.run()` + argument arrays
- `eval()` / `exec()` on LLM-generated code without sandboxing

**5. Enum & Value Completeness:**
When the diff introduces a new enum value, status string, tier name, or type constant:
- **Trace it through every consumer.** Read (don't just grep — READ) each file that switches on, filters by, or displays that value. If any consumer doesn't handle the new value, flag it.
- **Check allowlists/filter arrays.** Search for arrays containing sibling values and verify the new value is included.
- **Check `case`/`if-elsif` chains.** If existing code branches on the enum, does the new value fall through to a wrong default?

**6. Domain Rule Conformance (project-sourced — this is where the project's stack enters):**
The catalogs loaded in R1 (project `CLAUDE.md` critical-rules section, `hot`/`warm` R-NNN and
AP-NNN, contracts) ARE the concrete checklist for this project. For EACH changed hunk:
- Map it against the loaded rules/APs and **cite the id** (`R-NNN`/`AP-NNN`/`CON-NNN`) when
  flagging — a finding grounded in the project's own catalog outranks a generic hunch.
- Pay special attention to the classes that generic linters/reviewers miss because they are
  project contracts, not language errors: domain value semantics (units, enum values that must
  match DB CHECK constraints verbatim), mandated call order between operations, date/timezone
  handling rules, and which layer is allowed to write which table.
- If a hunk touches a domain the catalog covers, review it AGAINST the catalog, not from
  first principles.

Optional per-project overlay: if `.agent/memory/rc5-domain.md` exists, load it as additional
Pass 1 items — projects use it for worked examples too verbose for their rule index. Absence
is normal (the indexes alone are sufficient).

#### Verification of Claims (Anti-Rationalization Rules)

These prevent the agent from rationalizing away real issues:
- If claiming "this pattern is safe" → cite the specific line proving safety
- If claiming "this is handled elsewhere" → read and cite the handling code
- If claiming "tests cover this" → name the test file and method
- NEVER say "likely handled" or "probably tested" — verify or flag as unknown

#### Fix-First Protocol

This heuristic determines what is auto-fixed vs what requires operator judgment:

```
AUTO-FIX (agent fixes without asking):     ASK (needs human judgment):
├─ Dead code / unused variables            ├─ Security (auth, XSS, injection)
├─ N+1 queries (missing eager loading)     ├─ Race conditions
├─ Stale comments contradicting code       ├─ Design decisions
├─ Magic numbers → named constants         ├─ Large fixes (>20 lines)
├─ Missing LLM output validation           ├─ Enum completeness
├─ Version/path mismatches                 ├─ Removing functionality
├─ Variables assigned but never read       └─ Anything changing user-visible
└─ Inline styles, O(n*m) view lookups        behavior
```

**Rule of thumb:** If the fix is mechanical and a senior engineer would apply it without discussion → AUTO-FIX. If reasonable engineers could disagree about the fix → ASK.
**Critical findings default toward ASK** (they're inherently riskier).
**Informational findings default toward AUTO-FIX** (they're more mechanical).

#### Suppressions — DO NOT flag

- Redundancy that is harmless and aids readability
- "Add a comment explaining why this threshold was chosen" — thresholds change, comments rot
- "This assertion could be tighter" when it already covers the behavior
- Consistency-only changes (e.g., wrapping a value in a conditional to match another constant)
- Regex edge cases on constrained inputs where the edge case never occurs in practice
- Tests that exercise multiple guards simultaneously — that's fine
- Eval threshold changes tuned empirically
- ANYTHING already addressed in the diff being reviewed — read the FULL diff before commenting

#### Specialists Dispatch (Conditional on /cavecrew)

```
IF `/cavecrew` skill exists in the local environment:
  → Spawn cavecrew-investigator for each specialist:
    1. Testing specialist: detect coverage gaps that CI doesn't catch
    2. Security specialist: deeper analysis complementing Pass 1 CRITICAL
    3. Performance specialist: bundle impact and N+1 in views
  → Output comes back compressed (~60% smaller via caveman compression)
  → Consolidate findings into the RC5 output
ELSE:
  → List the 3 categories as reference for operator manual review
  → Do NOT block RC5 — primary review continues normally
```

#### RC5 Output Format

```
Pre-Landing Review: N issues (X critical)

**AUTO-FIXED:**
- [file:line] Problem → fix applied

**NEEDS INPUT:**
- [file:line] Problem description
  Recommended fix: suggested fix
```

If no issues found: `Pre-Landing Review: No issues found.`
Be terse. For each issue: one line for the problem, one line for the fix. No preamble, no summaries, no "looks good overall."

#### RC5 State & Events

- Update `state.json`: `"code_review": {"status": "clean|issues_found", "critical": N, "auto_fixed": N, "ask_items": N}`
- Append to `events.jsonl`: `{"event": "code_review_complete", "critical": N, "auto_fixed": N, "ask_items": N, "specialists_dispatched": bool}`
- If findings are recurrent (>2x in same project) → propose AP-NNN to operator
- Write journal entry with review summary

If there are ASK items → STOP and await operator decision. (Do not proceed to R2).

### RC6 — Independent AI Review (`/devflow ai-review`)

**Context:** RC5 is the *author* reviewing their own diff — strong for fix-first cleanup, but it is **not independent** (same agent, same context, same blind spots). When the Gemini GitHub reviewer retires, the property that disappears is the *independent second opinion on the PR*. RC6 restores exactly that property and nothing else. **RC5 and RC6 are complementary, not redundant:** RC5 = self-check before PR (in-context, fix-first); RC6 = independent gate on the PR (fresh context, flag-only).

**Invocation:** Solo, forceable at any time: `/devflow ai-review [<PR#>]`. Recommended trigger: after the PR is opened (manual `rtk ai-review <PR#>` or a local `post-push` hook). Tier 1+ (skip Tier 0).

**Independence is the whole point — enforce it by construction:**
- Run in a **fresh headless process**, NOT in the coding agent's session. Do **not** pass the coder's chat history, reasoning, or "what I intended" — only the diff + the rule catalogs. Cold-start is the feature, not a cost.
- Engine (OAuth quota, **$0 marginal** — no metered API):
  - **Primary: `agy -p` (Gemini 3.8 Flash)** — larger weekly quota, absorbs routine volume.
  - **Fallback / escalation: `claude -p` (Opus 4.8 / Sonnet 4.6)** — stronger reasoning; use on architectural PRs or when `agy -p` is unavailable/weak.

**Execution:**
```
1. Diff:    git diff $(git merge-base HEAD main)...HEAD, filtered to code files (.js/.jsx/.ts/.tsx).
2. Context: attach, in this order:
              a. CLAUDE.md — HOIST its "Regras Críticas" section to the TOP; the per-hunk rule mapping
                 in the Extensions (step 3) depends on the reviewer seeing these rules first.
              b. RULES_INDEX.md + ANTI_PATTERNS_INDEX.md — load the R-NNN / AP-NNN detail files whose
                 scope matches the changed files (e.g. AP-216 when Supabase auth / `{data,error}` is touched).
              c. FULL file content (NOT just the diff hunk) for every file whose diff changes control flow,
                 arithmetic, date/time handling, or exceeds ~20 changed lines. Diff-only context is RC6's
                 #1 blind spot — latent bugs routinely live in the unchanged lines next to a change
                 (RC6 field note 2026-07: the HeroDoseCard timezone bug was missed for exactly this reason).
              ~100-150KB ≈ 25-40K tokens — fits; model self-filters, no RAG/embeddings needed.
3. Prompt:  REUSE the RC5 "Pass 1 — CRITICAL Checklist" + "Verification of Claims (Anti-Rationalization)"
            + "Suppressions" verbatim, THEN append the "RC6 Reviewer Extensions" below. Add: "You are an
            INDEPENDENT auditor. You did NOT write this code and have no context beyond the diff + files +
            catalogs below. Audit against the CRITICAL checklist + the RC6 Extensions + the listed
            R-NNN / AP-NNN. Do not invent rules. Output strict JSON per the schema below."
4. Spawn:   TIER-SCALED (see "RC6 Passes" below) — not always a single pass. Parse JSON → merge/dedupe.
5. Publish: post inline comments on the PR via `gh api` (reuse the gemini-review.yml ingestion pipeline
            with GEMINI_BOT_LOGIN swapped). Severity tags as Gemini did (critical/high/medium/low).
```

#### RC6 Reviewer Extensions (append to the reused RC5 checklist)

These close the gaps found when RC6 was benchmarked against the retiring Gemini reviewer (PR #721, 2026-07).

**6. Language & Framework Footguns** — do NOT suppress these as "style"; they are correctness:
- **ASI (Automatic Semicolon Insertion) hazards:** a line beginning with `(` or `[` after a mock cast —
  e.g. `(x as jest.Mock)` / `(x as unknown as Mock)` — can silently merge with the previous statement.
  Require `jest.mocked(x)` instead.
- **Floating promises** — an un-awaited async call whose rejection is silently lost.
- **`as any` on an I/O or parse boundary** (Supabase `{ data, error }`, `JSON.parse`, network response) —
  hides the AP-216 null-destructure crash class. Flag and suggest a typed guard, not a blanket cast.
- **Missing defensive default** on a destructured prop later consumed via `.length`, index, or spread
  (e.g. `function F({ doses })` then `doses.length` → require `doses = []`).

**7. Domain Rule Conformance** — the project catalogs in the assembled context (project `CLAUDE.md`
critical-rules section + rule/AP indexes) ARE the concrete checklist. For EACH changed hunk, map it
against them and cite the rule id/name in the finding. Weight highest the classes generic review
misses because they are project contracts, not language errors:
- **Date/timezone handling rules** (e.g. a date-only string parsed as UTC midnight shifting a day in
  the user's timezone — the class RC6 once missed on a dashboard card precisely because it reviewed
  diff-only without the project's date rules in context).
- **Schema ↔ DB-constraint sync** (validation-layer enum/nullable rules must match the DB CHECK
  constraints verbatim — value, accent, case).
- **Domain value semantics and mandated call order** (units a field is denominated in; operations the
  project requires in a fixed sequence; which layer may write which table).

**8. Migration / Refactor Audit** — when the PR renames+edits (e.g. `.js → .ts`) or refactors:
- For each touched function, compare OLD vs NEW semantics. Flag ANY changed arithmetic, conditional,
  argument, or default — even one that "looks equivalent" — and state explicitly whether runtime behavior
  is preserved. (`a - b` vs `a.getTime() - b.getTime()` IS preserved; a *dropped argument* is preserved
  ONLY if the callee provably ignores it — verify by reading the callee, do not assume.)

**Causation discipline (RC6's edge over a hunk-only reviewer):**
Before asserting "change X causes bug Y", OPEN and read the definition of every symbol in the changed
expression and cite the exact line proving the mechanism. If the callee ignores the changed argument, say
so and reclassify the finding as **pre-existing** (present with OR without the diff). A hunk-only reviewer
mis-attributes latent bugs to the PR and proposes fixes that don't actually work (Gemini on PR #721 did
both on DoseListItem) — RC6 must not. Every finding MUST set `"introduced"` and `"causation"`.

**Output schema (strict JSON):**
```json
{
  "summary": "one paragraph",
  "findings": [{
    "file": "path", "line": 123, "severity": "critical|high|medium|low",
    "introduced": true,
    "rule": "R-NNN | AP-NNN | checklist#6 | none",
    "causation": "mechanism + the exact line/definition that proves it",
    "issue": "what is wrong", "fix": "concrete fix"
  }]
}
```

#### RC6 Passes (tier-scaled, multi-agent)

Cost is $0 (OAuth), so extra passes are cheap — scale by risk:
- **Tier 1** (small diff, no logic/migration): single pass — `agy` generalist vs CRITICAL + Extensions.
- **Tier 2 / migration / logic-preserving PR:** TWO passes, UNION the findings:
    - **Pass A** — `agy` generalist vs CRITICAL checklist + Extension #6 (footguns).
    - **Pass B** — domain-rule specialist vs Extensions #7/#8, with FULL-file context. Run on `claude -p`
      (Opus/Sonnet, stronger reasoning) for migration/architectural PRs; `agy` otherwise.
    - Merge + dedupe by (file, line, issue-class); keep the higher severity on collision.
- If `/cavecrew` exists locally, optionally fan Pass B into specialists (timezone, concurrency,
  test-quality) per §1493.

**No auto-fix.** Unlike RC5, RC6 **only flags** — an independent reviewer that also rewrites the code reintroduces the author-bias it exists to avoid. The coding agent applies fixes afterward (its own RC5/`check-review` cycle), then re-runs RC6 on the new diff.

**Enforcement without paying for API:** the LLM runs locally on OAuth ($0); a tiny CI job (`ai-review-gate.yml`, **no LLM**) audits that an RC6 comment exists on the PR before merge is allowed. Recovers the non-bypassable property of a CI reviewer at ~zero CI cost. The human gate (R-060) remains final.

**Fail-open:** if `agy -p` and `claude -p` are both unavailable or quota is exhausted, emit `⚠️ AI review unavailable — human review mandatory` and exit non-blocking. Never trap the push/merge permanently.

**State & events:**
- Update `state.json`: `"ai_review": {"engine": "agy|claude|agy+claude", "status": "clean|issues_found", "critical": N, "high": N, "introduced_critical": N, "introduced_high": N, "pr": <num>}`
- Append to `events.jsonl`: `{"event": "ai_review_complete", "engine": "...", "critical": N, "high": N, "introduced": N, "pr": <num>}`
- If a finding recurs (>2x same project) → propose AP-NNN to operator (same as RC5).

If RC6 reports Critical/High with `introduced:true` → STOP and await operator decision (do not auto-fix,
do not proceed). Findings with `introduced:false` (pre-existing latent bugs surfaced in touched code) are
reported for triage but do NOT block THIS PR's merge — log them for a separate fix so the merge gate keys
on regressions, not on debt the PR merely stood next to.

### R2 — Violation Scan
```
For each changed file:
  Check ANTI_PATTERNS_INDEX.md: does the change exhibit any AP-NNN pattern?
  Check CONTRACTS_INDEX.md: does the change modify any CON-NNN interface?
  Check DECISIONS_INDEX.md: does the change contradict any accepted ADR?
  Check RULES_INDEX.md: does the change fail to apply any relevant R-NNN?
```

### R3 — Severity Classification
```
CRITICAL: Contract violation without ADR, or change contradicts an accepted ADR
HIGH:     Anti-pattern AP-NNN triggered
MEDIUM:   Rule not followed (no incident yet, just omission)
LOW:      Style or verbosity concerns
```

### R4 — Memory Update
```
For each triggered AP-NNN:
  Acquire lock → increment trigger_count in ANTI_PATTERNS_INDEX.md → release lock
For new violations not in existing AP-NNN: propose new AP-NNN (add to index + create detail file)
For patterns done correctly: note in journal as positive signal
Append to events.jsonl: {event: "review_complete", violations: [...], compliant: [...]}
```

### R5 — Review Output & State Update
```
Produce structured review:
  CRITICAL issues (must fix before merge)
  HIGH issues (should fix)
  MEDIUM issues (consider fixing)
  Memory updates made
  Rules well-applied (positive signal)

Update state.json: session.status = "reviewed"
Write journal entry to memory/journal/YYYY-WWW.jsonl with findings summary
```

STOP. Awaiting merge decision.

### Integration with /check-review
```
/check-review  → technical code review (syntax, logic, security, style)
DEVFLOW review → memory sync: which rules were followed/violated?
                             → lifecycle update (trigger_count, incident_count)
                             → new AP-NNN proposals if new patterns found

Workflow: run /check-review first → then run DEVFLOW reviewing to sync findings with memory.
```

---

<!-- devflow-split:code:end -->

<!-- devflow-split:qr:begin -->
## Quick Reference — Do / Do Not

> Recorte **deste modo**. A tabela completa do DEVFLOW está distribuída pelas 7 skills — o núcleo (`/devflow`) guarda as linhas transversais.

| DO | DO NOT |
|----|--------|
| Draft ADR before breaking any contract | Break a contract without ADR |
| `git fetch origin` + sync local before creating new branch OR spawning sub-agent on shared files | Spawn from outdated branch — sub-agent will duplicate files |
| Verify canonical path with find/grep before editing | Assume file location from its name or the spec |
| Verify DEFINITION file, not just the caller | Mark a deliverable done after checking the call site |
| Read ENTIRE spec (all sections) at C1 before writing code | Skim spec and miss peripheral deliverables |
| Create TodoWrite task list immediately after C2 "go" | Start coding without a tracked task list |
| Run lint before EACH commit (not only at final C4 gate) | Accumulate commits and lint once at the end |
| Cite line number and code excerpt in each C4 DoD check | Say "I checked and it looks OK" |
| Keep the 5 artifacts mutually consistent (flag contradictions) | Let plan.md and analysis.md disagree on the same flow |
| Fix a refuted premise in the BODY of the artifact, same commit (C5/4b) | Park the correction in an appendix and leave the body proposing the wrong path |
| Annotate a refuted ceremony finding next to itself, with the date | Leave a `critical` finding asserting a mechanism the code disproved |
| Run C1.5 against THIS slice's target files, into `analysis-<slice>.md` | Inherit a `PASS` computed for another slice (or for the whole spec at Planning) |
| Ask whether the promised output is obtainable at the promised granularity | Verify every symbol exists and call the deliverable implementable |
| Audit the POs this slice OWNS in RC5 Pass 0 | Demand every PO of a sliced epic close before any slice may land |
| Fill a Behavioral Failure-Modes table (NULL/0/boundary/missing-join) for every new function + a negative-path test each | Verify only that a symbol exists/matches the repo and call it robust |
| Run RC5 (code review) on every Tier 1+ PR before push | Push without RC5 on Tier 2 work (safety net against regression) |
| Use check-review skill post-push if an external reviewer is configured | Skip RC5 just because an external reviewer exists (defense in depth) |
<!-- devflow-split:qr:end -->
