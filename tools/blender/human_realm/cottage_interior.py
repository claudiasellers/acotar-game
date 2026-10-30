"""Archeron cottage interior hero props (placeholders the art lane may replace)
and Feyre's painted motifs. Each prop: origin at its base centre, front -z.
Motif meshes share their furniture's origin, so the scene places them with
the same transform. Writes world/human_realm/cottage/assets/interior/.

Painted motifs (book, ch. 1-2): Elain's drawer violets and roses round the
knob, Nesta's drawer crackling flames, Feyre's drawer a night sky with whorls
of yellow stars, a pillar of foxglove up the table edge, faded too-yellow
daffodils on the cabinets. The bed is left unpainted. Chipped, fading, and
still the only saturated colour in the room.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import cottage_lib as L  # noqa: E402

OUT = "world/human_realm/cottage/assets/interior/"
PAINT_D = 0.006


def chip(c, k=0.85):
    """Fade a paint colour a little (chipped, years old)."""
    g = sum(c) / 3
    return tuple(g + (c[i] - g) * k for i in range(3))


def dot(r, x, y, z, col):
    L.cyl(r, PAINT_D, at=(x, y, z), rot=(-90, 0, 0), seg=7, col=col, smooth=False)


def flower(x, y, z, petal, centre, r=0.022, n=5, ang=0.0):
    for i in range(n):
        a = ang + i / n * math.tau
        dot(r, x + math.cos(a) * r * 1.3, y + math.sin(a) * r * 1.3, z, petal)
    dot(r * 0.6, x, y, z - 0.001, centre)


def vine(points, z, col=chip((0.18, 0.52, 0.22)), leaf=chip((0.3, 0.66, 0.26))):
    for (x0, y0), (x1, y1) in zip(points, points[1:]):
        ln = math.hypot(x1 - x0, y1 - y0)
        ang = math.degrees(math.atan2(y1 - y0, x1 - x0))
        L.box((ln, 0.008, PAINT_D), at=((x0 + x1) / 2, (y0 + y1) / 2, z), rot=(0, 0, ang), col=col)
        L.ball(0.016, at=((x0 + x1) / 2 + 0.01, (y0 + y1) / 2 + 0.012, z), scale=(1.6, 0.8, 0.3), rot=(0, 0, ang + 40), col=leaf, sub=0)


# --- Furniture ---------------------------------------------------------------

def bed():
    """The sisters' one bed: their mother's bed, unpainted. 2.0 x 1.6."""
    L.seed(21)
    for x in (-0.95, 0.95):
        for z in (-0.75, 0.75):
            L.box((0.1, 0.55 if x < 0 else 0.95, 0.1), at=(x, (0.55 if x < 0 else 0.95) / 2, z), col=L.TIMBER, bevel=0.01)
    L.box((0.06, 0.6, 1.5), at=(0.95, 0.6, 0), col=L.TIMBER_OLD, bevel=0.01)  # headboard
    for z in (-0.75, 0.75):
        L.box((1.9, 0.12, 0.06), at=(0, 0.32, z), col=L.TIMBER)
    L.box((1.85, 0.16, 1.45), at=(0, 0.44, 0), col=(0.6, 0.57, 0.5), jitter=0.01)  # straw tick
    L.box((1.4, 0.07, 1.5), at=(-0.25, 0.55, 0), col=L.WOOL, jitter=0.015)  # thin blanket
    L.box((1.0, 0.05, 1.52), at=(-0.4, 0.6, 0.02), rot=(0, 3, 0), col=L.CLOTH_GREY, jitter=0.015)
    for z in (-0.45, 0.0, 0.45):
        L.ball(0.17, at=(0.72, 0.6, z), scale=(1.0, 0.45, 1.3), col=(0.7, 0.68, 0.62))
    L.box((2.0, 0.7, 1.6), at=(0, 0.35, 0), collision=True)
    L.export(OUT + "bed.glb")


def father_chair():
    for x in (-0.22, 0.22):
        for z in (-0.22, 0.22):
            L.box((0.06, 0.45, 0.06), at=(x, 0.22, z), col=L.TIMBER)
    L.box((0.52, 0.05, 0.5), at=(0, 0.47, 0), col=L.TIMBER_OLD)
    for x in (-0.22, 0.22):
        L.box((0.06, 0.65, 0.06), at=(x, 0.8, 0.24), rot=(-8, 0, 0), col=L.TIMBER)
    for y in (0.75, 0.95, 1.08):
        L.box((0.48, 0.06, 0.03), at=(0, y, 0.27), rot=(-8, 0, 0), col=L.TIMBER_OLD)
    L.box((0.5, 0.05, 0.55), at=(0, 0.52, 0.02), col=L.CLOTH_GREY, jitter=0.01)  # folded rug
    L.box((0.55, 1.1, 0.55), at=(0, 0.55, 0), collision=True)
    L.export(OUT + "father_chair.glb")


def cane():
    L.cyl(0.018, 0.92, rot=(0, 0, 0), seg=6, col=L.TIMBER_OLD)
    L.cyl(0.02, 0.16, at=(0, 0.92, 0), rot=(0, 0, 90), seg=6, col=L.TIMBER)
    L.export(OUT + "cane.glb")


def carving_stool():
    """Low stool by the chair: carving knife, half-finished figures, shavings."""
    L.seed(23)
    L.cyl(0.2, 0.04, at=(0, 0.4, 0), seg=10, col=L.TIMBER_OLD)
    for i in range(3):
        a = i / 3 * math.tau
        L.cyl(0.025, 0.42, at=(0.12 * math.cos(a), 0, 0.12 * math.sin(a)), seg=5, col=L.TIMBER)
    L.box((0.1, 0.012, 0.02), at=(0.05, 0.445, -0.05), rot=(0, 30, 0), col=L.TIMBER)
    L.box((0.07, 0.006, 0.015), at=(-0.03, 0.445, -0.1), rot=(0, 30, 0), col=(0.6, 0.6, 0.62))
    L.export(OUT + "carving_stool.glb")


def wooden_figures():
    """Half-finished figures: a bird, a horse, a little woman, a hound."""
    L.seed(24)
    W = (0.72, 0.6, 0.44)
    WD = (0.55, 0.44, 0.31)
    # bird
    L.ball(0.04, at=(-0.12, 0.04, 0), scale=(1.5, 1, 1), col=W, sub=1)
    L.ball(0.025, at=(-0.07, 0.08, 0), col=W, sub=1)
    # horse (rough blocked out)
    L.box((0.1, 0.05, 0.035), at=(0.02, 0.07, 0), col=WD)
    for x in (-0.03, 0.06):
        L.box((0.015, 0.05, 0.03), at=(x, 0.025, 0), col=WD)
    L.box((0.03, 0.06, 0.03), at=(0.07, 0.11, 0), rot=(0, 0, -25), col=WD)
    # little figure, only the top finished
    L.cyl(0.025, 0.1, at=(0.13, 0, 0.02), r2=0.015, seg=6, col=W)
    L.ball(0.016, at=(0.13, 0.115, 0.02), col=W, sub=1)
    # a rough block still squared
    L.box((0.05, 0.08, 0.05), at=(0.2, 0.04, -0.03), col=WD)
    for k in range(10):
        L.cyl(0.01, 0.03, at=(L.rnd(-0.2, 0.25), 0.003, L.rnd(-0.08, 0.08)), rot=(90, L.rnd(0, 180), 0), r2=0.004, seg=4, col=(0.82, 0.72, 0.55))
    L.export(OUT + "wooden_figures.glb")


def wood_shavings():
    L.seed(25)
    for k in range(40):
        a, r = L.rnd(0, math.tau), L.rnd(0, 0.5) ** 0.7
        L.cyl(0.012, 0.04, at=(r * math.cos(a), 0.004, r * math.sin(a)), rot=(90, L.rnd(0, 180), 0), r2=0.006, seg=4, col=(0.8, 0.7, 0.52))
    L.export(OUT + "wood_shavings.glb")


def table():
    """Table 1.6 x 0.9; the foxglove motif runs up the front-right leg."""
    L.seed(26)
    L.box((1.6, 0.06, 0.9), at=(0, 0.74, 0), col=L.TIMBER_OLD, bevel=0.01, jitter=0.004)
    for x in (-0.72, 0.72):
        for z in (-0.37, 0.37):
            L.box((0.08, 0.71, 0.08), at=(x, 0.355, z), col=L.TIMBER)
    L.box((1.42, 0.12, 0.03), at=(0, 0.63, -0.39), col=L.TIMBER)
    L.box((1.42, 0.12, 0.03), at=(0, 0.63, 0.39), col=L.TIMBER)
    # Bench along the back, stool in front.
    L.box((1.3, 0.05, 0.28), at=(0, 0.45, 0.68), col=L.TIMBER_OLD)
    for x in (-0.55, 0.55):
        L.box((0.06, 0.45, 0.24), at=(x, 0.225, 0.68), col=L.TIMBER)
    L.cyl(0.17, 0.04, at=(0.3, 0.42, -0.75), seg=8, col=L.TIMBER_OLD)
    for i in range(3):
        a = i / 3 * math.tau
        L.cyl(0.02, 0.42, at=(0.3 + 0.1 * math.cos(a), 0, -0.75 + 0.1 * math.sin(a)), seg=4, col=L.TIMBER)
    # Chipped dishes and a heel of bread.
    for x, z in ((-0.4, -0.15), (0.0, 0.2), (0.35, -0.1)):
        L.cyl(0.1, 0.02, at=(x, 0.77, z), r2=0.12, seg=10, col=(0.72, 0.7, 0.64))
    L.ball(0.07, at=(-0.4, 0.8, -0.15), scale=(1.3, 0.7, 1.0), col=(0.55, 0.42, 0.28))
    L.box((1.6, 0.77, 0.9), at=(0, 0.385, 0), collision=True)
    L.export(OUT + "table.glb")


def motif_table_foxglove():
    """A pillar of foxglove up the front-right leg and along the apron edge."""
    z = -0.41 - PAINT_D
    vine([(0.72, 0.05), (0.73, 0.25), (0.71, 0.45), (0.72, 0.62)], z)
    pink = chip((0.78, 0.28, 0.62))
    pale = chip((0.92, 0.6, 0.82))
    for i in range(9):
        y = 0.2 + i * 0.05
        side = -1 if i % 2 else 1
        dot(0.016, 0.72 + side * 0.022, y, z - 0.001, pink if i % 3 else pale)
        dot(0.006, 0.72 + side * 0.022, y - 0.004, z - 0.002, chip((0.35, 0.08, 0.3)))
    # A trailing tendril along the apron toward the middle.
    vine([(0.68, 0.62), (0.4, 0.65), (0.1, 0.62), (-0.2, 0.64)], -0.405 - PAINT_D)
    for x in (0.5, 0.2, -0.1):
        flower(x, 0.64, -0.407 - PAINT_D, pink, chip((0.95, 0.85, 0.5)), r=0.012)
    L.export(OUT + "motif_table_foxglove.glb")


DR_W, DR_D, DR_H = 1.2, 0.5, 1.1
DRAWERS = ((0.8, 1.02), (0.47, 0.75), (0.14, 0.42))  # Elain (top), Nesta, Feyre


def dresser():
    """The sagging dresser: three drawers (Elain, Nesta, Feyre top to bottom)."""
    L.box((DR_W, DR_H, DR_D), at=(0, DR_H / 2, 0), col=L.TIMBER_OLD, bevel=0.01)
    L.box((DR_W + 0.06, 0.04, DR_D + 0.04), at=(0, DR_H + 0.02, 0), rot=(0, 0, 1.2), col=L.TIMBER)  # sag
    for y0, y1 in DRAWERS:
        L.box((DR_W - 0.1, y1 - y0, 0.03), at=(0, (y0 + y1) / 2, -DR_D / 2 - 0.01), col=L.TIMBER_OLD, bevel=0.005)
        L.ball(0.022, at=(0, (y0 + y1) / 2, -DR_D / 2 - 0.035), col=L.TIMBER, sub=1)
    L.box((DR_W, DR_H, DR_D), at=(0, DR_H / 2, 0), collision=True)
    L.export(OUT + "dresser.glb")


def motif_dresser():
    z = -DR_D / 2 - 0.026 - PAINT_D
    # Elain: violets and roses round the knob.
    y0, y1 = DRAWERS[0]
    yc = (y0 + y1) / 2
    for i in range(10):
        a = i / 10 * math.tau
        x, y = 0.13 * math.cos(a) * 1.6, yc + 0.08 * math.sin(a)
        if i % 2:
            flower(x, y, z, chip((0.45, 0.25, 0.75)), chip((0.95, 0.85, 0.3)), r=0.014)
        else:
            dot(0.024, x, y, z, chip((0.82, 0.2, 0.3)))
            dot(0.013, x, y, z - 0.001, chip((0.6, 0.1, 0.18)))
    vine([(-0.35, yc), (-0.22, yc + 0.05), (-0.1, yc - 0.02)], z + 0.001)
    vine([(0.1, yc - 0.02), (0.22, yc + 0.05), (0.35, yc)], z + 0.001)
    # Nesta: crackling flames.
    y0, y1 = DRAWERS[1]
    for i in range(11):
        x = -0.45 + i * 0.09
        h = 0.12 + 0.08 * math.sin(i * 1.7) ** 2
        for k, c in enumerate(((0.85, 0.22, 0.08), (0.95, 0.5, 0.1), (1.0, 0.82, 0.3))):
            s = 1.0 - k * 0.3
            L.cyl(0.03 * s, h * s, at=(x, y0 + 0.03, z - 0.001 * k), rot=(0, 0, L.rnd(-12, 12)), r2=0.0, seg=6, col=chip(c), smooth=False)
    # Feyre: night sky, whorls of yellow stars standing in for white.
    y0, y1 = DRAWERS[2]
    L.box((DR_W - 0.16, y1 - y0 - 0.06, PAINT_D), at=(0, (y0 + y1) / 2, z + 0.002), col=chip((0.1, 0.13, 0.36)))
    for w, (cx, cy) in enumerate(((-0.33, 0.3), (0.0, 0.25), (0.32, 0.31))):
        for i in range(12):
            t = i / 12
            a = t * math.tau * 1.4 + w
            r = 0.012 + t * 0.075
            dot(0.008 + 0.006 * (1 - t), cx + math.cos(a) * r * 1.4, cy + math.sin(a) * r, z - 0.001, chip((1.0, 0.86, 0.25)))
    L.export(OUT + "motif_dresser.glb")


def wall_cabinet():
    """Hung cabinet, origin at the wall (back) bottom centre, front -z."""
    L.box((0.9, 0.6, 0.3), at=(0, 0.3, -0.15), col=L.TIMBER_OLD, bevel=0.01)
    for x in (-0.22, 0.22):
        L.box((0.42, 0.54, 0.02), at=(x, 0.3, -0.31), col=L.TIMBER_OLD)
        L.ball(0.015, at=(x * 0.2, 0.3, -0.33), col=L.TIMBER, sub=0)
    L.box((0.95, 0.04, 0.34), at=(0, 0.62, -0.15), col=L.TIMBER)
    for x in (-0.3, 0.0, 0.25):  # chipped crockery on top
        L.cyl(0.05, 0.08, at=(x, 0.64, -0.15), r2=0.06, seg=8, col=(0.7, 0.68, 0.62))
    L.export(OUT + "wall_cabinet.glb")


def motif_cabinet_daffodils():
    z = -0.32 - PAINT_D
    yel = chip((1.0, 0.9, 0.12), 0.95)  # too-yellow, faded
    for x0 in (-0.22, 0.22):
        for i in range(3):
            x = x0 - 0.12 + i * 0.12
            vine([(x, 0.08), (x + 0.01, 0.25), (x, 0.36 + 0.04 * (i % 2))], z + 0.001)
            flower(x, 0.4 + 0.04 * (i % 2), z, yel, chip((0.95, 0.55, 0.1)), r=0.022, n=6)
    L.export(OUT + "motif_cabinet_daffodils.glb")


def motif_wall_vines():
    """Wall vines in a local frame: wall plane z=0, motif faces -z; origin at
    the floor. Placed beside the front window and over the door."""
    L.seed(28)
    z = -PAINT_D
    pts = [(0.0, 0.4 + i * 0.12) for i in range(12)]
    pts = [(math.sin(i * 0.9) * 0.08, y) for i, (_x, y) in enumerate(pts)]
    vine(pts, z)
    pts2 = [(0.05 + i * 0.13, 1.8 + math.sin(i * 0.8) * 0.06) for i in range(9)]
    vine(pts2, z)
    for (x, y) in pts[2::3] + pts2[1::3]:
        flower(x + 0.04, y, z - 0.001, chip((0.95, 0.55, 0.6)), chip((0.95, 0.85, 0.4)), r=0.018)
    for (x, y) in pts[4::4]:
        flower(x - 0.05, y + 0.03, z - 0.001, chip((0.5, 0.45, 0.9)), chip((1.0, 0.95, 0.6)), r=0.014)
    L.export(OUT + "motif_wall_vines.glb")


def pegs_clothes():
    """Peg rail on a wall (origin wall-bottom, front -z) with meagre clothes."""
    L.box((1.4, 0.08, 0.04), at=(0, 1.55, -0.02), col=L.TIMBER)
    for i, (c, ln) in enumerate(((L.CLOTH_GREY, 0.8), (L.CLOTH_BROWN, 0.95), ((0.36, 0.4, 0.42), 0.7), (L.WOOL, 0.5))):
        x = -0.5 + i * 0.33
        L.cyl(0.015, 0.1, at=(x, 1.55, -0.04), rot=(-90, 0, 0), seg=4, col=L.TIMBER_OLD)
        L.box((0.3, ln, 0.06), at=(x, 1.55 - ln / 2, -0.09), col=c, jitter=0.01)
    L.export(OUT + "pegs_clothes.glb")


def bow_quiver():
    """Feyre's bow leaning on the wall, a quiver of arrows, her knife."""
    L.seed(29)
    for i in range(10):
        t0, t1 = i / 10, (i + 1) / 10
        y0, y1 = t0 * 1.55, t1 * 1.55
        x0, x1 = 0.12 * math.sin(t0 * math.pi), 0.12 * math.sin(t1 * math.pi)
        L.box((0.03, y1 - y0 + 0.01, 0.025), at=((x0 + x1) / 2, (y0 + y1) / 2, 0), rot=(0, 0, -math.degrees(math.atan2(x1 - x0, y1 - y0))), col=L.TIMBER_OLD)
    L.box((0.003, 1.55, 0.003), at=(0, 0.775, 0), col=L.BONE)
    L.box((0.06, 0.1, 0.035), at=(0.12, 0.78, 0), col=L.CLOTH_BROWN)
    L.cyl(0.07, 0.55, at=(0.35, 0, 0.0), rot=(0, 0, -8), seg=8, col=(0.4, 0.3, 0.22))
    for k in range(7):
        L.cyl(0.006, 0.25, at=(0.38 + L.rnd(-0.04, 0.04), 0.5, L.rnd(-0.04, 0.04)), rot=(0, 0, -8), seg=3, col=L.TIMBER_OLD)
        L.box((0.004, 0.06, 0.03), at=(0.39 + L.rnd(-0.04, 0.04), 0.72, L.rnd(-0.04, 0.04)), col=(0.85, 0.85, 0.82))
    L.box((0.03, 0.14, 0.015), at=(0.55, 0.9, -0.01), col=L.TIMBER)
    L.box((0.025, 0.18, 0.006), at=(0.55, 0.74, -0.01), col=(0.62, 0.62, 0.64))
    L.export(OUT + "bow_quiver.glb")


