## The market sell screen (lane L53): Feyre steps up to a buyer and lays out
## what they would take, on the satchel's crafted look (L50: the deckled paper
## tag, stitched leather keys, enamel chips; SatchelTheme only, no colours
## here). One row per thing the buyer takes, with the coppers each; E sells
## one, R sells the lot, Esc steps away. Every sale chimes, sparkles at Feyre
## and bounces the purse. Selling goes through Inventory.sell, so the pelt's
## sale raises pelt_sold through PeltSale exactly as at the fur stall.
class_name MarketMenu
extends CanvasLayer

signal sold(item_id: StringName, count: int, coin: int)
signal closed

const WIDTH := 620.0
const ICON := 64.0

var buyer: MarketBuyer
var speaker: Node3D
var offers: Array[Dictionary] = []
var selected: int = 0

var _root: Control
var _card: PanelContainer
var _who: Label
var _says: Label
var _purse: Label
var _rows: VBoxContainer
var _prompts: HBoxContainer
var _buttons: Array[Button] = []


## Opens the screen for `buyer`, making one if the scene has none.
static func open_for(tree: SceneTree, for_buyer: MarketBuyer, who: Node3D = null) -> MarketMenu:
	if for_buyer == null:
		return null
	var found := tree.root.find_children("*", "MarketMenu", true, false)
	var menu: MarketMenu = found[0] as MarketMenu if found.size() > 0 else null
	if menu == null:
		menu = MarketMenu.new()
		(tree.current_scene if tree.current_scene else tree.root).add_child(menu)
	menu.open(for_buyer, who)
	return menu


func _init() -> void:
	name = "MarketMenu"


func _ready() -> void:
	layer = 19
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_root.visible = false


func is_open() -> bool:
	return _root != null and _root.visible


func open(for_buyer: MarketBuyer, who: Node3D = null) -> void:
	buyer = for_buyer
	speaker = who
	_root.theme = SatchelTheme.theme()
	_root.visible = true
	selected = 0
	_refresh()
	_says.text = "“%s”" % (buyer.greeting if not offers.is_empty() else buyer.nothing)
	_talk(true)
	if is_inside_tree():
		get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Juice.bounce_control(_card, 0.05)


func close() -> void:
	if not is_open():
		return
	_root.visible = false
	_talk(false)
	if is_inside_tree():
		get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	closed.emit()


## Sells `count` of the selected row (0 = all of it). Returns coppers earned.
func sell_selected(count: int = 1) -> int:
	if offers.is_empty():
		return 0
	var offer: Dictionary = offers[clampi(selected, 0, offers.size() - 1)]
	var inv := Gameplay.inventory
	var n: int = inv.count(offer.id) if count <= 0 else mini(count, inv.count(offer.id))
	var coin := inv.sell(offer.id, n, buyer.price_factor)
	if coin <= 0:
		return 0
	sold.emit(offer.id, n, coin)
	_says.text = "“%s”" % buyer.thanks
	_celebrate()
	_refresh()
	return coin


# --- input -------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if not is_open():
		return
	if event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel") \
			or _pad(event, JOY_BUTTON_B):
		close()
	elif _key(event, [KEY_E, KEY_ENTER, KEY_KP_ENTER]) or _pad(event, JOY_BUTTON_A):
		sell_selected(1)
	elif _key(event, [KEY_R]) or _pad(event, JOY_BUTTON_Y):
		sell_selected(0)
	elif event.is_action_pressed(&"ui_down") or event.is_action_pressed(&"move_back"):
		_move(1)
	elif event.is_action_pressed(&"ui_up") or event.is_action_pressed(&"move_forward"):
		_move(-1)
	else:
		return
	get_viewport().set_input_as_handled()


func _pad(event: InputEvent, button: JoyButton) -> bool:
	return event is InputEventJoypadButton and event.pressed and (event as InputEventJoypadButton).button_index == button


func _key(event: InputEvent, keys: Array) -> bool:
	return event is InputEventKey and event.pressed and not event.echo \
			and (event as InputEventKey).physical_keycode in keys


