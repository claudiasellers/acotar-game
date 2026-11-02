## Shared helpers for the garden rooms (L35): materials that never glare,
## draped walks and beds that follow the ground, hedges and edging laid along
## lines and arcs from the Blender modules, and planting helpers.
##
## Conventions: world XZ (-Z north). A catalogue prop's front faces -Z and its
## width runs along local X, so yaw_along() lays a module along a direction and
## yaw_facing() turns a prop's front toward one.
class_name GardenKit
extends RefCounted

const HEDGE_MODULE := 4.0        # yew_hedge length (m)
const EDGING_MODULE := 1.5       # box_edging spacing (m)
const HEDGE_H := 3.0


# --- Materials (manor glare fix: stone and gravel stay <= 0.85 albedo) ---------

## The walks: the drive's blush gravel shader, so the estate reads as one.
static func walk() -> Material:
	return ManorForecourt.drive_gravel()


## Warm garden stone for kerbs, copings and plinths.
static func stone() -> Material:
	return EstateKit.mat(Color(0.82, 0.75, 0.74), 0.7, 0.0, "garden_stone")


static func stone_shade() -> Material:
	return EstateKit.mat(Color(0.68, 0.60, 0.63), 0.8, 0.0, "garden_stone_shade")


## Rose-taupe paving for terraces and the canal surround.
static func paving() -> Material:
	return EstateKit.mat(Color(0.80, 0.68, 0.68), 0.6, 0.0, "garden_paving")


## Dark, rich mulch under the rose beds so the blooms pop.
static func mulch() -> Material:
	return EstateKit.mat(Color(0.40, 0.28, 0.27), 0.95, 0.0, "garden_mulch")


## Clipped lawn inside the rooms: a cooler, deeper green than the meadows.
static func lawn() -> Material:
	return EstateKit.mat(Color(0.40, 0.66, 0.40), 0.9, 0.0, "garden_lawn")


## Still mirror water for the reflecting pool (sky shows in it).
static func mirror_water() -> Material:
	var key := "garden_mirror_water"
	if EstateKit._materials.has(key):
		return EstateKit._materials[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.46, 0.56, 0.80, 0.9)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.0
	m.metallic = 0.85
	m.metallic_specular = 0.8
	m.rim_enabled = true
	m.rim = 0.3
	m.rim_tint = 0.6
	EstateKit._materials[key] = m
	return m


# --- Orientation ---------------------------------------------------------------

## Yaw that lays a prop's local X (its width) along `dir` (XZ).
static func yaw_along(dir: Vector2) -> float:
	return atan2(-dir.y, dir.x)


## Yaw that turns a prop's front (-Z) toward `dir` (XZ).
static func yaw_facing(dir: Vector2) -> float:
	return atan2(-dir.x, -dir.y)


static func on_circle(c: Vector2, r: float, a: float) -> Vector2:
	return c + Vector2(cos(a), sin(a)) * r


static func ring(c: Vector2, r: float, n: int = 48, a0: float = 0.0, a1: float = TAU) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n + 1:
		out.append(on_circle(c, r, lerpf(a0, a1, float(i) / n)))
	return out


# --- Ground pieces -------------------------------------------------------------

## An annular sector (a curved bed or ring walk) draped on the ground.
static func drape_sector(b: GroundsBatch, c: Vector2, r0: float, r1: float, a0: float, a1: float, material: Material,
		lift: float = 0.04, key: String = "|sector") -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := maxi(2, ceili((a1 - a0) * r1 / 2.0))
	var rings := maxi(1, ceili((r1 - r0) / 3.0))
	for i in n:
		for j in rings:
			var q := [
				on_circle(c, lerpf(r0, r1, float(j) / rings), lerpf(a0, a1, float(i) / n)),
				on_circle(c, lerpf(r0, r1, float(j + 1) / rings), lerpf(a0, a1, float(i) / n)),
				on_circle(c, lerpf(r0, r1, float(j + 1) / rings), lerpf(a0, a1, float(i + 1) / n)),
				on_circle(c, lerpf(r0, r1, float(j) / rings), lerpf(a0, a1, float(i + 1) / n)),
			]
			for idx in [0, 1, 2, 0, 2, 3]:
				var p: Vector2 = q[idx]
				st.set_normal(Vector3.UP)
				st.set_uv(p * 0.25)
				st.add_vertex(Vector3(p.x, WorldHeight.height_at(p.x, p.y) + lift, p.y))
	b.add_mesh(st.commit(), Transform3D(), material, key)


