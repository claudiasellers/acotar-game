"""The court's horrors (Acts II-III), merged into gen_act1_audio.py's SOUNDS
and CUES. Self-made from seeded noise and partials, CC0, like the rest.

Canon (lore/04-creatures, Storykeeper): the Suriel comes after "a ripple of
silence" with wheezing sniffing, and its scream in the snare is unavoidable;
four naga come because "they heard my scream"; Tamlin tears out a throat; the
Bogge is never seen, a leeching cold with chattering teeth that begs inside her
head; the puca is silent and ripples like water.
"""
import numpy as np

from dsp import (SR, bp, env_ar, env_exp, fade, grains, hp, lp, moving_bp, normalize,
                 osc_phase, place, reso, reverb, reverb_ir, reverb_mono, rms_to, rng,
                 saturate, secs, smooth_random, stereo, stick_slip, thump, voiced, white,
                 loop_seam, brown, widen)


def _whisper(r, s, f_shift=1.0, rate=5.0):
    """Wordless whispered syllables: breath through gliding vowel formants."""
    n = secs(s)
    src = white(r, n)
    out = np.zeros(n)
    f1 = (450 + 250 * smooth_random(r, n, rate, -1, 1)) * f_shift
    f2 = (1500 + 700 * smooth_random(r, n, rate * 0.8, -1, 1)) * f_shift
    out += moving_bp(src, f1, q=5) * 1.0
    out += moving_bp(src, f2, q=6) * 0.8
    out += hp(src, 4500) * 0.12  # sibilance
    syl = lp((smooth_random(r, n, rate, 0, 1) > 0.4).astype(float), 20)
    return out * syl


def _teeth(r, s, rate=16, gain=1.0):
    """Chattering teeth / bone clicks: a fast, uneven click train."""
    n = secs(s)
    return stick_slip(r, s, np.full(n, float(rate)), [(2400, 10, 1.0), (4100, 12, 0.5)], jitter=0.6) * gain


def _hiss(r, s, swell=0.35):
    n = secs(s)
    h = bp(white(r, n), 2500, 10000)
    tongue = 1 + 0.6 * np.sin(2 * np.pi * r.uniform(20, 30) * np.arange(n) / SR)
    return h * tongue * env_ar(n, swell, s * 0.45, max(s - swell - s * 0.45, 0))


# ---------------------------------------------------------------- the Suriel

def suriel_sniff():
    """Canon: wheezing sniffing in the silence, bone clicking."""
    r = rng(901)
    s = 5.0
    x = np.zeros(secs(s))
    at = 0.2
    for _ in range(4):  # wheezing breaths
        b = secs(r.uniform(0.7, 1.0))
        wheeze = bp(white(r, b), 500, 2500) * env_ar(b, 0.2, 0.5)
        tone = np.sin(osc_phase(np.full(b, r.uniform(780, 900)) * (1 + 0.03 * smooth_random(r, b, 8, -1, 1)))) * env_ar(b, 0.25, 0.4) * 0.15
        place(x, wheeze + tone, at)
        at += r.uniform(0.9, 1.3)
    for t0 in (0.9, 2.9):  # three quick sniffs
        for k in range(3):
            d = secs(0.07)
            place(x, bp(white(r, d), 1200, 6000) * env_ar(d, 0.01, 0.05) * 1.5, t0 + k * 0.11)
    for _ in range(6):  # joints and teeth
        place(x, _teeth(r, 0.12, 30, 0.6), r.uniform(0.2, s - 0.3))
    return normalize(fade(reverb_mono(x, reverb_ir(r, 1.8, 0.4), 0.3), 0.01, 0.3), -4)


def suriel_scream():
    """The snare takes it: an ancient, inhuman shriek that rips and cracks."""
    r = rng(902)
    s = 3.0
    n = secs(s)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for k, (base, g) in enumerate(((820, 1.0), (1240, 0.7), (566, 0.6))):
        f = base * (1 + 0.35 * np.sin(np.clip(t / 1.2, 0, 1) * np.pi / 2)) * (1 - 0.25 * np.clip((t - 1.6) / 1.4, 0, 1))
        f *= 1 + 0.04 * smooth_random(r, n, 25, -1, 1)
        v = voiced(r, f, [(1100, 4, 1.0), (2600, 5, 0.8), (3900, 6, 0.4)], breath=0.5, rough=1.6, sub=0.4)
        out += g * v / (np.max(np.abs(v)) + 1e-9)
    ring = np.sin(2 * np.pi * 37 * t)  # the wrongness: a slow ring modulation
    out = out * (0.75 + 0.25 * ring)
    out += hp(white(r, n), 3000) * 0.25
    out = saturate(out * env_ar(n, 0.04, 1.4, s - 1.5), 2.5)
    snap = np.zeros(n)
    place(snap, hp(white(r, secs(0.03)), 1500) * env_exp(secs(0.03), 0.004) * 1.5, 0.0)
    return normalize(fade(reverb(out + snap, reverb_ir(r, 2.6, 0.5), 0.45), 0.002, 0.4), -1)


