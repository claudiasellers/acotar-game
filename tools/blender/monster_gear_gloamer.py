"""Gloamer weapons and camp gear (lane L88; plans/hostile-fae/monster-gear.md §2.1).

Gloamers take what glints from the mortal side and the court's edges. Their
weapons are mortal tools bent into shape, lashed with green cord and hung with
trinkets: plain black-brown iron, bone and root, and one stolen bright thing
on each. See monster_gear.py for the contract.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import bpy  # noqa: E402,F401,I001
import bmesh  # noqa: E402
from mathutils import Vector  # noqa: E402
import monster_gear_kit as G  # noqa: E402
import prop_kit as K  # noqa: E402
import upcoming_kit as U  # noqa: E402
from monster_gear_kit import R, S, T, h1, wob  # noqa: E402

FADED_ROSE = K.mix(G.STOLEN_ROSE, G.HIDE, 0.55)
FADED_PERI = K.mix(G.STOLEN_PERI, G.HIDE, 0.6)
WOOL = (0.62, 0.59, 0.52)
OAK = G.grim(0.30, 0.21, 0.15)


def _iron(seed=1.0, rust=0.5):
    return G.mottle(G.IRON, K.mix(G.IRON, G.RUST, rust), 60.0, seed, K.mix(G.IRON, G.RUST, rust * 0.6))


def _edge_iron(seed, dist, d0, d1, worn=False):
    """Iron that wears bright toward its edge: dist(co) is the distance that
    runs from d0 (dark) to d1 (the edge)."""
    base = _iron(seed, 0.75 if worn else 0.45)
    return lambda co: K.mix(base(co), G.IRON_WORN, U._smooth(d0, d1, dist(co)) * (0.5 if worn else 0.85))


def _cord_tail(p, at, length, seed, kinds, color=G.CORD_GREEN):
    """A loose end of cord hanging from `at`, with trinkets tied along it."""
    pts = [(at[0] + 0.012 * wob(i * 0.9, seed) * i / 5, at[1] + 0.01 * wob(i * 1.1, seed + 3) * i / 5, at[2] - length * i / 5) for i in range(6)]
    p.add(K.tube(pts, 0.0022, 4), color, "fabric")
    for i, kind in enumerate(kinds):
        q = pts[-1 - 2 * i]
        _trinket(p, kind, T(q[0], q[1], q[2]) @ R("Z", 97 * i), seed + i)


def _trinket(p, kind, m, seed=1.0):
    if kind == "bead":
        p.add(U.sphere(0.006, 6, 5), G.STOLEN_MINT, "pearl", m @ T(0, 0, -0.006))
    elif kind == "brass_button":
        p.add(K.lathe([(0.0, 0.0), (0.011, 0.001), (0.012, 0.0035), (0.0, 0.005)], 8), G.BRASS, "gold", m @ T(0, 0, -0.014) @ R("X", 90))
    elif kind == "locket":
        p.add(K.torus(0.004, 0.0012, 6, 3), G.GILT, "gold", m @ T(0, 0, -0.004) @ R("X", 90))
        p.add(U.sphere(0.014, 8, 6), G.GILT, "gold", m @ T(0, 0, -0.022) @ S(1.0, 0.35, 1.2))
        p.add(U.sphere(0.005, 6, 4), G.STOLEN_ROSE, "pearl", m @ T(0, -0.005, -0.022))
    elif kind == "shoe":                          # a doll's shoe
        p.add(K.tube([(0, 0, -0.008), (0, 0, -0.028), (0, 0.006, -0.034), (0, 0.03, -0.036)], [0.007, 0.008, 0.009, 0.006], 6),
              G.STOLEN_ROSE, "satin", m)
        p.add(U.sphere(0.003, 5, 4), G.GILT, "gold", m @ T(0, 0.012, -0.027))
    else:
        G.trinket(p, kind, m, seed)


# ================================================================== weapons


def hookknife(p, worn):
    """Gloamer Hook-knife: a mortal sickle blade bent tighter, lashed to a
    knobbed bone with green cord, a brass button and a bead on the cord's end."""
    p.add(G.bone(0.20, 0.0098, 1.8, 7), G.BONE_OLD, "matte", T(0, 0, -0.10), shade=G.mottle(G.BONE_OLD, G.BONE_DARK, 110.0, 2.0, G.BONE))
    cy, cz, rr = 0.100, 0.235, 0.108
    path = [(0.0, 0.07), (-0.006, 0.15)] + G.arc(cy, cz, rr, 172, 22, 14)
    n = len(path)
    widths = [0.014, 0.020] + [0.030 * (1.0 - (i / 14) ** 1.7) + 0.003 for i in range(15)]
    thick = [0.006, 0.005] + [0.0042 * (1.0 - 0.7 * i / 14) for i in range(15)]
    dist = lambda co: rr - math.hypot(co.y - cy, co.z - cz)      # noqa: E731
    p.add(G.curved_blade(path, widths[:n], thick[:n], 3.0, chip=0.008 if worn else 0.002), G.IRON, "satin",
          shade=_edge_iron(1.0, dist, 0.0, 0.016, worn))
    p.add(G.lash(0.0125, 0.045, 0.115, 8, 0.0042, 4, 0.95, 0.001, 2.0), G.CORD_GREEN, "fabric")
    p.add(G.lash(0.0105, -0.035, 0.02, 4, 0.0036, 4), G.CORD_GREEN, "fabric")
    _cord_tail(p, (0.012, -0.004, 0.05), 0.11, 4.0, ["brass_button"] if worn else ["brass_button", "bead"])
    if worn:
        G.crack(p, (0.0052, -0.004, -0.06), (0.0055, 0.003, 0.03), 2.0)
        G.crack(p, (0.0026, cy - rr + 0.004, cz + 0.01), (0.0022, cy - rr + 0.022, cz + 0.045), 5.0, 0.001)
    tip = path[-1]
    return dict(tip=(0, tip[0], tip[1]), imbue=(0, cy - 0.02, cz + rr * 0.8), hands=1, kind="sickle")


