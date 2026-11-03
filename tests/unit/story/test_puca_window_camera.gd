## T067 contract (owner): when the puca shows itself under her window and she
## goes down to the hedges to him, the camera is hers to pan, on the stick and
## the mouse (both turn it through Feyre._look; the stick is driven here, as
## headless runs cannot capture the mouse). The window framing finds him for a moment only; after that no
## pull holds the camera on him while she walks the house and the garden.
extends GutTest

## Her room is upstairs: the window's anchor and her floor, over the lawn.
const ROOM_Y := 5.0

var feyre: Feyre
var space: PucaLure
var _clock_saved: Dictionary


func before_each() -> void:
	WorldState.clear()
	StoryControl.release()
	_clock_saved = Clock.to_dict()
	Clock.paused = true
	for global_space in StoryDirector.get_children():
		(global_space as SceneSpace).auto_tick = false
	var root := Node3D.new()
	add_child_autofree(root)
	space = Act2Spaces.space_for(StoryDirector.get_moment(&"puca")) as PucaLure
	space.position = Vector3(12, 0, -30)
	root.add_child(space)
	var room := Node3D.new()
	room.add_to_group(&"story_anchor")
	room.set_meta(&"anchor_id", PucaLure.WINDOW_ANCHOR)
	root.add_child(room)
	var house := space.mark(&"house")
	room.global_position = Vector3(house.x, ManorGrounds.ground(house.x, house.z) + ROOM_Y, house.z)
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200, 1, 200)
	shape.shape = box
	floor_body.add_child(shape)
	root.add_child(floor_body)
	floor_body.global_position = room.global_position - Vector3(0, 0.5, 0)
	feyre = (load("res://characters/feyre/feyre.tscn") as PackedScene).instantiate() as Feyre
	root.add_child(feyre)
	feyre.global_position = room.global_position + Vector3(0, 0.05, 0)
	WorldState.set_flag("bogge_survived")
	Clock.from_dict({"time_of_day": 0.95, "day": 3})


func after_each() -> void:
	for a in [&"look_right", &"move_forward"]:
		Input.action_release(a)
	for global_space in StoryDirector.get_children():
		(global_space as SceneSpace).auto_tick = true
	StoryControl.release()
	Clock.from_dict(_clock_saved)
	Clock.paused = false


## Signed yaw (rad) from where the camera faces to where he stands.
func _off_him() -> float:
	var to := space.puca().global_position - feyre.global_position
	return angle_difference(feyre.camera_yaw(), atan2(-to.x, -to.z))


func test_after_the_window_moment_the_camera_stays_where_she_pans_it() -> void:
	assert_true(space.start())
	await wait_seconds(0.3)
	assert_eq(StoryControl.focus, space.puca() as Node3D, "from the window the camera finds him")
	await wait_seconds(PucaLure.SEE_HIM_AFTER + 0.3)
	assert_eq(space.current_beat_label(), "she goes down to him", "she knows him; now she has to go down")
	# Stick look: turn away from him, then let go and walk.
	Input.action_press(&"look_right")
	await wait_seconds(0.6)
	Input.action_release(&"look_right")
	var stick_off := absf(_off_him())
	assert_gt(stick_off, 0.6, "the stick turns the camera off him (%.2f rad)" % stick_off)
	Input.action_press(&"move_forward")
	await wait_seconds(1.5)
	Input.action_release(&"move_forward")
	assert_gt(absf(_off_him()), stick_off - 0.15,
			"no pull back to him after a stick pan (%.2f -> %.2f rad)" % [stick_off, absf(_off_him())])
	assert_null(StoryControl.focus, "nothing holds the camera on him")
