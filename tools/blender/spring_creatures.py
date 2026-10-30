"""Spring Court ambient creatures, stylized for the court's look: rounded,
big-eyed, pastel. Headless Blender (bpy), deterministic.

Run:  <venv with `pip install bpy`>/bin/python tools/blender/spring_creatures.py [out_dir]
Out:  creatures/models/spring/<name>.gltf (feet at origin, facing -Z in Godot)

Butterfly and faelight are flat wings out along X on a thin body along Y;
the flutter shader flaps by distance from the body. No vertex colours:
the MultiMesh instance colour tints them. Horror creatures live in other generators; nothing
here should ever look frightening.
"""

import os
import sys

import bpy  # noqa: I001  (bpy must load before bmesh)
from mathutils import Vector

sys.path.insert(0, os.path.dirname(__file__))
import creatures as base  # noqa: E402  (shared helpers)

base.OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..", "..", "creatures", "models", "spring")


def eyes(head, head_r, side_x, fwd, up, size, objs, sparkle=True):
    """Big glossy eyes with a white catch-light: the appeal is in the eyes."""
    dark = base.material("EyeDark", (0.04, 0.03, 0.05), 0.08)
    shine = base.material("EyeShine", (1.0, 1.0, 1.0), 0.1, emission=(1, 1, 1), strength=0.6)
    for side in (-1, 1):
        c = head + Vector((side * head_r * side_x, head_r * fwd, head_r * up))
        objs.append(base.sphere(f"Eye{side}", c, head_r * size, dark, 12))
        if sparkle:
            objs.append(base.sphere(f"Shine{side}", c + Vector((side * head_r * size * 0.35, head_r * size * 0.7, head_r * size * 0.45)),
                                    head_r * size * 0.32, shine, 6))


def songbird(name, back, breast, cap, beak_rgb=(0.98, 0.72, 0.35)):
    """Chubby round songbird. Body, Head, WingL, WingR stay separate (Bird flaps them)."""
    base.reset()
    coat = base.material("Coat", back, 0.7)
    chest = base.material("Breast", breast, 0.7)
    crown = base.material("Cap", cap, 0.7)
    beak = base.material("Beak", beak_rgb, 0.4)
    g = base.Graph()
    g.add("tail", (0, -0.14, 0.13), (0.03, 0.006))
    g.add("rump", (0, -0.06, 0.12), 0.055, "tail")
    g.add("body", (0, 0.01, 0.12), 0.075, "rump")
    g.add("breast", (0, 0.05, 0.13), 0.07, "body")
    for side in (-1, 1):
        g.chain(f"leg{side}", "body", [(side * 0.02, 0.02, 0.05), (side * 0.02, 0.03, 0.004)], [0.007, 0.006])
    body = g.build("Body")
    base.assign_regions(body, [coat, chest], 0.2, belly_y=(-0.03, 0.2),
                        extra=lambda c, n, s: 1 if (c.y > 0.02 and n.y > 0.2 and c.z < 0.19) else s)
    head_c = Vector((0, 0.08, 0.21))
    parts = [base.sphere("HeadBall", head_c, 0.055, chest, 16)]
    parts.append(base.sphere("Crown", head_c + Vector((0, -0.01, 0.025)), 0.048, crown, 12))
    parts.append(base.cone("Beak", head_c + Vector((0, 0.045, -0.005)), head_c + Vector((0, 0.08, -0.012)), 0.013, beak, 8))
    eyes(head_c, 0.055, 0.55, 0.55, 0.15, 0.22, parts)
    head = base.join(parts, "Head")
    base.set_origin(head, (0, 0.07, 0.17))
    wings = []
    for side, label in ((-1, "WingL"), (1, "WingR")):
        w = base.Graph()
        w.add("root", (side * 0.06, 0.02, 0.15), (0.03, 0.01))
        w.add("mid", (side * 0.1, -0.03, 0.15), (0.035, 0.008), "root")
        w.add("tip", (side * 0.13, -0.08, 0.145), (0.015, 0.005), "mid")
        wing = w.build(label)
        wing.data.materials.append(crown)
        base.set_origin(wing, (side * 0.06, 0.02, 0.15))
        wings.append(wing)
    base.export(name, [body, head, *wings])


