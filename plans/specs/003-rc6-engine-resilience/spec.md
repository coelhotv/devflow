# 003 — Revisores externos resilientes, com cobertura honesta e estado visível

**Feature Directory:** `plans/specs/003-rc6-engine-resilience/`
**Created:** 2026-09-24
**Status:** delivered (código) — PO-1..3 fechadas com evidência de execução; aguarda PR
**Tier:** 1
**Input:** relato do agente coder do `dosiq` no PR #835 (2026-09-24). No RC6, o pass A (agy/Gemini)
perdeu 3 dos 4 chunks com `503 UNAVAILABLE — no capacity`, mas o JSON final saiu com
`coverage.partial: false`. A investigação mostrou que isso não é regressão da spec 001.

---

## Context

O RC6 é o gate de revisão independente. Duas propriedades dele estão quebradas, e as duas foram
verificadas no código:

1. **A cobertura mente.** `ai-review.sh:1191` passa `$NCHUNKS` como `n_reviewed` para o merge. Esse
   número é a quantidade de chunks **selecionados** depois do cap, e não a de chunks que o motor
   **revisou**. Por isso `partial` (`:1244`) só pega corte por orçamento, nunca falha do motor. O bug
   existe desde `8275b5a2`/`c9198301` (2026-07/08), antes da 001. É o AP-325 dentro da própria
   ferramenta de review: o gate diz que a cobertura foi total quando foi de 1 chunk em 4.
2. **Uma falha passageira vira perda definitiva.** `run_engine` (`engine-core.sh:182`) roda o motor
   uma vez. O 503 "no capacity" é falta de capacidade do pool do **modelo** (a cota do operador
   continuava disponível) e costuma passar em minutos. Como os chunks rodam em sequência, três 503
   seguidos e depois o chunk 4 passando mostram um pico curto, e não uma queda.

Três fragilidades vizinhas: o agy roda sem hang guard (só o claude passa por `run_bounded`); o
`agy.err` é sobrescrito a cada chunk, e a evidência das falhas anteriores se perde; e o agente que
pediu a revisão não vê nada do que acontece até o fim, só stderr solto.

O `second-opinion.sh` (001/F2) usa o mesmo `@core` e herda os dois defeitos.

## User Stories

### US1 — A cobertura reportada é a cobertura que aconteceu (P1)
Como agente que lê o resultado do RC6, quero que o JSON diga quantos chunks cada passe revisou de
fato e por quantos revisores independentes, para não tratar como "clean duplo" um run com um
revisor só.

**Given** um RC6 em que o motor do pass A falha em parte dos chunks e o pass B completa
**When** o merge gera o JSON
**Then** `coverage.partial` é `true`, `chunks_reviewed` conta só os chunks que deram certo, e o
detalhe por passe diz quais chunks falharam e por qual classe de erro.

```po PO-1
ac:     falha do motor em parte dos chunks aparece como cobertura parcial no JSON, por passe
proof:  tests/rc6-resilience.test.sh — caso "falha parcial do pass A" (agy falso: 503 em 3 de 4 chunks,
        esgotando retry e fallback; claude falso ok)
expect: partial=true; chunks_reviewed < chunks_planned; per_pass.A.ok=1, per_pass.A.planned=4;
        per_pass.A.failed lista 3 chunks com class=transient; independent_reviewers.min=1
guard:  caso "tudo ok" segue com partial=false e reviewers.min=2; os campos chunks_reviewed,
        chunks_planned, partial e not_reviewed continuam presentes (contrato aditivo); as 6 suítes
        de tests/ verdes e `tests/ai-review-paths.sh` sem diff nos 4 cenários antigos, **exceto as
        adições do contrato aditivo** (linha `status:`, linha `VERDICT`, chaves novas de `coverage`),
        provado removendo-as do "depois" e comparando de novo (RC3: guard ↑)
status: [x] done
evidence_class: execution
red:    contra o HEAD adbc351 (worktree limpo): "rc6-resilience: 6 passaram, 25 falharam". O primeiro
        FALHA reproduz o dosiq#835 literalmente: "partial=False (esperado True)", "chunks_reviewed=4".
note:   `bash tests/rc6-resilience.test.sh` → "31 passaram, 0 falharam" (2026-09-24): partial=true,
        chunks_reviewed<planned, per_pass.A=1/4, failed 3×transient, reviewers min=1 max=2. Guard: as 6
        suítes (ai-review-no-agent 3/3, mode-gate 10/10, no-core-shadowing 5/5, second-opinion 23/23,
        setup 19/19, skill-comply 10/10) + test-rank-chunks ok; ai-review-baseline sem diff; o diff do
        ai-review-paths depois de remover as 3 adições esperadas saiu VAZIO (argv do motor, egress,
        fail-open e ordem de logs byte a byte iguais).
uncertainty: o caminho `--post` (comentário no PR) não é exercitado por teste (exige gh + PR). O trecho
        de cobertura dele foi compilado e executado isolado sobre um merged sintético; o POST real fica
        para o primeiro RC6 de campo (SC-003).
```

