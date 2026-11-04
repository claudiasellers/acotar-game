## One page of the menu shell (MenuShell): the satchel, the wardrobe, the
## collection book, the sketchbook, the map. A page is built once, kept, and
## only shown and hidden; the shell owns pausing, the mouse, the tab strip and
## the keys every page shares. A page adds only what is its own:
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

var _shown_now: bool = false

static var _triggers: Dictionary = {}


func _enter_tree() -> void:
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
