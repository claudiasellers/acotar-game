"""The gloamer's clips (bestiary §16.4): names, lengths and wind-up times are
the guide's. Each clip is a table of key postures (biped.Keys) with a little
motion on top where a formula says it better (breath, a blink, a chitter).

It is wiry, greedy and never still: everything starts with a twitch and
overshoots. Two postures carry most of it: on its knuckles (KN, about 1.1 m
tall) and stood up to its full height to look or to strike (UP).
"""

import math
import os

import biped
import rig
from biped import Keys
from rig import pulse, ring, seg, smooth, wave

SPINE = ("spine", "spine2", "chest")
NECK = ("neck",)
LID_SHUT = 82.0        # degrees of `eyelid_*` pitch that close the eye

REST_R, REST_L = (0.585, 0.01, 0.47), (-0.585, 0.01, 0.47)
BASE = dict(biped.BASE)
BASE.update(foot_yaw=18.0, hc_r=REST_R, hc_l=REST_L, lid_r=0.0, lid_l=0.0)

# On its knuckles: bent forward from the hips, the long arms straight props,
# the head carried low and pushed forward.
FIST_R, FIST_L = (0.3, 0.6, 0.15), (-0.3, 0.6, 0.15)
DOWN_R, DOWN_L = (0.0, 0.35, -1.0), (0.0, 0.35, -1.0)
KN = dict(BASE)
KN.update(lean=54.0, drop=0.1, level=0.82, f_r=(0.03, 0.0, 0.0), f_l=(-0.03, 0.0, 0.0),
          hmix_r=1.0, hmix_l=1.0, hw_r=FIST_R, hw_l=FIST_L, aim_r=DOWN_R, aim_l=DOWN_L,
          pole_r=(1.0, -0.5, 0.3), pole_l=(-1.0, -0.5, 0.3), curl_r=0.9, curl_l=0.9, spread_r=0.0, spread_l=0.0)

# Stood up: still stooped, the arms hanging past the knees, fingers loose.
HANG_R, HANG_L = (0.34, 0.1, 0.5), (-0.34, 0.1, 0.5)
UP = dict(BASE)
UP.update(lean=10.0, drop=0.03, level=1.0, stretch=0.4, hc_r=HANG_R, hc_l=HANG_L, pole_r=(0.7, -1.0, 0.0), pole_l=(-0.7, -1.0, 0.0),
          curl_r=0.35, curl_l=0.35, spread_r=0.5, spread_l=0.5, f_r=(0.03, 0.0, 0.0), f_l=(-0.03, 0.0, 0.0))

# Asleep: curled forward over its knees in a ball, arms wrapped round its head.
SLEEP = dict(BASE)
SLEEP.update(lean=28.0, body_pitch=56.0, bend=24.0, level=0.0, neck_up=-8.0, neck_yaw=30.0, head_roll=-24.0, ground=1.0,
             fmix_r=1.0, fmix_l=1.0, fc_r=(0.1, 0.14, 0.44), fc_l=(-0.1, 0.14, 0.44), knee_r=(1.0, 0.7, 0.6), knee_l=(-1.0, 0.7, 0.6),
             heel_r=64.0, heel_l=64.0, hmix_r=1.0, hmix_l=1.0, hw_r=(0.16, 0.74, 0.1), hw_l=(-0.1, 0.8, 0.14),
             aim_r=(-0.8, 0.5, -0.1), aim_l=(0.8, 0.5, -0.1), pole_r=(1.0, -0.2, 0.25), pole_l=(-1.0, -0.2, 0.25),
             curl_r=0.55, curl_l=0.55, lid_r=1.0, lid_l=1.0, jaw=4.0)


def lying(side):
    """Dead on one flank (the creature's right for "r"), a heap of limbs."""
    d = dict(BASE)
    d.update(body_roll=82.0, lean=0.0, ground=1.0, bend=20.0, level=0.0, neck_up=14.0, neck_roll=-18.0, head_roll=-14.0,
             fmix_r=1.0, fmix_l=1.0, fc_r=(0.03, 0.06, 0.06), fc_l=(0.12, 0.22, 0.12), heel_r=40.0, heel_l=50.0, knee_l=(0.6, 1.0, 0.2),
             hmix_r=0.0, hmix_l=0.0, hc_r=(0.2, 0.34, 1.75), hc_l=(0.2, 0.5, 0.95), aim_r=None, aim_l=None, pole_r=(0.0, -1.0, 0.0),
             pole_l=(-0.4, -0.2, -1.0), curl_r=0.5, curl_l=0.6, jaw=20.0, lid_r=0.5, lid_l=0.5)
    return d if side == "r" else biped.mirrored(d)


def pose(r, d):
    p = biped.apply(r, d, SPINE, NECK)
    for side in ("r", "l"):
        if d[f"lid_{side}"]:
            p.turn(f"eyelid_{side}", pitch=LID_SHUT * d[f"lid_{side}"])
    return p


