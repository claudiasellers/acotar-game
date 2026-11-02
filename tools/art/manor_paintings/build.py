#!/usr/bin/env python3
"""Builds the manor's paintings (L39): every work in catalog.WORKS is painted,
packed into one WebP texture array and listed in data/manor_art/manor_art_catalog.tres.

  python3 tools/art/manor_paintings/build.py            # everything
  python3 tools/art/manor_paintings/build.py --only portrait_03,still_07 --contact /tmp/c.png
  python3 tools/art/manor_paintings/build.py --no-blender   # reuse cached renders only

Steps:
 1. Blender references: sitters (the game's own cast bodies, re-dressed) and
    tableaux (creatures/models/*.gltf) via tools/blender/manor_art_refs.py,
    headless Cycles through /opt/bpyenv/bin/python (R4), two processes.
 2. Each work: a reference picture is drawn (scenes_*.py), any render is
    composited into it, then painter.paint lays oil strokes over it and
    painter.finish adds varnish, age and the albedo cap (whites <= 0.85).
 3. Packing: every work that can hang is shelf-packed into the 2048 x 2040
    layers of one texture array (art/house/paintings/paintings.webp, two
    layers across, row by row), with 8 px edge-extended gutters. One array
    means one canvas material, so a room's canvases merge into one draw.
 4. data/manor_art/manor_art_catalog.tres (read by ManorArtHanger) and a
    keeper's review list in the project's plans folder when it is mounted.

Renders and paintings are cached outside the repo (MANOR_ART_CACHE, default
~/.cache/acotar/manor_art), keyed by a hash of the recipe and the code, so a
rebuild repaints only what changed. Every image here is generated for this
game; nothing is copied from an existing artwork (director's condition 1).
Deterministic: every random choice is seeded from the catalog.
"""

import argparse
import hashlib
import json
import os
import random
import re
import subprocess
import sys
import time
from multiprocessing import Pool

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, HERE)

import numpy as np  # noqa: E402
from PIL import Image, ImageDraw, ImageFilter  # noqa: E402

import catalog  # noqa: E402
import painter  # noqa: E402
import scenes_land as L  # noqa: E402
import scenes_misc as X  # noqa: E402
import scenes_portrait as P  # noqa: E402
import scenes_still as S  # noqa: E402

CACHE = os.environ.get("MANOR_ART_CACHE", os.path.expanduser("~/.cache/acotar/manor_art"))
BLENDER_PY = "/opt/bpyenv/bin/python"
REFS_SCRIPT = os.path.join(ROOT, "tools", "blender", "manor_art_refs.py")
OUT_DIR = os.path.join(ROOT, "art", "house", "paintings")
RES_DIR = "res://art/house/paintings"
TRES = os.path.join(ROOT, "data", "manor_art", "manor_art_catalog.tres")
REVIEW = "/mnt/project-files/plans/manor-art/catalog.md"
SHEET = 2048
GUTTER = 8
QUALITY = int(os.environ.get("MANOR_ART_QUALITY", "90"))
SOURCE = "generated for this game by tools/art/manor_paintings (L39)"
LICENCE = "original work made for this game"

# canvas pixels per format; "major" works hang in the 2.6 m frames
SIZES = {
    "land": (512, 360), "port": (384, 512), "square": (448, 448), "round": (448, 448),
    "oval_p": (384, 480), "oval_l": (480, 384), "arch_p": (384, 512),
}
MAJOR = {"land": (1008, 708), "port": (512, 768), "oval_l": (768, 614)}

