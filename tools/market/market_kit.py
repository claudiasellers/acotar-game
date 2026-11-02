"""The village market kit (lane L53, headless bpy). Run:
    /opt/bpyenv/bin/python tools/market/market_kit.py [name ...]
Writes story/market/assets/<name>.glb, each with its origin at the stall's
origin (Blender -Y = the stall's front, counter top at z 0.91):
  stall_<tone>   the stall in weathered oak with a faded canvas awning
                 (oat, rust, madder, slate): the village's own stall shape,
                 rebuilt lighter so the wood isn't near-black;
  goods_<trade>  what each trade lays on its counter and hangs from the eaves
                 (the goods tell the stalls apart first);
  sign_<trade>   a flat shaped board (a boot, shears, a loaf...) hanging from
                 an iron bracket off the front-left post at about 2.4 m;
  fingerpost     the cottage fork's post with a carved well-and-roof arm;
  handcart, crate_pile   set dressing for the square.
Wood, cloth, iron and paint only; albedo <= 0.85; nothing glows.
"""
import math
import os
import sys

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
sys.path.insert(0, os.path.join(REPO, "tools", "blender", "human_realm"))
import village_lib  # noqa: E402
from village_lib import C, SNOW, Asset, reset  # noqa: E402

village_lib.OUT_DIR = os.path.join(REPO, "story", "market", "assets")

OAK = (0.40, 0.34, 0.27)        # weathered grey-brown oak
OAK_DARK = (0.30, 0.25, 0.20)
OAK_PALE = (0.47, 0.41, 0.33)
TONES = {
    "oat": (0.74, 0.66, 0.50),
    "rust": (0.56, 0.32, 0.20),
    "madder": (0.55, 0.24, 0.24),
    "slate": (0.42, 0.46, 0.50),
}
P = {
    "leather": (0.38, 0.24, 0.14), "leather_dk": (0.24, 0.15, 0.09),
    "cream": (0.80, 0.76, 0.64), "wool_grey": (0.60, 0.58, 0.55), "wool_brown": (0.45, 0.35, 0.26),
    "copper": (0.62, 0.38, 0.22), "ochre": (0.72, 0.52, 0.22), "mustard": (0.70, 0.58, 0.20),
    "paprika": (0.62, 0.24, 0.14), "garlic": (0.82, 0.78, 0.70), "crust": (0.66, 0.42, 0.18),
    "crust_dk": (0.50, 0.30, 0.13), "turnip": (0.60, 0.40, 0.60), "onion": (0.70, 0.48, 0.26),
    "leaf": (0.32, 0.44, 0.24), "rowan": (0.66, 0.18, 0.12), "bone": (0.82, 0.78, 0.68),
    "cloth_blue": (0.36, 0.44, 0.56), "cloth_green": (0.38, 0.46, 0.32), "cloth_red": (0.56, 0.22, 0.20),
    "paint_bg": (0.70, 0.64, 0.50),
}
TOP = 0.91       # counter top
FRONT = -0.55    # counter's front half
BACK = 0.6       # the back shelf / rail
EAVE_Y, EAVE_Z = -1.2, 1.95

KIT = {}


def kit(name):
    def deco(fn):
        KIT[name] = fn
        return fn
    return deco


# --- stalls ------------------------------------------------------------------

def stall(tone):
    a = Asset("stall_" + tone, 400 + len(tone))
    cloth = TONES[tone]
    w, d = 3.0, 2.0
    for x in (-w / 2, w / 2):
        for y in (-d / 2, d / 2):
            h = 2.5 if y > 0 else 2.0
            a.box((0.12, 0.12, h), (x, y, h / 2), OAK, bevel=0.015, jitter=0.1)
    a.box((w + 0.1, 0.9, 0.85), (0, -d / 2 + 0.45, 0.43), OAK_PALE, bevel=0.03, jitter=0.1)
    for i in range(6):  # plank lines on the counter front
        a.box((0.02, 0.02, 0.8), (-w / 2 + 0.25 + i * 0.5, -d / 2 - 0.005, 0.43), OAK_DARK)
    a.box((w + 0.3, 1.0, 0.07), (0, -d / 2 + 0.45, 0.88), OAK, snow=0.3, bevel=0.01)
    a.box((w, 0.3, 0.05), (0, BACK + 0.1, 1.2), OAK_PALE)              # back shelf
    a.box((w, 0.06, 0.06), (0, BACK + 0.3, 1.95), OAK)                 # back rail
    a.box((w + 0.5, d + 0.6, 0.05), (0, 0, 2.28), cloth, rot=(-0.25, 0, 0), bevel=0.015, jitter=0.12)
    for i in range(7):  # scalloped valance
        a.box((0.42, 0.03, 0.26), (-w / 2 - 0.05 + i * 0.52, -d / 2 - 0.32, 1.99), cloth,
              rot=(0.1, 0, a.rng.uniform(-0.04, 0.04)), jitter=0.15)
    a.box((w + 0.3, d + 0.3, 0.08), (0, 0.05, 2.35), SNOW, rot=(-0.25, 0, 0), bevel=0.03)
    a.export()


