#!/usr/bin/env python3
"""B1 (import-graph chunk packing) and B2 (surgical external callee slicing) for ai-review.sh.

Standalone stdlib module: uses .graftroom/.graph/wiring.json when available as the fast
primary graph source, and always supplements/falls back with a lightweight JS/TS import
& definition resolver so new hunks, worktrees without .graftroom/, and CI work cleanly.
"""

from __future__ import annotations

import json
import os
import re
import sys
from collections import defaultdict

JS_EXTS = (".ts", ".tsx", ".js", ".jsx", ".mjs", ".cjs")
JS_KEYWORDS = frozenset({
    "const", "let", "var", "function", "return", "if", "else", "for", "while",
    "switch", "case", "break", "continue", "default", "import", "from", "export",
    "async", "await", "try", "catch", "finally", "throw", "new", "typeof", "void",
    "true", "false", "null", "undefined", "type", "interface", "extends", "implements",
    "class", "public", "private", "readonly", "string", "number", "boolean", "unknown",
    "never", "any", "object", "Array", "Promise", "Record", "Partial", "Pick", "Omit",
    "React", "useMemo", "useCallback", "useEffect", "useState", "useRef", "console",
})

IMPORT_CLAUSE_RE = re.compile(
    r"""(?:import|export)\s+(?:type\s+)?([^;]*?)\s+from\s+['"]([^'"]+)['"]"""
    r"""|(?:import|export)\s+['"]([^'"]+)['"]"""
    r"""|require\(\s*['"]([^'"]+)['"]\s*\)""",
    re.S,
)
SPEC_ONLY_RE = re.compile(
    r"""(?:import|export)\s+(?:[^;]*?\s+from\s+)?['"]([^'"]+)['"]"""
    r"""|(?:require|import)\(\s*['"]([^'"]+)['"]\s*\)""",
)
EXPORT_STAR_RE = re.compile(r"""export\s+\*\s+from\s+['"]([^'"]+)['"]""")
HUNK_RE = re.compile(r"^@@ -\d+(?:,\d+)? \+(\d+)(?:,(\d+))? @@")
TOKEN_RE = re.compile(r"\b([A-Za-z_][A-Za-z0-9_]{2,})\b")
SPAN_RE = re.compile(r"^L(\d+)-L(\d+)$")

DOSIQ_MOBILE_ALIASES = {
    "@shared": "apps/mobile/src/shared",
    "@features": "apps/mobile/src/features",
    "@utils": "apps/mobile/src/utils",
    "@schemas": "apps/mobile/src/schemas",
    "@adherence": "apps/mobile/src/features/adherence",
    "@medications": "apps/mobile/src/features/medications",
    "@protocols": "apps/mobile/src/features/protocols",
    "@stock": "apps/mobile/src/features/stock",
    "@dashboard": "apps/mobile/src/features/dashboard",
    "@navigation": "apps/mobile/src/navigation",
    "@platform": "apps/mobile/src/platform",
    "@profile": "apps/mobile/src/features/profile",
    "@notifications": "apps/mobile/src/features/notifications",
    "@treatments": "apps/mobile/src/features/treatments",
    "@dose": "apps/mobile/src/features/dose",
    "@history": "apps/mobile/src/features/history",
    "@measures": "apps/mobile/src/features/measures",
    "@": "apps/mobile/src",
}

DOSIQ_WEB_ALIASES = {
    "@features": "apps/web/src/features",
    "@shared": "apps/web/src/shared",
    "@services": "apps/web/src/services",
    "@dashboard": "apps/web/src/features/dashboard",
    "@medications": "apps/web/src/features/medications",
    "@protocols": "apps/web/src/features/protocols",
    "@stock": "apps/web/src/features/stock",
    "@adherence": "apps/web/src/features/adherence",
    "@calendar": "apps/web/src/features/calendar",
    "@emergency": "apps/web/src/features/emergency",
    "@prescriptions": "apps/web/src/features/prescriptions",
    "@settings": "apps/web/src/views/settings",
    "@schemas": "apps/web/src/schemas",
    "@utils": "apps/web/src/utils",
    "@": "apps/web/src",
}

PACKAGE_ALIASES = {
    "@dosiq/core": "packages/core/src",
    "@dosiq/shared-data": "packages/shared-data/src",
    "@dosiq/storage": "packages/storage/src",
    "@dosiq/design-tokens": "packages/design-tokens/src",
    "@dosiq/config": "packages/config/src",
}


