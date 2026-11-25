#!/usr/bin/env python3
"""Writes data/film/*.tres from the signed-off film scripts (lane L33).

Source: /mnt/project-files/plans/film/scripts.md v2.1 (Keeper and newcomer
critic signed off 2026-11-02). Times are seconds from the film's start; the
opening film is cut to the score music_opening_film (3:05, sound lane L15).
Rerun after a script change:  python3 tools/film/gen_film_data.py
"""
import os

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")

FILMS = {
    "opening_film": dict(
        id="opening", length=185.0, music="music_opening_film", seen="", bars=1.0,
        beats=[
            ("black_open", 0.0), ("land_fill", 10.0), ("court", 20.0), ("beasts", 33.0),
            ("eye_open", 39.0), ("slaves", 42.0), ("war", 54.0), ("war_crack", 63.0),
            ("treaty", 68.0), ("seal", 72.5), ("wall", 78.0), ("wash", 87.5), ("ripple", 93.0),
            ("to_world", 101.0), ("change_scene", 103.0), ("cottage_ext", 105.0),
            ("interior", 115.0), ("mother", 127.0), ("fall_house", 137.0), ("fall_ships", 142.5),
            ("fall_men", 148.0), ("cane", 154.8), ("foxglove", 156.8), ("larder", 159.0),
            ("dawn", 166.0), ("shoulder", 168.4), ("wolf_eye", 172.0), ("title", 176.0),
            ("handover", 183.0),
        ],
        lines=[
            ("op_01", 1.5, 6.8, "", "C", "Every human child learns the story the same way. In lullabies. In rhymes we chant before we can read."),
            ("op_02", 11.0, 7.5, "", "C", "Once, the whole of this land belonged to the faeries."),
            ("op_03", 21.0, 10.0, "", "C", "The greatest of them, the High Fae, were ageless, and so beautiful it hurt to look at them. Stronger than us, faster than us, with magic in their blood."),
            ("op_04", 34.5, 6.5, "", "C", "But not every faerie looked like a lord. Some wore the shapes of beasts."),
            # Owner-approved narration (2026-11-25, Keeper): spoken throughout, never sung.
            # Voice tags, every line: /mnt/project-files/film/narration/opening-narration-voice-tags.md (v3;
            # low and even, no pauses but the one before her name, so the holds are tight).
            ("op_05", 43.0, 8.6, "", "C", "For thousands of years, we were their slaves. We built their cities with our blood and sweat, and raised temples to their savage gods."),
            ("op_06", 54.5, 2.6, "", "C", "Until, at last, we rose against them."),
            ("op_07", 57.8, 5.4, "", "A/X", "Then one of them turned traitor, and told us their secret. Ash wood can kill them."),
            ("op_08", 64.0, 4.4, "", "A/X", "Still the killing went on, on both sides, until the ground was red."),
            ("op_09", 68.8, 5.0, "", "C", "Six human queens signed a Treaty with them, five hundred years ago. A promise."),
            ("op_10", 75.7, 9.8, "", "C", "The faeries kept the north, and took their magic with them. They called it Prythian. We were given the south, and a Wall between us that no one can see."),
            ("op_11", 86.5, 10.2, "", "A/X", "The war was so terrible that no one could bear to speak of it. So we turned it into songs, as warnings for our children. Songs are all we know of them now."),
            ("op_12", 97.4, 7.4, "", "C", "Five hundred years on, we still wear iron to keep them away. We tell our children that ash wood can kill them."),
            ("op_13", 107.0, 6.5, "", "C?", "My name is Feyre. I am nineteen, the youngest of three sisters."),
            ("op_14", 128.0, 8.5, "", "C", "My mother died when I was eight. On her deathbed, she made me promise to keep our family together, and to look after them."),
            # Keeper 2026-11-25 [A], ch 2 and ch 18, the owner's clearer telling: the fall's
            # beats (ships, men, cane) follow the words through the longer hold.
            ("op_15", 137.5, 21.5, "", "A", "We were rich once. My father was a merchant. Three years after she died, he sent everything we owned out on three trading ships, and all three sank. The men he owed money took our house and everything in it, and we fled to a cottage in a poor village. One of them found us there anyway. His men smashed my father's knee. He has walked with a cane ever since."),
            ("op_16", 160.0, 6.0, "", "C", "This winter is the worst yet. We are starving. My father can't hunt. My sisters won't."),
            ("op_17", 166.4, 2.2, "", "C", "So I hunt."),
            ("op_18", 168.4, 3.0, "", "C", "They say some of them are getting through the Wall now, into these woods. Out of Prythian."),
            # Carried over the cut to the dark wood: the eye opens under it.
            ("op_19", 171.3, 2.0, "", "C", "If I meet one, I'll kill it."),
        ],
    ),
    # Cutscene A (scripts.md section 2): the glamour lifts in the glen (ch 23).
    # The moment raises glamour_lifted on fact.film_eyes_open_lift, under the
    # black while her eyes are closed (R2: the film writes facts only).
    "eyes_open": dict(
        id="eyes_open", length=76.0, music="music_film_eyes_open", seen="fact.film_eyes_open_seen", bars=1.0,
        beats=[
            ("open", 0.0), ("study", 9.5), ("wary", 20.5), ("price", 23.8), ("fine", 29.4),
            ("kneel", 32.0), ("close_eyes", 34.0), ("kiss", 37.5),
            ("dark", 42.5), ("fact.film_eyes_open_lift", 44.0), ("open_eyes", 47.0), ("whisper", 50.6),
            ("true_form", 54.0), ("reach", 58.5), ("hide", 61.5), ("why", 62.3), ("normal", 64.8),
            ("hold", 68.0), ("handover", 73.0),
        ],
        lines=[
            ("a_01", 3.0, 2.4, "tamlin", "C", "It sings."),
            ("a_02", 5.6, 3.2, "feyre", "C", "And I suppose it knows drinking songs too."),
            ("a_03", 10.0, 4.2, "tamlin", "C?", "You're human. Your senses are sealed off from all of it."),
            ("a_04", 14.8, 5.0, "tamlin", "C?", "I could open them. Let you see my world. Hear it, smell it. Taste it."),
            ("a_05", 21.0, 2.6, "feyre", "C", "And what does it cost?"),
            ("a_06", 24.0, 2.8, "tamlin", "C", "Every gift comes with a price."),
            ("a_07", 27.3, 1.8, "tamlin", "C", "A kiss."),
            ("a_08", 29.6, 1.8, "feyre", "C", "...Fine."),
            ("a_09", 34.5, 2.4, "tamlin", "C", "Close your eyes."),
            ("a_10", 49.0, 4.0, "feyre", "C", "It smells of roses. Not metal any more."),
            ("a_11", 62.5, 2.2, "feyre", "C", "Why hide it?"),
            ("a_12", 65.0, 2.4, "tamlin", "C?", "To look normal."),
        ],
    ),
    # Cutscene B (scripts.md section 3): Rhysand at lunch (ch 26). The moment
    # raises rhysand_faced when the film ends.
    "night_court": dict(
        id="night_court", length=105.0, music="music_film_night_court", seen="fact.film_night_court_seen", bars=1.0,
        beats=[
            ("lunch", 0.0), ("snarl", 3.5), ("knife", 5.6), ("curtain", 8.0), ("veil_on", 9.0),
            ("slouch", 12.0), ("enter", 17.0), ("eyes_widen", 18.8), ("greet", 21.0), ("fox", 31.2),
            ("goblet", 35.5), ("look", 40.0), ("tear", 44.5), ("mind", 48.0), ("beg", 53.0),
            ("kneel", 57.5), ("fox_boy", 64.0), ("crouch", 67.5), ("flash", 73.6),
            ("fact.false_name_clare_beddor", 74.6), ("stand", 78.5), ("vanish", 86.0), ("after", 88.5),
            ("silence", 98.8), ("handover", 102.0),
        ],
        lines=[
            ("b_01", 4.4, 3.0, "tamlin", "C", "Get Feyre to the window. By the curtains."),
            ("b_02", 21.5, 2.0, "rhysand", "C", "High Lord."),
            ("b_03", 24.0, 1.8, "tamlin", "C", "Rhysand."),
            ("b_04", 26.2, 4.5, "rhysand", "C", "I don't see you for forty-nine years, and you start calling me Rhysand?"),
            ("b_05", 31.5, 3.4, "rhysand", "C", "A fox mask. Appropriate for you, Lucien."),
            ("b_06", 37.0, 2.5, "rhysand", "C", "Where's your guest?"),
            ("b_07", 41.5, 2.5, "rhysand", "C", "You dare glamour me?"),
            ("b_08", 48.5, 3.2, "rhysand", "X", "Let's see what's in that head of yours."),
            ("b_09", 53.3, 3.5, "tamlin", "C", "Please. Don't tell Amarantha about her."),
            ("b_10", 58.0, 3.4, "rhysand", "C", "Beg, and I'll consider not telling her."),
            ("b_11", 62.0, 1.6, "rhysand", "C", "Lower."),
            ("b_12", 64.0, 2.0, "rhysand", "C", "You too, fox-boy."),
            ("b_13", 68.5, 2.4, "rhysand", "C", "What's your name, love?"),
            ("b_14", 71.5, 2.0, "feyre", "C", "Clare Beddor."),
            ("b_15", 75.3, 2.6, "rhysand", "X", "Such a little liar."),
            ("b_16", 79.0, 6.0, "rhysand", "C", "I'm looking forward to seeing you three Under the Mountain. I'll give Amarantha your regards."),
            ("b_17", 89.5, 2.2, "feyre", "X", "Who was that?"),
            ("b_18", 92.3, 3.4, "lucien", "X", "Rhysand. High Lord of the Night Court."),
            ("b_19", 96.4, 2.2, "feyre", "X", "And Amarantha?"),
        ],
    ),
    # Cutscene C (scripts.md section 4): Alis's truth in the ruined manor
    # (end of ch 31 into ch 32). The moment raises alis_truth_heard at the end.
    "silent_manor": dict(
        id="silent_manor", length=150.0, music="music_film_silent_manor", seen="fact.film_silent_manor_seen", bars=1.0,
        beats=[
            ("hall", 0.0), ("sound", 6.0), ("hood", 11.0), ("kitchen", 17.5), ("packing", 29.0),
            ("mural_queen", 39.5), ("drain", 51.0), ("mural_masks", 56.0), ("curse", 62.0),
            ("mural_terms", 71.5), ("arrow", 79.0), ("understand", 91.0), ("stop", 104.0),
            ("stand", 115.0), ("look", 125.0), ("steps", 131.5), ("handover", 146.0),
        ],
        lines=[
            ("c_01", 13.0, 3.5, "alis", "C", "You can't be here. You were told to stay away."),
            ("c_02", 18.5, 3.0, "feyre", "C", "Where is he? What happened here?"),
            ("c_03", 22.0, 3.6, "alis", "C", "She took him. To her court, Under the Mountain."),
            ("c_04", 26.0, 2.2, "alis", "C", "Amarantha."),
            ("c_05", 29.0, 4.8, "alis", "C", "The seven times seven years are over. She is High Queen of Prythian now."),
            ("c_06", 34.3, 4.4, "alis", "C?", "That I can tell you any of this means the game is over, to her."),
            ("c_07", 40.5, 10.0, "alis", "C", "She came from across the sea, a commander in the old War. Forty-nine years ago, at a ball, she put a potion in the High Lords' wine and stole their powers. All seven of them."),
            ("c_08", 51.5, 4.0, "alis", "C", "For forty-nine years, we have been her slaves."),
            ("c_09", 56.5, 5.0, "alis", "C", "Tamlin would not be hers. He refused her and spat in her face."),
            ("c_10", 62.0, 4.2, "alis", "C", "So she cursed him, and all of us with him. The masks."),
            ("c_11", 66.5, 4.4, "alis", "C", "Then she bound us so we couldn't say a word about it. Not one word."),
            ("c_12", 72.0, 8.0, "alis", "C", "To break it, a human girl with ice in her heart, who hated our kind enough to kill one of his own, sent across the Wall."),
            ("c_13", 80.5, 4.0, "alis", "C", "And then she had to say she loved him, and mean it."),
            ("c_14", 85.0, 5.5, "alis", "C?", "If no girl did, he would be her slave forever, and Prythian would stay under her rule."),
            ("c_15", 91.5, 4.5, "alis", "C", "There was nothing in the Treaty about a life for a life. That was a lie."),
            ("c_16", 96.5, 7.0, "alis", "C", "The wolf you killed was one of us. Andras. Tamlin sent him across the Wall that day, knowing a girl like you might kill him."),
            ("c_17", 104.5, 4.0, "alis", "C", "You stupid, stupid girl. You never said it."),
            ("c_18", 109.0, 5.5, "alis", "C", "He had three days left when he sent you home. Three days, and he let you go."),
            ("c_19", 115.5, 2.0, "feyre", "C", "Where is he?"),
            ("c_20", 118.0, 3.8, "alis", "C", "Under the Mountain. With her. You'll die there."),
            ("c_21", 122.3, 2.2, "feyre", "C", "Then take me."),
            ("c_22", 128.0, 2.6, "alis", "C", "...Get your cloak."),
        ],
    ),
}