def food_tally():
    """Tally scratches on the side of a tie beam (local: beam face plane x=0,
    marks face -x). Groups of five, the latest groups short."""
    for g in range(6):
        for k in range(5 if g < 5 else 3):
            z = -0.45 + g * 0.16 + k * 0.025
            if k == 4:
                L.box((0.006, 0.006, 0.12), at=(-0.003, 0.0, z - 0.05), rot=(30, 0, 0), col=L.BONE)
            else:
                L.box((0.006, 0.09, 0.006), at=(-0.003, 0.0, z), col=L.BONE)
    L.export(OUT + "food_tally_marks.glb")


def paint_corner():
    """Feyre's paint corner: a crate, three tins of pigment, a scrap brush,
    a board with test strokes. Paint is the only saturated colour here."""
    L.seed(30)
    L.box((0.5, 0.4, 0.4), at=(0, 0.2, 0), col=L.TIMBER_OLD, bevel=0.01)
    for i, c in enumerate(((0.85, 0.2, 0.25), (0.95, 0.8, 0.2), (0.2, 0.35, 0.8))):
        x = -0.15 + i * 0.15
        L.cyl(0.05, 0.08, at=(x, 0.4, -0.05), seg=8, col=(0.5, 0.5, 0.52))
        L.cyl(0.044, 0.005, at=(x, 0.48, -0.05), seg=8, col=chip(c))
    L.cyl(0.008, 0.2, at=(0.0, 0.41, 0.1), rot=(0, 0, 84), seg=4, col=L.TIMBER)
    L.cyl(0.014, 0.04, at=(-0.1, 0.415, 0.1), rot=(0, 0, 84), r2=0.004, seg=5, col=chip((0.85, 0.2, 0.25)))
    L.box((0.45, 0.6, 0.02), at=(0.05, 0.3, 0.24), rot=(-12, 0, 0), col=(0.6, 0.55, 0.45))
    for i, c in enumerate(((0.85, 0.2, 0.25), (0.95, 0.8, 0.2), (0.2, 0.35, 0.8), (0.3, 0.6, 0.3))):
        L.box((0.3, 0.035, 0.005), at=(0.05, 0.42 - i * 0.08, 0.225), rot=(-12, 0, L.rnd(-6, 6)), col=chip(c))
    L.export(OUT + "paint_corner.glb")


