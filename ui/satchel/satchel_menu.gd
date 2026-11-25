## The satchel page of Feyre's journal: everything she carries, drawn on the
## left sheet as specimens (each over its own blot of wash), and the one she is
## looking at written up on the right: what it is, where and when it grows,
## what it is good for, and whether it hangs on her strap.
##
## A page of the menu shell (MenuShell): I / Tab opens it; Z / X (pad LT / RT)
## flip pockets, W (pad Y) is the wardrobe page, Enter / Space / F (pad A)
## uses, 1–4 (pad X) pins to the strap. The shell owns Q / E (LB / RB) for
## pages and closes it. A thing's slot is made once and kept (warmed while
## the book is closed), so opening and flipping pockets re-lays, never
## rebuilds. Silent by the user's call (T022). Look: JournalTheme variations
## only; no colours or fonts here.
class_name SatchelMenu
extends MenuTab

const COLUMNS := 5
const SLOT := 124.0
const ICON := 96.0
const STUDY := 250.0
const STUDY_ICON := 190.0
## Her two notes beside the study, in study space: where each note's hairline
## starts (the note sits outside it) and the spot on the picture it ends on.
const CALLOUTS: Array[Array] = [
	[Vector2(-18, 46), Vector2(78, 88)],
	[Vector2(268, 196), Vector2(172, 164)],
]
const CALLOUT_WIDTH := 190.0

var bar: QuickBar
var pocket: StringName = SatchelEntries.ALL
var selected_id: StringName = &""

var _flaps: HFlowContainer
var _pocket_buttons: Dictionary = {}
var _purse: Label
var _grid: GridContainer
var _empty: Label
## Every thing's slot, kept across opens and pockets: id -> Button.
var _slots: Dictionary = {}
var _study: Control
var _study_icon: Control
var _callouts: Control
var _notes: Array[Label] = []
var _detail: VBoxContainer
var _name: Label
var _line: Label
var _where: Label
var _chips: HFlowContainer
var _stats: Dictionary = {}  # word -> Label
var _use_button: Button
var _pin_row: HBoxContainer
var _pin_buttons: Array[Button] = []
var _load_glyph: SatchelGlyph
var _load_label: Label
var _new_ids: Dictionary = {}


func _init(quick_bar: QuickBar = null) -> void:
	bar = quick_bar if quick_bar else QuickBar.current()
	name = "SatchelMenu"
	tab_id = &"satchel"
	tab_title = "Satchel"
	tab_order = 0
	shortcut = SatchelHud.ACTION_OPEN


func _ready() -> void:
	_build()
	bar.changed.connect(_watch_new)
	_watch_new()


## Opens the satchel in whichever scene has one.
static func open_from(tree: SceneTree) -> void:
	MenuShell.open_tab(tree, &"satchel")


func _shown() -> void:
	_load_glyph.queue_redraw()
	_refresh()


func _hidden() -> void:
	_new_ids.clear()


## While the book is closed: one thing's slot a frame, so the satchel opens
## with every picture already loaded.
func warm_jobs() -> Array[Callable]:
	return [_warm_next]


func _warm_next() -> void:
	if _grid == null or is_open():
		return
	for e in SatchelEntries.list(bar.inventory, SatchelEntries.ALL):
		if not _slots.has(e.id):
			_make_slot(e)
			MenuShell.of(get_tree()).queue_warm(self)
			return


func set_pocket(p: StringName) -> void:
	if p == pocket:
		return
	pocket = p
	_refresh()


## Next / previous pocket, wrapping round.
func flip(step: int) -> void:
	var n := SatchelEntries.POCKETS.size()
	set_pocket(SatchelEntries.POCKETS[posmod(SatchelEntries.POCKETS.find(pocket) + step, n)])


func select(id: StringName) -> void:
	if id == selected_id:
		return
	selected_id = id
	_show_detail()
	_sync_hints()
	if _study_icon:
		Juice.bounce_control(_study, 0.05)


func use_selected() -> bool:
	if selected_id == &"" or not SatchelUse.can_pin(selected_id):
		return false
	var ok := SatchelUse.use(bar.inventory, selected_id, get_tree().get_first_node_in_group(&"player"))
	if ok:
		_refresh()
	return ok


