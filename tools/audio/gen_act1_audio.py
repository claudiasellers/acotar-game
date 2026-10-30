"""Generates every Act I sound and music file from fixed seeds (R8, R15).

    python3 tools/audio/gen_act1_audio.py            # all files
    python3 tools/audio/gen_act1_audio.py beast_roar # only names containing it

Writes OGG Vorbis into audio/ and audio/CREDITS.md. Everything is synthesised
here (no samples, no downloads), so every file is self-made and CC0. Canon
notes come from the Storykeeper (lore/07-story/book-scene-spaces.md):
the wolf arrives in silence and dies whining; the beast is a hush cut by a
roar and a bellow; the Spring Court arrival has small birds and no music.
Needs Python 3, numpy, scipy and ffmpeg with libvorbis.
"""
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).parent))
from dsp import *  # noqa: E402,F401,F403

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "audio"
GEN = "tools/audio/gen_act1_audio.py"

# ======================================================================
# Ambience beds (stereo, seamless loops)
# ======================================================================

def _wind(r, n, strength=1.0, whistle=True):
    gust = smooth_random(r, n, 0.12, 0.15, 1.0) * smooth_random(r, n, 0.5, 0.55, 1.0)
    gust = gust ** 1.6 * strength
    chans = []
    for _ in range(2):
        body = bp(pink(r, n), 120, 900) * (0.35 + gust)
        hiss = hp(white(r, n), 3500) * 0.05 * gust
        x = body + hiss
        if whistle:
            centre = 520 + 380 * smooth_random(r, n, 0.2)
            x += moving_bp(white(r, n), centre, q=14) * 2.2 * gust ** 2
        chans.append(x)
    return np.vstack(chans), gust


def _creak(r, s=1.2, low=False):
    n = secs(s)
    rate = np.linspace(r.uniform(18, 30), r.uniform(35, 60), n) * (0.6 if low else 1)
    modes = [(r.uniform(260, 420), 9, 1.0), (r.uniform(700, 1100), 10, 0.5), (r.uniform(1600, 2200), 12, 0.2)]
    if low:
        modes = [(f * 0.55, q, g) for f, q, g in modes]
    return fade(stick_slip(r, s, rate, modes) * env_ar(n, 0.15, 0.4, s - 0.6), 0.01, 0.1)


def _crow(r):
    """A distant crow: three harsh falling caws."""
    out = np.zeros(secs(1.6))
    at = 0.0
    for _ in range(r.integers(2, 4)):
        n = secs(r.uniform(0.22, 0.32))
        f0 = np.linspace(r.uniform(560, 640), r.uniform(420, 470), n)
        caw = voiced(r, f0, [(1100, 4, 1.0), (1900, 5, 0.6), (3100, 6, 0.3)], breath=0.25, rough=0.9)
        place(out, caw * env_ar(n, 0.02, 0.12, n / SR - 0.15), at)
        at += r.uniform(0.38, 0.5)
    return out


def amb_winter_wood():
    r = rng(101)
    L, F = 48.0, 3.0
    n = secs(L + F)
    wind, gust = _wind(r, n, 1.0)
    x = wind * 0.9
    x += np.vstack([hp(white(r, n), 6000) for _ in range(2)]) * 0.02 * (0.3 + gust)  # snow sifting
    ir = reverb_ir(r, 2.4, 0.3)
    for _ in range(4):
        place(x, reverb_mono(_creak(r, r.uniform(0.8, 1.6)), ir, 0.5) * 0.25, r.uniform(1, L), pan=r.uniform(-0.8, 0.8))
    for at in (r.uniform(6, 16), r.uniform(28, 40)):
        place(x, lp(reverb_mono(_crow(r), ir, 0.9), 2500) * 0.06, at, pan=r.uniform(-0.9, 0.9))
    return rms_to(loop_seam(x, L, F), -24)


def amb_cottage_yard():
    r = rng(102)
    L, F = 44.0, 3.0
    n = secs(L + F)
    wind, gust = _wind(r, n, 0.6, whistle=False)
    x = wind * 0.7
    ir = reverb_ir(r, 1.2, 0.3)
    for _ in range(3):  # the cottage's boards and shutters
        place(x, reverb_mono(_creak(r, r.uniform(0.6, 1.2), low=True), ir, 0.3) * 0.3, r.uniform(1, L), pan=r.uniform(-0.5, 0.5))
    for _ in range(2):  # a shutter knocking in a gust
        knock = lp(thump(160, 0.15, 0.04) + reso(white(r, secs(0.15)), 620, 6) * env_exp(secs(0.15), 0.03), 3000)
        t0 = r.uniform(3, L - 4)
        for k in range(r.integers(2, 4)):
            place(x, knock * 0.12, t0 + k * r.uniform(0.25, 0.5), pan=0.4)
    return rms_to(loop_seam(x, L, F), -26)


def _fire(r, n):
    rumble = lp(brown(r, n), 180) * (0.6 + 0.4 * smooth_random(r, n, 0.7))
    roar = bp(pink(r, n), 200, 1200) * 0.15 * smooth_random(r, n, 1.5, 0.4, 1.0)
    crackle = np.zeros(n)
    s = n / SR
    for _ in range(int(s * 7)):
        g = secs(r.uniform(0.002, 0.025))
        f = r.uniform(1200, 6000)
        tick = reso(white(r, g + 200), f, 2)[:g] * env_exp(g, r.uniform(0.002, 0.01), 0.0003)
        place(crackle, tick * r.uniform(0.2, 1.0) ** 2 * 3, r.uniform(0, s))
    for _ in range(int(s / 3)):  # bigger pops and sap hiss
        place(crackle, hp(white(r, secs(0.05)), 1500) * env_exp(secs(0.05), 0.008) * 3, r.uniform(0, s))
    return rumble + roar + crackle


def amb_cottage_hearth():
    r = rng(103)
    L, F = 40.0, 3.0
    n = secs(L + F)
    fire = _fire(r, n)
    x = np.vstack([fire, np.roll(fire, 37)]) * np.array([[1.0], [0.85]])
    wind, _ = _wind(r, n, 0.7, whistle=True)
    x += lp(wind, 500) * 0.25  # the storm through thin walls
    ir = reverb_ir(r, 0.6, 0.4)
    for _ in range(3):
        place(x, reverb_mono(_creak(r, r.uniform(0.7, 1.3), low=True), ir, 0.4) * 0.18, r.uniform(1, L), pan=r.uniform(-0.6, 0.6))
    return rms_to(loop_seam(x, L, F), -25)


def _babble(r, n):
    """Distant voices: noise through gliding vowel formants, syllable-chopped."""
    out = np.zeros(n)
    for v in range(5):
        syl = (smooth_random(r, n, r.uniform(4, 6.5), 0, 1) > 0.45).astype(float)
        syl = lp(syl, 18)
        phrase = (smooth_random(r, n, 0.25, 0, 1) > 0.5).astype(float)
        phrase = lp(phrase, 2)
        f0 = r.uniform(110, 230) * (1 + 0.08 * smooth_random(r, n, 3, -1, 1))
        vo = voiced(r, f0, lambda t, k=v: [(500 + 250 * np.sin(t * 7 + k), 5, 1.0), (1500 + 400 * np.sin(t * 5 + k * 2), 6, 0.5)], breath=0.1, rough=0.2)
        out += vo * syl * phrase
    return lp(out, 1600)


