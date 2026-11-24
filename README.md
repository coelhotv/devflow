# DEVFLOW — Autonomous Software Development Agent

> **The filesystem is the orchestrator.**
>
> **Status: v3.0.0 (PILOT) — Two doors for skill evolution (reactive friction ledger + proactive external-corpus pilots, each with a falsification clause), cold second opinion and resilient independent review (RC6), session handoff, sliced delivery + artifact truth maintenance, Goal-shaped delivery (Proof Obligations), spec-first workflow, Markdown memory, index-first loading.**
>
> The v2.4–v3.0 mutations are **pilots**: their falsification clocks only start in a consumer project whose ledger is committed (see `DEVFLOW-META.md`). No pilot has a verdict yet.

DEVFLOW is a skill for autonomous AI agents working on long-term software projects. It provides persistent memory, goal alignment, numbered feature specs, durable task plans, contract-aware coding, and continuous learning without requiring a central orchestrator.

Each session reads project state from files, acts, and records outcomes back to disk. The next session finds a richer codebase and richer knowledge base.

**Canonical skill file:** `SKILL.md` is the source of truth. `DEVFLOW.md` is a symlink to `SKILL.md` for compatibility with existing project setups.

---

## Core Concepts

| Concept | What it means |
|---------|--------------|
| **Assess → Execute → Record** | Every session follows this loop. Record is mandatory; a session that skips it consumed knowledge without contributing. |
| **Spec-first delivery** | New feature work can start with `/devflow specifying`, producing `plans/specs/NNN-feature-name/spec.md` before technical planning. |
| **Goal-shaped / Proof Obligations** | Every acceptance criterion (Tier 1+) carries a `po` block making it verifiable-by-transcript (`proof`/`expect`/`guard`). C4 closes each PO by pasting evidence; RC5 audits demonstrated-vs-affirmed. Stops weak/cheap models from declaring "done" prematurely. Provider-agnostic distillation of the `/goal` concept. |
| **Index-first memory** | Rules, ADRs, contracts, anti-patterns, and knowledge are stored as Markdown by category. Index files provide fast lookup; detail files load on demand. |
| **Constitution-aware bootstrap** | If `.agent/constitution.md` exists, DEVFLOW loads it before memory indexes and treats conflicts as critical. |
| **Filesystem as orchestrator** | Agents coordinate through `.agent/`, `plans/specs/`, events, journal entries, locks, and durable task files. |
| **Contract gateway** | Breaking an interface contract requires an accepted ADR before proceeding. Hard gate, not suggestion. |
| **Artifact coverage analysis** | Coding mode runs C1.5 to check `spec.md > plan.md > tasks.md > contracts` before implementation. |
| **Meta-evolution** | The agent may propose behavior changes, but human approval is required before applying them. |

---

## Quick Start

### New project

```bash
bash /path/to/devflow/scripts/setup.sh ./my-project "my-project" "react,typescript,supabase" [--with-git-hook]
```

This creates a `.agent/` structure with Markdown memory indexes, detail folders, state, genes, and sessions. Since v3.0 (spec 002) the setup:

- is **idempotent**: re-running it on an existing `.agent/` never overwrites a file, it only creates what is missing and says what it skipped;
- creates both ledgers empty (`.agent/memory/process-friction.jsonl`, `.agent/memory/attempts.jsonl`). A ledger is **active from the commit that added it** (derived from `git log`), so commit `.agent/` right after setup, or no pilot clock starts;
- creates or completes `.gitignore` with the DEVFLOW entries (see *Versioned* below), line by line, without duplicating;
- `--with-git-hook` installs `mode-gate.sh` as a local git hook (optional).

### Existing project

See [templates/README.md](templates/README.md) for onboarding rules, ADRs, contracts, anti-patterns, and knowledge.

For spec-first work, create or use:

```text
plans/specs/NNN-feature-name/
```

---

## Invocation

DEVFLOW modes:

```text
/devflow specifying "describe user-facing need"
/devflow planning "design implementation for current spec"
/devflow coding "implement current plan"
/devflow reviewing "PR #42"
/devflow distill
/devflow status
/devflow status --health
```