### US2 — Falha passageira do motor não custa um chunk (P1)
Como operador, quero que um erro de capacidade ou de rede ganhe novas tentativas e um modelo
alternativo antes de o chunk ser dado como perdido, sem gastar tempo em erros que não passam.

**Given** um motor que devolve erro passageiro e depois se recupera
**When** o RC6 roda o chunk
**Then** o chunk é revisado depois de nova tentativa ou no modelo alternativo, dentro do orçamento
de tempo. E um erro de quota ou fatal **não** ganha nova tentativa.

```po PO-2
ac:     erro passageiro é recuperado por retry ou fallback de modelo; quota e fatal não repetem
proof:  tests/rc6-resilience.test.sh — casos "503→503→ok", "503 persistente no modelo principal, ok no
        fallback", "429 sem retry", "3×503 abre o breaker e a segunda rodada recupera",
        "envelope FAILED com exit 0", "timeout não repete na hora" (fixture com o texto REAL do 503)
expect: chunk ok nos casos recuperáveis, com per_pass.A.retried e .model_fallback corretos; no 429,
        o agy falso é chamado 1 vez só; tempo extra ≤ RC6_RETRY_BUDGET (padrão 300s, com backoff
        encurtado por env no teste)
guard:  com RC6_RETRIES=0 e sem modelo de fallback, o comportamento é o de hoje (1 chamada por chunk);
        o A/B do 056/PO-5 não recebe saída de modelo alternativo; as 6 suítes verdes (RC3: guard ↑)
status: [x] done
evidence_class: execution
red:    mesmo run do PO-1 contra o HEAD: "503→503→ok: None", "fallback: None", "modelo alternativo
        nao foi chamado", "breaker: {...'partial': False...}", "timeout: None".
note:   31/31 (2026-09-24): 503→503→ok (retried=1); 503 com exit 1 também repete; fallback chamou
        gemini-3.7-flash-medium (model_fallback=1); 429 e fatal: 1 chamada só; 3×503 abre o breaker, a
        4ª chamada é o chunk 2 e a segunda rodada recupera o chunk 1; hang: a 2ª chamada é o chunk 2 e
        a segunda rodada recupera; hang com RC6_RETRY_BUDGET=0: não repete, classe timeout. Guard
        RC6_RETRIES=0 sem fallback: 4 chamadas para 4 chunks. A/B: saída marcada `.modelfb` fica fora
        do baseline (ai-review.sh:1134) e o par chama com fallback desligado (:1153).
uncertainty: o isolamento do A/B (FR-014) está verificado por leitura de código, não por teste: armar o
        A/B exige PR + log de medição, fora do fixture. A 1ª hipótese de texto de erro vem do log real
        (503); textos de 429/timeout do agy real nunca foram observados — padrões por palavra-chave, e
        o desconhecido cai em `fatal` (lado seguro, A-2).
```

