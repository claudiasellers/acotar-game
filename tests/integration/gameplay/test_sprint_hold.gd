## Contract: holding sprint keeps Feyre at sprint speed until she lets go.
extends GutTest

const TEST_SET := preload("res://data/phases/m0_test_phases.tres")
const SCENE := preload("res://world/shared/test_hill/test_hill.tscn")

var hill: Node3D
var feyre: Feyre


func before_each() -> void:
	WorldState.clear()
	Gameplay.reset()
	PhaseManager.start(TEST_SET)
	hill = SCENE.instantiate()
	add_child_autofree(hill)
	feyre = hill.feyre
	await wait_physics_frames(10)


func after_each() -> void:
	Input.action_release(&"sprint")
	Input.action_release(&"move_forward")


func test_holding_sprint_for_a_long_time_stays_at_sprint_speed() -> void:
	var start := feyre.global_position
	var target := feyre.sprint_speed * Gameplay.inventory.speed_multiplier() \
			* (1.0 + Gameplay.wardrobe.swift() * 0.5)
	Input.action_press(&"move_forward")
	Input.action_press(&"sprint")
	var slowest := INF
	# The hill is small, so slide her back to the start before she meets a wall.
	# 15 s is far past the old ~4.5 s of stamina, and past a full recovery pause.
	for i in 900:
		await wait_physics_frames(1)
		if feyre.global_position.distance_to(start) > 3.0:
			feyre.global_position = start
		if i > 120 and feyre.is_on_floor():
			slowest = minf(slowest, Vector2(feyre.velocity.x, feyre.velocity.z).length())
	assert_gt(slowest, target * 0.95, "never dropped out of the sprint")
