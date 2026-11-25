"""The Hollow Hob's mortal loot and its hollow (lane L88; monster-gear.md §2.4).

The Hob hoards what it took from mortals, so its weapons are farm and forge
tools, black-brown iron on old wood, and one trophy: a tooth of its own. It
stands 6.7 m, so its stone and its pile are built to that. See monster_gear.py
for the contract.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import bpy  # noqa: E402,F401,I001
import bmesh  # noqa: E402
from mathutils import Vector  # noqa: E402
import monster_gear_gloamer as GL  # noqa: E402
import monster_gear_kit as G  # noqa: E402
import prop_kit as K  # noqa: E402
import upcoming_kit as U  # noqa: E402
from monster_gear_kit import R, S, T, h1, wob  # noqa: E402

OAK_ROOT = G.grim(0.27, 0.19, 0.13)
TOOTH = G.grim(0.64, 0.59, 0.46)
TOOTH_STAIN = G.grim(0.38, 0.30, 0.20)
WOOL = (0.80, 0.77, 0.70)
COAT = G.grim(0.22, 0.20, 0.30)
STRAW = G.grim(0.62, 0.52, 0.24)
PLANK = G.grim(0.34, 0.26, 0.19)


def smiths_hammer(p, worn):
    """Smith's Hammer: a mortal cross-peen hammer, iron black with age, its
    rotted handle replaced with a gnawed oak root."""
    p.add(G.shaft(0.42, 0.015, 0.018, 9.0, 0.014, 2, 8, -0.14), OAK_ROOT, "matte", S(0.85, 1.1, 1.0), shade=G.wood(OAK_ROOT, 3.0, 0.35))
    z = 0.255
    st = [(-0.085, z - 0.003, z + 0.003, 0.02), (-0.06, z - 0.014, z + 0.014, 0.021), (-0.028, z - 0.026, z + 0.026, 0.024), (0.02, z - 0.028, z + 0.028, 0.026),
          (0.05, z - 0.03, z + 0.03, 0.028), (0.068, z - 0.031, z + 0.031, 0.029), (0.072, z - 0.027, z + 0.027, 0.025)]
    if worn:                                         # the face mushroomed and chipped
        st[-2] = (0.064, z - 0.034, z + 0.03, 0.031)
        st[-1] = (0.069, z - 0.022, z + 0.027, 0.024)
    face = lambda co: K.mix(GL._iron(2.0, 0.7 if worn else 0.4)(co), G.IRON_WORN, max(U._smooth(0.05, 0.072, co.y), U._smooth(-0.06, -0.085, co.y)) * 0.8)   # noqa: E731
    p.add(G.wedge(st, 0.3), G.IRON, "satin", shade=face)
    for sx in (-1, 1):                               # iron wedges holding the root in the eye
        p.add(K.box(0.005, 0.016, 0.012), G.IRON_WORN, "satin", T(sx * 0.006, 0, z + 0.03))
    for i in range(7):                               # gnaw marks
        zz = -0.11 + 0.04 * i
        a = math.radians(50 + 260 * h1(i, 3.0))
        p.add(U.sphere(0.006, 5, 4), K.lighter(OAK_ROOT, 0.4), "matte", T(0.012 * math.cos(a), 0.017 * math.sin(a), zz) @ S(0.45, 0.45, 2.2) @ R("X", 25))
    p.add(G.lash(0.019, -0.05, 0.04, 5, 0.0045, 4), G.HIDE, "fabric")
    if worn:
        G.crack(p, (0.013, 0.008, 0.02), (0.014, -0.004, 0.2), 2.0, 0.0016)
        G.crack(p, (0.026, 0.02, z + 0.02), (0.028, 0.06, z - 0.02), 3.0, 0.0013)
    return dict(tip=(0, 0.072, z), imbue=(0, 0.06, z + 0.04), hands=1, kind="club")


def shepherds_crook(p, worn):
    """Shepherd's Crook: a bent iron hook on a long pole, wool still caught in it."""
    p.add(G.shaft(1.66, 0.018, 0.015, 27.0, 0.022, 2, 8, -0.74), GL.OAK, "satin", shade=G.wood(GL.OAK, 4.0, 0.3))
    top = 0.92
    p.add(K.lathe([(0.0175, top - 0.10), (0.019, top - 0.08), (0.017, top), (0.012, top + 0.02)], 8), G.IRON, "satin", shade=GL._iron(2.0))
    cy, cz, rr = 0.07, top + 0.04, 0.07
    hook = [(0.0, 0.0, top)] + [(0.0, y, z) for y, z in G.arc(cy, cz, rr, 180, -95, 14, 1.25)]
    hook.append((0.0, hook[-1][1] + 0.035, hook[-1][2] - 0.01))                                    # the turned-out lip
    rad = [0.0085] + [0.008 - 0.003 * i / 14 for i in range(15)] + [0.004]
    if worn:
        hook, rad = hook[:-4], rad[:-4]
    p.add(K.tube(hook, rad, 6), G.IRON, "satin", shade=GL._iron(5.0, 0.7 if worn else 0.4))
    for i in range(2 if worn else 5):                # wool caught in the hook
        q = hook[4 + 2 * i] if 4 + 2 * i < len(hook) else hook[-1]
        p.add(G.stone(0.02 + 0.012 * h1(i, 2.0), 9.0 + i, 0.8, 1), WOOL, "fabric", T(0.004 * (i % 2), q[1], q[2] - 0.012))
    p.add(G.lash(0.019, -0.07, 0.07, 5, 0.0045, 4), G.HIDE, "fabric")
    p.add(G.lash(0.018, 0.40, 0.48, 4, 0.0045, 4), G.HIDE, "fabric")
    if worn:
        G.crack(p, (0.016, 0.006, 0.5), (0.0155, -0.004, 0.84), 3.0, 0.0018)
    tip = hook[-1]
    return dict(tip=(0, tip[1], tip[2]), imbue=(0, cy, cz + rr), hands=2, kind="spear")


