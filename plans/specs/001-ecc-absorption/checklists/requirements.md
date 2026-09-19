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
- [x] SC-005 é verificável por diff vazio
- [ ] SC-004 depende do slice H — reavaliar quando o caminho `external_corpus` existir
