"""Skeleton, skin weights and authored clips for the quadruped creatures.

Imported by tools/blender/creatures.py (and anything else built on its
`quadruped()` graph). Every bone sits on a joint of the skin-modifier graph the
body was grown from, so the skeleton matches the mesh exactly and needs no
hand rigging. Clips are authored here as motion, not as keyframes: gait cycles
from leg phase tables with a small analytic leg IK so planted paws stay planted,
and hit and death clips from timed curves. Deterministic, like the rest of the
generator: no randomness, so regenerating gives the same files.

Clips (each a glTF animation, in place, the game moves the body):
  idle, walk, trot, gallop, graze (+ stalk for wolves)   looping
  hit_l, hit_r       an arrow strikes the left / right side
  death_l, death_r   falls onto the left / right flank and dies; the last frame
                     holds. `death_breaths` sets how slowly (the great wolf
                     "dies slowly", ch1).

The native ground speed of each gait clip is written to
data/animation/creatures/<name>_gaits.txt for the game's CreatureAnimator.

Axes: Blender y is forward, z is up, +x is the creature's right.
"""

import math
import os

import bpy
import numpy as np
from mathutils import Euler, Matrix, Quaternion, Vector

FPS = 30
UP = Vector((0, 0, 1))
FWD = Vector((0, 1, 0))
LEGS = ("fl_l", "fl_r", "hl_l", "hl_r")


# ------------------------------------------------------------------ curves

def clamp01(x):
    return 0.0 if x < 0.0 else 1.0 if x > 1.0 else x


def seg(t, a, b):
    """0 before a, 1 after b, linear between."""
    return clamp01((t - a) / (b - a)) if b > a else float(t >= a)


def smooth(x):
    x = clamp01(x)
    return x * x * (3.0 - 2.0 * x)


def ease_in(x):
    x = clamp01(x)
    return x * x


def ease_out(x):
    x = clamp01(x)
    return 1.0 - (1.0 - x) * (1.0 - x)


def ring(t, t0, amp, freq, damp):
    """A damped oscillation that starts at t0 (a bounce, a shudder)."""
    if t < t0:
        return 0.0
    dt = t - t0
    return amp * math.exp(-damp * dt) * math.sin(2.0 * math.pi * freq * dt)


def pulse(t, a, peak, b):
    """0 -> 1 (eased out by `peak`) -> 0 (smooth by b)."""
    if t <= a or t >= b:
        return 0.0
    if t < peak:
        return ease_out(seg(t, a, peak))
    return 1.0 - smooth(seg(t, peak, b))


def rad(d):
    return math.radians(d)


# ------------------------------------------------------------------ armature

def _P(g, name):
    return Vector(g.points[g.names[name]])


def build_armature(g, spec):
    """Bones on the graph joints. Spine and head bones roll Z up; legs, ears and
    the ribs roll Z forward, so every bone's local X is the creature's right
    and a rotation about X is a pitch (flex or extend)."""
    L = spec["length"]
    data = bpy.data.armatures.new("Rig")
    arm = bpy.data.objects.new("Rig", data)
    bpy.context.collection.objects.link(arm)
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = arm
    arm.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    eb = data.edit_bones

    def bone(name, head, tail, parent, axis):
        b = eb.new(name)
        b.head, b.tail = Vector(head), Vector(tail)
        b.align_roll(axis)
        if parent:
            b.parent = eb[parent]
        b.use_connect = False
        b.use_deform = True
        return b

    mid, hip, chest, sh = _P(g, "mid"), _P(g, "hip"), _P(g, "chest"), _P(g, "shoulder")
    r_body = spec["girth"]
    bone("root", (0, 0, 0), (0, 0.25 * L, 0), None, UP)
    bone("body", mid, mid + Vector((0, 0.15 * L, 0)), "root", UP)
    bone("hips", mid, hip, "body", UP)
    bone("spine", mid, chest, "body", UP)
    rib = (mid + chest) * 0.5
    bone("ribs", rib, rib - Vector((0, 0, r_body * 0.95)), "spine", FWD)
    bone("chest", chest, sh, "spine", UP)
    bone("neck", sh, _P(g, "neck"), "chest", UP)
    bone("head", _P(g, "neck"), _P(g, "head"), "neck", UP)
    bone("muzzle", _P(g, "head"), _P(g, "snout"), "head", UP)
    if "jaw" in g.names:
        bone("jaw", _P(g, "head"), _P(g, "jaw"), "head", UP)
    for side, tag in ((-1, "l"), (1, "r")):
        bone(f"ear_{tag}", _P(g, f"ear{side}"), _P(g, f"eart{side}"), "head", FWD)
    bone("tail0", hip, _P(g, "tail0"), "hips", UP)
    prev, prev_bone, i = _P(g, "tail0"), "tail0", 0
    while f"tail_{i}" in g.names:
        name = f"tail{i + 1}"
        bone(name, prev, _P(g, f"tail_{i}"), prev_bone, UP)
        prev, prev_bone, i = _P(g, f"tail_{i}"), name, i + 1
    for key, parent in (("fl", "chest"), ("hl", "hips")):
        for side, tag in ((-1, "l"), (1, "r")):
            p = [_P(g, f"{key}{side}_{k}") for k in range(4)]
            leg = f"{key}_{tag}"
            bone(f"upper_{leg}", p[0], p[1], parent, FWD)
            bone(f"lower_{leg}", p[1], p[2], f"upper_{leg}", FWD)
            bone(f"paw_{leg}", p[2], p[3], f"lower_{leg}", FWD)
    bpy.ops.object.mode_set(mode="OBJECT")
    return arm


# ------------------------------------------------------------------ weights

# Bones that skin nothing themselves (they carry motion only).
CARRIERS = ("root", "body")


def _segments(arm):
    out = []
    for b in arm.data.bones:
        if b.name in CARRIERS:
            continue
        out.append((b.name, b.head_local.copy(), b.tail_local.copy()))
    return out


