## The one arrow model, built once per colourway and shared: a tapered shaft
## with a nock, a leaf-shaped steel or gold head and three curved vanes, in
## vertex colours (R3). Arrows in flight, arrows stuck in things and the arrow
## nocked on her bow all use it, so none of them is a primitive grey box (F44).
## The tip points down -Z; `nock_z` is where the nock end sits.
## Loaded by path (no global class): a new class_name isn't registered until
## the class cache is rebuilt, and a stale cache broke the bow (the arrow
## script failed to compile, so she could not shoot).
extends RefCounted

const RADIUS := 0.0055
const SIDES := 8
const HEAD_LENGTH := 0.07
const HEAD_WIDTH := 0.018
const VANE_LENGTH := 0.1
const VANE_HEIGHT := 0.018
const STEEL := Color(0.62, 0.64, 0.68)

static var _cache: Dictionary = {}
static var _material: CandyMaterial


## A mesh `length` long from the nock at `nock_z` to the tip at nock_z - length.
static func mesh(length: float, nock_z: float, shaft: Color, fletch: Color, head: Color) -> ArrayMesh:
	var key := "%.3f|%.3f|%s|%s|%s" % [length, nock_z, shaft.to_html(), fletch.to_html(), head.to_html()]
	if _cache.has(key):
		return _cache[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tip_z := nock_z - length
	var shaft_end := tip_z + HEAD_LENGTH * 0.6
	_tube(st, nock_z - 0.004, shaft_end, RADIUS * 0.85, RADIUS, shaft)
	# The nock: a slightly darker collar at the string end.
	_tube(st, nock_z, nock_z - 0.012, RADIUS * 1.15, RADIUS * 1.15, shaft.darkened(0.3))
	_head(st, shaft_end, tip_z, head)
	for i in 3:
		_vane(st, nock_z - 0.02, TAU * i / 3.0, fletch)
	st.generate_normals()
	var m := st.commit()
	m.surface_set_material(0, material())
	_cache[key] = m
	return m


static func material() -> CandyMaterial:
	if _material == null:
		_material = MaterialLibrary.surface()
		_material.vertex_color_use_as_albedo = true
		_material.roughness = 0.55
		_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _material


static func _tube(st: SurfaceTool, z0: float, z1: float, r0: float, r1: float, col: Color) -> void:
	for k in SIDES:
		var a0 := TAU * k / SIDES
		var a1 := TAU * (k + 1) / SIDES
		var p00 := Vector3(cos(a0) * r0, sin(a0) * r0, z0)
		var p01 := Vector3(cos(a1) * r0, sin(a1) * r0, z0)
		var p10 := Vector3(cos(a0) * r1, sin(a0) * r1, z1)
		var p11 := Vector3(cos(a1) * r1, sin(a1) * r1, z1)
		_tri(st, p00, p10, p11, col)
		_tri(st, p00, p11, p01, col)


## A leaf-shaped head: two crossed blades, widest a third of the way back.
static func _head(st: SurfaceTool, base_z: float, tip_z: float, col: Color) -> void:
	var widest := lerpf(base_z, tip_z, 0.35)
	for axis: Vector3 in [Vector3.RIGHT, Vector3.UP]:
		var tip := Vector3(0, 0, tip_z)
		var base := Vector3(0, 0, base_z)
		var l := axis * HEAD_WIDTH + Vector3(0, 0, widest)
		var r := -axis * HEAD_WIDTH + Vector3(0, 0, widest)
		_tri(st, base, l, tip, col)
		_tri(st, base, tip, r, col.lightened(0.15))


## One vane: a curved fin swept back from the nock, standing off the shaft.
static func _vane(st: SurfaceTool, front_z: float, angle: float, col: Color) -> void:
	var out := Vector3(cos(angle), sin(angle), 0.0)
	var steps := 5
	for k in steps:
		var t0 := float(k) / steps
		var t1 := float(k + 1) / steps
		var z0 := front_z - VANE_LENGTH * t0
		var z1 := front_z - VANE_LENGTH * t1
		var h0 := VANE_HEIGHT * sin(PI * (0.15 + 0.85 * t0) * 0.5 + 0.2) * (1.0 - t0 * 0.35)
		var h1 := VANE_HEIGHT * sin(PI * (0.15 + 0.85 * t1) * 0.5 + 0.2) * (1.0 - t1 * 0.35)
		var a := out * RADIUS + Vector3(0, 0, z0)
		var b := out * RADIUS + Vector3(0, 0, z1)
		var c := out * (RADIUS + h1) + Vector3(0, 0, z1)
		var d := out * (RADIUS + h0) + Vector3(0, 0, z0)
		_tri(st, a, b, c, col)
		_tri(st, a, c, d, col)


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
	for p: Vector3 in [a, b, c]:
		st.set_color(col)
		st.add_vertex(p)
