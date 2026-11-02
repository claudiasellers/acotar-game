"""The Spring Court's minor fae on the main cast's body (lane L48): the Calanmai revellers, the
cave trio, the masked household and the border sentries.  One module, many designs: the
design is picked by the MINOR_FAE environment variable, which tools/blender/cast/build_minor_fae.py
sets before build_cast imports this module.  Each design is data (DESIGNS) plus shared garment,
mask and hair builders, most of them borrowed from Feyre's wardrobe and the main cast.

Canon (Keeper, 2026-11-02):
- Calanmai (ch 20) [C]: hundreds of masked High Fae at the bonfire; masks and clothes not
  described [X].  Every Spring Court mask is a beast Tamlin can shift into (ch 9, Lucien:
  "to honor Tamlin's shape-shifting gifts. The servants, too") [C], so stag, hawk, hare and
  wolf masks are safe [X] choices.
- The cave trio (ch 20) [C]: unmasked, taller and leaner than Tamlin or Lucien, sharp-featured,
  pitch-black depthless eyes, slightly pointed teeth, pale too-long hands.  Clothes and hair [X].
- Household [C]: servants wear bird masks (Alis's is a simple brass bird, ch 6; ch 8-9);
  green-and-brown skin and long limbs among the lesser fae (ch 24).  No livery colours in the
  book [X].
- Sentries [C]: High Fae kept at the border; Tamlin can turn them into wolves (Andras).  The
  wolf mask is [X], from the shape-shifting rule.
"""

import math
import os

import numpy as np
from mathutils import Vector as V

import cast_common as cc

ID = os.environ.get("MINOR_FAE", "reveler_1")

# ---------------------------------------------------------------------------
# Bodies (cast_shape parameters) and warps
# ---------------------------------------------------------------------------
FEMALE = dict(
    eye_r=0.0212, eye_open_up=37.0, eye_open_lo=32.0, eye_tilt=4.0, eye_open_w=64.0,
    cheeks=1.0, cheekbones=0.4, chin=0.95, chin_drop=0.0, jaw_w=0.92, nose=0.88, nose_bridge=0.3,
    lips=1.15, lip_w=1.12, fae_ears=1.0, face_w=0.98, cranium=1.0, neck=0.97,
    bust=1.0, ribs=0.98, waist=0.96, belly=0.95, pelvis=1.0, seat=1.0,
    thigh=1.0, calf=1.0, arm=0.98, forearm=0.98, hand=1.0,
)
MALE = dict(
    eye_r=0.0172, eye_open_up=27.0, eye_open_lo=24.0, eye_tilt=5.0, eye_open_w=62.0,
    cheeks=0.0, cheekbones=1.0, gaunt=0.05, jaw=0.85, jaw_w=0.90, chin=1.2, chin_drop=0.02, brow=0.7,
    nose=1.12, nose_bridge=1.0, lips=0.80, lip_w=1.04, fae_ears=1.0, face_w=0.93, neck=1.08,
    adams_apple=0.5,
    bust=0.0, pecs=0.85, ribs=1.06, waist=1.08, belly=0.85, pelvis=0.92, seat=0.62, lats=1.15,
    thigh=0.92, calf=1.0, arm=1.08, forearm=1.06, deltoid=1.10, hand=1.06,
)
# taller and leaner than Tamlin or Lucien, sharp, beautiful, too-long hands (ch 20)
TRIO = dict(MALE, eye_r=0.0185, eye_open_up=30.0, eye_open_lo=27.0, eye_tilt=10.0, cheekbones=1.35, gaunt=0.40,
            jaw=0.7, jaw_w=0.82, chin=1.1, chin_point=0.5, nose=1.18, lips=0.74, fae_ears=1.25, face_w=0.88,
            pecs=1.10, ribs=1.10, waist=1.22, belly=0.95, pelvis=0.90, seat=0.50, lats=1.18, thigh=0.84, calf=0.90, arm=0.90, forearm=0.88,
            deltoid=0.95, hand=1.32)
