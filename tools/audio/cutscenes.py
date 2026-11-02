"""Scores for L33's three cutscenes, one continuous cue each, timed to
plans/film/cutscene_cues.md. Merged into gen_act1_audio.py's SOUNDS and CUES.
Self-made, CC0. B and C are horror: cold, never pretty (R3).
"""
import numpy as np

from dsp import (SR, bell, bp, celesta, env_ar, env_exp, harp, hp, lp, midi, moving_bp,
                 pad, piano, pink, place, reso, reverb, reverb_ir, rng, rms_to, saturate,
                 secs, smooth_random, thump, voiced, white, osc_phase, brown, stereo)
from film import LULLABY, _cello, _choir, _hum
from horrors import _whisper


def _render(length, ev, ir, wet):
    x = np.zeros((2, secs(length)))
    for at, sig, gain, pan in ev:
        place(x, sig, at, gain, pan)
    return reverb(x, ir, wet)


def _gate(x, spans):
    """Multiply the mix by 0 over (start, end) spans, with 80 ms edges."""
    g = np.ones(x.shape[1])
    e = secs(0.08)
    for a, b in spans:
        ia, ib = secs(a), secs(b)
        g[ia:ib] = 0.0
        g[max(ia - e, 0):ia] *= np.linspace(1, 0, ia - max(ia - e, 0))
        g[ib:ib + e] *= np.linspace(0, 1, len(g[ib:ib + e]))
    return x * g


def _bird(r):
    out = np.zeros(secs(1.6))
    at = 0.0
    base = r.uniform(2600, 4600)
    for _ in range(r.integers(3, 8)):
        d = r.uniform(0.04, 0.12)
        n = secs(d)
        f = np.linspace(base * r.uniform(0.85, 1.2), base * r.uniform(0.6, 1.5), n) + 200 * np.sin(np.linspace(0, r.uniform(6, 30), n))
        place(out, np.sin(osc_phase(f)) * np.hanning(n) * r.uniform(0.5, 1.0), at)
        at += d + r.uniform(0.02, 0.09)
    return out


def _brook(r, s):
    n = secs(s)
    x = bp(white(r, n), 400, 3500) * (0.5 + 0.5 * smooth_random(r, n, 3))
    for _ in range(int(s * 6)):
        d = secs(0.05)
        f = np.geomspace(r.uniform(600, 1400), r.uniform(1600, 2600), d)
        place(x, np.sin(osc_phase(f)) * np.hanning(d) * 0.3, r.uniform(0, s - 0.1))
    return x


def _hum_low(r, s, base=110.0):
    n = secs(s)
    t = np.arange(n) / SR
    return (np.sin(2 * np.pi * base * t) + 0.5 * np.sin(2 * np.pi * base * 1.007 * t)
            + 0.35 * np.sin(2 * np.pi * base * 1.5 * 1.012 * t)) * (0.7 + 0.3 * smooth_random(r, n, 0.3))


# ---------------------------------------------------------------- A, Eyes Open