# Room themes, in order of preference: which works a room hangs (catalog
# "rooms" keys). ManorArtHanger falls back to name patterns for rooms that
# are not listed (ROOM_PATTERNS), so new rooms from the refurnish lane work.
ROOM_THEMES = {
    "entrance_hall": ["hall", "gallery"],
    "garden_saloon": ["hall", "dining", "nursery"],
    "hidden_nook": ["library", "study"],
    "west_corridor@0": ["portrait", "mask", "corridor"],
    "map_stairwell": ["map", "library", "store"],
    "drawing_room": ["hall", "music", "bedroom"],
    "east_corridor@0": ["corridor", "hall", "portrait"],
    "music_room": ["music", "ballroom"],
    "ballroom": ["ballroom", "music"],
    "morning_room": ["nursery", "bedroom", "hall"],
    "gallery": ["gallery"],
    "dining_hall": ["dining", "hall"],
    "rose_corridor": ["corridor", "bedroom", "hall"],
    "card_room": ["mask", "music", "bedroom"],
    "mask_vault": ["mask", "portrait_dim"],
    "painting_store": ["store", "portrait_dim", "library"],
    "library": ["library", "study", "map"],
    "tamlin_study": ["study", "map", "library"],
    "study": ["study", "map", "library"],
    "svc_alis_room": ["alis", "service"],
    "svc_housekeeper": ["service", "stillroom"],
    "svc_attic_playroom": ["nursery", "service"],
    "svc_maid_bedroom_a": ["service", "bedroom"],
    "svc_stillroom": ["stillroom", "service"],
    "svc_kitchen": ["kitchen", "service"],
    "upper_hall": ["hall", "gallery"],
    "east_corridor@1": ["corridor", "bedroom", "hall"],
    "west_corridor@1": ["corridor", "portrait", "hall"],
    "attic_stair_hall": ["store", "service"],
    "feyre_bedroom": ["bedroom", "nursery"],
    "painting_room": ["gallery", "bedroom"],
    "portrait_gallery": ["portrait_full", "portrait"],
    "guest_suite_periwinkle": ["night", "bedroom"],
    "guest_suite_lilac": ["bedroom", "music"],
    "guest_suite_wisteria": ["autumn", "bedroom"],
    "rose_parlour": ["bedroom", "music", "hall"],
    "west_wing_hall": ["hall", "gallery", "corridor"],
    "attic_long_hall": ["store", "corridor"],
    "attic_painting_loft": ["store_secret", "store", "portrait_dim"],
    "moon_tower_hidden": ["night", "library"],
    "moon_tower": ["night", "portrait"],
}
ROOM_PATTERNS = [
    ("library", ["library", "study"]), ("study", ["study", "map"]), ("kitchen", ["kitchen", "service"]),
    ("still", ["stillroom", "service"]), ("svc_", ["service", "stillroom"]), ("nursery", ["nursery", "bedroom"]),
    ("bed", ["bedroom", "nursery"]), ("suite", ["bedroom", "night"]), ("dining", ["dining", "hall"]),
    ("music", ["music", "ballroom"]), ("ball", ["ballroom", "music"]), ("mask", ["mask", "portrait"]),
    ("portrait", ["portrait", "portrait_full"]), ("attic", ["store", "service"]), ("store", ["store"]),
    ("corridor", ["corridor", "hall"]), ("hall", ["hall", "gallery"]), ("", ["hall", "bedroom", "gallery"]),
]

CODE_FILES = ["painter.py", "motifs.py", "scenes_land.py", "scenes_still.py", "scenes_portrait.py", "scenes_misc.py", "build.py"]


def _h(obj):
    return hashlib.sha1(json.dumps(obj, sort_keys=True, default=str).encode()).hexdigest()[:12]


def _code_hash(files):
    h = hashlib.sha1()
    for f in files:
        h.update(open(f, "rb").read())
    return h.hexdigest()[:10]


def size_of(e):
    if e["major"] and e["fmt"] in MAJOR:
        return MAJOR[e["fmt"]]
    return SIZES[e["fmt"]]


# ------------------------------------------------------------------ Blender references

def ref_jobs(e):
    """The Blender renders a work needs: [(key, job)]."""
    w, h = size_of(e)
    out = []
    if "sitter" in e:
        out.append(dict(kind="sitter", w=w, h=h, **e["sitter"]))
    if "pair" in e:
        pw = int(w * 0.58)
        for s in e["pair"]:
            out.append(dict(kind="sitter", w=pw, h=h, **s))
    if "tableau" in e:
        out.append(dict(kind="tableau", w=w, h=h, **e["tableau"]))
    code = _code_hash([REFS_SCRIPT])
    return [(_h([j, code]), j) for j in out]


def ref_path(key):
    return os.path.join(CACHE, "refs", key + ".png")


