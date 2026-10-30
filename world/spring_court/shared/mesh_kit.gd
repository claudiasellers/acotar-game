## Small procedural mesh helpers for the woods' flora and props.
##
## Conventions shared with woods_foliage.gdshader:
## - COLOR is the albedo, authored in sRGB.
## - UV.x is how much the vertex sways in the wind (0 at the root, 1 at a tip).
## - UV.y is glow (emission strength, 0 for most plants).
class_name MeshKit
extends RefCounted

## Blooms are drawn this much larger than life (storybook look, rule R3).
const BLOOM_SCALE := 1.7

var st := SurfaceTool.new()
var rng := RandomNumberGenerator.new()


func _init(seed_value: int = 1) -> void:
	rng.seed = seed_value
	st.begin(Mesh.PRIMITIVE_TRIANGLES)


func tri(a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color,
		sa: float = 0.0, sb: float = 0.0, sc: float = 0.0, glow: float = 0.0) -> void:
	var n := (b - a).cross(c - a).normalized()
	for v in [[a, ca, sa], [b, cb, sb], [c, cc, sc]]:
		st.set_normal(n)
		st.set_color(v[1])
		st.set_uv(Vector2(v[2], glow))
		st.add_vertex(v[0])


func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col_bottom: Color, col_top: Color,
		sway_bottom: float = 0.0, sway_top: float = 1.0, glow: float = 0.0) -> void:
	# a, b at the bottom; c, d at the top (b above-right of a).
	tri(a, b, c, col_bottom, col_bottom, col_top, sway_bottom, sway_bottom, sway_top, glow)
	tri(a, c, d, col_bottom, col_top, col_top, sway_bottom, sway_top, sway_top, glow)


