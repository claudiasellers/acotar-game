## The satchel page: everything Feyre carries, by pocket, beside the map as
## one menu. I / Tab (pad LB tap) opens it, M / LB / RB flips to the map, Esc,
## I, Tab or pad B closes it. Pick an entry to read it; E / Enter / pad A uses
## it, 1–4 (pad X, again to move it) pins it to the quick bar.
##
## Look: theme variations from SatchelTheme only (no colours or fonts here).
class_name SatchelMenu
extends CanvasLayer

signal opened
signal closed

const COLUMNS := 5
const SLOT_PX := 92.0
const OPEN_SECONDS := 0.2

var bar: QuickBar
var pocket: StringName = SatchelEntries.ALL
var selected_id: StringName = &""

var _root: Control
var _card: PanelContainer
var _pocket_buttons: Dictionary = {}
var _grid: GridContainer
var _empty: Label
var _slot_buttons: Dictionary = {}
var _detail_icon_holder: CenterContainer
var _detail_name: Label
var _detail_meta: Label
var _detail_text: Label
var _detail_price: Label
var _use_button: Button
var _pin_buttons: Array[Button] = []
var _meter: ProgressBar
var _load_label: Label
var _coin_label: Label
var _hint: Label
var _map_tab: Button
var _new_ids: Dictionary = {}


func _init(quick_bar: QuickBar = null) -> void:
	bar = quick_bar if quick_bar else QuickBar.current()
	name = "SatchelMenu"


func _ready() -> void:
	layer = 19
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_root.visible = false
	bar.changed.connect(_watch_new)
	_watch_new()


## Marks fresh pickups "new" until the page is next closed (follows the bar
## onto a new inventory after Gameplay.reset).
func _watch_new() -> void:
	if not bar.inventory.item_added.is_connected(_on_item_added):
		bar.inventory.item_added.connect(_on_item_added)


func _on_item_added(id: StringName, _n: int, _c: StringName) -> void:
	_new_ids[id] = true


## Opens the satchel in whichever scene has one (for the map's own tab).
static func open_from(tree: SceneTree) -> void:
	var found := tree.root.find_children("*", "SatchelMenu", true, false)
	if found.size() > 0:
		(found[0] as SatchelMenu).open()


func is_open() -> bool:
	return _root.visible


func open() -> void:
	if is_open():
		return
	_apply_theme()
	_root.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh()
	_animate_in()
	SatchelSounds.play(&"open", self)
	opened.emit()


func close() -> void:
	if not is_open():
		return
	_root.visible = false
	_new_ids.clear()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	SatchelSounds.play(&"close", self)
	closed.emit()


func set_pocket(p: StringName) -> void:
	if p == pocket:
		return
	pocket = p
	SatchelSounds.play(&"page", self)
	_refresh()
	_focus_first()


func select(id: StringName) -> void:
	selected_id = id
	_show_detail()


func use_selected() -> bool:
	if selected_id == &"" or not SatchelUse.can_pin(selected_id):
		SatchelSounds.play(&"refuse", self)
		return false
	var ok := SatchelUse.use(bar.inventory, selected_id, get_tree().get_first_node_in_group(&"player"))
	SatchelSounds.play(&"use" if ok else &"refuse", self)
	if ok:
		var button := _slot_buttons.get(selected_id) as Control
		if button:
			Juice.bounce_control(button, 0.18)
	_refresh()
	return ok


func pin_selected(slot: int) -> bool:
	if not bar.pin(slot, selected_id):
		SatchelSounds.play(&"refuse", self)
		return false
	SatchelSounds.play(&"pin", self)
	Juice.bounce_control(_pin_buttons[slot], 0.2)
	_refresh()
	return true


# --- input -------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if not is_open():
		return
	if event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel") \
			or event.is_action_pressed(SatchelHud.ACTION_OPEN):
		close()
	elif event.is_action_pressed(MapSettings.ACTION_OPEN) or _pad(event, JOY_BUTTON_LEFT_SHOULDER) \
			or _pad(event, JOY_BUTTON_RIGHT_SHOULDER):
		_to_map()
	elif _pad(event, JOY_BUTTON_X):
		pin_selected(bar.next_slot_for(selected_id))
	elif event is InputEventKey and event.pressed and not event.echo \
			and (event as InputEventKey).physical_keycode in [KEY_E, KEY_ENTER, KEY_KP_ENTER]:
		use_selected()
	else:
		for i in QuickBar.SLOTS:
			if event.is_action_pressed(SatchelHud.slot_action(i)):
				pin_selected(i)
				get_viewport().set_input_as_handled()
				return
		return
	get_viewport().set_input_as_handled()


func _pad(event: InputEvent, button: JoyButton) -> bool:
	return event is InputEventJoypadButton and event.pressed and (event as InputEventJoypadButton).button_index == button


func _to_map() -> void:
	var huds := get_tree().root.find_children("*", "WorldMapHud", true, false)
	if huds.is_empty():
		SatchelSounds.play(&"refuse", self)
		return
	close()
	(huds[0] as WorldMapHud).full_map.open()


