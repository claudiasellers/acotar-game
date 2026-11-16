"""Grove: the builder for plants the court's places need and the game lacks
(docs/lanes/court-planting-by-place.md, "Assets we do not have"), where a
modelled plant suits better than a picture on a card: grass, small flowers,
ferns, and trees whose leaves are seen from close.

  wood   a skeleton grown from a species sheet and the form its site gives it,
         skinned and subdivided into one smooth body (Skin + Subsurf),
         coloured by height, girth and moss
  soft   leaves, petals and blades as small solid polygons (no cut-out
         pictures: nothing shimmers, nothing is dear to draw), each coloured
         base to tip and shaded as part of its cluster

Run:  <bpy python> tools/grove/plants.py [--only grass_glade_a,...] [--out dir]
Out:  <plant>.glb with mesh objects "wood" and "soft". COLOR_0 is albedo in
      sRGB (written raw), UV0.x is wind flex (0 at the root), UV0.y is glow:
      the woods' foliage shader (woods_foliage.gdshader) reads these.
A plant's seed is its name: the same plant on every run.
"""

import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector, kdtree, noise

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "world", "spring_court", "wider", "assets", "flora", "glade")
UP = Vector((0.0, 0.0, 1.0))


def hexc(h):
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def mix(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def shade(c, k):
    return tuple(max(0.0, min(1.0, v * k)) for v in c)


def heading(az, el):
    return Vector((math.cos(az) * math.cos(el), math.sin(az) * math.cos(el), math.sin(el)))


def frame(n):
    """Two unit vectors square to n and to each other."""
    a = n.cross(UP)
    if a.length < 1e-4:
        a = n.cross(Vector((1.0, 0.0, 0.0)))
    a.normalize()
    return a, n.cross(a).normalized()


# ------------------------------------------------------------------ soft ----

class Soft:
    """Leaves, petals, blades: solid polygons with their own normals."""

    def __init__(self):
        self.verts, self.normals, self.faces, self.cols, self.uvs = [], [], [], [], []

    def vert(self, p, n):
        self.verts.append(Vector(p))
        self.normals.append(Vector(n))
        return len(self.verts) - 1

    def face(self, idx, cols, flex, glow=0.0):
        self.faces.append(tuple(idx))
        self.cols.append(tuple(cols))
        self.uvs.append(tuple((f, glow) for f in (flex if isinstance(flex, (tuple, list)) else (flex,) * len(idx))))

    def tris(self):
        return sum(len(f) - 2 for f in self.faces)


# Leaf outlines in leaf space: (along 0..1, half-width as a share of length),
# one side only, base to tip; the builder mirrors them.
OUTLINES = {
    "oak": [(0.22, 0.17), (0.4, 0.1), (0.62, 0.21), (0.8, 0.11)],
    "birch": [(0.3, 0.3), (0.66, 0.17)],
    "hazel": [(0.25, 0.36), (0.6, 0.4), (0.85, 0.22)],
    "ovate": [(0.35, 0.24), (0.7, 0.16)],
    "strap": [(0.5, 0.06)],
    "petal": [(0.55, 0.3), (0.9, 0.2)],
}


def leaf(soft, outline, base, along, face_n, size, c_base, c_tip, flex, shade_n=None, cup=0.18, glow=0.0):
    """One leaf: a fan from its base over the outline, cupped along the midrib.
    face_n is the way its upper side looks; shade_n (the cluster's normal) is
    what it is lit by, so a cluster shades as one soft body."""
    side = along.cross(face_n)
    if side.length < 1e-4:
        side = frame(along)[0]
    side.normalize()
    nrm = side.cross(along).normalized()
    lit = (shade_n * 0.75 + nrm * 0.25).normalized() if shade_n is not None else nrm
    pts = [(0.0, 0.0)] + [(u, w) for u, w in outline] + [(1.0, 0.0)] + [(u, -w) for u, w in reversed(outline)]
    idx, cols = [], []
    for u, w in pts:
        p = base + along * (size * u) + side * (size * w) + nrm * (size * (cup * abs(w) * 2.0 - 0.1 * u * u))
        idx.append(soft.vert(p, lit))
        cols.append(mix(c_base, c_tip, u * (1.0 - abs(w))))
    for k in range(1, len(idx) - 1):
        soft.face((idx[0], idx[k], idx[k + 1]), (cols[0], cols[k], cols[k + 1]), flex, glow)


def cluster(soft, hearts, c, r, sheet, rng, crown_c, crown_r, flex):
    """A cluster of foliage round a twig end: real leaves shingled over a
    soft body of the same greens, tips out and down, so it is a rounded mass
    from far off and leaves from near."""
    lf = sheet["leaf"]
    squash = lf.get("squash", 0.8)
    droop = lf.get("droop", 0.5)
    depth = min(1.0, (c - crown_c).length / max(crown_r, 0.01))       # 0 at the crown's heart, 1 at its rim
    area = lf["size"] ** 2 * lf.get("area", 0.4)
    n = max(8, round(lf.get("cover", 0.3) * 4.0 * math.pi * r * r / area))
    for i in range(n):
        z = 1.0 - 2.0 * (i + 0.5) / n
        if z < -0.35 and rng.random() < 0.55:
            continue    # thinner underneath
        a = i * 2.39996 + rng.uniform(-0.4, 0.4)
        d = Vector((math.sqrt(1 - z * z) * math.cos(a), math.sqrt(1 - z * z) * math.sin(a), z))
        at = c + Vector((d.x, d.y, d.z * squash)) * (r * rng.uniform(0.8, 0.98))
        jit = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1)))
        down = (-UP - d * (-UP).dot(d))
        down = down.normalized() if down.length > 1e-3 else frame(d)[0]
        along = (d * 0.5 + down * droop + jit * 0.4).normalized()
        face = (d + jit * 0.25).normalized()
        lit = (d * 0.6 + (at - crown_c).normalized() * 0.4).normalized()
        # sunlit on top and at the rim of the crown, deep underneath and inside
        sun = max(0.0, min(1.0, 0.2 + 0.5 * (d.z * 0.5 + 0.5) + 0.3 * depth + rng.uniform(-0.14, 0.14)))
        base = mix(lf["deep"], lf["mid"], sun)
        tip = mix(lf["mid"], lf["light"], sun)
        if rng.random() < lf.get("young", 0.0) * (0.3 + 0.7 * max(d.z, 0.0)):
            tip = mix(tip, lf["new"], 0.75)
        size = lf["size"] * rng.uniform(0.8, 1.2)
        leaf(soft, OUTLINES[lf["shape"]], at, along, face, size, base, tip, flex + 0.08, lit, lf.get("cup", 0.18))
    hearts.append((Vector(c), r * lf.get("heart", 0.86), squash, flex, depth, Vector(crown_c)))


