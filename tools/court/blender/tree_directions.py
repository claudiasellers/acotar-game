"""Model direction test (M1, docs/lanes/wider-court-finish-plan.md): four court
trees (oak, silver birch, wild cherry, yew) rebuilt two ways, to judge on the
storybook ground before every species is redone.

  A "storybook deep": the soft storybook shapes kept, but crowns broken into
    many leaf clumps with sky holes and visible limbs, in deep painted greens:
    dark inside and underneath, sunlit only on top, so a crown is darker than
    the sunlit grass and reads as a silhouette. Blossom as colour on the outer
    clumps, not the whole crown.
  B "painterly leaf cards": the same trunks, limbs and crown envelopes, the
    crowns made of leaf cards (quads) whose leaves are painted by the shader
    (world/spring_court/wider/assets/tree_tests/leaf_card.gdshader, alpha
    scissor). The cards carry the crown's outward normal, so the crown lights
    as one soft mass with a broken, leafy edge.

Run (headless Blender, `pip install bpy`):
  <venv>/bin/python tools/court/blender/tree_directions.py [out_dir] [a_oak b_yew ...]
Out: world/spring_court/wider/assets/tree_tests/<a|b>_<species>.glb, one
"near" mesh each. Conventions as tools/woods/blender/woods_trees.py: COLOR_0
albedo in sRGB, UV0.x wind flex, UV0.y glow; B adds UV1 (Godot UV2), the
card's own 0..1 coordinates, and a second material slot "leaf_cards".
Budgets as woods_trees (R4): 3000 tris near, 4500 for an ancient oak.
Preview only: nothing in the game loads these until the owner picks.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "..", "woods", "blender"))
import woods_trees as wt  # noqa: E402

import bpy  # noqa: E402
from mathutils import Vector, noise  # noqa: E402

OUT = sys.argv[1] if len(sys.argv) > 1 and sys.argv[1] else os.path.join(
    os.path.dirname(__file__), "..", "..", "..", "world", "spring_court", "wider", "assets", "tree_tests")
CAP = 3000
SUN = Vector((0.35, 0.25, 0.9)).normalized()
hexc = wt.hexc
mix = wt.mix
shade = wt.shade

# Palettes (sRGB). Deep, painted greens: no lime (the deepest saturation sits
# in the shadow teal-greens, the sunlit tops are soft and yellowed).
GREENS = dict(shadow=hexc("1F4038"), mid=hexc("3C7449"), light=hexc("7DAA5A"), sun=hexc("A8C06E"))
BIRCH = dict(shadow=hexc("355B3E"), mid=hexc("5F8F4A"), light=hexc("A3BE6A"), sun=hexc("CBD48A"))
YEW = dict(shadow=hexc("12302E"), mid=hexc("1F4D45"), light=hexc("3A6E55"), sun=hexc("5E8A62"))
CHERRY = dict(shadow=hexc("2F5340"), mid=hexc("4F7D4E"), light=hexc("E48DAD"), sun=hexc("F7C6D5"),
              blossom_deep=hexc("B65C84"))
BARK0, BARK1 = hexc("4E3A3C"), hexc("75585A")
BIRCH_BARK, BIRCH_BAND = hexc("EEE8E2"), hexc("3A3036")


class CardKit(wt.Kit):
    """A Kit with a material slot and a second UV (the card's own 0..1) per
    face: slot 0 woods_foliage (wood, cores), slot 1 leaf_cards."""

    def __init__(self, seed):
        super().__init__(seed)
        self.mats = []
        self.uv2 = []
        self.slot = 0

    def face(self, idx, cols, uvs, uv2=((0.0, 0.0), (0.0, 0.0), (0.0, 0.0))):
        super().face(idx, cols, uvs)
        self.mats.append(self.slot)
        self.uv2.append(tuple(uv2))

    def cull_buried(self):
        self.blobs = []  # cards overlap on purpose; nothing is buried
        return 0


def crown_colour(pal, p, c, rx, rz, n_out, cherry=False):
    """Painted light baked per vertex: dark inside and underneath, sunlit on
    the top and the sun side; blossom on the outside of a cherry."""
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
    if cherry and k > 0.5:
        # Blossom lies on the outer, upper clumps; the inside stays leaf.
        col = mix(pal["blossom_deep"], col, min(1.0, (k - 0.5) * 2.2))
    return col


def env_normal(p, c, rx, rz):
    d = p - c
    return Vector((d.x / (rx * rx), d.y / (rx * rx), d.z / (rz * rz))).normalized()


def clump_points(kit, c, rx, rz, count, holes, lift=0.15, floor=-0.55, cone=0.0):
    """Clump centres on the crown's ellipsoid shell, with noise-carved sky
    holes and a slight bias upward; `cone` narrows the shell toward the top
    (the yew)."""
    pts = []
    seed = Vector((kit.rng.random() * 40, kit.rng.random() * 40, kit.rng.random() * 40))
    tries = 0
    while len(pts) < count and tries < count * 30:
        tries += 1
        v = Vector((kit.rng.gauss(0, 1), kit.rng.gauss(0, 1), kit.rng.gauss(0, 1) + lift)).normalized()
        if v.z < floor:
            continue  # the underside stays open: limbs and shade show
        if noise.noise(v * 2.2 + seed) > holes:
            continue  # a sky hole
        r = kit.rng.uniform(0.62, 0.95)
        narrow = 1.0 - cone * (v.z + 1.0) * 0.5
        pts.append(c + Vector((v.x * rx * r * narrow, v.y * rx * r * narrow, v.z * rz * r)))
    return pts


def clump(kit, at, radius, pal, c, rx, rz, flex, cherry=False, subdiv=1, lump=0.32):
    """A leaf clump (A): a lumpy icosphere coloured by where it sits in the
    crown; its normals lean toward the crown's, so the crown lights as one
    mass with clump-sized bumps."""
    verts, faces = wt.icosphere(subdiv)
    seed = Vector((kit.rng.random() * 50, kit.rng.random() * 50, kit.rng.random() * 50))
    tint = kit.rng.uniform(-0.06, 0.06)
    idx, cols = [], []
    first = len(kit.faces)
    for v in verts:
        n = noise.noise(v * 2.0 + seed)
        r = radius * (1.0 + lump * n)
        p = at + Vector((v.x * r, v.y * r, v.z * r * 0.82))
        idx.append(kit.add_vert(p))
        ne = env_normal(p, c, rx, rz)
        nn = (Vector(v) * 0.45 + ne * 0.55).normalized()
        kit.normals[idx[-1]] = nn
        col = crown_colour(pal, p, c, rx, rz, ne, cherry)
        col = shade(col, (1.0 + tint) * (0.86 if v.z < -0.2 else 1.0) * (1.0 + 0.08 * max(0.0, n)))
        cols.append(col)
    for f in faces:
        kit.face(tuple(idx[i] for i in f), tuple(cols[i] for i in f), tuple((flex, 0.0) for _ in f))
    kit.blobs.append((at, radius, 0.82, lump, first, len(kit.faces)))


def cards(kit, at, radius, count, pal, c, rx, rz, flex, cherry=False):
    """A leaf cluster (B): `count` cards about `at`, each facing out of the
    crown with a random twist, carrying the crown's outward normal."""
    for _ in range(count):
        off = Vector((kit.rng.uniform(-1, 1), kit.rng.uniform(-1, 1), kit.rng.uniform(-0.6, 1))) * radius * 0.55
        p = at + off
        ne = env_normal(p, c, rx, rz)
        facing = (ne + Vector((kit.rng.uniform(-0.6, 0.6), kit.rng.uniform(-0.6, 0.6), kit.rng.uniform(-0.3, 0.6)))).normalized()
        side = facing.orthogonal().normalized()
        twist = kit.rng.uniform(0, math.tau)
        u = (side * math.cos(twist) + facing.cross(side) * math.sin(twist)).normalized()
        w = facing.cross(u).normalized()
        s = radius * kit.rng.uniform(0.75, 1.1)
        corners = [p + (u * a + w * b) * s for a, b in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
        ids = [kit.add_vert(q) for q in corners]
        for i in ids:
            kit.normals[i] = ne
        col = crown_colour(pal, p, c, rx, rz, ne, cherry)
        col = shade(col, 1.0 + kit.rng.uniform(-0.07, 0.07))
        uv2 = [(0.0, 0.0), (1.0, 0.0), (1.0, 1.0), (0.0, 1.0)]
        for tri in ((0, 1, 2), (0, 2, 3)):
            kit.face(tuple(ids[t] for t in tri), (col, col, col), tuple((flex, 0.0) for _ in tri),
                     tuple(uv2[t] for t in tri))


def limbs_to(kit, trunk_top, targets, r_limb, bark):
    """Limbs from the trunk top out to clump centres, so the crown sits on
    visible wood."""
    for t in targets:
        d = t - trunk_top
        mid = trunk_top + d * 0.5 + Vector((0, 0, d.length * 0.08))
        line = [trunk_top, mid, trunk_top + d * 0.92]
        kit.tube(line, [r_limb, r_limb * 0.55, r_limb * 0.2], 6, bark[0], bark[1], 0.1, 0.4)


def tree(kit, style, spec):
    """Trunk, limbs and a clumped crown (A) or a card crown (B)."""
    near = True
    trunk = wt.trunk_line(kit, spec["trunk"], 5, spec.get("lean", 0.08))
    bark = spec.get("bark", (BARK0, BARK1))
    if spec.get("birch"):
        radii = wt.taper(len(trunk), spec["r0"], spec["r0"] * 0.35)
        for i in range(len(trunk) - 1):
            band = BIRCH_BARK if i % 2 == 0 else BIRCH_BAND
            kit.tube(trunk[i:i + 2], radii[i:i + 2], 7, band, BIRCH_BARK, 0.02 * i, 0.02 * (i + 1))
        # The trunk goes on up through the crown.
        top_line = [trunk[-1], trunk[-1] + Vector((0, 0, spec["rz"] * 1.2))]
        kit.tube(top_line, [radii[-1], 0.04], 6, BIRCH_BARK, BIRCH_BARK, 0.1, 0.4)
    else:
        kit.tube(trunk, wt.taper(len(trunk), spec["r0"], spec["r0"] * 0.55), 9, bark[0], bark[1], 0.0, 0.08,
                 flare=spec.get("flare", 0.4) if near else 0.0)
    top = Vector(trunk[-1])
    c = top + Vector((0, 0, spec["rz"] * spec.get("sit", 0.55)))
    rx, rz, pal = spec["rx"], spec["rz"], spec["pal"]
    cherry = spec.get("cherry", False)
    tiers = spec.get("tiers")
    pts = []
    if tiers:  # the yew: stacked rings, narrowing upward
        for i in range(tiers):
            t = i / (tiers - 1)
            ring_c = top + Vector((0, 0, spec["rz"] * 2.0 * t - spec["rz"] * 0.2))
            rr = rx * (1.0 - 0.75 * t)
            n = max(3, int(spec["count"] * (1.0 - 0.6 * t) / tiers * 1.6))
            for k in range(n):
                a = math.tau * k / n + kit.rng.uniform(-0.3, 0.3)
                pts.append(ring_c + Vector((math.cos(a) * rr, math.sin(a) * rr, kit.rng.uniform(-0.3, 0.3))))
            pts.append(ring_c)
        c = top + Vector((0, 0, spec["rz"] * 0.8))
        rz = spec["rz"] * 1.4
    else:
        pts = clump_points(kit, c, rx, rz, spec["count"], spec.get("holes", 0.35),
                           floor=spec.get("floor", -0.55), cone=spec.get("cone", 0.0))
    # Limbs to a spread of the clumps (not every one: twigs are implied).
    reach = [p for i, p in enumerate(sorted(pts, key=lambda q: -q.z)) if i % spec.get("limb_every", 3) == 0]
    if not spec.get("birch"):
        limbs_to(kit, top, reach[: spec.get("limbs", 7)], spec["r0"] * 0.5, bark)
    sizes = spec["clump"]
    if style == "a":
        # A dark inner core keeps the crown dense where no hole was carved.
        kit.blob(c, min(rx, rz) * 0.62, rz / max(rx, 0.01) * 0.9, pal["shadow"], shade(pal["shadow"], 0.85), 1, 0.35)
        for p in pts:
            clump(kit, p, kit.rng.uniform(*sizes), pal, c, rx, rz, 0.45, cherry)
        if cherry:
            tips = sorted(pts, key=lambda q: -q.z)[: len(pts) // 2]
            for t in tips:
                ne = env_normal(t, c, rx, rz)
                for _ in range(2):
                    kit.flower(t + ne * sizes[1] * 0.9 + Vector((kit.rng.uniform(-0.4, 0.4), kit.rng.uniform(-0.4, 0.4), 0)),
                               ne, 5, 0.22, kit.rng.choice([wt.CREAM, wt.BLUSH, wt.ROSE]), wt.GOLD, 0.55)
    else:
        kit.slot = 0
        kit.blob(c, min(rx, rz) * 0.55, rz / max(rx, 0.01) * 0.9, pal["shadow"], shade(pal["shadow"], 0.85), 1, 0.35)
        kit.slot = 1
        for p in pts:
            cards(kit, p, kit.rng.uniform(*sizes) * 1.25, spec.get("cards", 9), pal, c, rx, rz, 0.5, cherry)
        kit.slot = 0


SPECS = {
    "oak": dict(trunk=4.2, r0=0.62, flare=0.5, rx=5.6, rz=3.8, sit=0.6, pal=GREENS, count=30, holes=0.38,
                clump=(1.25, 1.9), limbs=8, cards=17),
    "silver_birch": dict(trunk=4.6, r0=0.24, lean=0.04, rx=2.6, rz=5.0, sit=0.72, pal=BIRCH, count=28, holes=0.28,
                         floor=-0.85, clump=(0.6, 1.0), birch=True, cards=12),
    "wild_cherry": dict(trunk=2.8, r0=0.32, lean=0.16, rx=4.4, rz=2.7, sit=0.5, pal=CHERRY, count=26, holes=0.4,
                        clump=(1.0, 1.45), cherry=True, limbs=8, cards=15),
    "yew": dict(trunk=1.4, r0=0.5, flare=0.5, rx=3.4, rz=4.6, sit=0.85, pal=YEW, count=30, holes=0.6, floor=-0.9,
                cone=0.75, clump=(0.85, 1.25), limbs=4, cards=14, bark=(hexc("4A2E2A"), hexc("6E4038"))),
}


def to_object(kit, name, cards_kit):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([tuple(v) for v in kit.verts], [], kit.faces)
    mesh.update()
    col = mesh.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
    uv = mesh.uv_layers.new(name="UVMap")
    uv2 = mesh.uv_layers.new(name="Card") if cards_kit else None
    for poly in mesh.polygons:
        for k, li in enumerate(poly.loop_indices):
            c = kit.colors[poly.index][k]
            col.data[li].color = (c[0], c[1], c[2], 1.0)
            u = kit.uvs[poly.index][k]
            uv.data[li].uv = (u[0], 1.0 - u[1])  # glTF flips V on export
            if uv2 is not None:
                w = kit.uv2[poly.index][k]
                uv2.data[li].uv = (w[0], 1.0 - w[1])
        poly.use_smooth = True
        if cards_kit:
            poly.material_index = kit.mats[poly.index]
    mesh.color_attributes.active_color = col
    if kit.normals:
        normals = [kit.normals.get(i) or v.normal.copy() for i, v in enumerate(mesh.vertices)]
        mesh.normals_split_custom_set_from_vertices([tuple(n) for n in normals])
    for mname in (("woods_foliage", "leaf_cards") if cards_kit else ("woods_foliage",)):
        mesh.materials.append(bpy.data.materials.get(mname) or bpy.data.materials.new(mname))
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def build(style, species):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    seed = sum(ord(ch) * (i + 1) for i, ch in enumerate(species))
    kit = CardKit(seed) if style == "b" else wt.Kit(seed)
    kit.skin = wt.SkinGraph()
    tree(kit, style, SPECS[species])
    culled = kit.cull_buried()
    crown = kit.tri_count()
    if isinstance(kit, CardKit):
        kit.slot = 0
    wood = wt.skin_wood(kit, max(450, min(wt.WOOD_MAX, CAP - crown - 10)))
    total = kit.tri_count()
    if total > CAP:
        raise SystemExit("%s_%s: %d tris over the %d cap" % (style, species, total, CAP))
    obj = to_object(kit, "near", style == "b")
    path = os.path.join(OUT, "%s_%s.glb" % (style, species))
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_yup=True,
                              export_vertex_color="ACTIVE", export_all_vertex_colors=False,
                              export_normals=True, export_texcoords=True, export_materials="PLACEHOLDER",
                              export_apply=False, export_animations=False)
    print("TREE %s_%-13s %5d tris (crown %4d after %3d buried, wood %4d)  %4.0f KB" % (
        style, species, total, crown, culled, wood, os.path.getsize(path) / 1024))


def main():
    os.makedirs(OUT, exist_ok=True)
    only = sys.argv[2:] if len(sys.argv) > 2 else ["%s_%s" % (s, sp) for s in "ab" for sp in SPECS]
    for name in only:
        style, species = name.split("_", 1)
        build(style, species)


if __name__ == "__main__":
    main()
