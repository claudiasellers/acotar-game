"""The naga (bestiary §2): creatures/models/fae/naga.gltf with its textures,
skeleton, face keys and clips, and data/animation/creatures/naga_gaits.txt.

    /opt/bpyenv/bin/python tools/blender/monsters/naga.py [--preview DIR] [--fast]

--preview DIR also renders check sheets there. --fast bakes 1K maps and a
coarser sculpt, for iterating; never commit a --fast build.
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))

import bpy  # noqa: E402
import numpy as np  # noqa: E402

import kit  # noqa: E402
import naga_body as nb  # noqa: E402
import naga_clips  # noqa: E402
import naga_rig  # noqa: E402
import rig  # noqa: E402

NAME = "naga"
OUT = os.path.join(kit.ROOT, "creatures", "models", "fae")
BODY_TRIS = 11800

# part numbers on the game mesh (kit.tag): which bone carries each hard part
PART_BONE = {1: "head", 2: "jaw", 3: "tongue", 10: "eye"}
# 20+i / 30+i: talon of finger i, right / left.  40+i / 50+i: toe claw i.


# ------------------------------------------------------------------ materials

SCALE = (0.03, 0.035, 0.04)
SEAM = (0.035, 0.075, 0.07)
BELLY = (0.075, 0.08, 0.082)
THROAT = (0.115, 0.105, 0.098)
MOUTH = (0.16, 0.035, 0.04)


def scales_material(mask=False):
    """Near-black scales with a cold undertone in the seams: big plates on the
    shoulders, forearms, back and crown, fine scales on the neck and face,
    transverse plates down the belly, a smooth leathery throat."""
    def build(nt, bsdf):
        g = kit.Graph(nt)
        P = g.position()
        belly, throat, plates = g.split(g.attr("zone_a"))
        fine, mouth, scar = g.split(g.attr("zone_b"))
        scute, _, _ = g.split(g.attr("zone_c"))
        warp = g.noise(P, 9.0, 2.0)

        def layer(scale, squash=(1.0, 1.0, 1.0)):
            v = g.scale_vec(P, squash)
            edge, _ = g.voronoi(v, scale)
            _, cell = g.voronoi(v, scale, feature="F1")
            r, _, _ = g.split(cell)
            return edge, r

        e_m, c_m = layer(105.0, (1.0, 1.0, 0.72))        # scales a little taller than wide
        e_b, c_b = layer(58.0, (1.0, 1.0, 0.8))
        e_f, c_f = layer(185.0)
        edge = g.mix(fine, g.mix(plates, e_m, e_b), e_f)
        cell = g.mix(fine, g.mix(plates, c_m, c_b), c_f)
        # the belly: broad plates across the body, each lapping the one below
        _, _, pz = g.split(P)
        band = g.math("FRACT", g.math("MULTIPLY", g.math("ADD", pz, g.math("MULTIPLY", warp, 0.006)), 30.0))
        tri = g.math("MINIMUM", band, g.math("MULTIPLY", g.math("SUBTRACT", 1.0, band), 4.0))
        edge = g.mix(scute, edge, g.math("MULTIPLY", tri, 0.4))
        cell = g.mix(scute, cell, band)
        plate = g.smooth(edge, 0.0, 0.11)                 # 0 in the seam, 1 on the scale
        seam = g.math("SUBTRACT", 1.0, g.smooth(edge, 0.0, 0.06))
        skin = g.math("MAXIMUM", throat, mouth)
        # each scale lifts toward one edge, so they overlap like a snake's
        height = g.math("ADD", plate, g.math("MULTIPLY", cell, 0.35))
        wrinkle = g.noise(g.scale_vec(P, (1.0, 1.0, 3.5)), 120.0, 4.0)
        height = g.mix(skin, height, g.math("MULTIPLY", wrinkle, 0.5))
        height = g.mix(belly, height, g.math("MULTIPLY", g.math("ADD", plate, g.math("MULTIPLY", cell, 0.35)), 0.6))
        normal = g.bump(height, 0.0028)
        seam_f = g.math("MULTIPLY", seam, g.math("SUBTRACT", 1.0, skin, clamp=True))
        if mask:
            bsdf.inputs["Base Color"].default_value = (0, 0, 0, 1)
            g.out(bsdf, emission=g.combine(0.0, seam_f, scar))
            return
        tone = g.math("ADD", 0.72, g.math("MULTIPLY", cell, 0.6))
        base = g.mix_rgb(belly, SCALE, BELLY)
        col = g.mix_rgb(seam_f, base, SEAM)
        scaled = nt.nodes.new("ShaderNodeVectorMath")
        scaled.operation = "SCALE"
        nt.links.new(col, scaled.inputs[0])
        nt.links.new(tone, scaled.inputs["Scale"])
        col = g.mix_rgb(throat, scaled.outputs["Vector"], THROAT)
        col = g.mix_rgb(mouth, col, MOUTH)
        rough = g.mix(seam_f, g.mix(plates, 0.72, 0.62), 0.92)
        rough = g.mix(throat, rough, 0.58)
        rough = g.mix(mouth, rough, 0.42)
        g.out(bsdf, color=col, rough=rough, normal=normal)
    return kit.sculpt_material("naga_scales_mask" if mask else "naga_scales", build)


def tooth_material():
    def build(nt, bsdf):
        g = kit.Graph(nt)
        grad, _, _ = g.split(g.attr("grad"))
        g.out(bsdf, color=g.mix_rgb(g.smooth(grad, 0.25, 1.0), (0.78, 0.72, 0.58), (0.2, 0.14, 0.1)), rough=0.28)
    return kit.sculpt_material("naga_teeth", build)


def eye_material(side):
    """Amber, almond, a vertical slit pupil; it glows faintly."""
    c = tuple(nb.EYE * (side, 1, 1))
    out_dir = np.array((0.86 * side, 0.48, 0.12))
    out_dir /= np.linalg.norm(out_dir)
    tan = np.cross((0, 0, 1.0), out_dir)
    tan /= np.linalg.norm(tan)

    def build(nt, bsdf):
        g = kit.Graph(nt)
        v = g.sub_vec(g.position(), c)
        r = nb.EYE_R
        x = g.math("DIVIDE", g.dot(v, tuple(tan)), r)            # across the slit
        z = g.math("DIVIDE", g.dot(v, (0.0, 0.0, 1.0)), r)       # along it
        o = g.math("DIVIDE", g.dot(v, tuple(out_dir)), r)
        width = g.math("MULTIPLY", 0.11, g.math("SQRT", g.math("SUBTRACT", 1.0, g.math("POWER", g.math("DIVIDE", z, 0.62), 2.0), clamp=True)))
        slit = g.math("MULTIPLY", g.math("SUBTRACT", 1.0, g.smooth(g.math("ABSOLUTE", x), width, g.math("ADD", width, 0.05))),
                      g.math("GREATER_THAN", o, 0.0))
        radial = g.math("SQRT", g.math("ADD", g.math("POWER", x, 2.0), g.math("POWER", z, 2.0)))
        iris = g.mix_rgb(g.smooth(radial, 0.15, 0.8), (1.0, 0.62, 0.1), (0.42, 0.13, 0.015))
        fleck = g.noise(g.position(), 900.0, 2.0)
        iris = g.mix_rgb(g.math("MULTIPLY", fleck, 0.35), iris, (0.9, 0.36, 0.03))
        col = g.mix_rgb(slit, iris, (0.004, 0.004, 0.004))
        g.out(bsdf, color=col, rough=0.06, emission=g.mix_rgb(slit, iris, (0, 0, 0)), strength=0.55)
    return kit.sculpt_material(f"naga_eye{side}", build)


# ------------------------------------------------------------------ build

def sculpt(voxel):
    def make():
        mid, side = nb.forms()
        s = kit.union(mid + side + [kit.mirror_x(o) for o in side], "naga_sculpt", voxel=voxel)
        kit.carve(s, nb.cutters())
        return s
    s = kit.cached(os.environ.get("MONSTER_SCULPT_CACHE"), make)
    s.name = "naga_sculpt"
    kit.displace(s, nb.scale_field)
    kit.shade_smooth(s)
    paint_zones(s)
    kit.set_material(s, scales_material())
    return s


def paint_zones(obj):
    def za(P, N):
        z = nb.zones(P, N)
        return np.stack([z["belly"], z["throat"], z["plates"]], axis=1)

    def zb(P, N):
        z = nb.zones(P, N)
        scar = kit.ss((0.006 - kit.path_dist(P, nb.SCAR_PATH)) / 0.004)
        return np.stack([z["fine"], z["mouth"], scar], axis=1)
    def zc(P, N):
        z = nb.zones(P, N)
        return np.stack([z["scute"], np.zeros(len(P)), np.zeros(len(P))], axis=1)
    kit.paint(obj, "zone_c", zc)
    kit.paint(obj, "zone_a", za)
    kit.paint(obj, "zone_b", zb)


def hard_parts():
    """Teeth, talons, toe claws, eyes and the tongue, at game resolution.
    Returns [(object, part number)]."""
    out = []
    ivory, talon = tooth_material(), kit.plain("naga_talon", (0.012, 0.012, 0.015), 0.1)
    lid = kit.plain("naga_membrane", (0.42, 0.47, 0.44), 0.3)

    def add(o, part, mat):
        kit.set_material(o, mat)
        out.append((kit.tag(o, part), part))

    # one row of needle teeth, back-curved; the upper row lies outside the lower lip
    ys = np.linspace(0.232, 0.448, 12)
    for s in (1, -1):
        for i, y in enumerate(ys):
            w = nb.skull_half_width(y) * 0.93
            long = 0.03 if i == 9 else 0.013 + 0.008 * (i / 11.0) + 0.003 * (i % 2)   # one long fang near the front
            root = np.array((s * w, y, nb.mouth_z(y) + 0.004))
            add(kit.horn(f"tooth_u{s}{i}", root, root + (s * 0.002, -0.0045, -long), 0.0034 + 0.0012 * (i == 9),
                         bend=(0, 0.004, 0), segs=4, rings=4), 1, ivory)
        for i, y in enumerate(np.linspace(0.25, 0.43, 9)):
            w = nb.skull_half_width(y) * 0.76
            root = np.array((s * w, y, nb.mouth_z(y) - 0.0045))
            add(kit.horn(f"tooth_l{s}{i}", root, root + (0, -0.003, 0.0105 + 0.002 * (i % 2)), 0.0028,
                         bend=(0, 0.003, 0), segs=4, rings=3), 2, ivory)
    for s in (1, -1):
        flip = np.array((s, 1, 1))
        for i, (root, midp, tip, claw) in enumerate(nb.fingers()):
            d = (tip - midp) / np.linalg.norm(tip - midp)
            add(kit.horn(f"talon{s}{i}", (tip - d * 0.012) * flip, claw * flip, 0.0112,
                         bend=np.array((0.012, 0, 0.022)) * flip, segs=6, rings=6, flat=0.72), (20 if s > 0 else 30) + i, talon)
        for i, (root, tip, claw) in enumerate(nb.toes()):
            add(kit.horn(f"toeclaw{s}{i}", (tip - (0, 0.012, -0.002)) * flip, claw * flip, 0.0115,
                         bend=np.array((0, 0.006, 0.014)) * flip, segs=6, rings=5, flat=0.75), (40 if s > 0 else 50) + i, talon)
        add(kit.ball(f"eye{s}", tuple(nb.EYE * flip), nb.EYE_R), 10, eye_material(s))
        add(membrane(s, lid), 11, lid)
    # the silvery forked tongue, lying in the floor of the mouth
    silver = kit.plain("naga_tongue", (0.62, 0.66, 0.72), 0.2)
    z = nb.mouth_z(0.3) - 0.0085
    add(kit.horn("tongue", (0, 0.215, z + 0.001), (0, 0.405, z - 0.003), 0.0085, segs=6, rings=7, flat=0.42, tip_r=0.45), 3, silver)
    for s in (1, -1):
        add(kit.horn(f"fork{s}", (s * 0.002, 0.398, z - 0.003), (s * 0.0085, 0.44, z - 0.004), 0.0036, segs=4, rings=4, flat=0.5), 3, silver)
    return out


def membrane(side, mat=None):
    """The nictitating membrane: a pale lid tucked at the front corner of the
    eye, which the `blink` key slides across sideways."""
    r_ = nb.EYE_R * 1.12
    c = nb.EYE * (side, 1, 1)
    o = kit.ball(f"membrane{side}", tuple(c), r_, segs=12, rings=8)
    out_dir = np.array((0.86 * side, 0.48, 0.12))
    out_dir /= np.linalg.norm(out_dir)
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(o.data)
    gone = [v for v in bm.verts if (np.array(v.co) - c) @ out_dir < r_ * math.cos(math.radians(50))]
    bmesh.ops.delete(bm, geom=gone, context="VERTS")
    bm.to_mesh(o.data)
    bm.free()
    P = kit.co(o)
    kit.set_co(o, _turn_z(P, c, math.radians(-MEMBRANE_TURN * side)))     # parked toward the snout
    return o


MEMBRANE_TURN = 52.0


def _turn_z(P, c, ang):
    ca, sa = math.cos(ang), math.sin(ang)
    v = P - c
    return np.stack([v[:, 0] * ca - v[:, 1] * sa, v[:, 0] * sa + v[:, 1] * ca, v[:, 2]], axis=1) + c


def face_keys(low):
    """threat, hiss, speak_open, blink, eyes_wide, nostrils (bestiary §2.5) and tongue,
    as shape keys on the game mesh. The jaw's swing is the `jaw` bone's; these
    are what a bone cannot do: lips, lids, nostrils."""
    P = kit.co(low)
    part = kit.parts_of(low)
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    lip = np.array([nb.mouth_z(v) for v in y])
    head = (y > 0.19) & (z > 1.75) & (np.abs(x) < 0.11) & (part == 0)
    near_lip = kit.ss((0.016 - np.abs(z - lip)) / 0.012) * head
    upper = (z >= lip)
    edge = kit.ss((np.abs(x) - 0.45 * np.array([nb.skull_half_width(v) for v in y])) / 0.02)   # the lips, not the palate
    low.shape_key_add(name="Basis")

    def key(name, D):
        kb = low.shape_key_add(name=name)
        kb.data.foreach_set("co", (P + D).ravel())

    # threat: the smile. The upper lip lifts off the teeth, the corners draw back.
    D = np.zeros_like(P)
    D[:, 2] += near_lip * edge * np.where(upper, 0.0045, -0.0035)
    corner = near_lip * kit.ss((0.27 - y) / 0.06)
    D[:, 1] -= 0.009 * corner
    D[:, 2] += 0.004 * corner
    key("threat", D)
    # hiss / speak_open: the lower lip and the floor of the mouth drop and the lips part further
    jawish = ((head & ~upper) | (part == 2) | (part == 3)).astype(float)
    for name, deg, purse in (("hiss", 7.0, 0.0), ("speak_open", 4.0, 0.08)):
        D = np.zeros_like(P)
        ang = math.radians(deg)
        ry, rz = y - nb.J["jaw"][1], z - nb.J["jaw"][2]
        D[:, 1] += (ry * (math.cos(ang) - 1) + rz * math.sin(ang)) * jawish
        D[:, 2] += (-ry * math.sin(ang) + rz * (math.cos(ang) - 1)) * jawish
        D[:, 0] -= purse * x * near_lip * kit.ss((y - 0.36) / 0.06)
        D[:, 2] += 0.002 * near_lip * edge * upper
        key(name, D)
    # nostrils flare as it scents her
    D = np.zeros_like(P)
    for s in (1, -1):
        c = np.array((0.0125 * s, 0.4585, 1.8455))
        v = P - c
        d = np.linalg.norm(v, axis=1)
        w = kit.ss((0.016 - d) / 0.012) * (part == 0)
        D += (v / np.maximum(d, 1e-6)[:, None]) * (0.003 * w)[:, None] * np.array((1.0, 0.3, 0.6))
    key("nostrils", D)
    # eyes: the membrane slides across; the eye bulges a touch when wide
    D = np.zeros_like(P)
    Dw = np.zeros_like(P)
    for s in (1, -1):
        c = nb.EYE * (s, 1, 1)
        m = (part == 11) & (np.sign(x) == s)
        D[m] = _turn_z(P[m], c, math.radians(MEMBRANE_TURN * s)) - P[m]
        e = (part == 10) & (np.sign(x) == s)
        Dw[e] = (P[e] - c) * 0.1 + np.array((0.0018 * s, 0.0008, 0))
        rim = kit.ss((0.03 - np.linalg.norm(P - c, axis=1)) / 0.012) * (part == 0)
        Dw[:, 2] += 0.0025 * rim * np.sign(z - c[2])
    key("blink", D)
    key("eyes_wide", Dw)
    # tongue: the face driver's idle flick (systems/faces); the clips use the tongue bones
    D = np.zeros_like(P)
    t = part == 3
    along = (y[t] - y[t].min()) / max(np.ptp(y[t]), 1e-6)
    D[t, 1] = 0.035 + 0.075 * along
    D[t, 2] = -0.012 * along
    key("tongue", D)


def build(fast=False, bake=True):
    kit.reset()
    s = sculpt(0.008 if fast else 0.0055)
    hard = hard_parts()
    low = kit.game_mesh(s, NAME, BODY_TRIS, keep=lambda P: nb.zones(P, np.zeros_like(P))["keep"])
    kit.tag(low, 0)
    arm = rig.build_armature(NAME, naga_rig.bones())
    rig.skin(low, arm, fix=naga_rig.fix_weights)
    pieces = []
    for o, part in hard:
        g = kit.duplicate(o, o.name + "_g")
        if part == 3:
            naga_rig.bind_tongue(g)
        else:
            rig.bind_rigid(g, naga_rig.part_bone(part))
        pieces.append(g)
    low = kit.join([low] + pieces, NAME)
    kit.triangulate(low)          # the engine's tangents then match the bake's
    if bake:
        # the head gets twice its share of the texture: it is what she looks at
        kit.unwrap(low, boost=lambda P: 1.0 + 0.9 * kit.ss((P[:, 2] - 1.66) / 0.08), centre=(0.0, 0.3, 1.8))
    rig.attach(low, arm)
    face_keys(low)
    paths = {}
    kept = kit.baked_material(low, NAME, OUT) if bake == "keep" else None
    if kept:
        _, paths = kept
    elif bake:
        talon_mask = kit.plain("_mask_glint", (0, 0, 0), 1.0, emission=(1, 0, 0), strength=1.0)
        masks = {s: scales_material(mask=True)}
        for o, part in hard:
            if part >= 20:
                masks[o] = talon_mask
        mat, paths = kit.bake([s] + [o for o, _ in hard], low, NAME, OUT, size=1024 if fast else 2048, masks=masks)
    else:
        kit.set_material(low, kit.plain("clay", (0.2, 0.22, 0.22), 0.5))
    r = rig.Rig(arm, low, naga_rig.spec())
    naga_clips.author(r)
    r.finish()
    return s, hard, low, arm, r, paths


if __name__ == "__main__":
    args = sys.argv[1:]
    fast = "--fast" in args
    # --keepbake: reuse the maps of the last full bake (same sculpt, new clips)
    s, hard, low, arm, r, paths = build(fast, bake="keep" if "--keepbake" in args else "--nobake" not in args)
    for name, rep in r.report.items():
        print(f"clip {name}: " + " ".join(f"{k}={v:.4f}" for k, v in rep.items()))
    hide = [s] + [o for o, _ in hard]
    if "--preview" in args:
        import preview
        d = args[args.index("--preview") + 1]
        for v in args[args.index("--preview") + 2:]:
            if v.startswith("--"):
                break
            if v in preview.VIEWS:
                preview.shot(os.path.join(d, f"low_{v}.png"), v, hide=hide, samples=32)
            else:
                clip, cam, at = (v.split("@") + ["", ""])[:3]
                views = dict(front=((0.0, 6.5, 1.0), (0, 0, 0.95), 60), q=((4.6, 4.6, 1.6), (0, 0, 0.9), 60),
                             top=((0.3, 1.2, 5.5), (0.3, 0.3, 0.2), 50), low=((2.6, 3.4, 0.9), (0.3, 0.2, 0.3), 50))
                kw = dict(view=views[cam]) if cam else {}
                if at:
                    ts = [float(x) for x in at.split(",")]
                    kw.update(at=ts, frames=len(ts), res=(900, 700))
                preview.strip(arm, low, clip, os.path.join(d, f"clip_{clip}{'_' + cam if at else ''}.png"), extra=hide, **kw)
    if "--dump" in args:
        clip = args[args.index("--dump") + 1]
        act = bpy.data.actions[clip]
        arm.animation_data.action = act
        if hasattr(arm.animation_data, "action_slot") and act.slots:
            arm.animation_data.action_slot = act.slots[0]
        bpy.context.scene.frame_set(int(act.frame_range[1]))
        bpy.context.view_layer.update()
        for b in ("pelvis", "chest", "neck", "head", "jaw", "arm_r", "forearm_r", "hand_r", "arm_l", "forearm_l", "hand_l",
                  "upper_leg_r", "lower_leg_r", "foot_leg_r", "paw_leg_r", "upper_leg_l", "lower_leg_l", "foot_leg_l", "paw_leg_l"):
            pb = arm.pose.bones[b]
            print(f"dump {b:12s} head {tuple(round(x, 2) for x in pb.head)} tail {tuple(round(x, 2) for x in pb.tail)} up {tuple(round(x, 2) for x in pb.z_axis)}")
        arm.animation_data.action = None
    if "--noexport" not in args:
        for o in hide:
            bpy.data.objects.remove(o, do_unlink=True)
        path = kit.export_gltf(NAME, [low, arm], OUT)
        rig.write_gaits(NAME, r, "creatures/models/fae/naga.gltf")
        print(f"{NAME}: {kit.tris(low)} tris -> {path}")
