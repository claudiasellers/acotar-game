## The little painted medallion on a thought card: a pearl disc with a gold
## ring, one simple picture and a few drifting sparkle motes (R3).
class_name GuideVignette
extends Control

const ICONS: Array[StringName] = [&"larder", &"trail", &"knife", &"coins", &"hearth", &"rose"]
const GOLD := Color(0.93, 0.76, 0.40)
const INK := Color(0.45, 0.28, 0.40)
const PEARL := Color(1.0, 0.96, 0.97)
const BLUSH := Color(0.98, 0.80, 0.87)
const LILAC := Color(0.82, 0.74, 0.96)
const MINT := Color(0.70, 0.90, 0.80)
const BUTTER := Color(1.0, 0.91, 0.62)
const ROSE := Color(0.95, 0.52, 0.68)

var icon: StringName = &"larder"
var _t: float = 0.0


func _init() -> void:
	custom_minimum_size = Vector2(96, 96)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_icon(kind: StringName) -> void:
	icon = kind if kind in ICONS else &"larder"
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5 - 3.0
	draw_circle(c, r + 3.0, GOLD)
	draw_circle(c, r, BLUSH)
	draw_circle(c + Vector2(0, -r * 0.18), r * 0.82, PEARL)
	var ir := r * 1.25  # the picture fills the pearl, not the whole disc
	match icon:
		&"trail": _draw_trail(c, ir)
		&"knife": _draw_knife(c, ir)
		&"coins": _draw_coins(c, ir)
		&"hearth": _draw_hearth(c, ir)
		&"rose": _draw_rose(c, ir)
		_: _draw_larder(c, ir)
	for i in 5:
		var a := _t * 0.6 + i * TAU / 5.0
		var p := c + Vector2(cos(a), sin(a * 1.3)) * r * (0.55 + 0.3 * sin(_t + i))
		var tw := 0.5 + 0.5 * sin(_t * 3.0 + i * 1.7)
		_sparkle(p, 2.0 + 2.5 * tw, Color(1, 1, 1, 0.35 + 0.6 * tw))


func _sparkle(p: Vector2, s: float, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([p + Vector2(0, -s), p + Vector2(s * 0.3, 0),
		p + Vector2(0, s), p + Vector2(-s * 0.3, 0)]), col)
	draw_colored_polygon(PackedVector2Array([p + Vector2(-s, 0), p + Vector2(0, s * 0.3),
		p + Vector2(s, 0), p + Vector2(0, -s * 0.3)]), col)


## An empty crock and one heel of bread.
func _draw_larder(c: Vector2, r: float) -> void:
	var jar := Rect2(c + Vector2(-r * 0.42, -r * 0.30), Vector2(r * 0.62, r * 0.78))
	draw_rect(jar, LILAC)
	draw_rect(Rect2(jar.position + Vector2(-r * 0.06, -r * 0.12), Vector2(jar.size.x + r * 0.12, r * 0.14)), GOLD)
	draw_circle(c + Vector2(r * 0.40, r * 0.30), r * 0.20, BUTTER)
	draw_arc(c + Vector2(r * 0.40, r * 0.30), r * 0.20, PI, TAU, 12, INK, 1.5)


## Two rounded pines and hoof-prints leading between them.
func _draw_trail(c: Vector2, r: float) -> void:
	for x in [-0.45, 0.45]:
		var base := c + Vector2(r * x, r * 0.35)
		draw_colored_polygon(PackedVector2Array([base + Vector2(-r * 0.24, 0),
			base + Vector2(0, -r * 0.8), base + Vector2(r * 0.24, 0)]), MINT)
	for i in 3:
		var p := c + Vector2((i % 2) * r * 0.12 - r * 0.06, r * 0.5 - i * r * 0.28)
		draw_circle(p + Vector2(-2.5, 0), 2.2, INK)
		draw_circle(p + Vector2(2.5, 0), 2.2, INK)


func _draw_knife(c: Vector2, r: float) -> void:
	var tip := c + Vector2(r * 0.5, -r * 0.5)
	var hilt := c + Vector2(-r * 0.1, r * 0.1)
	var side := (tip - hilt).orthogonal().normalized() * r * 0.11
	draw_colored_polygon(PackedVector2Array([hilt + side, tip, hilt - side]), Color(0.86, 0.88, 0.95))
	draw_line(hilt + side * 1.8, hilt - side * 1.8, GOLD, 4.0)
	draw_line(hilt, c + Vector2(-r * 0.45, r * 0.45), ROSE, 6.0)


func _draw_coins(c: Vector2, r: float) -> void:
	for i in 3:
		var p := c + Vector2(-r * 0.25 + i * r * 0.25, r * 0.25 - i * r * 0.18)
		draw_circle(p, r * 0.26, GOLD)
		draw_circle(p, r * 0.18, BUTTER)


## The cottage with a lit window.
func _draw_hearth(c: Vector2, r: float) -> void:
	var body := Rect2(c + Vector2(-r * 0.45, -r * 0.05), Vector2(r * 0.9, r * 0.55))
	draw_rect(body, LILAC)
	draw_colored_polygon(PackedVector2Array([body.position + Vector2(-r * 0.1, 0),
		c + Vector2(0, -r * 0.6), body.position + Vector2(body.size.x + r * 0.1, 0)]), ROSE)
	draw_rect(Rect2(c + Vector2(-r * 0.1, r * 0.08), Vector2(r * 0.22, r * 0.2)),
		BUTTER.lerp(Color(1, 0.7, 0.4), 0.5 + 0.5 * sin(_t * 2.0)))


func _draw_rose(c: Vector2, r: float) -> void:
	for i in 5:
		var a := i * TAU / 5.0 + 0.3
		draw_circle(c + Vector2(cos(a), sin(a)) * r * 0.25, r * 0.24, ROSE.lightened(0.15))
	draw_circle(c, r * 0.2, ROSE)
	draw_arc(c, r * 0.12, 0, TAU * 0.8, 12, INK, 1.5)
