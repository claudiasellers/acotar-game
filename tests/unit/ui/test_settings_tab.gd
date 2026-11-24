## The settings page of Feyre's journal (ui/menu/settings_tab.gd): Esc in play
## opens the book on it, it holds every setting and every pause action, and
## the whole book stays on screen at every text size.
extends GutTest

const PATH := "user://test_settings_tab.cfg"

var _saved_path: String
var page: SettingsTab


func before_each() -> void:
	_saved_path = GameSettings.settings_path
	GameSettings.settings_path = PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	GameSettings.load_settings()
	page = SettingsTab.new()
	add_child_autofree(page)
	await wait_process_frames(2)


func after_each() -> void:
	MenuShell.of(get_tree()).close()
	get_tree().paused = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	GameSettings.settings_path = _saved_path
	GameSettings.load_settings()


func _button_texts() -> Array:
	var texts := []
	for b in page.find_children("*", "Button", true, false):
		texts.append((b as Button).text)
	return texts


func test_esc_opens_the_book_at_the_ribbon_and_pauses() -> void:
	ScreenStack.pause_requested.emit()
	assert_true(page.is_open(), "Esc with nothing open lands on the settings page")
	assert_true(get_tree().paused)
	var shell := MenuShell.of(get_tree())
	assert_eq(ScreenStack.top(), shell, "as the book, one screen")
	var tab := shell.get_node(^"ShellRoot/Ribbon/Tabs/Tab_settings") as Button
	assert_eq(tab.theme_type_variation, JournalTheme.RIBBON_TAB, "its tab hangs from the ribbon")
	assert_null(shell.get_node_or_null(^"ShellRoot/TabStrip/Tabs/Tab_settings"), "not on the index strip")
	shell.screen_cancel()
	assert_false(page.is_open(), "Esc again closes the book")
	assert_false(get_tree().paused)


func test_page_holds_every_setting_and_action() -> void:
	page.open()
	assert_eq(page._controls.size(), GameSettings.DEFAULTS.size() - 1, "every setting but text size has a control")
	assert_eq(page._text_buttons.size(), GameSettings.TEXT_SIZES.size())
	assert_eq(page._scheme_buttons.size(), 2, "arrows / WASD switch")
	assert_eq(page._guide_buttons.size(), GuideSettings.LABELS.size(), "Feyre's thoughts")
	var texts := _button_texts()
	for t in ["Resume", "Wriggle free", "Return Home", "Save & Title", "Save & Quit"]:
		assert_has(texts, t)
	(page._controls[&"invert_y"] as CheckBox).button_pressed = true
	assert_true(GameSettings.invert_y, "a check box writes its setting")
	(page._controls[&"music_volume"] as HSlider).value = 0.25
	assert_almost_eq(float(GameSettings.get_value(&"music_volume")), 0.25, 0.001, "a slider writes its setting")
	GameSettings.set_value(&"hud_mode", 2)
	var modes := (page._controls[&"hud_mode"] as Control).get_children()
	assert_true((modes[2] as Button).button_pressed, "and the page follows a setting changed elsewhere")
	assert_true((page._controls[&"edge_fx"] as Button).text.begins_with("Edges: "))


func test_title_page_has_no_game_to_act_on() -> void:
	var title_page := SettingsTab.new()
	title_page.in_game = false
	title_page.tab_id = &"settings_on_title"
	add_child_autofree(title_page)
	await wait_process_frames(2)
	title_page.open()
	assert_false(get_tree().paused, "nothing to pause")
	var texts := []
	for b in title_page.find_children("*", "Button", true, false):
		texts.append((b as Button).text)
	assert_has(texts, "Back")
	for gone in ["Resume", "Wriggle free", "Return Home", "Save & Title", "Save & Quit"]:
		assert_does_not_have(texts, gone)
	assert_null(title_page._hint, "and no controls hint of its own")


func test_book_stays_on_screen_at_every_text_size() -> void:
	for i in GameSettings.TEXT_SIZES.size():
		GameSettings.set_value(&"text_size", i)
		page.open()
		await wait_process_frames(2)
		var view := get_viewport().get_visible_rect()
		var book := BookLayout.on_screen(view.size, Rect2(Vector2.ZERO, BookLayout.SIZE))
		var at := GameSettings.TEXT_SIZES[i]
		assert_true(view.encloses(book), "the whole book is on screen at %s" % at)
		assert_almost_eq(page._book.scale.x, BookLayout.fit(view.size), 0.001, "the page shrinks with it at %s" % at)
		assert_almost_eq(page._book.position.x, book.position.x, 0.5)
		for sheet: Control in [page.left_sheet(), page.right_sheet()]:
			var col := sheet.get_child(0) as Control
			assert_lte(col.get_combined_minimum_size().y, sheet.size.y, "%s sheet's rows fit it at %s" % [sheet.name, at])
			assert_lte(col.get_combined_minimum_size().x, sheet.size.x, "%s sheet's rows are no wider than it at %s" % [sheet.name, at])
		page.close()


func test_page_wears_the_journal_only() -> void:
	var source := FileAccess.get_file_as_string("res://ui/menu/settings_tab.gd")
	for banned in ["StyleBox", "add_theme_font", "add_theme_color", "Color(", ".theme ="]:
		assert_false(source.contains(banned), "no %s on the settings page" % banned)
