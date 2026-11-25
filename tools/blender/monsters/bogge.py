"""The Bogge's half-seen kit (bestiary §4.3): three parts that surface out of
its shimmer for a moment and sink back. It is never a whole body.

    creatures/models/fae/bogge_claws.gltf   three long hooked claws on a skeletal hand, 40 cm
    creatures/models/fae/bogge_jaw.gltf     a long jaw of uneven teeth, 50 cm
    creatures/models/fae/bogge_eye.gltf     one huge lidless eye, 15 cm

Each has its textures, a small skeleton, the clips `surface`, `hold`, `sink`
and `lunge`, and data/animation/creatures/<name>_gaits.txt.

A part is modelled pushing out of the plane y = 0 (z = 0 in the game) toward
+y (the game's -Z), centred on the origin: what is behind the plane is cut
away by creatures/materials/bogge_part.gdshader, so `surface` and `sink` only
have to slide the part through it.

    /opt/bpyenv/bin/python tools/blender/monsters/bogge.py [claws|jaw|eye ...] [--preview DIR] [--fast] [--nobake]
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))

import bpy  # noqa: E402
import numpy as np  # noqa: E402

import kit  # noqa: E402
import rig  # noqa: E402

OUT = os.path.join(kit.ROOT, "creatures", "models", "fae")

# near-colourless and cold: wet bone under old frost
WET = (0.085, 0.092, 0.1)
WET_DARK = (0.03, 0.034, 0.04)
FROST = (0.19, 0.22, 0.26)
SINEW = (0.05, 0.047, 0.052)


def _v(*p):
    return np.array(p, dtype=np.float64)


def _dir(yaw, pitch):
    """Forward, turned `yaw` degrees to +x and dropped `pitch` degrees."""
    a, b = math.radians(yaw), math.radians(pitch)
    return _v(math.sin(a) * math.cos(b), math.cos(a) * math.cos(b), -math.sin(b))


# ------------------------------------------------------------------ materials

def _frost(g, P):
    """Where old frost has taken: the upper faces (the `frost` paint) and
    patches anywhere. Returns (mask, crystal height)."""
    up, _, _ = g.split(g.attr("frost"))
    patch = g.noise(P, 34.0, 4.0)
    mask = g.smooth(g.math("ADD", g.math("MULTIPLY", patch, 1.0), g.math("MULTIPLY", up, 0.22)), 0.66, 0.8)
    cell, _ = g.voronoi(P, 900.0)
    return mask, g.math("MULTIPLY", g.smooth(cell, 0.0, 0.25), mask)


def bone_material(name, base=WET, dark=WET_DARK, rough=0.2):
    """Wet grey bone: pitted, darker in its hollows, rimed with frost on top."""
    def build(nt, bsdf):
        g = kit.Graph(nt)
        P = g.position()
        frost, crystal = _frost(g, P)
        age = g.smooth(g.noise(P, 22.0, 4.0), 0.35, 0.7)
        grain = g.noise(g.scale_vec(P, (1.0, 0.22, 1.0)), 420.0, 3.0)
        pit = g.smooth(g.noise(P, 520.0, 2.0), 0.64, 0.72)
        col = g.mix_rgb(age, base, dark)
        col = g.mix_rgb(g.math("MULTIPLY", pit, 0.85), col, (0.012, 0.014, 0.018))
        col = g.mix_rgb(frost, col, FROST)
        height = g.math("ADD", g.math("SUBTRACT", g.math("MULTIPLY", grain, 0.3), g.math("MULTIPLY", pit, 0.8)),
                        g.math("MULTIPLY", crystal, 0.7))
        g.out(bsdf, color=col, rough=g.mix(frost, g.mix(pit, rough, 0.6), 0.72), normal=g.bump(height, 0.0012))
    return kit.sculpt_material(name, build)


def horn_material(name, root, tip, rough=0.16):
    """A claw or a tooth: `root` to `tip` along its length, streaked, wet."""
    def build(nt, bsdf):
        g = kit.Graph(nt)
        P = g.position()
        grad, _, _ = g.split(g.attr("grad"))
        streak = g.noise(g.scale_vec(P, (1.0, 0.15, 0.15)), 700.0, 2.0)
        stain = g.smooth(g.noise(P, 90.0, 3.0), 0.5, 0.72)
        col = g.mix_rgb(g.smooth(grad, 0.05, 0.75), root, tip)
        col = g.mix_rgb(g.math("MULTIPLY", stain, 0.6), col, WET_DARK)
        rime = g.math("MULTIPLY", g.smooth(g.noise(P, 60.0, 3.0), 0.6, 0.72), g.math("SUBTRACT", 1.0, g.smooth(grad, 0.2, 0.6)))
        col = g.mix_rgb(rime, col, FROST)
        g.out(bsdf, color=col, rough=g.mix(rime, rough, 0.7), normal=g.bump(streak, 0.0005))
    return kit.sculpt_material(name, build)


def kit_warp(g, P, scale, amount):
    """P pushed about by noise, so cell patterns lose their straight edges."""
    n = g.nt.nodes.new("ShaderNodeTexNoise")
    g._set(n.inputs["Vector"], P)
    n.inputs["Scale"].default_value = scale
    off = g.nt.nodes.new("ShaderNodeVectorMath")
    off.operation = "SCALE"
    g.nt.links.new(n.outputs["Color"], off.inputs[0])
    off.inputs["Scale"].default_value = amount
    add = g.nt.nodes.new("ShaderNodeVectorMath")
    add.operation = "ADD"
    g._set(add.inputs[0], P)
    g.nt.links.new(off.outputs["Vector"], add.inputs[1])
    return add.outputs["Vector"]


EYE_C = _v(0.0, 0.065, 0.0)
EYE_R = 0.075


def eye_material():
    """Lidless and wet: a cold pale yellow iris of fine fibres round a slit
    of a pupil, the white of it veined and yellowed. The iris gives a little light."""
    def build(nt, bsdf):
        g = kit.Graph(nt)
        P = g.position()
        v = g.sub_vec(P, tuple(EYE_C))
        x, y, z = g.split(v)
        x, y, z = (g.math("DIVIDE", c, EYE_R) for c in (x, y, z))
        rho = g.math("SQRT", g.math("ADD", g.math("POWER", x, 2.0), g.math("POWER", z, 2.0)))
        front = g.smooth(y, 0.0, 0.1)
        safe = g.math("MAXIMUM", rho, 0.02)
        spoke = g.combine(g.math("DIVIDE", x, safe), 0.0, g.math("DIVIDE", z, safe))
        fibre = g.noise(spoke, 26.0, 4.0, 0.7)
        fine = g.noise(spoke, 90.0, 2.0)
        iris = g.math("MULTIPLY", g.math("SUBTRACT", 1.0, g.smooth(rho, 0.6, 0.64)), front)
        slit = g.math("ADD", g.math("POWER", g.math("DIVIDE", x, 0.1), 2.0), g.math("POWER", g.math("DIVIDE", z, 0.5), 2.0))
        pupil = g.math("MULTIPLY", g.math("SUBTRACT", 1.0, g.smooth(slit, 0.8, 1.1)), front)
        limbus = g.math("MULTIPLY", g.smooth(rho, 0.5, 0.63), iris)
        i_col = g.mix_rgb(g.smooth(fibre, 0.3, 0.75), (0.2, 0.21, 0.09), (0.66, 0.66, 0.3))
        i_col = g.mix_rgb(g.math("MULTIPLY", g.smooth(fine, 0.45, 0.7), 0.35), i_col, (0.8, 0.82, 0.55))
        i_col = g.mix_rgb(g.math("MULTIPLY", g.math("SUBTRACT", 1.0, g.smooth(rho, 0.1, 0.3)), 0.5), i_col, (0.3, 0.27, 0.08))     # darker round the slit
        i_col = g.mix_rgb(limbus, i_col, (0.035, 0.04, 0.03))
        vein_e, _ = g.voronoi(kit_warp(g, P, 30.0, 0.02), 24.0)
        vein = g.math("MULTIPLY", g.math("SUBTRACT", 1.0, g.smooth(vein_e, 0.0, 0.02)), g.smooth(rho, 0.66, 0.95))
        vein = g.math("MULTIPLY", vein, g.smooth(g.noise(P, 14.0, 2.0), 0.5, 0.68))
        w_col = g.mix_rgb(g.smooth(g.noise(P, 30.0, 3.0), 0.3, 0.8), (0.17, 0.17, 0.125), (0.09, 0.095, 0.085))
        w_col = g.mix_rgb(g.math("MULTIPLY", vein, 0.85), w_col, (0.07, 0.025, 0.028))
        w_col = g.mix_rgb(g.math("MULTIPLY", g.smooth(rho, 0.8, 1.0), 0.6), w_col, (0.05, 0.03, 0.035))
        col = g.mix_rgb(iris, w_col, i_col)
        col = g.mix_rgb(pupil, col, (0.002, 0.002, 0.003))
        glow = g.math("MULTIPLY", iris, g.math("SUBTRACT", 1.0, pupil))
        emit = g.mix_rgb(glow, (0.0, 0.0, 0.0), i_col)
        g.out(bsdf, color=col, rough=0.07, normal=g.bump(g.math("MULTIPLY", g.math("ADD", fibre, vein), iris), 0.0006),
              emission=emit, strength=1.0)
    return kit.sculpt_material("bogge_eyeball", build)


# ------------------------------------------------------------------ rigging

def bind_soft(obj, arm, bones, sigma=0.01, weights=None):
    """Bone weights by nearness: each vertex follows the bones it lies along,
    shared smoothly where two meet. `weights(P)` -> {bone: array} overrules."""
    P = kit.co(obj)
    if weights is not None:
        W = weights(P)
        names = list(W)
        M = np.stack([W[k] for k in names], axis=1)
    else:
        names = list(bones)
        M = np.zeros((len(P), len(names)))
        for i, b in enumerate(names):
            d, _ = kit.seg_dist(P, np.array(arm.data.bones[b].head_local), np.array(arm.data.bones[b].tail_local))
            M[:, i] = d
        M = np.exp(-((M - M.min(axis=1, keepdims=True)) / sigma) ** 2)
    if M.shape[1] > 4:
        cut = np.sort(M, axis=1)[:, -4][:, None]
        M = np.where(M >= cut, M, 0.0)
    M /= np.maximum(M.sum(axis=1, keepdims=True), 1e-9)
    for j, k in enumerate(names):
        vg = obj.vertex_groups.new(name=k)
        for i in np.nonzero(M[:, j] > 1e-3)[0]:
            vg.add([int(i)], float(M[i, j]), "REPLACE")


BASE = [("root", (0, 0, 0), (0, 0.1, 0), None, False),
        ("body", (0, -0.1, 0), (0, 0.0, 0), "root", False)]


def _lerp(a, b, u):
    return {k: a[k] + (b[k] - a[k]) * u for k in a}


# ------------------------------------------------------------------ the claws

class Claws:
    name = "bogge_claws"
    voxel = 0.0022
    tris = 1900
    hidden = -0.5          # how far back it sits when wholly inside the shimmer
    WRIST = _v(0.0, 0.04, 0.0)
    YAW = (-25.0, 1.0, 26.0)
    SCALE = (0.94, 1.08, 0.97)
    LEN = (0.09, 0.085, 0.07)
    PITCH = (-12.0, 10.0, 38.0)
    CLAW = (0.175, 60.0)

    def joints(self, i):
        """[metacarpal root, knuckle, mid joint, last joint, claw tip] of finger i."""
        p = self.WRIST + _v((i - 1) * 0.016, 0.006, 0.0)
        out = [p]
        for length, pitch in zip(self.LEN, self.PITCH):
            p = p + _dir(self.YAW[i], pitch) * length * self.SCALE[i]
            out.append(p)
        out.append(p + _dir(self.YAW[i], self.CLAW[1]) * self.CLAW[0] * self.SCALE[i])
        return out

    def forms(self):
        t, e = kit.tube, kit.ellipsoid
        F = []
        for s, r in ((1, 1.0), (-1, 0.85)):              # the two bones of the forearm, running back into the shimmer
            F.append(t(f"fore{s}", [(0.015 * s, -0.3, 0.004 * s), (0.017 * s, -0.12, 0.007 * s), (0.013 * s, 0.028, 0.0)],
                       [0.018 * r, 0.0105 * r, 0.019 * r], k=0.008, segs=14))
        for j, c in enumerate(((0.013, 0.04, 0.001), (-0.013, 0.041, 0.0), (0.0, 0.05, 0.004), (0.0, 0.034, -0.004))):
            F.append(e(f"carpal{j}", c, (0.017, 0.0155, 0.014), k=0.009, segs=12))
        for i in range(3):
            J = self.joints(i)
            for b in range(3):
                r = (0.0135, 0.012, 0.0105)[b] * self.SCALE[i]
                a, c = J[b], J[b + 1]
                pts = [a + (c - a) * u for u in (0.0, 0.3, 0.7, 1.0)]
                F.append(t(f"f{i}{b}", pts, [(r * 1.28, r * 1.1), r * 0.76, r * 0.7, (r * 1.24, r * 1.05)], k=0.005, segs=12, rings_per_m=160))
                F.append(e(f"k{i}{b}", tuple(c), (r * 1.45, r * 1.25, r * 1.3), k=0.005, segs=10))
        for i in range(2):                               # dried sinew still strung between the long bones
            A, B = self.joints(i), self.joints(i + 1)
            for u, w in ((0.45, 0.012), (0.85, 0.008)):
                a, b = A[0] + (A[1] - A[0]) * u, B[0] + (B[1] - B[0]) * u
                F.append(t(f"web{i}{u}", [tuple(a), tuple((a + b) / 2 - _v(0, 0.006, 0.004)), tuple(b)], [(0.004, w), (0.003, w * 0.6), (0.004, w)],
                           side=(0, 0, 1), k=0.006, segs=8, rings_per_m=300))
        return F

    def hard(self):
        mat = horn_material("bogge_claw", (0.13, 0.14, 0.15), (0.014, 0.016, 0.02), rough=0.13)
        out = []
        for i in range(3):
            J = self.joints(i)
            d = _dir(self.YAW[i], self.CLAW[1])
            up = _dir(self.YAW[i], self.CLAW[1] - 90.0)
            o = kit.horn(f"claw{i}", J[3] - d * 0.012 + up * 0.002, J[4], 0.0142 * self.SCALE[i], bend=up * 0.08,
                         segs=8, rings=10, flat=0.66, tip_r=0.02)
            kit.set_material(o, mat)
            out.append((kit.tag(o, 10 + i), f"claw_{i}"))
        spur = kit.horn("spur", self.WRIST + _v(0.012, 0.0, -0.008), self.WRIST + _v(0.03, 0.045, -0.075), 0.0095, bend=(0.0, 0.03, 0.0),
                        segs=6, rings=6, flat=0.7, tip_r=0.03)
        kit.set_material(spur, mat)
        out.append((kit.tag(spur, 14), "hand"))
        return out

    def bones(self):
        B = list(BASE)
        B.append(("forearm", (0, -0.3, 0.004), tuple(self.WRIST), "body", True))
        B.append(("hand", tuple(self.WRIST), tuple(self.WRIST + _v(0, 0.012, 0.0)), "forearm", True))
        for i in range(3):
            J = self.joints(i)
            par = "hand"
            for n, b in enumerate((f"finger_{i}", f"finger_{i}b", f"finger_{i}c")):
                B.append((b, tuple(J[n]), tuple(J[n + 1]), par, True))
                par = b
            B.append((f"claw_{i}", tuple(J[3]), tuple(J[4]), par, True))
        return B

    def skin_bones(self):
        return ["forearm"] + [f"finger_{i}{s}" for i in range(3) for s in ("", "b", "c")]

    # ---- motion: every pose is a few numbers
    def held(self, t):
        """The pose it holds, flexing: {y, pitch, roll, yaw, spread, c0, c1, c2}."""
        out = dict(y=0.012 * rig.wave(t, 3.0, 0.1), pitch=4.0 * rig.wave(t, 3.0), roll=7.0 * rig.wave(t, 3.0, 0.3),
                   yaw=3.0 * rig.wave(t, 1.5, 0.2), spread=0.75 + 0.25 * rig.wave(t, 3.0, 0.5))
        for i in range(3):                               # the fingers drum, one after another
            out[f"c{i}"] = -0.12 + 0.34 * (0.5 + 0.5 * rig.wave(t, 1.5, -0.17 * i)) ** 2
        return out

    def pose(self, q):
        p = rig.Pose()
        p.body(loc=(0, q["y"], q.get("z", 0.0)), pitch=q["pitch"], yaw=q["yaw"], roll=q["roll"])
        for i in range(3):
            c = q[f"c{i}"]
            p.turn(f"finger_{i}", pitch=16.0 * c, yaw=-13.0 * q["spread"] * (i - 1))
            p.turn(f"finger_{i}b", pitch=52.0 * c)
            p.turn(f"finger_{i}c", pitch=58.0 * c)
            p.turn(f"claw_{i}", pitch=24.0 * c)
        return p

    def away(self):
        return dict(y=self.hidden, pitch=0.0, roll=-20.0, yaw=0.0, spread=-0.4, c0=0.95, c1=1.0, c2=0.95)

    def lunge(self, t):
        h = self.held(0.0)
        cock = rig.smooth(rig.seg(t, 0.0, 0.1))
        rake = rig.ease_in(rig.seg(t, 0.1, 0.27), 1.6)
        q = _lerp(h, dict(y=-0.07, pitch=-30.0, roll=0.0, yaw=-6.0, spread=1.2, c0=-0.35, c1=-0.4, c2=-0.35), cock)
        q = _lerp(q, dict(y=0.3, pitch=34.0, roll=10.0, yaw=8.0, spread=0.9, c0=0.5, c1=0.55, c2=0.5), rake)
        q["z"] = 0.05 * cock - 0.1 * rake
        return q

    def paint(self, P, N):
        return kit.ss((N[:, 2] - 0.05) / 0.7)


# ------------------------------------------------------------------ the jaw

class Jaw:
    name = "bogge_jaw"
    voxel = 0.003
    tris = 2000
    hidden = -0.6
    HINGE = _v(0.0, 0.02, -0.04)
    OPEN = 14.0             # how far it hangs open as modelled

    @staticmethod
    def hw(y):
        """Half the upper jaw's width at y: narrowing, with a knob at the tip."""
        u = kit.sat(np.asarray(y, dtype=np.float64) / 0.5)
        return 0.058 - 0.036 * u ** 0.7 + 0.007 * np.exp(-((np.asarray(y) - 0.455) / 0.035) ** 2)

    @staticmethod
    def hh(y):
        return 0.037 - 0.021 * kit.sat(np.asarray(y, dtype=np.float64) / 0.5) ** 0.8

    @staticmethod
    def zc(y):
        return 0.022 - 0.014 * kit.sat((np.asarray(y, dtype=np.float64) - 0.38) / 0.12) ** 2

    def low(self, p):
        """A point of the lower jaw, given closed, where it is hanging open."""
        p = np.asarray(p, dtype=np.float64) - self.HINGE
        a = math.radians(self.OPEN)
        return self.HINGE + _v(p[0], p[1] * math.cos(a) + p[2] * math.sin(a), -p[1] * math.sin(a) + p[2] * math.cos(a))

    def forms(self):
        t, e = kit.tube, kit.ellipsoid
        ys = (-0.2, -0.06, 0.06, 0.18, 0.3, 0.4, 0.46, 0.5)
        up = [t("muzzle", [(0, y, float(self.zc(y))) for y in ys], [(float(self.hw(y)), float(self.hh(y))) for y in ys], k=0.012, segs=24),
              t("ridge", [(0, y, float(self.zc(y) + self.hh(y) * 0.85)) for y in ys[1:]], [0.011, 0.01, 0.009, 0.0075, 0.0065, 0.006, 0.005], k=0.012, segs=10)]
        for s in (1, -1):
            up.append(t(f"gum{s}", [(s * float(self.hw(y) - 0.005), y, float(self.zc(y) - self.hh(y) * 0.78)) for y in ys[2:]],
                        [0.0095, 0.009, 0.0085, 0.008, 0.008, 0.0075], k=0.008, segs=10))
            up.append(e(f"cheek{s}", (0.046 * s, 0.03, 0.052), (0.022, 0.05, 0.02), rot=(-8, 0, 0), k=0.018, segs=14))
        lw = [(y, float(self.hw(y)) - 0.0145) for y in (-0.02, 0.1, 0.2, 0.3, 0.37)]
        lo = []
        for s in (1, -1):
            lo.append(t(f"ramus{s}", [tuple(self.low((s * w, y, -0.036 - 0.008 * math.sin(math.pi * kit.sat(y / 0.4))))) for y, w in lw],
                        [(0.0095, 0.023), (0.009, 0.02), (0.009, 0.017), (0.0095, 0.014), (0.01, 0.012)], k=0.01, segs=12))
            lo.append(t(f"coronoid{s}", [tuple(self.low((s * lw[0][1], -0.02, -0.036))), tuple(self.low((s * (lw[0][1] + 0.004), -0.05, 0.0)))],
                        [0.009, 0.007], k=0.01, segs=10))
        lo.append(t("chin", [tuple(self.low((0, y, z))) for y, z in ((0.33, -0.038), (0.4, -0.037), (0.445, -0.033), (0.475, -0.024))], [(0.023, 0.014), (0.019, 0.013), (0.015, 0.012), (0.011, 0.01)], k=0.012, segs=14))
        cut = [e("palate", (0, 0.3, float(self.zc(0.3) - self.hh(0.3) - 0.003)), (0.017, 0.17, 0.012), k=0.004, segs=16),
               e("nose", (0, 0.425, float(self.zc(0.425) + self.hh(0.425))), (0.0105, 0.04, 0.012), k=0.004, segs=14),
               e("window", (0, 0.11, 0.024), (0.09, 0.05, 0.0125), k=0.004, segs=16)]
        for s in (1, -1):
            cut.append(e(f"nostril{s}", (0.0085 * s, 0.487, float(self.zc(0.487)) + 0.011), (0.0042, 0.0085, 0.0045), rot=(25, 0, 0), k=0.003, segs=10))
        return up, lo, cut

    def teeth(self):
        """Uneven, crowded, some broken: [(base, tip, radius, blunt, lower)]."""
        rnd = np.random.RandomState(11)
        out = []
        for s in (1, -1):
            y = 0.045 + 0.012 * rnd.rand()
            while y < 0.492:
                broken = rnd.rand() < 0.14
                fang = 0.39 < y < 0.48
                long = 0.014 if broken else (0.028 + 0.034 * rnd.rand() + (0.026 if fang else 0.0))
                x = float(self.hw(y)) - 0.0055
                base = _v(s * x, y, float(self.zc(y) - self.hh(y) * 0.8) - 0.004)
                d = _v(s * (0.1 + 0.25 * rnd.rand()), -0.12 + 0.3 * rnd.rand(), -1.0)
                out.append((base, base + d / np.linalg.norm(d) * long, 0.005 + 0.075 * long, broken, False))
                y += 0.021 + 0.018 * rnd.rand() + (0.008 if fang else 0.0)
            y = 0.06 + 0.012 * rnd.rand()
            while y < 0.46:
                broken = rnd.rand() < 0.12
                long = 0.012 if broken else 0.02 + 0.03 * rnd.rand()
                x = (float(self.hw(y)) - 0.0145) if y < 0.37 else max(0.02 - 0.12 * (y - 0.33), 0.004)
                base = _v(s * x, y, -0.03)
                d = _v(s * (-0.05 + 0.2 * rnd.rand()), -0.15 + 0.3 * rnd.rand(), 1.0)
                tip = base + d / np.linalg.norm(d) * long
                out.append((self.low(base), self.low(tip), 0.0045 + 0.075 * long, broken, True))
                y += 0.026 + 0.024 * rnd.rand()
        return out

    def hard(self):
        mat = horn_material("bogge_tooth", (0.045, 0.047, 0.045), (0.25, 0.27, 0.27), rough=0.2)
        out = []
        for n, (base, tip, r, broken, lower) in enumerate(self.teeth()):
            d = (tip - base) / np.linalg.norm(tip - base)
            o = kit.horn(f"tooth{n}", base - d * 0.004, tip, r, bend=(0.0, -0.008, 0.0), segs=5, rings=4, flat=0.8,
                         tip_r=0.55 if broken else 0.06)
            kit.set_material(o, mat)
            out.append((kit.tag(o, 2 if lower else 1), "jaw" if lower else "upper"))
        return out

    def bones(self):
        B = list(BASE)
        B.append(("upper", (0, -0.2, 0.018), (0, 0.5, 0.028), "body", True))
        B.append(("jaw", tuple(self.HINGE), tuple(self.low((0, 0.47, -0.036))), "body", True))
        return B

    def held(self, t):
        chatter = 2.5 * rig.pulse(t % 3.0, 1.9, 2.0, 2.1) + 2.5 * rig.pulse(t % 3.0, 2.1, 2.2, 2.3) + 2.0 * rig.pulse(t % 3.0, 2.3, 2.4, 2.5)
        return dict(y=0.015 * rig.wave(t, 3.0, 0.2), z=0.0, gape=6.0 + 7.0 * rig.wave(t, 3.0) - chatter, lift=2.0 * rig.wave(t, 3.0, 0.1),
                    yaw=5.0 * rig.wave(t, 3.0, 0.35), roll=4.0 * rig.wave(t, 1.5, 0.1), pitch=2.0 * rig.wave(t, 3.0, 0.6))

    def pose(self, q):
        p = rig.Pose()
        p.body(loc=(0, q["y"], q["z"]), pitch=q["pitch"], yaw=q["yaw"], roll=q["roll"])
        p.turn("jaw", pitch=q["gape"])
        p.turn("upper", pitch=-q["lift"])
        return p

    def away(self):
        return dict(y=self.hidden, z=0.0, gape=-self.OPEN + 1.0, lift=0.0, yaw=-8.0, roll=12.0, pitch=0.0)

    def lunge(self, t):
        h = self.held(0.0)
        gape = rig.smooth(rig.seg(t, 0.0, 0.11))
        go = rig.ease_in(rig.seg(t, 0.08, 0.25), 1.5)
        snap = rig.ease_in(rig.seg(t, 0.235, 0.27), 2.0)
        q = _lerp(h, dict(y=-0.06, z=0.0, gape=27.0, lift=14.0, yaw=0.0, roll=0.0, pitch=-6.0), gape)
        q = _lerp(q, dict(y=0.32, z=0.0, gape=31.0, lift=15.0, yaw=0.0, roll=-6.0, pitch=4.0), go)
        q["gape"] = rig.lerp(q["gape"], -self.OPEN + 2.0, snap)
        q["lift"] = rig.lerp(q["lift"], -2.0, snap)
        return q

    def paint(self, P, N):
        return kit.ss((N[:, 2] - 0.05) / 0.7)


