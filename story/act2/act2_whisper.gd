## A voice inside Feyre's head (the Bogge's pleas): no panel, no speaker,
## just words in the middle of her view that tremble and bleed in and out.
## Deliberately unlike Act2Caption's soft pastel card (R3: horror is never
## dressed up as the pretty UI). Never a choice (R2).
class_name Act2Whisper
extends CanvasLayer

const GROUP := &"act2_whisper"
const FADE := 0.35

var label: Label
var showing: String = ""
var tremble: float = 1.0

var _left: float = 0.0
var _t: float = 0.0
var _rest: Vector2


static func find_or_make(owner: Node) -> Act2Whisper:
	var tree := owner.get_tree() if owner.is_inside_tree() else null
	if tree:
		var existing := tree.get_first_node_in_group(GROUP) as Act2Whisper
		if existing:
			return existing
	var w := Act2Whisper.new()
	owner.add_child(w)
	return w


func _init() -> void:
	name = "Act2Whisper"
	layer = 26
	add_to_group(GROUP)
	label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.anchor_left = 0.12
	label.anchor_right = 0.88
	label.anchor_top = 0.36
	label.anchor_bottom = 0.5
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override(&"font_size", 34)
	label.add_theme_color_override(&"font_color", Color(0.78, 0.8, 0.74))
	label.add_theme_color_override(&"font_shadow_color", Color(0.25, 0.0, 0.02, 0.9))
	label.add_theme_constant_override(&"shadow_offset_x", 0)
	label.add_theme_constant_override(&"shadow_offset_y", 0)
	label.add_theme_constant_override(&"shadow_outline_size", 14)
	label.modulate.a = 0.0
	add_child(label)


func say(text: String, seconds: float = 3.0) -> void:
	label.text = text
	showing = text
	_left = seconds
	label.modulate.a = 0.0
	var tween := label.create_tween()
	tween.tween_property(label, ^"modulate:a", 0.92, FADE)


func _process(delta: float) -> void:
	_t += delta
	if _rest == Vector2.ZERO:
		_rest = label.position
	# It shakes like breath through clenched teeth.
	label.position = _rest + Vector2(sin(_t * 37.0) * 1.6, cos(_t * 29.0) * 1.2) * tremble
	if _left > 0.0:
		_left -= delta
		if _left <= 0.0:
			showing = ""
			var tween := label.create_tween()
			tween.tween_property(label, ^"modulate:a", 0.0, FADE * 2.0)