### US3 — Quem pediu a revisão acompanha o estado (P2)
Como agente que dispara o RC6 (às vezes em background), quero acompanhar o progresso e receber um
veredito explícito, para decidir sem ter que interpretar stderr solto.

**Given** um RC6 rodando, com retries acontecendo
**When** o agente acompanha o arquivo de status e lê o fim da execução
**Then** cada transição de estado aparece como uma linha JSON, a espera do backoff é anunciada no
stderr, e a última linha do stderr é um VERDICT que bate com o `coverage` do JSON.

```po PO-3
ac:     transições de estado viram eventos legíveis por máquina, e o VERDICT final bate com o JSON
proof:  tests/rc6-resilience.test.sh — caso "status file" (mesmo cenário do PO-2, com RC6_STATUS_FILE)
expect: o arquivo tem a sequência started→retrying→ok (ou →deferred→failed), cada linha é JSON
        válido com pass/chunk/state; ele sobrevive ao fim do run; a linha VERDICT diz
        coverage=partial|full e A=<ok>/<planned> iguais ao JSON
guard:  o stdout segue sendo só o JSON final (nenhum evento de status vaza para ele)
status: [x] done
evidence_class: execution
red:    contra o HEAD: status file inexistente, sem VERDICT (asserções de status/VERDICT FALHA).
note:   31/31 (2026-09-24): toda linha do status file é JSON com pass/chunk/state; contém started,
        retrying, breaker_open, deferred, ok, done; stderr anuncia "status: <caminho>"; heartbeat
        "aguardando 1s"; última linha do stderr = "VERDICT coverage=partial A=1/4 B=4/4
        reviewers_min=1 …", igual ao JSON; stdout segue JSON puro.
uncertainty: nenhuma.
```

## Functional Requirements

- **FR-001** `coverage.chunks_reviewed` conta os chunks revisados com sucesso por **todos** os passes
  ativos, e `partial` é `chunks_reviewed < chunks_planned`. Na prática, `partial` fica `true` quando
  qualquer passe ativo tem `ok < planned` *(corrigido na implementação em 2026-09-24; ver Registro
  de correções)*. **Contrato aditivo:** os
  campos atuais continuam, e entram `per_pass` (`planned`, `ok`, `retried`, `model_fallback`,
  `failed[{chunk, class, attempts}]`) e `independent_reviewers {min, max}`.
- **FR-002** Arquivos de chunks que **nenhum** passe revisou entram em `not_reviewed`. O motivo vai no
  campo novo `not_reviewed_detail[{file, reason: cap|engine_failed}]`, porque `not_reviewed` segue
  sendo lista de strings (contrato aditivo).
- **FR-003** O erro do motor é classificado em `transient`, `timeout`, `quota` ou `fatal`, a partir do
  texto de erro **da tentativa** (stderr do CLI e mensagem de envelope FAILED, inclusive com exit 0).
  Só `transient` ganha nova tentativa imediata. `timeout` vai direto para a segunda rodada, e só se
  o orçamento restante couber um timeout inteiro.
- **FR-004** Nova tentativa com backoff exponencial e jitter: padrão de 2 tentativas extras, com
  ajuste por env (`RC6_RETRIES`, `RC6_BACKOFF`).
- **FR-005** Se as tentativas esgotarem num erro `transient`, o chunk tenta o modelo alternativo
  `RC6_AGY_MODEL_FALLBACK`, padrão `gemini-3.7-flash-medium` (equivalente ao principal, decidido
  pelo operador em 2026-09-24).
- **FR-006** Chunks ainda falhos voltam uma vez para o fim da fila (segunda rodada).
- **FR-007** Circuit breaker: 3 falhas `transient` seguidas suspendem as tentativas imediatas e
  mandam os chunks restantes para a segunda rodada. Todo o tempo extra respeita
  `RC6_RETRY_BUDGET` (padrão 300s).
