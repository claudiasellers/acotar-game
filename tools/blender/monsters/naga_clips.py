"""The naga's clips (bestiary §2.4): names, lengths and timings are the
guide's. Each clip is a table of key postures (biped.Keys) plus, where a
formula says it better, a little motion on top (breath, tongue, tremble).

Every move starts slow and finishes fast: hold still, then strike.
"""

import math

import biped
import rig
from biped import Keys
from rig import pulse, ring, seg, smooth, wave

SPINE = ("spine", "spine2", "chest")
NECK = ("neck", "neck2")

# The naga at ease: hips sunk on bent legs, the long torso leaning from the
# hips, the neck bent back up so the wedge of the head rides level and
# forward, arms hanging ahead of the body with the talons half open.
HANG_R, HANG_L = (0.40, 0.13, 1.0), (-0.40, 0.13, 1.0)
DOWN_R, DOWN_L = (0.15, 0.35, -1.0), (-0.15, 0.35, -1.0)
NB = dict(biped.BASE)
NB.update(lean=10.0, drop=0.035, hc_r=HANG_R, hc_l=HANG_L, aim_r=DOWN_R, aim_l=DOWN_L,
          curl_r=0.35, curl_l=0.35, f_r=(0.02, 0.03, 0), f_l=(-0.02, -0.03, 0), foot_yaw=10.0,
          k_threat=0.0, k_hiss=0.0, k_speak_open=0.0, k_blink=0.0, k_eyes_wide=0.0, k_nostrils=0.0)


def tongue(p, amount, flutter=0.0):
    """The forked tongue slides out through the lips and tastes the air."""
    if amount <= 0.0:
        return
    p.turn("jaw", pitch=2.5 * amount)
    p.stretch("tongue0", (0, 0.05 * amount, 0))
    p.stretch("tongue1", (0, 0.035 * amount, 0))
    p.stretch("tongue2", (0, 0.03 * amount, 0))
    p.turn("tongue1", pitch=-10.0 * amount * flutter)
    p.turn("tongue2", pitch=-22.0 * amount * flutter)


def flick(t, *starts):
    """Tongue amount for flicks starting at the given times."""
    return sum(pulse(t, s, s + 0.12, s + 0.42) for s in starts)


def keyclip(r, name, keys, loop=False, more=None, tongue_at=(), contact=None, travel=None, breath=0.0):
    K = Keys(NB, keys)

    def fn(t):
        d = K(t)
        if breath:
            b = wave(t, K.duration / max(round(K.duration / 2.3), 1))
            d["lean"] += 0.8 * breath * b
            d["bob"] += 0.004 * breath * b
        if more is not None:
            more(t, d)
        p = biped.apply(r, d, SPINE, NECK)
        if breath:
            p.turn("chest", pitch=-1.2 * breath * wave(t, K.duration / max(round(K.duration / 2.3), 1)))
        if tongue_at:
            tongue(p, flick(t, *tongue_at), wave(t, 0.14))
        return p
    r.clip(name, K.duration, fn, loop=loop, contact=contact, travel=travel)


def lying(side):
    """Flat on one flank (the creature's right for "r")."""
    d = dict(body_roll=72.0, lean=0.0, drop=0.0, ground=1.0, bend=8.0, level=0.0, neck_up=22.0, head_up=14.0, neck_roll=-6.0, head_roll=-8.0,
             fmix_r=1.0, fmix_l=1.0, fc_r=(0.15, 0.18, 0.21), fc_l=(0.5, 0.43, 0.41), heel_r=66.0, heel_l=72.0, knee_l=(0.8, 1.0, 0.0),
             hc_r=(0.3, 0.3, 2.05), hc_l=(0.25, 0.35, 1.55), aim_r=None, aim_l=None, pole_r=(0.0, -1.0, 0.0),
             pole_l=(-0.4, -0.2, -1.0), curl_r=0.55, curl_l=0.55, jaw=7.0, sway=0.0)
    return d if side == "r" else biped.mirrored(d)


