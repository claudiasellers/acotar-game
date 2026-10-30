"""Hero landmarks of the winter hunting forest and the wall seam.

Run: <bpyenv>/bin/python tools/blender/human_realm/forest_landmarks.py
Writes .glb (+ .collision.json) under world/human_realm/hunting_forest/assets/
and world/human_realm/wall_seam/assets/.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import forest_kit as K  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
FOREST = os.path.join(ROOT, "world/human_realm/hunting_forest/assets")
SEAM = os.path.join(ROOT, "world/human_realm/wall_seam/assets")


def snow_cap(x, y, z, sx, sy, rot=0.0):
    K.box((sx + 0.08, sy + 0.08, 0.14), (x, y, z), (0, 0, rot), K.SNOW, 0.02, bevel=0.05)


def lodge_ruin():
    """The old noble hunting lodge: two-storey stone shell, gable end still
    standing, roof fallen in, chimney stack, rubble and fallen beams."""
    K.reset(11)
    W, D, T = 16.0, 10.0, 0.7
    r = K.rng()
    # Long walls (front y=-D/2 with a door gap and windows, back y=+D/2), broken tops.
    for side in (-1, 1):
        y = side * D / 2
        x = -W / 2
        segs = [(2.5, 6.5), (1.2, 3.0), (2.6, 5.8), (1.6, 2.2), (3.0, 4.9), (1.2, 2.8), (3.9, 3.6)] if side < 0 else \
               [(3.4, 5.6), (1.0, 4.4), (4.0, 3.2), (2.2, 1.6), (5.4, 4.2)]
        for i, (length, height) in enumerate(segs):
            gap = side < 0 and i in (1, 3, 5)  # door + windows: low sill only
            h = 0.9 if gap and i != 3 else (0.15 if gap else height)
            if not gap or h > 0.2:
                K.box((length, T, h), (x + length / 2, y, 0), color=K.STONE, grad=0.35, bevel=0.06, collide=True)
                snow_cap(x + length / 2, y, h, length, T)
            if gap and i != 3:
                # lintel over windows on the upper part
                K.box((length, T, 0.4), (x + length / 2, y, 2.6), color=K.STONE_DARK, bevel=0.04)
                K.box((length, T, 0.9), (x + length / 2, y, 3.0), color=K.STONE, grad=0.2, bevel=0.06, collide=True)
            x += length
    # Gable end (east, x=+W/2): stepped, crumbling, tall.
    steps = [(D, 6.0), (D * 0.8, 1.2), (D * 0.6, 1.1), (D * 0.4, 1.0), (D * 0.18, 0.9)]
    z = 0.0
    for width, h in steps:
        K.box((T, width, h), (W / 2, r.uniform(-0.2, 0.2) if z > 0 else 0, z), color=K.STONE, grad=0.3 if z == 0 else 0.0, bevel=0.06, collide=True)
        z += h
    snow_cap(W / 2, 0, z, T, D * 0.18)
    # West end: collapsed to a stub, with the chimney stack.
    K.box((T, D * 0.6, 2.2), (-W / 2, -D * 0.2, 0), color=K.STONE, grad=0.3, bevel=0.06, collide=True)
    snow_cap(-W / 2, -D * 0.2, 2.2, T, D * 0.6)
    K.box((1.6, 1.6, 9.5), (-W / 2 - 0.2, D * 0.3, 0), color=K.STONE_DARK, grad=0.25, bevel=0.08, collide=True)
    K.box((1.2, 1.2, 0.5), (-W / 2 - 0.2, D * 0.3, 9.5), color=K.CHAR, bevel=0.04)
    K.box((1.0, 0.5, 1.0), (-W / 2 + 0.6, D * 0.3, 0.0), color=K.CHAR)  # hearth mouth
    # Floor: frozen flagstones with snow drifted in.
    K.box((W - 0.6, D - 0.6, 0.12), (0, 0, 0), color=K.STONE_DARK, jitter=0.12)
    for _ in range(9):
        K.blob(r.uniform(0.8, 2.0), (r.uniform(-6, 6), r.uniform(-3.5, 3.5), 0.0), (1.4, 1.0, 0.35), K.SNOW, 1)
    # Collapsed roof: rafters sliding in from the walls, a ridge beam on the floor.
    for i in range(7):
        x = -6.0 + i * 2.0 + r.uniform(-0.3, 0.3)
        if i % 3 == 1:
            continue
        top = (x + r.uniform(-0.5, 0.5), D / 2 - 0.3, r.uniform(3.6, 5.2))
        bot = (x + r.uniform(-1.0, 1.0), r.uniform(-1.5, 1.0), 0.1)
        K.stick(top, bot, 0.14, K.WOOD_ROT, 5)
    for i in range(3):
        x = -4.0 + i * 3.5
        K.stick((x, -D / 2 + 0.3, r.uniform(3.0, 4.5)), (x + r.uniform(-1, 1), r.uniform(-0.5, 1.2), 0.1), 0.13, K.CHAR, 5)
    K.stick((-6.5, 0.6, 0.25), (7.0, -0.8, 1.6), 0.2, K.WOOD_ROT, 6)  # ridge beam
    # Slate heaps and rubble, inside and out.
    for _ in range(14):
        x, y = r.uniform(-7, 7), r.uniform(-4, 4)
        K.box((r.uniform(0.6, 1.4), r.uniform(0.4, 1.0), r.uniform(0.15, 0.4)), (x, y, 0.1), (0.2, 0.1, r.uniform(0, 3)), K.STONE_DARK, 0.1)
    for _ in range(16):
        a = r.uniform(0, math.tau)
        d = r.uniform(0.0, 1.0)
        x = math.cos(a) * (W / 2 + 1.0 + d * 2.5)
        y = math.sin(a) * (D / 2 + 1.0 + d * 2.0)
        K.blob(r.uniform(0.25, 0.7), (x, y, 0.1), (1.2, 1.0, 0.7), K.STONE, 1)
    # A rotted door hanging off the gap.
    K.box((1.1, 0.08, 2.1), (-W / 2 + 3.2, -D / 2 - 0.5, 0), (0.15, 0, 0.6), K.WOOD_ROT)
    # Antler trophy mount over the gable door -- the old lords' vanity.
    K.box((0.5, 0.12, 0.6), (W / 2 - 0.45, 0, 4.0), color=K.WOOD)
    for s in (-1, 1):
        K.stick((W / 2 - 0.5, s * 0.1, 4.4), (W / 2 - 0.7, s * 0.7, 5.2), 0.04, K.BONE, 5)
        K.stick((W / 2 - 0.6, s * 0.45, 4.8), (W / 2 - 0.8, s * 0.55, 5.3), 0.03, K.BONE, 5)
    K.export(os.path.join(FOREST, "lodge_ruin.glb"))


def boundary_wall_section():
    """12 m of the old hunting grounds' dry-stone boundary wall."""
    K.reset(12)
    r = K.rng()
    L = 12.0
    x = -L / 2
    while x < L / 2 - 0.1:
        seg = min(r.uniform(1.4, 2.6), L / 2 - x)
        h = r.uniform(1.25, 1.6)
        K.box((seg + 0.05, 0.75, h), (x + seg / 2, 0, 0), (0, 0, r.uniform(-0.03, 0.03)), K.MOSS_STONE if r.random() < 0.3 else K.STONE, 0.1, 0.35, 0.08)
        K.box((seg, 0.85, 0.18), (x + seg / 2, 0, h), color=K.SNOW, jitter=0.02, bevel=0.06)
        x += seg
    for _ in range(6):
        K.blob(r.uniform(0.18, 0.35), (r.uniform(-L / 2, L / 2), r.choice((-0.6, 0.6)), 0.05), (1.3, 1, 0.6), K.STONE)
    K.col_box((0, 0, 0.8), (L, 0.8, 1.6))
    K.export(os.path.join(FOREST, "boundary_wall_section.glb"))


