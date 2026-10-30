"""Shared helpers for the manor prop and flora generators (headless bpy).

Every prop is one mesh: parts are built in small bmeshes, coloured per face
corner (COLOR_0, linear), tagged with a *finish* and appended into the prop's
bmesh. The finish travels in UV.x (see Prop.to_object) and the mesh has only
two materials, "opaque" and "clear": the contract with Godot
(world/spring_court/manor_estate/props/prop_finishes.gd), whose uber shader
shades every finish, so a room of props merges into two draw calls.

Finishes: matte, satin, fabric, gold, pearl, glass, mirror, glow, water, leaf.

Axes while modelling: Blender Z up, the prop's front faces +Y (Godot -Z after
export), base centre at the origin. fit() scales the result to the catalogue
size so the game's layouts and colliders stay exactly as they were.
Deterministic: randomness only from seeded random.Random.
"""

import math
import os
import re
import random

import bpy  # noqa: I001  (bpy must load before bmesh)
import bmesh
from mathutils import Matrix, Vector

FINISHES = ["matte", "satin", "fabric", "gold", "pearl", "glass", "mirror", "glow", "water", "leaf"]
CLEAR = ("glass", "water")
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))

# --------------------------------------------------------------- palette


def srgb(c):
    """sRGB 0..1 tuple -> linear (glTF vertex colours are linear)."""
    def ch(v):
        return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4
    return (ch(c[0]), ch(c[1]), ch(c[2]), c[3] if len(c) > 3 else 1.0)


def _kit_colors():
    path = os.path.join(ROOT, "world/spring_court/manor_estate/shared/estate_kit.gd")
    out = {}
    for m in re.finditer(r"const (\w+) := Color\(([^)]*)\)", open(path).read()):
        out[m.group(1)] = tuple(float(v) for v in m.group(2).split(","))
    return out


KIT = _kit_colors()
PEARL, MARBLE, WARM_STONE, STONE_DARK = KIT["PEARL"], KIT["MARBLE"], KIT["WARM_STONE"], KIT["STONE_DARK"]
OAK, OAK_DARK, GOLD, ROSE, BLUSH = KIT["OAK"], KIT["OAK_DARK"], KIT["GOLD"], KIT["ROSE"], KIT["BLUSH"]
CREAM, BUTTER, MINT, LILAC, PERI = KIT["CREAM"], KIT["BUTTER"], KIT["MINT"], KIT["LILAC"], KIT["PERIWINKLE"]
MOSS, HEDGE = KIT["MOSS"], KIT["HEDGE"]

# Experience bar §2.2 overrides: softer gilt, foliage in mint-sage (no lime),
# rose-taupe bark, soft blue for Rococo boiserie.
def hexc(h):
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (1, 3, 5))


GOLD = hexc("#E6C068")          # between gold lit #F2D27A and base #D4A94F
GOLD_DEEP = hexc("#D4A94F")
SOFT_BLUE = hexc("#C9DAF4")
BARK = hexc("#8E6A6E")
FAWN = hexc("#C9A98A")
SAGE_LIGHT, SAGE, SAGE_DEEP, SAGE_SHADOW = hexc("#B5E3C0"), hexc("#7CC29A"), hexc("#4F9A82"), hexc("#3E6F78")
COPPER = (0.93, 0.58, 0.40)
IRON = (0.52, 0.46, 0.62)        # lilac-tinted iron: never grey
STRAW = (1.0, 0.88, 0.55)
LEAF = SAGE
LEAF_DARK = SAGE_DEEP
FLAME = (1.0, 0.82, 0.45)
GLASS_TINT = (0.88, 0.95, 1.0, 0.35)
WHITE = (1.0, 0.99, 0.97)
CANVAS = (1.0, 0.96, 0.90)


