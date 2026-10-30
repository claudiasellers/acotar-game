extends GutTest

const PATH := "user://test_pause_settings.cfg"
const FEYRE := preload("res://characters/feyre/feyre.tscn")

var _saved_path: String
var _saved_values: Dictionary


func before_each() -> void:
	_saved_path = GameSettings.settings_path
	_saved_values = {}
	for key: StringName in GameSettings.DEFAULTS:
		_saved_values[key] = GameSettings.get_value(key)
	GameSettings.settings_path = PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	GameSettings.load_settings()


func after_each() -> void:
	get_tree().paused = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	GameSettings.settings_path = _saved_path
	GameSettings.load_settings()


func _floor() -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60, 1, 60)
	shape.shape = box
	shape.position.y = -0.5
	body.add_child(shape)
	add_child_autofree(body)
	return body


func _block(at: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = at
	add_child_autofree(body)


func _feyre() -> Feyre:
	_floor()
	var f := FEYRE.instantiate() as Feyre
	add_child_autofree(f)
	f.global_position = Vector3(0, 0.05, 0)
	return f


func test_every_setting_round_trips_through_the_file() -> void:
	var changed := {
		&"mouse_sensitivity": 1.8, &"stick_sensitivity": 0.4, &"invert_x": true,
		&"invert_y": true, &"camera_follow": false, &"gentle_mode": true,
		&"reduced_effects": true, &"music_volume": 0.25, &"sound_volume": 0.6, &"text_size": 3,
	}
	assert_eq(changed.size(), GameSettings.DEFAULTS.size(), "test covers every setting")
	for key: StringName in changed:
		GameSettings.set_value(key, changed[key])
	GameSettings.load_settings()
	for key: StringName in changed:
		assert_almost_eq(float(GameSettings.get_value(key)), float(changed[key]), 0.0001, String(key))


func test_settings_are_applied() -> void:
	GameSettings.set_value(&"text_size", 3)
	assert_almost_eq(get_tree().root.content_scale_factor, 1.3, 0.001)
	GameSettings.set_value(&"music_volume", 0.5)
	var bus := AudioServer.get_bus_index(GameSettings.MUSIC_BUS)
	assert_gt(bus, 0)
	assert_almost_eq(AudioServer.get_bus_volume_db(bus), linear_to_db(0.5), 0.01)
	GameSettings.set_value(&"sound_volume", 0.0)
	assert_true(AudioServer.is_bus_mute(AudioServer.get_bus_index(GameSettings.SOUND_BUS)))
	GameSettings.set_value(&"reduced_effects", true)
	assert_lt(Juice.effects_scale, 0.5)


func test_new_audio_players_join_the_sound_bus() -> void:
	var p := AudioStreamPlayer.new()
	add_child_autofree(p)
	assert_eq(p.bus, GameSettings.SOUND_BUS)
	var m := AudioStreamPlayer.new()
	m.add_to_group(GameSettings.MUSIC_GROUP)
	add_child_autofree(m)
	assert_eq(m.bus, GameSettings.MUSIC_BUS)


func test_sensitivity_slider_is_centred_on_one() -> void:
	assert_almost_eq(GameSettings.sensitivity_from_slider(0.0), GameSettings.SENSITIVITY_MIN, 0.001)
	assert_almost_eq(GameSettings.sensitivity_from_slider(0.5), 1.0, 0.001)
	assert_almost_eq(GameSettings.sensitivity_from_slider(1.0), GameSettings.SENSITIVITY_MAX, 0.001)
	for t in [0.1, 0.35, 0.5, 0.8]:
		assert_almost_eq(GameSettings.slider_from_sensitivity(GameSettings.sensitivity_from_slider(t)), t, 0.001)


func test_r_recentres_the_camera_behind_her_quickly() -> void:
	var f := _feyre()
	f.model.rotation.y = 0.4
	f.nudge_camera(2.2, 0.5)
	f.recenter_camera()
	for i in 20:  # a third of a second at 60 fps
		f._process(1.0 / 60.0)
	assert_almost_eq(angle_difference(f.camera_yaw(), 0.4), 0.0, 0.02)
	assert_almost_eq(f.camera_pitch(), Feyre.DEFAULT_PITCH, 0.02)


func test_r_press_is_a_short_shift_the_short_way_round() -> void:
	var f := _feyre()
	f.model.rotation.y = 0.0
	f.nudge_camera(-2.6, 0.0)
	var start := f.camera_yaw()
	var ev := InputEventAction.new()
	ev.action = &"camera_recenter"
	ev.pressed = true
	f._unhandled_input(ev)
	for i in 30:
		f._process(1.0 / 60.0)
	var turned := angle_difference(start, f.camera_yaw())
	assert_almost_eq(absf(turned), deg_to_rad(f.recenter_max_turn), 0.02, "one press turns at most the cap")
	assert_lt(absf(angle_difference(f.camera_yaw(), 0.0)), absf(angle_difference(start, 0.0)),
			"and toward behind her, the short way")


func test_recenter_is_bound_to_r_and_right_stick() -> void:
	var keys := []
	var buttons := []
	for e in InputMap.action_get_events(&"camera_recenter"):
		if e is InputEventKey:
			keys.append((e as InputEventKey).physical_keycode)
		elif e is InputEventJoypadButton:
			buttons.append((e as InputEventJoypadButton).button_index)
	assert_has(keys, KEY_R)
	assert_has(buttons, JOY_BUTTON_RIGHT_STICK)
	for e in InputMap.action_get_events(&"craft_arrow") if InputMap.has_action(&"craft_arrow") else []:
		if e is InputEventKey:
			assert_ne((e as InputEventKey).physical_keycode, KEY_R, "R no longer crafts arrows")


func test_invert_and_sensitivity_change_the_look() -> void:
	var f := _feyre()
	var before := f.camera_yaw()
	f._look(0.1, 0.0)
	var normal := f.camera_yaw() - before
	GameSettings.set_value(&"invert_x", true)
	before = f.camera_yaw()
	f._look(0.1, 0.0)
	assert_almost_eq(f.camera_yaw() - before, -normal, 0.0001)
	assert_ne(normal, 0.0)


func test_wriggle_free_escapes_an_overlap() -> void:
	var f := _feyre()
	_block(Vector3(0, 1, 0), Vector3(1.2, 2, 1.2))
	await wait_physics_frames(2)
	var space := f.get_world_3d().direct_space_state
	assert_false(WriggleFree.fits(space, f.global_position, f.collision_mask, f.get_rid()), "starts stuck")
	assert_true(f.wriggle_free())
	assert_true(WriggleFree.fits(space, f.global_position, f.collision_mask, f.get_rid()), "now free")
	assert_lt(f.global_position.distance_to(Vector3.ZERO), 3.0, "nearby, not across the map")


func test_return_home_follows_the_story() -> void:
	assert_eq(ReturnHome.destination(&"p0_winter").anchor, &"opening_cottage_dawn")
	assert_eq(ReturnHome.destination(&"p1_wolf_and_crossing").region, &"cottage")
	assert_eq(ReturnHome.destination(&"p3_house_and_woods").region, &"manor_estate")
	assert_eq(ReturnHome.destination(&"p5_calanmai").anchor, &"feyre_bedroom_window")


func test_player_position_saves_and_loads() -> void:
	var f := _feyre()
	f.global_position = Vector3(3, 0.05, -4)
	f.model.rotation.y = 1.1
	var placement := PlayerPlacement.new(f)
	var data := placement.save_state()
	f.global_position = Vector3.ZERO
	placement.load_state(JSON.parse_string(JSON.stringify(data)))
	assert_almost_eq(f.global_position.x, 3.0, 0.001)
	assert_almost_eq(f.global_position.z, -4.0, 0.001)
	assert_almost_eq(f.model.rotation.y, 1.1, 0.001)


func test_menu_pauses_and_holds_every_option() -> void:
	var menu := SettingsPanel.new()
	add_child_autofree(menu)
	menu.open()
	assert_true(menu.is_open())
	assert_true(get_tree().paused)
	assert_eq(menu._controls.size(), GameSettings.DEFAULTS.size() - 1, "every setting but text size has a control")
	assert_eq(menu._text_buttons.size(), GameSettings.TEXT_SIZES.size())
	assert_eq(menu._scheme_buttons.size(), 2, "arrows / WASD switch kept")
	var texts := []
	for b in menu.find_children("*", "Button", true, false):
		texts.append((b as Button).text)
	for t in ["Resume", "Return Home", "Save & Title", "Save & Quit", "Wriggle free"]:
		assert_has(texts, t)
	(menu._controls[&"invert_y"] as CheckBox).button_pressed = true
	assert_true(GameSettings.invert_y, "checkbox writes the setting")
	menu.close()
	assert_false(menu.is_open())
	assert_false(get_tree().paused)


func test_settings_stay_on_screen_at_every_text_size() -> void:
	var menu := SettingsPanel.new()
	add_child_autofree(menu)
	for i in GameSettings.TEXT_SIZES.size():
		GameSettings.set_value(&"text_size", i)
		menu.open()
		var h := menu._scroll.custom_minimum_size.y
		assert_gt(h, 200.0, "settings area visible at %s" % GameSettings.TEXT_SIZES[i])
		assert_lt(h, 1080.0 / GameSettings.TEXT_SCALES[i] - 300.0, "room left for title and buttons")
		if i <= 1:
			assert_lt(h, 760.0, "no needless scrolling at %s" % GameSettings.TEXT_SIZES[i])
		menu.close()


func test_title_screen_builds() -> void:
	var title := (load("res://ui/title/title_screen.tscn") as PackedScene).instantiate()
	add_child_autofree(title)
	var texts := []
	for b in title.find_children("*", "Button", true, false):
		texts.append((b as Button).text)
	assert_eq(texts, ["Continue", "New Game", "Quit"])
