## Tending the white mare (lane L47-7, docs/contracts/mare_bond.md): T (her own key)
## beside her and the camera draws round to her near side. On the left, her;
## stroke her coat with the brush (hold the mouse, or A and the stick) and it
## comes up gleaming with a sparkle where the brush passes. On the right, in the
## satchel's hand: Care (the shine, and treats from what Feyre carries) and one
## tab per dress-up slot, where pieces are made from found things and put on
## her. Every change sparkles, chimes and makes her toss her head (R3). The
## world keeps turning; Feyre stands by her. Esc, E or Done to leave.
class_name MareTendingView
extends Control

signal closed

const PANEL_FRACTION := 0.42
const CAMERA_OUT := 5.2
const CAMERA_AHEAD := 1.3
const CAMERA_UP := 1.55
## How far right of her the camera aims (m), so she stands left of the panel.
const CAMERA_SHIFT := 1.25
const CARD_W := 210.0
## Pad brushing: stick travel per second while A is held, in screen widths.
const PAD_BRUSH := 1.6
## Her page (MarePage): what Feyre knows of her, what to try, what she remembers.
const PAGE_TAB := "Her"
## The lilac wash.
const WASH := 1

var mare: MareMount
var feyre: Node3D
var inventory: Inventory
var camera: Camera3D
var _prev_camera: Camera3D
var _tab: String = "Care"
var _tabs: HFlowContainer
var _body: VBoxContainer
var _shine_bar: ProgressBar
var _shine_label: Label
var _brushing: bool = false
var _brush_at: Vector2 = Vector2.ZERO
var _sparkles: CPUParticles2D
var _since_stroke: float = 99.0
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
	_show(_tab)


## Esc or B while the tending screen is the top screen.
func screen_cancel() -> void:
	close()


## Her tabs take their own focus when they are shown.
func screen_focus() -> void:
	pass


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

func _frame_camera() -> void:
	if mare == null:
		return
	_prev_camera = get_viewport().get_camera_3d()
	camera = Camera3D.new()
	camera.name = "MareTendingCamera"
	camera.fov = 42.0
	mare.get_parent().add_child(camera)
	var left := -mare.global_basis.x
	var fwd := -mare.global_basis.z
	var at := mare.global_position + Vector3.UP * 1.25
	var from := mare.global_position + left * CAMERA_OUT + fwd * CAMERA_AHEAD + Vector3.UP * CAMERA_UP
	# Put her in the left part of the frame: aim right of her, toward the panel.
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
	col.add_theme_constant_override(&"separation", 10)
	panel.add_child(col)
	var title := LoosePage.heading("Tending her", WASH)
	col.add_child(title)
	_tabs = HFlowContainer.new()
	_tabs.add_theme_constant_override(&"h_separation", 6)
	_tabs.add_theme_constant_override(&"v_separation", 6)
	col.add_child(_tabs)
	for name: String in _tab_names():
		var b := Button.new()
		b.text = name
		b.theme_type_variation = &"SatchelTab"
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_ALL
		b.pressed.connect(_show.bind(name))
		_tabs.add_child(b)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override(&"separation", 8)
	scroll.add_child(_body)
	var done := LoosePage.button("Done")
	done.pressed.connect(close)
	col.add_child(done)


func _tab_names() -> Array[String]:
	var out: Array[String] = ["Care", PAGE_TAB]
	for s in MareTack.SLOTS:
		out.append(MareTack.SLOT_NAMES[s])
	return out


func _slot_of(tab: String) -> StringName:
	for s: StringName in MareTack.SLOT_NAMES:
		if MareTack.SLOT_NAMES[s] == tab:
			return s
	return &""


func _show(tab: String) -> void:
	_tab = tab
	for b in _tabs.get_children():
		(b as Button).set_pressed_no_signal((b as Button).text == tab)
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	_shine_bar = null
	if tab == "Care":
		_build_care()
	elif tab == PAGE_TAB:
		_build_page()
	else:
		_build_slot(_slot_of(tab))


func _build_care() -> void:
	_body.add_child(BookKit.label("Her coat", &"SatchelSmall", true))
	_shine_bar = ProgressBar.new()
	_shine_bar.theme_type_variation = &"SatchelMeter"
	_shine_bar.min_value = 0.0
	_shine_bar.max_value = 1.0
	_shine_bar.show_percentage = false
	_shine_bar.custom_minimum_size = Vector2(0, 18)
	_body.add_child(_shine_bar)
	_shine_label = BookKit.label("", &"SatchelSmall", true)
	_body.add_child(_shine_label)
	_refresh_shine()
	_body.add_child(HSeparator.new())
	_body.add_child(BookKit.label("Treats", &"SatchelSmall", true))
	var have := MareCare.treats_in(inventory)
	if MareCare.full():
		_body.add_child(BookKit.label("She has had her fill today. She noses your hand anyway.", &"SatchelBody", true))
	elif have.is_empty():
		_body.add_child(BookKit.label("Nothing sweet in the satchel. She likes orchard fruit, berries, clover and dandelions.", &"SatchelBody", true))
	var grid := HFlowContainer.new()
	grid.add_theme_constant_override(&"h_separation", 8)
	_body.add_child(grid)
	for row: Array in have:
		var b := Button.new()
		b.theme_type_variation = &"SatchelSlot"
		b.text = "%s  ×%d" % [MareTack._item_name(row[0]), row[1]]
		b.disabled = MareCare.full() and row[0] != MareCare.HONEYPLUM
		b.pressed.connect(_feed.bind(row[0], b))
		grid.add_child(b)
	if MareBond.done(&"balked") and not MareBond.balmed():
		_body.add_child(HSeparator.new())
		_body.add_child(_card_balm())