def mix(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def lighter(c, t=0.3):
    return mix(c, (1.0, 1.0, 1.0), t)


def darker(c, t=0.25):
    return tuple(v * (1.0 - t) for v in c[:3])


def catalog():
    """id -> (category, (w, h, d), colour) parsed from prop_catalog.gd."""
    path = os.path.join(ROOT, "world/spring_court/manor_estate/props/prop_catalog.gd")
    out = {}
    pat = re.compile(r'&"(\w+)": \[&"(\w+)", Vector3\(([^)]*)\), (EstateKit\.(\w+)|Color\(([^)]*)\)), (true|false)\]')
    for m in pat.finditer(open(path).read()):
        size = tuple(float(v) for v in m.group(3).split(","))
        col = KIT[m.group(5)] if m.group(5) else tuple(float(v) for v in m.group(6).split(","))
        col = GOLD if m.group(5) == "GOLD" else col
        out[m.group(1)] = (m.group(2), size, col[:3])
    return out


# --------------------------------------------------------------- builder


class Prop:
    """Accumulates coloured, finished parts into one bmesh."""

    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        self.col = self.bm.loops.layers.float_color.new("Col")

    def add(self, part, color, finish="satin", matrix=None, smooth=True, sharp_deg=48.0):
        """Appends bmesh `part` (consumed) with one colour and finish."""
        if matrix is not None:
            part.transform(matrix)
        if smooth:
            for f in part.faces:
                f.smooth = True
            for e in part.edges:
                if e.is_manifold and e.calc_face_angle(0.0) > math.radians(sharp_deg):
                    e.smooth = False
        mi = FINISHES.index(finish)
        c = srgb(color)
        vmap = {}
        for v in part.verts:
            vmap[v] = self.bm.verts.new(v.co)
        for f in part.faces:
            try:
                nf = self.bm.faces.new([vmap[v] for v in f.verts])
            except ValueError:
                continue
            nf.material_index = mi
            nf.smooth = f.smooth
            for loop in nf.loops:
                loop[self.col] = c
        if smooth:
            # carry sharp edges across
            for e in part.edges:
                if not e.smooth:
                    a, b = vmap[e.verts[0]], vmap[e.verts[1]]
                    ne = self.bm.edges.get((a, b))
                    if ne:
                        ne.smooth = False
        part.free()
        return self

    def tris(self):
        return sum(len(f.verts) - 2 for f in self.bm.faces)

    def bounds(self):
        xs = [v.co for v in self.bm.verts]
        lo = Vector((min(v.x for v in xs), min(v.y for v in xs), min(v.z for v in xs)))
        hi = Vector((max(v.x for v in xs), max(v.y for v in xs), max(v.z for v in xs)))
        return lo, hi

    def fit(self, size):
        """Scales to catalogue (w, h, d) = Blender (x, z, y), base centre at origin."""
        lo, hi = self.bounds()
        ext = hi - lo
        w, h, d = size
        sx = w / max(ext.x, 1e-4)
        sy = d / max(ext.y, 1e-4)
        sz = h / max(ext.z, 1e-4)
        cx, cy = (lo.x + hi.x) / 2, (lo.y + hi.y) / 2
        m = Matrix.Diagonal((sx, sy, sz, 1.0)) @ Matrix.Translation((-cx, -cy, -lo.z))
        bmesh.ops.transform(self.bm, matrix=m, verts=self.bm.verts)
        return self

    def to_object(self, name=None):
        """Mesh with two materials, "opaque" and "clear" (glass, water); each
        corner's finish index rides in UV.x as (index + 0.5) / 16 so the game's
        uber shader shades every finish from one material (one draw call)."""
        me = bpy.data.meshes.new(name or self.name)
        self.bm.normal_update()
        self.bm.to_mesh(me)
        uv = me.uv_layers.new(name="finish")
        for poly in me.polygons:
            fi = poly.material_index
            for li in poly.loop_indices:
                uv.data[li].uv = ((fi + 0.5) / 16.0, 0.5)
            poly.material_index = 1 if FINISHES[fi] in CLEAR else 0
        me.materials.append(finish_material("opaque"))
        me.materials.append(finish_material("clear"))
        ob = bpy.data.objects.new(name or self.name, me)
        bpy.context.scene.collection.objects.link(ob)
        return ob


_mats = {}


def finish_material(name):
    if name in _mats and _mats[name].name in bpy.data.materials:
        return _mats[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    vc = nt.nodes.new("ShaderNodeVertexColor")
    vc.layer_name = "Col"
    nt.links.new(vc.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.4 if name == "opaque" else 0.05
    _mats[name] = m
    return m


def lod(ob, ratio=0.5):
    """LOD1 copy: collapse-decimated to ~ratio of the triangles."""
    me = ob.data.copy()
    lo = bpy.data.objects.new(ob.name + "_lod1", me)
    bpy.context.scene.collection.objects.link(lo)
    mod = lo.modifiers.new("dec", "DECIMATE")
    mod.decimate_type = "COLLAPSE"
    mod.ratio = ratio
    mod.use_collapse_triangulate = True
    dg = bpy.context.evaluated_depsgraph_get()
    ev = lo.evaluated_get(dg)
    new = bpy.data.meshes.new_from_object(ev)
    lo.modifiers.clear()
    lo.data = new
    return lo


def mesh_tris(ob):
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)


def export_glb(objs, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=path, use_selection=True, export_format="GLB", export_yup=True,
                              export_apply=True, export_materials="EXPORT", export_vertex_color="ACTIVE",
                              export_all_vertex_colors=False, export_texcoords=True, export_normals=True,
                              export_extras=False, export_cameras=False, export_lights=False)


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _mats.clear()


# --------------------------------------------------------------- primitives
# Each returns a fresh bmesh centred as documented; pass to Prop.add with a matrix.


def T(x=0.0, y=0.0, z=0.0):
    return Matrix.Translation((x, y, z))


def R(axis, deg):
    return Matrix.Rotation(math.radians(deg), 4, axis)


def S(x, y=None, z=None):
    return Matrix.Diagonal((x, x if y is None else y, x if z is None else z, 1.0))


def box(sx, sy, sz, bevel=0.0, seg=None):
    """Box centred at origin; optional rounded edges (2 segments from 3 cm up, else a chamfer)."""
    seg = seg if seg is not None else (2 if bevel >= 0.03 else 1)
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=(sx, sy, sz), verts=bm.verts)
    if bevel > 0.0:
        b = min(bevel, min(sx, sy, sz) * 0.49)
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=b, segments=seg, affect="EDGES", profile=0.5)
    return bm


