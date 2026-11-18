"""The white mare's saddle (lane L47-8, docs/contracts/mare_bond.md): a proper
riding saddle in place of the flat seat baked into white_horse.gltf. It has a
dished seat that rises to a pommel at the front and a cantle at the back,
skirts down her flanks, a scalloped rose cloth under it, a girth, and stirrup
leathers with gold irons where Feyre's feet sit in the seat pose
(systems/mount/ride_pose.gd).

Run:  /opt/bpyenv/bin/python tools/blender/mare_saddle.py [out_dir]
Out:  systems/mount/models/mare_saddle.gltf (a prop, not a creature), in the white horse's
      own model space (feet at origin, facing -Z in Godot). The game hangs it
      on her `spine` bone (systems/mount/mare_saddle.gd) and takes it off for
      bareback.

It is fitted to her body: every surface is laid at a set height over her coat,
read from the imported white_horse.gltf rest pose, so nothing floats or sinks.
The game recolours surfaces by material name: SaddleCloth (the cloth slot),
Gold (the tack slot); SaddleSeat stays pearl leather. Props budget: under 3k
tris (R4). Smooth-shaded, the seat built with Subsurf.
"""

import math
import os
import sys

import bpy  # noqa: I001
import bmesh  # noqa: E402 (needs bpy first)
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import creatures as base  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, "..", ".."))
HORSE = os.path.join(REPO, "creatures", "models", "fae", "white_horse.gltf")
base.OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(REPO, "systems", "mount", "models")

# Blender space (x, -z, y) of the Godot model space. Her barrel's axis runs
# along y at this height; angles are measured from straight up toward +x.
AXIS_Z = 1.42
# The seat's lowest point (the saddle centre) along her back. Godot z -0.20.
CENTRE_Y = 0.20
# Stirrup irons: the tread under the ball of Feyre's foot in the seat pose
# (Godot (+-0.39, 1.26, -0.37), probed from RidePose on the shipped rig).
STIRRUP = Vector((0.39, 0.37, 1.26))
# Where the leathers hang from (under the skirt, at the saddle's bar).
BAR = (0.30, 41.0)  # (y, angle in degrees)


def mats():
    return {
        "cloth": base.material("SaddleCloth", (0.85, 0.58, 0.68), 0.75),
        "seat": base.material("SaddleSeat", (0.85, 0.78, 0.74), 0.45),
        "gold": base.material("Gold", (0.85, 0.70, 0.42), 0.3),
    }


class Coat:
    """Her coat's radius from the barrel axis, by (y, angle), from the rest mesh."""

    def __init__(self):
        bpy.ops.import_scene.gltf(filepath=HORSE)
        pts = []
        for o in list(bpy.context.scene.objects):
            if o.type != "MESH":
                continue
            dg = bpy.context.evaluated_depsgraph_get()
            ev = o.evaluated_get(dg)
            me = ev.to_mesh()
            names = [m.name if m else "" for m in o.data.materials]
            for poly in me.polygons:
                n = names[poly.material_index] if poly.material_index < len(names) else ""
                if n.startswith("Coat") or n.startswith("Belly"):
                    for vi in poly.vertices:
                        pts.append((o.matrix_world @ me.vertices[vi].co).copy())
            ev.to_mesh_clear()
        for o in list(bpy.context.scene.objects):
            bpy.data.objects.remove(o, do_unlink=True)
        # Drop her imported materials too, or ours come out as "SaddleCloth.001"
        # and the game can't find them by name.
        for m in list(bpy.data.materials):
            bpy.data.materials.remove(m)
        self.pts = [p for p in pts if -0.5 < p.y < 0.9 and p.z > 0.9]
        self.cache = {}

    def radius(self, y, ang):
        key = (round(y / 0.02), round(math.degrees(ang) / 4.0))
        if key in self.cache:
            return self.cache[key]
        best, half = 0.0, 0.035
        while best == 0.0 and half < 0.2:
            for p in self.pts:
                if abs(p.y - y) > half:
                    continue
                dx, dz = p.x, p.z - AXIS_Z
                a = math.atan2(dx, dz)
                if abs(a - ang) < math.radians(7):
                    best = max(best, math.hypot(dx, dz))
            half *= 1.6
        self.cache[key] = best or 0.36
        return self.cache[key]

    def smooth(self, y, ang):
        """The radius averaged over its neighbours, so rolls and hems run smooth."""
        rs = [self.radius(y + dy, ang + math.radians(da)) for dy in (-0.03, 0.0, 0.03) for da in (-6, 0, 6)]
        return sum(rs) / len(rs)

    def at(self, y, ang, lift):
        r = self.smooth(y, ang) + lift
        return Vector((math.sin(ang) * r, y, AXIS_Z + math.cos(ang) * r))


