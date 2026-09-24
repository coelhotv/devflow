# 003 — Tasks

> Tier 1 · branch `spec/003-rc6-engine-resilience` · contrato de `coverage`: **aditivo**.
> Runners (herdados da 001): `test:` suítes de `tests/` · `lint:` `shellcheck` + `bash -n` ·
> `typecheck:` NONE · `build:` NONE.

- [x] T000 [E1] Extrair o texto REAL do 503 (stderr e/ou envelope) do log do dosiq#835 → fixture
- [x] T001 [PO-1][PO-2][PO-3] `tests/rc6-resilience.test.sh` (`[NEW]`) ANTES do código; colar a falha em `red:`
  * **Mirror**: `tests/second-opinion.test.sh` (ok/bad) + fakes de `tests/ai-review-paths.sh`
  * agy falso com roteiro por chamada (`FAKE_AGY_SCRIPT="503,503,ok"`); backoff/jitter zerados por env
  * **Validate**: `bash tests/rc6-resilience.test.sh` (deve falhar em PO-1..3)
  * **red:** HEAD adbc351 → "6 passaram, 25 falharam"; 1ª FALHA = "partial=False (esperado True)" (o dosiq#835)
- [x] T002 [PO-1] Contagem de sucesso por passe → `per_pass`, `independent_reviewers`, `partial`, `not_reviewed`
  * **Target**: `scripts/ai-review.sh` (laços dos passes A/B, chamada do merge em `:1191`, bloco `coverage` em `:1243`)
- [x] T003 [PO-2] `@core` 1.1.0 → 1.2.0: wrapper resiliente sobre o `run_engine` bruto (E4) — classificação
  transient/timeout/quota/fatal sobre o erro da tentativa (E1/E2), retry+backoff, fallback de modelo
  opcional por chamada (E3), hang guard no agy, stderr por tentativa, orçamento único (E8)
  * **Target**: `scripts/lib/engine-core.sh` (`run_engine`, `engine_err_hint`); `ENGINE_CORE_EXPECTED` nos 2 consumidores
- [x] T004 [PO-2] Segunda rodada + circuit breaker + `RC6_RETRY_BUDGET`
  * **Target**: `scripts/ai-review.sh` (laço do pass A e fallback chunked do B)
- [x] T005 [PO-3] Status file JSONL, heartbeat no backoff, linha VERDICT
  * **Target**: `scripts/lib/engine-core.sh` (emissor) + `scripts/ai-review.sh` (VERDICT)
- [x] T006 [FR-012] `second-opinion.sh` sobre o `@core` 1.2.0; `tests/second-opinion.test.sh` verde (23/23)
  * `skill-comply.sh` (3º consumidor, A-3): só a versão esperada; segue no `run_engine` bruto
- [x] T007 [FR-013] Prosa da seção RC6 em `skills/devflow-code/SKILL.md` (ler VERDICT/coverage; partial ≠ rerun)
- [x] T007b [FR-014] A/B: baseline e par sem modelo alternativo; guard `ai-review-paths.sh` sem diff
- [x] T008 [C4] Fechar PO-1..3 · regressão (6 suítes) + `shellcheck` · [C5] atrito + índice de specs
