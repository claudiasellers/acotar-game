## Draws Feyre's plan of the manor (ManorPlan) the way she would: wobbly
## hand-drawn walls, an X at each door, little circles for windows, hatching
## for stairs and a few pictures (her bed with a rose over it, a tub, books,
## a pot). Pencil until she has drawn the hall map, ink after. No words.
## `to_screen` maps house XZ to the canvas; `ppm` is pixels per metre.
extends RefCounted

const PENCIL := Color(0.38, 0.35, 0.38, 0.8)
const INK := Color(0.29, 0.17, 0.29, 0.95)
const WASH := Color(0.99, 0.90, 0.91, 0.55)
const PAPER := Color(0.99, 0.97, 0.93)
const ROSE := Color(0.93, 0.45, 0.62)


static func draw_plan(ci: CanvasItem, plan: RefCounted, l: int, to_screen: Callable, ppm: float) -> void:
	var inked: bool = plan.inked()
	var line := INK if inked else PENCIL
	var w := clampf(ppm * 0.16, 1.2, 2.4)
	var rooms: Array[ManorRoomDef] = plan.rooms_on(l)
	if inked:
		for r in rooms:
			_poly(ci, r.rect, to_screen, Color(WASH, 0.4 if r.kind == &"corridor" else 0.55))
	for s: ManorStairDef in plan.stairs_on(l):
		_hatch(ci, s, to_screen, ppm, line, w * 0.7)
	for r in rooms:
		_room(ci, r, to_screen, ppm, line, w, inked)
	for r in rooms:
		for p in plan.windows_of(r):
			ci.draw_arc(to_screen.call(p), clampf(ppm * 0.35, 1.8, 5.0), 0.0, TAU, 12, line, w * 0.7, true)
	for d: ManorDoorDef in plan.doors_on(l):
		_cross(ci, to_screen.call(d.at), clampf(ppm * 0.5, 3.0, 8.0), line, w)
	for r in rooms:
		_picture(ci, r, to_screen.call(r.rect.get_center()), clampf(ppm * 2.2, 9.0, 30.0), line, w, inked)


## Walls: each side a slightly bent stroke that runs past the corners, once in
## ink, twice (a little apart) in pencil.
static func _room(ci: CanvasItem, r: ManorRoomDef, to_screen: Callable, ppm: float, line: Color, w: float, inked: bool) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(r.id)
	var rc := r.rect
	var corners := [rc.position, Vector2(rc.end.x, rc.position.y), rc.end, Vector2(rc.position.x, rc.end.y)]
	var wobble := clampf(0.2 * ppm, 1.0, 3.5)
	for pass_i in (1 if inked else 2):
		for i in 4:
			var a: Vector2 = corners[i]
			var b: Vector2 = corners[(i + 1) % 4]
			var dir := (b - a).normalized()
			var over := rng.randf_range(0.1, 0.45)
			var pa: Vector2 = to_screen.call(a - dir * over)
			var pb: Vector2 = to_screen.call(b + dir * rng.randf_range(0.1, 0.45))
			var n := Vector2(-(pb - pa).normalized().y, (pb - pa).normalized().x)
			var bend := rng.randf_range(-1.0, 1.0) * wobble
			var shift := n * rng.randf_range(-0.6, 0.6) * pass_i * wobble
			var pts := PackedVector2Array()
			for k in 7:
				var t := k / 6.0
				pts.append(pa.lerp(pb, t) + n * sin(t * PI) * bend + shift)
			ci.draw_polyline(pts, Color(line, line.a * (1.0 if pass_i == 0 else 0.55)), w, true)


static func _poly(ci: CanvasItem, rc: Rect2, to_screen: Callable, c: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array([to_screen.call(rc.position), to_screen.call(Vector2(rc.end.x, rc.position.y)),
		to_screen.call(rc.end), to_screen.call(Vector2(rc.position.x, rc.end.y))]), c)


static func _cross(ci: CanvasItem, at: Vector2, s: float, line: Color, w: float) -> void:
	ci.draw_line(at + Vector2(-s, -s), at + Vector2(s, s), line, w, true)
	ci.draw_line(at + Vector2(s, -s), at + Vector2(-s, s), line, w, true)


