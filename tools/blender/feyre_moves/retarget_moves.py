"""Feyre's motion-capture move set, retargeted from CC0 Mesh2Motion clips onto her rig.

Reproducible build (cloud Blender module):
    /opt/bpyenv/bin/python -I tools/blender/feyre_moves/retarget_moves.py SOURCE_DIR OUT.glb \
        [--speeds data/animation/feyre_moves_speeds.txt]
    SOURCE_DIR  folder holding human-base-animations.glb and human-addon-animations.glb
    OUT.glb     normally characters/feyre/anim/feyre_moves.glb

Source: Mesh2Motion (github.com/scottpetrovic/mesh2motion-app), commit
eef2de986dab53283cb636f860d502d64b8073e7, static/animations/human-base-animations.glb
and human-addon-animations.glb, released under CC0 1.0 (LICENSE-CC0.MD in that repo).
See characters/feyre/anim/CREDITS.md.

Writes an animation-only glb: the Armature (same bone names as feyre.glb, declared as a
glTF skin so Godot builds Armature/Skeleton3D) plus one action per clip, no meshes.
Godot imports it as an AnimationLibrary.  Prints each clip's duration and, for the
locomotion loops, the native ground speed (mean backward speed of the stance foot) and
the worst per-step foot-slide residual at that speed; --speeds writes them to a file.

Clip mapping (source frames are on the 30 fps timeline; the CLIPS table is authoritative):
    idle          <- Idle_Subtle       1.25-77.5   76 f  loop
    walk          <- Walk_Female       1.25-41.25  28 f  loop  (x1.43: brisker cadence)
    run           <- Run_Female        1.25-25.0   24 f  loop
    sprint        <- Sprint            0-25.0      20 f  loop  (x1.25)
    jump_start    <- Jump_Start        1.25-8.25   crouch, push, takeoff (0.23 s)
    jump_rise     <- Jump_air          0-24        ping-pong loop, 1.6 s (airborne, knee up)
    jump_fall     <- Jump_air          24-48       ping-pong loop, 1.6 s (airborne, legs reaching down)
    jump_land     <- Jump_Land         1-12        impact and absorb (0.37 s)
    jump_double   <- Jump_2            3.25-17.25  tucked second jump, x1.27 (0.37 s)
    jump_flourish <- Jump_2            3.25-17.25  tucked pose under the game's procedural front flip (0.6 s)
    land_hero     <- Land_Three_Point  13.25-30.25 impact to three-point kneel (0.57 s)

Method.  Both rigs are T-posed, face -Y with Z up.  Each mapped bone takes the source
bone's armature-space rotation delta from its rest:  P_t = P_s @ R_s^-1 @ R_t, which keeps
Feyre's own rest shape (her clavicles run straight out, the mannequin's sweep back) and
transfers arm twist exactly.  Local quaternions follow from
M = M_parent @ (parent.matrix_local^-1 @ matrix_local) @ basis.
Hips translation = source pelvis offset from rest * K (K = 0.835 / 0.932, hip-joint
height ratio) with linear horizontal drift removed, so every clip plays in place (no root
motion; Root stays at rest).  "ground" clips then get a ground pass: per frame the hips
shift vertically so Feyre's lowest sole vertex sits at K * the mannequin's lowest sole
vertex (clamped at the floor: no floating, no sinking; knees, toes and hands are kept
above the floor too).  "air" clips keep the hips at rest
height (the game's jump arc supplies the height).  Gait loops also get a stance-foot lock:
while a foot is on the ground its contact patch is pinned to a treadmill moving at the
clip's native speed (two-bone leg IK, foot orientation unchanged), so with
speed_scale = game_speed / native_speed the planted foot does not skate; a smoothed
fore-aft hips surge absorbs most of the source's stance-speed wobble first (hips drop a
little where a locked leg would overstretch), and where her fuller thighs would make the
narrow-track run pass knee through knee the swing leg is abducted at the hip.
Posture pass (POSTURE): the performers hunch, so each gait clip's mean trunk lean is
rotated upright to a target (spread over Spine/Chest/UpperChest, frame-to-frame motion
kept), the head is levelled, clavicles go back and down, arms are abducted a little so
the swing stays at her sides, and the pelvis rolls toward the swing leg (hip sway).
Jaw, eyes, braid and Root stay at rest.  30 fps, every frame keyed, quaternions; loops end
on a copy of their first frame.
"""

import json
import math
import os
import struct
import sys

import bpy
import numpy as np
from mathutils import Matrix, Quaternion, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
TARGET_GLB = os.path.join(REPO, "characters", "feyre", "model", "feyre.glb")
SOURCE_FILES = {"base": "human-base-animations.glb", "addon": "human-addon-animations.glb"}

FPS = 30
K = 0.835 / 0.932          # Feyre hip-joint height / mannequin hip-joint height
SOLE_Z = 0.012             # rest vertices this close to the floor count as sole points
CONTACT_Z = 0.015          # a foot whose lowest sole point is below this is planted
LOCK_EASE = 3              # frames over which the foot lock fades in/out around a stance
SURGE_SIGMA = 1.5          # smoothing (frames) of the hips fore-aft surge in gait loops
LEG_GAP = 0.12             # min distance (m) between swing knee/shin and the other leg's axis
SIDES = (("l", "Left"), ("r", "Right"))

