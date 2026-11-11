## Contract (T093): at the curtain trap's "E rig the rope" step, and once it is
## rigged, her camera stays inside her bedroom, clear of the south wall, looking
## at her and the door from the room side. Built on the real CurtainTrap and the
## real Feyre camera, in a box with the bedroom's south wall and doorway where
## upper.tres puts them (0.25 m wall, inner face at trap-local z 18.15, a 1.6 m
## opening at x 0) and Feyre where the playtest stops her at the door.
# gate: when:story/act2/curtain_trap.gd,story/act2/act2_spaces.gd,data/story/moments/curtain_trap.tres,data/story/act2/curtain_trap_stage.tres,art/bedroom/*,characters/feyre/*
extends GutTest

const FEYRE := preload("res://characters/feyre/feyre.tscn")
const STEP := 0.1
## Where the T091 played run stood her at the rig step (trap-local).
const AT_DOOR := Vector3(-0.25, 0.05, 17.67)

var anchor: Marker3D


func before_each() -> void:
	WorldState.clear()
	StoryControl.release()
	CameraFade.headless_opt_in = true
	Clock.paused = true
	Clock.from_dict({"time_of_day": 0.95, "day": 3})
	WorldState.set_flag("wall_crossed")
	WorldState.set_flag("first_dinner_eaten")
	anchor = Marker3D.new()
	anchor.name = "feyre_bedroom_window"
	anchor.set_meta(&"anchor_id", &"feyre_bedroom_window")
	anchor.add_to_group(&"story_anchor")
	add_child_autofree(anchor)
	StoryDirector.attach_anchor(anchor)
	trap().auto_tick = false
	trap().instant_fades = true


func after_each() -> void:
	StoryControl.release()
	CameraFade.headless_opt_in = false
	Clock.paused = false


func trap() -> CurtainTrap:
	return anchor.get_node(^"Moment_curtain_trap") as CurtainTrap


func _slab(center: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	anchor.add_child(body)
	body.position = center


## Floor, ceiling, and the south wall (z 18.15..18.4) with her 1.6 m doorway.
func _bedroom() -> void:
	_slab(Vector3(0, -0.5, 8), Vector3(14, 1, 20))
	_slab(Vector3(0, 4.15, 8), Vector3(14, 0.3, 20))
	var z := 18.4 - 0.125
	_slab(Vector3(-3.9, 2, z), Vector3(6.2, 4, 0.25))
	_slab(Vector3(3.9, 2, z), Vector3(6.2, 4, 0.25))
	_slab(Vector3(0, 3.4, z), Vector3(1.6, 1.2, 0.25))


func _tick(seconds: float, until: Callable) -> bool:
	for _i in int(seconds / STEP):
		trap().tick(STEP)
		if until.call():
			return true
	return bool(until.call())


func test_the_camera_stays_in_her_room_at_the_rig_step() -> void:
	_bedroom()
	var f := FEYRE.instantiate() as Feyre
	add_child_autofree(f)
	f.teleport(trap().to_global(Vector3(0, 0.05, 8)))
	assert_true(trap().start())
	assert_true(_tick(5.0, func() -> bool: return trap().current_beat_label() == "reach door_inside"))
	# She walked south to the door: the camera behind her, in the room.
	f.teleport(trap().to_global(AT_DOOR))
	f.nudge_camera(angle_difference(f.camera_yaw(), PI), 0.0)
	assert_true(_tick(2.0, func() -> bool: return trap().current_beat_label() == "until she rigs it"))
	await wait_seconds(3.0)
	var cam := f.camera.global_position
	assert_true(trap().camera_in_room(cam), "rig step: camera at trap-local %s, in the room clear of the walls" % trap().to_local(cam))
	assert_lt(trap().to_local(cam).z, trap().to_local(f.global_position).z, "on the room side of her, the door beyond")
	trap().press_interact()
	assert_true(_tick(2.0, func() -> bool: return trap().rigged))
	await wait_seconds(2.0)
	cam = f.camera.global_position
	assert_true(trap().camera_in_room(cam), "rigged: camera at trap-local %s" % trap().to_local(cam))