def rabbit():
    base.reset()
    fur = base.material("Coat", (0.93, 0.86, 0.80), 0.9)
    belly = base.material("Belly", (1.0, 0.97, 0.94), 0.9)
    pink = base.material("Pink", (1.0, 0.70, 0.78), 0.6)
    g = base.Graph()
    g.add("tail", (0, -0.2, 0.13), 0.05)
    g.add("hip", (0, -0.12, 0.14), 0.11, "tail")
    g.add("chest", (0, 0.02, 0.14), 0.09, "hip")
    for side in (-1, 1):
        g.chain(f"hind{side}", "hip", [(side * 0.08, -0.1, 0.07), (side * 0.07, -0.02, 0.015)], [0.06, (0.035, 0.018)])
        g.chain(f"fore{side}", "chest", [(side * 0.045, 0.06, 0.06), (side * 0.045, 0.08, 0.012)], [0.025, 0.02])
    body = g.build("Body")
    base.assign_regions(body, [fur, belly], 0.12, belly_y=(-0.15, 0.1), belly_x=0.05)
    head = Vector((0, 0.1, 0.25))
    parts = [body, base.sphere("Head", head, 0.085, fur, 16), base.sphere("Cheeks", head + Vector((0, 0.035, -0.03)), 0.06, belly, 12)]
    parts.append(base.sphere("Nose", head + Vector((0, 0.085, -0.01)), 0.014, pink, 8))
    parts.append(base.sphere("Puff", (0, -0.25, 0.16), 0.045, belly, 10))
    for side in (-1, 1):
        e = base.Graph()
        e.add("a", (side * 0.035, 0.08, 0.31), (0.022, 0.012))
        e.add("b", (side * 0.05, 0.06, 0.42), (0.03, 0.012), "a")
        e.add("c", (side * 0.06, 0.05, 0.5), (0.012, 0.008), "b")
        ear = e.build(f"Ear{side}")
        ear.data.materials.append(fur)
        parts.append(ear)
    eyes(head, 0.085, 0.55, 0.45, 0.2, 0.24, parts)
    base.export("rabbit", [base.join(parts, "rabbit")])


def lamb():
    """A cloud of a lamb: fleece lumps on a small body, a cream face."""
    base.reset()
    fleece = base.material("Coat", (0.99, 0.96, 0.92), 0.95)
    face = base.material("Face", (0.98, 0.86, 0.80), 0.8)
    hoof = base.material("Hoof", (0.55, 0.45, 0.48), 0.6)
    g = base.Graph()
    g.add("hip", (0, -0.18, 0.3), 0.16)
    g.add("chest", (0, 0.12, 0.32), 0.17, "hip")
    for side in (-1, 1):
        for name, y in (("f", 0.13), ("h", -0.17)):
            g.chain(f"{name}{side}", "chest" if name == "f" else "hip",
                    [(side * 0.09, y, 0.16), (side * 0.09, y, 0.03)], [0.04, 0.034])
    body = g.build("Body")
    body.data.materials.append(fleece)
    parts = [body]
    for i, (x, y, z, r) in enumerate([(x, y, z - 0.12, r) for (x, y, z, r) in [(0, -0.2, 0.55, 0.13), (0.1, -0.05, 0.56, 0.12), (-0.1, -0.05, 0.56, 0.12),
                                      (0, 0.1, 0.58, 0.13), (0.13, 0.12, 0.47, 0.1), (-0.13, 0.12, 0.47, 0.1),
                                      (0.14, -0.18, 0.46, 0.1), (-0.14, -0.18, 0.46, 0.1), (0, -0.3, 0.46, 0.09)]]):
        parts.append(base.sphere(f"Fleece{i}", (x, y, z), r, fleece, 10))
    head = Vector((0, 0.3, 0.5))
    parts.append(base.sphere("Head", head, 0.1, face, 16))
    parts.append(base.sphere("Muzzle", head + Vector((0, 0.07, -0.03)), 0.06, face, 12))
    parts.append(base.sphere("Topknot", head + Vector((0, -0.02, 0.08)), 0.06, fleece, 10))
    for side in (-1, 1):
        parts.append(base.sphere(f"Ear{side}", head + Vector((side * 0.12, -0.02, 0.02)), 0.035, face, 8))
    eyes(head, 0.1, 0.5, 0.55, 0.2, 0.2, parts)
    for side in (-1, 1):
        for y in (0.13, -0.17):
            parts.append(base.sphere(f"Hoof{side}{y}", (side * 0.09, y, 0.02), 0.032, hoof, 8))
    base.export("lamb", [base.join(parts, "lamb")])


