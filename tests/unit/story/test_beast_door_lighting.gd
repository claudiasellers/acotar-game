extends GutTest
## Lane L55: the beast at the door is lit so he reads under the dread grade
## (BeastDoorLighting): moon through the door from outside, the hearth turned
## up, a rim behind his head; lights only, all gone again after the scene.


class FakeBeastSpace:
	extends Node3D
	var running: bool = true
	var space_id: StringName = &"beast_door"
	var beast: Node3D


class Flicker:
	extends OmniLight3D
	var _base := 0.0


var _space: FakeBeastSpace
var _door: Marker3D
var _fire: Flicker
var _beast: Node3D
var _rig: BeastDoorLighting


func before_each() -> void:
	_space = FakeBeastSpace.new()
	add_child_autofree(_space)
	_space.global_position = Vector3(0, 300, 0)
	# The door anchor: its +Z points outside (as BeastDoor places him).
	_door = Marker3D.new()
	_door.set_meta(&"anchor_id", &"act1_cottage_door")
	_door.add_to_group(&"story_anchor")
	_space.add_child(_door)
	_door.global_position = Vector3(0, 300, -3)
	var hearth := Node3D.new()
	hearth.add_to_group(&"hearth")
	_space.add_child(hearth)
	hearth.global_position = Vector3(3.5, 300, 0)
	_fire = Flicker.new()
	_fire.light_energy = 1.8
	_fire._base = 1.8
	hearth.add_child(_fire)
	_beast = Node3D.new()
	_space.add_child(_beast)
	_beast.global_position = Vector3(0, 300, -1)
	_space.beast = _beast
	_rig = BeastDoorLighting.new()
	_space.add_child(_rig)
	await wait_process_frames(1)


func test_nothing_lights_before_the_door_breaks() -> void:
	assert_null(_rig.moon)
	assert_null(_rig.rim)
	assert_almost_eq(_fire.light_energy, 1.8, 0.001)


func test_the_door_breaks_into_moon_fire_and_rim() -> void:
	EventBus.story_actor_cue.emit(&"tamlin_beast", &"enter")
	await wait_seconds(BeastDoorLighting.FADE_IN + BeastDoorLighting.FLARE_SECONDS + 0.2)
	assert_almost_eq(_rig.amount, 1.0, 0.001)
	# The moon hangs outside the door and shines in.
	var moon := _rig.moon
	assert_not_null(moon)
	assert_true(moon.shadow_enabled, "the doorway cuts the moon into a shaft")
	assert_gt(moon.global_position.z, _door.global_position.z + 2.0, "outside")
	assert_gt(moon.global_position.y, _door.global_position.y + 2.0, "above")
	var aim := -moon.global_basis.z
	assert_lt(aim.z, -0.5, "pointing into the room")
	assert_almost_eq(moon.light_energy, BeastDoorLighting.MOON_ENERGY, 0.01)
	# The hearth burns high (the existing shadowed light, not a second one).
	assert_almost_eq(_fire.light_energy, 1.8 * BeastDoorLighting.FIRE_GAIN, 0.01)
	assert_almost_eq(_fire._base, 1.8 * BeastDoorLighting.FIRE_GAIN, 0.01, "the flicker keeps its new base")
	# The rim rides behind his head and follows him.
	var rim := _rig.rim
	assert_not_null(rim)
	assert_false(rim.shadow_enabled)
	assert_gt(rim.global_position.z, _beast.global_position.z, "behind him")
	_beast.global_position += Vector3(1.0, 0, 1.0)
	await wait_process_frames(2)
	assert_almost_eq(rim.global_position.x, _beast.global_position.x, 0.01, "follows him")
	# At most three lights touched, two of them shadowed (the moon and the hearth's own).
	var added := _space.find_children("*", "Light3D", true, false).size()
	assert_eq(added, 3, "fire + moon + rim")


func test_the_gust_flares_the_fire_first() -> void:
	EventBus.story_actor_cue.emit(&"tamlin_beast", &"enter")
	await wait_seconds(BeastDoorLighting.FADE_IN + 0.05)
	assert_gt(_fire.light_energy, 1.8 * BeastDoorLighting.FIRE_GAIN + 0.1, "it leaps with the gust")


func test_the_room_gets_its_own_light_back_after() -> void:
	EventBus.story_actor_cue.emit(&"tamlin_beast", &"enter")
	await wait_seconds(BeastDoorLighting.FADE_IN + 0.1)
	EventBus.scene_space_finished.emit(&"beast_door")
	await wait_seconds(BeastDoorLighting.FADE_OUT + 0.3)
	assert_eq(_rig.amount, 0.0)
	assert_null(_rig.moon)
	assert_null(_rig.rim)
	assert_almost_eq(_fire.light_energy, 1.8, 0.001)
	assert_almost_eq(_fire._base, 1.8, 0.001)
	assert_eq(_space.find_children("*", "Light3D", true, false).size(), 1, "only the hearth")


func test_another_scene_ending_leaves_it_lit() -> void:
	EventBus.story_actor_cue.emit(&"tamlin_beast", &"enter")
	await wait_seconds(BeastDoorLighting.FADE_IN + 0.1)
	EventBus.scene_space_finished.emit(&"wolf_kill")
	await wait_seconds(0.3)
	assert_almost_eq(_rig.amount, 1.0, 0.001)


func test_a_stopped_scene_ignores_the_cue() -> void:
	_space.running = false
	EventBus.story_actor_cue.emit(&"tamlin_beast", &"enter")
	await wait_process_frames(2)
	assert_null(_rig.moon)
