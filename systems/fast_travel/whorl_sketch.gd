## Her pictogram sketch of the stones she has marked, on the travel card, in
## the sketchbook ink straight on the card's paper: a whorl where each pair
## stands (laid out as the land lies, north up), a ring round the pair she
## stands at, and a dotted ride line to the one picked. Only marked stones are
## drawn, so it never shows land she hasn't walked. Colours and the font come
## from JournalTheme (the card's theme).
class_name WhorlSketch
extends Control

const MARGIN := 40.0
## A whorl's radius on the sketch, and the clear air a name keeps from other
## names and other whorls.
const MARK := 13.0
const LABEL_AIR := 10.0
## A whorl's ring and glow reach this far past its radius; names keep off them.
const MARK_HALO := 9.0

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
	var ink := JournalTheme.color(&"ink")
	var accent := JournalTheme.color(&"accent")
	# Place names in the satchel serif (the heading face) at the small size.
	var font := get_theme_font(&"font", &"SatchelHeading")
	var fsize := get_theme_font_size(&"font_size", &"SatchelSmall")
	if here and picked:
		_ride_line(map_point(here.position), map_point(picked.position), accent)
	var names := label_rects()
	for d in _all():
		var at := map_point(d.position)
		var col := Color(ink, 0.55) if d.blight else ink
		var r := MARK
		if d == picked:
			r = 15.0 + 1.5 * sin(_t * 5.0)
			draw_circle(at, r + 7.0, Color(accent, 0.22))
		if d == here:
			draw_arc(at, r + 6.0, 0.0, TAU, 32, Color(ink, 0.8), 1.5, true)
		WhorlInk.ink_whorl(self, at, r, col, 2.2)
		var box: Rect2 = names[d.id]
		draw_string(font, Vector2(box.position.x, box.position.y + font.get_ascent(fsize)), WhorlStones.place_label(d),
				HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, col)


## Where each stone's name is written (stone id -> its box on the sketch):
## under its whorl if there is room, else beside or above it, so no name sits
## on another name or on another whorl.
func label_rects() -> Dictionary:
	var font := get_theme_font(&"font", &"SatchelHeading")
	var fsize := get_theme_font_size(&"font_size", &"SatchelSmall")
	var marks: Dictionary = {}
	for d in _all():
		marks[d.id] = mark_rect(d)
	var placed: Dictionary = {}
	var bounds := Rect2(Vector2.ZERO, size).grow(-2.0)
	for d in _all():
		var at := map_point(d.position)
		var box_size := font.get_string_size(WhorlStones.place_label(d), HORIZONTAL_ALIGNMENT_LEFT, -1, fsize)
		var best := Rect2()
		var found := false
		for ring in 6:
			var out := MARK + MARK_HALO + 2.0 + ring * (box_size.y + LABEL_AIR)
			# Under, over, right, left, then the four corners.
			for way: Vector2 in [Vector2(0, 1), Vector2(0, -1), Vector2(1, 0), Vector2(-1, 0),
					Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
				var centre := at + Vector2(way.x * (out + box_size.x * 0.5), way.y * (out + box_size.y * 0.5))
				var box := Rect2(centre - box_size * 0.5, box_size)
				box.position.x = clampf(box.position.x, bounds.position.x, maxf(bounds.position.x, bounds.end.x - box_size.x))
				box.position.y = clampf(box.position.y, bounds.position.y, maxf(bounds.position.y, bounds.end.y - box_size.y))
				if ring == 0 and way == Vector2(0, 1):
					best = box
				if _clear(box, d.id, marks, placed):
					best = box
					found = true
					break
			if found:
				break
		placed[d.id] = best
	return placed


## The room a stone's whorl takes, with its ring and glow.
func mark_rect(d: WhorlStoneDef) -> Rect2:
	var r := MARK + MARK_HALO
	return Rect2(map_point(d.position) - Vector2.ONE * r, Vector2.ONE * r * 2.0)


func _clear(box: Rect2, id: StringName, marks: Dictionary, placed: Dictionary) -> bool:
	var roomy := box.grow(LABEL_AIR)
	for other: StringName in placed:
		if roomy.intersects(placed[other]):
			return false
	for other: StringName in marks:
		if (roomy if other != id else box).intersects(marks[other]):
			return false
	return true


func _ride_line(a: Vector2, b: Vector2, col: Color) -> void:
	var n := maxi(2, int(a.distance_to(b) / 9.0))
	for i in n:
		if i % 2 == 0:
			draw_line(a.lerp(b, float(i) / n), a.lerp(b, float(i + 1) / n), Color(col, 0.85), 2.0, true)
