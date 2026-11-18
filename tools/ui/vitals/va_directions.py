#!/usr/bin/env python3
"""Look-dev only: two alternative HUD directions, mocked on the same scenes as the
first pass, so the owner can pick one. Nothing here ships.

  B "Jewelled": rose-cut gems, pearl, glow. Health is five jewelled roses.
  C "Painted":  Feyre's own brushwork. Health is a stroke of rose paint.

Run: python3 tools/ui/vitals/va_directions.py <out_dir>
"""
import math
import os
import random
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import va_checkpoint as ck  # noqa: E402
import va_pictos as vp  # noqa: E402
from va_common import (HORROR, SPRING, arc_d, circ, ell, f, g, leaf, line, mix, path, pol, pts_d, rose, star4, svg)  # noqa: E402

H = HORROR
S = SPRING
C = 128
OUT = {}


def add(name, w, h, body, defs=""):
    OUT[name] = svg(w, h, body, defs)


def pal_b(col):
    p = dict(S)
    for k in ("white", "pearl", "blush", "lilac", "periwinkle", "mint", "sky"):
        p[k] = "#FFFFFF"
    p.update({"rose": "#FFD3E2", "deep": "#FF8FB8", "butter": "#FFF1BE", "amber": "#FFD27A", "coral": "#FFAE98", "leaf": "#D2F3DC",
              "wood": "#F3D9BF", "cake": "#FFE7C2", "ink": mix(col, "#43102F", 0.66)})
    return p


def pal_c():
    p = dict(S)
    for k in ("white", "pearl"):
        p[k] = "rgba(255,255,255,0.7)"
    for k, a in (("blush", .7), ("lilac", .7), ("periwinkle", .75), ("mint", .7), ("sky", .75), ("rose", .8), ("deep", .85), ("butter", .8),
                 ("amber", .85), ("coral", .85), ("leaf", .8)):
        r, gg, b = [int(S[k][i:i + 2], 16) for i in (1, 3, 5)]
        p[k] = f"rgba({r},{gg},{b},{a})"
    p["wood"], p["cake"] = "rgba(176,120,76,0.8)", "rgba(242,201,138,0.85)"
    return p


BUFF_FN = {t: (fn, col) for _, t, fn, col in vp.BUFFS}
DEB_FN = {t: (fn, col) for _, t, fn, col in vp.DEBUFFS}
GLOW = {"venom": "#9FBF3A", "drowsy": "#9A6BD9", "roar_shake": "#E0303E", "chilled": "#8FD0FF", "starving": "#C9BFA8"}


# ------------------------------------------------------------------ B: jewelled

