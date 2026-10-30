"""Feyre's core locomotion clips, keyed procedurally onto the humanoid rig.

Used by build_feyre.py:
    import feyre_anims
    names = feyre_anims.add_actions(arm_obj)
    ... export_scene.gltf(..., export_animations=True, export_animation_mode="ACTIONS")

Actions (30 fps, every frame keyed, no root motion; Root stays at rest):
    idle        150 f  loop   braced, coiled stance; two breaths and a slow weight shift
    idle_look   150 f  loop   idle plus a watchful glance left, then right (eyes lead the head)
    walk         15 f  loop   3.2 m/s brisk stride
    run          15 f  loop   5.5 m/s
    sprint       13 f  loop   8.0 m/s
    turn_left    18 f  once   in-place 90 degree step turn (the game rotates the body)
    turn_right   18 f  once

Rotations are authored as deltas about *armature* axes (X her left, -Y forward, Z up)
applied at each bone as if its parent were at rest; `delta_to_basis` turns them into
local pose quaternions (bone rolls are 0, so local axes differ per bone).  Legs are
solved with a two-bone IK onto planted foot targets: in stance the foot's ground point
slides back at exactly the game speed, and heel strike / toe off roll about the heel /
ball, so the contact never skates.  Right-side deltas are mirrored from the left.
"""

import math
from dataclasses import dataclass, field

import bpy
from mathutils import Matrix, Quaternion, Vector

FPS = 30
SIDES = (("Left", 1.0), ("Right", -1.0))
FINGERS = ("Index", "Middle", "Ring", "Little")
SEGS = ("Proximal", "Intermediate", "Distal")
HEEL_BACK = 0.040      # heel contact behind the ankle (m), sole at z = 0
MAX_STRETCH = 0.985    # max hip-ankle distance / leg length before the hips are lowered
LOOPS = ("idle", "idle_look", "walk", "run", "sprint")


# --------------------------------------------------------------------------
# Small maths helpers
# --------------------------------------------------------------------------
def qx(deg: float) -> Quaternion:
    return Quaternion((1.0, 0.0, 0.0), math.radians(deg))


def qy(deg: float) -> Quaternion:
    return Quaternion((0.0, 1.0, 0.0), math.radians(deg))


def qz(deg: float) -> Quaternion:
    return Quaternion((0.0, 0.0, 1.0), math.radians(deg))


def mirror(q: Quaternion) -> Quaternion:
    """Reflect an armature-space rotation across the YZ plane (left <-> right)."""
    return Quaternion((q.w, q.x, -q.y, -q.z))


def smooth(e0: float, e1: float, x: float) -> float:
    t = min(max((x - e0) / (e1 - e0), 0.0), 1.0)
    return t * t * (3.0 - 2.0 * t)


def env(t: float, a: float, m: float, b: float) -> float:
    """0 -> 1 -> 0 envelope: eases up over [a, m], down over [m, b]."""
    return smooth(a, m, t) * (1.0 - smooth(m, b, t))


def wave(phase: float, lag: float = 0.0) -> float:
    return math.cos(2.0 * math.pi * (phase - lag))


# --------------------------------------------------------------------------
# Pose description for one frame
# --------------------------------------------------------------------------
@dataclass
class FootTarget:
    pos: Vector          # flat-foot offset from the rest ankle (armature space)
    pitch: float = 0.0   # deg; + toes up (rolls about the heel), - heel up (about the ball)
    toe: float = 0.0     # deg; extra toe bend upward relative to the foot


@dataclass
class Frame:
    rot: dict = field(default_factory=dict)    # bone -> armature-axis delta Quaternion
    hips: Vector = field(default_factory=Vector)
    feet: dict = field(default_factory=dict)   # "Left"/"Right" -> FootTarget

    def add(self, bone: str, q: Quaternion, side: float = 1.0) -> None:
        """Pre-multiply a delta on a bone; side -1 mirrors a left-side delta."""
        q = q if side > 0 else mirror(q)
        self.rot[bone] = q @ self.rot.get(bone, Quaternion())


