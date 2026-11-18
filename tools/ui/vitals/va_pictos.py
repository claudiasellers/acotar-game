"""Status medallions (B), imbue tags (C), world marks (E) and menu icons (F). Plan §15."""
import math
import random

from va_common import (HORROR, HUMAN, SPRING, arc_d, band_d, blob_lines, bloom, bow_drawn, circ, ell, f,
                       feather, flame, g, goblet, gold_circle, gold_line, hand, leaf, line, mix, path, pol,
                       pts_d, rose, star4, svg, thorn_vine, winged_boot)

H = HORROR
C = 128  # centre of the 256 box


def add(out, name, w, h, body, defs="", half=False):
    out[name] = {"w": w, "h": h, "svg": svg(w, h, body, defs), "half": half}


def at(body, s=1.0, dx=0.0, dy=0.0, rot=0.0):
    """Scale a 256-box drawing about its centre, then nudge and turn it."""
    return g(body, f"translate({f(C + dx)} {f(C + dy)}) rotate({rot}) scale({s}) translate(-128 -128)")


# ---------------------------------------------------------------- medallion bases

def chipped_pts(seed, r=94.0, notches=((38, 13), (203, 16), (292, 10)), sq=0.955):
    rng = random.Random(seed)
    pts = []
    for i in range(96):
        a = i * 360 / 96
        rr = r + rng.uniform(-1.6, 1.6)
        for na, nd in notches:
            d = min(abs(a - na), 360 - abs(a - na))
            if d < 9:
                rr -= nd * (1 - d / 9) ** 0.6
        x, y = pol(0, 0, rr, a)
        ca, sa = math.cos(0.5), math.sin(0.5)
        x2, y2 = x * ca - y * sa, (x * sa + y * ca) * sq
        pts.append((C + x2 * ca + y2 * sa, C - x2 * sa + y2 * ca))
    return pts


def cracks(seed, n, col, sw=3, r=88):
    rng = random.Random(seed)
    out = ""
    for _ in range(n):
        a = rng.uniform(0, 360)
        x, y = pol(C, C, r, a)
        pts = [(x, y)]
        ang = math.radians(a + 180 + rng.uniform(-40, 40))
        for _ in range(rng.randint(3, 5)):
            ang += rng.uniform(-0.8, 0.8)
            L = rng.uniform(10, 22)
            x, y = x + math.sin(ang) * L, y - math.cos(ang) * L
            pts.append((x, y))
        out += line(pts, col, sw)
    return out


def bases(out):
    for skin, p in (("spring", SPRING), ("human", HUMAN)):
        # Buff frame: gold rim, one painted gloss highlight, a sparkle notch.
        body = gold_circle(C, C, 97, p, 10)
        body += path(arc_d(C, C, 78, -62, -8), "none", "#FFFFFF", 11, 'opacity="0.62"')
        body += circ(*pol(C, C, 78, 8), 5.5, "#FFFFFF", extra='opacity="0.62"')
        if skin == "spring":
            x, y = pol(C, C, 97, 45)
            body += star4(x, y, 25, p["white"], p["gold"], 4)
            body += star4(x + 17, y - 21, 8, p["gold_lt"])
        else:  # twine knot instead of a sparkle
            x, y = pol(C, C, 97, 45)
            body += line([(x - 12, y - 12), (x + 12, y + 12)], p["butter"], 7) + line(
                [(x + 12, y - 12), (x - 12, y + 12)], p["butter"], 7) + circ(x, y, 6, p["gold_dk"])
        add(out, f"medallion/base_buff_frame_{skin}", 256, 256, body, half=True)

    # Buff fill: a white enamel disc the game tints (rose, blush, lilac...).
    body = circ(C, C, 93, "#FFFFFF") + path(arc_d(C, C, 80, 110, 250), "none", "#C9C4D6", 16, 'opacity="0.55"')
    add(out, "medallion/base_buff_fill", 256, 256, body, half=True)

    # Giddy (fae-toll): the half-buff. Same enamel, but the gold sits crooked.
    p = SPRING
    rim = g(gold_circle(0, 0, 97, p, 10), f"translate({C + 4} {C - 2}) rotate(-14) scale(1.03 0.95)")
    body = rim + path(arc_d(C, C, 78, -62, -8), "none", "#FFFFFF", 11, 'opacity="0.62"')
    x, y = pol(C, C, 99, 58)
    body += star4(x, y, 23, p["white"], p["gold"], 4, rot=18) + star4(*pol(C, C, 103, 232), 13, p["gold_lt"], p["gold"], 3, rot=30)
    add(out, "medallion/base_giddy_frame_spring", 256, 256, body, half=True)

    # Debuff: tarnished, chipped, lopsided. No gold, no sparkle.
    pts = chipped_pts(7)
    rng = random.Random(11)
    blot = ""
    for _ in range(9):
        a, r = rng.uniform(0, 360), rng.uniform(20, 78)
        x, y = pol(C, C, r, a)
        blot += ell(x, y, rng.uniform(10, 26), rng.uniform(8, 18), "#8C8C8C", extra=f'opacity="{rng.uniform(.25, .5):.2f}"')
    defs = f'<clipPath id="dc"><path d="{pts_d(pts, True)}"/></clipPath><filter id="soft"><feGaussianBlur stdDeviation="5"/></filter>'
    body = path(pts_d(pts, True), "#FFFFFF") + g(g(blot, extra='filter="url(#soft)"') + circ(C, C, 96, "none", "#000000", 26, 'opacity="0.38" filter="url(#soft)"'),
                                               extra='clip-path="url(#dc)"')
    add(out, "medallion/base_debuff_fill", 256, 256, body, defs, half=True)

    for skin, rimcol, patina, edge in (("spring", H["tarnish"], H["verdigris"], H["ichor"]),
                                      ("human", "#4A4640", "#8C8A86", HUMAN["ink"])):
        body = path(pts_d(pts, True), "none", edge, 15) + path(pts_d(pts, True), "none", rimcol, 9)
        body += path(pts_d(pts, True), "none", patina, 9, 'stroke-dasharray="14 46 30 80 8 60" opacity="0.9"')
        body += path(pts_d(pts, True), "none", H["bone"], 2, 'stroke-dasharray="20 150 12 210" opacity="0.5"')
        body += cracks(5, 4, edge, 3.5)
        add(out, f"medallion/base_debuff_frame_{skin}", 256, 256, body, half=True)

    # Timer ring (radial progress, tinted gold or bone) and the venom creep ring (fills upward).
    add(out, "medallion/timer_ring", 256, 256, circ(C, C, 114, "none", "#FFFFFF", 9), half=True)
    rng = random.Random(3)
    body = circ(C, C, 114, "none", "#FFFFFF", 8)
    for i in range(26):
        a = i * 360 / 26 + rng.uniform(-5, 5)
        x0, y0 = pol(C, C, 114, a)
        x1, y1 = pol(C, C, 114 - rng.uniform(8, 20), a + rng.uniform(-9, 9))
        body += line([(x0, y0), (x1, y1)], "#FFFFFF", rng.uniform(2.5, 5))
    add(out, "medallion/creep_ring", 256, 256, body, half=True)

    # Buff pop-in: six frames of sparkle.
    body = ""
    for i in range(6):
        t = i / 5
        fr = ""
        if i < 3:
            fr += circ(C, C, 60 + 50 * t * 2, "none", "#FFF6CF", 10 * (1 - t * 1.6), f'opacity="{1 - t * 1.8:.2f}"')
        for k in range(7):
            a = k * 360 / 7 + 14
            x, y = pol(C, C, 46 + 70 * (t ** 0.6), a)
            R = (30 if k % 2 else 20) * math.sin(math.pi * min(1, t * 1.05 + 0.12)) + 2
            fr += star4(x, y, R, "#FFFFFF" if k % 2 else SPRING["gold_lt"], SPRING["gold"], 2.5, rot=a + t * 40)
        body += g(fr, f"translate({i * 256} 0)")
    add(out, "medallion/pop_in_sheet", 256 * 6, 256, body)


