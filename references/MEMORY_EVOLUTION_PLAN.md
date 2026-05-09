# DEVFLOW Memory Evolution Plan
> Baseado em: "The AI Hippocampus: How Far are We From Human Memory?" (TMLR 11/2025)  
> Versão atual: DEVFLOW v1.7.0 → Versão alvo: v2.0.0  
> Status: PROPOSED

---

## 1. Contexto e Motivação

O DEVFLOW v1.7.0 já implementa os fundamentos de memória explícita filesystem-based: índices sparse, ciclo Assess→Execute→Record, distillation periódica e export global.

O paper categoriza memória em LLMs em três paradigmas — **Implícita** (parâmetros do modelo, analogia ao neocórtex), **Explícita** (RAG/grafos/vetores, analogia ao hipocampo) e **Agêntica** (STM+LTM em agentes autônomos, analogia ao córtex pré-frontal) — e mapeia onde a arquitetura de IA atual diverge da memória humana.

A análise de gap identificou seis oportunidades de alta alavancagem que não exigem mudança de infraestrutura — apenas extensões do schema `.agent/` e do protocolo SKILL.md:

| # | Gap Identificado | Conceito do Paper | Prioridade |
|---|-----------------|-------------------|-----------|
| G1 | Retrieval sem auto-avaliação de suficiência | Self-RAG §3.2.2 | Alta |
| G2 | Promoção de memória sem peso por frequência | Scaling Laws §2.1.1 | Alta |
| G3 | Arquivamento sem verificação de dependências | Memory Unlearning §2.2.1 | Alta |
| G4 | Memória episódica não indexada semanticamente | Episodic LTM §4.1.2 | Média |
| G5 | Crescimento linear de contexto intra-sessão | LongMem / CAMELoT §3.3.1 | Média |
| G6 | Relações entre entidades implícitas por texto | HippoRAG / Graph §3.1.2 | Baixa |

---

## 2. Conceitos-Chave, Aplicação Prática e Benefícios

---

### G1 — Self-RAG: Reflection Tokens no Assess

**Conceito do paper**  
Self-RAG (Asai et al., 2024) instrui o modelo a emitir tokens de reflexão que indicam quando o contexto recuperado é suficiente e quando buscar mais, antes de gerar qualquer resposta. Elimina execuções com contexto inadequado.

**Problema atual no devflow**  
PHASE 0 carrega hot+warm packs, mas o agente nunca sinaliza se a memória é adequada antes de executar. Falhas silenciosas ocorrem quando regras existem mas não foram carregadas porque o pack inference não as mapeou.

**Aplicação prática**  
Após PHASE 0, emitir bloco de reflexão obrigatório antes de avançar:

```
MEMORY ASSESSMENT
  confidence  : HIGH | MEDIUM | LOW
  gaps        : ["no ADR covers auth token storage", "CON-NNN missing for X"]
  auto_loaded : [R-012, R-034, AP-007, K-003]
  suggested   : [K-015 on JWT patterns — load? y/n]
```

Regras de comportamento:
- `HIGH` → avança normalmente para Execute
- `MEDIUM` → lista sugestões, aguarda go-ahead explícito do operador
- `LOW` → PARA, requer carga adicional ou confirmação explícita de risco aceito

**Casos de uso**
- Goal menciona autenticação mas nenhum ADR cobre auth → `LOW`, gap surfaced antes de qualquer código
- C1 identifica arquivo não coberto por nenhum CON-NNN → `MEDIUM`, sugestão de contrato antes do C2 Gate
- Refactor de componente com 3 regras hot diretamente aplicáveis → `HIGH`, flui sem fricção

**Benefício a longo prazo**  
Elimina a principal causa de retrabalho: execução com contexto incompleto. Torna o gap de memória explícito e humano-auditável em cada sessão.

---

### G2 — Frequency-Weighted Memory Promotion

**Conceito do paper**  
As scaling laws (Lu et al., 2024; Allen-Zhu & Li, 2024) demonstram que modelos memorizam melhor fatos de alta frequência. A capacidade de memorização segue lei de potência em relação ao número de exposições. Memória raramente ativada deve migrar para layers mais frios organicamente.

**Problema atual no devflow**  
`trigger_count` e `incident_count` existem nos índices, mas não influenciam prioridade de carga no Bootstrap. AP-007 com 40 triggers tem a mesma prioridade que AP-089 com 1 trigger, se ambas são `warm`.

**Aplicação prática**  
Adicionar campo `priority_score` calculado pela Distillation (D2) e persistido no índice:

