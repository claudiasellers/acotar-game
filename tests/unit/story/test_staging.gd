extends GutTest
## Lane L22: the film camera (Cine) and the wolf kill's staging
## (WolfKillStaging). Contract: docs/contracts/creature_motion.md (Staging).


class FakeSpace:
	extends Node3D
	var running: bool = true
	var wolf: Node3D


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


func test_follow_tightens_the_lens_and_keeps_her_view() -> void:
	var cine := Cine.of(get_tree())
	assert_eq(Cine.of(get_tree()), cine, "one per tree")
	cine.follow(48.0, 0.2)
	assert_true(cine.camera.current, "cine renders")
	await wait_seconds(0.4)
	assert_almost_eq(cine.camera.fov, 48.0, 0.01)
	_player_cam.global_position += Vector3(1, 0, 0)
	await wait_process_frames(2)
	assert_almost_eq(cine.camera.global_position, _player_cam.global_position, Vector3.ONE * 0.001,
			"rides her camera: she keeps control")
	cine.release(0.2)
	await wait_seconds(0.4)
	assert_false(cine.active)
	assert_true(_player_cam.current, "view handed back")


func test_cut_shot_tracks_its_subject_and_pushes_in() -> void:
	var cine := Cine.of(get_tree())
	var subject := {"at": Vector3(0, 1, -10)}
	var spot := Vector3(5, 1, -5)
	cine.shot(Transform3D(Basis.looking_at(subject.at - spot), spot), 34.0, 0.0,
			func() -> Vector3: return subject.at, 1.0, 0.3)
	await wait_process_frames(2)
	assert_almost_eq(cine.camera.fov, 34.0, 0.01, "a cut")
	subject.at = Vector3(-3, 1, -10)
	await wait_seconds(1.5)
	var fwd := -cine.camera.global_basis.z
	var want: Vector3 = (subject.at - cine.camera.global_position).normalized()
	assert_gt(fwd.dot(want), 0.99, "turned after the subject")
	assert_almost_eq(cine.camera.global_position.distance_to(spot), 1.0, 0.05, "pushed in")


func test_letterbox_bars() -> void:
	var cine := Cine.of(get_tree())
	cine.bars_to(1.0, 0.2)
	await wait_seconds(0.35)
	assert_almost_eq(cine.bars, 1.0, 0.001)
	cine.bars_to(0.0, 0.0)
	assert_eq(cine.bars, 0.0)


func test_clear_view_avoids_a_blocked_line() -> void:
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4, 4, 0.5)
	shape.shape = box
	wall.add_child(shape)
	add_child_autofree(wall)
	# A floor of its own far above the shared terrain: greybox rules.
	var subject := Vector3(0, 500, 0)
	wall.global_position = subject + Vector3(0, 1, 3)
	await wait_physics_frames(2)
	var dirs: Array[Vector3] = [Vector3(0, 0, 1), Vector3(1, 0, 0)]
	var spot := Cine.clear_view(wall.get_world_3d(), subject, dirs, 6.0, 0.9)
	assert_almost_eq(spot, subject + Vector3(6, 0.9, 0), Vector3.ONE * 0.01, "the open side")


func test_creature_slow_motion_recovers() -> void:
	var wolf := (load("res://creatures/wolves/great_wolf.tscn") as PackedScene).instantiate() as Creature
	add_child_autofree(wolf)
	wolf.global_position = Vector3(0, 500, 0)
	await wait_process_frames(1)
	wolf.animator.slow(0.2, 0.1, 0.1)
	assert_eq(wolf.animator.time_scale, 0.2)
	await wait_process_frames(2)
	assert_eq(wolf.animator.tree.callback_mode_process, AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL)
	await wait_seconds(0.4)
	assert_eq(wolf.animator.time_scale, 1.0)
	await wait_process_frames(2)
	assert_eq(wolf.animator.tree.callback_mode_process, AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE)


func test_wolf_kill_staging_films_the_kill_and_gives_her_back() -> void:
	var space := FakeSpace.new()
	add_child_autofree(space)
	var wolf := (load("res://creatures/wolves/great_wolf.tscn") as PackedScene).instantiate() as Creature
	space.add_child(wolf)
	wolf.global_position = Vector3(0, 500, -20)
	space.wolf = wolf
	var staging := WolfKillStaging.new()
	space.add_child(staging)
	await wait_process_frames(2)
	# His eyes: the scene's focus closes the lens through her camera.
	StoryControl.set_focus(wolf)
	var cine := Cine.of(get_tree())
	assert_eq(cine.target_kind, &"follow")
	StoryControl.set_focus(null)
	assert_eq(cine.target_kind, &"release")
	# The kill: slow motion, her controls held, a cut to the low angle.
	EventBus.creature_killed.emit(&"gw", &"great_wolf", &"arrow_wood", wolf.global_position)
	await wait_process_frames(2)
	assert_eq(staging.stage, &"fall")
	assert_eq(StoryControl.mode, StoryControl.Mode.NONE)
	assert_lt(wolf.animator.time_scale, 1.0, "slow motion")
	await wait_seconds(WolfKillStaging.BEAT_IN + 0.2)
	assert_eq(cine.target_kind, &"shot")
	assert_almost_eq(cine.camera.fov, WolfKillStaging.DEATH_FOV, 0.01)
	# The scene ending mid-shot does not hand her the controls early.
	StoryControl.release()
	EventBus.scene_space_finished.emit(&"wolf_kill")
	assert_eq(StoryControl.mode, StoryControl.Mode.NONE)
	# Interact skips once he is down.
	await wait_seconds(WolfKillStaging.SKIP_AFTER)
	var press := InputEventAction.new()
	press.action = &"interact"
	press.pressed = true
	staging._unhandled_input(press)
	assert_eq(staging.stage, &"release")
	assert_eq(StoryControl.mode, StoryControl.Mode.FULL)
	await wait_seconds(WolfKillStaging.RELEASE + 0.3)
	assert_eq(staging.stage, &"done")
	assert_true(_player_cam.current, "her camera again")
	assert_eq(cine.bars, 0.0)


func test_staging_ignores_other_kills_and_idle_scenes() -> void:
	var space := FakeSpace.new()
	space.running = false
	add_child_autofree(space)
	var staging := WolfKillStaging.new()
	space.add_child(staging)
	EventBus.creature_killed.emit(&"gw", &"great_wolf", &"arrow_ash", Vector3.ZERO)
	space.running = true
	EventBus.creature_killed.emit(&"d", &"deer", &"arrow_wood", Vector3.ZERO)
	await wait_process_frames(2)
	assert_eq(staging.stage, &"")
	assert_eq(StoryControl.mode, StoryControl.Mode.FULL)