def blink(t, d, *at):
    b = sum(pulse(t, s, s + 0.06, s + 0.16) for s in at)
    d["lid_r"] = max(d["lid_r"], b)
    d["lid_l"] = max(d["lid_l"], b)


def chitter(t, d, amount=1.0, rate=0.09):
    """The jaw rattling: the sound is the audio's, this is what shows."""
    d["jaw"] += 7.0 * amount * (wave(t, rate) * 0.5 + 0.5)
    d["head_up"] += 1.5 * amount * wave(t, rate * 2)


def keyclip(r, name, base, keys, loop=False, more=None, after=None, contact=None, travel=None, breath=0.0, period=2.4, blinks=()):
    K = Keys(base, keys)
    T = K.duration / max(round(K.duration / period), 1)

    def fn(t):
        d = K(t)
        if breath:
            b = wave(t, T, -0.25) * 0.5 + 0.5                 # 0 empty, 1 full
            d["bend"] -= 3.0 * breath * b
            d["bob"] += 0.005 * breath * b
        if blinks:
            blink(t, d, *blinks)
        if more is not None:
            more(t, d)
        p = pose(r, d)
        if breath:
            p.turn("chest", pitch=-2.5 * breath * (wave(t, T, -0.25) * 0.5 + 0.5))
        if after is not None:
            after(t, p)
        return p
    r.clip(name, K.duration, fn, loop=loop, contact=contact, travel=travel)


def author(r):
    """Keys every clip onto the rig, in the guide's order. GLOAMER_CLIPS=a,b
    keys only those (for a quick look)."""
    only = os.environ.get("GLOAMER_CLIPS")
    table = [("idle", idle), ("walk", walk), ("run", run), ("stalk", stalk), ("alert", alert), ("startle", startle), ("call", call),
             ("forage", forage), ("squabble", squabble), ("grab_shiny", grab_shiny), ("rake", rake), ("shove", shove),
             ("recover", recover), ("hit", hit), ("stagger", stagger), ("sleep_fall", sleep_fall), ("sleep", sleep), ("wake", wake),
             ("burn", burn), ("death", death), ("death_throat", death_throat)]
    for key, fn in table:
        if only and key not in only.split(","):
            continue
        fn(r)


# ------------------------------------------------------------------ idles

def idle(r):
    """On its knuckles, weight rocking, the head darting from one thing to the next."""
    T = 4.8
    keyclip(r, "idle", KN, [
        (0.0, dict(sway=0.025, neck_yaw=16.0, spine_roll=1.5)),
        (0.9, dict(neck_yaw=18.0)),
        (1.05, dict(neck_yaw=-24.0, head_roll=9.0, head_up=6.0), "snap"),                   # something over there
        (2.1, dict(sway=-0.03, neck_yaw=-22.0, spine_roll=-1.5)),
        (2.25, dict(neck_yaw=4.0, head_roll=-6.0, head_up=-8.0, hw_r=(0.3, 0.62, 0.24), curl_r=0.6), "snap"),   # its own hand
        (2.9, dict(hw_r=(0.3, 0.62, 0.26), curl_r=0.3, spread_r=0.6)),
        (3.4, dict(hw_r=FIST_R, curl_r=0.9, spread_r=0.0, head_up=0.0)),
        (3.9, dict(neck_yaw=10.0, head_roll=0.0)),
        (T, dict(sway=0.025, neck_yaw=16.0, spine_roll=1.5)),
    ], loop=True, breath=1.0, blinks=(1.3, 3.0, 4.2), more=lambda t, d: chitter(t, d, 0.5 * pulse(t, 2.3, 2.6, 3.3)))


def alert(r):
    """Curious: stood up tall, head tilted, chittering a question."""
    T = 3.0
    keyclip(r, "alert", UP, [
        (0.0, dict(head_roll=14.0, neck_yaw=6.0, sway=0.015)),
        (1.3, dict(head_roll=16.0, neck_yaw=8.0)),
        (1.45, dict(head_roll=-12.0, neck_yaw=-10.0, stretch=0.7), "snap"),
        (2.7, dict(head_roll=-14.0, neck_yaw=-8.0, sway=-0.015)),
        (2.85, dict(head_roll=12.0, neck_yaw=4.0, stretch=0.4), "snap"),
        (T, dict(head_roll=14.0, neck_yaw=6.0, sway=0.015)),
    ], loop=True, breath=1.0, period=1.5, blinks=(0.6, 2.0),
        more=lambda t, d: (chitter(t, d, pulse(t, 1.5, 1.7, 2.4)), d.update(curl_r=0.35 + 0.2 * wave(t, 0.5) * pulse(t, 0.2, 0.6, 1.2))))


def startle(r):
    """The moment it notices (0.8 s): it drops, then jerks upright."""
    keyclip(r, "startle", KN, [
        (0.0, dict()),
        (0.1, dict(drop=0.2, lean=60.0, neck_up=14.0, level=1.0, jaw=6.0), "snap"),
        (0.4, dict(UP, stretch=0.8, hmix_r=0.4, hmix_l=0.0, head_roll=-10.0), "out"),
        (0.6, dict(hmix_r=0.0, head_roll=14.0, neck_yaw=6.0)),
        (0.8, dict(UP, head_roll=14.0, neck_yaw=6.0, sway=0.015)),
    ])


