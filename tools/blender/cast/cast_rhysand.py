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
black trousers, black riding boots.  Short hair swept back off the brow with
one loose lock.
"""

import math

import numpy as np

import cast_common as cc

HEIGHT = 1.91
SHAPE = dict(
    eye_r=0.0167, eye_open_up=24.0, eye_open_lo=22.0, eye_tilt=6.0, eye_open_w=63.0,
    cheeks=0.0, cheekbones=1.10, gaunt=0.0, jaw=0.88, jaw_w=0.85, chin=1.25, chin_drop=0.02, brow=0.9,
    nose=1.18, nose_bridge=1.0, lips=0.82, lip_w=1.02, fae_ears=1.0, face_w=0.92, neck=1.08,
    adams_apple=0.5,
    bust=0.0, pecs=0.9, ribs=1.08, waist=1.08, belly=0.82, pelvis=0.90, seat=0.60, lats=1.22,
    thigh=0.88, calf=1.0, arm=1.08, forearm=1.06, deltoid=1.14, hand=1.07,
)
WARP = dict(height=HEIGHT, head=1.05, legs=1.05, arm_len=1.01, arm_thick=1.0,
            wx=((0.0, 1.05), (0.45, 1.03), (0.85, 0.97), (1.00, 1.03), (1.15, 1.14), (1.285, 1.22),
                (1.37, 1.08), (1.47, 1.0)),
            wy=((0.0, 1.0), (0.85, 0.96), (1.05, 1.02), (1.25, 1.06), (1.40, 1.03), (1.47, 1.0)))
GAIT = "male"
SKIN_SRGB = "F2DCD2"                 # pale, cool porcelain
SKIN_LINEAR = cc.srgb(SKIN_SRGB)
IRIS = ((0.20, 0.08, 0.38), (0.52, 0.30, 0.82), (0.80, 0.66, 0.98))   # violet: outer, inner, lilac fleck
IRIS_FLECKS = 0.7
LASH = 0.70
LASH_LINEAR = cc.srgb("0E0E18")
HAIR_RGB = cc.srgb("161A2C")         # blue-black
BROWS_SRGB = "1C1E2C"
LIPS_SRGB = "B47C80"

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
                     [1.600, 1.598, 1.585, 1.540, 1.500, 1.470, 1.462])


def style_short(st):
    bh = cc.bh()
    st.cap(thick=0.0105, back_extra=0.0045, line=short_line)
    st.cap_locks(math.radians(-10), n=26, off=0.0115, r=0.0092, front_sweep=True)
    for s in (1, -1):                                        # swept back at the temples
        st.skull_lock(s * math.radians(14), math.radians(70), s * math.radians(82), math.radians(20), 0.012, 0.0090,
                      n=9, sag=math.radians(3))
    for k, th in enumerate((-14, -4, 6)):                    # lift off the brow, swept up and back
        st.skull_lock(math.radians(th), math.radians(40), math.radians(th * 1.6), math.radians(78), 0.016 - 0.002 * k,
                      0.0098, n=9, sag=-math.radians(6))
    cc.tuck_behind_ears(st)
    del bh
