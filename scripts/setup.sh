#!/usr/bin/env bash
# DEVFLOW Setup Script v1.7.0
# Usage: bash setup.sh <project-path> <project-name> <stack-csv>
# Example: bash setup.sh ~/git/my-app "my-app" "react,vite,supabase,typescript"

set -e

DEVFLOW_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GLOBAL_BASE="$HOME/.devflow/global_base"

# ─── Args ────────────────────────────────────────────────────────────────────
PROJECT_PATH="${1:?Usage: setup.sh <project-path> <project-name> <stack-csv>}"
PROJECT_NAME="${2:?Usage: setup.sh <project-path> <project-name> <stack-csv>}"
STACK_CSV="${3:-unknown}"
PROJECT_SLUG=$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd '[:alnum:]-')
CURRENT_SPRINT=$(date +%Y-W%V)

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║  DEVFLOW Setup — $PROJECT_NAME"
echo "╚══════════════════════════════════════════╝"
echo ""

# ─── 1. Create directory structure ───────────────────────────────────────────
echo "→ Creating .agent/ directory structure..."
AGENT_DIR="$PROJECT_PATH/.agent"

# Detail dirs use category subdirs (e.g. rules/mobile_and_platform/R-NNN.md)
# No _detail suffix — categories are created on-demand during development
mkdir -p "$AGENT_DIR/memory/rules"
mkdir -p "$AGENT_DIR/memory/anti-patterns"
mkdir -p "$AGENT_DIR/memory/contracts"
mkdir -p "$AGENT_DIR/memory/decisions"
mkdir -p "$AGENT_DIR/memory/knowledge"
mkdir -p "$AGENT_DIR/memory/journal/archive"
mkdir -p "$AGENT_DIR/evolution"
mkdir -p "$AGENT_DIR/sessions"
mkdir -p "$AGENT_DIR/synthesis"

echo "  ✓ Directory tree created"

# ─── 2. Symlink DEVFLOW.md (always points to master, never stale) ────────────
ln -sf "$DEVFLOW_DIR/DEVFLOW.md" "$AGENT_DIR/DEVFLOW.md"
echo "  ✓ DEVFLOW.md symlinked → $DEVFLOW_DIR/DEVFLOW.md"

# ─── 3. Initialize state.json ────────────────────────────────────────────────
cat > "$AGENT_DIR/state.json" << EOF
{
  "schema_version": "1.0",
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
    "last_distillation": null,
    "journal_entries_since_distillation": 0
  },
  "evolution": {
    "genes_version": "1.0",
    "pending_mutations": []
  },
  "quality_gates": {
    "index_loaded_at": null,
    "relevant_rules_loaded_at": null
  }
}
EOF
echo "  ✓ state.json initialized"

# ─── 4. Initialize empty JSON index files ────────────────────────────────────
echo "[]" > "$AGENT_DIR/memory/rules.json"
echo "[]" > "$AGENT_DIR/memory/anti-patterns.json"
echo "[]" > "$AGENT_DIR/memory/contracts.json"
echo "[]" > "$AGENT_DIR/memory/decisions.json"
echo "[]" > "$AGENT_DIR/memory/knowledge.json"
echo "  ✓ JSON index files initialized (empty)"

# ─── 5. Initialize Markdown Sparse Index files ───────────────────────────────
# These are the primary bootstrap files agents read (Index-First protocol).
# Format: Markdown table — one row per rule/AP/contract/decision/fact.

cat > "$AGENT_DIR/memory/RULES_INDEX.md" << 'MDEOF'
# Rules Index

| id | title | layer | status | tags | applies_to |
|----|-------|-------|--------|------|------------|
MDEOF

cat > "$AGENT_DIR/memory/ANTI_PATTERNS_INDEX.md" << 'MDEOF'
# Anti-Patterns Index

| id | title | layer | status | trigger_count | tags |
|----|-------|-------|--------|---------------|------|
MDEOF

cat > "$AGENT_DIR/memory/CONTRACTS_INDEX.md" << 'MDEOF'
# Contracts Index

| id | title | status | interface | consumers | tags |
|----|-------|--------|-----------|-----------|------|
MDEOF

cat > "$AGENT_DIR/memory/DECISIONS_INDEX.md" << 'MDEOF'
# Decisions Index (ADRs)

