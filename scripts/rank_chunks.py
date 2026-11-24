import sys, os
workdir, nchunks, cap, fullfile_lines = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), int(sys.argv[4])
hot_min = int(sys.argv[5]) if len(sys.argv) > 5 else 4

# per-file signal from parse_cands.py: drops, changed, logic
sig = {}
with open(os.path.join(workdir, "cands.tsv")) as fh:
    for line in fh:
        parts = line.rstrip("\n").split("\t")
        if len(parts) != 4: continue
        d, c, l, p = parts
        sig[p] = (int(d), int(c), int(l))

HOT = ("server/", "api/", "packages/core/", "/notifications/", "/schemas/")
HOT_EFFORT = HOT + ("/services/", "/repositories/", "/platform/")
COLD = ("/_dev/", "/__tests__/", "/__mocks__/", ".test.", ".spec.", "/storybook/")

def risk(path):
    d, c, l = sig.get(path, (0, 0, 0))
    s = 0
    s += 3 if d > 0 else 0            # dropped call arg: the #1 migration-regression risk
    s += 2 if l else 0                # control flow / arithmetic / date-time
    s += 1 if c > fullfile_lines else 0
    if path.endswith("Schema.ts") or any(h in "/" + path for h in HOT): s += 2
    if any(x in "/" + path for x in COLD): s -= 2
    return s

def classify_chunk(files, max_score):
    non_cold = [f for f in files if f and not any(x in "/" + f for x in COLD)]
    has_prod_signal = any(sig.get(f, (0, 0, 0))[2] > 0 or sig.get(f, (0, 0, 0))[0] > 0 for f in non_cold)
    if not non_cold or not has_prod_signal:
        return "COLD"
    has_hot_domain = any(
        (f.endswith("Schema.ts") or any(h in "/" + f for h in HOT_EFFORT)) and sig.get(f, (0, 0, 0))[2] > 0
        for f in non_cold
    )
    if max_score >= hot_min or has_hot_domain:
        return "HOT"
    return "NORMAL"

scored = []
for i in range(nchunks):
    try:
        files = [l.strip() for l in open(os.path.join(workdir, "chunk_%d.files" % i)) if l.strip()]
    except OSError:
        files = []
    scores = [risk(f) for f in files] or [0]
    mx = max(scores)
    # sum ranks the chunk's total exposure; max keeps a single hot file from
    # being outvoted by a fat chunk of lukewarm ones.
    scored.append((i, sum(scores), mx, files, classify_chunk(files, mx)))

keep = sorted(scored, key=lambda t: (-t[1], -t[2], t[0]))[:cap]
keep_ids = sorted(t[0] for t in keep)
dropped = [t for t in scored if t[0] not in set(keep_ids)]
print(" ".join(str(i) for i in keep_ids))
print("|".join("%d:sum=%d,max=%d" % (i, s, m) for i, s, m, _, _ in scored))
print("|".join(f for _, _, _, files, _ in dropped for f in files))
print("|".join("%d:%s" % (i, tier) for i, _, _, _, tier in scored))