# ------------------------------------------------------------------ the eye

class Eye:
    name = "bogge_eye"
    voxel = 0.003
    tris = 800
    hidden = -0.17

    def forms(self):
        t = kit.tube
        rnd = np.random.RandomState(5)
        F = [t("stalk", [(0, -0.3, 0), (0.006, -0.16, 0.004), (0, -0.02, 0)], [0.024, 0.02, 0.034], k=0.02, segs=14)]
        n = 16
        ring = []
        for i in range(n + 3):                           # a torn collar of flesh the ball sits in
            a = 2 * math.pi * (i % n) / n
            rr = 0.071 + 0.004 * math.sin(3 * a + 1.0)
            ring.append((rr * math.cos(a), 0.03 + 0.008 * math.sin(2 * a + 0.5), rr * math.sin(a)))
        rad = [0.012 + 0.02 * rnd.rand() ** 1.5 for _ in range(n)]
        F.append(t("collar", ring, [rad[i % n] for i in range(n + 3)], k=0.012, segs=10, rings_per_m=220))
        for j in range(7):                               # cords running back to the stalk
            a = 2 * math.pi * (j + 0.3 * rnd.rand()) / 7
            c, s = math.cos(a), math.sin(a)
            F.append(t(f"cord{j}", [(0.07 * c, 0.03, 0.07 * s), (0.062 * c, -0.04, 0.062 * s), (0.03 * c, -0.13, 0.03 * s), (0.006 * c, -0.22, 0.006 * s)],
                       [0.014, 0.008 + 0.006 * rnd.rand(), 0.011 * rnd.rand() + 0.006, 0.011], k=0.01, segs=8, rings_per_m=120))
        for j in range(6):                               # torn flaps hanging off the collar
            a = 2 * math.pi * (j + rnd.rand()) / 6
            c, s = math.cos(a), math.sin(a)
            long = 0.03 + 0.04 * rnd.rand()
            F.append(t(f"flap{j}", [(0.078 * c, 0.03, 0.078 * s), (0.094 * c, 0.012, 0.094 * s - long * 0.4), (0.09 * c, -0.01, 0.09 * s - long)],
                       [(0.013, 0.006), (0.009, 0.004), (0.004, 0.003)], side=(-s, 0, c), k=0.008, segs=8, rings_per_m=200))
        return F

    def hard(self):
        o = kit.ball("eyeball", (0, 0, 0), EYE_R, segs=24, rings=14)
        P = kit.co(o)
        P = P[:, [0, 2, 1]] * (1, 1, -1)                 # its poles to the front and back, where the pupil hides one
        bulge = 0.007 * kit.ss((P[:, 1] / EYE_R - 0.82) / 0.18)      # the cornea
        P = P * (1.0 + bulge / EYE_R)[:, None] + EYE_C
        kit.set_co(o, P)
        kit.shade_smooth(o)
        kit.set_material(o, eye_material())
        return [(kit.tag(o, 10), "eye")]

    def bones(self):
        B = list(BASE)
        B.append(("stalk", (0, -0.3, 0), (0, -0.02, 0), "body", True))
        B.append(("eye", tuple(EYE_C), tuple(EYE_C + _v(0, EYE_R, 0)), "stalk", True))
        return B

    def held(self, t):
        # it darts, holds, darts: where it looks at each beat (yaw, pitch), ending on her
        looks = ((0, 0), (0, 0), (26, -8), (26, -8), (-30, 6), (-30, 6), (-12, 22), (8, -20), (0, 0))
        k = (t % 3.0) / 3.0 * (len(looks) - 1)
        i = min(int(k), len(looks) - 2)
        u = rig.smooth(rig.seg(k - i, 0.0, 0.35))
        return dict(y=0.01 * rig.wave(t, 3.0, 0.2), z=0.0, look_yaw=rig.lerp(looks[i][0], looks[i + 1][0], u),
                    look_pitch=rig.lerp(looks[i][1], looks[i + 1][1], u), yaw=4.0 * rig.wave(t, 3.0), pitch=3.0 * rig.wave(t, 1.5, 0.3))

    def pose(self, q):
        p = rig.Pose()
        p.body(loc=(0, q["y"], q["z"]))
        p.turn("stalk", pitch=q["pitch"], yaw=q["yaw"])
        p.turn("eye", pitch=q["look_pitch"], yaw=q["look_yaw"])
        return p

    def away(self):
        return dict(y=self.hidden, z=0.0, look_yaw=20.0, look_pitch=-70.0, yaw=0.0, pitch=0.0)

    def lunge(self, t):
        h = self.held(0.0)
        go = rig.ease_in(rig.seg(t, 0.05, 0.27), 1.6)
        q = _lerp(h, dict(y=0.24, z=0.0, look_yaw=0.0, look_pitch=0.0, yaw=0.0, pitch=0.0), go)
        q["look_yaw"] = 5.0 * rig.ring(t, 0.0, 1.0, 14.0, 6.0)
        return q

    def paint(self, P, N):
        return kit.ss((N[:, 2] - 0.2) / 0.6) * 0.6