ROUND = dict(FEMALE, cheeks=1.40, cheekbones=0.0, jaw_w=1.10, chin=1.15, face_w=1.08, neck=1.12, bust=1.25,
             ribs=1.14, waist=1.32, belly=1.40, pelvis=1.14, seat=1.20, thigh=1.18, calf=1.08, arm=1.18,
             forearm=1.12, hand=1.04, fae_ears=0.8)
BROAD = dict(MALE, pecs=1.0, ribs=1.12, waist=1.10, lats=1.25, deltoid=1.22, arm=1.16, forearm=1.12, thigh=1.02,
             neck=1.14, jaw=1.0, jaw_w=0.98)


def warp(height, kind):
    if kind == "trio":
        return dict(height=height, head=1.02, legs=1.12, arm_len=1.12, arm_thick=0.90,
                    wx=((0.0, 0.97), (0.45, 0.94), (0.85, 0.96), (1.00, 1.10), (1.15, 1.14), (1.285, 1.18),
                        (1.37, 1.0), (1.47, 1.0)),
                    wy=((0.0, 0.96), (0.85, 0.92), (1.05, 0.95), (1.25, 0.98), (1.40, 1.0), (1.47, 1.0)))
    if kind == "male":
        return dict(height=height, head=1.03, legs=1.05, arm_len=1.02, arm_thick=1.02,
                    wx=((0.0, 1.02), (0.45, 1.0), (0.85, 0.96), (1.00, 1.02), (1.15, 1.12), (1.285, 1.18),
                        (1.37, 1.06), (1.47, 1.0)),
                    wy=((0.0, 1.0), (0.85, 0.96), (1.05, 1.02), (1.25, 1.05), (1.40, 1.02), (1.47, 1.0)))
    if kind == "broad":
        return dict(height=height, head=1.02, legs=1.03, arm_len=1.02, arm_thick=1.10,
                    wx=((0.0, 1.05), (0.45, 1.04), (0.85, 1.02), (1.00, 1.08), (1.15, 1.20), (1.285, 1.26),
                        (1.37, 1.10), (1.47, 1.0)),
                    wy=((0.0, 1.02), (0.85, 1.02), (1.05, 1.08), (1.25, 1.10), (1.40, 1.04), (1.47, 1.0)))
    if kind == "round":
        return dict(height=height, head=1.02, legs=0.95, arm_len=0.97, arm_thick=1.08,
                    wx=((0.0, 1.06), (0.45, 1.10), (0.85, 1.16), (1.00, 1.18), (1.15, 1.14), (1.28, 1.08),
                        (1.47, 1.0)),
                    wy=((0.0, 1.04), (0.85, 1.10), (1.00, 1.16), (1.15, 1.12), (1.30, 1.04), (1.47, 1.0)))
    return dict(height=height, head=1.015, legs=1.0, arm_len=1.0, arm_thick=1.0,
                wx=((0.0, 1.0), (1.47, 1.0)), wy=((0.0, 1.0), (1.47, 1.0)))


