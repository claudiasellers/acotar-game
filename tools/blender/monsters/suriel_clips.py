"""The Suriel's clips (bestiary §3.4): names and lengths are the guide's.

It is still, and then it is sharp: long holds, and moves that arrive all at
once. The veil never rests: its ends stir in a breeze nothing else feels, in
every clip, whatever the game's wind is doing.

head_cock, speak and laugh are additive: they move only what they name (head,
jaw, fingers, chest) from the rest pose, so the game lays them over sit_idle.
"""

import math

import biped
import rig
import suriel_rig
from biped import Keys
from rig import pulse, ring, seg, smooth, wave

SPINE = ("spine", "spine2", "chest")
NECK = ("neck", "neck2")

# Standing: folded down into its hunch, the head low and forward between the
# shoulders, the long arms hanging ahead of the body, fingers loose.
HANG_R, HANG_L = (0.25, 0.10, 1.12), (-0.25, 0.10, 1.12)
DOWN_R, DOWN_L = (0.05, 0.3, -1.0), (-0.05, 0.3, -1.0)
SB = dict(biped.BASE)
SB.update(lean=24.0, bend=10.0, drop=0.07, level=0.72, hc_r=HANG_R, hc_l=HANG_L, aim_r=DOWN_R, aim_l=DOWN_L,
          curl_r=0.22, curl_l=0.22, spread_r=0.5, spread_l=0.5, f_r=(0.0, 0.03, 0), f_l=(0.0, -0.04, 0), foot_yaw=12.0,
          jaw=2.0, k_threat=0.0, k_speak_open=0.0, k_eyes_wide=0.0)

# Sitting in the snare: on the ground, knees drawn up, the back a hook, the
# forearms laid on the knees and the hands hanging off them.
KNEE_R, KNEE_L = (0.3, 0.2, 1.0), (-0.3, 0.2, 1.0)
SIT = dict(SB)
SIT.update(lean=20.0, bend=16.0, drop=0.98, ground=1.0, level=0.8, f_r=(0.04, 0.40, 0), f_l=(-0.05, 0.33, 0), foot_yaw=16.0,
           knee_r=KNEE_R, knee_l=KNEE_L, hw_r=(0.2, 0.68, 0.24), hw_l=(-0.21, 0.62, 0.22), hmix_r=1.0, hmix_l=1.0,
           aim_r=(-0.1, 0.15, -1.0), aim_l=(0.1, 0.15, -1.0), pole_r=(0.5, 1.0, 0.6), pole_l=(-0.5, 1.0, 0.6),
           curl_r=0.18, curl_l=0.24)

# Snared: a deep squat over the caught left ankle, both hands at the loops.
SNARE = dict(SIT)
SNARE.update(lean=30.0, bend=24.0, drop=0.84, ground=0.0, level=0.3, spine_yaw=8.0, hw_r=(-0.05, 0.4, 0.17), hw_l=(-0.25, 0.36, 0.17),
             aim_r=(-0.3, 0.1, -1.0), aim_l=(0.3, 0.1, -1.0), pole_r=(1.0, 0.3, 0.3), pole_l=(-1.0, 0.3, 0.3),
             curl_r=0.6, curl_l=0.6, spread_r=0.8, spread_l=0.8, jaw=8.0)


def _phase(name):
    return (sum(ord(c) * (i + 3) for i, c in enumerate(name)) % 97) / 97.0


def breeze(p, t, T, amp=1.0, gust=(0.0, 0.0)):
    """The phantom breeze. T is the clip's length (a loop comes round whole);
    `gust` (x, y) throws the veil's ends that way (a head that snaps round)."""
    for name, c in suriel_rig.chains().items():
        bones = suriel_rig.chain_bones(name, c)
        ph = _phase(name)
        n = len(bones)
        cyc = max(round(T / 2.6), 1)
        for j, b in enumerate(bones):
            k = (j + 1) / n
            a = wave(t, T / cyc, ph - 0.2 * j)
            c2 = wave(t, T / (cyc + 1), ph * 1.7 + 0.31 - 0.24 * j)
            if name.startswith("veil_f"):
                s = 1.0 if name.endswith("r") else -1.0
                v = ((0.10 * a + 0.05 * s) * k + gust[0] * k, (0.16 * c2 + 0.09) * k + gust[1] * k, 0.0)
            elif name.startswith("veil_b"):
                v = (0.10 * a * k + gust[0] * k, -(0.16 + 0.15 * c2) * k + gust[1] * k * 0.5, 0.0)
            elif name.startswith("sleeve"):
                v = (0.05 * a * k, 0.06 * c2 * k, 0.0)
            else:
                ang = 2 * math.pi * (int(name.split("_")[1]) + 0.5) / 8.0
                out = 0.07 + 0.06 * c2
                v = (out * math.sin(ang) * k + 0.04 * a * math.cos(ang) * k, out * math.cos(ang) * k - 0.04 * a * math.sin(ang) * k, 0.0)
            p.blow(b, (v[0] * amp, v[1] * amp, v[2] * amp))