def film_eyes_open():
    r = rng(1101)
    L = 76.0
    ev = []
    # 0-42.5: the veiled glen: a few birds, a brook, one harp line, muffled.
    ev.append((0.0, lp(_brook(r, 43.0), 1800) * env_ar(secs(43.0), 1.0, 1.0, 41.0), 0.12, 0.3))
    t = 1.0
    while t < 40:
        ev.append((t, lp(_bird(r), 3000), 0.05, float(r.uniform(-0.7, 0.7))))
        t += float(r.uniform(4, 8))
    line = [(76, 2), (74, 1), (71, 3), (69, 2), (71, 2), (74, 4)]
    tt = 1.5
    for m, d in line:
        ev.append((tt, lp(harp(midi(m), 2.4, r), 2200), 0.22, -0.2))
        tt += d * 0.7
    # 9.5: he offers to open her senses: a little warmth.
    ev.append((9.5, pad([midi(m) for m in (52, 59, 64, 68)], 23.0, 3.0, 2.5, 1100, r), 0.25, 0.0))
    t = 10.0
    k = 0
    while t < 31.0:
        ev.append((t, harp(midi([64, 68, 71, 73, 71, 68][k % 6]), 2.0, r), 0.16, -0.3 + (k % 6) * 0.1))
        t += 0.7
        k += 1
    # 32-42.5: one long held note, almost gone by the kisses.
    n = secs(11.0)
    ev.append((32.0, pad([midi(76)], 11.0, 1.0, 4.0, 2000, r) * np.linspace(1.0, 0.25, n), 0.4, 0.0))
    # 42.5: sound opens first: an orchestra of birds, the willow singing, a choir.
    for _ in range(70):
        ev.append((float(r.uniform(42.5, 68.0)), _bird(r), float(r.uniform(0.05, 0.12)), float(r.uniform(-0.9, 0.9))))
    willow = [(64, 3), (62, 2), (59, 3), (57, 4)]
    tt = 43.0
    for m, d in willow:
        n = secs(d * 0.9 + 0.6)
        v = voiced(r, np.full(n, midi(m - 12)) * (1 + 0.007 * np.sin(2 * np.pi * 4.6 * np.arange(n) / SR)),
                   [(650, 4, 1.0), (1100, 5, 0.5), (2800, 7, 0.15)], breath=0.08, rough=0.15)
        ev.append((tt, v / (np.max(np.abs(v)) + 1e-9) * env_ar(n, 0.3, 0.5, max(n / SR - 0.8, 0)), 0.18, 0.4))
        tt += d * 0.9
    ev.append((42.5, _choir([midi(m) for m in (52, 59, 64, 68)], 12.0, r) * np.linspace(0.2, 1.0, secs(12.0)), 0.35, 0.0))
    # 47: eyes open: celesta and strings, full and bright; 54: a warm swell.
    ev.append((47.0, pad([midi(m) for m in (52, 59, 64, 68, 71)], 12.0, 1.2, 2.5, 2600, r), 0.5, 0.0))
    mel = [(88, 1), (90, 1), (92, 2), (95, 2), (92, 1), (90, 1), (88, 2), (87, 2), (88, 4)]
    tt = 47.3
    for m, d in mel:
        ev.append((tt, celesta(midi(m), d * 0.6 + 1.0, r), 0.25, 0.25))
        tt += d * 0.6
    ev.append((54.0, pad([midi(m) for m in (45, 52, 57, 61, 64)], 5.0, 1.5, 1.5, 2200, r), 0.55, 0.0))
    # 58.5: the music catches on a suspended chord; 61.5 it resolves softly.
    ev.append((58.5, pad([midi(m) for m in (52, 57, 59, 64)], 3.2, 0.2, 0.8, 1800, r), 0.45, 0.0))
    ev.append((61.5, pad([midi(m) for m in (52, 56, 59, 64)], 7.0, 0.8, 3.0, 1600, r), 0.4, 0.0))
    # 68-76: the new, brighter glen: birds and brook, no veil, fading out.
    ev.append((61.0, _brook(r, 15.0) * env_ar(secs(15.0), 2.0, 5.0, 8.0), 0.12, 0.3))
    x = _render(L, ev, reverb_ir(r, 2.4, 0.8), 0.35)
    end = secs(L - 6.0)
    x[:, end:] *= np.linspace(1, 0, x.shape[1] - end) ** 1.5
    return rms_to(x, -21)


# ---------------------------------------------------------------- B, Night Court

def _footstep_marble(r):
    d = secs(1.4)
    tap = hp(white(r, d), 1200) * env_exp(d, 0.006, 0.0003)
    body = sum(g * reso(white(r, d), f, 18) for f, g in ((340, 0.6), (980, 0.5), (2300, 0.3))) * env_exp(d, 0.05)
    return tap + body * 1.5


