#!/usr/bin/env python3
"""Offline RC6 corpus validator, C3 duplicate/orphan auditor, and baseline evaluator.

Project-agnostic: consumes --corpus-dir, --schema, and target-repo memory/selector paths
via CLI flags (no repository-specific paths or rules hardcoded).
"""

import argparse
import datetime
import json
import os
import re
import subprocess
import sys
import tempfile
from collections import defaultdict

ID_RE = re.compile(r"\b(?:R|AP|CON|ADR)-[0-9]{3}\b")
DROP_RE = re.compile(r"[A-Za-z0-9_]+\(.*,.*\)")
LOGIC_RE = re.compile(
    r"(setHours|setMinutes|getTime|parseISO|parseLocalDate|new Date|Date\(|Math\.|"
    r"\bif\b|\breturn\b|=>|\.map\(|\.reduce\(|\.filter\(|\bfor\b|\bwhile\b|"
    r"\?\?|&&|\|\||\btimezone\b|\btz\b)"
)
STOPWORDS = {
    "the", "and", "for", "with", "that", "this", "from", "into", "when", "does",
    "not", "are", "was", "were", "have", "has", "will", "should", "must", "can",
    "para", "com", "sem", "que", "uma", "por", "não", "nao", "como", "mais",
    "sobre", "entre", "pode", "deve", "esta", "está", "esse", "essa", "isso",
    "mesmo", "mesma", "apenas", "antes", "depois", "quando", "onde", "cada",
}


def validate_schema_node(val, node, root_schema, path="$"):
    errors = []
    if "$ref" in node:
        ref = node["$ref"]
        if not ref.startswith("#/$defs/"):
            return [f"{path}: unsupported $ref {ref}"]
        def_name = ref[len("#/$defs/"):]
        if def_name not in root_schema.get("$defs", {}):
            return [f"{path}: missing $defs/{def_name}"]
        node = root_schema["$defs"][def_name]

    expected_type = node.get("type")
    if expected_type is not None:
        types = expected_type if isinstance(expected_type, list) else [expected_type]
        ok = False
        for t in types:
            if t == "object" and isinstance(val, dict):
                ok = True
            elif t == "array" and isinstance(val, list):
                ok = True
            elif t == "string" and isinstance(val, str):
                ok = True
            elif t == "integer" and isinstance(val, int) and not isinstance(val, bool):
                ok = True
            elif t == "number" and isinstance(val, (int, float)) and not isinstance(val, bool):
                ok = True
            elif t == "boolean" and isinstance(val, bool):
                ok = True
            elif t == "null" and val is None:
                ok = True
        if not ok:
            errors.append(f"{path}: expected type {types}, got {type(val).__name__}")
            return errors

    if "const" in node and val != node["const"]:
        errors.append(f"{path}: expected const {node['const']!r}, got {val!r}")
    if "enum" in node and val not in node["enum"]:
        errors.append(f"{path}: value {val!r} not in enum {node['enum']!r}")

    if isinstance(val, str):
        if "minLength" in node and len(val) < node["minLength"]:
            errors.append(f"{path}: length {len(val)} < minLength {node['minLength']}")
        if "pattern" in node and not re.search(node["pattern"], val):
            errors.append(f"{path}: {val!r} does not match pattern {node['pattern']!r}")
        fmt = node.get("format")
        if fmt == "date":
            try:
                datetime.date.fromisoformat(val)
            except ValueError:
                errors.append(f"{path}: invalid ISO date {val!r}")
        elif fmt == "date-time":
            try:
                datetime.datetime.fromisoformat(val.replace("Z", "+00:00"))
            except ValueError:
                errors.append(f"{path}: invalid ISO date-time {val!r}")

    if isinstance(val, (int, float)) and not isinstance(val, bool):
        if "minimum" in node and val < node["minimum"]:
            errors.append(f"{path}: {val} < minimum {node['minimum']}")
        if "maximum" in node and val > node["maximum"]:
            errors.append(f"{path}: {val} > maximum {node['maximum']}")

    if isinstance(val, dict):
        for req in node.get("required", []):
            if req not in val:
                errors.append(f"{path}: missing required key {req!r}")
        props = node.get("properties", {})
        if node.get("additionalProperties") is False:
            extra = set(val.keys()) - set(props.keys())
            if extra:
                errors.append(f"{path}: unexpected properties {sorted(extra)}")
        for k, sub_val in val.items():
            if k in props:
                errors.extend(validate_schema_node(sub_val, props[k], root_schema, f"{path}.{k}"))

    if isinstance(val, list) and "items" in node:
        for idx, item in enumerate(val):
            errors.extend(validate_schema_node(item, node["items"], root_schema, f"{path}[{idx}]"))

    return errors