## Act I and the Spring Court wear different themes (SatchelTheme).
func _apply_theme() -> void:
	_root.theme = SatchelTheme.theme()
	(_root.get_child(0) as ColorRect).color = SatchelTheme.color(&"scrim")


# --- build -------------------------------------------------------------------

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = SatchelTheme.theme()
	add_child(_root)
	var scrim := ColorRect.new()
	scrim.color = SatchelTheme.color(&"scrim")
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(scrim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	_card = PanelContainer.new()
	_card.theme_type_variation = &"SatchelCard"
	_card.custom_minimum_size = Vector2(1240, 700)
	center.add_child(_card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 14)
	_card.add_child(col)
	col.add_child(_build_header())
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override(&"separation", 18)
	col.add_child(body)
	body.add_child(_build_pockets())
	body.add_child(_build_grid())
	body.add_child(_build_detail())
	col.add_child(_build_footer())


func _build_header() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 10)
	var satchel_tab := _button("Satchel", &"SatchelTab")
	satchel_tab.toggle_mode = true
	satchel_tab.button_pressed = true
	satchel_tab.focus_mode = Control.FOCUS_NONE
	row.add_child(satchel_tab)
	_map_tab = _button("Map", &"SatchelTab")
	_map_tab.focus_mode = Control.FOCUS_NONE
	_map_tab.pressed.connect(_to_map)
	row.add_child(_map_tab)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	_coin_label = _label("", &"SatchelHeading")
	row.add_child(_coin_label)
	return row


func _build_pockets() -> Control:
	var list := VBoxContainer.new()
	list.custom_minimum_size = Vector2(210, 0)
	list.add_theme_constant_override(&"separation", 6)
	for p: StringName in SatchelEntries.POCKETS:
		var b := _button(SatchelEntries.POCKET_NAMES[p], &"SatchelTab")
		b.toggle_mode = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(set_pocket.bind(p))
		list.add_child(b)
		_pocket_buttons[p] = b
	return list


func _build_grid() -> Control:
	var holder := VBoxContainer.new()
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	holder.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override(&"h_separation", 10)
	_grid.add_theme_constant_override(&"v_separation", 10)
	scroll.add_child(_grid)
	_empty = _label("Nothing in here yet.", &"SatchelBody")
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	holder.add_child(_empty)
	return holder


func _build_detail() -> Control:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"SatchelDetail"
	panel.custom_minimum_size = Vector2(330, 0)
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 8)
	panel.add_child(col)
	_detail_icon_holder = CenterContainer.new()
	_detail_icon_holder.custom_minimum_size = Vector2(0, 136)
	col.add_child(_detail_icon_holder)
	_detail_name = _label("", &"SatchelHeading")
	_detail_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_detail_name)
	_detail_meta = _label("", &"SatchelSmall")
	col.add_child(_detail_meta)
	_detail_text = _label("", &"SatchelBody")
	_detail_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_detail_text)
	_detail_price = _label("", &"SatchelSmall")
	col.add_child(_detail_price)
	_use_button = _button("Use", &"SatchelTab")
	_use_button.pressed.connect(use_selected)
	col.add_child(_use_button)
	var pins := HBoxContainer.new()
	pins.add_theme_constant_override(&"separation", 6)
	pins.add_child(_label("Quick bar", &"SatchelSmall"))
	for i in QuickBar.SLOTS:
		var b := _button(str(i + 1), &"SatchelTab")
		b.custom_minimum_size = Vector2(44, 40)
		b.pressed.connect(pin_selected.bind(i))
		pins.add_child(b)
		_pin_buttons.append(b)
	col.add_child(pins)
	return panel


func _build_footer() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 14)
	_load_label = _label("", &"SatchelSmall")
	row.add_child(_load_label)
	_meter = ProgressBar.new()
	_meter.theme_type_variation = &"SatchelMeter"
	_meter.show_percentage = false
	_meter.custom_minimum_size = Vector2(260, 14)
	_meter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_meter)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	_hint = _label("", &"SatchelSmall")
	row.add_child(_hint)
	return row


func _button(text: String, variation: StringName) -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = variation
	return b


func _label(text: String, variation: StringName) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = variation
	return l


# --- state -------------------------------------------------------------------

