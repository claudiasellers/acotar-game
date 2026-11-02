"""Writes the P6 scenes' stages (marks and lines): data/story/act6/<scene>_stage.tres.

Run:  python3 tools/story/gen_act6_stages.py
Marks are in each scene's anchor frame (docs/contracts/story_anchors.md: -Z of
the anchor faces the scene). Lines are tagged: canon C (the book's words, from
the Keeper's answers 2026-11-02) or X (invented wording) in `invented`.
"""

import os

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "data/story/act6")

# feyre_bedroom_window: anchor at house (23, L1, -70.4); the room runs +z (AlisWelcome's marks).
BEDROOM = {
    "bed_side": (0.0, 0.0, 12.0),
    "alis_tray": (2.6, 0.0, 10.4),
    "bath": (8.6, 0.0, 13.0),
}

STAGES = {
    "glen_invite": {
        "canon": "Ch23 (Keeper 2026-11-02): another beautiful place on his land; they ride there. hall_mark_1 is at house (4, 0, -31); the front steps are at about (0, -17). glen_arrive is in glamour_lift_glade's frame, a few steps from the blanket.",
        "marks": {"tamlin_steps": (-4.0, 0.0, 14.0), "feyre_door": (-4.0, 0.0, 9.0), "glen_arrive": (2.2, 0.0, -2.6)},
        "lines": {
            "tamlin_come": ("Tamlin", "Come riding with me. There's somewhere I want you to see.", "X"),
            "press_go": ("", "The horses were saddled. He was waiting for me.", "X"),
            "ride_thought": ("", "We rode until the hills folded green around us.", "X"),
        },
    },
    "glen_picnic": {
        "canon": "Ch23 [C]: a grassy glen \"watched over by a weeping willow, with a clear brook\". Marks follow L33's eyes_open.gd (TAMLIN_SIT, WILLOW_AT).",
        "marks": {"tamlin_sit": (-0.85, 0.0, -0.1), "brook": (0.0, 0.0, 4.0)},
        "lines": {
            "glen_thought": ("", "A grassy glen, watched over by a weeping willow, with a clear brook.", "C"),
            "tamlin_sit_with_me": ("Tamlin", "Sit with me.", "X"),
        },
    },
    "eyes_open_wonders": {
        "canon": "Ch23 [C]: sound first, birdsong an orchestra; the willow sings, melancholy and weary; sight richer, clearer; the brook a near-invisible rainbow; magic smells like jasmine, like lilac, like roses. Bedroom offset bed_side is in feyre_bedroom_window's frame.",
        "marks": {"bed_side": BEDROOM["bed_side"]},
        "lines": {
            "everything_sang": ("", "The birdsong was an orchestra.", "C"),
            "willow_sings": ("", "The willow sang, melancholy and weary.", "C"),
            "brook_rainbow": ("", "A near-invisible rainbow ran over the brook.", "C"),
            "magic_scent": ("", "Magic smelled like jasmine, like lilac, like roses.", "C"),
            "tamlin_home": ("Tamlin", "Come. Alis will scold us both if we're late.", "X"),
        },
    },
    "alis_true_morning": {
        "canon": "Ch24 [C] (Keeper): the morning after the glen, in Feyre's bedroom, she wakes to the squat woman with skin made from tree bark fussing with her breakfast dishes, wearing the same bird mask: \"I am Alis.\" Alis goes into the bathing room to start her bath. Downstairs the halls bustle with masked faeries she'd never seen. Bark bleaches birch-white when frightened (alis.md).",
        "marks": BEDROOM,
        "lines": {
            "bark_thought": ("", "The squat woman with skin made from tree bark fussed with my breakfast dishes.", "C"),
            "birch_thought": ("", "Under my stare her bark paled, birch-white, before the brown crept back.", "X"),
            "alis_i_am": ("Alis", "I am Alis.", "C"),
            "halls_thought": ("", "The halls were bustling with masked faeries I'd never seen before.", "C"),
        },
    },
    "fountain_head": {
        "canon": "Ch24 [C] (Keeper): the next morning she hauls her paints out to paint the irises; the head is spiked on the heron's upraised bill; no mask, so not Spring; she backs into Tamlin, Lucien pale and grim beside him; Lucien wades in, finds the sigil behind the ear (a mountain with three stars); Tamlin: \"Night Court.\" Lucien climbs the heron's wing and yanks the head off while Tamlin holds her shoulders and she looks at a blossoming crab apple tree; \"court posturing\", \"You're still safe\"; Lucien leaves with it; Tamlin kneels and helps her pick up her paints. Marks in manor_fountain's frame: the fountain centre is (0, 0, -12.5).",
        "marks": {
            "fountain": (0.0, 0.0, -12.5),
            "tamlin_behind": (0.8, 0.0, -4.0),
            "lucien_behind": (-1.4, 0.0, -3.6),
            "lucien_rim": (-1.6, 0.0, -7.2),
            "lucien_wade": (-0.9, 0.0, -10.1),
            "lucien_exit": (-16.0, 0.0, 8.0),
            "crab_apple": (11.0, 2.6, -3.0),
        },
        "lines": {
            "irises_thought": ("", "I hauled my paints and easel out to paint one of the beds of irises.", "C"),
            "something_wrong": ("", "The birds had gone quiet.", "X"),
            "no_mask": ("", "No mask. So he wasn't a part of the Spring Court.", "C"),
            "lucien_not_autumn": ("Lucien", "Not Autumn Court... I don't recognize him at all.", "C"),
            "lucien_brand": ("Lucien", "They branded him behind the ear with a sigil... A mountain with three stars.", "C"),
            "tamlin_night_court": ("Tamlin", "Night Court.", "C"),
            "crab_apple_thought": ("", "His hands on my shoulders. I looked at a blossoming crab apple tree.", "C"),
            "tamlin_court_posturing": ("Tamlin", "Court posturing. Their lord's idea of a joke.", "C"),
            "tamlin_still_safe": ("Tamlin", "You're still safe.", "C"),
            "paints_thought": ("", "He knelt and helped me pick up my paints.", "C"),
        },
    },
    "solstice_dressing": {
        "canon": "Ch25 [C] (Keeper): that morning the garden is bedecked in ribbons and streamers; Alis: \"Summer Solstice. The main celebration used to be at the Summer Court... You're going.\" In late afternoon Alis yanked her upstairs: a cornflower-blue chiffon gown, hair unbound, a garland of pink, white and blue wildflowers around the crown. Downstairs Lucien: \"Cauldron boil me.\" Through the garden into the fields; the sun beginning its final descent when they reach the plateau. plateau_arrive is in solstice_dance_floor's frame.",
        "marks": dict(BEDROOM, alis_gown=(1.4, 0.0, 12.6), gown=(1.4, 0.0, 12.6), plateau_arrive=(6.0, 0.0, 8.0)),
        "lines": {
            "ribbons_thought": ("", "Beyond the window the garden was bedecked in ribbons and streamers.", "C"),
            "alis_solstice": ("Alis", "Summer Solstice. The main celebration used to be at the Summer Court... You're going.", "C"),
            "alis_upstairs": ("Alis", "Up. Now. You'll not go down looking like a stable hand.", "X"),
            "gown_prompt": ("", "Cornflower-blue chiffon, light as breath.", "C"),
            "garland_thought": ("", "My hair unbound, a garland of pink, white and blue wildflowers around the crown.", "C"),
            "alis_go_on": ("Alis", "Go on, then.", "X"),
            "lucien_cauldron": ("Lucien", "Cauldron boil me.", "C"),
            "plateau_thought": ("", "The sun was beginning its final descent when we reached the plateau.", "C"),
        },
    },
    "solstice_night": {
        "canon": "Ch25 [C] (Keeper): crowds of fae, unglamoured, seen for the first time; faerie wine (Lucien warns her, she drinks, he stays close); Tamlin plays the fiddle in the band; he takes her to the edge of a vast meadow; will-o'-the-wisps, spirits of air and light, dance around them; they dance; \"It's almost dawn\"; they watch the sunrise. Marks in solstice_dance_floor's frame (anchor at world -150, -1060): the dance ring is at (-150, -1080), the musicians' bower at (-100, -1135), the long tables at (-60, -1040), the wisp hollow round (-450, -950), r 85.",
        "marks": {
            "ring": (0.0, 0.0, -20.0), "bower": (48.0, 0.0, -72.0), "lucien_near": (3.0, 0.0, -2.0),
            "wine_table": (88.0, 0.0, 18.0), "tamlin_leave": (-40.0, 0.0, 8.0),
            "hollow_path": (-120.0, 0.0, 40.0), "hollow_edge": (-200.0, 0.0, 70.0), "hollow": (-235.0, 0.0, 85.0),
        },
        "lines": {
            "crowds_thought": ("", "Faeries everywhere, and for the first time I saw them as they were.", "C"),
            "lucien_wine_warning": ("Lucien", "Don't drink the wine. Not unless you want to dance until you drop.", "X"),
            "wine_prompt": ("", "Long tables of faerie wine and candied flowers. Tamlin was playing the fiddle with the band.", "C"),
            "wine_thought": ("", "It tasted of sunlight. The stars began to swim.", "X"),
            "lucien_nursemaid": ("Lucien", "Wonderful. And now I'm your nursemaid.", "X"),
            "tamlin_come_away": ("Tamlin", "Come with me.", "X"),
            "follow_thought": ("", "He led me from the fires to the edge of a vast meadow.", "C"),
            "wisps_thought": ("", "Will-o'-the-wisps, spirits of air and light, danced around us.", "C"),
            "kiss_thought": ("", "We danced, and he kissed me.", "C"),
            "tamlin_almost_dawn": ("Tamlin", "It's almost dawn.", "C"),
            "sunrise_thought": ("", "We watched the sun rise over the meadow.", "C"),
        },
    },
    "lunch_table": {
        "canon": "Ch26 [C]: a letter from Winter, the blight killed twenty-four younglings; she is already at the table at lunch with Tamlin and Lucien when Rhysand arrives (L33's film B plays the rest). manor_dining_table is at house (21, 0, -31.5) facing the table; L33's table centre is (21, -38).",
        "marks": {"table": (0.0, 0.0, -6.5), "tamlin_chair": (0.0, 0.0, -11.0), "lucien_chair": (-1.4, 0.0, -6.8), "feyre_chair": (1.4, 0.0, -6.2)},
        "lines": {
            "tamlin_letter": ("Tamlin", "A letter from Winter. The blight took twenty-four of their younglings.", "X"),
            "lucien_blight": ("Lucien", "Twenty-four. And it's spreading.", "X"),
            "chair_prompt": ("", "My place was laid beside Lucien's.", "X"),
        },
    },
    "farewell_night": {
        "canon": "Ch27-28 [C] (Keeper): no letter; that night Tamlin comes to HER bedroom by moonlight: \"So you need to go home, far from here.\" When? \"At dawn.\" They spend the night in her bed; he stays (handled with restraint: a fade). Ch28: Alis dresses her in mortal finery (pale pink silk with white and blue lace, a white linen jacket, a little ivory hat, lace gloves, white pumps); goodbye to Alis: \"Make the most of your freedom.\"",
        "marks": dict(BEDROOM, door=(-1.5, 0.0, 15.5), near_bed=(0.8, 0.0, 12.6), desk=(5.6, 0.0, 9.2)),
        "lines": {
            "moonlight_thought": ("", "He came to my room by moonlight.", "C"),
            "tamlin_go_home": ("Tamlin", "So you need to go home, far from here.", "C"),
            "feyre_when": ("Feyre", "When?", "C"),
            "tamlin_at_dawn": ("Tamlin", "At dawn.", "C"),
            "hand_prompt": ("", "I didn't want words. I reached for his hand.", "X"),
            "dawn_thought": ("", "He stayed.", "C"),
            "alis_finery": ("Alis", "Mortal finery. Pink silk, lace, and a hat to keep the sun off.", "X"),
            "dress_prompt": ("", "Pale pink silk with white and blue lace, a white linen jacket, a little ivory hat.", "C"),
            "alis_freedom": ("Alis", "Make the most of your freedom.", "C"),
            "paintings_prompt": ("", "My paintings, bundled on the writing table.", "X"),
        },
    },
    "carriage_farewell": {
        "canon": "Ch28 [C] (Keeper): downstairs Lucien: \"I thought you were smarter than this\" and storms off; Tamlin waits in front of a gilded carriage with six horses at the front of the house; \"My paintings, they're yours.\" \"Remember what I told you.\" Carriage, magic sleep. hall_mark_1 is at house (4, 0, -31); the front steps are at about (0, -17).",
        "marks": {
            "lucien_hall": (0.0, 0.0, 1.5), "feyre_door": (-4.0, 0.0, 10.0), "lucien_storms": (10.0, 0.0, -8.0),
            "carriage": (-1.0, 0.0, 24.0), "carriage_door": (-1.0, 0.0, 22.4), "tamlin_carriage": (-3.0, 0.0, 20.5),
        },
        "lines": {
            "lucien_smarter": ("Lucien", "I thought you were smarter than this.", "C"),
            "give_prompt": ("", "Six horses, a gilded carriage, and Tamlin waiting before it.", "C"),
            "feyre_paintings": ("Feyre", "My paintings. They're yours.", "C"),
            "tamlin_remember": ("Tamlin", "Remember what I told you.", "C"),
            "board_prompt": ("", "The carriage door stood open.", "X"),
            "sleep_thought": ("", "Sleep came over me like a hand.", "X"),
        },
    },
}


