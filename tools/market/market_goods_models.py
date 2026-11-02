"""Satchel models for the hides and pelts Feyre sells at market (lane L53),
so the satchel and the sell screen show the real thing, as L50 asked:
    /opt/bpyenv/bin/python tools/market/market_goods_models.py [id ...]
Writes art/forage/<id>.glb (origin at the base centre, about life size, which
SatchelModel finds by item id). Then render their icons with L50's renderer:
    xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver vulkan \
      --audio-driver Dummy --path . -s tools/ui/render_item_icons.gd -- <ids>
"""
import math
import os
import sys

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
sys.path.insert(0, os.path.join(REPO, "tools", "blender", "human_realm"))
import village_lib  # noqa: E402
from village_lib import C, Asset, reset  # noqa: E402

village_lib.OUT_DIR = os.path.join(REPO, "art", "forage")

F = {
    "wolf": (0.52, 0.50, 0.48), "wolf_dk": (0.34, 0.32, 0.31), "wolf_pale": (0.76, 0.73, 0.68),
    "hide": (0.66, 0.50, 0.34), "hide_in": (0.84, 0.74, 0.60), "hare": (0.56, 0.46, 0.36),
    "hare_pale": (0.80, 0.74, 0.64), "twine": (0.62, 0.52, 0.36),
}
MODELS = {}


def model(fn):
    MODELS[fn.__name__] = fn
    return fn


def folded_pelt(a, base, dark, pale, w, d, layers, tail=True):
    """A pelt folded in a soft heap, fur side out: rounded, overlapping lobes,
    a darker saddle along the back and the pale belly fur at the folds."""
    for i in range(layers):
        z = 0.035 + i * 0.05
        a.sphere(0.5, (a.rng.uniform(-0.02, 0.02), a.rng.uniform(-0.02, 0.02), z), base if i % 2 == 0 else dark,
                 scale=((w - i * 0.05), (d - i * 0.03), 0.075), subdiv=2)
        if i == 0:  # the pale belly fur shows only where the bottom fold turns
            a.sphere(0.5, (0.0, -d / 2 + 0.06, z), pale, scale=(w * 0.7, 0.1, 0.05), subdiv=1)
    top = 0.035 + (layers - 1) * 0.05 + 0.035
    a.sphere(0.5, (0.0, 0.03, top), dark, scale=(w * 0.65, d * 0.35, 0.03), subdiv=1)
    for k in range(9):  # tufts of guard hair on top
        a.cyl(0.018, 0.04, (a.rng.uniform(-w * 0.35, w * 0.35), a.rng.uniform(-d * 0.3, d * 0.3), top - 0.01),
              dark if k % 2 else base, rot=(a.rng.uniform(-0.5, 0.5), a.rng.uniform(-0.5, 0.5), 0), segs=4, r2=0.002)
    if tail:
        for k in range(5):
            a.sphere(0.055 - k * 0.006, (w / 2 + k * 0.06, 0.04 + k * 0.035, 0.05), dark if k >= 3 else base,
                     scale=(1.5, 1.0, 0.7), subdiv=1)


@model
def obj_wolf_pelt():
    """The great wolf's pelt: a big grey pelt folded and tied with twine."""
    a = Asset("obj_wolf_pelt", 701)
    folded_pelt(a, F["wolf"], F["wolf_dk"], F["wolf_pale"], 0.62, 0.42, 5)
    for x in (-0.15, 0.15):  # twine lashed round the bundle, not floating above it
        a.box((0.024, 0.32, 0.014), (x, 0, 0.262), F["twine"])
        for y in (-0.16, 0.16):
            a.box((0.024, 0.014, 0.22), (x, y + (0.02 if y > 0 else -0.02), 0.15), F["twine"])
    a.export()


@model
def ing_wolf_pelt():
    a = Asset("ing_wolf_pelt", 702)
    folded_pelt(a, F["wolf"], F["wolf_dk"], F["wolf_pale"], 0.5, 0.34, 4)
    a.export()


@model
def ing_hide():
    """A deer hide, scraped, rolled and tied."""
    a = Asset("ing_hide", 703)
    a.cyl(0.11, 0.5, (-0.25, 0, 0.11), F["hide"], rot=(0, math.pi / 2, 0), segs=12, bevel=0.01)
    a.cyl(0.07, 0.505, (-0.252, 0, 0.11), F["hide_in"], rot=(0, math.pi / 2, 0), segs=10)
    for x in (-0.13, 0.13):
        a.cyl(0.115, 0.025, (x - 0.012, 0, 0.11), F["twine"], rot=(0, math.pi / 2, 0), segs=12)
    a.box((0.22, 0.2, 0.012), (0.08, -0.16, 0.006), F["hide"], rot=(0, 0, 0.3), bevel=0.005)
    a.export()


@model
def ing_hare_pelt():
    a = Asset("ing_hare_pelt", 704)
    folded_pelt(a, F["hare"], F["hare"], F["hare_pale"], 0.3, 0.2, 2, tail=False)
    a.sphere(0.035, (0.17, 0.0, 0.07), F["hare_pale"], subdiv=1)
    a.export()


if __name__ == "__main__":
    names = [n for n in sys.argv[1:] if n in MODELS] or list(MODELS)
    reset()
    for n in names:
        MODELS[n]()
