"""The brackenhound's clips (bestiary §17.4): names, lengths and wind-up times
are the guide's. Each clip is a table of key postures (biped.Keys) with a
little motion on top where a formula says it better (breath, a shake).

It is dumb, loud and stiff: wood that moves. It holds still longer than an
animal would, then goes all at once; nothing about it is supple except the
long neck. The gaits start on the left hind paw (creature_motion.md).
"""

import math
import os

from mathutils import Vector

import brackenhound_body as bb
import rig
from biped import Keys
from rig import pulse, ring, seg, smooth, wave

LEGS = ("fl_l", "fl_r", "hl_l", "hl_r")
SPINE = ("spine", "ribs", "chest")
NECK = ("neck", "neck2", "neck3")
TAIL = ("tail0", "tail1", "tail2", "tail3")
ELBOW = (0.0, -1.0, 0.15)          # the way a front leg bends
STIFLE = (0.0, 1.0, 0.2)           # and a hind one


def _heel(k):
    d = bb.J[f"{k}_foot"] - bb.J[f"{k}_paw"]
    return math.degrees(math.asin(d[2] / math.hypot(d[1], d[2])))


HEEL_F, HEEL_H = _heel("f"), _heel("h")


def sym(prefix, pair, v):
    """One value for a pair of legs ("fl" or "hl"), given for the right one."""
    if isinstance(v, tuple):
        return {f"{prefix}_{pair}_r": v, f"{prefix}_{pair}_l": (-v[0], v[1], v[2])}
    return {f"{prefix}_{pair}_r": v, f"{prefix}_{pair}_l": v}


# x, y, z: the body's shift. pitch (+ nose down), yaw (+ nose left), roll (+ onto its right side).
# arch (+ hunched), swing (the spine bent sideways, + head end to the left), twist (chest rolled on the hips).
# neck_*, head_*: + pitch is down. reach stretches the neck. tail_p lifts the tail, tail_curl curls it up.
# fronds 0..1 lifts the spine's fronds and the bark with them; ears -1 flat .. +1 lifted.
# per leg: f_ the planted paw's shift, fc_ the same carried by the body, fmix_ 0 planted .. 1 carried.
BASE = dict(x=0.0, y=0.0, z=0.0, pitch=0.0, yaw=0.0, roll=0.0, arch=0.0, swing=0.0, twist=0.0,
            neck_p=0.0, neck_yaw=0.0, neck_roll=0.0, head_p=0.0, head_yaw=0.0, head_roll=0.0, reach=0.0, jaw=0.0,
            tail_p=0.0, tail_curl=0.0, tail_yaw=0.0, fronds=0.0, ears=0.0, ground=0.0)
STAND = dict(neck_p=30.0, head_p=-16.0)       # how it carries its head: forward, hardly above its back
for _leg in LEGS:
    BASE.update({f"f_{_leg}": (0.0, 0.0, 0.0), f"fc_{_leg}": (0.0, 0.0, 0.0), f"fmix_{_leg}": 0.0,
                 f"heel_{_leg}": HEEL_F if _leg[0] == "f" else HEEL_H, f"toe_{_leg}": 0.0, f"knee_{_leg}": None})

# Nose to the ground.
SNIFF = dict(BASE, pitch=11.0, z=-0.09, neck_p=78.0, head_p=16.0, tail_p=6.0)
# Head up, listening.
ALERT = dict(BASE, neck_p=14.0, head_p=-10.0, ears=1.0, fronds=0.35, tail_p=22.0, z=0.01)
# Lying like a log: on its breastbone, legs folded under, the neck and the long skull flat along the ground.
LIE = dict(BASE, ground=1.0, neck_p=60.0, head_p=-50.0, tail_p=8.0, tail_curl=6.0, tail_yaw=40.0, ears=-0.6,
           **sym("fmix", "fl", 1.0), **sym("fmix", "hl", 1.0), **sym("fc", "fl", (0.0, 0.3, 0.6)), **sym("fc", "hl", (0.07, 0.19, 0.6)),
           **sym("heel", "fl", 6.0), **sym("heel", "hl", 8.0), **sym("knee", "fl", (0.5, -1.0, 0.3)), **sym("knee", "hl", (1.0, 0.6, 0.45)))
# Asleep: the same heap, the head brought round to its flank.
SLEEP = dict(LIE, neck_p=40.0, neck_yaw=-70.0, head_p=-24.0, head_roll=-20.0, swing=-14.0, roll=6.0, jaw=3.0, ears=-1.0)
# Coiled to spring.
CROUCH = dict(BASE, z=-0.27, y=-0.08, pitch=5.0, arch=12.0, neck_p=26.0, head_p=-22.0, jaw=10.0, fronds=1.0, ears=-1.0, tail_p=-8.0,
              **sym("f", "fl", (0.03, 0.1, 0.0)), **sym("f", "hl", (0.04, 0.1, 0.0)))