## A tapered tube from `from` to `to`. `ring_colors` may hold one colour per
## ring (for birch bands); otherwise the bottom/top colours are blended.
func tube(from: Vector3, to: Vector3, r0: float, r1: float, segments: int,
		col0: Color, col1: Color, sway0: float = 0.0, sway1: float = 0.0, rings: int = 1) -> void:
	var axis := (to - from)
	var up := axis.normalized()
	var side := up.cross(Vector3.RIGHT if absf(up.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD).normalized()
	var fwd := up.cross(side)
	for ring in rings:
		var t0 := float(ring) / rings
		var t1 := float(ring + 1) / rings
		var p0 := from + axis * t0
		var p1 := from + axis * t1
		var ra := lerpf(r0, r1, t0)
		var rb := lerpf(r0, r1, t1)
		var ca := col0.lerp(col1, t0)
		var cb := col0.lerp(col1, t1)
		var sa := lerpf(sway0, sway1, t0)
		var sb := lerpf(sway0, sway1, t1)
		for i in segments:
			var a0 := TAU * i / segments
			var a1 := TAU * (i + 1) / segments
			var d0 := side * cos(a0) + fwd * sin(a0)
			var d1 := side * cos(a1) + fwd * sin(a1)
			var v00 := p0 + d0 * ra
			var v01 := p0 + d1 * ra
			var v10 := p1 + d0 * rb
			var v11 := p1 + d1 * rb
			_vert(v00, d0, ca, sa)
			_vert(v10, d0, cb, sb)
			_vert(v01, d1, ca, sa)
			_vert(v01, d1, ca, sa)
			_vert(v10, d0, cb, sb)
			_vert(v11, d1, cb, sb)


## A lumpy ellipsoid (leaf mass, moss mound, boulder, toadstool cap).
func blob(center: Vector3, radius: Vector3, col_top: Color, col_bottom: Color,
		lumpiness: float = 0.18, rings: int = 4, segments: int = 7, sway: float = 0.0, glow: float = 0.0) -> void:
	var offsets := {}
	var verts: Array[Array] = []
	for r in rings + 1:
		var row: Array = []
		var phi := PI * r / rings
		for s in segments + 1:
			var theta := TAU * (s % segments) / segments
			var dir := Vector3(sin(phi) * cos(theta), cos(phi), sin(phi) * sin(theta))
			var key := Vector2i(r, s % segments)
			if r == 0 or r == rings:
				key = Vector2i(r, 0)
			if not offsets.has(key):
				offsets[key] = 1.0 + rng.randf_range(-lumpiness, lumpiness)
			row.append(center + dir * radius * offsets[key])
		verts.append(row)
	for r in rings:
		for s in segments:
			var a: Vector3 = verts[r][s]
			var b: Vector3 = verts[r][s + 1]
			var c: Vector3 = verts[r + 1][s + 1]
			var d: Vector3 = verts[r + 1][s]
			var ta := 1.0 - float(r) / rings
			var tb := 1.0 - float(r + 1) / rings
			var cta := col_bottom.lerp(col_top, ta)
			var ctb := col_bottom.lerp(col_top, tb)
			_smooth(a, center, radius, cta, sway, glow)
			_smooth(c, center, radius, ctb, sway, glow)
			_smooth(b, center, radius, cta, sway, glow)
			_smooth(a, center, radius, cta, sway, glow)
			_smooth(d, center, radius, ctb, sway, glow)
			_smooth(c, center, radius, ctb, sway, glow)


## A crossed pair of blades (grass, reeds, leaves on a stem).
func blade(base: Vector3, height: float, width: float, lean: Vector3, col0: Color, col1: Color,
		glow: float = 0.0) -> void:
	var yaw := rng.randf() * TAU
	var right := Vector3(cos(yaw), 0.0, sin(yaw)) * width * 0.5
	var tip := base + Vector3.UP * height + lean
	var mid := base + Vector3.UP * height * 0.55 + lean * 0.35
	tri(base - right, base + right, mid + right * 0.6, col0, col0, col0.lerp(col1, 0.6), 0.0, 0.0, 0.55, glow)
	tri(base - right, mid + right * 0.6, mid - right * 0.6, col0, col0.lerp(col1, 0.6), col0.lerp(col1, 0.6), 0.0, 0.55, 0.55, glow)
	tri(mid - right * 0.6, mid + right * 0.6, tip, col0.lerp(col1, 0.6), col0.lerp(col1, 0.6), col1, 0.55, 0.55, 1.0, glow)


## A flat ring of petals facing up (or along `facing`).
func flower(center: Vector3, petals: int, radius: float, petal_col: Color, heart_col: Color,
		facing: Vector3 = Vector3.UP, sway: float = 1.0, glow: float = 0.0) -> void:
	radius *= BLOOM_SCALE
	var n := facing.normalized()
	var side := n.cross(Vector3.RIGHT if absf(n.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD).normalized()
	var fwd := n.cross(side)
	var heart := center + n * radius * 0.15
	for i in petals:
		var a0 := TAU * (i - 0.35) / petals
		var a1 := TAU * (i + 0.35) / petals
		var am := TAU * i / petals
		var p0 := center + (side * cos(a0) + fwd * sin(a0)) * radius * 0.45
		var p1 := center + (side * cos(a1) + fwd * sin(a1)) * radius * 0.45
		var tip := center + (side * cos(am) + fwd * sin(am)) * radius - n * radius * 0.12
		tri(heart, p0, tip, heart_col, petal_col, petal_col, sway, sway, sway, glow)
		tri(heart, tip, p1, heart_col, petal_col, petal_col, sway, sway, sway, glow)


## A drooping bell (bluebell, foxglove).
func bell(top: Vector3, length: float, radius: float, col: Color, inner: Color, sway: float = 1.0) -> void:
	length *= BLOOM_SCALE
	radius *= BLOOM_SCALE
	var segs := 5
	var mouth := top + Vector3.DOWN * length
	for i in segs:
		var a0 := TAU * i / segs
		var a1 := TAU * (i + 1) / segs
		var m0 := mouth + Vector3(cos(a0), 0.0, sin(a0)) * radius
		var m1 := mouth + Vector3(cos(a1), 0.0, sin(a1)) * radius
		tri(top, m1, m0, col, inner, inner, sway, sway, sway)


func commit() -> ArrayMesh:
	st.index()
	return st.commit()


func _vert(p: Vector3, n: Vector3, c: Color, sway: float) -> void:
	st.set_normal(n)
	st.set_color(c)
	st.set_uv(Vector2(sway, 0.0))
	st.add_vertex(p)


func _smooth(p: Vector3, center: Vector3, radius: Vector3, c: Color, sway: float, glow: float) -> void:
	var local := (p - center) / radius
	st.set_normal(local.normalized())
	st.set_color(c)
	st.set_uv(Vector2(sway, glow))
	st.add_vertex(p)