def b_medallion(tag, frac=0.7):
    if tag in BUFF_FN:
        fn, key = BUFF_FN[tag]
        col = S[key] if key != "pearl" else "#F6D9E6"
        deep = mix(col, "#6A2A6E", 0.42)
        defs = (f'<radialGradient id="gm" cx="0.36" cy="0.28" r="0.9"><stop offset="0" stop-color="{mix(col, "#FFFFFF", 0.8)}"/><stop offset="0.45" stop-color="{col}"/>'
                f'<stop offset="1" stop-color="{deep}"/></radialGradient>'
                f'<linearGradient id="gd" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#FFF6CC"/><stop offset="0.45" stop-color="{S["gold"]}"/>'
                f'<stop offset="0.7" stop-color="{S["gold_dk"]}"/><stop offset="1" stop-color="#FBE9A8"/></linearGradient>'
                '<radialGradient id="gl" cx="0.5" cy="0.5" r="0.5"><stop offset="0" stop-color="#FFF" stop-opacity="0.95"/><stop offset="1" stop-color="#FFF" stop-opacity="0"/></radialGradient>'
                '<filter id="bl" x="-40%" y="-40%" width="180%" height="180%"><feGaussianBlur stdDeviation="9"/></filter>'
                '<filter id="b2" x="-40%" y="-40%" width="180%" height="180%"><feGaussianBlur stdDeviation="3"/></filter>')
        body = circ(C, C, 88, mix(col, "#FFFFFF", 0.35), extra='filter="url(#bl)" opacity="0.85"')
        body += circ(C, C, 84, "none", "url(#gd)", 9) + circ(C, C, 84, "none", S["gold_dk"], 1.2, 'opacity="0.5"')
        body += circ(C, C, 79, "url(#gm)")
        body += circ(C, C, 66, "none", "#FFFFFF", 1.6, 'opacity="0.35"')
        body += vp.at(fn(pal_b(col)), 0.66)
        body += g(ell(0, 0, 44, 20, "url(#gl)"), "translate(98 76) rotate(-32)") + circ(160, 176, 9, "#FFFFFF", extra='opacity="0.35" filter="url(#b2)"')
        for a in (0, 90, 180, 270):
            x, y = pol(C, C, 84, a)
            body += circ(x, y, 6.5, "#FFFDF4", S["gold_dk"], 1.5) + circ(x - 1.6, y - 1.6, 2, "#FFFFFF")
        x, y = pol(C, C, 86, 45)
        body += g(star4(x, y, 26, "#FFFFFF"), extra='filter="url(#b2)" opacity="0.9"') + star4(x, y, 22, "#FFFFFF", S["gold_lt"], 1.5)
        body += path(arc_d(C, C, 102, 0, 360 * frac - 0.01), "none", "#FFFFFF", 6, 'filter="url(#b2)" opacity="0.9"') + path(
            arc_d(C, C, 102, 0, 360 * frac - 0.01), "none", "#FFF3C4", 3.5)
    else:
        fn, _ = DEB_FN[tag]
        glow = GLOW[tag]
        rng = random.Random(hash(tag) % 97)
        defs = (f'<radialGradient id="gm" cx="0.5" cy="0.82" r="0.9"><stop offset="0" stop-color="{mix(glow, "#000000", 0.45)}"/><stop offset="0.5" stop-color="#1A1016"/>'
                '<stop offset="1" stop-color="#050305"/></radialGradient>'
                '<filter id="bl" x="-40%" y="-40%" width="180%" height="180%"><feGaussianBlur stdDeviation="10"/></filter>'
                '<filter id="b2" x="-40%" y="-40%" width="180%" height="180%"><feGaussianBlur stdDeviation="2.5"/></filter>')
        pts = vp.chipped_pts(7, 80)
        body = circ(C, C, 84, glow, extra='filter="url(#bl)" opacity="0.5"')
        spikes = ""
        for i in range(9):
            a = i * 40 + rng.uniform(-9, 9)
            L = rng.uniform(12, 30)
            spikes += path(pts_d([pol(C, C, 80, a - 7), pol(C, C, 84 + L, a + rng.uniform(-6, 6)), pol(C, C, 80, a + 7)], True), "#16101A", "#2E2630", 2)
        body += spikes + path(pts_d(vp.chipped_pts(7, 87), True), "#16101A", "#3A3038", 3)
        body += path(pts_d(pts, True), "url(#gm)")
        crack = vp.cracks(5 + len(tag), 5, glow, 2.2, 76)
        body += g(crack, extra='filter="url(#b2)" opacity="0.9"') + g(vp.cracks(5 + len(tag), 5, mix(glow, "#FFFFFF", 0.5), 1, 76))
        body += vp.at(fn(S), 0.66)
        body += path(arc_d(C, C, 60, -60, -20), "none", "#FFFFFF", 5, 'opacity="0.18"')
        body += path(arc_d(C, C, 104, 0, 360 * frac - 0.01), "none", glow, 6, 'filter="url(#b2)" opacity="0.8"') + path(
            arc_d(C, C, 104, 0, 360 * frac - 0.01), "none", H["bone"], 3)
    add(f"b_med_{tag}", 256, 256, body, defs)


def b_rose(cx, cy, r, state, venom=False):
    """state: 'full', 'lag', 'empty'. A rose-cut gem in a gold claw setting."""
    if state == "empty":
        return circ(cx, cy, r * 0.82, "rgba(255,255,255,0.16)", S["gold"], 2.6) + circ(cx, cy, r * 0.3, "none", S["gold"], 1.8, 'opacity="0.7"')
    fill, inner, ink = ("url(#rg)", "url(#ri)", "#C2356E") if state == "full" else ("url(#pg)", "#FFFFFF", "#D9B8C6")
    if venom and state == "full":
        fill, inner, ink = "url(#vg)", "#5A6A2A", "#0C0A0C"
    out = circ(cx, cy, r * 1.08, "#FF9CC4" if not venom else "#7E9A2A", extra='filter="url(#rb)" opacity="0.75"') if state == "full" else ""
    out += rose(cx, cy, r, fill, inner, ink, 2.6)
    out += g(ell(0, 0, r * 0.5, r * 0.2, "url(#gl)"), f"translate({f(cx - r * 0.36)} {f(cy - r * 0.5)}) rotate(-30)")
    return out


