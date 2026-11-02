"""The opening film's score ("Once", L33): one continuous cue, 3:05, merged
into gen_act1_audio.py's SOUNDS and CUES. Self-made, CC0.

Sections (seconds), from plans/film/scripts.md and the cinematic lane:
  0 lullaby hum | 20 harp and celesta | 33 horror drone | 42 work drum |
  54 war drums and choir | 68 bell, slow lullaby | 78 glass shimmer (the Wall) |
  105 hearth cello | 172 silence, then a sub sting at 175.5 | 176 title swell.
"""
import numpy as np

from dsp import (SR, bell, bp, celesta, env_ar, env_exp, fade, harp, hp, lp, midi, pad,
                 piano, place, reverb, reverb_ir, rng, rms_to, saturate, secs,
                 smooth_random, thump, voiced, white, osc_phase)

LENGTH = 185.0
SECTIONS = [0.0, 20.0, 33.0, 42.0, 54.0, 68.0, 78.0, 105.0, 172.0, 176.0]

# The lullaby: a simple rocking tune in D major (beats of 0.75 s).
LULLABY = [(74, 2), (71, 1), (69, 2), (71, 1), (74, 2), (76, 1), (74, 3),
           (71, 2), (69, 1), (67, 2), (69, 1), (71, 2), (69, 1), (66, 3)]


def _hum(f, s, r):
    """A lone voice humming 'mm': soft harmonics through a closed-mouth formant."""
    n = secs(s)
    t = np.arange(n) / SR
    vib = 1 + 0.006 * np.sin(2 * np.pi * 5.2 * t) * np.clip(t / 0.4, 0, 1)
    v = voiced(r, np.full(n, f) * vib, [(280, 3, 1.0), (2400, 6, 0.08)], breath=0.03, rough=0.05)
    return lp(v, 2500) * env_ar(n, 0.12, 0.35, max(s - 0.47, 0))


def _melody(voice_fn, start, beat, gain, notes, ev, transpose=0, pan=0.1):
    t = start
    for m, d in notes:
        ev.append((t, voice_fn(midi(m + transpose), d * beat + 0.4), gain, pan))
        t += d * beat
    return t


def _cello(f, s, r):
    """A bowed cello line: rich harmonics, slow bow attack, vibrato."""
    n = secs(s)
    t = np.arange(n) / SR
    vib = 1 + 0.008 * np.sin(2 * np.pi * 5.0 * t) * np.clip((t - 0.3) / 0.5, 0, 1)
    ph = osc_phase(np.full(n, f) * vib)
    x = sum(np.sin(ph * k) / k ** 1.1 for k in range(1, 14))
    x = bp(x, 70, 2200) + 0.04 * bp(white(r, n), 1500, 4000)
    return x * env_ar(n, 0.35, 0.6, max(s - 0.95, 0))


def _choir(freqs, s, r):
    out = np.zeros(secs(s))
    for f in freqs:
        n = secs(s)
        v = voiced(r, np.full(n, f) * (1 + 0.005 * smooth_random(r, n, 4, -1, 1)),
                   [(750, 4, 1.0), (1150, 5, 0.6), (2600, 7, 0.2)], breath=0.08, rough=0.1)
        out += v / (np.max(np.abs(v)) + 1e-9)
    return out * env_ar(secs(s), 1.0, 2.0, max(s - 3.0, 0)) / len(freqs)


def _drum(r, f=60, decay=0.25, slap=0.3):
    s = 0.9
    x = thump(f, s, decay, 0.5)
    x += lp(white(r, secs(s)), 900) * env_exp(secs(s), 0.03, 0.001) * slap
    return x


