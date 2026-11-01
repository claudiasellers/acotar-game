"""Skeleton, skin weights and authored clips for the villagers and the court's
secondary cast (tools/blender/fae_people.py). The same approach as the animals
(creature_rig.py): bones on the skin graph's joints, weights by distance, motion
authored as curves with analytic leg IK so planted feet stay planted.

Clips (in place; the game moves the body):
  idle    weight on one hip, then the other; breath; small looks     looping
  walk    heel-strike, roll to the toe; hips turn and drop, arms swing looping
  talk    idle with a hand that explains and a nod                   looping
  flinch  startled: shoulders up, hands up, a half-step back
  bow     a courtly bow from the waist (servants, sentries greeting her)

Axes as in creature_rig: Blender y forward, z up, +x the figure's right.
"""

import math

import bpy
import numpy as np
from mathutils import Euler, Vector

import creature_rig as cr
from creature_rig import FPS, clamp01, pulse, rad, seg, smooth

LEGS = ("leg_l", "leg_r")
UP = Vector((0, 0, 1))
FWD = Vector((0, 1, 0))


def _P(g, name):
    return Vector(g.points[g.names[name]])


def build_armature(g, H, hr):
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

    pelvis, waist, chest, neck, head = (_P(g, n) for n in ("pelvis", "waist", "chest", "neck", "head"))
    bone("root", (0, 0, 0), (0, 0.25 * H, 0), None, UP)
    bone("body", pelvis, pelvis + Vector((0, 0.1 * H, 0)), "root", UP)
    bone("pelvis", pelvis, pelvis - Vector((0, 0, 0.07 * H)), "body", FWD)
    bone("spine", pelvis, waist, "body", FWD)
    bone("chest", waist, chest, "spine", FWD)
    bone("neck", chest, neck, "chest", FWD)
    bone("head", neck, head + Vector((0, 0, hr)), "neck", FWD)
    for side, tag in ((-1, "l"), (1, "r")):
        sh, el, wr, hd = (_P(g, f"{k}{side}") for k in ("sh", "el", "wr", "hd"))
        bone(f"clav_{tag}", chest + Vector((side * 0.02 * H, 0, 0.02 * H)), sh, "chest", UP)
        bone(f"arm_{tag}", sh, el, f"clav_{tag}", FWD)
        bone(f"forearm_{tag}", el, wr, f"arm_{tag}", FWD)
        bone(f"hand_{tag}", wr, hd + (hd - wr) * 0.6, f"forearm_{tag}", FWD)
        hip, kn, an, ft = (_P(g, f"{k}{side}") for k in ("hip", "kn", "an", "ft"))
        bone(f"upper_leg_{tag}", hip, kn, "pelvis", FWD)
        bone(f"lower_leg_{tag}", kn, an, f"upper_leg_{tag}", FWD)
        bone(f"paw_leg_{tag}", an, ft + (ft - an) * 0.5, f"lower_leg_{tag}", FWD)
    bpy.ops.object.mode_set(mode="OBJECT")
    return arm