# ---------------------------------------------------------------------------
# Designs.  Colours are sRGB hex.  canon: C = described in the book, X = invented (see header).
# ---------------------------------------------------------------------------
DESIGNS = {
    # -- Calanmai revellers: masked Spring High Fae in their festival best (ch 20) ------------------
    "reveler_1": dict(canon="X", body="female", height=1.74, skin="F3CDB9", iris="3F7A5A", hair="8A3A22",
                      lips="D9707E", brows="6E3420", style=("feyre", "rose_bun"),
                      outfit=[("gown", "gown_garden", "F7E2A0", "FFF6E4"), ("slippers", "E9C27A")],
                      mask=("stag", "D8B25A", "FFF3DC"), extras=[("earrings", "earrings_pearl")]),
    "reveler_2": dict(canon="X", body="male", height=1.86, skin="D9A688", iris="4C3A7A", hair="3A2416",
                      brows="2E1C12", lips="B47A68", style=("lucien", "style_half_up"),
                      outfit=[("tunic", "8F9DE2", "E9D49A", True), ("trousers", "F2EBDD"), ("boots", "8C6446")],
                      mask=("hawk", "D4AE5E", "F6E7C4")),
    "reveler_3": dict(canon="X", body="female", height=1.70, skin="F7DCCD", iris="6C8FC8", hair="EFE2C6",
                      lips="E58AA0", brows="B8A07C", style=("feyre", "soft_curls"),
                      outfit=[("gown", "gown_ball", "CDB4F2", "FFF4FA"), ("slippers", "E7D6FA")],
                      mask=("hare", "E8E6EE", "F4C6D8"), extras=[("earrings", "earrings_drop")]),
    # -- the cave trio: unmasked, beautiful, wrong (ch 20) ---------------------------------------------
    "calanmai_1": dict(canon="C", body="trio", height=2.08, skin="E9E7EC", iris="black", hair="E8E6EE",
                       brows="9A9AA8", lips="A88D98", style=("feyre", "loose"),
                       outfit=[("tunic", "232838", "8E93A8", False), ("trousers", "161922"), ("boots", "121318")]),
    "calanmai_2": dict(canon="C", body="trio", height=2.12, skin="DCDDE5", iris="black", hair="141218",
                       brows="141218", lips="9C8290", style=("lucien", "style_half_up"),
                       outfit=[("tunic", "3A2536", "A68A9C", False), ("trousers", "1A1418"), ("boots", "140F12")]),
    "calanmai_3": dict(canon="C", body="trio", height=2.05, skin="EFE7E2", iris="black", hair="C9B79C",
                       brows="8E7E66", lips="A68A84", style=("tamlin", "style_loose"),
                       outfit=[("tunic", "1E3530", "86A39A", False), ("trousers", "141C1A"), ("boots", "101412")]),
    # -- the masked household, true forms (lesser fae under the bird masks, ch 6-9, 24) ---------------
    "servant_maid_true": dict(canon="X", body="female", height=1.66, skin="A9D6A6", iris="5A3A20", hair="3E6B4A",
                              brows="2E4F36", lips="C78A8A", style=("feyre", "ballerina_bun"),
                              outfit=[("dress", "93A7D6", "6F84B8"), ("apron",), ("slippers", "6F84B8")],
                              mask=("bird", "C29A48", "E2C277")),
    "servant_footman_true": dict(canon="X", body="male", height=1.82, skin="D7C2E6", iris="5A4A2A", hair="6B5A80",
                                 brows="5A4A70", lips="B88A9A", style=("lucien", "style_half_up"),
                                 outfit=[("tunic", "5E8A68", "E2C277", True), ("trousers", "F1EADA"),
                                         ("boots", "4A3A2E")],
                                 mask=("bird", "C9A14E", "E9CF88")),
    "servant_cook_true": dict(canon="X", body="round", height=1.58, skin="9BAA84", iris="4A3018", hair="5A4630",
                              brows="3E3020", lips="A87068", style=("alis", "style_bun"),
                              outfit=[("dress", "D9B26F", "B08C50"), ("apron",), ("slippers", "5E4632")],
                              mask=("bird", "B98E40", "DDBB70")),
    # -- border sentries, High Fae (wolf masks: Tamlin turns sentries into wolves) --------------------
    "sentry_1": dict(canon="X", body="broad", height=1.92, skin="E2B596", iris="6A5A2A", hair="5A3A22",
                     brows="4A2E1A", lips="B07A66", style=("rhysand", "style_short"),
                     outfit=[("leathers", "7C8F62", "C9A55A"), ("boots", "4E3A28"), ("cloak", "4F6B44")],
                     mask=("wolf", "C9CDD6", "8E94A2")),
    "sentry_2": dict(canon="X", body="broad", height=1.88, skin="EED8C2", iris="4A6A8A", hair="C9A46A",
                     brows="9A7A48", lips="BE8676", style=("tamlin", "style_loose"),
                     outfit=[("leathers", "8A8A80", "D9BE72"), ("boots", "3E3022"), ("cloak", "6A5A84")],
                     mask=("wolf", "D2C6A8", "9A8A62")),
}