def boundary_wall_end():
    """A broken wall end where the old wall has a gap: tumbled stones."""
    K.reset(13)
    r = K.rng()
    for i in range(4):
        h = 1.4 - i * 0.32
        K.box((1.2, 0.75, h), (i * 1.1, 0, 0), color=K.STONE, grad=0.3, bevel=0.08)
        K.box((1.2, 0.85, 0.14), (i * 1.1, 0, h), color=K.SNOW, bevel=0.05)
    for _ in range(10):
        K.blob(r.uniform(0.2, 0.45), (r.uniform(1.5, 5.0), r.uniform(-1.2, 1.2), 0.0), (1.2, 1, 0.65), K.STONE)
    K.col_box((1.6, 0, 0.6), (4.0, 0.8, 1.2))
    K.export(os.path.join(FOREST, "boundary_wall_end.glb"))


def deer_stand():
    """A rotted high seat on four leaning posts, its ladder half fallen."""
    K.reset(14)
    tilt = 0.12
    legs = [(-0.9, -0.9), (0.9, -0.9), (0.9, 0.9), (-0.9, 0.9)]
    for lx, ly in legs:
        K.stick((lx * 1.3, ly * 1.3, 0), (lx + tilt, ly, 4.2), 0.11, K.WOOD_ROT, 6)
    K.box((2.2, 2.2, 0.12), (tilt, 0, 4.1), (0.06, -0.04, 0), K.WOOD_ROT, 0.1)
    K.box((2.25, 2.25, 0.12), (tilt, 0, 4.22), (0.06, -0.04, 0), K.SNOW)
    for s in (-1, 1):  # rails, one broken
        K.stick((s * 1.0 + tilt, -1.0, 4.2), (s * 1.0 + tilt, 1.0 if s < 0 else 0.1, 5.1), 0.05, K.WOOD_ROT, 5)
    K.stick((tilt - 1.0, 1.0, 5.1), (tilt + 1.0, 1.0, 5.0), 0.05, K.WOOD_ROT, 5)
    # Ladder lying against it, one rail snapped.
    K.stick((-0.7, -2.6, 0), (-0.5, -1.0, 4.0), 0.05, K.WOOD, 5)
    K.stick((0.5, -2.6, 0), (0.4, -1.8, 2.0), 0.05, K.WOOD, 5)
    for i in range(6):
        t = i / 6.0
        K.stick((-0.7 + 0.2 * t, -2.6 + 1.6 * t, 4.0 * t + 0.3), (0.5 - 0.1 * t, -2.6 + 1.6 * t, 4.0 * t + 0.3), 0.03, K.WOOD, 4)
    K.col_box((tilt, 0, 4.1), (2.2, 2.2, 0.3))
    for lx, ly in legs:
        K.col_box((lx * 1.15, ly * 1.15, 2.0), (0.25, 0.25, 4.0))
    K.export(os.path.join(FOREST, "deer_stand.glb"))


