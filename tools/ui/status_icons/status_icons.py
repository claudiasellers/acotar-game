"""Turns the status_icons.mjs PNGs into lossless WebP (R15) and removes the PNGs."""
import pathlib
from PIL import Image

OUT = pathlib.Path(__file__).resolve().parents[3] / "ui/theme/icons/status"
n = 0
for png in sorted(OUT.glob("*.png")):
    Image.open(png).convert("RGBA").save(png.with_suffix(".webp"), "WEBP", lossless=True, method=6)
    png.unlink()
    n += 1
print(f"status_icons: {n} webp in {OUT}")
