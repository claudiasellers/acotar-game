extends GutTest
## Lane L22: the ride north's staging (RideNorthStaging), camera only.


class FakeRideSpace:
	extends Node3D
	var running: bool = true
	var space_id: StringName = &"ride_north"
	var horse: Node3D
	var veil: ColorRect


var _player: Node3D
var _player_cam: Camera3D


func before_each() -> void:
	StoryControl.release()
	StoryControl.set_focus(null)
	_player = Node3D.new()
	_player.name = "FakeFeyre"
	_player.add_to_group(&"player")
	add_child(_player)
	_player_cam = Camera3D.new()
	_player_cam.fov = 70.0
	_player.add_child(_player_cam)
	_player_cam.global_position = Vector3(0, 1.6, 4)
	_player_cam.current = true
	_player.set(&"camera", _player_cam)


func after_each() -> void:
	var cine := get_tree().root.get_node_or_null(^"Cine")
	if cine:
		cine.free()
	_player.free()
	StoryControl.release()
	StoryControl.shake = 0.0


func test_ride_north_staging_follows_the_rider_through_the_teleport() -> void:
	var space := FakeRideSpace.new()
	add_child_autofree(space)
	var horse := Node3D.new()
	space.add_child(horse)
	horse.global_position = Vector3(0, 500, 0)
	space.horse = horse
	_player.global_position = horse.global_position + Vector3.UP * 1.1
	var staging := RideNorthStaging.new()
	space.add_child(staging)
	StoryControl.set_mode(StoryControl.Mode.LOOK)
	await wait_process_frames(1)
	var cine := Cine.of(get_tree())
	EventBus.story_actor_cue.emit(&"tamlin_beast", &"lead")
	await wait_process_frames(2)
	assert_eq(staging.shot_name, &"open")
	assert_eq(cine.target_kind, &"rig")
	# The camera rides along with the horse.
	for i in 20:
		horse.global_position += Vector3(0, 0, -0.3)
		_player.global_position = horse.global_position + Vector3.UP * 1.1
		await wait_process_frames(1)
	assert_lt(cine.camera.global_position.distance_to(horse.global_position), 12.0, "carried with them")
	EventBus.mood_requested.emit(&"enchanted_sleep", 1.0, 2.5)
	assert_eq(staging.shot_name, &"sleep")
	EventBus.grade_swap_requested.emit(&"spring", 2.0)
	assert_eq(staging.shot_name, &"wall")
	# The fade and the move to the sentry gate.
	var veil := ColorRect.new()
	veil.modulate.a = 1.0
	space.add_child(veil)
	space.veil = veil
	await wait_process_frames(3)
	assert_eq(staging.shot_name, &"dark")
	assert_true(_player_cam.current, "her camera in the dark")
	horse.global_position += Vector3(400, 0, 300)
	_player.global_position = horse.global_position + Vector3.UP * 1.1
	veil.modulate.a = 0.5
	await wait_process_frames(3)
	assert_eq(staging.shot_name, &"drive")
	assert_lt(cine.camera.global_position.distance_to(horse.global_position), 12.0, "cut with them to the gate")
	EventBus.story_actor_cue.emit(&"tamlin_beast", &"leave")
	assert_eq(staging.shot_name, &"released", "never past the dismount")
	await wait_seconds(1.5)
	assert_true(_player_cam.current)
	assert_eq(StoryControl.mode, StoryControl.Mode.LOOK, "camera only")
