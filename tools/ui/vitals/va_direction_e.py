#!/usr/bin/env python3
"""Look-dev only: direction E "Feyre's hand". The owner liked the painted idea but
found it too fairytale-sweet for the story and for Feyre. This is the same idea
in her actual hand: a hunter who paints with scavenged pigment. Dry-brush and
palette-knife marks, charcoal, tally ticks, earth pigments; nothing symmetrical
or polished. Horror is tar smeared by fingers and claw-scratched through.
Laid out the direction-D way (low centre, light on the screen).

Run: python3 tools/ui/vitals/va_direction_e.py <out_dir>
"""
import os
import random
import subprocess
import sys
import tempfile

from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import va_checkpoint as ck  # noqa: E402
import va_directions as vd  # noqa: E402
import va_pictos as vp  # noqa: E402
from va_common import HORROR, SPRING, arc_d, circ, ell, f, g, line, mix, path, pol, pts_d, svg  # noqa: E402

S, H, C = SPRING, HORROR, 128
OUT = {}
CHAR = "#1F1A1C"
BONE = "#F1E9DA"
PIG = {"lilac": "#75679C", "mint": "#5C8870", "butter": "#C49A38", "blush": "#B9614F", "periwinkle": "#566F96", "rose": "#A8324A", "pearl": "#B7A68A"}


def fx(seed=3):
    return (vd.rough("wb", 6, "0.07", 2) + vd.rough("knife", 30, "0.014 0.08", seed) + vd.rough("smear", 38, "0.03", seed + 3) +
            '<filter id="dry" x="-20%" y="-40%" width="140%" height="180%"><feTurbulence type="fractalNoise" baseFrequency="0.006 0.42" numOctaves="2" seed="SEED" result="n"/>'
            '<feColorMatrix in="n" type="matrix" values="0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  0 0 0 -2.2 1.75" result="a"/><feComposite in="SourceGraphic" in2="a" operator="in" result="s"/>'
            '<feTurbulence type="fractalNoise" baseFrequency="0.014 0.08" numOctaves="3" seed="7" result="m"/><feDisplacementMap in="s" in2="m" scale="22" xChannelSelector="R" yChannelSelector="G"/></filter>'
            '<filter id="grit" x="-20%" y="-20%" width="140%" height="140%"><feTurbulence type="fractalNoise" baseFrequency="0.8" numOctaves="2" seed="4" result="g"/>'
            '<feColorMatrix in="g" type="matrix" values="0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  0 0 0 -1.6 1.45" result="ga"/><feComposite in="SourceGraphic" in2="ga" operator="in" result="s"/>'
            '<feTurbulence type="fractalNoise" baseFrequency="0.07" numOctaves="2" seed="2" result="m"/><feDisplacementMap in="s" in2="m" scale="5" xChannelSelector="R" yChannelSelector="G"/></filter>'
            '<filter id="bl" x="-40%" y="-40%" width="180%" height="180%"><feGaussianBlur stdDeviation="8"/></filter>').replace("SEED", str(seed))


def pal_sketch():
    p = dict(S)
    for k in list(p):
        p[k] = BONE
    p.update({"ink": CHAR, "deep": "#D9B3A6", "amber": "#E8C877", "coral": "#E0A088", "leaf": "#C9D2B4", "wood": "#CDB79A", "cake": "#E3CFA6",
              "gold": CHAR, "gold_dk": CHAR, "gold_lt": BONE})
    return p