def cyl(r, h, n=12, r2=None, caps=True):
    """Cylinder/cone from z=0 to z=h."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=caps, cap_tris=False, segments=n, radius1=r,
                          radius2=r if r2 is None else r2, depth=h)
    bmesh.ops.translate(bm, vec=(0, 0, h / 2), verts=bm.verts)
    return bm


def sphere(r, u=12, v=8):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=u, v_segments=v, radius=r)
    return bm


def ico(r, sub=1):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=r)
    return bm


def lathe(profile, n=12, cap_bottom=True, cap_top=True):
    """Surface of revolution about Z. profile = [(radius, z), ...] bottom to top."""
    bm = bmesh.new()
    rings = []
    for r, z in profile:
        ring = []
        if r < 1e-5:
            ring = [bm.verts.new((0, 0, z))]
        else:
            for i in range(n):
                a = 2 * math.pi * i / n
                ring.append(bm.verts.new((r * math.cos(a), r * math.sin(a), z)))
        rings.append(ring)
    for a, b in zip(rings, rings[1:]):
        if len(a) == 1 and len(b) == 1:
            continue
        for i in range(n):
            j = (i + 1) % n
            if len(a) == 1:
                bm.faces.new((a[0], b[i], b[j]))
            elif len(b) == 1:
                bm.faces.new((a[i], b[0], a[j]))
            else:
                bm.faces.new((a[i], a[j], b[j], b[i]))
    if cap_bottom and len(rings[0]) > 2:
        bm.faces.new(list(reversed(rings[0])))
    if cap_top and len(rings[-1]) > 2:
        bm.faces.new(rings[-1])
    return bm


def tube(points, radius, sides=6, closed=False, caps=True):
    """Sweeps a circle along points. radius: float or list per point."""
    pts = [Vector(p) for p in points]
    radii = radius if isinstance(radius, (list, tuple)) else [radius] * len(pts)
    bm = bmesh.new()
    count = len(pts)
    tangents = []
    for i in range(count):
        if closed:
            t = pts[(i + 1) % count] - pts[i - 1]
        else:
            t = pts[min(i + 1, count - 1)] - pts[max(i - 1, 0)]
        tangents.append(t.normalized() if t.length > 1e-6 else Vector((0, 0, 1)))
    ref = Vector((0, 0, 1)) if abs(tangents[0].z) < 0.9 else Vector((1, 0, 0))
    normal = tangents[0].cross(ref).normalized()
    rings = []
    for i in range(count):
        if i > 0:
            # parallel transport
            axis = tangents[i - 1].cross(tangents[i])
            if axis.length > 1e-6:
                ang = tangents[i - 1].angle(tangents[i])
                normal = (Matrix.Rotation(ang, 3, axis.normalized()) @ normal).normalized()
        binormal = tangents[i].cross(normal).normalized()
        ring = []
        for s in range(sides):
            a = 2 * math.pi * s / sides
            off = (normal * math.cos(a) + binormal * math.sin(a)) * radii[i]
            ring.append(bm.verts.new(pts[i] + off))
        rings.append(ring)
    seq = list(zip(rings, rings[1:]))
    if closed:
        seq.append((rings[-1], rings[0]))
    for a, b in seq:
        for s in range(sides):
            k = (s + 1) % sides
            bm.faces.new((a[s], a[k], b[k], b[s]))
    if caps and not closed:
        bm.faces.new(list(reversed(rings[0])))
        bm.faces.new(rings[-1])
    return bm


def torus(R_, r, n=16, sides=6):
    pts = [(R_ * math.cos(2 * math.pi * i / n), R_ * math.sin(2 * math.pi * i / n), 0) for i in range(n)]
    return tube(pts, r, sides, closed=True)


def arc_pts(cx, cz, rx, rz, a0, a1, n, y=0.0):
    """Points on an ellipse arc in the XZ plane (degrees)."""
    out = []
    for i in range(n + 1):
        a = math.radians(a0 + (a1 - a0) * i / n)
        out.append((cx + rx * math.cos(a), y, cz + rz * math.sin(a)))
    return out


def slab(outline, depth, bevel=0.0):
    """Extrudes a 2D outline [(x, z)] in the XZ plane along +Y by depth (centred on y=0)."""
    bm = bmesh.new()
    vs = [bm.verts.new((x, -depth / 2, z)) for x, z in outline]
    f = bm.faces.new(vs)
    bmesh.ops.recalc_face_normals(bm, faces=[f])
    if f.normal.y > 0:
        f.normal_flip()
    r = bmesh.ops.extrude_face_region(bm, geom=[f])
    nv = [g for g in r["geom"] if isinstance(g, bmesh.types.BMVert)]
    bmesh.ops.translate(bm, vec=(0, depth, 0), verts=nv)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    if bevel > 0:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bevel, segments=1, affect="EDGES", profile=0.5,
                        clamp_overlap=True)
    return bm


def arched_outline(w, h, n=8, arch=None):
    """Rectangle with a round arch on top, base at z=0."""
    arch = w / 2 if arch is None else arch
    pts = [(-w / 2, 0.0), (w / 2, 0.0)]
    top = h - arch
    for i in range(n + 1):
        a = math.pi * i / n
        pts.append((w / 2 * math.cos(a), top + arch * math.sin(a)))
    return pts


def oval_outline(w, h, n=16):
    return [(w / 2 * math.cos(2 * math.pi * i / n), h / 2 + h / 2 * math.sin(2 * math.pi * i / n)) for i in range(n)]


def frame_ring(outline, width, depth):
    """A moulded frame around an outline (list of (x, z)), as a closed tube."""
    return tube([(x, 0.0, z) for x, z in outline], [width] * len(outline), 6, closed=True)


def cushion(sx, sy, sz, puff=0.35, seg=2):
    """Plump rounded cushion centred at origin."""
    bm = box(sx, sy, sz, bevel=min(sx, sy, sz) * 0.45, seg=seg)
    hz = sz / 2
    for v in bm.verts:
        fx = 1 - (2 * v.co.x / sx) ** 2
        fy = 1 - (2 * v.co.y / sy) ** 2
        if abs(v.co.z) > hz * 0.3:
            v.co.z += math.copysign(max(fx, 0) * max(fy, 0) * sz * puff * 0.5, v.co.z)
    return bm


def turned_leg(h, r, n=8, style="baluster"):
    """Turned furniture leg, z=0..h."""
    if style == "taper":
        prof = [(r * 0.55, 0), (r * 0.7, 0.05 * h), (r, 0.85 * h), (r * 1.15, 0.9 * h), (r * 1.15, h)]
    else:
        prof = [(r * 0.55, 0), (r * 0.8, 0.06 * h), (r * 0.6, 0.12 * h), (r * 0.75, 0.4 * h),
                (r * 1.15, 0.55 * h), (r * 0.7, 0.72 * h), (r * 1.0, 0.85 * h), (r * 1.2, 0.92 * h), (r * 1.2, h)]
    return lathe(prof, n)


def cabriole(h, r, kick=1.0):
    """S-curved cabriole leg (outward knee at the top), along z=0..h, knee toward +X+Y."""
    k = r * 1.6 * kick
    pts = [(k * 0.25, k * 0.25, 0.0), (0, 0, h * 0.12), (-k * 0.15, -k * 0.15, h * 0.4),
           (k * 0.1, k * 0.1, h * 0.75), (k * 0.6, k * 0.6, h * 0.92), (k * 0.4, k * 0.4, h)]
    radii = [r * 0.9, r * 0.6, r * 0.75, r * 1.0, r * 1.3, r * 1.2]
    return tube(pts, radii, 6)


def scroll(r, turns=1.4, n=14, thick=0.01, y=0.0):
    """Flat volute scroll in the XZ plane (gilt curlicues)."""
    pts = []
    for i in range(n + 1):
        t = i / n
        a = t * turns * 2 * math.pi
        rr = r * (1 - 0.75 * t)
        pts.append((rr * math.cos(a), y, rr * math.sin(a)))
    return tube(pts, [thick * (1.0 - 0.5 * i / n) for i in range(n + 1)], 5)


def disc(r, n=12, z=0.0):
    bm = bmesh.new()
    vs = [bm.verts.new((r * math.cos(2 * math.pi * i / n), r * math.sin(2 * math.pi * i / n), z)) for i in range(n)]
    bm.faces.new(vs)
    return bm


# --------------------------------------------------------------- flowers


def petal(length, width, cup=0.3, curl=0.15):
    """A soft cupped petal along +X from the origin (2x2 quads)."""
    bm = bmesh.new()
    rows = []
    for i, t in enumerate((0.0, 0.5, 1.0)):
        w = width * (0.25, 1.0, 0.45)[i]
        z = cup * length * t * t + curl * length * (t ** 3)
        row = [bm.verts.new((length * t, -w / 2, z + cup * w * 0.5)),
               bm.verts.new((length * t, 0.0, z)),
               bm.verts.new((length * t, w / 2, z + cup * w * 0.5))]
        rows.append(row)
    for a, b in zip(rows, rows[1:]):
        bm.faces.new((a[0], a[1], b[1], b[0]))
        bm.faces.new((a[1], a[2], b[2], b[1]))
    return bm


def bloom(prop, center, radius, color, rings=3, per=5, rng=None, finish="fabric", tilt=None, heart=None):
    """Layered cupped bloom (rose/peony style) facing +Z, added straight to prop."""
    rng = rng or random.Random(1)
    c = Vector(center)
    base_m = T(*c) @ (tilt if tilt is not None else Matrix.Identity(4))
    for ring in range(rings):
        t = ring / max(rings - 1, 1)
        n = per + ring
        L = radius * (0.45 + 0.55 * t)
        lift = 60 - 45 * t                     # inner petals stand up, outer open out
        col = lighter(color, 0.18 * (1 - t)) if ring < rings - 1 else color
        for i in range(n):
            a = 360.0 * i / n + ring * 23 + rng.uniform(-8, 8)
            m = base_m @ R("Z", a) @ R("Y", -lift) @ T(0, 0, 0)
            prop.add(petal(L, L * 0.9, cup=0.35, curl=0.1 + 0.1 * t), col, finish, m)
    hc = heart or lighter(color, 0.35)
    prop.add(sphere(radius * 0.22, 6, 4), hc, finish, base_m @ T(0, 0, radius * 0.12))


def leaf(length, width):
    """Pointed leaf along +X, slightly folded."""
    bm = bmesh.new()
    a = bm.verts.new((0, 0, 0))
    b = bm.verts.new((length * 0.45, -width / 2, width * 0.12))
    c = bm.verts.new((length * 0.45, width / 2, width * 0.12))
    m = bm.verts.new((length * 0.5, 0, 0))
    tip = bm.verts.new((length, 0, -width * 0.1))
    bm.faces.new((a, m, b))
    bm.faces.new((a, c, m))
    bm.faces.new((b, m, tip))
    bm.faces.new((m, c, tip))
    return bm


def star_flower(prop, center, radius, color, n=5, finish="fabric", heart=BUTTER, facing=None):
    """Flat star flower (daisy, forget-me-not)."""
    m0 = T(*center) @ (facing if facing is not None else Matrix.Identity(4))
    for i in range(n):
        prop.add(petal(radius, radius * 0.6, cup=0.15, curl=-0.05), color, finish, m0 @ R("Z", 360 * i / n))
    prop.add(sphere(radius * 0.28, 6, 4), heart, finish, m0 @ S(1, 1, 0.6))
