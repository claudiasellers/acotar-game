## The sketchbook's tie (L54): a leather thong from the back board, wound
## twice round a horn button and knotted, its tails hanging loose.
## Colours from SatchelTheme.
class_name JournalTie
extends Control


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(150, 220)


func _draw() -> void:
	var ink := SatchelTheme.color(&"ink")
	var thong := ink.lerp(SatchelTheme.color(&"accent"), 0.35)
	var glow := SatchelTheme.color(&"glow")
	var c := Vector2(30, size.y * 0.42)
	# Two wraps round the button.
	for k in 2:
		var pts := PackedVector2Array()
		for i in 25:
			var a := float(i) / 24.0 * TAU
			pts.append(c + Vector2(cos(a) * (26.0 + k * 4.0), sin(a) * (16.0 + k * 3.0)))
		draw_polyline(pts, Color(ink, 0.45), 9.0, true)
		draw_polyline(pts, thong, 6.0, true)
		draw_polyline(pts, Color(glow, 0.35), 1.5, true)
	# Tails, swinging off the board.
	for t in [[Vector2(60, 150), Vector2(96, 210)], [Vector2(84, 120), Vector2(140, 170)]]:
		var a: Vector2 = c + Vector2(14, 8)
		var pts := PackedVector2Array()
		for i in 17:
			var s := float(i) / 16.0
			pts.append(a.bezier_interpolate(a + Vector2(30, 6), t[0], t[1], s))
		draw_polyline(pts, Color(ink, 0.45), 9.0, true)
		draw_polyline(pts, thong, 6.0, true)
		draw_polyline(pts, Color(glow, 0.35), 1.5, true)
		draw_circle(t[1], 5.5, thong)
	# The horn button.
	draw_circle(c, 15.0, Color(ink, 0.45))
	draw_circle(c, 13.0, glow)
	draw_circle(c + Vector2(-3, -3), 3.0, Color(glow.lightened(0.7), 0.55))
	draw_circle(c + Vector2(-3, 0), 1.6, Color(ink, 0.6))
	draw_circle(c + Vector2(3, 0), 1.6, Color(ink, 0.6))
