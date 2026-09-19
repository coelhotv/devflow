# Draft F6 — Trio de aborto + ordenação por dependência (C3/C4)

- **Alvo:** `skills/devflow-code/SKILL.md` — **C3** (ordenação) e novo bloco **C4 · caminho de falha**,
  logo após `Run project-specific quality commands`.
- **Mirror:** ECC `commands/build-fix.md:26-28,40-46` (replicado em go/rust/kotlin/cpp/react/flutter);
  `agents/loop-operator.md:39-46`; `commands/santa-loop.md:126`.
- **origin:** `proactive`
- **Admissão (DT-1):** (a) estende C3/C4 — o caminho feliz existe, o **caminho de falha não existe**;
  (b) não aposenta nada; (c) parcialmente scriptável (contar erros antes/depois), mas a
  reclassificação de escopo é julgamento — fica prosa mínima. Piloto (DT-3).
- **Custo de contexto:** +13 linhas.
- **INV-5:** mexe no **C4**, sem incidente real ⇒ **rebaixado a piloto** com remoção abaixo.
- **Guard (PO-5):** o caminho feliz do C3/C4 **não ganha passo novo** — este bloco só é lido quando
  um gate já falhou.

## Texto proposto — C3 (ordenação)

```
  Falhou o gate? ORDENE os erros por dependência antes de corrigir: imports/resolução de módulo →
  tipos/schemas → lógica → estilo. Corrigir lógica antes do tipo gera retrabalho e mascara a causa.
```

## Texto proposto — C4 (caminho de falha; novo bloco)

```
LOOP DE CORREÇÃO — CONDIÇÕES DE ABORTO (só se aplica quando um gate falhou):
  PARE, não tente de novo, e ESCALE ao operador citando QUAL condição disparou:
    (a) DELTA LÍQUIDO — a correção introduziu mais erros do que resolveu (conte antes e depois; o
        sinal é o delta, não o número de tentativas).
    (b) REPETIÇÃO IDÊNTICA — o MESMO erro (mesma mensagem/stack) persiste após 3 tentativas.
        Critério observável; "escale se estiver travado" não é, porque o agente sempre acha que a
        próxima tentativa resolve.
    (c) RECLASSIFICAÇÃO DE ESCOPO — o conserto exige mudança arquitetural, não conserto de build.
        Isto deixou de ser C-mode: volta para Planning. Não é apelo à disciplina, é condição.
  Ao abortar: NÃO commite, NÃO push, NÃO marque PO como `[x]`. Registre o estado e pare a resposta
  (R-065: sem mais tool calls após o STOP).
  [PILOTO 2026-09 · origin: proactive]
```

## Linha na Quick Reference (modo Coding)

```
| ✅ Abortar citando delta líquido, erro idêntico 3x ou reclassificação de escopo | ❌ Tentar "mais uma vez" indefinidamente, ou commitar com gate vermelho |
```

## Assinatura de atrito prevista

Se isto importa, aparecerá `kind: fix_loop_thrash` ou `scope_creep` em `process-friction.jsonl`
em **10 sessões de C-mode**.

## Cláusula de falsificação / sunset

- **Remover** se em 10 sessões nenhum aborto for disparado por (a), (b) ou (c) — loop de correção
  não era o problema.
- **Remover (a)** isoladamente se o delta líquido nunca disparar sem que (b) já tivesse disparado:
  seria mecanismo redundante, exatamente o que DT-1 proíbe.
