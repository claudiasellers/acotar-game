"""Small modelling kit for the forage pickups (headless bpy).

Every pickup is one mesh: parts are built as little bmeshes, painted per face
corner into a "Col" attribute (linear colour) and merged.  Two materials:
"forage_vcol" (vertex colour, soft satin) and "forage_glow" (vertex colour,
emissive) for the few things that shine (glowcap, starmoss, faelight seeds).
Shading is smooth: the R3 look is round and soft, not faceted.

Axes: Blender Z up, base centre on the origin (the ground), exported Y up.
Deterministic: randomness only from the seeded random.Random in K.rng.
"""

import math
import random

import bpy  # noqa: F401  (must load before bmesh)
import bmesh
from mathutils import Matrix, Vector


def lin(h):
    """'#rrggbb' sRGB -> linear rgba."""
    h = h.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    return tuple(v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4 for v in c) + (1.0,)


def mix(a, b, t):
    a, b = (lin(a) if isinstance(a, str) else a), (lin(b) if isinstance(b, str) else b)
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3)) + (1.0,)


def _c(c):
    return lin(c) if isinstance(c, str) else c


def frame(d):
    """Orthonormal (side, up2, d) around direction d."""
    d = Vector(d).normalized()
    ref = Vector((0, 0, 1)) if abs(d.z) < 0.95 else Vector((1, 0, 0))
    s = d.cross(ref).normalized()
    return s, s.cross(d).normalized() * -1.0, d