_ICO = {}


def _ico(level):
    if level not in _ICO:
        ico = bmesh.new()
        bmesh.ops.create_icosphere(ico, subdivisions=level, radius=1.0)
        _ICO[level] = ([v.co.copy() for v in ico.verts], [tuple(v.index for v in f.verts) for f in ico.faces])
        ico.free()
    return _ICO[level]


def heart_mass(soft, hearts, sheet, rng, level=2):
    """The soft bodies inside the clusters, in the leaves' own greens: light
    on top, deep underneath and toward the crown's heart."""
    lf = sheet["leaf"]
    base, faces = _ico(level)
    for c, r, squash, flex, depth, crown_c in hearts:
        idx, cols = [], []
        off = Vector((rng.uniform(0, 9), rng.uniform(0, 9), rng.uniform(0, 9)))
        for v in base:
            k = 1.0 + 0.14 * noise.noise(v * 1.3 + off)
            p = c + Vector((v.x, v.y, v.z * squash)) * (r * k)
            idx.append(soft.vert(p, (v * 0.6 + (p - crown_c).normalized() * 0.4).normalized()))
            sun = max(0.0, min(1.0, 0.12 + 0.5 * (v.z * 0.5 + 0.5) + 0.3 * depth + 0.12 * noise.noise(v * 2.7 + off)))
            cols.append(mix(lf["deep"], lf["mid"], sun))
        for f in faces:
            soft.face(tuple(idx[k] for k in f), tuple(cols[k] for k in f), flex)


# ------------------------------------------------------------------ wood ----