def knuckleclub(p, worn):
    """Knuckle-club: a knotted root cudgel studded with bent nails, a horseshoe
    hammered round the head, moss in the grain."""
    mossy = G.mottle(G.DRIFTWOOD, K.darker(G.DRIFTWOOD, 0.4), 50.0, 1.0, G.MOSS)
    p.add(G.shaft(0.62, 0.016, 0.03, 5.0, 0.016, 3, 8, -0.14), G.DRIFTWOOD, "matte", shade=mossy)
    hz = 0.50
    head = G.stone(0.066, 3.3, 1.2, 3)
    p.add(head, G.DRIFTWOOD, "matte", T(0.003, 0.0, hz), shade=G.mottle(K.darker(G.DRIFTWOOD, 0.2), G.BOGWOOD, 48.0, 4.0, G.MOSS))
    shoe = [(0.074 * math.cos(math.radians(a)), 0.074 * math.sin(math.radians(a)), hz + 0.006 * math.sin(math.radians(a * 2)))
            for a in range(-150, 151, 25)]
    sm = (T(0, 0.012, 0.012) @ R("X", 14) @ R("Z", 25)) if worn else T(0, 0, 0)       # sprung loose when worn
    p.add(K.tube(shoe, [0.009] + [0.0105] * (len(shoe) - 2) + [0.009], 5), G.IRON, "satin", sm @ T(0, 0, 0) @ S(1.0, 1.0, 1.0),
          shade=_iron(2.0, 0.6))
    for i in range(7 if worn else 12):               # bent nails
        a = 2 * math.pi * h1(i, 7.0)
        el = math.radians(-30 + 105 * h1(i, 8.0))
        d = Vector((math.cos(a) * math.cos(el), math.sin(a) * math.cos(el), math.sin(el)))
        m = T(0.003, 0, hz) @ d.to_track_quat("Z", "Y").to_matrix().to_4x4() @ T(0, 0, 0.052)
        bend = 0.012 * (h1(i, 9.0) - 0.3)
        p.add(K.tube([(0, 0, 0), (0, bend * 0.3, 0.02), (0, bend, 0.042)], [0.0055, 0.0048, 0.0014], 5), G.IRON, "satin", m, shade=_iron(i, 0.8))
        p.add(K.cyl(0.0095, 0.004, 6), G.IRON, "matte", m @ T(0, 0, -0.002))
    p.add(G.lash(0.02, -0.06, 0.06, 6, 0.0045, 4), G.CORD_GREEN, "fabric")
    _cord_tail(p, (0.02, 0, -0.05), 0.10, 6.0, [] if worn else ["key"])
    if worn:
        G.crack(p, (0.05, 0.03, hz + 0.05), (0.03, 0.02, hz - 0.07), 3.0, 0.0022)
        G.crack(p, (-0.02, 0.022, 0.30), (-0.012, 0.018, 0.12), 4.0, 0.0016)
    return dict(tip=(0, 0, hz + 0.085), imbue=(0, 0.07, hz), hands=1, kind="club")


def trinket_flail(p, worn):
    """Trinket Flail: a short stick and a metre of cord ending in a fist of
    stolen trinkets. The cord and its knot are the child mesh "<id>_cord",
    modelled flung straight out past the stick: turn it about its origin to
    let it hang or to swing it."""
    top = 0.28
    p.add(G.shaft(0.40, 0.014, 0.012, 8.0, 0.012, 2, 7, -0.12), G.DRIFTWOOD, "matte", shade=G.wood(G.DRIFTWOOD, 3.0))
    p.add(G.lash(0.016, -0.05, 0.05, 6, 0.0042, 4), G.CORD_GREEN, "fabric")
    p.add(K.torus(0.011, 0.0032, 10, 5), G.IRON, "satin", T(0, 0, top + 0.008) @ R("Y", 90), shade=_iron(1.0))
    p.add(G.lash(0.014, top - 0.05, top - 0.01, 4, 0.0036, 4), G.CORD_GREEN, "fabric")
    if worn:
        G.crack(p, (0.0125, 0.004, 0.08), (0.0118, -0.003, 0.24), 2.0, 0.0015)
    cord = G.Prop("cord")
    ln = 1.0
    pts = [(0.02 * math.sin(i * 0.9) * math.sin(math.pi * i / 14), 0.03 * math.sin(i * 0.5) * math.sin(math.pi * i / 14), ln * i / 14) for i in range(15)]
    cord.add(K.tube(pts, 0.0055, 5), G.CORD_GREEN, "fabric")
    for z in (0.3, 0.62):                            # knots along the cord
        cord.add(U.sphere(0.011, 6, 4), G.CORD_GREEN, "fabric", T(0.01 * math.sin(z * 14 * 0.9), 0, z))
    kz = ln + 0.02
    cord.add(G.stone(0.04, 2.0, 1.0, 2), G.CORD_GREEN, "fabric", T(0, 0, kz))
    kinds = ["key", "bell", "spoon", "thimble", "key", "spoon", "bell", "ring", "coin"]
    for i, kind in enumerate(kinds):                 # the fist of trinkets bound into the knot
        a = 2 * math.pi * i / len(kinds)
        d = Vector((math.cos(a) * 0.8, math.sin(a) * 0.8, 0.35 + 0.5 * h1(i, 3.0))).normalized()
        m = T(0, 0, kz) @ d.to_track_quat("-Z", "Y").to_matrix().to_4x4() @ T(0, 0, -0.03) @ S(1.9)
        _trinket(cord, kind, m, i)
    return dict(tip=(0, 0, top + ln + 0.08), imbue=(0, 0, top + ln), hands=1, kind="whip", parts={"cord": (cord, (0, 0, top + 0.012))})