def tokenize_issue(text):
    tokens = re.findall(r"[a-z0-9_]{3,}", (text or "").lower())
    return {t for t in tokens if t not in STOPWORDS}


def jaccard(a, b):
    if not a or not b:
        return 0.0
    return len(a & b) / len(a | b)


def audit_case_c3(case, corpus_dir):
    merged_rel = (case.get("artifacts") or {}).get("merged_output_file")
    if not merged_rel:
        return {
            "inline_count": 0,
            "orphan_count": 0,
            "candidates": [],
            "line_drift_dupes": 0,
            "wording_dupes": 0,
        }
    merged_path = os.path.join(corpus_dir, merged_rel)
    if not os.path.exists(merged_path):
        return {
            "inline_count": 0,
            "orphan_count": 0,
            "candidates": [],
            "line_drift_dupes": 0,
            "wording_dupes": 0,
        }
    data = json.load(open(merged_path, encoding="utf-8"))
    findings = data.get("findings") or []
    inline = [f for f in findings if not f.get("orphan")]
    orphans = [f for f in findings if f.get("orphan")]

    by_file = defaultdict(list)
    for idx, f in enumerate(findings):
        by_file[f.get("file") or "?"].append((idx, f))

    candidates = []
    for fpath, items in sorted(by_file.items()):
        for i in range(len(items)):
            idx_a, fa = items[i]
            la = fa.get("line")
            ra = set(ID_RE.findall(fa.get("rule") or ""))
            ta = tokenize_issue((fa.get("issue") or "") + " " + (fa.get("causation") or ""))
            for j in range(i + 1, len(items)):
                idx_b, fb = items[j]
                lb = fb.get("line")
                rb = set(ID_RE.findall(fb.get("rule") or ""))
                tb = tokenize_issue((fb.get("issue") or "") + " " + (fb.get("causation") or ""))
                dist = abs(int(la) - int(lb)) if (isinstance(la, int) and isinstance(lb, int)) else None
                jac = jaccard(ta, tb)
                same_rule = bool(ra and rb and (ra & rb))
                close_line = dist is not None and dist <= 5
                rule_window = same_rule and (dist is None or dist <= 15)
                if close_line or rule_window or jac >= 0.45:
                    kind = "line_drift" if (close_line and (same_rule or jac >= 0.35)) else (
                        "wording_overlap" if jac >= 0.45 else "nearby_same_file"
                    )
                    candidates.append({
                        "file": fpath,
                        "line_a": la,
                        "line_b": lb,
                        "dist": dist,
                        "rule_a": fa.get("rule"),
                        "rule_b": fb.get("rule"),
                        "jaccard": round(jac, 3),
                        "kind": kind,
                        "issue_a": (fa.get("issue") or "")[:110],
                        "issue_b": (fb.get("issue") or "")[:110],
                    })

    line_drift = sum(1 for c in candidates if c["kind"] == "line_drift")
    wording = sum(1 for c in candidates if c["kind"] == "wording_overlap")
    return {
        "inline_count": len(inline),
        "orphan_count": len(orphans),
        "candidates": candidates,
        "line_drift_dupes": line_drift,
        "wording_dupes": wording,
    }


def compute_claude_preamble(claude_md_path):
    if not claude_md_path or not os.path.exists(claude_md_path):
        return 0, set()
    lines = open(claude_md_path, encoding="utf-8", errors="replace").readlines()
    crit, rest = [], []
    in_crit = False
    for line in lines:
        if line.startswith("## Regras Críticas"):
            in_crit = True
            crit.append(line)
            continue
        if in_crit and line.startswith("## "):
            in_crit = False
        if in_crit:
            crit.append(line)
        else:
            rest.append(line)
    out = (
        "===== PROJECT CRITICAL RULES (CLAUDE.md — Regras Críticas hoisted; read FIRST) =====\n"
        + "".join(crit)
        + "\n----- (rest of CLAUDE.md, critical section omitted above) -----\n"
        + "".join(rest)
    )
    return len(out.encode("utf-8")), set(ID_RE.findall("".join(lines)))


