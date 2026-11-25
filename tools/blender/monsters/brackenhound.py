"""The brackenhound (bestiary §17): creatures/models/fae/brackenhound.gltf with
its textures, skeleton and clips, and data/animation/creatures/brackenhound_gaits.txt.

    /opt/bpyenv/bin/python tools/blender/monsters/brackenhound.py [--preview DIR views...] [--fast]

--preview DIR also renders check sheets there. --fast bakes 1K maps and a
coarser sculpt, for iterating; never commit a --fast build.

One skinned mesh under one material: bark, moss and bone, thorn teeth, two
small green glints far back in the sockets, and fern fronds where ears would
be and down the spine, each cluster on its own `frond_<n>` bone. Packs of four
are on screen at once, so the whole thing is under 8,000 triangles with 2K maps.
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))

import bpy  # noqa: E402
import numpy as np  # noqa: E402

import brackenhound_body as bb  # noqa: E402
import brackenhound_clips  # noqa: E402
import brackenhound_rig  # noqa: E402
import kit  # noqa: E402
import rig  # noqa: E402
from hob import _scaled, blade, grad_material  # noqa: E402

NAME = "brackenhound"
OUT = os.path.join(kit.ROOT, "creatures", "models", "fae")
BODY_TRIS = 6300

# part numbers on the game mesh (kit.tag): 0 skin, 1 upper teeth, 2 lower
# teeth, 10 eyes, 60+k the fronds on bone frond_k.


# ------------------------------------------------------------------ materials

BARK = (0.15, 0.1, 0.055)
BARK_DARK = (0.055, 0.04, 0.025)
BARK_GREEN = (0.13, 0.15, 0.06)
FURROW = (0.025, 0.02, 0.014)
MOSS = (0.13, 0.2, 0.05)
MOSS_DARK = (0.04, 0.075, 0.02)
MOSS_PALE = (0.3, 0.36, 0.12)
BONE = (0.66, 0.6, 0.44)
BONE_STAIN = (0.4, 0.33, 0.2)
BONE_CRACK = (0.16, 0.12, 0.07)
KNOT = (0.76, 0.72, 0.58)
MOUTH = (0.07, 0.035, 0.03)
NAIL = (0.05, 0.04, 0.03)


def skin_material():
    """Bark in long plates over the body and legs, moss thick along the back,
    and pale, stained, cracked bone wherever the frame shows through. Bone and
    moss are wet: they catch the last light."""
    def build(nt, bsdf):
        g = kit.Graph(nt)
        P = g.position()
        moss, mouth, up = g.split(g.attr("zone_a"))
        nail, bone, knot = g.split(g.attr("zone_b"))
        Pw = g.nt.nodes.new("ShaderNodeVectorMath")
        Pw.operation = "ADD"
        nt.links.new(P, Pw.inputs[0])
        nt.links.new(g.combine(g.math("MULTIPLY", g.math("SUBTRACT", g.noise(P, 6.0, 3.0), 0.5), 0.2),
                               g.math("MULTIPLY", g.math("SUBTRACT", g.noise(P, 7.3, 3.0), 0.5), 0.14),
                               g.math("MULTIPLY", g.math("SUBTRACT", g.noise(P, 5.1, 3.0), 0.5), 0.2)), Pw.inputs[1])
        Pw = Pw.outputs["Vector"]
        long = g.scale_vec(Pw, (1.0, 0.22, 0.8))                    # plates run along the body
        e1, _ = g.voronoi(long, 24.0)
        _, cell = g.voronoi(long, 24.0, feature="F1")
        plate, _, _ = g.split(cell)
        wide = g.math("ADD", 0.03, g.math("MULTIPLY", g.noise(P, 12.0, 2.0), 0.08))
        furrow = g.math("SUBTRACT", 1.0, g.smooth(e1, 0.0, wide))
        grain = g.noise(g.scale_vec(P, (1.0, 0.3, 1.0)), 130.0, 3.0)
        base = g.mix_rgb(g.smooth(g.noise(P, 26.0, 3.0), 0.3, 0.7), BARK_DARK, BARK)
        base = g.mix_rgb(g.math("MULTIPLY", g.smooth(g.noise(P, 4.5, 4.0, 0.6), 0.5, 0.66), 0.6), base, BARK_GREEN)
        base = _scaled(g, base, g.math("ADD", 0.75, g.math("MULTIPLY", plate, 0.45)))
        base = _scaled(g, base, g.math("ADD", 0.88, g.math("MULTIPLY", grain, 0.24)))
        col = g.mix_rgb(g.math("MULTIPLY", furrow, 0.75), base, FURROW)
        # bone: ivory, stained in the hollows, hair cracks
        e3, _ = g.voronoi(Pw, 60.0)
        hair = g.math("MULTIPLY", g.math("SUBTRACT", 1.0, g.smooth(e3, 0.0, 0.035)), g.smooth(g.noise(P, 9.0, 3.0), 0.45, 0.6))
        bcol = g.mix_rgb(g.smooth(g.noise(P, 14.0, 4.0, 0.65), 0.35, 0.7), BONE_STAIN, BONE)
        bcol = g.mix_rgb(g.math("MULTIPLY", hair, 0.8), bcol, BONE_CRACK)
        bcol = g.mix_rgb(knot, bcol, g.mix_rgb(g.noise(P, 70.0, 3.0), KNOT, (0.66, 0.6, 0.46)))
        bfac = g.smooth(g.math("ADD", bone, g.math("MULTIPLY", g.math("SUBTRACT", g.noise(P, 30.0, 3.0), 0.5), 0.5)), 0.35, 0.6)
        bfac = g.math("MAXIMUM", bfac, knot)
        col = g.mix_rgb(bfac, col, bcol)
        # moss: thick on the back, creeping down the furrows and onto the bone's ledges
        edge_n = g.math("MULTIPLY", g.math("SUBTRACT", g.noise(P, 11.0, 4.0, 0.7), 0.5), 1.2)
        mfac = g.smooth(g.math("ADD", moss, edge_n), 0.62, 0.85)
        creep = g.math("MULTIPLY", g.math("MULTIPLY", furrow, g.smooth(up, 0.1, 0.5)), g.math("SUBTRACT", 1.0, bfac))
        mfac = g.math("MAXIMUM", mfac, g.math("MULTIPLY", creep, 0.9))
        mfac = g.math("MULTIPLY", mfac, g.math("SUBTRACT", 1.0, knot))
        mcol = g.mix_rgb(g.noise(P, 120.0, 3.0), MOSS_DARK, MOSS)
        mcol = g.mix_rgb(g.math("MULTIPLY", g.smooth(g.noise(P, 18.0, 3.0), 0.55, 0.75), 0.5), mcol, MOSS_PALE)
        col = g.mix_rgb(mfac, col, mcol)
        col = g.mix_rgb(nail, col, NAIL)
        col = g.mix_rgb(mouth, col, MOUTH)
        bark_h = g.math("ADD", g.math("MULTIPLY", furrow, -1.0), g.math("ADD", g.math("MULTIPLY", grain, 0.3), g.math("MULTIPLY", plate, 0.35)))
        bone_h = g.math("ADD", g.math("MULTIPLY", hair, -0.5), g.math("MULTIPLY", g.noise(P, 90.0, 3.0), 0.15))
        height = g.mix(bfac, bark_h, bone_h)
        moss_h = g.math("ADD", g.math("MULTIPLY", g.noise(P, 380.0, 2.0), 0.6), g.math("MULTIPLY", g.noise(P, 90.0, 3.0), 0.8))
        height = g.mix(mfac, height, moss_h)
        rough = g.mix(furrow, 0.82, 0.95)
        rough = g.mix(bfac, rough, 0.32)                            # wet bone
        rough = g.mix(mfac, rough, 0.5)                             # wet moss
        rough = g.mix(nail, rough, 0.35)
        rough = g.mix(mouth, rough, 0.3)
        g.out(bsdf, color=col, rough=rough, normal=g.bump(height, 0.004))
    return kit.sculpt_material("brackenhound_skin", build)


def eye_material(side):
    """A small moss-green glint with a pale shine, far back in the socket."""
    def build(nt, bsdf):
        g = kit.Graph(nt)
        g.out(bsdf, color=(0.42, 0.56, 0.2), rough=0.08, emission=(0.5, 0.75, 0.3), strength=0.6)
    return kit.sculpt_material(f"brackenhound_eye{side}", build)


# ------------------------------------------------------------------ sculpt

def sculpt(voxel):
    mid, side = bb.forms()
    body = mid + side + [kit.mirror_x(o) for o in side]
    f = kit.field(body)
    knobs = bb.ridge(f)
    path = os.environ.get("MONSTER_SCULPT_CACHE")

    def make():
        s = kit.union(body + knobs, "brackenhound_sculpt", voxel=voxel)
        kit.carve(s, bb.cutters())
        return s
    if path and os.path.exists(path):
        for o in body + knobs:
            kit._SDF.pop(o.name, None)
            bpy.data.objects.remove(o, do_unlink=True)
    s = kit.cached(path, make)
    s.name = "brackenhound_sculpt"
    kit.displace(s, bb.bark_field)
    kit.shade_smooth(s)

    def za(P, N):
        z = bb.zones(P, N)
        return np.stack([z["moss"], z["mouth"], z["up"]], axis=1)

    def zb(P, N):
        z = bb.zones(P, N)
        return np.stack([z["nail"], z["bone"], z["knot"]], axis=1)
    kit.paint(s, "zone_a", za)
    kit.paint(s, "zone_b", zb)
    kit.set_material(s, skin_material())
    return s


# ------------------------------------------------------------------ hard parts

def hard_parts():
    """Teeth, the eye glints and the fern fronds, at game resolution.
    Returns [(object, part number)]."""
    out = []
    rng = np.random.RandomState(13)

    def add(o, part, mat):
        kit.set_material(o, mat)
        out.append((kit.tag(o, part), part))

    # teeth like thorns: long, thin, uneven, leaning forward
    tooth = grad_material("brackenhound_tooth", (0.4, 0.32, 0.18), (0.72, 0.66, 0.48), rough=0.3, lo=0.0, hi=0.6)
    for s in (1, -1):
        for i, y in enumerate(np.linspace(1.04, 1.315, 8)):
            if (i, s) in ((3, 1), (5, -1)):
                continue
            w = bb.jaw_half_width(y) * 0.92
            long = 0.016 + 0.016 * rng.rand() + (0.012 if i == 6 else 0.0)
            root = np.array((s * w, y, bb.mouth_z(y) + 0.006))
            add(kit.horn(f"tooth_u{s}{i}", root, root + (s * 0.002 * rng.randn(), 0.006, -long), 0.0055 + 0.002 * rng.rand(),
                         segs=4, rings=2, flat=0.8, tip_r=0.2), 1, tooth)
        for i, y in enumerate(np.linspace(1.06, 1.3, 6)):
            w = bb.jaw_half_width(y) * 0.8
            long = 0.014 + 0.014 * rng.rand() + (0.014 if i == 4 else 0.0)
            root = np.array((s * w, y, bb.mouth_z(y) - 0.01))
            add(kit.horn(f"tooth_l{s}{i}", root, root + (s * 0.002 * rng.randn(), 0.005, long), 0.005 + 0.002 * rng.rand(),
                         segs=4, rings=2, flat=0.8, tip_r=0.2), 2, tooth)
        add(kit.ball(f"eye{s}", tuple(bb.EYE * (s, 1, 1)), bb.EYE_R, segs=8, rings=5), 10, eye_material(s))

    # fern fronds: two where ears would be, four clusters down the spine
    fern = grad_material("brackenhound_fern", (0.07, 0.13, 0.04), (0.24, 0.36, 0.1), rough=0.55)
    dry = grad_material("brackenhound_fern_dry", (0.12, 0.13, 0.04), (0.36, 0.3, 0.1), rough=0.6)
    for k, (name, (par, head, tail)) in enumerate(brackenhound_rig.FRONDS.items()):
        head, tail = np.array(head), np.array(tail)
        d0 = (tail - head) / np.linalg.norm(tail - head)
        ear = k < 2
        count = 3 if ear else 5
        for j in range(count):
            fan = (j - (count - 1) / 2.0) / max((count - 1) / 2.0, 1.0)
            if ear:
                d = d0 + np.array((0.0, -0.25 * abs(fan), 0.3 * fan)) + rng.normal(size=3) * 0.06
                face = np.cross(d, (np.sign(head[0]), 0.4, 0.2))
                L, wdt = 0.26 + 0.07 * rng.rand(), 0.085
            else:
                d = d0 + np.array((0.75 * fan, -0.1 * rng.rand(), -0.25 * abs(fan))) + rng.normal(size=3) * 0.08
                face = np.cross(d, (0.0, 1.0, 0.3))
                L, wdt = 0.24 + 0.14 * rng.rand(), 0.1
            root = head + np.array((0.03 * fan * (0 if ear else 1), 0.02 * rng.randn(), -0.02))
            o = blade(f"frond{k}_{j}", root, d, L, wdt, face, droop=0.3 + 0.3 * rng.rand(), zig=0.32, rings=6, gap=0.004)
            add(o, 60 + k, dry if (j + k) % 4 == 3 else fern)
    return out


# ------------------------------------------------------------------ build

def build(fast=False, bake=True):
    kit.reset()
    s = sculpt(0.0095 if fast else 0.006)
    hard = hard_parts()
    low = kit.game_mesh(s, NAME, BODY_TRIS, keep=lambda P: bb.zones(P, np.zeros_like(P))["keep"])
    kit.tag(low, 0)
    arm = rig.build_armature(NAME, brackenhound_rig.bones())
    rig.skin(low, arm, fix=brackenhound_rig.fix_weights)
    pieces = []
    for o, part in hard:
        g = kit.duplicate(o, o.name + "_g")
        rig.bind_rigid(g, brackenhound_rig.part_bone(part))
        pieces.append(g)
    low = kit.join([low] + pieces, NAME)
    kit.triangulate(low)          # the engine's tangents then match the bake's
    if bake:
        kit.unwrap(low, boost=lambda P: 1.0 + 0.9 * kit.ss((P[:, 1] - 0.9) / 0.06), centre=(0.0, 1.1, 1.1))
    rig.attach(low, arm)
    paths = {}
    kept = kit.baked_material(low, NAME, OUT) if bake == "keep" else None
    if kept:
        _, paths = kept
    elif bake:
        mat, paths = kit.bake([s] + [o for o, _ in hard], low, NAME, OUT, size=1024 if fast else 2048, extrusion=0.02)
    else:
        kit.set_material(low, kit.plain("clay", (0.3, 0.3, 0.28), 0.7))
    r = rig.Rig(arm, low, brackenhound_rig.spec())
    brackenhound_clips.author(r)
    r.finish()
    return s, hard, low, arm, r, paths


VIEWS = {
    "front34": ((2.6, 4.4, 1.3), (0, 0.1, 0.75), 50),
    "side": ((5.2, 0.1, 0.9), (0, 0.05, 0.75), 50),
    "back34": ((-2.6, -4.4, 1.6), (0, 0, 0.75), 50),
    "face": ((0.5, 2.0, 1.2), (0, 1.1, 1.08), 70),
    "face_side": ((1.1, 1.15, 1.12), (0, 1.12, 1.08), 85),
    "foot": ((0.9, 1.1, 0.3), (0.18, 0.4, 0.08), 70),
    "top": ((0.3, 0.0, 4.5), (0, 0.1, 0.8), 50),
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
                views = dict(front=((0.0, 7.0, 1.0), (0, 0, 0.7), 60), q=((4.4, 4.6, 1.4), (0, 0.1, 0.65), 60),
                             side=((6.5, 0.1, 0.9), (0, 0.1, 0.7), 60), top=((0.2, 0.0, 6.0), (0.2, 0.2, 0.2), 50))
                kw = dict(view=views[cam or "q"])
                if at:
                    ts = [float(x) for x in at.split(",")]
                    kw.update(at=ts, frames=len(ts), res=(900, 700))
                preview.strip(arm, low, clip, os.path.join(d, f"clip_{clip}{'_' + cam if cam else ''}.png"), extra=hide, **kw)
    if "--noexport" not in args:
        for o in hide:
            bpy.data.objects.remove(o, do_unlink=True)
        path = kit.export_gltf(NAME, [low, arm], OUT)
        rig.write_gaits(NAME, r, "creatures/models/fae/brackenhound.gltf")
        print(f"{NAME}: {kit.tris(low)} tris -> {path}")
