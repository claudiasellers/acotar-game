## The screen between Continue and play: the cream the title's crossing washes
## to, so the crossing runs straight into it, with a line saying what's going
## on, breathing while the world builds behind it. Lifts once Feyre has ground
## under her. Regions that build in one long frame stall the breath, not the look.
class_name LoadingVeil
extends CanvasLayer

const CREAM := Color(1.0, 0.95, 0.86, 1.0)
const INK := Color(0.42, 0.29, 0.34)
const FONT := preload("res://ui/title/fonts/EBGaramond-MediumItalic.ttf")
const LINE := "Returning…"
const FADE_SECONDS := 0.6
const BREATH_SECONDS := 2.4
const BREATH_LOW := 0.55
## Lifts anyway after this long (PlayerPlacement gives up on ground at 45 s).
const MAX_SECONDS := 60.0

## Seconds from Continue reaching the game scene to Feyre having control.
var seconds_to_control: float = -1.0

var _started_msec: int = 0
var _fill: ColorRect
var _label: Label
var _lifting: bool = false


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_started_msec = Time.get_ticks_msec()
	_fill = ColorRect.new()
	_fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fill.color = CREAM
	add_child(_fill)
	_label = Label.new()
	_label.text = LINE
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_override(&"font", FONT)
	_label.add_theme_font_size_override(&"font_size", 44)
	_label.add_theme_color_override(&"font_color", INK)
	_fill.add_child(_label)


func _process(_delta: float) -> void:
	if _lifting:
		return
	var waited := (Time.get_ticks_msec() - _started_msec) / 1000.0
	_label.modulate.a = lerpf(BREATH_LOW, 1.0, 0.5 + 0.5 * cos(TAU * waited / BREATH_SECONDS))
	var feyre := get_tree().get_first_node_in_group(&"player") as Node3D
	if (feyre != null and feyre.is_physics_processing()) or waited >= MAX_SECONDS:
		_lift(waited)


func _lift(waited: float) -> void:
	_lifting = true
	seconds_to_control = waited
	print("Continue: %.1f s to control" % waited)
	var tw := create_tween()
	tw.tween_property(_fill, ^"modulate:a", 0.0, FADE_SECONDS)
	tw.tween_callback(queue_free)