def lying(side):
    """Dead on one flank (the creature's right for "r"), legs out stiff as branches."""
    d = dict(BASE, roll=86.0, x=0.3, ground=1.0, neck_p=14.0, neck_yaw=-15.0, head_p=-10.0, head_roll=6.0, jaw=24.0, fronds=-0.5, ears=-1.0,
             tail_p=10.0, tail_yaw=-20.0, arch=-6.0,
             **sym("fmix", "fl", 1.0), **sym("fmix", "hl", 1.0),
             fc_fl_r=(0.0, 0.16, 0.16), fc_hl_r=(0.0, 0.2, 0.14), fc_fl_l=(0.36, -0.06, 0.1), fc_hl_l=(0.34, 0.12, 0.16),
             heel_fl_r=50.0, heel_fl_l=58.0, heel_hl_r=40.0, heel_hl_l=52.0)
    return d if side == "r" else mirrored(d)


def mirrored(d):
    """The same posture with left and right swapped."""
    out = {}
    for k, v in d.items():
        k2 = k[:-2] + ("_l" if k.endswith("_r") else "_r") if k.endswith(("_r", "_l")) else k
        if isinstance(v, (tuple, list)):
            v = (-v[0], v[1], v[2])
        if k in ("x", "yaw", "roll", "swing", "twist", "neck_yaw", "neck_roll", "head_yaw", "head_roll", "tail_yaw"):
            v = -v
        out[k2] = v
    return out


NECK_SET = 18.0     # the postures below were written for a neck carried this much higher than it is modelled


def pose(r, d, feet=True):
    p = rig.Pose()
    arch, swing = d["arch"], d["swing"]
    p.body(loc=(d["x"], d["y"], d["z"]), pitch=d["pitch"] - 0.5 * arch, yaw=d["yaw"] - 0.5 * swing, roll=d["roll"])
    p.spine(SPINE, pitch=arch, yaw=swing)
    if d["twist"]:
        p.turn("chest", roll=d["twist"])
    p.spine(NECK, pitch=d["neck_p"] - NECK_SET - 0.5 * arch, yaw=d["neck_yaw"], roll=d["neck_roll"])
    p.turn("head", pitch=d["head_p"] + NECK_SET, yaw=d["head_yaw"], roll=d["head_roll"])
    if d["reach"]:
        for b in ("neck2", "neck3", "head"):
            par = r.parent[b]
            p.stretch(b, (r.tail[par] - r.head[par]) * (0.14 * d["reach"]))
    if d["jaw"]:
        p.turn("jaw", pitch=d["jaw"])
    p.turn("tail0", pitch=d["tail_p"], yaw=d["tail_yaw"] * 0.4)
    for b in TAIL[1:]:
        p.turn(b, pitch=d["tail_curl"], yaw=d["tail_yaw"] * 0.2)
    for i in (0, 1):
        if d["ears"]:
            p.turn(f"frond_{i}", pitch=34.0 * d["ears"], roll=(8.0 if i == 0 else -8.0) * d["ears"])
    for i in (2, 3, 4, 5):
        if d["fronds"]:
            p.turn(f"frond_{i}", pitch=36.0 * d["fronds"])
            p.stretch(f"frond_{i}", (0.0, 0.0, 0.022 * max(d["fronds"], 0.0)))
    if feet:
        for leg in LEGS:
            front = leg[0] == "f"
            rest = r.rest_ball(leg)
            fm = d[f"fmix_{leg}"]
            p.foot(leg, ball=rest + Vector(d[f"f_{leg}"]) if fm < 1.0 else None,
                   carried=rest + Vector(d[f"fc_{leg}"]) if fm > 0.0 else None, mix=fm, space="chest" if front else "hips",
                   heel=d[f"heel_{leg}"], toe=d[f"toe_{leg}"], yaw=0.0, knee=d[f"knee_{leg}"] or (ELBOW if front else STIFLE))
    if d["ground"]:
        p.rest_on_ground(d["ground"])
    return p


def keyclip(r, name, base, keys, loop=False, more=None, contact=None, travel=None, breath=0.0, period=3.0):
    K = Keys(base, keys)
    T = K.duration / max(round(K.duration / period), 1)

    def fn(t):
        d = K(t)
        if breath:
            b = wave(t, T, -0.25) * 0.5 + 0.5                 # 0 empty, 1 full
            d["arch"] += 1.6 * breath * b
            d["z"] += 0.004 * breath * b
        if more is not None:
            more(t, d)
        return pose(r, d)
    r.clip(name, K.duration, fn, loop=loop, contact=contact, travel=travel)


def step(d, t, leg, t0, t1, to=(0.0, 0.0, 0.0), frm=(0.0, 0.0, 0.0), lift=0.07):
    """Picks a paw up at t0 and puts it down at t1, from `frm` to `to` (shifts from rest)."""
    k = seg(t, t0, t1)
    s = smooth(k)
    up = math.sin(math.pi * k)
    d[f"f_{leg}"] = (frm[0] + (to[0] - frm[0]) * s, frm[1] + (to[1] - frm[1]) * s, frm[2] + (to[2] - frm[2]) * s + lift * up)
    d[f"heel_{leg}"] += (26.0 if leg[0] == "f" else 18.0) * up


