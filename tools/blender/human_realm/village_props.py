"""Village props and small finds (headless bpy). Run:
    bpyenv/bin/python tools/blender/human_realm/village_props.py [name ...]
Writes world/human_realm/village/assets/<name>.glb (origin at base centre).
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from village_lib import C, SNOW, Asset, reset  # noqa: E402

PROPS = {}


def prop(fn):
    PROPS[fn.__name__] = fn
    return fn


@prop
def fence_wattle():
    """2.5 m woven hazel hurdle between two stakes."""
    a = Asset("village_fence_wattle", 51)
    for x in (-1.25, 1.25):
        a.box((0.1, 0.1, 1.3), (x, 0, 0.65), C["timber"], rot=(0, a.rng.uniform(-0.05, 0.05), 0))
    for i in range(6):
        z = 0.2 + i * 0.17
        a.box((2.5, 0.07, 0.12), (0, 0.03 * (-1) ** i, z), C["plank_old"], bevel=0.02, jitter=0.12)
    a.box((2.6, 0.18, 0.08), (0, 0, 1.18), SNOW, bevel=0.03)
    PROPS_EXPORT(a)


@prop
def fence_rail():
    """3 m split-rail fence section."""
    a = Asset("village_fence_rail", 52)
    for x in (-1.5, 1.5):
        a.box((0.14, 0.14, 1.25), (x, 0, 0.62), C["timber_grey"], rot=(0, a.rng.uniform(-0.06, 0.06), 0), bevel=0.02)
        a.box((0.2, 0.2, 0.08), (x, 0, 1.28), SNOW, bevel=0.03)
    for z in (0.45, 0.95):
        a.box((3.1, 0.1, 0.12), (0, 0.05, z), C["timber_grey"], rot=(0, a.rng.uniform(-0.03, 0.03), 0), bevel=0.02, snow=1.0)
    PROPS_EXPORT(a)


@prop
def shrine():
    """Wayside shrine: a stone pillar niche with a little roof, candle stubs and
    a wreath of holly. Superstitious offerings against what lies past the Wall."""
    a = Asset("village_shrine", 53)
    a.box((1.4, 1.0, 0.4), (0, 0, 0.2), C["stone_dark"], bevel=0.08, snow=1.0)
    a.box((0.9, 0.7, 1.6), (0, 0, 1.2), C["stone"], bevel=0.08)
    a.box((0.6, 0.12, 0.7), (0, -0.33, 1.35), C["black"], jitter=0.0)
    a.gable_fill(1.1, 0.9, 2.0, 0.5, C["stone"])
    a.gable_roof(1.1, 0.9, 2.0, 0.5, C["stone_dark"], overhang=0.15, thick=0.1, snow_depth=0.12)
    for i in range(4):
        a.cyl(0.04, 0.08 + 0.05 * i, (-0.25 + i * 0.17, -0.45, 0.4), C["bone"], segs=6)
    a.cyl(0.2, 0.06, (0, -0.37, 1.85), (0.10, 0.24, 0.14), rot=(math.pi / 2, 0, 0), segs=10)
    for i in range(5):
        ang = i / 5 * math.tau
        a.sphere(0.035, (math.cos(ang) * 0.2, -0.41, 1.85 + math.sin(ang) * 0.2), C["red"], subdiv=1)
    PROPS_EXPORT(a)


@prop
def pillory():
    a = Asset("village_pillory", 54)
    a.box((1.2, 1.2, 0.3), (0, 0, 0.15), C["plank"], bevel=0.04, snow=1.0)
    a.box((0.22, 0.22, 2.2), (0, 0, 1.25), C["timber"])
    a.box((1.5, 0.18, 0.35), (0, 0, 1.75), C["timber"], bevel=0.03, snow=1.0)
    for x in (-0.45, 0.0, 0.45):
        a.cyl(0.08 if x else 0.11, 0.2, (x, 0.1, 1.75), C["black"], rot=(math.pi / 2, 0, 0), segs=8)
    a.box((0.06, 0.2, 0.2), (0.7, 0, 1.75), C["iron"])
    PROPS_EXPORT(a)


@prop
def notice_board():
    """Notice board with a little roof: debts, tithes, a warning about the Wall."""
    a = Asset("village_notice_board", 55)
    for x in (-0.9, 0.9):
        a.box((0.14, 0.14, 2.4), (x, 0, 1.2), C["timber"])
    a.box((1.8, 0.08, 1.1), (0, 0, 1.45), C["plank"], bevel=0.02)
    for i in range(6):
        col = (C["cloth_pale"], C["bone"], C["salt"])[i % 3]
        a.box((a.rng.uniform(0.25, 0.4), 0.02, a.rng.uniform(0.3, 0.45)),
              (-0.6 + i * 0.24, -0.05, 1.45 + a.rng.uniform(-0.25, 0.25)), col, rot=(0, a.rng.uniform(-0.15, 0.15), 0), jitter=0.0)
    a.box((2.2, 0.6, 0.08), (0, 0, 2.45), C["shingle"], rot=(0.2, 0, 0), snow=1.0)
    a.box((2.1, 0.5, 0.1), (0, 0.02, 2.53), SNOW, rot=(0.2, 0, 0), bevel=0.04)
    PROPS_EXPORT(a)


@prop
def lantern_post():
    a = Asset("village_lantern_post", 56)
    a.box((0.16, 0.16, 2.8), (0, 0, 1.4), C["timber"])
    a.box((0.7, 0.1, 0.1), (0.3, 0, 2.7), C["timber"])
    a.box((0.03, 0.03, 0.2), (0.55, 0, 2.55), C["iron"])
    a.box((0.22, 0.22, 0.3), (0.55, 0, 2.3), C["glass_warm"], jitter=0.0)
    a.cyl(0.16, 0.12, (0.55, 0, 2.45), C["iron"], segs=4, r2=0.02, rot=(0, 0, math.pi / 4))
    a.box((0.26, 0.26, 0.04), (0.55, 0, 2.14), C["iron"])
    a.box((0.2, 0.2, 0.06), (0, 0, 2.83), SNOW, bevel=0.03)
    PROPS_EXPORT(a)


@prop
def woodpile():
    """Split logs stacked against cross-stakes, snow on top."""
    a = Asset("village_woodpile", 57)
    for row in range(4):
        for i in range(7 - row):
            a.cyl(0.13, 0.9, (-0.85 + i * 0.27 + row * 0.13, -0.45, 0.13 + row * 0.23), C["plank"], rot=(-math.pi / 2, 0, a.rng.uniform(-0.1, 0.1)), segs=6)
    a.box((2.0, 1.0, 0.12), (0.0, 0.0, 1.0), SNOW, bevel=0.05)
    for x in (-1.1, 1.1):
        a.box((0.08, 0.08, 1.2), (x, 0, 0.6), C["timber"])
    a.cyl(0.3, 0.45, (1.6, -0.2, 0), C["plank"], segs=9, snow=1.0)
    a.box((0.05, 0.05, 0.6), (1.6, -0.2, 0.7), C["timber"], rot=(0.4, 0, 0))
    a.box((0.2, 0.05, 0.12), (1.6, -0.3, 0.95), C["iron"], rot=(0.4, 0, 0))
    PROPS_EXPORT(a)


@prop
def washing_line():
    """Two poles and a line of frozen-stiff laundry."""
    a = Asset("village_washing_line", 58)
    for x in (-3.0, 3.0):
        a.box((0.1, 0.1, 2.0), (x, 0, 1.0), C["timber_grey"])
    a.box((6.0, 0.02, 0.02), (0, 0, 1.92), C["cloth_brown"], jitter=0.0)
    cols = (C["cloth_pale"], C["cloth_grey"], C["cloth_blue"], C["cloth_pale"], C["cloth_brown"], C["bone"])
    for i, col in enumerate(cols):
        w = a.rng.uniform(0.5, 0.9)
        h = a.rng.uniform(0.6, 1.0)
        a.box((w, 0.05, h), (-2.3 + i * 0.9, 0, 1.92 - h / 2), col, rot=(0, a.rng.uniform(-0.08, 0.08), 0), bevel=0.02)
        a.box((w, 0.08, 0.05), (-2.3 + i * 0.9, 0, 1.94), SNOW, jitter=0.0)
    PROPS_EXPORT(a)


@prop
def cart():
    a = Asset("village_cart", 59)
    a.box((2.2, 1.4, 0.12), (0, 0, 0.75), C["plank"], bevel=0.03, snow=1.0)
    for y in (-0.7, 0.7):
        a.box((2.2, 0.08, 0.45), (0, y, 1.0), C["plank"], bevel=0.02)
    a.box((0.08, 1.4, 0.45), (-1.1, 0, 1.0), C["plank"])
    for y in (-0.78, 0.78):
        a.cyl(0.55, 0.1, (0, y, 0.55), C["timber"], rot=(math.pi / 2, 0, 0), segs=12)
        a.cyl(0.12, 0.14, (0, y, 0.55), C["iron"], rot=(math.pi / 2, 0, 0), segs=8)
    for y in (-0.35, 0.35):
        a.box((2.2, 0.08, 0.08), (2.0, y, 0.55), C["timber"], rot=(0, 0.25, 0))
    a.box((2.0, 1.2, 0.18), (0, 0, 1.15), SNOW, bevel=0.06)
    a.cyl(0.3, 0.6, (-0.5, 0.2, 0.81), C["sack"], segs=8, r2=0.22)
    PROPS_EXPORT(a)


@prop
def barrel():
    a = Asset("village_barrel", 60)
    a.cyl(0.36, 0.45, (0, 0, 0), C["plank"], segs=10, r2=0.42)
    a.cyl(0.42, 0.45, (0, 0, 0.45), C["plank"], segs=10, r2=0.36)
    for z in (0.12, 0.45, 0.78):
        a.cyl(0.43 if z == 0.45 else 0.4, 0.05, (0, 0, z), C["iron"], segs=10)
    a.cyl(0.33, 0.08, (0, 0, 0.88), SNOW, segs=10, r2=0.2)
    PROPS_EXPORT(a)


@prop
def crate():
    a = Asset("village_crate", 61)
    a.box((0.8, 0.8, 0.7), (0, 0, 0.35), C["plank"], bevel=0.03)
    for y in (-0.41, 0.41):
        a.box((0.82, 0.03, 0.1), (0, y, 0.35), C["timber"], rot=(0, 0.7, 0))
    a.box((0.7, 0.7, 0.1), (0, 0, 0.74), SNOW, bevel=0.04)
    PROPS_EXPORT(a)


@prop
def chicken_coop():
    a = Asset("village_chicken_coop", 62)
    for x in (-0.8, 0.8):
        for y in (-0.5, 0.5):
            a.box((0.1, 0.1, 0.6), (x, y, 0.3), C["timber"])
    a.box((1.8, 1.2, 0.8), (0, 0, 1.0), C["plank_old"], bevel=0.03)
    a.box((2.0, 1.5, 0.08), (0, 0, 1.48), C["plank"], rot=(0.15, 0, 0), snow=1.0)
    a.box((1.9, 1.4, 0.12), (0, 0.02, 1.58), SNOW, rot=(0.15, 0, 0), bevel=0.05)
    a.box((0.3, 0.05, 0.35), (0.4, -0.62, 0.95), C["black"], jitter=0.0)
    a.box((0.25, 1.0, 0.04), (0.4, -1.0, 0.4), C["plank"], rot=(0.45, 0, 0))
    a.sphere(0.13, (-0.5, -0.9, 0.12), C["bone"], scale=(1.2, 0.9, 0.9))
    a.sphere(0.07, (-0.38, -0.95, 0.24), C["bone"])
    a.box((0.04, 0.05, 0.05), (-0.31, -0.95, 0.24), C["gold"])
    PROPS_EXPORT(a)


@prop
def haystack():
    a = Asset("village_haystack", 63)
    a.cyl(1.4, 1.6, (0, 0, 0), C["straw"], segs=12, r2=1.2)
    a.cyl(1.2, 1.3, (0, 0, 1.6), C["straw"], segs=12, r2=0.1)
    a.cyl(1.0, 0.9, (0, 0, 1.95), SNOW, segs=12, r2=0.12)
    a.box((0.08, 0.08, 3.4), (0, 0, 1.7), C["timber"])
    PROPS_EXPORT(a)


@prop
def trough():
    """Frozen water trough by the well."""
    a = Asset("village_trough", 64)
    a.box((2.0, 0.7, 0.55), (0, 0, 0.35), C["plank"], bevel=0.04)
    a.box((1.85, 0.55, 0.05), (0, 0, 0.6), C["ice"], jitter=0.0)
    for x in (-0.8, 0.8):
        a.box((0.12, 0.8, 0.15), (x, 0, 0.07), C["timber"])
    a.icicles(-0.9, 0.9, -0.37, 0.6, 6, (0.08, 0.25))
    PROPS_EXPORT(a)


# --- small finds, forage props and notice-moment subjects -----------------

@prop
def salt_sack():
    a = Asset("village_salt_sack", 70)
    a.cyl(0.22, 0.38, (0, 0, 0), C["sack"], segs=8, r2=0.17)
    a.sphere(0.16, (0, 0, 0.38), C["salt"], scale=(1, 1, 0.45))
    a.sphere(0.06, (0.24, 0.05, 0.03), C["salt"], scale=(1.4, 1, 0.4))
    PROPS_EXPORT(a)


@prop
def herb_bundle():
    """Dried herb bundle hung from a nail, tied with twine."""
    a = Asset("village_herb_bundle", 71)
    for i in range(7):
        ang = i / 7 * math.tau
        a.cyl(0.015, 0.45, (math.cos(ang) * 0.04, math.sin(ang) * 0.04, 0.0), C["thatch"] if i % 2 else (0.34, 0.38, 0.26), segs=4, rot=(math.cos(ang) * 0.18, math.sin(ang) * 0.18, 0))
    a.cyl(0.05, 0.05, (0, 0, 0.32), C["cloth_brown"], segs=6)
    for i in range(4):
        a.sphere(0.04, (math.cos(i) * 0.07, math.sin(i) * 0.07, 0.04), (0.36, 0.42, 0.30), subdiv=1)
    PROPS_EXPORT(a)


@prop
def iron_filings():
    """A heap of iron filings and scale on a scrap of leather."""
    a = Asset("village_iron_filings", 72)
    a.box((0.45, 0.35, 0.02), (0, 0, 0.01), C["cloth_brown"], rot=(0, 0, 0.2), jitter=0.0)
    a.sphere(0.13, (0, 0, 0.02), C["iron"], scale=(1.2, 1.0, 0.4))
    for i in range(6):
        a.box((0.05, 0.02, 0.01), (a.rng.uniform(-0.18, 0.18), a.rng.uniform(-0.12, 0.12), 0.03), C["rust"], rot=(0, 0, a.rng.uniform(0, 3)))
    PROPS_EXPORT(a)


@prop
def coin():
    a = Asset("village_coin", 73)
    a.cyl(0.035, 0.008, (0, 0, 0.0), C["cloth_grey"], segs=10)
    a.cyl(0.03, 0.008, (0.05, 0.02, 0.0), C["rust"], segs=10, rot=(0.2, 0, 0))
    a.sphere(0.06, (0, 0, -0.03), SNOW, scale=(1.4, 1.4, 0.4), subdiv=1)
    PROPS_EXPORT(a)


@prop
def pamphlet():
    """A Children of the Blessed pamphlet: pale paper, a gilt sun-disc."""
    a = Asset("village_pamphlet", 74)
    a.box((0.16, 0.22, 0.006), (0, 0, 0.004), C["cloth_pale"], jitter=0.0)
    a.box((0.16, 0.22, 0.006), (0.075, 0.0, 0.03), C["bone"], rot=(0, -0.4, 0), jitter=0.0)
    a.cyl(0.03, 0.003, (0, 0.03, 0.008), C["gold"], segs=10)
    PROPS_EXPORT(a)


@prop
def carved_toy():
    """A child's carved wooden horse, dropped in the snow."""
    a = Asset("village_carved_toy", 75)
    a.box((0.16, 0.06, 0.07), (0, 0, 0.1), C["plank"], bevel=0.015)
    for x in (-0.06, 0.06):
        for y in (-0.02, 0.02):
            a.box((0.02, 0.02, 0.07), (x, y, 0.035), C["plank"])
    a.box((0.04, 0.04, 0.08), (0.08, 0, 0.16), C["plank"], rot=(0, 0.4, 0))
    a.box((0.06, 0.035, 0.035), (0.11, 0, 0.2), C["plank"], bevel=0.008)
    a.box((0.02, 0.01, 0.06), (-0.09, 0, 0.09), C["cloth_brown"], rot=(0, 0.5, 0))
    PROPS_EXPORT(a)


