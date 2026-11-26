## Tending the white mare (docs/contracts/mare_bond.md; the screen is the UI
## lane's, redrawn 2026-11-26 on the owner's word that it "needs A LOT of
## work"): T (her own key) beside her and the camera draws round to her side,
## the side Feyre is not standing on. On the left, her: stroke her coat with
## the brush (hold the mouse, or A and the stick) and it comes up gleaming,
## with sparkles and a soft rising chime where the brush passes. On the
## right, a loose page of the journal: her coat and her bond as the same
## meters the Bonds page draws, then two rows of picture tabs, Care (brush
## and treats, her own page) and Dress her (one tab per MareTack slot). Treats
## are the satchel's own pictures; a dress-up piece shows its colours as
## enamel swatches and what making it takes as pictures. Every change
## sparkles, chimes and makes her toss her head (R3). The world keeps
## turning; Feyre stands by her. Esc, T, E or Done to leave.
class_name MareTendingView
extends Control

signal closed

const PANEL_FRACTION := 0.42
const CAMERA_OUT := 5.2
const CAMERA_AHEAD := 1.3
const CAMERA_UP := 1.55
## How far toward the page the camera aims past her (m), so she stands in
## the open part of the frame.
const CAMERA_SHIFT := 1.25
const CARD_W := 214.0
## Pad brushing: stick travel per second while A is held, in screen widths.
const PAD_BRUSH := 1.6
## The tabs that are not a dress-up slot: brush and treats, and her page
## (MarePage: what Feyre knows of her, what to try, what she remembers).
const CARE := &"care"
const HER := &"her"
const TAB_NAMES := {CARE: "Brush and treats", HER: "Her"}
## A tab: its picture over its name.
const TAB_SIZE := Vector2(104, 84)
const TAB_ICON := 40.0
## A treat from the satchel, a colour swatch on a piece, and a making's picture.
const TREAT_ICON := 52.0
const SWATCH := 26.0
const NEED_ICON := 24.0
## How faint a treat she likes but Feyre has none of.
const WISHED_ALPHA := 0.45
## The brush under the pointer, and the chime as it strokes: how often, how
## quiet, and how far its pitch climbs as her coat comes up.
const BRUSH_SIZE := 64.0
const CHIME_GAP := 0.42
const CHIME_DB := -20.0
const CHIME_PITCH := Vector2(0.9, 1.5)
## The lilac wash.
const WASH := 1

var mare: MareMount
var feyre: Node3D
var inventory: Inventory
var camera: Camera3D
var _prev_camera: Camera3D
var _tab: StringName = CARE
var _tabs: Dictionary = {}  # tab id -> Button
var _body: VBoxContainer
var _meters: VBoxContainer
var _coat: HBoxContainer
var _brushing: bool = false
var _brush_at: Vector2 = Vector2.ZERO
var _sparkles: CPUParticles2D
var _chime: AudioStreamPlayer
var _since_stroke: float = 99.0
var _since_chime: float = 99.0
var _last_applied: float = -1.0


## Opens the screen over `parent` for `mare`. Feyre stands still while it's open.
static func open(parent: Node, p_mare: MareMount, p_feyre: Node3D, p_inventory: Inventory) -> MareTendingView:
	var layer := CanvasLayer.new()
	layer.name = "MareTending"
	parent.add_child(layer)
	var v := MareTendingView.new()
	v.mare = p_mare
	v.feyre = p_feyre
	v.inventory = p_inventory
	layer.add_child(v)
	return v


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_frame_camera()
	if feyre:
		feyre.set_physics_process(false)
		if feyre is CharacterBody3D:
			(feyre as CharacterBody3D).velocity = Vector3.ZERO
	# The mare keeps moving under the brush, so the game is not paused.
	ScreenStack.push(self, ScreenStack.Flag.MOUSE)
	var layer := get_parent() as CanvasLayer
	if layer:
		layer.layer = ScreenStack.layer_of(self)
	_build()
	_sparkles = _make_sparkles()
	add_child(_sparkles)
	_chime = AudioStreamPlayer.new()
	_chime.stream = Juice.chime(&"pickup")
	_chime.volume_db = CHIME_DB
	add_child(_chime)
	_show(_tab)


