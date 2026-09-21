# Draft E/M2 — Pre-Report Gate mínimo (RC5 Pass 1)

- **Alvo:** `skills/devflow-code/SKILL.md`, entre *Verification of Claims (Anti-Rationalization
  Rules)* (:718) e *Fix-First Protocol* (:726).
- **origin:** `proactive` · **Fecha:** PO-13
- **INV-5:** RC5 **não** é C1/C4/Bootstrap ⇒ não se aplica. Piloto por DT-3.
- **Mirror:** a seção *Suppressions — DO NOT flag* do mesmo arquivo — que este draft **referencia
  e NÃO repete** (exigência explícita do T043 e da linha "não fazer" do relatório de garimpo).

## Orçamento (DT-1)

- **(a) Que mecanismo estende?** O *Verification of Claims*, que já proíbe rationalizar um achado
  para FORA ("likely handled"). Falta o simétrico: rationalizar um achado para DENTRO. O gate é o
  outro lado da mesma regra, colado nela.
- **(b) O que aposenta?** Nada removido. O limiar absorve o julgamento implícito que hoje o RC5 faz
  sem vocabulário — e que o Pass 0 (slice D) já aprendeu a fazer para POs (`evidence_class`).
  Mesma família: **demonstrado vs. afirmado**, agora aplicada ao achado de review.
- **(c) Podia ser script?** Não. Um script não mede confiança num achado. Podia ser rubrica numérica
  — e é **proibido** pelo Non-Goal 3 da spec (rubricas 1–10 rejeitadas). Por isso o limiar é um
  teste verbal ("você apostaria?"), não uma nota.

## Texto proposto — `devflow-code/SKILL.md`, após *Verification of Claims*

```
#### Pre-Report Gate (Tier 1+; antes de escrever qualquer achado)

Um achado que não passa nos três testes abaixo NÃO é reportado. Isto é o simétrico do
*Verification of Claims*: aquele impede descartar bug real, este impede inventar bug irreal.

1. **LIMIAR.** Reporte apenas o que você sustentaria numa aposta — acima de ~80% de confiança de
   que é defeito real neste código, não uma preferência sua. Abaixo disso, CALE. Não é uma nota
   numérica a registrar: é o teste verbal "eu apostaria que isto quebra?".
2. **PROVA OBRIGATÓRIA para HIGH e CRITICAL.** Severidade alta sem as três partes é rebaixada a
   MEDIUM ou descartada:
     (a) o snippet exato (`file:line`) onde o defeito mora;
     (b) input / estado concreto → desfecho errado (o mesmo par do `failure_scenario`);
     (c) **por que as guardas atuais não pegam** — qual teste, tipo, schema ou lint deveria ter
         barrado e não barra. Sem (c) o achado é uma hipótese, e hipótese não é CRITICAL.
3. **ZERO ACHADOS É RESULTADO CORRETO E ESPERADO.** `Pre-Landing Review: No issues found.` é uma
   saída válida e frequente. NÃO fabrique achado para justificar a execução do RC5 — inventar um
   MEDIUM para a revisão "render algo" é a falha que este gate existe para impedir, e custa mais
   caro que não revisar, porque ensina o operador a ignorar a saída.

O catálogo de falsos positivos NÃO se repete aqui: ver *Suppressions — DO NOT flag*, abaixo.
[PILOTO 2026-09 · origin: proactive · remoção: ver DEVFLOW-META.md, MP-004]
```

## Adição às *Suppressions* — no máximo 2 linhas (teto do garimpo)

```
- Número mágico cujo significado é óbvio no contexto imediato (`* 1000` para ms, `/ 100` para %)
- Falta de try/catch sob um error boundary, middleware ou supervisor que já captura — cite o
  captador ao suprimir; sem citá-lo, isto não é supressão, é suposição
```

## Assinatura de atrito prevista (DT-2)

`kind: unsatisfiable` (o agente tinha um HIGH sem conseguir produzir a parte (c)) em **5 revisões**.

## Cláusula de falsificação / sunset

- **A taxa de achados por revisão NÃO cair em 5 revisões** ⇒ o problema nunca foi o filtro:
  REMOVER o gate inteiro em vez de endurecê-lo.
- **Nenhuma revisão fechar com `No issues found` em 10 revisões** ⇒ o item 3 não está sendo lido
  como autorização; é sinal de que a pressão por achado vem de outro lugar — investigar, não inflar.
- Relógio conta a partir do primeiro projeto consumidor com ledger ativo (A-1).
