## Health-interactions §3.5 #5: a wind-up she can't see beats the HUD's edge
## on its side for its time to contact; one in view does not; one cut short
## calls it off.
extends GutTest

var her: Node3D
var camera: Camera3D
var watch: OffscreenWarning
var edge: VitalsEdgeFx


func before_each() -> void:
	GameSettings.set_value(&"hit_marks", true)
	her = Node3D.new()
	add_child_autofree(her)
	camera = Camera3D.new()
	add_child_autofree(camera)
	camera.global_position = Vector3(0, 1.6, 3.0)
	camera.make_current()
	edge = VitalsEdgeFx.new()
	add_child_autofree(edge)
	edge.set_process(false)
	watch = OffscreenWarning.new()
	watch.player = her
	add_child_autofree(watch)
	await wait_frames(2)


func _wind_up(at: Vector3, id: StringName = &"naga_1", seconds: float = 0.55) -> void:
	EventBus.hostile_windup.emit(id, &"naga", &"naga_claw", at, seconds)


func _side() -> float:
	return float(edge._mat.get_shader_parameter(&"warn_side"))


func test_one_behind_her_beats_the_edge_for_its_time() -> void:
	_wind_up(Vector3(0, 0, 8.0))
	assert_almost_eq(edge._warn_left, 0.55, 0.001)
	assert_almost_eq(_side(), 0.0, 0.01, "straight behind")


func test_the_side_it_comes_from() -> void:
	_wind_up(Vector3(-9.0, 0, 3.0))
	assert_lt(_side(), -0.9, "left")
	_wind_up(Vector3(9.0, 0, 3.0))
	assert_gt(_side(), 0.9, "right")


func test_one_she_can_see_needs_no_warning() -> void:
	_wind_up(Vector3(0, 0, -6.0))
	assert_eq(edge._warn_left, 0.0)


func test_far_off_is_nobodys_business() -> void:
	_wind_up(Vector3(0, 0, 30.0))
	assert_eq(edge._warn_left, 0.0)


func test_a_wind_up_cut_short_calls_it_off() -> void:
	_wind_up(Vector3(0, 0, 8.0), &"naga_1")
	EventBus.hostile_windup_cancelled.emit(&"naga_2")
	assert_gt(edge._warn_left, 0.0, "another's stagger changes nothing")
	EventBus.hostile_windup_cancelled.emit(&"naga_1")
	assert_eq(edge._warn_left, 0.0)


func test_the_real_naga_says_when_it_winds_up() -> void:
	watch_signals(EventBus)
	var naga: NagaRoamer = preload("res://creatures/hostile/naga_roamer.tscn").instantiate()
	add_child_autofree(naga)
	naga.set_physics_process(false)
	naga.global_position = Vector3(0, 0, 8.0)
	naga._wind_up(NagaRoamer.Fight.STRIKE, NagaRoamer.CLAW)
	assert_signal_emitted(EventBus, "hostile_windup")
	assert_almost_eq(edge._warn_left, AttackTable.resolve(NagaRoamer.CLAW).windup_s, 0.001)
