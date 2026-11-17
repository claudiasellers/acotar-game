"""The whorl stones: fast-travel landmarks for the Spring Court (lane L74).

Canon (Keeper, 2026-11-17, ch 31): crossing back through the Wall, Feyre finds
"the mossy stones placed across from each other, a faint whorl carved into them
both. A gate." The form is [C]; a pair in every Spring region is [X]. Feyre
traces the whorl and paints a small mark of her own beside it (ch 2's habit of
painting onto things) [X]: a mark, never magic.

Headless Blender, deterministic, prop_kit contract (one mesh per model, the
finish in UV.x, front +Y, base centre at the origin, true size).

Run:  /opt/bpyenv/bin/python tools/blender/whorl_stones.py [--only id,id] [--sheet DIR]
Out:  art/fast_travel/<id>.glb (+ "<id>_lod1") and whorl_stones_manifest.json

Models:
- whorl_stones: the pair, 2.8 m apart across the way (the way runs along Y),
  each stone 1.9 m, mossy, a faint whorl on the inner face.
- whorl_stones_blight: the same pair, cold and bare, lichen dead (R3 horror is
  never pastel).
- whorl_mark: her painted mark, a little five-petal rose in pink and butter,
  modelled in the pair's own space (stone A's inner face, beside its whorl),
  so the game places it with the same transform as the pair.
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(__file__))
import bpy  # noqa: E402,F401,I001
import bmesh  # noqa: E402,I001
from mathutils import Matrix, Vector  # noqa: E402
import prop_kit as K  # noqa: E402
import upcoming_kit as U  # noqa: E402
from prop_kit import BUTTER, ROSE, R, T  # noqa: E402

OUT = os.path.join(K.ROOT, "art/fast_travel")

SPRING_STONE = (0.62, 0.58, 0.62)
SPRING_MOSS = (0.47, 0.60, 0.45)
SPRING_LICHEN = (0.80, 0.78, 0.56)
BLIGHT_STONE = (0.30, 0.30, 0.35)
BLIGHT_MOSS = (0.24, 0.22, 0.25)
BLIGHT_LICHEN = (0.44, 0.43, 0.42)
GROOVE_DARK = 0.3

# One stone, modelled facing +Y: height, half-width, half-thickness.
H, W, D = 1.9, 0.40, 0.19
# Half the gap between the two stones' centres (the way runs between them).
HALF_GAP = 1.4
# Where the whorl sits on the inner face (x across, z up) and how big.
WHORL_Z = 1.12
WHORL_R = 0.17
WHORL_TURNS = 2.6
# The mark's spot on stone A's face: beside the whorl, a little lower.
MARK_X, MARK_Z = 0.2, 0.8
# Each stone's face is turned this far toward the south end of the way, so
# whoever walks up sees both whorls (and her mark) and not two edges.
FACE_TURN = 28.0


def clamp(v):
    return max(0.0, min(1.0, v))


def half_width(z):
    v = z / H
    top = math.sqrt(max(0.0, 1.0 - max(0.0, (v - 0.72) / 0.28) ** 2))   # a rounded crown
    return W * (1.06 - 0.16 * v + 0.03 * math.sin(v * 8.0)) * (0.32 + 0.68 * top)


def half_depth(z):
    v = z / H
    top = math.sqrt(max(0.0, 1.0 - max(0.0, (v - 0.76) / 0.24) ** 2))
    return D * (1.05 - 0.12 * v) * (0.4 + 0.6 * top)


def front_y(x, z):
    """The inner (front, +Y) face's depth at (x, z): a squared-off ellipse."""
    w = half_width(z)
    u = min(1.0, abs(x) / max(w, 1e-4))
    return half_depth(z) * (1.0 - u ** 4) ** 0.25


def whorl_points(n=46):
    """The spiral on the face, outside in, as (x, z)."""
    out = []
    for i in range(n):
        t = i / (n - 1)
        a = WHORL_TURNS * 2.0 * math.pi * t
        r = WHORL_R * (1.0 - 0.86 * t)
        out.append((r * math.cos(a), WHORL_Z + r * math.sin(a)))
    return out