def run_blender(works, procs=2):
    need = []
    for e in works:
        for key, job in ref_jobs(e):
            if not os.path.exists(ref_path(key)):
                j = dict(job)
                j["out"] = ref_path(key)
                need.append(j)
    if not need:
        return
    os.makedirs(os.path.join(CACHE, "refs"), exist_ok=True)
    if not os.path.exists(BLENDER_PY):
        sys.exit("manor art: %d renders missing and no Blender at %s" % (len(need), BLENDER_PY))
    print("blender: %d renders in %d processes" % (len(need), procs), flush=True)
    t = time.time()
    running = []
    for i in range(procs):
        part = need[i::procs]
        if not part:
            continue
        jf = os.path.join(CACHE, "refs", "jobs_%d.json" % i)
        json.dump(part, open(jf, "w"))
        log = open(os.path.join(CACHE, "refs", "blender_%d.log" % i), "w")
        running.append((subprocess.Popen([BLENDER_PY, REFS_SCRIPT, "--", jf], stdout=log, stderr=subprocess.STDOUT, cwd=ROOT), log))
    for p, log in running:
        p.wait()
        log.close()
    missing = [j["out"] for j in need if not os.path.exists(j["out"])]
    if missing:
        sys.exit("manor art: Blender did not write %d renders (see %s/refs/blender_*.log)" % (len(missing), CACHE))
    print("blender: done in %.0f s" % (time.time() - t), flush=True)


def _fit(rgb, a, box):
    """Scale and move a tableau render so its subjects' bounding box sits in
    box = (centre u, bottom v, max width, max height) of the canvas: the
    creatures stand in the near meadow, not on the horizon."""
    h, w = a.shape
    ys, xs = np.nonzero(a > 0.35)
    if len(xs) == 0:
        return rgb, a
    x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
    cu, bv, mw, mh = box
    s = min(mw * w / (x1 - x0), mh * h / (y1 - y0))
    rgba = np.dstack([rgb, a])
    im = Image.fromarray((np.clip(rgba, 0, 1) * 255).astype(np.uint8), "RGBA")
    nw, nh = max(1, int(w * s)), max(1, int(h * s))
    im = im.resize((nw, nh), Image.LANCZOS)
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ox = int(cu * w - (x0 + x1) / 2 * s)
    oy = int(bv * h - y1 * s)
    out.paste(im, (ox, oy))
    o = np.asarray(out, np.float32) / 255.0
    return o[..., :3], o[..., 3]


def _rgba(path, w, h):
    im = Image.open(path).convert("RGBA")
    if im.size != (w, h):
        im = im.resize((w, h), Image.LANCZOS)
    a = np.asarray(im, np.float32) / 255.0
    return a[..., :3], a[..., 3]


# ------------------------------------------------------------------ painting one work

FACE_V = {"bust": 0.56, "half": 0.36, "full": 0.2}


def _floor_band(r, q):
    """The floor a full-length sitter stands on (a grand setting has its own)."""
    if q.get("back") in P.SETTINGS:
        return
    if q.get("back") == "garden":
        import motifs as M
        M.meadow(r, 0.84, "spring", "golden", q["seed"], 0.5)
    else:
        base = P.BACKS.get(q.get("back", "umber"), P.BACKS["umber"])[1][1]
        r.vgrad([(0, painter.shade(painter.C(base), -0.05)), (1, painter.shade(painter.C(base), -0.3))], 0.86, 1.0,
                mask=(r.v > 0.86).astype(np.float32))


def _oil_sitter(rgb, alpha):
    """Take the render's CG look off a full-length sitter before the brush
    does (audit A5): simplified forms, shadows glazed warm, highlights held
    down, a softened silhouette."""
    img = Image.fromarray(np.clip(rgb * 255, 0, 255).astype(np.uint8), "RGB").filter(ImageFilter.MedianFilter(3))
    out = np.asarray(img, np.float32) / 255.0
    lum = (out @ np.array([0.3, 0.59, 0.11], np.float32))[..., None]
    glaze = np.array([0.42, 0.26, 0.2], np.float32)
    out = out * (0.86 + 0.1 * lum) + glaze * (1 - lum) * 0.14
    a = Image.fromarray(np.clip(alpha * 255, 0, 255).astype(np.uint8), "L").filter(ImageFilter.GaussianBlur(1.6))
    return np.clip(out, 0, 1), np.asarray(a, np.float32) / 255.0


