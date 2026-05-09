# Plano: DEVFLOW — Autonomous Software Development Skill

## Contexto

A SKILL.md do projeto second-brain implementa um agente autônomo de gestão de conhecimento pessoal com conceitos poderosos: estado persistido em arquivos, loop ReAct, alinhamento de metas, distilação de memória e meta-evolução. O usuário quer adaptar esses conceitos para projetos de desenvolvimento de software de médio-longo prazo, onde agentes autônomos executam tarefas de planning, coding e review sem um orquestrador formal.

O projeto meus-remedios já tem um sistema maduro de memória local (`.memory/` com 156+ regras, 100+ anti-patterns, journal semanal, CLAUDE.md com 664 linhas), mas carece de: distilação automática, rastreamento de lifecycle de regras, ADRs estruturados, contratos de interface, coordenação entre agentes concorrentes e síntese cross-project.

**O objetivo:** criar a skill DEVFLOW — uma skill de desenvolvimento autônomo onde o sistema de arquivos É o orquestrador.

---

## Nome: DEVFLOW

**Rationale:**
- "DEV" — contexto de software, sem ambiguidade
- "FLOW" — fluxo contínuo de aprendizado, melhoria e entrega; "state flow" (arquivo como estado compartilhado)
- Não conflita com terminologia existente: não é "orchestrator", "planner", "coder", "reviewer"
- Funciona como comando: `/devflow`
- Único e memorável

**Metáfora central: Sistema de Rios**
Cada sessão de agente (afluente) deposita conhecimento em arquivos (o leito do rio), que moldou o próximo agente sem um controlador central. O estado persiste em arquivos, não na memória do agente.

---

## Decisão Arquitetural: JSON + Markdown on-demand

**Formato base:** JSON estruturado compacto para índices (sempre carregados), Markdown on-demand para detalhes ricos (carregados só quando a regra/ADR é relevante).

**Protocolo de leitura:** índice primeiro → identificar entradas relevantes por `tags`/`applies_to` → carregar `_detail/` apenas das entradas relevantes.

**Vantagem principal:** o índice de 156 regras cabe em ~80 linhas de JSON. O agente consome contexto apenas com o detalhe das regras efetivamente aplicáveis à tarefa atual.

---

## Arquitetura

### Por Projeto: `.agent/`

```
<project-root>/
  .agent/
    DEVFLOW.md                    # Contexto mestre da skill
    state.json                    # Estado de sessão + metadados
    
    memory/
      rules.json                  # Índice compacto: [{id, summary, tags, applies_to, status, incident_count}]
      anti-patterns.json          # Índice compacto: [{id, summary, tags, triggers, status}]
      contracts.json              # Índice: [{id, name, consumers, breaking_change_requires, status}]
      decisions.json              # Índice: [{id, title, status, date, supersedes}]
      knowledge.json              # Fatos de domínio estruturados: [{topic, fact, valid_for, source}]
      
      rules_detail/
        R-NNN.md                  # Carregado on-demand: rationale, código de exemplo, histórico
      anti-patterns_detail/
        AP-NNN.md                 # Carregado on-demand: descrição completa, exemplo ruim/bom, prevenção
      contracts_detail/
        CON-NNN.md                # Carregado on-demand: schema completo, consumers, migration guide
      decisions_detail/
        ADR-NNN.md                # Carregado on-demand: contexto, opções, consequências, rollback
      
      journal/
        YYYY-WWW.jsonl            # Entradas de sprint (append-only JSONL, um evento por linha)
        archive/
          YYYY-WXX-WYY.json       # Compressão distilada do período
    
    evolution/
      genes.json                  # Parâmetros de comportamento da skill
      evolution_log.jsonl         # Histórico de mutações (append-only)
    
    sessions/
      .lock                       # Lock otimista {session_id, started_at, writing}
      events.jsonl                # Eventos de sessão (append-only, cap 200)
    
    synthesis/
      pending_export.json         # Regras candidatas à promoção global [{id, type, source}]
```

### Global: `~/.devflow/`

```
~/.devflow/
  global_base/
    universal_rules.json          # [{id: "GR-NNN", source_project, summary, tags}]
    universal_anti_patterns.json  # [{id: "GAP-NNN", source_project, summary, tags}]
    rules_detail/GR-NNN.md        # Detalhes on-demand
    anti-patterns_detail/GAP-NNN.md
    index.json                    # Registro de projetos + metadados
  projects/
    <project-slug>/
      health.json                 # Métricas de observabilidade
```

### Schemas-Chave

**`rules.json` (índice — sempre carregado):**
```json
[
  {
    "id": "R-001",
    "title": "Duplicate file check",
    "summary": "Verify no duplicate file exists before modifying any file",
    "applies_to": ["all"],
    "tags": ["file-management", "safety"],
    "incident_count": 5,
    "last_referenced": "2026-04-01",
    "review_due": "2026-07-01",
    "status": "active",
    "has_detail": true
  }
]
```

**`rules_detail/R-001.md` (on-demand):**
```markdown
# R-001: Duplicate File Check

**Rationale:** Edited the wrong file in 3 separate sessions. Fix was lost when the correct (unedited) file was compiled. Especially dangerous with similarly named components.

**Check:** `find src -name "*TargetName*" | wc -l` must return 1 before editing.

**Example:**
find src -name "*StockForm*"
→ src/features/stock/components/StockForm.jsx  ✓ (only one)
→ src/legacy/StockForm.jsx  ✗ (duplicate — investigate before proceeding)

**Related:** AP-001 (same incident, anti-pattern side)
```

