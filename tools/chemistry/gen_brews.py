#!/usr/bin/env python3
"""Generates the named brews (data/chemistry/brews/*.tres) for lane L62.

Run from the repo root:  python3 tools/chemistry/gen_brews.py
Edit the table below, never the generated .tres by hand (R8, R15).

A brew is recognised by what a result does (its effect tags after the rules in
lore/05-foraging-chemistry/tags-and-rules.md: same tags reinforce, opposites
cancel, fae multiplies and tolls, bitter flips healing to harm, bind for
salves and steeps), never by a fixed ingredient list. Every row carries one
real witness combination; tests/unit/chemistry/test_forage_chemistry.gd runs
each through Chemistry.combine and checks it makes that brew.

Priority (higher wins when several match): poison 9, pigment 8, fae 7,
keen 6, bright/quiet 5, swift/strong 4, steady 3, warm/cool 2, heal 1, plain 0.
"""
import os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "data", "chemistry", "brews")
ALL = []  # every method
NOT_STEEP = ["roast", "stew", "infuse", "cook", "bake", "preserve", "distill", "salve", "tincture"]

# id, name, methods, need {key: min}, priority, witness (station, [ids]),
# colour, note (Feyre's voice), extra: kind, forbid, element, canon
B = []
def brew(id, name, methods, need, pri, station, ids, color, note, kind="", forbid=(), element="", canon="X"):
    B.append(dict(id=id, name=name, methods=methods, need=need, pri=pri, station=station, ids=ids,
                  color=color, note=note, kind=kind, forbid=list(forbid), element=element, canon=canon))

# ---- Food (hearth, campfire, manor kitchen) ----
brew("brew_hunters_stew", "Hunter's stew", ["stew"], {"warm": 2.5, "hunger_relief": 0.2}, 2,
     "hearth", ["ing_venison", "ing_chaga"], "c2703d",
     "Thick enough to stand a spoon in. Warmth that lasts the whole walk out.", canon="C?")
brew("brew_hearty_stew", "Hearty stew", ["stew"], {"strong": 1.5, "hunger_relief": 0.2}, 4,
     "hearth", ["ing_venison", "ing_hazelnut"], "a0623a",
     "Heavy and good. My arms will thank me at full draw.")
brew("brew_spit_roast", "Spit roast", ["roast"], {"hunger_relief": 0.15}, 0,
     "hearth", ["ing_rabbit"], "d08a4e",
     "Crackling skin, fat in the flames. Nothing wasted.", canon="C?")
brew("brew_spring_feast", "Spring feast", ["cook"], {"heal": 0.4, "swift": 0.5}, 4,
     "manor_kitchen", ["ing_dead_chicken", "ing_honeysuckle", "ing_manor_fruit"], "f2b8c6",
     "More food than the cottage saw in a month, and it makes my feet light.")
brew("brew_honey_cakes", "Honey cakes", ["bake"], {"heal": 0.2, "swift": 0.5}, 4,
     "manor_kitchen", ["ing_honey", "ing_cherry_blossom", "ing_wild_strawberry"], "f4d58d",
     "Sticky, golden, gone in three bites.")
brew("brew_hedgerow_preserve", "Hedgerow preserve", ["preserve"], {"hunger_relief": 0.08}, 0,
     "manor_kitchen", ["ing_blackberry", "ing_wild_strawberry", "ing_salt"], "8e3b6b",
     "Summer in a jar. It will keep long after the fruit is gone.")

# ---- Teas (infuse) ----
brew("brew_mending_tea", "Mending tea", ["infuse"], {"heal": 0.3}, 1,
     "hearth", ["ing_willow_bark", "ing_rose_hip"], "e7a3a8",
     "Bitter bark, sweet hips. The ache in my hands lets go.")
brew("brew_hearthwarm_tea", "Hearth-warm tea", ["infuse"], {"warm": 2.0}, 2,
     "hearth", ["ing_chaga", "ing_blackberry"], "c9653c",
     "It sits in my chest like a coal. The snow can wait.")
brew("brew_snowmelt_tea", "Snowmelt tea", ["infuse"], {"cool": 2.0}, 2,
     "hearth", ["ing_wintergreen", "ing_snowmelt_water"], "bfe3e6",
     "Cold as the brook. Heat slides off me after.")
brew("brew_steadying_tea", "Steadying tea", ["infuse"], {"steady": 1.2}, 3,
     "hearth", ["ing_snowdrop"], "eef3f6",
     "My hands stop shaking. My aim stops wandering.")
brew("brew_quickfoot_tea", "Quickfoot tea", ["infuse"], {"swift": 1.2}, 4,
     "manor_kitchen", ["ing_honeysuckle"], "f6dd8c",
     "Nectar and sunlight. I could run to the Wall and back.")
brew("brew_clear_eye_tea", "Clear-eye tea", ["infuse"], {"keen": 1.2}, 6,
     "hearth", ["ing_pine_needles"], "7fa07a",
     "Sharp and green. Every track in the snow stands up to be read.")
brew("brew_faelight_tisane", "Faelight tisane", ["infuse"], {"bright": 1.0, "fae_toll": 0.4}, 7,
     "fae_potion_room", ["ing_moonflower", "ing_glowcap"], "d9d2ff",
     "It glows in the cup. It glows in me. The edges of things go soft.")

# ---- Remedies (stillroom, potion room) ----
brew("brew_healing_salve", "Healing salve", ["salve"], {"heal": 0.3}, 1,
     "stillroom", ["ing_willow_bark", "ing_honey"], "f3c7a4",
     "For bites that won't close and wounds magic can't mend.", canon="C?")