def weight_body(obj, arm):
    """Skin weights by distance to each bone segment. Up to three bones share a
    vertex, so joints bend smoothly. Leg, ear and tail bones don't reach past
    their own root, so the torso stays on the spine."""
    segs = _segments(arm)
    names = [s[0] for s in segs]
    heads = np.array([s[1] for s in segs])
    tails = np.array([s[2] for s in segs])
    axis = tails - heads
    length2 = np.maximum((axis * axis).sum(1), 1e-9)
    limb = np.array([n.startswith(("upper_", "ear_", "tail")) for n in names])
    groups = [obj.vertex_groups.new(name=n) for n in names]
    co = np.zeros(len(obj.data.vertices) * 3)
    obj.data.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    for vi, p in enumerate(co):
        rel = p - heads
        t = (rel * axis).sum(1) / length2
        tc = np.clip(t, 0.0, 1.0)
        d = np.linalg.norm(rel - axis * tc[:, None], axis=1)
        d = np.where(limb & (t < 0.0), d * 1.7, d)
        d = np.where(names_ribs_mask(names), d * 1.15, d)
        order = np.argsort(d)[:3]
        dm = d[order[0]] + 1e-4
        w = np.array([((dm) / (d[o] + 1e-4)) ** 8 for o in order])
        w = np.where(d[order] < dm * 1.6 + 0.01, w, 0.0)
        w /= w.sum()
        for o, wt in zip(order, w):
            if wt > 0.01:
                groups[o].add([vi], float(wt), "REPLACE")


_RIBS_CACHE = {}


def names_ribs_mask(names):
    key = tuple(names)
    if key not in _RIBS_CACHE:
        _RIBS_CACHE[key] = np.array([n == "ribs" for n in names])
    return _RIBS_CACHE[key]


def weight_rigid(obj, bone):
    group = obj.vertex_groups.new(name=bone)
    group.add(list(range(len(obj.data.vertices))), 1.0, "REPLACE")


def skin(obj, arm):
    obj.parent = arm
    mod = obj.modifiers.new("Armature", "ARMATURE")
    mod.object = arm


# ------------------------------------------------------------------ the rig at pose time

class Rig:
    """Rest data plus a pose solver: armature-space matrices from a pose spec,
    then each bone's local (matrix_basis) transform."""

    def __init__(self, arm, spec, g):
        self.arm = arm
        self.spec = spec
        bones = arm.data.bones
        self.rest = {b.name: b.matrix_local.copy() for b in bones}
        self.parent = {b.name: (b.parent.name if b.parent else None) for b in bones}
        self.order = []

        def walk(b):
            self.order.append(b.name)
            for c in b.children:
                walk(c)
        for b in bones:
            if b.parent is None:
                walk(b)
        self.length = {b.name: b.length for b in bones}
        self.L, self.H, self.W = spec["length"], spec["height"], spec["width"]
        self.r_body = spec["girth"]
        self.mid = bones["body"].head_local.copy()
        self.foot = {leg: bones[f"lower_{leg}"].tail_local.copy() for leg in LEGS}
        self.paw_vec = {leg: bones[f"paw_{leg}"].tail_local - bones[f"paw_{leg}"].head_local for leg in LEGS}
        # Claws reach past the toe joint (creatures.py: base +0.6 leg, tip +1.5 leg).
        self.claw = Vector((0, 1.5 * spec["leg"], -0.012)) if spec.get("claws") else Vector()
        self.leg_len = bones["hips"].tail_local.z
        self.has_jaw = "jaw" in bones
        self.tail_bones = [b.name for b in bones if b.name.startswith("tail")]
        # Height-based time scale (dynamic similarity): a bigger animal moves
        # with longer, slower beats.
        self.ts = math.sqrt(self.H / 0.8)

    # Pose spec: dict with optional keys
    #   body: (offset Vector, Euler(pitch, roll, yaw) about the body bone's head)
    #   rot: {bone: (x, y, z) radians, local}
    #   feet: {leg: (target Vector, paw_pitch)}   leg IK, armature space
    #   ik: {leg: weight 0..1}  (default 1 when the leg has a foot target)
    #   limp: {leg: ((ux, uy, uz), (lx, ly, lz), (px, py, pz))}  FK when ik < 1
    #   scale: {bone: Vector}
    def solve(self, pose):
        M, out = {}, {}
        rot = pose.get("rot", {})
        feet = pose.get("feet", {})
        ik = pose.get("ik", {})
        limp = pose.get("limp", {})
        scale = pose.get("scale", {})
        for name in self.order:
            if name in out:
                continue
            p = self.parent[name]
            base = (M[p] @ self.rest[p].inverted() @ self.rest[name]) if p else self.rest[name].copy()
            if name == "body":
                off, eul = pose.get("body", (Vector(), Euler()))
                head = self.rest["body"].translation
                Md = (Matrix.Translation(off) @ Matrix.Translation(head) @ eul.to_matrix().to_4x4()
                      @ Matrix.Translation(-head) @ self.rest["body"])
                Md = (M[p] @ self.rest[p].inverted()) @ Md if p else Md
                Lb = base.inverted() @ Md
            elif name.startswith("upper_"):
                leg = name[len("upper_"):]
                self._leg(leg, base, M, out, feet.get(leg), ik.get(leg, 1.0 if leg in feet else 0.0),
                          limp.get(leg), p)
                continue
            else:
                e = rot.get(name, (0.0, 0.0, 0.0))
                Lb = Euler(e, "XYZ").to_matrix().to_4x4()
                if name in scale:
                    Lb = Lb @ Matrix.Diagonal(scale[name].to_4d())
            M[name] = base @ Lb
            out[name] = Lb
        return out

    def _fk_local(self, angles):
        return Euler(angles or (0.0, 0.0, 0.0), "XYZ").to_matrix().to_4x4()

    def _leg(self, leg, base_u, M, out, foot, w, limp, parent):
        u, lo, pw = f"upper_{leg}", f"lower_{leg}", f"paw_{leg}"
        fk = limp or ((0, 0, 0), (0, 0, 0), (0, 0, 0))
        Lu_fk, Ll_fk, Lp_fk = (self._fk_local(a) for a in fk)
        if foot is None or w <= 0.0:
            Lu, Ll, Lp = Lu_fk, Ll_fk, Lp_fk
        else:
            target, paw_pitch = foot
            # Parent's rotation since rest: the pole and the paw follow the body's yaw.
            R = (M[parent].to_3x3() @ self.rest[parent].to_3x3().inverted()).normalized()
            back = R @ Vector((0, -1, 0))
            A = base_u.translation
            l1, l2 = self.length[u], self.length[lo]
            to = target - A
            d = max(min(to.length, l1 + l2 - 1e-4), abs(l1 - l2) + 1e-4)
            n = to.normalized()
            wv = back - n * back.dot(n)
            wv = wv.normalized() if wv.length > 1e-6 else Vector((0, -1, 0))
            a = (l1 * l1 - l2 * l2 + d * d) / (2.0 * d)
            h = math.sqrt(max(l1 * l1 - a * a, 0.0))
            B = A + n * a + wv * h
            C = A + n * d
            Mu = _frame(A, (B - A).normalized(), wv)
            Lu_ik = base_u.inverted() @ Mu
            base_l = Mu @ self.rest[u].inverted() @ self.rest[lo]
            Ml = _frame(B, (C - B).normalized(), wv)
            Ll_ik = base_l.inverted() @ Ml
            # The paw keeps its rest angle to the ground, turned with the body's yaw only.
            yaw = _yaw_only(R)
            flex = Matrix.Rotation(paw_pitch, 4, yaw @ Vector((1, 0, 0)))
            Rp = flex @ yaw.to_4x4() @ self.rest[pw]
            Rp.translation = C
            base_p = Ml @ self.rest[lo].inverted() @ self.rest[pw]
            Lp_ik = base_p.inverted() @ Rp
            if w >= 1.0:
                Lu, Ll, Lp = Lu_ik, Ll_ik, Lp_ik
            else:
                Lu, Ll, Lp = (_blend(f, i, w) for f, i in ((Lu_fk, Lu_ik), (Ll_fk, Ll_ik), (Lp_fk, Lp_ik)))
        M[u] = base_u @ Lu
        M[lo] = M[u] @ self.rest[u].inverted() @ self.rest[lo] @ Ll
        M[pw] = M[lo] @ self.rest[lo].inverted() @ self.rest[pw] @ Lp
        out[u], out[lo], out[pw] = Lu, Ll, Lp


