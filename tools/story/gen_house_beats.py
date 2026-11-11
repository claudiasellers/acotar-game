#!/usr/bin/env python3
"""Writes the p3 house beats' data (ch12-13, L28) under data/story/act3/house/:

  hall_map_plan.tres          HallMapPlan: the five marks, pictures, tower views
  wound_dressing_stage.tres   Act2Stage for WoundDressing + InfirmaryWorktable
  study_mural_stage.tres      Act2Stage for StudyMural

Marks are authored here in house space (the manor layout's x/z, y above the
ground floor) and written in each anchor's local frame, reading the anchors'
positions and yaws from data/regions/spring_court/manor_estate/house/anchors.tres,
so the scenes follow if the manor lane moves an anchor: just re-run.
Run from the repo root:  python3 tools/story/gen_house_beats.py
Lines are the book's words where the Keeper gave them (2026-11-01, ch12 [C]);
anything else is listed in `invented` (canon:"X").
"""
import math
import os
import re

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ANCHORS = os.path.join(ROOT, "data/regions/spring_court/manor_estate/house/anchors.tres")
OUT = os.path.join(ROOT, "data/story/act3/house")

# Mural notice spots as UV, from tools/art/paint_prythian_mural.py's output.
MURAL_SPOTS = {"mountain": (0.508, 0.432), "crocuses": (0.449, 0.676), "lambs": (0.515, 0.700),
               "roses": (0.576, 0.684), "wall": (0.508, 0.788)}


def anchors():
    text = open(ANCHORS).read()
    out = {}
    for blk in text.split("[sub_resource")[1:]:
        m = re.search(r'anchor_id = &"([^"]+)"', blk)
        if not m:
            continue
        pos = [float(v) for v in re.search(r"position = Vector3\(([^)]*)\)", blk).group(1).split(",")]
        yaw = re.search(r"yaw_deg = (-?[\d.]+)", blk)
        out[m.group(1)] = (pos, float(yaw.group(1)) if yaw else 0.0)
    return out


def to_local(anchor, p):
    (ax, _ay, az), yaw = anchor
    t = math.radians(yaw)
    dx, dz = p[0] - ax, p[2] - az
    return (round(dx * math.cos(t) - dz * math.sin(t), 3), round(p[1], 3), round(dx * math.sin(t) + dz * math.cos(t), 3))


def v3(v):
    return "Vector3(%s, %s, %s)" % tuple(("%g" % x) for x in v)


def gd_str(s):
    return '"%s"' % s.replace("\\", "\\\\").replace('"', '\\"')


def write_stage(name, anchor, marks, yaws, lines, invented, canon, extra=None):
    body = ['[gd_resource type="Resource" script_class="Act2Stage" format=3]', "",
            '[ext_resource type="Script" path="res://story/act2/act2_stage.gd" id="1"]', "", "[resource]",
            'script = ExtResource("1")', "marks = {"]
    rows = []
    for k in sorted(marks):
        rows.append("%s: %s" % (gd_str(k), v3(to_local(anchor, marks[k]))))
    for k in sorted(yaws):
        rows.append("%s: %s" % (gd_str(k + "_yaw"), v3((0, round(yaws[k] - anchor[1], 3), 0))))
    for k in sorted(extra or {}):
        rows.append("%s: %s" % (gd_str(k), v3(extra[k])))
    body.append(",\n".join(rows))
    body.append("}")
    body.append("lines = {")
    body.append(",\n".join('%s: {"text": %s, "who": %s}' % (gd_str(k), gd_str(t), gd_str(w)) for k, (w, t) in sorted(lines.items())))
    body.append("}")
    body.append("invented = PackedStringArray(%s)" % ", ".join(gd_str(i) for i in sorted(invented)))
    body.append("canon = %s" % gd_str(canon))
    open(os.path.join(OUT, name), "w").write("\n".join(body) + "\n")