# --------------------------------------------------------------------------
# Rig: rest data, forward kinematics, leg IK
# --------------------------------------------------------------------------
class Rig:
    def __init__(self, arm_obj: bpy.types.Object) -> None:
        self.obj = arm_obj
        bones = arm_obj.data.bones
        self.rest = {b.name: b.matrix_local.copy() for b in bones}
        self.rest3 = {n: m.to_3x3() for n, m in self.rest.items()}
        self.parent = {b.name: (b.parent.name if b.parent else None) for b in bones}
        self.names = [b.name for b in bones]
        self.leg = {}
        for side, _ in SIDES:
            hip = bones[side + "UpperLeg"].head_local
            knee = bones[side + "LowerLeg"].head_local
            ankle = bones[side + "Foot"].head_local
            ball = bones[side + "Toes"].head_local
            self.leg[side] = dict(
                l1=(knee - hip).length, l2=(ankle - knee).length, ankle=ankle.copy(),
                heel=Vector((ankle.x, ankle.y + HEEL_BACK, 0.0)), ball=Vector((ball.x, ball.y, 0.0)))
        self.stats = {"hip_drops": 0, "max_stretch": 0.0}

    def delta_to_basis(self, name: str, q: Quaternion) -> Quaternion:
        r = self.rest3[name]
        return (r.transposed() @ q.to_matrix() @ r).to_quaternion()

    def child_rest(self, name: str, parent_pose: Matrix) -> Matrix:
        """Pose matrix of `name` with an identity basis under a posed parent."""
        p = self.parent[name]
        return parent_pose @ self.rest[p].inverted() @ self.rest[name]

    def hips_pose(self, fr: Frame) -> Matrix:
        q = fr.rot.get("Hips", Quaternion())
        r = self.rest["Hips"]
        return Matrix.Translation(fr.hips) @ Matrix.Translation(r.translation) \
            @ (q.to_matrix() @ r.to_3x3()).to_4x4()

    def foot_pose(self, side: str, ft: FootTarget) -> tuple[Vector, Matrix]:
        """Ankle position and the foot's armature-space roll matrix."""
        lg = self.leg[side]
        roll = qx(-ft.pitch).to_matrix()
        pivot = (lg["heel"] if ft.pitch >= 0.0 else lg["ball"]) + ft.pos
        ankle = pivot + roll @ (lg["ankle"] + ft.pos - pivot)
        return ankle, roll

    def hip_drop(self, fr: Frame) -> float:
        """How far the hips must sink so no leg overstretches this frame."""
        h0 = self.hips_pose(fr)
        need = 0.0
        for side, s in SIDES:
            lg = self.leg[side]
            hip = (self.child_rest(side + "UpperLeg", h0)).translation
            ankle, _ = self.foot_pose(side, fr.feet[side])
            reach = MAX_STRETCH * (lg["l1"] + lg["l2"])
            d = ankle - hip
            horiz2 = d.x * d.x + d.y * d.y
            if d.length > reach and horiz2 < reach * reach:
                need = max(need, -d.z - math.sqrt(reach * reach - horiz2))
        return need

    @staticmethod
    def frame_from(y: Vector, x: Vector) -> Matrix:
        y = y.normalized()
        z = x.cross(y).normalized()
        return Matrix((y.cross(z), y, z)).transposed()

    def solve_leg(self, side: str, s: float, hips: Matrix, ft: FootTarget, out: dict) -> None:
        lg = self.leg[side]
        up_m = self.child_rest(side + "UpperLeg", hips)
        hip = up_m.translation
        ankle, roll = self.foot_pose(side, ft)
        d_vec = ankle - hip
        reach = lg["l1"] + lg["l2"]
        self.stats["max_stretch"] = max(self.stats["max_stretch"], d_vec.length / reach)
        d = min(d_vec.length, reach * 0.9995)
        dirn = d_vec.normalized()
        a = (lg["l1"] ** 2 - lg["l2"] ** 2 + d * d) / (2.0 * d)
        h = math.sqrt(max(lg["l1"] ** 2 - a * a, 0.0))
        pole = Vector((0.12 * s, -1.0, 0.0))            # knees forward, a touch outward
        pole = (pole - dirn * pole.dot(dirn)).normalized()
        knee = hip + dirn * a + pole * h
        hinge = pole.cross(dirn).normalized()
        rx = Vector((1.0, 0.0, 0.0))
        want = {}
        for name, y_new in ((side + "UpperLeg", knee - hip), (side + "LowerLeg", hip + dirn * d - knee)):
            r = self.rest3[name]
            want[name] = self.frame_from(y_new, hinge) @ self.frame_from(r.col[1], rx).transposed() @ r
        want[side + "Foot"] = roll @ self.rest3[side + "Foot"]
        want[side + "Toes"] = qx(-(ft.pitch + ft.toe)).to_matrix() @ self.rest3[side + "Toes"]
        parent = hips
        for name, rot in want.items():
            m0 = self.child_rest(name, parent)
            out[name] = (m0.to_3x3().inverted() @ rot).to_quaternion()
            parent = Matrix.Translation(m0.translation) @ rot.to_4x4()

    def bake(self, fr: Frame) -> tuple[dict, Vector]:
        """Frame -> (bone -> local basis quaternion, Hips location)."""
        drop = self.hip_drop(fr)
        if drop > 1e-5:
            self.stats["hip_drops"] += 1
            fr.hips = fr.hips - Vector((0.0, 0.0, drop))
        out = {n: Quaternion() for n in self.names}
        for name, q in fr.rot.items():
            out[name] = self.delta_to_basis(name, q)
        hips = self.hips_pose(fr)
        for side, s in SIDES:
            self.solve_leg(side, s, hips, fr.feet[side], out)
        loc = self.rest3["Hips"].transposed() @ fr.hips
        return out, loc