| id | title | status | date | tags |
|----|-------|--------|------|------|
MDEOF

cat > "$AGENT_DIR/memory/KNOWLEDGE_INDEX.md" << 'MDEOF'
# Knowledge Index

| id | title | category | tags |
|----|-------|----------|------|
MDEOF

echo "  ✓ Markdown Sparse Index files initialized (RULES_INDEX.md, ANTI_PATTERNS_INDEX.md, CONTRACTS_INDEX.md, DECISIONS_INDEX.md, KNOWLEDGE_INDEX.md)"

# ─── 6. Copy genes.json from template ────────────────────────────────────────
cp "$DEVFLOW_DIR/templates/genes.json" "$AGENT_DIR/evolution/genes.json"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
sed -i.bak "s/\"last_modified\": null/\"last_modified\": \"$TIMESTAMP\"/" "$AGENT_DIR/evolution/genes.json"
rm -f "$AGENT_DIR/evolution/genes.json.bak"
echo "  ✓ genes.json initialized with defaults"

# ─── 7. Initialize evolution_log.jsonl ───────────────────────────────────────
echo "{\"timestamp\":\"$TIMESTAMP\",\"event\":\"devflow_initialized\",\"version\":\"1.7.0\",\"project\":\"$PROJECT_SLUG\"}" > "$AGENT_DIR/evolution/evolution_log.jsonl"
echo "  ✓ evolution_log.jsonl initialized"

# ─── 8. Initialize sessions files ────────────────────────────────────────────
echo "" > "$AGENT_DIR/sessions/.lock"
echo "{\"timestamp\":\"$TIMESTAMP\",\"event\":\"devflow_initialized\",\"project\":\"$PROJECT_SLUG\"}" > "$AGENT_DIR/sessions/events.jsonl"
echo "  ✓ sessions/.lock and events.jsonl initialized"

# ─── 9. Initialize synthesis/pending_export.json ─────────────────────────────
echo "[]" > "$AGENT_DIR/synthesis/pending_export.json"
echo "  ✓ synthesis/pending_export.json initialized"

# ─── 10. Update .gitignore ───────────────────────────────────────────────────
GITIGNORE="$PROJECT_PATH/.gitignore"
if [ -f "$GITIGNORE" ]; then
  if ! grep -q "\.agent/sessions/" "$GITIGNORE"; then
    cat >> "$GITIGNORE" << 'EOF'

# DEVFLOW runtime files (not versioned)
.agent/DEVFLOW.md
.agent/sessions/.lock
.agent/sessions/events.jsonl
EOF
    echo "  ✓ .gitignore updated (DEVFLOW.md symlink, sessions/.lock and events.jsonl excluded)"
  else
    echo "  ℹ .gitignore already has DEVFLOW entries — skipped"
  fi
else
  cat > "$GITIGNORE" << 'EOF'
# DEVFLOW runtime files (not versioned)
.agent/DEVFLOW.md
.agent/sessions/.lock
.agent/sessions/events.jsonl
EOF
  echo "  ✓ .gitignore created with DEVFLOW entries"
fi

# ─── 11. Import from global base (if available) ──────────────────────────────
echo ""
if [ -d "$GLOBAL_BASE" ]; then
  UNIVERSAL_RULES="$GLOBAL_BASE/universal_rules.json"
  UNIVERSAL_APS="$GLOBAL_BASE/universal_anti_patterns.json"

  if [ -f "$UNIVERSAL_RULES" ]; then
    RULES_COUNT=$(python3 -c "import json; data=json.load(open('$UNIVERSAL_RULES')); print(len(data))" 2>/dev/null || echo "?")
    echo "→ Global base found — importing $RULES_COUNT universal rules..."
    cp "$UNIVERSAL_RULES" "$AGENT_DIR/memory/rules.json"

    # Detail files live in rules/[category]/ (not rules_detail/)
    if [ -d "$GLOBAL_BASE/rules" ]; then
      cp -r "$GLOBAL_BASE/rules/." "$AGENT_DIR/memory/rules/"
    fi

    # Rebuild RULES_INDEX.md from imported JSON
    if command -v python3 &>/dev/null; then
      python3 -c "
import json
with open('$AGENT_DIR/memory/rules.json') as f:
    rules = json.load(f)
