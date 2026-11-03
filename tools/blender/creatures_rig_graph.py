"""Skeletons for the creatures that had none (lane L61, render program T4).

The quadrupeds (wolves, deer, hare) are rigged by creature_rig.py and keep
their rigs and clips. This module gives every other creature model a real
Skeleton3D the same way: bones sit on the joints of the skin-modifier graph
each body was grown from, so the skeleton matches the mesh with no hand
rigging, and creature_rig's distance weights skin it. Separate parts (a
bird's Head and Wings, which the game swings) are bound rigidly to one bone.
No clips are authored here (T4 adds no animation): the rest pose is the
model exactly as before, so nothing in game moves differently.

Bone names: "root" at the origin, then one bone per graph edge named after
its child point ("body" becomes "torso", which creature_rig reserves as a
carrier), plus named extras: "head", "wing_l", "wing_r".
"""

import bpy
from mathutils import Vector

import creature_rig

UP = Vector((0, 0, 1))
FWD = Vector((0, 1, 0))
RENAME = {"body": "torso", "root": "root_g"}


def bone_name(point):
    return RENAME.get(point, point)


def armature(bones, name="Rig"):
    """bones: [(name, head, tail, parent or None)]. A "root" bone is added
    first. Returns the armature object."""
    data = bpy.data.armatures.new(name)
    arm = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(arm)
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = arm
    arm.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    eb = data.edit_bones
    root = eb.new("root")
    root.head, root.tail = Vector((0, 0, 0)), Vector((0, 0.1, 0))
    root.use_deform = False
    for n, head, tail, parent in bones:
        b = eb.new(n)
        b.head, b.tail = Vector(head), Vector(tail)
        if (b.tail - b.head).length < 1e-4:
            b.tail = b.head + Vector((0, 0.01, 0))
        b.align_roll(UP if abs((b.tail - b.head).normalized().z) < 0.9 else FWD)
        b.parent = eb[parent] if parent else root
        b.use_connect = False
        b.use_deform = True
    bpy.ops.object.mode_set(mode="OBJECT")
    arm.select_set(False)
    return arm


def graph_bones(g, prefix=""):
    """One bone per graph edge, parent point -> child point; bones whose
    parent point starts the graph hang off the root."""
    child_of = {}
    for a, b in g.edges:
        child_of[b] = a
    names = {i: n for n, i in g.names.items()}
    out = []
    for a, b in g.edges:
        parent = child_of.get(a)
        out.append((prefix + bone_name(names[b]), g.points[a], g.points[b],
                    prefix + bone_name(names[a]) if parent is not None else None))
    return out


def bind(obj, arm, bone=None):
    """Skins obj to arm: rigidly to `bone`, or by creature_rig's distance
    weights over every deforming bone."""
    if bone:
        creature_rig.weight_rigid(obj, bone)
    else:
        creature_rig.weight_body(obj, arm)
    creature_rig.skin(obj, arm)


def rig_graph(obj, g, extras=()):
    """A whole skin-graph body (and any parts joined into it): graph bones
    plus `extras` [(name, head, tail, parent)], distance-weighted."""
    arm = armature(graph_bones(g) + list(extras))
    bind(obj, arm)
    return arm


def rig_bird(body, g, head, head_pivot, wings):
    """Body, Head, WingL, WingR as separate objects (creatures/prey/bird.gd
    swings the head and wings): graph bones for the body, and a head bone and
    two wing bones the parts are bound to rigidly. wings: [(obj, root, tip)]."""
    hp = Vector(head_pivot)
    extras = [("head", hp, hp + Vector((0, 0.03, 0.04)), "torso")]
    for obj, root, tip in wings:
        side = "wing_l" if root[0] < 0 else "wing_r"
        extras.append((side, root, tip, "torso"))
    arm = armature(graph_bones(g) + extras)
    bind(body, arm)
    bind(head, arm, "head")
    for obj, root, _ in wings:
        bind(obj, arm, "wing_l" if root[0] < 0 else "wing_r")
    return arm


def rig_single(obj, length_axis=FWD):
    """A tiny flier (butterfly, faelight, water sprite): one deforming bone
    along its body, everything bound to it. The flutter shader does the flap."""
    lo = Vector([min(v.co[i] for v in obj.data.vertices) for i in range(3)])
    hi = Vector([max(v.co[i] for v in obj.data.vertices) for i in range(3)])
    c = (lo + hi) * 0.5
    half = max((hi - lo).dot(length_axis) * 0.5, 0.005)
    arm = armature([("torso", c - length_axis * half, c + length_axis * half, None)])
    bind(obj, arm, "torso")
    return arm