def nesta_ribbon_comb():
    L.box((0.12, 0.012, 0.04), at=(0, 0.006, 0), col=BONE_COMB)
    for k in range(10):
        L.box((0.004, 0.006, 0.03), at=(-0.05 + k * 0.011, 0.006, -0.03), col=BONE_COMB)
    for i in range(6):
        L.box((0.06, 0.004, 0.022), at=(0.12 + i * 0.045, 0.004, 0.03 * math.sin(i)), rot=(0, i * 25, 0), col=(0.32, 0.38, 0.62))
    L.export(OUT + "nesta_ribbon_comb.glb")


BONE_COMB = (0.86, 0.8, 0.66)


def elain_seed_packets():
    for i in range(5):
        L.box((0.07, 0.006, 0.1), at=(i * 0.05, 0.004 + i * 0.006, i * 0.01), rot=(0, i * 9 - 18, 0), col=(0.72, 0.66, 0.52))
        L.box((0.04, 0.007, 0.03), at=(i * 0.05, 0.005 + i * 0.006, i * 0.01 - 0.02), rot=(0, i * 9 - 18, 0), col=(0.55, 0.48, 0.38))
    L.cyl(0.03, 0.06, at=(0.32, 0, 0.0), seg=8, col=(0.6, 0.55, 0.45))  # twist of seeds
    L.export(OUT + "elain_seed_packets.glb")


