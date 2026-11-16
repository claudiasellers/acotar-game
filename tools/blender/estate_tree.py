"""The estate's trees (wider-court D2/E2). A tree-builder written for the
estate's look (owner, 2026-11-12, of patching other generators' trees: "do
you want to just start from scratch instead" ... "totally fine go ahead"):

  wood    a skeleton shaped on purpose (a stout trunk with a root flare,
          heavy limbs that kink and curve up, each forking once), skinned and
          subdivided (Skin + Subsurf), so it is one smooth organic body
  clouds  every limb ends inside a leaf cloud: a soft flattened ball built
          from leaf-clump cards (tools/court/gen_estate_tree_clumps.py) whose
          normals are the cloud's, so the crown keeps the cotton-candy shapes
          and is made of leaves; a darker heart inside each for depth
  willow  no clouds: fronds draped from arching limbs (see its recipe)
  builds  the same recipe from another seed is another tree, so neighbours
          differ: three per species, and two longer curtains for the willow

What the first rounds taught: no twigs ("sprinkles sticking out ... creepy
rather than beautiful and enchanted"), every limb ends in a cloud, no cloud
floats, the outline is leaves ("not detailed" was smooth puffs).

Run:  <bpy python> tools/blender/estate_tree.py [--only oak,birch] [--seeds 3]
Out:  world/spring_court/manor_estate/flora/trees/tree_<species>_<a..>.glb
      one mesh, a material slot per part: tree_bark, tree_leaves, tree_core,
      tree_fruit, tree_fronds (EstateTrees puts each on its material)
A seed's tree is the same on every run; the species table (height) is FloraLib's.
"""

import math
import os
import random
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import bpy  # noqa: E402,I001
import bmesh  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402
import prop_kit as K  # noqa: E402
import manor_flora as MF  # noqa: E402

OUT = os.path.join(K.ROOT, "world/spring_court/manor_estate/flora/trees")
# The court's great trees (docs/lanes/court-planting-by-place.md, "Assets we do
# not have"): grown by the same recipes so they stand beside the estate's as
# family, but they are the court's and live with its trees. species -> height (m).
COURT_OUT = os.path.join(K.ROOT, "world/spring_court/wider/assets/trees/great")
# Every tree's far form (--far): the same skeleton and clouds at a twentieth of the
# triangles, for the court's planting to draw past FAR_FROM (CourtGreatTrees). The
# estate's species' far forms live with the court's too: the estate draws its own way.
FAR_OUT = os.path.join(K.ROOT, "world/spring_court/wider/assets/trees/far")
COURT = {"pillar_birch": 18.0, "great_oak": 22.0, "great_sycamore": 28.0, "great_elm": 25.0, "aspen_spire": 27.0, "old_thorn": 7.0,
         "thorn_bush": 3.2, "weeping_lady": 36.0, "great_cherry": 15.0}
# the tree limit the game holds models to (tests/unit/manor_estate/test_manor_flora.gd)
BUDGET = 6000
UP = Vector((0, 0, 1))