**`decisions.json` (índice):**
```json
[
  {
    "id": "ADR-001",
    "title": "Zod Enums in Portuguese",
    "status": "accepted",
    "date": "2026-02-07",
    "tags": ["zod", "i18n", "validation"],
    "supersedes": null,
    "has_detail": true
  }
]
```

**`contracts.json` (índice):**
```json
[
  {
    "id": "CON-001",
    "name": "logService.createLog",
    "file": "src/services/api/logService.js",
    "consumers": ["StockService", "DashboardProvider", "TelegramBot"],
    "breaking_change_requires": "ADR + all consumer updates + migration",
    "status": "stable",
    "has_detail": true
  }
]
```

**`knowledge.json`:**
```json
[
  {
    "topic": "timezone",
    "fact": "Never use new Date('YYYY-MM-DD') — parses as UTC midnight, wrong for BR users",
    "correct": "Use parseLocalDate() from @/utils/dateUtils",
    "valid_for": ["js", "ts"],
    "source": "R-020"
  },
  {
    "topic": "supabase",
    "fact": "Supabase .optional() rejects null — use .nullable().optional() for nullable DB fields",
    "valid_for": ["supabase >= 2.0"],
    "source": "R-025"
  }
]
```

**`journal/YYYY-WWW.jsonl` (append-only):**
```jsonl
{"timestamp":"2026-04-07T10:30:00Z","session":"sess_001","event":"task_complete","task":"Add pharmacy field to StockForm","rules_applied":["R-001","R-021"],"aps_triggered":[],"files_changed":["src/schemas/stockSchema.js","src/features/stock/components/StockForm.jsx"]}
{"timestamp":"2026-04-07T11:00:00Z","session":"sess_001","event":"new_rule","rule_id":"R-157","summary":"Optional Zod fields must use .optional() not .nullable() for UI-only fields"}
```

**`state.json`:**
```json
{
  "schema_version": "1.0",
  "project": { "name": "...", "slug": "...", "stack": [], "phase": "...", "current_sprint": "YYYY-WWW" },
  "session": { "id": "...", "started_at": "...", "mode": "coding|planning|reviewing|distillation", "goal": "...", "goal_type": "feature|fix|refactor|docs|chore", "status": "active" },
  "memory": { "rules_count": 156, "anti_patterns_count": 45, "decisions_count": 23, "contracts_count": 12, "last_distillation": "...", "journal_entries_since_distillation": 7 },
  "evolution": { "genes_version": "1.0", "pending_mutations": [] },
  "quality_gates": { "index_loaded_at": null, "relevant_rules_loaded_at": null }
}
```

**`evolution/genes.json`:**
```json
{
  "genes": {
    "memory_distillation_threshold": 10,
    "auto_promote_rule_after_incidents": 2,
    "require_adr_for_schema_changes": true,
    "require_adr_for_api_breaking_changes": true,
    "enforce_contract_checks": true,
    "rule_review_cadence_weeks": 12,
    "anti_pattern_expiry_weeks": 52,
    "cross_project_export_auto": false
  }
}
```

---

## Idioma: English Only

**Todo o projeto DEVFLOW é escrito em inglês** — DEVFLOW.md, templates, specs de execução, arquivos de suporte, README, e todos os arquivos gerados nos projetos (rules.json, decisions_detail/, contracts_detail/, etc.).

**Razões:**
1. Futura publicação opensource — contribuidores internacionais
2. Modelos LLM mais simples (Gemma, Haiku, pequenos OSS) seguem instruções em inglês com maior fidelidade e consistência
3. Evita ambiguidades de tokenização em português para prompts de sistema

**Exceção:** conteúdo de domínio do projeto alvo (ex: meus-remedios) pode permanecer em português onde já existe — mas novos artefatos DEVFLOW desse projeto (decisions_detail/, contracts_detail/) serão em inglês.

---

## Skill DEVFLOW.md — Especificação Completa

O arquivo DEVFLOW.md é o sistema prompt da skill. Estrutura:

### Session Loop: Assess → Execute → Record

O DEVFLOW implementa um ciclo ReAct adaptado para desenvolvimento de software. A diferença crítica em relação ao ReAct padrão: **cada Observation é sempre externalizada em arquivos**. A próxima sessão encontra um estado mais rico — o loop persiste entre sessões, não apenas dentro de uma conversa.

```
Assess:   Read state.json + filtered rules/knowledge → understand current project state
Execute:  Plan, implement, or review — following the active mode protocol
Record:   Write to events.jsonl, journal, memory files → observations persist across sessions

The cycle repeats within a session and continues across sessions.
A session that skips Record is incomplete — it consumed knowledge without contributing.
```

**Por que não usar o vocabulário Thought/Action/Observation do PKM:**
- O DEVFLOW é usado por agentes de diferentes capacidades (de modelos simples a avançados)
- Assess/Execute/Record mapeia diretamente para o trabalho de desenvolvimento — sem abstração desnecessária
- A instrução "Record before exiting" é mais operacional do que "log your Observation"

