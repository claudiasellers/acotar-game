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
import creatures_rig_graph as rig  # noqa: E402
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
    arm = rig.rig_graph(obj, g)  # lane L61: graph skeleton, no clips
    base.export("attor", [obj, arm])


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
    # suriel() moved to tools/blender/monsters/suriel.py (L83: sculpted, baked, rigged, cloth chains, 14 clips)
    # naga() moved to tools/blender/monsters/naga.py (L83: sculpted, baked, rigged, 35 clips)
    attor()
    # white_horse() moved to tools/blender/white_mare.py (L47: one rigged horse for the ride north and the mount)