def author(r):
    """Keys every clip onto the rig, in the guide's order. BRACKENHOUND_CLIPS=a,b
    keys only those (for a quick look)."""
    only = os.environ.get("BRACKENHOUND_CLIPS")
    table = [("lie", lie), ("idle", idle), ("walk", walk), ("trot", trot), ("gallop", gallop), ("sniff", sniff), ("stalk", stalk),
             ("alert", alert), ("startle", startle), ("call", call), ("bay", bay), ("bite", bite), ("pounce", pounce),
             ("recover", recover), ("hit", hit), ("stagger", stagger), ("sleep_fall", sleep_fall), ("sleep", sleep), ("wake", wake),
             ("burn", burn), ("death", death), ("death_skull_knot", death_skull_knot)]
    for key, fn in table:
        if only and key not in only.split(","):
            continue
        fn(r)


# ------------------------------------------------------------------ still

def lie(r):
    """By day: a mossy log in the bracken. Nothing moves, not even the fronds."""
    keyclip(r, "lie", LIE, [(0.0, dict()), (1.0, dict())], loop=True)


def idle(r):
    """Stood square and stiff; the head comes round to listen, a paw shifts, the tail swings once."""
    T = 6.0

    def more(t, d):
        d["tail_yaw"] += 14.0 * wave(t, 3.0) * pulse(t, 2.6, 3.6, 5.6)
        step(d, t, "fl_r", 3.3, 3.62, lift=0.05)
        k = pulse(t, 4.3, 4.5, 5.0)                             # a shake of the head, like a dog with wet ears
        d["head_roll"] += 16.0 * k * wave(t, 0.16)
        d["neck_roll"] += 10.0 * k * wave(t, 0.16, 0.2)
        d["ears"] += 0.4 * k * wave(t, 0.16, 0.4)
    keyclip(r, "idle", BASE, [
        (0.0, dict(neck_p=30.0, head_p=-16.0, x=0.012, tail_p=2.0)),
        (1.3, dict(neck_p=31.0, x=0.014)),
        (1.5, dict(neck_p=10.0, head_p=-8.0, neck_yaw=34.0, head_yaw=10.0, head_roll=-10.0, ears=0.8, fronds=0.15), "snap"),       # what was that
        (2.7, dict(neck_p=9.0, neck_yaw=36.0, x=-0.012)),
        (3.1, dict(neck_p=40.0, head_p=-16.0, neck_yaw=6.0, head_yaw=0.0, head_roll=0.0, ears=0.0, fronds=0.0, jaw=5.0)),              # nothing
        (4.2, dict(neck_p=36.0, neck_yaw=-4.0, jaw=0.0)),
        (5.2, dict(neck_p=30.0, neck_yaw=0.0)),
        (T, dict(neck_p=30.0, head_p=-16.0, x=0.012, tail_p=2.0)),
    ], loop=True, breath=1.0, more=more)


def sniff(r):
    """Nose down, quartering the ground from one side to the other, snuffling."""
    T = 4.0

    def more(t, d):
        d["head_p"] += 3.0 * wave(t, 0.22)                       # the snuffle
        d["jaw"] += 2.0 * (wave(t, 0.22, 0.3) * 0.5 + 0.5)
        d["tail_yaw"] += 8.0 * wave(t, 1.0)
        step(d, t, "fl_l", 1.0, 1.3, to=(-0.03, 0.05, 0.0), lift=0.05) if t < 2.5 else step(d, t, "fl_l", 3.0, 3.3, frm=(-0.03, 0.05, 0.0), lift=0.05)
    keyclip(r, "sniff", SNIFF, [
        (0.0, dict(neck_yaw=-26.0, head_yaw=-8.0, x=0.015)),
        (0.9, dict(neck_yaw=-30.0, head_roll=8.0)),
        (1.6, dict(neck_yaw=8.0, head_yaw=4.0, head_roll=-6.0, neck_p=72.0)),
        (2.2, dict(neck_yaw=30.0, head_yaw=10.0, x=-0.015, neck_p=80.0)),
        (2.9, dict(neck_yaw=26.0, head_roll=-10.0)),
        (3.5, dict(neck_yaw=-6.0, head_roll=0.0, neck_p=74.0)),
        (T, dict(neck_yaw=-26.0, head_yaw=-8.0, x=0.015, neck_p=78.0, head_roll=0.0)),
    ], loop=True, breath=1.0, period=2.0, more=more)


def alert(r):
    """Curious: the head up, the fern ears lifting, one front paw held off the ground."""
    T = 3.2
    up = (0.0, 0.07, 0.16)
    keyclip(r, "alert", ALERT, [
        (0.0, dict(neck_yaw=8.0, head_roll=6.0, f_fl_r=up, heel_fl_r=HEEL_F + 34.0, toe_fl_r=-30.0, x=-0.02, y=-0.02)),
        (1.3, dict(neck_yaw=9.0, head_roll=7.0)),
        (1.42, dict(neck_yaw=-12.0, head_roll=-9.0, ears=0.7), "snap"),
        (1.6, dict(ears=1.0)),
        (2.8, dict(neck_yaw=-11.0, head_roll=-8.0)),
        (2.95, dict(neck_yaw=6.0, head_roll=4.0), "snap"),
        (T, dict(neck_yaw=8.0, head_roll=6.0)),
    ], loop=True, breath=1.0, period=1.6, more=lambda t, d: d.update(tail_yaw=5.0 * wave(t, 1.6)))


