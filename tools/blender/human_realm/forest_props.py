"""Small scatter props for the hunting forest and the wall seam: keepsakes,
notice-moment subjects (tracks, a robin, barked trees), wall-seam offerings,
iron stakes, cairns, bones, drifts.

Run: <bpyenv>/bin/python tools/blender/human_realm/forest_props.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import forest_kit as K  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
FOREST = os.path.join(ROOT, "world/human_realm/hunting_forest/assets/props")
SEAM = os.path.join(ROOT, "world/human_realm/wall_seam/assets/props")

PROPS = {}


def prop(folder):
    def deco(fn):
        PROPS[fn.__name__] = (folder, fn)
        return fn
    return deco


def _prints(points, size, color=(0.72, 0.76, 0.86), depth=0.03):
    for x, y, yaw, s in points:
        K.blob(size * s, (x, y, 0.0), (0.7, 1.0, depth / (size * s)), color, 1, 0.02, 0.05, (0, 0, yaw))


# --- hunting forest -------------------------------------------------------

@prop(FOREST)
def deer_tracks():
    """Cloven slots in the snow, a doe's walk across 3 m."""
    K.reset(101)
    pts = []
    for i in range(8):
        y = -1.5 + i * 0.42
        x = 0.1 * (1 if i % 2 else -1)
        pts.append((x - 0.02, y, 0.1, 1.0))
        pts.append((x + 0.02, y, 0.1, 1.0))
    _prints(pts, 0.035)
    K.export(os.path.join(FOREST, "deer_tracks.glb"))


@prop(FOREST)
def hare_tracks():
    """Hare bounds: two long hind prints ahead of two small fore prints."""
    K.reset(102)
    pts = []
    for i in range(5):
        y = -2 + i * 0.9
        pts += [(-0.06, y + 0.25, 0, 1.6), (0.06, y + 0.25, 0, 1.6), (0, y, 0, 0.8), (0.0, y - 0.1, 0, 0.8)]
    _prints(pts, 0.03)
    K.export(os.path.join(FOREST, "hare_tracks.glb"))


@prop(FOREST)
def wolf_tracks():
    """Paw prints far too big for a wolf, each wider than a hand. Uncanny."""
    K.reset(103)
    pts = []
    for i in range(6):
        y = -2.2 + i * 0.85
        x = 0.14 * (1 if i % 2 else -1)
        pts.append((x, y, 0, 1.0))
        for t in range(4):
            pts.append((x + (t - 1.5) * 0.05, y + 0.1 + (0.02 if t in (1, 2) else 0), 0, 0.35))
    _prints(pts, 0.09, (0.66, 0.70, 0.82), 0.05)
    K.export(os.path.join(FOREST, "wolf_tracks.glb"))


@prop(FOREST)
def fox_tracks():
    """A fox's neat single-file line."""
    K.reset(104)
    _prints([(0.01 * (i % 2), -2 + i * 0.3, 0, 1.0) for i in range(14)], 0.025)
    K.export(os.path.join(FOREST, "fox_tracks.glb"))


@prop(FOREST)
def barked_trunk():
    """Bark stripped by deer: a pale wound on a trunk stub at browse height."""
    K.reset(105)
    K.cyl(0.24, 2.2, (0, 0, 0), color=K.BARK, verts=8, r2=0.2)
    K.box((0.18, 0.12, 0.6), (0, -0.2, 0.7), color=(0.80, 0.72, 0.55))
    K.box((0.12, 0.12, 0.35), (0.08, -0.19, 1.35), color=(0.76, 0.66, 0.50))
    K.cyl(0.25, 0.08, (0, 0, 2.2), color=K.SNOW, verts=8)
    K.export(os.path.join(FOREST, "barked_trunk.glb"))


@prop(FOREST)
def robin_on_stump():
    """A robin on a snowy stump: one warm red breast in the grey."""
    K.reset(106)
    K.cyl(0.32, 0.55, (0, 0, 0), color=K.BARK, verts=9, r2=0.28)
    K.cyl(0.3, 0.07, (0, 0, 0.55), color=K.SNOW, verts=9)
    K.blob(0.07, (0, 0, 0.7), (1.0, 1.25, 1.0), (0.42, 0.34, 0.26), 1)
    K.blob(0.055, (0, -0.045, 0.69), (1.0, 0.6, 0.9), K.ROBIN_RED, 1)
    K.blob(0.04, (0, -0.06, 0.78), color=(0.42, 0.34, 0.26))
    K.cyl(0.01, 0.03, (0, -0.1, 0.78), (1.57, 0, 0), (0.1, 0.1, 0.1), 4, 0.0)
    K.box((0.05, 0.1, 0.015), (0, 0.1, 0.72), (-0.4, 0, 0), (0.35, 0.28, 0.22))
    K.export(os.path.join(FOREST, "robin_on_stump.glb"))


