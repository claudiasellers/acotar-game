"""Shared helpers for the village Blender generators (headless bpy).

Every asset is built into ONE bmesh (one joined mesh, one material), with its
colour baked into a corner byte-colour attribute "Col" (glTF COLOR_0) so the
shared stylized shader tints by vertex colour. Blender axes: X right, Y back
(front faces -Y, which is +Z in Godot), Z up. Origin = base centre.
"""
import math
import os
import random

import bpy  # noqa: I001 (bpy must load before bmesh)
import bmesh
from mathutils import Euler, Matrix, Vector

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
OUT_DIR = os.path.join(REPO, "world", "human_realm", "village", "assets")

SNOW = (0.92, 0.94, 0.98)

# Winter village palette: blue-grey, snow-white, wet-black, bone, smoke-brown.
C = {
    "daub": (0.74, 0.70, 0.62),
    "daub_grey": (0.62, 0.62, 0.60),
    "timber": (0.22, 0.16, 0.11),
    "timber_grey": (0.36, 0.33, 0.30),
    "plank": (0.38, 0.29, 0.20),
    "plank_old": (0.33, 0.30, 0.27),
    "stone": (0.52, 0.53, 0.56),
    "stone_dark": (0.38, 0.39, 0.42),
    "shingle": (0.30, 0.28, 0.28),
    "thatch": (0.48, 0.40, 0.27),
    "thatch_old": (0.38, 0.34, 0.27),
    "door": (0.26, 0.18, 0.12),
    "glass_dark": (0.16, 0.20, 0.27),
    "glass_warm": (1.0, 0.72, 0.36),
    "iron": (0.16, 0.16, 0.18),
    "rust": (0.42, 0.24, 0.14),
    "cloth_pale": (0.88, 0.86, 0.80),
    "cloth_grey": (0.58, 0.58, 0.62),
    "cloth_brown": (0.45, 0.33, 0.24),
    "cloth_blue": (0.32, 0.40, 0.52),
    "fur_brown": (0.40, 0.30, 0.22),
    "fur_grey": (0.55, 0.53, 0.50),
    "fur_white": (0.86, 0.85, 0.82),
    "sack": (0.66, 0.58, 0.44),
    "grain": (0.78, 0.66, 0.40),
    "salt": (0.95, 0.95, 0.93),
    "red": (0.62, 0.12, 0.10),
    "ember": (1.0, 0.45, 0.12),
    "ice": (0.74, 0.86, 0.95),
    "straw": (0.70, 0.60, 0.36),
    "gold": (0.80, 0.64, 0.28),
    "black": (0.08, 0.08, 0.09),
    "bone": (0.86, 0.82, 0.72),
}