def tooth_cleaver(p, worn):
    """Hob-tooth Cleaver (unique): one of its huge blunt teeth, stained brown,
    split along its length and bound to a stone-heavy handle."""
    p.add(G.shaft(0.36, 0.019, 0.022, 14.0, 0.008, 1, 8, -0.15), OAK_ROOT, "matte", shade=G.wood(OAK_ROOT, 2.0, 0.35))
    p.add(G.stone(0.045, 6.0, 1.1, 2), G.GRANITE, "matte", T(0, 0, -0.165), shade=G.mottle(G.GRANITE, K.darker(G.GRANITE, 0.4), 40.0, 1.0, G.MOSS))
    p.add(G.lash(0.041, -0.19, -0.145, 3, 0.006, 4, 1.0, 0.002, 2.0), G.HIDE_PALE, "fabric")
    st, th = [], []
    for i in range(12):                              # the tooth: a broad root, a blunt worn crown
        t = i / 11
        z = 0.14 + 0.30 * t
        w = 0.16 * (0.62 + 0.38 * math.sin(math.pi * min(t * 1.25, 1.0) * 0.5)) * (1.0 - 0.35 * t ** 4)
        st.append((z, -0.045, -0.045 + w))
        th.append(0.05 * (1.0 - 0.45 * t) * (0.55 + 0.45 * math.sin(math.pi * min(t + 0.25, 1.0))))
    stain = G.mottle(TOOTH, K.mix(TOOTH, TOOTH_STAIN, 0.5), 22.0, 2.0, K.lighter(TOOTH, 0.12))
    p.add(G.blade(st, th, 7.0, chip=0.022 if worn else 0.008, belly=0.72), TOOTH, "pearl",
          shade=lambda co: K.mix(stain(co), TOOTH_STAIN, U._smooth(0.24, 0.14, co.z) * 0.8))
    for i in range(3):                               # the split, showing darker dentine
        G.crack(p, (0.012, -0.02 + 0.03 * i, 0.18), (0.006, -0.015 + 0.035 * i, 0.40), 2.0 + i, 0.0022 if worn else 0.0013, color=TOOTH_STAIN)
    p.add(G.lash(0.023, 0.135, 0.215, 6, 0.007, 4, 2.4, 0.003, 4.0), G.HIDE, "fabric", T(0, 0.006, 0))
    p.add(G.lash(0.022, -0.06, 0.06, 6, 0.005, 4), G.HIDE_PALE, "fabric")
    if worn:
        G.crack(p, (0.016, 0.03, 0.2), (0.008, 0.07, 0.36), 6.0, 0.003, color=G.CHAR)
    return dict(tip=(0, 0.02, 0.44), imbue=(0, 0.07, 0.32), hands=1, kind="axe", unique=True)


# ================================================================== camp gear


