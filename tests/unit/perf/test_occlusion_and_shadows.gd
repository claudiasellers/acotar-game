## Contract (program T1): occlusion culling is on; box occluders keep walls and
## slabs and skip slivers; village building colliders become an occluder inside
## the drawn hull; world-scale suns follow the shadow profile, small lights don't.
extends GutTest


func test_occlusion_culling_enabled() -> void:
	assert_true(bool(ProjectSettings.get_setting("rendering/occlusion_culling/use_occlusion_culling")))


func test_occluder_mesh_keeps_walls_skips_slivers() -> void:
	var m := OccluderMesh.new()
	assert_true(m.add_box(Transform3D.IDENTITY, Vector3(4, 3, 0.25)), "a wall counts")
	assert_true(m.add_box(Transform3D.IDENTITY, Vector3(6, 0.3, 5)), "a slab counts")
	assert_false(m.add_box(Transform3D.IDENTITY, Vector3(1.2, 0.6, 0.25)), "a lintel does not")
	assert_eq(m.box_count(), 2)
	assert_eq(m.indices.size(), 72)
	var parent := Node3D.new()
	add_child_autofree(parent)
	var inst := m.build(parent, "Occ")
	assert_not_null(inst)
	assert_eq((inst.occluder as ArrayOccluder3D).get_vertices().size(), 16)


func test_collider_occluders_shrink_inside_hull() -> void:
	var root := Node3D.new()
	add_child_autofree(root)
	var col := Node3D.new()
	col.name = "Collision"
	root.add_child(col)
	for body_name in ["house_timber_1_2", "fence_rail_1_2", "mill_wheel_0_0"]:
		var body := StaticBody3D.new()
		body.name = body_name
		col.add_child(body)
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(7.5, 7.6, 5.5)
		cs.shape = box
		cs.position = Vector3(0, 3.8, 0)
		body.add_child(cs)
	var occ := ColliderOccluders.new()
	occ.prefixes = PackedStringArray(["house_", "mill"])
	occ.exclude = PackedStringArray(["mill_wheel"])
	root.add_child(occ)
	await wait_process_frames(2)
	assert_eq(occ.boxes, 1, "only the house; fence and mill wheel skipped")
	var inst := occ.get_node("Occluder") as OccluderInstance3D
	var aabb := AABB()
	var verts := (inst.occluder as ArrayOccluder3D).get_vertices()
	aabb.position = verts[0]
	for v in verts:
		aabb = aabb.expand(v)
	assert_almost_eq(aabb.position.y, 0.0, 0.01, "keeps the bottom on the ground")
	assert_almost_eq(aabb.end.y, 3.8, 0.01, "stops at half height, under the roof")
	assert_lt(aabb.size.x, 7.5, "inside the footprint")


func test_shadow_profile_applies_to_world_suns_only() -> void:
	var old := GameSettings.shadow_profile
	GameSettings.shadow_profile = "mac"
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 220.0
	var lamp := DirectionalLight3D.new()
	lamp.shadow_enabled = true
	lamp.directional_shadow_max_distance = 20.0
	add_child_autofree(sun)
	add_child_autofree(lamp)
	assert_eq(sun.directional_shadow_max_distance, 160.0)
	assert_eq(sun.directional_shadow_mode, DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS)
	assert_eq(lamp.directional_shadow_max_distance, 20.0, "satchel/title lights untouched")
	GameSettings.shadow_profile = "high"
	assert_eq(sun.directional_shadow_max_distance, 220.0, "back to its own reach")
	assert_eq(sun.directional_shadow_mode, DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS)
	GameSettings.shadow_profile = old


func test_village_and_manor_carry_occluders() -> void:
	var v: Node3D = load("res://world/human_realm/village/village.tscn").instantiate()
	add_child_autofree(v)
	await wait_process_frames(2)
	var boxes := (v.get_node("Occluders") as ColliderOccluders).boxes
	gut.p("village occluder boxes: %d" % boxes)
	assert_gt(boxes, 20, "every solid house in the village occludes")
	var holder := Node3D.new()
	add_child_autofree(holder)
	var house := ManorHouseBuilder.build(holder)
	var levels := house.get_children().filter(func(c: Node) -> bool: return c is OccluderInstance3D)
	for l in levels:
		gut.p("%s: %d boxes" % [l.name, (l.occluder as ArrayOccluder3D).get_vertices().size() / 8])
	assert_gte(levels.size(), 4, "one occluder per manor level")
