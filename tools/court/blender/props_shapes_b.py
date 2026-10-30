"""Court-props builders, part B: fae village, solstice, Old Shrines, autumn border, blight, generic."""
import math
from mathutils import Vector
import props_lib as L
from props_lib import T, MB, TAU
from props_shapes_a import P, FLOWER_COLS, colbox, colcyl, ivy, ivy_on_cyl, flecks, hanging_ribbon


# ------------------------------------------------------------------ fae village

def _flower_box(mb, rng, xf, w=0.9, n=3):
    L.rbox(mb, w, 0.3, 0.25, P["wood_pale"], xf, seg=6, rings=4, e=0.3)
    for i in range(n):
        x = -w / 2 + w * (i + 0.5) / n
        L.bloom(mb, (x, 0, 0.32), 0.12, P[FLOWER_COLS[rng.randrange(8)]], P["butter"], xf, detail=0)
        L.sphere(mb, 0.1, 0.06, 0.08, P["leaf"], xf @ T(x + 0.08, -0.1, 0.26), 5, 3)


def _round_window(mb, rng, r_wall, ang, z, size=0.42, glow="window_glow", box=True):
    a = math.radians(ang)
    pos = (r_wall * math.cos(a), r_wall * math.sin(a), z)
    xf = T(*pos, rz=ang + 90, rx=90)
    L.disc(mb, size, 12, P[glow], xf @ T(0, 0, 0.03))
    L.torus(mb, size, 0.06, P["gold"], xf @ T(0, 0, 0.04), 10, 3)
    L.box(mb, size * 1.8, 0.04, 0.04, P["gold"], T(*pos, rz=ang + 90) @ T(0, -0.05, 0, ry=0), base=False)
    if box:
        _flower_box(mb, rng, T((r_wall + 0.15) * math.cos(a), (r_wall + 0.15) * math.sin(a), z - size - 0.32, rz=ang + 90))


def _round_door(mb, r_wall, h=2.1, col="door_mint", ang=-90):
    a = math.radians(ang)
    pos = (r_wall * math.cos(a), r_wall * math.sin(a), 0.4)
    xf = T(*pos, rz=ang + 90)
    L.rbox(mb, 1.1, 0.25, h, P[col], xf, seg=10, rings=8, e=0.55)
    L.torus(mb, 0.6, 0.06, P["rosegold"], xf @ T(0, -0.1, h * 0.62, rx=90, s=(1, 1.4, 1)), 14, 4, arc=0.5)
    L.ball(mb, (0, 0, 0), 0.06, P["gold"], 6, 4, xf @ T(0.33, -0.14, h * 0.45))
    L.rbox(mb, 1.3, 0.7, 0.18, P["stone_pale"], T((r_wall + 0.3) * math.cos(a), (r_wall + 0.3) * math.sin(a), 0.0, rz=ang + 90), seg=6, rings=4)
    # little door lantern
    la = a + 0.42
    lp = ((r_wall + 0.18) * math.cos(la), (r_wall + 0.18) * math.sin(la), h * 0.95)
    L.cyl(mb, 0.1, 0.1, 0.22, 6, P["lantern"], T(*lp))
    L.cone(mb, 0.14, 0.14, 6, P["gold"], T(lp[0], lp[1], lp[2] + 0.22))


def fae_cottage(mb, rng, out, wall="butter", roof="rose", style="cone", r=2.6, wall_h=3.0, door="door_mint", chimney=True,
                windows=3, garden=True):
    L.lathe(mb, [(r + 0.2, 0.0), (r + 0.2, 0.4)], 20, P["stone_pale"], cap_bot=False, cap_top=True)
    L.lathe(mb, [(r, 0.4), (r * 1.04, 1.4), (r * 1.03, 2.3), (r * 0.97, wall_h)], 20, P[wall], cap_bot=False, cap_top=False)
    L.torus(mb, r + 0.06, 0.08, P["rosegold"], T(0, 0, 0.45), 20, 3)
    L.torus(mb, r * 0.98, 0.08, P["rosegold"], T(0, 0, wall_h - 0.05), 20, 3)
    zr = wall_h
    if style == "mushroom":
        prof = [(r * 1.3, zr), (r * 1.4, zr + 0.5), (r * 1.25, zr + 1.4), (r * 0.8, zr + 2.2), (0.0, zr + 2.5)]
        L.lathe(mb, prof, 20, P[roof], cap_bot=True, col_cap=P["cream"])
        for i in range(9):
            a = TAU * i / 9 + 0.3
            k = 0.55 + 0.25 * (i % 3) / 2
            rr = r * 1.3 * k + 0.1
            L.sphere(mb, 0.25, 0.25, 0.08, P["cream"], T(rr * math.cos(a), rr * math.sin(a), zr + 2.5 - 1.8 * k * k + 0.1,
                     rz=math.degrees(a), ry=-35 * k), 6, 3)
        top_z = zr + 2.5
    else:
        h = 3.2 if style != "tiered" else 2.4
        prof = [(r * 1.28, zr), (r * 1.05, zr + 0.6), (r * 0.6, zr + h * 0.65), (0.18, zr + h), (0.0, zr + h + 0.35, 0.25, 0.0)]
        L.lathe(mb, prof, 20, P[roof], cap_bot=True, col_cap=P["blush"])
        rows = ((r * 1.26, zr + 0.02, 14), (r * 0.85, zr + h * 0.38, 10))
        for row, (rr, z, n) in enumerate(rows[:1] if style == "tiered" else rows):
            for i in range(n):
                a = TAU * (i + 0.5 * row) / n
                L.sphere(mb, 0.42 if row == 0 else 0.36, 0.22, 0.2, P[roof] if i % 2 else P["blush"],
                         T(rr * math.cos(a), rr * math.sin(a), z, rz=math.degrees(a) + 90, rx=-30), 5, 3)
        L.ball(mb, (0.25, 0, zr + h + 0.4), 0.13, P["gold"], 6, 4)
        top_z = zr + h
        if style == "tiered":
            r2, z2 = r * 0.5, zr + 1.3
            L.lathe(mb, [(r2, z2), (r2, z2 + 1.4)], 14, P[wall], cap_bot=False, cap_top=False)
            L.torus(mb, r2 + 0.04, 0.06, P["rosegold"], T(0, 0, z2 + 1.4), 14, 4)
            L.lathe(mb, [(r2 * 1.35, z2 + 1.4), (r2 * 0.7, z2 + 2.3), (0.0, z2 + 3.0)], 14, P[roof], cap_bot=True)
            _round_window(mb, rng, r2 + 0.01, -90, z2 + 0.75, 0.28, box=False)
            top_z = z2 + 3.0
    _round_door(mb, r * 1.03 + 0.02, col=door)
    for ang, z in ((-150, 1.75), (60, 1.7), (-35, 1.7))[:windows]:
        _round_window(mb, rng, r * 1.04 + 0.01, ang, z)
    if chimney:
        pts = [(r * 0.55, r * 0.35, zr + 0.6), (r * 0.6, r * 0.38, zr + 2.0), (r * 0.5, r * 0.32, zr + 2.8), (r * 0.58, r * 0.36, zr + 3.4)]
        L.tube(mb, pts, 0.28, P["pearl_rose"], seg=7, r_end=0.24)
        L.torus(mb, 0.27, 0.06, P["rosegold"], T(*pts[-1]), 8, 3)
    for i in range(7 if garden else 0):
        a = math.radians(-60 + 300 * i / 6)
        if -110 < math.degrees(a) < -70:
            continue
        L.bloom(mb, ((r + 0.45) * math.cos(a), (r + 0.45) * math.sin(a), 0.05), 0.16, P[FLOWER_COLS[i % 8]], P["butter"], detail=0)
        L.sphere(mb, 0.22, 0.2, 0.16, P["leaf"], T((r + 0.35) * math.cos(a + 0.12), (r + 0.35) * math.sin(a + 0.12), 0.0), 5, 3)
    colcyl(out, r * 1.04, wall_h, seg=12)
    colcyl(out, r * 0.9, top_z - wall_h, T(0, 0, wall_h), seg=8)


def fae_bakery(mb, rng, out):
    fae_cottage(mb, rng, out, wall="cream", roof="coral", style="cone", r=2.9, door="rose", chimney=False, windows=2, garden=False)
    pts = [(-1.4, 1.2, 4.2), (-1.5, 1.25, 5.8), (-1.4, 1.2, 6.6)]
    L.tube(mb, pts, 0.4, P["pearl_rose"], seg=8, r_end=0.36)
    L.torus(mb, 0.38, 0.08, P["gold"], T(*pts[-1]), 8, 3)
    for i in range(5):
        L.sphere(mb, 0.3 + 0.08 * i, 0.3 + 0.08 * i, 0.25, P["white"], T(-1.4 + 0.15 * i, 1.2, 6.9 + 0.45 * i), 6, 3)
    # striped awning over a bread shelf to the right of the door
    for i in range(6):
        x = 0.7 + i * 0.3
        L.strip(mb, [(x, -2.95, 2.6), (x, -3.8, 2.15)], Vector((1, 0, 0)), 0.3, P["coral"] if i % 2 else P["cream"])
    L.rbox(mb, 1.9, 0.6, 0.85, P["wood_pale"], T(1.45, -3.35, 0.4), seg=6, rings=4, e=0.3)
    for i in range(7):
        L.sphere(mb, 0.18, 0.1, 0.09, P["wood_pale"] if i % 2 else P["butter"], T(0.7 + i * 0.25, -3.35 + 0.1 * (i % 2), 1.32, rz=20 * i), 6, 4)
    for i in range(3):
        L.sphere(mb, 0.14, 0.14, 0.1, P["rose"], T(0.9 + i * 0.5, -3.55, 1.28), 6, 4)
        L.ball(mb, (0.9 + i * 0.5, -3.55, 1.38), 0.04, P["red"], 4, 3)
    L.torus(mb, 0.28, 0.07, P["wood"], T(-1.0, -3.4, 2.7, rx=90), 12, 4)
    L.torus(mb, 0.16, 0.06, P["wood"], T(-1.12, -3.4, 2.8, rx=90), 10, 4)
    L.cyl(mb, 0.025, 0.025, 0.7, 4, P["gold"], T(-1.0, -3.0, 3.1, rx=90))
    colbox(out, 1.9, 0.7, 1.3, T(1.45, -3.35, 0))


