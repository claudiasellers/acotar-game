"""The Spring Court's secondary cast and the human villagers, stylized for the
court's look: long-limbed, big-eyed, clean shapes and clear colour. Headless
Blender (bpy), deterministic. Main characters are NOT made here (R4): Tamlin,
Lucien, Feyre's family stay placeholders for the user's own Blender pass.

Run:  <venv with `pip install bpy`>/bin/python tools/blender/fae_people.py [out_dir]
Out:  creatures/models/people/<id>.gltf, and <id>_true.gltf where the glamour
      hides a different shape (feet at origin, facing -Z in Godot).

Each design is data in CAST below: proportions, skin, outfit, hair and extras
(horns, antlers, wings, bark, tail...). `glamour` holds the overrides for the
look Feyre sees before the glamour lifts.
"""

import math
import os
import sys

import bpy  # noqa: I001  (bpy must load before bmesh)
from mathutils import Vector

sys.path.insert(0, os.path.dirname(__file__))
import creatures as base  # noqa: E402  (shared helpers)

base.OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..", "..", "creatures", "models", "people")

BUDGET = 15000


def mat(name, rgb, rough=0.8, metal=0.0, emit=0.0):
    m = base.material(name, rgb, rough, emission=rgb if emit else None, strength=emit)
    if metal:
        m.node_tree.nodes["Principled BSDF"].inputs["Metallic"].default_value = metal
    return m


def lathe(name, profile, material, segments=20, arc=None):
    """A surface of revolution about z from (radius, z) pairs: skirts, robes,
    hats. `arc` = (start, end) radians makes an open sheet (a cloak's back)."""
    verts, faces = [], []
    closed = arc is None
    start, end = arc if arc else (0.0, 2 * math.pi)
    ring = segments if closed else segments + 1
    for (r, z) in profile:
        for s in range(ring):
            a = start + (end - start) * s / segments
            verts.append((r * math.cos(a), r * math.sin(a), z))
    for i in range(len(profile) - 1):
        for s in range(segments):
            a, b = i * ring + s, i * ring + (s + 1) % ring
            faces.append((a, b, b + ring, a + ring))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(material)
    for p in obj.data.polygons:
        p.use_smooth = True
    return obj


def blob(name, center, radius, material, scale=(1, 1, 1), segments=12):
    o = base.sphere(name, center, radius, material, segments)
    o.scale = scale
    return o


def body(p, skin, cloth, legs_mat, boots, sleeves):
    """Skin-modifier figure; materials by region so one mesh is skin, sleeves,
    trousers and boots. Returns (obj, head centre, head radius)."""
    g = base.Graph()
    H = p["height"]
    s = p.get("build", 1.0)
    hr = H * p.get("head", 0.078)
    g.add("pelvis", (0, 0, H * 0.5), (0.13 * s * H / 1.8, 0.09 * s * H / 1.8))
    g.add("waist", (0, 0.0, H * 0.6), (0.10 * s * H / 1.8, 0.075 * s * H / 1.8), "pelvis")
    g.add("chest", (0, 0.0, H * 0.71), (0.135 * s * H / 1.8, 0.09 * s * H / 1.8), "waist")
    g.add("neck", (0, 0.01, H * 0.8), 0.04 * H / 1.8, "chest")
    head = Vector((0, 0.02, H * 0.8 + hr * 1.05))
    g.add("head", tuple(head), hr, "neck")
    arm = 0.035 * H / 1.8 * p.get("limb", 1.0)
    leg = 0.055 * H / 1.8 * p.get("limb", 1.0) * s ** 0.5
    sh_x = 0.17 * s * H / 1.8
    for side in (-1, 1):
        sh = Vector((side * sh_x, 0, H * 0.76))
        el = sh + Vector((side * 0.05, 0.02, -H * 0.16))
        wr = el + Vector((side * 0.02, 0.06, -H * 0.14))
        hd = wr + Vector((0, 0.02, -H * 0.05 * p.get("hands", 1.0)))
        g.add(f"sh{side}", tuple(sh), arm * 1.3, "chest")
        g.add(f"el{side}", tuple(el), arm, f"sh{side}")
        g.add(f"wr{side}", tuple(wr), arm * 0.75, f"el{side}")
        g.add(f"hd{side}", tuple(hd), (arm * 0.9, arm * 0.45), f"wr{side}")
        hip = Vector((side * 0.075 * s * H / 1.8, 0, H * 0.47))
        kn = hip + Vector((0, 0.02, -H * 0.22))
        an = kn + Vector((0, -0.02, -H * 0.21))
        ft = an + Vector((0, 0.09 * H / 1.8, -0.03 * H / 1.8))
        g.add(f"hip{side}", tuple(hip), leg * 1.25, "pelvis")
        g.add(f"kn{side}", tuple(kn), leg, f"hip{side}")
        g.add(f"an{side}", tuple(an), leg * 0.65, f"kn{side}")
        g.add(f"ft{side}", tuple(ft), (leg * 0.75, leg * 0.4), f"an{side}")
    obj = g.build("Body")
    for m in (skin, cloth, legs_mat, boots):
        obj.data.materials.append(m)
    for poly in obj.data.polygons:
        c = poly.center
        slot = 1
        if c.z > H * 0.79 or (abs(c.x) > sh_x * 1.15 and c.z < H * 0.62 and c.z > H * 0.36 and not sleeves[1]):
            slot = 0  # head, neck, and bare forearms/hands
        if abs(c.x) > sh_x * 0.95 and c.z > H * 0.36 and c.z < H * 0.79 and not sleeves[0]:
            slot = 0  # sleeveless
        if abs(c.x) > sh_x * 1.15 and c.z < H * 0.47:
            slot = 0  # hands always skin
        if c.z < H * 0.47 and abs(c.x) <= sh_x * 1.15:
            slot = 2
        if c.z < H * 0.1 and abs(c.x) <= sh_x * 1.15:
            slot = 3
        poly.material_index = slot
    return obj, head, hr


