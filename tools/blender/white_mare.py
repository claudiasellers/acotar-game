"""The white mare (lane L47): Feyre's travel mount from the painted stables
(canon ch 9: she rides a white mare with Lucien). Headless Blender (bpy).

Run:  /opt/bpyenv/bin/python tools/blender/white_mare.py [out_dir]
Out:  creatures/models/fae/white_horse.gltf (feet at origin, facing -Z in Godot)
      data/animation/creatures/white_horse_gaits.txt

One horse (director, L47): this is also the beast's white horse of the ch 5
ride north (creatures/fae/white_horse.gd), so the scripted ride and the mount
are the same animal. It replaces white_horse() in fae_creatures.py.

Built on the shared quadruped graph and rig (tools/blender/creatures.py,
creature_rig.py; docs/contracts/creature_motion.md), so she gets the same
bones and clips as every other quadruped: idle, walk, trot, gallop, graze,
hit_l/r, death_l/r. The look is the R3 princess version: a pearl coat, a
flowing blush-and-lilac mane and tail, gold tack, a rose saddle cloth and a
garland of oversized blooms on her brow. The saddle seat is the `spine` bone;
the game seats the rider there (systems/mount/).
"""

import math
import os
import sys

import bpy  # noqa: I001  (bpy must load before bmesh)
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import creatures as base  # noqa: E402
import creature_rig  # noqa: E402

base.OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..", "..", "creatures", "models", "fae")
NAME = "white_horse"
TRI_BUDGET = 15000

SPEC = {
    "length": 2.25, "height": 1.58, "width": 0.62, "girth": 0.42, "hip": 0.99, "withers": 1.0,
    "waist": 0.95, "neck": 0.8, "neck_angle": math.radians(54), "head": 0.16, "snout": 0.42,
    "snout_drop": 0.62, "snout_r": 0.58, "ear": 0.15, "ear_back": 0.05, "leg": 0.078, "thigh": 1.95,
    "hock": 0.42, "thigh_fwd": 0.05, "eye": 0.24, "eye_fwd": 0.32, "belly_line": 0.76,
    "tail": {
        # A short dock hidden in the hair; the locks carry the look.
        "points": lambda L, H, z: [(0, -0.42 * L, z * 0.9), (0, -0.45 * L, z * 0.72), (0, -0.46 * L, z * 0.52)],
        "radii": lambda r: [r * 0.08, r * 0.05, r * 0.03],
    },
}


def mat(name, rgb, rough=0.6, metallic=0.0, emission=None, strength=0.0):
    m = base.material(name, rgb, rough, emission, strength)
    m.node_tree.nodes["Principled BSDF"].inputs["Metallic"].default_value = metallic
    return m


def strand(name, points, radii, material):
    """A tapered, curving lock of hair (or strap) along `points`."""
    obj = base.skin_object(name, [tuple(p) for p in points], [(i, i + 1) for i in range(len(points) - 1)], radii)
    obj.data.materials.append(material)
    return obj


def cylinder(name, a, b, radius, material, verts=6, top=None):
    a, b = Vector(a), Vector(b)
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=radius, radius2=radius if top is None else top,
                                    depth=(b - a).length, location=(a + b) / 2)
    obj = bpy.context.active_object
    obj.name = name
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = Vector((0, 0, 1)).rotation_difference((b - a).normalized())
    obj.data.materials.append(material)
    return obj


def torus(name, center, axis, major, minor, material, seg=12, ring=4):
    bpy.ops.mesh.primitive_torus_add(major_segments=seg, minor_segments=ring, major_radius=major, minor_radius=minor,
                                     location=center)
    obj = bpy.context.active_object
    obj.name = name
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(Vector(axis).normalized())
    obj.data.materials.append(material)
    bpy.ops.object.shade_smooth()
    return obj


def ellipsoid(name, center, scale, material, segments=12):
    obj = base.sphere(name, center, 1.0, material, segments)
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return obj


def decimate(obj, ratio):
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    mod = obj.modifiers.new("Trim", "DECIMATE")
    mod.ratio = ratio
    bpy.ops.object.modifier_apply(modifier="Trim")
    obj.select_set(False)
    return obj