# ---------------------------------------------------------------- pictograms (256 box)

def oak_leaf(cx, cy, ln, w, rot, fill, ink, sw=7):
    right, left = [], []
    for i in range(49):
        t = i / 48
        half = w * math.sin(math.pi * t) ** 0.6 * (0.66 + 0.34 * math.cos(2 * math.pi * 3.5 * t + math.pi))
        right.append((half, -ln * t))
        left.append((-half, -ln * t))
    body = path(pts_d(right + left[::-1], True), fill, ink, sw) + path(f"M0 {f(ln * 0.16)} L0 {f(-ln * 0.86)}", "none", ink, sw * 0.7)
    return g(body, f"translate({f(cx)} {f(cy)}) rotate({rot})")


def arrow_level(p, y=92, x0=58, x1=198, shaft=None, head=None):
    ink = p["ink"]
    out = blob_lines([[(x0, y), (x1 - 44, y)]], shaft or p["butter"], ink, 8, 6)
    out += path(pts_d([(x1 - 50, y - 24), (x1, y), (x1 - 50, y + 24), (x1 - 40, y)], True), head or p["white"], ink, 7)
    out += path(f"M{x0} {y} l-14 -14 M{x0} {y} l-14 14 M{x0 + 14} {y} l-14 -14 M{x0 + 14} {y} l-14 14", "none", ink, 6)
    return out


def snowflake(cx, cy, r, col, sw=7):
    d = ""
    for i in range(3):
        x0, y0 = pol(cx, cy, r, i * 60)
        x1, y1 = pol(cx, cy, r, i * 60 + 180)
        d += f"M{f(x0)} {f(y0)} L{f(x1)} {f(y1)} "
    for i in range(6):
        bx, by = pol(cx, cy, r * 0.62, i * 60)
        for s in (-1, 1):
            tx, ty = pol(bx, by, r * 0.34, i * 60 + s * 42)
            d += f"M{f(bx)} {f(by)} L{f(tx)} {f(ty)} "
    return path(d, "none", col, sw)


def drop(cx, cy, s, fill, ink, sw=7):
    d = "M0 -84 Q52 -22 52 16 A52 52 0 0 1 -52 16 Q-52 -22 0 -84Z"
    return g(path(d, fill, ink, sw / s), f"translate({f(cx)} {f(cy)}) scale({s})")


def bow_knot(cx, cy, s, fill, ink, sw=6):
    d = "M0 0 L-34 -18 Q-42 0 -34 18Z M0 0 L34 -18 Q42 0 34 18Z"
    tails = "M-4 6 L-18 34 M4 6 L18 34"
    return g(path(tails, "none", ink, (9 + sw) / s) + path(tails, "none", fill, 8 / s) + path(d, fill, ink, sw / s) + circ(0, 0, 8, fill, ink, sw / s),
             f"translate({f(cx)} {f(cy)}) scale({s})")


def p_steady(p):
    return arrow_level(p, 72) + at(hand(p["blush"], p["ink"]), 0.66, 0, 42)


def p_swift(p):
    return at(winged_boot(p, p["blush"], p["white"]), 0.86, 22, 6)


def p_strong(p):
    return at(bow_drawn(p["wood"], p["ink"], p["deep"], 9, 0), 1.0, 22, 0) + oak_leaf(62, 196, 128, 40, 38, p["leaf"], p["ink"])


