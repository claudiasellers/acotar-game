"""Writes the woods regions' biome tables (data/regions/spring_court/<id>_biomes.tres).

Run:  python3 tools/woods/write_biomes.py
Blossom trees are crab apple (canon) rather than wild cherry. Deterministic. Edit the tables below, rerun, commit the .tres. Ground colours
are snapped toward the experience-bar §2.2 palette (pastel biomes) or its
horror swatches (dread biomes) so no biome strays into lime.
"""
import colorsys
import os

ROOT = os.path.join(os.path.dirname(__file__), "..", "..", "data", "regions", "spring_court")
os.makedirs(ROOT, exist_ok=True)


def hexc(h):
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


PASTEL_GROUND = [hexc(h) for h in ("8DBF7A", "7CC29A", "4F9A82", "B5E3C0", "C9A98A", "3E6F78")]
HORROR_GROUND = [hexc(h) for h in ("0E1612", "1F2B22", "3B2340", "9AA36A", "5A4F5E")]
HORROR_AMBIENCE = {"mist", "ash_motes"}


def snap(col, horror):
    """Pulls a ground colour 75% of the way to its nearest palette swatch."""
    pal = HORROR_GROUND if horror else PASTEL_GROUND
    best = min(pal, key=lambda p: sum((p[i] - col[i]) ** 2 for i in range(3)))
    return tuple(round(col[i] + (best[i] - col[i]) * 0.75, 3) for i in range(3))

def d(x): return "{"+", ".join(f'&"{k}": {float(v)}' for k,v in x.items())+"}"
def c(t): return f"Color({t[0]}, {t[1]}, {t[2]}, 1)"

VIS = {
 "ing_wild_hyacinth":"bluebell","ing_foxglove":"foxglove","ing_honeysuckle":"honeysuckle_bush","ing_elderflower":"elderflower_sprig",
 "ing_wild_strawberry":"strawberry_patch","ing_blackberry":"bramble","ing_faelight_dandelion":"faelight_dandelion","ing_moss":"starmoss",
 "ing_rose_red":"rose_bush_red","ing_rose_white":"rose_bush_white","ing_thornbriar_sap":"sap_briar","ing_willow_bark":"bark_strip",
 "ing_oak_gall":"oak_gall_twig","ing_crocus":"crocus","ing_snowdrop":"snowdrop","ing_madder":"madder_root","ing_honey":"wild_hive","ing_glowcap":"glowcap",
 "ing_hawk_feather":"feather_hawk","ing_owl_feather":"feather_owl","ing_snail_shell":"snail_shell","ing_river_silt":"silt_patch",
 "ing_wood_sorrel":"wood_sorrel","ing_wild_garlic":"wild_garlic","ing_hazelnut":"hazelnuts","ing_violet":"violet","ing_primrose":"primrose",
 "ing_meadowsweet":"meadowsweet","ing_water_mint":"water_mint","ing_hollow_root":"hollow_root","ing_trout":"trout_pool",
 "ing_rose_hip":"rose_hips","ing_blighted_petals":"blighted_bloom","ing_iron_filings":"rusted_iron",
 "col_odd_stone":"odd_stone","col_painted_pebble":"painted_pebble","col_jay_feather":"feather_jay","col_shed_antler":"shed_antler",
 "col_robin_egg_shell":"egg_shell","col_acorn_caps":"acorn_caps","col_old_arrowhead":"old_arrowhead","col_mask_ribbon":"mask_ribbon",
 "col_river_glass":"river_glass","col_bone_charm":"bone_charm",
}
RESPAWN = {k:(0 if k.startswith("col_") else 2) for k in VIS}
RESPAWN.update({"ing_honey":4,"ing_trout":1,"ing_faelight_dandelion":1,"ing_glowcap":1,"ing_iron_filings":0,"ing_hawk_feather":3,"ing_owl_feather":3,"ing_snail_shell":2})