def fae_seamstress_shop(mb, rng, out):
    L.rbox(mb, 6.2, 4.6, 0.4, P["stone_pale"], seg=8, rings=4, e=0.2)
    L.rbox(mb, 5.8, 4.2, 3.6, P["blush"], T(0, 0, 0.3), seg=12, rings=8, e=0.25)
    L.rbox(mb, 6.8, 5.2, 0.35, P["rosegold"], T(0, 0, 3.75), seg=10, rings=4, e=0.2)
    L.lathe(mb, [(1.0, 3.95), (0.75, 5.2), (0.35, 6.4), (0.0, 7.0)], 16, P["lilac"], T(s=(3.4, 2.6, 1)), cap_bot=True)
    for i in range(18):
        a = TAU * i / 18
        L.sphere(mb, 0.55, 0.3, 0.22, P["lilac"] if i % 2 else P["peri"], T(3.3 * math.cos(a), 2.5 * math.sin(a), 4.0, rz=math.degrees(a) + 90, rx=-30), 5, 3)
    L.ball(mb, (0, 0, 7.05), 0.16, P["gold"], 6, 4)
    # front: door + display window with dress form
    L.rbox(mb, 1.2, 0.25, 2.3, P["door_mint"], T(-1.4, -2.15, 0.4), seg=10, rings=8, e=0.55)
    L.ball(mb, (-1.05, -2.3, 1.4), 0.06, P["gold"], 6, 4)
    L.rbox(mb, 2.2, 0.15, 1.7, P["window_glow"], T(1.2, -2.12, 1.0), seg=8, rings=6, e=0.4)
    L.torus(mb, 1.12, 0.06, P["gold"], T(1.2, -2.2, 2.7, rx=90, s=(1, 0.7, 1)), 16, 4, arc=0.5)
    L.lathe(mb, [(0.05, 0.0), (0.22, 0.35), (0.16, 0.65), (0.25, 0.95), (0.0, 1.1)], 10, P["rose"], T(1.2, -1.9, 1.1))
    # ribbon awning (striped) with scallops
    for i in range(10):
        x = -2.7 + i * 0.6
        L.strip(mb, [(x, -2.15, 3.3), (x, -3.0, 2.95), (x, -3.6, 2.7)], Vector((1, 0, 0)), 0.6, P["rose"] if i % 2 else P["cream"])
        L.sphere(mb, 0.28, 0.08, 0.16, P["rose"] if i % 2 else P["cream"], T(x, -3.6, 2.66), 6, 3)
    for x in (-2.95, 2.95):
        hanging_ribbon(mb, (x, -3.55, 2.7), 1.2, P["gold"], (0, -0.1), 0.07)
        hanging_ribbon(mb, (x, -3.55, 2.7), 1.0, P["lilac"], (0.1, -0.15), 0.07)
    # table of cloth bolts
    L.rbox(mb, 2.4, 0.9, 0.85, P["wood_pale"], T(1.3, -3.2, 0.0), seg=6, rings=4, e=0.3)
    bolts = ["rose", "lilac", "mint", "butter", "peri", "blush", "coral"]
    for i, c in enumerate(bolts):
        x = 0.4 + i * 0.3
        L.cyl(mb, 0.13, 0.13, 0.8, 10, P[c], T(x, -3.6, 1.0, rx=90), col_cap=P["cream"])
    for i, c in enumerate(("gold", "rose", "peri")):
        L.cyl(mb, 0.12, 0.12, 0.14, 10, P["wood"], T(0.6 + i * 0.6, -2.95, 0.85))
        L.cyl(mb, 0.1, 0.1, 0.12, 10, P[c], T(0.6 + i * 0.6, -2.95, 0.86))
    # spool sign
    L.cyl(mb, 0.04, 0.04, 1.0, 5, P["gold"], T(-2.9, -2.2, 3.0, rx=90))
    L.cyl(mb, 0.35, 0.35, 0.08, 12, P["gold"], T(-2.9, -2.95, 2.9, ry=90))
    L.cyl(mb, 0.22, 0.22, 0.4, 10, P["rose"], T(-3.1, -2.95, 2.9, ry=90))
    L.cyl(mb, 0.35, 0.35, 0.08, 12, P["gold"], T(-2.7, -2.95, 2.9, ry=90))
    for ang in (90, 180):
        _round_window(mb, rng, 2.15 if ang == 90 else 2.95, ang, 1.9, 0.45, box=True)
    colbox(out, 6.0, 4.4, 3.9)
    colbox(out, 2.4, 0.9, 0.85, T(1.3, -3.2, 0))


def fae_potion_house(mb, rng, out):
    prof = []
    for k in range(7):
        z = 0.3 + 4.2 * k / 6
        prof.append((2.0 - 0.15 * math.sin(k), z, 0.12 * math.sin(k * 0.9), 0.08 * math.cos(k * 1.3)))
    L.lathe(mb, [(2.3, 0.0), (2.3, 0.3)], 16, P["stone_pale"], cap_top=True)
    L.lathe(mb, prof, 16, P["lilac"], cap_bot=False, cap_top=False)
    L.torus(mb, 2.02, 0.08, P["gold"], T(0, 0, 0.35), 16, 4)
    zt = 4.5
    roof = [(2.7, zt, 0.1), (2.1, zt + 0.8, 0.15), (1.2, zt + 2.2, 0.35), (0.5, zt + 3.4, 0.8, 0.1), (0.0, zt + 4.0, 1.3, 0.3)]
    L.lathe(mb, roof, 16, P["plum"], cap_bot=True, col_cap=P["lilac"])
    for i in range(14):
        a = TAU * i / 14
        L.sphere(mb, 0.4, 0.22, 0.2, P["plum"] if i % 2 else P["peri"], T(2.6 * math.cos(a) + 0.1, 2.6 * math.sin(a), zt, rz=math.degrees(a) + 90, rx=-30), 5, 3)
    L.ball(mb, (1.3, 0.3, zt + 4.05), 0.14, P["glow_teal"], 6, 4)
    pts = [(-0.9, 0.9, zt + 0.6), (-1.1, 1.0, zt + 1.6), (-0.7, 1.05, zt + 2.4), (-1.0, 0.9, zt + 3.0), (-0.6, 1.0, zt + 3.7)]
    L.tube(mb, pts, 0.3, P["pearl_rose"], seg=7, r_end=0.22)
    for i in range(4):
        L.sphere(mb, 0.18 + 0.07 * i, 0.18 + 0.07 * i, 0.15, P["glow_lilac"], T(-0.6 + 0.12 * i, 1.0, zt + 3.95 + 0.35 * i), 6, 4)
    _round_door(mb, 2.02, h=2.2, col="teal")
    bottle_cols = ["glow_teal", "glow_rose", "glow_lilac", "glow_gold"]
    for ang, z in ((-30, 1.6), (-150, 1.7), (40, 3.2), (160, 3.0)):
        a = math.radians(ang)
        r = 2.05
        L.rbox(mb, 1.0, 0.12, 1.1, P["window_glow"] if ang < 0 else P["glow_teal"], T(r * math.cos(a), r * math.sin(a), z - 0.5, rz=ang + 90), seg=6, rings=4, e=0.5)
        L.rbox(mb, 1.15, 0.35, 0.08, P["wood_pale"], T((r + 0.12) * math.cos(a), (r + 0.12) * math.sin(a), z - 0.6, rz=ang + 90), seg=6, rings=3)
        for b in range(4):
            off = (b - 1.5) * 0.24
            bx = (r + 0.16) * math.cos(a) - math.sin(a) * off
            by = (r + 0.16) * math.sin(a) + math.cos(a) * off
            hh = 0.16 + 0.06 * (b % 2)
            L.lathe(mb, [(0.07, 0.0), (0.09, hh * 0.6), (0.03, hh), (0.03, hh + 0.08)], 5, P[bottle_cols[(b + int(ang)) % 4]], T(bx, by, z - 0.52), cap_bot=False)
    # cauldron by the door
    L.lathe(mb, [(0.3, 0.1), (0.55, 0.35), (0.58, 0.6), (0.5, 0.8)], 12, P["plum"], T(1.3, -2.6, 0), cap_bot=True, cap_top=False)
    L.disc(mb, 0.49, 12, P["glow_teal"], T(1.3, -2.6, 0.72))
    for i in range(5):
        L.ball(mb, (1.3 + rng.uniform(-0.25, 0.25), -2.6 + rng.uniform(-0.25, 0.25), 0.8 + 0.12 * i), 0.05 + 0.01 * i, P["glow_teal"], 5, 3)
    for i in range(3):
        a = TAU * i / 3
        L.cyl(mb, 0.04, 0.04, 0.2, 4, P["gold"], T(1.3 + 0.35 * math.cos(a), -2.6 + 0.35 * math.sin(a), 0))
    ivy_on_cyl(mb, rng, 2.05, 100, 200, 0.4, 3.8, 18, size=0.26, flowers=0.4)
    colcyl(out, 2.1, zt, seg=10)
    colcyl(out, 2.0, 2.5, T(0, 0, zt), seg=8)