func pin_selected(slot: int) -> bool:
	if not bar.pin(slot, selected_id):
		return false
	Juice.bounce_control(_pin_buttons[slot], 0.2)
	_show_detail()
	return true


# --- input -------------------------------------------------------------------

func _page_input(event: InputEvent) -> bool:
	if pad_pressed(event, JOY_BUTTON_Y) or key_pressed(event, [KEY_W]):
		MenuShell.open_tab(get_tree(), &"wardrobe")
	elif trigger_pulled(event, JOY_AXIS_TRIGGER_LEFT) or key_pressed(event, [KEY_Z]):
		flip(-1)
	elif trigger_pulled(event, JOY_AXIS_TRIGGER_RIGHT) or key_pressed(event, [KEY_X]):
		flip(1)
	elif pad_pressed(event, JOY_BUTTON_X):
		pin_selected(bar.next_slot_for(selected_id))
	elif key_pressed(event, [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_F]):
		use_selected()
	else:
		for i in QuickBar.SLOTS:
			if event.is_action_pressed(SatchelHud.slot_action(i)):
				pin_selected(i)
				return true
		return false
	return true


func _watch_new() -> void:
	if not bar.inventory.item_added.is_connected(_on_item_added):
		bar.inventory.item_added.connect(_on_item_added)


func _on_item_added(id: StringName, _n: int, _c: StringName) -> void:
	_new_ids[id] = true
	if not _slots.has(id) and is_inside_tree():
		MenuShell.of(get_tree()).queue_warm(self)


# --- build -------------------------------------------------------------------

func _build() -> void:
	var left := column(left_sheet())
	var head := HBoxContainer.new()
	left.add_child(head)
	var title := BookKit.title("Satchel")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_purse = BookKit.label("", &"SatchelSmall")
	_purse.size_flags_vertical = Control.SIZE_SHRINK_END
	head.add_child(_purse)
	_flaps = HFlowContainer.new()
	_flaps.add_theme_constant_override(&"h_separation", 6)
	_flaps.add_theme_constant_override(&"v_separation", 6)
	left.add_child(_flaps)
	for p: StringName in SatchelEntries.POCKETS:
		var b := BookKit.chip(SatchelEntries.POCKET_NAMES[p])
		b.pressed.connect(set_pocket.bind(p))
		_flaps.add_child(b)
		_pocket_buttons[p] = b
	left.add_child(HSeparator.new())
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	left.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override(&"h_separation", 14)
	_grid.add_theme_constant_override(&"v_separation", 14)
	scroll.add_child(_grid)
	_empty = BookKit.label("Nothing in this pocket yet.", &"SatchelWhere")
	_empty.set_anchors_preset(Control.PRESET_CENTER)
	_empty.grow_horizontal = Control.GROW_DIRECTION_BOTH
	left_sheet().add_child(_empty)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override(&"separation", 10)
	left.add_child(foot)
	_load_glyph = SatchelGlyph.new()
	_load_glyph.custom_minimum_size = Vector2(44, 40)
	foot.add_child(_load_glyph)
	_load_label = BookKit.label("", &"SatchelSmall")
	_load_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(_load_label)

	_detail = column(right_sheet(), 8)
	_study = Control.new()
	_study.custom_minimum_size = Vector2(STUDY, STUDY)
	_study.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_study.pivot_offset = Vector2(STUDY, STUDY) * 0.5
	_study.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail.add_child(_study)
	_study.add_child(BookKit.wash(STUDY, 0))
	_callouts = Control.new()
	_callouts.name = "Callouts"
	_callouts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_callouts.z_index = 1
	_callouts.draw.connect(_draw_callouts)
	_study.add_child(_callouts)
	for i in CALLOUTS.size():
		var note := BookKit.label("", &"SatchelWhere")
		note.name = "Note%d" % i
		note.size = Vector2(CALLOUT_WIDTH, 28)
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if i == 0 else HORIZONTAL_ALIGNMENT_LEFT
		var from: Vector2 = CALLOUTS[i][0]
		note.position = from + Vector2(-CALLOUT_WIDTH - 8.0 if i == 0 else 8.0, -16.0)
		_callouts.add_child(note)
		_notes.append(note)
	_name = BookKit.label("", &"SatchelHeading", true)
	_detail.add_child(_name)
	_detail.add_child(HSeparator.new())
	_line = BookKit.label("", &"SatchelBody", true)
	_detail.add_child(_line)
	_where = BookKit.label("", &"SatchelWhere", true)
	_detail.add_child(_where)
	_chips = HFlowContainer.new()
	_chips.add_theme_constant_override(&"h_separation", 6)
	_chips.add_theme_constant_override(&"v_separation", 6)
	_detail.add_child(_chips)
	_detail.add_child(BookKit.gap(6))
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override(&"separation", 28)
	_detail.add_child(stats)
	for word in ["Carried", "On the strap", "Weight", "At market"]:
		var stat := BookKit.section(word)
		_stats[word] = BookKit.label("", &"SatchelBody")
		stat.add_child(_stats[word])
		stats.add_child(stat)
	_detail.add_child(BookKit.gap(6))
	var act := HBoxContainer.new()
	act.add_theme_constant_override(&"separation", 8)
	_detail.add_child(act)
	_use_button = BookKit.chip("Use", false)
	_use_button.pressed.connect(use_selected)
	act.add_child(_use_button)
	_pin_row = HBoxContainer.new()
	_pin_row.add_theme_constant_override(&"separation", 6)
	_pin_row.alignment = BoxContainer.ALIGNMENT_END
	_pin_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	act.add_child(_pin_row)
	var strap := BookKit.label("Strap", &"SatchelSmall")
	strap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_pin_row.add_child(strap)
	for i in QuickBar.SLOTS:
		var b := BookKit.chip(str(i + 1))
		b.tooltip_text = "Hang on strap ring %d" % (i + 1)
		b.pressed.connect(pin_selected.bind(i))
		_pin_row.add_child(b)
		_pin_buttons.append(b)
	_detail.add_child(BookKit.spring())
	var sky := BookKit.sky(520.0)
	sky.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_detail.add_child(sky)


