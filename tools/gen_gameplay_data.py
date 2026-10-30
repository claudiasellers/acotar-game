#!/usr/bin/env python3
"""Generates the gameplay data catalogue as Godot .tres resources.

Run from the repo root:  python3 tools/gen_gameplay_data.py
Edit the tables below, never the generated .tres by hand (R15).
Sources: lore/05-foraging-chemistry/ingredients.md (ids, tags, canon), the
world lanes' scatter requests, and lore/06-items/bows-and-arrows.md.
"""
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TINY, SMALL, MEDIUM, LARGE, HEAVY = range(5)

# Region ids (lore/01-world).
W = "reg_winter_forest"; V = "reg_village"; COT = "reg_archeron_cottage"
WALLH = "reg_wall_edge_mortal"; RIV = "reg_frozen_river"; OLD = "reg_old_hunting_grounds"
BURNT = "reg_burnt_estate"
MAN = "reg_manor_estate"; WOODS = "reg_estate_woods"; MARCH = "reg_wall_marches"
CAL = "reg_calanmai_hills"; ROSE = "reg_rosewild"; VALE = "reg_blossom_vale"
LAKES = "reg_mirror_lakes"; GREEN = "reg_greenmarch"; HAM = "reg_mask_villages"
ASHG = "reg_ash_grove"; BLIGHT = "reg_blighted_reach"; SHRINE = "reg_old_temples"
FELLS = "reg_western_fells"

# id, name, tags, regions, season, weight, edible, nutrition, food_days,
# respawn_days, abundance, price, canon, color(hex), pigment, craft_tags, desc,
# extra dict (night_only, perishes_at_dawn)
I = []
def ing(id, name, tags, regions, season="any", wc=SMALL, edible=True, nut=0.05, food=0.0,
        respawn=2.0, ab="common", price=1, canon="X", color="cccccc", pigment="",
        craft=(), desc="", **extra):
    I.append(dict(id=id, name=name, tags=tags, regions=regions, season=season, wc=wc,
                  edible=edible, nut=nut, food=food, respawn=respawn, ab=ab, price=price,
                  canon=canon, color=color, pigment=pigment, craft=list(craft), desc=desc,
                  extra=extra))

# ---- Flora: lore catalogue ----
ing("ing_rose_red", "Red rose", ["vital", "warm"], [MAN, ROSE], "spring", TINY, nut=0.02, canon="C", color="b8203a", desc="The court's signature bloom. Warm in the hand, somehow.")
ing("ing_rose_white", "White rose", ["cool", "steady"], [MAN], "spring", TINY, nut=0.02, canon="C?", color="f3efe6", desc="Cool petals that settle a racing pulse.")
ing("ing_rose_gold", "Gold rose", ["bright", "fae"], [MAN, ROSE], "spring", TINY, nut=0.02, respawn=6, ab="rare", price=6, color="e8b730", desc="Rare, deep in the gardens. The colour of a certain mask.")
ing("ing_rose_hip", "Rose hips", ["vital"], [ROSE, BLIGHT, W], "any", TINY, nut=0.06, respawn=4, ab="uncommon", color="c0392b", desc="Hips only form where time moves: winter hedges, and the blight's edge in Spring.")
ing("ing_thornbriar_sap", "Thornbriar sap", ["bind", "bitter"], [ROSE], "spring", SMALL, edible=False, respawn=3, color="6b4b2a", desc="Sticky, bitter sap from the thorn brakes.")
ing("ing_wild_hyacinth", "Wild hyacinth", ["quiet", "cool"], [WOODS, MARCH], "spring", TINY, nut=0.0, color="5a6fd6", desc="Bluebells carpet the Border Woods.")
ing("ing_foxglove", "Foxglove", ["bitter", "strong"], [WOODS], "spring", TINY, nut=0.0, ab="uncommon", color="b45fa6", desc="Beautiful and poisonous. For steeps, not stews.")
ing("ing_lavender", "Lavender", ["quiet", "steady"], [MAN, GREEN], "spring", TINY, nut=0.0, color="9a83c9", desc="Masks scent; calms the hands.")
ing("ing_honeysuckle", "Honeysuckle", ["swift", "vital"], [MAN, VALE], "spring", TINY, nut=0.02, color="f2d68a", desc="Sweet nectar from the hedges.")
ing("ing_willow_bark", "Willow bark", ["vital", "bind"], [W, RIV, LAKES], "any", SMALL, nut=0.0, respawn=5, color="7d6a4f", desc="Stream-bank bark that dulls pain when steeped.")
ing("ing_elderflower", "Elderflower", ["vital", "cool"], [VALE, MAN], "spring", TINY, nut=0.02, color="f6f1d8", desc="Creamy umbels at the orchard's edge.")
ing("ing_wild_strawberry", "Wild strawberry", ["vital"], [GREEN, VALE, WOODS], "spring", TINY, nut=0.05, food=0.05, color="e0393e", desc="Tiny, sun-warm, everywhere in the meadows.")
ing("ing_blackberry", "Blackberry", ["vital", "warm"], [W, MAN, VALE], "any", TINY, nut=0.05, food=0.05, respawn=3, color="2b1b3a", desc="In winter, a few shrivelled berries still on the cane. In Spring, hedges heavy with them.")
ing("ing_moonflower", "Moonflower", ["bright", "fae"], [LAKES], "spring", TINY, nut=0.0, ab="uncommon", price=4, color="eef2ff", desc="Opens only at night by the Starlight Pool.", night_only=True)
ing("ing_glowcap", "Glowcap", ["bright"], [WOODS], "spring", SMALL, nut=0.02, color="9fe3c4", desc="A mushroom that gives off a soft green light.")
ing("ing_hollow_root", "Hollow-root", ["quiet", "bind"], [WOODS], "spring", SMALL, nut=0.02, ab="uncommon", color="8c7b65", desc="A pale root that swallows sound and scent.")
ing("ing_faelight_dandelion", "Faelight dandelion", ["swift", "fae"], [WOODS, MARCH, GREEN], "spring", TINY, nut=0.0, color="fff4b0", desc="Its seeds drift off as little lights.")
ing("ing_ash_wood", "Ash wood", ["ash"], [W, OLD, ASHG], "any", MEDIUM, edible=False, nut=0.0, respawn=30, ab="rare", price=0, canon="C", color="d9cbb0", desc="Pale, straight-grained ash. The one wood the fae fear.")
ing("ing_oak_gall", "Oak gall", ["bind", "bitter"], [W, OLD], "any", TINY, edible=False, respawn=6, color="8a6d45", pigment="black", desc="Hard little galls; good for ink.")
ing("ing_woad", "Woad", ["steady"], [V, W, COT], "any", SMALL, edible=False, respawn=5, ab="uncommon", price=2, color="2f4f8f", pigment="blue", desc="Dried leaves that make a deep blue.")
ing("ing_madder", "Madder root", ["warm"], [V, W, VALE], "any", SMALL, edible=False, respawn=5, ab="uncommon", price=2, color="a83226", pigment="red", desc="A root that bleeds red dye.")
ing("ing_snowdrop", "Snowdrop", ["cool", "steady"], [W, COT, WALLH], "winter", TINY, nut=0.0, respawn=4, ab="uncommon", color="f5f8fa", desc="The only flower in the winter forest. Feyre always notices them.")
ing("ing_pine_resin", "Pine resin", ["bind", "warm"], [W, OLD], "winter", SMALL, edible=False, respawn=4, color="c98d2c", craft=["glue"], desc="Amber resin for fletching glue and torches.")
ing("ing_wisteria", "Wisteria", ["quiet", "fae"], [MAN], "spring", TINY, nut=0.0, color="b9a0e0", desc="Lilac drapes over the manor walls.")
ing("ing_cherry_blossom", "Orchard blossom", ["swift"], [VALE, MAN], "spring", TINY, nut=0.0, color="f7c6d4", pigment="pink", desc="Blossom that never quite falls.")
ing("ing_lilac", "Lilac", ["keen"], [MAN], "spring", TINY, nut=0.0, ab="uncommon", color="c8a2c8", desc="The scent sharpens everything.")
ing("ing_moss", "Starmoss", ["bright", "cool"], [WOODS, LAKES], "spring", TINY, nut=0.0, color="7fbf9a", pigment="green", desc="Moss flecked with pinprick lights.")
ing("ing_blighted_petals", "Blighted petals", ["bitter", "fae"], [BLIGHT], "spring", TINY, edible=False, ab="uncommon", color="6e6a5f", desc="Grey petals that crumble like ash.")

