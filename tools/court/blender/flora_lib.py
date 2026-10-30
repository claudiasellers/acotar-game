"""Geometry helpers and parametric archetype builders for the wider Spring Court flora.

Everything is built in a single bmesh per asset (Blender Z-up, metres, origin at the base
centre on the ground). Colours go in a float corner colour layer: RGB linear, alpha =
emissive strength (1.0 on glowing parts, 0.0 otherwise). Randomness only comes from the
`random.Random` instance passed in, which the generator seeds per asset id.
"""

from __future__ import annotations

import math
import random
from typing import Callable, Sequence

import bpy  # noqa: F401  (loads bmesh/mathutils in the bpy module build)
import bmesh
from mathutils import Matrix, Vector

TAU: float = math.tau

# --------------------------------------------------------------------------------------
# Colour
# --------------------------------------------------------------------------------------


def _srgb_to_linear(c: float) -> float:
	return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def hexc(code: str) -> tuple[float, float, float]:
	code = code.lstrip("#")
	return tuple(_srgb_to_linear(int(code[i:i + 2], 16) / 255.0) for i in (0, 2, 4))  # type: ignore[return-value]


def mix(a: Sequence[float], b: Sequence[float], t: float) -> tuple[float, float, float]:
	return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t)


def jitter(rng: random.Random, c: Sequence[float], amount: float = 0.08) -> tuple[float, float, float]:
	k = 1.0 + rng.uniform(-amount, amount)
	return (min(1.0, c[0] * k), min(1.0, c[1] * k), min(1.0, c[2] * k))


# Palette (sRGB hex -> linear). Candy pastels for the court; greys for the blight;
# reds/golds for the autumn foothills.
P: dict[str, tuple[float, float, float]] = {k: hexc(v) for k, v in {
	"rose": "#ff5fa2", "rose_deep": "#e8326f", "rose_red": "#e5243f", "blush": "#ffb3cf",
	"pearl": "#fff6f0", "white": "#fffdf8", "cream": "#fff1c9", "butter": "#ffe07a",
	"gold": "#f5c542", "gold_deep": "#d9a21b", "lilac": "#c9a0f0", "lilac_deep": "#a173d9",
	"lavender": "#9b7be0", "periwinkle": "#8fa8ff", "sky": "#9fd6ff", "mint": "#9df0c8",
	"leaf": "#5fcf7a", "leaf_light": "#8ee68f", "leaf_deep": "#2f9e5a", "sage": "#9cc7a0",
	"moss": "#4fbf6b", "teal_leaf": "#3fb89a", "stem": "#4cae5c", "bark": "#8a5a44",
	"bark_light": "#b88466", "bark_dark": "#5e3b2e", "birch": "#f4efe8", "birch_mark": "#4a3f3f",
	"pearl_bark": "#e9dcef", "earth": "#8f6a4f", "peach": "#ffb08a", "coral": "#ff7f6e",
	"cherry": "#d81e4a", "plum": "#7a3fa0", "berry_blue": "#4b5fc9", "blackberry": "#3a1f4f",
	"strawberry": "#ff3355", "orange": "#ff9a3c", "amber": "#ff8a1f", "crimson": "#c8102e",
	"maple_red": "#e0301e", "autumn_gold": "#ffb627", "rust": "#b5531f", "sloe": "#3d3a7a",
	"quince": "#f7d34a", "apple_red": "#ff4d5e", "apple_green": "#b8e05a", "honeyplum": "#ffa64d",
	"hazel": "#b07a3c", "violet": "#7f4fd6", "cornflower": "#5a7dff", "poppy": "#ff3b30",
	"blue_woad": "#4f7fd9", "madder": "#d9435e", "water": "#5fb7d9", "lily_pad": "#4fc28a",
	"silver": "#d8e2ec", "silver_deep": "#a9b8c8", "glow_white": "#f4fbff", "glow_blue": "#a8e4ff",
	"glow_mint": "#b9ffe0", "glow_gold": "#fff0a8", "moon": "#f2f0ff",
	"blight": "#6b6b70", "blight_dark": "#3a3a40", "blight_black": "#222226", "ash_grey": "#9a9a9e",
	"lichen": "#a7aaa2", "stone": "#c9c3cf", "nightshade": "#3b1d4f", "nightshade_berry": "#1e1028",
	"web": "#f3f6ff", "garlic": "#f8fbf0", "sorrel": "#9fe08a", "nettle": "#3f9a4a",
	"mugwort": "#8fae9a", "juniper": "#3d7f6a", "juniper_berry": "#5c6fb0", "heather": "#d18ce6",
}.items()}


