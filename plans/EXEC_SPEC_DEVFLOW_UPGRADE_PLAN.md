# EXEC SPEC — DEVFLOW v1.8 Spec-First Evolution

## Objetivo

Evoluir `/Users/coelhotv/SKILLS/devflow` para incorporar conceitos selecionados do `spec-kit` sem transformar DEVFLOW em uma cópia do Spec Kit.

DEVFLOW permanece sendo o protocolo de execução com memória persistente em `.agent/`, carregamento index-first, contratos, ADRs, gates e aprendizado em journal. O Spec Kit inspira uma camada anterior e mais formal de intenção: specs numeradas, perguntas de esclarecimento, checklists de requisitos, tarefas persistentes e análise cruzada de artefatos antes do código.

Resultado esperado:

- `/devflow specifying` cria uma spec versionada e numerada em `plans/specs/NNN-feature-name/`.
- `/devflow planning` refina essa spec com perguntas formais e gera `plan.md` + `tasks.md`.
- `/devflow coding` analisa `spec.md`, `plan.md`, `tasks.md` e contracts antes de entrar no C2 Contract Gateway.
- `.agent/constitution.md` passa a existir como camada governante acima de rules/APs.
- A maior implementação atual, `/Users/coelhotv/git/dosiq/.agent/`, recebe uma constitution v0 concreta.

## Restrições Obrigatórias

- Não instalar `.specify` em projetos consumidores.
- Não adicionar dependência operacional no `specify` CLI.
- Não quebrar specs legadas em `plans/<epic>/EXEC_SPEC*.md`.
- Não auto-avançar modos. `specifying`, `planning`, `coding`, `reviewing` e `distillation` continuam parando em seus gates.
- Não trocar TodoWrite por `tasks.md`. `tasks.md` vira fonte durável; TodoWrite segue como espelho runtime após C2 "go".
- Não substituir `.agent/memory` por specs. Specs descrevem intenção e plano; `.agent/memory` preserva regras, APs, ADRs, contracts e aprendizado.
- Não mover regras específicas de projeto para o skill global. A constitution v0 de `dosiq` fica em `/Users/coelhotv/git/dosiq/.agent/constitution.md`.
- Não alterar outros projetos consumidores nesta etapa, exceto a criação planejada da constitution v0 em `dosiq`.
- Manter `SKILL.md` agent-neutral.
- Preservar Phase 0 Bootstrap, Hard Stop Rule, C2 Contract Gateway, C5 Record Protocol, locking e distillation.

## Fontes Já Inspecionadas

### DEVFLOW

- `/Users/coelhotv/SKILLS/devflow/SKILL.md`
- `/Users/coelhotv/SKILLS/devflow/references/DEVFLOW-REFERENCE.md`
- `/Users/coelhotv/SKILLS/devflow/templates/schema-reference.md`
- `/Users/coelhotv/SKILLS/devflow/plans/EXEC_SPEC_DEVFLOW_UPGRADE_PLAN.md`

### Spec Kit

- `/Users/coelhotv/git/spec-kit/README.md`
- `/Users/coelhotv/git/spec-kit/spec-driven.md`
- `/Users/coelhotv/git/spec-kit/docs/quickstart.md`
- `/Users/coelhotv/git/spec-kit/templates/spec-template.md`
- `/Users/coelhotv/git/spec-kit/templates/plan-template.md`
- `/Users/coelhotv/git/spec-kit/templates/tasks-template.md`
- `/Users/coelhotv/git/spec-kit/templates/constitution-template.md`
- `/Users/coelhotv/git/spec-kit/templates/commands/specify.md`
- `/Users/coelhotv/git/spec-kit/templates/commands/clarify.md`
- `/Users/coelhotv/git/spec-kit/templates/commands/checklist.md`
- `/Users/coelhotv/git/spec-kit/templates/commands/tasks.md`
- `/Users/coelhotv/git/spec-kit/templates/commands/analyze.md`
- `/Users/coelhotv/git/spec-kit/templates/commands/implement.md`

### Dosiq DEVFLOW Implementation