```
priority_score = (trigger_count × 2.0) + (incident_count × 3.0) + recency_bonus
recency_bonus  = max(0, 10 − weeks_since_last_trigger)
```

Bootstrap ordena itens por `priority_score` dentro de cada layer. Novo gene:

```json
"bootstrap_memory_budget": 20
```

Itens com score zero por mais de `anti_pattern_expiry_weeks` → candidatos automáticos a deprecação na próxima Distillation.

**Casos de uso**
- AP-007 triggered 40 vezes → sempre no topo do bootstrap, visível antes de qualquer edit
- R-089 adicionada há 8 meses, nunca referenciada → score cai, migra para cold organicamente
- ADR-003 com 3 incidentes recentes → prioridade máxima na sessão seguinte ao incidente

**Benefício a longo prazo**  
Bootstrap auto-calibra pelo comportamento real do projeto. Memória raramente usada migra para cold sem curadoria manual. Projetos maduros convergem para bootstraps cada vez mais relevantes sem overhead.

---

### G3 — Dependency-Aware Memory Unlearning

**Conceito do paper**  
Knowledge unlearning (Liu et al., 2024; Tian et al., 2024) remove conhecimento específico sem degradar o restante. O risco central é "knowledge interference": remover entidade A pode silenciosamente invalidar entidade B que referenciava A. Frameworks como EUL e MemFlex introduzem verificação de dependência antes da remoção.

**Problema atual no devflow**  
Arquivar R-NNN ou AP-NNN é manual e muda apenas o campo `status`. Não há verificação de quais outros artefatos referenciam o item sendo removido. Referências a IDs arquivados permanecem ativas nos detail files de outras entidades.

**Aplicação prática**  
Antes de arquivar qualquer entidade, o agente executa Dependency Scan obrigatório:

```
DEPENDENCY SCAN — ADR-012 (candidato a arquivamento)
  Referenciado em:
    rules/backend/R-034.md      linha 12 — "ver ADR-012 para rationale"
    anti-patterns/auth/AP-007.md linha 8  — "conforme decisão em ADR-012"
    contracts/api/CON-005.md    linha 3  — "gateway definido em ADR-012"

  ⚠️ DEVFLOW: DEPENDENT_MEMORY — 3 dependentes encontrados.
  Opções:
    (a) Atualizar dependentes para remover referência antes de arquivar
    (b) Marcar ADR-012 como "deprecated" — mantém ID válido, sinaliza obsolescência
    (c) Cancelar arquivamento
```

Arquivamento só prossegue após resolução explícita de cada dependente.

**Casos de uso**
- Decisão arquitetural revogada mas 5 regras ainda a referenciam → update em cadeia forçado
- Anti-pattern deprecado que justificava um contrato → CON-NNN revisado antes do arquivamento
- Regra promovida para global base → arquivo local mantém ponteiro `superseded_by: GR-NNN`

**Benefício a longo prazo**  
Elimina "memória fantasma" — referências a IDs que não existem. Mantém consistência referencial ao longo de anos de evolução do projeto. Permite auditar o grafo de dependências em qualquer ponto histórico.

---

### G4 — Episodic Memory Index

**Conceito do paper**  
Memória episódica (Atkinson-Shiffrin, 1968; §4.1.2) armazena eventos específicos com seu contexto temporal, permitindo recuperar "o que aconteceu quando X estava em escopo". HippoRAG (Gutiérrez et al., 2025) usa Personalized PageRank sobre grafo de entidades para multi-hop retrieval episódico. O journal do devflow é append-only mas não indexado semanticamente.

**Problema atual no devflow**  
Não há forma de responder "qual decisão foi tomada na sessão que tocou `src/auth/`?" sem ler todo o journal. O Bootstrap não usa histórico de sessões para inferir contexto relevante.

**Aplicação prática**  
Novo arquivo: `.agent/memory/EPISODIC_INDEX.md`

```markdown
| episode_id | date       | goal_type | files_pattern   | rules_triggered     | aps_fired | outcome   |
|------------|------------|-----------|-----------------|---------------------|-----------|-----------|
| EP-001     | 2025-01-14 | feature   | src/auth/*      | R-012, R-034        | AP-007    | completed |
| EP-002     | 2025-01-21 | fix       | api/payments/*  | R-021               | none      | completed |
| EP-003     | 2025-02-03 | refactor  | src/auth/*, */* | R-012, R-034, R-041 | AP-007    | halted    |
```