# Lengths are fractions of the tree's height; angles in degrees.
#   trunk: radius at chest height; clear: the stem below the first limbs
#   whorls: rings of limbs up the trunk: (height, limbs, reach, rise0, rise1, forks)
#           reach = limb length, rise0/rise1 = angle above level at root/tip
#   kink: how far a limb's heading wanders per segment (the oak's gnarl)
#   cloud: cloud radius; flat: its height over its width; card: leaf-clump size
#   optional: flare (root radius x trunk, 1.9), limb (limb radius x trunk, 0.62),
#   sink (the whole tree set this far into the ground, 0), wood (share of the skinned wood's
#   triangles kept, 0.33), budget (the tree's triangle limit, BUDGET),
#   top (the leader's last reach, 0.13), top_cloud (x cloud, 1.15),
#   weep (the willow: fronds instead of leaf clouds, see its recipe), fruit (pears per cloud)
#   The court's trees also differ in how they are built, not only in their numbers
#   (owner, 2026-11-16: "vary the tree design a little more they are looking very
#   derivative of each other"):
#   along (a second cloud two thirds out along every limb, x cloud: a bough that carries
#   its leaves along its length), sweep (0..1: the wind's work, limbs pulled round to the
#   lee side and longer there, the clouds blown that way), stems + spread (no trunk:
#   that many stems from the ground, leaning out by spread)
RECIPES = {
    # the parkland oak: stout, four long low limbs, a broad tiered crown (owner: "a bit broader", "those look good")
    "oak": dict(
        trunk=0.046, clear=0.25, lean=0.025,
        whorls=[(0.25, 4, 0.44, 12, 38, 2), (0.39, 3, 0.33, 38, 60, 1)],
        leader=0.62, kink=22, cloud=0.12, flat=0.8, card=0.085, cover=2.1, rim=0.26,
    ),
    # the birch: a slender white stem that keeps going, short upswept limbs
    # ring after ring, small airy clouds in a narrow crown
    "birch": dict(
        trunk=0.021, clear=0.36, lean=0.045, flare=1.5, limb=0.5,
        whorls=[(0.36, 3, 0.2, 30, 58, 1), (0.5, 3, 0.18, 36, 62, 0), (0.63, 3, 0.15, 42, 66, 0), (0.75, 2, 0.12, 48, 70, 0)],
        leader=0.83, top=0.07, top_cloud=1.0, kink=10, cloud=0.072, flat=0.9, card=0.07, cover=1.6, rim=0.3,
    ),
    # the cherry: a short trunk opening into a wide vase, blossom clouds
    "cherry_blossom": dict(
        trunk=0.038, clear=0.27, lean=0.03, flare=1.7,
        whorls=[(0.27, 4, 0.46, 26, 50, 2), (0.39, 3, 0.36, 46, 66, 1)],
        leader=0.56, top=0.15, kink=16, cloud=0.15, flat=0.82, card=0.12, cover=2.1, rim=0.26,
    ),
    # the apple: low, round and gnarled
    "apple_blossom": dict(
        trunk=0.042, clear=0.25, lean=0.04, flare=1.8,
        whorls=[(0.25, 4, 0.4, 18, 44, 2), (0.37, 3, 0.3, 42, 62, 1)],
        leader=0.5, top=0.13, kink=28, cloud=0.16, flat=0.8, card=0.13, cover=2.1, rim=0.26,
    ),
    # the crab apple: smaller in the limb and more upright, a tight round head
    "crab_apple": dict(
        trunk=0.036, clear=0.28, lean=0.03, flare=1.7,
        whorls=[(0.28, 3, 0.34, 34, 58, 2), (0.41, 3, 0.27, 50, 68, 1)],
        leader=0.52, top=0.14, kink=20, cloud=0.155, flat=0.86, card=0.13, cover=2.1, rim=0.26,
    ),
    # the pear: upright, an oval crown, pears hanging under the leaves
    "pear_tree": dict(
        trunk=0.04, clear=0.26, lean=0.02, flare=1.6,
        whorls=[(0.26, 3, 0.27, 38, 66, 1), (0.42, 3, 0.23, 46, 70, 1), (0.57, 3, 0.17, 54, 74, 0)],
        leader=0.7, top=0.12, kink=14, cloud=0.118, flat=0.92, card=0.1, cover=2.1, rim=0.26, fruit=1.4,
    ),
    # the willow: a short leaning trunk, slender limbs that climb, arch over
    # and droop, and nothing on them but fronds: strands that leave the limb,
    # roll over a shoulder and fall towards the ground (owner, 2026-11-12: "i
    # love the cascading leaves ... but i dont like the clumps at the top ...
    # thats not what actual willows look like"). No leaf clouds.
    #   weep: fronds per limb, frond width, the shoulder's reach, how near the ground they hang
    # the pillar birch (court; book ch 14: a ring of white birches "tall and
    # straight as pillars"): a dead-straight white stem with nothing on it for
    # most of its height, and a small light crown of short limbs at the top
    "pillar_birch": dict(
        trunk=0.0125, clear=0.6, lean=0.012, flare=1.6, limb=0.46,
        # (four whorls: a fifth, closer under the leader, crashes Blender's Skin modifier)
        whorls=[(0.6, 3, 0.14, 30, 56, 1), (0.69, 3, 0.13, 38, 62, 1), (0.77, 3, 0.115, 44, 66, 1), (0.85, 3, 0.095, 52, 70, 0)],
        leader=0.92, top=0.05, top_cloud=1.0, kink=8, cloud=0.05, flat=1.0, card=0.05, cover=1.7, rim=0.3,
        wood=0.17, budget=7000, sink=0.025,   # set 0.45 m into the ground: it stands on the hollow's slopes
    ),
    # The knolls' great trees (the glen: one tree to a knoll, and you find your
    # way by them, so each is built its own way and no two share an outline).
    # The great oak: wider than tall. A short thick bole, heavy boughs that
    # leave it low and run out level, carrying their leaves along their length.
    "great_oak": dict(
        trunk=0.054, clear=0.16, lean=0.02, flare=2.1,
        whorls=[(0.16, 4, 0.62, 2, 22, 2), (0.3, 3, 0.46, 30, 50, 2), (0.44, 3, 0.3, 50, 68, 1)],
        leader=0.56, top=0.12, kink=26, cloud=0.105, flat=0.7, card=0.075, cover=2.0, rim=0.26,
        along=0.85, budget=12000, sink=0.02,
    ),
    # the great sycamore (book ch 6: a lone sycamore on a knoll): a tall clean
    # grey bole and a towering crown of a few great billows, big-leaved
    "great_sycamore": dict(
        trunk=0.036, clear=0.36, lean=0.012, flare=1.7,
        whorls=[(0.36, 3, 0.26, 34, 62, 1), (0.52, 3, 0.2, 48, 70, 0)],
        leader=0.74, top=0.1, top_cloud=1.25, kink=10, cloud=0.19, flat=1.05, card=0.11, cover=1.9, rim=0.3,
        budget=8000, sink=0.02,
    ),
    # the great elm (book ch 10: "an elm with a coarse trunk"): a vase. The
    # bole divides high into four limbs that climb and lean out, and the
    # leaves lie in plates across the top, the limbs bare beneath them
    "great_elm": dict(
        trunk=0.04, clear=0.4, lean=0.015, flare=2.0, limb=0.7,
        whorls=[(0.4, 4, 0.5, 74, 48, 2)],
        leader=0.46, top=0.06, top_cloud=0.9, kink=14, cloud=0.12, flat=0.5, card=0.07, cover=2.0, rim=0.28,
        along=0.7, budget=8000, sink=0.02,
    ),
    # the aspen spire: a column. A thin pale stem leaved almost to the ground,
    # short limbs held close, each cloud taller than it is wide
    "aspen_spire": dict(
        trunk=0.018, clear=0.14, lean=0.01, flare=1.6, limb=0.45,
        whorls=[(0.14, 3, 0.1, 62, 80, 0), (0.34, 3, 0.1, 64, 80, 0), (0.54, 3, 0.09, 66, 82, 0), (0.72, 3, 0.07, 68, 82, 0)],
        leader=0.9, top=0.07, top_cloud=0.9, kink=6, cloud=0.062, flat=1.9, card=0.05, cover=1.8, rim=0.3,
        wood=0.2, budget=7000, sink=0.02,
    ),
    # The great cherry (the Blossom Knoll on the glen's Knoll Walk: the one pink
    # tree on the way; built with --seeds 1, there is only the one). Wider than
    # it is tall: a short dark bole that divides low into great boughs, which
    # arch out level over your head, blossom in billows along their whole
    # length, so you walk in under it.
    "great_cherry": dict(
        trunk=0.062, clear=0.22, lean=0.03, flare=2.1, limb=0.66,
        whorls=[(0.22, 5, 0.74, 30, 0, 2), (0.36, 4, 0.52, 48, 14, 2), (0.5, 3, 0.32, 60, 42, 1)],
        leader=0.6, top=0.14, top_cloud=1.2, kink=20, cloud=0.17, flat=0.62, card=0.12, cover=2.1, rim=0.26,
        along=0.95, wood=0.24, budget=12000, sink=0.02,
    ),
    # the old thorn: a hawthorn the wind has made. It leans hard, every limb
    # is pulled round to the lee side, and the may lies in flat plates.
    # It leans toward +X whatever the build, so the planting can turn every
    # thorn the wind's way (and the two at the brae's gate toward each other).
    "old_thorn": dict(
        trunk=0.06, clear=0.3, lean=0.22, lean_az=0.0, flare=2.0,
        whorls=[(0.3, 4, 0.5, 14, 26, 2), (0.44, 3, 0.36, 30, 40, 1)],
        leader=0.5, top=0.1, kink=40, cloud=0.15, flat=0.42, card=0.1, cover=2.1, rim=0.26,
        sweep=0.8, sink=0.03,
    ),
    # a thorn bush: no trunk, five stems from the ground leaning out, a mound
    # of may head high: the height between the grass and the crowns
    "thorn_bush": dict(
        trunk=0.035, clear=0.0, lean=0.0, whorls=[], stems=5, spread=0.55,
        leader=0.8, kink=28, cloud=0.3, flat=0.75, card=0.2, cover=2.0, rim=0.26,
        wood=0.2, budget=4200, sink=0.04,
    ),
    # The Weeping Lady (Willow Mere's landmark; owner, 2026-11-16: "markedly
    # distinct from the other trees in color size etc. so that it stands out
    # from everything else. maybe add a few flowering strands too"). Not the
    # estate's willow grown large: three times its height, bowed out over the
    # water on a great dark leaning bole with roots running into the mere,
    # silver where every other tree is green, her strands falling the whole
    # way down and into the water, and among them chains of blossom that end
    # each in a drop of light. She leans along +X: the world turns her to the mere.
    "weeping_lady": dict(
        trunk=0.05, clear=0.26, lean=0.17, lean_az=0.0, flare=2.2, limb=0.5, limb_tip=0.16, limb_segs=6, roots=5,
        # boughs that climb, arch over and come down again
        whorls=[(0.26, 5, 0.56, 52, -38, 1), (0.4, 4, 0.48, 62, -34, 1), (0.53, 4, 0.36, 72, -28, 1)],
        leader=0.64, top=0.08, kink=16, cloud=0.1, flat=0.7, card=0.1, cover=1.7, rim=0.2,
        sweep=0.35, weep=(30, 0.062, 0.085, 0.02), trail=0.6, frond_tile=0.3, dip=0.13, drape_from=0.4,
        # chains per limb, shortest and longest, a floret's size; top, middle, tip, and the tear
        tears=(3, 0.12, 0.32, 0.013),
        tear_colours=((0.99, 0.86, 0.93), (0.95, 0.46, 0.72), (0.66, 0.18, 0.60), (1.0, 0.80, 0.38)),
        wood=0.3, budget=60000, sink=0.012,
    ),
    "willow": dict(
        trunk=0.046, clear=0.3, lean=0.07, flare=1.8, limb=0.5,
        whorls=[(0.3, 4, 0.36, 50, -18, 1), (0.4, 4, 0.32, 62, -12, 1), (0.49, 3, 0.25, 74, -4, 1)],
        leader=0.57, top=0.07, kink=14, cloud=0.1, flat=0.7, card=0.1, cover=1.7, rim=0.2,
        weep=(9, 0.15, 0.12, 0.11),
        # the longer curtains (owner: "one being SOME strands going to the
        # ground and then one being all very very long"; d "cut ... to about a fifth")
        variants=[("d", dict(trail=0.2)), ("e", dict(trail=1.0))],
    ),
}


