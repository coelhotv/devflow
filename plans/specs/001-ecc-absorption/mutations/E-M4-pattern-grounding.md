# Draft E/M4 — P2.5 Pattern Grounding (só Tier 2)

- **Alvo:** `skills/devflow-plan/SKILL.md`, **nova seção P2.5**, entre P2 (ADR Check) e P3 (Spec Creation).
- **origin:** `proactive` · **Fecha:** PO-12 (junto com M5)
- **INV-5:** não toca C1/C4/Bootstrap ⇒ não se aplica.
- **Mirror:** `skills/devflow-plan/SKILL.md:99-101` (P3 Tier 2 já exige `file:line` verificado para
  *estrutura*) — o P2.5 estende a MESMA disciplina de estrutura para **convenção**.

## Orçamento (DT-1)

- **(a) Que mecanismo estende?** A exigência de evidência `file:line` verificada que o P3 Tier 2 já
  faz. Não é mecanismo novo: é a mesma prova aplicada a outro objeto.
- **(b) O que aposenta?** Nada removido. Absorve o improviso de "seguir o padrão do projeto", hoje
  não escrito em lugar nenhum e portanto não auditável.
- **(c) Podia ser script?** Não. Achar o padrão dominante de nomenclatura/erro/acesso a dados exige
  julgamento sobre código. O que o script PODE fazer (e o gate faz de graça) é rejeitar célula vazia.

## Por que **só Tier 2**

Tier 1 herda a mesma disciplina pelo campo `Mirror:` da task (M5), que aponta o exemplar concreto
a imitar. Obrigar uma tabela de 4 linhas num slice de uma tarde é o preenchimento ritual que o
DT-1 manda evitar. **Tier 0 não passa por Planning.**

## Texto proposto — `devflow-plan/SKILL.md`, nova seção entre P2 e P3

```
### P2.5 — Pattern Grounding (Tier 2 apenas)
```
Antes de escrever o plano, ancore-o nas convenções QUE JÁ EXISTEM no repositório. O modo de falha
que isto evita: o plano introduz um utilitário novo ao lado de um equivalente que já existe, e
nenhum gate reclama porque o código novo está correto — só está duplicado e divergente.

Preencha a tabela. Cada célula traz um `file:line` REAL, obtido com grep/find/Read nesta sessão —
nunca de memória — ou a string literal `NENHUM PADRÃO EXISTENTE`. **Célula vazia bloqueia o P3.**

| Dimensão        | Padrão vigente | Evidência (file:line) |
|-----------------|----------------|-----------------------|
| Naming          |                |                       |
| Error handling  |                |                       |
| Data access     |                |                       |
| Tests           |                |                       |

REGRAS:
  - PROIBIDO inventar convenção. Se o grep não achou, a célula é `NENHUM PADRÃO EXISTENTE` — e isso
    é um achado legítimo, não uma falha sua.
  - PROIBIDO introduzir utilitário/helper novo quando a linha correspondente aponta um padrão
    existente. Quer divergir? Então é decisão arquitetural: volta ao P2 e vira ADR.
  - `NENHUM PADRÃO EXISTENTE` em Data access ou Error handling num repo maduro é SUSPEITO — quase
    sempre significa que a busca foi rasa. Varie os termos uma vez antes de aceitar.
  - Tier 1 NÃO preenche esta tabela: herda a ancoragem pelo campo `Mirror:` de cada task (P3).
  [PILOTO 2026-09 · origin: proactive · remoção: ver DEVFLOW-META.md, MP-004]
```
```

## Assinatura de atrito prevista (DT-2)

`kind: reinvented` (o agente criou um helper que já existia) ou `kind: no-slot`, em **5 slices T2**.

## Cláusula de falsificação / sunset

- **5 slices T2 sem nenhuma revisão (RC5/RC6) citar divergência de convenção** ⇒ REMOVER: a tabela
  não está prevenindo nada que o review já não pegue.
- **Se `NENHUM PADRÃO EXISTENTE` aparecer em >50% das células ao longo de 5 slices** ⇒ o P2.5 está
  sendo preenchido como formulário de escape: cortar para 2 dimensões (Data access + Error handling).
- Relógio conta a partir do primeiro projeto consumidor com ledger ativo (A-1).