def film_night_court():
    r = rng(1201)
    L = 105.0
    ev = []
    # 0-3.5: lunch: cutlery, birds, a light court air.
    for _ in range(14):
        f = float(r.uniform(2400, 5200))
        ev.append((float(r.uniform(0.0, 3.3)), bell(f, 0.3, r), 0.03, float(r.uniform(-0.6, 0.6))))
    ev.append((0.0, _bird(r), 0.05, -0.5))
    ev.append((1.2, _bird(r), 0.05, 0.6))
    for i, m in enumerate((76, 79, 83, 81)):
        ev.append((0.1 + i * 0.6, harp(midi(m), 1.8, r), 0.16, 0.1))
    # 8-12: the glamour: a faint metallic tang.
    n = secs(4.0)
    tt = np.arange(n) / SR
    tang = (np.sin(2 * np.pi * 6272 * tt) + np.sin(2 * np.pi * 6290 * tt)) * env_ar(n, 0.6, 1.8, 1.6)
    ev.append((8.0, tang, 0.02, 0.0))
    # 12-17: footsteps across marble, ringing, slow, closer.
    for i, at in enumerate(np.arange(12.0, 17.0, 0.95)):
        ev.append((float(at), _footstep_marble(r), 0.5 + 0.15 * i, 0.3 - 0.06 * i))
    # 17-48: a deep cold hum, rising slowly; it swells at 40.
    n = secs(36.0)
    hum = _hum_low(r, 36.0, 55.0) * np.linspace(0.15, 1.0, n) ** 1.5
    hum[secs(23.0):] *= np.linspace(1.0, 1.6, n - secs(23.0))
    ev.append((17.0, lp(hum, 400) * env_ar(n, 2.0, 1.0, 33.0), 0.5, 0.0))
    ev.append((17.0, bp(white(r, n), 60, 300) * np.linspace(0.0, 0.4, n), 0.4, 0.0))
    # 44.5: a heartbeat.
    for k in range(10):
        at = 44.5 + k * 0.46
        ev.append((at, thump(58, 0.25, 0.05, 0.4), 0.55, 0.0))
        ev.append((at + 0.13, thump(50, 0.25, 0.06, 0.4), 0.4, 0.0))
    # 48-53: he is in her mind: whispers circling, short breaths, a crushing sub.
    n = secs(5.5)
    t5 = np.arange(n) / SR
    for k in range(5):
        w = _whisper(r, 5.5, float(r.uniform(0.6, 1.1)), float(r.uniform(5, 8)))
        pan = np.sin(2 * np.pi * (k / 5 + t5 / 2.0))
        ev.append((48.0, np.vstack([w * (1 - pan), w * (1 + pan)]) * 0.5, 0.6, 0.0))
    for k in range(8):
        d = secs(0.22)
        ev.append((48.2 + k * 0.6, bp(white(r, d), 400, 2200) * env_ar(d, 0.04, 0.16), 0.25, 0.0))
    ev.append((48.0, saturate(np.sin(osc_phase(np.geomspace(38, 26, n))) * env_ar(n, 0.3, 2.0, 3.2), 1.8), 0.9, 0.0))
    # 53-67: the hum lower, the sub ebbing.
    n = secs(14.5)
    ev.append((53.0, lp(_hum_low(r, 14.5, 46.0), 300) * env_ar(n, 0.5, 4.0, 10.0) * np.linspace(1.0, 0.4, n), 0.5, 0.0))
    # 67.5-73.6: silence. 73.6: one glassy note.
    ev.append((73.6, bell(midi(93), 4.0, r), 0.2, 0.0))
    # 78.5-86: the hum returns; 86: a tearing sound, then silence.
    n = secs(7.5)
    ev.append((78.5, lp(_hum_low(r, 7.5, 52.0), 400) * env_ar(n, 1.5, 0.2, 5.8), 0.5, 0.0))
    d = secs(1.2)
    tear = moving_bp(white(r, d), np.geomspace(300, 5000, d), 2) * env_ar(d, 0.05, 0.9) * (1 + 0.8 * smooth_random(r, d, 60, -1, 1))
    ev.append((86.0, saturate(tear, 2.0), 0.7, 0.0))
    # 88.5-105: the house returns, thin; no music.
    n = secs(16.5)
    ev.append((88.5, np.vstack([lp(pink(r, n), 600) for _ in range(2)]) * env_ar(n, 3.0, 3.0, 10.5) * 0.05, 1.0, 0.0))
    for _ in range(3):
        ev.append((float(r.uniform(92.0, 102.0)), lp(_bird(r), 3500), 0.03, float(r.uniform(-0.8, 0.8))))
    x = _render(L, ev, reverb_ir(r, 3.2, 0.4), 0.35)
    x = _gate(x, [(3.5, 7.9), (67.5, 73.55), (87.3, 88.4)])
    return rms_to(x, -22)