# --------------------------------------------------------------------------------------
# Mesh builder
# --------------------------------------------------------------------------------------


class Mesh:
	"""Accumulates geometry with per-corner colour (alpha = glow)."""

	def __init__(self) -> None:
		self.bm: bmesh.types.BMesh = bmesh.new()
		self.col = self.bm.loops.layers.float_color.new("Color")

	def _face(self, verts: Sequence[bmesh.types.BMVert], color: Sequence[float], glow: float) -> None:
		f = self.bm.faces.new(verts)
		f.smooth = True
		rgba = (color[0], color[1], color[2], glow)
		for loop in f.loops:
			loop[self.col] = rgba

	def grid(self, pts: list[list[Vector]], color: Sequence[float], glow: float = 0.0,
			close_u: bool = False, flip: bool = False) -> None:
		"""pts[v][u] grid of positions -> quads."""
		rows = [[self.bm.verts.new(p) for p in row] for row in pts]
		nv = len(rows)
		nu = len(rows[0])
		umax = nu if close_u else nu - 1
		for j in range(nv - 1):
			for i in range(umax):
				i2 = (i + 1) % nu
				q = [rows[j][i], rows[j][i2], rows[j + 1][i2], rows[j + 1][i]]
				if flip:
					q.reverse()
				# Skip degenerate quads that collapse to a point on one side.
				if (q[0].co - q[1].co).length < 1e-7 and (q[2].co - q[3].co).length < 1e-7:
					continue
				self._face(q, color, glow)

	def fan_cap(self, ring: list[Vector], centre: Vector, color: Sequence[float], glow: float = 0.0,
			flip: bool = False) -> None:
		c = self.bm.verts.new(centre)
		vs = [self.bm.verts.new(p) for p in ring]
		n = len(vs)
		for i in range(n):
			tri = [c, vs[i], vs[(i + 1) % n]]
			if flip:
				tri.reverse()
			self._face(tri, color, glow)

	def finish(self) -> bmesh.types.BMesh:
		bmesh.ops.remove_doubles(self.bm, verts=self.bm.verts[:], dist=1e-6)
		bmesh.ops.triangulate(self.bm, faces=self.bm.faces[:])
		bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces[:])
		return self.bm


# --------------------------------------------------------------------------------------
# Primitive shapes
# --------------------------------------------------------------------------------------


def _frame(direction: Vector) -> tuple[Vector, Vector, Vector]:
	d = direction.normalized()
	ref = Vector((0, 0, 1)) if abs(d.z) < 0.95 else Vector((1, 0, 0))
	s = d.cross(ref).normalized()
	n = s.cross(d).normalized()
	return d, s, n


def ellipsoid(m: Mesh, centre: Vector, radii: Sequence[float], color: Sequence[float], glow: float = 0.0,
		seg: int = 10, rings: int = 6, rng: random.Random | None = None, noise: float = 0.0,
		rot: Matrix | None = None, flat_bottom: bool = False) -> None:
	"""UV ellipsoid built from a lathe so poles are single verts."""
	pts: list[list[Vector]] = []
	offsets: list[float] = []
	if rng is not None and noise > 0.0:
		offsets = [rng.uniform(-noise, noise) for _ in range((rings + 1) * seg)]
	for j in range(rings + 1):
		phi = math.pi * j / rings
		z = -math.cos(phi)
		r = 0.0 if j in (0, rings) else math.sin(phi)
		if flat_bottom and z < -0.2:
			z = -0.2 - (z + 0.2) * 0.25
		row: list[Vector] = []
		for i in range(seg):
			th = TAU * i / seg
			k = 1.0
			if offsets and 0 < j < rings:
				k += offsets[j * seg + i]
			v = Vector((math.cos(th) * r * radii[0] * k, math.sin(th) * r * radii[1] * k, z * radii[2] * k))
			if rot is not None:
				v = rot @ v
			row.append(centre + v)
		pts.append(row)
	m.grid(pts, color, glow, close_u=True)


