# gate: needs:terrain
# gate: when:characters/feyre/feyre.gd,story/act1/act1_game.gd,story/act1/cottage_door_latch.gd,systems/dialogue/dialogue_director.gd,systems/actor_body/*,systems/mount/mount_director.gd,ui/map/world_map_hud.gd,ui/map/map_settings.gd,ui/settings_panel.gd,core/save_system.gd,systems/player_assist/player_placement.gd,tests/integration/play/play_harness.gd
## Play test (T097): the woods, from New Game, driven by real key and pad
## events (tests/integration/play/README.md). The cottage in the human realm:
## she wakes there, her family is in the room, the woods are outside the door.
extends GutTest

const PlayHarness := preload("res://tests/integration/play/play_harness.gd")
const SLOT := "gut_play_woods"

var h: PlayHarness
var spawn := Vector3.ZERO
var booted := false
## What the first frames of the boot looked like (see test_she_wakes_on_the_ground).
var boot_fell := false
var fell_to := 0.0


func before_all() -> void:
	h = PlayHarness.new(self)
	booted = await h.boot_new_game()
	if booted:
		boot_fell = not h.on_solid_ground()
		fell_to = h.feyre.global_position.y
		var dawn := _anchor(&"opening_cottage_dawn")
		spawn = dawn.global_position if dawn else h.feyre.global_position
		if boot_fell:
			# Back on the floor where she should have woken, for the other tests.
			await h.place_on_ground(spawn.x, spawn.z, 0.3, 600, spawn.y + 1.5)


func after_all() -> void:
	SaveSystem.delete_save(SLOT)
	await h.shutdown()
	h.dispose()


func before_each() -> void:
	if not booted:
		pending("the game never gave her control")
	h.release_all()


func after_each() -> void:
	h.release_all()


## The cottage: her family stand in it. Their middle.
func _cottage_middle() -> Vector3:
	var sum := Vector3.ZERO
	var n := 0
	for node in get_tree().get_nodes_in_group(DialogueDirector.PRESENCE_GROUP):
		if node is Node3D and PlayHarness.flat_distance((node as Node3D).global_position, spawn) < 15.0:
			sum += (node as Node3D).global_position
			n += 1
	return sum / n if n > 0 else spawn


func _anchor(id: StringName) -> Node3D:
	for a in get_tree().get_nodes_in_group(&"story_anchor"):
		if StringName(a.get_meta(&"anchor_id", a.name)) == id:
			return a as Node3D
	return null


func test_she_wakes_on_the_ground() -> void:
	if not booted:
		return
	# F1 (T097, fixed by T104): New Game used to drop her through the ground
	# at the cottage door now and then.
	assert_false(boot_fell, "New Game sets her down on solid ground (fell to y=%.1f)" % fell_to)
	assert_true(h.on_solid_ground(), "standing on the ground at the cottage door")


