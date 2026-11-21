# Relatório de Benchmark — `agy` 1.5.13, Chunking e Effort Level no RC6 (`devflow` / `dosiq`)

**Escopo e integridade:** medições empíricas executadas sobre `agy` `1.5.13` com caso real do PR #971 (`dosiq`, commit base `a1569160`, diff `38cba08d` vs `248ff9d9`), sem mutações em `/Users/coelhotv/SKILLS/devflow`, `/Users/coelhotv/git/dosiq` ou `/Users/coelhotv/git/dosiq-moat`, e com zero chamadas ao `claude` (`RC6_ENGINE_CLAUDE=0`). Passo 5 (concorrência) foi pulado por decisão do operador.

---

## 1. Veredito Executivo

1. **Chunking em `~150KB` (`CTX_BUDGET=150000`) continua obrigatório no `agy` `1.5.13`.** Tanto via `argv` (`-p`) quanto via `stdin` (`--input-format stream-json`), o `agy` impõe um teto rígido de `~79.6K` `input_tokens` no Turn 1 (`~57.9K` tokens de prompt do usuário + `~21.5K–21.7K` tokens base de CLI/tool-schemas). Acima desse limite (já visível em `200KB` com `2/3` agulhas recuperadas), o CLI retorna `rc=0` e `status=SUCCESS`, porém **trunca silenciosamente a cauda do prompt** — exatamente onde o RC6 posiciona os diffs.
2. **Modelo, effort e transporte não rompem a parede de `~79.6K` no Turn 1.** `gemini-4-neon-low`, `gemini-4-neon-medium`, `gemini-4-neon-high`, `gemini-4-argon-medium` e `gemini-4-hydrogen-medium` tiveram exatamente a mesma perda de cauda em `250KB` (`2/3`). O modo `--input-format stream-json` resolve o limite `ARG_MAX` do sistema operacional (`1,048,576 B`), mas sofre o mesmo corte em `1,199,992 B` (`in=79,627`, `1/3`).
3. **Implicit prefix caching entre execuções e multi-turno em única sessão não reduzem esse custo hoje.** Duas chamadas independentes de `~143KB` compartilhando um prefixo byte-idêntico de `102,952 B` (`100,740` chars) registraram `cache_read_tokens=0`. Encadear chunks em sessão multi-turno estouraria o contexto já no segundo turno e ficaria exposto à issue aberta `#1166` (reuso de `structured_output` anterior em follow-ups).
4. **Effort level em `gemini-4-neon` governa diretamente o recall sem aumentar o prefill do Turn 1.** No mini-bench com `select-rules.mjs` ativo (`K_slot` + `K_hook`, `~148KB` cada, todos com `cache_read_tokens` entre `63,812` e `64,571`):
   - `low`: `1/9` (`11%`) em `118.4s` acumulados nos 2 chunks — custo de prefill idêntico com perda severa de qualidade.
   - `medium`: `5/9` (`56%`) em `280.2s` — equilíbrio adequado para Pass A rotineiro.
   - `high`: `9/9` (`100%`, `0` falsos positivos) em `585.7s` — igualou os achados críticos/médios/baixos do Pass B original com Claude (`F7` + `R-254`), mas atingiu `314.09s` em 1 chunk, aproximando-se do `AGY_TIMEOUT=8m` (`480s`).