def _wheel(p, m, r=0.45):
    rim = [(r * math.cos(2 * math.pi * i / 16), 0.0, r * math.sin(2 * math.pi * i / 16)) for i in range(16)]
    p.add(K.tube(rim, 0.035, 5, closed=True), PLANK, "matte", m, shade=G.wood(PLANK, 2.0, 0.35))
    p.add(K.cyl(0.07, 0.14, 8), PLANK, "matte", m @ T(0, 0.07, 0) @ R("X", 90))
    for i in range(8):
        a = 2 * math.pi * i / 8
        if i == 5:                                   # one spoke gone
            continue
        p.add(K.tube([(0.05 * math.cos(a), 0, 0.05 * math.sin(a)), (r * math.cos(a), 0, r * math.sin(a))], 0.02, 4), PLANK, "matte", m)


def _sack(p, m, r, seed, col=None):
    col = col or G.HIDE_PALE
    bm = U.sphere(r, 9, 7)
    for v in bm.verts:
        q = v.co
        k = (q.z + r) / (2 * r)
        s = 1.0 + 0.18 * wob(q.x * 8 + q.y * 6, seed)
        q.x *= s * (1.1 - 0.5 * k * k)
        q.y *= s * (0.9 - 0.4 * k * k)
        q.z = (q.z + r) * 0.72
    p.add(bm, col, "fabric", m, shade=G.mottle(col, G.HIDE, 28.0, seed))
    p.add(K.cyl(r * 0.2, r * 0.3, 6, r2=r * 0.32), col, "fabric", m @ T(0, 0, r * 1.38))


