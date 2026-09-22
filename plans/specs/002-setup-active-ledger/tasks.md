# 002 — Tasks

> Tier 1 · branch `spec/002-setup-active-ledger` · Q1 resolvida: marco de início **derivado do git**.
> Runners (herdados da 001, sem manifesto): `test:` suítes de `tests/` · `lint:` `shellcheck` +
> `bash -n` · `typecheck:` NONE · `build:` NONE.

- [ ] T001 [PO-1][PO-2][PO-3] Escrever `tests/setup.test.sh` ANTES do conserto; colar a falha em `red:`
  * **Target**: `tests/setup.test.sh` (`[NEW]`)
  * **Mirror**: `tests/second-opinion.test.sh` (estrutura ok/bad, contagem)
  * **Validate**: `bash tests/setup.test.sh` (deve falhar em PO-1..3 antes do T002)
- [ ] T002 [PO-1] Idempotência: todo `cat >` em `.agent/` passa a pular arquivo existente e reportar
  * **Target**: `scripts/setup.sh:54,96,131,166,201,236`
  * **Validate**: `bash -n scripts/setup.sh && shellcheck scripts/setup.sh && bash tests/setup.test.sh`
- [ ] T003 [PO-2] Ledgers vazios + aviso final "relógio começa no commit que adicionar o ledger" (Q1 = git)
  * **Target**: `scripts/setup.sh` (`[MODIFY]`)
- [ ] T004 [PO-3] `.gitignore`: criar se falta; completar linha a linha, sem duplicar
  * **Target**: `scripts/setup.sh:271-282`
- [ ] T005 [FR-005] Versão v3.0 no banner e no `schema_version`; `session.handoff: null` no template
  * **Target**: `scripts/setup.sh:2,19,54-91`
- [ ] T006 [FR-006] Flag `--with-git-hook` (nível 2 do `mode-gate`)
  * **Target**: `scripts/setup.sh` (`[MODIFY]`)
- [ ] T007 [SC-002] Rerun sobre uma CÓPIA do `.agent/` do dosiq, em diretório descartável
- [ ] T008 [C4] Fechar PO-1..3 · regressão v3 · [C5] atrito + índice de specs
