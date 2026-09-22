#!/usr/bin/env bash
# DEVFLOW Setup Script v3.0.0
# Usage: bash setup.sh <project-path> <project-name> <stack-csv> [--with-git-hook]
# Example: bash setup.sh ~/git/my-app "my-app" "react,vite,supabase,typescript"
#
# Idempotente (spec 002 / INV-1): nunca sobrescreve arquivo existente em .agent/. Rodar de novo
# so cria o que falta e reporta o que foi pulado.

set -e

DEVFLOW_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ─── Args ────────────────────────────────────────────────────────────────────
PROJECT_PATH="${1:?Usage: setup.sh <project-path> <project-name> <stack-csv> [--with-git-hook]}"
PROJECT_NAME="${2:?Usage: setup.sh <project-path> <project-name> <stack-csv> [--with-git-hook]}"
STACK_CSV="${3:-unknown}"
shift 3 2>/dev/null || true
WITH_GIT_HOOK=0
for a in "$@"; do
  case "$a" in
    --with-git-hook) WITH_GIT_HOOK=1 ;;
    *) echo "flag desconhecida: $a" >&2; exit 2 ;;
  esac
done
PROJECT_SLUG=$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd '[:alnum:]-')
CURRENT_SPRINT=$(date +%Y-W%V)

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║  DEVFLOW v3.0 Setup — $PROJECT_NAME"
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

# Create evolution, sessions
# (synthesis/ was the staging area of the cross-project export, RETIRED 2026-09-04 — see SKILL.md D4)
mkdir -p "$AGENT_DIR/evolution"
mkdir -p "$AGENT_DIR/sessions"

echo "  ✓ Directory tree created with 5 categories"

# ─── 2. Symlink DEVFLOW.md ──────────────────────────────────────────────────
ln -sf "$DEVFLOW_DIR/DEVFLOW.md" "$AGENT_DIR/DEVFLOW.md"
echo "  ✓ DEVFLOW.md symlinked"

# ─── 3. Initialize state.json (idempotente — INV-1) ─────────────────────────
if [ -f "$AGENT_DIR/state.json" ]; then
  echo "  · state.json ja existe — pulado"
else
  cat > "$AGENT_DIR/state.json" << EOF
{
  "schema_version": "3.0",
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
    "status": "idle",
    "handoff": null
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
    "genes_version": "3.0",
    "pending_mutations": []
  },
  "quality_gates": {
    "index_loaded_at": null,
    "relevant_rules_loaded_at": null
  }
}
EOF
  echo "  ✓ state.json initialized (v3.0 schema)"
fi

# ─── 4. Generate empty INDEX.md files ────────────────────────────────────────

# RULES_INDEX.md
if [ -f "$MEMORY_DIR/RULES_INDEX.md" ]; then
  echo "  · RULES_INDEX.md ja existe — pulado"
else
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
fi

# ANTI_PATTERNS_INDEX.md
if [ -f "$MEMORY_DIR/ANTI_PATTERNS_INDEX.md" ]; then
  echo "  · ANTI_PATTERNS_INDEX.md ja existe — pulado"
else
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
fi

# DECISIONS_INDEX.md
if [ -f "$MEMORY_DIR/DECISIONS_INDEX.md" ]; then
  echo "  · DECISIONS_INDEX.md ja existe — pulado"
else
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
fi

# CONTRACTS_INDEX.md
if [ -f "$MEMORY_DIR/CONTRACTS_INDEX.md" ]; then
  echo "  · CONTRACTS_INDEX.md ja existe — pulado"
else
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
fi

# KNOWLEDGE_INDEX.md
if [ -f "$MEMORY_DIR/KNOWLEDGE_INDEX.md" ]; then
  echo "  · KNOWLEDGE_INDEX.md ja existe — pulado"
else
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
fi

# ─── 4b. Create the two lifecycle ledgers (PO-2 / spec 002) ─────────────────
# Vazios de proposito: o relogio de cada um so comeca a contar quando o arquivo e
# COMMITADO (FR-003 — derivado do git, Q1 decidida). Ver aviso no resumo final.
for ledger in process-friction.jsonl attempts.jsonl; do
  L="$MEMORY_DIR/$ledger"
  if [ -f "$L" ]; then
    echo "  · $ledger ja existe — pulado"
  else
    : > "$L"
    echo "  ✓ $ledger created (vazio)"
  fi
done

