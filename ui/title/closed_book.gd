## Feyre's journal, shut: the title screen. A clothbound board with the game's
## name pressed into it in gold foil around a thorned rose, her index tabs
## showing along the top of the pages and the ribbon at their foot. lift()
## swings the cover open on its spine: the night-sky endpaper with her yellow
## whorls comes over to the left, and the first page lies open on the right
## for whatever the title writes there (page_rect()). Colours are the theme's
## BOOK tokens, the same in both acts as the open book's art is.
class_name ClosedBook
extends Control

signal lifted
signal shut

const KICKER := "A Court of"
const NAME := "Thorns and Roses"
const COURT := "The Spring Court"

## The board, in px on a 1920 x 1080 screen.
const SIZE := Vector2(700, 800)
## The spine's cloth, down the board's left edge.
const SPINE := 54.0
## How far the pages sit inside the boards.
const INSET := 12.0
## The writing area of the first page, in the book's own space.
const PAGE := Rect2(70, 60, 570, 680)
## The gold frame: its two rules, in from the board's edge.
const FRAME := [46.0, 58.0]
## The rose: where its heart is, and how far its ring of thorns reaches.
const ROSE_AT := Vector2(377, 420)
const ROSE_REACH := 136.0
const PETALS := 5
## A petal's arc: how far out its centre is (of the ring's reach), and how far
## round it runs before it meets the next petal.
const PETAL_OUT := 0.62
const PETAL_SWEEP := 1.91
const TAB := Vector2(62, 26)
const RIBBON := Vector2(22, 58)
const LIFT_SECONDS := 1.1
const WHORLS := 64
const SEED := 4

var open_now: bool = false

var _cover: Control
var _endpaper: Control
var _swing: Tween


func _init() -> void:
	name = "Book"
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pages := _part("Pages", _draw_pages)
	for i in JournalTheme.WASHES.size():
		var tab := ColorRect.new()
		tab.name = "Tab%d" % i
		tab.color = JournalTheme.wash(i)
		tab.size = TAB
		tab.position = Vector2(SPINE + 70.0 + i * (TAB.x + 8.0), -TAB.y + INSET)
		tab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tab.show_behind_parent = true
		pages.add_child(tab)
	_endpaper = _part("Endpaper", _draw_endpaper)
	_endpaper.position.x = -SIZE.x
	_endpaper.pivot_offset = Vector2(SIZE.x, SIZE.y * 0.5)
	_endpaper.scale.x = 0.0
	_cover = _part("Cover", _draw_cover)
	_cover.pivot_offset = Vector2(0, SIZE.y * 0.5)
	_foil(KICKER, &"CoverKicker", 150.0)
	_foil(NAME, &"CoverTitle", 184.0)
	_foil(COURT, &"CoverKicker", 640.0)


## The first page's writing area, on the screen.
func page_rect() -> Rect2:
	return Rect2(global_position + PAGE.position * scale, PAGE.size * scale)


## Swings the cover open. Returns once it lies flat (at once with seconds 0).
func lift(seconds: float = LIFT_SECONDS) -> void:
	if open_now:
		return
	open_now = true
	_swing_to(0.0, 1.0, seconds, lifted)


## Closes it again.
func close(seconds: float = LIFT_SECONDS * 0.6) -> void:
	if not open_now:
		return
	open_now = false
	_swing_to(1.0, 0.0, seconds, shut)