def clamp_file_bytes(path, max_chars=80):
    if not path or not os.path.exists(path):
        return 0
    total = 0
    with open(path, encoding="utf-8", errors="replace") as f:
        for line in f:
            clamped = line.rstrip("\n")[:max_chars] + "\n"
            total += len(clamped.encode("utf-8"))
    return total


def compute_wiki_bytes(rules_idx, ap_idx, max_chars=80):
    b = 0
    if rules_idx and os.path.exists(rules_idx):
        b += len(f"\n===== RULES_INDEX (pack-filtered; clamp {max_chars}c) =====\n".encode("utf-8"))
        b += clamp_file_bytes(rules_idx, max_chars)
    if ap_idx and os.path.exists(ap_idx):
        b += len(f"\n===== ANTI_PATTERNS_INDEX (pack-filtered; clamp {max_chars}c) =====\n".encode("utf-8"))
        b += clamp_file_bytes(ap_idx, max_chars)
    return b


def build_detail_map(memory_root):
    mapping = {}
    if not memory_root or not os.path.isdir(memory_root):
        return mapping
    for root, _, files in os.walk(memory_root):
        for fn in files:
            m = re.match(r"^((?:R|AP|CON|ADR)-[0-9]{3})\.md$", fn)
            if m:
                mapping[m.group(1)] = os.path.join(root, fn)
    return mapping


def compute_detail_for_diff(diff_text, detail_map, detail_max=24000):
    ids_in_diff = sorted(set(ID_RE.findall(diff_text)))
    included = set()
    dacc = 0
    total_bytes = 0
    for rid in ids_in_diff:
        p = detail_map.get(rid)
        if not p or not os.path.exists(p):
            continue
        sz = os.path.getsize(p)
        hdr = len(f"\n===== DETAIL {os.path.basename(p)} =====\n".encode("utf-8"))
        dacc += sz
        if dacc > detail_max:
            break
        total_bytes += sz + hdr
        included.add(rid)
    return total_bytes, included


def run_selector(selector_script, memory_root, diff_path, limit=60, as_json=True):
    cmd = ["node", selector_script]
    if memory_root:
        cmd.extend(["--root", memory_root])
    cmd.extend(["--diff-file", diff_path, "--limit", str(limit)])
    if as_json:
        cmd.append("--json")
    proc = subprocess.run(cmd, capture_output=True, text=True)
    if proc.returncode != 0:
        return None, proc.stderr.strip()
    if as_json:
        try:
            return json.loads(proc.stdout), proc.stderr.strip()
        except json.JSONDecodeError as e:
            return None, f"json error: {e}"
    return proc.stdout, proc.stderr.strip()


def split_diff_blocks(diff_text):
    blocks = []
    cur = []
    for line in diff_text.splitlines(keepends=True):
        if line.startswith("diff --git") and cur:
            blocks.append(cur)
            cur = []
        cur.append(line)
    if cur:
        blocks.append(cur)
    parsed = []
    for buf in blocks:
        text = "".join(buf)
        path = None
        changed = 0
        logic = 0
        add_ma = 0
        rem_ma = 0
        for line in buf:
            if line.startswith("+++ b/"):
                path = line[6:].rstrip("\n")
            elif line.startswith("+") and not line.startswith("+++"):
                changed += 1
                if LOGIC_RE.search(line):
                    logic = 1
                if DROP_RE.search(line):
                    add_ma += 1
            elif line.startswith("-") and not line.startswith("---"):
                changed += 1
                if LOGIC_RE.search(line):
                    logic = 1
                if DROP_RE.search(line):
                    rem_ma += 1
        drops = max(0, rem_ma - add_ma)
        parsed.append({
            "path": path or "",
            "text": text,
            "diff_bytes": len(text.encode("utf-8")),
            "drops": drops,
            "changed": changed,
            "logic": logic,
        })
    return parsed


