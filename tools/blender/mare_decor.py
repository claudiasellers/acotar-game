"""Dress-up pieces for the white mare (lane L47-7, docs/contracts/mare_bond.md):
a garland of oversized blooms round her neck, ribbon bows down her mane and a
big bow at her tail. R3 princess dress-up [X]: nothing in the book.

Run:  /opt/bpyenv/bin/python tools/blender/mare_decor.py [out_dir]
Out:  creatures/models/fae/mare_decor/<piece>.gltf, each in the white horse's
      own model space (feet at origin, facing -Z in Godot), so the game hangs a
      piece on a bone of hers without any offset (systems/mount/mare_look.gd).

Each piece is fitted to her body: it reads the imported white_horse.gltf (rest
pose) and places blooms and bows just off her coat and mane. Tintable surfaces
use fixed material names the game recolours: DecorBloom, DecorRibbon (the
colour the player picked) and DecorLeaf, DecorHeart (kept). Props budget: each
piece under 3k tris (R4).
"""

import math
import os
import sys

import bpy  # noqa: I001
from mathutils import Vector, Matrix

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import creatures as base  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, "..", ".."))
HORSE = os.path.join(REPO, "creatures", "models", "fae", "white_horse.gltf")
base.OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(REPO, "creatures", "models", "fae", "mare_decor")

# Godot-space bone heads (feet at origin, -Z forward) from the horse's rig;
# Blender space is (x, -z, y).
NECK = Vector((0.0, 0.6075, 1.58))
HEAD = Vector((0.0, 1.0677, 2.2344))
TAIL0 = Vector((0.0, -0.63, 1.5642))
TAIL1 = Vector((0.0, -0.81, 1.5329))


def mats():
    return {
        "bloom": base.material("DecorBloom", (0.85, 0.66, 0.76), 0.55),
        "heart": base.material("DecorHeart", (0.85, 0.76, 0.5), 0.5),
        "leaf": base.material("DecorLeaf", (0.55, 0.74, 0.58), 0.6),
        "ribbon": base.material("DecorRibbon", (0.85, 0.62, 0.74), 0.35),
    }