@prop
def ribbon():
    """A frozen red ribbon snagged and curled in the snow."""
    a = Asset("village_ribbon", 76)
    for i in range(6):
        a.box((0.09, 0.03, 0.004), (i * 0.07, math.sin(i * 1.3) * 0.04, 0.01 + 0.012 * math.sin(i)), C["red"], rot=(0.3 * math.sin(i), 0, math.cos(i * 1.3) * 0.6), jitter=0.0)
    PROPS_EXPORT(a)


@prop
def lost_button():
    a = Asset("village_lost_button", 77)
    a.cyl(0.02, 0.006, (0, 0, 0), C["bone"], segs=8)
    for x in (-0.006, 0.006):
        a.cyl(0.003, 0.008, (x, 0, 0), C["black"], segs=4)
    PROPS_EXPORT(a)


@prop
def iron_charm():
    """A ward against the fae: iron nails bound in a cross with red thread."""
    a = Asset("village_iron_charm", 78)
    a.box((0.012, 0.012, 0.14), (0, 0, 0.07), C["iron"], rot=(0, math.pi / 2, 0.3))
    a.box((0.012, 0.012, 0.14), (0, 0, 0.075), C["iron"], rot=(0, math.pi / 2, -0.9))
    a.sphere(0.014, (0, 0, 0.075), C["red"], subdiv=1)
    PROPS_EXPORT(a)


