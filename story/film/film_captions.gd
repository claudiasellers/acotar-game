## The film's words on screen: narration in gilt-edged italic, centred low in
## the frame, and spoken lines upright. Each fades in with a slight rise and
## fades out; a new line replaces the last. Purely presentational.
class_name FilmCaptions
extends Control

const FONT_ITALIC := preload("res://ui/title/fonts/EBGaramond-MediumItalic.ttf")
const FONT_UPRIGHT := preload("res://ui/title/fonts/EBGaramond-Medium.ttf")
const FADE_IN := 0.55
const FADE_OUT := 0.6
const RISE := 10.0
## Distance of the text's baseline above the bottom letterbox bar (px at 1080p).
const LIFT := 74.0
const NARRATION := Color(1.0, 0.96, 0.9)
## Spoken lines tint by speaker, so a newcomer can tell voices apart.
const SPEAKERS := {
	&"feyre": Color(1.0, 0.95, 0.88), &"tamlin": Color(1.0, 0.9, 0.7),
	&"lucien": Color(1.0, 0.82, 0.74), &"rhysand": Color(0.86, 0.82, 1.0),
	&"alis": Color(0.92, 0.96, 0.86),
}

var current: FilmLine
## How far the letterbox is in (the captions sit just above the bottom bar).
var bars_k: float = 1.0
var _label: Label
var _tween: Tween


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_constant_override(&"outline_size", 0)
	_label.add_theme_constant_override(&"shadow_offset_x", 0)
	_label.add_theme_constant_override(&"shadow_offset_y", 2)
	_label.add_theme_constant_override(&"shadow_outline_size", 10)
	_label.add_theme_color_override(&"font_shadow_color", Color(0.05, 0.02, 0.08, 0.75))
	_label.add_theme_constant_override(&"line_spacing", 4)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.modulate.a = 0.0
	add_child(_label)
	resized.connect(_layout)
	get_viewport().size_changed.connect(_layout)
	_layout()


## The bottom bar's height for a 2.39:1 frame at this size (0 with no bars).
func _bar(k: float) -> float:
	var s := _frame()
	return maxf(0.0, (s.y - s.x / Cine.BAR_ASPECT) * 0.5) * k


## The screen, not this control's own size: under a CanvasLayer that can still
## be zero on the frame a line first shows, which wrapped it one letter a line.
func _frame() -> Vector2:
	return get_viewport_rect().size


func _layout() -> void:
	var s := _frame()
	var w := minf(s.x * 0.62, 1180.0)
	_label.custom_minimum_size = Vector2(w, 0.0)
	_label.size = Vector2(w, 220.0)
	_label.position = Vector2((s.x - w) * 0.5, s.y - _bar(bars_k) - LIFT - 220.0)


func show_line(line: FilmLine) -> void:
	current = line
	var spoken := line.speaker != &""
	_label.add_theme_font_override(&"font", FONT_UPRIGHT if spoken else FONT_ITALIC)
	_label.add_theme_font_size_override(&"font_size", 36 if spoken else 40)
	_label.add_theme_color_override(&"font_color", SPEAKERS.get(line.speaker, NARRATION) as Color)
	_label.text = line.text
	_layout()
	if _tween:
		_tween.kill()
	var rest := _label.position.y
	_label.position.y = rest + RISE
	_label.modulate.a = 0.0
	_tween = create_tween().set_parallel()
	_tween.tween_property(_label, ^"modulate:a", 1.0, FADE_IN)
	_tween.tween_property(_label, ^"position:y", rest, FADE_IN * 1.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.chain().tween_interval(maxf(0.0, line.hold - FADE_IN - FADE_OUT))
	_tween.chain().tween_property(_label, ^"modulate:a", 0.0, FADE_OUT)


func clear(seconds: float = 0.4) -> void:
	current = null
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_label, ^"modulate:a", 0.0, seconds)


func showing_text() -> String:
	return _label.text if _label.modulate.a > 0.01 else ""