def p_warm(p):
    ink = p["ink"]
    out = flame(C, 112, 0.92, p["coral"], p["butter"], ink)
    out += path("M62 148 Q128 190 194 148 Q200 200 128 210 Q56 200 62 148Z", p["white"], ink, 7)
    out += path("M92 172 Q128 190 164 172", "none", ink, 4.5) + path("M194 148 Q208 132 198 118 Q184 126 182 150", p["white"], ink, 7)
    return out


def p_quiet(p):
    ink = p["ink"]
    out = circ(C, 52, 10, "none", ink, 7)
    out += path("M128 62 Q174 62 178 126 Q180 148 198 160 H58 Q76 148 78 126 Q82 62 128 62Z", p["butter"], ink, 7)
    out += path("M96 122 Q100 84 122 76", "none", p["white"], 7, 'opacity="0.8"')
    out += circ(C, 182, 13, p["amber"], ink, 7)
    out += bow_knot(C, 182, 0.95, p["rose"], ink)
    return out


def p_bright(p):
    ink = p["ink"]
    out = circ(C, 52, 13, "none", ink, 7)
    out += path("M96 84 L112 64 H144 L160 84Z", p["lilac"], ink, 7)
    out += path("M94 84 H162 V178 H94Z", p["white"], ink, 7, 'rx="6"')
    out += path("M84 178 H172 V196 H84Z", p["lilac"], ink, 7)
    out += flame(C, 148, 0.5, p["amber"], p["butter"], ink)
    out += star4(176, 98, 16, p["white"], ink, 3.5) + star4(76, 130, 11, p["white"], ink, 3)
    return out


def p_keen(p):
    ink = p["ink"]
    out = path("M48 132 Q128 62 208 132 Q128 202 48 132Z", p["white"], ink, 7)
    out += circ(C, 132, 31, p["periwinkle"], ink, 6) + circ(C, 132, 13, ink) + circ(118, 122, 6, "#FFFFFF")
    for a, x in ((-34, 78), (-16, 102), (0, 128), (16, 154), (34, 178)):
        y = 132 - 44 * math.cos(math.radians((x - 128) * 1.05)) + 2
        tx, ty = pol(x, y, 24, a)
        out += line([(x, y), (tx, ty)], ink, 7)
    return out


def p_cool(p):
    return drop(C, 138, 1.0, p["sky"], p["ink"]) + snowflake(C, 152, 30, p["white"], 6) + path(
        "M98 132 Q100 108 114 92", "none", "#FFFFFF", 6, 'opacity="0.75"')


def p_heal(p):
    ink = p["ink"]
    out = path("M128 150 Q124 190 138 222", "none", ink, 13) + path("M128 150 Q124 190 138 222", "none", p["leaf"], 6)
    out += g(path("M0 0 Q46 -22 78 4 Q46 30 0 0Z", p["white"], ink, 6) + path("M26 -8 L32 14 M44 -10 L50 14", "none", p["deep"], 6),
             "translate(132 190) rotate(-18)")
    out += leaf(124, 200, 52, 18, -62, p["leaf"], ink, 6)
    out += rose(C, 100, 50, p["white"], p["blush"], ink, 6)
    return out


def p_well_rested(p):
    ink = p["ink"]
    out = path("M54 168 Q60 150 84 156 Q128 164 172 156 Q196 150 202 168 Q210 196 198 214 Q128 204 58 214 Q46 196 54 168Z", p["white"], ink, 7)
    out += path("M84 176 Q128 184 172 176", "none", p["lilac"], 6)
    out += path("M150 44 A56 56 0 1 0 186 138 A44 44 0 1 1 150 44Z", p["butter"], ink, 7)
    out += star4(180, 70, 17, p["white"], ink, 3.5) + star4(76, 60, 10, p["white"], ink, 3)
    return out


def p_well_fed(p):
    ink = p["ink"]
    out = path("M60 122 V170 A68 24 0 0 0 196 170 V122Z", p["cake"], ink, 7)
    out += ell(C, 122, 68, 24, p["amber"], ink, 7)
    out += path("M62 126 Q70 152 84 142 Q92 170 108 146 Q122 164 136 148 Q150 176 164 146 Q180 158 194 126 A68 24 0 0 1 62 126Z", p["amber"], ink, 6)
    out += path("M84 112 Q112 104 140 106", "none", "#FFFFFF", 6, 'opacity="0.7"')
    out += rose(C, 96, 24, p["rose"], p["blush"], ink, 5)
    out += leaf(150, 108, 30, 11, 70, p["leaf"], ink, 5, False)
    return out


def p_at_ease(p):
    return at(bloom(p["rose"], p["butter"], p["ink"]), 0.98, 0, -26) + star4(190, 76, 15, p["white"], p["ink"], 3.5) + star4(64, 96, 10, p["white"], p["ink"], 3)


def p_giddy(p):
    ink = p["ink"]
    out = at(goblet(p["butter"], p["deep"], ink), 0.8, -26, 14, -34)
    for x, y, r, c in ((166, 74, 20, "white"), (196, 112, 13, "butter"), (176, 142, 17, "white"), (204, 166, 10, "butter"),
                       (150, 108, 9, "white"), (186, 194, 13, "white")):
        out += star4(x, y, r, p[c], ink, 3.5, rot=r)
    return out


def p_venom(p):
    out = at(hand(H["sick"], H["ichor"], crooked=True, sw=5), 0.98, 0, 0)
    veins = [[(128, 232), (126, 196), (116, 166), (102, 140), (86, 116), (76, 92)], [(126, 196), (136, 166), (142, 134), (148, 96), (144, 66)],
             [(116, 166), (114, 136), (106, 100), (112, 66)], [(136, 166), (158, 146), (176, 118), (180, 92)],
             [(118, 178), (98, 174), (74, 164), (58, 148)], [(104, 140), (96, 150)], [(142, 134), (152, 128)], [(117, 120), (108, 112)]]
    body = "".join(line(v, H["ichor"], 5.5) for v in veins) + "".join(line(v, "#2A3320", 2) for v in veins[:4])
    return out + at(body, 0.98, 0, 0)