## A flight of stairs: rungs across it, the way it climbs.
static func _hatch(ci: CanvasItem, s: ManorStairDef, to_screen: Callable, ppm: float, line: Color, w: float) -> void:
	var rc := s.rect
	var along_z := s.rise_toward == &"north" or s.rise_toward == &"south"
	var length := rc.size.y if along_z else rc.size.x
	var steps := maxi(3, int(length / 0.9))
	for i in steps + 1:
		var t := float(i) / steps
		var a: Vector2
		var b: Vector2
		if along_z:
			a = Vector2(rc.position.x, rc.position.y + rc.size.y * t)
			b = Vector2(rc.end.x, a.y)
		else:
			a = Vector2(rc.position.x + rc.size.x * t, rc.position.y)
			b = Vector2(a.x, rc.end.y)
		ci.draw_line(to_screen.call(a), to_screen.call(b), Color(line, line.a * 0.8), w, true)


## Little pictures for the rooms that matter to her.
static func picture_for(id: StringName) -> StringName:
	var s := String(id)
	if s == "feyre_bedroom":
		return &"her_bed"
	if s.contains("bedroom") or s.contains("bedchamber") or s.contains("chambers") or s.contains("guest_suite") or s.contains("dorm"):
		return &"bed"
	if s.contains("bath") or s.contains("wash"):
		return &"tub"
	if s.contains("library") or s.contains("reading") or s.contains("study"):
		return &"book"
	if s.contains("kitchen"):
		return &"pot"
	if s.contains("painting"):
		return &"easel"
	return &""


static func _picture(ci: CanvasItem, r: ManorRoomDef, c: Vector2, s: float, line: Color, w: float, inked: bool) -> void:
	match picture_for(r.id):
		&"her_bed":
			_bed(ci, c + Vector2(0, s * 0.25), s, line, w)
			_rose(ci, c + Vector2(0, -s * 0.75), s * 0.42, inked)
		&"bed":
			_bed(ci, c, s * 0.8, line, w)
		&"tub":
			var pts := PackedVector2Array()
			for i in 9:
				var a := PI * i / 8.0
				pts.append(c + Vector2(-cos(a) * s * 0.6, sin(a) * s * 0.35))
			pts.append(pts[0])
			ci.draw_polyline(pts, line, w, true)
			ci.draw_line(c + Vector2(-s * 0.4, s * 0.35), c + Vector2(-s * 0.45, s * 0.55), line, w, true)
			ci.draw_line(c + Vector2(s * 0.4, s * 0.35), c + Vector2(s * 0.45, s * 0.55), line, w, true)
		&"book":
			ci.draw_polyline(PackedVector2Array([c + Vector2(-s * 0.6, -s * 0.3), c + Vector2(0, -s * 0.15), c + Vector2(s * 0.6, -s * 0.3),
				c + Vector2(s * 0.6, s * 0.3), c + Vector2(0, s * 0.45), c + Vector2(-s * 0.6, s * 0.3), c + Vector2(-s * 0.6, -s * 0.3)]), line, w, true)
			ci.draw_line(c + Vector2(0, -s * 0.15), c + Vector2(0, s * 0.45), line, w, true)
		&"pot":
			ci.draw_arc(c + Vector2(0, s * 0.05), s * 0.4, 0.0, PI, 10, line, w, true)
			ci.draw_line(c + Vector2(-s * 0.55, s * 0.05), c + Vector2(s * 0.55, s * 0.05), line, w, true)
			for k in 3:
				var x := (k - 1) * s * 0.22
				ci.draw_line(c + Vector2(x, -s * 0.15), c + Vector2(x + s * 0.06, -s * 0.45), Color(line, line.a * 0.6), w * 0.8, true)
		&"easel":
			ci.draw_line(c + Vector2(0, -s * 0.6), c + Vector2(-s * 0.4, s * 0.55), line, w, true)
			ci.draw_line(c + Vector2(0, -s * 0.6), c + Vector2(s * 0.4, s * 0.55), line, w, true)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.35, -s * 0.35), Vector2(s * 0.7, s * 0.45)), line, false, w)


