# DEVFLOW v1.7 Templates

Templates for creating DEVFLOW memory items in v1.7 format (Markdown per category).

## Quick Start

Copy the relevant template to your `.agent/memory/` directory:

```bash
# Create a new rule in data_and_schema category
cp templates/examples/RULE_TEMPLATE.md .agent/memory/rules/data_and_schema/R-001.md

# Create a new decision in infra_and_deploy category
cp templates/examples/ADR_TEMPLATE.md .agent/memory/decisions/infra_and_deploy/ADR-001.md

# Create a new contract in react_and_ui category
cp templates/examples/CONTRACT_TEMPLATE.md .agent/memory/contracts/react_and_ui/CON-001.md

# Create a new anti-pattern in process_and_testing category
cp templates/examples/ANTI_PATTERN_TEMPLATE.md .agent/memory/anti-patterns/process_and_testing/AP-001.md

# Create a knowledge item
cp templates/examples/KNOWLEDGE_TEMPLATE.md .agent/memory/knowledge/mobile_and_platform/K-001.md
```

## Directory Structure

```
.agent/memory/
├── rules/                    # Coding rules & constraints
│   ├── data_and_schema/
│   ├── infra_and_deploy/
│   ├── mobile_and_platform/
│   ├── react_and_ui/
│   ├── process_and_testing/
│   └── RULES_INDEX.md        # Auto-generated index
├── anti-patterns/            # Patterns to avoid
│   ├── data_and_schema/
│   ├── infra_and_deploy/
│   ├── mobile_and_platform/
│   ├── react_and_ui/
│   ├── process_and_testing/
│   └── ANTI_PATTERNS_INDEX.md
├── decisions/                # Architecture Decision Records
│   ├── data_and_schema/
│   ├── infra_and_deploy/
│   ├── mobile_and_platform/
│   ├── react_and_ui/
│   ├── process_and_testing/
│   └── DECISIONS_INDEX.md
├── contracts/                # Service contracts & interfaces
│   ├── data_and_schema/
│   ├── infra_and_deploy/
│   ├── mobile_and_platform/
│   ├── react_and_ui/
│   ├── process_and_testing/
│   └── CONTRACTS_INDEX.md
├── knowledge/                # Facts & technical information
│   ├── data_and_schema/
│   ├── infra_and_deploy/
│   ├── mobile_and_platform/
│   ├── react_and_ui/
│   ├── process_and_testing/
│   └── KNOWLEDGE_INDEX.md
└── journal/                  # Session logs & distillations
    ├── [session-date].md
    └── archive/
```

## Categories

Use these categories to organize your memory items:

| Category | Use for |
|----------|---------|
| **data_and_schema** | Database, Zod schemas, APIs, data validation |
| **infra_and_deploy** | Infrastructure, CI/CD, deployments, environment |
| **mobile_and_platform** | Mobile-specific code, platform features |
| **react_and_ui** | React components, hooks, UI patterns |
| **process_and_testing** | Testing, QA, development processes |

## Templates

### Rule Template (`RULE_TEMPLATE.md`)
Use for coding rules and constraints. Examples:
- R-001: ALWAYS use parseLocalDate for dates
- R-002: NEVER use new Date('YYYY-MM-DD')
- R-003: Validate input with Zod safeParse()

### ADR Template (`ADR_TEMPLATE.md`)
Architecture Decision Records. Examples:
- ADR-001: Feature flag infrastructure for gradual rollouts
- ADR-002: CSV vs JSON for configuration storage
- ADR-003: Monorepo vs multi-repo structure

### Anti-Pattern Template (`ANTI_PATTERN_TEMPLATE.md`)
Patterns to avoid. Examples:
- AP-001: Using new Date('YYYY-MM-DD')
- AP-002: Mutating state directly in React
- AP-003: Skipping validation at service boundaries

### Contract Template (`CONTRACT_TEMPLATE.md`)
Service contracts and interfaces. Examples:
- CON-001: useAuth hook API
- CON-002: PaymentService interface
- CON-003: Logger service contract

### Knowledge Template (`KNOWLEDGE_TEMPLATE.md`)
Reusable facts and information. Examples:
- K-001: Project tech stack
- K-002: Stock level thresholds
- K-003: Supabase RLS patterns

## File Naming

- **Rules:** `R-NNN.md` (e.g., R-001.md, R-020.md)
- **ADRs:** `ADR-NNN.md` (e.g., ADR-001.md, ADR-017.md)
- **Anti-Patterns:** `AP-NNN.md` (e.g., AP-001.md, AP-058.md)
- **Contracts:** `CON-NNN.md` (e.g., CON-001.md, CON-015.md)
- **Knowledge:** `K-NNN.md` (e.g., K-001.md, K-042.md)

## After Creating an Item

1. **Update the INDEX.md:** Add your item to the appropriate `*_INDEX.md`
2. **Tag properly:** Add relevant tags for filtering
3. **Link related items:** Cross-reference rules, decisions, and anti-patterns
4. **Git commit:** Track memory items in version control

## Example: Creating a Rule

```bash
# 1. Copy template
cp templates/examples/RULE_TEMPLATE.md .agent/memory/rules/react_and_ui/R-050.md

# 2. Edit R-050.md
# - Change id to R-050
# - Replace [Concise rule title] with actual title
# - Fill in Rule, Why, Examples, etc.
# - Set applies_to, tags, review_due

# 3. Update RULES_INDEX.md
# - Add entry under "⚛️ React & UI" section

# 4. Commit
git add .agent/memory/rules/react_and_ui/R-050.md .agent/memory/RULES_INDEX.md
git commit -m "rule(react-ui): R-050 — Use useCallback for memoized callbacks"
```

## Validation

Run this to check for missing fields in your items:

```bash
# Check all rules for required frontmatter
grep -L "^id:" .agent/memory/rules/*/*.md

# Check all ADRs have a status
grep -L "^status:" .agent/memory/decisions/*/*.md
```

## See Also

- `DEVFLOW.md` — Full specification
- `README.md` — User-facing DEVFLOW documentation
- `examples/` — Complete example items from dosiq project
