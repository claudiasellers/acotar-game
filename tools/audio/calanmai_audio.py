#!/usr/bin/env python3
"""Fire Night sounds for the Calanmai chapter (L45). Self-made, CC0, fixed seeds.

    python3 tools/audio/calanmai_audio.py
Writes (ogg, via ffmpeg):
  audio/calanmai/calanmai_drums.ogg   16 s seamless loop: the great drums on the
      hill, felt more than heard ("I can feel them in my teeth"), a 6/8 pulse of
      low skins with a hand-drum chatter over it. Played positionally from the
      summit pyre, so from the manor it is a far throb.
  audio/calanmai/calanmai_fire.ogg    8 s loop: a big bonfire's roar and crackle.
  audio/calanmai/calanmai_hiss.ogg    2.5 s: the three's low hissing laugh (horror, not cute).
  audio/calanmai/calanmai_heart.ogg   4 s loop: her heartbeat, close, for the hallway.
"""

import os
import subprocess
import tempfile
import wave

import numpy as np

SR = 32000
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "audio", "calanmai")
rng = np.random.default_rng(2020)


def env(n, attack, decay):
    t = np.arange(n) / SR
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    return a * np.exp(-np.maximum(t - attack, 0) / decay)


def drum(f0, dur, decay, slap, bend=0.5):
    n = int(SR * dur)
    t = np.arange(n) / SR
    f = f0 * (1 + bend * np.exp(-t / 0.03))
    ph = 2 * np.pi * np.cumsum(f) / SR
    body = np.sin(ph) + 0.35 * np.sin(2.01 * ph)
    noise = rng.standard_normal(n) * np.exp(-t / 0.012) * slap
    return (body * env(n, 0.002, decay) + noise) * 0.9


def place(buf, snd, at, gain, loop=True):
    i = int(at * SR)
    n = len(snd)
    idx = (np.arange(n) + i) % len(buf) if loop else np.arange(i, min(i + n, len(buf)))
    buf[idx] += snd[: len(idx)] * gain


def lowpass(x, cutoff):
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.zeros_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc = (1 - a) * x[i] + a * acc
        y[i] = acc
    return y


def drums():
    L = 16.0
    buf = np.zeros(int(SR * L))
    beat = 60 / 108                            # dotted-quarter pulse, 6/8 feel
    k = 0
    t = 0.0
    while t < L - 1e-6:
        place(buf, drum(46, 1.2, 0.45, 0.5), t, 1.0)                     # the great skin
        place(buf, drum(58, 0.7, 0.25, 0.3), t + beat * 2 / 3, 0.45)       # its answer
        if k % 2:
            place(buf, drum(40, 1.4, 0.55, 0.6), t + beat / 3, 0.6)
        for j in range(6):                                                  # hand-drum chatter
            g = 0.16 + 0.1 * ((j + k) % 3 == 0)
            place(buf, drum(190 + 30 * (j % 2), 0.12, 0.05, 1.0, 0.2), t + j * beat / 6 + 0.003 * rng.standard_normal(), g)
        t += beat
        k += 1
    buf = 0.75 * buf + 0.25 * lowpass(buf, 300)
    return buf / np.max(np.abs(buf)) * 0.85


def fire():
    L = 8.0
    n = int(SR * L)
    roar = lowpass(rng.standard_normal(n), 380) * 3.0
    roar *= 0.8 + 0.2 * np.sin(np.arange(n) / SR * 2 * np.pi * 0.25)
    buf = roar
    for _ in range(180):
        at = rng.uniform(0, L)
        c = rng.standard_normal(int(SR * 0.02)) * env(int(SR * 0.02), 0.0005, 0.004) * rng.uniform(0.3, 1.0)
        place(buf, c, at, 1.0)
    fade = int(SR * 0.5)                       # cross-fade the seam
    buf[:fade] = buf[:fade] * np.linspace(0, 1, fade) + buf[-fade:] * np.linspace(1, 0, fade)
    buf = buf[: n - fade]
    return buf / np.max(np.abs(buf)) * 0.7


def hiss():
    n = int(SR * 2.5)
    t = np.arange(n) / SR
    breath = lowpass(rng.standard_normal(n), 5000) - lowpass(rng.standard_normal(n), 1500)
    laugh = 0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 5.5 * t)) * np.exp(-t / 1.2)
    voice = np.sin(2 * np.pi * (95 + 8 * np.sin(2 * np.pi * 5.5 * t)) * t) * 0.25
    out = (breath * 1.3 + voice) * laugh * env(n, 0.08, 1.1)
    return out / np.max(np.abs(out)) * 0.8


def heart():
    L = 4.0
    buf = np.zeros(int(SR * L))
    period = 60 / 96
    t = 0.0
    while t < L - 1e-6:
        place(buf, drum(52, 0.35, 0.09, 0.05, 0.3), t, 1.0)
        place(buf, drum(48, 0.3, 0.08, 0.04, 0.3), t + 0.26, 0.7)
        t += period
    buf = lowpass(buf, 160)
    return buf / np.max(np.abs(buf)) * 0.9


def write_ogg(name, data):
    os.makedirs(OUT, exist_ok=True)
    with tempfile.TemporaryDirectory() as d:
        wav = os.path.join(d, name + ".wav")
        with wave.open(wav, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes((np.clip(data, -1, 1) * 32767).astype(np.int16).tobytes())
        out = os.path.join(OUT, name + ".ogg")
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "4", out],
                       check=True)
        print("wrote", os.path.relpath(out, ROOT), os.path.getsize(out), "bytes")


if __name__ == "__main__":
    write_ogg("calanmai_drums", drums())
    write_ogg("calanmai_fire", fire())
    write_ogg("calanmai_hiss", hiss())
    write_ogg("calanmai_heart", heart())