### Protocolo de Leitura (Índice → Detalhe on-demand)

```
PHASE 0: BOOTSTRAP (sempre, antes de qualquer ação)

1. Ler state.json → contexto de sessão, sprint, goal, mode
2. Ler memory/rules.json → índice compacto (id + summary + tags)
   Filtrar por: applies_to contém stack atual OU tags intersectam com goal
   → Identificar R-NNN relevantes para a sessão (subset, não todos)
3. Ler memory/anti-patterns.json → mesmo filtro por tags/applies_to
4. Para cada R-NNN relevante identificado: ler rules_detail/R-NNN.md
5. Para cada AP-NNN relevante: ler anti-patterns_detail/AP-NNN.md
6. Ler memory/knowledge.json filtrado pelo topic relevante ao goal
7. Determinar modo: planning | coding | reviewing | distillation

GATE: Não prosseguir até completar os 7 passos.
```

**Custo de contexto esperado:**
- `rules.json` completo (156 regras): ~120 linhas
- Detalhes on-demand (~10-15 regras relevantes × ~15 linhas): ~200 linhas
- Total: ~320 linhas vs ~800+ linhas de rules.md completo

### Quatro Modos de Operação

#### Modo Planning
- P1: Analisar escopo (plans/ existentes, ADRs relevantes, contratos afetados)
- P2: ADR Check — decisão sem ADR = criar ADR-NNN (status: proposed) antes de prosseguir
- P3: Criar spec de execução em `plans/EXEC_SPEC_<GOAL>.md` com critérios verificáveis
- P4: Atualizar `state.json` + `events.jsonl`

#### Modo Coding
- C1: Pre-Code Checklist (7 verificações obrigatórias, não pular)
- C2: Contract Gateway — mudança quebrando contrato = HALT → ADR → aprovação humana
- C3: Implementação na ordem: schemas → services → components → views → tests → styles
- C4: Quality Gates (lint + tests + build, todos devem passar)
- C5: Post-Code Protocol (atualizar regras, anti-patterns, journal, events, state — obrigatório)

**Integração com `/deliver-sprint`:**
A skill `/deliver-sprint` já é usada em projetos existentes para organizar entregas em 8 etapas (pre-planning, setup, implementation, validation, git, push/review, merge, documentation). O DEVFLOW **referencia e delega** ao `/deliver-sprint` para o processo de entrega, adicionando as camadas de memória e alinhamento de contratos que o deliver-sprint não tem:

```
Modo Coding DEVFLOW = Bootstrap DEVFLOW + Contexto de memória
                    → execução via /deliver-sprint (processo de entrega)
                    → Post-Code DEVFLOW (atualização de memória)
```

O DEVFLOW.md incluirá: "Para execução da entrega, use `/deliver-sprint`. O DEVFLOW envolve essa execução com contexto de memória (pré) e atualização de conhecimento (pós)."

#### Modo Reviewing
- R1: Carregar contexto (rules, anti-patterns, contracts, decisions)
- R2: Violation Scan por arquivo modificado
- R3: Classificação CRITICAL | HIGH | MEDIUM | LOW
- R4: Atualizar memória (incrementar contadores de lifecycle, propor novos AP-NNN)
- R5: Output estruturado

**Integração com `/check-review`:**
A skill `/check-review` acompanha revisões automatizadas do GitHub (Gemini Code Assist e outros). O DEVFLOW **complementa**, não substitui:

```
/check-review → revisão técnica de código (GitHub/Gemini)
DEVFLOW review → revisão de memória: quais regras foram seguidas/violadas?
               → atualização de lifecycle (incident_count)
               → proposição de novos AP-NNN se padrão novo encontrado
```

O DEVFLOW.md incluirá: "Após `/check-review` completar, execute `/devflow reviewing` para sincronizar os achados da revisão com a base de memória do projeto."

#### Modo Distillation
- D1: Compressão de journal entries em arquivos de archive
- D2: Rule Lifecycle Review (flags overdue reviews, candidates para deprecação)
- D3: Promotion Assessment (regras para `pending_export.json`)
- D4: Global Export (quando `/devflow export` executado)
- D5: Reset de state (last_distillation, counters)

### Protocolo de Locking

```
Antes de escrever em qualquer .agent/memory/ file:
  1. Ler sessions/.lock
     SE vazio OU {writing: null} → prosseguir
     SE lock > 30 min → override (stale), registrar em events.jsonl
     SE lock ativo → aguardar 5s, retry 3x, reportar ao humano
  2. Escrever lock: {session_id, started_at, writing: "<filename>"}
  3. Escrever arquivo
  4. Limpar lock: {session_id, started_at, writing: null}

events.jsonl e journal/*.md: append-only, sem lock necessário
state.json: ciclo read-check-write (verificar mtime)
```

### Meta-Evolução Segura

```
1. Observação → append em evolution_log.jsonl (status: pending) com sandbox_test
2. Report ao humano via journal → NÃO auto-aplicar
3. Humano aprova → status: approved
4. Próxima sessão aplica genes.json
5. Rollback: reler evolution_log, restaurar valor anterior

DEVFLOW.md: mudanças exigem 3+ observações independentes + aprovação humana + /devflow meta-evolve
```

---

## Mitigação de Riscos