def lathe(m: Mesh, base: Vector, profile: Sequence[tuple[float, float]], color: Sequence[float],
		glow: float = 0.0, seg: int = 10, axis: Vector | None = None, wobble: float = 0.0,
		rng: random.Random | None = None, lobes: int = 0, lobe_amp: float = 0.0) -> None:
	"""Surface of revolution. profile = [(radius, height), ...] bottom to top."""
	d, s, n = _frame(axis if axis is not None else Vector((0, 0, 1)))
	pts: list[list[Vector]] = []
	ph = rng.uniform(0, TAU) if rng is not None else 0.0
	for r, h in profile:
		row: list[Vector] = []
		for i in range(seg):
			th = TAU * i / seg
			rr = r
			if lobes:
				rr *= 1.0 + lobe_amp * math.cos(lobes * th)
			if wobble and rng is not None:
				rr *= 1.0 + wobble * math.sin(3 * th + ph + h * 7.0)
			row.append(base + d * h + s * (math.cos(th) * rr) + n * (math.sin(th) * rr))
		pts.append(row)
	m.grid(pts, color, glow, close_u=True)


def tube(m: Mesh, path: Sequence[Vector], radii: Sequence[float], color: Sequence[float], glow: float = 0.0,
		sides: int = 6, cap_end: bool = True, color_end: Sequence[float] | None = None) -> None:
	"""Tapered tube along a polyline with a parallel-transported frame."""
	count = len(path)
	tangents: list[Vector] = []
	for i in range(count):
		a = path[max(0, i - 1)]
		b = path[min(count - 1, i + 1)]
		tangents.append((b - a).normalized())
	_, s, n = _frame(tangents[0])
	rings: list[list[Vector]] = []
	prev_t = tangents[0]
	for i in range(count):
		t = tangents[i]
		if i > 0:
			axis = prev_t.cross(t)
			if axis.length > 1e-6:
				ang = prev_t.angle(t)
				rmat = Matrix.Rotation(ang, 3, axis.normalized())
				s = (rmat @ s).normalized()
				n = (rmat @ n).normalized()
			prev_t = t
		r = radii[i]
		rings.append([path[i] + s * (math.cos(TAU * k / sides) * r) + n * (math.sin(TAU * k / sides) * r)
			for k in range(sides)])
	if color_end is None:
		m.grid(rings, color, glow, close_u=True)
	else:
		half = count // 2
		m.grid(rings[:half + 1], color, glow, close_u=True)
		m.grid(rings[half:], color_end, glow, close_u=True)
	if cap_end and radii[-1] > 0.0005:
		m.fan_cap(rings[-1], path[-1] + tangents[-1] * radii[-1] * 0.5, color_end or color, glow)


def curve_path(start: Vector, direction: Vector, length: float, bend: Vector, steps: int) -> list[Vector]:
	"""Quadratic path: start + dir*L*t + bend*t^2."""
	d = direction.normalized()
	return [start + d * (length * t) + bend * (t * t) for t in (i / steps for i in range(steps + 1))]


def sheet(m: Mesh, base: Vector, forward: Vector, side: Vector, length: float, width: float,
		color: Sequence[float], glow: float = 0.0, nu: int = 2, nv: int = 4,
		profile: Callable[[float], float] | None = None, cup: float = 0.0, curl: float = 0.0,
		normal: Vector | None = None, color_tip: Sequence[float] | None = None, thickness: float = 0.003) -> None:
	"""Double-sided curved sheet (petal, leaf, blade). u across [-1,1], v along [0,1]."""
	f = forward.normalized()
	s = side.normalized()
	nrm = normal.normalized() if normal is not None else f.cross(s).normalized()
	prof = profile or petal_round
	front: list[list[Vector]] = []
	for j in range(nv + 1):
		v = j / nv
		w = prof(v) * width
		row: list[Vector] = []
		for i in range(nu + 1):
			u = -1.0 + 2.0 * i / nu
			p = base + f * (v * length) + s * (u * w) + nrm * (cup * (u * u) * w + curl * v * v * length)
			row.append(p)
		front.append(row)
	back = [[p - nrm * thickness for p in row] for row in front]
	if color_tip is None:
		m.grid(front, color, glow)
		m.grid(back, color, glow, flip=True)
	else:
		half = (nv + 1) // 2
		m.grid(front[:half + 1], color, glow)
		m.grid(front[half:], color_tip, glow)
		m.grid(back[:half + 1], color, glow, flip=True)
		m.grid(back[half:], color_tip, glow, flip=True)


