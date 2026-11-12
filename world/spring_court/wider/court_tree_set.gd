## The court's trees (finish plan T3/T4/T6): the owner's mixed wood of
## Quaternius (CC0) and EZ-Tree models (assets/trees/, CREDITS.md) dressed by
## role in one palette, each pack keeping its own look ("that's how nature
## is"). A decor id the court already plants ("woods_oak", "flora_tree_rowan")
## names a role; the role lists its builds; the scatter spreads a layer's trees
## over the builds so neighbours differ (court_scatter_generator.gd).
##
## Every build has three detail steps (T2): the near mesh to NEAR m, the mid
## mesh from NEAR to court_scatter_generator.TREE_DRAW, and a far crown of 24
## triangles to TREE_FAR. Each build is scaled to the height FloraLibrary's tree
## for that id had, so the court's planting and sightlines keep their sizes.
##
## Meshes are built on the main thread (prewarm, from CourtRegion.prewarm) and
## read from any thread after; every cache read or write holds _lock.
class_name CourtTreeSet
extends RefCounted

## The switch: false puts the court back on FloraLibrary's trees.
const ON := true
const DIR := "res://world/spring_court/wider/assets/trees/"
const SHADER := "res://world/spring_court/wider/assets/trees/court_tree.gdshader"
## Near step's reach (m); the mid step runs from here to TREE_DRAW.
const NEAR := 80.0
## A region plants at most this many of a role's builds (each build and step
## is a draw call per chunk; T7: 13 broadleaf builds cost more than the eye
## gains). Different regions take different builds, so the court as a whole
## still shows them all.
const MAX_BUILDS := 6
enum Step { NEAR, MID, FAR }

## The mixed wood's palette (wcterrain-28, owner-approved): "deep" leaves,
## painted EZ bands, taupe bark.
const DEEP := {"leaf_col": Color(0.27, 0.48, 0.30), "leaf_light": Color(0.46, 0.64, 0.38),
	"shadow_col": Color(0.17, 0.32, 0.21), "mid_col": Color(0.27, 0.48, 0.30), "light_col": Color(0.46, 0.64, 0.38),
	"bark_col": Color(0.50, 0.42, 0.36)}