def _cast_shadow(r, alpha):
    """A soft shadow pooled at the sitter's feet, falling right (light from the left)."""
    rows = np.nonzero(alpha.max(axis=1) > 0.5)[0]
    cols = np.nonzero(alpha.max(axis=0) > 0.5)[0]
    if len(rows) == 0:
        return
    fy = rows.max() / r.h
    cx = (cols.min() + cols.max()) / 2 / r.w
    sh = r.ellipse(cx + 0.08, min(0.98, fy), 0.2, 0.025, blur=10.0)
    r.put("#291c1a", sh, alpha=0.45)


def _stand_back(rgb, alpha, stand):
    """Shrink a full-length sitter so the setting shows round them (audit A5):
    stand = (centre x, height) in canvas fractions, feet near the bottom."""
    h, w = alpha.shape
    cx, k = stand
    sw, sh = max(1, int(w * k)), max(1, int(h * k))
    small = np.asarray(Image.fromarray(np.clip(rgb * 255, 0, 255).astype(np.uint8)).resize((sw, sh), Image.LANCZOS), np.float32) / 255.0
    sa = np.asarray(Image.fromarray(np.clip(alpha * 255, 0, 255).astype(np.uint8)).resize((sw, sh), Image.LANCZOS), np.float32) / 255.0
    out = np.zeros_like(rgb)
    oa = np.zeros_like(alpha)
    x0 = int(w * cx - sw / 2)
    y0 = h - sh - int(h * 0.025)
    xa, xb = max(0, x0), min(w, x0 + sw)
    out[y0:y0 + sh, xa:xb] = small[:, xa - x0:xb - x0]
    oa[y0:y0 + sh, xa:xb] = sa[:, xa - x0:xb - x0]
    return out, oa, y0 / h + FACE_V["full"] * k


def _sitter_into(r, rgb, alpha, x0, frame, k=1.0, face_v=None):
    """Composite a sitter render (its own width) at pixel column x0."""
    if frame == "full":
        rgb, alpha = _oil_sitter(rgb, alpha)
        _cast_shadow(r, alpha)
    hh, ww = alpha.shape
    big_rgb = np.zeros((r.h, r.w, 3), np.float32)
    big_a = np.zeros((r.h, r.w), np.float32)
    xa, xb = max(0, x0), min(r.w, x0 + ww)
    big_rgb[:, xa:xb] = rgb[:, xa - x0:xb - x0]
    big_a[:, xa:xb] = alpha[:, xa - x0:xb - x0] * k
    r.put(big_rgb, big_a)
    face = big_a * (r.v < (face_v if face_v is not None else FACE_V.get(frame, 0.5)))
    r.mark_detail(face, 0.9 if frame == "full" else 0.6)


def reference(e):
    """Draw a work's reference picture (float RGB) and its detail mask."""
    w, h = size_of(e)
    p = dict(e)
    r = painter.Ref(w, h, random.Random(e["seed"]))
    g = e["genre"]
    renders = [ref_path(k) for k, _ in ref_jobs(e)]
    if g in ("landscape", "animal"):
        if "tableau" in e:
            rgb, a = _rgba(renders[0], w, h)
            rgb, a = _fit(rgb, a, e["tableau"].get("fit", (0.5, 0.93, 0.8, 0.5)))

            def overlay(rr, rgb=rgb, a=a):
                rr.put(rgb, a)
                rr.mark_detail(np.clip(a * 1.4, 0, 1), 0.55)
            p["_overlay"] = overlay
        L.landscape(r, p)
    elif g == "still":
        S.still_life(r, p)
    elif g == "portrait":
        rng = random.Random(e["seed"])
        P._backdrop(r, p, rng)
        if "sitter" in e:
            frame = e["sitter"].get("frame", "bust")
            if frame == "full":
                _floor_band(r, p)
            rgb, a = _rgba(renders[0], w, h)
            face_v = None
            if frame == "full":
                rgb, a, face_v = _stand_back(rgb, a, e.get("stand", (0.5, 0.8)))
            _sitter_into(r, rgb, a, 0, frame, face_v=face_v)
        else:
            pw = int(w * 0.58)
            for i, path in enumerate(renders):
                rgb, a = _rgba(path, pw, h)
                _sitter_into(r, rgb, a, 0 if i == 0 else w - pw, "bust")
    elif g == "plate":
        X.plate(r, p)
    elif g == "botanical":
        X.botanical(r, p)
    elif g == "map":
        X.court_map(r, p)
    elif g == "cauldron":
        X.cauldron(r, p)
    elif g == "interior":
        X.interior(r, p)
    else:
        raise ValueError("unknown genre %s" % g)
    return r


