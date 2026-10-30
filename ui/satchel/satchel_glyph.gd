## A small drawn satchel for the quick bar's badge, in the theme's ink and
## accent colours (no texture until the UI look lane ships one).
class_name SatchelGlyph
extends Control

const ICON_PATH := "res://ui/theme/icons/satchel.png"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(ICON_PATH):
		var tex := TextureRect.new()
		tex.texture = load(ICON_PATH)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(tex)


func _draw() -> void:
	if get_child_count() > 0:
		return
	var ink := SatchelTheme.color(&"ink")
	var accent := SatchelTheme.color(&"accent")
	var w := size.x
	var h := size.y
	# Strap, body, flap, buckle.
	draw_arc(Vector2(w * 0.5, h * 0.42), w * 0.30, PI, TAU, 16, ink, 2.0, true)
	var body := Rect2(w * 0.12, h * 0.40, w * 0.76, h * 0.54)
	draw_rect(body, Color(accent, 0.85))
	draw_rect(body, ink, false, 2.0)
	var flap := PackedVector2Array([Vector2(w * 0.12, h * 0.40), Vector2(w * 0.88, h * 0.40),
			Vector2(w * 0.80, h * 0.68), Vector2(w * 0.20, h * 0.68)])
	draw_colored_polygon(flap, Color(accent.lightened(0.25), 0.95))
	draw_polyline(flap + PackedVector2Array([flap[0]]), ink, 2.0, true)
	draw_circle(Vector2(w * 0.5, h * 0.66), w * 0.06, ink)
