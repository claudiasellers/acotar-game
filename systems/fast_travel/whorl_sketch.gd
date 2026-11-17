## Her pictogram sketch of the stones she has marked, on the travel card, in
## the sketchbook ink straight on the card's paper: a whorl where each pair
## stands (laid out as the land lies, north up), a ring round the pair she
## stands at, and a dotted ride line to the one picked. Only marked stones are
## drawn, so it never shows land she hasn't walked. Colours and the font come
## from SatchelTheme (the card's theme).
class_name WhorlSketch
extends Control

const MARGIN := 40.0

var here: WhorlStoneDef
var stones: Array[WhorlStoneDef] = []
var picked: WhorlStoneDef
var _t: float = 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(400, 360)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func pick(d: WhorlStoneDef) -> void:
	picked = d
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	if picked:
		queue_redraw()


## World XZ -> this control, fitting every drawn stone with a margin.
func map_point(p: Vector2) -> Vector2:
	var lo := Vector2(INF, INF)
	var hi := -lo
	for d in _all():
		lo = lo.min(d.position)
		hi = hi.max(d.position)
	var span := (hi - lo).max(Vector2(400, 400))
	var mid := (lo + hi) * 0.5
	var inner := size - Vector2.ONE * MARGIN * 2.0
	var k := minf(inner.x / span.x, inner.y / span.y)
	return size * 0.5 + (p - mid) * k


func _all() -> Array[WhorlStoneDef]:
	var all: Array[WhorlStoneDef] = stones.duplicate()
	if here:
		all.append(here)
	return all


func _draw() -> void:
	var ink := SatchelTheme.color(&"ink")
	var accent := SatchelTheme.color(&"accent")
	# Place names in the satchel serif (the heading face) at the small size.
	var font := get_theme_font(&"font", &"SatchelHeading")
	var fsize := get_theme_font_size(&"font_size", &"SatchelSmall")
	if here and picked:
		_ride_line(map_point(here.position), map_point(picked.position), accent)
	for d in _all():
		var at := map_point(d.position)
		var col := Color(ink, 0.55) if d.blight else ink
		var r := 13.0
		if d == picked:
			r = 15.0 + 1.5 * sin(_t * 5.0)
			draw_circle(at, r + 7.0, Color(accent, 0.22))
		if d == here:
			draw_arc(at, r + 6.0, 0.0, TAU, 32, Color(ink, 0.8), 1.5, true)
		WhorlInk.ink_whorl(self, at, r, col, 2.2)
		var label := WhorlStones.place_label(d)
		var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
		var lx := clampf(at.x - w * 0.5, 6.0, size.x - w - 6.0)
		draw_string(font, Vector2(lx, at.y + r + fsize + 4.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, col)


func _ride_line(a: Vector2, b: Vector2, col: Color) -> void:
	var n := maxi(2, int(a.distance_to(b) / 9.0))
	for i in n:
		if i % 2 == 0:
			draw_line(a.lerp(b, float(i) / n), a.lerp(b, float(i + 1) / n), Color(col, 0.85), 2.0, true)
