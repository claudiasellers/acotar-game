# gate: needs:terrain
# gate: when:systems/mount/*,data/mount/*,ui/mare/*,story/framework/scene_space.gd,story/framework/moment_space.gd,data/story/moments/*,core/story_control.gd,characters/feyre/feyre.gd,systems/interaction/*,tests/integration/play/play_harness.gd,ui/hud/use_prompt.gd,project.godot
## Play test (T148): the white mare from where a real player stands after the
## first dinner and the curtain trap, the mare never ridden. The background
## moments that wait on deeds all act (the hall marks, the manor map) are
## running, as they are from fact.alis_tripped on; they hold nothing and must
## never stop her. Real key and pad events: E mounts her the first time (and
## teaches the whistle), the stick rides, E gets down, H brings her, T (the second
## interact key, interact_alt) opens tending, a held X on the pad does too, the pad's brush (hold A, move the stick) brings her to a gleam (a bond deed).
extends GutTest

const PlayHarness := preload("res://tests/integration/play/play_harness.gd")
const SLOT := "gut_play_mare"
## Out of the stable yard toward the drive (as test_play_court.gd).
const RIDE_TO := Vector3(-60.0, 0.0, 160.0)
const SAVE := {
	"version": 2,
	"clock": {"day": 6, "time_of_day": 0.4},
	"world_state": {"flags": {"wolf_killed": true, "fact.wolf_skinned": true, "fact.wolf_spotted": true,
		"pelt_sold": true, "beast_claim_accepted": true, "wall_crossed": true, "fact.manor_arrived": true,
		"fact.alis_bathed": true, "fact.first_dinner_seen": true, "first_dinner_eaten": true,
		"curtain_trap_set": true, "fact.alis_tripped": true, "fact.hunt_invited": true, "bogge_survived": true}},
	"phase": {"phase": "p2_grounds", "phase_set": "res://data/phases/spring_court_phases.tres",
		"unlocked_regions": ["manor_estate", "manor_grounds", "manor_house"]},
	"world_deltas": {},
	"providers": {"player_placement": {"position": [-126.0, 9.0, -9.0], "yaw": 0.0}},
}

var h: PlayHarness
var booted := false
var md: MountDirector


func before_all() -> void:
	h = PlayHarness.new(self)
	booted = await h.boot_from_save(SLOT, SAVE)
	if booted:
		md = h.child_of(MountDirector) as MountDirector


func before_each() -> void:
	h.require_control(booted)


func after_all() -> void:
	SaveSystem.delete_save(SLOT)
	await h.shutdown()


func _live_spaces() -> Array:
	return get_tree().get_nodes_in_group(&"story_space_live").map(func(n: Node) -> StringName: return n.get_meta(&"story_space_id", &""))


func _mare_standing_near(radius: float) -> bool:
	return md.mare != null and is_instance_valid(md.mare) and md.mare.state == MareMount.State.STANDING \
			and PlayHarness.flat_distance(md.mare.global_position, h.feyre.global_position) < radius


func _up_to_her() -> void:
	await h.look_toward(md.mare.global_position)
	await h.walk_to(md.mare.global_position, 1.6, 300, false, 0.4)


func test_1_first_ride_from_the_stables() -> void:
	if not booted:
		return
	var home := md.data.home
	assert_true(await h.place_on_ground(home.x + 4.0, home.z + 7.0), "in the stable yard")
	assert_true(await h.wait_until(func() -> bool: return _mare_standing_near(30.0), 600), "the mare waits in the stables")
	assert_false(md.unlocked(), "never ridden yet")
	# The cause of T148: these moments run all act and used to block her.
	assert_true(_live_spaces().has(&"manor_map"), "the background manor-map moment is running (%s)" % [_live_spaces()])
	assert_eq(StoryControl.mode, StoryControl.Mode.FULL, "and holds nothing")
	await _up_to_her()
	await h.press(&"interact")
	var up := await h.wait_until(func() -> bool: return md.riding and md.motion == null, 240)
	assert_true(up, "E by her puts Feyre in the saddle (blocked: %s)" % md.last_block)
	if not up:
		return
	assert_true(WorldState.has_flag(MountDirector.RIDDEN_FLAG), "the first ride raises fact.mare_ridden")
	var from := md.mare.global_position
	for i in 150:
		h.stick_toward(RIDE_TO)
		await wait_physics_frames(1)
	h.stick(Vector2.ZERO)
	assert_gt(PlayHarness.flat_distance(from, md.mare.global_position), 5.0, "the stick rides her")
	await h.wait_until(func() -> bool: return md.mare.speed < 0.3, 60 * 6)
	await h.press(&"interact")
	assert_true(await h.wait_until(func() -> bool: return not md.riding and md.motion == null, 120), "E gets her down")
	assert_true(await h.wait_until(func() -> bool: return h.has_control(), 60), "and she has her legs back")


