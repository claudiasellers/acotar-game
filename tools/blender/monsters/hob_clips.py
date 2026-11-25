"""The Hollow Hob's clips (bestiary §10.4): names, lengths and wind-up times
are the guide's. Each clip is a table of key postures (biped.Keys) with a
little motion on top where a formula says it better (breath, a blink, a
tremble).

It is very heavy and very old: nothing starts quickly, everything lands hard.
Three postures carry most of it: on its knuckles (KN), seated (SIT) and
asleep, face down, a mossy mound (SLEEP).

`eye_open` and `hum` are overlays: they key only the bones they name (a lid
and the brow; the chest, head and mantle) and leave the rest at rest.
"""

import math
import os

from mathutils import Vector

import biped
import rig
from biped import Keys
from rig import pulse, ring, seg, smooth, wave

SPINE = ("spine", "spine2", "chest")
NECK = ("neck",)
LID_SHUT = 82.0        # degrees of `eyelid_*` pitch that close the eye
MOSS = ("moss_0", "moss_1", "moss_2", "moss_3", "moss_4", "moss_5", "moss_6")

REST_R, REST_L = (1.76, 0.02, 1.22), (-1.76, 0.02, 1.22)
BASE = dict(biped.BASE)
BASE.update(foot_yaw=16.0, hc_r=REST_R, hc_l=REST_L, lid_r=0.0, lid_l=0.0, brow=0.0, puff=0.0)

# On its knuckles: bent far forward from the hips, the arms straight props, the
# small head carried low between the shoulders and tipped up to look ahead.
FIST_R, FIST_L = (1.08, 1.12, 0.36), (-1.08, 1.12, 0.36)
DOWN_R, DOWN_L = (0.0, 0.35, -1.0), (0.0, 0.35, -1.0)
KN = dict(BASE)
KN.update(lean=63.0, drop=0.24, level=0.72, f_r=(0.12, 0.0, 0.0), f_l=(-0.12, 0.0, 0.0),
          hmix_r=1.0, hmix_l=1.0, hw_r=FIST_R, hw_l=FIST_L, aim_r=DOWN_R, aim_l=DOWN_L,
          pole_r=(1.0, -0.5, 0.3), pole_l=(-1.0, -0.5, 0.3), curl_r=0.9, curl_l=0.9, spread_r=0.0, spread_l=0.0, brow=0.3)

# Seated: slumped on its haunches, knees up, fists on the ground beside them.
SIT = dict(BASE)
SIT.update(lean=30.0, body_pitch=-6.0, level=0.6, ground=1.0, fmix_r=1.0, fmix_l=1.0,
           fc_r=(0.38, 1.0, 1.5), fc_l=(-0.38, 1.0, 1.5), knee_r=(0.9, 0.5, 1.0), knee_l=(-0.9, 0.5, 1.0), heel_r=16.0, heel_l=16.0,
           hmix_r=1.0, hmix_l=1.0, hw_r=(1.3, 0.75, 0.36), hw_l=(-1.3, 0.75, 0.36), aim_r=DOWN_R, aim_l=DOWN_L,
           pole_r=(1.0, -0.6, 0.2), pole_l=(-1.0, -0.6, 0.2), curl_r=0.8, curl_l=0.8, spread_r=0.0, spread_l=0.0, brow=0.2)
# ...and sat up, head high, tasting the air
SITUP = dict(SIT)
SITUP.update(lean=14.0, body_pitch=-2.0, level=1.0, stretch=0.6, neck_up=10.0, brow=-0.4)

# Asleep: face down over its folded legs, arms folded under its head, the
# mossy back uppermost. From 30 m it is a mound.
SLEEP = dict(BASE)
SLEEP.update(lean=24.0, body_pitch=62.0, bend=20.0, level=0.0, neck_up=-4.0, neck_yaw=38.0, head_roll=-30.0, ground=1.0,
             fmix_r=1.0, fmix_l=1.0, fc_r=(0.3, 0.35, 1.2), fc_l=(-0.3, 0.35, 1.2), knee_r=(1.0, 0.7, 0.6), knee_l=(-1.0, 0.7, 0.6),
             heel_r=66.0, heel_l=66.0, hmix_r=1.0, hmix_l=1.0, hw_r=(0.75, 2.5, 0.22), hw_l=(-0.55, 2.75, 0.22),
             aim_r=(-0.7, 0.7, -0.1), aim_l=(0.7, 0.7, -0.1), pole_r=(1.0, -0.2, 0.25), pole_l=(-1.0, -0.2, 0.25),
             curl_r=0.5, curl_l=0.5, lid_r=1.0, lid_l=1.0, jaw=5.0)


def lying(side):
    """Fallen on one flank (the creature's right for "r"), a hillside come down."""
    d = dict(BASE)
    d.update(body_roll=80.0, lean=0.0, ground=1.0, bend=12.0, level=0.0, neck_up=8.0, neck_roll=-14.0, head_roll=-10.0,
             fmix_r=1.0, fmix_l=1.0, fc_r=(0.1, 0.5, 0.45), fc_l=(0.5, 1.05, 0.9), heel_r=50.0, heel_l=56.0, knee_l=(0.6, 1.0, 0.2),
             hmix_r=0.0, hmix_l=0.0, hc_r=(0.7, 0.9, 4.9), hc_l=(0.4, 1.3, 2.9), aim_r=None, aim_l=None, pole_r=(0.0, -1.0, 0.0),
             pole_l=(-0.4, -0.2, -1.0), curl_r=0.4, curl_l=0.4, jaw=14.0, lid_r=0.6, lid_l=0.6)
    return d if side == "r" else biped.mirrored(d)


