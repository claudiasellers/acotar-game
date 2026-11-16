"""Mix the L21 Blender flora (tools/woods/blender/spring_flora.py) into the
Spring Court woods biomes. Idempotent: it sets each listed species' weight
in the biome's trees/shrubs/detail dictionary and leaves everything else.

Run:  python3 tools/woods/spring_flora_mix.py

Placement follows the book (lore/02-locations/spring-woods.md): the deep
woods stay oak, elm and beech; the candy-coloured trees and flowering
shrubs gather in clearings, glades, edges and by water. Horror biomes
(reed marsh, dread margin, Bogge's wood, blight edge, naga reeds) get
nothing, so the contrast holds (R3).

The magnolias (tools/woods/blender/special_trees.py; owner, 2026-11-12: "a
mix of both ... or one region that has a mix and one region has only one
kind"): the Border Woods grow the rose magnolia and the harlequin together,
the Eastern Woods the rose one alone.
"""

import os
import re

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "data", "regions", "spring_court")

MIX = {
    "border_woods": {
        "spring_woodland": {
            "trees": {"candyfloss_tree": 1.0, "wisteria_tree": 0.8},
            "shrubs": {"peony_bush": 0.6, "hydrangea": 0.7, "azalea": 0.7},
            "detail": {"forget_me_not": 1.2, "tulip_patch": 0.6, "pansy_patch": 0.5},
        },
        "bluebell_glade": {
            "trees": {"magnolia": 0.6, "magnolia_harlequin": 0.6, "candyfloss_tree": 0.6},
            "shrubs": {"hydrangea": 0.6, "iris_clump": 0.6},
            "detail": {"forget_me_not": 2.0, "allium": 0.6},
        },
        "foxglove_clearing": {
            "trees": {"golden_chain": 0.8, "magnolia": 0.4, "magnolia_harlequin": 0.4},
            "shrubs": {"spire_bed": 2.2, "lupin_clump": 0, "goldenrod": 0, "lavender_mound": 0, "peony_bush": 0.6},
            "detail": {"tulip_patch": 1.2, "daffodil": 0.8, "maidens_lace": 1.0, "pansy_patch": 0.5},
        },
        "rose_brake": {
            "trees": {"wisteria_tree": 1.0, "candyfloss_tree": 0.8},
            "shrubs": {"peony_bush": 1.3, "azalea": 0.9, "sugarberry_bush": 0},
            "detail": {"tulip_patch": 0.8, "forget_me_not": 0.6},
        },
        "faelight_hollow": {
            "shrubs": {"hydrangea": 0.5},
            "detail": {"forget_me_not": 0.8},
        },
        "brook": {
            "shrubs": {"iris_clump": 1.2},
            "detail": {"forget_me_not": 1.0},
        },
        "wall_verge": {
            "shrubs": {"spire_bed": 1.8, "goldenrod": 0, "lupin_clump": 0, "lavender_mound": 0},
            "detail": {"daffodil": 0.6, "maidens_lace": 0.6},
        },
        "crocus_knoll": {
            "trees": {"candyfloss_tree": 0.6},
            "shrubs": {"azalea": 0.5},
            "detail": {"daffodil": 0.8, "tulip_patch": 0.4},
        },
    },
    "eastern_woods": {
        "deep_wood": {
            "trees": {"wisteria_tree": 0.4},
            "shrubs": {"hydrangea": 0.5},
            "detail": {"forget_me_not": 0.6},
        },
        "fern_hollow": {
            "shrubs": {"hydrangea": 0.4},
            "detail": {"forget_me_not": 0.5},
        },
        "stream_glen": {
            "trees": {"golden_chain": 1.0, "magnolia": 0.8},
            "shrubs": {"iris_clump": 1.0, "lupin_clump": 1.0, "peony_bush": 0.6, "goldenrod": 0.6},
            "detail": {"tulip_patch": 1.0, "maidens_lace": 0.8, "daffodil": 0.6},
        },
        "stream_shallows": {
            "shrubs": {"iris_clump": 1.2},
            "detail": {"forget_me_not": 1.0},
        },
        "woods_edge": {
            "trees": {"candyfloss_tree": 1.0, "wisteria_tree": 0.8},
            "shrubs": {"azalea": 0.8, "peony_bush": 0.8, "sugarberry_bush": 0.6, "lavender_mound": 0.5, "hydrangea": 0.6},
            "detail": {"tulip_patch": 1.0, "pansy_patch": 0.6, "allium": 0.5},
        },
    },
    "suriel_glade": {
        "young_birches": {
            "shrubs": {"hydrangea": 0.4},
            "detail": {"forget_me_not": 1.0, "allium": 0.4, "pansy_patch": 0.4},
        },
        "snare_glade": {
            "shrubs": {"lupin_clump": 0.8, "goldenrod": 0.6, "peony_bush": 0.4},
            "detail": {"maidens_lace": 1.0, "daffodil": 0.6, "tulip_patch": 0.6},
        },
        "thornwater_banks": {
            "shrubs": {"iris_clump": 1.0},
            "detail": {"forget_me_not": 0.8},
        },
    },
}


def fmt(v):
    return ("%g" % v) if v != int(v) else "%.1f" % v


def set_weights(line, key, weights):
    m = re.match(r'^%s = \{(.*)\}$' % key, line)
    assert m, line
    body = m.group(1).strip()
    items = [] if not body else [tuple(p.split(": ")) for p in re.split(r", (?=&\")", body)]
    d = {k: v for k, v in items}
    for sp, w in weights.items():
        if w == 0:  # 0 removes a species (L21-4 merged some into spire_bed)
            d.pop('&"%s"' % sp, None)
        else:
            d['&"%s"' % sp] = fmt(w)
    return "%s = {%s}" % (key, ", ".join("%s: %s" % kv for kv in d.items()))


def main():
    for region, biomes in MIX.items():
        path = os.path.join(ROOT, region + "_biomes.tres")
        lines = open(path).read().split("\n")
        current = None
        for i, line in enumerate(lines):
            m = re.match(r'^id = &"(\w+)"$', line)
            if m:
                current = m.group(1)
                continue
            for key in ("trees", "shrubs", "detail"):
                if current in biomes and key in biomes[current] and line.startswith(key + " = {"):
                    lines[i] = set_weights(line, key, biomes[current][key])
        missing = set(biomes) - set(re.findall(r'^id = &"(\w+)"$', "\n".join(lines), re.M))
        assert not missing, missing
        open(path, "w").write("\n".join(lines))
        print(region, "ok")


if __name__ == "__main__":
    main()
