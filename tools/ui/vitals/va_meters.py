"""Meters (plan §15 A): the stamina rose wheel, the health ribbon, the grab prompt."""
import math
import random

from va_common import (HORROR, HUMAN, SPRING, arc_d, bezier_pts, circ, f, g, gold_circle, gold_line, leaf, line, mix,
                       path, pol, pts_d, rose, star4, svg, thorn_vine)

H = HORROR
K = 192  # centre of the 384 wheel canvas (ring is 96 px on screen, petals reach 135 px)


def add(out, name, w, h, body, defs="", half=False):
    out[name] = {"w": w, "h": h, "svg": svg(w, h, body, defs), "half": half}


PETAL_D = None


def petal_d():
    a = pol(K, K, 139, -27)
    b = pol(K, K, 139, 27)
    top = pol(K, K, 196, 0)
    low = pol(K, K, 150, 0)
    return f"M{f(a[0])} {f(a[1])} Q{f(top[0])} {f(top[1])} {f(b[0])} {f(b[1])} Q{f(low[0])} {f(low[1])} {f(a[0])} {f(a[1])}Z"


def wheel(out):
    add(out, "wheel/wheel_back", 384, 384, circ(K, K, 113, "none", SPRING["ink"], 22, 'opacity="0.42"'))
    add(out, "wheel/wheel_fill", 384, 384, circ(K, K, 113, "none", "#FFFFFF", 20))
    add(out, "wheel/wheel_gloss", 384, 384, path(arc_d(K, K, 118, -70, -12), "none", "#FFFFFF", 5, 'opacity="0.7"') + circ(
        *pol(K, K, 118, 0), 2.6, "#FFFFFF", extra='opacity="0.7"'))
    for skin, p in (("spring", SPRING), ("human", HUMAN)):
        if skin == "spring":
            body = gold_circle(K, K, 127, p, 6) + gold_circle(K, K, 99, p, 4.5)
            for k in range(5):
                a = 36 + 72 * k
                x, y = pol(K, K, 128, a)
                body += leaf(x, y, 24, 8, a + 70, p["leaf"], p["gold_dk"], 2.5, False) + leaf(x, y, 24, 8, a - 70 + 180, p["leaf"], p["gold_dk"], 2.5, False)
                body += rose(x, y, 14, p["rose"], p["blush"], p["gold_dk"], 2.6)
            for k in range(5):
                x, y = pol(K, K, 99, 72 * k)
                body += circ(x, y, 4.5, p["gold_lt"], p["gold_dk"], 2)
        else:
            body = ""
            for dx, dy, sw in ((0, 0, 5), (1.6, -1.2, 2)):
                body += circ(K + dx, K + dy, 127, "none", p["ink"], sw) + circ(K - dx, K + dy, 99, "none", p["ink"], sw * 0.8)
            for k in range(5):
                a = 36 + 72 * k
                x, y = pol(K, K, 127, a)
                body += g(path("M-11 -8 L11 8 M-11 8 L11 -8 M-13 0 H13", "none", p["ink"], 8) + path("M-11 -8 L11 8 M-11 8 L11 -8 M-13 0 H13", "none", p["butter"], 4.5),
                          f"translate({f(x)} {f(y)}) rotate({a})")
        add(out, f"wheel/wheel_frame_{skin}", 384, 384, body)
        pd = petal_d()
        if skin == "spring":
            body = path(pd, "none", p["gold_dk"], 7) + path(pd, "none", p["gold"], 4)
        else:
            body = path(pd, "none", p["ink"], 4.5)
        add(out, f"wheel/petal_frame_{skin}", 384, 384, body)
    pd = petal_d()
    add(out, "wheel/petal_fill", 384, 384, path(pd, "#FFFFFF") + path(arc_d(K, K, 160, -14, 4), "none", "#FFFFFF", 4))
    # Winded: the petal ring cracks.
    rng = random.Random(9)
    ink = "#3A2A36"
    body = ""
    for a in (14, 63, 121, 178, 236, 291, 338):
        pts = []
        for i in range(5):
            r = 101 + i * 6
            pts.append(pol(K, K, r, a + rng.uniform(-5, 5)))
        body += line(pts, ink, 3.2)
        mid = pts[2]
        body += line([mid, pol(K, K, 113 + rng.uniform(-8, 8), a + rng.choice((-9, 9)))], ink, 2.2)
    for a in (96, 262):
        x, y = pol(K, K, 124, a)
        body += path(pts_d([(x - 7, y - 5), (x + 6, y - 7), (x + 2, y + 8)], True), ink)
    add(out, "wheel/wheel_winded_cracks", 384, 384, body)
    # Growth bloom: a new petal unfurls with a sparkle. 6 frames, petal at the top.
    p = SPRING
    body = ""
    scales = (0.2, 0.7, 1.22, 1.08, 0.97, 1.0)
    for i, s in enumerate(scales):
        t = i / 5
        ox, oy = pol(K, K, 150, 0)
        fr = g(path(pd, p["rose"], p["gold_dk"], 7 / s) + path(pd, "none", p["gold"], 4 / s), f"translate({f(ox)} {f(oy)}) scale({s}) translate({f(-ox)} {f(-oy)})")
        for k in range(6):
            a = -60 + k * 24
            x, y = pol(ox, oy + 10, 24 + 62 * t ** 0.6, a)
            R = (20 if k % 2 else 12) * math.sin(math.pi * min(1, t + 0.08)) + 0.5
            fr += star4(x, y, R, "#FFFFFF" if k % 2 else p["butter"], p["gold"], 2, rot=a)
        body += g(fr, f"translate({i * 384} 0)")
    add(out, "wheel/petal_bloom_sheet", 384 * 6, 384, body)


