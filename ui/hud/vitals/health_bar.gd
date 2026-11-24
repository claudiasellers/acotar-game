## The health bar beside the stamina rose (bottom left): a rounded rose fill
## over a dark track, a pearl lag fill that drains after a hit, a gold notch at
## the walk-it-off regen cap, a pink sheen while healing, bile veins under venom
## and a heartbeat pulse when she is badly hurt (plan §15 A2).
class_name VitalsHealthBar
extends Control

const BAR := Vector2(320, 12)
const TRACK := Color(0.118, 0.086, 0.165, 0.42)
const ROSE := Color("#F0668C")
const HUMAN_FILL := Color("#B8574F")
const LAG := Color(1.0, 0.96, 0.93, 0.85)
const LOW := Color("#7A1E2A")
const BILE := Color("#6F7F3A")
const ICHOR := Color("#120C10")
const NOTCH := Color("#E8C14A")
const SHEEN := Color(1.0, 0.86, 0.92, 0.9)
const LAG_DELAY := 0.4
const LAG_SPEED := 0.6

## 0..1 of max.
var fraction: float = 1.0
var regen_cap: float = 0.5
var venom: float = 0.0
var healing: bool = false
var human_realm: bool = false
var line: Color = Color("#3A2444")
var _lag: float = 1.0
var _lag_hold: float = 0.0
var _sheen: float = 0.0
var _flash: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = BAR + Vector2(8, 8)
	size = custom_minimum_size


func set_health(value: float) -> void:
	if value < fraction:
		_lag = maxf(_lag, fraction)
		_lag_hold = LAG_DELAY
		_flash = 1.0
	fraction = value


func _process(delta: float) -> void:
	_lag_hold -= delta
	if _lag_hold <= 0.0:
		_lag = move_toward(_lag, fraction, LAG_SPEED * delta)
	_lag = maxf(_lag, fraction)
	_flash = maxf(_flash - delta * 4.0, 0.0)
	_sheen = fmod(_sheen + delta * 0.8, 1.6) if healing else 0.0
	queue_redraw()


func _draw() -> void:
	var o := Vector2(4, 4)
	var r := BAR.y * 0.5
	# A hairline in her plum, like the icons' line, keeps it readable on snow.
	draw_style_rect(Rect2(o - Vector2(1.2, 1.2), BAR + Vector2(2.4, 2.4)), r + 1.2, Color(line, 0.55))
	draw_style_rect(Rect2(o, BAR), r, TRACK)
	if _lag > fraction:
		draw_style_rect(Rect2(o, Vector2(BAR.x * _lag, BAR.y)), r, LAG)
	var fill := HUMAN_FILL if human_realm else ROSE
	if fraction < 0.3:
		var beat := pow(absf(sin(Time.get_ticks_msec() * 0.0036)), 8.0)
		fill = fill.lerp(LOW, 0.35 + 0.4 * beat)
	if venom >= 0.1:
		fill = fill.lerp(BILE, clampf(venom, 0.0, 0.7))
	fill = fill.lerp(Color.WHITE, _flash * 0.6)
	var w := maxf(BAR.x * fraction, BAR.y if fraction > 0.0 else 0.0)
	if fraction > 0.0:
		draw_style_rect(Rect2(o, Vector2(w, BAR.y)), r, fill)
		draw_style_rect(Rect2(o + Vector2(r * 0.6, 2.0), Vector2(maxf(w - r * 1.2, 0.0), 2.5)), 1.25, Color(1, 1, 1, 0.35))
	if venom >= 0.1:
		var veins := int(3 + venom * 6)
		for i in veins:
			var x := o.x + (float(i) + 0.5) / veins * w
			draw_line(Vector2(x - 4, o.y + 2), Vector2(x + 3, o.y + BAR.y - 2), Color(ICHOR, 0.7), 1.5, true)
	if healing and fraction > 0.0:
		var sx := o.x + (_sheen - 0.2) * w
		var x0 := clampf(sx, o.x, o.x + w)
		var x1 := clampf(sx + 22.0, o.x, o.x + w)
		if x1 > x0:
			draw_style_rect(Rect2(Vector2(x0, o.y), Vector2(x1 - x0, BAR.y)), r, SHEEN)
	if regen_cap < 0.999:
		var nx := o.x + BAR.x * regen_cap
		var c := Vector2(nx, o.y - 3.0)
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -4), c + Vector2(3.2, 0), c + Vector2(0, 4), c + Vector2(-3.2, 0)]), NOTCH)


func draw_style_rect(rect: Rect2, radius: float, color: Color) -> void:
	if rect.size.x <= 0.0:
		return
	radius = minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	var pts := PackedVector2Array()
	var steps := 6
	var corners := [
		[rect.position + Vector2(rect.size.x - radius, radius), -PI * 0.5],
		[rect.position + Vector2(rect.size.x - radius, rect.size.y - radius), 0.0],
		[rect.position + Vector2(radius, rect.size.y - radius), PI * 0.5],
		[rect.position + Vector2(radius, radius), PI],
	]
	for c: Array in corners:
		for i in steps + 1:
			var a: float = c[1] + PI * 0.5 * i / steps
			var pt: Vector2 = (c[0] as Vector2) + Vector2(cos(a), sin(a)) * radius
			# A pill's straight edges have no length: skip the doubled points.
			if pts.is_empty() or pts[pts.size() - 1].distance_squared_to(pt) > 0.01:
				pts.append(pt)
	if pts.size() > 2 and pts[0].distance_squared_to(pts[pts.size() - 1]) <= 0.01:
		pts.remove_at(pts.size() - 1)
	draw_colored_polygon(pts, color)