def scythe_glaive(p, worn):
    """Scythe-glaive: a mortal scythe blade set crosswise on a long crooked
    pole, the joint bound in rags and wire, bells on the binding."""
    p.add(G.shaft(1.84, 0.02, 0.016, 13.0, 0.035, 4, 8, -0.74), G.DRIFTWOOD, "matte", shade=G.wood(G.DRIFTWOOD, 6.0, 0.35))
    hz = 1.06
    path = [(-0.045, hz + 0.01)] + [(0.66 * t, hz + 0.01 + 0.10 * math.sin(math.pi * t * 0.55) - 0.20 * t * t) for t in [i / 13 for i in range(1, 14)]]
    widths = [0.05] + [0.078 * (1.0 - t ** 1.5) + 0.006 for t in [i / 13 for i in range(1, 14)]]
    thick = [0.008] + [0.0055 * (1.0 - 0.75 * i / 13) for i in range(1, 14)]
    dist = lambda co: (hz + 0.02 + 0.08 * math.sin(math.pi * min(co.y / 0.66, 1.0) * 0.55) - 0.20 * (co.y / 0.66) ** 2) - co.z     # noqa: E731
    p.add(G.curved_blade(path, widths, thick, 5.0, chip=0.016 if worn else 0.004), G.IRON, "satin", shade=_edge_iron(3.0, dist, 0.0, 0.04, worn))
    p.add(K.tube([(0, -0.045, hz + 0.012), (0, 0.30, hz + 0.075), (0, 0.5, hz + 0.045)], [0.006, 0.005, 0.002], 5), G.IRON, "satin",
          shade=_iron(4.0))                           # the rib along the blade's back
    p.add(G.lash(0.026, hz - 0.09, hz + 0.05, 9, 0.006, 4, 1.25, 0.003, 3.0), FADED_ROSE, "fabric", T(0, 0.004, 0))
    p.add(G.lash(0.031, hz - 0.06, hz + 0.03, 6, 0.0018, 3, 1.25, 0.002, 5.0), G.IRON, "satin", T(0, 0.004, 0))     # wire
    for i in range(2 if worn else 3):
        p.add(G.rag(0.16 + 0.05 * i, 0.03, 2.0 + i, 0.3, 6, 0.0016), (FADED_ROSE, FADED_PERI, G.HIDE_PALE)[i], "fabric",
              T(0, 0, hz - 0.07) @ R("Z", 120 * i + 40) @ T(0.026, 0, 0))
    for i in range(1 if worn else 3):                # bells on the binding
        a = math.radians(200 + 70 * i)
        q = (0.03 * math.cos(a), 0.03 * math.sin(a), hz - 0.03)
        p.add(K.tube([q, (q[0], q[1], q[2] - 0.035 - 0.01 * i)], 0.0012, 3), G.CORD_GREEN, "fabric")
        _trinket(p, "bell", T(q[0], q[1], q[2] - 0.035 - 0.01 * i), i)
    p.add(G.lash(0.021, -0.07, 0.07, 6, 0.005, 4), G.HIDE, "fabric")
    p.add(G.lash(0.021, 0.36, 0.46, 4, 0.005, 4), G.HIDE, "fabric")
    if worn:
        G.crack(p, (0.0024, 0.2, hz + 0.06), (0.0018, 0.26, hz - 0.01), 2.0, 0.0018)
        G.crack(p, (0.018, 0.006, 0.6), (0.017, -0.004, 0.86), 3.0, 0.0018)
    tip = path[-1]
    return dict(tip=(0, tip[0], tip[1]), imbue=(0, 0.3, hz + 0.02), hands=2, kind="spear")


def _axe_head(p, z, worn, seed=1.0):
    lo, hi = z - 0.028, z + 0.028
    st = [(-0.034, lo, hi, 0.015), (-0.012, lo - 0.002, hi + 0.002, 0.017), (0.018, lo - 0.002, hi + 0.004, 0.013),
          (0.060, lo - 0.016, hi + 0.012, 0.007), (0.088, lo - 0.03, hi + 0.018, 0.0028), (0.100, lo - 0.036, hi + 0.02, 0.0006)]
    if worn:
        st[-1] = (0.094, lo - 0.03, hi + 0.014, 0.0012)
    p.add(G.wedge(st), G.IRON, "satin", shade=_edge_iron(seed, lambda co: co.y, 0.06, 0.1, worn))


