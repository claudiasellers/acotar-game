# gate: when:systems/settings/*,ui/menu/settings_tab.gd,ui/hud/vitals/*,systems/vitals/*,characters/feyre/movement/crouch_motor.gd
## The bow and fights settings (aim help, hit pause, hold to break free)
## and the two edges that tell her of danger without a marker: the page's
## edge drawing in while she is hard to see, and the beat of an attack she
## cannot see.
extends GutTest

const PATH := "user://test_bow_and_fights.cfg"

var _saved_path: String


func before_each() -> void:
	_saved_path = GameSettings.settings_path
	GameSettings.settings_path = PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	GameSettings.load_settings()


func after_each() -> void:
	MenuShell.of(get_tree()).close()
	get_tree().paused = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	GameSettings.settings_path = _saved_path
	GameSettings.load_settings()


func test_the_three_settings_and_what_gentle_mode_does() -> void:
	assert_eq(GameSettings.SOFT_AIM_LEVELS[int(GameSettings.get_value(&"soft_aim"))], "Light")
	assert_eq(GameSettings.HIT_STOP_LEVELS[int(GameSettings.get_value(&"hit_stop"))], "Full")
	assert_false(GameSettings.break_free_hold)
	GameSettings.set_value(&"gentle_mode", true)
	assert_true(GameSettings.break_free_hold, "Gentle Mode holds for her")
	assert_false(GameSettings.get_value(&"break_free_hold"), "without changing her own choice")
	GameSettings.set_value(&"gentle_mode", false)
	GameSettings.set_value(&"break_free_hold", true)
	assert_true(GameSettings.break_free_hold)


func test_the_page_steps_through_them() -> void:
	var page := SettingsTab.new()
	add_child_autofree(page)
	await wait_process_frames(2)
	page.open()
	await wait_process_frames(2)
	var aim := page._controls[&"soft_aim"] as Button
	var stop := page._controls[&"hit_stop"] as Button
	assert_ne(aim.text, "", "aim help shows its setting")
	assert_ne(stop.text, "", "hit pause shows its setting")
	var aim_was: Variant = GameSettings.get_value(&"soft_aim")
	var first := aim.text
	aim.pressed.emit()
	assert_ne(aim.text, first, "a press steps aim help on, and the button says so")
	assert_ne(GameSettings.get_value(&"soft_aim"), aim_was, "and the setting follows")
	var second := aim.text
	aim.pressed.emit()
	assert_ne(aim.text, second, "and on again")
	stop.pressed.emit()
	assert_eq(GameSettings.get_value(&"hit_stop"), 1)
	(page._controls[&"break_free_hold"] as CheckBox).button_pressed = true
	assert_true(GameSettings.get_value(&"break_free_hold"))
	for key: StringName in [&"soft_aim", &"hit_stop", &"break_free_hold"]:
		var says := (page._controls[key] as Control).get_parent().get_child(1) as Label
		assert_gt(says.text.length(), 20, "%s has what it does written beside it" % key)
	var left := page.left_sheet()
	assert_lte((left.get_child(0) as Control).get_combined_minimum_size().y, left.size.y, "the left sheet still fits")
	page.close()


func test_an_unseen_attack_beats_on_its_side_until_it_lands() -> void:
	var fx := VitalsEdgeFx.new()
	add_child_autofree(fx)
	VitalsEdgeFx.warn(get_tree(), -1.0, 2.0)
	fx._process(0.1)
	var early := fx.value(&"warn")
	assert_gt(early, 0.0)
	assert_eq(fx.material.get_shader_parameter(&"warn_side"), -1.0)
	fx._process(1.5)
	assert_gt(fx.value(&"warn"), early, "stronger as it nears")
	fx._process(0.5)
	assert_eq(fx.value(&"warn"), 0.0, "gone when it lands")
	GameSettings.set_value(&"hit_marks", false)
	VitalsEdgeFx.warn(get_tree(), 1.0, 2.0)
	fx._process(0.1)
	assert_eq(fx.value(&"warn"), 0.0, "off with the hit marks")


func test_the_page_edge_draws_in_while_she_is_hard_to_see() -> void:
	var src := FileAccess.get_file_as_string("res://ui/hud/vitals/vitals_hud.gd")
	assert_true(src.contains("t[&\"hidden\"] = clampf(inverse_lerp(1.0, HIDDEN_FULL, Vitals.sight_scale(_player)), 0.0, 1.0)"))
	assert_eq(VitalsHud.HIDDEN_FULL, 0.5)
	assert_almost_eq(clampf(inverse_lerp(1.0, VitalsHud.HIDDEN_FULL, CrouchMotor.SIGHT_CROUCHED), 0.0, 1.0), 0.9, 0.001, "crouched is nearly all the way")
	assert_true(VitalsEdgeFx.EASED.has(&"hidden"), "it eases in and out")


func test_the_stamina_bow_shakes_when_she_has_too_little() -> void:
	var hud := VitalsHud.new()
	add_child_autofree(hud)
	await wait_process_frames(2)
	assert_eq(hud.stamina_bow.rotation, 0.0)
	VitalsHud.stamina_refused(get_tree())
	assert_gt(hud._stamina_timer, 0.0, "the bow shows itself")
	await wait_seconds(0.1)
	assert_ne(hud.stamina_bow.rotation, 0.0, "shaking its head")
	await wait_seconds(0.4)
	assert_almost_eq(hud.stamina_bow.rotation, 0.0, 0.001, "and still again")
