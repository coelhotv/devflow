# 001 — Absorção ECC → DEVFLOW

**Feature Directory:** `plans/specs/001-ecc-absorption/`
**Created:** 2026-09-19
**Status:** in-progress — slice A entregue, slice B é o próximo
**Tier:** 2
**Input:** garimpo de `/Users/coelhotv/git/Everything-Claude-Code` em duas rodadas
(`~/SKILLS/ecc-devflow-review-and-plan.md`, `~/SKILLS/ecc-devflow-mining-round2.md`)

---

## Context & Problem Statement

O DEVFLOW v2.3 evoluiu três vezes por fora do próprio protocolo de meta-evolução. Duas rodadas de
garimpo do ECC identificaram 8 lacunas instrucionais e 4 propostas estruturais que valem absorver.
Sem uma spec, isso vira um conjunto de edições soltas em arquivos de skill carregados em toda sessão —
exatamente o modo de falha que o DEVFLOW existe para evitar.

Esta spec é também o primeiro uso do DEVFLOW sobre si mesmo: o repositório não tinha `.agent/` nem
`plans/specs/`.

## Non-Goals (fora de escopo)

1. **Não** reescrever a divisão RC5/RC6. A separação autor-em-contexto vs. independente-em-contexto-frio
   é deliberada e foi confirmada na revisão — não é lacuna.
2. **Não** paralelizar a escrita de código (C3). "The filesystem is the orchestrator" é decisão de
   arquitetura; multi-agente ali compra contenção de arquivo, não qualidade.
3. **Não** introduzir rubricas numéricas de qualidade (escalas 1–10, confidence score). Rejeitado com
   base no próprio recuo do ECC em `commands/learn-eval.md:143-145`.
4. **Não** criar a skill `/devflow-aside`. Descartada: evidência fraca e `/btw` já cobre.
5. **Não** adotar hooks do Claude Code como substrato de enforcement — amarra o DEVFLOW a um cliente.

## System Invariants

Regras que nenhum slice pode violar. Quando uma virar contrato formal, promover a CON-NNN e referenciar.

- **INV-1 · R-065 permanece soberana.** Nenhuma mutação pode fazer o agente avançar de modo sozinho.
- **INV-2 · Portabilidade.** Todo enforcement novo roda em shell puro; nenhum comportamento pode
  depender de um cliente específico. Hook do Claude Code é açúcar opcional que só invoca o CLI.
- **INV-3 · Fail-open assimétrico.** Gate novo que não consegue decidir **deixa passar e marca**.
  Bloquear trabalho legítimo com carimbo de gate é o modo de falha inaceitável.
- **INV-4 · Nenhuma edição de prosa de skill fora do fluxo `devflow_mutation_proposal` + aprovação
  do operador (`DEVFLOW-META.md`).**
- **INV-5 · Mudança em C1/C4/Bootstrap exige incidente real** (`DEVFLOW-META.md:102`). Sem incidente,
  a mutação entra rebaixada a piloto com critério de remoção.
- **INV-6 · Máx. 2 propostas pendentes simultâneas** (`DEVFLOW-META.md:101`).

## Decisões transversais

### DT-1 · Regras de admissão (substituem o teto em LOC)
O recurso escasso não é linha; é o número de mecanismos distintos que um modelo fraco precisa segurar.
Toda mutação responde: **(a)** que mecanismo existente ela estende (criar novo exige justificar por que
nenhum serve); **(b)** o que ela aposenta, ou por que nada é aposentável; **(c)** pode ser script em
vez de prosa? Se pode, prosa é a escolha errada.

### DT-2 · Modo de evolução: esta spec é PROATIVA
O `DEVFLOW-META.md` é reativo (auto-heal: dor → ledger → 3 observações → proposta). Esta spec é
proativa: oportunidade minerada, **sem dor observada**. Risco dominante invertido — o pior caso não é
demorar, é construir maquinário que ninguém precisava (família AP-325). Controles compensatórios,
obrigatórios em toda proposta emitida por esta spec:

1. `origin: proactive` declarado na proposta e na linha de versão da skill.
2. **Assinatura de atrito prevista:** *"se isto importa, aparecerá `<kind>` em `process-friction.jsonl`
   em N sessões"*. Não apareceu ⇒ remover. O caminho proativo passa a **alimentar** o ledger reativo.