def call(r):
    """Engaged (1.2 s): arms spread, mouth wide, the chitter becomes a shriek."""
    wide = dict(UP, lean=-4.0, drop=0.0, stretch=1.0, neck_up=10.0, jaw=44.0, hc_r=(0.95, 0.25, 1.15), hc_l=(-0.95, 0.25, 1.15),
                aim_r=(0.8, 0.3, -0.5), aim_l=(-0.8, 0.3, -0.5), pole_r=(0.2, -1.0, -0.3), pole_l=(-0.2, -1.0, -0.3),
                curl_r=0.1, curl_l=0.1, spread_r=1.0, spread_l=1.0)

    def more(t, d):
        k = pulse(t, 0.3, 0.5, 1.0)
        d["jaw"] += 4.0 * k * wave(t, 0.07)
        d["head_roll"] += 5.0 * k * wave(t, 0.13)
        d["bob"] += 0.006 * k * wave(t, 0.07)
    keyclip(r, "call", UP, [
        (0.0, dict(head_roll=14.0, neck_yaw=6.0)),
        (0.22, dict(lean=26.0, drop=0.12, head_roll=0.0, neck_yaw=0.0, jaw=8.0, hc_r=(0.3, 0.2, 0.6), hc_l=(-0.3, 0.2, 0.6))),
        (0.42, wide, "out"),
        (0.95, dict(lean=-6.0, jaw=48.0)),
        (1.2, dict(KN, jaw=10.0), "slow"),
    ], more=more)


# ------------------------------------------------------------------ gaits

def _snap(speed, stride):
    T = max(int(round(stride / speed * rig.FPS)), 2) / rig.FPS
    return T, speed * T


def _gait_upper(r, speed, stride, duty, lean, drop, sway, bob, twist, hip_roll, hands, lift, mid_y, level=None, jaw=0.0, head=None):
    """The body over a knuckle gait. `hands`: {side: phase} plants the fists like feet."""
    T, stride = _snap(speed, stride)
    sweep = duty * stride

    def fist(side, ph):
        s = rig.side_sign(side)
        u = (ph - hands[side]) % 1.0
        x = FIST_R[0] * s
        if u < duty:
            return (x, mid_y + sweep / 2 - sweep * u / duty, FIST_R[2]), 0.0
        k = (u - duty) / (1.0 - duty)
        return (x + 0.03 * s * math.sin(math.pi * k), mid_y - sweep / 2 + sweep * (smooth(k) * 0.85 + k * 0.15),
                FIST_R[2] + lift * math.sin(math.pi * k) ** 0.8), math.sin(math.pi * k)

    def upper(t, ph, p):
        step = math.sin(2 * math.pi * ph)            # +1 as the right foot carries, -1 the left
        d = dict(KN)
        d.update(lean=lean, drop=drop, sway=sway * math.sin(2 * math.pi * (ph + 0.12)), bob=bob * math.cos(4 * math.pi * (ph + 0.06)),
                 body_yaw=twist * math.cos(2 * math.pi * ph), spine_yaw=-1.8 * twist * math.cos(2 * math.pi * ph),
                 pelvis_roll=hip_roll * step, chest_roll=-1.6 * hip_roll * step, jaw=jaw,
                 neck_yaw=0.8 * twist * math.cos(2 * math.pi * ph))
        if level is not None:
            d["level"] = level
        for side in ("r", "l"):
            pos, up = fist(side, ph)
            d[f"hw_{side}"] = pos
            d[f"curl_{side}"] = 0.9 - 0.3 * up
            d[f"aim_{side}"] = (0.0, 0.35 + 0.6 * up, -1.0)
        if head is not None:
            head(t, ph, d)
        q = pose(r, d)
        for k in ("body_loc", "body_rot", "fk", "offsets", "hands", "curl", "keys", "wind"):
            setattr(p, k, getattr(q, k))
    return upper


def walk(r):
    """The knuckle lope: 2 m/s, the shoulders rolling, the head bobbing ahead of it."""
    return r.gait("walk", speed=2.0, stride=1.2, duty=0.6, phases={"r": 0.0, "l": 0.5}, lift=0.08,
                  upper=_gait_upper(r, 2.0, 1.2, 0.6, lean=55.0, drop=0.12, sway=0.035, bob=0.02, twist=6.0, hip_roll=5.0,
                                    hands={"r": 0.42, "l": 0.92}, lift=0.12, mid_y=0.62),
                  stance_y=0.04, heel_off=24.0, swing_heel=16.0, toe_swing=-16.0, yaw=18.0, width=0.19)


