"""The Hollow Hob's skeleton (bestiary §10.5): a heavy biped on the names of
docs/contracts/creature_motion.md, with one short neck bone, a jaw, a brow,
real eyelids, three-bone fingers and a thumb, bones under the moss mantle (it
lifts when the Hob breathes), the necklace and one bone per charm."""

import numpy as np
from mathutils import Vector

import hob_body as hb
import kit

J = hb.J
MOSS = {            # bone -> (parent, head, tail): under the cushions of the mantle
    "moss_0": ("chest", (0, -0.6, 3.25), (0, -0.92, 3.4)),
    "moss_1": ("chest", (0.5, -0.55, 3.35), (0.72, -0.8, 3.6)),
    "moss_2": ("chest", (-0.5, -0.55, 3.35), (-0.72, -0.8, 3.6)),
    "moss_3": ("spine2", (0, -0.6, 2.75), (0, -0.92, 2.7)),
    "moss_4": ("clav_r", (0.85, -0.15, 3.7), (1.0, -0.2, 4.0)),
    "moss_5": ("clav_l", (-0.85, -0.15, 3.7), (-1.0, -0.2, 4.0)),
    "moss_6": ("head", (0, 0.25, 3.9), (0, 0.22, 4.05)),
}
CHARMS = 8
NAPE = (0.0, -0.22, 3.66)


def _m(p, s):
    return (p[0] * s, p[1], p[2])


def bones(cord=None):
    """[(name, head, tail, parent, deform)], parents first. `cord` is
    hob.necklace()'s layout: dict(bottom=point, hooks=[8 points])."""
    B = [
        ("root", (0, 0, 0), (0, 0.3, 0), None, False),
        ("body", tuple(J["pelvis"]), (0, 0.3, 2.0), "root", False),
        ("pelvis", tuple(J["pelvis"]), (0, -0.04, 1.75), "body", True),
        ("spine", (0, -0.06, 2.05), tuple(J["spine"]), "body", True),
        ("spine2", tuple(J["spine"]), tuple(J["spine2"]), "spine", True),
        ("chest", tuple(J["spine2"]), tuple(J["chest_end"]), "spine2", True),
        ("neck", tuple(J["neck"]), tuple(J["head"]), "chest", True),
        ("head", tuple(J["head"]), tuple(J["head_end"]), "neck", True),
        ("jaw", tuple(J["jaw"]), tuple(J["jaw_end"]), "head", True),
        ("brow", (0, 0.5, 3.815), (0, 0.62, 3.815), "head", True),
        ("mouth", (0, 0.68, 3.59), (0, 0.78, 3.59), "head", False),
    ]
    for side, s in (("r", 1), ("l", -1)):
        e = hb.EYE * (s, 1, 1)
        B.append((f"eyelid_{side}", tuple(e), tuple(e + (0, 0.07, 0)), "head", True))
    for side, s in (("r", 1), ("l", -1)):
        B.append((f"clav_{side}", _m(J["clav"], s), _m(J["arm"], s), "chest", True))
        B.append((f"arm_{side}", _m(J["arm"], s), _m(J["forearm"], s), f"clav_{side}", True))
        B.append((f"forearm_{side}", _m(J["forearm"], s), _m(J["hand"], s), f"arm_{side}", True))
        B.append((f"hand_{side}", _m(J["hand"], s), _m(J["knuckle"], s), f"forearm_{side}", True))
        th = hb.thumb()
        for n, suf in enumerate(("", "b", "c")):
            B.append((f"thumb{suf}_{side}", _m(th[n], s), _m(th[n + 1], s), f"hand_{side}" if n == 0 else f"thumb{('', 'b')[n - 1]}_{side}", True))
        for i, pts in enumerate(hb.fingers()):
            for n, suf in enumerate(("", "b", "c")):
                B.append((f"finger_{i}{suf}_{side}", _m(pts[n], s), _m(pts[n + 1], s),
                          f"hand_{side}" if n == 0 else f"finger_{i}{('', 'b')[n - 1]}_{side}", True))
        leg = f"leg_{side}"
        B.append((f"upper_{leg}", _m(J["upper"], s), _m(J["lower"], s), "pelvis", True))
        B.append((f"lower_{leg}", _m(J["lower"], s), _m(J["foot"], s), f"upper_{leg}", True))
        B.append((f"foot_{leg}", _m(J["foot"], s), _m(J["paw"], s), f"lower_{leg}", True))
        B.append((f"paw_{leg}", _m(J["paw"], s), _m(J["paw_end"], s), f"foot_{leg}", True))
        # socket: the stomp's dust
        B.append((f"foot_{side}", _m(J["paw"] * (1, 1, 0), s), _m(J["paw"] * (1, 1, 0) + (0, 0.1, 0), s), f"paw_{leg}", False))
    for name, (par, head, tail) in MOSS.items():
        B.append((name, head, tail, par, True))
    if cord is not None:
        B.append(("necklace", NAPE, tuple(cord["bottom"]), "chest", True))
        for i, h in enumerate(cord["hooks"]):
            B.append((f"charm_{i + 1}", tuple(h), (h[0], h[1], h[2] - 0.14), "necklace", True))
        h = cord["hooks"][0]
        B.append(("charm", tuple(h), (h[0], h[1], h[2] - 0.14), "necklace", False))      # the weak spot: where charm_1 hangs
    return B


