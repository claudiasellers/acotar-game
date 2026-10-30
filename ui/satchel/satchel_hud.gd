## The quick bar along the bottom of the screen, the satchel page, the
## satchel Feyre wears, and the little flight each pickup makes into her bag.
## Add one to an entry scene: add_child(SatchelHud.new()).
##
## The bar is a leather strap with four brass rings hung from it, the satchel
## itself at its left end; it lifts and the rings swing while LB is held.
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
## Ring spacing along the strap, and where the first ring hangs.
const RING_STEP := 96.0
const RING_START := 132.0
const BAG_PX := Vector2(64, 58)
## How far the strap lifts while the chord is held.
const CHORD_LIFT := 8.0
const IDLE_SECONDS := 6.0
const IDLE_ALPHA := 0.55
const MAX_FLIGHTS := 6

## Last input came from a gamepad (prompts switch glyphs).
static var pad_active: bool = false

var bar: QuickBar
var menu: SatchelMenu
var worn: SatchelWorn

var _bar_root: Control
var _row: Control
var _strap: QuickStrap
var _badge: Control
var _badge_key: Label
var _glyph: SatchelGlyph
var _slot_panels: Array[QuickRing] = []
var _chord: bool = false
var _chord_time: float = 0.0
var _chord_used: bool = false
var _idle: float = 0.0
var _flights: int = 0
var _row_y: float = 0.0


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
	if on and not _chord:
		for i in _slot_panels.size():
			_slot_panels[i].kick(0.9 * (1.0 if i % 2 else -1.0) * Juice.effects_scale)
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
	var lift := -CHORD_LIFT if _chord else 0.0
	_row.position.y = lerpf(_row.position.y, _row_y + lift, 1.0 - pow(0.7, delta * 60.0))


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
	var length := RING_START + RING_STEP * QuickBar.SLOTS - RING_STEP * 0.5 + 20.0
	var height := QuickStrap.BAND + QuickRing.TAB.y + QuickRing.RADIUS * 2.0 + 12.0
	_row = Control.new()
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.size = Vector2(length, height)
	_bar_root.add_child(_row)
	_bar_root.resized.connect(_place_row)
	_strap = QuickStrap.new()
	_strap.size = Vector2(length, QuickStrap.BAND)
	_strap.position = Vector2(0, BAG_PX.y * 0.35)
	_row.add_child(_strap)
	# The satchel hangs off the strap's left end; its key is stamped beneath.
	_badge = Control.new()
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge.size = BAG_PX
	_badge.position = Vector2(8, 0)
	_badge.pivot_offset = Vector2(BAG_PX.x * 0.5, 0)
	_row.add_child(_badge)
	_glyph = SatchelGlyph.new()
	_glyph.size = BAG_PX
	_badge.add_child(_glyph)
	_badge_key = Label.new()
	_badge_key.theme_type_variation = &"QuickBarKey"
	_badge_key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_badge_key.size = Vector2(BAG_PX.x, 20)
	_badge_key.position = Vector2(0, BAG_PX.y + 2)
	_badge.add_child(_badge_key)
	var rivets := PackedFloat32Array()
	for i in QuickBar.SLOTS:
		var ring := QuickRing.new()
		var x := RING_START + RING_STEP * i
		rivets.append(x)
		ring.position = Vector2(x - ring.size.x * 0.5, _strap.position.y + QuickStrap.BAND - 4.0)
		_row.add_child(ring)
		_slot_panels.append(ring)
	_strap.rivets = rivets
	_place_row()


## Centred along the bottom, clear of the controls hint.
func _place_row() -> void:
	_row_y = _bar_root.size.y - _row.size.y - 84.0
	_row.position = Vector2((_bar_root.size.x - _row.size.x) * 0.5, _row_y)


func _refresh() -> void:
	if _row == null:
		return
	var inv := bar.inventory
	_glyph.fill = inv.used(Inventory.SATCHEL) / float(Inventory.CAPACITY[Inventory.SATCHEL])
	_badge_key.text = "LB" if pad_active else "I"
	_strap.queue_redraw()
	for i in _slot_panels.size():
		var ring := _slot_panels[i]
		ring.lit = _chord
		ring.queue_redraw()
		for c in ring.get_children():
			c.queue_free()
		var id := bar.entry(i)
		var n := bar.count(i)
		var at := ring.centre()
		if id != &"":
			var e := SatchelEntries.find(inv, id)
			if e.is_empty():
				e = {"id": id, "icon": &"drop", "item": ItemCatalog.get_item(id)}
				var item := e.item as ItemData
				if item:
					e.icon = item.icon
			var icon := SatchelIcon.make(e, QuickRing.ICON_PX)
			icon.position = at - Vector2.ONE * QuickRing.ICON_PX * 0.5
			icon.modulate.a = 1.0 if n > 0 else 0.35
			ring.add_child(icon)
			var count := Label.new()
			count.theme_type_variation = &"QuickBarCount"
			count.text = str(n)
			count.position = at + Vector2(QuickRing.RADIUS * 0.45, QuickRing.RADIUS * 0.35)
			ring.add_child(count)
		# The key is stamped into the strap above the ring.
		var key := Label.new()
		key.theme_type_variation = &"QuickBarKey"
		key.text = SLOT_PAD_GLYPHS[i] if pad_active else str(i + 1)
		key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key.size = Vector2(ring.size.x, QuickStrap.BAND)
		key.position = Vector2(0, -QuickStrap.BAND + 2.0)
		key.add_theme_color_override(&"font_color", SatchelTheme.color(&"paper"))
		ring.add_child(key)


func _on_used(slot: int, _id: StringName) -> void:
	_idle = 0.0
	_pop(slot, 0.25)
	_slot_panels[slot].kick(2.4 * Juice.effects_scale)
	_sparkle(_slot_panels[slot])


func _pop(slot: int, amount: float) -> void:
	_idle = 0.0
	if slot >= 0 and slot < _slot_panels.size():
		Juice.bounce_control(_slot_panels[slot], amount * Juice.effects_scale)


func _shake(slot: int) -> void:
	# An empty or unusable ring just jerks on its tab.
	_slot_panels[slot].kick(-3.5 * Juice.effects_scale)


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
