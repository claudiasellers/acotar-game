"""Each character's canon expression range, as shape-key mixes (lane L36).

The one source for data/faces/<id>_face.tres (tools/blender/expressions/gen_face_profiles.py)
and for the close-up sheets (render_faces.py).  Keys are the 17 base keys plus
face_keys.EXPRESSION_KEYS.  Canon cues are from the Keeper's answers
(2026-11-02, book 1); [C] = stated in the book, [X] = our reading where the
book is silent.

A profile has:
  rest     - the face a character wears when nothing is asked of it
  presets  - its own named expressions: {key: weight}
  aliases  - the shared emotion vocabulary (EMOTIONS) -> one of its presets, so
             dialogue and story cues can say "angry" and Tamlin goes jaw-tight
             while the father winces.  Every emotion must resolve.
  tics     - small recurring moves layered over rest: (preset, min s, max s, hold s, weight)
  blink    - seconds between blinks (min, max)
  masked   - True when a fused mask hides brows, nose and cheeks [C] (Spring Court),
             so their acting is weighted onto jaw, mouth, lips and eyes
"""

# The shared vocabulary dialogue lines and story cues may use.
EMOTIONS = ("neutral", "happy", "laugh", "smirk", "tender", "angry", "fury", "contempt", "disgust", "sad",
            "grief", "afraid", "terror", "surprise", "pained", "weary", "guarded", "pleading")


def lr(base, **w):
    """Expand {key_S: v} for a side S ('L' or 'R') into concrete keys."""
    out = {}
    for k, v in w.items():
        out[k.replace("_S", "_" + base)] = v
    return out