def petal_round(v: float) -> float:
	return math.sin(math.pi * min(1.0, v * 0.92 + 0.04)) ** 0.55 * (0.35 + 0.65 * v ** 0.4)


def petal_pointed(v: float) -> float:
	return math.sin(math.pi * v) ** 1.1 * (1.0 - 0.35 * v)


def petal_heart(v: float) -> float:
	return math.sin(math.pi * min(1.0, v * 0.85 + 0.08)) ** 0.5 * (0.3 + 0.7 * v ** 0.5)


def blade_profile(v: float) -> float:
	return (1.0 - v) ** 0.8 + 0.02


def leaf_profile(v: float) -> float:
	return math.sin(math.pi * v) ** 0.8


def yaw_pitch(yaw: float, pitch: float) -> Vector:
	"""Direction: pitch measured from +Z, yaw around Z."""
	return Vector((math.sin(pitch) * math.cos(yaw), math.sin(pitch) * math.sin(yaw), math.cos(pitch)))


def side_of(yaw: float) -> Vector:
	return Vector((-math.sin(yaw), math.cos(yaw), 0.0))


# --------------------------------------------------------------------------------------
# Plant parts
# --------------------------------------------------------------------------------------


def leaf(m: Mesh, base: Vector, yaw: float, pitch: float, length: float, width: float,
		color: Sequence[float], curl: float = -0.25, nv: int = 3, profile: Callable[[float], float] | None = None,
		glow: float = 0.0) -> None:
	f = yaw_pitch(yaw, pitch)
	sheet(m, base, f, side_of(yaw), length, width, color, glow, nu=2, nv=nv,
		profile=profile or leaf_profile, cup=0.25, curl=curl)


def stem(m: Mesh, base: Vector, top: Vector, radius: float, color: Sequence[float], lean: Vector | None = None,
		sides: int = 5, steps: int = 3) -> list[Vector]:
	d = top - base
	bend = lean if lean is not None else Vector((0, 0, 0))
	path = curve_path(base, d, d.length, bend, steps)
	path[-1] = top + bend
	tube(m, path, [radius * (1.0 - 0.3 * i / steps) for i in range(steps + 1)], color, sides=sides, cap_end=False)
	return path


def blossom(m: Mesh, centre: Vector, axis: Vector, petals: int, radius: float, color: Sequence[float],
		centre_color: Sequence[float], shape: str = "round", open_pitch: float = 1.15, cup: float = 0.25,
		layers: int = 1, rng: random.Random | None = None, glow: float = 0.0, centre_glow: float = 0.0,
		tip_color: Sequence[float] | None = None, nv: int = 3, centre_size: float = 0.22) -> None:
	"""Radial flower head: petals around `axis`, plus a domed centre."""
	d, s, n = _frame(axis)
	prof = {"round": petal_round, "pointed": petal_pointed, "heart": petal_heart}.get(shape, petal_round)
	for layer in range(layers):
		lt = layer / max(1, layers - 1) if layers > 1 else 0.0
		count = petals if layer == 0 else max(3, petals - layer)
		pitch = open_pitch - lt * (open_pitch - 0.35)
		length = radius * (1.0 - 0.32 * lt)
		off = (layer * 0.5) / count * TAU + (rng.uniform(0, 0.4) if rng else 0.0)
		for k in range(count):
			th = off + TAU * k / count
			radial = s * math.cos(th) + n * math.sin(th)
			fwd = (d * math.cos(pitch) + radial * math.sin(pitch)).normalized()
			sd = d.cross(radial).normalized()
			if rng is not None:
				lj = length * rng.uniform(0.9, 1.08)
			else:
				lj = length
			sheet(m, centre + d * (0.04 * radius * layer), fwd, sd, lj, lj * 0.42, color, glow, nu=2, nv=nv,
				profile=prof, cup=cup, curl=-0.12 if layer == 0 else 0.1,
				normal=fwd.cross(sd), color_tip=tip_color)
	if centre_size > 0:
		cr = radius * centre_size
		ellipsoid(m, centre + d * (cr * 0.3), (cr, cr, cr * 0.7), centre_color, centre_glow, seg=8, rings=4,
			rot=_rot_to(d))