def p_drowsy(p):
    bone, ink, grey = H["bone"], H["ichor"], "#A9A2B0"
    out = ""
    for s in (1, -1):
        wing = path("M4 86 Q46 44 74 62 Q72 100 6 104Z", grey, ink, 6) + path("M6 104 Q42 108 48 132 Q22 138 4 114Z", "#8A8394", ink, 6)
        wing += circ(46, 76, 8, H["dusk"]) + path("M18 92 Q40 80 62 72", "none", ink, 3)
        out += g(wing, f"translate(128 0) scale({s} 1)")
    out += ell(C, 98, 8, 24, bone, ink, 5)
    out += path("M124 76 Q112 58 100 56 M132 76 Q144 58 156 56", "none", bone, 4.5)
    out += path("M62 172 Q128 150 194 172 Q128 214 62 172Z", H["dusk"], bone, 6)
    out += path("M62 172 Q128 214 194 172", "none", bone, 8)
    for x, y, dx in ((88, 190, -8), (112, 199, -4), (144, 199, 4), (168, 190, 8)):
        out += line([(x, y), (x + dx, y + 18)], bone, 6)
    return out


def p_roar(p):
    bone, ink = H["bone"], H["ichor"]
    out = ""
    for a0, a1, dr in ((8, 62, 0), (74, 128, 7), (142, 196, -5), (206, 262, 6), (276, 348, -3)):
        out += path(arc_d(C, C, 84 + dr, a0, a1), "none", bone, 9)
    for a in (68, 135, 201, 269, 357):
        x0, y0 = pol(C, C, 74, a)
        x1, y1 = pol(C, C, 98, a + 6)
        out += line([(x0, y0), ((x0 + x1) / 2 + 5, (y0 + y1) / 2 - 3), (x1, y1)], bone, 4)
    out = at(out, 1.12) + path("M82 116 Q128 78 174 116 Q180 154 128 176 Q76 154 82 116Z", "#2A0A10", bone, 6)
    out += ell(C, 140, 22, 16, H["crimson"])
    fangs = [[(92, 110), (101, 146), (112, 100)], [(144, 100), (155, 146), (164, 110)], [(116, 99), (122, 118), (128, 98)], [(128, 98), (134, 118), (140, 99)],
             [(104, 160), (112, 132), (120, 167)], [(136, 167), (144, 132), (152, 160)]]
    for t in fangs:
        out += path(pts_d(t, True), bone, ink, 3)
    return out


def p_chilled(p, ice=None):
    ice = ice or H["ice"]
    main = [(34, 70), (70, 88), (98, 108), (90, 130), (126, 136), (146, 146), (136, 172), (176, 184), (222, 200)]
    out = line(main, "#5E7C96", 15) + line(main, ice, 8)
    for br in ([(98, 108), (124, 92), (136, 70)], [(126, 136), (112, 158), (88, 168)], [(146, 146), (172, 132), (186, 108)], [(136, 172), (140, 196)],
               [(70, 88), (62, 112)], [(172, 132), (196, 138)]):
        out += line(br, ice, 5)
    out += snowflake(176, 76, 20, ice, 4.5) + snowflake(82, 190, 15, ice, 4)
    return out


def p_starving(p):
    bone, ink = H["bone"], H["ichor"]
    out = path("M56 126 H200 Q194 196 128 198 Q62 196 56 126Z", "#3A3A44", bone, 7)
    out += ell(C, 126, 72, 17, "#16151B", bone, 7)
    out += path("M96 196 H160 V208 H96Z", "#3A3A44", bone, 6)
    out += blob_lines([[(186, 46), (150, 116)]], bone, ink, 8, 4) + g(ell(0, 0, 15, 21, bone, ink, 4), "translate(190 40) rotate(27)")
    out += line([(92, 150), (100, 166), (94, 180)], bone, 3.5)
    return out


def p_stuffed(p):
    ink = p["ink"]
    out = path("M66 122 Q72 70 104 76 Q112 44 142 58 Q176 50 178 86 Q198 96 190 122Z", p["cake"], ink, 7)
    out += circ(104, 96, 7, p["deep"]) + circ(140, 80, 7, p["deep"]) + circ(160, 104, 7, p["deep"]) + circ(124, 110, 6, p["leaf"])
    out += path("M52 122 H204 Q198 196 128 198 Q58 196 52 122Z", p["white"], ink, 7)
    out += path("M56 146 Q128 164 200 146", "none", p["rose"], 9)
    out += bow_knot(C, 158, 0.95, p["rose"], ink)
    return out


BUFFS = [  # id, tag, picto, enamel colour key
    ("b01", "steady", p_steady, "lilac"), ("b02", "swift", p_swift, "mint"), ("b03", "strong", p_strong, "butter"),
    ("b04", "warm", p_warm, "blush"), ("b05", "quiet", p_quiet, "periwinkle"), ("b06", "bright", p_bright, "butter"),
    ("b07", "keen", p_keen, "mint"), ("b08", "cool", p_cool, "mint"), ("b09", "heal", p_heal, "rose"),
    ("b10", "well_rested", p_well_rested, "periwinkle"), ("b11", "well_fed", p_well_fed, "butter"),
    ("b12", "at_ease", p_at_ease, "pearl"), ("b13", "giddy", p_giddy, "lilac"), ("b19", "stuffed", p_stuffed, "blush"),
]
DEBUFFS = [  # id, tag, picto, disc tint
    ("b14", "venom", p_venom, "#3E4A22"), ("b15", "drowsy", p_drowsy, "#4A3358"), ("b16", "roar_shake", p_roar, "#7A1E2A"),
    ("b17", "chilled", p_chilled, "#1E2A44"), ("b18", "starving", p_starving, "#4A4640"),
]


