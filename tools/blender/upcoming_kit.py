"""Shared helpers for the L73 upcoming-content model generators (headless bpy).

Builds on prop_kit (one mesh per prop, colour per corner, finish in UV.x) and
adds what these families need: an albedo cap, swept limbs, a merged LOD1, a
manifest writer and a look-sheet renderer.

Bars (design director, 2026-11-12): nothing from raw primitives (everything is
generated and smooth-shaded), albedo <= 0.85 per channel, R4 tri caps, LOD1.
"""
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import bpy  # noqa: E402,I001
import bmesh  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402
import prop_kit as K  # noqa: E402

ALBEDO_CAP = 0.85
MAX_PROP_TRIS = 3000


def cap(c):
    return tuple(min(v, ALBEDO_CAP) for v in c[:3]) + tuple(c[3:])


class Prop(K.Prop):
    """prop_kit.Prop with every colour capped at ALBEDO_CAP (sRGB)."""

    def add(self, part, color, finish="satin", matrix=None, smooth=True, sharp_deg=48.0, shade=None):
        sh = (lambda co: cap(shade(co))) if shade else None
        return super().add(part, cap(color), finish, matrix, smooth, sharp_deg, sh)

    def mirror_z(self):
        bmesh.ops.scale(self.bm, vec=(1, 1, -1), verts=self.bm.verts)
        bmesh.ops.reverse_faces(self.bm, faces=self.bm.faces)
        return self

    def transform(self, m):
        bmesh.ops.transform(self.bm, matrix=m, verts=self.bm.verts)
        return self


def sphere(r, u=12, v=8):
    """A UV sphere as a lathe. bmesh.ops.create_uvsphere orders its faces
    differently from run to run in Blender 5.0, which made every file that
    used it change on each rebuild; this one is the same every time."""
    return K.lathe([(r * math.sin(math.pi * i / v), -r * math.cos(math.pi * i / v)) for i in range(v + 1)], u)


K.sphere = sphere        # so prop_kit's own helpers (flower hearts) use it too


def sweep(pts, wx, wy, sides=10):
    """Elliptical section swept along pts [(y, z)] in the YZ plane: wx is the
    half-width along X, wy the half-thickness along the in-plane normal."""
    n = len(pts)
    wxs = wx if isinstance(wx, (list, tuple)) else [wx] * n
    wys = wy if isinstance(wy, (list, tuple)) else [wy] * n
    bm = bmesh.new()
    rings = []
    for i, (y, z) in enumerate(pts):
        a, b = pts[max(i - 1, 0)], pts[min(i + 1, n - 1)]
        t = Vector((0, b[0] - a[0], b[1] - a[1])).normalized()
        nrm = Vector((0, -t.z, t.y))
        c = Vector((0, y, z))
        rings.append([bm.verts.new(c + Vector((1, 0, 0)) * math.cos(2 * math.pi * k / sides) * wxs[i]
                                   + nrm * math.sin(2 * math.pi * k / sides) * wys[i]) for k in range(sides)])
    side = []
    for a, b in zip(rings, rings[1:]):
        for s in range(sides):
            k = (s + 1) % sides
            side.append(bm.faces.new((a[s], a[k], b[k], b[s])))
    c0, c1 = bm.faces.new(list(reversed(rings[0]))), bm.faces.new(rings[-1])
    # explicit winding (no recalc_face_normals: its result varied run to run)
    f = side[0]
    f.normal_update()
    mid = (Vector((0, pts[0][0], pts[0][1])) + Vector((0, pts[1][0], pts[1][1]))) / 2
    if f.normal.dot(f.calc_center_median() - mid) < 0:
        bmesh.ops.reverse_faces(bm, faces=side)
    axis = Vector((0, pts[-1][0] - pts[0][0], pts[-1][1] - pts[0][1]))
    for cap_face, sign in ((c0, -1.0), (c1, 1.0)):
        cap_face.normal_update()
        if cap_face.normal.dot(axis) * sign < 0:
            cap_face.normal_flip()
    return bm


def slab(outline, depth):
    """prop_kit.slab with explicit winding: a 2D outline [(x, z)] extruded
    along Y by depth, centred on y=0. Same faces in the same order every run."""
    pts = list(outline)
    if sum(pts[i][0] * pts[(i + 1) % len(pts)][1] - pts[(i + 1) % len(pts)][0] * pts[i][1] for i in range(len(pts))) < 0:
        pts.reverse()
    bm = bmesh.new()
    front = [bm.verts.new((x, -depth / 2, z)) for x, z in pts]
    back = [bm.verts.new((x, depth / 2, z)) for x, z in pts]
    bm.faces.new(front)
    bm.faces.new(list(reversed(back)))
    n = len(pts)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((front[j], front[i], back[i], back[j]))
    return bm


