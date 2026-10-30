## The cameo medallion on a thought card and the corner tab: a gold bezel
## set with pearl beads around a rose cameo, the need's subject carved in
## white relief. `glow` (0..1) breathes a rose halo and twinkles the beads
## while a thought waits unread (R3).
class_name GuideVignette
extends Control

const ICONS: Array[StringName] = [&"larder", &"trail", &"knife", &"coins", &"hearth", &"rose"]
const GOLD_LIGHT := Color(1.0, 0.94, 0.75)
const GOLD := Color(0.89, 0.71, 0.36)
const GOLD_DEEP := Color(0.66, 0.46, 0.16)
const BEAD := Color(1.0, 0.96, 0.84)
const CAMEO_LIGHT := Color(0.97, 0.78, 0.85)
const CAMEO := Color(0.89, 0.56, 0.69)
const CAMEO_DEEP := Color(0.78, 0.43, 0.58)
const RELIEF := Color(1.0, 0.97, 0.98)
const RELIEF_SHADOW := Color(0.62, 0.27, 0.45, 0.55)
const HALO := Color(1.0, 0.71, 0.84)

var icon: StringName = &"larder"
var glow: float = 0.0:
	set(v):
		glow = clampf(v, 0.0, 1.0)
		queue_redraw()
var _t: float = 0.0


func _init() -> void:
	custom_minimum_size = Vector2(84, 84)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_icon(kind: StringName) -> void:
	icon = kind if kind in ICONS else &"larder"
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	if glow > 0.0 or icon == &"hearth":
		queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var big := minf(size.x, size.y) * 0.5 - 2.0
	if glow > 0.0:
		for i in 6:
			var rr := big + 3.0 + i * 2.2
			draw_arc(c, rr, 0.0, TAU, 48, Color(HALO, glow * (0.55 - i * 0.085)), 2.4, true)
	# Drop shadow, then the bezel: deep rim, gold face, light catch top-left.
	draw_circle(c + Vector2(0, 3), big + 1.0, Color(0.35, 0.14, 0.31, 0.22))
	draw_circle(c, big, GOLD_DEEP)
	draw_circle(c, big - 1.2, GOLD)
	draw_arc(c, big - 3.0, PI * 1.05, PI * 1.75, 16, Color(GOLD_LIGHT, 0.9), 2.5, true)
	var bead_r := big * 0.86
	for i in 24:
		var a := i * TAU / 24.0
		var tw := 0.0 if glow <= 0.0 else glow * (0.5 + 0.5 * sin(_t * 4.0 - i * 0.6))
		draw_circle(c + Vector2(cos(a), sin(a)) * bead_r, big * 0.042 + tw * 0.8, BEAD.lerp(Color.WHITE, tw))
	# The cameo: a soft radial rose, lighter up and to the left.
	var cam := big * 0.74
	draw_circle(c, cam + 1.0, GOLD_DEEP)
	for i in 8:
		var k := i / 7.0
		var col := CAMEO_DEEP.lerp(CAMEO, minf(k * 1.6, 1.0)).lerp(CAMEO_LIGHT, maxf(k - 0.55, 0.0) * 2.2)
		draw_circle(c + Vector2(-0.18, -0.2) * cam * k, cam * (1.0 - k * 0.62), col)
	draw_set_transform(c + Vector2(-cam * 0.2, -cam * 0.45), 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, cam * 0.5, Color(1, 1, 1, 0.2))
	draw_set_transform(Vector2.ZERO)
	# Relief: shadow pass a hair lower, then the white carving.
	_draw_subject(c + Vector2(0, 1.5), cam * 1.2, RELIEF_SHADOW)
	_draw_subject(c, cam * 1.2, RELIEF)


func _draw_subject(c: Vector2, r: float, col: Color) -> void:
	match icon:
		&"trail": _draw_trail(c, r, col)
		&"knife": _draw_knife(c, r, col)
		&"coins": _draw_coins(c, r, col)
		&"hearth": _draw_hearth(c, r, col)
		&"rose": _draw_rose(c, r, col)
		_: _draw_larder(c, r, col)


