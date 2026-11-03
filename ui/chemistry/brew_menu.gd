## The brewing screen (lane L62): at any hearth, kitchen range, stillroom
## bench, potion room or the starlight pool, Feyre lays forage from her pouch
## and satchel into the pot, picks how to work it, and brews. Drawn on the
## satchel's crafted look (L50; SatchelTheme only, no colours here).
##
## Discovery, not a recipe list: her hunch line only names a brew she has
## made before, or the tags she has learned from using each ingredient. The
## first time a named brew comes out of the pot, a card shows its name and
## her note, with sparkle, chime and bounce (R3).
class_name BrewMenu
extends CanvasLayer

signal brewed(result: Dictionary)
signal closed

const WIDTH := 780.0
const ICON := 52.0
const COLUMNS := 6
## The scene-tree name, kept from the M1 panel (tests and tools look for it).
const NODE_NAME := "HearthPanel"
## Effect tag -> the word Feyre senses for it.
const SENSE := {
	&"warm": "warm", &"cool": "cool", &"bright": "bright", &"quiet": "quiet",
	&"swift": "quick", &"strong": "strong", &"steady": "steadying", &"keen": "sharp",
	&"heal": "mending", &"harm": "bitter", &"fae_toll": "strange",
}

var feyre: Feyre
var station: CookingStation
var chosen: Array[StringName] = []
var method: StringName = &""
## The last brew result (empty before the first brew).
var last: Dictionary = {}

var _root: Control
var _card: PanelContainer
var _title: Label
var _found: Label
var _grid: GridContainer
var _pot: HBoxContainer
var _methods: HBoxContainer
var _hunch: Label
var _brew: Button
var _reveal: PanelContainer
var _reveal_name: Label
var _reveal_note: Label
var _reveal_swatch: Panel
var _outcome: Label
var _dishes: VBoxContainer


## Opens the screen at `at`, making one if the scene has none.
static func open_for(who: Feyre, at: CookingStation) -> BrewMenu:
	if who == null or at == null or not who.is_inside_tree():
		return null
	var menu := find(who.get_tree())
	if menu == null:
		menu = BrewMenu.new()
		who.get_tree().root.add_child(menu)
	menu.open(who, at)
	return menu


static func find(tree: SceneTree) -> BrewMenu:
	return tree.root.get_node_or_null(NODE_NAME) as BrewMenu


func _init() -> void:
	name = NODE_NAME


func _ready() -> void:
	layer = 19
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()


func is_open() -> bool:
	return _root != null and _root.visible


func open(who: Feyre, at: CookingStation) -> void:
	feyre = who
	station = at
	chosen.clear()
	method = at.station.methods[0] if at.station and not at.station.methods.is_empty() else &""
	_reveal.visible = false
	_outcome.text = ""
	_root.theme = SatchelTheme.theme()
	_root.visible = true
	_refresh()
	if is_inside_tree():
		get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Juice.bounce_control(_card, 0.05)


func close() -> void:
	if not is_open():
		return
	_root.visible = false
	if is_inside_tree():
		get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	closed.emit()


## Adds or removes one ingredient from the pot. Returns true if it changed.
func toggle(id: StringName) -> bool:
	if chosen.has(id):
		chosen.erase(id)
	elif station and chosen.size() < station.station.max_ingredients:
		chosen.append(id)
	else:
		return false
	_refresh()
	return true


func set_method(m: StringName) -> void:
	method = m
	_refresh()


## Brews what is in the pot. The result is CookingStation.cook's.
func brew() -> Dictionary:
	if station == null or chosen.is_empty():
		return {"ok": false, "reason": "the pot is empty"}
	var r := station.cook(chosen.duplicate(), method)
	last = r
	if r.ok:
		chosen.clear()
		_show_result(r)
		brewed.emit(r)
	else:
		_reveal.visible = false
		var why := String(r.reason)
		_outcome.text = why[0].to_upper() + why.substr(1) + "."
	_refresh()
	return r


