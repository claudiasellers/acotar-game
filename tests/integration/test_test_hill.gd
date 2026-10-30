## Loads the M0 test hill and plays the deed -> phase -> region loop for real.
extends GutTest

const TEST_SET := preload("res://data/phases/m0_test_phases.tres")
const SCENE := preload("res://world/shared/test_hill/test_hill.tscn")

var hill: Node3D


func before_each() -> void:
	WorldState.clear()
	PhaseManager.start(TEST_SET)
	hill = SCENE.instantiate()
	add_child_autofree(hill)
	await wait_physics_frames(30)


func test_feyre_lands_on_the_ground() -> void:
	var feyre := hill.feyre as Feyre
	assert_true(feyre.is_on_floor(), "Feyre should be standing on the terrain")


func test_walking_onto_the_summit_opens_the_thorn_gate() -> void:
	var gate := hill.get_node("ThornGate") as RegionGate
	assert_true(gate.is_locked())
	var summit := hill.get_node("SummitTrigger") as Node3D
	hill.feyre.global_position = summit.global_position + Vector3.UP * 0.5
	await wait_physics_frames(10)
	assert_eq(PhaseManager.current_phase, &"m0_summit")
	assert_false(gate.is_locked())
	assert_false(gate.visible)


func test_an_arrow_hitting_the_target_raises_its_flag() -> void:
	var target := hill.get_node("ArcheryTarget") as Node3D
	var arrow := Arrow.create()
	hill.add_child(arrow)
	var from := target.global_position + target.global_basis.z * 6.0
	arrow.launch(from, target.global_position - from, 40.0)
	await wait_physics_frames(30)
	assert_true(WorldState.has_flag("fact.test.target_hit"))
	assert_true(arrow.stuck)
	assert_true(arrow.is_in_group(Arrow.STUCK_GROUP))


func test_stuck_arrows_can_be_picked_up() -> void:
	var feyre := hill.feyre as Feyre
	var arrow := Arrow.create()
	hill.add_child(arrow)
	arrow.global_position = feyre.global_position + Vector3(1.0, 0.5, 0.0)
	arrow.add_to_group(Arrow.STUCK_GROUP)
	var before := feyre.quiver
	assert_true(feyre.pick_up_nearest_arrow())
	assert_eq(feyre.quiver, before + 1)