def suriel_voice(seed):
    """It answers: a dry rasp of breath shaped into words, teeth clicking."""
    def make():
        r = rng(seed)
        s = 2.6
        n = secs(s)
        w = _whisper(r, s, 0.8, 6.0)
        rasp = voiced(r, np.full(n, 72.0) * (1 + 0.06 * smooth_random(r, n, 3, -1, 1)),
                      [(380, 4, 1.0), (1100, 5, 0.6)], breath=0.6, rough=1.8, sub=0.6)
        rasp = rasp / (np.max(np.abs(rasp)) + 1e-9) * lp((smooth_random(r, n, 6, 0, 1) > 0.45).astype(float), 20)
        x = w * 2.5 + rasp * 0.35 + _teeth(r, s, 7, 0.25)
        x *= env_ar(n, 0.1, 0.4, s - 0.5)
        return normalize(fade(reverb_mono(x, reverb_ir(r, 0.9, 0.3), 0.2), 0.01, 0.2), -4)
    return make


def suriel_warning():
    """'We are not alone': the whisper turns urgent, far off something hisses."""
    r = rng(905)
    x = suriel_voice(906)()
    s = len(x) / SR + 1.5
    out = np.zeros(secs(s))
    place(out, x, 0.0)
    for k in range(3):
        place(out, lp(_hiss(r, 1.2), 3500) * 0.12, 1.4 + k * 0.35)
    return normalize(out, -4)


def snare_snap():
    """The double loop jerks tight: rope whip, a sapling springs, leaves."""
    r = rng(910)
    s = 1.2
    n = secs(s)
    x = np.zeros(n)
    place(x, moving_bp(white(r, secs(0.18)), np.geomspace(800, 4000, secs(0.18)), 2) * env_ar(secs(0.18), 0.03, 0.12), 0.0)
    place(x, hp(white(r, secs(0.04)), 1800) * env_exp(secs(0.04), 0.005) * 1.4, 0.15)
    place(x, stick_slip(r, 0.5, np.linspace(60, 20, secs(0.5)), [(330, 9, 1.0), (900, 10, 0.4)]) * env_ar(secs(0.5), 0.02, 0.4), 0.17)
    place(x, grains(r, 0.9, 900, (1, 4), (1500, 7000), lambda u: np.exp(-u * 4)) * 0.6, 0.15)
    return normalize(fade(x, 0.001, 0.2), -2)


def snare_creak_loop():
    """The snare holding a struggling thing: rope fibres and the bent sapling."""
    r = rng(911)
    L, F = 6.0, 1.0
    n = secs(L + F)
    tension = smooth_random(r, n, 1.2, 0.0, 1.0) ** 2
    rope = stick_slip(r, L + F, 12 + 45 * tension, [(260, 10, 1.0), (720, 12, 0.5), (1500, 14, 0.2)], jitter=0.5)
    rope *= 0.3 + tension
    rustle = grains(r, L + F, 300, (2, 6), (1500, 6000)) * tension
    return rms_to(loop_seam(stereo(rope + rustle * 0.3), L, F), -20)


def snare_release():
    r = rng(912)
    x = snare_snap() * 0.6
    place(x, grains(r, 0.6, 600, (2, 8), (800, 5000), lambda u: np.exp(-u * 3)) * 0.4, 0.2)  # it bolts
    return normalize(x, -3)


# ---------------------------------------------------------------- the naga

def naga_hiss(seed):
    def make():
        r = rng(seed)
        s = r.uniform(1.6, 2.2)
        n = secs(s)
        h = _hiss(r, s, 0.25)
        throat = voiced(r, np.full(n, r.uniform(55, 70)), [(260, 4, 1.0), (700, 5, 0.4)], breath=0.4, rough=1.4, sub=0.8)
        throat = throat / (np.max(np.abs(throat)) + 1e-9) * env_ar(n, 0.3, 0.8, s - 1.1) * 0.35
        return normalize(fade(reverb_mono(h + throat, reverb_ir(r, 1.4, 0.4), 0.25), 0.005, 0.2), -2)
    return make