def b_health(name, hp, lag=None, notch=None, venom=False):
    defs = ('<radialGradient id="rg" cx="0.35" cy="0.3" r="0.9"><stop offset="0" stop-color="#FFE1EC"/><stop offset="0.5" stop-color="#F57AA8"/><stop offset="1" stop-color="#C73A78"/></radialGradient>'
            '<radialGradient id="ri" cx="0.4" cy="0.35" r="0.8"><stop offset="0" stop-color="#FFF3F7"/><stop offset="1" stop-color="#F9A6C4"/></radialGradient>'
            '<radialGradient id="pg" cx="0.35" cy="0.3" r="0.9"><stop offset="0" stop-color="#FFFFFF" stop-opacity="0.95"/><stop offset="1" stop-color="#F6E2EA" stop-opacity="0.8"/></radialGradient>'
            '<radialGradient id="vg" cx="0.35" cy="0.3" r="0.9"><stop offset="0" stop-color="#C6CF8A"/><stop offset="0.5" stop-color="#8E3A62"/><stop offset="1" stop-color="#2A1024"/></radialGradient>'
            '<radialGradient id="gl" cx="0.5" cy="0.5" r="0.5"><stop offset="0" stop-color="#FFF" stop-opacity="0.95"/><stop offset="1" stop-color="#FFF" stop-opacity="0"/></radialGradient>'
            '<filter id="rb" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="8"/></filter>')
    vine_col = S["gold"] if not venom else "#1A1016"
    body = path("M40 78 Q110 96 180 74 T330 76 T480 74 T660 70", "none", S["gold_dk"] if not venom else "#000", 5.5) + path(
        "M40 78 Q110 96 180 74 T330 76 T480 74 T660 70", "none", vine_col, 3)
    for i in range(4):
        x = 150 + i * 130
        body += leaf(x, 80, 26, 9, 130 if i % 2 else 50, "#BFE8C9" if not venom else "#2A2A22", S["gold_dk"] if not venom else "#000", 2, False)
    for i in range(5):
        cx, cy = 86 + i * 130, 72
        lo = i * 20
        t = min(1.0, max(0.0, (hp - lo) / 20))
        tl = min(1.0, max(0.0, ((lag or hp) - lo) / 20))
        body += b_rose(cx, cy, 44, "empty")
        if tl > 0:
            body += f'<clipPath id="l{i}"><rect x="{cx - 60}" y="{cy - 60}" width="{f(120 * (0.12 + 0.76 * tl) if tl < 1 else 120)}" height="120"/></clipPath>'
            body += g(b_rose(cx, cy, 44, "lag"), extra=f'clip-path="url(#l{i})"')
        if t > 0:
            body += f'<clipPath id="c{i}"><rect x="{cx - 60}" y="{cy - 60}" width="{f(120 * (0.12 + 0.76 * t) if t < 1 else 120)}" height="120"/></clipPath>'
            body += g(b_rose(cx, cy, 44, "full", venom), extra=f'clip-path="url(#c{i})"')
            if venom:
                rng = random.Random(i)
                v = ""
                for k in range(4):
                    a = rng.uniform(0, 360)
                    pts = [pol(cx, cy, 46, a), pol(cx, cy, 30, a + rng.uniform(-20, 20)), pol(cx, cy, 14, a + rng.uniform(-50, 50))]
                    v += line(pts, "#050305", 2.6)
                body += g(v, extra=f'clip-path="url(#c{i})"')
    if notch:
        x = 86 + (notch / 20 - 0.5) * 130
        body += leaf(x, 132, 26, 9, 0, S["gold_lt"], S["gold_dk"], 2.4)
    add(name, 720, 144, body, defs)


