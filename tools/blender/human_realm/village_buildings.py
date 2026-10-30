"""Village buildings (headless bpy). Run:
    bpyenv/bin/python tools/blender/human_realm/village_buildings.py [name ...]
Writes world/human_realm/village/assets/<name>.glb. Footprints (w x d, Blender
X x Y) must match VillagePlan.FOOTPRINTS in world/human_realm/village/village_plan.gd.
Front (doors) faces Blender -Y = Godot +Z.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from village_lib import C, SNOW, Asset, reset  # noqa: E402


def plinth(a, w, d, h=0.45):
    a.box((w + 0.3, d + 0.3, h), (0, 0, h / 2), C["stone_dark"], bevel=0.08, snow=0.8)


def house_timber():
    """Two-storey timber-framed house, jettied upper floor, shingle roof."""
    a = Asset("village_house_timber", 11)
    w, d = 7.0, 5.0
    plinth(a, w, d)
    a.box((w, d, 2.5), (0, 0, 0.45 + 1.25), C["daub"], bevel=0.04)
    a.timber_frame(w, d, 0.45, 2.5, posts=3)
    a.box((w + 0.6, d + 0.6, 0.25), (0, 0, 3.07), C["timber"], bevel=0.03, snow=0.9)
    a.box((w + 0.5, d + 0.5, 2.3), (0, 0, 3.2 + 1.15), C["daub"], bevel=0.04)
    a.timber_frame(w + 0.5, d + 0.5, 3.2, 2.3, posts=4)
    a.gable_fill(w + 0.5, d + 0.5, 5.5, 2.9, C["daub"])
    a.gable_roof(w + 0.5, d + 0.5, 5.5, 2.9, C["shingle"], overhang=0.5)
    a.chimney(2.6, 0.9, 4.0, 5.6)
    a.door(-1.4, -d / 2)
    for x in (0.6, 2.3):
        a.window(x, -d / 2, 1.9)
    for x in (-2.2, 0.0, 2.2):
        a.window(x, -(d + 0.5) / 2, 4.3, w=0.7, h=0.8)
    a.window(-1.5, d / 2, 1.9, face="back")
    a.window(1.5, (d + 0.5) / 2, 4.3, face="back", w=0.7, h=0.8)
    a.icicles(-3.8, 3.8, -(d + 0.5) / 2 - 0.55, 5.35, 14)
    # A horseshoe nailed over the door against the fae.
    a.cyl(0.13, 0.04, (-1.4, -d / 2 - 0.2, 2.35), C["iron"], rot=(math.pi / 2, 0, 0), segs=8)
    a.snow_mound((3.2, -2.9, 0.0), 0.8, 0.35)
    a.export()


def house_wattle():
    """One-storey wattle-and-daub cottage with a heavy snow-laden thatch."""
    a = Asset("village_house_wattle", 12)
    w, d = 6.0, 4.4
    plinth(a, w, d, 0.35)
    a.box((w, d, 2.5), (0, 0, 0.35 + 1.25), C["daub_grey"], bevel=0.08)
    a.timber_frame(w, d, 0.35, 2.5, posts=2, braces=False)
    a.gable_fill(w, d, 2.85, 2.5, C["daub_grey"])
    a.gable_roof(w, d, 2.85, 2.5, C["thatch"], overhang=0.7, thick=0.5, snow_depth=0.28, bevel=0.18)
    a.chimney(-2.3, 0.6, 0.0, 6.4, w=0.65)
    a.door(0.8, -d / 2, w=1.0, h=1.9)
    a.window(-1.2, -d / 2, 1.7, w=0.7, h=0.7)
    a.window(1.8, d / 2, 1.7, face="back", w=0.7, h=0.7)
    a.icicles(-3.5, 3.5, -d / 2 - 0.75, 2.6, 10, (0.2, 0.7))
    a.box((0.9, 0.6, 0.9), (2.4, -2.6, 0.45), C["plank"], bevel=0.05, snow=1.0)
    a.export()


def house_long():
    """Longhouse: byre at one end, shingle roof, lean-to on the side."""
    a = Asset("village_house_long", 13)
    w, d = 10.0, 5.0
    plinth(a, w, d, 0.4)
    a.box((w, d, 2.7), (0, 0, 0.4 + 1.35), C["daub"], bevel=0.05)
    a.timber_frame(w, d, 0.4, 2.7, posts=5)
    a.gable_fill(w, d, 3.1, 3.0, C["daub"])
    a.gable_roof(w, d, 3.1, 3.0, C["thatch_old"], overhang=0.6, thick=0.42, snow_depth=0.25, bevel=0.15)
    a.chimney(-1.5, 0.0, 3.0, 4.2)
    a.door(-3.0, -d / 2)
    a.door(3.2, -d / 2, w=1.8, h=2.2, col=C["plank_old"])
    for x in (-0.8, 0.9):
        a.window(x, -d / 2, 1.8)
    # Lean-to log store on the east gable.
    a.box((1.6, 3.6, 0.15), (w / 2 + 0.9, 0, 2.2), C["plank_old"], rot=(0, 0.25, 0), snow=1.0)
    for y in (-1.6, 1.6):
        a.box((0.15, 0.15, 2.1), (w / 2 + 1.6, y, 1.05), C["timber"])
    for i in range(5):
        a.cyl(0.14, 3.2, (w / 2 + 0.5 + (i % 3) * 0.3, -1.6, 0.15 + (i // 3) * 0.3 + 0.14), C["plank"], rot=(-math.pi / 2, 0, 0), segs=7)
    a.icicles(-5.5, 5.5, -d / 2 - 0.65, 3.0, 16)
    a.export()


def house_croft():
    """Tiny stone croft with a low thatch and a lopsided chimney."""
    a = Asset("village_house_croft", 14)
    w, d = 5.0, 4.0
    a.box((w, d, 2.3), (0, 0, 1.15), C["stone"], bevel=0.12)
    for i in range(10):
        a.box((a.rng.uniform(0.4, 0.8), 0.08, 0.3), (a.rng.uniform(-2.2, 2.2), -d / 2 - 0.02, a.rng.uniform(0.3, 2.0)), C["stone_dark"])
    a.gable_fill(w, d, 2.3, 2.2, C["stone"])
    a.gable_roof(w, d, 2.3, 2.2, C["thatch"], overhang=0.6, thick=0.45, snow_depth=0.3, bevel=0.16)
    a.chimney(w / 2 - 0.2, 0.0, 0.0, 5.3, col=C["stone_dark"], w=0.6)
    a.door(-0.9, -d / 2, w=0.95, h=1.8)
    a.window(0.9, -d / 2, 1.4, w=0.6, h=0.6)
    a.icicles(-3.0, 3.0, -d / 2 - 0.7, 2.1, 9)
    a.export()


def shed():
    a = Asset("village_shed", 15)
    w, d = 3.2, 2.6
    a.box((w, d, 2.0), (0, 0, 1.0), C["plank_old"], bevel=0.04)
    for i in range(6):
        a.box((0.04, 0.05, 1.9), (-w / 2 + 0.3 + i * 0.52, -d / 2 - 0.02, 0.95), C["timber"])
    a.box((w + 0.6, d + 0.7, 0.16), (0, 0, 2.25), C["plank"], rot=(0.2, 0, 0), bevel=0.03)
    a.box((w + 0.4, d + 0.5, 0.18), (0, 0.02, 2.42), SNOW, rot=(0.2, 0, 0), bevel=0.06)
    a.door(0.2, -d / 2, w=0.9, h=1.8, col=C["plank_old"])
    a.icicles(-1.8, 1.8, -d / 2 - 0.35, 2.15, 6)
    a.export()


def tavern():
    """Two storeys; the ground floor is an enterable shell (door gap at the
    front, x = -1.5). Interior dressing is village_tavern_interior.glb."""
    a = Asset("village_tavern", 21)
    w, d, t = 12.0, 8.0, 0.35
    gh = 3.2
    plinth(a, w, d, 0.3)
    a.box((w - 0.4, d - 0.4, 0.12), (0, 0, 0.36), C["plank"], jitter=0.08)
    # Walls with a door gap 1.6 m wide at x -1.5.
    gap0, gap1 = -2.3, -0.7
    a.box((gap0 + w / 2, t, gh), ((-w / 2 + gap0) / 2, -d / 2 + t / 2, 0.3 + gh / 2), C["daub"], bevel=0.03)
    a.box((w / 2 - gap1, t, gh), ((w / 2 + gap1) / 2, -d / 2 + t / 2, 0.3 + gh / 2), C["daub"], bevel=0.03)
    a.box((gap1 - gap0, t, gh - 2.4), ((gap0 + gap1) / 2, -d / 2 + t / 2, 0.3 + 2.4 + (gh - 2.4) / 2), C["daub"])
    a.box((w, t, gh), (0, d / 2 - t / 2, 0.3 + gh / 2), C["daub"], bevel=0.03)
    for x in (-w / 2 + t / 2, w / 2 - t / 2):
        a.box((t, d, gh), (x, 0, 0.3 + gh / 2), C["daub"], bevel=0.03)
    a.timber_frame(w, d, 0.3, gh, posts=4, braces=False)
    a.box((w - 0.2, d - 0.2, 0.3), (0, 0, 0.3 + gh + 0.15), C["timber"])  # ceiling
    # Open door leaf, swung inward.
    a.box((1.5, 0.12, 2.3), (gap0 + 0.1, -d / 2 + 0.95, 0.3 + 1.15), C["door"], rot=(0, 0, 1.3), bevel=0.02)
    a.box((gap1 - gap0 + 0.4, 0.3, 0.2), ((gap0 + gap1) / 2, -d / 2 - 0.05, 0.3 + 2.5), C["timber"])
    # Upper storey.
    a.box((w + 0.4, d + 0.4, 2.8), (0, 0, 0.3 + gh + 0.3 + 1.4), C["daub"], bevel=0.04)
    a.timber_frame(w + 0.4, d + 0.4, 0.3 + gh + 0.3, 2.8, posts=6)
    top = 0.3 + gh + 0.3 + 2.8
    a.gable_fill(w + 0.4, d + 0.4, top, 3.6, C["daub"])
    a.gable_roof(w + 0.4, d + 0.4, top, 3.6, C["shingle"], overhang=0.6)
    a.chimney(w / 2 - 1.2, 1.5, 3.0, top + 2.9 - 3.0 + 1.5, w=1.0)
    # Warm windows, ground and upper.
    for x in (-4.4, 1.2, 3.8):
        a.window(x, -d / 2, 1.9, col=C["glass_warm"], w=1.1, h=1.0, shutters=False)
    for x in (-4.5, -1.5, 1.5, 4.5):
        a.window(x, -(d + 0.4) / 2, 5.4, col=C["glass_warm"], w=0.8, h=0.8)
    for y in (-1.8, 1.8):
        a.window(w / 2, y, 1.9, col=C["glass_warm"], face="right", shutters=False)
    a.window(-w / 2, 0.0, 1.9, col=C["glass_warm"], face="left", shutters=False)
    # Hanging sign on an iron bracket by the door: a tankard on a board.
    a.box((1.4, 0.08, 0.08), (-3.3, -d / 2 - 0.7, 3.2), C["iron"], rot=(0, 0, math.pi / 2))
    a.box((0.08, 1.3, 0.08), (-3.3, -d / 2 - 0.65, 3.2), C["iron"])
    for s in (-0.35, 0.35):
        a.box((0.03, 0.03, 0.35), (-3.3 + s, -d / 2 - 1.1, 3.0), C["iron"])
    a.box((1.0, 0.1, 0.75), (-3.3, -d / 2 - 1.1, 2.5), C["plank"], rot=(0, 0, 0), bevel=0.03)
    a.box((1.0, 0.1, 0.75), (-3.3, -d / 2 - 1.1, 2.5), C["plank"], rot=(0, 0, math.pi / 2), bevel=0.03)
    a.cyl(0.18, 0.35, (-3.3 - 0.06, -d / 2 - 1.1, 2.33), C["gold"], rot=(0, 0, 0), segs=8)
    a.icicles(-6.5, 6.5, -(d + 0.4) / 2 - 0.7, top - 0.1, 20)
    # Benches and a barrel out front.
    a.box((2.2, 0.4, 0.45), (2.5, -d / 2 - 0.55, 0.22), C["plank"], bevel=0.04, snow=1.0)
    a.cyl(0.38, 0.9, (5.2, -d / 2 - 0.6, 0.0), C["plank"], segs=10, snow=1.0)
    a.export()


def tavern_interior():
    """Bar, shelves, tables, benches and a hearth for the tavern's ground floor
    (in the tavern's local frame; the hearth is on the west wall)."""
    a = Asset("village_tavern_interior", 22)
    z = 0.42
    # Bar along the back-right.
    a.box((4.2, 0.8, 1.1), (3.0, 2.2, z + 0.55), C["plank"], bevel=0.05)
    a.box((4.4, 1.0, 0.1), (3.0, 2.2, z + 1.15), C["timber"], bevel=0.03)
    a.box((4.2, 0.4, 2.2), (3.0, 3.5, z + 1.1), C["timber"])
    for row in range(3):
        a.box((4.0, 0.42, 0.06), (3.0, 3.35, z + 0.6 + row * 0.6), C["plank"])
        for i in range(9):
            col = (C["glass_dark"], C["salt"], C["rust"], C["cloth_grey"])[(i + row) % 4]
            a.cyl(0.07, 0.28, (1.3 + i * 0.42, 3.35, z + 0.63 + row * 0.6), col, segs=6)
    for i in range(3):
        a.cyl(0.4, 0.95, (4.9, 1.0 + i * 0.85, z), C["plank"], segs=10)
    # Hearth on the west wall.
    a.box((2.4, 1.1, 1.4), (-5.2, 0.6, z + 0.7), C["stone"], bevel=0.08)
    a.box((1.4, 0.7, 0.9), (-4.9, 0.6, z + 0.45), C["black"], jitter=0.0)
    for i in range(3):
        a.cyl(0.09, 0.9, (-4.9, 0.25 + i * 0.25, z + 0.12), C["plank"], rot=(0, math.pi / 2, 0.3 * i), segs=6)
    a.sphere(0.3, (-4.85, 0.6, z + 0.35), C["ember"], scale=(1.4, 0.8, 0.6))
    a.box((2.8, 1.3, 0.2), (-5.2, 0.6, z + 1.5), C["timber"], bevel=0.04)
    a.box((1.4, 0.9, 1.7), (-5.5, 0.6, z + 2.4), C["stone"], bevel=0.06)
    # Tables with benches and tankards.
    for (x, y) in ((-2.0, -1.6), (0.8, -1.4), (-1.8, 1.6)):
        a.box((1.9, 0.9, 0.08), (x, y, z + 0.78), C["plank"], bevel=0.03)
        for sx in (-0.75, 0.75):
            a.box((0.1, 0.7, 0.74), (x + sx, y, z + 0.37), C["timber"])
        for sy in (-0.75, 0.75):
            a.box((1.8, 0.32, 0.06), (x, y + sy, z + 0.45), C["plank"], bevel=0.02)
            for sx in (-0.7, 0.7):
                a.box((0.08, 0.26, 0.42), (x + sx, y + sy, z + 0.21), C["timber"])
        for k in range(2):
            a.cyl(0.07, 0.16, (x - 0.4 + k * 0.7, y + 0.1 * k, z + 0.82), C["timber_grey"], segs=7)
    # Ceiling beams and a few hanging herbs.
    for i in range(5):
        a.box((0.22, 7.6, 0.25), (-4.8 + i * 2.4, 0, 3.35), C["timber"])
    for i in range(6):
        a.box((0.12, 0.12, 0.45), (-4.0 + i * 1.6, -2.4 + (i % 2) * 0.3, 3.0), C["thatch"], bevel=0.03)
    a.export()


def meeting_hall():
    """Where the Children of the Blessed preach: tall stone hall, pale banners."""
    a = Asset("village_meeting_hall", 23)
    w, d = 14.0, 8.0
    a.box((w + 0.4, d + 0.4, 1.2), (0, 0, 0.6), C["stone_dark"], bevel=0.1, snow=0.8)
    a.box((w, d, 3.6), (0, 0, 1.2 + 1.8), C["daub_grey"], bevel=0.05)
    for x in [-w / 2 + i * w / 5 for i in range(6)]:
        for y in (-d / 2, d / 2):
            a.box((0.45, 0.45, 4.8), (x, y, 2.4), C["stone"], bevel=0.06)
    a.gable_fill(w, d, 4.8, 4.6, C["daub_grey"])
    a.gable_roof(w, d, 4.8, 4.6, C["shingle"], overhang=0.6)
    # Bell cote on the ridge.
    a.box((1.0, 1.0, 1.3), (-w / 2 + 1.5, 0, 9.4 + 0.65), C["timber_grey"], bevel=0.04)
    a.cyl(0.32, 0.45, (-w / 2 + 1.5, 0, 9.75), C["iron"], segs=8, r2=0.18)
    a.box((1.3, 1.3, 0.15), (-w / 2 + 1.5, 0, 11.05), C["shingle"], snow=1.0)
    # Double door with a porch.
    a.door(-0.6, -d / 2, w=1.1, h=2.6, z=1.2)
    a.door(0.6, -d / 2, w=1.1, h=2.6, z=1.2)
    for i in range(4):
        a.box((3.2 - i * 0.3, 0.5, 0.3), (0, -d / 2 - 1.6 + i * 0.4, 0.15 + i * 0.3), C["stone"], bevel=0.04, snow=1.0)
    # Pale banners: long cream cloths with a pale sun-disc.
    for x in (-2.6, 2.6, -5.6, 5.6):
        a.box((1.1, 0.06, 3.0), (x, -d / 2 - 0.08, 2.4 + 1.5), C["cloth_pale"], bevel=0.02, jitter=0.02)
        a.cyl(0.32, 0.03, (x, -d / 2 - 0.13, 4.6), C["gold"], rot=(math.pi / 2, 0, 0), segs=12)
        a.box((1.4, 0.1, 0.1), (x, -d / 2 - 0.1, 5.45), C["timber"])
        a.box((0.5, 0.06, 0.5), (x, -d / 2 - 0.08, 2.35), C["cloth_pale"], rot=(0, math.pi / 4, 0))
    for x in (-5.0, -2.0, 2.0, 5.0):
        a.window(x, d / 2, 3.4, w=0.6, h=1.6, face="back", shutters=False)
    a.icicles(-7.5, 7.5, -d / 2 - 0.7, 4.65, 22, (0.2, 0.8))
    a.export()


def debt_house():
    """The debt family's house: a poor cottage, a patched sagging roof and a
    boarded window."""
    a = Asset("village_debt_house", 24)
    w, d = 5.6, 4.2
    plinth(a, w, d, 0.3)
    a.box((w, d, 2.3), (0, 0, 0.3 + 1.15), C["daub_grey"], bevel=0.06)
    for i in range(5):
        a.box((a.rng.uniform(0.4, 0.9), 0.06, a.rng.uniform(0.3, 0.6)), (a.rng.uniform(-2.3, 2.3), -d / 2 - 0.02, a.rng.uniform(0.6, 2.2)), C["daub"])
    a.timber_frame(w, d, 0.3, 2.3, col=C["timber_grey"], posts=2)
    a.gable_fill(w, d, 2.6, 2.2, C["daub_grey"])
    a.gable_roof(w, d, 2.6, 2.2, C["thatch_old"], overhang=0.5, thick=0.36, sag=0.2, bevel=0.12)
    a.box((1.6, 1.1, 0.12), (-1.2, -1.3, 4.1), C["plank_old"], rot=(-0.85, 0.05, 0.1))
    a.chimney(1.8, 0.5, 2.0, 3.9, col=C["stone_dark"], w=0.55)
    a.door(-1.4, -d / 2, w=0.9, h=1.8, col=C["plank_old"])
    a.window(1.0, -d / 2, 1.5, w=0.7, h=0.7, shutters=False)
    for i in range(3):
        a.box((1.0, 0.06, 0.16), (1.0, -d / 2 - 0.16, 1.25 + i * 0.25), C["plank_old"], rot=(0, 0.15 * (i - 1), 0))
    a.icicles(-3.0, 3.0, -d / 2 - 0.6, 2.4, 8)
    a.export()


def barn_abandoned():
    """Isaac Hale's barn on the outskirts: grey boards, a sagging roof with a
    hole, one big door hanging off its hinges."""
    a = Asset("village_barn_abandoned", 25)
    w, d, h = 14.0, 9.0, 4.8
    a.box((w, d, 0.4), (0, 0, 0.2), C["stone_dark"], bevel=0.06, snow=0.6)
    for i in range(int(w / 0.5)):
        if i in (12, 13, 20):
            continue
        x = -w / 2 + 0.25 + i * 0.5
        a.box((0.46, 0.1, h), (x, -d / 2, 0.4 + h / 2 - (0.4 if i % 7 == 3 else 0)), C["plank_old"], jitter=0.12)
        a.box((0.46, 0.1, h), (x, d / 2, 0.4 + h / 2), C["plank_old"], jitter=0.12)
    for y in (-d / 2, d / 2):
        for i in range(int(d / 0.5)):
            if y > 0 and i == 6:
                continue
            a.box((0.1, 0.46, h), (y / d * w, -d / 2 + 0.25 + i * 0.5, 0.4 + h / 2), C["plank_old"], jitter=0.12)
    a.timber_frame(w, d, 0.4, h, col=C["timber_grey"], posts=4)
    a.gable_fill(w, d, 0.4 + h, 4.4, C["plank_old"])
    # Front slab whole, back slab split around a hole.
    a.gable_roof(w, d, 0.4 + h, 4.4, C["shingle"], overhang=0.5, sag=0.35, bare_back=True)
    # Dark hole in the back slab, broken rafters showing.
    a.box((3.0, 2.4, 0.3), (2.6, 2.4, 0.4 + h + 2.2), C["black"], rot=(-math.atan2(4.4, d / 2), 0, 0), jitter=0.0)
    for i in range(4):
        a.box((0.14, 3.0, 0.14), (1.4 + i * 0.8, 2.4, 0.4 + h + 2.4), C["timber_grey"], rot=(-math.atan2(4.4, d / 2), 0, 0))
    # Big doors: one closed, one hanging askew.
    a.box((2.2, 0.16, 3.6), (-1.15, -d / 2 - 0.12, 2.2), C["plank"], bevel=0.03)
    a.box((2.2, 0.16, 3.4), (1.45, -d / 2 - 0.9, 1.9), C["plank"], rot=(0.0, 0.08, -0.7), bevel=0.03)
    # Hay loft door and a snow drift against the wall.
    a.box((1.4, 0.14, 1.3), (0, -d / 2 - 0.05, 5.9), C["door"])
    a.snow_mound((-4.5, -d / 2 - 0.4, 0.0), 2.2, 0.9)
    a.snow_mound((5.0, d / 2 + 0.4, 0.0), 2.8, 1.1)
    a.icicles(-7.0, 7.0, -d / 2 - 0.55, 4.9, 14, (0.2, 1.0))
    a.export()


def mill():
    """Watermill: stone ground floor, timber upper, wheel separate."""
    a = Asset("village_mill", 26)
    w, d = 8.0, 7.0
    a.box((w, d, 3.2), (0, 0, 1.6), C["stone"], bevel=0.12)
    a.box((w + 0.3, d + 0.3, 3.0), (0, 0, 3.2 + 1.5), C["plank"], bevel=0.04)
    a.timber_frame(w + 0.3, d + 0.3, 3.2, 3.0, posts=3)
    a.gable_fill(w + 0.3, d + 0.3, 6.2, 3.4, C["plank"])
    a.gable_roof(w + 0.3, d + 0.3, 6.2, 3.4, C["shingle"], overhang=0.6)
    a.door(-1.5, -d / 2, w=1.6, h=2.4)
    a.window(1.8, -d / 2, 2.0)
    a.window(0.0, -(d + 0.3) / 2, 4.8)
    a.box((1.4, 0.2, 1.6), (-1.5, -(d + 0.3) / 2 - 0.05, 4.6), C["door"])
    a.box((0.2, 0.2, 2.0), (-1.5, -(d + 0.3) / 2 - 0.9, 6.8), C["timber"], rot=(math.pi / 2, 0, 0))
    a.cyl(0.05, 1.6, (-1.5, -(d + 0.3) / 2 - 1.75, 5.2), C["cloth_brown"], segs=4)
    # Wheel axle housing on the west wall (-X): the wheel turns on that side.
    a.box((0.8, 1.2, 1.2), (-w / 2 - 0.3, 0, 2.6), C["timber"], bevel=0.05)
    for i in range(4):
        a.cyl(0.38, 0.8, (-2.6 + i * 0.75, -d / 2 - 0.7, 0.0), C["sack"], segs=8, r2=0.28)
    a.icicles(-4.5, 4.5, -(d + 0.3) / 2 - 0.7, 6.1, 14)
    a.export()


def mill_wheel():
    """Waterwheel frozen mid-turn, sheathed in ice and hung with icicles.
    Axis along Blender X; hub at origin height 2.6 (wheel bottom at 0)."""
    a = Asset("village_mill_wheel", 27)
    r, wd, hz = 2.6, 1.3, 2.6
    segs = 16
    for side in (-wd / 2, wd / 2):
        for i in range(segs):
            ang = i / segs * math.tau
            nxt = (i + 1) / segs * math.tau
            mid = (ang + nxt) / 2
            ln = 2 * r * math.sin(math.pi / segs) + 0.05
            a.box((0.16, ln, 0.22), (side, math.cos(mid) * r, hz + math.sin(mid) * r), C["timber"], rot=(mid + math.pi / 2, 0, 0))
        for i in range(6):
            ang = i / 6 * math.tau
            a.box((0.14, 0.14, r), (side, math.cos(ang) * r / 2, hz + math.sin(ang) * r / 2), C["timber"], rot=(ang - math.pi / 2, 0, 0))
    for i in range(segs):
        ang = i / segs * math.tau
        a.box((wd, 0.08, 0.55), (0, math.cos(ang) * (r - 0.2), hz + math.sin(ang) * (r - 0.2)), C["plank_old"], rot=(ang, 0, 0), snow=0.7)
    a.cyl(0.25, wd + 1.2, (-(wd + 1.2) / 2, 0, hz), C["timber"], rot=(0, math.pi / 2, 0), segs=8)
    # Ice: a frozen sheath at the bottom where it meets the creek, and icicles.
    a.sphere(1.0, (0, 0, 0.35), C["ice"], scale=(1.0, 2.6, 0.45), subdiv=2)
    for i in range(18):
        ang = math.pi + (i / 17) * math.pi
        y = math.cos(ang) * r * 0.95
        z = hz + math.sin(ang) * r * 0.95
        if z > 0.6:
            ln = a.rng.uniform(0.25, 0.9)
            a.cyl(0.006, ln, (a.rng.uniform(-0.5, 0.5), y, z - ln), C["ice"], segs=5, r2=0.08)
    a.export()


def smithy():
    """Open-fronted smithy with a forge, anvil, bellows and a quench tub."""
    a = Asset("village_smithy", 28)
    w, d = 7.0, 5.5
    a.box((w, d, 0.2), (0, 0, 0.1), C["stone_dark"])
    a.box((w, 0.4, 3.0), (0, d / 2 - 0.2, 1.5), C["stone"], bevel=0.08)
    for x in (-w / 2 + 0.2, w / 2 - 0.2):
        a.box((0.4, d, 3.0), (x, 0, 1.5), C["stone"], bevel=0.08)
    for x in (-w / 2 + 0.2, 0.0, w / 2 - 0.2):
        a.box((0.3, 0.3, 3.0), (x, -d / 2 + 0.15, 1.5), C["timber"])
    a.box((w + 0.3, 0.3, 0.3), (0, -d / 2 + 0.15, 3.0), C["timber"])
    a.gable_fill(w, d, 3.0, 2.2, C["plank_old"])
    a.gable_roof(w, d, 3.0, 2.2, C["shingle"], overhang=0.6)
    # Forge.
    a.box((1.8, 1.4, 0.9), (-1.6, 1.6, 0.65), C["stone_dark"], bevel=0.08)
    a.sphere(0.45, (-1.6, 1.5, 1.1), C["ember"], scale=(1.4, 1.0, 0.35))
    a.box((1.2, 1.0, 1.4), (-1.6, 1.8, 2.3), C["stone"], rot=(0, 0, 0), bevel=0.05)
    a.chimney(-1.6, 1.9, 3.0, 3.6, w=0.8)
    a.box((0.9, 0.5, 0.45), (-2.9, 1.2, 1.0), C["cloth_brown"], rot=(0, 0.3, 0), bevel=0.1)
    # Anvil on a stump, quench tub, tool rack.
    a.cyl(0.35, 0.6, (0.6, 0.2, 0.2), C["plank"], segs=9)
    a.box((0.7, 0.25, 0.25), (0.6, 0.2, 0.92), C["iron"], bevel=0.04)
    a.cyl(0.08, 0.3, (0.95, 0.2, 0.92), C["iron"], rot=(0, math.pi / 2, 0), r2=0.01, segs=6)
    a.box((0.35, 0.18, 0.12), (0.6, 0.2, 0.74), C["iron"])
    a.cyl(0.45, 0.65, (1.8, 1.2, 0.2), C["plank"], segs=10)
    a.cyl(0.4, 0.04, (1.8, 1.2, 0.8), C["glass_dark"], segs=10)
    a.box((2.2, 0.08, 1.2), (1.6, d / 2 - 0.45, 1.8), C["plank"])
    for i in range(6):
        a.box((0.06, 0.06, 0.7), (0.8 + i * 0.32, d / 2 - 0.5, 1.75), C["iron"], rot=(0, 0.1 * (i - 3), 0))
    # Horseshoes on the post and a snowy coal heap outside.
    for i in range(3):
        a.cyl(0.11, 0.04, (0.0, -d / 2 - 0.02, 1.6 + i * 0.35), C["rust"], rot=(math.pi / 2, 0, 0), segs=7)
    a.sphere(0.8, (w / 2 + 0.9, -1.2, 0.0), C["black"], scale=(1.2, 1.0, 0.55), snow=0.5)
    a.icicles(-4.0, 4.0, -d / 2 - 0.7, 3.0, 10)
    a.export()


def well():
    a = Asset("village_well", 29)
    a.cyl(1.05, 0.95, (0, 0, 0), C["stone"], segs=14, snow=1.0, bevel=0.06)
    a.cyl(0.8, 0.02, (0, 0, 0.94), C["black"], segs=14)
    a.cyl(1.12, 0.12, (0, 0, 0.92), C["stone_dark"], segs=14, snow=1.0)
    for x in (-1.0, 1.0):
        a.box((0.18, 0.18, 2.4), (x, 0, 1.2), C["timber"])
    a.gable_fill(2.6, 1.6, 2.35, 0.8, C["timber"])
    a.gable_roof(2.6, 1.6, 2.35, 0.8, C["shingle"], overhang=0.3, thick=0.12, snow_depth=0.14)
    a.cyl(0.1, 2.0, (-1.0, 0, 1.7), C["timber"], rot=(0, math.pi / 2, 0), segs=8)
    a.box((0.06, 0.06, 0.4), (1.15, 0, 1.55), C["timber"])
    a.cyl(0.02, 0.6, (0, 0, 1.1), C["cloth_brown"], segs=4)
    a.cyl(0.2, 0.3, (0.55, -0.6, 0.95), C["plank"], segs=8, r2=0.24)
    a.icicles(-1.4, 1.4, -1.1, 2.35, 7, (0.1, 0.35))
    a.export()


def market_stall(name, cloth, seed):
    a = Asset(name, seed)
    w, d = 3.0, 2.0
    for x in (-w / 2, w / 2):
        for y in (-d / 2, d / 2):
            a.box((0.12, 0.12, 2.5 if y > 0 else 2.0), (x, y, (2.5 if y > 0 else 2.0) / 2), C["timber"])
    a.box((w + 0.1, 0.9, 0.85), (0, -d / 2 + 0.45, 0.43), C["plank"], bevel=0.03)
    a.box((w + 0.3, 1.0, 0.07), (0, -d / 2 + 0.45, 0.88), C["timber"], snow=0.4)
    a.box((w + 0.5, d + 0.6, 0.06), (0, 0, 2.28), cloth, rot=(-0.25, 0, 0), bevel=0.02)
    for i in range(7):
        a.box((0.42, 0.04, 0.3), (-w / 2 - 0.05 + i * 0.52, -d / 2 - 0.32, 1.98), cloth, rot=(0.1, 0, 0))
    a.box((w + 0.3, d + 0.3, 0.1), (0, 0.05, 2.36), SNOW, rot=(-0.25, 0, 0), bevel=0.04)
    a.export()


def stall_goods():
    def goods(name, seed, fn):
        a = Asset(name, seed)
        fn(a)
        a.export()

    def furs(a):
        for i in range(5):
            col = (C["fur_brown"], C["fur_grey"], C["fur_white"], C["fur_brown"], C["fur_grey"])[i]
            a.box((0.9, 0.7, 0.09), (-1.0 + i * 0.5, -0.55, 0.92 + (i % 2) * 0.06), col, rot=(0, 0, a.rng.uniform(-0.3, 0.3)), bevel=0.04)
        for i in range(3):
            a.box((0.7, 0.05, 1.1), (-0.9 + i * 0.9, 0.9, 1.5), (C["fur_brown"], C["fur_grey"], C["fur_white"])[i], bevel=0.03)
        a.box((2.8, 0.06, 0.06), (0, 0.92, 2.1), C["timber"])

    def grain(a):
        for i in range(4):
            a.cyl(0.25, 0.55, (-1.05 + i * 0.7, -0.55, 0.9), C["sack"], segs=8, r2=0.18)
            a.sphere(0.2, (-1.05 + i * 0.7, -0.55, 1.42), C["grain"], scale=(1, 1, 0.4))
        for i in range(3):
            a.cyl(0.35, 0.8, (-0.9 + i * 0.9, 0.6, 0.0), C["sack"], segs=8, r2=0.26)

    def salt(a):
        for i in range(5):
            a.cyl(0.18, 0.4, (-1.1 + i * 0.55, -0.55, 0.9), C["cloth_grey"], segs=8, r2=0.13)
            a.sphere(0.14, (-1.1 + i * 0.55, -0.55, 1.28), C["salt"], scale=(1, 1, 0.5))
        a.box((0.6, 0.4, 0.3), (0.9, 0.6, 0.15), C["plank"])
        a.sphere(0.3, (0.9, 0.6, 0.3), C["salt"], scale=(1.0, 0.7, 0.4))

    def iron(a):
        for i in range(4):
            a.cyl(0.18, 0.18, (-1.1 + i * 0.6, -0.55, 0.92), C["iron"], segs=9, r2=0.22)
        for i in range(6):
            a.box((0.05, 0.05, 0.6), (-1.0 + i * 0.4, 0.95, 1.5), C["iron"])
            a.box((0.2, 0.05, 0.12), (-1.0 + i * 0.4, 0.95, 1.18), C["rust"])
        a.box((2.6, 0.06, 0.06), (0, 0.95, 1.85), C["timber"])
        for i in range(3):
            a.cyl(0.11, 0.04, (-0.6 + i * 0.6, -0.6, 0.95), C["rust"], segs=7)

    def pelts(a):
        # The pelt trader's rack: stretched pelts on frames.
        for i in range(3):
            x = -0.9 + i * 0.9
            a.box((0.06, 0.06, 1.6), (x - 0.35, 0.8, 1.5), C["timber"])
            a.box((0.06, 0.06, 1.6), (x + 0.35, 0.8, 1.5), C["timber"])
            a.box((0.6, 0.05, 1.2), (x, 0.82, 1.55), (C["fur_grey"], C["fur_brown"], C["fur_white"])[i], bevel=0.05)
        for i in range(3):
            a.box((0.8, 0.6, 0.08), (-0.8 + i * 0.8, -0.55, 0.93 + i * 0.03), C["fur_brown"], rot=(0, 0, 0.2 * i), bevel=0.04)
        a.box((0.5, 0.35, 0.25), (1.1, -0.5, 1.0), C["plank"], bevel=0.03)

    goods("village_goods_furs", 41, furs)
    goods("village_goods_grain", 42, grain)
    goods("village_goods_salt", 43, salt)
    goods("village_goods_iron", 44, iron)
    goods("village_goods_pelts", 45, pelts)


def bridge():
    """Stone bridge carrying the ride-north road over the frozen creek. Runs
    along Blender Y (Godot Z), 20 m long, deck top 0 at both ends rising to
    0.4 m mid-span; one low arch below. Origin at the deck centre-line, end height."""
    a = Asset("village_bridge", 30)
    ln, w = 20.0, 4.6
    segs = 10
    hump = lambda y: 0.4 * (1.0 - (2.0 * y / ln) ** 2)
    for i in range(segs):
        y0 = -ln / 2 + ln * i / segs
        y1 = y0 + ln / segs
        z0, z1 = hump(y0), hump(y1)
        ang = math.atan2(z1 - z0, y1 - y0)
        ym, zm = (y0 + y1) / 2, (z0 + z1) / 2
        seg_len = math.hypot(y1 - y0, z1 - z0) + 0.05
        a.box((w, seg_len, 0.35), (0, ym, zm - 0.175), C["stone"], rot=(ang, 0, 0), bevel=0.03, snow=0.6, jitter=0.08)
        for sx in (-1, 1):
            a.box((0.45, seg_len, 0.7), (sx * (w / 2 + 0.2), ym, zm + 0.3), C["stone_dark"], rot=(ang, 0, 0), bevel=0.06)
            a.box((0.55, seg_len, 0.14), (sx * (w / 2 + 0.2), ym, zm + 0.72), SNOW, rot=(ang, 0, 0), bevel=0.04, jitter=0.02)
    # Spandrel walls and the arch.
    for sx in (-1, 1):
        a.box((0.5, 7.0, 1.7), (sx * (w / 2 + 0.05), -6.5, -1.2), C["stone"], bevel=0.08)
        a.box((0.5, 7.0, 1.7), (sx * (w / 2 + 0.05), 6.5, -1.2), C["stone"], bevel=0.08)
    for k in range(9):
        ang = math.pi * (k + 0.5) / 9
        y = -math.cos(ang) * 3.2
        z = -2.3 + math.sin(ang) * 2.0
        a.box((w + 0.5, 1.2, 0.5), (0, y, z + 0.25), C["stone_dark"], rot=(-math.cos(ang) * 0.9, 0, 0), bevel=0.05)
    for sx in (-1, 1):
        for y in (-3.6, 3.6):
            a.box((w + 0.9, 1.4, 2.2), (0, y, -2.4), C["stone"], bevel=0.1)
    # Icicles under the arch and along the parapets.
    a.icicles(-2.0, 2.0, -3.3, -0.4, 6, (0.2, 0.6), along="x")
    a.icicles(-2.0, 2.0, 3.3, -0.4, 6, (0.2, 0.6), along="x")
    a.icicles(-9.0, 9.0, -(w / 2 + 0.45), -0.05, 10, (0.15, 0.45), along="y")
    a.icicles(-9.0, 9.0, w / 2 + 0.45, -0.05, 10, (0.15, 0.45), along="y")
    a.export()


ALL = {
    "house_timber": house_timber, "house_wattle": house_wattle, "house_long": house_long,
    "house_croft": house_croft, "shed": shed, "tavern": tavern, "tavern_interior": tavern_interior,
    "meeting_hall": meeting_hall, "debt_house": debt_house, "barn_abandoned": barn_abandoned,
    "mill": mill, "mill_wheel": mill_wheel, "bridge": bridge, "smithy": smithy, "well": well,
    "stalls": lambda: [market_stall("village_stall_grey", C["cloth_grey"], 31),
                       market_stall("village_stall_brown", C["cloth_brown"], 32),
                       market_stall("village_stall_blue", C["cloth_blue"], 33)],
    "goods": stall_goods,
}

if __name__ == "__main__":
    names = [a for a in sys.argv[1:] if a in ALL] or list(ALL)
    reset()
    for n in names:
        ALL[n]()