func test_2_the_whistle_brings_her() -> void:
	if not booted or not md.unlocked():
		return
	await h.wait_still(120)
	var at := h.feyre.global_position
	assert_true(await h.place_on_ground(at.x + 30.0, at.z + 25.0), "a way off from her")
	var answers: Array[bool] = []
	var on_whistle := func(ok: bool) -> void: answers.append(ok)
	md.whistled.connect(on_whistle)
	await h.press(&"call_mount")
	await wait_process_frames(2)
	md.whistled.disconnect(on_whistle)
	assert_eq(answers, [true] as Array[bool], "H whistles and she answers (blocked: %s)" % md.last_block)
	assert_true(await h.wait_until(func() -> bool: return _mare_standing_near(5.0), 60 * 30), "she comes up beside her and stands")
	assert_true(MareBond.done(&"answered"), "coming to the whistle is a bond deed")


func test_3_t_tends_her_and_brushing_bonds() -> void:
	if not booted or not _mare_standing_near(8.0):
		return
	await _up_to_her()
	await h.press(&"interact_alt")
	var opened := await h.wait_until(func() -> bool: return md.tending != null, 120)
	assert_true(opened, "T beside her opens tending (can_tend %s, blocked: %s)"
			% [md.can_tend(), md.block_reason(h.feyre.global_position)])
	if not opened:
		return
	# The pad's brush (hold A, move the stick), the road MareTendingView reads
	# each frame. Mouse GUI events don't reach Controls in a headless window.
	var a := InputEventJoypadButton.new()
	a.device = 0
	a.button_index = JOY_BUTTON_A
	a.pressed = true
	Input.parse_input_event(a)
	for i in 60 * 30:
		h.stick(Vector2(1.0 if (i / 30) % 2 == 0 else -1.0, 0.0))
		await wait_physics_frames(1)
		if MareCare.shine() >= 1.0:
			break
	h.stick(Vector2.ZERO)
	var off := a.duplicate() as InputEventJoypadButton
	off.pressed = false
	Input.parse_input_event(off)
	assert_almost_eq(MareCare.shine(), 1.0, 0.001, "brushing her brings her to a gleam")
	assert_true(MareBond.done(&"gleam"), "the gleam is a bond deed")
	await h.press(&"interact")
	assert_true(await h.wait_until(func() -> bool: return md.tending == null, 60), "E closes tending")


func test_4_a_held_x_on_the_pad_tends_her() -> void:
	if not booted or not _mare_standing_near(8.0):
		return
	await _up_to_her()
	assert_true(await h.wait_until(func() -> bool: return UsePrompt.of(get_tree()).offered().size() == 2, 60),
			"beside her the prompt names two keys: %s" % [UsePrompt.of(get_tree()).offered()])
	var x := InputEventJoypadButton.new()
	for bound in InputMap.action_get_events(&"interact"):
		if bound is InputEventJoypadButton:
			x.button_index = (bound as InputEventJoypadButton).button_index
	x.device = PlayHarness.PAD_DEVICE
	x.pressed = true
	x.pressure = 1.0
	Input.parse_input_event(x)
	var opened := await h.wait_until(func() -> bool: return md.tending != null, 120)
	var up := x.duplicate() as InputEventJoypadButton
	up.pressed = false
	up.pressure = 0.0
	Input.parse_input_event(up)
	await h.settle()
	assert_true(opened, "holding X beside her opens tending (can_tend %s)" % md.can_tend())
	assert_false(md.riding, "the hold tends; it never mounts her")
	if opened:
		await h.press(&"interact")
		assert_true(await h.wait_until(func() -> bool: return md.tending == null, 60), "E closes tending")
