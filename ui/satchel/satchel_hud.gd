## The quick bar along the bottom of the screen, the satchel page, the
## satchel Feyre wears, and the little flight each pickup makes into her bag.
## Add one to an entry scene: add_child(SatchelHud.new()).
##
## Keys: I / Tab opens the satchel, 1–4 use the quick slots.
## Pad: tap LB to open the satchel; hold LB and press the d-pad
## (up, right, down, left) to use slots 1–4. While LB is held the d-pad's own
## actions (arrow, craft, bow, crown) are held off; A stays jump.
## Actions are added in code with a has_action guard (R14, L01's call).
class_name SatchelHud
extends CanvasLayer

const ACTION_OPEN := &"satchel_open"
const ACTION_CHORD := &"quick_chord"
const SLOT_ACTIONS: Array[StringName] = [&"quick_1", &"quick_2", &"quick_3", &"quick_4"]
const SLOT_KEYS: Array[Key] = [KEY_1, KEY_2, KEY_3, KEY_4]
## D-pad direction for each slot while LB is held.
const SLOT_PAD: Array[JoyButton] = [JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_DOWN,
		JOY_BUTTON_DPAD_LEFT]
const SLOT_PAD_GLYPHS: Array[String] = ["↑", "→", "↓", "←"]
## A shorter LB press than this, with no slot used, opens the satchel.
const TAP_SECONDS := 0.3
const SLOT_PX := 76.0
const IDLE_SECONDS := 6.0
const IDLE_ALPHA := 0.55
const MAX_FLIGHTS := 6

## Last input came from a gamepad (prompts switch glyphs).
static var pad_active: bool = false

var bar: QuickBar
var menu: SatchelMenu
var worn: SatchelWorn

var _bar_root: Control
var _row: HBoxContainer
var _badge: PanelContainer
var _badge_meter: ProgressBar
var _glyph: SatchelGlyph
var _slot_panels: Array[PanelContainer] = []
var _chord: bool = false
var _chord_time: float = 0.0
var _chord_used: bool = false
var _idle: float = 0.0
var _flights: int = 0


func _init() -> void:
	name = "SatchelHud"


static func slot_action(i: int) -> StringName:
	return SLOT_ACTIONS[i]


static func ensure_actions() -> void:
	for spec in [[ACTION_OPEN, [KEY_I, KEY_TAB], []], [ACTION_CHORD, [], [JOY_BUTTON_LEFT_SHOULDER]]]:
		_add_action(spec[0], spec[1], spec[2])
	for i in SLOT_ACTIONS.size():
		_add_action(SLOT_ACTIONS[i], [SLOT_KEYS[i]], [])


