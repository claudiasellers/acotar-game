"""Market trade signs and the cottage fingerpost (lane L53, headless bpy). Run:
    /opt/bpyenv/bin/python tools/market/market_signs.py [name ...]
Writes story/market/assets/<name>.glb. Each trade sign is a carved, painted
emblem on a pole that stands at the back of a village stall (origin = the
stall's origin, Blender -Y = the stall's front), so the trade reads over the
awning from across the square. Wood, iron and paint only: no glow, and the
emblem is smaller than the goods on the counter (the director's rule: tell
the stalls apart by their goods first, the sign confirms).
"""
import math
import os
import sys

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
sys.path.insert(0, os.path.join(REPO, "tools", "blender", "human_realm"))
import village_lib  # noqa: E402
from village_lib import C, SNOW, Asset, reset  # noqa: E402

village_lib.OUT_DIR = os.path.join(REPO, "story", "market", "assets")

# Painted trade colours: muted winter-market paint, all albedo <= 0.85.
P = {
    "oxblood": (0.50, 0.14, 0.12),
    "ochre": (0.72, 0.52, 0.22),
    "moss": (0.34, 0.44, 0.26),
    "slate": (0.30, 0.38, 0.50),
    "plum": (0.42, 0.24, 0.38),
    "cream": (0.82, 0.78, 0.66),
    "copper": (0.62, 0.36, 0.20),
    "leather": (0.36, 0.22, 0.13),
    "turnip": (0.62, 0.42, 0.62),
    "leaf": (0.30, 0.46, 0.22),
    "crust": (0.66, 0.42, 0.18),
}

SIGNS = {}
POLE_X, POLE_Y = 0.0, 1.05      # behind the back rail, centred
TOP = 3.55                       # emblem centre height
EMBLEM_SCALE = 1.55              # emblem and roundel, scaled about their centre


def sign(fn):
    SIGNS["sign_" + fn.__name__] = fn
    return fn


def pole(a, colour):
    """The pole behind the stall, a painted collar and a crossbar."""
    a.cyl(0.055, TOP - 0.25, (POLE_X, POLE_Y, 0.0), C["timber"], segs=8)
    a.cyl(0.075, 0.14, (POLE_X, POLE_Y, TOP - 0.62), colour, segs=8)
    a.box((0.9, 0.08, 0.08), (POLE_X, POLE_Y, TOP - 0.42), C["timber"], bevel=0.015)
    a.snow_mound((POLE_X, POLE_Y, TOP - 0.36), 0.05, 0.03)


def roundel(a, colour, r=0.42):
    """A painted disc behind the emblem, facing the stall front (-Y), both faces."""
    a.cyl(r, 0.05, (POLE_X, POLE_Y + 0.03, TOP), colour, rot=(math.pi / 2, 0, 0), segs=20, bevel=0.01)
    a.cyl(r + 0.03, 0.03, (POLE_X, POLE_Y + 0.045, TOP), C["timber"], rot=(math.pi / 2, 0, 0), segs=20)


def front(dy=0.0):
    return POLE_Y - 0.06 + dy


@sign
def charms():
    """Charms and bits of iron [C]: a horseshoe with three hanging charms."""
    a = Asset("sign_charms", 301)
    pole(a, P["slate"])
    roundel(a, P["slate"])
    y = front()
    for i in range(9):  # an iron horseshoe, open end down
        t = math.pi * (-0.1 + 1.2 * i / 8)
        x, z = 0.24 * math.cos(t), TOP - 0.02 + 0.26 * math.sin(t)
        a.box((0.09, 0.07, 0.11), (x, y, z), C["iron"], rot=(0, -t, 0), bevel=0.012)
    for i, dx in enumerate((-0.16, 0.0, 0.16)):
        a.cyl(0.006, 0.18, (dx, y, TOP - 0.42), C["iron"], segs=4)
        a.sphere(0.045, (dx, y, TOP - 0.44), (C["gold"], C["rust"], C["bone"])[i], subdiv=1)
    a.export()


