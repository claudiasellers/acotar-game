## Fine gilt ornament drawn over a panel: an inset hairline with a small
## leaf-whorl at each corner, or (divider mode) a rule with a rose lozenge.
class_name GiltFrameDecor
extends Control

enum Mode { FRAME, DIVIDER }

var mode: Mode = Mode.FRAME


func _init(as_mode: Mode = Mode.FRAME) -> void:
	mode = as_mode
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if mode == Mode.DIVIDER:
		custom_minimum_size = Vector2(0, 16)


func _draw() -> void:
	if mode == Mode.DIVIDER:
		_draw_divider()
		return
	var r := Rect2(Vector2.ONE * 4.0, size - Vector2.ONE * 8.0)
	draw_rect(r, Color(DressingStyle.GILT, 0.8), false, 1.0, true)
	for corner: Vector2 in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
		var inward := (r.get_center() - corner).sign()
		_whorl(corner, inward)


## Two small curling leaves and a gilt bead tucked into a corner.
func _whorl(at: Vector2, inward: Vector2) -> void:
	var gilt := DressingStyle.GILT_DEEP
	draw_circle(at, 3.0, DressingStyle.GILT, true, -1.0, true)
	for axis: Vector2 in [Vector2(inward.x, 0), Vector2(0, inward.y)]:
		var tip := at + axis * 22.0
		var bend := at + axis * 12.0 + (inward - axis) * 7.0
		draw_polyline(_curve(at + axis * 4.0, bend, tip), gilt, 1.4, true)
		draw_circle(tip, 1.6, gilt, true, -1.0, true)


func _draw_divider() -> void:
	var mid := size * 0.5
	var gilt := DressingStyle.GILT
	draw_line(Vector2(0, mid.y), Vector2(mid.x - 16, mid.y), Color(gilt, 0.85), 1.0, true)
	draw_line(Vector2(mid.x + 16, mid.y), Vector2(size.x, mid.y), Color(gilt, 0.85), 1.0, true)
	var lozenge := PackedVector2Array([mid + Vector2(-9, 0), mid + Vector2(0, -6), mid + Vector2(9, 0), mid + Vector2(0, 6)])
	draw_colored_polygon(lozenge, gilt)
	draw_circle(mid, 2.6, DressingStyle.ROSE, true, -1.0, true)
	for s: float in [-1.0, 1.0]:
		draw_circle(mid + Vector2(s * 13.0, 0), 1.4, gilt, true, -1.0, true)


static func _curve(a: Vector2, ctrl: Vector2, b: Vector2, steps: int = 10) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in steps + 1:
		var t := float(i) / steps
		pts.append(a.lerp(ctrl, t).lerp(ctrl.lerp(b, t), t))
	return pts