# name, source file, source action, t0, t1, output frames, playback, placement
#   playback: "loop" (frames span t0..t1, then a copy of frame 0), "once" (t0..t1 inclusive),
#             "pingpong" (t0 -> t1 -> t0, loop)
#   placement: "gait" (ground pass + stance-foot lock), "ground", "air"
CLIPS = (
    ("idle", "addon", "Idle_Subtle", 1.25, 77.5, 76, "loop", "gait"),
    ("walk", "addon", "Walk_Female", 1.25, 41.25, 28, "loop", "gait"),
    ("run", "addon", "Run_Female", 1.25, 25.0, 24, "loop", "gait"),
    ("sprint", "base", "Sprint", 0.0, 25.0, 20, "loop", "gait"),
    ("jump_start", "base", "Jump_Start", 1.25, 8.25, 8, "once", "ground"),
    ("jump_rise", "base", "Jump_air", 0.0, 24.0, 48, "pingpong", "air"),
    ("jump_fall", "base", "Jump_air", 24.0, 48.0, 48, "pingpong", "air"),
    ("jump_land", "base", "Jump_Land", 1.0, 12.0, 12, "once", "ground"),
    ("jump_double", "addon", "Jump_2", 3.25, 17.25, 12, "once", "air"),
    ("jump_flourish", "addon", "Jump_2", 3.25, 17.25, 18, "once", "air"),
    ("land_hero", "addon", "Land_Three_Point", 13.25, 30.25, 18, "once", "ground"),
)
LOCOMOTION = tuple(c[0] for c in CLIPS if c[7] == "gait")

# Posture pass (degrees): the mocap performers hunch, Feyre is a lean, confident
# huntress.  lean = target forward trunk lean (hips -> neck, from vertical; the clip's
# mean lean is rotated to this, frame-to-frame motion kept), head = target head pitch
# (0 = level, eyes ahead), shoulders back/down at the clavicles, arms abducted so the
# swing stays at her sides, hip_sway = pelvis roll toward the swing leg (lock_feet
# re-solves the legs afterwards).
POSTURE = {
    "idle": dict(lean=0.0, head=0.0, back=6.0, down=4.0, arms=3.0, hip_sway=0.0),
    "walk": dict(lean=1.0, head=0.0, back=8.0, down=5.0, arms=5.0, hip_sway=3.0),
    "run": dict(lean=5.0, head=-2.0, back=8.0, down=5.0, arms=7.0, hip_sway=3.0),
    "sprint": dict(lean=9.0, head=-4.0, back=6.0, down=4.0, arms=6.0, hip_sway=1.5),
    # Airborne: the source flings both arms out level (a scarecrow T in the game). Drop
    # them toward her sides with soft elbows, chest lifted, chin up.
    "jump_rise": dict(lean=-2.0, head=2.0, back=10.0, down=6.0, arms=-46.0, elbow=12.0, swing=22.0, hip_sway=0.0),
    "jump_fall": dict(lean=3.0, head=0.0, back=8.0, down=5.0, arms=-38.0, elbow=14.0, hip_sway=0.0),
    # Landing squat: trunk and head as captured (lean=None), arms in from the flail.
    "jump_land": dict(lean=None, head=0.0, back=6.0, down=4.0, arms=-30.0, elbow=10.0, hip_sway=0.0),
}
UPPER_SPINE = (("Spine", 0.4), ("Chest", 0.35), ("UpperChest", 0.25))


def bone_map() -> dict:
    """Source bone -> target bone."""
    m = {"pelvis": "Hips", "spine_01": "Spine", "spine_02": "Chest", "spine_03": "UpperChest",
         "neck_01": "Neck", "head": "Head"}
    for s, side in SIDES:
        for a, b in (("clavicle", "Shoulder"), ("upperarm", "UpperArm"), ("lowerarm", "LowerArm"),
                     ("hand", "Hand"), ("thigh", "UpperLeg"), ("calf", "LowerLeg"),
                     ("foot", "Foot"), ("ball", "Toes")):
            m["%s_%s" % (a, s)] = side + b
        for i, seg in enumerate(("Metacarpal", "Proximal", "Distal")):
            m["thumb_%02d_%s" % (i + 1, s)] = side + "Thumb" + seg
        for a, b in (("index", "Index"), ("middle", "Middle"), ("ring", "Ring"), ("pinky", "Little")):
            for i, seg in enumerate(("Proximal", "Intermediate", "Distal")):
                m["%s_%02d_%s" % (a, i + 1, s)] = side + b + seg
    return m


def sample_times(t0: float, t1: float, n: int, playback: str) -> list[float]:
    if playback == "loop":        # n distinct frames, then a copy of the first
        return [t0 + (t1 - t0) * f / n for f in range(n + 1)]
    if playback == "pingpong":    # n distinct frames out and back (eased), then the first
        h = n // 2
        u = [f / h for f in range(h)] + [1.0 - f / h for f in range(h)] + [0.0]
        return [t0 + (t1 - t0) * (0.5 - 0.5 * math.cos(math.pi * x)) for x in u]
    return [t0 + (t1 - t0) * f / (n - 1) for f in range(n)]