def pose(r, d):
    p = biped.apply(r, d, SPINE, NECK)
    for side in ("r", "l"):
        if d[f"lid_{side}"]:
            p.turn(f"eyelid_{side}", pitch=LID_SHUT * d[f"lid_{side}"])
    if d["brow"]:
        p.turn("brow", pitch=7.0 * d["brow"])
        p.stretch("brow", (0.0, 0.0, -0.012 * d["brow"]))
    if d["puff"]:
        puff(r, p, d["puff"])
    return p


def puff(r, p, amount):
    """The mantle lifts off the back as the ribs fill."""
    for i, b in enumerate(MOSS):
        out = (r.tail[b] - r.head[b]).normalized()
        k = amount * (0.5 if b == "moss_6" else 1.0)
        p.stretch(b, out * (0.045 * k))
        p.turn(b, pitch=-2.5 * k * (1 if i % 2 else -1))


def blink(t, d, *at):
    b = sum(pulse(t, s, s + 0.09, s + 0.26) for s in at)
    d["lid_r"] = max(d["lid_r"], b)
    d["lid_l"] = max(d["lid_l"], b)


def keyclip(r, name, base, keys, loop=False, more=None, after=None, contact=None, travel=None, breath=0.0, period=4.0, blinks=()):
    K = Keys(base, keys)
    T = K.duration / max(round(K.duration / period), 1)

    def fn(t):
        d = K(t)
        if breath:
            b = wave(t, T, -0.25) * 0.5 + 0.5                 # 0 empty, 1 full
            d["bend"] -= 2.6 * breath * b
            d["bob"] += 0.012 * breath * b
            d["puff"] += breath * b
        if blinks:
            blink(t, d, *blinks)
        if more is not None:
            more(t, d)
        p = pose(r, d)
        if breath:
            p.turn("chest", pitch=-2.0 * breath * (wave(t, T, -0.25) * 0.5 + 0.5))
        if after is not None:
            after(t, p)
        return p
    r.clip(name, K.duration, fn, loop=loop, contact=contact, travel=travel)


def overlay(r, name, duration, fn, loop=False):
    """A clip that leaves the body at rest and moves only what fn(t, pose) turns."""
    def frame(t):
        p = rig.Pose()
        fn(t, p)
        return p
    r.clip(name, duration, frame, loop=loop)


def author(r):
    """Keys every clip onto the rig, in the guide's order. HOB_CLIPS=a,b keys
    only those (for a quick look)."""
    only = os.environ.get("HOB_CLIPS")
    table = [("sleep", sleep), ("eye_open", eye_open), ("wake", wake), ("sit_up", sit_up), ("sniff", sniff), ("stand_roar", stand_roar),
             ("idle", idle), ("idle_stand", idle_stand), ("walk", walk), ("run", run), ("wade", wade), ("scratch", scratch),
             ("count_charms", count_charms), ("hum", hum), ("search", search), ("eat", eat), ("swat", swat), ("stomp", stomp),
             ("throw", throw), ("charm_cut_stir", charm_cut_stir), ("sleep_fall", sleep_fall), ("burn", burn), ("hit", hit),
             ("stagger", stagger), ("death", death), ("death_charm", death_charm)]
    for key, fn in table:
        if only and key not in only.split(","):
            continue
        fn(r)


# ------------------------------------------------------------------ asleep and waking

def sleep(r):
    """Slow, heavy breaths that lift the moss. The snore is the sound's."""
    keyclip(r, "sleep", SLEEP, [(0.0, dict()), (4.5, dict(jaw=9.0)), (9.0, dict(jaw=5.0))], loop=True, breath=2.2, period=4.5)


def eye_open(r):
    """One eye opens in its sleep. It has been open a while."""
    def fn(t, p):
        k = smooth(seg(t, 0.0, 0.8))
        p.turn("eyelid_r", pitch=LID_SHUT * (1.0 - k))
        p.turn("eyelid_l", pitch=LID_SHUT)
        p.turn("brow", pitch=-3.0 * k, roll=4.0 * k)
    overlay(r, "eye_open", 1.0, fn)


def wake(r):
    """Dusk: it pushes itself up off its arms and sits, yawning."""
    keyclip(r, "wake", SLEEP, [
        (0.0, dict()),
        (0.7, dict(lid_r=0.5, lid_l=0.6, neck_yaw=20.0, head_roll=-14.0, hw_r=(1.1, 1.9, 0.3), hw_l=(-1.1, 1.9, 0.3),
                   aim_r=DOWN_R, aim_l=DOWN_L, curl_r=0.8, curl_l=0.8)),
        (1.7, dict(body_pitch=22.0, lean=34.0, bend=6.0, neck_yaw=0.0, head_roll=0.0, level=0.4, lid_r=0.3, lid_l=0.3,
                   hw_r=(1.25, 1.3, 0.36), hw_l=(-1.25, 1.3, 0.36), fc_r=(0.36, 0.8, 1.4), fc_l=(-0.36, 0.8, 1.4),
                   knee_r=SIT["knee_r"], knee_l=SIT["knee_l"], heel_r=30.0, heel_l=30.0, jaw=4.0), "slow"),
        (2.4, dict(SIT, jaw=34.0, neck_up=16.0, lid_r=0.9, lid_l=0.9, brow=-0.6, lean=22.0)),         # the yawn
        (3.0, dict(jaw=38.0, neck_up=20.0)),
        (3.6, dict(SIT)),
    ], breath=0.6)


