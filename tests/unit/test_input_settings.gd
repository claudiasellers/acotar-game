extends GutTest

const PATH := "user://test_settings.cfg"

var _saved_path: String
var _saved_scheme: InputSettings.Scheme


func before_each() -> void:
	_saved_path = InputSettings.settings_path
	_saved_scheme = InputSettings.scheme
	InputSettings.settings_path = PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func after_each() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	InputSettings.settings_path = _saved_path
	InputSettings.scheme = _saved_scheme
	InputSettings.apply()


func _keys(action: StringName) -> Array:
	var keys: Array = []
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			keys.append((event as InputEventKey).physical_keycode)
	return keys


func _has_joypad(action: StringName) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadMotion:
			return true
	return false


func test_arrows_are_the_default() -> void:
	InputSettings.load_settings()
	assert_eq(InputSettings.scheme, InputSettings.Scheme.ARROWS)
	assert_eq(_keys(&"move_forward"), [KEY_UP])
	assert_eq(_keys(&"move_left"), [KEY_LEFT])


func test_switching_to_wasd_rebinds_keys_and_keeps_the_gamepad() -> void:
	InputSettings.set_scheme(InputSettings.Scheme.WASD)
	assert_eq(_keys(&"move_forward"), [KEY_W])
	assert_eq(_keys(&"move_back"), [KEY_S])
	assert_eq(_keys(&"move_left"), [KEY_A])
	assert_eq(_keys(&"move_right"), [KEY_D])
	assert_true(_has_joypad(&"move_forward"), "stick binding survives the remap")


func test_the_choice_survives_a_relaunch() -> void:
	InputSettings.set_scheme(InputSettings.Scheme.WASD)
	InputSettings.scheme = InputSettings.Scheme.ARROWS
	InputSettings.load_settings()
	assert_eq(InputSettings.scheme, InputSettings.Scheme.WASD)
	assert_eq(_keys(&"move_right"), [KEY_D])
