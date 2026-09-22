# 001 · Slice F2 — Artifact Coverage Analysis (C1.5)

**Data:** 2026-09-22 · **Tier:** 2 · **Escopo:** `scripts/second-opinion.sh` (novo),
`scripts/lib/engine-core.sh`, `scripts/ai-review.sh`, `tests/`. T062/T063 (prosa de skill) ficam
fora deste C1.5: passam pelo gate INV-4 e ganham leitura própria quando forem abertos.
**Veredito:** **PASS com riscos MEDIUM** (listados no §4). Nenhum bloqueio.

## Decisões do operador que moldam o slice (2026-09-22)

- **D-1 · Proof sem LLM.** `second-opinion.sh` não tem efeito colateral (não há PR), logo não
  tem `--dry-run`. `--measure` para ANTES do engine (espelha `RC6_MEASURE`). O teste põe um
  `agy` falso no PATH que devolve envelope enlatado: exercita `unwrap_structured` + schema de
  ponta a ponta, deterministicamente. Os `proof:` da PO-16 e da PO-19 são reescritos com nota.
- **D-2 · Extração ampla.** Sobem para o core: egress guard, fail-open **e** probe de capacidade
  + montagem de `AGY_ARGS`/`CLAUDE_ARGS`. Motivo: o probe feature-detecta flags de SEGURANÇA
  (`--disable-slash-commands`, `--tools ""`); cópia divergente disso é o pior drift possível, e o
  `no-core-shadowing` não o pegaria (é bloco inline, não função). Core `1.0.0 → 1.1.0`.
- **D-3 · Este C1.5 existe.** Dogfood do slice B. **Não fecha PO-4** (A-2: repo não é consumidor).

## 1. Tabela de evidência (lida NESTA sessão)

| Afirmação do plano | Evidência no disco | Status |
|---|---|---|
| O core não tem egress nem fail-open | `engine-core.sh:8-20` lista 9 funções; nenhuma é egress/fail-open | ✅ confirma o gap da PO-17 |
| Egress mora inline no consumidor | `ai-review.sh:162-175` (regex PII sobre linhas `^\+`, override `RC6_ALLOW_SENSITIVE`, `exit 3`) | ✅ |
| Fail-open mora inline | `ai-review.sh:1234-1238` (`OUTS` vazio ⇒ JSON de aviso, `exit 0`) | ✅ |
| Probe de engine é local | `ai-review.sh:92-118` (`HAVE_*`, `*_SCHEMA`, `*_NOSLASH`, `CLAUDE_NOPERSIST`) | ✅ |
| Argv de engine é local, core só lê | `ai-review.sh:940-954`; contrato em `engine-core.sh:22-26` | ✅ |
| Schema de review é de domínio (fica no consumidor) | `ai-review.sh:909-938`; `engine-core.sh:18-19` diz que schema NÃO mora no core | ✅ — o second-opinion define o SEU schema |
| `unwrap_structured` exige chave `findings` | `engine-core.sh:141` | ✅ — schema novo precisa de `findings` |
| MEASURE para depois do probe/args, antes do engine | `ai-review.sh:966` | ✅ — o probe roda na baseline, mas em silêncio |
| `no-core-shadowing` acha consumidor novo sozinho | `tests/no-core-shadowing.test.sh:35` (grep por `lib/engine-core.sh`) | ✅ |
| Artefato `analysis` tem arquivo | `skills/devflow-code/SKILL.md:170-172` (`analysis.md` / `analysis-<slice>.md`) | ✅ — adaptador recebe caminho |

## 2. Cobertura da baseline — o risco que este C1.5 existe para achar

`tests/ai-review-baseline.sh` é determinística (2 execuções, `Files are identical`, 14 linhas), mas
**não exercita nenhum dos três blocos que vão mudar de lugar**:

| Bloco extraído | A baseline passa por ele? | Por quê |
|---|---|---|
| egress guard | sim, **mas pelo ramo silencioso** | fixture sem PII: o ramo que bloqueia nunca roda |
| fail-open | **não** | MEASURE sai em `:966`, antes |
| probe | sim, **sem saída** | binários locais têm as flags; nenhum `log` dispara |

⇒ "baseline idêntica" prova só que o caminho feliz não mudou. **Obrigatório** acrescentar:
- teste de egress que **bloqueia** (fixture com e-mail em linha `+`): mesmo `exit 3`, mesma
  mensagem, antes e depois — rodado no `ai-review.sh` E no `second-opinion.sh`;
- teste de fail-open com PATH sem `agy`/`claude`;
- teste do probe com `agy` falso SEM `--json-schema` no `--help` (ramo legado + `log`).

## 3. Critério de parada (C1.5/1c)

**Disparou: saturação.** As 3 últimas leituras (`ai-review.sh:890-960`, `:1230-1245`,
`tests/ai-review-baseline.sh`) só confirmaram fatos já na tabela.

<!-- deferred: skills/devflow-ceremony/SKILL.md (RC1–RC4, :49-203) — lido só o esqueleto; é alvo do T062 (F8), que abre com leitura própria sob o gate INV-4 -->
<!-- deferred: consumidores do ai-review.sh no dosiq (workflow ai-review-gate.yml) — a interface de linha de comando e o JSON de saída não mudam; se mudarem, é regressão que a baseline acusa -->

## 4. Riscos

| # | Severidade | Risco | Mitigação |
|---|---|---|---|
| R1 | MEDIUM | Extração muda ordem de `log` do probe ⇒ baseline diverge por motivo cosmético | Função do core emite os MESMOS `log` na MESMA ordem; baseline é o juiz |
| R2 | MEDIUM | Egress do second-opinion: artefato é markdown inteiro, não diff — `^\+` não se aplica | Função recebe modo (`added` para diff, `all` para artefato); regex e override únicos |
| R3 | MEDIUM | `RC6_ALLOW_SENSITIVE` é nome do RC6; o second-opinion herdaria prefixo alheio | Aceitar o mesmo override (um só interruptor de responsabilidade) — documentado, não renomeado |
| R4 | LOW | `log` do core prefixa `[rc6]`; second-opinion logaria como `[rc6]` | Aceito em 1.1.0; prefixo parametrizável é mudança à parte (mexeria na baseline) |
| R5 | LOW | Adaptador `analysis`: C1.5 real às vezes não gera arquivo | Script exige `--file`; sem arquivo ⇒ erro de uso, não fail-open |

## Uncertainty

- `uncertainty:` se o C1.5 Tier 2 real (T063) vai chamar o script na prática — PO-19 guard
  (Tier 0/1 não chamam) é verificável por grep; o USO só aparece num consumidor (A-2).
- `uncertainty:` qual engine o second-opinion deve preferir. Assumido: mesma ordem do RC6
  (agy, fallback claude), sem pass A/B — é uma opinião, não uma revisão em duas passadas.