## Esc or B while the tending screen is the top screen.
func screen_cancel() -> void:
	close()


## The open tab takes the focus, so a pad starts on it.
func screen_focus() -> void:
	if _tabs.has(_tab):
		(_tabs[_tab] as Button).grab_focus()


func close() -> void:
	ScreenStack.pop(self)
	if camera and is_instance_valid(camera):
		camera.current = false
		camera.queue_free()
	if _prev_camera and is_instance_valid(_prev_camera):
		_prev_camera.current = true
	if feyre and is_instance_valid(feyre):
		feyre.set_physics_process(true)
	closed.emit()
	var layer := get_parent()
	if layer is CanvasLayer:
		layer.queue_free()
	else:
		queue_free()


# ------------------------------------------------------------------ camera

## From her side, the one Feyre is not on, so Feyre never stands between the
## camera and the mare; she is framed in the part of the screen the page leaves.
func _frame_camera() -> void:
	if mare == null:
		return
	_prev_camera = get_viewport().get_camera_3d()
	camera = Camera3D.new()
	camera.name = "MareTendingCamera"
	camera.fov = 42.0
	mare.get_parent().add_child(camera)
	var side := -mare.global_basis.x
	if feyre and (feyre.global_position - mare.global_position).dot(side) > 0.0:
		side = -side
	var fwd := -mare.global_basis.z
	var at := mare.global_position + Vector3.UP * 1.25
	var from := mare.global_position + side * CAMERA_OUT + fwd * CAMERA_AHEAD + Vector3.UP * CAMERA_UP
	var right_of_view := (at - from).cross(Vector3.UP).normalized()
	camera.look_at_from_position(from, at + fwd * 0.4 + right_of_view * CAMERA_SHIFT)
	camera.current = true


# ------------------------------------------------------------------ layout

func _build() -> void:
	var panel := LoosePage.paper()
	panel.anchor_left = 1.0 - PANEL_FRACTION
	panel.anchor_right = 1.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 8
	panel.offset_right = -18
	panel.offset_top = 18
	panel.offset_bottom = -18
	add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 8)
	panel.add_child(col)
	col.add_child(LoosePage.heading("Tending her", WASH))
	_meters = VBoxContainer.new()
	_meters.add_theme_constant_override(&"separation", 3)
	col.add_child(_meters)
	col.add_child(BookKit.section("Care"))
	col.add_child(_tab_row([CARE, HER]))
	col.add_child(BookKit.section("Dress her"))
	col.add_child(_tab_row(MareTack.SLOTS))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override(&"separation", 8)
	scroll.add_child(_body)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override(&"separation", 12)
	col.add_child(foot)
	foot.alignment = BoxContainer.ALIGNMENT_END
	foot.add_child(BookKit.key_hint(KeyPrompt.key(MountDirector.TEND_ACTION), ""))
	var done := LoosePage.button("Done")
	done.pressed.connect(close)
	foot.add_child(done)


static func tab_name(tab: StringName) -> String:
	return String(TAB_NAMES.get(tab, MareTack.SLOT_NAMES.get(tab, "")))


## A row of picture tabs that wraps.
func _tab_row(ids: Array) -> HFlowContainer:
	var row := HFlowContainer.new()
	row.add_theme_constant_override(&"h_separation", 6)
	row.add_theme_constant_override(&"v_separation", 6)
	for id: StringName in ids:
		var b := Button.new()
		b.name = String(id)
		b.theme_type_variation = &"SatchelSlot"
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_ALL
		b.custom_minimum_size = TAB_SIZE
		b.pressed.connect(_show.bind(id))
		var inside := VBoxContainer.new()
		inside.set_anchors_preset(Control.PRESET_FULL_RECT)
		inside.alignment = BoxContainer.ALIGNMENT_CENTER
		inside.add_theme_constant_override(&"separation", 2)
		inside.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(inside)
		var picture := BookKit.picture(Icons.texture(Icons.TEND, id), Vector2(TAB_ICON, TAB_ICON))
		picture.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		inside.add_child(picture)
		var said := BookKit.label(tab_name(id), &"SatchelSmall")
		said.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		inside.add_child(said)
		_tabs[id] = b
		row.add_child(b)
	return row