def sit_up(r):
    """Something woke it. It sits up fast for its size, head high."""
    keyclip(r, "sit_up", SLEEP, [
        (0.0, dict()),
        (0.35, dict(lid_r=0.0, lid_l=0.0, neck_yaw=10.0, head_roll=-8.0, brow=-0.6, hw_r=(1.1, 1.9, 0.3), hw_l=(-1.1, 1.9, 0.3),
                    aim_r=DOWN_R, aim_l=DOWN_L, curl_r=0.8, curl_l=0.8)),
        (1.2, dict(body_pitch=18.0, lean=30.0, bend=4.0, neck_yaw=0.0, head_roll=0.0, level=0.7, jaw=2.0,
                   hw_r=(1.25, 1.3, 0.36), hw_l=(-1.25, 1.3, 0.36), fc_r=(0.36, 0.8, 1.4), fc_l=(-0.36, 0.8, 1.4),
                   knee_r=SIT["knee_r"], knee_l=SIT["knee_l"], heel_r=30.0, heel_l=30.0), "slow"),
        (2.0, dict(SITUP)),
    ])


def sniff(r):
    """Seated, head up, turning: two short pulls of air, then a long one."""
    def more(t, d):
        s = pulse(t, 0.3, 0.42, 0.62) + pulse(t, 0.75, 0.87, 1.07) + 1.4 * pulse(t, 1.9, 2.3, 2.9)
        d["head_up"] += 5.0 * s
        d["bob"] += 0.01 * s
        d["puff"] += 0.6 * s
        d["brow"] -= 0.3 * s
    keyclip(r, "sniff", SITUP, [
        (0.0, dict(neck_yaw=-24.0, head_yaw=-8.0)),
        (1.6, dict(neck_yaw=22.0, head_yaw=8.0, head_roll=5.0)),
        (3.2, dict(neck_yaw=-24.0, head_yaw=-8.0, head_roll=0.0)),
    ], loop=True, more=more, blinks=(1.3,))


def stand_roar(r):
    """Engaged: it heaves itself up to its full height and roars (2.0 s)."""
    tall = dict(BASE, lean=-6.0, drop=0.02, level=1.0, stretch=1.0, neck_up=16.0, head_up=10.0, jaw=40.0, brow=1.0,
                f_r=(0.22, 0.0, 0.0), f_l=(-0.22, 0.0, 0.0),
                hc_r=(2.45, 0.45, 2.2), hc_l=(-2.45, 0.45, 2.2), aim_r=None, aim_l=None,
                pole_r=(0.3, -1.0, -0.2), pole_l=(-0.3, -1.0, -0.2), curl_r=0.9, curl_l=0.9, spread_r=0.0, spread_l=0.0)

    def more(t, d):
        roar = pulse(t, 0.85, 1.1, 1.75)
        d["bob"] += 0.012 * roar * wave(t, 0.09)
        d["jaw"] += 4.0 * roar * wave(t, 0.11)
        d["head_roll"] += 3.0 * roar * wave(t, 0.23)
        d["puff"] += roar
    keyclip(r, "stand_roar", SITUP, [
        (0.0, dict()),
        (0.3, dict(lean=40.0, body_pitch=0.0, brow=0.8, hw_r=(1.2, 1.1, 0.36), hw_l=(-1.2, 1.1, 0.36), level=0.5, stretch=0.0, neck_up=0.0)),
        (0.75, dict(KN, drop=0.3, lean=44.0, jaw=6.0), "slow"),
        (1.05, tall, "out"),
        (1.65, dict(lean=-9.0, neck_up=20.0, jaw=44.0)),
        (2.0, dict(KN, hw_r=FIST_R, hw_l=FIST_L, jaw=10.0, brow=0.8), "slow"),
    ], more=more)


# ------------------------------------------------------------------ idles

def idle(r):
    """Seated, slumped, in no hurry about anything."""
    T = 8.0
    keyclip(r, "idle", SIT, [
        (0.0, dict(neck_yaw=10.0)),
        (T * 0.45, dict(neck_yaw=-14.0, head_roll=-5.0, curl_r=0.9)),
        (T * 0.55, dict(neck_yaw=-14.0, head_roll=-5.0)),
        (T, dict(neck_yaw=10.0, head_roll=0.0, curl_r=0.8)),
    ], loop=True, breath=1.0, blinks=(2.1, 5.7))


def idle_stand(r):
    """On its knuckles, weight rocking from fist to fist."""
    T = 8.0
    keyclip(r, "idle_stand", KN, [
        (0.0, dict(sway=0.06, neck_yaw=12.0, spine_roll=1.5)),
        (T / 2, dict(sway=-0.06, neck_yaw=-14.0, head_roll=-4.0, spine_roll=-1.5)),
        (T, dict(sway=0.06, neck_yaw=12.0, head_roll=0.0, spine_roll=1.5)),
    ], loop=True, breath=1.0, blinks=(1.4, 5.2))


# ------------------------------------------------------------------ gaits

def _snap(speed, stride):
    T = max(int(round(stride / speed * rig.FPS)), 2) / rig.FPS
    return T, speed * T