def _rot_to(direction: Vector) -> Matrix:
	return Vector((0, 0, 1)).rotation_difference(direction.normalized()).to_matrix()


def rose_head(m: Mesh, centre: Vector, axis: Vector, radius: float, color: Sequence[float], rng: random.Random,
		inner: Sequence[float] | None = None, glow: float = 0.0) -> None:
	"""Oversized cabbage-rose: three petal layers cupped around a bud."""
	blossom(m, centre, axis, 6, radius, color, inner or color, shape="round", open_pitch=1.25, cup=0.55,
		layers=3, rng=rng, centre_size=0.0, glow=glow, tip_color=mix(color, P["pearl"], 0.25), nv=3)
	ellipsoid(m, centre + axis.normalized() * radius * 0.25, (radius * 0.33, radius * 0.33, radius * 0.4),
		inner or mix(color, P["rose_deep"], 0.3), glow, seg=8, rings=5, rot=_rot_to(axis))
	d, s, n = _frame(axis)
	for k in range(5):  # sepals
		th = TAU * k / 5 + 0.3
		radial = s * math.cos(th) + n * math.sin(th)
		fwd = (-d * 0.35 + radial).normalized()
		sheet(m, centre - d * radius * 0.05, fwd, d.cross(radial), radius * 0.45, radius * 0.12, P["leaf_deep"],
			profile=petal_pointed, nv=2, nu=1)


def bell(m: Mesh, mouth_centre: Vector, axis: Vector, radius: float, length: float, color: Sequence[float],
		inner: Sequence[float] | None = None, seg: int = 7, flare: float = 1.25, glow: float = 0.0,
		lobes: int = 5) -> None:
	"""Bell / trumpet: axis points from the attachment point towards the mouth."""
	a = axis.normalized()
	base = mouth_centre - a * length
	prof = [(radius * 0.15, 0.0), (radius * 0.55, length * 0.3), (radius * 0.85, length * 0.7),
		(radius * flare, length)]
	lathe(m, base, prof, color, glow, seg=seg, axis=a, lobes=lobes, lobe_amp=0.12)
	inner_prof = [(radius * flare * 0.96, length - 0.002), (radius * 0.7, length * 0.6), (radius * 0.12, length * 0.1)]
	lathe(m, base, inner_prof, inner or mix(color, P["pearl"], 0.4), glow, seg=seg, axis=a, lobes=lobes,
		lobe_amp=0.12)


def bead_spike(m: Mesh, base: Vector, length: float, count: int, bead: float, color: Sequence[float],
		rng: random.Random, color_top: Sequence[float] | None = None, glow: float = 0.0,
		lean: Vector | None = None, around: int = 3) -> None:
	"""Spike of small beads/florets along a stem (lavender, heather, hyacinth)."""
	ln = lean if lean is not None else Vector((0, 0, 0))
	for i in range(count):
		t = i / max(1, count - 1)
		c = mix(color, color_top, t) if color_top is not None else color
		for a in range(around):
			th = TAU * a / around + i * 1.1
			rr = bead * (1.0 - 0.5 * t) * 0.9
			p = base + Vector((0, 0, length * t)) + ln * t * t + Vector((math.cos(th) * rr, math.sin(th) * rr, 0))
			r = bead * (1.0 - 0.45 * t) * rng.uniform(0.85, 1.1)
			ellipsoid(m, p, (r, r, r * 1.15), c, glow, seg=5, rings=3)