# ---- Flora and finds: human-realm winter additions (world lane request) ----
ing("ing_holly_berry", "Holly berries", ["bitter", "warm"], [W, COT], "winter", TINY, edible=False, respawn=5, color="c1121f", pigment="red", desc="Bright and poisonous. The red is worth crushing for paint.")
ing("ing_juniper_berry", "Juniper berries", ["warm", "keen"], [W, WALLH, FELLS], "any", TINY, nut=0.02, respawn=4, color="3d4f7a", desc="Resinous blue berries that clear the head.")
ing("ing_sloe", "Sloes", ["bitter", "bind"], [W, V, ROSE], "any", TINY, nut=0.02, respawn=4, color="2e3047", desc="Frost-sweetened, still mouth-puckering.")
ing("ing_hawthorn_haw", "Hawthorn haws", ["vital", "steady"], [W, V, COT], "winter", TINY, nut=0.03, food=0.03, respawn=3, color="9b1d20", desc="Mealy red haws left on the hedge for the birds.")
ing("ing_birch_bark", "Birch bark", ["vital", "bind"], [W, RIV, LAKES, FELLS], "any", SMALL, edible=False, respawn=6, color="eae7df", craft=["tinder"], desc="Papery bark that lights even when damp.")
ing("ing_chaga", "Chaga", ["vital", "warm"], [W, OLD], "winter", SMALL, nut=0.0, respawn=10, ab="rare", price=3, color="3a2a1e", desc="A charred-looking growth on birch; makes a warming tea.")
ing("ing_tinder_fungus", "Tinder fungus", ["warm"], [W, OLD], "any", SMALL, edible=False, respawn=8, ab="uncommon", color="7a5a3a", craft=["tinder"], desc="Hoof-shaped bracket that holds an ember for hours.")
ing("ing_old_mans_beard", "Old man's beard", ["vital", "bind"], [W, WALLH], "winter", TINY, edible=False, respawn=6, color="b8c4a8", desc="Grey-green lichen streaming from old branches; packs a wound.")
ing("ing_acorn", "Acorns", ["strong", "bitter"], [W, OLD], "any", TINY, nut=0.03, food=0.02, respawn=4, color="8b6b3e", desc="Bitter until leached. The hungry eat them anyway.")
ing("ing_hazelnut", "Hazelnuts", ["vital", "strong"], [W, V, FELLS, "reg_autumn_border"], "any", TINY, nut=0.05, food=0.05, respawn=5, ab="uncommon", color="a0743f", desc="A squirrel's cache, found under the snow.")
ing("ing_pine_needles", "Pine needles", ["warm", "keen"], [W, OLD, WALLH], "any", TINY, nut=0.0, respawn=1, color="2f5233", desc="A bitter, bright tea against the cold.")
ing("ing_frozen_reed", "Frozen reeds", ["quiet"], [RIV], "winter", SMALL, edible=False, respawn=5, color="b5a77a", desc="Hollow reeds locked in the river ice; good for snare work and whistles.")
ing("ing_mistletoe", "Mistletoe", ["bitter", "fae"], [W, OLD], "winter", TINY, edible=False, respawn=8, ab="rare", color="d7e2c0", desc="Villagers say the fae love it. Feyre leaves it where it grows, mostly.")
ing("ing_wintergreen", "Wintergreen", ["cool", "vital"], [W], "winter", TINY, nut=0.01, respawn=3, color="2e6b4f", desc="Glossy leaves under the snow, with a sharp minty bite.")
ing("ing_shed_antler", "Shed antler", [], [W, OLD], "winter", MEDIUM, edible=False, respawn=20, ab="rare", price=3, color="d8cbb2", craft=["arrowhead_blank", "handle"], desc="Dropped by a stag. Carves into toggles, handles, even points.")
ing("ing_flint", "Flint", [], [W, RIV, BURNT], "any", SMALL, edible=False, respawn=10, ab="uncommon", price=1, color="4a4a52", craft=["knappable"], desc="Knaps into arrowheads, and strikes sparks.")
ing("ing_chalk", "Chalk", ["steady"], [V, RIV, FELLS], "any", SMALL, edible=False, respawn=10, color="f2f0e8", pigment="white", desc="Soft white stone; a white for painting.")
ing("ing_red_ochre", "Red ochre", [], [RIV, BURNT], "any", SMALL, edible=False, respawn=10, ab="uncommon", price=2, color="a4472d", pigment="ochre_red", desc="Earth red from the riverbank cut.")
ing("ing_charcoal", "Charcoal", ["warm"], [BURNT, COT], "any", SMALL, edible=False, respawn=7, color="1c1c1c", pigment="black", craft=["tinder"], desc="From the burnt estate's beams. Draws, and burns again.")
ing("ing_clay", "Clay", ["bind"], [RIV], "any", SMALL, edible=False, respawn=6, color="9c8770", desc="Riverbank clay for sealing and for binding pigment.")
ing("ing_snowmelt_water", "Snowmelt water", ["cool", "vital"], [W, COT, WALLH], "winter", SMALL, nut=0.0, respawn=0.25, color="dfeef7", desc="Melted over the fire, it is the base of every stew.")
ing("ing_ice_moss", "Ice moss", ["cool", "quiet"], [RIV, WALLH], "winter", TINY, nut=0.01, respawn=4, color="9cb7b0", desc="Silvery moss in the river's frozen spray.")
ing("ing_hazel_rod", "Hazel rod", [], [W, V], "any", SMALL, edible=False, respawn=6, color="9b7b52", craft=["shaft_wood"], desc="Straight hazel shoots. Carved down, they make arrow shafts.")

# ---- Fauna products ----
ing("ing_venison", "Venison", ["vital", "strong", "warm"], [W, WOODS], "any", MEDIUM, nut=0.35, food=1.5, respawn=0, price=4, canon="C", color="7a2e2e", desc="A deer means days of food. Venison is life.")
ing("ing_sinew", "Sinew", ["bind"], [W, WOODS], "any", TINY, edible=False, respawn=0, price=1, color="d9c9a8", craft=["binding", "cordage"], desc="Dried tendon for bowstrings and binding.")
ing("ing_hide", "Deer hide", [], [W, WOODS], "any", LARGE, edible=False, respawn=0, price=6, canon="C", color="8a6a4a", desc="Scraped and sold, or kept against the cold.")
ing("ing_rabbit", "Rabbit", ["vital"], [W, WOODS, GREEN], "any", MEDIUM, nut=0.2, food=0.5, respawn=0, price=1, canon="C", color="8f7d6b", desc="A snared rabbit: one thin meal.")
ing("ing_hare", "Hare", ["vital"], [W, WOODS, GREEN], "any", MEDIUM, nut=0.25, food=0.6, respawn=0, price=2, canon="C", color="8a7a62", desc="Leaner than a deer, kinder than nothing.")
ing("ing_hare_pelt", "Hare pelt", [], [W, WOODS], "any", SMALL, edible=False, respawn=0, price=1, color="b3a48a", desc="A soft pelt; lines a glove.")
ing("ing_wolf_pelt", "Wolf pelt", [], [W], "winter", LARGE, edible=False, respawn=0, price=8, color="6b6b6b", desc="A grey winter pelt. Worth good coin at the market.")
ing("ing_boar", "Boar", ["strong"], [WOODS, FELLS], "spring", MEDIUM, nut=0.35, food=1.5, respawn=0, price=4, color="5a3e2b", desc="Rich, dark meat.")
ing("ing_trout", "Trout", ["vital", "cool"], [LAKES, RIV], "any", MEDIUM, nut=0.2, food=0.5, respawn=1, price=2, color="9aa9a0", desc="Speckled trout from the streams, or through the river ice.")
ing("ing_hawk_feather", "Hawk feather", ["swift"], [W, FELLS, GREEN], "any", TINY, edible=False, respawn=3, ab="uncommon", color="8b5a2b", craft=["fletching"], desc="Stiff barred flight feather. True fletching.")
ing("ing_owl_feather", "Owl feather", ["quiet"], [W, WOODS], "any", TINY, edible=False, respawn=4, ab="uncommon", color="c2a27a", craft=["fletching"], desc="Soft-edged. An arrow fletched with it barely whispers.")
ing("ing_crow_feather", "Crow feather", [], [W, V, COT], "winter", TINY, edible=False, respawn=1, color="1a1a22", craft=["fletching"], desc="Common, black, serviceable fletching.")
ing("ing_honey", "Honey", ["vital", "bind"], [VALE, V], "any", SMALL, nut=0.1, food=0.1, respawn=5, price=3, color="d9a521", desc="Sweetness, and a binder for salves.")
ing("ing_snail_shell", "Snail shells", [], [WOODS, MAN, LAKES], "spring", TINY, edible=False, respawn=2, color="e9dcc6", pigment="white", desc="Ground fine, they make a pearly white.")