def woodcutter_hatchet(p, worn):
    """Woodcutter's Hatchet: a plain mortal hatchet, the handle gnawed, a ribbon tied on."""
    p.add(G.shaft(0.40, 0.0135, 0.0155, 4.0, 0.006, 0, 8, -0.13), OAK, "satin", S(0.82, 1.15, 1.0), shade=G.wood(OAK, 2.0, 0.35))
    _axe_head(p, 0.235, worn)
    for i in range(9 if worn else 6):                # gnaw marks: pale bites out of the dark handle
        z = -0.10 + 0.035 * i + 0.01 * h1(i, 2.0)
        a = math.radians(60 + 240 * h1(i, 3.0))
        p.add(U.sphere(0.006, 5, 4), K.lighter(OAK, 0.4), "matte", T(0.0105 * math.cos(a), 0.0145 * math.sin(a), z) @ S(0.45, 0.45, 2.2) @ R("X", 25))
    p.add(G.lash(0.0165, 0.14, 0.165, 2.5, 0.004, 4, 1.3), FADED_PERI, "fabric")
    for i in range(2):
        p.add(G.rag(0.10 + 0.03 * i, 0.014, 3.0 + i, 0.35, 6, 0.0012), FADED_PERI, "fabric", T(0.012, -0.012, 0.15) @ R("Z", 200 + 50 * i))
    if worn:
        G.crack(p, (0.0115, 0.01, 0.0), (0.0118, -0.004, 0.17), 2.0, 0.0015)
        G.crack(p, (0.0125, 0.03, 0.25), (0.0075, 0.075, 0.225), 3.0, 0.0012)
    return dict(tip=(0, 0.10, 0.25), imbue=(0, 0.06, 0.235), hands=1, kind="axe")


def pruning_hook(p, worn):
    """Pruning Hook: a long-handled orchard hook with blossom twigs caught in the binding."""
    p.add(G.shaft(0.74, 0.013, 0.012, 17.0, 0.012, 1, 7, -0.22), OAK, "satin", shade=G.wood(OAK, 5.0, 0.3))
    cy, cz, rr = 0.062, 0.63, 0.064
    path = [(0.0, 0.47), (-0.003, 0.55)] + G.arc(cy, cz, rr, 178, 5, 10)
    widths = [0.012, 0.018] + [0.030 * (1.0 - (i / 10) ** 1.8) + 0.003 for i in range(11)]
    thick = [0.005, 0.0045] + [0.0038 * (1.0 - 0.7 * i / 10) for i in range(11)]
    dist = lambda co: rr - math.hypot(co.y - cy, co.z - cz)      # noqa: E731
    p.add(G.curved_blade(path, widths, thick, 6.0, chip=0.007 if worn else 0.0015), G.IRON, "satin", shade=_edge_iron(5.0, dist, 0.0, 0.014, worn))
    p.add(K.lathe([(0.0145, 0.44), (0.016, 0.455), (0.0155, 0.51), (0.013, 0.525)], 8), G.IRON, "satin", shade=_iron(2.0))      # the socket
    p.add(G.lash(0.017, 0.455, 0.505, 5, 0.0035, 4), G.SINEW, "matte")
    for i in range(1 if worn else 3):                # blossom twigs caught in the binding
        a = math.radians(140 + 80 * i)
        base = Vector((0.016 * math.cos(a), 0.016 * math.sin(a), 0.47))
        tw = [tuple(base), tuple(base + Vector((0.03 * math.cos(a), 0.03 * math.sin(a), -0.03))),
              tuple(base + Vector((0.07 * math.cos(a), 0.06 * math.sin(a), -0.035 - 0.02 * i)))]
        p.add(K.tube(tw, [0.0026, 0.002, 0.0012], 4), G.BOGWOOD, "matte")
        for k in (1, 2):
            K.star_flower(p, tw[k], 0.010, (0.80, 0.62, 0.64), 5, "fabric", (0.70, 0.56, 0.30), R("X", 60 * k - 30) @ R("Y", 70 * i))
    p.add(G.lash(0.0145, -0.06, 0.06, 5, 0.004, 4), G.HIDE, "fabric")
    if worn:
        G.crack(p, (0.011, 0.006, 0.12), (0.0112, -0.003, 0.36), 2.0, 0.0015)
    tip = path[-1]
    return dict(tip=(0, tip[0], tip[1]), imbue=(0, cy, cz + rr * 0.6), hands=1, kind="sickle")


# ================================================================== camp gear


def _log_ring(x, r, seed, n=14, squash=0.9):
    ring = []
    for s in range(n):
        a = 2 * math.pi * s / n
        rr = r * (1.0 + 0.07 * wob(s * 1.3 + x * 2.0, seed) + 0.04 * math.sin(a * 5 + x * 3))
        ring.append((x, rr * math.cos(a), r * squash + rr * squash * math.sin(a)))
    return ring


