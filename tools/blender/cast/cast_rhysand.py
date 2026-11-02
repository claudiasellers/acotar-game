"""Rhysand, the stranger at Calanmai (lore/03-characters/rhysand.md).

PROVISIONAL: the user co-designs his final look.  This is a finished-looking
first pass so no scene shows a primitive; keep the id, rig and file paths when
the look changes (L33's ch26 film loads characters/rhysand/rhysand_model.tscn).

Canon [C]: pale skin; short blue-black hair; violet eyes; no mask (the only
unmasked High Fae among Spring's); dark clothes; not of Spring.  Wings are not
shown in the Spring Court section.  Beautiful, still, amused.
[X]: 1.91 m, lean and long-limbed (between Lucien and Tamlin); a black
high-collared tunic with a short split skirt, fine silver thread at collar,
cuffs and hem and a line of small silver star buttons; a narrow black belt;
black trousers, black riding boots.  Short hair swept up and back off the brow
in fine, even locks.
"""

import math

import numpy as np

import cast_common as cc

HEIGHT = 1.91
SHAPE = dict(
    # face (L49): a storybook prince, "the most beautiful man I'd ever seen" (ch20) and "his perfect
    # face" (ch26) [C]; the shapes are [X]: long upswept almond eyes under heavy lids (the lazy,
    # amused look), low straight brows, wide cheekbones, a fine straight nose with a neat tip, a
    # refined, moderately square jaw with its corners under the outer irises and a defined chin (the
    # old jaw was too big and too long), a wide mouth with a full lower lip resting in a half smile
    # ("a half smile", ch20 [C]), and a warrior's neck.
    eye_r=0.0184, eye_open_up=21.0, eye_open_lo=20.0, eye_tilt=10.0, eye_open_w=65.0,
    eye_dx=0.0016, cut_reach=0.008, cut_soft=0.009, lid=0.80, eye_sink=0.75, eye_dz=-0.0010, brow_dz=-0.0006,
    cheeks=0.70, cheekbones=0.0, cheek_lift=0.003,
    jaw=0.45, jaw_w=0.86, jaw_taper=0.95, chin=1.05, chin_drop=0.006, chin_y=-0.003,
    brow=0.55, nose=0.92, nose_w=1.02, nose_up=0.08, nose_bridge=1.12, bridge_fill=1.2,
    lips=1.04, lip_upper=0.86, lip_lower=1.16, lip_w=1.80, lip_bow=1.0, smile=0.6,
    lower_fill=0.9, mouth_dy=0.006,
    fae_ears=1.0, face_w=1.0, neck=1.12, adams_apple=0.5,
    bust=0.0, pecs=0.9, ribs=1.08, waist=1.08, belly=0.82, pelvis=0.90, seat=0.60, lats=1.22,
    thigh=0.88, calf=1.0, arm=1.08, forearm=1.06, deltoid=1.14, hand=1.07,
)
WARP = dict(height=HEIGHT, head=1.05, legs=1.05, arm_len=1.01, arm_thick=1.0,
            wx=((0.0, 1.05), (0.45, 1.03), (0.85, 0.97), (1.00, 1.03), (1.15, 1.14), (1.285, 1.22),
                (1.37, 1.08), (1.47, 1.0)),
            wy=((0.0, 1.0), (0.85, 0.96), (1.05, 1.02), (1.25, 1.06), (1.40, 1.03), (1.47, 1.0)))
GAIT = "male"
SKIN_SRGB = "D8C6BF"                 # pale, cool porcelain (F2DCD2 under the 0.85 albedo cap, hue kept)
SKIN_LINEAR = cc.srgb(SKIN_SRGB)
IRIS = ((0.20, 0.08, 0.38), (0.52, 0.30, 0.82), (0.80, 0.66, 0.98))   # violet: outer, inner, lilac fleck
IRIS_FLECKS = 0.7                    # "a star-flecked violet gaze" (ch40) [C]
LASH = 1.0
LASH_STYLE = "strands"
LASH_COUNT = 24
LASH_FLICK = 0.35
LOWER_LASH = 0.35
FACE_TRIS = 6500                     # the close-up face budget the sisters use (L37)
# makeup-mask shapes (L49): dark, straight, strong brows with a low arch; a fine dark lash line
MASK = dict(shadow_h=21.0, liner_w=5.5, wing=6.0, wing_lift=8.0, lower_liner=0.40,
            blush=(0.056, 1.468, 0.021, 0.007),   # the "blush" channel is a contour under the cheekbones
            brow_arch=0.55, brow_peak=0.72, brow_weight=1.75)