# ─── 5. .gitignore: cria se falta, completa linha a linha se parcial ────────
GITIGNORE="$PROJECT_PATH/.gitignore"
GITIGNORE_LINES=(".agent/sessions/" ".agent/evolution/" ".agent/state.json")
if [ ! -f "$GITIGNORE" ]; then
  {
    echo "# DEVFLOW runtime"
    for l in "${GITIGNORE_LINES[@]}"; do echo "$l"; done
    echo "# Keep memory (rules, ADRs, etc.) in git"
  } > "$GITIGNORE"
  echo "  ✓ .gitignore created"
else
  added=0
  for l in "${GITIGNORE_LINES[@]}"; do
    grep -qxF "$l" "$GITIGNORE" || { echo "$l" >> "$GITIGNORE"; added=$((added+1)); }
  done
  if [ "$added" -gt 0 ]; then
    echo "  ✓ .gitignore updated ($added linha(s) adicionada(s))"
  else
    echo "  · .gitignore ja tem todas as entradas — pulado"
  fi
fi

# ─── 5b2. --with-git-hook: nivel 2 do FR-003 (mode-gate.sh), opcional ──────
if [ "$WITH_GIT_HOOK" = 1 ]; then
  GIT_HOOKS_DIR="$PROJECT_PATH/.git/hooks"
  if [ -d "$GIT_HOOKS_DIR" ]; then
    HOOK_FILE="$GIT_HOOKS_DIR/pre-commit"
    if [ -e "$HOOK_FILE" ]; then
      echo "  ⚠ $HOOK_FILE ja existe — nao sobrescrito (instale a mao se quiser o mode-gate)"
    else
      cat > "$HOOK_FILE" << HOOKEOF
#!/usr/bin/env bash
# Instalado por setup.sh --with-git-hook (spec 002, FR-006).
# Nivel 2 do FR-003 (spec 001): so INVOCA o nivel 1 (mode-gate.sh), nunca copia sua logica.
# Fail-open por design — ver o cabecalho de mode-gate.sh.
GATE="$DEVFLOW_DIR/scripts/mode-gate.sh"
[ -x "\$GATE" ] || exit 0
[ -f .agent/state.json ] || exit 0
out="\$("\$GATE" --state .agent/state.json)"
ok="\$(printf '%s' "\$out" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("ok", True))' 2>/dev/null)"
if [ "\$ok" = "False" ]; then
  echo "DEVFLOW mode-gate bloqueou o commit: \$out" >&2
  exit 1
fi
exit 0
HOOKEOF
      chmod +x "$HOOK_FILE"
      echo "  ✓ pre-commit hook instalado ($HOOK_FILE)"
    fi
  else
    echo "  ⚠ $GIT_HOOKS_DIR nao existe (repo sem git init?) — hook nao instalado"
  fi
fi

# ─── 5b. Install the DEVFLOW sub-skills ─────────────────────────────────────
# As 6 sub-skills sao versionadas DENTRO deste repo, mas a descoberta olha UM nivel
# abaixo de ~/.claude/skills/ — sub-skill aninhada nao e encontrada. Sem este passo o
# operador tem 1 skill em vez de 7, e descobre pela AUSENCIA (falha silenciosa).
echo "→ Installing DEVFLOW sub-skills..."
SKILL_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [ -x "$SKILL_ROOT/scripts/install-skills.sh" ]; then
  if bash "$SKILL_ROOT/scripts/install-skills.sh"; then
    echo "  ✓ sub-skills linked"
  else
    # NAO abortar o setup do projeto por causa disto — mas tambem NAO relatar sucesso.
    echo "  ⚠ sub-skill install FAILED (see above). Only /devflow is available; run scripts/install-skills.sh by hand." >&2
  fi
else
  echo "  ⚠ scripts/install-skills.sh not found (skip)"
fi

# ─── 6. Print summary ────────────────────────────────────────────────────────
echo ""
echo "✓ DEVFLOW v3.0 setup complete!"
echo ""
echo "⚠ O relogio dos ledgers so comeca no commit que adicionar cada arquivo ao git"
echo "  (process-friction.jsonl / attempts.jsonl — marco derivado do git, spec 002 Q1)."
echo "  Ate la, cada ledger conta como inativo."
echo ""
echo "Next steps:"
echo "  1. Add rules: cp templates/examples/RULE_TEMPLATE.md .agent/memory/rules/react_and_ui/R-001.md"
echo "  2. Add decisions: cp templates/examples/ADR_TEMPLATE.md .agent/memory/decisions/data_and_schema/ADR-001.md"
echo "  3. Review RULES_INDEX.md and other indexes as you add items"
echo "  4. Invoke /devflow in Claude Code to start using the skill"
echo "     (modes: /devflow-spec · /devflow-plan · /devflow-ceremony · /devflow-code · /devflow-ideation · /devflow-distill)"
echo ""