def run(r):
    """Closing or fleeing: a bounding knuckle-gallop at 6.5 m/s, both fists then both feet."""
    return r.gait("run", speed=6.5, stride=2.2, duty=0.34, phases={"r": 0.0, "l": 0.12}, lift=0.2,
                  upper=_gait_upper(r, 6.5, 2.2, 0.34, lean=58.0, drop=0.14, sway=0.02, bob=0.06, twist=3.0, hip_roll=3.0,
                                    hands={"r": 0.5, "l": 0.62}, lift=0.26, mid_y=0.66, jaw=14.0),
                  stance_y=0.0, heel_off=30.0, swing_heel=34.0, toe_swing=-26.0, yaw=14.0, width=0.19)


def stalk(r):
    """Searching: low and slow on its knuckles toward the sound, the head sweeping."""
    def head(t, ph, d):
        d["neck_yaw"] += 16.0 * math.sin(2 * math.pi * ph)
        d["head_roll"] = 6.0 * math.sin(2 * math.pi * ph + 1.0)
    return r.gait("stalk", speed=1.0, stride=0.9, duty=0.7, phases={"r": 0.0, "l": 0.5}, lift=0.05,
                  upper=_gait_upper(r, 1.0, 0.9, 0.7, lean=62.0, drop=0.24, sway=0.03, bob=0.008, twist=4.0, hip_roll=3.0,
                                    hands={"r": 0.4, "l": 0.9}, lift=0.07, mid_y=0.62, level=1.0, head=head),
                  stance_y=0.04, heel_off=18.0, swing_heel=8.0, toe_swing=-10.0, yaw=20.0, width=0.2)


# ------------------------------------------------------------------ the routine

def forage(r):
    """Nose down, one hand digging: it turns a stone over and paws under it."""
    T = 4.0
    low = dict(KN, lean=64.0, drop=0.26, level=0.3, neck_up=-6.0)

    def more(t, d):
        k = pulse(t, 0.5, 0.9, 2.2)                                # the scrabble
        a = wave(t, 0.22)
        x, y, z = d["hw_r"]
        d["hw_r"] = (x + 0.02 * k * a, y - 0.07 * k * a, z + 0.03 * k * abs(a))
        d["curl_r"] += 0.25 * k * a
        d["neck_yaw"] += 3.0 * k * a
        chitter(t, d, 0.4 * pulse(t, 2.6, 2.9, 3.6))
    keyclip(r, "forage", low, [
        (0.0, dict(neck_yaw=10.0)),
        (0.5, dict(hw_r=(0.16, 0.86, 0.12), aim_r=(-0.2, 1.0, -0.6), curl_r=0.4, spread_r=0.6, neck_yaw=-8.0, spine_yaw=6.0)),
        (2.2, dict(hw_r=(0.14, 0.9, 0.1), neck_yaw=-10.0)),
        (2.5, dict(hw_r=(0.2, 0.74, 0.34), aim_r=(-0.6, 0.5, 0.5), curl_r=0.7, spread_r=0.2, level=0.6, neck_yaw=-16.0, head_roll=10.0,
                   lean=58.0), "out"),                                                       # holds it up to look
        (3.2, dict(head_roll=-8.0)),
        (3.6, dict(hw_r=FIST_R, aim_r=DOWN_R, curl_r=0.9, spread_r=0.0, level=0.3, neck_yaw=6.0, head_roll=0.0, spine_yaw=0.0, lean=64.0)),
        (T, dict(neck_yaw=10.0)),
    ], loop=True, more=more, breath=0.8, period=2.0, blinks=(2.7,))


def squabble(r):
    """Two of them over one scrap, each playing this at the other: up off the
    knuckles, a shriek in its face, a two-handed shove, a cuff, and down."""
    def more(t, d):
        chitter(t, d, pulse(t, 0.15, 0.4, 0.8) + pulse(t, 1.1, 1.3, 1.7), rate=0.07)
    keyclip(r, "squabble", KN, [
        (0.0, dict()),
        (0.25, dict(lean=22.0, drop=0.06, level=1.0, stretch=0.6, neck_up=-6.0, jaw=26.0, hmix_r=0.0, hmix_l=0.0, hc_r=(0.34, 0.3, 0.95),
                    hc_l=(-0.34, 0.3, 0.95), aim_r=(0.0, 1.0, 0.3), aim_l=(0.0, 1.0, 0.3), curl_r=0.2, curl_l=0.2, spread_r=0.8, spread_l=0.8), "out"),
        (0.55, dict(lean=14.0, hc_r=(0.3, 0.2, 1.1), hc_l=(-0.3, 0.2, 1.1))),                                      # gathers
        (0.68, dict(lean=34.0, fwd=0.1, hc_r=(0.22, 0.9, 1.15), hc_l=(-0.22, 0.9, 1.15), jaw=34.0), "whip"),       # shoves
        (0.95, dict(lean=20.0, fwd=0.0, hc_l=(-0.4, 0.3, 0.8), hc_r=(0.6, -0.1, 1.5), aim_r=(0.3, 0.2, 1.0), spine_yaw=-22.0, jaw=14.0)),
        (1.12, dict(spine_yaw=24.0, hc_r=(-0.1, 0.85, 1.1), aim_r=(-1.0, 0.5, -0.2), lean=30.0, jaw=30.0), "whip"),  # cuffs
        (1.45, dict(spine_yaw=8.0, hc_r=(0.2, 0.5, 0.8), jaw=16.0)),
        (1.9, dict(KN), "slow"),
    ], more=more)


