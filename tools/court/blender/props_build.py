"""Generate every wider-Spring-Court prop, landmark piece and collectible as embedded glTF.

Usage (bpy venv python):
    $BPY tools/court/blender/props_build.py -- [--out world/spring_court/wider/assets/props] [--only id1,id2]

The single data table TABLE below drives everything: one row per asset id
(id, kind, region, builder, params). Each asset gets a seed from crc32(id), so
reruns are byte-identical. Per asset the file holds:
    <id>        base mesh (origin at base centre, +Y up, metres, COLOR_0 RGBA, alpha 1 = glow)
    <id>_LOD1   decimated to ~50 %
    <id>_col    collision (exported as "<id>_col-colonly": Godot makes a StaticBody3D, layer 1)
    <id>_climb  climbable quads for the traversal system (watchtowers only)
and props_manifest.json lists them all.
"""
import os
import sys
import json
import random
import zlib

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402
import props_lib as L  # noqa: E402
import props_export as E  # noqa: E402
import props_shapes_a as A  # noqa: E402
import props_shapes_b as B  # noqa: E402
import props_shapes_c as Cc  # noqa: E402
from props_lib import C  # noqa: E402

BUDGET = {"collectible": 600}
DEFAULT_BUDGET = 3000
LOD_RATIO = 0.5

LM, ST, PR, CO = "landmark", "structure", "prop", "collectible"
RITE, FELLS, VIL, SOL, SHR, AUT, BLI, ANY, POOL = (
    "hill_of_the_rite", "fells", "fae_village", "solstice_meadow", "old_shrines", "autumn_border", "blight", "any", "starlight_pool")