class K:
    def __init__(self, seed=1):
        self.bm = bmesh.new()
        self.col = self.bm.loops.layers.float_color.new("Col")
        self.rng = random.Random(seed)

    # -------------------------------------------------------------- core
    def _merge(self, tmp, color, glow=False, grad=None):
        """Append bmesh `tmp`; color is a colour or fn(face_centre)->colour; grad=(c2, z0, z1) blends by height."""
        vmap = {}
        for v in tmp.verts:
            vmap[v] = self.bm.verts.new(v.co)
        for f in tmp.faces:
            try:
                nf = self.bm.faces.new([vmap[v] for v in f.verts])
            except ValueError:
                continue
            nf.smooth = True
            nf.material_index = 1 if glow else 0
            for lp in nf.loops:
                c = color(lp.vert.co) if callable(color) else _c(color)
                if grad is not None:
                    c2, z0, z1 = grad
                    t = min(max((lp.vert.co.z - z0) / max(z1 - z0, 1e-6), 0.0), 1.0)
                    c = mix(c, _c(c2), t)
                lp[self.col] = c
        tmp.free()

    def jit(self, c, amt=0.07):
        c = _c(c)
        k = 1.0 + self.rng.uniform(-amt, amt)
        return (min(c[0] * k, 1), min(c[1] * k, 1), min(c[2] * k, 1), 1.0)

    def tris(self):
        return sum(len(f.verts) - 2 for f in self.bm.faces)

    # -------------------------------------------------------------- primitives
    def ell(self, c, r, color, seg=(10, 6), rot=None, glow=False, grad=None, squash_bottom=None):
        """Ellipsoid at c with radii r=(rx,ry,rz) (or scalar); rot: Matrix (3x3) or direction for +Z."""
        tmp = bmesh.new()
        bmesh.ops.create_uvsphere(tmp, u_segments=seg[0], v_segments=seg[1], radius=1.0)
        r = (r, r, r) if isinstance(r, (int, float)) else r
        R = _rot(rot)
        for v in tmp.verts:
            p = Vector((v.co.x * r[0], v.co.y * r[1], v.co.z * r[2]))
            if squash_bottom is not None and p.z < -r[2] * squash_bottom:
                p.z = -r[2] * squash_bottom
            v.co = Vector(c) + R @ p
        if grad is not None and len(grad) == 2:
            grad = (grad[0], c[2] - r[2] * 0.2 if not rot else c[2], c[2] + r[2])
        self._merge(tmp, color, glow, grad)

    def tube(self, pts, radii, color, sides=6, cap=True, glow=False, grad=None):
        pts = [Vector(p) for p in pts]
        n = len(pts)
        radii = radii if isinstance(radii, (list, tuple)) else [radii] * n
        tmp = bmesh.new()
        rings = []
        prev_side = None
        for i, p in enumerate(pts):
            d = (pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]).normalized()
            s, u, _ = frame(d)
            if prev_side is not None and s.dot(prev_side) < 0:
                s, u = -s, -u
            prev_side = s
            rings.append([tmp.verts.new(p + (s * math.cos(a) + u * math.sin(a)) * radii[i])
                          for a in (2 * math.pi * k / sides for k in range(sides))])
        for i in range(n - 1):
            for k in range(sides):
                tmp.faces.new((rings[i][k], rings[i][(k + 1) % sides], rings[i + 1][(k + 1) % sides], rings[i + 1][k]))
        if cap:
            if radii[0] > 1e-5:
                tmp.faces.new(list(reversed(rings[0])))
            if radii[-1] > 1e-5:
                tmp.faces.new(rings[-1])
        self._merge(tmp, color, glow, grad)

    def curve(self, a, b, bend=(0, 0, 0), n=6):
        """Quadratic curve a->b bulging by `bend` at the middle."""
        a, b, m = Vector(a), Vector(b), (Vector(a) + Vector(b)) * 0.5 + Vector(bend)
        return [a * (1 - t) ** 2 + m * 2 * t * (1 - t) + b * t * t for t in (i / (n - 1) for i in range(n))]

    def stem(self, a, b, r, color="#5E8A45", bend=(0, 0, 0), n=5, sides=5, tip=None):
        pts = self.curve(a, b, bend, n)
        radii = [r * (1.0 - 0.45 * i / (n - 1)) for i in range(n)] if tip is None else \
            [r + (tip - r) * i / (n - 1) for i in range(n)]
        self.tube(pts, radii, color, sides)
        return pts

    def cone(self, base, d, length, r0, r1, color, sides=8, glow=False, grad=None):
        base, d = Vector(base), Vector(d).normalized()
        self.tube([base, base + d * length], [r0, r1], color, sides, glow=glow, grad=grad)

    def leaf(self, base, d, length, width, color, up=(0, 0, 1), cup=0.25, fold=0.3, n=5, tip_c=None, shape="oval"):
        """Double-sided leaf blade with a soft midrib fold and cupping."""
        base, d = Vector(base), Vector(d).normalized()
        up = Vector(up)
        side = d.cross(up)
        if side.length < 1e-4:
            side = d.cross(Vector((1, 0, 0)))
        side.normalize()
        nrm = side.cross(d).normalized()
        if nrm.dot(up) < 0:
            nrm = -nrm
        tmp = bmesh.new()
        rows = []
        for i in range(n + 1):
            t = i / n
            if shape == "heart":
                w = width * (math.sin(math.pi * min(t * 1.15, 1.0)) ** 0.6) * (1.0 - 0.25 * t)
            elif shape == "lance":
                w = width * math.sin(math.pi * t) ** 0.8 * (1.0 - 0.3 * t)
            elif shape == "round":
                w = width * math.sin(math.pi * t) ** 0.5
            else:
                w = width * math.sin(math.pi * t) ** 0.7
            droop = -cup * length * t * t
            c = base + d * length * t + nrm * droop
            rows.append([c - side * w + nrm * w * fold, c + nrm * w * 0.05, c + side * w + nrm * w * fold])
        _two_sided(tmp, rows, nrm * 0.0006)
        g = None if tip_c is None else (tip_c, min(base.z, (base + d * length).z), max(base.z, (base + d * length).z) + 1e-4)
        self._merge(tmp, color, False, g)

    def petal_ring(self, c, nrm, r, n, color, cup=0.35, width=0.55, heart=None, heart_r=None, glow=False, tilt=0.0):
        """A flower head: n rounded petals around c facing nrm."""
        c, nrm = Vector(c), Vector(nrm).normalized()
        s, u, _ = frame(nrm)
        for k in range(n):
            a = 2 * math.pi * k / n + tilt
            d = (s * math.cos(a) + u * math.sin(a))
            pd = (d + nrm * cup).normalized()
            self.leaf(c, pd, r, r * width, color, up=nrm, cup=-cup * 0.3, fold=0.15, n=4, shape="round")
        if heart is not None:
            self.ell(c + nrm * r * 0.08, heart_r or r * 0.28, heart, seg=(8, 5), glow=glow)

    def bell(self, top, d, r, length, color, flare=1.25, sides=8, lip=None):
        """Hanging bell flower opening along d."""
        top, d = Vector(top), Vector(d).normalized()
        pts = [top + d * length * t for t in (0, 0.25, 0.6, 0.9, 1.0)]
        radii = [r * 0.35, r * 0.85, r, r * flare * 0.95, r * flare]
        self.tube(pts, radii, color, sides, cap=False, grad=None if lip is None else (lip, min(p.z for p in pts),
                                                                                     max(p.z for p in pts) + 1e-4))
        self.ell(pts[0], r * 0.4, color, seg=(6, 4))

    def pebble(self, c, r, color, seed_jit=0.18, seg=(10, 7), flat=0.55, grad=None):
        tmp = bmesh.new()
        bmesh.ops.create_uvsphere(tmp, u_segments=seg[0], v_segments=seg[1], radius=1.0)
        phase = self.rng.uniform(0, 6.28)
        r = (r, r, r) if isinstance(r, (int, float)) else r
        for v in tmp.verts:
            p = v.co.copy()
            k = 1.0 + seed_jit * (math.sin(3 * p.x + phase) * math.cos(2 * p.y + phase) * 0.6
                                  + 0.4 * math.sin(4 * p.z - phase))
            q = Vector((p.x * r[0] * k, p.y * r[1] * k, p.z * r[2] * k))
            if q.z < -r[2] * flat:
                q.z = -r[2] * flat
            v.co = Vector(c) + q + Vector((0, 0, r[2] * flat))
        self._merge(tmp, color, False, grad)

    def feather(self, base, d, length, width, vane, shaft="#EDE6D8", bars=None, curl=0.12, up=(0, 0, 1)):
        """A flight feather lying along d: shaft + two vanes, optional colour bars (list of (t, colour))."""
        base, d, up = Vector(base), Vector(d).normalized(), Vector(up)
        side = d.cross(up).normalized()
        nrm = side.cross(d).normalized()
        if nrm.dot(up) < 0:
            nrm = -nrm
        n = 9
        tmp = bmesh.new()
        rows = []
        for i in range(n + 1):
            t = i / n
            c = base + d * length * t + nrm * curl * length * t * t
            wl = width * (math.sin(math.pi * min(t * 1.05, 1.0)) ** 0.5) * (0.0 if t < 0.12 else 1.0)
            wr = wl * 0.62
            rows.append([c - side * wl + nrm * wl * 0.04, c + nrm * 0.0015, c + side * wr + nrm * wr * 0.04])
        _two_sided(tmp, rows, nrm * 0.0006)

        def paint(p, _b=base, _d=d, _bars=bars, _vane=vane, _L=length):
            if not _bars:
                return _c(_vane)
            t = (p - _b).dot(_d) / _L
            col = _c(_vane)
            for t0, t1, cc in _bars:
                if t0 <= t <= t1:
                    col = _c(cc)
            return col
        self._merge(tmp, paint)
        self.tube([base - d * 0.02, base + d * length * 0.98 + nrm * curl * length], [0.0028, 0.0012], shaft, 4)

    def ring_scatter(self, n, r0, r1, seed_off=0.0):
        """n points around the origin (x, y, yaw) for clustering small things."""
        out = []
        for k in range(n):
            a = 2 * math.pi * (k / n) + seed_off + self.rng.uniform(-0.35, 0.35)
            rr = r0 + (r1 - r0) * self.rng.random()
            out.append((math.cos(a) * rr, math.sin(a) * rr, a))
        return out

    # -------------------------------------------------------------- finish
    def to_object(self, name):
        bmesh.ops.remove_doubles(self.bm, verts=self.bm.verts, dist=1e-5)
        self.bm.normal_update()
        me = bpy.data.meshes.new(name)
        self.bm.to_mesh(me)
        self.bm.free()
        me.color_attributes.active_color = me.color_attributes["Col"]
        me.color_attributes.render_color_index = 0
        me.materials.append(material(False))
        me.materials.append(material(True))
        ob = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(ob)
        return ob