def weight_along(obj, arm, bones):
    """Soft weights to the nearest of `bones` (by distance to each bone's
    segment), blended over the two nearest so hair and reins bend smoothly."""
    segs = []
    for b in bones:
        bb = arm.data.bones[b]
        segs.append((b, Vector(bb.head_local), Vector(bb.tail_local)))
    groups = {b: obj.vertex_groups.new(name=b) for b in bones}
    for v in obj.data.vertices:
        p = obj.matrix_world @ v.co
        ds = []
        for b, h, t in segs:
            ab = t - h
            k = max(0.0, min(1.0, (p - h).dot(ab) / max(ab.length_squared, 1e-6)))
            ds.append(((p - (h + ab * k)).length, b))
        ds.sort()
        (d0, b0), (d1, b1) = ds[0], ds[1] if len(ds) > 1 else (ds[0][0] + 1.0, ds[0][1])
        w0 = 1.0 if d1 - d0 > 0.08 else 0.5 + 0.5 * (d1 - d0) / 0.08
        groups[b0].add([v.index], w0, "REPLACE")
        if w0 < 1.0:
            groups[b1].add([v.index], 1.0 - w0, "REPLACE")


def white_mare():
    base.reset()
    spec = SPEC
    L, H = spec["length"], spec["height"]
    coat = mat("Coat", (0.88, 0.86, 0.87), 0.42)
    belly = mat("Belly", (0.86, 0.83, 0.85), 0.5)
    eye = mat("Eyes", (0.16, 0.08, 0.13), 0.05)
    shine = mat("EyeShine", (0.88, 0.88, 0.88), 0.05)
    hoof = mat("Hoof", (0.84, 0.72, 0.56), 0.4, 0.5)
    nose = mat("Nose", (0.93, 0.74, 0.78), 0.45)
    lash = mat("Lash", (0.30, 0.22, 0.30), 0.6)
    mane_a = mat("ManeBlush", (0.88, 0.62, 0.74), 0.5)
    mane_b = mat("ManeLilac", (0.72, 0.64, 0.88), 0.5)
    mane_c = mat("ManeRose", (0.86, 0.56, 0.70), 0.5)
    gold = mat("Gold", (0.92, 0.74, 0.42), 0.34, 0.85)
    cloth = mat("SaddleCloth", (0.90, 0.58, 0.68), 0.75)
    leather = mat("SaddleSeat", (0.88, 0.80, 0.78), 0.5)
    bloom_rose = mat("BloomRose", (1.0, 0.62, 0.74), 0.55)
    bloom_butter = mat("BloomButter", (1.0, 0.93, 0.62), 0.55)
    bloom_peri = mat("BloomPeri", (0.74, 0.80, 1.0), 0.55)
    leaf = mat("Leaf", (0.62, 0.88, 0.70), 0.6)

    body, g, head, snout = base.quadruped(spec)
    arm = creature_rig.build_armature(g, spec)
    creature_rig.weight_body(body, arm)
    base.assign_regions(body, [coat, belly], H * spec["belly_line"],
                        belly_y=(-0.3 * L, 0.3 * L), belly_x=spec["width"] * 0.22)
    P = lambda n: Vector(g.points[g.names[n]])  # noqa: E731
    parts = [body]
    rigid = []   # (obj, bone)
    soft = []    # (obj, [bones])
    hr = spec["head"]

    # --- face: big glossy eyes with a catch-light and lashes
    for side in (-1, 1):
        ec = head + Vector((side * hr * 0.66, hr * spec["eye_fwd"], hr * 0.28))
        er = hr * spec["eye"]
        parts.append(base.sphere(f"Eye{side}", ec, er, eye, 10))
        rigid.append((parts[-1], "head"))
        parts.append(base.sphere(f"Shine{side}", ec + Vector((side * er * 0.55, er * 0.45, er * 0.4)), er * 0.3, shine, 6))
        rigid.append((parts[-1], "head"))
        for k in range(3):
            root = ec + Vector((side * er * 0.7, er * (0.5 - 0.45 * k), er * 0.75))
            parts.append(base.cone(f"Lash{side}{k}", root, root + Vector((side * er * 0.7, er * 0.25, er * 0.55)), er * 0.12, lash, 4))
            rigid.append((parts[-1], "head"))
    parts.append(base.sphere("Muzzle", snout + Vector((0, 0.03, -0.02)), hr * 0.5, nose, 10))
    rigid.append((parts[-1], "muzzle"))

    # --- hooves (pale gold, glossy)
    for key in ("fl", "hl"):
        for side, tag in ((-1, "l"), (1, "r")):
            paw = P(f"{key}{side}_3")
            parts.append(cylinder(f"Hoof{key}{side}", paw + Vector((0, 0.01, -0.02)), paw + Vector((0, 0.0, 0.09)),
                                  spec["leg"] * 1.2, hoof, 12, top=spec["leg"] * 0.95))
            rigid.append((parts[-1], f"paw_{key}_{tag}"))

    # --- mane: locks along the crest falling to her right, plus a forelock
    sh, nk = P("shoulder"), P("neck")
    mats = [mane_a, mane_b, mane_c]
    n_locks = 11
    for i in range(n_locks):
        t = i / (n_locks - 1)
        r = spec["girth"] * 0.72 * (1 - t) + hr * 0.75 * t  # neck radius here
        crest = sh.lerp(nk, t) + Vector((0, -0.06, r * 0.95))
        fall = 0.5 - 0.15 * t
        pts = [crest + Vector((0.0, 0.0, 0.04)),
               crest + Vector((r * 0.8, -0.04, -fall * 0.3)),
               crest + Vector((r * 1.15, 0.0, -fall * 0.7)),
               crest + Vector((r * 1.05, 0.05, -fall))]
        lock = strand(f"Mane{i}", pts, [(0.085, 0.045), (0.09, 0.045), (0.07, 0.035), (0.016, 0.01)], mats[i % 3])
        parts.append(lock)
        soft.append((lock, ["chest", "neck", "head"]))
    fore = head + Vector((0, -hr * 0.1, hr * 0.85))
    for k, dx in enumerate((-0.04, 0.0, 0.04)):
        lock = strand(f"Forelock{k}", [fore + Vector((dx, 0, 0)), fore + Vector((dx * 1.5, hr * 0.7, -hr * 0.2)),
                                       fore + Vector((dx * 1.8, hr * 1.1, -hr * 0.75))],
                      [(0.04, 0.022), (0.035, 0.02), (0.01, 0.006)], mats[k % 3])
        parts.append(lock)
        rigid.append((lock, "head"))

    # --- tail: long flowing locks from the dock to below the hock
    dock = P("tail0")
    for k in range(5):
        a = (k - 2) * 0.05
        pts = [dock + Vector((a * 0.5, 0.02, 0.02)),
               dock + Vector((a, -0.16, -0.18)),
               dock + Vector((a * 1.3, -0.24, -0.55)),
               dock + Vector((a * 1.5, -0.22, -0.95)),
               dock + Vector((a * 1.2, -0.18, -1.12))]
        lock = strand(f"Tail{k}", pts, [(0.08, 0.08), (0.1, 0.09), (0.095, 0.08), (0.07, 0.055), (0.016, 0.012)], mats[k % 3])
        parts.append(lock)
        soft.append((lock, ["tail0", "tail1", "tail2", "tail3"]))

    # --- tack: rose saddle cloth, pearl seat, gold pommel, cantle and stirrups
    mid, chest = P("mid"), P("chest")
    seat = mid.lerp(chest, 0.45)
    top = seat.z + spec["girth"] * 0.72
    sc = Vector((0, seat.y, top))
    parts.append(ellipsoid("SaddleCloth", sc + Vector((0, 0, -0.06)), (spec["girth"] * 1.12, 0.36, 0.1), cloth, 14))
    rigid.append((parts[-1], "spine"))
    parts.append(torus("ClothTrim", sc + Vector((0, 0, -0.07)), (0, 0, 1), 0.33, 0.018, gold, 16, 4))
    parts[-1].scale = (spec["girth"] * 3.2, 1.05, 1.0)
    bpy.ops.object.select_all(action="DESELECT")
    parts[-1].select_set(True)
    bpy.context.view_layer.objects.active = parts[-1]
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    rigid.append((parts[-1], "spine"))
    parts.append(ellipsoid("Seat", sc + Vector((0, -0.02, 0.03)), (0.19, 0.25, 0.07), leather, 12))
    rigid.append((parts[-1], "spine"))
    parts.append(ellipsoid("Pommel", sc + Vector((0, 0.22, 0.09)), (0.12, 0.05, 0.08), gold, 10))
    rigid.append((parts[-1], "spine"))
    parts.append(ellipsoid("Cantle", sc + Vector((0, -0.24, 0.08)), (0.15, 0.05, 0.07), gold, 10))
    rigid.append((parts[-1], "spine"))
    for side in (-1, 1):
        strap_top = sc + Vector((side * spec["girth"] * 0.95, 0.0, -0.05))
        strap_bot = Vector((side * spec["girth"] * 1.05, seat.y, H * 0.5))
        parts.append(base.cone(f"Leather{side}", strap_bot, strap_top, 0.022, gold, 4))
        rigid.append((parts[-1], "spine"))
        parts.append(torus(f"Stirrup{side}", strap_bot + Vector((0, 0, -0.07)), (0, 1, 0), 0.07, 0.013, gold, 10, 4))
        rigid.append((parts[-1], "spine"))
        # a little gold heart charm on the cloth's corner
        parts.append(base.sphere(f"Charm{side}", sc + Vector((side * spec["girth"] * 1.08, -0.22, -0.16)), 0.035, gold, 8))
        rigid.append((parts[-1], "spine"))

    # --- bridle: noseband, browband, cheek straps, bit rings and reins to the pommel
    snout_c = snout + Vector((0, -0.04, 0.0))
    parts.append(torus("Noseband", snout_c, (0, 1, -0.3), hr * 0.68, 0.014, gold, 12, 4))
    rigid.append((parts[-1], "muzzle"))
    brow = head + Vector((0, hr * 0.1, hr * 0.35))
    parts.append(torus("Browband", brow, (0, 1, 0.5), hr * 1.02, 0.015, gold, 12, 4))
    rigid.append((parts[-1], "head"))
    for side in (-1, 1):
        ring = snout + Vector((side * hr * 0.62, -0.02, -hr * 0.25))
        parts.append(torus(f"Bit{side}", ring, (1, 0, 0), 0.03, 0.009, gold, 8, 4))
        rigid.append((parts[-1], "muzzle"))
        cheek_top = head + Vector((side * hr * 0.95, -hr * 0.2, hr * 0.4))
        parts.append(base.cone(f"Cheek{side}", ring, cheek_top, 0.014, gold, 4))
        rigid.append((parts[-1], "head"))
        hand = sc + Vector((side * 0.1, 0.24, 0.12))
        sag = ring.lerp(hand, 0.45) + Vector((0, 0, -0.12))
        for k, (u, w) in enumerate(((ring, sag), (sag, hand))):
            rein = cylinder(f"Rein{side}{k}", u, w, 0.011, gold)
            parts.append(rein)
            soft.append((rein, ["spine", "chest", "neck", "head"]))

    # --- garland of oversized blooms over the poll
    bloom_mats = [bloom_rose, bloom_butter, bloom_peri, bloom_rose, bloom_peri, bloom_butter, bloom_rose]
    for k, m in enumerate(bloom_mats):
        a = (k / (len(bloom_mats) - 1) - 0.5) * math.radians(150)
        c = brow + Vector((math.sin(a) * hr * 1.05, -0.01, math.cos(a) * hr * 0.55 + hr * 0.12))
        parts.append(base.sphere(f"Bloom{k}", c, 0.034 if k % 2 == 0 else 0.028, m, 8))
        rigid.append((parts[-1], "head"))
        parts.append(base.sphere(f"Heart{k}", c + Vector((0, 0.02, 0.0)), 0.012, bloom_butter, 6))
        rigid.append((parts[-1], "head"))
        if k % 2 == 1:
            parts.append(base.cone(f"Leaf{k}", c, c + Vector((math.sin(a) * 0.05, 0.02, 0.03)), 0.014, leaf, 4))
            rigid.append((parts[-1], "head"))

    # Trim the locks so the whole stays under budget.
    for obj in [p for p in parts if p.name.startswith(("Mane", "Forelock"))]:
        decimate(obj, 0.22)
    for obj in [p for p in parts if p.name.startswith("Tail")]:
        decimate(obj, 0.2)
    if base.tris([body]) > 7000:
        decimate(body, 7000 / base.tris([body]))  # vertex groups survive decimation

    if os.environ.get("MARE_TRIS"):
        for p in sorted(parts, key=lambda o: -base.tris([o]))[:12]:
            print("  ", p.name, base.tris([p]))
    for part, bone in rigid:
        creature_rig.weight_rigid(part, bone)
    for part, bones in soft:
        weight_along(part, arm, bones)
    model = base.join(parts, NAME)
    model.name = NAME
    total = base.tris([model])
    assert total <= TRI_BUDGET, f"white_mare: {total} tris over the {TRI_BUDGET} budget"
    # A horse's gallop reaches further than a wolf's bound: a longer stance
    # sweep and a shorter duty make its native speed about 16 m/s, so the
    # ridden gallop (19 m/s, systems/mount/) plays near 1x with planted hooves.
    wolf_gallop = creature_rig.GAITS["gallop"]
    creature_rig.GAITS["gallop"] = dict(wolf_gallop, T=0.4, duty=0.27, D=1.55, lift=0.15)
    try:
        creature_rig.animate(NAME, model, arm, g, spec, death_breaths=2)
    finally:
        creature_rig.GAITS["gallop"] = wolf_gallop
    base.export(NAME, [model, arm])


if __name__ == "__main__":
    white_mare()
