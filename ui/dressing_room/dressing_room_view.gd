## The dressing room screen: Feyre stands in a gilded mirror on the left, the
## wardrobe hangs on the right. Pieces are grouped by garment (one card per
## gown, a row of colour swatches for its variants) and by category tab. Every
## change twirls her, sparkles and chimes while the game stays paused. Drag
## the mirror, Q/E or the arrows to turn her. Opened by DressingRoom.open().
## L64: pieces she hasn't seen yet wear a "New" ribbon and arrive with one
## sparkle; the header counts the collection; from the satchel only the small
## things she carries show (SATCHEL_TABS), never a gown.
class_name DressingRoomView
extends Control

const PANEL_FRACTION := 0.42
## Full-body framing (metres of height visible above and below her middle) and
## the vanity close-up on her face.
const BODY_HALF_HEIGHT := 1.12
const BODY_LOOK_Y := 0.92
const FACE_HALF_HEIGHT := 0.46
const FACE_LOOK_Y := 1.46
const CAMERA_DISTANCE := 3.2
const TURN_SPEED := 2.4
const TWIRL_SECONDS := 0.7

## Tab name -> slots that file a piece under it. Gowns fill top and bottom.
const CATEGORIES: Array[Dictionary] = [
	{"name": "Gowns", "slots": []},
	{"name": "Tops", "slots": [&"top", &"bottom"]},
	{"name": "Cloaks", "slots": [&"outer"]},
	{"name": "Shoes", "slots": [&"feet", &"legs_wear"]},
	{"name": "Crowns", "slots": [&"head"]},
	{"name": "Jewellery", "slots": [&"neck", &"ears", &"wrist", &"hands"]},
	{"name": "Masks", "slots": [&"mask"]},
]
## Slots a piece can simply come off from (a gown or tunic can't).
const REMOVABLE: Array[StringName] = [&"outer", &"head", &"neck", &"mask", &"ears", &"wrist", &"hands", &"legs_wear"]
## Tab -> how close the mirror comes: 1 = her face, 0 = full length.
const CLOSE_UPS := {"Hair": 1.0, "Makeup": 1.0, "Crowns": 0.7, "Jewellery": 0.55, "Masks": 0.8}
## What she can change from her satchel, out in the world.
const SATCHEL_TABS: Array[String] = ["Cloaks", "Crowns", "Jewellery", "Masks", "Hair"]
## The gilt of the mirror's frame (the dressing room's own; the panel is the satchel's).
const GILT := Color(0.83, 0.68, 0.38)
const COLUMNS := 3
const THUMB := 104.0
const SWATCH := 30.0

var feyre: Feyre
var mirror_only: bool = false
var from_satchel: bool = false
## Pieces showing that were New when the screen opened; seen when it closes.
var arrivals: Array[StringName] = []
var arrivals_label: Label
var found_label: Label
## The garment and colour in focus, under the tabs.
var about: Label
var _tab_row: HFlowContainer
var camera: Camera3D
var tabs: TabContainer
var wearing: Label

var _start_yaw: float = 0.0
var _yaw: float = 0.0
var _dragging: bool = false
var _twirl: Tween
var _frame_tween: Tween
var _face: float = 0.0
var _swatches: Array[Button] = []
var _hidden_layers: Array[CanvasLayer] = []
var _model_mode: ProcessMode = PROCESS_MODE_INHERIT


## The tab a piece is filed under.
static func category_of(p: WardrobePiece) -> String:
	if p.slots.has(&"top") and p.slots.has(&"bottom"):
		return "Gowns"
	for c in CATEGORIES:
		for s in p.slots:
			if (c["slots"] as Array).has(s):
				return c["name"]
	return "Jewellery"