- **FR-008** O agy ganha hang guard, igual ao claude.
- **FR-009** Cada tentativa guarda o próprio stderr. O hint de erro usado no log é o da tentativa
  que falhou.
- **FR-010** Eventos de estado em JSONL no caminho de `RC6_STATUS_FILE` (padrão fora do diretório
  de trabalho que é apagado no fim). O stderr informa o caminho logo antes da primeira chamada de
  motor, para quem não o definiu conseguir acompanhar *(era "primeira linha do stderr"; corrigido em
  2026-09-24: anunciar antes do egress/measure mudaria a saída de caminhos que não chamam motor)*. Estados: `started`, `ok`, `retrying`, `model_fallback`,
  `deferred`, `failed`, `breaker_open`, `done`.
- **FR-011** Durante o backoff, o stderr anuncia a espera (tentativa, chunk, orçamento restante). A
  última linha do stderr é `[rc6] VERDICT coverage=… A=ok/planned B=ok/planned reviewers_min=…`.
- **FR-012** O `second-opinion.sh` herda FR-003..FR-009 pelo `@core`. A troca agy→claude que ele já
  faz continua: lá existe uma voz só, então não há independência a contar (o Non-Goal 1 é do RC6).
- **FR-014** O A/B do 056/PO-5 não aceita saída de modelo alternativo, nem no baseline nem no par:
  comparar modelos diferentes mediria o modelo, não o filtro. Nova tentativa no mesmo modelo é
  permitida dos dois lados.
- **FR-016** Com exit ≠ 0, o envelope do agy também é desembrulhado para o arquivo de erro, antes de
  classificar *(achado na implementação: sem isso, o 503 com exit 1 virava `fatal`)*.
- **FR-015** O orçamento de tempo extra é um só por run, somado entre os passes A, B (fallback
  em chunks) e A/B.
- **FR-013** A seção RC6 do `devflow-code` ensina a ler o VERDICT e o `coverage`: `partial` é
  registro obrigatório no PR, não motivo para rodar de novo (a regra "RC6 roda uma vez" continua).

## Success Criteria

- **SC-001** 100% dos ACs com PO fechada (`status [x]`) ao fim do C-mode.
- **SC-002** A suíte de regressão (as 6 suítes de `tests/`) continua verde, e `shellcheck` fica limpo.
- **SC-003** No próximo RC6 real com 503 no dosiq, o JSON e o VERDICT concordam com o stderr. Isso
  é verificação de campo, feita depois do merge, e não bloqueia esta spec.

## Non-Goals

1. **Não** usar o claude para cobrir chunks do pass A que falharam (fallback cruzado) por padrão.
   A cobertura mostraria 4/4, mas com um revisor só, que é o engano do relato do dosiq.
   *(Opt-in `RC6_CROSS_FALLBACK=1` fica como pergunta aberta Q1, fora do escopo por enquanto.)*
2. **Não** repetir chamadas em erro de quota (429/RESOURCE_EXHAUSTED). Repetir só gasta mais cota. O
   certo é o operador trocar de motor (`RC6_ENGINE_CLAUDE=0` já existe para o caso inverso).
3. **Não** rodar os chunks em paralelo. Isso muda o perfil de carga no provedor, e é justamente o
   que provoca 503. Outra spec, se o tempo virar problema.
4. **Não** mudar a regra "RC6 roda uma vez por PR". Retry é por chunk, dentro do mesmo run.

## Invariants

- **INV-1 · O JSON nunca mostra mais cobertura do que houve.** Nenhum caminho (retry, fallback,
  segunda rodada) conta um chunk como revisado sem saída válida de um motor.
- **INV-2 · A independência dos revisores é contada, não presumida.** Chunk revisado por um só
  motor conta como 1 revisor, mesmo que o run tenha dois passes.
- **INV-3 · O stdout é só o contrato.** Progresso e estado vão para stderr ou para o status file,
  nunca para o stdout.
- **INV-4 · O egress guard continua antes de qualquer chamada.** Nenhuma tentativa pula o
  SC-SEC5.

