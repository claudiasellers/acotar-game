"""The gloamer (bestiary §16): creatures/models/fae/gloamer.gltf with its
textures, skeleton and clips, and data/animation/creatures/gloamer_gaits.txt.

    /opt/bpyenv/bin/python tools/blender/monsters/gloamer.py [--preview DIR views...] [--fast]

--preview DIR also renders check sheets there. --fast bakes 1K maps and a
coarser sculpt, for iterating; never commit a --fast build.

One skinned mesh under one material: skin, teeth, eyes, lids, lank hair and a
cord of stolen trinkets (a coin, a ring, a key) that swings on its own bones.
Packs of five are on screen at once, so the whole thing is under 8,000
triangles with 2K maps.
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))

import bpy  # noqa: E402
import bmesh  # noqa: E402,I001
import numpy as np  # noqa: E402

import gloamer_body as gb  # noqa: E402
import gloamer_clips  # noqa: E402
import gloamer_rig  # noqa: E402
import kit  # noqa: E402
import rig  # noqa: E402
from hob import _metal, _ngon, _rope, _scaled, blade, box, grad_material, sweep  # noqa: E402
from hob_body import _onto  # noqa: E402

NAME = "gloamer"
OUT = os.path.join(kit.ROOT, "creatures", "models", "fae")
BODY_TRIS = 6300

# part numbers on the game mesh (kit.tag): 0 skin, 1 upper teeth, 2 lower
# teeth, 10 eyes, 11/12 lids (right/left), 20 hair, 60 the cord, 71..73 the trinkets.


# ------------------------------------------------------------------ materials

BARK = (0.2, 0.135, 0.07)
BARK_DARK = (0.075, 0.052, 0.03)
BARK_RED = (0.24, 0.12, 0.06)
LICHEN = (0.2, 0.25, 0.09)
LICHEN_PALE = (0.36, 0.4, 0.2)
FURROW = (0.045, 0.034, 0.022)
MOSS = (0.11, 0.17, 0.045)
MOSS_DARK = (0.035, 0.065, 0.02)
DUN = (0.43, 0.34, 0.19)
THROAT = (0.62, 0.5, 0.34)
MOUTH = (0.1, 0.028, 0.032)
NAIL = (0.04, 0.032, 0.026)


def skin_material():
    """Bark: long plates split by furrows that run down the limbs, mottled
    lichen-green over bark-brown, moss in the furrows of the back, dun on the
    belly, a pale soft throat. The face and the knuckles are worn smooth."""
    def build(nt, bsdf):
        g = kit.Graph(nt)
        P = g.position()
        moss, mouth, up = g.split(g.attr("zone_a"))
        nail, soft, throat = g.split(g.attr("zone_b"))
        sheen, _, _ = g.split(g.attr("zone_c"))
        Pw = g.nt.nodes.new("ShaderNodeVectorMath")
        Pw.operation = "ADD"
        nt.links.new(P, Pw.inputs[0])
        nt.links.new(g.combine(g.math("MULTIPLY", g.math("SUBTRACT", g.noise(P, 7.0, 3.0), 0.5), 0.16),
                               g.math("MULTIPLY", g.math("SUBTRACT", g.noise(P, 8.3, 3.0), 0.5), 0.16),
                               g.math("MULTIPLY", g.math("SUBTRACT", g.noise(P, 6.1, 3.0), 0.5), 0.1)), Pw.inputs[1])
        Pw = Pw.outputs["Vector"]
        long = g.scale_vec(Pw, (1.0, 1.0, 0.3))                      # plates three times as tall as wide
        e1, _ = g.voronoi(long, 15.0)
        _, cell = g.voronoi(long, 15.0, feature="F1")
        plate, _, _ = g.split(cell)
        e2, _ = g.voronoi(g.scale_vec(Pw, (1.0, 1.0, 0.5)), 70.0)
        smooth_skin = g.math("MAXIMUM", g.math("MAXIMUM", soft, throat), sheen)
        wide = g.math("ADD", 0.05, g.math("MULTIPLY", g.noise(P, 14.0, 2.0), 0.12))
        furrow = g.math("SUBTRACT", 1.0, g.smooth(e1, 0.0, wide))
        fine = g.math("MULTIPLY", g.math("SUBTRACT", 1.0, g.smooth(e2, 0.0, 0.05)), 0.18)
        crack = g.math("MAXIMUM", furrow, fine)
        crack = g.math("MULTIPLY", crack, g.math("SUBTRACT", 1.0, g.math("MULTIPLY", smooth_skin, 0.75)))
        # the mottle: lichen-green in big blotches over bark-brown, each plate its own shade
        blotch = g.smooth(g.noise(P, 5.5, 4.0, 0.6), 0.5, 0.64)
        grain = g.noise(g.scale_vec(P, (1.0, 1.0, 0.25)), 150.0, 3.0)
        base = g.mix_rgb(g.smooth(g.noise(P, 30.0, 3.0), 0.3, 0.7), BARK_DARK, BARK)
        base = g.mix_rgb(g.math("MULTIPLY", g.smooth(g.noise(P, 3.1, 3.0), 0.45, 0.7), 0.5), base, BARK_RED)
        green = g.mix_rgb(g.smooth(g.noise(P, 38.0, 3.0, 0.7), 0.5, 0.75), LICHEN, LICHEN_PALE)
        base = g.mix_rgb(g.math("MULTIPLY", blotch, 0.6), base, green)
        base = _scaled(g, base, g.math("ADD", 0.78, g.math("MULTIPLY", plate, 0.4)))
        base = _scaled(g, base, g.math("ADD", 0.88, g.math("MULTIPLY", grain, 0.24)))
        dun = g.mix_rgb(g.smooth(g.noise(P, 24.0, 3.0), 0.3, 0.7), DUN, (0.34, 0.26, 0.14))
        base = g.mix_rgb(g.math("MULTIPLY", soft, 0.65), base, dun)
        base = g.mix_rgb(throat, base, g.mix_rgb(g.noise(P, 60.0, 2.0), THROAT, (0.55, 0.4, 0.3)))
        col = g.mix_rgb(crack, base, FURROW)
        # moss: a film on the back and shoulders, and down every furrow that faces the sky
        edge_n = g.math("MULTIPLY", g.math("SUBTRACT", g.noise(P, 16.0, 4.0, 0.7), 0.5), 1.6)
        mfac = g.math("MULTIPLY", g.smooth(g.math("ADD", moss, edge_n), 0.6, 0.8), 0.85)
        creep = g.math("MULTIPLY", crack, g.smooth(g.math("ADD", moss, g.math("MULTIPLY", up, 0.35)), 0.1, 0.4))
        mfac = g.math("MAXIMUM", mfac, g.math("MULTIPLY", creep, 0.9))
        mcol = g.mix_rgb(g.noise(P, 140.0, 3.0), MOSS_DARK, MOSS)
        col = g.mix_rgb(mfac, col, mcol)
        col = g.mix_rgb(nail, col, NAIL)
        col = g.mix_rgb(mouth, col, MOUTH)
        wet = g.math("MAXIMUM", nail, mouth)
        bark_h = g.math("ADD", g.math("MULTIPLY", crack, -1.0), g.math("ADD", g.math("MULTIPLY", grain, 0.3), g.math("MULTIPLY", plate, 0.3)))
        bark_h = g.math("MULTIPLY", bark_h, g.math("SUBTRACT", 1.0, g.math("MULTIPLY", smooth_skin, 0.6)))
        moss_h = g.math("ADD", g.math("MULTIPLY", g.noise(P, 420.0, 2.0), 0.6), g.math("MULTIPLY", g.noise(P, 100.0, 3.0), 0.7))
        height = g.mix(mfac, bark_h, moss_h)
        height = g.mix(wet, height, g.math("MULTIPLY", grain, 0.1))
        rough = g.mix(crack, 0.78, 0.95)
        rough = g.mix(soft, rough, 0.7)
        rough = g.mix(throat, rough, 0.5)
        rough = g.mix(g.math("MULTIPLY", sheen, 0.85), rough, 0.36)        # worn, greasy: it catches the dusk
        rough = g.mix(mfac, rough, 0.92)
        rough = g.mix(nail, rough, 0.3)
        rough = g.mix(mouth, rough, 0.3)
        g.out(bsdf, color=col, rough=rough, normal=g.bump(height, 0.0035))
    return kit.sculpt_material("gloamer_skin", build)


# ------------------------------------------------------------------ sculpt

def sculpt(voxel):
    """Returns the sculpt, the cord's layout and the hair's roots (read off the clay)."""
    mid, side = gb.forms()
    body = mid + side + [kit.mirror_x(o) for o in side]
    f = kit.field(body)
    knobs = gb.ridge(f)
    f_all = kit.field(body + knobs)
    cord = cord_layout(f_all)
    hair = hair_roots(f_all)
    path = os.environ.get("MONSTER_SCULPT_CACHE")

    def make():
        s = kit.union(body + knobs, "gloamer_sculpt", voxel=voxel)
        kit.carve(s, gb.cutters())
        return s
    if path and os.path.exists(path):
        for o in body + knobs:
            kit._SDF.pop(o.name, None)
            bpy.data.objects.remove(o, do_unlink=True)
    s = kit.cached(path, make)
    s.name = "gloamer_sculpt"
    kit.displace(s, gb.bark_field)
    kit.shade_smooth(s)

    def za(P, N):
        z = gb.zones(P, N)
        return np.stack([z["moss"], z["mouth"], z["up"]], axis=1)

    def zb(P, N):
        z = gb.zones(P, N)
        return np.stack([z["nail"], z["soft"], z["throat"]], axis=1)

    def zc(P, N):
        z = gb.zones(P, N)
        return np.stack([z["sheen"], np.zeros(len(P)), np.zeros(len(P))], axis=1)
    kit.paint(s, "zone_a", za)
    kit.paint(s, "zone_b", zb)
    kit.paint(s, "zone_c", zc)
    kit.set_material(s, skin_material())
    return s, cord, hair


def cord_layout(f):
    """A loop of twine round the neck, lying on the shoulders and hanging to
    the breastbone. Returns dict(path, bottom, hooks)."""
    half = [(0.0, -0.13, 1.4), (0.07, -0.1, 1.42), (0.115, -0.03, 1.4), (0.125, 0.05, 1.34), (0.1, 0.11, 1.27), (0.05, 0.14, 1.22),
            (0.0, 0.15, 1.2)]
    P, N = _onto(f, np.array(half))
    P = P + N * 0.008
    P[0, 0] = P[-1, 0] = 0.0
    loop = [tuple(p) for p in P] + [(-p[0], p[1], p[2]) for p in P[-2:0:-1]]
    n = 22
    pts = loop + [loop[0]]
    C, _ = kit._catmull(pts, [(1.0, 1.0)] * len(pts), n + 1)
    C = np.array(C[:-1])
    bottom = C[np.argmin(C[:, 2])]
    front = sorted([i for i in range(n) if C[i, 1] > 0.08 and C[i, 2] < 1.3], key=lambda i: C[i, 2])
    right = [i for i in front if C[i, 0] > 0.02]
    left = [i for i in front if C[i, 0] < -0.02]
    hooks = [bottom, C[right[min(1, len(right) - 1)]], C[left[min(1, len(left) - 1)]]]
    return dict(path=C, bottom=bottom, hooks=[h + np.array((0, 0.005, -0.006)) for h in hooks])


def hair_roots(f):
    """[(root, normal)]: a thin lank mane from the crown down the nape."""
    rng = np.random.RandomState(4)
    seeds = []
    for k in range(16):
        u = k / 15.0
        seeds.append((0.065 * rng.randn() * (1.0 - 0.3 * u), 0.14 - 0.26 * u, 1.62 - 0.12 * u * u))
    P, N = _onto(f, np.array(seeds))
    return list(zip(P, N))


# ------------------------------------------------------------------ hard parts

def eyelid(side):
    """The upper lid: a cap over the eye, modelled open (lifted back under the
    brow). Turning `eyelid_<side>` forward closes it."""
    r_ = gb.EYE_R * 1.22
    c = gb.EYE * (side, 1, 1)
    o = kit.ball(f"lid{side}", tuple(c), r_, segs=8, rings=8)
    pole = np.array((0.0, -0.42, 0.9))
    pole /= np.linalg.norm(pole)
    bm = bmesh.new()
    bm.from_mesh(o.data)
    gone = [v for v in bm.verts if (np.array(v.co) - c) @ pole < r_ * math.cos(math.radians(78))]
    bmesh.ops.delete(bm, geom=gone, context="VERTS")
    bm.to_mesh(o.data)
    bm.free()
    return o


def hard_parts(cord, hair):
    """Teeth, eyes, lids, hair, the cord and its trinkets, at game resolution.
    Returns [(object, part number)]."""
    out = []
    rng = np.random.RandomState(9)

    def add(o, part, mat):
        if mat is not None:
            kit.set_material(o, mat)
        out.append((kit.tag(o, part), part))

    # small, uneven, yellow teeth: needles and stumps, some missing
    tooth = grad_material("gloamer_tooth", (0.34, 0.24, 0.1), (0.7, 0.62, 0.4), rough=0.35, lo=0.0, hi=0.6)
    for s in (1, -1):
        for i, y in enumerate(np.linspace(0.15, 0.25, 7)):
            if (i, s) in ((1, 1), (4, -1)):
                continue
            w = gb.jaw_half_width(y) * 0.95
            long = 0.006 + 0.008 * rng.rand()
            root = np.array((s * w, y, gb.mouth_z(y) + 0.004))
            add(kit.horn(f"tooth_u{s}{i}", root, root + (s * 0.002 * rng.randn(), 0.002, -long), 0.004 + 0.0025 * rng.rand(),
                         segs=4, rings=2, flat=0.8, tip_r=0.35), 1, tooth)
        for i, y in enumerate(np.linspace(0.16, 0.243, 5)):
            if (i, s) == (2, -1):
                continue
            w = gb.jaw_half_width(y) * 0.84
            long = 0.005 + 0.008 * rng.rand()
            root = np.array((s * w, y, gb.mouth_z(y) - 0.008))
            add(kit.horn(f"tooth_l{s}{i}", root, root + (s * 0.002 * rng.randn(), 0.002, long), 0.004 + 0.002 * rng.rand(),
                         segs=4, rings=2, flat=0.8, tip_r=0.35), 2, tooth)
    eye = kit.plain("gloamer_eye", (0.012, 0.01, 0.01), 0.04)          # small, wet, black
    lid = kit.plain("gloamer_lid", (0.13, 0.1, 0.06), 0.6)
    for s in (1, -1):
        add(kit.ball(f"eye{s}", tuple(gb.EYE * (s, 1, 1)), gb.EYE_R, segs=8, rings=6), 10, eye)
        add(eyelid(s), 11 if s > 0 else 12, lid)

    # lank hair: flat locks off the crown and the nape, hanging back
    lock = grad_material("gloamer_hair", (0.07, 0.055, 0.03), (0.2, 0.16, 0.08), rough=0.55)
    for k, (p, n) in enumerate(hair):
        d = n * 0.15 + np.array((0.5 * np.sign(p[0]) * rng.rand(), -0.8, -0.55)) + rng.normal(size=3) * 0.15
        face = np.cross(d, n + rng.normal(size=3) * 0.3)
        add(blade(f"hair{k}", p - n * 0.004, d, 0.09 + 0.1 * rng.rand(), 0.022 + 0.012 * rng.rand(), face,
                  droop=0.5 + 0.4 * rng.rand(), rings=3), 20, lock)

    # the cord and what it stole
    add(sweep("cord", cord["path"], _ngon(0.0055, 4), closed=True), 60, kit.sculpt_material("gloamer_cord", _rope))
    for i, o in enumerate(trinkets(cord["hooks"])):
        out.append((kit.tag(o, 71 + i), 71 + i))
    return out


def trinkets(hooks):
    """Three things that glint, each under its hook on the cord: a silver coin,
    a brass ring and an iron key."""
    silver = kit.sculpt_material("gloamer_silver", lambda nt, bsdf: _metal(nt, bsdf, (0.62, 0.62, 0.58), (0.3, 0.3, 0.26), 0.3))
    brass = kit.sculpt_material("gloamer_brass", lambda nt, bsdf: _metal(nt, bsdf, (0.6, 0.45, 0.15), (0.24, 0.26, 0.12), 0.34))
    iron = kit.sculpt_material("gloamer_iron", lambda nt, bsdf: _metal(nt, bsdf, (0.12, 0.095, 0.08), (0.3, 0.14, 0.06), 0.7))
    twine = kit.plain("gloamer_twine", (0.3, 0.24, 0.12), 0.9)
    out = []

    def done(i, pieces):
        h = np.asarray(hooks[i])
        t = box(f"twine{i}", tuple(h + (0, 0, -0.012)), (0.003, 0.003, 0.03))
        kit.set_material(t, twine)
        o = kit.join(list(pieces) + [t], f"trinket_{i + 1}")
        kit.shade_smooth(o)
        out.append(o)

    def ring(name, centre, R, r_, mat, turn=0.0, n=8, sides=3):
        pts = [centre + (R * math.sin(2 * math.pi * k / n) * math.cos(turn), R * math.sin(2 * math.pi * k / n) * math.sin(turn),
                         R * math.cos(2 * math.pi * k / n)) for k in range(n)]
        o = sweep(name, pts, _ngon(r_, sides), closed=True, up=(-math.sin(turn), math.cos(turn), 0))
        kit.set_material(o, mat)
        return o

    # 1: a coin with a hole punched through its rim, flat to the chest
    h = np.asarray(hooks[0]) + (0, 0.004, -0.03)
    coin = kit.ball("coin", (0, 0, 0), 1.0, segs=10, rings=4)
    from mathutils import Matrix
    coin.data.transform(Matrix.Translation(h + (0, 0, -0.016)) @ Matrix.Diagonal((0.019, 0.0028, 0.019, 1.0)))
    kit.set_material(coin, silver)
    done(0, [coin])
    # 2: a brass ring
    h = np.asarray(hooks[1]) + (0, 0.004, -0.028)
    done(1, [ring("ring", h + (0, 0, -0.013), 0.013, 0.003, brass, turn=0.5)])
    # 3: an iron key
    h = np.asarray(hooks[2]) + (0, 0.004, -0.028)
    pieces = [ring("key_bow", h + (0, 0, -0.01), 0.01, 0.0026, iron, turn=-0.3, n=6),
              box("key_shaft", tuple(h + (0, 0, -0.04)), (0.004, 0.004, 0.042), rot_z=-0.3),
              box("key_bit", tuple(h + (0.006, -0.002, -0.055)), (0.011, 0.003, 0.012), rot_z=-0.3)]
    for o in pieces[1:]:
        kit.set_material(o, iron)
    done(2, pieces)
    return out


# ------------------------------------------------------------------ build

def build(fast=False, bake=True):
    kit.reset()
    s, cord, hair = sculpt(0.0085 if fast else 0.0055)
    hard = hard_parts(cord, hair)
    low = kit.game_mesh(s, NAME, BODY_TRIS, keep=lambda P: gb.zones(P, np.zeros_like(P))["keep"])
    kit.tag(low, 0)
    arm = rig.build_armature(NAME, gloamer_rig.bones(cord))
    rig.skin(low, arm, fix=gloamer_rig.fix_weights)
    pieces = []
    for o, part in hard:
        g = kit.duplicate(o, o.name + "_g")
        if part == 60:
            # the back of the cord lies on the shoulders; the front hangs with the cord bone
            P = kit.co(g)
            w = kit.ss((P[:, 1] - 0.0) / 0.1)
            for name, col in (("cord", w), ("chest", 1.0 - w)):
                vg = g.vertex_groups.new(name=name)
                for j in np.nonzero(col > 1e-3)[0]:
                    vg.add([int(j)], float(col[j]), "REPLACE")
        else:
            rig.bind_rigid(g, gloamer_rig.part_bone(part))
        pieces.append(g)
    low = kit.join([low] + pieces, NAME)
    kit.triangulate(low)          # the engine's tangents then match the bake's
    if bake:
        # the head gets twice its share of the texture and the trinkets more than theirs
        part = kit.parts_of(low)
        kit.unwrap(low, boost=lambda P: 1.0 + 0.9 * kit.ss((P[:, 2] - 1.4) / 0.04) * kit.ss((P[:, 1] - 0.03) / 0.05) + 1.5 * (part >= 71),
                   centre=(0.0, 0.15, 1.5))
    rig.attach(low, arm)
    paths = {}
    kept = kit.baked_material(low, NAME, OUT) if bake == "keep" else None
    if kept:
        _, paths = kept
    elif bake:
        mat, paths = kit.bake([s] + [o for o, _ in hard], low, NAME, OUT, size=1024 if fast else 2048, extrusion=0.02)
    else:
        kit.set_material(low, kit.plain("clay", (0.3, 0.3, 0.28), 0.7))
    r = rig.Rig(arm, low, gloamer_rig.spec())
    gloamer_clips.author(r)
    r.finish()
    return s, hard, low, arm, r, paths


VIEWS = {
    "front34": ((2.3, 4.2, 1.3), (0, 0, 0.85), 50),
    "side": ((4.8, 0.1, 1.1), (0, 0.05, 0.85), 50),
    "back34": ((-2.2, -4.2, 1.5), (0, 0, 0.85), 50),
    "face": ((0.42, 1.15, 1.56), (0, 0.2, 1.47), 70),
    "face_side": ((1.0, 0.3, 1.5), (0, 0.2, 1.47), 85),
    "hand": ((1.5, 0.8, 0.6), (0.63, 0.03, 0.33), 85),
    "foot": ((0.9, 0.9, 0.35), (0.18, 0.08, 0.08), 70),
    "chest": ((0.5, 1.8, 1.3), (0, 0.15, 1.25), 70),
}

if __name__ == "__main__":
    args = sys.argv[1:]
    fast = "--fast" in args
    s, hard, low, arm, r, paths = build(fast, bake="keep" if "--keepbake" in args else "--nobake" not in args)
    for name, rep in r.report.items():
        print(f"clip {name}: " + " ".join(f"{k}={v:.4f}" for k, v in rep.items()))
    pp = kit.parts_of(low)
    print("verts by part:", {int(k): int((pp == k).sum()) for k in np.unique(pp)})
    print(f"{NAME}: {kit.tris(low)} tris")
    hide = [s] + [o for o, _ in hard]
    if "--preview" in args:
        import preview
        d = args[args.index("--preview") + 1]
        for v in args[args.index("--preview") + 2:]:
            if v.startswith("--"):
                break
            if v in VIEWS:
                preview.shot(os.path.join(d, f"low_{v}.png"), VIEWS[v], hide=hide, samples=12, res=(700, 860))
            elif v.startswith("sculpt_"):
                preview.shot(os.path.join(d, f"{v}.png"), VIEWS[v[7:]], hide=[low] + [o for o, _ in hard], samples=12, res=(700, 860))
            else:
                clip, cam, at = (v.split("@") + ["", ""])[:3]
                views = dict(front=((0.0, 6.0, 1.0), (0, 0, 0.8), 60), q=((4.2, 4.2, 1.4), (0, 0, 0.75), 60),
                             side=((6.0, 0.0, 1.0), (0, 0.0, 0.8), 60), top=((0.2, 1.0, 5.5), (0.2, 0.2, 0.2), 50),
                             back=((-3.6, -4.4, 1.6), (0, 0, 0.75), 60), face=((0.7, 1.9, 1.3), (0, 0.25, 1.2), 60))
                kw = dict(view=views[cam or "q"])
                if at:
                    ts = [float(x) for x in at.split(",")]
                    kw.update(at=ts, frames=len(ts), res=(900, 700))
                preview.strip(arm, low, clip, os.path.join(d, f"clip_{clip}{'_' + cam if cam else ''}.png"), extra=hide, **kw)
    if "--noexport" not in args:
        for o in hide:
            bpy.data.objects.remove(o, do_unlink=True)
        path = kit.export_gltf(NAME, [low, arm], OUT)
        rig.write_gaits(NAME, r, "creatures/models/fae/gloamer.gltf")
        print(f"{NAME}: {kit.tris(low)} tris -> {path}")