def fae_market_stall(mb, rng, out, canopy=("rose", "cream"), goods="fruit"):
    w, d, h = 3.2, 1.8, 2.6
    for sx in (-1, 1):
        for sy in (-1, 1):
            L.cyl(mb, 0.07, 0.06, h + (0.3 if sy > 0 else 0.0), 7, P["wood_pale"], T(sx * w / 2, sy * d / 2, 0))
            L.ball(mb, (sx * w / 2, sy * d / 2, h + (0.35 if sy > 0 else 0.05)), 0.09, P["gold"], 6, 4)
    L.rbox(mb, w, 0.9, 0.95, P["wood_pale"], T(0, -d / 2 + 0.45, 0), seg=8, rings=4, e=0.25)
    L.rbox(mb, w + 0.1, 0.95, 0.08, P["mint"], T(0, -d / 2 + 0.45, 0.95), seg=8, rings=3, e=0.25)
    for i in range(8):
        x = -w / 2 + (i + 0.5) * w / 8
        c = P[canopy[i % 2]]
        L.strip(mb, [(x, d / 2 + 0.15, h + 0.35), (x, 0, h + 0.55), (x, -d / 2 - 0.3, h + 0.05)], Vector((1, 0, 0)), w / 8, c)
        L.sphere(mb, w / 16, 0.06, 0.13, c, T(x, -d / 2 - 0.3, h + 0.0), 6, 3)
    for sx in (-1, 1):
        hanging_ribbon(mb, (sx * w / 2, -d / 2 - 0.3, h), 0.9, P["gold"], (0, -0.1), 0.06)
    top = 1.03
    if goods == "fruit":
        fruit = ["red", "butter", "coral", "berry", "plum", "leaf"]
        for b in range(4):
            x = -1.2 + b * 0.8
            L.lathe(mb, [(0.18, 0.0), (0.32, 0.18)], 10, P["wood"], T(x, -0.45, top), cap_bot=True, cap_top=False)
            for k in range(7):
                a = TAU * k / 7
                L.ball(mb, (x + 0.16 * math.cos(a), -0.45 + 0.16 * math.sin(a), top + 0.2 + 0.03 * (k % 2)), 0.08, P[fruit[(b + k) % 6]], 6, 4)
            L.ball(mb, (x, -0.45, top + 0.28), 0.085, P[fruit[b]], 6, 4)
        for k in range(5):
            L.bloom(mb, (-1.4 + k * 0.7, 0.35, top), 0.14, P[FLOWER_COLS[k]], P["butter"], detail=1)
    elif goods == "cloth":
        for b in range(6):
            x = -1.3 + b * 0.52
            L.rbox(mb, 0.45, 0.6, 0.18, P[["lilac", "mint", "rose", "butter", "peri", "blush"][b]], T(x, -0.45, top), seg=6, rings=3, e=0.4)
            L.rbox(mb, 0.42, 0.56, 0.14, P[["blush", "cream", "lilac", "peri", "rose", "mint"][b]], T(x, -0.45, top + 0.18), seg=6, rings=3, e=0.4)
        L.tube(mb, [(-w / 2, d / 2, 2.2), (w / 2, d / 2, 2.2)], 0.03, P["gold"], seg=4)
        for i in range(9):
            x = -1.45 + i * 0.36
            hanging_ribbon(mb, (x, d / 2, 2.2), 0.9 + 0.2 * (i % 3), P[FLOWER_COLS[i % 8]], (0, -0.05), 0.1)
    else:
        jar_cols = ["peri", "rose", "mint", "butter", "lilac", "coral", "teal"]
        for b in range(7):
            x = -1.35 + b * 0.45
            hh = 0.3 + 0.12 * (b % 3)
            L.lathe(mb, [(0.0, 0.0), (0.14, 0.0), (0.19, hh * 0.45), (0.1, hh * 0.85), (0.12, hh)], 10, P[jar_cols[b]], T(x, -0.45, top), cap_top=False)
            L.torus(mb, 0.15, 0.015, P["gold"], T(x, -0.45, top + hh * 0.45), 10, 3)
        for b in range(4):
            L.lathe(mb, [(0.0, 0.0), (0.25, 0.04), (0.3, 0.1)], 12, P[jar_cols[b + 2]], T(-1.1 + b * 0.7, 0.4, top), cap_top=False)
    colbox(out, w, 0.9, 1.0, T(0, -d / 2 + 0.45, 0))


def fae_well(mb, rng, out):
    L.lathe(mb, [(1.05, 0.0), (1.1, 0.85), (1.15, 0.95), (0.8, 0.95), (0.78, 0.25)], 18, P["stone_pale"], cap_bot=False, cap_top=False, smooth=True)
    L.disc(mb, 0.79, 18, P["water"], T(0, 0, 0.3))
    L.torus(mb, 1.0, 0.06, P["rosegold"], T(0, 0, 0.98), 18, 4)
    for i in range(16):
        a = TAU * i / 16
        L.rbox(mb, 0.42, 0.12, 0.25, P["pearl_rose"] if i % 2 else P["pearl"], T(1.1 * math.cos(a), 1.1 * math.sin(a), 0.25, rz=math.degrees(a) + 90), seg=5, rings=3)
    for sx in (-1, 1):
        L.cyl(mb, 0.08, 0.08, 2.4, 7, P["wood_pale"], T(sx * 0.95, 0, 0.9))
    L.cyl(mb, 0.07, 0.07, 2.1, 8, P["wood"], T(-1.05, 0, 2.15, ry=90))
    L.tube(mb, [(1.05, 0, 2.15), (1.25, 0, 2.15), (1.25, -0.25, 2.0)], 0.03, P["gold"], seg=4)
    L.tube(mb, [(0.1, 0, 2.1), (0.1, 0, 1.3)], 0.015, P["cream"], seg=3)
    L.lathe(mb, [(0.13, 1.0), (0.17, 1.3)], 8, P["wood"], T(0.1, 0, 0.0), cap_bot=True, cap_top=False)
    L.torus(mb, 0.17, 0.015, P["gold"], T(0.1, 0, 1.28), 8, 3)
    L.lathe(mb, [(1.75, 3.1), (1.1, 3.55), (0.0, 4.1)], 4, P["rose"], T(), cap_bot=True, col_cap=P["blush"], phase=math.radians(45))
    for i in range(12):
        a = TAU * i / 12
        L.sphere(mb, 0.35, 0.16, 0.14, P["rose"] if i % 2 else P["blush"], T(1.4 * math.cos(a), 1.4 * math.sin(a), 3.1, rz=math.degrees(a) + 90, rx=-25), 5, 3)
    L.ball(mb, (0, 0, 4.15), 0.12, P["gold"], 6, 4)
    for i in range(8):
        a = TAU * i / 8 + 0.2
        L.bloom(mb, (1.35 * math.cos(a), 1.35 * math.sin(a), 0.03), 0.13, P[FLOWER_COLS[i]], P["butter"], detail=0)
    colcyl(out, 1.15, 1.0, seg=10)


def fae_footbridge(mb, rng, out, span=8.0, width=2.0, rise=1.3):
    n = 18
    for i in range(n):
        t = (i + 0.5) / n
        x = -span / 2 + span * t
        z = rise * math.sin(math.pi * t)
        slope = math.degrees(math.atan(rise * math.pi / span * math.cos(math.pi * t)))
        L.box(mb, span / n * 0.96, width, 0.12, P["wood_pale"] if i % 2 else P["wood"], T(x, 0, z, ry=-slope))
    for i in range(0, n + 1, 3):
        t = i / n
        x = -span / 2 + span * t
        z = rise * math.sin(math.pi * t)
        for sy in (-1, 1):
            L.cyl(mb, 0.06, 0.06, 0.95, 6, P["white"], T(x, sy * width / 2, z))
            L.ball(mb, (x, sy * width / 2, z + 1.0), 0.07, P["gold"], 6, 4)
    for sy in (-1, 1):
        rail = [(-span / 2 + span * k / 12, sy * width / 2, rise * math.sin(math.pi * k / 12) + 0.92) for k in range(13)]
        L.tube(mb, rail, 0.045, P["white"], seg=5)
        for k in range(6):
            a = rail[2 * k]
            b = rail[2 * k + 2]
            g = L.catenary((a[0], a[1] - sy * 0.04, a[2] - 0.1), (b[0], b[1] - sy * 0.04, b[2] - 0.1), 0.22, 3)
            L.tube(mb, g, 0.03, P["leaf"], seg=4)
            for j, p in enumerate(g[1:-1]):
                L.bloom(mb, (p.x, p.y, p.z), 0.08, P[FLOWER_COLS[(k + j) % 8]], P["butter"], detail=0)
    for sx in (-1, 1):
        L.rbox(mb, 0.9, width + 0.6, 0.5, P["stone_pale"], T(sx * (span / 2 + 0.2), 0, -0.3), seg=6, rings=4)
    for k in range(8):
        t = (k + 0.5) / 8
        x = -span / 2 + span * t
        z = rise * math.sin(math.pi * t)
        slope = math.degrees(math.atan(rise * math.pi / span * math.cos(math.pi * t)))
        colbox(out, span / 8, width, 0.15, T(x, 0, z - 0.03, ry=-slope))


def fae_lantern_post(mb, rng, out):
    L.lathe(mb, [(0.25, 0.0), (0.22, 0.15), (0.1, 0.3), (0.07, 0.5), (0.06, 2.9), (0.09, 3.0)], 10, P["rosegold"], cap_top=True)
    for z in (0.5, 1.6, 2.9):
        L.torus(mb, 0.08, 0.025, P["gold"], T(0, 0, z), 10, 3)
    curl = [(0.0, 0, 2.95)] + [(0.1 + 0.55 * k / 8, 0, 3.0 + 0.25 * math.sin(math.pi * k / 8)) for k in range(9)]
    L.tube(mb, curl, 0.03, P["rosegold"], seg=4)
    spiral = [(0.08 + 0.12 * math.cos(TAU * k / 10), 0, 2.75 + 0.12 * math.sin(TAU * k / 10)) for k in range(9)]
    L.tube(mb, spiral, 0.02, P["gold"], seg=3)
    lx, lz = 0.65, 2.45
    L.tube(mb, [(lx, 0, 3.0), (lx, 0, lz + 0.62)], 0.012, P["gold"], seg=3)
    L.cyl(mb, 0.14, 0.17, 0.08, 8, P["gold"], T(lx, 0, lz))
    L.cyl(mb, 0.12, 0.12, 0.42, 8, P["lantern"], T(lx, 0, lz + 0.08))
    for i in range(4):
        a = TAU * i / 4 + 0.78
        L.cyl(mb, 0.015, 0.015, 0.42, 3, P["gold"], T(lx + 0.15 * math.cos(a), 0.15 * math.sin(a), lz + 0.08))
    L.cone(mb, 0.2, 0.18, 8, P["gold"], T(lx, 0, lz + 0.5))
    L.ball(mb, (lx, 0, lz + 0.7), 0.04, P["gold"], 5, 3)
    L.ball(mb, (0, 0, 3.08), 0.08, P["gold"], 6, 4)
    for i in range(4):
        a = TAU * i / 4
        L.bloom(mb, (0.35 * math.cos(a), 0.35 * math.sin(a), 0.02), 0.1, P[FLOWER_COLS[i]], P["butter"], detail=0)
    hanging_ribbon(mb, (0.08, 0, 2.7), 0.6, P["rose"], (0.1, -0.1), 0.06)
    colcyl(out, 0.12, 3.0, seg=6)


def fae_bunting(mb, rng, out, length=8.0, sag=0.7, n=16):
    rope = L.catenary((-length / 2, 0, 0), (length / 2, 0, 0), sag, 16)
    L.tube(mb, rope, 0.012, P["cream"], seg=3)
    cols = ["rose", "butter", "mint", "lilac", "peri", "blush", "coral"]
    for i in range(n):
        t0 = (i + 0.1) / n
        t1 = (i + 0.9) / n
        def at(t):
            x = -length / 2 + length * t
            return Vector((x, 0, -sag * 4 * t * (1 - t)))
        a, b = at(t0), at(t1)
        tip = (a + b) / 2 + Vector((0, 0, -0.38))
        L.tri_flag(mb, a, b, tip, P[cols[i % len(cols)]])
        L.ball(mb, tuple(a), 0.018, P["gold"], 4, 2)