## Pieces grouped by garment: variants share a mesh, so each mesh is one card.
## Returns [{"name", "pieces": Array[WardrobePiece]}] in a stable order.
static func families(pieces: Array[WardrobePiece]) -> Array[Dictionary]:
	var by_key: Dictionary = {}
	var order: Array[String] = []
	for p in pieces:
		# Same mesh and same garment name: Elain's ribbon is its own card.
		var key := (p.mesh_path if p.mesh_path != "" else String(p.id)) + "|" + family_name(p)
		if not by_key.has(key):
			by_key[key] = {"name": family_name(p), "pieces": [] as Array[WardrobePiece]}
			order.append(key)
		(by_key[key]["pieces"] as Array[WardrobePiece]).append(p)
	var out: Array[Dictionary] = []
	for key in order:
		out.append(by_key[key])
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["name"] < b["name"])
	return out


## "Ball gown (rose)" -> "Ball gown".
static func family_name(p: WardrobePiece) -> String:
	var n := p.display_name
	var cut := n.find(" (")
	return n.substr(0, cut) if cut > 0 else n


## The colour in a variant's name, or its whole name: "Ball gown (rose)" -> "Rose".
static func variant_name(p: WardrobePiece) -> String:
	var n := p.display_name
	var cut := n.find(" (")
	return n.substr(cut + 2).trim_suffix(")").capitalize() if cut > 0 else n


func setup(who: Feyre, station_id: StringName) -> void:
	feyre = who
	mirror_only = station_id == &"dressing_mirror"
	from_satchel = station_id == DressingRoom.SATCHEL
	name = "DressingRoomView"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_face_the_room(station_id)
	_build()


func _ready() -> void:
	_hide_hud()
	_enter_camera()
	_model_mode = feyre.model.process_mode
	# Her idle breath and the twirl keep playing while the world is paused.
	feyre.model.process_mode = Node.PROCESS_MODE_ALWAYS
	Gameplay.wardrobe.changed.connect(_refresh)
	_refresh()
	_open_on_arrivals()
	_tab_changed(tabs.current_tab)
	if _swatches.size() > 0:
		_swatches[0].grab_focus.call_deferred()


func _exit_tree() -> void:
	Gameplay.wardrobe.mark_seen(arrivals)
	if Gameplay.wardrobe.changed.is_connected(_refresh):
		Gameplay.wardrobe.changed.disconnect(_refresh)
	if is_instance_valid(feyre) and is_instance_valid(feyre.model):
		feyre.model.process_mode = _model_mode
		feyre.model.rotation.y = _start_yaw
		feyre.model.scale = Vector3.ONE
	if camera and is_instance_valid(camera):
		camera.queue_free()
	for layer in _hidden_layers:
		if is_instance_valid(layer):
			layer.visible = true


func _process(delta: float) -> void:
	var turn := Input.get_axis(&"dress_turn_left", &"dress_turn_right") if InputMap.has_action(&"dress_turn_left") else 0.0
	if Input.is_physical_key_pressed(KEY_Q):
		turn -= 1.0
	if Input.is_physical_key_pressed(KEY_E):
		turn += 1.0
	if turn != 0.0:
		_turn(turn * TURN_SPEED * delta)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
	elif event is InputEventMouseMotion and _dragging:
		_turn(event.relative.x * 0.012)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		DressingRoom.close_room(feyre)


## Equip a variant: twirl, sparkle, chime.
func wear(piece_id: StringName) -> void:
	if Gameplay.wardrobe.equipped_in(WardrobeCatalog.piece(piece_id).slots[0]) == piece_id:
		_celebrate()
		return
	if Gameplay.wardrobe.equip(piece_id):
		_shed_the_cottage(WardrobeCatalog.piece(piece_id))
		_celebrate()