for _t in TONES:
    KIT["stall_" + _t] = (lambda t: (lambda: stall(t)))(_t)


# --- goods -------------------------------------------------------------------

def string_of(a, x, y, z, n, length, bead, col, r=0.05):
    """A cord from the eave with `n` things threaded down it."""
    a.cyl(0.006, length, (x, y, z - length), C["timber"], segs=4)
    for i in range(n):
        bead(a, x, y, z - 0.12 - i * (length - 0.12) / max(n - 1, 1), col, r)


def boot(a, x, y, z, col, s=1.0, yaw=0.0):
    a.box((0.11 * s, 0.1 * s, 0.26 * s), (x, y, z + 0.13 * s), col, rot=(0, 0, yaw), bevel=0.03)
    dx, dy = -math.sin(yaw) * 0.09 * s, -math.cos(yaw) * 0.09 * s
    a.box((0.11 * s, 0.26 * s, 0.09 * s), (x + dx, y + dy, z + 0.045 * s), col, rot=(0, 0, yaw), bevel=0.03)
    a.box((0.12 * s, 0.28 * s, 0.02 * s), (x + dx, y + dy, z + 0.005), P["leather_dk"], rot=(0, 0, yaw))


@kit("goods_cobbler")
def goods_cobbler():
    a = Asset("goods_cobbler", 501)
    for i in range(4):
        x = -1.1 + i * 0.7
        col = (P["leather"], P["leather_dk"], P["leather"], P["wool_brown"])[i]
        boot(a, x - 0.08, FRONT, TOP, col)
        boot(a, x + 0.08, FRONT + 0.04, TOP, col)
    for x in (-0.9, 0.0, 0.9):  # pairs hung by the laces
        a.cyl(0.005, 0.25, (x, EAVE_Y + 0.15, EAVE_Z - 0.25), C["timber"], segs=4)
        boot(a, x - 0.07, EAVE_Y + 0.15, EAVE_Z - 0.58, P["leather"], 0.9)
        boot(a, x + 0.07, EAVE_Y + 0.15, EAVE_Z - 0.6, P["leather"], 0.9)
    for i in range(5):  # hides on the back shelf
        a.box((0.5, 0.25, 0.04), (-1.1 + i * 0.55, BACK + 0.1, 1.25 + i * 0.01), (P["leather"], P["wool_brown"])[i % 2], bevel=0.02)
    a.box((0.3, 0.12, 0.12), (1.2, FRONT + 0.15, TOP + 0.06), C["iron"], bevel=0.02)  # a last
    a.export()


@kit("goods_clothier")
def goods_clothier():
    a = Asset("goods_clothier", 502)
    cols = [P["cloth_blue"], P["cream"], P["cloth_red"], P["cloth_green"], P["wool_grey"]]
    for i, c in enumerate(cols):  # bolts lying on the counter
        a.cyl(0.11, 0.55, (-1.15 + i * 0.55, FRONT, TOP + 0.11), c, rot=(math.pi / 2, 0, 0.15), segs=10)
    for i in range(3):  # folded stacks
        for k in range(4):
            a.box((0.38, 0.3, 0.06), (-0.9 + i * 0.9, FRONT + 0.35, TOP + 0.03 + k * 0.065), cols[(i + k) % 5], bevel=0.02)
    for i, c in enumerate((P["wool_brown"], P["cloth_blue"], P["cream"])):  # cloaks on the back rail
        a.box((0.6, 0.05, 1.05), (-0.9 + i * 0.9, BACK + 0.32, 1.42), c, bevel=0.03, jitter=0.1)
    for x in (-1.2, 1.2):  # lengths draped from the eave
        a.box((0.4, 0.03, 0.7), (x, EAVE_Y + 0.12, EAVE_Z - 0.38), cols[int(x > 0) * 2], bevel=0.01)
    a.export()


