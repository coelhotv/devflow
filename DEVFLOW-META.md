# DEVFLOW Meta-Evolution Protocol

> Carregado sob demanda — apenas quando `/devflow meta-evolve` é invocado.
> Não faz parte do bootstrap normal. Agentes não devem ler este arquivo autonomamente.

---

## Propósito

Este protocolo governa mudanças no próprio DEVFLOW: alterações em `genes.json` (comportamento do agente) e em `DEVFLOW.md` (a skill em si). Toda mutação requer evidência documentada e aprovação humana explícita.

---

## Gene Mutation Protocol

### Proposta
```
Observe um padrão que sugere que um gene deve mudar.
Documente em evolution/evolution_log.jsonl:

{
  "timestamp": "...",
  "type": "gene_mutation_proposal",
  "gene": "<gene_name>",
  "current_value": <current>,
  "proposed_value": <proposed>,
  "rationale": "<evidência do journal — cite eventos específicos>",
  "sandbox_test": "<o que teria mudado nas últimas 10 sessões com este gene ativo>",
  "status": "pending"
}

Escreva uma nota human-readable na entrada do journal atual.
NÃO aplique automaticamente. Aguarde aprovação humana.
```

### Aprovação
```
Human define status da entrada em evolution_log.jsonl → "approved".
Próxima sessão lê proposals aprovadas e aplica em genes.json.
Appenda entrada de confirmação em evolution_log.jsonl.
```

### Rollback
```
Leia evolution_log.jsonl.
Encontre a entrada do gene antes da mutação.
Restaure esse valor em genes.json.
Appenda entrada de rollback em evolution_log.jsonl.
```

---

## DEVFLOW.md Mutation Protocol

Mudanças no arquivo de skill são mais críticas que mudanças em genes — afetam todos os agentes e projetos que usam DEVFLOW.

### Requisitos para propor uma mudança
1. **3+ observações independentes** no journal suportando a mudança
2. **Evidência de regressão ou gap** — não apenas preferência estética
3. **Rascunho do texto alterado** incluído na proposta

### Processo
```
1. Documente a proposta em evolution/evolution_log.jsonl:
   {
     "type": "devflow_mutation_proposal",
     "section": "<seção afetada, ex: C1, C4, Bootstrap>",
     "rationale": "<3+ observações com referências a journal entries>",
     "draft": "<texto proposto — diff ou novo conteúdo>",
     "status": "pending"
   }

2. Aguarde aprovação humana via /devflow meta-evolve approve <id>

3. Após aprovação: aplique a mudança em DEVFLOW.md
   Bumpe a versão (v1.X.0 → v1.X+1.0 para mudanças de seção,
                    v1.X.0 → v2.0.0 para mudanças de protocolo fundamental)

4. Appenda confirmação em evolution_log.jsonl
```

### Guardrails
- Máximo 2 proposals pendentes simultâneas (de qualquer tipo)
- Nunca auto-modificar DEVFLOW.md sem este comando
- Mudanças em C1/C4/Bootstrap requerem aprovação com justificativa de incidente real
- Mudanças cosméticas (wording, exemplos) requerem apenas 1 observação + aprovação

---

## Histórico de mutações aprovadas

| Versão | Data | Seção | Mudança | Evidência |
|--------|------|-------|---------|-----------|
| v2.1.0 | 2026-06-18 | Work Tiers, S4, Goal Alignment, C4, RC5, D1 | Goal-shaped delivery: Proof Obligations (`po` blocks) verificáveis-por-transcript; C4 fecha PO colando evidência; RC5 Pass 0 audita demonstrado-vs-afirmado; state.acceptance_criteria vira ponteiro; guard escala por tier; distila o conceito `/goal` provider-agnóstico | Modelos fracos (sonnet/gpt/gemini) declarando "done" prematuro — pulando AC/regressões |
| v2.1.0 | 2026-06-18 | RC-SEC, RC3, RC2/RC4, C1 | Ceremonies absorvem PO: RC-SEC emite PO de segurança formal (+audit/evidence regulado), RC3 calibra Guard por blast-radius, RC2/RC4 emitem PO MANUAL via Ceremony Output; specs legadas pré-v2.1 com backfill lazy/oportunista no C1 (só AC tocadas; nunca big-bang) | Q1/Q2 da sessão de design v2.1: integrar conceito às ceremonies + migrar histórico sem desperdício |
| v1.7.0 | 2026-04-26 | C1, C4 | Canonical path verification + file-by-file DoD | AP-117, incidente N1.5 (buildNotificationPayload) |
| v1.7.0 | 2026-04-26 | Estrutura | Remoção de State Machine e Gene Reference para arquivos separados | Risco de context overflow em modelos menores |
