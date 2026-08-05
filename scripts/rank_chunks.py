import sys, os
workdir, nchunks, cap, fullfile_lines = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), int(sys.argv[4])

# per-file signal from parse_cands.py: drops, changed, logic
sig = {}
with open(os.path.join(workdir, "cands.tsv")) as fh:
    for line in fh:
        parts = line.rstrip("\n").split("\t")
        if len(parts) != 4: continue
        d, c, l, p = parts
        sig[p] = (int(d), int(c), int(l))

HOT = ("server/", "api/", "packages/core/", "/notifications/", "/schemas/")
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

scored = []
for i in range(nchunks):
    try:
        files = [l.strip() for l in open(os.path.join(workdir, "chunk_%d.files" % i)) if l.strip()]
    except OSError:
        files = []
    scores = [risk(f) for f in files] or [0]
    # sum ranks the chunk's total exposure; max keeps a single hot file from
    # being outvoted by a fat chunk of lukewarm ones.
    scored.append((i, sum(scores), max(scores), files))

keep = sorted(scored, key=lambda t: (-t[1], -t[2], t[0]))[:cap]
keep_ids = sorted(t[0] for t in keep)
dropped = [t for t in scored if t[0] not in set(keep_ids)]
print(" ".join(str(i) for i in keep_ids))
print("|".join("%d:sum=%d,max=%d" % (i, s, m) for i, s, m, _ in scored))
print("|".join(f for _, _, _, files in dropped for f in files))