def swan():
    base.reset()
    white = base.material("Coat", (0.99, 0.98, 0.96), 0.5)
    beak = base.material("Beak", (0.98, 0.55, 0.25), 0.4)
    black = base.material("Knob", (0.08, 0.07, 0.08), 0.4)
    g = base.Graph()
    g.add("tail", (0, -0.42, 0.18), (0.08, 0.04))
    g.add("body", (0, -0.12, 0.12), (0.22, 0.16), "tail")
    g.add("breast", (0, 0.18, 0.12), (0.17, 0.14), "body")
    # The S of the neck.
    g.chain("neck", "breast", [(0, 0.26, 0.3), (0, 0.22, 0.5), (0, 0.27, 0.66)], [0.05, 0.045, 0.045])
    g.add("head", (0, 0.34, 0.7), 0.05, "neck2")
    for side in (-1, 1):
        g.chain(f"wing{side}", "body", [(side * 0.15, -0.08, 0.19), (side * 0.1, -0.32, 0.22)], [(0.08, 0.04), (0.04, 0.025)])
    body = g.build("Body")
    body.data.materials.append(white)
    parts = [body, base.cone("Beak", (0, 0.37, 0.7), (0, 0.46, 0.67), 0.025, beak, 8),
             base.sphere("Knob", (0, 0.365, 0.715), 0.02, black, 8)]
    eyes(Vector((0, 0.34, 0.7)), 0.05, 0.75, 0.25, 0.15, 0.16, parts, sparkle=False)
    base.export("swan", [base.join(parts, "swan")])


def flier(name, wing_shape, body_len, body_r):
    """Flat wings (vertex red = distance from body) on a slim body, facing +Y."""
    base.reset()
    mat = base.material("Flier", (1, 1, 1), 0.6)
    verts, faces = [(0.0, 0.0, 0.0)], []
    for side in (-1, 1):
        start = len(verts)
        for (x, y) in wing_shape:
            verts.append((side * x, y, 0.0))
        n = len(wing_shape)
        for i in range(n - 1):
            faces.append((0, start + i, start + i + 1) if side > 0 else (0, start + i + 1, start + i))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    wings = bpy.data.objects.new("Wings", mesh)
    bpy.context.collection.objects.link(wings)
    wings.data.materials.append(mat)
    bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=body_r, depth=body_len, location=(0, 0, 0), rotation=(1.5708, 0, 0))
    body = bpy.context.active_object
    body.data.materials.append(mat)
    obj = base.join([wings, body], name)
    base.export(name, [obj])


def small_quadruped(name, spec, coat_rgb, belly_rgb, eye_rgb=(0.05, 0.04, 0.04), nose_rgb=(0.2, 0.12, 0.12),
                    extra=None):
    """Fox, cat, squirrel: the shared quadruped graph with stylized big eyes."""
    base.reset()
    coat = base.material("Coat", coat_rgb, 0.85)
    belly = base.material("Belly", belly_rgb, 0.85)
    nose = base.material("Nose", nose_rgb, 0.4)
    body, g, head, snout = base.quadruped(spec)
    base.assign_regions(body, [coat, belly], spec["height"] * spec.get("belly_line", 0.8),
                        belly_y=(-0.35 * spec["length"], 0.45 * spec["length"]), belly_x=spec["width"] * 0.3)
    parts = [body, base.sphere("Nose", snout + Vector((0, spec["head"] * 0.15, spec["head"] * 0.05)), spec["head"] * 0.14, nose, 8)]
    eyes(head, spec["head"], 0.55, spec.get("eye_fwd", 0.55), 0.25, spec.get("eye", 0.2), parts)
    if extra:
        extra(g, head, parts)
    base.export(name, [base.join(parts, name)])


def fox():
    spec = {
        "length": 0.9, "height": 0.42, "width": 0.22, "girth": 0.11, "waist": 0.85, "neck": 0.12,
        "neck_angle": 0.6, "head": 0.085, "snout": 0.11, "snout_drop": 0.2, "snout_r": 0.35, "ear": 0.11,
        "ear_back": 0.05, "leg": 0.022, "thigh": 1.9, "hock": 0.3, "eye": 0.2, "eye_fwd": 0.55, "belly_line": 0.75,
        "tail": {
            "points": lambda L, H, z: [(0, -0.5 * L, z * 0.85), (0, -0.7 * L, z * 0.6), (0, -0.85 * L, z * 0.45)],
            "radii": lambda r: [r * 0.6, r * 0.75, r * 0.35],
        },
    }

    def tip(g, head, parts):
        white = base.material("TailTip", (0.98, 0.96, 0.92), 0.85)
        t = Vector(g.points[g.names["tail_2"]])
        parts.append(base.sphere("TailTip", t, 0.04, white, 10))

    small_quadruped("fox", spec, (0.93, 0.48, 0.20), (0.99, 0.95, 0.9), extra=tip)


