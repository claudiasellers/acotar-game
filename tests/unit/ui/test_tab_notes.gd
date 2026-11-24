# gate: when:ui/menu/*,ui/theme/*,core/world_state.gd
## The first time a page of the journal is opened, a slip in Feyre's hand says
## what the page is to her. Once per story, and never what to do next (R2).
extends GutTest


class Page extends MenuTab:
	func _init(id: StringName, order: int) -> void:
		tab_id = id
		tab_title = String(id).capitalize()
		tab_order = order


var shell: MenuShell
var satchel: Page
var map: Page
var other: Page


func before_each() -> void:
	for id: StringName in TabNote.LINES:
		WorldState.set_flag(TabNote.FLAG % id, false)
	MenuShell.close_all(get_tree())
	shell = MenuShell.of(get_tree())
	satchel = Page.new(&"satchel", 0)
	map = Page.new(&"map", 1)
	other = Page.new(&"test_no_note", 2)
	for p: Page in [satchel, map, other]:
		add_child_autofree(p)
	await wait_process_frames(2)


func after_each() -> void:
	MenuShell.close_all(get_tree())
	for id: StringName in TabNote.LINES:
		WorldState.set_flag(TabNote.FLAG % id, false)


func test_a_page_says_its_line_the_first_time_only() -> void:
	satchel.open()
	assert_true(shell.note.visible)
	assert_eq(shell.note.text(), TabNote.LINES[&"satchel"])
	assert_true(WorldState.has_flag(TabNote.FLAG % &"satchel"), "read, and saved with the story")
	map.open()
	assert_eq(shell.note.text(), TabNote.LINES[&"map"], "each page has its own")
	satchel.open()
	assert_false(shell.note.visible, "a page she has read says nothing")
	other.open()
	assert_false(shell.note.visible, "a page with no line says nothing")
	shell.close()
	map.open()
	assert_false(shell.note.visible, "nor again on a later opening")


func test_the_slip_is_her_hand_on_paper_above_the_book() -> void:
	satchel.open()
	await wait_process_frames(2)
	var note := shell.note
	assert_eq(note.theme_type_variation, &"NotifyCard")
	assert_eq((note.get_child(0) as Label).theme_type_variation, &"ThoughtText")
	assert_lt(note.position.y + note.size.y, 0.0, "clear of the book's top edge")
	assert_almost_eq(note.position.x + note.size.x, BookLayout.SIZE.x - BookLayout.TABS_AT.x * 2.0, 0.5, "by the book's right end")
	var tabs := shell.find_child("Tabs", true, false) as Control
	assert_gt(note.position.x, tabs.position.x + tabs.size.x, "past the last index tab")


func test_every_page_has_a_short_line_that_asks_nothing() -> void:
	assert_eq(TabNote.LINES.keys(), [&"satchel", &"wardrobe", &"collection", &"sketchbook", &"map"])
	var asks := RegEx.create_from_string("(?i)\\bpress\\b|\\bopen\\b|\\bfind\\b|\\bgo\\b|\\bcollect\\b|\\d")
	for id: StringName in TabNote.LINES:
		var line: String = TabNote.LINES[id]
		assert_lt(line.length(), 60, "%s is short" % id)
		assert_null(asks.search(line), "%s only says what the page is" % id)
