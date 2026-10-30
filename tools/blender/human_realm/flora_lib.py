"""Parametric stylized flora/rock primitives for the human realm (headless bpy).

Everything is built into one bmesh per asset with a face-corner "Col" colour
attribute, then exported as a single joined mesh object (+Z up in Blender,
+Y up in the glb). All randomness goes through a seeded random.Random so a
run is deterministic.
"""
import math
import random

import bpy  # noqa: F401  (must load before bmesh)
import bmesh
import bpy
from mathutils import Matrix, Vector, noise

# ---------------------------------------------------------------- palette
PAL = {
    "bark_wet": (0.07, 0.065, 0.06),
    "bark_grey": (0.23, 0.21, 0.19),
    "bark_brown": (0.20, 0.15, 0.11),
    "bark_ash": (0.56, 0.57, 0.56),
    "bark_ash_lt": (0.70, 0.71, 0.70),
    "bark_birch": (0.86, 0.85, 0.82),
    "birch_mark": (0.10, 0.09, 0.09),
    "bark_pine": (0.30, 0.18, 0.12),
    "wood_dead": (0.45, 0.41, 0.36),
    "wood_cut": (0.62, 0.48, 0.32),
    "evergreen": (0.06, 0.16, 0.11),
    "evergreen_lt": (0.10, 0.23, 0.15),
    "spruce": (0.05, 0.14, 0.13),
    "holly_leaf": (0.04, 0.17, 0.09),
    "juniper": (0.17, 0.25, 0.22),
    "red": (0.72, 0.04, 0.04),
    "red_deep": (0.45, 0.03, 0.04),
    "orange_hip": (0.80, 0.18, 0.05),
    "sloe": (0.18, 0.20, 0.34),
    "juniper_berry": (0.25, 0.30, 0.45),
    "frost": (0.90, 0.93, 0.97),
    "snow": (0.95, 0.97, 1.0),
    "ice": (0.70, 0.84, 0.95),
    "lichen": (0.66, 0.72, 0.58),
    "lichen_grey": (0.62, 0.66, 0.62),
    "straw": (0.62, 0.52, 0.34),
    "straw_dark": (0.42, 0.34, 0.22),
    "bracken": (0.48, 0.24, 0.10),
    "reed": (0.55, 0.47, 0.32),
    "willow_red": (0.48, 0.16, 0.09),
    "willow_yellow": (0.62, 0.50, 0.20),
    "woad_leaf": (0.30, 0.40, 0.36),
    "madder_leaf": (0.18, 0.26, 0.12),
    "madder_root": (0.55, 0.12, 0.08),
    "snowdrop": (0.97, 0.98, 0.96),
    "snowdrop_green": (0.30, 0.48, 0.32),
    "wintergreen": (0.08, 0.22, 0.12),
    "mistletoe": (0.42, 0.52, 0.22),
    "mistletoe_berry": (0.92, 0.92, 0.82),
    "chaga": (0.08, 0.05, 0.04),
    "chaga_inner": (0.55, 0.30, 0.10),
    "tinder": (0.48, 0.42, 0.36),
    "tinder_rim": (0.70, 0.66, 0.58),
    "gall": (0.50, 0.36, 0.22),
    "acorn": (0.45, 0.30, 0.12),
    "acorn_cap": (0.30, 0.24, 0.14),
    "hazelnut": (0.52, 0.34, 0.16),
    "cone": (0.32, 0.20, 0.10),
    "resin": (0.85, 0.52, 0.10),
    "moss_ice": (0.36, 0.50, 0.42),
    "flint": (0.12, 0.12, 0.14),
    "flint_cortex": (0.82, 0.80, 0.72),
    "chalk": (0.93, 0.92, 0.86),
    "ochre": (0.62, 0.20, 0.10),
    "clay": (0.58, 0.40, 0.30),
    "antler": (0.80, 0.74, 0.62),
    "antler_tip": (0.92, 0.90, 0.84),
    "crow": (0.04, 0.04, 0.06),
    "owl": (0.62, 0.50, 0.36),
    "owl_bar": (0.30, 0.22, 0.14),
    "hawk": (0.45, 0.28, 0.14),
    "hawk_bar": (0.18, 0.12, 0.08),
    "quill": (0.85, 0.82, 0.74),
    "shell": (0.70, 0.62, 0.48),
    "shell_band": (0.30, 0.20, 0.14),
    "charcoal": (0.05, 0.05, 0.05),
    "rock": (0.42, 0.43, 0.46),
    "rock_dark": (0.30, 0.31, 0.34),
    "rock_warm": (0.46, 0.43, 0.40),
    "soil": (0.18, 0.14, 0.11),
}


