# Draft E/M3 — `Non-Goals` + `Invariants` obrigatórios no S4

- **Alvo:** `skills/devflow-spec/SKILL.md`, seção **S4**, bloco *Tier 1 (lite)* — vale T1 e T2, **não T0**.
- **origin:** `proactive` · **Fecha:** PO-11
- **INV-5:** não toca C1/C4/Bootstrap ⇒ não se aplica. Entra como piloto por DT-3.
- **Mirror:** o próprio `spec.md` desta spec (`## Non-Goals`, `## System Invariants`) — a seção nasceu
  aqui à mão, sem o S4 a exigir; é a evidência de que o formato cabe.

## Orçamento (DT-1)

- **(a) Que mecanismo estende?** O S4 já lista seções obrigatórias por tier. Duas linhas a mais nessa
  lista. Nenhum mecanismo novo.
- **(b) O que aposenta?** Nada removido. Mas `Non-Goals` **absorve** parte do trabalho que hoje o
  P1 (Scope Analysis) faz e perde: o escopo recusado só vive na conversa do Planning e evapora.
- **(c) Podia ser script?** Parcialmente: um gate poderia contar `## Non-Goals` e `≥2` itens. Mas não
  consegue julgar se o item é específico ou ritual — que é exatamente o modo de falha temido. Prosa
  é a escolha certa aqui, e o `mode-gate.sh` pode ganhar a contagem depois, como nível 1 barato.

## Texto proposto — `devflow-spec/SKILL.md`, S4, dentro do bloco Tier 1 (lite)

```
  - **`## Non-Goals`** — ≥2 itens, obrigatório em T1 e T2 (T0 não tem spec). Cada item nomeia algo
    ADJACENTE que alguém razoavelmente esperaria desta spec e que ela RECUSA, com o motivo em uma
    linha. "Não refatorar o resto" é ritual, não Non-Goal: não nomeia nada adjacente nem diz por quê.
    O teste do item: alguém poderia ter escrito um FR para ele? Se não poderia, não é um Non-Goal.
  - **`## Invariants`** — regras que nenhuma parte da implementação pode violar, numeradas `INV-N`.
    Ressalva de promoção: um invariante que sobrevive à entrega e passa a valer para OUTRO trabalho
    deixou de ser desta spec — promova-o a `CON-NNN` no CONTRACTS_INDEX e deixe aqui só a referência.
    Invariante que ninguém fora desta spec vai ler fica aqui mesmo.
    [PILOTO 2026-09 · origin: proactive · remoção: ver DEVFLOW-META.md, MP-004]
```

## Assinatura de atrito prevista (DT-2)

`kind: no-slot` (o agente precisou registrar escopo recusado e não tinha onde) ou
`kind: reinvented` (inventou uma seção equivalente com outro nome), em **10 specs T1+**.

## Cláusula de falsificação / sunset

- **5 specs seguidas com `Non-Goals` genéricos** ⇒ a seção está sendo preenchida por ritual:
  reduzir a **1 item** e exigir que ele cite um FR adjacente explicitamente recusado.
- **10 specs sem nenhum `INV-N` citado depois, em C-mode ou review** ⇒ REMOVER `Invariants`:
  invariante que ninguém invoca é decoração.
- Relógio conta a partir do primeiro projeto consumidor com ledger ativo (A-1).