Bootstrap adiciona step opcional: se arquivos em escopo correspondem a `files_pattern` de episódios anteriores → carregar episódios como contexto adicional.

Distillation (D1) popula o índice a partir de `events.jsonl` automaticamente.

**Casos de uso**
- Arquivo `src/auth/token.ts` em escopo → Bootstrap encontra EP-001 e EP-003, carrega que AP-007 foi triggered duas vezes nesse contexto
- Goal type "fix" em `api/payments/*` → Bootstrap referencia EP-002, sugere R-021 como regra comprovada
- Sessão halted (EP-003) → próxima sessão no mesmo escopo recebe flag de "sessão anterior interrompida"

**Benefício a longo prazo**  
Agente aprende padrões de risco por contexto de arquivo, não apenas por categoria global. Regiões do código com histórico de problemas recebem atenção extra automaticamente.

---

### G5 — Intra-Session Context Compression

**Conceito do paper**  
LongMem (Wang et al., 2023) e CAMELoT (He et al., 2024) comprimem contexto passado em representações compactas, descartando redundância e liberando espaço para conteúdo novo. Sessions longas com múltiplas iterações C3→C4→fix acumulam trace linear que se torna noise.

**Problema atual no devflow**  
Não há compressão intra-sessão. Sessões longas com muitas iterações crescem sem poda, tornando o contexto tardio da sessão menos coerente.

**Aplicação prática**  
Nova fase opcional: `C3.5 — Context Compression` entre iterações de implementação.

Ativada quando: número de tool calls desde C2 > gene `context_compression_threshold` (default: 15).

Protocolo:
1. Sumarizar arquivos modificados até agora em bullets concisos
2. Registrar `{"event": "context_compressed", "summary": "...", "files_done": [...]}` em `events.jsonl`
3. Descartar trace detalhado de iterações anteriores, preservar apenas state diff e critérios pendentes do C1
4. Retomar C3 com contexto comprimido

**Casos de uso**
- Feature grande com 8 arquivos: após 3 arquivos, comprime o que foi feito, continua com contexto limpo
- Bug fix com múltiplas tentativas: comprime tentativas falhas, preserva apenas a abordagem correta
- Sessão interrompida e retomada: compressão prévia facilita handoff para próxima sessão

**Benefício a longo prazo**  
Sessões longas mantêm coerência. Custo cognitivo do agente se mantém constante independente da duração da tarefa. Reduz drift de objetivo em sessões extensas.

---

### G6 — Knowledge Graph entre Entidades

**Conceito do paper**  
HippoRAG (Gutiérrez et al., 2025) usa grafo de conhecimento com Personalized PageRank para multi-hop retrieval: dado arquivo X, encontra ADRs → que causaram APs → que impactaram contratos. As conexões no devflow são por referência textual de IDs, sem grafo explícito.

**Problema atual no devflow**  
Impossível responder "quais APs foram causados pelo mesmo incidente que gerou ADR-003?" sem leitura manual de todos os detail files.

**Aplicação prática**  
Novo arquivo: `.agent/memory/KNOWLEDGE_GRAPH.json`

```json
{
  "edges": [
    {"from": "ADR-003", "rel": "caused", "to": "AP-012", "date": "2025-01-14"},
    {"from": "AP-012",  "rel": "protects", "to": "CON-005", "date": "2025-01-14"},
    {"from": "R-034",   "rel": "references", "to": "ADR-003", "date": "2024-11-02"},
    {"from": "EP-001",  "rel": "triggered", "to": "AP-007", "date": "2025-01-14"}
  ]
}
```

Distillation (D1) popula edges a partir de referências encontradas nos detail files.  
Bootstrap pode fazer multi-hop: arquivos em escopo → ADRs relacionados (1-hop) → APs causados (2-hop).

**Casos de uso**
- Antes de modificar `CON-005`, encontrar todos os ADRs e APs que a protegem via grafo
- Dado um incidente recente, identificar toda a cadeia de conhecimento afetada
- Auditoria: "quais decisões influenciaram as regras mais triggered este trimestre?"

**Benefício a longo prazo**  
Torna o `.agent/` um knowledge graph navegável, não apenas uma coleção de arquivos. Suporta análise de impacto antes de mudanças arquiteturais significativas.

---

## 3. Plano de Implementação

### Fase 1 — Fundação (v1.8.0)
*Prioridade Alta. Sem dependências entre si. Podem ser implementados em paralelo.*

#### Passo 1.1 — Self-RAG Reflection Tokens

**Arquivos a modificar**: `SKILL.md` (PHASE 0, Response Format)

