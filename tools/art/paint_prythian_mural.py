#!/usr/bin/env python3
"""Paints the study mural of Prythian's history (ch13, L28), deterministic.

Run:  python3 tools/art/paint_prythian_mural.py
Out:  art/house/prythian_mural.webp (2048 x 1228, WebP q85, R15 <= 2K)
      and prints the five notice spots as UV (0..1, origin top-left), which
      tools/story/gen_house_beats.py copies into the mural's stage data.

Canon (lore/01-world/prythian-overview.md, spring-manor-house.md): a mural of
Prythian's history: the War, the seven courts, the mountain at the centre that
belongs to no court. Prythian is a massive island; humans hold only its bottom
tip, south of the Wall, drawn as a dark smear. Spring is the southernmost
court, painted with crocuses, lambs and roses. Court positions are map lore
[C?]; the brushwork, palette and the War frieze are canon:"X" (R3 pastels).
"""

import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "art/house/prythian_mural.webp")
W, H = 2048, 1228
RNG = random.Random(1213)

SEA = (196, 214, 238)
SEA_DEEP = (168, 186, 226)
PARCH = (252, 244, 232)
LAND = (240, 228, 206)
INK = (92, 56, 86)
GOLD = (230, 192, 104)

# Court washes (R3 pastels; positions as the later maps, [C?]).
COURTS = {
    "night": ((1020, 250), 210, (122, 112, 176)),
    "winter": ((1390, 360), 190, (210, 226, 246)),
    "day": ((1330, 600), 160, (252, 226, 150)),
    "dawn": ((1560, 640), 140, (250, 196, 196)),
    "autumn": ((640, 560), 190, (236, 168, 120)),
    "summer": ((620, 840), 150, (150, 214, 200)),
    "spring": ((1020, 860), 210, (196, 232, 180)),
}
SPOTS = {}


def blob(cx, cy, r, n=48, wobble=0.18, squash=1.0, seed=0):
    rng = random.Random(seed)
    phase = [rng.uniform(0, 6.28) for _ in range(4)]
    pts = []
    for i in range(n):
        a = 2 * math.pi * i / n
        k = 1 + wobble * (0.6 * math.sin(3 * a + phase[0]) + 0.3 * math.sin(5 * a + phase[1]) + 0.2 * math.sin(9 * a + phase[2]))
        pts.append((cx + r * k * math.cos(a), cy + r * k * math.sin(a) * squash))
    return pts


def strokes(d, box, color, n, length, width, angle=0.0, jitter=0.6):
    x0, y0, x1, y1 = box
    for _ in range(n):
        x, y = RNG.uniform(x0, x1), RNG.uniform(y0, y1)
        a = angle + RNG.uniform(-jitter, jitter)
        dx, dy = math.cos(a) * length / 2, math.sin(a) * length / 2
        c = tuple(max(0, min(255, v + RNG.randint(-10, 10))) for v in color)
        d.line([(x - dx, y - dy), (x + dx, y + dy)], fill=c + (90,), width=width)


def crocus(d, x, y, s):
    for k in (-1, 0, 1):
        d.ellipse([x + k * s * 0.35 - s * 0.22, y - s, x + k * s * 0.35 + s * 0.22, y], fill=(186, 150, 226))
    d.ellipse([x - s * 0.2, y - s * 0.95, x + s * 0.2, y - s * 0.2], fill=(214, 186, 242))
    d.line([(x, y), (x, y + s * 0.6)], fill=(120, 190, 140), width=max(2, int(s * 0.12)))
    d.ellipse([x - s * 0.06, y - s * 0.55, x + s * 0.06, y - s * 0.4], fill=(250, 210, 110))


def lamb(d, x, y, s):
    for i in range(7):
        a = 2 * math.pi * i / 7
        d.ellipse([x + math.cos(a) * s * 0.45 - s * 0.32, y + math.sin(a) * s * 0.28 - s * 0.32,
                   x + math.cos(a) * s * 0.45 + s * 0.32, y + math.sin(a) * s * 0.28 + s * 0.32], fill=(255, 252, 246))
    d.ellipse([x + s * 0.55, y - s * 0.45, x + s * 1.0, y - s * 0.05], fill=(246, 224, 214))
    d.ellipse([x + s * 0.8, y - s * 0.32, x + s * 0.86, y - s * 0.26], fill=INK)
    for k in (-0.4, -0.1, 0.25, 0.5):
        d.line([(x + k * s, y + s * 0.3), (x + k * s, y + s * 0.62)], fill=(150, 120, 120), width=max(2, int(s * 0.1)))


