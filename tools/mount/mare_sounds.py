"""The white mare's sounds (lane L47), synthesised with numpy, fixed seed.

Run:  python3 tools/mount/mare_sounds.py
Out:  systems/mount/sounds/{whistle,clop_1..3,snort,whinny,wind}.wav (22.05 kHz mono)

Feyre's whistle is two bright notes (up, then a lilt down). The clops are
soft hollow knocks on turf; the snort a breathy burst; the whinny a rising,
whickering neigh that falls away. Gentle, never harsh: she's the princess
mare (R3), and the horror zones are where she goes quiet and balks.
"""
import os
import wave

import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "systems", "mount", "sounds")
rng = np.random.default_rng(47)


def env(n, a, r):
    e = np.ones(n)
    ai, ri = int(a * SR), int(r * SR)
    e[:ai] = np.linspace(0, 1, ai)
    e[-ri:] *= np.linspace(1, 0, ri) ** 2
    return e


def lowpass(x, k):
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += k * (v - acc)
        y[i] = acc
    return y


def save(name, x):
    x = x / max(1e-6, np.max(np.abs(x))) * 0.85
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())


def tone(freqs, dur):
    n = int(dur * SR)
    f = np.interp(np.linspace(0, 1, n), np.linspace(0, 1, len(freqs)), freqs)
    ph = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(ph), n


def whistle():
    a, na = tone([1500, 1980, 2050], 0.32)
    b, nb = tone([2050, 2400, 1700], 0.42)
    gap = np.zeros(int(0.06 * SR))
    x = np.concatenate([a * env(na, 0.03, 0.08), gap, b * env(nb, 0.02, 0.2)])
    x += 0.04 * lowpass(rng.standard_normal(len(x)), 0.3) * np.abs(x)  # breath
    save("whistle", x)


def clop(i):
    n = int(0.16 * SR)
    t = np.arange(n) / SR
    body = np.sin(2 * np.pi * (180 + 25 * i) * t) * np.exp(-t * 38)
    knock = lowpass(rng.standard_normal(n), 0.25) * np.exp(-t * 70)
    save(f"clop_{i}", body * 0.8 + knock * 0.9)


def snort():
    n = int(0.55 * SR)
    t = np.arange(n) / SR
    noise = lowpass(rng.standard_normal(n), 0.18) - lowpass(rng.standard_normal(n), 0.02)
    flutter = 1 + 0.6 * np.sin(2 * np.pi * 26 * t)
    save("snort", noise * flutter * env(n, 0.02, 0.3) * (1 - t / t[-1]) ** 0.5)


def whinny():
    dur = 1.35
    n = int(dur * SR)
    t = np.arange(n) / SR
    base = np.interp(t, [0, 0.25, 0.7, 1.35], [520, 980, 760, 420])
    vib = 1 + 0.07 * np.sin(2 * np.pi * 11 * t) * np.clip(t / 0.3, 0, 1)
    ph = 2 * np.pi * np.cumsum(base * vib) / SR
    voice = np.sin(ph) + 0.45 * np.sin(2 * ph) + 0.2 * np.sin(3 * ph)
    breath = lowpass(rng.standard_normal(n), 0.35) * 0.25
    save("whinny", (voice + breath) * env(n, 0.05, 0.5))


def wind():
    """A soft rush of air for the gallop: two seconds that loop seamlessly."""
    n = 2 * SR
    x = lowpass(rng.standard_normal(n * 2), 0.06)
    x = x[n // 2: n // 2 + n]
    fade = int(0.25 * SR)
    x[:fade] = x[:fade] * np.linspace(0, 1, fade) + x[-fade:] * np.linspace(1, 0, fade)
    x = x[:-fade]
    gust = 1 + 0.35 * np.sin(2 * np.pi * np.arange(len(x)) / len(x))
    save("wind", x * gust)


if __name__ == "__main__":
    wind()
    whistle()
    for i in (1, 2, 3):
        clop(i)
    snort()
    whinny()
    print("mare sounds ->", os.path.abspath(OUT))