def heading(az, rise):
    return Vector((math.cos(az) * math.cos(rise), math.sin(az) * math.cos(rise), math.sin(rise)))


class Skeleton:
    def __init__(self):
        self.pos, self.rad, self.edges, self.limbs = [], [], [], []

    def node(self, p, r, parent=None):
        self.pos.append(Vector(p))
        self.rad.append(r)
        if parent is not None:
            self.edges.append((parent, len(self.pos) - 1))
        return len(self.pos) - 1

    def limb(self, start, az, rise0, rise1, length, r0, r1, kink, rng, segs=3):
        """A limb from node `start`: it sets off at rise0, kinks from side to
        side and turns up to rise1. Returns its node indices."""
        at = self.pos[start].copy()
        out, prev = [], start
        side = rng.choice((-1, 1))
        for k in range(1, segs + 1):
            t = k / segs
            a = az + math.radians(kink) * side * (1 if k % 2 else -1) * rng.uniform(0.5, 1.0)
            at = at + heading(a, math.radians(rise0 + (rise1 - rise0) * t ** 0.8)) * (length / segs)
            prev = self.node(at, r0 + (r1 - r0) * t, prev)
            out.append(prev)
        self.limbs.append([start] + out)
        return out


def grow(sid, rng):
    """The species' skeleton (unit height) and its cloud seats [(centre, radius)]."""
    rc = RECIPES[sid]
    sk = Skeleton()
    r = rc["trunk"]
    lean_az = rng.uniform(0, math.tau)
    lean_az = rc.get("lean_az", lean_az)   # a landmark leans a way the world can turn to face
    lean = heading(lean_az, 0.0) * rc["lean"]
    top_z = rc["leader"]
    # the trunk: buried a little, flared at the root, a slow bend to the lean
    if "stems" in rc:
        # no trunk: stems from the ground, each leaning out its own way, a cloud at its
        # head, one at its middle and one on a side shoot
        root = sk.node((0, 0, -0.012), r * 1.5)
        az0 = rng.uniform(0, math.tau)
        seats = []
        for si in range(rc["stems"]):
            az = az0 + math.tau * si / rc["stems"] + rng.uniform(-0.3, 0.3)
            ln = top_z * rng.uniform(0.75, 1.05)
            rise = 90.0 - 55.0 * rc["spread"] * rng.uniform(0.7, 1.1)
            stalk = sk.limb(root, az, rise + 8, rise - 14, ln, r, r * 0.45, rc["kink"], rng, 4)
            seats.append((stalk[-1], rc["cloud"] * rng.uniform(0.9, 1.1)))
            seats.append((stalk[1], rc["cloud"] * rng.uniform(0.75, 0.95)))
            shoot = sk.limb(stalk[1], az + rng.choice((-1, 1)) * math.radians(rng.uniform(40, 70)), rise - 20, rise - 30, ln * 0.5,
                            r * 0.6, r * 0.35, rc["kink"], rng, 2)
            seats.append((shoot[-1], rc["cloud"] * rng.uniform(0.75, 0.95)))
        return sk, [[sk.pos[i] + UP * cr * 0.3 * rc["flat"], cr] for i, cr in seats]
    stem = [sk.node((0, 0, -0.006), r * rc.get("flare", 1.9))]
    for z, k in ((0.035, 1.35), (0.11, 1.06), (rc["clear"] * 0.62, 0.98)):
        stem.append(sk.node(lean * (z / top_z) ** 1.5 + Vector((0, 0, z)), r * k, stem[-1]))
    for k in range(rc.get("roots", 0)):
        # great roots running out from the foot and down into the ground (or the water)
        sk.limb(stem[1], lean_az + math.tau * (k + 0.5) / rc["roots"] + rng.uniform(-0.3, 0.3), -6, -30, rng.uniform(0.09, 0.15),
                r * 0.62, r * 0.2, 16, rng, 3)
    root_limbs = len(sk.limbs)
    az0 = rng.uniform(0, math.tau)
    seats = []
    for wi, (wh, n, reach, rise0, rise1, forks) in enumerate(rc["whorls"]):
        hub = sk.node(lean * (wh / top_z) ** 1.5 + Vector((rng.uniform(-0.006, 0.006), rng.uniform(-0.006, 0.006), wh)), r * (0.92 - 0.2 * wi), stem[-1])
        stem.append(hub)
        for i in range(n):
            az = az0 + math.tau * (i + 0.5 * wi) / n + rng.uniform(-0.22, 0.22)
            ln = reach * rng.uniform(0.88, 1.12)
            if "sweep" in rc:
                off = math.atan2(math.sin(az - lean_az), math.cos(az - lean_az))
                az = lean_az + off * (1.0 - 0.7 * rc["sweep"])
                ln *= 1.0 + 0.45 * rc["sweep"] * math.cos(off)
            lr = r * (rc.get("limb", 0.62) - 0.12 * wi)
            segs = rc.get("limb_segs", 3)
            limb = sk.limb(hub, az, rise0 + rng.uniform(-6, 6), rise1 + rng.uniform(-6, 6), ln, lr, lr * rc.get("limb_tip", 0.5), rc["kink"], rng, segs)
            seats.append((limb[-1], rc["cloud"] * rng.uniform(0.95, 1.15)))
            if "along" in rc:
                seats.append((limb[1], rc["cloud"] * rc["along"] * rng.uniform(0.9, 1.05)))
            # each limb forks: side limbs off its middle, shorter, still rising
            for f in range(forks):
                sgn = 1 if f % 2 == 0 else -1
                at = limb[(segs // 3) * (1 if f == 0 else 2) - 1]
                sub = sk.limb(at, az + sgn * math.radians(rng.uniform(42, 62)), rise0 + 14, rise1 + 6, ln * rng.uniform(0.5, 0.62), lr * 0.62, lr * 0.36, rc["kink"] * 0.7, rng, 2)
                seats.append((sub[-1], rc["cloud"] * rng.uniform(0.8, 1.0)))
    # the leader: the trunk's own top, one cloud over the crown
    tip = sk.node(lean + Vector((rng.uniform(-0.02, 0.02), rng.uniform(-0.02, 0.02), top_z)), r * 0.5, stem[-1])
    top2 = sk.node(sk.pos[tip] + Vector((rng.uniform(-0.03, 0.03), rng.uniform(-0.03, 0.03), rc.get("top", 0.13))), r * 0.3, tip)
    seats.append((top2, rc["cloud"] * rc.get("top_cloud", 1.15)))
    # every limb ends inside its cloud: the cloud sits just past the tip
    clouds = []
    for idx, cr in seats:
        out = Vector((sk.pos[idx].x, sk.pos[idx].y, 0.0))
        c = sk.pos[idx] + (out.normalized() * cr * 0.25 if out.length > 1e-5 else Vector()) + UP * cr * 0.35 * rc["flat"]
        if "sweep" in rc:
            c += heading(lean_az, 0.0) * cr * 0.6 * rc["sweep"]
        clouds.append([c, cr])
    if root_limbs:
        sk.limbs = sk.limbs[root_limbs:]   # nothing hangs from a root
    return sk, clouds


def settle(clouds):
    """No cloud floats and none swallows another: neighbours overlap a little."""
    for _ in range(6):
        for q in clouds:
            for o in clouds:
                if o is q:
                    continue
                d = q[0] - o[0]
                want = (q[1] + o[1]) * 0.74
                if 1e-6 < d.length < want:
                    q[0] += d.normalized() * (want - d.length) * 0.25


def wood(sk, name, keep=0.33):
    """The skeleton skinned and subdivided: one smooth body."""
    bm = bmesh.new()
    layer = bm.verts.layers.skin.verify()
    vs = []
    for i, (p, r) in enumerate(zip(sk.pos, sk.rad)):
        v = bm.verts.new(p)
        v[layer].radius = (r, r)
        v[layer].use_root = i == 0
        vs.append(v)
    for a, b in sk.edges:
        bm.edges.new((vs[a], vs[b]))
    me = bpy.data.meshes.new(name + "_skel")
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name + "_skel", me)
    bpy.context.scene.collection.objects.link(ob)
    skin = ob.modifiers.new("skin", "SKIN")
    skin.use_smooth_shade = True
    skin.branch_smoothing = 0.6
    sub = ob.modifiers.new("sub", "SUBSURF")
    sub.levels = 1
    # the subdivided body is rounder than it needs triangles for
    dec = ob.modifiers.new("dec", "DECIMATE")
    dec.ratio = keep
    done = ob.evaluated_get(bpy.context.evaluated_depsgraph_get())
    out = bmesh.new()
    out.from_mesh(done.to_mesh())
    done.to_mesh_clear()
    bpy.data.objects.remove(ob, do_unlink=True)
    return out


def card(bm, uv, col, centre, normal, up, size, tone, u0=0.0, u1=1.0):
    """A card facing `normal`, its picture's top towards `up`; size is a
    side or (width, height); u0..u1 picks a strip of the picture."""
    u = up.cross(normal)
    if u.length < 1e-4:
        u = Vector((1, 0, 0)).cross(normal)
    u.normalize()
    v = normal.cross(u).normalized()
    w, h = (size[0] * 0.5, size[1] * 0.5) if isinstance(size, tuple) else (size * 0.5, size * 0.5)
    f = bm.faces.new([bm.verts.new(centre + u * sx * w + v * sy * h) for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))])
    for loop, st in zip(f.loops, ((u0, 0), (u1, 0), (u1, 1), (u0, 1))):
        loop[uv].uv = st
        loop[col] = (tone, tone, tone, 1.0)