def b_wheel(name, frac, petals=0, low=False):
    col0, col1 = ("#FFD9E6", "#F0669A") if not low else ("#FFD2C4", "#EE5A44")
    defs = (f'<radialGradient id="pg" cx="0.4" cy="0.3" r="0.9"><stop offset="0" stop-color="{col0}"/><stop offset="1" stop-color="{col1}"/></radialGradient>'
            '<radialGradient id="bg" cx="0.4" cy="0.3" r="0.9"><stop offset="0" stop-color="#FFFBE6"/><stop offset="1" stop-color="#F2C24A"/></radialGradient>'
            '<filter id="rb" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="6"/></filter>')
    K = 192
    drop = "M0 -30 Q20 -6 20 10 A20 20 0 0 1 -20 10 Q-20 -6 0 -30Z"
    body = circ(K, K, 74, "none", S["gold_dk"], 4) + circ(K, K, 74, "none", S["gold"], 2.2)
    n = 10
    for i in range(n):
        a = i * 36 + 18
        x, y = pol(K, K, 108, a)
        on = (i + 0.5) / n <= frac + 1e-6
        tf = f"translate({f(x)} {f(y)}) rotate({a + 180})"
        if on:
            body += g(path(drop, col1, extra='filter="url(#rb)" opacity="0.7"') + path(drop, "url(#pg)", "#FFFFFF", 1.4) + ell(-6, 6, 5, 9, "#FFFFFF", extra='opacity="0.7"'), tf)
        else:
            body += g(path(drop, "rgba(255,255,255,0.16)", S["gold"], 2.2), tf)
    for k in range(5):
        x, y = pol(K, K, 152, k * 72)
        if k < petals:
            body += circ(x, y, 13, "#F2C24A", extra='filter="url(#rb)" opacity="0.7"') + circ(x, y, 11, "url(#bg)", S["gold_dk"], 1.5) + circ(x - 3, y - 3, 3, "#FFFFFF")
    add(name, 384, 384, body, defs)


def b_tag(name):
    defs = ('<linearGradient id="gd" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#FFF6CC"/><stop offset="0.5" stop-color="#D4A94F"/><stop offset="1" stop-color="#FBE9A8"/></linearGradient>'
            '<radialGradient id="pe" cx="0.35" cy="0.3" r="0.9"><stop offset="0" stop-color="#FFFFFF"/><stop offset="1" stop-color="#EBD9F2"/></radialGradient>'
            '<radialGradient id="ge" cx="0.35" cy="0.3" r="0.9"><stop offset="0" stop-color="#E6ECFF"/><stop offset="1" stop-color="#6F86E8"/></radialGradient>'
            '<filter id="rb" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="7"/></filter>')
    d = "M128 40 Q196 44 196 120 Q196 196 128 232 Q60 196 60 120 Q60 44 128 40Z"
    body = path(d, "#C9B4F0", extra='filter="url(#rb)" opacity="0.7"') + path(d, "url(#pe)", "url(#gd)", 9)
    body += circ(128, 30, 11, "none", "url(#gd)", 6)
    body += vp.at(vp.s_cloak(mix(S["ink"], "#8A5AA8", 0.25), "#FFFFFF"), 0.46, 0, -2)
    body += circ(128, 214, 17, "#8FA2FF", extra='filter="url(#rb)" opacity="0.8"') + circ(128, 214, 14, "url(#ge)", "url(#gd)", 4) + circ(123, 209, 4, "#FFFFFF")
    add(name, 256, 256, body, defs)


# ------------------------------------------------------------------ C: painted

def rough(i, scale, freq="0.035", seed=3):
    return (f'<filter id="{i}" x="-30%" y="-30%" width="160%" height="160%"><feTurbulence type="fractalNoise" baseFrequency="{freq}" numOctaves="3" seed="{seed}" result="n"/>'
            f'<feDisplacementMap in="SourceGraphic" in2="n" scale="{scale}" xChannelSelector="R" yChannelSelector="G"/></filter>')


