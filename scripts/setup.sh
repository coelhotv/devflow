#!/usr/bin/env bash
# DEVFLOW Setup Script v1.7.0
# Usage: bash setup.sh <project-path> <project-name> <stack-csv>
# Example: bash setup.sh ~/git/my-app "my-app" "react,vite,supabase,typescript"

set -e

DEVFLOW_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ─── Args ────────────────────────────────────────────────────────────────────
PROJECT_PATH="${1:?Usage: setup.sh <project-path> <project-name> <stack-csv>}"
PROJECT_NAME="${2:?Usage: setup.sh <project-path> <project-name> <stack-csv>}"
STACK_CSV="${3:-unknown}"
PROJECT_SLUG=$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd '[:alnum:]-')
CURRENT_SPRINT=$(date +%Y-W%V)

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║  DEVFLOW v1.7 Setup — $PROJECT_NAME"
echo "╚══════════════════════════════════════════╝"
echo ""

# ─── 1. Create directory structure ───────────────────────────────────────────
echo "→ Creating .agent/memory structure (v1.7 with categories)..."
AGENT_DIR="$PROJECT_PATH/.agent"
MEMORY_DIR="$AGENT_DIR/memory"

# Categories: data_and_schema, infra_and_deploy, mobile_and_platform, react_and_ui, process_and_testing
CATEGORIES=("data_and_schema" "infra_and_deploy" "mobile_and_platform" "react_and_ui" "process_and_testing")

# Create memory type dirs with category subdirs
for type in rules anti-patterns decisions contracts knowledge; do
  mkdir -p "$MEMORY_DIR/$type"
  for cat in "${CATEGORIES[@]}"; do
    mkdir -p "$MEMORY_DIR/$type/$cat"
  done
done

# Create journal with archive
mkdir -p "$MEMORY_DIR/journal/archive"

# Create evolution, sessions, synthesis
mkdir -p "$AGENT_DIR/evolution"
mkdir -p "$AGENT_DIR/sessions"
mkdir -p "$AGENT_DIR/synthesis"

echo "  ✓ Directory tree created with 5 categories"

# ─── 2. Symlink DEVFLOW.md ──────────────────────────────────────────────────
ln -sf "$DEVFLOW_DIR/DEVFLOW.md" "$AGENT_DIR/DEVFLOW.md"
echo "  ✓ DEVFLOW.md symlinked"

# ─── 3. Initialize state.json ────────────────────────────────────────────────
cat > "$AGENT_DIR/state.json" << EOF
{
  "schema_version": "1.7",
  "project": {
    "name": "$PROJECT_NAME",
    "slug": "$PROJECT_SLUG",
    "stack": [$(echo "$STACK_CSV" | sed 's/,/","/g' | sed 's/^/"/' | sed 's/$/"/')],
    "phase": "initial",
    "current_sprint": "$CURRENT_SPRINT"
  },
  "session": {
    "id": null,
    "started_at": null,
    "mode": null,
    "goal": null,
    "goal_type": null,
    "status": "idle"
  },
  "memory": {
    "rules_count": 0,
    "anti_patterns_count": 0,
    "decisions_count": 0,
    "contracts_count": 0,
    "knowledge_count": 0,
    "last_distillation": null,
    "journal_entries_since_distillation": 0
  },
  "evolution": {
    "genes_version": "1.7",
    "pending_mutations": []
  },
  "quality_gates": {
    "index_loaded_at": null,
    "relevant_rules_loaded_at": null
  }
}
EOF
echo "  ✓ state.json initialized (v1.7 schema)"

# ─── 4. Generate empty INDEX.md files ────────────────────────────────────────

# RULES_INDEX.md
cat > "$MEMORY_DIR/RULES_INDEX.md" << 'EOF'
# DEVFLOW Rules Index

Index is auto-populated as rules are added. Rules are organized by category.

## 📦 Data & Schema (`rules/data_and_schema`)

*No rules yet. Add rules here with format: `R-NNN.md`*

## 🚀 Infra & Deploy (`rules/infra_and_deploy`)

*No rules yet. Add rules here with format: `R-NNN.md`*

## 📱 Mobile & Platform (`rules/mobile_and_platform`)

*No rules yet. Add rules here with format: `R-NNN.md`*

## ⚛️ React & UI (`rules/react_and_ui`)

*No rules yet. Add rules here with format: `R-NNN.md`*

## 🧪 Process & Testing (`rules/process_and_testing`)

*No rules yet. Add rules here with format: `R-NNN.md`*

---

## Quick Links

- [Template](./templates/examples/RULE_TEMPLATE.md) — Copy to create new rule
- [DEVFLOW Schema](../DEVFLOW.md) — Full specification
EOF
echo "  ✓ RULES_INDEX.md created"

# ANTI_PATTERNS_INDEX.md
cat > "$MEMORY_DIR/ANTI_PATTERNS_INDEX.md" << 'EOF'
# DEVFLOW Anti-Patterns Index

Index is auto-populated as anti-patterns are added. Patterns are organized by category.

## 📦 Data & Schema (`anti-patterns/data_and_schema`)

*No anti-patterns yet. Add patterns here with format: `AP-NNN.md`*

## 🚀 Infra & Deploy (`anti-patterns/infra_and_deploy`)

*No anti-patterns yet. Add patterns here with format: `AP-NNN.md`*

## 📱 Mobile & Platform (`anti-patterns/mobile_and_platform`)

*No anti-patterns yet. Add patterns here with format: `AP-NNN.md`*

## ⚛️ React & UI (`anti-patterns/react_and_ui`)

*No anti-patterns yet. Add patterns here with format: `AP-NNN.md`*