func _show(tab: StringName) -> void:
	_tab = tab
	for id: StringName in _tabs:
		(_tabs[id] as Button).set_pressed_no_signal(id == tab)
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	_refresh_meters()
	if tab == CARE:
		_build_care()
	elif tab == HER:
		_build_page()
	else:
		_build_slot(tab)


## Her coat and her bond, as the meters the Bonds page draws.
func _refresh_meters() -> void:
	for c in _meters.get_children():
		_meters.remove_child(c)
		c.queue_free()
	_coat = MeterRow.make(Icons.texture(Icons.TEND, CARE), "Coat", &"SatchelMeter", MareCare.shine(), 1.0, _coat_word())
	_coat.name = "Coat"
	_meters.add_child(_coat)
	for m in BondBook.measures(BondBook.get_bond(BondBook.MARE)):
		if m.id == BondBook.CLOSENESS:
			_meters.add_child(MeterRow.of_measure(m))


func _coat_word() -> String:
	var s := MareCare.shine()
	return "Gleaming" if s >= 1.0 else ("Dull" if s < 0.05 else "Coming up lovely")


func _refresh_shine() -> void:
	if _coat:
		(_coat.get_node("Meter") as ProgressBar).value = MareCare.shine()
		(_coat.get_node("Word") as Label).text = _coat_word()


func _build_care() -> void:
	_body.add_child(BookKit.section("Brushing"))
	_body.add_child(BookKit.label("Hold the mouse on her and stroke to brush her coat.", &"SatchelBody", true))
	_body.add_child(BookKit.section("Treats"))
	var have := MareCare.treats_in(inventory)
	if MareCare.full():
		_body.add_child(BookKit.label("She has had her fill today. She noses your hand anyway.", &"SatchelBody", true))
	elif have.is_empty():
		_body.add_child(BookKit.label("Nothing sweet in the satchel. These are what she likes:", &"SatchelBody", true))
	var grid := HFlowContainer.new()
	grid.name = "Treats"
	grid.add_theme_constant_override(&"h_separation", 8)
	grid.add_theme_constant_override(&"v_separation", 8)
	_body.add_child(grid)
	for row: Array in have:
		var b := _treat(row[0], int(row[1]))
		b.disabled = MareCare.full() and row[0] != MareCare.HONEYPLUM
		b.pressed.connect(_feed.bind(row[0], b))
		grid.add_child(b)
	if have.is_empty() and not MareCare.full():
		for id in MareCare.TREATS:
			if Icons.has(Icons.ITEMS, Icons.item_key(id)):
				var wished := _treat(id, 0)
				wished.disabled = true
				wished.modulate.a = WISHED_ALPHA
				grid.add_child(wished)
	if MareBond.done(&"balked") and not MareBond.balmed():
		_body.add_child(HSeparator.new())
		_body.add_child(_card_balm())


## A treat: the satchel's picture of it, how many, and its name.
func _treat(id: StringName, count: int) -> Button:
	var b := Button.new()
	b.name = String(id)
	b.theme_type_variation = &"SatchelSlot"
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = TAB_SIZE
	var inside := VBoxContainer.new()
	inside.set_anchors_preset(Control.PRESET_FULL_RECT)
	inside.alignment = BoxContainer.ALIGNMENT_CENTER
	inside.add_theme_constant_override(&"separation", 0)
	inside.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(inside)
	var picture := Icons.item(SatchelEntries.item_entry(inventory, id, &""), TREAT_ICON)
	picture.custom_minimum_size = Vector2(TREAT_ICON, TREAT_ICON)
	picture.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inside.add_child(picture)
	var said := BookKit.label(MareTack._item_name(id), &"SatchelSmall")
	said.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	said.clip_text = true
	said.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	inside.add_child(said)
	if count > 0:
		var badge := BookKit.count_badge("×%d" % count)
		badge.position = Vector2(TAB_SIZE.x - 34.0, 4.0)
		b.add_child(badge)
	return b