func _refresh() -> void:
	var inv := bar.inventory
	for p: StringName in _pocket_buttons:
		var b := _pocket_buttons[p] as Button
		var n := SatchelEntries.list(inv, p).size()
		b.text = "%s  %d" % [SatchelEntries.POCKET_NAMES[p], n] if n > 0 else String(SatchelEntries.POCKET_NAMES[p])
		b.set_pressed_no_signal(p == pocket)
	var entries := SatchelEntries.list(inv, pocket)
	for c in _grid.get_children():
		c.queue_free()
	_slot_buttons.clear()
	for e in entries:
		var b := _slot(e)
		_grid.add_child(b)
		_slot_buttons[e.id] = b
	_empty.visible = entries.is_empty()
	if not entries.any(func(e: Dictionary) -> bool: return e.id == selected_id):
		selected_id = entries[0].id if entries.size() > 0 else &""
	_show_detail()
	_coin_label.text = "%d coppers" % inv.coin
	var cap := float(Inventory.CAPACITY[Inventory.SATCHEL])
	_meter.max_value = cap
	_meter.value = inv.used(Inventory.SATCHEL)
	_load_label.text = "Satchel %s / %d   Pouch %s / %d" % [
		_units(inv.used(Inventory.SATCHEL)), int(cap),
		_units(inv.used(Inventory.POUCH)), int(Inventory.CAPACITY[Inventory.POUCH])]
	if inv.speed_multiplier() < 1.0:
		_load_label.text += "   Heavy: she walks slower"
	_hint.text = "Use  E     Pin  1–4     Map  M     Close  Esc" if not SatchelHud.pad_active \
			else "Use  A     Pin  X     Map  LB / RB     Close  B"


func _slot(e: Dictionary) -> Button:
	var b := Button.new()
	b.theme_type_variation = &"SatchelSlot"
	b.custom_minimum_size = Vector2(SLOT_PX, SLOT_PX)
	b.focus_mode = Control.FOCUS_ALL
	b.tooltip_text = e.name
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centre.add_child(_icon(e, 58.0))
	b.add_child(centre)
	if int(e.count) > 1:
		var n := _label("×%d" % e.count, &"SatchelCount")
		n.position = Vector2(SLOT_PX - 40, SLOT_PX - 26)
		b.add_child(n)
	var at := bar.slot_of(e.id)
	if at >= 0:
		var pin := _label(str(at + 1), &"QuickBarKey")
		pin.position = Vector2(8, 4)
		b.add_child(pin)
	if _new_ids.has(e.id):
		var dot := _label("new", &"SatchelSmall")
		dot.position = Vector2(SLOT_PX - 40, 4)
		b.add_child(dot)
	b.focus_entered.connect(_on_slot_focus.bind(e.id))
	b.mouse_entered.connect(func() -> void: b.grab_focus())
	b.pressed.connect(func() -> void:
		if selected_id == e.id and SatchelUse.can_pin(e.id):
			use_selected()
		else:
			select(e.id))
	return b


func _on_slot_focus(id: StringName) -> void:
	if id == selected_id:
		return
	select(id)
	SatchelSounds.play(&"select", self)


func _icon(e: Dictionary, px: float) -> ItemIcon:
	var c: Color = e.color if e.item != null else SatchelTheme.color(&"accent")
	return ItemIcon.make(e.icon, c, false, e.rare and (e.item as ItemData).rarity == &"shiny", px)


func _show_detail() -> void:
	for c in _detail_icon_holder.get_children():
		c.queue_free()
	var e := SatchelEntries.find(bar.inventory, selected_id) if selected_id != &"" else {}
	var has := not e.is_empty()
	_detail_name.text = e.name if has else ""
	_detail_text.text = e.description if has else "Her satchel. Plain, patched, and everything she owns that matters fits in it."
	_detail_meta.text = ""
	_detail_price.text = ""
	if has:
		var big := _icon(e, 112.0)
		_detail_icon_holder.add_child(big)
		Juice.bounce_control(big, 0.08)
		var item := e.item as ItemData
		_detail_meta.text = "%s · carrying %d" % [SatchelEntries.POCKET_NAMES.get(e.pocket, ""), e.count]
		if item and item.base_price > 0:
			_detail_price.text = "The market pays %d coppers" % item.base_price
	var verb := SatchelUse.verb(selected_id) if has else ""
	_use_button.visible = verb != ""
	_use_button.text = verb
	for i in _pin_buttons.size():
		_pin_buttons[i].disabled = not has or not SatchelUse.can_pin(selected_id)
		_pin_buttons[i].set_pressed_no_signal(bar.entry(i) == selected_id)
		_pin_buttons[i].toggle_mode = true


func _units(v: float) -> String:
	return str(snappedf(v, 0.25)).trim_suffix(".0")


func _focus_first() -> void:
	var target := _slot_buttons.get(selected_id) as Control
	if target == null and _grid.get_child_count() > 0:
		target = _grid.get_child(0) as Control
	if target:
		target.grab_focus.call_deferred()
	else:
		(_pocket_buttons[pocket] as Control).grab_focus()


func _animate_in() -> void:
	_card.modulate.a = 0.0
	_card.pivot_offset = _card.size * 0.5
	_card.scale = Vector2.ONE * 0.96
	var t := _card.create_tween().set_parallel()
	t.tween_property(_card, ^"modulate:a", 1.0, OPEN_SECONDS)
	t.tween_property(_card, ^"scale", Vector2.ONE, OPEN_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var i := 0
	for c in _grid.get_children():
		var slot := c as Control
		slot.modulate.a = 0.0
		var st := slot.create_tween()
		st.tween_interval(0.05 + 0.018 * mini(i, 18))
		st.tween_property(slot, ^"modulate:a", 1.0, 0.12)
		i += 1
	_focus_first()
