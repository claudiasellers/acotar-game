"""The bow's feel sounds (bow design §5.8, slice B3), merged into
gen_act1_audio.py's SOUNDS and CUES. Self-made from seeded noise and
partials, CC0, like the rest.

What each one is for: the
creak loop is a held full draw; the let-down is the string eased forward with
nothing loosed; the pat is her hand on an empty quiver; a short gasp when
she has no breath left for a sidestep; each bow has its own
release and the ash arrow a deeper one with a chime tail; Focus is an inhale
and, let go, an exhale, with her heartbeat under it; each arrow type has a
short sound of its own, so what is chosen can be heard; an arrow pulled out
of what it stuck in; the bow limb as a club; an arrow on stone. Two more for
tracking: what a lost deer and a lost rabbit give away (CreatureData.lost_cue).
"""
import numpy as np

from dsp import (SR, BELL, bp, env_ar, env_exp, fade, grains, hp, loop_seam, lp, moving_bp,
                 normalize, osc_phase, pink, place, reso, rms_to, rng, saturate, secs,
                 smooth_random, stick_slip, thump, tone, voiced, white)

ARROW_TYPES = ("wood", "ash", "fire", "frost", "sleep", "lure", "light", "barbed", "rope", "signal")


def _t(n):
    return np.arange(n) / SR


def creak_loop():
    r = rng(1302)
    total, x = 1.8, 0.3
    s = total + x
    n = secs(s)
    creak = stick_slip(r, s, 16 + 7 * smooth_random(r, n, 1.5, -1, 1), [(330, 12, 1.0), (910, 14, 0.5), (2150, 16, 0.2)], jitter=0.4)
    strain = bp(pink(r, n), 150, 380) * (0.35 + 0.15 * smooth_random(r, n, 2.0, -1, 1))
    return rms_to(loop_seam(creak * 0.6 + strain * 0.4, total, x), -24)


def let_down():
    r = rng(1303)
    s = 0.5
    n = secs(s)
    creak = stick_slip(r, s, np.linspace(70, 14, n), [(300, 10, 1.0), (840, 12, 0.5)], jitter=0.3) * env_ar(n, 0.02, 0.4)
    sigh = lp(white(r, n), 1400) * env_ar(n, 0.08, 0.35) * 0.25
    return normalize(fade(creak + sigh, 0.005, 0.12), -10)


def empty_pat():
    r = rng(1304)
    s = 0.34
    n = secs(s)
    x = np.zeros(n)
    for at, gain in ((0.0, 1.0), (0.13, 0.7)):
        g = secs(0.12)
        pat = lp(white(r, g), 900) * env_exp(g, 0.022, 0.001) + thump(120, 0.12, 0.03, 0.5) * 0.5
        place(x, pat, at, gain)
    return normalize(fade(x, 0.0005, 0.05), -9)


def _release(seed, f0, decay, slap_hz, slap, body, s=0.75, partials=9, tilt=1.3):
    r = rng(seed)
    n = secs(s)
    t = _t(n)
    f = f0 * (1 + 0.05 * np.exp(-t / 0.02))
    twang = sum(np.sin(osc_phase(f * k)) / k ** tilt * np.exp(-t / (decay / k ** 0.5)) for k in range(1, partials))
    snap = hp(white(r, n), slap_hz) * env_exp(n, 0.006, 0.0002)
    return twang * 0.7 + snap * slap + thump(f0 * 0.62, s, 0.045) * body


def release_warbow():
    return normalize(fade(saturate(_release(1310, 88, 0.3, 900, 1.0, 1.1, s=0.9), 1.6), 0.0005, 0.12), -1)


def release_recurve():
    return normalize(fade(_release(1311, 176, 0.14, 2400, 0.9, 0.25, s=0.5, tilt=1.0), 0.0005, 0.08), -4)