def grab_shiny(r):
    """Something glints: it pounces on it, snatches it up, turns its back on the
    others and hunches over it."""
    held = dict(hmix_r=0.0, hc_r=(0.12, 0.3, 1.16), aim_r=(-0.8, 0.3, 0.5), pole_r=(1.0, -0.4, -0.5), curl_r=0.85, spread_r=0.0)
    keyclip(r, "grab_shiny", KN, [
        (0.0, dict()),
        (0.14, dict(level=1.0, neck_up=10.0, head_roll=10.0), "snap"),
        (0.4, dict(lean=66.0, drop=0.3, fwd=0.12, hw_r=(0.1, 1.0, 0.1), aim_r=(-0.1, 1.0, -0.5), curl_r=0.1, spread_r=1.0, level=0.5,
                   neck_up=0.0, head_roll=0.0), "whip"),
        (0.5, dict(curl_r=0.9, spread_r=0.0)),
        (0.9, dict(held, lean=30.0, drop=0.2, fwd=0.0, level=0.2, neck_up=-14.0, spine_yaw=26.0, body_yaw=10.0, neck_yaw=10.0,
                   hw_l=(-0.34, 0.5, 0.15)), "out"),
        (1.3, dict(neck_yaw=-34.0, level=0.6, neck_up=0.0, head_roll=-8.0), "snap"),         # a look over its shoulder
        (1.6, dict(neck_yaw=4.0, level=0.2, neck_up=-14.0, head_roll=6.0)),
        (2.0, dict(curl_r=0.7)),
    ], more=lambda t, d: chitter(t, d, 0.6 * pulse(t, 1.5, 1.7, 2.0)), blinks=(1.0,))


# ------------------------------------------------------------------ attacks

def rake(r):
    """8 claw, light. It stands and one long arm draws back and up (0.45 s);
    then the hand comes down and across."""
    back = dict(UP, lean=4.0, drop=0.05, spine_yaw=-34.0, body_yaw=-8.0, sway=-0.04, neck_yaw=22.0, jaw=14.0, stretch=0.5,
                hc_r=(0.75, -0.5, 1.6), aim_r=(0.4, -0.6, 0.7), pole_r=(1.0, -0.2, -0.4), curl_r=0.35, spread_r=1.0,
                hc_l=(-0.3, 0.3, 0.75), pole_l=(-0.7, -1.0, 0.0))
    keyclip(r, "telegraph_gloamer_rake", KN, [
        (0.0, dict()),
        (0.16, dict(lean=30.0, drop=0.08, level=1.0, hmix_l=0.0, hc_l=(-0.32, 0.25, 0.6), hw_r=(0.4, 0.3, 0.4), spine_yaw=-10.0), "out"),
        (0.38, back, "out"),
        (0.45, dict(spine_yaw=-38.0, hc_r=(0.78, -0.56, 1.64))),
    ])
    keyclip(r, "attack_gloamer_rake", UP, [
        (0.0, dict(back, spine_yaw=-38.0, hc_r=(0.78, -0.56, 1.64))),
        (0.067, dict(spine_yaw=-8.0, body_yaw=0.0, fwd=0.14, lean=20.0, hc_r=(0.5, 0.7, 1.5), aim_r=(0.0, 1.0, 0.0), jaw=30.0), "whip"),
        (0.133, dict(spine_yaw=24.0, body_yaw=8.0, fwd=0.3, lean=32.0, sway=0.04, hc_r=(-0.05, 0.95, 0.95), aim_r=(-0.6, 0.6, -0.5),
                     curl_r=0.5), "lin"),
        (0.26, dict(spine_yaw=40.0, lean=40.0, hc_r=(-0.45, 0.55, 0.5), aim_r=(-0.8, 0.0, -0.6), jaw=18.0), "out"),
        (0.7, dict(KN, fwd=0.3), "smooth"),
    ], contact=0.133, travel=0.3)


