extends GutTest
# gate: when:world/spring_court/wider/*,world/shared/scatter/*,data/regions/spring_court/content/*,tools/court/*
## Finish plan T3/T4/T6: the court's mixed wood (CourtTreeSet). Every id the
## court plants resolves to its role's builds at three detail steps within
## budget and at the old tree's height; the scatter splits a layer over the
## builds and steps; neighbours differ.

const CONTENT_DIR := "res://data/regions/spring_court/content/"
const STEP := CourtTreeSet.Step


func before_all() -> void:
	CourtHeight.prewarm()
	CourtTreeSet.prewarm(CourtTreeSet.ID_ROLES.keys())


func _tris(m: Mesh) -> int:
	var n := 0
	for i in m.get_surface_count():
		var a := m.surface_get_arrays(i)
		var idx: Variant = a[Mesh.ARRAY_INDEX]
		n += ((idx as PackedInt32Array).size() if idx != null else (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	return n


func test_every_role_id_has_every_step_within_budget() -> void:
	var bad: Array[String] = []
	for id: StringName in CourtTreeSet.ID_ROLES:
		assert_gt(CourtTreeSet.builds(id), 1, "%s has several builds" % id)
		for b in CourtTreeSet.builds(id):
			var budgets := [4500, 1200, 24]
			for step in [STEP.NEAR, STEP.MID, STEP.FAR]:
				var m := CourtTreeSet.mesh(id, b, step)
				if m == null or m.get_surface_count() == 0:
					bad.append("%s#%d step %d missing" % [id, b, step])
					continue
				if _tris(m) > budgets[step]:
					bad.append("%s#%d step %d: %d tris" % [id, b, step, _tris(m)])
				for i in m.get_surface_count():
					var mat := m.surface_get_material(i) as ShaderMaterial
					if mat == null or mat.shader.resource_path != CourtTreeSet.SHADER:
						bad.append("%s#%d step %d surface %d: not the court tree shader" % [id, b, step, i])
	assert_eq(bad, [] as Array[String])


func test_builds_stand_at_the_old_trees_height() -> void:
	for id: StringName in CourtTreeSet.ID_ROLES:
		var h := CourtTreeSet.target_height(id)
		for b in CourtTreeSet.builds(id):
			var near := CourtTreeSet.mesh(id, b, STEP.NEAR).get_aabb()
			assert_almost_eq(near.size.y, h, h * 0.02, "%s#%d height" % [id, b])
			assert_almost_eq(near.position.y, 0.0, 0.05, "%s#%d stands on the ground" % [id, b])


func test_the_flowering_bush_flowers_and_the_birch_is_white() -> void:
	# wcterrain-28 showed the flowering bush brown (its leaf surface took the
	# bark path); every Quaternius leaf surface is mode 1, its blossom too.
	var hawthorn := CourtTreeSet.mesh(&"woods_hawthorn", 0, STEP.NEAR)
	var modes := []
	for i in hawthorn.get_surface_count():
		modes.append((hawthorn.surface_get_material(i) as ShaderMaterial).get_shader_parameter(&"mode"))
	assert_eq(modes, [1, 1], "the flowering bush: leaves and blossom")
	var birch := CourtTreeSet.mesh(&"woods_silver_birch", 0, STEP.NEAR)
	var bark := birch.surface_get_material(0) as ShaderMaterial
	assert_eq(bark.get_shader_parameter(&"mode"), 0)
	var c: Color = bark.get_shader_parameter(&"bark_col")
	assert_gt(c.get_luminance(), 0.8, "birch bark is pale")


func test_the_scatter_splits_trees_over_builds_and_steps_and_neighbours_differ() -> void:
	var content := load(CONTENT_DIR + "western_fells.tres") as CourtRegionContent
	var near := 0
	var mid := 0
	var shade := 0
	var by_build := {}
	var points: Array = []
	for layer in CourtScatterGenerator.decor_layers(content):
		if not layer.tags.has("tree") or not String(layer.id).contains("@"):
			continue
		if layer.tags.has("shadow"):
			# what a near tree casts its shadow with: its solid stand-in, in the shadow maps only
			shade += layer.count()
			assert_true(layer.shadow_only and layer.cast_shadow, "%s is drawn into the shadow maps only" % layer.id)
			assert_lt(_tris(layer.mesh), 1300, "%s is the solid tree" % layer.id)
			continue
		if String(layer.id).ends_with("m"):
			mid += layer.count()
			# Each tree switches step at its own distance, in the shader: the mid
			# step's materials start at NEAR, the near step's end there.
			assert_true(layer.tags.has("mid"))
			assert_eq(layer.draw_from, 0.0, "%s: its chunk is drawn from the camera out" % layer.id)
			assert_not_null(layer.impostor_mesh, "%s has its far crown" % layer.id)
			for i in layer.mesh.get_surface_count():
				assert_eq(float((layer.mesh.surface_get_material(i) as ShaderMaterial).get_shader_parameter(&"lod_begin")), CourtTreeSet.NEAR,
					"%s starts past the near step" % layer.id)
			continue
		near += layer.count()
		assert_true(layer.tags.has("near"))
		assert_false(layer.cast_shadow, "%s: the leaves cast no shadow themselves" % layer.id)
		assert_gt(layer.draw_distance, CourtTreeSet.NEAR + CourtScatterGenerator.NEAR_CHUNK * 0.7, "%s: a near chunk is drawn while a tree of it could be near" % layer.id)
		for i in layer.mesh.get_surface_count():
			assert_eq(float((layer.mesh.surface_get_material(i) as ShaderMaterial).get_shader_parameter(&"lod_end")), CourtTreeSet.NEAR,
				"%s is the near step" % layer.id)
		var base := String(layer.id).get_slice("@", 0)
		for i in layer.count():
			var o := i * ScatterLayer.STRIDE
			points.append([layer.position_of(i), "%s@%s" % [base, String(layer.id).get_slice("@", 1)],
				layer.instances[o + 3], layer.instances[o + 4], base])
	assert_gt(near, 1000, "the Western Woods has its trees")
	assert_eq(mid, near, "every tree has a near and a mid step")
	assert_eq(shade, near, "and every near tree its shadow")
	# Neighbours (within the gap, same species) on the same build.
	var same := 0
	var pairs := 0
	var twins := 0
	var grid := {}
	for p: Array in points:
		var cell := Vector2i(floori((p[0] as Vector3).x / 9.0), floori((p[0] as Vector3).z / 9.0))
		for dx in range(-1, 2):
			for dz in range(-1, 2):
				for q: Array in grid.get(cell + Vector2i(dx, dz), []):
					if q[4] != p[4] or (q[0] as Vector3).distance_to(p[0]) >= CourtScatterGenerator.NEIGHBOUR_GAP:
						continue
					pairs += 1
					if q[1] == p[1]:
						same += 1
						if is_equal_approx(q[2], p[2]) and is_equal_approx(q[3], p[3]):
							twins += 1
		if not grid.has(cell):
			grid[cell] = []
		(grid[cell] as Array).append(p)
	gut.p("neighbour pairs %d, same build %d (%.1f%%)" % [pairs, same, 100.0 * same / maxf(pairs, 1.0)])
	assert_eq(twins, 0, "no two neighbours share build, yaw and scale")
	assert_lt(float(same) / maxf(pairs, 1.0), 0.05, "neighbours rarely share a build")