# --- the night of the Bogge (ch12) ------------------------------------------------
WOUND_MARKS = {
    # The foyer (entrance hall, x -10..10, z -60..-28): a little table by the
    # west wall between the columns, and the glass garden doors to the north.
    "foyer_table": (-8.0, 0.0, -47.0), "foyer_map": (-8.0, 0.71, -47.0),
    "garden_doors": (0.0, 0.0, -70.5), "saloon_mid": (-1.8, 0.0, -67.5), "saloon_in": (-1.8, 0.0, -62.5),
    "hall_door": (-1.0, 0.0, -59.0),  # between the west sofa and the tea table, past the armchair
    "beast_stop": (-6.5, 0.0, -53.0),
    # His walk to the infirmary, door to door through the service wing.
    "r1": (2.0, 0.0, -55.0), "r2": (9.0, 0.0, -50.0), "r3": (12.0, 0.0, -50.0), "r4": (40.0, 0.0, -50.0),
    # Round the east end of the servants' hall's long table, not through it.
    "r5": (44.0, 0.0, -50.5), "r6": (49.0, 0.0, -50.5), "r7": (49.0, 0.0, -47.0), "r8": (54.8, 0.0, -46.5),
    "r9": (54.8, 0.0, -38.0), "r10": (63.0, 0.0, -37.5), "tamlin_lean": (70.2, 0.0, -38.3), "exit": (58.0, 0.0, -37.5),
    # The small infirmary (x 64..74, z -41..-34): worktable, deep sink at the back,
    # the cabinets (bandage shelves) and the washstand drawer.
    "table": (71.3, 0.0, -39.2), "sink": (73.55, 0.0, -35.6), "hand": (70.6, 0.95, -38.6),
    "feyre_work": (70.4, 0.0, -37.4),
    "src_bowl": (66.0, 0.9, -34.7), "src_linen": (66.0, 1.0, -40.2), "src_bandage": (72.0, 1.0, -40.2),
}
WOUND_YAWS = {"table": 180.0, "sink": 90.0, "foyer_table": 0.0}
WOUND_LINES = {
    "set_down": ("", "Xs and circles. The doors, the windows, the marble stairs."),
    "breeze": ("", "A breeze. The glass garden doors stand open."),
    "beast_sounds": ("", "The scrape of claw, a huff of uneven breathing, the dripping of blood."),
    "shift": ("", "Between one step and the next, he changed forms. She squeezes her eyes shut at the blinding flash."),
    "feyre_bogge": ("Feyre", "Did you kill the Bogge?"),
    "tamlin_yes": ("Tamlin", "Yes."),
    "feyre_hurt": ("Feyre", "You're hurt."),
    "drip": ("", "His hand is bleeding. Drip, drip, onto the marble."),
    "tamlin_cant_write": ("Tamlin", "You can't write, can you."),
    "tamlin_adept": ("Tamlin", "No wonder you became so adept at other things."),
    "feyre_where": ("Feyre", "Where can we clean up your hand?"),
    "tamlin_infirmary": ("Tamlin", "There's a small infirmary."),
    "supplies": ("", "Cabinets and drawers. A bowl, clean linen, a bandage."),
    "fill": ("", "Water first. The deep sink at the back."),
    "inferno": ("", "The heat of his skin, like an inferno."),
    "cuts": ("", "A few vicious cuts. None of them need stitching."),
    "carry": ("", "The water's red now. To the sink with it."),
}
WOUND_INVENTED = ["set_down", "breeze", "drip", "supplies", "fill", "carry"]
WOUND_CANON = ("Ch12 (Keeper 2026-11-01, [C]): sleepless, she creeps barefoot down the moonlit stairs to the foyer, sets her "
               "little map on the foyer table and draws a few Xs and circles for the doors, the windows, the marble stairs. "
               "A breeze; he comes in through the open glass garden doors in beast form, eyes glowing, limping, dark shining "
               "stains on the marble; the beast fills the hall like a cage. Between one step and the next he changes forms "
               "(blinding flash, her eyes shut); fae, still and weary, no glow, clothes in shreds, only the hand bleeds. "
               "Lines as given. The infirmary: more of a supply closet with a worktable, cabinets, drawers, a deep sink at the "
               "back; she sorts supplies, cleans the blood and dirt in a bowl of water, binds and wraps his hand (a few vicious "
               "cuts, none needing stitches), carries the bowl of bloody water to the sink; he is silent, claws retracted. "
               "No salve in the book (dropped). Foyer table spot, route and props: X.")

# --- the study mural (ch13) -------------------------------------------------------
MURAL_MARKS = {
    # On the library's east wall (x -20), its north end beside the bank of windows,
    # facing west (the book's "study" is the manor library; Keeper, L38).
    "mural": (-20.38, 2.0, -69.0), "view": (-22.8, 0.0, -69.0),
}
MURAL_YAWS = {"mural": -90.0}
MURAL_LINES = {
    "painter_eye": ("", "Prythian, all of it, painted across the wall."),
    "spot_crocuses": ("", "Crocuses for Spring. Whoever painted these knew violet from lilac."),
    "spot_lambs": ("", "Lambs, three dabs of white each. So little paint, and they're soft."),
    "spot_roses": ("", "Roses, of course. The pink laid over a darker red so they glow."),
    "spot_wall": ("", "The Wall. Just a dark smear, as if the painter couldn't bear to look."),
    "spot_mountain": ("", "The mountain in the middle. It belongs to no court."),
    "whole": ("", "If I had paints like these."),
}
MURAL_INVENTED = ["painter_eye", "spot_crocuses", "spot_lambs", "spot_roses", "spot_wall", "whole"]
MURAL_CANON = ("Ch13 [C]: the study, candles lit by magic, a mural of Prythian's history: the War, the seven courts, the "
               "mountain in the middle that belongs to no court; Spring painted with crocuses, lambs and roses (Keeper "
               "correction); the Wall a dark smear. Her thoughts on the brushwork: X.")