def is_test_path(path: str) -> bool:
    return (
        "/__tests__/" in path
        or "/__mocks__/" in path
        or ".test." in path
        or ".spec." in path
    )


def subject_of_test(path: str) -> str:
    base = re.sub(r"\.(test|spec)\.(ts|tsx|js|jsx|mjs|cjs)$", r".\2", path)
    return base.replace("/__tests__/", "/")


def load_wiring(repo_root: str) -> dict | None:
    wpath = os.path.join(repo_root, ".graftroom", ".graph", "wiring.json")
    if not os.path.isfile(wpath):
        return None
    try:
        with open(wpath, encoding="utf-8") as fh:
            data = json.load(fh)
        if isinstance(data, dict) and "nodes" in data and "edges" in data:
            return data
    except (OSError, ValueError):
        return None
    return None


def _probe_file(repo_root: str, cand: str) -> str | None:
    cand = os.path.normpath(cand).replace("\\", "/")
    if cand.startswith(".."):
        return None
    full = os.path.join(repo_root, cand)
    if os.path.isfile(full):
        return cand
    # NodeNext TS: './foo.js' -> './foo.ts' / './foo.tsx'
    if cand.endswith((".js", ".mjs", ".cjs")):
        stem = os.path.splitext(cand)[0]
        for ext in (".ts", ".tsx", ".js", ".jsx", ".mts", ".mjs"):
            f = os.path.join(repo_root, stem + ext)
            if os.path.isfile(f):
                return stem + ext
    for ext in JS_EXTS:
        f = os.path.join(repo_root, cand + ext)
        if os.path.isfile(f):
            return cand + ext
    for ext in JS_EXTS:
        idx_cand = f"{cand}/index{ext}"
        if os.path.isfile(os.path.join(repo_root, idx_cand)):
            return idx_cand
    return None


def _load_tsconfig_aliases(repo_root: str, importer_path: str) -> dict[str, str]:
    aliases: dict[str, str] = dict(PACKAGE_ALIASES)
    if importer_path.startswith("apps/mobile/"):
        aliases.update(DOSIQ_MOBILE_ALIASES)
    elif importer_path.startswith("apps/web/"):
        aliases.update(DOSIQ_WEB_ALIASES)
    elif os.path.isdir(os.path.join(repo_root, "src")):
        aliases["@"] = "src"

    # Supplement from nearest tsconfig.json if present
    parts = importer_path.split("/")
    prefixes = []
    if len(parts) >= 2 and parts[0] in ("apps", "packages"):
        prefixes.append("/".join(parts[:2]))
    prefixes.append("")
    for pref in prefixes:
        cfg_path = os.path.join(repo_root, pref, "tsconfig.json") if pref else os.path.join(repo_root, "tsconfig.json")
        if not os.path.isfile(cfg_path):
            continue
        try:
            raw = open(cfg_path, encoding="utf-8", errors="replace").read()
            # Strip // line comments carefully (outside quotes) & trailing commas best-effort
            cleaned = re.sub(r"(?m)^\s*//.*$", "", raw)
            cleaned = re.sub(r",(\s*[}\]])", r"\1", cleaned)
            cfg = json.loads(cleaned)
            co = cfg.get("compilerOptions") or {}
            paths_map = co.get("paths") or {}
            base_url = co.get("baseUrl") or "."
            base_dir = os.path.normpath(os.path.join(pref, base_url)).replace("\\", "/")
            if base_dir == ".":
                base_dir = ""
            for k, vals in paths_map.items():
                if not isinstance(vals, list) or not vals:
                    continue
                key_clean = k[:-2] if k.endswith("/*") else k
                val_clean = vals[0][:-2] if vals[0].endswith("/*") else vals[0]
                mapped = os.path.normpath(os.path.join(base_dir, val_clean)).replace("\\", "/")
                if key_clean not in aliases:
                    aliases[key_clean] = mapped
        except (OSError, ValueError):
            pass
    return aliases


def resolve_specifier(repo_root: str, importer_path: str, spec: str) -> str | None:
    if not spec or (spec.startswith("node:")):
        return None
    if spec.startswith(("./", "../")):
        base_dir = os.path.dirname(importer_path)
        joined = os.path.join(base_dir, spec) if base_dir else spec
        return _probe_file(repo_root, joined)

    aliases = _load_tsconfig_aliases(repo_root, importer_path)
    # Longest matching prefix first
    for alias in sorted(aliases, key=len, reverse=True):
        target_base = aliases[alias]
        if spec == alias:
            return _probe_file(repo_root, target_base)
        if spec.startswith(alias + "/"):
            rest = spec[len(alias) + 1 :]
            return _probe_file(repo_root, f"{target_base}/{rest}" if target_base else rest)
    return None


