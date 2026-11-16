"""The species sheets and the plants built from them (tools/grove/grove.py).

A sheet says what the species is: how it branches, its bark, its leaf, its
colours. A form says what its site made of it (grown in the open, at a wood's
edge, in a forest). A plant is a species in a form, from a seed.

Run:  <bpy python> tools/grove/plants.py [--only oak_open_a,bluebell_a] [--out dir]
"""

import os
import random
import sys

sys.path.insert(0, os.path.dirname(__file__))
import bpy  # noqa: E402
import grove as G  # noqa: E402

hexc = G.hexc

# The world's greens (the glen's turf reads about 5FBA5C in daylight): every
# plant's foot is near the ground's own colour, so it grows out of it.
TURF = (0.30, 0.60, 0.31)
MOSS = (0.44, 0.68, 0.42)
BARK = hexc("8E6A6E")           # the world's rose-taupe bark

OAK = {
    "height": 15.0, "trunk": 0.046, "kink": 22.0,
    "bark": {"trunk": G.shade(BARK, 0.86), "twig": (0.64, 0.52, 0.52), "furrow": 7.0, "contrast": 0.22,
             "moss": 0.85, "moss_height": 0.45, "moss_col": MOSS},
    "leaf": {"shape": "oak", "size": 0.62, "area": 0.36, "cover": 0.3, "cluster": 0.112, "squash": 0.72, "droop": 0.5, "cup": 0.16,
             "deep": (0.20, 0.46, 0.34), "mid": (0.40, 0.70, 0.44), "light": (0.68, 0.89, 0.56), "new": (0.86, 0.95, 0.64),
             "young": 0.3, "heart": 0.86},
    "forms": {
        # grown alone on open ground: wider than tall, boughs low and level
        "open": {"spread": 1.25, "leader": 0.52, "clear": 0.2, "boughs": 6, "hubs": 3, "rise": (8.0, 48.0), "sag": 12.0, "lift": 30.0,
                 "bough": 0.6, "low_reach": 0.82, "high_reach": 0.62, "roots": 6, "root_reach": 1.25, "lean": 0.02,
                 "crown_limbs": 4, "crown_rise": 54.0, "wood_tris": 4600},
    },
}

BIRCH = {
    "height": 13.0, "trunk": 0.017, "kink": 9.0,
    "bark": {"trunk": (0.93, 0.92, 0.89), "twig": (0.46, 0.36, 0.38), "furrow": 2.0, "contrast": 0.05,
             "band": (0.27, 0.22, 0.24), "moss": 0.3, "moss_height": 0.12, "moss_col": MOSS},
    "leaf": {"shape": "birch", "size": 0.3, "area": 0.4, "cover": 0.34, "cluster": 0.062, "squash": 1.35, "droop": 0.9, "cup": 0.12,
             "deep": (0.28, 0.56, 0.38), "mid": (0.50, 0.79, 0.50), "light": (0.78, 0.94, 0.62), "new": (0.90, 0.96, 0.68),
             "young": 0.2, "heart": 0.8},
    "forms": {
        # at a wood's edge: a straight white stem, a narrow airy crown, twigs that hang
        "edge": {"spread": 0.42, "leader": 0.84, "clear": 0.42, "boughs": 8, "hubs": 5, "rise": (34.0, 58.0), "sag": 4.0, "lift": -34.0,
                 "bough": 0.3, "low_reach": 0.95, "high_reach": 0.6, "roots": 4, "root_reach": 0.9, "lean": 0.045,
                 "crown_limbs": 3, "crown_rise": 66.0, "wood_tris": 2600},
    },
}

GRASS_GLADE = {"blades": 18, "radius": 0.17, "height": 0.2, "lean": 42.0, "width": 0.022,
               "foot": TURF, "blade": (0.33, 0.65, 0.32), "tip": (0.54, 0.81, 0.42)}
GRASS_TALL = {"blades": 14, "radius": 0.14, "height": 0.62, "lean": 30.0, "width": 0.02,
              "foot": TURF, "blade": (0.40, 0.70, 0.38), "tip": (0.74, 0.88, 0.52)}
# the sward: what covers the floor between everything else, broad soft blades in a wide low tuft
GRASS_SWARD = {"blades": 44, "radius": 0.46, "height": 0.25, "lean": 46.0, "width": 0.036,
               "foot": TURF, "blade": (0.31, 0.63, 0.31), "tip": (0.52, 0.80, 0.40)}
BLUEBELL = {"height": 0.42, "bell": 0.05, "leaf_deep": (0.22, 0.50, 0.36), "leaf": (0.38, 0.68, 0.44), "stem": (0.42, 0.44, 0.62),
            "bell_deep": (0.33, 0.35, 0.80), "bell_light": (0.64, 0.68, 0.97)}
BLUEBELL_WHITE = dict(BLUEBELL, stem=(0.50, 0.66, 0.52), bell_deep=(0.86, 0.88, 0.95), bell_light=(0.98, 0.98, 1.0))
SNOWDROP = {"height": 0.24, "petal": 0.055, "stems": 3, "leaf_deep": (0.26, 0.52, 0.42), "leaf": (0.46, 0.72, 0.56),
            "white": (0.95, 0.96, 0.93), "white_tip": (1.0, 1.0, 0.98), "green_mark": (0.45, 0.74, 0.42)}
CROCUS = {"height": 0.2, "petal": 0.085, "stems": 3, "leaf_deep": (0.24, 0.50, 0.36), "leaf": (0.44, 0.70, 0.46),
          "white": (0.93, 0.92, 0.96), "gold": (0.98, 0.72, 0.22),
          "colours": [(hexc("5B3FA8"), hexc("8F6FD8"), hexc("CDB8F2")), (hexc("5B3FA8"), hexc("8F6FD8"), hexc("CDB8F2")),
                      (hexc("E0A020"), hexc("F6C83C"), hexc("FCE48A")), (hexc("D4CCE8"), hexc("F4F1FA"), hexc("FFFFFF"))]}