3. **Sunset por padrão:** reversível e expira, salvo promoção por observação real.
4. Nunca em C1/C4/Bootstrap sem incidente real (INV-5).

### DT-3 · Toda mutação nasce piloto com cláusula de falsificação
Exigência da v2.3 e compensação por DT-2. Nenhuma entra como regra consolidada nesta spec.

---

## User Stories

### US1 — O operador consegue rastrear o trabalho inteiro (P1)
Como operador do DEVFLOW, quero uma lista de slices com dependências e POs, para saber o que falta
sem reler dois relatórios de garimpo.

**Given** os relatórios das duas rodadas
**When** abro `spec.md` e `tasks.md`
**Then** cada achado está atribuído a exatamente um slice, com PO e critério de remoção.

### US2 — O controle de modo deixa de ser probabilístico (P1)
Como agente DEVFLOW rodando em qualquer cliente, quero que a transição de modo seja verificável por
script, para que a R-065 não dependa de eu lembrar dela.

**Given** um `state.json` e a skill carregada
**When** `scripts/mode-gate.sh` roda
**Then** devolve `{"ok":true}` ou `{"ok":false,"reason":…}`; e **na dúvida deixa passar marcando**.

### US3 — A evidência de uma PO passa a declarar a própria força (P2)
Como auditor no RC5 Pass 0, quero saber se a prova foi reconciliada, executada, lida ou inferida,
para distinguir demonstrado de afirmado.

**Given** um bloco `po` fechado
**When** o Pass 0 audita
**Then** a classe declarada em `evidence:` é confrontada com o que `proof:` prometia.

---

## Functional Requirements

- **FR-001** `spec.md` traz a tabela de slices como autoridade da ordem; todo `po` declara `slice:`.
- **FR-002** `scripts/mode-gate.sh` valida transição de modo sem LLM, em shell puro, com fail-open assimétrico.
- **FR-003** O gate é distribuído em 3 níveis de acoplamento; remover o nível 3 não altera comportamento.
- **FR-004** Bloco `po` ganha `boundary:`, `evidence:`, `uncertainty:` e o terceiro `status`.
- **FR-005** C-mode ganha caminho de falha: trio de aborto, ordenação por dependência, parada de busca no C1.5.
- **FR-006** R-065 ganha terminação mecânica e proibição do auto-consentimento.
- **FR-007** S4/P2.5/P3/RC5 recebem M2–M5 da 1ª rodada.
- **FR-008** Funções agnósticas do `ai-review.sh` passam a viver em `scripts/lib/engine-core.sh`, com equivalência provada.
- **FR-009** `scripts/second-opinion.sh` serve cerimônias e C1.5 Tier 2 sem tocar o caminho de PR.
- **FR-010** O protocolo de handoff é escolhido por comparação de formatos antes de virar texto no C5.
- **FR-011** `DEVFLOW-META.md` passa a prever evidência de corpus externo com controles compensatórios (DT-2).

## Success Criteria

- **SC-001** 100% dos ACs têm PO fechada (`status [x]`) ao fim do C-mode de cada slice.
- **SC-002** Nenhuma edição de prosa de skill ocorre fora de proposta aprovada (INV-4).
- **SC-003** Nunca mais de 2 propostas pendentes ao mesmo tempo (INV-6).
- **SC-004** Toda mutação desta spec carrega `origin: proactive`, assinatura de atrito prevista e sunset.
- **SC-005** `ai-review.sh` mantém comportamento byte-idêntico após a extração do `@core`.

---

## Estado & próximo passo (leia primeiro numa sessão nova)

**Última sessão:** 2026-09-19 · **Slices A e B entregues** · **POs fechadas: 4 de 23** (PO-1, PO-2, PO-14, PO-15).
**Propostas de mutação pendentes: 1** (MP-003 — INV-6: 1 vaga livre).

**Próximo passo exato:** ⛔ **aprovar ou rejeitar MP-003** (`mutations/D-po-grammar.md`, slice D).
Aprovada, segue T033. Livre em paralelo: **G** (estudo de handoff).

**Entregue no slice F1:** `scripts/lib/engine-core.sh` (9 funções agnósticas, `ENGINE_CORE_VERSION`
1.0.0) · `ai-review.sh` consome o core e valida a versão (1754 → 1583 linhas) ·
`tests/ai-review-baseline.sh` (baseline determinística, substitui um proof que passava por
construção) · `tests/no-core-shadowing.test.sh`. **PO-14 e PO-15 fechadas** — as duas primeiras POs
automatizáveis do épico. Nenhuma prosa de skill tocada, nenhuma proposta emitida.

