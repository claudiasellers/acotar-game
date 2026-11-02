# gate: needs:terrain
## L41-4 (audit G0): the first frame of the game shows Feyre clothed. The real game start
## (act1_game) dresses her through Gameplay.wardrobe: worn pieces cover her torso and legs.
extends GutTest

const GAME := "res://story/act1/act1_game.tscn"


func before_each() -> void:
	WorldState.clear()
	Gameplay.reset()


func test_act1_start_has_worn_pieces_over_torso_and_legs() -> void:
	var game := (load(GAME) as PackedScene).instantiate()
	add_child_autofree(game)
	await wait_frames(3)
	var feyre := game.get(&"feyre") as Feyre
	assert_not_null(feyre, "act1_game made Feyre")
	var worn := feyre.model.get_node_or_null(^"Worn")
	assert_not_null(worn, "her worn pieces are on the model")
	var meshes := 0
	for c in worn.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).skeleton != NodePath():
			meshes += 1
	assert_gt(meshes, 0, "skinned clothing, not placeholders")
	var covered: Array[StringName] = []
	for p in Gameplay.wardrobe.worn_pieces():
		if ResourceLoader.exists(p.mesh_path):
			covered.append_array(p.hides_body_regions)
	for r in [&"torso", &"legs"]:
		assert_has(covered, r, "worn pieces cover the %s" % r)