def face(head, hr, p, parts):
    """Big glossy eyes, a small nose, cheeks: the court's appeal is in the face."""
    eye_rgb = p.get("eyes", (0.25, 0.42, 0.30))
    iris = mat("Iris", eye_rgb, 0.1, emit=p.get("eye_glow", 0.0))
    white = mat("EyeWhite", (0.97, 0.96, 0.95), 0.2)
    shine = mat("EyeShine", (1, 1, 1), 0.1, emit=0.6)
    skin = mat("Nose", p["skin"], 0.7)
    black_eyes = p.get("black_eyes", False)
    for side in (-1, 1):
        c = head + Vector((side * hr * 0.36, hr * 0.86, hr * 0.06))
        if not black_eyes:
            parts.append(blob(f"White{side}", c, hr * 0.22, white, (1.0, 0.6, 1.0)))
            parts.append(blob(f"Iris{side}", c + Vector((0, hr * 0.1, 0)), hr * 0.15, iris, (1.0, 0.6, 1.0)))
        else:
            parts.append(blob(f"Iris{side}", c + Vector((0, hr * 0.02, 0)), hr * 0.21, mat("Black", (0.01, 0.01, 0.015), 0.05), (1.0, 0.6, 1.0)))
        parts.append(base.sphere(f"Shine{side}", c + Vector((side * hr * 0.05, hr * 0.2, hr * 0.07)), hr * 0.045, shine, 6))
        brow = mat("Brow", p.get("hair", (0.3, 0.2, 0.1)), 0.9)
        parts.append(blob(f"Brow{side}", c + Vector((0, hr * 0.05, hr * 0.26)), hr * 0.16, brow, (1.0, 0.35, 0.25), 8))
    parts.append(blob("NoseTip", head + Vector((0, hr * 0.98, -hr * 0.12)), hr * 0.1, skin, (0.8, 1.0, 0.9), 8))
    if p.get("cheeks", True):
        blush = mat("Blush", tuple(c * 0.6 + d * 0.4 for c, d in zip(p["skin"], (1.0, 0.5, 0.55))), 0.8)
        for side in (-1, 1):
            parts.append(blob(f"Cheek{side}", head + Vector((side * hr * 0.5, hr * 0.72, -hr * 0.3)), hr * 0.16, blush, (1.0, 0.4, 0.7), 8))
    mouth = mat("Mouth", p.get("lips", (0.72, 0.38, 0.40)), 0.6)
    parts.append(blob("Mouth", head + Vector((0, hr * 0.9, -hr * 0.45)), hr * 0.14, mouth, (1.0, 0.35, 0.3), 8))
    if p.get("fangs"):
        ivory = mat("Fang", (0.95, 0.93, 0.86), 0.4)
        for side in (-1, 1):
            parts.append(base.cone(f"Fang{side}", head + Vector((side * hr * 0.07, hr * 0.92, -hr * 0.47)),
                                   head + Vector((side * hr * 0.07, hr * 0.95, -hr * 0.62)), hr * 0.035, ivory))


def ears(head, hr, p, parts, skin):
    kind = p.get("ears", "pointed")
    if kind == "round":
        for side in (-1, 1):
            parts.append(blob(f"Ear{side}", head + Vector((side * hr * 0.98, 0, 0)), hr * 0.2, skin, (0.5, 0.8, 1.0), 8))
        return
    if kind == "fox":
        fur = mat("EarFur", p.get("hair", (0.8, 0.4, 0.2)), 0.9)
        for side in (-1, 1):
            parts.append(base.cone(f"Ear{side}", head + Vector((side * hr * 0.55, -hr * 0.1, hr * 0.7)),
                                   head + Vector((side * hr * 0.8, -hr * 0.1, hr * 1.55)), hr * 0.3, fur, 8))
        return
    length = {"pointed": 0.55, "long": 1.1}.get(kind, 0.55)
    for side in (-1, 1):
        parts.append(base.cone(f"Ear{side}", head + Vector((side * hr * 0.9, -hr * 0.05, hr * 0.05)),
                               head + Vector((side * hr * (0.95 + length), -hr * 0.2, hr * (0.25 + length * 0.5))), hr * 0.17, skin, 8))


