"""Spring Court fae creatures and the white horse, with headless Blender (bpy).

Run:  <venv with `pip install bpy`>/bin/python tools/blender/fae_creatures.py [out_dir]
Out:  creatures/models/fae/<name>.gltf (feet at origin, facing -Z in Godot)

The Suriel, the naga and the Attor are horror (engineering rule R3): never
cute, never pastel. Appearance follows the keeper's canon notes in
lore/04-creatures/. The white horse is the beautiful one.
"""

import math
import os
import sys

import bpy  # noqa: I001  (bpy must load before bmesh)
from mathutils import Vector

sys.path.insert(0, os.path.dirname(__file__))
import creatures as base  # noqa: E402  (shared helpers)

base.OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..", "..", "creatures", "models", "fae")


def decimated(obj, ratio):
    """Trims a model under the R4 triangle budget."""
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    mod = obj.modifiers.new("Trim", "DECIMATE")
    mod.ratio = ratio
    bpy.ops.object.modifier_apply(modifier="Trim")
    obj.select_set(False)
    return obj


def face_keys(obj, builders):
    """Threat-display shape keys (lane L36, docs/contracts/faces.md): builders is [(name, fn)], fn(P, mat)
    -> (n, 3) deltas, where P are vertex positions and mat each vertex's material name."""
    import numpy as np
    me = obj.data
    P = np.array([v.co[:] for v in me.vertices])
    names = [m.name for m in me.materials]
    mat = [""] * len(P)
    for poly in me.polygons:
        for vi in poly.vertices:
            mat[vi] = names[poly.material_index]
    mat = np.array(mat)
    obj.shape_key_add(name="Basis", from_mix=False)
    for name, fn in builders:
        sk = obj.shape_key_add(name=name, from_mix=False)
        sk.data.foreach_set("co", (P + fn(P, mat)).ravel())
        sk.value = 0.0
    return obj


def _np():
    import numpy as np
    return np


def _scale_islands(P, sel, centers, k):
    """Scale the selected vertices about the nearest of `centers` (eyes) by k."""
    np = _np()
    d = np.zeros_like(P)
    C = np.array([tuple(c) for c in centers])
    idx = np.where(sel)[0]
    near = np.argmin(((P[idx, None, :] - C[None, :, :]) ** 2).sum(-1), axis=1)
    d[idx] = (P[idx] - C[near]) * (k - 1.0)
    return d


def humanoid(p):
    """A skin-modifier figure from proportions. y forward, z up. Returns (obj, graph)."""
    g = base.Graph()
    H = p["height"]
    hunch = p.get("hunch", 0.0)
    g.add("pelvis", (0, 0, H * 0.5), (p["hips"], p["hips"] * 0.75))
    g.add("waist", (0, hunch * 0.3, H * 0.6), (p["waist"], p["waist"] * 0.75), "pelvis")
    g.add("chest", (0, hunch * 0.7, H * 0.72), (p["chest"], p["chest"] * 0.7), "waist")
    g.add("neck", (0, hunch * 1.2 + 0.03, H * 0.82), p["neck"], "chest")
    head = Vector((0, hunch * 1.4 + p.get("head_fwd", 0.05), H * 0.88))
    g.add("head", tuple(head), p["head"], "neck")
    if p.get("snout"):
        g.add("snout", tuple(head + Vector((0, p["snout"], -p["head"] * 0.25))), p["head"] * 0.45, "head")
    arm = p["arm"]
    for side in (-1, 1):
        sh = Vector((side * p["shoulders"], hunch * 0.7, H * 0.78))
        g.add(f"sh{side}", tuple(sh), arm * 1.3, "chest")
        reach = p.get("arm_len", 1.0)
        el = sh + Vector((side * 0.06, 0.05, -H * 0.17 * reach))
        wr = el + Vector((side * 0.02, 0.12 * reach, -H * 0.14 * reach))
        hand = wr + Vector((0, 0.06 * reach, -0.07 * reach))
        g.add(f"el{side}", tuple(el), arm, f"sh{side}")
        g.add(f"wr{side}", tuple(wr), arm * 0.7, f"el{side}")
        g.add(f"hd{side}", tuple(hand), (arm * 1.0, arm * 0.45), f"wr{side}")
        if p.get("legs", True):
            hip = Vector((side * p["hips"] * 0.55, 0, H * 0.47))
            kn = hip + Vector((0, 0.04 + p.get("knee_fwd", 0.0), -H * 0.23))
            an = kn + Vector((0, -0.04, -H * 0.21))
            ft = an + Vector((0, 0.1, -0.03))
            g.add(f"hip{side}", tuple(hip), p["leg"] * 1.25, "pelvis")
            g.add(f"kn{side}", tuple(kn), p["leg"], f"hip{side}")
            g.add(f"an{side}", tuple(an), p["leg"] * 0.6, f"kn{side}")
            g.add(f"ft{side}", tuple(ft), (p["leg"] * 0.7, p["leg"] * 0.35), f"an{side}")
    if p.get("tail"):
        g.chain("tail", "pelvis", p["tail"], p["tail_r"])
    return g.build("Body"), g, head