def startle(r):
    """The moment it notices (0.7 s): the whole frame jerks low, then the head comes up."""
    up = (0.0, 0.07, 0.16)
    keyclip(r, "startle", BASE, [
        (0.0, dict(STAND)),
        (0.1, dict(z=-0.1, arch=7.0, neck_p=24.0, head_p=-14.0, ears=-1.0, fronds=0.7, tail_p=-10.0), "snap"),
        (0.38, dict(ALERT, neck_p=2.0, fronds=0.6, x=-0.02, y=-0.02), "out"),
        (0.55, dict(f_fl_r=up, heel_fl_r=HEEL_F + 34.0, toe_fl_r=-30.0, neck_p=6.0, fronds=0.35)),
        (0.7, dict(neck_yaw=8.0, head_roll=6.0)),
    ])


def _bay(t, d, t0, t1):
    """The hollow wooden bay: the head thrown up, the long jaw wide, the frame shaking with it."""
    k = pulse(t, t0, t0 + 0.22, t1) ** 0.5 if t0 < t < t1 else 0.0
    d["neck_p"] += -46.0 * k
    d["head_p"] += -34.0 * k
    d["jaw"] += 42.0 * k + 3.0 * k * wave(t, 0.09)
    d["reach"] += 0.5 * k
    d["arch"] += -5.0 * k
    d["z"] += 0.004 * k * wave(t, 0.09)
    d["fronds"] += 0.5 * k
    d["tail_p"] += 26.0 * k


def call(r):
    """Engaged (1.4 s): it plants its front paws and bays."""
    keyclip(r, "call", ALERT, [
        (0.0, dict(neck_yaw=8.0, head_roll=6.0)),
        (0.22, dict(neck_p=30.0, head_p=4.0, neck_yaw=0.0, head_roll=0.0, z=-0.07, arch=6.0, jaw=6.0, ears=-0.5, y=-0.03,
                    **sym("f", "fl", (0.04, 0.06, 0.0)))),
        (0.5, dict(neck_p=-4.0, head_p=0.0, z=0.0, arch=0.0, y=-0.05, ears=1.0), "out"),
        (1.15, dict(y=-0.06)),
        (1.4, dict(BASE, **STAND, jaw=4.0, **sym("f", "fl", (0.04, 0.06, 0.0))), "slow"),
    ], more=lambda t, d: _bay(t, d, 0.26, 1.3))


def bay(r):
    """At the water's edge: it will not go in, so it paces a step and bays across."""
    T = 3.2
    plant = sym("f", "fl", (0.04, 0.06, 0.0))

    def more(t, d):
        _bay(t, d, 0.2, 1.3)
        _bay(t, d, 1.8, 2.9)
        step(d, t, "fl_l", 1.36, 1.6, to=(-0.04, 0.06, 0.0), frm=(-0.04, 0.06, 0.0), lift=0.09)
        step(d, t, "fl_r", 1.52, 1.76, to=(0.04, 0.06, 0.0), frm=(0.04, 0.06, 0.0), lift=0.09)
        step(d, t, "hl_r", 2.95, 3.18, lift=0.05)
    keyclip(r, "bay", dict(BASE, **plant), [
        (0.0, dict(neck_p=14.0, jaw=5.0, y=-0.04, z=-0.03)),
        (0.3, dict(neck_p=0.0, y=-0.06, z=0.0, neck_yaw=-6.0)),
        (1.3, dict(neck_p=4.0)),
        (1.6, dict(neck_p=26.0, z=-0.05, y=0.0, neck_yaw=4.0, jaw=8.0)),
        (1.9, dict(neck_p=0.0, z=0.0, y=-0.06, neck_yaw=8.0)),
        (2.9, dict(neck_p=4.0, neck_yaw=4.0)),
        (T, dict(neck_p=14.0, jaw=5.0, y=-0.04, z=-0.03, neck_yaw=0.0)),
    ], loop=True, more=more)


# ------------------------------------------------------------------ gaits

def _upper(r, fn):
    def upper(t, ph, p):
        d = dict(BASE)
        fn(t, ph, d)
        q = pose(r, d, feet=False)
        for k in ("body_loc", "body_rot", "fk", "offsets", "keys", "wind", "ground"):
            setattr(p, k, getattr(q, k))
        for leg in LEGS:
            p.feet[leg]["knee"] = Vector(ELBOW if leg[0] == "f" else STIFLE)
    return upper


def _stance(r, front=0.0, hind=0.0):
    return {leg: r.rest_ball(leg).y + (front if leg[0] == "f" else hind) for leg in LEGS}