def umbel(m: Mesh, centre: Vector, radius: float, florets: int, floret_r: float, color: Sequence[float],
		rng: random.Random, dome: float = 0.4, glow: float = 0.0) -> None:
	"""Flat-topped dome of tiny florets (yarrow, elderflower, meadowsweet)."""
	for i in range(florets):
		a = i * 2.39996323
		r = radius * math.sqrt((i + 0.5) / florets)
		h = dome * radius * (1.0 - (r / radius) ** 2)
		p = centre + Vector((math.cos(a) * r, math.sin(a) * r, h))
		fr = floret_r * rng.uniform(0.85, 1.15)
		ellipsoid(m, p, (fr, fr, fr * 0.8), jitter(rng, color, 0.05), glow, seg=5, rings=3)


def puff(m: Mesh, centre: Vector, radius: float, florets: int, floret_r: float, color: Sequence[float],
		rng: random.Random, color2: Sequence[float] | None = None, glow: float = 0.0) -> None:
	"""Ball of florets (hydrangea, clover)."""
	ellipsoid(m, centre, (radius * 0.85,) * 3, mix(color, P["leaf_deep"], 0.15), 0.0, seg=8, rings=5)
	for i in range(florets):
		y = 1.0 - 2.0 * (i + 0.5) / florets
		if y < -0.45:
			continue
		rr = math.sqrt(1 - y * y)
		a = i * 2.39996323
		p = centre + Vector((math.cos(a) * rr, math.sin(a) * rr, y)) * radius
		c = mix(color, color2, rng.random()) if color2 is not None else jitter(rng, color, 0.06)
		fr = floret_r * rng.uniform(0.85, 1.15)
		ellipsoid(m, p, (fr, fr, fr), c, glow, seg=5, rings=3)


def berry_cluster(m: Mesh, centre: Vector, count: int, r: float, color: Sequence[float], rng: random.Random,
		spread: float = 1.0, glow: float = 0.0, drupelets: bool = False) -> None:
	for i in range(count):
		off = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-0.6, 0.6))) * r * spread * 1.4
		rr = r * rng.uniform(0.85, 1.1)
		if drupelets:  # blackberry: lumpy elongated
			ellipsoid(m, centre + off, (rr, rr, rr * 1.3), color, glow, seg=6, rings=4, rng=rng, noise=0.12)
		else:
			ellipsoid(m, centre + off, (rr, rr, rr), jitter(rng, color, 0.06), glow, seg=6, rings=4)


def tuft(m: Mesh, base: Vector, count: int, height: float, width: float, color: Sequence[float],
		rng: random.Random, tip: Sequence[float] | None = None, spread: float = 0.5, radius: float = 0.03,
		nv: int = 3) -> None:
	"""Clump of curved blades."""
	for i in range(count):
		yaw = rng.uniform(0, TAU)
		pitch = rng.uniform(0.05, spread)
		h = height * rng.uniform(0.65, 1.1)
		p = base + Vector((math.cos(yaw), math.sin(yaw), 0)) * rng.uniform(0, radius)
		sheet(m, p, yaw_pitch(yaw, pitch), side_of(yaw), h, width * rng.uniform(0.8, 1.2), jitter(rng, color, 0.07),
			nu=1, nv=nv, profile=blade_profile, cup=0.15, curl=0.12 + pitch * 0.5,
			color_tip=tip)


def rosette(m: Mesh, base: Vector, count: int, length: float, width: float, color: Sequence[float],
		rng: random.Random, pitch: float = 1.15, profile: Callable[[float], float] | None = None) -> None:
	for i in range(count):
		yaw = TAU * i / count + rng.uniform(-0.2, 0.2)
		leaf(m, base + Vector((0, 0, 0.005)), yaw, pitch + rng.uniform(-0.15, 0.15), length * rng.uniform(0.8, 1.1),
			width, jitter(rng, color, 0.06), curl=-0.2, profile=profile)