GRASS={"grass_tuft":6,"tall_grass":2,"clover":1}
BORDER=[
 dict(id="spring_woodland",notes="Mixed oak, beech and birch woodland, sun-dappled, flower-strewn. The default Border Woods.",
  g=(0.42,0.66,0.32),g2=(0.52,0.72,0.36),td=0.011,t={"oak":3,"beech":3,"elm":1.5,"silver_birch":2,"hawthorn":1,"crab_apple":3,"lilac_tree":0.8,"yew":1},
  sd=0.045,s={"fern":3,"bracken":1,"hazel":1.5,"honeysuckle_bush":1,"bramble":1,"mossy_rock":1,"fallen_log":0.4,"foxglove":0.6,"moss_mound":1,"stump":0.4},
  dd=1.8,dt={**GRASS,"bluebell":2,"crocus":1,"snowdrop":0.6,"wood_anemone":2,"primrose":1.5,"violet":1,"leaf_litter":1.5,"wild_garlic":1,"moss_patch":1,"toadstools":0.3},
  fh=18,f={"ing_wild_hyacinth":3,"ing_wood_sorrel":2,"ing_wild_garlic":2,"ing_violet":2,"ing_primrose":2,"ing_hazelnut":1.5,"ing_honeysuckle":1.5,
   "ing_oak_gall":1.5,"ing_blackberry":1,"ing_snail_shell":1,"ing_hawk_feather":0.6,"ing_owl_feather":0.6,"ing_honey":0.4,"ing_moss":1,
   "col_odd_stone":0.6,"col_acorn_caps":1,"col_jay_feather":0.6,"col_robin_egg_shell":0.5,"col_painted_pebble":0.25,"col_mask_ribbon":0.15},
  amb=["pollen","petals","butterflies","songbirds","sparkles"]),
 dict(id="ancient_oak_wood",notes="[X] Huge ancient oaks with buttress roots you walk along; deep moss, ferns, glowing starmoss.",
  g=(0.36,0.62,0.34),g2=(0.30,0.52,0.30),td=0.0065,t={"ancient_oak":2,"oak":2,"elm":1,"beech":1,"yew":1.5},
  sd=0.06,s={"fern":4,"root_arch":1.2,"moss_mound":3,"mossy_rock":2,"fallen_log":1,"boulder":0.4,"stump":0.6},
  dd=1.4,dt={"moss_patch":4,"leaf_litter":2,"grass_tuft":1,"wood_anemone":2,"bluebell":1,"toadstools":1,"glowcap":0.4,"violet":1},
  fh=20,f={"ing_moss":3,"ing_oak_gall":2.5,"ing_glowcap":1.5,"ing_wood_sorrel":2,"ing_owl_feather":1,"ing_snail_shell":1.5,"ing_honey":0.8,
   "ing_hazelnut":1,"ing_violet":1,"col_acorn_caps":2,"col_odd_stone":0.8,"col_shed_antler":0.4,"col_jay_feather":0.8,"col_painted_pebble":0.3},
  amb=["faelights","pollen","songbirds","sparkles"]),
 dict(id="bluebell_glade",notes="[X] Birch-ringed glades carpeted in bluebells (wild hyacinth) and anemones.",
  g=(0.44,0.62,0.50),g2=(0.50,0.58,0.70),td=0.005,t={"silver_birch":4,"beech":1,"crab_apple":2,"lilac_tree":1},
  sd=0.02,s={"fern":1,"mossy_rock":1,"hazel":0.5},
  dd=2.6,dt={"bluebell":10,"wood_anemone":3,"grass_tuft":2,"violet":1,"primrose":1},
  fh=22,f={"ing_wild_hyacinth":6,"ing_violet":2,"ing_primrose":2,"ing_wood_sorrel":1,"ing_snail_shell":1,"col_robin_egg_shell":0.8,
   "col_painted_pebble":0.5,"col_jay_feather":0.5,"ing_hawk_feather":0.3},
  amb=["butterflies","petals","pollen","sparkles"]),
 dict(id="foxglove_clearing",notes="[X] Open sunny clearings: foxglove spires, wild strawberries, elder in flower, honeysuckle tangles. The moonstone ring stands in one.",
  g=(0.52,0.74,0.36),g2=(0.62,0.78,0.40),td=0.0018,t={"hawthorn":3,"lilac_tree":2.5,"crab_apple":2},
  sd=0.05,s={"foxglove":5,"honeysuckle_bush":2,"bramble":1.5,"rose_bush_red":0.6,"mossy_rock":0.5},
  dd=2.4,dt={"tall_grass":4,"grass_tuft":3,"buttercup":2,"daisy":2,"cowslip":1.5,"clover":1.5,"meadowsweet":0.6},
  fh=24,f={"ing_foxglove":4,"ing_wild_strawberry":4,"ing_elderflower":3,"ing_honeysuckle":2,"ing_blackberry":2,"ing_meadowsweet":1,
   "ing_madder":1,"ing_honey":0.6,"ing_hawk_feather":0.6,"col_odd_stone":0.5,"col_robin_egg_shell":0.4,"col_painted_pebble":0.4},
  amb=["butterflies","pollen","petals","songbirds","sparkles"]),
 dict(id="rose_brake",notes="[X] Wild rose thickets spilling south from the manor's gardens (the Rosewild's edge): red and white roses, thornbriar.",
  g=(0.50,0.70,0.38),g2=(0.62,0.66,0.42),td=0.003,t={"hawthorn":2,"oak":1,"crab_apple":3.5,"lilac_tree":1},
  sd=0.07,s={"rose_bush_red":4,"rose_bush_white":3,"thornbriar":2,"bramble":1,"honeysuckle_bush":1},
  dd=2.0,dt={"grass_tuft":4,"tall_grass":2,"daisy":2,"clover":2,"buttercup":1},
  fh=22,f={"ing_rose_red":5,"ing_rose_white":4,"ing_thornbriar_sap":3,"ing_honeysuckle":2,"ing_blackberry":1.5,"ing_wild_strawberry":1,
   "col_mask_ribbon":0.6,"col_painted_pebble":0.4,"col_odd_stone":0.4,"ing_snail_shell":0.6},
  amb=["petals","butterflies","sparkles","pollen"]),
 dict(id="faelight_hollow",notes="[X] A deep mossy hollow where faelight dandelions grow thick; at dusk the seeds rise as drifting lights.",
  g=(0.34,0.60,0.42),g2=(0.40,0.66,0.54),td=0.004,t={"silver_birch":2,"willow":1,"ancient_oak":0.5,"yew":1},
  sd=0.05,s={"moss_mound":4,"fern":2,"mossy_rock":2,"root_arch":0.6},
  dd=2.4,dt={"faelight_dandelion":7,"moss_patch":3,"glowcap":2,"wood_anemone":1,"grass_tuft":1},
  fh=26,f={"ing_faelight_dandelion":7,"ing_moss":3,"ing_glowcap":3,"ing_wood_sorrel":1,"ing_snail_shell":1,"col_odd_stone":1,"col_river_glass":0.5},
  amb=["faelights","fireflies","sparkles"]),
 dict(id="brook",notes="[X] The Border Woods brook: willows, alders, mint and meadowsweet; silt and river glass in the shallows.",
  g=(0.38,0.58,0.36),g2=(0.46,0.50,0.38),td=0.007,t={"willow":3,"silver_birch":2},
  sd=0.06,s={"reed_clump":2,"cattail":1,"mossy_rock":2,"fern":1},
  dd=2.0,dt={"water_mint":2,"meadowsweet":2,"grass_tuft":3,"pebbles":2,"lily_pad":1,"moss_patch":1},
  fh=26,f={"ing_willow_bark":3,"ing_water_mint":3,"ing_meadowsweet":2,"ing_river_silt":2,"ing_snail_shell":1.5,"col_river_glass":1.2,"col_odd_stone":1},
  amb=["dragonflies","fish","butterflies","sparkles"]),
 dict(id="wall_verge",notes="Open verge along the Wall: hawthorn and meadow, the sentries' path. First sight of the court after the crossing.",
  g=(0.56,0.74,0.40),g2=(0.66,0.76,0.44),td=0.0015,t={"hawthorn":3,"crab_apple":3},
  sd=0.02,s={"boulder":1,"honeysuckle_bush":1,"bramble":1,"foxglove":1},
  dd=2.6,dt={"tall_grass":5,"grass_tuft":3,"buttercup":3,"daisy":3,"cowslip":2,"clover":2},
  fh=16,f={"ing_wild_strawberry":3,"ing_elderflower":1,"ing_blackberry":1.5,"ing_hawk_feather":1,"ing_meadowsweet":1,"col_old_arrowhead":1,
   "col_odd_stone":0.6,"col_mask_ribbon":0.3},
  amb=["butterflies","pollen","songbirds","petals"]),
 dict(id="crocus_knoll",notes="[C]-flavoured (ch18 picnic glen: tall oaks, drifting dandelion fluff, a floor of crocuses, snowdrops and bluebells in thick golden light). A sunny knoll ringed by tall oaks.",
  g=(0.56,0.74,0.42),g2=(0.64,0.76,0.50),td=0.004,t={"oak":3,"elm":1,"beech":1,"crab_apple":0.5},
  sd=0.015,s={"mossy_rock":1,"hazel":1,"honeysuckle_bush":0.5},
  dd=2.8,dt={"crocus":5,"snowdrop":3,"bluebell":3,"faelight_dandelion":1.5,"grass_tuft":3,"daisy":1},
  fh=24,f={"ing_wild_hyacinth":3,"ing_crocus":3,"ing_snowdrop":2,"ing_faelight_dandelion":2,"ing_wild_strawberry":1.5,"ing_hazelnut":1,"ing_honey":0.6,
   "col_robin_egg_shell":0.6,"col_odd_stone":0.6,"col_painted_pebble":0.4,"ing_hawk_feather":0.5},
  amb=["pollen","butterflies","petals","sparkles","songbirds"]),
]