## A gown or court piece comes off the hanger and the patched cottage cloak
## comes off her shoulders: no one wants it over tulle.
func _shed_the_cottage(p: WardrobePiece) -> void:
	if p == null or p.source == &"cottage_chest" or not p.slots.has(&"top"):
		return
	var cloak := WardrobeCatalog.piece(Gameplay.wardrobe.equipped_in(&"outer"))
	if cloak and cloak.source == &"cottage_chest":
		Gameplay.wardrobe.unequip_slot(&"outer")
	# Old boots under a gown become the slippers nearest its colour.
	var boots := WardrobeCatalog.piece(Gameplay.wardrobe.equipped_in(&"feet"))
	if not p.slots.has(&"bottom") or boots == null or boots.source != &"cottage_chest":
		return
	var best: WardrobePiece = null
	for id in Gameplay.wardrobe.owned_pieces():
		var shoe := WardrobeCatalog.piece(id)
		if shoe and shoe.slots.has(&"feet") and shoe.source == &"manor_wardrobe":
			if best == null or _colour_gap(shoe.color, p.color) < _colour_gap(best.color, p.color):
				best = shoe
	if best:
		Gameplay.wardrobe.equip(best.id)


static func _colour_gap(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()


func is_twirling() -> bool:
	return _twirl != null and _twirl.is_running()


func take_off(slots: Array) -> void:
	for s: StringName in slots:
		if REMOVABLE.has(s):
			Gameplay.wardrobe.unequip_slot(s)
	_celebrate(false)


func _celebrate(twirl: bool = true) -> void:
	Juice.burst(feyre.model, &"outfit")
	if not twirl:
		return
	if _twirl and _twirl.is_valid():
		_twirl.kill()
	_twirl = feyre.model.create_tween()
	_twirl.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	var from := _yaw
	_twirl.tween_method(func(a: float) -> void: feyre.model.rotation.y = a, from, from + TAU, TWIRL_SECONDS) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_twirl.tween_callback(func() -> void: feyre.model.rotation.y = _yaw)


func _turn(amount: float) -> void:
	if _twirl and _twirl.is_running():
		return
	_yaw = wrapf(_yaw + amount, -PI, PI)
	feyre.model.rotation.y = _yaw


## She turns her back on the wardrobe or mirror she walked up to, so the
## mirror's view is of her with the room behind.
func _face_the_room(station_id: StringName) -> void:
	_start_yaw = feyre.model.rotation.y
	_yaw = _start_yaw
	var best: Node3D = null
	for s in feyre.get_tree().get_nodes_in_group(&"station"):
		if s is Node3D and s.get(&"station_id") == station_id:
			if best == null or s.global_position.distance_to(feyre.global_position) < best.global_position.distance_to(feyre.global_position):
				best = s
	if best == null or best.global_position.distance_to(feyre.global_position) > 6.0:
		return
	var away := feyre.global_position - best.global_position
	away.y = 0.0
	if away.length() < 0.05:
		return
	# The model looks down its -Z.
	var world_yaw := atan2(-away.x, -away.z)
	_yaw = world_yaw - feyre.global_rotation.y
	feyre.model.rotation.y = _yaw


func _build() -> void:
	# L64-3: the satchel's handmade look (SatchelTheme, L50): paper, stitched
	# tabs and slots, the serif. The gilt mirror stays the dressing room's own.
	theme = SatchelTheme.theme()
	var mirror := Panel.new()
	mirror.name = "MirrorFrame"
	mirror.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mirror.anchor_right = 1.0 - PANEL_FRACTION
	mirror.anchor_bottom = 1.0
	mirror.offset_left = 28
	mirror.offset_top = 28
	mirror.offset_right = -18
	mirror.offset_bottom = -28
	var frame := StyleBoxFlat.new()
	frame.draw_center = false
	frame.border_color = GILT
	frame.set_border_width_all(6)
	frame.set_corner_radius_all(220)
	frame.corner_detail = 16
	frame.shadow_color = Color(1.0, 0.85, 0.95, 0.55)
	frame.shadow_size = 18
	mirror.add_theme_stylebox_override(&"panel", frame)
	add_child(mirror)

	var panel := PanelContainer.new()
	panel.name = "Wardrobe"
	panel.theme_type_variation = &"SatchelDetail"
	panel.anchor_left = 1.0 - PANEL_FRACTION
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 0
	panel.offset_top = 28
	panel.offset_right = -28
	panel.offset_bottom = -28
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 10)
	panel.add_child(box)

	var head := HBoxContainer.new()
	var title := _label("Her satchel" if from_satchel else ("The vanity" if mirror_only else "The dressing room"), &"SatchelHeading")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var chip := PanelContainer.new()
	chip.theme_type_variation = &"SatchelChip"
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	found_label = _label(found_text(), &"SatchelCount")
	found_label.name = "Found"
	chip.add_child(found_label)
	head.add_child(chip)
	box.add_child(head)
	arrivals_label = _label("", &"SatchelBody")
	arrivals_label.name = "Arrivals"
	arrivals_label.add_theme_color_override(&"font_color", SatchelTheme.color(&"accent"))
	arrivals_label.visible = false
	box.add_child(arrivals_label)
	wearing = _label("", &"SatchelSmall")
	wearing.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(wearing)

	# Stitched leather tabs drive a page stack (the TabContainer keeps its API).
	_tab_row = HFlowContainer.new()
	_tab_row.add_theme_constant_override(&"h_separation", 6)
	_tab_row.add_theme_constant_override(&"v_separation", 6)
	box.add_child(_tab_row)
	about = _label("", &"SatchelSmall")
	about.name = "About"
	about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	about.custom_minimum_size = Vector2(0, 40)
	box.add_child(about)
	tabs = TabContainer.new()
	tabs.tabs_visible = false
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_theme_stylebox_override(&"panel", StyleBoxEmpty.new())
	tabs.tab_changed.connect(_tab_changed)
	box.add_child(tabs)
	var owned: Array[WardrobePiece] = []
	for id in Gameplay.wardrobe.owned_pieces():
		var p := WardrobeCatalog.piece(id)
		if p:
			owned.append(p)
	var names: Array[String] = []
	for c in CATEGORIES:
		names.append(c["name"])
	if mirror_only:
		tabs.add_child(_hair_tab())
		tabs.add_child(_makeup_tab())
		names = ["Crowns", "Jewellery", "Masks"]
	elif from_satchel:
		names = SATCHEL_TABS.filter(func(n: String) -> bool: return n != "Hair")
	for n in names:
		var here: Array[WardrobePiece] = owned.filter(func(p: WardrobePiece) -> bool: return category_of(p) == n)
		if not here.is_empty():
			tabs.add_child(_piece_tab(n, here))
			for p in here:
				if Gameplay.wardrobe.is_unseen(p.id):
					arrivals.append(p.id)
	if from_satchel:
		tabs.add_child(_hair_tab())
	elif not mirror_only:
		tabs.add_child(_hair_tab())
		tabs.add_child(_makeup_tab())
	for i in tabs.get_tab_count():
		var t := Button.new()
		t.text = String(tabs.get_tab_control(i).name)
		t.theme_type_variation = &"SatchelTab"
		t.toggle_mode = true
		t.focus_mode = Control.FOCUS_NONE
		var index := i
		t.pressed.connect(func() -> void: tabs.current_tab = index)
		_tab_row.add_child(t)

	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 18)
	box.add_child(row)
	row.add_child(_key_hint("Q  E", "Turn"))
	row.add_child(_key_hint("Esc", "Done"))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var done := Button.new()
	done.name = "Done"
	done.text = "Done"
	done.theme_type_variation = &"SatchelTab"
	done.pressed.connect(func() -> void: DressingRoom.close_room(feyre))
	row.add_child(done)