**Entregue no slice C:** `SKILL.md` (núcleo) — a R-065 ganha terminação mecânica (nenhuma tool call
após o STOP) e a proibição do auto-consentimento (perguntar e responder por conta própria =
consentimento falsificado). **v2.4.0 → v2.5.0 (PILOTO)**. Sunset com relógio suspenso até haver
ledger ativo (A-1).

**Entregue no slice B:** `skills/devflow-code/SKILL.md` — C1 resolve runners e proíbe `proof:` chutado ·
C1.5 ganha `1c` (parada: boundary / saturação / teto + `<!-- deferred: -->`) · C3 ordena erros por
dependência · C4 ganha trio de aborto · 3 linhas na Quick Reference. Núcleo **v2.3 → v2.4.0 (PILOTO)**.
Proposta e drafts em `mutations/` (MP-001 `approved` + `MP-001-applied`).

**Contexto que não está no repo:** os dois relatórios de garimpo que originaram esta spec vivem em
`~/SKILLS/ecc-devflow-review-and-plan.md` (1ª rodada) e `~/SKILLS/ecc-devflow-mining-round2.md`
(2ª rodada). **`~/SKILLS` não é repositório git** — se precisar deles, leia do disco.

**Atrito registrado nesta sessão:** o teste do slice A nasceu com expectativa errada (tratava
`devflow-spec --to specifying` como violação, quando é transição legítima concedida pelo operador).
`kind: test_expectation_wrong`. Não houve `.agent/` onde gravar (A-1) — está no `tasks.md`, T007.

---

## Tabela de slices — autoridade da ordem

| Slice | Status | Escopo | Tier | Depende de | POs | Arquivos | PR |
|---|---|---|---|---|---|---|---|
| **A** | ✅ done | `mode-gate.sh` em 3 níveis de acoplamento | 1 | — | PO-1, PO-2 | `scripts/mode-gate.sh`, `tests/` | — |
| **B** | ⚠️ aplicado (piloto) · POs MANUAL abertas | C-mode: M1 runner detection · F5 parada de busca (C1.5) · F6 trio de aborto (C3/C4) | 2 | — | PO-3, PO-4, PO-5 | `skills/devflow-code/SKILL.md` | — |
| **C** | ⚠️ aplicado (piloto) · PO-6 MANUAL aberta | R-065: F7 terminação mecânica + proibição do Y/N auto-respondido | 1 | A | PO-6 | `SKILL.md` | — |
| **D** | ⏸ aguardando aprovação (MP-003) | Gramática do `po`: F1 `boundary:` · F2 `evidence:` · F3 `status [!]` · F4 `uncertainty:` · M6 RED | 2 | B | PO-7..PO-10 | `SKILL.md`, `skills/devflow-code/`, `skills/devflow-spec/` | — |
| **E** | ⏳ todo | Spec & Plan: M3 Non-Goals · M4 Pattern Grounding · M5 task grammar · M2 pre-report gate | 1 | D | PO-11..PO-13 | `skills/devflow-spec/`, `skills/devflow-plan/`, `skills/devflow-code/` | — |
| **F1** | ✅ done — PO-14, PO-15 fechadas | Extração do `@core` — zero mudança de comportamento | 2 | — | PO-14, PO-15 | `scripts/lib/engine-core.sh`, `scripts/ai-review.sh` | — |
| **F2** | ⏳ todo | `second-opinion.sh` + clientes (RC1–RC4 com F8, C1.5 Tier 2) | 2 | C, D, F1 | PO-16..PO-19 | `scripts/second-opinion.sh`, `skills/devflow-code/`, `skills/devflow-ceremony/` | — |
| **G** | ⏳ todo (estudo pode começar já) | Handoff: estudo de formato → endurecimento do C5 | 1 | — | PO-20, PO-21 | `skills/devflow-code/` (C5) | — |
| **H** | ⏳ todo | Falsificação: medição de conformidade + caminho `external_corpus` no META | 1 | todos | PO-22, PO-23 | `DEVFLOW-META.md`, `scripts/` | — |