PARTS = dict(claws=Claws, jaw=Jaw, eye=Eye)


# ------------------------------------------------------------------ build

def author(r, part):
    """surface (0.4 s), hold (3 s loop), sink (0.5 s), lunge (0.3 s)."""
    start, away = part.held(0.0), part.away()

    def surface(t):
        u = t / 0.4
        q = _lerp(away, start, rig.smooth(rig.seg(u, 0.3, 1.0)))
        q["y"] = rig.lerp(away["y"], start["y"], rig.ease_out(rig.seg(u, 0.0, 0.7), 2.4)) + 0.03 * rig.pulse(u, 0.45, 0.72, 1.0)
        return part.pose(q)

    def sink(t):
        u = t / 0.5
        q = _lerp(start, away, rig.smooth(rig.seg(u, 0.0, 0.7)))
        q["y"] = rig.lerp(start["y"], away["y"], rig.ease_in(rig.seg(u, 0.15, 1.0), 1.8)) + 0.015 * rig.pulse(u, 0.0, 0.12, 0.3)
        return part.pose(q)

    r.clip("surface", 0.4, surface)
    r.clip("hold", 3.0, lambda t: part.pose(part.held(t)), loop=True)
    r.clip("sink", 0.5, sink)
    r.clip("lunge", 0.3, lambda t: part.pose(part.lunge(t)), contact=0.27)