@sign
def spice():
    """Hot food and spice [C]: a copper pot with a lid."""
    a = Asset("sign_spice", 302)
    pole(a, P["oxblood"])
    roundel(a, P["ochre"])
    y = front()
    a.cyl(0.24, 0.26, (0, y - 0.08, TOP - 0.18), P["copper"], segs=14, r2=0.27, bevel=0.01)
    a.cyl(0.26, 0.05, (0, y - 0.08, TOP + 0.08), P["copper"], segs=14, r2=0.2)
    a.sphere(0.05, (0, y - 0.08, TOP + 0.16), C["iron"], subdiv=1)
    for s in (-1, 1):
        a.box((0.1, 0.04, 0.04), (s * 0.3, y - 0.08, TOP - 0.02), C["iron"])
    a.export()


@sign
def cobbler():
    """The cobbler [C]: a leather boot."""
    a = Asset("sign_cobbler", 303)
    pole(a, P["oxblood"])
    roundel(a, P["cream"])
    y = front(-0.06)
    a.box((0.17, 0.16, 0.42), (-0.06, y, TOP + 0.04), P["leather"], bevel=0.05)
    a.box((0.36, 0.17, 0.14), (0.04, y, TOP - 0.2), P["leather"], bevel=0.05)
    a.box((0.38, 0.18, 0.04), (0.04, y, TOP - 0.28), C["black"], bevel=0.01)
    a.box((0.2, 0.17, 0.05), (-0.06, y, TOP + 0.26), P["oxblood"], bevel=0.015)
    a.export()


@sign
def clothier():
    """The clothier [C]: open shears over a folded bolt of cloth."""
    a = Asset("sign_clothier", 304)
    pole(a, P["plum"])
    roundel(a, P["plum"])
    y = front(-0.04)
    a.box((0.5, 0.12, 0.14), (0, y + 0.02, TOP - 0.22), P["cream"], bevel=0.03)
    a.box((0.5, 0.12, 0.05), (0, y + 0.02, TOP - 0.13), P["slate"], bevel=0.01)
    for s in (-1, 1):
        a.box((0.06, 0.04, 0.46), (s * 0.06, y - 0.05, TOP + 0.06), C["stone"], rot=(0, s * 0.42, 0), bevel=0.01)
        a.cyl(0.07, 0.03, (s * 0.14, y - 0.05, TOP - 0.1), C["iron"], rot=(math.pi / 2, 0, 0), segs=10)
    a.export()


@sign
def baker():
    """Bread [X]: a round loaf, scored."""
    a = Asset("sign_baker", 305)
    pole(a, P["ochre"])
    roundel(a, P["moss"])
    y = front(-0.05)
    a.sphere(0.3, (0, y, TOP), P["crust"], scale=(1.0, 0.45, 0.7), subdiv=3)
    for dx in (-0.12, 0.0, 0.12):
        a.box((0.03, 0.04, 0.26), (dx, y - 0.13, TOP + 0.02), C["grain"], rot=(0, 0.5, 0))
    a.export()


@sign
def grain():
    """Grain [C]: a tied sheaf."""
    a = Asset("sign_grain", 306)
    pole(a, P["moss"])
    roundel(a, P["moss"])
    y = front(-0.04)
    for i in range(9):
        t = (i - 4) / 4.0
        a.cyl(0.018, 0.62, (t * 0.05, y, TOP - 0.34), C["straw"], rot=(0, t * 0.28, 0), segs=5)
        a.sphere(0.05, (t * 0.05 + math.sin(t * 0.28) * 0.62, y, TOP + 0.25), C["grain"], scale=(0.6, 0.6, 1.4), subdiv=1)
    a.box((0.16, 0.08, 0.05), (0, y, TOP - 0.1), P["oxblood"])
    a.export()


@sign
def wool():
    """Wool and old cloth [X]: a cream skein."""
    a = Asset("sign_wool", 307)
    pole(a, P["slate"])
    roundel(a, P["oxblood"])
    y = front(-0.05)
    for i in range(12):
        t = math.tau * i / 12
        a.sphere(0.075, (0.2 * math.cos(t), y, TOP + 0.2 * math.sin(t) * 0.8), P["cream"], subdiv=1)
    a.box((0.08, 0.1, 0.2), (0.0, y, TOP + 0.16), P["slate"])
    a.export()