func _label(text: String, variation: StringName) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = variation
	return l


## A leather key glyph and its word, like the satchel's footer.
func _key_hint(key: String, word: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	var glyph := PanelContainer.new()
	glyph.theme_type_variation = &"SatchelKey"
	var k := _label(key, &"SatchelKeyLabel")
	k.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph.add_child(k)
	row.add_child(glyph)
	var w := _label(word, &"SatchelSmall")
	w.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(w)
	return row


func _scroll(tab_name: String) -> Array:
	var scroll := ScrollContainer.new()
	scroll.name = tab_name
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override(&"separation", 8)
	scroll.add_child(col)
	return [scroll, col]


func _grid(col: VBoxContainer) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override(&"h_separation", 8)
	grid.add_theme_constant_override(&"v_separation", 8)
	col.add_child(grid)
	return grid


func _piece_tab(tab_name: String, pieces: Array[WardrobePiece]) -> Control:
	var parts := _scroll(tab_name)
	var col: VBoxContainer = parts[1]
	var slots: Array = []
	for p in pieces:
		for s in p.slots:
			if REMOVABLE.has(s) and not slots.has(s):
				slots.append(s)
	if not slots.is_empty():
		var off := Button.new()
		off.text = "Take it off"
		off.theme_type_variation = &"SatchelSlot"
		off.pressed.connect(func() -> void: take_off(slots))
		col.add_child(off)
	var grid := _grid(col)
	for fam in families(pieces):
		grid.add_child(_card(fam))
	return parts[0]


## One garment: its rendered thumbnail (New pinned on it while unseen), its
## name, and a stitched swatch per colour. The thumbnail shows the colour
## worn, or the first.
func _card(fam: Dictionary) -> Control:
	var variants: Array[WardrobePiece] = fam["pieces"]
	var card := PanelContainer.new()
	card.theme_type_variation = &"SatchelCard"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.set_meta(&"pieces", variants.map(func(p: WardrobePiece) -> StringName: return p.id))
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 4)
	card.add_child(col)
	var pic := Control.new()
	pic.custom_minimum_size = Vector2(0, THUMB)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(pic)
	var thumb := WardrobeIcon.make(variants[0], THUMB)
	thumb.name = "Thumb"
	thumb.set_anchors_preset(Control.PRESET_FULL_RECT)
	pic.add_child(thumb)
	card.set_meta(&"thumb", thumb)
	if variants.any(func(p: WardrobePiece) -> bool: return Gameplay.wardrobe.is_unseen(p.id)):
		var pill := _new_ribbon()
		pill.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		pill.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		pic.add_child(pill)
	var name_label := _label(fam["name"], &"SatchelSmall")
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(name_label)
	var swatches := HFlowContainer.new()
	swatches.alignment = FlowContainer.ALIGNMENT_CENTER
	swatches.add_theme_constant_override(&"h_separation", 4)
	swatches.add_theme_constant_override(&"v_separation", 4)
	col.add_child(swatches)
	for p in variants:
		var sw := _swatch_button(p.color, variant_name(p))
		sw.set_meta(&"piece", p.id)
		sw.set_meta(&"card", card)
		var piece := p
		sw.pressed.connect(func() -> void: wear(piece.id))
		sw.focus_entered.connect(func() -> void: _show(piece, card))
		sw.mouse_entered.connect(func() -> void: _show(piece, card))
		swatches.add_child(sw)
		_swatches.append(sw)
	return card


