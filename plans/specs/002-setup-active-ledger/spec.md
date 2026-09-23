# 002 — `setup.sh` instala um projeto consumidor que o DEVFLOW v3 consegue medir

**Feature Directory:** `plans/specs/002-setup-active-ledger/`
**Created:** 2026-09-22
**Status:** delivered — PO-1..3 fechadas com evidência de execução; regressão (6 suítes) verde
**Tier:** 1
**Input:** diagnóstico pós-merge da spec 001 (v3.0.0). O `setup.sh` foi rodado num repo descartável
em 2026-09-22 e o resultado foi comparado com o que a v3 exige de um consumidor.

---

## Context

A v3.0.0 apoia todo veredito de piloto numa condição: os relógios de falsificação só correm em
**projeto consumidor com ledger ativo** (A-1, e agora no protocolo pela MP-007). O caminho que cria
um projeto consumidor, o `scripts/setup.sh`, está em v1.7 e tem três defeitos, verificados no disco:

1. **Rodar de novo apaga a memória.** Os 5 `*_INDEX.md` e o `state.json` são escritos com `cat >`
   sem checar se já existem (`setup.sh:54,96,131,166,201,236`). Reprodução: uma linha adicionada ao
   `RULES_INDEX.md` sumiu depois de rodar o setup de novo. O dosiq já tem `.agent/` real.
2. **Não cria os ledgers.** Nem `process-friction.jsonl` (C5/1c) nem `attempts.jsonl` (C5/1b). E
   nada define quando um ledger passa a ser "ativo", então nenhum relógio tem início.
3. **Não cria o `.gitignore` quando ele falta** (`setup.sh:271-282`, "No .gitignore found (skip)"). O
   `state.json`, que é estado local e agora carrega o `session.handoff`, vai para o git no primeiro
   commit.

Nenhuma suíte cobre o `setup.sh`: foi assim que o defeito 3 sobreviveu desde a v1.7.

## User Stories

### US1 — Reinstalar não destrói o que o projeto aprendeu (P1)
Como operador, quero rodar o setup num repo que já tem `.agent/` (para atualizar a instalação) sem
perder regras, APs, ADRs, contratos nem o estado da sessão.

**Given** um `.agent/` existente com conteúdo nos índices e no `state.json`
**When** o setup roda de novo no mesmo repo
**Then** todo arquivo existente fica byte-idêntico, e só o que faltava é criado.

```po PO-1
ac:     rodar o setup sobre um .agent/ existente não altera nenhum arquivo que já existia
proof:  tests/setup.test.sh — caso "rerun preserva" (checksum de todo arquivo antes e depois)
expect: checksums idênticos; a saída do setup diz quais arquivos foram pulados
guard:  caso "repo novo" do mesmo teste segue verde
status: [x] done
evidence_class: execution
note:   `bash tests/setup.test.sh` → "19 passaram, 0 falharam" (2026-09-22). Reforçado por SC-002 com
        cópia REAL do .agent/ do dosiq (940 arquivos, symlink resolvido via `cp -RL`): checksum
        idêntico antes/depois do rerun. guard "repo novo" verde no mesmo run.
uncertainty: nenhum caminho conhecido ficou sem cobertura; os 6 pontos de `cat >` do setup.sh
        (state.json + 5 INDEX.md) e os 2 ledgers são exercitados individualmente pelo teste.
```

### US2 — Um repo novo nasce com o ledger ativo e com data de início (P1)
Como operador, quero que um projeto recém-instalado já tenha os dois ledgers e um marco de início,
para que a primeira sessão de C-mode comece a contar os relógios dos pilotos.

**Given** um repo sem `.agent/`
**When** o setup roda
**Then** `process-friction.jsonl` e `attempts.jsonl` existem (vazios), e o setup avisa que o relógio
só começa quando eles forem commitados.

```po PO-2
ac:     repo novo sai do setup com os dois ledgers e um marco de início legível
proof:  tests/setup.test.sh — caso "ledger ativo"
expect: os 2 arquivos existem e estão vazios; antes do commit, `git log --diff-filter=A` sobre o
        ledger sai vazio (inativo); depois de um commit no repo descartável, devolve uma data ISO
guard:  nenhum kind novo no process-friction.jsonl (vocabulário fechado do C5/1c intacto)
status: [x] done
evidence_class: execution
note:   `bash tests/setup.test.sh` → casos "PO-2" e "PO-2 guard" verdes (2026-09-22). Mecanismo
        confirmado ao vivo neste repo antes de codar: `git log --diff-filter=A --format=%cI -- .agent/memory/process-friction.jsonl`
        devolveu `2026-09-21T10:39:16-03:00` (commitado) vs. string vazia p/ caminho não commitado.
uncertainty: nenhuma.
```

### US3 — O estado local não vaza para o git (P2)
Como operador, quero que `state.json`, `sessions/` e `evolution/` fiquem fora do git mesmo quando o
repo não tinha `.gitignore`.

**Given** um repo sem `.gitignore`
**When** o setup roda
**Then** o `.gitignore` existe com as entradas do DEVFLOW; e um `.gitignore` existente ganha as
entradas que faltam, sem duplicar as que já estão lá.

```po PO-3
ac:     depois do setup, git check-ignore confirma state.json, sessions/ e evolution/ ignorados
proof:  tests/setup.test.sh — casos "sem .gitignore" e "com .gitignore parcial"
expect: `git check-ignore` casa os 3 caminhos; os ledgers e os índices NÃO são ignorados
guard:  rodar duas vezes não duplica nenhuma linha
status: [x] done
evidence_class: execution
note:   `bash tests/setup.test.sh` → casos "PO-3" (sem .gitignore / parcial) e "PO-3 guard" verdes
        (2026-09-22). `git check-ignore` confirmado sobre os 3 caminhos nos dois cenários;
        `memory/RULES_INDEX.md` explicitamente testado como NÃO ignorado.
uncertainty: nenhuma.
```