5. **Preâmbulo (`~102KB`) exige poda inteligente, nunca remoção cega de índices.** Remover índices sem compensação (`C3`, `RC6_INDEXES=0`) zerou o recall (`0` findings), concentrando código demais por chunk e perdendo ancoragem. Já manter [`select-rules.mjs`](file:///Users/coelhotv/git/dosiq/scripts/select-rules.mjs) operacional mostrou-se determinante para capturar regras de domínio como `AP-365` (`F4`) em todos os níveis de esforço.

---

## 2. Inventário da Arquitetura de QA Externo (`devflow`)

A camada de invocação é centralizada na biblioteca [`engine-core.sh`](file:///Users/coelhotv/SKILLS/devflow/scripts/lib/engine-core.sh) (`ENGINE_CORE_VERSION="1.2.0"`, 534 linhas), consumida por três scripts que exigem `ENGINE_CORE_EXPECTED="1.2.0"`:

| Componente | Arquivo | Padrões / Parâmetros Verificados | Observações de Código |
|---|---|---|---|
| Core compartilhado | [`engine-core.sh`](file:///Users/coelhotv/SKILLS/devflow/scripts/lib/engine-core.sh) | `RC6_AGY_MODEL_FALLBACK=gemini-4-hydrogen-medium` ([L501](file:///Users/coelhotv/SKILLS/devflow/scripts/lib/engine-core.sh#L501)) | `build_engine_args` ([L303](file:///Users/coelhotv/SKILLS/devflow/scripts/lib/engine-core.sh#L303)) sem `--mode plan` (removido no commit `1249ecd`; nota em [L84-L88](file:///Users/coelhotv/SKILLS/devflow/scripts/lib/engine-core.sh#L84-L88)); accounting de `usage` em [L174-L185](file:///Users/coelhotv/SKILLS/devflow/scripts/lib/engine-core.sh#L174-L185); `run_bounded`, `unwrap_structured`, `egress_guard`, `fail_open`. |
| Review principal (RC6) | [`ai-review.sh`](file:///Users/coelhotv/SKILLS/devflow/scripts/ai-review.sh) | `CTX_BUDGET=150000`, `CTX_TOTAL_MAX=150000`, `IDX_LINE_MAX=80`, `RC6_MAX_CHUNKS=6`, `RC6_INDEXES=1`, `PACK_FILTER=auto`, `RC6_AGY_MODEL=gemini-4-neon-medium`, `AGY_TIMEOUT=8m`, `PASSB_TIMEOUT=480` | Constantes de tier/fullfile em [L62-L66](file:///Users/coelhotv/SKILLS/devflow/scripts/ai-review.sh#L62-L66) (`MAX_FULLFILE_LINES=20`, `TIER2_FILE_THRESHOLD=8`, `MAX_FULLFILES=14`), globs em [L70-L74](file:///Users/coelhotv/SKILLS/devflow/scripts/ai-review.sh#L70-L74), budgets em [L270-L285](file:///Users/coelhotv/SKILLS/devflow/scripts/ai-review.sh#L270-L285) e [L646-L693](file:///Users/coelhotv/SKILLS/devflow/scripts/ai-review.sh#L646-L693). Em `build_prompt` ([L938-L940](file:///Users/coelhotv/SKILLS/devflow/scripts/ai-review.sh#L938-L940), [L1155-L1156](file:///Users/coelhotv/SKILLS/devflow/scripts/ai-review.sh#L1155-L1156)), `$EXTRA` antecede `$ctx`. |
| Segunda opinião | [`second-opinion.sh`](file:///Users/coelhotv/SKILLS/devflow/scripts/second-opinion.sh) | `gemini-4-neon-medium`, `agy` -> `claude` fallback | 218 linhas; execução sem chunking. |
| Conformidade de skill | [`skill-comply.sh`](file:///Users/coelhotv/SKILLS/devflow/scripts/skill-comply.sh) | `gemini-4-neon-medium`, `agy` -> `claude` fallback | 164 linhas; execução sem chunking. |
| Utilitários de apoio | [`rank_chunks.py`](file:///Users/coelhotv/SKILLS/devflow/scripts/rank_chunks.py), [`reflect-gate.sh`](file:///Users/coelhotv/SKILLS/devflow/scripts/reflect-gate.sh) | Ranking de chunks (42L) e gate pós-review (120L) | Ordenação de risco usada para selecionar chunks prioritários dentro do teto `RC6_MAX_CHUNKS`. |
| Documentação & skills | [`devflow-code/SKILL.md`](file:///Users/coelhotv/SKILLS/devflow/skills/devflow-code/SKILL.md#L948), [`devflow-ceremony/SKILL.md`](file:///Users/coelhotv/SKILLS/devflow/skills/devflow-ceremony/SKILL.md#L250-L310), [`README.md`](file:///Users/coelhotv/SKILLS/devflow/README.md#L195-L250) | Documentação do fluxo RC6 e modelos | [`devflow-code/SKILL.md`](file:///Users/coelhotv/SKILLS/devflow/skills/devflow-code/SKILL.md#L948) ainda referencia `Primary: agy -p (Gemini 3.8 Flash)`, desatualizado em relação ao padrão `gemini-4-neon-medium` do código. |

---

## 3. Evidências Empíricas (Fases 0 a 4C)

### 3.1 Fase 0 — Inventário do PR #971 e `RC6_MEASURE=1` (0 chamadas LLM)

Fontes: [`pr971_view.json`](file:///Users/coelhotv/.gemini/antigravity/brain/29baf5d0-07fe-43c3-a590-4b3eb76f06e9/scratch/agy-bench/phase0/pr971_view.json), [`measure.log`](file:///Users/coelhotv/.gemini/antigravity/brain/29baf5d0-07fe-43c3-a590-4b3eb76f06e9/scratch/agy-bench/phase0/measure.log).

- **PR #971 (`38cba08d` vs `248ff9d9`):** 48 arquivos (`+3162/-117`), sendo 46 `CODE_GLOBS` (`207,310 B` de diff de código; `230,363 B` total), `0` `RISK_UNREVIEWED_GLOBS` e 2 arquivos `.md`.
- **Baseline histórico validado no commit `a1569160` (`agy+claude (7 chunks)`, `RC6_MAX_CHUNKS=7`):** 7 findings:
  - `F1`: `ConfiraSheet.tsx:47` (high, `R-107|R-109|AP-222`)
  - `F2`: `TodaySetupSlot.tsx:44` (med, `none`)
  - `F3`: `TodaySetupSlot.tsx:123` (med, `R-273`)
  - `F4`: `useTodaySetup.ts:142` (med, `AP-365`)
  - `F5`: `TodayScreen.tsx:535` (low, `R-326`)
  - `F6`: `treatmentSetup.ts:760` (low, `R-254` — originalmente apenas Pass B Claude)
  - `F7`: `TodaySetupSlot.tsx:71` (low, `R-299` — originalmente apenas Pass B Claude)
- **Composição do preâmbulo (`IDX_LINE_MAX=80`):** `CLAUDE.md` (`14,440 B`) + `seletor` (`10,168 B`, 4 memórias) + `wiki` (`54,599 B`) + `detail` (`23,196 B`) = `PRE_BYTES` de **`102,403 B`** (`reconciliacao: 0B`, ~73% de um chunk de `150KB`), restando `CHUNK_BUDGET=39,597 B`.

| Configuração (`RC6_MEASURE=1`) | Chunks | Fullfiles | Payload Total | Observação |
|---|---|---|---|---|
| Default (`150KB`, `RC6_MAX_CHUNKS=6`) | 6/7 enviados | — | `822,731 B` | Chunk `3/7` (5 arquivos) descartado pelo limite de 6 chunks |
| 1 chunk (`1MB`, cap padrão de fullfiles) | 1 | 14/40 | `344,317 B` | -58% em bytes totais (elimina replicação do preâmbulo) |
| 1 chunk (`1MB`, todos os fullfiles) | 1 | 40/40 | `682,732 B` | Inviável no `agy` pelo teto de `~79.6K` tokens (Fase 2) |
| 1 chunk (`IDX_LINE_MAX=300`, `PACK_FILTER=0`) | 1 | 14/40 | `448,193 B` | `PRE_BYTES=206,279 B` (`wiki=158,475 B`); com 40/40 sobe para `786,608 B` |

### 3.2 Fase 1 — Validação de Flags, Permissões e Transporte

Fonte: [`results.json` (Fase 1)](file:///Users/coelhotv/.gemini/antigravity/brain/29baf5d0-07fe-43c3-a590-4b3eb76f06e9/scratch/agy-bench/phase1/results.json).

| Caso | Configuração Testada | `rc` | Duração (`dur`) | Tokens (`in` / `out` / `think` / `cache`) | Resultado Observado |
|---|---|---|---|---|---|
| `T1.1` | `--mode plan` + `--disable-slash-commands` | `0` | `32.14s` (`24.50s`) | `21,897` / `760` / `700` / `17,101` | `SUCCESS`, `num_turns=2`, `created=[]`. Stderr: `warning: --mode plan has no effect while slash command expansion is disabled.` Valida a remoção feita no `devflow` (`1249ecd`). |
| `T1.2` | `--settings deny_settings.json` | `0` | `32.43s` (`19.61s`) | `21,559` / `740` / `610` / `16,689` | `SUCCESS`, `num_turns=1`, `created=[]`, `file_created=false`. Evidencia overhead fixo base de `~21.5K` `input_tokens` de CLI/tool-schemas. |
| `T1.3` | `--effort low` + `--model gemini-4-neon-medium` | `1` | `6.94s` | — | `ERROR`: `--model gemini-4-neon-medium conflicts with --effort=low`. O esforço deve ir no sufixo do modelo. |
| `T1.4a` | `--print` recebendo texto via stdin | `2` | `0.07s` | — | `flag needs an argument: -print`. |
| `T1.4b_v1` | `stream-json` com `{"type":"user",...}` | `1` | `8.01s` | — | Evento `init` revelou `"permission_mode":"request-review"` e ~60 tools (`write_to_file`, `replace_file_content`, `multi_replace_file_content`, `sed_file`, `run_command`, etc.); erro `stream input message is missing the "event" field`. |
| `T1.4b_v2` | `stream-json` com `{"event":"user_message","text":...}` | `0` | `8.22s` | — | `warning: ignoring unsupported stream input message event "user_message"`. |
| `T1.5a` | Prompt de `1,099,985 B` via `-p` (`ARG_MAX=1,048,576 B`) | `-1` | `0.01s` | — | Falha no SO: `[Errno 7] Argument list too long: 'agy'`. |

### 3.3 Fase 2 — Curva *Needle-at-the-End* e Transporte `stream-json`

Fontes: [`results.json` (Fase 2)](file:///Users/coelhotv/.gemini/antigravity/brain/29baf5d0-07fe-43c3-a590-4b3eb76f06e9/scratch/agy-bench/phase2/results.json), [`stream_results.json`](file:///Users/coelhotv/.gemini/antigravity/brain/29baf5d0-07fe-43c3-a590-4b3eb76f06e9/scratch/agy-bench/phase2/stream_results.json) e [pesquisa do subagente sobre `stream-json`](file:///Users/coelhotv/.gemini/antigravity/brain/41e58e27-af17-4eb2-924e-2436cb24dc9b/.system_generated/logs/transcript.jsonl).

| Caso | Transporte | Bytes de Prompt | `rc` / Status | Latência | `input_tokens` | `delta` vs base | `bpt` | `out` / `think` / `cache` | Agulhas |
|---|---|---|---|---|---|---|---|---|---|
| `150KB` | `argv` (`-p`) | `149,896 B` | `0` / `SUCCESS` | `31.08s` | `65,192` | `43,492` | `3.45` | `1,089` / `1,018` / `0` | `3/3` (`T/T/T`) |
| `200KB` | `argv` (`-p`) | `199,995 B` | `0` / `SUCCESS` | `29.46s` | `79,636` | `57,936` | `3.45` | `1,262` / `1,200` / `0` | `2/3` (`T/T/F`) |
| `250KB` | `argv` (`-p`) | `249,912 B` | `0` / `SUCCESS` | `29.51s` | `79,642` | `57,942` | `4.31` | `1,026` / `964` / `0` | `2/3` (`T/T/F`) |
| `400KB` | `argv` (`-p`) | `399,989 B` | `0` / `SUCCESS` | `28.20s` | `79,623` | `57,923` | `6.91` | `1,166` / `1,113` / `0` | `1/3` (`T/F/F`) |
| `T2_stream_smoke` | `stdin:stream-json` | `241 B` | `0` / `SUCCESS` | `24.82s` | `21,246` | — | — | `476` / `366` / `16,724` | `3/3` (10 eventos) |
| `T2_1200KB` | `stdin:stream-json` | `1,199,992 B` (`1,228,085 B` NDJSON) | `0` / `SUCCESS` | `33.48s` | `79,627` | — | — | `970` / `916` / `0` | `1/3` (`T/F/F`, 5 eventos) |

**Notas do protocolo `stream-json`:** a documentação oficial (`antigravity.google/docs/cli/headless/#stream-prompts-from-stdin`) utiliza `{"event":"user","message":{"content":...}}`. Nessa interface, `usage` é cumulativo ao longo de uma sessão multi-turno, e há issues abertas relevantes para automação: `#1166` (reaproveitamento do `structured_output` anterior em turnos follow-up de texto simples) e `#794`/`#1065` (`denied_actions`).

### 3.4 Fase 4A — Mini-sonda de Modelos/Effort e Prefix Caching

Fonte: [`results.json` (Fase 4A)](file:///Users/coelhotv/.gemini/antigravity/brain/29baf5d0-07fe-43c3-a590-4b3eb76f06e9/scratch/agy-bench/phase4a/results.json).

**Sonda de teto por modelo/effort (`249,912 B`):**

| Modelo | `input_tokens` | `cache_read` | `out` / `think` | `num_turns` | Latência (`dur`) | Agulhas |
|---|---|---|---|---|---|---|
| `gemini-4-neon-low` | `79,638` | `0` | `750` / `688` | — | `29.81s` (`22.33s`) | `2/3` |
| `gemini-4-neon-high` | `79,647` | `0` | `1,532` / `1,470` | — | `32.95s` (`25.44s`) | `2/3` |
| `gemini-4-argon-medium` | `79,635` | `0` | `332` / `267` | — | `27.49s` (`17.87s`) | `2/3` |
| `gemini-4-hydrogen-medium` | `83,324` | `78,286` | `949` / `817` | `2` | `25.26s` (`18.24s`) | `2/3` |

**Sonda de implicit prefix caching (`gemini-4-neon-medium`, prefixo byte-idêntico de `102,952 B` / `100,740` chars):**

| Chamada | Tamanho Total | Latência | `input_tokens` | `cache_read_tokens` | `out` | Agulhas |
|---|---|---|---|---|---|---|
| `b2_cache_call1` | `143,021 B` | `34.87s` | `62,997` | `0` | `1,210` | `3/3` |
| `b2_cache_call2` | `143,025 B` | `25.92s` | `64,255` | `0` | `595` | `3/3` |

Não houve aproveitamento de cache implícito entre chamadas independentes no CLI.

### 3.5 Fase 4B — Benchmark no Worktree `a1569160` (`--dry-run --tier1`, `RC6_MAX_CHUNKS=8`)

Fontes: [`summary.json` (Fase 4B)](file:///Users/coelhotv/.gemini/antigravity/brain/29baf5d0-07fe-43c3-a590-4b3eb76f06e9/scratch/agy-bench/phase4b/summary.json), [`measure_a1569160.log`](file:///Users/coelhotv/.gemini/antigravity/brain/29baf5d0-07fe-43c3-a590-4b3eb76f06e9/scratch/agy-bench/phase4b/measure_a1569160.log).

> [!WARNING]
> Neste worktree temporário isolado sem `node_modules`, o script [`select-rules.mjs`](file:///Users/coelhotv/git/dosiq/scripts/select-rules.mjs) falhou na importação de `js-yaml` e entrou em **fail-open** silencioso, não injetando as 4 memórias de domínio (`10,168 B`). Os resultados comparam `C1`, `C2` e `C3` sob essa condição idêntica entre si.

| Cenário | Config | Chunks | Bytes Totais | Latência Total | `sum_in` | `max_in` | `sum_cache` | `sum_out` | Findings (distribuição) |
|---|---|---|---|---|---|---|---|---|---|
| `C1_baseline` | `PACK_FILTER=auto` | `6/6` | `796,621 B` | `672.60s` | `455,058` | `81,041` (chunk 3) | `397,926` | `60,621` | `8` (`0/2/3/3`): `F1`, `F2` (low), `F5`, +5 extras (`useTodaySetup:167`, `useTodaySetup:80` `R-187\|AP-213`, `setupCopy:139`, `treatmentSetup:677`, `TodaySetupSlot:32`) |
| `C2_pack_filter` | `PACK_FILTER=1` | `6/6` | `689,648 B` | `644.47s` | `425,205` (-6.6%) | `75,835` | `364,481` | `63,008` | `5` (`0/1/3/1`): `F1`, +4 extras (`useTodaySetup:80`, `setupCopy:139`, `TodaySetupSlot:32`, `TodaySetupSlot:101`) |
| `C3_no_indexes` | `RC6_INDEXES=0` | `3/3` | `353,695 B` | `369.07s` | `289,016` (-36.5%) | `147,445` (chunk 1 `cache=0`; chunk 2 `83,782`, `cache=69,997`; chunk 3 `57,789`, `cache=49,365`) | `119,362` | `34,271` | `0` (`0/0/0/0`) |

**Leitura técnica:** `PACK_FILTER=auto` não é ativado abaixo do teto de `150KB`, e forçá-lo (`C2`) reduziu apenas `6.6%` dos `input_tokens` enquanto derrubou achados (`F2`, `F5` perdidos). Cortar todos os índices (`C3`) condensou o PR em 3 chunks pesados de código sem ancoragem de regras e zerou os achados (`0/0/0/0`).

### 3.6 Fase 4C — Mini-bench de Effort Level com `select-rules.mjs` Ativo

Fontes: [`summary.json` (Fase 4C)](file:///Users/coelhotv/.gemini/antigravity/brain/29baf5d0-07fe-43c3-a590-4b3eb76f06e9/scratch/agy-bench/phase4c/summary.json), [`capture.stderr.log`](file:///Users/coelhotv/.gemini/antigravity/brain/29baf5d0-07fe-43c3-a590-4b3eb76f06e9/scratch/agy-bench/phase4c/capture.stderr.log).

Prompts exatos capturados de `a1569160` com symlink para `node_modules` (`select-rules.mjs`: `4 memória(s), 10168B`, `PRE_BYTES=103,181 B`, 7 chunks no PR). Avaliados os 2 chunks mais densos: `K_slot` (`chunk_02.prompt.txt`, `148,255 B`) e `K_hook` (`chunk_04.prompt.txt`, `147,592 B`), 6 execuções sequenciais, todas `rc=0`, `SUCCESS`, `num_turns=2`:

| Modelo | Chunk | `t_wall` (`t_dur`) | `in` | `cache_read` | `out` | `think` | Findings Capturados | Recall Consolidado |
|---|---|---|---|---|---|---|---|---|
| `gemini-4-neon-low` | `K_slot` | `50.72s` (`42.47s`) | `66,990` | `64,571` | `2,442` | `2,263` | `0` | **`1/9` (`11%`)** / `118.4s` |
| `gemini-4-neon-low` | `K_hook` | `67.67s` (`60.11s`) | `68,434` | `63,816` | `5,085` | `4,050` | `1`: `F4` (`AP-365`) | — |
| `gemini-4-neon-medium` | `K_slot` | `148.26s` (`141.14s`) | `77,871` | `64,569` | `14,210` | `12,362` | `3`: `F3` (`R-273`), `F2`, `TodaySetupSlot:95` | **`5/9` (`56%`)** / `280.2s` |
| `gemini-4-neon-medium` | `K_hook` | `131.92s` (`124.67s`) | `77,013` | `63,820` | `13,931` | `12,395` | `2`: `F4` (`AP-365`), `F5` | — |
| `gemini-4-neon-high` | `K_slot` | `271.58s` (`264.38s`) | `94,661` | `64,559` | `31,978` | `28,611` | `5`: `F7` (`R-277` high), `F3` (`R-273`), `F2`, `TodaySetupSlot:95`, `TodaySetupSlot:32` | **`9/9` (`100%`, `0` FPs)** / `585.7s` |
| `gemini-4-neon-high` | `K_hook` | `314.09s` (`306.75s`) | `97,785` | `63,812` | `35,775` | `32,218` | `4`: `useTodaySetup:167`, `F4` (`AP-365`), `F5` (`R-326`), `TodayScreen:657` (`R-254`) | — |

**Dois comportamentos críticos revelados na Fase 4C:**
1. **Explicação de `in=94,661` / `97,785` sem violar a parede de `~79.6K`:** em chamadas de code review (`num_turns=2`), `usage.input_tokens` soma os tokens de entrada do Turn 1 + Turn 2. O Turn 2 relê o prefixo em cache (`cache_read_tokens` de `64,559` e `63,812`) somado ao raciocínio/saída do Turn 1 para emitir o JSON estruturado. Portanto, o payload original do chunk nunca encostou nos `~79.6K` do Turn 1 — o excedente veio da re-leitura de ~`28.6K–32.2K` `thinking_tokens` do Turn 1 no Turn 2.
2. **Impacto causal do seletor de regras:** diferentemente da Fase 4B (fail-open sem `js-yaml`), com [`select-rules.mjs`](file:///Users/coelhotv/git/dosiq/scripts/select-rules.mjs) ativo o achado `F4` (`useTodaySetup.ts:142`, `AP-365`) foi detectado nos três níveis (`low`, `medium`, `high`).

---

## 4. Avaliação das Specs de Contexto/QA no `dosiq-moat`

Base lida: [`README.md`](file:///Users/coelhotv/git/dosiq-moat/plans/specs/README.md) (`034`, `056`, `058`, `060`, `078`, `079`, `080` marcadas como `delivered`; `081` marcada como `superseded`). Avaliação das specs em `draft`:

| Spec | Dados Verificados no Repositório | Parecer Técnico Cruzado com o Benchmark |
|---|---|---|
| [`087-spike-jev/spec.md`](file:///Users/coelhotv/git/dosiq-moat/plans/specs/087-spike-jev/spec.md) (`draft`) | Referência System One a US\$0.042/M input; avaliação do seletor léxico com `recall@5=2/6` e `recall@60=5/6`; `ADR-097` propondo corte de `339 -> 232` regras (`152` via `detail` e `38` [`16%`] via seletor). | **Alta sinergia com o gargalo real.** Hoje o preâmbulo consome `102,403 B` (`wiki=54,599 B`, `detail=23,196 B`, `CLAUDE.md=14,440 B`, `seletor=10,168 B`), deixando apenas `39,597 B` de `CHUNK_BUDGET`. Cortar regras ociosas libera orçamento de código sem quebrar o teto de `~79.6K`. Atenção: dados os `100%` obtidos pelo `neon-high` em `K_slot`/`K_hook` e a falha observada em `select-rules.mjs` sem `js-yaml`, o ganho imediato está em aumentar a precisão/recall do seletor (hoje `2/6` em top-5) e reduzir `wiki`/`detail` antes de introduzir outro modelo no loop. |
| [`075-graftroom-benchmark/spec.md`](file:///Users/coelhotv/git/dosiq-moat/plans/specs/075-graftroom-benchmark/spec.md) & [`measurement.md`](file:///Users/coelhotv/git/dosiq-moat/plans/specs/075-graftroom-benchmark/measurement.md) (`draft`) | Seções A e C com `0` amostras; uso ad-hoc por `grep` em ~1% vs `grep -rn`; Seção B com **miss-to-ZERO** em JSX (`LogFormInjectionSiteSection` / `InjectionSitePicker`) e constante exportada (`ALARM_CRITICAL_CHANNEL_ID`); Seção D com `1/2` hit. | **Não pronta para compor contexto de QA do RC6.** Em código React Native / TypeScript (como `ConfiraSheet.tsx`, `TodaySetupSlot.tsx`, `TodayScreen.tsx`), falhar em componentes JSX e constantes exportadas comprometeria exatamente os arquivos críticos de UI. Completar A e C e sanar a indexação JSX antes de adotá-la como fonte primária de contexto. |
| [`089-spec-drift-detection/spec.md`](file:///Users/coelhotv/git/dosiq-moat/plans/specs/089-spec-drift-detection/spec.md) (`draft`) | ~`1,295` citações de código entre specs pendentes; Layer 2 projetada sobre `graftroom blast`. | **Separar entregáveis.** A Layer 1 determinística (validação direta de existência de caminhos/símbolos citados em disco) pode avançar imediatamente de forma independente; a Layer 2 deve permanecer condicionada ao desbloqueio da spec `075` (indexação confiável de JSX e constantes exportadas). |

---

## 5. Recomendações Priorizadas

### P0 — `devflow` (sem alterações já aplicadas nesta rodada)

1. **Preservar chunking em `<=150KB` (`CTX_BUDGET=150000`, `CTX_TOTAL_MAX=150000`):** não tentar escalar chunks via `stream-json` nem por modelo/effort alternativo enquanto a parede de `~79.6K` tokens no Turn 1 existir no `agy`.
2. **Proteger a ordem do prompt em `build_prompt` ([`ai-review.sh`](file:///Users/coelhotv/SKILLS/devflow/scripts/ai-review.sh#L938-L940)):** hoje `$EXTRA` vai antes de `$ctx` (deixando o diff na cauda, onde ocorre o corte silencioso). Garantir orçamento rígido pré-invocação e considerar priorizar metadados fixos + diff antes de blocos expansíveis quando próximo do limite.
3. **Corrigir heurística de truncamento para `num_turns >= 2` em [`engine-core.sh`](file:///Users/coelhotv/SKILLS/devflow/scripts/lib/engine-core.sh):** nunca disparar alarme de teto apenas com `usage.input_tokens >= 78500`, porque em `neon-high` (`num_turns=2`) `usage.input_tokens` acumula ambos os turnos (`94,661` / `97,785`). Para `num_turns >= 2`, monitorar `cache_read_tokens` próximo de `~79.6K` (proxy do prompt do Turn 1); quando `num_turns == 1`, usar `input_tokens` diretamente.
4. **Calibrar estratégia de Effort, Timeout e `RC6_MAX_CHUNKS` em [`ai-review.sh`](file:///Users/coelhotv/SKILLS/devflow/scripts/ai-review.sh):**
   - Manter `gemini-4-neon-medium` no Pass A rotineiro; **não** baixar para `low` (`11%` no mini-bench pelo mesmo prefill).
   - Quando rodar sem Claude (`RC6_ENGINE_CLAUDE=0`), adotar `gemini-4-neon-high` no Pass B ou nos top chunks ordenados por [`rank_chunks.py`](file:///Users/coelhotv/SKILLS/devflow/scripts/rank_chunks.py), ajustando `AGY_TIMEOUT` (hoje `8m` = `480s`) com margem confortável acima dos `314.09s` observados em chunk único isolado.
   - Revisar `RC6_MAX_CHUNKS=6`: no PR #971 o limite `6` descartou o chunk `3/7` (5 arquivos). Considerar aumentar para `>=7–8` em PRs desse porte ou documentar o corte explícito no resumo do review.
5. **Atualizar [`devflow-code/SKILL.md`](file:///Users/coelhotv/SKILLS/devflow/skills/devflow-code/SKILL.md#L948):** substituir a referência legada `Gemini 3.8 Flash` por `gemini-4-neon-medium` (e fallback `gemini-4-hydrogen-medium`), além de registrar que `--mode plan` é no-op com `--disable-slash-commands` e `--effort` conflita com sufixos de modelo no `agy 1.5.13`.

### P1 — `dosiq-moat` e integração `dosiq`

1. **Remover fail-open silencioso de [`select-rules.mjs`](file:///Users/coelhotv/git/dosiq/scripts/select-rules.mjs):** em reviews executados a partir de worktrees isolados sem `node_modules`, resolver `js-yaml` de forma resiliente ou sinalizar no output do preâmbulo que o seletor falhou (evitando repetir a perda de cobertura vista na Fase 4B).
2. **Priorizar poda de `wiki`/`detail` e calibração do seletor (`087-spike-jev`):** reduzir os `102,403 B` atuais de preâmbulo eleva o espaço útil por chunk dentro dos `150KB` existentes.
3. **Condicionar Layer 2 de `089` ao fechamento de `075`:** executar medições faltantes A/C e corrigir miss-to-ZERO de JSX/constantes antes de acoplar `graftroom blast` à detecção de drift ou ao QA.

---

## 6. Limitações e Escopo Não-Medido

- **Concorrência (Passo 5 pulado por decisão do operador):** não foram medidas contenção, latência agregada ou rate limits com 2–3 chamadas `agy` paralelas (relevante se Pass A paralelizar chunks, especialmente com `high` perto de `314s`).
- **`gemini-4-neon-xhigh` não testado** neste ciclo.
- **Fase 4C com amostra focal (`2` chunks, `1` execução por célula):** o mini-bench comparou `low`/`medium`/`high` nos chunks `K_slot` e `K_hook` do PR #971 (6 chamadas ao todo); não mede variância estocástica multi-seed nem generalização entre múltiplos PRs distintos.
- **Fase 4B sob fail-open do seletor:** os cenários `C1`, `C2` e `C3` rodaram no worktree temporário sem `js-yaml`, o que explica a ausência das memórias do seletor em todos os três cenários comparados naquela fase.