def weight(obj, arm, H, head_z):
    """Distance weights over the whole joined figure. Everything above the jaw
    rides the head; cloth that hangs away from the limbs (skirts, robes,
    cloaks, wings) leans on the pelvis or chest so it sways rather than tears."""
    segs = cr._segments(arm)
    names = [s[0] for s in segs]
    heads = np.array([s[1] for s in segs])
    tails = np.array([s[2] for s in segs])
    axis = tails - heads
    length2 = np.maximum((axis * axis).sum(1), 1e-9)
    limb = np.array([n.startswith(("upper_leg", "arm_", "clav_")) for n in names])
    idx = {n: i for i, n in enumerate(names)}
    groups = [obj.vertex_groups.new(name=n) for n in names]
    co = np.zeros(len(obj.data.vertices) * 3)
    obj.data.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    soft_r = 0.07 * H
    for vi, p in enumerate(co):
        if p[2] > head_z:
            groups[idx["head"]].add([vi], 1.0, "REPLACE")
            continue
        rel = p - heads
        t = (rel * axis).sum(1) / length2
        tc = np.clip(t, 0.0, 1.0)
        d = np.linalg.norm(rel - axis * tc[:, None], axis=1)
        d = np.where(limb & (t < 0.0), d * 1.8, d)
        order = np.argsort(d)[:3]
        dm = d[order[0]] + 1e-4
        w = {names[o]: ((dm / (d[o] + 1e-4)) ** 8 if d[o] < dm * 1.6 + 0.01 else 0.0) for o in order}
        total = sum(w.values())
        w = {k: v / total for k, v in w.items()}
        # Cloth over the thighs (tunic skirts, dresses, aprons, robes): what is
        # not the trouser leg itself follows the pelvis more than the leg.
        leg_w = sum(v for n, v in w.items() if n.startswith(("upper_leg", "lower_leg")))
        if leg_w > 0.0 and dm > 0.045 * H and p[2] > 0.08 * H:
            f = clamp01((dm - 0.045 * H) / (0.05 * H)) * 0.8
            w = {n: (v * (1.0 - f) if n.startswith(("upper_leg", "lower_leg")) else v) for n, v in w.items()}
            w["pelvis"] = w.get("pelvis", 0.0) + leg_w * f
        k = clamp01((dm - soft_r) / (0.12 * H)) * 0.65
        if k > 0.0:
            anchor = "pelvis" if p[2] < 0.62 * H else "chest"
            w = {n: v * (1.0 - k) for n, v in w.items()}
            w[anchor] = w.get(anchor, 0.0) + k
        for n, v in w.items():
            if v > 0.01:
                groups[idx[n]].add([vi], float(v), "REPLACE")


# ------------------------------------------------------------------ clips

def _feet(rig, shift=None):
    shift = shift or {}
    return {leg: (rig.foot[leg] + shift.get(leg, Vector()), 0.0) for leg in LEGS}


def _arms(swing_l, swing_r, bend=0.18, out=0.06):
    """Arm hang: forward swing per arm, a soft elbow, a little away from the body."""
    return {
        "arm_l": (swing_l, 0.0, out), "arm_r": (swing_r, 0.0, -out),
        "forearm_l": (bend + max(swing_l, 0.0) * 0.6, 0.0, 0.0),
        "forearm_r": (bend + max(swing_r, 0.0) * 0.6, 0.0, 0.0),
    }


def walk_clip(rig, H):
    T = 1.1 * math.sqrt(H / 1.75)
    duty, D = 0.62, 1.0 * rig.leg_len
    n = int(round(T * FPS))
    poses = []
    for i in range(n + 1):
        t = i / n
        w = 2.0 * math.pi * t
        feet = {}
        for leg, ph in (("leg_l", 0.0), ("leg_r", 0.5)):
            p = (t - ph) % 1.0
            c0 = rig.foot[leg]
            if p < duty:
                q = p / duty
                y = c0.y + D * 0.5 - D * q
                z = c0.z
                # Heel strike (toe up), flat, then the heel rises over the toe.
                pitch = rad(14.0) * (1.0 - smooth(seg(q, 0.0, 0.18))) - rad(32.0) * smooth(seg(q, 0.6, 1.0))
            else:
                s = (p - duty) / (1.0 - duty)
                y = c0.y - D * 0.5 + D * smooth(s)
                z = c0.z + 0.07 * H * math.sin(math.pi * clamp01(s * 1.05)) ** 1.4
                pitch = -rad(32.0) * (1.0 - smooth(seg(s, 0.0, 0.45))) + rad(14.0) * smooth(seg(s, 0.6, 1.0))
            feet[leg] = (cr._toe_on_ground(rig, leg, Vector((c0.x, y, z)), pitch), pitch)
        # Left foot strikes at t = 0: the body is lowest at each strike.
        bob = -0.012 * H * math.cos(2 * w)
        sway = 0.012 * H * math.cos(w)            # over the stance foot
        hip_yaw = rad(5.0) * math.sin(w)          # swing-side hip comes forward
        hip_drop = rad(3.0) * math.sin(w + math.pi / 2)
        arm = rad(18.0) * math.sin(w + math.pi / 2)
        rot = {
            "pelvis": (0.0, -hip_yaw, -hip_drop),
            "spine": (rad(2.5), -hip_yaw * 0.5, hip_drop * 0.4),
            "chest": (rad(1.0) + rad(1.0) * math.cos(2 * w), hip_yaw * 1.2, hip_drop * 0.3),
            "neck": (-rad(2.0), hip_yaw * 0.3, 0.0),
            "head": (-rad(1.5) * math.cos(2 * w), 0.0, -hip_drop * 0.4),
            **_arms(-arm, arm, bend=rad(12.0)),
        }
        poses.append({"body": (Vector((-sway, 0.0, bob)), Euler((rad(2.0), 0.0, 0.0))), "feet": feet, "rot": rot})
    cr.key_clip(rig, "walk", poses)
    return D / (duty * T), T