class Skeleton:
    def __init__(self):
        self.pos, self.rad, self.edges = [], [], []

    def node(self, p, r, parent=None):
        self.pos.append(Vector(p))
        self.rad.append(r)
        if parent is not None:
            self.edges.append((parent, len(self.pos) - 1))
        return len(self.pos) - 1

    def limb(self, start, az, el0, sag, lift, length, r0, r1, kink, rng, segs=5):
        """A limb from node `start`: it leaves at el0, sags in its middle
        under its own weight and turns up to the light at its tip."""
        at = self.pos[start].copy()
        out, prev = [], start
        side = rng.choice((-1, 1))
        for k in range(1, segs + 1):
            s = k / segs
            a = az + math.radians(kink) * side * (1 if k % 2 else -1) * rng.uniform(0.3, 1.0)
            el = math.radians(el0 - sag * math.sin(math.pi * min(s * 1.15, 1.0)) + lift * s * s)
            at = at + heading(a, el) * (length / segs)
            prev = self.node(at, r0 + (r1 - r0) * s ** 0.8, prev)
            out.append(prev)
        return out


def skin(sk, sheet, height, spread, budget):
    """The skeleton as one smooth body, coloured: bark by girth and height,
    moss on the upper sides low down. Returns [(co, normal, colour, flex)], faces."""
    bm = bmesh.new()
    layer = bm.verts.layers.skin.verify()
    vs = []
    for i, (p, r) in enumerate(zip(sk.pos, sk.rad)):
        v = bm.verts.new(p)
        v[layer].radius = (r, r)
        v[layer].use_root = i == 0
        vs.append(v)
    for a, b in sk.edges:
        bm.edges.new((vs[a], vs[b]))
    me = bpy.data.meshes.new("skel")
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new("skel", me)
    bpy.context.scene.collection.objects.link(ob)
    mod = ob.modifiers.new("skin", "SKIN")
    mod.use_smooth_shade = True
    mod.branch_smoothing = 0.55
    sub = ob.modifiers.new("sub", "SUBSURF")
    sub.levels = 1
    tri = ob.modifiers.new("tri", "TRIANGULATE")
    done = ob.evaluated_get(bpy.context.evaluated_depsgraph_get())
    count = len(done.to_mesh().polygons)
    done.to_mesh_clear()
    if count > budget:
        dec = ob.modifiers.new("dec", "DECIMATE")
        dec.ratio = budget / count
        ob.modifiers.move(len(ob.modifiers) - 1, 2)
    done = ob.evaluated_get(bpy.context.evaluated_depsgraph_get())
    mesh = done.to_mesh()
    tree = kdtree.KDTree(len(sk.pos))
    for i, p in enumerate(sk.pos):
        tree.insert(p, i)
    tree.balance()
    bk = sheet["bark"]
    r_max = max(sk.rad)
    verts = []
    for v in mesh.vertices:
        _, i, _ = tree.find(v.co)
        girth = (sk.rad[i] / r_max) ** 0.5
        col = mix(bk["twig"], bk["trunk"], girth)
        # furrows: darker streaks running up the trunk
        ang = math.atan2(v.co.y, v.co.x)
        streak = noise.noise(Vector((ang * bk.get("furrow", 5.0), v.co.z * 0.35, sk.rad[i] * 3.0)))
        col = shade(col, 1.0 + bk.get("contrast", 0.16) * streak * girth)
        if "band" in bk:   # the birch's dark lenticel bands
            band = noise.noise(Vector((ang * 0.8, v.co.z * 3.2, 4.0)))
            if band > 0.42:
                col = mix(col, bk["band"], min(1.0, (band - 0.42) * 6.0) * girth)
        low = 1.0 - min(1.0, max(0.0, (v.co.z / height - 0.05) / bk.get("moss_height", 0.4)))
        top = max(0.0, v.normal.z) ** 1.3
        moss = bk.get("moss", 0.0) * max(low * 0.55 + top * 0.75 * (0.4 + 0.6 * low), 0.0)
        moss *= 0.6 + 0.4 * noise.noise(v.co * 0.9)
        col = mix(col, bk["moss_col"], min(1.0, moss))
        if v.co.z < 0.12 * sk.rad[0] * 4.0:     # the foot settles into the ground's shade
            col = shade(col, 0.82)
        out = math.hypot(v.co.x, v.co.y) / max(spread, 0.01)
        flex = min(0.5, 0.45 * out ** 1.5 + 0.1 * max(0.0, v.co.z / height - 0.5))
        verts.append((v.co.copy(), v.normal.copy(), col, flex))
    faces = [tuple(p.vertices) for p in mesh.polygons]
    done.to_mesh_clear()
    bpy.data.objects.remove(ob, do_unlink=True)
    return verts, faces


