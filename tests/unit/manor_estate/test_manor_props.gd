## Every prop id builds a real mesh (its Blender model, else procedural):
## distinct, fits its size, within the triangle budget, never grey, and the
## whole catalogue builds fast.
extends GutTest

const MAX_TRIS := 3000
const FLAT_IDS := [&"rug_large", &"rug_round", &"rug_runner"]
const NEW_IDS := [&"tiara_display", &"flower_crown_stand", &"music_box", &"teacup_set", &"macaron_tower",
		&"petal_bowl", &"swan_planter", &"heart_cushion", &"ribbon_spools", &"perfume_bottles_tall", &"star_lamp",
		&"canopy_reading_nook", &"chaise_swing", &"bird_feeder", &"rose_window_panel", &"tea_cart", &"jewelry_tree",
		&"parasol_stand", &"ballgown_display", &"hatbox_stack", &"butterfly_dome", &"seashell_basin", &"topiary_heart",
		&"lily_pond_bridge", &"picnic_blanket", &"toy_wooden_horse", &"dumbwaiter", &"loose_jar", &"spinning_wheel",
		&"embroidery_frame", &"rocking_horse", &"dollhouse", &"loom_upright", &"telescope_brass",
		&"beehive_skep", &"rowing_boat", &"garden_well", &"jump_rails"]

static var _built := false
static var _build_ms := 0.0


func before_all() -> void:
	if _built:
		return
	var t0 := Time.get_ticks_usec()
	for id: StringName in PropCatalog.ENTRIES:
		var e: Array = PropCatalog.ENTRIES[id]
		PropShapes.mesh(id, e[1], e[2])
	_build_ms = (Time.get_ticks_usec() - t0) / 1000.0
	_built = true


func _mesh(id: StringName) -> ArrayMesh:
	var e: Array = PropCatalog.ENTRIES[id]
	return PropShapes.mesh(id, e[1], e[2])


