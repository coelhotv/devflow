# Draft D — Gramática do bloco `po`: 4 campos + M6

- **Alvo:** `SKILL.md` (núcleo, seção *Proof Obligations* — a tabela canônica) · `skills/devflow-code/SKILL.md`
  (C3, C4, RC5 Pass 0) · `skills/devflow-spec/SKILL.md` (S4, emissão do bloco).
- **origin:** `proactive` · **Fecha:** PO-7, PO-8, PO-9, PO-10
- **INV-5:** toca o **C4** ⇒ sem incidente real, a parte do C4 entra **rebaixada a piloto**.

## Orçamento — leia antes do texto

O bloco `po` tem hoje **6 campos** (+2 no Tier 2 regulado). Este draft propõe **5 novos**
(`boundary`, `evidence_class`, `uncertainty`, `red`, e o terceiro `status`). Um bloco de 11 campos
mata o que faz a PO funcionar: um formulário curto que o modelo fraco consegue segurar inteiro.

**Por isso nenhum campo novo é obrigatório em todo tier.** A regra de admissão (DT-1 c) foi aplicada
campo a campo, e dois foram **rejeitados como obrigatórios**:

| Campo | Obrigatório em | Por quê não em todo tier |
|---|---|---|
| `evidence_class:` | **T1+** | é um enum de 1 palavra; custo ~0, e é o que o Pass 0 audita |
| `status: [!]` | — (valor, não campo) | não acrescenta campo nenhum: amplia o domínio de um que já existe |
| `boundary:` | **T2 apenas** | em T1 o escopo cabe na cabeça; obrigar vira preenchimento ritual |
| `uncertainty:` | opcional, sempre | campo para registrar ignorância **só existe se for barato omitir** |
| `red:` | opcional, T1+ | TDD é *modo de preencher* a PO, não segundo mecanismo. Obrigar cria concorrência com `proof:` |

**O que isto aposenta (DT-1 b):** nada é removido, mas `evidence_class:` **absorve** a distinção que
hoje é feita à mão e sem vocabulário no RC5 Pass 0 ("demonstrado vs. afirmado") — o Pass 0 passa a
comparar dois campos em vez de julgar prosa.

## Colisão de nome — resolvida pelo operador (opção **a**, 2026-09-19)

`evidence:` **já existe** no núcleo (`SKILL.md:364`), restrito a Tier 2 regulado, significando
*"onde a linha de auditoria aparece na saída do proof"*. O campo novo chama-se **`evidence_class:`**
e o `evidence:` regulado fica **intacto**. Zero backfill; nenhum bloco existente muda de sentido.

## Texto proposto — núcleo (`SKILL.md`), após a tabela canônica

```
**Campos novos (v2.6 — PILOTO).** Nenhum é obrigatório em todo tier; ver a coluna *Required*.

| Field | Required | Meaning |
|-------|----------|---------|
| `boundary` | T2 | what must NOT be done to reach this AC — the moves that would satisfy the letter and betray the intent (e.g. "não relaxar o schema", "não mockar o caminho que a PO mede"). A PO without a boundary is satisfiable by deleting the test |
| `evidence_class` | T1+ | how strong the proof actually is — ONE of: `reconciliation` (output confrontado com uma baseline/artefato independente) · `execution` (comando rodado, saída colada) · `static-read` (arquivo lido, linha citada; nada executou) · `inference` (deduzido; NADA foi lido nem rodado). Declarado ao FECHAR, não ao escrever |
| `uncertainty` | opcional | what you do NOT know and did not fabricate. Preencher é preferível a inventar; vazio significa "nada a declarar", nunca "verifiquei tudo" |
| `red` | opcional (T1+) | quando o `proof:` é um teste: a falha esperada, colada ANTES da implementação. Falha por asserção ou símbolo ausente — nunca por erro de sintaxe/import (isso é teste quebrado, não teste vermelho) |

**`status` ganha um terceiro valor:** `[!] unavailable — <motivo>`.
Um check que NÃO PÔDE rodar (recurso ausente, ambiente sem acesso, dependência de outro slice)
fecha como `[!]` com o motivo, em vez de mentir `[x]` ou travar a sessão indefinidamente.
REGRA DURA: `[!]` **nunca** conta como `[x]` em nenhuma contagem de SC, e o RC5 Pass 0 o reporta
como **gate desarmado**. `[!]` é dívida visível; `[x]` sem evidência é fraude de processo.
O distill conta `[!]` ao lado de `po_unstable` — os dois dizem "a prova escolhida não se paga
neste tier", que é sinal de tiering errado, não de azar.
```

