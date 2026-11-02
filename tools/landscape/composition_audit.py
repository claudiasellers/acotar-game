#!/usr/bin/env python3
"""Composition audit over composition_dump.gd's CSVs (one per region).

  python3 -I tools/landscape/composition_audit.py <dump_dir> [out_dir] [region ...]

Per category (tree, shrub, rock, deadwood, flowers, grass, forage, prop):
  n        instance count
  R        Clark-Evans ratio (mean nearest-neighbour / expected for random):
           1 = random sprinkle, < 1 = gathered, > 1 = evenly spaced
  under / edge / open   share of instances < 5 m / 5-20 m / > 20 m from a tree
           (land share of each band is printed as `land`)
Also writes plan_<region>.png (1 px = 1 m) with every category drawn.
"""
import csv, math, os, sys
import numpy as np
from PIL import Image, ImageDraw

ROCK = ("rock", "boulder", "scree", "pebble", "cairn", "escarpment", "flint", "chalk")
DEAD = ("log", "stump", "deadfall", "leaning_trunk", "snag")
SHRUB = ("shrub:", "bush", "fern", "heather", "hydrangea", "thicket", "brake", "hazel", "bracken", "holly",
         "juniper", "blackthorn", "hawthorn", "briar", "ivy", "reeds", "reed", "cattail")
FLOWER = ("carpet", "snowdrop", "bluebell", "crocus", "foxglove", "iris", "peony", "azalea", "spire", "toadstool")
GRASS = ("grass", "tuft", "snow_mound", "litter")
COLORS = {"tree": (40, 100, 55), "shrub": (110, 170, 100), "rock": (120, 120, 130), "deadwood": (130, 85, 45),
          "flowers": (220, 110, 170), "grass": (200, 215, 170), "forage": (235, 170, 20), "prop": (120, 80, 200),
          "place": (230, 40, 90)}
ORDER = ["grass", "flowers", "shrub", "deadwood", "rock", "prop", "tree", "forage", "place"]


def category(i, tags):
    t = tags.split("|")
    s = i.lower()
    if "tree" in t or s.startswith("tree") or s.startswith("tree:"):
        return "tree"
    if "forage" in t:
        return "forage"
    if "place" in t:
        return "place"
    for k, keys in (("rock", ROCK), ("deadwood", DEAD), ("grass", GRASS), ("flowers", FLOWER), ("shrub", SHRUB)):
        if any(x in s for x in keys):
            if k == "rock" and "mossy_rock" not in s and s.startswith("shrub:") and "boulder" not in s:
                continue
            return k
    return "prop"


def nn_dist(a, b=None, cell=8.0, maxr=60.0):
    """Nearest-neighbour distance from each point of a to set b (a itself if b is None)."""
    same = b is None
    b = a if same else b
    grid = {}
    for k, (x, z) in enumerate(b):
        grid.setdefault((int(x // cell), int(z // cell)), []).append(k)
    out = np.full(len(a), maxr)
    rings = int(math.ceil(maxr / cell))
    for i, (x, z) in enumerate(a):
        cx, cz = int(x // cell), int(z // cell)
        best = maxr * maxr
        for r in range(rings + 1):
            if r > 0 and (r - 1) * cell * (r - 1) * cell > best:
                break
            for dx in range(-r, r + 1):
                for dz in range(-r, r + 1):
                    if max(abs(dx), abs(dz)) != r:
                        continue
                    for j in grid.get((cx + dx, cz + dz), ()):
                        if same and j == i:
                            continue
                        d = (b[j][0] - x) ** 2 + (b[j][1] - z) ** 2
                        if d < best:
                            best = d
        out[i] = math.sqrt(best)
    return out


def load(path):
    rows = list(csv.DictReader(open(path)))
    cats = {}
    for r in rows:
        c = category(r["id"], r["tags"])
        cats.setdefault(c, []).append((float(r["x"]), float(r["z"])))
    return {k: np.array(v) for k, v in cats.items()}


def audit(name, cats, out_dir):
    allp = np.concatenate(list(cats.values()))
    lo, hi = allp.min(0), allp.max(0)
    occ = {(int(x // 25), int(z // 25)) for x, z in allp}
    area = len(occ) * 625.0
    trees = cats.get("tree", np.zeros((0, 2)))
    # land share by distance band (sample a 10 m lattice of occupied cells)
    samp = np.array([(cx * 25 + ox, cz * 25 + oz) for cx, cz in occ for ox in (5, 15) for oz in (5, 15)])
    land = nn_dist(samp, trees) if len(trees) else np.full(len(samp), 99.0)
    bands = lambda d: [(d < 5).mean(), ((d >= 5) & (d < 20)).mean(), (d >= 20).mean()]
    lb = bands(land)
    print(f"== {name}  area {area/1e6:.2f} km2  land under/edge/open {lb[0]:.0%}/{lb[1]:.0%}/{lb[2]:.0%}")
    res = {}
    for c in ORDER:
        p = cats.get(c)
        if p is None or len(p) < 5:
            continue
        sub = p if len(p) <= 12000 else p[np.random.default_rng(1).choice(len(p), 12000, replace=False)]
        d = nn_dist(sub)
        dens = len(p) / area
        exp = 0.5 / math.sqrt(dens * len(sub) / len(p))
        R = d.mean() / exp
        tb = bands(nn_dist(sub, trees)) if len(trees) and c != "tree" else [0, 0, 0]
        res[c] = (len(p), R, tb)
        print(f"   {c:9s} n {len(p):6d}  R {R:4.2f}  under/edge/open {tb[0]:4.0%} {tb[1]:4.0%} {tb[2]:4.0%}")
    if out_dir:
        w, h = int(hi[0] - lo[0]) + 4, int(hi[1] - lo[1]) + 4
        img = Image.new("RGB", (w, h), (238, 242, 228))
        dr = ImageDraw.Draw(img)
        for c in ORDER:
            p = cats.get(c)
            if p is None:
                continue
            r = {"tree": 2.5, "forage": 1.5, "rock": 1.2, "deadwood": 1.2, "shrub": 1.0, "prop": 1.5, "place": 1.2}.get(c, 0.5)
            col = COLORS[c]
            for x, z in p:
                X, Z = x - lo[0] + 2, z - lo[1] + 2
                dr.ellipse((X - r, Z - r, X + r, Z + r), fill=col)
        img.save(os.path.join(out_dir, f"plan_{name}.png"))
    return res


if __name__ == "__main__":
    src = sys.argv[1]
    out = sys.argv[2] if len(sys.argv) > 2 else ""
    only = sys.argv[3:]
    for f in sorted(os.listdir(src)):
        if f.endswith(".csv") and (not only or f[:-4] in only):
            audit(f[:-4], load(os.path.join(src, f)), out)
