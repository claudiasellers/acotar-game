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
            ("interior", 115.0), ("mother", 127.0), ("fall_house", 137.0), ("fall_ships", 139.6),
            ("fall_men", 146.0), ("cane", 149.6), ("foxglove", 152.0), ("larder", 159.0),
            ("dawn", 166.0), ("shoulder", 168.4), ("wolf_eye", 172.0), ("title", 176.0),
            ("handover", 183.0),
        ],
        lines=[
            ("op_01", 1.5, 7.8, "", "C", "Every human child learns the story the same way. In lullabies. In rhymes we chant before we can read."),
            ("op_02", 11.0, 7.5, "", "C", "Once, the whole of this land belonged to the faeries."),
            ("op_03", 21.0, 11.0, "", "C", "The greatest of them, the High Fae, were ageless, and so beautiful it hurt to look at them. Stronger than us, faster than us, with magic in their blood."),
            ("op_04", 34.5, 6.5, "", "C", "But not every faerie looked like a lord. Some wore the shapes of beasts."),
            ("op_05", 43.0, 10.0, "", "C", "Once, we were their slaves. For thousands of years we built their cities with our blood and sweat, and their temples to gods we never knew."),
            ("op_06", 55.5, 9.5, "", "C", "Once, we rose against them. The war was so terrible that we never told it plainly. We sang it to our children instead."),
            ("op_07", 69.0, 8.0, "", "C", "Six human queens signed a Treaty with them, five hundred years ago. A promise."),
            ("op_08", 79.0, 10.5, "", "C", "The faeries kept the north, and took their magic with them. They called it Prythian. We were given the south, and a Wall between us that no one can see."),
            ("op_09", 92.0, 9.0, "", "C", "Five hundred years on, we still wear iron to keep them away. We still tell our children that ash wood can kill them."),
            ("op_10", 107.0, 6.5, "", "C?", "My name is Feyre. I am nineteen, the youngest of three sisters."),
            ("op_11", 128.0, 8.5, "", "C", "My mother died when I was eight. Before she did, she made me promise to keep us together, and to look after them."),
            ("op_12", 137.5, 14.0, "", "C", "We were rich once. My father was a merchant. Three years after she died, he put every coin we had on three ships, and the sea took all three. The men he owed took everything else. Later, one of them found us here, and broke his leg."),
            ("op_13", 160.0, 6.0, "", "C", "This winter is the worst yet. We are starving. My father can't hunt. My sisters won't."),
            ("op_14", 166.4, 2.2, "", "C", "So I hunt."),
            ("op_15", 168.4, 3.0, "", "C", "They say some of them are getting through the Wall now, into these woods. Out of Prythian."),
            # Carried over the cut to the dark wood: the eye opens under it.
            ("op_16", 171.3, 2.0, "", "C", "If I meet one, I'll kill it."),
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
