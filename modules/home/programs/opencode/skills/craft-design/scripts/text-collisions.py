#!/usr/bin/env python3
"""Fail when an edge comes near text in a Graphviz diagram.

Text boxes and edge paths both come from `dot -Tjson` (xdot), so widths are
measured, not guessed. Graphviz happily routes an arrow through a cluster
title or another edge's label; no checklist catches that by eye at note width,
so it is measured here. Node text is excluded: the node border protects it,
and an edge that reaches it is a different defect.

    text-collisions.py diagram.dot [--gap=8]

Points, origin bottom-left. Exit 1 on a finding.
"""

import json
import subprocess
import sys


def texts(ops):
    """Text boxes from an xdot draw list: (text, x0, y0, x1, y1)."""
    out, size = [], 12.0
    for op in ops:
        if op.get("op") == "F":
            size = float(op.get("size", size))
        if op.get("op") != "T":
            continue
        text = op.get("text", "")
        if not text.strip():
            continue
        x, y = op["pt"]
        w = float(op.get("width", 0.0))
        align = op.get("align", "l")
        x0 = x - w / 2 if align == "c" else (x - w if align == "r" else x)
        out.append((text, x0, y - 0.75 * size, x0 + w, y + 0.25 * size))
    return out


def path(ops):
    """Sample the splines of an edge (`b` ops) into points."""
    pts = []
    for op in ops:
        if op.get("op") != "b":
            continue
        p = [tuple(map(float, q)) for q in op.get("points", [])]
        if len(p) < 2:
            continue
        pts.append(p[0])
        i = 1
        while i + 2 < len(p):
            p0, p1, p2, p3 = p[i - 1], p[i], p[i + 1], p[i + 2]
            for k in range(1, 21):
                t = k / 20
                u = 1 - t
                pts.append(
                    (
                        u**3 * p0[0]
                        + 3 * u * u * t * p1[0]
                        + 3 * u * t * t * p2[0]
                        + t**3 * p3[0],
                        u**3 * p0[1]
                        + 3 * u * u * t * p1[1]
                        + 3 * u * t * t * p2[1]
                        + t**3 * p3[1],
                    )
                )
            i += 3
    return pts


def gap_to(px, py, box):
    _, x0, y0, x1, y1 = box
    dx = max(x0 - px, 0.0, px - x1)
    dy = max(y0 - py, 0.0, py - y1)
    return (dx * dx + dy * dy) ** 0.5


def inside(px, py, box):
    _, x0, y0, x1, y1 = box
    return x0 <= px <= x1 and y0 <= py <= y1


def main():
    gap = 8.0
    args = []
    for a in sys.argv[1:]:
        if a.startswith("--gap="):
            gap = float(a.split("=", 1)[1])
        else:
            args.append(a)
    if not args:
        print(__doc__)
        return 2

    out = subprocess.run(
        ["dot", "-Tjson", args[0]], capture_output=True, check=True
    ).stdout
    data = json.loads(out)

    # graph title and each cluster title
    titles = [(t, *b) for t, *b in texts(data.get("_ldraw_", []))]
    for obj in data.get("objects", []):
        if obj.get("name", "").startswith("cluster"):
            titles += [(t, *b) for t, *b in texts(obj.get("_ldraw_", []))]

    findings = []
    for e in data.get("edges", []):
        pts = path(e.get("_draw_", []))
        if not pts:
            continue

        def near(box, label, where):
            d = min(gap_to(px, py, box) for px, py in pts)
            hit = any(inside(px, py, box) for px, py in pts)
            if hit or d < gap:
                findings.append((0.0 if hit else d, label, e, where, hit))

        for text, x0, y0, x1, y1 in titles:
            near(("", x0, y0, x1, y1), text.strip(), "cluster/graph title")

        for f in data.get("edges", []):
            if f is e:
                continue
            for text, x0, y0, x1, y1 in texts(f.get("_ldraw_", [])):
                near(
                    ("", x0, y0, x1, y1),
                    text.strip(),
                    f"label of {f.get('tail')}->{f.get('head')}",
                )

    for d, text, e, where, hit in sorted(findings, key=lambda r: (not r[4], r[0])):
        state = "THROUGH the box" if hit else f"gap {d:4.1f}pt"
        print(f"{state}  {text!r} ({where})  edge {e.get('tail')} -> {e.get('head')}")
    print(
        f"{len(findings)} finding(s): a title or label box entered, or closer than {gap:g}pt"
    )
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
