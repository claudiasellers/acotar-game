## Contract test for docs/contracts/title.md: the boot flow and menu shape.
extends GutTest

const TITLE_SCENE := "res://ui/title/title_screen.tscn"
const SAVE_FILE := "user://saves/slot_0.json"

var _had_save := false
var _saved_bytes := PackedByteArray()


func before_each() -> void:
	_had_save = FileAccess.file_exists(SAVE_FILE)
	if _had_save:
		_saved_bytes = FileAccess.get_file_as_bytes(SAVE_FILE)
	GameSettings.pending_load_slot = ""


func after_each() -> void:
	if _had_save:
		var f := FileAccess.open(SAVE_FILE, FileAccess.WRITE)
		f.store_buffer(_saved_bytes)
		f.close()
	elif FileAccess.file_exists(SAVE_FILE):
		DirAccess.remove_absolute(SAVE_FILE)
	GameSettings.pending_load_slot = ""


func _title() -> Control:
	var t := (load(TITLE_SCENE) as PackedScene).instantiate() as Control
	add_child_autofree(t)
	return t


func _menu_texts(t: Control) -> Array:
	var texts := []
	for b in t.get_node("Menu").get_children():
		texts.append((b as Button).text)
	return texts


func test_game_scene_is_act1_and_never_the_title() -> void:
	var script := load("res://ui/title/title_screen.gd") as Script
	var game: String = script.get_script_constant_map()["GAME_SCENE"]
	assert_eq(game, "res://story/act1/act1_game.tscn")
	assert_true(ResourceLoader.exists(game))
	assert_ne(game, TITLE_SCENE)
	assert_eq(SettingsPanel.TITLE_SCENE, TITLE_SCENE, "Save & Title lands on this title")


func test_menu_without_a_save() -> void:
	if FileAccess.file_exists(SAVE_FILE):
		DirAccess.remove_absolute(SAVE_FILE)
	assert_eq(_menu_texts(_title()), ["New Game", "Settings", "Quit"])


func test_menu_with_a_save_and_continue_sets_the_slot() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_FILE.get_base_dir())
	var f := FileAccess.open(SAVE_FILE, FileAccess.WRITE)
	f.store_string("{}")
	f.close()
	var t := _title()
	assert_eq(_menu_texts(t), ["Continue", "New Game", "Settings", "Quit"])
	t.set(&"_leaving", true)  # don't actually leave the test scene
	t.call(&"_on_continue")
	assert_eq(GameSettings.pending_load_slot, "slot_0")


func test_title_settings_has_no_in_game_actions() -> void:
	var t := _title()
	t.call(&"_on_settings")
	await wait_process_frames(2)
	var settings := t.find_children("*", "TitleSettings", true, false)
	assert_eq(settings.size(), 1)
	var texts := []
	for b in (settings[0] as Node).find_children("*", "Button", true, false):
		texts.append((b as Button).text)
	assert_has(texts, "Back")
	for banned in ["Save & Title", "Save & Quit", "Return Home", "Wriggle free"]:
		assert_does_not_have(texts, banned)
	assert_false(t.get_tree().paused, "title keeps running behind settings")
	(settings[0] as TitleSettings).close()
	assert_true((t.get_node("Menu") as Control).visible)


func test_title_sets_no_story_state() -> void:
	var before := WorldState.all_flags().duplicate(true)
	_title()
	await wait_process_frames(3)
	var after := WorldState.all_flags()
	assert_eq(after, before, "R2: the title never touches WorldState")
