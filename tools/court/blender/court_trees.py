"""The wider court's leafy trees as painterly leaf-card models (owner's pick,
2026-11-10, from the M1 direction test: tools/court/blender/tree_directions.py,
style B). Five builds of every species, so a wood never shows the same tree
twice side by side.

Each tree: a Skin-modifier trunk and limbs (the woods_trees.py kit), a dark
inner core, and a crown of leaf cards. A card is a quad facing out of the
crown with a random twist; its leaves come from the painted leaf atlas
(tools/court/gen_leaf_atlas.py) through UV1 (Godot UV2), and it carries the
crown's outward normal, so the crown lights as one soft mass with a broken,
leafy edge. Colour is painted per card into COLOR_0 (sRGB): dark inside and
underneath, sunlit on top and on the sun side; blossom on a blossom tree's
outer cards. The trunk and core are material slot 0 (woods_foliage), the
cards slot 1 (court_leaf_card).

The builds of a species differ in trunk height and lean, crown width, height
and seat, the number of limbs and leaf clusters, the size of the sky holes,
and a small shift in the greens; the scatter adds yaw, scale and a per-tree
tint on top (court_leaf_card.gdshader).

Run (headless Blender, `pip install bpy`):
  <venv>/bin/python tools/court/blender/court_trees.py [out_dir] [species...]
Out: world/spring_court/shared/models/cards/<species>_v<n>.glb, n = 0..4,
each with a "near" mesh (<= 3000 tris, 4500 for the ancient oak; R4) and a
"far" mesh (<= 600 tris: fewer, bigger cards and a plain trunk) for the
court's tree impostor range.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "..", "woods", "blender"))
import woods_trees as wt  # noqa: E402

import bpy  # noqa: E402
from mathutils import Vector, noise  # noqa: E402

OUT = sys.argv[1] if len(sys.argv) > 1 and sys.argv[1] else os.path.join(
    os.path.dirname(__file__), "..", "..", "..", "world", "spring_court", "shared", "models", "cards")
VARIANTS = 5
FAR_CAP = 600
WOOD = 1300  # near trunk and limb triangles, unless the species says
SUN = Vector((0.35, 0.25, 0.9)).normalized()
hexc, mix, shade = wt.hexc, wt.mix, wt.shade

# Atlas cells (gen_leaf_atlas.py): 0 broad, 1 small, 2 long, 3 blossom.
BROAD, SMALL, LONG, BLOSSOM = 0, 1, 2, 3

# Palettes (sRGB): deep painted greens, no lime; the sunlit tops soft and
# only a little yellowed (the M1 test's oak and birch read too yellow).
GREENS = dict(shadow=hexc("1E3E37"), mid=hexc("386C47"), light=hexc("5C9152"), sun=hexc("84AB62"))
OLD_GREENS = dict(shadow=hexc("1A3833"), mid=hexc("2F6043"), light=hexc("4F844E"), sun=hexc("78A05C"))
BIRCH = dict(shadow=hexc("32563B"), mid=hexc("528445"), light=hexc("82AA5C"), sun=hexc("A6C070"))
YEW = dict(shadow=hexc("183B36"), mid=hexc("29594D"), light=hexc("467B5C"), sun=hexc("6C9568"))
WILLOW = dict(shadow=hexc("2C4F3C"), mid=hexc("4C7E4C"), light=hexc("7DA563"), sun=hexc("A3BE77"))
SHRUB = dict(shadow=hexc("23443A"), mid=hexc("3E7149"), light=hexc("62935A"), sun=hexc("88AD66"))
# Blossom: the colour of the outer cards (petals) over the tree's greens.
CHERRY_BLOOM = (hexc("B65C84"), hexc("E48DAD"), hexc("F7C6D5"))
APPLE_BLOOM = (hexc("C27C8E"), hexc("F0B3C2"), hexc("FBE3E8"))
LILAC_BLOOM = (hexc("7E5FA8"), hexc("B89AE0"), hexc("DCCBF4"))
CREAM_BLOOM = (hexc("C9BFA6"), hexc("F1EBDA"), hexc("FFFBF0"))
BARK0, BARK1 = hexc("4E3A3C"), hexc("75585A")
BIRCH_BARK, BIRCH_BAND = hexc("EEE8E2"), hexc("3A3036")
YEW_BARK = (hexc("4A2E2A"), hexc("6E4038"))

# Species. Lengths in metres. trunk: height to the crown's base; rx, rz: the
# crown's half width and half height; sit: how far up the crown sits on the
# trunk top (in rz); count: leaf clusters; cards: cards per cluster; cluster:
# cluster size range; holes: noise threshold (lower = more sky holes);
# leaf: atlas cell; bloom: blossom colours on the outer cards.
SPECIES = {
    "ancient_oak": dict(cap=4500, wood=2200, trunk=4.6, r0=1.25, flare=0.65, lean=0.06, rx=8.4, rz=5.0, sit=0.55,
                        pal=OLD_GREENS, count=46, cards=15, cluster=(1.6, 2.3), holes=0.42, limbs=10, leaf=BROAD),
    "oak": dict(trunk=4.2, r0=0.62, flare=0.5, rx=5.6, rz=3.8, sit=0.6, pal=GREENS, count=30, cards=17,
                cluster=(1.25, 1.9), holes=0.38, limbs=8, leaf=BROAD),
    "silver_birch": dict(trunk=4.6, r0=0.24, lean=0.04, rx=2.6, rz=5.0, sit=0.72, pal=BIRCH, count=28, cards=12,
                         cluster=(0.65, 1.0), holes=0.28, floor=-0.85, birch=True, leaf=SMALL),
    "wild_cherry": dict(trunk=2.8, r0=0.32, lean=0.16, rx=4.4, rz=2.7, sit=0.5, pal=GREENS, count=26, cards=15,
                        cluster=(1.0, 1.45), holes=0.4, limbs=8, leaf=BROAD, bloom=CHERRY_BLOOM, bloom_share=0.75),
    "crab_apple": dict(trunk=2.2, r0=0.3, lean=0.24, rx=4.0, rz=2.4, sit=0.5, pal=GREENS, count=24, cards=14,
                       cluster=(0.95, 1.35), holes=0.4, limbs=7, leaf=BROAD, bloom=APPLE_BLOOM, bloom_share=0.6),
    "lilac_tree": dict(wood=800, trunk=2.4, r0=0.16, lean=0.2, stems=3, rx=2.8, rz=2.4, sit=0.45, pal=SHRUB, count=22,
                       cards=12, cluster=(0.8, 1.15), holes=0.35, limbs=6, leaf=BROAD, bloom=LILAC_BLOOM,
                       bloom_share=0.5),
    "willow": dict(trunk=3.0, r0=0.55, lean=0.22, rx=5.0, rz=3.0, sit=0.45, pal=WILLOW, count=22, cards=10,
                   cluster=(1.1, 1.5), holes=0.45, limbs=7, leaf=LONG, weep=6),
    "hawthorn": dict(wood=800, trunk=1.8, r0=0.22, lean=0.32, rx=2.8, rz=2.1, sit=0.5, pal=SHRUB, count=20, cards=12,
                     cluster=(0.75, 1.1), holes=0.35, limbs=6, leaf=SMALL, bloom=CREAM_BLOOM, bloom_share=0.4),
    "elder": dict(wood=800, trunk=1.6, r0=0.15, lean=0.35, stems=2, rx=2.4, rz=1.8, sit=0.5, pal=SHRUB, count=18, cards=12,
                  cluster=(0.7, 1.0), holes=0.35, limbs=5, leaf=SMALL, bloom=CREAM_BLOOM, bloom_share=0.3),
    "yew": dict(trunk=1.4, r0=0.5, flare=0.5, rx=3.4, rz=4.6, sit=0.85, pal=YEW, count=30, cards=14,
                cluster=(0.85, 1.25), holes=0.6, floor=-0.9, cone=0.75, limbs=4, leaf=LONG, bark=YEW_BARK),
}


class CardKit(wt.Kit):
    """A Kit with a material slot and a second UV per face: slot 0
    woods_foliage (wood, core), slot 1 court_leaf_card (cards)."""

    def __init__(self, seed):
        super().__init__(seed)
        self.mats, self.uv2, self.slot = [], [], 0

    def face(self, idx, cols, uvs, uv2=((0.0, 0.0), (0.0, 0.0), (0.0, 0.0))):
        super().face(idx, cols, uvs)
        self.mats.append(self.slot)
        self.uv2.append(tuple(uv2))

    def cull_buried(self):
        self.blobs = []
        return 0


def vary(spec, v, rng):
    """Build v of a species: the same tree, grown differently."""
    if v == 0:
        return dict(spec)
    s = dict(spec)
    s["trunk"] = spec["trunk"] * rng.uniform(0.82, 1.2)
    s["lean"] = spec.get("lean", 0.08) * rng.uniform(0.6, 1.6)
    s["rx"] = spec["rx"] * rng.uniform(0.82, 1.18)
    s["rz"] = spec["rz"] * rng.uniform(0.85, 1.18)
    s["sit"] = spec.get("sit", 0.55) * rng.uniform(0.85, 1.15)
    s["count"] = max(8, int(round(spec["count"] * rng.uniform(0.85, 1.12))))
    s["holes"] = spec.get("holes", 0.35) + rng.uniform(-0.08, 0.08)
    s["limbs"] = max(2, spec.get("limbs", 7) + rng.choice((-2, -1, 0, 1, 1)))
    # A small shift in the greens: some trees a touch warmer, some cooler.
    warm = rng.uniform(-1.0, 1.0)
    k = rng.uniform(0.93, 1.06)

    def tint(c):
        return shade((c[0] * (1 + 0.05 * warm), c[1], c[2] * (1 - 0.05 * warm)), k)

    s["pal"] = {key: tint(c) for key, c in spec["pal"].items()}
    if "bloom" in spec:
        s["bloom"] = tuple(tint(c) for c in spec["bloom"])
        s["bloom_share"] = min(0.9, spec["bloom_share"] * rng.uniform(0.8, 1.2))
    return s


def env_normal(p, c, rx, rz):
    d = p - c
    return Vector((d.x / (rx * rx), d.y / (rx * rx), d.z / (rz * rz))).normalized()


def crown_colour(pal, p, c, rx, rz, n_out):
    """Painted light: dark inside and underneath, sunlit on top and on the
    sun side. Returns the colour and how lit the spot is (0..1)."""
    h = max(0.0, min(1.0, (p.z - (c.z - rz)) / (2.0 * rz)))
    d = p - c
    out = max(0.0, min(1.0, math.sqrt((d.x / rx) ** 2 + (d.y / rx) ** 2 + (d.z / rz) ** 2)))
    sun = max(0.0, n_out.dot(SUN))
    k = 0.35 * h + 0.35 * out + 0.45 * sun
    if k < 0.45:
        col = mix(pal["shadow"], pal["mid"], k / 0.45)
    elif k < 0.8:
        col = mix(pal["mid"], pal["light"], (k - 0.45) / 0.35)
    else:
        col = mix(pal["light"], pal["sun"], min(1.0, (k - 0.8) / 0.3))
    return col, k


def bloom_colour(bloom, k):
    deep, mid, light = bloom
    return mix(deep, mid, min(1.0, k / 0.6)) if k < 0.6 else mix(mid, light, min(1.0, (k - 0.6) / 0.5))


def cluster_points(kit, c, rx, rz, count, holes, floor=-0.55, cone=0.0, lift=0.15):
    """Leaf-cluster centres on the crown's shell: noise-carved sky holes, an
    open underside, an upward bias; `cone` narrows the top (the yew)."""
    pts = []
    seed = Vector((kit.rng.random() * 40, kit.rng.random() * 40, kit.rng.random() * 40))
    tries = 0
    while len(pts) < count and tries < count * 40:
        tries += 1
        v = Vector((kit.rng.gauss(0, 1), kit.rng.gauss(0, 1), kit.rng.gauss(0, 1) + lift)).normalized()
        if v.z < floor or noise.noise(v * 2.2 + seed) > holes:
            continue
        r = kit.rng.uniform(0.62, 0.95)
        narrow = 1.0 - cone * (v.z + 1.0) * 0.5
        pts.append(c + Vector((v.x * rx * r * narrow, v.y * rx * r * narrow, v.z * rz * r)))
    return pts


def card(kit, p, normal, facing, size, col, cell, flex):
    """One leaf card: a quad facing `facing` with a random twist, its UV2 in
    atlas cell `cell`, shaded with `normal`."""
    side = facing.orthogonal().normalized()
    twist = kit.rng.uniform(0, math.tau)
    u = (side * math.cos(twist) + facing.cross(side) * math.sin(twist)).normalized()
    w = facing.cross(u).normalized()
    corners = [p + (u * a + w * b) * size for a, b in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    ids = [kit.add_vert(q) for q in corners]
    for i in ids:
        kit.normals[i] = normal
    ox, oy = (cell % 2) * 0.5, (cell // 2) * 0.5
    uv2 = [(ox + 0.5 * a, oy + 0.5 * b) for a, b in ((0, 0), (1, 0), (1, 1), (0, 1))]
    for tri in ((0, 1, 2), (0, 2, 3)):
        kit.face(tuple(ids[t] for t in tri), (col, col, col), tuple((flex, 0.0) for _ in tri),
                 tuple(uv2[t] for t in tri))


def leaf_cluster(kit, s, at, radius, count, c, rx, rz, flex):
    for _ in range(count):
        off = Vector((kit.rng.uniform(-1, 1), kit.rng.uniform(-1, 1), kit.rng.uniform(-0.6, 1))) * radius * 0.55
        p = at + off
        ne = env_normal(p, c, rx, rz)
        facing = (ne + Vector((kit.rng.uniform(-0.6, 0.6), kit.rng.uniform(-0.6, 0.6),
                               kit.rng.uniform(-0.3, 0.6)))).normalized()
        col, k = crown_colour(s["pal"], p, c, rx, rz, ne)
        cell = s["leaf"]
        if "bloom" in s and k > 1.0 - s["bloom_share"] * 1.1 and kit.rng.random() < 0.85:
            col, cell = bloom_colour(s["bloom"], k), BLOSSOM
        col = shade(col, 1.0 + kit.rng.uniform(-0.07, 0.07))
        card(kit, p, ne, facing, radius * kit.rng.uniform(0.75, 1.1), col, cell, flex)


def weeping(kit, s, pts, c, rx, rz, near):
    """Willow curtains: chains of long-leaf cards hanging from the crown's
    lower clusters, facing out horizontally."""
    lows = sorted(pts, key=lambda q: q.z)[: s["weep"] * (2 if near else 1)]
    for t in lows:
        out = Vector((t.x - c.x, t.y - c.y, 0.0))
        out = out.normalized() if out.length > 1e-3 else Vector((1, 0, 0))
        steps = 4 if near else 2
        size = 0.75 if near else 1.3
        for k in range(steps):
            p = t + out * (0.25 * k) + Vector((0, 0, -size * 1.5 * (k + 0.5)))
            col, lit = crown_colour(s["pal"], t, c, rx, rz, out)
            col = shade(col, 0.95 - 0.08 * k)
            per = 3 if near else 1
            for _ in range(per):
                f = (out + Vector((kit.rng.uniform(-0.5, 0.5), kit.rng.uniform(-0.5, 0.5), 0))).normalized()
                card(kit, p + Vector((kit.rng.uniform(-0.3, 0.3), kit.rng.uniform(-0.3, 0.3), 0)), out, f,
                     size * kit.rng.uniform(0.85, 1.15), col, LONG, 0.6 + 0.1 * k)


def limbs_to(kit, base, targets, r_limb, bark, sides):
    for t in targets:
        d = t - base
        mid = base + d * 0.5 + Vector((0, 0, d.length * 0.08))
        line = [base, mid, base + d * 0.92]
        kit.tube(line, [r_limb, r_limb * 0.55, r_limb * 0.2], sides, bark[0], bark[1], 0.1, 0.4)


def grow(kit, s, near):
    bark = s.get("bark", (BARK0, BARK1))
    stems = s.get("stems", 1)
    tops = []
    for k in range(stems):
        base = Vector((0, 0, 0))
        if stems > 1:
            a = math.tau * k / stems + kit.rng.uniform(-0.3, 0.3)
            base = Vector((math.cos(a), math.sin(a), 0)) * 0.25
        trunk = [base + p for p in wt.trunk_line(kit, s["trunk"], 5 if near else 2, s.get("lean", 0.08))]
        if s.get("birch"):
            radii = wt.taper(len(trunk), s["r0"], s["r0"] * 0.35)
            if near:
                for i in range(len(trunk) - 1):
                    band = BIRCH_BARK if i % 2 == 0 else BIRCH_BAND
                    kit.tube(trunk[i:i + 2], radii[i:i + 2], 7, band, BIRCH_BARK, 0.02 * i, 0.02 * (i + 1))
            else:
                kit.tube(trunk, radii, 4, BIRCH_BARK, BIRCH_BARK)
            top_line = [trunk[-1], trunk[-1] + Vector((0, 0, s["rz"] * 1.2))]
            kit.tube(top_line, [radii[-1], 0.04], 6 if near else 3, BIRCH_BARK, BIRCH_BARK, 0.1, 0.4)
        else:
            r0 = s["r0"] / (1.0 if stems == 1 else 1.3)
            kit.tube(trunk, wt.taper(len(trunk), r0, r0 * 0.55), 9 if near else 4, bark[0], bark[1], 0.0, 0.08,
                     flare=s.get("flare", 0.4) if near else 0.0)
        tops.append(Vector(trunk[-1]))
    top = sum(tops, Vector()) / len(tops)
    c = top + Vector((0, 0, s["rz"] * s.get("sit", 0.55)))
    rx, rz = s["rx"], s["rz"]
    pts = cluster_points(kit, c, rx, rz, s["count"] if near else max(6, s["count"] // 3), s.get("holes", 0.35),
                         floor=s.get("floor", -0.55), cone=s.get("cone", 0.0))
    if not s.get("birch"):
        reach = [p for i, p in enumerate(sorted(pts, key=lambda q: -q.z)) if i % 3 == 0]
        n = s.get("limbs", 7) if near else max(2, s.get("limbs", 7) // 2)
        for i, t in enumerate(reach[:n]):
            limbs_to(kit, tops[i % len(tops)], [t], s["r0"] * 0.5, bark, 6 if near else 3)
    kit.slot = 1
    lo, hi = s["cluster"]
    if near:
        # Inner clusters instead of a solid core (a smooth dark core showed
        # through the sky holes up close): deep, shaded leaves fill the crown.
        inner = cluster_points(kit, c, rx * 0.55, rz * 0.55, max(4, s["count"] // 4), 0.9, floor=-0.7)
        for p in inner:
            leaf_cluster(kit, s, p, kit.rng.uniform(lo, hi) * 1.2, max(4, s["cards"] // 2), c, rx, rz, 0.4)
    for p in pts:
        if near:
            leaf_cluster(kit, s, p, kit.rng.uniform(lo, hi) * 1.25, s["cards"], c, rx, rz, 0.5)
        else:
            leaf_cluster(kit, s, p, kit.rng.uniform(lo, hi) * 2.1, max(3, s["cards"] // 3), c, rx, rz, 0.5)
    if s.get("weep"):
        weeping(kit, s, pts, c, rx, rz, near)
    kit.slot = 0


def to_object(kit, name):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([tuple(v) for v in kit.verts], [], kit.faces)
    mesh.update()
    col = mesh.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
    uv = mesh.uv_layers.new(name="UVMap")
    uv2 = mesh.uv_layers.new(name="Card")
    for poly in mesh.polygons:
        for k, li in enumerate(poly.loop_indices):
            c = kit.colors[poly.index][k]
            col.data[li].color = (c[0], c[1], c[2], 1.0)
            u = kit.uvs[poly.index][k]
            uv.data[li].uv = (u[0], 1.0 - u[1])  # glTF flips V on export
            w = kit.uv2[poly.index][k]
            uv2.data[li].uv = (w[0], 1.0 - w[1])
        poly.use_smooth = True
        poly.material_index = kit.mats[poly.index]
    mesh.color_attributes.active_color = col
    if kit.normals:
        normals = [kit.normals.get(i) or v.normal.copy() for i, v in enumerate(mesh.vertices)]
        mesh.normals_split_custom_set_from_vertices([tuple(n) for n in normals])
    for mname in ("woods_foliage", "court_leaf_card"):
        mesh.materials.append(bpy.data.materials.get(mname) or bpy.data.materials.new(mname))
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def build(species, v):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    base = SPECIES[species]
    seed = sum(ord(ch) * (i + 1) for i, ch in enumerate(species)) + 7919 * v
    cap = base.get("cap", 3000)
    objs, counts = [], []
    for name, near in (("near", True), ("far", False)):
        kit = CardKit(seed)
        s = vary(base, v, wt.random.Random(seed * 31 + 7))
        if near:
            kit.skin = wt.SkinGraph()
        grow(kit, s, near)
        crown = kit.tri_count()
        if near:
            kit.slot = 0
            # Wood takes what it needs, not the whole cap: the crowns are cheap
            # cards and a wood of these is many trees on screen.
            wt.skin_wood(kit, max(450, min(base.get("wood", WOOD), cap - crown - 10)))
        limit = cap if near else FAR_CAP
        if kit.tri_count() > limit:
            raise SystemExit("%s_v%d %s: %d tris over the %d cap" % (species, v, name, kit.tri_count(), limit))
        counts.append((kit.tri_count(), crown))
        objs.append(to_object(kit, name))
    path = os.path.join(OUT, "%s_v%d.glb" % (species, v))
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_yup=True,
                              export_vertex_color="ACTIVE", export_all_vertex_colors=False,
                              export_normals=True, export_texcoords=True, export_materials="PLACEHOLDER",
                              export_apply=False, export_animations=False)
    print("TREE %-13s v%d near %4d (cards %4d)  far %3d  %4.0f KB" % (
        species, v, counts[0][0], counts[0][1], counts[1][0], os.path.getsize(path) / 1024))


def main():
    os.makedirs(OUT, exist_ok=True)
    only = sys.argv[2:] if len(sys.argv) > 2 else list(SPECIES)
    for species in only:
        for v in range(VARIANTS):
            build(species, v)


if __name__ == "__main__":
    main()