def _gait_upper(r, base, speed, stride, duty, lean, drop, sway, bob, twist, hip_roll, hands=None, lift=0.3, mid_y=1.1, arms=None,
                level=None, jaw=0.0):
    """The body over a gait. `hands`: {side: phase} plants the fists like feet
    (a knuckle-walk); `arms(ph, d)` poses carried arms (wading)."""
    T, stride = _snap(speed, stride)
    sweep = duty * stride

    def fist(side, ph):
        s = rig.side_sign(side)
        u = (ph - hands[side]) % 1.0
        x = FIST_R[0] * s
        if u < duty:
            return (x, mid_y + sweep / 2 - sweep * u / duty, FIST_R[2]), 0.0
        k = (u - duty) / (1.0 - duty)
        return (x + 0.1 * s * math.sin(math.pi * k), mid_y - sweep / 2 + sweep * (smooth(k) * 0.85 + k * 0.15),
                FIST_R[2] + lift * math.sin(math.pi * k) ** 0.8), math.sin(math.pi * k)

    def upper(t, ph, p):
        step = math.sin(2 * math.pi * ph)            # +1 as the right foot carries, -1 the left
        d = dict(base)
        d.update(lean=lean, drop=drop, sway=sway * math.sin(2 * math.pi * (ph + 0.12)), bob=bob * math.cos(4 * math.pi * (ph + 0.06)),
                 body_yaw=twist * math.cos(2 * math.pi * ph), spine_yaw=-1.8 * twist * math.cos(2 * math.pi * ph),
                 pelvis_roll=hip_roll * step, chest_roll=-1.6 * hip_roll * step, jaw=jaw,
                 neck_yaw=0.8 * twist * math.cos(2 * math.pi * ph), puff=0.5 + 0.5 * math.cos(4 * math.pi * ph))
        if level is not None:
            d["level"] = level
        if hands:
            for side in ("r", "l"):
                pos, up = fist(side, ph)
                d[f"hw_{side}"] = pos
                d[f"curl_{side}"] = 0.9 - 0.25 * up
                d[f"aim_{side}"] = (0.0, 0.35 + 0.5 * up, -1.0)
        if arms:
            arms(ph, d)
        q = pose(r, d)
        for k in ("body_loc", "body_rot", "fk", "offsets", "hands", "curl", "keys", "wind"):
            setattr(p, k, getattr(q, k))
    return upper


def walk(r):
    """A slow knuckle-walk, the shoulders rolling: 1 m/s."""
    return r.gait("walk", speed=1.0, stride=2.0, duty=0.66, phases={"r": 0.0, "l": 0.5}, lift=0.2,
                  upper=_gait_upper(r, KN, 1.0, 2.0, 0.66, lean=64.0, drop=0.27, sway=0.1, bob=0.03, twist=5.0, hip_roll=3.5,
                                    hands={"r": 0.42, "l": 0.92}, lift=0.26),
                  stance_y=0.12, heel_off=20.0, swing_heel=10.0, toe_swing=-12.0, yaw=14.0, width=0.6)


def run(r):
    """Fleeing fire, or closing: a rolling knuckle-gallop, 4 m/s. The ground shakes."""
    return r.gait("run", speed=4.0, stride=3.6, duty=0.42, phases={"r": 0.0, "l": 0.5}, lift=0.4,
                  upper=_gait_upper(r, KN, 4.0, 3.6, 0.42, lean=66.0, drop=0.36, sway=0.07, bob=0.09, twist=7.0, hip_roll=5.0,
                                    hands={"r": 0.45, "l": 0.95}, lift=0.5, jaw=12.0),
                  stance_y=0.1, heel_off=24.0, swing_heel=22.0, toe_swing=-20.0, yaw=12.0, width=0.6)


def wade(r):
    """Through the stream, water to its thighs: upright, arms held out of it."""
    def arms(ph, d):
        sw = 0.25 * math.cos(2 * math.pi * ph)
        d.update(hmix_r=0.0, hmix_l=0.0, hc_r=(1.9, 0.35 + sw, 2.0), hc_l=(-1.9, 0.35 - sw, 2.0),
                 aim_r=None, aim_l=None, pole_r=(0.5, -1.0, 0.0), pole_l=(-0.5, -1.0, 0.0), curl_r=0.5, curl_l=0.5)
    return r.gait("wade", speed=0.8, stride=1.9, duty=0.64, phases={"r": 0.0, "l": 0.5}, lift=0.12,
                  upper=_gait_upper(r, KN, 0.8, 1.9, 0.64, lean=24.0, drop=0.2, sway=0.16, bob=0.03, twist=8.0, hip_roll=5.0,
                                    arms=arms, level=1.0),
                  stance_y=0.1, heel_off=14.0, swing_heel=6.0, toe_swing=-8.0, yaw=16.0, width=0.62)


# ------------------------------------------------------------------ the dusk routine

def scratch(r):
    """Seated: one fist comes up over the far shoulder and rakes at the moss."""
    at = dict(hmix_r=0.0, hc_r=(-0.5, 0.35, 3.75), aim_r=(-0.5, -0.8, 0.2), pole_r=(0.6, 0.6, -0.6), curl_r=0.55, spread_r=0.6,
              spine_yaw=16.0, spine_roll=-6.0, neck_yaw=-30.0, head_roll=10.0, lid_r=0.5, lid_l=0.5, brow=-0.3)

    def more(t, d):
        k = pulse(t, 0.8, 1.2, 2.5)
        a = wave(t, 0.36)
        x, y, z = d["hc_r"]
        d["hc_r"] = (x, y - 0.1 * k * a, z + 0.16 * k * a)
        d["curl_r"] += 0.2 * k * a
        d["spine_roll"] += 2.0 * k * a
    keyclip(r, "scratch", SIT, [(0.0, dict()), (0.8, at), (2.5, dict()), (3.3, dict(SIT))], more=more, breath=0.5)


def count_charms(r):
    """Seated, head bowed over the necklace: it lifts each charm in turn, turns
    it in its fingers and lets it fall. Eight charms, 0.8 s each."""
    T = 6.4
    held = dict(SIT, lean=34.0, level=0.15, neck_up=-14.0, hmix_r=0.0, aim_r=(-0.6, 0.2, 0.8), pole_r=(1.0, -0.3, -0.6),
                curl_r=0.5, spread_r=0.2, brow=-0.2, lid_r=0.25, lid_l=0.25)

    def more(t, d):
        i = int(t / 0.8) % 8
        u = (t % 0.8) / 0.8
        # along the cord: across the chest from its right to its left and back
        a = -1.0 + 2.0 * ((i if i < 4 else 7 - i) / 3.0)
        lift = pulse(u, 0.0, 0.3, 1.0)
        d["hc_r"] = (-0.3 * a + 0.05, 0.95 + 0.06 * lift, 3.0 + 0.1 * abs(a) + 0.12 * lift)
        d["curl_r"] = 0.45 + 0.3 * pulse(u, 0.1, 0.4, 0.8)
        d["neck_yaw"] = 9.0 * a
        d["head_roll"] = 4.0 * wave(t, T)
    def after(t, p):
        i = int(t / 0.8) % 8
        u = (t % 0.8) / 0.8
        order = (2, 4, 1, 3, 5, 7, 8, 6)
        p.blow(f"charm_{order[i]}", (0.0, 0.5 * pulse(u, 0.1, 0.4, 0.9), 0.0))
    keyclip(r, "count_charms", held, [(0.0, dict()), (T, dict())], loop=True, more=more, after=after, breath=0.7, blinks=(3.0,))