def author(r):
    """Keys every clip onto the rig, in the guide's order."""
    idle(r)
    keyclip(r, "startle", [
        (0.0, dict(lean=17.0, drop=0.075)),
        (0.13, dict(lean=3.0, drop=0.0, stretch=1.0, neck_up=10.0, head_up=6.0, k_eyes_wide=1.0, spread_r=0.9, spread_l=0.9,
                    curl_r=0.15, curl_l=0.15), "snap"),
        (0.5, dict(neck_yaw=10.0, k_threat=0.5, k_nostrils=1.0)),
        (0.8, dict(k_threat=1.0, k_eyes_wide=0.3, jaw=5.0)),
    ], tongue_at=(0.28,))
    keyclip(r, "alert", [
        (0.0, dict(lean=4.0, drop=0.01, stretch=0.85, neck_up=8.0, head_up=4.0, neck_yaw=-26.0, k_threat=0.8, jaw=4.0, curl_r=0.2, curl_l=0.2)),
        (1.5, dict(neck_yaw=26.0, head_roll=6.0)),
        (3.0, dict(neck_yaw=-26.0, head_roll=0.0)),
    ], loop=True, tongue_at=(0.5, 2.0), breath=1.0,
        more=lambda t, d: d.update(k_nostrils=pulse(t, 0.4, 0.7, 1.2) + pulse(t, 1.9, 2.2, 2.7)))
    keyclip(r, "call", [
        (0.0, dict(lean=4.0, drop=0.01, stretch=0.8)),
        (0.22, dict(lean=16.0, drop=0.1, stretch=0.0, hc_r=(0.36, -0.05, 1.05), hc_l=(-0.36, -0.05, 1.05)), "out"),
        (0.5, dict(lean=-9.0, drop=-0.01, stretch=1.0, neck_up=24.0, head_up=18.0, jaw=44.0, k_hiss=1.0, k_eyes_wide=1.0,
                   hc_r=(0.6, -0.12, 1.1), hc_l=(-0.6, -0.12, 1.1), spread_r=1.0, spread_l=1.0, curl_r=0.0, curl_l=0.0,
                   aim_r=(0.5, 0.1, -1.0), aim_l=(-0.5, 0.1, -1.0)), "whip"),
        (1.1, dict(neck_up=28.0, jaw=47.0)),
        (1.4, dict(lean=12.0, drop=0.05, stretch=0.2, neck_up=0.0, head_up=0.0, jaw=8.0, k_hiss=0.2, k_eyes_wide=0.0, k_threat=1.0,
                   hc_r=HANG_R, hc_l=HANG_L, aim_r=DOWN_R, aim_l=DOWN_L, curl_r=0.2, curl_l=0.2)),
    ], more=lambda t, d: d.update(neck_yaw=4.0 * ring(t, 0.5, 1.0, 9.0, 1.5), bob=d["bob"] + 0.004 * ring(t, 0.5, 1.0, 14.0, 1.0)))
    walk(r)
    lope(r)
    stalk(r)
    run(r)
    swim(r)
    for side in ("l", "r"):
        dodge(r, side)
    bask(r)
    nest(r)
    sleep(r)
    claw(r)
    lunge(r)
    coil(r)
    keyclip(r, "recover", [
        (0.0, dict(lean=20.0, drop=0.12, spine_yaw=18.0, hc_r=(0.05, 0.4, 1.0), k_threat=1.0, jaw=8.0)),
        (0.3, dict(lean=6.0, drop=0.04, sway=-0.12, fwd=-0.1, spine_yaw=0.0, hc_r=HANG_R, f_r=(0.02, -0.1, 0.07), heel_r=70.0), "out"),
        (0.55, dict(sway=-0.2, fwd=-0.2, f_r=(0.0, -0.22, 0.0), heel_r=None, f_l=(-0.12, -0.03, 0.06), heel_l=68.0, neck_yaw=-14.0)),
        (0.85, dict(sway=-0.14, fwd=-0.24, f_l=(-0.2, -0.2, 0.0), heel_l=None, neck_yaw=10.0)),
        (1.4, dict(lean=17.0, drop=0.1, sway=-0.1, fwd=-0.22, neck_yaw=0.0, curl_r=0.2, curl_l=0.2, k_threat=0.6, jaw=4.0)),
    ], travel=-0.22)
    for side in ("l", "r"):
        hit(r, side)
    keyclip(r, "stagger", [
        (0.0, dict()),
        (0.12, dict(lean=-14.0, drop=0.02, fwd=-0.1, neck_up=-22.0, head_up=-14.0, jaw=24.0, k_eyes_wide=1.0, spine_yaw=-16.0,
                    hc_l=(-0.62, -0.1, 1.25), spread_l=1.0, curl_l=0.0, hc_r=(0.14, 0.2, 1.52), aim_r=(-0.6, 0.2, 0.7), curl_r=0.6), "snap"),
        (0.38, dict(fwd=-0.24, f_l=(-0.06, -0.3, 0.05), heel_l=66.0, hc_r=(0.07, 0.19, 1.63), pole_r=(1.0, -0.2, -0.6), sway=0.05)),
        (0.6, dict(fwd=-0.3, f_l=(-0.08, -0.42, 0.0), heel_l=None, lean=6.0, drop=0.1, neck_up=0.0, head_up=-8.0, f_r=(0.03, -0.12, 0.05), heel_r=64.0)),
        (0.8, dict(f_r=(0.04, -0.3, 0.0), heel_r=None, lean=16.0, jaw=12.0, k_eyes_wide=0.2, hc_l=HANG_L, curl_l=0.35, spread_l=0.3)),
        (1.0, dict(lean=14.0, drop=0.08, spine_yaw=0.0, hc_r=(0.2, 0.22, 1.3), aim_r=DOWN_R, pole_r=None, curl_r=0.4, head_up=0.0, k_threat=0.7)),
    ], travel=-0.3, more=lambda t, d: d.update(head_roll=5.0 * ring(t, 0.12, 1.0, 5.0, 3.0)))
    burn(r)
    keyclip(r, "speak", [
        (0.0, dict(lean=7.0, stretch=0.4, neck_yaw=6.0, k_threat=0.5)),
        (1.0, dict(neck_yaw=-6.0, head_roll=5.0)),
        (2.0, dict(neck_yaw=6.0, head_roll=0.0)),
    ], loop=True, tongue_at=(1.45,), breath=1.0,
        more=lambda t, d: d.update(jaw=9.0 + 8.0 * abs(wave(t, 0.5)) * (0.6 + 0.4 * wave(t, 2.0, 0.2)),
                                   k_speak_open=0.5 + 0.5 * wave(t, 0.5, 0.1), k_hiss=pulse(t, 1.3, 1.5, 1.9)))
    keyclip(r, "laugh", [
        (0.0, dict()),
        (0.2, dict(lean=4.0, neck_up=12.0, head_up=10.0, jaw=26.0, k_threat=1.0, k_speak_open=1.0, hc_r=(0.44, 0.08, 1.02), hc_l=(-0.44, 0.08, 1.02)), "out"),
        (0.95, dict(neck_up=8.0, jaw=20.0)),
        (1.2, dict(lean=10.0, neck_up=0.0, head_up=0.0, jaw=4.0, k_threat=0.5, k_speak_open=0.0, hc_r=HANG_R, hc_l=HANG_L)),
    ], more=lambda t, d: d.update(bob=d["bob"] + 0.012 * pulse(t, 0.1, 0.5, 1.1) * wave(t, 0.17),
                                  bend=d["bend"] + 3.0 * pulse(t, 0.1, 0.5, 1.1) * wave(t, 0.17, 0.25),
                                  jaw=d["jaw"] + 5.0 * pulse(t, 0.1, 0.5, 1.1) * wave(t, 0.17)))
    for side in ("l", "r"):
        death(r, side)
    death_throat(r)
    death_ash(r)