# ---- Waters and minerals ----
ing("ing_starlight_water", "Starlight water", ["bright", "fae"], [LAKES], "spring", SMALL, nut=0.0, respawn=1, ab="uncommon", color="cfe0ff", desc="Water from the pool at night. Gone flat and ordinary by dawn.", night_only=True, perishes_at_dawn=True)
ing("ing_rose_maze_dew", "Rose-maze dew", ["vital", "quiet"], [MAN], "spring", SMALL, nut=0.0, respawn=1, color="e8f2f0", desc="Morning dew gathered in the hedge maze.")
ing("ing_rite_spring", "Rite spring water", ["strong", "fae"], [CAL], "spring", SMALL, nut=0.0, respawn=3, ab="rare", color="a9c9d6", desc="From the spring in the cave of the Rite.")
ing("ing_river_silt", "River silt", ["bind"], [LAKES, RIV], "any", SMALL, edible=False, respawn=3, color="9a7b4f", pigment="ochre", desc="Fine silt; an ochre pigment and a binder.")
ing("ing_salt", "Salt", ["preserve"], [V], "any", SMALL, nut=0.0, respawn=0, price=2, color="f4f4f4", desc="Bought dear at the market. Keeps meat through the winter.")
ing("ing_iron_filings", "Iron filings", [], [V], "any", SMALL, edible=False, respawn=0, price=3, canon="C", color="5b5b60", desc="Villagers swear iron wards off faeries. It doesn't; only humans believe it.")

# ---- Prepared foods ----
ing("ing_manor_fruit", "Manor fruit", ["vital"], [MAN], "spring", SMALL, nut=0.15, food=0.3, respawn=1, canon="C", color="f0a04b", desc="Platters of impossible fruit at every meal.")
ing("ing_faerie_wine", "Faerie wine", ["fae", "strong"], [MAN, CAL], "spring", SMALL, nut=0.0, respawn=0, canon="C", color="8e2c48", desc="Loosens everything. Careful.")
ing("ing_faerie_bread", "Faerie bread", ["vital", "fae"], [MAN, HAM], "spring", SMALL, nut=0.2, food=0.4, respawn=1, color="e8cf9a", desc="Light as air and gone too soon.")
ing("ing_candied_flowers", "Candied flowers", ["swift", "fae"], [MAN, HAM], "spring", TINY, nut=0.05, respawn=2, color="f2b5d4", desc="Sugared violets and rose petals.")
ing("ing_stale_bread", "Stale bread", ["vital"], [COT, V], "any", SMALL, nut=0.08, food=0.25, respawn=0, price=1, canon="C", color="b89a6a", desc="Thin porridge and stale bread: the cottage's usual.")
ing("ing_venison_stew", "Venison stew", ["vital", "warm"], [COT], "any", MEDIUM, nut=0.4, food=1.0, respawn=0, canon="C", color="6b3a26", desc="Her kills feed the family.")


# ---- Wider Spring Court additions (wider-court lane request, all [X]) ----
for _id, _name, _tags, _pig, _regions, _color, _desc in [
	("ing_watermint", "Water mint", ["cool", "keen"], "", [LAKES, WOODS], "4f9a6a", "Crushed underfoot at the stream's edge."),
	("ing_meadowsweet", "Meadowsweet", ["vital", "quiet"], "", [GREEN, LAKES], "f4ecd2", "Frothy cream flowers in damp meadows."),
	("ing_cowslip", "Cowslip", ["bright", "swift"], "", [GREEN, CAL], "f2d24b", "Nodding yellow bells on the downs."),
	("ing_heather", "Heather", ["steady", "warm"], "", [FELLS], "9b5a8c", "Purple across the fells."),
	("ing_bilberry", "Bilberry", ["vital", "keen"], "", [FELLS], "3b3f78", "Dusky berries that stain the fingers."),
	("ing_wild_thyme", "Wild thyme", ["warm", "strong"], "", [FELLS, GREEN], "8f7fb0", "Tiny and fierce-scented."),
	("ing_yarrow", "Yarrow", ["vital", "bind"], "", [GREEN, VALE], "efe9dc", "Feathery leaves for wounds."),
	("ing_chamomile", "Chamomile", ["quiet", "steady"], "", [GREEN, VALE], "fbf5d6", "Apple-scented daisies."),
	("ing_red_poppy", "Red poppy", ["quiet", "bitter"], "red", ["reg_solstice_meadow", GREEN], "d62828", "Papery red, a drowsy sap."),
	("ing_cornflower", "Cornflower", ["keen", "cool"], "blue", [GREEN, VALE], "4f74d9", "The bluest blue in the meadows."),
	("ing_water_lily", "Water lily", ["cool", "fae"], "", [LAKES], "f6e3ef", "Opens on the still pools."),
	("ing_marsh_marigold", "Marsh marigold", ["bright", "warm"], "yellow", [LAKES], "f6c12b", "Gold cups at the lake margins."),
	("ing_bulrush_root", "Bulrush root", ["bind", "vital"], "", [LAKES], "c9b38a", "Starchy root from the shallows."),
	("ing_mirror_reed", "Mirror reed", ["keen", "cool"], "", [LAKES], "bcd6d0", "Reeds that hold a reflection a moment too long."),
	("ing_chanterelle", "Chanterelle", ["vital", "warm"], "", [WOODS, "reg_autumn_border"], "f0a830", "Apricot-scented gold mushrooms."),
	("ing_fly_agaric", "Fly agaric", ["bitter", "fae"], "", ["reg_autumn_border"], "d7263d", "Red cap, white spots. No."),
	("ing_rowan_berry", "Rowan berry", ["bitter", "steady"], "", ["reg_autumn_border"], "e0521b", "Bright clusters at the autumn edge."),
	("ing_ember_maple_leaf", "Ember maple leaf", ["warm", "fae"], "red", ["reg_autumn_border"], "c8401e", "A leaf from over the Autumn border, warm to touch."),
	("ing_spring_apple", "Spring apple", ["vital", "swift"], "", [VALE], "9cc94a", "Crisp, always in season."),
	("ing_honeyplum", "Honeyplum", ["vital", "bright"], "", [VALE], "c25a8a", "Plums that taste of honey."),
	("ing_quince", "Quince", ["bind", "warm"], "", [VALE], "e8cf55", "Hard and fragrant; sets jellies."),
	("ing_cherry", "Cherry", ["vital", "bright"], "", [VALE, MAN], "a31621", "Dark sweet cherries."),
	("ing_fire_lily", "Fire lily", ["warm", "strong"], "orange", [CAL], "f26a1b", "Blooms around the bonfire fields."),
	("ing_ochre_clay", "Ochre clay", ["bind"], "ochre", [CAL, FELLS], "c58b3a", "Yellow-brown earth pigment."),
	("ing_lapis_shard", "Lapis shard", ["keen"], "blue", [SHRINE], "26619c", "Ultramarine, the rarest blue."),
	("ing_grey_lichen", "Grey lichen", ["bitter", "quiet"], "", [BLIGHT], "8a8c84", "Creeps over everything in the blight."),
	("ing_ashen_rose", "Ashen rose", ["bitter", "fae"], "grey", [BLIGHT], "8d8a86", "A rose drained of colour."),
	("ing_nightshade", "Nightshade", ["bitter", "strong"], "", [BLIGHT], "4b2a5c", "Purple berries at the blight's edge."),
	("ing_violet", "Sweet violet", ["quiet", "cool"], "violet", [LAKES, WOODS], "7b4fb0", "Shy purple flowers in the glen."),
	("ing_primrose", "Primrose", ["bright", "vital"], "", [WOODS, GREEN, VALE, MAN, MARCH], "f6e58d", "Pale yellow, everywhere in Spring."),
	("ing_wood_sorrel", "Wood sorrel", ["cool", "keen"], "", [WOODS, LAKES], "b7e08f", "Lemony clover-leaves."),
	("ing_nettle", "Nettle", ["strong", "bitter"], "", [HAM, V], "3f6b35", "Stings, then feeds."),
	("ing_dandelion", "Dandelion", ["vital"], "", [GREEN, HAM], "f7d038", "Bitter greens, bright heads."),
	("ing_clover", "Clover", ["vital", "swift"], "", [GREEN, VALE], "e4a5c0", "Sweet pink heads in the grass."),
	("ing_dreamcap", "Dreamcap", ["quiet", "fae"], "", [LAKES], "a9a2e8", "A pale mushroom that only shows at night."),
	("ing_spider_silk", "Spider silk", ["bind"], "", [ROSE, "reg_autumn_border"], "f1f1f1", "Dewy silk from the thorn brakes. Twisted, it makes a fine strong line."),
	("ing_wild_garlic", "Wild garlic", ["strong", "keen"], "", [LAKES, ASHG], "e9f2df", "Carpets the shade; smells for miles."),
	("ing_sweet_woodruff", "Sweet woodruff", ["quiet", "steady"], "", [ASHG], "d5ead0", "Smells of new hay once dried."),
	("ing_crocus", "Crocus", ["bright", "swift"], "", [WOODS, MARCH, GREEN], "a58fe0", "The first purple through the leaf litter."),
	("ing_mugwort", "Mugwort", ["keen", "bitter"], "", [SHRINE], "8fa38a", "Grows thick around the old shrines."),
]:
	_night = _id == "ing_dreamcap"
	_edible = not _pig and _id not in ("ing_fly_agaric", "ing_nightshade", "ing_spider_silk", "ing_ochre_clay", "ing_lapis_shard", "ing_grey_lichen", "ing_ashen_rose")
	ing(_id, _name, _tags, _regions, "spring", TINY, edible=_edible, craft=["cordage"] if _id == "ing_spider_silk" else [], nut=0.04 if _edible else 0.0, ab="uncommon" if _id in ("ing_lapis_shard", "ing_fly_agaric", "ing_dreamcap") else "common", color=_color, pigment=_pig, desc=_desc, night_only=_night)