## What she expects from the pot as it stands, without using anything up.
func hunch() -> String:
	if chosen.is_empty():
		return "Pick what goes in the pot."
	var items: Array[IngredientData] = []
	for id in chosen:
		items.append(ItemCatalog.get_item(id) as IngredientData)
	var r := Chemistry.combine(items, station.station if station else null, method)
	if not r.ok:
		var why := String(r.reason)
		return why[0].to_upper() + why.substr(1) + "."
	var brew_id := StringName(r.get("brew", &""))
	if brew_id != &"" and Gameplay.journal.has_brew(brew_id):
		return "%s. I've made this before." % BrewBook.get_rule(brew_id).display_name
	var words := PackedStringArray()
	for id in chosen:
		if Gameplay.journal.known_tags(id).is_empty():
			return "I don't know what this will make. Only one way to find out."
	for key: StringName in SENSE:
		if BrewRule.value_of(r, key) > 0.001 and not words.has(SENSE[key]):
			words.append(SENSE[key])
	if words.is_empty():
		return "Something plain, I think."
	return "Something %s, I think." % ", ".join(words.slice(0, 3))


# --- input -------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if not is_open():
		return
	if event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel") \
			or _pad(event, JOY_BUTTON_B):
		close()
	elif _key(event, [KEY_E, KEY_ENTER, KEY_KP_ENTER]) or _pad(event, JOY_BUTTON_Y):
		brew()
	else:
		return
	get_viewport().set_input_as_handled()


func _pad(event: InputEvent, button: JoyButton) -> bool:
	return event is InputEventJoypadButton and event.pressed and (event as InputEventJoypadButton).button_index == button


func _key(event: InputEvent, keys: Array) -> bool:
	return event is InputEventKey and event.pressed and not event.echo \
			and (event as InputEventKey).physical_keycode in keys


# --- build -------------------------------------------------------------------

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = SatchelTheme.theme()
	_root.visible = false
	add_child(_root)
	var scrim := ColorRect.new()
	scrim.color = SatchelTheme.color(&"scrim")
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(scrim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	_card = PanelContainer.new()
	_card.theme_type_variation = &"SatchelDetail"
	_card.custom_minimum_size = Vector2(WIDTH, 0)
	center.add_child(_card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 12)
	_card.add_child(col)

	var head := HBoxContainer.new()
	col.add_child(head)
	_title = _label("", &"SatchelHeading")
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	var chip := PanelContainer.new()
	chip.theme_type_variation = &"SatchelChip"
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(chip)
	_found = _label("", &"SatchelCount")
	chip.add_child(_found)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, (ICON + 22.0) * 3.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override(&"h_separation", 8)
	_grid.add_theme_constant_override(&"v_separation", 8)
	scroll.add_child(_grid)

	col.add_child(HSeparator.new())
	var pot_row := HBoxContainer.new()
	pot_row.add_theme_constant_override(&"separation", 12)
	col.add_child(pot_row)
	pot_row.add_child(_label("In the pot", &"SatchelSmall"))
	_pot = HBoxContainer.new()
	_pot.add_theme_constant_override(&"separation", 6)
	_pot.custom_minimum_size = Vector2(0, ICON)
	_pot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pot_row.add_child(_pot)
	_methods = HBoxContainer.new()
	_methods.add_theme_constant_override(&"separation", 6)
	col.add_child(_methods)
	_hunch = _label("", &"SatchelBody")
	_hunch.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_hunch)
	_brew = Button.new()
	_brew.theme_type_variation = &"SatchelSlot"
	_brew.text = "Brew"
	_brew.custom_minimum_size = Vector2(0, 44)
	_brew.pressed.connect(func() -> void: brew())
	col.add_child(_brew)

	_reveal = PanelContainer.new()
	_reveal.theme_type_variation = &"SatchelCard"
	_reveal.visible = false
	col.add_child(_reveal)
	var reveal_row := HBoxContainer.new()
	reveal_row.add_theme_constant_override(&"separation", 14)
	_reveal.add_child(reveal_row)
	_reveal_swatch = Panel.new()
	var round := StyleBoxFlat.new()
	round.set_corner_radius_all(20)
	round.border_color = Color(1, 1, 1, 0.85)
	round.set_border_width_all(3)
	_reveal_swatch.add_theme_stylebox_override(&"panel", round)
	_reveal_swatch.custom_minimum_size = Vector2(40, 40)
	_reveal_swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	reveal_row.add_child(_reveal_swatch)
	var reveal_text := VBoxContainer.new()
	reveal_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reveal_row.add_child(reveal_text)
	reveal_text.add_child(_label("A new brew", &"SatchelSmall"))
	_reveal_name = _label("", &"SatchelHeading")
	reveal_text.add_child(_reveal_name)
	_reveal_note = _label("", &"SatchelBody")
	_reveal_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reveal_text.add_child(_reveal_note)
	_outcome = _label("", &"SatchelBody")
	_outcome.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_outcome)

	col.add_child(_label("Made", &"SatchelSmall"))
	_dishes = VBoxContainer.new()
	_dishes.add_theme_constant_override(&"separation", 4)
	col.add_child(_dishes)
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override(&"separation", 22)
	col.add_child(footer)
	for p in [["E", "Brew"], ["Esc", "Step away"]]:
		var glyph := PanelContainer.new()
		glyph.theme_type_variation = &"SatchelKey"
		glyph.add_child(_label(p[0], &"SatchelKeyLabel"))
		footer.add_child(glyph)
		footer.add_child(_label(p[1], &"SatchelSmall"))