def col(name_or_rgb):
    c = PAL[name_or_rgb] if isinstance(name_or_rgb, str) else name_or_rgb
    return (c[0], c[1], c[2], 1.0)


def mix(a, b, t):
    a, b = col(a), col(b)
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3)) + (1.0,)


def jitter(c, rng, amt=0.06):
    c = col(c)
    f = 1.0 + rng.uniform(-amt, amt)
    return (min(1, c[0] * f), min(1, c[1] * f), min(1, c[2] * f), 1.0)


def _frame(d):
    """Two unit vectors perpendicular to d."""
    d = d.normalized()
    up = Vector((0, 0, 1)) if abs(d.z) < 0.95 else Vector((1, 0, 0))
    u = d.cross(up).normalized()
    v = d.cross(u).normalized()
    return u, v


class Builder:
    """Accumulates geometry with per-face colours into one bmesh."""

    def __init__(self, seed=0):
        self.bm = bmesh.new()
        self.col = self.bm.loops.layers.color.new("Col")
        self.rng = random.Random(seed)
        self.seed = seed

    # ---------------------------------------------------------- low level
    def _face(self, verts, c):
        try:
            f = self.bm.faces.new(verts)
        except ValueError:
            return None
        for loop in f.loops:
            loop[self.col] = c
        return f

    def _paint(self, faces, c):
        for f in faces:
            for loop in f.loops:
                loop[self.col] = c

    def tri_count(self):
        return sum(len(f.verts) - 2 for f in self.bm.faces)

    # ---------------------------------------------------------- tubes
    def tube(self, pts, radii, sides=6, color="bark_grey", tip_color=None, cap=True,
             flatten=1.0, twist=0.0):
        """Tapered tube along a polyline. Colour may blend to tip_color."""
        n = len(pts)
        rings = []
        prev_u = None
        for i, p in enumerate(pts):
            if i == 0:
                d = pts[1] - pts[0]
            elif i == n - 1:
                d = pts[-1] - pts[-2]
            else:
                d = (pts[i + 1] - pts[i - 1])
            u, v = _frame(d)
            if prev_u is not None and u.dot(prev_u) < 0:
                u, v = -u, -v
            prev_u = u
            r = radii[i]
            ring = []
            for s in range(sides):
                a = 2 * math.pi * s / sides + twist * i
                off = u * math.cos(a) * r + v * math.sin(a) * r * flatten
                ring.append(self.bm.verts.new(p + off))
            rings.append(ring)
        faces = []
        for i in range(n - 1):
            t = i / max(1, n - 2)
            c = mix(color, tip_color, t) if tip_color else col(color)
            for s in range(sides):
                a, b = rings[i][s], rings[i][(s + 1) % sides]
                c2, d2 = rings[i + 1][(s + 1) % sides], rings[i + 1][s]
                f = self._face([a, b, c2, d2], c)
                if f:
                    faces.append(f)
        if cap and radii[-1] > 0.002:
            self._face(list(reversed(rings[-1])) if False else rings[-1],
                       col(tip_color or color))
        return faces

    def branch_curve(self, start, direction, length, segs, wobble=0.15, droop=0.0,
                     rise=0.0):
        """Polyline that wanders a little; droop pulls the tip down, rise up."""
        pts = [start.copy()]
        d = direction.normalized()
        p = start.copy()
        step = length / segs
        for i in range(segs):
            d = (d + Vector((self.rng.uniform(-wobble, wobble),
                             self.rng.uniform(-wobble, wobble),
                             self.rng.uniform(-wobble, wobble) - droop + rise))).normalized()
            p = p + d * step
            pts.append(p.copy())
        return pts, d

    # ---------------------------------------------------------- blobs
    def blob(self, center, size, subdiv=1, color="evergreen", noise_amt=0.18,
             snow=None, flat_bottom=None, color2=None, seed_off=0):
        """Lumpy ico-sphere. size = scalar or (sx, sy, sz).
        subdiv 0 = 20 tris, 1 = 80, 2 = 320 (bmesh counts the icosahedron as 1)."""
        if not isinstance(size, (tuple, list, Vector)):
            size = (size, size, size)
        tmp = bmesh.new()
        bmesh.ops.create_icosphere(tmp, subdivisions=subdiv + 1, radius=1.0)
        off = Vector((self.seed * 1.37 + seed_off * 3.1, self.rng.uniform(0, 50), 7.7))
        for v in tmp.verts:
            n = noise.noise(v.co * 1.7 + off)
            v.co = v.co * (1.0 + n * noise_amt)
            v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))
            if flat_bottom is not None and v.co.z < -size[2] * flat_bottom:
                v.co.z = -size[2] * flat_bottom
            v.co += center
        return self._merge(tmp, color, snow, color2)

    def _merge(self, tmp, color, snow=None, color2=None, color_fn=None):
        vmap = {v: self.bm.verts.new(v.co) for v in tmp.verts}
        faces = []
        for f in tmp.faces:
            nf = None
            try:
                nf = self.bm.faces.new([vmap[v] for v in f.verts])
            except ValueError:
                continue
            nf.normal_update()
            if color_fn:
                c = color_fn(nf)
            else:
                c = jitter(color, self.rng, 0.08) if not color2 else mix(color, color2, self.rng.random())
            if snow is not None and nf.normal.z > snow:
                t = min(1.0, (nf.normal.z - snow) / max(0.01, 1 - snow) * 1.6)
                c = tuple(c[i] + (col("snow")[i] - c[i]) * t for i in range(3)) + (1.0,)
            self._paint([nf], c)
            faces.append(nf)
        tmp.free()
        return faces

    def mesh_from(self, verts, faces_idx, color, snow=None, color_fn=None):
        tmp = bmesh.new()
        vs = [tmp.verts.new(v) for v in verts]
        for fi in faces_idx:
            try:
                tmp.faces.new([vs[i] for i in fi])
            except ValueError:
                pass
        return self._merge(tmp, color, snow, color_fn=color_fn)

    # ---------------------------------------------------------- shapes
    def cone(self, base, height, radius, sides=8, color="spruce", color_tip=None,
             droop=0.0, bottom=True, snow=None, ragged=0.0):
        verts = [base + Vector((0, 0, height))]
        for s in range(sides):
            a = 2 * math.pi * s / sides + self.rng.uniform(-0.15, 0.15)
            r = radius * (1 + self.rng.uniform(-ragged, ragged))
            verts.append(base + Vector((math.cos(a) * r, math.sin(a) * r, -droop * radius)))
        faces = [[0, 1 + s, 1 + (s + 1) % sides] for s in range(sides)]
        if bottom:
            verts.append(base + Vector((0, 0, radius * 0.15)))
            c = len(verts) - 1
            faces += [[c, 1 + (s + 1) % sides, 1 + s] for s in range(sides)]
        tip = color_tip
        fn = None
        if tip:
            def fn(f, _c=color, _t=tip):
                h = (f.calc_center_median().z - base.z) / max(0.01, height)
                return mix(_c, _t, max(0, min(1, h)))
        return self.mesh_from(verts, faces, color, snow=snow, color_fn=fn)

    def blade(self, base, direction, length, width, color="straw", tip_color=None,
              bend=0.3, segs=3, thick=0.0):
        """Tapered leaf/grass blade, double-faced (as a thin wedge)."""
        d = direction.normalized()
        u, v = _frame(d)
        pts_l, pts_r = [], []
        p = base.copy()
        for i in range(segs + 1):
            t = i / segs
            w = width * (1 - t) ** 0.8 * 0.5
            q = base + d * length * t + Vector((0, 0, -bend * length * t * t))
            pts_l.append(q - u * w)
            pts_r.append(q + u * w)
        verts = []
        faces = []
        for i in range(segs + 1):
            verts += [pts_l[i], pts_r[i]]
        for i in range(segs):
            a, b, c, e = 2 * i, 2 * i + 1, 2 * i + 3, 2 * i + 2
            faces.append([a, b, c, e])
            faces.append([e, c, b, a])
        fn = None
        if tip_color:
            def fn(f, _b=base, _c=color, _t=tip_color, _l=length):
                h = (f.calc_center_median() - _b).length / max(0.01, _l)
                return mix(_c, _t, min(1, h))
        return self.mesh_from(verts, faces, color, color_fn=fn)

    def leaf(self, base, direction, length, width, color, normal_up=True):
        """Flat diamond leaf (2 faces, double-sided)."""
        d = direction.normalized()
        u, _ = _frame(d)
        tip = base + d * length
        mid = base + d * length * 0.45
        verts = [base, mid + u * width * 0.5, tip, mid - u * width * 0.5,
                 mid + Vector((0, 0, width * 0.12))]
        faces = [[0, 1, 4], [1, 2, 4], [2, 3, 4], [3, 0, 4],
                 [4, 1, 0], [4, 2, 1], [4, 3, 2], [4, 0, 3]]
        return self.mesh_from(verts, faces, color)

    def box(self, center, size, color, rot_z=0.0, snow=None, bevel_noise=0.0):
        tmp = bmesh.new()
        bmesh.ops.create_cube(tmp, size=1.0)
        m = Matrix.Rotation(rot_z, 4, "Z")
        for v in tmp.verts:
            co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))
            if bevel_noise:
                co += Vector((self.rng.uniform(-1, 1), self.rng.uniform(-1, 1),
                              self.rng.uniform(-1, 1))) * bevel_noise
            v.co = m @ co + center
        return self._merge(tmp, color, snow)

    def berry(self, center, r, color="red", subdiv=0):
        tmp = bmesh.new()
        bmesh.ops.create_icosphere(tmp, subdivisions=subdiv + 1, radius=r)
        bmesh.ops.translate(tmp, verts=tmp.verts, vec=center)
        return self._merge(tmp, color)

    def rock(self, center, size, subdiv=2, color="rock", noise_amt=0.35, snow=0.55,
             flat=0.35, facet=2.3):
        """Faceted displaced ico rock, buried flat bottom, snow on top faces."""
        if not isinstance(size, (tuple, list, Vector)):
            size = (size, size, size)
        tmp = bmesh.new()
        bmesh.ops.create_icosphere(tmp, subdivisions=subdiv + 1, radius=1.0)
        off = Vector((self.rng.uniform(0, 100), self.rng.uniform(0, 100), self.seed * 0.71))
        for v in tmp.verts:
            n = noise.noise(v.co * facet + off)
            n2 = noise.noise(v.co * facet * 2.3 + off * 1.3) * 0.4
            v.co = v.co * (1.0 + (n + n2) * noise_amt)
            v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))
            if v.co.z < -size[2] * flat:
                v.co.z = -size[2] * flat
        for v in tmp.verts:
            v.co.z += size[2] * flat
            v.co += center
        rng = self.rng

        def fn(f, _c=color):
            c = jitter(_c, rng, 0.1)
            if f.calc_center_median().z < center.z + size[2] * 0.25:
                c = mix(c[:3], "rock_dark", 0.4)
            return c
        return self._merge(tmp, color, snow=snow, color_fn=fn)

    # ---------------------------------------------------------- finish
    def to_object(self, name):
        bmesh.ops.remove_doubles(self.bm, verts=self.bm.verts, dist=0.0001)
        me = bpy.data.meshes.new(name)
        self.bm.to_mesh(me)
        self.bm.free()
        me.color_attributes.active_color = me.color_attributes["Col"]
        me.color_attributes.render_color_index = 0
        mat = _material()
        me.materials.append(mat)
        ob = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(ob)
        for p in me.polygons:
            p.use_smooth = False
        return ob


