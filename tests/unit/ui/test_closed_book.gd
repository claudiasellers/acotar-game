## The title is Feyre's journal, shut (docs/contracts/title.md): the cover
## carries the game's name in foil, lifts on its spine, and the stories are
## written on the first page under it. Its colours and type are the theme's.
extends GutTest

const TITLE_SCENE := "res://ui/title/title_screen.tscn"


func after_each() -> void:
	GameSettings.pending_load_slot = ""


func _title() -> Control:
	var t := (load(TITLE_SCENE) as PackedScene).instantiate() as Control
	add_child_autofree(t)
	return t


func _book() -> ClosedBook:
	var b := ClosedBook.new()
	add_child_autofree(b)
	return b


func test_the_cover_carries_the_name_in_foil() -> void:
	var cover := _book().get_node(^"Cover")
	var lines := {}
	for l: Label in cover.find_children("*", "Label", true, false):
		lines[l.text] = l
	assert_eq(lines.keys(), [ClosedBook.KICKER, ClosedBook.NAME, ClosedBook.COURT])
	assert_eq(ClosedBook.NAME, "Thorns and Roses")
	for l: Label in lines.values():
		assert_true(l.uppercase)
		assert_eq(l.get_theme_color(&"font_color"), JournalTheme.BOOK[&"foil"], l.text)
		assert_string_contains(l.get_theme_font(&"font").get(&"base_font").resource_path, "Marcellus")


func test_the_cover_lifts_on_its_spine_and_shuts_again() -> void:
	var book := _book()
	var cover := book.get_node(^"Cover") as Control
	var endpaper := book.get_node(^"Endpaper") as Control
	assert_false(book.open_now)
	assert_eq(cover.scale.x, 1.0)
	assert_almost_eq(endpaper.scale.x, 0.0, 0.001, "the endpaper is under the shut cover")
	assert_eq(cover.pivot_offset.x, 0.0, "the cover turns on the spine")
	assert_eq(endpaper.position.x + endpaper.pivot_offset.x, 0.0, "and so does its inside")
	watch_signals(book)
	book.lift(0.0)
	assert_true(book.open_now)
	assert_almost_eq(cover.scale.x, 0.0, 0.001, "edge-on: the engine keeps a hair of it")
	assert_eq(endpaper.scale.x, 1.0)
	assert_signal_emit_count(book, "lifted", 1)
	book.lift(0.0)
	assert_signal_emit_count(book, "lifted", 1, "an open book does not open again")
	book.close(0.0)
	assert_false(book.open_now)
	assert_eq(cover.scale.x, 1.0)
	assert_almost_eq(endpaper.scale.x, 0.0, 0.001)
	assert_signal_emit_count(book, "shut", 1)


func test_the_cover_lifts_over_time() -> void:
	var book := _book()
	book.lift(0.2)
	await wait_seconds(0.4)
	assert_almost_eq((book.get_node(^"Cover") as Control).scale.x, 0.0, 0.001)
	assert_almost_eq((book.get_node(^"Endpaper") as Control).scale.x, 1.0, 0.001)


func test_the_book_shows_her_tabs_and_the_page_is_inside_the_boards() -> void:
	var book := _book()
	var tabs := book.get_node(^"Pages").find_children("Tab*", "ColorRect", false, false)
	assert_eq(tabs.size(), JournalTheme.WASHES.size(), "one tab per wash, as on the open book")
	for i in tabs.size():
		assert_eq((tabs[i] as ColorRect).color, JournalTheme.wash(i))
		assert_lt((tabs[i] as Control).position.y, 0.0, "a tab stands above the boards")
	assert_true(Rect2(Vector2.ZERO, ClosedBook.SIZE).grow(-ClosedBook.INSET).encloses(ClosedBook.PAGE))


func test_the_book_colours_are_the_same_in_both_acts() -> void:
	var phase := PhaseManager.current_phase
	for token: StringName in JournalTheme.BOOK:
		PhaseManager.current_phase = &"p1_test"
		var human := JournalTheme.color(token)
		PhaseManager.current_phase = &"p2_test"
		assert_eq(JournalTheme.color(token), human, String(token))
		assert_eq(human, JournalTheme.BOOK[token])
		for act: JournalTheme.Act in [JournalTheme.Act.HUMAN, JournalTheme.Act.SPRING]:
			assert_false(JournalTheme.colors(act).has(token), "%s is the book's, not an act's" % token)
	PhaseManager.current_phase = phase


func test_the_title_is_the_shut_book_with_the_menu_beside_it() -> void:
	var t := _title()
	var book := t.get(&"book") as ClosedBook
	assert_not_null(book)
	assert_false(book.open_now)
	var menu := t.get_node(^"Menu") as Control
	for b: Button in menu.get_children():
		assert_eq(b.theme_type_variation, JournalTheme.TITLE_CHOICE, b.text)
	assert_gt(menu.position.x, book.position.x + ClosedBook.SIZE.x * book.scale.x, "the menu is clear of the cover")
	assert_eq((t.get_node(^"Tagline") as Label).text, "A life for a life.")


func test_the_stories_are_written_on_the_first_page() -> void:
	var t := _title()
	var book := t.get(&"book") as ClosedBook
	t.call(&"_on_load")
	assert_true(book.open_now, "Load lifts the cover")
	var slots := t.get_node(^"Slots") as TitleSlots
	await wait_seconds(ClosedBook.LIFT_SECONDS + 0.3)
	var page := book.page_rect().grow(2.0)
	assert_true(page.encloses(slots.get_global_rect()), "the list lies on the page: %s in %s" % [slots.get_global_rect(), page])
	for b: Button in slots.find_children("*", "Button", true, false):
		assert_true(b.theme_type_variation in [JournalTheme.PAGE_CHOICE, &"SatchelTab"], b.text)
	assert_false((t.get_node(^"Menu") as Control).visible)
	slots.close()
	assert_false(book.open_now, "going back shuts it")
	assert_true((t.get_node(^"Menu") as Control).visible)


func test_starting_lifts_the_cover_and_washes_to_the_page() -> void:
	var t := _title()
	var book := t.get(&"book") as ClosedBook
	var veil := t.get_node(^"Veil") as ColorRect
	# Stop before the scene change: the wash's last step is the load.
	t.call(&"_enter_game")
	assert_true(book.open_now)
	assert_eq(Color(veil.color, 1.0), JournalTheme.color(&"paper"), "the veil is the page's own paper")
	t.queue_free()
	await wait_process_frames(2)


func test_the_loading_page_is_her_paper_and_her_hand() -> void:
	var veil := LoadingVeil.new()
	add_child_autofree(veil)
	var fill := veil.get_child(0) as ColorRect
	assert_eq(fill.color, JournalTheme.color(&"paper"))
	var line := fill.get_child(0) as Label
	assert_eq(line.text, LoadingVeil.LINE)
	assert_eq(line.theme_type_variation, &"ReadText")


func test_the_film_names_the_game_as_the_cover_does() -> void:
	var card := FilmTitleCard.new()
	add_child_autofree(card)
	var texts := []
	for l: Label in card.find_children("*", "Label", true, false):
		texts.append(l.text)
		assert_eq(l.get_theme_color(&"font_color"), JournalTheme.BOOK[&"foil"])
	assert_eq(texts, [ClosedBook.KICKER, ClosedBook.NAME, ClosedBook.COURT])