def mushroom(m: Mesh, base: Vector, height: float, cap_r: float, cap_color: Sequence[float],
		stem_color: Sequence[float], rng: random.Random, shape: str = "dome", spots: Sequence[float] | None = None,
		glow: float = 0.0, stem_glow: float = 0.0, tilt: Vector | None = None, seg: int = 10) -> None:
	ax = (Vector((0, 0, 1)) + (tilt or Vector((0, 0, 0)))).normalized()
	sr = cap_r * 0.28
	if shape == "funnel":  # chanterelle: stem flares into a wavy funnel
		prof = [(sr * 0.9, 0.0), (sr, height * 0.4), (cap_r * 0.6, height * 0.8), (cap_r, height), (cap_r * 0.92, height * 1.02),
			(cap_r * 0.5, height * 0.92), (0.001, height * 0.85)]
		lathe(m, base, prof, cap_color, glow, seg=seg, axis=ax, wobble=0.12, rng=rng)
		return
	lathe(m, base, [(sr * 1.15, 0.0), (sr, height * 0.5), (sr * 0.85, height * 0.95)], stem_color, stem_glow, seg=7, axis=ax)
	top = base + ax * height
	if shape == "cone":  # dreamcap / glowcap
		prof = [(0.001, -cap_r * 0.1), (cap_r * 0.9, -cap_r * 0.05), (cap_r, cap_r * 0.05), (cap_r * 0.75, cap_r * 0.45),
			(cap_r * 0.35, cap_r * 0.95), (0.001, cap_r * 1.2)]
	else:
		prof = [(0.001, -cap_r * 0.05), (cap_r * 0.92, -cap_r * 0.12), (cap_r, 0.0), (cap_r * 0.92, cap_r * 0.3),
			(cap_r * 0.62, cap_r * 0.58), (0.001, cap_r * 0.7)]
	lathe(m, top, prof, cap_color, glow, seg=seg, axis=ax, wobble=0.04, rng=rng)
	if spots is not None:
		for k in range(9):
			th = k * 2.39996323
			phi = 0.25 + 0.75 * ((k + 0.5) / 9)
			v = Vector((math.cos(th) * math.sin(phi) * cap_r * 0.86, math.sin(th) * math.sin(phi) * cap_r * 0.86,
				math.cos(phi) * cap_r * 0.62))
			sz = cap_r * rng.uniform(0.09, 0.14)
			ellipsoid(m, top + v, (sz, sz, sz * 0.5), spots, glow, seg=5, rings=3, rot=_rot_to(v))


def fruit(m: Mesh, base: Vector, radius: float, color: Sequence[float], rng: random.Random, kind: str = "apple",
		blush_color: Sequence[float] | None = None, glow: float = 0.0) -> Vector:
	"""Lathe fruit sitting on the ground. Returns the stalk top."""
	r = radius
	if kind == "apple":
		prof = [(0.001, r * 0.18), (r * 0.6, 0.02 * r), (r * 0.95, r * 0.5), (r, r * 0.95), (r * 0.85, r * 1.45),
			(r * 0.45, r * 1.7), (0.001, r * 1.55)]
	elif kind == "pear":  # quince
		prof = [(0.001, 0.0), (r * 0.7, r * 0.08), (r, r * 0.6), (r * 0.85, r * 1.2), (r * 0.55, r * 1.65),
			(r * 0.4, r * 1.95), (0.001, r * 2.0)]
	elif kind == "plum":
		prof = [(0.001, 0.0), (r * 0.7, r * 0.15), (r * 0.98, r * 0.75), (r * 0.95, r * 1.35), (r * 0.6, r * 1.8),
			(0.001, r * 1.9)]
	elif kind == "nut":  # hazelnut: rounded body + shaggy husk
		prof = [(0.001, 0.0), (r * 0.8, r * 0.2), (r, r * 0.8), (r * 0.7, r * 1.45), (0.001, r * 1.7)]
	elif kind == "heart":  # strawberry
		prof = [(0.001, 0.0), (r * 0.45, r * 0.25), (r * 0.85, r * 0.9), (r, r * 1.4), (r * 0.55, r * 1.7), (0.001, r * 1.72)]
	else:
		prof = [(0.001, 0.0), (r * 0.7, r * 0.15), (r, r), (r * 0.7, r * 1.85), (0.001, r * 2.0)]
	top_h = prof[-1][1]
	lathe(m, base, prof, color, glow, seg=10, wobble=0.03, rng=rng)
	if blush_color is not None:
		ellipsoid(m, base + Vector((r * 0.55, -r * 0.4, top_h * 0.55)), (r * 0.42, r * 0.42, r * 0.5), blush_color,
			seg=6, rings=4)
	return base + Vector((0, 0, top_h))


