# EXEC_SPEC_DEVFLOW_AGENT_SKILLS_UPGRADE.md

## Objetivo

Atualizar `/Users/coelhotv/SKILLS/devflow` usando aprendizados de `/Users/coelhotv/git-icloud/agent-skills`, sem copiar o pacote inteiro. Preservar identidade DEVFLOW: memória persistente em `.agent/`, carregamento index-first, gates contratuais, modos explícitos e `Assess -> Execute -> Record`.

Resultado esperado: skill mais enxuta, prescritiva, fácil de carregar por agentes, com referências sob demanda, verificação por evidência e menos drift documental.

## Restrições Obrigatórias

- Não transformar DEVFLOW em clone de `agent-skills`.
- Não remover: Phase 0 Bootstrap, Hard Stop Rule, C2 Contract Gateway, C5 Record Protocol, locking, distillation.
- Manter `SKILL.md` agent-neutral. Não tornar texto específico de Codex.
- Não assumir `RTK.md`: arquivo não existe em `/Users/coelhotv/SKILLS/devflow`; registrar como lacuna, não inventar regra.
- Não alterar runtime de projetos consumidores nesta tarefa.
- Não usar symlink antigo como verdade: estado atual é `SKILL.md` arquivo real e `DEVFLOW.md -> /Users/coelhotv/SKILLS/devflow/SKILL.md`.

## Fontes a Ler Antes de Editar

- `/Users/coelhotv/SKILLS/devflow/SKILL.md`
- `/Users/coelhotv/SKILLS/devflow/README.md`
- `/Users/coelhotv/SKILLS/devflow/templates/schema-reference.md`
- `/Users/coelhotv/SKILLS/devflow/scripts/setup.sh`
- `/Users/coelhotv/git-icloud/agent-skills/README.md`
- `/Users/coelhotv/git-icloud/agent-skills/docs/skill-anatomy.md`
- `/Users/coelhotv/git-icloud/agent-skills/skills/using-agent-skills/SKILL.md`
- `/Users/coelhotv/git-icloud/agent-skills/skills/spec-driven-development/SKILL.md`
- `/Users/coelhotv/git-icloud/agent-skills/skills/planning-and-task-breakdown/SKILL.md`
- `/Users/coelhotv/git-icloud/agent-skills/skills/incremental-implementation/SKILL.md`
- `/Users/coelhotv/git-icloud/agent-skills/skills/test-driven-development/SKILL.md`
- `/Users/coelhotv/git-icloud/agent-skills/skills/code-review-and-quality/SKILL.md`
- `/Users/coelhotv/git-icloud/agent-skills/skills/context-engineering/SKILL.md`
- `/Users/coelhotv/git-icloud/agent-skills/skills/doubt-driven-development/SKILL.md`

## Arquivos-Alvo

Criar:
- `/Users/coelhotv/SKILLS/devflow/plans/EXEC_SPEC_DEVFLOW_AGENT_SKILLS_UPGRADE.md`
- `/Users/coelhotv/SKILLS/devflow/references/modes.md`
- `/Users/coelhotv/SKILLS/devflow/references/memory-protocol.md`
- `/Users/coelhotv/SKILLS/devflow/references/quality-gates.md`
- `/Users/coelhotv/SKILLS/devflow/references/orchestration-patterns.md`

Modificar:
- `/Users/coelhotv/SKILLS/devflow/SKILL.md`
- `/Users/coelhotv/SKILLS/devflow/README.md`
- `/Users/coelhotv/SKILLS/devflow/templates/schema-reference.md`
- `/Users/coelhotv/SKILLS/devflow/agents/openai.yaml` somente se frontmatter/descrição mudarem

Opcional:
- `/Users/coelhotv/SKILLS/devflow/scripts/validate-devflow-skill.sh`

## Implementação Prescritiva

### 1. Preparar Baseline

Executar:

```bash
cd /Users/coelhotv/SKILLS/devflow
git status --short
ls -la
wc -l SKILL.md README.md references/*.md templates/schema-reference.md
rg -n "rules.json|anti-patterns.json|_detail|SKILL.md symlink|DEVFLOW.md symlink" .
```

Registrar no spec:
- estado git inicial
- line count de `SKILL.md`
- symlink shape atual
- ocorrências stale encontradas

Bloqueio: se houver mudanças não relacionadas, não reverter. Trabalhar ao redor.

### 2. Criar Spec Persistente

Criar `/Users/coelhotv/SKILLS/devflow/plans/EXEC_SPEC_DEVFLOW_AGENT_SKILLS_UPGRADE.md` com este conteúdo adaptado ao estado vivo.

Critério: arquivo deve permitir que outro agente continue sem consultar chat.

### 3. Extrair Conteúdo do `SKILL.md`

Mover detalhes longos para referências:

`references/modes.md` deve conter:
- Planning P0-P4
- Coding C0-C5
- Reviewing R0-R5
- Distillation D0-D6
- lifecycle mapping: Define, Plan, Build, Verify, Review, Ship/Record
- mode stop rules

`references/memory-protocol.md` deve conter:
- `.agent/` structure
- memory classes
- hot/warm/cold/archived
- pack inference
- locking protocol
- journal/events/state updates
- distillation and lifecycle heuristics
- global export

`references/quality-gates.md` deve conter:
- C1 full spec extraction
- canonical path verification
- C2 contract gateway
- C4 verification
- file-by-file DoD verification
- TDD/prove-it rules
- exact evidence requirements