Mudanças:
1. Adicionar bloco `MEMORY ASSESSMENT` como saída obrigatória ao final de PHASE 0
2. Definir regras de comportamento por nível de confidence (HIGH/MEDIUM/LOW)
3. Atualizar Response Format para incluir seção `Memory Confidence` no header de cada resposta
4. Adicionar campo `memory_confidence` ao `state.json` session object

Schema de `state.json` — adição:
```json
{
  "session": {
    "memory_confidence": "HIGH | MEDIUM | LOW",
    "memory_gaps": ["string"],
    "memory_suggested": ["R-NNN | AP-NNN | K-NNN"]
  }
}
```

#### Passo 1.2 — Frequency-Weighted Promotion

**Arquivos a modificar**: `SKILL.md` (D2), `DEVFLOW-REFERENCE.md` (Gene Reference)

Mudanças:
1. Adicionar fórmula de `priority_score` à seção D2
2. Adicionar gene `bootstrap_memory_budget` (default: 20) ao Gene Reference
3. Definir que Bootstrap ordena por `priority_score` dentro de cada layer
4. Adicionar campo `priority_score` ao schema dos índices (calculado, não manual)

Schema de índice — adição de coluna:
```markdown
| id | status | layer | trigger_count | incident_count | priority_score | ... |
```

#### Passo 1.3 — Dependency-Aware Unlearning

**Arquivos a modificar**: `SKILL.md` (D2, D2.5)

Mudanças:
1. Adicionar protocolo `DEPENDENCY SCAN` antes de qualquer operação de arquivamento
2. Definir os três caminhos de resolução (update dependentes / marcar deprecated / cancelar)
3. Adicionar status `deprecated` ao lifecycle de entidades (entre `active` e `archived`)
4. Atualizar D2.5 Memory Lifecycle Heuristics para incluir deprecated como layer intermediária

Novo status de lifecycle:
```
active → deprecated → archived
                    ↘ (se nenhum dependente) → archived direto
```

---

### Fase 2 — Episodic Memory (v1.9.0)
*Prioridade Média. Depende de Fase 1 concluída para dados de qualidade.*

#### Passo 2.1 — EPISODIC_INDEX.md Schema

**Arquivos a criar**: `.agent/memory/EPISODIC_INDEX.md` (template)  
**Arquivos a modificar**: `DEVFLOW-REFERENCE.md` (File Reference Map), `SKILL.md` (D1, PHASE 0)

Mudanças:
1. Definir schema do `EPISODIC_INDEX.md` com colunas: episode_id, date, goal_type, files_pattern, rules_triggered, aps_fired, outcome
2. Adicionar ao File Reference Map
3. Adicionar passo de escrita no D1 (Distillation): popular EPISODIC_INDEX a partir de events.jsonl
4. Adicionar ao PHASE 0: se arquivos em escopo correspondem a files_pattern → carregar episódios relevantes como contexto adicional
5. Adicionar evento `{"event": "episode_created", "episode_id": "EP-NNN"}` ao events.jsonl no C5

#### Passo 2.2 — Intra-Session Context Compression

**Arquivos a modificar**: `SKILL.md` (C3), `DEVFLOW-REFERENCE.md` (Gene Reference)

Mudanças:
1. Adicionar fase `C3.5 — Context Compression` entre iterações de implementação
2. Definir trigger: tool calls > gene `context_compression_threshold` (default: 15)
3. Definir protocolo de compressão: bullets de arquivos feitos, event em events.jsonl, descarte de trace
4. Adicionar gene ao Gene Reference

---

### Fase 3 — Knowledge Graph (v2.0.0)
*Prioridade Baixa. Depende de Fase 2. Alto valor para projetos maduros (>50 ADRs).*

#### Passo 3.1 — KNOWLEDGE_GRAPH.json

**Arquivos a criar**: `.agent/memory/KNOWLEDGE_GRAPH.json` (template)  
**Arquivos a modificar**: `DEVFLOW-REFERENCE.md` (File Reference Map), `SKILL.md` (D1, C2, PHASE 0)

Mudanças:
1. Definir schema do grafo: `{edges: [{from, rel, to, date}]}`
2. Adicionar ao File Reference Map
3. Adicionar ao D1: varrer detail files por referências a IDs, popular edges no grafo
4. Adicionar ao C2 (Contract Gateway): antes de modificar arquivo coberto por CON-NNN, fazer 2-hop no grafo (CON → ADRs relacionados → APs protetoras) e incluir no C2 Gate summary
5. Adicionar ao PHASE 0 (opcional, ativado por gene): multi-hop load de entidades relacionadas aos arquivos em escopo

