"""Camp gear any family's site can use (lane L88): the fire, the markers and
the one shelter. See monster_gear.py for the contract."""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import bpy  # noqa: E402,F401,I001
import bmesh  # noqa: E402
from mathutils import Vector  # noqa: E402
import monster_gear_kit as G  # noqa: E402
import prop_kit as K  # noqa: E402
from monster_gear_kit import R, S, T, h1, wob  # noqa: E402,F401


def camp_fire_spit(p):
    """The fire every camp sits round: a stone ring, burnt-out logs and a
    haunch on a spit. The flame and its light are the game's, not the model's."""
    G.ground_ring(p, 0.46, 10, 0.10, 3.0)
    p.add(K.lathe([(0.0, 0.012), (0.30, 0.02), (0.42, 0.0)], 12, cap_bottom=False), G.ASH, "matte",
          shade=G.mottle(G.ASH, G.CHAR, 22.0, 2.0))
    for i in range(5):
        a = 2 * math.pi * i / 5 + 0.4
        p.add(G.pole_between((0.30 * math.cos(a), 0.30 * math.sin(a), 0.04), (-0.05 * math.cos(a), -0.05 * math.sin(a), 0.14 + 0.03 * i), 0.04, i + 2.0),
              G.CHAR, "matte", shade=G.mottle(G.CHAR, G.ASH, 60.0, i, (0.30, 0.12, 0.06)))
    a = G.forked_stake(p, -0.72, 0.0, 0.78, 0.022, 4.0, 4)
    b = G.forked_stake(p, 0.72, 0.0, 0.74, 0.022, 7.0, -3)
    p.add(G.pole_between(a + Vector((-0.12, 0, 0)), b + Vector((0.12, 0, 0)), 0.014, 9.0), G.BOGWOOD, "matte")
    mid = (a + b) / 2
    haunch = K.lathe([(0.0, -0.17), (0.07, -0.13), (0.10, -0.03), (0.085, 0.07), (0.045, 0.14), (0.02, 0.17)], 9)
    p.add(haunch, G.MEAT, "satin", T(mid.x, mid.y, mid.z) @ R("Y", 90),
          shade=lambda co: K.mix(K.mix(G.MEAT, G.CHAR, 0.5 + 0.5 * math.sin(co.z * 60 + co.x * 40)), G.FAT, max(0.0, math.sin(co.x * 55.0)) * 0.35))
    p.add(G.bone(0.14, 0.012, 1.8, 6), G.BONE, "satin", T(mid.x + 0.15, mid.y, mid.z) @ R("Y", 90))
    for i in range(4):                            # gnawed bones thrown down
        p.add(G.bone(0.16 + 0.05 * h1(i), 0.011, 1.8, 6), G.BONE_OLD, "matte",
              T(0.75 * math.cos(1.0 + i * 1.7), 0.62 * math.sin(1.0 + i * 1.7), 0.014) @ R("Z", 70 * i) @ R("Y", 90))
    return dict(family="any", kind="fire", fire=(0, 0, 0.2))


def bone_totem(p):
    """A warning read from across a field: skulls roped up a pole under a
    spread of antler, crow feathers and rags stirring below."""
    p.add(G.shaft(2.25, 0.04, 0.026, 6.0, 0.04, 3, 7, -0.1), G.BOGWOOD, "matte", shade=G.wood(G.BOGWOOD, 2.0, 0.4))
    G.skull_on(p, T(0, 0.045, 1.98) @ R("X", 12), 0.105, G.BONE, 1.0, 1.0, 0.0)
    for sx in (-1, 1):                               # the antlers
        beam = [(sx * 0.05, 0.0, 2.06), (sx * 0.22, -0.03, 2.22), (sx * 0.40, -0.02, 2.44), (sx * 0.47, 0.03, 2.66)]
        p.add(K.tube(beam, [0.022, 0.018, 0.013, 0.004], 6), G.BONE_OLD, "satin", shade=G.mottle(G.BONE_OLD, G.BONE_DARK, 40.0, sx))
        for k, (bx, bz, ln) in enumerate(((0.16, 2.17, 0.20), (0.30, 2.31, 0.23), (0.41, 2.47, 0.16))):
            p.add(G.fang(ln, 0.012, 0.35, 5, 5), G.BONE_OLD, "satin", T(sx * bx, -0.02, bz) @ R("Z", 90 - sx * 90) @ R("Y", sx * (18 - 10 * k)) @ R("X", -14))
    G.skull_on(p, T(0.01, 0.05, 1.62) @ R("X", 20) @ R("Z", 14), 0.075, G.BONE_OLD, 2.0, 0.7, 0.0, False)
    G.skull_on(p, T(-0.01, 0.05, 1.38) @ R("X", 26) @ R("Z", -18), 0.062, G.BONE_OLD, 3.0, 0.5, 0.0, False)
    for z0, z1, r in ((1.86, 1.92, 0.05), (1.50, 1.56, 0.045), (1.27, 1.32, 0.045)):
        p.add(G.lash(r, z0, z1, 3, 0.006), G.SINEW, "matte")
    for i in range(4):                               # crow feathers and rags
        a = 360 * i / 4 + 20
        ln = 0.22 + 0.1 * h1(i, 2.0)
        p.add(K.tube([(0, 0, 0), (0, 0, -0.08)], 0.0015, 3), G.SINEW, "matte", T(0, 0, 1.24) @ R("Z", a) @ T(0.046, 0, 0))
        p.add(K.leaf(ln, 0.05), G.FEATHER, "satin", T(0, 0, 1.24) @ R("Z", a) @ T(0.046, 0, -0.08) @ R("Y", 90 - 12 * wob(i, 1.0)))
    for i in range(2):
        p.add(G.rag(0.45 + 0.1 * i, 0.07, 3.0 + i, 0.2, 7), K.mix(G.BLOOD, G.HIDE, 0.4 * i), "fabric", T(0, 0, 1.0 - 0.12 * i) @ R("Z", 120 * i + 30) @ T(0.04, 0, 0))
    G.ground_ring(p, 0.14, 3, 0.08, 9.0)
    return dict(family="any", kind="marker")