@prop(FOREST)
def snare():
    """A wire snare on a bent sapling over a run: someone else's, or hers."""
    K.reset(107)
    K.stick((0, 0, 0), (0.1, 0, 0.9), 0.02, K.WOOD, 4)
    K.stick((0.1, 0, 0.9), (0.5, 0, 0.6), 0.015, K.WOOD, 4)
    K.torus(0.08, 0.006, (0.5, 0, 0.25), (0, 1.57, 0), K.TIN, 10, 3)
    K.stick((0.5, 0, 0.6), (0.5, 0, 0.33), 0.004, K.TIN, 3)
    K.cyl(0.02, 0.3, (0.75, 0, 0), color=K.WOOD, verts=4)
    K.export(os.path.join(FOREST, "snare.glb"))


@prop(FOREST)
def birch_bark_curl():
    """Peeling curls of birch bark at a birch's foot."""
    K.reset(108)
    r = K.rng()
    for _ in range(4):
        K.cyl(0.06, 0.25, (r.uniform(-0.2, 0.2), r.uniform(-0.2, 0.2), 0.05), (1.57, 0, r.uniform(0, 3)), (0.92, 0.90, 0.86), 7)
        K.box((0.02, 0.1, 0.02), (r.uniform(-0.2, 0.2), r.uniform(-0.2, 0.2), 0.05), color=(0.15, 0.13, 0.12))
    K.export(os.path.join(FOREST, "birch_bark_curl.glb"))


@prop(FOREST)
def broken_arrow():
    """Someone's lost arrow, snapped: grey goose fletching."""
    K.reset(109)
    K.stick((-0.3, 0, 0.02), (0.15, 0.02, 0.03), 0.006, K.WOOD_PALE, 4)
    K.stick((0.2, 0.05, 0.02), (0.38, 0.1, 0.02), 0.006, K.WOOD_PALE, 4)
    K.box((0.1, 0.002, 0.03), (-0.25, 0, 0.02), color=(0.6, 0.6, 0.62))
    K.box((0.04, 0.012, 0.012), (0.42, 0.11, 0.015), (0, 0, 0.3), K.IRON)
    K.export(os.path.join(FOREST, "broken_arrow.glb"))


@prop(FOREST)
def lost_button():
    """A horn button from a good coat, from the family's old life perhaps."""
    K.reset(110)
    K.cyl(0.02, 0.006, (0, 0, 0), color=(0.55, 0.42, 0.28), verts=10)
    K.blob(0.08, (0, 0, -0.03), (1.4, 1.4, 0.4), K.SNOW, 1)
    K.export(os.path.join(FOREST, "lost_button.glb"))


@prop(FOREST)
def horn_fragment():
    """A cracked brass-bound hunting horn from the old lords' hunts."""
    K.reset(111)
    K.cyl(0.05, 0.4, (0, 0, 0.05), (0, 1.57, 0.2), K.BONE, 8, 0.015)
    K.torus(0.05, 0.008, (0.0, 0, 0.05), (0, 1.57, 0.2), (0.62, 0.48, 0.22), 10, 3)
    K.export(os.path.join(FOREST, "horn_fragment.glb"))


@prop(FOREST)
def rusty_spur():
    K.reset(112)
    K.torus(0.05, 0.007, (0, 0, 0.01), color=K.RUST, major=10, minor=3)
    K.stick((0.05, 0, 0.01), (0.12, 0, 0.01), 0.006, K.RUST, 4)
    K.cyl(0.02, 0.004, (0.13, 0, 0.0), (1.57, 0, 0), K.RUST, 8)
    K.export(os.path.join(FOREST, "rusty_spur.glb"))


