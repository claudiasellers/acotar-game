"""The human village's people on the main cast's body (lane L52): the market and square villagers,
the travelling peddler, a Child of the Blessed and the ch 3 mercenary who buys the wolf pelt.

They replace the old skin-modifier figures of tools/blender/fae_people.py (thin tubes on a stick
skeleton, which read as skeletons in game).  The build reuses lane L48's minor-fae pipeline
(tools/blender/cast/build_minor_fae.py on Feyre's body): tools/blender/cast/build_village_people.py
imports cast_minor, then install() adds these designs and garments to it and points it at one id.

Canon (Keeper, 2026-11-02, ch 3 and ch 29-30):
- The village is poor, grim and ramshackle in winter; a tiny square with a broken fountain.  The poor
  wear cloaks and layers and have "that hungry look" [C]; cloth, cuts and colours are [X] (approved:
  patched wool in dun, grey and brown with faded pastel accents; no bright dyes on the poor).
- Iron is worn against the fae: a woman in "a full necklace of braided iron" as a status display;
  most people's iron is small and cheap [C].
- The mercenary is a WOMAN [C]: "a mountain of a woman", massive, thick dark hair shorn to her
  chin, tan granite face, night-dark eyes, a heavy coat over trousers, "gleaming and wicked"
  weapons (types [X]), scarred hands chapped from the cold.  Her bitten forearm and poisoned leg
  stay covered.
- The Children of the Blessed [C]: a pale-robed young woman in pale blue robes, silver jewellery and
  a bracelet of real silver bells, moon-white hands, unbound dark hair, a clean, spotless face.  No
  dirt or patching: the one spotless thing in the square.
- The peddler: travelling, no description [X].
"""

import math

import numpy as np
from mathutils import Vector as V

import cast_common as cc

# ---------------------------------------------------------------------------
# Bodies: humans, so round ears (fae_ears 0).  Thin from a hungry winter, but fleshed out.
# ---------------------------------------------------------------------------
_HUMAN = dict(fae_ears=0.0)


def shapes(cm):
    """cast_shape parameters per body kind, built on cast_minor's FEMALE/MALE/ROUND/BROAD."""
    lean_f = dict(cm.FEMALE, **_HUMAN, cheeks=0.75, cheekbones=0.6, waist=0.94, belly=0.9, thigh=0.96, arm=0.96)
    lean_m = dict(cm.MALE, **_HUMAN, gaunt=0.18, ribs=1.02, waist=1.02, belly=0.85, arm=1.02, forearm=1.02)
    elder = dict(cm.ROUND, **_HUMAN, cheeks=1.0, bust=1.05, waist=1.18, belly=1.2, eye_open_up=33.0, eye_open_lo=28.0)
    stout_m = dict(cm.BROAD, **_HUMAN, belly=1.05, waist=1.16)
    # "a mountain of a woman": a woman's face on a big, heavy frame; strong jaw, no softness
    mountain = dict(cm.FEMALE, **_HUMAN, eye_r=0.0190, eye_open_up=31.0, eye_open_lo=28.0, eye_tilt=2.0,
                    cheeks=0.25, cheekbones=0.9, jaw=0.6, jaw_w=1.04, chin=1.12, nose=1.05, nose_bridge=0.7,
                    lips=1.0, lip_w=1.05, face_w=1.04, neck=1.18,
                    bust=1.05, ribs=1.16, waist=1.20, belly=1.0, pelvis=1.08, seat=1.06, lats=1.15,
                    thigh=1.18, calf=1.12, arm=1.20, forearm=1.18, deltoid=1.15, hand=1.12)
    return {"v_female": lean_f, "v_male": lean_m, "v_elder": elder, "v_stout": stout_m, "v_mountain": mountain}