@prop
def snowman():
    """Children's snowman: coal eyes, a stick arm, a scrap of scarf."""
    a = Asset("village_snowman", 79)
    a.sphere(0.45, (0, 0, 0.4), SNOW)
    a.sphere(0.33, (0, 0, 1.0), SNOW)
    a.sphere(0.23, (0, 0, 1.45), SNOW)
    for x in (-0.08, 0.08):
        a.sphere(0.03, (x, -0.21, 1.5), C["black"], subdiv=1)
    a.cyl(0.03, 0.15, (0, -0.2, 1.43), C["rust"], r2=0.004, rot=(math.pi / 2, 0, 0), segs=5)
    a.box((0.6, 0.03, 0.03), (0.4, 0, 1.1), C["timber"], rot=(0, -0.5, 0))
    a.cyl(0.25, 0.08, (0, 0, 1.24), C["cloth_blue"], segs=10)
    PROPS_EXPORT(a)


@prop
def cat():
    """A grey cat curled tight against the cold."""
    a = Asset("village_cat", 80)
    a.sphere(0.18, (0, 0, 0.1), C["fur_grey"], scale=(1.3, 1.0, 0.6))
    a.sphere(0.09, (0.18, -0.05, 0.16), C["fur_grey"])
    for y in (-0.09, -0.01):
        a.cyl(0.03, 0.06, (0.2, y, 0.22), C["fur_grey"], r2=0.003, segs=4)
    a.cyl(0.035, 0.32, (-0.05, 0.14, 0.04), C["fur_grey"], rot=(0, math.pi / 2, 0.4), segs=6)
    PROPS_EXPORT(a)