**Branch:** `spec/001-ecc-absorption` — **único para o épico inteiro** (decisão do operador, 2026-09-19;
renomeado de `spec/001-ecc-absorption-slice-a`). Um commit semântico por slice; não se abre branch por slice.
A coluna PR da tabela fica vazia enquanto o épico não for aberto como PR.

**Execução:** A → B → C → D → E → F1 → F2 → G (estudo em paralelo desde o início) → H.
F1 não emite proposta (não toca prosa) — pode correr a qualquer momento.
Por INV-6 (máx. 2 propostas em voo): o slice A fechou sem emitir nenhuma, então B e C podem abrir juntos;
D espera uma das duas fechar.

---

## Proof Obligations

```po PO-1
slice:  A
ac:     mode-gate.sh aprova uma transição de modo legítima e rejeita uma com PO aberta
proof:  bash tests/mode-gate.test.sh
expect: todos os casos passam; caso "PO aberta" retorna ok=false com reason
guard:  bash -n scripts/*.sh && shellcheck scripts/mode-gate.sh
status: [x] done
# evidencia 2026-09-19: "10 passaram, 0 falharam" (exit=0), incluindo
#   "violacao: PO aberta em coding" -> ok=false e "PO fechada: passa" -> ok=true.
#   guard: shellcheck limpo, bash -n ok.
```

```po PO-2
slice:  A
ac:     na dúvida o gate deixa passar marcando — arquivo ausente, JSON malformado e campo desconhecido nunca bloqueiam
proof:  bash tests/mode-gate.test.sh --degraded
expect: os três casos retornam ok=true com uma marca de degradação; nenhum retorna ok=false
guard:  nenhum caso de teste do PO-1 regride
status: [x] done
# evidencia 2026-09-19: "7 passaram, 0 falharam" (exit=0) — state ausente, JSON malformado,
#   campo desconhecido, state vazio, JSON nao-objeto, skill desconhecida, kill switch:
#   todos ok=true com marca DEGRADED:*. Nenhum ok=false.
#   guard: suite PO-1 reexecutada verde depois.
```

```po PO-3
slice:  B
ac:     C1 resolve os comandos reais de test/lint/typecheck antes de qualquer PO citar comando
proof:  MANUAL — rodar C1 num projeto não-npm e colar a resolução registrada
expect: os comandos registrados vêm de state.json/manifesto do projeto, não de chute
guard:  nenhuma PO da sessão cita comando fora dos resolvidos
status: [ ] open
# M1 aplicado em skills/devflow-code/SKILL.md (C1, bloco RUNNERS RESOLVIDOS) em 2026-09-19.
#   Evidencia pendente: proof e MANUAL e exige C1 rodado em projeto nao-npm real (A-2).
#   INSTRUMENTO PRONTO != AC DEMONSTRADA. Nao marcar [x] sem colar a evidencia.
```

```po PO-4
slice:  B
ac:     C1.5 declara por que parou de buscar e registra o que ficou por ler
proof:  MANUAL — executar um C1.5 Tier 2 e colar o critério de parada disparado
expect: um dos três critérios nomeado + marcador deferred quando sobrar arquivo
guard:  o PASS do C1.5 continua exigindo tabela de evidência populada
status: [ ] open
# F5 aplicado em skills/devflow-code/SKILL.md (C1.5, item 1c) em 2026-09-19.
#   Evidencia pendente: proof e MANUAL e exige um C1.5 Tier 2 real (A-2).
#   INSTRUMENTO PRONTO != AC DEMONSTRADA. Nao marcar [x] sem colar a evidencia.
```

```po PO-5
slice:  B
ac:     um loop de correção aborta por delta líquido, repetição idêntica ou reclassificação de escopo
proof:  MANUAL — provocar erro repetido e colar o aborto com a condição citada
expect: a sessão para e escala, citando qual das três condições disparou
guard:  o caminho feliz do C3/C4 não ganha passo novo
status: [ ] open
# F6 aplicado em skills/devflow-code/SKILL.md (C3 + C4, trio de aborto) em 2026-09-19.
#   Evidencia pendente: proof e MANUAL e exige um loop de correcao real (A-2).
#   INSTRUMENTO PRONTO != AC DEMONSTRADA. Nao marcar [x] sem colar a evidencia.
```