def pressed_flower_cup():
    L.cyl(0.04, 0.09, r2=0.045, seg=10, col=(0.72, 0.7, 0.64))
    L.cyl(0.003, 0.12, at=(0.0, 0.05, 0.0), rot=(0, 0, 8), seg=3, col=(0.5, 0.48, 0.32))
    for i in range(5):
        a = i / 5 * math.tau
        L.ball(0.012, at=(0.017 + 0.012 * math.cos(a), 0.17, 0.012 * math.sin(a)), scale=(1, 0.3, 1), col=(0.75, 0.62, 0.62), sub=0)
    L.export(OUT + "pressed_flower_cup.glb")


def iron_pot():
    """The iron pot on its trivet in the hearth, thin stew."""
    L.ball(0.24, at=(0, 0.3, 0), scale=(1, 0.8, 1), col=L.IRON, sub=2)
    L.cyl(0.2, 0.04, at=(0, 0.46, 0), seg=12, col=(0.42, 0.36, 0.28))
    L.cyl(0.23, 0.04, at=(0, 0.46, 0), seg=12, col=L.IRON, cap=False)
    for i in range(3):
        a = i / 3 * math.tau
        L.cyl(0.018, 0.2, at=(0.17 * math.cos(a), 0, 0.17 * math.sin(a)), seg=4, col=L.IRON)
    L.box((0.02, 0.02, 0.5), at=(0, 0.62, 0), rot=(0, 0, 0), col=L.IRON)
    L.export(OUT + "iron_pot.glb")


