## Every flora species has a mesh (Blender model, else procedural) on the shared
## foliage shader, swaying from the base, within its triangle budget and height,
## plus tree impostors.
extends GutTest

const SHADER_PATH := "res://world/shared/shaders/stylized_foliage.gdshader"
const ORIGINAL := [&"rose_red", &"rose_white", &"rose_gold", &"rose_pink", &"rose_climbing", &"hedge_box",
		&"lavender", &"foxglove", &"wild_hyacinth", &"honeysuckle", &"elderflower", &"wild_strawberry", &"blackberry",
		&"wisteria", &"lilac", &"faelight_dandelion", &"starmoss", &"willow", &"oak", &"cherry_blossom",
		&"apple_blossom", &"pear_tree", &"birch", &"reed", &"water_lily", &"tulip_bed", &"peony", &"forget_me_not",
		&"daisy", &"herb_patch", &"vegetable_row", &"fern", &"mushroom_glowcap"]


static func _tris(m: Mesh) -> int:
	var n := 0
	for i in m.get_surface_count():
		n += (m.surface_get_arrays(i)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	return n


func test_original_species_and_kinds_are_kept() -> void:
	assert_eq(ORIGINAL.size(), 33)
	for id: StringName in ORIGINAL:
		assert_true(FloraLib.has(id), "missing %s" % id)
	for id: StringName in [&"crocus", &"buttercup", &"iris", &"madder", &"crab_apple", &"orchid"]:
		assert_true(FloraLib.has(id), "missing requested %s" % id)


func test_meshes_use_the_shared_shader_with_wind_flex() -> void:
	var bad := []
	var rows := []
	var t0 := Time.get_ticks_usec()
	for id: StringName in FloraLib.SPECIES:
		var m := FloraLib.mesh(id)
		var n := _tris(m)
		var tree := FloraLib.kind_of(id) == &"tree"
		rows.append("%s=%d" % [id, n])
		if n > (6000 if tree else 3000) or n < 20:
			bad.append("%s tris %d" % [id, n])
		var max_flex := 0.0
		var root_flex := 0.0
		for i in m.get_surface_count():
			var sm := m.surface_get_material(i) as ShaderMaterial
			if sm == null or sm.shader == null or sm.shader.resource_path != SHADER_PATH:
				bad.append("%s surface %d not on the foliage shader" % [id, i])
			if FloraLib.is_model(id):
				if sm != null and absf(float(sm.get_shader_parameter(&"flex_height")) - FloraLib.height_of(id)) > 0.01:
					bad.append("%s flex_height is not its height" % id)
				max_flex = 1.0
				continue
			var arr := m.surface_get_arrays(i)
			var cols: PackedColorArray = arr[Mesh.ARRAY_COLOR]
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			if cols.is_empty():
				bad.append("%s surface %d has no vertex colours" % [id, i])
				continue
			for j in cols.size():
				max_flex = maxf(max_flex, cols[j].r)
				if verts[j].y < 0.02:
					root_flex = maxf(root_flex, cols[j].r)
				if cols[j].g != 0.0 or cols[j].b != 0.0:
					bad.append("%s tints by vertex colour" % id)
					break
		if max_flex < (0.1 if id == &"hedge_box" else 0.2):
			bad.append("%s barely sways (max flex %.2f)" % [id, max_flex])
		if root_flex > 0.1 and FloraLib.kind_of(id) != &"aquatic":
			bad.append("%s roots sway (%.2f)" % [id, root_flex])
		var h := FloraLib.height_of(id)
		var bb := m.get_aabb()
		var top := bb.end.y
		if top < h * 0.7 or top > h * 1.35 + 0.05:
			bad.append("%s height %.2f vs %.2f" % [id, top, h])
		if bb.position.y < -maxf(0.05, h * 0.01):
			bad.append("%s sinks below ground %.2f" % [id, bb.position.y])
	print("[flora] build all %.0f ms; tris: %s" % [(Time.get_ticks_usec() - t0) / 1000.0, ", ".join(rows)])
	assert_eq(bad.size(), 0, "%s" % [bad])


func test_species_meshes_are_distinct() -> void:
	var seen := {}
	for id: StringName in FloraLib.SPECIES:
		var m := FloraLib.mesh(id)
		var sig := "%d|%d|%s" % [_tris(m), m.get_surface_count(), m.get_aabb().size.snapped(Vector3.ONE * 0.01)]
		assert_false(seen.has(sig), "%s looks like %s" % [id, seen.get(sig, "")])
		seen[sig] = id


func test_trees_have_light_impostors() -> void:
	for id: StringName in FloraLib.SPECIES:
		var imp := FloraLib.impostor(id)
		if FloraLib.kind_of(id) != &"tree":
			assert_null(imp)
			continue
		assert_not_null(imp, "%s impostor" % id)
		assert_lte(_tris(imp), 80)
		assert_almost_eq(imp.get_aabb().end.y, FloraLib.height_of(id), FloraLib.height_of(id) * 0.3)
	assert_eq(FloraLib.IMPOSTOR_DISTANCE, 120.0)


func test_meshes_are_cached() -> void:
	assert_same(FloraLib.mesh(&"rose_pink"), FloraLib.mesh(&"rose_pink"))