def pictos(out):
    for skin, p in (("spring", SPRING), ("human", HUMAN)):
        for bid, tag, fn, _ in BUFFS:
            add(out, f"medallion/picto_{bid}_{tag}_{skin}", 256, 256, at(fn(p), 0.84), half=True)
    for bid, tag, fn, _ in DEBUFFS:
        add(out, f"medallion/picto_{bid}_{tag}", 256, 256, at(fn(SPRING), 0.84), half=True)
    add(out, "medallion/picto_b17_chilled_human", 256, 256, at(p_chilled(HUMAN, "#EAF6FF"), 0.84), half=True)


# ---------------------------------------------------------------- imbue tags (C)

def s_cloak(c, w):
    return path("M128 28 Q166 32 172 74 Q212 122 216 224 H40 Q44 122 84 74 Q90 32 128 28Z M128 52 Q104 56 104 84 Q128 100 152 84 Q152 56 128 52Z",
                c, extra='fill-rule="evenodd"') + line([(128, 104), (128, 222)], w, 5)


def s_boots(c, w):
    b = "M92 62 H140 V134 Q184 140 198 170 Q204 190 186 190 H92Z"
    return g(path(b, c), "translate(-34 36) scale(0.8)") + g(path(b, c, w, 7), "translate(38 52) scale(0.8)")


def s_gloves(c, w):
    return hand(c, c, sw=1) + path("M100 204 H156 L168 244 H88Z", c) + line([(98, 218), (158, 218)], w, 5)


def s_bowstring(c, w):
    return path("M96 36 Q196 128 96 220", "none", c, 15) + line([(96, 36), (96, 220)], c, 6) + circ(96, 128, 9, c) + path(
        "M96 36 l-12 -8 M96 220 l-12 8", "none", c, 9)


def s_knife(c, w):
    body = path("M118 26 Q150 86 140 152 H118Z", c) + path("M100 152 H156 V164 H100Z", c) + path("M114 164 H142 V218 Q128 232 114 218Z", c)
    body += line([(120, 180), (136, 180)], w, 4) + line([(120, 194), (136, 194)], w, 4)
    return g(body, "rotate(40 128 128)")


def s_charm(c, w):
    return path("M128 118 Q64 64 128 34 Q192 64 128 118", "none", c, 7) + path("M128 112 Q170 150 170 180 A42 42 0 0 1 86 180 Q86 150 128 112Z", c) + star4(
        128, 180, 22, w)


SILS = [("c1", "cloak", s_cloak), ("c2", "boots", s_boots), ("c3", "gloves", s_gloves), ("c4", "bowstring", s_bowstring),
        ("c5", "knife", s_knife), ("c6", "charm", s_charm)]
TAG_D = "M60 94 L98 52 H158 L196 94 V218 Q196 232 182 232 H74 Q60 232 60 218Z"


def tags(out):
    for skin, p in (("spring", SPRING), ("human", HUMAN)):
        ink = p["ink"]
        loop = "M128 78 Q98 40 112 20 Q128 4 140 24 Q150 44 128 78"
        ribbon = p["rose"] if skin == "spring" else p["butter"]
        body = path(TAG_D, p["paper"], p["gold_dk"], 9) + path(TAG_D, "none", p["gold"], 5)
        body += path("M72 98 L103 64 H153 L184 98 V214 Q184 220 178 220 H78 Q72 220 72 214Z", "none", p["gold"], 2.5, 'stroke-dasharray="7 6"')
        body += circ(128, 78, 10, p["paper"], p["gold_dk"], 6) + circ(128, 78, 10, "none", p["gold"], 3)
        body += path(loop, "none", ink, 12) + path(loop, "none", ribbon, 7)
        body += circ(170, 206, 21, p["paper"], p["gold_dk"], 7) + circ(170, 206, 21, "none", p["gold"], 4)
        add(out, f"imbue/tag_base_{skin}", 256, 256, body, half=True)
    # Gem: tinted with the brew's colour at runtime.
    body = circ(170, 206, 17, "#FFFFFF") + path(arc_d(170, 206, 10, -70, 0), "none", "#FFFFFF", 5) + path(
        arc_d(170, 206, 11, 110, 240), "none", "#B8B4C4", 6, 'opacity="0.6"')
    add(out, "imbue/tag_gem", 256, 256, body, half=True)
    for cid, name, fn in SILS:
        for skin, p in (("spring", SPRING), ("human", HUMAN)):
            add(out, f"imbue/item_{cid}_{name}_{skin}", 256, 256, at(fn(p["ink"], p["paper"]), 0.86), half=True)
    # C7 imbue flourish: a gold swirl winds round the item and bursts into sparkle. 8 frames.
    p = SPRING
    swirl = "M128 214 C40 214 30 96 112 74 C176 58 214 112 180 152 C156 180 110 168 112 132 C114 110 138 104 148 120"
    body = ""
    for i in range(8):
        t = i / 7
        prog = min(1.0, t * 1.7)
        fade = 1.0 if t < 0.6 else max(0.0, 1 - (t - 0.6) / 0.4)
        fr = path(swirl, "none", p["gold_dk"], 11, f'pathLength="1" stroke-dasharray="{prog:.3f} 2" opacity="{fade:.2f}"')
        fr += path(swirl, "none", p["gold"], 7, f'pathLength="1" stroke-dasharray="{prog:.3f} 2" opacity="{fade:.2f}"')
        fr += path(swirl, "none", p["gold_lt"], 2.5, f'pathLength="1" stroke-dasharray="{prog:.3f} 2" opacity="{fade:.2f}"')
        if t > 0.3:
            u = (t - 0.3) / 0.7
            for k in range(9):
                a = k * 40 + 10
                x, y = pol(132, 128, 30 + 86 * u ** 0.7, a)
                R = (26 if k % 3 == 0 else 15) * math.sin(math.pi * min(1, u * 0.95 + 0.1)) + 1
                fr += star4(x, y, R, "#FFFFFF" if k % 2 else p["butter"], p["gold"], 2.5, rot=a)
        body += g(fr, f"translate({i * 256} 0)")
    add(out, "imbue/flourish_sheet", 256 * 8, 256, body)
    # C8 expiry fizz: the gem dims and smokes. 6 frames.
    body = ""
    rng = random.Random(21)
    puffs = [(rng.uniform(-16, 16), rng.uniform(0.7, 1.2), rng.uniform(0, 1)) for _ in range(5)]
    for i in range(6):
        t = i / 5
        gemc = mix("#FFFFFF", "#6E6A70", t)
        fr = circ(128, 170, 30 * (1 - 0.12 * t), gemc, "#4A464C", 4, f'opacity="{1 - 0.35 * t:.2f}"')
        fr += line([(116, 162), (122, 172), (118, 182)], "#4A464C", 2.5 * t + 0.1) + line([(134, 156), (130, 168), (140, 178)], "#4A464C", 2.5 * t + 0.1)
        for dx, sc, ph in puffs:
            u = max(0.0, t - ph * 0.35)
            if u <= 0:
                continue
            y = 140 - 100 * u
            fr += path(f"M{f(128 + dx)} {f(y + 22)} q-14 -10 0 -22 q14 -10 0 -24", "none", "#8E8A92", 7 * sc, f'opacity="{max(0, 0.75 - u * 0.7):.2f}"')
        body += g(fr, f"translate({i * 256} 0)")
    add(out, "imbue/fizz_sheet", 256 * 6, 256, body)


