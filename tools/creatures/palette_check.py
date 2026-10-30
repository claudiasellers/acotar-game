"""Palette test (experience bar §3.2) for Spring Court creatures and people:
no material may sit in the banned lime/acid-green family.

Run: python3 tools/creatures/palette_check.py   (exit 1 on any hit)
Reads glTF baseColorFactor (linear) from the court model folders and swarm
colours from the ambient scenes, converts to sRGB and checks hue/saturation.
"""

import colorsys
import glob
import json
import os
import re
import sys

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
MODELS = ["creatures/models/spring", "creatures/models/people"]
SCENES = "creatures/ambient/scenes/*.tscn"


def srgb(c):
    return [12.92 * v if v <= 0.0031308 else 1.055 * v ** (1 / 2.4) - 0.055 for v in c]


def lime(rgb):
    h, s, v = colorsys.rgb_to_hsv(*rgb)
    return 70 <= h * 360 <= 150 and s > 0.55 and v > 0.55


def main():
    hits = []
    for folder in MODELS:
        for path in sorted(glob.glob(os.path.join(ROOT, folder, "*.gltf"))):
            with open(path) as f:
                doc = json.load(f)
            for m in doc.get("materials", []):
                base = m.get("pbrMetallicRoughness", {}).get("baseColorFactor", [1, 1, 1, 1])
                if lime(srgb(base[:3])):
                    hits.append(f"{os.path.basename(path)}: {m.get('name')} {base[:3]}")
    for path in sorted(glob.glob(os.path.join(ROOT, SCENES))):
        text = open(path).read()
        for match in re.finditer(r"colors = PackedColorArray\(([^)]*)\)", text):
            vals = [float(x) for x in match.group(1).split(",")]
            for i in range(0, len(vals), 4):
                if lime(vals[i:i + 3]):
                    hits.append(f"{os.path.basename(path)}: swarm colour {vals[i:i + 3]}")
    for h in hits:
        print("LIME:", h)
    print(f"palette check: {len(hits)} lime materials")
    return 1 if hits else 0


if __name__ == "__main__":
    sys.exit(main())