func _refresh() -> void:
	if station == null:
		return
	var data := station.station
	_title.text = data.display_name
	_found.text = "%d / %d brews" % [Gameplay.journal.brews.size(), BrewBook.rules().size()]
	for c in _grid.get_children():
		c.queue_free()
	var ids := _pantry()
	if ids.is_empty():
		_grid.add_child(_label("Nothing to brew with. Forage first.", &"SatchelSmall"))
	for id in ids:
		_grid.add_child(_tile(id))
	for c in _pot.get_children():
		c.queue_free()
	for id in chosen:
		var item := ItemCatalog.get_item(id)
		var pair := HBoxContainer.new()
		pair.add_theme_constant_override(&"separation", 4)
		pair.add_child(SatchelIcon.make({"id": id, "item": item}, ICON * 0.8))
		var named := _label(item.display_name, &"SatchelSmall")
		named.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pair.add_child(named)
		_pot.add_child(pair)
	for c in _methods.get_children():
		c.queue_free()
	var group := ButtonGroup.new()
	for m in data.methods:
		var b := Button.new()
		b.theme_type_variation = &"SatchelTab"
		b.text = String(m).capitalize()
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = m == method
		b.pressed.connect(set_method.bind(m))
		_methods.add_child(b)
	_hunch.text = hunch()
	_brew.disabled = chosen.is_empty()
	_refresh_dishes()


## Every ingredient she carries, pouch first.
func _pantry() -> Array[StringName]:
	var ids: Array[StringName] = []
	for container: StringName in [Inventory.POUCH, Inventory.SATCHEL]:
		for id: StringName in Gameplay.inventory.contents(container):
			if ItemCatalog.get_item(id) is IngredientData and not ids.has(id):
				ids.append(id)
	return ids