## Role -> {builds: [model, ...], palette overrides}. A model is "qtz/<file>"
## or "ez/<name>" under DIR. Colours are sRGB; each override replaces DEEP's.
const ROLES := {
	&"broadleaf": {"builds": ["qtz/CommonTree_1.gltf", "qtz/CommonTree_2.gltf", "qtz/CommonTree_3.gltf",
		"qtz/CommonTree_4.gltf", "qtz/CommonTree_5.gltf", "ez/oak_a", "ez/oak_b", "ez/oak_c", "ez/oak_d",
		"ez/ash_a", "ez/ash_b", "ez/ash_c", "ez/ash_d"]},
	&"ancient": {"builds": ["qtz/TwistedTree_1.gltf", "qtz/TwistedTree_2.gltf", "qtz/TwistedTree_3.gltf",
		"qtz/TwistedTree_4.gltf", "qtz/TwistedTree_5.gltf"]},
	&"birch": {"builds": ["ez/aspen_a", "ez/aspen_b", "ez/aspen_c", "ez/aspen_d"],
		"bark_col": Color(0.88, 0.86, 0.82)},
	&"cherry": {"builds": ["qtz/CommonTree_1.gltf", "qtz/CommonTree_3.gltf", "qtz/CommonTree_4.gltf",
		"qtz/CommonTree_5.gltf"], "leaf_col": Color(0.88, 0.46, 0.62), "leaf_light": Color(0.99, 0.74, 0.84)},
	&"apple": {"builds": ["qtz/CommonTree_2.gltf", "qtz/CommonTree_3.gltf", "qtz/CommonTree_5.gltf"],
		"leaf_col": Color(0.86, 0.80, 0.80), "leaf_light": Color(1.0, 0.96, 0.94)},
	&"lilac": {"builds": ["ez/lilac_a", "ez/lilac_b", "qtz/CommonTree_4.gltf"],
		"leaf_col": Color(0.66, 0.56, 0.84), "leaf_light": Color(0.86, 0.80, 0.96)},
	&"hawthorn": {"builds": ["qtz/Bush_Common_Flowers.gltf", "ez/bush_a", "ez/bush_c"]},
	&"elder": {"builds": ["qtz/Bush_Common.gltf", "ez/bush_b", "ez/bush_c"]},
	&"conifer": {"builds": ["qtz/Pine_1.gltf", "qtz/Pine_2.gltf", "qtz/Pine_3.gltf", "qtz/Pine_4.gltf",
		"qtz/Pine_5.gltf", "ez/pine_a", "ez/pine_b", "ez/pine_c"],
		"leaf_col": Color(0.20, 0.36, 0.27), "leaf_light": Color(0.33, 0.50, 0.36),
		"shadow_col": Color(0.12, 0.24, 0.18), "mid_col": Color(0.20, 0.36, 0.27), "light_col": Color(0.33, 0.50, 0.36)},
	&"dead": {"builds": ["qtz/DeadTree_1.gltf", "qtz/DeadTree_2.gltf", "qtz/DeadTree_3.gltf", "qtz/DeadTree_4.gltf",
		"qtz/DeadTree_5.gltf", "ez/dead_a", "ez/dead_b", "ez/dead_c"],
		"bark_col": Color(0.44, 0.40, 0.42), "leaf_col": Color(0.40, 0.37, 0.40), "leaf_light": Color(0.52, 0.49, 0.52),
		"drain": 0.35},
	&"autumn_oak": {"builds": ["qtz/CommonTree_1.gltf", "qtz/CommonTree_2.gltf", "ez/oak_a", "ez/oak_c"],
		"leaf_col": Color(0.74, 0.34, 0.20), "leaf_light": Color(0.94, 0.62, 0.30),
		"shadow_col": Color(0.46, 0.18, 0.14), "mid_col": Color(0.74, 0.34, 0.20), "light_col": Color(0.95, 0.64, 0.30)},
	&"autumn_maple": {"builds": ["qtz/CommonTree_3.gltf", "qtz/CommonTree_4.gltf", "ez/ash_a", "ez/ash_c"],
		"leaf_col": Color(0.72, 0.22, 0.20), "leaf_light": Color(0.92, 0.42, 0.30),
		"shadow_col": Color(0.44, 0.12, 0.13), "mid_col": Color(0.72, 0.22, 0.20), "light_col": Color(0.93, 0.45, 0.30)},
	&"golden_birch": {"builds": ["ez/aspen_a", "ez/aspen_b", "ez/aspen_d"], "bark_col": Color(0.88, 0.86, 0.82),
		"shadow_col": Color(0.55, 0.40, 0.12), "mid_col": Color(0.86, 0.66, 0.22), "light_col": Color(0.98, 0.86, 0.45),
		"leaf_col": Color(0.86, 0.66, 0.22), "leaf_light": Color(0.98, 0.86, 0.45)},
	&"rowan": {"builds": ["ez/ash_b", "ez/ash_d", "qtz/CommonTree_5.gltf"],
		"leaf_col": Color(0.80, 0.42, 0.20), "leaf_light": Color(0.96, 0.66, 0.32),
		"shadow_col": Color(0.50, 0.22, 0.12), "mid_col": Color(0.80, 0.42, 0.20), "light_col": Color(0.96, 0.66, 0.32)},
}
## The ids the court plants -> role. The willow (decision D1) and the leaning
## trunk stay FloraLibrary's.
const ID_ROLES := {
	&"woods_oak": &"broadleaf", &"woods_ancient_oak": &"ancient", &"woods_silver_birch": &"birch",
	&"woods_wild_cherry": &"cherry", &"woods_crab_apple": &"apple", &"woods_lilac_tree": &"lilac",
	&"woods_hawthorn": &"hawthorn", &"woods_elder": &"elder", &"woods_yew": &"conifer",
	&"woods_blighted_tree": &"dead", &"woods_twisted_dead": &"dead",
	&"flora_tree_autumn_oak": &"autumn_oak", &"flora_tree_autumn_maple": &"autumn_maple",
	&"flora_tree_golden_birch": &"golden_birch", &"flora_tree_rowan": &"rowan",
}
## EZ builds: name -> [leaf spray, bark] (assets/trees/ez/leaf_<spray>.png or
## blossom_<spray>.png, bark_<bark>.png). EZ meshes come in EZ-Tree units; the
## painted leaves' height shading reads them over EZ_UNITS (the preview's).
const EZ := {
	"oak": ["leaf_oak", "oak"], "ash": ["leaf_ash", "oak"], "aspen": ["leaf_aspen", "birch"],
	"pine": ["leaf_pine", "pine"], "bush": ["leaf_oak", "oak"], "dead": ["", "oak"], "lilac": ["blossom_lilac", "oak"],
}
const EZ_UNITS := 70.0
## Quaternius material -> texture (qtz/).
const QTZ_TEX := {
	"Bark_NormalTree": "Bark_NormalTree.png", "Bark_TwistedTree": "Bark_TwistedTree.png",
	"Bark_DeadTree": "Bark_DeadTree.png", "Leaves_NormalTree": "Leaves_NormalTree_C.png",
	"Leaves_TwistedTree": "Leaves_TwistedTree_C.png", "Leaves_Pine": "Leaf_Pine_C.png", "Flowers": "Flowers.png",
}
## The flowering bush's blossom (the approved preview's).
const FLOWERS := {"leaf_col": Color(0.93, 0.80, 0.86), "leaf_light": Color(1.0, 0.94, 0.96)}