TABLE = [
    # ---------------- Hill of the Rite
    ("rite_standing_stone_a", LM, RITE, A.standing_stone, dict(h=4.2, w=1.5, d=0.8, spirals=2, ribbon="rose")),
    ("rite_standing_stone_b", LM, RITE, A.standing_stone, dict(h=3.4, w=1.3, d=0.75, lean=4, spirals=1)),
    ("rite_standing_stone_c", LM, RITE, A.standing_stone, dict(h=5.0, w=1.6, d=0.9, spirals=2, ribbon="lilac")),
    ("rite_standing_stone_d", LM, RITE, A.standing_stone, dict(h=3.0, w=1.7, d=0.85, lean=-6, spirals=1, ribbon="butter")),
    ("rite_standing_stone_e", LM, RITE, A.standing_stone, dict(h=4.6, w=1.2, d=0.7, spirals=2)),
    ("rite_altar_stone", LM, RITE, A.altar_stone, {}),
    ("rite_cave_mouth", LM, RITE, A.cave_mouth, {}),
    ("rite_cave_wall_a", ST, RITE, A.cave_wall, dict(length=6.0, height=4.0, curve=0.8)),
    ("rite_cave_wall_b", ST, RITE, A.cave_wall, dict(length=5.0, height=5.0, curve=1.4)),
    ("rite_cave_wall_c", ST, RITE, A.cave_wall, dict(length=7.0, height=3.2, curve=0.3)),
    ("rite_cave_pillar", ST, RITE, A.cave_pillar, {}),
    ("rite_cave_pool_rim", ST, RITE, A.cave_pool_rim, {}),
    ("rite_bonfire", PR, RITE, A.bonfire, {}),
    ("rite_drum", PR, RITE, A.rite_drum, {}),
    ("rite_terrace_wall", ST, RITE, A.terrace_wall, {}),
    ("rite_ribbon_pole", PR, RITE, A.ribbon_pole, {}),
    # ---------------- watchtower & fells
    ("watchtower_base", LM, FELLS, A.watchtower_base, {}),
    ("watchtower_stair", LM, FELLS, A.watchtower_stair, {}),
    ("watchtower_top", LM, FELLS, A.watchtower_top, {}),
    ("watchtower_ruined", LM, FELLS, A.watchtower_ruined, {}),
    ("fells_cairn", PR, FELLS, A.fells_cairn, {}),
    ("fells_sheepfold_wall", ST, FELLS, A.sheepfold_wall, {}),
    ("fells_overlook_bench", PR, FELLS, A.overlook_bench, {}),
    ("escarpment_rock_a", LM, FELLS, A.escarpment_rock, dict(sx=7.0, sy=4.0, sz=6.0, parts=4)),
    ("escarpment_rock_b", LM, FELLS, A.escarpment_rock, dict(sx=9.0, sy=5.0, sz=4.5, parts=5)),
    ("escarpment_rock_c", LM, FELLS, A.escarpment_rock, dict(sx=5.0, sy=4.0, sz=8.0, parts=3)),
    # ---------------- fae village
    ("fae_cottage_a", ST, VIL, B.fae_cottage, dict(wall="butter", roof="rose", style="cone")),
    ("fae_cottage_b", ST, VIL, B.fae_cottage, dict(wall="mint", roof="lilac", style="cone", r=2.3, door="rose")),
    ("fae_cottage_c", ST, VIL, B.fae_cottage, dict(wall="butter", roof="peri", style="tiered", r=2.8, door="lilac")),
    ("fae_cottage_d", ST, VIL, B.fae_cottage, dict(wall="mint", roof="coral", style="mushroom", r=2.4, door="butter")),
    ("fae_seamstress_shop", ST, VIL, B.fae_seamstress_shop, {}),
    ("fae_potion_house", ST, VIL, B.fae_potion_house, {}),
    ("fae_market_stall_a", PR, VIL, B.fae_market_stall, dict(canopy=("rose", "cream"), goods="fruit")),
    ("fae_market_stall_b", PR, VIL, B.fae_market_stall, dict(canopy=("lilac", "butter"), goods="cloth")),
    ("fae_market_stall_c", PR, VIL, B.fae_market_stall, dict(canopy=("mint", "cream"), goods="pottery")),
    ("fae_well", ST, VIL, B.fae_well, {}),
    ("fae_footbridge", ST, VIL, B.fae_footbridge, {}),
    ("fae_lantern_post", PR, VIL, B.fae_lantern_post, {}),
    ("fae_bunting", PR, VIL, B.fae_bunting, {}),
    ("fae_mill", ST, VIL, B.fae_mill, {}),
    ("fae_bench", PR, VIL, B.fae_bench, {}),
    ("fae_flower_cart", PR, VIL, B.fae_flower_cart, {}),
    ("fae_bakery", ST, VIL, B.fae_bakery, {}),
    # ---------------- solstice
    ("solstice_flower_arch", ST, SOL, B.solstice_flower_arch, {}),
    ("solstice_musicians_bower", ST, SOL, B.solstice_musicians_bower, {}),
    ("solstice_dance_ring_stone", PR, SOL, B.solstice_dance_ring_stone, {}),
    ("solstice_maypole", LM, SOL, B.solstice_maypole, {}),
    ("solstice_long_table", PR, SOL, B.solstice_long_table, {}),
    ("solstice_lantern_string", PR, SOL, B.solstice_lantern_string, {}),
    # ---------------- Old Shrines
    ("shrine_column", ST, SHR, B.shrine_column, {}),
    ("shrine_column_broken", ST, SHR, B.shrine_column_broken, {}),
    ("shrine_wall_mural", ST, SHR, B.shrine_wall_mural, {}),
    ("shrine_altar", ST, SHR, B.shrine_altar, {}),
    ("shrine_arch", ST, SHR, B.shrine_arch, {}),
    ("shrine_steps", ST, SHR, B.shrine_steps, {}),
    # ---------------- autumn border
    ("autumn_pass_gate", LM, AUT, B.autumn_pass_gate, {}),
    ("autumn_border_marker", PR, AUT, B.autumn_border_marker, {}),
    ("autumn_fallen_log", PR, AUT, B.autumn_fallen_log, {}),
    # ---------------- blight
    ("blight_dead_stump", PR, BLI, B.blight_dead_stump, {}),
    ("blight_broken_arbor", PR, BLI, B.blight_broken_arbor, {}),
    ("blight_mask_pile", PR, BLI, B.blight_mask_pile, {}),
    ("blight_withered_fence", PR, BLI, B.blight_withered_fence, {}),
    ("blight_bone_rock", PR, BLI, B.blight_bone_rock, {}),
    # ---------------- generic
    ("rock_mossy_a", PR, ANY, B.rock_mossy, dict(s=1.4, hue="pearl_lilac", flowers=4)),
    ("rock_mossy_b", PR, ANY, B.rock_mossy, dict(s=0.8, hue="pearl_rose", flowers=3)),
    ("rock_mossy_c", PR, ANY, B.rock_mossy, dict(s=2.2, hue="stone_pale", flowers=6)),
    ("rock_mossy_d", PR, ANY, B.rock_mossy, dict(s=1.1, hue="pearl", flowers=2)),
    ("rock_pebble_cluster", PR, ANY, B.rock_pebble_cluster, {}),
    ("fence_rail", PR, ANY, B.fence_rail, {}),
    ("stepping_stones", PR, ANY, B.stepping_stones, {}),
    ("wooden_footbridge_small", ST, ANY, B.wooden_footbridge_small, {}),
    ("starlight_pool_rim_stone_a", PR, POOL, B.starlight_rim_stone, dict(s=1.0)),
    ("starlight_pool_rim_stone_b", PR, POOL, B.starlight_rim_stone, dict(s=1.5)),
    ("starlight_pool_rim_stone_c", PR, POOL, B.starlight_rim_stone, dict(s=0.7)),
    ("pool_glow_crystal", PR, POOL, B.pool_glow_crystal, {}),
]

