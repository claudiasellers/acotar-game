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