def daub(tag, frac=0.7):
    seed = sum(map(ord, tag)) % 30 + 2
    rng = random.Random(seed)
    tilt = rng.uniform(-9, 9)
    if tag in vd.BUFF_FN:
        fn, key = vd.BUFF_FN[tag]
        col = PIG[key]
        body = g(path("M46 70 Q128 50 214 64 L206 196 Q128 214 50 194Z", mix(col, "#000000", 0.3), extra='opacity="0.85"'), f"rotate({tilt} 128 128)", 'filter="url(#knife)"')
        body += g(path("M52 62 Q128 46 208 58 L202 188 Q128 204 56 186Z", col), f"rotate({tilt} 128 128)", 'filter="url(#knife)"')
        body += g(path("M60 78 H196 M64 96 H190", "none", mix(col, "#FFFFFF", 0.45), 12, 'opacity="0.55"'), f"rotate({tilt} 128 128)", 'filter="url(#dry)"')
        body += g(vp.at(fn(pal_sketch()), 0.62), extra='filter="url(#grit)"')
        tick = CHAR
    else:
        fn, _ = vd.DEB_FN[tag]
        glow = vd.GLOW[tag]
        body = g(ell(C, C, 96, 84, mix(glow, "#000000", 0.4), extra='opacity="0.5"'), extra='filter="url(#bl)"')
        tar = path("M40 84 Q120 40 220 70 Q232 150 196 204 Q120 226 48 196 Q30 140 40 84Z", "#0A0709")
        for _ in range(4):  # finger drags
            x = rng.uniform(60, 190)
            tar += line([(x, 190), (x + rng.uniform(-14, 14), 226 + rng.uniform(0, 26))], "#0A0709", rng.uniform(9, 16))
        for _ in range(9):
            a, r = rng.uniform(0, 360), rng.uniform(100, 124)
            tar += circ(*pol(C, C, r, a), rng.uniform(2, 6), "#0A0709")
        body += g(tar, extra='filter="url(#smear)"')
        claws = ""
        for k in range(3):  # claw-scratched through the tar
            x0 = 66 + k * 30 + rng.uniform(-4, 4)
            claws += path(f"M{f(x0)} 52 Q{f(x0 + 46)} 120 {f(x0 + 70)} 212", "none", glow, rng.uniform(3.5, 6))
        body += g(claws, extra='filter="url(#wb)" opacity="0.55"')
        body += g(vp.at(fn(S), 0.62), extra='filter="url(#grit)"')
        tick = H["bone"]
    n = 6
    ticks = "".join(path(f"M{74 + i * 22} {232 + (i % 2) * 2} l5 -22", "none", tick, 5, 'opacity="%s"' % ("1" if i < round(frac * n) else "0.25")) for i in range(n))
    body += g(ticks, extra='filter="url(#wb)"')
    OUT[f"e_daub_{tag}"] = svg(256, 256, body, fx(seed))


def tag_scrap():
    body = g(path("M58 44 L200 52 L194 214 L64 208Z", "#E6DCC8", "#B9AD96", 2), extra='filter="url(#knife)"')
    body += g(path("M70 150 Q128 126 188 150 L184 196 Q128 208 74 196Z", PIG["periwinkle"], extra='opacity="0.9"'), extra='filter="url(#knife)"')
    sil = vp.s_cloak("none", CHAR).replace('fill="none"', f'fill="rgba(31,26,28,0.16)" stroke="{CHAR}" stroke-width="8"')
    body += g(vp.at(sil, 0.52, 0, 2), extra='filter="url(#grit)"')
    body += g(path("M128 50 Q118 22 134 8", "none", "#8C7B5E", 5), extra='filter="url(#wb)"')
    OUT["e_tag"] = svg(256, 256, body, fx(5))