def canopy(m: Mesh, centre: Vector, radius: float, blobs: int, color: Sequence[float], rng: random.Random,
		color2: Sequence[float] | None = None, squash: float = 0.75, spread: float = 0.75, seg: int = 9,
		rings: int = 6, flecks: Sequence[float] | None = None, fleck_count: int = 0) -> None:
	"""Rounded blob canopy: one core blob + satellites; optional blossom flecks."""
	ellipsoid(m, centre, (radius, radius, radius * squash), color, seg=seg + 1, rings=rings, rng=rng, noise=0.06)
	pts: list[tuple[Vector, float]] = [(centre, radius)]
	for i in range(blobs):
		a = i * 2.39996323 + rng.uniform(-0.3, 0.3)
		el = rng.uniform(-0.35, 0.6)
		d = Vector((math.cos(a) * math.cos(el), math.sin(a) * math.cos(el), math.sin(el) * squash))
		r = radius * rng.uniform(0.5, 0.72)
		p = centre + d * radius * spread
		c = mix(color, color2, rng.random()) if color2 is not None else jitter(rng, color, 0.07)
		ellipsoid(m, p, (r, r, r * squash), c, seg=seg, rings=rings - 1, rng=rng, noise=0.08)
		pts.append((p, r))
	if flecks is not None:
		for i in range(fleck_count):
			p, r = pts[i % len(pts)]
			th = rng.uniform(0, TAU)
			z = rng.uniform(-0.2, 0.95)
			rr = math.sqrt(max(0.0, 1 - z * z))
			q = p + Vector((math.cos(th) * rr * r, math.sin(th) * rr * r, z * r * squash)) * 1.01
			fr = radius * rng.uniform(0.07, 0.11)
			ellipsoid(m, q, (fr, fr, fr * 0.7), jitter(rng, flecks, 0.05), seg=5, rings=3)


def branchy_trunk(m: Mesh, height: float, radius: float, color: Sequence[float], rng: random.Random,
		branches: int = 3, lean: float = 0.0, twist: float = 0.0, sides: int = 8, branch_len: float = 0.45,
		branch_up: float = 0.6, color_end: Sequence[float] | None = None) -> list[Vector]:
	"""Tapered trunk with flared roots + branches. Returns branch tip positions (plus the trunk top)."""
	steps = 6
	lean_dir = Vector((math.cos(rng.uniform(0, TAU)), math.sin(rng.uniform(0, TAU)), 0)) * lean
	path = []
	for i in range(steps + 1):
		t = i / steps
		wob = Vector((math.sin(t * 5.0 + twist) * twist * 0.15, math.cos(t * 4.0 + twist) * twist * 0.15, 0)) * height * 0.1
		path.append(Vector((0, 0, height * t)) + lean_dir * height * t * t + wob)
	radii = [radius * (1.35 if i == 0 else 1.0 - 0.55 * (i / steps)) for i in range(steps + 1)]
	tube(m, path, radii, color, sides=sides, color_end=color_end)
	# Root flares
	for k in range(4):
		a = TAU * k / 4 + rng.uniform(-0.3, 0.3)
		d = Vector((math.cos(a), math.sin(a), 0))
		tube(m, [Vector((0, 0, radius * 0.9)) + d * radius * 0.3, d * radius * 1.6 + Vector((0, 0, 0.02))],
			[radius * 0.5, radius * 0.15], color, sides=4)
	tips = [path[-1]]
	for b in range(branches):
		t = 0.5 + 0.4 * (b / max(1, branches - 1)) if branches > 1 else 0.7
		idx = min(steps - 1, int(t * steps))
		start = path[idx]
		a = b * 2.39996323 + rng.uniform(-0.4, 0.4)
		d = Vector((math.cos(a), math.sin(a), branch_up)).normalized()
		ln = height * branch_len * rng.uniform(0.8, 1.15)
		bp = curve_path(start, d, ln, Vector((0, 0, ln * 0.2 * branch_up)), 3)
		tube(m, bp, [radii[idx] * 0.55, radii[idx] * 0.4, radii[idx] * 0.28, radii[idx] * 0.15], color, sides=5)
		tips.append(bp[-1])
	return tips