## Assumptions / Open Questions

- **A-1** O `gemini-3.7-flash-medium` tem pool de capacidade separado do `3.8` (é a premissa do
  FR-005; decidida pelo operador).
- **A-3** O `skill-comply.sh` (001/H) é um terceiro consumidor do `@core`, que o RC3 não mapeou. Ele
  continua no `run_engine` bruto (é instrumento de medição, e retry mudaria o que ele mede). Só a
  versão esperada subiu, e ele herda o hang guard do agy.
- **A-2** A classificação usa as mensagens de erro dos CLIs (`agy`, `claude`) observadas até hoje. Um
  texto de erro desconhecido cai em `fatal`, sem nova tentativa, que é o lado seguro.
- **Q1 (não bloqueia)** Oferecer `RC6_CROSS_FALLBACK=1` numa spec futura, com `engine_substituted`
  no `coverage`? Fica fora desta spec (Non-Goal 1).

## Ceremony: eng-review (RC3 · 2026-09-24)

### Posição inicial — RC3
- Posição: o escopo está certo, mas o retry precisa morar num único ponto do `@core`, e a spec o
  espalhava pelos laços dos consumidores.
- Três razões mais fortes: existem 4 laços que chamam `run_engine` (A, fallback do B, par A/B,
  second-opinion) · o orçamento de tempo só funciona se for contado num lugar só · a classificação
  depende do formato do erro do agy, que não foi conferido.
- Maior risco do caminho preferido: retry dentro do `@core` também atinge o A/B do 056/PO-5.