| Risco | Mitigação |
|-------|-----------|
| Conflito de escrita concorrente | Lock otimista em `sessions/.lock` com timeout 30min; append-only para eventos e journal |
| Memória stale/incorreta | `rule_lifecycle.json` com `review_due`; distilação sinaliza overdue; tags de versão em knowledge.md |
| Bloat de arquivos | events.jsonl cap 200; journal archive após threshold; poda de regras deprecated após 1 ano |
| Meta-evolução ruim | Genes NUNCA auto-aplicados; aprovação humana obrigatória; rollback via evolution_log |
| Context window overflow | Gene `max_memory_read_lines: 300`; knowledge.md lido por seção (Grep first); journal: apenas 2 últimas semanas |

---

## Guia de Implementação

### Setup para Projeto Novo (10 passos)

1. Criar estrutura `.agent/` com todos os subdiretórios
2. Criar `state.json` com metadados do projeto
3. Criar `memory/rules.json` (array vazio `[]`)
4. Criar `memory/anti-patterns.json` (array vazio `[]`)
5. Popular `memory/knowledge.json` com fatos de stack, path aliases, arquivos-chave
6. Criar `memory/decisions.json` e `memory/contracts.json` (arrays vazios)
7. Criar diretórios `rules_detail/`, `anti-patterns_detail/`, `contracts_detail/`, `decisions_detail/`
8. Criar `evolution/genes.json` com valores padrão
9. Criar `sessions/.lock` (arquivo vazio) e `sessions/events.jsonl` (entrada de inicialização)
10. Rodar `/devflow status` — verificar todos os arquivos legíveis e contagens corretas

### Onboarding de Projeto Existente (meus-remedios)

1. Criar `.agent/` ao lado de `.memory/` existente (aditivo, não destrutivo)
2. **Converter `rules.md` → `rules.json` + `rules_detail/`:**
   - Para cada R-NNN: extrair campos (id, summary, tags, applies_to, status) → entrada no JSON
   - Mover corpo completo (rationale, exemplos) → `rules_detail/R-NNN.md`
3. Mesmo processo para `anti-patterns.md` → `anti-patterns.json` + `anti-patterns_detail/`
4. Popular `knowledge.json` a partir de `knowledge.md` (estruturar por topic/fact/valid_for)
5. Migrar `journal/YYYY-WWW.md` → `journal/YYYY-WWW.jsonl` (um evento por linha)
6. **Arqueologia de ADRs:** escanear journal entries + CLAUDE.md → criar `decisions.json` + `decisions_detail/ADR-NNN.md`
7. **Extração de contratos:** escanear `docs/reference/SERVICES.md`, `HOOKS.md` → criar `contracts.json` + `contracts_detail/CON-NNN.md`
8. Inicializar `state.json` com fase atual, sprint, contagens
9. Adicionar no topo do CLAUDE.md: `> Este projeto usa DEVFLOW. Contexto primário: .agent/DEVFLOW.md`

---

## Casos de Uso

### UC1: Implementação Guiada por Memória
**Trigger:** `/devflow coding "adicionar campo farmácia ao StockForm"`
- Bootstrap lê rules (R-001 duplicate check, R-021 Zod Portuguese) + anti-patterns + contracts
- Verifica CON-004 (StockForm schema contract) → campo opcional = não-breaking
- Implementa → roda quality gates
- Pós-implementação: atualiza journal, events, state

### UC2: Sessões Concorrentes
**Trigger:** Dois agentes abertos simultaneamente (um codando, um documentando)
- Eventos e journal: append-only, sem conflito
- memory files: lock otimista serializa escritas
- Journal usa headers com timestamp de sessão → merge válido após distilação

### UC3: Lifecycle de Regras e Expiração
**Trigger:** `/devflow distill` (automático após 10 journal entries)
- Lê `rule_lifecycle.json`, encontra R-011 sem referência há 8 semanas
- Flag `in-review`, escreve nota no journal para revisão humana
- AP-024 (4 triggers) → promovido para `pending_export.json`
- Comprime journal em archive, reset de contadores

### UC4: ADR Gateway para Breaking Changes
**Trigger:** Agente tenta modificar assinatura de `logService.createLog()`
- Lê `contracts.md` → CON-001 cobre essa interface → mudança é breaking
- HALT → draft ADR-019 em `decisions.md` (status: proposed)
- Informa humano: "Breaking change detectado. ADR-019 criado. Aguardando aprovação."
- Humano aprova → agente retoma implementação com referência ao ADR no commit

### UC5: Síntese Cross-Project
**Trigger:** Novo projeto usando React + Supabase
- Lê `~/.devflow/global_base/universal_rules.md`
- Encontra GR-001 (timezone: nunca `new Date('YYYY-MM-DD')`) e GR-002 (Supabase nullable)
- Copia como R-001/R-002 com anotação `[source: global/GR-001]`
- Novo projeto evita bugs já resolvidos em projetos anteriores

### UC6: Observabilidade
**Trigger:** `/devflow status --health`
- Analisa events.jsonl dos últimos 30 dias
- Top anti-patterns: AP-024 (4x), AP-001 (2x)
- Compliance de contratos: 67% das sessões verificaram antes de codar
- Gera sugestão: "Considere lint rule para AP-024 (hardcoded colors)"