## A rectangle draped on the ground (beds, lawns, paving), axis-aligned.
static func drape_rect(b: GroundsBatch, r: Rect2, material: Material, lift: float = 0.04, step: float = 3.0, key: String = "|rect") -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nx := maxi(1, ceili(r.size.x / step))
	var nz := maxi(1, ceili(r.size.y / step))
	for i in nx:
		for j in nz:
			var q := [
				r.position + Vector2(r.size.x * i / nx, r.size.y * j / nz),
				r.position + Vector2(r.size.x * i / nx, r.size.y * (j + 1) / nz),
				r.position + Vector2(r.size.x * (i + 1) / nx, r.size.y * (j + 1) / nz),
				r.position + Vector2(r.size.x * (i + 1) / nx, r.size.y * j / nz),
			]
			for idx in [0, 2, 1, 0, 3, 2]:
				var p: Vector2 = q[idx]
				st.set_normal(Vector3.UP)
				st.set_uv(p * 0.25)
				st.add_vertex(Vector3(p.x, WorldHeight.height_at(p.x, p.y) + lift, p.y))
	b.add_mesh(st.commit(), Transform3D(), material, key)


# --- Hedges and edging ------------------------------------------------------------

## A clipped yew wall from a to c (3 m), modules every 4 m; the last module is
## pulled back so the wall ends exactly at c. Returns the module count.
static func hedge_line(b: GroundsBatch, a: Vector2, c: Vector2) -> int:
	var length := a.distance_to(c)
	if length < 1.0:
		return 0
	var dir := (c - a) / length
	var n := maxi(1, ceili(length / HEDGE_MODULE))
	var spacing := length / n     # <= the module, so neighbours overlap a little
	var yaw := yaw_along(dir)
	for k in n:
		var p := a + dir * spacing * (k + 0.5)
		# a short run gets a smaller module rather than poking past its end
		var s := minf(1.0, length / HEDGE_MODULE * 1.05) if n == 1 else 1.0
		b.prop_on_ground(&"yew_hedge", p.x, p.y, yaw, maxf(s, 0.6), -0.05)
	return n


## A yew wall along a polyline with gaps of `gap` metres at the given points
## (openings). Gaps that carry an arch get one placed across them.
static func hedge_with_openings(b: GroundsBatch, a: Vector2, c: Vector2, openings: Array, gap: float = 4.0, arch: bool = true) -> void:
	var length := a.distance_to(c)
	var dir := (c - a) / length
	var cuts: Array[float] = []
	for o: Vector2 in openings:
		cuts.append((o - a).dot(dir))
	cuts.sort()
	var s := 0.0
	for t in cuts:
		hedge_line(b, a + dir * s, a + dir * (t - gap * 0.5))
		if arch:
			var p := a + dir * t
			b.prop_on_ground(&"yew_hedge_arch", p.x, p.y, yaw_along(dir), 1.0, -0.05)
		s = t + gap * 0.5
	hedge_line(b, a + dir * s, c)


## Dwarf box edging along a polyline (beds, parterre scrolls).
static func edging(b: GroundsBatch, pts: PackedVector2Array) -> int:
	var n := 0
	for i in pts.size() - 1:
		var a := pts[i]
		var c := pts[i + 1]
		var seg := a.distance_to(c)
		if seg < 0.05:
			continue
		var dir := (c - a) / seg
		var k := maxi(1, roundi(seg / EDGING_MODULE))
		for j in k:
			var p := a + dir * seg * (j + 0.5) / k
			b.prop_on_ground(&"box_edging", p.x, p.y, yaw_along(dir), 1.0, -0.03)
			n += 1
	return n