Mode control is strict:

- Bootstrap -> STOP
- Specifying -> STOP
- Planning -> STOP
- Coding C2 -> STOP
- Coding C5 -> STOP
- Reviewing -> STOP
- Distillation -> STOP

If your project uses `/deliver-sprint`, DEVFLOW wraps it:

- **Before** `/deliver-sprint`: DEVFLOW Bootstrap + C1/C1.5 + C2 Contract Gateway
- **During** `/deliver-sprint`: DEVFLOW rules/AP/contract constraints
- **After** `/deliver-sprint`: DEVFLOW C5 Post-Code Record

If your project uses `/check-review`, run it first, then sync findings with DEVFLOW:

- `/check-review` -> technical code review
- `/devflow reviewing` -> memory sync, rule lifecycle, new AP proposals

---

## Repository Structure

```text
devflow/
  SKILL.md                         ← canonical skill definition
  DEVFLOW.md                       ← symlink to SKILL.md
  README.md                        ← this file
  CLAUDE.md                        ← repository-local instructions
  DEVFLOW-META.md                  ← meta-evolution protocol

  references/
    DEVFLOW-REFERENCE.md           ← file map, genes, state machine
    *.md                           ← additional reference material

  plans/
    EXEC_SPEC_DEVFLOW_UPGRADE_PLAN.md
    EXEC_SPEC_DOSIQ_PLAN_MIGRATION_TO_DEVFLOW_V18.md

  templates/
    README.md
    state.json
    genes.json
    schema-reference.md
    examples/
      RULE_TEMPLATE.md
      ADR_TEMPLATE.md
      ANTI_PATTERN_TEMPLATE.md
      CONTRACT_TEMPLATE.md
      KNOWLEDGE_TEMPLATE.md

  skills/                          ← the skill split into 7 operator-invoked modes
    devflow-spec/ devflow-plan/ devflow-code/ devflow-ceremony/
    devflow-distill/ devflow-ideation/ ...  (install: scripts/install-skills.sh)

  scripts/
    setup.sh                       ← consumer-project installer (idempotent, v3.0)
    ai-review.sh                   ← RC6 independent review (agy/claude, chunked)
    second-opinion.sh              ← cold second opinion on spec/plan/analysis
    rc6_graph_context.py           ← B1 graph packing, B2 callees, B3 line nums, B4 CON/ADR
    eval-rc6-corpus.py             ← offline C7 corpus evaluator
    skill-comply.sh                ← measures whether a skill step is followed
    mode-gate.sh / reflect-gate.sh ← mechanical gates (no LLM)
    lib/engine-core.sh             ← shared engine layer (@core, versioned contract)

  tests/                           ← offline suites (fake agy/claude, no LLM calls)
```

---

## Project Structure (v3.0)

Each project using DEVFLOW gets a `.agent/` folder:

```text
.agent/
  DEVFLOW.md                       ← symlink to shared skill, where used
  state.json                       ← session state
  constitution.md                  ← optional project principles and constraints

  memory/
    RULES_INDEX.md
    ANTI_PATTERNS_INDEX.md
    DECISIONS_INDEX.md
    CONTRACTS_INDEX.md
    KNOWLEDGE_INDEX.md
    rules/<category>/R-NNN.md
    anti-patterns/<category>/AP-NNN.md
    decisions/<category>/ADR-NNN.md
    contracts/<category>/CON-NNN.md
    knowledge/<category>/K-NNN.md
    journal/YYYY-WWW.jsonl
    journal/archive/
    process-friction.jsonl         ← C5/1c: where the process got in the way (drives skill mutations)
    attempts.jsonl                 ← C5/1b: interventions tried, measured and reverted

  evolution/
    genes.json
    evolution_log.jsonl

  sessions/
    .lock                          ← optimistic write lock, not versioned
    events.jsonl                   ← append-only session events, not versioned
```

Spec-first feature work lives outside `.agent/`:

```text
plans/
  specs/
    NNN-feature-name/
      spec.md                      ← WHAT/WHY, user stories, FRs, SCs
      plan.md                      ← technical plan and clarifications
      tasks.md                     ← durable task list mirrored into TodoWrite
      analysis.md                  ← C1.5 artifact coverage analysis
      checklists/
        requirements.md            ← requirements quality checklist
      contracts/
        *.md                       ← feature-local contracts, if needed
```

**Versioned:** `.agent/memory/` (indexes, detail files, journal and both ledgers), `.agent/constitution.md`, `plans/specs/`.

**Not versioned** (the setup's `.gitignore`): `.agent/state.json` (local session state, including `session.handoff`), `.agent/sessions/`, `.agent/evolution/`.

---

## Independent Review Scripts (RC6 / second opinion)

`scripts/ai-review.sh` (RC6) and `scripts/second-opinion.sh` send the diff or artifact to an external engine in a **fresh process** (`agy -p` primary, `claude -p` fallback), with no tools and an egress guard for PII-shaped lines. Both share `scripts/lib/engine-core.sh`, whose version is a contract (`ENGINE_CORE_EXPECTED`); a mismatched core fails loudly.

Since `@core` 1.2.0 (spec 003, after dosiq#835 reported full coverage while 3 of 4 chunks had died on a 503):

- **Coverage is what was reviewed, not what was planned.** `coverage.chunks_reviewed` counts chunks reviewed by every active pass; `per_pass.{A,B}` and `independent_reviewers.{min,max}` say how many reviewers each chunk actually had.
- **Transient engine errors are retried, others are not.** Errors are classified `transient | timeout | quota | fatal` from each attempt's error text (including a failure envelope returned with exit 0). Only `transient` is retried (backoff, then a fallback model, then one re-queue at the end), all under one time budget per run.
- **Turn-1 truncation guard & Pass B hardening (`@core` 1.3.0):** `unwrap_structured` logs `thinking=` / `turns=` and flags Turn-1 `agy` context saturation (`~79.6K` tokens) without false-positiving on multi-turn `high` effort (`cache_read` check when `num_turns >= 2`), marking `coverage.truncated_chunks` + `partial: true`. `ai-review.sh` places `DIFF` before `FULL FILES`, defaults `RC6_MAX_CHUNKS=8`, escalates Pass B `agy` fallback to `gemini-4-neon-high` (`10m`), and exposes `coverage.selector` / `selector=FAILED` on selector errors or fail-safe degradation.
- **Per-chunk context & graph assembly (`A1/A2/A5`, `B1–B4`):** `select-rules.mjs` and `DETAIL_FILES` run per chunk (`RC6_CHUNK_SCOPE=1`, `--related-paths`, `--format card`), `rc6_graph_context.py` packs coupled files by import graph (`B1`), slices unchanged external callees (`B2`), annotates `RIGHT`-side diff line numbers (`B3`), and injects touched `CON-NNN`/`ADR-NNN` entries (`B4`), all bounded under `RC6_CTX_TOTAL_MAX` (`150 KB`).
- **Adaptive effort, symmetric quota fallback & standardized language (`C2`, `RC6_ENGINE_AGY=0`, `RC6_LANG`):** `rank_chunks.py` routes `HOT` chunks to `gemini-4-neon-high` (`10m`) and `COLD` Pass B fallback chunks to `neon-medium`. `RC6_ENGINE_AGY=0` runs Pass A (Tier 1 & 2) on `claude` (`RC6_CLAUDE_MODEL`, default `sonnet`). `RC6_LANG` (default `pt-BR`) standardizes output prose while keeping JSON keys, `severity`, `file`, and `snippet` verbatim.
- **Deterministic reflection & cold second opinion (`C4`, `C6`):** `reflect-gate.sh` adds diff-backed `comment_only` refutation (preserving prompt-injection exceptions), non-refuting `rule_id_warning`, and `corroborated_by_tool` (`tsc`/`eslint`). `second-opinion.sh` adds bounded `CLAUDE.md` + cited `CON/ADR` grounding (`<=150 KB`), `--tier2` (`gemini-4-neon-high`, `10m`), `"truncated"` telemetry, and `RC6_LANG`.
- **The last stderr line is the verdict:** `[rc6] VERDICT coverage=partial A=1/4 B=4/4 reviewers_min=1 …`, matching the JSON (appending `truncated=<N>` and `selector=FAILED` when triggered). `partial` is recorded in the PR, not a reason to run RC6 again. A JSONL status feed (`[rc6] status: <path>`) lets a background caller follow progress.

| Env var | Default | Effect |
|---|---|---|
| `RC6_AGY_MODEL` | `gemini-4-neon-medium` | Primary `agy` model (Pass A and standalone scripts). |
| `RC6_AGY_PASSB_MODEL` | `gemini-4-neon-high` | `agy` model for Pass B fallback; empty reuses `RC6_AGY_MODEL`. |
| `RC6_AGY_PASSB_TIMEOUT` | `${RC6_AGY_TIMEOUT:-10m}` | Per-chunk `--print-timeout` during Pass B `agy` fallback. |
| `RC6_MAX_CHUNKS` | `8` | Maximum chunks sent per pass before risk ranking drops excess chunks. |
| `RC6_AGY_TRUNC_TOKENS` | `78000` | Turn-1 `agy` truncation warning threshold (`<=0` disables). |
| `RC6_RETRIES` | `2` | Extra attempts per call. `0` also disables the second round (pre-003 behavior). |
| `RC6_BACKOFF` | `30 90` | Seconds before extra attempt N (last value repeats); `RC6_JITTER=1` adds up to +⅓. |
| `RC6_RETRY_BUDGET` | `300` | Extra seconds allowed per run (waits + extra attempts + second round). |
| `RC6_BREAKER` | `3` | Consecutive transient failures that stop immediate retries. |
| `RC6_AGY_MODEL_FALLBACK` | `gemini-4-hydrogen-medium` | Fallback model for agy; empty disables. Never used by the A/B measurement. |
| `RC6_STATUS_FILE` | `$TMPDIR/rc6-status-<pid>.jsonl` | Where status events go. |
| `RC6_ENGINE_CLAUDE` | `1` | `0` keeps RC6 off claude (quota guard). |
| `RC6_ENGINE_AGY` | `1` | `0` disables `agy` and runs Pass A (Tier 1 & 2) on `claude` (quota guard). |
| `RC6_CLAUDE_MODEL` | `sonnet` | Overrides `--model` on `claude` calls (`sonnet`, `opus`, etc.). |
| `RC6_LANG` | `pt-BR` | Standardizes prose fields (`summary`, `issue`, `causation`/`suggestion`, `fix`) while preserving keys, `file`, and `snippet`/`quote`. |
| `RC6_CHUNK_SCOPE` | `1` | `1` (`A1`) runs `select-rules.mjs` and `DETAIL_FILES` per chunk with local dedupe; `0` restores global scope. |
| `RC6_SELECTOR_FORMAT` | `""` | Empty sends full rule text; `card` passes `--format card` (`Review Cards <=450 B`) when available. |
| `RC6_SELECTOR_RELATED` | `1` | Passes 1-hop `chunk_i.related` neighbors via `--related-paths` to `select-rules.mjs` (`A5`). |
| `RC6_GRAPH_CHUNK` | `1` | `1` (`B1`) packs chunks by import graph cohesion (`.graftroom/` + regex/`tsconfig`/barrels); `0` restores alphabetical split. |
| `RC6_CALLEES` / `RC6_CALLEES_MAX_BYTES` | `1` / `12000` | `B2` surgical slicing of external callees referenced in diff hunks. |
| `RC6_DIFF_LINE_NUMS` | `1` | `B3` annotates diff `+`/context lines with `HEAD` `RIGHT` line numbers (`+   N | ...`). |
| `RC6_CONTRACTS` / `RC6_CONTRACTS_MAX_BYTES` | `1` / `6000` | `B4` injects active `CON-NNN`/`ADR-NNN` entries touched by each chunk. |
| `RC6_ADAPTIVE_EFFORT` | `auto` | `C2` routes `HOT` chunks to `neon-high` (`10m`) and `COLD` Pass B fallback chunks to `neon-medium`. |
| `RC6_SO_GROUNDING` | `1` | Enables bounded `CLAUDE.md` + cited `CON/ADR` grounding (`<=150 KB`) in `second-opinion.sh` (`C6`). |

---

## Modes

| Mode | Command | Purpose |
|------|---------|---------|
| Specifying | `/devflow specifying "goal"` | Create numbered `plans/specs/NNN-feature-name/spec.md` focused on WHAT/WHY |
| Planning | `/devflow planning "goal"` | Clarify requirements, create plan/tasks, check ADR needs |
| Coding | `/devflow coding "task"` | Analyze artifacts, pass contract gateway, implement with memory constraints |
| Reviewing | `/devflow reviewing "PR #N"` | Analyze changes against rules/contracts/ADRs and sync memory |
| Distillation | `/devflow distill` | Compress journal, lifecycle review, reconcile indexes/counters |
| Status | `/devflow status` | Current state dashboard |

---

## Memory Categories

| Category | Use for |
|----------|---------|
| **data_and_schema** | Database, schemas, APIs, data validation |
| **infra_and_deploy** | Infrastructure, CI/CD, deployments, environment |
| **mobile_and_platform** | Mobile-specific code, native platform behavior |
| **react_and_ui** | React components, hooks, UI patterns |
| **process_and_testing** | Testing, QA, delivery processes |

Projects may add categories when their `.agent/memory/*_INDEX.md` files and detail paths stay consistent.

---

## Memory Item Types

| Type | ID | Location | Index |
|------|----|----------|-------|
| Rule | `R-NNN` | `.agent/memory/rules/<category>/R-NNN.md` | `RULES_INDEX.md` |
| ADR | `ADR-NNN` | `.agent/memory/decisions/<category>/ADR-NNN.md` | `DECISIONS_INDEX.md` |
| Anti-pattern | `AP-NNN` | `.agent/memory/anti-patterns/<category>/AP-NNN.md` | `ANTI_PATTERNS_INDEX.md` |
| Contract | `CON-NNN` | `.agent/memory/contracts/<category>/CON-NNN.md` | `CONTRACTS_INDEX.md` |
| Knowledge | `K-NNN` | `.agent/memory/knowledge/<category>/K-NNN.md` | `KNOWLEDGE_INDEX.md` |

Each detail file uses YAML frontmatter plus Markdown body. See [templates/schema-reference.md](templates/schema-reference.md).

---

## Cross-Project Knowledge — RETIRED (2026-09-04)

The shared knowledge base at `~/.devflow/global_base/` and the `/devflow export` step are **no
longer part of the protocol** (dosiq spec 078 / ADR-097). Measured before retiring it: 616 KB,
133 `.md`, every content file last written **2026-04-08** — five months write-only — and **zero**
read paths anywhere in the skill. Nothing consumed it, so nothing was learned from it.

Promotion now happens **inside** a project (D3): rank memories by the refreshed `incident_count`,
take the top-K, and let the file that is always loaded be the consumer. The directory is left on
disk for traceability; nothing was deleted. Reviving cross-project sharing needs the two things it
never had: a reader, and a way to validate a rule from project A inside project B.

## Language

DEVFLOW protocol files are in **English** for model compatibility.

Project domain content, UI copy, changelogs, and product docs may use the project's native language.

---

## How to Add Memory Items

1. Copy a template from `templates/examples/`.
2. Rename it to match the type ID (`R-NNN`, `ADR-NNN`, `AP-NNN`, `CON-NNN`, `K-NNN`).
3. Place it in the correct category subdirectory.
4. Fill required YAML frontmatter.
5. Update the relevant `*_INDEX.md`.
6. Use the lock protocol before editing shared index files.

See [templates/README.md](templates/README.md) for examples.

---

## License

MIT — use freely, contribute back if you improve it.