def _frame(origin, y, pole):
    """A bone matrix whose Y runs along `y` and whose Z faces away from the pole
    (the elbow or hock bends toward the pole)."""
    z = -(pole - y * pole.dot(y))
    z = z.normalized() if z.length > 1e-6 else Vector((0, 1, 0))
    x = y.cross(z).normalized()
    z = x.cross(y).normalized()
    m = Matrix((x, y, z)).transposed().to_4x4()
    m.translation = origin
    return m


def _yaw_only(R):
    f = R @ Vector((0, 1, 0))
    yaw = math.atan2(-f.x, f.y)
    return Matrix.Rotation(yaw, 3, "Z")


def _blend(a, b, w):
    la, ra, sa = a.decompose()
    lb, rb, sb = b.decompose()
    m = ra.slerp(rb, w).to_matrix().to_4x4()
    m.translation = la.lerp(lb, w)
    return m


# ------------------------------------------------------------------ keying

def key_clip(rig, name, poses, ground=None):
    """Keys one pose per frame into a new action on its own NLA track (the glTF
    exporter writes one animation per track). `ground`: for death clips, the
    frame from which the body lies on the ground; every later frame is moved so
    its lowest vertex touches y = 0, and no earlier frame sinks below it."""
    arm = rig.arm
    locals_ = [rig.solve(p) for p in poses]
    if ground is not None:
        dz = _ground_offsets(rig, locals_, ground)
        for i, L in enumerate(locals_):
            L["body"] = Matrix.Translation((0, 0, dz[i])) @ L["body"]
    ad = arm.animation_data or arm.animation_data_create()
    for t in ad.nla_tracks:
        t.mute = True
    act = bpy.data.actions.new(name)
    ad.action = act
    _key_frames(arm, locals_)
    ad.action = None
    track = ad.nla_tracks.new()
    track.name = name
    strip = track.strips.new(name, 0, act)
    strip.name = name
    for t in ad.nla_tracks:
        t.mute = False
    return act


def _key_frames(arm, locals_):
    prev = {}
    for f, L in enumerate(locals_):
        for name, m in L.items():
            pb = arm.pose.bones[name]
            pb.rotation_mode = "QUATERNION"
            loc, q, sca = m.decompose()
            if name in prev and prev[name].dot(q) < 0.0:
                q = -q
            prev[name] = q
            pb.rotation_quaternion = q
            pb.keyframe_insert("rotation_quaternion", frame=f)
            if name in ("root", "body"):
                pb.location = loc
                pb.keyframe_insert("location", frame=f)
            if name == "ribs":
                pb.scale = sca
                pb.keyframe_insert("scale", frame=f)


def _apply_pose(arm, L):
    for name, m in L.items():
        pb = arm.pose.bones[name]
        pb.rotation_mode = "QUATERNION"
        loc, q, sca = m.decompose()
        pb.rotation_quaternion = q
        pb.location = loc if name in ("root", "body") else Vector()
        pb.scale = sca if name == "ribs" else Vector((1, 1, 1))