def hum(r):
    """It hums with its mouth closed: the chest and the moss on it, a slow nod."""
    def fn(t, p):
        b = wave(t, 4.0, -0.25) * 0.5 + 0.5
        p.turn("chest", pitch=-2.5 * b)
        p.turn("spine2", pitch=-1.0 * b)
        p.turn("neck", pitch=3.0 * wave(t, 2.0), roll=3.0 * wave(t, 4.0))
        p.turn("head", roll=4.0 * wave(t, 4.0, 0.1), pitch=2.0 * wave(t, 2.0, 0.15))
        p.turn("jaw", pitch=1.2 + 0.8 * wave(t, 1.0))
        puff(r, p, 0.6 * b + 0.25 * (wave(t, 0.5) * 0.5 + 0.5))
    overlay(r, "hum", 4.0, fn, loop=True)


def search(r):
    """A charm is missing. Bent low, grumbling, it turns stones over."""
    T = 6.0
    low = dict(KN, lean=66.0, drop=0.6, level=0.45, brow=0.9, jaw=5.0)

    def more(t, d):
        d["jaw"] += 4.0 * abs(wave(t, 0.7)) * pulse(t, 2.6, 3.4, 5.0)
        d["head_roll"] += 3.0 * wave(t, 1.5)
    keyclip(r, "search", low, [
        (0.0, dict(neck_yaw=22.0, head_yaw=8.0, sway=-0.05)),
        (1.0, dict(neck_yaw=-10.0, hw_r=(1.3, 1.5, 0.9), aim_r=(0.0, 1.0, -0.4), curl_r=0.3, spread_r=0.8, spine_yaw=-6.0, sway=-0.14)),
        (1.7, dict(hw_r=(1.5, 2.1, 0.5), aim_r=(0.0, 1.0, -0.6), curl_r=0.15, neck_yaw=-26.0, head_yaw=-10.0, spine_yaw=8.0, lean=70.0)),
        (2.1, dict(hw_r=(1.5, 2.1, 0.42), curl_r=0.7)),                                    # takes hold of the stone
        (2.9, dict(hw_r=(1.9, 1.6, 0.95), aim_r=(0.8, 0.4, -0.3), spine_yaw=-4.0, neck_yaw=-34.0, level=0.3), "slow"),   # and rolls it over
        (3.6, dict(neck_yaw=-30.0, head_roll=8.0)),
        (4.3, dict(hw_r=(1.75, 1.75, 0.5), aim_r=(0.3, 0.8, -0.6), curl_r=0.3, level=0.45)),
        (5.2, dict(hw_r=FIST_R, aim_r=DOWN_R, curl_r=0.9, spread_r=0.0, spine_yaw=0.0, neck_yaw=10.0, head_roll=0.0, lean=66.0, sway=-0.05)),
        (T, dict(neck_yaw=22.0, head_yaw=8.0)),
    ], loop=True, more=more, breath=0.6, blinks=(3.9,))


def eat(r):
    """Seated: both hands bring the sheep (a prop on `hand_r`) to its mouth; it
    bites, tears, chews."""
    up = dict(hmix_r=0.0, hmix_l=0.0, hc_r=(0.42, 1.0, 3.64), hc_l=(-0.42, 1.0, 3.64), aim_r=(-0.8, 0.1, 0.6), aim_l=(0.8, 0.1, 0.6),
              pole_r=(1.0, -0.2, -0.6), pole_l=(-1.0, -0.2, -0.6), curl_r=0.55, curl_l=0.55, lean=24.0, level=0.5, neck_up=-6.0)

    def more(t, d):
        chew = pulse(t, 2.5, 3.0, 4.6)
        d["jaw"] += 10.0 * chew * (wave(t, 0.5) * 0.5 + 0.5)
        d["head_roll"] += 3.0 * chew * wave(t, 1.0)
    keyclip(r, "eat", SIT, [
        (0.0, dict()),
        (0.9, dict(up, hc_r=(0.5, 1.1, 2.6), hc_l=(-0.5, 1.1, 2.6), jaw=4.0)),
        (1.5, dict(up, jaw=36.0, neck_up=4.0)),
        (1.8, dict(jaw=6.0, neck_up=-8.0), "whip"),                                        # the bite
        (2.2, dict(hc_r=(0.5, 1.25, 3.1), hc_l=(-0.5, 1.25, 3.1), neck_up=14.0, head_roll=-10.0, lean=18.0), "whip"),   # and the tear
        (3.2, dict(hc_r=(0.6, 1.2, 2.5), hc_l=(-0.6, 1.2, 2.5), neck_up=0.0, head_roll=0.0, lean=28.0)),
        (4.6, dict(jaw=3.0)),
        (5.4, dict(SIT)),
    ], more=more, breath=0.4, blinks=(2.9,))


# ------------------------------------------------------------------ attacks

