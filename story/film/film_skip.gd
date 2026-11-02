## Hold-to-skip for films: any confirm or escape input shows a small gilt ring
## in the corner; holding it HOLD seconds, or pressing twice within DOUBLE
## seconds, skips. The ring fades when untouched. Emits `skip`.
class_name FilmSkip
extends Control

signal skip

const HOLD := 0.8
const DOUBLE := 0.6
const ACTIONS: Array[StringName] = [&"interact", &"ui_accept", &"pause", &"ui_cancel", &"fire"]
const GOLD := Color(0.96, 0.84, 0.52)
const FONT := preload("res://ui/title/fonts/EBGaramond-MediumItalic.ttf")

var held: float = 0.0
var _shown: float = 0.0
var _last_press_ms: int = -100000
var _done: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	modulate.a = 0.0


## True when `event` is one of the skip inputs being pressed.
static func is_skip_press(event: InputEvent) -> bool:
	if event.is_echo():
		return false
	for a in ACTIONS:
		if InputMap.has_action(a) and event.is_action_pressed(a):
			return true
	return false


func press() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_press_ms < int(DOUBLE * 1000.0):
		_fire()
	_last_press_ms = now
	_shown = 2.0


func _any_held() -> bool:
	for a in ACTIONS:
		if InputMap.has_action(a) and Input.is_action_pressed(a):
			return true
	return false


func _process(delta: float) -> void:
	if _done:
		return
	if _any_held() and _shown > 0.0:
		held += delta
		_shown = 2.0
		if held >= HOLD:
			_fire()
	else:
		held = maxf(0.0, held - delta * 2.0)
	_shown -= delta
	modulate.a = move_toward(modulate.a, 1.0 if _shown > 0.0 else 0.0, delta * 4.0)
	queue_redraw()


func _fire() -> void:
	if _done:
		return
	_done = true
	skip.emit()


func _draw() -> void:
	var vs := get_viewport_rect().size
	var bar := maxf(0.0, (vs.y - vs.x / Cine.BAR_ASPECT) * 0.5)
	var c := Vector2(vs.x - 70.0, vs.y - bar * 0.5 - 2.0)
	if bar < 40.0:
		c.y = vs.y - 60.0
	draw_arc(c, 15.0, 0.0, TAU, 48, Color(GOLD, 0.25), 2.0, true)
	var k := clampf(held / HOLD, 0.0, 1.0)
	if k > 0.0:
		draw_arc(c, 15.0, -PI * 0.5, -PI * 0.5 + TAU * k, 48, GOLD, 3.0, true)
	draw_string(FONT, c + Vector2(-150.0, 7.0), "hold to skip", HORIZONTAL_ALIGNMENT_RIGHT, 120.0, 20, Color(GOLD, 0.85))
