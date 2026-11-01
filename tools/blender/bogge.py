"""The Bogge, with headless Blender (bpy).

Run:  <venv with `pip install bpy`>/bin/python tools/blender/bogge.py [out_dir]
Out:  creatures/models/fae/bogge.gltf (feet at origin, facing -Z in Godot),
      skinned to a small rig with two clips: `idle` (a slow, too-deep breath
      and a head that twitches the wrong way) and `lunge` (it rises and reaches).

Canon (keeper, ch 9-12): the book never describes it. It has claws ("I will
grind your bones between my claws") and a bite; it is ancient, cold and only
real once looked at. Everything visible here is canon:"X": a thing of the
wood's own dark, bark-hided and gaunt, three metres if it stood, double-jointed
arms long enough to walk on, legs that bend backwards, claws like split
kindling, a long jaw of needle teeth, a cluster of lamp-pale eyes.

Materials are named so bogge.gd can find them: BoggeHide (body, rags),
BoggeBone (claws, teeth, spurs), BoggeEyes. In game they are replaced by the
bogge_form shader, which dissolves the whole form by `reveal`.
"""

import math
import os
import random
import sys

import bpy  # noqa: I001  (bpy must load before bmesh)
from mathutils import Quaternion, Vector

sys.path.insert(0, os.path.dirname(__file__))
import creatures as base  # noqa: E402  (shared helpers)
import creature_rig  # noqa: E402  (shared skinning)

base.OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..", "..", "creatures", "models", "fae")

UP = Vector((0, 0, 1))
FWD = Vector((0, 1, 0))
FPS = 30


def body_graph():
    """Skin-modifier body. y forward, z up. Returns the graph."""
    g = base.Graph()
    g.add("pelvis", (0, -0.12, 1.15), (0.2, 0.17))
    g.add("waist", (0, 0.08, 1.58), (0.14, 0.12), "pelvis")
    g.add("chest", (0, 0.4, 2.05), (0.32, 0.26), "waist")
    g.add("hump", (0, 0.42, 2.42), (0.3, 0.24), "chest")
    g.add("neck", (0, 0.82, 2.36), 0.085, "hump")
    g.add("head", (0, 1.12, 2.2), (0.18, 0.15), "neck")
    g.add("snout", (0, 1.58, 2.04), (0.11, 0.075), "head")
    g.add("jaw", (0, 1.52, 1.84), (0.08, 0.035), "head")
    for side in (-1, 1):
        g.add(f"sh{side}", (side * 0.42, 0.42, 2.3), 0.11, "hump")
        # Splayed up and out, then a second elbow that bends the wrong way.
        g.add(f"el{side}", (side * 0.98, 0.72, 2.12), 0.09, f"sh{side}")
        g.add(f"el2{side}", (side * 1.16, 1.12, 1.25), 0.085, f"el{side}")
        g.add(f"wr{side}", (side * 0.88, 1.5, 0.3), 0.065, f"el2{side}")
        g.add(f"hd{side}", (side * 0.86, 1.68, 0.08), (0.085, 0.03), f"wr{side}")
        # Legs: the knee folds backwards, the shin comes forward to the foot.
        g.add(f"hip{side}", (side * 0.22, -0.15, 1.08), 0.12, "pelvis")
        g.add(f"kn{side}", (side * 0.34, -0.62, 0.78), 0.09, f"hip{side}")
        g.add(f"an{side}", (side * 0.3, -0.22, 0.3), 0.05, f"kn{side}")
        g.add(f"ft{side}", (side * 0.3, 0.08, 0.04), (0.07, 0.028), f"an{side}")
    return g


def P(g, n):
    return Vector(g.points[g.names[n]])


def bark(obj):
    """Furrowed bark: noise stretched up the body, pushed along the normals."""
    tex = bpy.data.textures.new("Bark", "DISTORTED_NOISE")
    tex.noise_scale = 0.16
    tex.distortion = 1.1
    empty = bpy.data.objects.new("BarkSpace", None)
    bpy.context.collection.objects.link(empty)
    empty.scale = (1.0, 1.0, 4.5)
    mod = obj.modifiers.new("Bark", "DISPLACE")
    mod.texture = tex
    mod.texture_coords = "OBJECT"
    mod.texture_coords_object = empty
    mod.strength = 0.03
    mod.mid_level = 0.5
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier="Bark")
    bpy.data.objects.remove(empty)


