## Contract test for ScreenStack (docs/contracts/ui-frame.md): one owner for
## the pause, the mouse, Esc and gamepad focus while screens are open.
extends GutTest


class Screen extends CanvasLayer:
	var cancels: int = 0
	var button := Button.new()

	func _init() -> void:
		add_child(button)

	func screen_cancel() -> void:
		cancels += 1
		ScreenStack.pop(self)


## A screen with no hooks of its own: the stack's defaults apply.
class Plain extends CanvasLayer:
	var button := Button.new()

	func _init() -> void:
		add_child(button)


var book: Screen
var station: Screen
var requests: int = 0


func before_each() -> void:
	get_tree().paused = false
	book = Screen.new()
	station = Screen.new()
	add_child_autofree(book)
	add_child_autofree(station)
	requests = 0
	ScreenStack.pause_requested.connect(_on_pause_requested)


func after_each() -> void:
	ScreenStack.pause_requested.disconnect(_on_pause_requested)
	ScreenStack.pop(station)
	ScreenStack.pop(book)
	get_tree().paused = false


func _on_pause_requested() -> void:
	requests += 1


func _press(action: StringName) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	ScreenStack._unhandled_input(e)


func test_pause_holds_until_the_last_pausing_screen_closes() -> void:
	ScreenStack.push(book)
	ScreenStack.push(station)
	assert_true(get_tree().paused)
	ScreenStack.pop(station)
	assert_true(get_tree().paused, "the book is still open")
	ScreenStack.pop(book)
	assert_false(get_tree().paused)


func test_closing_the_lower_screen_first_keeps_the_pause() -> void:
	ScreenStack.push(book)
	ScreenStack.push(station)
	ScreenStack.pop(book)
	assert_true(get_tree().paused, "the station is still open")
	assert_same(ScreenStack.top(), station)
	ScreenStack.pop(station)
	assert_false(get_tree().paused)
	assert_true(ScreenStack.is_empty())


func test_a_screen_without_the_pause_flag_leaves_the_game_running() -> void:
	ScreenStack.push(book, ScreenStack.Flag.MOUSE)
	assert_false(get_tree().paused)
	assert_true(ScreenStack.mouse_shown())


func test_mouse_shows_while_a_screen_wants_it_and_is_caught_again_in_the_world() -> void:
	var player := Node.new()
	player.add_to_group(ScreenStack.PLAYER_GROUP)
	add_child_autofree(player)
	ScreenStack.push(book)
	ScreenStack.push(station)
	assert_true(ScreenStack.mouse_shown())
	ScreenStack.pop(station)
	assert_true(ScreenStack.mouse_shown(), "not caught while the book is open")
	ScreenStack.pop(book)
	assert_false(ScreenStack.mouse_shown(), "caught again with nothing open")


func test_mouse_stays_free_where_there_is_no_player() -> void:
	ScreenStack.push(book)
	ScreenStack.pop(book)
	assert_true(ScreenStack.mouse_shown(), "the title has no one to steer")


func test_escape_closes_only_the_top_screen() -> void:
	ScreenStack.push(book)
	ScreenStack.push(station)
	_press(&"ui_cancel")
	assert_eq(station.cancels, 1)
	assert_eq(book.cancels, 0, "one press closes one screen")
	assert_same(ScreenStack.top(), book)
	_press(&"pause")
	assert_eq(book.cancels, 1)
	assert_true(ScreenStack.is_empty())
	assert_eq(requests, 0, "a press that closed a screen opens nothing")


func test_escape_with_nothing_open_asks_for_the_pause_panel() -> void:
	_press(&"ui_cancel")
	assert_eq(requests, 0, "B alone does not pause")
	_press(&"pause")
	assert_eq(requests, 1)


func test_a_screen_with_no_cancel_of_its_own_is_popped_and_hidden() -> void:
	var plain := Plain.new()
	add_child_autofree(plain)
	ScreenStack.push(plain)
	_press(&"ui_cancel")
	assert_false(ScreenStack.has(plain))
	assert_false(plain.visible)


func test_focus_goes_to_the_new_screen_and_back_to_the_one_beneath() -> void:
	ScreenStack.push(book)
	assert_same(get_viewport().gui_get_focus_owner(), book.button, "first focusable control")
	ScreenStack.push(station)
	assert_same(get_viewport().gui_get_focus_owner(), station.button)
	ScreenStack.pop(station)
	assert_same(get_viewport().gui_get_focus_owner(), book.button, "back to the book")
	ScreenStack.pop(book)
	assert_null(get_viewport().gui_get_focus_owner(), "nothing keeps focus in the world")


func test_an_open_screen_runs_while_paused_and_gets_its_mode_back() -> void:
	book.process_mode = Node.PROCESS_MODE_PAUSABLE
	ScreenStack.push(book)
	assert_eq(book.process_mode, Node.PROCESS_MODE_ALWAYS)
	ScreenStack.pop(book)
	assert_eq(book.process_mode, Node.PROCESS_MODE_PAUSABLE)


func test_each_screen_sits_a_layer_above_the_one_beneath() -> void:
	ScreenStack.push(book)
	ScreenStack.push(station)
	assert_eq(book.layer, UiLayers.SCREEN)
	assert_eq(station.layer, UiLayers.SCREEN + 1)
	assert_eq(ScreenStack.layer_of(station), UiLayers.SCREEN + 1)
	ScreenStack.pop(book)
	assert_eq(station.layer, UiLayers.SCREEN, "it drops down when the one beneath closes")
	assert_lt(UiLayers.SCREEN + ScreenStack.MAX_DEPTH - 1, UiLayers.LINE, "screens never reach the line band")


func test_a_freed_screen_pops_itself() -> void:
	var gone := Screen.new()
	add_child(gone)
	ScreenStack.push(gone)
	assert_true(get_tree().paused)
	gone.free()
	assert_true(ScreenStack.is_empty())
	assert_false(get_tree().paused)


func test_pushing_twice_is_one_entry() -> void:
	ScreenStack.push(book)
	ScreenStack.push(book)
	ScreenStack.pop(book)
	assert_true(ScreenStack.is_empty())


func test_only_the_stack_touches_pause_mouse_and_escape_in_what_it_holds() -> void:
	# Hand-ins 1b to 1d widen this list until it is every script in the game.
	var moved := [
		"res://ui/menu/menu_shell.gd", "res://ui/menu/menu_tab.gd", "res://ui/menu/wardrobe_tab.gd",
		"res://ui/satchel/satchel_menu.gd", "res://ui/journal/story_journal.gd", "res://ui/map/full_map.gd",
		"res://ui/collection_book/collection_tab.gd", "res://ui/collection_book/collection_book_ui.gd",
		"res://ui/dressing_room/dressing_room_view.gd", "res://ui/settings_panel.gd",
		"res://ui/title/title_settings.gd",
	]
	var bad := RegEx.create_from_string("paused\\s*=[^=]|mouse_mode\\s*=[^=]|&\"pause\"|&\"ui_cancel\"|\\blayer\\s*=\\s*\\d")
	for path: String in moved:
		var hits: Array[String] = []
		for line in FileAccess.get_file_as_string(path).split("\n"):
			if not line.strip_edges().begins_with("#") and bad.search(line):
				hits.append(line.strip_edges())
		assert_eq(hits, [], "%s does a job the frame owns" % path)