@kit("goods_spice")
def goods_spice():
    a = Asset("goods_spice", 503)
    # The hot pot on its trivet at the counter end.
    a.cyl(0.04, 0.15, (-1.05, FRONT + 0.1, TOP), C["iron"], segs=6)
    a.cyl(0.28, 0.3, (-1.05, FRONT + 0.1, TOP + 0.12), P["copper"], segs=14, r2=0.3, bevel=0.01)
    a.cyl(0.26, 0.02, (-1.05, FRONT + 0.1, TOP + 0.4), (0.50, 0.32, 0.18), segs=14)
    for i, c in enumerate((P["ochre"], P["paprika"], P["mustard"], (0.40, 0.30, 0.20))):  # open spice sacks
        x = -0.35 + i * 0.42
        a.cyl(0.16, 0.3, (x, FRONT, TOP), C["sack"], segs=9, r2=0.18)
        a.sphere(0.15, (x, FRONT, TOP + 0.3), c, scale=(1, 1, 0.45), subdiv=1)
    for x in (-1.0, -0.2, 0.6, 1.25):  # garlic and chilli strings
        string_of(a, x, EAVE_Y + 0.1, EAVE_Z, 4, 0.6,
                  lambda a, x, y, z, c, r: a.sphere(r, (x, y, z), c, scale=(1, 1, 0.9), subdiv=1),
                  P["garlic"] if x < 0.5 else P["paprika"], 0.055)
    for i in range(4):  # little jars on the shelf
        a.cyl(0.07, 0.16, (-0.9 + i * 0.6, BACK + 0.1, 1.23), (P["ochre"], C["cloth_pale"], P["copper"], P["paprika"])[i], segs=8)
    a.export()


@kit("goods_charms")
def goods_charms():
    a = Asset("goods_charms", 504)
    for i in range(7):  # charms on strings: iron rings, bones, rowan
        x = -1.35 + i * 0.45
        if i % 3 == 0:
            string_of(a, x, EAVE_Y + 0.1, EAVE_Z, 3, 0.75,
                      lambda a, x, y, z, c, r: a.cyl(r, 0.015, (x, y, z), c, rot=(math.pi / 2, 0, 0), segs=10),
                      C["iron"], 0.06)
        elif i % 3 == 1:
            string_of(a, x, EAVE_Y + 0.1, EAVE_Z, 3, 0.65,
                      lambda a, x, y, z, c, r: a.box((0.03, 0.03, 0.12), (x, y, z), c, bevel=0.01),
                      P["bone"], 0.05)
        else:
            string_of(a, x, EAVE_Y + 0.1, EAVE_Z, 5, 0.7,
                      lambda a, x, y, z, c, r: a.sphere(r, (x, y, z), c, subdiv=1),
                      P["rowan"], 0.03)
    for i in range(3):  # trays of bits of iron and charms
        x = -0.95 + i * 0.95
        a.box((0.75, 0.42, 0.05), (x, FRONT, TOP + 0.025), OAK_DARK, bevel=0.01)
        for k in range(6):
            a.cyl(0.035, 0.012, (x - 0.28 + k * 0.11, FRONT + a.rng.uniform(-0.12, 0.12), TOP + 0.06),
                  (C["iron"], C["rust"], P["bone"])[k % 3], segs=8)
    for i in range(5):  # horseshoes nailed to the back rail
        t = i * 0.6 - 1.2
        for j in range(5):
            u = math.pi * (-0.1 + 1.2 * j / 4)
            a.box((0.04, 0.03, 0.05), (t + 0.09 * math.cos(u), BACK + 0.26, 1.7 + 0.09 * math.sin(u)), C["iron"])
    a.export()