PROFILES = {
    # ------------------------------------------------------------------
    "tamlin": dict(
        canon="Mask over brows, nose, cheeks [C ch6]. Jaw tightens, quivers [C ch7, ch11]; growls and snarls "
              "[C ch6-7]; fangs when furious [C ch11]; claws out [C ch7, ch10]; still and weary after the Bogge "
              "[C ch12]; does not smile early [C ch7]; colour in his cheeks then a broad, unguarded grin "
              "[C ch16]; later a lazy grin [C ch22]. Never smirks or sneers (Lucien's register).",
        masked=True,
        rest="guarded",
        blink=(3.0, 6.5),
        presets={
            "guarded": {"lip_press": 0.25, "jaw_clench": 0.2, "frown": 0.1},
            "restraint": {"jaw_clench": 0.95, "lip_press": 0.6, "squint": 0.25, "frown": 0.2},
            "growl": {"sneer_L": 0.55, "sneer_R": 0.65, "lips_part": 0.45, "squint": 0.4, "frown": 0.3},
            "fury": {"sneer_L": 1.0, "sneer_R": 1.0, "jaw_open": 0.35, "lips_part": 0.5, "mouth_stretch": 0.2,
                     "squint": 0.55, "frown": 0.3},
            "weary": {"blink_L": 0.42, "blink_R": 0.42, "frown": 0.25, "jaw_open": 0.04},
            "shy_warmth": {"smile": 0.32, "smile_L": 0.12, "blink_L": 0.18, "blink_R": 0.18},
            "grin": {"smile": 1.0, "lips_part": 0.35, "jaw_open": 0.12, "squint": 0.3},
            "lazy_grin": {"smile": 0.55, "smile_R": 0.2, "blink_L": 0.25, "blink_R": 0.25, "lips_part": 0.15},
        },
        aliases={"neutral": "guarded", "guarded": "guarded", "happy": "shy_warmth", "laugh": "grin",
                 "smirk": "lazy_grin", "tender": "shy_warmth", "angry": "restraint", "fury": "fury",
                 "contempt": "growl", "disgust": "growl", "sad": "weary", "grief": "weary", "afraid": "restraint",
                 "terror": "restraint", "surprise": "guarded", "pained": "restraint", "weary": "weary",
                 "pleading": "weary"},
        tics=[("restraint", 7.0, 15.0, 0.9, 0.45)],
    ),
    # ------------------------------------------------------------------
    "lucien": dict(
        canon="Fox mask over the upper face [C]. Smirks often, the scar pulling [C ch8-9; side X: the scarred, "
              "metal-eye side, his left]; lazy, vicious grin, too-white teeth [C ch8-9]; scowl with the scar "
              "stretching [C ch9]; snorts, harsh barking laugh [C ch7, ch9]; very pale, gaze fixed in fear "
              "[C ch9]; a rare crooked, genuine smile [C ch12].",
        masked=True,
        rest="idle_smirk",
        blink=(2.5, 5.5),
        presets={
            "idle_smirk": lr("L", smile_S=0.28, mouth_side_S=0.15),
            "smirk": dict(lr("L", smile_S=0.95, mouth_side_S=0.5, squint_S=0.35, sneer_S=0.15)),
            "vicious_grin": dict(lr("L", smile_S=0.35), smile=0.8, jaw_open=0.1, lips_part=0.55, squint=0.3),
            "scowl": dict(lr("L", sneer_S=0.45), frown=0.7, lip_press=0.3, squint=0.4),
            "bark_laugh": dict(lr("L", smile_S=0.2), smile=0.65, jaw_open=0.42, squint=0.5),
            "pale_fear": {"eyes_wide_L": 0.85, "eyes_wide_R": 0.85, "lips_part": 0.3, "mouth_stretch": 0.3},
            "crooked_smile": dict(lr("L", smile_S=0.25), smile=0.5, squint=0.2),
            "grim": {"lip_press": 0.5, "frown": 0.45, "blink_L": 0.12, "blink_R": 0.12},
        },
        aliases={"neutral": "idle_smirk", "guarded": "smirk", "happy": "crooked_smile", "laugh": "bark_laugh",
                 "smirk": "smirk", "tender": "crooked_smile", "angry": "scowl", "fury": "scowl",
                 "contempt": "smirk", "disgust": "scowl", "sad": "grim", "grief": "grim", "afraid": "pale_fear",
                 "terror": "pale_fear", "surprise": "pale_fear", "pained": "grim", "weary": "grim",
                 "pleading": "grim"},
        tics=[("smirk", 6.0, 12.0, 0.7, 0.55)],
    ),
    # ------------------------------------------------------------------
    "alis": dict(
        canon="Masked like all the Spring folk [C]. Clicks her tongue again and again [C ch7, 28, 32]; sneer "
              "[C ch7]; barks a laugh [C ch7]; lips a tight line [C ch22]; eyes wide with remembered horror "
              "[C ch32]; eyes soften [C ch32]. Dry and brusque, never giggly or effusive.",
        masked=True,
        rest="brisk",
        blink=(2.8, 6.0),
        presets={
            "brisk": dict(lr("R", mouth_side_S=0.15), lip_press=0.25),
            "tongue_click": dict(lr("R", mouth_side_S=0.5, sneer_S=0.15), lip_press=0.7, squint=0.15),
            "sneer": dict(lr("R", sneer_S=0.85, smile_S=0.2), lips_part=0.2, squint=0.3),
            "bark_laugh": {"smile": 0.6, "jaw_open": 0.45, "squint": 0.5},
            "tight_lips": {"lip_press": 1.0, "frown": 0.3},
            "horror_memory": {"eyes_wide_L": 0.9, "eyes_wide_R": 0.9, "lips_part": 0.4, "mouth_stretch": 0.3},
            "softened": {"smile": 0.22, "blink_L": 0.24, "blink_R": 0.24},
        },
        aliases={"neutral": "brisk", "guarded": "tight_lips", "happy": "softened", "laugh": "bark_laugh",
                 "smirk": "sneer", "tender": "softened", "angry": "tight_lips", "fury": "sneer",
                 "contempt": "sneer", "disgust": "sneer", "sad": "softened", "grief": "horror_memory",
                 "afraid": "horror_memory", "terror": "horror_memory", "surprise": "horror_memory",
                 "pained": "tight_lips", "weary": "tight_lips", "pleading": "softened"},
        tics=[("tongue_click", 8.0, 16.0, 0.35, 0.8)],
    ),
    # ------------------------------------------------------------------
    "father": dict(
        canon="Unmasked, human. Dozing, slack by the fire [C ch3]; terror-stricken [C ch4]; grimace, grunting at "
              "the pain of standing [C ch4]; stammered pleas [C]; a passive, defeated look that avoids eyes "
              "[X from 'he just stopped trying']; trembling at the goodbye [C ch5]. Never stern or commanding.",
        masked=False,
        rest="defeated",
        blink=(2.2, 4.8),
        presets={
            "defeated": {"brow_inner_up": 0.35, "frown": 0.3, "blink_L": 0.22, "blink_R": 0.22},
            "dozing": {"blink_L": 0.88, "blink_R": 0.88, "jaw_open": 0.16, "brow_inner_up": 0.1},
            "terror": {"eyes_wide_L": 1.0, "eyes_wide_R": 1.0, "brow_inner_up": 0.8, "brow_up": 0.6,
                       "mouth_stretch": 0.6, "jaw_open": 0.3, "lips_part": 0.3},
            "wince": {"squint": 0.8, "brow_down": 0.45, "brow_inner_up": 0.3, "mouth_stretch": 0.4,
                      "jaw_clench": 0.5},
            "pleading": {"brow_inner_up": 1.0, "eyes_wide_L": 0.3, "eyes_wide_R": 0.3, "lips_part": 0.35,
                         "frown": 0.35, "chin_raise": 0.2},
            "goodbye_tears": {"chin_raise": 0.75, "brow_inner_up": 0.85, "frown": 0.6, "squint": 0.3},
            "faint_smile": {"smile": 0.25, "brow_inner_up": 0.3, "blink_L": 0.15, "blink_R": 0.15},
            # what the puca shows her: her father whole, sharp and steady, the defeat gone [X]
            "clear_eyed": {"eyes_wide_L": 0.15, "eyes_wide_R": 0.15, "brow_up": 0.12, "smile": 0.3, "chin_raise": 0.1},
        },
        aliases={"neutral": "defeated", "guarded": "defeated", "happy": "faint_smile", "laugh": "faint_smile",
                 "smirk": "faint_smile", "tender": "faint_smile", "angry": "wince", "fury": "wince",
                 "contempt": "defeated", "disgust": "wince", "sad": "defeated", "grief": "goodbye_tears",
                 "afraid": "terror", "terror": "terror", "surprise": "terror", "pained": "wince",
                 "weary": "dozing", "pleading": "pleading"},
        tics=[("wince", 10.0, 22.0, 0.6, 0.35)],
    ),
    # ------------------------------------------------------------------
    "nesta": dict(
        canon="Unmasked, human. Cold, mother-like [C]; the sneer and narrowed eyes [C]; stormy eyes over thin, "
              "pressed lips [C]; imperious, looking down at people [C later]; rarely smiles [C]. Our reading [X]: "
              "fear and grief held behind the same tight mouth, chin up, never let fall.",
        masked=False,
        rest="cold",
        blink=(3.0, 6.5),
        presets={
            "cold": {"lip_press": 0.3, "squint": 0.18, "chin_raise": 0.15, "brow_down": 0.1},
            "sneer": {"sneer_L": 0.45, "sneer_R": 0.75, "squint": 0.4, "brow_down": 0.35, "mouth_side_R": 0.25},
            "narrowed": {"squint": 0.75, "brow_down": 0.55, "lip_press": 0.4},
            "storm": {"brow_down": 0.85, "lip_press": 0.85, "squint": 0.5, "frown": 0.3, "jaw_clench": 0.45},
            "imperious": {"chin_raise": 0.5, "brow_up": 0.25, "blink_L": 0.22, "blink_R": 0.22, "lip_press": 0.3},
            "rare_smile": {"smile": 0.3, "smile_R": 0.1, "squint": 0.15},
            "shaken": {"eyes_wide_L": 0.4, "eyes_wide_R": 0.4, "brow_inner_up": 0.3, "lip_press": 0.55},
            "grief_held": {"chin_raise": 0.6, "lip_press": 0.7, "brow_inner_up": 0.45, "squint": 0.25},
        },
        aliases={"neutral": "cold", "guarded": "cold", "happy": "rare_smile", "laugh": "rare_smile",
                 "smirk": "sneer", "tender": "rare_smile", "angry": "storm", "fury": "storm", "contempt": "sneer",
                 "disgust": "sneer", "sad": "grief_held", "grief": "grief_held", "afraid": "shaken",
                 "terror": "shaken", "surprise": "shaken", "pained": "grief_held", "weary": "imperious",
                 "pleading": "grief_held"},
        tics=[("narrowed", 8.0, 16.0, 0.6, 0.4)],
    ),
    # ------------------------------------------------------------------
    "elain": dict(
        canon="Unmasked, human, 'lovely' [C]. The gasp, the wince, pale and cowering, weeping [C]; later bright "
              "laughter [C]. Never sneers [C]. Our reading [X]: a soft, sweet rest face, worry before anger.",
        masked=False,
        rest="sweet",
        blink=(2.2, 5.0),
        presets={
            "sweet": {"smile": 0.22, "brow_inner_up": 0.12, "cheek_raise": 0.1},
            "smile": {"smile": 0.6, "cheek_raise": 0.35, "squint": 0.15},
            "laugh": {"smile": 1.0, "cheek_raise": 0.6, "squint": 0.35, "jaw_open": 0.2, "lips_part": 0.4,
                      "brow_up": 0.2},
            "gasp": {"eyes_wide_L": 0.45, "eyes_wide_R": 0.45, "brow_up": 0.6, "brow_inner_up": 0.3, "jaw_open": 0.3,
                     "lips_part": 0.5},
            "wince": {"squint": 0.7, "brow_inner_up": 0.6, "frown": 0.35, "lip_press": 0.3},
            "cower": {"brow_inner_up": 0.9, "eyes_wide_L": 0.3, "eyes_wide_R": 0.3, "frown": 0.4, "chin_raise": 0.3,
                      "lips_part": 0.2},
            "weeping": {"brow_inner_up": 1.0, "frown": 0.65, "squint": 0.45, "chin_raise": 0.5, "lips_part": 0.25},
            "worried": {"brow_inner_up": 0.6, "frown": 0.2, "lip_press": 0.2},
        },
        aliases={"neutral": "sweet", "guarded": "worried", "happy": "smile", "laugh": "laugh", "smirk": "smile",
                 "tender": "smile", "angry": "worried", "fury": "wince", "contempt": "worried", "disgust": "wince",
                 "sad": "worried", "grief": "weeping", "afraid": "cower", "terror": "cower", "surprise": "gasp",
                 "pained": "wince", "weary": "worried", "pleading": "cower"},
        tics=[("smile", 7.0, 14.0, 0.8, 0.4)],
    ),
}