# --------------------------------------------------------------------------
# Scene helpers
# --------------------------------------------------------------------------
def import_glb(path: str) -> list:
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    return [o for o in bpy.data.objects if o not in before]


def sole_points(arm: bpy.types.Object, mesh: bpy.types.Object, bones: list[str]) -> dict:
    """Rest sole vertices (z <= SOLE_Z) by dominant foot bone, in bone-local space."""
    names = {g.index: g.name for g in mesh.vertex_groups}
    mw = mesh.matrix_world
    out = {b: [] for b in bones}
    for v in mesh.data.vertices:
        p = mw @ v.co
        if p.z > SOLE_Z or not v.groups:
            continue
        bn = names.get(max(v.groups, key=lambda e: e.weight).group)
        if bn in out:
            out[bn].append(arm.data.bones[bn].matrix_local.inverted() @ p)
    return out


def body_probes(arm: bpy.types.Object, mesh: bpy.types.Object, bones: list[str], step: int = 3) -> dict:
    """Every `step`-th vertex skinned mostly to `bones`, bone-local (rigid approximation)."""
    names = {g.index: g.name for g in mesh.vertex_groups}
    mw = mesh.matrix_world
    out = {b: [] for b in bones}
    for v in list(mesh.data.vertices)[::step]:
        if not v.groups:
            continue
        bn = names.get(max(v.groups, key=lambda e: e.weight).group)
        if bn in out:
            out[bn].append(arm.data.bones[bn].matrix_local.inverted() @ (mw @ v.co))
    return out


def depth(b: bpy.types.Bone) -> int:
    d = 0
    while b.parent:
        b, d = b.parent, d + 1
    return d


class Rig:
    """Rest data plus forward kinematics for one armature."""

    def __init__(self, arm: bpy.types.Object, soles: dict) -> None:
        self.obj = arm
        bones = sorted(arm.data.bones, key=depth)
        self.names = [b.name for b in bones]
        self.rest = {b.name: b.matrix_local.copy() for b in bones}
        self.rest3 = {n: m.to_3x3() for n, m in self.rest.items()}
        self.parent = {b.name: (b.parent.name if b.parent else None) for b in bones}
        self.rel = {n: (self.rest[p].inverted() @ self.rest[n] if p else self.rest[n])
                    for n, p in self.parent.items()}
        self.soles = soles
        self.probes: dict = {}

    def fk(self, quats: dict, hips_loc: Vector) -> dict:
        """Bone -> armature-space pose matrix from local quaternions + Hips location."""
        out = {}
        for n in self.names:
            basis = quats.get(n, Quaternion()).to_matrix().to_4x4()
            if n == "Hips":
                basis = Matrix.Translation(hips_loc) @ basis
            p = self.parent[n]
            out[n] = (out[p] if p else Matrix()) @ self.rel[n] @ basis
        return out

    def foot_points(self, pose: dict, bones=None) -> list[Vector]:
        bones = self.soles if bones is None else bones
        return [pose[b] @ p for b in bones for p in self.soles[b]]

    def lowest(self, pose: dict) -> float:
        return min(p.z for p in self.foot_points(pose))


def set_action(obj: bpy.types.Object, act: bpy.types.Action) -> None:
    ad = obj.animation_data or obj.animation_data_create()
    ad.action = act
    if hasattr(ad, "action_slot") and act.slots and ad.action_slot is None:
        ad.action_slot = act.slots[0]


def fix_quat_signs(act: bpy.types.Action, obj: bpy.types.Object) -> None:
    """Make each bone's quaternion keys sign-continuous.

    Some source keys flip sign between neighbours; Blender interpolates the components
    linearly, so sampling between such keys (24 fps keys on a 30 fps timeline) would
    pass through a near-zero quaternion and the bone would spin.
    """
    curves = {}
    for layer in act.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for fc in bag.fcurves:
                    if fc.data_path.endswith("rotation_quaternion"):
                        curves.setdefault(fc.data_path, [None] * 4)[fc.array_index] = fc
    for fcs in curves.values():
        if None in fcs or len({len(fc.keyframe_points) for fc in fcs}) != 1:
            continue
        keys = [fc.keyframe_points for fc in fcs]
        prev = None
        for i in range(len(keys[0])):
            q = [k[i].co[1] for k in keys]
            if prev is not None and sum(a * b for a, b in zip(q, prev)) < 0.0:
                for k in keys:
                    k[i].co[1] = -k[i].co[1]
                    k[i].handle_left[1] = -k[i].handle_left[1]
                    k[i].handle_right[1] = -k[i].handle_right[1]
                q = [-x for x in q]
            prev = q
        for fc in fcs:
            fc.update()


def sample_source(src: Rig, act: bpy.types.Action, times: list[float]) -> list[dict]:
    """Armature-space pose matrices of every source bone at each (fractional) frame."""
    scn = bpy.context.scene
    set_action(src.obj, act)
    frames = []
    for t in times:
        f = math.floor(t)
        scn.frame_set(f, subframe=t - f)
        frames.append({pb.name: pb.matrix.copy() for pb in src.obj.pose.bones})
    return frames


