## Feyre's play HUD (plan §14, the chosen look in ui/icon-directions/
## CHOSEN_cute_thin_plum_line.png): one vitals block bottom left (status chips
## over the health bar, Feyre's bow as its crest), the grab ring in the centre,
## and her screen edges under everything. It reads her VitalsState and shows
## only what matters: meters stay (Always, the default), or appear when they
## change and fade at rest (Auto), or go (Off: the grab ring and the edges
## stay). Nothing shows while she is down. No words, no objectives.
## The block, the ring and the edges sit in HudLayout's VITALS, WORLD and EDGE
## zones, which decide where they are and when they show.
## Add one to an entry scene: add_child(VitalsHud.new()).
class_name VitalsHud
extends Node

enum Mode { CONTEXTUAL, ALWAYS, OFF }

## The block, top left to bottom right: two rows of chips, then the bow with
## the bar running from its arrow.
const BLOCK := Vector2(418, 234)
const STATUS_AT := Vector2(82, 0)
const BOW_AT := Vector2(0, 134)
const BAR_AT := Vector2(90, 174)
const HEALTH_SHOW_SECONDS := 4.0
const HEALTH_FULL_LINGER := 3.0
const STAMINA_FULL_LINGER := 1.2
const BUFF_SHOW_SECONDS := 5.0
const BUFF_TAIL_SECONDS := 15.0
const FADE_SPEED := 3.0
## Her thought on waking after a knockdown, by how she wakes (wake_line).
const WAKE_LINES := {
	&"human": "Cold woke me. The light had moved; I'd lost hours I didn't have. Up.",
	&"spring": "I came round on the ground, aching all over. Hours gone.",
	&"carried": "Someone must have carried me in. My head still rang.",
	&"gentle": "That knocked the air out of me. Up, slowly.",
}
const WAKE_LINE_SECONDS := 6.0
const HIT_FADE := 1.2
const EDGE_STRENGTH: Array[float] = [1.0, 0.5, 0.0]

var health_bar: VitalsHealthBar
var stamina_bow: VitalsStaminaBow
var status_row: VitalsStatusRow
var grab_prompt: VitalsGrabPrompt
var edge_fx: VitalsEdgeFx

var _root: Control
var _vitals: VitalsState
var _player: Node3D
var _health_timer: float = 0.0
var _stamina_timer: float = 0.0
var _health_alpha: float = 0.0
var _stamina_alpha: float = 0.0
var _status_alpha: float = 0.0
var _hit: float = 0.0
var _first_seen: Dictionary = {}
var _clock: float = 0.0


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	var hud := HudLayout.of(get_tree())
	edge_fx = VitalsEdgeFx.new()
	hud.place(edge_fx, HudLayout.Zone.EDGE, self)
	_root = Control.new()
	_root.name = "Vitals"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.custom_minimum_size = BLOCK
	hud.place(_root, HudLayout.Zone.VITALS, self)
	status_row = VitalsStatusRow.new()
	status_row.position = STATUS_AT
	_root.add_child(status_row)
	stamina_bow = VitalsStaminaBow.new()
	stamina_bow.position = BOW_AT
	_root.add_child(stamina_bow)
	health_bar = VitalsHealthBar.new()
	health_bar.position = BAR_AT
	_root.add_child(health_bar)
	# Resting the pointer on a meter names it, like a chip.
	for meter: Array in [[health_bar, &"health"], [stamina_bow, &"stamina"]]:
		var c := meter[0] as Control
		c.mouse_filter = Control.MOUSE_FILTER_PASS
		c.tooltip_text = "%s\n%s" % [StatusRules.title(meter[1]), StatusRules.blurb(meter[1])]
	grab_prompt = VitalsGrabPrompt.new()
	grab_prompt.visible = false
	hud.place(grab_prompt, HudLayout.Zone.WORLD, self)
	for c: CanvasItem in [status_row, stamina_bow, health_bar]:
		c.modulate.a = 0.0


func _process(delta: float) -> void:
	_clock += delta
	_attach()
	var mode := _mode()
	if _vitals == null:
		_root.visible = false
		edge_fx.target.clear()
		return
	var play := not _vitals.is_down
	_root.visible = true
	edge_fx.set_strength(EDGE_STRENGTH[clampi(_setting(&"edge_fx", 0), 0, 2)])
	_update_meters(delta, mode, play)
	_update_statuses(delta, mode, play)
	_update_grab()
	_update_edges(delta)


# --- Meters ------------------------------------------------------------------