def hearth_embers_glow():
    """Logs and embers; material name ends _glow so the import adds emission."""
    L.seed(31)
    for k in range(3):
        L.cyl(0.07, 0.6, at=(-0.25, 0.07, -0.2 + k * 0.2), rot=(0, 0, -90), seg=6, col=(0.95, 0.4, 0.1) if k == 1 else (0.5, 0.15, 0.05), jitter=0.01)
    for k in range(14):
        L.ball(0.04, at=(L.rnd(-0.3, 0.3), 0.03, L.rnd(-0.3, 0.3)), col=(1.0, 0.5 + L.rnd(0, 0.3), 0.1), sub=0)
    L.export(OUT + "hearth_embers_glow.glb")


def shutter_frost():
    """Frost on the inside of a closed shutter (wall plane z=0, faces -z)."""
    L.seed(32)
    L.box((0.8, 0.8, 0.01), at=(0, 0.4, 0), col=(0.7, 0.76, 0.84))
    for k in range(40):
        a = L.rnd(0, math.tau)
        r = 0.32 + L.rnd(-0.06, 0.06)
        x, y = max(-0.38, min(0.38, math.cos(a) * r)), 0.4 + max(-0.38, min(0.38, math.sin(a) * r))
        L.box((L.rnd(0.05, 0.14), 0.006, 0.006), at=(x, y, -0.008), rot=(0, 0, L.rnd(0, 180)), col=L.FROST)
    L.export(OUT + "shutter_frost.glb")