- `/Users/coelhotv/git/dosiq/.agent/state.json`
- `/Users/coelhotv/git/dosiq/.agent/memory/RULES_INDEX.md`
- `/Users/coelhotv/git/dosiq/.agent/memory/CONTRACTS_INDEX.md`
- `/Users/coelhotv/git/dosiq/plans/dose_instances_refactor/EXEC_SPECS_PHASE_4.md`
- `/Users/coelhotv/git/dosiq/plans/native_app_ux_revamp/PRD_NATIVE_APP_UX_REVAMP.md`

## Arquitetura Desejada

### Novo Fluxo de Alto Nível

```text
Bootstrap
  -> Specifying
  -> Planning
  -> Coding
  -> Reviewing
  -> Distillation
```

Cada modo continua sob controle humano:

- Bootstrap -> STOP
- Specifying -> STOP
- Planning -> STOP
- Coding C2 -> STOP
- Coding C5 -> STOP
- Reviewing -> STOP
- Distillation -> STOP

### Diretório Canônico de Feature

Novas specs vivem em:

```text
plans/specs/NNN-feature-name/
  spec.md
  plan.md
  tasks.md
  analysis.md
  checklists/
    requirements.md
  contracts/
```

Campos novos em `.agent/state.json.session`:

```json
{
  "spec_dir": "plans/specs/001-feature-name",
  "spec": "plans/specs/001-feature-name/spec.md",
  "plan": "plans/specs/001-feature-name/plan.md",
  "tasks": "plans/specs/001-feature-name/tasks.md",
  "analysis": "plans/specs/001-feature-name/analysis.md"
}
```

Compatibilidade:

- Se `session.spec_dir` existir, C1 usa o novo diretório.
- Se só `session.spec` existir, C1 usa a spec legada atual.
- Specs antigas continuam válidas até migração manual.

### Constitution

Path padrão:

```text
.agent/constitution.md
```

Semântica:

- constitution = princípios e constraints governantes do projeto.
- rules/APs = memória operacional detalhada e aprendida.
- contracts/ADRs = interfaces e decisões específicas.

Precedência:

```text
constitution > accepted ADRs > contracts > rules/APs > plan/tasks
```

Conflito com constitution é issue CRITICAL no planning/coding analysis.

## Implementação Prescritiva

## Feature 1 — Mode: Specifying

### Alterar `SKILL.md`

Adicionar novo modo antes de `Mode: Planning`:

```markdown
## Mode: Specifying

Purpose: Convert a product/development intent into a durable, numbered feature specification before technical planning.
```

### S0 — State Transition to Specifying

Ao receber `/devflow specifying <feature description>`:

1. Ler `.agent/state.json`.
2. Atualizar imediatamente:

```json
{
  "session": {
    "mode": "specifying",
    "status": "specifying",
    "goal": "<feature description>",
    "goal_type": "feature"
  }
}
```

3. Verificar escrita antes de seguir para S1.

### S1 — Short Name

Gerar short name com os critérios do Spec Kit:

- 2 a 4 palavras.
- kebab-case.
- preferir action-noun quando aplicável.
- preservar termos técnicos (`OAuth`, `API`, `tz`, `PDF`, etc.).
- remover filler.

Exemplos:

```text
"Add user authentication" -> user-auth
"Fix payment processing timeout" -> fix-payment-timeout
"Create analytics dashboard" -> analytics-dashboard
```

### S2 — Numbering

Diretório base:

```text
plans/specs/
```

Algoritmo sequencial:

1. Criar `plans/specs/` se não existir.
2. Listar diretórios que começam com `^[0-9]{3,}-`.
3. Extrair prefixos numéricos.
4. Próximo número = maior + 1.
5. Se não houver diretórios, começar em `001`.
6. Formatar com pelo menos 3 dígitos; permitir expansão natural após `999`.

Não contar specs legadas fora de `plans/specs/`.

### S3 — Directory Creation

Criar:

```text
plans/specs/NNN-feature-name/
plans/specs/NNN-feature-name/checklists/
plans/specs/NNN-feature-name/contracts/
```

### S4 — `spec.md`

Criar `spec.md` com esta estrutura mínima:

```markdown
# Feature Specification: <Feature Name>

**Feature Directory**: `plans/specs/NNN-feature-name`
**Created**: YYYY-MM-DD
**Status**: Draft
**Input**: <original user request>

## User Scenarios & Testing

### User Story 1 - <Brief Title> (Priority: P1)

<plain-language user journey>

**Why this priority**: <value>
**Independent Test**: <how to test this story alone>

**Acceptance Scenarios**:

1. Given <state>, When <action>, Then <outcome>

## Edge Cases

- <boundary/error scenario>

## Requirements

### Functional Requirements

- **FR-001**: <testable requirement>

### Key Entities

- **Entity**: <meaning and key attributes, no implementation details>

## Success Criteria

- **SC-001**: <measurable, technology-agnostic outcome>

## Assumptions

- <explicit default chosen>
```

