## One page of Feyre's journal (MenuShell): the satchel, the wardrobe, the
## collection, the sketchbook, the map, and settings on the ribbon. The
## shell draws the open book and its index tabs; a page writes on the book's two sheets, left_sheet() and
## right_sheet() (or spread() for one picture across both), and names its keys
## with set_hints(). A page is built once, kept, and only shown and hidden;
## the shell owns pausing, the mouse and the keys every page shares. A page
## adds only what is its own:
##   _page_input(event) -> bool  its keys (return true when it used one)
##   _shown() / _hidden()        refresh what may have changed / let go
##   warm_jobs() -> Array        slow first-time work, run a slice per frame
## and sets tab_id, tab_title, tab_order and shortcut in _init.
##
## open() / close() / is_open() stay the page's own API, so callers and tests
## that open one page keep working; they go through the shell.
class_name MenuTab
extends CanvasLayer

signal opened
signal closed

## The foot of the right sheet kept for the key hints.
const HINTS_HEIGHT := 44.0

## Stable id (MenuShell.open_tab(tree, id)).
var tab_id: StringName = &""
## The word on its tab.
var tab_title: String = ""
## Left to right on the strip.
var tab_order: int = 0
## The action that opens the shell on this page from play (and closes it
## again from the page). &"" for a page reached only from the strip.
var shortcut: StringName = &""
## Opens even while a story scene holds her controls (StoryControl not FULL).
var opens_in_story: bool = false
## Hangs from the book's ribbon, at its foot, not on the index strip.
var on_ribbon: bool = false
## Whether the game holds still when the book opens on this page (the title
## has no game to hold, and its sky keeps drifting).
var pauses: bool = true

var _shown_now: bool = false
var _book: Control
var _sheets: Dictionary = {}  # BookLayout rect -> Control
var _key_hints: HBoxContainer

static var _triggers: Dictionary = {}


func _enter_tree() -> void:
	layer = UiLayers.PAGE
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not _shown_now:
		visible = false
	MenuShell.of(get_tree()).register(self)


func _exit_tree() -> void:
	MenuShell.of(get_tree()).unregister(self)


func is_open() -> bool:
	return _shown_now


## Opens the shell on this page (or flips to it if the shell is open).
func open() -> void:
	MenuShell.of(get_tree()).show_tab(self)


func close() -> void:
	if _shown_now:
		MenuShell.of(get_tree()).close()


## Whether its tab is on the strip right now.
func available() -> bool:
	return true


# --- the book's sheets --------------------------------------------------------

## The left-hand sheet's writing area.
func left_sheet() -> Control:
	return _sheet(BookLayout.LEFT, "Left")


## The right-hand sheet's writing area. Its foot holds the key hints.
func right_sheet() -> Control:
	return _sheet(BookLayout.RIGHT, "Right")


## Both sheets as one area, for a page that is a single picture.
func spread() -> Control:
	return _sheet(BookLayout.SPREAD, "Spread")


## A column down a sheet, ready to add rows to.
func column(sheet: Control, separation: int = 10) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override(&"separation", separation)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet.add_child(col)
	return col


## The keys this page answers, as caps at the foot of the right sheet:
## [["Z X", "Pocket"], ["Esc", "Back"]].
func set_hints(pairs: Array) -> void:
	if _key_hints == null:
		_key_hints = HBoxContainer.new()
		_key_hints.name = "Hints"
		_key_hints.alignment = BoxContainer.ALIGNMENT_END
		_key_hints.add_theme_constant_override(&"separation", 22)
		_key_hints.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_book_root().add_child(_key_hints)
		var foot := BookLayout.RIGHT
		_key_hints.position = Vector2(foot.position.x, foot.end.y - HINTS_HEIGHT)
		_key_hints.size = Vector2(foot.size.x, HINTS_HEIGHT)
	for c in _key_hints.get_children():
		_key_hints.remove_child(c)
		c.queue_free()
	for p: Array in pairs:
		_key_hints.add_child(BookKit.key_hint(p[0], p[1]))


func _sheet(rect: Rect2, sheet_name: String) -> Control:
	if not _sheets.has(rect):
		var c := Control.new()
		c.name = sheet_name
		c.position = rect.position
		c.size = rect.size - Vector2(0, HINTS_HEIGHT + 8.0 if rect == BookLayout.RIGHT else 0.0)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_book_root().add_child(c)
		_sheets[rect] = c
	return _sheets[rect]


## A Control the size and place of the book, that every sheet hangs from.
func _book_root() -> Control:
	if _book == null:
		_book = Control.new()
		_book.name = "Book"
		_book.size = BookLayout.SIZE
		_book.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_book)
		_place_book()
		get_viewport().size_changed.connect(_place_book)
	return _book


func _place_book() -> void:
	var view := get_viewport().get_visible_rect().size
	_book.scale = Vector2.ONE * BookLayout.fit(view)
	_book.position = BookLayout.origin(view)


## Something new on the page she hasn't looked at yet (a mark on its tab).
func has_news() -> bool:
	return false


# --- called by the shell only -------------------------------------------------

func shell_show() -> void:
	if _shown_now:
		return
	_shown_now = true
	visible = true
	_shown()
	opened.emit()


func shell_hide() -> void:
	if not _shown_now:
		return
	_shown_now = false
	visible = false
	_hidden()
	closed.emit()


func shell_input(event: InputEvent) -> bool:
	return _page_input(event)


# --- for pages to override ------------------------------------------------------

func _shown() -> void:
	pass


func _hidden() -> void:
	pass


func _page_input(_event: InputEvent) -> bool:
	return false


## The shell is about to draw the page nearly clear for a frame or two (and
## when `on` is false, has finished): show anything that is normally hidden
## until needed, so its first real draw costs nothing.
func warm_render(_on: bool) -> void:
	pass


## Callables the shell runs one per frame while it is closed, so the first
## open has nothing slow left to do. Asked again whenever the page calls
## MenuShell.of(tree).queue_warm(self).
func warm_jobs() -> Array[Callable]:
	return []


# --- small helpers pages share ----------------------------------------------

static func pad_pressed(event: InputEvent, button: JoyButton) -> bool:
	return event is InputEventJoypadButton and event.pressed \
			and (event as InputEventJoypadButton).button_index == button


## A pad trigger pulled past halfway, once per pull (pages use LT / RT).
static func trigger_pulled(event: InputEvent, axis: JoyAxis) -> bool:
	if not event is InputEventJoypadMotion or (event as InputEventJoypadMotion).axis != axis:
		return false
	var down := (event as InputEventJoypadMotion).axis_value > 0.6
	var key := "trigger_%d" % axis
	var was: bool = _triggers.get(key, false)
	_triggers[key] = down
	return down and not was


static func key_pressed(event: InputEvent, keys: Array) -> bool:
	return event is InputEventKey and event.pressed and not event.echo \
			and (event as InputEventKey).physical_keycode in keys