def _read_text_for_file(repo_root: str, rel_path: str, diff_added_lines: list[str] | None = None) -> str:
    full = os.path.join(repo_root, rel_path)
    if os.path.isfile(full):
        try:
            with open(full, encoding="utf-8", errors="replace") as fh:
                return fh.read()
        except OSError:
            pass
    if diff_added_lines:
        return "\n".join(diff_added_lines)
    return ""


def _parse_barrel_exports(barrel_text: str) -> tuple[dict[str, tuple[str, str]], list[str]]:
    """Returns ({exported_name: (orig_name, spec)}, [star_specs])."""
    named: dict[str, tuple[str, str]] = {}
    stars: list[str] = []
    for m in EXPORT_STAR_RE.finditer(barrel_text):
        stars.append(m.group(1))
    # Match export { a, b as c } from 'spec' and export type { ... } from 'spec'
    for m in re.finditer(r"""export\s+(?:type\s+)?\{([^}]*)\}\s*from\s*['"]([^'"]+)['"]""", barrel_text, re.S):
        inner, spec = m.group(1), m.group(2)
        for item in inner.split(","):
            item = re.sub(r"^\s*type\s+", "", item).strip()
            if not item:
                continue
            if " as " in item:
                orig, exp_name = [p.strip() for p in item.split(" as ", 1)]
            else:
                orig = exp_name = item
            named[exp_name] = (orig, spec)
    return named, stars


def resolve_through_barrel(
    repo_root: str,
    start_file: str,
    symbol_name: str,
    max_hops: int = 2,
) -> tuple[str, str]:
    """Resolves a re-exported symbol through barrel index files up to max_hops."""
    cur_file = start_file
    cur_sym = symbol_name
    seen = {cur_file}
    for _ in range(max_hops):
        if not os.path.basename(cur_file).startswith("index."):
            break
        txt = _read_text_for_file(repo_root, cur_file)
        if not txt:
            break
        named, stars = _parse_barrel_exports(txt)
        if cur_sym in named:
            orig, spec = named[cur_sym]
            nxt = resolve_specifier(repo_root, cur_file, spec)
            if nxt and nxt not in seen:
                seen.add(nxt)
                cur_file = nxt
                cur_sym = orig
                continue
        # Follow star exports if symbol appears exported inside referenced module
        followed = False
        def_pat = re.compile(rf"\bexport\s+(?:async\s+)?(?:function|const|let|var|class|interface|type)\s+{re.escape(cur_sym)}\b")
        for spec in stars:
            nxt = resolve_specifier(repo_root, cur_file, spec)
            if not nxt or nxt in seen:
                continue
            ntxt = _read_text_for_file(repo_root, nxt)
            if ntxt and def_pat.search(ntxt):
                seen.add(nxt)
                cur_file = nxt
                followed = True
                break
        if not followed:
            break
    return cur_file, cur_sym