func _move(by: int) -> void:
	if offers.is_empty():
		return
	selected = wrapi(selected + by, 0, offers.size())
	_buttons[selected].grab_focus()


# --- build -------------------------------------------------------------------

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = SatchelTheme.theme()
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
	col.add_theme_constant_override(&"separation", 14)
	_card.add_child(col)

	var head := HBoxContainer.new()
	col.add_child(head)
	_who = _label("", &"SatchelHeading")
	_who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_who)
	var purse_chip := PanelContainer.new()
	purse_chip.theme_type_variation = &"SatchelChip"
	purse_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(purse_chip)
	_purse = _label("", &"SatchelCount")
	purse_chip.add_child(_purse)

	_says = _label("", &"SatchelBody")
	_says.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_says.custom_minimum_size = Vector2(WIDTH - 40.0, 0)
	col.add_child(_says)
	col.add_child(HSeparator.new())

	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override(&"separation", 8)
	col.add_child(_rows)

	_prompts = HBoxContainer.new()
	_prompts.add_theme_constant_override(&"separation", 22)
	_prompts.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(_prompts)


func _refresh() -> void:
	offers = buyer.offers(Gameplay.inventory) if buyer else []
	selected = clampi(selected, 0, maxi(offers.size() - 1, 0))
	_who.text = buyer.display_name.capitalize() if buyer else ""
	_purse.text = "%d coppers" % Gameplay.inventory.coin
	for c in _rows.get_children():
		c.queue_free()
	_buttons.clear()
	if offers.is_empty():
		var none := _label("Nothing in your satchel they'd buy.", &"SatchelSmall")
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_rows.add_child(none)
	for i in offers.size():
		_rows.add_child(_row(i, offers[i]))
	_build_prompts()
	if not _buttons.is_empty() and is_inside_tree():
		_buttons[selected].grab_focus.call_deferred()


func _row(i: int, offer: Dictionary) -> Button:
	var b := Button.new()
	b.theme_type_variation = &"SatchelSlot"
	b.custom_minimum_size = Vector2(0, ICON + 16.0)
	b.focus_entered.connect(func() -> void: selected = i)
	b.pressed.connect(func() -> void:
		selected = i
		sell_selected(1))
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 10
	row.offset_right = -14
	row.add_theme_constant_override(&"separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var icon := SatchelIcon.make(offer.entry, ICON)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var title := _label("%s  ×%d" % [offer.name, offer.count], &"SatchelBody")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(title)
	var price := _label("%d %s each" % [offer.price, "copper" if offer.price == 1 else "coppers"], &"SatchelCount")
	price.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(price)
	_buttons.append(b)
	return b


## Button glyphs, like the satchel's footer.
func _build_prompts() -> void:
	for c in _prompts.get_children():
		c.queue_free()
	var pad := SatchelHud.pad_active
	var pairs: Array = []
	if not offers.is_empty():
		pairs.append(["A" if pad else "E", "Sell one"])
		pairs.append(["Y" if pad else "R", "Sell all"])
	pairs.append(["B" if pad else "Esc", "Step away"])
	for p in pairs:
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 8)
		var glyph := PanelContainer.new()
		glyph.theme_type_variation = &"SatchelKey"
		var key := _label(p[0], &"SatchelKeyLabel")
		key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		glyph.add_child(key)
		row.add_child(glyph)
		var word := _label(p[1], &"SatchelSmall")
		word.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(word)
		_prompts.add_child(row)


func _label(text: String, variation: StringName) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = variation
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


# --- feedback ----------------------------------------------------------------

func _celebrate() -> void:
	var feyre := get_tree().get_first_node_in_group(&"player") if is_inside_tree() else null
	Juice.burst(feyre, &"craft")
	Juice.bounce_control(_purse.get_parent() as Control, 0.2)


func _talk(on: bool) -> void:
	if speaker and is_instance_valid(speaker) and speaker.has_method(&"set_talking"):
		speaker.call(&"set_talking", on)