static var _meshes := {}
static var _heights := {}
static var _materials := {}
static var _qtz_names := {}
static var _lock := Mutex.new()


static func role(id: StringName) -> StringName:
	if not ON:
		return &""
	return ID_ROLES.get(StringName(String(id).get_slice("@", 0)), &"")


static func has(id: StringName) -> bool:
	return role(id) != &""


## How many builds the id's role has (0 when the id isn't in the set).
static func builds(id: StringName) -> int:
	var r := role(id)
	return (ROLES[r]["builds"] as Array).size() if r != &"" else 0


## The builds a region plants of `id`: all of them up to MAX_BUILDS, else
## MAX_BUILDS of them, starting where the region's name hashes to.
static func region_builds(id: StringName, region: StringName) -> PackedInt32Array:
	var n := builds(id)
	var out := PackedInt32Array()
	if n <= MAX_BUILDS:
		for b in n:
			out.append(b)
		return out
	var start := absi(hash(String(region) + "|" + String(id).get_slice("@", 0))) % n
	for k in MAX_BUILDS:
		out.append((start + k * n / MAX_BUILDS) % n)
	out.sort()
	return out


## The mesh for build `b` of `id` at a detail step, scaled to the id's height.
static func mesh(id: StringName, b: int, step: int) -> Mesh:
	var base := StringName(String(id).get_slice("@", 0))
	var key := "%s#%d#%d" % [base, b, step]
	_lock.lock()
	var m: Mesh = _meshes.get(key)
	if m == null:
		m = _build_locked(base, b, step)
		_meshes[key] = m
	_lock.unlock()
	return m


## Builds every step of every build of these ids (main thread, before the
## region's workers start).
static func prewarm(ids: Array) -> void:
	for id: StringName in ids:
		for b in builds(id):
			for step in [Step.NEAR, Step.MID, Step.FAR]:
				mesh(id, b, step)


## The height (m) a build of `id` is scaled to: FloraLibrary's tree for a
## woods id, the court's own model for a flora id, else 12.
static func target_height(id: StringName) -> float:
	if _heights.has(id):
		return _heights[id]
	var h := 12.0
	var s := String(id)
	if s.begins_with(CourtAssets.WOODS_PREFIX) and FloraLibrary.has(StringName(s.substr(CourtAssets.WOODS_PREFIX.length()))):
		var fm := FloraLibrary.mesh(StringName(s.substr(CourtAssets.WOODS_PREFIX.length())))
		if fm != null and fm.get_aabb().size.y > 0.5:
			h = fm.get_aabb().size.y
	elif CourtAssets.scene_path(id) != "":
		var root := (load(CourtAssets.scene_path(id)) as PackedScene).instantiate()
		var mi := root.find_children("*", "MeshInstance3D", true, false)
		if not mi.is_empty() and (mi[0] as MeshInstance3D).mesh != null:
			h = maxf((mi[0] as MeshInstance3D).mesh.get_aabb().size.y, 1.0)
		root.free()
	_heights[id] = h
	return h


