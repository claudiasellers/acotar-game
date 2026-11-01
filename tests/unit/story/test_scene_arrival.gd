## Scenes start when Feyre walks into them, whatever the hour: a night scene
## by day (or a day scene by night) brings its hour to her and then starts.
extends GutTest

var player: CharacterBody3D
var _saved: Dictionary


func before_each() -> void:
	WorldState.clear()
	StoryControl.release()
	_saved = Clock.to_dict()
	Clock.paused = true
	player = CharacterBody3D.new()
	player.add_to_group(&"player")
	add_child_autofree(player)


func after_each() -> void:
	Clock.from_dict(_saved)
	Clock.paused = false
	StoryControl.release()


func _space(at: Vector3, radius: float) -> SceneSpace:
	var space := SceneSpace.new()
	space.space_id = &"test_arrival"
	space.arrive_radius = radius
	add_child_autofree(space)
	space.global_position = at
	return space


func test_walking_into_a_day_scene_starts_it() -> void:
	Clock.from_dict({"time_of_day": 0.5, "day": 1})
	var space := _space(Vector3(100, 0, 0), 20.0)
	watch_signals(space)
	await wait_physics_frames(2)
	assert_signal_not_emitted(space, "started", "too far")
	player.global_position = Vector3(85, 7, 0)
	await wait_physics_frames(2)
	assert_signal_emitted(space, "started", "15 m away, 7 m up: she's arrived")


func test_a_night_scene_by_day_brings_the_night_then_starts() -> void:
	Clock.from_dict({"time_of_day": 0.5, "day": 4})
	var space := _space(Vector3.ZERO, 10.0)
	space.night_only = true
	watch_signals(space)
	await wait_physics_frames(2)
	assert_true(space.shifting_time, "the evening falls for her")
	assert_eq(StoryControl.mode, StoryControl.Mode.NONE, "held through the fade")
	await wait_seconds(TimeShift.FADE + TimeShift.HOLD + 0.4)
	assert_true(Clock.is_night())
	assert_eq(Clock.day, 4, "the same evening, not tomorrow")
	assert_signal_emitted(space, "started")


func test_a_day_scene_by_night_brings_the_morning() -> void:
	Clock.from_dict({"time_of_day": 22.0 / 24.0, "day": 2})
	var space := _space(Vector3.ZERO, 10.0)
	space.day_only = true
	watch_signals(space)
	await wait_physics_frames(2)
	await wait_seconds(TimeShift.FADE + TimeShift.HOLD + 0.4)
	assert_false(Clock.is_night())
	assert_almost_eq(Clock.hour(), 8.0, 0.1)
	assert_eq(Clock.day, 3, "the next morning")
	assert_signal_emitted(space, "started")


func test_unmet_requirements_never_shift_the_hour() -> void:
	Clock.from_dict({"time_of_day": 0.5, "day": 1})
	var space := _space(Vector3.ZERO, 10.0)
	space.night_only = true
	space.require_flags = PackedStringArray(["pelt_sold"])
	await wait_physics_frames(3)
	assert_false(space.shifting_time)
	assert_almost_eq(Clock.time_of_day, 0.5, 0.001)


func test_the_hunt_starts_within_sight_of_the_doe() -> void:
	Clock.from_dict({"time_of_day": 0.3, "day": 1})
	var hunt := WolfKill.new()
	add_child_autofree(hunt)
	var doe_spot := hunt.global_transform * hunt.doe_offset
	player.global_position = doe_spot + Vector3(0, 12, 70)
	await wait_physics_frames(2)
	assert_false(hunt.running, "70 m out: not yet")
	player.global_position = doe_spot + Vector3(0, 12, 50)
	await wait_physics_frames(2)
	assert_true(hunt.running, "50 m from the doe, on a slope above: the hunt is on")
