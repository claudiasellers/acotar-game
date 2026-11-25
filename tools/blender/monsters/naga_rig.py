"""The naga's skeleton (bestiary §2.5): the biped names of
docs/contracts/creature_motion.md, plus a second neck bone, the jaw, a tongue
chain, digitigrade legs (upper, lower, foot, paw), two-bone fingers and the
socket bones the game hangs effects on."""

import numpy as np
from mathutils import Vector

import kit
import naga_body as nb
import rig

J = nb.J


def _m(p, s):
    return (p[0] * s, p[1], p[2])


def bones():
    """[(name, head, tail, parent, deform)], parents first."""
    B = [
        ("root", (0, 0, 0), (0, 0.15, 0), None, False),
        ("body", tuple(J["pelvis"]), (0, 0.13, 1.04), "root", False),
        ("pelvis", tuple(J["pelvis"]), (0, -0.02, 0.93), "body", True),
        ("spine", (0, -0.03, 1.06), tuple(J["spine"]), "body", True),
        ("spine2", tuple(J["spine"]), (0, -0.045, 1.33), "spine", True),
        ("chest", (0, -0.045, 1.33), (0, -0.01, 1.57), "spine2", True),
        ("neck", (0, 0.0, 1.585), tuple(J["neck2"]), "chest", True),
        ("neck2", tuple(J["neck2"]), tuple(J["head"]), "neck", True),
        ("head", tuple(J["head"]), tuple(J["head_end"]), "neck2", True),
        ("jaw", tuple(J["jaw"]), tuple(J["jaw_end"]), "head", True),
    ]
    z = nb.mouth_z(0.3) - 0.0085
    ty = (0.215, 0.285, 0.35, 0.44)
    for i in range(3):
        B.append((f"tongue{i}", (0, ty[i], z), (0, ty[i + 1], z - 0.002), "jaw" if i == 0 else f"tongue{i - 1}", True))
    # sockets
    B.append(("throat", (0, 0.165, 1.725), (0, 0.215, 1.725), "neck2", False))
    B.append(("mouth", (0, 0.44, 1.812), (0, 0.49, 1.812), "head", False))
    B.append(("grab_point", (0, 0.2, 1.40), (0, 0.25, 1.40), "chest", False))
    for side, s in (("r", 1), ("l", -1)):
        B.append((f"clav_{side}", _m(J["clav"], s), _m(J["arm"], s), "chest", True))
        B.append((f"arm_{side}", _m(J["arm"], s), _m(J["forearm"], s), f"clav_{side}", True))
        B.append((f"forearm_{side}", _m(J["forearm"], s), _m(J["hand"], s), f"arm_{side}", True))
        B.append((f"hand_{side}", _m(J["hand"], s), _m(J["knuckle"], s), f"forearm_{side}", True))
        fs = nb.fingers()
        for i, (root, mid, tip, claw) in enumerate(fs):
            B.append((f"finger_{i}_{side}", _m(root, s), _m(mid, s), f"hand_{side}", True))
            B.append((f"finger_{i}b_{side}", _m(mid, s), _m(tip, s), f"finger_{i}_{side}", True))
        mid_tip = (fs[1][3] + fs[2][3]) / 2
        B.append((f"talon_{side}", _m(mid_tip, s), _m(mid_tip + (0, 0, -0.05), s), f"hand_{side}", False))
        leg = f"leg_{side}"
        B.append((f"upper_{leg}", _m(J["upper"], s), _m(J["lower"], s), "pelvis", True))
        B.append((f"lower_{leg}", _m(J["lower"], s), _m(J["foot"], s), f"upper_{leg}", True))
        B.append((f"foot_{leg}", _m(J["foot"], s), _m(J["paw"], s), f"lower_{leg}", True))
        B.append((f"paw_{leg}", _m(J["paw"], s), _m(J["paw_end"], s), f"foot_{leg}", True))
    return B


