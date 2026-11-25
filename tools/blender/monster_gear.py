"""Monster weapons and camp gear (lane L88). Headless Blender, deterministic.
The list, names and looks are L75's: plans/hostile-fae/monster-gear.md.

Run:  /opt/bpyenv/bin/python tools/blender/monster_gear.py [--only id,id] [--family name] [--sheet DIR]
Out:  art/monster_gear/<id>.glb and art/monster_gear/monster_gear_manifest.json

Contract (docs/contracts/monster_gear_models.md). Every file holds the mesh
"<id>" and "<id>_lod1", shaded by PropFinishes like every prop_kit model.

Weapons: the grip's centre is at the origin, the weapon runs up +Y and its
cutting edge or striking face looks down -Z (the bows' axes, so one hand
socket fits both). "<id>_worn" is the same weapon chipped and cracked, shown
below 30% durability. Empties, children of "<id>": "<id>_tip" at the far end
(its distance is the manifest's reach_m) and "<id>_imbue" where a steep's
glow hangs. The same file is the world drop: the manifest's rest_deg and
rest_lift_m lay it on the ground.

Camp gear: base centre at the origin, up +Y, front toward -Z. A container has
an empty "<id>_loot" at its mouth and, if it opens, a mesh "<id>_lid" whose
origin is its hinge.

One module per family (monster_gear_<family>.py; "wilds" holds four small
families and names each item's in FAMILY), each with WEAPONS and CAMP:
id -> builder. A weapon builder is fn(prop, worn) -> meta; a camp builder is
fn(prop) -> meta. meta["parts"] = {suffix: (Prop, origin)} adds child meshes.
"""
import importlib
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import bpy  # noqa: E402,I001
from mathutils import Vector  # noqa: E402
import monster_gear_kit as G  # noqa: E402
import prop_kit as K  # noqa: E402
import upcoming_kit as U  # noqa: E402

OUT = os.path.join(K.ROOT, "art/monster_gear")
Prop = G.Prop
MODULES = ("gloamer", "naga", "briarling", "hob", "wilds", "camp")
WEAPONS, CAMP, FAMILY_OF = {}, {}, {}
for _f in MODULES:
    _m = importlib.import_module("monster_gear_" + _f)
    WEAPONS.update(_m.WEAPONS)
    CAMP.update(_m.CAMP)
    FAMILY_OF.update({k: getattr(_m, "FAMILY", {}).get(k, _f) for k in list(_m.WEAPONS) + list(_m.CAMP)})
ALL = {**WEAPONS, **CAMP}
POINTS = ("tip", "imbue", "loot", "fire", "rest", "cut")


def to_game(v):
    """Blender (x, y, z) -> the game's: glTF is +Y up, and Blender's +Y is the game's -Z."""
    return [round(v[0], 4), round(v[2], 4), round(-v[1], 4)]


def _empty(name, at, parent):
    e = bpy.data.objects.new(name, None)
    e.empty_display_size = 0.03
    e.location = at
    e.parent = parent
    bpy.context.scene.collection.objects.link(e)
    return e


