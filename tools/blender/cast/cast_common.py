"""Helpers shared by the cast_<id> modules (imported before bpy is configured,
so anything Blender-side is looked up lazily)."""

import math
import sys

import numpy as np


def srgb(hexstr):
    h = hexstr.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    return tuple(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)


def bf():
    return sys.modules["build_feyre"]


def bh():
    return sys.modules["build_hair"]


def tris_line(obj):
    return "%-22s tris=%5d" % (obj.name, bf().tri_count(obj))


def tuck_behind_ears(st, depth=1.0):
    """Carve the hair away from High Fae ears so their points show."""
    import sdf
    for s in (1, -1):
        st.g.subtract(sdf.ellipsoid((0.096 * s, 0.024, 1.528), (0.015 * depth, 0.024, 0.046)), 0.006)


FINGER_BONES = ("Index", "Middle", "Ring", "Little", "Thumb")


def build_claws(ctx, length=0.032, curve=0.5, rgb=(0.012, 0.010, 0.012), name="Claws"):
    """A curved black claw at every fingertip, rigid on the distal bone.  Basis: retracted inside the
    fingertip; shape key `claws_out`: fully out (lore: they slide out when he's angry)."""
    import bmesh
    import bpy
    from mathutils import Vector
    B = bf()
    bm = bmesh.new()
    rest, out = [], []
    groups = []
    seg, sec = 7, 6
    for side in ("Left", "Right"):
        for f in FINGER_BONES:
            bone = ctx.arm.data.bones[side + f + "Distal"]
            tip = Vector(bone.tail_local)
            d = (bone.tail_local - bone.head_local).normalized()
            up = Vector((0, 0, 1))
            if f == "Thumb":
                up = (up - d * up.dot(d)).normalized()
            side_v = d.cross(up).normalized()
            k = 0.82 if f in ("Little", "Thumb") else 1.0
            L = length * k
            r0 = 0.0042 * k
            for state, scale in ((rest, 0.12), (out, 1.0)):
                ring_pts = []
                for i in range(seg + 1):
                    t = i / seg
                    a = curve * t * t * 1.2
                    p = tip - d * 0.007 + up * 0.0025 + (d * math.cos(a) * t - up * math.sin(a) * t) * L * scale
                    r = r0 * (1.0 - t) ** 0.8 + 0.0002
                    fwd = (d * math.cos(a) - up * math.sin(a)).normalized()
                    upn = fwd.cross(side_v).normalized() * -1
                    ring = [p + (side_v * math.cos(2 * math.pi * j / sec) * r * 0.75
                                 + upn * math.sin(2 * math.pi * j / sec) * r) for j in range(sec)]
                    ring_pts.append(ring)
                state.append(ring_pts)
            groups.append(side + f + "Distal")
    vid = []
    for rings in rest:
        vs = [[bm.verts.new(p) for p in ring] for ring in rings]
        vid.append(vs)
        for i in range(seg):
            for j in range(sec):
                a, b = vs[i][j], vs[i][(j + 1) % sec]
                c, e = vs[i + 1][(j + 1) % sec], vs[i + 1][j]
                bm.faces.new((a, b, c, e))
        bm.faces.new(list(reversed(vs[0])))
    bm.normal_update()
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    me.materials.append(B.make_material("claws", rgb, 0.18))
    for p in me.polygons:
        p.use_smooth = True
    per = (seg + 1) * sec
    for k, gname in enumerate(groups):
        g = obj.vertex_groups.get(gname) or obj.vertex_groups.new(name=gname)
        g.add(list(range(k * per, (k + 1) * per)), 1.0, "REPLACE")
    B.skin_to_armature(obj, ctx.arm)
    obj.shape_key_add(name="Basis", from_mix=False)
    sk = obj.shape_key_add(name="claws_out", from_mix=False)
    P = np.array([p for rings in out for ring in rings for p in ring])
    sk.data.foreach_set("co", P.ravel())
    sk.value = 0.0
    B.ensure_uvs(obj)
    return obj
