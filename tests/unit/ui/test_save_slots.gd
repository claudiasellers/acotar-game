## Contract: three story slots, each its own file. Continue takes the story
## played last; a save from before slots (slot_0) is Story 1, read as it is;
## New Game and Delete ask on the title before a story is lost.
extends GutTest

const TITLE_SCENE := "res://ui/title/title_screen.tscn"

var _kept: Dictionary = {}


func before_each() -> void:
	for slot in SaveSystem.SLOTS:
		for path in _paths(slot):
			if FileAccess.file_exists(path):
				_kept[path] = FileAccess.get_file_as_bytes(path)
		SaveSystem.delete_save(slot)
	GameSettings.pending_load_slot = ""


func after_each() -> void:
	for slot in SaveSystem.SLOTS:
		SaveSystem.delete_save(slot)
	for path: String in _kept:
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_buffer(_kept[path])
		f.close()
	_kept.clear()
	GameSettings.pending_load_slot = ""
	SaveSystem.active_slot = "slot_0"
	SaveSystem.play_seconds = 0.0


func _paths(slot: String) -> Array[String]:
	var p := "%s/%s.json" % [SaveSystem.SAVE_DIR, slot]
	return [p, p + SaveSystem.BACKUP_SUFFIX]


func _write(slot: String, data: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(SaveSystem.SAVE_DIR)
	var f := FileAccess.open(_paths(slot)[0], FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()


func _story(day: int, saved_at: int) -> Dictionary:
	return {"version": 2, "saved_at": saved_at, "play_seconds": 600, "clock": {"day": day, "time_of_day": 0.3},
		"phase": {"phase": "p2_grounds", "phase_set": "res://data/phases/spring_court_phases.tres"}}


func _title() -> Control:
	var t := (load(TITLE_SCENE) as PackedScene).instantiate() as Control
	add_child_autofree(t)
	return t


func _slots(t: Control) -> TitleSlots:
	return t.get_node(^"Slots") as TitleSlots


func _press(b: Button) -> void:
	b.pressed.emit()


func test_there_are_three_slots_and_the_old_save_is_story_one() -> void:
	assert_eq(SaveSystem.SLOTS, ["slot_0", "slot_1", "slot_2"] as Array[String])
	# A save from before slots: no saved_at, no play time.
	var old := _story(7, 0)
	old.erase("saved_at")
	old.erase("play_seconds")
	_write("slot_0", old)
	var before := FileAccess.get_file_as_string(_paths("slot_0")[0])
	var info := SaveSystem.slot_info("slot_0")
	assert_true(info.readable)
	assert_eq(info.phase, "The grounds")
	assert_eq(info.day, 7)
	assert_eq(info.play_seconds, -1, "no play time to show")
	assert_gt(int(info.saved_at), 0, "the file's own date stands in")
	assert_eq(TitleSlots.slot_name("slot_0"), "Story 1")
	assert_eq(SaveSystem.latest_slot(), "slot_0")
	_title()
	assert_eq(FileAccess.get_file_as_string(_paths("slot_0")[0]), before, "untouched")


func test_continue_takes_the_story_played_last() -> void:
	_write("slot_0", _story(2, 1000))
	_write("slot_2", _story(9, 3000))
	_write("slot_1", _story(4, 2000))
	var t := _title()
	t.set(&"_leaving", true)
	t.call(&"_on_continue")
	assert_eq(GameSettings.pending_load_slot, "slot_2")


func test_load_lists_the_slots_and_plays_the_one_picked() -> void:
	_write("slot_1", _story(4, 2000))
	var t := _title()
	t.call(&"_on_load")
	var slots := _slots(t)
	assert_true(slots.visible)
	assert_false((t.get_node(^"Menu") as Control).visible)
	assert_true((slots.get_node(^"slot_0/Pick") as Button).disabled, "nothing to load in an empty slot")
	assert_string_contains((slots.get_node(^"slot_0/Pick") as Button).text, "Empty")
	var pick := slots.get_node(^"slot_1/Pick") as Button
	assert_eq(pick.text, "Story 2  ·  The grounds")
	assert_string_starts_with((slots.get_node(^"slot_1_details") as Label).text, "Day 4  ·  10 min played")
	t.set(&"_leaving", true)
	_press(pick)
	assert_eq(GameSettings.pending_load_slot, "slot_1")


func test_new_game_asks_before_a_story_is_overwritten() -> void:
	_write("slot_0", _story(4, 2000))
	var t := _title()
	t.call(&"_on_new_game")
	var slots := _slots(t)
	_press(slots.get_node(^"slot_0/Pick") as Button)
	assert_eq(slots.asking, "slot_0", "a used slot asks first")
	assert_true(SaveSystem.has_save("slot_0"), "nothing lost by asking")
	_press(slots.get_node(^"Keep") as Button)
	assert_eq(slots.asking, "")
	assert_true(SaveSystem.has_save("slot_0"), "Keep it keeps it")
	_press(slots.get_node(^"slot_0/Pick") as Button)
	t.set(&"_leaving", true)  # don't leave the test scene
	_press(slots.get_node(^"Yes") as Button)
	assert_false(SaveSystem.has_save("slot_0"), "the old story and its backup go")
	assert_eq(SaveSystem.active_slot, "slot_0", "the new story saves there")
	assert_eq(GameSettings.pending_load_slot, "", "a new game, not a load")


func test_new_game_in_an_empty_slot_just_begins() -> void:
	_write("slot_0", _story(4, 2000))
	var t := _title()
	t.call(&"_on_new_game")
	t.set(&"_leaving", true)
	_press(_slots(t).get_node(^"slot_2/Pick") as Button)
	assert_eq(SaveSystem.active_slot, "slot_2")
	assert_true(SaveSystem.has_save("slot_0"), "the other story is left alone")


func test_delete_asks_and_the_menu_follows() -> void:
	_write("slot_1", _story(4, 2000))
	var t := _title()
	assert_has(_menu(t), "Load")
	t.call(&"_on_load")
	var slots := _slots(t)
	_press(slots.get_node(^"slot_1/Delete") as Button)
	assert_eq(slots.asking, "slot_1")
	assert_true(SaveSystem.has_save("slot_1"))
	_press(slots.get_node(^"Yes") as Button)
	assert_false(SaveSystem.has_save("slot_1"))
	assert_false(slots.visible, "nothing left to load")
	assert_eq(_menu(t), ["New Game", "Settings", "Quit"])


func test_the_fresh_program_after_a_game_keeps_the_slot_chosen() -> void:
	var script := load("res://ui/title/title_screen.gd") as Script
	var arg: String = script.get_script_constant_map()["NEW_STORY_ARG"]
	assert_eq(script.call(&"new_story_from", PackedStringArray([arg + "slot_1"])), "slot_1")
	assert_eq(script.call(&"new_story_from", PackedStringArray([arg + "../etc"])), "")
	assert_eq(script.call(&"new_story_from", PackedStringArray()), "")


func _menu(t: Control) -> Array:
	var texts := []
	for b in t.get_node(^"Menu").get_children():
		if not b.is_queued_for_deletion():
			texts.append((b as Button).text)
	return texts