# ---------------------------------------------------------------- perk badges (F1), drawn bolder for 32 px

def ward(inner, p):
    return circ(C, C, 96, "none", p["ink"], 9, 'stroke-dasharray="1 21.3" stroke-linecap="round"') + at(inner, 0.74)


def f_sight(p):
    ink = p["ink"]
    out = path("M54 150 Q128 204 202 150", "none", ink, 12)
    for x, y, dx in ((84, 176, -10), (128, 186, 0), (172, 176, 10)):
        out += line([(x, y), (x + dx, y + 22)], ink, 10)
    return out + leaf(66, 132, 140, 44, 78, p["leaf"], ink, 9)


def f_noise(p):
    return feather(100, 196, 170, 44, 30, p["white"], p["ink"], 9) + path("M150 206 q24 12 48 0 M160 226 q14 6 28 0", "none", p["ink"], 9)


def f_scent(p):
    return path("M46 104 H150 Q184 104 184 78 Q184 54 160 54 Q142 54 142 72 M46 148 H180 Q212 148 212 174 Q212 198 188 198 Q170 198 170 182 M70 190 H128",
                "none", p["ink"], 12)


def f_dread(p):
    ink = p["ink"]
    out = path("M128 204 Q50 148 56 98 Q62 60 98 64 Q120 68 128 90 Q136 68 158 64 Q194 60 200 98 Q206 148 128 204Z", p["deep"], ink, 9)
    pts = [(40 + i * 12, 150 - i * 3.4 + 22 * math.sin(i * 0.75)) for i in range(16)]
    return out + thorn_vine(pts, 9, ink, None, 3, 2.3)


def f_sway(p):
    return arrow_level(p, 104, 50, 208) + path("M62 176 H194", "none", p["ink"], 11) + circ(C, 176, 15, p["white"], p["ink"], 8)


def f_draw(p):
    ink = p["ink"]
    return at(bow_drawn(p["wood"], ink, ink, 9, 50), 1.0, 26, 0) + line([(70, 128), (206, 128)], ink, 9) + path(
        pts_d([(196, 108), (232, 128), (196, 148)], True), p["white"], ink, 8)


def f_stamina(p):
    out = circ(C, C, 70, "none", p["ink"], 30) + circ(C, C, 70, "none", p["white"], 14) + path(arc_d(C, C, 70, 0, 250), "none", p["rose"], 14)
    return out + rose(C, 58, 26, p["rose"], p["blush"], p["ink"], 6)


def f_sprint(p):
    return at(winged_boot(p, p["blush"], p["white"], 9), 1.0, 24, 6)


def f_climb(p):
    ink = p["ink"]
    ivy = "M0 0 Q-26 -8 -30 -34 Q-14 -30 -6 -40 Q0 -58 0 -58 Q0 -58 6 -40 Q14 -30 30 -34 Q26 -8 0 0Z"
    out = hand(p["white"], ink, sw=9)
    out += path("M70 236 Q128 196 190 214", "none", ink, 14) + path("M70 236 Q128 196 190 214", "none", p["leaf"], 6)
    for x, y, r in ((84, 226, -30), (140, 204, 6), (190, 212, 40)):
        out += g(path(ivy, p["leaf"], ink, 7), f"translate({x} {y}) rotate({r}) scale(0.9)")
    return out


def f_warmth(p):
    ink = p["ink"]
    out = path("M44 76 Q128 44 212 76 L128 212Z", p["rose"], ink, 9)
    out += path("M88 70 Q128 118 168 70", "none", ink, 9)
    out += path("M66 112 L54 132 M86 144 L72 164 M106 176 L92 196 M190 112 L202 132 M170 144 L184 164 M150 176 L164 196", "none", ink, 8)
    return out


def f_thorn(p):
    return path("M70 214 Q120 170 190 40 Q170 160 118 226Z", p["leaf"], p["ink"], 10) + path("M56 236 Q96 226 136 196", "none", p["ink"], 12)