def walk(r):
    """1.6 m/s, four beats: stiff-legged, the head carried low and nodding."""
    def up(t, ph, d):
        c = math.cos(2 * math.pi * (ph - 0.08))
        d.update(z=-0.055 + 0.012 * math.cos(4 * math.pi * (ph - 0.06)), x=0.014 * math.sin(2 * math.pi * (ph + 0.1)),
                 swing=4.5 * c, twist=3.0 * math.sin(2 * math.pi * ph), roll=-1.2 * math.sin(2 * math.pi * ph),
                 neck_p=38.0 + 5.0 * math.cos(4 * math.pi * (ph - 0.15)), head_p=-14.0 - 3.0 * math.cos(4 * math.pi * (ph - 0.2)),
                 neck_yaw=-2.5 * c, tail_p=4.0, tail_yaw=10.0 * math.sin(2 * math.pi * (ph - 0.1)), jaw=3.0)
    return r.gait("walk", speed=1.6, stride=1.0, duty=0.62, phases={"hl_l": 0.0, "fl_l": 0.25, "hl_r": 0.5, "fl_r": 0.75}, lift=0.065,
                  upper=_upper(r, up), stance_y=_stance(r, 0.0, 0.03), heel_off=18.0, swing_heel=22.0, toe_swing=-14.0, yaw=0.0)


def stalk(r):
    """Casting for scent at 1.2 m/s: low, the nose sweeping a hand above the ground."""
    def up(t, ph, d):
        c = math.cos(2 * math.pi * (ph - 0.08))
        d.update(SNIFF)
        d.update(z=-0.1 + 0.008 * math.cos(4 * math.pi * (ph - 0.06)), pitch=6.0, x=0.012 * math.sin(2 * math.pi * (ph + 0.1)),
                 swing=4.0 * c, neck_p=70.0, neck_yaw=22.0 * math.sin(2 * math.pi * ph), head_yaw=8.0 * math.sin(2 * math.pi * (ph - 0.08)),
                 head_p=14.0 + 3.0 * wave(t, 0.2), tail_p=-2.0, tail_yaw=6.0 * math.sin(2 * math.pi * (ph - 0.1)), jaw=3.0)
    return r.gait("stalk", speed=1.2, stride=1.0, duty=0.68, phases={"hl_l": 0.0, "fl_l": 0.25, "hl_r": 0.5, "fl_r": 0.75}, lift=0.05,
                  upper=_upper(r, up), stance_y=_stance(r, 0.0, 0.03), heel_off=14.0, swing_heel=16.0, toe_swing=-10.0, yaw=0.0)


def trot(r):
    """4 m/s, the diagonal pairs together: a hard, jolting trot, the head level."""
    def up(t, ph, d):
        b = math.cos(4 * math.pi * (ph - 0.12))
        d.update(z=-0.07 + 0.022 * b, pitch=1.2 * math.sin(4 * math.pi * ph), swing=3.0 * math.cos(2 * math.pi * (ph - 0.05)),
                 twist=2.5 * math.sin(2 * math.pi * ph), neck_p=34.0 - 3.0 * b, head_p=-16.0 + 2.5 * b, jaw=7.0 + 2.0 * b,
                 tail_p=20.0 + 4.0 * b, tail_curl=3.0, tail_yaw=6.0 * math.sin(2 * math.pi * ph), ears=-0.3 - 0.25 * b, fronds=0.1 - 0.1 * b)
    return r.gait("trot", speed=4.0, stride=1.6, duty=0.42, phases={"hl_l": 0.0, "fl_r": 0.0, "hl_r": 0.5, "fl_l": 0.5}, lift=0.11,
                  upper=_upper(r, up), stance_y=_stance(r, 0.0, 0.04), heel_off=22.0, swing_heel=34.0, toe_swing=-20.0, yaw=0.0)


def gallop(r):
    """8 m/s: the back folding and flinging open, the neck out flat, the jaw hanging."""
    def up(t, ph, d):
        gather = math.cos(2 * math.pi * (ph - 0.9))               # +1 folded in the air, -1 flung open
        d.update(z=-0.1 + 0.045 * math.cos(4 * math.pi * (ph - 0.4)), pitch=-6.5 * math.cos(2 * math.pi * (ph - 0.12)),
                 arch=4.0 + 13.0 * gather, neck_p=30.0 + 6.5 * math.cos(2 * math.pi * (ph - 0.12)) - 5.0 * gather,
                 head_p=-12.0 + 4.0 * gather, reach=0.3 - 0.3 * gather, jaw=13.0 + 5.0 * math.cos(2 * math.pi * (ph - 0.5)),
                 tail_p=34.0 - 12.0 * gather, tail_curl=5.0 * gather, ears=-0.9, fronds=0.25 + 0.2 * math.cos(4 * math.pi * ph),
                 swing=2.0 * math.sin(2 * math.pi * ph))
    return r.gait("gallop", speed=8.0, stride=3.0, duty=0.24, phases={"hl_l": 0.0, "hl_r": 0.1, "fl_l": 0.45, "fl_r": 0.55}, lift=0.17,
                  upper=_upper(r, up), stance_y=_stance(r, 0.06, 0.1), heel_off=24.0, swing_heel=40.0, toe_swing=-24.0, yaw=0.0)


# ------------------------------------------------------------------ attacks

BITE_READY = dict(BASE, z=-0.09, y=-0.1, pitch=4.0, arch=6.0, neck_p=34.0, head_p=-20.0, jaw=20.0, ears=-1.0, fronds=0.5, tail_p=14.0,
                  **sym("f", "fl", (0.03, 0.04, 0.0)))