# feyre_skin.gdshader makeup (L49): a smoky violet-grey lid, a soft dark lash line, the faintest cool
# contour on the cheekbones, a natural mouth; a cool lilac rim light (the Night Court against Spring).
MAKEUP = dict(lips_amount=0.72, lips_sheen=0.22, eyeshadow_color="5A4C5E", eyeshadow_amount=0.62,
              eyeshadow_sheen=0.15, liner_color="141220", liner_amount=0.85, blush_color="9C7C78",
              blush_amount=0.32, blush_sheen=0.0, subsurface=0.45, brows_amount=1.0, rim_color="D8D0FF", rim_amount=0.30)
LASH_LINEAR = cc.srgb("0E0E18")
HAIR_RGB = cc.srgb("131830")         # blue-black
BROWS_SRGB = "1C1E2C"
LIPS_SRGB = "9A6461"                 # a muted rose-brown

INK, INK_D, SILVER, SILVER_D = "2B2540", "1C1828", "D9DDEA", "A3A9BE"
PAL = {"fabric": (INK, 0.66, 0.0), "trim": (SILVER, 0.24, 0.9), "chain": (SILVER, 0.2, 0.95),
       "leather": ("2A2430", 0.5, 0.0), "leather_d": ("1C1820", 0.46, 0.0)}


def build(ctx):
    bw, bg, probe, sh = ctx.bw, ctx.bg, ctx.probe, ctx.sh
    rep = []
    # -- tunic: long sleeves, high collar, silver thread, a short split skirt
    B = ctx.builder("rhysand_tunic", PAL)
    hole = bw.neckline(0.028, 0.050, 1.350)
    bm = sh.make(lambda r, c: r in ("torso", "arms") and not hole(c),
                 lambda c: 0.0070, [bw.z_below(0.90)] + bw.x_beyond(0.590), max_tris=3200)
    bw.add_bm(B, bm, "fabric", "shell", fit=0.0070)
    bw.bind(B, bm, 0.0026, "trim", where=lambda p: p[2] > 1.2 and abs(p[0]) < 0.2, fit=0.0070)
    bw.bind(B, bm, 0.0036, "trim", where=lambda p: abs(p[0]) > 0.5, squash=1.5, fit=0.0070)
    bm.free()
    bw.peplum(B, probe, 0.95, 0.74, 0.050, ["fabric"] * 4 + ["trim"], 5, fold=(0.016, 8, 0.0), lmax=0.6,
              gap=0.040)
    bw.belt(B, probe, 0.962, 0.024, "leather_d", off=0.018)
    bw.buttons(B, probe, np.linspace(1.000, 1.300, 7), 0.0100, r=0.0040, mat="chain")
    rep.append(cc.tris_line(ctx.cloth(B, "rhysand_tunic")))

    # -- trousers + riding boots, all black
    B = ctx.builder("rhysand_trousers", {**PAL, "fabric": ("1E1A28", 0.7, 0.0)})
    bm = sh.make(lambda r, c: r == "legs" or (r == "torso" and c.z < 1.0),
                 lambda c: 0.0055, [bw.z_above(0.86), bw.z_below(0.28)], max_tris=3200)
    bw.add_bm(B, bm, "fabric", "shell", fit=0.0055)
    bm.free()
    rep.append(cc.tris_line(ctx.cloth(B, "rhysand_trousers")))
    B = ctx.builder("rhysand_boots", {**PAL, "fabric": ("1A1620", 0.4, 0.0)})
    bw.build_riding_boots(B, probe, sh, ctx.rng)
    rep.append(cc.tris_line(ctx.cloth(B, "rhysand_boots")))

    # -- hair
    obj, clear = ctx.hair_style("rhysand_short", style_short, HAIR_RGB)
    for m in obj.data.materials:                          # matte satin, not the kit's glossy coat (L49)
        bsdf = m.node_tree.nodes.get("Principled BSDF") if m and m.use_nodes else None
        if bsdf is not None:
            bsdf.inputs["Roughness"].default_value = 0.70
            bsdf.inputs["Coat Weight"].default_value = 0.0
            bsdf.inputs["Specular IOR Level"].default_value = 0.30
    rep.append(cc.tris_line(obj) + " crown_clear=%.4f" % clear)
    return rep