def foliage(sid, clouds, rng):
    """Leaf-clump cards over every cloud (shingled, a few standing out along
    the rim) with the cloud's own normals, and the hearts inside."""
    rc = RECIPES[sid]
    crown = sum((c * r for c, r in clouds), Vector()) / sum(r for _, r in clouds)
    leaves = bmesh.new()
    uv = leaves.loops.layers.uv.new("UVMap")
    col = leaves.loops.layers.float_color.new("Col")
    normals = []
    core = K.Prop("core")
    flat = Matrix.Diagonal((1.0, 1.0, rc["flat"]))
    for ci, (cc, r) in enumerate(clouds):
        tone = 0.9 + 0.2 * rng.random()
        n = max(10, round(4 * math.pi * r * r * rc["cover"] / (rc["card"] ** 2)))
        for i in range(n):
            z = 1.0 - 2.0 * (i + 0.5) / n
            if z < -0.45 and rng.random() < 0.4:
                continue   # thinner on a cloud's underside
            a = i * 2.39996 + rng.uniform(-0.3, 0.3)
            d = Vector((math.sqrt(1 - z * z) * math.cos(a), math.sqrt(1 - z * z) * math.sin(a), z))
            at = cc + flat @ (d * r * 0.92)
            shade = (d * 0.6 + (at - crown).normalized() * 0.4).normalized()
            jit = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1)))
            s = rc["card"] * rng.uniform(0.85, 1.15)
            card(leaves, uv, col, at, (d + jit * 0.45).normalized(), Matrix.Rotation(rng.uniform(0, math.tau), 3, d) @ UP, s, tone)
            normals += [shade] * 4
            if rng.random() < rc["rim"]:
                side = d.cross(jit)
                side = side.normalized() if side.length > 1e-3 else d.orthogonal().normalized()
                card(leaves, uv, col, at + d * s * 0.1, side, side.cross(d), s, tone)
                normals += [shade] * 4
        MF.blob(core, cc.x, cc.y, cc.z, r * 0.62, (1, 1, 1), rng, 1, rc["flat"], fine=1)
    return leaves, normals, core