def rose(d, x, y, s):
    d.ellipse([x - s, y - s, x + s, y + s], fill=(240, 150, 176))
    d.ellipse([x - s * 0.65, y - s * 0.65, x + s * 0.65, y + s * 0.65], fill=(250, 186, 204))
    d.arc([x - s * 0.5, y - s * 0.5, x + s * 0.5, y + s * 0.5], 30, 300, fill=(206, 106, 140), width=max(2, int(s * 0.18)))
    d.ellipse([x + s * 0.7, y + s * 0.2, x + s * 1.5, y + s * 0.7], fill=(130, 196, 150))


def figure(d, x, y, s, color, wings=False, chained=False):
    d.ellipse([x - s * 0.18, y - s, x + s * 0.18, y - s * 0.64], fill=color)
    d.polygon([(x - s * 0.28, y), (x + s * 0.28, y), (x + s * 0.12, y - s * 0.62), (x - s * 0.12, y - s * 0.62)], fill=color)
    if wings:
        d.polygon([(x - s * 0.1, y - s * 0.55), (x - s * 0.7, y - s * 0.95), (x - s * 0.5, y - s * 0.3)], fill=color)
        d.polygon([(x + s * 0.1, y - s * 0.55), (x + s * 0.7, y - s * 0.95), (x + s * 0.5, y - s * 0.3)], fill=color)
    if chained:
        for k in range(3):
            d.ellipse([x - s * 0.5 + k * s * 0.22, y - s * 0.4, x - s * 0.3 + k * s * 0.22, y - s * 0.28], outline=GOLD, width=2)