def to_object(name, verts, normals, faces, cols, uvs, material):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([tuple(v) for v in verts], [], faces)
    mesh.update()
    col = mesh.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
    uv = mesh.uv_layers.new(name="UVMap")
    for poly in mesh.polygons:
        poly.use_smooth = True
        for k, li in enumerate(poly.loop_indices):
            c = cols[poly.index][k]
            col.data[li].color = (c[0], c[1], c[2], 1.0)
            u = uvs[poly.index][k]
            uv.data[li].uv = (u[0], 1.0 - u[1])   # glTF flips V on export
    mesh.color_attributes.active_color = col
    mesh.normals_split_custom_set_from_vertices([tuple(n) for n in normals])
    mesh.materials.append(bpy.data.materials.get(material) or bpy.data.materials.new(material))
    ob = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def wood_object(verts, faces):
    return to_object("wood", [v[0] for v in verts], [v[1] for v in verts], faces,
                     [tuple(verts[i][2] for i in f) for f in faces],
                     [tuple((verts[i][3], 0.0) for i in f) for f in faces], "grove_wood")


def soft_object(soft):
    return to_object("soft", soft.verts, soft.normals, soft.faces, soft.cols, soft.uvs, "grove_soft")


def export(name, objs, out_dir):
    os.makedirs(out_dir, exist_ok=True)
    path = os.path.join(out_dir, name + ".glb")
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_yup=True,
                              export_vertex_color="ACTIVE", export_all_vertex_colors=False,
                              export_normals=True, export_texcoords=True, export_materials="PLACEHOLDER",
                              export_apply=False, export_animations=False)
    return os.path.getsize(path)


# ------------------------------------------------------------------ trees ---