def coat_points():
    """World-space rest vertices of her body and mane, from the shipped model."""
    bpy.ops.import_scene.gltf(filepath=HORSE)
    pts = []
    mane = []
    for o in list(bpy.context.scene.objects):
        if o.type != "MESH":
            continue
        dg = bpy.context.evaluated_depsgraph_get()
        ev = o.evaluated_get(dg)
        me = ev.to_mesh()
        names = [m.name if m else "" for m in o.data.materials]
        for poly in me.polygons:
            n = names[poly.material_index] if poly.material_index < len(names) else ""
            for vi in poly.vertices:
                p = o.matrix_world @ me.vertices[vi].co
                if n.startswith("Coat") or n.startswith("Belly"):
                    pts.append(p.copy())
                elif n.startswith("Mane"):
                    mane.append(p.copy())
        ev.to_mesh_clear()
    for o in list(bpy.context.scene.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    return pts, mane


def ring(points, centre, axis, half=0.035):
    """Points of the body's cross-section at `centre` across `axis`."""
    return [p for p in points if abs((p - centre).dot(axis)) < half]


def frame(axis):
    a = axis.normalized()
    up = Vector((0, 0, 1))
    side = a.cross(up)
    if side.length < 1e-4:
        side = Vector((1, 0, 0))
    side.normalize()
    top = side.cross(a).normalized()
    return a, side, top


def bloom(name, at, normal, size, m, parts):
    """A five-petal oversized bloom facing out along `normal`, with a heart."""
    n = normal.normalized()
    t = n.orthogonal().normalized()
    b = n.cross(t)
    for k in range(5):
        ang = k * 2 * math.pi / 5
        d = t * math.cos(ang) + b * math.sin(ang)
        p = base.sphere(f"{name}P{k}", at + d * size * 0.62 + n * size * 0.06, size * 0.5, m["bloom"], 6)
        _squash(p, n, 0.38)  # flatten each petal along the normal
        parts.append(p)
    parts.append(base.sphere(f"{name}H", at + n * size * 0.22, size * 0.3, m["heart"], 6))


def _squash(obj, axis, k):
    bpy.context.view_layer.update()
    a = axis.normalized()
    s = Matrix.Identity(3) + (k - 1.0) * Matrix((
        (a.x * a.x, a.x * a.y, a.x * a.z),
        (a.y * a.x, a.y * a.y, a.y * a.z),
        (a.z * a.x, a.z * a.y, a.z * a.z)))
    c = obj.matrix_world.translation.copy()
    me = obj.data
    for v in me.vertices:
        w = obj.matrix_world @ v.co
        v.co = obj.matrix_world.inverted() @ (c + s @ (w - c))


def leaf(name, at, along, out, size, m, parts):
    tip = at + along.normalized() * size
    lf = base.cone(name, at, tip, size * 0.32, m["leaf"], 6)
    _squash(lf, out, 0.35)
    parts.append(lf)


def bow(name, at, facing, up, size, m, parts, tails=True):
    """A ribbon bow: two looped lobes, a knot and two tails, facing out."""
    f = facing.normalized()
    u = up.normalized()
    s = u.cross(f).normalized()
    for side in (-1, 1):
        c = at + s * side * size * 0.55 + u * size * 0.08
        lobe = base.sphere(f"{name}L{side}", c, size * 0.5, m["ribbon"], 10)
        _squash(lobe, f, 0.42)
        _squash(lobe, u, 0.72)
        parts.append(lobe)
    parts.append(base.sphere(f"{name}K", at + f * size * 0.06, size * 0.2, m["ribbon"], 8))
    if tails:
        for side in (-1, 1):
            a = at - u * size * 0.1
            b = at - u * size * 1.15 + s * side * size * 0.38 + f * size * 0.05
            t = base.cone(f"{name}T{side}", a, b, size * 0.16, m["ribbon"], 6)
            _squash(t, f, 0.3)
            parts.append(t)


def garland(points, m):
    """Blooms and leaves round the base of her neck, just off the coat."""
    parts = []
    axis, side, top = frame(HEAD - NECK)
    centre = NECK.lerp(HEAD, 0.24)
    sec = ring(points, centre, axis)
    n = 10
    for k in range(n):
        ang = k * 2 * math.pi / n
        d = side * math.cos(ang) + top * math.sin(ang)
        # the coat's radius this way round (its farthest point within 18 degrees)
        r = 0.18
        for p in sec:
            v = p - centre
            v = v - axis * v.dot(axis)
            if v.length > 1e-4 and v.normalized().dot(d) > 0.95:
                r = max(r, v.length)
        at = centre + d * (r + 0.03)
        size = 0.075 if k % 2 == 0 else 0.06
        bloom(f"G{k}", at, d, size, m, parts)
        if k % 2 == 1:
            leaf(f"GL{k}", at - axis * 0.02, side * -math.sin(ang) + top * math.cos(ang), d, 0.09, m, parts)
    return parts


def mane_bows(points, mane, m):
    """Three bows down her crest, sitting on the mane."""
    parts = []
    axis, side, top = frame(HEAD - NECK)
    src = mane if mane else points
    for i, t in enumerate((0.36, 0.56, 0.76)):
        centre = NECK.lerp(HEAD, t)
        sec = ring(src, centre, axis, 0.05)
        best = centre + top * 0.25
        score = -1e9
        for p in sec:
            v = p - centre
            sc = v.dot(top) + 0.35 * v.dot(side)  # the top of the crest, to the side the mane falls
            if sc > score:
                score = sc
                best = p
        out = (best - centre)
        out = (out - axis * out.dot(axis)).normalized()
        bow(f"M{i}", best + out * 0.025, out, axis, 0.1 - i * 0.01, m, parts, tails=i == 0)
    return parts


def tail_bow(points, m):
    parts = []
    axis = (TAIL1 - TAIL0).normalized()
    at = TAIL0 + (TAIL1 - TAIL0) * 0.3 + Vector((0, 0, 0.12))
    back = Vector((0, -1, 0.35)).normalized()
    bow("T", at, back, Vector((0, 0, 1)), 0.17, m, parts)
    return parts


def main():
    base.reset()
    points, mane = coat_points()
    m = mats()
    pieces = {
        "mare_garland": garland(points, m),
        "mare_mane_bows": mane_bows(points, mane, m),
        "mare_tail_bow": tail_bow(points, m),
    }
    for name, parts in pieces.items():
        for o in parts:
            o.data.polygons.foreach_set("use_smooth", [True] * len(o.data.polygons))
        joined = base.join(parts, name)
        base.export(name, [joined])
        bpy.data.objects.remove(joined, do_unlink=True)


main()