lines = ['# Rules Index', '', '| id | title | layer | status | tags | applies_to |', '|----|-------|-------|--------|------|------------|']
for r in rules:
    tags = ', '.join(r.get('tags', []))
    applies = ', '.join(r.get('applies_to', []))
    lines.append(f\"| {r.get('id','')} | {r.get('title','')} | {r.get('layer','')} | {r.get('status','')} | {tags} | {applies} |\")
with open('$AGENT_DIR/memory/RULES_INDEX.md', 'w') as f:
    f.write('\n'.join(lines) + '\n')
print(f'  ✓ RULES_INDEX.md rebuilt ({len(rules)} rules)')
"
    fi

    # Update rules_count in state.json
    if command -v python3 &>/dev/null; then
      python3 -c "
import json
with open('$AGENT_DIR/state.json') as f:
    state = json.load(f)
with open('$AGENT_DIR/memory/rules.json') as f:
    rules = json.load(f)
state['memory']['rules_count'] = len(rules)
with open('$AGENT_DIR/state.json', 'w') as f:
    json.dump(state, f, indent=2)
"
    fi
    echo "  ✓ $RULES_COUNT GR-NNN rules imported"
  fi

  if [ -f "$UNIVERSAL_APS" ]; then
    APS_COUNT=$(python3 -c "import json; data=json.load(open('$UNIVERSAL_APS')); print(len(data))" 2>/dev/null || echo "?")
    echo "→ Importing $APS_COUNT universal anti-patterns..."
    cp "$UNIVERSAL_APS" "$AGENT_DIR/memory/anti-patterns.json"

    # Detail files live in anti-patterns/[category]/ (not anti-patterns_detail/)
    if [ -d "$GLOBAL_BASE/anti-patterns" ]; then
      cp -r "$GLOBAL_BASE/anti-patterns/." "$AGENT_DIR/memory/anti-patterns/"
    fi

    # Rebuild ANTI_PATTERNS_INDEX.md from imported JSON
    if command -v python3 &>/dev/null; then
      python3 -c "
import json
with open('$AGENT_DIR/memory/anti-patterns.json') as f:
    aps = json.load(f)
lines = ['# Anti-Patterns Index', '', '| id | title | layer | status | trigger_count | tags |', '|----|-------|-------|--------|---------------|------|']
for ap in aps:
    tags = ', '.join(ap.get('tags', []))
    lines.append(f\"| {ap.get('id','')} | {ap.get('title','')} | {ap.get('layer','')} | {ap.get('status','')} | {ap.get('trigger_count',0)} | {tags} |\")
with open('$AGENT_DIR/memory/ANTI_PATTERNS_INDEX.md', 'w') as f:
    f.write('\n'.join(lines) + '\n')
print(f'  ✓ ANTI_PATTERNS_INDEX.md rebuilt ({len(aps)} anti-patterns)')
"
    fi

    # Update anti_patterns_count in state.json
    if command -v python3 &>/dev/null; then
      python3 -c "
import json
with open('$AGENT_DIR/state.json') as f:
    state = json.load(f)
with open('$AGENT_DIR/memory/anti-patterns.json') as f:
    aps = json.load(f)
state['memory']['anti_patterns_count'] = len(aps)
with open('$AGENT_DIR/state.json', 'w') as f:
    json.dump(state, f, indent=2)
"
    fi
    echo "  ✓ $APS_COUNT GAP-NNN anti-patterns imported"
  fi
else
  echo "ℹ No global base found at ~/.devflow/global_base/"
  echo "  Starting with empty memory. Run /devflow export after your first project matures."
fi

# ─── Done ────────────────────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════╗"
echo "║  DEVFLOW setup complete!  (v1.7.0)       ║"
echo "╚══════════════════════════════════════════╝"
echo ""
echo "Next steps (manual):"
echo "  1. Populate .agent/memory/knowledge.json with stack-specific facts"
echo "     (see templates/schema-reference.md for format)"
echo "  2. Run: /devflow status"
echo "  3. Start your first session: /devflow planning \"describe project goals\""
echo ""
echo "Files created:"
find "$AGENT_DIR" -type f | sed "s|$PROJECT_PATH/||" | sort | sed 's/^/  /'
echo ""