GE=dict(GRASS)
EASTERN=[
 dict(id="deep_wood",notes="Old mixed woods east of the manor: tall, green-gold, deceptive (book: lush and dangerous).",
  g=(0.38,0.60,0.32),g2=(0.32,0.52,0.30),td=0.013,t={"oak":3,"beech":3,"elm":1.5,"ancient_oak":0.6,"silver_birch":1,"hawthorn":0.5,"yew":2,"leaning_trunk":1},
  sd=0.05,s={"fern":4,"bracken":1,"hazel":1,"mossy_rock":1.5,"fallen_log":0.8,"moss_mound":1.5,"root_arch":0.4,"foxglove":0.4},
  dd=1.5,dt={"leaf_litter":3,"moss_patch":2,"grass_tuft":2,"wood_anemone":1.5,"bluebell":1,"toadstools":0.5,"glowcap":0.4,"violet":0.6},
  fh=18,f={"ing_glowcap":2,"ing_hollow_root":2,"ing_oak_gall":1.5,"ing_wood_sorrel":2,"ing_hazelnut":1.5,"ing_moss":1.5,"ing_wild_hyacinth":1,
   "ing_owl_feather":1,"ing_honey":0.5,"ing_snail_shell":1,"col_acorn_caps":1.5,"col_jay_feather":0.8,"col_shed_antler":0.4,"col_odd_stone":0.6},
  amb=["pollen","songbirds","faelights","sparkles"]),
 dict(id="beech_hall",notes="[X] Cathedral-like beech stands with smooth grey trunks and a gold-green roof; open floor of leaf litter and anemones.",
  g=(0.56,0.56,0.34),g2=(0.62,0.52,0.32),td=0.009,t={"beech":6,"oak":1,"yew":0.5},
  sd=0.015,s={"mossy_rock":1,"fern":1,"fallen_log":0.5},
  dd=1.2,dt={"leaf_litter":5,"wood_anemone":3,"moss_patch":1,"wild_garlic":1.5},
  fh=15,f={"ing_wild_garlic":3,"ing_wood_sorrel":2,"ing_hazelnut":1,"ing_glowcap":0.8,"col_acorn_caps":1,"col_jay_feather":1,"col_odd_stone":0.6,"col_painted_pebble":0.3},
  amb=["pollen","songbirds","sparkles"]),
 dict(id="fern_hollow",notes="[X] Damp hollows drowned in ferns and moss, glowcaps under the logs.",
  g=(0.30,0.56,0.34),g2=(0.34,0.60,0.40),td=0.008,t={"alder":2,"silver_birch":1,"oak":1},
  sd=0.09,s={"fern":7,"bracken":2,"moss_mound":2,"fallen_log":1,"mossy_rock":1},
  dd=1.6,dt={"moss_patch":4,"glowcap":2,"toadstools":1,"leaf_litter":2},
  fh=20,f={"ing_glowcap":3,"ing_moss":3,"ing_hollow_root":2,"ing_snail_shell":2,"ing_wood_sorrel":1,"col_odd_stone":0.6},
  amb=["fireflies","faelights","sparkles"]),
 dict(id="stream_glen",notes="[X] A quiet grassy glen by the stream, standing stones half sunk in the grass.",
  g=(0.52,0.72,0.40),g2=(0.58,0.70,0.44),td=0.0008,t={"hawthorn":1,"elder":1},
  sd=0.012,s={"standing_stone":0.5,"mossy_rock":1,"foxglove":1},
  dd=2.4,dt={"tall_grass":4,"grass_tuft":3,"buttercup":2,"cowslip":2,"daisy":1},
  fh=14,f={"ing_wild_strawberry":2,"ing_elderflower":2,"ing_meadowsweet":2,"ing_foxglove":1,"col_odd_stone":1,"ing_hawk_feather":0.6},
  amb=["butterflies","pollen","sparkles"]),
 dict(id="stream_shallows",notes="[X] Clear shallows over pebbles: willows, mint, trout holding in the eddies, river glass.",
  g=(0.40,0.60,0.38),g2=(0.52,0.52,0.40),td=0.006,t={"willow":3,"alder":3},
  sd=0.06,s={"reed_clump":1.5,"cattail":1,"mossy_rock":2,"boulder":0.5},
  dd=2.0,dt={"pebbles":3,"water_mint":2,"meadowsweet":1.5,"grass_tuft":2,"lily_pad":1},
  fh=26,f={"ing_trout":3,"ing_willow_bark":2.5,"ing_river_silt":2,"ing_water_mint":2,"ing_meadowsweet":1,"ing_snail_shell":1,"col_river_glass":1.5,"col_odd_stone":1},
  amb=["dragonflies","fish","butterflies","sparkles"]),
 dict(id="reed_marsh",notes="[C?] naga ambush ground. Horror exception: dark water, tall reeds closing over your head, grey light, no sparkle, frogs then silence.",
  g=(0.26,0.32,0.24),g2=(0.22,0.26,0.22),td=0.002,t={"twisted_dead":1,"alder":1},
  sd=0.16,s={"reed_clump":8,"cattail":4},
  dd=1.6,dt={"grey_grass":3,"lily_pad":1,"dead_leaves":1},
  fh=12,f={"ing_river_silt":3,"ing_willow_bark":1,"ing_hollow_root":1,"col_bone_charm":0.5,"col_old_arrowhead":0.6},
  amb=["mist"]),
 dict(id="dread_margin",notes="The readable tip into Bogge territory: trees thin and go grey, flowers fade, birdsong stops.",
  g=(0.34,0.40,0.30),g2=(0.30,0.32,0.28),td=0.012,t={"twisted_dead":2,"blighted_tree":2,"oak":1},
  sd=0.03,s={"withered_bush":2,"pale_fungus":1},
  dd=1.2,dt={"grey_grass":3,"dead_leaves":3,"leaf_litter":1},
  fh=10,f={"ing_hollow_root":2,"ing_foxglove":1,"ing_owl_feather":1,"col_bone_charm":0.6,"col_shed_antler":0.3},
  amb=["mist"]),
 dict(id="bogge_territory",notes="[C] Horror exception. The Bogge's wood: black twisted trees, pale fungus, thick fog, silence. Do not look.",
  g=(0.18,0.19,0.18),g2=(0.14,0.15,0.15),td=0.016,t={"twisted_dead":5,"blighted_tree":1},
  sd=0.04,s={"pale_fungus":3,"withered_bush":1},
  dd=1.0,dt={"dead_leaves":4,"grey_grass":2},
  fh=6,f={"ing_hollow_root":2,"ing_iron_filings":1,"col_bone_charm":1},
  amb=["mist"]),
 dict(id="woods_edge",notes="[X] The woods' edge facing the estate: blossom, hedgerow and meadow. (Keeper: the puca is in the garden, not here.)",
  g=(0.54,0.76,0.40),g2=(0.64,0.78,0.42),td=0.004,t={"hawthorn":2,"elder":1,"oak":1,"crab_apple":5,"lilac_tree":2},
  sd=0.04,s={"honeysuckle_bush":2,"rose_bush_white":1,"rose_bush_red":1,"bramble":1.5,"foxglove":1},
  dd=2.6,dt={"tall_grass":4,"grass_tuft":3,"buttercup":2,"daisy":2,"cowslip":1,"clover":2},
  fh=20,f={"ing_wild_strawberry":3,"ing_blackberry":2,"ing_honeysuckle":2,"ing_elderflower":2,"ing_rose_white":1,"ing_madder":1,
   "ing_violet":1,"ing_primrose":1,"col_painted_pebble":0.5,"col_robin_egg_shell":0.6,"col_mask_ribbon":0.3},
  amb=["butterflies","petals","pollen","songbirds","sparkles"]),
 dict(id="blight_edge",notes="[C] blight / [X] expression: the eastern border where spring sickens: grey petals, rose hips (time moves here), thornbriar.",
  g=(0.44,0.46,0.38),g2=(0.40,0.40,0.36),td=0.008,t={"blighted_tree":4,"oak":1,"hawthorn":1},
  sd=0.05,s={"withered_bush":3,"thornbriar":2,"rose_bush_red":0.5},
  dd=1.4,dt={"grey_grass":4,"grass_tuft":1,"dead_leaves":2},
  fh=16,f={"ing_rose_hip":4,"ing_blighted_petals":4,"ing_thornbriar_sap":2,"ing_blackberry":1,"col_bone_charm":0.3,"col_odd_stone":0.5},
  amb=["ash_motes"]),
]

