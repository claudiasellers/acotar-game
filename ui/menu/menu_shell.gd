## The one menu: every page Feyre keeps (satchel, wardrobe, collection book,
## sketchbook, map) is a tab of this shell. Each page's own key opens the shell
## on that page; from inside, any page's key jumps to it and the same key
## again closes. Contract: docs/contracts/menu_shell.md.
##
## Keys, the same on every page:
##   I / Tab, J, L, M (pad: LB tap, Back, RB)  open on that page / jump / close
##   Q / E (pad LB / RB)                        previous / next page
##   Esc (pad B)                                close
## Pages keep their own keys inside (MenuTab._page_input runs before these).
##
## The shell owns what every page used to do for itself: pausing the game,
## showing the mouse, hiding the controls hint, the tab strip. Pages are built
## once and only shown and hidden, and their slow first-time work (icons,
## models, shader first draws) runs a slice per frame while the shell is
## closed, so opening any page costs no frame hitch.
##
## Look: the strip is a SatchelDetail panel of SatchelTab buttons
## (SatchelTheme, which carries L65's borders); no colours or fonts here.
class_name MenuShell
extends CanvasLayer

signal tab_changed(tab_id: StringName)
signal shell_opened
signal shell_closed

const GROUP := &"menu_shell"
## Above every page (map 18, satchel and sketchbook 19, wardrobe 20).
const LAYER := 24
## Previous / next page, as in Dreamlight Valley (ui-direction/dreamlight-reference.md).
const STEP_KEYS: Array[Array] = [[KEY_Q], [KEY_E]]
const STEP_PAD: Array[JoyButton] = [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER]
## Milliseconds of warm work per frame while closed.
const WARM_BUDGET_MS := 4.0
## Alpha a page is drawn at for its warm-up frames (above the renderer's cull).
const WARM_ALPHA := 0.01
const WARM_FRAMES := 2
## Space the strip leaves at the top of the screen for the pages.
const STRIP_TOP := 14.0

var tabs: Array[MenuTab] = []
var current: MenuTab = null

var _tree: SceneTree
var _root: Control
var _strip: PanelContainer
var _row: HBoxContainer
var _buttons: Dictionary = {}  # MenuTab -> Button
var _prev_glyph: Label
var _next_glyph: Label
var _jobs: Array[Callable] = []
var _render_queue: Array[MenuTab] = []
var _rendering: MenuTab = null
var _render_frames: int = 0

static var _shell: MenuShell = null


## The shell for this tree, made the first time it is asked for.
static func of(tree: SceneTree) -> MenuShell:
	if _shell and is_instance_valid(_shell) and _shell._tree == tree:
		return _shell
	_shell = MenuShell.new()
	_shell._tree = tree
	# The root may be mid-way through adding the main scene.
	tree.root.add_child.call_deferred(_shell)
	return _shell


## Opens the shell on page `id`, wherever it is called from. False when the
## scene has no such page.
static func open_tab(tree: SceneTree, id: StringName) -> bool:
	var shell := of(tree)
	var tab := shell.find(id)
	if tab == null:
		return false
	shell.show_tab(tab)
	return true


static func close_all(tree: SceneTree) -> void:
	of(tree).close()


static func is_shell_open(tree: SceneTree) -> bool:
	return of(tree).is_open()


func _init() -> void:
	name = "MenuShell"
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	add_to_group(GROUP)
	_build()
	_root.visible = current != null
	_sync_strip()


func is_open() -> bool:
	return current != null


func find(id: StringName) -> MenuTab:
	for t in tabs:
		if t.tab_id == id:
			return t
	return null


func register(tab: MenuTab) -> void:
	if tab in tabs:
		return
	tabs.append(tab)
	tabs.sort_custom(func(a: MenuTab, b: MenuTab) -> bool: return a.tab_order < b.tab_order)
	_render_queue.append(tab)
	queue_warm(tab)
	_sync_strip()