def tree(sheet, form, rng):
    """A tree of the species in the form its site gives it. Returns wood
    (verts, faces) and its Soft."""
    f = sheet["forms"][form]
    h = sheet["height"] * f.get("height", 1.0) * rng.uniform(0.94, 1.06)
    spread = h * f["spread"] * 0.5                  # the crown's radius
    r = sheet["trunk"] * h * f.get("girth", 1.0)    # trunk radius at chest height
    sk = Skeleton()
    lean = heading(rng.uniform(0, math.tau), 0.0) * (h * f.get("lean", 0.03))
    top_t = f["leader"]                              # where the trunk gives out into boughs

    def trunk_at(t):
        wob = Vector((noise.noise(Vector((t * 2.3, 1.7, h))), noise.noise(Vector((t * 2.3, 5.1, h))), 0.0)) * (r * 0.9 * t)
        return lean * t ** 1.6 + wob + UP * (h * t)

    def girth_at(t):
        return r * (1.0 - 0.5 * (t / top_t) ** 1.2)

    stem = [sk.node((0, 0, -0.25 * r), r * 1.45)]
    stem.append(sk.node(trunk_at(0.035), r * 1.18, stem[-1]))
    # roots: the foot spreads into the ground
    for k in range(f.get("roots", 5)):
        az = math.tau * (k + rng.uniform(-0.25, 0.25)) / f.get("roots", 5)
        reach = r * rng.uniform(1.9, 2.8) * f.get("root_reach", 1.0)
        knee = sk.node(heading(az, 0.0) * reach * 0.5 + UP * (r * 0.28), r * 0.5, stem[0])
        sk.node(heading(az + rng.uniform(-0.3, 0.3), 0.0) * reach - UP * (r * 0.3), r * 0.2, knee)
    seats = []
    n = f["boughs"]
    clear = f["clear"]
    az0 = rng.uniform(0, math.tau)
    # the trunk's hubs, evenly up it; boughs leave from them (two may share one)
    hubs_n = f.get("hubs", max(2, (n + 1) // 2))
    stem.append(sk.node(trunk_at(clear * 0.55), girth_at(clear * 0.55), stem[-1]))
    hubs = []
    for k in range(hubs_n):
        t = clear + (top_t - clear) * (k / hubs_n)
        hubs.append((sk.node(trunk_at(t), girth_at(t), stem[-1]), t))
        stem.append(hubs[-1][0])
    for i in range(n):
        hub, t = hubs[min(hubs_n - 1, i * hubs_n // n)]
        u = (t - clear) / max(top_t - clear, 1e-4)             # 0 lowest hub, 1 highest
        az = az0 + i * 2.39996 + rng.uniform(-0.3, 0.3)
        el0 = f["rise"][0] + (f["rise"][1] - f["rise"][0]) * u + rng.uniform(-5, 5)
        # a bough reaches the crown's outline at its own height
        length = spread * (f.get("low_reach", 0.85) * (1 - u) + f.get("high_reach", 0.7) * u) * rng.uniform(0.88, 1.08)
        br = girth_at(t) * f.get("bough", 0.5)
        limb = sk.limb(hub, az, el0, f.get("sag", 14.0), f.get("lift", 26.0), length, br, br * 0.3, sheet["kink"], rng)
        seats.append((sk.pos[limb[-1]], 1.0))
        # side branches, alternate sides, off the bough's outer part
        for j, at in enumerate(limb[1:-1]):
            sgn = 1 if (i + j) % 2 else -1
            s = (j + 2) / len(limb)
            sub_len = length * (0.5 - 0.22 * s) * rng.uniform(0.8, 1.15)
            sr = sk.rad[at] * 0.62
            sub = sk.limb(at, az + sgn * math.radians(rng.uniform(42, 68)), el0 * 0.5 + rng.uniform(8, 24),
                          f.get("sag", 14.0) * 0.5, f.get("lift", 26.0), sub_len, sr, sr * 0.35, sheet["kink"] * 0.8, rng, 3)
            seats.append((sk.pos[sub[-1]], 0.92))
        # and foliage riding on the bough itself, the crown's inner storey
        for at in limb[2:4]:
            seats.append((sk.pos[at] + UP * (h * sheet["leaf"]["cluster"] * 0.7), 0.85))
    # the leader: the trunk's own top, crowned
    tip = sk.node(trunk_at(top_t) + UP * (h * 0.02), girth_at(top_t) * 0.8, stem[-1])
    for k in range(f.get("crown_limbs", 3)):
        az = az0 + 1.3 + math.tau * k / f.get("crown_limbs", 3) + rng.uniform(-0.4, 0.4)
        length = (h * (1.0 - top_t)) * rng.uniform(0.8, 1.0)
        cr = girth_at(top_t) * 0.55
        limb = sk.limb(tip, az, f.get("crown_rise", 62.0) + rng.uniform(-8, 8), 6.0, 14.0, length, cr, cr * 0.3, sheet["kink"], rng, 4)
        seats.append((sk.pos[limb[-1]], 1.0))
        seats.append((sk.pos[limb[1]] + heading(az + 1.2, 0.3) * (length * 0.3), 0.9))
    verts, faces = skin(sk, sheet, h, spread, f.get("wood_tris", 4200))
    # leaf clusters at every seat, settled so none swallows another
    lf = sheet["leaf"]
    cr = lf["cluster"] * h
    clouds = [[Vector(p) + UP * (cr * 0.3), cr * k * rng.uniform(0.9, 1.15)] for p, k in seats]
    for _ in range(5):
        for q in clouds:
            for o in clouds:
                d = q[0] - o[0]
                want = (q[1] + o[1]) * 0.7
                if o is not q and 1e-6 < d.length < want:
                    q[0] += d.normalized() * (want - d.length) * 0.25
    crown_c = sum((c for c, _ in clouds), Vector()) / len(clouds)
    crown_r = max((c - crown_c).length + cr for c, cr in clouds)
    soft, hearts = Soft(), []
    for c, cr in clouds:
        out = math.hypot(c.x, c.y) / max(spread, 0.01)
        flex = min(0.9, 0.3 + 0.5 * out ** 1.3 + 0.15 * (c.z / h))
        cluster(soft, hearts, c, cr, sheet, rng, crown_c, crown_r, flex)
    heart_mass(soft, hearts, sheet, rng)
    return (verts, faces), soft, {"height": h, "spread": spread, "trunk": r, "clusters": len(clouds)}


# ---------------------------------------------------------- ground plants ---

def blade(soft, base, az, lean, length, width, c0, c1, rng, flex=0.9, segs=3):
    """A grass blade or strap leaf: a tapered strip that leans and bends over.
    Lit from above, like the ground it grows from."""
    d = heading(az, 0.0)
    side = Vector((-d.y, d.x, 0.0))
    left, right, cols, flexes = [], [], [], []
    at = Vector(base)
    el = math.radians(90.0 - lean)
    for k in range(segs + 1):
        s = k / segs
        w = width * (1.0 - s) ** 0.7 * 0.5
        lit = (UP * 0.85 + d * 0.15).normalized()
        left.append(soft.vert(at + side * w, lit))
        right.append(soft.vert(at - side * w, lit))
        cols.append(mix(c0, c1, s ** 0.8))
        flexes.append(flex * s ** 1.4)
        el -= math.radians(lean * 0.9 / segs + rng.uniform(0, 8))
        at = at + heading(az, el) * (length / segs)
    for k in range(segs):
        if k == segs - 1:
            soft.face((left[k], right[k], left[k + 1]), (cols[k], cols[k], cols[k + 1]), (flexes[k], flexes[k], flexes[k + 1]))
        else:
            soft.face((left[k], right[k], right[k + 1], left[k + 1]), (cols[k], cols[k], cols[k + 1], cols[k + 1]),
                      (flexes[k], flexes[k], flexes[k + 1], flexes[k + 1]))


def stalk(soft, pts, r, c0, c1, flex0, flex1):
    """A thin three-sided stem along the points."""
    rings = []
    for i, p in enumerate(pts):
        d = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        a, b = frame(d)
        t = i / (len(pts) - 1)
        rings.append(([soft.vert(p + (a * math.cos(k * 2.094) + b * math.sin(k * 2.094)) * r * (1 - 0.5 * t),
                                 a * math.cos(k * 2.094) + b * math.sin(k * 2.094)) for k in range(3)], mix(c0, c1, t), flex0 + (flex1 - flex0) * t))
    for (a, ca, fa), (b, cb, fb) in zip(rings, rings[1:]):
        for k in range(3):
            soft.face((a[k], a[(k + 1) % 3], b[(k + 1) % 3], b[k]), (ca, ca, cb, cb), (fa, fa, fb, fb))


def grass(sheet, rng):
    soft = Soft()
    for k in range(sheet["blades"]):
        a = rng.uniform(0, math.tau)
        rr = sheet["radius"] * math.sqrt(rng.random())
        base = Vector((math.cos(a) * rr, math.sin(a) * rr, 0.0))
        az = a + rng.uniform(-0.9, 0.9)
        length = sheet["height"] * rng.uniform(0.55, 1.1)
        blade(soft, base, az, rng.uniform(6, sheet["lean"]), length, sheet["width"] * rng.uniform(0.7, 1.2),
              sheet["foot"], mix(sheet["blade"], sheet["tip"], rng.random()), rng)
    return soft


def bluebell(sheet, rng):
    soft = Soft()
    for k in range(4):
        blade(soft, Vector((0, 0, 0)), rng.uniform(0, math.tau), rng.uniform(25, 55), sheet["height"] * rng.uniform(0.6, 0.85),
              0.028, sheet["leaf_deep"], sheet["leaf"], rng, 0.6)
    # the stem rises and nods over to one side, bells hanging from the outside of the curve
    az = rng.uniform(0, math.tau)
    pts, at, el = [Vector((0, 0, 0))], Vector((0, 0, 0)), math.radians(86)
    for k in range(6):
        el -= math.radians(4 + 9 * k * 0.6)
        at = at + heading(az, el) * (sheet["height"] / 5.2)
        pts.append(at.copy())
    stalk(soft, pts, 0.006, sheet["leaf"], sheet["stem"], 0.2, 0.9)
    for k in range(2, len(pts)):
        if k == 2 and rng.random() < 0.5:
            continue
        p = pts[k]
        t = k / (len(pts) - 1)
        out = heading(az + rng.uniform(-0.5, 0.5), -0.5)
        mouth = p + out * 0.02 - UP * sheet["bell"]
        col = mix(sheet["bell_deep"], sheet["bell_light"], rng.uniform(0.2, 0.9))
        a, b = frame((mouth - p).normalized())
        rim = []
        for j in range(5):
            dj = a * math.cos(j * math.tau / 5) + b * math.sin(j * math.tau / 5)
            rim.append(soft.vert(mouth + dj * sheet["bell"] * 0.42 + (mouth - p).normalized() * 0.004, (dj + UP * 0.3).normalized()))
        mid = [soft.vert(p + (mouth - p) * 0.55 + (a * math.cos(j * math.tau / 5) + b * math.sin(j * math.tau / 5)) * sheet["bell"] * 0.2,
                         a * math.cos(j * math.tau / 5) + b * math.sin(j * math.tau / 5)) for j in range(5)]
        top = soft.vert(p, UP)
        for j in range(5):
            soft.face((top, mid[(j + 1) % 5], mid[j]), (sheet["bell_deep"], col, col), 0.5 + 0.4 * t)
            soft.face((mid[j], mid[(j + 1) % 5], rim[(j + 1) % 5], rim[j]), (col, col, sheet["bell_light"], sheet["bell_light"]), 0.5 + 0.4 * t)
    return soft


def snowdrop(sheet, rng):
    soft = Soft()
    for stem_k in range(sheet.get("stems", 3)):
        off = Vector((rng.uniform(-0.04, 0.04), rng.uniform(-0.04, 0.04), 0.0))
        for k in range(2):
            blade(soft, off, rng.uniform(0, math.tau), rng.uniform(8, 22), sheet["height"] * rng.uniform(0.6, 0.8), 0.012,
                  sheet["leaf_deep"], sheet["leaf"], rng, 0.5, 2)
        az = rng.uniform(0, math.tau)
        hgt = sheet["height"] * rng.uniform(0.85, 1.1)
        pts = [off, off + UP * hgt * 0.6 + heading(az, 0) * 0.005, off + UP * hgt + heading(az, 0) * 0.02, off + UP * hgt * 0.97 + heading(az, 0) * 0.045]
        stalk(soft, pts, 0.004, sheet["leaf"], sheet["leaf"], 0.2, 0.8)
        hang = pts[-1]
        for j in range(3):   # three white outer petals hanging like a drop
            d = heading(az + j * 2.094 + 0.4, 0.0)
            leaf(soft, OUTLINES["petal"], hang, (d * 0.42 - UP).normalized(), d, sheet["petal"], sheet["white"], sheet["white_tip"], 0.85, (d - UP * 0.3).normalized(), 0.3)
        cup = soft.vert(hang - UP * sheet["petal"] * 0.5, -UP)
        ring = [soft.vert(hang - UP * sheet["petal"] * 0.25 + heading(az + j * 2.094 + 1.45, 0) * sheet["petal"] * 0.16, heading(az + j * 2.094 + 1.45, 0)) for j in range(3)]
        for j in range(3):
            soft.face((ring[j], cup, ring[(j + 1) % 3]), (sheet["white"], sheet["green_mark"], sheet["white"]), 0.85)
    return soft


def crocus(sheet, rng):
    soft = Soft()
    for stem_k in range(sheet.get("stems", 3)):
        off = Vector((rng.uniform(-0.05, 0.05), rng.uniform(-0.05, 0.05), 0.0))
        for k in range(3):
            blade(soft, off, rng.uniform(0, math.tau), rng.uniform(10, 35), sheet["height"] * rng.uniform(0.8, 1.2), 0.008,
                  sheet["leaf_deep"], sheet["leaf"], rng, 0.5, 2)
        col_deep, col, col_light = rng.choice(sheet["colours"])
        hgt = sheet["height"] * rng.uniform(0.45, 0.6)
        stalk(soft, [off, off + UP * hgt], 0.006, sheet["leaf"], mix(sheet["white"], col, 0.5), 0.1, 0.4)
        cup_open = rng.uniform(0.18, 0.5)
        rot = rng.uniform(0, math.tau)
        for j in range(6):   # a goblet of six petals, three inside three
            d = heading(rot + j * math.tau / 6, 0.0)
            tilt = cup_open * (1.25 if j % 2 else 0.85)
            leaf(soft, OUTLINES["petal"], off + UP * hgt, (UP + d * tilt).normalized(), d, sheet["petal"] * (1.0 if j % 2 else 0.92),
                 col_deep, col_light if j % 2 else col, 0.5, (d * 0.6 + UP * 0.6).normalized(), 0.4)
        heart = soft.vert(off + UP * (hgt + sheet["petal"] * 0.55), UP)
        ring = [soft.vert(off + UP * (hgt + sheet["petal"] * 0.2) + heading(j * 2.094, 0) * 0.006, heading(j * 2.094, 0)) for j in range(3)]
        for j in range(3):
            soft.face((ring[j], ring[(j + 1) % 3], heart), (sheet["gold"],) * 3, 0.5, 0.15)
    return soft


def fern(sheet, rng):
    soft = Soft()
    n = sheet["fronds"]
    for k in range(n):
        az = math.tau * k / n + rng.uniform(-0.3, 0.3)
        length = sheet["height"] * rng.uniform(0.8, 1.2)
        d = heading(az, 0.0)
        side = Vector((-d.y, d.x, 0.0))
        at, el = Vector((0, 0, 0)), math.radians(rng.uniform(62, 78))
        segs = 7
        spine = []
        for s in range(segs + 1):
            spine.append(at.copy())
            el -= math.radians(rng.uniform(13, 19))
            at = at + heading(az, el) * (length / segs)
        for s in range(segs):
            t = (s + 0.5) / segs
            w = length * 0.26 * math.sin(math.pi * (0.12 + 0.88 * t) ** 0.8)
            a, b = spine[s], spine[s + 1]
            fwd = (b - a).normalized()
            up_n = side.cross(fwd).normalized()
            col0 = mix(sheet["deep"], sheet["mid"], t)
            col1 = mix(sheet["mid"], sheet["light"], t)
            for sgn in (-1, 1):   # a pair of pinnae swept toward the tip
                tipp = a + side * sgn * w + fwd * (w * 0.45) - up_n * (w * 0.12)
                i0 = soft.vert(a, (UP * 0.7 + up_n * 0.3).normalized())
                i1 = soft.vert(b, (UP * 0.7 + up_n * 0.3).normalized())
                i2 = soft.vert(tipp, (UP * 0.7 + up_n * 0.3).normalized())
                fx = 0.3 + 0.6 * t
                soft.face((i0, i1, i2) if sgn > 0 else (i0, i2, i1), (col0, col0, col1), fx)
    return soft


def patch(make, sheet, rng, count, radius, size=(0.8, 1.2)):
    """Several of one small plant growing together: what a drift is made of.
    Thick at the heart, thinning to the rim, each plant turned and sized its
    own way."""
    soft = Soft()
    for k in range(count):
        one = make(sheet, rng)
        a = rng.uniform(0, math.tau)
        rr = radius * rng.random() ** 0.75
        turn = rng.uniform(0, math.tau)
        s = rng.uniform(*size)
        ca, sa = math.cos(turn), math.sin(turn)
        off = Vector((math.cos(a) * rr, math.sin(a) * rr, 0.0))
        base = len(soft.verts)
        for v, n in zip(one.verts, one.normals):
            soft.verts.append(Vector(((v.x * ca - v.y * sa) * s, (v.x * sa + v.y * ca) * s, v.z * s)) + off)
            soft.normals.append(Vector((n.x * ca - n.y * sa, n.x * sa + n.y * ca, n.z)))
        for f, c, u in zip(one.faces, one.cols, one.uvs):
            soft.faces.append(tuple(i + base for i in f))
            soft.cols.append(c)
            soft.uvs.append(u)
    return soft


def far_patch(tops, leaf, height, radius, rng):
    """What a patch of flowers is from far off: a low faceted cushion, the
    flowers' colours over its top and the leaves' round its skirt. A flower is
    less than a pixel wide past sixty metres; the drift's colour still has to
    carry across a valley."""
    soft = Soft()
    n = 6
    turn = rng.uniform(0, math.tau)
    top = soft.vert((0.0, 0.0, height), UP)
    mid, rim = [], []
    for k in range(n):
        d = heading(turn + k * math.tau / n + rng.uniform(-0.2, 0.2), 0.0)
        lit = (d * 0.3 + UP).normalized()
        mid.append(soft.vert(d * radius * rng.uniform(0.5, 0.7) + UP * height * rng.uniform(0.7, 0.95), lit))
        rim.append(soft.vert(d * radius * rng.uniform(0.95, 1.15) + UP * 0.03, lit))
    for k in range(n):
        j = (k + 1) % n
        c = rng.choice(tops)
        soft.face((top, mid[k], mid[j]), (c, c, c), 0.0)
        c2 = mix(rng.choice(tops), leaf, 0.25)
        soft.face((mid[k], rim[k], rim[j], mid[j]), (c2, leaf, leaf, c2), 0.0)
    return soft
