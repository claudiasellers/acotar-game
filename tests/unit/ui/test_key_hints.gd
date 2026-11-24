# gate: when:ui/hud/key_hints.gd,ui/hud/key_prompt.gd,story/act1/key_prompts.gd,ui/satchel/satchel_hud.gd,ui/menu/tips.gd,systems/settings/*
## One table of key hints for the whole game (KeyHints): a row shows while a
## system holds it or for a few seconds after a nudge, the first row in the
## table wins, each is taught once and remembered, and hints off leaves only
## the rows that must always show.
extends GutTest

const CFG := "user://test_key_hints_table.cfg"
const SETTINGS := "user://test_key_hints_table_settings.cfg"

var hints: KeyHints
var _saved_path: String


func before_each() -> void:
	Gameplay.reset()
	SatchelHud.ensure_actions()
	StoryControl.release()
	_saved_path = GameSettings.settings_path
	GameSettings.settings_path = SETTINGS
	GameSettings.load_settings()
	hints = KeyHints.of(get_tree())
	hints.use_settings(CFG)


func after_each() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CFG))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS))
	GameSettings.settings_path = _saved_path
	GameSettings.load_settings()
	hints.use_settings("user://settings.cfg")
	hints._nudged.clear()
	hints._held.clear()


func _holder() -> Node:
	var n := Node.new()
	add_child_autofree(n)
	return n


func test_there_is_one_table_and_every_row_names_a_key() -> void:
	assert_same(KeyHints.of(get_tree()), hints)
	for id: StringName in KeyHints.ROWS:
		var row := KeyHints.row(id)
		assert_ne(String(row[0][0]), "", "%s opens on a key" % id)
		for pair: Array in row:
			assert_ne(String(pair[1]), "", "%s says what the key does" % id)


func test_a_held_row_shows_until_learnt_and_is_remembered() -> void:
	var a := _holder()
	hints.hold(a, &"crouch")
	assert_eq(hints.wanted(), &"crouch")
	await wait_process_frames(2)
	assert_string_contains(hints.text(), "crouch")
	hints.learn(&"crouch")
	assert_eq(hints.wanted(), &"", "taught once")
	hints.use_settings(CFG)
	assert_false(hints.teaches(&"crouch"), "read back from the file")
	hints.forget_taught()
	assert_eq(hints.wanted(), &"crouch", "Show tips again")
	hints.hold(a, &"")
	assert_eq(hints.wanted(), &"")


func test_the_first_row_in_the_table_wins_and_a_freed_holder_lets_go() -> void:
	var a := _holder()
	var b := Node.new()
	add_child(b)
	hints.hold(a, &"look")
	hints.hold(b, &"sell")
	assert_eq(hints.wanted(), &"sell")
	b.free()
	assert_eq(hints.wanted(), &"look")


func test_hints_off_leaves_only_the_rows_that_always_show() -> void:
	var a := _holder()
	var b := _holder()
	hints.hold(a, &"walk")
	GameSettings.set_value(&"key_hints", false)
	assert_eq(hints.wanted(), &"")
	hints.hold(b, &"beast")
	assert_eq(hints.wanted(), &"beast")
	hints.learn(&"beast")
	assert_eq(hints.wanted(), &"beast", "never learnt")
	GameSettings.set_value(&"key_hints", true)


func test_a_nudge_shows_for_a_few_seconds_once() -> void:
	hints.nudge(&"satchel")
	assert_eq(hints.wanted(), &"satchel")
	hints._process(KeyHints.NUDGE_SECONDS - 0.5)
	assert_eq(hints.wanted(), &"satchel")
	hints._process(1.0)
	assert_eq(hints.wanted(), &"")
	hints.nudge(&"satchel")
	assert_eq(hints.wanted(), &"", "once")


func test_her_first_find_names_the_satchel_and_a_second_bow_the_bow_key() -> void:
	var satchel := SatchelHud.new()
	add_child_autofree(satchel)
	await wait_process_frames(3)
	Gameplay.inventory.add(&"arrow_wood", 2)
	assert_eq(hints.wanted(), &"", "arrows go to the quiver")
	Gameplay.inventory.add(&"ing_rose_red", 1)
	assert_eq(hints.wanted(), &"satchel")


func test_her_first_collection_entry_names_its_key() -> void:
	hints._process(0.016)
	Gameplay.collection.discovered.emit(&"ing_rose_red", &"flora")
	assert_eq(hints.wanted(), &"collection")
	assert_eq(KeyHints.row(&"collection")[0][1], "open the collection")
	Gameplay.reset()
	hints.forget_taught()
	hints._nudged.clear()
	hints._process(0.016)
	Gameplay.collection.discovered.emit(&"ing_rose_red", &"flora")
	assert_eq(hints.wanted(), &"collection", "a new story's book is heard too")


func test_a_thought_arrow_makings_and_a_found_place_nudge_their_keys() -> void:
	assert_true(FileAccess.get_file_as_string("res://ui/guide/guide_journal.gd").contains("nudge(&\"thought\")"))
	assert_true(FileAccess.get_file_as_string("res://ui/satchel/satchel_hud.gd").contains("nudge(&\"craft\")"))
	assert_true(FileAccess.get_file_as_string("res://ui/map/world_map_hud.gd").contains("nudge(&\"map\")"))
	for id: StringName in [&"thought", &"craft", &"map"]:
		assert_true(KeyHints.ROWS.has(id))


func test_act_one_holds_its_rows_through_the_table() -> void:
	var src := FileAccess.get_file_as_string("res://story/act1/key_prompts.gd")
	for gone: String in ["KeyPrompt.make", "ConfigFile", "const PROMPTS", "GameSettings"]:
		assert_false(src.contains(gone), "KeyPrompts still has %s" % gone)
	assert_true(src.contains("_hints.hold(self, current)"))
