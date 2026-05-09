# DEVFLOW Reference — Static Definitions

> Carregado sob demanda. Não faz parte do bootstrap normal.
> Consulte quando precisar do mapa de arquivos, defaults de genes, ou diagrama do estado.

---

## File Reference Map

```
.agent/
  DEVFLOW.md                    ← skill definition (symlink — do not modify without /devflow meta-evolve)
  state.json                    ← session state (read first, update last in every session)

  memory/
    RULES_INDEX.md              ← Rules Sparse Index
    ANTI_PATTERNS_INDEX.md      ← Anti-Patterns Sparse Index
    DECISIONS_INDEX.md          ← ADR Sparse Index
    CONTRACTS_INDEX.md          ← Contracts Sparse Index
    KNOWLEDGE_INDEX.md          ← Knowledge Sparse Index

    rules/[category]/[id].md    ← YAML-backed detail files
    anti-patterns/[cat]/[id].md
    decisions/[cat]/[id].md
    contracts/[cat]/[id].md
    knowledge/[cat]/[id].md

    journal/
      YYYY-WWW.jsonl            ← current sprint events (append-only)
      archive/YYYY-WXX-WYY.json ← distilled past entries

  evolution/
    genes.json                  ← behavior parameters (human-modifiable via approval process)
    evolution_log.jsonl         ← append-only mutation history

  sessions/
    .lock                       ← optimistic write lock (clear after every write)
    events.jsonl                ← session events (append-only, capped at 200 entries)

  synthesis/
    pending_export.json         ← rules/APs ready for global base promotion
```

---

## Gene Reference

Default values in `evolution/genes.json`:

| Gene | Default | Description |
|------|---------|-------------|
| `memory_distillation_threshold` | 15 | Journal entries before auto-distillation |
| `auto_promote_rule_after_incidents` | 2 | Incident count to trigger global promotion candidate |
| `require_adr_for_schema_changes` | true | Gate on schema modifications |
| `require_adr_for_api_breaking_changes` | true | Gate on breaking API changes |
| `enforce_contract_checks` | true | Run contract gateway in coding mode |
| `rule_review_cadence_weeks` | 12 | Weeks before a rule is flagged for review |
| `anti_pattern_expiry_weeks` | 52 | Weeks before an AP with zero triggers is deprecated |
| `cross_project_export_auto` | false | Auto-export to global base without human approval |

---

## Session State Machine

```
PLANNING MODE:
  START (/devflow planning)
    ↓
  P0: session.status = "planning"
    ↓
  P1-P3: scope analysis, ADR check, spec creation
    ↓
  P4: session.status = "planned"
    ↓
  END → STOP (awaiting Coding mode invocation)

CODING MODE:
  START (/devflow coding)
    ↓
  C0: session.status = "analysis"
    ↓
  C1-C2: pre-code checklist, contract gateway (C2 GATE fires)
    ↓
  "go" / /deliver-sprint → session.status = "coding"
  "stop"                 → session.status = "halted" → END
    ↓
  C3-C4: implementation, quality gates
    ↓
  C5: session.status = "completed"
    ↓
  END → STOP (memory updated, awaiting next phase)

REVIEWING MODE:
  START (/devflow reviewing)
    ↓
  R0: session.status = "reviewing"
    ↓
  R1-R4: load context, violation scan, severity, memory update
    ↓
  R5: session.status = "reviewed"
    ↓
  END → STOP (awaiting merge decision)

DISTILLATION MODE:
  START (/devflow distill)
    ↓
  D0: session.status = "distilling"
    ↓
  D1-D3: journal compression, lifecycle review, promotion assessment
    ↓
  D4 (optional, /devflow export):
    → session.status = "exporting" → export → session.status = "exported"
    ↓
  D5: index self-cleaning
    ↓
  D6: session.status = "distilled"
    ↓
  END → STOP (counters reset)
```

**Orchestration Rules:**
- Read `session.status` BEFORE deciding what actions are valid
- Update `session.status` EXACTLY as documented at each phase transition
- Append to `events.jsonl` ONLY at final state of each mode (P4, C5, R5, D6)
- NEVER modify `session.status` outside the documented phases