def shove(r):
    """12 blunt, medium, knocks her back. Both arms pull in and it hunches
    (0.6 s); then both palms go out with its whole weight behind them."""
    hunch = dict(UP, lean=36.0, drop=0.2, bend=14.0, level=1.0, neck_up=-8.0, jaw=4.0, fwd=-0.08,
                 hc_r=(0.2, 0.22, 0.98), hc_l=(-0.2, 0.22, 0.98), aim_r=(0.1, 0.8, 0.6), aim_l=(-0.1, 0.8, 0.6),
                 pole_r=(1.0, -0.6, -0.2), pole_l=(-1.0, -0.6, -0.2), curl_r=0.2, curl_l=0.2, spread_r=0.9, spread_l=0.9)
    keyclip(r, "telegraph_gloamer_shove", KN, [
        (0.0, dict()),
        (0.2, dict(lean=44.0, drop=0.14, hmix_r=0.0, hmix_l=0.0, hc_r=(0.3, 0.3, 0.7), hc_l=(-0.3, 0.3, 0.7), level=1.0), "out"),
        (0.5, hunch, "out"),
        (0.6, dict(drop=0.23, fwd=-0.1, bend=17.0)),
    ])
    keyclip(r, "attack_gloamer_shove", UP, [
        (0.0, dict(hunch, drop=0.23, fwd=-0.1, bend=17.0)),
        (0.133, dict(lean=38.0, drop=0.1, bend=0.0, fwd=0.5, neck_up=6.0, jaw=32.0, hc_r=(0.2, 1.05, 1.12), hc_l=(-0.2, 1.05, 1.12),
                     aim_r=(0.0, 0.7, 0.7), aim_l=(0.0, 0.7, 0.7), f_r=(0.03, 0.45, 0.0), f_l=(-0.03, 0.2, 0.0)), "whip"),
        (0.3, dict(lean=44.0, fwd=0.55, hc_r=(0.24, 0.95, 0.95), hc_l=(-0.24, 0.95, 0.95), jaw=20.0), "out"),
        (0.8, dict(KN, fwd=0.5, f_r=(0.03, 0.5, 0.0), f_l=(-0.03, 0.5, 0.0)), "smooth"),
    ], contact=0.133, travel=0.5)


def recover(r):
    """It backs off after a strike: two quick scuttles backward, watching her."""
    keyclip(r, "recover", KN, [
        (0.0, dict()),
        (0.18, dict(fwd=-0.2, drop=0.16, level=1.0, hw_r=(0.3, 0.5, 0.26), f_l=(-0.03, -0.18, 0.08), heel_l=40.0), "out"),
        (0.36, dict(fwd=-0.4, hw_r=(0.3, 0.3, 0.15), f_l=(-0.03, -0.4, 0.0), heel_l=None, hw_l=(-0.3, 0.42, 0.26), f_r=(0.03, -0.2, 0.08), heel_r=40.0)),
        (0.56, dict(fwd=-0.62, hw_l=(-0.3, 0.1, 0.15), f_r=(0.03, -0.52, 0.0), heel_r=None, hw_r=(0.3, 0.22, 0.26), f_l=(-0.03, -0.55, 0.08), heel_l=40.0)),
        (0.8, dict(KN, fwd=-0.8, f_r=(0.03, -0.8, 0.0), f_l=(-0.03, -0.8, 0.0), hw_r=(0.3, -0.2, 0.15), hw_l=(-0.3, -0.2, 0.15), jaw=8.0)),
    ], travel=-0.8, more=lambda t, d: chitter(t, d, 0.5 * pulse(t, 0.4, 0.6, 0.8)))


# ------------------------------------------------------------------ hurt, asleep, burning

def hit(r):
    """A squeal and a flinch from the struck side (hit_l: struck on its left). 0.25 s."""
    for side in ("l", "r"):
        keys = [
            (0.0, dict()),
            (0.07, dict(sway=0.05, spine_roll=10.0, spine_yaw=-12.0, neck_roll=-14.0, head_yaw=-18.0, drop=0.18, jaw=28.0,
                        lid_r=0.7, lid_l=0.7, hw_l=(-0.32, 0.56, 0.28), curl_l=0.6), "snap"),
            (0.25, dict(KN, jaw=6.0)),
        ]
        if side == "r":
            keys = [(k[0], biped.mirrored(k[1])) + tuple(k[2:]) for k in keys]
        keyclip(r, f"hit_{side}", KN, keys)


def stagger(r):
    """Knocked off its knuckles: it reels back on its short legs, arms wheeling,
    and drops down again. Its attack is lost."""
    keyclip(r, "stagger", KN, [
        (0.0, dict()),
        (0.12, dict(lean=14.0, drop=0.1, fwd=-0.1, level=1.0, neck_up=-18.0, jaw=34.0, spine_yaw=-14.0, hmix_r=0.0, hmix_l=0.0,
                    hc_r=(0.8, 0.2, 1.2), hc_l=(-0.85, 0.0, 1.45), aim_r=(0.7, 0.4, 0.2), aim_l=(-0.8, 0.2, 0.4),
                    curl_r=0.2, curl_l=0.1, spread_r=1.0, spread_l=1.0), "snap"),
        (0.35, dict(fwd=-0.28, lean=4.0, f_l=(-0.04, -0.3, 0.08), heel_l=44.0, sway=0.05, hc_r=(0.7, 0.4, 1.5), hc_l=(-0.8, 0.3, 1.0))),
        (0.52, dict(fwd=-0.4, f_l=(-0.04, -0.46, 0.0), heel_l=None, f_r=(0.04, -0.2, 0.08), heel_r=44.0, sway=-0.04, lean=16.0,
                    hc_r=(0.8, 0.1, 1.0), hc_l=(-0.7, 0.4, 1.4))),
        (0.7, dict(f_r=(0.04, -0.44, 0.0), heel_r=None, lean=36.0, neck_up=0.0, jaw=14.0, sway=0.0, fwd=-0.46)),
        (1.0, dict(KN, fwd=-0.5, f_r=(0.03, -0.5, 0.0), f_l=(-0.03, -0.5, 0.0), hw_r=(0.3, 0.1, 0.15), hw_l=(-0.3, 0.1, 0.15))),
    ], travel=-0.5, more=lambda t, d: d.update(head_roll=8.0 * ring(t, 0.12, 1.0, 4.0, 4.0)))


