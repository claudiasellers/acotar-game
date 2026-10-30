## Woods lane: builds the smallest woods region for real and checks the
## contract hookups, the story anchors, the ground and the ambient switch.
extends GutTest

var region: WoodsRegion


func before_all() -> void:
	region = load("res://world/spring_court/suriel_glade/suriel_glade.tscn").instantiate()
	region.build_ground_cover = false
	add_child(region)
	region.build_now()


func after_all() -> void:
	region.free()


func test_forage_chunks_follow_the_contract() -> void:
	var chunks := get_tree().get_nodes_in_group(&"forage_field")
	assert_gt(chunks.size(), 20)
	var c: MultiMeshInstance3D = chunks[0]
	assert_eq(c.get_meta(&"region_id"), &"suriel_glade")
	assert_true(String(c.get_meta(&"ingredient_id")).begins_with("ing_") or String(c.get_meta(&"ingredient_id")).begins_with("col_"))
	assert_eq((c.get_meta(&"instance_ids") as PackedInt32Array).size(), c.multimesh.instance_count)


func test_story_anchors_exist() -> void:
	for anchor in ["suriel_snare", "WaitingOak", "NagaBackwater"]:
		assert_not_null(region.find_child(anchor, true, false), anchor)
	assert_gte(region.landmark_count, 3)


func test_fallback_ground_is_solid_where_world_height_says() -> void:
	await wait_physics_frames(2)
	var p := SurielGladeTerrain.SNARE_SITE
	var space := region.get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x, 200, p.y), Vector3(p.x, -200, p.y), 1))
	assert_false(hit.is_empty(), "ray hits the TerrainFallback collision")
	if not hit.is_empty():
		assert_almost_eq(hit.position.y, WorldHeight.height_at(p.x, p.y), 0.3)


func test_ambient_life_goes_silent_in_the_naga_reeds() -> void:
	var life := region.get_node("AmbientLife") as AmbientLife
	life.refresh(&"young_birches", 12.0)
	assert_has(life.active_effects(), "butterflies")
	assert_has(life.active_effects(), "sparkles")
	life.refresh(&"naga_reeds", 12.0)
	assert_does_not_have(life.active_effects(), "sparkles")
	assert_does_not_have(life.active_effects(), "songbirds")
	life.refresh(&"thornwater_banks", 22.0)
	assert_does_not_have(life.active_effects(), "dragonflies", "dragonflies are a day thing")