# ------------------------------------------------------------------ loops

def idle(r):
    T = 4.6
    keyclip(r, "idle", [
        (0.0, dict(sway=0.018, neck_yaw=18.0, head_yaw=4.0)),
        (T / 2, dict(sway=-0.018, neck_yaw=-20.0, head_yaw=-4.0, head_roll=-4.0, curl_r=0.45, curl_l=0.28)),
        (T, dict(sway=0.018, neck_yaw=18.0, head_yaw=4.0, head_roll=0.0, curl_r=0.35, curl_l=0.35)),
    ], loop=True, tongue_at=(1.1, 3.3), breath=1.0)


def _gait_upper(r, lean, drop, sway, bob, twist, hip_roll, swing, out=0.0, down=0.0, fwd=0.0, curl=0.4, spread=0.3,
                level=1.0, jaw=0.0, head_up=0.0, tongue_every=None):
    def upper(t, ph, p):
        step = math.sin(2 * math.pi * ph)            # +1 as the right foot carries, -1 the left
        d = dict(NB)
        d.update(lean=lean, drop=drop, sway=sway * math.sin(2 * math.pi * (ph + 0.12)), bob=bob * math.cos(4 * math.pi * (ph + 0.06)),
                 body_yaw=twist * math.cos(2 * math.pi * ph), spine_yaw=-1.6 * twist * math.cos(2 * math.pi * ph),
                 pelvis_roll=hip_roll * step, chest_roll=-1.3 * hip_roll * step, level=level, jaw=jaw, head_up=head_up,
                 curl_r=curl, curl_l=curl, spread_r=spread, spread_l=spread)
        sw = swing * math.cos(2 * math.pi * ph)
        d["hc_r"] = (HANG_R[0] + out, HANG_R[1] + fwd + sw, HANG_R[2] - down - abs(sw) * 0.2)
        d["hc_l"] = (HANG_L[0] - out, HANG_L[1] + fwd - sw, HANG_L[2] - down - abs(sw) * 0.2)
        q = biped.apply(r, d, SPINE, NECK)
        # the gait owns the feet; take everything else from the posture
        for k in ("body_loc", "body_rot", "fk", "offsets", "hands", "curl", "keys"):
            setattr(p, k, getattr(q, k))
        if tongue_every:
            tongue(p, pulse(t % tongue_every, 0.1, 0.22, 0.5), wave(t, 0.14))
    return upper


def walk(r):
    """A heel-high prowl: the shoulders roll, the head holds still."""
    return r.gait("walk", speed=1.4, stride=1.3, duty=0.62, phases={"r": 0.0, "l": 0.5}, lift=0.10,
                  upper=_gait_upper(r, lean=17.0, drop=0.075, sway=0.028, bob=0.014, twist=5.0, hip_roll=3.0, swing=0.11),
                  stance_y=0.06, heel_off=22.0, swing_heel=14.0)


def lope(r):
    """Between the prowl and the sprint: closing a gap it need not hurry over.
    Not in the guide's table; without it nothing covers 2.4 to 5.5 m/s and
    the feet slide there."""
    return r.gait("lope", speed=3.4, stride=2.0, duty=0.42, phases={"r": 0.0, "l": 0.5}, lift=0.17,
                  upper=_gait_upper(r, lean=24.0, drop=0.09, sway=0.024, bob=0.03, twist=7.0, hip_roll=4.0, swing=0.14,
                                    out=0.06, fwd=0.03, curl=0.25, spread=0.6, level=0.95, jaw=4.0),
                  stance_y=0.09, heel_off=24.0, swing_heel=22.0, toe_swing=-25.0)


def stalk(r):
    """Bent double, the head barely above the reeds, savouring it."""
    return r.gait("stalk", speed=0.8, stride=1.0, duty=0.7, phases={"r": 0.0, "l": 0.5}, lift=0.13,
                  upper=_gait_upper(r, lean=44.0, drop=0.2, sway=0.035, bob=0.008, twist=7.0, hip_roll=4.0, swing=0.07,
                                    out=0.06, down=0.18, fwd=0.1, curl=0.2, spread=0.8, head_up=-4.0, jaw=3.0, tongue_every=1.25),
                  stance_y=0.1, heel_off=16.0, swing_heel=26.0, toe_swing=-38.0, yaw=14.0)


def run(r):
    """Upright and much too fast: bent forward from the hips, arms out and
    low with the talons open, long digitigrade strides."""
    return r.gait("run", speed=8.0, stride=3.4, duty=0.3, phases={"r": 0.0, "l": 0.5}, lift=0.26,
                  upper=_gait_upper(r, lean=33.0, drop=0.11, sway=0.02, bob=0.045, twist=9.0, hip_roll=5.0, swing=0.16,
                                    out=0.14, down=-0.04, fwd=0.05, curl=0.12, spread=1.0, level=0.9, jaw=10.0),
                  stance_y=0.12, heel_off=26.0, swing_heel=30.0, toe_swing=-35.0)