def sleep_fall(r):
    """A sleep arrow: it sways, its eyes roll shut and it folds up where it stands."""
    keyclip(r, "sleep_fall", KN, [
        (0.0, dict()),
        (0.3, dict(lid_r=0.8, lid_l=0.9, level=0.3, neck_up=-10.0, head_roll=12.0, jaw=8.0, drop=0.16, sway=0.03)),
        (0.9, dict(lean=38.0, body_pitch=22.0, drop=0.36, fmix_r=0.7, fmix_l=0.7, fc_r=SLEEP["fc_r"], fc_l=SLEEP["fc_l"],
                   knee_r=SLEEP["knee_r"], knee_l=SLEEP["knee_l"], heel_r=50.0, heel_l=50.0, lid_r=1.0, lid_l=1.0, level=0.1,
                   hw_r=(0.3, 0.7, 0.12), hw_l=(-0.3, 0.7, 0.12)), "slow"),
        (1.4, dict(SLEEP), "smooth"),
        (1.6, dict()),
    ], more=lambda t, d: d.update(ground=smooth(seg(t, 0.6, 1.2))))


def sleep(r):
    """Curled in a ball, breathing fast and shallow, a finger twitching."""
    keyclip(r, "sleep", SLEEP, [(0.0, dict()), (2.0, dict(jaw=7.0)), (4.0, dict(jaw=4.0))], loop=True, breath=1.6, period=2.0,
            more=lambda t, d: d.update(curl_l=0.55 + 0.2 * pulse(t, 2.6, 2.75, 3.1)))


def wake(r):
    """It uncurls all at once and is on its knuckles, looking for what woke it."""
    keyclip(r, "wake", SLEEP, [
        (0.0, dict()),
        (0.25, dict(lid_r=0.0, lid_l=0.0, neck_yaw=10.0, head_roll=-8.0, neck_up=6.0), "snap"),
        (0.8, dict(body_pitch=14.0, lean=40.0, bend=6.0, neck_yaw=0.0, head_roll=0.0, level=0.7, jaw=2.0, hw_r=(0.3, 0.66, 0.15),
                   hw_l=(-0.3, 0.66, 0.15), aim_r=DOWN_R, aim_l=DOWN_L, curl_r=0.9, curl_l=0.9, fc_r=(0.08, 0.2, 0.3), fc_l=(-0.08, 0.2, 0.3),
                   heel_r=40.0, heel_l=40.0), "out"),
        (1.3, dict(KN, level=1.0, neck_yaw=-26.0), "smooth"),
        (1.55, dict(neck_yaw=24.0), "snap"),
        (1.8, dict(KN)),
    ], more=lambda t, d: d.update(ground=1.0 - smooth(seg(t, 0.5, 1.1))))


def burn(r):
    """On fire: upright, beating at itself with both hands, hopping from foot to foot, shrieking."""
    T = 1.0

    def more(t, d):
        ph = (t / T) % 1.0
        a = wave(t, T / 2)                                  # hands alternate, a slap each 0.5 s
        d["hc_r"] = (-0.08 + 0.2 * (a < 0), 0.24, 1.4 - 0.4 * (a < 0) + 0.06 * a)
        d["hc_l"] = (0.08 - 0.2 * (a > 0), 0.24, 1.4 - 0.4 * (a > 0) - 0.06 * a)
        d["spine_yaw"] = 20.0 * wave(t, T)
        d["neck_yaw"] = -24.0 * wave(t, T, 0.1)
        d["head_roll"] = 12.0 * wave(t, T / 2, 0.2)
        for side, off in (("r", 0.0), ("l", 0.5)):
            u = (ph * 2 + off) % 1.0
            up = pulse(u, 0.0, 0.3, 0.6)
            s = 1.0 if side == "r" else -1.0
            d[f"f_{side}"] = (s * 0.04, 0.0, 0.12 * up)
            d[f"heel_{side}"] = 30.0 + 26.0 * up
        d["bob"] = 0.02 * wave(t, T / 4)
        d["sway"] = 0.04 * wave(t, T, 0.2)
        d["jaw"] = 36.0 + 6.0 * wave(t, 0.08)
    keyclip(r, "burn", BASE, [(0.0, dict(lean=20.0, drop=0.08, level=0.9, aim_r=(-0.7, -0.5, 0.3), aim_l=(0.7, -0.5, 0.3),
                                         curl_r=0.2, curl_l=0.2, spread_r=0.9, spread_l=0.9, pole_r=(0.8, 0.2, -1.0), pole_l=(-0.8, 0.2, -1.0))),
                              (T, dict())], loop=True, more=more)