def build(which, fast=False, bake=True):
    kit.reset()
    part = PARTS[which]()
    name = part.name
    forms = part.forms()
    lower = None
    if which == "jaw":
        up, lo, cut = forms
        lower, upper = kit.field(lo), kit.field(up)
        s = kit.union(up + lo, name + "_sculpt", voxel=part.voxel * (1.4 if fast else 1.0), project=6, cut=cut)
    else:
        s = kit.union(forms, name + "_sculpt", voxel=part.voxel * (1.4 if fast else 1.0), project=5)
    kit.drop_hollows(s)
    kit.shade_smooth(s)
    kit.paint(s, "frost", part.paint)
    kit.set_material(s, bone_material(name + "_body", base=SINEW, dark=(0.02, 0.018, 0.022), rough=0.16) if which == "eye"
                     else bone_material(name + "_body"))
    hard = part.hard()
    low = kit.game_mesh(s, name, part.tris)
    kit.tag(low, 0)
    arm = rig.build_armature(name, part.bones())
    if which == "jaw":
        def weights(P):
            w = kit.ss((upper(P) - lower(P)) / 0.012 + 0.5)
            return dict(upper=1.0 - w, jaw=w)
        bind_soft(low, arm, None, weights=weights)
    elif which == "eye":
        rig.bind_rigid(low, "stalk")
    else:
        bind_soft(low, arm, part.skin_bones(), sigma=0.008)
    pieces = []
    for o, bone in hard:
        g = kit.duplicate(o, o.name + "_g")
        rig.bind_rigid(g, bone)
        pieces.append(g)
    low = kit.join([low] + pieces, name)
    kit.triangulate(low)
    if bake:
        kit.unwrap(low)
    rig.attach(low, arm)
    sources = [s] + [o for o, _ in hard]
    paths = {}
    if bake:
        _, paths = kit.bake(sources, low, name, OUT, size=512 if fast else 1024, extrusion=0.006)
    else:
        kit.set_material(low, kit.plain("clay", (0.2, 0.22, 0.22), 0.5))
    r = rig.Rig(arm, low, {})
    author(r, part)
    r.finish()
    return sources, low, arm, r, paths