static func _tris(m: Mesh) -> int:
	var n := 0
	for i in m.get_surface_count():
		n += (m.surface_get_arrays(i)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	return n


func test_every_id_is_handled_by_a_real_builder() -> void:
	var fallback := PropShapes.fallback_ids.keys()
	assert_eq(fallback.size(), 0, "ids still on the stand-in box: %s" % [fallback])


func test_sizes_fit_within_ten_percent() -> void:
	var bad := []
	for id: StringName in PropCatalog.ENTRIES:
		var size: Vector3 = PropCatalog.ENTRIES[id][1]
		var bb := _mesh(id).get_aabb()
		for ax in 3:
			if absf(bb.size[ax] - size[ax]) > size[ax] * 0.1 + 0.002:
				bad.append("%s axis %d: %.3f vs %.3f" % [id, ax, bb.size[ax], size[ax]])
		if absf(bb.position.y) > 0.01 or absf(bb.get_center().x) > size.x * 0.05 + 0.002 or absf(bb.get_center().z) > size.z * 0.05 + 0.002:
			bad.append("%s not base-centred: %s" % [id, bb])
	assert_eq(bad.size(), 0, "%s" % [bad])


func test_triangle_budget_and_not_a_plain_box() -> void:
	var over := []
	var boxes := []
	var rows := []
	for id: StringName in PropCatalog.ENTRIES:
		var m := _mesh(id)
		var n := _tris(m)
		rows.append([n, id, m.get_surface_count()])
		if n > MAX_TRIS:
			over.append("%s: %d" % [id, n])
		if not FLAT_IDS.has(id) and (n <= 12 or m.get_surface_count() < 2 and n < 48):
			boxes.append(id)
	rows.sort_custom(func(a, b): return a[0] > b[0])
	var total := 0
	for r in rows:
		total += r[0]
	print("[props] %d ids, %d tris total, mean %d, build all %.0f ms" % [rows.size(), total, total / rows.size(), _build_ms])
	print("[props] heaviest: ", rows.slice(0, 8).map(func(r): return "%s=%d" % [r[1], r[0]]))
	print("[props] lightest: ", rows.slice(rows.size() - 5).map(func(r): return "%s=%d" % [r[1], r[0]]))
	assert_eq(over.size(), 0, "over %d tris: %s" % [MAX_TRIS, over])
	assert_eq(boxes.size(), 0, "plain boxes: %s" % [boxes])


func test_meshes_are_distinct() -> void:
	var seen := {}
	var dup := []
	for id: StringName in PropCatalog.ENTRIES:
		var m := _mesh(id)
		var bb := m.get_aabb()
		var sig := "%d|%d|%s" % [_tris(m), m.get_surface_count(), bb.size.snapped(Vector3.ONE * 0.001)]
		if seen.has(sig):
			dup.append("%s == %s" % [id, seen[sig]])
		seen[sig] = id
	assert_eq(dup.size(), 0, "%s" % [dup])


func test_never_grey_and_always_some_colour() -> void:
	var grey := []
	var dull := []
	for id: StringName in PropCatalog.ENTRIES:
		var m := _mesh(id)
		if PropShapes.is_model(id):
			if not _vertex_colourful(m):
				dull.append(id)
			continue
		var colourful := false
		for i in m.get_surface_count():
			var mat := m.surface_get_material(i) as BaseMaterial3D
			if mat == null:
				continue
			var c := mat.albedo_color
			if c.s < 0.05 and c.v < 0.85:
				grey.append("%s surface %d %s" % [id, i, c])
			if c.s > 0.12:
				colourful = true
		if not colourful:
			dull.append(id)
	assert_eq(grey.size(), 0, "grey materials: %s" % [grey])
	assert_eq(dull.size(), 0, "no colourful material: %s" % [dull])


## Models carry colour per vertex: at least a tenth of the vertices must be tinted.
static func _vertex_colourful(m: Mesh) -> bool:
	var tinted := 0
	var total := 0
	for i in m.get_surface_count():
		var cols: PackedColorArray = m.surface_get_arrays(i)[Mesh.ARRAY_COLOR]
		total += cols.size()
		for c in cols:
			if c.s > 0.12:
				tinted += 1
	return total > 0 and tinted * 10 >= total


func test_blender_models_cover_the_placed_props_with_lod1() -> void:
	var models := 0
	var bad := []
	for id: StringName in PropCatalog.ENTRIES:
		if not PropShapes.is_model(id):
			continue
		models += 1
		var pair := PropModels.prop(id)
		var n0 := PropModels.tri_count(pair[0])
		if pair[1] == null:
			bad.append("%s has no lod1" % id)
			continue
		var r := float(PropModels.tri_count(pair[1])) / maxf(n0, 1.0)
		if r > 0.75 or r < 0.25:
			bad.append("%s lod1 %.0f%%" % [id, r * 100.0])
		for i in (pair[0] as Mesh).get_surface_count():
			var mat := (pair[0] as Mesh).surface_get_material(i)
			if mat != PropFinishes.material(&"opaque") and mat != PropFinishes.material(&"clear"):
				bad.append("%s surface %d off the finish shader" % [id, i])
	assert_gte(models, 160, "Blender models in use")
	assert_eq(bad.size(), 0, "%s" % [bad])


func test_new_charm_ids_are_catalogued() -> void:
	assert_gte(NEW_IDS.size(), 20)
	for id: StringName in NEW_IDS:
		assert_true(PropCatalog.ENTRIES.has(id), "missing %s" % id)


func test_lights_only_on_lighting_props_and_capped() -> void:
	for id: StringName in PropShapes.LIGHTS:
		var e: Array = PropCatalog.ENTRIES[id]
		assert_eq(e[0], &"lighting", "%s carries a light" % id)
		var node := PropShapes.build(id, e[1], e[2])
		var lights := node.find_children("*", "OmniLight3D", true, false)
		assert_eq(lights.size(), 1)
		var l := lights[0] as OmniLight3D
		assert_lte(l.omni_range, 9.0)
		assert_false(l.shadow_enabled)
		node.free()


func test_instances_share_the_cached_mesh_and_prop_lib_still_builds() -> void:
	var a := PropLib.build(&"armchair")
	var b := PropLib.build(&"armchair")
	var ma := (a.get_node("Look/Mesh") as MeshInstance3D).mesh
	var mb := (b.get_node("Look/Mesh") as MeshInstance3D).mesh
	assert_same(ma, mb)
	a.free()
	b.free()


func test_build_all_under_three_seconds() -> void:
	assert_lt(_build_ms, 3000.0, "built every prop in %.0f ms" % _build_ms)