def swim(r):
    """Deep water: a fast breaststroke with the head and neck held above the
    surface. (In the shallows the code plays `walk`.) 2 m/s."""
    T = 1.2

    def fn(t):
        ph = (t / T) % 1.0
        pull = smooth(seg(ph, 0.0, 0.35))                 # arms sweep back
        back = smooth(seg(ph, 0.5, 0.95))                 # and reach forward again
        a = pull - back                                   # 0 reach, 1 at the hips
        kick = pulse(ph, 0.3, 0.5, 0.8)                   # legs drive as the arms recover
        d = dict(NB)
        d.update(lean=0.0, body_pitch=62.0 - 5.0 * a, drop=0.25, bob=0.03 * a, level=0.0, neck_up=44.0, head_up=22.0, stretch=0.6,
                 hc_r=(0.2 + 0.42 * math.sin(math.pi * a), 0.62 - 0.55 * a, 1.5 - 0.35 * a),
                 curl_r=0.05, spread_r=0.6 - 0.6 * back, aim_r=None, pole_r=(1.0, -0.3, 0.4),
                 fmix_r=1.0, fc_r=(0.03 + 0.1 * (1 - kick), 0.12 - 0.3 * kick, 0.3 - 0.32 * kick), heel_r=62.0 - 40.0 * kick,
                 toe_r=-20.0 * kick, jaw=5.0)
        d.update({k[:-2] + "_l": ((-v[0], v[1], v[2]) if isinstance(v, tuple) else v) for k, v in d.items() if k.endswith("_r")})
        return biped.apply(r, d, SPINE, NECK)
    r.clip("swim", T, fn, loop=True, speed=2.0)


def dodge(r, side):
    """A quick step aside from a shot it sees coming."""
    keys = [
        (0.0, dict()),
        (0.1, dict(lean=22.0, drop=0.14, sway=-0.16, spine_roll=-14.0, neck_roll=10.0, head_yaw=10.0, f_l=(-0.24, 0.0, 0.07), heel_l=66.0,
                   hc_r=(0.5, 0.05, 1.05), hc_l=(-0.55, 0.0, 1.0), k_threat=1.0), "snap"),
        (0.22, dict(sway=-0.3, f_l=(-0.42, 0.02, 0.0), heel_l=None, f_r=(-0.12, 0.0, 0.06), heel_r=66.0)),
        (0.4, dict(lean=12.0, drop=0.05, sway=-0.36, spine_roll=0.0, neck_roll=0.0, head_yaw=0.0, f_r=(-0.34, 0.03, 0.0), heel_r=None,
                   f_l=(-0.38, -0.03, 0.0), hc_r=(0.04, 0.13, 1.0), hc_l=(-0.76, 0.13, 1.0), jaw=6.0)),
    ]
    if side == "r":
        keys = [(k[0], biped.mirrored(k[1])) + tuple(k[2:]) for k in keys]
    keyclip(r, f"dodge_{side}", keys, travel=0.36)


def bask(r):
    """Belly-down on a sun-warm stone, chin up, eyes half-lidded."""
    keyclip(r, "bask", [
        (0.0, dict(lean=0.0, body_pitch=84.0, ground=1.0, level=0.0, bend=-14.0, neck_up=46.0, head_up=20.0, neck_yaw=6.0, k_blink=0.5,
                   hc_r=(0.3, 0.5, 1.7), hc_l=(-0.34, 0.5, 1.62), aim_r=(-0.25, 1.0, 0.0), aim_l=(0.25, 1.0, 0.0),
                   pole_r=(1.0, -0.4, 0.3), pole_l=(-1.0, -0.4, 0.3), curl_r=0.15, curl_l=0.15,
                   fmix_r=1.0, fmix_l=1.0, fc_r=(0.34, 0.3, 0.5), fc_l=(-0.2, 0.3, 0.16), heel_r=70.0, heel_l=78.0,
                   knee_r=(1.0, 0.2, 0.5), knee_l=(-1.0, 0.2, 0.2))),
        (3.0, dict(neck_yaw=-8.0, neck_up=42.0, k_blink=0.75, curl_r=0.3)),
        (6.0, dict(neck_yaw=6.0, neck_up=46.0, k_blink=0.5, curl_r=0.15)),
    ], loop=True, tongue_at=(4.1,), more=lambda t, d: d.update(bend=d["bend"] + 1.5 * wave(t, 3.0)))


def nest(r):
    """Night sleep in the reeds: curled on its side, knees up, ribs moving slowly."""
    base = lying("r")
    base.update(bend=44.0, neck_up=-26.0, head_up=-10.0, fc_r=(0.15, 0.42, 0.45), fc_l=(0.5, 0.52, 0.55), heel_r=74.0, heel_l=78.0,
                hc_r=(0.3, 0.45, 1.75), hc_l=(0.25, 0.42, 1.4), k_blink=1.0, jaw=2.0)
    keyclip(r, "nest", [(0.0, base), (2.5, dict(bend=46.5, curl_l=0.65)), (5.0, dict(bend=44.0, curl_l=0.55))], loop=True)


