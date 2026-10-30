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
ing("ing_ash_wood", "Ash wood", ["ash"], [W, OLD, ASHG], "any", MEDIUM, edible=False, nut=0.0, respawn=30, ab="rare", price=0, canon="C", color="d9cbb0", craft=["ash_shaft"], desc="Pale, straight-grained ash. The one wood the fae fear. Carve it into an arrow and keep it close.")
ing("ing_oak_gall", "Oak gall", ["bind", "bitter"], [W, OLD], "any", TINY, edible=False, respawn=6, color="8a6d45", pigment="black", desc="Hard little galls; good for ink.")
ing("ing_woad", "Woad", ["steady"], [V, W, COT], "any", SMALL, edible=False, respawn=5, ab="uncommon", price=2, color="2f4f8f", pigment="blue", desc="Dried leaves that make a deep blue.")
ing("ing_madder", "Madder root", ["warm"], [V, W, VALE], "any", SMALL, edible=False, respawn=5, ab="uncommon", price=2, color="a83226", pigment="red", desc="A root that bleeds red dye.")
ing("ing_snowdrop", "Snowdrop", ["cool", "steady"], [W, COT, WALLH], "winter", TINY, nut=0.0, respawn=4, ab="uncommon", color="f5f8fa", desc="The only flower in the winter forest. Feyre always notices them.")
ing("ing_pine_resin", "Pine resin", ["bind", "warm"], [W, OLD], "winter", SMALL, edible=False, respawn=4, color="c98d2c", craft=["glue"], desc="Amber resin for fletching glue and torches.")
ing("ing_wisteria", "Wisteria", ["quiet", "fae"], [MAN], "spring", TINY, nut=0.0, color="b9a0e0", desc="Lilac drapes over the manor walls.")
ing("ing_cherry_blossom", "Orchard blossom", ["swift"], [VALE, MAN], "spring", TINY, nut=0.0, color="f7c6d4", desc="Blossom that never quite falls.")
ing("ing_lilac", "Lilac", ["keen"], [MAN], "spring", TINY, nut=0.0, ab="uncommon", color="c8a2c8", desc="The scent sharpens everything.")
ing("ing_moss", "Starmoss", ["bright", "cool"], [WOODS, LAKES], "spring", TINY, nut=0.0, color="7fbf9a", desc="Moss flecked with pinprick lights.")
ing("ing_blighted_petals", "Blighted petals", ["bitter", "fae"], [BLIGHT], "spring", TINY, edible=False, ab="uncommon", color="6e6a5f", desc="Grey petals that crumble like ash.")

