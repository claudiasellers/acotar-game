"""The brackenhound's skeleton (bestiary §17.5): the quadruped names of
docs/contracts/creature_motion.md (`hips`, `spine`, `ribs`, `chest`, `neck`,
`head`, `jaw`, `tail0..3`, and per leg `upper_`, `lower_`, `paw_<leg>` for
`fl_l`, `fl_r`, `hl_l`, `hl_r`) with a three-bone neck (`neck`, `neck2`,
`neck3`), a `foot_<leg>` bone between the wrist or hock and the paw,
`frond_0..5` (0 and 1 are the fern-frond ears, 2..5 run down the spine and
lift the bark of the back with them), the `skull_knot` and `mouth` sockets and
`keel`, a helper under the chest that the solver lies the body down on."""

import numpy as np

import brackenhound_body as bb
import kit

J = bb.J
LEGS = ("fl_l", "fl_r", "hl_l", "hl_r")
FRONDS = {            # bone -> (parent, head, tail)
    "frond_0": ("head", (0.055, 0.94, 1.18), (0.13, 0.84, 1.27)),
    "frond_1": ("head", (-0.055, 0.94, 1.18), (-0.13, 0.84, 1.27)),
    "frond_2": ("chest", (0, 0.36, 1.03), (0, 0.27, 1.17)),
    "frond_3": ("ribs", (0, 0.08, 0.99), (0, -0.01, 1.13)),
    "frond_4": ("spine", (0, -0.22, 0.975), (0, -0.31, 1.11)),
    "frond_5": ("hips", (0, -0.5, 0.975), (0, -0.59, 1.11)),
}


def _m(p, s):
    return (p[0] * s, p[1], p[2])


def bones():
    """[(name, head, tail, parent, deform)], parents first."""
    B = [
        ("root", (0, 0, 0), (0, 0.2, 0), None, False),
        ("body", (0, -0.08, 0.9), (0, 0.12, 0.9), "root", False),
        ("hips", tuple(J["hips"]), tuple(J["spine"]), "body", True),
        ("spine", tuple(J["spine"]), tuple(J["ribs"]), "hips", True),
        ("ribs", tuple(J["ribs"]), tuple(J["chest"]), "spine", True),
        ("chest", tuple(J["chest"]), tuple(J["chest_end"]), "ribs", True),
        ("neck", tuple(J["chest_end"]), tuple(J["neck2"]), "chest", True),
        ("neck2", tuple(J["neck2"]), tuple(J["neck3"]), "neck", True),
        ("neck3", tuple(J["neck3"]), tuple(J["head"]), "neck2", True),
        ("head", tuple(J["head"]), tuple(J["head_end"]), "neck3", True),
        ("jaw", tuple(J["jaw"]), tuple(J["jaw_end"]), "head", True),
        ("skull_knot", tuple(bb.KNOT + (0, 0, 0.02)), tuple(bb.KNOT + (0, 0, 0.07)), "head", False),
        ("mouth", (0, 1.33, 1.028), (0, 1.38, 1.028), "head", False),
        ("keel", (0, 0.16, 0.6), (0, 0.38, 0.66), "chest", False),     # the breastbone, for lying on it
    ]
    tl = J["tail"]
    for i in range(4):
        B.append((f"tail{i}", tuple(tl[i]), tuple(tl[i + 1]), "hips" if i == 0 else f"tail{i - 1}", True))
    for leg in LEGS:
        k = "f" if leg[0] == "f" else "h"
        s = 1 if leg.endswith("_r") else -1
        par = "chest" if k == "f" else "hips"
        B.append((f"upper_{leg}", _m(J[f"{k}_upper"], s), _m(J[f"{k}_lower"], s), par, True))
        B.append((f"lower_{leg}", _m(J[f"{k}_lower"], s), _m(J[f"{k}_foot"], s), f"upper_{leg}", True))
        B.append((f"foot_{leg}", _m(J[f"{k}_foot"], s), _m(J[f"{k}_paw"], s), f"lower_{leg}", True))
        B.append((f"paw_{leg}", _m(J[f"{k}_paw"], s), _m(J[f"{k}_paw_end"], s), f"foot_{leg}", True))
    for name, (par, head, tail) in FRONDS.items():
        B.append((name, head, tail, par, True))
    return B


def spec():
    return dict(legs={leg: (f"upper_{leg}", f"lower_{leg}", f"foot_{leg}", f"paw_{leg}") for leg in LEGS}, pole_space="body",
                core=["hips.head", "spine.head", "ribs.head", "chest", "keel", "neck2", "head", "jaw.tail", "tail2"],
                radius={"hips.head": 0.15, "spine.head": 0.11, "ribs.head": 0.17, "chest": 0.18, "keel": 0.08, "neck2": 0.07,
                        "head": 0.05, "jaw.tail": 0.02, "tail2": 0.03})


def part_bone(part):
    """Which bone a hard part (kit.tag number) rides on."""
    if part in (1, 10):
        return "head"
    if part == 2:
        return "jaw"
    if 60 <= part < 66:
        return f"frond_{part - 60}"
    raise KeyError(part)


def fix_weights(P, W):
    """What heat weights get wrong or cannot know. The jaw line is set by rule
    (below the lip the lower jaw follows `jaw`, above it the skull follows
    `head`); the ear fronds' bones move only the fronds; and the bark along the
    top of the back gives half its weight to the spine fronds' bones, so the
    back splits open when they lift."""
    n = len(P)
    for k in ("head", "jaw"):
        W.setdefault(k, np.zeros(n))
    for k, (par, head, tail) in FRONDS.items():
        if k in W:
            W.setdefault(par, np.zeros(n))
            W[par] = W[par] + W[k]
            W[k] = np.zeros(n)
        else:
            W[k] = np.zeros(n)
    x, y, z = np.abs(P[:, 0]), P[:, 1], P[:, 2]
    lip = np.array([bb.mouth_z(v) for v in y])
    in_head = (y > 0.96) & (z > 0.97) & (x < 0.08)
    front = kit.ss((y - 0.98) / 0.05)                  # 0 at the hinge, 1 along the jaws
    lower = (z < lip).astype(float)
    skull_w = np.where(in_head, (1.0 - lower) * front, 0.0)
    jaw_w = np.where(in_head, lower * front, 0.0)
    keep = 1.0 - (skull_w + jaw_w)
    for k in W:
        W[k] = W[k] * keep
    W["head"] = W["head"] + skull_w
    W["jaw"] = W["jaw"] + jaw_w
    # the back's bark
    for k in ("frond_2", "frond_3", "frond_4", "frond_5"):
        head = np.array(FRONDS[k][1])
        d = np.linalg.norm((P - head) / np.array((0.11, 0.17, 0.09)), axis=1)
        w = 0.5 * kit.ss((1.0 - d) / 0.5)
        for j in W:
            if j != k:
                W[j] = W[j] * (1.0 - w)
        W[k] = W[k] + w