def sleep(r):
    """The sleep arrow: it drops where it stands, slumps for 5 s, wakes groggy
    and snaps alert."""
    down = lying("l")
    down.update(k_blink=1.0, jaw=10.0, bend=22.0)
    keyclip(r, "sleep_fall", [
        (0.0, dict()),
        (0.25, dict(lean=4.0, drop=0.2, neck_up=-25.0, head_up=-20.0, head_roll=14.0, k_blink=0.8, hc_r=(0.36, 0.05, 0.9), hc_l=(-0.36, 0.05, 0.9),
                    curl_r=0.5, curl_l=0.5, heel_r=30.0, heel_l=34.0)),
        (0.5, dict(drop=0.55, lean=18.0, body_roll=-30.0, sway=-0.15, heel_r=14.0, heel_l=12.0, fmix_r=0.5, fmix_l=0.5,
                   fc_r=(0.0, 0.3, 0.3), fc_l=(-0.02, 0.22, 0.2)), "slow"),
        (0.8, dict(down, sway=-0.3), "lin"),
    ], more=lambda t, d: d.update(ground=max(d["ground"], smooth(seg(t, 0.45, 0.62)))))
    keyclip(r, "sleep", [(0.0, dict(down, sway=-0.3)), (2.5, dict(bend=24.5, jaw=13.0)), (5.0, dict(bend=22.0, jaw=10.0))], loop=True)
    keyclip(r, "wake", [
        (0.0, dict(down, sway=-0.3)),
        (0.3, dict(k_blink=0.3, neck_up=14.0, head_roll=0.0, hmix_l=1.0, hw_l=(-0.72, 0.3, 0.02), aim_l=(0.0, 1.0, -0.2))),
        (0.7, dict(body_roll=-28.0, drop=0.5, lean=24.0, ground=0.0, sway=-0.12, fmix_r=0.0, fmix_l=0.0, f_r=(0.04, -0.05, 0),
                   f_l=(-0.1, 0.1, 0), heel_r=20.0, heel_l=24.0, bend=10.0, jaw=6.0, k_blink=0.0, hc_r=HANG_R, aim_r=DOWN_R, pole_r=None)),
        (1.0, dict(body_roll=0.0, drop=0.14, lean=20.0, sway=0.0, heel_r=None, heel_l=None, f_r=NB["f_r"], f_l=NB["f_l"], bend=0.0,
                   hmix_l=0.0, hc_l=HANG_L, aim_l=DOWN_L, pole_l=None, level=1.0, neck_up=0.0, neck_roll=0.0, curl_r=0.35, curl_l=0.35)),
        (1.2, dict(lean=4.0, drop=0.01, stretch=0.85, neck_up=8.0, head_up=4.0, k_eyes_wide=0.8, k_threat=0.8, jaw=4.0), "snap"),
    ], more=lambda t, d: d.update(ground=d["ground"] if t < 0.5 else 0.0))


def burn(r):
    """On fire: beating at its own shoulders, half running, jaw wide."""
    T = 1.0

    def more(t, d):
        ph = (t / T) % 1.0
        a = wave(t, 0.5)                                    # two beats a second, hands alternating
        d["hc_r"] = (-0.12 + 0.2 * (a < 0), 0.2, 1.5 + 0.06 * a)
        d["hc_l"] = (0.12 - 0.2 * (a > 0), 0.2, 1.5 - 0.06 * a)
        d["spine_yaw"] = 20.0 * wave(t, T)
        d["neck_yaw"] = -24.0 * wave(t, T, 0.1)
        d["head_roll"] = 12.0 * wave(t, 0.5, 0.2)
        for side, off in (("r", 0.0), ("l", 0.5)):
            u = (ph * 2 + off) % 1.0                        # each foot stamps twice a second
            up = pulse(u, 0.0, 0.25, 0.5)
            s = 1.0 if side == "r" else -1.0
            d[f"f_{side}"] = (s * 0.03, 0.02, 0.12 * up)
            d[f"heel_{side}"] = 49.0 + 28.0 * up
        d["bob"] = 0.025 * wave(t, 0.25)
    keyclip(r, "burn", [(0.0, dict(lean=24.0, drop=0.1, jaw=30.0, k_hiss=1.0, k_eyes_wide=1.0, aim_r=None, aim_l=None, curl_r=0.2, curl_l=0.2,
                                   pole_r=(0.6, -0.2, -1.0), pole_l=(-0.6, -0.2, -1.0))), (T, dict())], loop=True, more=more)


# ------------------------------------------------------------------ attacks

def claw(r):
    """22 claw, medium. The arm draws back and up, the talons spread (the
    glint is on them); then a raking swipe down across the body. Reach 1.7 m."""
    wound = dict(lean=8.0, drop=0.06, spine_yaw=-30.0, body_yaw=-8.0, neck_yaw=22.0, head_yaw=10.0,
                 hc_r=(0.56, -0.2, 1.78), aim_r=(0.1, 0.5, 1.0), pole_r=(1.0, -0.6, -0.2), curl_r=0.0, spread_r=1.0,
                 hc_l=(-0.3, 0.34, 1.22), aim_l=(0.1, 1.0, 0.1), curl_l=0.15, spread_l=0.8, k_threat=1.0, jaw=10.0)
    keyclip(r, "telegraph_naga_claw", [
        (0.0, dict()),
        (0.3, wound, "out"),
        (0.55, dict(hc_r=(0.6, -0.24, 1.82), spine_yaw=-34.0, drop=0.08)),      # the held breath before it falls
    ])
    keyclip(r, "attack_naga_claw", [
        (0.0, dict(wound, hc_r=(0.6, -0.24, 1.82), spine_yaw=-34.0, drop=0.08)),
        (0.067, dict(lean=22.0, drop=0.12, spine_yaw=10.0, body_yaw=4.0, fwd=0.1, hc_r=(0.2, 0.68, 1.42), aim_r=(-0.5, 0.6, -0.6),
                     pole_r=(1.0, -0.2, 0.4), curl_r=0.25, jaw=22.0, k_hiss=1.0), "whip"),
        (0.17, dict(spine_yaw=34.0, body_yaw=10.0, hc_r=(-0.3, 0.42, 0.95), aim_r=(-0.8, 0.0, -0.6), lean=27.0), "out"),
        (0.5, dict(lean=20.0, drop=0.12, spine_yaw=18.0, body_yaw=0.0, fwd=0.0, hc_r=(0.05, 0.4, 1.0), aim_r=DOWN_R, pole_r=None,
                   hc_l=HANG_L, aim_l=DOWN_L, neck_yaw=0.0, head_yaw=0.0, curl_r=0.35, curl_l=0.35, spread_l=0.3, spread_r=0.3, jaw=8.0, k_hiss=0.0)),
    ], contact=0.067)


