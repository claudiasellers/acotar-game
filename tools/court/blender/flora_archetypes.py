"""Parametric archetype builders. Each takes (Mesh, rng, **params) and builds one asset.

The data table in flora_table.py picks an archetype and parameters per asset id.
"""

from __future__ import annotations

import math
import random
from typing import Sequence

from mathutils import Vector

import flora_lib as L
from flora_lib import P, TAU, Mesh

V = Vector


def _c(x: str | Sequence[float]) -> Sequence[float]:
	return P[x] if isinstance(x, str) else x


def _ring(rng: random.Random, i: int, n: int, radius: float) -> Vector:
	a = TAU * i / max(1, n) + rng.uniform(-0.35, 0.35)
	r = radius * (0.35 + 0.65 * math.sqrt((i + 0.5) / max(1, n))) if n > 1 else 0.0
	return V((math.cos(a) * r, math.sin(a) * r, 0.0))


# --------------------------------------------------------------------------------------
# Flowering plants
# --------------------------------------------------------------------------------------


def flower(m: Mesh, rng: random.Random, head: str = "daisy", stems: int = 3, height: float = 0.4,
		radius: float = 0.06, petals: int = 8, color: str = "rose", centre: str = "butter", shape: str = "round",
		leaves: int = 4, leaf_color: str = "leaf", leaf_len: float = 0.12, spread: float = 0.08,
		glow: float = 0.0, centre_glow: float = 0.0, color2: str | None = None, nod: float = 0.0,
		layers: int = 1, basal: int = 0, open_pitch: float = 1.2, stem_color: str = "stem") -> None:
	col = _c(color)
	col2 = _c(color2) if color2 else None
	if basal:
		L.rosette(m, V((0, 0, 0)), basal, leaf_len, leaf_len * 0.35, _c(leaf_color), rng, pitch=1.2)
	for si in range(stems):
		base = _ring(rng, si, stems, spread)
		h = height * rng.uniform(0.75, 1.0) * (1.0 if si == 0 else 0.92)
		lean = V((base.x, base.y, 0)) * 1.4 + V((rng.uniform(-1, 1), rng.uniform(-1, 1), 0)) * height * 0.06
		top = base + V((0, 0, h))
		path = L.stem(m, base, top, max(0.004, radius * 0.07), _c(stem_color), lean=lean)
		tip = path[-1]
		axis = (tip - path[-2]).normalized()
		if nod:
			axis = (axis + V((lean.x, lean.y, 0)).normalized() * nod * 2.0 - V((0, 0, nod))).normalized()
		c = L.mix(col, col2, rng.random()) if col2 is not None else L.jitter(rng, col, 0.05)
		for li in range(leaves):
			t = 0.15 + 0.55 * li / max(1, leaves)
			p = path[0].lerp(path[-1], t)
			L.leaf(m, p, rng.uniform(0, TAU), rng.uniform(0.9, 1.3), leaf_len * rng.uniform(0.8, 1.1),
				leaf_len * 0.3, L.jitter(rng, _c(leaf_color), 0.05))
		_head(m, rng, head, tip, axis, radius, petals, c, _c(centre), shape, glow, centre_glow, col2, layers,
			open_pitch, h)


def _head(m: Mesh, rng: random.Random, head: str, tip: Vector, axis: Vector, radius: float, petals: int,
		c: Sequence[float], centre: Sequence[float], shape: str, glow: float, centre_glow: float,
		col2: Sequence[float] | None, layers: int, open_pitch: float, h: float) -> None:
	if head == "daisy":
		L.blossom(m, tip, axis, petals, radius, c, centre, shape=shape, open_pitch=open_pitch, cup=0.15,
			layers=layers, rng=rng, glow=glow, centre_glow=centre_glow, centre_size=0.3)
	elif head == "cup":
		L.blossom(m, tip, axis, petals, radius, c, centre, shape=shape, open_pitch=0.7, cup=0.45, layers=layers,
			rng=rng, glow=glow, centre_glow=centre_glow, centre_size=0.25)
	elif head == "rose":
		L.rose_head(m, tip, axis, radius, c, rng, glow=glow)
	elif head == "bells":  # foxglove / bluebell / hyacinth: spike of hanging/outward bells
		count = petals
		for i in range(count):
			t = i / max(1, count - 1)
			p = tip - axis * (h * 0.45) * (1.0 - t)
			a = i * 2.39996323
			out = V((math.cos(a), math.sin(a), -0.35)).normalized()
			r = radius * (1.0 - 0.45 * t)
			cc = L.mix(c, col2, t) if col2 is not None else c
			L.bell(m, p + out * r * 1.6, out, r * 0.55, r * 1.6, cc, centre, seg=6, glow=glow)
	elif head == "spike":  # lavender / heather / woad / mugwort florets
		L.bead_spike(m, tip - axis * h * 0.3, h * 0.32, petals, radius, c, rng, color_top=col2, glow=glow,
			around=3)
	elif head == "umbel":
		L.umbel(m, tip, radius, petals, radius * 0.16, c, rng, glow=glow)
	elif head == "puff":
		L.puff(m, tip + axis * radius * 0.7, radius, petals, radius * 0.3, c, rng, color2=col2, glow=glow)
	elif head == "seedhead":  # dandelion clock: core + radial plumes with glowing tips
		ctr = tip + axis * radius * 0.2
		L.ellipsoid(m, ctr, (radius * 0.18,) * 3, centre, centre_glow, seg=6, rings=4)
		for i in range(petals):
			y = 1.0 - 2.0 * (i + 0.5) / petals
			rr = math.sqrt(max(0.0, 1 - y * y))
			a = i * 2.39996323
			d = V((math.cos(a) * rr, math.sin(a) * rr, y))
			L.tube(m, [ctr, ctr + d * radius * 0.85], [radius * 0.012, radius * 0.008], c, glow * 0.5, sides=3,
				cap_end=False)
			L.ellipsoid(m, ctr + d * radius, (radius * 0.08,) * 3, c, glow, seg=4, rings=2)
	elif head == "trumpet":  # honeysuckle, fire lily, moonflower
		for k in range(max(1, petals)):
			a = TAU * k / max(1, petals) + rng.uniform(-0.2, 0.2)
			d = (axis + V((math.cos(a), math.sin(a), 0.2)) * (0.9 if petals > 1 else 0.0)).normalized()
			L.bell(m, tip + d * radius * 1.6, d, radius * 0.5, radius * 1.6, c, centre, seg=7, flare=1.9, glow=glow,
				lobes=petals if petals > 1 else 5)
			for s in range(3):  # stamens
				sd = (d + V((rng.uniform(-.2, .2), rng.uniform(-.2, .2), rng.uniform(-.2, .2)))).normalized()
				L.tube(m, [tip + d * radius * 0.4, tip + sd * radius * 2.1], [radius * 0.03, radius * 0.02], centre,
					glow, sides=3)
	elif head == "raceme":  # wisteria / lilac: cone of florets, hanging if axis points down
		count = petals
		for i in range(count):
			t = i / max(1, count - 1)
			rr = radius * (1.0 - t) * 0.9
			a = i * 2.39996323
			p = tip + axis * (h * 0.0 + radius * 3.0 * t) + V((math.cos(a) * rr, math.sin(a) * rr, 0))
			cc = L.mix(c, col2, t) if col2 is not None else L.jitter(rng, c, 0.05)
			fr = radius * 0.3 * (1.0 - 0.4 * t)
			L.ellipsoid(m, p, (fr, fr, fr * 0.8), cc, glow, seg=5, rings=3)
	elif head == "cornflower":
		L.ellipsoid(m, tip, (radius * 0.3,) * 3, centre, 0.0, seg=6, rings=4)
		for k in range(petals):
			a = TAU * k / petals
			d = (axis * 0.5 + V((math.cos(a), math.sin(a), 0))).normalized()
			L.bell(m, tip + d * radius, d, radius * 0.28, radius * 0.8, c, L.mix(c, P["white"], 0.3), seg=5,
				flare=1.6, lobes=4)
	elif head == "bud":  # rose hip / sloe-like
		L.ellipsoid(m, tip, (radius, radius, radius * 1.25), c, glow, seg=8, rings=5)