def warp(cm, kind, height):
    if kind == "v_mountain":
        return dict(height=height, head=1.0, legs=1.02, arm_len=1.02, arm_thick=1.12,
                    wx=((0.0, 1.06), (0.45, 1.06), (0.85, 1.06), (1.00, 1.10), (1.15, 1.18), (1.285, 1.22),
                        (1.37, 1.08), (1.47, 1.0)),
                    wy=((0.0, 1.04), (0.85, 1.06), (1.05, 1.10), (1.25, 1.10), (1.40, 1.04), (1.47, 1.0)))
    base = {"v_female": "female", "v_male": "male", "v_elder": "round", "v_stout": "broad"}[kind]
    return cm.warp(height, base)


# ---------------------------------------------------------------------------
# Palette: winter-poor wool, faded pastels (rose, lilac, periwinkle, butter, mint) under grey and dun.
# ---------------------------------------------------------------------------
OAT, DUN, DUN_D, BARK, SLATE = "C9BFAE", "7C7466", "625B50", "5A4A3E", "6E7078"
ROSE_F, LILAC_F, PERI_F, BUTTER_F, MINT_F = "A8868A", "9A8EA8", "8790A8", "C2B48A", "8E9E8E"
IRON = "4A4C51"
SILVER = "C8CCD6"

# Men's layers on the father's cut (cast_father.build_outfit: shirt, vest, long coat, trousers, shoes;
# patched elbows, a darned knee, a missing button).  o = shirt hex, vest, vest trim, trousers, shoes,
# and the coat's palette.
def _men(shirt, vest, trim, trousers, shoe, coat, lining, patch_a, patch_b):
    return dict(shirt=shirt, vest=(vest, 0.9, 0.0), vest_trim=(trim, 0.9, 0.0), trousers=(trousers, 0.85, 0.0),
                shoe=(shoe, 0.75, 0.0),
                pal={"fabric": (coat, 0.85, 0.0), "lining": (lining, 0.85, 0.0), "trim": (coat, 0.85, 0.0),
                     "chain": ("5B4636", 0.55, 0.0), "patch_a": (patch_a, 0.9, 0.0), "patch_b": (patch_b, 0.9, 0.0),
                     "thread": ("B9B09C", 0.85, 0.0)})


DESIGNS = {
    # -- the egg seller at the market stall: dress, apron, a hooded shawl, a cheap iron bangle
    "human_woman": dict(canon="X", body="v_female", height=1.63, skin="EBC6AE", iris="5E6A48", hair="6B4A30",
                        brows="4E3626", lips="B07468", style=("alis", "style_bun"),
                        outfit=[("dress", ROSE_F, "86686A"), ("apron",), ("slippers", "4E3A2E"),
                                ("shawl", LILAC_F, "7E7490"), ("iron_bangle", 1, "band")]),
    # -- the man by the well: the father's layered cut in dun and faded periwinkle, an iron charm
    "human_man": dict(canon="X", body="v_male", height=1.77, skin="E0B494", iris="4A3A28", hair="5A4030",
                      brows="3E2C1E", lips="A8786A", style=("rhysand", "style_short"),
                      outfit=[("layers", _men("D6CEBB", PERI_F, "6E7690", "6A6258", "4E4038", DUN, OAT, BUTTER_F, ROSE_F)),
                              ("iron_charm",)]),
    # -- the old woman at the notice board: a full hooded cloak and the braided iron necklace (status)
    "human_elder": dict(canon="C", body="v_elder", height=1.55, skin="EBCDBC", iris="6A7A8A", hair="D2CEC8",
                        brows="A8A29A", lips="B08478", style=("alis", "style_bun"),
                        outfit=[("dress", SLATE, "585A62"), ("apron",), ("slippers", "4A3C34"),
                                ("cloak_worn", PERI_F, "6E7690", 0.36), ("iron_braid",)]),
    # -- the young man by the tavern: a belted wool tunic, a short hooded cape, boots
    "human_youth": dict(canon="X", body="v_male", height=1.74, skin="D9A888", iris="5A4630", hair="3A2A20",
                        brows="2E2018", lips="A87868", style=("village", "style_bob"),
                        outfit=[("tunic_wool", MINT_F, "6E7C6E"), ("trousers", "5E564C"), ("boots", "4A3A2E"),
                                ("cloak_worn", BARK, "6A584A", 0.46)]),
    # -- the travelling peddler: greying beard, a plum coat gone soft with road dust, a long cloak
    "peddler": dict(canon="X", body="v_stout", height=1.71, skin="D8AE90", iris="4A3A2A", hair="8E8478",
                    brows="6E665C", lips="A47C70", style=("father", "style_greying"),
                    outfit=[("layers", _men("CFC6B2", BUTTER_F, "8C8064", "5A5048", "3E3430", "7A6474", "9A8EA8", MINT_F, OAT)),
                            ("cloak_worn", "6A5A50", "54483E", 0.40), ("iron_charm",)]),
    # -- a Child of the Blessed: spotless pale blue robes, silver, silver bells, unbound dark hair
    "blessed": dict(canon="C", body="v_female", height=1.68, skin="F4E2DA", iris="5E7290", hair="2E2420",
                    brows="2A201C", lips="D08A94", style=("feyre", "loose"),
                    outfit=[("gown", "gown_garden", "BCCDE6", "E6ECF4"), ("slippers", "DCE4F0"),
                            ("robe_cloak", "A9BFE0"), ("silver", "charm_bracelet"), ("silver", "necklace_pendant"),
                            ("silver", "earrings_drop")]),
    # -- the mercenary at the broken fountain: heavy coat, trousers, boots, a sword and a long knife
    "mercenary": dict(canon="C", body="v_mountain", height=1.86, skin="C9946E", iris="2A1A12", hair="241A16",
                      brows="1E1612", lips="9E6C5E", style=("village", "style_bob"),
                      outfit=[("layers", _men("BDB2A0", "4E4A44", "3A3632", "3E3A36", "2E2622", "4A3A30", "6E3A36",
                                              "5A4A3E", "4E443A")),
                              ("weapons",)]),
}