@sign
def roots():
    """Roots and turnips [X]: a turnip with its leaves."""
    a = Asset("sign_roots", 308)
    pole(a, P["moss"])
    roundel(a, P["cream"])
    y = front(-0.06)
    a.sphere(0.2, (0, y, TOP - 0.06), P["turnip"], scale=(1.0, 0.8, 0.9), subdiv=2)
    a.sphere(0.13, (0, y, TOP - 0.2), P["cream"], scale=(1.0, 0.8, 0.8), subdiv=2)
    a.cyl(0.02, 0.12, (0, y, TOP - 0.38), P["cream"], segs=5, r2=0.002)
    for t in (-0.45, 0.0, 0.45):
        a.box((0.08, 0.03, 0.28), (math.sin(t) * 0.12, y, TOP + 0.24), P["leaf"], rot=(0, t, 0), bevel=0.01)
    a.export()


@sign
def tinker():
    """The tinker [C]: a kettle."""
    a = Asset("sign_tinker", 309)
    pole(a, P["slate"])
    roundel(a, P["ochre"])
    y = front(-0.06)
    a.cyl(0.22, 0.28, (0, y, TOP - 0.2), C["iron"], segs=14, r2=0.16, bevel=0.01)
    a.cyl(0.04, 0.22, (0.2, y, TOP - 0.12), C["iron"], rot=(0, 0.9, 0), segs=6, r2=0.02)
    for i in range(7):
        t = math.pi * i / 6
        a.box((0.04, 0.04, 0.04), (0.15 * math.cos(t), y, TOP + 0.1 + 0.13 * math.sin(t)), C["iron"])
    a.export()


@sign
def salt():
    """Salt [C]: a crock heaped white."""
    a = Asset("sign_salt", 310)
    pole(a, P["slate"])
    roundel(a, P["slate"])
    y = front(-0.06)
    a.cyl(0.2, 0.3, (0, y, TOP - 0.24), P["ochre"], segs=14, r2=0.23, bevel=0.01)
    a.cyl(0.24, 0.04, (0, y, TOP + 0.04), C["timber"], segs=14)
    a.sphere(0.22, (0, y, TOP + 0.08), C["salt"], scale=(1.0, 1.0, 0.55), subdiv=2)
    a.export()


@sign
def fingerpost():
    """The cottage fork's fingerpost: one arm, cut to a point, with a carved
    well and roof pictogram (Feyre can barely read; the picture says village).
    The arm points along Blender -Y (Godot +Z)."""
    a = Asset("sign_fingerpost", 311)
    a.cyl(0.07, 2.35, (0, 0, 0), C["timber_grey"], segs=8)
    a.cyl(0.09, 0.08, (0, 0, 2.35), C["timber"], segs=8, r2=0.03)
    a.box((0.07, 1.05, 0.24), (0, -0.5, 1.95), C["plank_old"], bevel=0.015)
    a.box((0.07, 0.24, 0.24), (0, -1.08, 1.95), C["plank_old"], rot=(math.pi / 4, 0, 0), bevel=0.01)
    a.box((0.1, 0.12, 0.16), (0, -0.62, 1.95), C["stone"])          # the well
    a.box((0.1, 0.18, 0.04), (0, -0.62, 2.05), C["timber"])
    a.box((0.1, 0.14, 0.12), (0, -0.36, 1.93), C["daub"])            # a house
    a.box((0.1, 0.17, 0.05), (0, -0.36, 2.02), P["oxblood"], rot=(0.0, 0, 0))
    a.box((0.09, 1.0, 0.04), (0, -0.48, 2.08), SNOW, bevel=0.015)
    a.box((0.1, 0.1, 0.06), (0, 0.0, 2.08), SNOW)
    a.snow_mound((0, 0, 0.0), 0.25, 0.12)
    a.export()


def _export_scaled(a):
    """Scales the emblem (everything above the crossbar) about its centre, so it
    reads across the square while the pole stays thin."""
    from mathutils import Vector
    c = Vector((POLE_X, POLE_Y, TOP))
    for v in a.bm.verts:
        if v.co.z > TOP - 0.7:
            v.co = c + (v.co - c) * EMBLEM_SCALE
    village_lib.Asset.export_plain(a)


if __name__ == "__main__":
    village_lib.Asset.export_plain = village_lib.Asset.export
    names = [n for n in sys.argv[1:] if n in SIGNS] or list(SIGNS)
    reset()
    for n in names:
        village_lib.Asset.export = _export_scaled if n != "sign_fingerpost" else village_lib.Asset.export_plain
        SIGNS[n]()