## Edging round an annular sector bed (both arcs and both radial sides).
static func edge_sector(b: GroundsBatch, c: Vector2, r0: float, r1: float, a0: float, a1: float) -> int:
	var n := 0
	var seg := maxi(3, ceili((a1 - a0) * r1 / EDGING_MODULE))
	n += edging(b, ring(c, r1, seg, a0, a1))
	n += edging(b, ring(c, r0, maxi(2, ceili((a1 - a0) * r0 / EDGING_MODULE)), a0, a1))
	n += edging(b, PackedVector2Array([on_circle(c, r0, a0), on_circle(c, r1, a0)]))
	n += edging(b, PackedVector2Array([on_circle(c, r0, a1), on_circle(c, r1, a1)]))
	return n


static func rect_outline(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position])


# --- Planting ---------------------------------------------------------------

## Fills an annular sector with one species on a staggered grid; with `mix`, every
## other plant is that layer instead (forage roses among their garden look).
static func fill_sector(sb: ManorScatter, id: StringName, c: Vector2, r0: float, r1: float, a0: float, a1: float,
		step: float, rng: RandomNumberGenerator, scale_range: Vector2 = Vector2(0.9, 1.1), mix: StringName = &"") -> int:
	var n := 0
	var r := r0 + step * 0.5
	var row := 0
	while r < r1 - step * 0.3:
		var arc := (a1 - a0) * r
		var k := maxi(1, floori(arc / step))
		for i in k:
			var a := a0 + (a1 - a0) * (i + 0.5 + (0.25 if row % 2 else -0.25) * 0.0) / k
			var p := on_circle(c, r + rng.randf_range(-0.15, 0.15), a + rng.randf_range(-0.02, 0.02))
			var this := mix if mix != &"" and (i + row) % 2 == 1 else id
			sb.put(this, p.x, p.y, rng.randf() * TAU, rng.randf_range(scale_range.x, scale_range.y))
			n += 1
		r += step * 0.87
		row += 1
	return n


## Fills a rectangle with one species on a staggered grid (inset by `inset`).
static func fill_rect(sb: ManorScatter, id: StringName, r: Rect2, step: float, rng: RandomNumberGenerator,
		inset: float = 0.4, scale_range: Vector2 = Vector2(0.9, 1.1)) -> int:
	var n := 0
	var g := r.grow(-inset)
	var z := g.position.y + step * 0.5
	var row := 0
	while z < g.end.y:
		var x := g.position.x + step * (0.5 if row % 2 == 0 else 1.0)
		while x < g.end.x:
			sb.put(id, x + rng.randf_range(-0.12, 0.12), z + rng.randf_range(-0.12, 0.12), rng.randf() * TAU,
					rng.randf_range(scale_range.x, scale_range.y))
			n += 1
			x += step
		z += step * 0.87
		row += 1
	return n


## A planted line (a border row) of one species along a polyline.
static func fill_line(sb: ManorScatter, id: StringName, pts: PackedVector2Array, step: float, rng: RandomNumberGenerator,
		jitter: float = 0.2, scale_range: Vector2 = Vector2(0.85, 1.15)) -> int:
	var n := 0
	for i in pts.size() - 1:
		var a := pts[i]
		var c := pts[i + 1]
		var seg := a.distance_to(c)
		var k := maxi(1, floori(seg / step))
		for j in k:
			var p := a.lerp(c, (j + 0.5) / k)
			sb.put(id, p.x + rng.randf_range(-jitter, jitter), p.y + rng.randf_range(-jitter, jitter), rng.randf() * TAU,
					rng.randf_range(scale_range.x, scale_range.y))
			n += 1
	return n


## A drift (soft natural cluster) of a species round a point.
static func drift(sb: ManorScatter, id: StringName, c: Vector2, radius: float, count: int, rng: RandomNumberGenerator) -> void:
	for i in count:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * radius
		sb.put(id, c.x + cos(a) * r, c.y + sin(a) * r, rng.randf() * TAU, rng.randf_range(0.8, 1.15))