# ---- Crafting materials (not foraged; made or bought) ----
MATERIALS = [
	dict(id="mat_shaft", name="Arrow shaft", wc=TINY, craft=["shaft"], price=0, color="b08a5a", desc="A straight, scraped hazel shaft."),
	dict(id="obj_wolf_pelt", name="The great wolf's pelt", wc=LARGE, craft=[], price=40, color="8d8a84", canon="C", desc="Too big for any wolf. It sells for more than she's seen in years."),
	dict(id="obj_lucien_knife", name="Lucien's knife", wc=SMALL, craft=["blade"], price=0, color="b8b8c0", canon="C?", desc="A fine fae blade, lent and not asked back."),
	dict(id="obj_white_roses", name="White roses", wc=SMALL, craft=[], price=0, color="f6f3ec", canon="C?", desc="A bundle of white roses."),
	dict(id="mat_barbed_head", name="Barbed head", wc=TINY, craft=["arrowhead"], price=2, color="d8cbb2", desc="An antler point with a backward hook."),
	dict(id="mat_arrowhead", name="Arrowhead", wc=TINY, craft=["arrowhead"], price=1, color="55555c", desc="Knapped flint or a cheap iron head from the market."),
]

# ---- Collectibles: keepsakes for the pouch ----
C = [
	("col_odd_stone", "Odd stone", [W, WOODS, RIV], "A stone with a hole worn clean through.", "8c8c8c", "uncommon"),
	("col_painted_pebble", "Painted pebble", [COT, V], "Someone painted a tiny flower on it. Maybe her, years ago.", "d9a0a0", "rare"),
	("col_pressed_violet", "Pressed violet", [WOODS, MAN], "Flattened between pages, still purple.", "7b5ea7", "uncommon"),
	("col_robin_egg_shell", "Robin's egg shell", [WOODS, VALE], "The exact blue she can never mix.", "9fd3e6", "uncommon"),
	("col_wren_feather", "Wren feather", [W, WOODS], "Tiny and barred. Too small to fletch, too pretty to drop.", "8a6a48", "common"),
	("col_acorn_cap", "Acorn cap", [W, OLD], "A perfect little cup.", "8b6b3e", "common"),
	("col_frost_glass", "Frost-clear ice shard", [RIV, WALLH], "Ice so clear it bends the light. It won't last.", "e6f4fb", "uncommon"),
	("col_carved_bird", "Carved wooden bird", [COT, V], "One of her father's figures, unsold.", "b48a5a", "rare"),
	("col_ribbon_scrap", "Ribbon scrap", [V, COT], "A bit of Nesta's ribbon. She'd never admit it was hers.", "c06c84", "rare"),
	("col_seed_packet", "Elain's seed packet", [COT], "Paper twist of seeds for a garden that might grow.", "c9b37a", "rare"),
	("col_coin_old", "Old copper coin", [V, BURNT, SHRINE], "Older than the Wall, maybe.", "b87333", "uncommon"),
	("col_antler_tine", "Antler tine", [W, OLD], "A tip snapped from a shed antler.", "d8cbb2", "uncommon"),
	("col_snail_spiral", "Spiral shell", [WOODS, LAKES, MAN], "A perfect spiral, pink at the lip.", "eccfc0", "common"),
	("col_rose_petal_pressed", "Pressed rose petal", [MAN, ROSE], "Red, dried thin as paper.", "b8203a", "common"),
	("col_glass_bead", "Sea-green glass bead", [HAM, MAN], "Fae work: there is a light inside it.", "7fd1b9", "rare"),
	("col_silver_leaf", "Silver leaf", [WOODS, LAKES], "A leaf that dried silver instead of brown.", "c9cfd6", "uncommon"),
	("col_fae_bell", "Tiny bell", [HAM, CAL], "Rings without being touched, sometimes.", "e3c46b", "rare"),
	("col_mask_shard", "Mask shard", [CAL, SHRINE], "A chip of gilded mask from the revels.", "d4af37", "rare"),
	("col_mural_chip", "Mural chip", [SHRINE], "Painted plaster from the old shrines: a human hand in chains.", "a67b5b", "rare"),
	("col_dandelion_clock", "Faelight seed head", [WOODS, GREEN], "Held carefully, it glows for a day.", "fff4b0", "common"),
	("col_blue_jay_feather", "Blue jay feather", [WOODS, VALE], "Blue on one side, grey on the other.", "3f6fb5", "uncommon"),
	("col_river_pearl", "River pearl", [LAKES], "Lumpy and lovely.", "efe9df", "rare"),
	("col_heart_stone", "Heart-shaped stone", [RIV, LAKES, GREEN], "She'd scoff at it. She keeps it.", "a09080", "uncommon"),
	("col_blighted_bloom", "Petrified bloom", [BLIGHT], "A rose turned to grey stone. It's cold.", "6e6a5f", "uncommon"),
	("col_horseshoe", "Old horseshoe", [V, MARCH], "Iron. Villagers nail these over doors.", "5b5b60", "uncommon"),
	("col_feather_kingfisher", "Kingfisher feather", [LAKES], "A flash of impossible blue.", "1f8fbf", "rare"),
	("col_feather_pheasant", "Pheasant feather", [GREEN, VALE], "Copper and black bars.", "a65a2a", "common"),
	("col_feather_swan", "Swan feather", [LAKES], "Long, white, perfect.", "f7f7f2", "uncommon"),
	("col_feather_heron", "Heron feather", [LAKES], "Slate grey and soft.", "8a96a0", "uncommon"),
	("col_shell_river_mussel", "Mussel shell", [LAKES, RIV], "Mother-of-pearl inside.", "4a5a6a", "common"),
	("col_stone_quartz", "Quartz", [FELLS, SHRINE], "Clear as frozen water.", "eef0f2", "uncommon"),
	("col_stone_amber", "Amber", [WOODS, FELLS], "A gnat caught in gold.", "e0952b", "rare"),
	("col_stone_garnet", "Garnet", [FELLS], "A drop of dark red.", "7b1e2b", "rare"),
	("col_stone_obsidian", "Obsidian", [CAL], "Black glass from the Rite hills.", "1b1b22", "uncommon"),
	("col_stone_starglass", "Starglass", [LAKES], "Glows faintly at night.", "cfe0ff", "rare"),
	("col_stone_fossil", "Fossil", [FELLS, SHRINE], "A shell from before the sea left.", "bfae92", "uncommon"),
	("col_shrine_tile", "Shrine tile", [SHRINE], "A glazed tile with a faded eye.", "3f7a8c", "uncommon"),
	("col_calanmai_ribbon", "Calanmai ribbon", [CAL], "Singed at one end.", "c0392b", "uncommon"),
	("col_solstice_bead", "Solstice bead", ["reg_solstice_meadow", MAN], "Gold glass, warm in the hand.", "e8b730", "uncommon"),
	("col_leaf_gilded", "Gilded leaf", [MAN, WOODS], "Real gold leaf, or a glamour.", "d4af37", "rare"),
	("col_acorn_carved", "Carved acorn", [HAM], "A tiny face carved into it.", "8b6b3e", "uncommon"),
	("col_wool_tuft", "Wool tuft", [GREEN], "Caught on a thorn by the shepherds' path.", "efe8dc", "common"),
	("col_candle_stub", "Candle stub", [SHRINE, HAM], "Beeswax, still faintly sweet.", "e9d8a6", "common"),
	("col_beetle_jewel", "Jewel beetle wing", [VALE, WOODS], "Iridescent green.", "2e8b57", "uncommon"),
	("col_snake_skin", "Shed snake skin", [FELLS, LAKES], "Whole, papery, patterned.", "cbbf9a", "uncommon"),
	("col_driftwood", "Driftwood", [LAKES], "Silver and smooth.", "b9b2a4", "common"),
	("col_seed_pod", "Seed pod", [GREEN, "reg_autumn_border"], "Rattles when shaken.", "a08a5a", "common"),
	("col_bone_bleached", "Bleached bone", [BLIGHT, FELLS], "Small, white, unsettling.", "eae5d8", "uncommon"),
	("col_pinecone", "Pinecone", [W, FELLS], "Perfectly whole.", "6b4b2a", "common"),
	("col_old_arrowhead", "Old arrowhead", [WOODS, MARCH], "Iron, rusted, from some hunt long ago.", "6d5a4a", "uncommon"),
	("col_mask_ribbon", "Mask ribbon", [WOODS, HAM, CAL], "A silk tie from someone's mask.", "c89ad8", "uncommon"),
	("col_river_glass", "River glass", [LAKES, WOODS], "Frosted green glass, smooth as soap.", "9fd8c0", "common"),
	("col_bone_charm", "Bone charm", [WOODS, SHRINE], "A carved knot of bone on a thong.", "e8e0cc", "rare"),
	("col_snow_owl_down", "Owl down", [W, WALLH], "A wisp of white down caught on bark.", "f5f2ea", "common"),
]