def idle_clip(rig, H, talk=False):
    T = 6.0 if not talk else 4.0
    n = int(round(T * FPS))
    poses = []
    for i in range(n + 1):
        t = i / n
        w = 2.0 * math.pi * t
        # Weight settles on one hip, then the other.
        shift = math.sin(w) if not talk else 0.35 * math.sin(w)
        breath = math.sin(2.0 * math.pi * t * (3 if not talk else 2))
        off = Vector((0.025 * H * shift, 0.0, -0.006 * H * abs(shift) + 0.002 * H * breath))
        roll = rad(2.0) * shift
        rot = {
            "pelvis": (0.0, 0.0, -roll * 1.5),
            "spine": (rad(1.0) * breath, rad(1.5) * math.sin(w + 0.5), roll * 0.8),
            "chest": (rad(1.2) * breath, 0.0, roll * 0.5),
            "neck": (rad(1.0) * math.sin(2 * w), rad(6.0) * math.sin(w + 1.3), 0.0),
            "head": (rad(1.5) * math.sin(3 * w + 0.4), rad(5.0) * math.sin(w + 2.0), -roll * 0.6),
            "clav_l": (0.0, 0.0, rad(1.5) * breath), "clav_r": (0.0, 0.0, -rad(1.5) * breath),
            **_arms(rad(2.0) * math.sin(w), rad(2.0) * math.sin(w + 1.0), bend=rad(14.0)),
        }
        if talk:
            # A hand that explains: up, turns, settles; twice, and a nod with each.
            g1 = pulse(t, 0.05, 0.18, 0.45)
            g2 = pulse(t, 0.55, 0.66, 0.92)
            g = max(g1, g2)
            rot["arm_r"] = (rad(28.0) * g, 0.0, -rad(10.0) * g - rad(6.0))
            rot["forearm_r"] = (rad(75.0) * g + rad(14.0), rad(30.0) * g, 0.0)
            rot["hand_r"] = (-rad(20.0) * g, rad(25.0) * math.sin(math.pi * g), 0.0)
            nod = pulse(t, 0.12, 0.2, 0.32) + pulse(t, 0.62, 0.7, 0.82)
            rot["head"] = (rot["head"][0] + rad(8.0) * nod, rot["head"][1], rot["head"][2])
            rot["chest"] = (rot["chest"][0] + rad(3.0) * g, -rad(4.0) * g, rot["chest"][2])
        poses.append({"body": (off, Euler((0.0, roll * 0.3, 0.0))), "feet": _feet(rig), "rot": rot})
    cr.key_clip(rig, "talk" if talk else "idle", poses)
    return T


