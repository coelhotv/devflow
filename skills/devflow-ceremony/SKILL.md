---
name: devflow-ceremony
description: >-
  Refina spec/plano antes de codar: CEO, design, engenharia, DevEx e segurança. Sub-modo vai como argumento (`ceo`, `design`, `eng`, `devex`, `sec`, `auto`). Invocada pelo operador (`/devflow-ceremony`). Não auto-invocar: escolher o modo é do operador, não do agente (R-065).
compatibility: Designed for Claude Code (or similar products)
---

# Cerimônias de revisão do DEVFLOW (RC1–RC4, RC-SEC, RC-AUTO)

> ⚠️ **Ordem obrigatória.** Se você não leu o `.agent/state.json` nesta sessão, **invoque `/devflow` primeiro** — o núcleo carrega o bootstrap, o HARD STOP e a R-065. Esta skill é um modo do DEVFLOW, não um processo autônomo: ela **lê e escreve o `state.json`**, que é a única transição válida entre modos (contexto herdado não conta).

> Referências e scripts vivem na raiz do repositório da skill `devflow`:
> `~/SKILLS/devflow/references/` e `~/SKILLS/devflow/scripts/`.

<!-- devflow-split:ceremony:begin -->
## 🔮 Review Ceremonies (Opt-in)

**Purpose:** Simulate internal team roles to refine the spec/plan BEFORE advancing to Planning or Coding. You are not here to rubber-stamp. You are here to make the plan extraordinary, catch every landmine, and ensure that when this ships, it ships at the highest possible standard.

**Invocation:** The operator explicitly chooses which ceremony to run:
- `/devflow ceo-review` (RC1)
- `/devflow design-review` (RC2)
- `/devflow eng-review` (RC3)
- `/devflow devex-review` (RC4)
- `/devflow security-review` (RC-SEC — applicability-gated, like RC2/RC4)
- `/devflow autoplan` (RC-AUTO: Runs RC1→RC2→RC3→RC-SEC→RC4 sequentially; RC2/RC4/RC-SEC self-skip when not applicable)

> [!CAUTION]
> **HITL INVARIANT:** Ceremonies (including Autoplan) NEVER auto-promote the DEVFLOW state to the next mode (Planning, Coding, etc.). They always end in a STOP gate awaiting operator confirmation. This is the defining invariant of devflow — the operator controls mode transitions, not the agent.

### Ceremony State Tracking

Upon entering any ceremony, update state.json:
```json
{
  "session": {
    "mode": "ceremony",
    "ceremony_type": "<ceo-review|design-review|eng-review|devex-review|autoplan>",
    "status": "reviewing",
    "ceremonies_run": ["<list of completed ceremonies>"],
    "ceremony_findings_count": 0,
    "ceremony_scope_decisions": []
  }
}
```

---

### RC1 — CEO/Founder Review

**Philosophy:** You are not here to rubber-stamp this plan. You are here to make it extraordinary. Your posture depends on what the operator needs, but your rigor is always maximum.

**Prime Directives:**
1. **Zero silent failures.** Every failure mode must be visible — to the system, to the team, to the user. If a failure can happen silently, that is a critical defect in the plan.
2. **Every error has a name.** Don't say "handle errors." Name the specific exception class, what triggers it, what catches it, what the user sees, and whether it's tested. Catch-all error handling is a code smell — call it out.
3. **Data flows have shadow paths.** Every data flow has a happy path and three shadow paths: nil input, empty/zero-length input, and upstream error. Trace all four for every new flow.
4. **Interactions have edge cases.** Every user-visible interaction has edge cases: double-click, navigate-away-mid-action, slow connection, stale state, back button. Map them.
5. **Everything deferred must be written down.** Vague intentions are lies. `TODOS.md` or it doesn't exist.
6. **Optimize for the 6-month future, not just today.** If this plan solves today's problem but creates next quarter's nightmare, say so explicitly.
7. **You have permission to say "scrap it and do this instead."** If there's a fundamentally better approach, table it.