def lunge(r):
    """30 blunt, heavy, from 4-6 m. Head down, it sinks low on bent legs and
    one foot scrapes the ground; then it springs up to 5 m and slams its head
    and shoulders into her. The code carries the body `travel_m`."""
    low = dict(lean=46.0, drop=0.3, level=0.55, head_up=-10.0, hc_r=(0.5, -0.16, 0.95), hc_l=(-0.5, -0.16, 0.95), spread_r=1.0, spread_l=1.0,
               curl_r=0.1, curl_l=0.1, aim_r=(0.3, -0.2, -1.0), aim_l=(-0.3, -0.2, -1.0), k_threat=1.0, jaw=6.0, heel_r=34.0, heel_l=34.0)
    keyclip(r, "telegraph_naga_lunge", [
        (0.0, dict()),
        (0.3, low, "out"),
        (0.42, dict(f_r=(0.03, 0.14, 0.03), heel_r=44.0)),
        (0.62, dict(f_r=(0.03, -0.26, 0.0), heel_r=40.0), "lin"),                # the scrape
        (0.8, dict(drop=0.36, lean=50.0, fwd=-0.06)),
    ])
    keyclip(r, "attack_naga_lunge", [
        (0.0, dict(low, f_r=(0.03, -0.26, 0.0), heel_r=40.0, drop=0.36, lean=50.0, fwd=-0.06)),
        (0.1, dict(lean=30.0, body_pitch=34.0, drop=-0.02, fwd=0.2, level=0.8, head_up=-24.0, neck_up=-10.0, jaw=4.0,
                   heel_r=80.0, heel_l=80.0, f_r=(0.03, -0.5, 0.0), f_l=(-0.03, -0.42, 0.0),
                   hc_r=(0.52, 0.3, 1.3), hc_l=(-0.52, 0.3, 1.3), aim_r=(0.0, 1.0, -0.2), aim_l=(0.0, 1.0, -0.2)), "whip"),
        (0.2, dict(fmix_r=1.0, fmix_l=1.0, fc_r=(0.0, -0.4, 0.08), fc_l=(0.0, -0.3, 0.14), heel_r=25.0, heel_l=30.0, drop=-0.1,
                   body_pitch=42.0), "lin"),                                   # airborne, stretched out
        (0.33, dict(drop=0.1, body_pitch=30.0, fc_r=(0.0, 0.35, 0.06), fc_l=(0.0, 0.1, 0.1), hc_r=(0.3, 0.55, 1.35), hc_l=(-0.3, 0.55, 1.35),
                    curl_r=0.5, curl_l=0.5), "lin"),                             # the blow lands
        (0.42, dict(fmix_r=0.0, fmix_l=0.0, f_r=(0.03, 0.32, 0.0), f_l=(-0.03, 0.02, 0.0), heel_r=30.0, heel_l=40.0, drop=0.36, body_pitch=0.0,
                    lean=40.0, fwd=0.1), "lin"),
        (0.6, dict(drop=0.16, lean=22.0, fwd=0.14, level=1.0, head_up=0.0, neck_up=0.0, heel_r=None, heel_l=None, hc_r=HANG_R, hc_l=HANG_L,
                   aim_r=DOWN_R, aim_l=DOWN_L, curl_r=0.3, curl_l=0.3, jaw=10.0)),
    ], contact=0.333, travel=5.0)