func _tile(id: StringName) -> Button:
	var item := ItemCatalog.get_item(id)
	var left := Gameplay.inventory.count(id) - chosen.count(id)
	var b := Button.new()
	b.theme_type_variation = &"SatchelSlot"
	b.custom_minimum_size = Vector2(ICON + 56.0, ICON + 18.0)
	b.toggle_mode = true
	b.button_pressed = chosen.has(id)
	var known := Gameplay.journal.known_tags(id)
	b.tooltip_text = "%s\n%s" % [item.display_name,
			", ".join(PackedStringArray(known)) if not known.is_empty() else "I haven't used this yet."]
	b.pressed.connect(func() -> void:
		if toggle(id):
			Juice.bounce_control(_pot, 0.08))
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 6
	row.offset_right = -6
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var icon := SatchelIcon.make({"id": id, "item": item}, ICON)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var count := _label("×%d" % maxi(left, 0), &"SatchelCount")
	count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(count)
	return b


func _refresh_dishes() -> void:
	for c in _dishes.get_children():
		c.queue_free()
	var inv := Gameplay.inventory
	if inv.dishes.is_empty():
		_dishes.add_child(_label("Nothing yet.", &"SatchelSmall"))
	for i in inv.dishes.size():
		var d: Dictionary = inv.dishes[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 10)
		var title := _label(String(d.get("name", "Dish")), &"SatchelBody")
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(title)
		row.add_child(_small_button("Eat" if StringName(d.get("kind", &"")) == &"food" else "Drink", eat.bind(i)))
		if float(d.get("food_days", 0.0)) > 0.0:
			row.add_child(_small_button("Give to family", give.bind(i)))
		_dishes.add_child(row)


## Feyre eats or drinks dish `i`; its effects run on her body (BodyState).
func eat(i: int) -> void:
	var dish := Gameplay.inventory.take_dish(i)
	if dish.is_empty():
		return
	if feyre and feyre.body_state:
		feyre.body_state.eat(dish)
	_outcome.text = "She takes it. %s" % describe(dish)
	_reveal.visible = false
	_refresh()


func give(i: int) -> void:
	var dish := Gameplay.inventory.take_dish(i)
	if dish.is_empty():
		return
	var days := Gameplay.food_tally.give_dish(dish)
	_outcome.text = "+%.1f days of food. The tally reads %.1f." % [days, Gameplay.food_tally.days_of_food]
	_reveal.visible = false
	_refresh()


func _show_result(r: Dictionary) -> void:
	var rule := BrewBook.get_rule(StringName(r.get("brew", &"")))
	if r.get("new_brew", false) and rule:
		_reveal.visible = true
		_reveal_name.text = String(r.name)
		_reveal_note.text = "“%s”" % rule.note
		(_reveal_swatch.get_theme_stylebox(&"panel") as StyleBoxFlat).bg_color = rule.color
		_outcome.text = describe(r)
		Juice.bounce_control(_reveal, 0.18)
		Juice.bounce_control(_found.get_parent() as Control, 0.25)
	else:
		_reveal.visible = false
		_outcome.text = "%s. %s" % [r.name, describe(r)]


static func describe(r: Dictionary) -> String:
	var parts := PackedStringArray()
	if float(r.get("hunger_relief", 0.0)) > 0.0:
		parts.append("fills %d%%" % roundi(float(r.hunger_relief) * 100.0))
	if float(r.get("heal", 0.0)) > 0.0:
		parts.append("mends")
	if float(r.get("harm", 0.0)) > 0.0:
		parts.append("bitter: it hurts")
	var effects: Dictionary = r.get("effects", {})
	for tag: Variant in effects:
		parts.append(String(SENSE.get(StringName(tag), String(tag))))
	if float(r.get("fae_toll", 0.0)) > 0.0:
		parts.append("the world tilts a little")
	if r.has("arrows"):
		parts.append("%d arrows coated" % int(r.arrows.count))
	if parts.is_empty():
		return ""
	var line := ", ".join(parts) + "."
	return line[0].to_upper() + line.substr(1)


func _small_button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.theme_type_variation = &"SatchelSlot"
	b.text = text
	b.pressed.connect(action)
	return b


func _label(text: String, variation: StringName) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = variation
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