# ----------------------------------------------------------------------
# Creatures (lane L36-3).  No visemes, no blinks: a threat display, driven by
# what the creature is doing (`states`: its brain's State enum, lower-cased, or
# its face_state()), by story cues (`cues`: cue -> (preset, seconds), -1 = hold)
# and by Faces.express like the cast.  Keys:
#   fae (shape keys, tools/blender/fae_creatures.py): threat, eyes_wide, tongue, ears_back
#   wolves (bones, SnarlModifier): jaw_open, ears_back, ears_up, head_low
# The monsters stay frightening (R3): every threat is wide and toothy, never cute.
# The Bogge has no face at all (shadow, no eye bloom) and the beast has its own
# snarl clips, so neither is here.
WOLF_ALIASES = {"neutral": "rest", "guarded": "rest", "happy": "rest", "laugh": "rest", "smirk": "rest",
                "tender": "rest", "angry": "snarl", "fury": "lunge", "contempt": "snarl", "disgust": "snarl",
                "sad": "rest", "grief": "rest", "afraid": "cowed", "terror": "cowed", "surprise": "alert",
                "pained": "cowed", "weary": "rest", "pleading": "cowed"}

CREATURES = {
    "great_wolf": dict(
        canon="Andras in wolf form, pony-sized and unnaturally quiet [C ch1]: no sound and no bared teeth while "
              "he creeps on the doe; jaws open only for the burst and the seize; after the ash he turns and "
              "looks at her with something too aware in his face, ears up, jaw shut [C ch1]; dies slowly, eye "
              "on the sky, jaw slack [C ch1].",
        rest="rest",
        presets={
            "rest": {"ears_up": 0.3},
            "stalk": {"ears_up": 0.8, "head_low": 0.35},
            "rush": {"jaw_open": 0.95, "ears_back": 0.9, "head_low": 0.3},
            "hold_prey": {"jaw_open": 0.35, "ears_back": 0.5, "head_low": 0.2},
            "stare": {"ears_up": 1.0},
            "retreat": {"ears_back": 0.7, "jaw_open": 0.2, "head_low": 0.45},
            "snarl": {"jaw_open": 0.35, "ears_back": 0.85, "head_low": 0.6},
            "lunge": {"jaw_open": 1.0, "ears_back": 1.0, "head_low": 0.3},
            "alert": {"ears_up": 1.0},
            "cowed": {"ears_back": 1.0, "head_low": 0.8},
            "dying": {"jaw_open": 0.3, "ears_back": 0.35},
            "dead": {"jaw_open": 0.4, "ears_back": 0.5},
        },
        aliases=WOLF_ALIASES,
        tics=[("alert", 5.0, 11.0, 0.3, 0.6)],
        states={"stalk": "stalk", "rush": "rush", "hold_prey": "hold_prey", "stare": "stare", "retreat": "retreat",
                "dying": "dying", "dead": "dead"},
        cues={},
    ),
    "wolf": dict(
        canon="The human-realm forest wolves [C ch1-2]: a pack that stalks, flanks and circles, darting in. "
              "Our reading [X]: ears pinned and heads low with lips off the teeth while they ring her, the "
              "jaws gaping for each feint, silent and ears-forward while roaming.",
        rest="rest",
        presets={
            "rest": {"ears_up": 0.4},
            "stalk": {"ears_up": 0.7, "head_low": 0.5},
            "snarl": {"jaw_open": 0.4, "ears_back": 0.9, "head_low": 0.65},
            "lunge": {"jaw_open": 1.0, "ears_back": 1.0, "head_low": 0.3},
            "alert": {"ears_up": 1.0},
            "cowed": {"ears_back": 1.0, "head_low": 0.8},
            "dying": {"jaw_open": 0.3, "ears_back": 0.35},
            "dead": {"jaw_open": 0.4, "ears_back": 0.5},
        },
        aliases=WOLF_ALIASES,
        tics=[("alert", 4.0, 9.0, 0.3, 0.6)],
        states={"stalk": "stalk", "flank": "snarl", "circle": "snarl", "break": "snarl", "lunge": "lunge",
                "dying": "dying", "dead": "dead"},
        cues={},
    ),
    "suriel": dict(
        canon="Thin as death, skin like old cloth, lipless mouth over too-many grey teeth [C ch14]. It smiles "
              "that lipless smile while it answers her, amused, and the teeth are horribly large [C ch14]; its "
              "milky eyes widen and it shrieks when it scents the naga [C ch14]. Never sad, never pleading.",
        rest="calm",
        presets={
            "calm": {},
            "smile": {"threat": 0.55},
            "grin": {"threat": 1.0},
            "watch": {"eyes_wide": 0.45},
            "shriek": {"threat": 1.0, "eyes_wide": 1.0},
            "speak": {"threat": 0.45},
        },
        aliases={"neutral": "calm", "guarded": "calm", "happy": "smile", "laugh": "grin", "smirk": "smile",
                 "tender": "smile", "angry": "grin", "fury": "shriek", "contempt": "smile", "disgust": "smile",
                 "sad": "calm", "grief": "calm", "afraid": "shriek", "terror": "shriek", "surprise": "watch",
                 "pained": "watch", "weary": "calm", "pleading": "calm"},
        tics=[("smile", 6.0, 12.0, 0.8, 0.5)],
        states={"snared": "watch", "caught": "smile", "screaming": "shriek", "stalking": "calm", "freed": "grin"},
        cues={"naga_are_coming": ("shriek", 2.0), "freed": ("grin", 1.5)},
    ),
    "naga": dict(
        canon="Serpent-faced fae with scales [C ch14-15]: 'the creature smiled, a row of razor-sharp teeth', "
              "the jaw dropping away from them, a silvery forked tongue [C ch15]. Our reading [X]: the tongue "
              "tastes the air while it lurks, the eyes flare as it strikes.",
        rest="lurk",
        presets={
            "lurk": {},
            "taste": {"tongue": 1.0},
            "smile": {"threat": 0.7, "eyes_wide": 0.3},
            "strike": {"threat": 1.0, "eyes_wide": 1.0, "tongue": 0.3},
            "hiss": {"threat": 0.5, "tongue": 0.8},
            "reel": {"eyes_wide": 1.0, "threat": 0.25},
            "flee": {"eyes_wide": 0.6},
        },
        aliases={"neutral": "lurk", "guarded": "lurk", "happy": "smile", "laugh": "smile", "smirk": "smile",
                 "tender": "smile", "angry": "hiss", "fury": "strike", "contempt": "smile", "disgust": "hiss",
                 "sad": "lurk", "grief": "lurk", "afraid": "flee", "terror": "flee", "surprise": "reel",
                 "pained": "reel", "weary": "lurk", "pleading": "lurk"},
        tics=[("taste", 2.5, 6.0, 0.3, 1.0)],
        states={"lurk": "lurk", "charge": "smile", "strike": "strike", "recover": "hiss", "stagger": "reel",
                "flee": "flee", "dying": "reel", "dead": "reel"},
        cues={"attack": ("smile", 1.0), "stagger": ("reel", 1.0)},
    ),
    "attor": dict(
        canon="Grey leathery skin, bat-like wings, long thin fingers, a snout full of fangs [C]; her painting "
              "shows it 'snout open in a roar, revealing row after row of fangs' [C]. It hisses when it speaks of "
              "her (ch19 cue speaks_of_her). Our reading [X]: ears pinned back as it hisses, the snout never "
              "fully shut.",
        rest="menace",
        presets={
            "menace": {"threat": 0.15, "ears_back": 0.25},
            "hiss": {"threat": 0.6, "ears_back": 1.0},
            "roar": {"threat": 1.0, "ears_back": 1.0},
            "listen": {"ears_back": 0.0},
        },
        aliases={"neutral": "menace", "guarded": "menace", "happy": "hiss", "laugh": "hiss", "smirk": "hiss",
                 "tender": "menace", "angry": "hiss", "fury": "roar", "contempt": "hiss", "disgust": "hiss",
                 "sad": "menace", "grief": "menace", "afraid": "listen", "terror": "listen", "surprise": "listen",
                 "pained": "roar", "weary": "menace", "pleading": "menace"},
        tics=[("hiss", 5.0, 10.0, 0.5, 0.4)],
        states={},
        cues={"speaks_of_her": ("hiss", 2.5)},
    ),
}