def release_gilded():
    r = rng(1312)
    x = _release(1312, 132, 0.2, 1500, 0.7, 0.5, s=1.6)
    ring = tone(1056, 1.6, BELL, 1.1, 0.6, r, 0.002) * 0.22
    return normalize(fade(x + ring, 0.0005, 0.3), -3)


def release_ash():
    """Her one sacred arrow: a deeper thrum, and a faint chime after it."""
    r = rng(1313)
    x = _release(1313, 98, 0.34, 1100, 0.8, 0.9, s=1.9)
    chime = np.zeros(secs(1.9))
    place(chime, tone(1568, 1.5, BELL, 0.9, 0.5, r, 0.002) * 0.1, 0.09)
    place(chime, tone(2349, 1.3, BELL, 0.7, 0.5, r, 0.002) * 0.05, 0.16)
    return normalize(fade(x + chime, 0.0005, 0.4), -2)


def _breath(seed, s, lo, hi, rise):
    r = rng(seed)
    n = secs(s)
    centre = np.geomspace(lo, hi, n)
    air = moving_bp(white(r, n), centre, q=1.6) + hp(white(r, n), 5000) * 0.08
    return air * (env_ar(n, s * 0.55, s * 0.4) if rise else env_ar(n, 0.06, s * 0.85))


def focus_in():
    return normalize(fade(_breath(1320, 0.9, 700, 1700, True), 0.02, 0.15), -14)


def focus_out():
    return normalize(fade(_breath(1321, 1.1, 1300, 500, False), 0.01, 0.3), -15)


def winded():
    # A short, sharp breath in through the teeth: she has nothing left to move on.
    return normalize(fade(_breath(1322, 0.32, 1500, 3200, True), 0.01, 0.08), -12)


def heartbeat():
    """One slow beat (lub, dub), looped at 56 a minute: in her ears, muffled."""
    L = 60.0 / 56.0
    x = np.zeros(secs(L))
    place(x, thump(56, 0.22, 0.055, 0.4), 0.02)
    place(x, thump(48, 0.22, 0.065, 0.4) * 0.7, 0.02 + 0.16)
    return rms_to(lp(x, 150), -20)


def _select(kind):
    r = rng(1330 + ARROW_TYPES.index(kind))
    s = 0.32
    n = secs(s)
    t = _t(n)
    tick = reso(white(r, n), 1700, 16) * env_exp(n, 0.01, 0.0003) * 0.6
    if kind == "wood":
        x = tick + reso(white(r, n), 640, 10) * env_exp(n, 0.02) * 0.6
    elif kind == "ash":
        x = tick * 0.4 + tone(1568, s, BELL, 0.22, 0.5, r, 0.002) * 0.5
    elif kind == "fire":
        x = tick * 0.3 + grains(r, s, 900, (0.3, 2.0), (1500, 7000), lambda u: np.exp(-u * 3)) * 0.9
    elif kind == "frost":
        x = sum(tone(f, s, [(1, 1.0), (2.7, 0.3)], 0.08, 0.5) * g for f, g in ((3520, 0.5), (4699, 0.35), (5274, 0.25)))
        x = x * 0.5 + tick * 0.3
    elif kind == "sleep":
        x = np.sin(2 * np.pi * 196 * t) * (1 + 0.3 * np.sin(2 * np.pi * 5 * t)) * env_ar(n, 0.05, 0.22) * 0.6 + tick * 0.2
    elif kind == "lure":
        x = tone(988, s, BELL, 0.2, 0.4, r, 0.001) * 0.6 + tick * 0.2
    elif kind == "light":
        x = sum(tone(f, s, [(1, 1.0)], 0.1, 0) * 0.3 for f in (2093, 2637, 3136, 3951)) * env_ar(n, 0.04, 0.24) + tick * 0.2
    elif kind == "barbed":
        x = stick_slip(r, s, np.linspace(220, 90, n), [(2400, 9, 1.0), (4100, 10, 0.5)], jitter=0.5) * env_ar(n, 0.01, 0.2) * 0.5 + tick * 0.4
    elif kind == "rope":
        x = stick_slip(r, s, np.linspace(40, 22, n), [(260, 9, 1.0), (700, 10, 0.5)], jitter=0.3) * env_ar(n, 0.02, 0.26) + tick * 0.2
    else:  # signal
        x = moving_bp(white(r, n), np.geomspace(2500, 6500, n), q=3.0) * env_ar(n, 0.02, 0.26) * 0.8 + tick * 0.2
    return normalize(fade(x, 0.0005, 0.06), -12)