def death(r):
    """It collapses in a heap of limbs (death_l: onto its left); the last frame holds."""
    for side in ("l", "r"):
        s = 1.0 if side == "r" else -1.0
        down = lying(side)
        m = (lambda d: d) if side == "r" else biped.mirrored
        keys = [
            (0.0, dict()),
            (0.12, m(dict(lean=24.0, drop=0.1, level=1.0, neck_up=-20.0, jaw=36.0, spine_roll=10.0, hmix_l=0.0, hmix_r=0.0,
                          hc_l=(-0.8, 0.1, 1.3), hc_r=(0.6, 0.3, 0.9), aim_l=(-0.6, 0.4, 0.3), curl_l=0.1, spread_l=1.0, sway=0.04)), "snap"),
            (0.5, m(dict(lean=30.0, drop=0.22, sway=0.14, body_roll=18.0, spine_roll=14.0, neck_roll=-14.0, jaw=24.0, lid_r=0.4, lid_l=0.4,
                         hc_l=(-0.5, 0.3, 0.8), hc_r=(0.5, 0.3, 0.7)))),
            (0.85, m(dict(drop=0.4, sway=0.32, body_roll=50.0, lean=16.0, fmix_r=0.6, fmix_l=0.6,
                          fc_r=lying("r")["fc_r"], fc_l=lying("r")["fc_l"], heel_r=40.0, heel_l=44.0)), "slow"),
            (1.05, dict(down, sway=0.5 * s, jaw=26.0), "lin"),
            (1.5, dict(jaw=18.0, curl_r=0.7, curl_l=0.7)),
            (2.2, dict(jaw=14.0, lid_r=0.7, lid_l=0.7)),
        ]

        def more(t, d):
            d["ground"] = max(d["ground"], smooth(seg(t, 0.7, 1.0)))
            d["bob"] += 0.02 * abs(ring(t, 1.05, 1.0, 3.0, 6.0))
        keyclip(r, f"death_{side}", KN, keys, more=more)


def death_throat(r):
    """The throat: it rears up clutching at it with both hands, coughs wetly,
    sits down hard and folds over its knees."""
    clutch = dict(hmix_r=0.0, hmix_l=0.0, hc_r=(0.07, 0.2, 1.34), hc_l=(-0.07, 0.22, 1.3), aim_r=(-0.8, 0.0, 0.6), aim_l=(0.8, 0.0, 0.6),
                  pole_r=(1.0, -0.2, -0.6), pole_l=(-1.0, -0.2, -0.6), curl_r=0.7, curl_l=0.7, spread_r=0.3, spread_l=0.3)

    def more(t, d):
        c = pulse(t, 0.5, 0.7, 1.5)                                      # the cough
        d["bend"] += 8.0 * c * (wave(t, 0.28) * 0.5 + 0.5)
        d["jaw"] += 10.0 * c * (wave(t, 0.28) * 0.5 + 0.5)
        d["ground"] = max(d["ground"], smooth(seg(t, 1.3, 1.7)))
        d["bob"] += 0.02 * abs(ring(t, 1.7, 1.0, 3.0, 6.0))
    keyclip(r, "death_throat", KN, [
        (0.0, dict()),
        (0.14, dict(UP, **clutch, lean=-6.0, stretch=0.9, neck_up=18.0, jaw=40.0, drop=0.0), "snap"),
        (0.6, dict(lean=6.0, neck_up=6.0, sway=0.05, f_l=(-0.04, -0.14, 0.0), jaw=30.0)),
        (1.2, dict(lean=16.0, sway=-0.04, neck_up=-6.0, drop=0.14, jaw=22.0, lid_r=0.4, lid_l=0.4)),
        (1.7, dict(lean=26.0, drop=0.5, fmix_r=1.0, fmix_l=1.0, fc_r=(0.1, 0.3, 0.42), fc_l=(-0.1, 0.3, 0.42), knee_r=(0.9, 0.5, 1.0),
                   knee_l=(-0.9, 0.5, 1.0), heel_r=20.0, heel_l=20.0, level=0.5), "slow"),          # sits down hard
        (2.3, dict(lean=44.0, bend=22.0, level=0.0, neck_up=-14.0, jaw=12.0, lid_r=0.8, lid_l=0.8, hc_r=(0.2, 0.5, 0.6),
                   hc_l=(-0.16, 0.5, 0.56), curl_r=0.4, curl_l=0.4), "slow"),                      # folds over its knees
        (2.8, dict(head_roll=16.0, lid_r=1.0, lid_l=1.0, jaw=8.0)),
    ], more=more)