@kit("goods_grain")
def goods_grain():
    a = Asset("goods_grain", 505)
    for i in range(4):
        x = -1.05 + i * 0.7
        a.cyl(0.24, 0.5, (x, FRONT, TOP), C["sack"], segs=9, r2=0.2)
        a.sphere(0.2, (x, FRONT, TOP + 0.5), C["grain"], scale=(1, 1, 0.4), subdiv=1)
    a.box((0.06, 0.06, 0.3), (0.95, FRONT + 0.3, TOP + 0.15), OAK)  # a scoop and a measure
    a.cyl(0.13, 0.15, (0.6, FRONT + 0.3, TOP), OAK_PALE, segs=10)
    for x in (-1.25, 1.25):  # sheaves leaning on the front posts
        for k in range(7):
            t = (k - 3) / 3.0
            a.cyl(0.015, 1.1, (x + t * 0.05, -1.15, 0.0), C["straw"], rot=(0.18, t * 0.12, 0), segs=4)
        a.box((0.14, 0.14, 0.05), (x, -1.08, 0.55), P["paprika"])
    a.export()


@kit("goods_baker")
def goods_baker():
    a = Asset("goods_baker", 506)
    for i in range(3):  # baskets of loaves
        x = -0.95 + i * 0.95
        a.cyl(0.32, 0.16, (x, FRONT, TOP), C["straw"], segs=12, r2=0.36)
        for k in range(3):
            a.sphere(0.14, (x - 0.14 + k * 0.14, FRONT + a.rng.uniform(-0.08, 0.08), TOP + 0.2),
                     (P["crust"], P["crust_dk"])[k % 2], scale=(1.2, 0.8, 0.6), subdiv=1)
    for x in (-1.0, 0.0, 1.0):  # ring loaves on a pole under the eave
        for k in range(2):
            a.cyl(0.11, 0.04, (x + k * 0.22 - 0.11, EAVE_Y + 0.1, EAVE_Z - 0.35), P["crust"],
                  rot=(math.pi / 2, 0, 0), segs=10)
    a.box((2.8, 0.04, 0.04), (0, EAVE_Y + 0.1, EAVE_Z - 0.2), OAK)
    for i in range(6):
        a.sphere(0.13, (-1.2 + i * 0.48, BACK + 0.1, 1.3), P["crust"], scale=(1.3, 0.8, 0.6), subdiv=1)
    a.export()