# --------------------------------------------------------------------------
# Retarget
# --------------------------------------------------------------------------
def lean_deg(v: Vector) -> float:
    """Forward lean of an up-pointing vector from vertical (forward is -Y), degrees."""
    return math.degrees(math.atan2(-v.y, v.z))


def subtree(tgt: Rig, root: str) -> set:
    out = {root}
    for n in tgt.names:             # names are sorted by depth: parents come first
        if tgt.parent[n] in out:
            out.add(n)
    return out


def posture_rotations(src: Rig, tgt: Rig, frames: list[dict], spec: dict) -> dict:
    """Constant per-bone armature-space corrections (bone -> 3x3) applied to the subtree."""
    trunk = sum(lean_deg(fr["neck_01"].translation - fr["pelvis"].translation) for fr in frames)
    head = sum(lean_deg(fr["head"].to_3x3() @ src.rest3["head"].inverted() @ Vector((0, 0, 1)))
               for fr in frames)
    trunk, head = trunk / len(frames), head / len(frames)
    keep = spec["lean"] is None
    back = 0.0 if keep else trunk - spec["lean"]
    # Head pitch after the trunk fix, brought to the target (eyes ahead, chin up).
    nod = 0.0 if keep else (head - back) - spec["head"]
    rx = lambda deg: Matrix.Rotation(math.radians(-deg), 3, "X")  # noqa: E731  (+deg pitches back)
    rot = {name: rx(back * w) for name, w in UPPER_SPINE}
    rot["Neck"] = rx(nod * 0.5)
    rot["Head"] = rx(nod * 0.5)
    for side, s in (("Left", 1.0), ("Right", -1.0)):
        rot[side + "Shoulder"] = (Matrix.Rotation(math.radians(spec["back"] * s), 3, "Z")
                                  @ Matrix.Rotation(math.radians(spec["down"] * s), 3, "Y"))
        # swing > 0: right arm forward, left arm back (opposite her raised left knee).
        rot[side + "UpperArm"] = (Matrix.Rotation(math.radians(spec.get("swing", 0.0) * s), 3, "X")
                                  @ Matrix.Rotation(math.radians(-spec["arms"] * s), 3, "Y"))
        if spec.get("elbow"):       # bends the forearm forward at the elbow
            rot[side + "LowerArm"] = Matrix.Rotation(math.radians(-spec["elbow"]), 3, "X")
    if not keep:
        print("  posture: trunk lean %.1f -> %.1f deg, head %.1f -> %.1f deg"
              % (trunk, spec["lean"], head, spec["head"]))
    return rot


def hip_sway(src: Rig, fr: dict, deg: float) -> Matrix:
    """Pelvis roll toward the swing leg: the side whose foot is higher drops."""
    lift = fr["foot_r"].translation.z - fr["foot_l"].translation.z
    roll = deg * math.tanh(lift / 0.06)
    # +roll about -Y (forward) drops her right hip when the right foot is up.
    return Matrix.Rotation(math.radians(roll), 3, Vector((0.0, -1.0, 0.0)))


def retarget(src: Rig, tgt: Rig, frames: list[dict], cyclic: bool, placement: str,
             posture: dict | None = None) -> list:
    """Source pose frames -> per-frame (target local quaternions, Hips location)."""
    inv = {t: s for s, t in bone_map().items()}
    fixes = []
    if posture:
        # Each correction rotates its bone's whole subtree rigidly (children follow).
        for bone, m in posture_rotations(src, tgt, frames, posture).items():
            fixes.append((bone, subtree(tgt, bone), m))
    offs = [fr["pelvis"].translation - src.rest["pelvis"].translation for fr in frames]
    n = len(offs)
    t = np.arange(n, dtype=float)
    if cyclic:   # drift from first to last frame is root motion
        fits = [((offs[-1][i] - offs[0][i]) / max(n - 1, 1), offs[0][i]) for i in range(2)]
    else:
        fits = [np.polyfit(t, [o[i] for o in offs], 1) for i in range(2)]
    hips_inv = tgt.rest3["Hips"].inverted()
    out = []
    for f, fr in enumerate(frames):
        world = {tn: fr[inv[tn]].to_3x3().normalized() @ src.rest3[inv[tn]].inverted() @ tgt.rest3[tn]
                 for tn in tgt.names if tn in inv}
        for _, bones, m in fixes:
            for b in bones:
                if b in world:
                    world[b] = m @ world[b]
        if posture and posture["hip_sway"] > 0.0:
            world["Hips"] = hip_sway(src, fr, posture["hip_sway"]) @ world["Hips"]
        quats, posed = {}, {}
        for tn in tgt.names:
            p = tgt.parent[tn]
            under = (posed[p] if p else Matrix.Identity(3)) @ tgt.rel[tn].to_3x3()
            posed[tn] = world.get(tn, under)
            quats[tn] = (under.inverted() @ posed[tn]).to_quaternion().normalized()
        o = offs[f]
        d = Vector([(o[i] - (fits[i][0] * f + fits[i][1])) * K for i in range(2)] + [o.z * K])
        if placement == "air":
            d = Vector((d.x, d.y, 0.0))
        else:
            want = max(K * src.lowest(fr), 0.0)
            d.z += want - tgt.lowest(tgt.fk(quats, hips_inv @ d))
            # Knees, toes and hands (kneels, three-point landings) must not sink either.
            pose = tgt.fk(quats, hips_inv @ d)
            d.z -= min(0.0, min((pose[b] @ p).z for b, pts in tgt.probes.items() for p in pts))
        out.append((quats, hips_inv @ d))
    return out


