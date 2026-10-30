"""Small DSP kit for the self-made Act I audio (gen_act1_audio.py).

Everything here is synthesis from seeded noise and sine partials, so every
file it makes is original work released CC0. Needs numpy and scipy.
"""
import subprocess
import tempfile
from pathlib import Path

import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, fftconvolve, sosfilt

SR = 44100


def t_axis(seconds: float) -> np.ndarray:
    return np.arange(int(seconds * SR)) / SR


def secs(n: float) -> int:
    return int(n * SR)


# ---------------------------------------------------------------- filters

def _sos(kind: str, freq, order: int = 2):
    nyq = SR / 2
    if isinstance(freq, (list, tuple)):
        lo, hi = max(freq[0], 10.0), min(freq[1], nyq * 0.95)
        return butter(order, [lo / nyq, hi / nyq], btype="band", output="sos")
    return butter(order, min(freq, nyq * 0.95) / nyq, btype=kind, output="sos")


def lp(x, f, order=2):
    return sosfilt(_sos("low", f, order), x, axis=-1)


def hp(x, f, order=2):
    return sosfilt(_sos("high", f, order), x, axis=-1)


def bp(x, lo, hi, order=2):
    return sosfilt(_sos("band", (lo, hi), order), x, axis=-1)


def reso(x, f, q=8.0):
    """Narrow band-pass at f with quality q (a resonant mode)."""
    bw = f / q
    return bp(x, f - bw / 2, f + bw / 2, 2)


def moving_bp(x, centres, q=3.0, block=512):
    """Band-pass whose centre follows `centres` (one value per sample)."""
    out = np.zeros_like(x)
    zi = None
    for i in range(0, len(x), block):
        c = float(np.mean(centres[i:i + block]))
        sos = _sos("band", (c - c / q / 2, c + c / q / 2), 2)
        if zi is None:
            zi = np.zeros((sos.shape[0], 2))
        out[i:i + block], zi = sosfilt(sos, x[i:i + block], zi=zi)
    return out


# ---------------------------------------------------------------- sources

def rng(seed: int) -> np.random.Generator:
    return np.random.default_rng(seed)


def white(r, n):
    return r.standard_normal(n)


def pink(r, n):
    """1/f noise by spectral shaping."""
    spec = np.fft.rfft(r.standard_normal(n))
    f = np.arange(len(spec))
    f[0] = 1
    spec /= np.sqrt(f)
    x = np.fft.irfft(spec, n)
    return x / (np.std(x) + 1e-9)


def brown(r, n):
    x = np.cumsum(r.standard_normal(n))
    x = hp(x, 15)
    return x / (np.std(x) + 1e-9)


def smooth_random(r, n, rate_hz, lo=0.0, hi=1.0):
    """A slow random curve: points every 1/rate s, cosine-interpolated."""
    pts = max(int(n / SR * rate_hz) + 3, 4)
    vals = r.uniform(lo, hi, pts)
    pos = np.linspace(0, pts - 1.001, n)
    i = pos.astype(int)
    frac = (1 - np.cos((pos - i) * np.pi)) / 2
    return vals[i] * (1 - frac) + vals[i + 1] * frac


def osc_phase(freq):
    """Phase (radians) for a per-sample frequency curve."""
    return 2 * np.pi * np.cumsum(freq) / SR


# ---------------------------------------------------------------- envelopes

def env_exp(n, decay_s, attack_s=0.002):
    t = np.arange(n) / SR
    a = np.clip(t / max(attack_s, 1e-4), 0, 1)
    return a * np.exp(-t / max(decay_s, 1e-4))


def env_ar(n, attack_s, release_s, hold_s=0.0):
    t = np.arange(n) / SR
    up = np.clip(t / max(attack_s, 1e-4), 0, 1)
    down = np.clip(1 - (t - attack_s - hold_s) / max(release_s, 1e-4), 0, 1)
    return np.minimum(up, down) ** 1.5


def fade(x, fin=0.005, fout=0.02):
    x = x.copy()
    a, b = secs(fin), secs(fout)
    if a:
        x[..., :a] *= np.linspace(0, 1, a)
    if b:
        x[..., -b:] *= np.linspace(1, 0, b)
    return x


# ---------------------------------------------------------------- mixing

def place(dst, src, at_s, gain=1.0, pan=None):
    """Add src into dst at time at_s. dst may be mono (n,) or stereo (2, n)."""
    i = secs(at_s)
    if i >= dst.shape[-1]:
        return dst
    if dst.ndim == 2 and src.ndim == 1:
        p = 0.0 if pan is None else pan
        l, rr = np.cos((p + 1) * np.pi / 4), np.sin((p + 1) * np.pi / 4)
        src = np.vstack([src * l, src * rr]) * 1.414
    m = min(src.shape[-1], dst.shape[-1] - i)
    dst[..., i:i + m] += src[..., :m] * gain
    return dst


