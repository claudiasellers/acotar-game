## Her page of the halls (ch12, L28): a sheet of drawing paper where every
## room she has walked into is inked in her hand, a wobbly outline with a soft
## wash and a little picture instead of a name, since she can't write. Her X
## marks and circles sit on the doors and stairs she noted. A new room inks
## itself in on a small page at the lower left (a quill scratch, a sparkle,
## gone in a few seconds); the whole page opens when she sets it down on the
## foyer table. No words on it anywhere: that's the point (Keeper, [C]).
class_name HallMapPage
extends CanvasLayer

const GROUP := &"hall_map_page"
const PAPER := Color(1.0, 0.965, 0.91)
const PAPER_EDGE := Color(0.93, 0.85, 0.76)
const INK := Color(0.36, 0.22, 0.34)
const GOLD := Color(0.90, 0.75, 0.40)
## One wash per storey (R3 pastels): cellars, ground, first, attic, towers.
const WASH := {-1: Color(0.80, 0.78, 0.92, 0.45), 0: Color(0.98, 0.80, 0.86, 0.45), 1: Color(0.80, 0.90, 1.0, 0.5),
		2: Color(0.84, 0.95, 0.84, 0.5), 3: Color(1.0, 0.93, 0.70, 0.55)}
const TOAST_SIZE := Vector2(420, 250)
const FULL_SIZE := Vector2(1100, 640)
const TOAST_HOLD := 2.6
const INK_SECONDS := 0.7

var plan: HallMapPlan
var rooms: Array[Dictionary] = []
## The storey on show (the latest sketch's).
var level: int = 0
## Room id -> seconds since it started inking (for the stroke animation).
var inking: Dictionary = {}
var is_full: bool = false

var _sheet: Control
var _hold: float = 0.0
var _full_left: float = -1.0
var _scratch: AudioStreamPlayer


static func find_or_make(owner: Node) -> HallMapPage:
	var tree := owner.get_tree()
	var existing := tree.get_first_node_in_group(GROUP) as HallMapPage
	if existing:
		return existing
	var page := HallMapPage.new()
	tree.root.add_child(page)
	return page


func _init() -> void:
	name = "HallMapPage"
	layer = 24
	add_to_group(GROUP)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_sheet = Control.new()
	_sheet.name = "Sheet"
	_sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sheet.draw.connect(_draw_sheet)
	_sheet.modulate.a = 0.0
	add_child(_sheet)
	_scratch = AudioStreamPlayer.new()
	_scratch.stream = _quill_sound()
	_scratch.volume_db = -14.0
	add_child(_scratch)


func _ready() -> void:
	if plan == null and ResourceLoader.exists(HallMap.PLAN_PATH):
		plan = load(HallMap.PLAN_PATH) as HallMapPlan
	if rooms.is_empty():
		rooms = HallMap.load_rooms()
	_layout()


## A room has just gone onto her page.
func sketch_room(id: StringName) -> void:
	for r in rooms:
		if StringName(r["id"]) == id:
			level = int(r["level"])
	inking[id] = 0.0
	_show_toast()
	if _scratch.is_inside_tree():
		_scratch.play()


## She marked one of the five places (an X or a circle).
func sketch_mark(_n: int) -> void:
	level = 0
	_show_toast()
	if _scratch.is_inside_tree():
		_scratch.play()


## From a tower top she drew the land beyond the windows on her world map.
func sketch_view(_id: StringName) -> void:
	level = 3
	_show_toast()


## The whole page, centred (she sets it down on the foyer table).
## seconds <= 0 keeps it up until close().
func open_full(seconds: float = 0.0) -> void:
	is_full = true
	level = 0
	_full_left = seconds if seconds > 0.0 else -1.0
	_layout()
	_fade_to(1.0)


func close() -> void:
	is_full = false
	_full_left = -1.0
	_fade_to(0.0)


func showing() -> bool:
	return _sheet.modulate.a > 0.01 or is_full or _hold > 0.0


func _show_toast() -> void:
	if is_full:
		_sheet.queue_redraw()
		return
	_hold = TOAST_HOLD
	_layout()
	_fade_to(1.0)