def swat(r):
    """55 blunt, heavy. The head goes down and one arm drags back along the
    ground, scraping (0.9 s); then it comes round flat and low like a falling tree."""
    back = dict(lean=62.0, drop=0.5, level=0.35, neck_yaw=10.0, spine_yaw=-30.0, body_yaw=-8.0, sway=-0.2, brow=1.0, jaw=6.0,
                hw_r=(1.9, -1.2, 0.34), aim_r=(0.5, -1.0, -0.2), curl_r=0.35, spread_r=0.8, pole_r=(1.0, 0.0, 0.6),
                hw_l=(-0.9, 1.2, 0.36))
    keyclip(r, "telegraph_hob_swat", KN, [
        (0.0, dict()),
        (0.25, dict(level=0.35, brow=1.0, sway=-0.12, hw_r=(1.3, 0.9, 0.5), spine_yaw=-8.0, hw_l=(-0.9, 1.2, 0.36))),
        (0.75, back, "lin"),                                                                 # the drag
        (0.9, dict(hw_r=(1.95, -1.35, 0.4), spine_yaw=-33.0)),
    ], more=lambda t, d: d.update(puff=smooth(seg(t, 0.2, 0.9))))                          # the huge inhale
    keyclip(r, "attack_hob_swat", KN, [
        (0.0, dict(back, hw_r=(1.95, -1.35, 0.4), spine_yaw=-33.0)),
        (0.1, dict(spine_yaw=-6.0, body_yaw=0.0, sway=0.0, fwd=0.25, hw_r=(2.4, 1.0, 0.7), aim_r=(0.3, 1.0, 0.0), curl_r=0.2, jaw=24.0), "whip"),
        (0.2, dict(spine_yaw=26.0, body_yaw=8.0, fwd=0.45, sway=0.15, hw_r=(0.5, 3.1, 0.8), aim_r=(-1.0, 0.5, 0.0), pole_r=(0.6, -0.4, 1.0),
                   level=0.6), "lin"),
        (0.36, dict(spine_yaw=40.0, body_yaw=12.0, hw_r=(-1.5, 2.2, 1.1), aim_r=(-1.0, -0.4, 0.1), jaw=30.0), "out"),
        (0.8, dict(spine_yaw=30.0, hw_r=(-1.0, 1.9, 0.6), jaw=14.0)),
        (1.5, dict(KN, fwd=0.45, brow=0.8), "smooth"),
    ], contact=0.2, travel=0.45)


def stomp(r):
    """35 blunt, heavy, 3 m all round. It rocks onto its fists and one huge foot
    comes up (1.0 s); then down."""
    up = dict(lean=48.0, drop=0.3, sway=-0.34, spine_roll=-6.0, level=0.5, brow=1.0, f_r=(0.2, 0.35, 1.05), heel_r=58.0, toe_r=10.0,
              hw_r=(1.0, 1.25, 0.36), hw_l=(-1.2, 1.2, 0.36), jaw=8.0)
    keyclip(r, "telegraph_hob_stomp", KN, [
        (0.0, dict()),
        (0.35, dict(sway=-0.3, spine_roll=-4.0, hw_r=(1.0, 1.25, 0.36), hw_l=(-1.2, 1.2, 0.36), level=0.5)),
        (0.8, up, "out"),
        (1.0, dict(f_r=(0.2, 0.38, 1.15), drop=0.26)),
    ], more=lambda t, d: d.update(puff=smooth(seg(t, 0.3, 1.0)), bob=d["bob"] + 0.006 * wave(t, 0.08) * seg(t, 0.8, 1.0)))
    keyclip(r, "attack_hob_stomp", KN, [
        (0.0, dict(up, f_r=(0.2, 0.38, 1.15), drop=0.26)),
        (0.133, dict(f_r=(0.2, 0.5, 0.0), heel_r=None, toe_r=0.0, sway=0.05, drop=0.62, lean=58.0, spine_roll=4.0, jaw=20.0), "whip"),
        (0.4, dict(drop=0.5, jaw=12.0)),
        (1.1, dict(KN, f_r=(0.2, 0.5, 0.0))),
    ], contact=0.133, more=lambda t, d: d.update(bob=d["bob"] + 0.05 * ring(t, 0.133, 1.0, 5.0, 6.0)))


def throw(r):
    """It digs a boulder out of the ground and lifts it over its head (1.0 s);
    then both arms come down and it lets go. The rock rides `hand_r`."""
    over = dict(BASE, lean=-10.0, drop=0.06, level=1.0, neck_up=-6.0, brow=1.0, jaw=10.0, f_r=(0.2, 0.0, 0.0), f_l=(-0.2, -0.2, 0.0),
                hc_r=(0.55, -0.1, 5.25), hc_l=(-0.55, -0.1, 5.25), aim_r=(-0.5, -0.3, 0.8), aim_l=(0.5, -0.3, 0.8),
                pole_r=(1.0, 0.3, 0.0), pole_l=(-1.0, 0.3, 0.0), curl_r=0.35, curl_l=0.35, spread_r=0.8, spread_l=0.8)
    keyclip(r, "telegraph_hob_throw", KN, [
        (0.0, dict()),
        (0.3, dict(lean=64.0, drop=0.55, hw_r=(0.6, 1.7, 0.45), hw_l=(-0.6, 1.7, 0.45), aim_r=(-0.8, 0.3, -0.5), aim_l=(0.8, 0.3, -0.5),
                   curl_r=0.4, curl_l=0.4, spread_r=0.8, spread_l=0.8, level=0.3, brow=1.0)),
        (0.45, dict(drop=0.6)),
        (0.85, over, "slow"),
        (1.0, dict(lean=-14.0, hc_r=(0.55, -0.4, 5.2), hc_l=(-0.55, -0.4, 5.2))),
    ], more=lambda t, d: d.update(puff=smooth(seg(t, 0.4, 1.0))))
    keyclip(r, "attack_hob_throw", KN, [
        (0.0, dict(over, lean=-14.0, hc_r=(0.55, -0.4, 5.2), hc_l=(-0.55, -0.4, 5.2))),
        (0.2, dict(lean=34.0, drop=0.3, level=0.9, jaw=34.0, hc_r=(0.6, 1.5, 3.9), hc_l=(-0.6, 1.5, 3.9), aim_r=(-0.2, 1.0, -0.2), aim_l=(0.2, 1.0, -0.2),
                   curl_r=0.1, curl_l=0.1, spread_r=1.0, spread_l=1.0), "whip"),
        (0.45, dict(lean=58.0, drop=0.46, hc_r=(0.9, 1.3, 1.6), hc_l=(-0.9, 1.3, 1.6), aim_r=DOWN_R, aim_l=DOWN_L, jaw=20.0), "out"),
        (1.2, dict(KN, f_r=(0.2, 0.0, 0.0), f_l=(-0.2, -0.2, 0.0))),
    ], contact=0.2)