# --------------------------------------------------------------------------
# Upper body layers
# --------------------------------------------------------------------------
def relaxed_arms(fr: Frame, swing: tuple[float, float], elbow: tuple[float, float],
                 lower: float = 72.0, curl: float = 1.0, out: float = 0.0) -> None:
    """Arms down from the T-pose; swing deg (+ = forward), elbow flex deg per side."""
    for i, (side, s) in enumerate(SIDES):
        fr.add(side + "Shoulder", qy(5.0) @ qz(-3.0), s)
        fr.add(side + "UpperArm", qx(-swing[i]) @ qy(lower - 5.0 - out) @ qz(-8.0), s)
        fr.add(side + "LowerArm", qz(-elbow[i]) @ qx(15.0), s)        # pronate (palms back), then flex
        fr.add(side + "Hand", qz(-6.0) @ qy(10.0 * curl), s)
        for k, f in enumerate(FINGERS):
            for j, seg in enumerate(SEGS):
                fr.add(side + f + seg, qy(curl * (14.0 + 6.0 * k) * (1.0 - 0.2 * j)), s)
        fr.add(side + "ThumbMetacarpal", qx(-10.0 * curl) @ qz(-8.0 * curl), s)
        fr.add(side + "ThumbProximal", qy(12.0 * curl), s)
        fr.add(side + "ThumbDistal", qy(14.0 * curl), s)


def spine(fr: Frame, lean: float, yaw: float, roll: float = 0.0, breath: float = 0.0) -> None:
    """Lean forward (deg) over three bones; chest counter-yaws against the pelvis."""
    fr.add("Spine", qx(lean * 0.35) @ qz(yaw * 0.4) @ qy(roll * 0.5))
    fr.add("Chest", qx(lean * 0.35 - breath * 1.2) @ qz(yaw * 0.6) @ qy(roll * 0.3))
    fr.add("UpperChest", qx(lean * 0.3 - breath * 1.8) @ qz(yaw * 0.4))
    for side, s in SIDES:
        fr.add(side + "Shoulder", qy(-breath * 1.5), s)


def head(fr: Frame, pitch: float, yaw: float, tilt: float = 0.0) -> None:
    fr.add("Neck", qx(pitch * 0.4) @ qz(yaw * 0.35) @ qy(tilt * 0.4))
    fr.add("Head", qx(pitch * 0.6) @ qz(yaw * 0.65) @ qy(tilt * 0.6))