def stance(tgt: Rig, baked: list, cyclic: bool) -> dict:
    """Per foot: planted flags and contact-patch velocity (m/s) per frame.

    The contact patch = that foot's sole points within 1 cm of its lowest; its velocity is
    taken as material points into the next frame.
    """
    n = len(baked) - 1 if cyclic else len(baked)
    poses = [tgt.fk(q, loc) for q, loc in baked]
    res = {}
    for _, side in SIDES:
        bones = (side + "Foot", side + "Toes")
        on, vel = [], []
        for f in range(n):
            g = (f + 1) % n if cyclic else min(f + 1, n - 1)
            p0 = tgt.foot_points(poses[f], bones)
            p1 = tgt.foot_points(poses[g], bones)
            zmin = min(p.z for p in p0)
            idx = [i for i, p in enumerate(p0) if p.z < zmin + 0.01]
            on.append(zmin < CONTACT_Z)
            vel.append(sum((p1[i] - p0[i] for i in idx), Vector()) / len(idx) * FPS)
        res[side] = (on, vel)
    return res


def windows(on: list[bool], cyclic: bool) -> list[list[int]]:
    """Runs of planted frames (wrapping around for loops)."""
    n = len(on)
    if all(on):
        return [list(range(n))]
    start = next(i for i in range(n) if not on[i]) if cyclic else 0
    runs, cur = [], []
    for k in range(n):
        i = (start + k) % n if cyclic else k
        if on[i]:
            cur.append(i)
        elif cur:
            runs.append(cur)
            cur = []
    if cur:
        runs.append(cur)
    return runs


def native_speed(st: dict) -> float:
    vs = [v.y for on, vel in st.values() for o, v in zip(on, vel) if o]
    return sum(vs) / len(vs) if vs else 0.0


def solve_leg(tgt: Rig, quats: dict, loc: Vector, side: str, offset: Vector) -> bool:
    """Move the ankle by `offset` (two-bone IK, knee stays in its plane, foot keeps its
    armature-space orientation).  Returns False if the leg had to be clamped."""
    pose = tgt.fk(quats, loc)
    up, lo, ft = side + "UpperLeg", side + "LowerLeg", side + "Foot"
    hip, knee, ankle = pose[up].translation, pose[lo].translation, pose[ft].translation
    l1, l2 = (knee - hip).length, (ankle - knee).length
    d_vec = ankle + offset - hip
    ok = d_vec.length <= 0.9995 * (l1 + l2)
    d = min(max(d_vec.length, abs(l1 - l2) + 1e-4), 0.9995 * (l1 + l2))
    dirn = d_vec.normalized()
    goal = hip + dirn * d
    pole = (knee - hip) - dirn * (knee - hip).dot(dirn)
    pole = pole.normalized() if pole.length > 1e-6 else Vector((0.0, -1.0, 0.0))
    a = (l1 * l1 - l2 * l2 + d * d) / (2.0 * d)
    knee_new = hip + dirn * a + pole * math.sqrt(max(l1 * l1 - a * a, 0.0))
    r1 = (knee - hip).rotation_difference(knee_new - hip).to_matrix()
    w_up = r1 @ pose[up].to_3x3().normalized()
    r2 = (r1 @ (ankle - knee)).rotation_difference(goal - knee_new).to_matrix()
    w_lo = r2 @ r1 @ pose[lo].to_3x3().normalized()
    w_ft = pose[ft].to_3x3().normalized()
    under = pose["Hips"].to_3x3().normalized() @ tgt.rel[up].to_3x3()
    quats[up] = (under.inverted() @ w_up).to_quaternion().normalized()
    quats[lo] = ((w_up @ tgt.rel[lo].to_3x3()).inverted() @ w_lo).to_quaternion().normalized()
    quats[ft] = ((w_lo @ tgt.rel[ft].to_3x3()).inverted() @ w_ft).to_quaternion().normalized()
    return ok


