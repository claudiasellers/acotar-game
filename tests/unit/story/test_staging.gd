extends GutTest
## Lane L22: the film camera (Cine) and the wolf kill's staging
## (WolfKillStaging). Contract: docs/contracts/creature_motion.md (Staging).


class FakeSpace:
	extends Node3D
	var running: bool = true
	var wolf: Node3D


class FakeBeastSpace:
	extends Node3D
	var running: bool = true
	var space_id: StringName = &"beast_door"
	var beast: Node3D


class FakeFamily:
	extends Node3D
	var member_id: StringName = &"father"


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


func test_kill_shots_yield_to_a_new_scene() -> void:
	var space := FakeSpace.new()
	add_child_autofree(space)
	var wolf := (load("res://creatures/wolves/great_wolf.tscn") as PackedScene).instantiate() as Creature
	space.add_child(wolf)
	wolf.global_position = Vector3(0, 500, -20)
	space.wolf = wolf
	var staging := WolfKillStaging.new()
	space.add_child(staging)
	await wait_process_frames(2)
	EventBus.creature_killed.emit(&"gw", &"great_wolf", &"arrow_wood", wolf.global_position)
	await wait_process_frames(2)
	assert_eq(staging.stage, &"fall")
	# The next scene starts and takes her controls.
	StoryControl.set_mode(StoryControl.Mode.LOOK)
	EventBus.scene_space_started.emit(&"wolf_skinning")
	assert_eq(staging.stage, &"release", "cuts back to her camera")
	EventBus.scene_space_finished.emit(&"wolf_kill")
	await wait_seconds(WolfKillStaging.RELEASE + 0.3)
	assert_eq(StoryControl.mode, StoryControl.Mode.LOOK, "the new scene keeps its control")
	assert_true(_player_cam.current)


func test_beast_door_staging_moves_only_the_camera() -> void:
	var space := FakeBeastSpace.new()
	add_child_autofree(space)
	var floor_y := 500.0
	_player.global_position = Vector3(0, floor_y, 0)
	var beast := Node3D.new()
	beast.add_to_group(&"beast")
	space.add_child(beast)
	beast.global_position = Vector3(0, floor_y, -4)
	space.beast = beast
	var father := FakeFamily.new()
	father.add_to_group(&"family")
	space.add_child(father)
	father.global_position = Vector3(-1.5, floor_y, -2.2)
	var staging := BeastDoorStaging.new()
	space.add_child(staging)
	await wait_process_frames(1)
	var cine := Cine.of(get_tree())
	EventBus.story_actor_cue.emit(&"tamlin_beast", &"enter")
	await wait_process_frames(2)
	assert_eq(staging.shot_name, &"door")
	assert_eq(cine.target_kind, &"shot")
	StoryControl.set_mode(StoryControl.Mode.LOOK)
	StoryControl.set_focus(beast)
	assert_eq(staging.shot_name, &"low", "it fills the room")
	await wait_process_frames(2)
	assert_lt(cine.camera.global_position.y, floor_y + 1.0, "looking up at him")
	# The decision window: over her shoulder at him, the scene's control untouched.
	StoryControl.set_mode(StoryControl.Mode.LOOK, PackedStringArray(["fire"]))
	await wait_process_frames(2)
	assert_eq(staging.shot_name, &"window")
	assert_eq(cine.target_kind, &"shot")
	assert_gt(cine.camera.global_position.distance_to(beast.global_position + Vector3.UP * 2.0), 1.3, "not inside him")
	assert_eq(StoryControl.mode, StoryControl.Mode.LOOK)
	assert_eq(StoryControl.allowed_actions, PackedStringArray(["fire"]))
	# The father pleads: both in frame.
	EventBus.story_actor_cue.emit(&"father", &"plead")
	await wait_seconds(BeastDoorStaging.PLEAD_DELAY + 1.0)
	assert_eq(staging.shot_name, &"plead")
	assert_true(cine.camera.is_position_in_frustum(father.global_position + Vector3.UP * 1.2), "father in frame")
	assert_true(cine.camera.is_position_in_frustum(beast.global_position + Vector3.UP * 2.0), "beast in frame")
	EventBus.story_actor_cue.emit(&"tamlin_beast", &"snap_ash_arrow")
	assert_eq(staging.shot_name, &"close")
	EventBus.scene_space_finished.emit(&"beast_door")
	await wait_seconds(BeastDoorStaging.RELEASE + 0.3)
	assert_eq(staging.shot_name, &"released")
	assert_true(_player_cam.current, "her camera again")
	assert_eq(StoryControl.mode, StoryControl.Mode.LOOK, "never touched her controls")


func test_beast_door_shot_through_a_wall_falls_back_to_her_view() -> void:
	var space := FakeBeastSpace.new()
	add_child_autofree(space)
	_player.global_position = Vector3(0, 500, 0)
	var beast := Node3D.new()
	space.add_child(beast)
	beast.global_position = Vector3(0, 500, -4)
	space.beast = beast
	# A wall between her and him: no spot on her side sees him.
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(6, 6, 0.3)
	shape.shape = box
	wall.add_child(shape)
	space.add_child(wall)
	wall.global_position = Vector3(0, 501, -2.0)
	var staging := BeastDoorStaging.new()
	space.add_child(staging)
	await wait_physics_frames(2)
	EventBus.story_actor_cue.emit(&"tamlin_beast", &"enter")
	await wait_process_frames(2)
	assert_eq(staging.shot_name, &"door")
	assert_eq(Cine.of(get_tree()).target_kind, &"follow", "her own view through a tighter lens")


## F17: the scene freed mid-shot (its region unloaded) must not leave the
## camera calling into a dead staging, and her view comes back.
func test_staging_freed_mid_track_gives_the_view_back() -> void:
	var space := FakeBeastSpace.new()
	add_child(space)
	_player.global_position = Vector3(0, 500, 0)
	var beast := Node3D.new()
	space.add_child(beast)
	beast.global_position = Vector3(0, 500, -4)
	space.beast = beast
	var staging := BeastDoorStaging.new()
	space.add_child(staging)
	await wait_process_frames(1)
	EventBus.story_actor_cue.emit(&"tamlin_beast", &"snap_ash_arrow")
	var cine := Cine.of(get_tree())
	assert_eq(staging.shot_name, &"close")
	assert_eq(cine.target_kind, &"shot")
	assert_eq(cine.owner_node, staging)
	await wait_process_frames(2)
	space.free()
	await wait_process_frames(3)
	assert_null(cine.owner_node, "dropped")
	assert_false(cine._track.is_valid(), "no track into the freed scene")
	await wait_seconds(1.1)
	assert_false(cine.active)
	assert_true(_player_cam.current, "her camera again")
	assert_eq(cine.bars, 0.0)


func test_a_finished_scene_does_not_take_the_camera_from_the_next() -> void:
	var a := Node.new()
	var b := Node.new()
	add_child_autofree(a)
	add_child_autofree(b)
	var cine := Cine.of(get_tree())
	cine.claim(a)
	cine.follow(50.0, 0.0)
	cine.claim(b)
	cine.shot(Transform3D(Basis.IDENTITY, Vector3(0, 1, 0)), 40.0)
	cine.drop(a)
	assert_eq(cine.target_kind, &"shot", "the next scene keeps its shot")
	cine.drop(b, 0.1)
	await wait_seconds(0.3)
	assert_false(cine.active)