@prop(FOREST)
def bone_token():
    """A carved bone token: a little stag, someone's charm."""
    K.reset(113)
    K.cyl(0.03, 0.01, (0, 0, 0), color=K.BONE, verts=8)
    K.box((0.02, 0.004, 0.012), (0, 0, 0.01), color=(0.4, 0.3, 0.25))
    K.stick((0.03, 0, 0.005), (0.07, 0.01, 0.005), 0.002, LEATHER_CORD, 3)
    K.export(os.path.join(FOREST, "bone_token.glb"))


@prop(FOREST)
def pamphlet():
    """A Children of the Blessed pamphlet, damp and frozen to the snow."""
    K.reset(114)
    K.box((0.16, 0.22, 0.004), (0, 0, 0), (0, 0, 0.3), K.PAPER)
    K.box((0.1, 0.02, 0.002), (0, 0.06, 0.004), (0, 0, 0.3), (0.3, 0.3, 0.35))
    K.box((0.08, 0.08, 0.002), (0, -0.03, 0.004), (0, 0, 0.3), (0.55, 0.5, 0.25))  # the sun-and-fae woodcut
    K.export(os.path.join(FOREST, "pamphlet.glb"))


@prop(FOREST)
def frozen_ribbon():
    """A ribbon frozen stiff on a twig: ribbon offerings drift south too."""
    K.reset(115)
    K.stick((0, 0, 0), (0.05, 0, 0.6), 0.008, K.BARK, 4)
    K.box((0.03, 0.004, 0.35), (0.04, 0.01, 0.15), (0.2, 0, 0.3), K.CLOTH_RED)
    K.export(os.path.join(FOREST, "frozen_ribbon.glb"))


@prop(FOREST)
def antler_rub():
    """A sapling thrashed by a stag: frayed bark strips (look)."""
    K.reset(116)
    K.cyl(0.06, 1.6, (0, 0, 0), color=K.BARK, verts=6, r2=0.03)
    for z in (0.4, 0.6, 0.8):
        K.box((0.03, 0.01, 0.2), (0.05, 0.03, z), (0.3, 0, 0.5), (0.80, 0.72, 0.55))
    K.export(os.path.join(FOREST, "antler_rub.glb"))


# --- wall seam ------------------------------------------------------------

@prop(SEAM)
def warning_cairn():
    K.reset(201)
    z = 0.0
    r = 0.5
    while r > 0.12:
        K.blob(r, (K.rng().uniform(-0.05, 0.05), 0, z + r * 0.6), (1.2, 1.1, 0.75), K.STONE, 1)
        z += r * 1.0
        r *= 0.72
    K.blob(0.15, (0, 0, z + 0.05), (1.3, 1.3, 0.4), K.SNOW, 1)
    K.export(os.path.join(SEAM, "warning_cairn.glb"))


@prop(SEAM)
def iron_stake():
    """One of the villagers' iron stakes, driven in at a slant toward the Wall."""
    K.reset(202)
    K.cyl(0.03, 1.3, (0, 0, -0.2), (0.25, 0, 0), K.IRON, 5, 0.012)
    K.box((0.08, 0.08, 0.04), (0, 0.27, 0.95), (0.25, 0, 0), K.RUST)
    K.box((0.07, 0.1, 0.03), (0, 0.0, 0.0), color=(0.55, 0.30, 0.18))  # rust bloom in the snow
    K.export(os.path.join(SEAM, "iron_stake.glb"))


@prop(SEAM)
def offering_bundle():
    """A frozen offering: a straw doll and a heel of bread in a cloth."""
    K.reset(203)
    K.box((0.3, 0.3, 0.02), (0, 0, 0), (0, 0, 0.4), K.CLOTH_CREAM)
    K.blob(0.07, (0.03, 0.02, 0.05), (1.4, 1, 0.7), (0.62, 0.45, 0.25))
    K.cyl(0.025, 0.2, (-0.07, -0.03, 0.02), (1.4, 0, 0.6), K.STRAW, 6)
    K.blob(0.035, (-0.14, -0.07, 0.04), color=K.STRAW)
    K.export(os.path.join(SEAM, "offering_bundle.glb"))


@prop(SEAM)
def lost_boot():
    """A single boot, stiff with frost, toes pointing at the Wall."""
    K.reset(204)
    K.box((0.12, 0.28, 0.08), (0, 0, 0), color=K.LEATHER, bevel=0.03)
    K.cyl(0.07, 0.24, (0, 0.09, 0.05), (0.2, 0, 0), K.LEATHER, 8)
    K.cyl(0.075, 0.03, (0, 0.14, 0.27), (0.2, 0, 0), K.SNOW, 8)
    K.export(os.path.join(SEAM, "lost_boot.glb"))


