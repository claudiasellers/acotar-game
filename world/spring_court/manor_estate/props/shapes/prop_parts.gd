## Reusable prop pieces built into a PropMeshKit: legs, cushions, drawers, book
## rows, candles, frames, scrolls. Coordinates in metres, base at y = 0, front -Z.
class_name PropParts
extends RefCounted


static func rng(id: StringName) -> RandomNumberGenerator:
	return EstateKit.rng("prop:" + String(id))


## A turned (lathe) leg: foot, slim shaft, bead, collar.
static func turned_leg(k: PropMeshKit, m: Material, pos: Vector3, h: float, r: float) -> void:
	k.lathe(m, pos, PackedVector2Array([Vector2(0, 0), Vector2(r * 0.9, 0), Vector2(r * 1.1, h * 0.06),
			Vector2(r * 0.55, h * 0.18), Vector2(r * 0.7, h * 0.5), Vector2(r * 1.1, h * 0.6),
			Vector2(r * 0.7, h * 0.7), Vector2(r, h * 0.92), Vector2(r, h), Vector2(0, h)]), 8)


## A curved cabriole leg as a tapering tube with a little gold foot.
static func cabriole_leg(k: PropMeshKit, m: Material, pos: Vector3, h: float, r: float, out: Vector3) -> void:
	var o := Vector3(out.x, 0, out.z).normalized() * h * 0.12
	var pts := PackedVector3Array()
	for i in 6:
		var t := float(i) / 5.0
		var bow := sin(t * PI) * 0.6 - (1.0 - t) * 0.5
		pts.append(pos + Vector3(0, h * t, 0) + o * bow)
	k.tube(m, pts, r * 0.6, 6, Transform3D.IDENTITY, r)
	k.sphere(PropMats.gold(), pos + Vector3(0, r * 0.4, 0) - o * 0.5, Vector3.ONE * r * 0.75, 6, 3)


## Four legs under a w x d top at height h.
static func legs4(k: PropMeshKit, m: Material, w: float, d: float, h: float, r: float,
		style: int = 0, inset: float = -1.0) -> void:
	var ins := r * 1.6 if inset < 0.0 else inset
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var p := Vector3(sx * (w * 0.5 - ins), 0, sz * (d * 0.5 - ins))
			match style:
				0: turned_leg(k, m, p, h, r)
				1: cabriole_leg(k, m, p, h, r, Vector3(sx, 0, sz))
				_: k.box(m, p + Vector3(0, h * 0.5, 0), Vector3(r * 2, h, r * 2))


## A plump cushion: a flattened ellipsoid.
static func cushion(k: PropMeshKit, m: Material, center: Vector3, size: Vector3,
		t: Transform3D = Transform3D.IDENTITY) -> void:
	k.sphere(m, center, size * 0.5, 10, 6, t)


## A slab with a rounded front lip (table tops, seats).
static func slab(k: PropMeshKit, m: Material, center: Vector3, size: Vector3, trim: Material = null) -> void:
	k.box(m, center, size)
	if trim:
		k.box(trim, center + Vector3(0, -size.y * 0.5 - 0.012, 0), Vector3(size.x * 0.96, 0.025, size.z * 0.96))


## A grid of drawer fronts with knobs on the -Z face at z_front.
static func drawers(k: PropMeshKit, front: Material, knob: Material, x0: float, x1: float,
		y0: float, y1: float, z_front: float, rows: int, cols: int = 1) -> void:
	var gap := 0.02
	var cw := (x1 - x0) / cols
	var rh := (y1 - y0) / rows
	for r in rows:
		for c in cols:
			var cx := x0 + cw * (c + 0.5)
			var cy := y0 + rh * (r + 0.5)
			k.box(front, Vector3(cx, cy, z_front - 0.01), Vector3(cw - gap, rh - gap, 0.02))
			k.sphere(knob, Vector3(cx, cy, z_front - 0.035), Vector3.ONE * minf(0.025, rh * 0.15), 6, 3)


## A row of coloured book spines between x0 and x1 standing on y, spines at z_front.
static func books(k: PropMeshKit, rnd: RandomNumberGenerator, x0: float, x1: float, y: float,
		z_front: float, depth: float, max_h: float, lean_gap: float = 0.0) -> void:
	var x := x0 + 0.01
	while x < x1 - 0.05:
		var w := rnd.randf_range(0.05, 0.11)
		if x + w > x1:
			break
		var h := max_h * rnd.randf_range(0.7, 1.0)
		var dd := depth * rnd.randf_range(0.8, 1.0)
		var mi := rnd.randi() % PropMats.BOOKS.size()
		k.box(PropMats.book(mi), Vector3(x + w * 0.5, y + h * 0.5, z_front + dd * 0.5), Vector3(w * 0.94, h, dd))
		if rnd.randf() < 0.18:
			k.box(PropMats.gold(), Vector3(x + w * 0.5, y + h * 0.78, z_front - 0.003), Vector3(w * 0.96, 0.015, 0.006))
		x += w
		if lean_gap > 0.0 and rnd.randf() < 0.08:
			x += lean_gap