def fae_mill(mb, rng, out):
    L.lathe(mb, [(3.2, 0.0), (3.2, 0.5)], 18, P["stone_pale"], cap_top=True)
    L.lathe(mb, [(2.9, 0.5), (2.95, 2.4)], 18, P["pearl"], cap_bot=False, cap_top=False)
    L.lathe(mb, [(2.95, 2.4), (2.8, 6.0)], 18, P["butter"], cap_bot=False, cap_top=False)
    for z in (0.5, 2.4, 6.0):
        L.torus(mb, 2.95 if z < 3 else 2.82, 0.08, P["rosegold"], T(0, 0, z), 18, 4)
    L.lathe(mb, [(3.5, 6.0), (2.8, 6.8), (1.4, 8.6), (0.0, 9.6)], 18, P["lilac"], cap_bot=True, col_cap=P["blush"])
    for i in range(16):
        a = TAU * i / 16
        L.sphere(mb, 0.5, 0.25, 0.2, P["lilac"] if i % 2 else P["peri"], T(3.45 * math.cos(a), 3.45 * math.sin(a), 6.0, rz=math.degrees(a) + 90, rx=-30), 5, 3)
    L.ball(mb, (0, 0, 9.7), 0.15, P["gold"], 6, 4)
    _round_door(mb, 2.95, col="rose")
    for ang, z in ((-30, 3.3), (-150, 3.6), (150, 4.8), (-60, 5.0)):
        _round_window(mb, rng, 2.92, ang, z, 0.38, box=(z < 4))
    # waterwheel on +X
    wx = 3.6
    xf = T(wx, 0, 2.6, ry=90)
    L.torus(mb, 2.3, 0.08, P["wood"], xf @ T(0, 0, -0.45), 20, 4)
    L.torus(mb, 2.3, 0.08, P["wood"], xf @ T(0, 0, 0.45), 20, 4)
    L.cyl(mb, 0.25, 0.25, 1.4, 10, P["wood_dk"], xf @ T(0, 0, -0.7))
    L.torus(mb, 0.3, 0.06, P["gold"], xf @ T(0, 0, 0.72), 10, 3)
    for i in range(8):
        a = TAU * i / 8
        for zz in (-0.45, 0.45):
            L.tube(mb, [(0.2 * math.cos(a), 0.2 * math.sin(a), zz), (2.3 * math.cos(a), 2.3 * math.sin(a), zz)], 0.045, P["wood_pale"], seg=4, xf=xf)
    for i in range(14):
        a = TAU * i / 14
        L.box(mb, 0.5, 1.0, 0.07, P["mint"] if i % 2 else P["wood_pale"],
              xf @ T(2.2 * math.cos(a), 2.2 * math.sin(a), 0, rz=math.degrees(a), rx=90) @ T(0, 0, -0.035), base=True)
    # race / trough and water spill
    L.rbox(mb, 1.4, 4.6, 0.5, P["wood"], T(wx, 1.4, 4.6), seg=6, rings=3, e=0.2)
    L.box(mb, 1.0, 4.4, 0.05, P["water"], T(wx, 1.4, 5.02))
    L.strip(mb, [(wx, -0.9, 4.9), (wx, -1.4, 4.2), (wx, -1.7, 3.2)], Vector((1, 0, 0)), 0.9, P["sky"])
    for sx in (-0.55, 0.55):
        L.cyl(mb, 0.09, 0.09, 4.6, 6, P["wood_dk"], T(wx + sx, 3.3, 0))
    colcyl(out, 3.0, 6.0, seg=12)
    colcyl(out, 2.5, 2.5, T(0, 0, 6.0), seg=8)
    colbox(out, 1.2, 4.8, 4.8, T(wx, 0.3, 0.3))


def fae_bench(mb, rng, out):
    for i in range(3):
        L.rbox(mb, 1.8, 0.16, 0.06, P["white"], T(0, -0.18 + i * 0.18, 0.45), seg=6, rings=3, e=0.3)
    for i in range(3):
        L.rbox(mb, 1.8, 0.05, 0.13, P["mint"], T(0, 0.3 + 0.03 * i, 0.6 + i * 0.18, rx=-12), seg=6, rings=3, e=0.3)
    for sx in (-0.8, 0.8):
        curl = [(sx, -0.25 + 0.03 * k, 0.45 - 0.45 * math.sin(math.pi * k / 16)) for k in range(9)]
        L.tube(mb, [(sx, -0.25, 0.0), (sx, -0.22, 0.45)], 0.035, P["gold"], seg=5)
        L.tube(mb, [(sx, 0.25, 0.0), (sx, 0.3, 1.1)], 0.035, P["gold"], seg=5)
        L.tube(mb, [(sx, -0.28, 0.6), (sx, -0.2, 0.68), (sx, 0.1, 0.65), (sx, 0.3, 0.66)], 0.03, P["gold"], seg=4)
        L.torus(mb, 0.1, 0.02, P["gold"], T(sx, -0.25, 0.12, ry=90), 8, 3)
        L.ball(mb, (sx, 0.3, 1.12), 0.05, P["gold"], 5, 3)
    L.rbox(mb, 0.45, 0.4, 0.12, P["rose"], T(0.45, -0.02, 0.5), seg=6, rings=4, e=0.5)
    colbox(out, 1.8, 0.6, 0.55)


def fae_flower_cart(mb, rng, out):
    L.rbox(mb, 1.8, 1.1, 0.6, P["mint"], T(0, 0, 0.55), seg=8, rings=5, e=0.25)
    L.torus(mb, 0.9, 0.03, P["gold"], T(0, 0, 1.12, s=(1, 0.62, 1)), 18, 3)
    for sx in (-1, 1):
        xf = T(0.2, sx * 0.62, 0.55, rx=90)
        L.torus(mb, 0.5, 0.05, P["wood_pale"], xf, 16, 4)
        L.cyl(mb, 0.08, 0.08, 0.1, 8, P["gold"], xf @ T(0, 0, -0.05))
        for i in range(6):
            a = TAU * i / 6
            L.tube(mb, [(0, 0, 0), (0.5 * math.cos(a), 0.5 * math.sin(a), 0)], 0.022, P["wood_pale"], seg=3, xf=xf, caps=False)
    L.tube(mb, [(-0.9, -0.4, 0.95), (-1.8, -0.4, 0.8)], 0.035, P["wood"], seg=5)
    L.tube(mb, [(-0.9, 0.4, 0.95), (-1.8, 0.4, 0.8)], 0.035, P["wood"], seg=5)
    L.cyl(mb, 0.04, 0.04, 0.55, 5, P["wood"], T(0.75, 0, 0))
    for i in range(22):
        x = rng.uniform(-0.75, 0.75)
        y = rng.uniform(-0.42, 0.42)
        z = 1.15 + 0.25 * (1 - (x / 0.8) ** 2) * (1 - (y / 0.45) ** 2) + rng.uniform(0, 0.08)
        L.bloom(mb, (x, y, z), rng.uniform(0.09, 0.13), P[FLOWER_COLS[i % 8]], P["butter"], detail=0)
    for i in range(5):
        L.bloom(mb, (-0.6 + i * 0.3, -0.57, 0.95), 0.12, P[FLOWER_COLS[(i * 3) % 8]], P["butter"], detail=1, tilt=80)
    for k, x in enumerate((1.15, 1.45)):
        L.lathe(mb, [(0.13, 0.0), (0.16, 0.35)], 8, P[["peri", "rose"][k]], T(x, 0.2 * k, 0), cap_bot=True, cap_top=False)
        for j in range(4):
            L.bloom(mb, (x + 0.06 * math.cos(j * 1.6), 0.2 * k + 0.06 * math.sin(j * 1.6), 0.42 + 0.05 * j), 0.08, P[FLOWER_COLS[(j + k * 2) % 8]], P["butter"], detail=0)
    colbox(out, 2.0, 1.3, 1.2)


# ------------------------------------------------------------------ solstice

def solstice_flower_arch(mb, rng, out, h=3.5, w=2.6):
    R = w / 2
    legs = h - R
    for sx in (-1, 1):
        L.cyl(mb, 0.08, 0.08, legs, 7, P["white"], T(sx * R, 0, 0))
    L.torus(mb, R, 0.08, P["white"], T(0, 0, legs, rx=90), 16, 5, arc=0.5)
    L.torus(mb, R - 0.12, 0.025, P["gold"], T(0, -0.09, legs, rx=90), 16, 3, arc=0.5)
    n = 30
    for i in range(n):
        t = i / (n - 1)
        u = t * (2 * legs + math.pi * R)
        if u < legs:
            p = (-R, 0, u)
        elif u > legs + math.pi * R:
            p = (R, 0, 2 * legs + math.pi * R - u)
        else:
            a = math.pi - (u - legs) / R
            p = (R * math.cos(a), 0, legs + R * math.sin(a))
        jx = rng.uniform(-0.08, 0.08)
        L.sphere(mb, 0.2, 0.2, 0.14, P["leaf"] if i % 2 else P["moss"], T(p[0] + jx, rng.uniform(-0.12, 0.12), p[2], rz=rng.uniform(0, 180)), 5, 3)
        L.bloom(mb, (p[0] + jx, -0.14 + rng.uniform(-0.05, 0.05), p[2]), rng.uniform(0.12, 0.18), P[FLOWER_COLS[i % 8]], P["butter"],
                detail=1 if i % 3 == 0 else 0, tilt=90)
    for sx in (-1, 1):
        hanging_ribbon(mb, (sx * 0.6, -0.1, legs + R * 0.8), 1.1, P["rose" if sx < 0 else "lilac"], (0, -0.1), 0.07)
        L.rbox(mb, 0.4, 0.4, 0.15, P["stone_pale"], T(sx * R, 0, 0), seg=6, rings=3)
    colcyl(out, 0.12, legs, T(-R, 0, 0), seg=6)
    colcyl(out, 0.12, legs, T(R, 0, 0), seg=6)