static func _build_locked(id: StringName, b: int, step: int) -> Mesh:
	var r := role(id)
	var spec: Dictionary = ROLES[r]
	var model: String = (spec["builds"] as Array)[clampi(b, 0, (spec["builds"] as Array).size() - 1)]
	var src := _lod_mesh(model, step == Step.NEAR)
	var near := src if step == Step.NEAR else _lod_mesh(model, true)
	if src == null or near == null:
		return null
	var h := target_height(id)
	# Scaled by the near mesh's size, so every step of a build matches.
	var aabb := near.get_aabb()
	var s := h / maxf(aabb.size.y, 0.01)
	var out := ArrayMesh.new()
	if step == Step.FAR:
		_far_crown(out, src, s, aabb)
		out.surface_set_material(0, _material(r, model, "far", s, h, Step.FAR))
		return out
	var leaves := PackedVector3Array()
	for i in src.get_surface_count():
		var kind := _surface_kind(src, i, model)
		var arr := src.surface_get_arrays(i)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		for k in verts.size():
			verts[k] = Vector3(verts[k].x * s, (verts[k].y - aabb.position.y) * s, verts[k].z * s)
		if step == Step.MID and kind != "bark":
			# The mid step's crown is solid (T7: cut-out leaves cost the dense
			# wood its frame time; a solid crown at 80 m+ reads the same).
			leaves.append_array(verts)
			continue
		arr[Mesh.ARRAY_VERTEX] = verts
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		out.surface_set_material(out.get_surface_count() - 1, _material(r, model, kind, s, h, step))
	if not leaves.is_empty():
		_mid_crown(out, leaves, b)
		out.surface_set_material(out.get_surface_count() - 1, _material(r, model, "far", s, h, Step.MID))
	return out


## The mid step's solid crown: the leaves gathered into CROWN_LUMPS clusters
## (k-means on the leaf vertices), each a rounded lump sized to its cluster,
## with round normals. Vertex alpha 1 (crown), as the far crown's.
const CROWN_LUMPS := 7
const LUMP_SEGMENTS := 8


static func _mid_crown(out: ArrayMesh, pts: PackedVector3Array, seed_b: int) -> void:
	var k := mini(CROWN_LUMPS, maxi(1, pts.size() / 12))
	var centres: Array[Vector3] = []
	var step := maxi(1, pts.size() / k)
	for i in k:
		centres.append(pts[(i * step + seed_b * 7) % pts.size()])
	var sums: Array[Vector3] = []
	var counts := PackedInt32Array()
	var spread := PackedFloat32Array()
	for it in 8:
		sums.clear()
		counts.resize(0)
		counts.resize(k)
		for i in k:
			sums.append(Vector3.ZERO)
		for p in pts:
			var best := 0
			var bd := INF
			for i in k:
				var d := p.distance_squared_to(centres[i])
				if d < bd:
					bd = d
					best = i
			sums[best] += p
			counts[best] += 1
		for i in k:
			if counts[i] > 0:
				centres[i] = sums[i] / counts[i]
	# Each lump's radii: the cluster's spread on each axis.
	var ext: Array[Vector3] = []
	for i in k:
		ext.append(Vector3.ZERO)
	for p in pts:
		var best := 0
		var bd := INF
		for i in k:
			var d := p.distance_squared_to(centres[i])
			if d < bd:
				bd = d
				best = i
		var d3 := (p - centres[best]).abs()
		ext[best] = Vector3(maxf(ext[best].x, d3.x), maxf(ext[best].y, d3.y), maxf(ext[best].z, d3.z))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_color(Color(1, 1, 1, 1))
	for i in k:
		if counts[i] == 0:
			continue
		var rad := ext[i] * 0.78
		rad = Vector3(maxf(rad.x, 0.3), maxf(rad.y, 0.3), maxf(rad.z, 0.3))
		_lump(st, centres[i], rad)
	st.commit(out)


