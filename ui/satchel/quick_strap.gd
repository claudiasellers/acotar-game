## The quick bar's leather strap: a stitched band with a brass rivet where
## each ring hangs. Colours from SatchelTheme (ink for the leather, line for
## the stitching and brass).
class_name QuickStrap
extends Control

const BAND := 24.0
const STITCH_INSET := 4.0
const STITCH := 7.0

## Strap-space x of each ring's rivet.
var rivets: PackedFloat32Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var ink := SatchelTheme.color(&"ink")
	var line := SatchelTheme.color(&"line")
	var w := size.x
	var r := BAND * 0.5
	# Leather: a band with rounded ends.
	draw_rect(Rect2(r, 0, w - BAND, BAND), ink)
	draw_circle(Vector2(r, r), r, ink)
	draw_circle(Vector2(w - r, r), r, ink)
	draw_line(Vector2(r, 2), Vector2(w - r, 2), Color(ink.lightened(0.25), 0.6), 1.0)
	# Saddle stitching along both edges.
	for y in [STITCH_INSET, BAND - STITCH_INSET]:
		var x := BAND
		while x + STITCH < w - BAND:
			draw_line(Vector2(x, y), Vector2(x + STITCH * 0.6, y), Color(line, 0.75), 1.5, true)
			x += STITCH
	for x in rivets:
		draw_circle(Vector2(x, BAND - 3.0), 4.0, line.darkened(0.2))
		draw_circle(Vector2(x - 1.0, BAND - 4.0), 1.5, line.lightened(0.4))
