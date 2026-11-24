## The quick bar along the bottom of the screen, the satchel page, the
## satchel Feyre wears, the little flight each pickup makes into her bag and
## the pickup log that names it.
## Add one to an entry scene: add_child(SatchelHud.new()).
##
## The bar is her paint tin (PaintTin): the book at its left end and four
## pans; it lifts and the pans stand proud while LB is held. It sits in
## HudLayout's STRAP zone.
##
## Keys: I / Tab opens the satchel, 1–4 use the quick slots.
## Pad: tap LB to open the satchel; hold LB and press the d-pad
## (up, right, down, left) to use slots 1–4. While LB is held the d-pad's own
## actions (arrow, craft, bow, crown) are held off; A stays jump.
## Actions are added in code with a has_action guard (R14, L01's call).
class_name SatchelHud
extends Node

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
## How far the tin lifts while the chord is held.
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
var pickups: PickupLog
var _tin: PaintTin
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
	process_mode = Node.PROCESS_MODE_ALWAYS
	ensure_actions()
	bar = QuickBar.current()
	SaveSystem.register_provider(QuickBar.SAVE_KEY, bar)
	menu = SatchelMenu.new(bar)
	add_child(menu)
	# The wardrobe on what she carries (L64), the satchel's neighbour page.
	add_child(WardrobeTab.new())
	_build_bar()
	bar.changed.connect(_refresh)
	bar.used.connect(_on_used)
	bar.pinned.connect(func(slot: int, id: StringName) -> void:
		_pop(slot, 0.22)
		_name(slot, id))
	_refresh()
	Gameplay.listen(&"phase_changed", func(_a: StringName, _b: StringName) -> void: _apply_theme())
	_attach_worn.call_deferred()


func _apply_theme() -> void:
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
	# I / Tab itself is the menu shell's (MenuShell); the LB tap is read here.
	if not _can_play():
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


func _can_play() -> bool:
	return UiMode.current(get_tree()) == UiMode.Mode.PLAY


func _set_chord(on: bool) -> void:
	if on and not _chord:
		for pan in _tin.pans:
			pan.kick(60.0 * Juice.effects_scale)
	_chord = on
	_chord_time = 0.0
	_chord_used = false
	_idle = 0.0
	_refresh()


func _process(delta: float) -> void:
	_follow_inventory()
	if _chord:
		_chord_time += delta
	_idle += delta
	var target := 1.0 if _chord or _idle < IDLE_SECONDS else IDLE_ALPHA
	_bar_root.modulate.a = move_toward(_bar_root.modulate.a, target, delta * 2.5)
	var lift := -CHORD_LIFT if _chord else 0.0
	_tin.position.y = lerpf(_tin.position.y, CHORD_LIFT + lift, 1.0 - pow(0.7, delta * 60.0))


## After Gameplay.reset (new game) the bar rebinds to the new inventory.
func _follow_inventory() -> void:
	if bar == QuickBar.current() and not bar.inventory.item_added.is_connected(_on_item_added):
		bar.inventory.item_added.connect(_on_item_added)
		_refresh()


# --- the bar -----------------------------------------------------------------

## The room the tin takes in the STRAP zone.
static func bar_size() -> Vector2:
	return PaintTin.TIN + Vector2(0, PaintTin.NAME_ROOM + CHORD_LIFT)


func _build_bar() -> void:
	_bar_root = Control.new()
	_bar_root.name = "QuickBar"
	_bar_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_root.custom_minimum_size = bar_size()
	HudLayout.of(get_tree()).place(_bar_root, HudLayout.Zone.STRAP, self)
	# A new scene's HUD starts with an empty log.
	pickups = PickupLog.of(get_tree())
	pickups.clear()
	_tin = PaintTin.new()
	_tin.position = Vector2(0, CHORD_LIFT)
	_bar_root.add_child(_tin)


func _refresh() -> void:
	if _tin == null:
		return
	var inv := bar.inventory
	_tin.book_key.text = "LB" if pad_active else BookKit.key_word(ACTION_OPEN)
	for i in _tin.pans.size():
		var id := bar.entry(i)
		var icon: Control = null
		if id != &"":
			var e := SatchelEntries.find(inv, id)
			if e.is_empty():
				e = {"id": id, "icon": &"drop", "item": ItemCatalog.get_item(id)}
				var item := e.item as ItemData
				if item:
					e.icon = item.icon
			icon = Icons.item(e, PaintTin.Pan.ICON_PX)
		_tin.pans[i].lit = _chord
		_tin.fill(i, icon, bar.count(i), SLOT_PAD_GLYPHS[i] if pad_active else str(i + 1), hash(String(id)))


func _on_used(slot: int, id: StringName) -> void:
	_idle = 0.0
	_pop(slot, 0.25)
	_tin.pans[slot].kick(150.0 * Juice.effects_scale)
	_sparkle(_tin.pans[slot])
	_name(slot, id)


## Names what is in a pan, above it, for a moment.
func _name(slot: int, id: StringName) -> void:
	var item := ItemCatalog.get_item(id)
	_tin.name_pan(slot, item.display_name if item else "")


func _pop(slot: int, amount: float) -> void:
	_idle = 0.0
	if slot >= 0 and slot < _tin.pans.size():
		Juice.bounce_control(_tin.pans[slot], amount * Juice.effects_scale)


func _shake(slot: int) -> void:
	# An empty or unusable pan just dips in its seat.
	_tin.pans[slot].kick(-90.0 * Juice.effects_scale)


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
	s.color = JournalTheme.color(&"glow")
	s.position = target.size * 0.5
	target.add_child(s)
	get_tree().create_timer(0.8, true).timeout.connect(s.queue_free)


## A pickup flies from Feyre into the tin's book, which bounces and sings.
func _on_item_added(id: StringName, count: int, _container: StringName) -> void:
	_idle = 0.0
	_refresh()
	pickups.add(id, count)
	if not _bar_root.is_visible_in_tree() or _flights >= MAX_FLIGHTS:
		return
	var feyre := _player()
	var cam := get_viewport().get_camera_3d()
	if feyre == null or cam == null or cam.is_position_behind(feyre.global_position):
		return
	var item := ItemCatalog.get_item(id)
	var icon := ItemIcon.make(item.icon if item else &"trinket", item.color if item else JournalTheme.color(&"accent"),
			false, item != null and item.rarity == &"shiny", 44.0)
	icon.top_level = true
	_bar_root.add_child(icon)
	icon.position = cam.unproject_position(feyre.global_position + Vector3.UP * 1.3) - Vector2(22, 22)
	var to := _tin.book.global_position + _tin.book.size * 0.5 - Vector2(22, 22)
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
		Juice.bounce_control(_tin.book, 0.2 * Juice.effects_scale)
		SatchelSounds.play(&"pickup", self))


func _quad(a: Vector2, b: Vector2, c: Vector2, k: float) -> Vector2:
	return a.lerp(b, k).lerp(b.lerp(c, k), k)