def vec(v):
    return "Vector3(%g, %g, %g)" % v


def esc(t):
    return t.replace("\\", "\\\\").replace('"', '\\"')


def write(name, spec):
    marks = ",\n".join('"%s": %s' % (k, vec(v)) for k, v in sorted(spec["marks"].items()))
    lines = ",\n".join('"%s": {"text": "%s", "who": "%s"}' % (k, esc(t), who)
                       for k, (who, t, _c) in sorted(spec["lines"].items()))
    invented = ", ".join('"%s"' % k for k, (_w, _t, c) in sorted(spec["lines"].items()) if c == "X")
    body = (
        '[gd_resource type="Resource" script_class="Act2Stage" format=3]\n\n'
        '[ext_resource type="Script" path="res://story/act2/act2_stage.gd" id="1"]\n\n'
        "[resource]\n"
        'script = ExtResource("1")\n'
        "marks = {\n%s\n}\n" % marks
        + "lines = {\n%s\n}\n" % lines
        + "extra_require = PackedStringArray()\n"
        + "invented = PackedStringArray(%s)\n" % invented
        + 'canon = "%s"\n' % esc(spec["canon"])
    )
    with open(os.path.join(OUT, name + "_stage.tres"), "w") as f:
        f.write(body)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for n, s in STAGES.items():
        write(n, s)
    print("wrote %d stages to %s" % (len(STAGES), OUT))