def surge_hips(tgt: Rig, baked: list, cyclic: bool) -> None:
    """Take up most of the stance foot's speed wobble with a smooth fore-aft hips surge.

    In-place mocap lets the planted foot speed up and slow down; moving the body (rather
    than only the foot) keeps legs within reach.  The correction integrates
    (v - stance speed) over planted frames, is smoothed (gaussian, SURGE_SIGMA frames) and
    has zero mean and no net drift, so the clip still plays in place.
    """
    n = len(baked) - 1 if cyclic else len(baked)
    st = stance(tgt, baked, cyclic)
    speeds = []
    for f in range(n):
        vs = [vel[f].y for on, vel in st.values() if on[f]]
        speeds.append(sum(vs) / len(vs) if vs else None)
    planted = [s for s in speeds if s is not None]
    if not planted:
        return
    v = sum(planted) / len(planted)
    c, acc = [], 0.0
    for s in speeds:
        c.append(acc)
        acc += ((v - s) if s is not None else 0.0) / FPS
    c = [x - acc * f / n for f, x in enumerate(c)]           # close the loop exactly
    k = [math.exp(-0.5 * (j / SURGE_SIGMA) ** 2) for j in range(-6, 7)]
    sm = [sum(w * c[(f + j - 6) % n if cyclic else min(max(f + j - 6, 0), n - 1)]
              for j, w in enumerate(k)) / sum(k) for f in range(n)]
    mean = sum(sm) / n
    hips_inv = tgt.rest3["Hips"].inverted()
    for f in range(n):
        quats, loc = baked[f]
        baked[f] = (quats, loc + hips_inv @ Vector((0.0, sm[f] - mean, 0.0)))
    if cyclic:
        baked[-1] = baked[0]


def lock_feet(tgt: Rig, baked: list, cyclic: bool) -> int:
    """Pin each planted foot's contact patch to a treadmill at the clip's native speed.

    Within a stance the patch should move (0, v, 0) per second; the shortfall is
    integrated into an ankle offset (centred over the stance so the leg moves least) and
    applied with leg IK, fading over LOCK_EASE frames either side.  Returns clamp count.
    """
    n = len(baked) - 1 if cyclic else len(baked)
    surge_hips(tgt, baked, cyclic)
    st = stance(tgt, baked, cyclic)
    v = native_speed(st)
    offsets = {side: [Vector() for _ in range(n)] for _, side in SIDES}
    for side, (on, vel) in st.items():
        for run in windows(on, cyclic):
            acc, corr = Vector(), []
            for i in run:
                corr.append(acc.copy())
                acc = acc + Vector((-vel[i].x, v - vel[i].y, 0.0)) / FPS
            mean = sum(corr, Vector()) / len(corr)
            corr = [c - mean for c in corr]
            after = acc - mean          # the frame after the stance closes its last step
            for i, c in zip(run, corr):
                offsets[side][i] = c
            for k in range(1, LOCK_EASE + 1):
                w = 0.5 + 0.5 * math.cos(math.pi * k / (LOCK_EASE + 1))
                w_out = 0.5 + 0.5 * math.cos(math.pi * (k - 1) / (LOCK_EASE + 1))
                for i, c in ((run[0] - k, corr[0] * w), (run[-1] + k, after * w_out)):
                    if cyclic:
                        i %= n
                    if 0 <= i < n and not on[i]:
                        offsets[side][i] = offsets[side][i] + c
    # Where a locked foot is out of reach, lower the hips (eased over neighbouring frames)
    # and keep both ankles where they were.
    need = []
    for f in range(n):
        pose = tgt.fk(*baked[f])
        h = 0.0
        for side, offs in offsets.items():
            hip = pose[side + "UpperLeg"].translation
            knee = pose[side + "LowerLeg"].translation
            ankle = pose[side + "Foot"].translation
            reach = 0.999 * ((knee - hip).length + (ankle - knee).length)
            d = ankle + offs[f] - hip
            horiz2 = d.x * d.x + d.y * d.y
            if d.length > reach and horiz2 < reach * reach:
                h = max(h, -d.z - math.sqrt(reach * reach - horiz2))
        need.append(h)
    ease = (0.45, 0.8, 1.0, 0.8, 0.45)
    hips_inv = tgt.rest3["Hips"].inverted()
    clamps = 0
    for f in range(n):
        idx = [((f + j - 2) % n if cyclic else min(max(f + j - 2, 0), n - 1)) for j in range(5)]
        drop = max(need[i] * w for i, w in zip(idx, ease))
        quats, loc = baked[f]
        loc = loc - hips_inv @ Vector((0.0, 0.0, drop))
        baked[f] = (quats, loc)
        for side in offsets:
            off = offsets[side][f] + Vector((0.0, 0.0, drop))
            if off.length > 1e-6:
                clamps += not solve_leg(tgt, quats, loc, side, off)
    return clamps