@kit("goods_roots")
def goods_roots():
    a = Asset("goods_roots", 507)
    for i, c in enumerate((P["turnip"], P["onion"], P["garlic"], P["turnip"])):  # crates of roots
        x = -1.05 + i * 0.7
        a.box((0.55, 0.42, 0.2), (x, FRONT, TOP + 0.1), OAK_PALE, bevel=0.01)
        for k in range(5):
            a.sphere(0.08, (x - 0.18 + (k % 3) * 0.18, FRONT - 0.1 + (k // 3) * 0.2, TOP + 0.22), c, subdiv=1)
    for x in (-1.1, -0.4, 0.4, 1.1):  # onion plaits
        string_of(a, x, EAVE_Y + 0.1, EAVE_Z, 5, 0.75,
                  lambda a, x, y, z, c, r: a.sphere(r, (x, y, z), c, scale=(1, 1, 0.85), subdiv=1),
                  P["onion"], 0.06)
    for i in range(3):  # leafy bunches on the shelf
        a.box((0.15, 0.1, 0.35), (-0.8 + i * 0.8, BACK + 0.1, 1.4), P["leaf"], rot=(0.2, 0, 0), bevel=0.02)
    a.export()


@kit("goods_wool")
def goods_wool():
    a = Asset("goods_wool", 508)
    cols = [P["cream"], P["wool_grey"], P["wool_brown"], P["cream"], P["wool_grey"]]
    for i, c in enumerate(cols):  # skeins heaped on the counter
        a.sphere(0.13, (-1.1 + i * 0.55, FRONT, TOP + 0.08), c, scale=(1.4, 0.8, 0.6), subdiv=1)
        a.sphere(0.11, (-0.85 + i * 0.55, FRONT + 0.22, TOP + 0.08), cols[(i + 2) % 5], scale=(1.4, 0.8, 0.6), subdiv=1)
    for i, c in enumerate((P["cream"], P["wool_brown"], P["wool_grey"])):  # fleeces hung on the back rail
        a.box((0.7, 0.06, 0.8), (-0.9 + i * 0.9, BACK + 0.32, 1.5), c, bevel=0.06, jitter=0.12)
    for x in (-1.2, 1.2):
        a.box((0.35, 0.03, 0.6), (x, EAVE_Y + 0.12, EAVE_Z - 0.32), P["wool_grey"], bevel=0.02)
    a.export()


@kit("goods_tinker")
def goods_tinker():
    a = Asset("goods_tinker", 509)
    for i in range(3):  # pots and kettles
        x = -1.0 + i * 0.9
        a.cyl(0.18, 0.22, (x, FRONT, TOP), (C["iron"], P["copper"], C["iron"])[i], segs=12, r2=0.15, bevel=0.01)
        a.cyl(0.05, 0.14, (x + 0.18, FRONT, TOP + 0.1), C["iron"], rot=(0, 0.9, 0), segs=6, r2=0.025)
    for x in (-1.1, -0.35, 0.4, 1.15):  # pans hung by their handles
        a.cyl(0.005, 0.15, (x, EAVE_Y + 0.12, EAVE_Z - 0.15), C["iron"], segs=4)
        a.box((0.03, 0.03, 0.22), (x, EAVE_Y + 0.12, EAVE_Z - 0.3), C["iron"])
        a.cyl(0.15, 0.03, (x, EAVE_Y + 0.12, EAVE_Z - 0.55), (P["copper"], C["iron"])[int(x > 0)],
              rot=(math.pi / 2, 0, 0), segs=12)
    for i in range(6):  # ladles and tongs on the shelf
        a.box((0.03, 0.03, 0.35), (-1.2 + i * 0.48, BACK + 0.1, 1.38), C["iron"])
    a.export()


@kit("goods_salt")
def goods_salt():
    a = Asset("goods_salt", 510)
    for i in range(4):  # crocks heaped white
        x = -1.05 + i * 0.7
        a.cyl(0.17, 0.26, (x, FRONT, TOP), P["ochre"] if i % 2 else (0.55, 0.45, 0.35), segs=10, r2=0.19)
        a.sphere(0.17, (x, FRONT, TOP + 0.26), C["salt"], scale=(1, 1, 0.5), subdiv=1)
    a.box((0.5, 0.3, 0.25), (0.9, FRONT + 0.35, TOP + 0.125), C["salt"], bevel=0.03)  # a block of salt
    for i in range(5):  # small bags on the shelf
        a.cyl(0.09, 0.18, (-1.1 + i * 0.5, BACK + 0.1, 1.23), C["sack"], segs=8, r2=0.05)
    a.export()


# --- signs: flat shaped boards on an iron bracket -----------------------------

BRACKET_X, BRACKET_Z = -1.5, 2.4
BOARD_X, BOARD_Y, BOARD_Z = -2.0, -1.0, 1.95
THICK = 0.04


def bracket(a):
    a.box((0.05, 0.05, BRACKET_Z - 1.95), (BRACKET_X, -1.0, (BRACKET_Z + 1.95) / 2), C["iron"])  # upright on the post
    a.box((0.75, 0.04, 0.04), (BRACKET_X - 0.36, -1.0, BRACKET_Z), C["iron"])
    a.box((0.45, 0.03, 0.03), (BRACKET_X - 0.18, -1.0, BRACKET_Z - 0.17), C["iron"], rot=(0, -0.75, 0))
    a.cyl(0.03, 0.03, (BRACKET_X - 0.74, -1.0, BRACKET_Z - 0.015), C["iron"], segs=6)
    for dx in (-0.16, 0.16):  # chains
        a.cyl(0.006, 0.12, (BOARD_X + dx, -1.0, BRACKET_Z - 0.12), C["iron"], segs=4)


def flat(a, profile, col, dz=0.0, dx=0.0, outline=True, depth=0.0):
    """A flat cut-out in the board's plane (X right, Z up, thin along Y)."""
    prof = [(-(x + dx), z + dz) for x, z in profile]
    loc = (BOARD_X, BOARD_Y + depth, BOARD_Z)
    a.prism(prof, THICK, loc, col, rot=(0, 0, math.pi / 2))
    if outline:  # a darker edge board behind, 2 cm proud all round
        cx = sum(p[0] for p in prof) / len(prof)
        cz = sum(p[1] for p in prof) / len(prof)
        big = [(cx + (x - cx) * 1.09, cz + (z - cz) * 1.09) for x, z in prof]
        a.prism(big, THICK * 0.8, (BOARD_X, BOARD_Y + 0.025 + depth, BOARD_Z), OAK_DARK, rot=(0, 0, math.pi / 2))


def ellipse(rx, rz, n=14, cx=0.0, cz=0.0):
    return [(cx + rx * math.cos(math.tau * i / n), cz + rz * math.sin(math.tau * i / n)) for i in range(n)]


def sign_asset(name, seed, draw):
    def fn():
        a = Asset(name, seed)
        bracket(a)
        draw(a)
        a.export()
    KIT[name] = fn


sign_asset("sign_cobbler", 601, lambda a: flat(a, [(-0.12, 0.28), (0.08, 0.28), (0.08, -0.05), (0.3, -0.12),
                                                    (0.3, -0.26), (-0.12, -0.26)], P["leather"]))
sign_asset("sign_clothier", 602, lambda a: (
    flat(a, [(-0.04, 0.3), (0.04, 0.3), (0.2, -0.12), (0.12, -0.14)], C["stone"]),
    flat(a, [(-0.04, 0.3), (0.04, 0.3), (-0.12, -0.14), (-0.2, -0.12)], C["stone"], depth=-0.03),
    flat(a, ellipse(0.08, 0.08, 10, 0.17, -0.2), C["iron"], depth=-0.05),
    flat(a, ellipse(0.08, 0.08, 10, -0.17, -0.2), C["iron"], depth=-0.05)))
sign_asset("sign_spice", 603, lambda a: (
    flat(a, [(-0.24, 0.1), (0.24, 0.1), (0.2, -0.2), (-0.2, -0.2)], P["copper"]),
    flat(a, [(-0.27, 0.1), (0.27, 0.1), (0.27, 0.15), (-0.27, 0.15)], C["iron"], depth=-0.03, outline=False),
    flat(a, ellipse(0.05, 0.1, 8, -0.08, 0.3), C["cloth_pale"], outline=False),
    flat(a, ellipse(0.05, 0.1, 8, 0.08, 0.34), C["cloth_pale"], outline=False)))
sign_asset("sign_charms", 604, lambda a: flat(a, [(0.24 * math.cos(math.pi * (-0.15 + 1.3 * i / 10)),
                                                   0.02 + 0.24 * math.sin(math.pi * (-0.15 + 1.3 * i / 10)))
                                                  for i in range(11)]
                                              + [(0.16 * math.cos(math.pi * (-0.15 + 1.3 * i / 10)),
                                                  0.02 + 0.16 * math.sin(math.pi * (-0.15 + 1.3 * i / 10)))
                                                 for i in reversed(range(11))], C["iron"]))
sign_asset("sign_baker", 605, lambda a: (
    flat(a, ellipse(0.3, 0.17), P["crust"]),
    *[flat(a, [(dx - 0.02, -0.1), (dx + 0.02, -0.1), (dx + 0.08, 0.1), (dx + 0.04, 0.1)], P["crust_dk"],
           depth=-0.03, outline=False) for dx in (-0.12, 0.0, 0.12)]))
sign_asset("sign_grain", 606, lambda a: (
    flat(a, [(-0.06, -0.3), (0.06, -0.3), (0.2, 0.3), (-0.2, 0.3)], C["straw"]),
    flat(a, [(-0.1, -0.02), (0.1, -0.02), (0.1, 0.05), (-0.1, 0.05)], P["paprika"], depth=-0.03, outline=False)))
sign_asset("sign_roots", 607, lambda a: (
    flat(a, ellipse(0.17, 0.15, 12, 0, -0.05), P["turnip"]),
    flat(a, [(-0.03, -0.2), (0.03, -0.2), (0.0, -0.32)], P["cream"], outline=False),
    *[flat(a, ellipse(0.05, 0.13, 8, dx, 0.2), P["leaf"], outline=False) for dx in (-0.08, 0.0, 0.08)]))
sign_asset("sign_wool", 608, lambda a: (
    flat(a, ellipse(0.26, 0.17), P["cream"]),
    flat(a, [(-0.03, -0.17), (0.03, -0.17), (0.03, 0.17), (-0.03, 0.17)], P["cloth_red"], depth=-0.03, outline=False)))
sign_asset("sign_tinker", 609, lambda a: (
    flat(a, [(-0.2, 0.1), (0.2, 0.1), (0.24, -0.2), (-0.24, -0.2)], C["iron"]),
    flat(a, [(0.2, 0.0), (0.36, 0.14), (0.33, 0.17), (0.18, 0.06)], C["iron"], outline=False),
    flat(a, [(-0.14, 0.1), (-0.1, 0.25), (0.1, 0.25), (0.14, 0.1), (0.1, 0.1), (0.07, 0.21), (-0.07, 0.21), (-0.1, 0.1)],
         C["iron"], outline=False)))
sign_asset("sign_salt", 610, lambda a: (
    flat(a, [(-0.17, 0.08), (0.17, 0.08), (0.2, -0.25), (-0.2, -0.25)], P["ochre"]),
    flat(a, ellipse(0.2, 0.12, 12, 0, 0.12), C["salt"], depth=-0.03, outline=False)))


# --- the fingerpost and square dressing ---------------------------------------

@kit("fingerpost")
def fingerpost():
    """One arm, cut to a point, with a carved well and roof (Feyre can barely
    read; the picture says village). The arm points along Blender -Y (Godot +Z)."""
    a = Asset("sign_fingerpost", 611)
    a.cyl(0.07, 2.35, (0, 0, 0), OAK, segs=8)
    a.cyl(0.09, 0.08, (0, 0, 2.35), OAK_DARK, segs=8, r2=0.03)
    a.box((0.07, 1.05, 0.24), (0, -0.5, 1.95), OAK_PALE, bevel=0.015)
    a.box((0.07, 0.24, 0.24), (0, -1.08, 1.95), OAK_PALE, rot=(math.pi / 4, 0, 0), bevel=0.01)
    a.box((0.1, 0.12, 0.16), (0, -0.62, 1.95), C["stone"])
    a.box((0.1, 0.18, 0.04), (0, -0.62, 2.05), OAK_DARK)
    a.box((0.1, 0.14, 0.12), (0, -0.36, 1.93), C["daub"])
    a.box((0.1, 0.17, 0.05), (0, -0.36, 2.02), P["cloth_red"])
    a.box((0.09, 1.0, 0.04), (0, -0.48, 2.08), SNOW, bevel=0.015)
    a.snow_mound((0, 0, 0.0), 0.25, 0.12)
    a.export()


@kit("handcart")
def handcart():
    a = Asset("handcart", 612)
    a.box((1.3, 0.8, 0.06), (0, 0, 0.6), OAK_PALE, bevel=0.01)
    for s in (-1, 1):
        a.box((1.3, 0.04, 0.25), (0, s * 0.4, 0.72), OAK, bevel=0.01)
        a.cyl(0.32, 0.06, (0.1, s * 0.46, 0.32), OAK_DARK, rot=(math.pi / 2, 0, 0), segs=12)
        a.box((1.1, 0.05, 0.05), (-1.15, s * 0.3, 0.55), OAK, rot=(0, -0.3, 0))
    for i in range(3):
        a.cyl(0.18, 0.4, (-0.35 + i * 0.35, 0.0, 0.63), C["sack"], segs=8, r2=0.14)
    a.box((1.2, 0.7, 0.06), (0, 0, 1.06), SNOW, bevel=0.03)
    a.export()


@kit("crate_pile")
def crate_pile():
    a = Asset("crate_pile", 613)
    spots = [(0, 0, 0), (0.62, 0.05, 0), (0.3, 0.55, 0), (0.3, 0.1, 0.5), (-0.4, 0.6, 0)]
    for i, (x, y, z) in enumerate(spots):
        a.box((0.55, 0.5, 0.48), (x, y, z + 0.24), OAK_PALE if i % 2 else OAK, rot=(0, 0, a.rng.uniform(-0.2, 0.2)), bevel=0.02)
        a.box((0.57, 0.04, 0.05), (x, y - 0.25, z + 0.3), OAK_DARK)
    a.cyl(0.25, 0.6, (1.15, 0.4, 0), OAK, segs=10, r2=0.22)
    a.box((0.6, 0.55, 0.06), (0.3, 0.1, 1.0), SNOW, bevel=0.02)
    a.export()


if __name__ == "__main__":
    names = [n for n in sys.argv[1:] if n in KIT] or list(KIT)
    reset()
    for n in names:
        KIT[n]()