def _torso_mask(rig):
    """Vertices whose main bone is not a leg: while it is still falling, only
    these may lift the body (limp legs sweep through the ground for a few
    frames rather than levitating the whole animal)."""
    mesh = rig.mesh
    legs = {g.index for g in mesh.vertex_groups if g.name.startswith(("upper_", "lower_", "paw_"))}
    mask = np.ones(len(mesh.data.vertices), dtype=bool)
    for v in mesh.data.vertices:
        if v.groups:
            g = max(v.groups, key=lambda gg: gg.weight)
            mask[v.index] = g.group not in legs
    return mask


def _lowest(rig, L, mask=None):
    mesh = rig.mesh
    _apply_pose(rig.arm, L)
    bpy.context.view_layer.update()
    deps = bpy.context.evaluated_depsgraph_get()
    ev = mesh.evaluated_get(deps)
    me = ev.to_mesh()
    co = np.zeros(len(me.vertices) * 3)
    me.vertices.foreach_get("co", co)
    ev.to_mesh_clear()
    z = co.reshape(-1, 3)[:, 2]
    return float(z[mask].min() if mask is not None else z.min())


def _ground_offsets(rig, locals_, ground_frame):
    ad = rig.arm.animation_data
    if ad:
        ad.action = None
        for t in ad.nla_tracks:
            t.mute = True
    raw = []
    torso = _torso_mask(rig)
    for i, L in enumerate(locals_):
        if i >= ground_frame:
            raw.append(-_lowest(rig, L))
        else:
            raw.append(max(0.0, -_lowest(rig, L, torso)))
    # Ease the correction in over the frames around first contact, so the body
    # lands rather than snaps.
    dz = []
    blend = max(int(0.12 * FPS), 1)
    for i, v in enumerate(raw):
        if ground_frame - blend <= i < ground_frame:
            k = (i - (ground_frame - blend)) / blend
            v = max(raw[i], raw[ground_frame] * smooth(k))
        dz.append(v)
    return dz


# ------------------------------------------------------------------ gaits

GAITS = {
    # name: period (s, wolf scale), duty, stance travel (x leg length), lift (x H), leg phases
    "walk": dict(T=1.0, duty=0.64, D=0.6, lift=0.09, phase={"hl_l": 0.0, "fl_l": 0.25, "hl_r": 0.5, "fl_r": 0.75}),
    "trot": dict(T=0.6, duty=0.45, D=0.8, lift=0.12, phase={"fl_l": 0.0, "hl_r": 0.0, "fl_r": 0.5, "hl_l": 0.5}),
    "gallop": dict(T=0.36, duty=0.32, D=1.1, lift=0.16, phase={"hl_l": 0.0, "hl_r": 0.1, "fl_l": 0.5, "fl_r": 0.6}),
    "stalk": dict(T=1.2, duty=0.75, D=0.85, lift=0.06, phase={"hl_l": 0.0, "fl_l": 0.25, "hl_r": 0.5, "fl_r": 0.75}),
}
HOP = {
    "walk": dict(T=0.8, duty=0.55, D=0.5, lift=0.10, phase={"hl_l": 0.0, "hl_r": 0.0, "fl_l": 0.55, "fl_r": 0.6}),
    "trot": dict(T=0.45, duty=0.45, D=0.8, lift=0.14, phase={"hl_l": 0.0, "hl_r": 0.02, "fl_l": 0.5, "fl_r": 0.56}),
    "gallop": dict(T=0.3, duty=0.28, D=1.2, lift=0.18, phase={"hl_l": 0.0, "hl_r": 0.04, "fl_l": 0.42, "fl_r": 0.5}),
}


def gait_speed(rig, g):
    T = g["T"] * rig.ts
    return g["D"] * rig.leg_len / (g["duty"] * T)


def _foot(rig, leg, p, g, lift_scale=1.0, D_scale=1.0):
    """Paw joint target and paw pitch for a leg at its own phase p (0..1)."""
    c0 = rig.foot[leg]
    D = g["D"] * rig.leg_len * D_scale
    duty = g["duty"]
    front = leg.startswith("f")
    lift = g["lift"] * rig.H * lift_scale * (1.0 if front else 0.8)
    if p < duty:
        q = p / duty
        y = c0.y + D * 0.5 - D * q
        z = c0.z
        # Heel-off: the paw rolls onto its toes at the end of the stance.
        pitch = -rad(25.0 if front else 18.0) * smooth(seg(q, 0.75, 1.0))
    else:
        s = (p - duty) / (1.0 - duty)
        y = c0.y - D * 0.5 + D * smooth(s)
        z = c0.z + lift * math.sin(math.pi * clamp01(s * 1.1)) ** (0.8 if front else 1.0)
        # Swing: the paw folds back (the front carpus much more), then reaches.
        fold = rad(95.0 if front else 45.0) * math.sin(math.pi * clamp01(s / 0.75))
        reach = rad(12.0) * smooth(seg(s, 0.7, 1.0)) * (1.0 - smooth(seg(s, 0.95, 1.0)))
        pitch = -fold * (1.0 - smooth(seg(s, 0.55, 0.9))) - rad(25.0 if front else 18.0) * (1.0 - smooth(seg(s, 0.0, 0.2))) + reach
    return _toe_on_ground(rig, leg, Vector((c0.x, y, z)), pitch), pitch


def _toe_on_ground(rig, leg, wrist, pitch):
    """Lifts the paw joint so a pitched paw's toe never goes below its rest
    height: heel-off rolls over the toe instead of driving it into the ground."""
    R = Matrix.Rotation(pitch, 3, "X")
    floor = rig.foot[leg].z + rig.paw_vec[leg].z
    lift = 0.0
    for tip, rest_z in ((rig.paw_vec[leg], floor), (rig.paw_vec[leg] + rig.claw, floor + rig.claw.z)):
        z = wrist.z + (R @ tip).z
        lift = max(lift, rest_z - z)
    return wrist + Vector((0, 0, lift))