if __name__ == "__main__":
    args = sys.argv[1:]
    todo = [a for a in args if a in PARTS] or list(PARTS)
    for which in todo:
        hide, low, arm, r, paths = build(which, "--fast" in args, bake="--nobake" not in args)
        name = PARTS[which].name
        if "--preview" in args:
            import preview
            d = args[args.index("--preview") + 1]
            bpy.ops.mesh.primitive_plane_add(size=40, location=(0, 0, -0.5))
            bpy.context.view_layer.objects.active.name = "pfloor"
            cams = dict(q=((0.75, 0.95, 0.45), (0, 0.12, -0.02), 50), side=((1.3, 0.15, 0.05), (0, 0.12, -0.02), 60),
                        front=((0.12, 1.2, 0.15), (0, 0.1, -0.02), 60), under=((0.5, 0.8, -0.4), (0, 0.15, -0.02), 50))
            full = "--all" in args
            for v in ("q", "side", "front", "under"):
                preview.shot(os.path.join(d, f"{name}_sculpt_{v}.png"), cams[v], hide=[low], samples=24, res=(900, 700))
                if full or v == "q":
                    preview.shot(os.path.join(d, f"{name}_low_{v}.png"), cams[v], hide=hide, samples=24, res=(900, 700))
            for clip, at in (("surface", (0.0, 0.4, 0.7, 1.0)), ("hold", (0.0, 0.25, 0.5, 0.75)), ("lunge", (0.0, 0.33, 0.66, 0.9, 1.0)), ("sink", (0.0, 0.5, 1.0))):
                if not full and clip != "lunge":
                    continue
                preview.strip(arm, low, clip, os.path.join(d, f"{name}_clip_{clip}.png"), extra=hide, view=((1.25, 1.1, 0.5), (0, 0.0, -0.02), 50),
                              at=list(at), frames=len(at), res=(700, 560))
        if "--noexport" not in args:
            for o in hide:
                bpy.data.objects.remove(o, do_unlink=True)
            path = kit.export_gltf(name, [low, arm], OUT)
            rig.write_gaits(name, r, f"creatures/models/fae/{name}.gltf")
            print(f"{name}: {kit.tris(low)} tris -> {path}")
