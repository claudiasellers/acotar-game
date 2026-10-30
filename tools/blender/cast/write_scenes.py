"""Writes characters/<id>/<id>_model.tscn for each built cast member.

    /opt/bpyenv/bin/python tools/blender/cast/write_scenes.py [id ...]

The scene instances <id>.glb turned 180 degrees (glTF faces +Z), gives the body
feyre_skin.gdshader with the character's skin, brow and lip colours and its own
makeup masks, and lists its default outfit, hair and held props for
characters/cast/cast_model.gd.  Each cast_<id>.py may set DEFAULT_OUTFIT (wardrobe
file stems), DEFAULT_HAIR (hair stem), HELD_PROPS ([(stem, bone[, (tx, ty, tz, qx, qy, qz, qw)])]), IDLE_CLIP,
WALK_CLIP, LIPS_SRGB; otherwise every wardrobe glb is worn and the first hair is used.
"""

import importlib
import os
import sys

import bpy  # noqa: F401  (the cast modules import mathutils)

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, HERE)
CAST = ("tamlin", "lucien", "nesta", "elain", "father")


def col(hexstr, a=1.0):
    h = hexstr.lstrip("#")
    r, g, b = (int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))
    return "Color(%.3f, %.3f, %.3f, %.1f)" % (r, g, b, a)


def write(cid):
    C = importlib.import_module("cast_" + cid)
    root = "res://characters/%s" % cid
    d = os.path.join(REPO, "characters", cid)
    if not os.path.exists(os.path.join(d, "model", cid + ".glb")):
        print("skip", cid, "(not built)")
        return
    ward = sorted(f[:-4] for f in os.listdir(os.path.join(d, "wardrobe")) if f.endswith(".glb"))
    hair = sorted(f[:-4] for f in os.listdir(os.path.join(d, "hair")) if f.endswith(".glb"))
    outfit = getattr(C, "DEFAULT_OUTFIT", ward)
    hair_id = getattr(C, "DEFAULT_HAIR", hair[0] if hair else "")
    props = getattr(C, "HELD_PROPS", [])
    pname = "".join(w.capitalize() for w in cid.split("_")) + "Model"
    lines = [
        '[gd_scene load_steps=8 format=3]',
        '',
        '[ext_resource type="Script" path="res://characters/cast/cast_model.gd" id="1_script"]',
        '[ext_resource type="PackedScene" path="%s/model/%s.glb" id="2_glb"]' % (root, cid),
        '[ext_resource type="Shader" path="res://characters/feyre/feyre_skin.gdshader" id="3_skin"]',
        '[ext_resource type="Texture2D" path="%s/model/makeup_mask_a.png" id="4_mask_a"]' % root,
        '[ext_resource type="Texture2D" path="%s/model/makeup_mask_b.png" id="5_mask_b"]' % root,
        '',
        '[sub_resource type="ShaderMaterial" id="ShaderMaterial_head"]',
        'resource_name = "skin_head"',
        'resource_local_to_scene = true',
        'shader = ExtResource("3_skin")',
        'shader_parameter/albedo = %s' % col(C.SKIN_SRGB),
        'shader_parameter/makeup_mask_a = ExtResource("4_mask_a")',
        'shader_parameter/makeup_mask_b = ExtResource("5_mask_b")',
        'shader_parameter/brows_color = %s' % col(getattr(C, "BROWS_SRGB", "4A3524")),
        'shader_parameter/lips_color = %s' % col(getattr(C, "LIPS_SRGB", "B07A68")),
        '',
        '[sub_resource type="ShaderMaterial" id="ShaderMaterial_body"]',
        'resource_name = "skin"',
        'shader = ExtResource("3_skin")',
        'shader_parameter/albedo = %s' % col(C.SKIN_SRGB),
        'shader_parameter/brows_amount = 0.0',
        'shader_parameter/lips_amount = 0.0',
        '',
        '[node name="%s" type="Node3D"]' % pname,
        'script = ExtResource("1_script")',
        'skin_head_material = SubResource("ShaderMaterial_head")',
        'skin_body_material = SubResource("ShaderMaterial_body")',
        'hair_path = "%s"' % ("%s/hair/%s.glb" % (root, hair_id) if hair_id else ""),
        'outfit = PackedStringArray(%s)' % ", ".join('"%s/wardrobe/%s.glb"' % (root, w) for w in outfit),
        'held_props = PackedStringArray(%s)' % ", ".join('"%s/model/%s.glb@%s%s"' % (root, p[0], p[1], ("@" + ",".join("%.5f" % v for v in p[2])) if len(p) > 2 else "") for p in props),
    ]
    if getattr(C, "IDLE_CLIP", ""):
        lines.append('idle_clip = &"%s"' % C.IDLE_CLIP)
    if getattr(C, "WALK_CLIP", ""):
        lines.append('walk_clip = &"%s"' % C.WALK_CLIP)
    lines += ['', '[node name="%s" parent="." instance=ExtResource("2_glb")]' % cid,
              'transform = Transform3D(-1, 0, 0, 0, 1, 0, 0, 0, -1, 0, 0, 0)', '']
    path = os.path.join(d, cid + "_model.tscn")
    with open(path, "w") as f:
        f.write("\n".join(lines))
    print("wrote", os.path.relpath(path, REPO), "outfit=%d hair=%s props=%d" % (len(outfit), hair_id, len(props)))


if __name__ == "__main__":
    for cid in (sys.argv[1:] or CAST):
        write(cid)