def _selector(kind):
    return lambda: _select(kind)


def retrieve():
    r = rng(1350)
    s = 0.36
    n = secs(s)
    pull = stick_slip(r, s, np.linspace(160, 60, n), [(520, 8, 1.0), (1400, 10, 0.4)], jitter=0.4) * env_ar(n, 0.01, 0.16, 0.05)
    out = np.zeros(n)
    g = secs(0.1)
    place(out, (lp(white(r, g), 1100) * env_exp(g, 0.02, 0.001) + thump(170, 0.1, 0.02, 0.4) * 0.6), 0.2)
    return normalize(fade(pull * 0.7 + out, 0.002, 0.06), -9)


def bash():
    r = rng(1351)
    s = 0.4
    n = secs(s)
    knock = sum(g * reso(white(r, n), f, 9) for f, g in ((430, 1.0), (980, 0.5))) * env_exp(n, 0.03, 0.0005)
    return normalize(fade(saturate(knock * 1.5 + thump(95, s, 0.06) * 1.0, 1.6), 0.0005, 0.08), -3)


def hit_stone():
    r = rng(1352)
    s = 0.6
    n = secs(s)
    x = np.zeros(n)
    for at, gain, f in ((0.0, 1.0, 3200), (0.11, 0.45, 2700), (0.19, 0.3, 3600), (0.25, 0.18, 3000)):
        g = secs(0.12)
        clack = (reso(white(r, g), f, 22) + reso(white(r, g), f * 1.83, 20) * 0.5) * env_exp(g, 0.012, 0.0002)
        place(x, clack, at, gain)
    return normalize(fade(x + hp(white(r, n), 4000) * env_exp(n, 0.004) * 0.4, 0.0003, 0.1), -4)


def deer_lost():
    """A lost deer gives itself away: a crash in the brush, then a snort."""
    r = rng(1360)
    s = 1.7
    n = secs(s)
    crash = grains(r, s, 1400, (0.5, 4.0), (500, 6000), lambda u: np.exp(-u * 4.5) if u < 0.6 else 0.0)
    for at in (0.05, 0.22, 0.4):
        g = secs(0.2)
        place(crash, reso(white(r, g), r.uniform(900, 1700), 10) * env_exp(g, 0.02, 0.0003) * 0.8, at)
    m = secs(0.5)
    snort = (bp(white(r, m), 350, 2600) * env_ar(m, 0.015, 0.4)) * (1 + 0.5 * np.sin(2 * np.pi * 38 * _t(m)))
    x = crash * 0.8
    place(x, snort * 0.9, 1.05)
    return normalize(fade(x, 0.002, 0.2), -4)


def hare_lost():
    """A lost rabbit: one thin squeal, somewhere in the brush."""
    r = rng(1361)
    s = 0.7
    n = secs(s)
    f0 = 1250 + 500 * np.exp(-_t(n) / 0.12) + 60 * np.sin(2 * np.pi * 21 * _t(n))
    cry = voiced(r, f0, [(2300, 5, 1.0), (3900, 6, 0.6), (5600, 7, 0.25)], breath=0.3, rough=0.4) * env_ar(n, 0.02, 0.5, 0.1)
    rustle = grains(r, s, 500, (0.4, 2.0), (1200, 6000), lambda u: np.exp(-u * 3)) * 0.3
    return normalize(fade(cry + rustle, 0.002, 0.15), -8)