def flinch_clip(rig, H):
    T = 1.2
    n = int(round(T * FPS))
    poses = []
    for i in range(n + 1):
        t = i / n * T
        jolt = pulse(t, 0.0, 0.1, 1.1)
        step = smooth(seg(t, 0.05, 0.3))
        lift = math.sin(math.pi * seg(t, 0.05, 0.3))
        back = Vector((0.0, -0.18 * H * step, 0.05 * H * lift))
        feet = _feet(rig)
        tgt, _ = feet["leg_r"]
        feet["leg_r"] = (tgt + back * (1.0 - smooth(seg(t, 0.6, 1.1))), 0.0)
        rot = {
            "spine": (-rad(8.0) * jolt, 0.0, 0.0),
            "chest": (-rad(5.0) * jolt, rad(6.0) * jolt, 0.0),
            "neck": (-rad(8.0) * jolt, 0.0, 0.0),
            "head": (-rad(6.0) * jolt, rad(8.0) * jolt, 0.0),
            "clav_l": (0.0, 0.0, -rad(10.0) * jolt), "clav_r": (0.0, 0.0, rad(10.0) * jolt),
            "arm_l": (rad(40.0) * jolt, 0.0, rad(14.0) * jolt), "arm_r": (rad(40.0) * jolt, 0.0, -rad(14.0) * jolt),
            "forearm_l": (rad(95.0) * jolt + rad(14.0), 0.0, 0.0), "forearm_r": (rad(95.0) * jolt + rad(14.0), 0.0, 0.0),
            "hand_l": (-rad(30.0) * jolt, 0.0, 0.0), "hand_r": (-rad(30.0) * jolt, 0.0, 0.0),
        }
        off = Vector((0.0, -0.06 * H * jolt, -0.02 * H * jolt))
        poses.append({"body": (off, Euler((-rad(5.0) * jolt, 0.0, 0.0))), "feet": feet, "rot": rot})
    cr.key_clip(rig, "flinch", poses)
    return T


def bow_clip(rig, H):
    T = 2.4
    n = int(round(T * FPS))
    poses = []
    for i in range(n + 1):
        t = i / n * T
        b = smooth(seg(t, 0.1, 0.8)) * (1.0 - smooth(seg(t, 1.5, 2.3)))
        rot = {
            "spine": (rad(22.0) * b, 0.0, 0.0),
            "chest": (rad(10.0) * b, 0.0, 0.0),
            "neck": (rad(8.0) * b, 0.0, 0.0),
            "head": (rad(10.0) * b, 0.0, 0.0),
            "arm_r": (rad(30.0) * b, 0.0, -rad(6.0)),
            "forearm_r": (rad(70.0) * b + rad(14.0), 0.0, -rad(30.0) * b),
            **{k: v for k, v in _arms(-rad(6.0) * b, 0.0, bend=rad(14.0)).items() if k.endswith("_l")},
        }
        off = Vector((0.0, -0.03 * H * b, -0.01 * H * b))
        poses.append({"body": (off, Euler((0.0, 0.0, 0.0))), "feet": _feet(rig), "rot": rot})
    cr.key_clip(rig, "bow", poses)
    return T


def animate(name, mesh, arm, g, H):
    bpy.context.scene.render.fps = FPS
    pelvis = _P(g, "pelvis")
    spec = {"length": 0.25 * H, "height": H, "width": 0.3 * H, "girth": 0.08 * H, "leg": 0.03 * H}
    pole = {leg: Vector((0, 1, 0)) for leg in LEGS}
    rig = cr.Rig(arm, spec, g, legs=LEGS, pole=pole, leg_len=pelvis.z)
    rig.mesh = mesh
    cr.skin(mesh, arm)
    rows = [("idle", 0.0, idle_clip(rig, H), 1)]
    v, T = walk_clip(rig, H)
    rows.append(("walk", v, T, 1))
    rows.append(("talk", None, idle_clip(rig, H, talk=True), 1))
    rows.append(("flinch", None, flinch_clip(rig, H), 0))
    rows.append(("bow", None, bow_clip(rig, H), 0))
    for pb in arm.pose.bones:
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.location = (0, 0, 0)
        pb.scale = (1, 1, 1)
    cr.write_speeds(name, rows, subdir="people")
    return arm
