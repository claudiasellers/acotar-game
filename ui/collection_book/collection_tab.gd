## The collection page of Feyre's journal: built once, its grid redrawn only
## when another of its own tabs is shown or its entries changed. J (pad Back)
## opens it; Z / X (pad LT / RT) flip its tabs, as the satchel's pockets. The
## left sheet says what she is collecting and how far along she is; the right
## sheet is the things themselves. Look: JournalTheme variations only.
class_name CollectionTab
extends MenuTab

const UI := preload("res://ui/collection_book/collection_book_ui.gd")
const COLUMNS := 5

## Always the live book (Gameplay.reset makes a new one).
var book: CollectionBook:
	get:
		return Gameplay.collection
var page: StringName = &""

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
	_watch()
	FindCard.clear(get_tree())
	show_page(_first_page())


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
	var left := column(left_sheet())
	left.add_child(BookKit.title("Collection"))
	var tabs := HFlowContainer.new()
	tabs.add_theme_constant_override(&"h_separation", 6)
	tabs.add_theme_constant_override(&"v_separation", 6)
	left.add_child(tabs)
	left.add_child(BookKit.gap(8))
	_bar = ProgressBar.new()
	_bar.theme_type_variation = &"SatchelMeter"
	_bar.custom_minimum_size = Vector2(0, 16)
	_bar.show_percentage = false
	left.add_child(_bar)
	_count = BookKit.label("", &"SatchelSmall")
	left.add_child(_count)
	_reward = BookKit.label("", &"SatchelWhere", true)
	left.add_child(_reward)
	left.add_child(BookKit.spring())
	_detail = BookKit.label("", &"SatchelBody", true)
	_detail.custom_minimum_size = Vector2(0, 120)
	left.add_child(_detail)
	var sky := BookKit.sky(420.0)
	sky.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	left.add_child(sky)

	var right := column(right_sheet())
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override(&"h_separation", 12)
	_grid.add_theme_constant_override(&"v_separation", 12)
	scroll.add_child(_grid)
	for tab in CollectionBook.TABS:
		var b := BookKit.chip("")
		b.pressed.connect(show_page.bind(tab))
		tabs.add_child(b)
		_buttons[tab] = b
	UI._refresh_labels(_buttons, book)
	set_hints([["Z X", "Flip"], ["J", "Close"], ["Esc", "Back"]])