def berry_shrub(m: Mesh, rng: random.Random, height: float = 0.5, radius: float = 0.35, leaf_color: str = "leaf",
		berry: str = "strawberry", berries: int = 12, berry_r: float = 0.015, blobs: int = 4,
		flower_color: str | None = None, flowers: int = 0, drupelets: bool = False, thorny: bool = False,
		ground: bool = False, glow: float = 0.0, leaf_color2: str | None = None, clusters: int = 1,
		needles: bool = False) -> None:
	lc = _c(leaf_color)
	lc2 = _c(leaf_color2) if leaf_color2 else None
	if ground:  # low runners with trefoil leaves (strawberry)
		for i in range(blobs * 3):
			a = rng.uniform(0, TAU)
			p = V((math.cos(a), math.sin(a), 0)) * rng.uniform(0, radius * 0.8)
			for k in range(3):
				L.leaf(m, p + V((0, 0, height * 0.6)), a + k * TAU / 3, 1.2, radius * 0.25, radius * 0.12,
					L.jitter(rng, lc, 0.06), profile=L.petal_round)
			L.stem(m, p, p + V((0, 0, height * 0.6)), 0.003, P["stem"])
	else:
		for i in range(blobs):
			a = i * 2.39996323
			off = V((math.cos(a), math.sin(a), 0)) * radius * (0.0 if i == 0 else 0.45)
			r = radius * (0.7 if i == 0 else rng.uniform(0.45, 0.6))
			cc = L.mix(lc, lc2, rng.random()) if lc2 else L.jitter(rng, lc, 0.07)
			L.ellipsoid(m, off + V((0, 0, height * 0.55)), (r, r, height * 0.5 * (1.0 if i == 0 else 0.8)), cc,
				seg=9, rings=6, rng=rng, noise=0.1, flat_bottom=True)
		if needles:
			for i in range(40):
				a = rng.uniform(0, TAU)
				z = rng.uniform(0.15, 0.95)
				d = V((math.cos(a) * (1 - z * 0.5), math.sin(a) * (1 - z * 0.5), 0))
				p = d * radius * 0.85 + V((0, 0, height * z))
				L.leaf(m, p, a, 1.0 - z * 0.4, radius * 0.25, radius * 0.03, L.jitter(rng, lc, 0.1), curl=0.0, nv=2)
		if thorny:
			for i in range(16):
				a = rng.uniform(0, TAU)
				z = rng.uniform(0.2, 0.95)
				p = V((math.cos(a) * radius * 0.75, math.sin(a) * radius * 0.75, height * z))
				L.tube(m, [p, p + V((math.cos(a), math.sin(a), 0.3)) * radius * 0.18], [0.006, 0.0005], P["bark"], sides=3,
					cap_end=False)
	bc = _c(berry)
	for ci in range(clusters):
		for i in range(berries // clusters):
			a = rng.uniform(0, TAU)
			z = rng.uniform(0.25, 0.9) if not ground else 0.0
			rr = radius * (0.8 if not ground else rng.uniform(0.1, 0.8))
			p = V((math.cos(a) * rr, math.sin(a) * rr, height * z + (berry_r if ground else 0)))
			if drupelets:
				L.berry_cluster(m, p, 1, berry_r, bc, rng, drupelets=True, glow=glow)
			elif ground:
				L.fruit(m, p - V((0, 0, berry_r)), berry_r, bc, rng, kind="heart")
				L.blossom(m, p + V((0, 0, berry_r * 1.6)), V((0, 0, 1)), 5, berry_r * 0.9, P["leaf_deep"], P["leaf"],
					shape="pointed", centre_size=0.0, open_pitch=1.5)
			else:
				L.berry_cluster(m, p, 3, berry_r, bc, rng, spread=0.8, glow=glow)
	if flower_color:
		fc = _c(flower_color)
		for i in range(flowers):
			a = rng.uniform(0, TAU)
			z = rng.uniform(0.35, 0.95)
			d = V((math.cos(a) * (1.0 - z * 0.4), math.sin(a) * (1.0 - z * 0.4), z * 0.6)).normalized()
			p = V((0, 0, height * 0.55)) + V((d.x * radius * 0.85, d.y * radius * 0.85, (z - 0.5) * height * 0.9))
			L.blossom(m, p, d, 5, radius * 0.16, L.jitter(rng, fc, 0.05), P["butter"], open_pitch=1.35, rng=rng,
				centre_size=0.25)


def rose_plant(m: Mesh, rng: random.Random, height: float = 0.6, color: str = "rose_red", blooms: int = 3,
		bloom_r: float = 0.08, glow: float = 0.0, leaf_color: str = "leaf_deep", stem_color: str = "stem",
		withered: bool = False, buds: int = 1, thorn_color: str = "bark") -> None:
	"""Rose cane with oversized cabbage blooms, leaves and thorns."""
	col = _c(color)
	for i in range(blooms + buds):
		base = _ring(rng, i, blooms + buds, 0.05)
		h = height * rng.uniform(0.7, 1.0)
		lean = V((base.x, base.y, 0)) * 3.0 + V((rng.uniform(-1, 1), rng.uniform(-1, 1), 0)) * height * 0.08
		path = L.stem(m, base, base + V((0, 0, h)), 0.007, _c(stem_color), lean=lean, steps=4)
		for k in range(3):
			p = path[0].lerp(path[-1], 0.25 + 0.2 * k)
			a = rng.uniform(0, TAU)
			L.tube(m, [p, p + V((math.cos(a), math.sin(a), 0.4)) * 0.018], [0.004, 0.0005], _c(thorn_color), sides=3,
				cap_end=False)
			for s in range(3):  # leaflet triplets
				L.leaf(m, p, a + 1.2 + (s - 1) * 0.5, 1.1 + 0.2 * s, height * 0.12, height * 0.055,
					L.jitter(rng, _c(leaf_color), 0.05), curl=-0.3 if not withered else 0.6)
		axis = (path[-1] - path[-2]).normalized()
		if withered:
			axis = (axis + V((lean.x, lean.y, -0.6))).normalized()
		if i < blooms:
			L.rose_head(m, path[-1], axis, bloom_r * rng.uniform(0.9, 1.1), L.jitter(rng, col, 0.05), rng, glow=glow)
		else:
			L.ellipsoid(m, path[-1] + axis * bloom_r * 0.3, (bloom_r * 0.3, bloom_r * 0.3, bloom_r * 0.5), col, glow,
				seg=7, rings=4, rot=L._rot_to(axis))


def rose_hip(m: Mesh, rng: random.Random, height: float = 0.45, count: int = 7, r: float = 0.016,
		color: str = "coral") -> None:
	"""Arching bare cane with glossy hips."""
	for i in range(3):
		a = TAU * i / 3 + rng.uniform(-0.3, 0.3)
		path = L.curve_path(V((0, 0, 0)), V((math.cos(a) * 0.4, math.sin(a) * 0.4, 1)), height,
			V((math.cos(a), math.sin(a), -0.6)) * height * 0.5, 5)
		L.tube(m, path, [0.007 * (1 - t / 6) + 0.002 for t in range(6)], P["bark"], sides=5)
		for k in range(count // 3 + 1):
			p = path[2 + k % 4]
			hip = p + V((0, 0, -r * 1.8))
			L.tube(m, [p, hip + V((0, 0, r))], [0.002, 0.002], P["stem"], sides=3)
			L.ellipsoid(m, hip, (r, r, r * 1.35), L.jitter(rng, _c(color), 0.06), seg=8, rings=5)
			L.ellipsoid(m, hip - V((0, 0, r * 1.3)), (r * 0.35, r * 0.35, r * 0.25), P["bark_dark"], seg=5, rings=3)
			L.leaf(m, p, a + 1.5, 1.2, height * 0.12, height * 0.05, P["leaf_deep"])


def herb(m: Mesh, rng: random.Random, kind: str = "blades", count: int = 14, height: float = 0.25,
		width: float = 0.02, color: str = "leaf", tip: str | None = None, flowers: str | None = None,
		flower_head: str = "daisy", flower_count: int = 0, flower_r: float = 0.03, petals: int = 6,
		centre: str = "butter", glow: float = 0.0, spread: float = 0.6, radius: float = 0.04) -> None:
	"""Herb tuft. kinds: blades (garlic/chives), whorl (woodruff/thyme), serrated (nettle/mint),
	trefoil (clover/sorrel), feathery (yarrow/chamomile/mugwort)."""
	col = _c(color)
	tc = _c(tip) if tip else None
	if kind == "blades":
		L.tuft(m, V((0, 0, 0)), count, height, width, col, rng, tip=tc, spread=spread, radius=radius)
	elif kind == "trefoil":
		for i in range(count):
			base = _ring(rng, i, count, radius * 2.5)
			h = height * rng.uniform(0.5, 1.0)
			top = base + V((0, 0, h))
			L.stem(m, base, top, 0.0025, P["stem"], steps=2)
			a0 = rng.uniform(0, TAU)
			for k in range(3):
				L.leaf(m, top, a0 + TAU * k / 3, 1.35, width * 1.4, width * 0.8, L.jitter(rng, col, 0.05),
					profile=L.petal_heart, curl=-0.1, nv=2)
	elif kind in ("whorl", "serrated", "feathery"):
		stems = max(3, count // 4)
		for si in range(stems):
			base = _ring(rng, si, stems, radius * 2.0)
			h = height * rng.uniform(0.7, 1.0)
			lean = V((base.x, base.y, 0)) * 2.0
			path = L.stem(m, base, base + V((0, 0, h)), 0.003, L.mix(col, P["stem"], 0.5), lean=lean, steps=3)
			tiers = 4 if kind != "feathery" else 5
			for t in range(tiers):
				p = path[0].lerp(path[-1], 0.2 + 0.75 * t / tiers)
				n_l = 6 if kind == "whorl" else (2 if kind == "serrated" else 3)
				a0 = rng.uniform(0, TAU)
				for k in range(n_l):
					ln = width * (2.2 if kind != "feathery" else 2.6) * (1.0 - 0.4 * t / tiers)
					wd = width * (0.45 if kind == "whorl" else (0.7 if kind == "serrated" else 0.2))
					L.leaf(m, p, a0 + TAU * k / n_l, 1.2 if kind != "serrated" else 1.0, ln, wd, L.jitter(rng, col, 0.06),
						curl=-0.15, nv=3 if kind != "feathery" else 2)
	if flowers and flower_count:
		fc = _c(flowers)
		for i in range(flower_count):
			base = _ring(rng, i, flower_count, radius * 2.0)
			top = base + V((rng.uniform(-.02, .02), rng.uniform(-.02, .02), height * rng.uniform(1.0, 1.25)))
			L.stem(m, base, top, 0.0025, P["stem"], steps=2)
			_head(m, rng, flower_head, top, V((0, 0, 1)), flower_r, petals, L.jitter(rng, fc, 0.05), _c(centre), "round",
				glow, glow, None, 1, 1.25, height * 0.5)


def mushrooms(m: Mesh, rng: random.Random, count: int = 3, height: float = 0.12, cap_r: float = 0.06,
		cap: str = "orange", stem_color: str = "cream", shape: str = "dome", spots: str | None = None,
		glow: float = 0.0, stem_glow: float = 0.0, spread: float = 0.08, ring: bool = False, grass: int = 0) -> None:
	for i in range(count):
		if ring:
			a = TAU * i / count
			base = V((math.cos(a), math.sin(a), 0)) * spread
		else:
			base = _ring(rng, i, count, spread)
		k = 1.0 if i == 0 else rng.uniform(0.55, 0.85)
		tilt = V((base.x, base.y, 0)) * (2.0 / max(0.01, spread)) * 0.08
		L.mushroom(m, base, height * k, cap_r * k, L.jitter(rng, _c(cap), 0.05), _c(stem_color), rng, shape=shape,
			spots=_c(spots) if spots else None, glow=glow, stem_glow=stem_glow, tilt=tilt)
	if grass:
		L.tuft(m, V((0, 0, 0)), grass, height * 0.6, 0.01, P["leaf"], rng, radius=spread)


def reed(m: Mesh, rng: random.Random, count: int = 10, height: float = 1.0, color: str = "sage",
		head: str | None = "bark", head_count: int = 3, root: bool = False, silver: bool = False,
		glow: float = 0.0, radius: float = 0.08) -> None:
	col = _c(color)
	L.tuft(m, V((0, 0, 0)), count, height, 0.018, col, rng, tip=L.mix(col, P["butter"], 0.3) if not silver else P["silver"],
		spread=0.25, radius=radius, nv=4)
	if head:
		for i in range(head_count):
			base = _ring(rng, i, head_count, radius)
			top = base + V((rng.uniform(-.05, .05), rng.uniform(-.05, .05), height * rng.uniform(0.9, 1.1)))
			path = L.stem(m, base, top, 0.006, L.mix(col, P["stem"], 0.4), steps=3)
			L.ellipsoid(m, path[-1] + V((0, 0, height * 0.07)), (0.02, 0.02, height * 0.08), L.jitter(rng, _c(head), 0.05),
				glow, seg=6, rings=4)
			L.tube(m, [path[-1] + V((0, 0, height * 0.14)), path[-1] + V((0, 0, height * 0.22))], [0.003, 0.001], col,
				sides=3)
	if root:  # exposed knobbly rhizome with pale shoots
		path = [V((-0.12, 0, 0.02)), V((-0.04, 0.02, 0.03)), V((0.05, -0.01, 0.025)), V((0.14, 0.01, 0.02))]
		L.tube(m, path, [0.022, 0.026, 0.024, 0.015], P["cream"], sides=7)
		for p in path:
			L.tube(m, [p, p + V((rng.uniform(-.03, .03), rng.uniform(-.03, .03), -0.02))], [0.004, 0.001], P["earth"],
				sides=3)


def vine(m: Mesh, rng: random.Random, height: float = 0.8, strands: int = 3, color: str = "leaf",
		flower: str | None = None, flower_head: str = "trumpet", flower_count: int = 4, flower_r: float = 0.025,
		centre: str = "butter", petals: int = 1, leaves: int = 8, leaf_len: float = 0.06, support: bool = True,
		hang: bool = False, width: float = 0.3, glow: float = 0.0, color2: str | None = None) -> None:
	"""Climber on a little twig trellis (support) or hanging curtain (hang)."""
	col = _c(color)
	if support:
		L.tube(m, [V((0, 0, 0)), V((0.01, 0, height * 1.02))], [0.012, 0.008], P["bark"], sides=5)
	for s in range(strands):
		pts = []
		ph = rng.uniform(0, TAU)
		x0 = (s / max(1, strands - 1) - 0.5) * width if strands > 1 else 0.0
		for i in range(9):
			t = i / 8
			if hang:
				p = V((x0 + math.sin(t * 5 + ph) * 0.03, 0.02 * math.sin(t * 3 + ph), height * (1.0 - t * rng.uniform(0.7, 1.0))))
			else:
				p = V((math.cos(t * 9 + ph) * 0.03 + x0 * 0.2, math.sin(t * 9 + ph) * 0.03, height * t))
			pts.append(p)
		L.tube(m, pts, [0.004] * len(pts), L.mix(col, P["stem"], 0.4), sides=4, cap_end=False)
		for li in range(leaves):
			p = pts[1 + li % 8]
			L.leaf(m, p, rng.uniform(0, TAU), rng.uniform(1.2, 1.9), leaf_len * rng.uniform(0.8, 1.15), leaf_len * 0.55,
				L.jitter(rng, col, 0.07), profile=L.petal_heart, nv=2)
		if flower:
			for fi in range(flower_count):
				p = pts[2 + (fi * 3) % 7]
				d = V((rng.uniform(-1, 1), rng.uniform(-1, 1), 0.4 if not hang else -0.8)).normalized()
				fc = L.mix(_c(flower), _c(color2), rng.random()) if color2 else _c(flower)
				_head(m, rng, flower_head, p, d, flower_r, petals, fc, _c(centre), "round", glow, glow,
					_c(color2) if color2 else None, 1, 1.2, height * 0.3)


def fruit_drop(m: Mesh, rng: random.Random, kind: str = "apple", count: int = 3, r: float = 0.04,
		color: str = "apple_red", blush: str | None = None, leaf_color: str = "leaf", twig: bool = True,
		stalk_pairs: bool = False, husk: str | None = None) -> None:
	"""Windfall fruit lying on the ground with a leaf (and twig)."""
	for i in range(count):
		base = _ring(rng, i, count, r * 2.2)
		top = L.fruit(m, base, r * rng.uniform(0.85, 1.05), L.jitter(rng, _c(color), 0.05), rng, kind=kind,
			blush_color=_c(blush) if blush else None)
		if husk:  # hazelnut / acorn cup
			L.lathe(m, top - V((0, 0, r * 0.75)), [(r * 0.75, 0), (r * 0.95, r * 0.3), (r * 0.7, r * 0.7), (0.002, r * 0.75)],
				_c(husk), seg=9, wobble=0.15, rng=rng)
		stalk_end = top + V((rng.uniform(-.01, .01), rng.uniform(-.01, .01), r * 0.5))
		L.tube(m, [top - V((0, 0, r * 0.15)), stalk_end], [0.003, 0.002], P["bark_dark"], sides=3)
		if stalk_pairs and i % 2 == 1:
			continue
		L.leaf(m, stalk_end, rng.uniform(0, TAU), 1.5, r * 1.6, r * 0.7, L.jitter(rng, _c(leaf_color), 0.05))
	if twig:
		L.tube(m, [V((-r * 3, -r, 0.01)), V((0, -r * 1.5, 0.015)), V((r * 3, -r * 1.2, 0.01))], [0.006, 0.005, 0.003],
			P["bark"], sides=4)


def wood(m: Mesh, rng: random.Random, kind: str = "branch", length: float = 0.8, r: float = 0.04,
		color: str = "bark", mark: str | None = None, extra: str | None = None, glow: float = 0.0) -> None:
	"""Woody gatherables: fallen branch, bark curl, oak gall twig, bracket fungus, canker."""
	col = _c(color)
	if kind == "branch":
		path = [V((-length / 2, 0, r)), V((-length / 6, 0.03, r * 1.1)), V((length / 6, -0.02, r)), V((length / 2, 0.02, r * 0.8))]
		L.tube(m, path, [r, r * 0.9, r * 0.75, r * 0.55], col, sides=7)
		for k in range(3):
			p = path[1 + k % 3]
			a = rng.uniform(-1.2, 1.2) + (0 if k % 2 else math.pi)
			L.tube(m, [p, p + V((0.3, math.sin(a), 0.5)) * length * 0.25], [r * 0.4, r * 0.15], col, sides=4)
			if extra:  # ash keys / leaves
				L.leaf(m, p + V((0.3, math.sin(a), 0.5)) * length * 0.25, a, 1.3, length * 0.1, length * 0.03, _c(extra))
		if mark:
			for k in range(8):
				p = path[0].lerp(path[-1], (k + 0.5) / 8)
				L.ellipsoid(m, p + V((0, 0, r * 0.9)), (r * 0.5, r * 0.25, r * 0.12), _c(mark), seg=5, rings=3)
	elif kind == "bark":  # curl of bark lying on the ground
		pts = []
		for j in range(5):
			v = j / 4
			row = []
			for i in range(7):
				a = math.pi * (0.1 + 0.9 * i / 6) * 1.6
				row.append(V((v * length - length / 2, math.cos(a) * r, r + math.sin(a) * r * 0.9)))
			pts.append(row)
		m.grid(pts, col)
		m.grid([[p + V((0, 0, -0.004)) for p in row] for row in pts], L.mix(col, P["cream"], 0.5), flip=True)
		if mark:
			for k in range(6):
				L.ellipsoid(m, V(((k + 0.5) / 6 * length - length / 2, rng.uniform(-r, r) * 0.4, r * 1.85)),
					(length * 0.05, r * 0.08, 0.004), _c(mark), seg=5, rings=3)
	elif kind == "gall":  # oak twig with round galls and lobed leaves
		L.tube(m, [V((-length / 2, 0, 0.01)), V((length / 2, 0.02, 0.02))], [0.006, 0.004], P["bark"], sides=5)
		for k in range(3):
			p = V((-length / 3 + k * length / 3, 0.0, 0.02 + r))
			L.ellipsoid(m, p, (r, r, r), L.jitter(rng, col, 0.08), seg=8, rings=6, rng=rng, noise=0.05)
			L.ellipsoid(m, p + V((r * 0.3, -r * 0.6, r * 0.3)), (r * 0.12,) * 3, P["bark_dark"], seg=4, rings=2)
		for k in range(4):
			L.leaf(m, V((-length / 2 + k * length / 4, 0, 0.015)), rng.uniform(0, TAU), 1.45, length * 0.35, length * 0.14,
				L.jitter(rng, _c(extra or "leaf"), 0.06), profile=lambda v: L.leaf_profile(v) * (0.8 + 0.2 * math.cos(v * 18)))
	elif kind == "bracket":  # tinder fungus shelves on a stump
		L.lathe(m, V((0, 0, 0)), [(r * 2.2, 0), (r * 2.0, length * 0.5), (r * 1.8, length)], P["bark_light"], seg=10,
			wobble=0.05, rng=rng)
		m.fan_cap([V((math.cos(TAU * i / 10) * r * 1.8, math.sin(TAU * i / 10) * r * 1.8, length)) for i in range(10)],
			V((0, 0, length)), P["cream"])
		for k in range(3):
			a = k * 2.1
			h = length * (0.35 + 0.22 * k)
			d = V((math.cos(a), math.sin(a), 0))
			ctr = d * r * 2.0 + V((0, 0, h))
			L.ellipsoid(m, ctr + d * r * 0.6, (r * 1.2, r * 1.2, r * 0.45), L.jitter(rng, col, 0.05), seg=9, rings=5,
				rot=L._rot_to(V((0, 0, 1))))
			L.ellipsoid(m, ctr + d * r * 0.6 + V((0, 0, r * 0.15)), (r * 1.15, r * 1.15, r * 0.25), _c(extra or "bark_light"),
				seg=9, rings=4)
	elif kind == "canker":  # chaga: black crusty lump on a birch stump
		L.lathe(m, V((0, 0, 0)), [(r * 2.2, 0), (r * 2.0, length * 0.5), (r * 1.8, length)], P["birch"], seg=10)
		for k in range(6):
			L.ellipsoid(m, V((rng.uniform(-1, 1) * r * 1.9, -r * 1.9, length * (k + 0.5) / 6)),
				(r * 0.5, r * 0.06, r * 0.08), P["birch_mark"], seg=4, rings=2)
		L.ellipsoid(m, V((r * 1.9, 0, length * 0.55)), (r * 1.0, r * 1.2, r * 1.3), col, seg=9, rings=6, rng=rng,
			noise=0.22)
		L.ellipsoid(m, V((r * 2.2, 0, length * 0.55)), (r * 0.7, r * 0.8, r * 0.9), _c(extra or "rust"), seg=7, rings=4,
			rng=rng, noise=0.2)
	elif kind == "root":  # hollow root: gnarled pale root with hollow cavity glow
		path = [V((-length / 2, 0, r * 0.6)), V((-length / 5, 0.04, r * 1.3)), V((length / 6, -0.03, r * 1.2)),
			V((length / 2, 0.02, r * 0.4))]
		L.tube(m, path, [r * 0.5, r, r * 0.9, r * 0.3], col, sides=8)
		L.ellipsoid(m, path[1] + V((0, -r * 0.75, 0)), (r * 0.45, r * 0.25, r * 0.55), _c(extra or "lilac"), glow,
			seg=7, rings=4)
		for k in range(6):
			p = path[k % 4]
			L.tube(m, [p, p + V((rng.uniform(-.1, .1), rng.uniform(-.1, .1), -r))], [r * 0.2, r * 0.03], col, sides=4)


def lichen_rock(m: Mesh, rng: random.Random, r: float = 0.25, rock: str = "stone", color: str = "lichen",
		patches: int = 14, tufts: bool = False) -> None:
	L.ellipsoid(m, V((0, 0, r * 0.4)), (r, r * 0.8, r * 0.55), _c(rock), seg=10, rings=6, rng=rng, noise=0.12,
		flat_bottom=True)
	for i in range(patches):
		th = rng.uniform(0, TAU)
		z = rng.uniform(0.1, 0.95)
		rr = math.sqrt(1 - z * z)
		n = V((math.cos(th) * rr, math.sin(th) * rr * 0.8, z * 0.55)).normalized()
		p = V((math.cos(th) * rr * r, math.sin(th) * rr * r * 0.8, r * 0.4 + z * r * 0.55))
		if tufts:  # old man's beard: hanging pale strands
			for k in range(3):
				L.tube(m, [p, p + V((rng.uniform(-.02, .02), rng.uniform(-.02, .02), -r * 0.35))], [0.006, 0.001],
					L.jitter(rng, _c(color), 0.05), sides=3)
		s = r * rng.uniform(0.12, 0.22)
		L.ellipsoid(m, p, (s, s, s * 0.25), L.jitter(rng, _c(color), 0.06), seg=6, rings=3, rot=L._rot_to(n))


def moss_cushion(m: Mesh, rng: random.Random, r: float = 0.22, color: str = "moss", specks: str = "glow_gold",
		speck_count: int = 22, glow: float = 1.0) -> None:
	for i in range(5):
		off = _ring(rng, i, 5, r * 0.55)
		rr = r * (0.65 if i == 0 else rng.uniform(0.4, 0.55))
		L.ellipsoid(m, off, (rr, rr, rr * 0.5), L.jitter(rng, _c(color), 0.08), seg=9, rings=5, rng=rng, noise=0.08,
			flat_bottom=True)
	for i in range(speck_count):  # tiny glowing stars
		a = i * 2.39996323
		rr = r * 0.85 * math.sqrt((i + 0.5) / speck_count)
		h = r * 0.32 * (1.0 - (rr / r) ** 2) + 0.012
		p = V((math.cos(a) * rr, math.sin(a) * rr, h))
		for k in range(5):
			ka = TAU * k / 5 + a
			L.tube(m, [p, p + V((math.cos(ka), math.sin(ka), 0.3)) * 0.012], [0.003, 0.0005], _c(specks), glow, sides=3,
				cap_end=False)


def water_lily(m: Mesh, rng: random.Random, pads: int = 1, r: float = 0.22, bloom: str = "blush", blooms: int = 1,
		pad_color: str = "lily_pad", bloom_r: float = 0.08, buds: int = 0) -> None:
	for i in range(pads):
		c = _ring(rng, i, pads, r * 1.3) if pads > 1 else V((0, 0, 0))
		rr = r * (1.0 if i == 0 else rng.uniform(0.55, 0.85))
		notch = rng.uniform(0, TAU)
		ring = []
		for k in range(14):
			a = notch + 0.35 + (TAU - 0.7) * k / 13
			ring.append(c + V((math.cos(a) * rr, math.sin(a) * rr, 0.01)))
		m.fan_cap(ring, c + V((0, 0, 0.012)), L.jitter(rng, _c(pad_color), 0.06))
		m.fan_cap([p - V((0, 0, 0.006)) for p in ring], c + V((0, 0, 0.006)), L.mix(_c(pad_color), P["coral"], 0.3),
			flip=True)
	for b in range(blooms):
		c = _ring(rng, b, max(1, pads), r * 0.4) + V((0, 0, 0.015))
		L.blossom(m, c, V((0, 0, 1)), 8, bloom_r, _c(bloom), P["butter"], shape="pointed", open_pitch=1.25, cup=0.3,
			layers=3, rng=rng, centre_size=0.3, tip_color=L.mix(_c(bloom), P["rose"], 0.4))
	for b in range(buds):
		c = _ring(rng, b + 2, 4, r * 1.1)
		L.ellipsoid(m, c + V((0, 0, 0.06)), (0.02, 0.02, 0.04), _c(bloom), seg=6, rings=4)


def web(m: Mesh, rng: random.Random, size: float = 0.35, color: str = "web", glow: float = 0.0) -> None:
	"""Spider silk: orb web strung between two forked twigs, with dew beads."""
	for x in (-size * 0.55, size * 0.55):
		L.tube(m, [V((x, 0, 0)), V((x * 1.05, 0, size * 1.1))], [0.008, 0.005], P["bark"], sides=5)
		L.tube(m, [V((x, 0, size * 0.7)), V((x * 1.3, 0, size * 1.0))], [0.004, 0.002], P["bark"], sides=4)
	ctr = V((0, 0, size * 0.62))
	spokes = 10
	for k in range(spokes):
		a = TAU * k / spokes
		e = ctr + V((math.cos(a) * size * 0.5, 0, math.sin(a) * size * 0.45))
		L.tube(m, [ctr, e], [0.0012, 0.0012], _c(color), glow, sides=3, cap_end=False)
	for ring in range(1, 5):
		rr = ring / 5
		pts = [ctr + V((math.cos(TAU * k / spokes) * size * 0.5 * rr, 0, math.sin(TAU * k / spokes) * size * 0.45 * rr))
			for k in range(spokes + 1)]
		L.tube(m, pts, [0.001] * len(pts), _c(color), glow, sides=3, cap_end=False)
		for k in range(0, spokes, 3):
			L.ellipsoid(m, pts[k], (0.004,) * 3, P["glow_blue"], glow, seg=4, rings=2)


def grass(m: Mesh, rng: random.Random, count: int = 26, height: float = 0.35, color: str = "leaf",
		tip: str = "leaf_light", radius: float = 0.12, seeds: int = 0, seed_color: str = "butter") -> None:
	L.tuft(m, V((0, 0, 0)), count, height, 0.014, _c(color), rng, tip=_c(tip), spread=0.55, radius=radius, nv=3)
	for i in range(seeds):
		base = _ring(rng, i, seeds, radius)
		top = base + V((rng.uniform(-.05, .05), rng.uniform(-.05, .05), height * 1.25))
		L.stem(m, base, top, 0.002, _c(color), steps=2)
		L.ellipsoid(m, top, (0.008, 0.008, 0.03), _c(seed_color), seg=5, rings=3)


def carpet(m: Mesh, rng: random.Random, r: float = 0.9, color: str = "rose", color2: str | None = None,
		flowers: int = 26, base: str = "leaf", petals: int = 5, head: str = "daisy") -> None:
	"""Flat patch of ground cover studded with little oversized-for-their-size blooms."""
	ring = []
	for k in range(16):
		a = TAU * k / 16
		rr = r * (1.0 + 0.12 * math.sin(a * 3 + 1.0))
		ring.append(V((math.cos(a) * rr, math.sin(a) * rr, 0.01)))
	m.fan_cap(ring, V((0, 0, 0.015)), _c(base))
	L.tuft(m, V((0, 0, 0)), 18, 0.12, 0.012, L.mix(_c(base), P["leaf_light"], 0.3), rng, radius=r * 0.85, spread=0.7)
	for i in range(flowers):
		a = i * 2.39996323
		rr = r * 0.9 * math.sqrt((i + 0.5) / flowers)
		p = V((math.cos(a) * rr, math.sin(a) * rr, 0.015))
		h = rng.uniform(0.04, 0.12)
		L.stem(m, p, p + V((0, 0, h)), 0.0025, P["stem"], steps=1)
		c = L.mix(_c(color), _c(color2), rng.random()) if color2 else L.jitter(rng, _c(color), 0.06)
		_head(m, rng, head, p + V((0, 0, h)), V((rng.uniform(-.2, .2), rng.uniform(-.2, .2), 1)).normalized(),
			rng.uniform(0.028, 0.04), petals, c, P["butter"], "round", 0.0, 0.0, None, 1, 1.3, h)


def fern(m: Mesh, rng: random.Random, fronds: int = 7, length: float = 0.7, color: str = "leaf",
		tip: str = "leaf_light") -> None:
	for i in range(fronds):
		yaw = TAU * i / fronds + rng.uniform(-0.2, 0.2)
		d = L.yaw_pitch(yaw, rng.uniform(0.6, 0.95))
		ln = length * rng.uniform(0.8, 1.05)
		path = L.curve_path(V((0, 0, 0)), d, ln, V((0, 0, -ln * 0.35)), 5)
		L.tube(m, path, [0.006 - 0.0009 * k for k in range(6)], L.mix(_c(color), P["stem"], 0.4), sides=3, cap_end=False)
		for k in range(1, 6):
			p = path[k]
			w = (1.0 - k / 6.5) * ln * 0.28
			for sgn in (-1, 1):
				L.leaf(m, p, yaw + sgn * 1.25, 1.35, w, w * 0.22, L.mix(_c(color), _c(tip), k / 6), curl=-0.3, nv=2)
	L.ellipsoid(m, V((0, 0, 0.03)), (0.05, 0.05, 0.04), P["bark"], seg=6, rings=3)


def toadstool_ring(m: Mesh, rng: random.Random, count: int = 9, r: float = 0.7, cap: str = "rose",
		spots: str = "pearl", glow: float = 0.0) -> None:
	mushrooms(m, rng, count=count, height=0.16, cap_r=0.08, cap=cap, stem_color="pearl", spots=spots, glow=glow,
		spread=r, ring=True)
	for i in range(count):
		a = TAU * (i + 0.5) / count
		L.tuft(m, V((math.cos(a) * r, math.sin(a) * r, 0)), 4, 0.1, 0.01, P["leaf_light"], rng, radius=0.04)


def ivy_curtain(m: Mesh, rng: random.Random, width: float = 1.6, height: float = 2.2, strands: int = 9,
		color: str = "leaf_deep", color2: str = "leaf_light", flower: str = "blush") -> None:
	L.tube(m, [V((-width / 2, 0, height)), V((0, 0.02, height * 1.02)), V((width / 2, 0, height))], [0.03, 0.035, 0.03],
		P["bark"], sides=6)
	for s in range(strands):
		x = -width / 2 + width * (s + 0.5) / strands
		ln = height * rng.uniform(0.55, 0.98)
		pts = [V((x + math.sin(t * 4 + s) * 0.04, 0.02 * math.cos(t * 3 + s), height - ln * t)) for t in (i / 6 for i in range(7))]
		L.tube(m, pts, [0.006] * 7, P["stem"], sides=3, cap_end=False)
		for k in range(1, 7):
			for sgn in (-1, 1):
				c = L.mix(_c(color), _c(color2), rng.random())
				L.leaf(m, pts[k], math.pi / 2 * sgn + rng.uniform(-0.6, 0.6) - math.pi / 2, rng.uniform(1.6, 2.2),
					0.09, 0.07, c, profile=L.petal_heart, nv=2)
		if s % 2 == 0:
			L.blossom(m, pts[3] + V((0, -0.03, 0)), V((0, -1, 0.2)), 5, 0.035, _c(flower), P["butter"], open_pitch=1.3,
				rng=rng, centre_size=0.25)


# --------------------------------------------------------------------------------------
# Trees
# --------------------------------------------------------------------------------------


def tree(m: Mesh, rng: random.Random, height: float = 8.0, trunk_r: float = 0.3, bark: str = "bark",
		canopy: str = "leaf", canopy2: str | None = None, canopy_r: float = 2.5, blobs: int = 5,
		branches: int = 3, flecks: str | None = None, fleck_count: int = 0, squash: float = 0.75,
		lean: float = 0.0, marks: str | None = None, style: str = "round", fruit_color: str | None = None,
		fruit_count: int = 0, bark_end: str | None = None, petals_ground: str | None = None) -> None:
	bark_c = _c(bark)
	if style == "dead":
		_dead_tree(m, rng, height, trunk_r, bark_c, _c(canopy))
		return
	trunk_h = height - canopy_r * squash * (1.3 if style != "willow" else 0.6)
	tips = L.branchy_trunk(m, trunk_h, trunk_r, bark_c, rng, branches=branches, lean=lean,
		twist=0.6 if style == "windswept" else 0.0, branch_len=0.32, branch_up=0.9 if style != "willow" else 0.5,
		color_end=_c(bark_end) if bark_end else None)
	if marks:  # birch lenticels
		for k in range(14):
			z = trunk_h * (0.08 + 0.8 * k / 14)
			a = rng.uniform(0, TAU)
			rr = trunk_r * (1.0 - 0.5 * z / trunk_h) * 1.02
			L.ellipsoid(m, V((math.cos(a) * rr, math.sin(a) * rr, z)), (trunk_r * 0.4, trunk_r * 0.4, trunk_r * 0.08),
				_c(marks), seg=5, rings=3, rot=L._rot_to(V((math.cos(a), math.sin(a), 0))))
	top = tips[0]
	cc = _c(canopy)
	cc2 = _c(canopy2) if canopy2 else None
	if style == "willow":
		ctr = top + V((0, 0, canopy_r * 0.3))
		L.canopy(m, ctr, canopy_r * 0.75, 3, cc, rng, color2=cc2, squash=0.55)
		for i in range(22):  # drooping curtains
			a = i * 2.39996323
			rr = canopy_r * rng.uniform(0.55, 0.95)
			start = ctr + V((math.cos(a) * rr * 0.7, math.sin(a) * rr * 0.7, canopy_r * 0.25))
			drop = (height - 0.6) * rng.uniform(0.6, 0.85)
			path = [start, start + V((math.cos(a) * rr * 0.4, math.sin(a) * rr * 0.4, canopy_r * 0.05)),
				start + V((math.cos(a) * rr * 0.55, math.sin(a) * rr * 0.55, -drop * 0.5)),
				start + V((math.cos(a) * rr * 0.6, math.sin(a) * rr * 0.6, -drop))]
			c = L.mix(cc, cc2, rng.random()) if cc2 else cc
			L.sheet(m, path[1], (path[3] - path[1]), V((-math.sin(a), math.cos(a), 0)), (path[3] - path[1]).length,
				canopy_r * 0.16, c, nu=1, nv=4, profile=L.blade_profile, cup=0.2,
				normal=V((math.cos(a), math.sin(a), 0)), curl=0.05)
			L.tube(m, path[:2], [0.03, 0.02], bark_c, sides=3, cap_end=False)
	else:
		sq = squash
		L.canopy(m, top + V((0, 0, canopy_r * sq * 0.45)), canopy_r, blobs, cc, rng, color2=cc2, squash=sq,
			flecks=_c(flecks) if flecks else None, fleck_count=fleck_count)
		for t in tips[1:]:
			r2 = canopy_r * rng.uniform(0.45, 0.6)
			L.canopy(m, t + V((0, 0, r2 * 0.3)), r2, 1, cc if not cc2 else L.mix(cc, cc2, 0.5), rng, squash=sq,
				flecks=_c(flecks) if flecks else None, fleck_count=fleck_count // 4, seg=8, rings=5)
	if fruit_color and fruit_count:
		for i in range(fruit_count):
			a = i * 2.39996323
			z = rng.uniform(-0.3, 0.4)
			p = top + V((0, 0, canopy_r * squash * 0.45)) + V((math.cos(a) * canopy_r * 0.95, math.sin(a) * canopy_r * 0.95,
				z * canopy_r * squash))
			L.ellipsoid(m, p, (canopy_r * 0.06,) * 3, L.jitter(rng, _c(fruit_color), 0.05), seg=5, rings=3)
	if petals_ground:  # fallen petal drift around the trunk
		for i in range(18):
			a = i * 2.39996323
			rr = canopy_r * 0.9 * math.sqrt((i + 0.5) / 18) + trunk_r
			p = V((math.cos(a) * rr, math.sin(a) * rr, 0.01))
			s = canopy_r * rng.uniform(0.05, 0.08)
			L.ellipsoid(m, p, (s, s * 0.8, 0.008), L.jitter(rng, _c(petals_ground), 0.06), seg=5, rings=2)


def _dead_tree(m: Mesh, rng: random.Random, height: float, r: float, bark_c: Sequence[float],
		accent: Sequence[float]) -> None:
	"""Twisted, leafless, grey blighted tree with clawing branches."""
	steps = 7
	path = []
	for i in range(steps + 1):
		t = i / steps
		path.append(V((math.sin(t * 4.2) * height * 0.06, math.cos(t * 3.1) * height * 0.05, height * 0.7 * t)))
	L.tube(m, path, [r * (1.4 if i == 0 else 1.0 - 0.6 * i / steps) for i in range(steps + 1)], bark_c, sides=7)
	for k in range(5):
		a = TAU * k / 5
		d = V((math.cos(a), math.sin(a), 0))
		L.tube(m, [d * r * 0.5 + V((0, 0, r)), d * r * 2.4 + V((0, 0, -0.05))], [r * 0.5, r * 0.1], bark_c, sides=4)

	def limb(start: Vector, d: Vector, ln: float, rad: float, depth: int) -> None:
		pts = [start]
		dd = d.normalized()
		for s in range(3):
			dd = (dd + V((rng.uniform(-.45, .45), rng.uniform(-.45, .45), rng.uniform(-.2, .3)))).normalized()
			pts.append(pts[-1] + dd * ln / 3)
		L.tube(m, pts, [rad, rad * 0.7, rad * 0.4, rad * 0.08], bark_c, sides=4 if depth else 5)
		if depth > 0:
			for c in range(2):
				nd = (dd + V((rng.uniform(-.9, .9), rng.uniform(-.9, .9), 0.2))).normalized()
				limb(pts[2 + c % 2], nd, ln * 0.6, rad * 0.45, depth - 1)

	for b in range(5):
		idx = 3 + b % 4
		a = b * 2.39996323
		limb(path[min(steps, idx)], V((math.cos(a), math.sin(a), 0.7)), height * 0.35, r * 0.45, 2)
	for k in range(4):  # dark hollows/fungus shelves
		L.ellipsoid(m, path[1 + k] + V((r * 0.7, 0, 0)), (r * 0.35, r * 0.5, r * 0.15), accent, seg=6, rings=3)


def thicket(m: Mesh, rng: random.Random, height: float = 1.6, radius: float = 1.2, cane: str = "blight_black",
		roses: str | None = None, rose_count: int = 0, rose_r: float = 0.12, canes: int = 14,
		leaf_color: str | None = None, withered: str | None = None) -> None:
	"""Thorn thicket / brake: arching thorny canes; optional roses (rosewild) or withered heads (blight)."""
	cc = _c(cane)
	tips: list[tuple[Vector, Vector]] = []
	for i in range(canes):
		a = i * 2.39996323 + rng.uniform(-0.2, 0.2)
		base = V((math.cos(a), math.sin(a), 0)) * radius * rng.uniform(0.0, 0.45)
		out = V((math.cos(a), math.sin(a), 0))
		h = height * rng.uniform(0.7, 1.05)
		pts = [base + out * radius * 0.6 * t * t + V((0, 0, h * math.sin(t * math.pi * 0.62) / math.sin(math.pi * 0.62)))
			for t in (k / 5 for k in range(6))]
		L.tube(m, pts, [radius * 0.035 * (1 - k / 7) for k in range(6)], cc, sides=5)
		for k in range(1, 6):
			p = pts[k]
			ta = rng.uniform(0, TAU)
			L.tube(m, [p, p + V((math.cos(ta), math.sin(ta), 0.2)).normalized() * radius * 0.07],
				[radius * 0.012, 0.0005], cc, sides=3, cap_end=False)
			if leaf_color and k % 2 == 0:
				L.leaf(m, p, ta + 1.4, 1.2, radius * 0.1, radius * 0.05, L.jitter(rng, _c(leaf_color), 0.06))
		tips.append((pts[-1], (pts[-1] - pts[-2]).normalized()))
	if roses:
		for i in range(rose_count):
			p, d = tips[i % len(tips)]
			if i >= len(tips):
				p = p - d * radius * 0.25 * (i // len(tips))
			up = (d + V((0, 0, 1.2))).normalized()
			L.rose_head(m, p, up, rose_r * rng.uniform(0.85, 1.15), L.jitter(rng, _c(roses), 0.06), rng)
	if withered:
		for i in range(min(len(tips), 8)):
			p, d = tips[i]
			L.blossom(m, p, (d - V((0, 0, 0.8))).normalized(), 5, rose_r, _c(withered), P["blight_black"],
				shape="pointed", open_pitch=0.5, cup=0.6, rng=rng, centre_size=0.25)


def blighted_petals(m: Mesh, rng: random.Random, count: int = 16, r: float = 0.18, color: str = "blight",
		color2: str = "blight_dark") -> None:
	"""Drift of fallen withered grey petals around a snapped dead stem."""
	L.tube(m, [V((0, 0, 0)), V((0.02, 0, 0.18)), V((0.07, 0.0, 0.14))], [0.006, 0.005, 0.003], P["blight_black"],
		sides=4)
	L.blossom(m, V((0.07, 0, 0.14)), V((0.5, 0, -1)), 4, 0.05, _c(color2), P["blight_black"], shape="pointed",
		open_pitch=0.6, cup=0.7, rng=rng, centre_size=0.2)
	for i in range(count):
		a = i * 2.39996323
		rr = r * math.sqrt((i + 0.5) / count)
		p = V((math.cos(a) * rr, math.sin(a) * rr, 0.004))
		yaw = rng.uniform(0, TAU)
		L.sheet(m, p, L.yaw_pitch(yaw, 1.45), L.side_of(yaw), 0.045, 0.02, L.mix(_c(color), _c(color2), rng.random()),
			nu=2, nv=2, cup=0.7, curl=0.3)


def leaf_drop(m: Mesh, rng: random.Random, count: int = 3, length: float = 0.14, color: str = "maple_red",
		color2: str | None = None, lobed: bool = False) -> None:
	"""Fallen leaves on the ground, slightly curled; lobed = maple star shape."""
	for i in range(count):
		base = _ring(rng, i, count, length * 0.6) + V((0, 0, 0.004 + 0.004 * i))
		yaw = rng.uniform(0, TAU)
		c = L.mix(_c(color), _c(color2), rng.random()) if color2 else _c(color)
		if lobed:
			for k in range(5):  # five lobes radiating from the stalk point
				ly = yaw + (k - 2) * 0.62
				L.sheet(m, base, L.yaw_pitch(ly, 1.48), L.side_of(ly), length * (1.0 - 0.18 * abs(k - 2)), length * 0.32,
					L.jitter(rng, c, 0.05), nu=2, nv=3, profile=L.petal_pointed, cup=0.15, curl=0.12)
		else:
			L.sheet(m, base, L.yaw_pitch(yaw, 1.48), L.side_of(yaw), length, length * 0.4, c, nu=2, nv=4,
				profile=L.leaf_profile, cup=0.3, curl=0.15, color_tip=L.mix(c, P["glow_white"], 0.35))
		L.tube(m, [base, base - L.yaw_pitch(yaw, 1.45) * length * 0.3], [0.0025, 0.0015], L.mix(c, P["bark"], 0.5),
			sides=3)


def hydrangea(m: Mesh, rng: random.Random, height: float = 1.1, radius: float = 0.7) -> None:
	"""Rounded leafy bush covered in big lilac/periwinkle puffball heads."""
	berry_shrub(m, rng, height=height * 0.85, radius=radius, leaf_color="leaf_deep", leaf_color2="leaf", berries=0,
		blobs=5)
	for i in range(9):
		a = i * 2.39996323
		z = 0.35 + 0.6 * ((i + 0.5) / 9)
		d = V((math.cos(a) * (1.1 - z), math.sin(a) * (1.1 - z), z)).normalized()
		p = V((0, 0, height * 0.47)) + V((d.x * radius * 0.8, d.y * radius * 0.8, d.z * height * 0.48))
		L.puff(m, p, radius * 0.22, 26, radius * 0.06, P["lilac"], rng, color2=P["periwinkle"])
