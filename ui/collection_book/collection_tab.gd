## The collection book as a page of the menu shell (MenuShell): built once,
## its grid redrawn only when another of the book's tabs is shown or its
## entries changed. J (pad Back) opens it; Z / X (pad LT / RT) flip the book's
## own tabs, as the satchel's pockets. The look is the book's own (UiStyle).
class_name CollectionTab
extends MenuTab

const UI := preload("res://ui/collection_book/collection_book_ui.gd")
const WIDTH := 980.0

var book: CollectionBook
var page: StringName = &""

var _card: Control
var _buttons: Dictionary = {}  # tab -> Button
var _bar: ProgressBar
var _count: Label
var _reward: Label
var _grid: GridContainer
var _detail: Label
## The book tab whose tiles are in the grid, and whether they need drawing again.
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
	book = Gameplay.collection
	_build()
	book.discovered.connect(func(_id: StringName, _tab: StringName) -> void:
		_stale = true
		MenuShell.of(get_tree()).queue_warm(self))


func available() -> bool:
	return is_inside_tree() and get_tree().get_first_node_in_group(&"player") != null


func has_news() -> bool:
	return book != null and book.new_count() > 0


func _shown() -> void:
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
		if book and not is_open():
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
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(&"panel", UiStyle.panel_box())
	panel.custom_minimum_size = Vector2(WIDTH, 0)
	center.add_child(panel)
	_card = panel
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 10)
	panel.add_child(box)
	box.add_child(UiStyle.label("My collection", 28))
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override(&"separation", 6)
	box.add_child(tabs)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(0, 18)
	_bar.show_percentage = false
	_bar.add_theme_stylebox_override(&"fill", UI._rounded(UiStyle.ACCENT))
	_bar.add_theme_stylebox_override(&"background", UI._rounded(Color(1, 1, 1, 0.8)))
	box.add_child(_bar)
	var count_row := HBoxContainer.new()
	box.add_child(count_row)
	_count = UiStyle.label("", 16)
	_count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_count.autowrap_mode = TextServer.AUTOWRAP_OFF
	count_row.add_child(_count)
	_reward = UiStyle.label("", 16)
	_reward.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_reward.autowrap_mode = TextServer.AUTOWRAP_OFF
	_reward.add_theme_color_override(&"font_color", Color(0.72, 0.52, 0.18))
	count_row.add_child(_reward)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 470)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 7
	_grid.add_theme_constant_override(&"h_separation", 10)
	_grid.add_theme_constant_override(&"v_separation", 10)
	scroll.add_child(_grid)
	_detail = UiStyle.label("", 16)
	box.add_child(_detail)
	for tab in CollectionBook.TABS:
		var b := UiStyle.button("", true)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(show_page.bind(tab))
		tabs.add_child(b)
		_buttons[tab] = b
	UI._refresh_labels(_buttons, book)
