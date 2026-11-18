"""Shared palette and SVG helpers for the vitals HUD art (plan §15).

Everything in ui/hud/vitals/art/ is drawn as SVG here and rasterised by
render_svgs.mjs (headless Chromium), so the art is reproducible from this
folder: python3 tools/ui/vitals/build_vitals_art.py
"""
import math
import random

# Spring skin: AcotarPalette.SPRING ink and line, plus the R3 candy enamels.
SPRING = {
    "ink": "#5A2E44", "ink_soft": "#8E6A6E", "paper": "#FBF7EE",
    "gold": "#D4A94F", "gold_dk": "#A47A2B", "gold_lt": "#F8E6A8",
    "rose": "#F28FB1", "blush": "#FBC7D4", "lilac": "#CDB4F0",
    "periwinkle": "#A9B8F5", "mint": "#A8E6CF", "butter": "#FCE9A6",
    "pearl": "#FBF3EA", "white": "#FFFFFF", "leaf": "#86C99A",
    "coral": "#F27C6B", "deep": "#D9558A", "sky": "#8FD3F0", "amber": "#F2B544",
}
# Human-realm skin: AcotarPalette.HUMAN charcoal and paper, twine, muted madder and ochre.
HUMAN = {
    "ink": "#2B2A33", "ink_soft": "#5E6670", "paper": "#E9E4DA",
    "gold": "#8C7B5E", "gold_dk": "#4A4640", "gold_lt": "#C9BFA8",
    "rose": "#A85454", "blush": "#C9A59C", "lilac": "#8E7AA8",
    "periwinkle": "#8792A6", "mint": "#93A68E", "butter": "#C9A040",
    "pearl": "#E9E4DA", "white": "#F3EFE6", "leaf": "#74845C",
    "coral": "#A8482F", "deep": "#8E2A2A", "sky": "#9DB3C4", "amber": "#C9A040",
}
# Horror palette (plan §14.1). Never cute, never sparkly.
HORROR = {
    "ichor": "#120C10", "plum": "#3A1E2E", "bile": "#6F7F3A", "blood": "#7A1E2A",
    "bone": "#D8CFC0", "tarnish": "#5C4B3A", "verdigris": "#4E5E4A",
    "sick": "#B9BF8E", "ice": "#CFE4F2", "blueblack": "#141B2A", "dusk": "#2E2238",
    "crimson": "#A3202E",
}


def hex_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def mix(a, b, t):
    ra, rb = hex_rgb(a), hex_rgb(b)
    return "#%02X%02X%02X" % tuple(round(ra[i] + (rb[i] - ra[i]) * t) for i in range(3))


def f(v):
    return ("%.1f" % v).rstrip("0").rstrip(".")


def svg(w, h, body, defs=""):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" '
            f'viewBox="0 0 {w} {h}"><defs>{defs}</defs>{body}</svg>')


def g(body, tf="", extra=""):
    return f'<g transform="{tf}" {extra}>{body}</g>'


def path(d, fill="none", stroke=None, sw=8, extra=""):
    s = f'stroke="{stroke}" stroke-width="{f(sw)}" stroke-linecap="round" stroke-linejoin="round"' if stroke else ""
    return f'<path d="{d}" fill="{fill}" {s} {extra}/>'


def circ(cx, cy, r, fill="none", stroke=None, sw=8, extra=""):
    s = f'stroke="{stroke}" stroke-width="{f(sw)}"' if stroke else ""
    return f'<circle cx="{f(cx)}" cy="{f(cy)}" r="{f(r)}" fill="{fill}" {s} {extra}/>'


def ell(cx, cy, rx, ry, fill="none", stroke=None, sw=8, extra=""):
    s = f'stroke="{stroke}" stroke-width="{f(sw)}"' if stroke else ""
    return f'<ellipse cx="{f(cx)}" cy="{f(cy)}" rx="{f(rx)}" ry="{f(ry)}" fill="{fill}" {s} {extra}/>'


def pts_d(pts, close=False):
    d = "M" + " L".join(f"{f(x)} {f(y)}" for x, y in pts)
    return d + ("Z" if close else "")


def line(pts, stroke, sw=8, extra=""):
    return path(pts_d(pts), "none", stroke, sw, extra)


def pol(cx, cy, r, deg):
    a = math.radians(deg)
    return cx + r * math.sin(a), cy - r * math.cos(a)  # 0 deg = up, clockwise


def arc_d(cx, cy, r, a0, a1):
    """Clockwise arc from a0 to a1 degrees (0 = up)."""
    x0, y0 = pol(cx, cy, r, a0)
    x1, y1 = pol(cx, cy, r, a1)
    large = 1 if (a1 - a0) % 360 > 180 else 0
    return f"M{f(x0)} {f(y0)} A{f(r)} {f(r)} 0 {large} 1 {f(x1)} {f(y1)}"


