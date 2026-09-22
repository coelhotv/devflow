# Draft F2/T063 — C1.5 Tier 2 pode pedir segunda opinião independente sobre a análise

- **Alvo:** `skills/devflow-code/SKILL.md`, **C1.5** — item novo `1e`, logo após o `1d`
  (uncertainty) e antes do item 2 (cross-file consistency) + 1 linha na Quick Reference.
- **origin:** `proactive` · **Fecha:** PO-19 (a metade de prosa; o uso real é MANUAL — A-2)
- **INV-5:** C1.5 não é C1/C4/Bootstrap, mas a MP-004 já o tratou "sob a mesma cautela por
  vizinhança". Mantenho: **piloto** com critério de remoção.
- **Mirror:** RC6 (`devflow-code/SKILL.md:843-850`) — a MESMA propriedade (voz independente em
  processo frio, flag-only, fail-open), aplicada à análise em vez do PR.

## O defeito que isto ataca

O cabeçalho do próprio C1.5 (`:155-159`) nomeia o modo de falha: *"an analysis.md that validates the
spec's narrative instead of the real repo is worse than no analysis"*. As regras de honestidade
(`Prefer finding gaps`, `zero gaps on a Tier 2 epic is suspect`) pedem ao **autor** que desconfie de
si mesmo — mesmo agente, mesmo contexto, mesmos pontos cegos. É o argumento exato que justificou o
RC6 sobre o RC5: autocrítica não é independência.

## Orçamento (DT-1)

- **(a) Que mecanismo estende?** As *Honesty rules* do C1.5 ("zero gaps é suspeito") — hoje só
  exortação; ganham um instrumento. E reusa o RC6 inteiro via `@core` (sem motor novo).
- **(b) O que aposenta?** Nada removido. Dá ao "re-run against the repo before declaring PASS" um
  segundo leitor em vez de uma segunda leitura do mesmo leitor.
- **(c) Podia ser script?** A voz É script (`second-opinion.sh`, T060, entregue). A prosa só diz
  QUANDO chamar e o que fazer com a resposta — isso nenhum script decide.

## Texto proposto — `devflow-code/SKILL.md`, C1.5, novo item `1e`

```
1e. SEGUNDA OPINIÃO INDEPENDENTE (Tier 2, opcional; Tier 0/1: NÃO chame). Com o analysis.md
   escrito e ANTES de declarar PASS, você pode pedir um leitor que não é você:
     ~/SKILLS/devflow/scripts/second-opinion.sh --artifact analysis \
       --spec-dir plans/specs/NNN-feature --file plans/specs/NNN-feature/analysis[-<slice>].md
   Processo frio: o motor vê o analysis, a spec e o plano — nada desta sessão. Recomendado quando a
   análise achou ZERO gaps num Tier 2 (a regra de honestidade abaixo já chama isso de suspeito).
   Cada finding devolvido vira UMA linha no analysis.md, e só uma de duas:
     acolhido — com a evidência (file:line) que você foi buscar por causa dele; ou
     recusado — com o motivo, citando o trecho que o contradiz.
   A opinião é INSUMO, não veredito: não altera sozinha a severidade nem o gate. Um HIGH acolhido
   bloqueia porque VOCÊ o acolheu com evidência, não porque o script o emitiu.
   Saída "unavailable" (nenhum motor) é fail-open: anote no analysis.md e siga — a ausência da
   segunda opinião nunca bloqueia o C1.5.
   [PILOTO 2026-09 · origin: proactive · remoção: ver DEVFLOW-META.md, MP-005]
```

## Texto proposto — Quick Reference (Do / Do Not)

```
| C1.5 T2 com zero gaps: pedir `second-opinion.sh --artifact analysis` e responder cada finding | Tratar a segunda opinião como veredito, ou chamá-la em Tier 0/1 |
```

## Assinatura de atrito prevista (DT-2)

Se isto importa, aparecerá **`contradiction`** no `process-friction.jsonl`: a segunda opinião
aponta algo que a análise afirmava como `✅` e o agente precisa corrigir a Evidence Table.
Critério de **remoção**: 5 análises Tier 2 com a segunda opinião chamada e **zero findings
acolhidos** ⇒ o leitor externo não acha nada que o autor não achasse; REMOVER o `1e`.
Critério de **remoção alternativo**: o `1e` nunca chamado em 5 análises T2 ⇒ passo morto (AP-325).
**Promoção:** ≥3 findings acolhidos, com evidência, em ≥2 specs.
⏱️ Relógio só corre em projeto consumidor com ledger ativo (A-1).

## Guard da PO-19 ("Tier 0 e Tier 1 não chamam o script")

Verificável por grep depois de aplicado: a única menção ao script no `devflow-code` fica dentro do
C1.5, cuja primeira linha já é `Tier 2 MANDATORY; Tier 1 only if risk; Tier 0 skip`, e o `1e` diz
literalmente `Tier 0/1: NÃO chame`.