def loot_pile(p):
    """The Hob's pile: a heap of mortal things. A cart wheel, a scarecrow's
    coat, kettles, a cradle, a rusted plough share, sheep bones."""
    heap = K.lathe([(0.0, 0.62), (0.45, 0.52), (0.95, 0.24), (1.4, 0.0)], 16, cap_bottom=False)
    for v in heap.verts:
        k = 1.0 + 0.12 * wob(v.co.x * 2.3 + v.co.y * 1.7, 2.0)
        v.co.x *= k
        v.co.y *= k * 0.9
        v.co.z *= 1.0 + 0.2 * wob(v.co.x * 3 + v.co.y * 2, 5.0)
    p.add(heap, G.HIDE, "fabric", shade=G.mottle(G.HIDE, G.BOGWOOD, 9.0, 1.0, STRAW))
    _wheel(p, T(-0.75, -0.35, 0.50) @ R("X", -18) @ R("Z", 25))
    GL._kettle(p, T(0.35, -0.75, 0.24) @ R("Y", -25) @ R("Z", 200) @ S(1.5))
    # the cradle, on its side
    cm = T(0.75, 0.15, 0.42) @ R("Z", -30) @ R("Y", 62)
    for sy in (-1, 1):
        p.add(K.box(0.72, 0.03, 0.30, 0.006), PLANK, "satin", cm @ T(0, sy * 0.21, 0.19), shade=G.wood(PLANK, sy + 3.0))
        rock = [(-0.42 + 0.84 * i / 8, sy * 0.0, 0.07 * math.cos(math.pi * (i / 8 - 0.5)) ** 2 * -1 + 0.07) for i in range(9)]
        p.add(K.tube([(x, sy * 0.3 * (1 if abs(x) > 0.3 else 1), z - 0.03) for x, _, z in rock], 0.022, 4), PLANK, "satin", cm @ R("Z", 90) @ T(0, 0, 0) @ S(0.6, 1, 1) @ T(sy * 0.0, sy * 0.5, 0))
    for sx in (-1, 1):
        p.add(K.box(0.03, 0.42, 0.34 + 0.12 * (sx > 0), 0.006), PLANK, "satin", cm @ T(sx * 0.36, 0, 0.21 + 0.06 * (sx > 0)))
    p.add(K.box(0.72, 0.42, 0.025), PLANK, "satin", cm @ T(0, 0, 0.05))
    p.add(G.rag(0.4, 0.3, 4.0, 0.2, 5), GL.FADED_PERI, "fabric", cm @ T(0.1, 0.0, 0.34) @ R("Y", 20))           # its blanket
    # the scarecrow's coat on its cross-pole
    sm = T(-0.15, 0.55, 0.30) @ R("X", -38) @ R("Z", 10)
    p.add(G.shaft(1.5, 0.03, 0.024, 6.0, 0.03, 1, 6), PLANK, "matte", sm)
    p.add(G.shaft(1.1, 0.024, 0.02, 8.0, 0.02, 0, 5), PLANK, "matte", sm @ T(-0.55, 0, 1.15) @ R("Y", 90))
    coat = bmesh.new()
    grid = []
    for j in range(7):
        v = j / 6
        row = []
        for i in range(9):
            u = i / 8
            x = (-0.5 + u) * (1.05 - 0.45 * U._smooth(0.15, 0.4, v) + 0.2 * v)
            row.append(coat.verts.new((x, -0.05 - 0.07 * math.sin(math.pi * u) - 0.03 * wob(u * 6 + v * 4, 2.0), 1.2 - 0.8 * v + 0.04 * math.cos(math.pi * u * 2) * (v < 0.1))))
        grid.append(row)
    for j in range(6):
        for i in range(8):
            if j == 5 and i % 3 == 1:
                continue                             # the hem is in tatters
            coat.faces.new((grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i]))
    p.add(coat, COAT, "fabric", sm, shade=G.mottle(COAT, K.darker(COAT, 0.4), 14.0, 2.0, STRAW))
    p.add(G.stone(0.13, 8.0, 1.0, 2), G.HIDE_PALE, "fabric", sm @ T(0, 0, 1.38), shade=G.mottle(G.HIDE_PALE, STRAW, 30.0, 1.0))  # its sacking head
    for i in range(6):
        p.add(K.cyl(0.006, 0.16, 3, r2=0.002), STRAW, "matte", sm @ T(0.5 * (1 if i % 2 else -1), 0, 1.15) @ R("Y", (95 if i % 2 else -95) + 12 * (i - 3)))
    # the plough share
    st = [(0.0, -0.10, 0.10), (0.15, -0.14, 0.16), (0.35, -0.12, 0.17), (0.52, -0.07, 0.10), (0.62, -0.02, 0.02)]
    p.add(G.blade(st, [0.025, 0.022, 0.018, 0.012, 0.005], 3.0, chip=0.02, belly=0.7), G.IRON, "satin",
          T(0.25, -0.2, 0.52) @ R("Y", 65) @ R("Z", 110), shade=GL._iron(3.0, 0.9))
    for i in range(4):                               # sheep bones through it all
        a = 2 * math.pi * h1(i, 2.0)
        d = 0.5 + 0.8 * h1(i, 3.0)
        p.add(G.bone(0.26 + 0.14 * h1(i, 4.0), 0.017, 1.8, 5), K.mix(G.BONE, G.BONE_OLD, h1(i, 5.0)), "matte",
              T(d * math.cos(a), d * math.sin(a) * 0.9, 0.08 + 0.42 * (1 - d / 1.3)) @ R("Z", 360 * h1(i, 6.0)) @ R("Y", 70 + 30 * h1(i, 7.0)))
    G.skull_on(p, T(1.0, -0.6, 0.14) @ R("Z", 230), 0.10, G.BONE, 2.0, 1.0, 0.2, False)
    _sack(p, T(-1.0, 0.35, 0.02) @ R("Y", -12), 0.26, 3.0)
    for i, kind in enumerate(["coin", "coin", "spoon", "coin", "ring", "key"]):
        a = math.radians(210 + 110 * h1(i, 8.0))
        d = 1.15 + 0.35 * h1(i, 9.0)
        GL._trinket(p, kind, T(d * math.cos(a), d * math.sin(a), 0.012) @ R("Z", 360 * h1(i, 10.0)) @ R("X", 90) @ S(1.6), i)
    return dict(kind="hoard", loot=(0.0, -0.9, 0.35))