def naga_attack():
    """One comes at her: leaves and scales, then the hiss rears up."""
    r = rng(921)
    s = 2.2
    x = np.zeros(secs(s))
    place(x, grains(r, 0.9, 2500, (1, 5), (2500, 9000), lambda u: u) * 0.7, 0.0)  # scales through leaves
    place(x, lp(white(r, secs(0.9)), 400) * env_ar(secs(0.9), 0.5, 0.3) * 0.5, 0.0)
    place(x, naga_hiss(922)() * 0.9, 0.7)
    return normalize(x, -1)


def naga_strike():
    """Talons rake her: a whip of air, three streaks, a bite of hiss."""
    r = rng(923)
    s = 0.9
    x = np.zeros(secs(s))
    place(x, moving_bp(white(r, secs(0.2)), np.geomspace(600, 3500, secs(0.2)), 2) * env_ar(secs(0.2), 0.05, 0.12), 0.0)
    for k in range(3):
        d = secs(0.09)
        place(x, bp(white(r, d), 2500, 9000) * env_exp(d, 0.03, 0.001) * 1.2, 0.17 + k * 0.025)
    place(x, thump(110, 0.3, 0.05) * 0.8 + 0, 0.18)
    place(x, _hiss(r, 0.5, 0.02) * 0.6, 0.2)
    return normalize(fade(saturate(x, 1.6), 0.001, 0.15), -1)


def naga_hurt():
    """An arrow or the knife: a hissing shriek."""
    r = rng(924)
    s = 1.0
    n = secs(s)
    t = np.arange(n) / SR
    f = 300 + 260 * np.exp(-t / 0.25)
    v = voiced(r, f, [(700, 4, 1.0), (1800, 5, 0.6), (3000, 6, 0.3)], breath=0.8, rough=1.6, sub=0.3)
    v = saturate(v / (np.max(np.abs(v)) + 1e-9), 2.5) * env_ar(n, 0.01, 0.7, 0.2)
    return normalize(fade(v + _hiss(r, s, 0.01) * 0.6, 0.001, 0.15), -1)


def naga_death():
    """It goes down: a gurgling hiss, thrashing coils, then still."""
    r = rng(925)
    s = 3.4
    n = secs(s)
    t = np.arange(n) / SR
    gurgle = voiced(r, 90 + 30 * np.exp(-t / 1.0), [(400, 3, 1.0), (1100, 4, 0.5)], breath=0.5, rough=2.0, sub=0.9)
    bubbles = 1 + 0.8 * smooth_random(r, n, 22, -1, 1)
    gurgle = gurgle / (np.max(np.abs(gurgle)) + 1e-9) * bubbles * env_ar(n, 0.05, 2.2, 0.4) * 0.6
    x = gurgle + _hiss(r, s, 0.05) * np.exp(-t / 0.9) * 0.6
    for k in range(6):  # thrashing in leaves and mud
        d = secs(0.2)
        place(x, lp(white(r, d), 1500) * env_ar(d, 0.02, 0.15) * r.uniform(0.4, 0.9) * np.exp(-k / 3), 0.1 + k * r.uniform(0.2, 0.35))
    return normalize(fade(reverb_mono(x, reverb_ir(r, 1.6, 0.4), 0.25), 0.002, 0.4), -2)


def throat_tear():
    """Tamlin tears out a naga's throat: a wet rip under a roar."""
    r = rng(926)
    s = 1.4
    n = secs(s)
    rip = lp(white(r, n), 2000) * (1 + 0.9 * smooth_random(r, n, 70, -1, 1)) * env_ar(n, 0.02, 0.5, 0.15)
    crackle = grains(r, 0.6, 1800, (0.3, 2.0), (800, 5000), lambda u: np.exp(-u * 3))
    x = rip * 0.8 + thump(70, s, 0.15) * 0.8
    place(x, crackle * 0.6, 0.05)
    roar = voiced(r, np.full(n, 70.0) * (1 + 0.2 * np.sin(np.linspace(0, np.pi, n))),
                  [(450, 4, 1.0), (1000, 5, 0.6), (2200, 6, 0.3)], breath=0.4, rough=1.5, sub=1.0)
    roar = saturate(roar / (np.max(np.abs(roar)) + 1e-9), 2.5) * env_ar(n, 0.1, 0.8, 0.4) * 0.6
    return normalize(fade(reverb_mono(x + roar, reverb_ir(r, 1.4, 0.4), 0.25), 0.001, 0.3), -1)