def bite(r):
    """Wind-up 0.55 s: the head drops and the jaw cracks open. Then the neck throws the skull forward and it shuts."""
    keyclip(r, "telegraph_brackenhound_bite", BASE, [
        (0.0, dict(STAND)),
        (0.2, dict(BITE_READY, jaw=6.0, y=-0.05), "out"),
        (0.36, dict(jaw=9.0, y=-0.1)),
        (0.44, dict(jaw=24.0, head_roll=7.0), "snap"),
        (0.55, dict(jaw=20.0, head_roll=5.0)),
    ])
    hit = dict(BITE_READY, y=0.24, z=-0.1, pitch=7.0, arch=-6.0, neck_p=30.0, head_p=-26.0, reach=1.0, jaw=40.0, head_roll=-4.0, tail_p=30.0)
    keyclip(r, "attack_brackenhound_bite", dict(BITE_READY, head_roll=5.0), [
        (0.0, dict()),
        (0.1, hit, "whip"),
        (0.133, dict(jaw=0.0, head_p=-20.0, reach=1.0), "snap"),
        (0.23, dict(jaw=0.0, head_roll=14.0, neck_yaw=10.0, y=0.2)),                    # a wrench with it shut
        (0.33, dict(head_roll=-12.0, neck_yaw=-8.0)),
        (0.55, dict(BITE_READY, jaw=6.0, y=0.0, head_roll=0.0), "slow"),
    ], contact=0.133)


def pounce(r):
    """Wind-up 0.8 s: a low crouch, the bark of its back splitting up. Then a 4 m leap (the code carries it)."""
    def more(t, d):
        k = seg(t, 0.3, 0.8)
        d["fronds"] += 0.12 * k * wave(t, 0.08)                   # the bark working
        d["tail_yaw"] += 10.0 * k * wave(t, 0.2)
    keyclip(r, "telegraph_brackenhound_pounce", BASE, [
        (0.0, dict(STAND)),
        (0.3, dict(CROUCH, fronds=0.2, z=-0.2, jaw=4.0), "out"),
        (0.62, dict(CROUCH, z=-0.29, y=-0.12, fronds=0.9)),
        (0.8, dict(CROUCH, z=-0.3, y=-0.14)),
    ], more=more)
    air = dict(BASE, z=0.42, pitch=-12.0, arch=-10.0, neck_p=22.0, head_p=-16.0, reach=0.6, jaw=40.0, fronds=1.0, ears=-1.0, tail_p=40.0,
               **sym("fmix", "fl", 1.0), **sym("fmix", "hl", 1.0), **sym("fc", "fl", (0.02, 0.42, 0.3)), **sym("fc", "hl", (0.0, -0.5, 0.22)),
               **sym("heel", "fl", 40.0), **sym("heel", "hl", 110.0), **sym("toe", "fl", 20.0))
    keyclip(r, "attack_brackenhound_pounce", dict(CROUCH, z=-0.3, y=-0.14), [
        (0.0, dict()),
        (0.1, dict(BASE, z=0.05, y=0.2, pitch=-16.0, arch=-8.0, neck_p=20.0, head_p=-14.0, jaw=30.0, fronds=1.0, ears=-1.0, tail_p=30.0,
                   **sym("fmix", "fl", 1.0), **sym("fc", "fl", (0.02, 0.3, 0.35)), **sym("heel", "fl", 50.0),
                   **sym("f", "hl", (0.0, -0.3, 0.0)), **sym("heel", "hl", HEEL_H + 26.0)), "whip"),
        (0.24, air, "out"),
        (0.4, dict(air, z=0.34, pitch=10.0, arch=4.0, neck_p=14.0, jaw=44.0, **sym("fc", "fl", (0.03, 0.38, 0.12)), **sym("fc", "hl", (0.0, -0.3, 0.3)),
                   **sym("heel", "hl", 90.0))),
        (0.5, dict(BASE, z=-0.16, y=0.1, pitch=12.0, arch=8.0, neck_p=30.0, head_p=-10.0, jaw=4.0, fronds=0.8, ears=-1.0, tail_p=36.0,
                   **sym("f", "fl", (0.03, 0.14, 0.0)), **sym("fmix", "hl", 1.0), **sym("fc", "hl", (0.0, -0.1, 0.25))), "whip"),
        (0.62, dict(BASE, z=-0.22, y=0.0, pitch=2.0, arch=12.0, neck_p=26.0, head_p=-14.0, jaw=10.0, fronds=0.6, ears=-1.0, tail_p=0.0,
                    **sym("f", "fl", (0.03, 0.08, 0.0)), **sym("f", "hl", (0.03, 0.12, 0.0))), "out"),
        (0.8, dict(z=-0.12, arch=6.0, fronds=0.4)),
    ], contact=0.45, travel=4.0)


def recover(r):
    """After a strike: it stands back up out of it and shakes its head."""
    def more(t, d):
        k = pulse(t, 0.25, 0.4, 0.7)
        d["head_roll"] += 14.0 * k * wave(t, 0.15)
        d["neck_roll"] += 8.0 * k * wave(t, 0.15, 0.2)
    keyclip(r, "recover", dict(BITE_READY, jaw=6.0), [
        (0.0, dict()),
        (0.3, dict(z=-0.03, y=-0.03, pitch=0.0, arch=0.0, neck_p=16.0, head_p=-4.0, jaw=8.0, fronds=0.2, ears=-0.3)),
        (0.8, dict(BASE, **STAND)),
    ], more=more)