static func _bed(ci: CanvasItem, c: Vector2, s: float, line: Color, w: float) -> void:
	var r := Rect2(c + Vector2(-s * 0.45, -s * 0.6), Vector2(s * 0.9, s * 1.1))
	ci.draw_rect(r, line, false, w)
	ci.draw_rect(Rect2(r.position + Vector2(s * 0.12, s * 0.1), Vector2(s * 0.66, s * 0.25)), line, false, w * 0.8)
	ci.draw_line(r.position + Vector2(0, s * 0.5), r.position + Vector2(r.size.x, s * 0.5), line, w * 0.8, true)


## Her mark for her own room: a rose, rose-coloured once inked.
static func _rose(ci: CanvasItem, c: Vector2, s: float, inked: bool) -> void:
	var col := ROSE if inked else Color(ROSE.lerp(PENCIL, 0.5), 0.85)
	for i in 5:
		var a := TAU * i / 5.0 + 0.3
		ci.draw_circle(c + Vector2(cos(a), sin(a)) * s * 0.55, s * 0.5, Color(col, 0.75))
	ci.draw_circle(c, s * 0.4, col.darkened(0.15))
	ci.draw_arc(c, s * 0.22, 0.0, TAU * 0.8, 10, col.darkened(0.4), 1.2, true)
	ci.draw_line(c + Vector2(0, s * 0.9), c + Vector2(s * 0.2, s * 1.9), Color(0.45, 0.62, 0.45), 1.6, true)


## Her on the plan. On another floor she is a hollow ring with an arrow up
## (she is above this floor) or down.
static func draw_her(ci: CanvasItem, at: Vector2, angle: float, s: float, t: float, here_level: int, drawn_level: int) -> void:
	if here_level == drawn_level:
		MapMarks.draw_feyre(ci, at, angle, s, t)
		return
	var col := Color(MapMarks.ROSE, 0.85)
	ci.draw_arc(at, s * 0.8, 0.0, TAU, 24, col, 2.0, true)
	var up := here_level > drawn_level
	var d := Vector2(0, -1) if up else Vector2(0, 1)
	var tip := at + d * s * 2.0
	ci.draw_line(at + d * s * 0.9, tip, col, 2.0, true)
	ci.draw_polyline(PackedVector2Array([tip - d * s * 0.6 + Vector2(-s * 0.5, 0), tip, tip - d * s * 0.6 + Vector2(s * 0.5, 0)]), col, 2.0, true)


## A floor key: a little house front with that storey's band filled in, so
## the floors read without words. Cellars are a band under the ground line.
static func draw_floor_key(ci: CanvasItem, c: Vector2, s: float, l: int, chosen: bool, here: bool) -> void:
	var line := INK if chosen else Color(INK, 0.55)
	var body := Rect2(c + Vector2(-s, -s * 0.6), Vector2(s * 2.0, s * 1.4))
	var band_h := body.size.y / 4.0
	ci.draw_rect(Rect2(c - Vector2(s * 1.35, s * 1.35), Vector2(s * 2.7, s * 2.7)), Color(PAPER, 0.95 if chosen else 0.7))
	if chosen:
		ci.draw_rect(Rect2(c - Vector2(s * 1.35, s * 1.35), Vector2(s * 2.7, s * 2.7)), MapMarks.GOLD, false, 2.0)
	var band: Rect2
	if l < 0:
		band = Rect2(Vector2(body.position.x, body.end.y + s * 0.12), Vector2(body.size.x, band_h))
	else:
		var row := clampi(l, 0, 3)
		band = Rect2(Vector2(body.position.x, body.end.y - band_h * (row + 1)), Vector2(body.size.x, band_h))
	ci.draw_rect(band, Color(MapMarks.ROSE, 0.75 if chosen else 0.45))
	ci.draw_rect(body, line, false, 1.6)
	ci.draw_polyline(PackedVector2Array([body.position + Vector2(-s * 0.15, 0), c + Vector2(0, -s * 1.15), Vector2(body.end.x + s * 0.15, body.position.y)]), line, 1.6, true)
	ci.draw_line(Vector2(body.position.x - s * 0.3, body.end.y), Vector2(body.end.x + s * 0.3, body.end.y), line, 1.2, true)
	if here:
		ci.draw_circle(band.get_center(), s * 0.18, MapMarks.PLUM)