# brush settings per family
PAINT = {
    "portrait": dict(crisp=0.2),
    "full": dict(scales=(0.05, 0.026, 0.014, 0.008), threshold=0.085, bristle=0.7, crisp=0.08, value_jitter=0.04),
    "still": dict(crisp=0.2),
    "print": dict(scales=(0.03, 0.015, 0.008, 0.005), crisp=0.5, bristle=0.25, value_jitter=0.015),
    "default": dict(),
}
FINISH = {
    "portrait": dict(varnish=0.35, vignette=0.45, contrast=0.12, saturate=0.05),
    "full": dict(varnish=0.5, vignette=0.5, contrast=0.2, saturate=0.12),
    "still": dict(varnish=0.35, vignette=0.4, contrast=0.12, saturate=0.08),
    "print": dict(varnish=0.08, vignette=0.0),
    "default": dict(varnish=0.3, vignette=0.22, contrast=0.22, saturate=0.12),
}


def _family(e):
    g = e["genre"]
    if g in ("plate", "botanical", "map"):
        return "print"
    if g == "portrait" and e.get("sitter", {}).get("frame") == "full":
        return "full"
    if g in ("portrait", "still"):
        return g
    return "default"


# Bump when reference()/paint_one() change how a family is composited.
RECIPE_VERSION = {"portrait": 4, "landscape": 2, "animal": 2, "still": 1, "plate": 1, "botanical": 2,
                  "map": 1, "cauldron": 2, "interior": 1}
GENRE_FILES = {"landscape": "scenes_land.py", "animal": "scenes_land.py", "still": "scenes_still.py",
               "portrait": "scenes_portrait.py", "plate": "scenes_misc.py", "botanical": "scenes_misc.py",
               "map": "scenes_misc.py", "cauldron": "scenes_misc.py", "interior": "scenes_misc.py"}


def painted_key(e, code):
    """Cache key: the recipe, the brush code and the genre's own scene file, so
    a change to one genre repaints only that genre."""
    rec = {k: v for k, v in e.items() if k not in ("title", "ref", "rooms", "canon", "pin", "reserve")}
    files = ["painter.py", "motifs.py", GENRE_FILES[e["genre"]]] + (["scenes_land.py"] if e["genre"] == "portrait" else [])
    gcode = _code_hash([os.path.join(HERE, f) for f in files])
    return "%s-%s" % (e["id"], _h([rec, gcode, RECIPE_VERSION[e["genre"]], size_of(e)]))


def paint_one(args):
    e, code = args
    out = os.path.join(CACHE, "painted", painted_key(e, code) + ".png")
    if os.path.exists(out):
        return e["id"], out, 0.0
    t = time.time()
    r = reference(e)
    ref = np.clip(r.rgb, 0, 1)
    if e.get("eye") == "fae" and e["genre"] not in ("plate", "botanical", "map"):
        ref = painter.bend(ref, e["seed"], 0.006 if e["genre"] == "portrait" else 0.012)
    fam = _family(e)
    img = painter.paint(ref, random.Random(e["seed"]), detail=r.detail, flow_seed=e["seed"], **PAINT[fam])
    fin = dict(FINISH[fam])
    img = painter.finish(img, random.Random(e["seed"] + 1), age=e.get("age", 0.0), **fin)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    painter.to_image(img).save(out + ".tmp.png")
    os.replace(out + ".tmp.png", out)
    return e["id"], out, time.time() - t


# ------------------------------------------------------------------ packing

LAYER_W, LAYER_H = SHEET, 2040   # one layer of the canvas array; 8 rows stay under WebP's 16383 px
COLS, MAX_ROWS = 2, 8
ARRAY_NAME = "paintings.webp"