D = DESIGNS[ID]
KIND = D["body"]
HEIGHT = D["height"]
SHAPE = {"female": FEMALE, "male": MALE, "trio": TRIO, "round": ROUND, "broad": BROAD}[KIND]
WARP = warp(HEIGHT, {"female": "female", "male": "male", "trio": "trio", "round": "round", "broad": "broad"}[KIND])
GAIT = "female" if KIND in ("female", "round") else "male"
SKIN_SRGB = D["skin"]
SKIN_LINEAR = cc.srgb(SKIN_SRGB)
BLACK_EYES = D["iris"] == "black"
if BLACK_EYES:
    IRIS = ((0.010, 0.010, 0.016), (0.020, 0.020, 0.030), (0.06, 0.06, 0.09))
    IRIS_FLECKS = 0.0
else:
    _i = np.array(cc.srgb(D["iris"]))
    IRIS = (tuple(_i * 0.45), tuple(_i), tuple(np.minimum(_i * 1.6 + 0.05, 1.0)))
    IRIS_FLECKS = 0.5
LASH = 1.2 if KIND in ("female", "round") else 0.7
LASH_LINEAR = cc.srgb("1A1210")
HAIR_RGB = cc.srgb(D["hair"])
BROWS_SRGB = D["brows"]
LIPS_SRGB = D["lips"]
CANON = D["canon"]


# ---------------------------------------------------------------------------
def build(ctx):
    rep = []
    for piece in D["outfit"]:
        obj = OUTFIT[piece[0]](ctx, *piece[1:])
        if obj is not None:
            rep.append(cc.tris_line(obj))
    if "mask" in D:
        kind, metal, accent = D["mask"]
        rep.append(cc.tris_line(MASKS[kind](ctx, metal, accent)))
    for kind, name in D.get("extras", []):
        B = ctx.builder("%s_%s" % (ID, name), {"fabric": ("F6EFE4", 0.15, 0.0)})
        getattr(ctx.bw, "build_" + name)(B, ctx.probe, ctx.sh, ctx.rng)
        rep.append(cc.tris_line(ctx.head_piece(B, "%s_%s" % (ID, name))))
    mod, fn = D["style"]
    obj, clear = ctx.hair_style(ID + "_hair", _style(mod, fn), HAIR_RGB)
    rep.append(cc.tris_line(obj) + " crown_clear=%.4f" % clear)
    if BLACK_EYES:
        import cast_summer_faerie
        cast_summer_faerie.black_eyes()
    return rep


def _style(mod, fn):
    if mod == "feyre":
        return cc.bh().STYLES[fn]
    import importlib
    f = getattr(importlib.import_module("cast_" + mod), fn)
    if mod in ("summer_faerie", "lucien", "rhysand"):
        return f                    # these already tuck the hair behind High Fae ears

    def tucked(st):
        f(st)
        cc.tuck_behind_ears(st)
    return tucked


def _pal(fabric, trim=None, rough=0.42):
    p = {"fabric": (fabric, rough, 0.0), "lining": (trim or fabric, 0.45, 0.0)}
    if trim:
        p["trim"] = (trim, 0.30, 0.55)
        p["chain"] = (trim, 0.28, 0.70)
    return p


# ---------------------------------------------------------------------------
# Garments
# ---------------------------------------------------------------------------
def gown(ctx, which, fabric, lining):
    bg = ctx.bg
    pal = {**bg.GOWNS[which]["pal"], "fabric": (fabric, 0.32, 0.0), "lining": (lining, 0.40, 0.0)}
    B = ctx.builder(ID + "_gown", pal)
    bg.GOWNS[which]["fn"](B, ctx.probe, ctx.rng)
    return ctx.gown(B, ID + "_gown")


