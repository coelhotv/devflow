#!/usr/bin/env bash
# Regression corpus for the chunk risk ranking (spec 056/T040).
# Frozen on the real dosiq#794 diff: 98 files, 13 chunks, cap 6. Before the
# ranking, chunk 1 was `_dev/screens/DevHubScreen.tsx` — dev tooling reviewed
# only because `_dev` sorts early, while production chunks were dropped.
# Without this test the ranking is a belief, not a behavior.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIX="$HERE/fixtures/rank-794"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
cp "$FIX"/chunk_*.files "$FIX"/cands.tsv "$WORK"/
OUT="$(python3 "$HERE/../scripts/rank_chunks.py" "$WORK" 13 6 20)"
KEEP="$(printf '%s' "$OUT" | sed -n 1p)"
DROP="$(printf '%s' "$OUT" | sed -n 3p)"
TIERS="$(printf '%s' "$OUT" | sed -n 4p)"
fail=0
assert_dropped() { case "|$DROP|" in *"|$1|"*) echo "  ok   descartado: $1";; *) echo "  FAIL deveria ser descartado: $1"; fail=1;; esac; }
assert_kept()    { case "|$DROP|" in *"|$1|"*) echo "  FAIL deveria ser MANTIDO: $1"; fail=1;; *) echo "  ok   mantido: $1";; esac; }
assert_tier()    { case "|$TIERS|" in *"|$1|"*) echo "  ok   tier: $1";; *) echo "  FAIL tier esperado '$1' em [$TIERS]"; fail=1;; esac; }
echo "keep=[$KEEP] tiers=[$TIERS]"
# O caso que motivou a mudança: dev tooling não pode ocupar vaga.
assert_dropped "apps/mobile/src/features/_dev/screens/DevHubScreen.tsx"
# Código de produção com lógica/data não pode cair.
assert_kept "server/notifications/dispatcher/_reminderHelpers.ts"
assert_kept "server/notifications/dispatcher/dispatchLiveActivityStarts.ts"
[ "$(printf '%s' "$KEEP" | wc -w | tr -d ' ')" = 6 ] && echo "  ok   6 chunks mantidos" || { echo "  FAIL cap não respeitado"; fail=1; }
assert_tier "11:HOT"
assert_tier "12:HOT"
assert_tier "5:COLD"
assert_tier "0:NORMAL"

# Caso sintético: valida fronteiras HOT / NORMAL / COLD da 4a linha
SYN="$(mktemp -d)"; trap 'rm -rf "$WORK" "$SYN"' EXIT
printf '0\t12\t1\tpackages/core/src/calc.ts\n0\t12\t1\tsrc/components/ui.js\n0\t5\t0\tsrc/__tests__/ui.test.js\n' > "$SYN/cands.tsv"
printf 'packages/core/src/calc.ts\n' > "$SYN/chunk_0.files"
printf 'src/components/ui.js\n' > "$SYN/chunk_1.files"
printf 'src/__tests__/ui.test.js\n' > "$SYN/chunk_2.files"
SYN_TIERS="$(python3 "$HERE/../scripts/rank_chunks.py" "$SYN" 3 8 20 | sed -n 4p)"
[ "$SYN_TIERS" = "0:HOT|1:NORMAL|2:COLD" ] && echo "  ok   tiers sintéticos: $SYN_TIERS" || { echo "  FAIL tiers sintéticos: $SYN_TIERS"; fail=1; }
exit $fail
