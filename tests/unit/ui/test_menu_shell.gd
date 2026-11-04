## Contract test for the menu shell (docs/contracts/menu_shell.md): one shell
## owns pausing and the keys every page shares; each page keeps its own key.
extends GutTest

const PAGE_FILES := [
	"res://ui/satchel/satchel_menu.gd", "res://ui/journal/story_journal.gd",
	"res://ui/map/full_map.gd", "res://ui/collection_book/collection_tab.gd",
	"res://ui/collection_book/collection_book_ui.gd", "res://ui/menu/wardrobe_tab.gd",
	"res://ui/menu/menu_shell.gd", "res://ui/menu/menu_tab.gd",
]
## One look: page chrome comes from SatchelTheme only. (The wardrobe's gilt
## mirror and colour swatches in DressingRoomView are its own, by L64-3.)
const OFF_THEME := "StyleBoxFlat|add_theme_font_override|DISPLAY_FONT|body_font|SystemFont|FontFile|\\.ttf|PauseStyle\\.(title|note|theme|card_box)|UiStyle\\."


class Page extends MenuTab:
	var keys_seen: int = 0

	func _init(id: StringName, order: int, action: StringName) -> void:
		tab_id = id
		tab_title = String(id).capitalize()
		tab_order = order
		shortcut = action

	func _page_input(event: InputEvent) -> bool:
		if key_pressed(event, [KEY_K]):
			keys_seen += 1
			return true
		return false


var shell: MenuShell
var a: Page
var b: Page
var c: Page


func before_all() -> void:
	for spec in [[&"test_page_a", KEY_F6], [&"test_page_b", KEY_F7], [&"test_page_c", KEY_F8]]:
		if not InputMap.has_action(spec[0]):
			InputMap.add_action(spec[0])
			var k := InputEventKey.new()
			k.physical_keycode = spec[1]
			InputMap.action_add_event(spec[0], k)


func before_each() -> void:
	get_tree().paused = false
	StoryControl.release()
	shell = MenuShell.of(get_tree())
	# Out of order on purpose: the strip sorts by tab_order.
	c = Page.new(&"c", 92, &"test_page_c")
	a = Page.new(&"a", 90, &"test_page_a")
	b = Page.new(&"b", 91, &"test_page_b")
	for p in [c, a, b]:
		add_child_autofree(p)
	await wait_process_frames(1)


func after_each() -> void:
	shell.close()
	get_tree().paused = false


func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.pressed = true
	return e


func _action(name: StringName) -> InputEventAction:
	var e := InputEventAction.new()
	e.action = name
	e.pressed = true
	return e


func test_one_shell_for_the_tree_and_pages_register_in_order() -> void:
	assert_same(MenuShell.of(get_tree()), shell)
	assert_eq(get_tree().get_nodes_in_group(MenuShell.GROUP).size(), 1, "exactly one shell")
	var ours := shell.tabs.filter(func(t: MenuTab) -> bool: return t in [a, b, c])
	assert_eq(ours, [a, b, c], "sorted by tab_order")


func test_shortcut_opens_jumps_and_closes() -> void:
	shell._input(_key(KEY_F7))
	assert_true(b.is_open(), "its own key opens the shell on that page")
	assert_true(get_tree().paused, "the shell pauses")
	assert_eq(Input.mouse_mode, Input.MOUSE_MODE_VISIBLE)
	shell._input(_key(KEY_F6))
	assert_true(a.is_open() and not b.is_open(), "another page's key jumps there")
	assert_true(get_tree().paused, "still paused between pages")
	assert_true(a.visible and not b.visible and not c.visible, "one page drawn at a time")
	shell._input(_key(KEY_F6))
	assert_false(shell.is_open(), "the same key again closes")
	assert_false(get_tree().paused)


func test_page_keys_step_and_wrap_and_escape_closes() -> void:
	a.open()
	var shown := shell.tabs.filter(func(t: MenuTab) -> bool: return t.available())
	var i := shown.find(a)
	shell._input(_key(KEY_E))
	assert_same(shell.current, shown[(i + 1) % shown.size()], "E is the next page")
	shell._input(_key(KEY_Q))
	shell._input(_key(KEY_Q))
	assert_same(shell.current, shown[posmod(i - 1, shown.size())], "Q steps back and wraps")
	shell._input(_action(&"ui_cancel"))
	assert_false(shell.is_open())
	assert_false(get_tree().paused)


func test_a_page_keeps_its_own_keys_first() -> void:
	c.open()
	shell._input(_key(KEY_K))
	assert_eq(c.keys_seen, 1)
	assert_true(c.is_open())


func test_closed_shortcuts_wait_for_play() -> void:
	get_tree().paused = true
	shell._input(_key(KEY_F6))
	assert_false(shell.is_open(), "another screen pausing the game keeps the keys")
	get_tree().paused = false
	StoryControl.set_mode(StoryControl.Mode.LOOK)
	shell._input(_key(KEY_F6))
	assert_false(shell.is_open(), "a story scene holds them too")
	a.opens_in_story = true
	shell._input(_key(KEY_F6))
	assert_true(a.is_open(), "unless the page opens in story (sketchbook, collection)")
	StoryControl.release()


func test_strip_button_per_page_and_news_dot() -> void:
	a.open()
	var strip := shell.get_node(^"ShellRoot/TabStrip/Tabs") as HBoxContainer
	assert_not_null(strip)
	for p in [a, b, c]:
		assert_not_null(strip.get_node_or_null("Tab_%s" % p.tab_id), String(p.tab_id))
	var tab_b := strip.get_node("Tab_b") as Button
	assert_string_contains(tab_b.text, "F7", "the tab shows its key")
	assert_true((strip.get_node("Tab_a") as Button).button_pressed)


func test_pages_wear_one_look() -> void:
	var bad := RegEx.create_from_string(OFF_THEME)
	for path: String in PAGE_FILES:
		var hits := []
		for line in FileAccess.get_file_as_string(path).split("\n"):
			if not line.strip_edges().begins_with("#") and bad.search(line):
				hits.append(line.strip_edges())
		assert_eq(hits, [], "%s styles itself outside SatchelTheme" % path)


func test_only_the_shell_pauses() -> void:
	for path: String in PAGE_FILES:
		if path.begins_with("res://ui/menu/menu_"):
			continue
		var src := FileAccess.get_file_as_string(path)
		assert_false(src.contains("paused ="), "%s sets pause itself" % path)
		assert_false(src.contains("mouse_mode ="), "%s sets the mouse itself" % path)


func test_real_pages_open_through_the_shell() -> void:
	var menu := SatchelMenu.new(QuickBar.new(Inventory.new()))
	add_child_autofree(menu)
	var journal := StoryJournal.new()
	add_child_autofree(journal)
	await wait_process_frames(1)
	menu.open()
	assert_same(shell.current, menu)
	assert_true(get_tree().paused)
	journal.open()
	assert_false(menu.is_open())
	assert_true(journal.is_open())
	journal.close()
	assert_false(get_tree().paused)
	var flaps := menu.get(&"_flaps") as HBoxContainer
	for f in flaps.get_children():
		assert_false((f as Button).text in ["Map", "Sketchbook", "Wardrobe"], "those are shell tabs now")
