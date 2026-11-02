#!/usr/bin/env python3
"""Writes data/story/moments/*.tres: phases 2-8 of book 1 as StoryMoments.

Source: lore/07-story/timeline-overview.md (Keeper's chapter spine). Run from
the repo root:  python3 tools/story/gen_moments.py
Steps vocabulary: story/framework/moment_space.gd. [X] marks invented detail.
"""
import os

V = lambda x, y, z: ("V3", x, y, z)

def W(s): return {"do": "wait", "s": s}
def C(mode, focus="", allow=None):
    d = {"do": "control", "mode": mode}
    if focus: d["focus"] = focus
    if allow: d["allow"] = allow
    return d
def SP(actor, at, face=V(0, 0, 0)): return {"do": "spawn", "actor": actor, "at": at, "face": face}
def DS(actor): return {"do": "despawn", "actor": actor}
def CU(actor, cue): return {"do": "cue", "actor": actor, "cue": cue}
def MO(mood, i, s=1.5, shake=0.0): return {"do": "mood", "mood": mood, "i": i, "s": s, "shake": shake}
def CEL(kind="deed"): return {"do": "celebrate", "kind": kind}
def R(flag): return {"do": "raise", "flag": flag}
def J(entry): return {"do": "journal", "entry": entry}
def G(item, n=1): return {"do": "grant", "item": item, "n": n}
def IN(n, r=4.0): return {"do": "interact", "n": n, "r": r}
def ST(s, r, near="self", strict=False, fail=""):
    d = {"do": "stay", "s": s, "r": r, "near": near, "strict": strict}
    if fail: d["fail_fact"] = fail
    return d
def UF(flag): return {"do": "until_flag", "flag": flag}
def UK(kind, n): return {"do": "until_killed", "kind": kind, "n": n}
def DEC(options, s, default): return {"do": "decision", "options": options, "s": s, "default": default}

M = []
def moment(id, ch, anchor, region, req, steps, trigger="enter", r=6.0, night=False, notes=""):
    M.append(dict(id=id, ch=ch, anchor=anchor, region=region, req=req, steps=steps,
                  trigger=trigger, r=r, night=night, notes=notes))

# --- P2 The grounds (ch 6-11) ------------------------------------------------
moment("first_dinner", "7", "manor_dining_table", "manor_house", ["wall_crossed"], [
    R("fact.first_dinner_seen"), C("LOOK"), SP("tamlin", V(0, 0, -2.5)), SP("lucien", V(2, 0, -1.2)), W(1.5),
    CU("tamlin", "i_dont_keep_slaves"), C("NONE", "tamlin", ["interact"]),
    IN(3, 3.0), CU("lucien", "presses_about_andras"), W(3.0), R("first_dinner_eaten"), CEL("meal"),
], r=3.0, notes="Magic holds her at the table until she eats (three bites).")
moment("curtain_trap", "7", "feyre_bedroom_window", "manor_house", ["first_dinner_eaten"], [
    C("LOOK", "self"), W(1.0), C("WALK"), IN(2, 3.0), R("curtain_trap_set"),
], trigger="interact", r=2.5, night=True, notes="Next morning it knocks over Alis.")
moment("bogge", "9-10", "bogge_hunt_path", "border_woods", ["first_dinner_eaten"], [
    SP("lucien", V(1.5, 0, 0)), C("WALK"), CU("lucien", "talks_of_andras"), W(3.0),
    J("treaty_no_loophole"), J("masks_are_permanent"), CU("lucien", "dont_move_look_ahead"),
    C("LOOK"), MO("dread", 0.9, 1.5, 0.15), SP("bogge", V(-6, 0, 4)), CU("bogge", "pass_behind"),
    {"do": "gaze_avoid", "actor": "bogge", "s": 14.0, "cone": 40.0, "max": 0.8, "fail_fact": "fact.bogge_looked"},
    DS("bogge"), MO("dread", 0.2, 3.0), CU("tamlin", "hunts_the_bogge"), R("bogge_survived"),
], r=8.0, notes="It is real only if acknowledged: looking at it for more than 0.8 s fails the scene.")
moment("puca", "10-11", "garden_gate", "manor_grounds", ["bogge_survived"], [
    SP("puca", V(0, 0, -10)), C("WALK", "puca"), CU("puca", "looks_like_father"), W(2.0),
    SP("tamlin", V(2, 0, 1)), CU("tamlin", "stops_her"), C("LOOK", "puca"), CU("puca", "shift_image"),
    MO("dread", 0.6, 1.0), W(3.0), DS("puca"), R("puca_resisted"),
], r=5.0, night=True, notes="She climbs down the trellis toward 'Father'; Tamlin stops her at the gate.")