def band_d(cx, cy, r0, r1, a0, a1):
    """Annulus sector between radii r0 < r1."""
    x0, y0 = pol(cx, cy, r1, a0)
    x1, y1 = pol(cx, cy, r1, a1)
    x2, y2 = pol(cx, cy, r0, a1)
    x3, y3 = pol(cx, cy, r0, a0)
    large = 1 if (a1 - a0) > 180 else 0
    return (f"M{f(x0)} {f(y0)} A{f(r1)} {f(r1)} 0 {large} 1 {f(x1)} {f(y1)} "
            f"L{f(x2)} {f(y2)} A{f(r0)} {f(r0)} 0 {large} 0 {f(x3)} {f(y3)}Z")


def star4(cx, cy, R, fill, stroke=None, sw=4, pinch=0.16, rot=0):
    """The four-point sparkle used everywhere (concave sides)."""
    k = R * pinch
    d = (f"M0 {-R} Q{k} {-k} {R} 0 Q{k} {k} 0 {R} Q{-k} {k} {-R} 0 Q{-k} {-k} 0 {-R}Z")
    return g(path(d, fill, stroke, sw), f"translate({f(cx)} {f(cy)}) rotate({rot})")


def star5(cx, cy, R, fill, stroke=None, sw=4, rot=0):
    p = []
    for i in range(10):
        r = R if i % 2 == 0 else R * 0.42
        p.append(pol(0, 0, r, i * 36))
    return g(path(pts_d(p, True), fill, stroke, sw), f"translate({f(cx)} {f(cy)}) rotate({rot})")


def gold_line(d, p, sw=6, extra=""):
    """Gold filigree stroke: a darker rim under the gold, then a thin light glint."""
    return (path(d, "none", p["gold_dk"], sw + 3, extra) + path(d, "none", p["gold"], sw, extra)
            + path(d, "none", p["gold_lt"], max(1.2, sw * 0.28), extra + ' opacity="0.9"'))


def gold_circle(cx, cy, r, p, sw=6):
    return (circ(cx, cy, r, "none", p["gold_dk"], sw + 3) + circ(cx, cy, r, "none", p["gold"], sw)
            + circ(cx, cy, r - sw * 0.2, "none", p["gold_lt"], max(1.2, sw * 0.25), 'opacity="0.9"'))


def leaf(cx, cy, ln, w, rot, fill, ink, sw=6, rib=True):
    d = f"M0 0 Q{f(w)} {f(-ln * 0.45)} 0 {f(-ln)} Q{f(-w)} {f(-ln * 0.45)} 0 0Z"
    body = path(d, fill, ink, sw)
    if rib:
        body += path(f"M0 {f(-ln * 0.12)} L0 {f(-ln * 0.8)}", "none", ink, sw * 0.6)
    return g(body, f"translate({f(cx)} {f(cy)}) rotate({rot})")


def rose(cx, cy, r, fill, inner, ink, sw=6):
    """A top-down rose: five lapped petals round a swirl."""
    out = ""
    for i in range(5):
        x, y = pol(cx, cy, r * 0.5, i * 72 + 12)
        out += circ(x, y, r * 0.56, fill, ink, sw)
    out += circ(cx, cy, r * 0.56, inner, ink, sw)
    s = r * 0.3
    out += path(f"M{f(cx - s)} {f(cy + s * 0.2)} Q{f(cx - s)} {f(cy - s)} {f(cx)} {f(cy - s)} "
                f"Q{f(cx + s)} {f(cy - s)} {f(cx + s * 0.8)} {f(cy)} Q{f(cx + s * 0.5)} {f(cy + s * 0.7)} "
                f"{f(cx)} {f(cy + s * 0.3)}", "none", ink, sw * 0.8)
    return out


def blob_lines(segs, fill, ink, w, sw=7):
    """Thick round-capped strokes with an ink outline: hands, twigs, gloves."""
    out = ""
    for pts in segs:
        out += line(pts, ink, w + sw * 2)
    for pts in segs:
        out += line(pts, fill, w)
    return out


def hand(fill, ink, crooked=False, sw=7):
    """An upright open hand in a 256 box (wrist at the bottom)."""
    if crooked:
        fingers = [[(96, 134), (70, 100), (76, 64)], [(116, 126), (104, 82), (116, 38)],
                   [(138, 126), (152, 82), (142, 40)], [(158, 134), (188, 102), (184, 66)],
                   [(94, 180), (60, 166), (42, 134)]]
    else:
        fingers = [[(96, 134), (80, 76)], [(116, 126), (110, 50)], [(138, 126), (144, 52)],
                   [(158, 134), (178, 80)], [(94, 180), (56, 146)]]
    palm = [[(106, 142), (150, 142)], [(106, 166), (150, 166)], [(114, 188), (144, 188)],
            [(128, 196), (128, 226)]]
    out = ""
    for pts in fingers:
        out += line(pts, ink, 15 + sw * 2)
    for pts in palm:
        out += line(pts, ink, 32 + sw * 2)
    for pts in palm:
        out += line(pts, fill, 32)
    for pts in fingers:
        out += line(pts, fill, 15)
    return out


