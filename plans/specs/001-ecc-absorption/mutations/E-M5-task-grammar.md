# Draft E/M5 — Gramática de task: `Target` / `Mirror` / `Validate` no P3

- **Alvo:** `skills/devflow-plan/SKILL.md`, **P3**, bloco `Each task MUST` (:116).
- **origin:** `proactive` · **Fecha:** PO-12 (junto com M4)
- **INV-5:** não toca C1/C4/Bootstrap ⇒ não se aplica.
- **Mirror:** `plans/specs/001-ecc-absorption/tasks.md` — as tasks desta spec JÁ usam
  `* **Target**` / `* **Mirror**` / `* **Validate**` (T001..T005, T051..T053). O formato nasceu à
  mão, sem o P3 a exigir; é a evidência de que cabe e de que o agente o inventa quando falta.
  Isto é uma linha `kind: reinvented` esperando lugar — e é o argumento mais forte deste draft.

## Orçamento (DT-1)

- **(a) Que mecanismo estende?** O bloco `Each task MUST`, que já lista campos obrigatórios
  (`TNNN`, `[P]`, `[USn]`, `[C4]`, `[C5]`, `[PO-N]`). Três campos a mais na MESMA lista.
- **(b) O que aposenta?** `Validate:` **absorve** a checagem por arquivo que o C3 (M6, já aplicado no
  slice D) manda rodar mas não sabia onde ler: hoje o C3 diz "rode o `Validate:` da task" e o P3 não
  obriga ninguém a escrevê-lo. **O M5 fecha uma dependência pendente do que já está no disco** —
  não é adição especulativa.
- **(c) Podia ser script?** A presença dos 3 campos, sim (gate barato, candidato ao `mode-gate.sh`).
  O conteúdo, não. Prosa agora, gate depois.

## Texto proposto — `devflow-plan/SKILL.md`, acrescentar ao bloco `Each task MUST`

```
  - Declarar os três campos de ancoragem, um por linha, logo abaixo do título da task:
      * **Target**: `path/do/arquivo` (`[NEW]` | `[MODIFY]` | `[DELETE]`) — o arquivo que DEFINE o
        símbolo, nunca um chamador (mesma regra do C1). Vários alvos ⇒ várias linhas Target.
      * **Mirror**: `file:line` do exemplar a imitar, ou `NENHUM` — o que ancora a task no padrão
        real do repo (é como o Tier 1 herda o P2.5 sem preencher a tabela).
      * **Validate**: UM comando isolado, executável, que prova ESTA task — resolvido no C1
        (runners), nunca chutado. É o comando que o C3 roda após cada arquivo.
    `Validate` é por-task; `guard:` continua sendo do bloco `po` e fecha no C4. Não confunda:
    `Validate` responde "este arquivo ficou de pé?", `guard:` responde "nada regrediu?".
    ⚠️ Se o `Validate` de toda task for IGUAL ao gate global do C4, a granularidade não existe —
    isso é o sinal de falsificação deste campo, não um detalhe de estilo.
    Task de C5 (registro/memória) pode declarar `Validate: NONE (ausente)` — é honesto e visível.
    [PILOTO 2026-09 · origin: proactive · remoção: ver DEVFLOW-META.md, MP-004]
```

## Assinatura de atrito prevista (DT-2)

`kind: reinvented` (o agente escreve Target/Validate por conta própria, como fez nesta spec) ou
`kind: unsatisfiable` (o C3 mandou rodar um `Validate:` que a task não tinha), em **10 slices T1+**.

## Cláusula de falsificação / sunset

- **`Validate` idêntico ao gate global do C4 em 10 slices seguidos** ⇒ CORTAR o campo: ele não
  compra granularidade nenhuma e o C3 pode citar o gate do C4 diretamente.
- **`Mirror: NENHUM` em >80% das tasks ao longo de 10 slices** ⇒ CORTAR `Mirror`: ou o repo não tem
  padrões, ou ninguém procura — e nos dois casos o campo é ruído.
- **`Target`** — sem sunset independente: é o caminho canônico que o C1 já exige verificar; remover
  exigiria provar que o C1 verifica caminho sem a task dizer qual é.
- Relógio conta a partir do primeiro projeto consumidor com ledger ativo (A-1).
