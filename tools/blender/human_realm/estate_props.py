"""The burnt Archeron estate on the hill and the father's workshop shed:
gutted house shell, fallen beams, charred stair, the dead formal garden
(broken fountain, toppled statue, parterre, frozen ornamental pond, rose
briar), gateposts, family plot, dead orchard trees, and the shed with its
bench, tools, carvings and cold stove. Plus the estate's keepsakes.
Writes world/human_realm/workshop/assets/. [X] (no burnt estate in canon.)
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import cottage_lib as L  # noqa: E402

OUT = "world/human_realm/workshop/assets/"
SCORCH = (0.16, 0.14, 0.13)
ASHSTONE = (0.5, 0.49, 0.48)

# Ruin footprint (outer half extents), wall thickness.
RX, RZ, RT = 12.0, 7.0, 0.7


def scorched(p, n):
    base = L.mottled(ASHSTONE, 0.08, 3)(p, n)
    k = 0.5 + 0.5 * math.sin(p[0] * 0.9 + p[1] * 0.7) * math.sin(p[2] * 1.3 - p[1] * 0.4)
    t = min(1.0, max(0.0, (p[1] - 2.0) / 5.0)) * 0.6 + k * 0.45
    t = min(1.0, t)
    return tuple(base[i] * (1 - t) + SCORCH[i] * t for i in range(3))


def jag(i, seed_off):
    """Jagged wall-top height for column i."""
    v = 7.5 + 2.0 * math.sin(i * 1.7 + seed_off) + 1.5 * math.sin(i * 0.6 + 2 * seed_off)
    return max(2.2, min(9.0, v))


def ruin_wall(along_x, c0, c1, a0, a1, door, seed_off, collision):
    cols = int(round((a1 - a0) / 1.2))
    w = (a1 - a0) / cols
    for i in range(cols):
        a = a0 + w * (i + 0.5)
        top = jag(i, seed_off)
        spans = []
        is_door = door and abs(a) < 1.6
        is_win = (i % 3 == 1) and not is_door
        if is_door:
            spans = [(3.4, top)]
        elif is_win:
            spans = [(-1.0, 1.0), (3.2, min(top, 4.6))]
            if top > 7.0:
                spans.append((6.6, top))
        else:
            spans = [(-1.0, top)]
        for y0, y1 in spans:
            if y1 - y0 < 0.1:
                continue
            size = (w, y1 - y0, c1 - c0) if along_x else (c1 - c0, y1 - y0, w)
            at = (a, (y0 + y1) / 2, (c0 + c1) / 2) if along_x else ((c0 + c1) / 2, (y0 + y1) / 2, a)
            if collision:
                L.box(size, at=at, collision=True)
            else:
                L.box(size, at=at, col_fn=scorched, jitter=0.03, snow=0.75)


def estate_ruin():
    L.seed(51)
    for collision in (False, True):
        ruin_wall(True, -RZ, -RZ + RT, -RX, RX, True, 0.0, collision)
        ruin_wall(True, RZ - RT, RZ, -RX, RX, False, 1.3, collision)
        ruin_wall(False, -RX, -RX + RT, -RZ + RT, RZ - RT, False, 2.1, collision)
        ruin_wall(False, RX - RT, RX, -RZ + RT, RZ - RT, False, 3.4, collision)
        # Inner cross wall, half fallen, with an arch gap.
        for z0, z1, top in ((-RZ + RT, -1.4, 5.5), (1.4, RZ - RT, 3.2)):
            if collision:
                L.box((0.5, top + 1, z1 - z0), at=(-3.0, top / 2 - 0.5, (z0 + z1) / 2), collision=True)
            else:
                L.box((0.5, top + 1, z1 - z0), at=(-3.0, top / 2 - 0.5, (z0 + z1) / 2), col_fn=scorched, jitter=0.03, snow=0.75)
    # Tall chimney stacks at both ends: the silhouette from the village.
    for x in (-RX - 0.5, RX + 0.5):
        L.box((1.4, 11.5, 2.2), at=(x, 5.0, 1.5), col_fn=scorched, jitter=0.03, snow=0.7)
        L.box((1.6, 0.3, 2.4), at=(x, 10.8, 1.5), col=SCORCH, snow=0.6)
        L.box((1.4, 11.5, 2.2), at=(x, 5.0, 1.5), collision=True)
    # Front steps and broken portico columns.
    for k in range(3):
        L.box((5.0 - k * 0.6, 0.2, 1.0 - k * 0.25), at=(0, 0.1 + k * 0.2, -RZ - 0.9 + k * 0.25), col=ASHSTONE, snow=0.6)
    for x, h in ((-2.2, 4.2), (2.2, 1.8)):
        L.cyl(0.35, h, at=(x, 0, -RZ - 1.4), seg=10, col_fn=scorched, snow=0.7)
        L.cyl(0.35, h, at=(x, 0, -RZ - 1.4), seg=8, collision=True)
    L.cyl(0.35, 3.5, at=(3.4, 0.3, -RZ - 3.2), rot=(0, 30, 88), seg=10, col_fn=scorched, snow=0.5)
    # Floor: charred boards, ash, rubble heaps.
    L.box((2 * RX - 2 * RT, 0.15, 2 * RZ - 2 * RT), at=(0, 0.05, 0), col=SCORCH, col_fn=L.mottled((0.2, 0.18, 0.17), 0.05, 2))
    for k in range(16):
        L.ball(L.rnd(0.6, 1.5), at=(L.rnd(-RX + 1.5, RX - 1.5), 0.0, L.rnd(-RZ + 1.5, RZ - 1.5)), scale=(1.3, 0.45, 1.0), col_fn=scorched, jitter=0.12, sub=1, snow=0.6)
    L.box((2 * RX, 0.3, 2 * RZ), at=(0, -0.05, 0), collision=True)
    L.export(OUT + "estate_ruin.glb")


def estate_beams():
    """Fallen roof beams and joists, charred, slumped inside the shell."""
    L.seed(52)
    for k in range(9):
        ln = L.rnd(4.0, 9.0)
        L.box((ln, 0.35, 0.35), at=(L.rnd(-8, 8), L.rnd(0.4, 2.2), L.rnd(-4.5, 4.5)), rot=(L.rnd(-10, 10), L.rnd(0, 180), L.rnd(-25, 25)), col=L.CHAR, jitter=0.03, snow=0.7)
    for k in range(5):
        L.box((L.rnd(2, 4), 0.2, 0.2), at=(L.rnd(-8, 8), L.rnd(4.0, 6.5), L.rnd(-4.5, 4.5)), rot=(0, 90 * (k % 2), L.rnd(-8, 8)), col=L.CHAR, snow=0.7)
    L.export(OUT + "estate_beams.glb")


def estate_staircase():
    """The charred grand staircase climbing to nothing."""
    for k in range(16):
        y = 0.2 + k * 0.22
        L.box((1.8, 0.08, 0.38), at=(0, y, k * 0.3), col=L.CHAR, jitter=0.01, snow=0.7)
        if k < 13:
            L.box((1.8, y, 0.04), at=(0, y / 2, k * 0.3 - 0.17), col=SCORCH)
    for x in (-0.95, 0.95):
        L.box((0.12, 0.3, 5.4), at=(x, 1.9, 2.25), rot=(-36, 0, 0), col=L.CHAR)
        for k in range(0, 14, 2):
            L.cyl(0.03, 0.9 if k < 10 else 0.4, at=(x, 0.4 + k * 0.22, k * 0.3), seg=5, col=L.CHAR)
    L.box((1.9, 0.12, 5.0), at=(0, 1.8, 2.2), rot=(-36, 0, 0), collision=True)
    L.box((1.8, 3.6, 0.3), at=(0, 1.8, 4.8), collision=True)
    L.export(OUT + "estate_staircase.glb")


def fountain_broken():
    L.seed(53)
    for i in range(16):
        a = i / 16 * math.tau
        if 4 <= i <= 5:
            continue  # broken section
        L.box((1.6, 0.6, 0.4), at=(4.0 * math.cos(a), 0.3, 4.0 * math.sin(a)), rot=(0, -math.degrees(a) + 90, 0), col=ASHSTONE, bevel=0.05, snow=0.6)
    L.cyl(3.85, 0.1, at=(0, 0.15, 0), seg=24, col=L.ICE)
    L.cyl(0.5, 1.6, at=(0, 0, 0), r2=0.35, seg=10, col=ASHSTONE)
    L.cyl(1.4, 0.25, at=(0, 1.6, 0), r2=1.6, seg=14, col=ASHSTONE, snow=0.6)
    L.cyl(0.3, 0.9, at=(0, 1.85, 0), seg=8, col=ASHSTONE)
    L.cyl(0.6, 0.2, at=(1.8, 0.2, 0.6), rot=(70, 20, 0), r2=0.8, seg=10, col=ASHSTONE, snow=0.6)  # fallen top bowl
    for k in range(10):  # icicles from the bowl rim
        a = k / 10 * math.tau
        L.cyl(0.05, L.rnd(0.3, 0.8), at=(1.5 * math.cos(a), 1.62, 1.5 * math.sin(a)), rot=(180, 0, 0), r2=0.0, seg=4, col=L.ICE)
    for k in range(5):
        L.ball(0.3, at=(4.0 * math.cos(1.7) + L.rnd(-0.8, 0.8), 0.1, 4.0 * math.sin(1.7) + L.rnd(-0.8, 0.8)), col=ASHSTONE, sub=0, jitter=0.05)
    L.cyl(4.2, 0.6, seg=12, collision=True)
    L.export(OUT + "fountain_broken.glb")


def statue_toppled():
    """A marble lady face-down in the snow beside her plinth, arm raised."""
    L.box((1.2, 1.4, 1.2), at=(0, 0.7, 0), col=ASHSTONE, bevel=0.05, snow=0.6)
    L.box((1.4, 0.15, 1.4), at=(0, 1.47, 0), col=ASHSTONE, snow=0.6)
    M = (0.8, 0.79, 0.76)
    L.cyl(0.45, 2.0, at=(1.2, 0.35, 0.3), rot=(0, 10, -90), r2=0.3, seg=10, col=M, snow=0.6)
    L.ball(0.28, at=(3.4, 0.35, 0.65), col=M, snow=0.6)
    L.cyl(0.11, 0.9, at=(2.6, 0.5, 0.8), rot=(0, 10, -30), seg=6, col=M)
    L.cyl(0.5, 0.25, at=(1.0, 0.0, 0.25), rot=(0, 10, -90), seg=10, col=M)
    L.box((1.4, 1.6, 1.4), at=(0, 0.8, 0), collision=True)
    L.export(OUT + "statue_toppled.glb")


def parterre_dead():
    """Box-hedge parterre gone brown and bare, in a knot pattern, 20 x 14."""
    L.seed(54)
    DEAD = (0.34, 0.3, 0.22)

    def hedge(x0, z0, x1, z1):
        n = max(1, int(math.hypot(x1 - x0, z1 - z0) / 1.0))
        for i in range(n):
            t = (i + 0.5) / n
            L.ball(0.45, at=(x0 + (x1 - x0) * t, 0.25, z0 + (z1 - z0) * t), scale=(1.2, 0.8, 1.2), col=DEAD, jitter=0.12, sub=1, snow=0.55)
    for sx in (-1, 1):
        for sz in (-1, 1):
            cx, cz = sx * 7.0, sz * 4.5
            hedge(cx - 3.5, cz - 2.5, cx + 3.5, cz - 2.5)
            hedge(cx - 3.5, cz + 2.5, cx + 3.5, cz + 2.5)
            hedge(cx - 3.5, cz - 2.5, cx - 3.5, cz + 2.5)
            hedge(cx + 3.5, cz - 2.5, cx + 3.5, cz + 2.5)
            hedge(cx - 2, cz - 1.5, cx + 2, cz + 1.5)
            hedge(cx - 2, cz + 1.5, cx + 2, cz - 1.5)
    L.export(OUT + "parterre_dead.glb")


def rose_briar_overgrown():
    """A huge tangle of rose briar climbing a wall stub, hips like blood drops."""
    L.seed(55)
    for k in range(70):
        a, r = L.rnd(0, math.tau), L.rnd(0.0, 3.0)
        x, z = r * math.cos(a) * 1.4, r * math.sin(a) * 0.6
        L.cyl(0.03, L.rnd(1.0, 2.5), at=(x, 0, z), rot=(L.rnd(-50, 50), L.rnd(0, 180), L.rnd(-50, 50)), r2=0.01, seg=4, col=(0.25, 0.17, 0.14), smooth=False)
    for k in range(60):
        L.ball(0.05, at=(L.rnd(-3.5, 3.5), L.rnd(0.4, 2.2), L.rnd(-1.5, 1.5)), scale=(1, 1.3, 1), col=L.BERRY_RED, sub=0)
    for k in range(10):
        L.ball(0.4, at=(L.rnd(-3, 3), L.rnd(0.6, 1.8), L.rnd(-1, 1)), scale=(1.4, 0.3, 1.0), col=L.SNOW, sub=1, jitter=0.05)
    L.export(OUT + "rose_briar_overgrown.glb")


def ornamental_pond():
    """Rectangular stone-rimmed pond, frozen; origin at the ice surface."""
    L.box((10.0, 0.1, 5.0), at=(0, -0.05, 0), col=L.ICE, col_fn=lambda p, n: (0.5, 0.62, 0.74) if abs(p[0]) < 3 and abs(p[2]) < 1.2 else L.ICE)
    for x0, z0, sx, sz in ((0, -2.7, 10.8, 0.5), (0, 2.7, 10.8, 0.5), (-5.2, 0, 0.5, 5.0), (5.2, 0, 0.5, 5.0)):
        L.box((sx, 0.5, sz), at=(x0, 0.05, z0), col=ASHSTONE, bevel=0.04, snow=0.6)
    L.cyl(0.6, 0.06, at=(-2.0, 0.0, 0.6), seg=12, col=(0.35, 0.38, 0.3))  # frozen lily pads
    L.cyl(0.4, 0.06, at=(1.5, 0.0, -0.8), seg=12, col=(0.35, 0.38, 0.3))
    L.export(OUT + "ornamental_pond.glb")


def estate_gateposts():
    for x in (-3.0, 3.0):
        L.box((0.9, 3.2, 0.9), at=(x, 1.6, 0), col=ASHSTONE, bevel=0.05, snow=0.6)
        L.ball(0.4, at=(x, 3.5, 0), col=ASHSTONE, snow=0.6)
        L.box((0.9, 3.2, 0.9), at=(x, 1.6, 0), collision=True)
    # One gate leaf hanging, one fallen.
    for i in range(7):
        L.cyl(0.03, 2.4, at=(-2.4 + i * 0.35, 0.1, -0.2 - i * 0.12), seg=4, col=L.IRON)
    L.box((2.4, 0.06, 0.06), at=(-1.35, 2.2, -0.55), rot=(0, 20, 0), col=L.IRON)
    L.box((2.4, 0.06, 0.06), at=(-1.35, 0.4, -0.55), rot=(0, 20, 0), col=L.IRON)
    L.box((2.4, 0.06, 2.4), at=(1.4, 0.05, -1.2), rot=(0, -15, 0), col=L.IRON, jitter=0.0)
    L.export(OUT + "estate_gateposts.glb")


def family_plot():
    """Three small headstones (the mother's, and two older family stones)
    inside a low iron railing, one with a withered wreath."""
    L.seed(56)
    for i, (x, h) in enumerate(((-1.4, 0.95), (0.0, 1.15), (1.4, 0.8))):
        L.box((0.7, h, 0.16), at=(x, h / 2, 0), rot=(L.rnd(-4, 4), L.rnd(-5, 5), L.rnd(-4, 4)), col=L.mottled(ASHSTONE, 0.08, 6)((x, 0, 0), None), bevel=0.03, snow=0.6)
        L.cyl(0.35, 0.16, at=(x, h - 0.02, -0.08), rot=(90, 0, 0), seg=10, col=ASHSTONE, snow=0.6)
        L.ball(0.35, at=(x, 0.0, -0.9), scale=(1.0, 0.3, 1.8), col=L.SNOW, sub=1)
    for k in range(10):  # wreath on the mother's stone
        a = k / 10 * math.tau
        L.ball(0.06, at=(0.0 + 0.2 * math.cos(a), 0.65 + 0.2 * math.sin(a), -0.11), col=(0.3, 0.3, 0.22), sub=0)
    for side in range(4):
        n = 12 if side % 2 == 0 else 7
        for i in range(n):
            t = i / (n - 1)
            if side == 0:
                x, z = -2.5 + 5 * t, -2.0
            elif side == 2:
                x, z = -2.5 + 5 * t, 1.0
            elif side == 1:
                x, z = 2.5, -2.0 + 3 * t
            else:
                x, z = -2.5, -2.0 + 3 * t
            if side == 0 and 0.4 < t < 0.6:
                continue
            L.cyl(0.02, 0.8, at=(x, 0, z), seg=4, col=L.IRON)
            L.ball(0.035, at=(x, 0.82, z), col=L.IRON, sub=0)
    L.box((5.0, 0.04, 0.04), at=(0, 0.7, 1.0), col=L.IRON)
    L.box((0.04, 0.04, 3.0), at=(-2.5, 0.7, -0.5), col=L.IRON)
    L.box((0.04, 0.04, 3.0), at=(2.5, 0.7, -0.5), col=L.IRON)
    L.export(OUT + "family_plot.glb")


def dead_fruit_tree():
    """Bare, unpruned apple/pear tree from the dead orchard."""
    L.seed(57)
    BARK = (0.2, 0.17, 0.16)
    L.cyl(0.18, 1.6, seg=7, r2=0.13, col=BARK, jitter=0.02)

    def branch(x, y, z, yaw, pitch, ln, r, depth):
        L.cyl(r, ln, at=(x, y, z), rot=(pitch, yaw, 0), r2=r * 0.6, seg=5, col=BARK)
        if depth == 0:
            return
        ry, rp = math.radians(yaw), math.radians(pitch)
        ex = x + ln * math.sin(rp) * math.sin(ry)
        ey = y + ln * math.cos(rp)
        ez = z + ln * math.sin(rp) * math.cos(ry)
        for k in range(2):
            branch(ex, ey, ez, yaw + L.rnd(-60, 60), pitch + L.rnd(-10, 20), ln * 0.65, r * 0.6, depth - 1)
    for k in range(4):
        branch(0, 1.5, 0, k * 90 + L.rnd(-20, 20), L.rnd(35, 55), 1.6, 0.09, 2)
    L.export(OUT + "dead_fruit_tree.glb")


def rubble_pile():
    L.seed(58)
    for k in range(9):
        L.ball(L.rnd(0.2, 0.45), at=(L.rnd(-0.8, 0.8), 0.1, L.rnd(-0.8, 0.8)), col_fn=scorched, sub=0, jitter=0.06, snow=0.6)
    L.box((1.4, 0.15, 0.2), at=(0.1, 0.35, 0.1), rot=(0, 30, 12), col=L.CHAR)
    L.export(OUT + "rubble_pile.glb")


# --- The workshop ------------------------------------------------------------

SX, SZ = 2.4, 1.9  # shed half extents


def workshop_shed():
    """Lean-to timber shed on a stone plinth; doorway on the -z front, one
    shuttered window; the bench/stove/carvings are separate props."""
    L.seed(59)
    BOARD = (0.3, 0.25, 0.2)
    L.box((2 * SX + 0.3, 1.2, 2 * SZ + 0.3), at=(0, -0.55, 0), col=L.STONE, col_fn=L.mottled(L.STONE, 0.08, 5))
    L.box((2 * SX, 0.08, 2 * SZ), at=(0, 0.06, 0), col=(0.38, 0.32, 0.25))

    def walls(collision):
        # back (+z) taller for the lean-to roof
        hb, hf = 2.5, 3.1
        if collision:
            L.box((2 * SX, hf, 0.12), at=(0, hf / 2, SZ - 0.06), collision=True)
            for x in (-SX + 0.06, SX - 0.06):
                L.box((0.12, hf, 2 * SZ), at=(x, hf / 2, 0), collision=True)
            for x0, x1 in ((-SX, -0.5), (0.5, SX)):
                L.box((x1 - x0, hb, 0.12), at=((x0 + x1) / 2, hb / 2, -SZ + 0.06), collision=True)
            L.box((2 * SX + 0.4, 0.15, 2 * SZ + 0.6), at=(0, (hb + hf) / 2 + 0.1, 0), rot=(math.degrees(math.atan2(hf - hb, 2 * SZ)), 0, 0), collision=True)
            return
        n = 14
        for i in range(n):
            x = -SX + 2 * SX * (i + 0.5) / n
            L.box((2 * SX / n - 0.02, hf, 0.08), at=(x, hf / 2, SZ - 0.04), col=L.mottled(BOARD, 0.05)((x, 0, 0), None))
            if abs(x) > 0.55:
                L.box((2 * SX / n - 0.02, hb, 0.08), at=(x, hb / 2, -SZ + 0.04), col=L.mottled(BOARD, 0.05)((x, 1, 0), None))
        for side in (-1, 1):
            for i in range(10):
                z = -SZ + 2 * SZ * (i + 0.5) / 10
                h = hb + (hf - hb) * (z + SZ) / (2 * SZ)
                if side > 0 and abs(z) < 0.4 and True:
                    L.box((0.08, h - 1.6, 2 * SZ / 10 - 0.02), at=(side * (SX - 0.04), 1.6 + (h - 1.6) / 2, z), col=BOARD)
                    L.box((0.08, 0.6, 2 * SZ / 10 - 0.02), at=(side * (SX - 0.04), 0.3, z), col=BOARD)
                    continue
                L.box((0.08, h, 2 * SZ / 10 - 0.02), at=(side * (SX - 0.04), h / 2, z), col=L.mottled(BOARD, 0.05)((0, 0, z), None))
        for x in (-SX, SX):
            for z in (-SZ, SZ):
                L.box((0.16, 3.1, 0.16), at=(x, 1.55, z), col=L.TIMBER)
        L.box((1.2, 0.16, 0.16), at=(0, 2.0, -SZ - 0.02), col=L.TIMBER)
        # Lean-to roof with snow and icicles.
        ang = math.degrees(math.atan2(hf - hb, 2 * SZ))
        L.box((2 * SX + 0.4, 0.12, 2 * SZ + 0.6), at=(0, (hb + hf) / 2 + 0.06, 0), rot=(ang, 0, 0), col=L.TIMBER_OLD)
        L.box((2 * SX + 0.35, 0.18, 2 * SZ + 0.45), at=(0, (hb + hf) / 2 + 0.2, 0.02), rot=(ang, 0, 0), col=L.SNOW, jitter=0.02)
        for i in range(14):
            L.cyl(0.03, L.rnd(0.15, 0.5), at=(-SX + i * 2 * SX / 13, hb - 0.05, -SZ - 0.28), rot=(180, 0, 0), r2=0.0, seg=4, col=L.ICE)
        # Stovepipe through the roof.
        L.cyl(0.09, 1.4, at=(1.6, 2.6, 1.2), seg=8, col=L.IRON)
        L.cyl(0.14, 0.12, at=(1.6, 4.0, 1.2), seg=8, col=L.IRON)
    walls(False)
    walls(True)
    L.box((2 * SX + 0.3, 1.2, 2 * SZ + 0.3), at=(0, -0.55, 0), collision=True)
    L.export(OUT + "workshop_shed.glb")


def workbench():
    L.box((2.2, 0.1, 0.7), at=(0, 0.88, 0), col=L.TIMBER_OLD, jitter=0.005)
    for x in (-1.0, 1.0):
        for z in (-0.28, 0.28):
            L.box((0.1, 0.85, 0.1), at=(x, 0.42, z), col=L.TIMBER)
    L.box((2.0, 0.05, 0.6), at=(0, 0.25, 0), col=L.TIMBER)
    L.box((0.3, 0.2, 0.3), at=(-0.85, 1.03, -0.15), col=L.IRON)  # vice
    for k in range(5):
        L.box((0.4, 0.06, 0.1), at=(-0.2 + k * 0.1, 0.3, 0.0), rot=(0, k * 12, 0), col=(0.6, 0.5, 0.38))  # offcuts
    L.box((2.2, 0.95, 0.7), at=(0, 0.47, 0), collision=True)
    L.export(OUT + "workbench.glb")


def carving_tools():
    """Tool rack (wall plane z=0, faces -z): gouges, chisels, mallet, knife.
    The sisters want to buy him a new chisel; one slot is empty."""
    L.box((1.2, 0.12, 0.06), at=(0, 1.45, -0.03), col=L.TIMBER)
    for i in range(8):
        x = -0.5 + i * 0.14
        if i == 3:
            continue
        L.cyl(0.015, 0.14, at=(x, 1.35, -0.08), seg=5, col=(0.55, 0.42, 0.3))
        L.box((0.012, 0.12, 0.006), at=(x, 1.24, -0.08), col=(0.55, 0.55, 0.58))
    L.cyl(0.05, 0.12, at=(0.55, 1.2, -0.08), rot=(0, 0, 90), seg=8, col=L.TIMBER)
    L.export(OUT + "carving_tools.glb")


def unfinished_carvings():
    """On the bench: a ship half-emerged from its block (his lost fleet), a
    horse, a bird, a girl with a bow."""
    W = (0.72, 0.6, 0.44)
    L.box((0.4, 0.14, 0.14), at=(0, 0.07, 0), col=(0.55, 0.44, 0.31))
    L.ball(0.12, at=(0.12, 0.12, 0), scale=(2.0, 0.6, 0.6), col=W)
    L.cyl(0.008, 0.25, at=(0.1, 0.14, 0), seg=4, col=W)
    L.box((0.12, 0.1, 0.004), at=(0.1, 0.27, 0), col=W)
    L.cyl(0.03, 0.14, at=(-0.35, 0, 0.1), r2=0.018, seg=6, col=W)
    L.ball(0.02, at=(-0.35, 0.16, 0.1), col=W, sub=1)
    L.box((0.004, 0.14, 0.01), at=(-0.31, 0.08, 0.1), rot=(0, 0, 10), col=W)
    L.ball(0.035, at=(-0.2, 0.035, -0.12), scale=(1.5, 1, 1), col=W, sub=1)
    L.export(OUT + "unfinished_carvings.glb")


def cold_stove():
    L.box((0.6, 0.6, 0.5), at=(0, 0.35, 0), col=L.IRON, bevel=0.03)
    for x in (-0.25, 0.25):
        for z in (-0.2, 0.2):
            L.cyl(0.03, 0.08, at=(x, 0, z), seg=4, col=L.IRON)
    L.box((0.3, 0.25, 0.02), at=(0, 0.35, -0.26), col=(0.12, 0.12, 0.13))
    L.cyl(0.09, 1.0, at=(0, 0.65, 0.1), seg=8, col=L.IRON)
    L.ball(0.06, at=(0.0, 0.0, -0.4), scale=(2, 0.3, 1), col=(0.55, 0.53, 0.5), sub=0)  # cold ash
    L.box((0.6, 0.7, 0.5), at=(0, 0.35, 0), collision=True)
    L.export(OUT + "cold_stove.glb")


def workshop_shavings():
    L.seed(60)
    for k in range(60):
        a, r = L.rnd(0, math.tau), L.rnd(0, 0.9) ** 0.7
        L.cyl(0.014, 0.05, at=(r * math.cos(a), 0.004, r * math.sin(a) * 0.6), rot=(90, L.rnd(0, 180), 0), r2=0.006, seg=4, col=(0.82, 0.72, 0.54))
    L.export(OUT + "workshop_shavings.glb")


def woodstack_seasoning():
    """Seasoning blanks for carving: split rounds stacked under a tarp."""
    L.seed(61)
    for i in range(12):
        L.cyl(0.14, 0.4, at=(-0.6 + (i % 5) * 0.3, 0.14 + (i // 5) * 0.26, 0), rot=(90, 0, 0), seg=7, col=(0.4, 0.33, 0.26), col_fn=lambda p, n: (0.72, 0.62, 0.46) if abs(n[2]) > 0.8 else (0.4, 0.33, 0.26))
    L.box((1.7, 0.05, 0.7), at=(0, 0.88, 0), rot=(0, 0, 4), col=(0.4, 0.42, 0.36), jitter=0.02)
    L.box((1.6, 0.1, 0.6), at=(0, 0.95, 0), col=L.SNOW)
    L.export(OUT + "woodstack_seasoning.glb")


# --- Estate keepsakes (collectibles) ------------------------------------------

def ring(r=0.2):
    L.cyl(r, 0.02, at=(0, -0.01, 0), seg=10, col=(0.62, 0.6, 0.6))


def scorched_page():
    ring()
    L.box((0.15, 0.004, 0.2), at=(0, 0.01, 0), rot=(0, 25, 3), col=(0.75, 0.68, 0.52), col_fn=lambda p, n: SCORCH if abs(p[0]) + abs(p[2]) > 0.13 else (0.75, 0.68, 0.52))
    L.export(OUT + "small/scorched_page.glb")


def silver_spoon():
    ring(0.15)
    L.box((0.13, 0.008, 0.012), at=(0, 0.008, 0), col=(0.7, 0.7, 0.72))
    L.ball(0.025, at=(0.08, 0.01, 0), scale=(1.4, 0.3, 1), col=(0.62, 0.6, 0.62), sub=1)
    L.export(OUT + "small/silver_spoon.glb")


def porcelain_shard():
    ring(0.15)
    L.poly([(0, 0.01, 0), (0.06, 0.012, 0.01), (0.03, 0.012, 0.05), (-0.02, 0.01, 0.04)], [(0, 1, 2, 3)], col=(0.92, 0.93, 0.95))
    L.box((0.03, 0.002, 0.006), at=(0.02, 0.014, 0.02), col=(0.25, 0.35, 0.7))
    L.export(OUT + "small/porcelain_shard.glb")


def carved_bird():
    ring(0.15)
    L.ball(0.035, at=(0, 0.03, 0), scale=(1.6, 1, 1), col=(0.7, 0.58, 0.42), sub=1)
    L.ball(0.022, at=(0.045, 0.055, 0), col=(0.7, 0.58, 0.42), sub=1)
    L.export(OUT + "small/carved_bird.glb")


def brass_key():
    ring(0.15)
    L.box((0.09, 0.008, 0.01), at=(0, 0.008, 0), col=(0.68, 0.55, 0.3))
    L.cyl(0.02, 0.008, at=(-0.055, 0.004, 0), seg=8, col=(0.68, 0.55, 0.3))
    L.box((0.015, 0.008, 0.025), at=(0.04, 0.008, 0.012), col=(0.68, 0.55, 0.3))
    L.export(OUT + "small/brass_key.glb")


def ledger_page():
    """A page of the father's shipping ledger: names of ships, all struck out."""
    ring()
    L.box((0.16, 0.004, 0.22), at=(0, 0.01, 0), rot=(0, -15, 2), col=(0.8, 0.76, 0.64))
    for k in range(5):
        L.box((0.12, 0.002, 0.005), at=(0, 0.013, -0.07 + k * 0.035), rot=(0, -15, 0), col=(0.3, 0.25, 0.22))
    L.export(OUT + "small/ledger_page.glb")


def figurehead_fragment():
    """A gilt splinter of a ship figurehead, the father's lost fleet."""
    ring(0.25)
    L.cyl(0.06, 0.3, at=(0, 0.05, 0), rot=(0, 30, -85), r2=0.03, seg=6, col=(0.55, 0.45, 0.3))
    L.ball(0.05, at=(0.2, 0.06, -0.12), col=(0.72, 0.6, 0.32), sub=1)
    L.export(OUT + "small/figurehead_fragment.glb")


def cameo_brooch():
    ring(0.15)
    L.cyl(0.025, 0.008, at=(0, 0.006, 0), seg=10, col=(0.6, 0.5, 0.3))
    L.cyl(0.018, 0.006, at=(0, 0.012, 0), seg=10, col=(0.86, 0.8, 0.74))
    L.export(OUT + "small/cameo_brooch.glb")


def melted_candlestick():
    ring(0.2)
    L.cyl(0.04, 0.02, at=(0, 0, 0), seg=8, col=(0.58, 0.55, 0.5))
    L.cyl(0.012, 0.14, at=(0, 0.0, 0), rot=(0, 0, 70), seg=6, col=(0.58, 0.55, 0.5))
    L.export(OUT + "small/melted_candlestick.glb")


if __name__ == "__main__":
    L.reset()
    for fn in (estate_ruin, estate_beams, estate_staircase, fountain_broken, statue_toppled, parterre_dead,
               rose_briar_overgrown, ornamental_pond, estate_gateposts, family_plot, dead_fruit_tree, rubble_pile,
               workshop_shed, workbench, carving_tools, unfinished_carvings, cold_stove, workshop_shavings,
               woodstack_seasoning, scorched_page, silver_spoon, porcelain_shard, carved_bird, brass_key,
               ledger_page, figurehead_fragment, cameo_brooch, melted_candlestick):
        fn()