brew("brew_burn_salve", "Burn salve", ["salve"], {"cool": 1.5}, 2,
     "stillroom", ["ing_elderflower", "ing_wintergreen", "ing_clay"], "cfe8e1",
     "Cool clay and flowers. For when I get too close to the fire.")
brew("brew_glow_draught", "Glow draught", ["distill"], {"bright": 2.0}, 5,
     "stillroom", ["ing_glowcap", "ing_moss"], "b6f2d4",
     "A little lantern I can drink. The dark backs away from me.")
brew("brew_hush_draught", "Hush draught", ["distill"], {"quiet": 2.0}, 5,
     "stillroom", ["ing_lavender", "ing_wild_hyacinth"], "a99ad8",
     "No scent, no sound. Let the wolves sniff at nothing.")
brew("brew_oakheart_draught", "Oakheart draught", ["distill"], {"strong": 2.0}, 4,
     "stillroom", ["ing_hazelnut", "ing_acorn"], "9b7a4c",
     "Tastes like the forest floor. The bowstring comes back like nothing.")
brew("brew_iron_will_tincture", "Iron-will tincture", ["tincture"], {"keen": 2.0, "steady": 1.5}, 6,
     "fae_potion_room", ["ing_lilac", "ing_juniper_berry", "ing_woad"], "8fa3d6",
     "Nesta never needed a bottle for this. I do. Something's painted the wrong shade, and I notice the seams.")
brew("brew_giddy_tincture", "Giddy tincture", ["tincture"], {"strong": 1.0, "fae_toll": 0.4}, 7,
     "fae_potion_room", ["ing_faerie_wine", "ing_honey"], "f0a6d8",
     "One drop and the music gets louder. I'll pay for it in the morning.")
brew("brew_bitter_draught", "Bitter draught", NOT_STEEP, {"harm": 0.1}, 9,
     "stillroom", ["ing_foxglove", "ing_oak_gall"], "5d4a6e",
     "Pretty flowers, ugly end. Never by mistake.", kind="poison")

# ---- Steeps (coat wood arrows; stillroom, potion room, starlight pool) ----
brew("brew_firebrand_steep", "Firebrand steep", ["steep"], {"warm": 1.5}, 2,
     "stillroom", ["ing_pine_resin", "ing_madder"], "ff8a3d",
     "Resin and red root. The arrowhead catches as it flies. Dry grass won't forgive it.",
     element="fire")
brew("brew_rime_steep", "Rime steep", ["steep"], {"cool": 1.5}, 2,
     "stillroom", ["ing_snowdrop", "ing_wintergreen", "ing_clay"], "a9dcf2",
     "Frost blooms where it lands. Even a fire gives up under it.", element="water")
brew("brew_hush_steep", "Hush steep", ["steep"], {"quiet": 1.5}, 5,
     "stillroom", ["ing_hollow_root", "ing_lavender"], "9d8fcf",
     "Whatever it touches forgets to stay awake.")
brew("brew_starlight_steep", "Starlight steep", ["steep"], {"bright": 1.5}, 5,
     "starlight_pool", ["ing_starlight_water", "ing_honey"], "fff3c4",
     "Pool water at midnight. The arrow burns white where it lands.")
brew("brew_lure_steep", "Lure steep", ["steep"], {"heal": 0.2}, 1,
     "stillroom", ["ing_honey", "ing_wild_strawberry"], "f7a8b8",
     "Sweet enough to bring anything hungry to where it lands.",
     forbid=["warm", "cool", "quiet", "bright"])

# ---- Paint ----
brew("brew_painters_colours", "Painter's colours", ["infuse"], {}, 8,
     "hearth", ["ing_woad"], "5b7bd6",
     "Colour I made myself, from things I found. I want to paint everything.", kind="pigment")


def sn_array(xs):
    return "Array[StringName]([%s])" % ", ".join('&"%s"' % x for x in xs)


def color(hexs):
    r, g, b = (int(hexs[i:i + 2], 16) / 255.0 for i in (0, 2, 4))
    return "Color(%.3f, %.3f, %.3f, 1)" % (r, g, b)


def esc(s):
    return s.replace("\\", "\\\\").replace('"', '\\"')


def main():
    os.makedirs(OUT, exist_ok=True)
    for f in os.listdir(OUT):
        if f.endswith(".tres"):
            os.remove(os.path.join(OUT, f))
    ids = set()
    for b in B:
        assert b["id"] not in ids, b["id"]
        ids.add(b["id"])
        need = "{\n%s\n}" % ",\n".join('&"%s": %s' % (k, float(v)) for k, v in b["need"].items()) if b["need"] else "{}"
        body = "\n".join([
            '[gd_resource type="Resource" script_class="BrewRule" format=3]',
            "",
            '[ext_resource type="Script" path="res://data/chemistry/brew_rule.gd" id="1"]',
            "",
            "[resource]",
            'script = ExtResource("1")',
            'id = &"%s"' % b["id"],
            'display_name = "%s"' % esc(b["name"]),
            'note = "%s"' % esc(b["note"]),
            "methods = %s" % sn_array(b["methods"]),
            'kind = &"%s"' % b["kind"],
            "need = %s" % need,
            "forbid = %s" % sn_array(b["forbid"]),
            "priority = %d" % b["pri"],
            'element = &"%s"' % b["element"],
            "color = %s" % color(b["color"]),
            'witness_station = &"%s"' % b["station"],
            "witness = %s" % sn_array(b["ids"]),
            'canon = "%s"' % b["canon"],
            "",
        ])
        with open(os.path.join(OUT, b["id"] + ".tres"), "w") as fh:
            fh.write(body)
    print("gen_brews: wrote %d brews to data/chemistry/brews" % len(B))


if __name__ == "__main__":
    main()
