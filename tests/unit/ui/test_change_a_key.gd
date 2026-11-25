# gate: when:core/input_settings.gd,ui/menu/key_list.gd,ui/menu/settings_tab.gd,ui/hud/key_prompt.gd,project.godot
## A key or mouse button is hers to change from the Every key list: press
## its cap, then the key. A key another row had is swapped, a key that moves
## her is refused, the pad is left alone, and the choice is remembered.
extends GutTest

const PATH := "user://test_change_a_key.cfg"

var _saved_path: String
var list: KeyList


func before_each() -> void:
	_saved_path = InputSettings.settings_path
	InputSettings.settings_path = PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	InputSettings.load_settings()
	list = KeyList.new()
	add_child_autofree(list)
	InputSettings.keys_changed.connect(list.refresh)
	list.refresh()


func after_each() -> void:
	InputSettings.keys_changed.disconnect(list.refresh)
	InputSettings.reset_keys()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	InputSettings.settings_path = _saved_path
	InputSettings.load_settings()
	SatchelHud.pad_active = false


func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.pressed = true
	return e


func _press_cap(action: String) -> void:
	(list.rows.get_node(action).find_child("Bind", true, false) as Button).pressed.emit()


func test_she_can_shoot_from_the_keyboard() -> void:
	assert_eq(KeyPrompt.board_word(&"fire"), "Left mouse")
	_press_cap("fire")
	assert_eq(list.listening, &"fire")
	list._input(_key(KEY_K))
	assert_eq(list.listening, &"")
	assert_eq(KeyPrompt.board_word(&"fire"), "K")
	assert_true(InputMap.action_has_event(&"fire", _key(KEY_K)))
	assert_eq(KeyPrompt.pad_word(&"fire"), "RT", "the pad keeps its trigger")
	assert_string_contains(list.note.text, "K")
	InputSettings.load_settings()
	assert_eq(KeyPrompt.board_word(&"fire"), "K", "remembered")
	(list.rows.find_child("Reset", true, false) as Button).pressed.emit()
	assert_eq(KeyPrompt.board_word(&"fire"), "Left mouse", "as it came")
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	assert_false(cfg.has_section(InputSettings.KEYS_SECTION))


func test_a_key_another_row_had_is_swapped() -> void:
	var was := KeyPrompt.board_word(&"interact")
	var other := KeyPrompt.board_word(&"cycle_bow")
	_press_cap("interact")
	var taken := InputSettings.board_events(&"cycle_bow")[0].duplicate() as InputEventKey
	taken.pressed = true
	list._input(taken)
	assert_eq(KeyPrompt.board_word(&"interact"), other)
	assert_eq(KeyPrompt.board_word(&"cycle_bow"), was, "the two swapped")
	assert_string_contains(list.note.text, "Change bow moved to %s." % was, "and the list says so")


func test_a_key_that_moves_her_is_refused_and_esc_leaves_it_be() -> void:
	var was := KeyPrompt.board_word(&"interact")
	_press_cap("interact")
	list._input(_key(InputSettings.KEYS[InputSettings.scheme][&"move_forward"]))
	assert_eq(KeyPrompt.board_word(&"interact"), was)
	assert_eq(list.note.text, "That key moves her.")
	_press_cap("interact")
	list._input(_key(KEY_ESCAPE))
	assert_eq(list.listening, &"")
	assert_eq(KeyPrompt.board_word(&"interact"), was)


func test_rows_whose_words_are_given_cannot_be_changed() -> void:
	assert_null(list.rows.get_node("move_forward").find_child("Bind", true, false))
	assert_null(list.rows.get_node("look_left").find_child("Bind", true, false))
	assert_not_null(list.rows.get_node("aim").find_child("Bind", true, false))


func test_a_new_movement_scheme_takes_its_keys_back() -> void:
	InputSettings.set_scheme(InputSettings.Scheme.WASD)
	assert_true(InputSettings.rebind(&"cycle_bow", _key(KEY_UP), KeyList.changeable()))
	InputSettings.set_scheme(InputSettings.Scheme.ARROWS)
	assert_false(InputSettings.rebound(&"cycle_bow"), "Up moves her again")
	assert_eq(KeyPrompt.board_word(&"cycle_bow"), "B")
	InputSettings.set_scheme(InputSettings.Scheme.WASD)


func test_a_mouse_button_or_the_wheel_can_be_given() -> void:
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_MIDDLE
	wheel.pressed = true
	_press_cap("strike")
	list._input(wheel)
	assert_eq(KeyPrompt.board_word(&"strike"), "Middle mouse")
	assert_eq(KeyPrompt.board_word(&"arrow_next"), "Wheel down")