func _fade_to(a: float) -> void:
	if not _sheet.is_inside_tree():
		_sheet.modulate.a = a
		return
	var tween := _sheet.create_tween()
	tween.tween_property(_sheet, ^"modulate:a", a, 0.25)


func _layout() -> void:
	var view := Vector2(1920, 1080)
	if is_inside_tree():
		view = get_viewport().get_visible_rect().size
	var size := FULL_SIZE if is_full else TOAST_SIZE
	size = size.min(view * 0.9)
	_sheet.size = size
	_sheet.position = (view - size) * 0.5 if is_full else Vector2(28, view.y - size.y - 120)
	_sheet.queue_redraw()


func _process(delta: float) -> void:
	var busy := false
	for id in inking.keys():
		if float(inking[id]) < INK_SECONDS:
			inking[id] = float(inking[id]) + delta
			busy = true
	if busy:
		_sheet.queue_redraw()
	if is_full:
		if _full_left > 0.0:
			_full_left -= delta
			if _full_left <= 0.0:
				close()
		return
	if _hold > 0.0:
		_hold -= delta
		if _hold <= 0.0:
			_fade_to(0.0)


# --- drawing ------------------------------------------------------------------

func _draw_sheet() -> void:
	var s := _sheet.size
	var rng := RandomNumberGenerator.new()
	rng.seed = 1212
	# A deckled sheet with a soft shadow and a thin gilt rule.
	var edge := PackedVector2Array()
	var n := 40
	for i in n:
		var t := float(i) / n
		edge.append(_perimeter(s, t) + Vector2(rng.randf_range(-2.5, 2.5), rng.randf_range(-2.5, 2.5)))
	var shadow := PackedVector2Array()
	for p in edge:
		shadow.append(p + Vector2(6, 8))
	_sheet.draw_colored_polygon(shadow, Color(0.3, 0.15, 0.25, 0.22))
	_sheet.draw_colored_polygon(edge, PAPER)
	edge.append(edge[0])
	_sheet.draw_polyline(edge, PAPER_EDGE, 3.0, true)
	_sheet.draw_rect(Rect2(Vector2(14, 14), s - Vector2(28, 28)), GOLD, false, 1.5, true)
	var area := Rect2(Vector2(30, 30), s - Vector2(60, 70))
	var bounds := _level_bounds(level)
	if bounds.size.x <= 0.0:
		return
	var k := minf(area.size.x / bounds.size.x, area.size.y / bounds.size.y)
	var origin := area.position + (area.size - bounds.size * k) * 0.5
	var to_page := func(x: float, z: float) -> Vector2:
		return origin + (Vector2(x, z) - bounds.position) * k
	for r in rooms:
		if int(r["level"]) != level or not WorldState.has_flag(HallMap.room_fact(r)):
			continue
		var rect := r["rect"] as Rect2
		var a: Vector2 = to_page.call(rect.position.x, rect.position.y)
		var b: Vector2 = to_page.call(rect.end.x, rect.end.y)
		var page_rect := Rect2(a, b - a)
		var id := StringName(r["id"])
		var grown := clampf(float(inking.get(id, INK_SECONDS)) / INK_SECONDS, 0.0, 1.0)
		var wash: Color = WASH.get(level, WASH[0])
		_sheet.draw_rect(page_rect.grow(-1.5), Color(wash.r, wash.g, wash.b, wash.a * grown))
		_draw_wobbly_rect(page_rect, grown, hash(id))
		if grown >= 1.0 and page_rect.size.x > 14.0 and page_rect.size.y > 14.0:
			var pic := _picture_for(id)
			if pic != "":
				_draw_picture(pic, page_rect.get_center(), minf(minf(page_rect.size.x, page_rect.size.y) * 0.32, 18.0))
	if level == 0 and plan:
		for m in plan.marks:
			var mn := int(m.get("n", 0))
			if not (WorldState.has_flag("fact.hall_x_%d" % mn) or WorldState.has_flag("fact.hall_mark_%d" % mn)):
				continue
			var at: Vector2 = to_page.call(float(m.get("x", 0.0)), float(m.get("z", 0.0)))
			if String(m.get("shape", "x")) == "o":
				_sheet.draw_arc(at, 7.0, 0.0, TAU, 18, INK, 2.2, true)
			else:
				_sheet.draw_line(at - Vector2(6, 6), at + Vector2(6, 6), INK, 2.4, true)
				_sheet.draw_line(at + Vector2(-6, 6), at + Vector2(6, -6), INK, 2.4, true)
	# Storey pips: one dot per floor, the one on show filled.
	for l in range(-1, 4):
		var at := Vector2(s.x - 30 - (3 - l) * 16, s.y - 26)
		if l == level:
			_sheet.draw_circle(at, 5.0, INK)
		else:
			_sheet.draw_arc(at, 5.0, 0.0, TAU, 12, INK, 1.4, true)