def hoard_log(p):
    """Hollow-log hoard: a fallen hollow log, one end stuffed with rags, moss
    and shiny things. The bark flap on its flank is the lid."""
    r, half = 0.34, 1.2
    bark = G.mottle(K.darker(G.DRIFTWOOD, 0.15), G.BOGWOOD, 16.0, 1.0, G.MOSS)
    xs = [-half + 2 * half * i / 12 for i in range(13)]
    p.add(G.loft([_log_ring(x, r * (1.0 + 0.10 * math.sin(x * 2.1)), 2.0) for x in xs], cap0=True, cap1=False), G.BOGWOOD, "matte", shade=bark)
    outer = _log_ring(half, r * (1.0 + 0.10 * math.sin(half * 2.1)), 2.0)
    inner = _log_ring(half - 0.02, r * 0.74, 5.0)
    p.add(G.loft([outer, inner], False, False), (0.36, 0.27, 0.19), "matte", shade=G.mottle((0.36, 0.27, 0.19), G.BOGWOOD, 40.0, 3.0))      # the broken rim
    hollow = G.loft([inner, _log_ring(half - 0.35, r * 0.7, 5.0), _log_ring(half - 0.7, r * 0.5, 5.0)], False, True)
    bmesh.ops.reverse_faces(hollow, faces=hollow.faces[:])
    p.add(hollow, G.CHAR, "matte")
    for i in range(4):                               # snapped branch stubs
        x = -0.9 + 0.55 * i
        a = math.radians(50 + 35 * i)
        m = T(x, r * 0.9 * math.cos(a), r * 0.9 + r * 0.85 * math.sin(a)) @ R("X", math.degrees(a) - 90 + 180)
        p.add(G.shaft(0.16 + 0.1 * h1(i), 0.05, 0.028, i + 3.0, 0.01, 0, 6), G.BOGWOOD, "matte", m @ R("X", 180), shade=bark)
    for i in range(7):                               # moss along the top, shelf fungus on the flank
        x = -1.0 + 0.33 * i
        p.add(G.stone(0.12 + 0.05 * h1(i, 2.0), 30.0 + i, 0.35, 2), G.MOSS, "fabric", T(x, 0.05 * wob(i, 3.0), r * 1.82),
              shade=G.mottle(G.MOSS, K.darker(G.MOSS, 0.4), 30.0, i))
    for i in range(5):
        x = -0.75 + 0.2 * i + 0.1 * h1(i, 4.0)
        p.add(K.lathe([(0.0, 0.0), (0.07 + 0.03 * h1(i, 5.0), 0.004), (0.06, 0.02), (0.0, 0.028)], 8), G.BONE_OLD, "matte",
              T(x, -r * 0.93, r * (0.7 + 0.25 * h1(i, 6.0))) @ S(1, 0.6, 1), shade=G.mottle(G.BONE_OLD, G.HIDE, 90.0, i))
    # the stuffing at the open end
    mouth = Vector((half - 0.06, 0.0, r * 0.78))
    for i in range(7):
        col = (FADED_ROSE, G.HIDE_PALE, FADED_PERI, G.HIDE, WOOL, G.MOSS, G.HIDE_PALE)[i]
        p.add(G.stone(0.10 + 0.04 * h1(i, 7.0), 40.0 + i, 0.75, 1), col, "fabric",
              T(mouth.x - 0.02 + 0.07 * h1(i, 8.0), 0.17 * wob(i, 9.0), r * 0.35 + 0.30 * h1(i, 10.0)))
    for i in range(3):
        p.add(G.rag(0.3 + 0.1 * i, 0.09, 6.0 + i, 0.3, 6), (FADED_PERI, G.HIDE_PALE, FADED_ROSE)[i], "fabric",
              T(half + 0.03, -0.12 + 0.12 * i, r * (0.75 - 0.15 * i)) @ R("Z", 90))
    for i, kind in enumerate(["spoon", "coin", "ring", "key", "coin", "thimble", "coin", "bell"]):
        a = math.radians(-70 + 140 * h1(i, 11.0))
        d = 0.14 + 0.32 * h1(i, 12.0)
        _trinket(p, kind, T(half + d * math.cos(a), d * math.sin(a), 0.008) @ R("Z", 360 * h1(i, 13.0)) @ R("X", 90), i)
    _trinket(p, "locket", T(half + 0.02, 0.08, r * 0.95))
    # the flap: a window cut in the front flank (-Y), its bark a hinged lid
    a0, a1 = math.radians(196), math.radians(262)
    x0, x1 = -0.52, 0.12

    def flank(x, a, out):
        rr = r * (1.0 + 0.10 * math.sin(x * 2.1)) + out
        return Vector((x, rr * math.cos(a), r * 0.9 + rr * 0.9 * math.sin(a)))

    hole = bmesh.new()
    grid = [[hole.verts.new(flank(x0 + (x1 - x0) * i / 6, a0 + (a1 - a0) * j / 5, 0.006)) for i in range(7)] for j in range(6)]
    for j in range(5):
        for i in range(6):
            hole.faces.new((grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i]))
    p.add(hole, G.CHAR, "matte")
    for i, kind in enumerate(["coin", "spoon", "ring"]):          # a glint inside the window
        q = flank(x0 + 0.15 + 0.17 * i, math.radians(235 + 8 * i), 0.012)
        _trinket(p, kind, T(q.x, q.y, q.z + 0.02) @ R("X", 60), i)
    hinge = flank((x0 + x1) / 2, a0, 0.02)
    lid = G.Prop("lid")
    lb = bmesh.new()
    lift = 0.42                                       # propped ajar, radians
    lg = []
    for j in range(6):
        row = []
        for i in range(9):
            x = x0 - 0.04 + (x1 - x0 + 0.08) * i / 8
            q = flank(x, a0 + (a1 - a0 + 0.06) * j / 5, 0.03 + 0.012 * wob(i * 1.3 + j, 2.0)) - hinge
            ang = -lift
            q = Vector((q.x, q.y * math.cos(ang) - q.z * math.sin(ang), q.y * math.sin(ang) + q.z * math.cos(ang)))
            if j == 5:
                q.z -= 0.03 * h1(i, 4.0)
            row.append(lb.verts.new(q))
        lg.append(row)
    for j in range(5):
        for i in range(8):
            lb.faces.new((lg[j][i], lg[j + 1][i], lg[j + 1][i + 1], lg[j][i + 1]))
    lid.add(lb, G.BOGWOOD, "matte", shade=lambda co: bark(co + hinge))
    loot = flank((x0 + x1) / 2, (a0 + a1) / 2, 0.05)
    return dict(kind="hoard", loot=tuple(loot), parts={"lid": (lid, tuple(hinge))})