### Achados (lidos no código, não presumidos)
| # | Sev | Achado | Decisão |
|---|---|---|---|
| E1 | alta | Com `AGY_SCHEMA=1`, a falha pode vir com **exit 0** e envelope `status≠SUCCESS`. Aí o erro só aparece na mensagem do `unwrap_structured` (`engine-core.sh:139`, `2>>agy.err`). Classificar só pelo stderr do CLI deixaria o 503 como `fatal`. | FR-003: classificar sobre o texto de erro da tentativa. PO-2 ganha o caso "envelope FAILED com exit 0" e fixture com o texto **real** do 503 (tirado do log do dosiq#835). |
| E2 | alta | `timeout` tratado como `transient` gasta até 8 min por tentativa (`AGY_TIMEOUT=8m`, `PASSB_TIMEOUT=480`). Uma tentativa já estoura o orçamento de 300s. | Classe nova `timeout`: não repete na hora; entra na segunda rodada só se o orçamento restante couber um timeout inteiro. |
| E3 | alta | O A/B (`ai-review.sh:1077-1096`) usa `outA_*` como baseline. Com a saída do modelo alternativo no baseline, o par compararia modelos diferentes e mediria o modelo, não o filtro. | FR-014: modelo alternativo nunca entra no A/B. Nova tentativa no mesmo modelo, sim, dos dois lados. |
| E4 | média | O log de falha (`FAILED — $(engine_err_hint …)`) está repetido em 4 laços. Pôr o retry em cada laço repetiria a lógica 4 vezes. | Plano: um wrapper resiliente no `@core` que chama o `run_engine` bruto (que continua existindo) e cuida sozinho de log, status e orçamento. O consumidor só diz "pode usar fallback de modelo?". |
| E5 | média | O `second-opinion.sh:193-198` já troca agy→claude. Isso parecia contradizer o Non-Goal 1. | FR-012 deixa explícito: lá existe uma voz só, então não há independência a contar. O Non-Goal 1 vale para o RC6. |
| E6 | média | O status file com caminho padrão não é encontrável por quem não definiu `RC6_STATUS_FILE`. | FR-010: a primeira linha do stderr anuncia o caminho. |
| E7 | média | `tests/ai-review-paths.sh` é um harness de caracterização (saída → `diff` antes/depois), não de asserções. Misturar os dois estraga os dois. | Suíte nova `tests/rc6-resilience.test.sh` (estilo ok/bad do `second-opinion.test.sh`); agy falso com roteiro por chamada; `RC6_BACKOFF`/jitter zerados por env. O `ai-review-paths.sh` vira guard: sem diff nos 4 cenários antigos. |
| E8 | baixa | Cada passe contando o próprio orçamento soma mais que 300s. | FR-015: um orçamento só por run. |

### Guard calibration
- **PO-1 e PO-2: guard ↑ para a suíte inteira** (6 suítes + `ai-review-paths.sh` sem diff). Motivo: o
  `@core` tem 2 consumidores e a mudança acontece no ponto por onde passa toda chamada de motor, então
  o raio de impacto é maior que o de um Tier 1 comum. PO-3 fica como está (canal lateral e isolado).

### Complexidade
Arquivos tocados: `engine-core.sh`, `ai-review.sh`, `second-opinion.sh`, `devflow-code/SKILL.md`,
`tests/rc6-resilience.test.sh` (novo), mais o guard em `ai-review-paths.sh`. São 5 a 6 arquivos e
nenhum serviço novo: abaixo do limite de 8. O Tier 1 com PR único se sustenta.

### Síntese
Nenhuma divergência da posição inicial. O risco do A/B se confirmou (E3). A leitura acrescentou
E1 e E2, que eu não tinha previsto: sem eles, o retry não dispararia no 503 real (E1) ou estouraria o
orçamento no primeiro timeout (E2). Os dois são pré-condição do PO-2.

## Registro de correções (HISTÓRICO — a fonte de verdade é o corpo acima)

| O que estava errado | Como foi verificado | Onde a correção mora |
|---|---|---|
| FR-001 dizia "revisado por **algum** motor", mas a PO-1 esperava `chunks_reviewed < planned` num cenário em que o claude cobre tudo. As duas coisas não podiam ser verdade juntas. | Ao escrever a asserção da PO-1 | FR-001: "por **todos** os passes ativos". Mantém `partial ⇔ reviewed < planned`, a semântica anterior. |
| FR-010: "primeira linha do stderr" | O diff do `ai-review-paths.sh` mostraria a linha nova em egress/fail-open | FR-010: "antes da primeira chamada de motor" |
| O RC3 mapeou 2 consumidores do `@core`; são 3 | `grep ENGINE_CORE_EXPECTED scripts/` | A-3 |
| O E1 do RC3 cobria só o envelope com exit 0 | Caso `503x` do teste: exit 1 com envelope → o texto sumia | FR-016 + `engine-core.sh:201` |
| O guard da PO-1 prometia "sem diff" no `ai-review-paths.sh`, o que é impossível sob contrato aditivo | Diff real: só `status:`, `VERDICT` e chaves novas | Guard da PO-1 reescrito (diff sem as 3 adições = vazio) |

## Próximo passo exato (handoff — sem state.json neste repo)

**Escrito em:** 2026-09-24.

**Next step:** push da branch `spec/003-rc6-engine-resilience` e PR (decisão do operador, R-065).
Depois do merge, o primeiro RC6 real no dosiq com 503 fecha o SC-003 (verificação de campo).

**Failed:** `failed: []`. Nenhuma intervenção revertida. O primeiro vermelho rodou contaminado (o core
foi editado durante a execução) e foi refeito num worktree limpo do HEAD. O segundo vermelho rodou
com um bug do próprio fake (`cut -f2` sem `-s` repetia roteiros de um token) e também foi refeito.

**Worked (evidência DESTA sessão):** `bash tests/rc6-resilience.test.sh` → 31/31; as 6 suítes da
regressão verdes; `ai-review-baseline` sem diff; `ai-review-paths` com diff só aditivo; `shellcheck`
com os mesmos avisos do HEAD (SC1091/SC2012/SC2016/8×SC2034/7×SC2086, todos pré-existentes).

**Not tried:** `--post` contra um PR real; A/B armado (PR + log de medição); agy real com 503 (é o
SC-003).
