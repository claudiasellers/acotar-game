#!/usr/bin/env python3
"""The opening film's land map detail (lane L67).

Lays Kenney's Cartography Pack (CC0, art/film/mural/cartography/kenney/) onto
the mural's island as gold-ink map icons, for story/film/mural/mural_map.gdshader:

  art/film/mural/cartography/map_detail.webp   2048 x 2048, lossless, RGB:
      R  ink line (the sprite's own outline, antialiased)
      G  body (the sprite's inside, so the procedural stipple and stars
         under it are cleared and each icon reads cleanly)
      B  draw-in order. < 0.5: a sea icon, drawn with the coastline
         (B / 0.45 against `draw`); >= 0.5: a land icon, drawn over the
         fill ((B - 0.5) * 2 against `detail`). Each icon sweeps in from its
         lower left, like a brush stroke.
  art/film/mural/cartography/map_detail.json   the placements (for the test)

Image row 0 is the far north (shader p.y = 1). Positions below are in the
shader's p space: x west->east, y south->north, the island about
x 0.24..0.76, y 0.1..0.9, the Wall at y 0.38. Placement follows the Keeper's
reading of ch 3 / ch 13 (lore/00-keeper/questions-log.md, L67): this is the
map before the War, so fae palaces and temples stand over the WHOLE island,
south included, and nothing on it is human. Physical geography only; court
positions are post-Treaty and not drawn. Every zone is canon "X" except the
central mountain, which stays the shader's own (canon "C").

Deterministic (fixed seed). Run: python3 tools/film/gen_mural_map_detail.py
"""
import json
import math
import os
import random

from PIL import Image, ImageDraw

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
SRC = os.path.join(ROOT, "art", "film", "mural", "cartography", "kenney")
OUT = os.path.join(ROOT, "art", "film", "mural", "cartography")
SIZE = 2048
SEED = 20261104
WALL_V = 0.38

# Zones: (name, category, sprites, count, (x0, x1), (y0, y1), size range, order range, canon)
# size = sprite height as a fraction of the map; order = when it draws in.
LAND_ZONES = [
	("northern_peaks", "mountain", ["rocksMountain", "rocksTall", "rocksA", "rocksMountain"], 9,
			(0.33, 0.67), (0.645, 0.80), (0.044, 0.056), (0.00, 0.22), "X"),
	("northern_pines", "forest", ["treePines", "treePine", "treePineLarge", "treePinesSmall"], 8,
			(0.29, 0.71), (0.58, 0.76), (0.030, 0.038), (0.18, 0.38), "X"),
	("western_woods", "forest", ["treeRound", "treePines", "treeRound", "treePinesSmall"], 9,
			(0.28, 0.43), (0.45, 0.66), (0.034, 0.044), (0.30, 0.52), "X"),
	("eastern_hills", "hill", ["rocks", "rocksB", "rocks"], 6,
			(0.55, 0.72), (0.415, 0.66), (0.032, 0.042), (0.30, 0.50), "X"),
	("southern_blossom", "forest", ["treeRound", "treeRound", "treePinesSmall"], 8,
			(0.32, 0.68), (0.405, 0.50), (0.032, 0.040), (0.44, 0.62), "X"),
	("southern_tip_woods", "forest", ["treePines", "treeRound", "treePinesSmall", "treePine"], 8,
			(0.36, 0.64), (0.17, 0.355), (0.032, 0.040), (0.50, 0.68), "X"),
	("southern_tip_hills", "hill", ["rocks", "rocksB"], 3,
			(0.38, 0.62), (0.16, 0.34), (0.034, 0.040), (0.50, 0.66), "X"),
]
# Fixed places: (name, category, sprite, x, y, size, order, canon)
LAND_FIXED = [
	# Palaces and temples over the whole land, south included [A, Keeper ch 3].
	("palace_north", "palace", "castleTall", 0.5, 0.775, 0.052, 0.72, "X"),
	("palace_east", "palace", "castle", 0.655, 0.665, 0.046, 0.76, "X"),
	("palace_west", "palace", "castleWide", 0.34, 0.60, 0.050, 0.80, "X"),
	("palace_south", "palace", "castle", 0.585, 0.445, 0.050, 0.84, "X"),
	("palace_tip", "palace", "castleTall", 0.45, 0.255, 0.056, 0.88, "X"),
	("temple_north", "temple", "churchLarge", 0.62, 0.60, 0.038, 0.74, "X"),
	("temple_west", "temple", "churchLarge", 0.38, 0.47, 0.040, 0.82, "X"),
	("temple_east", "temple", "churchLarge", 0.68, 0.53, 0.040, 0.86, "X"),
	("temple_tip", "temple", "churchLarge", 0.56, 0.21, 0.040, 0.90, "X"),
	("lake_west", "lake", "lakeRound", 0.40, 0.66, 0.040, 0.24, "X"),
	("lake_tip", "lake", "lakeRound", 0.52, 0.30, 0.036, 0.56, "X"),
]
# The sea, inside the frame the land shots see (x 0.05..0.95, y 0.23..0.86).
SEA_FIXED = [
	("compass", "compass", "compass", 0.855, 0.70, 0.105, None, "X"),
	("cartouche", "cartouche", "banner", 0.145, 0.66, 0.100, None, "X"),
]
SEA_WAVES = (16, (0.05, 0.95), (0.20, 0.88), (0.050, 0.062))
# Keep clear: the central mountain (the shader's own, the heart of the map)
# and a band along the Wall so its one line of light reads.
# Icons of a kind may tuck behind each other (a range, a wood); negative = overlap.
GAP = {"mountain": -0.016, "forest": -0.008, "hill": -0.004}
CENTRAL = ((0.5, 0.585), 0.085)
WALL_BAND = 0.028