# ---------------- collectibles / forage (region hint = where they are usually scattered)
_COL = [
    ("col_shell_river_mussel", "riverbanks", Cc.shell_mussel, {}),
    ("col_snail_spiral", "meadows", Cc.snail_spiral, {}),
    ("col_odd_stone", "riverbanks", Cc.hagstone, {}),
    ("col_stone_quartz", FELLS, Cc.crystal_cluster, dict(cols=("white", "blush"))),
    ("col_stone_amber", "woods", Cc.amber, {}),
    ("col_stone_garnet", FELLS, Cc.gem, dict(col="crimson")),
    ("col_stone_obsidian", RITE, Cc.obsidian, {}),
    ("col_stone_starglass", POOL, Cc.crystal_cluster, dict(cols=("glow_star", "glow_lilac"), n=5, h=0.1, glow=True)),
    ("col_stone_fossil", FELLS, Cc.fossil, {}),
    ("col_painted_pebble", VIL, Cc.painted_pebble, {}),
    ("col_mask_shard", BLI, Cc.mask_shard, {}),
    ("col_mural_chip", SHR, Cc.mural_chip, {}),
    ("col_coin_old", SHR, Cc.coin, {}),
    ("col_calanmai_ribbon", RITE, Cc.ribbon_coil, dict(cols=("red", "gold"))),
    ("col_solstice_bead", SOL, Cc.solstice_bead, {}),
    ("col_leaf_gilded", "woods", Cc.leaf, dict(col="gold", vein="butter")),
    ("col_acorn_carved", "woods", Cc.acorn, {}),
    ("ing_shed_antler", "woods", Cc.antler, dict(scale=1.2, tines=3)),
    ("col_wool_tuft", FELLS, Cc.wool_tuft, {}),
    ("col_glass_bead", VIL, Cc.glass_bead, {}),
    ("col_candle_stub", SHR, Cc.candle_stub, {}),
    ("col_beetle_jewel", "meadows", Cc.beetle, {}),
    ("col_snake_skin", FELLS, Cc.snake_skin, {}),
    ("col_driftwood", "riverbanks", Cc.driftwood, {}),
    ("col_robin_egg_shell", "woods", Cc.robin_egg, {}),
    ("col_seed_pod", "meadows", Cc.seed_pod, {}),
    ("col_bone_bleached", FELLS, Cc.bone, {}),
    ("col_pinecone", "woods", Cc.pinecone, {}),
    ("ing_red_ochre", FELLS, Cc.lump, dict(col=C("b8452f"), s=0.1, flecks_col="au_gold")),
    ("ing_chalk", FELLS, Cc.lump, dict(col="white", s=0.09, n=3)),
    ("ing_lapis_shard", SHR, Cc.lump, dict(col=C("2f4fb8"), s=0.07, flecks_col="gold", n=1)),
    ("ing_river_silt", "riverbanks", Cc.lump, dict(col=C("b39a80"), s=0.16, n=3, flecks_col="cream")),
    ("ing_salt", "riverbanks", Cc.salt, {}),
    ("ing_iron_filings", FELLS, Cc.iron_filings, {}),
    ("ing_starlight_water", POOL, Cc.starlight_water, {}),
    ("ing_rite_spring", RITE, Cc.rite_spring, {}),
    ("ing_rose_maze_dew", "rose_maze", Cc.rose_dew, {}),
    ("ing_honey", "woods", Cc.honey, {}),
    ("col_fae_bell", VIL, Cc.fae_bell, {}),
    ("col_heart_stone", "riverbanks", Cc.heart_stone, {}),
    ("ing_flint", FELLS, Cc.flint, {}),
    ("ing_charcoal", RITE, Cc.lump, dict(col=C("231f26"), s=0.07, flecks_col="rust", n=3)),
    ("col_river_pearl", "riverbanks", Cc.river_pearl, {}),
    ("col_horseshoe", VIL, Cc.horseshoe, {}),
    ("col_carved_bird", VIL, Cc.carved_bird, {}),
    ("col_seed_packet", VIL, Cc.seed_packet, {}),
    ("col_ribbon_scrap", SOL, Cc.ribbon_scrap, {}),
    ("col_rose_petal_pressed", "rose_maze", Cc.pressed_petal, {}),
    ("col_antler_tine", "woods", Cc.antler, dict(scale=0.6, tines=1)),
    ("ing_snail_shell", "meadows", Cc.snail_spiral, dict(col="cream", band="wood")),
    ("ing_clay", "riverbanks", Cc.lump, dict(col=C("d4a59a"), s=0.11, n=2)),
]
for _fid, _kw in Cc.FEATHERS.items():
    _region = {"col_feather_kingfisher": "riverbanks", "col_feather_swan": "riverbanks", "col_feather_heron": "riverbanks",
               "ing_crow_feather": BLI, "ing_hawk_feather": FELLS}.get(_fid, "woods")
    _COL.append((_fid, _region, Cc.feather, _kw))