def amb_village():
    r = rng(104)
    L, F = 44.0, 3.0
    n = secs(L + F)
    wind, _ = _wind(r, n, 0.45, whistle=False)
    x = wind * 0.6
    voices = _babble(r, n)
    x += widen(r, voices, 17) * 0.5
    ir = reverb_ir(r, 1.8, 0.4)
    anvil = place(bell(1250, 0.9, r) * 0.6, bell(1873, 0.6, r) * 0.25, 0.0)
    t = 2.0
    while t < L - 3:  # a smith at work, in bursts
        for k in range(r.integers(3, 7)):
            place(x, reverb_mono(anvil, ir, 0.6) * 0.035, t + k * 0.55, pan=0.55)
        t += r.uniform(7, 12)
    for _ in range(3):  # a cart creaking past, a door
        place(x, reverb_mono(_creak(r, r.uniform(1.2, 2.0), low=True), ir, 0.4) * 0.12, r.uniform(1, L), pan=r.uniform(-0.8, 0.8))
    return rms_to(loop_seam(x, L, F), -24)


def amb_wall_seam():
    """The Wall: wind thins out, a low pressure hum and a glassy shimmer."""
    r = rng(105)
    L, F = 40.0, 4.0
    n = secs(L + F)
    t = np.arange(n) / SR
    wind, _ = _wind(r, n, 0.25, whistle=False)
    hum = (np.sin(2 * np.pi * 55 * t) + 0.6 * np.sin(2 * np.pi * 55.35 * t) + 0.3 * np.sin(2 * np.pi * 82.6 * t)) * 0.12
    shimmer = np.zeros(n)
    for f in (3520, 4186, 4699, 5274):
        shimmer += np.sin(2 * np.pi * f * t + r.uniform(0, 6)) * smooth_random(r, n, 0.3, 0, 1) ** 3
    x = wind * 0.35 + stereo(hum) + widen(r, shimmer * 0.012, 23)
    return rms_to(loop_seam(x, L, F), -30)


def _bird_phrase(r, kind=0):
    """A small songbird: quick sine chirps with steep pitch sweeps."""
    out = np.zeros(secs(2.2))
    at = 0.0
    base = r.uniform(2800, 4200)
    for i in range(r.integers(3, 8)):
        d = r.uniform(0.04, 0.12)
        n = secs(d)
        f_from = base * r.uniform(0.85, 1.25)
        f_to = f_from * r.uniform(0.6, 1.5)
        f = np.linspace(f_from, f_to, n) + 180 * np.sin(np.linspace(0, r.uniform(6, 30), n))
        chirp = np.sin(osc_phase(f)) * np.hanning(n)
        place(out, chirp * r.uniform(0.5, 1.0), at)
        at += d + r.uniform(0.02, 0.1)
    if kind == 1:  # the bunting's trailing buzz
        n = secs(0.35)
        f = np.full(n, base * 0.8) + 300 * np.sin(np.linspace(0, 90, n))
        place(out, np.sin(osc_phase(f)) * np.hanning(n) * 0.5, at)
    return out


def amb_spring_arrival():
    """Canon: hushed estate, balmy breeze, small birds the only sound."""
    r = rng(106)
    L, F = 48.0, 3.0
    n = secs(L + F)
    breeze = np.vstack([lp(pink(r, n), 700) for _ in range(2)]) * (0.25 + 0.2 * smooth_random(r, n, 0.15))
    leaves = np.vstack([hp(white(r, n), 2500) for _ in range(2)]) * 0.025 * smooth_random(r, n, 0.4, 0, 1) ** 2
    x = breeze + leaves
    ir = reverb_ir(r, 1.6, 0.6)
    t = 1.0
    while t < L:
        ph = _bird_phrase(r, int(r.random() < 0.3))
        place(x, reverb(ph, ir, 0.35) * r.uniform(0.04, 0.09), t)
        t += r.uniform(2.5, 7.0)
    tt = np.arange(n) / SR  # "the faint stench of metal": a thin high shimmer
    metal = sum(np.sin(2 * np.pi * f * tt) for f in (6272, 7040)) * smooth_random(r, n, 0.1, 0, 1) ** 4
    x += widen(r, metal * 0.004, 19)
    return rms_to(loop_seam(x, L, F), -30)


def amb_dread():
    """The world withdraws: near silence, a sub-bass pressure, nothing else."""
    r = rng(107)
    L, F = 30.0, 3.0
    n = secs(L + F)
    t = np.arange(n) / SR
    sub = np.sin(2 * np.pi * 36 * t) * (0.6 + 0.4 * smooth_random(r, n, 0.2))
    air = np.vstack([lp(brown(r, n), 120) for _ in range(2)]) * 0.3
    return rms_to(loop_seam(stereo(sub * 0.5) + air, L, F), -34)


# ======================================================================
# Footsteps (mono, short)
# ======================================================================

def _snow_step(r, heavy=1.0):
    s = 0.32 * heavy ** 0.3
    n = secs(s)
    heel = lambda u: np.exp(-((u - 0.18) / 0.12) ** 2)  # noqa: E731
    toe = lambda u: np.exp(-((u - 0.55) / 0.18) ** 2) * 0.8  # noqa: E731
    crunch = grains(r, s, 4200 * heavy, (0.2, 1.4), (500, 7500), lambda u: min(1.0, heel(u) + toe(u)))
    squeak = grains(r, s, 900, (1.5, 4.0), (1400, 3000), lambda u: toe(u))
    body = lp(white(r, n), 400) * env_ar(n, 0.02, 0.15) * 0.3 + thump(90, s, 0.05) * 0.35 * heavy
    return normalize(fade(crunch + squeak * 0.4 + body, 0.002, 0.04), -3)


def _wood_step(r):
    s = 0.3
    n = secs(s)
    knock = thump(r.uniform(95, 120), s, 0.05)
    board = sum(g * reso(white(r, n), f * r.uniform(0.95, 1.05), 12) for f, g in ((190, 1.0), (360, 0.6), (650, 0.35)))
    board *= env_exp(n, 0.06, 0.001)
    click = hp(white(r, n), 2500) * env_exp(n, 0.004, 0.0005) * 0.4
    x = knock * 0.6 + board * 1.2 + click
    if r.random() < 0.35:
        place(x, _creak(r, 0.25, low=True) * 0.25, 0.05)
    return normalize(fade(x, 0.001, 0.05), -3)


def _grass_step(r):
    s = 0.28
    n = secs(s)
    swish = bp(white(r, n), 1800, 7000) * env_ar(n, 0.03, 0.2) * 0.5
    blades = grains(r, s, 1400, (0.5, 2.0), (2500, 8000), lambda u: np.exp(-((u - 0.3) / 0.25) ** 2))
    soft = lp(white(r, n), 250) * env_ar(n, 0.01, 0.1) * 0.5
    return normalize(fade(swish + blades * 0.6 + soft, 0.002, 0.05), -6)


def _stone_step(r):
    s = 0.25
    n = secs(s)
    tap = hp(white(r, n), 1500) * env_exp(n, 0.008, 0.0003)
    body = sum(g * reso(white(r, n), f, 15) for f, g in ((420, 0.6), (1150, 0.5), (2600, 0.3))) * env_exp(n, 0.03)
    grit = grains(r, s, 500, (0.2, 0.8), (3000, 9000), lambda u: np.exp(-u * 6))
    return normalize(fade(tap * 0.8 + body * 1.5 + grit * 0.3 + thump(110, s, 0.03) * 0.3, 0.001, 0.04), -4)