def solstice_musicians_bower(mb, rng, out):
    r = 2.6
    L.lathe(mb, [(r + 0.2, 0.0), (r + 0.2, 0.35)], 16, P["wood_pale"], cap_top=True, col_cap=P["blush"], arc=0.5, phase=0.0)
    for i in range(5):
        a = math.pi * i / 4
        x, y = r * math.cos(a), r * math.sin(a)
        L.cyl(mb, 0.07, 0.07, 3.0, 7, P["white"], T(x, y, 0.35))
        top = Vector((x, y, 3.35))
        L.tube(mb, [top, top * 0.6 + Vector((0, 0, 1.1)), Vector((0, 0.3, 4.2))], 0.05, P["white"], seg=5)
        for k in range(4):
            z = 0.6 + k * 0.7
            L.bloom(mb, (x * 1.03, y * 1.03, z), 0.13, P[FLOWER_COLS[(i + k) % 8]], P["butter"], detail=0)
            L.sphere(mb, 0.14, 0.12, 0.1, P["leaf"], T(x, y, z + 0.25), 5, 3)
    rim = [(r * math.cos(math.pi * k / 12), r * math.sin(math.pi * k / 12), 3.35) for k in range(13)]
    L.tube(mb, rim, 0.05, P["gold"], seg=4)
    for k in range(12):
        a, b = rim[k], rim[k + 1]
        g = L.catenary(a, b, 0.25, 3)
        for j, p in enumerate(g[1:-1]):
            L.bloom(mb, (p.x, p.y, p.z), 0.12, P[FLOWER_COLS[(k + j) % 8]], P["butter"], detail=0)
    for k in range(6):
        a = math.pi * (k + 0.5) / 6
        hanging_ribbon(mb, (r * 0.9 * math.cos(a), r * 0.9 * math.sin(a), 3.3), 1.3, P[["rose", "lilac", "butter", "peri", "mint", "blush"][k]], (0, -0.1), 0.08)
    # instruments: a harp, two stools and a lute leaning
    L.tube(mb, [(-0.8, 1.2, 0.35), (-0.8, 1.2, 1.6), (-0.3, 1.2, 1.9), (-0.2, 1.2, 1.2), (-0.8, 1.2, 0.5)], 0.04, P["gold"], seg=5)
    for k in range(6):
        L.tube(mb, [(-0.7 + k * 0.08, 1.2, 0.5 + k * 0.05), (-0.7 + k * 0.08, 1.2, 1.6 + k * 0.03)], 0.006, P["cream"], seg=3, caps=False)
    for x in (0.4, 1.3):
        L.cyl(mb, 0.25, 0.25, 0.08, 10, P["rose"], T(x, 1.0, 0.8))
        for k in range(3):
            a = TAU * k / 3
            L.cyl(mb, 0.03, 0.03, 0.45, 4, P["wood_pale"], T(x + 0.15 * math.cos(a), 1.0 + 0.15 * math.sin(a), 0.35))
    L.sphere(mb, 0.3, 0.1, 0.36, P["wood"], T(1.9, 1.3, 0.75, ry=-20), 8, 5)
    L.tube(mb, [(1.9, 1.25, 1.0), (1.75, 1.25, 1.65)], 0.035, P["wood_dk"], seg=4)
    colbox(out, 2 * r + 0.4, r + 0.2, 0.35, T(0, (r + 0.2) / 2, 0))


def solstice_dance_ring_stone(mb, rng, out):
    L.rock(mb, 1.2, 0.9, 0.35, P["pearl"], rng, seg=10, rings=5, jit=0.05, e=0.4)
    L.spiral_beads(mb, 0.02, 0.32, 2.2, 22, 0.03, P["gold"], T(0, 0, 0.33, rx=90))
    for i in range(8):
        a = TAU * i / 8
        L.sphere(mb, 0.03, 0.08, 0.02, P["gold"], T(0.43 * math.cos(a), 0.43 * math.sin(a), 0.32, rz=math.degrees(a) + 90), 4, 2)
    for i in range(4):
        a = TAU * i / 4 + 0.6
        L.bloom(mb, (0.62 * math.cos(a), 0.5 * math.sin(a), 0.02), 0.07, P[FLOWER_COLS[i * 2]], P["butter"], detail=0)
    colbox(out, 1.1, 0.85, 0.35)


def solstice_maypole(mb, rng, out, h=7.0):
    L.cyl(mb, 0.12, 0.09, h, 10, P["white"])
    for k in range(9):
        L.torus(mb, 0.11 - 0.003 * k, 0.02, P["gold"], T(0, 0, 0.6 + k * 0.7, rx=12), 10, 3)
    L.torus(mb, 0.45, 0.08, P["leaf"], T(0, 0, h - 0.15), 14, 4)
    for i in range(12):
        a = TAU * i / 12
        L.bloom(mb, (0.45 * math.cos(a), 0.45 * math.sin(a), h - 0.05), 0.13, P[FLOWER_COLS[i % 8]], P["butter"], detail=1 if i % 2 else 0)
    L.ball(mb, (0, 0, h + 0.15), 0.18, P["gold"], 8, 5)
    L.cone(mb, 0.08, 0.35, 6, P["gold"], T(0, 0, h + 0.28))
    cols = ["rose", "lilac", "butter", "mint", "peri", "blush", "coral", "gold", "white", "berry"]
    for i, c in enumerate(cols):
        a = TAU * i / len(cols)
        top = Vector((0.12 * math.cos(a), 0.12 * math.sin(a), h - 0.35))
        bot = Vector((3.0 * math.cos(a), 3.0 * math.sin(a), 0.05))
        pts = [top.lerp(bot, t) + Vector((0, 0, -0.6 * math.sin(math.pi * t))) for t in (0, 0.2, 0.4, 0.6, 0.8, 1.0)]
        L.strip(mb, pts, Vector((-math.sin(a), math.cos(a), 0)), 0.1, P[c])
        L.rbox(mb, 0.2, 0.2, 0.1, P["stone_pale"], T(*bot), seg=5, rings=3)
    for i in range(8):
        a = TAU * i / 8
        L.bloom(mb, (0.4 * math.cos(a), 0.4 * math.sin(a), 0.03), 0.1, P[FLOWER_COLS[i]], P["butter"], detail=0)
    colcyl(out, 0.15, h, seg=6)


def solstice_long_table(mb, rng, out, length=6.0):
    L.rbox(mb, length, 1.2, 0.08, P["wood_pale"], T(0, 0, 0.78), seg=8, rings=3, e=0.2)
    L.rbox(mb, length + 0.1, 1.3, 0.3, P["cream"], T(0, 0, 0.56), seg=10, rings=4, e=0.15)
    L.box(mb, length, 0.4, 0.012, P["gold"], T(0, 0, 0.865))
    for sx in (-1, 1):
        for k in range(3):
            x = sx * (length / 2 - 0.3) if k != 1 else 0
            if k == 1 and sx > 0:
                continue
            L.cyl(mb, 0.06, 0.06, 0.6, 6, P["wood"], T(x, 0.45, 0))
            L.cyl(mb, 0.06, 0.06, 0.6, 6, P["wood"], T(x, -0.45, 0))
    for i in range(8):
        x = -length / 2 + 0.4 + i * (length - 0.8) / 7
        for sy in (-1, 1):
            L.lathe(mb, [(0.0, 0.0), (0.06, 0.003), (0.11, 0.015)], 8, P["pearl"], T(x, sy * 0.38, 0.865), cap_top=False)
            L.lathe(mb, [(0.11, 0.015), (0.135, 0.022)], 8, P["gold"], T(x, sy * 0.38, 0.865), cap_bot=False, cap_top=False)
            if i % 2 == 0:
                L.lathe(mb, [(0.03, 0.0), (0.008, 0.06), (0.008, 0.12), (0.05, 0.2)], 6, P["gold"], T(x + 0.18, sy * 0.25, 0.86), cap_top=False)
    for k in range(5):
        x = -length / 2 + 0.6 + k * (length - 1.2) / 4
        if k % 2 == 0:
            L.lathe(mb, [(0.08, 0.0), (0.16, 0.08), (0.18, 0.12)], 10, P["rosegold"], T(x, 0, 0.86), cap_top=False)
            for j in range(6):
                a = TAU * j / 6
                L.bloom(mb, (x + 0.12 * math.cos(a), 0.12 * math.sin(a), 1.0), 0.09, P[FLOWER_COLS[(j + k) % 8]], P["butter"], detail=0)
            L.bloom(mb, (x, 0, 1.06), 0.11, P["rose"], P["butter"], detail=1)
        else:
            for j in range(3):
                hh = 0.18 + 0.08 * j
                L.cyl(mb, 0.03, 0.03, hh, 6, P["cream"], T(x - 0.1 + j * 0.1, 0.05 * (j - 1), 0.87))
                L.sphere(mb, 0.02, 0.02, 0.045, P["flame"], T(x - 0.1 + j * 0.1, 0.05 * (j - 1), 0.87 + hh + 0.03), 4, 3)
    for i in range(4):
        L.sphere(mb, 0.13, 0.13, 0.12, P[["red", "butter", "plum", "coral"][i]], T(-length / 2 + 1.0 + i * 1.3, 0.1, 0.88), 6, 4)
    colbox(out, length, 1.3, 0.86)


def solstice_lantern_string(mb, rng, out, length=10.0, sag=0.9):
    rope = L.catenary((-length / 2, 0, 0), (length / 2, 0, 0), sag, 16)
    L.tube(mb, rope, 0.012, P["gold"], seg=3)
    cols = ["glow_rose", "lantern", "glow_lilac", "glow_teal", "glow_gold"]
    n = 11
    for i in range(n):
        t = (i + 0.5) / n
        x = -length / 2 + length * t
        z = -sag * 4 * t * (1 - t)
        L.tube(mb, [(x, 0, z), (x, 0, z - 0.12)], 0.006, P["gold"], seg=3, caps=False)
        L.lathe(mb, [(0.0, -0.45), (0.12, -0.41), (0.17, -0.3), (0.12, -0.17), (0.0, -0.13)], 8, P[cols[i % 5]], T(x, 0, z))
        L.cyl(mb, 0.06, 0.06, 0.03, 6, P["gold"], T(x, 0, z - 0.15))
        L.ball(mb, (x, 0, z - 0.47), 0.02, P["gold"], 4, 2)


# ------------------------------------------------------------------ Old Shrines (pre-Treaty ruins)

def _column_body(mb, rng, h, broken=False):
    L.rbox(mb, 1.2, 1.2, 0.35, P["stone_pale"], seg=8, rings=4, e=0.25)
    L.lathe(mb, [(0.5, 0.35), (0.48, 0.45)], 16, P["pearl"], cap_bot=False, cap_top=False)
    top = h - (0.7 if not broken else 0.0)
    if broken:
        prof = [(0.42, 0.45), (0.4, top * 0.6)]
        L.lathe(mb, prof, 16, P["pearl_lilac"], cap_bot=False, cap_top=False)
        for i in range(16):
            a = TAU * (i + 0.5) / 16
            hh = rng.uniform(0.05, 0.8)
            L.box(mb, 0.18, 0.18, hh, P["pearl_lilac"], T(0.36 * math.cos(a), 0.36 * math.sin(a), top * 0.6 - 0.05, rz=math.degrees(a)))
        L.disc(mb, 0.38, 16, P["moss"], T(0, 0, top * 0.6 + 0.1))
    else:
        L.lathe(mb, [(0.42, 0.45), (0.4, top * 0.5), (0.36, top)], 16, P["pearl_lilac"], cap_bot=False, cap_top=False)
        L.lathe(mb, [(0.38, top), (0.55, top + 0.35), (0.6, top + 0.4)], 16, P["pearl"], cap_bot=False, cap_top=True)
        L.rbox(mb, 1.3, 1.3, 0.3, P["stone_pale"], T(0, 0, top + 0.4), seg=8, rings=4, e=0.25)
        for i in range(4):
            a = TAU * i / 4 + math.pi / 4
            L.spiral_beads(mb, 0.01, 0.12, 1.8, 10, 0.025, P["gold"], T(0.5 * math.cos(a), 0.5 * math.sin(a), top + 0.25, rz=math.degrees(a) + 90))
    for k in range(16):
        a = TAU * k / 16
        zz = top * (0.55 if broken else 0.95)
        L.tube(mb, [(0.41 * math.cos(a), 0.41 * math.sin(a), 0.5), (0.37 * math.cos(a), 0.37 * math.sin(a), zz)], 0.025, P["pearl"], seg=3, caps=False)
    ivy_on_cyl(mb, rng, 0.43, -150, 30, 0.4, top * (0.6 if broken else 0.75), 18, size=0.22, flowers=0.4)