def slippers(ctx, colour):
    B = ctx.builder(ID + "_shoes", {"fabric": (colour, 0.45, 0.0), "lining": (colour, 0.5, 0.0)})
    ctx.bw.build_slippers(B, ctx.probe, ctx.sh, ctx.rng)
    return ctx.cloth(B, ID + "_shoes")


def boots(ctx, colour):
    B = ctx.builder(ID + "_boots", {"fabric": (colour, 0.42, 0.0), "lining": (colour, 0.5, 0.0)})
    ctx.bw.build_riding_boots(B, ctx.probe, ctx.sh, ctx.rng)
    return ctx.cloth(B, ID + "_boots")


def tunic(ctx, fabric, trim, skirted):
    """A fitted long-sleeved tunic; `skirted` adds a flared peplum, gold buttons and a belt (court
    and livery); plain (the trio) is a close dark coat with a high collar and fine piping."""
    bw, probe, sh = ctx.bw, ctx.probe, ctx.sh
    pal = {**_pal(fabric, trim, 0.42 if skirted else 0.88), "leather_d": ("3A2A20", 0.45, 0.0)}
    B = ctx.builder(ID + "_tunic", pal)
    hole = bw.neckline(0.040 if skirted else 0.026, 0.054, 1.345)
    bm = sh.make(lambda r, c: r in ("torso", "arms") and not hole(c),
                 lambda c: 0.0065, [bw.z_below(0.90)] + bw.x_beyond(0.590), max_tris=3000)
    bw.add_bm(B, bm, "fabric", "shell", fit=0.0065)
    bw.bind(B, bm, 0.0028, "trim", where=lambda p: p[2] > 1.2 and abs(p[0]) < 0.2, fit=0.0065)
    bw.bind(B, bm, 0.0040, "trim", where=lambda p: abs(p[0]) > 0.5, squash=1.5, fit=0.0065)
    bm.free()
    if skirted:
        bw.peplum(B, probe, 0.95, 0.68, 0.075, ["fabric"] * 4 + ["trim"], 6, fold=(0.022, 7, 0.0), lmax=0.6, gap=0.030)
        bw.belt(B, probe, 0.965, 0.026, "leather_d", off=0.016)
        bw.buttons(B, probe, np.linspace(1.02, 1.30, 6), 0.0100, r=0.0042, mat="chain")
    else:
        bw.peplum(B, probe, 0.95, 0.40, 0.075, ["fabric"] * 7 + ["trim"], 8, fold=(0.018, 9, 0.0), lmax=0.7, gap=0.030)
        bw.belt(B, probe, 0.962, 0.016, "trim", off=0.016, buckle=None)
        bw.buttons(B, probe, np.linspace(1.00, 1.31, 9), 0.0085, r=0.0034, mat="chain")   # a close row of silver
        bw.belt(B, probe, 1.335, 0.020, "trim", off=0.010, buckle=None)                     # a high collar band
    return ctx.cloth(B, ID + "_tunic")


def trousers(ctx, colour):
    bw = ctx.bw
    B = ctx.builder(ID + "_trousers", {"fabric": (colour, 0.78, 0.0)})
    bm = ctx.sh.make(lambda r, c: r == "legs" or (r == "torso" and c.z < 1.0),
                     lambda c: 0.0055, [bw.z_above(0.86), bw.z_below(0.28)], max_tris=2800)
    bw.add_bm(B, bm, "fabric", "shell", fit=0.0055)
    bm.free()
    return ctx.cloth(B, ID + "_trousers")


def dress(ctx, fabric, lining):
    """The household's working dress: Alis's cut in this servant's colours."""
    import cast_alis
    cast_alis.PAL = {**cast_alis.PAL, "fabric": (fabric, 0.70, 0.0), "lining": (lining, 0.75, 0.0)}
    obj = cast_alis.build_dress(ctx)
    obj.name = ID + "_dress"
    return obj