def foot_jump():
    r = rng(210)
    n = secs(0.35)
    centre = np.linspace(700, 2600, n)
    whoosh = moving_bp(white(r, n), centre, q=2) * env_ar(n, 0.08, 0.25)
    cloth = grains(r, 0.35, 600, (2, 6), (1500, 5000), lambda u: 1 - u)
    return normalize(fade(whoosh + cloth * 0.3), -8)


def foot_land_snow():
    r = rng(211)
    x = _snow_step(r, 2.2)
    place(x, lp(white(r, secs(0.3)), 300) * env_exp(secs(0.3), 0.06) * 0.6, 0.0)
    return normalize(x, -2)


# ======================================================================
# Bow and arrows (mono)
# ======================================================================

def bow_draw():
    r = rng(301)
    s = 1.1
    n = secs(s)
    rate = np.linspace(25, 95, n) ** 1.0
    creak = stick_slip(r, s, rate, [(310, 10, 1.0), (880, 12, 0.6), (2100, 14, 0.25)], jitter=0.35)
    groan = bp(pink(r, n), 140, 320) * np.linspace(0.1, 0.5, n)
    rustle = grains(r, s, 500, (2, 6), (1800, 6000), lambda u: np.exp(-u * 5))
    x = creak * env_ar(n, 0.1, 0.25, s - 0.35) + groan * 0.4 + rustle * 0.25
    return normalize(fade(x, 0.01, 0.15), -6)


def bow_release():
    r = rng(302)
    s = 0.7
    n = secs(s)
    t = np.arange(n) / SR
    f = 118 * (1 + 0.05 * np.exp(-t / 0.02))
    twang = sum(np.sin(osc_phase(f * k)) / k ** 1.3 * np.exp(-t / (0.22 / k ** 0.5)) for k in range(1, 9))
    slap = hp(white(r, n), 1200) * env_exp(n, 0.006, 0.0002)
    x = twang * 0.7 + slap * 0.8 + thump(75, s, 0.04) * 0.6
    return normalize(fade(x, 0.0005, 0.1), -2)


def arrow_whoosh():
    r = rng(303)
    s = 0.45
    n = secs(s)
    centre = np.geomspace(2600, 700, n)
    x = moving_bp(white(r, n), centre, q=2.5) * env_ar(n, 0.04, 0.38)
    flutter = 1 + 0.35 * np.sin(2 * np.pi * 42 * np.arange(n) / SR)
    return normalize(fade(x * flutter), -6)


def arrow_hit_flesh():
    r = rng(304)
    s = 0.45
    n = secs(s)
    thud = thump(85, s, 0.07) * 0.9
    wet = lp(white(r, n), 520) * env_exp(n, 0.05, 0.001) * (1 + 0.6 * np.sin(2 * np.pi * 23 * np.arange(n) / SR))
    crack = bp(white(r, n), 1800, 5000) * env_exp(n, 0.006, 0.0003) * 0.35
    return normalize(fade(saturate(thud + wet * 1.2 + crack, 1.8), 0.0005, 0.08), -2)


def arrow_hit_wood():
    r = rng(305)
    s = 0.7
    n = secs(s)
    t = np.arange(n) / SR
    thock = sum(g * reso(white(r, n), f, 14) for f, g in ((780, 1.0), (1620, 0.6), (2650, 0.3))) * env_exp(n, 0.025, 0.0003)
    shaft = np.sin(2 * np.pi * 185 * t) * np.exp(-t / 0.22) * (0.5 + 0.5 * np.sin(2 * np.pi * 14 * t)) * 0.25
    return normalize(fade(thock * 2 + shaft + thump(140, s, 0.02) * 0.3, 0.0005, 0.1), -3)


def arrow_hit_snow():
    r = rng(306)
    s = 0.3
    n = secs(s)
    puff = lp(white(r, n), 900) * env_exp(n, 0.05, 0.001)
    crunch = grains(r, s, 2000, (0.2, 1.0), (700, 5000), lambda u: np.exp(-u * 8))
    return normalize(fade(puff + crunch * 0.5), -6)


def arrow_break():
    r = rng(307)
    s = 0.4
    n = secs(s)
    snap = hp(white(r, n), 2000) * env_exp(n, 0.004, 0.0002)
    body = reso(white(r, n), 1350, 8) * env_exp(n, 0.02) * 1.5
    splinters = grains(r, s, 1500, (0.3, 1.5), (2000, 8000), lambda u: np.exp(-u * 5))
    return normalize(fade(snap + body + splinters * 0.5, 0.0003, 0.08), -3)


# ======================================================================
# The great wolf (canon: silent until he takes the doe)
# ======================================================================

WOLF_OPEN = [(420, 5, 1.0), (1150, 6, 0.7), (2400, 7, 0.35), (3600, 8, 0.15)]
WOLF_CLOSED = [(300, 5, 1.0), (850, 6, 0.5), (2200, 8, 0.15)]


def _growl(r, s, f0=(78, 92), formants=WOLF_CLOSED, rough=0.9, sub=0.6):
    n = secs(s)
    f = np.linspace(*f0, n) * (1 + 0.1 * smooth_random(r, n, 2, -1, 1))
    g = voiced(r, f, formants, breath=0.2, rough=rough, sub=sub)
    flutter = 1 + 0.5 * smooth_random(r, n, 18, -1, 1)
    return saturate(g * flutter / (np.max(np.abs(g)) + 1e-9), 1.6)


def wolf_seize():
    """The forest's silence broken: a burst through snow, jaws, the doe falls."""
    r = rng(401)
    s = 2.4
    x = np.zeros(secs(s))
    place(x, _snow_step(r, 3.5) * 0.9, 0.0)
    place(x, moving_bp(white(r, secs(0.5)), np.geomspace(500, 2400, secs(0.5)), 2) * env_ar(secs(0.5), 0.05, 0.4) * 0.5, 0.0)
    snarl = _growl(r, 0.9, (140, 105), WOLF_OPEN, rough=1.2, sub=0.4) * env_ar(secs(0.9), 0.04, 0.5, 0.3)
    place(x, snarl * 0.9, 0.12)
    jaw = place(thump(95, 0.2, 0.04) * 0.8, hp(white(r, secs(0.08)), 1500) * env_exp(secs(0.08), 0.006), 0.0)
    place(x, jaw, 0.32)
    for k in range(5):  # the struggle
        place(x, lp(white(r, secs(0.18)), 900) * env_ar(secs(0.18), 0.02, 0.15) * r.uniform(0.3, 0.6), 0.5 + k * r.uniform(0.15, 0.28))
        place(x, _snow_step(r, 1.4) * 0.5, 0.55 + k * 0.24)
    place(x, thump(55, 0.6, 0.15) * 0.8, 1.6)  # the doe goes down
    ir = reverb_ir(r, 2.0, 0.3)
    return normalize(fade(reverb_mono(x, ir, 0.25), 0.0005, 0.2), -1)


