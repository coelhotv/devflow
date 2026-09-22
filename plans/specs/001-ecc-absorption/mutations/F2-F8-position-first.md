# Draft F2/T062 — F8: cada papel registra a própria posição ANTES de ler as demais

- **Alvo:** `skills/devflow-ceremony/SKILL.md`, seção **Ceremony Output Persistence** (passo comum
  a RC1–RC4 e RC-SEC) + **RC-AUTO** (uma frase) + 1 linha na Quick Reference.
- **origin:** `proactive` · **Fecha:** PO-18 (instrumento; o `proof:` é MANUAL — A-2)
- **INV-5:** não se aplica (cerimônia ≠ C1/C4/Bootstrap). Entra como **piloto** mesmo assim (DT-3).
- **Mirror:** `ECC skills/council/SKILL.md:76-83` — *"Before reading other voices, write down: your
  initial position, the three strongest reasons for it, the main risk in your preferred path. Do
  this first so the synthesis does not simply mirror the external voices."*

## O defeito que isto ataca

O RC-AUTO roda RC1→RC2→RC3→RC-SEC→RC4 **em sequência, cada fase construindo sobre a anterior**
(`devflow-ceremony/SKILL.md:303`). Isso é deliberado e fica. O efeito colateral: quando o RC3 começa,
os achados do RC1 já estão no contexto, e a posição de engenharia tende a ser uma **paráfrase da
posição de produto**. Cinco papéis que concordam sempre é um papel só com cinco cabeçalhos.

## ⚠️ Limite honesto — o que o F8 NÃO consegue sozinho

Numa sessão única, "não ler as demais" é impossível: o RC1 já está no contexto quando o RC3 roda.
O F8 **não compra independência**, compra **rastro de ancoragem**: a posição escrita antes de REABRIR
os achados anteriores deixa visível, no próprio artefato, se a síntese só repetiu o que já estava lá.
A independência de verdade é de outro processo, e é por isso que este draft viaja junto do
`second-opinion.sh` (T060): a voz externa entra **depois** que as posições foram registradas.

## Orçamento (DT-1)

- **(a) Que mecanismo estende?** O passo comum *Ceremony Output Persistence*, que já é onde todo
  RC grava o que achou. Nada de seção nova por cerimônia.
- **(b) O que aposenta?** Nada removido. Absorve a síntese que concorda com tudo (achado sem dono).
- **(c) Podia ser script?** A metade independente, sim — e já é: `second-opinion.sh`. A metade
  "escreva antes de ler" não: nenhum script sabe o que o agente leu.

## Texto proposto — `Ceremony Output Persistence`, novo passo 0 (antes do passo 1)

```
0. **Posição antes da leitura (F8).** Ao abrir um RC, e ANTES de reabrir os achados de
   cerimônias anteriores ou qualquer segunda opinião, grave no output deste RC:
     ### Posição inicial — <RC> · <ISO timestamp>
     - Posição: <uma frase>
     - Três razões mais fortes: <1> · <2> · <3>
     - Maior risco do caminho que eu prefiro: <uma frase>
   Só DEPOIS leia o resto e sintetize. Na síntese, onde a sua conclusão final divergir da posição
   inicial, diga O QUE mudou sua cabeça (achado de qual RC, ou qual trecho). Concordância total com
   o RC anterior é permitida — mas precisa ser declarada, não herdada em silêncio.
   ⚠️ Em sessão única isto NÃO é independência (o RC anterior já está no contexto): é rastro de
   ancoragem. Voz independente de verdade é o passo 0b.
0b. **Voz externa (opcional, Tier 2).** Com as posições registradas, o operador pode pedir:
     ~/SKILLS/devflow/scripts/second-opinion.sh --artifact <spec|plan> --spec-dir <dir>
   Processo frio, sem esta conversa. Os findings são INSUMO: cada um vira decisão registrada
   (acolhido com a mudança, ou recusado com o motivo) — nunca veredito automático. Saída
   "unavailable" (fail-open) é anotada e a cerimônia segue.
   [PILOTO 2026-09 · origin: proactive · remoção: ver DEVFLOW-META.md, MP-005]
```

## Texto proposto — RC-AUTO, após "Sequential execution"

```
Cada fase abre com a Posição inicial (passo 0 do *Ceremony Output Persistence*) ANTES de reler as
fases anteriores. Sequência não é consenso: o RC3 constrói sobre o RC1, mas declara onde discorda.
```

## Texto proposto — Quick Reference (Do / Do Not)

```
| Gravar a posição inicial do RC antes de reler achados anteriores | Sintetizar herdando a conclusão do RC anterior sem declarar |
```

## Assinatura de atrito prevista (DT-2)

Se isto importa, aparecerá **`unsatisfiable`** no `process-friction.jsonl` quando o agente não
conseguir escrever uma posição "antes de ler" porque o RC anterior já está no contexto — é o limite
honesto acima, e é o sinal de que o passo virou ritual. Critério de **remoção**: 5 cerimônias
RC-AUTO com a posição inicial de cada fase **idêntica em substância** à conclusão da fase anterior
⇒ o passo 0 não produz sinal; REMOVER o 0 e manter só o 0b (a voz externa).
**Promoção:** divergência declarada (passo 0 ≠ síntese, com motivo) em ≥3 cerimônias de ≥2 specs.
⏱️ Relógio só corre em projeto consumidor com ledger ativo (A-1).