def leg_clearance(tgt: Rig, baked: list, cyclic: bool) -> int:
    """Swing the airborne leg out at the hip where her knees/shins would pass through
    each other (narrow-track mocap on a fuller-thighed body).  Returns frames touched."""
    n = len(baked) - 1 if cyclic else len(baked)

    def gap(pose: dict, swing: str, rot: Matrix) -> float:
        hip = pose[swing + "UpperLeg"].translation
        pts = {}
        for side in ("Left", "Right"):
            k, a = pose[side + "LowerLeg"].translation, pose[side + "Foot"].translation
            if side == swing:
                k, a = hip + rot @ (k - hip), hip + rot @ (a - hip)
            h = pose[side + "UpperLeg"].translation
            pts[side] = ([h.lerp(k, 0.5 + i / 12) for i in range(7)],
                         [k.lerp(a, i / 10) for i in range(11)])
        o = "Right" if swing == "Left" else "Left"
        pairs = ((pts[swing][1], pts[o][0]), (pts[swing][1], pts[o][1]), (pts[swing][0], pts[o][1]))
        return min((p - q).length for x, y in pairs for p in x for q in y)

    need = []
    for f in range(n):
        pose = tgt.fk(*baked[f])
        swing = max(("Left", "Right"), key=lambda s: min(
            p.z for p in tgt.foot_points(pose, (s + "Foot", s + "Toes"))))
        sign = -1.0 if swing == "Left" else 1.0       # rotation about +Y that moves it outward
        ang = 0.0
        while ang < 15.0 and gap(pose, swing, Matrix.Rotation(math.radians(sign * ang), 3, "Y")) < LEG_GAP:
            ang += 0.5
        need.append((swing, sign * ang))
    ease = (0.45, 0.8, 1.0, 0.8, 0.45)
    touched = 0
    for f in range(n):
        idx = [((f + j - 2) % n if cyclic else min(max(f + j - 2, 0), n - 1)) for j in range(5)]
        swing = need[f][0]
        ang = max((abs(need[i][1]) * w for i, w in zip(idx, ease) if need[i][0] == swing), default=0.0)
        if ang <= 0.0:
            continue
        touched += 1
        quats, loc = baked[f]
        pose = tgt.fk(quats, loc)
        up = swing + "UpperLeg"
        rot = Matrix.Rotation(math.radians(ang * (-1.0 if swing == "Left" else 1.0)), 3, "Y")
        under = pose["Hips"].to_3x3().normalized() @ tgt.rel[up].to_3x3()
        quats[up] = (under.inverted() @ rot @ pose[up].to_3x3().normalized()).to_quaternion().normalized()
    return touched


def foot_stats(tgt: Rig, baked: list) -> dict:
    """Native speed and the worst per-stance slide against a treadmill at that speed."""
    st = stance(tgt, baked, True)
    v = native_speed(st)
    worst = 0.0
    for on, vel in st.values():
        for run in windows(on, True):
            pos, xs, ys = Vector(), [0.0], [0.0]
            for i in run:
                pos = pos + Vector((vel[i].x, vel[i].y - v, 0.0)) / FPS
                xs.append(pos.x)
                ys.append(pos.y)
            worst = max(worst, math.hypot(max(xs) - min(xs), max(ys) - min(ys)))
    return {"speed": v, "residual": worst}


# --------------------------------------------------------------------------
# Keying and export
# --------------------------------------------------------------------------
def key_action(obj: bpy.types.Object, name: str, baked: list, cyclic: bool) -> bpy.types.Action:
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    set_action(obj, act)
    nf = len(baked)
    frames = np.arange(nf, dtype=np.float32)
    channels = [('pose.bones["%s"].rotation_quaternion' % b, i, b,
                 [fr[0][b][i] for fr in baked]) for b in baked[0][0] for i in range(4)]
    channels += [('pose.bones["Hips"].location', i, "Hips", [fr[1][i] for fr in baked]) for i in range(3)]
    for path, i, group, vals in channels:
        fc = act.fcurve_ensure_for_datablock(obj, path, index=i, group_name=group)
        fc.keyframe_points.add(nf)
        fc.keyframe_points.foreach_set("co", np.column_stack((frames, np.float32(vals))).ravel())
        fc.keyframe_points.foreach_set("interpolation", [1] * nf)  # LINEAR
        fc.update()
    act.frame_range = (0.0, float(nf - 1))
    act.use_frame_range = True
    act.use_cyclic = cyclic
    return act


def export(arm: bpy.types.Object, path: str) -> None:
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.export_scene.gltf(
        filepath=path, export_format="GLB", use_selection=True, export_apply=False,
        export_animations=True, export_animation_mode="ACTIONS", export_skins=False,
        export_morph=False, export_yup=True, export_extras=False, export_force_sampling=True,
        export_frame_step=1, export_optimize_animation_size=False, export_anim_slide_to_zero=False,
        export_def_bones=False, export_reset_pose_bones=True)
    add_skin(path)


def add_skin(path: str) -> None:
    """Declare the bone nodes as a glTF skin.

    Blender writes an armature without a skinned mesh as plain nodes, which Godot would
    import as Node3Ds.  A skin (joints only; no mesh uses it) makes Godot build the same
    Armature/Skeleton3D as feyre.glb, so tracks read "Armature/Skeleton3D:<Bone>".
    """
    with open(path, "rb") as f:
        data = f.read()
    jlen = struct.unpack("<I", data[12:16])[0]
    doc = json.loads(data[20:20 + jlen])
    rest = data[20 + jlen:]
    arm = next(i for i, nd in enumerate(doc["nodes"]) if nd.get("name") == "Armature")
    joints, queue = [], list(doc["nodes"][arm].get("children", []))
    while queue:
        i = queue.pop(0)
        joints.append(i)
        queue.extend(doc["nodes"][i].get("children", []))
    doc["skins"] = [{"name": "Armature", "skeleton": joints[0], "joints": joints}]
    js = json.dumps(doc, separators=(",", ":")).encode()
    js += b" " * (-len(js) % 4)
    body = struct.pack("<I", len(js)) + b"JSON" + js + rest
    with open(path, "wb") as f:
        f.write(b"glTF" + struct.pack("<II", 2, 12 + len(body)) + body)