Rules:

- Focus on WHAT and WHY.
- Do not choose stack, files, APIs, DB tables or implementation details.
- Use `[NEEDS CLARIFICATION: question]` only when ambiguity changes scope, UX, security/privacy, architecture or validation.
- Maximum 3 clarification markers in initial spec.

### S5 — State Update

Atualizar `.agent/state.json`:

```json
{
  "session": {
    "status": "specified",
    "spec_dir": "plans/specs/NNN-feature-name",
    "spec": "plans/specs/NNN-feature-name/spec.md"
  }
}
```

### S6 — Record

Append em `.agent/sessions/events.jsonl`:

```json
{"timestamp":"...","event":"specifying_complete","spec_dir":"plans/specs/NNN-feature-name","spec":"plans/specs/NNN-feature-name/spec.md"}
```

Escrever journal entry curto em `.agent/memory/journal/YYYY-WWW.jsonl`.

STOP:

```text
Specifying complete. Awaiting /devflow planning.
```

## Feature 2 — Constitution v0

### Alterar Bootstrap

No Phase 0, após ler `.agent/state.json` e antes dos índices:

```text
1.5. If `.agent/constitution.md` exists:
     Read it.
     Extract project principles and MUST/SHOULD constraints.
     Include constitution summary in Assessment output.
```

Assessment deve reportar:

```text
Constitution: loaded | missing
Principles: <short list>
Potential conflicts: none | <list>
```

### Autoridade

Adicionar regra:

```text
If plan, task, rule, AP, ADR draft or code path conflicts with `.agent/constitution.md`,
flag [DEVFLOW: CONSTITUTION CONFLICT] and stop before implementation unless the operator
explicitly requests a constitution amendment workflow.
```

### Modelo v0

Adicionar template textual em `SKILL.md` ou `references/DEVFLOW-REFERENCE.md`:

```markdown
# <Project> Constitution

## Core Principles

### I. <Principle Name>
<MUST/SHOULD constraints and rationale>

## Delivery Constraints

## Quality Gates

## Governance

**Version**: 0.1.0 | **Ratified**: YYYY-MM-DD | **Last Amended**: YYYY-MM-DD
```

### Aplicação concreta em `dosiq`

Criar `/Users/coelhotv/git/dosiq/.agent/constitution.md` com princípios concretos:

1. **Health Data Safety**
   - Nunca modificar dados reais de produção em testes.
   - Fluxos com dados de saúde devem preservar privacidade e menor exposição possível.

2. **Mobile-First Reliability**
   - Decisões de produto devem considerar devices low-mid e uso mobile primeiro.
   - Lists, aggregation e rendering não podem assumir hardware desktop.

3. **Server-Side Aggregation for Long-Range Health Metrics**
   - Métricas long-range e heatmaps de adesão devem manter agregação server-side.
   - É proibido mover cálculo long-range para client como solução principal.

4. **Timezone Correctness**
   - Timezone IANA é parte do domínio clínico.
   - Offsets fixos não representam identidade de fuso.
   - Query windows usam UTC real; timezone governa wall-clock/local day.

5. **Contract and ADR Discipline**
   - Mudanças breaking em interface exigem ADR aceito antes do código.
   - Contracts devem ser atualizados quando shape público muda.

6. **Release and SQP Discipline**
   - Mudanças code-facing classificam plataforma e SemVer.
   - CHANGELOG em português é obrigatório quando há impacto de produto.
   - Mobile release exige store-note relevance quando aplicável.

7. **Human-Controlled Delivery**
   - Agentes não fazem merge próprio.
   - Smoke PO é obrigatório antes de PR para mudanças mobile/visuais relevantes.

8. **Filesystem Memory Is Canonical**
   - Chat não é fonte de verdade.
   - `.agent/state.json`, journal, indexes, ADRs, contracts e plans devem refletir o estado oficial.

Governance:

- Alterações na constitution exigem `/devflow planning` ou ADR.
- Conflito detectado em C1.5 bloqueia coding.
- Bootstrap sempre reporta se constitution foi carregada.

## Feature 3 — Planning Clarification Questions

### Inserir P1.5

No modo Planning, após P1 Scope Analysis e antes de P2 ADR Check:

```markdown
### P1.5 — Formal Requirement Clarification
```

Objetivo:

Detectar ambiguidade que prejudica plano técnico, contratos, tarefas, testes, UX, segurança, performance ou aceite.

Taxonomia:

- Functional Scope & Behavior
- Personas / User Roles
- Domain & Data Model
- Interaction & UX Flow
- Non-Functional Requirements
- Integration & External Dependencies
- Edge Cases & Failure Handling
- Constraints & Tradeoffs
- Terminology & Consistency
- Completion Signals

Regras:

- Máximo 5 perguntas por planning session.
- Perguntar só quando resposta muda implementação, task breakdown, test design, architecture, contracts ou validation.
- Preferir múltipla escolha com recomendação.
- Não perguntar o que pode ser descoberto lendo repo.
- Registrar cada resposta em `plan.md` sob `## Clarifications`.
- Se operador pular clarifications, registrar risco em `plan.md`.

Formato em `plan.md`:

```markdown
## Clarifications

- Q: <question> -> A: <answer>
```

### Checklist de requisitos

Criar/atualizar:

```text
plans/specs/NNN-feature-name/checklists/requirements.md
```

Checklist testa qualidade dos requisitos, não implementação.

Itens devem usar formato:

```markdown
- [ ] CHK001 Are <requirement quality issue> defined/specified/quantified? [Completeness|Clarity|Consistency|Coverage|Measurability]
```

Proibido:

- "Verify button works"
- "Test API returns 200"
- "Confirm UI renders"

Permitido:

- "Are loading and empty states specified for all primary flows? [Coverage]"
- "Is 'fast' quantified with a measurable threshold? [Clarity]"
- "Are acceptance criteria mapped to each P1 user story? [Traceability]"

## Feature 5 — Persistent Tasks

### Gerar `tasks.md`

No Planning, após `plan.md`, gerar:

```text
plans/specs/NNN-feature-name/tasks.md
```

Formato obrigatório:

```markdown
# Tasks: <Feature Name>

**Input**: `spec.md`, `plan.md`, contracts, checklist
**Status**: Draft

## Format

- [ ] T001 [P?] [US?] [MODE?] Description with exact file path when known
```

Labels:

- `[P]`: tarefa paralelizável, arquivos independentes.
- `[US1]`, `[US2]`: user story.
- `[P1]`, `[P2]`: planning tasks, se necessário.
- `[C3]`: implementation.
- `[C4]`: validation/DoD.
- `[C5]`: record/memory/state.

### Conteúdo mínimo

Tasks devem cobrir:

- cada deliverable do `plan.md`
- cada acceptance criterion do `spec.md`
- cada contract/ADR action
- cada quality gate
- cada C4 DoD verification
- cada C5 record step

### Relação com TodoWrite

Atualizar C2:

- Antes de escrever código, ler `tasks.md`.
- Após C2 "go", criar TodoWrite a partir de `tasks.md`.
- Marcar conclusão em TodoWrite durante execução.
- Atualizar `tasks.md` nos checkpoints persistentes.
- Se sessão interromper, próxima sessão retoma por `tasks.md` + `state.json`.

## Feature 6 — Artifact Coverage Analysis

### Inserir C1.5

No modo Coding, após C1 Pre-Code Checklist e antes de C2 Contract Gateway:

```markdown
### C1.5 — Artifact Coverage Analysis
```

Inputs:

- `spec.md`
- `plan.md`
- `tasks.md`
- `checklists/requirements.md`
- `contracts/` feature-local, se existir
- `.agent/constitution.md`, se existir
- `.agent/memory/CONTRACTS_INDEX.md`
- `.agent/memory/DECISIONS_INDEX.md`
- relevant rules/APs loaded during bootstrap

Output:

```text
plans/specs/NNN-feature-name/analysis.md
```

### Checks Obrigatórios

1. **Spec Coverage**
   - Todo `FR-###` tem task ou justificativa.
   - Todo `SC-###` tem verificação C4.
   - Toda user story P1/P2 tem independent test.