## The line under the tabs names the garment and colour in focus, and its card
## shows that colour.
func _show(p: WardrobePiece, card: Control) -> void:
	about.text = ("%s. %s" % [p.display_name, p.description]).strip_edges() if p.description != "" else p.display_name
	var thumb := card.get_meta(&"thumb") as Control
	if thumb:
		WardrobeIcon.show_piece(thumb, p)


## The "New" pin on a card she hasn't looked at yet; it bounces in.
func _new_ribbon() -> Control:
	var pill := PanelContainer.new()
	pill.name = "NewRibbon"
	pill.theme_type_variation = &"SatchelChip"
	var word := _label("New", &"SatchelPin")
	word.add_theme_color_override(&"font_color", SatchelTheme.color(&"accent"))
	pill.add_child(word)
	pill.ready.connect(func() -> void:
		pill.pivot_offset = pill.size * 0.5
		Juice.bounce_control(pill, 0.3))
	return pill


## "34 of 170 found", the collection page's own count for the wardrobe.
static func found_text() -> String:
	var got := Gameplay.wardrobe.owned_pieces().size()
	var total := WardrobeCatalog.all_pieces().size()
	if Gameplay.collection:
		var p := Gameplay.collection.progress(&"wardrobe")
		got = p.x
		total = p.y
	return "%d of %d found" % [got, total]