def hair(head, hr, H, p, parts):
    style = p.get("hair_style", "short")
    if style == "none":
        return
    m = mat("Hair", p.get("hair", (0.4, 0.25, 0.12)), p.get("hair_rough", 0.6))
    # Back and crown only, so the face stays clear.
    parts.append(blob("HairCap", head + Vector((0, -hr * 0.28, hr * 0.2)), hr * 1.06, m, (1.04, 0.88, 0.98), 14))
    if style == "bun":
        parts.append(base.sphere("Bun", head + Vector((0, -hr * 0.75, hr * 0.75)), hr * 0.45, m, 10))
    elif style == "long":
        g = base.Graph()
        g.add("a", tuple(head + Vector((0, -hr * 0.7, 0.0))), (hr * 0.85, hr * 0.5))
        g.add("b", tuple(head + Vector((0, -hr * 0.8, -hr * 1.6))), (hr * 0.8, hr * 0.4), "a")
        g.add("c", tuple(head + Vector((0, -hr * 0.75, -hr * 3.0))), (hr * 0.55, hr * 0.25), "b")
        o = g.build("LongHair")
        o.data.materials.append(m)
        parts.append(o)
    elif style == "braid":
        for i in range(6):
            parts.append(base.sphere(f"Braid{i}", head + Vector((0, -hr * 0.85 - i * 0.01, -hr * (0.4 + i * 0.42))),
                                     hr * (0.3 - i * 0.025), m, 8))
    elif style == "tall":
        parts.append(blob("Crest", head + Vector((0, -hr * 0.2, hr * 0.85)), hr * 0.7, m, (0.7, 1.0, 1.1), 10))
    if p.get("beard"):
        parts.append(blob("Beard", head + Vector((0, hr * 0.62, -hr * 0.85)), hr * 0.42, m, (1.0, 0.6, 0.9), 10))


def outfit(H, p, parts):
    kind = p.get("outfit", "tunic")
    cloth = mat("Cloth", p["cloth"], 0.85)
    trim = mat("Trim", p.get("trim", (0.95, 0.85, 0.55)), 0.5, metal=p.get("trim_metal", 0.0))
    s = p.get("build", 1.0) * H / 1.8
    if kind in ("dress", "gown"):
        hem = 0.42 if kind == "gown" else 0.32
        parts.append(lathe("Skirt", [(0.11 * s, H * 0.62), (0.15 * s, H * 0.5), (0.25 * s * hem / 0.32, H * 0.22),
                                     (hem * s, H * 0.02), (hem * s * 0.97, H * 0.0)], cloth))
        parts.append(lathe("Sash", [(0.108 * s, H * 0.6), (0.112 * s, H * 0.635)], trim))
    elif kind == "robe":
        parts.append(lathe("Robe", [(0.16 * s, H * 0.77), (0.15 * s, H * 0.6), (0.2 * s, H * 0.3),
                                    (0.28 * s, H * 0.02), (0.27 * s, H * 0.0)], cloth))
        parts.append(lathe("Belt", [(0.153 * s, H * 0.58), (0.157 * s, H * 0.61)], trim))
    elif kind == "tunic":
        parts.append(lathe("Tunic", [(0.12 * s, H * 0.62), (0.155 * s, H * 0.48), (0.18 * s, H * 0.36), (0.175 * s, H * 0.34)], cloth))
        parts.append(lathe("Belt", [(0.123 * s, H * 0.57), (0.128 * s, H * 0.6)], trim))
    elif kind == "armor":
        steel = mat("Armor", p["cloth"], 0.35, metal=0.8)
        parts.append(blob("Breastplate", (0, 0.02 * s, H * 0.7), 0.16 * s, steel, (1.0, 0.75, 1.15), 14))
        for side in (-1, 1):
            parts.append(blob(f"Pauldron{side}", (side * 0.19 * s, 0, H * 0.77), 0.075 * s, steel, (1.1, 1.0, 0.75), 10))
        parts.append(lathe("Tasset", [(0.13 * s, H * 0.6), (0.17 * s, H * 0.46), (0.18 * s, H * 0.4)], trim))
        if p.get("cloak"):
            cloak = mat("Cloak", p["cloak"], 0.9)
            parts.append(lathe("Cloak", [(0.17 * s, H * 0.79), (0.24 * s, H * 0.5), (0.3 * s, H * 0.1)], cloak, 20,
                               arc=(math.pi * 1.08, math.pi * 1.92)))
    if p.get("apron"):
        apron = mat("Apron", p["apron"], 0.9)
        bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0.15 * s, H * 0.42))
        a = bpy.context.active_object
        a.name = "Apron"
        a.scale = (0.24 * s, 0.01, H * 0.36)
        a.data.materials.append(apron)
        parts.append(a)
    if p.get("shawl"):
        shawl = mat("Shawl", p["shawl"], 0.95)
        parts.append(lathe("Shawl", [(0.08 * s, H * 0.81), (0.2 * s, H * 0.75), (0.21 * s, H * 0.66)], shawl))
    if p.get("collar"):
        parts.append(lathe("Collar", [(0.06 * s, H * 0.8), (0.14 * s, H * 0.77)], trim))


def mask(head, hr, p, parts):
    """The Spring Court's masks, fused on by the curse: gilt leaves over the
    upper face, eyes showing through."""
    if not p.get("mask"):
        return
    gold = mat("Mask", p["mask"], 0.3, metal=0.85)
    parts.append(blob("Mask", head + Vector((0, hr * 0.66, hr * 0.14)), hr * 0.8, gold, (0.98, 0.42, 0.36), 14))
    for side in (-1, 1):
        for i in range(2):
            tip = head + Vector((side * hr * (0.78 + 0.18 * i), hr * 0.55, hr * (0.32 + 0.2 * i)))
            leaf = blob(f"Leaf{side}{i}", tip, hr * 0.2, gold, (1.1, 0.25, 0.45), 8)
            leaf.rotation_euler = (0, side * -0.6, 0)
            parts.append(leaf)


