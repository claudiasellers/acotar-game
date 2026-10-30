## Meshes for the estate's scatter layers. Plants with a FloraLib species use
## FloraLib.mesh() (the props lane upgrades those looks); small gatherables,
## lore flowers without a species yet, and every keepsake are built here as
## tiny vertex-coloured meshes on manor_item.gdshader. Keepsakes carry a
## twinkling sparkle glint so they read as "pick me up".
class_name ManorLooks
extends RefCounted

const ITEM_SHADER := preload("res://world/spring_court/manor_estate/scatter/manor_item.gdshader")
const GLINT := Color(1.0, 0.95, 0.75, 0.5)
const LEAF := Color(0.36, 0.74, 0.40)
const STEM := Color(0.42, 0.68, 0.36)

static var _cache: Dictionary = {}
static var _material: ShaderMaterial


static func material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = ITEM_SHADER
	return _material


## Mesh for a look spec: [&"flora", species] or [&"item", kind, colour].
static func mesh_for(look: Array) -> Mesh:
	var key := str(look)
	if _cache.has(key):
		return _cache[key]
	var m: Mesh
	if look[0] == &"flora":
		m = FloraLib.mesh(look[1])
	else:
		m = item(look[1], look[2] if look.size() > 2 else Color.WHITE)
	_cache[key] = m
	return m


static func item(kind: StringName, c: Color) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var glint := true
	match kind:
		&"clump":      # a little flower clump: stems, leaves, petal heads
			glint = false
			_clump(st, c, 7, 0.38, 0.09)
		&"tall_clump": # irises, madder: taller spears
			glint = false
			_clump(st, c, 5, 0.75, 0.11)
		&"low_clump":  # crocus, buttercup carpets
			glint = false
			_clump(st, c, 9, 0.18, 0.07)
		&"drift":      # fallen blossom petals round a sprig
			glint = false
			for i in 14:
				var a := i * 2.4
				var r := 0.12 + 0.05 * i
				_diamond(st, Vector3(cos(a) * r, 0.03, sin(a) * r), 0.07, c.lerp(Color.WHITE, 0.2 * (i % 3)), true)
			_box(st, Vector3(0, 0.05, 0), Vector3(0.4, 0.04, 0.04), Color(0.55, 0.36, 0.30))
			_diamond(st, Vector3(0.12, 0.12, 0), 0.09, c, false)
			_diamond(st, Vector3(-0.1, 0.11, 0.03), 0.09, c, false)
		&"bark":
			glint = false
			_box(st, Vector3(0, 0.06, 0), Vector3(0.5, 0.1, 0.22), c)
			_box(st, Vector3(0.05, 0.13, 0), Vector3(0.4, 0.06, 0.16), c.lightened(0.15))
		&"dew":        # a cluster of bright droplets on a leaf
			_diamond(st, Vector3(0, 0.02, 0), 0.3, LEAF, true)
			for i in 5:
				_octa(st, Vector3(cos(i * 1.3) * 0.12, 0.06, sin(i * 1.3) * 0.12), 0.05, Color(0.8, 0.95, 1.0, 0.5))
		&"jar":        # honey jar on a little comb
			_cyl(st, Vector3(0, 0, 0), 0.1, 0.22, Color(1.0, 0.72, 0.18), 8)
			_cyl(st, Vector3(0, 0.22, 0), 0.11, 0.04, Color(1.0, 0.6, 0.75), 8)
			_box(st, Vector3(0.2, 0.04, 0.0), Vector3(0.2, 0.08, 0.14), Color(1.0, 0.82, 0.3))
		&"shell":
			_octa(st, Vector3(0, 0.08, 0), 0.1, c)
			_octa(st, Vector3(0.07, 0.05, 0.02), 0.06, c.lightened(0.2))
		&"feather":
			_feather(st, c)
		&"ripple":     # rings on the water and a silver flash: a trout rising
			for r: float in [0.4, 0.7]:
				_ring(st, Vector3(0, 0.02, 0), r, 0.04, Color(0.85, 0.92, 1.0))
			_diamond(st, Vector3(0, 0.12, 0), 0.18, Color(0.85, 0.75, 0.9), false)
		&"fruit":      # windfall fruit in a little heap
			glint = false
			for i in 5:
				_octa(st, Vector3(cos(i * 1.25) * 0.12, 0.07, sin(i * 1.25) * 0.12), 0.07, c.lerp(Color(1.0, 0.85, 0.3), 0.3 * (i % 2)))
			_octa(st, Vector3(0, 0.15, 0), 0.07, c)
		&"silt":
			glint = false
			_octa(st, Vector3(0, 0.0, 0), 0.32, c)
			_octa(st, Vector3(0.2, 0.0, 0.1), 0.2, c.darkened(0.1))
		&"pebble":
			_octa(st, Vector3(0, 0.05, 0), 0.08, c)
			_box(st, Vector3(0, 0.1, 0), Vector3(0.06, 0.01, 0.06), Color(1.0, 0.6, 0.8))
		&"ribbon":
			for i in 6:
				_box(st, Vector3(-0.25 + i * 0.1, 0.02 + 0.02 * (i % 2), 0.03 * sin(i)), Vector3(0.1, 0.01, 0.05), c)
			_diamond(st, Vector3(0, 0.05, 0), 0.08, c.lightened(0.2), true)
		&"button":
			_cyl(st, Vector3.ZERO, 0.06, 0.02, c, 10)
		&"marble":
			_octa(st, Vector3(0, 0.05, 0), 0.05, c)
		&"horseshoe":
			for i in 7:
				var a := PI * i / 6.0
				_box(st, Vector3(cos(a) * 0.1, 0.01, sin(a) * 0.1), Vector3(0.04, 0.02, 0.06), c)
		&"key":
			_box(st, Vector3(0, 0.01, 0), Vector3(0.2, 0.02, 0.025), c)
			_ring(st, Vector3(-0.12, 0.01, 0), 0.05, 0.02, c)
			_box(st, Vector3(0.09, 0.01, 0.03), Vector3(0.025, 0.02, 0.05), c)
		&"violet":     # pressed violet between two leaves
			_diamond(st, Vector3(0, 0.01, 0), 0.2, Color(0.95, 0.9, 0.8), true)
			for i in 5:
				_diamond(st, Vector3(cos(i * 1.26) * 0.05, 0.02, sin(i * 1.26) * 0.05), 0.05, c, true)
		&"quartz":
			_octa(st, Vector3(0, 0.1, 0), 0.08, c)
			_octa(st, Vector3(0.05, 0.06, 0.03), 0.05, c.lightened(0.2))
		&"comb":
			_box(st, Vector3(0, 0.01, 0), Vector3(0.18, 0.02, 0.05), c)
			for i in 7:
				_box(st, Vector3(-0.08 + i * 0.027, 0.01, 0.05), Vector3(0.012, 0.015, 0.05), c)
		&"thimble":
			_cyl(st, Vector3.ZERO, 0.04, 0.07, c, 8)
		&"acorn":
			_octa(st, Vector3(0, 0.05, 0), 0.05, c)
			_cyl(st, Vector3(0, 0.07, 0), 0.05, 0.03, c.darkened(0.2), 8)
		_:
			_octa(st, Vector3(0, 0.08, 0), 0.08, c)
	if glint:
		_glint(st)
	st.generate_normals()
	var m := st.commit()
	m.surface_set_material(0, material())
	return m