# ---------------------------------------------------------------------------
def short_line(theta):
    """Hairline: a natural brow line set low over the forehead (L49), short at the nape."""
    a = np.abs(theta) / math.pi
    return np.interp(a, [0.0, 0.12, 0.25, 0.40, 0.55, 0.75, 1.0],
                     [1.574, 1.574, 1.568, 1.534, 1.500, 1.470, 1.462])


def style_short(st):
    """Short, tousled black hair in strand clumps (L49): a thin cap for the scalp, then ~60 short
    clumps that flow from the crown forward and out at random lengths and lifts (an uneven,
    feathered silhouette), broad locks falling onto the forehead, and fine flyaways."""
    rng = np.random.default_rng(4949)
    st.cap(thick=0.0105, back_extra=0.0050, line=short_line, lift=0.006)
    st.cap_locks(math.radians(-12), n=30, off=0.0080, r=0.0072, front_sweep=False)
    # clumps: rings from the crown outwards; each flows away from the crown whorl (behind the top)
    for ph_deg, n, ln in ((78, 6, 18), (64, 12, 22), (50, 16, 24), (36, 18, 22), (22, 14, 18)):
        for i in range(n):
            th = math.radians(-180 + 360 * (i + rng.uniform(0.15, 0.85)) / n)
            if abs(th) < math.radians(40) and ph_deg <= 36:
                continue                                  # the forehead is the fringe's
            ph = math.radians(ph_deg + rng.uniform(-4, 4))
            flow = math.radians(rng.uniform(-14, 14))     # tousled: each clump turns its own way
            th1 = th + flow + (0.10 if th > 0 else -0.10) * (abs(th) > 0.3)
            ph1 = ph - math.radians(ln + rng.uniform(-6, 8))
            off = 0.0140 + rng.uniform(0.0, 0.0070) * (1.0 if ph_deg >= 50 else 0.6)
            st.skull_lock(th, ph, th1, ph1, off, rng.uniform(0.0058, 0.0080), n=8,
                          sag=-math.radians(rng.uniform(2, 7)))
    # locks falling over the forehead from a soft side part, the longest towards his right
    for k, (th0, th1, ph1, r) in enumerate(((-30, -40, 34, 0.0088), (-14, -22, 28, 0.0094), (0, -4, 26, 0.0090),
                                             (16, 14, 30, 0.0086), (30, 36, 36, 0.0080))):
        st.skull_lock(math.radians(th0), math.radians(72 - 2 * k), math.radians(th1), math.radians(ph1),
                      0.0090 + 0.0010 * (k % 2), r, n=11, sag=-math.radians(7))
    for s in (1, -1):                                     # short at the temples, over the ear tops
        st.skull_lock(s * math.radians(50), math.radians(52), s * math.radians(86), math.radians(4), 0.0120, 0.0080,
                      n=9, sag=-math.radians(3))
    for i in range(9):                                    # the nape grows down to the collar
        th = math.radians(140 + 80 * (i + 0.5) / 9)
        th = th if th <= math.pi else th - 2 * math.pi
        top = st.head.scalp(th, math.radians(-8), 0.008)
        st.hang(top, 0.045 + rng.uniform(0.0, 0.015), 0.006, r0=0.0080, r1=0.0040, wave=0.002)
    st.flyaways(n=7)
    cc.tuck_behind_ears(st)
