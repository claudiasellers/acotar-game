"""The gloamer's skeleton (bestiary §16.5): the biped names of
docs/contracts/creature_motion.md with long arms, a jaw, eyelids, three
three-bone fingers and a thumb, the `throat` socket, and a cord of stolen
trinkets that swings from the neck."""

import numpy as np
from mathutils import Vector

import gloamer_body as gb
import kit

J = gb.J
TRINKETS = 3
NAPE = (0.0, -0.09, 1.4)


def _m(p, s):
    return (p[0] * s, p[1], p[2])


def bones(cord=None):
    """[(name, head, tail, parent, deform)], parents first. `cord` is
    gloamer.cord_layout(): dict(bottom=point, hooks=[3 points])."""
    B = [
        ("root", (0, 0, 0), (0, 0.12, 0), None, False),
        ("body", tuple(J["pelvis"]), (0, 0.1, 0.74), "root", False),
        ("pelvis", tuple(J["pelvis"]), (0, -0.015, 0.65), "body", True),
        ("spine", (0, -0.025, 0.76), tuple(J["spine"]), "body", True),
        ("spine2", tuple(J["spine"]), tuple(J["spine2"]), "spine", True),
        ("chest", tuple(J["spine2"]), tuple(J["chest_end"]), "spine2", True),
        ("neck", tuple(J["neck"]), tuple(J["head"]), "chest", True),
        ("head", tuple(J["head"]), tuple(J["head_end"]), "neck", True),
        ("jaw", tuple(J["jaw"]), tuple(J["jaw_end"]), "head", True),
        # sockets
        ("throat", tuple(gb.THROAT), tuple(gb.THROAT + (0, 0.05, 0)), "neck", False),
        ("mouth", (0, 0.27, 1.445), (0, 0.32, 1.445), "head", False),
    ]
    for side, s in (("r", 1), ("l", -1)):
        e = gb.EYE * (s, 1, 1)
        B.append((f"eyelid_{side}", tuple(e), tuple(e + (0, 0.03, 0)), "head", True))
    for side, s in (("r", 1), ("l", -1)):
        B.append((f"clav_{side}", _m(J["clav"], s), _m(J["arm"], s), "chest", True))
        B.append((f"arm_{side}", _m(J["arm"], s), _m(J["forearm"], s), f"clav_{side}", True))
        B.append((f"forearm_{side}", _m(J["forearm"], s), _m(J["hand"], s), f"arm_{side}", True))
        B.append((f"hand_{side}", _m(J["hand"], s), _m(J["knuckle"], s), f"forearm_{side}", True))
        th = gb.thumb()
        for n, suf in enumerate(("", "b", "c")):
            B.append((f"thumb{suf}_{side}", _m(th[n], s), _m(th[n + 1], s), f"hand_{side}" if n == 0 else f"thumb{('', 'b')[n - 1]}_{side}", True))
        for i, pts in enumerate(gb.fingers()):
            for n, suf in enumerate(("", "b", "c")):
                B.append((f"finger_{i}{suf}_{side}", _m(pts[n], s), _m(pts[n + 1], s),
                          f"hand_{side}" if n == 0 else f"finger_{i}{('', 'b')[n - 1]}_{side}", True))
        leg = f"leg_{side}"
        B.append((f"upper_{leg}", _m(J["upper"], s), _m(J["lower"], s), "pelvis", True))
        B.append((f"lower_{leg}", _m(J["lower"], s), _m(J["foot"], s), f"upper_{leg}", True))
        B.append((f"foot_{leg}", _m(J["foot"], s), _m(J["paw"], s), f"lower_{leg}", True))
        B.append((f"paw_{leg}", _m(J["paw"], s), _m(J["paw_end"], s), f"foot_{leg}", True))
    if cord is not None:
        B.append(("cord", NAPE, tuple(cord["bottom"]), "chest", True))
        for i, h in enumerate(cord["hooks"]):
            B.append((f"trinket_{i + 1}", tuple(h), (h[0], h[1], h[2] - 0.06), "cord", True))
    return B


def spec():
    out = dict(legs={}, arms={}, fingers={}, palm={})
    for side, s in (("r", 1), ("l", -1)):
        leg = f"leg_{side}"
        out["legs"][side] = (f"upper_{leg}", f"lower_{leg}", f"foot_{leg}", f"paw_{leg}")
        out["arms"][side] = (f"clav_{side}", f"arm_{side}", f"forearm_{side}", f"hand_{side}")
        out["fingers"][side] = ([[f"thumb_{side}", f"thumbb_{side}", f"thumbc_{side}"]]
                                + [[f"finger_{i}_{side}", f"finger_{i}b_{side}", f"finger_{i}c_{side}"] for i in range(3)])
        out["palm"][side] = Vector(gb.PALM * (s, 1, 1)).normalized()
    out["cloth"] = [dict(bones=["cord"], hang=0.9)] + [dict(bones=[f"trinket_{i + 1}"], hang=1.0) for i in range(TRINKETS)]
    # capsules the body rests on when it sits or lies (rig.Pose.rest_on_ground)
    out["core"] = ["pelvis", "spine", "spine2", "chest", "clav_r.tail", "clav_l.tail", "upper_leg_r.head", "upper_leg_l.head", "head"]
    out["radius"] = dict(pelvis=0.13, spine=0.13, spine2=0.16, chest=0.17, clav=0.08, upper_leg=0.085, head=0.1)
    return out


def part_bone(part):
    """Which bone a hard part (kit.tag number) rides on."""
    if part in (1, 10, 20):
        return "head"
    if part == 2:
        return "jaw"
    if part in (11, 12):
        return "eyelid_r" if part == 11 else "eyelid_l"
    if 71 <= part < 71 + TRINKETS:
        return f"trinket_{part - 70}"
    raise KeyError(part)


def fix_weights(P, W):
    """What heat weights get wrong or cannot know. The jaw line is set by rule
    (below the lip the lower jaw follows `jaw`, above it the skull follows
    `head`), and the cord, trinket and lid bones move only their own hard
    parts."""
    n = len(P)
    for k in ("head", "jaw", "chest"):
        W.setdefault(k, np.zeros(n))
    parents = dict(cord="chest", eyelid_r="head", eyelid_l="head")
    parents.update({f"trinket_{i + 1}": "chest" for i in range(TRINKETS)})
    for k, par in parents.items():
        if k in W:
            W.setdefault(par, np.zeros(n))
            W[par] = W[par] + W[k]
            W[k] = np.zeros(n)
    x, y, z = np.abs(P[:, 0]), P[:, 1], P[:, 2]
    lip = np.array([gb.mouth_z(v) for v in y])
    in_head = (y > 0.115) & (z > 1.395) & (z < 1.5) & (x < 0.13)
    front = kit.ss((y - 0.12) / 0.035)                # 0 at the hinge, 1 along the jaws
    lower = (z < lip).astype(float)
    skull_w = np.where(in_head, (1.0 - lower) * front, 0.0)
    jaw_w = np.where(in_head, lower * front, 0.0)
    # the whole skull above the mouth is the head's alone
    skull_w = np.maximum(skull_w, kit.ss((z - 1.475) / 0.02) * kit.ss((y - 0.06) / 0.04) * (x < 0.14))
    skull_w = np.clip(skull_w, 0.0, 1.0 - jaw_w)
    keep = 1.0 - (skull_w + jaw_w)
    for k in W:
        W[k] = W[k] * keep
    W["head"] = W["head"] + skull_w
    W["jaw"] = W["jaw"] + jaw_w