---

## Formato de Resposta da Skill

```
DEVFLOW [modo] — [projeto] — [data]

Goal
  [Goal atual e tipo]

Steps Taken
  1. [Bootstrap: arquivos lidos]
  2. [Ações com referências a arquivos]
  3. [Quality gates executados e resultados]

Memory Updates
  Rules: [R-NNN adicionado/atualizado, ou "nenhum"]
  Anti-Patterns: [AP-NNN adicionado/triggered, ou "nenhum"]
  ADRs: [ADR-NNN criado/referenciado, ou "nenhum"]
  Journal: [entrada em YYYY-WWW.md, ou "nenhum"]

Goal Alignment
  Critérios atendidos: [lista]
  Drift detectado: [lista ou "nenhum"]

Next Session
  [O que a próxima sessão deve saber]
  [Distilação necessária: sim/não]
  [Aprovações humanas pendentes: lista ou "nenhuma"]
```

---

## Arquivos Críticos para Implementação

### Referência (leitura)
- `second-brain/SKILL.md` — skill original (base conceitual)
- `meus-remedios/.memory/rules.md` — 156+ regras a migrar
- `meus-remedios/.memory/anti-patterns.md` — 100+ anti-patterns a migrar
- `meus-remedios/CLAUDE.md` — decisões e regras a extrair como ADRs
- `meus-remedios/AGENTS.md` — referência rápida a consolidar em DEVFLOW.md
- `meus-remedios/docs/reference/SERVICES.md` e `HOOKS.md` — base para contracts.md

### Novos arquivos a criar
- `second-brain/DEVFLOW.md` — skill completa (ou localização a decidir com usuário)
- `meus-remedios/.agent/DEVFLOW.md` — instância do projeto
- `meus-remedios/.agent/state.json`
- `meus-remedios/.agent/memory/rules.json` (índice convertido de rules.md)
- `meus-remedios/.agent/memory/anti-patterns.json` (índice convertido)
- `meus-remedios/.agent/memory/knowledge.json` (estruturado de knowledge.md)
- `meus-remedios/.agent/memory/decisions.json` + `decisions_detail/ADR-NNN.md`
- `meus-remedios/.agent/memory/contracts.json` + `contracts_detail/CON-NNN.md`
- `meus-remedios/.agent/memory/rules_detail/R-NNN.md` (para cada regra migrada)
- `meus-remedios/.agent/memory/anti-patterns_detail/AP-NNN.md` (para cada AP migrado)
- `meus-remedios/.agent/evolution/genes.json`
- `meus-remedios/.agent/sessions/.lock`
- `meus-remedios/.agent/sessions/events.jsonl`
- `meus-remedios/.agent/synthesis/pending_export.json`

---

## Fases de Implementação

### Fase 0 — Repositório DEVFLOW + Skill Template

**Local:** `/Users/coelhotv/SKILLS/devflow` — repositório dedicado, independente do second-brain.

**Passos:**
1. Criar diretório `/Users/coelhotv/SKILLS/devflow`
2. `git init` + estrutura inicial do repo
3. Criar conta/repo GitHub `devflow` (ou `coelhotv/devflow`) + `git remote add origin`
4. Escrever `DEVFLOW.md` completo (o skill template mestre)
5. Criar `README.md` com: o que é DEVFLOW, como instalar, como usar, estrutura de arquivos
6. Criar `templates/` com arquivos-template para novos projetos:
   - `templates/state.json` — state.json com placeholders
   - `templates/genes.json` — genes com valores padrão
   - `templates/rules.json` — array vazio com comentário de schema
7. Criar `scripts/setup.sh` — script de setup automatizado (ver abaixo)
8. Primeiro commit + push

---

### Script de Setup Automatizado (`scripts/setup.sh`)

O script deve automatizar o máximo possível do processo de inicialização do `.agent/` em qualquer projeto.

**Uso:** `bash /Users/coelhotv/SKILLS/devflow/scripts/setup.sh [project-path] [project-name] [stack]`

**O que o script faz:**
1. Cria toda a árvore de diretórios `.agent/` no projeto alvo
2. Copia templates de `/Users/coelhotv/SKILLS/devflow/templates/`
3. Substitui placeholders em `state.json` com nome/slug/stack informados
4. Checa se `~/.devflow/global_base/` existe → se sim, oferece import automático
5. Adiciona `/.agent/sessions/.lock` e `/.agent/sessions/events.jsonl` ao `.gitignore` (runtime, não versionados)
6. Adiciona `.agent/` ao `.gitignore` EXCETO `memory/` e `evolution/` (esses são versionados)
7. Exibe checklist de próximos passos manuais (popular knowledge.json, ADR archaeology, etc.)

**Saída esperada:**
```bash
$ bash setup.sh ~/git/novo-projeto "novo-projeto" "react,vite,supabase"
✓ .agent/ structure created (14 directories, 8 files)
✓ state.json initialized for novo-projeto
✓ genes.json copied from defaults
✓ .gitignore updated
ℹ ~/.devflow/global_base/ found — importing 28 universal rules...
✓ 28 GR-NNN imported to .agent/memory/rules.json
✓ 15 GAP-NNN imported to .agent/memory/anti-patterns.json

Next steps (manual):
1. Populate .agent/memory/knowledge.json with stack-specific facts
2. Copy DEVFLOW.md from /Users/coelhotv/SKILLS/devflow/DEVFLOW.md
3. Run: /devflow status
```

