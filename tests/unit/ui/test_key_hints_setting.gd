## Key hints (the prompts that teach a key the first time it matters) are one
## setting, GameSettings' "key_hints", and it is offered in two places: the
## settings page under Play, and the page New Game asks its story on.
extends GutTest

const PATH := "user://test_key_hints.cfg"

var _saved_path: String


func before_each() -> void:
	_saved_path = GameSettings.settings_path
	GameSettings.settings_path = PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	GameSettings.load_settings()


func after_each() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	GameSettings.settings_path = _saved_path
	GameSettings.load_settings()


func test_hints_are_on_until_she_turns_them_off_and_it_is_kept() -> void:
	assert_true(GameSettings.get_value(&"key_hints"), "on for a new player")
	watch_signals(GameSettings)
	GameSettings.set_value(&"key_hints", false)
	assert_signal_emitted_with_parameters(GameSettings, "changed", [&"key_hints"])
	GameSettings.load_settings()
	assert_false(GameSettings.get_value(&"key_hints"), "read back from the file")
	var file := ConfigFile.new()
	file.load(PATH)
	assert_eq(file.get_value("play", "key_hints"), false)


func test_the_settings_page_has_the_row_under_play() -> void:
	var page := SettingsTab.new()
	add_child_autofree(page)
	await wait_process_frames(2)
	page._sync()
	var box := page._controls[&"key_hints"] as CheckBox
	assert_true(box.button_pressed)
	box.button_pressed = false
	assert_false(GameSettings.get_value(&"key_hints"))
	GameSettings.set_value(&"key_hints", true)
	page._sync()
	assert_true(box.button_pressed, "the row follows the setting")


func test_new_game_asks_on_its_page_and_load_does_not() -> void:
	var slots := TitleSlots.new()
	add_child_autofree(slots)
	slots.open(TitleSlots.Mode.NEW)
	await wait_process_frames(2)
	var box := slots.get_node(^"KeyHints") as CheckBox
	assert_true(box.button_pressed)
	assert_lt(box.get_index(), slots.get_node(^"Back").get_index(), "above Back")
	box.button_pressed = false
	assert_false(GameSettings.get_value(&"key_hints"))
	slots.open(TitleSlots.Mode.LOAD)
	await wait_process_frames(2)
	assert_null(slots.get_node_or_null(^"KeyHints"), "Load has no such choice")
	slots.close()
	await wait_process_frames(2)