CREATURE_KEYS = {"great_wolf": ("jaw_open", "ears_back", "ears_up", "head_low"),
                 "wolf": ("jaw_open", "ears_back", "ears_up", "head_low"),
                 "suriel": ("threat", "eyes_wide"), "naga": ("threat", "tongue", "eyes_wide"),
                 "attor": ("threat", "ears_back")}


# Symmetric names in a preset are spread onto the stronger one-sided keys
# (face_keys builds those to read at game distance; the base keys are shy).
SYMMETRIC = ("smile", "frown", "squint", "brow_down", "brow_up", "eyes_wide", "sneer")


def expand(mix):
    out = {}
    for k, v in mix.items():
        if k in SYMMETRIC:
            for s in ("_L", "_R"):
                out[k + s] = round(out.get(k + s, 0.0) + v, 3)
        else:
            out[k] = round(out.get(k, 0.0) + v, 3)
    return out


for _p in PROFILES.values():
    _p["presets"] = {n: expand(m) for n, m in _p["presets"].items()}


# Skin under a Spring Court mask never moves (the mask is rigid and must not be pierced):
# FaceDriver also zeroes these for masked profiles.
MASK_HIDDEN = ("brow_down_L", "brow_down_R", "brow_up_L", "brow_up_R", "brow_inner_up", "brow_up", "brow_down",
               "cheek_raise", "cheek_puff")


def check():
    """Every alias resolves, every emotion is covered, masked faces act only below the mask."""
    for cid, p in PROFILES.items():
        if p["masked"]:
            for n, m in p["presets"].items():
                assert not set(m) & set(MASK_HIDDEN), (cid, n, set(m) & set(MASK_HIDDEN))
        assert p["rest"] in p["presets"], (cid, p["rest"])
        for e in EMOTIONS:
            assert p["aliases"].get(e) in p["presets"], (cid, e)
        for t in p["tics"]:
            assert t[0] in p["presets"], (cid, t)
    for cid, p in CREATURES.items():
        assert p["rest"] in p["presets"], (cid, p["rest"])
        for e in EMOTIONS:
            assert p["aliases"].get(e) in p["presets"], (cid, e)
        for n, m in p["presets"].items():
            assert set(m) <= set(CREATURE_KEYS[cid]), (cid, n, set(m) - set(CREATURE_KEYS[cid]))
        for t in p["tics"]:
            assert t[0] in p["presets"], (cid, t)
        for st, pr in p["states"].items():
            assert pr in p["presets"], (cid, st)
        for cue, (pr, _sec) in p["cues"].items():
            assert pr in p["presets"], (cid, cue)


check()
