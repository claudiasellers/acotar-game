"""Straightens the top edge of hunter_boots.glb without rebuilding the body (T057).

The boots' cuff is cut from the body's legs region by a per-face filter, so it was a saw-tooth that
showed as a torn edge over her trousers.  build_feyre.py now cleans it as the shell is made
(shell_from_body rim_z); a full build_feyre run is not reproducible byte for byte, so this applies
the same cure to the hunter_boots already in feyre.blend and re-exports its glb:
    /Applications/Blender.app/Contents/MacOS/Blender -b -P tools/blender/feyre/patch_hunter_boots.py
Prints the spread of the rim's height before and after.  Idempotent: a clean rim stays put.
"""

import os
import sys

import bpy
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import build_feyre as bf  # noqa: E402


def rim_heights(obj, z_min):
    me = obj.data
    use = {}
    for e in me.edges:
        use[e.key] = 0
    for p in me.polygons:
        for k in p.edge_keys:
            use[k] += 1
    ids = sorted({i for k, n in use.items() if n == 1 for i in k})
    z = np.array([me.vertices[i].co.z for i in ids])
    return z[z > z_min]


def main(z_min: float = 0.2) -> None:
    bpy.ops.wm.open_mainfile(filepath=os.path.join(bf.MODEL_DIR, "feyre.blend"))
    body, arm, boots = bpy.data.objects["Body"], bpy.data.objects["Armature"], bpy.data.objects["hunter_boots"]
    base_P = bf.verts_np(body.data)
    before = rim_heights(boots, z_min)
    old = bf.verts_np(boots.data).copy()
    bf.neat_neckline(boots, base_P, body, lambda co: 0.008 + 0.002 * (co.z > 0.2), z_min=z_min, iters=40)
    new = bf.verts_np(boots.data)
    keys = boots.data.shape_keys.key_blocks
    delta = new - old
    for kb in keys:
        if kb.name == "Basis":
            continue
        cur = np.empty(len(old) * 3)
        kb.data.foreach_get("co", cur)
        kb.data.foreach_set("co", (cur.reshape(-1, 3) + delta).ravel())   # the nourished boot rim follows
    after = rim_heights(boots, z_min)
    print("RIM before: n=%d z %.3f..%.3f spread %.1f mm" % (len(before), before.min(), before.max(), 1000 * np.ptp(before)))
    print("RIM after:  n=%d z %.3f..%.3f spread %.1f mm" % (len(after), after.min(), after.max(), 1000 * np.ptp(after)))
    bpy.context.view_layer.update()
    bf.export_glb(os.path.join(bf.WARDROBE_DIR, "hunter_boots.glb"), [boots], arm)


if __name__ == "__main__":
    main()