# ---- Flora and finds: human-realm winter additions (world lane request) ----
ing("ing_holly_berry", "Holly berries", ["bitter", "warm"], [W, COT], "winter", TINY, edible=False, respawn=5, color="c1121f", pigment="red", desc="Bright and poisonous. The red is worth crushing for paint.")
ing("ing_juniper_berry", "Juniper berries", ["warm", "keen"], [W, WALLH], "winter", TINY, nut=0.02, respawn=4, color="3d4f7a", desc="Resinous blue berries that clear the head.")
ing("ing_sloe", "Sloes", ["bitter", "bind"], [W, V], "winter", TINY, nut=0.02, respawn=4, color="2e3047", desc="Frost-sweetened, still mouth-puckering.")
ing("ing_hawthorn_haw", "Hawthorn haws", ["vital", "steady"], [W, V, COT], "winter", TINY, nut=0.03, food=0.03, respawn=3, color="9b1d20", desc="Mealy red haws left on the hedge for the birds.")
ing("ing_birch_bark", "Birch bark", ["bind"], [W, RIV], "any", SMALL, edible=False, respawn=6, color="eae7df", craft=["tinder"], desc="Papery bark that lights even when damp.")
ing("ing_chaga", "Chaga", ["vital", "warm"], [W, OLD], "winter", SMALL, nut=0.0, respawn=10, ab="rare", price=3, color="3a2a1e", desc="A charred-looking growth on birch; makes a warming tea.")
ing("ing_tinder_fungus", "Tinder fungus", ["warm"], [W, OLD], "any", SMALL, edible=False, respawn=8, ab="uncommon", color="7a5a3a", craft=["tinder"], desc="Hoof-shaped bracket that holds an ember for hours.")
ing("ing_old_mans_beard", "Old man's beard", ["vital", "bind"], [W, WALLH], "winter", TINY, edible=False, respawn=6, color="b8c4a8", desc="Grey-green lichen streaming from old branches; packs a wound.")
ing("ing_acorn", "Acorns", ["strong", "bitter"], [W, OLD], "any", TINY, nut=0.03, food=0.02, respawn=4, color="8b6b3e", desc="Bitter until leached. The hungry eat them anyway.")
ing("ing_hazelnut", "Hazelnuts", ["vital", "strong"], [W, V], "winter", TINY, nut=0.05, food=0.05, respawn=5, ab="uncommon", color="a0743f", desc="A squirrel's cache, found under the snow.")
ing("ing_pine_needles", "Pine needles", ["warm", "keen"], [W, OLD, WALLH], "any", TINY, nut=0.0, respawn=1, color="2f5233", desc="A bitter, bright tea against the cold.")
ing("ing_frozen_reed", "Frozen reeds", ["quiet"], [RIV], "winter", SMALL, edible=False, respawn=5, color="b5a77a", desc="Hollow reeds locked in the river ice; good for snare work and whistles.")
ing("ing_mistletoe", "Mistletoe", ["bitter", "fae"], [W, OLD], "winter", TINY, edible=False, respawn=8, ab="rare", color="d7e2c0", desc="Villagers say the fae love it. Feyre leaves it where it grows, mostly.")
ing("ing_wintergreen", "Wintergreen", ["cool", "vital"], [W], "winter", TINY, nut=0.01, respawn=3, color="2e6b4f", desc="Glossy leaves under the snow, with a sharp minty bite.")
ing("ing_shed_antler", "Shed antler", [], [W, OLD], "winter", MEDIUM, edible=False, respawn=20, ab="rare", price=3, color="d8cbb2", craft=["arrowhead_blank", "handle"], desc="Dropped by a stag. Carves into toggles, handles, even points.")
ing("ing_flint", "Flint", [], [W, RIV, BURNT], "any", SMALL, edible=False, respawn=10, ab="uncommon", price=1, color="4a4a52", craft=["knappable"], desc="Knaps into arrowheads, and strikes sparks.")
ing("ing_chalk", "Chalk", [], [V, RIV], "any", SMALL, edible=False, respawn=10, color="f2f0e8", pigment="white", desc="Soft white stone; a white for painting.")
ing("ing_red_ochre", "Red ochre", [], [RIV, BURNT], "any", SMALL, edible=False, respawn=10, ab="uncommon", price=2, color="a4472d", pigment="ochre_red", desc="Earth red from the riverbank cut.")
ing("ing_charcoal", "Charcoal", ["warm"], [BURNT, COT], "any", SMALL, edible=False, respawn=7, color="1c1c1c", pigment="black", craft=["tinder"], desc="From the burnt estate's beams. Draws, and burns again.")
ing("ing_clay", "Clay", ["bind"], [RIV], "any", SMALL, edible=False, respawn=6, color="9c8770", desc="Riverbank clay for sealing and for binding pigment.")
ing("ing_snowmelt_water", "Snowmelt water", ["cool", "vital"], [W, COT, WALLH], "winter", SMALL, nut=0.0, respawn=0.25, color="dfeef7", desc="Melted over the fire, it is the base of every stew.")
ing("ing_ice_moss", "Ice moss", ["cool", "quiet"], [RIV, WALLH], "winter", TINY, nut=0.01, respawn=4, color="9cb7b0", desc="Silvery moss in the river's frozen spray.")
ing("ing_hazel_rod", "Hazel rod", [], [W, V], "any", SMALL, edible=False, respawn=6, color="9b7b52", craft=["shaft_wood"], desc="Straight hazel shoots. Carved down, they make arrow shafts.")

# ---- Fauna products ----
ing("ing_venison", "Venison", ["vital", "strong", "warm"], [W, WOODS], "any", MEDIUM, nut=0.35, food=1.5, respawn=0, price=4, canon="C", color="7a2e2e", desc="A deer means days of food. Venison is life.")
ing("ing_sinew", "Sinew", ["bind"], [W, WOODS], "any", TINY, edible=False, respawn=0, price=1, color="d9c9a8", craft=["binding"], desc="Dried tendon for bowstrings and binding.")
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
ing("ing_iron_filings", "Iron filings", ["iron"], [V], "any", SMALL, edible=False, respawn=0, price=3, canon="C?", color="5b5b60", desc="Village folk-protection against the fae. Applied, never eaten.")

# ---- Prepared foods ----
ing("ing_manor_fruit", "Manor fruit", ["vital"], [MAN], "spring", SMALL, nut=0.15, food=0.3, respawn=1, canon="C", color="f0a04b", desc="Platters of impossible fruit at every meal.")
ing("ing_faerie_wine", "Faerie wine", ["fae", "strong"], [MAN, CAL], "spring", SMALL, nut=0.0, respawn=0, canon="C", color="8e2c48", desc="Loosens everything. Careful.")
ing("ing_faerie_bread", "Faerie bread", ["vital", "fae"], [MAN, HAM], "spring", SMALL, nut=0.2, food=0.4, respawn=1, color="e8cf9a", desc="Light as air and gone too soon.")
ing("ing_candied_flowers", "Candied flowers", ["swift", "fae"], [MAN, HAM], "spring", TINY, nut=0.05, respawn=2, color="f2b5d4", desc="Sugared violets and rose petals.")
ing("ing_stale_bread", "Stale bread", ["vital"], [COT, V], "any", SMALL, nut=0.08, food=0.25, respawn=0, price=1, canon="C", color="b89a6a", desc="Thin porridge and stale bread: the cottage's usual.")
ing("ing_venison_stew", "Venison stew", ["vital", "warm"], [COT], "any", MEDIUM, nut=0.4, food=1.0, respawn=0, canon="C", color="6b3a26", desc="Her kills feed the family.")

