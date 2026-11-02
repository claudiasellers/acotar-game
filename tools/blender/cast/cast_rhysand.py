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
    # amused look), low straight brows, high sculpted cheekbones over a faint hollow, a fine straight
    # nose, a tapered jaw to a neat, short chin (the old jaw was too big and too long), and a mouth
    # that rests in a half smile ("a half smile", ch20 [C]).
    eye_r=0.0200, eye_open_up=21.0, eye_open_lo=17.0, eye_tilt=10.0, eye_open_w=65.0,
    eye_dx=0.0016, cut_reach=0.008, cut_soft=0.009, lid=1.0, eye_sink=0.75, eye_dz=-0.0010, brow_dz=-0.0006,
    cheeks=0.50, cheekbones=0.45, cheek_lift=0.003,
    jaw=0.30, jaw_w=0.80, jaw_taper=0.80, chin=0.95, chin_drop=0.004, chin_point=0.35, chin_y=-0.004,
    brow=0.55, nose=1.04, nose_w=0.84, nose_bridge=0.85, bridge_fill=0.8,
    lips=1.0, lip_upper=0.74, lip_lower=1.10, lip_w=1.34, lip_bow=0.6, smile=0.6,
    lower_fill=0.9, mouth_dy=0.006,
    fae_ears=1.0, face_w=0.95, neck=0.99, adams_apple=0.4,
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
LASH = 0.85
LASH_STYLE = "strands"
LASH_COUNT = 24
LASH_FLICK = 0.35
LOWER_LASH = 0.3
FACE_TRIS = 6500                     # the close-up face budget the sisters use (L37)
# makeup-mask shapes (L49): dark, straight, strong brows with a low arch; a fine dark lash line
MASK = dict(shadow_h=16.0, liner_w=4.5, wing=6.0, wing_lift=8.0, lower_liner=0.25,
            blush=(0.054, 1.486, 0.018, 0.008), brow_arch=0.55, brow_peak=0.72, brow_weight=1.75)
# feyre_skin.gdshader makeup (L49): a smoky violet-grey lid, a soft dark lash line, the faintest cool
# contour on the cheekbones, a natural mouth; a cool lilac rim light (the Night Court against Spring).
MAKEUP = dict(lips_amount=0.60, lips_sheen=0.30, eyeshadow_color="5E5470", eyeshadow_amount=0.35,
              eyeshadow_sheen=0.15, liner_color="141220", liner_amount=0.85, blush_color="B89AA8",
              blush_amount=0.18, blush_sheen=0.0, brows_amount=1.0, rim_color="D8D0FF", rim_amount=0.30)
LASH_LINEAR = cc.srgb("0E0E18")
HAIR_RGB = cc.srgb("161A2C")         # blue-black
BROWS_SRGB = "1C1E2C"
LIPS_SRGB = "A8686F"                 # a natural dusky rose

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
    rep.append(cc.tris_line(obj) + " crown_clear=%.4f" % clear)
    return rep


# ---------------------------------------------------------------------------
def short_line(theta):
    """Hairline: a clean brow line, cut high and short at the nape."""
    a = np.abs(theta) / math.pi
    return np.interp(a, [0.0, 0.12, 0.25, 0.40, 0.55, 0.75, 1.0],
                     [1.588, 1.588, 1.580, 1.540, 1.500, 1.470, 1.462])


def style_short(st):
    bh = cc.bh()
    st.cap(thick=0.0092, back_extra=0.0045, line=short_line)
    st.cap_locks(math.radians(-10), n=26, off=0.0115, r=0.0092, front_sweep=True)
    for s in (1, -1):                                        # swept back at the temples
        st.skull_lock(s * math.radians(14), math.radians(70), s * math.radians(82), math.radians(20), 0.012, 0.0090,
                      n=9, sag=math.radians(3))
    for k, th in enumerate((-30, -16, -3, 10, 24)):        # swept up and back off the brow: fine, even locks
        st.skull_lock(math.radians(th), math.radians(36), math.radians(th * 1.3), math.radians(80), 0.0115,
                      0.0078, n=10, sag=-math.radians(4))
    cc.tuck_behind_ears(st)
    del bh
