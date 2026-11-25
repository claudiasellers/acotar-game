# gate: when:ui/menu/*,ui/hud/key_prompt.gd,ui/hud/vitals/status_row.gd,story/act1/key_prompts.gd,systems/settings/*,core/input_settings.gd
## The settings page lists every key from the InputMap with its pad button,
## says truly what Gentle Mode does, and can make every tip show once more
## (the UX review, 2026-11-24).
extends GutTest

const CFG := "user://test_keys_and_tips.cfg"

var page: SettingsTab


func before_each() -> void:
	SatchelHud.pad_active = false
	MenuShell.close_all(get_tree())
	page = SettingsTab.new()
	add_child_autofree(page)
	await wait_process_frames(2)


func after_each() -> void:
	MenuShell.close_all(get_tree())
	SatchelHud.pad_active = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CFG))


func test_every_key_takes_the_right_sheet_and_gives_it_back() -> void:
	page.open()
	await wait_process_frames(2)
	assert_false(page.keys.visible)
	page.keys_chip.button_pressed = true
	assert_true(page.keys.visible)
	assert_false(page.get(&"_right").visible, "the settings stand aside")
	assert_not_null(page.keys.rows.get_node_or_null(^"interact"))
	assert_not_null(page.keys.rows.get_node_or_null(^"satchel_open"))
	assert_null(page.keys.rows.get_node_or_null(^"an_action_nobody_added"))
	page.keys_chip.button_pressed = false
	assert_true(page.get(&"_right").visible)


func test_a_row_names_the_key_and_the_pad_from_the_input_map() -> void:
	for spec: Array in KeyList.ROWS:
		assert_ne(spec[1], "", "%s says what it does" % spec[0])
		if not InputMap.has_action(spec[0]):
			continue
		var said := KeyList.words(spec)
		assert_ne(said[1], "", "%s has a key or mouse word" % spec[0])
	assert_eq(KeyList.words([&"interact", "Use", "", ""]), ["Use", "E", "X"] as Array[String])
	assert_eq(KeyList.words([&"move_forward", "Move", "scheme", "Left stick"])[1], InputSettings.SCHEME_NAMES[InputSettings.scheme])
	assert_eq(KeyPrompt.pad_word(&"satchel_open"), "", "no pad button of its own")
	for button: JoyButton in [JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT,
			JOY_BUTTON_BACK, JOY_BUTTON_START, JOY_BUTTON_LEFT_STICK, JOY_BUTTON_RIGHT_STICK]:
		assert_true(KeyPrompt.PAD_BUTTONS.has(button), "pad button %d has a name" % button)


func test_gentle_mode_says_what_it_does() -> void:
	var said := ""
	for l in page.find_children("*", "Label", true, false):
		said += (l as Label).text + "\n"
	assert_false(said.contains("sprints twice"), "sprint is free; the old line was false")
	assert_string_contains(said, "Kinder jumps and ledges")
	assert_string_contains(said, "When her health and stamina show")


class Taught extends Node:
	var taught := {&"x": true}

	func _ready() -> void:
		add_to_group(Tips.GROUP)

	func forget_taught() -> void:
		taught.clear()


func test_show_tips_again_forgets_everything_taught_once() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(KeyHints.SECTION, "aim", true)
	cfg.set_value(VitalsStatusRow.TAUGHT_SECTION, "cold", true)
	cfg.set_value("audio", "music_volume", 0.4)
	cfg.save(CFG)
	WorldState.set_flag(TabNote.FLAG % &"map")
	var node := Taught.new()
	add_child_autofree(node)
	Tips.show_again(get_tree(), CFG)
	var after := ConfigFile.new()
	after.load(CFG)
	assert_false(after.has_section(KeyHints.SECTION))
	assert_false(after.has_section(VitalsStatusRow.TAUGHT_SECTION))
	assert_eq(after.get_value("audio", "music_volume"), 0.4, "nothing else is touched")
	assert_false(WorldState.has_flag(TabNote.FLAG % &"map"), "a journal page says its line again")
	assert_true(node.taught.is_empty(), "and what is running forgets too")
	assert_not_null(page.find_child("TipsAgain", true, false), "the button is on the page")
