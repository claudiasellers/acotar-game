## The dressing room screen: Feyre stands in a gilded mirror on the left, the
## wardrobe hangs on the right. Pieces are grouped by garment (one card per
## gown, a row of colour swatches for its variants) and by category tab. Every
## change twirls her, sparkles and chimes while the game stays paused. Drag
## the mirror, Q/E or the arrows to turn her. Opened by DressingRoom.open().
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

var feyre: Feyre
var mirror_only: bool = false
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
		var key := p.mesh_path if p.mesh_path != "" else String(p.id)
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
	_tab_changed(tabs.current_tab)
	if _swatches.size() > 0:
		_swatches[0].grab_focus.call_deferred()


func _exit_tree() -> void:
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
	frame.border_color = UiStyle.BORDER
	frame.set_border_width_all(6)
	frame.set_corner_radius_all(220)
	frame.corner_detail = 16
	frame.shadow_color = Color(1.0, 0.85, 0.95, 0.55)
	frame.shadow_size = 18
	mirror.add_theme_stylebox_override(&"panel", frame)
	add_child(mirror)

	var hint := UiStyle.label("Drag, or Q / E, to turn", 15)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate.a = 0.75
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.anchor_right = 1.0 - PANEL_FRACTION
	hint.offset_top = -74
	hint.offset_bottom = -44
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint)

	var panel := PanelContainer.new()
	panel.name = "Wardrobe"
	panel.add_theme_stylebox_override(&"panel", UiStyle.panel_box())
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

	var title := UiStyle.label("The vanity" if mirror_only else "The dressing room", 30)
	title.add_theme_color_override(&"font_color", Color(0.62, 0.36, 0.52))
	box.add_child(title)
	wearing = UiStyle.label("", 15)
	wearing.modulate.a = 0.85
	box.add_child(wearing)

	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_style_tabs(tabs)
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
	for n in names:
		var here: Array[WardrobePiece] = owned.filter(func(p: WardrobePiece) -> bool: return category_of(p) == n)
		if not here.is_empty():
			tabs.add_child(_piece_tab(n, here))
	if not mirror_only:
		tabs.add_child(_hair_tab())
		tabs.add_child(_makeup_tab())

	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	box.add_child(row)
	var left := UiStyle.button("  ◀  ")
	left.pressed.connect(func() -> void: _turn(-PI / 4.0))
	row.add_child(left)
	var right := UiStyle.button("  ▶  ")
	right.pressed.connect(func() -> void: _turn(PI / 4.0))
	row.add_child(right)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var done := UiStyle.button("   Done   ")
	done.name = "Done"
	done.pressed.connect(func() -> void: DressingRoom.close_room(feyre))
	row.add_child(done)


## Ribbon tabs over a clear page, so the cards sit on the panel's blush.
func _style_tabs(t: TabContainer) -> void:
	var page := StyleBoxFlat.new()
	page.bg_color = Color(1.0, 0.97, 0.98, 0.6)
	page.set_corner_radius_all(14)
	page.set_content_margin_all(10)
	page.border_color = Color(UiStyle.BORDER, 0.35)
	page.set_border_width_all(1)
	t.add_theme_stylebox_override(&"panel", page)
	for state in ["tab_selected", "tab_unselected", "tab_hovered", "tab_focus"]:
		var tab := StyleBoxFlat.new()
		tab.set_corner_radius_all(12)
		tab.corner_radius_bottom_left = 0
		tab.corner_radius_bottom_right = 0
		tab.content_margin_left = 10
		tab.content_margin_right = 10
		tab.content_margin_top = 6
		tab.content_margin_bottom = 6
		match state:
			"tab_selected":
				tab.bg_color = UiStyle.ACCENT
				tab.border_color = UiStyle.BORDER
				tab.border_width_top = 2
			"tab_hovered", "tab_focus":
				tab.bg_color = Color(1.0, 0.86, 0.92)
			_:
				tab.bg_color = Color(1.0, 0.93, 0.96)
		if state == "tab_focus":
			tab.draw_center = false
			tab.border_color = UiStyle.BORDER
			tab.set_border_width_all(2)
		t.add_theme_stylebox_override(state, tab)
	t.add_theme_color_override(&"font_selected_color", Color.WHITE)
	t.add_theme_color_override(&"font_unselected_color", UiStyle.TEXT)
	t.add_theme_color_override(&"font_hovered_color", UiStyle.TEXT)
	t.add_theme_font_size_override(&"font_size", 15)


func _scroll(tab_name: String) -> Array:
	var scroll := ScrollContainer.new()
	scroll.name = tab_name
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override(&"separation", 8)
	scroll.add_child(col)
	return [scroll, col]


func _piece_tab(tab_name: String, pieces: Array[WardrobePiece]) -> Control:
	var parts := _scroll(tab_name)
	var col: VBoxContainer = parts[1]
	var slots: Array = []
	for p in pieces:
		for s in p.slots:
			if REMOVABLE.has(s) and not slots.has(s):
				slots.append(s)
	if not slots.is_empty():
		var off := UiStyle.button("Take it off")
		off.pressed.connect(func() -> void: take_off(slots))
		col.add_child(off)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override(&"h_separation", 8)
	grid.add_theme_constant_override(&"v_separation", 8)
	col.add_child(grid)
	for fam in families(pieces):
		grid.add_child(_card(fam))
	return parts[0]


