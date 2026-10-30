"""Archeron cottage exterior/shell, its door (intact + broken), the yard props
and the field landmarks. Writes glbs to world/human_realm/cottage/assets/.

Cottage local frame (Godot axes): origin = floor centre at floor level, door
on the -z (front) wall, hearth on the +x gable. The region scene rotates it by
HumanRealmLayout.COTTAGE_YAW. Numbers here are mirrored in cottage_gen.gd
(CottageSpec) for collision-free prop placement.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import cottage_lib as L  # noqa: E402

OUT = "world/human_realm/cottage/assets/"

# Shell dimensions (outer).
HX, HZ = 4.5, 3.2      # half extents
T = 0.5                # wall thickness
H = 2.7                # eaves height
RISE = 2.6             # roof rise
FOOT = -1.2            # stone footing depth
DOOR = (-2.4, -1.4, 0.0, 1.95)
WIN_FRONT = (1.0, 1.8, 0.9, 1.7)
WIN_BACK = (-1.0, -0.2, 0.9, 1.7)


def wallcol(p, _n):
    if p[1] < 1.1:
        return L.mottled(L.STONE, 0.08, 5)(p, _n)
    c = L.mottled(L.PLASTER, 0.05, 3)(p, _n)
    # Smoke staining toward the eaves.
    t = max(0.0, (p[1] - 1.8) / 1.5)
    return tuple(c[k] * (1.0 - 0.35 * t) for k in range(3))


def wall_x(z0, z1, x0, x1, y0, y1, openings, collision=False):
    """Wall running along x (front/back), thickness between z0..z1."""
    cuts = sorted({x0, x1} | {o[0] for o in openings} | {o[1] for o in openings})
    for a, b in zip(cuts, cuts[1:]):
        hole = next((o for o in openings if o[0] <= a and o[1] >= b), None)
        spans = [(y0, y1)] if hole is None else [(y0, hole[2]), (hole[3], y1)]
        for ya, yb in spans:
            if yb - ya > 0.01:
                L.box((b - a, yb - ya, z1 - z0), at=((a + b) / 2, (ya + yb) / 2, (z0 + z1) / 2), col_fn=None if collision else wallcol, collision=collision)


def wall_z(x0, x1, z0, z1, y0, y1, collision=False):
    L.box((x1 - x0, y1 - y0, z1 - z0), at=((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), col_fn=None if collision else wallcol, collision=collision)


def gable(x0, x1, collision=False):
    v = [(x0, H, -HZ), (x0, H, HZ), (x0, H + RISE, 0), (x1, H, -HZ), (x1, H, HZ), (x1, H + RISE, 0)]
    f = [(0, 1, 2), (3, 5, 4), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0)]
    L.poly(v, f, col=L.PLASTER, col_fn=None if collision else wallcol, collision=collision)


def shell(collision):
    wall_x(-HZ, -HZ + T, -HX, HX, FOOT, H, [DOOR, WIN_FRONT], collision)
    wall_x(HZ - T, HZ, -HX, HX, FOOT, H, [WIN_BACK], collision)
    wall_z(-HX, -HX + T, -HZ + T, HZ - T, FOOT, H, collision)
    wall_z(HX - T, HX, -HZ + T, HZ - T, FOOT, H, collision)
    gable(-HX, -HX + T, collision)
    gable(HX - T, HX, collision)
    L.box((2 * HX, 0.3, 2 * HZ), at=(0, -0.15, 0), col=L.EARTH, col_fn=L.mottled(L.EARTH, 0.05, 2), collision=collision)


def cottage():
    L.seed(11)
    shell(False)
    # Timber framing on the outside and the inner wall plate.
    for x in (-HX - 0.03, HX + 0.03):
        for z in (-HZ + 0.1, HZ - 0.1):
            L.box((0.18, H - 1.0, 0.18), at=(x, 1.0 + (H - 1.0) / 2, z), col=L.TIMBER)
    for z in (-HZ - 0.04, HZ + 0.04):
        L.box((2 * HX + 0.1, 0.16, 0.12), at=(0, 1.1, z), col=L.TIMBER)
        L.box((2 * HX + 0.1, 0.2, 0.14), at=(0, H - 0.1, z), col=L.TIMBER)
        for x in (-3.4, -0.6, 2.3, 3.6):
            L.box((0.14, H - 1.2, 0.1), at=(x, 1.1 + (H - 1.1) / 2, z), col=L.TIMBER)
        # Diagonal braces.
        L.box((0.12, 1.9, 0.08), at=(-3.0 if z < 0 else 3.0, 1.9, z), rot=(0, 0, 38 if z < 0 else -38), col=L.TIMBER)
    for z in (-HZ + T + 0.07, HZ - T - 0.07):
        L.box((2 * HX - 2 * T, 0.2, 0.14), at=(0, H - 0.1, z), col=L.TIMBER)
    # Door frame and lintel.
    for x in (DOOR[0] - 0.06, DOOR[1] + 0.06):
        L.box((0.14, DOOR[3] + 0.1, T + 0.06), at=(x, (DOOR[3] + 0.1) / 2, -HZ + T / 2), col=L.TIMBER)
    L.box((DOOR[1] - DOOR[0] + 0.4, 0.2, T + 0.08), at=((DOOR[0] + DOOR[1]) / 2, DOOR[3] + 0.1, -HZ + T / 2), col=L.TIMBER)
    # Window frames + closed shutters, frosted at the edges.
    for (xa, xb, ya, yb), z in ((WIN_FRONT, -HZ - 0.02), (WIN_BACK, HZ + 0.02)):
        w = (xb - xa) / 2
        for i in range(2):
            cx = xa + w * (i + 0.5)
            L.box((w - 0.03, yb - ya - 0.04, 0.06), at=(cx, (ya + yb) / 2, z), col=L.TIMBER_OLD)
            L.box((w - 0.05, 0.05, 0.08), at=(cx, ya + 0.12, z), col=L.FROST)
            L.box((0.05, yb - ya - 0.2, 0.08), at=(cx + (w / 2 - 0.05) * (1 if i else -1), (ya + yb) / 2, z), col=L.FROST)
        L.box((xb - xa + 0.3, 0.08, 0.3), at=((xa + xb) / 2, ya - 0.04, z), col=L.STONE_LIGHT, snow=0.6)
    # Tie beams inside (the food tally is scratched on the middle one).
    for x in (-2.0, 0.0, 2.0):
        L.box((0.22, 0.24, 2 * HZ - 2 * T), at=(x, H - 0.12, 0), col=L.TIMBER, jitter=0.01)
    L.box((0.18, RISE - 0.3, 0.18), at=(0.0, H + (RISE - 0.3) / 2, 0), col=L.TIMBER)
    L.box((2 * HX - 2 * T, 0.2, 0.2), at=(0, H + RISE - 0.35, 0), col=L.TIMBER)
    # Hearth masonry inside the +x gable, sooted firebox.
    hx0, hx1 = 3.25, HX - T
    for z in (-1.0, 1.0):
        L.box((hx1 - hx0, 1.25, 0.3), at=((hx0 + hx1) / 2, 0.62, z), col_fn=L.mottled(L.STONE_DARK, 0.07, 6))
    L.box((hx1 - hx0 + 0.1, 0.35, 2.3), at=((hx0 + hx1) / 2 - 0.05, 1.42, 0), col=L.STONE_DARK, bevel=0.03)
    L.box((0.12, 0.12, 2.5), at=(hx0 - 0.05, 1.62, 0), col=L.TIMBER)  # mantel
    L.box((hx1 - hx0 - 0.15, H - 1.6, 1.5), at=((hx0 + hx1) / 2 + 0.07, 1.6 + (H - 1.6) / 2, 0), col=L.STONE, col_fn=L.gradient(L.SOOT, L.STONE_DARK, 1.6, 2.6))
    L.box((0.05, 1.1, 1.7), at=(hx1 - 0.03, 0.6, 0), col=L.SOOT)
    L.box((1.3, 0.08, 2.4), at=(hx1 - 0.65, 0.04, 0), col=L.STONE_DARK)
    # Chimney stack outside the +x gable.
    top = H + RISE + 0.9
    L.box((0.9, top - FOOT, 1.3), at=(HX + 0.45, (top + FOOT) / 2, 0), col_fn=L.mottled(L.STONE, 0.08, 4), jitter=0.02)
    L.box((1.05, 0.15, 1.45), at=(HX + 0.45, top + 0.05, 0), col=L.STONE_DARK, snow=0.6)
    L.box((0.5, 0.25, 0.6), at=(HX + 0.45, top + 0.25, 0), col=L.SOOT)
    # Thatch, then a heavy snow blanket that stops short of the eaves.
    L.prism_roof(2 * HX, 2 * HZ, RISE, at=(0, H, 0), thick=0.45, col=L.THATCH, snow=2.0, overhang=0.55, jitter=0.03)
    L.prism_roof(2 * HX - 0.2, 2 * HZ - 0.2, RISE, at=(0, H + 0.38, 0), thick=0.25, col=L.SNOW, snow=0.0, overhang=0.42, jitter=0.04)
    L.cyl(0.22, 2 * HX + 1.0, at=(-HX - 0.5, H + RISE + 0.38, 0), rot=(0, 0, -90), col=L.SNOW, seg=8)
    # Icicles along both eaves.
    for side in (-1, 1):
        for i in range(26):
            x = -HX - 0.4 + i * (2 * HX + 0.8) / 25 + L.rnd(-0.1, 0.1)
            ln = L.rnd(0.12, 0.55)
            z = side * (HZ + 0.5)
            L.cyl(0.035, ln, at=(x, H - 0.45, z), rot=(180, 0, 0), r2=0.002, seg=5, col=L.ICE)
    # Snow drifts banked against the walls and a stone step.
    for x, z, s in ((-3.8, -HZ - 0.3, 1.2), (3.2, -HZ - 0.4, 1.0), (-HX - 0.4, 1.5, 1.3), (1.5, HZ + 0.4, 1.4), (-2.5, HZ + 0.4, 1.0)):
        L.ball(0.8, at=(x, -0.1, z), scale=(s * 1.6, 0.45, 0.8), col=L.SNOW, jitter=0.05)
    L.box((1.4, 0.18, 0.7), at=((DOOR[0] + DOOR[1]) / 2, 0.02, -HZ - 0.38), col=L.STONE_LIGHT, bevel=0.04, snow=0.6)
    # Collision: shell, roof, chimney.
    shell(True)
    L.prism_roof(2 * HX, 2 * HZ, RISE, at=(0, H, 0), thick=0.45, collision=True, overhang=0.55)
    L.box((0.9, top - FOOT, 1.3), at=(HX + 0.45, (top + FOOT) / 2, 0), collision=True)
    L.box((hx1 - hx0, 1.6, 2.3), at=((hx0 + hx1) / 2, 0.8, 0), collision=True)
    L.export(OUT + "cottage_shell.glb")


def door_intact():
    w, h = DOOR[1] - DOOR[0] - 0.04, DOOR[3] - 0.03
    for i in range(5):
        x = -w / 2 + w / 5 * (i + 0.5)
        L.box((w / 5 - 0.012, h - L.rnd(0, 0.03), 0.07), at=(x, h / 2, 0), col=L.mottled(L.TIMBER_OLD, 0.05)(( x, 0, 0), None), bevel=0.006)
    for y in (0.3, h - 0.3):
        L.box((w - 0.06, 0.14, 0.05), at=(0, y, 0.06), col=L.TIMBER)
        L.box((w * 0.7, 0.05, 0.02), at=(-w * 0.12, y, -0.045), col=L.IRON)
    L.box((0.05, 1.3, 0.05), at=(0, h / 2, 0.06), rot=(0, 0, 33), col=L.TIMBER)
    L.cyl(0.035, 0.02, at=(w / 2 - 0.12, 1.0, -0.04), rot=(-90, 0, 0), col=L.IRON, seg=8)
    L.box((w, h, 0.12), at=(0, h / 2, 0), collision=True)
    L.export(OUT + "cottage_door_intact.glb")


def door_broken():
    """What is left after the beast comes through: hinge-side shards, the
    latch side gone, splinters strewn inward (+z), claw gouges."""
    L.seed(4)
    w, h = DOOR[1] - DOOR[0] - 0.04, DOOR[3] - 0.03
    for i, hh in enumerate((h, h * 0.8, 0.55)):
        x = -w / 2 + w / 5 * (i + 0.5)
        L.box((w / 5 - 0.012, hh, 0.07), at=(x, h - hh / 2 if i < 2 else hh / 2, 0), col=L.TIMBER_OLD, jitter=0.01)
        L.cyl(0.05, 0.18, at=(x, h - hh if i < 2 else hh, 0), rot=(180, 0, 0), r2=0.001, seg=4, col=L.BONE)
    L.box((w * 0.45, 0.14, 0.05), at=(-w * 0.28, h - 0.3, 0.06), rot=(0, 0, -12), col=L.TIMBER)
    for k in range(3):
        L.box((0.025, 0.7, 0.012), at=(-w * 0.32 + k * 0.06, 1.1, -0.04), rot=(0, 0, 8), col=L.BONE)
    for k in range(9):
        L.box((L.rnd(0.06, 0.12), 0.03, L.rnd(0.3, 0.8)), at=(L.rnd(-0.6, 0.6), 0.02, L.rnd(0.3, 1.6)), rot=(0, L.rnd(0, 180), 0), col=L.TIMBER_OLD)
    L.box((w / 5, 0.07, 1.1), at=(0.2, 0.05, 1.0), rot=(0, 20, 4), col=L.TIMBER_OLD)
    L.export(OUT + "cottage_door_broken.glb")


def outhouse():
    L.seed(7)
    for x in (-0.6, 0.6):
        L.box((0.1, 2.0, 1.2), at=(x, 1.0, 0), col=L.TIMBER_OLD, jitter=0.01)
    L.box((1.3, 2.1, 0.1), at=(0, 1.05, 0.6), col=L.TIMBER_OLD)
    L.box((0.95, 1.8, 0.06), at=(0.0, 0.92, -0.6), rot=(0, 18, 0), col=L.TIMBER)
    L.box((0.1, 0.12, 0.02), at=(0.0, 1.55, -0.64), col=L.SOOT)  # the crescent-ish vent
    L.box((1.5, 0.08, 1.5), at=(0, 2.12, 0), rot=(-8, 0, 0), col=L.TIMBER, snow=0.5)
    L.box((1.45, 0.15, 1.45), at=(0, 2.22, 0.02), rot=(-8, 0, 0), col=L.SNOW)
    L.box((1.3, 2.2, 1.3), at=(0, 1.1, 0), collision=True)
    L.export(OUT + "outhouse.glb")


def woodpile():
    L.seed(8)
    L.box((2.6, 0.1, 0.9), at=(0, 0.05, 0), col=L.TIMBER)
    for row in range(5):
        for i in range(9 - row):
            x = -1.15 + i * 0.28 + row * 0.14
            L.cyl(0.13, 0.85, at=(x, 0.22 + row * 0.24, -0.42), rot=(90, 0, 0), seg=7, col=L.TIMBER_OLD, col_fn=lambda p, n: L.BONE if abs(n[2]) > 0.8 else L.TIMBER_OLD, jitter=0.01)
    L.box((2.9, 0.08, 1.2), at=(0, 1.45, 0), rot=(6, 0, 0), col=L.TIMBER)
    for x in (-1.35, 1.35):
        L.box((0.1, 1.45, 0.1), at=(x, 0.72, 0.5), col=L.TIMBER)
    L.box((2.95, 0.14, 1.25), at=(0, 1.53, 0), rot=(6, 0, 0), col=L.SNOW)
    L.box((2.7, 1.5, 1.0), at=(0, 0.75, 0), collision=True)
    L.export(OUT + "woodpile.glb")


def chopping_block():
    L.cyl(0.33, 0.55, col=L.TIMBER_OLD, seg=10, col_fn=lambda p, n: L.BONE if n[1] > 0.8 else L.TIMBER_OLD)
    L.box((0.05, 0.7, 0.04), at=(0.02, 0.85, 0), rot=(0, 0, 28), col=L.TIMBER_OLD)
    L.box((0.2, 0.14, 0.03), at=(-0.12, 0.6, 0), rot=(0, 0, 28), col=L.IRON)
    for k in range(6):
        L.cyl(0.07, 0.3, at=(0.5 + k * 0.08, 0.04, -0.3 + k * 0.1), rot=(90, k * 30, 0), seg=5, col=L.BONE)
    L.export(OUT + "chopping_block.glb")


def elain_garden():
    """Elain's struggling winter garden: sacking-covered beds, dead stalks, a
    wattle fence, and a few snowdrops she coaxed up. Origin = garden centre."""
    L.seed(9)
    for i, (x, z) in enumerate(((-1.6, -1.0), (0.2, -1.0), (2.0, -1.0), (-0.7, 1.2), (1.1, 1.2))):
        L.box((1.4, 0.3, 0.9), at=(x, 0.15, z), col=L.TIMBER_OLD)
        L.box((1.3, 0.12, 0.8), at=(x, 0.32, z), col=L.EARTH)
        if i % 2 == 0:
            L.box((1.35, 0.06, 0.85), at=(x, 0.4, z), rot=(0, 0, 3), col=L.CLOTH_BROWN, jitter=0.02)
            L.ball(0.5, at=(x, 0.43, z), scale=(1.2, 0.12, 0.7), col=L.SNOW)
        else:
            for k in range(7):
                L.cyl(0.012, L.rnd(0.3, 0.7), at=(x + L.rnd(-0.55, 0.55), 0.35, z + L.rnd(-0.3, 0.3)), rot=(L.rnd(-15, 15), 0, L.rnd(-25, 25)), seg=4, col=L.DEAD_GREEN)
                L.ball(0.035, at=(x + L.rnd(-0.55, 0.55), 0.7, z + L.rnd(-0.3, 0.3)), col=(0.32, 0.26, 0.2), sub=0)
    # Snowdrops: white bells on green stems, the garden's one hope.
    for k in range(9):
        x, z = L.rnd(-0.3, 1.5), 1.2 + L.rnd(-0.3, 0.3)
        L.cyl(0.008, 0.16, at=(x, 0.36, z), seg=4, col=(0.35, 0.5, 0.32))
        L.ball(0.025, at=(x + 0.015, 0.5, z), scale=(1, 1.4, 1), col=(0.97, 0.98, 0.96), sub=1)
    # Wattle fence round three sides.
    for side in range(3):
        for k in range(11):
            t = k / 10
            if side == 0:
                x, z = -2.6 + 5.4 * t, -2.0
            elif side == 1:
                x, z = -2.6, -2.0 + 4.0 * t
            else:
                x, z = 2.8, -2.0 + 4.0 * t
            L.cyl(0.03, 0.75, at=(x, 0, z), seg=5, col=L.TIMBER)
    for y in (0.3, 0.55):
        L.box((5.4, 0.06, 0.05), at=(0.1, y, -2.0), col=L.TIMBER_OLD)
        L.box((0.05, 0.06, 4.0), at=(-2.6, y, 0.0), col=L.TIMBER_OLD)
        L.box((0.05, 0.06, 4.0), at=(2.8, y, 0.0), col=L.TIMBER_OLD)
    # Watering can and trowel.
    L.cyl(0.12, 0.22, at=(2.3, 0, 1.6), seg=8, col=L.IRON)
    L.cyl(0.02, 0.25, at=(2.4, 0.12, 1.6), rot=(0, 0, -60), seg=4, col=L.IRON)
    L.export(OUT + "elain_garden.glb")


def rain_barrel():
    L.cyl(0.38, 0.95, seg=12, col=L.TIMBER_OLD, col_fn=lambda p, n: L.IRON if abs(p[1] - 0.2) < 0.05 or abs(p[1] - 0.75) < 0.05 else L.TIMBER_OLD, r2=0.4)
    L.cyl(0.36, 0.04, at=(0, 0.88, 0), seg=12, col=L.ICE)
    L.cyl(0.4, 0.06, at=(0, 0.94, 0), seg=12, col=L.SNOW)
    L.export(OUT + "rain_barrel.glb")


def snares_hanging():
    """A peg board by the door with wire snares and a hare (or nothing)."""
    L.box((0.9, 0.12, 0.05), at=(0, 1.6, 0), col=L.TIMBER)
    for k, x in enumerate((-0.3, 0.0, 0.3)):
        L.cyl(0.015, 0.1, at=(x, 1.6, -0.02), rot=(-90, 0, 0), seg=4, col=L.TIMBER_OLD)
        for j in range(5):
            a = j / 5 * math.tau
            L.box((0.008, 0.06, 0.008), at=(x + 0.08 * math.cos(a), 1.35 + 0.08 * math.sin(a), -0.06), rot=(0, 0, math.degrees(a)), col=L.IRON)
        L.cyl(0.004, 0.22, at=(x, 1.42, -0.06), seg=3, col=L.IRON)
    L.export(OUT + "snares_hanging.glb")


def drying_rack():
    L.seed(10)
    for x in (-0.9, 0.9):
        L.box((0.08, 1.7, 0.08), at=(x, 0.85, 0), col=L.TIMBER)
    L.box((1.95, 0.08, 0.08), at=(0, 1.65, 0), col=L.TIMBER)
    L.box((1.95, 0.06, 0.06), at=(0, 1.0, 0), col=L.TIMBER)
    # A stretched hide and bundles of drying herbs, rabbit pelts.
    L.box((0.7, 0.9, 0.03), at=(-0.35, 1.15, 0.05), col=(0.48, 0.38, 0.28), jitter=0.02)
    for k in range(4):
        L.cyl(0.05, 0.28, at=(0.25 + k * 0.17, 1.35, 0), rot=(180, 0, 0), r2=0.02, seg=5, col=(0.36, 0.38, 0.3))
    L.box((0.18, 0.4, 0.04), at=(0.5, 0.75, 0.05), col=(0.58, 0.52, 0.45))
    L.box((2.0, 0.06, 0.12), at=(0, 1.71, 0), col=L.SNOW)
    L.export(OUT + "drying_rack.glb")


def scarecrow():
    L.seed(12)
    L.cyl(0.06, 2.3, seg=6, col=L.TIMBER)
    L.box((1.6, 0.08, 0.08), at=(0, 1.75, 0), col=L.TIMBER)
    L.box((0.6, 0.75, 0.3), at=(0, 1.5, 0), col=L.CLOTH_BROWN, jitter=0.03)
    for x in (-0.55, 0.55):
        L.box((0.5, 0.18, 0.2), at=(x, 1.75, 0), col=L.CLOTH_GREY, jitter=0.03)
        for k in range(4):
            L.cyl(0.01, 0.18, at=(x * 1.45, 1.75, -0.05 + k * 0.03), rot=(0, 0, 100 * (1 if x > 0 else -1)), seg=3, col=L.THATCH)
    L.ball(0.2, at=(0, 2.1, 0), scale=(1, 1.1, 1), col=(0.55, 0.5, 0.42), jitter=0.02)
    L.cyl(0.32, 0.04, at=(0, 2.25, 0), seg=10, col=L.TIMBER_OLD)
    L.cyl(0.17, 0.25, at=(0, 2.27, 0), r2=0.12, seg=10, col=L.TIMBER_OLD)
    L.cyl(0.33, 0.06, at=(0, 2.3, 0), seg=10, col=L.SNOW)
    L.box((0.05, 0.05, 0.02), at=(-0.07, 2.13, -0.19), col=L.SOOT)
    L.box((0.05, 0.05, 0.02), at=(0.07, 2.13, -0.19), col=L.SOOT)
    L.box((0.8, 0.06, 0.24), at=(0, 1.83, 0), col=L.SNOW)
    # A crow on the arm.
    L.ball(0.08, at=(0.65, 1.88, 0), scale=(1, 0.9, 1.6), col=L.SOOT)
    L.ball(0.05, at=(0.65, 1.97, -0.1), col=L.SOOT)
    L.cyl(0.02, 0.06, at=(0.65, 1.97, -0.14), rot=(-90, 0, 0), r2=0.0, seg=4, col=(0.25, 0.22, 0.2))
    L.export(OUT + "scarecrow.glb")


def shepherd_hut_ruin():
    """Roofless dry-stone hut, a doorway, a collapsed corner, a sapling in it."""
    L.seed(13)
    for i in range(14):
        a = i / 14 * math.tau
        if 0.2 < a < 0.75:
            continue  # doorway
        hgt = 1.6 if not (3.0 < a < 4.2) else L.rnd(0.4, 0.8)
        L.box((1.0, hgt, 0.5), at=(2.2 * math.cos(a), hgt / 2, 2.2 * math.sin(a)), rot=(0, -math.degrees(a) + 90, 0), col_fn=L.mottled(L.STONE, 0.1, 5), jitter=0.04, snow=0.7)
        L.box((1.0, hgt, 0.5), at=(2.2 * math.cos(a), hgt / 2, 2.2 * math.sin(a)), rot=(0, -math.degrees(a) + 90, 0), collision=True)
    for k in range(10):
        a = L.rnd(3.0, 4.2)
        L.ball(0.25, at=((2.2 + L.rnd(0.2, 1.4)) * math.cos(a), 0.1, (2.2 + L.rnd(0.2, 1.4)) * math.sin(a)), col=L.STONE, jitter=0.05, sub=0, snow=0.6)
    for k in range(3):
        L.box((0.12, 0.12, 2.6), at=(L.rnd(-0.6, 0.6), 0.1 + k * 0.08, L.rnd(-0.6, 0.6)), rot=(0, L.rnd(0, 180), L.rnd(-8, 8)), col=L.CHAR)
    L.cyl(0.6, 0.06, at=(0.4, 0, 0.3), seg=10, col=L.SOOT)  # old fire ring
    L.export(OUT + "shepherd_hut_ruin.glb")


def frozen_pond():
    """Ice disc with a snow lip and a few reeds; origin at the ice surface."""
    L.seed(14)
    L.cyl(1.0, 0.1, at=(0, -0.1, 0), seg=28, col=L.ICE, col_fn=lambda p, n: (0.5, 0.64, 0.76) if (p[0] ** 2 + p[2] ** 2) < 0.4 else L.ICE, smooth=False)
    for i in range(18):
        a = i / 18 * math.tau
        L.ball(0.18, at=(1.02 * math.cos(a), -0.02, 1.02 * math.sin(a)), scale=(1.4, 0.4, 1.0), rot=(0, -math.degrees(a), 0), col=L.SNOW, sub=1)
    for k in range(4):
        L.box((L.rnd(0.2, 0.5), 0.004, 0.006), at=(L.rnd(-0.5, 0.5), 0.002, L.rnd(-0.5, 0.5)), rot=(0, L.rnd(0, 180), 0), col=(0.9, 0.95, 1.0))
    L.export(OUT + "frozen_pond.glb")


def drystone_wall():
    """4 m dry-stone field wall with a snow cap; tiled along field lines."""
    L.seed(15)
    for row in range(3):
        x = -2.0
        while x < 2.0:
            ln = L.rnd(0.35, 0.6)
            L.box((min(ln, 2.0 - x), 0.32, 0.55 - row * 0.08), at=(x + ln / 2, 0.16 + row * 0.3, L.rnd(-0.03, 0.03)), col_fn=L.mottled(L.STONE, 0.1, 6), bevel=0.04)
            x += ln
    L.box((4.0, 0.12, 0.45), at=(0, 0.98, 0), col=L.SNOW, jitter=0.02)
    L.export(OUT + "drystone_wall.glb")


if __name__ == "__main__":
    L.reset()
    for fn in (cottage, door_intact, door_broken, outhouse, woodpile, chopping_block, elain_garden, rain_barrel,
               snares_hanging, drying_rack, scarecrow, shepherd_hut_ruin, frozen_pond, drystone_wall):
        fn()