def smoothstep(e0, e1, x):
    t = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


def grid_object(name, rows, cols, point, m, close_u=False):
    """A mesh from a (rows+1) x (cols+1) grid of points point(i, j)."""
    me = bpy.data.meshes.new(name)
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    bm = bmesh.new()
    verts = [[bm.verts.new(point(i, j)) for j in range(cols + 1)] for i in range(rows + 1)]
    for i in range(rows):
        for j in range(cols if not close_u else cols):
            jn = j + 1
            bm.faces.new((verts[i][j], verts[i][jn], verts[i + 1][jn], verts[i + 1][j]))
    for f in bm.faces:
        f.smooth = True
    bm.normal_update()
    bm.to_mesh(me)
    bm.free()
    me.materials.append(m)
    return obj


def outward(obj):
    """Faces point away from her barrel axis (so they aren't culled)."""
    me = obj.data
    flip = 0
    for p in me.polygons:
        c = p.center
        out = Vector((c.x, 0.0, c.z - AXIS_Z))
        if p.normal.dot(out) < 0:
            flip += 1
    if flip > len(me.polygons) / 2:
        bm = bmesh.new()
        bm.from_mesh(me)
        bmesh.ops.reverse_faces(bm, faces=bm.faces[:])
        bm.to_mesh(me)
        bm.free()


def modify(obj, kind, **kw):
    mod = obj.modifiers.new(kind, kind)
    for k, v in kw.items():
        setattr(mod, k, v)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.ops.object.modifier_apply(modifier=mod.name)


def cloth(coat, m):
    """The rose saddle cloth: a rounded pad over her back, scalloped hem."""
    rows, cols = 10, 16
    y0, y1 = CENTRE_Y - 0.30, CENTRE_Y + 0.33
    amax = math.radians(68)

    def point(i, j):
        u = j / cols * 2 - 1          # -1..1 across her back
        v = i / rows                  # back to front
        # Rounded corners: the pad is shorter toward its lower edge.
        k = 1.0 - 0.32 * abs(u) ** 4
        y = CENTRE_Y + (y0 - CENTRE_Y) * k * (1 - v) + (y1 - CENTRE_Y) * k * v
        # Scallops along the hem (the lower edges on both sides).
        a = u * amax * (1 + (0.035 * math.cos(v * math.pi * 6) if abs(u) > 0.99 else 0.0))
        return coat.at(y, a, 0.012)

    obj = grid_object("SaddleCloth", rows, cols, point, m)
    outward(obj)
    modify(obj, "SOLIDIFY", thickness=0.012, offset=1.0)
    return obj


def seat_width(v):
    """Half-width of the seat (radians) from the back (v 0) to the front (v 1)."""
    return math.radians(36 - 12 * smoothstep(0.55, 1.0, v) - 4 * smoothstep(0.25, 0.0, v))


def seat_lift(v, u):
    """Height of the seat over her coat: dished in the middle, rising to the
    cantle at the back and the pommel at the front, curled up on the midline."""
    lift = 0.035 + 0.12 * smoothstep(0.32, 0.0, v) ** 1.4 + 0.10 * smoothstep(0.66, 1.0, v) ** 1.6
    lift += (0.02 * smoothstep(0.3, 0.0, v) + 0.015 * smoothstep(0.7, 1.0, v)) * (1 - abs(u))
    return lift - 0.012 * abs(u) ** 2


SEAT_Y = (CENTRE_Y - 0.25, CENTRE_Y + 0.27)


def seat(coat, m):
    """The seat: dished in the middle, a pommel rising at the front and a
    cantle at the back, the leather narrowing toward the pommel."""
    rows, cols = 7, 6
    y0, y1 = SEAT_Y

    def point(i, j):
        v = i / rows
        u = j / cols * 2 - 1
        return coat.at(y0 + (y1 - y0) * v, u * seat_width(v), seat_lift(v, u))

    obj = grid_object("SaddleSeat", rows, cols, point, m)
    outward(obj)
    modify(obj, "SOLIDIFY", thickness=0.03, offset=-1.0)
    modify(obj, "SUBSURF", levels=1, render_levels=1)
    return obj


