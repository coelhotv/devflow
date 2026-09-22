# Draft H/T082 — `DEVFLOW-META.md` passa a prever o caminho proativo (`external_corpus`)

- **Alvo:** `DEVFLOW-META.md`, seção *DEVFLOW.md Mutation Protocol*: nova subseção
  `### Caminho proativo (origin: external_corpus)` entre *Requisitos para propor uma mudança* e
  *Processo*.
- **origin:** `proactive` · **Fecha:** PO-23
- **Guard da PO-23:** a barra reativa (*3+ observações de ≥2 specs*) **não muda uma letra**. O
  item 1 dos *Requisitos* fica intacto. A subseção nova só descreve uma segunda porta de ENTRADA,
  e essa porta nunca leva à promoção.

## O defeito que isto ataca

Seis mutações (MP-001 a MP-006) entraram pelo caminho proativo da spec 001 (DT-2). Os controles
compensatórios delas existem só no `spec.md` da 001. O META, que é o protocolo, ainda diz que toda
mudança exige 3+ observações. Resultado: as linhas v2.4 a v2.9 do histórico parecem violar o
próprio protocolo, e a próxima spec proativa vai reinventar os controles (ou esquecê-los).

## Orçamento (DT-1)

- **(a) Que mecanismo estende?** O *Mutation Protocol*. A porta nova usa o mesmo processo (proposta
  `pending` → aprovação → aplicar → confirmar).
- **(b) O que aposenta?** Aposenta a DT-2 como regra local da spec 001: ela passa a viver no
  protocolo, e a spec só a cita.
- **(c) Podia ser script?** Não. É uma regra de admissão, julgada pelo operador na aprovação.

## Texto proposto

```
### Caminho proativo (origin: external_corpus)
A barra acima é REATIVA: dor observada → ledger → proposta. Existe uma segunda porta, PROATIVA:
oportunidade minerada de um corpus externo (outra skill, outro harness), SEM dor observada. O risco
se inverte: o pior caso deixa de ser demorar e passa a ser construir maquinário que ninguém
precisava (AP-325). Por isso ela só admite mutações com TODOS os controles abaixo:
  1. `origin: proactive` na proposta E na linha do histórico, com a citação file:line do corpus.
  2. Assinatura de atrito prevista: "se isto importa, aparecerá `<kind>` em process-friction.jsonl".
  3. Cláusula de falsificação com número: "N sessões sem <sinal> ⇒ REMOVER".
  4. Entra SEMPRE como PILOTO. Em C1/C4/Bootstrap sem incidente real, rebaixada a piloto.
  5. Os relógios de falsificação só correm em projeto consumidor com ledger ativo. Silêncio de um
     ledger que ninguém podia escrever não é evidência de ausência.
A porta proativa ADMITE um piloto. Ela nunca PROMOVE: a promoção a regra consolidada exige a barra
reativa acima, 3+ observações de ≥2 specs, sem exceção. Num repo com uma spec só a dispersão pode
ser inatingível; nesse caso o piloto espera, e a barra não afrouxa.
```

## Linha no histórico (quando aplicada)

~~`v2.10.0 (PILOTO)`~~ → **`v3.0.0 (PILOTO)`** (operador, 2026-09-22: muda o protocolo de evolução, critério de major do próprio META), seção *Mutation Protocol*. Falsificação: se nenhuma spec além da 001 usar a
porta proativa em 6 meses, a subseção volta para a DT-2 da spec 001 (a regra não era geral).
