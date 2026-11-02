#!/usr/bin/env python3
"""Writes the Calanmai chapter's staging (ch20-22, L45) under data/story/act5/:
one Act2Stage per scene (story/act5/calanmai/*.gd).

Marks are authored in world/house space and written in each anchor's local
frame (anchors.tres for the manor, tools/court/court_content_table.gd for the
Hill of the Rite), like tools/story/gen_house_beats.py: re-run if an anchor moves.
    python3 tools/story/gen_calanmai_beats.py
Lines: the book's words where the Keeper quoted them (2026-11-02, ch20-22);
everything else is listed in `invented` (canon:"X").
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_house_beats as H  # noqa: E402

ROOT = H.ROOT
OUT = os.path.join(ROOT, "data/story/act5")
COURT_TABLE = os.path.join(ROOT, "tools/court/court_content_table.gd")


def court_anchors():
    out = {}
    for m in re.finditer(r'\["(calanmai_[a-z_]+)", (-?[\d.]+), (-?[\d.]+), (-?[\d.]+), [\d.]+\]', open(COURT_TABLE).read()):
        out[m.group(1)] = ([float(m.group(2)), 0.0, float(m.group(3))], float(m.group(4)))
    return out


def stage(name, anchor_id, marks, lines, invented, canon, yaws=None, extra=None):
    H.OUT = OUT
    anchor = ALL[anchor_id]
    H.write_stage(name, anchor, marks, yaws or {}, lines, invented, canon, extra)
    print("wrote data/story/act5/%s (%d marks, %d lines)" % (name, len(marks), len(lines)))


ALL = {**H.anchors(), **court_anchors()}
os.makedirs(OUT, exist_ok=True)

# --- ch20 dusk: the order to stay inside (entrance hall) -----------------------
stage("fire_night_order_stage.tres", "manor_window_hide", {
    "tamlin": (4.0, 0.0, -33.0), "feyre_look": (6.0, 0.0, -31.0), "door": (6.0, 0.0, -26.5),
    "out": (6.0, 0.0, -18.0),
}, {
    "dusk": ("", "Dying sunlight through the hall. He's bare to the waist but for the baldric."),
    "calanmai": ("Tamlin", "It's Calanmai. I have to go."),
    "rite": ("Tamlin", "As a High Lord, I have to partake in the Great Rite."),
    "lock": ("Tamlin", "Go to your chamber. Lock your doors, set up a snare, whatever you do."),
    "drums": ("", "Far off on the hills, the drums begin."),
}, ["dusk", "drums"],
    "Ch20 (Keeper 2026-11-02, [C]): Tamlin alone, at dusk in the hall, shirtless but for the baldric, armed. "
    "'It's Calanmai... I have to go.' 'As a High Lord, I have to partake in the Great Rite.' 'Go to your chamber... "
    "Lock your doors, set up a snare, whatever you do.' Lucien isn't there. She locks herself in; by ten she follows the drums.")

# --- ch20 night: the first giant bonfire atop the hill --------------------------
C = ALL["calanmai_bonfires"][0]
stage("rite_fires_stage.tres", "calanmai_bonfires", {
    # The great pyre just ahead of where she comes up the hill, four more down the terraces,
    # and the summit ring's crown fire (court_content_table.gd: stone_ring 800,-1100).
    "pyre_0": (C[0] + 2.0, 0.0, C[2] - 16.0), "pyre_1": (C[0] + 55.0, 0.0, C[2] - 40.0),
    "pyre_2": (C[0] - 30.0, 0.0, C[2] - 52.0), "pyre_3": (C[0] + 120.0, 0.0, C[2] - 20.0),
    "pyre_4": (800.0, 0.0, -1100.0), "pyre_5": (C[0] + 70.0, 0.0, C[2] + 50.0),
    "drums": (560.0, 0.0, -860.0), "trench": (690.0, 0.0, -995.0),
}, {
    "masks": ("", "Hundreds of High Fae round the fire. Masks, only masks; when I try to see a face, it blurs into colour."),
    "trench": ("", "The crowd drifts toward a trench between two hills."),
}, ["masks", "trench"],
    "Ch20 (Keeper, [C]): 'the first giant bonfire atop the hill': 'hundreds of High Fae... I couldn't discern any of "
    "their features beyond the various masks.' She follows the crowd to 'a trench between two nearby hills', where a "
    "cave mouth opens, dressed with flowers. Six pyres, the ribbons and the crowd's dance are [X].")

# --- ch20-21: the three, the stranger, Lucien (the cave path) --------------------
stage("cave_path_stage.tres", "calanmai_cave_mouth", {
    "cave": (690.0, 0.0, -1000.0), "lucien_from": (700.0, 0.0, -1000.0),
}, {
    "fun": ("A faerie", "Just some Fire Night fun."),
    "pinned": ("", "Hands on my arms, pulling them away from my knives. Their eyes are black all the way through."),
    "looking": ("The stranger", "There you are. I've been looking for you."),
    "thanks": ("The stranger", "Thank you for finding her for me."),
    "enjoy": ("The stranger", "Enjoy the Rite."),
    "arm": ("", "His arm is still round my shoulders."),
    "trouble": ("The stranger", "Enjoy the Rite, then. Try to stay out of trouble."),
    "fool": ("Lucien", "Useless human fool."),
    "sack": ("", "He throws me over his shoulder like a sack of potatoes, and the night blurs past."),
}, ["pinned", "arm", "sack"],
    "Ch20-21 (Keeper, [C]): by a bonfire near the trees the three unmasked lesser faeries ('Just some Fire Night "
    "fun') pin her arms away from her knives and shove her; a stranger catches her: 'There you are. I've been looking "
    "for you.' His arm round her shoulders; 'Thank you for finding her for me... Enjoy the Rite'; they scuttle off. "
    "Black hair, violet eyes, all-black fine clothes, no mask. She steps out of his arm; 'Enjoy the Rite, then. Try "
    "to stay out of trouble.' SHE walks away; he doesn't vanish. Lucien finds her by the cave path ('Useless human "
    "fool'), throws her over his shoulder 'like a sack of potatoes' and runs at fae speed; the horse is left.")

# --- ch21: dropped in the hallway, the Rite explained -----------------------------
stage("rite_explained_stage.tres", "manor_window_hide", {
    "feyre_floor": (2.0, 0.0, -36.0), "lucien": (3.5, 0.0, -38.0), "lucien_exit": (6.0, 0.0, -26.5),
}, {
    "floor": ("", "He drops me on the floor of the hallway."),
    "hunter": ("Lucien", "Tonight he's the Hunter. The magic takes him; he hunts the white stag, and then he finds the Maiden in the cave."),
    "scent": ("Lucien", "If he'd caught your scent before he found her, it would have been you. He'd have had no say in it."),
    "stay": ("Lucien", "Stay in your room tonight, Feyre."),
}, ["hunter", "scent"],
    "Ch21 (Keeper, [C]): he drops her 'on the floor of the manor hallway' and explains the Hunter, the Maiden and the "
    "white stag there; his last line: 'Stay in your room tonight, Feyre.' The two explanation lines are paraphrase [X].")

# --- ch21: supper in the empty kitchen ---------------------------------------------
stage("kitchen_supper_stage.tres", "manor_alis_hiding", {
    "bread": (47.2, 0.92, -60.1), "apple": (47.6, 0.92, -59.8), "tart": (48.0, 0.92, -60.2),
    "table": (47.6, 0.0, -60.0),
}, {
    "empty": ("", "The kitchen's empty. Bread, an apple, a lemon tart."),
    "fed": ("", "Better. Now the painting room, where I can't think about any of it."),
}, ["fed"],
    "Ch21 (Keeper, [C]): hungry, she eats in 'the empty kitchen': bread, an apple, a lemon tart. Then she walks toward "
    "her painting room.")

# --- ch21: the moonlit hallway --------------------------------------------------------
stage("hallway_bite_stage.tres", "manor_kitchen_hall", {
    "tamlin_shadow": (40.5, 0.0, -50.8), "wall": (43.4, 0.0, -53.3), "pin": (43.4, 0.0, -52.75),
    "moon": (41.5, 4.2, -50.6), "exit": (36.0, 0.0, -50.5),
}, {
    "moon": ("", "Moonlight in the hallway. Someone is standing in it."),
    "going": ("Tamlin", "Going somewhere?"),
    "laurel": ("", "His mask, and a crown of laurel. His eyes aren't his own tonight."),
    "teeth": ("", "Claws punch into the wall beside my head. His teeth at my neck, holding, not piercing."),
    "dont": ("Feyre", "Don't bite me like some enraged beast."),
    "gone": ("", "He lets go. Then he's gone into the dark."),
}, ["moon", "laurel", "gone"],
    "Ch21 (Keeper, [C]): NOT in the kitchen: walking to her painting room she meets him in a moonlit hallway, masked, "
    "crowned with laurel. 'Going somewhere?' He pins her to the wall, claws punch into the wall, he bites to hold her; "
    "the teeth don't pierce. She: 'don't bite me like some enraged beast.' No slap in canon: her E is pushing him off. "
    "Restraint: the camera stays with her, the screen nearly dark, no close-up of the bite.")

# --- ch22 morning: the bruise at the vanity -------------------------------------------
stage("bruise_vanity_stage.tres", "feyre_bedroom_window", {
    "vanity": (41.85, 0.0, -66.0), "stand": (40.9, 0.0, -66.0), "mirror": (41.85, 1.35, -66.0),
}, {
    "bruise": ("", "An enormous bruise, where his teeth held me."),
    "scarf": ("", "A scarf would cover it."),
    "open": ("", "I open the collar of my tunic farther. Let them look."),
}, ["scarf"],
    "Ch22 (Keeper, [C]): the servants sleep in; she draws her own bath and sits at the vanity: 'an enormous bruise'. "
    "She looks for a scarf, then 'opened the collar of my tunic farther'. Her blue tunic, not a gown.")

# --- ch22 lunch: faerie pig -----------------------------------------------------------
stage("bruise_lunch_stage.tres", "manor_dining_table", {
    "feyre_chair": (25.95, 0.0, -38.0), "tamlin_seat": (16.25, 0.0, -38.0), "lucien_seat": (17.6, 0.0, -39.5),
}, {
    "look": ("", "Lucien's eyes go to my neck, and he grins."),
    "stayed": ("Tamlin", "You should have stayed in your room."),
    "pig": ("Feyre", "Faerie pig!"),
    "laugh": ("", "Lucien howls. Even Tamlin laughs."),
}, ["look"],
    "Ch22 (Keeper, [C]): she goes down to the dining room for LUNCH with the bruise showing. They laugh; Tamlin says "
    "she should have stayed in her room; she yells 'Faerie pig!' She paints the pig portraits after.")

# --- ch22 dinner: the white roses -------------------------------------------------------
stage("rose_dinner_stage.tres", "manor_dining_table", {
    "feyre_chair": (25.95, 0.0, -38.0), "tamlin": (24.6, 0.0, -38.9), "roses": (25.3, 0.82, -38.45),
}, {
    "sorry": ("Tamlin", "About last night. I'm sorry."),
    "roses": ("", "White roses, from his parents' garden."),
    "alis": ("", "Alis takes them up to my painting room."),
}, ["sorry"],
    "Ch22 (Keeper, [C]): 'We apologized at dinner. He even brought me a bouquet of white roses from his parents' "
    "garden.' Alis puts them in her painting room.")

# --- ch22: the gown, the table, the paintings ------------------------------------------
E = ALL["painting_room_easel"][0]
stage("gown_dinner_stage.tres", "manor_dining_table", {
    "feyre_chair": (25.95, 0.0, -38.0), "tamlin_seat": (16.25, 0.0, -38.0), "table": (21.0, 0.0, -38.0),
    "feyre_close": (22.7, 0.0, -38.0), "tamlin_close": (19.4, 0.0, -38.0),
}, {
    "far": ("Feyre", "You're so far away."),
    "shrinks": ("", "The table shrinks between us. It costs him; I can see it."),
    "come": ("Feyre", "Come with me."),
    "room": ("", "My painting room. I've never shown anyone."),
    "forest": ("Tamlin", "That was your forest. Where you hunted."),
    "want": ("Tamlin", "That one. I want that one."),
    "give": ("Feyre", "It's yours."),
    "dress": ("", "Not in a hunting tunic. Not tonight."),
}, ["come", "room", "give", "dress"],
    "Ch22 (Keeper, [C]): she wears a gown to dinner. 'You're so far away', and the table shrinks (it costs him). She "
    "leads him to her locked painting room. Seeing the snowy one: 'That was your forest. Where you hunted', then 'That "
    "one. I want that one.' He keeps the snowy forest, not the glen. [X]: he keeps whichever of the player's canvases "
    "is most wintry, with her premade 'hazy landscape of snow and skeletal trees' as the guaranteed fallback; it hangs "
    "in his bedchamber (no study in canon).",
    extra={
        # Lean spots along the painting room's west wall (house x 8..24, z -48..-28), clear of the canvas stacks (z -42, -45),
        # written relative to the painting_room_easel anchor so GownDinner reads them from there.
        "lean_1": tuple(round(v, 3) for v in (9.2 - E[0], 0.0, -33.6 - E[2])),
        "lean_2": tuple(round(v, 3) for v in (9.2 - E[0], 0.0, -35.9 - E[2])),
        "lean_3": tuple(round(v, 3) for v in (9.2 - E[0], 0.0, -38.2 - E[2])),
        "lean_4": tuple(round(v, 3) for v in (9.2 - E[0], 0.0, -40.5 - E[2])),
        "view": tuple(round(v, 3) for v in (11.4 - E[0], 0.0, -37.0 - E[2])),
    })