## New pieces: open on the first tab holding one, say what came, and give
## the arrival its one sparkle and chime.
func _open_on_arrivals() -> void:
	if arrivals.is_empty():
		return
	arrivals_label.text = WardrobeStock.arrivals_line(arrivals)
	arrivals_label.visible = true
	var first := WardrobeCatalog.piece(arrivals[0])
	for i in tabs.get_tab_count():
		if first and String(tabs.get_tab_control(i).name) == category_of(first):
			tabs.current_tab = i
			break
	Juice.burst(feyre.model, &"outfit")


## A small stitched slot holding an enamel dot of the colour; pressed while worn.
func _swatch_button(color: Color, tip: String) -> Button:
	var b := Button.new()
	b.theme_type_variation = &"SatchelSlot"
	b.custom_minimum_size = Vector2(SWATCH, SWATCH)
	b.tooltip_text = tip
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_ALL
	var dot := Panel.new()
	dot.name = "Dot"
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.set_anchors_preset(Control.PRESET_FULL_RECT)
	dot.offset_left = 6
	dot.offset_top = 6
	dot.offset_right = -6
	dot.offset_bottom = -6
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(SWATCH)
	fill.border_color = Color(SatchelTheme.color(&"ink"), 0.35)
	fill.set_border_width_all(1)
	fill.anti_aliasing = true
	dot.add_theme_stylebox_override(&"panel", fill)
	b.add_child(dot)
	b.pressed.connect(func() -> void:
		b.pivot_offset = b.size * 0.5
		Juice.bounce_control(b, 0.18))
	return b


func _hair_tab() -> Control:
	var parts := _scroll("Hair")
	var grid := _grid(parts[1] as VBoxContainer)
	var styles := WardrobeCatalog.available_hair()
	styles.sort_custom(func(a: HairstyleData, b: HairstyleData) -> bool: return a.display_name < b.display_name)
	for h in styles:
		var b := Button.new()
		b.text = h.display_name
		b.theme_type_variation = &"SatchelSlot"
		b.toggle_mode = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 44)
		b.clip_text = true
		b.set_meta(&"hair", h.id)
		var id := h.id
		b.pressed.connect(func() -> void:
			if Gameplay.wardrobe.set_hair(id):
				_celebrate(false))
		grid.add_child(b)
	return parts[0]


func _makeup_tab() -> Control:
	var parts := _scroll("Makeup")
	var col: VBoxContainer = parts[1]
	for channel in MakeupData.CHANNELS:
		col.add_child(_label(String(channel).replace("_", " ").capitalize(), &"SatchelBody"))
		var row := HFlowContainer.new()
		row.add_theme_constant_override(&"h_separation", 4)
		row.add_theme_constant_override(&"v_separation", 4)
		col.add_child(row)
		var none := Button.new()
		none.text = "None"
		none.theme_type_variation = &"SatchelSlot"
		var ch := channel
		none.pressed.connect(func() -> void: Gameplay.wardrobe.clear_makeup(ch))
		row.add_child(none)
		for m in WardrobeCatalog.all_makeup():
			if m.channel != channel:
				continue
			var sw := _swatch_button(m.color, m.display_name)
			sw.set_meta(&"makeup", m.id)
			var id := m.id
			sw.pressed.connect(func() -> void:
				if Gameplay.wardrobe.apply_makeup(id):
					_celebrate(false))
			row.add_child(sw)
	return parts[0]


