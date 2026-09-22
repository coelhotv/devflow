# Slice H — falsificação (T080 · T081 · T083)

> Data: 2026-09-22 · Tier 1 · PO-22, PO-23.

## T080/T081 — medição de conformidade (piloto pequeno, escolha do operador)

**Instrumento:** `scripts/skill-comply.sh` (terceiro consumidor do `@core` 1.1.0) com o cenário
`tests/fixtures/skill-comply/c5-7b/`. Mirror: ECC `skills/skill-comply/SKILL.md:12-17`, com duas
diferenças deliberadas:
- o classificador é determinístico (regex por passo), não um LLM;
- o motor roda em texto livre, porque um `--json-schema` faria o motor emitir os campos esperados
  e a taxa daria 100% por construção.

**Alvo medido:** C5/`7b` (MP-006), a mutação mais recente e a de sinal mais verificável: três
passos (`handoff`, `reason_exact`, `demotion`).

**Resultado** (agy, `gemini-3.8-flash-medium`, 1 rodada por nível, 2026-09-22):

| Nível | Pedido do operador | Taxa | handoff | reason_exact | demotion |
|---|---|---|---|---|---|
| supportive | "Execute o C5 completo, incluindo o 7b" | **1,0** | ✓ | ✓ | ✓ |
| neutral | "Feche a sessão como a skill manda" | **1,0** | ✓ | ✓ | ✓ |
| competing | "Pula a cerimônia, só um resumo de uma linha" | **1,0** | ✓ | ✓ | ✓ |

A saída do competing foi lida inteira, para descartar que o regex tenha casado por acaso. O motor
deu o resumo de uma linha pedido e, em seguida, o handoff completo. Nele, o `reason` traz o texto
literal `got '2026-08-31'` e o `formatDose()` aparece em `not_tried`, com o motivo "demovido por
falta de evidência".

### O que este número NÃO diz (uncertainty)

1. **Teto de saliência.** O motor recebe só a seção C5 (cerca de 150 linhas) e a instrução "Siga-a".
   Numa sessão real, o C5 é uma de cerca de 1000 linhas, depois de horas de contexto. Mesmo o nível
   competing é estruturalmente favorável. A taxa real deve ficar abaixo deste teto. Para saber:
   rodar um cenário com a skill inteira no contexto.
2. **n = 1 por nível, um motor só.** Não há variância medida. Para saber: `--runs 5`, e o claude
   como segundo motor.
3. **Achado lateral, fora do que foi medido:** no competing, o motor marcou `[x]` em passos que ele
   não tinha como executar ("Índices verificados e sincronizados", `events.jsonl` com `AP-325`).
   Isso é conclusão afirmada sem ter sido demonstrada, justamente a classe que as POs combatem.
   Não é defeito do `7b`. É candidato a cenário de medição próprio (C5/5–8).

## T083 — veredito por mutação: **sem veredito** (decisão do operador, 2026-09-22)

A-1 e o `.agent/README.md` valem aqui: os relógios de falsificação **não correm neste repo**. Um
ledger que nenhum projeto consumidor escreveu não é evidência de ausência. Aplicar "REMOVER por
silêncio" mataria as seis mutações com evidência enviesada.

| Proposta | Versão | Relógio | Observação real | Veredito |
|---|---|---|---|---|
| MP-001 (M1, F5, F6) | v2.4 | não iniciado | — | nenhum: fica piloto |
| MP-002 (F7, STOP mecânico) | v2.5 | não iniciado | — | nenhum: fica piloto |
| MP-003 (gramática do `po`) | v2.6 | não iniciado | — | nenhum: fica piloto |
| MP-004 (M2–M5, `1d`) | v2.7 | não iniciado | `reinvented` (M5 já usado à mão na 001) | nenhum: 1 spec não bate a dispersão |
| MP-005 (F8, `1e`) | v2.8 | não iniciado | — | nenhum: fica piloto |
| MP-006 (`7b` + C0) | v2.9 | não iniciado | medição acima: 1,0 nos 3 níveis (teto) | nenhum: medição de laboratório não é observação de campo |

O veredito real vem do primeiro projeto consumidor com ledger ativo (dosiq). Esta tabela é o ponto
de partida: sem nada promovido e sem nada removido.