def shrine_column(mb, rng, out):
    _column_body(mb, rng, 4.6)
    colbox(out, 1.0, 1.0, 4.6)


def shrine_column_broken(mb, rng, out):
    _column_body(mb, rng, 3.6, broken=True)
    L.cyl(mb, 0.4, 0.4, 0.9, 14, P["pearl_lilac"], T(1.2, 0.6, 0.4, ry=90, rz=25), col_cap=P["stone_pale"])
    L.rock(mb, 0.5, 0.4, 0.3, P["pearl"], rng, T(-1.0, -0.6, 0), seg=6, rings=4)
    L.sphere(mb, 0.5, 0.3, 0.1, P["moss"], T(1.0, 0.5, 0.82), 6, 3)
    colbox(out, 1.0, 1.0, 2.4)


def shrine_wall_mural(mb, rng, out, w=4.0, h=3.0):
    L.rbox(mb, w, 0.6, h, P["pearl"], seg=10, rings=8, e=0.18, rng=rng, jit=0.015)
    L.rbox(mb, w * 0.75, 0.1, h * 0.65, P["pearl_lilac"], T(0, -0.28, h * 0.15), seg=8, rings=6, e=0.15)
    L.torus(mb, 1.0, 0.04, P["gold"], T(0, -0.33, h * 0.48, rx=90, s=(1.35, 1, 1)), 24, 4)
    # relief: a sun disc, waves, two figures dancing, spirals
    L.sphere(mb, 0.35, 0.08, 0.35, P["gold"], T(0, -0.36, h * 0.66), 10, 5)
    for i in range(10):
        a = TAU * i / 10
        L.sphere(mb, 0.04, 0.03, 0.14, P["gold"], T(0.5 * math.cos(a), -0.36, h * 0.66 + 0.5 * math.sin(a), ry=-math.degrees(a) + 90), 4, 2)
    for row in range(2):
        pts = [(-1.3 + k * 0.13, -0.36, h * 0.3 + row * 0.16 + 0.05 * math.sin(k * 1.1)) for k in range(21)]
        L.tube(mb, pts, 0.03, P["peri"], seg=4)
    for sx in (-1, 1):
        x = sx * 0.95
        L.sphere(mb, 0.08, 0.04, 0.08, P["rose"], T(x, -0.36, h * 0.72), 6, 3)
        L.lathe(mb, [(0.03, 0.0), (0.18, 0.05), (0.06, 0.45), (0.0, 0.5)], 6, P["rose"], T(x, -0.36, h * 0.48, s=(1, 0.3, 1)))
        L.tube(mb, [(x - sx * 0.2, -0.36, h * 0.66), (x, -0.36, h * 0.62), (x + sx * 0.25, -0.36, h * 0.72)], 0.02, P["rose"], seg=3)
        L.spiral_beads(mb, 0.02, 0.18, 2.0, 14, 0.03, P["gold"], T(sx * 1.55, -0.32, h * 0.22))
    for _ in range(6):
        L.rock(mb, 0.3, 0.2, 0.2, P["stone_pale"], rng, T(rng.uniform(-w / 2, w / 2), rng.uniform(-0.9, -0.5), 0), seg=5, rings=3)
    ivy(mb, rng, [((rng.uniform(-w / 2, w / 2), rng.uniform(-0.2, 0.2), h + 0.02), rng.uniform(0, 360)) for _ in range(12)], 0.28, flowers=0.5)
    ivy(mb, rng, [((w / 2 - rng.uniform(0, 0.3), -0.32, rng.uniform(0.3, h)), -90) for _ in range(10)], 0.22, flowers=0.3)
    flecks(mb, rng, 12, w, 0.6, 0.2, h, P["gold"], 0.03)
    colbox(out, w, 0.6, h)


def shrine_altar(mb, rng, out):
    L.rbox(mb, 1.8, 1.0, 0.25, P["stone_pale"], seg=8, rings=4, e=0.25)
    L.rbox(mb, 1.5, 0.8, 0.85, P["pearl"], T(0, 0, 0.2), seg=8, rings=6, e=0.25)
    L.rbox(mb, 1.8, 1.05, 0.18, P["pearl_lilac"], T(0, 0, 1.0), seg=8, rings=4, e=0.25)
    L.spiral_beads(mb, 0.02, 0.22, 2.2, 18, 0.035, P["gold"], T(0, -0.42, 0.62))
    for sx in (-0.55, 0.55):
        L.torus(mb, 0.16, 0.025, P["gold"], T(sx, -0.42, 0.62, rx=90), 10, 3)
    L.lathe(mb, [(0.0, 0.0), (0.15, 0.02), (0.28, 0.12), (0.3, 0.15)], 12, P["gold"], T(0, 0, 1.18), cap_top=False)
    L.disc(mb, 0.26, 12, P["water"], T(0, 0, 1.3))
    for i in range(5):
        L.bloom(mb, (-0.6 + i * 0.12, 0.25 - 0.05 * (i % 2), 1.18), 0.08, P[FLOWER_COLS[i]], P["butter"], detail=0)
    L.ball(mb, (0.6, 0.2, 1.24), 0.06, P["butter"], 6, 4)
    L.ball(mb, (0.5, 0.3, 1.22), 0.05, P["red"], 6, 4)
    ivy(mb, rng, [((rng.uniform(-0.8, 0.8), 0.5, rng.uniform(0.2, 1.0)), 90) for _ in range(8)], 0.2, flowers=0.5)
    colbox(out, 1.8, 1.05, 1.2)


def shrine_arch(mb, rng, out, w=3.2, h=4.4):
    for sx in (-1, 1):
        L.rbox(mb, 0.8, 0.8, 0.3, P["stone_pale"], T(sx * w / 2, 0, 0), seg=6, rings=4, e=0.25)
        L.lathe(mb, [(0.3, 0.3), (0.28, h - 1.6)], 14, P["pearl_lilac"], T(sx * w / 2, 0, 0), cap_bot=False, cap_top=False)
        L.lathe(mb, [(0.3, h - 1.6), (0.45, h - 1.35)], 14, P["pearl"], T(sx * w / 2, 0, 0), cap_bot=False, cap_top=True)
    L.torus(mb, w / 2, 0.3, P["pearl"], T(0, 0, h - 1.35, rx=90), 16, 6, arc=0.5)
    L.rbox(mb, 0.45, 0.65, 0.55, P["gold"], T(0, 0, h - 1.35 + w / 2 - 0.05), seg=6, rings=4, e=0.4)
    for k in range(12):
        a = math.pi * (k + 0.5) / 12
        L.sphere(mb, 0.035, 0.035, 0.035, P["gold"], T(w / 2 * math.cos(a), -0.3, h - 1.35 + w / 2 * math.sin(a)), 4, 2)
    ivy(mb, rng, [((-w / 2 + rng.uniform(-0.3, 0.3), -0.25, rng.uniform(0.3, h - 1.0)), -90) for _ in range(14)], 0.24, flowers=0.4)
    ivy(mb, rng, [((w / 2 * math.cos(a), 0.0, h - 1.35 + (w / 2 + 0.25) * math.sin(a)), 0) for a in [rng.uniform(0.2, 1.4) for _ in range(10)]], 0.24, flowers=0.4)
    for sx in (-1, 1):
        colbox(out, 0.7, 0.7, h - 1.3, T(sx * w / 2, 0, 0))
    colbox(out, w + 0.8, 0.6, 0.8, T(0, 0, h - 1.35 + w / 2 - 0.5))


def shrine_steps(mb, rng, out, w=4.0, n=4):
    for k in range(n):
        d = 0.5 * (n - k)
        L.rbox(mb, w - 0.25 * k, d, 0.22, P["pearl"] if k % 2 else P["stone_pale"], T(0, d / 2 - 0.25 * n, 0.2 * k), seg=8, rings=4, e=0.2, rng=rng, jit=0.02)
        colbox(out, w - 0.25 * k, d, 0.22, T(0, d / 2 - 0.25 * n, 0.2 * k))
    for i in range(4):
        L.rock(mb, 0.4, 0.3, 0.25, P["pearl_lilac"], rng, T(rng.choice((-1, 1)) * (w / 2 + 0.2), rng.uniform(-0.9, 0.4), 0), seg=5, rings=3)
    for i in range(n):
        L.sphere(mb, 0.35, 0.18, 0.08, P["moss"], T(rng.uniform(-w / 2, w / 2) * 0.9, 0.5 * (n - i) - 0.25 * n - 0.05, 0.2 * i + 0.2), 6, 3)
        L.bloom(mb, (-w / 2 + 0.2 + 0.2 * i, -0.25 * n + 0.5 * (n - i) - 0.1, 0.2 * i + 0.2), 0.08, P[FLOWER_COLS[i]], P["butter"], detail=0)


# ------------------------------------------------------------------ autumn border