def island_d(x, y):
	"""The shader's island without its ragged noise (the noise moves the
	coast by at most about 0.085), so clearances below allow for it."""
	cx, cy = x - 0.5, y - 0.5
	t = min(1.0, max(0.0, (cy - 0.1) / (-0.45 - 0.1)))
	cx *= 1.0 + 0.55 * (t * t * (3.0 - 2.0 * t))
	return math.hypot(cx * 1.55, cy) - 0.4


def coast_angle(x, y):
	"""Where the shader's brush tip is (0..1) when it passes this point."""
	return math.atan2(x - 0.5, -(y - 0.5)) / (2.0 * math.pi) + 0.5


_cache = {}
# Icons cut from a pack sprite: name -> (sprite, fraction of its height kept
# from the top). Kenney's tall tree has a notched stem that reads as a key at
# map scale; cut short, it is a round broadleaf crown.
CUTS = {"treeRound": ("treeTall", 0.52)}


def sprite(name):
	"""(line, body) as L images: ink alpha, and everything the outline encloses."""
	if name in _cache:
		return _cache[name]
	src, keep = CUTS.get(name, (name, 1.0))
	im = Image.open(os.path.join(SRC, src + ".png")).convert("RGBA")
	bbox = im.getchannel("A").getbbox()
	im = im.crop(bbox)
	if keep < 1.0:
		im = im.crop((0, 0, im.width, int(round(im.height * keep))))
		im = im.crop(im.getchannel("A").getbbox())
	line = im.getchannel("A")
	pad = 2
	w, h = line.size
	mask = Image.new("L", (w + 2 * pad, h + 2 * pad), 0)
	mask.paste(line.point(lambda a: 255 if a > 40 else 0), (pad, pad))
	ImageDraw.floodfill(mask, (0, 0), 128)
	body = mask.point(lambda v: 0 if v == 128 else 255).crop((pad, pad, pad + w, pad + h))
	_cache[name] = (line, body)
	return _cache[name]


def extent(name, size):
	line, _ = sprite(name)
	w, h = line.size
	return size * w / h, size


def footprint_ok(x, y, wd, ht, land, margin):
	pts = [(x + dx * wd / 2.0, y + dy * ht) for dx in (-1, 0, 1) for dy in (0.0, 0.5, 1.0)]
	if land:
		return all(island_d(px, py) < -margin for px, py in pts)
	return all(island_d(px, py) > margin for px, py in pts)


def clear_of_reserved(x, y, wd, ht):
	(cx, cy), r = CENTRAL
	for px, py in [(x - wd / 2, y), (x + wd / 2, y), (x, y + ht), (x, y + ht / 2)]:
		if math.hypot(px - cx, py - cy) < r:
			return False
	return not (y - WALL_BAND < WALL_V < y + ht + WALL_BAND)


def overlaps(placed, x, y, wd, ht, gap):
	for p in placed:
		if abs(p["x"] - x) < (p["w"] + wd) / 2 + gap and abs((p["y"] + p["h"] / 2) - (y + ht / 2)) < (p["h"] + ht) / 2 + gap:
			return True
	return False


def place(placed, item, x, y, size, land):
	wd, ht = extent(item["sprite"], size)
	item.update(x=round(x, 4), y=round(y, 4), w=round(wd, 4), h=round(ht, 4), land=land)
	placed.append(item)