def skirts(coat, m):
    """A leather skirt down each flank under the seat, rounded at the bottom."""
    parts = []
    rows, cols = 4, 5
    for side in (-1, 1):
        def point(i, j, side=side):
            v = i / rows
            u = j / cols
            a0, a1 = math.radians(26), math.radians(64)
            a = a0 + (a1 - a0) * u
            half = 0.17 * (1 - 0.45 * u ** 2)
            y = CENTRE_Y + 0.05 + (v * 2 - 1) * half
            return coat.at(y, side * a, 0.03)
        o = grid_object(f"Skirt{side}", rows, cols, point, m)
        outward(o)
        modify(o, "SOLIDIFY", thickness=0.012, offset=1.0)
        parts.append(o)
    return parts


def girth(coat, m):
    """The girth round her barrel, cloth edge to cloth edge underneath."""
    rows, cols = 1, 20
    y = CENTRE_Y + 0.04

    def point(i, j):
        a = math.radians(64) + (math.radians(296) - math.radians(64)) * j / cols
        return coat.at(y + (i - 0.5) * 0.06, a, 0.008)

    o = grid_object("Girth", rows, cols, point, m)
    outward(o)
    return o


def tube(name, pts, radius, m, sides=6):
    """A smooth tube through `pts` (for the gold rolls and the leathers)."""
    curve = bpy.data.curves.new(name, "CURVE")
    curve.dimensions = "3D"
    sp = curve.splines.new("POLY")
    sp.points.add(len(pts) - 1)
    for k, p in enumerate(pts):
        sp.points[k].co = (p.x, p.y, p.z, 1.0)
    curve.bevel_depth = radius
    curve.bevel_resolution = max(0, sides // 2 - 2)
    curve.use_fill_caps = True
    obj = bpy.data.objects.new(name, curve)
    bpy.context.scene.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.ops.object.convert(target="MESH")
    obj = bpy.context.view_layer.objects.active
    obj.data.materials.clear()
    obj.data.materials.append(m)
    obj.data.polygons.foreach_set("use_smooth", [True] * len(obj.data.polygons))
    return obj


def rolls(coat, m):
    """Gold piping along the seat's front (over the pommel) and back (the cantle) rims."""
    parts = []
    y0, y1 = SEAT_Y
    for v in (0.0, 1.0):
        pts = []
        for k in range(13):
            u = k / 12 * 2 - 1
            pts.append(coat.at(y0 + (y1 - y0) * v, u * seat_width(v), seat_lift(v, u) + 0.004))
        parts.append(tube("Roll", pts, 0.014, m))
    return parts


def stirrups(coat, leather, gold):
    """Leathers from the bar under each skirt down to a gold iron."""
    parts = []
    for side in (-1, 1):
        top = coat.at(BAR[0], side * math.radians(BAR[1]), 0.045)
        tread = Vector((side * STIRRUP.x, STIRRUP.y, STIRRUP.z))
        eye = tread + Vector((0, 0, 0.13))
        mid = top.lerp(eye, 0.5)
        mid.x += side * 0.02  # bellies out over the skirt and her barrel
        parts.append(tube(f"Leather{side}", [top, mid, eye], 0.011, leather, 4))
        # The iron: an arch over the foot and a flat tread, in the plane across her.
        arch = []
        for k in range(11):
            a = math.pi * k / 10
            arch.append(tread + Vector((math.cos(a) * 0.06, 0.0, 0.012 + math.sin(a) * 0.11)))
        parts.append(tube(f"Iron{side}", arch, 0.011, gold, 6))
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=tread)
        t = bpy.context.active_object
        t.name = f"Tread{side}"
        t.scale = (0.13, 0.06, 0.014)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        modify(t, "BEVEL", width=0.005, segments=1)
        t.data.materials.append(gold)
        parts.append(t)
    return parts


def main():
    base.reset()
    coat = Coat()
    m = mats()
    parts = [cloth(coat, m["cloth"]), seat(coat, m["seat"]), girth(coat, m["seat"])]
    parts += skirts(coat, m["seat"])
    parts += rolls(coat, m["gold"])
    parts += stirrups(coat, m["seat"], m["gold"])
    joined = base.join(parts, "mare_saddle")
    n = base.tris([joined])
    assert n <= 3000, f"mare_saddle: {n} tris over the 3k props budget"
    base.export("mare_saddle", [joined])


main()