def ribbon(path, width, thick=0.0012):
    """A flat ribbon: path [(x, z)] in the XZ plane, `width` wide along Y."""
    out = list(path) + [(x + thick, z) for x, z in reversed(path)]
    return slab(out, width)


def grain(base, amount=0.1, freq=90.0):
    """Vertex shade: soft streaks along Z, so wood is not one flat colour."""
    dark = K.darker(base, amount)

    def shade(co):
        f = 0.5 + 0.5 * math.sin(co.z * freq + math.sin(co.x * 300.0 + co.y * 170.0) * 1.5)
        return K.mix(base, dark, f)
    return shade


def merged_lod(objs, name, ratio=0.5):
    """One decimated mesh from several objects (their locations applied)."""
    bm = bmesh.new()
    for o in objs:
        tmp = o.data.copy()
        tmp.transform(Matrix.Translation(o.location))
        bm.from_mesh(tmp)
        bpy.data.meshes.remove(tmp)
    me = bpy.data.meshes.new(name + "_full")
    bm.to_mesh(me)
    bm.free()
    me.materials.append(K.finish_material("opaque"))
    me.materials.append(K.finish_material("clear"))
    if me.color_attributes:
        me.color_attributes.active_color_name = me.color_attributes[0].name
        me.attributes.default_color_name = me.color_attributes[0].name
    full = bpy.data.objects.new(name + "_full", me)
    bpy.context.scene.collection.objects.link(full)
    lo = K.lod(full, ratio)
    lo.name = name
    lo.data.validate(clean_customdata=False)
    bpy.data.objects.remove(full)
    return lo


def finish_single(p, pid):
    """Prop -> (object, lod1) the way every single-mesh prop here ships."""
    ob = p.to_object(pid)
    n = K.mesh_tris(ob)
    lo = K.lod(ob, 0.5 if n > 300 else 0.6)
    lo.name = pid + "_lod1"
    lo.data.validate(clean_customdata=False)
    return ob, lo


def bounds(objs):
    bpy.context.view_layer.update()
    pts = [o.matrix_world @ Vector(c) for o in objs if o.type == "MESH" for c in o.bound_box]
    lo = Vector((min(q.x for q in pts), min(q.y for q in pts), min(q.z for q in pts)))
    hi = Vector((max(q.x for q in pts), max(q.y for q in pts), max(q.z for q in pts)))
    return lo, hi


def max_albedo(ob):
    """Largest sRGB channel in the mesh's colour layer (for the report)."""
    def to_srgb(v):
        return v * 12.92 if v <= 0.0031308 else 1.055 * (v ** (1 / 2.4)) - 0.055
    m = 0.0
    for d in ob.data.color_attributes[0].data:
        m = max(m, d.color[0], d.color[1], d.color[2])
    return to_srgb(m)


def write_manifest(path, rows):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        json.dump({"assets": rows}, f, indent=1, sort_keys=True)
        f.write("\n")


# ------------------------------------------------------------------ look sheet

ROUGH = [0.78, 0.42, 0.92, 0.3, 0.18, 0.05, 0.06, 0.5, 0.04, 0.7]
METAL = [0.0, 0.0, 0.0, 1.0, 0.12, 0.1, 0.9, 0.0, 0.2, 0.0]
COAT = [0.0, 0.3, 0.0, 0.0, 0.7, 1.0, 0.0, 0.0, 0.0, 0.0]
GLOW = [0.0] * 7 + [1.6, 0.0, 0.0]


def preview_materials():
    """Blender-side stand-in for the game's finish shader (sheet only)."""
    for name in ("opaque", "clear"):
        m = bpy.data.materials.get(name)
        if m is None or m.get("previewed"):
            continue
        m["previewed"] = True
        nt = m.node_tree
        bsdf = nt.nodes["Principled BSDF"]
        vc = [n for n in nt.nodes if n.bl_idname == "ShaderNodeVertexColor"][0]
        uv = nt.nodes.new("ShaderNodeUVMap")
        uv.uv_map = "finish"
        sep = nt.nodes.new("ShaderNodeSeparateXYZ")
        nt.links.new(uv.outputs["UV"], sep.inputs[0])

        def ramp(vals):
            r = nt.nodes.new("ShaderNodeValToRGB")
            cr = r.color_ramp
            cr.interpolation = "CONSTANT"
            cr.elements[0].position = 0.0
            cr.elements[1].position = 9 / 16
            for i in range(1, 9):
                cr.elements.new(i / 16)
            for i, e in enumerate(sorted(cr.elements, key=lambda e: e.position)):
                e.color = (vals[i], vals[i], vals[i], 1.0)
            nt.links.new(sep.outputs["X"], r.inputs["Fac"])
            return r.outputs["Color"]

        nt.links.new(ramp(ROUGH), bsdf.inputs["Roughness"])
        nt.links.new(ramp(METAL), bsdf.inputs["Metallic"])
        nt.links.new(ramp(COAT), bsdf.inputs["Coat Weight"])
        nt.links.new(ramp(GLOW), bsdf.inputs["Emission Strength"])
        nt.links.new(vc.outputs["Color"], bsdf.inputs["Emission Color"])
        if name == "clear":
            nt.links.new(vc.outputs["Alpha"], bsdf.inputs["Alpha"])