# --- tiny geometry helpers (all vertex-coloured) ------------------------------

static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
	for v in [a, b, c]:
		st.set_color(col)
		st.add_vertex(v)


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
	_tri(st, a, b, c, col)
	_tri(st, a, c, d, col)


static func _box(st: SurfaceTool, ctr: Vector3, s: Vector3, col: Color) -> void:
	var h := s * 0.5
	var p := []
	for i in 8:
		p.append(ctr + Vector3(h.x if i & 1 else -h.x, h.y if i & 2 else -h.y, h.z if i & 4 else -h.z))
	for f in [[0, 1, 3, 2], [4, 6, 7, 5], [0, 4, 5, 1], [2, 3, 7, 6], [0, 2, 6, 4], [1, 5, 7, 3]]:
		_quad(st, p[f[0]], p[f[1]], p[f[2]], p[f[3]], col)


static func _octa(st: SurfaceTool, c: Vector3, r: float, col: Color) -> void:
	var t := c + Vector3.UP * r
	var b := c - Vector3.UP * r * 0.7
	var ring := [c + Vector3(r, 0, 0), c + Vector3(0, 0, r), c + Vector3(-r, 0, 0), c + Vector3(0, 0, -r)]
	for i in 4:
		_tri(st, t, ring[(i + 1) % 4], ring[i], col)
		_tri(st, b, ring[i], ring[(i + 1) % 4], col.darkened(0.08))


