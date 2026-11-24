## Feyre's bow at the start of the health bar (Gilded Enamel, the owner's pick):
## the limb is five enamel pieces that go dark from the top down as stamina
## drops, and the nocked arrow points along the bar. Lit pieces pulse when she
## is low and grey when she is winded. A gold bud rides outside the limb for
## every 10 points her stamina has grown (ease); a new one blooms with a
## sparkle, a chime and a bounce. Layers: tools/ui/status_icons/bow_meter.mjs.
class_name VitalsStaminaBow
extends Control

const SIZE := 100.0
const DIR := "res://ui/theme/icons/status/"
const PIECES := 5
const WINDED := Color(0.62, 0.6, 0.66)
const BUD := Color("#E8C14A")
const KEYLINE := Color("#24142C")
const MAX_BUDS := 5
## The layers' 48 grid inside SIZE (bow_meter.mjs renders with an 8% pad).
const PAD := 0.08
## The limb's arc on that grid: centre, outer radius, first piece's start angle
## and each piece's sweep (degrees, 0 = +x, down positive).
const ARC_CENTRE := Vector2(7, 24)
const ARC_OUTER := 24.2
const ARC_START := -62.0
const ARC_SPAN := 124.0 / 5.0

var fraction: float = 1.0
var winded: bool = false
## 0..5 growth buds (each +10 max stamina).
var buds: int = 0
var _string: Texture2D
var _front: Texture2D
var _lit: Array[Texture2D] = []
var _dark: Array[Texture2D] = []
var _bloom: float = 0.0
var _sparkle: float = 0.0
var _player: AudioStreamPlayer


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(SIZE, SIZE)
	size = custom_minimum_size
	pivot_offset = size * 0.5


func _ready() -> void:
	_string = load(DIR + "hud_bow_string.webp") as Texture2D
	_front = load(DIR + "hud_bow_front.webp") as Texture2D
	for i in PIECES:
		_lit.append(load(DIR + "hud_bow_piece%d_lit.webp" % i) as Texture2D)
		_dark.append(load(DIR + "hud_bow_piece%d_dark.webp" % i) as Texture2D)
	_player = AudioStreamPlayer.new()
	_player.volume_db = -10.0
	add_child(_player)


func set_buds(count: int) -> void:
	count = clampi(count, 0, MAX_BUDS)
	if count > buds:
		_bloom = 1.0
		_sparkle = 1.0
		_player.stream = Juice.chime(&"unlock")
		_player.play()
		Juice.bounce_control(self, 0.18)
	buds = count


## How lit piece i is (0..1). Piece 0 is the top, the first to go dark.
func piece_lit(i: int) -> float:
	return clampf(fraction * PIECES - (PIECES - 1 - i), 0.0, 1.0)


func _process(delta: float) -> void:
	_bloom = maxf(_bloom - delta * 1.2, 0.0)
	_sparkle = maxf(_sparkle - delta * 1.5, 0.0)
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var tint := Color.WHITE
	if winded:
		tint = WINDED
	elif fraction < 0.25:
		tint.a = 0.6 + 0.4 * (0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.0126))
	draw_texture_rect(_string, rect, false)
	for i in PIECES:
		draw_texture_rect(_dark[i], rect, false)
		var lit := piece_lit(i)
		if lit > 0.0:
			draw_texture_rect(_lit[i], rect, false, Color(tint, tint.a * lit))
	draw_texture_rect(_front, rect, false)
	# Buds ride outside the limb, filling from the bottom piece up.
	for b in buds:
		var p := _grid(PIECES - 1 - b, ARC_OUTER + 2.4)
		var rad := 2.4 + (_bloom * 2.4 if b == buds - 1 else 0.0)
		draw_circle(p, rad + 1.1, KEYLINE, true, -1.0, true)
		draw_circle(p, rad, BUD, true, -1.0, true)
	if _sparkle > 0.0 and buds > 0:
		var c := _grid(PIECES - buds, ARC_OUTER + 2.4)
		for i in 8:
			var a := TAU * i / 8.0 + _sparkle
			_star(c + Vector2(cos(a), sin(a)) * 18.0 * (1.0 - _sparkle), 5.0 * _sparkle, Color(1.0, 0.92, 0.6, _sparkle))


## The point at the middle of piece i's sweep, `radius` out from the arc centre,
## in this control's pixels.
func _grid(i: int, radius: float) -> Vector2:
	var a := deg_to_rad(ARC_START + (i + 0.5) * ARC_SPAN)
	var g := ARC_CENTRE + Vector2(cos(a), sin(a)) * radius
	return size * PAD + g * (size.x * (1.0 - 2.0 * PAD) / 48.0)


func _star(p: Vector2, r: float, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([p + Vector2(0, -r), p + Vector2(r * 0.3, -r * 0.3), p + Vector2(r, 0),
		p + Vector2(r * 0.3, r * 0.3), p + Vector2(0, r), p + Vector2(-r * 0.3, r * 0.3), p + Vector2(-r, 0),
		p + Vector2(-r * 0.3, -r * 0.3)]), color)