def f_flame(p):
    return flame(C, 148, 1.5, p["coral"], p["butter"], p["ink"], 10)


def f_cold(p):
    return snowflake(C, C, 92, p["ink"], 22) + snowflake(C, C, 92, p["sky"], 9)


def f_venom_drop(p):
    return drop(C, 150, 1.35, H["ichor"], p["ink"], 9) + path("M100 150 Q102 120 118 98", "none", H["bile"], 9)


def f_fall(p):
    return feather(150, 196, 170, 44, -24, p["white"], p["ink"], 9) + path("M56 60 V120 M88 40 V88 M196 150 V214", "none", p["ink"], 9)


def f_glint(p):
    return leaf(96, 220, 180, 56, 22, p["leaf"], p["ink"], 9) + star4(180, 78, 46, p["butter"], p["ink"], 7)


def f_yield(p):
    ink = p["ink"]
    out = path("M70 124 Q128 20 186 124", "none", ink, 11)
    out += circ(100, 112, 18, p["deep"], ink, 7) + circ(136, 104, 20, p["rose"], ink, 7) + circ(164, 116, 15, p["deep"], ink, 7)
    out += path("M48 122 H208 L190 212 H66Z", p["cake"], ink, 9)
    out += path("M58 152 H198 M62 182 H194 M96 124 L104 212 M160 124 L152 212 M128 124 V212", "none", ink, 6)
    return out


def f_ease(p):
    return at(bloom(p["rose"], p["butter"], p["ink"], 9), 1.15, 0, -30)


def f_mare(p):
    d = "M78 206 V124 A50 50 0 0 1 178 124 V206"
    out = path(d, "none", p["ink"], 44) + path(d, "none", p["white"], 26)
    for x, y in ((78, 190), (78, 150), (92, 96), (128, 76), (164, 96), (178, 150), (178, 190)):
        out += circ(x, y, 5.5, p["ink"])
    return out


def f_swim(p):
    ink = p["ink"]
    return circ(118, 138, 66, p["sky"], ink, 9) + path(arc_d(118, 138, 46, -70, -10), "none", "#FFFFFF", 12) + circ(196, 74, 20, p["white"], ink, 8) + circ(
        206, 190, 12, p["white"], ink, 7)


def f_toll(p):
    return at(goblet(p["butter"], p["deep"], p["ink"], 9), 1.15, 0, 6) + star4(196, 62, 22, p["white"], p["ink"], 5)


def f_tells(p):
    ink = p["ink"]
    out = path("M34 150 Q104 60 222 96 Q164 196 34 150Z", p["amber"], ink, 9)
    out += g(ell(0, 0, 13, 40, ink), "translate(134 124) rotate(14)") + circ(118, 106, 8, "#FFFFFF")
    out += path("M34 150 Q20 150 12 138 M222 96 Q234 90 240 76", "none", ink, 9)
    return out


BADGES = [
    ("sight", f_sight, "periwinkle"), ("noise", f_noise, "periwinkle"), ("scent", f_scent, "periwinkle"), ("dread_gain", f_dread, "blush"),
    ("sway", f_sway, "mint"), ("draw_speed", f_draw, "mint"), ("stamina_regen", f_stamina, "mint"), ("sprint", f_sprint, "mint"),
    ("climb", f_climb, "mint"), ("warmth", f_warmth, "blush"), ("resist_thorn", lambda p: ward(f_thorn(p), p), "lilac"),
    ("resist_fire", lambda p: ward(f_flame(p), p), "lilac"), ("resist_cold", lambda p: ward(f_cold(p), p), "lilac"),
    ("resist_venom", lambda p: ward(f_venom_drop(p), p), "lilac"), ("resist_fall", lambda p: ward(f_fall(p), p), "lilac"),
    ("forage_glint", f_glint, "butter"), ("forage_yield", f_yield, "butter"), ("ease_gain", f_ease, "blush"), ("mare", f_mare, "butter"),
    ("swim_breath", f_swim, "butter"), ("fae_toll", f_toll, "blush"), ("tells", f_tells, "periwinkle"),
]


def badges(out):
    for skin, p in (("spring", SPRING), ("human", HUMAN)):
        for name, fn, col in BADGES:
            chip = circ(C, C, 112, p[col], p["gold_dk"], 14) + circ(C, C, 112, "none", p["gold"], 8)
            chip += path(arc_d(C, C, 92, -58, -14), "none", "#FFFFFF", 12, 'opacity="0.6"')
            body = g(chip + at(fn(p), 0.66), "scale(0.5)")
            add(out, f"menu/perk_{name}_{skin}", 128, 128, body)


# ---------------------------------------------------------------- F2–F5, E1–E3

def skull(cx, cy, s):
    bone, ink = H["bone"], H["ichor"]
    b = path("M-30 6 A30 30 0 1 1 30 6 Q30 22 18 26 V40 H-18 V26 Q-30 22 -30 6Z", bone, ink, 5)
    b += ell(-12, 2, 8, 10, ink) + ell(12, 2, 8, 10, ink) + path("M0 12 L-4 22 H4Z", ink) + path("M-8 28 V40 M0 28 V40 M8 28 V40", "none", ink, 3)
    return g(b, f"translate({cx} {cy}) scale({s})")