SOUNDS = {
    "sfx/bow/creak_loop": (creak_loop, 4, "A held full draw: string and limb creak (loop)"),
    "sfx/bow/let_down": (let_down, 4, "The string eased forward, nothing loosed"),
    "sfx/bow/empty_pat": (empty_pat, 4, "Her hand pats an empty quiver"),
    "sfx/bow/release_warbow": (release_warbow, 4, "Sentry warbow release: a heavy thwack"),
    "sfx/bow/release_recurve": (release_recurve, 4, "Fae recurve release: a soft bright snap"),
    "sfx/bow/release_gilded": (release_gilded, 4, "Gilded bow release: a ringing note"),
    "sfx/bow/release_ash": (release_ash, 4, "The ash arrow leaves: a deeper thrum with a faint chime tail"),
    "sfx/bow/focus_in": (focus_in, 4, "Focus: a steadying inhale"),
    "sfx/bow/focus_out": (focus_out, 4, "Focus let go: an exhale"),
    "sfx/bow/winded": (winded, 4, "Out of breath: a short gasp when she can't sidestep"),
    "sfx/bow/heartbeat": (heartbeat, 4, "Her heartbeat in the hush, one slow beat (loop)"),
    "sfx/bow/retrieve": (retrieve, 4, "An arrow pulled out of what it stuck in"),
    "sfx/bow/bash": (bash, 4, "The bow limb as a club: a wooden thud"),
    "sfx/bow/hit_stone": (hit_stone, 4, "An arrow clatters off stone"),
    "sfx/prey/deer_lost": (deer_lost, 4, "A lost deer gives itself away: a crash in the brush and a snort"),
    "sfx/prey/hare_lost": (hare_lost, 4, "A lost rabbit squeals in the brush"),
}
SOUNDS.update({"sfx/arrow/select_%s" % k: (_selector(k), 4, "The %s arrow comes to hand" % k) for k in ARROW_TYPES})

# cue id: (files, volume_db, pitch_jitter, loop, music, max_distance)
CUES = {
    "bow_creak": (["sfx/bow/creak_loop"], -10, 0, True, False, 20),
    "bow_let_down": (["sfx/bow/let_down"], -8, 0.05, False, False, 20),
    "bow_empty": (["sfx/bow/empty_pat"], -8, 0.05, False, False, 20),
    "bow_release_sentry_warbow": (["sfx/bow/release_warbow"], -1, 0.03, False, False, 70),
    "bow_release_fae_recurve": (["sfx/bow/release_recurve"], -4, 0.04, False, False, 50),
    "bow_release_gilded_bow": (["sfx/bow/release_gilded"], -3, 0.02, False, False, 60),
    "bow_release_ash": (["sfx/bow/release_ash"], -2, 0, False, False, 60),
    "bow_focus_in": (["sfx/bow/focus_in"], -10, 0.03, False, False, 0),
    "bow_focus_out": (["sfx/bow/focus_out"], -11, 0.03, False, False, 0),
    "breath_winded": (["sfx/bow/winded"], -7, 0.04, False, False, 0),
    "bow_heartbeat": (["sfx/bow/heartbeat"], -8, 0, True, False, 0),
    "arrow_retrieve": (["sfx/bow/retrieve"], -8, 0.06, False, False, 20),
    "bow_bash": (["sfx/bow/bash"], -3, 0.06, False, False, 40),
    "bow_hit_stone": (["sfx/bow/hit_stone"], -3, 0.08, False, False, 70),
    "deer_lost": (["sfx/prey/deer_lost"], -2, 0.04, False, False, 90),
    "hare_lost": (["sfx/prey/hare_lost"], -4, 0.05, False, False, 70),
}
CUES.update({"arrow_select_%s" % k: (["sfx/arrow/select_%s" % k], -10, 0.02, False, False, 0) for k in ARROW_TYPES})