def braid(fr: Frame, trail: float, swing: list[float], side: list[float]) -> None:
    """Hair chain: trail (deg back) plus per-segment lagged swing/side values."""
    for i in range(4):
        w = 0.4 + 0.2 * i
        fr.add("Braid_%d" % (i + 1), qx(trail * (0.5 if i == 0 else 0.25) + swing[i] * w) @ qy(side[i] * w))


# --------------------------------------------------------------------------
# Idle family
# --------------------------------------------------------------------------
IDLE_FRAMES = 150
STANCE = {"Left": Vector((0.022, -0.035, 0.0)), "Right": Vector((-0.018, 0.045, 0.0))}


def idle_frame(phase: float, look: float = 0.0, look_tilt: float = 0.0, still: float = 0.0) -> Frame:
    """Braced, coiled stance. look = head/eye yaw (deg, + left); still damps breathing."""
    fr = Frame()
    breath = math.sin(2.0 * math.pi * 2.0 * phase) * (1.0 - 0.75 * still)  # two breaths per loop
    shift = math.sin(2.0 * math.pi * phase)                                   # one weight shift
    fr.hips = Vector((0.018 * shift, 0.012, -0.035 + 0.004 * breath))
    fr.add("Hips", qz(-6.0 + 1.5 * shift) @ qy(-2.5 * shift) @ qx(2.0))
    for side, _ in SIDES:
        fr.feet[side] = FootTarget(STANCE[side].copy())
    spine(fr, lean=4.0, yaw=5.0 - 1.0 * shift + look * 0.2, roll=2.0 * shift, breath=breath)
    head(fr, pitch=3.0 - 0.8 * breath, yaw=1.0 + look * 0.75, tilt=-1.0 * shift + look_tilt)
    for side, s in SIDES:
        fr.add(side + "Eye", qz(look * 0.4), 1.0)
    sw = 2.0 * shift
    relaxed_arms(fr, swing=(4.0 + sw, 6.0 - sw), elbow=(20.0 + 1.5 * breath, 24.0 + 1.5 * breath))
    lag = [math.sin(2.0 * math.pi * (phase - 0.04 * (i + 1))) for i in range(4)]
    braid(fr, 4.0, [0.6 * breath] * 4, [-3.0 * v for v in lag])
    return fr


def look_curve(t: float) -> tuple[float, float, float]:
    """idle_look: (yaw deg, tilt deg, stillness 0..1) at loop time t in [0, 1)."""
    left = env(t, 0.10, 0.17, 0.44)
    right = env(t, 0.48, 0.56, 0.84)
    settle = env(t, 0.84, 0.88, 0.96)
    yaw = 38.0 * left - 34.0 * right + 4.0 * settle
    return yaw, 4.0 * left - 3.0 * right, max(smooth(0.15, 0.22, t) * (1.0 - smooth(0.36, 0.44, t)), right)


def idle_look_frame(phase: float) -> Frame:
    yaw, tilt, still = look_curve(phase)
    eye_yaw, _, _ = look_curve((phase + 0.02) % 1.0)  # eyes lead the head by ~3 frames
    fr = idle_frame(phase, look=yaw, look_tilt=tilt, still=still)
    for side, _ in SIDES:
        fr.add(side + "Eye", qz((eye_yaw - yaw) * 0.8 + yaw * 0.1))
    return fr


