# Draft F5 — Condição de parada de busca (C1.5)

- **Alvo:** `skills/devflow-code/SKILL.md`, **C1.5**, dentro do bloco REALITY CHECK, novo item `1c`
  (depois de `1b. OBTAINABILITY`).
- **Mirror:** ECC `agents/spec-miner.md:57-68`; suficiência em `skills/iterative-retrieval/SKILL.md:129-133,205`.
- **origin:** `proactive`
- **Admissão (DT-1):** (a) estende a Evidence Table do C1.5 — nenhum mecanismo novo; (b) não aposenta
  nada (o C1.5 hoje **não tem** condição de parada: é a lacuna); (c) não pode ser script — a decisão
  "li o suficiente" é semântica. Piloto (DT-3).
- **Custo de contexto:** +10 linhas. **INV-5 não se aplica** (C1.5 não é C1/C4/Bootstrap).

## Texto proposto

```
1c. CONDIÇÃO DE PARADA — a Evidence Table diz o que verificar, não quando parar. Sem isto o agente
   lê de menos (e o PASS vira carimbo) ou espirala. PARE de buscar quando UMA destas disparar, e
   DECLARE qual foi, no analysis.md:
     (i) BOUNDARY — a cadeia de chamadas alcançou uma fronteira externa (SDK, rede, DB, binário).
    (ii) SATURAÇÃO — 3 arquivos expandidos consecutivos sem nenhuma asserção comportamental nova.
   (iii) TETO — 15 arquivos lidos para esta capacidade (3 arquivos de alta relevância batem 10 medíocres).
   Sobrou arquivo por ler? REGISTRE no fim do analysis.md:
     <!-- deferred: path/a.ts, path/b.sql — motivo: teto atingido; retomar por aqui -->
   O marcador `deferred:` é ponto de retomada da próxima sessão — não é dívida silenciosa.
   Parada NÃO afrouxa o gate: o PASS continua exigindo Evidence Table populada (item 1). Parar com
   linha ❌/UNVERIFIED na tabela é BLOQUEIO, não parada.
   [PILOTO 2026-09 · origin: proactive]
```

## Linha na Quick Reference (modo Coding)

```
| ✅ Nomear o critério de parada do C1.5 e marcar `deferred:` o que ficou | ❌ Parar de ler sem dizer por quê, ou espiralar até o contexto estourar |
```

## Assinatura de atrito prevista

Se isto importa, aparecerá `kind: analysis_incomplete` ou `context_exhausted` em
`process-friction.jsonl` em **8 sessões Tier 2**.

## Cláusula de falsificação / sunset

- **Remover** se em 8 sessões Tier 2 nenhum `deferred:` for escrito **e** nenhum C1.5 citar (ii) ou (iii)
  — significa que a parada nunca foi o problema.
- **Remover** se algum `deferred:` virar desculpa: PASS declarado com ❌ na Evidence Table. Aí o item
  causou dano e sai imediatamente.
