## The stamina rose at the start of the health bar: five petals that fill one by
## one as stamina comes back, coral and pulsing when low, pale when winded, and
## a gold bud round the rose for every 10 points her stamina has grown (ease).
## A new bud blooms with a sparkle, a chime and a bounce (plan §6.1, §15 A1).
class_name VitalsStaminaRose
extends Control

const SIZE := 100.0
const PETAL_PATH := "res://ui/theme/icons/status/hud_petal.webp"
const HEART_PATH := "res://ui/theme/icons/status/hud_rose_heart.webp"
const ROSE := Color(1, 1, 1)
const LOW := Color("#FF8F7A")
const WINDED := Color(0.78, 0.76, 0.8)
const BUD := Color("#E8C14A")
const MAX_BUDS := 5

var fraction: float = 1.0
var winded: bool = false
## 0..5 growth buds (each +10 max stamina).
var buds: int = 0
var _petal: Texture2D
var _heart: Texture2D
var _bloom: float = 0.0
var _sparkle: float = 0.0
var _player: AudioStreamPlayer


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(SIZE, SIZE)
	size = custom_minimum_size
	pivot_offset = size * 0.5


func _ready() -> void:
	_petal = load(PETAL_PATH) as Texture2D
	_heart = load(HEART_PATH) as Texture2D
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


func _process(delta: float) -> void:
	_bloom = maxf(_bloom - delta * 1.2, 0.0)
	_sparkle = maxf(_sparkle - delta * 1.5, 0.0)
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var tint := ROSE
	if winded:
		tint = WINDED
	elif fraction < 0.25:
		tint = ROSE.lerp(LOW, 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.0126))
	for i in 5:
		var lit := clampf(fraction * 5.0 - i, 0.0, 1.0)
		draw_set_transform(c, TAU * i / 5.0, Vector2.ONE)
		var rect := Rect2(-c, size)
		if _petal:
			draw_texture_rect(_petal, rect, false, Color(tint, 0.28))
			if lit > 0.0:
				var grow := 0.75 + 0.25 * lit
				draw_texture_rect(_petal, Rect2(-c * grow, size * grow), false, Color(tint, lit))
	draw_set_transform(c, 0.0, Vector2.ONE)
	if _heart:
		draw_texture_rect(_heart, Rect2(-c, size), false)
	for i in buds:
		var a := -PI * 0.5 + TAU * (i + 0.5) / MAX_BUDS
		var p := Vector2(cos(a), sin(a)) * (SIZE * 0.5 + 2.0)
		var rad := 3.6 + (_bloom * 3.0 if i == buds - 1 else 0.0)
		draw_circle(p, rad + 1.1, Color("#3A2444"))
		draw_circle(p, rad, BUD)
	if _sparkle > 0.0:
		for i in 8:
			var a := TAU * i / 8.0 + _sparkle
			var p := Vector2(cos(a), sin(a)) * (SIZE * 0.5 + 18.0 * (1.0 - _sparkle))
			_star(p, 5.0 * _sparkle, Color(1.0, 0.92, 0.6, _sparkle))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _star(p: Vector2, r: float, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([p + Vector2(0, -r), p + Vector2(r * 0.3, -r * 0.3), p + Vector2(r, 0),
		p + Vector2(r * 0.3, r * 0.3), p + Vector2(0, r), p + Vector2(-r * 0.3, r * 0.3), p + Vector2(-r, 0),
		p + Vector2(-r * 0.3, -r * 0.3)]), color)