def wolf_bark_pain():
    """Canon: 'he barked in pain' at the ash arrow."""
    r = rng(402)
    s = 0.55
    n = secs(s)
    t = np.arange(n) / SR
    f = 420 * np.exp(-t / 0.35) + 210
    bark = voiced(r, f, WOLF_OPEN, breath=0.35, rough=1.3, sub=0.3)
    bark = saturate(bark / (np.max(np.abs(bark)) + 1e-9), 2.5) * env_ar(n, 0.008, 0.35, 0.05)
    return normalize(fade(reverb_mono(bark, reverb_ir(r, 1.8, 0.3), 0.3), 0.0005, 0.05), -1)


def wolf_growl_low():
    """Canon: 'his low growl reverberated' as he turns to her."""
    r = rng(403)
    s = 3.2
    n = secs(s)
    g = _growl(r, s, (70, 64), WOLF_CLOSED, rough=1.0, sub=0.8) * env_ar(n, 0.6, 1.2, s - 1.8)
    return normalize(fade(reverb_mono(lp(g, 2500), reverb_ir(r, 2.2, 0.25), 0.35)), -3)


def wolf_death():
    """Canon: a low whine through the wind, a whimper, breath slowing, still."""
    r = rng(404)
    s = 10.0
    x = np.zeros(secs(s))
    n = secs(1.6)
    t = np.arange(n) / SR
    f = 640 - 120 * t / 1.6 + 25 * np.sin(2 * np.pi * 5.5 * t)
    whine = voiced(r, f, [(900, 6, 1.0), (2300, 7, 0.4)], breath=0.1, rough=0.4)
    place(x, whine * env_ar(n, 0.2, 0.9, 0.5) * 0.7, 0.0)
    m = secs(0.45)
    tt = np.arange(m) / SR
    whimper = voiced(r, 560 + 140 * np.exp(-tt / 0.1), [(800, 6, 1.0), (2000, 7, 0.4)], breath=0.2, rough=0.5)
    place(x, whimper * env_ar(m, 0.02, 0.35) * 0.5, 2.1)
    at, gap, vol = 3.0, 0.9, 0.5
    for k in range(6):  # the breaths, each longer apart and weaker
        b = secs(0.7)
        breath = bp(white(r, b), 300, 1800) * env_ar(b, 0.15, 0.5)
        place(x, breath * vol, at)
        at += gap
        gap *= 1.25
        vol *= 0.7
    ir = reverb_ir(r, 2.4, 0.25)
    return normalize(fade(reverb_mono(x, ir, 0.3), 0.01, 0.5), -3)


def wolf_pack_growl():
    r = rng(405)
    s = 2.4
    n = secs(s)
    g = _growl(r, s, (96, 88), WOLF_CLOSED, rough=0.8, sub=0.5) * env_ar(n, 0.3, 0.8, s - 1.1)
    return normalize(fade(lp(g, 3000)), -4)


def stinger_wrong():
    """Experience bar 1.5: after the world withdraws, 'a single wrong sound'.
    A bowed-metal scrape that bends out of tune."""
    r = rng(406)
    s = 3.5
    n = secs(s)
    t = np.arange(n) / SR
    f = 311 * (1 - 0.06 * t / s)
    bow = stick_slip(r, s, np.full(n, 311.0), [(311, 30, 1.0), (622 * 1.013, 30, 0.5), (1083, 25, 0.35), (1777, 25, 0.2)], jitter=0.08)
    bow *= env_ar(n, 0.5, 2.2, 0.6)
    drone = np.sin(osc_phase(f * 0.5)) * 0.15 * env_ar(n, 1.0, 2.0)
    x = reverb(bow + drone, reverb_ir(r, 3.5, 0.5), 0.6)
    return normalize(fade(x, 0.01, 0.6), -4)


# ======================================================================
# The beast at the cottage door
# ======================================================================

BEAST_OPEN = lambda t: [(380 + 260 * np.sin(min(t, 2.4) / 2.4 * np.pi), 4, 1.0),  # noqa: E731
                        (900 + 300 * np.sin(min(t, 2.4) / 2.4 * np.pi), 5, 0.7),
                        (2100, 6, 0.35), (3200, 7, 0.15)]


def beast_roar():
    """Canon: 'a roar that half deafened me'. Big, open, cottage-close."""
    r = rng(501)
    s = 3.2
    n = secs(s)
    t = np.arange(n) / SR
    f = 62 + 40 * np.sin(np.clip(t / 2.6, 0, 1) * np.pi) ** 0.7
    v = voiced(r, f, BEAST_OPEN, breath=0.45, rough=1.5, sub=1.0)
    v = saturate(v / (np.max(np.abs(v)) + 1e-9), 3.0)
    air = bp(white(r, n), 300, 3000) * 0.35
    body = v + air
    body *= env_ar(n, 0.08, 1.4, s - 1.6)
    x = body + thump(42, s, 0.6) * 0.5
    return normalize(fade(reverb(x, reverb_ir(r, 1.1, 0.35), 0.3), 0.002, 0.4), -1)


def _bellow(seed, vowels, s):
    """A bellowed word through a maw: vowel formants glide through `vowels`."""
    r = rng(seed)
    n = secs(s)
    t = np.arange(n) / SR
    pts = np.linspace(0, s, len(vowels))

    def fm(tt):
        i = min(int(np.searchsorted(pts, tt)), len(vowels) - 1)
        j = max(i - 1, 0)
        u = 0 if i == j else (tt - pts[j]) / (pts[i] - pts[j])
        a, b = vowels[j], vowels[i]
        return [(a[0] + (b[0] - a[0]) * u, 4, 1.0), (a[1] + (b[1] - a[1]) * u, 5, 0.7), (2400, 6, 0.3)]
    f = 88 + 30 * np.sin(np.clip(t / s, 0, 1) * np.pi)
    v = voiced(r, f, fm, breath=0.35, rough=1.3, sub=0.9)
    v = saturate(v / (np.max(np.abs(v)) + 1e-9), 3.0) * env_ar(n, 0.05, 0.6, s - 0.7)
    beats = (smooth_random(r, n, 4.5, 0.6, 1.0))  # the syllables
    x = v * beats + bp(white(r, n), 200, 2500) * 0.2 * env_ar(n, 0.05, 0.6, s - 0.7)
    return normalize(fade(reverb(x, reverb_ir(r, 0.9, 0.3), 0.3), 0.002, 0.3), -1)


def beast_bellow_murderers():
    """'MURDERERS!' bellowed, not spoken: mur-der-ers (voice lane may layer
    real words over it)."""
    return _bellow(502, [(500, 1300), (480, 1350), (650, 1200), (500, 1400), (600, 1250)], 1.9)


def beast_bellow_who():
    """'WHO KILLED HIM?' - the second bellow that shakes the cottage."""
    return _bellow(503, [(320, 800), (350, 900), (420, 2000), (450, 1900), (400, 1800)], 1.7)