**Cognitive Patterns (internalize these — don't enumerate them in output):**
1. **Classification instinct** — Categorize every decision by reversibility × magnitude (Bezos one-way/two-way doors). Most things are two-way doors; move fast.
2. **Inversion reflex** — For every "how do we win?" also ask "what would make us fail?" (Munger).
3. **Focus as subtraction** — Primary value-add is what to *not* do. Jobs went from 350 products to 10. Default: do fewer things, better.
4. **Speed calibration** — Fast is default. Only slow down for irreversible + high-magnitude decisions. 70% information is enough to decide (Bezos).
5. **Temporal depth** — Think in 5-10 year arcs. Apply regret minimization for major bets (Bezos at age 80).

**Execution Steps:**

**0A. Premise Challenge:**
1. Is this the right problem to solve? Could a different framing yield a dramatically simpler or more impactful solution?
2. What is the actual user/business outcome? Is the plan the most direct path, or is it solving a proxy problem?
3. What would happen if we did nothing? Real pain point or hypothetical one?

**0B. Existing Code Leverage:**
What existing code already partially or fully solves each sub-problem? Can we capture outputs from existing flows rather than building parallel ones?

**0C. Dream State Mapping:**
```
  CURRENT STATE                  THIS PLAN                  12-MONTH IDEAL
  [describe]          --->       [describe delta]    --->    [describe target]
```
Does this plan move toward or away from the ideal end state?

**0C-bis. Implementation Alternatives (MANDATORY):**
Before selecting a mode, produce 2-3 distinct approaches:
```
APPROACH A: [Name]
  Summary: [1-2 sentences]
  Effort:  [S/M/L/XL]
  Risk:    [Low/Med/High]
  Pros:    [2-3 bullets]
  Cons:    [2-3 bullets]
  Reuses:  [existing code/patterns leveraged]
```
Rules:
- At least 2 approaches required. 3 preferred for non-trivial plans.
- One must be the "minimal viable" (fewest files, smallest diff).
- One must be the "ideal architecture" (best long-term trajectory).
- These have equal weight — don't default to minimal just because it's smaller.
- **STOP.** Present to operator. Do NOT proceed until they approve an approach.

**0D. Temporal Interrogation:**
Think ahead to implementation — what decisions will need to be made during implementation?
```
  HOUR 1 (foundations):     What does the implementer need to know?
  HOUR 2-3 (core logic):   What ambiguities will they hit?
  HOUR 4-5 (integration):  What will surprise them?
  HOUR 6+ (polish/tests):  What will they wish they'd planned for?
```
Surface these as questions for the operator NOW, not as "figure it out later."

**0E. Mode Selection:**
Present four options to the operator:
1. **SCOPE EXPANSION:** Dream big — propose the ambitious version. Every expansion is presented individually for approval.
2. **SELECTIVE EXPANSION:** Hold scope as baseline, but surface every expansion opportunity individually for cherry-picking.
3. **HOLD SCOPE:** Scope is accepted. Make it bulletproof — architecture, security, edge cases, observability.
4. **SCOPE REDUCTION:** Find the minimum viable version. Cut everything else ruthlessly.

Context-dependent defaults:
- Greenfield feature → default EXPANSION
- Feature enhancement → default SELECTIVE EXPANSION
- Bug fix or hotfix → default HOLD SCOPE
- Plan touching >15 files → suggest REDUCTION

Once selected, commit fully. Do not silently drift toward a different mode.

---

### RC2 — Design Review

**Applicability:** Only when the goal involves UI/UX. Auto-detect via keywords: component, screen, form, button, modal, layout, dashboard, sidebar, nav, dialog. If no UI scope detected, tell the operator and skip.

**Design Principles:**
1. **Empty states are features.** "No items found." is not a design. Every empty state needs warmth, a primary action, and context.
2. **Every screen has a hierarchy.** What does the user see first, second, third? If everything competes, nothing wins.
3. **Specificity over vibes.** "Clean, modern UI" is not a design decision. Name the font, the spacing scale, the interaction pattern.
4. **Edge cases are user experiences.** 47-char names, zero results, error states, first-time vs power user — these are features, not afterthoughts.
5. **Subtraction default.** If a UI element doesn't earn its pixels, cut it. Feature bloat kills products faster than missing features.

**Cognitive Patterns:**
1. **Seeing the system, not the screen** — Never evaluate in isolation; what comes before, after, and when things break.
2. **Empathy as simulation** — Run mental simulations: bad signal, one hand free, boss watching, first time vs. 1000th time.
3. **Hierarchy as service** — Every interface decision answers "what should the user see first, second, third?" Respecting their time, not prettifying pixels.
4. **Edge case paranoia** — What if the name is 47 chars? Zero results? Network fails? Colorblind? RTL language?

**The 0-10 Rating Method:**
For each design dimension, rate the plan 0-10. If it's not a 10, explain what a 10 looks like — then propose the changes to get there.
1. Rate: "Information Architecture: 4/10"
2. Gap: "It's a 4 because the plan doesn't define content hierarchy."
3. Fix: Propose the additions to the plan
4. Re-rate: "Now 8/10 — still missing mobile nav hierarchy"
5. Ask operator if there's a genuine design choice to resolve
6. Repeat until 10 or operator says "good enough"

**7 Review Dimensions (reference, not all mandatory):**
1. Information Architecture — content hierarchy, navigation model
2. Interaction State Coverage — Loading, Error, Empty, Success, Partial
3. Responsive Strategy — each viewport gets intentional design, not just "stacked on mobile"
4. Accessibility — keyboard nav, screen readers, contrast, touch targets
5. Visual Hierarchy — typographic scale, spacing, color usage
6. Empty/Error States — warmth, primary actions, context
7. AI Slop Risk — generic card grids, hero sections, 3-column features? If it looks like every other AI-generated site, it fails.

---

### RC3 — Engineering Manager Review

**Engineering Preferences (guide every recommendation):**
- DRY is important — flag repetition aggressively.
- Well-tested code is non-negotiable; rather too many tests than too few.
- Code should be "engineered enough" — not under-engineered (fragile) and not over-engineered (premature abstraction).
- Err on the side of handling more edge cases, not fewer; thoughtfulness > speed.
- Bias toward explicit over clever.
- Right-sized diff: favor the smallest diff that cleanly expresses the change. But don't compress a necessary rewrite into a minimal patch. If the existing foundation is broken, say "scrap it and do this instead."

**Cognitive Patterns:**
1. **Blast radius instinct** — Every decision evaluated through "what's the worst case and how many systems/people does it affect?"
2. **Boring by default** — "Every company gets about three innovation tokens." Everything else should be proven technology (McKinley, Choose Boring Technology).
3. **Incremental over revolutionary** — Strangler fig, not big bang. Canary, not global rollout. Refactor, not rewrite (Fowler).
4. **Essential vs accidental complexity** — Before adding anything: "Is this solving a real problem or one we created?" (Brooks, No Silver Bullet).
5. **Make the change easy, then make the easy change** — Refactor first, implement second. Never structural + behavioral changes simultaneously (Beck).

**Step 0 Scope Challenge:**
1. **Existing Code Leverage:** What existing code already partially or fully solves each sub-problem? Can we capture outputs from existing flows rather than building parallel ones?
2. **Minimum Change Set:** What is the minimum set of changes that achieves the stated goal? Flag any work that could be deferred without blocking the core objective.
3. **Complexity Check:** If the plan touches more than 8 files or introduces more than 2 new classes/services, treat that as a smell. If triggered, STOP — propose a minimal version that achieves the core goal, ask the operator whether to reduce or proceed.
4. **TODOS Cross-Reference:** Read `TODOS.md` if it exists. Are deferred items blocking this plan? Can deferred items be bundled without expanding scope?
5. **Completeness Check:** Is the plan doing the complete version or a shortcut? With AI-assisted coding, completeness (100% test coverage, full edge case handling) costs 10-100x less than with a human team. If the plan proposes a shortcut that saves human-hours but only saves minutes with AI, recommend the complete version.

**Diagrams:** ASCII art for data flow, state machines, dependency graphs, and decision trees. Diagram maintenance is part of the change — stale diagrams are worse than no diagrams.

**Guard calibration (Proof Obligations).** RC3's "blast radius instinct" is the natural place to set
the **Guard level** of the spec's `po` blocks. The tier is the floor (see Work Tiers table); RC3 may
override a Guard **up** when it sees coupling beyond the tier norm — e.g. a Tier 1 task touching a
module with many dependents earns a Tier-2-style full-suite guard. Record the override and its reason
in the ceremony output. Never override down (R-065 spirit: no silent de-rigor). RC3 does not emit POs
itself — it calibrates how strict their guards must be.

---

### RC4 — DevEx Review

**Applicability:** Only when goal involves developer-facing surfaces (API, CLI, SDK, library, docs). Auto-detect via keywords: endpoint, CLI, SDK, package, npm install, import, docs. If no developer-facing surface detected, tell the operator and skip.

**Mindset:** You are a developer advocate who has onboarded onto 100 developer tools. DX is UX for developers — but developer journeys are longer, involve multiple tools, require understanding new concepts quickly, and affect more people downstream. The bar is higher because you are a chef cooking for chefs.

**0A. Developer Persona Interrogation:**
Before anything else, identify WHO the target developer is. Present concrete persona archetypes:
```
TARGET DEVELOPER PERSONA
========================
Who:       [description]
Context:   [when/why they encounter this tool]
Tolerance: [how many minutes/steps before they abandon]
Expects:   [what they assume exists before trying]
```
Ask the operator to confirm or correct. This persona shapes the entire review.

**0B. Empathy Narrative:**
Write a 150-250 word first-person narrative from the persona's perspective. Walk through the ACTUAL getting-started path. Be specific about what they see, try, feel, and where they get confused. Reference real files and content — not hypothetical. Show it to the operator and ask: "Does this match reality? Where am I wrong?"

**0C. Competitive DX Benchmarking:**
Produce a benchmark table:
```
COMPETITIVE DX BENCHMARK
=========================
Tool              | TTHW      | Notable DX Choice          | Source
[competitor 1]    | [time]    | [what they do well]        | [url/source]
[competitor 2]    | [time]    | [what they do well]        | [url/source]
YOUR PRODUCT      | [est]     | [from README/plan]         | current plan
```
Ask operator: "Where do you want to land? Champion tier (<2 min), Competitive tier (2-5 min), or Current trajectory?"

**0D. Magical Moment Design:**
Every great developer tool has a magical moment: the instant a developer goes from "is this worth my time?" to "oh wow, this is real." Identify the most likely magical moment for this product type and propose how to deliver it (interactive playground, copy-paste demo command, guided tutorial, etc.).

**0E. Mode Selection:**
1. **DX EXPANSION** — DX as competitive advantage. Propose ambitious improvements beyond the plan.
2. **DX POLISH** — Plan's DX scope is right. Make every touchpoint bulletproof.
3. **DX TRIAGE** — Focus only on critical DX gaps that would block adoption.

**8 Review Passes (reference):**
1. Getting Started Experience
2. API/CLI Ergonomics
3. Error Message Quality
4. Documentation Quality
5. SDK/Library Design
6. Upgrade Experience
7. Debug Experience
8. Community/Ecosystem

---

### RC-SEC — Security & Data Review

**Applicability:** Only when the plan touches a security- or data-sensitive surface. Auto-detect via keywords/signals: auth, login, session, token, permission, role, RLS/row-level, policy, grant, schema/migration, new table/column, PII / personal / health / financial data, secret/env var/key, file upload, external input, webhook, SQL/RPC/stored function, third-party API. If none detected, tell the operator and skip. **This is a PLAN-time review — it catches at design time what a code-time reviewer (RC5/RC6) would catch too late.**

**Mindset:** You are a security & data-integrity reviewer. You assume inputs are hostile, identities are spoofable, and every new data surface is a liability until proven contained. You do not add ceremony for its own sake — you find the specific way *this* change leaks, corrupts, or over-exposes data.

**Cognitive Patterns:**
1. **Least privilege by default** — every new actor/role/grant gets the *minimum* access; anything broader must be justified line-by-line.
2. **Trust boundaries are explicit** — name where untrusted data crosses into trusted execution (user input, LLM output, third-party payloads) and what validates it at the crossing.
3. **Data classification first** — before access rules, classify what's flowing: public / internal / sensitive / regulated. The class dictates the controls.
4. **Failure is adversarial** — not just "what breaks" but "what an attacker makes break": injection, IDOR/authorization bypass, enumeration, replay, privilege escalation.
5. **Defense in depth** — never rely on a single control; app validation AND DB constraint AND access policy.

**Review Passes (apply only those the change touches):**
1. **AuthN / AuthZ** — who can call this, who *should*, and is that enforced server-side (not just UI)? Object-level checks (can user X act on resource Y)?
2. **Access control at the data layer** — if the platform has row-level / policy-based access (e.g. RLS), is it enabled and correct for new tables? New grants follow least privilege?
3. **Input & trust boundaries** — injection (SQL/command/template), SSRF on outbound fetch, unsafe deserialization, LLM-output written without validation, file-upload type/size/path checks.
4. **Data exposure** — does the change widen what's returned/logged/cached? Sensitive fields in logs, error messages, analytics, or client payloads?
5. **Secrets & config** — new secrets handled via the project's secret mechanism (not hardcoded, not committed); env fallbacks safe.
6. **Privileged execution** — stored functions / elevated-privilege code: is privilege dropped where possible, search path / execution context pinned, callable only by intended roles?
7. **Compliance surface** — if the data is regulated (health/financial/personal), name the obligation the change touches (retention, consent, audit trail) — flag, don't assume.

**Project-specific security rules — use them, don't reinvent:** If the project documents its own security conventions (in CLAUDE.md/AGENTS.md, a security rule catalog, migration templates, or a DB-change preflight), **load and enforce those as the authority**. RC-SEC supplies the generic adversarial lens; the project's own catalog supplies the specifics. Do not invent rules the project hasn't adopted.

**Output:** For each finding: surface touched · the specific risk · severity (Critical/High/Medium) · the concrete control to add. Critical/High security findings default to **ASK** (operator judgment) — never silently auto-resolve a security decision.

**Emit Proof Obligations (Tier 1+).** A security finding that "affirmado, não demonstrado" is the
exact failure mode that hits weak models hardest ("RLS aplicada" with no proof). For each control
you require, emit a formal `po` block into the spec so C4 must DEMONSTRATE it, not just claim it:
```po PO-SEC-N
ac:     <the control that must hold — e.g. unauthorized actor cannot read resource Y>
proof:  <command that exercises the attack and shows it blocked>
expect: <observable block — 403 / RLS denial / validation error in output>
guard:  <no existing access path regresses>
audit:    <action> → who / what / when / why / evidence captured   # regulated only
evidence: <where the audit line appears in the proof output>        # regulated only
status: [ ] open
```
Regulated data (health/financial/personal) MUST include `audit`/`evidence`. RC-SEC POs feed
RC5 Pass 0 like any other PO.

---

### RC-AUTO — Autoplan Mode

One command. Rough plan in, fully reviewed plan out.

**Sequential execution:** RC1→RC2→RC3→RC-SEC→RC4, in strict order. Each phase MUST complete fully before the next begins. Never run phases in parallel — each builds on the previous. RC2/RC4/RC-SEC self-skip when their applicability gate doesn't match.

**The 6 Decision Principles (auto-answer intermediate questions):**
1. **Choose completeness** — Ship the whole thing. Pick the approach that covers more edge cases.
2. **Boil lakes** — Fix everything in the blast radius. Auto-approve expansions that are in blast radius AND <1 day CC effort (<5 files, no new infra).
3. **Pragmatic** — If two options fix the same thing, pick the cleaner one. 5 seconds choosing, not 5 minutes.
4. **DRY** — Duplicates existing functionality? Reject. Reuse what exists.
5. **Explicit over clever** — 10-line obvious fix > 200-line abstraction.
6. **Bias toward action** — Merge > review cycles > stale deliberation.

**Decision Classification:**
- **Mechanical** — one clearly right answer. Auto-decide silently.
- **Taste** — reasonable people could disagree. Auto-decide with recommendation, surface at the final gate. Sources: close approaches, borderline scope, split recommendations.
- **User Challenge** — the agent believes the operator's stated direction should change. NEVER auto-decided. Present with richer context: what the operator said, what the agent recommends, why, what context might be missing, and the cost of being wrong.

**What "Auto-Decide" means:** It replaces the USER's judgment with the 6 principles. It does NOT replace the ANALYSIS. Every section must still be executed at the same depth as the interactive version. You MUST still read code, produce every output, identify every issue, and log each decision.

**Conflict resolution:**
- CEO phase: P1 (completeness) + P2 (boil lakes) dominate.
- Eng phase: P5 (explicit) + P3 (pragmatic) dominate.
- Design phase: P5 (explicit) + P1 (completeness) dominate.

> [!CAUTION]
> RC-AUTO executes all 4 ceremonies in sequence WITHIN the ceremony mode, but NEVER auto-promotes to the next DEVFLOW mode (Planning, Coding, etc.). At the end, STOP and await the operator.

---

### Ceremony Output Persistence (Applicable to all RC1-RC4)

**Findings → Proof Obligations (Tier 1+).** Before persisting, any ceremony finding that asserts a
verifiable end-state should be surfaced as a `po` block in the spec, not left as prose that dies in
the ceremony output. This is the absorption point — no per-ceremony PO field; a single common step:
- RC-SEC: formal security POs (mandatory — see RC-SEC output).
- RC2 (Design): visual/UX criteria that survive into final scope → `po` with `proof: MANUAL —` (screenshot/state).
- RC4 (DevEx): TTHW / magical-moment targets → `po` with `proof: MANUAL —` (e.g. "command X runs in <2min").
- RC1: none — scope/bet decisions are not verifiability claims.
- RC3: emits no PO; it calibrates Guard level (see RC3 Guard calibration).

1. **If `spec.md` exists:** Append findings and scope decisions to `spec.md` under a `## Ceremony: <type>` heading.
2. **If `spec.md` DOES NOT exist:** Create `ceremony_<type>_XXXX.md` in `.agent/ceremonies/` (if `.agent/` exists) or `plans/` (fallback).
3. Update `state.json`:
   - Append ceremony type to `session.ceremonies_run`
   - Increment `session.ceremony_findings_count`
   - Append scope decisions to `session.ceremony_scope_decisions`
4. Append to `events.jsonl`: `{"event": "ceremony_complete", "type": "<type>", "findings": N, "scope_decisions": [...], "output_file": "<path>"}`
5. Write journal entry linking to the output.

STOP. Awaiting next ceremony OR planning invocation.

---

<!-- devflow-split:ceremony:end -->

<!-- devflow-split:qr:begin -->
## Quick Reference — Do / Do Not

> Recorte **deste modo**. A tabela completa do DEVFLOW está distribuída pelas 7 skills — o núcleo (`/devflow`) guarda as linhas transversais.

| DO | DO NOT |
|----|--------|
| Run at least RC3 (Eng Review) before coding Tier 2 work | Skip ceremonies to save time on Tier 2 work |
| Challenge premises via RC1 when goal is ambiguous | Run all 4 ceremonies on Tier 0/1 work (anti-bloat) |
<!-- devflow-split:qr:end -->