def _arrow(id, name, effect="", drag=0.0022, brk=0.35, dmg=1.0, shaft="8c6a45", fletch="d9d2c3", price=1, fae=False, mass=0.03, desc="", canon="X"):
	return dict(id=id, item_id="arrow_" + id, name=name, effect=effect, mass=mass, drag=drag, wet=1.7, wspeed=0.92,
		brk=brk, fae=fae, dmg=dmg, shaft=shaft, fletch=fletch, price=price, desc=desc, canon=canon)

ARROWS = [
	_arrow("wood", "Wood arrow", desc="Hazel shaft, feather fletching, a flint or iron head."),
	_arrow("ash", "Ash arrow", drag=0.0020, brk=0.2, dmg=1.5, shaft="e3d6bd", fletch="8b5a2b", price=0, fae=True, mass=0.034, canon="C",
		desc="Mountain-ash shaft, iron head, bought from a travelling peddler. The one thing the fae truly fear. She keeps it for faeries."),
	_arrow("barbed", "Barbed arrow", "barbed", drag=0.0024, brk=0.3, dmg=1.4, fletch="7a5a3a", price=2, desc="Antler barbs that don't pull free."),
	_arrow("rope", "Rope arrow", "rope", drag=0.0034, brk=0.15, dmg=0.3, fletch="c9b38a", price=2, mass=0.05, desc="Trails a line of sinew and silk; it holds when it bites into wood or stone."),
	_arrow("signal", "Signal arrow", "signal", drag=0.0026, brk=0.5, dmg=0.3, fletch="e85d3a", price=2, desc="A resin-and-charcoal head that flares on impact."),
	_arrow("sleep", "Sleep arrow", "sleep", dmg=0.4, fletch="9a83c9", price=4, desc="Steeped in something quiet. The prey just... lies down."),
	_arrow("lure", "Lure arrow", "lure", dmg=0.2, fletch="f2b5d4", price=3, desc="Steeped sweet. Whatever smells it comes to look."),
	_arrow("fire", "Fire arrow", "fire", dmg=1.0, fletch="f26a1b", price=4, desc="Steeped hot. It catches as it lands."),
	_arrow("frost", "Frost arrow", "frost", dmg=0.8, fletch="a7d8f2", price=4, desc="Steeped cold. Rime spreads from where it strikes."),
	_arrow("light", "Light arrow", "light", dmg=0.3, fletch="fff4b0", price=3, desc="Steeped bright. It glows where it sticks, for a long while."),
]

# id, name, inputs{key:count}, output, count
RECIPES = [
	("carve_shaft", "Carve shafts", {"ing_hazel_rod": 1}, "mat_shaft", 2),
	("knap_arrowhead", "Knap arrowheads", {"ing_flint": 1}, "mat_arrowhead", 2),
	("antler_arrowhead", "Carve antler points", {"ing_shed_antler": 1}, "mat_arrowhead", 4),
	("arrow_wood", "Wood arrow", {"mat_shaft": 1, "tag:fletching": 1, "mat_arrowhead": 1}, "arrow_wood", 1),
	("barbed_heads", "Carve barbed heads", {"ing_shed_antler": 1}, "mat_barbed_head", 2),
	("arrow_barbed", "Barbed arrow", {"mat_shaft": 1, "tag:fletching": 1, "mat_barbed_head": 1}, "arrow_barbed", 1),
	("arrow_rope", "Rope arrow", {"arrow_wood": 1, "tag:cordage": 2}, "arrow_rope", 1),
	("arrow_signal", "Signal arrow", {"arrow_wood": 1, "ing_pine_resin": 1, "ing_charcoal": 1}, "arrow_signal", 1),
]

STATIONS = [
	("hearth", "Hearth", ["roast", "stew", "infuse"], 0, False, 4),
	("campfire", "Campfire", ["roast", "infuse"], 0, False, 3),
	("manor_kitchen", "Manor kitchen", ["roast", "stew", "infuse", "cook", "preserve", "bake"], 2, False, 5),
	("stillroom", "Stillroom", ["infuse", "distill", "salve", "steep"], 3, False, 5),
	("fae_potion_room", "Fae potion room", ["infuse", "tincture", "salve", "steep"], 4, True, 5),
	("starlight_pool", "Starlight pool", ["steep"], 4, True, 3),
	("rite_cave_fire", "Rite cave fire", ["stew"], 5, True, 4),
]
STATION_RULES = {"starlight_pool": {"night_only": True}, "rite_cave_fire": {"required_flag": "calanmai_attended"}}
STATIONS = STATIONS + [
]

# id, name, method, required ids, journal note
DISHES = [
	("venison_stew", "Venison stew", "stew", ["ing_venison"], "Stretches one deer across many days. Snowmelt and whatever roots there are."),
	("roast_venison", "Roast venison", "roast", ["ing_venison"], "Fat spitting in the fire. Rare as a feast day."),
	("hare_stew", "Hare stew", "stew", ["ing_hare"], "Thin, but hot."),
	("roast_hare", "Roast hare", "roast", ["ing_hare"], ""),
	("rabbit_stew", "Rabbit stew", "stew", ["ing_rabbit"], ""),
	("pine_needle_tea", "Pine-needle tea", "infuse", ["ing_pine_needles"], "Bitter and bright. Warms from the inside."),
	("willow_bark_tea", "Willow-bark tea", "infuse", ["ing_willow_bark"], "Takes the ache out of cold fingers."),
	("chaga_tea", "Chaga tea", "infuse", ["ing_chaga"], "Dark as earth and twice as warming."),
	("snowdrop_infusion", "Snowdrop infusion", "infuse", ["ing_snowdrop"], "Steadies the hands. She almost didn't pick it."),
	("blackberry_tea", "Blackberry tea", "infuse", ["ing_blackberry"], ""),
	("hedgerow_porridge", "Hedgerow porridge", "stew", ["ing_stale_bread", "ing_hawthorn_haw"], "Stale bread stretched with haws. It's food."),
	("trout_roast", "Roast trout", "roast", ["ing_trout"], ""),
]