def autumn_pass_gate(mb, rng, out, w=7.0, h=8.0):
    st, dk = P["au_stone"], P["au_stone_dk"]
    for sx in (-1, 1):
        L.rbox(mb, 1.8, 1.8, 0.6, dk, T(sx * w / 2, 0, 0), seg=6, rings=4, e=0.3)
        L.rbox(mb, 1.4, 1.4, h - 1.6, st, T(sx * w / 2, 0, 0.5), seg=8, rings=6, e=0.25)
        for k in range(5):
            L.sphere(mb, 0.28, 0.08, 0.18, P[["crimson", "amber", "au_gold"][k % 3]], T(sx * w / 2, -0.72, 1.2 + k * 1.1, ry=sx * 30 * (k % 2)), 6, 3)
    L.rbox(mb, w + 2.4, 1.8, 1.4, st, T(0, 0, h - 1.3), seg=10, rings=5, e=0.25)
    L.rbox(mb, w * 0.5, 1.5, 0.9, dk, T(0, 0, h + 0.05), seg=8, rings=4, e=0.3)
    for k in range(9):
        x = -w / 2 + w * (k + 0.5) / 9
        L.sphere(mb, 0.3, 0.08, 0.2, P[["crimson", "amber", "au_gold"][k % 3]], T(x, -0.92, h - 0.6, ry=40 * (k % 2) - 20), 6, 3)
    # ward runes glowing on lintel & pillars
    for k in range(5):
        x = -1.6 + k * 0.8
        L.torus(mb, 0.18, 0.035, P["ward"], T(x, -0.93, h - 0.25, rx=90), 8, 3)
    for sx in (-1, 1):
        for k in range(3):
            L.box(mb, 0.08, 0.05, 0.4, P["ward"], T(sx * w / 2, -0.72, 2.2 + k * 1.6, ry=30))
            L.box(mb, 0.08, 0.05, 0.4, P["ward"], T(sx * w / 2, -0.72, 2.2 + k * 1.6, ry=-30))
    # wall of living thorn filling the opening
    inner = w - 1.4
    for i in range(26):
        x0 = rng.uniform(-inner / 2, inner / 2)
        z0 = rng.uniform(0.0, h - 2.0)
        x1 = x0 + rng.uniform(-2.5, 2.5)
        z1 = min(h - 1.3, max(0.0, z0 + rng.uniform(-2.0, 2.5)))
        x1 = max(-inner / 2, min(inner / 2, x1))
        y = rng.uniform(-0.4, 0.4)
        mid = ((x0 + x1) / 2 + rng.uniform(-0.4, 0.4), y + rng.uniform(-0.3, 0.3), (z0 + z1) / 2)
        L.tube(mb, [(x0, y, z0), mid, (x1, y, z1)], rng.uniform(0.08, 0.16), P["thorn"] if i % 3 else P["thorn_dk"], seg=5, r_end=0.04)
        for j in range(3):
            t = 0.2 + 0.3 * j
            px = x0 + (x1 - x0) * t
            pz = z0 + (z1 - z0) * t
            L.cone(mb, 0.05, 0.3, 4, P["thorn_dk"], T(px, y - 0.1, pz, rx=rng.uniform(60, 120), rz=rng.uniform(-60, 60)), cap=False)
    for i in range(10):
        L.sphere(mb, 0.18, 0.06, 0.12, P["crimson"], T(rng.uniform(-inner / 2, inner / 2), -0.45, rng.uniform(0.3, h - 2)), 5, 3)
    # the ward-light veil itself
    for k in range(4):
        z = 0.4 + k * (h - 2.2) / 4
        L.strip(mb, [(-inner / 2, -0.55, z), (0, -0.62, z + 0.25), (inner / 2, -0.55, z)], Vector((0, 0, 1)), 0.06, P["ward"])
    for i in range(14):
        L.ball(mb, (rng.uniform(-inner / 2, inner / 2), -0.6, rng.uniform(0.3, h - 1.6)), 0.06, P["ward"], 4, 2)
    for i in range(10):
        L.sphere(mb, 0.2, 0.15, 0.04, P[["crimson", "amber", "au_gold", "rust"][i % 4]], T(rng.uniform(-w / 2 - 1, w / 2 + 1), rng.uniform(-2.2, -0.9), 0.02, rz=rng.uniform(0, 180)), 5, 2)
    for sx in (-1, 1):
        colbox(out, 1.6, 1.6, h - 1.0, T(sx * w / 2, 0, 0))
    colbox(out, w + 2.4, 1.8, 1.6, T(0, 0, h - 1.3))
    colbox(out, inner, 1.0, h - 1.3, T(0, 0, 0))


def autumn_border_marker(mb, rng, out):
    L.rbox(mb, 0.7, 0.7, 0.3, P["au_stone_dk"], seg=6, rings=4, e=0.3)
    L.rbox(mb, 0.5, 0.4, 1.8, P["au_stone"], T(0, 0, 0.25), seg=8, rings=6, e=0.35)
    L.lathe(mb, [(0.0, 0.0), (0.14, 0.12), (0.0, 0.42)], 6, P["crimson"], T(0, -0.2, 1.1, rx=90, s=(1, 1, 1)))
    L.tube(mb, [(0, -0.21, 1.1), (0, -0.21, 1.55)], 0.012, P["au_gold"], seg=3)
    L.torus(mb, 0.1, 0.02, P["ward"], T(0, -0.21, 1.75, rx=90), 8, 3)
    L.torus(mb, 0.28, 0.035, P["crimson"], T(0, 0, 1.4, s=(1, 0.8, 1)), 12, 3)
    hanging_ribbon(mb, (0.2, -0.15, 1.4), 0.8, P["crimson"], (0.25, -0.2), 0.08)
    hanging_ribbon(mb, (-0.2, -0.15, 1.4), 0.7, P["amber"], (-0.2, -0.2), 0.07)
    for i in range(8):
        a = TAU * i / 8
        L.sphere(mb, 0.15, 0.1, 0.03, P[["crimson", "amber", "au_gold", "rust"][i % 4]], T(0.55 * math.cos(a), 0.55 * math.sin(a), 0.02, rz=math.degrees(a)), 5, 2)
    colbox(out, 0.6, 0.5, 2.0)


def autumn_fallen_log(mb, rng, out):
    pts = [(-2.0, 0, 0.35), (-0.7, 0.1, 0.4), (0.6, -0.05, 0.38), (2.0, 0.05, 0.32)]
    L.tube(mb, pts, 0.38, P["wood_dk"], seg=10, r_end=0.3)
    L.disc(mb, 0.3, 10, P["wood_pale"], T(2.01, 0.05, 0.32, ry=90))
    L.torus(mb, 0.2, 0.012, P["wood"], T(2.02, 0.05, 0.32, ry=90), 10, 3)
    L.tube(mb, [(-0.4, 0.1, 0.6), (-0.2, 0.5, 1.0), (0.0, 0.7, 1.15)], 0.08, P["wood_dk"], seg=5, r_end=0.03)
    for i in range(16):
        x = rng.uniform(-1.9, 1.9)
        a = rng.uniform(-1.3, 1.3)
        L.sphere(mb, 0.14, 0.09, 0.02, P[["crimson", "amber", "au_gold", "rust"][i % 4]], T(x, 0.36 * math.sin(a), 0.35 + 0.36 * math.cos(a), rz=rng.uniform(0, 180)), 5, 2)
    for i in range(5):
        x = -1.2 + i * 0.55
        L.cyl(mb, 0.03, 0.03, 0.12, 5, P["cream"], T(x, -0.32, 0.02))
        L.sphere(mb, 0.09, 0.09, 0.05, P["amber"] if i % 2 else P["crimson"], T(x, -0.32, 0.14), 6, 3)
    for i in range(10):
        L.sphere(mb, 0.18, 0.12, 0.03, P[["crimson", "amber", "au_gold", "rust"][i % 4]], T(rng.uniform(-2.2, 2.2), rng.uniform(-0.9, 0.9), 0.01, rz=rng.uniform(0, 180)), 5, 2)
    colbox(out, 4.0, 0.75, 0.7)


# ------------------------------------------------------------------ blight (dark, broken, frightening)

def blight_dead_stump(mb, rng, out):
    L.lathe(mb, [(0.75, 0.0), (0.55, 0.3), (0.45, 0.9), (0.42, 1.2)], 9, P["bl_dk"], cap_top=True, col_cap=P["bl_black"])
    for i in range(7):
        a = TAU * i / 7 + rng.uniform(-0.2, 0.2)
        hh = rng.uniform(0.3, 1.1)
        L.cone(mb, 0.12, hh, 4, P["bl_black"], T(0.36 * math.cos(a), 0.36 * math.sin(a), 1.1, rx=rng.uniform(-15, 15), ry=rng.uniform(-15, 15)))
    for i in range(5):
        a = TAU * i / 5 + 0.3
        root = [(0.4 * math.cos(a), 0.4 * math.sin(a), 0.3), (1.0 * math.cos(a), 1.0 * math.sin(a), 0.08), (1.5 * math.cos(a + 0.2), 1.5 * math.sin(a + 0.2), -0.02)]
        L.tube(mb, root, 0.14, P["bl_black"], seg=5, r_end=0.03)
    L.tube(mb, [(0.3, 0, 1.0), (0.8, 0.2, 1.6), (1.2, 0.1, 1.7), (1.4, 0.3, 1.5)], 0.08, P["bl_dk"], seg=5, r_end=0.02)
    for i in range(6):
        a = rng.uniform(0, TAU)
        z = rng.uniform(0.3, 0.9)
        L.sphere(mb, 0.14, 0.14, 0.04, P["bl_ash"], T(0.5 * math.cos(a), 0.5 * math.sin(a), z, rz=math.degrees(a)), 5, 2)
    colcyl(out, 0.55, 1.3, seg=6)


def blight_broken_arbor(mb, rng, out):
    L.cyl(mb, 0.08, 0.08, 2.2, 6, P["bl_dk"], T(-1.3, 0, 0, ry=4))
    L.cyl(mb, 0.08, 0.08, 1.3, 6, P["bl_dk"], T(1.3, 0, 0, ry=-6))
    L.cone(mb, 0.08, 0.25, 4, P["bl_black"], T(1.33, 0, 1.3))
    L.torus(mb, 1.3, 0.07, P["bl_dk"], T(-0.02, 0, 2.2, rx=90, ry=12), 12, 4, arc=0.32)
    L.tube(mb, [(1.25, 0, 1.4), (0.8, 0.2, 0.6), (0.6, 0.4, 0.05)], 0.07, P["bl_dk"], seg=5)
    for k in range(3):
        vine = [(-1.3 + rng.uniform(-0.1, 0.1), 0.05, 0.1 + 0.7 * j) for j in range(4)]
        vine = [(v[0] + 0.15 * math.sin(j * 2 + k), v[1] - 0.08 * k, v[2]) for j, v in enumerate(vine)]
        L.tube(mb, vine, 0.03, P["bl_black"], seg=4)
    for i in range(10):
        L.sphere(mb, 0.07, 0.04, 0.07, P["bl_ash"], T(rng.uniform(-1.3, 1.0), rng.uniform(-0.2, 0.2), rng.uniform(0.2, 2.3), rz=rng.uniform(0, 180)), 4, 2)
        L.cone(mb, 0.03, 0.18, 3, P["bl_grey"], T(rng.uniform(-1.3, 1.3), rng.uniform(-0.2, 0.2), rng.uniform(0.0, 0.05), rx=80, rz=rng.uniform(0, 360)), cap=False)
    for i in range(6):
        L.sphere(mb, 0.2, 0.14, 0.03, P["bl_grey"], T(rng.uniform(-1.5, 1.5), rng.uniform(-0.8, 0.8), 0.01), 5, 2)
    colbox(out, 0.2, 0.2, 2.2, T(-1.3, 0, 0))
    colbox(out, 0.2, 0.2, 1.3, T(1.3, 0, 0))


