## Loads the hunt demo headless and checks the creatures settle on the hill.
extends GutTest

const DEMO := preload("res://creatures/demo/hunt_demo.tscn")


# The demo's test hill starts the test phase ladder; leave the story as found.
func after_each() -> void:
	PhaseManager.phase_set = null
	PhaseManager.current_phase = &""


func test_demo_loads_and_creatures_stand_on_the_ground() -> void:
	WorldState.clear()
	var demo := DEMO.instantiate()
	add_child_autofree(demo)
	await wait_physics_frames(45)
	var creatures := get_tree().get_nodes_in_group(Creature.GROUP)
	assert_eq(creatures.size(), 3 + 4 + 6 + 4 + 1)
	var grounded := 0
	for c in creatures:
		if (c as Creature).is_on_floor():
			grounded += 1
	assert_gte(grounded, 15, "nearly everything is standing on the terrain")
	assert_true(demo.andras.alive)
	assert_eq(demo.andras.prey, demo.doe)