func unregister(tab: MenuTab) -> void:
	if tab == current:
		close()
	if tab == _rendering:
		_end_render()
	tabs.erase(tab)
	_render_queue.erase(tab)
	var b: Node = _buttons.get(tab)
	if is_instance_valid(b):
		# Out of the row now, so a page re-made with the same id gets its name.
		b.get_parent().remove_child(b)
		b.queue_free()
	_buttons.erase(tab)
	_sync_strip()


## Asks the page for its slow first-time work again (say, a new thing in
## her satchel needs its picture made).
func queue_warm(tab: MenuTab) -> void:
	_jobs.append_array(tab.warm_jobs())


## Draws the page once more, nearly clear, after its warm jobs made new
## things to draw.
func queue_render(tab: MenuTab) -> void:
	if not tab in _render_queue:
		_render_queue.append(tab)


## Opens the shell on `tab`, or flips to it if the shell is already open.
func show_tab(tab: MenuTab) -> void:
	if tab == current or not tab in tabs:
		return
	_end_render()
	var was_open := is_open()
	if current:
		current.shell_hide()
	if not was_open:
		_open_shell()
	current = tab
	tab.shell_show()
	_sync_strip()
	if _buttons.has(tab) and was_open:
		Juice.bounce_control(_buttons[tab] as Control, 0.12)
	tab_changed.emit(tab.tab_id)
	if not was_open:
		shell_opened.emit()


func close() -> void:
	if current == null:
		return
	var tab := current
	current = null
	tab.shell_hide()
	if _root:
		_root.visible = false
	_tree.paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	shell_closed.emit()


## Next (+1) or previous (-1) page on the strip, wrapping round.
func step(direction: int) -> void:
	var shown := _available()
	if current == null or shown.is_empty():
		return
	var i := shown.find(current)
	show_tab(shown[posmod(i + direction, shown.size())])


func _open_shell() -> void:
	_tree.paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for n in _tree.root.find_children("*", "ControlsHint", true, false):
		(n as ControlsHint).hide_now()
	if _root:
		_root.theme = SatchelTheme.theme()
		_root.visible = true


func _available() -> Array[MenuTab]:
	return tabs.filter(func(t: MenuTab) -> bool: return t.available())


# --- input -----------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if current == null:
		_input_closed(event)
		return
	if event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel"):
		close()
	elif not current.shell_input(event):
		# The page keys come before the shortcuts: RB is both "next" and the map's key.
		var direction := _step_of(event)
		var tab := _shortcut_tab(event) if direction == 0 else null
		if direction != 0:
			step(direction)
		elif tab == current:
			close()
		elif tab:
			show_tab(tab)
		else:
			return
	get_viewport().set_input_as_handled()


func _input_closed(event: InputEvent) -> void:
	if _tree.paused:
		return
	var tab := _shortcut_tab(event)
	if tab and (tab.opens_in_story or StoryControl.mode == StoryControl.Mode.FULL):
		show_tab(tab)
		get_viewport().set_input_as_handled()


func _shortcut_tab(event: InputEvent) -> MenuTab:
	if event.is_echo():
		return null
	for t in _available():
		if t.shortcut != &"" and InputMap.has_action(t.shortcut) and event.is_action_pressed(t.shortcut):
			return t
	return null


## -1 / +1 for the page keys and bumpers, else 0.
func _step_of(event: InputEvent) -> int:
	for i in 2:
		if MenuTab.key_pressed(event, STEP_KEYS[i]) or MenuTab.pad_pressed(event, STEP_PAD[i]):
			return -1 if i == 0 else 1
	return 0


# --- warm-up -----------------------------------------------------------------