def gait_clip(rig, name, g, style):
    T = g["T"] * rig.ts
    n = max(int(round(T * FPS)), 8)
    H, L = rig.H, rig.L
    poses = []
    for i in range(n + 1):
        t = i / n
        w = 2.0 * math.pi * t
        feet = {leg: _foot(rig, leg, (t - g["phase"][leg]) % 1.0, g, D_scale=1.0) for leg in LEGS}
        crouch = 0.0
        if name == "walk":
            bob, pitch, roll = -0.012 * H * math.cos(2 * w), rad(1.2) * math.sin(2 * w), rad(2.0) * math.sin(w)
            spine, neck = rad(1.5) * math.sin(2 * w + 0.6), rad(3.0) * math.sin(2 * w + 1.4)
            tail_amp, tail_lift = rad(9.0), 0.0
            ears = 0.0
        elif name == "trot":
            bob, pitch, roll = -0.02 * H * math.cos(2 * w), rad(1.0) * math.sin(2 * w), rad(1.0) * math.sin(w)
            spine, neck = rad(1.0) * math.sin(2 * w), rad(-2.0) * math.cos(2 * w)
            tail_amp, tail_lift = rad(7.0), rad(6.0)
            ears = -rad(10.0)
        elif name == "gallop":
            # Suspension after the front stance: the body flies and the spine
            # gathers then extends once a stride.
            bob = 0.05 * H * math.sin(w + 0.4)
            pitch = rad(6.0) * math.sin(w - 0.6)
            roll = rad(1.5) * math.sin(w)
            spine = rad(10.0) * math.sin(w + 1.2)
            neck = -rad(6.0) * math.sin(w - 0.6) - rad(8.0)
            tail_amp, tail_lift = rad(5.0), rad(28.0)
            ears = -rad(35.0)
        else:  # stalk: belly-low, shoulders working, head low and dead level
            crouch = 0.17 * H
            bob, pitch, roll = -0.006 * H * math.cos(2 * w), rad(-3.0), rad(1.0) * math.sin(w)
            spine, neck = rad(1.0) * math.sin(2 * w), rad(-18.0) + rad(1.0) * math.sin(2 * w + 1.4)
            tail_amp, tail_lift = rad(2.0), rad(-20.0)
            ears = rad(8.0)
        if style == "hop":
            bob = 0.06 * H * math.sin(w + 0.2)
            pitch = rad(9.0) * math.sin(w - 0.4)
            spine = rad(12.0) * math.sin(w + 1.0)
            roll = 0.0
        offset = Vector((0.0, 0.0, bob - crouch))
        tail = {}
        for k, tb in enumerate(rig.tail_bones):
            lag = 0.7 * k
            tail[tb] = (tail_lift / max(len(rig.tail_bones), 1) + (rad(3.0) * math.sin(2 * w + lag) if name == "gallop" else 0.0),
                        0.0, tail_amp * math.sin(w - lag) * (0.5 + 0.5 * k / max(len(rig.tail_bones), 1)))
        rot = {
            "spine": (spine, 0.0, rad(1.5) * math.sin(w + 0.5) if name == "walk" else 0.0),
            "hips": (spine * 0.8, 0.0, 0.0),
            "chest": (spine * 0.4, 0.0, 0.0),
            "neck": (neck - pitch, 0.0, 0.0),
            "head": (-neck * 0.5 - pitch * 0.5, 0.0, 0.0),
            "ear_l": (ears, 0.0, 0.0), "ear_r": (ears, 0.0, 0.0),
            **tail,
        }
        if rig.has_jaw and name == "gallop":
            rot["jaw"] = (-rad(10.0) - rad(4.0) * math.sin(w), 0.0, 0.0)
        breath = 1.0 + (0.03 if name == "gallop" else 0.012) * math.sin(w * (1 if name == "gallop" else 2))
        poses.append({"body": (offset, Euler((pitch, roll, 0.0), "XYZ")), "feet": feet, "rot": rot,
                      "scale": {"ribs": Vector((breath, breath, 1.0 + (breath - 1.0) * 0.3))}})
    key_clip(rig, name, poses)
    return gait_speed(rig, g), T


def _standing_feet(rig, shift=None):
    shift = shift or {}
    return {leg: (rig.foot[leg] + shift.get(leg, Vector()), 0.0) for leg in LEGS}


def idle_clip(rig, menace):
    T = 4.0 * rig.ts
    n = int(round(T * FPS))
    poses = []
    for i in range(n + 1):
        t = i / n
        w = 2.0 * math.pi * t
        breath = 1.0 + 0.022 * math.sin(2 * w)
        flick = pulse(t, 0.30, 0.32, 0.38)
        flick2 = pulse(t, 0.71, 0.73, 0.79)
        base_neck = -rad(10.0) if menace else 0.0
        rot = {
            "neck": (base_neck + rad(3.0) * math.sin(w + 0.3), 0.0, rad(9.0) * math.sin(w)),
            "head": (rad(2.0) * math.sin(2 * w), rad(2.5) * math.sin(w + 1.0), rad(5.0) * math.sin(w - 0.4)),
            "spine": (rad(0.6) * math.sin(2 * w), 0.0, 0.0),
            "ear_l": (-rad(28.0) * flick + (rad(6.0) if menace else 0.0), 0.0, 0.0),
            "ear_r": (-rad(24.0) * flick2 + (rad(6.0) if menace else 0.0), 0.0, 0.0),
        }
        for k, tb in enumerate(rig.tail_bones):
            rot[tb] = ((-rad(4.0) if menace else 0.0), 0.0, rad(5.0) * math.sin(w - 0.8 * k))
        if rig.has_jaw:
            rot["jaw"] = (-rad(2.0) * (0.5 + 0.5 * math.sin(2 * w)), 0.0, 0.0)
        offset = Vector((0.006 * rig.L * math.sin(w), 0.0, -0.004 * rig.H * math.sin(2 * w)))
        poses.append({"body": (offset, Euler((0.0, rad(0.8) * math.sin(w), 0.0), "XYZ")),
                      "feet": _standing_feet(rig), "rot": rot,
                      "scale": {"ribs": Vector((breath, breath, 1.0 + (breath - 1.0) * 0.3))}})
    key_clip(rig, "idle", poses)
    return T