@prop
def crow():
    a = Asset("village_crow", 81)
    a.sphere(0.09, (0, 0, 0.12), C["black"], scale=(1.6, 0.9, 0.9))
    a.sphere(0.06, (0.12, 0, 0.2), C["black"])
    a.cyl(0.025, 0.07, (0.17, 0, 0.2), C["iron"], r2=0.002, rot=(0, math.pi / 2, 0), segs=4)
    a.box((0.14, 0.06, 0.02), (-0.17, 0, 0.12), C["black"], rot=(0, 0.25, 0))
    for y in (-0.03, 0.03):
        a.box((0.01, 0.01, 0.07), (0.0, y, 0.035), C["iron"])
    PROPS_EXPORT(a)


@prop
def robin():
    """A robin on a post: the only red in the lane."""
    a = Asset("village_robin", 82)
    a.sphere(0.06, (0, 0, 0.08), C["fur_brown"], scale=(1.2, 1.0, 1.0))
    a.sphere(0.045, (0.04, 0, 0.075), C["red"], scale=(0.8, 0.9, 0.9))
    a.sphere(0.035, (0.05, 0, 0.13), C["fur_brown"])
    a.cyl(0.01, 0.03, (0.08, 0, 0.13), C["black"], r2=0.001, rot=(0, math.pi / 2, 0), segs=4)
    PROPS_EXPORT(a)


