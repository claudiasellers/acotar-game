# gate: needs:terrain
# gate: when:systems/bow/*,characters/feyre/*,core/story_control.gd,story/act1/act1_game*
## T096: the bow works the same in the real game in both places the owner
## shoots: the woods at the start of Act I and the Spring Court (a Continue
## into the manor). Hold right mouse, left click: one arrow; let go: none.
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
	Engine.time_scale = 1.0
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
	if Gameplay.inventory.arrow_count() < 3:
		Gameplay.inventory.add(&"arrow_wood", 3)
	return feyre


## Three aim-and-click shots and one aim-and-let-go; the scene must allow the bow.
func _shoot_and_check(feyre: Feyre, where: String) -> void:
	assert_true(feyre.is_physics_processing(), "%s: she has control" % where)
	assert_true(StoryControl.can_shoot(), "%s: free play allows the bow (mode %d, scenes %s)"
			% [where, StoryControl.mode, _running_scenes()])
	for i in 3:
		_mouse(MOUSE_BUTTON_RIGHT, true)
		await wait_physics_frames(15)
		assert_true(feyre.is_aiming, "%s: right mouse raises the bow" % where)
		_mouse(MOUSE_BUTTON_LEFT, true)
		_mouse(MOUSE_BUTTON_LEFT, false)
		await wait_physics_frames(2)
		assert_eq(fired.size(), i + 1, "%s: shot %d fired" % [where, i + 1])
		assert_false(feyre.is_aiming, "%s: the bow comes down after the shot" % where)
		_mouse(MOUSE_BUTTON_RIGHT, false)
		await wait_physics_frames(2)
	_mouse(MOUSE_BUTTON_RIGHT, true)
	await wait_physics_frames(15)
	_mouse(MOUSE_BUTTON_RIGHT, false)
	await wait_physics_frames(3)
	assert_eq(fired.size(), 3, "%s: letting go fires nothing" % where)
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