# ------------------------------------------------------------------ hurt

def hit(r):
    """A crack like a snapped branch (0.3 s): the frame jolts away from the blow and comes back."""
    for side in ("l", "r"):
        s = 1.0 if side == "l" else -1.0               # hit on its left: thrown to its right
        keyclip(r, f"hit_{side}", BASE, [
            (0.0, dict(STAND)),
            (0.06, dict(x=0.07 * s, roll=7.0 * s, swing=-9.0 * s, z=-0.05, neck_p=22.0, neck_yaw=-20.0 * s, head_roll=16.0 * s, jaw=16.0,
                        ears=-1.0, fronds=0.8, tail_p=18.0, twist=6.0 * s), "snap"),
            (0.18, dict(x=0.03 * s, roll=2.0 * s, swing=-3.0 * s, z=-0.02, neck_yaw=-8.0 * s, head_roll=4.0 * s, jaw=6.0, fronds=0.3)),
            (0.3, dict(BASE, **STAND)),
        ])


def stagger(r):
    """Knocked off its line (1.0 s): the legs go every way, it scrabbles back half a metre."""
    def more(t, d):
        step(d, t, "fl_l", 0.1, 0.26, to=(-0.1, -0.06, 0.0), lift=0.1)
        step(d, t, "hl_r", 0.16, 0.34, to=(0.1, -0.08, 0.0), lift=0.08)
        if t > 0.36:
            step(d, t, "fl_r", 0.38, 0.54, to=(0.05, -0.04, 0.0), lift=0.08)
        if t > 0.6:
            step(d, t, "fl_l", 0.62, 0.8, frm=(-0.1, -0.06, 0.0), lift=0.06)
            step(d, t, "hl_r", 0.66, 0.84, frm=(0.1, -0.08, 0.0), lift=0.06)
        if t > 0.8:
            step(d, t, "fl_r", 0.82, 0.96, frm=(0.05, -0.04, 0.0), lift=0.05)
    keyclip(r, "stagger", BASE, [
        (0.0, dict(STAND)),
        (0.12, dict(z=-0.16, pitch=-7.0, roll=9.0, x=0.06, arch=8.0, neck_p=30.0, neck_yaw=-24.0, head_roll=20.0, jaw=18.0, ears=-1.0,
                    fronds=0.9, tail_p=-12.0), "snap"),
        (0.4, dict(z=-0.2, pitch=4.0, roll=-6.0, x=-0.05, neck_yaw=16.0, head_roll=-12.0, jaw=10.0)),
        (0.7, dict(z=-0.08, pitch=0.0, roll=2.0, x=0.0, arch=3.0, neck_p=18.0, neck_yaw=0.0, head_roll=0.0, jaw=6.0, fronds=0.4)),
        (1.0, dict(BASE, **STAND)),
    ], more=more, travel=-0.5)


def sleep_fall(r):
    """Put to sleep (1.6 s): the legs fold one end at a time and it goes down like a felled thing."""
    keyclip(r, "sleep_fall", BASE, [
        (0.0, dict(STAND)),
        (0.4, dict(neck_p=40.0, head_p=6.0, z=-0.06, x=0.03, jaw=6.0, ears=-0.6), "slow"),
        (0.85, dict(LIE, ground=0.55, pitch=12.0, neck_p=56.0, head_p=-20.0, **sym("fmix", "hl", 0.0), **sym("heel", "hl", HEEL_H),
                    **sym("knee", "hl", None), jaw=8.0)),                                              # down in front
        (1.3, dict(LIE, neck_p=52.0, neck_yaw=-30.0, head_p=-40.0, roll=3.0), "out"),
        (1.6, dict(SLEEP)),
    ])


def sleep(r):
    T = 5.0
    keyclip(r, "sleep", SLEEP, [(0.0, dict()), (2.5, dict(jaw=5.0, tail_yaw=42.0)), (T, dict())], loop=True, breath=1.6, period=5.0)


def wake(r):
    """(1.8 s) The head first, then the front end, then the rest, and a shake."""
    def more(t, d):
        k = pulse(t, 1.3, 1.45, 1.75)
        d["twist"] += 7.0 * k * wave(t, 0.14)
        d["head_roll"] += 12.0 * k * wave(t, 0.14, 0.25)
        d["fronds"] += 0.3 * k
    keyclip(r, "wake", SLEEP, [
        (0.0, dict()),
        (0.4, dict(neck_p=10.0, neck_yaw=-20.0, head_p=-20.0, head_roll=0.0, swing=-4.0, roll=2.0, ears=0.6, jaw=0.0)),
        (0.8, dict(LIE, ground=0.5, pitch=-14.0, neck_p=-6.0, head_p=4.0, ears=0.8, **sym("fmix", "fl", 0.0), **sym("heel", "fl", HEEL_F),
                   **sym("knee", "fl", None), **sym("f", "fl", (0.0, 0.08, 0.0)))),                        # up in front
        (1.25, dict(BASE, neck_p=-8.0, ears=0.6, z=-0.04), "out"),
        (1.8, dict(BASE, **STAND)),
    ], more=more)


