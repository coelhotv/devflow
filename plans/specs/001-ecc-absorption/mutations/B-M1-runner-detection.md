# Draft M1 — Runner & Gate Detection (C1)

- **Alvo:** `skills/devflow-code/SKILL.md`, seção **C1 — Pre-Code Checklist**, novo item de checkbox
  logo abaixo de `Test framework confirmed per workspace`.
- **origin:** `proactive` (DT-2 — oportunidade minerada do ECC, sem dor observada)
- **Admissão (DT-1):** (a) estende mecanismo existente — o checklist do C1, nenhum mecanismo novo;
  (b) aposenta a linha solta `Test framework confirmed per workspace`, absorvida como caso particular;
  (c) não pode ser script: a resolução precisa virar registro que o S4/C4 citam, e o C1 é onde o
  agente lê o projeto. Piloto (DT-3).
- **Custo de contexto:** +11 linhas, −4 (a linha aposentada). Líquido +7 em `devflow-code` (934 linhas).
- **INV-5:** mexe no C1 e **não há incidente real** registrado. Entra **rebaixado a piloto** com o
  critério de remoção abaixo. Não promove a regra consolidada sem observação real.

## Texto proposto

```
  [ ] RUNNERS RESOLVIDOS E REGISTRADOS — antes de qualquer gate ou `po.proof:`.
      Resolva test / lint / typecheck / build nesta ordem de precedência, parando na primeira que responde:
        1. state.json (.knowledge) — comandos já resolvidos em sessão anterior
        2. manifesto do projeto — package.json:scripts | Cargo.toml | pyproject.toml | Makefile | go.mod
        3. PERGUNTE ao operador. Não chute.
      REGISTRE os 4 comandos resolvidos no transcript, citando a fonte de cada um
      (ex.: `test: bun test — package.json:scripts.test`). Comando não resolvido = `NONE (ausente)`,
      e quem depende dele fecha `[!] unavailable`, nunca `[x]`.
      PROIBIDO escrever em `po.proof:` (aqui, no S4 ou no C4) comando que não veio desta resolução.
      Absorve a checagem de framework de teste por workspace: em monorepo, resolva POR WORKSPACE-ALVO
      — nunca assuma que o runner da raiz vale (Jest vs Vitest; nunca misture vi.fn()/jest.fn()).
      [PILOTO 2026-09 · origin: proactive · remoção: ver cláusula de falsificação]
```

## Linha na Quick Reference (modo Coding)

```
| ✅ Resolver test/lint/typecheck/build do projeto no C1 e citar a fonte | ❌ Escrever `proof:` com comando chutado (`npm test` em projeto Bun/Cargo) |
```

## Assinatura de atrito prevista (DT-2 / DT-3)

Se isto importa, aparecerá `kind: wrong_gate_command` (ou `test_expectation_wrong` com `workaround`
citando runner) em `process-friction.jsonl` em **10 sessões de C-mode**.

## Cláusula de falsificação / sunset

- **Remover** se em 10 sessões a resolução **nunca divergir** do chute — nesse caso o bloco colapsa
  numa linha só (`registre o comando de test/lint e sua fonte`).
- **Remover** se em 10 sessões nenhuma PO tiver sido bloqueada por comando não-resolvido.
- **Promover** a regra consolidada somente com ≥3 observações de ≥2 specs distintas (barra reativa do META).
