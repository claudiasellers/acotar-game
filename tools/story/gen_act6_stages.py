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