def build(pid, lod=True):
    """-> (objects to export, [meshes that count], lod1 or None, manifest row)."""
    weapon = pid in WEAPONS
    p = Prop(pid)
    meta = ALL[pid](p, False) if weapon else ALL[pid](p)
    ob = p.to_object(pid)
    objs, meshes = [ob], [ob]
    row = dict(id=pid, file=pid + ".glb", group="weapon" if weapon else "camp", family=FAMILY_OF[pid])
    parts = meta.pop("parts", {})
    for key in POINTS:
        if key in meta:
            at = meta.pop(key)
            objs.append(_empty(f"{pid}_{key}", at, ob))
            row[key] = to_game(at)
    for suffix, (pp, origin) in parts.items():
        child = pp.to_object(f"{pid}_{suffix}")
        child.location = origin
        child.parent = ob
        objs.append(child)
        meshes.append(child)
        row[suffix + "_at"] = to_game(origin)
    lo = None
    if lod:
        lo = U.merged_lod(meshes, pid + "_lod1", 0.5 if sum(K.mesh_tris(m) for m in meshes) > 300 else 0.6)
        objs.append(lo)
    if weapon:
        w = Prop(pid + "_worn")
        ALL[pid](w, True)
        wo = w.to_object(pid + "_worn")
        objs.append(wo)
        row["tris_worn"] = K.mesh_tris(wo)
        blo, bhi = p.bounds()
        row["reach_m"] = round(Vector(row["tip"]).length, 3)
        row["length_m"] = round(bhi.z - blo.z, 3)
        # lying on the ground: rolled onto its flat, lifted by half its thickness
        row["rest_deg"] = [0.0, 0.0, 90.0]
        row["rest_lift_m"] = round(max(bhi.x, -blo.x), 3)
    row.update(meta)
    return objs, meshes, lo, row


def sheet(out_dir, only=None):
    """Look sheets, one tile per item: weapons (each beside its worn self) and camp gear."""
    os.makedirs(out_dir, exist_ok=True)
    for name, ids, cols, az, el in (("monster_weapons.png", list(WEAPONS), 4, 62, 8), ("monster_camp_gear.png", list(CAMP), 4, 150, 14)):
        ids = [i for i in ids if not only or i in only]
        if not ids:
            continue
        K.reset()
        tiles = []
        for pid in ids:
            objs, meshes, _, row = build(pid, lod=False)
            keep = list(meshes)
            for o in objs:
                if o.type == "MESH" and o.name.endswith("_worn"):
                    o.location = (-max(0.16, row["length_m"] * 0.3), max(0.08, row["length_m"] * 0.16), 0)
                    keep.append(o)
            tiles.append((keep, az, el))
        U.preview_materials()
        U.studio(ground_z=None if name.startswith("monster_weapons") else 0.0, dark=False)
        U.tile_sheet(tiles, os.path.join(out_dir, name), min(cols, len(ids)))


def main():
    args = sys.argv[1:]
    only = set(args[args.index("--only") + 1].split(",")) if "--only" in args else None
    if "--family" in args:
        fam = args[args.index("--family") + 1]
        only = {k for k, v in FAMILY_OF.items() if v == fam}
    if "--sheet" in args:
        sheet(args[args.index("--sheet") + 1], only)
        return
    rows, over = [], []
    print(f"  {'id':30s} {'lod0':>6s} {'lod1':>6s} {'worn':>6s} {'bytes':>8s} {'albedo':>6s}  size (x, y, z)")
    for pid in ALL:
        if only and pid not in only:
            continue
        K.reset()
        objs, meshes, lo, row = build(pid)
        n0, n1 = sum(K.mesh_tris(m) for m in meshes), K.mesh_tris(lo)
        alb = max(U.max_albedo(m) for m in meshes)
        blo, bhi = U.bounds(meshes)
        path = os.path.join(OUT, pid + ".glb")
        K.export_glb(objs, path)
        nbytes = os.path.getsize(path)
        ext = [round(bhi.x - blo.x, 3), round(bhi.z - blo.z, 3), round(bhi.y - blo.y, 3)]
        print(f"  {pid:30s} {n0:6d} {n1:6d} {row.get('tris_worn', 0):6d} {nbytes:8d} {alb:6.3f}  {ext}")
        rows.append(dict(row, tris=n0, tris_lod1=n1, bytes=nbytes, size_m=ext))
        if max(n0, row.get("tris_worn", 0)) > U.MAX_PROP_TRIS or alb > U.ALBEDO_CAP + 0.005:
            over.append(pid)
    if not only:
        U.write_manifest(os.path.join(OUT, "monster_gear_manifest.json"), rows)
    if over:
        print("OVER BUDGET:", ", ".join(over))
        sys.exit(1)


if __name__ == "__main__":
    main()