## A rounded lump: LUMP_SEGMENTS around, three bands (top cap, two rings,
## bottom cap): 4 * LUMP_SEGMENTS triangles.
static func _lump(st: SurfaceTool, c: Vector3, rad: Vector3) -> void:
	var rings: Array[PackedVector3Array] = []
	for lat in [0.45, -0.35]:
		var ring := PackedVector3Array()
		for j in LUMP_SEGMENTS:
			var a := TAU * (float(j) + (0.5 if lat < 0.0 else 0.0)) / LUMP_SEGMENTS
			var cl := cos(lat * PI * 0.5)
			ring.append(Vector3(cos(a) * cl, sin(lat * PI * 0.5), sin(a) * cl))
		rings.append(ring)
	var top := Vector3.UP
	var bottom := Vector3.DOWN
	var put := func(u: Vector3) -> void:
		st.set_normal(u.normalized())
		st.add_vertex(c + u * rad)
	for j in LUMP_SEGMENTS:
		var j2 := (j + 1) % LUMP_SEGMENTS
		for u: Vector3 in [top, rings[0][j2], rings[0][j], rings[0][j], rings[0][j2], rings[1][j],
				rings[1][j], rings[0][j2], rings[1][j2], bottom, rings[1][j], rings[1][j2]]:
			put.call(u)


## "bark", "leaf", "flowers" for a surface of a model, from its material name.
static func _surface_kind(m: Mesh, i: int, model: String) -> String:
	var name := _surface_name(m, i)
	if name.begins_with("Flowers"):
		return "flowers"
	if name.contains("eaves") or name.contains("Leaf") or name == "ez_leaves":
		return "leaf"
	return "bark"


static func _surface_name(m: Mesh, i: int) -> String:
	var mat := m.surface_get_material(i)
	var n := String(mat.resource_name) if mat != null else ""
	if n == "" and m is ArrayMesh:
		n = (m as ArrayMesh).surface_get_name(i)
	return n


## One mesh (near or mid) from lod/<model>.glb, all its parts in one.
static func _lod_mesh(model: String, near: bool) -> Mesh:
	var base := model.get_file().get_basename()
	if model.begins_with("ez/"):
		base = "ez_" + base
	var path := "%slod/%s.glb" % [DIR, base]
	var packed := load(path) as PackedScene
	if packed == null:
		return null
	var root := packed.instantiate()
	var node := root.find_child("near" if near else "mid", true, false) as MeshInstance3D
	var m: Mesh = node.mesh if node != null else null
	root.free()
	return m


## A far crown of 24 triangles: a five-sided double cone with a middle band
## (20), fitted to the leaves' extent (or the whole tree's when it has none),
## with round normals so it shades like a soft mass, and a trunk of two
## crossed quads (4) under it. Vertex alpha tells the shader crown (1) from
## trunk (0).
static func _far_crown(out: ArrayMesh, src: Mesh, s: float, aabb: AABB) -> void:
	var box := AABB()
	var first := true
	for i in src.get_surface_count():
		if _surface_kind(src, i, "") == "bark" and src.get_surface_count() > 1:
			continue
		for v: Vector3 in src.surface_get_arrays(i)[Mesh.ARRAY_VERTEX]:
			box = AABB(v, Vector3.ZERO) if first else box.expand(v)
			first = false
	var cx := box.get_center().x * s
	var cz := box.get_center().z * s
	var y0 := (box.position.y - aabb.position.y) * s
	var y1 := (box.end.y - aabb.position.y) * s
	var mid := Vector3(cx, (y0 + y1) * 0.5, cz)
	var rx := box.size.x * 0.5 * s
	var rz := box.size.z * 0.5 * s
	var lo := Vector3(cx, y0, cz)
	var hi := Vector3(cx, y1, cz)
	var rings: Array[PackedVector3Array] = []
	for f in [0.32, 0.68]:
		var ring := PackedVector3Array()
		var y := lerpf(y0, y1, f)
		var w := 0.95 if f < 0.5 else 0.85
		for k in 5:
			var a := TAU * (float(k) + (0.5 if f > 0.5 else 0.0)) / 5.0
			ring.append(Vector3(cx + cos(a) * rx * w, y, cz + sin(a) * rz * w))
		rings.append(ring)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var crown := func(p: Vector3) -> void:
		st.set_color(Color(1, 1, 1, 1))
		st.set_normal((p - mid).normalized())
		st.add_vertex(p)
	for k in 5:
		var k2 := (k + 1) % 5
		for p in [lo, rings[0][k2], rings[0][k], rings[0][k], rings[0][k2], rings[1][k],
				rings[1][k], rings[0][k2], rings[1][k2], hi, rings[1][k], rings[1][k2]]:
			crown.call(p)
	var tw := maxf(rx, rz) * 0.12
	var ty := y0 + (y1 - y0) * 0.3
	for d: Vector3 in [Vector3(tw, 0, 0), Vector3(0, 0, tw)]:
		var a: Vector3 = Vector3(cx, 0.0, cz) - d
		var b: Vector3 = Vector3(cx, 0.0, cz) + d
		for p in [a, b, b + Vector3(0, ty, 0), a, b + Vector3(0, ty, 0), a + Vector3(0, ty, 0)]:
			st.set_color(Color(1, 1, 1, 0))
			st.set_normal(Vector3.UP)
			st.add_vertex(p)
	st.commit(out)