---

## Migração da Base de Conhecimento do meus-remedios (7 Ondas)

O meus-remedios possui a maior base de memória existente (156+ regras, 100+ anti-patterns, journal semanal, knowledge, docs de referência). A migração é o trabalho de maior valor: gera a base local sólida E o corpus inicial da base global `~/.devflow/`. Cada onda é independente e entrega valor por si mesma.

---

### Onda 0 — Scaffolding da estrutura `.agent/`

**Objetivo:** criar toda a árvore de diretórios e arquivos base vazios.

**Entregáveis:**
```
meus-remedios/.agent/
  DEVFLOW.md                          ← cópia da skill mestre
  state.json                          ← inicializado com metadados do projeto
  memory/
    rules.json                        ← []
    anti-patterns.json                ← []
    contracts.json                    ← []
    decisions.json                    ← []
    knowledge.json                    ← []
    rules_detail/
    anti-patterns_detail/
    contracts_detail/
    decisions_detail/
    journal/
      archive/
  evolution/
    genes.json                        ← valores padrão
    evolution_log.jsonl               ← entrada de init
  sessions/
    .lock
    events.jsonl                      ← entrada de init
  synthesis/
    pending_export.json               ← []
```

**Critério:** `/devflow status` retorna estrutura válida, contadores em zero.

---

### Onda 1 — Migração de Regras (rules.md → rules.json + rules_detail/)

**Objetivo:** extrair cada R-NNN em dois artefatos: índice JSON compacto + arquivo Markdown rico.

**Volume:** 156 regras → 156 entradas JSON + 156 arquivos Markdown

**Processo por regra:**
1. Extrair: id, título, summary (1 linha), tags, applies_to
2. Estimar incident_count a partir de menções no journal
3. Inferir review_due = data estimada de criação + 12 semanas
4. Criar `rules_detail/R-NNN.md`: rationale completo, código de exemplo, anti-pattern relacionado

**Schema de entrada em rules.json:**
```json
{
  "id": "R-NNN",
  "title": "...",
  "summary": "Uma linha descrevendo a regra",
  "applies_to": ["js", "ts", "react", "supabase", "telegram", "all"],
  "tags": ["file-management", "timezone", "zod", "performance", "design"],
  "incident_count": 0,
  "last_referenced": null,
  "review_due": "YYYY-MM-DD",
  "status": "active",
  "has_detail": true
}
```

**Sub-ondas (para volume gerenciável):**
- Onda 1a: R-001 a R-050 (gestão de arquivos, React, dados/validação)
- Onda 1b: R-051 a R-100 (Telegram, infra, qualidade de código)
- Onda 1c: R-101 a R-156 (performance, design, UI/UX)

**Critério:** `rules.json` com 156 entradas; `rules_detail/` com 156 arquivos; contadores corretos.

---

### Onda 2 — Migração de Anti-Patterns (anti-patterns.md → anti-patterns.json + anti-patterns_detail/)

**Objetivo:** mesmo processo da Onda 1, para os anti-patterns.

**Volume:** ~100+ APs → 100+ entradas JSON + 100+ Markdown

**Schema de entrada em anti-patterns.json:**
```json
{
  "id": "AP-NNN",
  "title": "...",
  "summary": "O que não fazer — em uma linha",
  "applies_to": ["js", "ts", "react", "all"],
  "tags": ["timezone", "zod", "performance", "ux"],
  "trigger_count": 0,
  "last_triggered": null,
  "expiry_date": "YYYY-MM-DD",
  "status": "active",
  "related_rule": "R-NNN",
  "has_detail": true
}
```

**`anti-patterns_detail/AP-NNN.md` contém:** problema, exemplo ruim, exemplo correto, como prevenir, incidentes registrados.

**Sub-ondas:**
- Onda 2a: AP-001 a AP-A04 (gestão de código)
- Onda 2b: AP-P01 a AP-P21 (performance)
- Onda 2c: AP-W01 a AP-W23 (UX/workflow)
- Onda 2d: AP-S01, AP-D01 a AP-D06 (stock, design)

---

### Onda 3 — Estruturação do Knowledge (knowledge.md → knowledge.json)

**Objetivo:** converter `knowledge.md` de markdown livre para JSON estruturado por topic/fact.

**Processo:** cada fato discreto → entrada `{topic, fact, correct, valid_for, source}`. Fatos com código extenso → `knowledge_detail/K-NNN.md` on-demand.

---

### Onda 4 — Arqueologia de ADRs (decisions.json + decisions_detail/)

**Objetivo:** surfaçar decisões arquiteturais implícitas no CLAUDE.md, journals e histórico de PRs, formalizando como ADRs.

**Fontes (em ordem de riqueza):**
1. **PRs mergeados (GitHub)** — fonte mais rica: cada PR tem contexto de mudança, discussão, motivação
2. **`.memory/journal/`** — sprints semanais com decisões tomadas
3. **`CLAUDE.md`** — regras críticas que escondem decisões arquiteturais
4. **`docs/`** — architecture docs com decisões de design

**Sub-etapa: Mining de PRs com Agente**

