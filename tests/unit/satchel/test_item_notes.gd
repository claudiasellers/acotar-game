## Every thing Feyre can carry has her two notes for the satchel study.
extends GutTest


func test_every_item_has_two_notes() -> void:
	for id in ItemCatalog.all_ids():
		var notes := ItemNotes.of(id)
		assert_not_null(notes, "%s has no notes in data/satchel/notes" % id)
		if notes:
			assert_eq(notes.id, id)
			assert_eq(notes.labels.size(), 2, "%s: two notes" % id)
			assert_true(notes.canon in ["C", "C?", "X"], "%s: canon tag (R7)" % id)


func test_every_dish_has_notes() -> void:
	for file in ResourceLoader.list_directory("res://data/dishes"):
		if not file.ends_with(".tres"):
			continue
		var dish := load("res://data/dishes".path_join(file)) as DishData
		var notes := ItemNotes.of(StringName(SatchelEntries.DISH_PREFIX + String(dish.id)))
		assert_not_null(notes, "dish %s has no notes" % dish.id)


func test_notes_are_short_and_plain() -> void:
	for file in ResourceLoader.list_directory(ItemNotes.FOLDER):
		var notes := load(ItemNotes.FOLDER + file) as ItemNotes
		assert_not_null(notes, file)
		for label in notes.labels:
			assert_lt(label.length(), 24, "%s: \"%s\" fits beside the study" % [file, label])
			assert_eq(label, label.to_lower(), "%s: written small" % file)


func test_the_study_shows_the_selected_things_notes() -> void:
	var inv := Inventory.new()
	inv.add(&"ing_crow_feather")
	var menu := SatchelMenu.new(QuickBar.new(inv))
	add_child_autofree(menu)
	await wait_process_frames(2)
	menu.select(&"ing_crow_feather")
	await wait_process_frames(2)
	assert_eq(menu._notes[0].text, "black vane")
	assert_eq(menu._notes[1].text, "split quill")