def _snout_low(rig, neck_share=0.65):
    """Neck + head bend (radians) that puts the muzzle on the ground."""
    target = 0.05 * rig.H
    best, best_err = 0.0, 1e9
    for k in range(0, 121):
        a = rad(k)
        L = rig.solve({"feet": _standing_feet(rig), "body": (Vector(), Euler((-rad(4.0), 0, 0)))
                       , "rot": {"neck": (-a * neck_share, 0, 0), "head": (-a * (1 - neck_share), 0, 0)}})
        M = _pose_matrices(rig, L)
        tip = M["muzzle"] @ Vector((0, rig.length["muzzle"], 0))
        err = abs(tip.z - target)
        if err < best_err:
            best, best_err = a, err
    return best


def _pose_matrices(rig, L):
    M = {}
    for name in rig.order:
        p = rig.parent[name]
        base = (M[p] @ rig.rest[p].inverted() @ rig.rest[name]) if p else rig.rest[name]
        M[name] = base @ L[name]
    return M


def graze_clip(rig):
    """Head down at the ground (deer graze, hares nibble, wolves feed or hold a kill)."""
    T = 4.0 * rig.ts
    n = int(round(T * FPS))
    a = _snout_low(rig)
    poses = []
    for i in range(n + 1):
        t = i / n
        w = 2.0 * math.pi * t
        chew = math.sin(w * 6.0)
        look = pulse(t, 0.45, 0.55, 0.7)
        breath = 1.0 + 0.018 * math.sin(2 * w)
        rot = {
            "neck": (-a * 0.65 + rad(14.0) * look + rad(1.0) * chew, 0.0, rad(3.0) * math.sin(w)),
            "head": (-a * 0.35 + rad(4.0) * look, 0.0, rad(4.0) * math.sin(w + 0.6)),
            "ear_l": (rad(10.0) * look - rad(15.0) * pulse(t, 0.2, 0.22, 0.27), 0.0, 0.0),
            "ear_r": (rad(10.0) * look, 0.0, 0.0),
            "muzzle": (rad(2.0) * chew, 0.0, 0.0),
        }
        if rig.has_jaw:
            rot["jaw"] = (-rad(6.0) * (0.5 + 0.5 * chew), 0.0, 0.0)
        for k, tb in enumerate(rig.tail_bones):
            rot[tb] = (0.0, 0.0, rad(8.0) * math.sin(2 * w - 0.8 * k))
        shift = {leg: Vector((0, 0.04 * rig.L if leg.startswith("f") else 0.0, 0)) for leg in LEGS}
        poses.append({"body": (Vector((0, 0, -0.02 * rig.H)), Euler((-rad(4.0), 0.0, 0.0), "XYZ")),
                      "feet": _standing_feet(rig, shift), "rot": rot,
                      "scale": {"ribs": Vector((breath, breath, 1.0 + (breath - 1.0) * 0.3))}})
    key_clip(rig, "graze", poses)
    return T


# ------------------------------------------------------------------ hit and death

def hit_clip(rig, name, k):
    """An arrow strikes side k (-1 left, +1 right). The body jolts away from the
    blow and curls round the wound, the head whips to it, the near hind leg
    skips, the ears pin back. No step toward the shooter."""
    T = 0.8 * rig.ts
    n = int(round(T * FPS))
    H, L, W = rig.H, rig.L, rig.W
    poses = []
    for i in range(n + 1):
        t = (i / n) * 0.8  # normalised to wolf seconds
        hit = pulse(t, 0.0, 0.07, 0.75)
        curl = pulse(t, 0.02, 0.16, 0.78)
        skip = pulse(t, 0.03, 0.16, 0.4)
        near_hind = "hl_l" if k < 0 else "hl_r"
        shift = {near_hind: Vector((-k * 0.03 * W, 0.05 * L * smooth(seg(t, 0.1, 0.35)), 0.0))}
        feet = _standing_feet(rig, shift)
        target, _ = feet[near_hind]
        feet[near_hind] = (_toe_on_ground(rig, near_hind, target + Vector((0, 0, 0.09 * H * skip)), -rad(30.0) * skip),
                           -rad(30.0) * skip)
        off = Vector((-k * 0.05 * L * hit, -0.02 * L * hit, -0.035 * H * hit))
        rot = {
            "spine": (rad(3.0) * curl, 0.0, -k * rad(9.0) * curl),
            "chest": (0.0, 0.0, -k * rad(6.0) * curl),
            "hips": (0.0, 0.0, k * rad(8.0) * curl),
            "neck": (-rad(8.0) * curl + rad(14.0) * hit, 0.0, -k * rad(32.0) * curl),
            "head": (-rad(6.0) * curl, -k * rad(10.0) * curl, -k * rad(12.0) * curl),
            "ear_l": (-rad(55.0) * curl, 0.0, 0.0),
            "ear_r": (-rad(55.0) * curl, 0.0, 0.0),
        }
        if rig.has_jaw:
            rot["jaw"] = (-rad(22.0) * pulse(t, 0.02, 0.12, 0.6), 0.0, 0.0)
        for j, tb in enumerate(rig.tail_bones):
            rot[tb] = (-rad(14.0) * curl, 0.0, k * rad(10.0) * curl)
        poses.append({"body": (off, Euler((rad(1.5) * hit, -k * rad(7.0) * hit, 0.0), "XYZ")),
                      "feet": feet, "rot": rot})
    key_clip(rig, name, poses)
    return T