# ---- Wardrobe (R3: dress-up is a headline feature) ----
# Palettes: candy-bright pastels with gold accents (engineering-rules R3).
PASTELS = {"rose": "f4a6c0", "blush": "f7cfd8", "lilac": "c8a8e9", "periwinkle": "a7b8f2",
	"mint": "b5ead7", "butter": "fbe7a1", "pearl": "f6f1ea", "gold": "e6c06a", "sage": "b7c9a8",
	"cream": "f3ead6", "ivory": "fbf6ea", "sky": "b9dcf5", "peach": "f9c9a8", "emerald": "4fae86"}
# id, name, slots, hides, colours (None = single), warmth, stealth, swift, reaction, source, phase, canon, mesh, desc
PIECES = [
	("hunter_tunic", "Patched tunic", ["top"], ["torso", "arms"], {"": "6f6a63"}, 0.2, 0.1, 0, "hunter", "cottage_chest", 0, "C", "hunter_tunic", "Worn soft, patched at both elbows."),
	("hunter_trousers", "Hunting trousers", ["bottom"], ["legs"], {"": "5a5146"}, 0.1, 0.1, 0, "hunter", "cottage_chest", 0, "C", "hunter_trousers", ""),
	("hunter_cloak", "Heavy patched cloak", ["outer"], [], {"": "4b4f57"}, 0.4, 0.2, 0, "hunter", "cottage_chest", 0, "C", "hunter_cloak", "Hood up, she disappears into the snow."),
	("hunter_boots", "Old boots", ["feet"], ["feet"], {"": "4a3a2c"}, 0.1, 0.1, 0, "", "cottage_chest", 0, "C", "hunter_boots", ""),
	("spring_tunic", "Fine tunic", ["top"], ["torso", "arms"], {k: PASTELS[k] for k in ("sage", "cream", "rose", "lilac", "sky")}, 0.0, 0, 0.05, "", "manor_wardrobe", 2, "C", "spring_tunic", "She chooses tunics over gowns whenever she can."),
	("spring_trousers", "Fine trousers", ["bottom"], ["legs"], {k: PASTELS[k] for k in ("cream", "sage", "pearl")}, 0.0, 0, 0.05, "", "manor_wardrobe", 2, "C", "spring_trousers", ""),
	("riding_leathers", "Riding leathers", ["top", "bottom"], ["torso", "arms", "legs"], {"": "8a5a3c", "rose": "b9707f"}, 0.1, 0.1, 0.15, "rider", "stables", 2, "X", "riding_leathers", ""),
	("woods_leathers", "Woods leathers", ["top", "bottom"], ["torso", "arms", "legs"], {"": "5d6b4a", "mint": "7fa58f"}, 0.1, 0.35, 0.05, "hunter", "seamstress", 4, "X", "woods_leathers", "Green-brown, cut for moving quietly."),
	("dinner_gown", "Dinner gown", ["top", "bottom"], ["torso", "legs"], {k: PASTELS[k] for k in ("rose", "lilac", "ivory", "periwinkle", "blush")}, 0.0, -0.3, 0, "formal", "alis", 2, "C", "gown_dinner", "Flowing, light as breath. Alis insists."),
	("solstice_gown", "Solstice gown", ["top", "bottom"], ["torso", "arms", "legs"], {k: PASTELS[k] for k in ("butter", "mint", "blush", "gold")}, 0.0, -0.3, 0, "fae", "alis_gift", 6, "C?", "gown_solstice", "Made for dancing under the longest day."),
	("ball_gown", "Ball gown", ["top", "bottom"], ["torso", "legs"], {k: PASTELS[k] for k in ("rose", "periwinkle", "pearl", "lilac", "emerald")}, 0.0, -0.5, -0.1, "formal", "manor_wardrobe", 3, "X", "gown_ball", "Layers of tulle, a bodice stitched with tiny roses."),
	("garden_dress", "Garden tea dress", ["top", "bottom"], ["torso", "legs"], {k: PASTELS[k] for k in ("mint", "butter", "peach", "sky")}, 0.0, -0.1, 0, "formal", "manor_wardrobe", 2, "X", "gown_garden", "Short sleeves and a skirt that swishes."),
	("starlight_gown", "Starlight gown", ["top", "bottom"], ["torso", "arms", "legs"], {"": "c9d6ff", "lilac": "d8c8f4"}, 0.0, -0.4, 0, "fae", "seamstress", 4, "X", "gown_starlight", "It holds a little light of its own after dark."),
	("rose_petal_gown", "Rose-petal gown", ["top", "bottom"], ["torso", "legs"], {"": "f08aa8", "gold": "f2c879", "pearl": "f7e8ef"}, 0.0, -0.4, 0, "formal", "manor_wardrobe", 4, "X", "gown_rose_petal", "A skirt of layered silk petals."),
	("painter_smock", "Painter's smock", ["top"], ["torso", "arms"], {"": "e9e0cf", "blush": "f3d6db"}, 0.0, 0, 0, "painter", "painting_room", 4, "X", "painter_smock", "Already smudged, and she loves it."),
	("velvet_cloak", "Velvet cloak", ["outer"], [], {k: PASTELS[k] for k in ("rose", "lilac", "emerald", "periwinkle")}, 0.3, 0.0, 0, "formal", "manor_wardrobe", 3, "X", "velvet_cloak", ""),
	("satin_slippers", "Satin slippers", ["feet"], ["feet"], {k: PASTELS[k] for k in ("blush", "pearl", "lilac", "gold", "mint")}, 0.0, 0.1, 0, "formal", "manor_wardrobe", 2, "X", "slippers", ""),
	("riding_boots", "Riding boots", ["feet"], ["feet"], {"": "6b4a33"}, 0.1, 0, 0.1, "rider", "stables", 2, "X", "riding_boots", ""),
	("lace_gloves", "Lace gloves", ["hands"], ["hands"], {k: PASTELS[k] for k in ("ivory", "blush", "lilac")}, 0.0, 0, 0, "formal", "manor_wardrobe", 3, "X", "gloves_lace", ""),
	("flower_crown", "Flower crown", ["head"], [], {k: PASTELS[k] for k in ("rose", "butter", "lilac", "mint", "pearl")}, 0.0, 0, 0, "fae", "alis_gift", 2, "C?", "flower_crown", "Woven from the manor's own gardens."),
	("tiara", "Tiara", ["head"], [], {"gold": PASTELS["gold"], "silver": "d9dde3", "pearl": PASTELS["pearl"], "rose": "e8a3b8"}, 0.0, -0.1, 0, "formal", "manor_wardrobe", 3, "X", "tiara", "A delicate band of gilt leaves and seed pearls."),
	("circlet", "Circlet", ["head"], [], {"gold": PASTELS["gold"], "silver": "d9dde3"}, 0.0, 0, 0, "formal", "manor_wardrobe", 3, "X", "circlet", ""),
	("pearl_necklace", "Pearl necklace", ["neck"], [], {"": PASTELS["pearl"]}, 0.0, 0, 0, "formal", "manor_wardrobe", 3, "X", "necklace_pearl", ""),
	("gold_locket", "Gold locket", ["neck"], [], {"": PASTELS["gold"]}, 0.0, 0, 0, "", "manor_wardrobe", 3, "X", "necklace_locket", ""),
	("emerald_pendant", "Emerald pendant", ["neck"], [], {"": PASTELS["emerald"]}, 0.0, 0, 0, "formal", "manor_wardrobe", 4, "X", "necklace_pendant", "Spring's green, on a fine chain."),
	("rose_choker", "Rose choker", ["neck"], [], {k: PASTELS[k] for k in ("rose", "lilac")}, 0.0, 0, 0, "formal", "manor_wardrobe", 3, "X", "necklace_choker", ""),
	("butterfly_mask", "Butterfly mask", ["mask"], [], {k: PASTELS[k] for k in ("lilac", "sky", "gold")}, 0.0, 0.1, 0, "fae", "calanmai", 5, "X", "mask_butterfly", "Every revel needs a mask. She isn't cursed to wear one."),
	("gilded_leaf_mask", "Gilded-leaf mask", ["mask"], [], {"": PASTELS["gold"], "emerald": PASTELS["emerald"]}, 0.0, 0.1, 0, "fae", "calanmai", 5, "X", "mask_leaf", ""),
	("outfit_solstice_blue_gown", "Blue solstice gown", ["top", "bottom"], ["torso", "arms", "legs"], {"": "a9c6f0"}, 0.0, -0.3, 0, "fae", "story", 6, "C?", "gown_solstice", "The gown for the longest day."),
	("outfit_mortal_travel_dress", "Travelling dress", ["top", "bottom"], ["torso", "arms", "legs"], {"": "8f8a9e"}, 0.2, 0.0, 0, "formal", "story", 7, "C?", "gown_garden", "A mortal dress for the road home."),
	("fox_mask", "Fox mask", ["mask"], [], {"": "d9773b"}, 0.0, 0.1, 0, "fae", "calanmai", 5, "C?", "mask_fox", "Like Lucien's, which may be the point."),
]
HAIR = [
	("braid", "Hunter's braid", "C", False), ("loose", "Loose", "C", False), ("hunters_knot", "Hunter's knot", "X", False),
	("crown_braid", "Crown braid", "X", False), ("flower_crown_hair", "Solstice flowers", "C?", True), ("half_up", "Half up, ribboned", "X", False),
	("soft_curls", "Soft curls", "X", False), ("hair_loose_with_flowers", "Loose, with flowers", "C?", True), ("high_ponytail", "High ponytail", "X", False), ("wet", "Wet from the pool", "X", False),
]
# id, name, channel, colour, amount, sheen
MAKEUP = [
	("lips_rosebud", "Rosebud", "lips", "e26d8a", 0.7, 0.2), ("lips_berry", "Berry stain", "lips", "a3324f", 0.6, 0.1),
	("lips_peach", "Peach gloss", "lips", "f2a38a", 0.6, 0.6), ("lips_coral", "Coral", "lips", "f0776a", 0.7, 0.3),
	("lips_plum", "Plum", "lips", "7f3b63", 0.6, 0.1), ("lips_nude", "Petal nude", "lips", "d39a8e", 0.5, 0.3),
	("lips_ruby", "Rose-garden red", "lips", "c21d3a", 0.8, 0.2), ("lips_pearl", "Pearl gloss", "lips", "f2d9de", 0.4, 0.9),
	("eyes_lilac", "Lilac haze", "eyeshadow", "b79ad9", 0.6, 0.4), ("eyes_gold", "Gold leaf", "eyeshadow", "e3bc5c", 0.6, 0.9),
	("eyes_rose", "Rose dust", "eyeshadow", "e9a0b4", 0.6, 0.5), ("eyes_mint", "Spring mint", "eyeshadow", "a8e0c6", 0.5, 0.4),
	("eyes_periwinkle", "Periwinkle", "eyeshadow", "9fb1ee", 0.6, 0.4), ("eyes_smoke", "Soft smoke", "eyeshadow", "6e6676", 0.5, 0.1),
	("eyes_champagne", "Champagne", "eyeshadow", "f1dcc0", 0.5, 0.8), ("eyes_emerald", "Emerald", "eyeshadow", "3f9b78", 0.5, 0.5),
	("liner_kohl", "Kohl", "liner", "1f1a1e", 0.8, 0.0), ("liner_brown", "Soft brown", "liner", "4a3328", 0.7, 0.0),
	("liner_gold", "Gold line", "liner", "e3bc5c", 0.8, 0.9),
	("blush_rose", "Rose blush", "blush", "f08aa0", 0.4, 0.1), ("blush_peach", "Peach blush", "blush", "f4a98a", 0.4, 0.1),
	("blush_berry", "Berry flush", "blush", "c7577a", 0.35, 0.0), ("blush_glow", "Dewy glow", "blush", "f7c6c6", 0.3, 0.7),
	("brows_soft", "Soft brows", "brows", "6b4a32", 0.5, 0.0), ("brows_defined", "Defined brows", "brows", "4a3122", 0.7, 0.0),
	("paint_gold_freckles", "Gold freckles", "face_paint", "e6c06a", 0.6, 1.0), ("paint_silver_dust", "Silver dust", "face_paint", "dfe5ee", 0.5, 1.0),
	("paint_calanmai_swirl", "Calanmai swirl", "face_paint", "3a5fae", 0.7, 0.2), ("paint_petal_glitter", "Petal glitter", "face_paint", "f4a6c0", 0.5, 1.0),
]