## The sweetbalm: masks the smell of the blight so she'll carry Feyre in (MareBond).
func _card_balm() -> Control:
	var card := PanelContainer.new()
	card.theme_type_variation = &"SatchelCard"
	var col := VBoxContainer.new()
	card.add_child(col)
	col.add_child(BookKit.label("Sweetbalm", &"SatchelBody", true))
	var needs := PackedStringArray()
	for id in MareBond.BALM_NEEDS:
		needs.append("%s %s" % [MareTack._item_name(id), "✓" if inventory and inventory.count(id) > 0 else "·"])
	col.add_child(BookKit.label("Rubbed on her muzzle, so the grey ground smells of nothing. " + ", ".join(needs), &"SatchelSmall", true))
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
	_body.add_child(BookKit.label("What I know of her", &"SatchelSmall", true))
	_body.add_child(BookKit.label(MarePage.now_line(), &"SatchelBody", true))
	var after := MarePage.after_line()
	if after != "":
		_body.add_child(HSeparator.new())
		_body.add_child(BookKit.label("What I mean to try", &"SatchelSmall", true))
		_body.add_child(BookKit.label(after, &"SatchelBody", true))
		for h in MarePage.hints_shown():
			_body.add_child(BookKit.label(h, &"SatchelSmall", true))
		var think := Button.new()
		think.theme_type_variation = &"SatchelTab"
		think.text = "Think on it"
		think.disabled = not MarePage.can_think()
		think.pressed.connect(func() -> void:
			MarePage.think()
			_show(_tab))
		_body.add_child(think)
	var kept := MarePage.memories()
	if not kept.is_empty():
		_body.add_child(HSeparator.new())
		_body.add_child(BookKit.label("Remembered", &"SatchelSmall", true))
		for m in kept:
			_body.add_child(BookKit.label(m, &"SatchelSmall", true))


func _refresh_shine() -> void:
	var s := MareCare.shine()
	if _shine_bar:
		_shine_bar.value = s
	if _shine_label:
		_shine_label.text = "Gleaming." if s >= 1.0 else ("Stroke her coat with the brush." if s < 0.05 else "Coming up lovely.")


func _build_slot(slot: StringName) -> void:
	var grid := HFlowContainer.new()
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


func _card(p: MareDecor, wearing: bool) -> Control:
	var card := PanelContainer.new()
	card.theme_type_variation = &"SatchelCard"
	card.custom_minimum_size = Vector2(CARD_W, 0)
	var col := VBoxContainer.new()
	card.add_child(col)
	var row := HBoxContainer.new()
	col.add_child(row)
	var swatch := ColorRect.new()
	swatch.custom_minimum_size = Vector2(22, 22)
	swatch.color = p.colors[0] if not p.colors.is_empty() else JournalTheme.wash(0)
	row.add_child(swatch)
	var name := BookKit.label(p.display_name, &"SatchelBody", true)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name)
	if p.blurb != "":
		col.add_child(BookKit.label(p.blurb, &"SatchelSmall", true))
	var b := Button.new()
	b.theme_type_variation = &"SatchelSlot"
	if wearing:
		b.text = "She's wearing it"
		b.disabled = true
	elif MareTack.owned(p.id):
		b.text = "Put it on her"
		b.pressed.connect(_wear.bind(p))
	else:
		for need: Array in MareTack.needs(p, inventory):
			var l := BookKit.label("%s  %d / %d" % [need[0], mini(need[1], need[2]), need[2]], &"SatchelSmall", true)
			if int(need[1]) < int(need[2]):
				l.modulate.a = 0.55
			col.add_child(l)
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
	if event.is_action_pressed(MountDirector.TEND_ACTION) or event.is_action_pressed(&"interact"):
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
	if absf(now - _last_applied) > 0.04 or (now >= 1.0 and before < 1.0):
		_apply(false)
	if now >= 1.0 and before < 1.0:
		Juice.burst(mare, &"unlock")
		mare.nicker()
	_refresh_shine()


func _draw() -> void:
	if not _over_mare(_brush_at) or _brush_at == Vector2.ZERO:
		return
	# The brush: an oval back with soft bristles.
	var c := _brush_at + Vector2(18, -14)
	var ink := JournalTheme.color(&"ink")
	var glow := JournalTheme.color(&"glow")
	draw_set_transform(c, -0.5, Vector2(1.0, 0.55))
	draw_circle(Vector2.ZERO, 22.0, glow)
	draw_arc(Vector2.ZERO, 22.0, 0.0, TAU, 32, ink, 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for k in 7:
		var x := -15.0 + k * 5.0
		draw_line(c + Vector2(x, 8).rotated(-0.5), c + Vector2(x, 18).rotated(-0.5), ink.lerp(glow, 0.4), 2.0)


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
