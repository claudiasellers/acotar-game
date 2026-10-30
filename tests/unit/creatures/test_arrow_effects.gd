extends GutTest
## Definition of done: sleep stops a creature then wears off, barbed bleeds and
## slows, lure draws calm prey to the arrow and leaves fleeing prey alone.

const RABBIT := preload("res://creatures/ambient/scenes/rabbit.tscn")


func _rabbit(at: Vector3) -> Prey:
	var r := RABBIT.instantiate() as Prey
	add_child_autofree(r)
	r.global_position = at
	r.home = at
	r._wander_target = at
	return r


func _arrow(at: Vector3) -> Node3D:
	var a := Node3D.new()
	add_child_autofree(a)
	a.global_position = at
	return a


func test_sleep_holds_still_then_wears_off() -> void:
	var r := _rabbit(Vector3.ZERO)
	r.on_arrow_effect(&"sleep", _arrow(Vector3.ZERO))
	r._start_flee(Vector3(5, 0, 0))
	r._physics_process(0.1)
	assert_eq(r.move_speed, 0.0, "asleep: no running")
	r.asleep_left = 0.05
	r._physics_process(0.1)
	r._physics_process(0.1)
	assert_gt(r.move_speed, 0.0, "awake again and still fleeing")


func test_fae_shrug_off_most_of_the_sleep() -> void:
	var r := _rabbit(Vector3.ZERO)
	r.data = r.data.duplicate()
	r.data.fae = true
	r.on_arrow_effect(&"sleep", _arrow(Vector3.ZERO))
	assert_lt(r.asleep_left, Creature.SLEEP_TIME * 0.5)


func test_barbed_bleeds_and_slows() -> void:
	var r := _rabbit(Vector3.ZERO)
	r.on_arrow_effect(&"barbed", _arrow(Vector3.ZERO))
	r._start_flee(Vector3(5, 0, 0))
	r._physics_process(0.1)
	assert_gt(r.bleeding, 0.0)
	assert_lt(r.move_speed, r.data.run_speed * 0.6)


func test_lure_draws_calm_prey_but_not_fleeing_prey() -> void:
	var calm := _rabbit(Vector3(10, 0, 0))
	var scared := _rabbit(Vector3(-10, 0, 0))
	scared._start_flee(Vector3(-12, 0, 0))
	var far := _rabbit(Vector3(80, 0, 0))
	Creature.lure(get_tree(), Vector3.ZERO)
	assert_eq(calm._wander_target, Vector3.ZERO)
	assert_eq(scared.state, Prey.State.FLEE)
	assert_ne(far._wander_target, Vector3.ZERO, "out of reach")