def beast_door_smash():
    """The door gives (not in the text, [X]), and snow bursts into the room."""
    r = rng(504)
    s = 3.0
    x = np.zeros(secs(s))
    for k, at in enumerate((0.0, 0.03, 0.07, 0.12)):
        c = secs(0.12)
        crack = hp(white(r, c), 900) * env_exp(c, 0.012, 0.0002) + reso(white(r, c), r.uniform(300, 600), 5) * env_exp(c, 0.04)
        place(x, crack * (1.0 - k * 0.15), at)
    place(x, thump(52, 1.0, 0.25), 0.0)
    place(x, grains(r, 1.0, 2500, (0.5, 3.0), (800, 7000), lambda u: np.exp(-u * 4)) * 0.6, 0.02)
    for _ in range(9):  # pieces of door hitting the floor
        d = secs(0.12)
        piece = reso(white(r, d), r.uniform(250, 900), 10) * env_exp(d, 0.02) * 1.5
        place(x, piece * r.uniform(0.2, 0.6), r.uniform(0.25, 1.1))
    w = secs(2.6)  # "snow burst into the room", "blistering cold"
    rush = moving_bp(white(r, w), np.geomspace(400, 1600, w), 1.5) * env_ar(w, 0.1, 2.2)
    place(x, rush * 0.55, 0.05)
    return normalize(fade(reverb_mono(x, reverb_ir(r, 0.8, 0.4), 0.3), 0.0005, 0.3), -1)


def beast_snarl_loop():
    """Under everything while it fills the room: 'the snarling of a gigantic beast'."""
    r = rng(505)
    L, F = 6.0, 1.0
    n = secs(L + F)
    f = 58 + 6 * smooth_random(r, n, 0.8, -1, 1)
    g = voiced(r, f, [(280, 5, 1.0), (720, 6, 0.5), (1900, 8, 0.15)], breath=0.3, rough=1.4, sub=1.0)
    g = saturate(g / (np.max(np.abs(g)) + 1e-9), 2.0) * (0.6 + 0.4 * smooth_random(r, n, 0.6))
    return rms_to(loop_seam(stereo(lp(g, 2200)), L, F), -18)


def beast_claws():
    """Canon: claws 'thudded as they embedded in the wood, one by one', and the
    table 'groaned beneath him'."""
    r = rng(506)
    s = 3.0
    x = np.zeros(secs(s))
    for k in range(4):
        d = secs(0.25)
        hit = thump(130, 0.25, 0.04) * 0.7 + reso(white(r, d), r.uniform(500, 800), 9) * env_exp(d, 0.03) * 1.6
        hit += grains(r, 0.25, 1500, (0.3, 1.5), (1500, 7000), lambda u: np.exp(-u * 10)) * 0.5
        place(x, hit, 0.1 + k * r.uniform(0.32, 0.42))
    place(x, _creak(r, 1.5, low=True) * 0.7, 1.4)
    return normalize(fade(reverb_mono(x, reverb_ir(r, 0.7, 0.4), 0.25), 0.0005, 0.2), -2)


def cottage_rattle():
    """Canon: 'the entire cottage shake... plates and cups rattling'."""
    r = rng(507)
    s = 2.0
    n = secs(s)
    x = np.zeros(n)
    shake = 0.5 + 0.5 * np.sin(2 * np.pi * 11 * np.arange(n) / SR)
    for _ in range(140):
        at = r.uniform(0, s * 0.85)
        f = r.uniform(2200, 5200)
        clink = tone(f, 0.12, [(1, 1.0), (2.4, 0.4), (4.1, 0.2)], 0.03, 0.5) * r.uniform(0.2, 1.0)
        place(x, clink, at)
    x *= shake * env_ar(n, 0.05, 1.2, 0.6)
    rumble = lp(brown(r, n), 90) * env_ar(n, 0.05, 1.4, 0.4)
    return normalize(fade(x * 0.6 + rumble * 0.9, 0.002, 0.3), -3)


def heartbeat_loop():
    """Canon: her heartbeat 'pounding in my ears'. 130 bpm, in-ear muffled."""
    L = 60.0 / 130.0 * 4
    n = secs(L)
    x = np.zeros(n)
    for k in range(4):
        at = k * L / 4
        place(x, thump(58, 0.2, 0.05, 0.4), at)
        place(x, thump(50, 0.2, 0.06, 0.4) * 0.7, at + 0.13)
    return rms_to(stereo(lp(x, 160)), -16)



def beast_huff():
    r = rng(510)
    s = 1.4
    n = secs(s)
    breath = bp(white(r, n), 120, 1400) * env_ar(n, 0.06, 1.0)
    rumble = _growl(r, s, (54, 48), [(240, 4, 1.0), (650, 5, 0.4)], rough=0.6, sub=0.4) * env_ar(n, 0.05, 1.1) * 0.35
    return normalize(fade(breath + rumble, 0.002, 0.2), -4)


def ash_arrow_snap():
    r = rng(511)
    x = arrow_break() * 0.8
    place(x, hp(white(r, secs(0.05)), 3000) * env_exp(secs(0.05), 0.003) * 0.6, 0.004)
    return normalize(x, -2)


# ======================================================================
# UI (the princess side: glassy, sparkly, never harsh)
# ======================================================================

def _glitter(r, s, density=60, lo=4000, hi=9000):
    out = np.zeros(secs(s))
    for _ in range(int(density * s)):
        at = r.uniform(0, s * 0.85)
        place(out, tone(r.uniform(lo, hi), 0.08, [(1, 1)], 0.02, 0) * r.uniform(0.1, 0.5) * np.exp(-at / s * 2), at)
    return out


PENTA = [0, 2, 4, 7, 9, 12, 14, 16, 19, 21, 24]


def ui_hover():
    x = tone(2637, 0.09, [(1, 1.0), (2.01, 0.25)], 0.02, 0.3)
    return normalize(fade(x, 0.0005, 0.02), -14)


def ui_click():
    r = rng(602)
    x = place(bell(1568, 0.6, r) * 0.7, bell(2349, 0.4, r) * 0.25, 0.0)
    return normalize(fade(reverb(x, reverb_ir(r, 0.8, 0.8), 0.2).mean(axis=0)), -9)


def ui_open():
    r = rng(603)
    x = np.zeros(secs(1.0))
    for i, st in enumerate(PENTA[:6]):
        place(x, harp(midi(79 + st), 0.8, r) * (0.6 + i * 0.06), i * 0.045)
    x += _glitter(r, 1.0, 40) * 0.3
    return normalize(fade(reverb(x, reverb_ir(r, 1.2, 0.8), 0.25).mean(axis=0), 0.001, 0.2), -8)


def ui_close():
    r = rng(604)
    x = np.zeros(secs(0.8))
    for i, st in enumerate(reversed(PENTA[:4])):
        place(x, harp(midi(79 + st), 0.6, r) * 0.5, i * 0.05)
    return normalize(fade(reverb(x, reverb_ir(r, 1.0, 0.8), 0.2).mean(axis=0), 0.001, 0.2), -11)


def ui_deny():
    r = rng(605)
    x = reso(white(r, secs(0.2)), 300, 6) * env_exp(secs(0.2), 0.04) * 2 + thump(160, 0.2, 0.05) * 0.5
    return normalize(fade(x), -12)


def satchel_pickup():
    """res://audio/ui/satchel_pickup.ogg, picked up by SatchelSounds."""
    r = rng(606)
    x = np.zeros(secs(1.0))
    place(x, celesta(midi(88), 0.9, r), 0.0)
    place(x, celesta(midi(95), 0.9, r) * 0.7, 0.07)
    x += _glitter(r, 1.0, 70) * 0.35
    return normalize(fade(reverb(x, reverb_ir(r, 1.2, 0.9), 0.25).mean(axis=0), 0.001, 0.2), -7)


