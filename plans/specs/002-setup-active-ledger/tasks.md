# 002 — Tasks

> Tier 1 · branch `spec/002-setup-active-ledger` · Q1 resolvida: marco de início **derivado do git**.
> Runners (herdados da 001, sem manifesto): `test:` suítes de `tests/` · `lint:` `shellcheck` +
> `bash -n` · `typecheck:` NONE · `build:` NONE.

- [x] T001 [PO-1][PO-2][PO-3] Escrever `tests/setup.test.sh` ANTES do conserto; colar a falha em `red:`
  * **Target**: `tests/setup.test.sh` (`[NEW]`)
  * **Mirror**: `tests/second-opinion.test.sh` (estrutura ok/bad, contagem)
  * **Validate**: `bash tests/setup.test.sh` (deve falhar em PO-1..3 antes do T002)
  * **red:** baseline contra o setup.sh v1.7: "8 passaram, 11 falharam" — PO-1 (rerun altera arquivo),
    PO-2 (ledgers ausentes), PO-3 (.gitignore nunca criado/completado), FR-005/006 (v1.7, sem hook).
- [x] T002 [PO-1] Idempotência: todo `cat >` em `.agent/` passa a pular arquivo existente e reportar
  * **Target**: `scripts/setup.sh:66,113,152,191,230` (guardas `[ -f ... ]`)
  * **Validate**: `bash -n scripts/setup.sh && shellcheck scripts/setup.sh && bash tests/setup.test.sh` — limpo
- [x] T003 [PO-2] Ledgers vazios + aviso final "relógio começa no commit que adicionar o ledger" (Q1 = git)
  * **Target**: `scripts/setup.sh:305-315` (ledgers), `394-397` (aviso)
- [x] T004 [PO-3] `.gitignore`: criar se falta; completar linha a linha, sem duplicar
  * **Target**: `scripts/setup.sh:319-340`
- [x] T005 [FR-005] Versão v3.0 no banner e no `schema_version`; `session.handoff: null` no template
  * **Target**: `scripts/setup.sh:2,28,70,85`
- [x] T006 [FR-006] Flag `--with-git-hook` (nível 2 do `mode-gate`)
  * **Target**: `scripts/setup.sh:18-23,342-372`
- [x] T007 [SC-002] Rerun sobre uma CÓPIA do `.agent/` do dosiq, em diretório descartável
  * 940 arquivos reais (`cp -RL ~/git/dosiq/.agent`), checksum idêntico antes/depois do rerun.
- [x] T008 [C4] Fechar PO-1..3 · regressão v3 · [C5] atrito + índice de specs
  * PO-1..3: `[x] done`, `evidence_class: execution` (ver spec.md). Regressão: 6 suítes, 0 falha.