def split_diff_blocks(diff_path: str, workdir: str, repo_root: str) -> list[tuple[int, str, str, int]]:
    fullfiles_path = os.path.join(workdir, "fullfiles.txt")
    fullfiles: set[str] = set()
    if os.path.isfile(fullfiles_path):
        with open(fullfiles_path, encoding="utf-8", errors="replace") as fh:
            fullfiles = {l.strip() for l in fh if l.strip()}

    raw_blocks: list[list[str]] = []
    cur: list[str] = []
    with open(diff_path, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            if line.startswith("diff --git") and cur:
                raw_blocks.append(cur)
                cur = []
            cur.append(line)
    if cur:
        raw_blocks.append(cur)

    out: list[tuple[int, str, str, int]] = []
    for idx, buf in enumerate(raw_blocks):
        text = "".join(buf)
        path = ""
        for l in buf:
            if l.startswith("+++ b/"):
                path = l[6:].rstrip("\n")
                break
        cost = len(text)
        if path and path in fullfiles:
            try:
                cost += os.path.getsize(os.path.join(repo_root, path))
            except OSError:
                pass
        out.append((idx, path, text, cost))
    return out


def _added_lines_from_block(diff_text: str) -> list[str]:
    return [
        line[1:]
        for line in diff_text.splitlines()
        if line.startswith("+") and not line.startswith("+++")
    ]


def cmd_chunk(diff_path: str, workdir: str, budget: int, repo_root: str, graph_mode: int) -> None:
    blocks = split_diff_blocks(diff_path, workdir, repo_root)
    for _, path, _, cost in blocks:
        if cost > budget:
            sys.stderr.write(
                f"[rc6] WARN: {path} alone exceeds chunk budget ({cost}B) — its pass is advisory\n"
            )

    if graph_mode == 0 or len(blocks) <= 1:
        chunks: list[list[tuple[int, str, str, int]]] = []
        cur_items: list[tuple[int, str, str, int]] = []
        acc = 0
        for item in blocks:
            _, _, _, cost = item
            if acc and acc + cost > budget:
                chunks.append(cur_items)
                cur_items, acc = [], 0
            cur_items.append(item)
            acc += cost
        if cur_items:
            chunks.append(cur_items)

        for i, items in enumerate(chunks):
            with open(os.path.join(workdir, f"chunk_{i}.diff"), "w", encoding="utf-8") as df:
                df.write("".join(t[2] for t in items))
            with open(os.path.join(workdir, f"chunk_{i}.files"), "w", encoding="utf-8") as ff:
                ff.write("\n".join(t[1] for t in items if t[1]) + "\n")
            with open(os.path.join(workdir, f"chunk_{i}.related"), "w", encoding="utf-8") as rf:
                rf.write("")
        return

    # Graph mode (B1): combine wiring.json + lightweight regex/alias resolver
    fset = {b[1] for b in blocks if b[1]}
    adj: dict[str, dict[str, int]] = defaultdict(dict)
    ext_out: dict[str, dict[str, int]] = defaultdict(lambda: defaultdict(int))

    wiring = load_wiring(repo_root)
    if wiring is not None:
        node_by_id = {n["id"]: n for n in wiring.get("nodes", []) if "id" in n}
        for e in wiring.get("edges", []):
            s_id = e.get("source", "")
            t_id = e.get("target", "")
            rel = e.get("relation", "")
            if rel not in ("calls", "references", "imports", "extends"):
                continue
            tn = node_by_id.get(t_id)
            if not tn:
                continue
            sf = s_id.split("#", 1)[0]
            tf = tn.get("path", "")
            if not sf or not tf or sf == tf:
                continue
            if sf not in fset and tf not in fset:
                continue
            is_barrel = sf.endswith(("/index.ts", "/index.tsx", "/index.js", "/index.jsx")) or tf.endswith(
                ("/index.ts", "/index.tsx", "/index.js", "/index.jsx")
            )
            wt = 1 if is_barrel else (4 if rel in ("calls", "imports") else 2)
            if sf in fset and tf in fset:
                if wt > adj[sf].get(tf, 0):
                    adj[sf][tf] = wt
                    adj[tf][sf] = wt
            elif sf in fset and tf not in fset and not is_test_path(tf):
                if wt > ext_out[sf][tf]:
                    ext_out[sf][tf] = wt

    # Fallback / supplement from source files + diff added lines (catches unindexed/new files)
    for _, path, text, _ in blocks:
        if not path:
            continue
        sb = subject_of_test(path)
        if sb != path and sb in fset:
            adj[path][sb] = max(adj[path].get(sb, 0), 3)
            adj[sb][path] = max(adj[sb].get(path, 0), 3)
        elif sb != path and os.path.isfile(os.path.join(repo_root, sb)) and not is_test_path(sb):
            ext_out[path][sb] = max(ext_out[path][sb], 3)

        src_text = _read_text_for_file(repo_root, path, _added_lines_from_block(text))
        if not src_text:
            continue
        for m in SPEC_ONLY_RE.finditer(src_text):
            spec = m.group(1) or m.group(2)
            if not spec:
                continue
            resolved = resolve_specifier(repo_root, path, spec)
            if not resolved or resolved == path:
                continue
            is_barrel = os.path.basename(resolved).startswith("index.")
            wt = 1 if is_barrel else 4
            if resolved in fset:
                if wt > adj[path].get(resolved, 0):
                    adj[path][resolved] = wt
                    adj[resolved][path] = wt
            elif not is_test_path(resolved):
                ext_out[path][resolved] = max(ext_out[path][resolved], wt)
            if is_barrel:
                btxt = _read_text_for_file(repo_root, resolved)
                if btxt:
                    # Also connect named imports directly when barrel re-exports
                    for bm in re.finditer(r"""export\s+(?:type\s+)?\{([^}]*)\}\s*from\s*['"]([^'"]+)['"]""", btxt):
                        sub_res = resolve_specifier(repo_root, resolved, bm.group(2))
                        if sub_res and sub_res != path and sub_res in fset:
                            # Only add soft bridge if named symbol appears in src_text
                            syms = [re.sub(r"^\s*type\s+", "", s).strip().split(" as ")[-1].strip() for s in bm.group(1).split(",")]
                            if any(sym and sym in src_text for sym in syms):
                                adj[path][sub_res] = max(adj[path].get(sub_res, 0), 3)
                                adj[sub_res][path] = max(adj[sub_res].get(path, 0), 3)

    # Greedy Prod-First Max-Edge Cohesion Packing
    # Map path -> block item (handle duplicate empty paths safely via unique slot key if needed)
    items_by_key: dict[str, tuple[int, str, str, int]] = {}
    key_order: list[str] = []
    for item in blocks:
        idx, path, _, _ = item
        key = path if path and path not in items_by_key else f"__anon_{idx}"
        items_by_key[key] = item
        key_order.append(key)

    unplaced = set(key_order)
    packed_keys: list[list[str]] = []

    while unplaced:
        has_prod_left = any(not is_test_path(items_by_key[k][1]) for k in unplaced)
        seed = min(
            unplaced,
            key=lambda k: (
                is_test_path(items_by_key[k][1]) and has_prod_left,
                -(sum(adj[items_by_key[k][1]].get(items_by_key[q][1], 0) for q in unplaced if not is_test_path(items_by_key[q][1])) > 0),
                items_by_key[k][0],
            ),
        )
        unplaced.remove(seed)
        cur_keys = [seed]
        cur_paths = {items_by_key[seed][1]} if items_by_key[seed][1] else set()
        cur_cost = items_by_key[seed][3]

        while unplaced:
            fitting = [k for k in unplaced if cur_cost + items_by_key[k][3] <= budget]
            if not fitting:
                break

            cur_dirs = {os.path.dirname(u) for u in cur_paths if u}

            def cand_key(k: str):
                p = items_by_key[k][1]
                g = sum(adj[p].get(u, 0) for u in cur_paths) if p else 0
                is_t = is_test_path(p)
                prod_conn = g > 0 and not is_t
                test_conn = g > 0 and is_t
                same_dir = bool(p) and (os.path.dirname(p) in cur_dirs)
                return (
                    prod_conn,
                    g if prod_conn else 0,
                    test_conn,
                    g,
                    same_dir and not is_t,
                    same_dir,
                    -items_by_key[k][0],
                )

            best_k = max(fitting, key=cand_key)
            best_p = items_by_key[best_k][1]
            gain = sum(adj[best_p].get(u, 0) for u in cur_paths) if best_p else 0
            if gain == 0:
                rem_paths = [items_by_key[u][1] for u in unplaced if items_by_key[u][1]]
                rem_has_edges = any(adj[u].get(v, 0) > 0 for u in rem_paths for v in rem_paths if u < v)
                same_dir = bool(best_p) and (os.path.dirname(best_p) in cur_dirs)
                if rem_has_edges and not same_dir and cur_cost >= budget * 0.55:
                    break

            unplaced.remove(best_k)
            cur_keys.append(best_k)
            if best_p:
                cur_paths.add(best_p)
            cur_cost += items_by_key[best_k][3]

        # Deterministic intra-chunk order: production files first, then original diff index
        cur_keys.sort(key=lambda k: (is_test_path(items_by_key[k][1]), items_by_key[k][0]))
        packed_keys.append(cur_keys)

    for i, keys in enumerate(packed_keys):
        items = [items_by_key[k] for k in keys]
        cpaths = {t[1] for t in items if t[1]}
        with open(os.path.join(workdir, f"chunk_{i}.diff"), "w", encoding="utf-8") as df:
            df.write("".join(t[2] for t in items))
        with open(os.path.join(workdir, f"chunk_{i}.files"), "w", encoding="utf-8") as ff:
            ff.write("\n".join(t[1] for t in items if t[1]) + "\n")

        rel_weights: dict[str, int] = defaultdict(int)
        for p in cpaths:
            for nb, wt in ext_out.get(p, {}).items():
                if nb not in cpaths and not is_test_path(nb):
                    rel_weights[nb] += wt
        top_rel = [p for p, _ in sorted(rel_weights.items(), key=lambda kv: (-kv[1], kv[0]))[:15]]
        with open(os.path.join(workdir, f"chunk_{i}.related"), "w", encoding="utf-8") as rf:
            rf.write("\n".join(top_rel) + ("\n" if top_rel else ""))


def _parse_chunk_diff_hunks(diff_path: str) -> tuple[dict[str, list[tuple[int, int]]], set[str]]:
    hunks: dict[str, list[tuple[int, int]]] = defaultdict(list)
    tokens: set[str] = set()
    cur_file = ""
    with open(diff_path, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            if line.startswith("+++ b/"):
                cur_file = line[6:].rstrip("\n")
            elif line.startswith("@@ ") and cur_file:
                m = HUNK_RE.match(line)
                if m:
                    st = int(m.group(1))
                    cnt = int(m.group(2) or "1")
                    en = st + max(1, cnt) - 1
                    hunks[cur_file].append((max(1, st - 2), en + 2))
            elif (line.startswith("+") and not line.startswith("+++")) or (
                line.startswith("-") and not line.startswith("---")
            ):
                for tok in TOKEN_RE.findall(line[1:]):
                    if tok not in JS_KEYWORDS:
                        tokens.add(tok)
    return hunks, tokens


def _parse_span(span: str | None) -> tuple[int, int] | None:
    if not span:
        return None
    m = SPAN_RE.match(span)
    if not m:
        return None
    return int(m.group(1)), int(m.group(2))


def _spans_overlap(a: tuple[int, int], ranges: list[tuple[int, int]]) -> bool:
    for rs, re_ in ranges:
        if a[0] <= re_ and a[1] >= rs:
            return True
    return False


def _parse_imported_bindings(src_text: str) -> list[tuple[str, str, str]]:
    """Returns [(local_name, orig_name, spec)] from static JS/TS import clauses."""
    out: list[tuple[str, str, str]] = []
    # Match multiline import ... from 'spec'
    for m in re.finditer(r"""import\s+(?:type\s+)?([\s\S]*?)\s+from\s+['"]([^'"]+)['"]""", src_text):
        clause, spec = m.group(1).strip(), m.group(2)
        if not clause:
            continue
        # Namespace import: * as ns
        ns_m = re.match(r"^\*\s+as\s+([A-Za-z_][A-Za-z0-9_]*)$", clause)
        if ns_m:
            continue
        # Extract named {...} part if any
        brace_m = re.search(r"\{([\s\S]*?)\}", clause)
        if brace_m:
            prefix = clause[: brace_m.start()].strip().rstrip(",").strip()
            if prefix and re.match(r"^[A-Za-z_][A-Za-z0-9_]*$", prefix):
                out.append((prefix, prefix, spec))
            for item in brace_m.group(1).split(","):
                item = re.sub(r"^\s*type\s+", "", item).strip()
                if not item:
                    continue
                if " as " in item:
                    orig, local = [p.strip() for p in item.split(" as ", 1)]
                else:
                    orig = local = item
                if re.match(r"^[A-Za-z_][A-Za-z0-9_]*$", local) and re.match(r"^[A-Za-z_][A-Za-z0-9_]*$", orig):
                    out.append((local, orig, spec))
        elif re.match(r"^[A-Za-z_][A-Za-z0-9_]*$", clause):
            out.append((clause, clause, spec))
    return out


def _find_definition_span(lines: list[str], sym_name: str, is_default: bool = False) -> tuple[int, int] | None:
    esc = re.escape(sym_name)
    patterns = [
        re.compile(rf"^\s*(?:export\s+(?:default\s+)?)?(?:async\s+)?function\s+{esc}\b"),
        re.compile(rf"^\s*(?:export\s+)?class\s+{esc}\b"),
        re.compile(rf"^\s*(?:export\s+)?(?:const|let|var)\s+{esc}\b"),
        re.compile(rf"^\s*(?:export\s+)?(?:interface|type|enum)\s+{esc}\b"),
    ]
    if is_default:
        patterns.append(re.compile(rf"^\s*export\s+default\s+(?:async\s+)?function\s+(?:{esc}\b|\()"))

    hit_idx: int | None = None
    for idx, line in enumerate(lines):
        if any(p.search(line) for p in patterns):
            hit_idx = idx
            break
    if hit_idx is None:
        return None

    # Include up to 2 preceding JSDoc lines if immediately above
    start_idx = hit_idx
    if hit_idx > 0 and lines[hit_idx - 1].strip().endswith("*/"):
        for back in range(hit_idx - 1, max(-1, hit_idx - 6), -1):
            start_idx = back
            if "/*" in lines[back]:
                break

    # Trace balanced braces/parens to determine definition end (cap 60 lines)
    depth = 0
    seen_open = False
    end_idx = hit_idx
    max_scan = min(len(lines) - 1, hit_idx + 59)
    for j in range(hit_idx, max_scan + 1):
        l = lines[j]
        # Simple char scan skipping quotes
        in_q: str | None = None
        escape = False
        for ch in l:
            if escape:
                escape = False
                continue
            if ch == "\\" and in_q is not None:
                escape = True
                continue
            if in_q is not None:
                if ch == in_q:
                    in_q = None
                continue
            if ch in ("'", '"', "`"):
                in_q = ch
            elif ch in "{(":
                depth += 1
                seen_open = True
            elif ch in "})":
                depth -= 1
        end_idx = j
        if seen_open and depth <= 0:
            break
        if not seen_open and (l.rstrip().endswith(";") or (j > hit_idx and not l.strip())):
            break

    return start_idx + 1, end_idx + 1


def _kind_priority(kind: str) -> int:
    if kind in ("function", "method", "class"):
        return 3
    if kind in ("constant", "variable"):
        return 2
    return 1


def _path_priority(path: str) -> int:
    if path.startswith(("packages/core/", "packages/shared-data/", "server/", "api/")):
        return 2
    return 1


def cmd_callees(chunk_diff: str, chunk_files_path: str, repo_root: str, max_bytes: int) -> None:
    if max_bytes <= 0:
        return
    try:
        chunk_files = [l.strip() for l in open(chunk_files_path, encoding="utf-8", errors="replace") if l.strip()]
    except OSError:
        return
    if not chunk_files:
        return
    chunk_files_set = set(chunk_files)
    hunks, hunk_tokens = _parse_chunk_diff_hunks(chunk_diff)

    candidates: list[tuple[str, str, str, int, int, int, int]] = []
    # (target_path, name, kind, start, end, in_hunk, score)

    wiring = load_wiring(repo_root)
    if wiring is not None:
        node_by_id = {n["id"]: n for n in wiring.get("nodes", []) if "id" in n}
        nodes_by_path: dict[str, list[dict]] = defaultdict(list)
        for n in wiring.get("nodes", []):
            p = n.get("path", "")
            if p in chunk_files_set and n.get("kind") != "file":
                nodes_by_path[p].append(n)
        out_edges: dict[str, list[tuple[str, str]]] = defaultdict(list)
        for e in wiring.get("edges", []):
            rel = e.get("relation", "")
            if rel in ("calls", "references", "extends"):
                out_edges[e.get("source", "")].append((e.get("target", ""), rel))

        for path in chunk_files:
            hranges = hunks.get(path, [])
            seed_ids: set[str] = set()
            for n in nodes_by_path.get(path, []):
                sp = _parse_span(n.get("span"))
                if not hranges or (sp and _spans_overlap(sp, hranges)) or (n.get("name") in hunk_tokens):
                    seed_ids.add(n["id"])
            # Include 1-hop intra-file children (e.g. ConfiraSheet -> AskStep)
            expanded_ids = set(seed_ids)
            for sid in seed_ids:
                for tid, _ in out_edges.get(sid, []):
                    tn = node_by_id.get(tid)
                    if tn and tn.get("path") == path:
                        expanded_ids.add(tid)

            for sid in expanded_ids:
                for tid, rel in out_edges.get(sid, []):
                    tn = node_by_id.get(tid)
                    if not tn:
                        continue
                    tp = tn.get("path", "")
                    if not tp or tp in chunk_files_set or is_test_path(tp) or tp.endswith("database.types.ts"):
                        continue
                    sp = _parse_span(tn.get("span"))
                    if not sp:
                        continue
                    name = tn.get("name", "")
                    kind = tn.get("kind", "function")
                    in_tok = 1 if name in hunk_tokens else 0
                    score = in_tok * 10 + _kind_priority(kind) * 2 + _path_priority(tp) + (1 if rel == "calls" else 0)
                    candidates.append((tp, name, kind, sp[0], sp[1], in_tok, score))

    # Fallback / new-diff resolver: catches calls newly added in diff and repos without wiring.json
    file_lines_cache: dict[str, list[str]] = {}

    def get_lines(relp: str) -> list[str]:
        if relp not in file_lines_cache:
            txt = _read_text_for_file(repo_root, relp)
            file_lines_cache[relp] = txt.splitlines() if txt else []
        return file_lines_cache[relp]

    for path in chunk_files:
        src_text = _read_text_for_file(repo_root, path)
        if not src_text:
            continue
        for local_name, orig_name, spec in _parse_imported_bindings(src_text):
            if local_name not in hunk_tokens and orig_name not in hunk_tokens:
                continue
            resolved = resolve_specifier(repo_root, path, spec)
            if not resolved:
                continue
            tp, final_sym = resolve_through_barrel(repo_root, resolved, orig_name, max_hops=2)
            if not tp or tp in chunk_files_set or is_test_path(tp) or tp.endswith("database.types.ts"):
                continue
            tlines = get_lines(tp)
            if not tlines:
                continue
            sp = _find_definition_span(tlines, final_sym, is_default=(orig_name == local_name and "index." not in tp))
            if not sp:
                continue
            score = 10 + 6 + _path_priority(tp) + 1
            candidates.append((tp, final_sym, "function", sp[0], sp[1], 1, score))

    if not candidates:
        return

    # Deduplicate by (target_path, start, end), keeping max score
    best_by_key: dict[tuple[str, int, int], tuple[str, str, str, int, int, int, int]] = {}
    for c in candidates:
        key = (c[0], c[3], c[4])
        if key not in best_by_key or c[6] > best_by_key[key][6]:
            best_by_key[key] = c

    ranked = sorted(
        best_by_key.values(),
        key=lambda c: (-c[5], -c[6], c[0], c[3], c[1]),
    )

    header = "===== EXTERNAL CALLEES (unchanged definitions referenced by diff hunks — read-only context) =====\n"
    out_parts: list[str] = []
    used_bytes = len(header.encode("utf-8"))
    seen_symbol_names: set[tuple[str, str]] = set()

    for tp, name, _, st, en, _, _ in ranked:
        if (tp, name) in seen_symbol_names:
            continue
        tlines = get_lines(tp)
        if not tlines:
            continue
        s0 = max(1, st)
        e0 = min(len(tlines), min(en, s0 + 59))
        if e0 < s0:
            continue
        truncated_note = f" (truncated to {e0 - s0 + 1} lines of L{st}-L{en})" if en > e0 else ""
        block_lines = [f"\n----- CALLEE {tp}#{name} (L{s0}-L{e0}){truncated_note} -----"]
        for ln in range(s0, e0 + 1):
            block_lines.append(f"{ln}: {tlines[ln - 1]}")
        block = "\n".join(block_lines) + "\n"
        b_bytes = len(block.encode("utf-8"))
        if used_bytes + b_bytes > max_bytes:
            if not out_parts:
                # Try fitting a compact slice for at least the #1 callee
                avail = max_bytes - used_bytes
                if avail > 200:
                    partial = block.encode("utf-8")[: avail - 40].decode("utf-8", errors="ignore")
                    partial = partial.rsplit("\n", 1)[0] + "\n... (callee truncated by budget)\n"
                    out_parts.append(partial)
                    seen_symbol_names.add((tp, name))
            break
        out_parts.append(block)
        used_bytes += b_bytes
        seen_symbol_names.add((tp, name))

    if out_parts:
        sys.stdout.write(header + "".join(out_parts))


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        sys.stderr.write("usage: rc6_graph_context.py <chunk|callees> ...\n")
        return 2
    cmd = argv[1]
    if cmd == "chunk":
        if len(argv) < 6:
            return 2
        diff_path, workdir, budget, repo_root = argv[2], argv[3], int(argv[4]), argv[5]
        graph_mode = int(argv[6]) if len(argv) > 6 else 1
        cmd_chunk(diff_path, workdir, budget, repo_root, graph_mode)
        return 0
    if cmd == "callees":
        if len(argv) < 6:
            return 2
        cmd_callees(argv[2], argv[3], argv[4], int(argv[5]))
        return 0
    sys.stderr.write(f"unknown subcommand: {cmd}\n")
    return 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