# ---------------------------------------------------------------- C, Silent Manor

def _detuned(f, s, r, cents=35.0):
    """A wrong piano note: two strings far apart, a slow wow."""
    n = secs(s)
    wow = 1 + 0.006 * np.sin(2 * np.pi * 0.7 * np.arange(n) / SR)
    a = piano(f, s, r)
    b = piano(f * 2 ** (cents / 1200), s, r)
    m = min(len(a), len(b))
    x = (a[:m] + b[:m] * 0.8)
    idx = np.clip(np.cumsum(wow[:m]) - 1, 0, m - 1).astype(int)
    return x[idx]


def _cello_line(notes, start, beat, r, ev, gain=0.3, octave=0):
    t = start
    for m, d in notes:
        ev.append((t, _cello(midi(m + octave), d * beat + 0.5, r), gain, -0.15))
        t += d * beat
    return t


def film_silent_manor():
    r = rng(1301)
    L = 150.0
    ev = []
    # 0-17.5: wind through broken glass; no birds. 6: uneven, limping steps.
    n = secs(39.0)
    wind = np.vstack([bp(pink(r, n), 150, 900) for _ in range(2)]) * (0.4 + smooth_random(r, n, 0.2, 0, 1))
    whistle = moving_bp(white(r, n), 900 + 500 * smooth_random(r, n, 0.3), q=20) * smooth_random(r, n, 0.25, 0, 1) ** 2 * 2.0
    ev.append((0.0, (wind + stereo(whistle)) * env_ar(n, 1.0, 4.0, 34.0), 0.14, 0.0))
    t = 6.0
    for k in range(10):
        ev.append((t, _footstep_marble(r) * (1.0 if k % 2 == 0 else 0.6), 0.18, 0.2))
        t += 0.55 if k % 2 == 0 else 1.05
    # 17.5-39.5: the kitchen; Alis packs: low strings.
    ev.append((17.5, pad([midi(m) for m in (38, 45, 50)], 22.5, 3.0, 3.0, 450, r), 0.4, 0.0))
    _cello_line([(50, 4), (48, 2), (46, 4), (45, 6), (43, 4), (45, 8)], 18.5, 0.75, r, ev, 0.28)
    # 39.5-91: the dark mural: the lullaby detuned and wrong; 56 a cracked
    # waltz; 71.5 a clock under everything.
    tt = 39.5
    for m, d in LULLABY + LULLABY[:6]:
        ev.append((tt, _detuned(midi(m), d * 0.85 + 1.2, r), 0.22, 0.1))
        tt += d * 0.85
    ev.append((39.5, lp(_hum_low(r, 51.5, 41.0), 300) * env_ar(secs(51.5), 4.0, 3.0, 44.5), 0.3, 0.0))
    waltz = [[45, 57, 60, 64], [44, 56, 59, 64], [43, 55, 58, 63], [42, 54, 57, 62]]
    beat = 0.62
    t = 56.0
    k = 0
    while t < 90.0:
        ch = waltz[(k // 3) % 4]
        if k % 3 == 0:
            ev.append((t, _detuned(midi(ch[0]), 1.6, r, 45), 0.2, -0.2))
        else:
            for m in ch[1:]:
                ev.append((t, _detuned(midi(m), 0.9, r, 45), 0.07, 0.2))
        t += beat * (1.0 + 0.08 * float(r.uniform(-1, 1)))  # the waltz limps
        k += 1
    t = 71.5
    while t < 91.0:
        d = secs(0.05)
        tick = reso(white(r, d), 2600 if int((t - 71.5) / 1.0) % 2 else 2100, 12) * env_exp(d, 0.008, 0.0005)
        ev.append((t, tick, 0.35, 0.0))
        t += 1.0
    # 91: silence, then low strings; 104: one note.
    ev.append((94.0, pad([midi(m) for m in (38, 45)], 21.0, 3.0, 3.0, 400, r), 0.4, 0.0))
    ev.append((104.0, _cello(midi(57), 5.0, r), 0.35, 0.0))
    # 115: the hunting motif, low; 131.5-150: the full theme, bigger.
    motif = [(50, 2), (53, 1), (57, 2), (55, 1), (53, 2), (50, 4)]
    _cello_line(motif + motif, 115.0, 0.75, r, ev, 0.34)
    ev.append((115.0, pad([midi(m) for m in (38, 45, 50)], 17.0, 2.0, 2.0, 500, r), 0.35, 0.0))
    t = 115.0
    while t < 131.0:
        ev.append((t, thump(55, 0.8, 0.25, 0.5), 0.3, 0.0))
        t += 1.5
    ev.append((131.5, pad([midi(m) for m in (38, 45, 50, 53, 57, 62)], 18.5, 3.0, 3.0, 2200, r), 0.6, 0.0))
    ev.append((131.5, _choir([midi(m) for m in (50, 57, 62, 65)], 18.5, r), 0.4, 0.0))
    tt = 132.0
    for m, d in LULLABY[:8]:
        ev.append((tt, _cello(midi(m - 12), d * 0.9 + 0.6, r), 0.32, -0.2))
        ev.append((tt, harp(midi(m), 2.0, r), 0.18, 0.3))
        tt += d * 0.9
    t = 132.0
    while t < 148.0:
        ev.append((t, thump(48, 0.9, 0.35, 0.5) + lp(white(r, secs(0.9)), 800) * env_exp(secs(0.9), 0.03) * 0.3, 0.55, 0.0))
        t += 1.5
    x = _render(L, ev, reverb_ir(r, 3.4, 0.4), 0.38)
    x = _gate(x, [(91.0, 93.8)])
    end = secs(L - 2.0)
    x[:, end:] *= np.linspace(1, 0.4, x.shape[1] - end)  # carried into play
    return rms_to(x, -21)


SOUNDS = {
    "music/film_eyes_open": (film_eyes_open, 3, "Cutscene A 'Eyes Open' (76 s): veiled glen, the senses open into birds, a singing willow, celesta"),
    "music/film_night_court": (film_night_court, 3, "Cutscene B 'The Night Court' (105 s): silence, marble steps, a cold rising hum, whispers in her mind"),
    "music/film_silent_manor": (film_silent_manor, 3, "Cutscene C 'The Silent Manor' (150 s): wind through broken glass, the lullaby detuned, a cracked waltz, the theme"),
}
CUES = {
    "music_film_eyes_open": (["music/film_eyes_open"], -2, 0, False, True, 0),
    "music_film_night_court": (["music/film_night_court"], -2, 0, False, True, 0),
    "music_film_silent_manor": (["music/film_silent_manor"], -2, 0, False, True, 0),
}