def stereo(left, right=None):
    return np.vstack([left, left if right is None else right])


def widen(r, x, ms=11.0):
    """Mono to stereo with a short decorrelating delay."""
    d = secs(ms / 1000)
    rgt = np.concatenate([np.zeros(d), x[:-d]]) if d else x
    return np.vstack([x, rgt])


def saturate(x, drive=2.0):
    return np.tanh(x * drive) / np.tanh(drive)


def normalize(x, peak_db=-1.0):
    p = np.max(np.abs(x)) + 1e-9
    return x * (10 ** (peak_db / 20) / p)


def rms_to(x, db):
    r = np.sqrt(np.mean(x ** 2)) + 1e-9
    y = x * (10 ** (db / 20) / r)
    p = np.max(np.abs(y))
    return y / p * 0.98 if p > 0.98 else y


def loop_seam(x, total_s, xfade_s):
    """x was rendered total_s + xfade_s long; fold the tail into the head."""
    n, f = secs(total_s), secs(xfade_s)
    out = x[..., :n].copy()
    k = np.linspace(0, np.pi / 2, f)
    out[..., :f] = out[..., :f] * np.sin(k) + x[..., n:n + f] * np.cos(k)
    return out


# ---------------------------------------------------------------- reverb

def reverb_ir(r, seconds, bright=0.5, predelay_ms=12.0, early=6):
    """Stereo noise impulse response: highs die faster than lows."""
    n = secs(seconds)
    t = np.arange(n) / SR
    out = []
    for _ in range(2):
        lo = lp(white(r, n), 900) * np.exp(-t * 6.9 / seconds)
        mid = bp(white(r, n), 900, 4000) * np.exp(-t * 6.9 / (seconds * (0.45 + 0.4 * bright)))
        hi = hp(white(r, n), 4000) * np.exp(-t * 6.9 / (seconds * (0.15 + 0.3 * bright)))
        ir = lo + 0.8 * mid + 0.5 * bright * hi
        pd = secs(predelay_ms / 1000)
        ir = np.concatenate([np.zeros(pd), ir])[:n]
        for _ in range(early):
            k = secs(r.uniform(0.004, 0.06))
            if k < n:
                ir[k] += r.uniform(-0.6, 0.6) * 4
        out.append(ir / np.sqrt(np.sum(ir ** 2)))
    return np.vstack(out)


def reverb(x, ir, wet=0.3, dry=1.0):
    mono = x if x.ndim == 1 else x.mean(axis=0)
    tail = np.vstack([fftconvolve(mono, ir[c])[:len(mono)] for c in range(2)])
    base = stereo(x) if x.ndim == 1 else x
    return base * dry + tail * wet


def reverb_mono(x, ir, wet=0.3):
    return x + fftconvolve(x, ir[0])[:len(x)] * wet


# ---------------------------------------------------------------- voices

def tone(freq, seconds, partials, decay_s, bright_decay=1.0, r=None, detune=0.0):
    """Additive plucked/struck tone. partials = [(ratio, amp), ...]. Higher
    partials decay faster (bright_decay scales how much)."""
    n = secs(seconds)
    t = np.arange(n) / SR
    x = np.zeros(n)
    for k, (ratio, amp) in enumerate(partials):
        f = freq * ratio * (1 + (r.uniform(-detune, detune) if r is not None and detune else 0))
        if f > SR * 0.45:
            continue
        d = decay_s / (1 + bright_decay * k * 0.6)
        x += amp * np.sin(2 * np.pi * f * t + (k * 1.3)) * np.exp(-t / d)
    attack = np.clip(t / 0.003, 0, 1)
    return x * attack


HARP = [(1, 1.0), (2, 0.55), (3, 0.3), (4, 0.18), (5, 0.1), (6, 0.06), (7, 0.03)]
PIANO = [(1, 1.0), (2, 0.42), (3, 0.22), (4, 0.12), (5.01, 0.07), (6.02, 0.04), (7.03, 0.02)]
BELL = [(1, 1.0), (2.76, 0.45), (5.4, 0.25), (8.93, 0.12), (13.34, 0.06), (0.5, 0.2)]
CELESTA = [(1, 1.0), (4.0, 0.3), (2.0, 0.12), (9.2, 0.05)]


def harp(f, s=2.6, r=None):
    return tone(f, s, HARP, s * 0.45, 1.2, r)


def piano(f, s=3.0, r=None):
    return tone(f, s, PIANO, s * 0.35, 0.9, r)


def bell(f, s=2.0, r=None):
    return tone(f, s, BELL, s * 0.4, 0.5, r)