def _lying_feet(rig, s, roll_max, lying_drop):
    """Where each paw lies once the body is down on flank s: its standing spot
    carried round with the fallen body, then laid on the ground (the top pair
    resting on the bottom pair)."""
    r, L = rig.r_body, rig.L
    head = rig.rest["body"].translation
    off = Vector((s * 0.7 * r, -0.04 * L, -0.06 * rig.H - lying_drop))
    R = Euler((-rad(2.0), s * roll_max, 0.0), "XYZ").to_matrix().to_4x4()
    M = Matrix.Translation(off) @ Matrix.Translation(head) @ R @ Matrix.Translation(-head)
    out = {}
    for leg in LEGS:
        top = (leg.endswith("_l") and s > 0) or (leg.endswith("_r") and s < 0)
        p = M @ rig.foot[leg]
        front = leg.startswith("f")
        p.y += (0.10 if front else -0.06) * L + (0.06 * L if top else 0.0)
        p.x -= s * 0.1 * r
        p.z = rig.foot[leg].z + (2.5 * rig.spec["leg"] if top else 0.0)
        out[leg] = p
    return out


def death_clip(rig, name, s, breaths=2):
    """Falls onto flank s (-1 left, +1 right) and dies. Times are in wolf
    seconds and stretch with size. The body staggers away from the blow, the
    front legs buckle and the chest drops, the hindquarters go and it rolls
    onto its side under its own weight, the head lands after the body, then
    `breaths` slow, failing breaths (with a hind-leg twitch) before stillness."""
    ts = rig.ts
    H, L, W, r = rig.H, rig.L, rig.W, rig.r_body
    t_imp, t_stag, t_buck, t_roll, t_land = 0.15, 0.85, 1.3, 1.9, 1.9
    t_breath0 = 2.6
    breath_len = [0.9 + 0.2 * b for b in range(breaths)]
    t_end = t_breath0 + sum(breath_len) + 0.9
    n = int(round(t_end * ts * FPS))
    lying_drop = rig.mid.z - r * 1.05
    hip_arm = rig.length["hips"]
    chest_y = rig.rest["chest"].to_translation().y
    hip_y = rig.mid.y - rig.length["hips"]
    front_angle = math.atan2(rig.rest["chest"].to_translation().z - r - 0.14 * H, chest_y - hip_y)
    roll_max = rad(84.0)
    poses = []
    ground_frame = int(round(t_land * ts * FPS))
    lying_feet = _lying_feet(rig, s, roll_max, lying_drop)
    for i in range(n + 1):
        t = i / (ts * FPS)
        # Breath index and phase after the fall.
        b_amp, b_phase, twitch = 0.0, 0.0, 0.0
        tb = t_breath0
        for b, bl in enumerate(breath_len):
            if tb <= t < tb + bl:
                b_phase = (t - tb) / bl
                b_amp = 0.07 * (1.0 - b / max(breaths, 1)) + 0.02
                if b == min(1, breaths - 1):
                    twitch = pulse(b_phase, 0.55, 0.62, 0.85)
            tb += bl
        inhale = math.sin(math.pi * b_phase) ** 2 if b_amp else 0.0
        jolt = pulse(t, 0.0, 0.06, 0.45)
        sag = smooth(seg(t, t_imp, t_stag))
        buck = ease_in(seg(t, t_stag, t_buck))
        fall = ease_in(seg(t, t_buck, t_roll))
        bounce = ring(t, t_land, 1.0, 2.6, 7.0)
        # Body: jolt away from the blow, sag, nose-down as the front goes, then
        # the roll onto the flank, overshoot and settle.
        # The front goes first: the body pitches nose-down about the hips (still
        # standing) until the chest is near the ground, then the rear drops.
        front = front_angle * buck * (1.0 - fall)
        off = Vector((
            s * (0.05 * L * jolt + 0.06 * W * sag + 0.7 * r * fall),
            -0.03 * L * jolt - 0.04 * L * buck,
            -0.06 * H * sag - hip_arm * math.sin(front) - lying_drop * fall + 0.01 * H * inhale,
        ))
        pitch = -front - rad(2.0) * fall + rad(1.5) * jolt
        roll = s * (rad(5.0) * sag * (1.0 - fall) + roll_max * fall + rad(6.0) * bounce
                    + rad(1.2) * inhale - rad(2.0) * twitch)
        yaw = s * rad(6.0) * sag
        body = (off, Euler((pitch, roll, yaw), "XYZ"))
        # Head: thrown up and away by the blow, droops in the stagger, drops
        # with the chest, lands a beat after the body and bounces once.
        head_lag = ring(t, t_land + 0.12, 1.0, 3.0, 8.0)
        lie = smooth(seg(t, t_buck, t_roll + 0.15))
        neck_p = (rad(26.0) * jolt - rad(22.0) * sag * (1.0 - buck) + rad(12.0) * buck * (1.0 - lie)
                  + rad(4.0) * lie - rad(9.0) * head_lag + rad(2.0) * inhale)
        neck_y = -s * (rad(18.0) * jolt + rad(10.0) * sag * (1.0 - lie)) - s * rad(9.0) * lie
        head_p = rad(14.0) * jolt - rad(10.0) * sag * (1.0 - lie) + rad(6.0) * lie - rad(5.0) * head_lag
        rot = {
            "neck": (neck_p, 0.0, neck_y),
            "head": (head_p, s * rad(10.0) * lie, -s * rad(8.0) * jolt - s * rad(10.0) * lie),
            "spine": (rad(4.0) * inhale - rad(3.0) * buck * (1 - fall), 0.0, s * rad(5.0) * sag * (1 - lie)),
            "hips": (-rad(6.0) * sag * (1 - lie), 0.0, -s * rad(6.0) * lie),
            "ear_l": (-rad(55.0) * jolt - rad(30.0) * sag, 0.0, 0.0),
            "ear_r": (-rad(55.0) * jolt - rad(30.0) * sag, 0.0, 0.0),
        }
        if rig.has_jaw:
            gasp = pulse(t, 0.0, 0.1, 0.6)
            rot["jaw"] = (-rad(20.0) * gasp - rad(10.0) * lie - rad(8.0) * inhale, 0.0, 0.0)
        n_tail = max(len(rig.tail_bones), 1)
        for j, tb_name in enumerate(rig.tail_bones):
            lag = ring(t, t_land + 0.05 * j, 1.0, 2.2, 6.0)
            rot[tb_name] = (-rad(18.0) * sag * (1 - lie) / n_tail - rad(6.0) * lag, 0.0,
                            s * rad(26.0) * lie / n_tail)
        # Legs: planted through the stagger (the near-side front foot steps out
        # to catch the weight and the other crosses after it, a hind foot slips),
        # then folded under as the front buckles, then limp on the ground.
        step1 = smooth(seg(t, 0.25, 0.55))
        step2 = smooth(seg(t, 0.45, 0.78))
        near_f = "fl_r" if s > 0 else "fl_l"
        far_f = "fl_l" if s > 0 else "fl_r"
        shift = {
            near_f: Vector((s * 0.35 * W * step1, 0.04 * L * step1, 0)),
            far_f: Vector((s * 0.25 * W * step2, 0.02 * L * step2, 0)),
            ("hl_l" if s > 0 else "hl_r"): Vector((0, -0.08 * L * smooth(seg(t, 0.6, 0.95)), 0)),
        }
        # As the chest goes down the front paws skid forward and splay.
        for leg in (near_f, far_f):
            shift[leg] = shift[leg] + Vector((s * 0.1 * W * buck, 0.14 * L * buck, 0))
        feet = _standing_feet(rig, shift)
        for leg, k0, k1 in ((near_f, 0.25, 0.55), (far_f, 0.45, 0.78)):
            lift = math.sin(math.pi * seg(t, k0, k1)) * 0.07 * H
            tgt, _ = feet[leg]
            pp = -rad(40.0) * math.sin(math.pi * seg(t, k0, k1))
            feet[leg] = (_toe_on_ground(rig, leg, tgt + Vector((0, 0, lift)), pp), pp)
        # Then the roll: the paws skid out along the ground on the belly side
        # as the body goes over (the bottom pair stays down, the top pair flops
        # over onto them), and that is where they lie. IK all the way, so no
        # paw ever goes through the ground.
        over = smooth(seg(t, t_buck + 0.05, t_roll + 0.1))
        for leg in LEGS:
            top = (leg.endswith("_l") and s > 0) or (leg.endswith("_r") and s < 0)
            tgt, pp = feet[leg]
            lie_at = lying_feet[leg]
            if not leg.startswith("f") and top:
                # The death twitch: the top hind leg kicks back once.
                lie_at = lie_at + Vector((0, -0.12 * L * twitch, 0.05 * H * twitch))
            pos = tgt.lerp(lie_at, over)
            if top:
                pos = pos + Vector((0, 0, 0.12 * H * math.sin(math.pi * over)))
            feet[leg] = (pos, pp * (1.0 - over) - rad(30.0) * over)
        ik = {leg: 1.0 for leg in LEGS}
        limp = {}
        breath = 1.0 + b_amp * inhale
        poses.append({"body": body, "feet": feet, "ik": ik, "limp": limp, "rot": rot,
                      "scale": {"ribs": Vector((breath, breath, 1.0 + (breath - 1.0) * 0.3))}})
    key_clip(rig, name, poses, ground=ground_frame)
    return n / FPS