Escalar um agente (`gh pr list --state merged --limit 100 --json number,title,body,mergedAt`) para:
1. Listar todos os PRs mergeados do meus-remedios
2. Para cada PR: ler título, body, labels, reviews
3. Identificar padrões de decisão: "Por que não X", "Decidimos Y por causa de Z", mudanças de arquitetura, breaking changes
4. Gerar rascunhos de ADRs a partir dos achados
5. Consolidar com os achados das outras fontes

**Processo combinado:**
```
Agent: gh pr list --state merged --limit 100 → resumo por PR
Agent: gh pr view <n> --json body,reviews,comments → detalhe de PRs relevantes
Human/Agent: consolidar em ADR-NNN rascunhos
Human: revisar e promover de proposed → accepted
```

**Exemplos esperados (identificados na exploração):**
- ADR-001: Zod enums em português
- ADR-002: Sem process.exit() em serverless
- ADR-003: Merge apenas por humano (não por agente)
- ADR-004: Vercel Hobby — limite de 12 funções serverless
- ADR-005: Schemas Zod apenas em `src/schemas/`
- ADR-006: Views com lazy loading + Suspense + ViewSkeleton
- ADR-007: Commit semântico em português
- ADR-008: Arquitetura feature-based (não layer-based)
- ADR-009: Gemini Code Assist para review (não apenas humano)
- ... (estimativa com PRs: 30-50 ADRs, muito mais rico que apenas docs)

**`decisions_detail/ADR-NNN.md` contém:** contexto, opções consideradas, decisão tomada, consequências, status, link do PR originador se disponível, rollback.

---

### Onda 5 — Extração de Contratos (contracts.json + contracts_detail/)

**Objetivo:** mapear interfaces estáveis entre features e services.

**Fontes:** `docs/reference/SERVICES.md`, `HOOKS.md`, `SCHEMAS.md`, `src/shared/`.

**Exemplos esperados:**
- CON-001: `logService.createLog()`
- CON-002: `useCachedQuery(key, fetcher, options)`
- CON-003: `parseLocalDate()` de dateUtils
- CON-004: Schema `stockSchema` (Zod)
- CON-005: `<Button>` props interface
- ... (estimativa: 15-25 contratos)

**`contracts_detail/CON-NNN.md` contém:** assinatura completa, consumidores (com grep), breaking change definition, migration guide.

---

### Onda 6 — Export Global e Base Universal

**Objetivo:** identificar conhecimento universal (não específico do meus-remedios) e exportar para `~/.devflow/global_base/`.

**Critério de universalidade:** aplica-se a qualquer projeto React+JS+Supabase sem mencionar conceitos de domínio (remédio, dose, paciente, telegram bot).

**Processo:** varrer rules.json e anti-patterns.json filtrando por applies_to sem tags de domínio → exportar candidatos com novos IDs (GR-NNN, GAP-NNN) para `~/.devflow/`.

**Exemplos esperados:**
- GR-001: Timezone — nunca `new Date('YYYY-MM-DD')`
- GR-002: Supabase `.nullable().optional()` para campos nullable
- GR-003: Zod enums devem usar valores do banco
- GR-004: Verificar duplicatas antes de editar
- GAP-001: Nunca `process.exit()` em serverless
- GAP-002: CSS hardcoded → sempre tokens
- ... (estimativa: 20-30 itens universais)

**Estrutura resultante:**
```
~/.devflow/
  global_base/
    universal_rules.json         ← 20-30 GR-NNN
    universal_anti_patterns.json ← 15-20 GAP-NNN
    rules_detail/GR-NNN.md
    anti-patterns_detail/GAP-NNN.md
    index.json                   ← {projects: ["meus-remedios"], last_export: "..."}
```

---

### Onda 7 — Validação e Primeira Sessão DEVFLOW Live

**Checklist de validação:**
1. `/devflow status`: rules_count=156, anti_patterns_count=100+, decisions_count=20+, contracts_count=15+
2. Filtro por tags funciona: goal "react" carrega apenas regras com tag "react"
3. Detalhe on-demand: R-020 em `rules.json` → `rules_detail/R-020.md` carregado quando timezone no goal
4. ADR gateway: breaking change em CON-001 → HALT + draft ADR
5. Lock: arquivo `.lock` criado e limpo após escrita de memória
6. Journal: `journal/2026-W15.jsonl` tem entrada válida após sessão
7. Global import: novo projeto fictício consegue importar GR-001 e GR-002 em < 30 min

---

## Estrutura como Template para Novos Projetos

Ao final das 7 ondas, `.agent/` do meus-remedios serve como **template de referência**:

```
.agent/                          # Template completo
  DEVFLOW.md                     # Copiada do second-brain
  state.json                     # Inicializar com dados do novo projeto
  memory/
    rules.json                   # Partir de [] ou importar de ~/.devflow/global_base/
    anti-patterns.json           # Idem
    contracts.json               # []
    decisions.json               # []
    knowledge.json               # Seed com stack e arquivos-chave
    rules_detail/                # Vazio; cresce com o projeto
    anti-patterns_detail/
    contracts_detail/
    decisions_detail/
    journal/archive/
  evolution/genes.json           # Valores padrão (copiado do template)
  sessions/.lock
  sessions/events.jsonl
  synthesis/pending_export.json  # []
```