def extras(head, hr, H, p, parts):
    s = H / 1.8
    for kind in p.get("extras", []):
        if kind == "horns":
            horn = mat("Horn", p.get("horn", (0.86, 0.80, 0.66)), 0.5)
            for side in (-1, 1):
                prev = head + Vector((side * hr * 0.45, -hr * 0.1, hr * 0.7))
                for i in range(3):
                    nxt = prev + Vector((side * hr * 0.25, -hr * 0.25, hr * (0.35 - i * 0.15)))
                    parts.append(base.cone(f"Horn{side}{i}", prev, nxt, hr * (0.2 - i * 0.05), horn, 8))
                    prev = nxt
        elif kind == "antlers":
            horn = mat("Antler", p.get("horn", (0.82, 0.72, 0.55)), 0.6)
            for side in (-1, 1):
                root = head + Vector((side * hr * 0.4, -hr * 0.1, hr * 0.85))
                top = root + Vector((side * hr * 0.6, -hr * 0.2, hr * 1.5))
                parts.append(base.cone(f"Antler{side}", root, top, hr * 0.12, horn, 6))
                for t in (0.35, 0.65):
                    b = root.lerp(top, t)
                    parts.append(base.cone(f"Tine{side}{t}", b, b + Vector((side * hr * 0.5, hr * 0.2, hr * 0.45)), hr * 0.07, horn, 6))
        elif kind == "wings":
            wing = mat("Wing", p.get("wing", (0.8, 0.9, 1.0)), 0.2, emit=0.25)
            for side in (-1, 1):
                for i, (w, h, z) in enumerate(((0.42, 0.5, 0.74), (0.3, 0.34, 0.56))):
                    o = blob(f"Wing{side}{i}", (side * w * s * 0.7, -0.12 * s, H * z), w * s, wing, (0.75, 0.04, h / w))
                    o.rotation_euler = (0, side * -0.35, side * 0.4 * (1 if i == 0 else -1))
                    parts.append(o)
        elif kind == "tail":
            fur = mat("Tail", p.get("tail", p.get("hair", (0.8, 0.4, 0.2))), 0.9)
            g = base.Graph()
            g.add("a", (0, -0.1 * s, H * 0.46), 0.04 * s)
            g.add("b", (0, -0.3 * s, H * 0.35), 0.1 * s, "a")
            g.add("c", (0, -0.45 * s, H * 0.42), 0.09 * s, "b")
            g.add("d", (0, -0.5 * s, H * 0.55), 0.03 * s, "c")
            o = g.build("Tail")
            o.data.materials.append(fur)
            parts.append(o)
            if p.get("tail_tip"):
                parts.append(base.sphere("TailTip", (0, -0.5 * s, H * 0.54), 0.06 * s, mat("TailTip", p["tail_tip"], 0.9), 8))
        elif kind == "bark":
            # Ridged bark plates over arms and face edges; knots on the brow.
            bark = mat("BarkRidge", tuple(c * 0.75 for c in p["skin"]), 0.95)
            for i in range(7):
                a = i * 0.9
                c = head + Vector((math.cos(a) * hr * 0.95, math.sin(a) * hr * 0.4 - hr * 0.2, hr * (0.6 - i * 0.12)))
                parts.append(blob(f"Knot{i}", c, hr * 0.14, bark, (0.6, 0.6, 1.4), 6))
            for side in (-1, 1):
                for i in range(4):
                    c = Vector((side * 0.215 * s, 0.03, H * (0.68 - i * 0.07)))
                    parts.append(blob(f"Ridge{side}{i}", c, 0.03 * s, bark, (0.8, 0.8, 1.6), 6))
        elif kind == "leaves":
            leaf = mat("Leaf", p.get("leaf", (0.45, 0.72, 0.35)), 0.6)
            for i in range(9):
                a = i * 2 * math.pi / 9
                c = head + Vector((math.cos(a) * hr * 0.95, math.sin(a) * hr * 0.6 - hr * 0.2, hr * 0.75 + 0.02 * math.sin(a * 3)))
                o = blob(f"LeafCrown{i}", c, hr * 0.3, leaf, (0.45, 0.15, 1.0), 8)
                o.rotation_euler = (0.3 * math.sin(a), 0.4 * math.cos(a), a)
                parts.append(o)
        elif kind == "flowers":
            petal = mat("Petal", p.get("flower", (1.0, 0.7, 0.8)), 0.5)
            heart = mat("FlowerHeart", (1.0, 0.85, 0.35), 0.5)
            for i in range(5):
                a = -0.9 + i * 0.45
                c = head + Vector((math.sin(a) * hr * 1.0, -hr * 0.1 + math.cos(a) * hr * 0.3, hr * (0.8 - abs(a) * 0.2)))
                parts.append(blob(f"Flower{i}", c, hr * 0.2, petal, (1.0, 1.0, 0.45), 8))
                parts.append(base.sphere(f"Heart{i}", c + Vector((0, 0, hr * 0.06)), hr * 0.07, heart, 6))
        elif kind == "mushroom":
            cap = mat("Cap", p.get("cap", (0.85, 0.25, 0.22)), 0.6)
            spot = mat("Spot", (0.98, 0.96, 0.9), 0.7)
            parts.append(blob("Cap", head + Vector((0, 0, hr * 0.85)), hr * 1.6, cap, (1.0, 1.0, 0.5), 16))
            for i in range(6):
                a = i * 1.05
                parts.append(base.sphere(f"Spot{i}", head + Vector((math.cos(a) * hr * 0.9, math.sin(a) * hr * 0.9, hr * 1.4)), hr * 0.17, spot, 6))
        elif kind == "quills":
            q = mat("Quill", p.get("hair", (0.5, 0.4, 0.3)), 0.8)
            for i in range(14):
                a = -1.2 + i * 0.18
                b = head + Vector((math.sin(a) * hr * 0.7, -hr * 0.5, hr * 0.5 - abs(a) * hr * 0.3))
                parts.append(base.cone(f"Quill{i}", b, b + Vector((math.sin(a) * hr * 0.6, -hr * 1.2, hr * 0.2)), hr * 0.08, q, 5))
        elif kind == "scales":
            sc = mat("Scale", p.get("scale", (0.4, 0.75, 0.75)), 0.25, metal=0.3)
            for side in (-1, 1):
                for i in range(5):
                    parts.append(blob(f"Scale{side}{i}", head + Vector((side * hr * 0.75, hr * 0.2, -hr * 0.1 + i * hr * 0.12)), hr * 0.1, sc, (0.4, 1.0, 0.7), 6))
            parts.append(blob("Fin", head + Vector((0, -hr * 0.3, hr * 0.9)), hr * 0.6, sc, (0.15, 1.0, 0.7), 10))
        elif kind == "feathers":
            fe = mat("Feather", p.get("hair", (0.6, 0.5, 0.4)), 0.8)
            for side in (-1, 1):
                parts.append(base.cone(f"Tuft{side}", head + Vector((side * hr * 0.5, 0, hr * 0.75)),
                                       head + Vector((side * hr * 0.75, -hr * 0.2, hr * 1.45)), hr * 0.18, fe, 6))
            parts.append(blob("Ruff", (0, 0, H * 0.79), hr * 1.2, fe, (1.0, 0.9, 0.35), 12))
        elif kind == "thorns":
            th = mat("Thorn", (0.32, 0.42, 0.22), 0.6)
            for i in range(10):
                a = i * 0.63
                b = Vector((math.cos(a) * 0.13 * s, math.sin(a) * 0.1 * s, H * (0.55 + 0.02 * i)))
                parts.append(base.cone(f"Thorn{i}", b, b * 1.0 + Vector((math.cos(a) * 0.06 * s, math.sin(a) * 0.05 * s, 0.03)), 0.012 * s, th, 5))
        elif kind == "pack":
            pack = mat("Pack", (0.45, 0.32, 0.2), 0.95)
            parts.append(blob("Pack", (0, -0.2 * s, H * 0.62), 0.22 * s, pack, (1.0, 0.7, 1.3), 12))
            for i, rgb in enumerate(((0.7, 0.25, 0.2), (0.3, 0.45, 0.6), (0.85, 0.75, 0.4))):
                parts.append(blob(f"Bundle{i}", (-0.12 * s + i * 0.12 * s, -0.25 * s, H * 0.82 + 0.02 * i), 0.07 * s, mat(f"Bundle{i}", rgb, 0.9), (1, 1, 0.8), 8))
        elif kind == "hat":
            felt = mat("Hat", p.get("hat", (0.25, 0.2, 0.16)), 0.95)
            parts.append(lathe("Hat", [(hr * 1.7, head.z + hr * 0.55), (hr * 1.6, head.z + hr * 0.62), (hr * 0.85, head.z + hr * 0.7),
                                       (hr * 0.75, head.z + hr * 1.35), (0.001, head.z + hr * 1.4)], felt, 16))
        elif kind == "hood":
            hood = mat("Hood", p.get("hood", p["cloth"]), 0.95)
            parts.append(blob("Hood", head + Vector((0, -hr * 0.15, hr * 0.1)), hr * 1.25, hood, (1.0, 1.0, 1.05), 14))
        elif kind == "vials":
            glass = [mat(f"Vial{i}", rgb, 0.1, emit=0.6) for i, rgb in enumerate(((0.4, 0.9, 0.6), (0.9, 0.45, 0.8), (0.5, 0.7, 1.0)))]
            for i, gm in enumerate(glass):
                parts.append(blob(f"Vial{i}", (-0.08 * s + i * 0.08 * s, 0.17 * s, H * 0.57), 0.025 * s, gm, (1, 1, 1.6), 8))
        elif kind == "pins":
            pin = mat("Pin", (0.85, 0.82, 0.78), 0.2, metal=0.9)
            for i in range(6):
                parts.append(base.sphere(f"Pin{i}", (-0.07 * s + (i % 3) * 0.06 * s, 0.155 * s, H * (0.6 - (i // 3) * 0.05)), 0.008 * s, pin, 6))
            ribbon = mat("Ribbon", (0.95, 0.6, 0.75), 0.5)
            parts.append(lathe("Tape", [(0.165 * s, H * 0.77), (0.17 * s, H * 0.78)], ribbon, 16))
        elif kind == "spear":
            wood = mat("Shaft", (0.45, 0.32, 0.2), 0.8)
            steel = mat("Head", (0.85, 0.85, 0.82), 0.3, metal=0.9)
            x = 0.3 * s
            parts.append(base.cone("Shaft", (x, 0.12 * s, 0.0), (x, 0.12 * s, H * 1.12), 0.018 * s, wood, 6))
            parts.append(base.cone("Blade", (x, 0.12 * s, H * 1.08), (x, 0.12 * s, H * 1.22), 0.035 * s, steel, 6))
        elif kind == "basket":
            wicker = mat("Wicker", (0.72, 0.56, 0.32), 0.9)
            parts.append(lathe("Basket", [(0.07 * s, H * 0.4), (0.12 * s, H * 0.48), (0.12 * s, H * 0.5)], wicker, 14))


def build(name, p):
    base.reset()
    H = p["height"]
    skin = mat("Skin", p["skin"], p.get("skin_rough", 0.6))
    cloth = mat("Top", p.get("top", p["cloth"]), 0.85)
    legs = mat("Legs", p.get("legs", tuple(c * 0.6 for c in p["cloth"])), 0.85)
    boots = mat("Boots", p.get("boots", (0.32, 0.22, 0.14)), 0.7)
    obj, head, hr = body(p, skin, cloth, legs, boots, p.get("sleeves", (True, True)))
    parts = [obj]
    face(head, hr, p, parts)
    ears(head, hr, p, parts, skin)
    hair(head, hr, H, p, parts)
    outfit(H, p, parts)
    mask(head, hr, p, parts)
    extras(head, hr, H, p, parts)
    joined = base.join(parts, name)
    n = base.tris([joined])
    assert n <= BUDGET, f"{name}: {n} tris over the R4 budget"
    base.export(name, [joined])


def look(design, **overrides):
    out = dict(design)
    out.update(overrides)
    return out


# ------------------------------------------------------------------ the cast
# Canon tags live in data/people/*.tres; [X] means invented here. Glamoured
# looks are what Feyre sees before the glamour lifts (keeper: lifted ch23).

SPRING_MASK = (0.92, 0.78, 0.42)

CAST = {
    # --- the manor household
    "alis": {"height": 1.62, "skin": (0.56, 0.40, 0.27), "skin_rough": 0.95, "cloth": (0.42, 0.52, 0.34),
             "apron": (0.93, 0.9, 0.82), "outfit": "dress", "hair": (0.32, 0.22, 0.13), "hair_style": "bun",
             "eyes": (0.45, 0.3, 0.15), "extras": ["bark", "leaves"], "leaf": (0.5, 0.65, 0.32), "mask": SPRING_MASK,
             "cheeks": False},
    "servant_maid": {"height": 1.66, "skin": (0.62, 0.78, 0.60), "cloth": (0.55, 0.68, 0.82), "apron": (0.97, 0.95, 0.9),
                     "outfit": "dress", "hair": (0.95, 0.88, 0.62), "hair_style": "braid", "ears": "long",
                     "eyes": (0.2, 0.4, 0.6), "extras": ["flowers"], "flower": (1.0, 0.82, 0.9), "mask": SPRING_MASK},
    "servant_footman": {"height": 1.82, "skin": (0.80, 0.70, 0.86), "cloth": (0.28, 0.45, 0.32), "trim": (0.92, 0.8, 0.45),
                        "trim_metal": 0.7, "outfit": "tunic", "legs": (0.9, 0.88, 0.8), "hair": (0.25, 0.2, 0.3),
                        "hair_style": "short", "extras": ["horns"], "horn": (0.95, 0.9, 0.78), "collar": True, "mask": SPRING_MASK},
    "servant_cook": {"height": 1.58, "build": 1.3, "skin": (0.58, 0.64, 0.52), "skin_rough": 0.9, "cloth": (0.75, 0.55, 0.42),
                     "apron": (0.97, 0.95, 0.9), "outfit": "dress", "hair": (0.35, 0.45, 0.28), "hair_style": "bun",
                     "ears": "pointed", "eyes": (0.5, 0.35, 0.2), "extras": ["mushroom"], "cap": (0.78, 0.5, 0.3),
                     "mask": SPRING_MASK},
    "seamstress": {"height": 1.86, "skin": (0.80, 0.74, 0.92), "cloth": (0.58, 0.42, 0.72), "trim": (0.95, 0.85, 0.95),
                   "outfit": "gown", "hair": (0.95, 0.95, 0.98), "hair_style": "long", "limb": 0.85, "hands": 1.5,
                   "eyes": (0.5, 0.3, 0.6), "extras": ["pins", "wings"], "wing": (0.85, 0.8, 1.0), "mask": SPRING_MASK},
    "potion_maker": {"height": 1.6, "skin": (0.75, 0.66, 0.52), "cloth": (0.32, 0.36, 0.52), "trim": (0.85, 0.7, 0.4),
                     "outfit": "robe", "hair": (0.68, 0.6, 0.5), "hair_style": "tall", "eyes": (0.95, 0.75, 0.25),
                     "eye_glow": 0.4, "extras": ["feathers", "vials"], "mask": SPRING_MASK},
    # --- the sentries [X]: Tamlin's warriors at the borders
    "sentry_1": {"height": 1.92, "build": 1.15, "skin": (0.82, 0.68, 0.55), "cloth": (0.55, 0.62, 0.48), "trim": (0.75, 0.62, 0.38),
                 "outfit": "armor", "cloak": (0.3, 0.42, 0.26), "legs": (0.3, 0.28, 0.22), "hair": (0.3, 0.18, 0.1),
                 "hair_style": "short", "extras": ["spear", "horns"], "horn": (0.4, 0.35, 0.3), "mask": (0.5, 0.55, 0.4)},
    "sentry_2": {"height": 1.88, "build": 1.1, "skin": (0.92, 0.84, 0.74), "cloth": (0.6, 0.6, 0.58), "trim": (0.85, 0.75, 0.45),
                 "outfit": "armor", "cloak": (0.45, 0.25, 0.2), "legs": (0.3, 0.28, 0.22), "hair": (0.85, 0.5, 0.25),
                 "hair_style": "short", "ears": "fox", "extras": ["spear", "tail"], "tail_tip": (0.98, 0.96, 0.92),
                 "mask": (0.5, 0.55, 0.4)},
    # --- Calanmai's three (story ids high_fae_male, _2, _3): lesser faeries,
    # beautiful and wrong. Black eyes, pointed teeth, too-long pale hands.
    "calanmai_1": {"height": 2.08, "build": 0.85, "skin": (0.88, 0.88, 0.9), "cloth": (0.14, 0.16, 0.22), "trim": (0.6, 0.62, 0.7),
                   "outfit": "tunic", "legs": (0.1, 0.1, 0.12), "hair": (0.06, 0.06, 0.08), "hair_style": "long",
                   "black_eyes": True, "fangs": True, "hands": 1.9, "limb": 0.85, "cheeks": False, "lips": (0.6, 0.5, 0.55)},
    "calanmai_2": {"height": 2.12, "build": 0.82, "skin": (0.84, 0.86, 0.88), "cloth": (0.22, 0.14, 0.2), "trim": (0.7, 0.6, 0.7),
                   "outfit": "tunic", "legs": (0.1, 0.08, 0.1), "hair": (0.75, 0.75, 0.8), "hair_style": "long",
                   "black_eyes": True, "fangs": True, "hands": 1.9, "limb": 0.85, "cheeks": False, "lips": (0.55, 0.5, 0.55)},
    "calanmai_3": {"height": 2.05, "build": 0.88, "skin": (0.9, 0.87, 0.84), "cloth": (0.12, 0.2, 0.18), "trim": (0.55, 0.7, 0.62),
                   "outfit": "tunic", "legs": (0.08, 0.1, 0.1), "hair": (0.1, 0.12, 0.1), "hair_style": "short",
                   "black_eyes": True, "fangs": True, "hands": 1.9, "limb": 0.85, "cheeks": False, "lips": (0.6, 0.5, 0.5)},
    # --- lesser fae of the villages and Fire Night: twelve kinds [X]
    "fae_dryad": {"height": 1.75, "skin": (0.72, 0.84, 0.6), "cloth": (0.4, 0.62, 0.36), "outfit": "dress", "hair": (0.35, 0.55, 0.25),
                  "hair_style": "long", "sleeves": (False, False), "extras": ["leaves", "flowers"], "flower": (1.0, 0.95, 0.75)},
    "fae_mushroom": {"height": 1.05, "build": 1.25, "head": 0.1, "skin": (0.9, 0.82, 0.7), "cloth": (0.5, 0.4, 0.3),
                     "outfit": "tunic", "hair_style": "none", "ears": "round", "extras": ["mushroom"]},
    "fae_moth": {"height": 1.6, "skin": (0.92, 0.9, 0.82), "cloth": (0.75, 0.68, 0.55), "outfit": "dress", "hair": (0.85, 0.8, 0.7),
                 "hair_style": "bun", "eyes": (0.1, 0.1, 0.12), "extras": ["wings", "feathers"], "wing": (0.82, 0.75, 0.6)},
    "fae_fox": {"height": 1.7, "skin": (0.95, 0.85, 0.75), "cloth": (0.3, 0.45, 0.25), "outfit": "tunic", "legs": (0.5, 0.4, 0.3),
                "hair": (0.9, 0.45, 0.18), "hair_style": "short", "ears": "fox", "extras": ["tail"], "tail_tip": (0.98, 0.96, 0.92)},
    "fae_stag": {"height": 2.0, "build": 1.15, "skin": (0.7, 0.55, 0.42), "cloth": (0.45, 0.35, 0.25), "outfit": "tunic",
                 "legs": (0.35, 0.28, 0.2), "hair": (0.4, 0.3, 0.2), "hair_style": "short", "beard": True, "extras": ["antlers"]},
    "fae_nymph": {"height": 1.7, "skin": (0.62, 0.82, 0.86), "cloth": (0.4, 0.7, 0.75), "outfit": "gown", "hair": (0.2, 0.45, 0.55),
                  "hair_style": "long", "ears": "long", "sleeves": (False, False), "extras": ["scales"], "scale": (0.45, 0.8, 0.8)},
    "fae_birch": {"height": 1.9, "build": 0.8, "skin": (0.92, 0.9, 0.86), "skin_rough": 0.95, "cloth": (0.75, 0.82, 0.55),
                  "outfit": "robe", "hair": (0.75, 0.8, 0.4), "hair_style": "long", "extras": ["bark", "leaves"], "leaf": (0.85, 0.75, 0.3)},
    "fae_hedgehog": {"height": 1.0, "build": 1.3, "head": 0.1, "skin": (0.85, 0.72, 0.6), "cloth": (0.6, 0.35, 0.3),
                     "outfit": "dress", "apron": (0.95, 0.92, 0.85), "hair": (0.5, 0.38, 0.28), "hair_style": "none",
                     "ears": "round", "extras": ["quills", "basket"]},
    "fae_pixie": {"height": 1.2, "build": 0.85, "head": 0.09, "skin": (0.98, 0.86, 0.9), "cloth": (0.98, 0.7, 0.82), "outfit": "dress",
                  "hair": (0.95, 0.55, 0.7), "hair_style": "tall", "ears": "long", "sleeves": (False, False),
                  "extras": ["wings", "flowers"], "wing": (0.95, 0.8, 1.0), "flower": (1.0, 1.0, 0.8)},
    "fae_satyr": {"height": 1.75, "skin": (0.85, 0.68, 0.55), "cloth": (0.6, 0.42, 0.25), "top": (0.85, 0.75, 0.55),
                  "outfit": "tunic", "legs": (0.5, 0.36, 0.24), "boots": (0.15, 0.12, 0.1), "hair": (0.25, 0.15, 0.1),
                  "hair_style": "short", "extras": ["horns", "tail"], "tail": (0.5, 0.36, 0.24), "horn": (0.55, 0.45, 0.35)},
    "fae_rose": {"height": 1.72, "skin": (0.95, 0.78, 0.78), "cloth": (0.82, 0.2, 0.32), "outfit": "gown", "hair": (0.55, 0.08, 0.15),
                 "hair_style": "long", "sleeves": (False, False), "extras": ["flowers", "thorns"], "flower": (0.95, 0.3, 0.42)},
    "fae_owl": {"height": 1.45, "build": 1.15, "head": 0.09, "skin": (0.82, 0.74, 0.62), "cloth": (0.55, 0.45, 0.35), "outfit": "robe",
                "hair": (0.65, 0.55, 0.42), "hair_style": "tall", "eyes": (0.95, 0.65, 0.15), "eye_glow": 0.5, "extras": ["feathers"]},
    # --- the human village near the cottage: winter-poor, drab, warm [C?]
    "human_woman": {"height": 1.62, "skin": (0.93, 0.80, 0.70), "cloth": (0.45, 0.38, 0.32), "outfit": "dress",
                    "shawl": (0.55, 0.3, 0.25), "hair": (0.4, 0.28, 0.18), "hair_style": "bun", "ears": "round"},
    "human_man": {"height": 1.75, "skin": (0.88, 0.74, 0.62), "cloth": (0.38, 0.36, 0.32), "outfit": "tunic", "legs": (0.3, 0.27, 0.24),
                  "hair": (0.3, 0.22, 0.15), "hair_style": "short", "beard": True, "ears": "round", "extras": ["hat"]},
    "human_elder": {"height": 1.55, "build": 0.95, "skin": (0.9, 0.78, 0.7), "cloth": (0.32, 0.3, 0.35), "outfit": "dress",
                    "shawl": (0.4, 0.42, 0.5), "hair": (0.85, 0.85, 0.85), "hair_style": "bun", "ears": "round",
                    "extras": ["hood", "basket"], "hood": (0.4, 0.42, 0.5)},
    "human_youth": {"height": 1.7, "build": 0.9, "skin": (0.78, 0.6, 0.48), "cloth": (0.42, 0.45, 0.38), "outfit": "tunic",
                    "legs": (0.32, 0.28, 0.24), "hair": (0.12, 0.1, 0.08), "hair_style": "short", "ears": "round"},
    "peddler": {"height": 1.7, "build": 1.05, "skin": (0.86, 0.72, 0.6), "cloth": (0.45, 0.32, 0.4), "trim": (0.85, 0.7, 0.35),
                "outfit": "robe", "hair": (0.5, 0.45, 0.4), "hair_style": "short", "beard": True, "ears": "round",
                "extras": ["pack", "hat"], "hat": (0.35, 0.25, 0.3)},
}

# What Feyre sees before the glamour lifts: the household as masked,
# High-Fae-smooth figures with no bark, horns, wings or caps. [X] pending keeper.
GLAMOUR_HIDES = ("bark", "leaves", "horns", "antlers", "wings", "tail", "mushroom", "quills", "scales", "feathers", "thorns")
GLAMOURED = {
    "alis": {"skin": (0.9, 0.78, 0.66), "skin_rough": 0.6, "cheeks": True},
    "servant_maid": {"skin": (0.94, 0.82, 0.74), "ears": "pointed"},
    "servant_footman": {"skin": (0.9, 0.78, 0.7)},
    "servant_cook": {"skin": (0.9, 0.76, 0.66), "hair_style": "bun"},
    "seamstress": {"skin": (0.94, 0.84, 0.8)},
    "potion_maker": {"skin": (0.88, 0.76, 0.64), "eye_glow": 0.0, "eyes": (0.35, 0.3, 0.2)},
    "sentry_1": {},
    "sentry_2": {"ears": "pointed"},
}


def glamoured(name):
    design = CAST[name]
    keep = [e for e in design.get("extras", []) if e not in GLAMOUR_HIDES]
    return look(design, extras=keep, **GLAMOURED[name])


if __name__ == "__main__":
    only = set(os.environ.get("ONLY", "").split(",")) - {""}
    for name, design in CAST.items():
        if only and name not in only:
            continue
        if name in GLAMOURED:
            build(name, glamoured(name))
            build(f"{name}_true", design)
        else:
            build(name, design)
