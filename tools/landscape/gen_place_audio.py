#!/usr/bin/env python3
"""Synthesises the place ambience loops (lane L32) into audio/amb/places/*.ogg.

  python3 -I tools/landscape/gen_place_audio.py [name ...]

Self-made from seeded noise and sine partials (no recordings), CC0, like
tools/audio/gen_act1_audio.py. Each loop is mono, 22.05 kHz, 10 s, and wraps
seamlessly (the tail is crossfaded into the head). Needs numpy and ffmpeg.
"""
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np

SR = 22050
LEN = 10.0
FADE = 1.0
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "audio", "amb", "places")


def t_axis(sec):
    return np.arange(int(sec * SR)) / SR


def onepole(x, cutoff):
    """Simple low-pass."""
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return y


def bandnoise(rng, n, lo, hi):
    """Band-limited noise via FFT masking (fast)."""
    spec = np.fft.rfft(rng.standard_normal(n))
    f = np.fft.rfftfreq(n, 1 / SR)
    spec[(f < lo) | (f > hi)] = 0
    x = np.fft.irfft(spec, n)
    return x / (np.abs(x).max() + 1e-9)


def env(n, attack, decay):
    t = np.arange(n) / SR
    return np.minimum(t / max(attack, 1e-4), 1.0) * np.exp(-t / decay)


def place(buf, start, grain):
    end = min(len(buf), start + len(grain))
    buf[start:end] += grain[: end - start]


def bell(freq, dur, rng):
    t = t_axis(dur)
    tone = sum(a * np.sin(2 * np.pi * freq * m * t + rng.uniform(0, 6)) for m, a in ((1, 1.0), (2.76, 0.4), (5.4, 0.18), (8.9, 0.08)))
    return tone * env(len(t), 0.003, dur / 4)


def chirp(rng):
    dur = rng.uniform(0.05, 0.14)
    t = t_axis(dur)
    f0 = rng.uniform(2800, 4800)
    f = f0 * (1 + rng.uniform(-0.35, 0.35) * t / dur) + 300 * np.sin(2 * np.pi * rng.uniform(25, 60) * t)
    ph = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(ph) * np.sin(np.pi * t / dur) ** 2


# --- the loops ---------------------------------------------------------------

def brook(rng, n):
    base = bandnoise(rng, n, 300, 3200) * 0.35
    burble = np.zeros(n)
    for _ in range(int(LEN * 38)):
        dur = rng.uniform(0.02, 0.07)
        t = t_axis(dur)
        f = rng.uniform(500, 1600) * (1 + 1.2 * t / dur)
        g = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.sin(np.pi * t / dur)
        place(burble, rng.integers(0, n), g * rng.uniform(0.08, 0.25))
    return base * (0.75 + 0.25 * np.sin(2 * np.pi * 0.3 * t_axis(LEN))) + burble


def fire(rng, n):
    roar = bandnoise(rng, n, 60, 700) * 0.5
    crackle = np.zeros(n)
    for _ in range(int(LEN * 22)):
        k = int(rng.uniform(0.002, 0.012) * SR)
        g = rng.standard_normal(k) * env(k, 0.0005, 0.003)
        place(crackle, rng.integers(0, n), g * rng.uniform(0.3, 1.0))
    pops = bandnoise(rng, n, 1500, 6000) * 0
    return roar * (0.7 + 0.3 * np.abs(np.sin(2 * np.pi * 0.17 * t_axis(LEN)))) + crackle * 0.6 + pops


def bees(rng, n):
    t = t_axis(LEN)
    out = np.zeros(n)
    for _ in range(5):
        f = rng.uniform(190, 260)
        wob = 1 + 0.03 * np.sin(2 * np.pi * rng.uniform(0.2, 0.7) * t + rng.uniform(0, 6))
        ph = 2 * np.pi * np.cumsum(f * wob) / SR
        saw = sum(np.sin(k * ph) / k for k in range(1, 9))
        amp = 0.5 + 0.5 * np.sin(2 * np.pi * rng.uniform(0.05, 0.2) * t + rng.uniform(0, 6))
        out += saw * amp * 0.12
    out = onepole(out, 1800)
    for _ in range(4):
        place(out, rng.integers(0, n), chirp(rng) * 0.12)
    return out + bandnoise(rng, n, 200, 2500) * 0.05


def chimes(rng, n):
    pent = [523.25, 587.33, 659.25, 783.99, 880.0, 1046.5, 1174.7]
    out = bandnoise(rng, n, 2000, 7000) * 0.02
    t = t_axis(LEN)
    pad = sum(np.sin(2 * np.pi * f * t) for f in (261.6, 392.0, 523.25)) * 0.03 * (0.6 + 0.4 * np.sin(2 * np.pi * 0.1 * t))
    out += pad
    for _ in range(int(LEN * 1.4)):
        place(out, rng.integers(0, n - SR), bell(rng.choice(pent), 2.5, rng) * rng.uniform(0.15, 0.35))
    return out


def wind_birds(rng, n):
    t = t_axis(LEN)
    wind = bandnoise(rng, n, 150, 1200) * (0.35 + 0.25 * np.sin(2 * np.pi * 0.13 * t) + 0.1 * np.sin(2 * np.pi * 0.31 * t))
    birds = np.zeros(n)
    for _ in range(6):
        at = rng.integers(0, n - SR)
        for k in range(rng.integers(2, 6)):
            place(birds, at + int(k * rng.uniform(0.09, 0.16) * SR), chirp(rng) * 0.25)
    return wind + birds