def woodcutter_leanto():
    """The woodcutter's abandoned lean-to: pole frame, bough roof heavy with
    snow, a chopping block with a rusted axe, a collapsed woodpile, dead fire."""
    K.reset(15)
    r = K.rng()
    for x in (-1.6, 1.6):
        K.stick((x, 1.2, 0), (x, 1.2, 2.2), 0.08, K.WOOD)
        K.stick((x, -1.4, 0), (x, 1.2, 2.1), 0.06, K.WOOD)
    K.stick((-1.9, 1.2, 2.15), (1.9, 1.2, 2.15), 0.07, K.WOOD)
    for i in range(9):
        x = -1.6 + i * 0.4
        K.stick((x, 1.3, 2.2), (x + r.uniform(-0.1, 0.1), -1.5, 0.1), 0.05, K.BARK, 4)
    K.box((3.6, 3.0, 0.25), (0, -0.1, 1.05), (-0.72, 0, 0), K.SNOW, 0.03, bevel=0.1)
    K.box((3.4, 0.2, 0.06), (0, 0.4, 0.0), color=(0.25, 0.30, 0.22))  # old bracken bed
    # Chopping block and axe.
    K.cyl(0.32, 0.55, (2.6, -1.4, 0), color=K.WOOD_PALE, verts=10)
    K.cyl(0.33, 0.06, (2.6, -1.4, 0.55), color=K.SNOW, verts=10)
    K.stick((2.5, -1.4, 0.55), (2.9, -1.0, 1.25), 0.03, K.WOOD, 5)
    K.box((0.25, 0.04, 0.18), (2.5, -1.45, 0.52), (0, 0, 0.8), K.RUST)
    # Woodpile slumped against the frame.
    for i in range(12):
        K.stick((-2.6 + r.uniform(-0.2, 0.2), -0.6 + (i % 4) * 0.28, 0.12 + (i // 4) * 0.24),
                (-1.9, -0.6 + (i % 4) * 0.28, 0.12 + (i // 4) * 0.24), 0.11, K.WOOD_PALE, 6)
    # Dead fire ring.
    for p in K.ring_points(8, 0.55):
        K.blob(0.16, (p[0] + 0.4, p[1] - 2.6, 0.05), (1.2, 1, 0.8), K.STONE_DARK, 1)
    K.blob(0.35, (0.4, -2.6, 0.0), (1.2, 1.2, 0.25), K.CHAR, 1)
    K.col_box((0, 0, 1.0), (3.4, 2.6, 2.0))
    K.export(os.path.join(FOREST, "woodcutter_leanto.glb"))


def split_oak():
    """A lightning-split oak: the trunk torn in two, halves splayed, the heart
    charred black, one half still carrying bare limbs."""
    K.reset(16)
    r = K.rng()
    K.cyl(1.2, 1.2, (0, 0, 0), color=K.BARK, verts=10, r2=0.95, grad=0.3)
    for side in (-1, 1):
        lean = side * 0.28
        K.cyl(0.62, 7.0 if side < 0 else 5.2, (side * 0.45, 0, 0.9), (0, lean, 0), K.BARK, 8, 0.38, grad=0.2)
        K.cyl(0.32, 6.6 if side < 0 else 4.8, (side * 0.3, 0, 1.0), (0, lean, 0), K.CHAR, 6, 0.18)
    tip = (-2.4, 0, 7.4)
    for i in range(5):
        a = r.uniform(0, math.tau)
        K.stick((tip[0] * 0.8, 0, 6.0), (tip[0] + math.cos(a) * 2.8, math.sin(a) * 2.8, 7.0 + r.uniform(0.5, 2.5)), 0.14, K.BARK, 5, 0.04)
    for i in range(3):
        a = r.uniform(0, math.tau)
        K.stick((1.6, 0, 4.6), (2.0 + math.cos(a) * 1.8, math.sin(a) * 1.8, 5.5 + r.uniform(0, 1.2)), 0.1, K.BARK, 5, 0.03)
    K.stick((2.2, 1.0, 0.2), (6.5, 3.0, 0.5), 0.35, K.BARK, 7, 0.2)  # the limb that fell
    for _ in range(4):
        K.blob(0.5, (r.uniform(2, 6), r.uniform(0.5, 3), 0.1), (1.5, 1, 0.4), K.SNOW, 1)
    K.col_box((0, 0, 2.5), (2.2, 1.6, 5.0))
    K.export(os.path.join(FOREST, "split_oak.glb"))


def frozen_fall():
    """A small fall on the creek frozen mid-pour: a mossy rock lip, columns of
    blue ice, icicle fringe, a frozen plunge pool."""
    K.reset(17)
    r = K.rng()
    for x in (-3.2, -1.8, 1.8, 3.4):
        K.blob(1.3, (x, 0.6, 0.8), (1.0, 1.2, 1.1), K.MOSS_STONE if x < 0 else K.STONE, 1)
    K.box((5.0, 2.4, 1.6), (0, 1.6, 0), color=K.STONE_DARK, grad=0.3, bevel=0.3, collide=True)
    K.box((5.2, 2.6, 0.2), (0, 1.6, 1.6), color=K.SNOW, bevel=0.08)
    for i in range(11):
        x = -2.2 + i * 0.44 + r.uniform(-0.1, 0.1)
        h = r.uniform(1.2, 1.7)
        K.cyl(r.uniform(0.14, 0.3), h, (x, 0.35, 1.7 - h), color=K.ICE, verts=6, r2=r.uniform(0.05, 0.12), smooth=True)
    for i in range(16):
        x = -2.4 + i * 0.32
        K.cyl(0.06, r.uniform(0.3, 0.9), (x, 0.3, 1.6), (math.pi, 0, 0), K.ICE, 5, 0.0)
    K.blob(2.6, (0, -1.8, 0.0), (1.2, 0.8, 0.06), K.ICE_DEEP, 2, 0.04, 0.02)  # pool
    K.blob(2.8, (0, -1.8, -0.05), (1.25, 0.85, 0.08), K.SNOW, 2, 0.02, 0.02)
    K.export(os.path.join(FOREST, "frozen_fall.glb"))


def _ash_wall_run(length, h, r):
    K.box((length, 0.9, h), (0, 0, 0), color=K.MOSS_STONE if r.random() < 0.35 else K.STONE, jitter=0.1, grad=0.4, bevel=0.08)
    K.box((length + 0.04, 1.0, 0.16), (0, 0, h), color=K.SNOW, jitter=0.02, bevel=0.06)


def ash_wall_segment():
    """One 3.6 m run of the walled ash grove's high wall (local X along the
    wall). The generator rings ASH_GROVE with these (radius 40 m)."""
    K.reset(18)
    r = K.rng()
    _ash_wall_run(3.6, 3.4, r)
    K.box((0.5, 0.35, 2.7), (0, 0.55, 0), color=K.STONE_DARK, bevel=0.05)  # buttress (outside = +Y)
    K.col_box((0, 0, 1.7), (3.6, 0.9, 3.4))
    K.export(os.path.join(FOREST, "ash_wall_segment.glb"))


def ash_wall_slump():
    """The slumped stretch: the wall top has fallen to 1.7 m and the stones
    make a ramp on the outside. A careful climber gets over here."""
    K.reset(32)
    r = K.rng()
    _ash_wall_run(3.6, 1.7, r)
    for k in range(7):
        K.blob(r.uniform(0.4, 0.7), (r.uniform(-1.5, 1.5), 0.8 + k * 0.18, 0.1 + (6 - k) * 0.18), (1.3, 1.0, 0.8), K.STONE)
    K.blob(0.9, (0, 1.6, 0.0), (1.6, 1.2, 0.4), K.SNOW, 1)
    K.col_box((0, 0, 0.85), (3.6, 0.9, 1.7))
    K.export(os.path.join(FOREST, "ash_wall_slump.glb"))


def ash_gate():
    """The ash grove's one gate: two piers and a locked, chained iron gate.
    6 m wide along local X, outside = +Y."""
    K.reset(33)
    for s in (-1, 1):
        K.box((1.2, 1.2, 4.2), (s * 2.3, 0, 0), color=K.STONE_DARK, bevel=0.1, collide=True)
        K.blob(0.45, (s * 2.3, 0, 4.45), (1, 1, 0.9), K.STONE, 1)
    for i in range(13):
        x = -1.6 + i * 0.27
        K.cyl(0.035, 3.3, (x, 0, 0.05), color=K.IRON, verts=5)
        K.cyl(0.05, 0.25, (x, 0, 3.35), color=K.IRON, verts=4, r2=0.0)
    for z in (0.5, 1.7, 3.0):
        K.stick((-1.75, 0, z), (1.75, 0, z), 0.045, K.IRON, 5)
    for k in range(5):
        K.torus(0.07, 0.018, (-0.25 + k * 0.12, 0.08, 1.6 + (k % 2) * 0.05), (1.57 * (k % 2), 0, 0), K.RUST, 8, 4)
    K.box((0.22, 0.12, 0.26), (0.12, 0.12, 1.4), color=K.RUST, bevel=0.03)  # padlock
    K.col_box((0, 0, 1.7), (3.6, 0.3, 3.4))
    K.export(os.path.join(FOREST, "ash_gate.glb"))


def water_grate(broken=False):
    """Where the frozen creek runs under the ash grove wall: an arch with an
    iron grate. The broken one has two bars bent apart, a gap to squeeze
    through (the way in that the keeper doesn't know about)."""
    K.reset(34 + int(broken))
    r = K.rng()
    for s in (-1, 1):
        K.box((1.4, 1.1, 3.6), (s * 4.3, 0, -1.2), color=K.STONE, grad=0.3, bevel=0.08, collide=True)
    K.box((10.0, 0.9, 1.8), (0, 0, 1.6), color=K.STONE, grad=0.2, bevel=0.08, collide=True)
    K.box((10.04, 1.0, 0.16), (0, 0, 3.4), color=K.SNOW, bevel=0.06)
    for i in range(14):
        x = -3.4 + i * 0.52
        if broken and i in (6, 7):
            K.stick((x, 0, -1.2), (x + (-0.5 if i == 6 else 0.5), 0.3, 0.6), 0.04, K.RUST, 5)
            continue
        K.cyl(0.04, 2.9, (x, 0, -1.2), color=K.RUST if broken else K.IRON, verts=5)
    K.stick((-3.6, 0, 1.4), (3.6, 0, 1.4), 0.05, K.IRON, 5)
    for _ in range(8):
        K.cyl(0.05, r.uniform(0.3, 0.7), (r.uniform(-3.5, 3.5), r.choice((-0.5, 0.5)), 1.6), (math.pi, 0, 0), K.ICE, 5, 0.0)
    if not broken:
        K.col_box((0, 0, 0.2), (7.2, 0.3, 2.8))
    K.export(os.path.join(FOREST, "water_grate_broken.glb" if broken else "water_grate.glb"))


def gamekeeper_hut():
    """The ash grove keeper's hut: low stone and timber, one lit window,
    smoke-stained chimney, a woodstack and a bench by the door."""
    K.reset(24)
    K.box((5.0, 4.0, 2.4), (0, 0, 0), color=K.STONE, grad=0.3, bevel=0.06, collide=True)
    for s in (-1, 1):
        K.box((5.6, 2.6, 0.22), (0, s * 1.15, 2.35), (s * 0.62, 0, 0), K.WOOD_ROT, bevel=0.03)
        K.box((5.7, 2.7, 0.16), (0, s * 1.2, 2.5), (s * 0.62, 0, 0), K.SNOW, 0.02, bevel=0.05)
    K.box((0.8, 0.8, 4.4), (1.9, 1.0, 0), color=K.STONE_DARK, bevel=0.05)
    K.box((0.9, 0.06, 1.8), (-0.8, -2.02, 0), color=K.WOOD)
    K.box((0.7, 0.06, 0.6), (1.2, -2.02, 1.1), color=(1.0, 0.72, 0.35), jitter=0.0)
    K.box((1.6, 0.4, 0.45), (-0.8, -2.5, 0), color=K.WOOD_PALE)
    for i in range(10):
        K.stick((-2.9, -1.6 + (i % 5) * 0.32, 0.15 + (i // 5) * 0.3),
                (-2.6, -1.6 + (i % 5) * 0.32, 0.15 + (i // 5) * 0.3), 0.13, K.WOOD_PALE, 6)
    K.export(os.path.join(FOREST, "gamekeeper_hut.glb"))


def lantern_post():
    """A guard's lantern on a post: warm light in the blue snow (stealth)."""
    K.reset(25)
    K.cyl(0.09, 2.6, (0, 0, 0), color=K.WOOD_ROT, verts=6)
    K.stick((0, 0, 2.5), (0.5, 0, 2.5), 0.04, K.IRON, 5)
    K.box((0.24, 0.24, 0.32), (0.5, 0, 2.05), color=(1.0, 0.78, 0.40), jitter=0.0)
    K.box((0.3, 0.3, 0.06), (0.5, 0, 2.37), color=K.IRON)
    K.cyl(0.1, 0.06, (0, 0, 2.6), color=K.SNOW, verts=6)
    K.export(os.path.join(FOREST, "lantern_post.glb"))


def waystone():
    """A mile waystone on the ride north: carved notches, a snow cap."""
    K.reset(26)
    K.box((0.6, 0.35, 1.3), (0, 0, -0.1), (0.05, 0.03, 0), K.STONE, 0.1, 0.3, 0.12, collide=True)
    K.box((0.66, 0.42, 0.14), (0.03, 0, 1.18), (0.05, 0.03, 0), K.SNOW, bevel=0.05)
    for z in (0.5, 0.75, 0.95):
        K.box((0.3, 0.37, 0.05), (0, 0, z), color=K.STONE_DARK)
    K.export(os.path.join(FOREST, "waystone.glb"))


def roadside_shrine():
    """A little roofed roadside shrine to the old human gods (not the fae):
    a stone box on a post, guttered candles, a frozen sprig."""
    K.reset(27)
    K.box((0.5, 0.5, 1.2), (0, 0, 0), color=K.STONE_DARK, bevel=0.05, collide=True)
    K.box((0.9, 0.7, 0.8), (0, 0, 1.2), color=K.STONE, bevel=0.05)
    K.box((0.6, 0.1, 0.55), (0, -0.32, 1.32), color=(0.12, 0.10, 0.10))
    for s in (-1, 1):
        K.box((1.1, 0.55, 0.08), (0, s * 0.22, 2.0), (s * 0.6, 0, 0), K.WOOD_ROT)
        K.box((1.15, 0.6, 0.08), (0, s * 0.24, 2.07), (s * 0.6, 0, 0), K.SNOW)
    for x in (-0.15, 0.0, 0.14):
        K.cyl(0.035, 0.12, (x, -0.3, 1.32), color=K.CLOTH_CREAM, verts=6)
    K.blob(0.06, (0.22, -0.3, 1.4), color=(0.6, 0.06, 0.06))
    K.export(os.path.join(FOREST, "roadside_shrine.glb"))


def frozen_bridge():
    """A humped stone bridge over the frozen creek, parapets crusted in snow.
    Long axis = X, 12 m; 4.6 m wide; deck top at ~1.4 m above the banks."""
    K.reset(28)
    r = K.rng()
    for i in range(12):
        x = -5.5 + i
        t = 1.0 - abs(x) / 6.0
        z = 0.8 + t * 0.6
        K.box((1.02, 4.0, 0.35), (x, 0, z - 0.35), color=K.STONE, bevel=0.03)
        K.box((1.02, 4.05, 0.08), (x, 0, z), color=(0.62, 0.58, 0.52))  # rutted, trodden deck
        for s in (-1, 1):
            K.box((1.02, 0.35, 0.65), (x, s * 2.15, z), color=K.STONE_DARK, bevel=0.03)
            K.box((1.04, 0.42, 0.12), (x, s * 2.15, z + 0.65), color=K.SNOW, bevel=0.04)
    K.box((3.0, 4.0, 1.1), (0, 0, -0.6), color=K.STONE_DARK, bevel=0.1)  # arch fill
    K.box((2.0, 4.1, 0.5), (0, 0, -0.95), color=(0.06, 0.07, 0.09))  # dark under the arch
    for s in (-1, 1):
        for x in (-5.5, 5.5):
            K.blob(0.4, (x, s * 2.15, 1.0), (1, 1, 0.6), K.SNOW, 1)
        for _ in range(4):
            K.cyl(0.05, r.uniform(0.3, 0.6), (r.uniform(-1, 1), s * 2.2, 0.75), (math.pi, 0, 0), K.ICE, 5, 0.0)
    for x in range(-5, 6):
        t = 1.0 - abs(x) / 6.0
        K.col_box((x, 0, 0.6 + t * 0.6), (1.05, 4.0, 0.4))
    K.export(os.path.join(FOREST, "frozen_bridge.glb"))


def gibbet():
    """An old gibbet at the crossroads: a crooked post, an arm, an empty
    iron cage creaking in the wind. Grim, a warning against poaching."""
    K.reset(29)
    K.cyl(0.18, 4.6, (0, 0, 0), (0.0, 0.04, 0), K.WOOD_ROT, 8)
    K.stick((0, 0, 4.2), (1.8, 0, 4.3), 0.11, K.WOOD_ROT, 6)
    K.stick((0, 0, 3.0), (1.0, 0, 4.25), 0.07, K.WOOD_ROT, 6)
    K.stick((1.6, 0, 4.25), (1.6, 0, 3.3), 0.015, K.IRON, 4)
    for k in range(8):
        a = k / 8 * math.tau
        K.stick((1.6 + math.cos(a) * 0.35, math.sin(a) * 0.35, 1.6), (1.6 + math.cos(a) * 0.3, math.sin(a) * 0.3, 3.3), 0.02, K.IRON, 4)
    for z in (1.6, 2.4, 3.3):
        K.torus(0.33, 0.02, (1.6, 0, z), color=K.RUST, major=10, minor=4)
    K.blob(0.6, (0, 0, 0), (1.4, 1.4, 0.3), K.SNOW, 1)
    K.col_box((0, 0, 2.3), (0.4, 0.4, 4.6))
    K.export(os.path.join(FOREST, "gibbet.glb"))


def broken_signpost():
    """A leaning signpost, one arm snapped and lying in the snow."""
    K.reset(30)
    K.cyl(0.1, 2.6, (0, 0, 0), (0.1, 0.05, 0), K.WOOD_ROT, 6)
    K.box((1.1, 0.06, 0.24), (0.45, 0, 2.2), (0.1, 0.05, 0.1), K.WOOD_PALE, bevel=0.02)
    K.box((0.9, 0.06, 0.22), (-0.3, 0.1, 1.8), (0.1, 0.05, 2.6), K.WOOD_PALE, bevel=0.02)
    K.box((1.0, 0.24, 0.06), (0.8, 0.6, 0.02), (0, 0, 0.7), K.WOOD_PALE, bevel=0.02)
    K.cyl(0.12, 0.08, (0.12, 0.08, 2.6), color=K.SNOW, verts=6)
    K.export(os.path.join(FOREST, "broken_signpost.glb"))


def farmstead():
    """An abandoned farmstead off the north road: a small stone longhouse
    with a caved-in thatch, a collapsed byre and a broken hurdle fence.
    Footprint about 18 x 14 m around the origin."""
    K.reset(31)
    r = K.rng()
    # Longhouse.
    K.box((9.0, 0.6, 2.4), (0, -2.5, 0), color=K.STONE, grad=0.3, bevel=0.05, collide=True)
    K.box((9.0, 0.6, 2.0), (0, 2.5, 0), color=K.STONE, grad=0.3, bevel=0.05, collide=True)
    for s in (-1, 1):
        K.box((0.6, 5.6, 2.4), (s * 4.5, 0, 0), color=K.STONE, grad=0.3, bevel=0.05, collide=True)
        K.box((0.6, 3.0, 1.3), (s * 4.5, 0, 2.4), color=K.STONE, bevel=0.05)
    K.box((1.0, 0.7, 1.9), (-1.2, -2.5, 0), color=(0.08, 0.08, 0.09))  # doorway (dark)
    for s in (-1, 1):  # sagging thatch, holed
        K.box((4.0, 3.4, 0.35), (-2.6, s * 1.4, 2.6), (s * 0.55, 0.12, 0), K.STRAW, 0.15, bevel=0.1)
        K.box((4.1, 3.5, 0.2), (-2.6, s * 1.45, 2.78), (s * 0.55, 0.12, 0), K.SNOW, bevel=0.08)
    for i in range(5):
        x = 0.6 + i * 0.8
        K.stick((x, -2.4, 2.4), (x + r.uniform(-0.4, 0.4), 0.4, 3.4 - i * 0.5), 0.08, K.WOOD_ROT, 5)
    K.blob(1.6, (2.2, 0, 0.2), (1.4, 1.2, 0.5), K.SNOW, 1)
    # Collapsed byre.
    for i in range(6):
        K.stick((-3 + i * 0.9, 6.0, 0), (-3 + i * 0.9 + r.uniform(-0.3, 0.3), 7.5, 1.6 - (i % 3) * 0.5), 0.09, K.WOOD_ROT, 5)
    K.box((5.5, 2.8, 0.25), (-0.5, 6.8, 0.6), (0.35, 0.05, 0.08), K.SNOW, bevel=0.1)
    # Hurdle fence, broken.
    for i in range(9):
        x = -8 + i * 2.0
        if i in (3, 4):
            K.box((1.9, 0.08, 0.9), (x + 1.0, -6.8, 0.0), (1.3, 0, 0.1), K.WOOD_ROT)
            continue
        K.cyl(0.06, 1.1, (x, -6.0, 0), color=K.WOOD_ROT, verts=5)
        K.box((1.9, 0.06, 0.8), (x + 1.0, -6.0, 0.2), color=(0.30, 0.24, 0.17))
    # Well stub with a frozen bucket.
    K.cyl(0.8, 0.8, (6.5, 4.0, 0), color=K.STONE, verts=10, smooth=False)
    K.cyl(0.6, 0.05, (6.5, 4.0, 0.75), color=K.ICE, verts=10)
    K.cyl(0.18, 0.3, (7.3, 3.4, 0), color=K.WOOD, verts=8, r2=0.22)
    K.col_box((6.5, 4.0, 0.4), (1.6, 1.6, 0.8))
    K.export(os.path.join(FOREST, "farmstead.glb"))


def hunters_hide():
    """Feyre's thorn thicket hide by the waiting oak: a dome of bent thorny
    brush with a gap to watch the clearing through."""
    K.reset(19)
    r = K.rng()
    for i in range(22):
        a = i / 22 * math.tau
        if abs(math.atan2(math.sin(a + math.pi / 2), math.cos(a + math.pi / 2))) < 0.45:
            continue  # the watching gap faces -Y
        base = (math.cos(a) * 1.7, math.sin(a) * 1.7, 0)
        top = (math.cos(a) * 0.3 + r.uniform(-0.2, 0.2), math.sin(a) * 0.3, 1.5 + r.uniform(-0.2, 0.2))
        K.stick(base, top, 0.04, K.BARK, 4, 0.01)
    for _ in range(14):
        a = r.uniform(0, math.tau)
        if abs(math.atan2(math.sin(a + math.pi / 2), math.cos(a + math.pi / 2))) < 0.5:
            continue
        K.blob(r.uniform(0.35, 0.6), (math.cos(a) * 1.4, math.sin(a) * 1.4, r.uniform(0.3, 1.0)), (1.2, 1, 0.9), (0.20, 0.17, 0.14), 1, 0.1, 0.3)
    K.blob(1.4, (0, 0.6, 1.2), (1.3, 1.0, 0.35), K.SNOW, 1, 0.02, 0.15)
    for _ in range(6):  # thorns' few berries: the only red
        a = r.uniform(0, math.tau)
        K.blob(0.05, (math.cos(a) * 1.55, math.sin(a) * 1.55, r.uniform(0.5, 1.2)), color=(0.6, 0.06, 0.06), subdiv=1)
    K.export(os.path.join(FOREST, "hunters_hide.glb"))


def leaning_stone():
    """One of the two old leaning stones that mark the gap in the Wall."""
    K.reset(20)
    K.box((1.3, 0.8, 4.2), (0, 0, -0.3), (0.0, 0.16, 0.05), K.STONE_DARK, 0.12, 0.35, 0.3, collide=True)
    K.blob(0.9, (0.0, 0.0, 0.0), (1.3, 1.1, 0.4), K.SNOW, 1)
    for z in (1.2, 2.3, 3.1):  # faint weathered notches, the old warding marks
        K.box((0.08, 0.84, 0.35), (0.45 + z * 0.16, 0, z), (0, 0.16, 0), (0.55, 0.55, 0.52))
    K.blob(0.6, (0.75, 0, 3.75), (0.9, 0.9, 0.25), K.SNOW, 1, 0.02, 0.1)
    K.export(os.path.join(SEAM, "leaning_stone.glb"))


def great_cairn():
    """The great warning cairn: a tall stack of stones capped with an antlered
    skull and hung with rags; villagers add a stone and turn back."""
    K.reset(21)
    r = K.rng()
    z = 0.0
    radius = 1.6
    while radius > 0.25:
        for p in K.ring_points(max(3, int(radius * 6)), radius * 0.75, 0.3):
            K.blob(radius * 0.42, (p[0], p[1], z + radius * 0.25), (1.2, 1.2, 0.8), K.STONE if r.random() < 0.7 else K.STONE_DARK, 1)
        z += radius * 0.48
        radius *= 0.8
    K.blob(0.25, (0, 0, z + 0.1), (1.0, 1.4, 0.8), K.BONE, 1)
    for s in (-1, 1):
        K.stick((s * 0.12, 0.1, z + 0.25), (s * 0.6, 0.0, z + 0.9), 0.035, K.BONE, 5, 0.015)
    for i in range(4):
        a = r.uniform(0, math.tau)
        K.box((0.08, 0.02, 0.6), (math.cos(a) * 0.7, math.sin(a) * 0.7, z * 0.55), (0, 0.15, a), K.CLOTH_CREAM if i % 2 else K.CLOTH_RED)
    K.blob(1.2, (0, 0, 0), (1.5, 1.5, 0.35), K.SNOW, 1, 0.02, 0.2)
    K.col_box((0, 0, 1.2), (2.4, 2.4, 2.4))
    K.export(os.path.join(SEAM, "great_cairn.glb"))


def offering_post():
    """The Children of the Blessed's offering post: a weathered post with a
    crossbar, ribbons frozen stiff, bundles and candle stubs at its foot."""
    K.reset(22)
    r = K.rng()
    K.cyl(0.14, 3.2, (0, 0, 0), color=K.WOOD_ROT, verts=8)
    K.stick((-0.9, 0, 2.6), (0.9, 0, 2.6), 0.07, K.WOOD_ROT, 6)
    cols = [K.CLOTH_CREAM, K.CLOTH_BLUE, K.CLOTH_RED, (0.75, 0.62, 0.30), (0.55, 0.42, 0.62)]
    for i in range(9):
        x = -0.8 + i * 0.2
        K.box((0.07, 0.015, r.uniform(0.6, 1.1)), (x, 0.05, 2.6 - 1.0), (r.uniform(-0.15, 0.15), 0.1, 0), cols[i % len(cols)])
    for i in range(5):
        a = i / 5 * math.tau
        K.box((0.3, 0.22, 0.18), (math.cos(a) * 0.55, math.sin(a) * 0.55, 0), (0, 0, a), K.STRAW, bevel=0.05)
        K.cyl(0.04, 0.12, (math.cos(a + 0.6) * 0.4, math.sin(a + 0.6) * 0.4, 0), color=K.CLOTH_CREAM, verts=6)
    K.box((0.4, 0.3, 0.02), (0, 0.2, 1.4), (1.57, 0, 0), K.PAPER)  # a nailed pamphlet
    K.blob(0.8, (0, 0, 0), (1.4, 1.4, 0.25), K.SNOW, 1)
    K.col_box((0, 0, 1.6), (0.3, 0.3, 3.2))
    K.export(os.path.join(SEAM, "offering_post.glb"))


def iron_fence_gate():
    """Where the villagers' iron stakes are thickest, a crude iron-bound
    post with horseshoes nailed up, facing the Wall."""
    K.reset(23)
    K.cyl(0.18, 2.4, (0, 0, 0), color=K.WOOD_ROT, verts=8)
    for i in range(5):
        K.torus(0.12, 0.025, (0.0, -0.18, 0.8 + i * 0.3), (1.57, 0, 0), K.RUST, 10, 4)
    for x in (-0.8, -0.4, 0.4, 0.8):
        K.cyl(0.035, 1.6, (x, 0, 0), (0.0, 0.08 * x, 0), K.IRON, 5, 0.01)
    K.stick((-0.9, 0, 1.2), (0.9, 0, 1.2), 0.025, K.RUST, 5)
    K.col_box((0, 0, 1.2), (0.4, 0.4, 2.4))
    K.export(os.path.join(SEAM, "iron_post.glb"))


if __name__ == "__main__":
    for fn in (lodge_ruin, boundary_wall_section, boundary_wall_end, deer_stand, woodcutter_leanto, split_oak,
               frozen_fall, ash_wall_segment, ash_wall_slump, ash_gate, water_grate, lambda: water_grate(True), gamekeeper_hut, lantern_post, waystone, roadside_shrine,
               frozen_bridge, gibbet, broken_signpost, farmstead, hunters_hide, leaning_stone, great_cairn, offering_post, iron_fence_gate):
        fn()