func _update_meters(delta: float, mode: int, play: bool) -> void:
	var v := _vitals
	var human := v.in_human_realm()
	health_bar.human_realm = human
	health_bar.set_health(v.health_fraction())
	health_bar.points = roundi(v.health)
	health_bar.points_max = roundi(VitalsState.MAX_HEALTH)
	health_bar.regen_cap = v.regen_cap() / VitalsState.MAX_HEALTH
	health_bar.venom = v.affliction(&"venom")
	health_bar.healing = v.statuses().any(func(s: Dictionary) -> bool: return s.tag == &"heal")
	var stamina := float(_player.get(&"stamina")) if "stamina" in _player else 100.0
	var max_st := v.max_stamina()
	stamina_bow.fraction = clampf(stamina / max_st, 0.0, 1.0)
	stamina_bow.winded = _player.has_method(&"is_winded") and bool(_player.call(&"is_winded"))
	stamina_bow.set_buds(int(floor((max_st - 100.0) / 10.0 + 0.001)))
	_health_timer = maxf(_health_timer - delta, 0.0)
	if v.health < VitalsState.MAX_HEALTH - 0.05:
		_health_timer = maxf(_health_timer, HEALTH_FULL_LINGER)
	_stamina_timer = maxf(_stamina_timer - delta, 0.0)
	if stamina < max_st - 0.05:
		_stamina_timer = STAMINA_FULL_LINGER
	var want_health := 1.0 if _health_timer > 0.0 else 0.0
	var want_stamina := 1.0 if _stamina_timer > 0.0 else 0.0
	if mode == Mode.ALWAYS:
		want_health = 1.0
		want_stamina = 1.0
	elif mode == Mode.OFF or not play:
		want_health = 0.0
		want_stamina = 0.0
	# The bow is the bar's crest: it shows whenever the bar does.
	want_stamina = maxf(want_stamina, want_health)
	_health_alpha = move_toward(_health_alpha, want_health, delta * FADE_SPEED)
	_stamina_alpha = move_toward(_stamina_alpha, want_stamina, delta * FADE_SPEED)
	health_bar.modulate.a = _health_alpha
	stamina_bow.modulate.a = _stamina_alpha
	# Each meter is taught once, the first time it moves while she can see it.
	if play and mode != Mode.OFF:
		if v.health < VitalsState.MAX_HEALTH - 0.05:
			status_row.offer(&"health")
		if stamina < max_st - 0.05:
			status_row.offer(&"stamina")


func _on_health_changed(_health: float, _max_health: float, _delta: float, _source: StringName) -> void:
	_health_timer = HEALTH_SHOW_SECONDS


# --- Statuses ------------------------------------------------------------------

func _update_statuses(delta: float, mode: int, play: bool) -> void:
	var all := _vitals.statuses()
	var seen: Dictionary = {}
	var show: Array[Dictionary] = []
	for s in all:
		seen[s.tag] = true
		if not _first_seen.has(s.tag):
			_first_seen[s.tag] = _clock
		if mode == Mode.ALWAYS or _status_wanted(s):
			show.append(s)
	for tag: StringName in _first_seen.keys():
		if not seen.has(tag):
			_first_seen.erase(tag)
	status_row.set_statuses(show if mode != Mode.OFF and play else ([] as Array[Dictionary]))
	_status_alpha = move_toward(_status_alpha, 1.0 if not status_row.shown.is_empty() else 0.0, delta * FADE_SPEED)
	status_row.modulate.a = _status_alpha


## Contextual: dangers and the half-buff always; buffs when new and near their end.
func _status_wanted(s: Dictionary) -> bool:
	if StatusRules.kind(s.tag) != StatusRules.Kind.BUFF:
		return true
	if _clock - float(_first_seen.get(s.tag, _clock)) < BUFF_SHOW_SECONDS:
		return true
	return float(s.total) > 0.0 and float(s.seconds_left) < BUFF_TAIL_SECONDS


# --- Grab ----------------------------------------------------------------------

func _update_grab() -> void:
	var grabbed := _vitals.is_grabbed() and not _vitals.is_down
	grab_prompt.visible = grabbed
	if grabbed:
		grab_prompt.presses_total = _vitals.grab_presses_total
		grab_prompt.presses_left = _vitals.grab_presses_left
		grab_prompt.key_text = "A" if SatchelHud.pad_active else _key_label(&"interact")


func _key_label(action: StringName) -> String:
	if InputMap.has_action(action):
		for e in InputMap.action_get_events(action):
			var k := e as InputEventKey
			if k:
				var code := k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
				return OS.get_keycode_string(code)
	return "E"