# --- P3 The house and the woods (ch 12-17) -----------------------------------
# The house beats are deeds played by story/act3/house (L28): HallMark (her X
# marks), HallMap (rooms on her page), WoundDressing (the night of the Bogge:
# the map on the foyer table, the beast, the infirmary) and StudyMural (her
# painter's eye). These moments only turn their facts into the phase deeds.
for i in range(1, 6):
    moment("hall_mark_%d" % i, "12", "hall_mark_%d" % i, "manor_house", ["puca_resisted"], [
        UF("fact.hall_x_%d" % i), R("fact.hall_mark_%d" % i)], trigger="auto",
        notes="Played by HallMark: an X or a circle on her map of the halls.")
moment("manor_map", "12", "", "manor_house", ["puca_resisted"],
    [UF("fact.hall_mark_%d" % i) for i in range(1, 6)] + [UF("fact.hall_map_set_down"), R("manor_map_drawn"), CEL("map")],
    trigger="auto", notes="Global: all five marks made and the map set down on the foyer table (WoundDressing).")
moment("wound_dressing", "12", "manor_infirmary", "manor_house", ["manor_map_drawn"], [
    UF("fact.tamlin_hand_bound"), R("tamlin_wound_dressed"),
], trigger="auto", notes="Played by WoundDressing: clean, bind and wrap his Bogge-bitten hand in the small infirmary.")
moment("study_mural", "13", "manor_study_mural", "manor_house", ["tamlin_wound_dressed"], [
    UF("fact.mural_studied"), J("prythian_history_mural"), SP("lucien", V(2, 0, 2)), CU("lucien", "how_to_catch_a_suriel"),
    J("suriel_method"), R("fact.suriel_method_known"), R("study_mural_seen"),
], trigger="auto", notes="Played by StudyMural: three details of the mural studied with a painter's eye.")
# The Suriel and the naga are deeds played by story/act3/suriel (L26):
# SurielSnare (snare, bait, downwind wait, answers) and NagaAmbush (the fight).
# These moments only turn their facts into the phase deeds.
moment("suriel", "14", "suriel_snare", "suriel_glade", ["fact.suriel_method_known"], [
    UF("fact.suriel_answered"), R("suriel_bound"),
], trigger="auto", notes="Played by SurielSnare: young birches, running water, bait, a double-loop snare, wait downwind.")
moment("naga", "15", "suriel_snare", "suriel_glade", ["suriel_bound"], [
    UF("fact.naga_escaped"), R("naga_survived"),
], trigger="auto", notes="Played by NagaAmbush: four naga; she kills one, survives until Tamlin arrives.")
# The Summer faerie is played by story/act3/summer (L29): SummerFaerieTriage on
# the hall table (holding his hand when he dies) or, if he died alone, the
# daytime vigil at his grave (SummerFaerieGrave). Either raises the farewell.
moment("summer_faerie", "17", "", "manor_house", ["naga_survived"], [
    UF("fact.summer_faerie_farewell"), R("summer_faerie_comforted"),
], trigger="auto", notes="Unwinnable triage on the entrance-hall table; the deed is holding his hand until he dies.")

