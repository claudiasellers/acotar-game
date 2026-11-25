## Health-interactions §3.5 #5: a wind-up she can't see is warned once, with
## its side and its time to contact; one in view is not.
extends GutTest

const ROAMER := preload("res://creatures/hostile/naga_roamer.tscn")

var her: Node3D
var camera: Camera3D
var watch: OffscreenWarning
var warnings: Array = []


func before_each() -> void:
	for group: StringName in [Creature.GROUP, &"player"]:
		for stale in get_tree().get_nodes_in_group(group):
			stale.remove_from_group(group)
	warnings.clear()
	her = Node3D.new()
	her.add_to_group(&"player")
	add_child_autofree(her)
	camera = Camera3D.new()
	add_child_autofree(camera)
	camera.global_position = Vector3(0, 1.6, 3.0)
	camera.make_current()
	watch = OffscreenWarning.new()
	add_child_autofree(watch)
	watch.set_physics_process(false)
	watch.warned.connect(func(side: float, seconds: float) -> void: warnings.append([side, seconds]))
	await wait_frames(2)


func _naga(at: Vector3) -> NagaRoamer:
	var n: NagaRoamer = ROAMER.instantiate()
	add_child_autofree(n)
	n.set_physics_process(false)
	n.global_position = at
	return n


func _wind_up(n: NagaRoamer, attack: StringName = &"naga_claw") -> void:
	n.fight = NagaRoamer.Fight.STRIKE
	n._attack = attack


func test_one_behind_her_is_warned_once_with_its_time() -> void:
	var n := _naga(Vector3(0, 0, 8.0))
	watch.watch()
	assert_eq(warnings.size(), 0, "nothing is winding up")
	_wind_up(n)
	watch.watch()
	watch.watch()
	assert_eq(warnings.size(), 1, "once for the wind-up, not every frame")
	assert_almost_eq(float(warnings[0][0]), 0.0, 0.01, "straight behind")
	assert_eq(float(warnings[0][1]), AttackTable.resolve(&"naga_claw").windup_s)
	assert_gte(float(warnings[0][1]), 0.4, "time enough to act on")


func test_the_side_it_comes_from() -> void:
	_wind_up(_naga(Vector3(-9.0, 0, 3.0)))
	watch.watch()
	_wind_up(_naga(Vector3(9.0, 0, 3.0)))
	watch.watch()
	assert_eq(warnings.size(), 2)
	assert_lt(float(warnings[0][0]), -0.9, "left")
	assert_gt(float(warnings[1][0]), 0.9, "right")


func test_one_she_can_see_needs_no_warning() -> void:
	_wind_up(_naga(Vector3(0, 0, -6.0)))
	watch.watch()
	assert_eq(warnings.size(), 0)


func test_far_off_is_nobodys_business() -> void:
	_wind_up(_naga(Vector3(0, 0, 30.0)))
	watch.watch()
	assert_eq(warnings.size(), 0)


func test_its_next_wind_up_is_warned_again() -> void:
	var n := _naga(Vector3(0, 0, 8.0))
	_wind_up(n)
	watch.watch()
	n.fight = NagaRoamer.Fight.CIRCLE
	watch.watch()
	_wind_up(n, &"naga_lunge")
	watch.watch()
	assert_eq(warnings.size(), 2)
	assert_eq(float(warnings[1][1]), AttackTable.resolve(&"naga_lunge").windup_s)
