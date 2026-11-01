## Spoken lines in Act II scenes: a soft pearl-and-gold caption low on the
## screen, the speaker's name in rose, fading in and out. Lines are what
## people say to Feyre; she never picks a reply (R2: no dialogue choices).
class_name Act2Caption
extends CanvasLayer

const GROUP := &"act2_caption"
const FADE := 0.35

var panel: PanelContainer
var who_label: Label
var text_label: Label
## The line on screen now ("" when hidden), for tests and the playtest log.
var showing: String = ""
var _left: float = 0.0


static func find_or_make(owner: Node) -> Act2Caption:
	var existing := owner.get_tree().get_first_node_in_group(GROUP) as Act2Caption
	if existing:
		return existing
	var caption := Act2Caption.new()
	owner.get_tree().root.add_child(caption)
	return caption


func _init() -> void:
	name = "Act2Caption"
	layer = 25
	add_to_group(GROUP)
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override(&"panel", UiStyle.panel_box())
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.anchor_left = 0.2
	panel.anchor_right = 0.8
	panel.anchor_top = 0.82
	panel.anchor_bottom = 0.82
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	who_label = UiStyle.label("", 17)
	who_label.add_theme_color_override(&"font_color", UiStyle.ACCENT)
	text_label = UiStyle.label("", 22)
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	who_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(who_label)
	box.add_child(text_label)
	panel.add_child(box)
	panel.modulate.a = 0.0
	add_child(panel)


## Shows one line for about as long as it takes to read it.
func say(who: String, text: String, seconds: float = -1.0) -> float:
	who_label.text = who
	who_label.visible = who != ""
	text_label.text = text
	showing = text
	_left = seconds if seconds > 0.0 else reading_time(text)
	var tween := panel.create_tween()
	tween.tween_property(panel, ^"modulate:a", 1.0, FADE)
	return _left


static func reading_time(text: String) -> float:
	return clampf(1.2 + text.split(" ", false).size() * 0.28, 1.8, 6.0)


func _process(delta: float) -> void:
	if _left <= 0.0:
		return
	_left -= delta
	if _left <= 0.0:
		showing = ""
		var tween := panel.create_tween()
		tween.tween_property(panel, ^"modulate:a", 0.0, FADE)