def health(name, hp, lag=None, notch=None, venom=False):
    x0, x1, y = 70, 850, 64
    xa = lambda t: x0 + (x1 - x0) * t / 100
    col = "#B3243B" if not venom else "#6E2440"
    slash = lambda xe, w0: (f"M{x0 - 8} {y + 6} Q{(x0 + xe) / 2} {y - 16} {xe} {y - 4} L{xe + 22} {y - 10} L{xe + 4} {y + 8} "
                            f"Q{(x0 + xe) / 2} {y + w0 - 10} {x0 - 6} {y + w0}Z")
    rule = f"M{x0 - 4} {y + 34} Q{(x0 + x1) / 2} {y + 40} {x1} {y + 32}"
    body = g(path(rule, "none", "#FFFFFF", 7, 'opacity="0.35"') + path(rule, "none", CHAR, 3.2), extra='filter="url(#wb)"')
    ticks = "".join(path(f"M{xa(t)} {y + 24} l-5 20", "none", CHAR, 3.2) for t in (0, 25, 50, 75, 100))
    body += g(ticks, extra='filter="url(#wb)"')
    if lag:
        body += g(path(slash(xa(lag), 30), "#E7B9B4", extra='opacity="0.75"'), extra='filter="url(#dry)"')
    body += g(path(slash(xa(hp), 34), mix(col, "#000000", 0.35)), "translate(0 3)", 'filter="url(#knife)" opacity="0.8"')
    body += g(path(slash(xa(hp), 32), col), extra='filter="url(#dry)"')
    body += g(path(f"M{x0 + 10} {y} Q{(x0 + xa(hp)) / 2} {y - 14} {xa(hp) - 30} {y - 2}", "none", "#E8788A", 7, 'opacity="0.7"'), extra='filter="url(#dry)"')
    if venom:
        rng = random.Random(8)
        tar = ""
        for k in range(5):
            bx = xa(hp) - rng.uniform(-6, (xa(hp) - x0) * 0.7)
            tar += ell(bx, y + rng.uniform(-4, 16), rng.uniform(18, 50), rng.uniform(8, 16), "#08060A")
            L = rng.uniform(16, 44)
            tar += line([(bx, y + 14), (bx + rng.uniform(-3, 3), y + 22 + L)], "#08060A", rng.uniform(5, 9))
        body += g(tar, extra='filter="url(#smear)"')
        body += g(path(f"M{x0 + 40} {y + 4} q50 -16 100 2 t110 -6", "none", "#8E9A3A", 5, 'opacity="0.8"'), extra='filter="url(#dry)"')
    if notch:
        body += g(path(f"M{xa(notch)} {y - 34} v30 m-9 -11 l9 11 l9 -11", "none", "#FFFFFF", 8, 'opacity="0.4"') + path(
            f"M{xa(notch)} {y - 34} v30 m-9 -11 l9 11 l9 -11", "none", CHAR, 4), extra='filter="url(#wb)"')
    OUT[name] = svg(900, 130, body, fx(6))


def wheel(name, frac, petals=0, low=False):
    K = 192
    col = "#C49A38" if not low else "#B3243B"
    body = g(circ(K, K, 118, "none", "#FFFFFF", 6, 'opacity="0.3"') + circ(K, K, 118, "none", CHAR, 3) + circ(K + 2, K - 2, 121, "none", CHAR, 1.6, 'opacity="0.6"'),
             extra='filter="url(#wb)"')
    body += g(path(arc_d(K, K, 100, 4, 360 * frac), "none", mix(col, "#000000", 0.3), 30), extra='filter="url(#knife)" opacity="0.8"')
    body += g(path(arc_d(K, K, 100, 0, 360 * frac), "none", col, 26), extra='filter="url(#dry)"')
    for k in range(petals):
        x, y = pol(K, K, 146, 14 + k * 16)
        body += g(path(f"M{f(x)} {f(y)} l8 -30", "none", CHAR, 5), extra='filter="url(#wb)"')
    OUT[name] = svg(384, 384, body, fx(4))


def render():
    for t in vd.TAGS:
        daub(t)
    tag_scrap()
    health("e_health_hurt", 58, 71, 80)
    health("e_health_venom", 44, None, None, True)
    wheel("e_wheel", 0.6, 2)
    wheel("e_wheel_low", 0.3, 2, True)
    tmp = tempfile.mkdtemp(prefix="vitals_e_")
    sd, pd = os.path.join(tmp, "svg"), os.path.join(tmp, "png")
    os.makedirs(sd)
    for n, s in OUT.items():
        open(os.path.join(sd, n + ".svg"), "w").write(s)
    subprocess.run(["node", os.path.join(HERE, "render_svgs.mjs"), sd, pd], check=True)
    return {n: Image.open(os.path.join(pd, n + ".png")).convert("RGBA") for n in OUT}


