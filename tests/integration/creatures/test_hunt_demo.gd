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
	# Exactly what the demo placed, read from the demo itself: every creature it
	# put on the hill is in the group, and nothing else is.
	var placed := demo.get_children().filter(func(n: Node) -> bool: return n is Creature)
	assert_gt(placed.size(), 1, "the demo placed its creatures")
	assert_eq(creatures.size(), placed.size(), "each one the demo placed, and only those")
	for c in placed:
		assert_true(creatures.has(c), "%s is in the creature group" % c.name)
	assert_gt(demo.pack.members.size(), 0, "the pack has its wolves")
	var grounded := 0
	for c in creatures:
		if (c as Creature).is_on_floor():
			grounded += 1
	assert_gte(grounded, int(creatures.size() * 0.8), "nearly everything is standing on the terrain (%d of %d)" % [grounded, creatures.size()])
	assert_true(demo.andras.alive)
	assert_eq(demo.andras.prey, demo.doe)