@prop
def fox_tracks():
    """A line of fox prints pressed into the snow (dark blue-grey dimples)."""
    a = Asset("village_fox_tracks", 83)
    for i in range(10):
        x = i * 0.35
        y = 0.06 * (-1) ** i
        a.sphere(0.045, (x, y, 0.0), (0.55, 0.60, 0.70), scale=(1.2, 1.0, 0.12), subdiv=1)
        for k in range(4):
            a.sphere(0.015, (x + 0.06, y + (k - 1.5) * 0.02, 0.0), (0.55, 0.60, 0.70), scale=(1, 1, 0.2), subdiv=1)
    PROPS_EXPORT(a)


@prop
def candle_offering():
    """Melted candle stubs and a bone token at the foot of the shrine."""
    a = Asset("village_candle_offering", 84)
    for i in range(3):
        a.cyl(0.03, 0.06 + i * 0.03, (i * 0.08, 0, 0), C["bone"], segs=6)
        a.cyl(0.003, 0.02, (i * 0.08, 0, 0.06 + i * 0.03), C["black"], segs=3)
    a.box((0.05, 0.03, 0.01), (0.1, 0.08, 0.005), C["bone"], rot=(0, 0, 0.6))
    PROPS_EXPORT(a)


def PROPS_EXPORT(a):
    a.export()


if __name__ == "__main__":
    names = [n for n in sys.argv[1:] if n in PROPS] or list(PROPS)
    reset()
    for n in names:
        PROPS[n]()