def select_fullfiles_and_chunk(blocks, fullfiles_dir, chunk_budget, max_fullfiles=14, ctx_budget=150000, fullfile_lines=20):
    cands = []
    for b in blocks:
        p = b["path"]
        if not p or not fullfiles_dir:
            continue
        fp = os.path.join(fullfiles_dir, p)
        if not os.path.isfile(fp):
            continue
        if b["logic"] == 1 or b["changed"] > fullfile_lines or b["drops"] > 0:
            cands.append((b["drops"], os.path.getsize(fp), p))
    cands.sort(key=lambda t: (-t[0], t[1]))
    attached = {}
    acc = 0
    for _, sz, p in cands:
        if len(attached) >= max_fullfiles:
            break
        acc += sz
        if acc > ctx_budget:
            break
        attached[p] = sz

    chunks = []
    cur_files, cur_texts, acc_b = [], [], 0
    for b in blocks:
        cost = b["diff_bytes"] + attached.get(b["path"], 0)
        if acc_b and acc_b + cost > chunk_budget:
            chunks.append((cur_files, "".join(cur_texts)))
            cur_files, cur_texts, acc_b = [], [], 0
        cur_files.append(b["path"])
        cur_texts.append(b["text"])
        acc_b += cost
    if cur_texts:
        chunks.append((cur_files, "".join(cur_texts)))
    return chunks


def evaluate_case(case, corpus_dir, args, claude_bytes, hoisted_ids, wiki_bytes, detail_map):
    diff_path = os.path.join(corpus_dir, case["artifacts"]["diff_file"])
    fullfiles_dir = os.path.join(corpus_dir, case["artifacts"]["fullfiles_dir"])
    diff_text = open(diff_path, encoding="utf-8", errors="replace").read() if os.path.exists(diff_path) else ""

    det_bytes, det_ids = compute_detail_for_diff(diff_text, detail_map)
    sel_bytes = 0
    sel_json = None
    sel_err = ""
    if args.selector_script and os.path.exists(diff_path) and diff_text.strip():
        sel_json, sel_err = run_selector(args.selector_script, args.memory_root, diff_path, limit=60, as_json=True)
        sel_text, _ = run_selector(args.selector_script, args.memory_root, diff_path, limit=5, as_json=False)
        if isinstance(sel_text, str) and sel_text.strip():
            # mirror ai-review.sh dedupe against DETAIL
            kept_blocks = []
            cur = []
            head_re = re.compile(r"^## (?:\[HOT\] )?((?:R|AP|ADR)-[0-9]+)")
            for ln in sel_text.splitlines(keepends=True):
                m = head_re.match(ln)
                if m:
                    if cur:
                        kept_blocks.append(cur)
                    cur = [ln]
                elif cur:
                    cur.append(ln)
            if cur:
                kept_blocks.append(cur)
            deduped = "".join(
                "".join(b) for b in kept_blocks if head_re.match(b[0]).group(1) not in det_ids
            )
            if deduped.strip():
                hdr = (
                    "\n===== SELECTED MEMORIES (compiled index; top-5 by diff match; FULL text) =====\n"
                    "Estas foram ESCOLHIDAS pelo diff — o score e o motivo vão em cada bloco. Prioridade\n"
                    "sobre as linhas dos índices abaixo, que chegam clampadas e sem seleção.\n\n"
                )
                sel_bytes = len((hdr + deduped).encode("utf-8"))

    pre_bytes = claude_bytes + sel_bytes + wiki_bytes + det_bytes
    chunk_budget = max(30000, 150000 - pre_bytes - 8000)
    blocks = split_diff_blocks(diff_text)
    chunks = select_fullfiles_and_chunk(blocks, fullfiles_dir, chunk_budget)

    # Per-chunk selector evaluation (A1 preview)
    chunk_selected = []
    if args.selector_script and chunks:
        with tempfile.TemporaryDirectory() as td:
            for idx, (cfiles, cdiff) in enumerate(chunks):
                cp = os.path.join(td, f"chunk_{idx}.diff")
                open(cp, "w", encoding="utf-8").write(cdiff)
                cjs, _ = run_selector(args.selector_script, args.memory_root, cp, limit=5, as_json=True)
                ids5 = [r["id"] for r in (cjs or {}).get("selected", [])[:5]]
                chunk_selected.append((set(cfiles), ids5))

    hot_ids = {r["id"] for r in (sel_json or {}).get("hot", [])}
    selected_list = (sel_json or {}).get("selected", [])
    rank_map = {r["id"]: (idx + 1, r.get("score"), r.get("reasons", [])) for idx, r in enumerate(selected_list)}
    top5 = {r["id"] for r in selected_list[:5]}
    top20 = {r["id"] for r in selected_list[:20]}
    top60 = {r["id"] for r in selected_list[:60]}

    expected = (case.get("ground_truth") or {}).get("expected_rules") or []
    # Unique rule_ids for recall metrics; also retain per-instance trace
    unique_expected = {}
    for er in expected:
        rid = er["rule_id"]
        unique_expected.setdefault(rid, []).append(er)

    rule_diag = []
    hit5 = hit20 = hit60 = hit_chunk_union = hit_chunk_scoped = hit_any_door = 0
    n_expected = len(unique_expected)
    for rid, occs in sorted(unique_expected.items()):
        rank, score, reasons = rank_map.get(rid, (None, None, []))
        in5 = rid in top5
        in20 = rid in top20
        in60 = rid in top60
        in_hot = rid in hot_ids
        in_claude = rid in hoisted_ids
        in_detail = rid in det_ids
        in_chunk_union = any(rid in ids5 for _, ids5 in chunk_selected)
        occ_files = {o.get("file") for o in occs if o.get("file")}
        in_chunk_scoped = any(
            (occ_files & cfiles) and (rid in ids5) for cfiles, ids5 in chunk_selected
        )
        if in5:
            hit5 += 1
        if in20:
            hit20 += 1
        if in60:
            hit60 += 1
        if in_chunk_union:
            hit_chunk_union += 1
        if in_chunk_scoped:
            hit_chunk_scoped += 1
        if in5 or in_hot or in_claude or in_detail:
            hit_any_door += 1
        rule_diag.append({
            "rule_id": rid,
            "files": sorted(occ_files),
            "rank": rank,
            "score": score,
            "reasons": reasons,
            "in_hot": in_hot,
            "in_claude_md": in_claude,
            "in_detail": in_detail,
            "in_top5": in5,
            "in_top20": in20,
            "in_top60": in60,
            "in_chunk_top5_union": in_chunk_union,
            "in_chunk_top5_scoped": in_chunk_scoped,
        })

    baseline_obj = {
        "pre_bytes": pre_bytes,
        "chunk_budget": chunk_budget,
        "chunks_planned": len(chunks),
        "selector_recall_at_5": round(hit5 / n_expected, 4) if n_expected else None,
        "selector_recall_at_20": round(hit20 / n_expected, 4) if n_expected else None,
        "selector_recall_at_60": round(hit60 / n_expected, 4) if n_expected else None,
    }
    return {
        "id": case["id"],
        "pr": case["pr"],
        "category": case["category"],
        "diff_bytes": len(diff_text.encode("utf-8")),
        "pre_breakdown": {
            "claude": claude_bytes,
            "selector": sel_bytes,
            "wiki": wiki_bytes,
            "detail": det_bytes,
        },
        "baseline": baseline_obj,
        "n_expected": n_expected,
        "hits": {
            "top5": hit5,
            "top20": hit20,
            "top60": hit60,
            "chunk_top5_union": hit_chunk_union,
            "chunk_top5_scoped": hit_chunk_scoped,
            "any_non_wiki_door_at5": hit_any_door,
        },
        "rule_diag": rule_diag,
        "selector_err": sel_err,
    }