def _two_sided(tmp, rows, off):
    """A strip of quads from rows of 3 points, plus a back copy offset by -off with reversed winding."""
    for sign in (1, -1):
        vs = [[tmp.verts.new(p - off * (0 if sign > 0 else 1)) for p in r] for r in rows]
        for i in range(len(vs) - 1):
            a, b = vs[i], vs[i + 1]
            for k in range(2):
                q = (a[k], a[k + 1], b[k + 1], b[k])
                tmp.faces.new(q if sign > 0 else tuple(reversed(q)))


def _rot(rot):
    if rot is None:
        return Matrix.Identity(3)
    if isinstance(rot, Matrix):
        return rot.to_3x3()
    d = Vector(rot).normalized()
    return Vector((0, 0, 1)).rotation_difference(d).to_matrix()


_MATS = {}


def material(glow):
    key = "forage_glow" if glow else "forage_vcol"
    m = _MATS.get(key)
    if m is not None and m.name in bpy.data.materials:
        return m
    m = bpy.data.materials.new(key)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    attr = nt.nodes.new("ShaderNodeVertexColor")
    attr.layer_name = "Col"
    nt.links.new(attr.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.55
    if glow:
        nt.links.new(attr.outputs["Color"], bsdf.inputs["Emission Color"])
        bsdf.inputs["Emission Strength"].default_value = 1.2
    _MATS[key] = m
    return m


def lod(ob, ratio=0.5):
    me = ob.data.copy()
    lo = bpy.data.objects.new(ob.name + "_LOD1", me)
    bpy.context.scene.collection.objects.link(lo)
    mod = lo.modifiers.new("dec", "DECIMATE")
    mod.ratio = ratio
    bpy.context.view_layer.objects.active = lo
    with bpy.context.temp_override(object=lo, active_object=lo):
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return lo


def tri_count(ob):
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)


def reset():
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob, do_unlink=True)
    for me in list(bpy.data.meshes):
        bpy.data.meshes.remove(me)


def export(objs, path):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.gltf(
        filepath=path, export_format="GLB", use_selection=True, export_apply=True,
        export_yup=True, export_vertex_color="ACTIVE", export_normals=True,
        export_texcoords=False, export_materials="EXPORT", export_animations=False,
        export_skins=False, export_morph=False, export_cameras=False, export_lights=False)