def _mask(mb, xf, col, eye_col, broken=0.0):
    arc = 1.0 - broken
    L.lathe(mb, [(0.0, 0.0), (0.12, 0.03), (0.2, 0.09), (0.24, 0.16)], 8, col, xf @ T(s=(1.0, 1.25, 1.0)), cap_top=False, arc=arc, phase=0.4)
    for sx in (-1, 1):
        L.sphere(mb, 0.045, 0.03, 0.02, eye_col, xf @ T(sx * 0.08, 0.06, 0.07), 5, 2)


def blight_mask_pile(mb, rng, out):
    for i in range(16):
        r = rng.uniform(0, 0.75) * (1 - i / 22)
        a = rng.uniform(0, TAU)
        z = 0.06 + (0.55 - r * 0.6) * (i / 16)
        xf = T(r * math.cos(a), r * math.sin(a), z, rx=rng.uniform(-70, 70) + 180 * (i % 3 == 0), ry=rng.uniform(-60, 60), rz=rng.uniform(0, 360))
        _mask(mb, xf, P[["bl_grey", "bl_ash", "bl_dk"][i % 3]], P["bl_black"], broken=rng.uniform(0.0, 0.45))
    for i in range(10):
        L.sphere(mb, 0.06, 0.04, 0.015, P["bl_ash"], T(rng.uniform(-1.0, 1.0), rng.uniform(-1.0, 1.0), 0.01, rz=rng.uniform(0, 360)), 4, 2)
    for i in range(4):
        L.tube(mb, [(rng.uniform(-0.6, 0.6), rng.uniform(-0.6, 0.6), 0.02), (rng.uniform(-0.9, 0.9), rng.uniform(-0.9, 0.9), 0.0)], 0.01, P["bl_black"], seg=3)
    colcyl(out, 0.7, 0.5, seg=6)


def blight_withered_fence(mb, rng, out, length=3.0):
    for i in range(7):
        x = -length / 2 + length * i / 6
        h = rng.uniform(0.5, 1.2) if i % 3 else rng.uniform(0.2, 0.5)
        L.box(mb, 0.1, 0.06, h, P["bl_dk"] if i % 2 else P["bl_grey"], T(x, 0, 0, rx=rng.uniform(-14, 14), ry=rng.uniform(-10, 10)))
        L.cone(mb, 0.06, 0.15, 3, P["bl_black"], T(x, 0, h - 0.02, ry=rng.uniform(-20, 20)), cap=False)
    L.box(mb, length * 0.6, 0.05, 0.08, P["bl_dk"], T(-length * 0.15, -0.05, 0.75, ry=6), base=False)
    L.box(mb, length * 0.45, 0.05, 0.08, P["bl_grey"], T(length * 0.2, -0.05, 0.25, ry=-18), base=False)
    vine = [(-length / 2 + length * k / 8, -0.06, 0.4 + 0.25 * math.sin(k * 1.7)) for k in range(9)]
    L.tube(mb, vine, 0.025, P["bl_black"], seg=4)
    for i in range(5):
        L.sphere(mb, 0.05, 0.03, 0.05, P["bl_ash"], T(*vine[i * 2]), 4, 2)
    colbox(out, length, 0.2, 1.0)


def blight_bone_rock(mb, rng, out):
    L.rock(mb, 1.9, 1.5, 1.3, P["bl_dk"], rng, seg=9, rings=6, jit=0.25)
    L.rock(mb, 1.0, 0.8, 0.7, P["bl_black"], rng, T(1.0, 0.4, 0, rz=40), seg=7, rings=5, jit=0.25)
    for i in range(6):
        a = rng.uniform(0, TAU)
        p0 = Vector((0.6 * math.cos(a), 0.5 * math.sin(a), rng.uniform(0.3, 1.0)))
        p1 = p0 + Vector((math.cos(a) * 0.5, math.sin(a) * 0.5, rng.uniform(-0.1, 0.4)))
        L.tube(mb, [p0, p1], 0.05, P["bl_bone"], seg=5)
        L.ball(mb, tuple(p1), 0.08, P["bl_bone"], 5, 3)
    for k in range(4):
        L.torus(mb, 0.35 - 0.03 * k, 0.025, P["bl_bone"], T(-0.4, -0.7, 0.3 + k * 0.12, rx=70, rz=10 * k), 8, 3, arc=0.55)
    L.sphere(mb, 0.16, 0.14, 0.14, P["bl_bone"], T(-0.75, -0.5, 0.08), 6, 4)
    for sx in (-1, 1):
        L.sphere(mb, 0.04, 0.02, 0.04, P["bl_black"], T(-0.75 + sx * 0.06, -0.63, 0.24), 4, 2)
    colbox(out, 1.8, 1.4, 1.1)


# ------------------------------------------------------------------ generic

def rock_mossy(mb, rng, out, s=1.4, hue="pearl_lilac", flowers=4):
    L.rock(mb, s, s * 0.8, s * 0.7, P[hue], rng, seg=9, rings=6, jit=0.2)
    L.sphere(mb, s * 0.4, s * 0.33, s * 0.12, P["moss"], T(rng.uniform(-0.1, 0.1) * s, 0, s * 0.62), 7, 4)
    L.sphere(mb, s * 0.25, s * 0.2, s * 0.08, P["leaf"], T(s * 0.2, s * 0.15, s * 0.58), 6, 3)
    for i in range(flowers):
        L.bloom(mb, (rng.uniform(-0.3, 0.3) * s, rng.uniform(-0.25, 0.25) * s, s * 0.68), 0.08 * s, P[FLOWER_COLS[(i * 3) % 8]], P["butter"], detail=0)
    flecks(mb, rng, 6, s, s * 0.8, 0.05, s * 0.5, P["gold"], 0.02 * s)
    colbox(out, s * 0.85, s * 0.7, s * 0.65)


def rock_pebble_cluster(mb, rng, out):
    for i in range(10):
        s = rng.uniform(0.12, 0.35)
        L.rock(mb, s, s * 0.8, s * 0.5, P[["pearl", "pearl_lilac", "pearl_rose", "stone_pale", "sky"][i % 5]], rng,
               T(rng.uniform(-0.6, 0.6), rng.uniform(-0.5, 0.5), 0, rz=rng.uniform(0, 360)), seg=6, rings=4, jit=0.12)


def fence_rail(mb, rng, out, length=3.0):
    for x in (-length / 2, 0.0, length / 2):
        L.rbox(mb, 0.14, 0.14, 1.1, P["white"], T(x, 0, 0), seg=6, rings=5, e=0.3)
        L.ball(mb, (x, 0, 1.14), 0.08, P["white"], 6, 4)
    for z in (0.45, 0.85):
        L.rbox(mb, length, 0.06, 0.12, P["white"], T(0, -0.05, z), seg=6, rings=3, e=0.3)
    for i in range(3):
        L.bloom(mb, (-0.9 + i * 0.9, -0.12, 0.88), 0.07, P[FLOWER_COLS[i]], P["butter"], detail=0)
    colbox(out, length, 0.2, 1.1)


def stepping_stones(mb, rng, out):
    for i in range(5):
        t = i / 4
        x = -2.0 + 4.0 * t
        y = 0.6 * math.sin(math.pi * t * 1.4)
        L.rock(mb, 0.65, 0.55, 0.18, P[["pearl", "pearl_rose", "pearl_lilac"][i % 3]], rng, T(x, y, 0, rz=rng.uniform(0, 180)), seg=8, rings=4, jit=0.08, e=0.5)
        L.sphere(mb, 0.15, 0.1, 0.04, P["moss"], T(x + 0.15, y + 0.15, 0.16), 5, 2)
        colbox(out, 0.55, 0.45, 0.18, T(x, y, 0))


def wooden_footbridge_small(mb, rng, out, span=3.0):
    for i in range(10):
        x = -span / 2 + span * (i + 0.5) / 10
        z = 0.25 * math.sin(math.pi * (i + 0.5) / 10)
        L.box(mb, span / 10 * 0.92, 1.1 + 0.05 * (i % 2), 0.08, P["wood_pale"] if i % 2 else P["wood"], T(x, 0, z, rz=rng.uniform(-2, 2)))
    for sy in (-1, 1):
        L.tube(mb, [(-span / 2, sy * 0.5, 0.05), (span / 2, sy * 0.5, 0.05)], 0.07, P["wood_dk"], seg=6)
        for x in (-span / 2, span / 2):
            L.cyl(mb, 0.06, 0.06, 0.95, 6, P["wood_dk"], T(x, sy * 0.55, 0))
            L.ball(mb, (x, sy * 0.55, 0.98), 0.065, P["gold"], 5, 3)
        L.tube(mb, L.catenary((-span / 2, sy * 0.55, 0.9), (span / 2, sy * 0.55, 0.9), 0.2, 8), 0.02, P["cream"], seg=3)
        for k in range(3):
            L.bloom(mb, (-0.8 + k * 0.8, sy * 0.55, 0.72), 0.06, P[FLOWER_COLS[k + (sy > 0) * 3]], P["butter"], detail=0)
    colbox(out, span, 1.1, 0.3)


def starlight_rim_stone(mb, rng, out, s=1.0):
    L.rock(mb, s * 1.2, s * 0.9, s * 0.7, P["pearl"], rng, seg=9, rings=6, jit=0.15)
    L.rock(mb, s * 0.6, s * 0.5, s * 0.4, P["pearl_lilac"], rng, T(s * 0.6, s * 0.25, 0), seg=7, rings=4, jit=0.15)
    flecks(mb, rng, 26, s * 1.25, s * 0.95, 0.05, s * 0.65, P["glow_star"], 0.025 * s)
    flecks(mb, rng, 8, s * 1.2, s * 0.9, 0.05, s * 0.6, P["glow_lilac"], 0.03 * s)
    L.prism(mb, 0.05 * s, 0.18 * s, P["glow_lilac"], T(-s * 0.35, s * 0.1, s * 0.55, rx=20))
    colbox(out, s * 1.1, s * 0.85, s * 0.65)


def pool_glow_crystal(mb, rng, out):
    cols = ["glow_lilac", "glow_star", "glow_teal", "glow_rose"]
    for i in range(9):
        a = TAU * i / 9
        rr = 0.0 if i == 0 else rng.uniform(0.12, 0.35)
        h = 0.9 if i == 0 else rng.uniform(0.3, 0.7)
        L.prism(mb, rng.uniform(0.06, 0.11) * (1.5 if i == 0 else 1), h, P[cols[i % 4]],
                T(rr * math.cos(a), rr * math.sin(a), 0, rx=rr * 60 * math.sin(a), ry=-rr * 60 * math.cos(a)))
    L.rock(mb, 0.7, 0.6, 0.2, P["pearl_lilac"], rng, seg=7, rings=4)
    flecks(mb, rng, 10, 0.7, 0.6, 0.05, 0.2, P["glow_star"], 0.015)
