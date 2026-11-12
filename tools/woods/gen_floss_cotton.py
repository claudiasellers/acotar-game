"""Paints the candyfloss tree's cotton (world/spring_court/shared/
woods_floss.gdshader lays it over the tree from three sides):
world/spring_court/shared/models/floss_cotton.png, a tile that repeats.
RGB is the fluff's light and dark, soft cloudy mottling; alpha is the cover
of the fuzz that stands off the surface, small soft tufts over about half
the tile.

Run:  python3 tools/woods/gen_floss_cotton.py [out.png]
Deterministic. Needs numpy and Pillow.
"""

import os
import sys

import numpy as np
from PIL import Image

N = 512


def cloud(rng, low, high, slope):
    """Repeating noise with its energy between `low` and `high` cycles a
    tile, falling off as 1 / f^slope; scaled to 0..1."""
    f = np.fft.fftfreq(N) * N
    fx, fy = np.meshgrid(f, f)
    r = np.sqrt(fx * fx + fy * fy)
    amp = np.where((r >= low) & (r <= high), 1.0 / np.maximum(r, 1.0) ** slope, 0.0)
    spec = amp * np.exp(1j * rng.uniform(0.0, 2.0 * np.pi, (N, N)))
    img = np.real(np.fft.ifft2(spec))
    lo, hi = np.percentile(img, (1.0, 99.0))
    return np.clip((img - lo) / (hi - lo), 0.0, 1.0)


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, "..", "..", "world", "spring_court", "shared", "models", "floss_cotton.png")
    rng = np.random.default_rng(20261112)
    # the fluff's light and dark: broad soft billows with finer puffs on them
    value = 0.62 * cloud(rng, 2, 14, 1.3) + 0.38 * cloud(rng, 10, 60, 1.0)
    value = 0.45 + 0.55 * value
    # the fuzz: small soft tufts, about half the tile
    tufts = 0.7 * cloud(rng, 9, 26, 0.6) + 0.3 * cloud(rng, 24, 80, 0.8)
    cut = np.percentile(tufts, 48.0)
    cover = np.clip((tufts - cut) / 0.07 + 0.5, 0.0, 1.0)
    img = np.dstack([value, value, value, cover])
    Image.fromarray((img * 255).astype(np.uint8), "RGBA").save(out)
    print("%s  %dx%d  fuzz cover %.0f%%" % (os.path.relpath(out), N, N, (cover > 0.5).mean() * 100))


if __name__ == "__main__":
    main()
