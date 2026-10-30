"""Generates the Manor Estate prop models (headless Blender, deterministic).

Run:  /opt/bpyenv/bin/python tools/blender/manor_props.py [--only id,id] [--preview dir]
Out:  world/spring_court/manor_estate/props/models/<id>.glb
      Nodes "<id>" and "<id>_lod1" (~50% tris), fitted to the
      catalogue size in prop_catalog.gd (w, h, d), base centre at the origin,
      front facing -Z in Godot. Finishes are material names (see prop_kit.py).

Budgets (R4): <= 3,000 tris per prop, LOD1 ~50%. The run fails if one is over.
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import bpy  # noqa: E402,I001
import prop_kit as K  # noqa: E402
import manor_props_a as A  # noqa: E402
import manor_props_b as B  # noqa: E402

OUT = os.path.join(K.ROOT, "world/spring_court/manor_estate/props/models")
MAX_TRIS = 3000
BUILDERS = {**A.BUILDERS, **B.BUILDERS}


def build(pid, entry):
    cat, size, color = entry
    p = K.Prop(pid)
    BUILDERS[pid](p, size, color)
    p.fit(size)
    ob = p.to_object(pid)
    n = K.mesh_tris(ob)
    lo = K.lod(ob, 0.5 if n > 300 else 0.6)
    lo.name = pid + "_lod1"
    return ob, lo


def preview(objs, path, cols=6):
    """Cycles contact sheet of LOD0 models (for review only; not committed)."""
    sc = bpy.context.scene
    cell = 3.2
    for i, ob in enumerate(objs):
        dims = ob.dimensions
        s = 2.2 / max(dims.x, dims.y, dims.z, 0.1)
        ob.scale = (s, s, s)
        ob.location = (-(i % cols) * cell, (i // cols) * cell, 0)
    rows = (len(objs) + cols - 1) // cols
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = max(cols, rows * 1.2) * cell * 1.05
    cx, cy = -(cols - 1) * cell / 2, (rows - 1) * cell / 2
    cam.location = (cx, cy + 20, 16)
    cam.rotation_euler = (math.radians(52), 0, math.radians(180))
    for rot, energy in (((0.8, 0.3, 0.6), 3.5), ((1.2, -0.4, -2.2), 1.2)):
        sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
        sun.data.energy = energy
        sc.collection.objects.link(sun)
        sun.rotation_euler = rot
    sc.world = bpy.data.worlds.new("w")
    if sc.world.node_tree is None:
        sc.world.use_nodes = True
    sc.world.node_tree.nodes["Background"].inputs[0].default_value = (0.75, 0.72, 0.85, 1)
    sc.world.node_tree.nodes["Background"].inputs[1].default_value = 0.8
    sc.render.engine = "CYCLES"
    sc.cycles.samples = 24
    sc.cycles.device = "CPU"
    sc.render.resolution_x = 1500
    sc.render.resolution_y = int(1500 * rows / cols * 1.0)
    sc.view_settings.view_transform = "Standard"
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)


def main():
    args = sys.argv[1:]
    only = None
    prev = None
    if "--only" in args:
        only = set(args[args.index("--only") + 1].split(","))
    if "--preview" in args:
        prev = args[args.index("--preview") + 1]
    cat = K.catalog()
    missing = sorted(set(cat) - set(BUILDERS))
    if missing and only is None:
        print("NO BUILDER:", ", ".join(missing))
    by_cat = {}
    for pid in sorted(cat):
        if pid in BUILDERS and (only is None or pid in only):
            by_cat.setdefault(cat[pid][0], []).append(pid)
    over = []
    total = 0
    for category, ids in sorted(by_cat.items()):
        K.reset()
        objs = []
        for pid in ids:
            ob, lo = build(pid, cat[pid])
            n0, n1 = K.mesh_tris(ob), K.mesh_tris(lo)
            print(f"  {pid:22s} {n0:5d} tris  lod1 {n1:5d} ({n1 / max(n0, 1):.0%})")
            if n0 > MAX_TRIS:
                over.append((pid, n0))
            objs += [ob, lo]
            total += 1
            if not prev:
                K.export_glb([ob, lo], os.path.join(OUT, f"{pid}.glb"))
        if prev:
            for o in objs:
                if o.name.endswith("_lod1"):
                    o.hide_render = True
            preview([o for o in objs if not o.name.endswith("_lod1")], os.path.join(prev, f"{category}.png"))
    print(f"{total} props built; {len(missing)} without builder; over budget: {over}")
    if over:
        sys.exit(1)


if __name__ == "__main__":
    main()