```po PO-6
slice:  C
ac:     ao parar num gate a resposta termina sem mais tool calls, e o agente nunca responde o próprio Y/N
proof:  MANUAL — provocar um STOP de modo e inspecionar o transcript
expect: nenhuma tool call após a linha de STOP; nenhuma auto-resposta a pergunta do operador
guard:  scripts/mode-gate.sh continua verde
status: [ ] open
# F7 aplicado em SKILL.md (MODE CONTROL RULE) em 2026-09-19. guard SATISFEITO:
#   mode-gate.test.sh 10/10 + --degraded 7/7 verdes. proof PENDENTE: e MANUAL e exige
#   provocar um STOP real e inspecionar o transcript num projeto consumidor (A-2).
#   INSTRUMENTO PRONTO != AC DEMONSTRADA. Nao marcar [x] sem colar o transcript.
```

```po PO-7
slice:  D
ac:     todo po de Tier 1+ declara boundary (o que não vale fazer para chegar lá)
proof:  rtk grep -c 'boundary:' plans/specs/001-ecc-absorption/spec.md
expect: contagem igual ao número de blocos po do slice corrente
guard:  blocos po legados sem boundary não invalidam (backfill oportunista)
status: [ ] open
```

```po PO-8
slice:  D
ac:     todo po declara a classe da evidência e o Pass 0 confronta com o proof
proof:  MANUAL — fechar uma PO com evidence static-read cujo proof prometia execução
expect: o Pass 0 rejeita por incompatibilidade de classe
guard:  POs com classe compatível continuam fechando normalmente
status: [ ] open
```

```po PO-9
slice:  D
ac:     um check que não pôde rodar fecha como [!] unavailable com motivo, em vez de mentir ou travar
proof:  MANUAL — rodar C4 sem acesso ao recurso do proof e colar o bloco
expect: status [!] com motivo; RC5 Pass 0 enxerga e reporta o gate desarmado
guard:  [!] nunca conta como [x] em nenhuma contagem de SC
status: [ ] open
```

```po PO-10
slice:  D
ac:     o C1.5/C4 tem onde registrar ignorância sem fabricar conteúdo
proof:  rtk grep -n 'uncertainty:' skills/devflow-code/SKILL.md
expect: o campo existe e a instrução proíbe inventar quando ele é aplicável
guard:  o limite de 3 marcadores [NEEDS CLARIFICATION] do S4 permanece
status: [ ] open
```

```po PO-11
slice:  E
ac:     toda spec nova traz Non-Goals com ao menos 2 itens e Invariants
proof:  MANUAL — criar uma spec Tier 1 de teste e inspecionar as seções
expect: ambas as seções presentes e específicas, não genéricas
guard:  Tier 0 continua sem spec
status: [ ] open
```

```po PO-12
slice:  E
ac:     o P2.5 exige file:line real ou a string NENHUM PADRÃO EXISTENTE
proof:  MANUAL — rodar P2.5 Tier 2 e colar a tabela
expect: nenhuma célula vazia; convenções inventadas rejeitadas
guard:  Tier 1 não é obrigado a P2.5
status: [ ] open
```

```po PO-13
slice:  E
ac:     RC5 Pass 1 aceita zero findings como resultado válido e exige prova para HIGH/CRITICAL
proof:  MANUAL — revisar um diff limpo e colar a saída
expect: Pre-Landing Review: No issues found, sem achados fabricados
guard:  a lista de Suppressions não é duplicada em lugar nenhum
status: [ ] open
```

```po PO-14
slice:  F1
ac:     ai-review.sh mantém saída byte-idêntica após a extração do @core
proof:  bash tests/ai-review-baseline.sh /tmp/before.txt  (antes) ; idem /tmp/after.txt (depois) ; diff
expect: diff vazio (exit 0)
guard:  a baseline é determinística — duas execuções seguidas produzem arquivos idênticos
evidence: reconciliation (execução real, saída colada)
status: [x] done
# evidencia 2026-09-19: diff before.txt after.txt -> "Files are identical" (exit 0), 14 linhas,
#   incluindo changed=3, tier=1, full-file attach 2/2 ~163B, preamble 395B,
#   "MEASURE: total payload across 1 chunk(s) = 1369B". Reconfirmado apos os ajustes de bash 3.2.
#   guard: 2 execucoes consecutivas da baseline -> "Files are identical".
#   shellcheck: nenhum achado NOVO de substancia — so SC1091 (source nao seguido estaticamente)
#   e SC2034 PASSB_TIMEOUT (agora consumido DENTRO do core; e o contrato documentado no cabecalho).
#
# NOTA DE METODO — o `proof:` original desta PO foi SUBSTITUIDO, e o motivo importa:
#   era `./scripts/ai-review.sh --dry-run > after.txt && diff before.txt after.txt`. Nao provava nada.
#   (a) --dry-run AINDA CHAMA O ENGINE (ai-review.sh:20) — saida de LLM nao e reproduzivel;
#   (b) este repo nao tem .js/.ts, entao o script saía em "No code changes" antes de montar
#       contexto: o diff daria VAZIO sempre, inclusive com o refactor quebrado. Gate que passa
#       por construcao e pior que gate nenhum.
#   Substituido por RC6_MEASURE=1 sobre um repo-fixture com diff real, que para antes do engine.
```