## The sweetbalm: masks the smell of the blight so she'll carry Feyre in (MareBond).
func _card_balm() -> Control:
	var card := PanelContainer.new()
	card.theme_type_variation = &"SatchelCard"
	var col := VBoxContainer.new()
	card.add_child(col)
	col.add_child(BookKit.label("Sweetbalm", &"SatchelBody", true))
	col.add_child(BookKit.label("Rubbed on her muzzle, so the grey ground smells of nothing.", &"SatchelSmall", true))
	for id in MareBond.BALM_NEEDS:
		col.add_child(_need(String(id), MareTack._item_name(id), inventory.count(id) if inventory else 0, 1))
	var b := Button.new()
	b.theme_type_variation = &"SatchelSlot"
	b.text = "Make it and put it on"
	b.disabled = not MareBond.can_make_balm(inventory)
	b.pressed.connect(func() -> void:
		if MareBond.put_balm(inventory):
			Juice.burst(mare, &"craft")
			if mare:
				mare.nicker()
			_show(_tab))
	col.add_child(b)
	return card


## Her page, in Feyre's hand (MarePage).
func _build_page() -> void:
	_body.add_child(BookKit.section("What I know of her"))
	_body.add_child(BookKit.label(MarePage.now_line(), &"SatchelBody", true))
	var after := MarePage.after_line()
	if after != "":
		_body.add_child(BookKit.section("What I mean to try"))
		_body.add_child(BookKit.label(after, &"SatchelBody", true))
		for h in MarePage.hints_shown():
			_body.add_child(BookKit.label(h, &"SatchelSmall", true))
		var think := LoosePage.button("Think on it")
		think.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		think.disabled = not MarePage.can_think()
		think.pressed.connect(func() -> void:
			MarePage.think()
			_show(_tab))
		_body.add_child(think)
	var kept := MarePage.memories()
	if not kept.is_empty():
		_body.add_child(BookKit.section("Remembered"))
		for m in kept:
			_body.add_child(BookKit.label(m, &"SatchelSmall", true))


func _build_slot(slot: StringName) -> void:
	var grid := HFlowContainer.new()
	grid.name = "Pieces"
	grid.add_theme_constant_override(&"h_separation", 8)
	grid.add_theme_constant_override(&"v_separation", 8)
	_body.add_child(grid)
	var now := MareTack.worn_in(slot)
	if slot == &"tack" and MareBond.can_ride_bareback():
		grid.add_child(_card_saddle())
	if slot in MareTack.OPTIONAL:
		grid.add_child(_card_none(slot, now == null))
	for p in MareTack.in_slot(slot):
		grid.add_child(_card(p, now != null and now.id == p.id))


## A bead of enamel in `color` with the gold rim the icons have.
static func swatch(color: Color, px: float) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(px, px)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := BookKit.picture(Icons.texture(Icons.TEND, &"swatch_fill"), Vector2(px, px))
	fill.modulate = color
	holder.add_child(fill)
	holder.add_child(BookKit.picture(Icons.texture(Icons.TEND, &"swatch_rim"), Vector2(px, px)))
	return holder


## One thing a making takes: its picture (an item) or the slot's own (a kind
## of bloom or cord), its name, and how many she has of how many it needs.
func _need(key: String, label: String, have: int, need: int) -> HBoxContainer:
	var line := HBoxContainer.new()
	line.add_theme_constant_override(&"separation", 6)
	var id := StringName(key)
	if not key.begins_with("tag:") and Icons.has(Icons.ITEMS, Icons.item_key(id)):
		line.add_child(BookKit.picture(Icons.texture(Icons.ITEMS, Icons.item_key(id)), Vector2(NEED_ICON, NEED_ICON)))
	else:
		line.add_child(BookKit.picture(Icons.texture(Icons.TEND, &"brow"), Vector2(NEED_ICON, NEED_ICON)))
	var said := BookKit.label("%s  %d / %d" % [label, mini(have, need), need], &"SatchelSmall", true)
	said.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(said)
	return line