def turn_frame(t: float, s: float) -> Frame:
    """In-place 90 degree step turn; s = +1 left, -1 right. Starts/ends at idle_frame(0)."""
    fr = idle_frame(0.0)
    lead, trail = ("Left", "Right") if s > 0 else ("Right", "Left")
    head_yaw = 30.0 * env(t, 0.0, 0.22, 0.78) - 5.0 * env(t, 0.70, 0.84, 1.0)
    chest_yaw = 14.0 * env(t, 0.05, 0.32, 0.85)
    fr.add("Hips", qz(s * 8.0 * env(t, 0.10, 0.40, 0.92)))
    fr.add("Spine", qz(s * chest_yaw * 0.4))
    fr.add("Chest", qz(s * chest_yaw * 0.6) @ qx(-3.0 * env(t, 0.0, 0.2, 0.5)))
    fr.add("Neck", qz(s * head_yaw * 0.35))
    fr.add("Head", qz(s * head_yaw * 0.65) @ qx(4.0 * env(t, 0.72, 0.85, 1.0)))
    for side, _ in SIDES:
        fr.add(side + "Eye", qz(s * 10.0 * env(t, 0.0, 0.12, 0.6)))
    # Weight onto the trailing foot, lead foot steps, then weight across and trail foot steps.
    fr.hips += Vector((-s * 0.030 * env(t, 0.0, 0.22, 0.48) + s * 0.028 * env(t, 0.35, 0.58, 0.88), 0.0,
                       -0.018 * env(t, 0.0, 0.12, 0.3) - 0.022 * env(t, 0.72, 0.84, 1.0)))
    for foot, a, m, b, out in ((lead, 0.10, 0.27, 0.46, 0.022), (trail, 0.46, 0.62, 0.80, 0.0)):
        e = env(t, a, m, b)
        land = smooth(m, b, t)
        ft = fr.feet[foot]
        sx = 1.0 if foot == "Left" else -1.0
        ft.pos += Vector((sx * out * land, -0.03 * e, 0.065 * e))
        ft.pitch -= 14.0 * env(t, a - 0.05, a + 0.06, m + 0.05)
        ft.toe += 14.0 * env(t, a - 0.05, a + 0.06, m + 0.05) * 0.6
    # Settle the lead foot's sideways step back by the end so the clip ends at idle.
    fr.feet[lead].pos.x -= (1.0 if lead == "Left" else -1.0) * 0.022 * smooth(0.80, 1.0, t)
    arm = 14.0 * env(t, 0.05, 0.35, 0.95)
    fr.add("LeftUpperArm", qx(arm * (1.0 if s < 0 else -0.6)))
    fr.add("RightUpperArm", qx(arm * (1.0 if s > 0 else -0.6)))
    lagged = [env(t, 0.08 + 0.05 * i, 0.38 + 0.05 * i, 0.9 + 0.025 * i) for i in range(4)]
    for i in range(4):
        fr.add("Braid_%d" % (i + 1), qz(-s * 9.0 * lagged[i]) @ qy(-s * 7.0 * lagged[i]))
    return fr


# --------------------------------------------------------------------------
# Locomotion
# --------------------------------------------------------------------------
@dataclass(frozen=True)
class Gait:
    name: str
    speed: float      # m/s, matches characters/feyre/feyre.gd
    frames: int       # cycle length (two steps)
    duty: float       # stance fraction of the cycle per foot
    centre: float     # stance centre, m behind the rest ankle
    width: float      # foot x
    lift: float       # swing ankle lift (m)
    release: float    # swing leaves the ground at this fraction of ground speed (no toe slip)
    strike: float     # heel-strike pitch (deg, toes up)
    push: float       # toe-off pitch (deg, heel up)
    crouch: float     # hips lowered (m)
    bob: float        # hips bob amplitude (m)
    flight: bool      # run-type bob (low at mid stance) vs walk-type (low at contact)
    sway: float       # hips sideways (m)
    yaw: float        # pelvis yaw (deg)
    roll: float       # pelvis roll (deg)
    lean: float       # forward lean (deg)
    arm: float        # arm swing (deg)
    elbow: float      # base elbow flex (deg)
    elbow_swing: float
    trail: float      # braid trailing angle (deg)
    curl: float       # finger curl scale

    @property
    def stride(self) -> float:
        return self.speed * self.frames / FPS

    @property
    def stance_travel(self) -> float:
        return self.stride * self.duty