def pack(works, images):
    """Shelf-pack every work that can hang into the layers of one texture
    array, tallest first, so all the manor's canvases share one material.
    Held-back works are not packed. Returns [[(id, x, y, w, h)], ...]."""
    items = sorted((e for e in works if not e.get("reserve")),
                   key=lambda e: (-images[e["id"]].size[1], -images[e["id"]].size[0], e["id"]))
    layers, shelves = [], []   # shelves[i]: [[y, h, x], ...] of layer i
    for e in items:
        iw, ih = images[e["id"]].size
        spot = None
        for li, sh in enumerate(shelves):   # first fit: an open shelf, else a new shelf below
            for s in sh:
                if ih <= s[1] and s[2] + iw + GUTTER <= LAYER_W:
                    spot = (li, s)
                    break
            if spot is None:
                y = sh[-1][0] + sh[-1][1] + GUTTER
                if y + ih + GUTTER <= LAYER_H:
                    sh.append([y, ih, GUTTER])
                    spot = (li, sh[-1])
            if spot:
                break
        if spot is None:
            layers.append([])
            shelves.append([[GUTTER, ih, GUTTER]])
            spot = (len(layers) - 1, shelves[-1][0])
        li, s = spot
        layers[li].append((e["id"], s[2], s[0], iw, ih))
        s[2] += iw + GUTTER
    assert len(layers) <= COLS * MAX_ROWS, "%d layers; the array holds %d" % (len(layers), COLS * MAX_ROWS)
    return layers


def _extend(sheet, x, y, w, h):
    """Copy a cell's edge pixels into its gutter so mipmaps don't bleed."""
    a = np.asarray(sheet)
    g = GUTTER
    x0, y0, x1, y1 = max(0, x - g), max(0, y - g), min(a.shape[1], x + w + g), min(a.shape[0], y + h + g)
    a = a.copy()
    a[y0:y, x:x + w] = a[y:y + 1, x:x + w]
    a[y + h:y1, x:x + w] = a[y + h - 1:y + h, x:x + w]
    a[y0:y1, x0:x] = a[y0:y1, x:x + 1]
    a[y0:y1, x + w:x1] = a[y0:y1, x + w - 1:x + w]
    return Image.fromarray(a)


