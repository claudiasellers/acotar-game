## The mirror Feyre stands in: a tall arched frame of layered gilt mouldings
## with a rose and leaf-whorls on the crest, drawn so it scales to any screen.
class_name GiltMirrorFrame
extends Control

const ARCH_SEGMENTS := 48


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	# Mouldings from the outside in: a dark edge, the broad gilt band, a bright bead.
	_arch(0.0, DressingStyle.GILT_DEEP, 3.0)
	_arch(5.0, DressingStyle.GILT, 7.0)
	_arch(9.0, DressingStyle.GILT_LIGHT, 2.0)
	_arch(13.0, DressingStyle.GILT_DEEP, 1.5)
	_arch(19.0, DressingStyle.GILT, 3.0)
	_arch(23.0, Color(DressingStyle.GILT_DEEP, 0.6), 1.0)
	_crest(Vector2(size.x * 0.5, 4.0))
	for x: float in [size.x * 0.5 - 42.0, size.x * 0.5 + 42.0]:
		draw_circle(Vector2(x, size.y - 2.0), 4.0, DressingStyle.GILT, true, -1.0, true)


## A round-topped outline inset by `inset`, as one closed polyline.
func _arch(inset: float, colour: Color, width: float) -> void:
	# An elliptical crown, so a wide frame still reads as a tall mirror.
	var rx := size.x * 0.5 - inset
	var ry := minf(size.x * 0.5, size.y * 0.3) - inset
	var centre := Vector2(size.x * 0.5, inset + ry)
	var pts := PackedVector2Array()
	pts.append(Vector2(inset, size.y - inset))
	for i in ARCH_SEGMENTS + 1:
		var a := PI + PI * float(i) / ARCH_SEGMENTS
		pts.append(centre + Vector2(cos(a) * rx, sin(a) * ry))
	pts.append(Vector2(size.x - inset, size.y - inset))
	pts.append(Vector2(inset, size.y - inset))
	draw_polyline(pts, colour, width, true)


## A rose bud between two emerald leaf-whorls (Tamlin's mask leaves, no mask).
func _crest(top: Vector2) -> void:
	var gilt := DressingStyle.GILT
	for s: float in [-1.0, 1.0]:
		var leaf := PackedVector2Array([top, top + Vector2(s * 16, -4), top + Vector2(s * 30, 4), top + Vector2(s * 16, 8)])
		draw_colored_polygon(leaf, DressingStyle.EMERALD)
		draw_polyline(PackedVector2Array([top, top + Vector2(s * 26, 4)]), gilt, 1.2, true)
		draw_circle(top + Vector2(s * 38, 6), 2.2, gilt, true, -1.0, true)
	draw_circle(top, 11.0, DressingStyle.GILT_DEEP, true, -1.0, true)
	draw_circle(top, 9.0, DressingStyle.ROSE, true, -1.0, true)
	draw_arc(top, 5.0, 0.4, TAU - 0.4, 16, Color("#C9688C"), 1.6, true)
	draw_circle(top, 2.0, Color("#C9688C"), true, -1.0, true)