# ---------------------------------------------------------------- the Bogge

def bogge_presence_loop():
    """Never seen: a leeching cold. Sub pressure that throbs wrong, an icy
    beating whine, teeth chattering, wood creaking as plants recoil."""
    r = rng(931)
    L, F = 12.0, 2.0
    n = secs(L + F)
    t = np.arange(n) / SR
    throb = 0.5 + 0.5 * np.sin(osc_phase(0.7 + 0.5 * smooth_random(r, n, 0.4)))
    sub = (np.sin(2 * np.pi * 31 * t) + 0.5 * np.sin(2 * np.pi * 46.5 * t)) * throb
    ice = (np.sin(2 * np.pi * 7040 * t) + np.sin(2 * np.pi * 7047.5 * t)) * 0.004
    chatter = np.zeros(n)
    for _ in range(5):
        d = r.uniform(0.6, 1.4)
        place(chatter, _teeth(r, d, r.uniform(12, 18)) * env_ar(secs(d), 0.1, 0.3), r.uniform(0, L))
    air = lp(brown(r, n), 200) * 0.4
    x = stereo(sub * 0.5 + air) + widen(r, ice + chatter * 0.25, 19)
    return rms_to(loop_seam(x, L, F), -22)


def bogge_whisper(seed):
    """It begs inside her head: several whispering voices, close, wordless,
    circling the listener (flat, no room)."""
    def make():
        r = rng(seed)
        s = 3.2
        n = secs(s)
        x = np.zeros((2, n))
        for k in range(4):
            w = _whisper(r, s, r.uniform(0.6, 1.2), r.uniform(4.0, 7.0))
            pan = np.sin(2 * np.pi * (k / 4 + np.arange(n) / SR / 3.0))  # circling
            x[0] += w * (1 - pan) * 0.5
            x[1] += w * (1 + pan) * 0.5
        under = voiced(r, np.full(n, 48.0), [(220, 3, 1.0), (600, 4, 0.5)], breath=0.5, rough=1.6, sub=1.0)
        under = under / (np.max(np.abs(under)) + 1e-9) * 0.2
        x += stereo(under)
        return normalize(fade(x * env_ar(n, 0.4, 0.8, s - 1.2), 0.02, 0.3), -3)
    return make


def bogge_passed():
    """It moves on: the cold lets go in one long falling breath."""
    r = rng(935)
    s = 3.0
    n = secs(s)
    breath = moving_bp(white(r, n), np.geomspace(1600, 300, n), 2) * env_ar(n, 0.4, 2.2)
    sub = np.sin(osc_phase(np.geomspace(40, 22, n))) * env_ar(n, 0.1, 2.5) * 0.6
    return normalize(fade(stereo(breath * 0.6 + sub)), -6)


# ---------------------------------------------------------------- the puca

def puca_ripple():
    """It changes what it shows: a soft watery shimmer (it is silent in the
    book; this is the light rippling, kept quiet)."""
    r = rng(941)
    s = 1.8
    n = secs(s)
    x = np.zeros(n)
    for k in range(7):
        d = secs(r.uniform(0.5, 1.0))
        f = np.geomspace(r.uniform(1800, 3200), r.uniform(700, 1100), d)
        place(x, np.sin(osc_phase(f)) * env_ar(d, 0.05, 0.4) * 0.3, r.uniform(0, 0.8))
    x += bp(white(r, n), 3000, 8000) * env_ar(n, 0.3, 1.2) * 0.05
    return normalize(fade(reverb(x, reverb_ir(r, 1.8, 0.8), 0.5), 0.01, 0.4), -12)


def puca_dart():
    r = rng(942)
    s = 0.8
    n = secs(s)
    w = moving_bp(white(r, n), np.geomspace(4000, 900, n), 3) * env_ar(n, 0.03, 0.6)
    return normalize(fade(reverb(w, reverb_ir(r, 1.2, 0.8), 0.4), 0.002, 0.2), -8)


