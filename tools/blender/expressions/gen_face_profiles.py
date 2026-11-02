"""Write data/faces/<id>_face.tres from face_profiles.PROFILES (lane L36).

    python3 tools/blender/expressions/gen_face_profiles.py

Plain Python (no bpy).  Deterministic: keys are written sorted.
"""

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))

import face_profiles  # noqa: E402

OUT = os.path.join(REPO, "data", "faces")
SCRIPT = "res://systems/faces/face_profile.gd"


def s(v):
    return '"%s"' % str(v).replace("\\", "\\\\").replace('"', '\\"')


def num(v):
    t = ("%.3f" % float(v)).rstrip("0").rstrip(".")
    return t + ".0" if "." not in t else t


def mix(d):
    return "{ " + ", ".join("%s: %s" % (s(k), num(float(v))) for k, v in sorted(d.items())) + " }"


def write(cid, p):
    lines = ['[gd_resource type="Resource" script_class="FaceProfile" load_steps=2 format=3]', "",
             '[ext_resource type="Script" path="%s" id="1_face"]' % SCRIPT, "", "[resource]",
             'script = ExtResource("1_face")',
             'character_id = &"%s"' % cid,
             "canon = %s" % s(p["canon"]),
             "masked = %s" % ("true" if p["masked"] else "false"),
             'rest = &"%s"' % p["rest"],
             "blink_min = %s" % num(p["blink"][0]),
             "blink_max = %s" % num(p["blink"][1])]
    lines.append("presets = {\n" + ",\n".join("%s: %s" % (s(n), mix(m)) for n, m in sorted(p["presets"].items()))
                 + "\n}")
    lines.append("aliases = {\n" + ",\n".join("%s: %s" % (s(e), s(p["aliases"][e]))
                                                for e in face_profiles.EMOTIONS) + "\n}")
    tics = ["{ %s: %s, %s: %s, %s: %s, %s: %s, %s: %s }" % (s("hold"), num(t[3]), s("max"), num(t[2]), s("min"),
                                                            num(t[1]), s("preset"), s(t[0]), s("weight"), num(t[4]))
            for t in p["tics"]]
    lines.append("tics = [" + ", ".join(tics) + "]")
    if "states" in p:
        lines.append("creature = true")
        lines.append("states = {\n" + ",\n".join("%s: %s" % (s(k), s(v)) for k, v in sorted(p["states"].items()))
                     + "\n}")
        lines.append("cues = {\n" + ",\n".join("%s: { %s: %s, %s: %s }" % (s(k), s("preset"), s(v[0]), s("seconds"),
                                                                       num(v[1]))
                                              for k, v in sorted(p["cues"].items())) + "\n}")
    path = os.path.join(OUT, cid + "_face.tres")
    with open(path, "w") as fh:
        fh.write("\n".join(lines) + "\n")
    return path


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    profiles = dict(face_profiles.PROFILES)
    for cid, p in face_profiles.CREATURES.items():
        profiles[cid] = dict(p, masked=False, blink=(0.0, 0.0))
    for cid, p in sorted(profiles.items()):
        print("wrote", os.path.relpath(write(cid, p), REPO))