# ------------------------------------------------------------------ sleep, fire, hurt

def charm_cut_stir(r):
    """A charm is cut while it sleeps: it stirs, mumbles, paws at its neck, settles."""
    def more(t, d):
        m = pulse(t, 0.6, 1.4, 2.6)
        d["jaw"] += 6.0 * m * abs(wave(t, 0.45))
    keyclip(r, "charm_cut_stir", SLEEP, [
        (0.0, dict()),
        (0.7, dict(neck_yaw=24.0, head_roll=-18.0, neck_up=6.0, bend=16.0, lid_r=0.75, lid_l=0.85, brow=0.6)),
        (1.5, dict(hw_r=(0.5, 2.25, 0.5), curl_r=0.8, neck_yaw=30.0, bend=18.0)),
        (2.4, dict(hw_r=SLEEP["hw_r"], curl_r=0.5, neck_up=0.0, lid_r=1.0, lid_l=1.0, brow=0.0)),
        (3.5, dict(SLEEP)),
    ], more=more, breath=1.4, period=3.5)


def sleep_fall(r):
    """A sleep arrow: its eyes roll shut and it sags back down where it stands."""
    keyclip(r, "sleep_fall", KN, [
        (0.0, dict()),
        (0.5, dict(lid_r=0.8, lid_l=0.9, level=0.3, neck_up=-10.0, head_roll=10.0, jaw=8.0, drop=0.5, sway=0.06)),
        (1.3, dict(lean=40.0, body_pitch=24.0, drop=1.0, fmix_r=0.7, fmix_l=0.7, fc_r=SLEEP["fc_r"], fc_l=SLEEP["fc_l"],
                   knee_r=SLEEP["knee_r"], knee_l=SLEEP["knee_l"], heel_r=50.0, heel_l=50.0, lid_r=1.0, lid_l=1.0, level=0.1,
                   hw_r=(1.1, 1.7, 0.3), hw_l=(-1.1, 1.7, 0.3)), "slow"),
        (2.0, dict(SLEEP), "smooth"),
        (2.4, dict()),
    ], more=lambda t, d: d.update(ground=smooth(seg(t, 0.9, 1.7)), bob=d["bob"] + 0.03 * abs(ring(t, 1.9, 1.0, 3.0, 6.0))))


def burn(r):
    """On fire: half upright, slapping at its moss, stamping, bellowing."""
    T = 1.6

    def more(t, d):
        ph = (t / T) % 1.0
        a = wave(t, T / 2)                                  # hands alternate, a slap each 0.8 s
        d["hc_r"] = (-0.2 + 0.5 * (a < 0), 0.5, 3.95 - 0.5 * (a < 0) + 0.15 * a)
        d["hc_l"] = (0.2 - 0.5 * (a > 0), 0.5, 3.95 - 0.5 * (a > 0) - 0.15 * a)
        d["spine_yaw"] = 16.0 * wave(t, T)
        d["neck_yaw"] = -20.0 * wave(t, T, 0.1)
        d["head_roll"] = 9.0 * wave(t, T / 2, 0.2)
        for side, off in (("r", 0.0), ("l", 0.5)):
            u = (ph * 2 + off) % 1.0
            up = pulse(u, 0.0, 0.3, 0.6)
            s = 1.0 if side == "r" else -1.0
            d[f"f_{side}"] = (s * 0.15, 0.0, 0.3 * up)
            d[f"heel_{side}"] = 29.0 + 24.0 * up
        d["bob"] = 0.04 * wave(t, T / 4)
        d["sway"] = 0.1 * wave(t, T, 0.2)
    keyclip(r, "burn", BASE, [(0.0, dict(lean=26.0, drop=0.25, jaw=34.0, brow=-0.8, level=0.8, aim_r=(-0.7, -0.5, 0.3), aim_l=(0.7, -0.5, 0.3),
                                         curl_r=0.2, curl_l=0.2, spread_r=0.8, spread_l=0.8, pole_r=(0.8, 0.2, -1.0), pole_l=(-0.8, 0.2, -1.0))),
                              (T, dict())], loop=True, more=more)


def hit(r):
    """A heavy flinch from the struck side (hit_l: struck on its left). 0.4 s."""
    for side in ("l", "r"):
        keys = [
            (0.0, dict()),
            (0.1, dict(sway=0.1, spine_roll=7.0, spine_yaw=-9.0, neck_roll=-10.0, head_yaw=-14.0, drop=0.5, jaw=18.0, brow=1.0,
                       lid_r=0.6, lid_l=0.6, hw_l=(-1.1, 1.05, 0.55), curl_l=0.7), "snap"),
            (0.4, dict(KN, brow=0.8, jaw=6.0)),
        ]
        if side == "r":
            keys = [(k[0], biped.mirrored(k[1])) + tuple(k[2:]) for k in keys]
        keyclip(r, f"hit_{side}", KN, keys)