def ui_celebrate():
    """A deed or unlock lands (EventBus.celebration_requested): harp sweep,
    a bell chord, a shower of glitter."""
    r = rng(607)
    s = 2.6
    x = np.zeros(secs(s))
    for i, st in enumerate(PENTA[:9]):
        place(x, harp(midi(67 + st), 1.6, r) * 0.55, i * 0.05)
    for st in (0, 4, 7, 12):
        place(x, bell(midi(84 + st), 2.0, r) * 0.25, 0.45)
    x += _glitter(r, s, 90) * 0.4
    return normalize(fade(reverb(x, reverb_ir(r, 2.0, 0.9), 0.35), 0.001, 0.4), -5)


# ======================================================================
# Music (one cue per Act I space; stereo loops; none at the Spring arrival)
# ======================================================================

def _render_music(L, F, events, ir, wet, seed):
    x = np.zeros((2, secs(L + F)))
    for (at, sig, gain, pan) in events:
        place(x, sig, at, gain, pan)
    x = reverb(x, ir, wet)
    return loop_seam(x, L, F)


def mus_cottage():
    """Cold, tender, D minor: the family at the edge of starving."""
    r = rng(701)
    bpm = 66
    beat = 60 / bpm
    chords = [[50, 57, 62, 65], [46, 53, 58, 62], [41, 48, 53, 57], [45, 52, 57, 61],
              [50, 57, 62, 65], [43, 50, 55, 58], [46, 53, 58, 62], [45, 52, 57, 61]]
    melody = [(0, 74, 2), (2, 72, 1), (3, 69, 1), (4, 70, 3), (8, 69, 2), (10, 65, 2), (12, 64, 4),
              (16, 74, 2), (18, 77, 1), (19, 76, 1), (20, 74, 3), (24, 70, 2), (26, 69, 2), (28, 69, 4)]
    # Second pass: the tune drops an octave and thins out, then a high answer.
    melody += [(32 + b, m - 12, d) for (b, m, d) in melody[:7]]
    melody += [(48, 81, 3), (52, 79, 2), (54, 77, 2), (56, 76, 4), (60, 74, 4)]
    chords = chords * 2
    bars = len(chords)
    L = bars * 4 * beat
    ev = []
    for b, ch in enumerate(chords):
        t0 = b * 4 * beat
        ev.append((t0, pad([midi(m) for m in ch[:3]], 4 * beat + 2.5, 1.2, 2.0, 900, r), 0.5, 0.0))
        for k, m in enumerate([ch[0], ch[1], ch[2], ch[3], ch[2], ch[1]]):
            ev.append((t0 + k * beat * 0.66, piano(midi(m), 3.0, r), 0.18, -0.3 + 0.12 * k))
    for (bt, m, d) in melody:
        ev.append((bt * beat, piano(midi(m), d * beat + 2, r), 0.32, 0.15))
    x = _render_music(L, 4.0, ev, reverb_ir(r, 2.6, 0.4), 0.35, 701)
    return rms_to(x, -22)


def mus_winter_forest():
    """Hunger: mostly silence, a low drone, a few cold bell notes."""
    r = rng(702)
    L, F = 72.0, 5.0
    ev = [(0.0, pad([midi(38), midi(45)], L + F, 6.0, 6.0, 500, r), 0.7, 0.0),
          (L / 2, pad([midi(41), midi(48)], L / 2 + F, 8.0, 6.0, 450, r), 0.4, 0.0)]
    t = 4.0
    notes = [74, 77, 81, 76, 72, 69, 74, 79]
    i = 0
    while t < L - 4:
        ev.append((t, bell(midi(notes[i % len(notes)]), 4.0, r), 0.12, r.uniform(-0.7, 0.7)))
        i += 1
        t += r.uniform(5.0, 9.0)
    x = _render_music(L, F, ev, reverb_ir(r, 4.0, 0.3), 0.55, 702)
    return rms_to(x, -28)


def mus_village():
    """A small market in a poor town: A dorian, a plucked lute and a drone."""
    r = rng(703)
    bpm = 92
    beat = 60 / bpm
    prog = [[57, 64, 69], [55, 62, 67], [57, 64, 69], [52, 59, 64]] * 8
    L = len(prog) * 3 * beat
    ev = [(0.0, pad([midi(45), midi(52)], L + 4, 2.0, 2.0, 600, r), 0.35, 0.0)]
    tune = [69, 71, 72, 74, 72, 71, 69, 67, 69, 71, 69, 64, 66, 67, 69, 71]
    for b, ch in enumerate(prog):
        t0 = b * 3 * beat
        for k in range(3):
            ev.append((t0 + k * beat, harp(midi(ch[k] - 12 if k == 0 else ch[k]), 1.4, r), 0.25, -0.3))
        if b % 2 == 0:
            ev.append((t0, harp(midi(tune[b % len(tune)] + 12), 2.0, r), 0.3, 0.25))
            ev.append((t0 + 1.5 * beat, harp(midi(tune[(b + 1) % len(tune)] + 12), 1.6, r), 0.22, 0.25))
    x = _render_music(L, 3.0, ev, reverb_ir(r, 1.6, 0.5), 0.3, 703)
    return rms_to(x, -24)


def mus_spring_estate():
    """For the estate once the story allows music (not the arrival, which the
    book keeps silent): a harp waltz in E lydian, celesta, warm strings."""
    r = rng(704)
    bpm = 84
    beat = 60 / bpm
    prog = [[52, 59, 64, 68], [54, 61, 66, 70], [56, 63, 68, 71], [49, 56, 61, 64],
            [52, 59, 64, 68], [54, 61, 66, 70], [45, 52, 57, 61], [47, 54, 59, 63]] * 4
    L = len(prog) * 3 * beat
    ev = []
    mel = [76, 78, 80, 83, 82, 80, 78, 76, 75, 76, 78, 80, 81, 80, 78, 75]
    for b, ch in enumerate(prog):
        t0 = b * 3 * beat
        ev.append((t0, pad([midi(m) for m in ch], 3 * beat + 2.0, 0.8, 1.6, 1600, r), 0.45, 0.0))
        ev.append((t0, harp(midi(ch[0] - 12), 2.4, r), 0.35, -0.2))
        for k, m in enumerate(ch[1:] + [ch[1] + 12, ch[2] + 12, ch[3] + 12]):
            ev.append((t0 + beat * (0.5 + k * 0.42), harp(midi(m + 12), 1.8, r), 0.2, -0.4 + k * 0.15))
        ev.append((t0 + beat, celesta(midi(mel[b % len(mel)] + 12), 2.0, r), 0.22, 0.3))
        ev.append((t0 + 2 * beat, celesta(midi(mel[(b * 3 + 1) % len(mel)] + 12), 1.6, r), 0.16, 0.35))
    x = _render_music(L, 4.0, ev, reverb_ir(r, 3.2, 0.8), 0.45, 704)
    x += np.vstack([_glitter(r, x.shape[1] / SR, 6, 5000, 9000)] * 2) * 0.05
    return rms_to(x, -21)


# ======================================================================