def coil(r):
    """A grab from behind: a low crouch and a held breath, then both arms
    lock round her chest, talons at her ribs. The pair is with Feyre's
    grabbed pose; `grab_point` on the chest is where she is held."""
    crouch = dict(lean=30.0, drop=0.26, hc_r=(0.66, 0.16, 1.32), hc_l=(-0.66, 0.16, 1.32), aim_r=(-0.3, 1.0, 0.0), aim_l=(0.3, 1.0, 0.0),
                  pole_r=(1.0, -0.4, 0.0), pole_l=(-1.0, -0.4, 0.0), curl_r=0.05, curl_l=0.05, spread_r=1.0, spread_l=1.0, jaw=3.0,
                  k_threat=0.6, heel_r=36.0, heel_l=36.0)
    held = dict(lean=16.0, drop=0.1, fwd=0.12, hc_r=(0.1, 0.5, 1.36), hc_l=(-0.14, 0.46, 1.26), aim_r=(-1.0, 0.1, -0.1), aim_l=(1.0, 0.1, 0.1),
                pole_r=(1.0, 0.1, -0.2), pole_l=(-1.0, 0.1, -0.2), curl_r=0.75, curl_l=0.75, spread_r=0.4, spread_l=0.4,
                neck_up=-22.0, head_up=-14.0, neck_yaw=-20.0, head_roll=-14.0, jaw=22.0, k_threat=1.0, heel_r=None, heel_l=None)
    keyclip(r, "telegraph_naga_coil", [(0.0, dict()), (0.35, crouch, "out"), (0.6, dict(drop=0.29, hc_r=(0.7, 0.1, 1.34), hc_l=(-0.7, 0.1, 1.34)))])
    keyclip(r, "attack_naga_coil", [
        (0.0, dict(crouch, drop=0.29, hc_r=(0.7, 0.1, 1.34), hc_l=(-0.7, 0.1, 1.34))),
        (0.1, dict(lean=22.0, drop=0.14, fwd=0.1, hc_r=(0.5, 0.56, 1.36), hc_l=(-0.5, 0.56, 1.3)), "whip"),
        (0.2, dict(held), "lin"),
        (0.4, dict(lean=14.0)),
    ], contact=0.2)
    keyclip(r, "coil_hold", [(0.0, dict(held, lean=14.0)), (0.5, dict(lean=17.0, hc_r=(0.07, 0.47, 1.36), hc_l=(-0.11, 0.43, 1.26), jaw=27.0, drop=0.12)),
                             (1.0, dict(lean=14.0, hc_r=held["hc_r"], hc_l=held["hc_l"], jaw=22.0, drop=0.1))], loop=True)
    keyclip(r, "coil_thrown", [
        (0.0, dict(held, lean=14.0)),
        (0.12, dict(lean=-12.0, drop=0.0, fwd=-0.12, hc_r=(0.7, 0.1, 1.5), hc_l=(-0.7, 0.1, 1.45), aim_r=(0.6, 0.3, 0.6), aim_l=(-0.6, 0.3, 0.6),
                    curl_r=0.0, curl_l=0.0, spread_r=1.0, spread_l=1.0, neck_up=-18.0, head_up=-10.0, neck_yaw=0.0, head_roll=0.0, jaw=30.0,
                    k_eyes_wide=1.0), "snap"),
        (0.35, dict(fwd=-0.34, f_r=(0.04, -0.36, 0.05), heel_r=64.0, sway=0.06)),
        (0.55, dict(fwd=-0.5, f_r=(0.04, -0.6, 0.0), heel_r=None, f_l=(-0.05, -0.3, 0.06), heel_l=64.0, lean=10.0, drop=0.14, sway=-0.04)),
        (0.9, dict(fwd=-0.55, f_l=(-0.06, -0.52, 0.0), heel_l=None, lean=20.0, drop=0.12, sway=0.0, hc_r=HANG_R, hc_l=HANG_L, aim_r=DOWN_R,
                   aim_l=DOWN_L, pole_r=None, pole_l=None, curl_r=0.3, curl_l=0.3, neck_up=0.0, head_up=0.0, jaw=12.0, k_eyes_wide=0.0)),
    ], travel=-0.55)


# ------------------------------------------------------------------ hits and deaths

def hit(r, side):
    """0.25 s flinch from the struck side (hit_l: struck on its left)."""
    keys = [
        (0.0, dict()),
        (0.07, dict(sway=0.05, spine_roll=12.0, spine_yaw=-14.0, neck_roll=-12.0, head_yaw=-16.0, lean=15.0, drop=0.07, jaw=16.0,
                    hc_l=(-0.34, 0.2, 1.2), curl_l=0.7, k_eyes_wide=1.0), "snap"),
        (0.25, dict(sway=0.0, spine_roll=0.0, spine_yaw=0.0, neck_roll=0.0, head_yaw=0.0, lean=10.0, drop=0.035, jaw=4.0, hc_l=HANG_L,
                    curl_l=0.35, k_eyes_wide=0.0, k_threat=0.6)),
    ]
    if side == "r":
        keys = [(k[0], biped.mirrored(k[1])) + tuple(k[2:]) for k in keys]
    keyclip(r, f"hit_{side}", keys)


def death(r, side):
    """Falls away from the blow onto one flank (death_l: onto its left), a
    last spasm of the talons, then still. The last frame holds."""
    s = 1.0 if side == "r" else -1.0
    down = lying(side)
    m = (lambda d: d) if side == "r" else biped.mirrored
    keys = [
        (0.0, dict()),
        (0.14, m(dict(lean=-6.0, spine_roll=16.0, spine_yaw=-18.0, neck_roll=-16.0, sway=0.08, jaw=30.0, k_eyes_wide=1.0, hc_l=(-0.6, 0.0, 1.4),
                      spread_l=1.0, curl_l=0.0, spread_r=1.0, curl_r=0.0)), "snap"),
        (0.5, m(dict(lean=8.0, drop=0.18, sway=0.2, body_roll=14.0, f_r=(0.16, -0.08, 0.0), heel_r=30.0, heel_l=56.0, hc_r=(0.5, 0.1, 0.95)))),
        (0.8, m(dict(drop=0.5, sway=0.36, body_roll=42.0, heel_r=16.0, heel_l=30.0, fmix_r=0.4, fmix_l=0.4, fc_r=down["fc_r"] if side == "r" else biped.mirrored(down)["fc_r"],
                     fc_l=down["fc_l"] if side == "r" else biped.mirrored(down)["fc_l"], neck_roll=-20.0)), "slow"),
        (1.05, dict(down, sway=0.55 * s, jaw=26.0, k_eyes_wide=1.0, curl_r=0.1, curl_l=0.1, spread_r=1.0, spread_l=1.0), "lin"),
        (1.6, dict(jaw=18.0, curl_r=0.85, curl_l=0.85, spread_r=0.2, spread_l=0.2, k_eyes_wide=0.5)),      # the spasm closes the talons
        (2.6, dict(jaw=11.0, curl_r=0.55, curl_l=0.55, k_eyes_wide=0.0, k_blink=0.6)),
    ]

    def more(t, d):
        d["ground"] = max(d["ground"], smooth(seg(t, 0.7, 0.95)))
        tw = pulse(t, 1.05, 1.3, 1.9)
        d["bend"] += 5.0 * tw * wave(t, 0.13)
        d["neck_up"] += 6.0 * tw * wave(t, 0.11)
        # the body bounces once as it lands
        d["bob"] += 0.03 * abs(ring(t, 1.05, 1.0, 4.0, 7.0))
    keyclip(r, f"death_{side}", keys, more=more)