# ---------------------------------------------------------------------------
# Garments (Feyre space; each returns the finished object or None)
# ---------------------------------------------------------------------------
def _cm():
    import sys
    return sys.modules["cast_minor"]


def layers(ctx, o):
    """Shirt, vest, long coat, trousers and shoes on the father's cut, in this figure's wool."""
    import cast_father
    rep = cast_father.build_outfit(ctx, o, _cm().ID + "_")
    print("\n".join(rep))
    return None


def shawl(ctx, colour, edge):
    """A short wool capelet over the shoulders, a frill of faded petals at the hem and a bow at the
    throat (Feyre's capelet cut in coarse wool)."""
    B = ctx.builder(_cm().ID + "_shawl", {"fabric": (colour, 0.88, 0.0), "lining": (edge, 0.9, 0.0)})
    ctx.bw.build_capelet(B, ctx.probe, ctx.sh, ctx.rng)
    return ctx.cloth(B, _cm().ID + "_shawl")


def cloak_worn(ctx, colour, edge, hem):
    import cast_nesta
    # the lining takes the outer colour: after decimation it pokes through the thin shell in places,
    # and a darker lining reads as holes in the cloak (seen in the L52 cloud shots)
    del edge
    pal = {"fabric": (colour, 0.88, 0.0), "lining": (colour, 0.9, 0.0), "patch": (ROSE_F, 0.9, 0.0),
           "cord": (OAT, 0.85, 0.0), "clasp": (IRON, 0.6, 0.7)}
    return cast_nesta.worn_cloak(ctx, _cm().ID + "_cloak", pal, hem=hem, hood=True)


def robe_cloak(ctx, colour):
    """The Blessed's long pale robe over the gown: Feyre's velvet cloak, spotless, a silver clasp."""
    B = ctx.builder(_cm().ID + "_robe", {"fabric": (colour, 0.5, 0.0), "lining": ("E6ECF4", 0.5, 0.0),
                                         "chain": (SILVER, 0.25, 0.9), "trim": (SILVER, 0.25, 0.9)})
    ctx.bw.build_velvet_cloak(B, ctx.probe, ctx.sh, ctx.rng)
    return ctx.cloth(B, _cm().ID + "_robe")


