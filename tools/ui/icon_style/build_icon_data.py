#!/usr/bin/env python3
"""Rebuild icon_data.json: one row per icon file the game loads, with the name,
description and colour from the item's data file. Run from the repo root:

    python3 tools/ui/icon_style/build_icon_data.py

The drawings in set_*.mjs read colours from this table, so a new colour of an
existing outfit only needs its .webp name to exist (or be added to EXTRA below)
and a rerun of this script.
"""
import glob, json, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
EXTRA = {}  # id -> folder, for an icon that has no .webp yet


def parse(path):
    text = open(path, encoding="utf-8").read()
    d = {}
    for key in ["id", "display_name", "description", "color", "icon", "mesh_path"]:
        m = re.search(r"^%s = (.*)$" % key, text, re.M)
        if m:
            d[key] = m.group(1)
    m = re.match(r"Color\(([^)]*)\)", d.get("color", ""))
    if m:
        v = [float(x) for x in m.group(1).split(",")[:3]]
        d["hex"] = "#%02X%02X%02X" % tuple(round(x * 255) for x in v)
    return d


def main():
    want = {}
    for folder in ["items", "wardrobe", "brews"]:
        for f in sorted(glob.glob("ui/theme/icons/%s/*.webp" % folder)):
            want[os.path.basename(f)[:-5]] = folder
    want.update(EXTRA)
    by_id = {}
    for f in sorted(glob.glob("data/**/*.tres", recursive=True)):
        p = parse(f)
        if "id" in p:
            by_id.setdefault(p["id"].strip('&"'), (f, p))
    out, missing = {}, []
    for i, folder in want.items():
        if i not in by_id:
            missing.append(i)
            continue
        f, p = by_id[i]
        out[i] = {
            "cat": folder, "file": f,
            "name": p.get("display_name", "").strip('"'),
            "desc": p.get("description", "").strip('"'),
            "hex": p.get("hex"), "icon": p.get("icon", "").strip('&"'),
            "mesh": os.path.basename(p.get("mesh_path", "").strip('"')),
        }
    json.dump(out, open(os.path.join(HERE, "icon_data.json"), "w"), indent=0)
    print("wrote %d rows" % len(out))
    if missing:
        print("no data file for:", " ".join(missing), file=sys.stderr)


if __name__ == "__main__":
    main()