func _card(p: MareDecor, wearing: bool) -> Control:
	var card := PanelContainer.new()
	card.name = String(p.id)
	card.theme_type_variation = &"SatchelCard"
	card.custom_minimum_size = Vector2(CARD_W, 0)
	var col := VBoxContainer.new()
	card.add_child(col)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 4)
	col.add_child(row)
	if p.colors.is_empty():
		row.add_child(BookKit.picture(Icons.texture(Icons.TEND, p.slot), Vector2(SWATCH, SWATCH)))
	for c in p.colors:
		row.add_child(swatch(c, SWATCH))
	var name := BookKit.label(p.display_name, &"SatchelBody", true)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name)
	if p.blurb != "":
		col.add_child(BookKit.label(p.blurb, &"SatchelSmall", true))
	if wearing:
		col.add_child(BookKit.label("She's wearing it", &"SatchelBody", true))
		return card
	var b := Button.new()
	b.theme_type_variation = &"SatchelSlot"
	b.focus_mode = Control.FOCUS_ALL
	if MareTack.owned(p.id):
		b.text = "Put it on her"
		b.pressed.connect(_wear.bind(p))
	else:
		var needs := MareTack.needs(p, inventory)
		var keys := p.inputs.keys()
		for i in needs.size():
			col.add_child(_need(String(keys[i]), String(needs[i][0]), int(needs[i][1]), int(needs[i][2])))
		b.text = "Make it"
		b.disabled = not MareTack.can_make(p, inventory)
		b.pressed.connect(_make.bind(p))
	col.add_child(b)
	return card


## Once she trusts Feyre (MareBond), the saddle can come off: bareback (L47-8, canon ch 20).
func _card_saddle() -> Control:
	var card := PanelContainer.new()
	card.theme_type_variation = &"SatchelCard"
	card.custom_minimum_size = Vector2(CARD_W, 0)
	var col := VBoxContainer.new()
	card.add_child(col)
	var on := MareTack.saddled()
	col.add_child(BookKit.label("Saddle", &"SatchelBody", true))
	col.add_child(BookKit.label("She'll carry you without it now." if on else "Just her back and your knees.", &"SatchelSmall", true))
	var b := Button.new()
	b.theme_type_variation = &"SatchelSlot"
	b.focus_mode = Control.FOCUS_ALL
	b.text = "Ride bareback" if on else "Saddle her"
	b.pressed.connect(func() -> void:
		MareTack.set_saddled(not MareTack.saddled())
		_apply(true)
		_show(_tab))
	col.add_child(b)
	return card


func _card_none(slot: StringName, bare: bool) -> Control:
	var card := PanelContainer.new()
	card.theme_type_variation = &"SatchelCard"
	card.custom_minimum_size = Vector2(CARD_W, 0)
	var col := VBoxContainer.new()
	card.add_child(col)
	col.add_child(BookKit.label("Nothing", &"SatchelBody", true))
	var b := Button.new()
	b.theme_type_variation = &"SatchelSlot"
	b.focus_mode = Control.FOCUS_ALL
	b.text = "Bare" if bare else "Take it off"
	b.disabled = bare
	b.pressed.connect(func() -> void:
		MareTack.take_off(slot)
		_apply(true)
		_show(_tab))
	col.add_child(b)
	return card


# ------------------------------------------------------------------ deeds

func _wear(p: MareDecor) -> void:
	if MareTack.wear(p):
		_apply(true)
		_show(_tab)


func _make(p: MareDecor) -> void:
	if MareTack.make(p, inventory):
		MareTack.wear(p)
		_apply(true)
		Juice.burst(mare, &"craft")
		_show(_tab)


func _feed(id: StringName, button: Button) -> void:
	if not MareCare.feed(id, inventory):
		return
	Juice.burst(mare, &"pickup")
	if mare and mare.horse and mare.horse.animator:
		mare.horse.animator.nibble()
	if mare:
		mare.nicker()
	if button:
		Juice.bounce_control(button)
	_show(_tab)