static func _add_action(action: StringName, keys: Array, buttons: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for k in keys:
		var key := InputEventKey.new()
		key.physical_keycode = k
		InputMap.action_add_event(action, key)
	for b in buttons:
		var pad := InputEventJoypadButton.new()
		pad.button_index = b
		InputMap.action_add_event(action, pad)


func _ready() -> void:
	layer = 12
	process_mode = Node.PROCESS_MODE_ALWAYS
	ensure_actions()
	bar = QuickBar.current()
	SaveSystem.register_provider(QuickBar.SAVE_KEY, bar)
	menu = SatchelMenu.new(bar)
	add_child(menu)
	_build_bar()
	bar.changed.connect(_refresh)
	bar.used.connect(_on_used)
	bar.pinned.connect(func(slot: int, _id: StringName) -> void: _pop(slot, 0.22))
	_refresh()
	Gameplay.listen(&"phase_changed", func(_a: StringName, _b: StringName) -> void: _apply_theme())
	_attach_worn.call_deferred()


func _apply_theme() -> void:
	_bar_root.theme = SatchelTheme.theme()
	_refresh()


func _attach_worn() -> void:
	var feyre := _player()
	if feyre == null or feyre.has_node(^"SatchelWorn"):
		return
	worn = SatchelWorn.new()
	feyre.add_child(worn)


func _player() -> Feyre:
	return get_tree().get_first_node_in_group(&"player") as Feyre


## Uses quick slot `i` on Feyre, with the feel (pop, sparkle, sound).
func use_slot(i: int) -> bool:
	var ok := bar.use(i, _player())
	if not ok:
		SatchelSounds.play(&"refuse", self)
		_shake(i)
	return ok


func open_satchel() -> void:
	_set_chord(false)
	menu.open()


# --- input -------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		if not pad_active and (event is InputEventJoypadButton or absf((event as InputEventJoypadMotion).axis_value) > 0.4):
			pad_active = true
			_refresh()
	elif event is InputEventKey or event is InputEventMouseButton:
		if pad_active:
			pad_active = false
			_refresh()
	if menu.is_open():
		return
	if get_tree().paused:
		_from_map(event)
		return
	if not _can_play():
		return
	if event.is_action_pressed(ACTION_OPEN):
		open_satchel()
		get_viewport().set_input_as_handled()
		return
	if event.is_action(ACTION_CHORD) and not event.is_echo():
		if event.is_pressed():
			_set_chord(true)
		elif _chord:
			var tapped := not _chord_used and _chord_time < TAP_SECONDS
			_set_chord(false)
			if tapped:
				open_satchel()
		get_viewport().set_input_as_handled()
		return
	if _chord and event is InputEventJoypadButton:
		var i := SLOT_PAD.find((event as InputEventJoypadButton).button_index)
		if i >= 0:
			if event.is_pressed():
				_chord_used = true
				use_slot(i)
			get_viewport().set_input_as_handled()
			return
	for i in SLOT_ACTIONS.size():
		if event.is_action_pressed(SLOT_ACTIONS[i]):
			use_slot(i)
			get_viewport().set_input_as_handled()
			return


## I / Tab / LB on the open map flips to the satchel (one menu, two pages).
func _from_map(event: InputEvent) -> void:
	if not (event.is_action_pressed(ACTION_OPEN) or event.is_action_pressed(ACTION_CHORD)):
		return
	for hud in get_tree().root.find_children("*", "WorldMapHud", true, false):
		var full_map := (hud as WorldMapHud).full_map
		if full_map and full_map.is_open():
			full_map.close()
			open_satchel()
			get_viewport().set_input_as_handled()
			return


func _can_play() -> bool:
	return StoryControl.mode == StoryControl.Mode.FULL


func _set_chord(on: bool) -> void:
	_chord = on
	_chord_time = 0.0
	_chord_used = false
	_idle = 0.0
	_refresh()


func _process(delta: float) -> void:
	_follow_inventory()
	_bar_root.visible = _can_play() and not get_tree().paused
	if _chord:
		_chord_time += delta
	_idle += delta
	var target := 1.0 if _chord or _idle < IDLE_SECONDS else IDLE_ALPHA
	_bar_root.modulate.a = move_toward(_bar_root.modulate.a, target, delta * 2.5)


## After Gameplay.reset (new game) the bar rebinds to the new inventory.
func _follow_inventory() -> void:
	if bar == QuickBar.current() and not bar.inventory.item_added.is_connected(_on_item_added):
		bar.inventory.item_added.connect(_on_item_added)
		_refresh()


# --- the bar -----------------------------------------------------------------

func _build_bar() -> void:
	_bar_root = Control.new()
	_bar_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bar_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_root.theme = SatchelTheme.theme()
	add_child(_bar_root)
	_row = HBoxContainer.new()
	_row.add_theme_constant_override(&"separation", 10)
	_row.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_row.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_row.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_row.offset_bottom = -84  # clear of the controls hint along the bottom edge
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_root.add_child(_row)
	_badge = PanelContainer.new()
	_badge.theme_type_variation = &"QuickBarSlot"
	_badge.custom_minimum_size = Vector2(SLOT_PX, SLOT_PX)
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var badge_col := VBoxContainer.new()
	badge_col.alignment = BoxContainer.ALIGNMENT_CENTER
	_badge.add_child(badge_col)
	var glyph := SatchelGlyph.new()
	_glyph = glyph
	glyph.custom_minimum_size = Vector2(40, 36)
	glyph.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	badge_col.add_child(glyph)
	_badge_meter = ProgressBar.new()
	_badge_meter.theme_type_variation = &"SatchelMeter"
	_badge_meter.show_percentage = false
	_badge_meter.custom_minimum_size = Vector2(48, 6)
	_badge_meter.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	badge_col.add_child(_badge_meter)
	var key := Label.new()
	key.theme_type_variation = &"QuickBarKey"
	key.name = "Key"
	key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_col.add_child(key)
	_row.add_child(_badge)
	for i in QuickBar.SLOTS:
		var p := PanelContainer.new()
		p.custom_minimum_size = Vector2(SLOT_PX, SLOT_PX)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_row.add_child(p)
		_slot_panels.append(p)


func _refresh() -> void:
	if _row == null:
		return
	var inv := bar.inventory
	_glyph.queue_redraw()
	_badge_meter.max_value = float(Inventory.CAPACITY[Inventory.SATCHEL])
	_badge_meter.value = inv.used(Inventory.SATCHEL)
	(_badge.find_child("Key", true, false) as Label).text = "LB" if pad_active else "I"
	for i in _slot_panels.size():
		var p := _slot_panels[i]
		p.theme_type_variation = &"QuickBarSlotSelected" if _chord else &"QuickBarSlot"
		for c in p.get_children():
			c.queue_free()
		var stack := Control.new()
		stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(stack)
		var id := bar.entry(i)
		var n := bar.count(i)
		if id != &"":
			var e := SatchelEntries.find(inv, id)
			var item := ItemCatalog.get_item(id) if not SatchelEntries.is_dish(id) else null
			var color: Color = item.color if item else SatchelTheme.color(&"accent")
			var shape: StringName = item.icon if item else &"drop"
			var icon := ItemIcon.make(shape, color, n == 0, false, 48.0)
			icon.position = Vector2(SLOT_PX - 48.0, SLOT_PX - 48.0) * 0.5 - Vector2(0, 4)
			stack.add_child(icon)
			var count := Label.new()
			count.theme_type_variation = &"QuickBarCount"
			count.text = str(n) if not e.is_empty() else "0"
			count.position = Vector2(SLOT_PX - 34, SLOT_PX - 30)
			stack.add_child(count)
		var key := Label.new()
		key.theme_type_variation = &"QuickBarKey"
		key.text = SLOT_PAD_GLYPHS[i] if pad_active else str(i + 1)
		key.position = Vector2(6, 2)
		stack.add_child(key)


func _on_used(slot: int, _id: StringName) -> void:
	_idle = 0.0
	SatchelSounds.play(&"use", self)
	_pop(slot, 0.25)
	_sparkle(_slot_panels[slot])


func _pop(slot: int, amount: float) -> void:
	_idle = 0.0
	if slot >= 0 and slot < _slot_panels.size():
		Juice.bounce_control(_slot_panels[slot], amount * Juice.effects_scale)


func _shake(slot: int) -> void:
	var p := _slot_panels[slot]
	var t := p.create_tween()
	for dx in [-6.0, 5.0, -3.0, 0.0]:
		t.tween_property(p, ^"position:x", p.position.x + dx, 0.04)


func _sparkle(target: Control) -> void:
	var s := CPUParticles2D.new()
	s.one_shot = true
	s.emitting = true
	s.amount = maxi(4, int(14 * Juice.effects_scale))
	s.lifetime = 0.6
	s.explosiveness = 0.9
	s.spread = 180.0
	s.initial_velocity_min = 60.0
	s.initial_velocity_max = 140.0
	s.gravity = Vector2(0, 120)
	s.scale_amount_min = 2.0
	s.scale_amount_max = 4.0
	s.color = SatchelTheme.color(&"glow")
	s.position = target.size * 0.5
	target.add_child(s)
	get_tree().create_timer(0.8, true).timeout.connect(s.queue_free)


## A pickup flies from Feyre into the satchel badge, which bounces and sings.
func _on_item_added(id: StringName, count: int, _container: StringName) -> void:
	_idle = 0.0
	_refresh()
	if not _bar_root.visible or _flights >= MAX_FLIGHTS:
		return
	var feyre := _player()
	var cam := get_viewport().get_camera_3d()
	if feyre == null or cam == null or cam.is_position_behind(feyre.global_position):
		return
	var item := ItemCatalog.get_item(id)
	var icon := ItemIcon.make(item.icon if item else &"trinket", item.color if item else SatchelTheme.color(&"accent"),
			false, item != null and item.rarity == &"shiny", 44.0)
	_bar_root.add_child(icon)
	icon.position = cam.unproject_position(feyre.global_position + Vector3.UP * 1.3) - Vector2(22, 22)
	var to := _badge.global_position + _badge.size * 0.5 - Vector2(22, 22)
	var from := icon.position
	var arc := from.lerp(to, 0.5) + Vector2(0, -120)
	_flights += 1
	var t := icon.create_tween()
	t.tween_method(func(k: float) -> void:
		icon.position = _quad(from, arc, to, k)
		icon.scale = Vector2.ONE * lerpf(1.1, 0.55, k), 0.0, 1.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.tween_callback(func() -> void:
		icon.queue_free()
		_flights -= 1
		Juice.bounce_control(_badge, 0.2 * Juice.effects_scale)
		_plus(count)
		SatchelSounds.play(&"pickup", self))


func _quad(a: Vector2, b: Vector2, c: Vector2, k: float) -> Vector2:
	return a.lerp(b, k).lerp(b.lerp(c, k), k)


func _plus(count: int) -> void:
	var l := Label.new()
	l.theme_type_variation = &"QuickBarCount"
	l.text = "+%d" % count
	_bar_root.add_child(l)
	l.position = _badge.global_position + Vector2(_badge.size.x * 0.5 - 10, -18)
	var t := l.create_tween().set_parallel()
	t.tween_property(l, ^"position:y", l.position.y - 30, 0.7).set_ease(Tween.EASE_OUT)
	t.tween_property(l, ^"modulate:a", 0.0, 0.7).set_delay(0.25)
	t.chain().tween_callback(l.queue_free)
