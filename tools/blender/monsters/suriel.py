"""The Suriel (bestiary §3): creatures/models/fae/suriel.gltf with its
textures, skeleton, face keys and clips, and
data/animation/creatures/suriel_gaits.txt.

    /opt/bpyenv/bin/python tools/blender/monsters/suriel.py [--preview DIR views...] [--fast]

--fast bakes 1K maps and a coarser sculpt, for iterating; never commit a
--fast build. --nobake leaves it clay; --keepbake reuses the last bake's maps
(same sculpt, new clips).
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))

import bpy  # noqa: E402
import numpy as np  # noqa: E402

import kit  # noqa: E402
import rig  # noqa: E402
import suriel_body as sb  # noqa: E402
import suriel_clips  # noqa: E402
import suriel_rig  # noqa: E402

NAME = "suriel"
OUT = os.path.join(kit.ROOT, "creatures", "models", "fae")
BODY_TRIS = 11700

CLOTH = (0.043, 0.038, 0.036)
CLOTH_WORN = (0.115, 0.098, 0.082)
BONE = (0.25, 0.225, 0.165)
BONE_OLD = (0.12, 0.1, 0.072)
SKIN = (0.085, 0.08, 0.072)
SCAB = (0.05, 0.04, 0.035)
GUM = (0.032, 0.022, 0.022)
NAIL = (0.36, 0.28, 0.11)


# ------------------------------------------------------------------ materials

def _cloth(g, P, fray=None):
    """Thin, old, near-black cloth: threadbare where it has worn, the weave
    just visible. Returns (colour, roughness, height)."""
    worn = g.smooth(g.noise(P, 6.0, 4.0), 0.5, 0.74)
    blotch = g.noise(P, 23.0, 3.0)
    warp = g.noise(g.scale_vec(P, (1.0, 1.0, 0.06)), 700.0, 1.0)      # threads running down
    weft = g.noise(g.scale_vec(P, (0.06, 0.06, 1.0)), 700.0, 1.0)     # and across
    weave = g.math("ADD", g.math("MULTIPLY", warp, 0.5), g.math("MULTIPLY", weft, 0.5))
    thin = g.math("MULTIPLY", worn, g.math("ADD", 0.45, g.math("MULTIPLY", weave, 1.1)), clamp=True)
    if fray is not None:
        thin = g.math("MAXIMUM", thin, g.math("MULTIPLY", g.smooth(fray, 0.55, 1.0), 0.14))
    col = g.mix_rgb(thin, CLOTH, CLOTH_WORN)
    shade = nt_scale(g, col, g.math("ADD", 0.75, g.math("MULTIPLY", blotch, 0.5)))
    height = g.math("ADD", g.math("MULTIPLY", weave, 0.5), g.math("MULTIPLY", blotch, 0.5))
    return shade, 0.96, height


def nt_warp(g, P, scale, amount):
    """P pushed about by noise, so cell patterns lose their straight edges."""
    n = g.nt.nodes.new("ShaderNodeTexNoise")
    g._set(n.inputs["Vector"], P)
    n.inputs["Scale"].default_value = scale
    off = g.nt.nodes.new("ShaderNodeVectorMath")
    off.operation = "SCALE"
    g.nt.links.new(n.outputs["Color"], off.inputs[0])
    off.inputs["Scale"].default_value = amount
    add = g.nt.nodes.new("ShaderNodeVectorMath")
    g._set(add.inputs[0], P)
    g.nt.links.new(off.outputs["Vector"], add.inputs[1])
    return add.outputs["Vector"]


def nt_scale(g, col, f):
    n = g.nt.nodes.new("ShaderNodeVectorMath")
    n.operation = "SCALE"
    g._set(n.inputs[0], col)
    g._set(n.inputs["Scale"], f)
    return n.outputs["Vector"]


def body_material():
    """The whole sculpt: cloth, weatherworn bone, scabbed grey skin, blackened
    gums, the black of the pits, yellowed toenails, each where its zone is."""
    def build(nt, bsdf):
        g = kit.Graph(nt)
        P = g.position()
        cloth, bone, skin = g.split(g.attr("zone_a"))
        gum, dark, nail = g.split(g.attr("zone_b"))
        c_col, c_rough, c_h = _cloth(g, P)

        # bone: dried and weatherworn, cracked and pitted
        age = g.noise(P, 14.0, 4.0)
        crack_e, _ = g.voronoi(nt_warp(g, P, 30.0, 0.012), 24.0)
        crack = g.math("SUBTRACT", 1.0, g.smooth(crack_e, 0.0, 0.012))
        crack = g.math("MULTIPLY", crack, g.smooth(g.noise(P, 8.0, 2.0), 0.5, 0.62))      # only here and there
        pit = g.smooth(g.noise(P, 300.0, 2.0), 0.66, 0.74)
        grain = g.noise(g.scale_vec(P, (1.0, 1.0, 0.25)), 320.0, 3.0)
        b_col = g.mix_rgb(g.smooth(age, 0.35, 0.72), BONE, BONE_OLD)
        b_col = nt_scale(g, b_col, g.math("ADD", 0.82, g.math("MULTIPLY", grain, 0.32)))
        b_col = g.mix_rgb(g.math("MAXIMUM", crack, g.math("MULTIPLY", pit, 0.8)), b_col, (0.07, 0.055, 0.04))
        b_h = g.math("SUBTRACT", g.math("MULTIPLY", grain, 0.25), g.math("ADD", g.math("MULTIPLY", crack, 1.0), g.math("MULTIPLY", pit, 0.6)))

        # skin: grey and dry over veins and tendon, crusted with scabs
        scab = g.smooth(g.noise(P, 48.0, 3.0), 0.56, 0.66)
        vein_e, _ = g.voronoi(nt_warp(g, P, 40.0, 0.01), 30.0)
        vein = g.math("MULTIPLY", g.math("SUBTRACT", 1.0, g.smooth(vein_e, 0.0, 0.02)), g.smooth(g.noise(P, 11.0, 2.0), 0.5, 0.65))
        crease = g.noise(g.scale_vec(P, (0.3, 0.3, 1.0)), 260.0, 3.0)
        s_col = nt_scale(g, g.mix_rgb(g.math("MULTIPLY", vein, 0.6), SKIN, (0.05, 0.052, 0.06)), g.math("ADD", 0.8, g.math("MULTIPLY", crease, 0.4)))
        s_col = g.mix_rgb(scab, s_col, SCAB)
        s_col = g.mix_rgb(nail, s_col, NAIL)
        s_h = g.math("ADD", g.math("ADD", g.math("MULTIPLY", crease, 0.35), g.math("MULTIPLY", vein, 0.5)), g.math("MULTIPLY", scab, 0.9))

        col = g.mix_rgb(skin, g.mix_rgb(bone, c_col, b_col), s_col)
        col = g.mix_rgb(gum, col, GUM)
        col = g.mix_rgb(dark, col, (0.006, 0.005, 0.005))
        rough = g.mix(skin, g.mix(bone, c_rough, 0.86), g.mix(scab, 0.82, 0.95))
        rough = g.mix(nail, rough, 0.5)
        rough = g.mix(gum, rough, 0.45)
        rough = g.mix(dark, rough, 0.9)
        height = g.mix(skin, g.mix(bone, g.math("MULTIPLY", c_h, 0.45), b_h), s_h)
        g.out(bsdf, color=col, rough=rough, normal=g.bump(height, 0.0022))
    return kit.sculpt_material("suriel_body", build)


def rag_material():
    """The loose strips: the same cloth, fraying pale toward their ends."""
    def build(nt, bsdf):
        g = kit.Graph(nt)
        grad, _, _ = g.split(g.attr("grad"))
        col, rough, h = _cloth(g, g.position(), fray=grad)
        col = nt_scale(g, col, 0.72)
        g.out(bsdf, color=col, rough=rough, normal=g.bump(g.math("MULTIPLY", h, 0.45), 0.0022))
    return kit.sculpt_material("suriel_rags", build)


def tooth_material():
    """Grey, long, stained dark where the gums hold them."""
    def build(nt, bsdf):
        g = kit.Graph(nt)
        grad, _, _ = g.split(g.attr("grad"))
        streak = g.noise(g.scale_vec(g.position(), (1.0, 1.0, 0.12)), 420.0, 2.0)
        col = g.mix_rgb(g.smooth(grad, 0.0, 0.4), (0.04, 0.032, 0.026), (0.2, 0.195, 0.175))
        col = nt_scale(g, col, g.math("ADD", 0.7, g.math("MULTIPLY", streak, 0.6)))
        g.out(bsdf, color=col, rough=0.38, normal=g.bump(streak, 0.0006))
    return kit.sculpt_material("suriel_teeth", build)


def nail_material():
    def build(nt, bsdf):
        g = kit.Graph(nt)
        grad, _, _ = g.split(g.attr("grad"))
        crack = g.noise(g.scale_vec(g.position(), (0.2, 0.2, 1.0)), 500.0, 2.0)
        col = g.mix_rgb(g.smooth(grad, 0.45, 1.0), NAIL, (0.26, 0.19, 0.08))
        col = nt_scale(g, col, g.math("ADD", 0.65, g.math("MULTIPLY", crack, 0.7)))
        g.out(bsdf, color=col, rough=0.45, normal=g.bump(crack, 0.0008))
    return kit.sculpt_material("suriel_nails", build)


def eye_material(side):
    """A pit of milky white, swirled; it glows faintly so it reads under the veil."""
    c = tuple(sb.EYE * (side, 1, 1))

    def build(nt, bsdf):
        g = kit.Graph(nt)
        v = g.sub_vec(g.position(), c)
        x, _, z = g.split(v)
        ang = g.math("ARCTAN2", z, x)
        rad = g.math("DIVIDE", g.math("SQRT", g.math("ADD", g.math("POWER", x, 2.0), g.math("POWER", z, 2.0))), sb.EYE_R)
        arms = g.math("SINE", g.math("ADD", g.math("MULTIPLY", ang, 2.0), g.math("MULTIPLY", rad, 7.0)))
        cloud = g.noise(g.position(), 160.0, 3.0)
        swirl = g.smooth(g.math("ADD", g.math("MULTIPLY", arms, 0.5), cloud), 0.2, 1.0)
        col = g.mix_rgb(swirl, (0.36, 0.39, 0.42), (0.7, 0.72, 0.73))
        g.out(bsdf, color=col, rough=0.22, emission=col, strength=1.0)
    return kit.sculpt_material(f"suriel_eye{side}", build)


# ------------------------------------------------------------------ build

_ZONES = {}


def zones_for(kinds):
    """sb.zones, remembered per set of points (the three clay fields are slow)."""
    def z(P, N):
        key = (len(P), round(float(P[::97].sum()), 6))
        if key not in _ZONES:
            _ZONES.clear()
            _ZONES[key] = sb.zones(P, N, kinds)
        return _ZONES[key]
    return z


def sculpt(voxel):
    F = sb.forms()
    kinds, every = {}, []
    for kind, (mid, side) in F.items():
        objs = mid + side + [kit.mirror_x(o) for o in side]
        kinds[kind] = kit.field(objs)
        every += objs

    def make():
        s = kit.union(every, "suriel_sculpt", voxel=voxel, project=6, cut=sb.cutters())
        kit.drop_hollows(s)
        return s
    path = os.environ.get("MONSTER_SCULPT_CACHE")
    if path and os.path.exists(path):
        for o in every:
            bpy.data.objects.remove(o, do_unlink=True)
    s = kit.cached(path, make)
    s.name = "suriel_sculpt"
    zones = zones_for(kinds)
    kit.displace(s, lambda P, N: sb.cloth_field(P, N) * zones(P, N)["cloth"])
    kit.shade_smooth(s)
    kit.paint(s, "zone_a", lambda P, N: np.stack([zones(P, N)[k] for k in ("cloth", "bone", "skin")], axis=1))
    kit.paint(s, "zone_b", lambda P, N: np.stack([zones(P, N)[k] for k in ("gum", "dark", "nail")], axis=1))
    kit.set_material(s, body_material())
    return s, zones


def hard_parts():
    """Teeth, eyes and fingernails at game resolution: [(object, part number)]."""
    out = []
    grey, nail = tooth_material(), nail_material()

    def add(o, part, mat):
        kit.set_material(o, mat)
        out.append((kit.tag(o, part), part))

    # too long for the mouth and always showing: the upper row closes in front of the lower jaw
    for s in (1, -1):
        for i, x in enumerate((0.0065, 0.0185, 0.029, 0.038)):
            long = (0.043, 0.038, 0.032, 0.023)[i] + 0.003 * ((i + (s > 0)) % 2)
            r = (0.0068, 0.0064, 0.0056, 0.0048)[i]
            y = sb.upper_arc(x) - 0.003
            add(kit.horn(f"tooth_u{s}{i}", (s * x, y, 2.017), (s * x * 1.03, y + 0.003, 2.017 - long), r, bend=(1e-4, 0, 0),
                         segs=6, rings=4, flat=0.62, tip_r=0.5), 1, grey)
        for i, x in enumerate((0.006, 0.017, 0.027, 0.036)):
            long = (0.02, 0.022, 0.018, 0.014)[i] + 0.002 * ((i + (s < 0)) % 2)
            y = sb.lower_arc(x)
            add(kit.horn(f"tooth_l{s}{i}", (s * x, y, 1.991), (s * x, y + 0.001, 1.991 + long), 0.005 - 0.0003 * i, bend=(1e-4, 0, 0),
                         segs=6, rings=4, flat=0.62, tip_r=0.5), 2, grey)
    out_n = np.array((0.75, -0.2, 0.62))
    out_n /= np.linalg.norm(out_n)
    for s in (1, -1):
        flip = np.array((s, 1, 1))
        for i, (root, midp, tip) in enumerate(sb.fingers()):
            d = (tip - midp) / np.linalg.norm(tip - midp)
            across = np.cross(d, out_n)
            add(kit.horn(f"nail{s}{i}", (tip - d * 0.013 + out_n * 0.004) * flip, (tip + d * 0.021 + out_n * 0.001) * flip,
                         0.0078 if i == 0 else 0.0068, bend=across * flip * 1e-4, segs=6, rings=4, flat=0.3, tip_r=0.3),
                (20 if s > 0 else 30) + i, nail)
        add(kit.ball(f"eye{s}", tuple(sb.EYE * flip), sb.EYE_R), 10, eye_material(s))
    return out


def rags():
    """The loose cloth: {strip name: object}, each hanging down its chain."""
    out = {}
    mat = rag_material()
    for name, st in suriel_rig.strips().items():
        lean = np.array(st.get("lean", (0.0, 0.0, -1.0)), dtype=np.float64)
        lean /= np.linalg.norm(lean)
        root = np.array(st["root"]) - lean * 0.02          # tucked under the cloth it hangs from
        n = len(st["width"])
        face = np.array(st["face"], dtype=np.float64)
        face /= np.linalg.norm(face)
        side = np.cross(lean, face)
        pts = []
        for i in range(n):
            u = i / (n - 1)
            wob = math.sin(u * 7.0 + st["seed"] * 1.7)
            pts.append(root + lean * ((st["length"] + 0.02) * u) + face * (0.012 * u * wob) + side * (0.01 * u * math.cos(u * 5.0 + st["seed"])))
        o = kit.ribbon(name, pts, st["width"], st["face"], thick=0.0035, ragged=0.75, seed=st["seed"], rings=n + 2)
        kit.set_material(o, mat)
        out[name] = kit.tag(o, 60)
    return out


def face_keys(low):
    """threat (the lipless smile: the jaw drops off the long teeth), speak_open
    and eyes_wide, as shape keys (data/faces/suriel_face.tres plays them)."""
    P = kit.co(low)
    part = kit.parts_of(low)
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    in_head = (y > 0.118) & (np.abs(x) < 0.075) & (z > 1.955) & (z < 2.04)
    jawish = np.where((part == 0) & in_head & (z < sb.LIP_Z), kit.ss((y - 0.118) / 0.035), 0.0)
    jawish = np.where(part == 2, 1.0, jawish)
    low.shape_key_add(name="Basis")

    def key(name, D):
        kb = low.shape_key_add(name=name)
        kb.data.foreach_set("co", (P + D).ravel())

    for name, deg in (("threat", 9.0), ("speak_open", 5.0)):
        D = np.zeros_like(P)
        ang = math.radians(deg)
        ry, rz = y - sb.J["jaw"][1], z - sb.J["jaw"][2]
        D[:, 1] = (ry * (math.cos(ang) - 1) + rz * math.sin(ang)) * jawish
        D[:, 2] = (-ry * math.sin(ang) + rz * (math.cos(ang) - 1)) * jawish
        key(name, D)
    D = np.zeros_like(P)
    for s in (1, -1):
        c = sb.EYE * (s, 1, 1)
        e = (part == 10) & (np.sign(x) == s)
        D[e] = (P[e] - c) * 0.2 + np.array((0.0, 0.005, 0.0))
    key("eyes_wide", D)


def build(fast=False, bake=True):
    kit.reset()
    s, zones = sculpt(0.008 if fast else 0.0055)
    hard = hard_parts()
    cloth = rags()
    low = kit.game_mesh(s, NAME, BODY_TRIS, keep=lambda P: zones(P, np.zeros_like(P))["keep"], keep_bias=0.92)
    kit.tag(low, 0)
    arm = rig.build_armature(NAME, suriel_rig.bones())
    rig.skin(low, arm, fix=suriel_rig.fix_weights)
    pieces = []
    for o, part in hard:
        g = kit.duplicate(o, o.name + "_g")
        rig.bind_rigid(g, suriel_rig.part_bone(part))
        pieces.append(g)
    chains = suriel_rig.chains()
    strips = suriel_rig.strips()
    for name, o in cloth.items():
        g = kit.duplicate(o, name + "_g")
        c = strips[name].get("chain", name)
        rig.bind_chain(g, arm, suriel_rig.chain_bones(c, chains[c]))
        pieces.append(g)
    low = kit.join([low] + pieces, NAME)
    kit.triangulate(low)          # the engine's tangents then match the bake's
    if bake:
        # the face gets twice its share of the texture: it is what she looks at
        kit.unwrap(low, boost=lambda P: 1.0 + 0.9 * kit.ss((P[:, 2] - 1.955) / 0.04) * kit.ss((P[:, 1] - 0.1) / 0.05),
                   centre=(0.0, 0.2, 2.06))
    rig.attach(low, arm)
    face_keys(low)
    sources = [s] + [o for o, _ in hard] + list(cloth.values())
    paths = {}
    kept = kit.baked_material(low, NAME, OUT) if bake == "keep" else None
    if kept:
        _, paths = kept
    elif bake:
        _, paths = kit.bake(sources, low, NAME, OUT, size=1024 if fast else 2048)
    else:
        kit.set_material(low, kit.plain("clay", (0.2, 0.22, 0.22), 0.5))
    r = rig.Rig(arm, low, suriel_rig.spec())
    suriel_clips.author(r)
    r.finish()
    return sources, low, arm, r, paths


if __name__ == "__main__":
    args = sys.argv[1:]
    hide, low, arm, r, paths = build("--fast" in args, bake="keep" if "--keepbake" in args else "--nobake" not in args)
    for name, rep in r.report.items():
        print(f"clip {name}: " + " ".join(f"{k}={v:.4f}" for k, v in rep.items()))
    if "--preview" in args:
        import preview
        d = args[args.index("--preview") + 1]
        still = dict(front34=((2.6, 4.8, 1.7), (0, 0, 1.1), 50), side=((5.4, 0.15, 1.3), (0, 0.0, 1.1), 50),
                     back34=((-2.4, -4.8, 1.8), (0, 0, 1.1), 50), face=((0.42, 1.0, 2.1), (0, 0.2, 2.05), 70),
                     face_side=((0.9, 0.3, 2.07), (0, 0.2, 2.05), 85), hand=((1.25, 0.75, 1.3), (0.72, 0.0, 1.07), 85),
                     foot=((0.75, 0.85, 0.4), (0.1, 0.08, 0.12), 70), back=((0.3, -3.2, 1.9), (0, 0, 1.6), 60))
        for v in args[args.index("--preview") + 2:]:
            if v.startswith("--"):
                break
            if v.startswith("sculpt_"):
                preview.shot(os.path.join(d, f"{v}.png"), still[v[7:]], hide=[low], samples=32)
            elif v in still:
                preview.shot(os.path.join(d, f"low_{v}.png"), still[v], hide=hide, samples=32)
            else:
                clip, cam, at = (v.split("@") + ["", ""])[:3]
                views = dict(front=((0.0, 6.8, 1.2), (0, 0, 1.0), 60), q=((4.8, 4.8, 1.7), (0, 0, 1.0), 60),
                             top=((0.3, 1.2, 5.5), (0.3, 0.3, 0.2), 50), low=((2.6, 3.4, 0.9), (0.0, 0.2, 0.6), 50),
                             side=((6.5, 0.2, 1.1), (0, 0.1, 1.0), 60), back=((-3.6, -5.2, 1.7), (0, 0, 1.0), 60))
                kw = dict(view=views[cam]) if cam else {}
                if at:
                    ts = [float(x) for x in at.split(",")]
                    kw.update(at=ts, frames=len(ts), res=(900, 700))
                preview.strip(arm, low, clip, os.path.join(d, f"clip_{clip}{'_' + cam if cam else ''}.png"), extra=hide, **kw)
    if "--noexport" not in args:
        for o in hide:
            bpy.data.objects.remove(o, do_unlink=True)
        path = kit.export_gltf(NAME, [low, arm], OUT)
        rig.write_gaits(NAME, r, "creatures/models/fae/suriel.gltf")
        print(f"{NAME}: {kit.tris(low)} tris -> {path}")