## One material per role, model, part and detail step: the step is its
## distance window in the shader (the near step to NEAR, the mid step from it;
## each tree switches at its own distance, whatever chunk it is drawn from).
static func _material(r: StringName, model: String, kind: String, s: float, h: float, step: int) -> ShaderMaterial:
	var ez := model.begins_with("ez/")
	var key := "%s|%s|%s|%d" % [r, model, kind, step]
	if _materials.has(key):
		return _materials[key]
	var spec: Dictionary = ROLES[r]
	var mat := ShaderMaterial.new()
	mat.shader = load(SHADER)
	if step == Step.NEAR:
		mat.set_shader_parameter(&"lod_end", NEAR)
	elif step == Step.MID:
		mat.set_shader_parameter(&"lod_begin", NEAR)
	for k: String in DEEP:
		mat.set_shader_parameter(k, spec.get(k, DEEP[k]))
	mat.set_shader_parameter(&"drain", spec.get("drain", 0.0))
	mat.set_shader_parameter(&"model_height", h)
	var wind := 0.5
	if kind == "far":
		mat.set_shader_parameter(&"mode", 4)
		if (spec["builds"] as Array).size() > 0 and r == &"dead":
			mat.set_shader_parameter(&"leaf_col", spec.get("bark_col", DEEP["bark_col"]))
			mat.set_shader_parameter(&"leaf_light", spec.get("leaf_light", DEEP["leaf_light"]))
	elif ez:
		var kind_name := model.get_file().get_slice("_", 0)
		var tex: Array = EZ.get(kind_name, EZ["oak"])
		if kind == "leaf":
			var blossom := String(tex[0]).begins_with("blossom")
			mat.set_shader_parameter(&"mode", 3 if blossom else 2)
			mat.set_shader_parameter(&"tex", load("%sez/%s.png" % [DIR, tex[0]]))
			mat.set_shader_parameter(&"model_height", EZ_UNITS * s)
		else:
			mat.set_shader_parameter(&"mode", 0)
			mat.set_shader_parameter(&"tex", load("%sez/bark_%s.png" % [DIR, tex[1]]))
			mat.set_shader_parameter(&"bark_mean", 0.42)
			wind = 0.0
	else:
		var name := _qtz_material_name(model, kind)
		mat.set_shader_parameter(&"tex", load("%sqtz/%s" % [DIR, QTZ_TEX.get(name, "Bark_NormalTree.png")]))
		if kind == "bark":
			mat.set_shader_parameter(&"mode", 0)
			wind = 0.0
		else:
			mat.set_shader_parameter(&"mode", 1)
			if kind == "flowers":
				for k: String in FLOWERS:
					mat.set_shader_parameter(k, FLOWERS[k])
	mat.set_shader_parameter(&"wind_amount", wind)
	_materials[key] = mat
	return mat


## The Quaternius material behind a surface kind of a model (its .gltf's list).
static func _qtz_material_name(model: String, kind: String) -> String:
	var path := DIR + model
	var names: Array = _qtz_names.get(path, [])
	if names.is_empty():
		var j: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if j is Dictionary:
			for m: Dictionary in (j as Dictionary).get("materials", []):
				names.append(m.get("name", ""))
		_qtz_names[path] = names
	for n: String in names:
		if kind == "flowers" and n.begins_with("Flowers"):
			return n
		if kind == "leaf" and (n.contains("eaves") or n.contains("Leaf")):
			return n
		if kind == "bark" and n.begins_with("Bark"):
			return n
	return names[0] if not names.is_empty() else ""
