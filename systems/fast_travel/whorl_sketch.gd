## Her pictogram sketch of the stones she has marked, on the travel card: a
## spiral where each pair stands (laid out as the land lies, north up), a gold
## ring on the pair she stands at, and a dotted ride line to the one picked.
## Only marked stones are drawn, so it never shows her land she hasn't walked.
class_name WhorlSketch
extends Control

const PAPER := Color(1.0, 0.97, 0.93)
const INK := Color(0.42, 0.30, 0.46)
const GOLD := Color(0.88, 0.70, 0.36)
const ROSE := Color(0.93, 0.52, 0.68)
const BLIGHT := Color(0.40, 0.38, 0.42)
const MARGIN := 34.0

var here: WhorlStoneDef
var stones: Array[WhorlStoneDef] = []
var picked: WhorlStoneDef
var _t: float = 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(420, 380)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func pick(d: WhorlStoneDef) -> void:
	picked = d
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	if picked:
		queue_redraw()


## World XZ -> this control, fitting every drawn stone with a margin.
func to_local_point(p: Vector2) -> Vector2:
	var all: Array[WhorlStoneDef] = stones.duplicate()
	if here:
		all.append(here)
	var lo := Vector2(INF, INF)
	var hi := -lo
	for d in all:
		lo = lo.min(d.position)
		hi = hi.max(d.position)
	var span := (hi - lo).max(Vector2(400, 400))
	var mid := (lo + hi) * 0.5
	var inner := size - Vector2.ONE * MARGIN * 2.0
	var k := minf(inner.x / span.x, inner.y / span.y)
	return size * 0.5 + (p - mid) * k


func _draw() -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = PAPER
	box.set_corner_radius_all(16)
	box.border_color = Color(GOLD, 0.6)
	box.set_border_width_all(2)
	draw_style_box(box, Rect2(Vector2.ZERO, size))
	var font := get_theme_default_font()
	if here and picked:
		_ride_line(to_local_point(here.position), to_local_point(picked.position))
	var all: Array[WhorlStoneDef] = stones.duplicate()
	if here:
		all.append(here)
	for d in all:
		var at := to_local_point(d.position)
		var col := BLIGHT if d.blight else INK
		var r := 13.0
		if d == picked:
			r = 15.0 + 1.5 * sin(_t * 5.0)
			draw_circle(at, r + 7.0, Color(ROSE, 0.28))
		if d == here:
			draw_arc(at, r + 6.0, 0.0, TAU, 32, GOLD, 2.5, true)
		_spiral(at, r, col)
		var label := WhorlStones.place_label(d)
		var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		var lx := clampf(at.x - w * 0.5, 6.0, size.x - w - 6.0)
		draw_string(font, Vector2(lx, at.y + r + 18.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, col)


## The whorl as she'd draw it: a spiral in two and a half turns, outside in.
func _spiral(at: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 40:
		var t := i / 39.0
		var a := 2.6 * TAU * t
		pts.append(at + Vector2(cos(a), sin(a)) * r * (1.0 - 0.86 * t))
	draw_polyline(pts, col, 2.2, true)


func _ride_line(a: Vector2, b: Vector2) -> void:
	var n := maxi(2, int(a.distance_to(b) / 9.0))
	for i in n:
		if i % 2 == 0:
			var p0 := a.lerp(b, float(i) / n)
			var p1 := a.lerp(b, float(i + 1) / n)
			draw_line(p0, p1, Color(ROSE, 0.85), 2.5, true)
