#!/usr/bin/env python3
"""Paints the journal's paper: a near-white canvas page with a faint weave,
fine grain and a deckled edge, as a 9-patch the theme tints per act.
Run from the repo root: python3 tools/ui_theme/build_journal_paper.py
Writes ui/theme/paper/page.png and ui/theme/paper/slip.png (fixed seed)."""
import numpy as np
from PIL import Image

SEED = 77


def paper(size: int, edge: int, deckle: float, seed: int) -> Image.Image:
    rng = np.random.default_rng(seed)
    y, x = np.mgrid[0:size, 0:size].astype(np.float32)
    # Canvas weave: two crossed threads, a few percent of luminance.
    weave = 0.018 * (np.sin(x * np.pi / 2.0) * np.sin(y * np.pi / 2.0))
    weave += 0.010 * np.sin(x * np.pi / 1.0 + 0.6) * 0.5
    weave += 0.010 * np.sin(y * np.pi / 1.0 + 1.1) * 0.5
    mid = size - 2 * edge
    lum = np.clip(0.972 + weave + rng.normal(0.0, 0.005, (size, size)), 0.0, 1.0)

    # Deckle: the page's outline drifts in and out by a pixel or two, in
    # slow waves that repeat with the middle so the tiled edge has no teeth.
    def wobble(n: int) -> np.ndarray:
        t = (np.arange(n, dtype=np.float32) - edge) / mid * 2.0 * np.pi
        w = sum(rng.uniform(0.4, 1.0) / k * np.sin(k * t + rng.uniform(0.0, 2.0 * np.pi)) for k in (1, 2, 3, 5))
        return w / (np.abs(w).max() + 1e-6) * deckle

    inset = deckle + 2.0
    left, right, top, bottom = wobble(size), wobble(size), wobble(size), wobble(size)
    d = np.minimum.reduce([
        x - (inset + left[y.astype(int)]),
        (size - 1 - x) - (inset + right[y.astype(int)]),
        y - (inset + top[x.astype(int)]),
        (size - 1 - y) - (inset + bottom[x.astype(int)]),
    ])
    alpha = np.clip(d + 0.5, 0.0, 1.0)
    # A soft shade just inside the edge, where a torn sheet thins.
    rim = np.clip(1.0 - d / float(edge) * 2.2, 0.0, 1.0) ** 2
    lum = lum * (1.0 - 0.07 * rim)
    rgba = np.dstack([lum, lum, lum, alpha])
    return Image.fromarray((rgba * 255.0 + 0.5).astype(np.uint8), "RGBA")


if __name__ == "__main__":
    paper(192, 40, 2.0, SEED).save("ui/theme/paper/page.png")
    paper(96, 20, 1.2, SEED + 1).save("ui/theme/paper/slip.png")