# id, name, draw_time, min_speed, max_speed, sway, loudness, canon, desc
BOWS = [
	("yew_longbow", "Yew longbow", 1.1, 18.0, 60.0, 1.3, 0.5, "X", "From the manor armory. A long, honest draw."),
	("fae_recurve", "Fae recurve", 0.55, 16.0, 54.0, 1.1, 0.25, "X", "Quick and nearly silent. The limbs curl like fern fronds."),
	("sentry_warbow", "Sentry warbow", 1.4, 22.0, 70.0, 1.8, 0.7, "X", "A sentry's bow from the fells tower. Heavy, brutal, far."),
	("gilded_bow", "Gilded bow", 0.6, 20.0, 62.0, 0.8, 0.35, "X", "Gold-leafed and impossibly balanced. A gift."),
]


# Paints for the painting system: pigment name -> (display name, colour).
PIGMENTS = {
	"black": ("Ink black", "1d1a1f"), "blue": ("Woad blue", "2f4f8f"), "red": ("Madder red", "b02a2e"),
	"white": ("Chalk white", "f4f1ea"), "ochre_red": ("Red ochre", "a4472d"), "ochre": ("Yellow ochre", "c58b3a"),
	"yellow": ("Marigold yellow", "f4c430"), "orange": ("Fire-lily orange", "f26a1b"), "violet": ("Violet", "7b4fb0"),
	"grey": ("Ash grey", "8d8a86"), "pink": ("Blossom pink", "f4a6c0"), "green": ("Moss green", "4f8f5a"),
}


def sn_array(values):
	return "Array[StringName]([%s])" % ", ".join('&"%s"' % v for v in values)


def color(hexs):
	r, g, b = (int(hexs[i:i + 2], 16) / 255.0 for i in (0, 2, 4))
	return "Color(%.3f, %.3f, %.3f, 1)" % (r, g, b)


def esc(s):
	return s.replace("\\", "\\\\").replace('"', '\\"')


def write(path, script_path, script_class, body_lines):
	full = os.path.join(ROOT, path)
	os.makedirs(os.path.dirname(full), exist_ok=True)
	with open(full, "w") as f:
		f.write('[gd_resource type="Resource" script_class="%s" format=3]\n\n' % script_class)
		f.write('[ext_resource type="Script" path="%s" id="1"]\n\n' % script_path)
		f.write("[resource]\nscript = ExtResource(\"1\")\n")
		for line in body_lines:
			f.write(line + "\n")


def clear(dirname):
	d = os.path.join(ROOT, dirname)
	for name in os.listdir(d):
		if name.endswith(".tres"):
			os.remove(os.path.join(d, name))


def clear_rec(dirname):
	d = os.path.join(ROOT, dirname)
	os.makedirs(d, exist_ok=True)
	clear(dirname)