## While closed: draw each page once, nearly clear, so its shaders and
## textures are ready; then run queued warm jobs within the frame budget.
func _process(_delta: float) -> void:
	if current != null:
		return
	if _rendering:
		_render_frames -= 1
		if _render_frames <= 0:
			_end_render()
		return
	if _jobs.is_empty():
		if not _render_queue.is_empty() and is_inside_tree():
			_begin_render(_render_queue.pop_front())
		return
	var start := Time.get_ticks_usec()
	while not _jobs.is_empty() and (Time.get_ticks_usec() - start) / 1000.0 < WARM_BUDGET_MS:
		var job: Callable = _jobs.pop_front()
		if job.is_valid():
			job.call()


func _begin_render(tab: MenuTab) -> void:
	if not is_instance_valid(tab) or not tab.is_inside_tree():
		return
	_rendering = tab
	_render_frames = WARM_FRAMES
	tab.warm_render(true)
	for c in tab.get_children():
		if c is CanvasItem:
			(c as CanvasItem).modulate.a = WARM_ALPHA
	tab.visible = true


func _end_render() -> void:
	if _rendering == null:
		return
	var tab := _rendering
	_rendering = null
	if not is_instance_valid(tab):
		return
	for c in tab.get_children():
		if c is CanvasItem:
			(c as CanvasItem).modulate.a = 1.0
	tab.visible = tab.is_open()
	tab.warm_render(false)


# --- the strip -----------------------------------------------------------------

func _build() -> void:
	_root = Control.new()
	_root.name = "ShellRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = SatchelTheme.theme()
	add_child(_root)
	_strip = PanelContainer.new()
	_strip.name = "TabStrip"
	_strip.theme_type_variation = &"SatchelDetail"
	_strip.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_strip.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_strip.offset_top = STRIP_TOP
	_root.add_child(_strip)
	_row = HBoxContainer.new()
	_row.name = "Tabs"
	_row.add_theme_constant_override(&"separation", 8)
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_strip.add_child(_row)
	_prev_glyph = _glyph("Q")
	_row.add_child(_prev_glyph.get_parent())
	_next_glyph = _glyph("E")


func _glyph(text: String) -> Label:
	var box := PanelContainer.new()
	box.theme_type_variation = &"SatchelKey"
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var l := Label.new()
	l.text = text
	l.theme_type_variation = &"SatchelKeyLabel"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(l)
	return l


func _sync_strip() -> void:
	if _row == null:
		return
	var pad := SatchelHud.pad_active
	_prev_glyph.text = "LB" if pad else "Q"
	_next_glyph.text = "RB" if pad else "E"
	var shown := _available()
	for t in tabs:
		if not _buttons.has(t):
			var b := Button.new()
			b.name = "Tab_%s" % t.tab_id
			b.theme_type_variation = &"SatchelTab"
			b.toggle_mode = true
			b.focus_mode = Control.FOCUS_NONE
			b.pressed.connect(show_tab.bind(t))
			b.add_child(NewsDot.new())
			_row.add_child(b)
			_buttons[t] = b
	# Strip order: Z glyph, the tabs by tab_order, X glyph.
	var at := 1
	for t in tabs:
		var b := _buttons[t] as Button
		_row.move_child(b, at)
		at += 1
		b.visible = t in shown
		b.text = t.tab_title + ("   " + _key_word(t.shortcut) if t.shortcut != &"" else "")
		b.set_pressed_no_signal(t == current)
		(b.get_node(^"News") as Control).visible = t.has_news() and t != current
	var next_box := _next_glyph.get_parent()
	if next_box.get_parent() == null:
		_row.add_child(next_box)
	_row.move_child(next_box, -1)
	_prev_glyph.get_parent().visible = shown.size() > 1
	next_box.visible = shown.size() > 1


## The first key bound to an action, as its label ("I", "M").
func _key_word(action: StringName) -> String:
	if not InputMap.has_action(action):
		return ""
	for e in InputMap.action_get_events(action):
		if e is InputEventKey:
			var k := e as InputEventKey
			var code := k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
			return OS.get_keycode_string(code)
	return ""
