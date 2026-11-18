#!/usr/bin/env python3
"""Look-dev only: direction D "Faelight glass". The owner's steer: borrow how
Genshin Impact and (a little) Zelda let the HUD sit on the play screen: thin,
translucent, white-glyph pieces at the screen's edges, health and buffs low
centre, stamina beside her, a pickup feed that slides in at the left, and
everything fading out when nothing is happening. The shapes and art are ours.

Run: python3 tools/ui/vitals/va_direction_d.py <out_dir>
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
from va_common import HORROR, SPRING, arc_d, circ, f, g, leaf, line, mix, path, pol, pts_d, star4, svg  # noqa: E402

S, H, C = SPRING, HORROR, 128
OUT = {}
BLUR = ('<filter id="b2" x="-40%" y="-40%" width="180%" height="180%"><feGaussianBlur stdDeviation="3"/></filter>'
        '<filter id="b9" x="-40%" y="-40%" width="180%" height="180%"><feGaussianBlur stdDeviation="10"/></filter>')


def pal_white():
    p = dict(S)
    for k in list(p):
        if k not in ("gold", "gold_dk", "gold_lt"):
            p[k] = "#FFFFFF"
    p.update({"ink": "rgba(52,28,64,0.62)", "wood": "#FFFFFF", "cake": "#FFFFFF", "deep": "#FFD0E0", "amber": "#FFE7A8", "coral": "#FFD2C4", "leaf": "#E4FFEA"})
    return p


def chip(tag, frac=0.7):
    if tag in vd.BUFF_FN:
        fn, key = vd.BUFF_FN[tag]
        col = S[key] if key != "pearl" else "#F6D4E2"
        defs = BLUR + (f'<radialGradient id="tg" cx="0.5" cy="0.85" r="0.9"><stop offset="0" stop-color="{col}" stop-opacity="0.85"/>'
                       f'<stop offset="0.7" stop-color="{mix(col, "#2A1838", 0.55)}" stop-opacity="0.62"/><stop offset="1" stop-color="#2A1838" stop-opacity="0.55"/></radialGradient>')
        body = circ(C, C, 92, "url(#tg)") + circ(C, C, 92, "none", "#FFFFFF", 2.5, 'opacity="0.55"')
        body += path(arc_d(C, C, 92, 0, 360 * frac - 0.01), "none", "#FFF3C4", 7, 'filter="url(#b2)" opacity="0.8"') + path(
            arc_d(C, C, 92, 0, 360 * frac - 0.01), "none", "#FFFFFF", 5)
        body += g(vp.at(fn(pal_white()), 0.7), extra='filter="url(#b2)" opacity="0.35"') + vp.at(fn(pal_white()), 0.7)
        x, y = pol(C, C, 92, 360 * frac)
        body += star4(x, y, 15, "#FFFFFF")
    else:
        fn, _ = vd.DEB_FN[tag]
        glow = vd.GLOW[tag]
        pts = vp.chipped_pts(7, 90)
        defs = BLUR + (f'<radialGradient id="tg" cx="0.5" cy="0.85" r="0.9"><stop offset="0" stop-color="{mix(glow, "#000000", 0.5)}" stop-opacity="0.92"/>'
                       '<stop offset="0.75" stop-color="#0A0609" stop-opacity="0.86"/><stop offset="1" stop-color="#050305" stop-opacity="0.86"/></radialGradient>')
        body = circ(C, C, 92, glow, extra='filter="url(#b9)" opacity="0.45"') + path(pts_d(pts, True), "url(#tg)")
        body += path(pts_d(pts, True), "none", glow, 2.5, 'opacity="0.75" stroke-dasharray="70 14 30 22 110 9"')
        body += vp.cracks(9 + len(tag), 4, glow, 1.8, 84)
        body += path(arc_d(C, C, 100, 0, 360 * frac - 0.01), "none", H["bone"], 4, 'opacity="0.9"')
        body += vp.at(fn(S), 0.7)
    OUT[f"d_chip_{tag}"] = svg(256, 256, body, defs)


def tag_chip():
    defs = BLUR + ('<radialGradient id="tg" cx="0.5" cy="0.85" r="0.9"><stop offset="0" stop-color="#A9B8F5" stop-opacity="0.8"/>'
                   '<stop offset="1" stop-color="#2A1838" stop-opacity="0.55"/></radialGradient>')
    d = "M128 30 L206 76 V180 L128 226 L50 180 V76Z"
    body = path(d, "url(#tg)", "#FFFFFF", 3, 'stroke-opacity="0.6"') + vp.at(vp.s_cloak("#FFFFFF", "rgba(52,28,64,0.6)"), 0.5, 0, -4)
    body += circ(128, 206, 15, "#A9B8F5", extra='filter="url(#b2)"') + circ(128, 206, 11, "#DDE4FF", "#FFFFFF", 2)
    OUT["d_tag"] = svg(256, 256, body, defs)


def health(name, hp, lag=None, notch=None, venom=False):
    x0, x1, y, h = 96, 860, 60, 20
    xa = lambda t: x0 + (x1 - x0) * t / 100
    c0, c1 = ("#FFC2DA", "#F0669A") if not venom else ("#B9C27A", "#7A2E55")
    defs = (BLUR +
                   f'<linearGradient id="hf" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{c0}"/><stop offset="1" stop-color="{c1}"/></linearGradient>'
                   '<radialGradient id="rg" cx="0.35" cy="0.3" r="0.9"><stop offset="0" stop-color="#FFE1EC"/><stop offset="0.5" stop-color="#F57AA8"/><stop offset="1" stop-color="#C73A78"/></radialGradient>'
                   '<radialGradient id="ri" cx="0.4" cy="0.35" r="0.8"><stop offset="0" stop-color="#FFF3F7"/><stop offset="1" stop-color="#F9A6C4"/></radialGradient>'
                   '<radialGradient id="vg" cx="0.35" cy="0.3" r="0.9"><stop offset="0" stop-color="#C6CF8A"/><stop offset="0.5" stop-color="#8E3A62"/><stop offset="1" stop-color="#2A1024"/></radialGradient>'
                   '<radialGradient id="gl" cx="0.5" cy="0.5" r="0.5"><stop offset="0" stop-color="#FFF" stop-opacity="0.95"/><stop offset="1" stop-color="#FFF" stop-opacity="0"/></radialGradient>'
                   '<filter id="rb" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="8"/></filter>')
    rr = lambda xe: f"M{x0} {y} H{f(xe - h / 2)} A{h / 2} {h / 2} 0 0 1 {f(xe - h / 2)} {y + h} H{x0}Z"
    body = path(f"M{x0 - 6} {y - 5} H{x1 - 10} A15 15 0 0 1 {x1 - 10} {y + h + 5} H{x0 - 6}Z", "rgba(34,20,46,0.52)", "#FFFFFF", 2, 'stroke-opacity="0.5"')
    if lag:
        body += path(rr(xa(lag)), "#FFF4F8", extra='opacity="0.85"')
    body += path(rr(xa(hp)), c1, extra='filter="url(#b2)" opacity="0.7"') + path(rr(xa(hp)), "url(#hf)")
    body += path(f"M{x0 + 30} {y + 5} H{f(xa(hp) - 16)}", "none", "#FFFFFF", 3, 'opacity="0.65"')
    if venom:
        rng = random.Random(3)
        v = ""
        for sy in (y + 5, y + 11, y + 16):
            pts = [(x0 + 20, sy)]
            while pts[-1][0] < xa(hp) - 12:
                pts.append((pts[-1][0] + rng.uniform(10, 22), min(y + h - 2, max(y + 2, pts[-1][1] + rng.uniform(-6, 6)))))
            v += line(pts, "#07050A", 2.6)
        body += v
    for t in (25, 50, 75):
        body += line([(xa(t), y + 2), (xa(t), y + h - 2)], "#FFFFFF", 1.6, 'opacity="0.35"')
    if notch:
        body += leaf(xa(notch), y - 4, 22, 8, 0, S["gold_lt"], S["gold_dk"], 2)
    body += vd.b_rose(70, y + h / 2, 38, "full", venom)
    OUT[name] = svg(900, 120, body, defs)


def wheel(name, frac, petals=0, low=False):
    K = 192
    c0, c1 = ("#FFE9A8", "#F58AB0") if not low else ("#FFC2A8", "#EE5A44")
    defs = BLUR + f'<linearGradient id="wf" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="{c0}"/><stop offset="1" stop-color="{c1}"/></linearGradient>'
    body = circ(K, K, 100, "none", "rgba(34,20,46,0.5)", 18) + circ(K, K, 110, "none", "#FFFFFF", 1.6, 'opacity="0.5"') + circ(K, K, 90, "none", "#FFFFFF", 1.6, 'opacity="0.5"')
    body += path(arc_d(K, K, 100, 0, 360 * frac), "none", c1, 14, 'filter="url(#b2)" opacity="0.7"') + path(arc_d(K, K, 100, 0, 360 * frac), "none", "url(#wf)", 12)
    for k in range(5):
        a0 = k * 72 + 8
        on = k < petals
        body += path(arc_d(K, K, 126, a0, a0 + 56), "none", "#FFE9A8" if on else "rgba(34,20,46,0.42)", 8)
        if on:
            body += path(arc_d(K, K, 126, a0, a0 + 56), "none", "#FFF6D8", 9, 'filter="url(#b2)" opacity="0.6"')
    x, y = pol(K, K, 100, 360 * frac)
    body += star4(x, y, 16, "#FFFFFF")
    OUT[name] = svg(384, 384, body, defs)


def render():
    for t in vd.TAGS:
        chip(t)
    tag_chip()
    health("d_health_hurt", 58, 71, 80)
    health("d_health_venom", 44, None, None, True)
    wheel("d_wheel", 0.6, 2)
    wheel("d_wheel_low", 0.3, 2, True)
    tmp = tempfile.mkdtemp(prefix="vitals_d_")
    sd, pd = os.path.join(tmp, "svg"), os.path.join(tmp, "png")
    os.makedirs(sd)
    for n, s in OUT.items():
        open(os.path.join(sd, n + ".svg"), "w").write(s)
    subprocess.run(["node", os.path.join(HERE, "render_svgs.mjs"), sd, pd], check=True)
    return {n: Image.open(os.path.join(pd, n + ".png")).convert("RGBA") for n in OUT}


def glass(layer, box, r=18, a=128):
    ImageDraw.Draw(layer).rounded_rectangle(box, r, fill=(34, 20, 46, a), outline=(255, 255, 255, 120), width=1)


def hud(bg, A, night, wheel_xy):
    out = bg.convert("RGBA")
    L = Image.new("RGBA", out.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(L)
    # Health low centre, buffs in a row just above it, the way an action RPG reads at a glance.
    hx, hy = 735, 962
    ck.put(L, A[f"d_health_{'venom' if night else 'hurt'}"], (hx, hy), 450)
    hp = "44 / 100" if night else "58 / 100"
    d.text((hx + 440 - d.textlength(hp, font=ck.font(20, "Medium")), hy + 46), hp, font=ck.font(20, "Medium"), fill=(255, 255, 255, 235),
           stroke_width=2, stroke_fill=(40, 24, 52, 200))
    names = ("venom", "drowsy") if night else ("steady", "well_rested")
    x = hx + 50
    for n in names:
        ck.put(L, A[f"d_chip_{n}"], (x, hy - 40), 48)
        x += 54
    if not night:
        ck.put(L, A["d_tag"], (x + 8, hy - 40), 48)
    ck.put(L, A[f"d_wheel{'_low' if night else ''}"], wheel_xy, 116)
    if not night:
        # Pickup feed: slides in at the left edge, stacks, fades after a few seconds.
        for i, (t, n) in enumerate((("Moonflower", "×2"), ("Bluebell", "×1"))):
            y = 520 + i * 52
            glass(L, (40, y, 330, y + 42), 21, 120 - i * 30)
            ck.put(L, A["d_chip_heal" if i == 0 else "d_chip_well_rested"], (46, y + 3), 36)
            d.text((94, y + 6), t, font=ck.font(26, "Medium"), fill=(255, 255, 255, 240 - i * 60))
            d.text((290, y + 6), n, font=ck.font(26, "Medium"), fill=(255, 243, 196, 240 - i * 60))
        # Contextual prompt by the thing she's facing.
        glass(L, (1010, 372, 1196, 414), 21, 130)
        d.ellipse((1016, 378, 1046, 408), fill=(255, 255, 255, 235))
        d.text((1024, 377), "E", font=ck.font(24), fill=S["ink"])
        d.text((1056, 378), "Touch stone", font=ck.font(24, "Medium"), fill=(255, 255, 255, 240))
    return Image.alpha_composite(out, L).convert("RGB")


def strip(A):
    st = ck.paper(1920, 560)
    dr = ImageDraw.Draw(st)
    title = "Direction D · Faelight glass"
    dr.text((40, 14), title, font=ck.font(50), fill=S["ink"])
    dr.text((44 + dr.textlength(title, font=ck.font(50)) + 20, 36), "thin translucent pieces, white glyphs, health and buffs low centre, stamina by her shoulder",
            font=ck.font(26, "MediumItalic"), fill=S["ink_soft"])
    day = ck.plate("spring_day.png").crop((0, 0, 1920, 760)).resize((920, 400)).filter(ImageFilter.GaussianBlur(5))
    st.paste(day, (40, 86))
    dr.rectangle((980, 86, 1880, 486), fill="#14111C")
    for x0, hl, wh, meds in ((40, "hurt", "", vd.TAGS[:4]), (980, "venom", "_low", vd.TAGS[4:])):
        ck.put(st, A[f"d_health_{hl}"], (x0 + 16, 110), 620)
        ck.put(st, A[f"d_wheel{wh}"], (x0 + 670, 96), 210)
        for i, n in enumerate(meds):
            ck.put(st, A[f"d_chip_{n}"], (x0 + 24 + i * 150, 250), 140)
        if not wh:
            ck.put(st, A["d_tag"], (x0 + 700, 320), 140)
    notes = ("Fades out when she's at full health and nothing is ticking  ·  buffs slide in above the bar and sweep down as they run out  ·  "
             "pickups stack at the left edge and fade  ·  stamina follows her shoulder")
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
    board.save(os.path.join(out_dir, "direction_d_faelight_glass.jpg"), quality=92)
    n = hud(vd.night_plate(), A, True, (1056, 510))
    vd.chip(n, "Direction D · Faelight glass", "night: dread 0.7, venom, drowsy")
    n.save(os.path.join(out_dir, "direction_d_night_horror.jpg"), quality=92)
    print("direction D in", out_dir)


if __name__ == "__main__":
    main()