def build_rig(g):
    data = bpy.data.armatures.new("Rig")
    arm = bpy.data.objects.new("Rig", data)
    bpy.context.collection.objects.link(arm)
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = arm
    arm.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    eb = data.edit_bones

    def bone(name, head, tail, parent, axis=UP):
        b = eb.new(name)
        b.head, b.tail = Vector(head), Vector(tail)
        b.align_roll(axis)
        if parent:
            b.parent = eb[parent]
        b.use_connect = False
        return b

    pel = P(g, "pelvis")
    bone("root", (0, 0, 0), (0, 0.4, 0), None)
    bone("body", pel, pel + Vector((0, 0.3, 0)), "root")
    bone("hips", P(g, "waist"), pel, "body")
    bone("spine", P(g, "waist"), P(g, "chest"), "body")
    bone("chest", P(g, "chest"), P(g, "hump"), "spine")
    bone("neck", P(g, "hump"), P(g, "neck"), "chest")
    bone("head", P(g, "neck"), P(g, "head"), "neck")
    bone("muzzle", P(g, "head"), P(g, "snout"), "head")
    bone("jaw", P(g, "head"), P(g, "jaw"), "head")
    for side, tag in ((-1, "l"), (1, "r")):
        bone(f"upper_arm_{tag}", P(g, f"sh{side}"), P(g, f"el{side}"), "chest", FWD)
        bone(f"lower_arm_{tag}", P(g, f"el{side}"), P(g, f"el2{side}"), f"upper_arm_{tag}", FWD)
        bone(f"fore_arm_{tag}", P(g, f"el2{side}"), P(g, f"wr{side}"), f"lower_arm_{tag}", FWD)
        bone(f"hand_{tag}", P(g, f"wr{side}"), P(g, f"hd{side}"), f"fore_arm_{tag}", FWD)
        bone(f"upper_leg_{tag}", P(g, f"hip{side}"), P(g, f"kn{side}"), "hips", FWD)
        bone(f"lower_leg_{tag}", P(g, f"kn{side}"), P(g, f"an{side}"), f"upper_leg_{tag}", FWD)
        bone(f"foot_{tag}", P(g, f"an{side}"), P(g, f"ft{side}"), f"lower_leg_{tag}", FWD)
    bpy.ops.object.mode_set(mode="OBJECT")
    return arm


