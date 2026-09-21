# Checklist de requisitos — 001

Testes unitários da *escrita* dos requisitos, não do comportamento implementado.

## Completude
- [x] Todo FR tem ao menos um slice responsável
- [x] Todo AC tem um bloco `po`
- [x] Todo `po` declara `slice:`
- [x] Non-Goals tem ≥2 itens explícitos
- [x] Invariantes declarados e numerados

## Clareza
- [x] Nenhum FR usa "deveria", "idealmente" ou "quando possível"
- [x] Todo `proof:` é comando exato ou `MANUAL —` com ação observável
- [x] Todo `expect:` nomeia sinal observável, não "funciona"

## Consistência
- [x] A tabela de slices bate com as POs (cada PO pertence a um slice existente)
- [x] A ordem de execução respeita as dependências declaradas
- [x] Nenhum Non-Goal contradiz um FR

## Rastreabilidade
- [x] Cada achado dos relatórios de garimpo está atribuído a exatamente um slice
- [x] Restrições de governança citam arquivo e linha (`DEVFLOW-META.md:101-102`)

## Mensurabilidade
- [~] SC-005 é verificável por diff vazio — **ESCOPO PRECISADO em 2026-09-21**, não mais `[x]`
  como estava escrito. O diff vazio prova a **extração** (F1); não é congelamento permanente do
  `ai-review.sh`. O conserto do AC-1 mudou comportamento DEPOIS, de propósito. Deixar `[x]` aqui
  afirmaria uma revisão que passou a valer para algo diferente do que foi revisado
- [ ] SC-004 depende do slice H — reavaliar quando o caminho `external_corpus` existir

## Cobertura de trabalho não previsto (acrescentado em 2026-09-21)
- [x] Trabalho fora da tabela de slices está registrado (AC-1 + init do `.agent/` → grupo
  *Interlúdio* em `tasks.md`), para não aparecer no `git log` sem origem
- [~] "Cada achado está atribuído a exatamente um slice" continua valendo para os achados de
  GARIMPO, que é o que a linha da Rastreabilidade mede. Achados COLATERAIS (AC-1) não têm slice
  por construção — e isso é correto, não um furo de rastreabilidade

**Revalidação 2026-09-21** (C5/4b): os itens de Completude/Clareza/Consistência/Rastreabilidade
foram reconferidos contra o `spec.md` atual e seguem verdadeiros. O único que deixou de ser
verdadeiro como estava escrito é o SC-005, desmarcado acima com o motivo.