def curtain(sid, sk, rng, trail=0.0):
    """The willow's fronds. Each is a ribbon of hanging strands that leaves a
    limb, rolls outward over a shoulder and falls: thick along the limbs'
    outer reach and at their tips, so the crown's top is the limbs' arch
    draped in strands and the rest is a curtain to near the ground.
    trail: the share of strands that fall all the way to the ground (0 the
    curtain stops short, 0.3 some trail, 1 every strand is that long)."""
    n, width, reach, foot = RECIPES[sid]["weep"]
    tile = RECIPES[sid].get("frond_tile")
    dip, dip_az = RECIPES[sid].get("dip", 0.0), RECIPES[sid].get("lean_az", 0.0)
    fronds = bmesh.new()
    uv = fronds.loops.layers.uv.new("UVMap")
    col = fronds.loops.layers.float_color.new("Col")
    normals = []
    seats = []
    for limb in sk.limbs:
        pts = [sk.pos[i] for i in limb]
        for k in range(n):
            # along the limb's outer two thirds, crowding towards the tip
            t = 0.2 + 0.8 * ((k + rng.random()) / n) ** 0.8
            f = t * (len(pts) - 1)
            i = min(int(f), len(pts) - 2)
            seats.append((pts[i].lerp(pts[i + 1], f - i) + UP * rng.uniform(-0.012, 0.02), pts[i + 1] - pts[i], t))
        for _ in range(3):
            seats.append((pts[-1].copy(), pts[-1] - pts[-2], 1.0))
    tip = sk.pos[-1]
    for _ in range(n):      # the leader's top: a fountain all round
        seats.append((tip.copy(), Vector((0, 0, 1)), 1.0))
    def hang(at, along, t):
            flat = Vector((along.x, along.y, 0.0))
            a = (math.atan2(flat.y, flat.x) if flat.length > 1e-4 else rng.uniform(0, math.tau)) + rng.uniform(-1.0, 1.0) * (1.3 if flat.length > 1e-4 else math.pi)
            d = Vector((math.cos(a), math.sin(a), 0.0))
            side = d.cross(UP).normalized()
            side = (side + d * rng.uniform(-0.35, 0.35)).normalized()
            w = width * rng.uniform(0.85, 1.2) * 0.5
            r = reach * rng.uniform(0.7, 1.3)
            low = foot * rng.uniform(0.7, 3.0) + (0.0 if t > 0.7 else at.z * rng.uniform(0.2, 0.5))
            if trail > 0.0 and rng.random() < trail:
                low = rng.uniform(0.0, 0.012)    # to the grass
                if dip and at.x * math.cos(dip_az) + at.y * math.sin(dip_az) > 0.1:
                    low = -dip * rng.uniform(0.75, 1.0)    # past the bank, into the water she leans over
            low = min(low, at.z - r)
            # leave the limb, rise a little, roll over the shoulder, fall
            spine = [at, at + d * r * 0.4 + UP * r * 0.3, at + d * r * 0.9 + UP * r * 0.22, at + d * r * 1.3 - UP * r * 0.35]
            spine.append(Vector((spine[-1].x + d.x * r * 0.1, spine[-1].y + d.y * r * 0.1, low)))
            if tile:
                # a long fall is cut into lengths, so the wind can move along it
                a0, a1 = spine[-2], spine[-1]
                cuts = max(1, int((a0.z - a1.z) / 0.06))
                spine = spine[:-1] + [a0.lerp(a1, (c + 1) / cuts) for c in range(cuts)]
            lens = [0.0]
            for q0, q1 in zip(spine, spine[1:]):
                lens.append(lens[-1] + (q1 - q0).length)
            half = rng.random() < 0.5
            u0, u1 = (0.0, 0.5) if half else (0.5, 1.0)
            tone = 0.92 + 0.16 * rng.random()
            rows = []
            for q, ln in zip(spine, lens):
                v = 1.0 - ln / lens[-1]
                # tiled: the picture repeats down the strand at its own size, and how far
                # down the strand a point hangs rides in the colour's green
                rows.append((fronds.verts.new(q - side * w), fronds.verts.new(q + side * w), 1.0 - ln / tile if tile else v, 1.0 - v))
                # shade: the shoulder faces the sky, the fall faces out
                normals.extend([(d * (0.35 + 0.5 * (1.0 - v)) + UP * (0.25 + 0.7 * v)).normalized()] * 2)
            for (l0, r0, v0, h0), (l1, r1, v1, h1) in zip(rows, rows[1:]):
                face = fronds.faces.new((l0, r0, r1, l1))
                for loop, st, hg in zip(face.loops, ((u0, v0), (u1, v0), (u1, v1), (u0, v1)), (h0, h0, h1, h1)):
                    loop[uv].uv = st
                    loop[col] = (tone, hg, tone, 1.0) if tile else (tone, tone, tone, 1.0)

    for seat in seats:
        hang(*seat)
    # The wood along the crown's top wears strands too (owner, 2026-11-12: "i
    # want that brown branch covered just a little bit more"): short ones
    # leave from just above it and fall to either side.
    crown_top = max(q.z for q, _, _ in seats)
    flip = 1
    for a, b in sk.edges:
        pa, pb = sk.pos[a], sk.pos[b]
        if (pa.z + pb.z) * 0.5 < crown_top * RECIPES[sid].get("drape_from", 0.72):
            continue
        steps = max(1, round((pb - pa).length / 0.045))
        for k in range(steps):
            f = (k + 0.5) / steps
            q = pa.lerp(pb, f) + UP * (sk.rad[a] + (sk.rad[b] - sk.rad[a]) * f + 0.006)
            along = pb - pa
            across = Vector((-along.y, along.x, 0.0)) * flip
            flip = -flip
            hang(q, across if across.length > 1e-4 else Vector((0, 0, 1)), 0.5)
    return fronds, normals