func test_talking_to_her_family_shows_a_line_and_leaves_her_free() -> void:
	if not booted:
		return
	await h.place_on_ground(spawn.x, spawn.z, 0.3, 600, spawn.y + 1.5)
	var dd := h.child_of(DialogueDirector) as DialogueDirector
	var heard: Array[StringName] = []
	var on_line := func(_id: StringName, speaker: StringName, _t: String, _at: Vector3, _inner: bool) -> void:
		heard.append(speaker)
	dd.line_spoken.connect(on_line)
	# Walk up to the nearest of them (face to face, on camera) and wait.
	var near := h.nearest_in_group(DialogueDirector.PRESENCE_GROUP, 15.0)
	assert_not_null(near, "someone of her family is in the cottage")
	if near == null:
		return
	# She wakes at the front door: in through it (it swings open as she comes up).
	var door := _anchor(&"act1_cottage_door")
	if door:
		var inside := _cottage_middle()
		await h.walk_to(door.global_position, 0.5, 300, false, 0.5)
		await h.walk_to(door.global_position.lerp(inside, 0.5), 0.5, 300, false, 0.5)
	var spoke := false
	for attempt in 3:
		await h.walk_to(near.global_position, 1.8, 240, false, 0.4)
		await h.look_toward(near.global_position)
		spoke = await h.wait_until(func() -> bool:
			return heard.any(func(s: StringName) -> bool: return s in DialogueDirector.FAMILY), 60 * 15)
		if spoke:
			break
	dd.line_spoken.disconnect(on_line)
	if not spoke:
		var c := dd._find_cottage()
		gut.p("why: Feyre at %s, cottage %s, her local %s, camera yaw %.2f at %s" % [h.feyre.global_position,
				c.global_position if c else Vector3.INF,
				(c.global_transform.affine_inverse() * h.feyre.global_position) if c else Vector3.INF,
				h.feyre.camera_yaw(), get_viewport().get_camera_3d().global_position])
		for n in get_tree().get_nodes_in_group(DialogueDirector.PRESENCE_GROUP):
			if n is Node3D and PlayHarness.flat_distance((n as Node3D).global_position, spawn) < 15.0:
				var n3 := n as Node3D
				gut.p("why: %s at %.2f m, in_cottage her %s them %s, on_camera %s, face_to_face %s, speaker %s, busy %s, greeted %s" % [
					n3.name, n3.global_position.distance_to(h.feyre.global_position),
					dd.in_cottage(h.feyre.global_position), dd.in_cottage(n3.global_position),
					dd.on_camera(n3), dd.face_to_face(n3, h.feyre.global_position), dd._node_speaker(n3),
					dd.busy(), dd._greeted.get(n3.get_instance_id(), false)])
	assert_true(spoke, "one of her family speaks when she comes up to them (heard %s)" % [heard])
	assert_true(h.has_control(), "a line never takes the controls")
	var caption := get_tree().get_first_node_in_group(Act2Caption.GROUP) as Act2Caption
	if caption:
		assert_true(await h.wait_until(func() -> bool: return caption.showing == "", 60 * 20),
				"the caption goes away by itself")
	var before := h.feyre.global_position
	await h.hold_for(&"move_back", 20)
	assert_gt(PlayHarness.flat_distance(before, h.feyre.global_position), 0.3, "and she walks on afterwards")


func test_n_hides_and_shows_the_minimap() -> void:
	if not booted:
		return
	var hud := h.child_of(WorldMapHud) as WorldMapHud
	await h.wait_until(func() -> bool: return hud.minimap.visible, 30)
	var was := hud.minimap.visible
	assert_true(was, "the minimap is on at the start")
	await h.press(&"map_minimap")
	await wait_process_frames(2)
	assert_ne(hud.minimap.visible, was, "N flips it")
	await h.press(&"map_minimap")
	await wait_process_frames(2)
	assert_eq(hud.minimap.visible, was, "N again puts it back")


func test_walk_run_sprint_move_her_and_letting_go_stops_her() -> void:
	if not booted:
		return
	# Out in the clearing south of the cottage, where there is room.
	var out := _cottage_middle() + Vector3(0.0, 0.0, 14.0)
	assert_true(await h.place_on_ground(out.x, out.z), "set down outside the cottage")
	var speeds := {}
	for mode: Array in [[&"walk", 0.4, false], [&"run", 1.0, false], [&"sprint", 1.0, true]]:
		await h.place_on_ground(out.x, out.z)
		var from := h.feyre.global_position
		if mode[2]:
			h.hold(&"sprint")
		h.stick(Vector2(0.0, 1.0) * mode[1])  # back, away from the cottage
		await wait_physics_frames(45)
		speeds[mode[0]] = h.flat_speed()
		h.stick(Vector2.ZERO)
		h.release(&"sprint")
		assert_gt(PlayHarness.flat_distance(from, h.feyre.global_position), 0.5, "%s moves her" % mode[0])
		assert_true(await h.wait_still(45), "%s: she stops within 45 frames of letting go (speed %.2f)" % [mode[0], h.flat_speed()])
	assert_lt(speeds.walk, speeds.run, "a light stick walks, slower than a full run (%s)" % [speeds])
	assert_lt(speeds.run, speeds.sprint, "sprint is faster than a run (%s)" % [speeds])
	# The keyboard too: the arrow key moves her and letting go stops her.
	await h.place_on_ground(out.x, out.z)
	var from := h.feyre.global_position
	await h.hold_for(&"move_back", 30)
	assert_gt(PlayHarness.flat_distance(from, h.feyre.global_position), 1.0, "the arrow key moves her")
	assert_true(await h.wait_still(45), "and she stops when it is let go")