GRAIN = ('<filter id="gr" x="-30%" y="-30%" width="160%" height="160%"><feTurbulence type="fractalNoise" baseFrequency="0.035" numOctaves="3" seed="8" result="n"/>'
         '<feDisplacementMap in="SourceGraphic" in2="n" scale="26" xChannelSelector="R" yChannelSelector="G" result="d"/>'
         '<feTurbulence type="fractalNoise" baseFrequency="0.9" numOctaves="2" seed="4" result="g"/>'
         '<feColorMatrix in="g" type="matrix" values="0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  0 0 0 -1.1 1.25" result="ga"/>'
         '<feComposite in="d" in2="ga" operator="in"/></filter>')


def c_medallion(tag, frac=0.7):
    seed = sum(map(ord, tag)) % 40 + 1
    defs = rough("w1", 44, "0.028", seed) + rough("w2", 22, "0.05", seed + 5) + rough("wb", 5, "0.06", 2) + GRAIN.replace('seed="8"', f'seed="{seed}"') + (
        '<filter id="sf"><feGaussianBlur stdDeviation="2.2"/></filter><filter id="bleed" x="-40%" y="-40%" width="180%" height="180%"><feGaussianBlur stdDeviation="9"/></filter>')
    if tag in BUFF_FN:
        fn, key = BUFF_FN[tag]
        col = S[key] if key != "pearl" else "#F6D4E2"
        edge = mix(col, S["ink"], 0.32)
        body = g(circ(C, C, 84, col, extra='opacity="0.55"'), extra='filter="url(#w1)"')
        body += g(circ(C + 4, C + 2, 74, col, extra='opacity="0.9"'), extra='filter="url(#gr)"')
        body += g(circ(C, C, 82, "none", edge, 3, 'opacity="0.5"'), extra='filter="url(#w1)"')
        body += g(ell(104, 96, 34, 22, "#FFFFFF", extra='opacity="0.4"'), extra='filter="url(#sf)"')
        body += g(vp.at(fn(pal_c()), 0.7), extra='filter="url(#wb)"')
        ringc = S["ink"]
    else:
        fn, _ = DEB_FN[tag]
        glow = GLOW[tag]
        rng = random.Random(seed)
        body = g(circ(C, C, 86, mix(glow, "#000000", 0.35), extra='opacity="0.5"'), extra='filter="url(#bleed)"')
        blot = circ(C, C, 78, "#0B080C")
        for _ in range(7):
            a = rng.uniform(0, 360)
            x, y = pol(C, C, rng.uniform(84, 108), a)
            blot += circ(x, y, rng.uniform(3, 9), "#0B080C") + line([pol(C, C, 70, a), (x, y)], "#0B080C", rng.uniform(2, 5))
        for dx in (-34, 6, 40):
            L = rng.uniform(26, 58)
            blot += line([(C + dx, C + 60), (C + dx + rng.uniform(-2, 2), C + 70 + L)], "#0B080C", rng.uniform(6, 10))
            blot += circ(C + dx, C + 72 + L, rng.uniform(5, 8), "#0B080C")
        body += g(blot, extra='filter="url(#w2)"')
        body += g(circ(C + 6, C + 8, 56, mix(glow, "#000000", 0.55), extra='opacity="0.55"'), extra='filter="url(#bleed)"')
        body += g(vp.at(fn(S), 0.68), extra='filter="url(#wb)"')
        ringc = H["bone"]
    ring = path(arc_d(C, C, 104, 0, 360 * frac - 0.01), "none", ringc, 4)
    body += g(ring, extra='filter="url(#wb)"')
    add(f"c_med_{tag}", 256, 256, body, defs)