def write(region, provider_path, cls, biomes, seed, name):
    region_file=region+"_biomes"
    lines=[]
    n=len(biomes)
    lines.append(f'[gd_resource type="Resource" script_class="WoodsRegionDef" load_steps={n+4} format=3]\n')
    lines.append('[ext_resource type="Script" path="res://world/spring_court/shared/woods_region_def.gd" id="1_def"]')
    lines.append('[ext_resource type="Script" path="res://world/spring_court/shared/woods_biome.gd" id="2_biome"]')
    lines.append(f'[ext_resource type="Script" path="{provider_path}" id="3_provider"]\n')
    for i,b in enumerate(biomes):
        lines.append(f'[sub_resource type="Resource" id="b_{b["id"]}"]')
        lines.append('script = ExtResource("2_biome")')
        lines.append(f'id = &"{b["id"]}"')
        lines.append('notes = "'+b["notes"].replace('"','\\"')+'"')
        horror = bool(HORROR_AMBIENCE & set(b["amb"])) or b["id"] in ("dread_margin",)
        lines.append(f'ground_color = {c(snap(b["g"], horror))}')
        lines.append(f'ground_color_alt = {c(snap(b["g2"], horror))}')
        lines.append(f'tree_density = {b["td"]}')
        lines.append(f'trees = {d(b["t"])}')
        lines.append(f'shrub_density = {b["sd"]}')
        lines.append(f'shrubs = {d(b["s"])}')
        lines.append(f'detail_density = {b["dd"]}')
        lines.append(f'detail = {d(b["dt"])}')
        lines.append(f'forage_per_hectare = {float(b["fh"])}')
        lines.append(f'forage = {d(b["f"])}')
        lines.append('ambience = PackedStringArray('+", ".join(f'"{a}"' for a in b["amb"])+')\n')
    used=set(k for b in biomes for k in b["f"])
    vis={k:VIS[k] for k in sorted(used)}
    rs={k:RESPAWN[k] for k in sorted(used)}
    lines.append('[resource]')
    lines.append('script = ExtResource("1_def")')
    lines.append(f'region_id = &"{region}"')
    lines.append(f'display_name = "{name}"')
    lines.append('provider = ExtResource("3_provider")')
    lines.append(f'seed = {seed}')
    lines.append('biomes = Array[ExtResource("2_biome")]('+'['+", ".join(f'SubResource("b_{b["id"]}")' for b in biomes)+'])')
    lines.append('forage_visuals = {'+", ".join(f'&"{k}": &"{v}"' for k,v in vis.items())+'}')
    lines.append('respawn_days = {'+", ".join(f'&"{k}": {float(v)}' for k,v in rs.items())+'}')
    open(f'{ROOT}/{region_file}.tres','w').write("\n".join(lines)+"\n")
    print(region, len(used), "forage types")