def tears(sid, sk, rng):
    """The Weeping Lady's flowering strands: chains of blossom hanging among
    the fronds, each floret two crossed petals, full at the top and thinning
    to the tip, where one drop of light hangs (her tears). Made for the woods'
    foliage shader, not the estate's: the colour is the vertex's own, UV.x is
    how far down the chain a floret hangs (the wind's hold on it) and UV.y how
    much it glows."""
    per_limb, lo, hi, size = RECIPES[sid]["tears"]
    top_c, mid_c, tip_c, drop_c = RECIPES[sid]["tear_colours"]
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    col = bm.loops.layers.float_color.new("Col")

    def petal(at, yaw, s, c, flex, glow):
        # two crossed diamonds: a point above, a longer point below
        for turn in (0.0, math.pi * 0.5):
            side = Vector((math.cos(yaw + turn), math.sin(yaw + turn), 0.0)) * s * 0.42
            quad = [bm.verts.new(q) for q in (at + UP * s * 0.5, at + side, at - UP * s * 0.7, at - side)]
            face = bm.faces.new(quad)
            for loop in face.loops:
                # (glTF turns V over: 1 - glow here is glow in the game)
                loop[uv].uv = (flex, 1.0 - glow)
                loop[col] = (c[0], c[1], c[2], 1.0)

    def mix3(t):
        a, b, f = (top_c, mid_c, t * 2.0) if t < 0.5 else (mid_c, tip_c, t * 2.0 - 1.0)
        return tuple(a[i] + (b[i] - a[i]) * f for i in range(3))

    for limb in sk.limbs:
        pts = [sk.pos[i] for i in limb]
        for k in range(per_limb + 1):
            t = 1.0 if k == per_limb else 0.25 + 0.75 * (k + rng.random()) / per_limb
            f = t * (len(pts) - 1)
            i = min(int(f), len(pts) - 2)
            on = pts[i].lerp(pts[i + 1], f - i)
            # outside the curtain of fronds, where they show: past where the fronds fall
            a = math.atan2(on.y, on.x) + rng.uniform(-0.5, 0.5)
            start = on + Vector((math.cos(a), math.sin(a), 0.0)) * (RECIPES[sid]["weep"][2] * rng.uniform(1.45, 1.75)) - UP * rng.uniform(0.0, 0.04)
            length = min(rng.uniform(lo, hi), start.z - 0.02)
            if length < size * 4:
                continue
            drift = Vector((math.cos(a), math.sin(a), 0.0)) * rng.uniform(0.0, 0.02)
            count = max(4, int(length / (size * 1.25)))
            for j in range(count):
                u = j / (count - 1)
                s = size * (1.05 - 0.55 * u) * rng.uniform(0.85, 1.15)
                off = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), 0.0)) * s * 0.45
                c = mix3(min(1.0, max(0.0, u + rng.uniform(-0.12, 0.12))))
                petal(start - UP * length * u + drift * u + off, rng.uniform(0, math.tau), s, c, min(1.0, length * u / 0.3), 0.1 + 0.2 * u)
            # the tear
            petal(start - UP * (length + size * 1.3) + drift, rng.uniform(0, math.tau), size * 1.5, drop_c, min(1.0, length / 0.3), 0.5)
    return bm