func test_the_cottage_wall_stops_her() -> void:
	if not booted:
		return
	var middle := _cottage_middle()
	# From the back, away from the front door (which swings open for her).
	var door := _anchor(&"act1_cottage_door")
	var away := Vector3(0.0, 0.0, 1.0)
	if door:
		away = middle - door.global_position
		away.y = 0.0
		away = away.normalized()
	var out := middle + away * 9.0
	assert_true(await h.place_on_ground(out.x, out.z), "set down outside the cottage")
	# Run straight at the wall for two seconds.
	for i in 120:
		h.stick_toward(middle)
		await wait_physics_frames(1)
	h.stick(Vector2.ZERO)
	var d := PlayHarness.flat_distance(h.feyre.global_position, middle)
	assert_gt(d, 2.3, "she stays outside the wall (%.2f m from the middle)" % d)
	assert_lt(d, 7.0, "she got up to the wall")


func test_whistle_does_not_bring_the_mare_south_of_the_wall() -> void:
	if not booted:
		return
	var md := h.child_of(MountDirector) as MountDirector
	var answers: Array[bool] = []
	var on_whistle := func(ok: bool) -> void: answers.append(ok)
	md.whistled.connect(on_whistle)
	await h.press(&"call_mount")
	await wait_process_frames(30)
	md.whistled.disconnect(on_whistle)
	assert_eq(answers, [false] as Array[bool], "H whistles, and nobody answers in the human lands")
	assert_true(md.mare == null or not is_instance_valid(md.mare), "no mare appears")
	assert_true(h.has_control())


func test_pause_saves_and_continue_puts_her_back() -> void:
	if not booted:
		return
	var out := _cottage_middle() + Vector3(3.0, 0.0, 12.0)
	await h.place_on_ground(out.x, out.z)
	await h.hold_for(&"move_right", 20)
	await h.wait_still()
	var panel := h.child_of(SettingsPanel) as SettingsPanel
	await h.press(&"pause")
	assert_true(panel.is_open(), "Esc opens the pause menu")
	assert_true(get_tree().paused, "and pauses the game")
	# The menu's Save buttons save then leave for the title, which would end
	# this test run, so the save is the button's own call; the load below is
	# the real Continue road.
	SaveSystem.active_slot = SLOT
	assert_eq(SaveSystem.save_game(SLOT), OK, "saved")
	await h.press(&"pause")
	assert_false(panel.is_open(), "Esc closes it")
	assert_false(get_tree().paused, "and play goes on")
	var at := h.feyre.global_position
	var yaw := h.feyre.model.rotation.y
	var flags := WorldState.all_flags().duplicate()
	var phase := PhaseManager.current_phase
	await h.shutdown()
	booted = await h.boot_slot(SLOT)
	assert_true(booted, "Continue gives her control")
	# Finding F3 (T097): now and then, freeing the game and Continuing logs
	# "Lambda capture at index 0 was freed" (a game callback outlives its node).
	if h.excuse_errors("Lambda capture at index 0 was freed") > 0:
		pending("F3: after the game is freed and Continue runs, a callback fires with a freed capture")
	if not booted:
		return
	assert_lt(PlayHarness.flat_distance(at, h.feyre.global_position), 0.5,
			"she is where she saved (%s, saved at %s)" % [h.feyre.global_position, at])
	assert_almost_eq(h.feyre.model.rotation.y, yaw, 0.05, "facing the same way")
	assert_eq(PhaseManager.current_phase, phase, "same phase")
	var now_flags := WorldState.all_flags()
	var lost := flags.keys().filter(func(k: String) -> bool: return not now_flags.has(k))
	var gained := now_flags.keys().filter(func(k: String) -> bool: return not flags.has(k))
	assert_eq(lost, [], "no deed lost in the load")
	# Lines heard since she landed (dlg.*) are new, honestly; nothing else is.
	assert_eq(gained.filter(func(k: String) -> bool: return not k.begins_with("dlg.")), [],
			"no deed gained by loading (gained %s)" % [gained])
	assert_true(await h.wait_still(120) and h.on_solid_ground(), "standing on the ground")
	var before := h.feyre.global_position
	await h.hold_for(&"move_back", 20)
	assert_gt(PlayHarness.flat_distance(before, h.feyre.global_position), 0.5, "and she walks")