def parts(g, bone_mat, eye_mat, hide):
    """Claws, teeth, bark spurs, eyes and rags, each riding one bone."""
    rnd = random.Random(13)
    out = []
    for side, tag in ((-1, "l"), (1, "r")):
        hand = P(g, f"hd{side}")
        for f in range(4):
            a = math.radians(-40 + f * 26) * side
            length = 0.62 + rnd.uniform(-0.08, 0.12)
            tip = hand + Vector((math.sin(a) * length, math.cos(a) * length, 0.12))
            root = hand + Vector((math.sin(a) * 0.05, 0.03, 0.01))
            out.append((base.cone(f"Claw{tag}{f}", root, tip, 0.035, bone_mat, 3), f"hand_{tag}"))
            # A splinter off each claw: split kindling.
            mid = root.lerp(tip, 0.45)
            out.append((base.cone(f"Split{tag}{f}", mid, mid + Vector((side * 0.06, 0.12, 0.03)), 0.01, bone_mat, 3), f"hand_{tag}"))
        foot = P(g, f"ft{side}")
        for f in range(3):
            a = math.radians(-25 + f * 25)
            tip = foot + Vector((math.sin(a) * 0.2, math.cos(a) * 0.2, -0.03))
            out.append((base.cone(f"Toe{tag}{f}", foot, tip, 0.018, bone_mat, 3), f"foot_{tag}"))
        # Broken-branch spurs at the wrong elbows.
        for j, bn in (("el", f"upper_arm_{tag}"), ("el2", f"fore_arm_{tag}")):
            p = P(g, f"{j}{side}")
            out.append((base.cone(f"Spur{j}{tag}", p, p + Vector((side * 0.16, -0.12, 0.22)), 0.035, hide, 4), bn))
    # Spurs along the spine and hump, like snapped branches.
    spine = [P(g, "waist"), P(g, "chest"), P(g, "hump"), P(g, "neck")]
    bones = ["spine", "spine", "chest", "neck"]
    for i in range(9):
        t = i / 8.0
        k = min(int(t * 3), 2)
        p = spine[k].lerp(spine[k + 1], t * 3 - k)
        r = 0.27 if k > 0 else 0.15
        root = p + Vector((rnd.uniform(-0.12, 0.12), -0.05, r * 0.8))
        tip = root + Vector((rnd.uniform(-0.15, 0.15), -rnd.uniform(0.1, 0.3), rnd.uniform(0.18, 0.42)))
        out.append((base.cone(f"BackSpur{i}", root, tip, 0.04, hide, 4), bones[min(k + (1 if t > 0.9 else 0), 3)]))
    # Needle teeth, upper and lower, too many and uneven.
    head, snout, jaw = P(g, "head"), P(g, "snout"), P(g, "jaw")
    for side in (-1, 1):
        for i in range(7):
            t = 0.1 + i * 0.13
            up = head.lerp(snout, t) + Vector((side * 0.07 * (1.1 - t * 0.5), 0, -0.06))
            out.append((base.cone(f"ToothU{side}{i}", up, up + Vector((0, 0.01, -0.08 - rnd.uniform(0, 0.05))), 0.012, bone_mat, 3), "muzzle"))
            lo = head.lerp(jaw, t) + Vector((side * 0.06 * (1.1 - t * 0.5), 0, 0.03))
            out.append((base.cone(f"ToothL{side}{i}", lo, lo + Vector((0, 0.01, 0.06 + rnd.uniform(0, 0.04))), 0.01, bone_mat, 3), "jaw"))
    # Eyes: a cluster where a face should be, none of them paired.
    face = head.lerp(snout, 0.35) + Vector((0, 0.04, 0.09))
    for i in range(11):
        c = face + Vector((rnd.uniform(-0.12, 0.12), rnd.uniform(-0.04, 0.05), rnd.uniform(-0.04, 0.09)))
        out.append((base.sphere(f"Eye{i}", c, rnd.uniform(0.012, 0.03), eye_mat, 8), "head"))
    # Rags of itself trailing off the back and arms into the fog.
    for i in range(7):
        anchor, bn = [(P(g, "hump"), "chest"), (P(g, "chest"), "spine"), (P(g, "waist"), "spine")][i % 3]
        root = anchor + Vector((rnd.uniform(-0.25, 0.25), -0.1, rnd.uniform(-0.1, 0.15)))
        out.append((rag(f"Rag{i}", root, rnd, hide), bn))
    return out


def rag(name, root, rnd, mat):
    """A torn strip hanging back and down, ragged at its end."""
    w = rnd.uniform(0.12, 0.22)
    length = rnd.uniform(0.7, 1.3)
    sway = rnd.uniform(-0.2, 0.2)
    verts, faces = [], []
    rows = 5
    for r in range(rows + 1):
        t = r / rows
        c = root + Vector((sway * t, -0.45 * length * t, -length * t))
        half = w * (1.0 - 0.6 * t) * 0.5
        verts += [tuple(c + Vector((-half, 0, 0))), tuple(c + Vector((half, 0, 0)))]
        if r:
            a = (r - 1) * 2
            faces.append((a, a + 1, a + 3, a + 2))
    # Tattered end: two points of different lengths.
    end = root + Vector((sway, -0.45 * length, -length))
    verts.append(tuple(end + Vector((-w * 0.15, -0.05, -0.18))))
    verts.append(tuple(end + Vector((w * 0.2, -0.08, -0.32))))
    n = rows * 2
    faces.append((n, n + 1, n + 3, n + 2))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    return obj


def key_clip(arm, name, frames, pose_at, loop=True):
    """Keys pose_at(t in 0..1) -> {bone: Quaternion} on its own NLA track."""
    ad = arm.animation_data or arm.animation_data_create()
    act = bpy.data.actions.new(name)
    ad.action = act
    for f in range(frames + 1):
        pose = pose_at(f / frames)
        for pb in arm.pose.bones:
            pb.rotation_mode = "QUATERNION"
            val = pose.get(pb.name)
            q, loc = val if isinstance(val, tuple) else (val or Quaternion(), None)
            pb.rotation_quaternion = q
            pb.keyframe_insert("rotation_quaternion", frame=f)
            if pb.name == "body":
                pb.location = loc if loc is not None else Vector()
                pb.keyframe_insert("location", frame=f)
    ad.action = None
    track = ad.nla_tracks.new()
    track.name = name
    strip = track.strips.new(name, 0, act)
    strip.name = name
    return act