## 🧪 Process & Testing (`anti-patterns/process_and_testing`)

*No anti-patterns yet. Add patterns here with format: `AP-NNN.md`*

---

## Quick Links

- [Template](./templates/examples/ANTI_PATTERN_TEMPLATE.md) — Copy to create new pattern
- [DEVFLOW Schema](../DEVFLOW.md) — Full specification
EOF
echo "  ✓ ANTI_PATTERNS_INDEX.md created"

# DECISIONS_INDEX.md
cat > "$MEMORY_DIR/DECISIONS_INDEX.md" << 'EOF'
# DEVFLOW Decisions Index

Architecture Decision Records (ADRs) are organized by category.

## 📦 Data & Schema (`decisions/data_and_schema`)

*No decisions yet. Add ADRs here with format: `ADR-NNN.md`*

## 🚀 Infra & Deploy (`decisions/infra_and_deploy`)

*No decisions yet. Add ADRs here with format: `ADR-NNN.md`*

## 📱 Mobile & Platform (`decisions/mobile_and_platform`)

*No decisions yet. Add ADRs here with format: `ADR-NNN.md`*

## ⚛️ React & UI (`decisions/react_and_ui`)

*No decisions yet. Add ADRs here with format: `ADR-NNN.md`*

## 🧪 Process & Testing (`decisions/process_and_testing`)

*No decisions yet. Add ADRs here with format: `ADR-NNN.md`*

---

## Quick Links

- [Template](./templates/examples/ADR_TEMPLATE.md) — Copy to create new ADR
- [DEVFLOW Schema](../DEVFLOW.md) — Full specification
EOF
echo "  ✓ DECISIONS_INDEX.md created"

# CONTRACTS_INDEX.md
cat > "$MEMORY_DIR/CONTRACTS_INDEX.md" << 'EOF'
# DEVFLOW Contracts Index

Service contracts, API specs, and interfaces organized by category.

## 📦 Data & Schema (`contracts/data_and_schema`)

*No contracts yet. Add contracts here with format: `CON-NNN.md`*

## 🚀 Infra & Deploy (`contracts/infra_and_deploy`)

*No contracts yet. Add contracts here with format: `CON-NNN.md`*

## 📱 Mobile & Platform (`contracts/mobile_and_platform`)

*No contracts yet. Add contracts here with format: `CON-NNN.md`*

## ⚛️ React & UI (`contracts/react_and_ui`)

*No contracts yet. Add contracts here with format: `CON-NNN.md`*

## 🧪 Process & Testing (`contracts/process_and_testing`)

*No contracts yet. Add contracts here with format: `CON-NNN.md`*

---

## Quick Links

- [Template](./templates/examples/CONTRACT_TEMPLATE.md) — Copy to create new contract
- [DEVFLOW Schema](../DEVFLOW.md) — Full specification
EOF
echo "  ✓ CONTRACTS_INDEX.md created"

# KNOWLEDGE_INDEX.md
cat > "$MEMORY_DIR/KNOWLEDGE_INDEX.md" << 'EOF'
# DEVFLOW Knowledge Index

Reusable facts, specs, and technical information organized by category.

## 📦 Data & Schema (`knowledge/data_and_schema`)

*No knowledge yet. Add facts here with format: `K-NNN.md`*

## 🚀 Infra & Deploy (`knowledge/infra_and_deploy`)

*No knowledge yet. Add facts here with format: `K-NNN.md`*

## 📱 Mobile & Platform (`knowledge/mobile_and_platform`)

*No knowledge yet. Add facts here with format: `K-NNN.md`*

## ⚛️ React & UI (`knowledge/react_and_ui`)

*No knowledge yet. Add facts here with format: `K-NNN.md`*

## 🧪 Process & Testing (`knowledge/process_and_testing`)

*No knowledge yet. Add facts here with format: `K-NNN.md`*

---

## Quick Links

- [Template](./templates/examples/KNOWLEDGE_TEMPLATE.md) — Copy to create new fact
- [DEVFLOW Schema](../DEVFLOW.md) — Full specification
EOF
echo "  ✓ KNOWLEDGE_INDEX.md created"

# ─── 5. Create .gitignore entry ──────────────────────────────────────────────
if [ -f "$PROJECT_PATH/.gitignore" ]; then
  if ! grep -q ".agent/" "$PROJECT_PATH/.gitignore"; then
    echo "" >> "$PROJECT_PATH/.gitignore"
    echo "# DEVFLOW runtime" >> "$PROJECT_PATH/.gitignore"
    echo ".agent/sessions/" >> "$PROJECT_PATH/.gitignore"
    echo ".agent/synthesis/" >> "$PROJECT_PATH/.gitignore"
    echo ".agent/evolution/" >> "$PROJECT_PATH/.gitignore"
    echo ".agent/state.json" >> "$PROJECT_PATH/.gitignore"
    echo "# Keep memory (rules, ADRs, etc.) in git" >> "$PROJECT_PATH/.gitignore"
  fi
  echo "  ✓ .gitignore updated"
else
  echo "  ⚠ No .gitignore found (skip)"
fi

# ─── 6. Print summary ────────────────────────────────────────────────────────
echo ""
echo "✓ DEVFLOW v1.7 setup complete!"
echo ""
echo "Next steps:"
echo "  1. Add rules: cp templates/examples/RULE_TEMPLATE.md .agent/memory/rules/react_and_ui/R-001.md"
echo "  2. Add decisions: cp templates/examples/ADR_TEMPLATE.md .agent/memory/decisions/data_and_schema/ADR-001.md"
echo "  3. Review RULES_INDEX.md and other indexes as you add items"
echo "  4. Invoke /devflow in Claude Code to start using the skill"
echo ""