# ---------------------------------------------------------------- health ribbon (720 x 112, shown 360 x 56)
BAR = (70, 40, 588, 32, 16)  # x, y, w, h, radius of the fill


def rrect(x, y, w, h, r):
    return f"M{x + r} {y} H{x + w - r} A{r} {r} 0 0 1 {x + w - r} {y + h} H{x + r} A{r} {r} 0 0 1 {x + r} {y}Z"


def sprig(p, col, edge, leafcol, flip=1):
    pts = bezier_pts((660, 56), (684, 56), (694, 40), (712, 16), 12)
    out = thorn_vine(pts, 5, col, edge, 3, 2.6, sw=2.2, flip=flip)
    out += leaf(686, 56, 26, 9, 118, leafcol, edge, 2.5, False)
    out += path("M676 58 Q694 70 704 88", "none", edge, 6.5) + path("M676 58 Q694 70 704 88", "none", col, 3.5)
    out += path(pts_d([(694, 74), (706, 70), (698, 80)], True), col, edge, 2)
    return out


def ribbon(out):
    x, y, w, h, r = BAR
    add(out, "ribbon/ribbon_back", 720, 112, path(rrect(x - 3, y - 3, w + 6, h + 6, r + 3), SPRING["ink"], extra='opacity="0.5"'))
    add(out, "ribbon/ribbon_fill", 720, 112, path(rrect(x, y, w, h, r), "#FFFFFF"))
    add(out, "ribbon/ribbon_gloss", 720, 112, path(rrect(x + 14, y + 4, w - 28, 6, 3), "#FFFFFF", extra='opacity="0.5"'))
    defs = '<filter id="fl" x="-10%" y="-80%" width="120%" height="260%"><feGaussianBlur stdDeviation="7"/></filter>'
    add(out, "ribbon/ribbon_hit_flash", 720, 112, path(rrect(x - 4, y - 4, w + 8, h + 8, r + 4), "#FFFFFF", extra='filter="url(#fl)"') + path(
        rrect(x, y, w, h, r), "#FFFFFF"), defs)
    defs = ('<linearGradient id="sh" x1="0" x2="1"><stop offset="0" stop-color="#FFF" stop-opacity="0"/><stop offset="0.5" stop-color="#FFF" stop-opacity="0.92"/>'
            '<stop offset="1" stop-color="#FFF" stop-opacity="0"/></linearGradient>')
    add(out, "ribbon/ribbon_heal_sheen", 160, 112, path("M50 36 H150 L110 76 H10Z", "url(#sh)"), defs)
    p = SPRING
    add(out, "ribbon/regen_notch", 48, 64, path("M24 30 V60", "none", p["gold_dk"], 5) + path("M24 30 V60", "none", p["gold"], 2.5) + leaf(
        24, 34, 30, 11, 0, p["gold_lt"], p["gold_dk"], 3, True))

    frame_d = rrect(x - 6, y - 6, w + 12, h + 12, r + 6)
    for skin, p in (("spring", SPRING), ("human", HUMAN)):
        if skin == "spring":
            body = gold_line(frame_d, p, 5.5)
            for fx in (0.25, 0.5, 0.75):
                cx = x + w * fx
                body += star4(cx, y - 6, 7, p["gold_lt"], p["gold_dk"], 1.6) + star4(cx, y + h + 6, 7, p["gold_lt"], p["gold_dk"], 1.6)
            body += sprig(p, p["gold"], p["gold_dk"], p["leaf"])
            body += leaf(52, 56, 44, 14, -50, p["leaf"], p["gold_dk"], 3) + leaf(52, 56, 44, 14, 230, p["leaf"], p["gold_dk"], 3)
            body += rose(52, 56, 37, p["rose"], p["blush"], p["ink"], 3.6)
        else:
            body = path(frame_d, "none", p["ink"], 5) + path(rrect(x - 8, y - 5, w + 14, h + 11, r + 6), "none", p["ink"], 1.6, 'opacity="0.7"')
            for ex in (88, 620):
                for k in range(4):
                    body += line([(ex + k * 9 - 6, y - 8), (ex + k * 9 + 6, y + h + 8)], p["ink"], 6.5) + line(
                        [(ex + k * 9 - 6, y - 8), (ex + k * 9 + 6, y + h + 8)], p["butter"], 3.5)
            body += sprig(p, p["ink_soft"], p["ink"], p["leaf"])
            body += leaf(52, 56, 44, 14, -50, p["leaf"], p["ink"], 3) + leaf(52, 56, 44, 14, 230, p["leaf"], p["ink"], 3)
            body += rose(52, 56, 37, p["rose"], p["blush"], p["ink"], 3.6)
        add(out, f"ribbon/ribbon_frame_{skin}", 720, 112, body)

    # Low health: the gold tarnishes, the thorns go to ink and climb the rod. Horror.
    p = SPRING
    tar = mix(p["gold"], H["tarnish"], 0.72)
    body = path(frame_d, "none", H["ichor"], 8.5) + path(frame_d, "none", tar, 5.5)
    body += path(frame_d, "none", H["verdigris"], 5.5, 'stroke-dasharray="26 90 12 140 40 70"')
    body += path(frame_d, "none", H["ichor"], 5.5, 'stroke-dasharray="6 61 3 97 9 44" opacity="0.8"')
    rng = random.Random(4)
    pts = [(96 + i * 14, 56 + 27 * math.sin(i * 0.52 + 0.4) + rng.uniform(-2, 2)) for i in range(41)]
    body += thorn_vine(pts, 4.2, "#2A1420", H["ichor"], 2, 2.9, rng, 1.6)
    body += sprig(p, "#2A1420", H["ichor"], "#3A2A2E")
    body += leaf(52, 56, 44, 14, -50, "#4A3A3A", H["ichor"], 3) + leaf(52, 56, 44, 14, 230, "#4A3A3A", H["ichor"], 3)
    body += rose(52, 56, 37, "#7A2E45", "#4A1626", H["ichor"], 3.6)
    body += path("M30 96 Q40 88 48 98 Q38 106 30 96Z", "#7A2E45", H["ichor"], 2.5)
    add(out, "ribbon/ribbon_frame_low", 720, 112, body)

    # Venom: black-green veins crossing the fill. Horror.
    rng = random.Random(17)
    veins = ""

    def vein(px, py, ang, ln, wd, depth):
        nonlocal veins
        pts = [(px, py)]
        steps = int(ln / 9)
        for i in range(steps):
            ang += rng.uniform(-0.45, 0.45)
            ang *= 0.9
            px, py = px + math.cos(ang) * 9, py + math.sin(ang) * 9
            py = min(max(py, y + 1), y + h - 1)
            pts.append((px, py))
            if depth > 0 and rng.random() < 0.2:
                vein(px, py, ang + rng.choice((-1, 1)) * rng.uniform(0.5, 1.1), ln * 0.3, wd * 0.6, depth - 1)
        veins += line(pts, mix(H["bile"], "#000000", 0.35), wd + 2.4, 'opacity="0.75"') + line(pts, H["ichor"], wd)

    for sy in (47, 56, 65):
        vein(x, sy + rng.uniform(-2, 2), 0.0, w + 10, 2.6, 2)
    defs = f'<clipPath id="vc"><path d="{rrect(x, y, w, h, r)}"/></clipPath>'
    add(out, "ribbon/ribbon_venom_veins", 720, 112, g(veins, extra='clip-path="url(#vc)"'), defs)


def grab(out):
    """A3: a thorn-vine ring that loosens a step with each press. Bone on ichor; the game tints it."""
    body = ""
    for s in range(6):
        rng = random.Random(40 + s)
        R = 82 + s * 4.5
        gap = (0, 5, 12, 21, 31, 43)[s]
        fr = ""
        for strand in (0, 1):
            for k in range(6):
                a0 = k * 60 + gap / 2 + s * 7
                a1 = (k + 1) * 60 - gap / 2 + s * 7
                if s == 5 and k % 2 == strand:
                    continue
                n = 14
                pts = []
                for i in range(n + 1):
                    a = a0 + (a1 - a0) * i / n
                    rr = R + (5.5 if strand else -5.5) * math.sin(math.radians(a * 6)) + 0
                    pts.append(pol(120, 120, rr, a))
                fr += thorn_vine(pts, 5.5 - s * 0.35, H["bone"], H["ichor"], 3 + (s // 2), 2.7, rng, 2.4, flip=1 if strand else -1)
        body += g(fr, f"translate({s * 240} 0)")
    add(out, "grab/grab_ring_sheet", 240 * 6, 240, body)


def build(out):
    wheel(out)
    ribbon(out)
    grab(out)
