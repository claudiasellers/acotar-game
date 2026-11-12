"""Paints the candyfloss tree's spun-sugar wisps (tools/woods/blender/
special_trees.py lays them on the tree; world/spring_court/shared/
woods_floss.gdshader draws them): world/spring_court/shared/models/
floss_wisp.png, four wisps in a 2 x 2 sheet. Each is a skein of fine sugar
threads running its length: a dense middle that thins to single stray
threads at its ends and edges. RGB is the threads' painted light and dark
(the shader colours them), alpha their cover.

Run:  python3 tools/woods/gen_floss_wisp.py [out.png]
Deterministic. Needs numpy and Pillow.
"""

import math
import os
import random
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

W, H = 512, 256          # one wisp
SS = 2                   # painted at twice the size, then reduced


def wisp(seed, threads, spread, wave):
    rng = random.Random(seed)
    cover = np.zeros((H * SS, W * SS), np.float32)
    light = np.zeros((H * SS, W * SS), np.float32)
    weight = np.zeros((H * SS, W * SS), np.float32)
    drift = rng.uniform(-0.05, 0.05)
    for _ in range(threads):
        # where the thread lies across the skein: mostly near the middle
        y0 = 0.5 + rng.gauss(0.0, spread)
        if not 0.04 < y0 < 0.96:
            continue
        # the middle's threads run nearly the whole length; the outer ones are short strays
        off = abs(y0 - 0.5) / 0.5
        length = rng.uniform(0.55, 0.98) * (1.0 - 0.55 * off)
        x0 = rng.uniform(0.01, 0.99 - length)
        amp = rng.uniform(0.2, 1.0) * wave
        freq = rng.uniform(0.6, 1.8)
        phase = rng.uniform(0.0, math.tau)
        lift = rng.uniform(-0.06, 0.06) + drift
        value = rng.uniform(0.45, 1.0)
        width = rng.choice((1, 1, 2, 2, 3)) * SS // 2 + 1
        layer = Image.new("L", (W * SS, H * SS), 0)
        draw = ImageDraw.Draw(layer)
        pts = []
        n = 48
        for i in range(n + 1):
            t = i / n
            x = x0 + length * t
            y = y0 + amp * math.sin(freq * math.tau * t + phase) + lift * (t - 0.5)
            pts.append((x * W * SS, y * H * SS))
        # a thread thins to nothing at each end
        for i in range(n):
            t = (i + 0.5) / n
            fade = min(1.0, t / 0.16, (1.0 - t) / 0.16)
            draw.line([pts[i], pts[i + 1]], fill=int(255 * fade), width=width)
        a = np.asarray(layer.filter(ImageFilter.GaussianBlur(0.6 * SS)), np.float32) / 255.0
        cover = 1.0 - (1.0 - cover) * (1.0 - a * 0.9)
        light += a * value
        weight += a
    # The fleece: the body of the skein under the threads, a soft lens that
    # breaks into streaks toward its edge, so the outline is threads, not a
    # shape, and the wisp still covers when the picture is small and far off.
    ys, xs = np.mgrid[0:H * SS, 0:W * SS].astype(np.float32)
    u = xs / (W * SS)
    v = ys / (H * SS)
    rows = np.array([rng.random() for _ in range(H * SS // 3 + 2)], np.float32)
    bend = 0.012 * np.sin(u * math.tau * 1.3 + seed)
    streak = np.interp(((v + bend) * (H * SS / 3.0)).ravel(), np.arange(rows.size), rows).reshape(v.shape)
    lens = 1.45 - ((u - 0.5) / 0.49) ** 2 - ((v - 0.5) / 0.44) ** 2
    body = np.clip(lens, 0.0, 1.0)
    fleece = np.clip((body - streak * (1.1 - 0.85 * body)) * 3.0, 0.0, 1.0)
    cover = 1.0 - (1.0 - cover) * (1.0 - fleece)
    light += fleece * (0.62 + 0.3 * streak)
    weight += fleece
    value = np.where(weight > 1e-4, light / np.maximum(weight, 1e-4), 0.75)
    # the dense middle reads a little deeper than the stray threads round it
    value = np.clip(value * (1.08 - 0.22 * np.clip(weight / 6.0, 0.0, 1.0)), 0.0, 1.0)
    img = np.dstack([value, value, value, np.clip(cover, 0.0, 1.0)])
    out = Image.fromarray((img * 255).astype(np.uint8), "RGBA").resize((W, H), Image.LANCZOS)
    return out


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, "..", "..", "world", "spring_court", "shared", "models", "floss_wisp.png")
    sheet = Image.new("RGBA", (W * 2, H * 2), (190, 190, 190, 0))
    recipes = [(11, 170, 0.2, 0.03), (23, 140, 0.18, 0.05), (37, 190, 0.21, 0.025), (41, 120, 0.17, 0.06)]
    for i, (seed, threads, spread, wave) in enumerate(recipes):
        sheet.paste(wisp(seed, threads, spread, wave), ((i % 2) * W, (i // 2) * H))
    # colour under the clear parts so the edges do not darken when the picture is shrunk
    a = np.asarray(sheet, np.float32)
    rgb = np.where(a[..., 3:4] > 8, a[..., :3], 200.0)
    Image.fromarray(np.dstack([rgb, a[..., 3:4]]).astype(np.uint8), "RGBA").save(out)
    cov = (a[..., 3] > 127).mean()
    print("%s  %dx%d  cover %.0f%%" % (os.path.relpath(out), W * 2, H * 2, cov * 100))


if __name__ == "__main__":
    main()