# --- the specimens -----------------------------------------------------------

## Lays the current pocket out on the left sheet.
func _refresh() -> void:
	var inv := bar.inventory
	for p: StringName in _pocket_buttons:
		(_pocket_buttons[p] as Button).set_pressed_no_signal(p == pocket)
	var entries := SatchelEntries.list(inv, pocket)
	var here := {}
	for i in entries.size():
		var e := entries[i]
		var slot: Button = _slots[e.id] if _slots.has(e.id) else _make_slot(e)
		slot.visible = true
		_grid.move_child(slot, i)
		here[e.id] = true
	# Off this pocket: kept for next time. No longer carried: let go.
	var carried := {}
	for e in SatchelEntries.list(inv, SatchelEntries.ALL):
		carried[e.id] = true
	for id: StringName in _slots.keys():
		var slot := _slots[id] as Button
		if not carried.has(id):
			_slots.erase(id)
			slot.queue_free()
		elif not here.has(id):
			slot.visible = false
	_empty.visible = entries.is_empty()
	_detail.visible = not entries.is_empty()
	if not here.has(selected_id):
		selected_id = entries[0].id if entries.size() > 0 else &""
	_show_detail()
	_purse.text = _coppers(inv.coin)
	var cap := float(Inventory.CAPACITY[Inventory.SATCHEL])
	_load_glyph.fill = clampf(inv.used(Inventory.SATCHEL) / cap, 0.0, 1.0)
	_load_label.text = "%s / %d" % [_units(inv.used(Inventory.SATCHEL)), int(cap)]
	if inv.speed_multiplier() < 1.0:
		_load_label.text += "   heavy, she walks slower"
	_sync_hints()
	_focus_selected.call_deferred()