def apron(ctx):
    import cast_alis
    obj = cast_alis.build_apron(ctx)
    obj.name = ID + "_apron"
    return obj


def leathers(ctx, fabric, trim):
    """A sentry's kit: Feyre's woods leathers cut for him, a brass-buckled belt with a sheathed
    sword at the left hip."""
    bw, probe = ctx.bw, ctx.probe
    B = ctx.builder(ID + "_leathers", {**_pal(fabric, trim, 0.55), "leather_d": ("3A2A1E", 0.45, 0.0)})
    bw.build_woods_leathers(B, probe, ctx.sh, ctx.rng)
    bw.belt(B, probe, 0.965, 0.034, "leather_d", off=0.020)
    i0 = len(B.bm.verts)                                    # scabbard hanging from the left hip
    p, n = probe.on_torso(0.95, 100, 0.030)
    top = V(p) + V(n) * 0.012
    path = np.array([tuple(top + V((0.0, -0.06 * t, -0.62 * t))) for t in np.linspace(0, 1, 8)])
    B.tube(path, [0.022, 0.020, 0.019, 0.018, 0.017, 0.016, 0.014, 0.008], 6, "leather_d", squash=0.45,
           up=V((0, 1, 0)))
    B.tube(np.array([tuple(top + V((0, 0, 0.004))), tuple(top + V((0.0, 0.01, 0.13)))]), 0.012, 6, "trim")
    B.mark("near", i0, fit=0.03)
    return ctx.cloth(B, ID + "_leathers")


def cloak(ctx, colour):
    B = ctx.builder(ID + "_cloak", {"fabric": (colour, 0.6, 0.0), "lining": (colour, 0.7, 0.0)})
    ctx.bw.build_velvet_cloak(B, ctx.probe, ctx.sh, ctx.rng)
    return ctx.cloth(B, ID + "_cloak")


OUTFIT = {"gown": gown, "slippers": slippers, "boots": boots, "tunic": tunic, "trousers": trousers,
          "dress": dress, "apron": apron, "leathers": leathers, "cloak": cloak}


# ---------------------------------------------------------------------------
# Masks: every one a beast Tamlin can become (ch 9)
# ---------------------------------------------------------------------------
def _mask_builder(ctx, name, metal, accent):
    return ctx.builder(name, {"fabric": (metal, 0.28, 0.85), "chain": (accent, 0.25, 0.6),
                              "cord": (accent, 0.35, 0.2), "gem": ("2A1E14", 0.2, 0.3), "pearl": ("FFF6EC", 0.15, 0.0)})


def mask_bird(ctx, metal, accent):
    """The household's bird mask (Alis's brass bird, ch 6), in this servant's metal."""
    import cast_alis
    B = _mask_builder(ctx, ID + "_mask", metal, accent)
    cast_alis.build_mask(B, ctx)
    return ctx.head_piece(B, ID + "_mask")


def mask_hawk(ctx, metal, accent):
    """A gilded hawk: the bird mask with long swept brow feathers and pearl-set eyes."""
    import cast_alis
    bw = ctx.bw
    B = _mask_builder(ctx, ID + "_mask", metal, accent)
    cast_alis.build_mask(B, ctx)
    i0 = len(B.bm.verts)
    for s in (1, -1):
        for k in range(4):                                 # long feathers sweeping back over the temples
            a = V((s * (0.070 + 0.006 * k), 0.000 + 0.012 * k, 1.552 - 0.010 * k))
            b = a + V((s * 0.040, 0.075, 0.030 - 0.010 * k))
            path = np.array([tuple(a.lerp(b, t) + V((0, 0, 0.012 * math.sin(math.pi * t)))) for t in np.linspace(0, 1, 7)])
            B.tube(path, [0.0050, 0.0068, 0.0070, 0.0062, 0.0048, 0.0030, 0.0008], 6, "chain" if k % 2 else "fabric",
                   squash=0.35, up=V((0, 0, 1)))
        B.bead(bw.on_face(ctx.probe, s * 0.058, 1.548, 0.0050)[0], 0.0032, "pearl", 5, 3)
    B.mark("acc", i0)
    return ctx.head_piece(B, ID + "_mask")