def suriel():
    """Tall, thin, corpse-like, hunched; veiled tattered robe; bone face;
    long teeth; scabby grey arms; yellow cracked nails; swirling milky eyes."""
    base.reset()
    skin = base.material("Skin", (0.42, 0.42, 0.40), 0.85)
    robe = base.material("Robe", (0.06, 0.055, 0.06), 0.95)
    bone = base.material("Bone", (0.78, 0.74, 0.64), 0.7)
    nails = base.material("Nails", (0.72, 0.62, 0.30), 0.5)
    gums = base.material("Gums", (0.05, 0.03, 0.03), 0.6)
    eyes = base.material("Eyes", (0.88, 0.90, 0.92), 0.1, emission=(0.85, 0.9, 0.95), strength=1.5)
    body, g, head = humanoid({
        "height": 2.3, "hunch": 0.32, "hips": 0.12, "waist": 0.08, "chest": 0.13, "neck": 0.045,
        "head": 0.11, "head_fwd": 0.12, "shoulders": 0.17, "arm": 0.026, "arm_len": 1.45, "leg": 0.04,
        "legs": False,
    })
    body.data.materials.append(skin)
    parts = [body]
    # The robe: a ragged bell from the shoulders to the ground, hood over the skull.
    bpy.ops.mesh.primitive_cone_add(vertices=14, radius1=0.42, radius2=0.14, depth=1.75, location=(0, 0.1, 0.875))
    cloak = bpy.context.active_object
    for i, v in enumerate(cloak.data.vertices):
        if v.co.z < -0.8:
            v.co.z += 0.12 * (i % 3) - 0.05  # ragged hem
            v.co.x *= 1.0 + 0.12 * ((i * 7) % 3 - 1)
    cloak.data.materials.append(robe)
    parts.append(cloak)
    hood = base.sphere("Hood", head + Vector((0, -0.04, 0.03)), 0.16, robe, 12)
    hood.scale = (1.0, 1.15, 1.05)
    parts.append(hood)
    face = base.sphere("Face", head + Vector((0, 0.07, -0.01)), 0.095, bone, 12)
    face.scale = (0.85, 0.7, 1.15)
    parts.append(face)
    parts.append(base.sphere("Mouth", head + Vector((0, 0.13, -0.07)), 0.035, gums, 8))
    for i in range(-3, 4):
        x = i * 0.011
        parts.append(base.cone(f"Tooth{i}", head + Vector((x, 0.145, -0.05)), head + Vector((x, 0.15, -0.105)), 0.006, bone, 4))
    for side in (-1, 1):
        parts.append(base.sphere(f"Eye{side}", head + Vector((side * 0.035, 0.12, 0.02)), 0.022, eyes, 10))
        hand = Vector(g.points[g.names[f"hd{side}"]])
        for f in range(4):
            b = hand + Vector(((f - 1.5) * 0.012, 0.03, -0.02))
            parts.append(base.cone(f"Nail{side}{f}", b, b + Vector((0, 0.07, -0.05)), 0.006, nails, 4))
    # Knobby spine through the robe's back.
    for i in range(6):
        t = i / 5.0
        parts.append(base.sphere(f"Spine{i}", (0, -0.02 + 0.35 * t, 1.45 + 0.55 * t), 0.035, skin, 6))
    obj = base.join(parts, "suriel")
    m = head + Vector((0, 0.13, -0.07))
    eyes_c = [head + Vector((side * 0.035, 0.12, 0.02)) for side in (-1, 1)]

    def grin(P, mat):
        # it "smiles" with that lipless mouth, the grey teeth horrifically large (ch14): the mouth
        # widens and everything below its middle stretches down, teeth and gums with it
        np = _np()
        reg = ((np.abs(P[:, 0]) < 0.07) & (P[:, 1] > head.y + 0.08) & (P[:, 2] > head.z - 0.14)
               & (P[:, 2] < head.z - 0.025) & (mat != "Robe") & (mat != "Eyes"))
        d = np.zeros_like(P)
        below = np.clip(m.z + 0.01 - P[:, 2], 0.0, None)
        d[:, 2] = -0.65 * below * reg
        d[:, 0] = 0.35 * P[:, 0] * reg
        return d

    def eyes_wide(P, mat):
        return _scale_islands(P, mat == "Eyes", eyes_c, 1.4)

    face_keys(obj, [("threat", grin), ("eyes_wide", eyes_wide)])
    base.export("suriel", [obj])


