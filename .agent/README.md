# `.agent/` do repositório `devflow` — INIT PARCIAL, e deliberadamente incompleto

> **Leia isto antes de concluir qualquer coisa a partir da existência deste diretório.**
> Ele NÃO significa que o DEVFLOW foi inicializado aqui. Significa o contrário: foi inicializado
> **pela metade, de propósito**, e o que falta é a parte importante.

Decisão do operador, 2026-09-21, durante a spec 001 (`plans/specs/001-ecc-absorption/`).

## O que existe aqui, e por quê

| Arquivo | Por que pertence a este repo |
|---|---|
| `memory/process-friction.jsonl` | Registra atrito com **o DEVFLOW enquanto se desenvolve o DEVFLOW**. Esse atrito é real, é sobre ESTE repo, e já estava acumulando à mão numa tabela do `spec.md` por não ter onde cair |
| `memory/attempts.jsonl` | Intervenções tentadas, medidas e revertidas ao trabalhar neste repo |

## O que NÃO existe aqui, e por que a ausência é a decisão

| Ausente | Motivo |
|---|---|
| `state.json` | O próprio `scripts/setup.sh:277` o gitignora — é estado efêmero de instância, não memória de projeto |
| `ANTI_PATTERNS_INDEX.md`, `RULES_INDEX.md`, `CONTRACTS_INDEX.md`, `DECISIONS_INDEX.md` | Catalogam padrões de um **codebase de runtime**. Este repo é texto de skill + 8 scripts shell. Um catálogo aqui teria amostra pequena demais para significar algo |
| Qualquer coisa que faça um **relógio de sunset** correr | ⬇️ leia a seção seguinte. É o ponto mais importante deste arquivo |

## ⚠️ Os relógios de falsificação NÃO correm aqui — A-1 continua de pé

As mutações dos slices B–E (v2.4 → v2.7, todas PILOTO) carregam cláusulas do tipo
*"N sessões sem uso ⇒ REMOVER"*. Todas dizem que **o relógio só começa num projeto consumidor com
ledger ativo**.

A existência deste diretório **não inicia esses relógios**, e a tentação de achar que inicia é
exatamente o erro que este README existe para impedir. Motivo concreto, não cerimonial:

> Este repo **não tem schemas, services, componentes nem runner de verdade** — o `typecheck` e o
> `build` resolvidos no C1 são literalmente `NONE (ausente)`. Instruções como o P2.5 (Pattern
> Grounding) ou o `Target`/`Mirror`/`Validate` mediriam silêncio aqui por falta de objeto, não por
> falta de valor. E as cláusulas dizem que silêncio ⇒ REMOVER. Contar este ledger como amostra
> **mataria mutações boas com evidência enviesada.**

A-2 também continua de pé: as POs `MANUAL` (PO-3..PO-6, PO-8, PO-9, PO-11..PO-13) exigem trabalho
sobre código real. **Este diretório não as desbloqueia** — não é isso que ele faz.

## O leitor tem nome

Um ledger que ninguém lê é AP-325 (passo que existe para parecer diligente). Este tem leitor
declarado: o **slice H** da spec 001, cujo trabalho é aplicar o veredito de cada piloto —
promover o que apareceu, REMOVER o que não apareceu. Se o slice H morrer, este diretório deve ser
reavaliado, não herdado.

## Isto não substitui conserto nenhum

Em particular, o **AC-1** (`ai-review.sh` morria em repo sem `ANTI_PATTERNS_INDEX.md`) foi
consertado **no script**, em commit próprio, ANTES deste diretório nascer — e não por criação do
arquivo que faltava. Criar o índice teria feito o sintoma sumir aqui e mantido o bug para todo
repo de cliente sem `.agent/`. Guarda durável: `tests/ai-review-no-agent.test.sh`.