def skull_stake(p):
    """The small marker at a camp's edge: one skull on a sharpened stake."""
    p.add(G.shaft(1.15, 0.026, 0.012, 3.0, 0.03, 2, 6, -0.1), G.DRIFTWOOD, "matte", T(0, 0, 0) @ R("Y", 5), shade=G.wood(G.DRIFTWOOD, 4.0))
    G.skull_on(p, T(0.09, 0.03, 0.98) @ R("Y", 5) @ R("X", 18), 0.085, G.BONE, 5.0, 0.85, 0.11)
    p.add(G.rag(0.32, 0.06, 2.0, 0.25, 6), G.BLOOD, "fabric", T(0.07, 0.03, 0.86) @ R("Z", 80))
    p.add(G.lash(0.02, 0.80, 0.86, 4, 0.005), G.SINEW, "matte", T(0.07, 0, 0))
    return dict(family="any", kind="marker")


def hide_lean_to(p):
    """A hide thrown over three poles: the only shelter a camp builds, with a
    litter of bracken under it."""
    ridge_a, ridge_b = Vector((-0.9, 0.2, 1.25)), Vector((0.9, 0.2, 1.15))
    for sx, q in ((-1, ridge_a), (1, ridge_b)):
        p.add(G.pole_between((sx * 1.0, 0.3, -0.05), q + Vector((0, 0, 0.12)), 0.026, sx + 2.0), G.DRIFTWOOD, "matte", shade=G.wood(G.DRIFTWOOD, sx))
        p.add(G.pole_between((sx * 0.8, -0.25, -0.05), q + Vector((0, 0.03, 0.1)), 0.022, sx + 5.0), G.DRIFTWOOD, "matte", shade=G.wood(G.DRIFTWOOD, sx + 1))
        p.add(G.lash(0.04, -0.04, 0.04, 5, 0.006), G.SINEW, "matte", T(q.x, q.y + 0.02, q.z))
    p.add(G.pole_between(ridge_a + Vector((-0.2, 0, 0)), ridge_b + Vector((0.2, 0, 0)), 0.022, 9.0), G.BOGWOOD, "matte")
    bm = bmesh.new()                                 # the hide: ridge down to pegs at the back
    nu, nv = 12, 8
    grid = []
    for j in range(nv + 1):
        v = j / nv
        row = []
        for i in range(nu + 1):
            u = i / nu
            top = ridge_a.lerp(ridge_b, u)
            foot = Vector((-1.15 + 2.3 * u, 1.35, 0.03))
            q = top.lerp(foot, v)
            q.z -= 0.16 * math.sin(math.pi * v) * (0.6 + 0.4 * math.sin(math.pi * u))      # the sag
            q.z += 0.05 * wob(u * 5 + v * 3, 2.0) * math.sin(math.pi * v)
            if j == nv:
                q.y += 0.12 * wob(u * 6, 5.0)
            if j == 0:
                q.z += 0.03
                q.y -= 0.10 + 0.05 * wob(u * 7, 3.0)                                       # flap over the ridge
            row.append(bm.verts.new(q))
        grid.append(row)
    for j in range(nv):
        for i in range(nu):
            bm.faces.new((grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i]))
    p.add(bm, G.HIDE, "fabric", shade=G.mottle(G.HIDE, K.darker(G.HIDE, 0.4), 7.0, 1.0, G.HIDE_PALE))
    for i in range(6):                               # the seam where two hides are stitched
        y = 0.35 + 0.16 * i
        p.add(K.tube([(-0.05, y, 1.02 - 0.17 * i), (0.05, y + 0.05, 1.0 - 0.17 * i)], 0.004, 3), G.SINEW, "matte", T(0.05, 0, 0.0))
    for i in range(4):
        x = -1.1 + 0.73 * i
        p.add(K.cyl(0.018, 0.2, 5, r2=0.006), G.BOGWOOD, "matte", T(x, 1.36, 0.12) @ R("X", 160))
    p.add(K.lathe([(0.0, 0.07), (0.5, 0.06), (0.75, 0.0)], 12, cap_bottom=False), G.REED_DARK, "fabric", T(0, 0.65, 0) @ S(1.1, 0.7, 1.0),
          shade=lambda co: K.mix(G.REED_DARK, G.BRIAR, 0.5 + 0.5 * math.sin(co.x * 31 + co.y * 47)))
    return dict(family="any", kind="shelter", loot=(0.0, 0.65, 0.1))


WEAPONS = {}
CAMP = {
    "camp_fire_spit": camp_fire_spit,
    "camp_bone_totem": bone_totem,
    "camp_skull_stake": skull_stake,
    "camp_hide_lean_to": hide_lean_to,
}