# --- P4 The wider court (ch 18-19) -------------------------------------------
# Coded by L44 (story/act4/starlight_pool_swim.gd, Act2Spaces.CODED): these
# steps are the fallback and name the deed. No knife in ch18 (Keeper).
moment("starlight_pool", "18", "starlight_pool", "starlight_glen", ["summer_faerie_comforted"], [
    SP("tamlin", V(2, 0, 2)), C("WALK"), CU("tamlin", "shows_his_childhood_pool"), CEL("vista"),
    ST(6.0, 8.0), R("starlight_pool_found"), CEL("deed"), J("lucien_autumn_history"),
], r=10.0, notes="L44: picnic on the glen shore; she finds the pool below the falls and jumps in; Tamlin tells Lucien's history.")
moment("gallery", "19", "manor_gallery", "manor_house", ["gallery_opened"], [
    C("WALK"), {"do": "gaze_hold", "actor": "self", "s": 3.0, "cone": 35.0}, CEL("gallery"),
    R("fact.gallery_seen"),
], r=6.0, notes="L30: gallery_opened is her deed (first P4 stroke at the easel, systems/studio/studio_deeds.gd); this is her first look inside.")
moment("first_painting", "19-20", "painting_room_easel", "manor_house", ["gallery_opened"], [
    UF("first_painting"), R("first_painting"), CEL("painting"),
], trigger="interact", r=2.5, notes="L30: the studio (ui/studio) raises first_painting when her first canvas is finished.")
moment("rose_thorn", "19", "rose_garden_bush", "manor_grounds", ["gallery_opened"], [
    SP("tamlin", V(1, 0, 1)), C("LOOK", "tamlin"), CU("tamlin", "kisses_her_palm"), W(2.0),
    R("fact.rose_thorn_healed"), CEL("rose"),
], trigger="interact", r=2.5, notes="Optional: the mating-gift garden.")
moment("attor", "19", "attor_hiding_spot", "manor_grounds", ["first_painting"], [
    SP("tamlin", V(1, 0, -2)), CU("tamlin", "hides_her"), C("WALK"), MO("dread", 0.8, 1.0),
    SP("attor", V(0, 3, -12)), CU("attor", "speaks_of_her"),
    ST(18.0, 2.5, "self", True, "fact.attor_detected"), MO("dread", 0.2, 2.0), DS("attor"),
    R("attor_evaded"),
], r=3.0, notes="L44 (story/act4/attor_in_the_garden.gd): by day; Tamlin says stay hidden and she hides herself behind the hedge; leaving cover or rustling is detection (a permanent fact) and the scene ends.")

# --- P5 Calanmai (ch 20-22) --------------------------------------------------
moment("calanmai_fires", "20", "calanmai_bonfires", "hill_of_the_rite", ["attor_evaded"], [
    MO("fire_night", 1.0, 3.0), R("calanmai_attended"),
], r=25.0, night=True)
moment("cave_mouth", "20-21", "calanmai_cave_mouth", "hill_of_the_rite", ["calanmai_attended"], [
    SP("high_fae_male", V(2, 0, -2)), SP("high_fae_male_2", V(-2, 0, -2)), SP("high_fae_male_3", V(0, 0, -3)),
    C("WALK"), MO("dread", 0.9, 0.8, 0.2), W(4.0), SP("rhysand", V(0, 0, 2)), CU("rhysand", "steadies_her"),
    CU("high_fae_male", "flee"), DS("high_fae_male"), DS("high_fae_male_2"), DS("high_fae_male_3"),
    MO("dread", 0.3, 2.0), C("LOOK", "rhysand"), W(4.0), J("stranger_violet_eyes"), R("stranger_met"),
    SP("lucien", V(3, 0, 3)), CU("lucien", "carries_her_home"),
], r=5.0, night=True)
moment("bite", "21", "manor_kitchen_hall", "manor_house", ["stranger_met"], [
    SP("tamlin", V(0, 0, -1)), C("NONE", "tamlin", ["interact"]), MO("dread", 0.8, 0.3, 0.3),
    CU("tamlin", "pins_and_bites"), W(2.5),
    DEC([{"action": "interact", "fact": "fact.bite.slapped"}], 4.0, "fact.bite.slapped"),
    MO("dread", 0.0, 2.0), R("bite_endured"), G("obj_white_roses"),
], r=4.0, night=True, notes="She slaps him (canon); the next day he gives her white roses.")
moment("paintings_shown", "22", "manor_dining_table", "manor_house", ["bite_endured", "first_painting"], [
    SP("tamlin", V(0, 0, -2.5)), C("LOOK", "tamlin"), CU("tamlin", "shrinks_the_table"), IN(1, 3.0),
    CU("tamlin", "keeps_the_snowy_forest"), R("fact.tamlin_kept_snowy_forest"), R("paintings_shown"),
    CEL("deed"),
], trigger="interact", r=3.0)