# ---- Crafting materials (not foraged; made or bought) ----
MATERIALS = [
	dict(id="mat_shaft", name="Arrow shaft", wc=TINY, craft=["shaft"], price=0, color="b08a5a", desc="A straight, scraped hazel shaft."),
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
	("col_snow_owl_down", "Owl down", [W, WALLH], "A wisp of white down caught on bark.", "f5f2ea", "common"),
]

ARROWS = [
	dict(id="wood", item_id="arrow_wood", name="Wood arrow", mass=0.03, drag=0.0022, wet=1.7, wspeed=0.92,
	     brk=0.35, fae=False, dmg=1.0, shaft="8c6a45", fletch="d9d2c3", price=1,
	     desc="Hazel shaft, feather fletching, a flint or iron head."),
	dict(id="ash", item_id="arrow_ash", name="Ash arrow", mass=0.034, drag=0.0020, wet=1.6, wspeed=0.93,
	     brk=0.2, fae=True, dmg=1.5, shaft="e3d6bd", fletch="8b5a2b", price=0,
	     desc="Carved whole from ash wood. The one thing the fae truly fear."),
]

# id, name, inputs{key:count}, output, count
RECIPES = [
	("carve_shaft", "Carve shafts", {"ing_hazel_rod": 1}, "mat_shaft", 2),
	("knap_arrowhead", "Knap arrowheads", {"ing_flint": 1}, "mat_arrowhead", 2),
	("antler_arrowhead", "Carve antler points", {"ing_shed_antler": 1}, "mat_arrowhead", 4),
	("arrow_wood", "Wood arrow", {"mat_shaft": 1, "tag:fletching": 1, "mat_arrowhead": 1}, "arrow_wood", 1),
	("arrow_ash", "Ash arrow", {"ing_ash_wood": 1, "tag:fletching": 1}, "arrow_ash", 1),
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
			"color = %s" % color(m["color"])]
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
			"fae_lethal = %s" % str(a["fae"]).lower(), "damage = %s" % a["dmg"],
			"shaft_color = %s" % color(a["shaft"]), "fletching_color = %s" % color(a["fletch"])]
		write("data/arrows/%s.tres" % a["id"], "res://data/arrows/arrow_data.gd", "ArrowData", lines)
		# The arrow as an inventory item.
		item = ['id = &"%s"' % a["item_id"], 'display_name = "%s"' % a["name"], 'description = "%s"' % esc(a["desc"]),
			"weight_class = 0", 'craft_tags = Array[StringName]([&"arrow"])', "base_price = %d" % a["price"],
			'canon = "%s"' % ("C" if a["fae"] else "X"), "color = %s" % color(a["shaft"])]
		write("data/items/%s.tres" % a["item_id"], "res://data/items/item_data.gd", "ItemData", item)
	for rid, name, inputs, out, count in RECIPES:
		dict_body = ", ".join('"%s": %d' % (k, v) for k, v in inputs.items())
		lines = ['id = &"%s"' % rid, 'display_name = "%s"' % name, "inputs = {%s}" % dict_body,
			'output = &"%s"' % out, "output_count = %d" % count]
		write("data/recipes/%s.tres" % rid, "res://data/recipes/craft_recipe.gd", "CraftRecipe", lines)
	for sid, name, methods, phase, fae_safe, max_ing in STATIONS:
		lines = ['id = &"%s"' % sid, 'display_name = "%s"' % name, "methods = %s" % sn_array(methods),
			"phase = %d" % phase, "fae_safe = %s" % str(fae_safe).lower(), "max_ingredients = %d" % max_ing]
		write("data/stations/%s.tres" % sid, "res://data/stations/station_data.gd", "StationData", lines)
	for did, name, method, req, note in DISHES:
		lines = ['id = &"%s"' % did, 'display_name = "%s"' % name, 'method = &"%s"' % method,
			"required = %s" % sn_array(req), 'journal_note = "%s"' % esc(note)]
		write("data/dishes/%s.tres" % did, "res://data/dishes/dish_data.gd", "DishData", lines)
	print("ingredients %d, collectibles %d, materials %d, arrows %d, recipes %d, stations %d, dishes %d" % (
		len(I), len(C), len(MATERIALS), len(ARROWS), len(RECIPES), len(STATIONS), len(DISHES)))


if __name__ == "__main__":
	main()