SOUNDS = {
    "amb/winter_wood": (amb_winter_wood, 3, "Winter hunting forest: gusting wind, whistles, sifting snow, creaking trees, a distant crow"),
    "amb/cottage_yard": (amb_cottage_yard, 3, "Outside the cottage: lighter wind, boards creaking, a shutter knocking"),
    "amb/cottage_hearth": (amb_cottage_hearth, 3, "Inside the cottage: hearth fire crackle, the storm through thin walls"),
    "amb/village": (amb_village, 3, "The village: distant voices, a smith's anvil, carts, wind"),
    "amb/wall_seam": (amb_wall_seam, 3, "The Wall: wind thins out, low pressure hum, glassy shimmer"),
    "amb/spring_arrival": (amb_spring_arrival, 3, "Spring Court arrival: balmy breeze, leaves, sparse small birds, faint metal shimmer"),
    "amb/dread": (amb_dread, 2, "Dread bed: near silence and sub-bass pressure"),
    "sfx/foot/jump": (foot_jump, 4, "Jump: cloth whoosh"),
    "sfx/foot/land_snow": (foot_land_snow, 4, "Heavy landing in snow"),
    "sfx/bow/draw": (bow_draw, 4, "Bow draw: wood and string creak"),
    "sfx/bow/release": (bow_release, 4, "Bow release: string twang and slap"),
    "sfx/bow/whoosh": (arrow_whoosh, 4, "Arrow in flight"),
    "sfx/bow/hit_flesh": (arrow_hit_flesh, 4, "Arrow hits flesh"),
    "sfx/bow/hit_wood": (arrow_hit_wood, 4, "Arrow hits wood, shaft quivering"),
    "sfx/bow/hit_snow": (arrow_hit_snow, 4, "Arrow lands in snow"),
    "sfx/bow/break": (arrow_break, 4, "Arrow snaps"),
    "sfx/wolf/seize": (wolf_seize, 4, "The great wolf bursts from cover and seizes the doe"),
    "sfx/wolf/bark_pain": (wolf_bark_pain, 4, "The great wolf barks in pain (ash arrow)"),
    "sfx/wolf/growl_low": (wolf_growl_low, 4, "The great wolf's low reverberating growl"),
    "sfx/wolf/death": (wolf_death, 4, "The great wolf dies: whine, whimper, slowing breaths"),
    "sfx/wolf/pack_growl": (wolf_pack_growl, 4, "Ordinary wolf growl"),
    "sfx/horror/wrong": (stinger_wrong, 4, "Horror: the single wrong sound when the world withdraws"),
    "sfx/beast/roar": (beast_roar, 4, "The beast's roar at the door"),
    "sfx/beast/bellow_murderers": (beast_bellow_murderers, 4, "The beast bellows MURDERERS (wordless)"),
    "sfx/beast/bellow_who": (beast_bellow_who, 4, "The beast bellows WHO KILLED HIM (wordless)"),
    "sfx/beast/door_smash": (beast_door_smash, 4, "The cottage door breaks, snow rushes in"),
    "sfx/beast/snarl_loop": (beast_snarl_loop, 3, "The beast's continuous snarl (loop)"),
    "sfx/beast/claws": (beast_claws, 4, "Claws embed in the table one by one; the table groans"),
    "sfx/beast/cottage_rattle": (cottage_rattle, 4, "Plates and cups rattle as the cottage shakes"),
    "sfx/beast/heartbeat": (heartbeat_loop, 3, "Feyre's heartbeat pounding in her ears (loop)"),
    "sfx/beast/huff": (beast_huff, 4, "The beast's huffing breath"),
    "sfx/beast/snap_arrow": (ash_arrow_snap, 4, "The beast snaps the ash arrow"),
    "ui/hover": (ui_hover, 4, "UI hover: glass tick"),
    "ui/click": (ui_click, 4, "UI press: soft bell"),
    "ui/open": (ui_open, 4, "Menu open: harp rise and glitter"),
    "ui/close": (ui_close, 4, "Menu close: harp fall"),
    "ui/deny": (ui_deny, 4, "Not allowed: soft wooden tock"),
    "ui/satchel_pickup": (satchel_pickup, 4, "Satchel pickup: celesta pair and glitter"),
    "ui/celebrate": (ui_celebrate, 4, "Deed or unlock: harp sweep, bell chord, glitter shower"),
    "music/cottage": (mus_cottage, 3, "Music, cottage: D minor, piano and pad"),
    "music/winter_forest": (mus_winter_forest, 3, "Music, winter forest: drone and sparse cold bells"),
    "music/village": (mus_village, 3, "Music, village: A dorian lute and drone"),
    "music/spring_estate": (mus_spring_estate, 3, "Music, spring estate (from Act II): harp waltz in E lydian"),
}
for _kind, _fn, _n in (("snow", _snow_step, 5), ("wood", _wood_step, 4), ("grass", _grass_step, 4), ("stone", _stone_step, 4)):
    for _i in range(_n):
        SOUNDS["sfx/foot/%s_%d" % (_kind, _i + 1)] = (
            (lambda f=_fn, s=800 + _i * 7 + len(_kind): f(rng(s))), 4, "Footstep on %s, variant %d" % (_kind, _i + 1))
for _i in range(3):
    SOUNDS["sfx/beast/footfall_%d" % (_i + 1)] = ((lambda s=509 + _i * 13: _beast_footfall_seeded(s)), 4, "The beast's heavy footfall, variant %d" % (_i + 1))


def _beast_footfall_seeded(seed):
    r = rng(seed)
    x = thump(48 * r.uniform(0.9, 1.1), 0.6, 0.12) * 0.9
    place(x, _snow_step(r, 2.5) * 0.5, 0.0)
    return normalize(fade(x), -2)



# ======================================================================
# The sound bank (data/audio/act1_sound_bank.tres) read by SoundDirector
# ======================================================================