def stagger(r):
    """Rocked back off its fists: a step back, an arm thrown wide, and down again."""
    keyclip(r, "stagger", KN, [
        (0.0, dict()),
        (0.18, dict(lean=30.0, drop=0.3, fwd=-0.2, level=1.0, neck_up=-14.0, jaw=26.0, brow=-0.6, spine_yaw=-12.0,
                    hmix_r=0.0, hmix_l=0.0, hc_r=(2.2, 0.5, 1.9), hc_l=(-2.3, 0.2, 2.4), aim_r=(0.6, 0.6, -0.5), aim_l=(-0.7, 0.3, -0.3),
                    curl_r=0.3, curl_l=0.2, spread_l=1.0, spread_r=0.8), "snap"),
        (0.55, dict(fwd=-0.55, f_l=(-0.16, -0.75, 0.25), heel_l=50.0, sway=0.14)),
        (0.8, dict(fwd=-0.75, f_l=(-0.16, -1.0, 0.0), heel_l=None, lean=40.0, drop=0.4, f_r=(0.14, -0.4, 0.22), heel_r=48.0, sway=-0.08)),
        (1.05, dict(f_r=(0.14, -0.9, 0.0), heel_r=None, lean=52.0, neck_up=0.0, jaw=12.0, sway=0.0)),
        (1.5, dict(KN, fwd=-0.8, f_r=(0.12, -0.9, 0.0), f_l=(-0.12, -1.0, 0.0), hw_r=(1.08, 0.25, 0.36), hw_l=(-1.08, 0.25, 0.36), brow=0.8)),
    ], travel=-0.9, more=lambda t, d: d.update(head_roll=5.0 * ring(t, 0.18, 1.0, 3.0, 3.0)))


def death(r):
    """It falls like a hillside (death_l: onto its left). The ground shakes;
    the last frame holds."""
    for side in ("l", "r"):
        s = 1.0 if side == "r" else -1.0
        down = lying(side)
        m = (lambda d: d) if side == "r" else biped.mirrored
        keys = [
            (0.0, dict()),
            (0.25, m(dict(lean=40.0, drop=0.3, level=1.0, neck_up=-16.0, jaw=30.0, brow=-0.8, spine_roll=8.0, hmix_l=0.0,
                          hc_l=(-2.2, 0.3, 2.6), aim_l=(-0.6, 0.4, -0.4), curl_l=0.2, spread_l=1.0, sway=0.1)), "snap"),
            (1.0, m(dict(lean=46.0, drop=0.5, sway=0.4, body_roll=14.0, spine_roll=12.0, neck_roll=-12.0, jaw=20.0, lid_r=0.4, lid_l=0.4,
                         hw_r=(1.5, 0.9, 0.36)))),
            (1.7, m(dict(drop=0.9, sway=0.9, body_roll=46.0, lean=24.0, hmix_r=0.4, fmix_r=0.5, fmix_l=0.5,
                         fc_r=lying("r")["fc_r"], fc_l=lying("r")["fc_l"], heel_r=40.0, heel_l=44.0)), "slow"),
            (2.1, dict(down, sway=1.5 * s, jaw=22.0), "lin"),
            (2.9, dict(jaw=16.0, curl_r=0.6, curl_l=0.6)),
            (4.0, dict(jaw=12.0, lid_r=0.75, lid_l=0.75)),
        ]

        def more(t, d):
            d["ground"] = max(d["ground"], smooth(seg(t, 1.5, 2.0)))
            d["bob"] += 0.07 * abs(ring(t, 2.1, 1.0, 2.5, 4.0))
            d["bend"] += 3.0 * pulse(t, 2.1, 2.5, 3.6) * wave(t, 0.5)
        keyclip(r, f"death_{side}", KN, keys, more=more)


def death_charm(r):
    """The charm at its throat breaks. It sits back, sighs, and goes still."""
    keyclip(r, "death_charm", KN, [
        (0.0, dict()),
        (0.3, dict(level=1.0, neck_up=-10.0, brow=-1.0, jaw=12.0, hmix_r=0.0, hc_r=(0.3, 0.95, 3.05), aim_r=(-0.6, 0.2, 0.8),
                   pole_r=(1.0, -0.3, -0.6), curl_r=0.6), "out"),                         # a hand to the necklace
        (1.5, dict(SIT, lean=20.0, hmix_r=0.0, hc_r=(0.3, 0.95, 3.05), aim_r=(-0.6, 0.2, 0.8), pole_r=(1.0, -0.3, -0.6), curl_r=0.6,
                   level=0.8, brow=-1.0, jaw=8.0, ground=0.0, drop=1.45), "slow"),       # sits back, heavily
        (2.4, dict(lean=14.0, bend=-6.0, neck_up=14.0, jaw=20.0, puff=1.0)),               # the breath in
        (3.6, dict(lean=44.0, bend=14.0, level=0.0, neck_up=-16.0, jaw=6.0, puff=0.0, lid_r=0.7, lid_l=0.7, brow=0.0,
                   hmix_r=1.0, hw_r=(1.2, 1.0, 0.3), aim_r=DOWN_R, pole_r=SIT["pole_r"], curl_r=0.4, curl_l=0.4), "slow"),   # and out
        (4.6, dict(lean=50.0, head_roll=14.0, lid_r=1.0, lid_l=1.0, jaw=3.0)),
    ], more=lambda t, d: d.update(ground=smooth(seg(t, 1.0, 1.5)), bob=d["bob"] + 0.04 * abs(ring(t, 1.5, 1.0, 3.0, 6.0))))