def burn(r):
    """On fire: it goes mad, bucking and snapping at its own flanks."""
    T = 1.6

    def more(t, d):
        d["z"] += 0.02 * wave(t, 0.2)
        d["fronds"] += 0.3 * wave(t, 0.1)
        d["jaw"] += 8.0 * wave(t, 0.13)
        step(d, t, "fl_l", 0.05, 0.3, lift=0.2)
        step(d, t, "fl_r", 0.1, 0.36, lift=0.24)
        step(d, t, "hl_l", 0.85, 1.1, lift=0.2)
        step(d, t, "hl_r", 0.9, 1.16, lift=0.24)
    keyclip(r, "burn", dict(BASE, ears=-1.0, fronds=0.7, jaw=24.0), [
        (0.0, dict(pitch=0.0, neck_p=10.0, swing=0.0)),
        (0.2, dict(pitch=-14.0, z=0.04, arch=-8.0, neck_p=-20.0, neck_yaw=20.0, tail_p=30.0), "snap"),              # rears
        (0.45, dict(pitch=2.0, z=-0.1, arch=10.0, swing=-34.0, neck_p=30.0, neck_yaw=-70.0, head_roll=-20.0, jaw=40.0, tail_yaw=30.0)),   # snaps at its right flank
        (0.75, dict(swing=-10.0, neck_yaw=-20.0, z=-0.04)),
        (1.0, dict(pitch=13.0, z=0.02, arch=-6.0, swing=20.0, neck_p=36.0, neck_yaw=40.0, head_roll=14.0, tail_p=44.0, tail_yaw=-30.0), "snap"),   # bucks
        (1.3, dict(pitch=0.0, z=-0.08, arch=8.0, swing=30.0, neck_yaw=64.0, jaw=40.0)),
        (T, dict(pitch=0.0, z=0.0, arch=0.0, neck_p=10.0, swing=0.0, neck_yaw=0.0, head_roll=0.0, jaw=24.0, tail_p=0.0, tail_yaw=0.0)),
    ], loop=True, more=more)


def death(r):
    """Shot from one side, it goes over onto the other (1.5 s): the legs stiffen, it topples like a cut tree and the frame slackens."""
    for side in ("l", "r"):
        fall = "r" if side == "l" else "l"
        s = 1.0 if fall == "r" else -1.0
        down = lying(fall)

        def more(t, d, s=s):
            d["roll"] += s * ring(t, 0.62, 5.0, 3.2, 6.0)                 # the bounce as it lands
            d["jaw"] += 6.0 * pulse(t, 0.6, 0.72, 1.1)
            d["tail_curl"] += 5.0 * pulse(t, 0.7, 0.9, 1.4)
        keyclip(r, f"death_{side}", BASE, [
            (0.0, dict(STAND)),
            (0.08, dict(x=0.06 * s, roll=8.0 * s, swing=-8.0 * s, neck_p=-10.0, neck_yaw=-18.0 * s, head_roll=14.0 * s, jaw=30.0, ears=-1.0,
                        fronds=1.0, z=0.02, arch=-5.0, tail_p=30.0), "snap"),
            (0.32, dict(x=0.12 * s, roll=20.0 * s, neck_p=-20.0, jaw=34.0, z=0.0, **sym("f", "fl", (0.03, 0.03, 0.0)))),      # stiff, tipping
            (0.62, dict(down, fronds=0.6, neck_p=-4.0, jaw=34.0), "whip"),
            (0.95, dict(down, fronds=0.0)),
            (1.5, dict(down), "out"),
        ], more=more)


def death_skull_knot(r):
    """The knot between its eyes (1.6 s): the head snaps back, the front end goes out from under it,
    it ploughs in nose first and rolls over."""
    down = lying("l")

    def more(t, d):
        d["roll"] += -ring(t, 1.0, 4.0, 3.0, 6.0)
        k = pulse(t, 1.05, 1.2, 1.5)
        d["tail_curl"] += 6.0 * k * wave(t, 0.12)                         # the last of it
    keyclip(r, "death_skull_knot", BASE, [
        (0.0, dict(STAND)),
        (0.07, dict(neck_p=-52.0, head_p=-30.0, jaw=36.0, y=-0.08, z=0.03, pitch=-6.0, arch=-6.0, ears=-1.0, fronds=1.0, tail_p=36.0), "snap"),
        (0.3, dict(neck_p=-40.0, head_roll=-16.0, y=-0.12, z=-0.03, pitch=-3.0, jaw=40.0)),
        (0.62, dict(LIE, ground=0.6, pitch=20.0, y=0.05, neck_p=44.0, head_p=-34.0, head_roll=-20.0, jaw=20.0, fronds=0.7,
                    **sym("fmix", "hl", 0.0), **sym("heel", "hl", HEEL_H), **sym("knee", "hl", None)), "whip"),          # nose first
        (1.0, dict(down, fronds=0.3), "smooth"),
        (1.6, dict(down), "out"),
    ], more=more)