## A candle with a glowing flame; returns the flame position.
static func candle(k: PropMeshKit, pos: Vector3, h: float, r: float, wax: Color = EstateKit.CREAM) -> Vector3:
	k.cyl(PropMats.pearl(wax), pos, r, r * 0.9, h, 6)
	var f := pos + Vector3(0, h + r * 1.2, 0)
	k.sphere(PropMats.flame(), f, Vector3(r * 0.55, r * 1.3, r * 0.55), 5, 3)
	return f


## A rectangular picture frame in the XY plane (face toward -Z), outer w x h.
static func frame(k: PropMeshKit, m: Material, center: Vector3, w: float, h: float, bar: float, depth: float) -> void:
	k.box(m, center + Vector3(0, h * 0.5 - bar * 0.5, 0), Vector3(w, bar, depth))
	k.box(m, center - Vector3(0, h * 0.5 - bar * 0.5, 0), Vector3(w, bar, depth))
	k.box(m, center + Vector3(w * 0.5 - bar * 0.5, 0, 0), Vector3(bar, h - bar * 2, depth))
	k.box(m, center - Vector3(w * 0.5 - bar * 0.5, 0, 0), Vector3(bar, h - bar * 2, depth))
	# little gilt corner rosettes
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			k.sphere(m, center + Vector3(sx * (w * 0.5 - bar * 0.5), sy * (h * 0.5 - bar * 0.5), -depth * 0.5),
					Vector3(bar * 0.6, bar * 0.6, bar * 0.3), 6, 3)


## An arch curve (semicircle) in the XY plane from x=-w/2 to w/2 springing at y.
static func arch_pts(w: float, y: float, z: float, steps: int = 10, rise: float = -1.0) -> PackedVector3Array:
	var pts := PackedVector3Array()
	var hgt := w * 0.5 if rise < 0.0 else rise
	for i in steps + 1:
		var a := PI * i / steps
		pts.append(Vector3(-cos(a) * w * 0.5, y + sin(a) * hgt, z))
	return pts


## A circle of points in the XZ plane.
static func ring_pts(center: Vector3, r: float, steps: int = 16) -> PackedVector3Array:
	var pts := PackedVector3Array()
	for i in steps + 1:
		var a := TAU * i / steps
		pts.append(center + Vector3(cos(a) * r, 0, sin(a) * r))
	return pts


## A little round bloom (rose) made of a centre ball and a petal collar.
static func bloom(k: PropMeshKit, m: Material, pos: Vector3, r: float) -> void:
	k.sphere(m, pos, Vector3(r, r * 0.8, r), 6, 4)
	k.torus(m, pos - Vector3(0, r * 0.2, 0), r * 0.9, r * 0.35, 6, 3)


## A gown: fitted bodice and a full bell skirt, standing at `pos`.
static func gown(k: PropMeshKit, m: Material, trim: Material, pos: Vector3, h: float, r: float) -> void:
	k.lathe(m, pos, PackedVector2Array([Vector2(0, 0), Vector2(r, 0), Vector2(r * 0.98, h * 0.08),
			Vector2(r * 0.8, h * 0.25), Vector2(r * 0.5, h * 0.42), Vector2(r * 0.28, h * 0.55),
			Vector2(r * 0.22, h * 0.6), Vector2(r * 0.3, h * 0.75), Vector2(r * 0.26, h * 0.82), Vector2(0, h * 0.84)]), 12)
	k.torus(trim, pos + Vector3(0, h * 0.58, 0), r * 0.24, r * 0.04, 10, 4)
	k.torus(trim, pos + Vector3(0, h * 0.04, 0), r * 0.99, r * 0.05, 14, 4)


## A small bottle (perfume, vial, potion).
static func bottle(k: PropMeshKit, m: Material, cap: Material, pos: Vector3, h: float, r: float) -> void:
	k.lathe(m, pos, PackedVector2Array([Vector2(0, 0), Vector2(r, 0), Vector2(r, h * 0.55),
			Vector2(r * 0.35, h * 0.75), Vector2(r * 0.3, h * 0.85), Vector2(0, h * 0.85)]), 6)
	k.sphere(cap, pos + Vector3(0, h * 0.92, 0), Vector3(r * 0.45, h * 0.1, r * 0.45), 6, 3)
