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

const GARDEN_WATER := preload("res://world/spring_court/manor_estate/gardens/garden_water.gdshader")

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


## Brown loam under the beds. It was a dark mauve (0.40, 0.28, 0.27) that the
## lilac dusk grade turned near-black purple in the parterres (L56, user
## report); a rose-cocoa try read salmon at noon, so: plain warm brown earth.
const MULCH := Color(0.46, 0.35, 0.27)


static func mulch() -> Material:
	return EstateKit.mat(MULCH, 0.95, 0.0, "garden_mulch")


## Clipped lawn inside the rooms: a cooler, deeper green than the meadows.
static func lawn() -> Material:
	return EstateKit.mat(Color(0.40, 0.66, 0.40), 0.9, 0.0, "garden_lawn")


## Still water for the reflecting canal: deep looking down, a rippled mirror of
## the sky at a glance (garden_water.gdshader; L35-6, audit E2).
static func mirror_water() -> Material:
	var key := "garden_mirror_water"
	if EstateKit._materials.has(key):
		return EstateKit._materials[key]
	var m := ShaderMaterial.new()
	m.shader = GARDEN_WATER
	m.resource_name = key
	EstateKit._materials[key] = m
	return m


## Records how many of each prop a batch placed (meta "props") before it flushes,
## for the tests.
static func tag_props(b: GroundsBatch) -> void:
	var d := {}
	for id: StringName in b._props:
		d[id] = (b._props[id] as Array).size()
	if b.has_meta(&"edging_modules"):
		d[&"box_edging"] = int(b.get_meta(&"edging_modules"))
	b.root.set_meta(&"props", d)


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


## Dwarf box edging along a polyline (beds, parterre scrolls): one continuous
## clipped hedge, swept along the line and mitred at the corners, with a soft,
## slightly irregular top and the clipped-leaf texture (L56-2). It replaced a
## 1.6 m box_edging module repeated end to end, which read as Lego: tube
## segments with seams and hexagon studs. Returns the old module count (1.5 m
## runs), kept for the gardens' tests.
const EDGING_W := 0.44
const EDGING_H := 0.46
const BOX_GREEN := Color(0.24, 0.47, 0.30)

static var _edging_mat: ShaderMaterial


static func edging_material() -> ShaderMaterial:
	if _edging_mat == null:
		var m := ShaderMaterial.new()
		m.shader = FloraLib.FOLIAGE_SHADER
		m.resource_name = "box_edging_hedge"
		m.set_shader_parameter(&"use_vertex_color", true)
		m.set_shader_parameter(&"alpha_scissor", 0.0)
		m.set_shader_parameter(&"wind_amount", 0.0)
		m.set_shader_parameter(&"sparkle", 0.0)
		m.set_shader_parameter(&"translucency", 0.2)
		m.set_shader_parameter(&"leaf_noise", 1.0)
		m.set_shader_parameter(&"leaf_scale", 16.0)
		m.set_shader_parameter(&"leaf_bump", 0.7)
		m.set_shader_parameter(&"leaf_lump", 0.015)
		_edging_mat = m
	return _edging_mat


## Cross-section (across, up) of the clipped box, from one foot round the top to the other.
const EDGING_PROFILE := [Vector2(-0.50, 0.0), Vector2(-0.50, 0.50), Vector2(-0.40, 0.86), Vector2(-0.18, 1.0),
	Vector2(0.18, 1.0), Vector2(0.40, 0.86), Vector2(0.50, 0.50), Vector2(0.50, 0.0)]


static func edging(b: GroundsBatch, pts: PackedVector2Array) -> int:
	if pts.size() < 2:
		return 0
	var closed := pts[0].distance_to(pts[pts.size() - 1]) < 0.05
	# resample to ~0.3 m, keeping the corners
	var line := PackedVector2Array()
	var length := 0.0
	for i in pts.size() - 1:
		var seg := pts[i].distance_to(pts[i + 1])
		if seg < 0.05:
			continue
		var k := maxi(1, ceili(seg / 0.3))
		for j in k:
			line.append(pts[i].lerp(pts[i + 1], float(j) / k))
		length += seg
	line.append(pts[pts.size() - 1])
	if line.size() < 2:
		return 0
	var n := line.size()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows: Array = []
	var dist := 0.0
	for i in n:
		var prev := line[i - 1] if i > 0 else (line[n - 2] if closed else line[i])
		var next := line[i + 1] if i < n - 1 else (line[1] if closed else line[i])
		var d0 := (line[i] - prev).normalized() if line[i] != prev else (next - line[i]).normalized()
		var d1 := (next - line[i]).normalized() if next != line[i] else d0
		var t := (d0 + d1).normalized() if (d0 + d1).length() > 0.01 else d1
		var nrm := Vector2(-t.y, t.x)
		# mitre: widen at corners so both sides keep their thickness
		var miter := 1.0 / maxf(0.5, nrm.dot(Vector2(-d1.y, d1.x)))
		if i > 0:
			dist += line[i].distance_to(line[i - 1])
		# clipped by hand: the top waves a few centimetres, the sides breathe
		var wob := 0.035 * sin(dist * 1.7 + line[i].x * 0.3) + 0.02 * sin(dist * 4.3 + 1.1)
		var y := WorldHeight.height_at(line[i].x, line[i].y) - 0.04
		var row: Array[Vector3] = []
		for q: Vector2 in EDGING_PROFILE:
			var across := q.x * EDGING_W * miter * (1.0 + wob * 0.8)
			var up := q.y * (EDGING_H + wob) if q.y > 0.0 else 0.0
			var p := line[i] + nrm * across
			row.append(Vector3(p.x, y + up, p.y))
		rows.append([row, dist])
	for i in n - 1:
		var r0: Array = rows[i][0]
		var r1: Array = rows[i + 1][0]
		for j in EDGING_PROFILE.size() - 1:
			var quad := [r0[j], r1[j], r1[j + 1], r0[j + 1]]
			var shade := 0.92 + 0.08 * float(EDGING_PROFILE[j].y)
			for idx in [0, 1, 2, 0, 2, 3]:
				st.set_color(BOX_GREEN.lightened(0.06 * shade - 0.03))
				st.add_vertex(quad[idx])
	# end caps on open runs
	if not closed:
		for e in [0, n - 1]:
			var r: Array = rows[e][0]
			for j in range(1, EDGING_PROFILE.size() - 2):
				var tri := [r[0], r[j], r[j + 1]] if e == n - 1 else [r[0], r[j + 1], r[j]]
				for v in tri:
					st.set_color(BOX_GREEN)
					st.add_vertex(v)
	st.generate_normals()
	b.add_mesh(st.commit(), Transform3D(), edging_material(), "|edging")
	var modules := maxi(1, roundi(length / EDGING_MODULE))
	b.set_meta(&"edging_modules", int(b.get_meta(&"edging_modules", 0)) + modules)
	return modules


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
