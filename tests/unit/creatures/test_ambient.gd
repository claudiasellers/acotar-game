extends GutTest

const BUTTERFLIES := preload("res://creatures/ambient/scenes/butterflies.tscn")
const SWAN := preload("res://creatures/ambient/scenes/swan.tscn")


func test_swarm_is_one_multimesh_with_every_flier() -> void:
	var swarm := BUTTERFLIES.instantiate() as AmbientSwarm
	add_child_autofree(swarm)
	assert_eq(swarm.multimesh.instance_count, 40)
	assert_eq(swarm.find_children("*", "MultiMeshInstance3D", true, false).size(), 1)
	assert_gt(swarm.multimesh.mesh.get_surface_count(), 0, "the Blender butterfly mesh loaded")


func test_fliers_stay_in_their_cloud() -> void:
	var swarm := BUTTERFLIES.instantiate() as AmbientSwarm
	add_child_autofree(swarm)
	for i in swarm.count:
		for t in [0.0, 13.7, 120.0]:
			var p := swarm.offset_at(i, t)
			assert_lte(Vector2(p.x, p.z).length(), swarm.radius * 1.42)
			assert_between(p.y, swarm.min_height - 0.001, swarm.max_height + 0.001)


func test_swan_floats_at_the_water_level() -> void:
	var swan := SWAN.instantiate() as Swan
	swan.water_level = 2.5
	add_child_autofree(swan)
	for i in 30:
		swan._physics_process(0.1)
	assert_almost_eq(swan.global_position.y, 2.5, 0.05)


func test_lamb_barely_startles() -> void:
	var lamb := preload("res://creatures/ambient/scenes/lamb.tscn").instantiate() as Prey
	add_child_autofree(lamb)
	CreatureSenses.emit_noise(get_tree(), lamb.global_position + Vector3(10, 0, 0), 0.5)
	assert_ne(lamb.state, Prey.State.FLEE)