def naga():
    """Male humanoid with serpentine features: dark scales, amber eyes, razor
    teeth, forked silver tongue, powerful arms, black polished talons."""
    base.reset()
    scales = base.material("Scales", (0.06, 0.09, 0.07), 0.35)
    belly = base.material("Belly", (0.22, 0.24, 0.17), 0.5)
    talon = base.material("Talons", (0.01, 0.01, 0.01), 0.15)
    teeth = base.material("Teeth", (0.88, 0.86, 0.78), 0.3)
    tongue = base.material("Tongue", (0.75, 0.78, 0.82), 0.2)
    eyes = base.material("Eyes", (0.95, 0.62, 0.12), 0.1, emission=(0.95, 0.55, 0.1), strength=2.0)
    body, g, head = humanoid({
        "height": 1.95, "hunch": 0.12, "hips": 0.13, "waist": 0.11, "chest": 0.2, "neck": 0.075,
        "head": 0.1, "head_fwd": 0.08, "snout": 0.16, "shoulders": 0.25, "arm": 0.05, "arm_len": 1.15,
        "leg": 0.065, "knee_fwd": 0.06,
        "tail": [(0, -0.15, 0.85), (0, -0.4, 0.45), (0, -0.7, 0.12), (0, -1.05, 0.05)],
        "tail_r": [0.1, 0.08, 0.05, 0.015],
    })
    base.assign_regions(body, [scales, belly], 1.5, belly_y=(0.05, 0.4), belly_x=0.1)
    parts = [body]
    snout = Vector(g.points[g.names["snout"]])
    for side in (-1, 1):
        parts.append(base.sphere(f"Eye{side}", head + Vector((side * 0.065, 0.07, 0.03)), 0.022, eyes, 10))
        for t in range(3):
            b = snout + Vector((side * 0.03, -0.02 - t * 0.04, -0.03))
            parts.append(base.cone(f"Tooth{side}{t}", b, b + Vector((0, 0.005, -0.04)), 0.008, teeth, 4))
        hand = Vector(g.points[g.names[f"hd{side}"]])
        for f in range(4):
            b = hand + Vector(((f - 1.5) * 0.02, 0.03, -0.02))
            parts.append(base.cone(f"Talon{side}{f}", b, b + Vector((0, 0.08, -0.06)), 0.01, talon, 5))
    parts.append(base.cone("Tongue", snout + Vector((0, 0.06, -0.04)), snout + Vector((0, 0.16, -0.06)), 0.008, tongue, 4))
    # A ridge of scutes down the back of the skull and spine.
    for i in range(7):
        t = i / 6.0
        parts.append(base.cone(f"Scute{i}", (0, 0.08 - 0.25 * t, 1.75 - 0.6 * t), (0, 0.02 - 0.25 * t, 1.83 - 0.6 * t), 0.03, scales, 4))
    obj = base.join(parts, "naga")
    eyes_c = [head + Vector((side * 0.065, 0.07, 0.03)) for side in (-1, 1)]
    root_y = snout.y + 0.06

    def smile(P, mat):
        # "The creature smiled, a row of razor-sharp teeth" (ch14-15): the lower jaw drops away from
        # the teeth, which lengthen; the mouth's corners draw back
        np = _np()
        near = np.linalg.norm(P - np.array(tuple(snout)), axis=1) < 0.16
        jaw = near & (P[:, 2] < snout.z - 0.035) & (mat != "Teeth") & (mat != "Tongue") & (mat != "Eyes")
        d = np.zeros_like(P)
        hinge = np.clip((P[:, 1] - (snout.y - 0.12)) / 0.12, 0.3, 1.0)   # swings from the back of the jaw
        d[:, 2] -= 0.085 * hinge * jaw
        d[:, 1] -= 0.015 * jaw
        teeth = mat == "Teeth"
        d[:, 2] -= 0.5 * np.clip(snout.z - 0.03 - P[:, 2], 0.0, None) * teeth
        d[:, 0] += 0.25 * P[:, 0] * (near & (P[:, 2] < snout.z) & (mat != "Teeth"))
        return d

    def tongue_out(P, mat):
        # the silvery forked tongue darts out
        np = _np()
        t = (mat == "Tongue").astype(float)
        along = np.clip((P[:, 1] - root_y) / 0.10, 0.0, 1.0)
        d = np.zeros_like(P)
        d[:, 1] = (0.03 + 0.11 * along) * t
        d[:, 2] = -0.02 * along * t
        return d

    def eyes_wide(P, mat):
        return _scale_islands(P, mat == "Eyes", eyes_c, 1.3)

    face_keys(obj, [("threat", smile), ("tongue", tongue_out), ("eyes_wide", eyes_wide)])
    base.export("naga", [obj])