Novo gene:
```json
"knowledge_graph_hop_depth": 2
```

---

## 4. Novos Genes — Tabela Completa

| Gene | Default | Fase | Descrição |
|------|---------|------|-----------|
| `bootstrap_memory_budget` | 20 | 1.2 | Top-N itens por layer no bootstrap |
| `memory_confidence_gate` | `MEDIUM` | 1.1 | Nível mínimo para avançar sem go-ahead |
| `context_compression_threshold` | 15 | 2.2 | Tool calls antes de C3.5 ser ativado |
| `knowledge_graph_hop_depth` | 2 | 3.1 | Profundidade do multi-hop no grafo |
| `episodic_index_lookback_weeks` | 12 | 2.1 | Janela temporal para busca episódica |

---

## 5. Novos Artefatos de Memória

| Arquivo | Fase | Propósito |
|---------|------|-----------|
| `.agent/memory/EPISODIC_INDEX.md` | 2.1 | Índice sparse de sessões passadas por contexto |
| `.agent/memory/KNOWLEDGE_GRAPH.json` | 3.1 | Grafo de relações entre entidades de memória |

---

## 6. Riscos e Mitigações

| Risco | Probabilidade | Mitigação |
|-------|--------------|-----------|
| MEMORY ASSESSMENT verboso demais → friction | Média | Gene `memory_confidence_gate` permite desligar gate para HIGH |
| priority_score diverge do valor real | Baixa | Score é sugestão — layer manual sempre sobrepõe |
| KNOWLEDGE_GRAPH.json cresce sem controle | Média | D2 (Lifecycle) remove edges de entidades arquivadas |
| EPISODIC_INDEX cresce sem limit | Baixa | Gene `episodic_index_lookback_weeks` limita janela de carga |
| Dependency Scan lento em projetos grandes | Baixa | Grep é O(N files) — aceitável até ~500 detail files |

---

## 7. Critérios de Sucesso por Fase

**Fase 1 (v1.8.0)**
- [ ] MEMORY ASSESSMENT emitido em 100% dos bootstraps
- [ ] `priority_score` calculado e persistido em toda Distillation
- [ ] Zero arquivamentos sem Dependency Scan precedente
- [ ] Gene `bootstrap_memory_budget` respeitado no Bootstrap

**Fase 2 (v1.9.0)**
- [ ] EPISODIC_INDEX populado automaticamente pela Distillation
- [ ] Bootstrap carrega episódios relevantes quando files_pattern bate
- [ ] Context Compression ativada em sessões longas sem perda de DoD tracking

**Fase 3 (v2.0.0)**
- [ ] KNOWLEDGE_GRAPH.json populado com edges de todos os detail files existentes
- [ ] C2 Gate inclui entidades 2-hop do grafo no summary
- [ ] Multi-hop load opcional no Bootstrap funcionando

---

## 8. Analogia Consolidada: Devflow como Cérebro

```
Memória Implícita (Neocórtex)
  → Não implementável diretamente — é o próprio modelo de linguagem
  → Devflow compensa via memória explícita de alta qualidade

Memória Explícita (Hipocampo) — JÁ IMPLEMENTADO
  → [CLASS]_INDEX.md + detail files = armazenamento episódico/semântico externo
  → RAG análogo: index-first + selective detail load

  Evoluções nesta camada:
  → G1 Self-RAG: reflexão sobre suficiência do contexto recuperado
  → G2 Frequency-Weighting: retrieval prioriza o mais frequentemente relevante
  → G3 Dependency Unlearning: remoção segura sem "knowledge interference"
  → G4 Episodic Index: recuperação por contexto de arquivo e sessão
  → G6 Knowledge Graph: multi-hop retrieval entre entidades relacionadas

Memória Agêntica (Córtex Pré-Frontal) — JÁ IMPLEMENTADO
  → state.json = STM (working memory da sessão atual)
  → journal + events.jsonl = LTM episódica (log de experiências)
  → Distillation = consolidação hipocampal→neocortical

  Evolução nesta camada:
  → G5 Context Compression: manutenção de coerência em sessões longas
```

---

*DEVFLOW Memory Evolution Plan — gerado em 2026-05-03*  
*Fonte: análise de "The AI Hippocampus: How Far are We From Human Memory?" (TMLR 11/2025)*  
*Próximo passo: aprovar Fase 1 e iniciar implementação em SKILL.md*