_MAT = None


def _material():
    global _MAT
    if _MAT is not None and _MAT.name in bpy.data.materials:
        return _MAT
    m = bpy.data.materials.new("flora_vcol")
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    attr = nt.nodes.new("ShaderNodeVertexColor")
    attr.layer_name = "Col"
    nt.links.new(attr.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.9
    _MAT = m
    return m


def reset_scene():
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob, do_unlink=True)
    for me in list(bpy.data.meshes):
        bpy.data.meshes.remove(me)


def export(ob, path):
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.export_scene.gltf(
        filepath=path, export_format="GLB", use_selection=True, export_apply=True,
        export_yup=True, export_vertex_color="ACTIVE", export_normals=True,
        export_texcoords=False, export_materials="EXPORT", export_animations=False,
        export_skins=False, export_morph=False, export_cameras=False,
        export_lights=False)


# ---------------------------------------------------------------- trees
def grow(b, start, direction, length, radius, depth, cfg, out_tips):
    """Recursive branching. cfg keys: segs, sides, children, spread, ratio,
    rratio, droop, rise, wobble, color, tip_color, min_r."""
    segs = cfg["segs"][min(depth, len(cfg["segs"]) - 1)]
    sides = cfg["sides"][min(depth, len(cfg["sides"]) - 1)]
    pts, end_dir = b.branch_curve(start, direction, length, segs, cfg["wobble"],
                                  cfg.get("droop", 0) * depth, cfg.get("rise", 0))
    r_end = radius * cfg["taper"]
    radii = [radius + (r_end - radius) * (i / segs) for i in range(segs + 1)]
    b.tube(pts, radii, sides, cfg["color"], cfg.get("tip_color") if depth == 0 else None,
           cap=False)
    if depth >= cfg["depth"]:
        out_tips.append((pts[-1], end_dir, radius))
        return
    nchild = cfg["children"][min(depth, len(cfg["children"]) - 1)]
    for k in range(nchild):
        t = cfg.get("child_start", 0.35) + (1 - cfg.get("child_start", 0.35)) * (k + 0.5 + b.rng.uniform(-0.3, 0.3)) / nchild
        if k == nchild - 1 and cfg.get("leader", True):
            t = 1.0
        idx = min(segs, max(1, int(round(t * segs))))
        p = pts[idx]
        seg_dir = (pts[idx] - pts[idx - 1]).normalized()
        u, v = _frame(seg_dir)
        a = b.rng.uniform(0, 2 * math.pi) + k * 2.4
        spread = cfg["spread"] if not (k == nchild - 1 and cfg.get("leader", True)) else cfg["spread"] * 0.35
        nd = (seg_dir * math.cos(spread) + (u * math.cos(a) + v * math.sin(a)) * math.sin(spread)).normalized()
        nd.z += cfg.get("up_bias", 0.0)
        nr = radii[idx] * cfg["rratio"]
        grow(b, p, nd, length * cfg["ratio"] * b.rng.uniform(0.8, 1.15), nr, depth + 1, cfg, out_tips)


def flare(b, base, radius, n=5, color="bark_wet", height=0.6, length=1.2):
    """Root flare: short tapered tubes splaying into the ground."""
    for k in range(n):
        a = 2 * math.pi * k / n + b.rng.uniform(-0.3, 0.3)
        d = Vector((math.cos(a), math.sin(a), 0))
        pts = [base + Vector((0, 0, height)) + d * radius * 0.3,
               base + d * (radius * 0.9 + length * 0.4) + Vector((0, 0, height * 0.3)),
               base + d * (radius + length) + Vector((0, 0, -0.1))]
        b.tube(pts, [radius * 0.45, radius * 0.3, radius * 0.08], 5, color, cap=False)