def cat():
    spec = {
        "length": 0.62, "height": 0.3, "width": 0.17, "girth": 0.08, "waist": 0.85, "neck": 0.06,
        "neck_angle": 0.9, "head": 0.075, "snout": 0.04, "snout_drop": 0.2, "snout_r": 0.6, "ear": 0.06,
        "ear_back": 0.0, "leg": 0.017, "thigh": 2.0, "hock": 0.3, "eye": 0.26, "eye_fwd": 0.6, "belly_line": 0.7,
        "tail": {
            "points": lambda L, H, z: [(0, -0.5 * L, z * 1.1), (0, -0.6 * L, z * 1.6), (0, -0.55 * L, z * 2.0)],
            "radii": lambda r: [r * 0.22, r * 0.2, r * 0.16],
        },
    }
    small_quadruped("cat", spec, (0.62, 0.60, 0.66), (0.95, 0.94, 0.96), nose_rgb=(1.0, 0.7, 0.75))


def squirrel():
    spec = {
        "length": 0.32, "height": 0.16, "width": 0.1, "girth": 0.05, "hip": 1.1, "withers": 0.9,
        "waist": 0.95, "neck": 0.03, "neck_angle": 0.9, "head": 0.04, "snout": 0.025, "snout_drop": 0.2,
        "snout_r": 0.6, "ear": 0.035, "ear_back": 0.0, "leg": 0.009, "thigh": 3.0, "hock": 0.25, "eye": 0.28,
        "eye_fwd": 0.5, "belly_line": 0.8,
        "tail": {
            "points": lambda L, H, z: [(0, -0.55 * L, z * 1.4), (0, -0.62 * L, z * 2.4), (0, -0.45 * L, z * 3.1)],
            "radii": lambda r: [r * 0.9, r * 1.2, r * 0.9],
        },
    }
    small_quadruped("squirrel", spec, (0.78, 0.32, 0.14), (0.99, 0.93, 0.85))


if __name__ == "__main__":
    songbird("songbird_blue", (0.52, 0.70, 0.95), (0.99, 0.88, 0.80), (0.42, 0.58, 0.92))
    songbird("songbird_rose", (0.88, 0.62, 0.70), (1.0, 0.86, 0.88), (0.95, 0.48, 0.62))
    songbird("songbird_gold", (0.97, 0.82, 0.42), (1.0, 0.95, 0.75), (0.30, 0.26, 0.28))
    rabbit()
    lamb()
    swan()
    songbird("lark", (0.62, 0.50, 0.38), (0.96, 0.90, 0.78), (0.52, 0.40, 0.30))
    songbird("hen", (0.98, 0.95, 0.90), (1.0, 0.97, 0.93), (0.92, 0.25, 0.25))
    songbird("owl", (0.62, 0.48, 0.34), (0.90, 0.82, 0.66), (0.55, 0.42, 0.30), beak_rgb=(0.35, 0.3, 0.25))
    songbird("hawk", (0.45, 0.33, 0.24), (0.92, 0.86, 0.76), (0.40, 0.30, 0.22), beak_rgb=(0.95, 0.8, 0.3))
    # Blighted Reaches crows are not cute: no catch-light in the eye.
    songbird("crow", (0.06, 0.06, 0.08), (0.08, 0.08, 0.1), (0.05, 0.05, 0.07), beak_rgb=(0.05, 0.05, 0.05))
    fox()
    cat()
    squirrel()
    # Rounded butterfly wings: forewing then hindwing outline, right side.
    flier("butterfly", [(0.0, 0.02), (0.03, 0.045), (0.055, 0.04), (0.065, 0.015), (0.05, -0.005),
                        (0.055, -0.03), (0.04, -0.05), (0.015, -0.04), (0.0, -0.015)], 0.05, 0.005)
    # Faelight: a tiny moth of light, small round wings.
    flier("faelight", [(0.0, 0.012), (0.018, 0.02), (0.028, 0.006), (0.024, -0.012), (0.01, -0.018), (0.0, -0.008)], 0.02, 0.004)
