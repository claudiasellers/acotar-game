"""Turns the tend_icons.mjs PNGs into 128 px lossless WebP (R15) and removes the PNGs."""
import pathlib
from PIL import Image

OUT = pathlib.Path(__file__).resolve().parents[3] / "ui/theme/icons/tend"
n = 0
for png in sorted(OUT.glob("*.png")):
    Image.open(png).convert("RGBA").resize((128, 128), Image.LANCZOS).save(png.with_suffix(".webp"), "WEBP", lossless=True, method=6)
    png.unlink()
    n += 1
print(f"tend_icons: {n} webp in {OUT}")