def spec():
    out = dict(legs={}, arms={}, fingers={}, palm={})
    for side, s in (("r", 1), ("l", -1)):
        leg = f"leg_{side}"
        out["legs"][side] = (f"upper_{leg}", f"lower_{leg}", f"foot_{leg}", f"paw_{leg}")
        out["arms"][side] = (f"clav_{side}", f"arm_{side}", f"forearm_{side}", f"hand_{side}")
        out["fingers"][side] = ([[f"thumb_{side}", f"thumbb_{side}", f"thumbc_{side}"]]
                                + [[f"finger_{i}_{side}", f"finger_{i}b_{side}", f"finger_{i}c_{side}"] for i in range(4)])
        out["palm"][side] = Vector(hb.PALM * (s, 1, 1)).normalized()
    out["cloth"] = [dict(bones=["necklace"], hang=0.9)] + [dict(bones=[f"charm_{i + 1}"], hang=1.0) for i in range(CHARMS)] \
        + [dict(bones=["charm"], hang=1.0)]
    # capsules the body rests on when it sits or lies (rig.Pose.rest_on_ground)
    out["core"] = ["pelvis", "spine", "spine2", "chest", "clav_r.tail", "clav_l.tail", "upper_leg_r.head", "upper_leg_l.head", "head"]
    out["radius"] = dict(pelvis=0.5, spine=0.6, spine2=0.62, chest=0.62, clav=0.36, upper_leg=0.36, head=0.2)
    return out


def part_bone(part):
    """Which bone a hard part (kit.tag number) rides on."""
    if part in (1, 10):
        return "head"
    if part == 2:
        return "jaw"
    if part in (11, 12):
        return "eyelid_r" if part == 11 else "eyelid_l"
    if 61 <= part < 61 + len(MOSS):
        return f"moss_{part - 61}"
    if 71 <= part < 71 + CHARMS:
        return f"charm_{part - 70}"
    raise KeyError(part)


def moss_bone_near(p):
    """Index of the mantle bone nearest a point."""
    best, bi = 1e9, 0
    for i, (par, head, tail) in enumerate(MOSS.values()):
        d = float(np.linalg.norm(np.asarray(p) - np.asarray(tail)))
        if d < best:
            best, bi = d, i
    return bi


def fix_weights(P, W):
    """What heat weights get wrong or cannot know. The jaw line is set by rule
    (below the lip the lower jaw follows `jaw`, above it the skull follows
    `head`); the brow ridge follows `brow`; the skin under the moss gives a
    share to the mantle bones; and the necklace, charm and lid bones move only
    their own hard parts."""
    n = len(P)
    for k in ("head", "jaw", "brow", "chest"):
        W.setdefault(k, np.zeros(n))
    parents = dict(necklace="chest", eyelid_r="head", eyelid_l="head", brow="head")
    parents.update({f"charm_{i + 1}": "chest" for i in range(CHARMS)})
    parents.update({k: v[0] for k, v in MOSS.items()})
    for k, par in parents.items():
        if k in W:
            W.setdefault(par, np.zeros(n))
            W[par] = W[par] + W[k]
            W[k] = np.zeros(n)
    x, y, z = np.abs(P[:, 0]), P[:, 1], P[:, 2]
    lip = np.array([hb.mouth_z(v) for v in y])
    in_head = (y > 0.36) & (z > 3.42) & (z < 3.72) & (x < 0.3)
    front = kit.ss((y - 0.38) / 0.1)                  # 0 at the hinge, 1 along the jaws
    lower = (z < lip).astype(float)
    skull_w = np.where(in_head, (1.0 - lower) * front, 0.0)
    jaw_w = np.where(in_head, lower * front, 0.0)
    # the whole skull above the mouth is the head's alone
    skull_w = np.maximum(skull_w, kit.ss((z - 3.66) / 0.06) * kit.ss((y - 0.2) / 0.1) * (x < 0.32))
    skull_w = np.clip(skull_w, 0.0, 1.0 - jaw_w)
    keep = 1.0 - (skull_w + jaw_w)
    for k in W:
        W[k] = W[k] * keep
    W["head"] = W["head"] + skull_w
    W["jaw"] = W["jaw"] + jaw_w
    # the brow ridge
    bd = kit.path_dist(np.stack([x, y, z], axis=1), [(0.0, 0.6, 3.815), (0.1, 0.6, 3.822), (0.2, 0.55, 3.81)])
    bw = kit.ss((0.085 - bd) / 0.05) * 0.85
    for k in W:
        if k != "brow":
            W[k] = W[k] * (1.0 - bw)
    W["brow"] = W["brow"] + bw
    # the mantle: each cushion's skin follows the nearest mantle bone by 0.65
    moss = hb.moss_near(P) * 0.65
    tails = np.array([v[2] for v in MOSS.values()])
    d = np.linalg.norm(P[:, None, :] - tails[None, :, :], axis=2)
    near = np.exp(-((d - d.min(axis=1, keepdims=True)) / 0.25) ** 2)
    near /= near.sum(axis=1, keepdims=True)
    for k in W:
        W[k] = W[k] * (1.0 - moss)
    for i, k in enumerate(MOSS):
        W[k] = W.get(k, np.zeros(n)) + moss * near[:, i]