## The cover turns edge-on first, then the endpaper comes over; closing runs
## the other way round.
func _swing_to(cover_x: float, endpaper_x: float, seconds: float, done: Signal) -> void:
	if _swing:
		_swing.kill()
	if seconds <= 0.0 or not is_inside_tree():
		_cover.scale.x = cover_x
		_endpaper.scale.x = endpaper_x
		done.emit()
		return
	var first: Control = _cover if open_now else _endpaper
	var second: Control = _endpaper if open_now else _cover
	_swing = create_tween()
	_swing.tween_property(first, ^"scale:x", 0.0, seconds * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_swing.tween_property(second, ^"scale:x", 1.0, seconds * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_swing.tween_callback(done.emit)


func _part(part_name: String, painter: Callable) -> Control:
	var c := Control.new()
	c.name = part_name
	c.size = SIZE
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(painter.bind(c))
	add_child(c)
	return c


func _foil(text: String, variation: StringName, y: float) -> void:
	var l := BookKit.label(text, variation)
	l.uppercase = true
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = Vector2(SPINE, y)
	l.size.x = SIZE.x - SPINE
	_cover.add_child(l)


func _board(on: Control, shadow: float) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = JournalTheme.color(&"cloth")
	box.set_corner_radius_all(10)
	box.shadow_color = Color(JournalTheme.color(&"ink"), shadow)
	box.shadow_size = 26
	box.shadow_offset = Vector2(0, 10)
	on.draw_style_box(box, Rect2(Vector2.ZERO, SIZE))


## The back board, the block of pages on it, and the ribbon out of its foot.
func _draw_pages(on: Control) -> void:
	_board(on, 0.5)
	var block := Rect2(INSET, INSET, SIZE.x - INSET * 2.0, SIZE.y - INSET * 2.0)
	on.draw_rect(block, JournalTheme.color(&"paper_deep"))
	on.draw_rect(block.grow_individual(0, 0, -5, -5), JournalTheme.color(&"paper"))
	var foil := JournalTheme.color(&"foil")
	var x := SIZE.x * 0.3
	var top := SIZE.y - INSET
	on.draw_colored_polygon(PackedVector2Array([
		Vector2(x, top), Vector2(x + RIBBON.x, top), Vector2(x + RIBBON.x, top + RIBBON.y),
		Vector2(x + RIBBON.x * 0.5, top + RIBBON.y - 12.0), Vector2(x, top + RIBBON.y),
	]), foil)


func _draw_cover(on: Control) -> void:
	_board(on, 0.0)
	var deep := JournalTheme.color(&"cloth_deep")
	var foil := JournalTheme.color(&"foil")
	var spine := StyleBoxFlat.new()
	spine.bg_color = deep
	spine.corner_radius_top_left = 10
	spine.corner_radius_bottom_left = 10
	on.draw_style_box(spine, Rect2(0, 0, SPINE, SIZE.y))
	for y: float in [86.0, 98.0, SIZE.y - 98.0, SIZE.y - 86.0]:
		on.draw_line(Vector2(8, y), Vector2(SPINE - 8.0, y), foil, 3.0)
	var face := Rect2(SPINE, 0, SIZE.x - SPINE, SIZE.y)
	on.draw_rect(face.grow(-FRAME[0]), foil, false, 3.0)
	var inner := face.grow(-FRAME[1])
	on.draw_rect(inner, foil, false, 1.5)
	for corner: Vector2 in [inner.position, Vector2(inner.end.x, inner.position.y), inner.end, Vector2(inner.position.x, inner.end.y)]:
		_sprig(on, corner, (inner.get_center() - corner).sign(), foil)
	_rose(on, ROSE_AT, ROSE_REACH, foil)
	_diamond(on, Vector2(ROSE_AT.x, 700), 7.0, foil)


## A curl of vine with a leaf, growing in from a corner of the frame.
func _sprig(on: Control, at: Vector2, inward: Vector2, foil: Color) -> void:
	var stem := PackedVector2Array()
	for i in 13:
		var t := i / 12.0
		stem.append(at + Vector2(inward.x * (8.0 + 58.0 * t), inward.y * (8.0 + 16.0 * sin(t * PI))))
	on.draw_polyline(stem, foil, 2.0, true)
	_leaf(on, stem[7], Vector2(inward.x, inward.y * 1.4).normalized(), 13.0, foil)
	on.draw_circle(at + inward * 8.0, 3.5, foil)


func _leaf(on: Control, at: Vector2, along: Vector2, length: float, foil: Color) -> void:
	var side := along.orthogonal() * length * 0.3
	on.draw_polyline(PackedVector2Array([
		at, at + along * length * 0.5 + side, at + along * length, at + along * length * 0.5 - side, at,
	]), foil, 1.5, true)


func _diamond(on: Control, at: Vector2, reach: float, foil: Color) -> void:
	on.draw_colored_polygon(PackedVector2Array([
		at + Vector2(0, -reach), at + Vector2(reach, 0), at + Vector2(0, reach), at + Vector2(-reach, 0),
	]), foil)


## The rose: three rings of five petals round a whorl, inside a ring of
## briar with a thorn at every turn and a leaf between.
func _rose(on: Control, at: Vector2, reach: float, foil: Color) -> void:
	var ring := PackedVector2Array()
	for i in 11:
		var a := TAU * i / 10.0 - PI * 0.5
		var out := Vector2.from_angle(a)
		ring.append(at + out * reach)
		if i < 10:
			var tip := at + out * (reach + 15.0)
			var across := out.orthogonal() * 5.0
			on.draw_colored_polygon(PackedVector2Array([at + out * reach + across, tip, at + out * reach - across]), foil)
			var between := Vector2.from_angle(a + TAU / 20.0)
			_leaf(on, at + between * (reach * 0.96), between, 16.0, foil)
	on.draw_polyline(ring, foil, 2.5, true)
	# A petal is an arc that meets its neighbours where they cross, so each
	# ring is one scalloped line; each ring is turned half a petal on the last.
	var rings := [reach * 0.74, reach * 0.5, reach * 0.28]
	for r in rings.size():
		var radius: float = rings[r]
		for p in PETALS:
			var a := TAU * p / PETALS - PI * 0.5 + r * PI / PETALS
			on.draw_arc(at + Vector2.from_angle(a) * radius * PETAL_OUT, radius * (1.0 - PETAL_OUT), a - PETAL_SWEEP, a + PETAL_SWEEP, 20, foil, 2.5, true)
	var whorl := PackedVector2Array()
	for i in 40:
		var t := i / 39.0
		whorl.append(at + Vector2.from_angle(t * TAU * 1.75) * (1.5 + t * reach * 0.1))
	on.draw_polyline(whorl, foil, 2.5, true)


## The inside of the cover: night sky, with the whorls of stars she paints.
func _draw_endpaper(on: Control) -> void:
	_board(on, 0.4)
	var sky := Rect2(INSET, INSET, SIZE.x - INSET * 2.0, SIZE.y - INSET * 2.0)
	on.draw_rect(sky, JournalTheme.color(&"night"))
	var foil := JournalTheme.color(&"foil")
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	for i in WHORLS:
		var at := sky.position + Vector2(rng.randf(), rng.randf()) * sky.size
		var reach := rng.randf_range(2.0, 10.0)
		if reach < 4.0:
			on.draw_circle(at, reach * 0.5, foil)
			continue
		var whorl := PackedVector2Array()
		var turn := rng.randf() * TAU
		for s in 14:
			var t := s / 13.0
			whorl.append(at + Vector2.from_angle(turn + t * TAU * 1.5) * t * reach)
		on.draw_polyline(whorl, foil, 1.5, true)
