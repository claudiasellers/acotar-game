## The collection book as a page of the menu shell (MenuShell): built once,
## its grid redrawn only when another of the book's tabs is shown or its
## entries changed. J (pad Back) opens it; Z / X (pad LT / RT) flip the book's
## own tabs, as the satchel's pockets. The look is the satchel's (SatchelTheme:
## framed paper, stitched tabs and slots, the serif); no colours or fonts here.
class_name CollectionTab
extends MenuTab

const UI := preload("res://ui/collection_book/collection_book_ui.gd")
const WIDTH := 1260.0
const GRID_HEIGHT := 520.0
## Clear space under the card.
const BOTTOM := 40.0

## Always the live book (Gameplay.reset makes a new one).
var book: CollectionBook:
	get:
		return Gameplay.collection
var page: StringName = &""

var _root: Control
var _card: Control
var _buttons: Dictionary = {}  # tab -> Button
var _bar: ProgressBar
var _count: Label
var _reward: Label
var _grid: GridContainer
var _detail: Label
## The book tab whose tiles are in the grid, and whether they need drawing again.
var _watched: CollectionBook = null
var _drawn_tab: StringName = &""
var _stale: bool = true


## The scene's collection page, made (as a child of the shell) if it has none.
static func ensure(tree: SceneTree) -> CollectionTab:
	var shell := MenuShell.of(tree)
	var tab := shell.find(&"collection") as CollectionTab
	if tab == null:
		tab = CollectionTab.new()
		shell.add_child(tab)
		shell.register(tab)
	return tab


func _init() -> void:
	name = "CollectionBook"
	tab_id = &"collection"
	tab_title = "Collection"
	tab_order = 2
	shortcut = &"open_collection"
	opens_in_story = true
	layer = 20


func _ready() -> void:
	_build()
	_watch()


## Redraws (in the background) when the book finds something new.
func _watch() -> void:
	if _watched == book:
		return
	_watched = book
	_stale = true
	book.discovered.connect(func(_id: StringName, _tab: StringName) -> void:
		_stale = true
		if is_inside_tree():
			MenuShell.of(get_tree()).queue_warm(self))


func available() -> bool:
	return is_inside_tree() and get_tree().get_first_node_in_group(&"player") != null


func has_news() -> bool:
	return book != null and book.new_count() > 0


func _shown() -> void:
	_root.theme = SatchelTheme.theme()
	_watch()
	FindCard.clear(get_tree())
	show_page(_first_page())
	Juice.bounce_control(_card, 0.03)


func _hidden() -> void:
	MenuShell.of(get_tree()).queue_warm(self)


## The tab it opens on: the first with something new, else the first.
func _first_page() -> StringName:
	for tab in CollectionBook.TABS:
		if book.new_count(tab) > 0:
			return tab
	return CollectionBook.TABS[0]


## While the shell is closed: lay out the tiles of the page it will open on.
func warm_jobs() -> Array[Callable]:
	return [func() -> void:
		if not is_open():
			_watch()
			_draw_tiles(_first_page())]


func _draw_tiles(tab: StringName) -> void:
	if tab == _drawn_tab and not _stale:
		return
	for c in _grid.get_children():
		c.queue_free()
	for e in book.entries(tab):
		_grid.add_child(UI._tile(e, _detail))
	_drawn_tab = tab
	_stale = false


## Shows one of the book's own tabs (Forage, Recipes, ...).
func show_page(tab: StringName) -> void:
	page = tab
	for t: StringName in _buttons:
		(_buttons[t] as Button).set_pressed_no_signal(t == tab)
	var p := book.progress(tab)
	_bar.visible = p.y > 0
	if p.y > 0:
		_bar.max_value = p.y
		_bar.value = p.x
		_count.text = "%d of %d found" % [p.x, p.y]
	else:
		_count.text = "%d so far" % p.x if p.x > 0 else "Nothing yet. Keep your eyes open."
	_reward.text = UI._reward_text(book, tab)
	_draw_tiles(tab)
	# New badges show once: drawn with them now, without them next time.
	if book.new_count(tab) > 0:
		_stale = true
	book.seen(tab)
	UI._refresh_labels(_buttons, book)


func _page_input(event: InputEvent) -> bool:
	var step := 0
	if key_pressed(event, [KEY_Z]) or trigger_pulled(event, JOY_AXIS_TRIGGER_LEFT):
		step = -1
	elif key_pressed(event, [KEY_X]) or trigger_pulled(event, JOY_AXIS_TRIGGER_RIGHT):
		step = 1
	else:
		return false
	var n := CollectionBook.TABS.size()
	show_page(CollectionBook.TABS[posmod(CollectionBook.TABS.find(page) + step, n)])
	return true


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = SatchelTheme.theme()
	add_child(_root)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.offset_top = page_top()
	center.offset_bottom = -BOTTOM
	_root.add_child(center)
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"SatchelDetail"
	panel.custom_minimum_size = Vector2(WIDTH, 0)
	center.add_child(panel)
	_card = panel
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 10)
	panel.add_child(box)
	box.add_child(_label("My collection", &"SatchelHeading"))
	var tabs := HFlowContainer.new()
	tabs.add_theme_constant_override(&"h_separation", 8)
	tabs.add_theme_constant_override(&"v_separation", 6)
	box.add_child(tabs)
	_bar = ProgressBar.new()
	_bar.theme_type_variation = &"SatchelMeter"
	_bar.custom_minimum_size = Vector2(0, 16)
	_bar.show_percentage = false
	box.add_child(_bar)
	var count_row := HBoxContainer.new()
	box.add_child(count_row)
	_count = _label("", &"SatchelSmall")
	_count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	count_row.add_child(_count)
	_reward = _label("", &"SatchelWhere")
	_reward.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_row.add_child(_reward)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, GRID_HEIGHT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 8
	_grid.add_theme_constant_override(&"h_separation", 10)
	_grid.add_theme_constant_override(&"v_separation", 10)
	scroll.add_child(_grid)
	_detail = _label("", &"SatchelBody")
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_detail)
	for tab in CollectionBook.TABS:
		var b := Button.new()
		b.theme_type_variation = &"SatchelTab"
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(show_page.bind(tab))
		tabs.add_child(b)
		_buttons[tab] = b
	UI._refresh_labels(_buttons, book)


func _label(text: String, variation: StringName) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = variation
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