def tunic_wool(ctx, fabric, trim):
    """A belted long-sleeved wool tunic: cast_minor's livery tunic, rough and matt, horn buttons."""
    cm = _cm()
    obj = cm.tunic(ctx, fabric, trim, True)
    for m in obj.data.materials:
        b = m.node_tree.nodes.get("Principled BSDF") if m and m.node_tree else None
        if b is None:
            continue
        b.inputs["Roughness"].default_value = max(b.inputs["Roughness"].default_value, 0.85)
        if "Metallic" in b.inputs:
            b.inputs["Metallic"].default_value = 0.0
        if "Coat Weight" in b.inputs:
            b.inputs["Coat Weight"].default_value = 0.0
    return obj


def iron_bangle(ctx, side, kind):
    import cast_nesta
    return cast_nesta.iron_bangle(ctx, "%s_iron_%d" % (_cm().ID, side), side=side, kind=kind)


def iron_charm(ctx):
    """A cheap iron charm on a cord at the throat."""
    B = ctx.builder(_cm().ID + "_charm", {"fabric": (IRON, 0.62, 0.85), "chain": ("6A5A48", 0.8, 0.0)})
    ctx.bw.build_necklace_pendant(B, ctx.probe, ctx.sh, ctx.rng)
    return ctx.cloth(B, _cm().ID + "_charm")


def iron_braid(ctx):
    """"A full necklace of braided iron" (ch 3): three twisted iron strands in a collar."""
    bw, probe = ctx.bw, ctx.probe
    B = ctx.builder(_cm().ID + "_ironbraid", {"fabric": (IRON, 0.58, 0.85)})
    for k, front in enumerate((1.300, 1.282, 1.264)):
        path = bw.neck_ring(probe, bw.chain_z(front), 0.0060 + 0.002 * k, 72)
        for strand in (0, 1):
            ph = np.linspace(0, 2 * math.pi * 18, len(path)) + strand * math.pi
            pts = path + np.stack([0.0012 * np.cos(ph), 0.0012 * np.sin(ph), 0.0012 * np.sin(ph)], 1)
            B.tube(pts, 0.0016, 4, "fabric", cap=False)
    B.mark("near", 0, fit=0.004)
    return ctx.cloth(B, _cm().ID + "_ironbraid")


def silver(ctx, piece):
    """The Blessed's real silver: bells on the bracelet, a pendant, drops at the ears."""
    pal = {"fabric": (SILVER, 0.22, 0.95), "chain": (SILVER, 0.22, 0.95), "pearl": ("F4F2EE", 0.15, 0.0)}
    B = ctx.builder("%s_%s" % (_cm().ID, piece), pal)
    getattr(ctx.bw, "build_" + piece)(B, ctx.probe, ctx.sh, ctx.rng)
    if piece.startswith("earrings"):
        return ctx.head_piece(B, "%s_%s" % (_cm().ID, piece))
    return ctx.cloth(B, "%s_%s" % (_cm().ID, piece))


def weapons(ctx):
    """'Gleaming and wicked' (ch 3; types [X]): a sword belt buckled over the heavy coat, a
    broadsword at the left hip and a long knife at the right."""
    bw, probe = ctx.bw, ctx.probe
    B = ctx.builder(_cm().ID + "_weapons", {"leather_d": ("2E2420", 0.55, 0.0), "steel": ("B8BCC4", 0.25, 0.95),
                                            "brass": ("A8885A", 0.35, 0.8)}, first="leather_d")
    bw.belt(B, probe, 0.955, 0.040, "leather_d", off=0.040)
    for side, length, r0, z_off in ((100, 0.82, 0.034, 0.0), (-100, 0.36, 0.026, 0.02)):
        i0 = len(B.bm.verts)
        p, n = probe.on_torso(0.95 + z_off, side, 0.046)
        top = V(p) + V(n) * 0.010
        path = np.array([tuple(top + V((0.0, -0.08 * t, -length * t))) for t in np.linspace(0, 1, 8)])
        B.tube(path, list(np.linspace(r0, r0 * 0.7, 8)), 6, "leather_d", squash=0.55, up=V((0, 1, 0)))
        B.tube(path[-2:], [r0 * 0.75, r0 * 0.5], 6, "brass", squash=0.55, up=V((0, 1, 0)))   # chape
        guard = top + V((0, 0.004, 0.006))
        B.tube(np.array([tuple(guard + V((-0.05 if length > 0.5 else -0.03, 0, 0))),
                         tuple(guard + V((0.05 if length > 0.5 else 0.03, 0, 0)))]), 0.006, 6, "steel")
        B.tube(np.array([tuple(guard), tuple(guard + V((0.0, 0.012, 0.16 if length > 0.5 else 0.10)))]),
               0.011, 6, "leather_d")
        B.bead(guard + V((0.0, 0.014, 0.17 if length > 0.5 else 0.11)), 0.016, "brass", 6, 4)
        B.mark("near", i0, fit=0.04)
    return ctx.cloth(B, _cm().ID + "_weapons")


