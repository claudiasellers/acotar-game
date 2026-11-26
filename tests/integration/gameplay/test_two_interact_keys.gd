# gate: when:systems/interaction/*,ui/hud/use_prompt.gd,ui/hud/key_prompt.gd,ui/hud/key_hints.gd,characters/feyre/feyre.gd,project.godot
## Two things in reach never both say E (owner, 2026-11-26). The first is on
## `interact` (E, a tap of the pad's X), the second on `interact_alt` (T, a
## hold of X), and the one use prompt names both. On a pad with something in
## slot 2, a tap acts on release and a hold past Interactor.HOLD_SECOND does
## slot 2; with nothing in slot 2, X acts on press (director, R14).
extends GutTest

const TEST_SET := preload("res://data/phases/m0_test_phases.tres")
const SCENE := preload("res://world/shared/test_hill/test_hill.tscn")


## A station with a first and, when alt_verb is set, a second action.
class Thing extends Node3D:
	var station_id := &"two_key_thing"
	var use_verb := ""
	var alt_verb := ""
	var used := 0
	var alted := 0

	func open_now() -> bool:
		return true

	func use(_user: Node) -> void:
		used += 1

	func use_alt(_user: Node) -> void:
		alted += 1


var hill: Node3D
var feyre: Feyre


func before_each() -> void:
	WorldState.clear()
	Gameplay.reset()
	PhaseManager.start(TEST_SET)
	StoryControl.release()
	SatchelHud.pad_active = false
	hill = SCENE.instantiate()
	add_child_autofree(hill)
	feyre = hill.feyre
	feyre.set_physics_process(false)
	await wait_physics_frames(5)
	feyre.global_position = Vector3(400.0, 80.0, 400.0)


func after_each() -> void:
	SatchelHud.pad_active = false
	StoryControl.release()


func _thing(verb: String, alt: String = "", offset: float = 1.0) -> Thing:
	var t := Thing.new()
	t.use_verb = verb
	t.alt_verb = alt
	t.add_to_group(&"station")
	hill.add_child(t)
	t.global_position = feyre.global_position + Vector3(offset, 0, 0)
	return t


func _pad_x(pressed: bool) -> void:
	var e := InputEventJoypadButton.new()
	for bound in InputMap.action_get_events(&"interact"):
		if bound is InputEventJoypadButton:
			e.button_index = (bound as InputEventJoypadButton).button_index
	e.device = 0
	e.pressed = pressed
	e.pressure = 1.0 if pressed else 0.0
	Input.parse_input_event(e)


func _key(action: StringName) -> void:
	for pressed: bool in [true, false]:
		var e := InputEventAction.new()
		e.action = action
		e.pressed = pressed
		Input.parse_input_event(e)
		await wait_process_frames(2)


func _prompt_text() -> String:
	await wait_seconds(Interactor.PROMPT_REFRESH * 2.0 + 0.05)
	await wait_process_frames(2)
	return UsePrompt.of(get_tree()).text()


func test_one_thing_with_two_actions_names_two_keys() -> void:
	var mare := _thing("ride", "tend")
	assert_eq(await _prompt_text(), "E   ride  ·  T   tend", "two keys, slot 1 first")
	SatchelHud.pad_active = true
	assert_eq(await _prompt_text(), "X   ride  ·  Hold X   tend", "on a pad the second is a hold")
	SatchelHud.pad_active = false
	await _key(&"interact")
	assert_eq([mare.used, mare.alted], [1, 0], "E does the first")
	await _key(&"interact_alt")
	assert_eq([mare.used, mare.alted], [1, 1], "T does the second")


func test_two_things_in_reach_take_one_key_each() -> void:
	var near := _thing("play a few notes", "", 0.8)
	var far := _thing("rest", "", 1.6)
	assert_eq(await _prompt_text(), "E   play a few notes  ·  T   rest", "nearest on E")
	await _key(&"interact_alt")
	assert_eq([near.used, far.used], [0, 1], "T uses the second")


func test_a_pad_tap_acts_on_release_with_a_second_in_reach() -> void:
	var mare := _thing("ride", "tend")
	await wait_process_frames(2)
	_pad_x(true)
	await wait_process_frames(3)
	assert_eq(mare.used, 0, "a press waits: it could be a hold")
	_pad_x(false)
	await wait_process_frames(3)
	assert_eq([mare.used, mare.alted], [1, 0], "a tap under %.1f s does the first, on release" % Interactor.HOLD_SECOND)


func test_a_pad_hold_does_the_second() -> void:
	var mare := _thing("ride", "tend")
	await wait_process_frames(2)
	_pad_x(true)
	await wait_seconds(Interactor.HOLD_SECOND + 0.2)
	assert_eq([mare.used, mare.alted], [0, 1], "held past %.1f s it does the second" % Interactor.HOLD_SECOND)
	_pad_x(false)
	await wait_process_frames(3)
	assert_eq([mare.used, mare.alted], [0, 1], "letting go after the hold does nothing more")


func test_a_pad_press_acts_at_once_with_nothing_second() -> void:
	var stone := _thing("trace the whorl")
	await wait_process_frames(2)
	_pad_x(true)
	await wait_process_frames(3)
	assert_eq(stone.used, 1, "alone in reach, X acts on press")
	_pad_x(false)
	await wait_process_frames(3)
	assert_eq(stone.used, 1, "and once")