static func _diamond(st: SurfaceTool, c: Vector3, r: float, col: Color, flat: bool) -> void:
	if flat:
		_quad(st, c + Vector3(r, 0, 0), c + Vector3(0, 0, r * 0.6), c + Vector3(-r, 0, 0), c + Vector3(0, 0, -r * 0.6), col)
	else:
		_quad(st, c + Vector3(0, r, 0), c + Vector3(r * 0.6, 0, 0), c + Vector3(0, -r, 0), c + Vector3(-r * 0.6, 0, 0), col)
		_quad(st, c + Vector3(0, r, 0), c + Vector3(0, 0, r * 0.6), c + Vector3(0, -r, 0), c + Vector3(0, 0, -r * 0.6), col)


static func _cyl(st: SurfaceTool, base: Vector3, r: float, h: float, col: Color, n: int) -> void:
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var p0 := base + Vector3(cos(a0) * r, 0, sin(a0) * r)
		var p1 := base + Vector3(cos(a1) * r, 0, sin(a1) * r)
		_quad(st, p0, p1, p1 + Vector3.UP * h, p0 + Vector3.UP * h, col)
		_tri(st, base + Vector3.UP * h, p1 + Vector3.UP * h, p0 + Vector3.UP * h, col.lightened(0.1))


static func _ring(st: SurfaceTool, c: Vector3, r: float, w: float, col: Color) -> void:
	var n := 14
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		_quad(st, c + d0 * (r - w), c + d1 * (r - w), c + d1 * (r + w), c + d0 * (r + w), col)


static func _clump(st: SurfaceTool, c: Color, stems: int, height: float, head: float) -> void:
	for i in stems:
		var a := i * 2.399
		var r := 0.05 + 0.04 * (i % 3)
		var base := Vector3(cos(a) * r, 0, sin(a) * r)
		var h := height * (0.75 + 0.25 * ((i * 7) % 4) / 3.0)
		var tip := base * 1.6 + Vector3.UP * h
		_quad(st, base + Vector3(-0.01, 0, 0), base + Vector3(0.01, 0, 0), tip + Vector3(0.01, 0, 0), tip + Vector3(-0.01, 0, 0), STEM)
		_quad(st, base, base + Vector3(cos(a + 0.5), 0.3, sin(a + 0.5)) * height * 0.5, base + Vector3(cos(a), 0.6, sin(a)) * height * 0.55, base + Vector3(cos(a - 0.4), 0.2, sin(a - 0.4)) * height * 0.3, LEAF)
		var col := c.lerp(Color.WHITE, 0.15 * (i % 3))
		for k in 5:
			var pa := k * TAU / 5.0 + a
			_diamond(st, tip + Vector3(cos(pa), 0.2, sin(pa)) * head * 0.7, head * 0.6, col, true)
		_octa(st, tip, head * 0.35, Color(1.0, 0.9, 0.4))


static func _feather(st: SurfaceTool, c: Color) -> void:
	var tip := Vector3(0.32, 0.03, 0.0)
	var root := Vector3(-0.2, 0.02, 0.0)
	_box(st, Vector3(0.05, 0.02, 0), Vector3(0.52, 0.012, 0.012), c.lightened(0.4))
	for i in 6:
		var t := float(i) / 6.0
		var p := root.lerp(tip, t)
		var w := 0.07 * sin(PI * (t * 0.9 + 0.1))
		var band := c if i % 2 == 0 else c.darkened(0.25)
		_quad(st, p + Vector3(0, 0, -w), p + Vector3(0.09, 0, -w * 0.9), p + Vector3(0.09, 0, w * 0.9), p + Vector3(0, 0, w), band)


## The keepsake sparkle: two crossed four-point stars floating above the item.
static func _glint(st: SurfaceTool) -> void:
	var c := Vector3(0, 0.35, 0)
	var r := 0.16
	var w := 0.03
	_quad(st, c + Vector3(-r, 0, 0), c + Vector3(0, w, 0), c + Vector3(r, 0, 0), c + Vector3(0, -w, 0), GLINT)
	_quad(st, c + Vector3(0, -r, 0), c + Vector3(w, 0, 0), c + Vector3(0, r, 0), c + Vector3(-w, 0, 0), GLINT)
	_quad(st, c + Vector3(0, 0, -r), c + Vector3(0, w, 0), c + Vector3(0, 0, r), c + Vector3(0, -w, 0), GLINT)
	_quad(st, c + Vector3(0, -r * 0.6, 0), c + Vector3(0, 0, w), c + Vector3(0, r * 0.6, 0), c + Vector3(0, 0, -w), GLINT)
