## The little mark on a menu-shell tab while its page has something new
## (Dreamlight's "new" dot). Drawn in the theme's accent, with a gold ring.
class_name NewsDot
extends Control

const RADIUS := 6.0


func _init() -> void:
	name = "News"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(RADIUS, RADIUS) * 2.0
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -RADIUS * 1.6
	offset_top = -RADIUS * 0.4
	offset_right = offset_left + RADIUS * 2.0
	offset_bottom = offset_top + RADIUS * 2.0


func _draw() -> void:
	var c := Vector2(RADIUS, RADIUS)
	draw_circle(c, RADIUS, SatchelTheme.color(&"accent"))
	draw_arc(c, RADIUS, 0.0, TAU, 20, SatchelTheme.color(&"line"), 1.5, true)