@prop(SEAM)
def candle_stub():
    K.reset(205)
    for x, h in ((0, 0.12), (0.06, 0.07), (-0.05, 0.05)):
        K.cyl(0.02, h, (x, 0, 0), color=K.CLOTH_CREAM, verts=7)
    K.blob(0.08, (0, 0, -0.01), (1.3, 1.3, 0.2), (0.85, 0.80, 0.68), 1)  # wax pool
    K.export(os.path.join(SEAM, "candle_stub.glb"))


@prop(SEAM)
def child_mitten():
    """A child's knitted mitten. Someone came too close."""
    K.reset(206)
    K.blob(0.05, (0, 0, 0.015), (1.0, 1.5, 0.35), CLOTH_RUST_WOOL, 1)
    K.blob(0.02, (0.045, 0.02, 0.015), (1, 1.4, 0.5), CLOTH_RUST_WOOL, 1)
    K.export(os.path.join(SEAM, "child_mitten.glb"))


@prop(SEAM)
def tin_charm():
    """A tin charm against the fae, an iron nail through it."""
    K.reset(207)
    K.cyl(0.035, 0.004, (0, 0, 0), color=K.TIN, verts=6)
    K.stick((0, 0, 0.0), (0.0, 0.0, 0.07), 0.004, K.IRON, 4)
    K.export(os.path.join(SEAM, "tin_charm.glb"))


@prop(SEAM)
def deer_bones():
    """A deer's ribcage and skull picked clean, half under snow."""
    K.reset(208)
    r = K.rng()
    K.stick((-0.5, 0, 0.08), (0.5, 0, 0.12), 0.03, K.BONE, 5)
    for i in range(7):
        x = -0.35 + i * 0.11
        for s in (-1, 1):
            K.stick((x, 0, 0.12), (x + 0.03, s * 0.22, 0.04 + r.uniform(0, 0.1)), 0.012, K.BONE, 4)
    K.blob(0.08, (0.68, 0.05, 0.06), (1.6, 0.9, 0.8), K.BONE, 1)
    K.blob(0.3, (-0.2, 0.15, 0.0), (1.6, 1.0, 0.25), K.SNOW, 1)
    K.export(os.path.join(SEAM, "deer_bones.glb"))


@prop(SEAM)
def tracks_end():
    """Fox tracks that come up to the Wall's line and turn back."""
    K.reset(209)
    pts = [(0.01 * (i % 2), 2.0 - i * 0.3, 0, 1.0) for i in range(8)]
    pts += [(0.15 + 0.3 * i, -0.4 + 0.3 * i, 0.8, 1.0) for i in range(5)]
    pts += [(0.05, -0.35, 0, 1.4), (0.1, -0.3, 0.5, 1.3)]  # the scuffed hesitation
    _prints(pts, 0.026)
    K.export(os.path.join(SEAM, "tracks_end.glb"))


@prop(SEAM)
def snow_drift():
    """A long drift banked against nothing: snow piled against the Wall's
    invisible line. 4 m long along X, flat face on -Y (north)."""
    K.reset(210)
    r = K.rng()
    for i in range(6):
        x = -1.8 + i * 0.72
        K.blob(0.9, (x, 0.35, 0.0), (1.0, 0.9, 0.85 + r.uniform(-0.15, 0.2)), K.SNOW, 2, 0.02, 0.06)
    K.box((4.3, 0.12, 1.1), (0, -0.4, -0.2), color=(0.88, 0.91, 0.97), jitter=0.02)
    K.export(os.path.join(SEAM, "snow_drift.glb"))


@prop(SEAM)
def salt_ring():
    """A ring of grey salt and ash crusted on the snow: a villager's ward."""
    K.reset(211)
    for p in K.ring_points(14, 0.6, 0.1):
        K.blob(0.08, (p[0], p[1], 0.0), (1.4, 1.0, 0.25), (0.62, 0.62, 0.64), 1)
    K.export(os.path.join(SEAM, "salt_ring.glb"))


LEATHER_CORD = (0.25, 0.17, 0.11)
CLOTH_RUST_WOOL = (0.58, 0.24, 0.16)

if __name__ == "__main__":
    for name, (_, fn) in PROPS.items():
        fn()
