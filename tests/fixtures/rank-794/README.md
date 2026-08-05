# Fixture — dosiq#794 (spec 056/T040)

Derivada do diff REAL do PR #794 (98 arquivos, 92 em CODE_GLOBS), congelada em 2026-08-04.

- `cands.tsv` — saída **real** do `parse_cands.py` sobre o diff (drops/changed/logic por arquivo).
- `chunk_*.files` — 13 chunks, reproduzindo a contagem do run real (`Coverage: 6/13`).
  Budget calibrado em 35000B para bater os 13 chunks: os tamanhos de arquivo aqui vêm da `main`,
  não da branch do PR, então o budget nominal do run original não reproduz a contagem.

**O que o corpus trava:** antes do ranking, o cap ficava com os 6 PRIMEIROS chunks em ordem de path.
O chunk 0 é `_dev/screens/DevHubScreen.tsx` — dev tooling revisado só porque `_dev` ordena cedo,
enquanto chunks de código de produção não foram olhados. O teste falha se isso voltar.