```po PO-15
slice:  F1
ac:     nenhuma função do @core é redefinida localmente em nenhum consumidor
proof:  bash tests/no-core-shadowing.test.sh
expect: zero redefinições encontradas
guard:  engine-core.sh declara versão e todo consumidor cita a que espera
evidence: execution (suite rodada, saida colada)
status: [x] done
# evidencia 2026-09-19: "3 passaram, 0 falharam" (exit=0).
#   core exporta 9 funcoes: ab_counts ab_total clamp_index clamp_lines engine_err_hint
#   log run_bounded run_engine unwrap_structured.
#   scripts/ai-review.sh cita ENGINE_CORE_EXPECTED="1.0.0"; zero redefinicoes.
#   guard: o teste FALHA se um consumidor der source sem citar versao — e a checagem 3a.
#
# ESCOPO HONESTO: hoje ha UM consumidor. O texto original dizia "ambos os consumidores"
#   supondo o second-opinion.sh, que so nasce no slice F2. O teste descobre consumidores por
#   grep (nao tem lista fixa), entao o segundo entra sob a mesma regra no dia em que existir.
```

```po PO-16
slice:  F2
ac:     second-opinion.sh avalia um plan.md em processo frio e devolve JSON no schema
proof:  ./scripts/second-opinion.sh --artifact plan --dry-run
expect: JSON válido contra o schema, sem nenhum caminho de PR exercitado
guard:  ./scripts/ai-review.sh --dry-run continua idêntico ao PO-14
status: [ ] open
```

```po PO-17
slice:  F2
ac:     o egress guard e o fail-open valem para o second-opinion sem duplicação de código
proof:  bash tests/second-opinion.test.sh --egress --failopen
expect: ambos os controles disparam a partir do @core
guard:  nenhuma cópia local de egress/fail-open no script novo
status: [ ] open
```

```po PO-18
slice:  F2
ac:     cada papel de cerimônia registra a posição própria antes de ler as demais
proof:  MANUAL — rodar RC1→RC3 e colar as três posições iniciais
expect: as posições estão datadas antes da síntese e divergem entre si quando cabe
guard:  a cerimônia continua parando no fim de cada RC (R-065)
status: [ ] open
```

```po PO-19
slice:  F2
ac:     C1.5 Tier 2 pode pedir segunda opinião independente sobre a análise
proof:  ./scripts/second-opinion.sh --artifact analysis --dry-run
expect: JSON com findings sobre a análise, contexto frio confirmado no cabeçalho
guard:  Tier 0 e Tier 1 não chamam o script
status: [ ] open
```

```po PO-20
slice:  G
ac:     existe uma comparação de formatos de handoff decidida pelo operador
proof:  MANUAL — apresentar a comparação e registrar a escolha
expect: os quatro formatos avaliados pelos três critérios; uma escolha registrada
guard:  nenhuma edição no C5 antes da escolha
status: [ ] open
```

```po PO-21
slice:  G
ac:     o C5 passa a exigir motivo exato da falha e demove o não-evidenciado
proof:  MANUAL — encerrar uma sessão com uma tentativa falha e colar o registro
expect: motivo exato presente; item sem evidência aparece como não-tentado
guard:  o journal e attempts.jsonl continuam append-only
status: [ ] open
```

```po PO-22
slice:  H
ac:     uma instrução nova é medida quanto a ser seguida sob prompt que não a apoia
proof:  MANUAL — rodar a medição nos três níveis de rigor e colar a taxa
expect: taxa de conformidade reportada por nível, incluindo o nível competing
guard:  a medição não altera nenhuma skill
status: [ ] open
```