def spec():
    out = dict(legs={}, arms={}, fingers={}, palm={})
    for side, s in (("r", 1), ("l", -1)):
        leg = f"leg_{side}"
        out["legs"][side] = (f"upper_{leg}", f"lower_{leg}", f"foot_{leg}", f"paw_{leg}")
        out["arms"][side] = (f"clav_{side}", f"arm_{side}", f"forearm_{side}", f"hand_{side}")
        out["fingers"][side] = [[f"finger_{i}_{side}", f"finger_{i}b_{side}"] for i in range(4)]
        out["palm"][side] = Vector((-0.75 * s, 0.1, -0.65)).normalized()
    # capsules the body rests on when it lies down (rig.Pose.rest_on_ground)
    out["core"] = ["pelvis", "spine", "spine2", "chest", "clav_r.tail", "clav_l.tail", "upper_leg_r.head", "upper_leg_l.head"]
    out["radius"] = dict(pelvis=0.12, spine=0.11, spine2=0.13, chest=0.165, neck=0.08, neck2=0.07, head=0.045, jaw=0.03, clav=0.075,
                         arm=0.06, forearm=0.05, hand=0.025, upper_leg=0.09, lower_leg=0.055, foot_leg=0.035, paw_leg=0.02)
    return out


def part_bone(part):
    """Which bone a hard part (kit.tag number) rides on."""
    if part in (1, 10, 11):
        return "head"
    if part == 2:
        return "jaw"
    if 20 <= part < 30:
        return f"finger_{part - 20}b_r"
    if 30 <= part < 40:
        return f"finger_{part - 30}b_l"
    if 40 <= part < 50:
        return "paw_leg_r"
    if 50 <= part < 60:
        return "paw_leg_l"
    raise KeyError(part)


def fix_weights(P, W):
    """Heat weights bleed across the mouth slot and between close fingers.
    The jaw line is known exactly, so it is set by rule: below the lip line
    the lower jaw follows `jaw`, above it the skull follows `head`, with a
    short blend at the hinge so the throat band stretches cleanly."""
    n = len(P)
    for k in ("head", "jaw"):
        W.setdefault(k, np.zeros(n))
    x, y, z = np.abs(P[:, 0]), P[:, 1], P[:, 2]
    lip = np.array([nb.mouth_z(v) for v in y])
    in_head = (y > 0.15) & (z > 1.755) & (x < 0.11)
    front = kit.ss((y - 0.165) / 0.05)                 # 0 at the hinge, 1 along the jaws
    lower = (z < lip).astype(float)
    skull_w = np.zeros(n)
    jaw_w = np.zeros(n)
    skull_w[in_head] = ((1.0 - lower) * front)[in_head]
    jaw_w[in_head] = (lower * front)[in_head]
    keep = 1.0 - (skull_w + jaw_w)
    for k in W:
        W[k] = W[k] * keep
    W["head"] = W["head"] + skull_w
    # behind the blend the old head/jaw mix remains; give the jaw's share under the lip to `jaw`
    W["jaw"] = W["jaw"] + jaw_w
    # the tongue bones only move the tongue (a hard part), never the body
    for k in ("tongue0", "tongue1", "tongue2"):
        if k in W:
            W["jaw"] = W["jaw"] + W[k]
            W[k] = np.zeros(n)


def bind_tongue(obj):
    """Smooth weights along the tongue's length."""
    P = kit.co(obj)
    ys = (0.215, 0.285, 0.35, 0.44)
    for i in range(3):
        vg = obj.vertex_groups.new(name=f"tongue{i}")
        mid = (ys[i] + ys[i + 1]) / 2
        half = (ys[i + 1] - ys[i]) / 2
        w = np.clip(1.0 - np.abs(P[:, 1] - mid) / (half * 2.0), 0.0, 1.0)
        if i == 0:
            w = np.where(P[:, 1] < mid, 1.0, w)
        if i == 2:
            w = np.where(P[:, 1] > mid, 1.0, w)
        for j in np.nonzero(w > 1e-3)[0]:
            vg.add([int(j)], float(w[j]), "REPLACE")