def hud(bg, A, night, wheel_xy):
    out = bg.convert("RGBA")
    L = Image.new("RGBA", out.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(L)
    hx, hy = 735, 950
    ck.put(L, A[f"e_health_{'venom' if night else 'hurt'}"], (hx, hy), 450)
    x = hx + 30
    for n in (("venom", "drowsy") if night else ("steady", "well_rested")):
        ck.put(L, A[f"e_daub_{n}"], (x, hy - 54), 60)
        x += 62
    if not night:
        ck.put(L, A["e_tag"], (x + 6, hy - 54), 56)
        for i, (t, n) in enumerate((("Moonflower", "×2"), ("Bluebell", "×1"))):
            y = 520 + i * 50
            scrap = Image.new("RGBA", (300, 44), (0, 0, 0, 0))
            ImageDraw.Draw(scrap).polygon([(2, 4), (296, 0), (298, 40), (0, 43)], fill=(230, 220, 200, 235 - i * 70))
            L.alpha_composite(scrap.rotate(-1.5 + i * 2.5, Image.BICUBIC, expand=True), (40, y))
            d.text((58, y + 6), t, font=ck.font(26, "MediumItalic"), fill=(31, 26, 28, 245 - i * 70))
            d.text((296, y + 6), n, font=ck.font(26, "MediumItalic"), fill=(168, 50, 74, 245 - i * 70))
    ck.put(L, A[f"e_wheel{'_low' if night else ''}"], wheel_xy, 112)
    return Image.alpha_composite(out, L).convert("RGB")


def strip(A):
    st = ck.paper(1920, 560)
    dr = ImageDraw.Draw(st)
    title = "Direction E · Feyre's hand"
    dr.text((40, 14), title, font=ck.font(50), fill=S["ink"])
    dr.text((44 + dr.textlength(title, font=ck.font(50)) + 20, 36), "the painted idea, but hers: dry-brush, palette knife, charcoal, earth pigment; nothing polished",
            font=ck.font(26, "MediumItalic"), fill=S["ink_soft"])
    day = ck.plate("spring_day.png").crop((0, 0, 1920, 760)).resize((920, 400)).filter(ImageFilter.GaussianBlur(5))
    st.paste(day, (40, 86))
    dr.rectangle((980, 86, 1880, 486), fill="#14111C")
    for x0, hl, wh, meds in ((40, "hurt", "", vd.TAGS[:4]), (980, "venom", "_low", vd.TAGS[4:])):
        ck.put(st, A[f"e_health_{hl}"], (x0 + 16, 100), 620)
        ck.put(st, A[f"e_wheel{wh}"], (x0 + 670, 96), 210)
        for i, n in enumerate(meds):
            ck.put(st, A[f"e_daub_{n}"], (x0 + 20 + i * 150, 236), 160)
        if not wh:
            ck.put(st, A["e_tag"], (x0 + 700, 320), 140)
    notes = ("Health is one slash of madder over a charcoal rule with tally ticks  ·  each status is a knife-daub that wears away tick by tick  ·  "
             "horror is tar dragged by fingers and clawed through")
    dr.text((40, 502), notes, font=ck.font(24, "Medium"), fill=S["ink"])
    return st.convert("RGB")


def main():
    out_dir = sys.argv[1]
    os.makedirs(out_dir, exist_ok=True)
    ck.ART = os.path.normpath(os.path.join(HERE, "..", "..", "..", "ui", "hud", "vitals", "art"))
    A = render()
    board = Image.new("RGB", (1920, 1640))
    board.paste(hud(ck.plate("spring_day.png"), A, False, (1040, 530)), (0, 0))
    board.paste(strip(A), (0, 1080))
    board.save(os.path.join(out_dir, "direction_e_feyres_hand.jpg"), quality=92)
    n = hud(vd.night_plate(), A, True, (1056, 510))
    vd.chip(n, "Direction E · Feyre's hand", "night: dread 0.7, venom, drowsy")
    n.save(os.path.join(out_dir, "direction_e_night_horror.jpg"), quality=92)
    print("direction E in", out_dir)


if __name__ == "__main__":
    main()