func _perimeter(s: Vector2, t: float) -> Vector2:
	var p := t * 4.0
	if p < 1.0:
		return Vector2(s.x * p, 0)
	if p < 2.0:
		return Vector2(s.x, s.y * (p - 1.0))
	if p < 3.0:
		return Vector2(s.x * (3.0 - p), s.y)
	return Vector2(0, s.y * (4.0 - p))


func _level_bounds(l: int) -> Rect2:
	var out := Rect2()
	var first := true
	for r in rooms:
		if int(r["level"]) != l:
			continue
		var rect := r["rect"] as Rect2
		out = rect if first else out.merge(rect)
		first = false
	return out


## Her hand: four slightly bowed strokes, drawn up to `grown` of the way round.
func _draw_wobbly_rect(r: Rect2, grown: float, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	var pts := PackedVector2Array()
	for i in 4:
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % 4]
		var bow := rng.randf_range(-1.6, 1.6)
		for j in 6:
			var t := j / 6.0
			var normal := (b - a).orthogonal().normalized()
			pts.append(a.lerp(b, t) + normal * sin(t * PI) * bow + Vector2(rng.randf_range(-0.5, 0.5), rng.randf_range(-0.5, 0.5)))
	pts.append(pts[0])
	var upto := int(ceil(grown * (pts.size() - 1))) + 1
	if upto >= 2:
		_sheet.draw_polyline(pts.slice(0, upto), INK, 1.8, true)


func _picture_for(id: StringName) -> String:
	if plan and (plan.pictograms.has(id) or plan.pictograms.has(String(id))):
		return String(plan.pictograms.get(id, plan.pictograms.get(String(id), "")))
	return HallMap.guess_pictogram(String(id))


