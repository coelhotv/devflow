# Draft E/T039 — `uncertainty:` chega onde a ignorância acontece (C1.5 + C4)

- **Alvo:** `skills/devflow-code/SKILL.md`, **C1.5** (item novo `1d`, logo após o `1c` de parada) e
  **C4** (uma linha no bloco de fechamento de PO).
- **origin:** `proactive` · **Fecha:** **PO-10** (dívida transferida do slice D em 2026-09-19)
- **INV-5:** ⚠️ **APLICA-SE** — toca o **C4**, e não há incidente real. Essa parte entra
  **REBAIXADA A PILOTO** com critério de remoção, como MP-001 e MP-003 fizeram.
- **Mirror:** `SKILL.md` (núcleo, tabela canônica de campos do `po`) — o campo já está **DEFINIDO**
  lá desde a MP-003. Aqui ele é **USADO**. Definição ≠ uso: é exatamente o que a PO-10 cobra.

## Por que esta dívida existe (não repita o diagnóstico)

A MP-003 aprovou as seções *Proof Obligations*, C3, C4, Pass 0 e S4. **O C1.5 não estava entre
elas**, e editá-lo fora do aprovado violaria a INV-4. Resultado: `grep -n 'uncertainty:'
skills/devflow-code/SKILL.md` **retorna vazio hoje** (verificado no disco, 2026-09-20). Não é
`[!] unavailable` — `[!]` é "não pôde rodar"; isto é "não foi implementado".

## Orçamento (DT-1)

- **(a) Que mecanismo estende?** O `1c` do C1.5 (condição de parada), que já criou o marcador
  `<!-- deferred: -->` para "ficou por ler". `uncertainty:` é o irmão semântico: `deferred` diz
  **o que não foi lido**, `uncertainty` diz **o que foi lido e mesmo assim não se sabe**. Sem o
  segundo, a única saída para a ignorância residual é preencher a Evidence Table com plausível.
- **(b) O que aposenta?** Nada removido. Absorve o hábito de marcar `✅` numa linha "quase
  verificada" — que é o carimbo de borracha que o C1.5 inteiro existe para impedir.
- **(c) Podia ser script?** Não. Nenhum script sabe que o agente não sabe. Um gate pode, no máximo,
  rejeitar `PASS` com linha `UNVERIFIED` — e isso o C1.5 **já** faz.

## Texto proposto — `devflow-code/SKILL.md`, C1.5, novo item `1d`

```
1d. REGISTRE A IGNORÂNCIA EM VEZ DE PREENCHÊ-LA. O `1c` diz quando PARAR; este diz o que fazer com
   o que sobrou sabendo. Toda linha da Evidence Table que não fechou `✅`, e toda promessa do `1b`
   cuja obtenibilidade você não conseguiu decidir, vai para `uncertainty:` — no bloco `po` da AC
   correspondente quando existe, ou numa lista `## Uncertainty` no fim do `analysis.md` quando não.
   Uma linha por item: **o que você não sabe · o que faria para saber · o que assumiu enquanto isso**.
   REGRA DURA: é PROIBIDO transformar ignorância em conteúdo plausível. Um `uncertainty:` populado
   NUNCA bloqueia o PASS; uma linha `❌`/`UNVERIFIED` na Evidence Table continua bloqueando (item 1).
   Os dois não se confundem: `UNVERIFIED` é uma afirmação da spec que você não conferiu — dívida de
   verificação; `uncertainty` é algo que você conferiu e segue sem resposta — dívida de conhecimento.
   `uncertainty:` vazio significa "nada a declarar", **nunca** "verifiquei tudo".
   ⚠️ Isto NÃO é um canal novo de pergunta ao operador: o limite de 3 marcadores
   `[NEEDS CLARIFICATION]` do S4 permanece intacto e continua sendo o único caminho para ambiguidade
   que muda escopo, UX, segurança, arquitetura ou modelo de dados. `uncertainty:` é registro, não
   pergunta — se o item PRECISA de decisão do operador, ele é um marcador do S4, não uma linha aqui.
   [PILOTO 2026-09 · origin: proactive · remoção: ver DEVFLOW-META.md, MP-004]
```

## Texto proposto — `devflow-code/SKILL.md`, C4, no bloco de fechamento de PO

Acrescentar imediatamente após a regra de `evidence_class:` (aplicada na MP-003):

```
  Fechou com `execution` mas sobrou algo que você não sabe — um caminho que a prova não cobriu, um
  ambiente que não pôde exercitar? Declare em `uncertainty:` no MESMO bloco, ao fechar. Prova forte
  com ponto cego declarado é honesta; prova forte com ponto cego calado é como o `[x]` sem evidência
  se parece por dentro. `uncertainty:` NÃO rebaixa a `evidence_class` nem reabre a PO.
  [PILOTO 2026-09 · origin: proactive · INV-5: sem incidente real ⇒ piloto]
```

## Assinatura de atrito prevista (DT-2)

`kind: no-slot` (o agente tinha uma dúvida residual e a escreveu num comentário solto, fora de
qualquer campo) em **12 sessões T1+** — mesmo relógio que a MP-003 deu ao campo no núcleo.

## Cláusula de falsificação / sunset

- **Herda o sunset do campo na MP-003**: 12 sessões com `uncertainty:` sempre vazio ⇒ REMOVER o
  campo inteiro (núcleo + C1.5 + C4 juntos). Não faz sentido remover a definição e manter o uso.
- **Específico deste draft:** se em 12 sessões o `uncertainty:` só aparecer no C4 e nunca no C1.5,
  o item `1d` não pegou — cortar `1d` e manter só a linha do C4.
- **Inverso vale como promoção:** se aparecer no C1.5 e evitar ao menos um `✅` fabricado numa
  Evidence Table, isto vira observação REAL e o piloto promove pela barra reativa do META.
- Relógio conta a partir do primeiro projeto consumidor com ledger ativo (A-1).