`references/orchestration-patterns.md` deve conter:
- filesystem as orchestrator
- no automatic mode chaining
- `/deliver-sprint` integration
- `/check-review` integration
- optional review fan-out
- no nested persona orchestration
- main agent merges reports

### 4. Reescrever `SKILL.md`

`SKILL.md` deve ficar como entrada enxuta, idealmente <500 linhas.

Estrutura obrigatória:

```markdown
---
name: devflow
description: >
  Persistent software development workflow...
---

# DEVFLOW

## Overview
## When to Use
## When Not to Use
## Non-Negotiable Rules
## Phase 0 Bootstrap
## Mode Selection
## Reference Loading Map
## Core Workflow
## Common Rationalizations
## Red Flags
## Verification
```

Conteúdo obrigatório:
- “filesystem is orchestrator”
- “Record before exiting”
- Hard Stop: projeto com `.agent/` exige bootstrap antes de plano/edição
- Mode Control: nunca avançar automaticamente entre modos
- Phase 0 passos 1-5
- tabela:
  - `planning`: spec, ADR, task plan
  - `coding`: implementation, tests, contract-safe changes
  - `reviewing`: review plus memory sync
  - `distillation`: journal compression and memory lifecycle
- reference loading map com links para novos arquivos
- anti-rationalization table:
  - “task is small, skip bootstrap” -> falso
  - “spec is obvious” -> falso
  - “test at end” -> falso
  - “lint passed, DoD complete” -> falso
  - “can clean adjacent code” -> falso
- verification checklist final:
  - bootstrap complete
  - relevant rules/APs loaded
  - contract gate respected
  - acceptance criteria verified with evidence
  - memory recorded

### 5. Atualizar `README.md`

README deve refletir:
- `SKILL.md` é arquivo real canônico
- `DEVFLOW.md` é symlink para `SKILL.md`
- skill é agent-neutral
- referências ficam em `references/`
- setup cria `.agent/`
- quick start continua funcionando
- modos e integração com `/deliver-sprint` e `/check-review`

Remover ou corrigir qualquer frase dizendo que `SKILL.md` é symlink.

### 6. Atualizar `templates/schema-reference.md`

Corrigir drift:
- remover descrição de `rules.json`, `anti-patterns.json`, `*_detail`
- documentar modelo atual:
  - índices Markdown em `.agent/memory/*_INDEX.md`
  - arquivos detalhe Markdown com frontmatter em subpastas categóricas
  - campos: `id`, `title`, `summary`, `applies_to`, `tags`, `status`, `layer`, `pack`, `bootstrap_default`
- manter exemplos curtos e compatíveis com templates existentes.

### 7. Validar `agents/openai.yaml`

Se `SKILL.md` frontmatter mudar materialmente, atualizar:

```yaml
interface:
  display_name: "DEVFLOW"
  short_description: "Persistent memory dev workflow"
  default_prompt: "Use $devflow to bootstrap project memory and run a structured software development workflow for this task."
```

Não adicionar branding específico sem necessidade.

### 8. Validador Opcional

Se criar `scripts/validate-devflow-skill.sh`, ele deve:
- usar `#!/usr/bin/env bash`
- usar `set -euo pipefail`
- verificar frontmatter de `SKILL.md`
- verificar linha máxima alvo de `SKILL.md`
- verificar links diretos de referências
- verificar ausência de claims stale em docs canônicos
- não modificar arquivos

## Critérios de Aceitação

- `SKILL.md` fica <500 linhas ou exceção documentada no spec.
- `SKILL.md` contém só protocolo essencial e mapa de referências.
- Todos os detalhes extraídos existem em `references/`.
- `README.md` não menciona symlink errado.
- `templates/schema-reference.md` descreve arquitetura Markdown atual, não JSON antiga.
- DEVFLOW preserva bootstrap, C2, C5, locking e distillation.
- Upgrade incorpora de `agent-skills`:
  - progressive disclosure
  - anti-rationalization
  - red flags
  - verification evidence
  - incremental slices
  - TDD/prove-it
  - five-axis review
  - context discipline
  - optional fan-out review
- Nenhuma mudança adiciona dependência externa obrigatória.
- Nenhum arquivo de projeto consumidor é alterado.

## Comandos de Verificação

Executar no final:

```bash
cd /Users/coelhotv/SKILLS/devflow
git diff --check
wc -l SKILL.md
rg -n "SKILL.md symlink|rules.json|anti-patterns.json|_detail" SKILL.md README.md templates/schema-reference.md references
bash scripts/setup.sh /private/tmp/devflow-smoke "devflow-smoke" "react,typescript"
find /private/tmp/devflow-smoke/.agent -maxdepth 3 -type f | sort
```

Se validador for criado:

```bash
bash scripts/validate-devflow-skill.sh
```

## Revisão Final Obrigatória

Antes de concluir, revisar diff com foco em:
- instruções ambíguas que permitem pular bootstrap
- qualquer modo avançando automaticamente
- qualquer contradição entre `SKILL.md` e referências
- qualquer claim stale sobre symlink
- qualquer referência a Codex no corpo core da skill
- qualquer conteúdo copiado demais de `agent-skills`

## Entrega Esperada

Commit sugerido:

```text
refactor: streamline devflow skill workflow

Adapts agent-skills workflow patterns into DEVFLOW while preserving
filesystem-based memory, bootstrap gates, contract checks, and record protocol.
```

Resumo final deve listar:
- arquivos criados
- arquivos modificados
- comandos executados
- comandos não executados e motivo
- riscos residuais
