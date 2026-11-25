"""The lampwing (bestiary §8): creatures/models/fae/lampwing.gltf and
lampwing_albedo.webp, one small moth for a MultiMesh swarm.

It has no skeleton: forty to eighty of them are drawn as one MultiMesh, so
creatures/materials/lampwing.gdshader moves it in the vertex stage. The mesh
tells the shader what each vertex is through its second UV set:

    UV2.x  how far out along a wing the vertex is (0 = body or hinge, 1 = edge)
    UV2.y  how far along a mouth lobe (0 = not a lobe, 1 = its tip)

and through where its first UVs sit in the atlas (QUADS below): fore wing, hind
wing, the body (which is where the light comes from), and the small parts.
The MultiMesh's instance colour stays free as a tint.

    /opt/bpyenv/bin/python tools/blender/monsters/lampwing.py [--preview DIR]
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))

import bpy  # noqa: E402
import numpy as np  # noqa: E402

import kit  # noqa: E402

NAME = "lampwing"
OUT = os.path.join(kit.ROOT, "creatures", "models", "fae")
STATES = os.path.join(kit.ROOT, "data", "animation", "creatures", "lampwing_states.txt")
SIZE = 512

# Blender axes: +y is the way it faces, +x its right wing, +z up. Metres.
HINGE = (0.0055, 0.008, 0.004)                 # where a wing meets the thorax (the shader has the same numbers)
MOUTH = (0.0, 0.0285, 0.001)                   # the middle of the face
# where each kind of part sits in the atlas: (u0, v0, u1, v1)
QUADS = dict(fore=(0.0, 0.5, 0.5, 1.0), hind=(0.5, 0.5, 1.0, 1.0), body=(0.0, 0.0, 0.5, 0.5))
CELLS = ("eye", "inner", "tooth", "tongue", "lobe", "feeler", "leg", "spare")   # the small parts: a 4 x 2 grid in the last quarter; the top row is wet


def cell(name):
    i = CELLS.index(name)
    u0, v0 = 0.5 + 0.125 * (i % 4), 0.25 - 0.25 * (i // 4)
    return (u0, v0, u0 + 0.125, v0 + 0.25)


def _v(*p):
    return np.array(p, dtype=np.float64)


def _unit(v):
    v = np.asarray(v, dtype=np.float64)
    return v / max(np.linalg.norm(v), 1e-12)


class Mesh:
    def __init__(self):
        self.P, self.UV, self.W, self.F = [], [], [], []

    def vert(self, p, rect, st, wing=0.0, lobe=0.0):
        """st = where in its atlas rect (0..1 each way)."""
        u0, v0, u1, v1 = rect
        pad = 0.012
        self.P.append(tuple(float(x) for x in p))
        self.UV.append((u0 + pad + st[0] * (u1 - u0 - 2 * pad), v0 + pad + st[1] * (v1 - v0 - 2 * pad)))
        self.W.append((wing, lobe))
        return len(self.P) - 1

    def face(self, *idx):
        self.F.append(idx)

    def build(self, name):
        me = bpy.data.meshes.new(name)
        me.from_pydata(self.P, [], self.F)
        me.update()
        uv, uv2 = me.uv_layers.new(name="UVMap"), me.uv_layers.new(name="what")
        for loop in me.loops:
            uv.data[loop.index].uv = self.UV[loop.vertex_index]
            uv2.data[loop.index].uv = self.W[loop.vertex_index]
        o = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(o)
        kit.shade_smooth(o)
        return o


# ------------------------------------------------------------------ the mesh

def wing(m, side, kind):
    """One wing as a fan from its hinge: a hinge point, a ring half-way out and
    the rounded edge. Faces wind so the upper side is the front."""
    if kind == "fore":
        a0, a1, segs, reach, peak, z = 62.0, -28.0, 7, 0.0665, 24.0, 0.0
    else:
        a0, a1, segs, reach, peak, z = -20.0, -112.0, 6, 0.047, -62.0, -0.0012
    h = _v(HINGE[0], HINGE[1] - (0.0 if kind == "fore" else 0.004), HINGE[2] + z)

    def at(k, f):
        t = k / segs
        a = math.radians(a0 + (a1 - a0) * t)
        r = reach * (0.8 + 0.2 * math.cos(math.radians((a0 + (a1 - a0) * t - peak) * 2.0))) * (0.9 + 0.1 * math.sin(math.pi * t) ** 0.5)
        p = h + _v(math.cos(a), math.sin(a), 0.0) * r * f
        p[2] += 0.004 * math.sin(math.pi * f) * (0.4 + 0.6 * math.sin(math.pi * t)) - 0.002 * f * f    # a little camber, the edge dipped
        p[0] *= side
        return m.vert(p, QUADS[kind], (t, f), wing=f)

    root = [at(k, 0.0) for k in range(segs + 1)]                    # one point in space, a row in the atlas
    mid = [at(k, 0.52) for k in range(segs + 1)]
    edge = [at(k, 1.0) for k in range(segs + 1)]
    for k in range(segs):
        for a, b in ((root, mid), (mid, edge)):
            q = (a[k], a[k + 1], b[k + 1], b[k]) if a is not root else (a[k], b[k + 1], b[k])
            m.face(*(q if side > 0 else tuple(reversed(q))))


def body(m):
    """Abdomen and thorax as one furred spindle, 8 round."""
    rings = [(-0.034, 0.0015), (-0.026, 0.0052), (-0.012, 0.0068), (0.002, 0.0074), (0.012, 0.0086), (0.02, 0.0066)]
    R = 8
    loops = []
    for i, (y, r) in enumerate(rings):
        droop = -0.004 * max(0.0, (-y - 0.005) / 0.03) ** 2                     # the abdomen hangs a little
        loops.append([m.vert((math.cos(2 * math.pi * j / R) * r, y, math.sin(2 * math.pi * j / R) * r * 0.92 + droop), QUADS["body"],
                             (j / R, i / (len(rings) - 1))) for j in range(R)])
    for a, b in zip(loops[:-1], loops[1:]):
        for j in range(R):
            m.face(a[j], b[j], b[(j + 1) % R], a[(j + 1) % R])
    tail = m.vert((0.0, -0.0375, -0.0045), QUADS["body"], (0.5, 0.0))
    for j in range(R):
        m.face(loops[0][(j + 1) % R], tail, loops[0][j])
    return loops[-1]


def head(m, neck):
    """The face: two great black eyes, and a snout that is four furred lobes
    closed to a point. Open (the shader spreads them) they show a wet throat,
    a ring of needle teeth and a curled tongue."""
    R = len(neck)
    y0 = 0.0245
    ring = [m.vert((math.cos(2 * math.pi * j / R) * 0.0058, y0, math.sin(2 * math.pi * j / R) * 0.0055 + MOUTH[2]), QUADS["body"], (j / R, 1.0)) for j in range(R)]
    for j in range(R):
        m.face(neck[j], ring[j], ring[(j + 1) % R], neck[(j + 1) % R])
    # the lobes: up, right, down, left; each a kite from the ring to the point
    for q in range(4):
        a = math.pi / 2 - q * math.pi / 2
        d = _v(math.cos(a), 0.0, math.sin(a))
        s = _v(-d[2], 0.0, d[0])
        base = _v(MOUTH[0], y0, MOUTH[2])
        b0 = m.vert(base + (d * 0.72 + s * 0.72) * 0.0056, cell("lobe"), (0.0, 0.0), lobe=0.0)
        b1 = m.vert(base + (d * 0.72 - s * 0.72) * 0.0056, cell("lobe"), (1.0, 0.0), lobe=0.0)
        mid = m.vert(base + d * 0.0052 + _v(0, 0.004, 0), cell("lobe"), (0.5, 0.5), lobe=0.55)
        tip = m.vert(base + d * 0.0006 + _v(0, 0.0085, 0), cell("lobe"), (0.5, 1.0), lobe=1.0)
        m.face(b0, mid, b1)
        m.face(b0, tip, mid)
        m.face(mid, tip, b1)
        # its inner side, wet (a second skin just inside the first)
        i0 = m.vert(base + (d * 0.7 + s * 0.7) * 0.005, cell("inner"), (0.0, 0.0), lobe=0.0)
        i1 = m.vert(base + (d * 0.7 - s * 0.7) * 0.005, cell("inner"), (1.0, 0.0), lobe=0.0)
        it = m.vert(base + d * 0.0003 + _v(0, 0.0078, 0), cell("inner"), (0.5, 1.0), lobe=1.0)
        m.face(i0, i1, it)
    # the throat and its teeth
    base = _v(MOUTH[0], y0 + 0.0005, MOUTH[2])
    back = m.vert(base - _v(0, 0.004, 0), cell("inner"), (0.5, 0.1))
    rim = [m.vert(base + _v(math.cos(2 * math.pi * j / 8), 0.0, math.sin(2 * math.pi * j / 8)) * 0.0046, cell("inner"), (j / 8, 0.9)) for j in range(8)]
    for j in range(8):
        m.face(rim[j], back, rim[(j + 1) % 8])
    for j in range(8):
        a = 2 * math.pi * (j + 0.5) / 8
        r = _v(math.cos(a), 0.0, math.sin(a))
        t = _v(-r[2], 0.0, r[0])
        p = base + r * 0.0043
        m.face(m.vert(p + t * 0.0009, cell("tooth"), (0.0, 0.0)), m.vert(p - t * 0.0009, cell("tooth"), (1.0, 0.0)),
               m.vert(p - r * 0.0024 + _v(0, 0.0062, 0), cell("tooth"), (0.5, 1.0)))
    # the tongue: a curled strip in the middle of it
    pts = [(0.0, -0.002), (0.0035, -0.001), (0.0052, 0.0012), (0.0036, 0.0028), (0.0018, 0.0016)]
    strip = [(m.vert(base + _v(-0.0006, y, z - 0.0008), cell("tongue"), (0.0, i / 4)), m.vert(base + _v(0.0006, y, z - 0.0008), cell("tongue"), (1.0, i / 4)))
             for i, (y, z) in enumerate(pts)]
    for a, b in zip(strip[:-1], strip[1:]):
        m.face(a[0], a[1], b[1], b[0])
    # eyes
    for side in (1.0, -1.0):
        c = _v(side * 0.0056, 0.0222, 0.0032)
        out = _unit(_v(side * 0.8, 0.35, 0.45))
        x = _unit(np.cross(out, (0, 0, 1)))
        y = np.cross(out, x)
        top = m.vert(c + out * 0.0034, cell("eye"), (0.5, 0.5))
        rim = [m.vert(c + (x * math.cos(2 * math.pi * j / 6) + y * math.sin(2 * math.pi * j / 6)) * 0.0036, cell("eye"), (0.5 + 0.5 * math.cos(2 * math.pi * j / 6), 0.5 + 0.5 * math.sin(2 * math.pi * j / 6)))
               for j in range(6)]
        for j in range(6):
            q = (rim[j], rim[(j + 1) % 6], top)
            m.face(*q)
    # feelers: two feathered blades swept back
    for side in (1.0, -1.0):
        a = _v(side * 0.003, 0.0235, 0.0058)
        d = _unit(_v(side * 0.75, 0.25, 0.6))
        w = _unit(np.cross(d, (0, 1, 0))) * 0.0019
        mid = a + d * 0.012 + _v(0, -0.002, 0.001)
        end = a + d * 0.022 + _v(0, -0.008, 0.0)
        q = [m.vert(a, cell("feeler"), (0.5, 0.0)), m.vert(mid + w, cell("feeler"), (1.0, 0.5)), m.vert(end, cell("feeler"), (0.5, 1.0)), m.vert(mid - w, cell("feeler"), (0.0, 0.5))]
        m.face(*q)
    # legs, drawn up under the thorax
    for side in (1.0, -1.0):
        for k, y in enumerate((0.016, 0.009, 0.002)):
            a = _v(side * 0.003, y, -0.005)
            m.face(m.vert(a + _v(0, 0.0012, 0), cell("leg"), (0.0, 0.0)), m.vert(a - _v(0, 0.0012, 0), cell("leg"), (1.0, 0.0)),
                   m.vert(a + _v(side * 0.006, 0.002 - 0.003 * k, -0.007), cell("leg"), (0.5, 1.0)))


# ------------------------------------------------------------------ the atlas

def _enc(x):
    x = np.clip(x, 0.0, 1.0)
    return np.where(x <= 0.0031308, x * 12.92, 1.055 * x ** (1.0 / 2.4) - 0.055)


def _noise(shape, cells, seed):
    r = np.random.default_rng(seed).random((cells[0] + 2, cells[1] + 2))
    y = np.linspace(0, cells[0], shape[0], endpoint=False)
    x = np.linspace(0, cells[1], shape[1], endpoint=False)
    yi, xi = y.astype(int), x.astype(int)
    fy, fx = (y - yi)[:, None], (x - xi)[None, :]
    fy, fx = fy * fy * (3 - 2 * fy), fx * fx * (3 - 2 * fx)
    a, b, c, d = r[yi][:, xi], r[yi][:, xi + 1], r[yi + 1][:, xi], r[yi + 1][:, xi + 1]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


PEARL, BLUSH, PLUM = _v(0.6, 0.57, 0.55), _v(0.7, 0.36, 0.44), _v(0.12, 0.05, 0.1)
FUR, FUR_PALE = _v(0.36, 0.3, 0.29), _v(0.56, 0.5, 0.47)


def paint():
    """The albedo atlas (linear colour in, sRGB out). Rows run bottom to top."""
    A = np.zeros((SIZE, SIZE, 3))

    def region(rect):
        u0, v0, u1, v1 = rect
        ys, xs = slice(int(v0 * SIZE), int(v1 * SIZE)), slice(int(u0 * SIZE), int(u1 * SIZE))
        h, w = ys.stop - ys.start, xs.stop - xs.start
        return ys, xs, np.linspace(0, 1, h)[:, None] * np.ones((1, w)), np.ones((h, 1)) * np.linspace(0, 1, w)[None, :]

    # wings: s runs round the wing (leading edge to trailing), t from the hinge out to the edge
    for kind, veins, spot in (("fore", 9, (0.42, 0.63)), ("hind", 7, (0.5, 0.6))):
        ys, xs, t, s = region(QUADS[kind])
        col = PEARL[None, None, :] * (1.0 - kit.ss((t - 0.45) / 0.5))[:, :, None] + BLUSH[None, None, :] * kit.ss((t - 0.45) / 0.5)[:, :, None]
        col = col * (0.82 + 0.18 * kit.ss(t / 0.25))[:, :, None]                         # shaded toward the body, furred there
        vein = np.exp(-((((s * veins) % 1.0) - 0.5) / 0.05) ** 2) * kit.ss((t - 0.08) / 0.2)
        col = col * (1.0 - 0.3 * vein)[:, :, None]
        band = np.exp(-((t - 0.8 + 0.03 * np.sin(s * veins * 2 * np.pi)) / 0.03) ** 2)   # a scalloped line inside the margin
        col = col * (1.0 - 0.35 * band)[:, :, None] + (PLUM * 0.6)[None, None, :] * (0.35 * band)[:, :, None]
        d = np.sqrt(((s - spot[0]) / 0.17) ** 2 + ((t - spot[1]) / 0.13) ** 2)           # the eye-spot: a pale pupil in a plum ring in a pale ring
        ring, pupil, halo = np.exp(-((d - 0.62) / 0.2) ** 2), np.exp(-(d / 0.3) ** 2), np.exp(-((d - 1.05) / 0.16) ** 2)
        col = col * (1.0 - 0.8 * ring)[:, :, None] + PLUM[None, None, :] * (0.8 * ring)[:, :, None]
        col = col * (1.0 - 0.5 * halo)[:, :, None] + (PEARL * 1.1)[None, None, :] * (0.5 * halo)[:, :, None]
        col = col * (1.0 - 0.7 * pupil)[:, :, None] + (PEARL * 1.12)[None, None, :] * (0.7 * pupil)[:, :, None]
        dust = np.random.default_rng(11 if kind == "fore" else 12).random(t.shape)
        col = col * (0.94 + 0.1 * dust * (dust > 0.7))[:, :, None] * (0.95 + 0.08 * _noise(t.shape, (9, 9), 2))[:, :, None]
        A[ys, xs] = np.minimum(col, 0.85)

    # the body: fur, in rings down the abdomen, paler on the thorax
    ys, xs, t, s = region(QUADS["body"])
    fur = _noise(t.shape, (10, 90), 4)
    rings = 0.5 + 0.5 * np.sin(t * 2 * np.pi * 7.0)
    lum = (0.8 + 0.3 * fur) * (1.0 - 0.22 * rings * (t < 0.62))
    col = FUR[None, None, :] * (1.0 - kit.ss((t - 0.5) / 0.3))[:, :, None] + FUR_PALE[None, None, :] * kit.ss((t - 0.5) / 0.3)[:, :, None]
    A[ys, xs] = np.minimum(col * lum[:, :, None], 0.85)

    flat = dict(eye=(0.006, 0.005, 0.008), inner=(0.42, 0.03, 0.07), tooth=(0.7, 0.66, 0.56), tongue=(0.1, 0.02, 0.05),
                lobe=tuple(FUR_PALE), feeler=tuple(FUR * 0.8), leg=(0.07, 0.05, 0.05), spare=(0.2, 0.2, 0.2))
    for name, rgb in flat.items():
        ys, xs, t, s = region(cell(name))
        lum = np.ones_like(t)
        if name == "inner":
            lum = 0.35 + 0.65 * t                                                       # darker down the throat
        elif name == "feeler":
            lum = 0.55 + 0.45 * (np.sin(t * 2 * np.pi * 9.0) > 0.0) * (np.abs(s - 0.5) > 0.12)   # a comb either side of the shaft
        elif name == "lobe":
            lum = 0.85 + 0.2 * _noise(t.shape, (6, 14), 6)
        elif name == "tooth":
            lum = 0.75 + 0.25 * t
        A[ys, xs] = np.asarray(rgb)[None, None, :] * lum[:, :, None]

    img = bpy.data.images.new(NAME + "_albedo", SIZE, SIZE, alpha=False, float_buffer=False)
    img.colorspace_settings.name = "sRGB"
    px = np.ones((SIZE, SIZE, 4), dtype=np.float32)
    px[:, :, :3] = _enc(A)
    img.pixels.foreach_set(px.ravel())
    os.makedirs(OUT, exist_ok=True)
    return img, kit._save(img, os.path.join(OUT, f"{NAME}_albedo.webp"))


# What L75's swarm sets per moth (INSTANCE_CUSTOM, or the material's uniforms of
# the same names) for each beat of bestiary §8.2. The swarm moves the moths;
# these only pose them.
ROWS = (("roost", 1.0, 0.0, 0.0, 0.0, "-", "wings shut upright over the back, grey undersides out, light out"),
        ("feed", 0.0, 0.12, 0.0, 1.0, "-", "wings slowly opening and closing"),
        ("flutter", 0.0, 1.0, 0.0, 1.0, "-", "the ordinary flight"),
        ("swarm", 0.0, 1.8, 0.0, 1.0, "-", "fast flutter"),
        ("bite", 0.0, 1.8, 1.0, 1.0, "0.3", "mouth 0 to 1 by 0.12 s and back to 0 by 0.3 s, while the swarm darts it in"),
        ("scatter", 0.0, 2.4, 0.0, 1.0, "-", "a burst away; the swarm tumbles it"),
        ("fall", 0.6, 0.0, 0.0, 0.0, "-", "wings half shut and still, light out; the swarm spirals it down"))


def write_states():
    os.makedirs(os.path.dirname(STATES), exist_ok=True)
    with open(STATES, "w") as f:
        f.write(f"# lampwing poses (creatures/models/fae/{NAME}.gltf, creatures/materials/lampwing.gdshader). Written by tools/blender/monsters/lampwing.py.\n")
        f.write("# name fold rate mouth light duration_s   # what it shows   ('-' = holds or loops)\n")
        for name, fold, rate, mouth, light, dur, note in ROWS:
            f.write(f"{name} {fold:.2f} {rate:.2f} {mouth:.2f} {light:.2f} {dur}   # {note}\n")


def build():
    kit.reset()
    m = Mesh()
    neck = body(m)
    head(m, neck)
    for side in (1.0, -1.0):
        wing(m, side, "hind")
        wing(m, side, "fore")
    o = m.build(NAME)
    kit.triangulate(o)
    img, path = paint()
    mat = bpy.data.materials.new(NAME)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    tex = nt.nodes.new("ShaderNodeTexImage")
    img.source = "FILE"
    img.filepath = path
    img.reload()
    tex.image = img
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    kit.set_material(o, mat)
    return o


if __name__ == "__main__":
    args = sys.argv[1:]
    low = build()
    print(f"{NAME}: {kit.tris(low)} tris")
    if "--preview" in args:
        import preview
        d = args[args.index("--preview") + 1]
        preview.shot(os.path.join(d, f"{NAME}_top.png"), ((0.0, 0.0, 0.3), (0, 0, 0), 50), samples=16, res=(900, 700))
        preview.shot(os.path.join(d, f"{NAME}_q.png"), ((0.12, 0.16, 0.1), (0, 0, 0), 60), samples=16, res=(900, 700))
    if "--noexport" not in args:
        path = kit.export_gltf(NAME, [low], OUT)
        write_states()
        print(f"{NAME}: {kit.tris(low)} tris -> {path}")
