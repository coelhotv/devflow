# Draft G/T072 — C5 escreve um handoff lido na sessão seguinte (formato híbrido)

- **Alvo:** `skills/devflow-code/SKILL.md`, três pontos:
  1. **C5**: item novo `7b`, entre o journal (7) e o `state.json` (8). É o **escritor**.
  2. **C0**: um parágrafo que manda ler `session.handoff`. É o **leitor**.
  3. **Quick Reference**: uma linha.
  Mais o campo opcional `session.handoff` em `templates/schema-reference.md`.
- **origin:** `proactive` · **Fecha:** PO-21 (a metade de prosa; o proof é MANUAL — A-2)
- **Formato:** híbrido `state.json` + `attempts.jsonl`, escolhido pelo operador em 2026-09-22
  (PO-20, `handoff-study-G.md`).
- **Mirror:** ECC `commands/save-session.md:101-110`. De lá vêm duas coisas: o motivo exato
  ("threw X because Y", nunca "didn't work") e a demoção de tudo que não tem evidência para
  "Not Tried Yet".
- **INV-5:** C5 e C0 não são C1/C4/Bootstrap. **O Bootstrap NÃO é tocado de propósito.** O passo 1
  dele já lê o `state.json` inteiro, mas mandar *exibir* o handoff ali seria mudança no Bootstrap
  sem incidente real. O C0 faz esse papel sem violar a INV-5. Entra como **piloto**.
- **INV-6:** MP-001 a MP-005 estão todas aplicadas. Esta é a única proposta em voo.

## O defeito que isto ataca

Hoje o C5 escreve **para arquivos que a sessão seguinte não lê**:
- o journal (7) só é lido pelo distill (`devflow-distill:36`), e o distill ainda o comprime;
- o `attempts.jsonl` (1b) só é consultado na busca do próprio C5.

O que chega à sessão seguinte depende de o operador lembrar e colar. Neste repo, a seção
*"Próximo passo exato"* do `spec.md` é mantida à mão justamente por isso. O `state.json` é o único
arquivo lido automaticamente, e hoje ele não guarda nada disso (`schema-reference.md:15-42`).

## Orçamento (DT-1)

- **(a) Que mecanismo estende?** O item 8 do C5, que já escreve o `state.json`, e o item 1b, que
  já registra intervenções revertidas. O `7b` só junta um bloco ao que o item 8 já grava.
- **(b) O que aposenta?** Nada é removido. A seção "Próximo passo exato" da spec continua como
  **substituto** quando não há `state.json`, e deixa de ser a única via.
- **(c) Podia ser script?** A escrita não pode, porque decidir o que tem evidência é julgamento. A
  leitura no C0 é uma linha de prosa, e um script não economizaria nada.

## Texto proposto — C5, novo item `7b` (entre 7 e 8)

```
  [ ] 7b. HANDOFF — o que a PRÓXIMA sessão precisa saber, onde ela lê sem o operador pedir.
      O journal (7) é lido só pelo distill e o attempts.jsonl (1b) só pela busca do C5: nenhum dos
      dois chega à sessão seguinte. O state.json chega (Bootstrap, passo 1). Grave nele, no mesmo
      write do item 8, o bloco `session.handoff` — SOBRESCREVE o da sessão anterior:
        {"written_at":"<ISO>","spec":"<NNN ou null>",
         "next_step":"<a próxima ação concreta, uma linha>",
         "failed":[{"what":"<abordagem>","reason":"<motivo EXATO: mensagem, saída, file:line>",
                    "attempt":"<id/terms no attempts.jsonl, ou null>"}],
         "worked":[{"what":"...","evidence":"<comando+saída ou file:line DESTA sessão>"}],
         "not_tried":["<ideia ou item sem evidência>"]}
      REGRAS DURAS:
        - `reason` é o erro ou a saída literal. "não funcionou", "deu problema", "falhou" sem o
          porquê é PROIBIDO: sem o motivo exato a próxima sessão tenta de novo.
        - DEMOÇÃO: um item vai em `worked` só com evidência colada NESTA sessão. Sem evidência, ele
          vai para `not_tried`, mesmo que você "tenha certeza". Isto vale para o que foi herdado
          do handoff anterior: evidência de outra sessão não conta como evidência desta.
        - Falha que foi uma intervenção REVERTIDA: primeiro registre no attempts.jsonl (1b) e
          aponte para ela em `attempt`. O histórico durável fica no ledger; o handoff pode ser
          sobrescrito sem perder nada. Journal e attempts.jsonl continuam APPEND-ONLY.
        - Nada falhou? `failed: []`. Lista vazia é um resultado válido. Não invente falha.
      SEM state.json (repo com .agent/ parcial, como o próprio devflow): escreva o mesmo conteúdo
      na seção "Próximo passo exato" da spec. Sem spec, escreva no fim da resposta final.
      [PILOTO 2026-09 · origin: proactive · remoção: ver DEVFLOW-META.md, MP-006]
```

## Texto proposto — C0, parágrafo após o checklist

```
Existe `session.handoff` no state.json que você acabou de ler? MOSTRE-O antes do C1: next_step,
cada `failed` com seu `reason`, e `not_tried`. Um item de `failed` que o plano desta sessão repete
EXIGE nova evidência de que a causa mudou; sem ela, não repita. Um item de `not_tried` nunca é
tratado como feito. Handoff de outra spec (campo `spec` diferente do goal): mostre e ignore.
[PILOTO 2026-09 · origin: proactive · MP-006]
```

## Texto proposto — Quick Reference (Do / Do Not)

```
| Gravar `session.handoff` no C5/7b com o motivo exato de cada falha e o não-evidenciado em `not_tried` | Escrever "não funcionou" sem o porquê, ou pôr em `worked` o que não tem evidência desta sessão |
```

## Texto proposto — `templates/schema-reference.md`, depois dos campos opcionais v1.8

```
Optional v2.9 field — written by C5/7b, read by C0 (PILOT, MP-006):

{"session": {"handoff": {"written_at": "...", "spec": "NNN", "next_step": "...",
  "failed": [{"what": "...", "reason": "...", "attempt": null}],
  "worked": [{"what": "...", "evidence": "..."}], "not_tried": ["..."]}}}

Overwritten every session by design. Durable failure history lives in memory/attempts.jsonl.
```

## Assinatura de atrito prevista (DT-2)

Se isto importa, deve aparecer **`stale`** no `process-friction.jsonl`: o C0 mostra um handoff
cujo `next_step` já foi feito, ou um `failed` cuja causa já não existe. Isso significa que o leitor
funciona e que o conteúdo envelheceu.

- **Remoção:** 10 sessões com o handoff escrito e o C0 nunca citando nenhum item dele no transcript
  ⇒ o leitor não lê, o passo está morto (AP-325). REMOVER o `7b` e o parágrafo do C0.
- **Remoção alternativa:** `reason` vago em mais da metade dos `failed` de 5 sessões ⇒ a regra
  dura não pega. Cortar para só `next_step` + `not_tried`.
- **Promoção:** 3 ou mais casos, em 2 ou mais specs, em que o C0 mostrou um `failed` e isso evitou
  uma nova tentativa (citado no transcript).
- ⏱️ O relógio só corre em projeto consumidor com ledger ativo (A-1).

## Guard da PO-21 ("journal e attempts.jsonl continuam append-only")

Verificável por grep depois de aplicado: o `7b` diz literalmente `Journal e attempts.jsonl
continuam APPEND-ONLY`, e o único arquivo que ele sobrescreve é o `state.json`.