def celesta(f, s=1.6, r=None):
    return tone(f, s, CELESTA, s * 0.3, 0.8, r)


def pad(freqs, seconds, attack=1.5, release=2.0, cutoff=1400, r=None, voices=3):
    """Soft string-ish pad: detuned saw stacks, low-passed, slow envelope."""
    n = secs(seconds)
    t = np.arange(n) / SR
    x = np.zeros(n)
    for f in freqs:
        for v in range(voices):
            fd = f * (1 + (v - (voices - 1) / 2) * 0.004)
            ph = 2 * np.pi * fd * t + (r.uniform(0, 6.28) if r is not None else v)
            for h in range(1, 12):
                if fd * h > 6000:
                    break
                x += np.sin(ph * h) / h
    x = lp(x, cutoff, 2)
    return x * env_ar(n, attack, release, max(seconds - attack - release, 0)) / (len(freqs) * voices * 2)


def midi(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def voiced(r, f0_curve, formants, breath=0.15, rough=0.3, sub=0.0):
    """A creature voice: a jittery glottal buzz through formant resonances.
    f0_curve per sample (Hz); formants = [(freq, q, gain), ...] static, or a
    callable(t)->list for gliding vowels."""
    n = len(f0_curve)
    jitter = 1 + rough * 0.06 * smooth_random(r, n, 35, -1, 1)
    f0 = f0_curve * jitter
    ph = osc_phase(f0)
    buzz = np.zeros(n)
    for h in range(1, 40):
        if np.max(f0) * h > SR * 0.45:
            break
        buzz += np.sin(ph * h) / h ** 0.9
    if sub:
        buzz += sub * np.sin(ph * 0.5) * (1 + np.sin(ph * 0.5 + 1)) * 0.6
    amp_rough = 1 + rough * smooth_random(r, n, 60, -0.6, 0.6)
    src = buzz * amp_rough + breath * white(r, n) * 3
    out = np.zeros(n)
    if callable(formants):
        block = 1024
        t = np.arange(n) / SR
        for i in range(0, n, block):
            seg = src[i:i + block]
            for (f, q, g) in formants(t[i]):
                out[i:i + block] += g * reso(np.concatenate([src[max(i - 2048, 0):i], seg]), f, q)[-len(seg):]
    else:
        for (f, q, g) in formants:
            out += g * reso(src, f, q)
    return out


# ---------------------------------------------------------------- foley atoms

def grains(r, seconds, density, dur_ms=(0.3, 1.2), band=(800, 7000), env=None):
    """Granular crackle: many tiny filtered noise ticks (snow, splinters)."""
    n = secs(seconds)
    x = np.zeros(n)
    count = int(density * seconds)
    for _ in range(count):
        at = r.uniform(0, seconds)
        if env is not None:
            if r.random() > env(at / seconds):
                continue
        g = secs(r.uniform(*dur_ms) / 1000) + 2
        tick = white(r, g) * np.hanning(g) * r.uniform(0.2, 1.0)
        place(x, tick, at)
    return bp(x, band[0], band[1], 2)


def thump(freq, seconds, decay_s, drop=0.6):
    """Low body hit: a sine that drops in pitch."""
    n = secs(seconds)
    t = np.arange(n) / SR
    f = freq * (1 - drop * (1 - np.exp(-t / 0.03)))
    return np.sin(osc_phase(f)) * env_exp(n, decay_s, 0.001)


def stick_slip(r, seconds, rate_curve, modes, jitter=0.25):
    """Creak: an irregular click train (rate in Hz per sample) through wood
    resonances [(f, q, gain)]."""
    n = secs(seconds)
    rate = rate_curve if np.ndim(rate_curve) else np.full(n, rate_curve)
    acc = np.cumsum(rate / SR * (1 + jitter * smooth_random(r, n, 40, -1, 1)))
    clicks = np.diff(np.floor(acc), prepend=0)
    clicks *= r.uniform(0.4, 1.0, n)
    out = np.zeros(n)
    for (f, q, g) in modes:
        out += g * reso(clicks, f, q)
    return out


# ---------------------------------------------------------------- output

def write_ogg(path: Path, x: np.ndarray, quality: float = 4.0) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    data = x.T if x.ndim == 2 else x
    pcm = (np.clip(data, -1, 1) * 32767).astype(np.int16)
    with tempfile.TemporaryDirectory() as tmp:
        wav = Path(tmp) / "x.wav"
        wavfile.write(wav, SR, pcm)
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(wav), "-c:a", "libvorbis",
                        "-q:a", str(quality), "-map_metadata", "-1", "-fflags", "+bitexact",
                        "-flags:a", "+bitexact", str(path)], check=True)
