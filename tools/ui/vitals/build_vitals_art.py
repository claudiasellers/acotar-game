#!/usr/bin/env python3
"""Builds every vitals HUD texture (plan §15 A-F) into ui/hud/vitals/art/.

Run:  python3 tools/ui/vitals/build_vitals_art.py [--only medallion] [--sheets DIR]
Needs: Pillow, numpy, node with the `playwright` package (headless Chromium).

The art is drawn as SVG in va_pictos.py, va_meters.py and va_edges.py,
rasterised by render_svgs.mjs, then saved as PNG (icons, frames; 256 px
masters get a `_128` twin) or WebP (the big screen-edge maps). Fixed seeds:
the same commit always gives the same pixels. --sheets also writes the
contact sheet and the three mock frames (va_checkpoint.py).
"""
import os
import shutil
import subprocess
import sys
import tempfile

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
OUT = os.path.normpath(os.path.join(HERE, "..", "..", "..", "ui", "hud", "vitals", "art"))

import va_edges  # noqa: E402
import va_meters  # noqa: E402
import va_pictos  # noqa: E402


def main() -> None:
    only = sys.argv[sys.argv.index("--only") + 1] if "--only" in sys.argv else ""
    sheets = sys.argv[sys.argv.index("--sheets") + 1] if "--sheets" in sys.argv else ""
    assets = {}
    for mod in (va_pictos, va_meters, va_edges):
        mod.build(assets)
    if only:
        assets = {k: v for k, v in assets.items() if k.startswith(only)}
    tmp = tempfile.mkdtemp(prefix="vitals_art_")
    svg_dir, png_dir = os.path.join(tmp, "svg"), os.path.join(tmp, "png")
    os.makedirs(svg_dir)
    for name, a in assets.items():
        if "svg" in a:
            with open(os.path.join(svg_dir, name.replace("/", "__") + ".svg"), "w") as fh:
                fh.write(a["svg"])
    subprocess.run(["node", os.path.join(HERE, "render_svgs.mjs"), svg_dir, png_dir], check=True)
    count = 0
    for name, a in assets.items():
        dst = os.path.join(OUT, name)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        if "svg" in a:
            img = Image.open(os.path.join(png_dir, name.replace("/", "__") + ".png")).convert("RGBA")
        else:
            img = a["image"]
        if "post" in a:
            img = a["post"](img)
        if a.get("webp"):
            img.save(dst + ".webp", quality=a.get("quality", 90), method=6)
        else:
            img.save(dst + ".png", optimize=True)
            if a.get("half"):
                img.resize((img.width // 2, img.height // 2), Image.LANCZOS).save(dst + "_128.png", optimize=True)
        count += 1
    shutil.rmtree(tmp)
    print(f"built {count} assets into {OUT}")
    if sheets:
        import va_checkpoint
        va_checkpoint.build(OUT, sheets)


if __name__ == "__main__":
    main()