write("border_woods","res://world/spring_court/border_woods/border_woods_terrain.gd","BorderWoodsTerrain",BORDER,2100,"The Border Woods")
write("eastern_woods","res://world/spring_court/eastern_woods/eastern_woods_terrain.gd","EasternWoodsTerrain",EASTERN,3100,"The Eastern Woods")

GLADE=[
 dict(id="young_birches",notes="[C] Western woods (book text): wild, oaks, elms and beeches intertwined, moss underfoot, and a glen of young skinny birches by running water (ch. 13-15).",
  g=(0.48,0.70,0.44),g2=(0.56,0.72,0.56),td=0.02,t={"silver_birch":8,"oak":1,"elm":1,"beech":0.8,"leaning_trunk":0.5},
  sd=0.04,s={"hazel":2,"fern":2,"mossy_rock":1,"honeysuckle_bush":1,"bramble":1},
  dd=2.4,dt={"bluebell":5,"wood_anemone":3,"grass_tuft":3,"primrose":1,"violet":1,"wild_garlic":1},
  fh=60,f={"ing_wild_hyacinth":3,"ing_violet":2,"ing_primrose":2,"ing_wood_sorrel":2,"ing_wild_garlic":2,"ing_hazelnut":2,"ing_honeysuckle":1,
   "ing_blackberry":1,"ing_owl_feather":1,"ing_hawk_feather":1,"ing_snail_shell":1,"ing_moss":1,"ing_glowcap":0.6,
   "col_robin_egg_shell":1,"col_jay_feather":1,"col_acorn_caps":1,"col_painted_pebble":0.5,"col_odd_stone":0.8,"col_shed_antler":0.5},
  amb=["butterflies","pollen","songbirds","sparkles"]),
 dict(id="snare_glade",notes="[X] The open patch where the snare goes: short grass, a waiting oak, wildflowers. Clear sight lines on purpose.",
  g=(0.56,0.76,0.44),g2=(0.62,0.78,0.48),td=0.0,t={},
  sd=0.01,s={"mossy_rock":1,"foxglove":1},
  dd=2.6,dt={"grass_tuft":5,"buttercup":2,"daisy":2,"clover":2,"cowslip":1},
  fh=24,f={"ing_wild_strawberry":3,"ing_elderflower":1,"ing_foxglove":1,"ing_meadowsweet":1,"col_odd_stone":1},
  amb=["butterflies","pollen","sparkles"]),
 dict(id="thornwater_banks",notes="[X] The Thornwater's banks: willow, alder, mint, pebbles and trout lies. Water does not stop the naga (ch. 15).",
  g=(0.40,0.62,0.40),g2=(0.50,0.54,0.42),td=0.012,t={"willow":3,"alder":3,"silver_birch":1},
  sd=0.06,s={"reed_clump":1.5,"cattail":1,"mossy_rock":2,"fern":1},
  dd=2.0,dt={"pebbles":3,"water_mint":2,"meadowsweet":2,"grass_tuft":2,"lily_pad":0.5},
  fh=50,f={"ing_willow_bark":2,"ing_water_mint":2,"ing_meadowsweet":1.5,"ing_river_silt":2,"ing_trout":2,"col_river_glass":1.5,"col_odd_stone":1},
  amb=["dragonflies","fish","butterflies","sparkles"]),
 dict(id="naga_reeds",notes="[C?] Horror exception: the naga's backwater. Black still water, reeds over head height, grey light, frogs that stop. No sparkle.",
  g=(0.24,0.30,0.22),g2=(0.20,0.24,0.20),td=0.004,t={"twisted_dead":1,"alder":1},
  sd=0.2,s={"reed_clump":8,"cattail":3},
  dd=1.6,dt={"grey_grass":3,"lily_pad":1,"dead_leaves":1},
  fh=20,f={"ing_river_silt":2,"ing_hollow_root":2,"col_bone_charm":1,"col_old_arrowhead":1},
  amb=["mist"]),
]
write("suriel_glade","res://world/spring_court/suriel_glade/suriel_glade_terrain.gd","SurielGladeTerrain",GLADE,4100,"The Suriel's Glade")