# --- her map of the halls (ch12) ------------------------------------------------------
MARKS = [
    (1, "x", "the front doors", "The front doors. An X."),
    (2, "o", "the marble stairs", "The marble stairs. A circle."),
    (3, "x", "the glass garden doors", "The garden doors. An X."),
    (4, "x", "the kitchen door", "The kitchen door. An X."),
    (5, "o", "the servants' stair", "The servants' stair. A circle."),
]
PICTOGRAMS = {"entrance_hall": "stair", "garden_saloon": "flower", "tamlin_study": "book", "map_room": "key",
              "svc_infirmary": "bandage", "svc_stillroom": "bottle", "dining_hall": "cup", "feyre_bedroom": "bed",
              "painting_room": "brush", "dressing_room": "crown", "gallery": "brush", "armory": "bow"}
LOOKOUTS = {"observatory": ["rosewild", "fae_village", "autumn_foothills"],
            "rose_bower": ["solstice_meadow", "hill_of_the_rite", "eastern_woods"],
            "lantern_lookout": ["western_fells"], "moon_tower": ["blossom_vale"]}
MIN_ROOMS = 10
PLAN_CANON = ("Ch12 [C]: sleepless, she maps the manor halls with X marks; she can't write, so the page has Xs and circles "
              "for the doors, the windows, the marble stairs. Room pictures, the five marked places and the tower views: X. "
              "Start moved earlier by the owner (2026-11-11), V: from the morning Alis trips her rope (ch7) it runs "
              "beside the other beats; the Bogge night at the foyer table stays after the puca (ch12).")
# Owner, 2026-11-11: the mapping starts the morning after the rope (fact.alis_tripped).
START_FLAG = "fact.alis_tripped"
FIRST_THOUGHT = "If I'm going to be stuck here, I need to know my way around this house."


def write_plan(anch):
    marks = []
    for n, shape, what, thought in MARKS:
        (x, _y, z), _yaw = anch["hall_mark_%d" % n]
        marks.append('{"n": %d, "shape": "%s", "what": %s, "thought": %s, "x": %g, "z": %g}' % (
            n, shape, gd_str(what), gd_str(thought), x, z))
    pics = ", ".join("&%s: %s" % (gd_str(k), gd_str(v)) for k, v in sorted(PICTOGRAMS.items()))
    looks = ", ".join("&%s: PackedStringArray(%s)" % (gd_str(k), ", ".join(gd_str(p) for p in v)) for k, v in sorted(LOOKOUTS.items()))
    body = ['[gd_resource type="Resource" script_class="HallMapPlan" format=3]', "",
            '[ext_resource type="Script" path="res://story/act3/house/hall_map_plan.gd" id="1"]', "", "[resource]",
            'script = ExtResource("1")',
            "marks = Array[Dictionary]([%s])" % ", ".join(marks),
            "pictograms = {%s}" % pics, "lookouts = {%s}" % looks, "min_rooms = %d" % MIN_ROOMS,
            'start_flag = %s' % gd_str(START_FLAG), "first_thought = %s" % gd_str(FIRST_THOUGHT),
            "canon = %s" % gd_str(PLAN_CANON)]
    open(os.path.join(OUT, "hall_map_plan.tres"), "w").write("\n".join(body) + "\n")


def main():
    os.makedirs(OUT, exist_ok=True)
    anch = anchors()
    write_plan(anch)
    write_stage("wound_dressing_stage.tres", anch["manor_infirmary"], WOUND_MARKS, WOUND_YAWS, WOUND_LINES,
                WOUND_INVENTED, WOUND_CANON)
    spots = {"spot_" + k: (u, v, 0.0) for k, (u, v) in MURAL_SPOTS.items()}
    write_stage("study_mural_stage.tres", anch["manor_study_mural"], MURAL_MARKS, MURAL_YAWS, MURAL_LINES,
                MURAL_INVENTED, MURAL_CANON, extra=spots)
    print("wrote 3 resources to", os.path.relpath(OUT, ROOT))


if __name__ == "__main__":
    main()
