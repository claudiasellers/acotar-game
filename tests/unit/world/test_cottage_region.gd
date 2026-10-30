## Cottage region: hero nodes the story/systems lanes attach to, the enclosed
## interior, scatter placement rules, and generator determinism.
extends GutTest

const Builder := preload("res://world/human_realm/cottage/region_builder.gd")
const SCENE := "res://world/human_realm/cottage/cottage.tscn"
const SCATTER := "res://world/human_realm/cottage/scatter/"


func _layers(dir: String) -> Array[ScatterLayer]:
	var out: Array[ScatterLayer] = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".tres"):
			out.append(load(dir + f))
	return out


func test_hero_nodes_exist() -> void:
	var root: Node = (load(SCENE) as PackedScene).instantiate()
	var hearth_spot := root.find_child("HearthSpot", true, false)
	assert_not_null(hearth_spot, "HearthSpot")
	assert_true(hearth_spot is Marker3D)
	assert_true(hearth_spot.get_parent().is_in_group(&"hearth"), "Hearth in group hearth")
	var tally := root.find_child("FoodTally", true, false)
	assert_not_null(tally, "FoodTally")
	var marker_found := false
	for c in tally.get_children():
		marker_found = marker_found or c is Marker3D
	assert_true(marker_found, "FoodTally has a Marker3D")
	var door := root.find_child("CottageDoor", true, false)
	assert_not_null(door, "CottageDoor")
	assert_not_null(door.get_node_or_null("IntactState/Intact"))
	assert_not_null(door.get_node_or_null("BrokenState/Broken"))
	for n in ["FireLight", "SistersBed", "FathersChair", "PaintedMotifs", "FeyresBowAndQuiver", "ElainGarden", "Scarecrow"]:
		assert_not_null(root.find_child(n, true, false), n)
	root.free()


func test_interior_is_enclosed() -> void:
	var root: Node3D = (load(SCENE) as PackedScene).instantiate()
	add_child_autofree(root)
	await wait_physics_frames(3)
	var cottage: Node3D = root.find_child("ArcheronCottage", true, false)
	var space := root.get_world_3d().direct_space_state
	var from := cottage.global_transform * Vector3(0.5, 1.3, 0.6)
	for dir: Vector3 in [Vector3.UP, Vector3.DOWN, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:
		var to := from + cottage.global_transform.basis * dir * 10.0
		var q := PhysicsRayQueryParameters3D.create(from, to, 1)
		q.hit_back_faces = true
		var hit := space.intersect_ray(q)
		assert_false(hit.is_empty(), "interior closed toward %s" % dir)
		if not hit.is_empty():
			assert_lt(from.distance_to(hit.position), 6.0, "wall within the room toward %s" % dir)


func test_placements_in_area_and_off_roads() -> void:
	var rects: Array[Rect2] = [HumanRealmLayout.REGION_RECTS[&"cottage"], HumanRealmLayout.COTTAGE_FIELDS]
	var bad := 0
	for layer in _layers(SCATTER):
		for i in layer.count():
			var p := layer.position_of(i)
			var q := Vector2(p.x, p.z)
			if not (rects[0].has_point(q) or rects[1].has_point(q)):
				bad += 1
			elif HumanRealmLayout.distance_to_road(q) < HumanRealmLayout.ROAD_HALF_WIDTH:
				bad += 1
			elif q.distance_to(HumanRealmLayout.COTTAGE) < 7.0:
				bad += 1  # nothing scattered inside the house
	assert_eq(bad, 0, "placements outside the area, on a road or in the house")


func test_layers_tagged_and_no_ash() -> void:
	for layer in _layers(SCATTER):
		assert_true(layer.tags.has("canon:C") or layer.tags.has("canon:X"), "%s canon tag" % layer.id)
		assert_ne(layer.ingredient_id, &"ing_ash_wood")
		assert_false(layer.mesh_path.contains("tree_ash"), "%s uses ash" % layer.id)


func test_builder_is_deterministic() -> void:
	var a := _sample_layer()
	var b := _sample_layer()
	assert_eq(a.count(), 40)
	assert_eq(a.instances, b.instances)


func _sample_layer() -> ScatterLayer:
	var rects: Array[Rect2] = [HumanRealmLayout.REGION_RECTS[&"cottage"]]
	var bld := Builder.new(&"cottage", rects, 1234)
	bld.reserve(HumanRealmLayout.COTTAGE, 12.0)
	return bld.add_layer({id = "t", mesh = "flint_nodule", ingredient = "ing_flint", count = 40})
