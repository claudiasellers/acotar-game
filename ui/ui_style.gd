## Shared look for gameplay panels: soft pastel cards, rounded, gold accents (R3).
class_name UiStyle
extends RefCounted

const BG := Color(0.99, 0.94, 0.96, 0.94)
const BORDER := Color(0.90, 0.74, 0.42)
const TEXT := Color(0.36, 0.22, 0.32)
const ACCENT := Color(0.96, 0.62, 0.76)
const SELECTED := Color(0.80, 0.70, 0.98)


static func panel_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = BG
	box.border_color = BORDER
	box.set_border_width_all(3)
	box.set_corner_radius_all(22)
	box.set_content_margin_all(18)
	box.shadow_color = Color(0.6, 0.3, 0.5, 0.25)
	box.shadow_size = 12
	return box


static func button(text: String, toggle: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = toggle
	b.focus_mode = Control.FOCUS_ALL
	for state in ["normal", "hover", "pressed", "focus"]:
		var box := StyleBoxFlat.new()
		box.set_corner_radius_all(14)
		box.set_content_margin_all(8)
		box.bg_color = Color(1, 1, 1, 0.9) if state == "normal" else (SELECTED if state == "pressed" else Color(1.0, 0.88, 0.93))
		box.border_color = BORDER if state != "normal" else Color(BORDER, 0.5)
		box.set_border_width_all(2)
		b.add_theme_stylebox_override(state, box)
	b.add_theme_color_override(&"font_color", TEXT)
	b.add_theme_color_override(&"font_pressed_color", TEXT)
	b.add_theme_color_override(&"font_hover_color", TEXT)
	b.pressed.connect(func() -> void: Juice.bounce_control(b, 0.06))
	return b


static func label(text: String, size: int = 18) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## A centred card on its own CanvasLayer that pauses the game while open.
static func modal(owner_name: String, width: float = 760.0) -> Array:
	var layer := CanvasLayer.new()
	layer.name = owner_name
	layer.layer = 20
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(&"panel", panel_box())
	panel.custom_minimum_size = Vector2(width, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 10)
	panel.add_child(box)
	return [layer, box]