def keyclip(r, name, base, keys, loop=False, more=None, breath=0.0, wind=1.0, gust=None, after=None):
    K = Keys(base, keys)

    def fn(t):
        d = K(t)
        b = wave(t, K.duration / max(round(K.duration / 3.2), 1)) if breath else 0.0
        if breath:
            d["bend"] += 0.9 * breath * b
            d["bob"] += 0.003 * breath * b
        if more is not None:
            more(t, d)
        p = biped.apply(r, d, SPINE, NECK)
        if breath:
            p.turn("chest", pitch=-1.0 * breath * b)
        breeze(p, t, K.duration if loop else 2.6, wind, gust(t) if gust else (0.0, 0.0))
        if after is not None:
            after(t, p)
        return p
    r.clip(name, K.duration, fn, loop=loop)


def additive(r, name, duration, fn, loop=False):
    """A clip that leaves the body at rest and moves only what fn(t, pose) turns."""
    def frame(t):
        p = rig.Pose()
        fn(t, p)
        return p
    r.clip(name, duration, frame, loop=loop)


def author(r):
    """Keys every clip onto the rig, in the guide's order."""
    T = 5.0
    keyclip(r, "idle", SB, [
        (0.0, dict(sway=0.012, neck_yaw=9.0)),
        (T * 0.45, dict(sway=-0.012, neck_yaw=-12.0, head_roll=-5.0, curl_r=0.34, curl_l=0.18)),
        (T * 0.55, dict(neck_yaw=-12.0, head_roll=-5.0)),
        (T, dict(sway=0.012, neck_yaw=9.0, head_roll=0.0, curl_r=0.22, curl_l=0.22)),
    ], loop=True, breath=1.0)
    stalk(r)
    snared(r)
    scream(r)
    sit_down(r)
    T = 6.0
    keyclip(r, "sit_idle", SIT, [
        (0.0, dict(neck_yaw=3.0)),
        (T / 2, dict(neck_yaw=-3.0, head_roll=2.0, curl_r=0.26, curl_l=0.16)),
        (T, dict(neck_yaw=3.0, head_roll=0.0, curl_r=0.18, curl_l=0.24)),
    ], loop=True, breath=0.6, wind=1.25)
    # "went rigid. And sniffed. Once. Twice"; "slowly, it turned"
    keyclip(r, "notice", SIT, [
        (0.0, dict()),
        (0.14, dict(lean=12.0, bend=6.0, level=1.0, stretch=0.5, curl_r=0.05, curl_l=0.05, spread_r=1.0, spread_l=1.0, k_eyes_wide=0.6), "snap"),
        (1.05, dict()),
        (2.0, dict(neck_yaw=46.0, head_yaw=14.0, spine_yaw=16.0, head_roll=6.0, k_eyes_wide=0.3), "smooth"),
    ], more=lambda t, d: d.update(head_up=d["head_up"] + 9.0 * (pulse(t, 0.42, 0.5, 0.68) + pulse(t, 0.78, 0.86, 1.04)),
                                  bob=d["bob"] + 0.004 * (pulse(t, 0.42, 0.5, 0.68) + pulse(t, 0.78, 0.86, 1.04))))
    # "cocked its head… an erratic, sharp movement, the dark veil snapping with it"
    def cock(t, p):
        k = rig.ease_out(seg(t, 0.0, 0.09), 3.0)
        p.turn("head", roll=24.0 * k, yaw=5.0 * k)
        p.turn("neck2", roll=8.0 * k)
        g = -0.5 * pulse(t, 0.0, 0.07, 0.25)
        breeze(p, t, 2.6, 1.0, gust=(g, 0.0))
    additive(r, "head_cock", 0.25, cock)
    # "Click, click, click went its fingers against each other, one for each word"
    def speak(t, p):
        word = t % 0.5
        p.turn("jaw", pitch=3.0 + 9.0 * pulse(word, 0.02, 0.14, 0.38))
        p.key("speak_open", 0.3 + 0.7 * pulse(word, 0.02, 0.14, 0.38))
        p.key("threat", 0.35)
        click = pulse(word, 0.0, 0.07, 0.16)
        hand = "r" if int(t / 0.5) % 2 == 0 else "l"
        for side in ("r", "l"):
            p.fingers(side, curl=0.12 + (0.5 * click if side == hand else 0.0), spread=0.3 - (0.5 * click if side == hand else 0.0))
        p.turn("head", pitch=1.5 * wave(t, 1.0), roll=2.0 * wave(t, 2.0))
        breeze(p, t, 2.0)
    additive(r, "speak", 2.0, speak, loop=True)
    # "a huffing, awful laugh"
    def laugh(t, p):
        env = pulse(t, 0.0, 0.3, 1.0)
        huff = wave(t, 0.2) * env
        p.turn("chest", pitch=5.0 * huff + 3.0 * env)
        p.turn("spine2", pitch=3.0 * huff)
        p.turn("neck", pitch=-7.0 * env)
        p.turn("head", pitch=-8.0 * env - 3.0 * huff, roll=4.0 * env)
        p.turn("jaw", pitch=15.0 * env + 5.0 * huff)
        p.key("threat", env)
        breeze(p, t, 2.6)
    additive(r, "laugh", 1.0, laugh)
    # "We are not alone."
    keyclip(r, "warn", SIT, [
        (0.0, dict()),
        (0.12, dict(lean=10.0, bend=4.0, level=1.0, stretch=0.7, neck_yaw=-58.0, head_yaw=-18.0, spine_yaw=-14.0, k_eyes_wide=1.0,
                    curl_r=0.0, curl_l=0.0, spread_r=1.0, spread_l=1.0, jaw=6.0), "snap"),
        (1.0, dict(neck_yaw=-60.0)),
    ], gust=lambda t: (0.55 * pulse(t, 0.0, 0.1, 0.5), 0.0),
        more=lambda t, d: d.update(head_roll=3.0 * ring(t, 0.12, 1.0, 9.0, 5.0)))
    burst(r)
    for side in ("l", "r"):
        hit(r, side)