## Texto proposto — `devflow-code`, C4 (fechamento)

```
  Ao fechar cada PO, DECLARE `evidence_class:` e confronte com o que o `proof:` prometia:
    proof: era comando executável  → evidence_class deve ser `execution` ou `reconciliation`.
    Fechar com `static-read` ou `inference` um proof que prometia execução é REJEITADO no Pass 0.
    proof: MANUAL —                → `execution` (ação feita, evidência colada) ou `[!]` com motivo.
  Não pôde rodar? `status: [!] unavailable — <motivo>`. NÃO invente saída, NÃO marque [x].
  [PILOTO 2026-09 · origin: proactive]
```

## Texto proposto — `devflow-code`, C3 (M6)

```
  A ordem acima é de DEPENDÊNCIA, não cronograma: schemas antes de services porque services
  dependem deles, não porque a semana começa no schema.
  Tier 1+: quando o `proof:` de uma PO é um teste, escreva o teste ANTES da implementação e cole
  a falha esperada no campo `red:` do bloco. A falha vale se for por asserção ou símbolo ausente;
  falha por sintaxe/import é teste quebrado, não teste vermelho. Tier 0 pula.
  Após CADA arquivo, rode o `Validate:` da task (comandos resolvidos no C1). Não avance com erro
  pendente. O `guard:` NÃO migra para cá — o C4 segue sendo o portão único de fechamento.
```

## Texto proposto — `devflow-spec`, S4 (emissão)

```
  Ao emitir um bloco `po`: Tier 2 exige `boundary:`. `evidence_class:` NÃO se escreve aqui —
  ele é declarado no C4, ao fechar, porque é uma propriedade da prova obtida, não da prometida.
  Bloco legado sem os campos novos NÃO é inválido: backfill oportunista, só nas POs que a
  sessão tocar (mesma regra do backfill pré-v2.1).
```

## Assinatura de atrito prevista (DT-2)

`evidence_class` → `kind: proof_class_mismatch` · `[!]` → `kind: gate_unsatisfiable`
· `boundary` → `kind: ac_satisfied_wrongly`, em **12 sessões Tier 1+**.

## Cláusula de falsificação / sunset

- **`boundary:`** — 12 sessões T2 sem nenhuma PO satisfeita-pela-letra ⇒ REMOVER.
- **`evidence_class:`** — se em 12 sessões toda PO fechar com `execution`, o campo não está
  discriminando nada ⇒ colapsa numa marca binária (`demonstrado` / `afirmado`).
- **`uncertainty:`** — 12 sessões sempre vazio ⇒ REMOVER (é campo para uso raro; vazio sempre
  significa que ninguém o usa, não que ninguém tem dúvida).
- **`red:`** — 12 sessões sem nenhum `red:` preenchido ⇒ REMOVER; TDD não pegou por prosa.
- **`[!]`** — **sem sunset.** Não é passo novo: é valor a mais num campo existente, e o modo de
  falha que ele evita (mentir `[x]` ou travar) não expira. Remover exigiria provar que todo check
  sempre pode rodar.
- Relógio das 12 sessões conta a partir do primeiro projeto consumidor com ledger ativo (A-1).