def write_sheets(layers, images):
    """One WebP holding every layer, COLS across, row by row (Godot's slice
    order), imported as a Texture2DArray. Returns {id: (layer, uv, px)}."""
    os.makedirs(OUT_DIR, exist_ok=True)
    for f in os.listdir(OUT_DIR):
        if f.startswith("paintings_") and (f.endswith(".webp") or f.endswith(".webp.import")):
            os.remove(os.path.join(OUT_DIR, f))  # the per-family sheets this replaced
    rows = (len(layers) + COLS - 1) // COLS
    big = Image.new("RGB", (COLS * LAYER_W, rows * LAYER_H), (60, 48, 44))
    cells = {}
    for li, items in enumerate(layers):
        layer = Image.new("RGB", (LAYER_W, LAYER_H), (60, 48, 44))
        for wid, x, y, w, h in items:
            layer.paste(images[wid], (x, y))
        for wid, x, y, w, h in items:
            layer = _extend(layer, x, y, w, h)
            cells[wid] = (li, (x / LAYER_W, y / LAYER_H, w / LAYER_W, h / LAYER_H), (w, h))
        big.paste(layer, ((li % COLS) * LAYER_W, (li // COLS) * LAYER_H))
        print("layer %2d %3d works" % (li, len(items)))
    path = os.path.join(OUT_DIR, ARRAY_NAME)
    big.save(path, "WEBP", quality=QUALITY, method=6)
    print("array %s %dx%d, %d layers of %dx%d, %.2f MB" % (ARRAY_NAME, big.width, big.height, len(layers),
                                                           LAYER_W, LAYER_H, os.path.getsize(path) / 1e6))
    _import_settings(path, rows)
    return cells


def patch_array(works, images):
    """Paste repainted works into their existing cells of the committed array,
    so a fix to a few works needs neither the others' cache nor a repack."""
    cat = open(TRES).read()
    Image.MAX_IMAGE_PIXELS = None
    path = os.path.join(OUT_DIR, ARRAY_NAME)
    big = Image.open(path).convert("RGB")
    for e in works:
        blk = cat[cat.index('id = &%s' % _q(e["id"])):]
        blk = blk[:blk.index("[sub_resource") if "[sub_resource" in blk else len(blk)]
        layer = int(re.search(r"layer = (-?\d+)", blk).group(1))
        uv = [float(x) for x in re.search(r"uv = Rect2\(([^)]*)\)", blk).group(1).split(",")]
        px = tuple(int(x) for x in re.search(r"pixels = Vector2i\(([^)]*)\)", blk).group(1).split(","))
        assert layer >= 0, "%s is held back: it has no cell" % e["id"]
        assert images[e["id"]].size == px, "%s changed size %s -> %s: run a full build" % (e["id"], px, images[e["id"]].size)
        lx, ly = (layer % COLS) * LAYER_W, (layer // COLS) * LAYER_H
        x, y = round(uv[0] * LAYER_W), round(uv[1] * LAYER_H)
        lay = big.crop((lx, ly, lx + LAYER_W, ly + LAYER_H))
        lay.paste(images[e["id"]], (x, y))
        lay = _extend(lay, x, y, px[0], px[1])
        big.paste(lay, (lx, ly))
        print("patched %s into layer %d at %d,%d" % (e["id"], layer, x, y))
    big.save(path, "WEBP", quality=QUALITY, method=6)
    print("array %s %.2f MB" % (ARRAY_NAME, os.path.getsize(path) / 1e6))


IMPORT = """[remap]

importer="2d_array_texture"
type="CompressedTexture2DArray"

[params]

compress/mode=2
compress/high_quality=false
compress/lossy_quality=0.7
compress/hdr_compression=1
compress/channel_pack=0
mipmaps/generate=true
mipmaps/limit=-1
slices/horizontal=%d
slices/vertical=%d
"""


def _import_settings(path, rows):
    """A VRAM-compressed, mipmapped texture array (R15), COLS x rows slices.
    An existing .import keeps its uid; only the slice count is updated."""
    imp = path + ".import"
    if not os.path.exists(imp):
        open(imp, "w").write(IMPORT % (COLS, rows))
        return
    s = open(imp).read()
    s = re.sub(r"slices/horizontal=\d+", "slices/horizontal=%d" % COLS, s)
    s = re.sub(r"slices/vertical=\d+", "slices/vertical=%d" % rows, s)
    open(imp, "w").write(s)


# ------------------------------------------------------------------ catalog resource

def _q(s):
    return '"' + str(s).replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'


def _psa(xs):
    return "PackedStringArray(" + ", ".join(_q(x) for x in xs) + ")"


def write_tres(works, cells):
    lines = ['[gd_resource type="Resource" script_class="ManorArtCatalog" format=3]', "",
             '[ext_resource type="Script" path="res://world/spring_court/manor_estate/art/manor_art_work.gd" id="1_work"]',
             '[ext_resource type="Script" path="res://world/spring_court/manor_estate/art/manor_art_catalog.gd" id="2_cat"]', ""]
    ids = []
    for i, e in enumerate(works):
        layer, uv, px = cells.get(e["id"], (-1, (0.0, 0.0, 0.0, 0.0), (0, 0)))
        sid = "w%03d" % i
        ids.append(sid)
        lines += ['[sub_resource type="Resource" id="%s"]' % sid, 'script = ExtResource("1_work")',
                  "id = &%s" % _q(e["id"]), "title = %s" % _q(e["title"]), "genre = &%s" % _q(e["genre"]),
                  "fmt = &%s" % _q(e["fmt"]), "major = %s" % ("true" if e["major"] else "false"),
                  "canon = %s" % _q(e["canon"]), "story_ref = %s" % _q(e["ref"]), "themes = %s" % _psa(e["rooms"]),
                  "pin = &%s" % _q(e["pin"]), "reserve = %s" % ("true" if e.get("reserve") else "false"), "sheet = %s" % _q(RES_DIR + "/" + ARRAY_NAME if layer >= 0 else ""), "layer = %d" % layer,
                  "uv = Rect2(%.7f, %.7f, %.7f, %.7f)" % uv, "pixels = Vector2i(%d, %d)" % px,
                  "source = %s" % _q(SOURCE), "licence = %s" % _q(LICENCE), ""]
    themes = ", ".join("%s: %s" % (_q(k), _psa(v)) for k, v in sorted(ROOM_THEMES.items()))
    pats = ", ".join("%s, %s" % (_q(k), _psa(v)) for k, v in ROOM_PATTERNS)
    lines += ["[resource]", 'script = ExtResource("2_cat")',
              "; every work that can hang in the manor; built by tools/art/manor_paintings/build.py, do not hand-edit",
              "works = Array[ExtResource(\"1_work\")]([%s])" % ", ".join('SubResource("%s")' % s for s in ids),
              "room_themes = {%s}" % themes,
              "room_patterns = Array[PackedStringArray]([%s])" % ", ".join(
                  "PackedStringArray(%s)" % ", ".join([_q(k)] + [_q(x) for x in v]) for k, v in ROOM_PATTERNS), ""]
    os.makedirs(os.path.dirname(TRES), exist_ok=True)
    open(TRES, "w").write("\n".join(lines))
    print("wrote", os.path.relpath(TRES, ROOT))


def write_review(works):
    if not os.path.isdir("/mnt/project-files/plans"):
        return
    os.makedirs(os.path.dirname(REVIEW), exist_ok=True)
    out = ["# The manor's paintings: list for the Keeper (L39)", "",
           "Every work that can hang in the manor house. Each hangs at most once. Canon: C book, C? map lore, X invented.",
           "Built from tools/art/manor_paintings/catalog.py; the in-game plaque is illegible (Feyre can't read).", "",
           "| # | id | title | canon | hangs in | story link |", "|---|---|---|---|---|---|"]
    for i, e in enumerate(works):
        where = ", ".join(e["rooms"]) + (" (pinned: %s)" % e["pin"].replace("|", " or ") if e["pin"] else "") + (" (held back)" if e.get("reserve") else "")
        out.append("| %d | %s | %s | %s | %s | %s |" % (i + 1, e["id"], e["title"], e["canon"], where, e["ref"].replace("|", "/")))
    open(REVIEW, "w").write("\n".join(out) + "\n")
    print("wrote", REVIEW)


# ------------------------------------------------------------------ contact sheet

def contact(works, images, path, cols=6, cell=300):
    rows = (len(works) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * cell, rows * (cell + 16)), (30, 26, 28))
    d = ImageDraw.Draw(sheet)
    for i, e in enumerate(works):
        im = images[e["id"]].copy()
        im.thumbnail((cell - 8, cell - 8))
        x, y = (i % cols) * cell, (i // cols) * (cell + 16)
        sheet.paste(im, (x + (cell - im.width) // 2, y + (cell - im.height) // 2))
        d.text((x + 4, y + cell), e["id"], fill=(230, 220, 220))
    sheet.save(path)
    print("contact", path)


# ------------------------------------------------------------------ main

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="", help="comma-separated ids: paint these only, no sheets")
    ap.add_argument("--contact", default="", help="write a contact sheet PNG")
    ap.add_argument("--jobs", type=int, default=max(1, (os.cpu_count() or 4)))
    ap.add_argument("--no-blender", action="store_true")
    ap.add_argument("--no-sheets", action="store_true")
    ap.add_argument("--patch", action="store_true",
                    help="with --only: repaint those works into their cells of the committed array (same sizes), leaving the rest as they are")
    a = ap.parse_args()
    works = catalog.WORKS
    ids = [e["id"] for e in works]
    assert len(ids) == len(set(ids)), "duplicate work ids"
    assert len({e["title"] for e in works}) == len(works), "duplicate titles"
    if a.only:
        want = set(a.only.split(","))
        works = [e for e in works if e["id"] in want]
    if not a.no_blender:
        run_blender(works)
    code = _code_hash([os.path.join(HERE, f) for f in CODE_FILES if f != "build.py"])
    t = time.time()
    images = {}
    with Pool(a.jobs) as pool:
        for wid, path, dt in pool.imap_unordered(paint_one, [(e, code) for e in works]):
            images[wid] = Image.open(path).convert("RGB")
            if dt:
                print("painted %-28s %5.1f s" % (wid, dt), flush=True)
    print("painted %d works in %.0f s" % (len(works), time.time() - t))
    if a.contact:
        contact(works, images, a.contact)
    if a.patch:
        patch_array(works, images)
        return
    if a.only or a.no_sheets:
        return
    cells = write_sheets(pack(works, images), images)
    write_tres(works, cells)
    write_review(works)


if __name__ == "__main__":
    main()