# --- Edges ---------------------------------------------------------------------

func _update_edges(delta: float) -> void:
	var v := _vitals
	var body := _player.get(&"body_state") as BodyState
	var t := edge_fx.target
	t[&"dread"] = clampf((v.dread - 0.2) / 0.8, 0.0, 1.0)
	t[&"low_health"] = clampf((30.0 - v.health) / 30.0, 0.0, 1.0) * 0.8 + (0.2 if v.health < 30.0 and not v.is_down else 0.0)
	t[&"venom"] = clampf((v.affliction(&"venom") - 0.5) / 0.5, 0.0, 1.0)
	t[&"cold"] = clampf((body.cold - 0.5) / 0.5, 0.0, 1.0) if body else 0.0
	t[&"fae"] = clampf((body.fae_toll - 0.45) / 0.5, 0.0, 1.0) if body else 0.0
	t[&"ease"] = clampf(v.ease_pulse, 0.0, 1.0)
	t[&"heal"] = 1.0 if health_bar.healing else 0.0
	var drowsy := v.affliction(&"drowsy")
	var lid := 0.0
	if drowsy >= 0.5:
		var phase := fmod(_clock, 3.2)
		var blink := sin(phase / 0.6 * PI) if phase < 0.6 else 0.0
		lid = maxf((drowsy - 0.5) * 0.5, blink * drowsy * 0.9)
	t[&"drowsy_lid"] = lid
	var p := v.down_progress if v.is_down else 0.0
	t[&"stars"] = smoothstep(0.0, 0.12, p) * (1.0 - smoothstep(0.7, 0.85, p)) if v.is_down else 0.0
	t[&"iris"] = smoothstep(0.35, 0.75, p) if v.is_down else 0.0
	t[&"wake"] = v.wake_progress
	_hit = maxf(_hit - delta / HIT_FADE, 0.0)
	edge_fx.target[&"hit_amount"] = _hit
	edge_fx.set_frost_human(v.in_human_realm())


func _on_hit_taken(origin: Vector3, damage: float, _reaction: StringName) -> void:
	_health_timer = HEALTH_SHOW_SECONDS
	if not bool(_setting(&"hit_marks", true)):
		return
	_hit = clampf(damage / 30.0, 0.4, 1.0)
	edge_fx.set_hit(_screen_direction(origin), _hit)


## The attacker's direction on screen: up is in front of the camera.
func _screen_direction(origin: Vector3) -> Vector2:
	var cam := get_viewport().get_camera_3d()
	if origin == Vector3.INF or cam == null:
		return Vector2(0.0, -1.0)
	var local := cam.global_transform.basis.inverse() * (origin - cam.global_position)
	var d := Vector2(local.x, local.z)
	return d.normalized() if d.length_squared() > 0.0001 else Vector2(0.0, -1.0)


# --- Wiring --------------------------------------------------------------------

func _attach() -> void:
	if is_instance_valid(_vitals) and _vitals.is_inside_tree():
		return
	_vitals = null
	_player = get_tree().get_first_node_in_group(&"player") as Node3D
	var v := Vitals.of(_player)
	if v == null:
		return
	_vitals = v
	v.health_changed.connect(_on_health_changed)
	v.hit_taken.connect(_on_hit_taken)
	v.grab_press.connect(func(_left: int) -> void: grab_prompt.press())
	v.woke.connect(_on_woke)


## Her first thought on coming round after a knockdown (UX review G10).
func _on_woke(rest_id: StringName) -> void:
	LinePresenter.of(get_tree()).say(LinePresenter.Voice.THOUGHT, "", wake_line(rest_id), self, WAKE_LINE_SECONDS)


## Which waking thought fits: carried to a rest point, Gentle Mode (no time
## lost), or where she fell, in the human lands or past the wall.
func wake_line(rest_id: StringName) -> String:
	if rest_id != &"":
		return WAKE_LINES[&"carried"]
	if bool(_setting(&"gentle_mode", false)):
		return WAKE_LINES[&"gentle"]
	return WAKE_LINES[&"human" if _vitals and _vitals.in_human_realm() else &"spring"]


func _mode() -> int:
	return clampi(int(_setting(&"hud_mode", Mode.ALWAYS)), 0, 2)


func _setting(key: StringName, default: Variant) -> Variant:
	var settings := Gameplay.autoload(&"GameSettings")
	if settings == null:
		return default
	var value: Variant = settings.call(&"get_value", key)
	return default if value == null else value