## Re-lays her look; `celebrate` adds the dress-up sparkle, chime and a toss of her head.
func _apply(celebrate: bool) -> void:
	if mare and mare.horse:
		MareSaddle.set_saddled(mare.horse, MareTack.saddled())
		MareLook.apply(mare.horse, MareTack.outfit(), MareCare.shine())
		_last_applied = MareCare.shine()
		if celebrate:
			Juice.burst(mare, &"outfit")
			Juice.bounce(mare.horse.model, 0.06)
			mare.nicker()


# ------------------------------------------------------------------ brushing

func _over_mare(at: Vector2) -> bool:
	return at.x < size.x * (1.0 - PANEL_FRACTION)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_brushing = (event as InputEventMouseButton).pressed and _over_mare((event as InputEventMouseButton).position)
		_brush_at = (event as InputEventMouseButton).position
		accept_event()
	elif event is InputEventMouseMotion:
		_brush_at = (event as InputEventMouseMotion).position
		if _brushing and _over_mare(_brush_at):
			_stroke((event as InputEventMouseMotion).relative.length() / maxf(size.x, 1.0))
		queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"interact_alt") or event.is_action_pressed(&"interact"):
		get_viewport().set_input_as_handled()
		close()
		return
	# Nothing else reaches the game while she's being tended; ScreenStack
	# still hears Esc.
	if ScreenStack.answers(event):
		return
	if event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion:
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_since_stroke += delta
	_since_chime += delta
	if _sparkles and _sparkles.emitting and _since_stroke > 0.15:
		_sparkles.emitting = false
	# Pad: hold A and move the stick to brush.
	var stick := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	if Input.is_joy_button_pressed(0, JOY_BUTTON_A) and stick.length() > 0.2:
		if _brush_at == Vector2.ZERO:
			_brush_at = Vector2(size.x * 0.3, size.y * 0.5)
		_brush_at += stick * delta * size.x * 0.4
		_brush_at.x = clampf(_brush_at.x, 40.0, size.x * (1.0 - PANEL_FRACTION) - 40.0)
		_brush_at.y = clampf(_brush_at.y, 60.0, size.y - 60.0)
		_stroke(stick.length() * PAD_BRUSH * delta)
		queue_redraw()


func _stroke(amount: float) -> void:
	if amount <= 0.0:
		return
	var before := MareCare.shine()
	var now := MareCare.brush(amount)
	_since_stroke = 0.0
	if _sparkles:
		_sparkles.position = _brush_at
		_sparkles.emitting = true
	if _chime and _since_chime >= CHIME_GAP and before < 1.0:
		_since_chime = 0.0
		_chime.pitch_scale = lerpf(CHIME_PITCH.x, CHIME_PITCH.y, now)
		_chime.play()
	if absf(now - _last_applied) > 0.04 or (now >= 1.0 and before < 1.0):
		_apply(false)
	if now >= 1.0 and before < 1.0:
		Juice.burst(mare, &"unlock")
		if mare:
			mare.nicker()
	_refresh_shine()


func _draw() -> void:
	if not _over_mare(_brush_at) or _brush_at == Vector2.ZERO:
		return
	# The brush, held by its back above the pointer.
	draw_texture_rect(Icons.texture(Icons.TEND, CARE), Rect2(_brush_at + Vector2(-BRUSH_SIZE * 0.5, -BRUSH_SIZE * 0.8), Vector2(BRUSH_SIZE, BRUSH_SIZE)), false)


func _make_sparkles() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = 24
	p.lifetime = 0.7
	p.one_shot = false
	p.emitting = false
	p.explosiveness = 0.0
	p.spread = 180.0
	p.initial_velocity_min = 30.0
	p.initial_velocity_max = 90.0
	p.gravity = Vector2(0, 60)
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.5
	var g := Gradient.new()
	g.colors = PackedColorArray([JournalTheme.color(&"glow"), Color(JournalTheme.wash(0), 0.0)])
	p.color_ramp = g
	return p
