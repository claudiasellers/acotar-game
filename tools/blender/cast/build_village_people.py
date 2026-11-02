"""The human village's people on the main cast's body (lane L52), built with lane L48's minor-fae
pipeline (build_minor_fae.py) and the designs in cast_village.py.

    /opt/bpyenv/bin/python tools/blender/cast/build_village_people.py <id> [<id> ...]   (ids: cast_village.DESIGNS)
    /opt/bpyenv/bin/python tools/blender/cast/build_village_people.py all

Each id runs in its own process: cast_minor is imported on a placeholder design, cast_village.install()
points it at the village design, then build_minor_fae.py runs unchanged and writes
creatures/models/people/<id>.gltf and data/animation/people/<id>_gaits.txt (same ids, clips and
facing as the old tools/blender/fae_people.py figures, so the CourtNpc scenes need no change).
"""

import os
import re
import runpy
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))


def _all():
    src = open(os.path.join(HERE, "cast_village.py")).read()
    block = src.split("DESIGNS = {", 1)[1].split("\n}\n", 1)[0]
    return re.findall(r'^    "([a-z_0-9]+)": dict\(', block, re.M)


if __name__ == "__main__" and os.environ.get("VILLAGER") is None:
    args = [a for a in sys.argv[1:] if not a.startswith("-")]
    ids = _all() if args == ["all"] else args
    bad = 0
    for i in ids:
        r = subprocess.run([sys.executable, os.path.abspath(__file__)], env=dict(os.environ, VILLAGER=i))
        print("== %s: %s" % (i, "ok" if r.returncode == 0 else "FAILED (%d)" % r.returncode))
        bad += r.returncode != 0
    sys.exit(1 if bad else 0)

VID = os.environ["VILLAGER"]
sys.path.insert(0, HERE)
os.environ["MINOR_FAE"] = "reveler_1"          # any cast_minor design; replaced below
import bpy  # noqa: E402,F401  (brings mathutils)
import cast_minor  # noqa: E402
import cast_village  # noqa: E402

cast_village.install(cast_minor, VID)
os.environ["MINOR_FAE"] = VID
runpy.run_path(os.path.join(HERE, "build_minor_fae.py"), run_name="__main__")


def warm_sclera(path):
    """The eye texture's sclera comes out of the albedo cap as a flat 0.85 grey, which stares white
    in game; take it down to a soft warm ivory (~0.80) and keep the iris as it is."""
    img = bpy.data.images.load(path, check_existing=False)
    w, h = img.size
    import numpy as np
    px = np.array(img.pixels[:], np.float32).reshape(h, w, 4)
    rgb = px[..., :3]
    mx, mn = rgb.max(-1), rgb.min(-1)
    sclera = ((mx - mn) < 0.06) & (mx > 0.55)
    k = np.clip((mx - 0.55) / 0.25, 0, 1)[..., None] * sclera[..., None]
    target = rgb / np.maximum(mx[..., None], 1e-6) * np.array([0.80, 0.765, 0.725], np.float32)
    px[..., :3] = rgb * (1 - k) + target * k
    img.pixels = px.ravel()
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    print("sclera warmed on %d px of %s" % (int(sclera.sum()), os.path.basename(path)))


warm_sclera(os.path.join(HERE, "..", "..", "..", "creatures", "models", "people", VID + "_eye_iris.png"))