SOUNDS = {
    "sfx/suriel/sniff": (suriel_sniff, 4, "The Suriel's wheezing sniffing as it nears"),
    "sfx/suriel/scream": (suriel_scream, 4, "The Suriel screams as the snare takes it"),
    "sfx/suriel/voice_1": (suriel_voice(903), 4, "The Suriel answers (wordless rasp), variant 1"),
    "sfx/suriel/voice_2": (suriel_voice(904), 4, "The Suriel answers (wordless rasp), variant 2"),
    "sfx/suriel/voice_3": (suriel_voice(907), 4, "The Suriel answers (wordless rasp), variant 3"),
    "sfx/suriel/warning": (suriel_warning, 4, "The Suriel: 'We are not alone', a hiss far off"),
    "sfx/suriel/snare_snap": (snare_snap, 4, "The double-loop snare jerks tight"),
    "sfx/suriel/snare_creak": (snare_creak_loop, 3, "The snare straining under a struggling thing (loop)"),
    "sfx/suriel/snare_release": (snare_release, 4, "The tether cut, the Suriel bolts"),
    "sfx/naga/hiss_1": (naga_hiss(927), 4, "Naga hiss, variant 1"),
    "sfx/naga/hiss_2": (naga_hiss(928), 4, "Naga hiss, variant 2"),
    "sfx/naga/hiss_3": (naga_hiss(929), 4, "Naga hiss, variant 3"),
    "sfx/naga/attack": (naga_attack, 4, "A naga comes at her through the leaves"),
    "sfx/naga/strike": (naga_strike, 4, "Naga talons rake her"),
    "sfx/naga/hurt": (naga_hurt, 4, "A naga's hissing shriek when hit"),
    "sfx/naga/death": (naga_death, 4, "A naga dies: gurgling hiss, thrashing"),
    "sfx/naga/throat_tear": (throat_tear, 4, "Tamlin tears out a naga's throat"),
    "sfx/bogge/presence": (bogge_presence_loop, 3, "The Bogge near: sub throb, icy whine, chattering teeth (loop)"),
    "sfx/bogge/whisper_1": (bogge_whisper(932), 4, "The Bogge begs inside her head, variant 1"),
    "sfx/bogge/whisper_2": (bogge_whisper(933), 4, "The Bogge begs inside her head, variant 2"),
    "sfx/bogge/whisper_3": (bogge_whisper(934), 4, "The Bogge begs inside her head, variant 3"),
    "sfx/bogge/passed": (bogge_passed, 4, "The Bogge passes: the cold lets go"),
    "sfx/puca/ripple": (puca_ripple, 4, "The puca's image ripples like water"),
    "sfx/puca/dart": (puca_dart, 4, "The puca darts away in a shimmer"),
}

# cue id: (files, volume_db, pitch_jitter, loop, music, max_distance)
CUES = {
    "suriel_sniff": (["sfx/suriel/sniff"], -2, 0.03, False, False, 50),
    "suriel_scream": (["sfx/suriel/scream"], 2, 0.02, False, False, 250),
    "suriel_voice": (["sfx/suriel/voice_%d" % i for i in (1, 2, 3)], -2, 0.03, False, False, 30),
    "suriel_warning": (["sfx/suriel/warning"], -1, 0, False, False, 30),
    "snare_snap": (["sfx/suriel/snare_snap"], -2, 0.03, False, False, 60),
    "snare_creak": (["sfx/suriel/snare_creak"], -4, 0, True, False, 40),
    "snare_release": (["sfx/suriel/snare_release"], -2, 0.03, False, False, 60),
    "naga_hiss": (["sfx/naga/hiss_%d" % i for i in (1, 2, 3)], 0, 0.08, False, False, 70),
    "naga_attack": (["sfx/naga/attack"], 0, 0.06, False, False, 80),
    "naga_strike": (["sfx/naga/strike"], 0, 0.05, False, False, 40),
    "naga_hurt": (["sfx/naga/hurt"], 0, 0.08, False, False, 80),
    "naga_death": (["sfx/naga/death"], 0, 0.05, False, False, 80),
    "tamlin_throat_tear": (["sfx/naga/throat_tear"], 2, 0, False, False, 120),
    "bogge_presence": (["sfx/bogge/presence"], -2, 0, True, False, 0),
    "bogge_whisper": (["sfx/bogge/whisper_%d" % i for i in (1, 2, 3)], -3, 0.04, False, False, 0),
    "bogge_passed": (["sfx/bogge/passed"], -4, 0, False, False, 0),
    "puca_ripple": (["sfx/puca/ripple"], -6, 0.05, False, False, 60),
    "puca_dart": (["sfx/puca/dart"], -4, 0.05, False, False, 60),
}