def c_health(name, hp, lag=None, notch=None, venom=False):
    x0, x1, y = 96, 676, 72
    xa = lambda t: x0 + (x1 - x0) * t / 100
    defs = (rough("dry", 16, "0.012 0.11", 7) + rough("wb", 4, "0.06", 2) + rough("w2", 26, "0.04", 9) +
            '<filter id="bleed" x="-20%" y="-60%" width="140%" height="220%"><feGaussianBlur stdDeviation="6"/></filter>'
            '<filter id="streak" x="-10%" y="-40%" width="120%" height="180%"><feTurbulence type="fractalNoise" baseFrequency="0.004 0.5" numOctaves="2" seed="5" result="n"/>'
            '<feColorMatrix in="n" type="matrix" values="0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  0 0 0 -1.3 1.7" result="a"/><feComposite in="SourceGraphic" in2="a" operator="in" result="s"/>'
            '<feTurbulence type="fractalNoise" baseFrequency="0.012 0.11" numOctaves="3" seed="7" result="m"/><feDisplacementMap in="s" in2="m" scale="16" xChannelSelector="R" yChannelSelector="G"/></filter>')
    ink = S["ink"]
    body = g(path(f"M{x0} {y + 22} Q{(x0 + x1) / 2} {y + 28} {x1} {y + 20} M{x1} {y + 8} V{y + 32}", "none", ink, 2.4, 'opacity="0.55"'), extra='filter="url(#wb)"')
    stroke_d = lambda xe: f"M{x0 - 4} {y - 4} Q{(x0 + xe) / 2} {y - 12} {xe} {y}"
    if lag:
        body += g(path(stroke_d(xa(lag)), "none", "#F8D9E4", 42, 'opacity="0.8"'), extra='filter="url(#dry)"')
    col = "#EE7AA6" if not venom else "#A8456F"
    body += g(path(stroke_d(xa(hp)), "none", col, 44), extra='filter="url(#streak)"')
    body += g(path(f"M{x0} {y - 12} Q{(x0 + xa(hp)) / 2} {y - 22} {xa(hp) - 16} {y - 10}", "none", "#FFFFFF", 5, 'opacity="0.5"'), extra='filter="url(#dry)"')
    body += g(path(f"M{x0} {y + 10} Q{(x0 + xa(hp)) / 2} {y + 4} {xa(hp) - 10} {y + 12}", "none", mix(col, ink, 0.4), 5, 'opacity="0.45"'), extra='filter="url(#dry)"')
    if venom:
        rng = random.Random(12)
        blk = ""
        for k in range(5):
            bx = xa(hp) - rng.uniform(0, (xa(hp) - x0) * 0.75)
            blk += ell(bx, y + rng.uniform(-8, 8), rng.uniform(16, 44), rng.uniform(7, 15), "#07050A")
            if k % 2 == 0:
                L = rng.uniform(20, 44)
                blk += line([(bx, y + 8), (bx + 1, y + 16 + L)], "#07050A", 6) + circ(bx + 1, y + 18 + L, 5, "#07050A")
        body += g(blk, extra='filter="url(#bleed)" opacity="0.5"') + g(blk, extra='filter="url(#w2)"')
        body += g(path(f"M{x0 + 30} {y} q40 -14 80 2 t90 -4 t70 6", "none", H["bile"], 2.5, 'opacity="0.8"'), extra='filter="url(#wb)"')
    r = g(rose(60, 70, 40, "rgba(248,150,184,0.85)" if not venom else "rgba(120,50,84,0.9)", "rgba(255,226,236,0.9)" if not venom else "rgba(60,30,50,0.9)", ink, 3.2)
          + leaf(60, 70, 44, 13, 228, "rgba(134,201,154,0.8)", ink, 2.6), extra='filter="url(#wb)"')
    body += r
    if notch:
        body += g(path(f"M{xa(notch)} {y - 26} v52", "none", S["gold"], 5) + leaf(xa(notch), y - 22, 26, 9, 20, "#F2D27A", S["gold_dk"], 2), extra='filter="url(#wb)"')
    add(name, 720, 144, body, defs)