GAITS = (
    Gait("walk", 3.2, 15, 0.52, 0.035, 0.085, 0.08, 1.0, 16.0, -32.0, 0.085, 0.018, False,
         0.020, 7.0, 4.0, 5.0, 18.0, 15.0, 10.0, 10.0, 1.0),
    Gait("run", 5.5, 15, 0.30, 0.060, 0.072, 0.20, 0.3, 7.0, -40.0, 0.095, 0.030, True,
         0.014, 9.0, 3.0, 11.0, 34.0, 76.0, 10.0, 26.0, 1.4),
    Gait("sprint", 8.0, 13, 0.24, 0.080, 0.066, 0.30, 0.3, 3.0, -45.0, 0.095, 0.032, True,
         0.010, 10.0, 2.5, 17.0, 50.0, 86.0, 8.0, 40.0, 1.8),
)


def gait_foot(g: Gait, u: float, x: float) -> FootTarget:
    """Foot target at local phase u (0 = this foot's strike)."""
    d = g.stance_travel
    y_strike, y_off = g.centre - d / 2.0, g.centre + d / 2.0
    if u < g.duty:
        s = u / g.duty
        pitch = g.strike * (1.0 - smooth(0.0, 0.3, s)) + g.push * smooth(0.45, 1.0, s) ** 1.5
        return FootTarget(Vector((x, y_strike + d * s, 0.0)), pitch, max(-pitch, 0.0))
    w = (u - g.duty) / (1.0 - g.duty)
    ground = d / g.duty * (1.0 - g.duty)      # ground speed in swing-phase units
    m0, m1 = ground * g.release, ground * (0.55 if g.flight else 0.35)  # m1: swing retraction
    h = (2 * w ** 3 - 3 * w ** 2 + 1, w ** 3 - 2 * w ** 2 + w, -2 * w ** 3 + 3 * w ** 2, w ** 3 - w ** 2)
    y = h[0] * y_off + h[1] * m0 + h[2] * y_strike + h[3] * m1
    z = g.lift * math.sin(math.pi * w) ** 1.2 * (1.0 - 0.35 * w)
    pitch = g.push + (g.strike - g.push) * smooth(0.0, 0.85, w) + 8.0 * math.sin(math.pi * w)
    toe = max(-g.push, 0.0) * (1.0 - smooth(0.0, 0.35, w))
    return FootTarget(Vector((x, y, z)), pitch, toe)


def gait_frame(g: Gait, phase: float) -> Frame:
    fr = Frame()
    mid = g.duty / 2.0                       # left mid-stance
    if g.flight:
        bob = -g.bob * math.cos(4.0 * math.pi * (phase - mid))
    else:
        bob = -g.bob * math.cos(4.0 * math.pi * phase)
    lat = wave(phase, mid)                    # +1 at left mid-stance
    fr.hips = Vector((g.sway * lat, 0.0, -g.crouch + bob))
    pel_yaw = -g.yaw * wave(phase)            # left hip forward at left strike
    fr.add("Hips", qz(pel_yaw) @ qy(-g.roll * lat) @ qx(g.lean * 0.25))
    for side, s in SIDES:
        off = 0.0 if s > 0 else 0.5
        fr.feet[side] = gait_foot(g, (phase - off) % 1.0, s * (g.width - 0.090))
    spine(fr, lean=g.lean * 0.75, yaw=-1.2 * pel_yaw, roll=g.roll * 0.6 * lat,
          breath=0.5 * math.sin(4.0 * math.pi * (phase - 0.1)))
    # Head stays level and forward; nod lags the bob a little (settle).
    head(fr, pitch=-g.lean * 0.75 + 2.0 * math.cos(4.0 * math.pi * (phase - mid - 0.12)) * (g.bob / 0.03),
         yaw=0.68 * pel_yaw, tilt=g.roll * 0.4 * wave(phase, mid + 0.08))
    arm_l = -g.arm * wave(phase, 0.04)        # left arm forward at right strike (phase 0.5)
    fwd = (arm_l, -arm_l)
    elbows = tuple(g.elbow + g.elbow_swing * max(a / g.arm, -0.4) for a in
                   (-g.arm * wave(phase, 0.09), g.arm * wave(phase, 0.09)))
    relaxed_arms(fr, swing=(fwd[0] + 4.0, fwd[1] + 4.0), elbow=elbows, curl=g.curl,
                 lower=72.0 if g.name == "walk" else 70.0, out=0.0 if g.name == "walk" else 2.0)
    swing = [-math.cos(4.0 * math.pi * (phase - mid - 0.07 * (i + 1))) * (g.bob / 0.03) * 4.0
             for i in range(4)]
    side = [-3.0 * g.sway / 0.015 * wave(phase, mid + 0.08 * (i + 1)) for i in range(4)]
    braid(fr, g.trail, swing, side)
    return fr