BANK = ROOT / "data" / "audio" / "act1_sound_bank.tres"
# cue id: (files, volume_db, pitch_jitter, loop, music, max_distance)
CUES = {
    "amb_winter_wood": (["amb/winter_wood"], -4, 0, True, False, 0),
    "amb_cottage_yard": (["amb/cottage_yard"], -4, 0, True, False, 0),
    "amb_cottage_hearth": (["amb/cottage_hearth"], -2, 0, True, False, 0),
    "amb_village": (["amb/village"], -4, 0, True, False, 0),
    "amb_wall_seam": (["amb/wall_seam"], -2, 0, True, False, 0),
    "amb_spring_arrival": (["amb/spring_arrival"], 0, 0, True, False, 0),
    "amb_dread": (["amb/dread"], 0, 0, True, False, 0),
    "foot_snow": (["sfx/foot/snow_%d" % i for i in range(1, 6)], -8, 0.08, False, False, 30),
    "foot_wood": (["sfx/foot/wood_%d" % i for i in range(1, 5)], -8, 0.06, False, False, 30),
    "foot_grass": (["sfx/foot/grass_%d" % i for i in range(1, 5)], -8, 0.08, False, False, 30),
    "foot_stone": (["sfx/foot/stone_%d" % i for i in range(1, 5)], -8, 0.06, False, False, 30),
    "foot_jump": (["sfx/foot/jump"], -10, 0.08, False, False, 30),
    "foot_land_snow": (["sfx/foot/land_snow"], -4, 0.05, False, False, 30),
    "bow_draw": (["sfx/bow/draw"], -6, 0, False, False, 40),
    "bow_release": (["sfx/bow/release"], -2, 0.04, False, False, 60),
    "bow_whoosh": (["sfx/bow/whoosh"], -6, 0.08, False, False, 40),
    "bow_hit_flesh": (["sfx/bow/hit_flesh"], -2, 0.06, False, False, 80),
    "bow_hit_wood": (["sfx/bow/hit_wood"], -2, 0.08, False, False, 80),
    "bow_hit_snow": (["sfx/bow/hit_snow"], -4, 0.1, False, False, 50),
    "bow_break": (["sfx/bow/break"], -4, 0.08, False, False, 50),
    "wolf_seize": (["sfx/wolf/seize"], 0, 0, False, False, 120),
    "wolf_bark_pain": (["sfx/wolf/bark_pain"], 0, 0.04, False, False, 120),
    "wolf_growl_low": (["sfx/wolf/growl_low"], 0, 0, False, False, 80),
    "wolf_death": (["sfx/wolf/death"], -2, 0, False, False, 60),
    "wolf_pack_growl": (["sfx/wolf/pack_growl"], -2, 0.1, False, False, 60),
    "horror_wrong": (["sfx/horror/wrong"], -6, 0.05, False, False, 0),
    "beast_roar": (["sfx/beast/roar"], 2, 0, False, False, 150),
    "beast_bellow_murderers": (["sfx/beast/bellow_murderers"], 2, 0, False, False, 150),
    "beast_bellow_who": (["sfx/beast/bellow_who"], 2, 0, False, False, 150),
    "beast_door_smash": (["sfx/beast/door_smash"], 0, 0, False, False, 120),
    "beast_snarl": (["sfx/beast/snarl_loop"], -4, 0, True, False, 60),
    "beast_claws": (["sfx/beast/claws"], 0, 0, False, False, 60),
    "beast_cottage_rattle": (["sfx/beast/cottage_rattle"], -2, 0, False, False, 0),
    "beast_heartbeat": (["sfx/beast/heartbeat"], -4, 0, True, False, 0),
    "beast_footfall": (["sfx/beast/footfall_%d" % i for i in range(1, 4)], -2, 0.05, False, False, 100),
    "beast_huff": (["sfx/beast/huff"], -4, 0.05, False, False, 60),
    "beast_snap_arrow": (["sfx/beast/snap_arrow"], -2, 0, False, False, 40),
    "ui_hover": (["ui/hover"], -6, 0.03, False, False, 0),
    "ui_click": (["ui/click"], -4, 0.02, False, False, 0),
    "ui_open": (["ui/open"], -4, 0, False, False, 0),
    "ui_close": (["ui/close"], -4, 0, False, False, 0),
    "ui_deny": (["ui/deny"], -6, 0, False, False, 0),
    "ui_pickup": (["ui/satchel_pickup"], -4, 0.03, False, False, 0),
    "ui_celebrate": (["ui/celebrate"], -3, 0, False, False, 0),
    "music_cottage": (["music/cottage"], -6, 0, True, True, 0),
    "music_winter_forest": (["music/winter_forest"], -4, 0, True, True, 0),
    "music_village": (["music/village"], -6, 0, True, True, 0),
    "music_spring_estate": (["music/spring_estate"], -6, 0, True, True, 0),
}
SPRING = ["border_woods", "manor_estate", "eastern_woods", "suriel_glade", "blossom_vale", "rosewild",
          "solstice_meadow", "starlight_glen", "western_fells", "autumn_foothills", "hill_of_the_rite",
          "fae_village", "blighted_reaches"]
SPACE_BEDS = {"cottage": "amb_cottage_yard", "cottage_interior": "amb_cottage_hearth",
              "hunting_forest": "amb_winter_wood", "workshop": "amb_winter_wood",
              "village": "amb_village", "wall_seam": "amb_wall_seam"}
SPACE_BEDS.update({k: "amb_spring_arrival" for k in SPRING})
# None at the wall or past it: the book keeps the Spring Court arrival silent.
SPACE_MUSIC = {"cottage": "music_cottage", "cottage_interior": "music_cottage",
               "hunting_forest": "music_winter_forest", "workshop": "music_winter_forest",
               "village": "music_village"}
SPACE_SURFACES = {"cottage_interior": "wood"}
SPACE_SURFACES.update({k: "grass" for k in SPRING})


def _gd_dict(d):
    return "{\n" + ",\n".join('&"%s": &"%s"' % (k, v) for k, v in sorted(d.items())) + "\n}"


def write_bank():
    files = sorted({f for c in CUES.values() for f in c[0]})
    ext = {f: "a%d" % i for i, f in enumerate(files)}
    out = ['[gd_resource type="Resource" script_class="SoundBank" load_steps=%d format=3]' % (len(files) + len(CUES) + 3), "",
           '[ext_resource type="Script" path="res://systems/audio/sound_bank.gd" id="1"]',
           '[ext_resource type="Script" path="res://systems/audio/sound_cue.gd" id="2"]']
    out += ['[ext_resource type="AudioStream" path="res://audio/%s.ogg" id="%s"]' % (f, ext[f]) for f in files]
    for i, (cid, (fs, vol, jit, loop, music, dist)) in enumerate(sorted(CUES.items())):
        out += ["", '[sub_resource type="Resource" id="c%d"]' % i, 'script = ExtResource("2")', 'id = &"%s"' % cid,
                "streams = Array[AudioStream]([%s])" % ", ".join('ExtResource("%s")' % ext[f] for f in fs),
                "volume_db = %.1f" % vol, "pitch_jitter = %.2f" % jit, "loop = %s" % str(loop).lower(),
                "music = %s" % str(music).lower(), "max_distance = %.1f" % (dist or 40)]
    out += ["", "[resource]", 'script = ExtResource("1")',
            'cues = Array[ExtResource("2")]([%s])' % ", ".join('SubResource("c%d")' % i for i in range(len(CUES))),
            "space_beds = " + _gd_dict(SPACE_BEDS), "space_music = " + _gd_dict(SPACE_MUSIC),
            "space_surfaces = " + _gd_dict(SPACE_SURFACES)]
    BANK.parent.mkdir(parents=True, exist_ok=True)
    BANK.write_text("\n".join(out) + "\n")


def write_credits():
    lines = ["# Audio credits and licences", "",
             "Every file in this folder is self-made: synthesised from seeded noise and sine",
             "partials by `%s` (no recordings, samples or downloads)." % GEN,
             "Licence: CC0 1.0 (public domain dedication). Rebuild any file with",
             "`python3 %s <name>`." % GEN, "",
             "| File | What it is | Source | Licence |", "|---|---|---|---|"]
    for name in sorted(SOUNDS):
        lines.append("| audio/%s.ogg | %s | self-made, `%s` | CC0 |" % (name, SOUNDS[name][2], GEN))
    (OUT / "CREDITS.md").write_text("\n".join(lines) + "\n")


def main(argv):
    only = argv[1] if len(argv) > 1 else ""
    for cid, spec in CUES.items():
        for f in spec[0]:
            assert f in SOUNDS, "%s names a file nobody makes: %s" % (cid, f)
    for name, (fn, q, _desc) in SOUNDS.items():
        if only and only not in name:
            continue
        x = fn()
        assert np.all(np.isfinite(x)), name
        write_ogg(OUT / (name + ".ogg"), x, q)
        print("%-34s %5.1f s  %4d KB" % (name, x.shape[-1] / SR, (OUT / (name + ".ogg")).stat().st_size // 1024))
    write_credits()
    write_bank()


if __name__ == "__main__":
    main(sys.argv)