def main():
    img = Image.new("RGB", (W, H), PARCH)
    paint = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(paint)
    # The sea round the island, in soft periwinkle strokes.
    d.rectangle([60, 150, W - 60, H - 60], fill=SEA + (255,))
    strokes(d, (90, 170, W - 90, H - 80), SEA_DEEP, 700, 46, 4, 0.0, 0.2)
    # The island: one massive landmass, its bottom tip running south.
    island = blob(1040, 640, 560, 72, 0.12, 0.78, seed=3) + []
    d.polygon(island, fill=LAND + (255,))
    d.polygon([(860, 980), (1220, 980), (1110, 1150), (1000, 1160)], fill=LAND + (255,))
    # Court washes, blurred later into soft watercolour.
    # Each wash is a blurred mask filled with its own colour (no dark halos).
    for i, (name, ((cx, cy), r, col)) in enumerate(COURTS.items()):
        mask = Image.new("L", (W, H), 0)
        ImageDraw.Draw(mask).polygon(blob(cx, cy, r, 40, 0.22, 0.75, seed=10 + i), fill=210)
        mask = mask.filter(ImageFilter.GaussianBlur(14))
        paint.paste(Image.new("RGBA", (W, H), col + (255,)), (0, 0), mask)
    d = ImageDraw.Draw(paint)
    # Night: stars over deep hills in the far north.
    for _ in range(60):
        x, y = RNG.uniform(860, 1180), RNG.uniform(140, 330)
        r = RNG.uniform(2, 5)
        d.ellipse([x - r, y - r, x + r, y + r], fill=(255, 246, 214, 230))
    # Winter: little frosted pines. Autumn: russet leaf dabs. Day/Dawn: suns.
    for _ in range(26):
        x, y = RNG.uniform(1280, 1500), RNG.uniform(290, 440)
        d.polygon([(x, y - 26), (x - 12, y + 6), (x + 12, y + 6)], fill=(170, 196, 232, 255))
    for _ in range(80):
        x, y = RNG.uniform(500, 780), RNG.uniform(460, 680)
        d.ellipse([x - 7, y - 4, x + 7, y + 4], fill=(214, 120, 80, 200))
    for (cx, cy, col) in [(1330, 600, (250, 206, 110)), (1560, 640, (246, 170, 170))]:
        d.ellipse([cx - 34, cy - 34, cx + 34, cy + 34], fill=col + (255,))
        for k in range(12):
            a = 2 * math.pi * k / 12
            d.line([(cx + 44 * math.cos(a), cy + 44 * math.sin(a)), (cx + 62 * math.cos(a), cy + 62 * math.sin(a))], fill=col + (255,), width=6)
    # Summer: a coast of sea-glass waves.
    for k in range(6):
        d.arc([520 + k * 30, 860 + k * 8, 600 + k * 30, 900 + k * 8], 200, 340, fill=(90, 170, 170, 255), width=4)
    # The mountain at the centre, which belongs to no court.
    mx, my = 1040, 560
    d.polygon([(mx - 120, my + 70), (mx, my - 150), (mx + 120, my + 70)], fill=(150, 136, 168, 255))
    d.polygon([(mx - 36, my - 82), (mx, my - 150), (mx + 36, my - 82), (mx + 10, my - 92), (mx - 12, my - 76)], fill=(250, 248, 255, 255))
    SPOTS["mountain"] = (mx, my - 30)
    # Spring, southernmost: crocuses, lambs and roses.
    for (x, y) in [(900, 800), (940, 830), (880, 860), (925, 880), (960, 790)]:
        crocus(d, x, y, 30)
    SPOTS["crocuses"] = (920, 830)
    for (x, y) in [(1040, 820), (1100, 870), (1010, 900)]:
        lamb(d, x, y, 34)
    SPOTS["lambs"] = (1055, 860)
    for (x, y) in [(1150, 780), (1190, 820), (1160, 860), (1210, 900)]:
        rose(d, x, y, 22)
    SPOTS["roses"] = (1180, 840)
    # The Wall: a dark smear right across the island.
    smear = Image.new("L", (W, H), 0)
    sd = ImageDraw.Draw(smear)
    for k in range(9):
        y0 = 962 + RNG.randint(-6, 6)
        sd.line([(760 + RNG.randint(-20, 20), y0), (1320 + RNG.randint(-20, 20), y0 + RNG.randint(-8, 8))], fill=170, width=RNG.randint(6, 14))
    smear = smear.filter(ImageFilter.GaussianBlur(5))
    paint.paste(Image.new("RGBA", (W, H), (58, 46, 62, 255)), (0, 0), smear)
    d = ImageDraw.Draw(paint)
    SPOTS["wall"] = (1040, 968)
    # The human lands below it: muted fields and tiny cottages.
    for _ in range(14):
        x, y = RNG.uniform(940, 1150), RNG.uniform(1010, 1120)
        d.rectangle([x - 8, y - 6, x + 8, y + 6], fill=(200, 184, 170, 255))
        d.polygon([(x - 10, y - 6), (x, y - 15), (x + 10, y - 6)], fill=(170, 140, 130, 255))
    # The War: a frieze across the top, humans in chains and winged fae.
    d.rectangle([60, 40, W - 60, 140], fill=(246, 230, 214, 255))
    for i in range(22):
        x = 120 + i * 82
        fae = i % 3 == 1
        figure(d, x, 128, 72, (176, 120, 150, 255) if fae else (120, 104, 120, 255), wings=fae, chained=not fae and i % 2 == 0)
    d.line([(60, 142), (W - 60, 142)], fill=GOLD + (255,), width=6)
    d.line([(60, 38), (W - 60, 38)], fill=GOLD + (255,), width=6)
    # Painterly finish: a soft blur pass, then fine canvas grain.
    paint = paint.filter(ImageFilter.GaussianBlur(1.2))
    img.paste(paint, (0, 0), paint)
    grain = Image.frombytes("L", (W, H), RNG.randbytes(W * H)).convert("RGB")
    img = Image.blend(img, grain, 0.03)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    img.save(OUT, "WEBP", quality=85, method=6)
    for k, (x, y) in SPOTS.items():
        print(f"{k}: ({x / W:.3f}, {y / H:.3f})")


if __name__ == "__main__":
    main()