def c_wheel(name, frac, petals=0, low=False):
    K = 192
    col = "#EE7AA6" if not low else "#EE6A4E"
    defs = rough("wb", 4, "0.06", 2) + ('<filter id="streak" x="-20%" y="-20%" width="140%" height="140%"><feTurbulence type="fractalNoise" baseFrequency="0.05" numOctaves="2" seed="5" result="n"/>'
                                         '<feColorMatrix in="n" type="matrix" values="0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  0 0 0 -1.1 1.6" result="a"/><feComposite in="SourceGraphic" in2="a" operator="in" result="s"/>'
                                         '<feTurbulence type="fractalNoise" baseFrequency="0.03" numOctaves="3" seed="7" result="m"/><feDisplacementMap in="s" in2="m" scale="14" xChannelSelector="R" yChannelSelector="G"/></filter>')
    body = g(circ(K, K, 126, "none", S["ink"], 2.2, 'opacity="0.5"') + circ(K, K, 98, "none", S["ink"], 1.6, 'opacity="0.35" stroke-dasharray="3 8"'), extra='filter="url(#wb)"')
    body += g(path(arc_d(K, K, 112, 0, 360 * frac), "none", col, 24), extra='filter="url(#streak)"')
    body += g(path(arc_d(K, K, 120, 6, 360 * frac - 12), "none", "#FFFFFF", 4, 'opacity="0.5"'), extra='filter="url(#wb)"')
    x, y = pol(K, K, 112, 0)
    body += g(circ(x, y, 15, col), extra='filter="url(#wb)"')
    for k in range(petals):
        px, py = pol(K, K, 132, k * 72)
        body += g(leaf(px, py, 46, 17, k * 72, "rgba(246,160,190,0.9)", S["ink"], 2.4), extra='filter="url(#wb)"')
    add(name, 384, 384, body, defs)


def c_tag(name):
    defs = rough("wb", 5, "0.06", 2) + rough("tear", 9, "0.08", 6)
    d = "M64 52 H192 V226 H64Z"
    body = g(path(d, "#FBF7EE", "#D9CDB8", 2), extra='filter="url(#tear)"')
    body += g(circ(128, 72, 8, "none", S["ink"], 2.4) + path("M128 64 Q110 30 128 14 Q146 30 128 64", "none", S["rose"], 6), extra='filter="url(#wb)"')
    body += g(circ(128, 150, 50, "rgba(169,184,245,0.6)"), extra='filter="url(#tear)"')
    body += g(vp.at(vp.s_cloak("none", S["ink"]).replace('fill="none"', f'fill="rgba(90,46,68,0.2)" stroke="{S["ink"]}" stroke-width="7"'), 0.5, 0, 22), extra='filter="url(#wb)"')
    add(name, 256, 256, body, defs)


# ------------------------------------------------------------------ boards

TAGS = ("steady", "well_rested", "warm", "heal", "venom", "drowsy", "roar_shake", "chilled")


def render(tmp):
    for t in TAGS:
        b_medallion(t)
        c_medallion(t)
    for d, health, wheel, tag in (("b", b_health, b_wheel, b_tag), ("c", c_health, c_wheel, c_tag)):
        health(f"{d}_health_hurt", 58, 71, 80)
        health(f"{d}_health_venom", 44, None, None, True)
        wheel(f"{d}_wheel", 0.6, 2)
        wheel(f"{d}_wheel_low", 0.3, 2, True)
        tag(f"{d}_tag")
    sd, pd = os.path.join(tmp, "svg"), os.path.join(tmp, "png")
    os.makedirs(sd)
    for n, s in OUT.items():
        open(os.path.join(sd, n + ".svg"), "w").write(s)
    subprocess.run(["node", os.path.join(HERE, "render_svgs.mjs"), sd, pd], check=True)
    return {n: Image.open(os.path.join(pd, n + ".png")).convert("RGBA") for n in OUT}


def night_plate():
    arr = np.asarray(ck.plate("spring_dusk.png"), dtype=np.float32) / 255
    arr = arr ** 1.25 * np.array([0.30, 0.36, 0.60])
    grey = arr.mean(axis=2, keepdims=True)
    arr = grey + (arr - grey) * 0.4
    noise = np.asarray(ck.load("edge/dread_noise").convert("L").resize((1024, 1024)), dtype=np.float32) / 255
    noise = np.tile(noise, (2, 2))[:1080, :1920]
    arr *= (1 - np.clip(ck.vignette((1920, 1080), 0.22, 1.25) * (0.5 + 0.7 * noise), 0, 1) * 0.94)[..., None]
    img = Image.fromarray((np.clip(arr, 0, 1) * 255).astype(np.uint8))
    return ck.lay(img, ck.reveal("edge/venom_veins", 0.36, 46), "#07060A", 0.96)


