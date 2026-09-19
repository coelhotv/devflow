# Draft F7 — Terminação mecânica e proibição do auto-consentimento (R-065)

- **Alvo:** `SKILL.md` (núcleo), seção **MODE CONTROL RULE (R-065)**, logo após a lista de STOPs.
- **Mirror:** ECC `commands/multi-plan.md:227,229`; `agents/harness-optimizer.md:47`.
- **origin:** `proactive`
- **Admissão (DT-1):** (a) estende a R-065, que já existe e é soberana (INV-1) — nenhum mecanismo
  novo; (b) não aposenta nada: a R-065 hoje diz *não avance de modo* e **não** diz *pare de agir*,
  logo o STOP é semântico, não mecânico; (c) **parcialmente scriptável e já scriptado** — o
  `scripts/mode-gate.sh` do slice A decide a transição. O que falta é o comportamento DENTRO da
  resposta, que nenhum script observa. Piloto (DT-3).
- **Custo de contexto:** +9 linhas no núcleo (carregado em toda sessão — o mais caro do épico;
  por isso é o texto mais curto possível).
- **INV-5:** a seção é o núcleo, **não** é C1/C4/Bootstrap ⇒ INV-5 não se aplica. Mesmo assim entra
  piloto por DT-3.
- **INV-1:** reforça a R-065; não a relaxa em nenhuma direção.

## Texto proposto

```
**STOP é mecânico, não retórico.** Ao atingir um STOP acima:
- ENCERRE a resposta ali. **Nenhuma tool call depois da linha de STOP** — nem leitura, nem
  "só conferir uma coisa". Uma tool call após o STOP é violação da R-065, não zelo.
- É **ABSOLUTAMENTE PROIBIDO** perguntar ao operador e responder por ele. Fazer a pergunta e
  seguir em frente na mesma resposta — com qualquer redação ("assumindo que sim", "sigo por
  ora", "como não houve objeção") — é **falsificar consentimento**, não eficiência.
  O consentimento do operador é um EVENTO NA CONVERSA: chega numa mensagem dele, nunca de uma
  inferência sua. Sem esse evento, a resposta acabou.
- Diante da dúvida entre parar e seguir: **PARE**. Parar cedo demais custa uma mensagem;
  seguir sem mandato custa trabalho que o operador não autorizou.
[PILOTO 2026-09 · origin: proactive · remoção: ver DEVFLOW-META.md, MP-002]
```

## Linha na Quick Reference (núcleo)

```
| Encerrar a resposta na linha de STOP, sem mais nenhuma tool call | Perguntar Y/N ao operador e seguir na mesma resposta ("assumindo que sim") |
```

## Assinatura de atrito prevista (DT-2)

Se isto importa, aparecerá `kind: mode_boundary_crossed` (ou `consent_fabricated`) em
`process-friction.jsonl` em **10 sessões**.

## Cláusula de falsificação / sunset

- **Remover** se em 10 sessões nenhuma violação de STOP for observada — o STOP semântico bastava.
- **Promover** a regra consolidada (sem marca de piloto) ao primeiro **incidente real** de
  auto-consentimento observado: aí deixa de ser proativo e passa a ter a evidência que o
  `DEVFLOW-META.md` exige.
- **Não remover por silêncio do ledger enquanto `.agent/` não existir neste repo** (A-1): a ausência
  de registro aqui não é evidência de ausência de violação. O relógio das 10 sessões conta a partir
  do primeiro projeto consumidor com ledger ativo.