def mask_stag(ctx, metal, accent):
    """A gilt stag: a leafy brow mask and branching antlers rising from the temples."""
    bw, probe = ctx.bw, ctx.probe
    B = _mask_builder(ctx, ID + "_mask", metal, accent)

    def sdf(X, Z):
        d = bw.sd_ellipse(X, Z, 0.0, 1.522, 0.080, 0.034)
        for s in (1, -1):
            d = bw.bg_smin(d, bw.sd_leaf(X, Z, (s * 0.050, 1.540), (s * 0.092, 1.585), 0.012), 0.005)  # ears
            d = bw.bg_smin(d, bw.sd_leaf(X, Z, (s * 0.020, 1.500), (s * 0.060, 1.468), 0.010), 0.005)  # cheeks
        d = bw.bg_smin(d, bw.sd_tri(X, Z, (-0.014, 1.505), (0.014, 1.505), (0.0, 1.470)), 0.005)
        return np.maximum(d, -bw.eye_holes(X, Z))
    bw.mask_sheet(B, probe, sdf, h=0.0036, lift=0.0034)
    i0 = len(B.bm.verts)
    for s in (1, -1):
        root = V(bw.on_face(probe, s * 0.050, 1.556, 0.004)[0])
        beam = [root, root + V((s * 0.030, 0.012, 0.070)), root + V((s * 0.080, 0.040, 0.155)),
                root + V((s * 0.110, 0.070, 0.240)), root + V((s * 0.115, 0.105, 0.300))]
        B.tube(cc_smooth(beam, 16), np.linspace(0.0100, 0.0030, 16), 6, "fabric")
        for t, d, L in ((0.30, V((s * 0.050, -0.040, 0.050)), 1.0), (0.55, V((s * 0.055, -0.015, 0.060)), 0.9),
                        (0.78, V((-s * 0.015, -0.040, 0.070)), 0.75)):
            base = _along(beam, t)
            tine = [base, base + d * 0.5 * L + V((0, 0, 0.010)), base + d * L + V((0, 0, 0.025))]
            B.tube(cc_smooth(tine, 8), np.linspace(0.0055, 0.0016, 8), 6, "fabric")
        for k in range(3):                                   # pearls and little gold leaves along the beam
            B.bead(_along(beam, 0.12 + 0.18 * k) + V((0, -0.006, 0)), 0.0034, "pearl", 5, 3)
        bw.face_tube(B, probe, [(s * 0.012, 1.540), (s * 0.030, 1.552), (s * 0.052, 1.550)], 0.0012, 0.0050, "chain", 8)
    B.mark("acc", i0)
    return ctx.head_piece(B, ID + "_mask")