def small(out):
    p = SPRING
    ink = p["ink"]
    add(out, "menu/chevron_up", 64, 64, path("M12 42 L32 20 L52 42", "none", ink, 15) + path("M12 42 L32 20 L52 42", "none", p["mint"], 8))
    add(out, "menu/chevron_down", 64, 64, path("M12 22 L32 44 L52 22", "none", ink, 15) + path("M12 22 L32 44 L52 22", "none", p["rose"], 8))
    for name, fill, inner in (("empty", "none", "none"), ("filled", p["rose"], p["blush"])):
        body = ""
        for i in range(5):
            x, y = pol(32, 32, 13, i * 72)
            body += circ(x, y, 11, fill, p["gold_dk"], 4.5) + circ(x, y, 11, "none", p["gold"], 2.5)
        body += circ(32, 32, 9, inner if inner != "none" else p["paper"], p["gold_dk"], 4.5) + circ(32, 32, 9, "none", p["gold"], 2.5)
        add(out, f"menu/set_rosette_{name}", 64, 64, body)
    for name in ("empty", "full"):
        body = circ(32, 32, 20, "#FFFFFF" if name == "full" else p["paper"], extra='opacity="%s"' % ("1" if name == "full" else "0.55"))
        body += circ(32, 32, 22, "none", p["gold_dk"], 7) + circ(32, 32, 22, "none", p["gold"], 4)
        if name == "full":
            body += path(arc_d(32, 32, 13, -60, -5), "none", "#FFFFFF", 4)
        add(out, f"menu/effect_pip_{name}", 64, 64, body)

    # F3 "Her kit" header ornament, 512 x 64 on screen, authored at 2x.
    body = ""
    for s in (1, -1):
        side = gold_line("M70 64 H250 Q300 64 300 40 Q300 22 282 22 Q268 22 268 36 Q268 46 278 46", p, 5)
        side += gold_line("M250 64 Q300 64 300 88 Q300 104 284 104 Q272 104 272 92", p, 4)
        side += gold_line("M330 64 H470", p, 3) + circ(486, 64, 5, p["gold"]) + circ(318, 64, 6, p["gold"]) + star4(40, 64, 20, p["gold_lt"], p["gold"], 3)
        side += leaf(120, 64, 46, 13, 60, p["gold_lt"], p["gold"], 3, False) + leaf(170, 64, 40, 12, 120, p["gold_lt"], p["gold"], 3, False)
        body += g(side, f"translate(512 0) scale({s} 1)")
    body += rose(512, 64, 34, p["blush"], p["rose"], p["gold_dk"], 4)
    add(out, "menu/her_kit_header", 1024, 128, body)

    # F4 the "bait" corner mark: a tiny skull and foxglove. Horror palette.
    body = circ(64, 64, 58, H["ichor"], H["tarnish"], 6)
    body += path("M96 108 Q92 60 104 22", "none", H["bile"], 6)
    for x, y, r in ((104, 34, 150), (99, 58, 160), (96, 84, 165)):
        body += g(path("M0 0 Q-13 6 -11 26 Q0 32 11 26 Q13 6 0 0Z", "#8E3A6E", H["ichor"], 3) + circ(0, 22, 2.5, H["bone"]), f"translate({x} {y}) rotate({r - 250})")
    body += skull(52, 58, 0.95)
    add(out, "menu/bait_mark", 128, 128, body)

    # E1 dropped-bundle glint (billboard) and E2 its charcoal map pictogram.
    sack = "M70 112 Q128 76 186 112 Q214 168 190 214 Q128 238 66 214 Q42 168 70 112Z"
    body = path(sack, p["cake"], ink, 8) + path("M92 128 Q128 108 164 128", "none", mix(p["cake"], ink, 0.35), 5)
    body += path("M128 92 V230 M52 164 Q128 190 204 164", "none", ink, 17) + path("M128 92 V230 M52 164 Q128 190 204 164", "none", p["rose"], 10)
    body += path("M100 96 Q128 60 156 96 Q128 108 100 96Z", p["cake"], ink, 7) + bow_knot(128, 102, 1.25, p["rose"], ink)
    body += star4(200, 62, 34, "#FFFFFF", p["gold"], 4) + star4(228, 104, 13, p["butter"], p["gold"], 3) + star4(52, 84, 16, "#FFFFFF", p["gold"], 3)
    add(out, "world/bundle_glint", 256, 256, body, half=True)
    ch = HUMAN["ink"]
    body = path(sack, "none", ch, 9) + path("M128 92 V230 M52 164 Q128 190 204 164", "none", ch, 7)
    body += path("M100 96 Q128 60 156 96 Q128 108 100 96Z", "none", ch, 8)
    body += path("M128 100 L96 84 V120Z M128 100 L160 84 V120Z", "none", ch, 7)
    body += path("M76 196 L96 176 M84 208 L108 184 M150 206 L176 180 M160 216 L186 190", "none", ch, 4, 'opacity="0.7"')
    add(out, "world/bundle_map_pictogram", 128, 128, g(body, "scale(0.5)"))

    # E3 awareness marks (optional, hostile lane): curious and alerted. Horror style.
    curl = [pol(64, 70, 34 - i * 1.5, 200 + i * 30) for i in range(17)]
    body = thorn_vine(curl, 6, H["bone"], H["ichor"], 4, 2.2, sw=2.5) + circ(64, 112, 6.5, H["bone"], H["ichor"], 2.5)
    add(out, "world/aware_curious", 128, 128, body)
    body = path("M52 10 L78 14 L70 46 L84 44 L66 86 L58 84 L62 52 L48 54Z", H["crimson"], H["ichor"], 4)
    body += path("M52 10 L40 22 M78 14 L92 20", "none", H["crimson"], 4) + path(pts_d([(64, 100), (74, 110), (64, 122), (54, 110)], True), H["crimson"], H["ichor"], 4)
    add(out, "world/aware_alerted", 128, 128, body)


def build(out):
    for p in (SPRING, HUMAN):
        p.setdefault("wood", "#C08A5B" if p is SPRING else "#7A6248")
        p.setdefault("cake", "#F2C98A" if p is SPRING else "#B89A6A")
    bases(out)
    pictos(out)
    tags(out)
    badges(out)
    small(out)