# ------------------------------------------------------------------ the whole set

def animate(name, mesh, arm, g, spec, style="walk", menace=False, stalk=False, death_breaths=2):
    """Skins `mesh` (already weighted) to `arm`, authors every clip and writes
    the gait speeds file. Export the armature with the mesh."""
    bpy.context.scene.render.fps = FPS
    rig = Rig(arm, spec, g)
    rig.mesh = mesh
    skin(mesh, arm)
    table = HOP if style == "hop" else GAITS
    rows = [("idle", 0.0, idle_clip(rig, menace), 1)]
    for gait in ("walk", "trot", "gallop"):
        v, T = gait_clip(rig, gait, table[gait], style)
        rows.append((gait, v, T, 1))
    if stalk:
        v, T = gait_clip(rig, "stalk", GAITS["stalk"], "walk")
        rows.append(("stalk", v, T, 1))
    rows.append(("graze", None, graze_clip(rig), 1))
    for clip, k in (("hit_l", -1), ("hit_r", 1)):
        rows.append((clip, None, hit_clip(rig, clip, k), 0))
    for clip, s in (("death_l", -1), ("death_r", 1)):
        rows.append((clip, None, death_clip(rig, clip, s, death_breaths), 0))
    # Rest pose at export.
    for pb in arm.pose.bones:
        pb.rotation_quaternion = Quaternion()
        pb.location = Vector()
        pb.scale = Vector((1, 1, 1))
    write_speeds(name, rows)
    return arm


SPEEDS_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "data", "animation", "creatures")


def write_speeds(name, rows):
    os.makedirs(SPEEDS_DIR, exist_ok=True)
    path = os.path.abspath(os.path.join(SPEEDS_DIR, f"{name}_gaits.txt"))
    with open(path, "w") as f:
        f.write(f"# {name} clips (creatures/models/{name}.gltf), 30 fps. Written by tools/blender/creature_rig.py.\n")
        f.write("# name native_speed_mps duration_s loop(0/1)   ('-' = not a locomotion clip)\n")
        for clip, v, T, loop in rows:
            speed = "-" if v is None else f"{v:.3f}"
            f.write(f"{clip} {speed} {T:.3f} {loop}\n")
    print(f"{name}: gaits -> {path}")