def pears(sid, clouds, rng):
    """Pears hanging under the pear's clouds."""
    fruit = K.Prop("fruit")
    for cc, r in clouds:
        for _ in range(int(RECIPES[sid]["fruit"] + rng.random())):
            a = rng.uniform(0, math.tau)
            at = cc + Vector((math.cos(a), math.sin(a), 0.0)) * r * rng.uniform(0.3, 0.85) - UP * r * RECIPES[sid]["flat"] * rng.uniform(0.7, 0.95)
            s = rng.uniform(0.85, 1.15)
            fruit.add(K.lathe([(0, 0), (0.021 * s, 0.012 * s), (0.012 * s, 0.036 * s), (0, 0.047 * s)], 6), (0.86, 0.9, 0.46) if rng.random() < 0.7 else (0.95, 0.84, 0.5), MF.F,
                      K.T(at.x, at.y, at.z - 0.04 * s))
    return fruit


def build(sid, letter, seed, **opts):
    h = COURT[sid] if sid in COURT else MF.species()[sid][1]
    name = f"tree_{sid}_{letter}"
    rng = random.Random(seed)
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    sk, clouds = grow(sid, rng)
    settle(clouds)
    rc = RECIPES[sid]
    bark = wood(sk, name, rc.get("wood", 0.33))
    weep = "weep" in rc
    leaves, normals, core = foliage(sid, clouds, rng) if not weep else (None, [], None)
    fronds, frond_normals = curtain(sid, sk, rng, opts.get("trail", rc.get("trail", 0.0))) if weep else (None, [])
    fruit = pears(sid, clouds, rng) if "fruit" in rc else None
    bloom = tears(sid, sk, rng) if "tears" in rc else None
    # to the species height, standing on the ground (the root stays buried)
    crown = [fronds] if weep else [leaves, core.bm]
    top = max(v.co.z for b in crown for v in b.verts)
    m = K.S(h / top)
    if "sink" in rc:
        # a deep foot: the whole tree set down into the ground, for standing on a slope
        m = Matrix.Translation((0.0, 0.0, -rc["sink"] * h)) @ m
    meshes = [("bark", bark, None)] + ([("fronds", fronds, frond_normals)] if weep else [("leaves", leaves, normals)])
    for b in [b for _, b, _ in meshes] + ([core.bm] if core else []) + ([fruit.bm] if fruit else []) + ([bloom] if bloom else []):
        bmesh.ops.transform(b, matrix=m, verts=b.verts)
    parts = meshes + ([("core", core.bm, None)] if core else []) + ([("fruit", fruit.bm, None)] if fruit else [])
    parts += [("bloom", bloom, None)] if bloom else []
    if opts.get("far"):
        return far_form(sid, name, sk, clouds, rng, m, fronds)
    ob, tris = assemble(name, parts)
    total = sum(tris.values())
    print(f"  {name:24s} {total:5d} tris ({', '.join(f'{k} {v}' for k, v in tris.items())}; {len(clouds)} seats)")
    K.export_glb([ob], os.path.join(COURT_OUT if sid in COURT else OUT, f"{name}.glb"))
    return total