def chip(img, text, sub):
    d = ImageDraw.Draw(img)
    w = int(max(d.textlength(text, font=ck.font(34)), d.textlength(sub, font=ck.font(22, "MediumItalic")))) + 44
    d.rounded_rectangle((1920 - w - 30, 1080 - 108, 1920 - 30, 1080 - 24), 14, fill=S["paper"], outline=S["gold"], width=3)
    d.text((1920 - w - 8, 1080 - 104), text, font=ck.font(34), fill=S["ink"])
    d.text((1920 - w - 8, 1080 - 62), sub, font=ck.font(22, "MediumItalic"), fill=S["ink_soft"])


def hud(bg, A, d, night, feyre):
    out = bg.convert("RGBA")
    layer = Image.new("RGBA", out.size, (0, 0, 0, 0))
    ck.put(layer, A[f"{d}_health_{'venom' if night else 'hurt'}"], (44, 36), 360)
    names = ("venom", "drowsy") if night else ("steady", "well_rested")
    x = 52
    for n in names:
        ck.put(layer, A[f"{d}_med_{n}"], (x, 112), 76)
        x += 74
    if not night:
        ImageDraw.Draw(layer).ellipse((x + 6, 146, x + 14, 154), fill=S["gold"])
        ck.put(layer, A[f"{d}_tag"], (x + 20, 116), 64)
    ck.put(layer, A[f"{d}_wheel{'_low' if night else ''}"], feyre, 144)
    return Image.alpha_composite(out, layer).convert("RGB")


def strip(A, d, title, blurb):
    st = ck.paper(1920, 500)
    dr = ImageDraw.Draw(st)
    dr.text((40, 14), title, font=ck.font(50), fill=S["ink"])
    dr.text((44 + dr.textlength(title, font=ck.font(50)) + 20, 36), blurb, font=ck.font(26, "MediumItalic"), fill=S["ink_soft"])
    day = ck.plate("spring_day.png").crop((0, 0, 1920, 760)).resize((920, 400)).filter(ImageFilter.GaussianBlur(5))
    st.paste(day, (40, 86))
    dr.rounded_rectangle((980, 86, 1880, 486), 0, fill="#14111C")
    for x0, hl, wh, meds in ((40, "hurt", "", TAGS[:4]), (980, "venom", "_low", TAGS[4:])):
        ck.put(st, A[f"{d}_health_{hl}"], (x0 + 16, 100), 560)
        ck.put(st, A[f"{d}_wheel{wh}"], (x0 + 640, 96), 230)
        for i, n in enumerate(meds):
            ck.put(st, A[f"{d}_med_{n}"], (x0 + 14 + i * 150, 240), 160)
        if not wh:
            ck.put(st, A[f"{d}_tag"], (x0 + 690, 330), 150)
    return st.convert("RGB")


def main():
    out_dir = sys.argv[1]
    os.makedirs(out_dir, exist_ok=True)
    ck.ART = os.path.normpath(os.path.join(HERE, "..", "..", "..", "ui", "hud", "vitals", "art"))
    A = render(tempfile.mkdtemp(prefix="vitals_dir_"))
    day, night = ck.plate("spring_day.png"), night_plate()
    info = {"b": ("Direction B · Jewelled", "rose-cut gems, pearl and glow; health is five jewelled roses, stamina a ring of gem petals"),
            "c": ("Direction C · Painted", "Feyre's own brushwork; health is a stroke of rose paint, statuses are watercolour blots and ink")}
    nights = []
    for d in ("b", "c"):
        frame = hud(day, A, d, False, (1030, 520))
        board = Image.new("RGB", (1920, 1580))
        board.paste(frame, (0, 0))
        board.paste(strip(A, d, *info[d]), (0, 1080))
        board.save(os.path.join(out_dir, f"direction_{d}_{'jewelled' if d == 'b' else 'painted'}.jpg"), quality=92)
        n = hud(night, A, d, True, (1050, 500))
        chip(n, info[d][0], "night: dread 0.7, venom, drowsy")
        nights.append(n)
    both = Image.new("RGB", (1920, 2176), "#1A1620")
    both.paste(nights[0], (0, 0))
    both.paste(nights[1], (0, 1096))
    both.save(os.path.join(out_dir, "directions_night_horror_b_then_c.jpg"), quality=92)
    print("direction boards in", out_dir)


if __name__ == "__main__":
    main()