```po PO-23
slice:  H
ac:     DEVFLOW-META.md passa a prever evidência de corpus externo com controles compensatórios
proof:  rtk grep -n 'proactive' DEVFLOW-META.md
expect: origin, assinatura de atrito prevista e sunset descritos
guard:  a barra reativa de 3+ observações / 2+ specs permanece intacta
status: [ ] open
```

---

## Achados colaterais (não previstos pela spec)

### AC-1 · `ai-review.sh` morre em repo sem `.agent/memory/ANTI_PATTERNS_INDEX.md`
Descoberto ao montar a baseline do F1. `emit_wiki_block` termina num `[ -f "$AP_IDX" ]` que
retorna 1 quando o arquivo não existe; a função é o elo esquerdo do pipeline que alimenta
`WIKI_BYTES="$(emit_wiki_block "" | wc -c | tr -d ' ')"`, e `set -o pipefail` + `set -e`
(linha 40) derrubam o script inteiro. Saída: exit 1 sem mensagem de erro.

**Por que nunca apareceu:** o consumidor real (dosiq) tem `.agent/`, e este repo sai antes, em
"No code changes". Dois acasos escondendo o mesmo defeito.

**Por que NÃO foi consertado no F1:** a PO-14 exige comportamento byte-idêntico antes e depois da
extração. Consertar um bug no mesmo slice destruiria a própria prova de equivalência — e um
refactor que muda comportamento "de leve" é exatamente o que a PO existe para impedir. O fixture da
baseline cria `.agent/memory/` (é o que um consumidor DEVFLOW tem) e o defeito fica registrado aqui.

**Decisão pendente do operador:** virar spec própria (Tier 0/1, ~3 linhas de conserto) ou entrar
como task do slice F2, que já mexe no fail-open. Recomendo spec própria — F2 tem escopo demais.

## Assumptions & Open Questions

- **A-1** O repo `devflow` seguirá sem `.agent/` por enquanto; esta spec vive em `plans/specs/`.
- **A-2** Os slices B–H exigem projeto consumidor real (dosiq) para POs MANUAL.
- **A-3** `1 slice = 1 PR` é regra que o DEVFLOW **impõe aos seus clientes**, não que ele obedeça a
  si mesmo (decisão do operador, 2026-09-19). Aqui o artefato é texto de skill e shell — não há
  codebase de runtime, logo não há blast radius de deploy que justifique um PR por slice. O épico
  inteiro vive em `spec/001-ecc-absorption`, um commit semântico por slice. **Não é mutação:** a
  tabela de Work Tiers permanece como está, e nenhuma proposta é emitida por causa disto.
- **[NEEDS CLARIFICATION]** O formato de handoff do slice G — decisão do operador no PO-20.
- ~~**[NEEDS CLARIFICATION]** Se `po_unstable` está morto~~ → **RESOLVIDO (T030, 2026-09-19): está VIVO.**
  Mora em `skills/devflow-distill/SKILL.md:42,47` — evento que o distill captura quando uma PO
  repete/falha, realimentando a escolha de tier. O slice D **não o absorve nem o mata**: integra.
  Um `status [!] unavailable` (F3) é justamente um sinal que o distill deveria contar ao lado do
  `po_unstable`, e essa ligação precisa entrar no draft.
- ~~**[NEEDS CLARIFICATION]**~~ → **RESOLVIDO (a).** **Colisão de nome em `evidence:`.** O campo JÁ
  EXISTE no núcleo (`SKILL.md:364`), restrito a Tier 2 regulado, e significa *"onde a linha de
  auditoria aparece na saída do proof"*. O FR-004 quer `evidence:` com outro sentido — a **classe**
  da prova (reconciled / executed / static-read / inferred). Dois sentidos sob um nome é o modo de
  falha que o Pass 0 não consegue auditar. Três saídas, decisão do operador:
    (a) **ESCOLHIDA pelo operador em 2026-09-19** — o campo novo chama-se `evidence_class:` e o
        `evidence:` regulado fica intacto;
    (b) `evidence:` passa a ser a classe (geral, todo tier) e o regulado vira `audit_evidence:`;
    (c) fundir num só campo com duas partes (`evidence: executed — linha 42 do output`).
  Recomendo **(a)**: não toca em nada que já funciona e não exige backfill de bloco regulado.
