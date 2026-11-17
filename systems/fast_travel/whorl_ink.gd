## The whorl as she draws it, in the sketchbook ink: a spiral of two and a half
## turns, outside in. `progress` 0..1 draws it stroke by stroke (the ride's
## inking beat); the travel card's sketch draws it whole.
class_name WhorlInk
extends Control

const TURNS := 2.6
const STEPS := 48

var progress: float = 1.0:
	set(v):
		progress = clampf(v, 0.0, 1.0)
		queue_redraw()
var ink: Color = Color(0.42, 0.30, 0.46)
var width: float = 4.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	ink_whorl(self, size * 0.5, minf(size.x, size.y) * 0.45, ink, width, progress)


## Draws a whorl on any CanvasItem (the sketch's pictograms use this too).
static func ink_whorl(on: CanvasItem, at: Vector2, r: float, col: Color, w: float, amount: float = 1.0) -> void:
	var n := int(STEPS * clampf(amount, 0.0, 1.0))
	if n < 2:
		return
	var pts := PackedVector2Array()
	for i in n:
		var t := i / float(STEPS - 1)
		var a := TURNS * TAU * t
		pts.append(at + Vector2(cos(a), sin(a)) * r * (1.0 - 0.86 * t))
	on.draw_polyline(pts, col, w, true)