## One thing on the page: its picture over a blot of wash, how many, and
## which strap ring it hangs on.
func _make_slot(e: Dictionary) -> Button:
	var b := Button.new()
	b.name = String(e.id).validate_node_name()
	b.theme_type_variation = &"SatchelSlot"
	b.toggle_mode = true
	b.custom_minimum_size = Vector2(SLOT, SLOT)
	b.pivot_offset = Vector2(SLOT, SLOT) * 0.5
	b.focus_mode = Control.FOCUS_ALL
	b.tooltip_text = e.name
	b.visible = false
	var blot := BookKit.wash(SLOT * 0.86, hash(String(e.id)))
	blot.position = Vector2.ONE * SLOT * 0.07
	b.add_child(blot)
	var icon := Icons.item(e, ICON)
	icon.position = Vector2.ONE * (SLOT - ICON) * 0.5
	b.add_child(icon)
	var count := BookKit.count_badge()
	count.name = "Count"
	count.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	count.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	count.grow_vertical = Control.GROW_DIRECTION_BEGIN
	count.offset_right = -4
	count.offset_bottom = -4
	b.add_child(count)
	var pin := BookKit.slot_badge()
	pin.name = "Pin"
	pin.position = Vector2(2, 2)
	b.add_child(pin)
	var fresh := BookKit.new_badge()
	fresh.name = "New"
	fresh.position = Vector2(2, 2)
	b.add_child(fresh)
	_grid.add_child(b)
	_slots[e.id] = b
	b.focus_entered.connect(select.bind(e.id))
	b.mouse_entered.connect(b.grab_focus)
	# Pointing at a thing chooses it, so a press uses it.
	b.pressed.connect(func() -> void:
		select(e.id)
		use_selected()
		_mark_selected())
	return b


func _mark_selected() -> void:
	for id: StringName in _slots:
		(_slots[id] as Button).set_pressed_no_signal(id == selected_id)


func _update_badges(e: Dictionary) -> void:
	var slot := _slots.get(e.id) as Button
	if slot == null:
		return
	var count := slot.get_node(^"Count") as Label
	count.text = "×%d" % e.count
	count.visible = int(e.count) > 1
	var pin := slot.get_node(^"Pin") as Label
	var at := bar.slot_of(e.id)
	pin.text = str(at + 1) if at >= 0 else ""
	pin.visible = at >= 0
	# A thing in a pan has been handled: it wears its pan's key, not the ribbon.
	(slot.get_node(^"New") as Label).visible = at < 0 and _new_ids.has(e.id)


func _show_detail() -> void:
	for e in SatchelEntries.list(bar.inventory, pocket):
		_update_badges(e)
	_mark_selected()
	var e := SatchelEntries.find(bar.inventory, selected_id) if selected_id != &"" else {}
	if e.is_empty():
		return
	var item := e.item as ItemData
	if _study_icon:
		_study_icon.queue_free()
	_study_icon = Icons.item(e, STUDY_ICON)
	_study_icon.position = Vector2.ONE * (STUDY - STUDY_ICON) * 0.5
	_study.add_child(_study_icon)
	(_study.get_child(0) as CanvasItem).modulate = JournalTheme.wash(hash(String(e.id)))
	var written := ItemNotes.of(e.id)
	for i in _notes.size():
		_notes[i].text = written.labels[i] if written and i < written.labels.size() else ""
	_callouts.queue_redraw()
	_name.text = e.name
	_line.text = e.description
	_where.text = " ".join([where_text(item), made_from(e.id)]).strip_edges()
	_where.visible = _where.text != ""
	for c in _chips.get_children():
		c.queue_free()
	for word in trait_words(item):
		var chip := PanelContainer.new()
		chip.theme_type_variation = &"SatchelChip"
		chip.add_child(BookKit.label(word, &"SatchelSmall"))
		_chips.add_child(chip)
	_chips.visible = not trait_words(item).is_empty()
	var ring := bar.slot_of(selected_id)
	(_stats["Carried"] as Label).text = str(e.count)
	(_stats["On the strap"] as Label).text = "ring %d" % (ring + 1) if ring >= 0 else "no"
	(_stats["Weight"] as Label).text = _units(item.weight_units()) if item else "light"
	(_stats["At market"] as Label).text = _coppers(item.base_price) if item and item.base_price > 0 else "not sold"
	var verb := SatchelUse.verb(selected_id)
	_use_button.visible = verb != ""
	_use_button.text = verb
	_pin_row.visible = SatchelUse.can_pin(selected_id)
	for i in _pin_buttons.size():
		_pin_buttons[i].set_pressed_no_signal(bar.entry(i) == selected_id)