class Asset:
    """One asset under construction: a single bmesh with a Col layer."""

    def __init__(self, name, seed=1):
        self.name = name
        self.bm = bmesh.new()
        self.col = self.bm.loops.layers.color.new("Col")
        self.rng = random.Random(seed)

    # --- colouring -------------------------------------------------------
    def _paint(self, n0, col, snow=0.0, jitter=0.05):
        bm = self.bm
        bm.faces.ensure_lookup_table()
        bm.normal_update()
        for f in bm.faces[n0:]:
            j = 1.0 + self.rng.uniform(-jitter, jitter)
            c = [min(1.0, x * j) for x in col]
            if snow > 0.0 and f.normal.z > 0.45:
                t = snow * min(1.0, (f.normal.z - 0.45) / 0.35)
                c = [a + (b - a) * t for a, b in zip(c, SNOW)]
            for loop in f.loops:
                loop[self.col] = (c[0], c[1], c[2], 1.0)

    def _bevel(self, n0, amount, segments=1):
        if amount <= 0.0:
            return
        self.bm.faces.ensure_lookup_table()
        edges = {e for f in self.bm.faces[n0:] for e in f.edges}
        bmesh.ops.bevel(self.bm, geom=list(edges), offset=amount, segments=segments,
                        affect="EDGES", profile=0.5, clamp_overlap=True)

    @staticmethod
    def _matrix(loc, rot, scale=(1, 1, 1)):
        return (Matrix.Translation(Vector(loc)) @ Euler(rot, "XYZ").to_matrix().to_4x4()
                @ Matrix.Diagonal(Vector((scale[0], scale[1], scale[2], 1.0))))

    # --- primitives ------------------------------------------------------
    def box(self, size, loc, col, rot=(0, 0, 0), bevel=0.0, snow=0.0, jitter=0.05):
        n0 = len(self.bm.faces)
        bmesh.ops.create_cube(self.bm, size=1.0, matrix=self._matrix(loc, rot, size))
        self._bevel(n0, bevel)
        self._paint(n0, col, snow, jitter)

    def cyl(self, r, h, loc, col, rot=(0, 0, 0), segs=10, r2=None, snow=0.0, bevel=0.0):
        """Cylinder (or cone with r2) standing on loc (base centre) along local Z."""
        n0 = len(self.bm.faces)
        m = self._matrix(loc, rot) @ Matrix.Translation((0, 0, h * 0.5))
        bmesh.ops.create_cone(self.bm, cap_ends=True, cap_tris=False, segments=segs,
                              radius1=r, radius2=r if r2 is None else r2, depth=h, matrix=m)
        self._bevel(n0, bevel)
        self._paint(n0, col, snow)

    def sphere(self, r, loc, col, scale=(1, 1, 1), subdiv=2, snow=0.0, rot=(0, 0, 0)):
        n0 = len(self.bm.faces)
        bmesh.ops.create_icosphere(self.bm, subdivisions=subdiv, radius=r,
                                   matrix=self._matrix(loc, rot, scale))
        self._paint(n0, col, snow)

    def prism(self, profile, length, loc, col, rot=(0, 0, 0), snow=0.0, bevel=0.0):
        """Extrude a closed YZ profile (list of (y, z)) along X, centred on loc."""
        n0 = len(self.bm.faces)
        m = self._matrix(loc, rot)
        half = length * 0.5
        left = [self.bm.verts.new(m @ Vector((-half, y, z))) for y, z in profile]
        right = [self.bm.verts.new(m @ Vector((half, y, z))) for y, z in profile]
        n = len(profile)
        self.bm.faces.new(list(reversed(left)))
        self.bm.faces.new(right)
        for i in range(n):
            j = (i + 1) % n
            self.bm.faces.new([left[i], left[j], right[j], right[i]])
        self.bm.faces.ensure_lookup_table()
        bmesh.ops.recalc_face_normals(self.bm, faces=list(self.bm.faces)[n0:])
        self._bevel(n0, bevel)
        self._paint(n0, col, snow)

    # --- architectural kit ----------------------------------------------
    def gable_roof(self, w, d, z0, h, col, overhang=0.45, thick=0.22, snow_depth=0.16,
                   sag=0.0, bevel=0.06, x0=0.0, y0=0.0, bare_back=False):
        """Two slanted slabs from the eaves (z0) to the ridge (z0 + h) along X,
        with a chunky snow layer on top of each and a snow bolster on the ridge."""
        half = d * 0.5
        run = half + overhang
        pitch = math.atan2(h, half)
        rise = run * math.tan(pitch)
        slab = math.hypot(run, rise)
        for side in (-1, 1):
            rx = -side * pitch
            n = Vector((0, -math.sin(rx), math.cos(rx)))
            centre = Vector((x0, y0 + side * run * 0.5, z0 + h - rise * 0.5 - sag))
            size = (w + 2 * overhang, slab, thick)
            self.box(size, tuple(centre + n * (thick * 0.5)), col, rot=(rx, 0, 0), bevel=bevel)
            if bare_back and side == 1:
                continue
            sloc = centre + n * (thick + snow_depth * 0.4)
            sloc.y -= side * slab * 0.04
            self.box((size[0] - 0.15, slab * 0.9, snow_depth), tuple(sloc), SNOW, rot=(rx, 0, 0), bevel=0.06, jitter=0.02)
        ln = w + 2 * overhang - 0.2
        self.cyl(0.2, ln, (x0 - ln / 2, y0, z0 + h + thick * 0.7 - sag), SNOW, rot=(0, math.pi / 2, 0), segs=8)

    def gable_fill(self, w, d, z0, h, col, x0=0.0, y0=0.0):
        half = d * 0.5
        self.prism([(-half, 0.0), (half, 0.0), (0.0, h)], w, (x0, y0, z0), col)

    def timber_frame(self, w, d, z0, h, col=None, braces=True, posts=3, t=0.16):
        col = col or C["timber"]
        hw, hd = w * 0.5, d * 0.5
        # Corner + intermediate posts on front/back.
        for i in range(posts + 1):
            x = -hw + w * i / posts
            for y in (-hd, hd):
                self.box((t, t, h), (x, y, z0 + h / 2), col, bevel=0.02)
        for y in (-hd + d / 2,):
            for x in (-hw, hw):
                self.box((t, t, h), (x, y, z0 + h / 2), col, bevel=0.02)
        # Rails.
        for z in (z0 + t / 2, z0 + h - t / 2):
            for y in (-hd, hd):
                self.box((w + t, t, t), (0, y, z), col)
            for x in (-hw, hw):
                self.box((t, d + t, t), (x, 0, z), col)
        if braces:
            ang = math.atan2(h, w / posts)
            ln = math.hypot(h, w / posts) * 0.92
            for i in range(posts):
                cx = -hw + w * (i + 0.5) / posts
                for y in (-hd - 0.01, hd + 0.01):
                    if (i % 2) == 0:
                        self.box((ln, t * 0.8, t * 0.8), (cx, y, z0 + h / 2), col, rot=(0, -ang if i % 4 == 0 else ang, 0))

    def window(self, x, y, z, col=None, w=0.8, h=0.9, face="front", shutters=True, frame=None, open_shutters=True):
        col = col or C["glass_dark"]
        frame = frame or C["timber"]
        out = -1 if face in ("front", "left") else 1
        if face in ("front", "back"):
            self.box((w, 0.12, h), (x, y + out * 0.02, z), col, jitter=0.0)
            self.box((w + 0.16, 0.16, 0.1), (x, y + out * 0.05, z - h / 2 - 0.05), frame, snow=1.0)
            self.box((w + 0.16, 0.16, 0.08), (x, y + out * 0.05, z + h / 2 + 0.04), frame)
            self.box((0.06, 0.14, h), (x, y + out * 0.05, z), frame)
            if shutters:
                for s in (-1, 1):
                    self.box((w / 2, 0.06, h), (x + s * (w * 0.75 + 0.02), y + out * 0.09, z), C["plank_old"], bevel=0.015)
        else:
            self.box((0.12, w, h), (x + out * 0.02, y, z), col, jitter=0.0)
            self.box((0.16, w + 0.16, 0.1), (x + out * 0.05, y, z - h / 2 - 0.05), frame, snow=1.0)
            self.box((0.16, w + 0.16, 0.08), (x + out * 0.05, y, z + h / 2 + 0.04), frame)
            if shutters:
                for s in (-1, 1):
                    self.box((0.06, w / 2, h), (x + out * 0.09, y + s * (w * 0.75 + 0.02), z), C["plank_old"], bevel=0.015)

    def door(self, x, y, w=1.1, h=2.0, col=None, face="front", z=0.0):
        col = col or C["door"]
        out = -1 if face == "front" else 1
        self.box((w, 0.14, h), (x, y + out * 0.03, z + h / 2), col, bevel=0.02)
        for i in range(3):
            self.box((w * 0.9, 0.04, 0.1), (x, y + out * 0.11, z + 0.3 + i * (h - 0.5) / 2), C["timber"])
        self.box((w + 0.25, 0.2, 0.16), (x, y + out * 0.06, z + h + 0.08), C["timber"])
        self.sphere(0.05, (x + w * 0.35, y + out * 0.14, z + h * 0.48), C["iron"], subdiv=1)

    def chimney(self, x, y, z0, h, col=None, w=0.75):
        col = col or C["stone"]
        self.box((w, w, h), (x, y, z0 + h / 2), col, bevel=0.05)
        self.box((w + 0.16, w + 0.16, 0.18), (x, y, z0 + h - 0.05), C["stone_dark"], bevel=0.04, snow=1.0)
        self.box((w * 0.5, w * 0.5, 0.05), (x, y, z0 + h + 0.05), C["black"], jitter=0.0)

    def icicles(self, x0, x1, y, z, count, rng_len=(0.15, 0.55), along="x"):
        """Hanging icicles under an eave from x0 to x1 at depth y, top at z."""
        for i in range(count):
            t = (i + self.rng.uniform(0.2, 0.8)) / count
            ln = self.rng.uniform(*rng_len)
            a = x0 + (x1 - x0) * t
            p = (a, y, z - ln) if along == "x" else (y, a, z - ln)
            self.cyl(0.006, ln, p, C["ice"], segs=5, r2=0.05)

    def snow_mound(self, loc, r, h=0.4):
        self.sphere(r, loc, SNOW, scale=(1.0, 1.0, h / r), subdiv=2)

    # --- output ----------------------------------------------------------
    def export(self):
        os.makedirs(OUT_DIR, exist_ok=True)
        bm = self.bm
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)
        bm.normal_update()
        me = bpy.data.meshes.new(self.name)
        bm.to_mesh(me)
        bm.free()
        if me.color_attributes:
            me.color_attributes.active_color = me.color_attributes[0]
            me.color_attributes.render_color_index = 0
        mat = bpy.data.materials.get("village") or bpy.data.materials.new("village")
        me.materials.append(mat)
        for p in me.polygons:
            p.use_smooth = False
        ob = bpy.data.objects.new(self.name, me)
        bpy.context.scene.collection.objects.link(ob)
        for o in bpy.context.scene.objects:
            o.select_set(o == ob)
        bpy.context.view_layer.objects.active = ob
        path = os.path.join(OUT_DIR, self.name + ".glb")
        bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True,
                                  export_vertex_color="ACTIVE", export_apply=True,
                                  export_materials="EXPORT", export_yup=True)
        bpy.data.objects.remove(ob)
        bpy.data.meshes.remove(me)
        print("wrote", os.path.relpath(path, REPO))


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