def stone_body(seed):
    """A standing stone: rings of a squared ellipse, more rings and columns
    where the whorl is so its shading has mesh, weathered by a fixed noise.
    The "cav" layer carries how proud or sunken each vertex is."""
    rng = random.Random(seed)
    bm = bmesh.new()
    cav = bm.verts.layers.float.new("cav")
    zs = [H * k / 10 * 0.5 for k in range(10)] + [H * (0.5 + 0.5 * k / 9) for k in range(10)]
    # angle samples: packed on the front (+Y, a = pi/2)
    na = 22
    angs = []
    for i in range(na):
        s = -1.0 + 2.0 * i / na
        angs.append(math.pi / 2 + math.pi * (s + 0.35 * math.sin(math.pi * s)))
    ph = rng.uniform(0, 6.0)
    rings = []
    for z in zs:
        w, d = half_width(z), half_depth(z)
        ring = []
        for a in angs:
            c, s = math.cos(a), math.sin(a)
            # squared ellipse: |x/w|^4 + |y/d|^4 = 1 along this direction
            k = (abs(c) ** 4 + abs(s) ** 4) ** -0.25
            x, y = w * c * k, d * s * k
            n = (math.sin(x * 9.0 + z * 4.1 + ph) * math.cos(z * 6.3 - x * 3.0 + ph * 0.7)
                 + 0.5 * math.sin(z * 15.0 + x * 11.0 + ph * 2.0))
            bump = 1.0 + 0.045 * n
            v = bm.verts.new((x * bump, y * bump, z))
            v[cav] = clamp(0.5 + 0.28 * n)
            ring.append(v)
        rings.append(ring)
    for r0, r1 in zip(rings, rings[1:]):
        for i in range(na):
            j = (i + 1) % na
            bm.faces.new((r0[i], r0[j], r1[j], r1[i]))
    top = bm.verts.new((0.0, 0.0, H + 0.015))
    top[cav] = 0.6
    for i in range(na):
        bm.faces.new((rings[-1][i], rings[-1][(i + 1) % na], top))
    return bm


def stone_shade(bm, stone, moss, lichen, seed, mossy=True):
    """Lit tops, dark crevices; moss creeping up from the foot and over the
    crown's north shoulder; lichen rosettes clear of the whorl."""
    rng = random.Random(seed)
    patches = [(rng.uniform(-0.3, 0.3), rng.uniform(0.25, 1.6), rng.uniform(0.05, 0.1)) for _ in range(5)]

    def tint(co, col):
        z = co.z
        moss_f = clamp(1.0 - z / 0.42 + 0.18 * math.sin(co.x * 13.0 + seed)) if mossy else 0.0
        crown = clamp((z - 1.55) / 0.25) * clamp(0.5 - co.y * 3.0) if mossy else 0.0
        col = K.mix(col, moss, max(moss_f, crown) * 0.7)
        if co.y > 0.0:
            wx, wz = co.x, z - WHORL_Z
            if math.hypot(wx, wz) > WHORL_R * 1.4:
                for px, pz, pr in patches:
                    d = math.hypot(co.x - px, z - pz)
                    if d < pr:
                        col = K.mix(col, lichen, 0.7 * (1.0 - d / pr))
        return col
    return U.stone_shade(bm, stone, 0.5, 0.32, (0.9, 0.08), tint)


def whorl_groove(dark):
    """The carved whorl as a shallow, darker channel sitting in the face."""
    pts = []
    for x, z in whorl_points():
        pts.append((x, front_y(x, z) - 0.006, z))
    return K.tube(pts, 0.011, sides=4), dark


def stone_matrix(side, seed):
    """Stone A (side -1) stands at -X facing +X; B at +X facing -X; both faces
    turned FACE_TURN toward the way's south end (-Y here, the game's +Z, where
    she arrives); each leans a touch and is a few degrees off, as stones set by
    hand would be."""
    rng = random.Random(seed)
    lean = rng.uniform(1.5, 3.5) * (1 if rng.random() > 0.5 else -1)
    yaw = rng.uniform(-6.0, 6.0)
    return T(side * HALF_GAP, 0.0, 0.0) @ R("Z", -90.0 * -side) @ R("Z", FACE_TURN * side + yaw) @ R("Y", lean)