def feather(cx, cy, ln, w, rot, fill, ink, sw=6):
    d = f"M0 0 Q{f(w)} {f(-ln * 0.3)} {f(w * 0.7)} {f(-ln * 0.7)} Q{f(w * 0.3)} {f(-ln)} 0 {f(-ln)} Q{f(-w)} {f(-ln * 0.75)} {f(-w * 0.8)} {f(-ln * 0.3)} Q{f(-w * 0.4)} {f(-ln * 0.05)} 0 0Z"
    body = path(d, fill, ink, sw)
    body += path(f"M0 {f(ln * 0.28)} L0 {f(-ln * 0.86)}", "none", ink, sw * 0.7)
    body += path(f"M{f(w * 0.72)} {f(-ln * 0.42)} L{f(w * 0.25)} {f(-ln * 0.36)} M{f(-w * 0.78)} {f(-ln * 0.55)} L{f(-w * 0.3)} {f(-ln * 0.5)}",
                 "none", ink, sw * 0.6)
    return g(body, f"translate({f(cx)} {f(cy)}) rotate({rot})")


def flame(cx, cy, s, outer, inner, ink, sw=7):
    d = ("M0 -70 Q34 -34 34 8 A34 34 0 0 1 -34 8 Q-34 -12 -18 -28 Q-14 -10 -6 -8 Q-12 -38 0 -70Z")
    d2 = "M0 -22 Q16 -4 16 14 A16 16 0 0 1 -16 14 Q-14 2 -8 -4 Q-4 4 0 -22Z"
    return g(path(d, outer, ink, sw / s) + path(d2, inner), f"translate({f(cx)} {f(cy)}) scale({s})")


def winged_boot(p, boot, wing, sw=7):
    ink = p["ink"]
    wing_d = "M52 96 Q30 84 22 60 Q44 62 58 72 Q40 62 36 44 Q58 52 72 68 Q62 52 66 38 Q88 54 96 82Z"
    out = g(path(wing_d, wing, ink, sw / 1.5), "translate(98 86) scale(1.5) translate(-96 -84)")
    out += path("M96 58 H140 Q138 110 148 132 Q188 140 200 168 Q206 190 186 190 H94 Q90 120 96 58Z", boot, ink, sw)
    out += path("M92 190 H190", "none", ink, sw + 3)
    out += path("M95 84 H139", "none", ink, sw * 0.7)
    return out


def goblet(bowl, wine, ink, sw=7):
    out = path("M84 60 H172 Q172 126 128 132 Q84 126 84 60Z", bowl, ink, sw)
    out += path("M94 74 H162 Q158 112 128 118 Q98 112 94 74Z", wine)
    out += path("M128 132 V180 M96 186 Q128 172 160 186", "none", ink, sw + 2)
    return out


def bloom(petal, heart, ink, sw=7):
    """An opening bloom: five petals fanned upward."""
    out = ""
    pet = "M0 0 Q30 -40 0 -86 Q-30 -40 0 0Z"
    for rot in (-72, 72, -38, 38, 0):
        out += g(path(pet, petal, ink, sw), f"translate(128 176) rotate({rot})")
    out += path("M100 176 Q128 206 156 176 Q128 188 100 176Z", heart, ink, sw)
    return out


def bow_drawn(wood, ink, string, sw=7, draw=34):
    out = path("M96 44 Q180 128 96 212", "none", ink, 12 + sw)
    out += path("M96 44 Q180 128 96 212", "none", wood, 10)
    out += path(f"M96 44 L{96 - draw} 128 L96 212", "none", string, sw * 0.7)
    return out


def bezier_pts(p0, p1, p2, p3, n=24):
    out = []
    for i in range(n + 1):
        t = i / n
        a, b, c, d = (1 - t) ** 3, 3 * (1 - t) ** 2 * t, 3 * (1 - t) * t * t, t ** 3
        out.append((a * p0[0] + b * p1[0] + c * p2[0] + d * p3[0], a * p0[1] + b * p1[1] + c * p2[1] + d * p3[1]))
    return out


def thorn_vine(pts, w, col, ink=None, thorn_every=3, thorn_len=2.4, rng=None, sw=3, flip=1):
    """A vine along a polyline with thorns alternating either side."""
    rng = rng or random.Random(1)
    out = ""
    thorns = ""
    side = flip
    for i in range(1, len(pts) - 1):
        if i % thorn_every:
            continue
        (x0, y0), (x1, y1) = pts[i - 1], pts[i + 1]
        dx, dy = x1 - x0, y1 - y0
        n = math.hypot(dx, dy) or 1
        dx, dy = dx / n, dy / n
        px, py = -dy * side, dx * side
        side = -side
        x, y = pts[i]
        L = w * thorn_len * rng.uniform(0.8, 1.25)
        tip = (x + px * L + dx * L * 0.45, y + py * L + dy * L * 0.45)
        base = [(x - dx * w * 0.9, y - dy * w * 0.9), tip, (x + dx * w * 0.9, y + dy * w * 0.9)]
        thorns += path(pts_d(base, True), col, ink, sw if ink else 0)
    if ink:
        out += line(pts, ink, w + sw * 2)
    out += thorns + line(pts, col, w)
    return out