# --------------------------------------------------------------------------
# Build
# --------------------------------------------------------------------------
def build(source_dir: str, clips=CLIPS) -> tuple[Rig, list]:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scn = bpy.context.scene
    scn.render.fps, scn.render.fps_base = FPS, 1.0       # before import: keys land at 30 fps
    objs = import_glb(TARGET_GLB)
    arm = next(o for o in objs if o.type == "ARMATURE")
    body = next(o for o in objs if o.name == "Body")
    tgt = Rig(arm, sole_points(arm, body, [side + b for _, side in SIDES for b in ("Foot", "Toes")]))
    tgt.probes = body_probes(arm, body, [side + b for _, side in SIDES
                                         for b in ("LowerLeg", "Foot", "Toes", "Hand", "LowerArm")])
    for a in list(bpy.data.actions):
        bpy.data.actions.remove(a)
    for o in objs:
        if o is not arm:
            bpy.data.objects.remove(o, do_unlink=True)
    srcs, acts = {}, {}
    for key, fn in SOURCE_FILES.items():
        before = set(bpy.data.actions)
        objs = import_glb(os.path.join(source_dir, fn))
        sarm = next(o for o in objs if o.type == "ARMATURE")
        mesh = next(o for o in objs if o.type == "MESH" and o.vertex_groups)
        soles = sole_points(sarm, mesh, ["%s_%s" % (b, s) for s, _ in SIDES for b in ("foot", "ball")])
        for o in objs:
            if o is not sarm:
                bpy.data.objects.remove(o, do_unlink=True)
        sarm.name = "src_" + key
        srcs[key] = Rig(sarm, soles)
        acts[key] = {a.name: a for a in bpy.data.actions if a not in before}
        for a in acts[key].values():
            fix_quat_signs(a, sarm)
    arm.name = "Armature"
    results = []
    for name, key, sact, t0, t1, nout, playback, placement in clips:
        cyclic = playback != "once"
        frames = sample_source(srcs[key], acts[key][sact], sample_times(t0, t1, nout, playback))
        print(name)
        baked = retarget(srcs[key], tgt, frames, cyclic, placement, POSTURE.get(name))
        if cyclic:
            baked[-1] = baked[0]
        clamps = 0
        if placement == "gait":
            clamps = lock_feet(tgt, baked, cyclic)
            leg_clearance(tgt, baked, cyclic)
        if cyclic:
            baked[-1] = (dict(baked[0][0]), baked[0][1].copy())
        for f in range(1, len(baked)):      # keep quaternion signs continuous
            for b, q in baked[f][0].items():
                if q.dot(baked[f - 1][0][b]) < 0.0:
                    baked[f][0][b] = -q
        results.append((name, baked, cyclic, clamps))
    for rig in srcs.values():
        bpy.data.objects.remove(rig.obj, do_unlink=True)
    for a in list(bpy.data.actions):
        bpy.data.actions.remove(a)
    for pb in arm.pose.bones:
        pb.rotation_mode = "QUATERNION"
    for name, baked, cyclic, _ in results:
        key_action(arm, name, baked, cyclic)
    arm.animation_data.action = None
    for pb in arm.pose.bones:
        pb.rotation_quaternion = Quaternion()
        pb.location = Vector()
    return tgt, results


def report(tgt: Rig, results: list) -> list[str]:
    lines = []
    for name, baked, cyclic, clamps in results:
        dur = (len(baked) - 1) / FPS
        if name in LOCOMOTION:
            st = foot_stats(tgt, baked)
            lines.append("%s %.3f %.3f %d" % (name, max(st["speed"], 0.0), dur, int(cyclic)))
            print("  %-14s %3d f  %.3f s  native %.3f m/s  slide residual %.1f cm  ik clamps %d"
                  % (name, len(baked), dur, st["speed"], st["residual"] * 100.0, clamps))
        else:
            lines.append("%s - %.3f %d" % (name, dur, int(cyclic)))
            print("  %-14s %3d f  %.3f s" % (name, len(baked), dur))
    return lines


def main() -> None:
    argv = sys.argv[1:]
    speeds = None
    if "--speeds" in argv:
        i = argv.index("--speeds")
        speeds = argv[i + 1]
        del argv[i:i + 2]
    source_dir, out = argv[0], argv[1]
    tgt, results = build(source_dir)
    export(tgt.obj, out)
    print("wrote", out, "%.2f MB" % (os.path.getsize(out) / 1e6))
    lines = report(tgt, results)
    if speeds:
        os.makedirs(os.path.dirname(os.path.abspath(speeds)), exist_ok=True)
        with open(speeds, "w") as f:
            f.write("# Feyre move set (characters/feyre/anim/feyre_moves.glb), 30 fps.\n"
                    "# name native_speed_mps duration_s loop(0/1)   ('-' = not a locomotion clip)\n")
            f.write("\n".join(lines) + "\n")
        print("wrote", speeds)


if __name__ == "__main__":
    main()