FERN = {"fronds": 9, "height": 0.75, "deep": (0.18, 0.44, 0.33), "mid": (0.34, 0.64, 0.42), "light": (0.60, 0.83, 0.50)}

# plant -> (kind, sheet, form or None). The trees here are studies, built only
# by name; the glade's floor is what the court uses today.
PLANTS = {
    "grass_glade_a": ("grass", GRASS_GLADE, None),
    "grass_glade_b": ("grass", GRASS_GLADE, None),
    "grass_glade_c": ("grass", GRASS_GLADE, None),
    "grass_tall_a": ("grass", GRASS_TALL, None),
    "grass_tall_b": ("grass", GRASS_TALL, None),
    "grass_sward_a": ("grass", GRASS_SWARD, None),
    "grass_sward_b": ("grass", GRASS_SWARD, None),
    "grass_sward_c": ("grass", GRASS_SWARD, None),
    # the glen's three flowers (book ch 18), as the patches a drift is laid from: (kind, sheet, plants, radius m)
    "bluebell_patch_a": ("patch", BLUEBELL, ("bluebell", 9, 0.42)),
    "bluebell_patch_b": ("patch", BLUEBELL, ("bluebell", 9, 0.42)),
    "bluebell_patch_c": ("patch", BLUEBELL, ("bluebell", 6, 0.34)),
    # the odd white one among the blue
    "bluebell_white": ("patch", BLUEBELL_WHITE, ("bluebell", 3, 0.16)),
    "snowdrop_patch_a": ("patch", SNOWDROP, ("snowdrop", 6, 0.3)),
    "snowdrop_patch_b": ("patch", SNOWDROP, ("snowdrop", 4, 0.24)),
    "crocus_patch_a": ("patch", CROCUS, ("crocus", 6, 0.34)),
    "crocus_patch_b": ("patch", CROCUS, ("crocus", 6, 0.34)),
    "crocus_patch_c": ("patch", CROCUS, ("crocus", 4, 0.26)),
    "fern_a": ("fern", FERN, None),
    "fern_b": ("fern", FERN, None),
    "fern_c": ("fern", FERN, None),
}
STUDIES = {
    "oak_open_a": ("tree", OAK, "open"),
    "birch_edge_a": ("tree", BIRCH, "edge"),
    "bluebell_a": ("bluebell", BLUEBELL, None),
    "snowdrop_a": ("snowdrop", SNOWDROP, None),
    "crocus_a": ("crocus", CROCUS, None),
}
# what a patch's far cushion is topped with, and how high it stands: kind -> (colours, height)
FAR = {
    "bluebell": lambda sh: ([G.mix(sh["leaf"], sh["bell_deep"], 0.6), G.mix(sh["bell_deep"], sh["bell_light"], 0.5),
                             G.mix(sh["bell_deep"], sh["bell_light"], 0.7), G.mix(sh["leaf"], sh["bell_light"], 0.45)], sh["height"] * 0.6),
    "snowdrop": lambda sh: ([sh["white"], G.mix(sh["leaf"], sh["white"], 0.6), G.mix(sh["leaf"], sh["white"], 0.4)], sh["height"] * 0.8),
    "crocus": lambda sh: ([G.mix(sh["leaf"], c[1], 0.75) for c in sh["colours"]] + [sh["leaf"]], sh["height"] * 0.7),
}
SMALL = {"grass": G.grass, "bluebell": G.bluebell, "snowdrop": G.snowdrop, "crocus": G.crocus, "fern": G.fern}


def build(name, out_dir):
    kind, sheet, form = (PLANTS.get(name) or STUDIES[name])
    bpy.ops.wm.read_factory_settings(use_empty=True)
    rng = random.Random(sum(ord(c) * (i + 1) for i, c in enumerate(name)))
    if kind == "tree":
        (verts, faces), soft, facts = G.tree(sheet, form, rng)
        objs = [G.wood_object(verts, faces), G.soft_object(soft)]
        note = "wood %5d  soft %6d  %.1f m tall, %.1f m across, trunk %.2f m, %d clusters" % (
            len(faces), soft.tris(), facts["height"], facts["spread"] * 2.0, facts["trunk"] * 2.0, facts["clusters"])
    elif kind == "patch":
        of, count, radius = form
        soft = G.patch(SMALL[of], sheet, rng, count, radius)
        objs = [G.soft_object(soft)]
        note = "soft %6d" % soft.tris()
        size = G.export(name, objs, out_dir)
        print("%-16s %s  %5.0f KB" % (name, note, size / 1024.0))
        # and the same patch from far off
        bpy.ops.wm.read_factory_settings(use_empty=True)
        tops, height = FAR[of](sheet)
        far = G.far_patch(tops, G.mix(sheet["leaf_deep"], sheet["leaf"], 0.5), height, radius, rng)
        name, objs, note = name + "_far", [G.soft_object(far)], "soft %6d" % far.tris()
    else:
        soft = SMALL[kind](sheet, rng)
        objs = [G.soft_object(soft)]
        note = "soft %6d" % soft.tris()
    size = G.export(name, objs, out_dir)
    print("%-16s %s  %5.0f KB" % (name, note, size / 1024.0))


def main():
    out_dir = sys.argv[sys.argv.index("--out") + 1] if "--out" in sys.argv else G.OUT
    only = sys.argv[sys.argv.index("--only") + 1].split(",") if "--only" in sys.argv else list(PLANTS)
    for name in only:
        build(name, out_dir)


if __name__ == "__main__":
    main()
