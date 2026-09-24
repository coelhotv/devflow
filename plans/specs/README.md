# Índice de specs — DEVFLOW

Fonte canônica de status das specs em `plans/specs/`. **Registrar aqui na criação e em toda
transição de status, no mesmo passo que causou a mudança** (S6 — SPECS INDEX SYNC). Índice
desatualizado é drift silencioso.

| # | Nome | Tier | Status | Nota |
|---|---|---|---|---|
| 001 | [ecc-absorption](001-ecc-absorption/) | 2 | delivered (pilotos) | Absorção de achados do ECC em 9 slices, **todos entregues** (DEVFLOW v2.3 → **v3.0.0 PILOTO**, MP-001..MP-007). 11/23 POs fechadas; PO-21 `[!]`; 11 MANUAL aguardam projeto consumidor (A-2). Veredito dos pilotos: nenhum ainda (A-1). Branch `spec/001-ecc-absorption`, PR #1 (registro). |
| 002 | [setup-active-ledger](002-setup-active-ledger/) | 1 | specified | `setup.sh` idempotente (rerun hoje APAGA a memória), cria ledgers com marco de início e `.gitignore`. Marco de início do ledger: derivado do git (Q1). Branch `spec/002-setup-active-ledger`. |
| 003 | [rc6-engine-resilience](003-rc6-engine-resilience/) | 1 | specified | RC6: `coverage.partial` mentia com falha do motor (dosiq#835, 1/4 chunks reportado como cheio). Cobertura por passe (contrato aditivo) + retry/backoff/fallback `gemini-3.7-flash-medium`/breaker no `@core` + status file e VERDICT p/ o agente. Branch `spec/003-rc6-engine-resilience`. |

> Specs legadas fora deste diretório (`plans/EXEC_SPEC_*.md`) não entram na numeração.
