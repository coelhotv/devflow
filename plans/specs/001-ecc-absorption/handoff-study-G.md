# Slice G — estudo de formatos de handoff (T070 · PO-20)

> Data: 2026-09-22 · Tier 1 · **Nenhuma edição no C5 antes da escolha do operador** (guard do PO-20).
> Referência externa: ECC `commands/save-session.md:101-110` (seções "What Did NOT Work (and why)"
> e demoção do não-evidenciado para "Not Tried Yet").

## O problema

O handoff tem dois conteúdos que precisam chegar à sessão seguinte:
1. **o motivo exato** de cada coisa que falhou, para que ninguém tente de novo;
2. **o que não tem evidência**, rebaixado a "não tentado", para que ninguém o trate como feito.

Um formato só serve se a sessão seguinte o **lê sem o operador pedir**. Um arquivo que ninguém lê
não é handoff, é arquivo morto.

## Comparação

| Formato | 1. Lido na sessão seguinte sem o operador pedir? | 2. Sobrevive a compact? | 3. Quem mantém? |
|---|---|---|---|
| **journal** (`memory/journal/YYYY-WWW.jsonl`) | ❌ Não. O bootstrap (`SKILL.md:204-226`) não lê o journal. Só o distill lê (`skills/devflow-distill/SKILL.md:36`) | O arquivo fica no disco, mas nada o relê depois do compact | O agente escreve no C5/7. O distill **comprime e arquiva** (`devflow-distill:46`), então o motivo exato se perde na compressão |
| **arquivo por sessão** (estilo ECC, `~/.claude/session-data/`) | ❌ Não. Só é lido com `/resume-session` explícito (`ECC resume-session.md:2,20`). O DEVFLOW não tem leitor para ele. `.agent/sessions/` já existe (`setup.sh:275`), mas guarda `.lock` e `events.jsonl`, não handoff | Fica no disco, mas nada o relê | O agente, ao encerrar. Ninguém apaga os antigos, e eles acumulam |
| **`state.json`** | ✅ Sim. É o passo 1 do bootstrap (`SKILL.md:205`), e toda sub-skill o lê ao entrar (`SKILL.md:263-265`) | ✅ Sim. Ele é relido justamente para atravessar um compact (`SKILL.md:264-265`: "mesmo se este núcleo se perder num compact") | O agente, a cada transição. ⚠️ É **sobrescrito**, não append: a falha de duas sessões atrás some. ⚠️ É **gitignorado** (`setup.sh:277`): não viaja entre máquinas. ⚠️ **Não existe neste repo** (decisão do `.agent/README.md`) |
| **`attempts.jsonl` estendido** | ❌ Não no bootstrap. Só é consultado na busca do C5/1b e no `--check` (dosiq) | Fica no disco, mas não é relido | O agente no C5/1b. É append-only, versionado e tem gate (`--check` cruza reverts). ⚠️ O conteúdo é outro: hoje o ledger guarda "tentado, medido, revertido". Colocar ali "funcionou" e "não tentado" dilui o vocabulário que o `--check` conta |

## Leitura

- **Só o `state.json` passa no critério 1.** É o critério que decide: os outros três formatos são
  duráveis, mas ninguém os lê.
- **O `state.json` falha no que os outros têm de bom.** Ele é sobrescrito, efêmero e local. Não
  guarda histórico de falhas.
- **O `attempts.jsonl` já é o lugar certo para o motivo exato de uma intervenção revertida.** Ele é
  append-only, versionado e tem gate. Isso já vale hoje pelo C5/1b.
- **Observação lateral (5º formato, de fato):** neste repo o handoff real é a seção
  *"Próximo passo exato"* do `spec.md` (`spec.md:181`), mantida à mão. Ela é lida porque a spec é
  lida no C1. Funciona, mas só para trabalho que tem spec.

## Recomendação (a decisão é do operador)

**Híbrido `state.json` + `attempts.jsonl`:**
- O `state.json` ganha um bloco curto `handoff` (próximo passo · o que falhou, com motivo exato ·
  o que não tem evidência → "não tentado"). É o **portador**, porque é o único formato lido
  automaticamente.
- Toda falha que envolveu uma intervenção revertida continua indo para o `attempts.jsonl` (C5/1b).
  O `handoff` só **aponta** para ela. O histórico fica durável no ledger, e o `state.json` pode
  continuar sendo sobrescrito.
- O guard do PO-21 fica intacto: journal e attempts continuam append-only.

Risco declarado: em repo sem `state.json` (como este) o handoff não tem portador. Nesse caso cai
para a seção "Próximo passo exato" da spec.

## Uncertainty
- Não sei se o compact do harness preserva o conteúdo do `state.json` lido *antes* do compact.
  Assumi que não, e que o que garante a sobrevivência é a **releitura** ao entrar numa sub-skill.
  Para saber: observar uma sessão real que passe por um compact.

## Escolha do operador (T071)

**2026-09-22 — Híbrido `state.json` + `attempts.jsonl`**, escolhido pelo operador entre as quatro
opções apresentadas (AskUserQuestion, sessão do slice G). O T072 redige o C5 neste formato.