## Functional Requirements

- **FR-001** O setup é idempotente: nunca sobrescreve um arquivo existente em `.agent/` e informa o
  que foi pulado.
- **FR-002** O setup cria `.agent/memory/process-friction.jsonl` e `.agent/memory/attempts.jsonl`
  vazios, quando ausentes.
- **FR-003** O início do relógio de um ledger é **derivado do git**: é a data do commit que
  adicionou `.agent/memory/process-friction.jsonl` (Q1, decidida). Ledger que nunca foi commitado
  não está ativo, e o setup diz isso ao terminar.
- **FR-004** O setup cria o `.gitignore` quando falta e completa as entradas que faltam, linha a linha.
- **FR-005** A versão anunciada pelo setup e o `schema_version` do `state.json` acompanham a skill
  (v3.0), e o template inclui `session.handoff: null`.
- **FR-006** Flag opcional `--with-git-hook` instala o `mode-gate.sh` como hook local (nível 2 do
  FR-003 da spec 001). Sem a flag, nada muda.
- **FR-007** `tests/setup.test.sh` roda o setup em diretórios descartáveis, sem tocar o
  `~/.claude/skills` real.

## Success Criteria

- **SC-001** 100% dos ACs com PO fechada (`status [x]`) ao fim do C-mode.
- **SC-002** Rerun sobre um `.agent/` real (cópia do dosiq) preserva 100% dos arquivos.
- **SC-003** A suíte de regressão da v3 continua verde.

## Non-Goals

1. **Não** migrar `.agent/` de versões antigas (reorganizar categorias, converter o schema do
   `state.json` legado). Idempotência significa não destruir, não atualizar conteúdo. Migração é
   outra spec.
2. **Não** criar ou copiar os scripts (`second-opinion.sh`, `mode-gate.sh`, `skill-comply.sh`) para
   dentro do consumidor. As skills os chamam por caminho absoluto (`~/SKILLS/devflow/scripts/`), e
   copiar criaria versões divergentes.
3. **Não** iniciar o relógio de nenhum piloto neste repo (`devflow`). Aqui o `.agent/` segue parcial
   por decisão (`.agent/README.md`), e A-1 continua valendo.
4. **Não** instalar hook do Claude Code (nível 3). Só o git hook local, opcional.

## Invariants

- **INV-1 · Nunca destruir memória.** Nenhum caminho do setup sobrescreve ou apaga um arquivo que já
  existia em `.agent/`. Isso vale inclusive com flags.
- **INV-2 · Shell puro, sem dependência nova.** O setup continua rodando só com bash e as
  ferramentas que ele já usa.
- **INV-3 · O vocabulário do ledger não muda.** O marco de início não pode virar um `kind` novo no
  `process-friction.jsonl` (os `kind` são um vocabulário fechado, contado pelo D3.5).

## Assumptions / Open Questions

- **Q1 — RESOLVIDA 2026-09-22 pelo operador: (a) derivado do git.** Opções que foram consideradas:
  - **(a) Derivado do git:** "ativo desde o commit que adicionou `process-friction.jsonl`". Zero
    artefato novo e impossível de forjar sem reescrever o histórico. Porém exige que o operador
    commite o `.agent/`, e um ledger criado e nunca commitado não tem início. *Recomendada.*
  - **(b) Arquivo versionado `.agent/memory/ledger.json`**, com `{started_at, devflow_version}`.
    Explícito e legível sem git. Porém é um artefato a mais, e é editável à mão.
  - **(c) Linha no `evolution_log.jsonl`.** ⚠️ Inviável como está: o próprio setup gitignora
    `.agent/evolution/` (`setup.sh:276`), então o marco não seria versionado.
- **A-1** O `~/SKILLS/devflow` é o caminho canônico do clone (as skills já assumem isso).
- **A-2** O SC-002 usa uma **cópia** do `.agent/` do dosiq em diretório descartável, nunca o repo real.

## Próximo passo exato (handoff — sem state.json neste repo)

**Escrito em:** 2026-09-22.

**Next step:** nenhum — PO-1..3 fechadas, T001-T008 completas, SC-001..003 satisfeitos. Falta só
push + PR (branch `spec/002-setup-active-ledger`), que é decisão do operador (R-065).

**Failed:** nenhuma tentativa revertida nesta sessão. `failed: []`.

**Worked (evidência DESTA sessão):**
- Idempotência dos 6 pontos `cat >` via guarda `[ -f ... ]` — `bash tests/setup.test.sh` → "19
  passaram, 0 falharam".
- Marco de início derivado de `git log --diff-filter=A --format=%cI` — testado ao vivo neste repo
  E na suíte (caso "ledger ativo").
- SC-002 com cópia real do `.agent/` do dosiq (940 arquivos) — checksum idêntico, sem uso de mock.
- Regressão completa (6 suítes: ai-review-no-agent, mode-gate, no-core-shadowing, second-opinion,
  setup, skill-comply) — 0 falha, `shellcheck` limpo.

**Not tried:** `--with-git-hook` não foi exercitado contra um `mode-gate.sh` real bloqueando um
commit de verdade (só verificado que o arquivo é instalado e é executável — ver friction logada em
`process-friction.jsonl`, `kind: no-slot`, sobre a ambiguidade do conteúdo do hook). Se o operador
quiser essa garantia mais forte, é o próximo item natural, não coberto por PO-1..3.
