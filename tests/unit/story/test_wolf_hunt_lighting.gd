extends GutTest
## Lane L18-11: the ch1 wolf hunt is lit so it reads (WolfHuntLighting): a
## shadowed break in the overcast over the doe's clearing and a cold rim on the
## doe and the great wolf, behind each from the camera; lights only, opening as
## the hunt runs and gone again after it.


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
	assert_null(_rig.cloud_break, "no rig until the hunt runs")


func test_the_cloud_breaks_over_the_doe_and_the_rims_sit_behind_them() -> void:
	_space.running = true
	_rig._process(0.1)
	_rig._process(WolfHuntLighting.OPEN_SECONDS)
	assert_almost_eq(_rig.amount, 1.0, 0.001)
	var brk := _rig.cloud_break
	assert_not_null(brk)
	assert_true(brk.shadow_enabled, "the trunks lay bars across the snow")
	assert_almost_eq(brk.light_energy, WolfHuntLighting.BREAK_ENERGY, 0.001)
	assert_gt(brk.global_position.y, _space.doe.global_position.y + 25.0, "from high in the overcast")
	var down := -brk.global_basis.z
	var to_doe := (_space.doe.global_position - brk.global_position).normalized()
	assert_gt(down.dot(to_doe), 0.99, "aimed at the doe's clearing")
	assert_gt(brk.spot_range, brk.global_position.distance_to(_space.doe.global_position), "reaches the snow")
	for pair in [[_rig.doe_rim, _space.doe], [_rig.wolf_rim, _space.wolf]]:
		var rim := pair[0] as SpotLight3D
		var actor := pair[1] as Node3D
		assert_true(rim.visible)
		assert_gt(rim.light_energy, 0.0)
		var cam_to_actor := actor.global_position - _cam.global_position
		var actor_to_rim := rim.global_position - actor.global_position
		cam_to_actor.y = 0.0
		actor_to_rim.y = 0.0
		assert_gt(cam_to_actor.normalized().dot(actor_to_rim.normalized()), 0.9, "%s's rim is behind it" % rim.name)
		assert_gt(rim.spot_range, rim.global_position.distance_to(actor.global_position + Vector3.UP * WolfHuntLighting.BODY_UP))


func test_the_light_follows_the_actors_and_hides_without_them() -> void:
	_space.running = true
	_rig._process(WolfHuntLighting.OPEN_SECONDS)
	_space.doe.global_position += Vector3(5, 0, 0)
	_rig._process(0.1)
	assert_almost_eq(_rig.cloud_break.global_position.x, _space.doe.global_position.x + WolfHuntLighting.BREAK_FROM.x, 0.01)
	_space.wolf.free()
	_rig._process(0.1)
	assert_false(_rig.wolf_rim.visible, "no rim on a freed wolf")


func test_the_cloud_closes_after_the_hunt() -> void:
	_space.running = true
	_rig._process(WolfHuntLighting.OPEN_SECONDS)
	_space.running = false
	_rig._process(WolfHuntLighting.CLOSE_SECONDS * 0.5)
	assert_almost_eq(_rig.amount, 0.5, 0.01, "closes slowly")
	_rig._process(WolfHuntLighting.CLOSE_SECONDS)
	await wait_process_frames(1)
	assert_null(_rig.cloud_break, "all its lights are gone")
	assert_eq(_space.find_children("*", "SpotLight3D", true, false).size(), 0)


func test_the_wolf_kill_space_carries_the_rig() -> void:
	var wk := WolfKill.new()
	add_child_autofree(wk)
	assert_eq(wk.find_children("*", "WolfHuntLighting", false, false).size(), 1)
