## The sketchbook's sewn spine (L54): the pages fold into a shadowed gutter
## and are sewn through it with thread, a running stitch down the fold and
## kettle stitches over five linen tapes, the way a bookbinder (or Feyre,
## with Alis's needle) would bind loose sheets. Colours from SatchelTheme.
class_name JournalSpine
extends Control

const STATIONS := 5
const MARGIN := 40.0
## Width of the shadow the fold casts onto each page.
const SHADE := 70.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _col(n: StringName, fallback: StringName = &"ink") -> Color:
	return SatchelTheme.color(n) if SatchelTheme.theme().has_color(n, SatchelTheme.COLOR_TYPE) \
			else SatchelTheme.color(fallback)


func _draw() -> void:
	var ink := SatchelTheme.color(&"ink")
	var thread := SatchelTheme.color(&"accent")
	var shine := SatchelTheme.color(&"glow")
	var tape := _col(&"paper_deep", &"paper")
	var cx := size.x * 0.5
	# The fold: pages curving down into the gutter.
	for i in int(SHADE):
		var t := float(i) / SHADE
		var a := 0.30 * pow(1.0 - t, 2.2)
		draw_line(Vector2(cx - i, 0), Vector2(cx - i, size.y), Color(ink, a), 1.0)
		draw_line(Vector2(cx + i, 0), Vector2(cx + i, size.y), Color(ink, a), 1.0)
	draw_line(Vector2(cx, 6), Vector2(cx, size.y - 6), Color(ink, 0.45), 1.5, true)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	# Running stitch down the fold.
	var y := MARGIN
	while y < size.y - MARGIN:
		var len := rng.randf_range(16.0, 22.0)
		var x := cx + rng.randf_range(-0.6, 0.6)
		draw_line(Vector2(x, y), Vector2(x, y + len), Color(ink, 0.35), 4.0, true)
		draw_line(Vector2(x, y), Vector2(x, y + len), thread, 2.6, true)
		draw_line(Vector2(x - 0.6, y + 2), Vector2(x - 0.6, y + len - 3), Color(shine, 0.6), 0.8, true)
		draw_circle(Vector2(x, y + len + 4.0), 1.6, Color(ink, 0.5))
		y += len + 9.0
	# Kettle stitches over linen tapes.
	var step := (size.y - MARGIN * 2.0) / float(STATIONS - 1)
	for i in STATIONS:
		var sy := MARGIN + step * i
		var r := Rect2(cx - 26.0, sy - 9.0, 52.0, 18.0)
		draw_rect(r, Color(tape, 0.92))
		draw_rect(r, Color(ink, 0.25), false, 1.0)
		for k in 3:
			var ky := sy - 6.0 + k * 6.0
			draw_line(Vector2(cx - 24.0, ky), Vector2(cx + 24.0, ky), Color(ink, 0.08), 1.0)
		for s in [-1.0, 1.0]:
			draw_line(Vector2(cx - 12.0, sy - 12.0 * s), Vector2(cx + 12.0, sy + 12.0 * s), Color(ink, 0.3), 4.0, true)
			draw_line(Vector2(cx - 12.0, sy - 12.0 * s), Vector2(cx + 12.0, sy + 12.0 * s), thread, 2.6, true)