# --- P6 The blight tightens (ch 23-27) ---------------------------------------
moment("glamour_lift", "23", "glamour_lift_glade", "blossom_vale", ["paintings_shown"], [
    SP("tamlin", V(0, 0, -1.2)), C("LOOK", "tamlin"), W(2.0), CU("tamlin", "kisses_her_eyelids"),
    R("glamour_lifted"), CU("feyre", "smell_flowers"), CEL("glamour"), W(3.0),
], r=8.0, notes="Magic smells of flowers now; true forms show (GlamourLayer).")
moment("fountain_head", "24", "manor_fountain", "manor_grounds", ["glamour_lifted"], [
    C("LOOK", "self"), MO("dread", 0.7, 1.0), W(3.0), J("night_court_mark"), R("fountain_head_found"),
], r=6.0)
moment("solstice", "25", "solstice_dance_floor", "solstice_meadow", ["fountain_head_found"], [
    G("outfit_solstice_blue_gown"), G("hair_loose_with_flowers"), SP("lucien", V(2, 0, 0)),
    SP("tamlin", V(0, 0, -6)), CU("tamlin", "plays_the_fiddle"), CEL("solstice"), ST(15.0, 15.0),
    CU("lucien", "warns_of_faerie_wine"), CU("tamlin", "takes_her_to_the_wisps"),
    ST(12.0, 3.0, "tamlin"), CEL("dance"), R("solstice_danced"),
], r=12.0)
moment("rhysand_visit", "26", "manor_window_hide", "manor_house", ["solstice_danced"], [
    SP("lucien", V(1, 0, 0)), CU("lucien", "glamours_her"), SP("rhysand", V(0, 0, -6)),
    SP("tamlin", V(-2, 0, -5)), MO("dread", 0.7, 1.0), C("WALK", "rhysand"), CU("rhysand", "mocks_tamlin"),
    ST(10.0, 2.5), CU("rhysand", "pries_into_her_mind"), MO("dread", 0.9, 0.3, 0.25),
    DEC([{"action": "interact", "fact": "fact.false_name_clare_beddor"}], 6.0, "fact.false_name_clare_beddor"),
    CU("rhysand", "see_you_under_the_mountain"), MO("dread", 0.2, 2.0), R("rhysand_faced"),
], r=3.0)
moment("sent_home", "27-28", "manor_tamlin_room", "manor_house", ["rhysand_faced"], [
    SP("tamlin", V(0, 0, -1.5)), C("LOOK", "tamlin"), W(4.0), CU("tamlin", "sends_her_home"),
    G("outfit_mortal_travel_dress"), MO("enchanted_sleep", 1.0, 2.5), W(3.0), R("sent_home"),
    {"do": "grade", "to": "human_spring", "s": 2.0}, {"do": "travel", "region": "archeron_estate", "anchor": "arrival_archeron_estate"},
    MO("calm", 0.0, 2.0),
], r=4.0)