def stalk(r):
    """Creeping to the bait: bent low, each bare foot lifted high and set down slow, sniffing."""
    T = 1.0

    def upper(t, ph, p):
        step = math.sin(2 * math.pi * ph)
        d = dict(SB)
        d.update(lean=30.0, bend=14.0, drop=0.14, level=0.85, sway=0.03 * math.sin(2 * math.pi * (ph + 0.1)),
                 bob=0.008 * math.cos(4 * math.pi * (ph + 0.08)), body_yaw=3.0 * math.cos(2 * math.pi * ph),
                 spine_yaw=-5.0 * math.cos(2 * math.pi * ph), pelvis_roll=2.5 * step, chest_roll=-3.0 * step,
                 neck_yaw=10.0 * math.sin(2 * math.pi * ph), head_up=5.0 * pulse(ph, 0.1, 0.25, 0.5),
                 curl_r=0.3 + 0.15 * step, curl_l=0.3 - 0.15 * step)
        sw = 0.05 * math.cos(2 * math.pi * ph)
        d["hc_r"] = (0.2, 0.26 + sw, 1.2)
        d["hc_l"] = (-0.2, 0.26 - sw, 1.2)
        q = biped.apply(r, d, SPINE, NECK)
        for k in ("body_loc", "body_rot", "fk", "offsets", "hands", "curl", "keys"):
            setattr(p, k, getattr(q, k))
        breeze(p, t, T * 2, 1.0)
    return r.gait("stalk", speed=0.6, stride=0.6 * T, duty=0.68, phases={"r": 0.0, "l": 0.5}, lift=0.09, upper=upper,
                  stance_y=0.05, heel_off=14.0, swing_heel=10.0, toe_swing=-10.0, yaw=12.0)


def snared(r):
    """Clawing at the loops round its ankle, the caught foot jerking at the tether."""
    T = 1.5

    def more(t, d):
        a = wave(t, 0.5)
        b = wave(t, 0.5, 0.5)
        d["hw_r"] = (-0.05 + 0.03 * a, 0.4, 0.17 + 0.05 * a)
        d["hw_l"] = (-0.25 + 0.03 * b, 0.36, 0.17 + 0.05 * b)
        d["curl_r"] = 0.55 + 0.25 * a
        d["curl_l"] = 0.55 + 0.25 * b
        tug = pulse(t, 0.55, 0.72, 1.0)
        d["f_l"] = (-0.05, 0.33 - 0.06 * tug, 0.04 * tug)
        d["sway"] = 0.02 * wave(t, 1.5)
        d["lean"] += 3.0 * wave(t, 0.5, 0.2)
        d["neck_yaw"] = 8.0 * wave(t, 1.5, 0.3)
    keyclip(r, "snared", SNARE, [(0.0, dict()), (T, dict())], loop=True, more=more, wind=1.3)