def esc(s):
    return s.replace("\\", "\\\\").replace('"', '\\"')


def write(name, f):
    lines = f["lines"]
    out = []
    n_sub = len(lines) + len(f["beats"])
    out.append('[gd_resource type="Resource" script_class="FilmScript" load_steps=%d format=3]' % (n_sub + 4))
    out.append("")
    out.append('[ext_resource type="Script" path="res://story/film/film_script.gd" id="1_script"]')
    out.append('[ext_resource type="Script" path="res://story/film/film_line.gd" id="2_line"]')
    out.append('[ext_resource type="Script" path="res://story/film/film_beat.gd" id="3_beat"]')
    out.append("")
    ids_l, ids_b = [], []
    for i, (lid, at, hold, spk, canon, text) in enumerate(lines):
        sid = "L%02d" % i
        ids_l.append(sid)
        out.append('[sub_resource type="Resource" id="%s"]' % sid)
        out.append('script = ExtResource("2_line")')
        out.append('id = &"%s"' % lid)
        out.append("at = %s" % repr(float(at)))
        out.append("hold = %s" % repr(float(hold)))
        out.append('speaker = &"%s"' % spk)
        out.append('text = "%s"' % esc(text))
        out.append('canon = "%s"' % canon)
        out.append("")
    for i, (bname, at) in enumerate(f["beats"]):
        sid = "B%02d" % i
        ids_b.append(sid)
        out.append('[sub_resource type="Resource" id="%s"]' % sid)
        out.append('script = ExtResource("3_beat")')
        out.append('name = &"%s"' % bname)
        out.append("at = %s" % repr(float(at)))
        out.append("")
    out.append("[resource]")
    out.append('script = ExtResource("1_script")')
    out.append('id = &"%s"' % f["id"])
    out.append("length = %s" % repr(float(f["length"])))
    out.append('music_cue = &"%s"' % f["music"])
    out.append('seen_flag = "%s"' % f["seen"])
    out.append("bars = %s" % repr(float(f["bars"])))
    out.append("lines = Array[ExtResource(\"2_line\")]([%s])" % ", ".join('SubResource("%s")' % s for s in ids_l))
    out.append("beats = Array[ExtResource(\"3_beat\")]([%s])" % ", ".join('SubResource("%s")' % s for s in ids_b))
    out.append("")
    path = os.path.join(ROOT, "data", "film", name + ".tres")
    with open(path, "w") as fh:
        fh.write("\n".join(out))
    print("wrote", os.path.relpath(path, ROOT), len(lines), "lines", len(f["beats"]), "beats")


if __name__ == "__main__":
    for k, v in FILMS.items():
        write(k, v)