def hidden_coin():
    """A loose hearthstone pried up over Feyre's small hoard of coin."""
    L.box((0.3, 0.05, 0.25), at=(0, 0.025, 0), rot=(0, 0, 8), col=L.STONE_DARK)
    L.ball(0.06, at=(0.12, 0.03, 0.0), scale=(1, 0.6, 1), col=(0.42, 0.33, 0.22))
    for k in range(3):
        L.cyl(0.012, 0.003, at=(0.06 + k * 0.03, 0.005, 0.08), seg=8, col=(0.62, 0.45, 0.25))
    L.export(OUT + "hidden_coin.glb")


def dish_shelf():
    L.box((0.9, 0.04, 0.22), at=(0, 0, -0.11), col=L.TIMBER)
    for x in (-0.3, -0.05, 0.25):
        L.cyl(0.08, 0.02, at=(x, 0.02, -0.11), seg=10, col=(0.72, 0.7, 0.64))
    L.cyl(0.05, 0.12, at=(0.38, 0.02, -0.11), seg=8, col=(0.5, 0.46, 0.4))
    L.export(OUT + "dish_shelf.glb")


if __name__ == "__main__":
    L.reset()
    for fn in (bed, father_chair, cane, carving_stool, wooden_figures, wood_shavings, table, motif_table_foxglove,
               dresser, motif_dresser, wall_cabinet, motif_cabinet_daffodils, motif_wall_vines, pegs_clothes,
               bow_quiver, food_tally, paint_corner, nesta_ribbon_comb, elain_seed_packets, pressed_flower_cup,
               iron_pot, hearth_embers_glow, shutter_frost, hidden_coin, dish_shelf):
        fn()