def scream(r):
    """"A hollowed-out, wicked scream": the back arches, the jaw drops wide, and it goes rigid."""
    up = dict(lean=2.0, bend=-14.0, drop=0.1, fwd=0.34, level=0.0, neck_up=30.0, head_up=22.0, jaw=44.0, stretch=1.0, k_eyes_wide=1.0, k_threat=1.0,
              spine_yaw=0.0, hmix_r=0.0, hmix_l=0.0, hc_r=(0.55, -0.05, 1.3), hc_l=(-0.55, -0.05, 1.3),
              aim_r=(0.5, 0.2, -0.85), aim_l=(-0.5, 0.2, -0.85), pole_r=None, pole_l=None, curl_r=0.0, curl_l=0.0, spread_r=1.0, spread_l=1.0)
    keyclip(r, "scream", SNARE, [
        (0.0, dict()),
        (0.12, dict(lean=36.0, drop=0.88)),
        (0.3, up, "snap"),
        (1.2, dict(neck_up=34.0, jaw=47.0)),
        (1.6, dict(SNARE, fwd=0.0)),
    ], more=lambda t, d: d.update(head_roll=2.5 * wave(t, 0.07) * pulse(t, 0.25, 0.5, 1.3), bob=d["bob"] + 0.004 * wave(t, 0.06) * pulse(t, 0.25, 0.5, 1.3),
                                  jaw=d["jaw"] + 2.0 * wave(t, 0.09) * pulse(t, 0.25, 0.5, 1.3)),
        wind=1.6, gust=lambda t: (0.0, -0.5 * pulse(t, 0.12, 0.3, 0.9)))


def sit_down(r):
    """From the snare's crouch down onto the ground: it stops fighting and waits."""
    keyclip(r, "sit_down", SNARE, [
        (0.0, dict()),
        (0.45, dict(lean=34.0, drop=0.8, level=0.5, spine_yaw=0.0, hw_r=(0.14, 0.5, 0.3), hw_l=(-0.2, 0.46, 0.3), curl_r=0.3, curl_l=0.3, jaw=4.0)),
        (1.0, dict(SIT, lean=26.0), "out"),
        (1.5, dict(SIT)),
    ])


def burst(r):
    """Her arrow cuts the tether: it uncoils out of its seat and is gone, "like
    a shadow on the wind". The last frames leave the ground; the game hides it there."""
    keyclip(r, "burst", SIT, [
        (0.0, dict()),
        (0.1, dict(lean=34.0, bend=24.0, curl_r=0.6, curl_l=0.6), "out"),
        (0.3, dict(lean=-4.0, bend=-8.0, drop=0.0, ground=0.0, level=0.3, stretch=1.0, jaw=30.0, k_eyes_wide=1.0, k_threat=1.0,
                   hmix_r=0.0, hmix_l=0.0, hc_r=(0.6, -0.2, 1.0), hc_l=(-0.6, -0.2, 1.0), aim_r=(0.4, -0.3, -1.0), aim_l=(-0.4, -0.3, -1.0),
                   curl_r=0.0, curl_l=0.0, spread_r=1.0, spread_l=1.0, fmix_r=1.0, fmix_l=1.0, fc_r=(0.0, -0.1, 0.0), fc_l=(0.0, 0.05, 0.0),
                   knee_r=None, knee_l=None), "whip"),
        (0.6, dict(bob=3.2, fwd=-1.6, body_pitch=-28.0, body_yaw=40.0), "whip"),
    ], wind=2.2, gust=lambda t: (0.0, 0.9 * smooth(seg(t, 0.25, 0.5))))


def hit(r, side):
    """A stray arrow: it flinches from the side it came from, and is still again."""
    s = 1.0 if side == "l" else -1.0          # hit on the left: it folds away to the right
    keyclip(r, f"hit_{side}", SB, [
        (0.0, dict()),
        (0.07, dict(spine_roll=9.0 * s, spine_yaw=-12.0 * s, neck_roll=10.0 * s, head_roll=8.0 * s, sway=0.03 * s, drop=0.1, jaw=14.0,
                    k_eyes_wide=1.0, curl_r=0.0, curl_l=0.0, spread_r=1.0, spread_l=1.0), "snap"),
        (0.25, dict(spine_roll=2.0 * s, spine_yaw=-3.0 * s, neck_roll=3.0 * s, head_roll=2.0 * s, sway=0.0, drop=0.07, jaw=4.0,
                    k_eyes_wide=0.2, curl_r=0.22, curl_l=0.22, spread_r=0.5, spread_l=0.5)),
    ], gust=lambda t: (0.4 * s * pulse(t, 0.0, 0.07, 0.25), 0.0))