def style_bob(st):
    """Thick dark hair shorn to the chin (the mercenary, ch 3) and the shaggy village cut: the
    loose style of cast_tamlin, its back mass and side locks cut off at the jaw."""
    st.cap(thick=0.0070, back_extra=0.004)
    st.cap_locks(math.radians(6), n=26, off=0.0090, r=0.0080, front_sweep=True)
    for s in (1, -1):                                    # side locks to the jaw, over the ears
        st.skull_lock(s * math.radians(12), math.radians(64), s * math.radians(80), math.radians(-6), 0.013, 0.0090,
                      n=10, sag=math.radians(3))
        st.skull_lock(s * math.radians(40), math.radians(58), s * math.radians(100), math.radians(-10), 0.013, 0.0090,
                      n=10, sag=math.radians(3))
    st.back_mass(1.455, n=16, spread=0.022, r=0.0140, wave=0.003, arc=(100, 260))
    st.front_locks(1.50, n=2, r=0.0085, wave=0.003)


OUTFIT = {"layers": layers, "shawl": shawl, "cloak_worn": cloak_worn, "robe_cloak": robe_cloak,
          "tunic_wool": tunic_wool, "iron_bangle": iron_bangle, "iron_charm": iron_charm, "iron_braid": iron_braid,
          "silver": silver, "weapons": weapons}


# ---------------------------------------------------------------------------
def install(cm, vid):
    """Point cast_minor at village design `vid`: its DESIGNS, garments and every module global that
    cast_minor derives from the design at import time (see cast_minor.py after DESIGNS)."""
    D = DESIGNS[vid]
    cm.DESIGNS[vid] = D
    cm.OUTFIT.update(OUTFIT)
    cm.ID = vid
    cm.D = D
    body = D["body"]
    # cast_minor's kind names, which build_minor_fae keys the face bake and the stroll on
    cm.KIND = {"v_female": "female", "v_elder": "round", "v_mountain": "female", "v_male": "male",
               "v_stout": "broad"}[body]
    cm.HEIGHT = D["height"]
    cm.SHAPE = shapes(cm)[body]
    cm.WARP = warp(cm, body, cm.HEIGHT)
    cm.GAIT = "female" if cm.KIND in ("female", "round") else "male"
    cm.SKIN_SRGB = D["skin"]
    cm.SKIN_LINEAR = cc.srgb(D["skin"])
    cm.BLACK_EYES = False
    _i = np.array(cc.srgb(D["iris"]))
    cm.IRIS = (tuple(_i * 0.45), tuple(_i), tuple(np.minimum(_i * 1.6 + 0.05, 1.0)))
    cm.IRIS_FLECKS = 0.5
    cm.LASH = {"v_female": 1.1, "v_elder": 0.8, "v_mountain": 0.8}.get(body, 0.6)
    cm.LASH_LINEAR = cc.srgb("1A1210")
    cm.HAIR_RGB = cc.srgb(D["hair"])
    cm.BROWS_SRGB = D["brows"]
    cm.LIPS_SRGB = D["lips"]
    cm.CANON = D["canon"]
    cm.SKIN_TEX = ""
    return D
