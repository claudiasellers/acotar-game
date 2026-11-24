extends GutTest
## Lane L18: the ch1 wolf hunt's rim light (WolfHuntLighting): a cold rim on
## the doe and the great wolf, behind each from the camera, while the hunt
## runs; nothing lights the clearing itself (L18-14).


class FakeHuntSpace:
	extends Node3D
	var running: bool = false
	var space_id: StringName = &"wolf_kill"
	var doe: Node3D
	var wolf: Node3D


var _space: FakeHuntSpace
var _cam: Camera3D
var _rig: WolfHuntLighting


func before_each() -> void:
	_space = FakeHuntSpace.new()
	add_child_autofree(_space)
	_space.global_position = Vector3(0, 300, 0)
	_space.doe = Node3D.new()
	_space.add_child(_space.doe)
	_space.doe.global_position = Vector3(0, 300, -22)
	_space.wolf = Node3D.new()
	_space.add_child(_space.wolf)
	_space.wolf.global_position = Vector3(14, 300, -30)
	_cam = Camera3D.new()
	_space.add_child(_cam)
	_cam.global_position = Vector3(0, 302, 4)
	_cam.make_current()
	_rig = WolfHuntLighting.new()
	_space.add_child(_rig)
	await wait_process_frames(1)


func test_nothing_lit_before_the_hunt() -> void:
	_rig._process(1.0)
	assert_null(_rig.doe_rim, "no rig until the hunt runs")


func test_only_the_two_rims_and_they_sit_behind_the_actors() -> void:
	_space.running = true
	_rig._process(0.1)
	_rig._process(WolfHuntLighting.FADE_IN)
	assert_almost_eq(_rig.amount, 1.0, 0.001)
	var lights := _space.find_children("*", "Light3D", true, false)
	assert_eq(lights.size(), 2, "no light on the clearing, only the rims")
	for pair in [[_rig.doe_rim, _space.doe], [_rig.wolf_rim, _space.wolf]]:
		var rim := pair[0] as SpotLight3D
		var actor := pair[1] as Node3D
		assert_true(rim.visible)
		assert_almost_eq(rim.light_energy, WolfHuntLighting.RIM_ENERGY, 0.001)
		assert_false(rim.shadow_enabled)
		var cam_to_actor := actor.global_position - _cam.global_position
		var actor_to_rim := rim.global_position - actor.global_position
		cam_to_actor.y = 0.0
		actor_to_rim.y = 0.0
		assert_gt(cam_to_actor.normalized().dot(actor_to_rim.normalized()), 0.9, "%s is behind it" % rim.name)
		var body := actor.global_position + Vector3.UP * WolfHuntLighting.BODY_UP
		assert_gt(rim.spot_range, rim.global_position.distance_to(body))
		assert_lt(rim.spot_range, 10.0, "a short rim that can't reach the snow far round it")


func test_the_rims_follow_and_hide_without_their_actor() -> void:
	_space.running = true
	_rig._process(WolfHuntLighting.FADE_IN)
	_space.doe.global_position += Vector3(5, 0, 0)
	_rig._process(0.1)
	assert_gt(_rig.doe_rim.global_position.x, 4.0, "the doe's rim went with her")
	_space.wolf.free()
	_rig._process(0.1)
	assert_false(_rig.wolf_rim.visible, "no rim on a freed wolf")


func test_the_rims_go_after_the_hunt() -> void:
	_space.running = true
	_rig._process(WolfHuntLighting.FADE_IN)
	_space.running = false
	_rig._process(WolfHuntLighting.FADE_OUT * 0.5)
	assert_almost_eq(_rig.amount, 0.5, 0.01, "fades slowly")
	_rig._process(WolfHuntLighting.FADE_OUT)
	await wait_process_frames(1)
	assert_null(_rig.doe_rim, "all its lights are gone")
	assert_eq(_space.find_children("*", "SpotLight3D", true, false).size(), 0)


func test_the_wolf_kill_space_carries_the_rig() -> void:
	var wk := WolfKill.new()
	add_child_autofree(wk)
	assert_eq(wk.find_children("*", "WolfHuntLighting", false, false).size(), 1)