def opening_film():
    r = rng(1001)
    ev = []
    beat = 0.75
    # 0:00 lullaby hum, one lone voice, a breath of pad under it.
    ev.append((0.0, pad([midi(50), midi(57)], 21.0, 4.0, 3.0, 500, r), 0.35, 0.0))
    _melody(lambda f, s: _hum(f, s, r), 0.8, beat, 0.5, LULLABY, ev, -12)
    # 0:20 harp and celesta: the faeries' beauty (E lydian, glitter).
    ev.append((20.0, pad([midi(m) for m in (52, 59, 64, 68, 70)], 14.0, 1.5, 2.5, 1800, r), 0.45, 0.0))
    t = 20.0
    for k in range(24):
        ev.append((t, harp(midi([64, 68, 71, 75, 78, 76][k % 6] + (12 if k >= 12 else 0)), 2.0, r), 0.24, -0.3 + (k % 6) * 0.12))
        t += 0.25
    _melody(lambda f, s: celesta(f, s + 0.6, r), 21.0, 0.5, 0.3, [(88, 2), (90, 1), (92, 3), (95, 2), (92, 2), (90, 4), (88, 4)], ev, 0, 0.3)
    # 0:33 horror drone: the beauty cut off; sub and a dissonant cluster.
    for f, g in ((36.7, 0.9), (73.4, 0.3), (77.8, 0.25), (110.0 * 1.06, 0.15)):
        n = secs(10.0)
        tt = np.arange(n) / SR
        ev.append((33.0, np.sin(2 * np.pi * f * tt) * env_ar(n, 0.8, 2.0, 7.0), g, 0.0))
    ev.append((33.0, bp(white(r, secs(9.0)), 300, 1200) * env_ar(secs(9.0), 2.0, 2.0, 5.0), 0.05, 0.0))
    # 0:42 work drum: slaves at labour, a steady low beat and a dull ostinato.
    t = 42.0
    while t < 54.0:
        ev.append((t, _drum(r, 58, 0.22, 0.25), 0.55, -0.1))
        ev.append((t + 0.9, _drum(r, 64, 0.15, 0.15), 0.3, 0.1))
        t += 1.5
    ev.append((42.0, pad([midi(38), midi(45), midi(50)], 12.5, 1.0, 1.5, 450, r), 0.5, 0.0))
    # 0:54 the War: big drums and a choir in D minor.
    t = 54.0
    k = 0
    while t < 68.0:
        ev.append((t, _drum(r, 48, 0.4, 0.6), 0.9, -0.4 + 0.8 * (k % 2)))
        if k % 4 == 3:
            ev.append((t + 0.3, _drum(r, 55, 0.3, 0.5), 0.6, 0.0))
        t += 0.75 if k % 8 < 6 else 0.375
        k += 1
    for i, ch in enumerate(([50, 57, 62, 65], [46, 53, 58, 62], [48, 55, 60, 64], [45, 52, 57, 61])):
        ev.append((54.0 + i * 3.5, _choir([midi(m) for m in ch], 4.5, r), 0.5, 0.0))
    # 1:08 one bell, then the lullaby slow on piano.
    ev.append((68.0, bell(midi(50), 6.0, r), 0.5, 0.0))
    _melody(lambda f, s: piano(f, s + 1.0, r), 69.5, 0.62, 0.3, LULLABY[:7], ev, 0, 0.1)
    # 1:18 glass shimmer: the Wall. Beating high partials, sparse glass notes.
    n = secs(27.0)
    tt = np.arange(n) / SR
    glass = sum(np.sin(2 * np.pi * f * tt) * smooth_random(r, n, 0.2, 0, 1) ** 2 for f in (1760, 1763.5, 2637, 2641, 3520))
    ev.append((78.0, glass * env_ar(n, 3.0, 4.0, 20.0) * 0.05, 1.0, 0.0))
    t = 80.0
    while t < 103.0:
        ev.append((t, bell(midi(int(r.choice([86, 88, 93, 95, 98]))), 3.5, r), 0.12, float(r.uniform(-0.6, 0.6))))
        t += float(r.uniform(2.5, 4.5))
    ev.append((78.0, pad([midi(62), midi(69)], 27.0, 4.0, 4.0, 700, r), 0.25, 0.0))
    # 1:45 the hearth: a warm cello line, near silence, a few crackles.
    cello_line = [(50, 4), (57, 2), (55, 2), (54, 4), (52, 4), (50, 3), (49, 1), (50, 4),
                  (55, 4), (57, 2), (59, 2), (57, 4), (55, 2), (54, 2), (52, 4), (50, 8)]
    t = 106.0
    for rep in range(2):
        for m, d in cello_line:
            ev.append((t, _cello(midi(m), d * 0.9 + 0.5, r), 0.32, -0.15))
            t += d * 0.9
        if t > 168:
            break
    for i, ch in enumerate([[38, 45, 50], [43, 50, 55], [38, 45, 50], [45, 52, 57]] * 4):
        if 105.0 + i * 4.2 < 170:
            ev.append((105.0 + i * 4.2, pad([midi(m) for m in ch], 5.5, 1.5, 2.0, 600, r), 0.28, 0.0))
    for _ in range(40):
        at = float(r.uniform(105.0, 170.0))
        g = secs(float(r.uniform(0.003, 0.02)))
        ev.append((at, hp(white(r, g), 1500) * env_exp(g, 0.004, 0.0003), 0.08, float(r.uniform(-0.5, 0.5))))
    # 2:52 silence; 2:55.5 the wolf's sub sting; 2:56 the title swell.
    ev.append((175.5, saturate(thump(34, 3.0, 1.2, 0.3) * 1.5, 1.5), 0.9, 0.0))
    swell = [midi(m) for m in (50, 57, 62, 66, 69, 74)]
    ev.append((176.0, pad(swell, 9.0, 5.0, 1.0, 2400, r), 0.8, 0.0))
    for k in range(16):
        ev.append((177.0 + k * 0.3, harp(midi([62, 66, 69, 74][k % 4] + (12 if k >= 8 else 0)), 2.5, r), 0.22, -0.4 + (k % 4) * 0.25))
    for f in (74, 81, 86):
        ev.append((181.5, bell(midi(f), 3.5, r), 0.18, 0.0))

    x = np.zeros((2, secs(LENGTH)))
    for at, sig, gain, pan in ev:
        place(x, sig, at, gain, pan)
    x = reverb(x, reverb_ir(r, 3.0, 0.6), 0.4)
    # The silence at 2:52 is real silence before the sting.
    gate = np.ones(x.shape[1])
    a, b = secs(171.0), secs(172.5)
    gate[a:b] = np.linspace(1, 0, b - a)
    gate[b:secs(175.4)] = 0.0
    x *= gate
    end = secs(LENGTH - 1.5)
    x[:, end:] *= np.linspace(1, 0, x.shape[1] - end)
    return rms_to(x, -20)


SOUNDS = {"music/opening_film": (opening_film, 3, "Opening film score 'Once' (3:05): lullaby, beauty, war, the Wall, hearth, title swell")}
CUES = {"music_opening_film": (["music/opening_film"], -2, 0, False, True, 0)}