def studio(ground_z=None, bg=(0.80, 0.74, 0.86), dark=False):
    sc = bpy.context.scene
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.data.type = "ORTHO"
    for rot, energy, ang in (((0.75, 0.15, 0.7), 0.9 if dark else 2.6, 0.35), ((1.1, -0.3, -2.4), 0.3 if dark else 1.1, 0.6)):
        sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
        sun.data.energy = energy
        sun.data.angle = ang
        sc.collection.objects.link(sun)
        sun.rotation_euler = rot
    sc.world = bpy.data.worlds.new("w")
    sc.world.use_nodes = True
    b = sc.world.node_tree.nodes["Background"]
    b.inputs[0].default_value = (*bg, 1)
    b.inputs[1].default_value = 0.25 if dark else 0.55
    if ground_z is not None:
        gm = bpy.data.materials.new("groundmat")
        gm.use_nodes = True
        gb = gm.node_tree.nodes["Principled BSDF"]
        gb.inputs["Base Color"].default_value = (0.20, 0.17, 0.22, 1) if dark else (0.50, 0.44, 0.56, 1)
        gb.inputs["Roughness"].default_value = 0.9
        gme = bpy.data.meshes.new("ground")
        gme.from_pydata([(-80, -80, ground_z), (80, -80, ground_z), (80, 80, ground_z), (-80, 80, ground_z)], [], [(0, 1, 2, 3)])
        gme.materials.append(gm)
        sc.collection.objects.link(bpy.data.objects.new("ground", gme))
    sc.render.engine = "CYCLES"
    sc.cycles.samples = 48
    sc.cycles.device = "CPU"
    try:
        sc.cycles.use_denoising = True
    except Exception:
        pass
    sc.view_settings.view_transform = "Standard"
    sc.render.film_transparent = False
    return cam


def shot(objs, path, resx, resy, az, el, pad=1.08, box=None):
    """Orthographic render framed on objs from azimuth/elevation (degrees)."""
    sc = bpy.context.scene
    lo, hi = box or bounds(objs)
    corners = [Vector((x, y, z)) for x in (lo.x, hi.x) for y in (lo.y, hi.y) for z in (lo.z, hi.z)]
    c = (lo + hi) / 2
    a, e = math.radians(az), math.radians(el)
    d = Vector((math.sin(a) * math.cos(e), math.cos(a) * math.cos(e), math.sin(e)))
    cam = sc.camera
    cam.location = c + d * 40
    cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
    right = (-d).cross(Vector((0, 0, 1))).normalized()
    up = right.cross(-d).normalized()
    ex = max(abs((q - c).dot(right)) for q in corners) * 2
    ey = max(abs((q - c).dot(up)) for q in corners) * 2
    aspect = resx / resy
    # ortho_scale spans the larger render dimension
    cam.data.ortho_scale = pad * (max(ex, ey * aspect) if aspect >= 1 else max(ey, ex / aspect))
    cam.data.clip_end = 200
    sc.render.resolution_x, sc.render.resolution_y = resx, resy
    sc.render.resolution_percentage = 100
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)


def tile_sheet(tiles, path, cols, tile=640, tmp=None):
    """Composites rendered tiles into one sheet. tiles: [(objs, az, el)], each
    rendered alone on the studio ground at tile x tile pixels."""
    import numpy as np
    sc = bpy.context.scene
    tmp = tmp or os.path.join(os.path.dirname(path), "_tiles")
    os.makedirs(tmp, exist_ok=True)
    every = [o for objs, _, _ in tiles for o in objs]
    rows = (len(tiles) + cols - 1) // cols
    canvas = np.ones((rows * tile, cols * tile, 4), dtype=np.float32)
    canvas[:, :, :3] = 0.82
    for k, (objs, az, el) in enumerate(tiles):
        for o in every:
            o.hide_render = o not in objs
        f = os.path.join(tmp, f"t{k:02d}.png")
        shot(objs, f, tile, tile, az, el, pad=1.15)
        im = bpy.data.images.load(f)
        a = np.array(im.pixels[:], dtype=np.float32).reshape(tile, tile, 4)
        bpy.data.images.remove(im)
        os.remove(f)
        r, c = divmod(k, cols)
        canvas[r * tile:(r + 1) * tile, c * tile:(c + 1) * tile] = np.flipud(a)
    os.rmdir(tmp)
    img = bpy.data.images.new("sheet", cols * tile, rows * tile, alpha=False)
    img.pixels = np.flipud(canvas).ravel().tolist()
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    sc.render.filepath = ""
    print("sheet:", path)


