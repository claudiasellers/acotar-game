## The Bonds page of Feyre's journal (owner, 2026-11-25): everyone in her
## life and the white mare in one place. The left sheet lists who she knows;
## the right sheet is the one she has turned to: what she calls them, how
## they are with her these days, and what has passed between them, oldest
## first, each with its day. Everything is in her hand and nothing is a
## number or a meter (R2): the words are BondBook's, which reads story flags.
## A mark on the tab says something has passed since she last looked.
class_name BondsTab
extends MenuTab

## The dab of paint beside a name in the list, and on the open page.
const DAB := 34.0
const PAGE_DAB := 64.0
const ROW_HEIGHT := 62.0

## The bond the right sheet shows.
var showing: StringName = &""

var _list: VBoxContainer
var _name: Label
var _dab_holder: Control
var _days: Label
var _past: VBoxContainer
var _rows: Dictionary = {}  # bond id -> Button


## The scene's Bonds page, made (as a child of the shell) if it has none.
static func ensure(tree: SceneTree) -> BondsTab:
	var shell := MenuShell.of(tree)
	var tab := shell.find(&"bonds") as BondsTab
	if tab == null:
		tab = BondsTab.new()
		shell.add_child(tab)
		shell.register(tab)
	return tab


func _init() -> void:
	name = "Bonds"
	tab_id = &"bonds"
	tab_title = "Bonds"
	tab_order = 5
	opens_in_story = true


func _ready() -> void:
	_build()
	# One listener for the game, whichever scene's page came first.
	if not EventBus.flag_changed.is_connected(BondBook.stamp):
		EventBus.flag_changed.connect(BondBook.stamp)


func available() -> bool:
	return is_inside_tree() and get_tree().get_first_node_in_group(&"player") != null


## Something has passed with someone since she last opened the page.
func has_news() -> bool:
	return BondBook.count() > int(WorldDeltas.get_region_value(BondBook.DELTAS, "seen", 0))


func _shown() -> void:
	WorldDeltas.set_region_value(BondBook.DELTAS, "seen", BondBook.count())
	_refresh()


## Turns the right sheet to one of the people she knows.
func show_bond(id: StringName) -> void:
	showing = id
	_refresh()


func _build() -> void:
	var left := column(left_sheet(), 8)
	left.add_child(BookKit.title("Bonds"))
	left.add_child(BookKit.label("Who I know, and what has passed between us.", &"SatchelWhere", true))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override(&"separation", 6)
	scroll.add_child(_list)

	var right := column(right_sheet(), 8)
	var head := HBoxContainer.new()
	head.add_theme_constant_override(&"separation", 14)
	right.add_child(head)
	_dab_holder = Control.new()
	_dab_holder.custom_minimum_size = Vector2(PAGE_DAB, PAGE_DAB)
	head.add_child(_dab_holder)
	_name = BookKit.label("", &"SatchelHeading")
	_name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_name)
	right.add_child(BookKit.section("These days"))
	_days = BookKit.label("", &"SatchelBody", true)
	right.add_child(_days)
	right.add_child(BookKit.gap(6.0))
	right.add_child(BookKit.section("What has passed between us"))
	var past_scroll := ScrollContainer.new()
	past_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	past_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(past_scroll)
	_past = VBoxContainer.new()
	_past.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_past.add_theme_constant_override(&"separation", 10)
	past_scroll.add_child(_past)
	set_hints([["Q E", "Page"], ["Esc", "Back"]])


func _refresh() -> void:
	var known := BondBook.known()
	if BondBook.get_bond(showing).is_empty() or not known.has(BondBook.get_bond(showing)):
		showing = known[0].id if not known.is_empty() else &""
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	_rows.clear()
	var group := ButtonGroup.new()
	for i in known.size():
		var row := _row(known[i], i, group)
		_rows[known[i].id] = row
		_list.add_child(row)
	_write_page(BondBook.get_bond(showing), known.find(BondBook.get_bond(showing)))


## One of the people she knows: a dab of paint, the name, and the last thing
## that passed.
func _row(bond: Dictionary, i: int, group: ButtonGroup) -> Button:
	var b := Button.new()
	b.name = String(bond.id)
	b.theme_type_variation = &"SatchelSlot"
	b.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	b.focus_mode = Control.FOCUS_ALL
	b.toggle_mode = true
	b.button_group = group
	b.button_pressed = bond.id == showing
	b.pressed.connect(show_bond.bind(bond.id))
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 10
	row.offset_right = -10
	row.add_theme_constant_override(&"separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var dab := BookKit.wash(DAB, i)
	dab.modulate.a = LoosePage.DAB_LIFT
	dab.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(dab)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	words.add_theme_constant_override(&"separation", 0)
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(words)
	words.add_child(BookKit.label(BondBook.called(bond), &"SatchelBody"))
	var past := BondBook.moments(bond)
	var last := BookKit.label(String(past[-1].then) if not past.is_empty() else "", &"SatchelSmall")
	last.clip_text = true
	last.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	words.add_child(last)
	return b


func _write_page(bond: Dictionary, i: int) -> void:
	for c in _dab_holder.get_children():
		_dab_holder.remove_child(c)
		c.queue_free()
	for c in _past.get_children():
		_past.remove_child(c)
		c.queue_free()
	if bond.is_empty():
		_name.text = ""
		_days.text = ""
		return
	var dab := BookKit.wash(PAGE_DAB, i)
	dab.modulate.a = LoosePage.DAB_LIFT
	_dab_holder.add_child(dab)
	_name.text = BondBook.called(bond)
	_days.text = BondBook.these_days(bond)
	for m in BondBook.moments(bond):
		var line := HBoxContainer.new()
		line.add_theme_constant_override(&"separation", 12)
		var day := BookKit.label("Day %d" % int(m.day) if int(m.day) > 0 else "Before", &"SatchelWhere")
		day.custom_minimum_size.x = 84.0
		line.add_child(day)
		var then := BookKit.label(String(m.then), &"SatchelBody", true)
		then.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(then)
		_past.add_child(line)