## An empty crock and one heel of bread.
func _draw_larder(c: Vector2, r: float, col: Color) -> void:
	draw_rect(Rect2(c + Vector2(-r * 0.42, -r * 0.52), Vector2(r * 0.74, r * 0.17)), col)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.36, -r * 0.30), c + Vector2(r * 0.26, -r * 0.30),
		c + Vector2(r * 0.32, r * 0.30), c + Vector2(r * 0.20, r * 0.50), c + Vector2(-r * 0.30, r * 0.50),
		c + Vector2(-r * 0.42, r * 0.30)]), col)
	draw_circle(c + Vector2(r * 0.36, r * 0.36), r * 0.19, col)


## Two pines and hoof-prints leading between them.
func _draw_trail(c: Vector2, r: float, col: Color) -> void:
	for x in [-0.42, 0.42]:
		var base := c + Vector2(r * x, r * 0.30)
		draw_colored_polygon(PackedVector2Array([base + Vector2(-r * 0.24, 0),
			base + Vector2(0, -r * 0.78), base + Vector2(r * 0.24, 0)]), col)
		draw_rect(Rect2(base + Vector2(-r * 0.04, 0), Vector2(r * 0.08, r * 0.14)), col)
	for i in 3:
		var p := c + Vector2((i % 2) * r * 0.12 - r * 0.06, r * 0.52 - i * r * 0.28)
		draw_circle(p + Vector2(-r * 0.05, 0), r * 0.045, col)
		draw_circle(p + Vector2(r * 0.05, 0), r * 0.045, col)


func _draw_knife(c: Vector2, r: float, col: Color) -> void:
	var tip := c + Vector2(r * 0.52, -r * 0.52)
	var hilt := c + Vector2(-r * 0.08, r * 0.08)
	var side := (tip - hilt).orthogonal().normalized() * r * 0.12
	draw_colored_polygon(PackedVector2Array([hilt + side, tip, hilt - side]), col)
	draw_line(hilt + side * 1.9, hilt - side * 1.9, col, r * 0.09)
	draw_line(hilt, c + Vector2(-r * 0.46, r * 0.46), col, r * 0.15)


func _draw_coins(c: Vector2, r: float, col: Color) -> void:
	for i in 3:
		var p := c + Vector2(-r * 0.26 + i * r * 0.26, r * 0.24 - i * r * 0.2)
		draw_circle(p, r * 0.26, col)
		if col.a > 0.9:
			draw_arc(p, r * 0.17, 0.0, TAU, 20, Color(CAMEO, 0.45), 1.2, true)


## The cottage with a lit window.
func _draw_hearth(c: Vector2, r: float, col: Color) -> void:
	var body := Rect2(c + Vector2(-r * 0.42, -r * 0.04), Vector2(r * 0.84, r * 0.52))
	draw_rect(body, col)
	draw_colored_polygon(PackedVector2Array([body.position + Vector2(-r * 0.12, 0),
		c + Vector2(0, -r * 0.58), body.position + Vector2(body.size.x + r * 0.12, 0)]), col)
	if col.a > 0.9:
		var flicker := 0.5 + 0.5 * sin(_t * 2.0)
		draw_rect(Rect2(c + Vector2(-r * 0.11, r * 0.1), Vector2(r * 0.22, r * 0.2)),
			CAMEO.lerp(Color(1.0, 0.85, 0.55), flicker * 0.6))


## A cameo rose: bloom, stem and two leaves.
func _draw_rose(c: Vector2, r: float, col: Color) -> void:
	var bloom := c + Vector2(0, -r * 0.24)
	draw_circle(bloom, r * 0.27, col)
	for i in 3:
		var a := PI * 0.9 + i * PI * 0.6
		draw_circle(bloom + Vector2(cos(a), sin(a)) * r * 0.14, r * 0.17, col)
	draw_line(bloom + Vector2(0, r * 0.2), c + Vector2(0, r * 0.62), col, r * 0.07)
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, r * 0.3), c + Vector2(-r * 0.32, r * 0.16),
		c + Vector2(-r * 0.12, r * 0.36)]), col)
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, r * 0.42), c + Vector2(r * 0.32, r * 0.28),
		c + Vector2(r * 0.12, r * 0.48)]), col)
	if col.a > 0.9:
		draw_arc(bloom, r * 0.1, 0.4, TAU * 0.75, 12, Color(CAMEO, 0.5), 1.2, true)