def main():
    ap = argparse.ArgumentParser(description="Validate & evaluate offline RC6 corpus.")
    ap.add_argument("--corpus-dir", required=True)
    ap.add_argument("--schema", required=True)
    ap.add_argument("--selector-script", default=None)
    ap.add_argument("--memory-root", default=None)
    ap.add_argument("--claude-md", default=None)
    ap.add_argument("--rules-idx", default=None)
    ap.add_argument("--ap-idx", default=None)
    ap.add_argument("--update-manifest", action="store_true")
    ap.add_argument("--report-out", default=None)
    args = ap.parse_args()

    manifest_path = os.path.join(args.corpus_dir, "manifest.json")
    manifest = json.load(open(manifest_path, encoding="utf-8"))
    schema = json.load(open(args.schema, encoding="utf-8"))

    errs = validate_schema_node(manifest, schema, schema)
    if errs:
        print("SCHEMA VALIDATION FAILED:", file=sys.stderr)
        for e in errs[:40]:
            print(" ", e, file=sys.stderr)
        sys.exit(2)
    print(f"Schema OK: {len(manifest['cases'])} case(s) in {manifest_path}")

    claude_bytes, hoisted_ids = compute_claude_preamble(args.claude_md)
    wiki_bytes = compute_wiki_bytes(args.rules_idx, args.ap_idx)
    detail_map = build_detail_map(args.memory_root)

    eval_rows = []
    c3_rows = []
    lines_md = [
        "# Relatório Offline do Corpus RC6 (`C7` Baseline + Auditoria `C3`)",
        "",
        f"- **Gerado em:** {datetime.datetime.now().isoformat(timespec='seconds')}",
        f"- **Casos:** {len(manifest['cases'])}",
        "",
        "## 1. Auditoria C3 (Duplicatas Pass A/B e Findings Orphan)",
        "",
        "| PR | Categoria | Inline | Orphan | Candidatos (line_drift / wording / nearby) |",
        "|---|---|---|---|---|",
    ]

    for case in manifest["cases"]:
        c3 = audit_case_c3(case, args.corpus_dir)
        c3_rows.append((case, c3))
        ev = evaluate_case(case, args.corpus_dir, args, claude_bytes, hoisted_ids, wiki_bytes, detail_map)
        eval_rows.append((case, ev))
        if args.update_manifest:
            case["baseline"] = ev["baseline"]
            case["c3_audit"]["orphan_findings"] = c3["orphan_count"]
            case["c3_audit"]["line_drift_duplicates"] = c3["line_drift_dupes"]
            case["c3_audit"]["wording_duplicates"] = c3["wording_dupes"]
            case["c3_audit"]["duplicate_pairs_across_passes"] = c3["line_drift_dupes"] + c3["wording_dupes"]

        if case["category"] == "recent_findings" or c3["inline_count"] or c3["orphan_count"]:
            lines_md.append(
                f"| #{case['pr']} | {case['category']} | {c3['inline_count']} | {c3['orphan_count']} | "
                f"{len(c3['candidates'])} ({c3['line_drift_dupes']} / {c3['wording_dupes']} / "
                f"{len(c3['candidates']) - c3['line_drift_dupes'] - c3['wording_dupes']}) |"
            )

    if args.update_manifest:
        with open(manifest_path, "w", encoding="utf-8") as fh:
            json.dump(manifest, fh, ensure_ascii=False, indent=2)
            fh.write("\n")

    lines_md += ["", "### Pares candidatos para inspeção manual (`C3`)", ""]
    any_cand = False
    for case, c3 in c3_rows:
        for cand in c3["candidates"]:
            any_cand = True
            lines_md.append(
                f"- **PR #{case['pr']}** `{cand['file']}` L{cand['line_a']} vs L{cand['line_b']} "
                f"(dist={cand['dist']}, jaccard={cand['jaccard']}, kind=`{cand['kind']}`) · "
                f"`{cand['rule_a']}` vs `{cand['rule_b']}`\n"
                f"  - A: {cand['issue_a']}\n"
                f"  - B: {cand['issue_b']}"
            )
    if not any_cand:
        lines_md.append("- Nenhum par candidato encontrado.")

    lines_md += [
        "",
        "## 2. Baseline do Seletor (`select-rules.mjs`) e Chunking",
        "",
        "| Case | PR | Categoria | Diff B | PRE B | Budget | Chunks | Expected | R@5 | R@20 | R@60 | Chunk@5 (scoped/union) | Non-wiki@5 (incl. CLAUDE/DETAIL/HOT) |",
        "|---|---|---|---|---|---|---|---|---|---|---|---|---|",
    ]

    agg = defaultdict(lambda: defaultdict(int))
    for case, ev in eval_rows:
        n = ev["n_expected"]
        h = ev["hits"]
        b = ev["baseline"]
        cat = case["category"]
        if n > 0:
            for k in ("top5", "top20", "top60", "chunk_top5_union", "chunk_top5_scoped", "any_non_wiki_door_at5"):
                agg[cat][k] += h[k]
                agg["ALL"][k] += h[k]
            agg[cat]["n"] += n
            agg["ALL"]["n"] += n
        r5 = f"{h['top5']}/{n}" if n else "-"
        r20 = f"{h['top20']}/{n}" if n else "-"
        r60 = f"{h['top60']}/{n}" if n else "-"
        rc = f"{h['chunk_top5_scoped']}/{h['chunk_top5_union']}/{n}" if n else "-"
        ra = f"{h['any_non_wiki_door_at5']}/{n}" if n else "-"
        lines_md.append(
            f"| {case['id']} | #{case['pr']} | {cat} | {ev['diff_bytes']} | {b['pre_bytes']} | "
            f"{b['chunk_budget']} | {b['chunks_planned']} | {n} | {r5} | {r20} | {r60} | {rc} | {ra} |"
        )

    # Canonical 078 check (768, 801, 812)
    c078_ids = {"classic-pr768", "classic-pr801", "classic-pr812"}
    c078_hits = sum(ev["hits"]["top5"] for case, ev in eval_rows if case["id"] in c078_ids)
    c078_tot = sum(ev["n_expected"] for case, ev in eval_rows if case["id"] in c078_ids)

    lines_md += ["", "### Resumo Agregado de Recall", ""]
    for grp in ("classic_benchmark", "recent_findings", "ALL"):
        g = agg[grp]
        n = g["n"]
        if not n:
            continue
        lines_md.append(
            f"- **{grp}** (`n={n}` regras únicas por PR): "
            f"`recall@5={g['top5']}/{n}` ({100*g['top5']/n:.1f}%), "
            f"`recall@20={g['top20']}/{n}` ({100*g['top20']/n:.1f}%), "
            f"`recall@60={g['top60']}/{n}` ({100*g['top60']/n:.1f}%), "
            f"`chunk@5_scoped={g['chunk_top5_scoped']}/{n}` ({100*g['chunk_top5_scoped']/n:.1f}%), "
            f"`chunk@5_union={g['chunk_top5_union']}/{n}` ({100*g['chunk_top5_union']/n:.1f}%), "
            f"`non_wiki@5={g['any_non_wiki_door_at5']}/{n}` ({100*g['any_non_wiki_door_at5']/n:.1f}%)"
        )
    if c078_tot:
        lines_md.append(f"- **Canônico `078` (`768, 801, 812`)**: `recall@5 = {c078_hits}/{c078_tot}`")

    lines_md += ["", "### Diagnóstico por Regra Esperada", ""]
    for case, ev in eval_rows:
        if not ev["rule_diag"]:
            continue
        lines_md.append(f"#### PR #{case['pr']} (`{case['id']}`)")
        for rd in ev["rule_diag"]:
            doors = []
            if rd["in_claude_md"]:
                doors.append("CLAUDE.md")
            if rd["in_hot"]:
                doors.append("HOT")
            if rd["in_detail"]:
                doors.append("DETAIL")
            if rd["in_top5"]:
                doors.append("sel@5")
            elif rd["in_top20"]:
                doors.append("sel@20")
            elif rd["in_top60"]:
                doors.append("sel@60")
            if rd["in_chunk_top5_scoped"]:
                doors.append("chunk@5-scoped")
            elif rd["in_chunk_top5_union"]:
                doors.append("chunk@5-union")
            lines_md.append(
                f"- `{rd['rule_id']}` (rank={rd['rank']}, score={rd['score']}) · "
                f"portas=[{', '.join(doors) if doors else 'MISS'}] · files={rd['files']}"
            )

    report_txt = "\n".join(lines_md) + "\n"
    if args.report_out:
        os.makedirs(os.path.dirname(args.report_out), exist_ok=True)
        with open(args.report_out, "w", encoding="utf-8") as fh:
            fh.write(report_txt)

    # Print concise stdout summary
    print(f"Canonical 078 (768,801,812) recall@5 = {c078_hits}/{c078_tot}")
    for grp in ("classic_benchmark", "recent_findings", "ALL"):
        g = agg[grp]
        if g["n"]:
            print(
                f"  {grp}: n={g['n']} R@5={g['top5']}/{g['n']} R@20={g['top20']}/{g['n']} "
                f"R@60={g['top60']}/{g['n']} chunk@5(scoped={g['chunk_top5_scoped']},union={g['chunk_top5_union']}) "
                f"non_wiki@5={g['any_non_wiki_door_at5']}/{g['n']}"
            )
    tot_inline = sum(c3["inline_count"] for _, c3 in c3_rows if _["category"] == "recent_findings")
    tot_orphan = sum(c3["orphan_count"] for _, c3 in c3_rows if _["category"] == "recent_findings")
    tot_cands = sum(len(c3["candidates"]) for _, c3 in c3_rows if _["category"] == "recent_findings")
    print(f"C3 audit (recent_findings): inline={tot_inline}, orphan={tot_orphan}, candidate_pairs={tot_cands}")
    for case, c3 in c3_rows:
        for cand in c3["candidates"]:
            print(
                f"  CANDIDATE PR#{case['pr']} {cand['file']}:{cand['line_a']} vs :{cand['line_b']} "
                f"({cand['kind']}, j={cand['jaccard']}, {cand['rule_a']} vs {cand['rule_b']})"
            )


if __name__ == "__main__":
    main()