2. **Plan Coverage**
   - Todo deliverable tem task.
   - Todo target file tem path verificado ou fica BLOCKED.
   - Toda migration/config/doc exigida aparece em tasks.

3. **Task Traceability**
   - Toda task mapeia para user story, FR, SC, deliverable, quality gate ou C5.
   - Tasks sem mapeamento são `Unmapped`.

4. **Contract Coverage**
   - Interfaces tocadas aparecem em `CONTRACTS_INDEX.md` ou em `contracts/`.
   - Breaking change sem ADR aceito vira CRITICAL.

5. **Constitution Alignment**
   - Conflito com `.agent/constitution.md` vira CRITICAL.
   - Constraints MUST ausentes no plano viram HIGH ou CRITICAL conforme impacto.

6. **Checklist Status**
   - Checklist incompleto antes de coding vira HIGH.
   - Item incompleto de segurança, privacidade, release ou contract vira CRITICAL se bloquear entrega segura.

### Severity

- CRITICAL: constitution conflict, breaking contract without accepted ADR, missing task for baseline FR, missing required artifact.
- HIGH: ambiguous security/performance requirement, acceptance criterion without verification, checklist blocker.
- MEDIUM: terminology drift, non-functional requirement weakly covered, task ordering risk.
- LOW: wording/style/process improvement.

### Gate Behavior

- Se CRITICAL ou HIGH existir: STOP antes de C2.
- Se só MEDIUM/LOW existir: pode seguir para C2 com riscos listados.

Mensagem:

```text
[DEVFLOW: ARTIFACT ANALYSIS BLOCKED]
analysis.md contains CRITICAL/HIGH issues. Resolve before C2.
```

### `analysis.md` Template

```markdown
# Artifact Coverage Analysis: <Feature Name>

**Feature Directory**: `plans/specs/NNN-feature-name`
**Created**: YYYY-MM-DD
**Status**: PASS | BLOCKED

## Findings

| ID | Category | Severity | Artifact | Summary | Required Action |
|----|----------|----------|----------|---------|-----------------|

## Coverage Summary

| Requirement | Covered? | Task IDs | Notes |
|-------------|----------|----------|-------|

## Contract Alignment

## Constitution Alignment

## Unmapped Tasks

## Gate Decision
```

## Atualizações em `references/DEVFLOW-REFERENCE.md`

Atualizar File Reference Map:

```text
.agent/
  constitution.md              ← project governing principles and non-negotiable constraints
```

Adicionar plans map:

```text
plans/
  specs/
    NNN-feature-name/
      spec.md                  ← product intent, WHAT/WHY, user stories, FRs, SCs
      plan.md                  ← technical plan from Planning mode
      tasks.md                 ← durable task list mirrored into TodoWrite during Coding
      analysis.md              ← C1.5 artifact coverage report
      checklists/
        requirements.md        ← requirements quality checklist
      contracts/
        *.md                   ← feature-local interface contracts, if needed
```

Atualizar State Machine:

```text
SPECIFYING MODE:
  START (/devflow specifying)
    ↓
  S0: session.status = "specifying"
    ↓
  S1-S4: short name, numbering, spec directory, spec.md
    ↓
  S5-S6: session.status = "specified"; event/journal
    ↓
  END -> STOP (awaiting Planning mode invocation)
```

Atualizar Gene Reference somente se necessário. Não criar gene novo nesta versão.

## Atualizações em `templates/schema-reference.md`

Adicionar documentação dos novos campos opcionais em `state.json.session`:

```json
{
  "spec_dir": "plans/specs/NNN-feature-name",
  "spec": "plans/specs/NNN-feature-name/spec.md",
  "plan": "plans/specs/NNN-feature-name/plan.md",
  "tasks": "plans/specs/NNN-feature-name/tasks.md",
  "analysis": "plans/specs/NNN-feature-name/analysis.md"
}
```

Adicionar `.agent/constitution.md` como arquivo de projeto, não índice de memória.

Documentar que `plans/specs` é outside `.agent/` e deve ser versionado junto do projeto.

## Compatibilidade e Migração Gradual

### Specs Legadas

Continuar aceitando:

```json
{
  "session": {
    "spec": "plans/dose_instances_refactor/EXEC_SPECS_PHASE_4.md"
  }
}
```

C1 deve detectar:

- novo formato: `session.spec_dir` + `spec.md`
- legado: `session.spec`

### Migração Manual Futura

Adicionar seção opcional no `SKILL.md`:

```text
/devflow migrate-spec
```

Não implementar comando agora, só reservar conceito se desejado.

Migração manual recomendada:

1. Criar `plans/specs/NNN-feature-name/`.
2. Copiar PRD/EXEC_SPEC legado para `spec.md` ou `legacy.md`.
3. Criar `plan.md` resumindo execução técnica.
4. Criar `tasks.md` com IDs.
5. Atualizar `state.session.spec_dir`.

### Dosiq Estado Atual

`/Users/coelhotv/git/dosiq/.agent/state.json` atualmente aponta para:

```json
{
  "spec": "plans/dose_instances_refactor/EXEC_SPECS_PHASE_4.md"
}
```

Isso deve continuar válido após v1.8.

## Critérios de Aceite

- `SKILL.md` documenta `/devflow specifying`.
- `SKILL.md` documenta `P1.5 — Formal Requirement Clarification`.
- `SKILL.md` documenta `C1.5 — Artifact Coverage Analysis`.
- `SKILL.md` documenta `tasks.md` persistente e relação com TodoWrite.
- `SKILL.md` documenta `.agent/constitution.md` no bootstrap.
- `references/DEVFLOW-REFERENCE.md` contém `.agent/constitution.md`.
- `references/DEVFLOW-REFERENCE.md` contém `plans/specs/NNN-feature-name/`.
- `templates/schema-reference.md` contém os novos campos opcionais de `state.json.session`.
- `/Users/coelhotv/git/dosiq/.agent/constitution.md` existe com princípios concretos do projeto.
- C1 aceita specs novas e specs legadas.
- C1.5 bloqueia C2 quando há CRITICAL/HIGH.
- Nenhum texto exige instalação de `.specify`.
- Nenhum texto diz que DEVFLOW vira Spec Kit.
- Nenhuma mudança remove C2, C5, locking, distillation ou Mode Control Rule.

## Comandos de Verificação

Executar em `/Users/coelhotv/SKILLS/devflow`:

```bash
git diff --check
rg -n "specifying|Mode: Specifying|P1.5|C1.5|Artifact Coverage|plans/specs|constitution|tasks.md" SKILL.md references/DEVFLOW-REFERENCE.md templates/schema-reference.md plans/EXEC_SPEC_DEVFLOW_UPGRADE_PLAN.md
rg -n "stale upgrade source markers|legacy upgrade target markers|\\.specify" plans/EXEC_SPEC_DEVFLOW_UPGRADE_PLAN.md SKILL.md references/DEVFLOW-REFERENCE.md templates/schema-reference.md
```

Expected:

- First `rg` finds all new v1.8 concepts.
- Second `rg` finds no stale upgrade-source dependency, no legacy upgrade-target marker, and no instruction to install `.specify`.

Executar JSON validation:

```bash
python3 -m json.tool /Users/coelhotv/git/dosiq/.agent/state.json >/tmp/dosiq-state-json-ok.txt
```

Executar constitution path check:

```bash
test -f /Users/coelhotv/git/dosiq/.agent/constitution.md
sed -n '1,220p' /Users/coelhotv/git/dosiq/.agent/constitution.md
```

Executar final status:

```bash
git status --short
git -C /Users/coelhotv/git/dosiq status --short
```

## Sequência Recomendada de Implementação

1. Atualizar `SKILL.md` com `Mode: Specifying`, P1.5, C1.5, tasks persistentes e constitution bootstrap.
2. Atualizar `references/DEVFLOW-REFERENCE.md` com novo file map e state machine.
3. Atualizar `templates/schema-reference.md` com novos campos de state e constitution.
4. Criar `/Users/coelhotv/git/dosiq/.agent/constitution.md`.
5. Rodar comandos de verificação.
6. Revisar diff para garantir que specs legadas seguem aceitas.
7. Commit separado por repo, se solicitado.

## Fora de Escopo

- Implementar CLI.
- Instalar Spec Kit.
- Criar `.specify/`.
- Migrar specs antigas de `dosiq`.
- Criar gerador automático real para `tasks.md`.
- Criar workflow YAML.
- Criar sistema de presets/extensões.
- Alterar regras específicas de `dosiq` além da constitution v0.
