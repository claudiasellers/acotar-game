#!/usr/bin/env python3
"""Builds data/journal/story_journal.tres, Feyre's sketchbook (L54).

One chapter per story phase (data/phases/spring_court_phases.tres), each with
its steps in story order. Every phase exit flag must be some step's done_flag
(tests/unit/journal/test_story_journal.gd checks it). Lines are in Feyre's
voice, never ahead of the step they belong to; hints run gentle to plain.
Steps with guide= borrow flags and lines from the G thoughts
(data/guide/act1_guide.tres), so both always agree.

Run: python3 tools/journal/build_journal.py
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "data/journal/story_journal.tres"

# (phase, numeral, title, opener, [steps])
# step: dict(id, done, req=[], fail=[], after, hints=[], memory, guide, canon)
# Hints start vague and in her voice; only the last may name a key (director, R2).
CHAPTERS = [
    ("p0_winter", "Chapter One", "Winter", "Snow to the knees and the larder bare. Four of us at the table, and only I hunt.", [
        dict(id="hunt", guide="hunt", memory="The doe, and the thing that came for her. Both mine.", canon="V"),
        dict(id="shoot", guide="shoot", canon="V"),
        dict(id="skin", guide="skin", memory="Its pelt, rolled tight in my pack.", canon="V"),
        dict(id="sell", guide="sell", memory="The pelt sold. Coin enough to breathe on, for a while.", canon="V"),
    ]),
    ("p1_wolf_and_crossing", "Chapter Two", "The Long Night", "Coin in the jar and a fire in the hearth. For one night, we can rest.", [
        dict(id="home", guide="home", memory="A life for a life. I said I would go, and I went.", canon="V"),
        dict(id="ride", done="wall_crossed", req=["beast_claim_accepted"],
             after="Wherever it's taking me, there's no turning back now.",
             hints=["The white horse knows the way. All I can do is hold on and look.",
                    "Ride on through the woods. There's nothing to do but watch."],
             memory="His magic put me under. I woke in the saddle, and it was spring.", canon="A"),
    ]),
    ("p2_grounds", "Chapter Three", "Across the Wall", "Spring, in the dead of winter. Everything here is lovely, and none of it is safe.", [
        dict(id="arrive", done="fact.manor_arrived", req=["wall_crossed"],
             after="A house this big has a front door. Better to face them than stand out here.",
             hints=["The drive runs straight up to the great house.",
                    "Up the drive to the front doors, then follow where he leads."],
             memory="The doors opened on their own. He turned into a man at the table.", canon="A"),
        dict(id="bathe", done="fact.alis_bathed", req=["fact.manor_arrived"],
             after="Bathe. He says I could use a bath, and I couldn't argue.",
             hints=["The bath. Alis drew it for me.",
                    "The bath in my room is steaming. Step in (E)."],
             memory="Hot water, for the first time in years.", canon="A"),
        dict(id="dinner", done="first_dinner_eaten", req=["fact.alis_bathed"],
             after="They expect me at dinner. I won't eat their food. I can't starve, either.",
             hints=["My chair is at the far end of the table.",
                    "Sit in my chair and take a bite (E). The table won't let me up until I eat."],
             memory="I ate their food. Nothing happened to me, and the table let me go.", canon="A"),
        dict(id="curtain_trap", done="curtain_trap_set", req=["first_dinner_eaten"],
             after="If anything comes through my door tonight, I want warning.",
             hints=["My room is full of soft things that could be rope.",
                    "My bedroom window, after dark: those curtains have long trimmings.",
                    "At my window at night, twist the curtain trimmings into a rope and rig it from the light fixture to snap into anyone's face (E)."],
             memory="My rope caught Alis, not a monster.", canon="A"),
        dict(id="bogge", done="bogge_survived", req=["curtain_trap_set"], fail=["fact.bogge_looked"],
             after="If there's a way home, it's out past the grounds. Lucien hunts the border woods.",
             hints=["Lucien might take me with him if I go out where he hunts.",
                    "The border woods, with Lucien and my bow.",
                    "If something circles us, don't look. Eyes on one far tree, and think of good things."],
             memory="Something circled us and begged me to look. I didn't.", canon="A"),
        dict(id="puca", done="puca_resisted", req=["bogge_survived"],
             after="I can't sleep. Every night I watch the garden from my window.",
             hints=["Something moves by the hedges at night, under my window.",
                    "After dark, go down to the garden hedges.",
                    "At night, follow what waits by the hedges, all the way to the gates."],
             memory="It wore my father's face. It wasn't him.", canon="A"),
    ]),
    ("p3_house_and_woods", "Chapter Four", "The House and the Woods", "A prisoner should know her cage. I'll learn every hall of this one.", [
        dict(id="map", done="manor_map_drawn", req=["puca_resisted"],
             after="If I ever have to run, I need this house by heart.",
             hints=["Mark the halls my own way: crosses and circles, since I can't write.",
                    "Walk the halls and mark the doors that matter. The towers show the grounds.",
                    "Make all five marks and draw enough rooms, then set my map down on the foyer table at night (E)."],
             memory="My map of the halls: crosses, circles and little pictures.", canon="A"),
        dict(id="wound", done="tamlin_wound_dressed", req=["manor_map_drawn"],
             after="He's hurt, and nobody is helping him.",
             hints=["The infirmary. There'll be something in the cabinets.",
                    "Sort the bowl, linen and bandage from the cabinets, then clean and bind his hand (E)."],
             memory="I bound his hand. He saw I couldn't read.", canon="A"),
        dict(id="mural", done="study_mural_seen", req=["tamlin_wound_dressed"],
             after="There's a painted wall in the study I can't stop thinking about.",
             hints=["The study. Stand before the mural and really look.",
                    "Let my eyes rest on three details of the mural, one after another."],
             memory="The mural: the courts, the mountain, and spring in crocuses and lambs.", canon="A"),
        dict(id="suriel", done="suriel_bound", req=["study_mural_seen"],
             after="Lucien says there's a creature that will answer any question, if I can catch it.",
             hints=["The western woods, near young birches and running water.",
                    "A fresh-killed chicken for bait, and cord for a double-loop snare.",
                    "In the young-birch glade: set the snare (E), lay the bait, then wait hidden, still and downwind."],
             memory="It told me the truth. Then it told me to run.", canon="A"),
        dict(id="naga", done="naga_survived", req=["suriel_bound"],
             after="Run. Get away from the glade.",
             hints=["Cut it free, or stand and shoot. Water won't stop them.",
                    "My bow first, my knife when they're close. Keep moving."],
             memory="Four of them. I'd be dead if he hadn't come.", canon="A"),
        dict(id="summer_faerie", done="summer_faerie_comforted", req=["naga_survived"],
             after="I'm tired of being no use in this house.",
             hints=["Stay near the house at night. If something happens, be there.",
                    "At the long table in the entrance hall, take his hand (E) and stay with him."],
             memory="I held his hand until the end. I promised him his wings.", canon="A"),
    ]),
    ("p4_wider_court", "Chapter Five", "The Wider Court", "They ride out across his lands now, and sometimes they take me.", [
        dict(id="starlight", done="starlight_pool_found", req=["summer_faerie_comforted"],
             after="Tamlin wants to show me something.",
             hints=["Join them at the purple blanket in the glen.",
                    "Follow him down past the stream to the clearing.",
                    "At the hollow's rim, wade or jump into the water."],
             memory="A pool full of starlight. I swam in it.", canon="A"),
        dict(id="gallery", done="gallery_opened", req=["starlight_pool_found"],
             after="I asked for paint. I'd like to hold a brush again.",
             hints=["There's a room for painting now, with an easel.",
                    "Find the easel and make my first stroke (E)."],
             memory="He opened the gallery for me.", canon="A"),
        dict(id="first_painting", done="first_painting", req=["gallery_opened"],
             after="Finish something. Anything.",
             hints=["At the easel, keep painting until it's done."],
             memory="My first painting in years.", canon="V"),
        dict(id="attor", done="attor_evaded", req=["first_painting"], fail=["fact.attor_detected"],
             after="Tamlin's walking in the rose garden. I'd like to walk with him.",
             hints=["The rose garden's west walk, by day.",
                    "If he says hide, stay hidden and still. Make no noise.",
                    "Crouch, and don't move while it's close. Wait until it's gone."],
             memory="I stayed hidden. Whatever it was, it didn't find me.", canon="A"),
    ]),
    ("p5_calanmai", "Chapter Six", "Fire Night", "Drums in the hills all day. They're building bonfires.", [
        dict(id="fires", done="calanmai_attended", req=["attor_evaded"],
             after="They told me to lock myself in tonight. I'd rather see the fires.",
             hints=["The first great bonfire, on top of the hill.",
                    "Go up to the hill fires after dark, by ten o'clock."],
             memory="Fire Night. I went, though they told me not to.", canon="A"),
        dict(id="cave", done="stranger_met", req=["calanmai_attended"],
             after="The crowd's drifting toward the trees. I should keep my wits.",
             hints=["Toward the cave hung with leaves and flowers.",
                    "When someone holds me, step out of his arm."],
             memory="A stranger with violet eyes. I hope I never see him again.", canon="A"),
        dict(id="bruise", done="bite_endured", req=["stranger_met"],
             after="I'm not hiding in my room over this.",
             hints=["Lunch in the dining room. Let them see it."],
             memory="Faerie pig. Lucien howled. Even Tamlin smiled.", canon="A"),
        dict(id="paintings", done="paintings_shown", req=["bite_endured"],
             after="I'd like him to see what I've painted.",
             hints=["Come down to dinner in a gown.",
                    "Dress in a gown, go down to dinner, then lead him up to my painting room."],
             memory="He kept the snow-veiled woods.", canon="A"),
    ]),
    ("p6_blight_tightens", "Chapter Seven", "The Blight Tightens", "Something is closing in on this court. I can see it in all of them.", [
        dict(id="glen", done="glamour_lifted", req=["paintings_shown"],
             after="He asked me out to a glen by a brook.",
             hints=["A weeping willow by a brook, and a blanket under it.",
                    "Sit with him on the blanket under the willow (E)."],
             memory="He opened my eyes. Magic smells like jasmine and lilac and roses now.", canon="A"),
        dict(id="fountain", done="fountain_head_found", req=["glamour_lifted"],
             after="I want to paint the irises in the garden.",
             hints=["Carry my paints out to the garden.",
                    "In the morning, take my paints to the fountain's iris beds."],
             memory="A head on the heron's bill. I can't stop seeing it.", canon="A"),
        dict(id="solstice", done="solstice_danced", req=["fountain_head_found"],
             after="Midsummer. The whole court's in ribbons.",
             hints=["Alis will want to dress me for it.",
                    "Dress for the Solstice and go out to the dancing."],
             memory="We danced until sunrise among the will-o'-the-wisps.", canon="A"),
        dict(id="visitor", done="rhysand_faced", req=["solstice_danced"],
             after="A letter came from another court. Everyone's on edge.",
             hints=["Stay close to the house.",
                    "If they hide me, stay put and keep my answers short."],
             memory="He saw through everything. I gave him a false name.", canon="A"),
        dict(id="farewell", done="sent_home", req=["rhysand_faced"],
             after="He wants me far from here. I don't want to go.",
             hints=["My bedroom, tonight.", "Take his hand (E)."],
             memory="I went home.", canon="A"),
    ]),
    ("p7_return_home", "Chapter Eight", "Home Again", "Silk dresses and a manor. My family is rich now, and I can't sleep.", [
        dict(id="nesta", done="nesta_truth_heard", req=["sent_home"],
             after="Nesta watches me like she knows something.",
             hints=["Find Nesta alone.", "Sit with Nesta and let her talk."],
             memory="She knew. The glamour never touched her.", canon="A"),
        dict(id="beddor", done="beddor_fire_learned", req=["nesta_truth_heard"],
             after="Something's wrong. I can feel it.",
             hints=["Listen to Father and Elain at lunch, the day after the party."],
             memory="Clare Beddor's family. Because of me.", canon="A"),
        dict(id="recross", done="wall_recrossed", req=["beddor_fire_learned"],
             after="I have to go back.",
             hints=["North, to the Wall.", "Ride for the Wall, alone."],
             memory="I crossed back alone.", canon="A"),
    ]),
    ("p8_the_pass", "Chapter Nine", "The Silent House", "No birdsong. No servants. Marks on the walls.", [
        dict(id="alis", done="alis_truth_heard", req=["wall_recrossed"],
             after="Somebody must still be here.",
             hints=["Search the house.", "Hide in the dining room and wait."],
             memory="Alis told me everything.", canon="A"),
        dict(id="depart", done="departed_for_mountain", req=["alis_truth_heard"],
             after="I know where he is now.",
             hints=["Toward the mountain."],
             memory="I'm going after him.", canon="V"),
    ]),
]


CHAPTER_SKETCH = {
    "p0_winter": "tree", "p1_wolf_and_crossing": "moon", "p2_grounds": "rose",
    "p3_house_and_woods": "door", "p4_wider_court": "wave", "p5_calanmai": "flame",
    "p6_blight_tightens": "mask", "p7_return_home": "house", "p8_the_pass": "mountain",
}
SKETCH = {
    "hunt": "bow", "shoot": "bow", "skin": "tree", "sell": "coin", "home": "house", "ride": "moon",
    "arrive": "door", "bathe": "wave", "dinner": "flame", "curtain_trap": "moon", "bogge": "tree",
    "puca": "moon", "map": "door", "wound": "flame", "mural": "brush", "suriel": "tree",
    "naga": "wave", "summer_faerie": "feather", "starlight": "star", "gallery": "brush",
    "first_painting": "brush", "attor": "rose", "fires": "flame", "cave": "flame", "bruise": "rose",
    "paintings": "brush", "glen": "tree", "fountain": "wave", "solstice": "star", "visitor": "mask",
    "farewell": "moon", "nesta": "house", "beddor": "flame", "recross": "moon", "alis": "door",
    "depart": "mountain",
}


def q(s: str) -> str:
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def psa(items) -> str:
    return "PackedStringArray(" + ", ".join(q(i) for i in items) + ")"


def main() -> None:
    out = ['[gd_resource type="Resource" script_class="JournalBook" format=3]', "",
           '[ext_resource type="Script" path="res://ui/journal/journal_book.gd" id="1_book"]',
           '[ext_resource type="Script" path="res://ui/journal/journal_chapter.gd" id="2_chap"]',
           '[ext_resource type="Script" path="res://ui/journal/journal_entry.gd" id="3_entry"]', ""]
    chapter_ids = []
    for ci, (phase, numeral, title, opener, steps) in enumerate(CHAPTERS):
        entry_ids = []
        for s in steps:
            sid = f"e_{s['id']}"
            entry_ids.append(sid)
            out += [f'[sub_resource type="Resource" id="{sid}"]', 'script = ExtResource("3_entry")',
                    f'id = &"{s["id"]}"']
            if s.get("done"):
                out.append(f'done_flag = {q(s["done"])}')
            if s.get("req"):
                out.append(f'require_flags = {psa(s["req"])}')
            if s.get("fail"):
                out.append(f'fail_flags = {psa(s["fail"])}')
            if s.get("after"):
                out.append(f'after = {q(s["after"])}')
            if s.get("hints"):
                out.append(f'hints = {psa(s["hints"])}')
            if s.get("memory"):
                out.append(f'memory = {q(s["memory"])}')
            if s.get("guide"):
                out.append(f'guide_thread = &"{s["guide"]}"')
            out.append(f'sketch = &"{SKETCH.get(s["id"], "rose")}"')
            out += [f'canon = {q(s.get("canon", "X"))}', ""]
        cid = f"c_{ci}"
        chapter_ids.append(cid)
        out += [f'[sub_resource type="Resource" id="{cid}"]', 'script = ExtResource("2_chap")',
                f'phase = &"{phase}"', f"numeral = {q(numeral)}", f"title = {q(title)}",
                f"opener = {q(opener)}", f'sketch = &"{CHAPTER_SKETCH[phase]}"',
                'entries = Array[ExtResource("3_entry")]([' + ", ".join(f'SubResource("{e}")' for e in entry_ids) + "])", ""]
    out += ["[resource]", 'script = ExtResource("1_book")',
            'chapters = Array[ExtResource("2_chap")]([' + ", ".join(f'SubResource("{c}")' for c in chapter_ids) + "])", ""]
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text("\n".join(out))
    n = sum(len(c[4]) for c in CHAPTERS)
    print(f"wrote {OUT.relative_to(ROOT)}: {len(CHAPTERS)} chapters, {n} steps")


if __name__ == "__main__":
    main()