def layout():
	rng = random.Random(SEED)
	placed = []
	for name, cat, spr, x, y, size, order, canon in LAND_FIXED:
		place(placed, dict(zone=name, category=cat, sprite=spr, order=order, canon=canon), x, y, size, True)
	for name, cat, spr, x, y, size, order, canon in SEA_FIXED:
		order = 0.94 if cat == "compass" else 0.97  # drawn as the coast closes
		place(placed, dict(zone=name, category=cat, sprite=spr, order=order, canon=canon), x, y, size, False)
	for name, cat, sprites, count, (x0, x1), (y0, y1), (s0, s1), (o0, o1), canon in LAND_ZONES:
		got, tries = 0, 0
		while got < count and tries < 4000:
			tries += 1
			spr = sprites[got % len(sprites)]
			size = rng.uniform(s0, s1)
			x, y = rng.uniform(x0, x1), rng.uniform(y0, y1)
			wd, ht = extent(spr, size)
			if not footprint_ok(x, y, wd, ht, True, 0.05) or not clear_of_reserved(x, y, wd, ht):
				continue
			if overlaps(placed, x, y, wd, ht, GAP.get(cat, 0.002)):
				continue
			# Drawn north to south within the zone, like a hand working down the page.
			order = o0 + (o1 - o0) * (1.0 - (y - y0) / max(1e-6, y1 - y0))
			place(placed, dict(zone=name, category=cat, sprite=spr, order=round(order, 4), canon=canon), x, y, size, True)
			got += 1
		if got < count:
			raise SystemExit("zone %s placed %d of %d" % (name, got, count))
	count, (x0, x1), (y0, y1), (s0, s1) = SEA_WAVES
	got, tries = 0, 0
	while got < count and tries < 8000:
		tries += 1
		x, y = rng.uniform(x0, x1), rng.uniform(y0, y1)
		size = rng.uniform(s0, s1)
		wd, ht = extent("textureWater", size)
		if not footprint_ok(x, y, wd, ht, False, 0.09) or overlaps(placed, x, y, wd, ht, 0.02):
			continue
		order = min(0.98, coast_angle(x, y + ht / 2) + 0.02)
		place(placed, dict(zone="sea", category="wave", sprite="textureWater", order=round(order, 4), canon="X"), x, y, size, False)
		got += 1
	if got < count:
		raise SystemExit("sea placed %d of %d" % (got, count))
	return placed


def render(placed):
	r = Image.new("L", (SIZE, SIZE), 0)
	g = Image.new("L", (SIZE, SIZE), 0)
	b = Image.new("L", (SIZE, SIZE), 0)
	# Far ones first, so nearer (more southern) icons overlap them, as on a page.
	for p in sorted(placed, key=lambda p: -p["y"]):
		line, body = sprite(p["sprite"])
		hp = max(4, int(round(p["h"] * SIZE)))
		wp = max(4, int(round(p["w"] * SIZE)))
		ls = line.resize((wp, hp), Image.LANCZOS)
		bs = body.resize((wp, hp), Image.LANCZOS)
		left = int(round(p["x"] * SIZE - wp / 2))
		top = int(round((1.0 - p["y"]) * SIZE - hp))
		# Clear what lies under this icon's body, then lay its ink.
		cover = bs.point(lambda v: 255 - v)
		for ch in (r, g):
			under = ch.crop((left, top, left + wp, top + hp))
			ch.paste(Image.composite(under, Image.new("L", (wp, hp), 0), cover), (left, top))
		r.paste(Image.composite(ls, r.crop((left, top, left + wp, top + hp)), ls), (left, top))
		g.paste(Image.composite(bs, g.crop((left, top, left + wp, top + hp)), bs), (left, top))
		# Order: a sweep from lower left to upper right across the icon, padded
		# a few texels so filtering never pulls in an earlier order.
		span = 0.05 if p["land"] else 0.03
		base = p["order"]
		pad = 4
		bw, bh = wp + 2 * pad, hp + 2 * pad
		ramp = Image.new("L", (bw, bh))
		px = ramp.load()
		for j in range(bh):
			for i in range(bw):
				u = (i / max(1, bw - 1) + (1.0 - j / max(1, bh - 1))) * 0.5
				t = min(1.0, base + span * u)
				v = 0.5 + 0.5 * t if p["land"] else 0.45 * t
				px[i, j] = int(round(v * 255))
		region = (left - pad, top - pad, left - pad + bw, top - pad + bh)
		keep = Image.composite(ramp, b.crop(region), Image.new("L", (bw, bh), 255))
		# Only where nothing has claimed the texel yet, or under this icon's own ink.
		claimed = b.crop(region).point(lambda v: 255 if v > 0 else 0)
		mine = Image.new("L", (bw, bh), 0)
		mine.paste(bs.point(lambda v: 255 if v > 0 else 0), (pad, pad))
		mine.paste(Image.composite(Image.new("L", (wp, hp), 255), mine.crop((pad, pad, pad + wp, pad + hp)), ls.point(lambda v: 255 if v > 0 else 0)), (pad, pad))
		use = Image.composite(Image.new("L", (bw, bh), 255), claimed.point(lambda v: 255 - v), mine)
		b.paste(Image.composite(keep, b.crop(region), use), region[:2])
	return Image.merge("RGB", (r, g, b))


def main():
	placed = layout()
	img = render(placed)
	img.save(os.path.join(OUT, "map_detail.webp"), "WEBP", lossless=True, quality=100, method=6)
	counts = {}
	for p in placed:
		counts[p["category"]] = counts.get(p["category"], 0) + 1
	manifest = {
		"source": "Kenney Cartography Pack (CC0 1.0), art/film/mural/cartography/kenney/License.txt",
		"size": SIZE, "seed": SEED, "wall_v": WALL_V, "counts": counts,
		"placements": placed,
	}
	with open(os.path.join(OUT, "map_detail.json"), "w") as f:
		json.dump(manifest, f, indent=1)
		f.write("\n")
	print("placements %d %s; %d KB" % (len(placed), counts,
			os.path.getsize(os.path.join(OUT, "map_detail.webp")) // 1024))


if __name__ == "__main__":
	main()