def bubbles(rng, n):
    out = bandnoise(rng, n, 80, 500) * 0.15
    for _ in range(int(LEN * 9)):
        dur = rng.uniform(0.04, 0.12)
        t = t_axis(dur)
        f = rng.uniform(250, 700) * (1 + 2.5 * t / dur)
        g = np.sin(2 * np.pi * np.cumsum(f) / SR) * env(len(t), 0.002, dur / 2.5)
        place(out, rng.integers(0, n), g * rng.uniform(0.2, 0.5))
    return out


def mill(rng, n):
    out = brook(rng, n) * 0.6
    period = 2.5
    for k in range(int(LEN / period)):
        dur = 0.6
        t = t_axis(dur)
        f = 140 + 60 * np.sin(np.pi * t / dur)
        creak = np.sign(np.sin(2 * np.pi * np.cumsum(f) / SR)) * env(len(t), 0.05, 0.3)
        place(out, int((k * period + rng.uniform(0, 0.2)) * SR), onepole(creak, 900) * 0.25)
        place(out, int((k * period + 1.25) * SR), bandnoise(rng, int(0.25 * SR), 200, 1500) * env(int(0.25 * SR), 0.01, 0.08) * 0.3)
    return out


def village(rng, n):
    t = t_axis(LEN)
    murmur = np.zeros(n)
    for _ in range(4):
        x = bandnoise(rng, n, 250, 1200)
        syl = 0.5 + 0.5 * np.sin(2 * np.pi * rng.uniform(3, 5) * t + rng.uniform(0, 6))
        murmur += x * syl * (0.5 + 0.5 * np.sin(2 * np.pi * rng.uniform(0.1, 0.3) * t)) * 0.12
    out = murmur + bandnoise(rng, n, 150, 900) * 0.08
    for _ in range(3):
        place(out, rng.integers(0, n - SR), bell(rng.choice([880.0, 1046.5, 1318.5]), 1.5, rng) * 0.08)
    for _ in range(3):
        place(out, rng.integers(0, n), chirp(rng) * 0.1)
    return out


def blight_drone(rng, n):
    t = t_axis(LEN)
    # Beating low partials that never settle, a breath of wind, wood that groans.
    drone = sum(np.sin(2 * np.pi * f * t + rng.uniform(0, 6)) * a for f, a in ((41.0, 0.6), (43.1, 0.5), (61.7, 0.3), (87.3, 0.15)))
    drone *= 0.6 + 0.4 * np.sin(2 * np.pi * 0.07 * t) ** 2
    air = bandnoise(rng, n, 100, 600) * 0.25 * (0.5 + 0.5 * np.sin(2 * np.pi * 0.11 * t))
    out = drone * 0.5 + air
    for _ in range(2):
        dur = 1.4
        tt = t_axis(dur)
        f = 70 + 40 * np.sin(np.pi * tt / dur) + 6 * np.sin(2 * np.pi * 9 * tt)
        g = onepole(np.sign(np.sin(2 * np.pi * np.cumsum(f) / SR)), 600) * env(len(tt), 0.2, 0.6)
        place(out, rng.integers(0, n - int(dur * SR)), g * 0.25)
    return out


def shrine_hum(rng, n):
    t = t_axis(LEN)
    hum = sum(np.sin(2 * np.pi * f * t) * a for f, a in ((196.0, 0.3), (293.7, 0.2), (392.0, 0.12), (587.3, 0.05)))
    hum *= 0.6 + 0.4 * np.sin(2 * np.pi * 0.05 * t)
    out = hum * 0.4 + bandnoise(rng, n, 3000, 8000) * 0.015
    for _ in range(2):
        place(out, rng.integers(0, n - 2 * SR), bell(rng.choice([784.0, 1174.7]), 3.0, rng) * 0.08)
    return out


LOOPS = {"brook": brook, "fire": fire, "bees": bees, "chimes": chimes, "wind_birds": wind_birds,
         "bubbles": bubbles, "mill": mill, "village": village, "blight_drone": blight_drone, "shrine_hum": shrine_hum}


def render(name):
    rng = np.random.default_rng(hash_name(name))
    # Render LEN + FADE seconds, then fold the tail over the head so it loops.
    x = _render_len(name, rng, LEN + FADE)
    f = int(FADE * SR)
    body = x[: int(LEN * SR)].copy()
    ramp = np.linspace(0, 1, f)
    body[:f] = body[:f] * ramp + x[int(LEN * SR): int(LEN * SR) + f] * (1 - ramp)
    body = body - body.mean()
    body = body / (np.abs(body).max() + 1e-9) * 0.7
    return body


def _render_len(name, rng, sec):
    global LEN
    keep = LEN
    LEN = sec
    try:
        return LOOPS[name](rng, int(sec * SR))
    finally:
        LEN = keep


def hash_name(name):
    h = 2166136261
    for c in name.encode():
        h = ((h ^ c) * 16777619) & 0xFFFFFFFF
    return h


def write_ogg(name, data):
    os.makedirs(OUT, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        wav = os.path.join(tmp, name + ".wav")
        with wave.open(wav, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes((np.clip(data, -1, 1) * 32767).astype("<i2").tobytes())
        out = os.path.join(OUT, name + ".ogg")
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "2",
                        "-fflags", "+bitexact", "-map_metadata", "-1", out], check=True)
        return out


if __name__ == "__main__":
    names = sys.argv[1:] or list(LOOPS)
    for nm in names:
        path = write_ogg(nm, render(nm))
        print(f"{nm}: {os.path.getsize(path) // 1024} KB")