def attor():
    """Bony, leathery grey; pointed glistening face; bat ears; silver fangs;
    forked tongue; wings; slithering tail; clawed feet."""
    base.reset()
    hide = base.material("Hide", (0.30, 0.31, 0.32), 0.3)
    wing = base.material("Wing", (0.16, 0.15, 0.16), 0.6)
    fang = base.material("Fangs", (0.85, 0.87, 0.9), 0.1)
    claw = base.material("Claws", (0.05, 0.05, 0.05), 0.2)
    eyes = base.material("Eyes", (0.75, 0.82, 0.55), 0.1, emission=(0.7, 0.8, 0.45), strength=1.2)
    body, g, head = humanoid({
        "height": 1.75, "hunch": 0.28, "hips": 0.09, "waist": 0.07, "chest": 0.14, "neck": 0.04,
        "head": 0.085, "head_fwd": 0.1, "snout": 0.13, "shoulders": 0.18, "arm": 0.028, "arm_len": 1.3,
        "leg": 0.04, "knee_fwd": 0.1,
        "tail": [(0, -0.2, 0.7), (0, -0.55, 0.35), (0, -0.95, 0.08), (0, -1.35, 0.03)],
        "tail_r": [0.05, 0.035, 0.02, 0.006],
    })
    body.data.materials.append(hide)
    parts = [body]
    snout = Vector(g.points[g.names["snout"]])
    for side in (-1, 1):
        ear_b = head + Vector((side * 0.06, -0.02, 0.06))
        parts.append(base.cone(f"Ear{side}", ear_b, ear_b + Vector((side * 0.08, -0.04, 0.2)), 0.05, hide, 6))
        parts.append(base.sphere(f"Eye{side}", head + Vector((side * 0.05, 0.06, 0.02)), 0.017, eyes, 8))
        b = snout + Vector((side * 0.025, -0.01, -0.03))
        parts.append(base.cone(f"Fang{side}", b, b + Vector((0, 0.01, -0.07)), 0.009, fang, 4))
        for f in range(3):
            fb = Vector(g.points[g.names[f"ft{side}"]]) + Vector(((f - 1) * 0.025, 0.04, 0))
            parts.append(base.cone(f"Claw{side}{f}", fb, fb + Vector((0, 0.07, -0.02)), 0.01, claw, 4))
        # Wings: a membrane fan off the back, folded half-open.
        root = Vector((side * 0.08, 0.1, 1.42))
        verts = [root]
        for k in range(5):
            a = math.radians(20 + k * 28)
            verts.append(root + Vector((side * math.cos(a) * 0.95, -0.25 - 0.1 * k, math.sin(a) * 0.75 - 0.15)))
        mesh = bpy.data.meshes.new(f"Wing{side}")
        mesh.from_pydata([tuple(v) for v in verts], [], [(0, i, i + 1) for i in range(1, 5)])
        w = bpy.data.objects.new(f"Wing{side}", mesh)
        bpy.context.collection.objects.link(w)
        w.data.materials.append(wing)
        parts.append(w)
        for i in (1, 5):
            parts.append(base.cone(f"Finger{side}{i}", root, verts[i], 0.012, hide, 4))
    # The lower jaw, built shut and small inside the snout (unseen at rest): the roar swings it down off
    # the silver fangs, a dark maw lined with row after row of fangs.
    jaw_m = base.material("Jaw", (0.30, 0.31, 0.32), 0.3)
    maw_m = base.material("Maw", (0.22, 0.04, 0.06), 0.5)
    maw_f = base.material("MawFangs", (0.85, 0.87, 0.9), 0.1)
    hinge = Vector((0, head.y + 0.02, snout.z - 0.018))
    tip = Vector((0, snout.y - 0.015, hinge.z))
    parts.append(base.cone("Jaw", hinge, tip, 0.02, jaw_m, 8))
    parts.append(base.cone("Maw", hinge + Vector((0, 0, 0.012)), tip + Vector((0, -0.01, 0.007)), 0.014, maw_m, 8))
    for i in range(5):
        t = 0.3 + 0.15 * i
        at = hinge.lerp(tip, t)
        for xo, ln in ((0.014, 0.02), (0.006, 0.014)):
            for side in (-1, 1):
                fb = at + Vector((side * xo * (1.0 - 0.4 * t), 0, 0.012))
                parts.append(base.cone(f"MawFang{i}{side}{xo}", fb, fb + Vector((0, 0.004, ln)), 0.004, maw_f, 4))
    obj = decimated(base.join(parts, "attor"), 0.85)
    ears = [head + Vector((side * 0.06, -0.02, 0.06)) for side in (-1, 1)]

    def roar(P, mat):
        # "snout open in a roar, revealing row after row of fangs" (her painting, ch20 [C?]): the lower
        # snout swings down off the silver fangs
        np = _np()
        near = np.linalg.norm(P - np.array(tuple(snout)), axis=1) < 0.13
        chin = near & (P[:, 2] < snout.z - 0.02) & (mat == "Hide")
        d = np.zeros_like(P)
        d[:, 2] -= 0.015 * chin            # the throat gives a little; the jaw itself swings
        jaw = (mat == "Jaw") | (mat == "Maw") | (mat == "MawFangs")
        a = math.radians(45.0)
        rel = (P[jaw] - np.array(tuple(hinge))) * 1.75   # it unfolds far bigger than the snout could hide
        y = rel[:, 1] * math.cos(a) + rel[:, 2] * math.sin(a)
        z = -rel[:, 1] * math.sin(a) + rel[:, 2] * math.cos(a)
        d[jaw, 1] = y - rel[:, 1]
        d[jaw, 2] = z - rel[:, 2]
        return d

    def ears_back(P, mat):
        np = _np()
        d = np.zeros_like(P)
        for e in ears:
            near = (np.linalg.norm(P - np.array(tuple(e)), axis=1) < 0.25) & (P[:, 2] > e.z - 0.01) & (mat == "Hide")
            up = np.clip(P[:, 2] - e.z, 0.0, None)
            d[:, 1] -= 0.8 * up * near
            d[:, 2] -= 0.35 * up * near
        return d

    face_keys(obj, [("threat", roar), ("ears_back", ears_back)])
    base.export("attor", [obj])


