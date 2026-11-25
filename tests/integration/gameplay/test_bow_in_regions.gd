# gate: needs:terrain
# gate: when:systems/bow/*,characters/feyre/*,core/story_control.gd,story/act1/act1_game*
## T096: the bow works the same in the real game in both places the owner
## shoots: the woods at the start of Act I and the Spring Court (a Continue
## into the manor). Hold right mouse, hold left to draw, let go: one arrow.
extends GutTest

const GAME := "res://story/act1/act1_game.tscn"
const SLOT := "gut_bow_regions"
const MANOR_BEDROOM := [20.15, 13.7, -63.54]
const CONTROL_WAIT := 90.0

var fired: Array = []


func before_each() -> void:
	WorldState.clear()
	Gameplay.reset()
	fired = []


func after_each() -> void:
	_mouse(MOUSE_BUTTON_LEFT, false)
	_mouse(MOUSE_BUTTON_RIGHT, false)
	TimeScale.reset()
	GameSettings.pending_load_slot = ""
	SaveSystem.delete_save(SLOT)
	WorldStreamer.track(null)
	WorldStreamer.unload_all()
	WorldState.clear()
	StoryControl.release()
	PhaseManager.phase_set = null
	PhaseManager.current_phase = &""


func _mouse(button: MouseButton, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.pressed = pressed
	e.position = Vector2(320, 240)
	e.global_position = e.position
	Input.parse_input_event(e)
	Input.flush_buffered_events()


func _start(game: Node) -> Feyre:
	add_child_autofree(game)
	var feyre := game.get(&"feyre") as Feyre
	var started := Time.get_ticks_msec()
	while not feyre.is_physics_processing() and (Time.get_ticks_msec() - started) / 1000.0 < CONTROL_WAIT:
		await wait_frames(1)
	# The woods open on a held establishing shot (LOOK) before play.
	await wait_until(func() -> bool: return StoryControl.mode == StoryControl.Mode.FULL, 20.0)
	await wait_physics_frames(5)
	feyre.arrow_fired.connect(func(a: Arrow) -> void: fired.append(a))
	# A full quiver, whatever the chapter gives her: this is about the bow.
	Gameplay.inventory.carry_quiver(Inventory.FULL_QUIVER)
	if Gameplay.inventory.arrow_count() < 5:
		Gameplay.inventory.add(&"arrow_wood", 4)
	return feyre


## Aim held throughout: three draws held to full and let go loose three
## arrows with the bow staying up between them; a tap looses nothing; letting
## go of aim lowers the bow. The scene must allow the bow.
func _shoot_and_check(feyre: Feyre, where: String) -> void:
	assert_true(feyre.is_physics_processing(), "%s: she has control" % where)
	assert_true(StoryControl.can_shoot(), "%s: free play allows the bow (mode %d, scenes %s)"
			% [where, StoryControl.mode, _running_scenes()])
	var bow := feyre.bow_controller
	var full_draw := ceili((bow.bow.draw_time + 0.15) * 60.0)
	var recover := ceili((bow.tuning.follow_through_s + 0.1) * 60.0)
	_mouse(MOUSE_BUTTON_RIGHT, true)
	await wait_physics_frames(15)
	assert_true(feyre.is_aiming, "%s: right mouse raises the bow" % where)
	assert_true(bow.is_nocked, "%s: with an arrow on the string" % where)
	for i in 3:
		_mouse(MOUSE_BUTTON_LEFT, true)
		await wait_physics_frames(full_draw)
		assert_eq(fired.size(), i, "%s: holding the draw looses nothing" % where)
		_mouse(MOUSE_BUTTON_LEFT, false)
		await wait_physics_frames(2)
		assert_eq(fired.size(), i + 1, "%s: letting go looses shot %d" % [where, i + 1])
		assert_true(feyre.is_aiming, "%s: the bow stays up after the shot" % where)
		await wait_physics_frames(recover)
	_mouse(MOUSE_BUTTON_LEFT, true)
	await wait_physics_frames(2)
	_mouse(MOUSE_BUTTON_LEFT, false)
	await wait_physics_frames(full_draw)
	assert_eq(fired.size(), 4, "%s: a tap is a weak shot, never nothing" % where)
	assert_lt((fired[3] as Arrow).get_meta(&"speed"), bow.bow.max_speed * 0.8, "%s: and a short one" % where)
	_mouse(MOUSE_BUTTON_RIGHT, false)
	await wait_physics_frames(3)
	assert_eq(fired.size(), 4, "%s: letting go of aim fires nothing" % where)
	assert_false(feyre.is_aiming, "%s: and lowers the bow" % where)


func _running_scenes() -> Array[String]:
	var out: Array[String] = []
	for n in get_tree().root.find_children("*", "", true, false):
		if n is SceneSpace and (n as SceneSpace).running:
			out.append(String(n.name))
	return out


func test_the_bow_in_the_woods() -> void:
	var feyre := await _start((load(GAME) as PackedScene).instantiate())
	await _shoot_and_check(feyre, "woods")


func test_the_bow_in_the_spring_court() -> void:
	DirAccess.make_dir_recursive_absolute(SaveSystem.SAVE_DIR)
	var f := FileAccess.open("user://saves/%s.json" % SLOT, FileAccess.WRITE)
	f.store_string(JSON.stringify({
		"version": 2,
		"clock": {"day": 4, "time_of_day": 0.25},
		"world_state": {"flags": {"wolf_killed": true, "fact.wolf_skinned": true, "fact.wolf_spotted": true,
			"pelt_sold": true, "wall_crossed": true, "fact.manor_arrived": true,
			# Past the welcome, the first dinner and the curtain: free play.
			"fact.alis_bathed": true, "fact.first_dinner_seen": true, "first_dinner_eaten": true,
			"curtain_trap_set": true, "fact.alis_tripped": true, "fact.hunt_invited": true}},
		"phase": {"phase": "p2_grounds", "phase_set": "res://data/phases/spring_court_phases.tres",
			"unlocked_regions": ["manor_estate", "manor_grounds", "manor_house"]},
		"world_deltas": {},
		"providers": {"player_placement": {"position": MANOR_BEDROOM, "yaw": 0.0}},
	}))
	f.close()
	GameSettings.pending_load_slot = SLOT
	var feyre := await _start((load(GAME) as PackedScene).instantiate())
	await _shoot_and_check(feyre, "spring court")