def rot(axis, deg):
    return Quaternion(Vector(axis), math.radians(deg))


def idle_pose(t):
    """Four seconds: one breath too slow and too deep, the jaw working, and
    halfway through the head ticks sideways and stays wrong a moment."""
    breath = math.sin(t * 2 * math.pi)
    tick = creature_rig.pulse(t, 0.48, 0.5, 0.78)
    sway = math.sin(t * 2 * math.pi + 1.0)
    pose = {
        "spine": rot((1, 0, 0), 3 * breath),
        "chest": rot((1, 0, 0), -4 * breath),
        "neck": rot((1, 0, 0), 2 * breath),
        "head": rot((0, 1, 0), 28 * tick) @ rot((1, 0, 0), 4 * sway),
        "jaw": rot((1, 0, 0), 6 + 6 * max(0.0, math.sin(t * 4 * math.pi))),
    }
    for tag, s in (("l", -1), ("r", 1)):
        pose[f"upper_arm_{tag}"] = rot((1, 0, 0), 2 * breath * s)
        pose[f"hand_{tag}"] = rot((1, 0, 0), 8 * max(0.0, math.sin(t * 2 * math.pi + s)))
    return pose


def lunge_pose(t):
    """0.8 s: it rears up off its knuckles and reaches, jaw wide."""
    k = creature_rig.ease_out(min(1.0, t / 0.55))
    pose = {
        "body": (rot((1, 0, 0), 0), Vector((0, 0.0, 0.35 * k))),
        "spine": rot((1, 0, 0), -12 * k),
        "chest": rot((1, 0, 0), -10 * k),
        "neck": rot((1, 0, 0), 18 * k),
        "head": rot((1, 0, 0), 10 * k),
        "jaw": rot((1, 0, 0), 6 + 34 * k),
    }
    for tag in ("l", "r"):
        pose[f"upper_arm_{tag}"] = rot((1, 0, 0), -55 * k)
        pose[f"lower_arm_{tag}"] = rot((1, 0, 0), 25 * k)
        pose[f"fore_arm_{tag}"] = rot((1, 0, 0), -35 * k)
        pose[f"hand_{tag}"] = rot((1, 0, 0), -30 * k)
        pose[f"upper_leg_{tag}"] = rot((1, 0, 0), -14 * k)
    return pose


def bogge():
    base.reset()
    hide = base.material("BoggeHide", (0.032, 0.028, 0.026), 0.92)
    bone_mat = base.material("BoggeBone", (0.42, 0.39, 0.33), 0.55)
    eye_mat = base.material("BoggeEyes", (0.86, 0.9, 0.62), 0.1, emission=(0.86, 0.9, 0.62), strength=2.0)
    g = body_graph()
    body = g.build("Body")
    body.data.materials.append(hide)
    bark(body)
    arm = build_rig(g)
    creature_rig.weight_body(body, arm)
    extra = parts(g, bone_mat, eye_mat, hide)
    for obj, bn in extra:
        creature_rig.weight_rigid(obj, bn)
    model = base.join([body] + [o for o, _ in extra], "bogge")
    print("raw tris", base.tris([model]))
    model = decimate_to(model, 13500)
    creature_rig.skin(model, arm)
    key_clip(arm, "idle", 4 * FPS, idle_pose)
    key_clip(arm, "lunge", int(0.8 * FPS), lunge_pose)
    base.export("bogge", [model, arm])


def decimate_to(obj, budget):
    have = base.tris([obj])
    if have <= budget:
        return obj
    bpy.context.view_layer.objects.active = obj
    mod = obj.modifiers.new("Trim", "DECIMATE")
    mod.ratio = budget / have
    bpy.ops.object.modifier_apply(modifier="Trim")
    return obj


if __name__ == "__main__":
    bogge()