## Worn swatches, hairstyles and makeup stay pressed; each card shows the
## colour she wears; the line under the title names the look.
func _refresh() -> void:
	var worn: Array = Gameplay.wardrobe.equipped().values()
	for sw in _swatches:
		if not is_instance_valid(sw):
			continue
		var on := worn.has(sw.get_meta(&"piece"))
		sw.set_pressed_no_signal(on)
		if on:
			var thumb := (sw.get_meta(&"card") as Control).get_meta(&"thumb") as Control
			WardrobeIcon.show_piece(thumb, WardrobeCatalog.piece(sw.get_meta(&"piece")))
	var mk := Gameplay.wardrobe.makeup()
	for b in find_children("*", "Button", true, false):
		if b.has_meta(&"hair"):
			(b as Button).set_pressed_no_signal(b.get_meta(&"hair") == Gameplay.wardrobe.hair)
		elif b.has_meta(&"makeup"):
			var m := WardrobeCatalog.makeup(b.get_meta(&"makeup"))
			(b as Button).set_pressed_no_signal(mk.has(m.channel) and mk[m.channel]["id"] == m.id)
	var names: Array[String] = []
	for p in Gameplay.wardrobe.worn_pieces():
		names.append(p.display_name)
	wearing.text = "Wearing: " + (", ".join(PackedStringArray(names)) if not names.is_empty() else "nothing much")


func _tab_changed(index: int) -> void:
	for i in _tab_row.get_child_count():
		(_tab_row.get_child(i) as Button).set_pressed_no_signal(i == index)
	var tab := tabs.get_tab_control(index)
	var face: float = CLOSE_UPS.get(String(tab.name), 0.0) if tab else 0.0
	if _frame_tween and _frame_tween.is_valid():
		_frame_tween.kill()
	_frame_tween = create_tween()
	_frame_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_frame_tween.tween_method(_frame, _face, face, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## The mirror's camera, framing her in the gilded oval on the left.
func _enter_camera() -> void:
	camera = Camera3D.new()
	camera.name = "VanityCamera"
	camera.process_mode = Node.PROCESS_MODE_ALWAYS
	camera.near = 0.05
	feyre.get_parent().add_child(camera)
	_frame(0.0)
	camera.current = true


## 0 = full length, 1 = her face. The camera stands in front of where she
## faces, pulled in if a wall is closer, and shifted so she sits in the mirror.
func _frame(face: float) -> void:
	_face = face
	if camera == null or not is_instance_valid(camera):
		return
	var half := lerpf(BODY_HALF_HEIGHT, FACE_HALF_HEIGHT, face)
	var look_y := lerpf(BODY_LOOK_Y, FACE_LOOK_Y, face)
	var dir := Basis(Vector3.UP, feyre.global_rotation.y + _yaw) * Vector3.FORWARD
	dir.y = 0.0
	dir = dir.normalized()
	var target := feyre.global_position + Vector3.UP * look_y
	var dist := lerpf(CAMERA_DISTANCE, 1.1, face)
	var hit := feyre.get_world_3d().direct_space_state.intersect_ray(
			PhysicsRayQueryParameters3D.create(target, target + dir * (dist + 0.3), 1, [feyre.get_rid()]))
	if not hit.is_empty():
		dist = maxf(0.6, target.distance_to(hit["position"]) - 0.3)
	camera.fov = rad_to_deg(2.0 * atan(half / dist))
	var view := get_viewport_rect().size if is_inside_tree() else Vector2(16, 9)
	var aspect := view.x / maxf(view.y, 1.0)
	# Centre her in the mirror (the left part of the screen), not the screen.
	var mirror_centre := (1.0 - PANEL_FRACTION) * 0.5
	camera.h_offset = (0.5 - mirror_centre) * 2.0 * half * aspect
	camera.look_at_from_position(target + dir * dist, target)


func _hide_hud() -> void:
	for layer in get_tree().root.find_children("*", "CanvasLayer", true, false):
		var l := layer as CanvasLayer
		if l.visible and l.layer < 20 and not l.is_ancestor_of(self):
			l.visible = false
			_hidden_layers.append(l)
