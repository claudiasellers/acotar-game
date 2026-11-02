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


def _m(base, *parts, **kw):
    out = dict(base)
    for p in parts:
        out.update(p)
    out.update(kw)
    return out


def shapes(cm):
    """cast_shape parameters per body kind, built on cast_minor's FEMALE/MALE/ROUND/BROAD.  Human
    faces, not the court's: smaller eyes with the upper lid over the top of the iris."""
    hf = dict(eye_r=0.0182, eye_open_up=30.0, eye_open_lo=27.0, eye_tilt=1.0)
    hm = dict(eye_r=0.0160, eye_open_up=23.0, eye_open_lo=22.0, eye_tilt=2.0)
    lean_f = _m(cm.FEMALE, _HUMAN, hf, cheeks=0.75, cheekbones=0.6, waist=0.94, belly=0.9, thigh=0.96, arm=0.96)
    plump_f = _m(cm.ROUND, _HUMAN, hf, cheeks=1.25, bust=1.2, waist=1.22, belly=1.25, seat=1.15, thigh=1.12)
    lean_m = _m(cm.MALE, _HUMAN, hm, gaunt=0.30, cheekbones=1.1, ribs=0.98, waist=0.98, belly=0.80, arm=0.96,
                  forearm=0.96, deltoid=0.98, thigh=0.88, calf=0.92)
    slight_m = _m(cm.MALE, _HUMAN, hm, eye_r=0.0168, gaunt=0.12, jaw=0.7, jaw_w=0.86, chin=1.05,
                    pecs=0.6, ribs=0.94, waist=0.96, lats=1.0, deltoid=0.9, arm=0.90, forearm=0.90, thigh=0.86,
                    calf=0.9, neck=0.98, adams_apple=0.3)
    elder = _m(cm.ROUND, _HUMAN, hf, eye_r=0.0172, eye_open_up=26.0, cheeks=1.0, bust=1.0, waist=1.15,
                 belly=1.15, gaunt=0.15)
    stout_m = _m(cm.BROAD, _HUMAN, hm, belly=1.15, waist=1.20)
    # "a mountain of a woman": tall and heavy, a woman's frame (hips, bust, a softer jaw) and a hard,
    # weathered face; big through the arms and thighs rather than the shoulders
    mountain = dict(cm.FEMALE, **_HUMAN, eye_r=0.0178, eye_open_up=27.0, eye_open_lo=25.0, eye_tilt=3.0,
                    cheeks=0.45, cheekbones=1.0, chin=1.0, jaw_w=0.96, nose=1.0, nose_bridge=0.6,
                    lips=1.08, lip_w=1.04, face_w=1.0, neck=1.08,
                    bust=1.12, ribs=1.08, waist=1.06, belly=0.98, pelvis=1.12, seat=1.12,
                    thigh=1.18, calf=1.12, arm=1.12, forearm=1.10, hand=1.06)
    return {"v_female": lean_f, "v_plump": plump_f, "v_male": lean_m, "v_slight": slight_m, "v_elder": elder,
            "v_stout": stout_m, "v_mountain": mountain}


def warp(cm, kind, height):
    if kind == "v_mountain":
        return dict(height=height, head=0.99, legs=1.02, arm_len=1.0, arm_thick=1.08,
                    wx=((0.0, 1.06), (0.45, 1.08), (0.85, 1.10), (1.00, 1.08), (1.15, 1.08), (1.285, 1.06),
                        (1.37, 1.02), (1.47, 1.0)),
                    wy=((0.0, 1.04), (0.85, 1.08), (1.05, 1.08), (1.25, 1.08), (1.40, 1.02), (1.47, 1.0)))
    if kind == "v_slight":
        return dict(height=height, head=1.03, legs=1.0, arm_len=1.0, arm_thick=0.92,
                    wx=((0.0, 0.96), (0.85, 0.94), (1.15, 0.96), (1.285, 0.98), (1.47, 1.0)),
                    wy=((0.0, 0.96), (0.85, 0.94), (1.25, 0.96), (1.47, 1.0)))
    base = {"v_female": "female", "v_plump": "round", "v_male": "male", "v_elder": "round",
            "v_stout": "broad"}[kind]
    return cm.warp(height, base)


# ---------------------------------------------------------------------------
# Palette: winter-poor humans in undyed wool, oatmeal, peat brown, slate, rust and faded madder,
# with one muted accent each (the Spring Court's lilac, mint, sky and blush stay over the Wall).
# Only the Children of the Blessed wear a clean pale blue.
# ---------------------------------------------------------------------------
UNDYED, OAT, PEAT, PEAT_D, SLATE, SLATE_D = "C4B8A2", "B3A68E", "5A4636", "463628", "5E636B", "4A4E56"
RUST, MADDER, DUN, MOSS_F, ASH = "8E5638", "8E5258", "7A6E5C", "6E7258", "8A847A"
IRON = "4A4C51"
SILVER = "C8CCD6"
BLESSED_BLUE, BLESSED_PALE = "A9BCD8", "C9D6E8"