def main():
	for d in ("data/ingredients", "data/collectibles", "data/arrows", "data/recipes", "data/stations", "data/dishes", "data/items"):
		clear(d)
	ids = set()
	for x in I:
		assert x["id"] not in ids, x["id"]
		ids.add(x["id"])
		lines = [
			'id = &"%s"' % x["id"], 'display_name = "%s"' % esc(x["name"]),
			'description = "%s"' % esc(x["desc"]), "weight_class = %d" % x["wc"],
			"craft_tags = %s" % sn_array(x["craft"]), "base_price = %d" % x["price"],
			'canon = "%s"' % x["canon"], "color = %s" % color(x["color"]),
			"tags = %s" % sn_array(x["tags"]), "regions = %s" % sn_array(x["regions"]),
			'season = &"%s"' % x["season"],
			"night_only = %s" % str(x["extra"].get("night_only", False)).lower(),
			"perishes_at_dawn = %s" % str(x["extra"].get("perishes_at_dawn", False)).lower(),
			"respawn_days = %s" % float(x["respawn"]), 'abundance = &"%s"' % x["ab"],
			"edible = %s" % str(x["edible"]).lower(), "nutrition = %s" % float(x["nut"]),
			"food_days = %s" % float(x["food"]), 'pigment = &"%s"' % x["pigment"],
		]
		write("data/ingredients/%s.tres" % x["id"], "res://data/ingredients/ingredient_data.gd", "IngredientData", lines)
	for m in MATERIALS:
		lines = ['id = &"%s"' % m["id"], 'display_name = "%s"' % m["name"], 'description = "%s"' % esc(m["desc"]),
			"weight_class = %d" % m["wc"], "craft_tags = %s" % sn_array(m["craft"]), "base_price = %d" % m["price"],
			"color = %s" % color(m["color"]), 'canon = "%s"' % m.get("canon", "X")]
		write("data/items/%s.tres" % m["id"], "res://data/items/item_data.gd", "ItemData", lines)
	for cid, name, regions, desc, col, ab in C:
		lines = ['id = &"%s"' % cid, 'display_name = "%s"' % esc(name), 'description = "%s"' % esc(desc),
			"weight_class = 0", "color = %s" % color(col), "regions = %s" % sn_array(regions),
			'abundance = &"%s"' % ab]
		write("data/collectibles/%s.tres" % cid, "res://data/collectibles/collectible_data.gd", "CollectibleData", lines)
	for a in ARROWS:
		lines = ['id = &"%s"' % a["id"], 'item_id = &"%s"' % a["item_id"], 'display_name = "%s"' % a["name"],
			"mass = %s" % a["mass"], "drag = %s" % a["drag"], "wet_drag_multiplier = %s" % a["wet"],
			"wet_speed_multiplier = %s" % a["wspeed"], "stone_break_chance = %s" % a["brk"],
			"fae_lethal = %s" % str(a["fae"]).lower(), "damage = %s" % a["dmg"], 'effect = &"%s"' % a["effect"],
			"shaft_color = %s" % color(a["shaft"]), "fletching_color = %s" % color(a["fletch"])]
		write("data/arrows/%s.tres" % a["id"], "res://data/arrows/arrow_data.gd", "ArrowData", lines)
		# The arrow as an inventory item.
		item = ['id = &"%s"' % a["item_id"], 'display_name = "%s"' % a["name"], 'description = "%s"' % esc(a["desc"]),
			"weight_class = 0", 'craft_tags = Array[StringName]([&"arrow"])', "base_price = %d" % a["price"],
			'canon = "%s"' % a["canon"], "color = %s" % color(a["fletch"])]
		write("data/items/%s.tres" % a["item_id"], "res://data/items/item_data.gd", "ItemData", item)
	for rid, name, inputs, out, count in RECIPES:
		dict_body = ", ".join('"%s": %d' % (k, v) for k, v in inputs.items())
		lines = ['id = &"%s"' % rid, 'display_name = "%s"' % name, "inputs = {%s}" % dict_body,
			'output = &"%s"' % out, "output_count = %d" % count]
		write("data/recipes/%s.tres" % rid, "res://data/recipes/craft_recipe.gd", "CraftRecipe", lines)
	for sid, name, methods, phase, fae_safe, max_ing in STATIONS:
		lines = ['id = &"%s"' % sid, 'display_name = "%s"' % name, "methods = %s" % sn_array(methods),
			"phase = %d" % phase, "fae_safe = %s" % str(fae_safe).lower(), "max_ingredients = %d" % max_ing,
			"night_only = %s" % str(STATION_RULES.get(sid, {}).get("night_only", False)).lower(),
			'required_flag = "%s"' % STATION_RULES.get(sid, {}).get("required_flag", "")]
		write("data/stations/%s.tres" % sid, "res://data/stations/station_data.gd", "StationData", lines)
	for did, name, method, req, note in DISHES:
		lines = ['id = &"%s"' % did, 'display_name = "%s"' % name, 'method = &"%s"' % method,
			"required = %s" % sn_array(req), 'journal_note = "%s"' % esc(note)]
		write("data/dishes/%s.tres" % did, "res://data/dishes/dish_data.gd", "DishData", lines)

	clear_rec("data/wardrobe/pieces"); clear_rec("data/wardrobe/hair"); clear_rec("data/wardrobe/makeup")
	n_pieces = 0
	for pid, name, slots, hides, colours, warmth, stealth, swift, reaction, source, phase, canon, mesh, desc in PIECES:
		for cname, chex in colours.items():
			vid = pid if cname == "" else "%s_%s" % (pid, cname)
			vname = name if cname == "" else "%s (%s)" % (name, cname)
			lines = ['id = &"%s"' % vid, 'display_name = "%s"' % esc(vname), 'description = "%s"' % esc(desc),
				"slots = %s" % sn_array(slots), "hides_body_regions = %s" % sn_array(hides),
				'mesh_path = "res://characters/feyre/wardrobe/%s.glb"' % mesh, "color = %s" % color(chex),
				"warmth = %s" % float(warmth), "stealth = %s" % float(stealth), "swift = %s" % float(swift),
				'reaction_tag = &"%s"' % reaction, 'source = &"%s"' % source, "phase = %d" % phase, 'canon = "%s"' % canon]
			write("data/wardrobe/pieces/%s.tres" % vid, "res://data/wardrobe/wardrobe_piece.gd", "WardrobePiece", lines)
			n_pieces += 1
	for hid, name, canon, occ in HAIR:
		lines = ['id = &"%s"' % hid, 'display_name = "%s"' % esc(name), 'mesh_path = "res://characters/feyre/hair/%s.glb"' % hid,
			"occupies_head = %s" % str(occ).lower(), 'canon = "%s"' % canon]
		write("data/wardrobe/hair/%s.tres" % hid, "res://data/wardrobe/hairstyle_data.gd", "HairstyleData", lines)
	for mid, name, ch, chex, amt, sheen in MAKEUP:
		lines = ['id = &"%s"' % mid, 'display_name = "%s"' % esc(name), 'channel = &"%s"' % ch, "color = %s" % color(chex),
			"amount = %s" % amt, "sheen = %s" % sheen]
		write("data/wardrobe/makeup/%s.tres" % mid, "res://data/wardrobe/makeup_data.gd", "MakeupData", lines)
	print("wardrobe pieces %d (from %d designs), hairstyles %d, makeup %d" % (n_pieces, len(PIECES), len(HAIR), len(MAKEUP)))
	for pig, (name, hexs) in PIGMENTS.items():
		lines = ['id = &"pig_%s"' % pig, 'display_name = "%s"' % name, 'description = "A cake of %s paint."' % name.lower(),
			"weight_class = 0", 'craft_tags = Array[StringName]([&"pigment"])', "base_price = 2", "color = %s" % color(hexs)]
		write("data/items/pig_%s.tres" % pig, "res://data/items/item_data.gd", "ItemData", lines)
	used = {x["pigment"] for x in I if x["pigment"]}
	assert used <= set(PIGMENTS), used - set(PIGMENTS)
	for bid, name, draw, vmin, vmax, sway, loud, canon, desc in BOWS:
		lines = ['id = &"%s"' % bid, 'display_name = "%s"' % name, "draw_time = %s" % draw, "min_speed = %s" % vmin,
			"max_speed = %s" % vmax, "sway_degrees = %s" % sway, "loudness = %s" % loud]
		write("data/bows/%s.tres" % bid, "res://data/bows/bow_data.gd", "BowData", lines)
	for bid, name, canon, desc in [("hunting_bow", "Hunting bow", "C", "Plain, worn, a poor girl's bow.")] + [(b[0], b[1], b[7], b[8]) for b in BOWS]:
		lines = ['id = &"bow_%s"' % bid, 'display_name = "%s"' % name, 'description = "%s"' % esc(desc), "weight_class = 3",
			'craft_tags = Array[StringName]([&"bow"])', 'canon = "%s"' % canon, "color = %s" % color("b08a5a")]
		write("data/items/bow_%s.tres" % bid, "res://data/items/item_data.gd", "ItemData", lines)
	print("ingredients %d, collectibles %d, materials %d, arrows %d, recipes %d, stations %d, dishes %d" % (
		len(I), len(C), len(MATERIALS), len(ARROWS), len(RECIPES), len(STATIONS), len(DISHES)))


if __name__ == "__main__":
	main()