def sleep_stone(p):
    """Sleeping stone: a huge mossy slab with a body-shaped hollow worn in it."""
    bm = U.rock(1.0, 3, 9.0, 0.16)
    for v in bm.verts:
        q = v.co
        q.x *= 2.1
        q.y *= 1.5
        q.z = q.z * 0.5 + 0.42
        if q.z > 0.62:
            q.z = 0.62 + (q.z - 0.62) * 0.35
            d = math.hypot((q.x + 0.1) / 1.25, (q.y - 0.05) / 0.72)          # the hollow, as long as the Hob's back
            q.z -= 0.2 * U._smooth(1.0, 0.25, d)
    stone = G.mottle(G.GRANITE, K.darker(G.GRANITE, 0.4), 4.0, 1.0, K.lighter(G.GRANITE, 0.15))

    def shade(co):
        d = math.hypot((co.x + 0.1) / 1.25, (co.y - 0.05) / 0.72)
        moss = U._smooth(0.45, 0.75, co.z) * U._smooth(0.8, 1.15, d) * (0.6 + 0.4 * math.sin(co.x * 3 + co.y * 4))
        c = K.mix(stone(co), G.MOSS, min(1.0, max(0.0, moss)))
        return K.mix(c, K.darker(G.GRANITE, 0.25), U._smooth(0.9, 0.3, d) * 0.5 if co.z > 0.4 else 0.0)     # worn smooth and dark where it lies
    p.add(bm, G.GRANITE, "matte", shade=shade)
    for i in range(12):                              # moss cushions round the rim
        a = 2 * math.pi * i / 12 + 0.3 * wob(i, 2.0)
        p.add(U.sphere(0.24 + 0.12 * h1(i, 3.0), 9, 5), G.MOSS, "fabric", T(1.75 * math.cos(a), 1.22 * math.sin(a), 0.60 + 0.04 * wob(i, 4.0)) @ R("Z", 40 * i) @ S(1.3, 0.9, 0.32),
              shade=G.mottle(G.MOSS, K.darker(G.MOSS, 0.4), 12.0, i))
    G.ground_ring(p, 1.6, 6, 0.3, 14.0, G.GRANITE, 0.55)
    for i in range(3):                               # what it dropped in its sleep
        p.add(G.bone(0.3, 0.02, 1.8, 5), G.BONE_OLD, "matte", T(-1.2 + 0.5 * i, -1.55, 0.03) @ R("Z", 40 * i) @ R("Y", 90))
    return dict(kind="rest", rest=(-0.1, 0.05, 0.5))


def sheep_bones(p):
    """Sheep bones: skulls and bones scattered where it sits to eat."""
    for i in range(12):
        a = 2 * math.pi * h1(i, 1.0)
        d = 0.7 * math.sqrt(h1(i, 2.0))
        p.add(G.bone(0.20 + 0.16 * h1(i, 4.0), 0.014, 1.8, 6), K.mix(G.BONE, G.BONE_OLD, h1(i, 5.0)), "matte",
              T(d * math.cos(a), d * math.sin(a), 0.016) @ R("Z", 360 * h1(i, 6.0)) @ R("Y", 90), shade=G.mottle(G.BONE, G.BONE_OLD, 70.0, i))
    m = T(0.1, -0.15, 0.0) @ R("Z", 40)              # a rib cage, half sunk
    p.add(K.tube([(-0.26, 0, 0.17), (0.26, 0, 0.15)], 0.016, 5), G.BONE, "matte", m)
    for i in range(7):
        for sx in (-1, 1):
            x = -0.22 + 0.072 * i
            rib = [(x, 0, 0.16), (x, sx * 0.12, 0.14), (x, sx * 0.16, 0.04), (x, sx * 0.12, -0.02)]
            p.add(K.tube(rib, [0.008, 0.007, 0.006, 0.003], 4), G.BONE, "matte", m)
    G.skull_on(p, T(-0.45, 0.25, 0.075) @ R("Z", 150) @ R("Y", 12), 0.095, G.BONE, 2.0, 1.0, 0.19)
    G.skull_on(p, T(0.48, 0.3, 0.07) @ R("Z", 20) @ R("X", 25), 0.09, G.BONE_OLD, 3.0, 1.0, 0.16)
    G.skull_on(p, T(0.2, -0.55, 0.065) @ R("Z", 260), 0.085, G.BONE_OLD, 4.0, 0.95, 0.0, False)
    for i in range(6):                               # tufts of fleece
        a = 2 * math.pi * h1(i, 8.0)
        p.add(G.stone(0.06 + 0.03 * h1(i, 9.0), 12.0 + i, 0.5, 1), WOOL, "fabric", T(0.6 * math.cos(a), 0.6 * math.sin(a), 0.02))
    return dict(kind="dressing")


WEAPONS = {
    "wpn_smiths_hammer": smiths_hammer,
    "wpn_shepherds_crook": shepherds_crook,
    "wpn_hob_tooth_cleaver": tooth_cleaver,
}
CAMP = {
    "camp_hob_loot_pile": loot_pile,
    "camp_hob_sleep_stone": sleep_stone,
    "camp_hob_sheep_bones": sheep_bones,
}
