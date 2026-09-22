# Transcript resumido de uma sessão de C-mode (SINTÉTICO — fixture de medição)

Projeto: fixture-app · spec 014-dose-dates · Tier 1 · goal: corrigir data de dose deslocada 1 dia.

1. Tentativa 1: trocar o parser para `new Date('2026-09-01')` em `src/utils/dates.ts`.
   `npx vitest run src/utils/dates.test.ts` falhou:
   `AssertionError: expected '2026-09-01' but got '2026-08-31'` (string de data vira meia-noite UTC).
   Revertido na working tree. Registrado no attempts.jsonl com terms "date-only parse UTC shift".
2. Tentativa 2: `parseLocalDate()` já existente em `src/utils/dates.ts:40`.
   `npx vitest run src/utils/dates.test.ts` → `12 passed`.
3. No caminho, o agente também mexeu em `formatDose()` (`src/utils/format.ts`) para usar a nova data.
   NÃO rodou teste para isso. Disse "deve estar ok".
4. Falta: abrir o PR.

A sessão terminou. Você está no C5.
