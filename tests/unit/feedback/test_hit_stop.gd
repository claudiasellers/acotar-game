## Health-interactions §3.5 #6: every hit, both ways, holds TimeScale at 0.05
## for 4 to 10 frames of real time by reaction and zone, and time always
## returns to the next-lowest request afterwards.
extends GutTest

const FRAME := 1.0 / 60.0

var stop: HitStop
var vitals: VitalsState
var strike: StrikeController


func before_each() -> void:
	TimeScale.reset()
	GameSettings.set_value(&"reduced_effects", false)
	GameSettings.set_value(HitStop.SETTING, 0)
	vitals = VitalsState.new()
	add_child_autofree(vitals)
	strike = StrikeController.new()
	strike.player = Node3D.new()
	add_child_autofree(strike.player)
	add_child_autofree(strike)
	stop = HitStop.new()
	stop.vitals = vitals
	stop.strike = strike
	add_child_autofree(stop)


func after_each() -> void:
	GameSettings.set_value(&"reduced_effects", false)
	GameSettings.set_value(HitStop.SETTING, 0)
	TimeScale.reset()


## Real seconds the freeze now running lasts: what it asked for as it began
## (within a frame of `frames`), and then waited out on the wall clock, which
## may run a little over on a busy machine but never under.
func _held(frames: int = -1, what: String = "") -> float:
	var began := Time.get_ticks_usec()
	var asked := stop.left()
	if frames >= 0:
		assert_almost_eq(asked, frames * FRAME, FRAME, "%s asks for %d frames" % [what, frames])
	while stop.active() and Time.get_ticks_usec() - began < 1000000:
		await get_tree().process_frame
	var took := (Time.get_ticks_usec() - began) / 1000000.0
	if frames >= 0:
		assert_between(took, asked - 0.002, asked + 6.0 * FRAME, "%s holds for what it asked" % what)
	return took


func test_frames_by_reaction_and_zone() -> void:
	assert_eq(HitStop.frames(&"light"), 4)
	assert_eq(HitStop.frames(&"medium"), 6)
	assert_eq(HitStop.frames(&"heavy"), 9)
	assert_eq(HitStop.frames(&"light", true), 7)
	assert_eq(HitStop.frames(&"heavy", true), 12)
	assert_eq(HitStop.frames(&"light", false, true), 10)
	assert_eq(HitStop.frames(&"none", true), 0)


func test_an_arrow_in_the_body_holds_four_frames_at_the_slow_scale() -> void:
	EventBus.creature_hit.emit(&"naga_1", &"naga", &"arrow_wood", &"body")
	assert_eq(Engine.time_scale, HitStop.SCALE)
	await _held(4, "body")
	assert_eq(Engine.time_scale, 1.0)


func test_a_weak_spot_holds_seven_and_a_kill_ten() -> void:
	EventBus.creature_hit.emit(&"naga_1", &"naga", &"arrow_wood", &"throat")
	await _held(7, "weak spot")
	EventBus.creature_hit.emit(&"naga_1", &"naga", &"arrow_wood", &"body")
	EventBus.creature_killed.emit(&"naga_1", &"naga", &"arrow_wood", Vector3.ZERO)
	await _held(10, "kill")


func test_a_mortal_wound_running_out_later_freezes_nothing() -> void:
	EventBus.creature_hit.emit(&"wolf", &"wolf", &"arrow_ash", &"body")
	await _held()
	await get_tree().process_frame
	EventBus.creature_killed.emit(&"wolf", &"wolf", &"arrow_ash", Vector3.ZERO)
	assert_false(stop.active())


func test_what_she_did_not_do_freezes_nothing() -> void:
	EventBus.creature_hit.emit(&"deer", &"deer", &"wolf_bite", &"body")
	EventBus.creature_killed.emit(&"deer", &"deer", &"fire", Vector3.ZERO)
	assert_false(stop.active())
	assert_eq(Engine.time_scale, 1.0)


func test_the_bash_and_the_knife_by_how_hard_they_land() -> void:
	var c := Creature.new()
	autofree(c)
	EventBus.creature_hit.emit(&"naga_1", &"naga", &"bow_bash", &"body")
	strike.struck.emit(&"bash", c)
	await _held(6, "bash")
	EventBus.creature_hit.emit(&"naga_1", &"naga", &"knife", &"body")
	strike.struck.emit(&"knife", c)
	await _held(4, "knife")
	EventBus.creature_hit.emit(&"naga_1", &"naga", &"knife", &"body")
	strike.struck.emit(&"sneak", c)
	await _held(9, "sneak")
	strike.struck.emit(&"cut", null)
	assert_false(stop.active(), "cutting a snare is no hit")


func test_a_blow_on_her_holds_by_its_reaction() -> void:
	vitals.hit_taken.emit(Vector3.INF, 22.0, &"light")
	await _held(4, "light")
	vitals.hit_taken.emit(Vector3.INF, 30.0, &"medium")
	await _held(6, "medium")
	vitals.hit_taken.emit(Vector3.INF, 45.0, &"heavy")
	await _held(9, "heavy")


func test_a_blow_from_out_of_view_gets_none() -> void:
	var camera := Camera3D.new()
	add_child_autofree(camera)
	camera.make_current()
	await get_tree().process_frame
	vitals.hit_taken.emit(camera.global_position + camera.global_basis.z * 5.0, 22.0, &"light")
	assert_false(stop.active(), "behind the lens")
	vitals.hit_taken.emit(camera.global_position - camera.global_basis.z * 5.0, 22.0, &"light")
	assert_true(stop.active(), "in front of it")


func test_time_returns_to_focus_not_to_full_speed() -> void:
	TimeScale.request(&"bow_slow", 0.4)
	stop.hit(&"light")
	assert_eq(Engine.time_scale, HitStop.SCALE, "the freeze wins while it holds")
	await _held()
	assert_eq(Engine.time_scale, 0.4)


func test_a_longer_freeze_is_not_cut_short_by_a_shorter_one() -> void:
	stop.hit(&"heavy")
	stop.hit(&"light")
	await _held(9, "heavy then light")


func test_reduced_effects_halves_it() -> void:
	GameSettings.set_value(&"reduced_effects", true)
	stop.hit(&"medium")
	await _held(3, "half of six")


func test_the_setting_is_full_half_or_off() -> void:
	assert_eq(GameSettings.HIT_STOP_LEVELS, ["Full", "Half", "Off"] as Array[String])
	GameSettings.set_value(HitStop.SETTING, 1)
	stop.hit(&"heavy")
	await _held(4, "half of nine")
	GameSettings.set_value(HitStop.SETTING, 2)
	stop.hit(&"heavy", true)
	assert_false(stop.active(), "off")
	assert_eq(Engine.time_scale, 1.0)


func test_leaving_the_tree_lets_time_go() -> void:
	stop.hit(&"heavy")
	remove_child(stop)
	assert_eq(Engine.time_scale, 1.0)
	add_child(stop)


func test_only_time_scale_writes_engine_time() -> void:
	var out: Array = []
	OS.execute("grep", ["-rln", "--include=*.gd", "Engine.time_scale =", ProjectSettings.globalize_path("res://systems"),
		ProjectSettings.globalize_path("res://characters"), ProjectSettings.globalize_path("res://creatures"),
		ProjectSettings.globalize_path("res://story"), ProjectSettings.globalize_path("res://ui"),
		ProjectSettings.globalize_path("res://world")], out)
	var files := Array(String(out[0]).strip_edges().split("\n", false))
	assert_eq(files.size(), 1, str(files))
	assert_true(files.size() == 1 and String(files[0]).ends_with("systems/feedback/time_scale.gd"))