def mask_hare(ctx, metal, accent):
    """A silver hare: a soft rounded mask, a pink-lined pair of long ears standing up from the crown."""
    bw, probe = ctx.bw, ctx.probe
    B = _mask_builder(ctx, ID + "_mask", metal, accent)

    def sdf(X, Z):
        d = bw.sd_ellipse(X, Z, 0.0, 1.520, 0.078, 0.036)
        d = bw.bg_smin(d, bw.sd_ellipse(X, Z, 0.0, 1.486, 0.024, 0.016), 0.006)
        return np.maximum(d, -bw.eye_holes(X, Z))
    bw.mask_sheet(B, probe, sdf, h=0.0036, lift=0.0034)
    i0 = len(B.bm.verts)
    for s in (1, -1):
        base = V((s * 0.040, 0.015, 1.628))
        tip = base + V((s * 0.040, 0.030, 0.170))
        c = base.lerp(tip, 0.5)
        ax = (tip - base) * 0.5
        side = V((1, 0, 0)) if s > 0 else V((-1, 0, 0))
        B.ellipsoid(c, side * 0.024, V((0, 0.010, 0)), ax, "fabric", 8, 6)
        B.ellipsoid(c + V((0, -0.008, 0.004)), side * 0.015, V((0, 0.004, 0)), ax * 0.86, "cord", 8, 5)
        B.tube(np.array([tuple(bw.on_face(probe, s * 0.052, 1.548, 0.004)[0]), tuple(base)]), 0.006, 6, "fabric")
        for k in range(3):                                      # whisker pearls on the cheek
            B.bead(bw.on_face(probe, s * (0.022 + 0.010 * k), 1.482 - 0.004 * k, 0.0045)[0], 0.0024, "pearl", 4, 2)
    B.bead(bw.on_face(probe, 0.0, 1.490, 0.0060)[0], 0.0050, "cord", 6, 3)   # the nose
    B.mark("acc", i0)
    return ctx.head_piece(B, ID + "_mask")


def mask_wolf(ctx, metal, accent):
    """A sentry's steel wolf: tall pricked ears, a ridged brow and a short muzzle over the nose."""
    bw, probe = ctx.bw, ctx.probe
    B = _mask_builder(ctx, ID + "_mask", metal, accent)

    def sdf(X, Z):
        d = bw.sd_ellipse(X, Z, 0.0, 1.520, 0.086, 0.040)
        for s in (1, -1):
            d = bw.bg_smin(d, bw.sd_tri(X, Z, (s * 0.028, 1.548), (s * 0.084, 1.536), (s * 0.072, 1.625)), 0.006)
            d = bw.bg_smin(d, bw.sd_tri(X, Z, (s * 0.050, 1.505), (s * 0.094, 1.500), (s * 0.080, 1.455)), 0.006)
        return np.maximum(d, -bw.eye_holes(X, Z))
    bw.mask_sheet(B, probe, sdf, h=0.0036, lift=0.0036)
    i0 = len(B.bm.verts)
    top = V((0.0, -0.082, 1.532))
    path = np.array([tuple(top), (0.0, -0.098, 1.512), (0.0, -0.112, 1.492), (0.0, -0.118, 1.478), (0.0, -0.116, 1.470)])
    B.tube(path, [0.020, 0.020, 0.017, 0.012, 0.004], 10, "fabric", up=V((1, 0, 0)), squash=0.8)
    B.bead(V((0.0, -0.119, 1.481)), 0.0060, "gem", 6, 3)
    for s in (1, -1):
        bw.face_tube(B, probe, [(s * 0.010, 1.546), (s * 0.034, 1.560), (s * 0.060, 1.552)], 0.0018, 0.0055, "chain", 10)
        bw.face_tube(B, probe, [(s * 0.040, 1.570), (s * 0.058, 1.600)], 0.0012, 0.0050, "chain", 6)
    B.mark("acc", i0)
    return ctx.head_piece(B, ID + "_mask")


MASKS = {"bird": mask_bird, "hawk": mask_hawk, "stag": mask_stag, "hare": mask_hare, "wolf": mask_wolf}


def cc_smooth(ctrl, n):
    return cc.bg_smooth(ctrl, n) if hasattr(cc, "bg_smooth") else _smooth(ctrl, n)


def _smooth(ctrl, n):
    import sys
    return sys.modules["build_gowns"].smooth_curve(np.array([tuple(p) for p in ctrl]), n)


def _along(pts, t):
    P = [V(p) for p in pts]
    seg = [(P[i + 1] - P[i]).length for i in range(len(P) - 1)]
    goal = t * sum(seg)
    for i, L in enumerate(seg):
        if goal <= L or i == len(seg) - 1:
            return P[i].lerp(P[i + 1], min(goal / max(L, 1e-9), 1.0))
        goal -= L
    return P[-1]