**Onboarding de novo projeto em < 30 minutos:**
1. Copiar estrutura acima
2. Zerar índices JSON ou importar de `~/.devflow/global_base/`
3. Popular `knowledge.json` com fatos do novo stack
4. Atualizar `state.json` com nome/slug/stack
5. `/devflow status` → pronto

---

## Estratégia de Execução por Janelas de Tempo

Dado o limite de tokens do Claude Pro (janelas de ~5h), este projeto **não pode ser executado em uma sessão contínua**. Cada onda deve ser um **Execution Spec independente**, com estado de progresso persistido em arquivo para que a próxima janela retome sem perda de contexto.

### Arquivo de Controle: `devflow-migration-status.json`

Localização: `/Users/coelhotv/SKILLS/devflow/migration-status.json`

```json
{
  "project": "meus-remedios",
  "last_updated": "2026-04-07",
  "waves": {
    "wave_0": { "status": "pending", "started": null, "completed": null, "notes": "" },
    "wave_1a": { "status": "pending", "started": null, "completed": null, "rules_done": 0, "rules_total": 50 },
    "wave_1b": { "status": "pending", "started": null, "completed": null, "rules_done": 0, "rules_total": 50 },
    "wave_1c": { "status": "pending", "started": null, "completed": null, "rules_done": 0, "rules_total": 56 },
    "wave_2a": { "status": "pending", "started": null, "completed": null, "aps_done": 0, "aps_total": 4 },
    "wave_2b": { "status": "pending", "started": null, "completed": null },
    "wave_2c": { "status": "pending", "started": null, "completed": null },
    "wave_2d": { "status": "pending", "started": null, "completed": null },
    "wave_3": { "status": "pending", "started": null, "completed": null },
    "wave_4": { "status": "pending", "started": null, "completed": null, "prs_mined": false, "adrs_done": 0 },
    "wave_5": { "status": "pending", "started": null, "completed": null, "contracts_done": 0 },
    "wave_6": { "status": "pending", "started": null, "completed": null, "items_exported": 0 },
    "wave_7": { "status": "pending", "started": null, "completed": null }
  }
}
```

### Specs de Execução por Onda

Cada onda terá seu próprio arquivo de spec em `/Users/coelhotv/SKILLS/devflow/specs/`:

```
specs/
  WAVE_0_SCAFFOLDING.md     # Setup inicial do .agent/
  WAVE_1A_RULES_1-50.md     # Migração R-001 a R-050
  WAVE_1B_RULES_51-100.md   # Migração R-051 a R-100
  WAVE_1C_RULES_101-156.md  # Migração R-101 a R-156
  WAVE_2A_AP_CODE.md        # Anti-patterns de código
  WAVE_2B_AP_PERF.md        # Anti-patterns de performance
  WAVE_2C_AP_UX.md          # Anti-patterns de UX/workflow
  WAVE_2D_AP_OTHER.md       # Anti-patterns restantes
  WAVE_3_KNOWLEDGE.md       # Estruturação de knowledge.json
  WAVE_4_ADR_MINING.md      # Arqueologia de ADRs + PR mining
  WAVE_5_CONTRACTS.md       # Extração de contratos
  WAVE_6_EXPORT_GLOBAL.md   # Export para ~/.devflow/
  WAVE_7_VALIDATION.md      # Validação e primeira sessão live
```

### Protocolo de Retomada entre Janelas

**Início de cada janela:**
1. Ler `migration-status.json` → identificar onda atual e progresso
2. Ler o spec da onda (ex: `WAVE_1A_RULES_1-50.md`) → saber exatamente o que falta
3. Verificar `rules.json` atual → confirmar quantas entradas existem (estado real)
4. Retomar da última entrada processada (não do zero)

**Final de cada janela:**
1. Atualizar `migration-status.json` com progresso real
2. Fazer commit do progresso: `git commit -m "feat(wave-1a): migrar R-001 a R-035 para rules.json"`
3. Push para GitHub → contexto seguro entre janelas

### Estimativa de Janelas Necessárias

| Onda | Esforço estimado | Janelas |
|------|-----------------|---------|
| 0 + Fase 0 (repo + DEVFLOW.md) | Alto (skill completa) | 1-2 |
| 1a + 1b + 1c (156 regras) | Alto | 3-4 |
| 2a + 2b + 2c + 2d (~100 APs) | Alto | 2-3 |
| 3 (knowledge) | Médio | 1 |
| 4 (ADRs + PR mining) | Alto | 2-3 |
| 5 (contratos) | Médio | 1-2 |
| 6 (export global) | Baixo | 1 |
| 7 (validação) | Baixo | 1 |
| **Total estimado** | | **12-17 janelas** |

**Prioridade de execução:** Fase 0 → Onda 0 → Onda 1a → resto em paralelo com uso real do projeto.

---

## Verificação Final

1. `/devflow status` retorna contagens corretas
2. Sessão de planning cria spec em `plans/` e journal entry
3. Sessão de coding detecta violação de contrato (testar breaking change em mock)
4. Distilação comprime journal e reseta contadores
5. Lock serializa escritas concorrentes
6. Export global cria entradas em `~/.devflow/global_base/`
7. Novo projeto fictício onboards a partir da base global em < 30 minutos