def pair(p, stone, moss, lichen, mossy):
    for side, seed in ((-1, 31), (1, 57)):
        m = stone_matrix(side, seed)
        bm = stone_body(seed)
        p.add(bm, stone, "matte", m, sharp_deg=70.0, shade=stone_shade(bm, stone, moss, lichen, seed, mossy))
        groove, _ = whorl_groove(K.darker(stone, GROOVE_DARK))
        p.add(groove, K.darker(stone, GROOVE_DARK), "matte", m)


def whorl_stones(p):
    pair(p, SPRING_STONE, SPRING_MOSS, SPRING_LICHEN, True)


def whorl_stones_blight(p):
    pair(p, BLIGHT_STONE, BLIGHT_MOSS, BLIGHT_LICHEN, False)


def whorl_mark(p):
    """Her mark: five round petals of rose paint and a butter heart, laid flat
    on stone A's inner face beside the whorl, a hair proud of the stone."""
    m_stone = stone_matrix(-1, 31)
    y = front_y(MARK_X, MARK_Z) + 0.004
    face = m_stone @ T(MARK_X, y, MARK_Z) @ R("X", -90.0)     # +Z of the flower = the face normal (+Y)
    r = 0.1
    for i in range(5):
        p.add(K.round_petal(r, r * 0.8, cup=0.04, curl=0.0), ROSE, "satin", face @ R("Z", 72.0 * i + 18.0))
    heart = U.sphere(r * 0.3, 8, 4)
    p.add(heart, BUTTER, "satin", face @ Matrix.Diagonal((1.0, 1.0, 0.35, 1.0)))
    # two painted leaves under it
    for a in (-120.0, -60.0):
        p.add(K.round_petal(r * 0.9, r * 0.45, cup=0.04, curl=0.0), K.SAGE, "satin", face @ R("Z", a) @ T(r * 0.6, 0, 0))


BUILDERS = {
    "whorl_stones": (whorl_stones, None, dict(canon="C form, X placement", horror=False)),
    "whorl_stones_blight": (whorl_stones_blight, None, dict(canon="C form, X placement", horror=True)),
    "whorl_mark": (whorl_mark, None, dict(canon="X", horror=False)),
}

SHEETS = [("whorl_stones.png", ["whorl_stones", "whorl_stones_blight", "whorl_mark"], 3, 30, 14, False)]


def mark_centre():
    """The mark's centre in game space (x, y up, z = -Blender y), for WhorlStone.MARK_AT."""
    m = stone_matrix(-1, 31)
    v = m @ Vector((MARK_X, front_y(MARK_X, MARK_Z), MARK_Z))
    return (round(v.x, 3), round(v.z, 3), round(-v.y, 3))


def main(argv):
    if "--sheet" in argv:
        U.run_family(BUILDERS, OUT, "whorl_stones_manifest.json", argv, SHEETS)
        return
    os.makedirs(OUT, exist_ok=True)
    # The mark is modelled in the pair's space: never re-centred, so it lands on
    # the stone. run_family centres each model on its base, so do it by hand.
    rows = []
    for pid, (fn, _size, meta) in BUILDERS.items():
        K.reset()
        p = U.Prop(pid)
        fn(p)
        ob, lo = U.finish_single(p, pid)
        n0, n1 = K.mesh_tris(ob), K.mesh_tris(lo)
        path = os.path.join(OUT, pid + ".glb")
        K.export_glb([ob, lo], path)
        alb = U.max_albedo(ob)
        print(f"  {pid:22s} {n0:6d} {n1:6d} {os.path.getsize(path):8d} {alb:6.3f}")
        if n0 > U.MAX_PROP_TRIS or alb > U.ALBEDO_CAP + 0.005:
            print("OVER BUDGET:", pid)
            sys.exit(1)
        rows.append(dict(id=pid, file=pid + ".glb", tris=n0, tris_lod1=n1, **meta))
    U.write_manifest(os.path.join(OUT, "whorl_stones_manifest.json"), rows)
    print("  mark centre (game space):", mark_centre())


if __name__ == "__main__":
    main(sys.argv[1:])