def death_throat(r):
    """The weak-spot kill: both hands round the arrow in its throat, choking
    down to its knees, then forward onto its face."""
    at_throat = dict(hc_r=(0.07, 0.2, 1.64), hc_l=(-0.07, 0.2, 1.6), aim_r=(-0.7, 0.2, 0.6), aim_l=(0.7, 0.2, 0.6), pole_r=(1.0, -0.2, -0.6),
                     pole_l=(-1.0, -0.2, -0.6), curl_r=0.7, curl_l=0.7)
    keys = [
        (0.0, dict()),
        (0.12, dict(lean=-14.0, neck_up=-24.0, head_up=-16.0, jaw=34.0, k_eyes_wide=1.0, fwd=-0.08, hc_r=(0.5, 0.0, 1.4), hc_l=(-0.5, 0.0, 1.4),
                    spread_r=1.0, spread_l=1.0, curl_r=0.0, curl_l=0.0), "snap"),
        (0.45, dict(at_throat, lean=-6.0, fwd=-0.16, f_l=(-0.04, -0.28, 0.0), stretch=0.6)),
        (1.1, dict(lean=12.0, drop=0.12, neck_up=-8.0, jaw=40.0, sway=0.05)),
        (1.6, dict(drop=0.62, lean=10.0, fwd=-0.05, heel_r=8.0, heel_l=8.0, f_r=(0.05, -0.2, 0.0), f_l=(-0.06, -0.42, 0.0), toe_r=-30.0, toe_l=-30.0,
                   jaw=44.0, neck_up=10.0, sway=0.0), "slow"),                      # onto its knees
        (2.1, dict(lean=22.0, neck_up=-10.0, jaw=30.0, k_eyes_wide=0.6, stretch=0.2)),
        (2.6, dict(lean=0.0, body_pitch=84.0, drop=0.0, ground=1.0, level=0.0, bend=-4.0, neck_up=10.0, neck_roll=24.0, head_roll=30.0, fwd=0.2,
                   fmix_r=1.0, fmix_l=1.0, fc_r=(0.2, 0.3, 0.3), fc_l=(-0.1, 0.3, 0.1), heel_r=74.0, heel_l=80.0, toe_r=0.0, toe_l=0.0,
                   knee_r=(1.0, 0.2, 0.4), knee_l=(-1.0, 0.2, 0.1), jaw=16.0,
                   hc_r=(0.26, 0.5, 1.72), hc_l=(-0.22, 0.5, 1.5), pole_r=(1.0, -0.4, 0.3), pole_l=(-1.0, -0.5, 0.2), aim_r=(-0.3, 1.0, 0.0),
                   aim_l=(0.4, 0.6, 0.0), k_eyes_wide=0.2), "slow"),
        (3.0, dict(jaw=10.0, curl_r=0.5, curl_l=0.5, k_blink=0.5, k_eyes_wide=0.0)),
    ]

    def more(t, d):
        d["ground"] = smooth(seg(t, 2.15, 2.5))
        choke = pulse(t, 0.4, 1.0, 2.2)
        d["bend"] += 6.0 * choke * wave(t, 0.31)
        d["neck_yaw"] += 10.0 * choke * wave(t, 0.47)
    keyclip(r, "death_throat", keys, more=more)


def death_ash(r):
    """An ash arrow: it staggers on through the 4 s of the mortal wound (the
    code dulls its sheen meanwhile) and falls."""
    down = lying("r")
    keys = [
        (0.0, dict()),
        (0.15, dict(lean=-8.0, jaw=26.0, k_eyes_wide=1.0, hc_r=(0.3, 0.24, 1.36), curl_r=0.7, spine_yaw=10.0), "snap"),
        (0.7, dict(lean=20.0, drop=0.12, fwd=0.14, f_r=(0.03, 0.34, 0.0), sway=0.06, hc_l=(-0.5, 0.2, 0.9), jaw=14.0)),
        (1.4, dict(lean=26.0, drop=0.16, fwd=0.34, f_l=(-0.06, 0.52, 0.0), sway=-0.08, neck_up=-12.0, spine_yaw=-6.0)),
        (2.1, dict(lean=30.0, drop=0.24, fwd=0.5, f_r=(0.08, 0.76, 0.0), sway=0.1, neck_up=-20.0, heel_r=36.0, heel_l=30.0, curl_l=0.6)),
        (2.7, dict(lean=34.0, drop=0.34, fwd=0.56, sway=0.14, body_roll=10.0, heel_r=24.0, jaw=22.0, k_eyes_wide=0.4)),
        (3.1, dict(drop=0.6, sway=0.3, body_roll=40.0, fmix_r=0.4, fmix_l=0.4, fc_r=down["fc_r"], fc_l=down["fc_l"], heel_r=14.0, heel_l=20.0), "slow"),
        (3.4, dict(down, fwd=0.6, sway=0.5, jaw=20.0, k_eyes_wide=0.2), "lin"),
        (4.0, dict(jaw=10.0, curl_r=0.6, curl_l=0.6, k_eyes_wide=0.0, k_blink=0.7)),
    ]

    def more(t, d):
        d["ground"] = max(d["ground"], smooth(seg(t, 3.0, 3.3)))
        shake = pulse(t, 0.3, 2.0, 3.0)
        d["head_roll"] += 5.0 * shake * wave(t, 0.23)
        d["bob"] += 0.006 * shake * wave(t, 0.19)
    keyclip(r, "death_ash", keys, more=more, travel=0.6)