# --------------------------------------------------------------------------
# Keying
# --------------------------------------------------------------------------
def key_action(rig: Rig, name: str, frames: list[Frame], loop: bool) -> bpy.types.Action:
    obj = rig.obj
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    obj.animation_data_create()
    obj.animation_data.action = act
    baked = [rig.bake(fr) for fr in frames]
    if loop:
        baked.append(baked[0])
    prev: dict = {}
    pbones = obj.pose.bones
    moving = {n for n in rig.names
              if any(abs(b[0][n].dot(baked[0][0][n])) < 1.0 - 1e-9 for b in baked)}
    for f, (quats, loc) in enumerate(baked):
        for n in rig.names:
            if n not in moving and 0 < f < len(baked) - 1:
                continue
            q = quats[n].copy()
            if n in prev and prev[n].dot(q) < 0.0:
                q.negate()
            prev[n] = q
            pb = pbones[n]
            pb.rotation_mode = "QUATERNION"
            pb.rotation_quaternion = q
            pb.keyframe_insert("rotation_quaternion", frame=f, group=n)
        pbones["Hips"].location = loc
        pbones["Hips"].keyframe_insert("location", frame=f, group="Hips")
    act.frame_range = (0.0, float(len(baked) - 1))
    act.use_frame_range = True
    act.use_cyclic = loop
    for fc in _fcurves(act, obj):
        for kp in fc.keyframe_points:
            kp.interpolation = "LINEAR"
    return act


def _fcurves(act: bpy.types.Action, obj: bpy.types.Object) -> list:
    """F-curves of an action (Blender 4.4+ slotted actions, or legacy)."""
    if hasattr(act, "layers") and act.layers:
        slot = obj.animation_data.action_slot
        return [fc for layer in act.layers for strip in layer.strips
                for fc in strip.channelbag(slot).fcurves]
    return list(act.fcurves)


def reset_pose(obj: bpy.types.Object) -> None:
    for pb in obj.pose.bones:
        pb.rotation_mode = "QUATERNION"
        pb.rotation_quaternion = Quaternion()
        pb.location = Vector()
        pb.scale = Vector((1.0, 1.0, 1.0))


def add_actions(arm_obj: bpy.types.Object) -> list[str]:
    """Create Feyre's clips on `arm_obj`; returns the action names. Leaves the rig at rest."""
    scene = bpy.context.scene
    scene.render.fps, scene.render.fps_base = FPS, 1.0
    for n in ("idle", "idle_look", "turn_left", "turn_right") + tuple(g.name for g in GAITS):
        old = bpy.data.actions.get(n)
        if old is not None:
            bpy.data.actions.remove(old)
    rig = Rig(arm_obj)
    clips: list[tuple[str, list[Frame], bool]] = [
        ("idle", [idle_frame(f / IDLE_FRAMES) for f in range(IDLE_FRAMES)], True),
        ("idle_look", [idle_look_frame(f / IDLE_FRAMES) for f in range(IDLE_FRAMES)], True),
    ]
    for g in GAITS:
        clips.append((g.name, [gait_frame(g, f / g.frames) for f in range(g.frames)], True))
    turn_n = 18
    for name, s in (("turn_left", 1.0), ("turn_right", -1.0)):
        clips.append((name, [turn_frame(f / turn_n, s) for f in range(turn_n + 1)], False))
    names = []
    for name, frames, loop in clips:
        reset_pose(arm_obj)
        key_action(rig, name, frames, loop)
        names.append(name)
    arm_obj.animation_data.action = None
    reset_pose(arm_obj)
    scene.frame_set(0)
    add_actions.stats = dict(rig.stats)  # type: ignore[attr-defined]
    return names