## One garment: its name, a line of description, and a swatch per colour.
func _card(fam: Dictionary) -> Control:
	var variants: Array[WardrobePiece] = fam["pieces"]
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.set_meta(&"pieces", variants.map(func(p: WardrobePiece) -> StringName: return p.id))
	card.add_theme_stylebox_override(&"panel", _card_box(false))
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 4)
	card.add_child(col)
	col.add_child(UiStyle.label(fam["name"], 17))
	var about := UiStyle.label(variants[0].description, 12)
	about.modulate.a = 0.75
	about.custom_minimum_size = Vector2(0, 34)
	col.add_child(about)
	var swatches := HFlowContainer.new()
	swatches.add_theme_constant_override(&"h_separation", 6)
	swatches.add_theme_constant_override(&"v_separation", 6)
	col.add_child(swatches)
	for p in variants:
		var sw := _swatch_button(p.color, variant_name(p))
		sw.set_meta(&"piece", p.id)
		var id := p.id
		sw.pressed.connect(func() -> void: wear(id))
		swatches.add_child(sw)
		_swatches.append(sw)
	return card


func _swatch_button(color: Color, tip: String) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(34, 34)
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_ALL
	for state in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(state, _swatch_box(color, state != "normal", false))
	b.pressed.connect(func() -> void: Juice.bounce_control(b, 0.18))
	b.pivot_offset = Vector2(17, 17)
	return b


func _swatch_box(color: Color, hot: bool, worn: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(17)
	box.set_border_width_all(4 if worn else (3 if hot else 2))
	box.border_color = UiStyle.BORDER if worn else (Color(1, 1, 1) if hot else Color(1, 1, 1, 0.85))
	box.shadow_color = Color(0.6, 0.3, 0.5, 0.35) if not worn else Color(1.0, 0.85, 0.45, 0.8)
	box.shadow_size = 3 if not worn else 7
	box.anti_aliasing = true
	return box


func _card_box(worn: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(1, 1, 1, 0.92) if not worn else Color(1.0, 0.93, 0.96)
	box.set_corner_radius_all(16)
	box.set_content_margin_all(10)
	box.set_border_width_all(2 if not worn else 3)
	box.border_color = Color(UiStyle.BORDER, 0.45) if not worn else UiStyle.ACCENT
	return box


func _hair_tab() -> Control:
	var parts := _scroll("Hair")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	(parts[1] as VBoxContainer).add_child(grid)
	var styles := WardrobeCatalog.all_hair()
	styles.sort_custom(func(a: HairstyleData, b: HairstyleData) -> bool: return a.display_name < b.display_name)
	for h in styles:
		var b := UiStyle.button(h.display_name, true)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
		col.add_child(UiStyle.label(String(channel).replace("_", " ").capitalize(), 16))
		var row := HFlowContainer.new()
		row.add_theme_constant_override(&"h_separation", 6)
		row.add_theme_constant_override(&"v_separation", 6)
		col.add_child(row)
		var none := UiStyle.button("None")
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


## Worn swatches get a gold ring, their cards a rose border; the line under
## the title names the look.
func _refresh() -> void:
	var worn: Array = Gameplay.wardrobe.equipped().values()
	for sw in _swatches:
		if not is_instance_valid(sw):
			continue
		var on := worn.has(sw.get_meta(&"piece"))
		sw.add_theme_stylebox_override(&"normal", _swatch_box(_swatch_color(sw), false, on))
		var card := sw.get_parent().get_parent().get_parent() as PanelContainer
		if card:
			var any := false
			for id in card.get_meta(&"pieces"):
				any = any or worn.has(id)
			card.add_theme_stylebox_override(&"panel", _card_box(any))
	var mk := Gameplay.wardrobe.makeup()
	for b in find_children("*", "Button", true, false):
		if b.has_meta(&"hair"):
			(b as Button).set_pressed_no_signal(b.get_meta(&"hair") == Gameplay.wardrobe.hair)
		elif b.has_meta(&"makeup"):
			var m := WardrobeCatalog.makeup(b.get_meta(&"makeup"))
			var on: bool = mk.has(m.channel) and mk[m.channel]["id"] == m.id
			b.add_theme_stylebox_override(&"normal", _swatch_box(m.color, false, on))
	var names: Array[String] = []
	for p in Gameplay.wardrobe.worn_pieces():
		names.append(p.display_name)
	wearing.text = "Wearing: " + (", ".join(PackedStringArray(names)) if not names.is_empty() else "nothing much")


func _swatch_color(sw: Button) -> Color:
	var p := WardrobeCatalog.piece(sw.get_meta(&"piece"))
	return p.color if p else Color.WHITE


func _tab_changed(index: int) -> void:
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
