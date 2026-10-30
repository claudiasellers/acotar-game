## Workshop region: named landmarks, ruin/shed collision, placement rules.
extends GutTest

const SCENE := "res://world/human_realm/workshop/workshop.tscn"
const SCATTER := "res://world/human_realm/workshop/scatter/"


func test_landmarks_exist() -> void:
	var root: Node = (load(SCENE) as PackedScene).instantiate()
	for n in ["BurntEstate", "FathersWorkshop", "FamilyPlot", "BrokenFountain", "ToppledStatue", "OrnamentalPond", "DeadOrchard", "EstateGates", "Workbench", "ColdStove", "CharredStaircase"]:
		var node := root.find_child(n, true, false)
		assert_not_null(node, n)
	var bodies := root.find_child("BurntEstate", true, false).find_children("*", "StaticBody3D", true, false)
	assert_gt(bodies.size(), 0, "ruin has collision")
	for body: StaticBody3D in bodies:
		assert_eq(body.collision_layer & 1, 1)
	assert_gt(root.find_child("FathersWorkshop", true, false).find_children("*", "StaticBody3D", true, false).size(), 0, "shed has collision")
	root.free()


func test_placements_in_area_and_off_roads() -> void:
	var rect: Rect2 = HumanRealmLayout.REGION_RECTS[&"workshop"]
	var bad := 0
	for f in DirAccess.get_files_at(SCATTER):
		if not f.ends_with(".tres"):
			continue
		var layer: ScatterLayer = load(SCATTER + f)
		assert_true(layer.tags.has("canon:C") or layer.tags.has("canon:X"), "%s canon tag" % layer.id)
		assert_false(layer.mesh_path.contains("tree_ash") or layer.ingredient_id == &"ing_ash_wood", "%s uses ash" % layer.id)
		for i in layer.count():
			var p := layer.position_of(i)
			var q := Vector2(p.x, p.z)
			if not rect.has_point(q) or HumanRealmLayout.distance_to_road(q) < HumanRealmLayout.ROAD_HALF_WIDTH:
				bad += 1
	assert_eq(bad, 0, "placements outside the rect or on a road")