# Men's layers on the father's cut (cast_father.build_outfit: shirt, vest, long coat, trousers, shoes;
# patched elbows, a darned knee, a missing button).  The patches are a different, lighter cloth so they
# read as sewn patches, not holes.
def _men(shirt, vest, trim, trousers, shoe, coat, lining, patch_a, patch_b):
    return dict(shirt=shirt, vest=(vest, 0.9, 0.0), vest_trim=(trim, 0.9, 0.0), trousers=(trousers, 0.85, 0.0),
                shoe=(shoe, 0.75, 0.0),
                pal={"fabric": (coat, 0.85, 0.0), "lining": (lining, 0.85, 0.0), "trim": (coat, 0.85, 0.0),
                     "chain": ("5B4636", 0.55, 0.0), "patch_a": (patch_a, 0.9, 0.0), "patch_b": (patch_b, 0.9, 0.0),
                     "thread": ("D8CDB6", 0.85, 0.0)})


DESIGNS = {
    # -- a plump, pretty farmer's wife selling eggs, wealthy enough for "a full necklace of braided iron"
    #    (ch 3): peat-brown dress, undyed apron, a faded-madder capelet
    "human_woman": dict(canon="C", body="v_plump", height=1.60, skin="EDC6AC", iris="6A5A3A", hair="7A5634",
                        brows="5A3E28", lips="B98078", style=("alis", "style_bun"),
                        outfit=[("dress", PEAT, PEAT_D), ("apron",), ("slippers", "3E3028"),
                                ("shawl", MADDER, "74424A"), ("iron_braid",)]),
    # -- a thin, hungry man by the well: undyed shirt, slate vest, peat coat with rust elbow patches
    "human_man": dict(canon="X", body="v_male", height=1.78, skin="DDB294", iris="5A4A34", hair="4E3828",
                      brows="3A2A1E", lips="B08A7C", style=("rhysand", "style_short"),
                      outfit=[("layers", _men(UNDYED, SLATE, SLATE_D, DUN, "3E3430", PEAT, OAT, RUST, OAT)),
                              ("iron_charm",)]),
    # -- the old woman at the notice board, stooped: slate dress, oatmeal hooded cloak, a cheap charm
    "human_elder": dict(canon="X", body="v_elder", height=1.54, skin="EBCDBC", iris="6A7480", hair="CFCAC2",
                        brows="A29C94", lips="C09A90", style=("alis", "style_bun"), stoop=1.8,
                        outfit=[("dress", SLATE, SLATE_D), ("apron",), ("slippers", "3E342E"),
                                ("cloak_worn", ASH, ASH, 0.36), ("iron_charm",)]),
    # -- the young man by the tavern, shorter and slighter: undyed shirt, rust vest, a slate cape
    "human_youth": dict(canon="X", body="v_slight", height=1.64, skin="E2B494", iris="5A4630", hair="4A3626",
                        brows="3A2A1E", lips="B48A7C", style=("village", "style_bob"),
                        outfit=[("layers", dict(_men(UNDYED, RUST, "6E4230", PEAT, "3E3028", PEAT, OAT, OAT, OAT),
                                                no_coat=True)),
                                ("cloak_worn", SLATE, SLATE, 0.50)]),
    # -- the travelling peddler, stout, greying beard: a rust coat gone soft with road dust, peat cloak
    "peddler": dict(canon="X", body="v_stout", height=1.71, skin="D8AE90", iris="4A3A2A", hair="8E8478",
                    brows="6E665C", lips="A88274", style=("father", "style_greying"),
                    outfit=[("layers", _men(UNDYED, OAT, DUN, "5A5048", "3E3430", RUST, OAT, MOSS_F, UNDYED)),
                            ("cloak_worn", PEAT, PEAT, 0.40), ("iron_charm",)]),
    # -- the Children of the Blessed (ch 3): plain floor-length pale blue robes, cord belt, real silver,
    #    bells at the wrist, long uncut hair, bare heads; spotless.  The speaker is a young woman with
    #    brown eyes and a clean, glowing face; five acolytes behind her, young men and women both.
    "blessed": dict(canon="C", body="v_female", height=1.68, skin="F4E6E0", iris="6A4A30", hair="2E2420",
                    brows="2A201C", lips="D4949C", style=("feyre", "loose"), face="glow",
                    outfit=[("robe", BLESSED_BLUE), ("slippers", BLESSED_PALE), ("cord_belt",),
                            ("silver", "charm_bracelet"), ("silver", "necklace_pendant")]),
    "blessed_2": dict(canon="C", body="v_slight", height=1.76, skin="F2E2D8", iris="4E5E70", hair="6A4A30",
                      brows="4E3626", lips="C49088", style=("tamlin", "style_loose"), face="glow",
                      outfit=[("robe", BLESSED_PALE), ("slippers", BLESSED_PALE), ("cord_belt",),
                              ("silver", "charm_bracelet")]),
    # -- the mercenary at the broken fountain: heavy peat coat with a rust lining, sword and long knife
    "mercenary": dict(canon="C", body="v_mountain", height=1.86, skin="C9946E", iris="3A2418", hair="241A16",
                      brows="1E1612", lips="A8705E", style=("village", "style_bob"),
                      outfit=[("layers", _men("BDB2A0", "3E3A36", "2E2A26", "3A3632", "2A2420", PEAT_D, RUST,
                                              "5A4A3E", "6A5A4A")),
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
    import bpy
    import cast_father
    rep = cast_father.build_outfit(ctx, o, _cm().ID + "_")
    if o.get("no_coat"):                      # shirt and vest only: the youth goes without a coat
        coat = bpy.data.objects[_cm().ID + "_coat"]
        ctx.wardrobe[:] = [(ob, k) for ob, k in ctx.wardrobe if ob is not coat]
        bpy.data.objects.remove(coat)
        rep = [r for r in rep if "_coat" not in r]
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
    pal = {"fabric": (colour, 0.88, 0.0), "lining": (colour, 0.9, 0.0), "patch": (UNDYED, 0.9, 0.0),
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
    obj = cm.tunic(ctx, fabric, trim, False)    # the straight cut: a flared peplum read as a skirt
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


def apron(ctx):
    """Alis's apron in undyed linen gone grey with wear; the pocket the same cloth."""
    import cast_alis
    cast_alis.PAL = {**cast_alis.PAL, "apron": ("CFC5B2", 0.85, 0.0), "apron_d": ("C2B8A4", 0.85, 0.0),
                     "cord": ("B3A68E", 0.85, 0.0)}
    obj = cast_alis.build_apron(ctx)
    obj.name = _cm().ID + "_apron"
    return obj


def robe(ctx, colour):
    """The Blessed's plain floor-length robe: Alis's long-sleeved dress cut in clean pale blue wool,
    the long cloak over it with the hood thrown back."""
    cm = _cm()
    obj = cm.dress(ctx, colour, colour)
    rep = robe_cloak(ctx, colour)
    del rep
    return obj


def cord_belt(ctx):
    """A plain white cord tied at the waist, the ends hanging."""
    bw, probe = ctx.bw, ctx.probe
    B = ctx.builder(_cm().ID + "_cord", {"fabric": ("E8E6E0", 0.7, 0.0)})
    bw.belt(B, probe, 0.975, 0.008, "fabric", off=0.022, buckle=None)
    i0 = len(B.bm.verts)
    p, n = probe.on_torso(0.975, -20, 0.030)
    for dx, L in ((-0.008, 0.30), (0.010, 0.26)):
        path = np.array([tuple(V(p) + V((dx, -0.004 * t, -L * t))) for t in np.linspace(0, 1, 7)])
        B.tube(path, 0.0045, 5, "fabric")
    B.mark("near", i0, fit=0.03)
    return ctx.cloth(B, _cm().ID + "_cord")


OUTFIT = {"apron": apron, "robe": robe, "cord_belt": cord_belt, "layers": layers, "shawl": shawl, "cloak_worn": cloak_worn, "robe_cloak": robe_cloak,
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
    cm.KIND = {"v_female": "female", "v_plump": "round", "v_elder": "round", "v_mountain": "female",
               "v_male": "male", "v_slight": "male", "v_stout": "broad"}[body]
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
    cm.LASH = {"v_female": 0.9, "v_plump": 0.9, "v_elder": 0.7, "v_mountain": 0.7}.get(body, 0.55)
    cm.LASH_LINEAR = cc.srgb("1A1210")
    cm.HAIR_RGB = cc.srgb(D["hair"])
    cm.BROWS_SRGB = D["brows"]
    cm.LIPS_SRGB = D["lips"]
    cm.CANON = D["canon"]
    cm.SKIN_TEX = ""
    cm.face_layers = lambda layers: face_layers(D, cm, layers)
    cm.pose_frame = (lambda name, fr: stoop(fr, D["stoop"])) if D.get("stoop") else None
    return D


def face_layers(D, cm, layers):
    """build_minor_fae's face bake layers (blush, lid wash, liner, brows, lips) for a village face:
    no court makeup.  Cold-pink cheeks, no lid colour, a whisper of lash line, natural lips.  The
    Blessed glow a little more ("a clean, fresh face", ch 3)."""
    glow = D.get("face") == "glow"
    female = cm.KIND in ("female", "round")
    amts = {"blush": (0.30 if glow else 0.20) if female else 0.14, "lid": 0.0, "liner": 0.22 if female else 0.12,
            "brows": 0.75, "lips": (0.55 if glow else 0.42) if female else 0.30}
    keys = ["blush", "lid", "liner", "brows", "lips"]
    out = []
    for k, (m, hexc, _amt) in zip(keys, layers):
        if k == "blush":
            hexc = "E39A94"
        if k == "liner":
            hexc = "5A4034"
        out.append((m, hexc, amts[k]))
    return out


def stoop(fr, amt):
    """An old woman's carriage on every clip: rounded back, head forward, knees soft (the father's
    stoop, cast_father._stoop, made deeper)."""
    import cast_father
    import feyre_anims as fa
    cast_father._stoop(fr, amt)
    fr.add("Hips", fa.qx(4.0 * amt))
    fr.hips += V((0.0, 0.010 * amt, -0.012 * amt))
    return fr
