"""The Suriel's skeleton (bestiary §3.5): the biped names of
docs/contracts/creature_motion.md with a second spine bone for the hunch,
long forearms, five two-bone fingers, the jaw, and chains of cloth bones in
the veil, the sleeves and the robe's torn hem. The cloth chains hang by
themselves (rig.Rig "cloth"); the clips only blow on them.

Sockets: ankle_l (the snare's loops), mouth (the voice), eyes (the swirl).
"""

import math

import numpy as np
from mathutils import Vector

import kit
import suriel_body as sb

J = sb.J


def _m(p, s):
    return (p[0] * s, p[1], p[2])


# ---- cloth: every strip of loose cloth, and the chain of bones it hangs on.
# name -> dict(parent, root (x, y, z), length, bones, hang, width, face, seed)

def strips():
    out = {}
    # the veil's two long ends, hanging by the cheeks to the chest
    for side, s in (("r", 1), ("l", -1)):
        out[f"veil_f{side}"] = dict(parent="head", root=(0.094 * s, 0.122, 2.04), length=0.46, bones=3, hang=0.92,
                                    width=(0.04, 0.075, 0.07, 0.06, 0.05, 0.03), face=(0.75 * s, 0.66, 0.0), seed=1 + s)
    # its two tails down the back, either side of the spine's knobs
    for i, s in enumerate((1, -1)):
        out[f"veil_b{i}"] = dict(parent="chest", root=(0.092 * s, -0.178, 1.85), length=0.5 - 0.08 * i, bones=3, hang=0.3,
                                 width=(0.085, 0.08, 0.07, 0.06, 0.04, 0.025), face=(0.4 * s, -1.0, 0.0), seed=5 + i, lean=(0.0, 0.1, -1.0))
    # the sleeves' rags, from the lower edge of each cuff
    f = J["forearm"]
    for side, s in (("r", 1), ("l", -1)):
        for i, dy in enumerate((-0.03, 0.012, 0.045)):
            out[f"sleeve_{side}{i}"] = dict(parent=f"arm_{side}", root=((f[0] + 0.03) * s, f[1] + dy, f[2] - 0.085), length=0.15 + 0.05 * ((i + 1) % 2),
                                            bones=2, hang=1.0, width=(0.05, 0.045, 0.035, 0.02), face=(0.55 * s, 0.2 * (i - 1), 0.0),
                                            seed=10 + i + s, chain=f"sleeve_{side}")
    # the hem: sixteen rags in two layers round the robe's edge, on eight chains
    n = 16
    for i in range(n):
        ang = 2 * math.pi * (i + 0.5 + 0.3 * math.sin(i * 2.4)) / n
        up = (0.0, 0.04, 0.02, 0.05, 0.03, 0.0, 0.05, 0.02)[i % 8]            # how far above the edge it starts
        k = 1.0 - 0.55 * up
        x, y = 0.25 * k * math.sin(ang), 0.186 * k * math.cos(ang)
        c = 2 * math.pi * (i // 2 + 0.5) / (n // 2)
        length = (0.2, 0.34, 0.13, 0.29, 0.17, 0.36, 0.22, 0.26)[(i * 3) % 8] + up
        w = (0.09, 0.07, 0.1, 0.08)[i % 4]
        length = min(length, sb.HEM_Z + 0.03 + up - 0.13)
        out[f"hem_{i}"] = dict(parent="lower_leg_r" if math.sin(c) > 0 else "lower_leg_l", root=(x, y, sb.HEM_Z + 0.03 + up), length=length,
                               bones=2, hang=0.9, width=(w, w * 0.95, w * 0.8, w * 0.55, w * 0.3), face=(math.sin(ang), math.cos(ang), 0.0),
                               seed=20 + i, chain=f"hem_{i // 2}", chain_root=(0.25 * math.sin(c), 0.186 * math.cos(c), sb.HEM_Z + 0.05))
    return out


def chains():
    """{chain name: dict(parent, root, length, bones, hang)}: several strips can share one chain."""
    out = {}
    for name, st in strips().items():
        c = st.get("chain", name)
        if c not in out:
            out[c] = dict(st)
        else:
            # a shared chain hangs from the middle of its strips and reaches as far as the longest
            out[c]["length"] = max(out[c]["length"], st["length"])
    for side, s in (("r", 1), ("l", -1)):
        f = J["forearm"]
        out[f"sleeve_{side}"]["root"] = ((f[0] + 0.03) * s, f[1] + 0.01, f[2] - 0.085)
    for c in out.values():
        if "chain_root" in c:
            c["length"] += c["root"][2] - c["chain_root"][2]
            c["root"] = c["chain_root"]
    return out


def chain_bones(name, c):
    return [f"{name}_{j}" for j in range(c["bones"])]


def bones():
    """[(name, head, tail, parent, deform)], parents first."""
    B = [
        ("root", (0, 0, 0), (0, 0.15, 0), None, False),
        ("body", tuple(J["pelvis"]), (0, 0.13, 1.20), "root", False),
        ("pelvis", tuple(J["pelvis"]), (0, -0.01, 1.08), "body", True),
        ("spine", (0, -0.025, 1.22), tuple(J["spine"]), "body", True),
        ("spine2", tuple(J["spine"]), tuple(J["spine2"]), "spine", True),
        ("chest", tuple(J["spine2"]), (0, -0.075, 1.85), "spine2", True),
        ("neck", tuple(J["neck"]), tuple(J["neck2"]), "chest", True),
        ("neck2", tuple(J["neck2"]), tuple(J["head"]), "neck", True),
        ("head", tuple(J["head"]), tuple(J["head_end"]), "neck2", True),
        ("jaw", tuple(J["jaw"]), tuple(J["jaw_end"]), "head", True),
        ("mouth", (0, 0.24, sb.LIP_Z), (0, 0.29, sb.LIP_Z), "head", False),
        ("eyes", (0, sb.EYE[1] + 0.02, sb.EYE[2]), (0, sb.EYE[1] + 0.07, sb.EYE[2]), "head", False),
    ]
    for side, s in (("r", 1), ("l", -1)):
        B.append((f"clav_{side}", _m(J["clav"], s), _m(J["arm"], s), "chest", True))
        B.append((f"arm_{side}", _m(J["arm"], s), _m(J["forearm"], s), f"clav_{side}", True))
        B.append((f"forearm_{side}", _m(J["forearm"], s), _m(J["hand"], s), f"arm_{side}", True))
        B.append((f"hand_{side}", _m(J["hand"], s), _m(J["knuckle"], s), f"forearm_{side}", True))
        for i, (root, mid, tip) in enumerate(sb.fingers()):
            B.append((f"finger_{i}_{side}", _m(root, s), _m(mid, s), f"hand_{side}", True))
            B.append((f"finger_{i}b_{side}", _m(mid, s), _m(tip, s), f"finger_{i}_{side}", True))
        leg = f"leg_{side}"
        B.append((f"upper_{leg}", _m(J["upper"], s), _m(J["lower"], s), "pelvis", True))
        B.append((f"lower_{leg}", _m(J["lower"], s), _m(J["foot"], s), f"upper_{leg}", True))
        B.append((f"foot_{leg}", _m(J["foot"], s), _m(J["paw"], s), f"lower_{leg}", True))
        B.append((f"paw_{leg}", _m(J["paw"], s), _m(J["paw_end"], s), f"foot_{leg}", True))
    B.append(("ankle_l", _m(J["foot"] + (0, 0, 0.03), -1), _m(J["foot"] + (0, 0.05, 0.03), -1), "lower_leg_l", False))
    for name, c in chains().items():
        lean = Vector(c.get("lean", (0.0, 0.0, -1.0))).normalized()
        step = c["length"] / c["bones"]
        p = Vector(c["root"])
        par = c["parent"]
        for b in chain_bones(name, c):
            B.append((b, tuple(p), tuple(p + lean * step), par, True))
            p = p + lean * step
            par = b
    return B


def spec():
    out = dict(legs={}, arms={}, fingers={}, palm={})
    for side, s in (("r", 1), ("l", -1)):
        leg = f"leg_{side}"
        out["legs"][side] = (f"upper_{leg}", f"lower_{leg}", f"foot_{leg}", f"paw_{leg}")
        out["arms"][side] = (f"clav_{side}", f"arm_{side}", f"forearm_{side}", f"hand_{side}")
        out["fingers"][side] = [[f"finger_{i}_{side}", f"finger_{i}b_{side}"] for i in range(5)]
        out["palm"][side] = Vector((-0.75 * s, 0.1, -0.65)).normalized()
    out["cloth"] = [dict(bones=chain_bones(n, c), hang=c["hang"]) for n, c in chains().items()]
    # what it rests on when it sits or lies (rig.Pose.rest_on_ground)
    out["core"] = ["pelvis", "spine", "upper_leg_r.head", "upper_leg_l.head"]
    out["radius"] = dict(pelvis=0.105, spine=0.09, spine2=0.09, chest=0.1, upper_leg=0.09)
    return out


def part_bone(part):
    """Which bone a hard part (kit.tag number) rides on."""
    if part in (1, 10):
        return "head"
    if part == 2:
        return "jaw"
    if 20 <= part < 30:
        return f"finger_{part - 20}b_r"
    if 30 <= part < 40:
        return f"finger_{part - 30}b_l"
    raise KeyError(part)


def fix_weights(P, W):
    """The skull and the cap of the veil on it follow `head` alone, the lower
    jaw follows `jaw`, and the cloth bones move only their own strips."""
    n = len(P)
    for k in ("head", "jaw"):
        W.setdefault(k, np.zeros(n))
    for name, c in chains().items():
        par = c["parent"]
        for b in chain_bones(name, c):
            if b in W:
                W.setdefault(par, np.zeros(n))
                W[par] = W[par] + W[b]
                W[b] = np.zeros(n)
    x, y, z = np.abs(P[:, 0]), P[:, 1], P[:, 2]
    in_head = (y > 0.118) & (x < 0.075) & (z > 1.955) & (z < 2.04)
    front = kit.ss((y - 0.118) / 0.035)
    jaw_w = np.where(in_head & (z < sb.LIP_Z), front, 0.0)
    skull_w = np.maximum(kit.ss((z - 2.035) / 0.03) * (y > -0.07), np.where(in_head & (z >= sb.LIP_Z), front, 0.0))
    skull_w = np.clip(skull_w, 0.0, 1.0 - jaw_w)
    keep = 1.0 - (skull_w + jaw_w)
    for k in W:
        W[k] = W[k] * keep
    W["head"] = W["head"] + skull_w
    W["jaw"] = W["jaw"] + jaw_w