## The little pictures, a few ink strokes each.
func _draw_picture(pic: String, c: Vector2, r: float) -> void:
	var w := 1.6
	match pic:
		"book":
			_sheet.draw_rect(Rect2(c - Vector2(r, r * 0.7), Vector2(r * 2, r * 1.4)), INK, false, w)
			_sheet.draw_line(c - Vector2(0, r * 0.7), c + Vector2(0, r * 0.7), INK, w)
		"bed":
			_sheet.draw_rect(Rect2(c - Vector2(r, r * 0.4), Vector2(r * 2, r * 0.8)), INK, false, w)
			_sheet.draw_rect(Rect2(c - Vector2(r * 0.9, r * 0.3), Vector2(r * 0.5, r * 0.4)), INK, false, w)
		"pot":
			_sheet.draw_arc(c, r * 0.7, 0.0, PI, 10, INK, w)
			_sheet.draw_line(c - Vector2(r, 0), c + Vector2(r, 0), INK, w)
		"harp":
			_sheet.draw_line(c + Vector2(-r * 0.6, r), c + Vector2(-r * 0.6, -r), INK, w)
			_sheet.draw_arc(c + Vector2(-r * 0.6, 0), r, -PI * 0.5, PI * 0.5, 10, INK, w)
		"flower":
			for i in 5:
				_sheet.draw_arc(c + Vector2.from_angle(TAU * i / 5.0) * r * 0.5, r * 0.35, 0.0, TAU, 8, INK, w)
		"star":
			var pts := PackedVector2Array()
			for i in 11:
				pts.append(c + Vector2.from_angle(-PI * 0.5 + PI * i / 5.0) * (r if i % 2 == 0 else r * 0.45))
			_sheet.draw_polyline(pts, GOLD.darkened(0.2), w)
		"cup":
			_sheet.draw_rect(Rect2(c - Vector2(r * 0.6, r * 0.5), Vector2(r * 1.2, r)), INK, false, w)
			_sheet.draw_arc(c + Vector2(r * 0.6, 0), r * 0.3, -PI * 0.5, PI * 0.5, 6, INK, w)
		"bath":
			_sheet.draw_arc(c, r, 0.0, PI, 10, INK, w)
			_sheet.draw_line(c - Vector2(r, 0), c + Vector2(r, 0), INK, w)
		"brush":
			_sheet.draw_line(c + Vector2(-r, r), c + Vector2(r * 0.4, -r * 0.4), INK, w)
			_sheet.draw_circle(c + Vector2(r * 0.6, -r * 0.6), r * 0.25, Color(0.9, 0.55, 0.7))
		"bow":
			_sheet.draw_arc(c, r, -PI * 0.5, PI * 0.5, 10, INK, w)
			_sheet.draw_line(c + Vector2(0, -r), c + Vector2(0, r), INK, 1.0)
		"crown":
			_sheet.draw_polyline(PackedVector2Array([c + Vector2(-r, r * 0.5), c + Vector2(-r, -r * 0.4), c + Vector2(-r * 0.5, r * 0.1),
					c + Vector2(0, -r * 0.6), c + Vector2(r * 0.5, r * 0.1), c + Vector2(r, -r * 0.4), c + Vector2(r, r * 0.5),
					c + Vector2(-r, r * 0.5)]), GOLD.darkened(0.2), w)
		"bandage":
			_sheet.draw_rect(Rect2(c - Vector2(r, r * 0.4), Vector2(r * 2, r * 0.8)), INK, false, w)
			_sheet.draw_circle(c, r * 0.15, INK)
		"bottle":
			_sheet.draw_rect(Rect2(c - Vector2(r * 0.4, r * 0.2), Vector2(r * 0.8, r)), INK, false, w)
			_sheet.draw_line(c - Vector2(0, r * 0.2), c - Vector2(0, r * 0.8), INK, w)
		"needle":
			_sheet.draw_line(c + Vector2(-r, r), c + Vector2(r, -r), INK, w)
			_sheet.draw_arc(c + Vector2(r * 0.8, -r * 0.8), r * 0.2, 0.0, TAU, 6, INK, 1.0)
		"candle":
			_sheet.draw_rect(Rect2(c - Vector2(r * 0.25, r * 0.2), Vector2(r * 0.5, r)), INK, false, w)
			_sheet.draw_circle(c - Vector2(0, r * 0.5), r * 0.22, Color(1.0, 0.75, 0.35))
		"stair":
			_sheet.draw_polyline(PackedVector2Array([c + Vector2(-r, r), c + Vector2(-r * 0.3, r), c + Vector2(-r * 0.3, 0),
					c + Vector2(r * 0.3, 0), c + Vector2(r * 0.3, -r), c + Vector2(r, -r)]), INK, w)
		"key":
			_sheet.draw_arc(c - Vector2(r * 0.5, 0), r * 0.35, 0.0, TAU, 8, INK, w)
			_sheet.draw_line(c - Vector2(r * 0.15, 0), c + Vector2(r, 0), INK, w)


## A soft quill scratch: filtered noise, 0.25 s.
static func _quill_sound() -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * 0.25)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var last := 0.0
	for i in n:
		var t := float(i) / n
		last = lerpf(last, rng.randf_range(-1.0, 1.0), 0.35)
		var env := sin(t * PI) * (0.6 + 0.4 * sin(t * 40.0))
		data.encode_s16(i * 2, int(clampf(last * env * 0.35, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = data
	return wav
