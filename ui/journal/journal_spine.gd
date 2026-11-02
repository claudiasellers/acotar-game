## The sketchbook's spiral binding (L54): gilt wire rings through punched
## holes down the gutter between the two pages. Colours from SatchelTheme.
class_name JournalSpine
extends Control

const RINGS := 16
const MARGIN := 46.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var wire := SatchelTheme.color(&"line")
	var shine := SatchelTheme.color(&"glow")
	var hole := SatchelTheme.color(&"ink_soft") if SatchelTheme.theme().has_color(&"ink_soft", SatchelTheme.COLOR_TYPE) \
			else SatchelTheme.color(&"ink")
	var step := (size.y - MARGIN * 2.0) / float(RINGS - 1)
	var cx := size.x * 0.5
	var half := size.x * 0.5 - 6.0
	for i in RINGS:
		var y := MARGIN + step * i
		draw_circle(Vector2(cx - half + 4.0, y), 5.0, Color(hole, 0.55))
		draw_circle(Vector2(cx + half - 4.0, y), 5.0, Color(hole, 0.55))
		var pts := PackedVector2Array()
		for k in 17:
			var a := PI + PI * float(k) / 16.0
			pts.append(Vector2(cx + cos(a) * half, y - 4.0 + sin(a) * 12.0))
		draw_polyline(pts, Color(hole, 0.35), 6.0, true)
		draw_polyline(pts, wire, 4.0, true)
		var hi := pts.slice(5, 12)
		for j in hi.size():
			hi[j] += Vector2(0, -1.2)
		draw_polyline(hi, Color(shine, 0.9), 1.5, true)