def _stump(p, r, h, seed=1.0):
    prof = [(r * 1.7, 0.0), (r * 1.2, h * 0.16), (r * 1.02, h * 0.5), (r, h), (r * 0.9, h * 1.01), (0.0, h * 0.99)]
    bm = K.lathe(prof, 30, cap_bottom=False)
    for v in bm.verts:
        a = math.atan2(v.co.y, v.co.x)
        k = 1.0 + (0.16 if v.co.z < h * 0.2 else 0.06) * math.sin(a * 5 + seed) + 0.04 * wob(a * 3 + v.co.z * 9, seed)
        v.co.x *= k
        v.co.y *= k
    top = (0.42, 0.33, 0.24)
    p.add(bm, G.BOGWOOD, "matte",
          shade=lambda co: K.mix(top, K.darker(top, 0.3), 0.5 + 0.5 * math.sin(math.hypot(co.x, co.y) * 190)) if co.z > h * 0.97
          else G.mottle(K.darker(G.DRIFTWOOD, 0.15), G.BOGWOOD, 30.0, seed, G.MOSS)(co))


def shiny_line(p):
    """The shiny line: a stump with bottle glass, buttons, a cracked mirror
    shard and spoons set out in a careful row. It glints at dusk."""
    r, h = 0.27, 0.46
    _stump(p, r, h, 2.0)
    z = h * 1.01
    y = -0.08
    row = [-0.19, -0.13, -0.085, -0.045, 0.0, 0.05, 0.10, 0.15, 0.20]
    # a bottle's broken base, standing
    p.add(K.lathe([(0.03, 0.0), (0.032, 0.012), (0.03, 0.05), (0.026, 0.085)], 9, cap_top=False), G.BOTTLE, "glass", T(row[0], y, z))
    p.add(K.lathe([(0.0, 0.0), (0.012, 0.001), (0.013, 0.004), (0.0, 0.005)], 8), G.BRASS, "gold", T(row[1], y, z))
    p.add(K.lathe([(0.0, 0.0), (0.010, 0.001), (0.011, 0.003), (0.0, 0.004)], 8), K.PEARL, "pearl", T(row[2], y, z))
    p.add(K.lathe([(0.0, 0.0), (0.009, 0.001), (0.010, 0.003), (0.0, 0.004)], 8), G.STOLEN_ROSE, "pearl", T(row[3], y, z))
    shard = U.slab([(-0.045, 0.0), (0.03, 0.0), (0.05, 0.06), (0.012, 0.115), (-0.03, 0.085)], 0.004)       # the mirror, propped on a pebble
    p.add(shard, G.SILVER, "mirror", T(row[4] + 0.01, y + 0.03, z) @ R("X", -22))
    G.crack(p, (row[4] - 0.01, y + 0.018, z + 0.03), (row[4] + 0.035, y + 0.0, z + 0.075), 2.0, 0.0012)
    p.add(G.stone(0.022, 3.0, 0.8, 1), G.GRANITE, "matte", T(row[4] + 0.01, y + 0.05, z + 0.012))
    for i in (5, 6):
        G.trinket(p, "spoon", T(row[i], y - 0.05, z + 0.004) @ R("X", -90) @ R("Z", 6 * (i - 5)))
    p.add(K.lathe([(0.02, 0.0), (0.02, 0.03), (0.011, 0.055), (0.012, 0.08), (0.014, 0.085)], 8, cap_top=False), G.BOTTLE, "glass", T(row[7], y, z))
    G.trinket(p, "thimble", T(row[8], y + 0.02, z + 0.022))
    for i in range(5):                               # more glass in the grass at its foot
        a = math.radians(200 + 35 * i)
        p.add(U.shard(__import__("random").Random(i + 3), 0.035), G.BOTTLE, "glass", T(0.5 * math.cos(a), 0.5 * math.sin(a), 0.006) @ R("Z", 70 * i))
    return dict(kind="tell")