def far_form(sid, name, sk, clouds, rng, m, fronds):
    """The tree from far off: its wood at a fraction of the triangles, each
    cloud one coarse ball at the cloud's full size (so the outline is the near
    tree's), and a weeping tree's fronds thinned to every fourth, widened to
    keep the veil. Two surfaces: tree_bark and tree_core (or tree_fronds)."""
    rc = RECIPES[sid]
    bark = wood(sk, name + "_far", rc.get("wood", 0.33) * 0.12)
    bmesh.ops.transform(bark, matrix=m, verts=bark.verts)
    parts = [("bark", bark, None)]
    if fronds is not None:
        # every fourth strand (a strand is a run of quads sharing no vert with the next), four times as wide
        thin = bmesh.new()
        uv = thin.loops.layers.uv.new("UVMap")
        col = thin.loops.layers.float_color.new("Col")
        fuv, fcol = fronds.loops.layers.uv.active, fronds.loops.layers.float_color.active
        fronds.verts.ensure_lookup_table()
        seen, strand = set(), 0
        for f in fronds.faces:
            if f.index in seen:
                continue
            # walk this strand: the faces linked through shared edges
            stack, run = [f], []
            while stack:
                g = stack.pop()
                if g.index in seen:
                    continue
                seen.add(g.index)
                run.append(g)
                for e in g.edges:
                    stack.extend(h for h in e.link_faces if h.index not in seen)
            strand += 1
            if strand % 4:
                continue
            for g in run:
                mid = sum((v.co for v in g.verts), Vector()) / len(g.verts)
                # widen across the strand only: keep each vert's height
                vs = [thin.verts.new(Vector((mid.x + (v.co.x - mid.x) * 4.0, mid.y + (v.co.y - mid.y) * 4.0, v.co.z))) for v in g.verts]
                h = thin.faces.new(vs)
                for src, dst in zip(g.loops, h.loops):
                    dst[uv].uv = src[fuv].uv
                    dst[col] = src[fcol]
        thin.verts.index_update()
        thin.normal_update()
        normals = []
        for v in thin.verts:
            out = Vector((v.co.x, v.co.y, 0.0))
            normals.append(((out.normalized() if out.length > 1e-4 else Vector((1, 0, 0))) * 0.6 + UP * 0.6).normalized())
        parts.append(("fronds", thin, normals))
    else:
        core = K.Prop("core")
        for cc, r in clouds:
            MF.blob(core, cc.x, cc.y, cc.z, r * 0.97, (1, 1, 1), rng, 1, rc["flat"])
        bmesh.ops.transform(core.bm, matrix=m, verts=core.bm.verts)
        parts.append(("core", core.bm, None))
    ob, tris = assemble(name + "_far", parts)
    total = sum(tris.values())
    print(f"  {name + '_far':24s} {total:5d} tris ({', '.join(f'{k} {v}' for k, v in tris.items())})")
    os.makedirs(FAR_OUT, exist_ok=True)
    K.export_glb([ob], os.path.join(FAR_OUT, f"{name}_far.glb"))
    return 0


def assemble(name, parts):
    """One mesh from the parts [(label, bmesh, normals or None)], a material
    slot per part (tree_<label>); a part without its own normals is smooth."""
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    col = bm.loops.layers.float_color.new("Col")
    normals, tris = [], {}
    for slot, (label, part, own) in enumerate(parts):
        part.verts.index_update()
        part.normal_update()
        puv = part.loops.layers.uv.active
        pcol = part.loops.layers.float_color.active
        new = [bm.verts.new(v.co) for v in part.verts]
        normals += [Vector(n) for n in own] if own else [v.normal.copy() for v in part.verts]
        tris[label] = 0
        for f in part.faces:
            g = bm.faces.new([new[v.index] for v in f.verts])
            g.material_index = slot
            g.smooth = True
            tris[label] += len(f.verts) - 2
            for src, dst in zip(f.loops, g.loops):
                dst[uv].uv = src[puv].uv if puv else (0.0, 0.0)
                dst[col] = src[pcol] if pcol else (1.0, 1.0, 1.0, 1.0)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    me.normals_split_custom_set_from_vertices([tuple(n) for n in normals])
    me.color_attributes.active_color_name = "Col"
    me.attributes.default_color_name = "Col"
    for label, _, _ in parts:
        me.materials.append(bpy.data.materials.get(f"tree_{label}") or bpy.data.materials.new(f"tree_{label}"))
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob, tris


def main():
    K.reset()
    # (the court's great trees are built by name: a plain run rebuilds the estate's only)
    only = sys.argv[sys.argv.index("--only") + 1].split(",") if "--only" in sys.argv else [r for r in RECIPES if r not in COURT]
    seeds = int(sys.argv[sys.argv.index("--seeds") + 1]) if "--seeds" in sys.argv else 3
    far = "--far" in sys.argv   # the far forms of the same builds, and nothing else
    over = []
    for sid in only:
        jobs = [("abcdef"[k], {}) for k in range(seeds)] + RECIPES[sid].get("variants", [])
        for k, (letter, opts) in enumerate(jobs):
            total = build(sid, letter, sum(map(ord, sid)) * 7 + 101 * k, far=far, **opts)
            if total > RECIPES[sid].get("budget", BUDGET):
                over.append((sid, letter, total))
    if over:
        sys.exit(f"over the {BUDGET}-triangle tree budget: {over}")


if __name__ == "__main__":
    main()