## A hairline from each written note to the part of the picture it names.
func _draw_callouts() -> void:
	var ink := Color(JournalTheme.color(&"ink_soft"), 0.75)
	for i in _notes.size():
		if _notes[i].text == "":
			continue
		var from: Vector2 = CALLOUTS[i][0]
		var to: Vector2 = CALLOUTS[i][1]
		_callouts.draw_line(from, to, ink, 1.2, true)
		_callouts.draw_circle(to, 2.5, ink, true, -1.0, true)


## Where and when it grows, from the catalogue: "The western fells, in
## spring." / "Only at night." Empty for things that aren't found.
static func where_text(item: ItemData) -> String:
	if item == null:
		return ""
	var parts: Array[String] = []
	if item.hint != "":
		parts.append(item.hint.trim_suffix("."))
	var when := ""
	var bound := item.bound
	if item is IngredientData and (item as IngredientData).night_only:
		bound = &"night"
	match bound:
		&"dawn": when = "only at dawn"
		&"dusk": when = "only at dusk"
		&"night": when = "only at night"
		&"mist": when = "only in the morning mist"
		&"rain": when = "only in the rain"
		&"snow": when = "only in the snow"
	if when == "" and item is IngredientData:
		var season := (item as IngredientData).season
		if season == &"winter" or season == &"spring":
			when = "in " + String(season)
	if when != "" and not (parts.size() > 0 and parts[0].to_lower().contains(when.trim_prefix("only ").trim_prefix("in ").trim_prefix("at "))):
		parts.append(when)
	if parts.is_empty():
		return ""
	var out := ", ".join(parts)
	return out.left(1).to_upper() + out.substr(1) + "."


## What an arrow is made from, from its recipe: "Made from 1 arrow shaft,
## 1 fletching, 1 arrowhead." Empty for anything else.
static func made_from(id: StringName) -> String:
	var recipe := Crafting.recipe(id) if String(id).begins_with("arrow_") else null
	if recipe == null:
		return ""
	var parts: Array[String] = []
	for key: String in recipe.inputs:
		var part := ItemCatalog.get_item(StringName(key))
		var word := key.trim_prefix("tag:") if key.begins_with("tag:") else (part.display_name.to_lower() if part else key)
		parts.append("%d %s" % [int(recipe.inputs[key]), word])
	return "Made from %s." % ", ".join(parts)


## Small chips: its chemistry tags, whether she can eat it, and how rare it
## is. Words come straight from the data (no invented lore).
static func trait_words(item: ItemData) -> Array[String]:
	var out: Array[String] = []
	if item == null:
		return out
	if item.rarity == &"shiny":
		out.append("Shimmering")
	elif item.rarity == &"rare":
		out.append("Rare")
	if item is IngredientData:
		var ing := item as IngredientData
		for t in ing.tags:
			out.append(String(t).capitalize())
		if ing.edible and ing.nutrition > 0.0 and not ing.is_apply_only():
			out.append("Edible")
		if ing.pigment != &"":
			out.append("%s pigment" % String(ing.pigment).capitalize())
	return out


## Key caps, not a sentence: pad or keys, whichever was used last.
func _sync_hints() -> void:
	var pad := SatchelHud.pad_active
	var pairs: Array = []
	var verb := SatchelUse.verb(selected_id) if selected_id != &"" else ""
	if verb != "":
		pairs.append(["A" if pad else "Enter", verb])
		pairs.append(["X" if pad else "1–4", "Strap"])
	pairs.append(["LT RT" if pad else "Z X", "Pocket"])
	pairs.append(["Y" if pad else "W", "Wardrobe"])
	pairs.append(["B" if pad else "Esc", "Back"])
	set_hints(pairs)


func _focus_selected() -> void:
	var slot := _slots.get(selected_id) as Button
	if slot and slot.is_visible_in_tree():
		slot.grab_focus()


func _units(v: float) -> String:
	return str(snappedf(v, 0.25)).trim_suffix(".0")


func _coppers(n: int) -> String:
	return "1 copper" if n == 1 else "%d coppers" % n