def trinket_cords(p):
    """Trinket cords: three cords strung between two dead branches, hung with
    keys, bells, a doll's shoe and a locket."""
    a = G.forked_stake(p, -1.5, 0.0, 2.15, 0.03, 2.0, -6)
    b = G.forked_stake(p, 1.5, 0.05, 1.95, 0.03, 6.0, 5)
    for sx, q, sd in ((-1, a, 3.0), (1, b, 8.0)):    # side twigs, so they read as dead branches
        for k in range(2):
            z = 0.9 + 0.5 * k
            p.add(G.shaft(0.35 + 0.1 * k, 0.014, 0.004, sd + k, 0.02, 0, 5), G.DRIFTWOOD, "matte",
                  T(q.x * (z / q.z) * 0.98 + sx * 0.0, q.y, z) @ R("Z", 130 * k + 20) @ R("Y", 48), shade=G.wood(G.DRIFTWOOD, sd + k))
    lines = [(a, b, 0.22, ["key", "bell", "ribbon", "shoe", "bell", "locket", "ribbon"]),
             (a + Vector((0.06, 0, -0.5)), b + Vector((-0.05, 0, -0.38)), 0.16, ["bell", "key", "bell", "ribbon"]),
             (a + Vector((0.11, 0, -1.0)), b + Vector((-0.02, 0, -0.1)), 0.28, ["spoon", "key", "bell", "coin"])]
    for i, (q0, q1, sag, kinds) in enumerate(lines):
        cord, pts = G.cord_between(q0, q1, sag, 0.0045, 14, 3)
        p.add(cord, G.CORD_GREEN, "fabric")
        step = max(1, (len(pts) - 2) // len(kinds))
        for k, kind in enumerate(kinds):
            q = Vector(pts[min(1 + k * step, len(pts) - 2)])
            d = 0.05 + 0.09 * h1(k, i + 2.0)
            p.add(K.tube([tuple(q), (q.x, q.y, q.z - d)], 0.0014, 3), G.CORD_GREEN, "fabric")
            _trinket(p, kind, T(q.x, q.y, q.z - d) @ R("Z", 360 * h1(k, i + 5.0)) @ S(1.6), k + i * 10)
    return dict(kind="tell")


def _kettle(p, m):
    prof = [(0.0, 0.0), (0.10, 0.004), (0.13, 0.05), (0.135, 0.12), (0.10, 0.19), (0.06, 0.21), (0.055, 0.225)]
    bm = K.lathe(prof, 12, cap_top=False)
    for v in bm.verts:                               # the dent
        d = (v.co - Vector((0.13, 0.02, 0.11))).length
        if d < 0.09:
            v.co.x -= 0.045 * (1 - d / 0.09) ** 2
    p.add(bm, G.IRON, "satin", m, shade=_iron(2.0, 0.7))
    p.add(K.tube([(-0.11, 0, 0.10), (-0.18, 0, 0.14), (-0.23, 0, 0.21)], [0.024, 0.018, 0.013], 7), G.IRON, "satin", m, shade=_iron(3.0, 0.7))
    p.add(K.tube(K.arc_pts(0.0, 0.225, 0.075, 0.12, 0, 180, 8), 0.007, 5), G.IRON, "satin", m @ R("X", 25))
    p.add(K.lathe([(0.062, 0.0), (0.05, 0.02), (0.012, 0.03), (0.014, 0.05), (0.0, 0.055)], 10), G.IRON, "satin",
          m @ T(0.26, 0.05, 0.0) @ R("X", 70), shade=_iron(4.0, 0.8))                              # its lid, lying off


def _boot(p, m):
    leather = G.mottle(G.HIDE, K.darker(G.HIDE, 0.45), 45.0, 2.0, G.HIDE_PALE)
    p.add(K.tube([(0, -0.02, 0.30), (0, -0.015, 0.16), (0, 0.0, 0.07), (0, 0.06, 0.045), (0, 0.15, 0.035), (0, 0.19, 0.03)],
                 [0.052, 0.046, 0.05, 0.05, 0.045, 0.028], 9), G.HIDE, "satin", m @ S(0.85, 1, 1), shade=leather)
    p.add(K.box(0.085, 0.27, 0.018, 0.006), G.BOGWOOD, "matte", m @ T(0, 0.07, 0.008))
    p.add(K.box(0.07, 0.07, 0.03, 0.006), G.BOGWOOD, "matte", m @ T(0, -0.02, 0.012))
    p.add(K.torus(0.05, 0.007, 10, 4), K.darker(G.HIDE, 0.3), "satin", m @ T(0, -0.02, 0.30) @ S(0.85, 1, 1))
    p.add(U.sphere(0.044, 8, 5), G.CHAR, "matte", m @ T(0, -0.02, 0.298) @ S(0.85, 1, 0.2))


def _lantern(p, m):
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.add(K.box(0.008, 0.008, 0.2), G.IRON, "satin", m @ T(sx * 0.06, sy * 0.06, 0.12))
    for z in (0.02, 0.22):
        p.add(K.box(0.14, 0.14, 0.012, 0.003), G.IRON, "satin", m @ T(0, 0, z), shade=_iron(z * 9, 0.7))
    p.add(K.lathe([(0.085, 0.226), (0.05, 0.27), (0.02, 0.29), (0.0, 0.292)], 4), G.IRON, "satin", m @ R("Z", 45), shade=_iron(5.0, 0.8))
    p.add(K.torus(0.03, 0.004, 10, 4), G.IRON, "satin", m @ T(0, 0, 0.31) @ R("X", 90))
    p.add(U.slab([(-0.055, 0.03), (0.055, 0.03), (0.055, 0.12), (0.01, 0.16), (-0.02, 0.10), (-0.055, 0.14)], 0.003), (0.55, 0.60, 0.55, 0.45), "glass",
          m @ T(0, -0.062, 0))                                                                      # one pane left, broken
    p.add(K.cyl(0.012, 0.05, 6, r2=0.009), G.FAT, "matte", m @ T(0, 0, 0.026))                        # the candle stub


def squabble_pile(p):
    """Squabble pile: a heap of mortal junk they fight over. A dented kettle,
    one boot, a broken lantern, a chair leg, a basket."""
    p.add(K.lathe([(0.0, 0.05), (0.35, 0.04), (0.62, 0.0)], 12, cap_bottom=False), G.HIDE, "fabric", S(1, 0.85, 1),
          shade=G.mottle(G.HIDE, G.BOGWOOD, 18.0, 1.0, FADED_PERI))                                  # a trodden rag under it all
    _kettle(p, T(-0.18, 0.08, 0.06) @ R("Y", 28) @ R("Z", 30) @ S(1.25))
    _boot(p, T(0.30, -0.22, 0.05) @ R("Z", -40) @ R("Y", 72) @ S(1.1))
    _lantern(p, T(0.02, -0.02, 0.36) @ R("X", 58) @ R("Z", 20) @ S(1.2))
    basket = K.lathe([(0.0, 0.0), (0.14, 0.005), (0.19, 0.14), (0.21, 0.26)], 12, cap_top=False)
    bm_m = T(0.28, 0.28, 0.17) @ R("Y", 105) @ R("X", 20)
    p.add(basket, G.REED, "matte", bm_m, shade=lambda co: K.mix(G.REED, G.REED_DARK, 0.5 + 0.5 * math.sin(co.z * 120) * math.sin(math.atan2(co.y, co.x) * 12)))
    p.add(K.torus(0.21, 0.014, 14, 5), G.REED_DARK, "matte", bm_m @ T(0, 0, 0.26))
    p.add(K.tube(K.arc_pts(0.0, 0.26, 0.2, 0.16, 20, 150, 8), 0.011, 5), G.REED_DARK, "matte", bm_m)
    p.add(K.turned_leg(0.42, 0.024, 8), OAK, "satin", T(-0.40, -0.26, 0.05) @ R("Z", 60) @ R("Y", 82), shade=G.wood(OAK, 2.0))
    p.add(K.box(0.07, 0.09, 0.04, 0.008), OAK, "satin", T(-0.60, -0.37, 0.07) @ R("Z", 60) @ R("Y", 10))      # the splintered corner of its seat
    for i in range(4):
        p.add(G.rag(0.25 + 0.08 * i, 0.07, 4.0 + i, 0.3, 6), (FADED_ROSE, G.HIDE_PALE, FADED_PERI, WOOL)[i], "fabric",
              T(0.3 * math.cos(i * 1.9), 0.3 * math.sin(i * 1.9), 0.20 + 0.06 * i) @ R("Z", 80 * i) @ R("Y", 55))
    for i, kind in enumerate(["spoon", "coin", "key", "fork", "brass_button"]):
        a = 2 * math.pi * h1(i, 3.0)
        _trinket(p, kind, T(0.52 * math.cos(a), 0.45 * math.sin(a), 0.03) @ R("Z", 360 * h1(i, 4.0)) @ R("X", 90), i)
    return dict(kind="dressing")


def rag_nest(p):
    """Rag nest: a trampled bowl of rags, moss and stolen wool where the pack
    lies up by day."""
    cols = [G.HIDE_PALE, FADED_ROSE, G.HIDE, FADED_PERI, WOOL, G.MOSS, G.HIDE_PALE, K.mix(G.STOLEN_MINT, G.HIDE, 0.6)]
    rings = []
    for i in range(22):
        a = 2 * math.pi * i / 22
        r0 = 0.56 * (1 + 0.08 * wob(i * 0.7, 1.0))
        hh = 0.17 * (1 + 0.35 * wob(i * 0.9, 2.0))
        c = Vector((r0 * math.cos(a), r0 * math.sin(a), 0))
        out = Vector((math.cos(a), math.sin(a), 0))
        rings.append([tuple(c + out * 0.21), tuple(c + out * 0.09 + Vector((0, 0, hh))), tuple(c - out * 0.10 + Vector((0, 0, hh * 0.9))), tuple(c - out * 0.24)])
    rings.append(rings[0])
    p.add(G.loft(rings, False, False), G.HIDE, "fabric",
          shade=lambda co: cols[int((math.atan2(co.y, co.x) + math.pi) * 2.3 + co.z * 9 + 3 * wob(co.x * 6 + co.y * 5, 3.0)) % len(cols)])
    p.add(K.lathe([(0.0, 0.035), (0.25, 0.03), (0.42, 0.055)], 14, cap_bottom=False), G.HIDE, "fabric",
          shade=lambda co: cols[int(co.x * 9 + co.y * 7 + 40) % len(cols)])
    for i in range(18):                              # rags and wool worked into the rim
        a = 2 * math.pi * i / 18 + 0.2 * wob(i, 4.0)
        rr = 0.52 + 0.12 * h1(i, 5.0)
        col = cols[(i * 3) % len(cols)]
        if i % 3 == 0:
            p.add(G.stone(0.09 + 0.04 * h1(i, 6.0), 50.0 + i, 0.6, 1), WOOL if i % 2 else G.MOSS, "fabric", T(rr * math.cos(a), rr * math.sin(a), 0.15))
        else:
            p.add(G.rag(0.30 + 0.15 * h1(i, 7.0), 0.10, 5.0 + i, 0.3, 6), col, "fabric",
                  T(rr * math.cos(a), rr * math.sin(a), 0.2) @ R("Z", math.degrees(a)) @ R("Y", -48))
    for i, kind in enumerate(["bell", "ribbon", "coin"]):       # what one of them took to bed
        _trinket(p, kind, T(0.12 * math.cos(i * 2.2), 0.12 * math.sin(i * 2.2), 0.05) @ R("X", 90), i)
    return dict(kind="rest", rest=(0, 0, 0.06))


WEAPONS = {
    "wpn_gloamer_hookknife": hookknife,
    "wpn_gloamer_knuckleclub": knuckleclub,
    "wpn_gloamer_trinket_flail": trinket_flail,
    "wpn_gloamer_scythe_glaive": scythe_glaive,
    "wpn_woodcutter_hatchet": woodcutter_hatchet,
    "wpn_pruning_hook": pruning_hook,
}
CAMP = {
    "camp_gloamer_hoard_log": hoard_log,
    "camp_gloamer_shiny_line": shiny_line,
    "camp_gloamer_trinket_cords": trinket_cords,
    "camp_gloamer_squabble_pile": squabble_pile,
    "camp_gloamer_rag_nest": rag_nest,
}