TABLE += [(i, CO, r, fn, kw) for i, r, fn, kw in _COL]


# modular pieces: placed at the transform of another asset plus a vertical offset
STACK = {"watchtower_stair": ("watchtower_base", 0.0), "watchtower_top": ("watchtower_base", 13.0)}


def seed_for(asset_id: str) -> int:
    return zlib.crc32(asset_id.encode("utf-8"))


def bounds(mb):
    xs = [v.x for v in mb.v]
    ys = [v.y for v in mb.v]
    zs = [v.z for v in mb.v]
    return (min(xs), min(ys), min(zs)), (max(xs), max(ys), max(zs))


def build_one(row, out_dir: str) -> dict:
    asset_id, kind, region, fn, params = row
    rng = random.Random(seed_for(asset_id))
    mb = L.MB()
    extra: dict = {}
    fn(mb, rng, extra, **params)
    lo, hi = bounds(mb)
    if extra.get("keep_origin"):
        offset = Vector((0.0, 0.0, 0.0))  # modular pieces built around a shared origin
    else:
        offset = Vector((-(lo[0] + hi[0]) / 2, -(lo[1] + hi[1]) / 2, -lo[2]))
    E.reset_scene()
    base = E.mb_to_object(asset_id, mb, offset)
    lod = E.make_lod(base, asset_id + "_LOD1", LOD_RATIO)
    objs = [base, lod]
    if "col" in extra:
        objs.append(E.mb_to_object(asset_id + "_col-colonly", extra["col"], offset))
    if "climb" in extra:
        objs.append(E.mb_to_object(asset_id + "_climb", extra["climb"], offset))
    tris, tris_lod = E.tri_count(base), E.tri_count(lod)
    budget = BUDGET.get(kind, DEFAULT_BUDGET)
    if tris > budget:
        raise SystemExit("BUDGET %s: %d tris > %d" % (asset_id, tris, budget))
    glows = any(c[3] > 0.5 for c in mb.c)
    E.export(os.path.join(out_dir, asset_id + ".gltf"), objs)
    size = (hi[0] - lo[0], hi[2] - lo[2], hi[1] - lo[1])  # Godot axes: x, y(up), z
    entry = {
        "id": asset_id, "kind": kind, "region": region, "tris": tris, "tris_lod1": tris_lod,
        "size_m": [round(s, 3) for s in size], "glows": glows, "climbable": "climb" in extra,
        "collision": "col" in extra, "file": asset_id + ".gltf",
    }
    if asset_id in STACK:
        entry["stack_on"], entry["stack_offset_y"] = STACK[asset_id]
    if extra.get("keep_origin"):
        lo_g = (lo[0], lo[2], -hi[1])
        entry["aabb_min"] = [round(v, 3) for v in lo_g]
    return entry


def main() -> None:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    here = os.path.dirname(os.path.abspath(__file__))
    root = os.path.abspath(os.path.join(here, "..", "..", ".."))
    out_dir = os.path.join(root, "world", "spring_court", "wider", "assets", "props")
    only = None
    for i, a in enumerate(argv):
        if a == "--out":
            out_dir = os.path.abspath(argv[i + 1])
        if a == "--only":
            only = set(argv[i + 1].split(","))
    os.makedirs(out_dir, exist_ok=True)
    ids = [r[0] for r in TABLE]
    if len(ids) != len(set(ids)):
        raise SystemExit("duplicate ids in TABLE")
    entries = []
    for row in TABLE:
        if only and row[0] not in only:
            continue
        entries.append(build_one(row, out_dir))
        e = entries[-1]
        print("ASSET %-30s %-11s tris %5d lod %5d size %s%s" % (e["id"], e["kind"], e["tris"], e["tris_lod1"], e["size_m"], " glow" if e["glows"] else ""))
    if only is None:
        manifest = {"version": 1, "front": "+Z", "up": "+Y", "units": "m",
                    "generator": "tools/court/blender/props_build.py", "assets": entries}
        with open(os.path.join(out_dir, "props_manifest.json"), "w", encoding="utf-8") as f:
            json.dump(manifest, f, indent=1, sort_keys=True)
            f.write("\n")
        print("WROTE %d assets" % len(entries))


if __name__ == "__main__":
    main()