# --- P7 Return to the human realm (ch 28-31) ---------------------------------
moment("nesta_truth", "29-30", "archeron_estate_garden", "archeron_estate", ["sent_home"], [
    SP("elain", V(1, 0, -1)), SP("nesta", V(0, 0, -5)), CU("elain", "digs_the_garden"),
    ST(8.0, 3.0, "elain"), R("fact.garden_dug_with_elain"), C("WALK", "nesta"),
    ST(10.0, 3.0, "nesta"), CU("nesta", "tells_the_truth"), J("nesta_tried_the_wall"), R("nesta_truth_heard"),
], r=6.0)
moment("beddor_fire", "31", "archeron_estate_hall", "archeron_estate", ["nesta_truth_heard"], [
    C("LOOK", "self"), MO("dread", 0.5, 1.5), W(3.0), J("beddor_family_fire"), R("beddor_fire_learned"),
], r=5.0)
moment("wall_recross", "31", "wall_gate_north", "wall_seam", ["beddor_fire_learned"], [
    C("LOOK"), {"do": "grade", "to": "spring", "s": 2.0}, R("wall_recrossed"),
], r=6.0, notes="She rides back alone; the manor beyond is silent.")

# --- P8 The pass (ch 32) -----------------------------------------------------
moment("alis_truth", "32", "manor_alis_hiding", "manor_house", ["wall_recrossed"], [
    MO("dread", 0.5, 2.0), SP("alis", V(0, 0, -1.5)), C("LOOK", "alis"), W(6.0),
    J("amarantha_and_the_curse"), J("andras_crossed_to_help"), R("alis_truth_heard"),
], r=4.0, notes="The manor shows signs of violent struggle (region lanes: StateVisibility on wall_recrossed).")
moment("departure", "32", "the_pass_road", "the_pass", ["alis_truth_heard"], [
    C("LOOK"), W(3.0), R("departed_for_mountain"),
], r=10.0)


def lit(v):
    if isinstance(v, tuple) and v[0] == "V3":
        return "Vector3(%s, %s, %s)" % tuple(float(x) for x in v[1:])
    if isinstance(v, bool): return "true" if v else "false"
    if isinstance(v, (int, float)): return repr(float(v)) if isinstance(v, float) else str(v)
    if isinstance(v, str): return '"%s"' % v
    if isinstance(v, list): return "[%s]" % ", ".join(lit(x) for x in v)
    if isinstance(v, dict): return "{%s}" % ", ".join('"%s": %s' % (k, lit(x)) for k, x in v.items())
    raise TypeError(v)

out_dir = "data/story/moments"
os.makedirs(out_dir, exist_ok=True)
for f in os.listdir(out_dir):
    if f.endswith(".tres"): os.remove(os.path.join(out_dir, f))
for m in M:
    lines = ['[gd_resource type="Resource" script_class="StoryMoment" format=3]', '',
             '[ext_resource type="Script" path="res://story/framework/story_moment.gd" id="1"]', '',
             '[resource]', 'script = ExtResource("1")',
             'id = &"%s"' % m["id"], 'chapters = "%s"' % m["ch"], 'anchor_id = &"%s"' % m["anchor"],
             'region_id = &"%s"' % m["region"], 'require_flags = PackedStringArray(%s)' % ", ".join('"%s"' % f for f in m["req"]),
             'night_only = %s' % lit(m["night"]), 'trigger = &"%s"' % m["trigger"], 'entry_radius = %s' % float(m["r"]),
             'steps = Array[Dictionary]([%s])' % ", ".join(lit(s) for s in m["steps"]),
             'notes = "%s"' % m["notes"], '']
    open(os.path.join(out_dir, m["id"] + ".tres"), "w").write("\n".join(lines))

# Contract table of anchors.
rows = {}
for m in M:
    if m["anchor"]:
        rows.setdefault((m["region"], m["anchor"]), []).append("%s (ch %s)" % (m["id"], m["ch"]))
with open("docs/contracts/story_anchors_table.md", "w") as f:
    f.write("<!-- Generated by tools/story/gen_moments.py. Do not edit by hand. -->\n")
    f.write("| Region | Anchor (Marker3D name) | Moments |\n|---|---|---|\n")
    for (region, anchor), ids in sorted(rows.items()):
        f.write("| %s | `%s` | %s |\n" % (region, anchor, ", ".join(ids)))
    f.write("| archeron_estate | `arrival_archeron_estate` | where the carriage sets her down (travel target) |\n")
print("%d moments, %d anchors" % (len(M), len(rows)))