def white_horse():
    """The beast's white horse (ch5): beautiful, calm, pale mane."""
    base.reset()
    spec = {
        "length": 2.3, "height": 1.6, "width": 0.55, "girth": 0.36, "hip": 0.98, "withers": 1.0,
        "waist": 0.95, "neck": 0.72, "neck_angle": math.radians(50), "head": 0.14, "snout": 0.38,
        "snout_drop": 0.55, "snout_r": 0.6, "ear": 0.14, "ear_back": 0.1, "leg": 0.07, "thigh": 1.6,
        "hock": 0.42, "thigh_fwd": 0.05, "eye": 0.18, "eye_fwd": 0.3, "belly_line": 0.75,
        "tail": {
            "points": lambda L, H, z: [(0, -0.45 * L, z * 0.96), (0, -0.52 * L, z * 0.7), (0, -0.54 * L, z * 0.45)],
            "radii": lambda r: [r * 0.22, r * 0.3, r * 0.2],
        },
    }
    coat = base.material("Coat", (0.96, 0.95, 0.93), 0.55)
    belly = base.material("Belly", (0.92, 0.91, 0.90), 0.6)
    eye = base.material("Eyes", (0.06, 0.04, 0.04), 0.05)
    hoof = base.material("Hoof", (0.35, 0.32, 0.3), 0.5)
    nose = base.material("Nose", (0.75, 0.68, 0.68), 0.5)
    body, g, head, snout = base.quadruped(spec)
    base.assign_regions(body, [coat, belly], spec["height"] * spec["belly_line"],
                        belly_y=(-0.3 * spec["length"], 0.3 * spec["length"]), belly_x=spec["width"] * 0.22)
    mane_mat = base.material("Mane", (0.86, 0.85, 0.88), 0.7)
    parts = [body]
    neck_base = Vector(g.points[g.names["shoulder"]])
    neck_top = Vector(g.points[g.names["neck"]])
    for i in range(9):
        t = i / 8.0
        p = neck_base.lerp(neck_top, t) + Vector((0, -0.06, 0.09))
        parts.append(base.sphere(f"Mane{i}", p, 0.085 - 0.025 * t, mane_mat, 8))
    tail = Vector(g.points[g.names["tail_2"]])
    parts.append(base.cone("TailHair", tail + Vector((0, 0.02, 0.35)), tail + Vector((0, -0.1, -0.45)), 0.09, mane_mat, 8))
    for side in (-1, 1):
        parts.append(base.sphere(f"Eye{side}", head + Vector((side * spec["head"] * 0.65, spec["head"] * 0.3, spec["head"] * 0.25)), 0.025, eye, 8))
        for key in ("fl", "hl"):
            paw = Vector(g.points[g.names[f"{key}{side}_3"]])
            parts.append(base.sphere(f"Hoof{key}{side}", paw + Vector((0, 0, 0.02)), 0.065, hoof, 8))
    parts.append(base.sphere("Muzzle", snout + Vector((0, 0.02, -0.02)), 0.07, nose, 10))
    base.export("white_horse", [base.join(parts, "white_horse")])


if __name__ == "__main__":
    suriel()
    naga()
    attor()
    white_horse()