def run_family(builders, out_dir, manifest, argv, sheets=None, caps=None):
    """The shared main for a family of single-mesh props.
    builders: id -> (fn(prop), (w, h, d) metres, meta dict).
    sheets: [(file name, [ids], cols, az, el, dark)] for --sheet DIR."""
    caps = caps or {}
    if "--sheet" in argv:
        out = argv[argv.index("--sheet") + 1]
        os.makedirs(out, exist_ok=True)
        for name, ids, cols, az, el, dark in sheets or []:
            K.reset()
            tiles = []
            for pid in ids:
                p = Prop(pid)
                builders[pid][0](p)
                p.fit(builders[pid][1])
                tiles.append(([p.to_object(pid)], az, el))
            preview_materials()
            studio(ground_z=0.0, dark=dark)
            tile_sheet(tiles, os.path.join(out, name), cols)
        return
    only = set(argv[argv.index("--only") + 1].split(",")) if "--only" in argv else None
    rows, over = [], []
    print(f"  {'id':28s} {'lod0':>6s} {'lod1':>6s} {'bytes':>8s} {'albedo':>6s}  fit scale")
    for pid, (fn, size, meta) in builders.items():
        if only and pid not in only:
            continue
        K.reset()
        p = Prop(pid)
        fn(p)
        lo_, hi_ = p.bounds()
        ext = hi_ - lo_
        sc = (size[0] / ext.x, size[1] / ext.z, size[2] / ext.y)
        p.fit(size)
        ob, lo = finish_single(p, pid)
        n0, n1 = K.mesh_tris(ob), K.mesh_tris(lo)
        alb = max_albedo(ob)
        path = os.path.join(out_dir, pid + ".glb")
        K.export_glb([ob, lo], path)
        nbytes = os.path.getsize(path)
        warn = "  <- check proportions" if max(sc) / min(sc) > 1.25 else ""
        print(f"  {pid:28s} {n0:6d} {n1:6d} {nbytes:8d} {alb:6.3f}  ({sc[0]:.2f}, {sc[1]:.2f}, {sc[2]:.2f}){warn}")
        rows.append(dict(id=pid, file=pid + ".glb", tris=n0, tris_lod1=n1, bytes=nbytes, size_m=list(size), **meta))
        if n0 > caps.get(pid, MAX_PROP_TRIS) or alb > ALBEDO_CAP + 0.005:
            over.append(pid)
    if not only:
        write_manifest(os.path.join(out_dir, manifest), rows)
    if over:
        print("OVER BUDGET:", ", ".join(over))
        sys.exit(1)


def rock(r, sub, seed, amp=0.18):
    """A lumpy boulder: an icosphere pushed in and out by a fixed noise."""
    bm = K.ico(r, sub)
    for v in bm.verts:
        n = v.co.normalized()
        d = 1.0 + amp * (math.sin(n.x * 3.1 + seed) * math.cos(n.y * 2.7 + seed * 1.3)
                         + 0.5 * math.sin(n.z * 5.3 + seed * 0.7 + n.x * 4.1)
                         + 0.25 * math.sin(n.y * 9.0 + n.z * 7.0 + seed * 2.1))
        v.co = n * r * d
    return bm


def splat(rx, ry, n, rng, wob=0.25, h=0.004):
    """A flat irregular blob in the XY plane, slightly domed (a puddle, a stain)."""
    bm = bmesh.new()
    c = bm.verts.new((0, 0, h))
    ring = []
    for i in range(n):
        a = 2 * math.pi * i / n
        k = 1.0 + wob * (math.sin(a * 3 + rng.uniform(0, 6)) * 0.5 + rng.uniform(-0.5, 0.5))
        ring.append(bm.verts.new((math.cos(a) * rx * k, math.sin(a) * ry * k, 0.0)))
    for i in range(n):
        bm.faces.new((c, ring[i], ring[(i + 1) % n]))
    return bm


def shard(rng, size):
    """A jagged flat sliver (glass, splintered wood) lying in the XY plane."""
    n = rng.choice((3, 4, 4, 5))
    out = []
    for i in range(n):
        a = 2 * math.pi * i / n + rng.uniform(-0.4, 0.4)
        rr = size * rng.uniform(0.35, 1.0)
        out.append((math.cos(a) * rr, math.sin(a) * rr * rng.uniform(0.4, 1.0)))
    return slab(out, size * 0.06)
