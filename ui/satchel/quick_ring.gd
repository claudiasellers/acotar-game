## One quick slot: a brass ring hung from the strap on a leather tab, with the
## item sitting inside. It swings on a damped spring about its tab when
## kicked (used, pinned, or the chord coming down).
class_name QuickRing
extends Control

const RADIUS := 32.0
const TAB := Vector2(12, 12)
const ICON_PX := 44.0
## Spring stiffness and damping for the swing.
const K := 70.0
const DAMP := 5.0

## Lit while the pad chord (LB) is held.
var lit: bool = false:
	set(v):
		lit = v
		queue_redraw()

var _angle: float = 0.0
var _spin: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(RADIUS * 2.0 + 8.0, TAB.y + RADIUS * 2.0 + 8.0)
	size = custom_minimum_size
	pivot_offset = Vector2(size.x * 0.5, 0.0)


func centre() -> Vector2:
	return Vector2(size.x * 0.5, TAB.y + RADIUS + 2.0)


## Sets it swinging; `amount` is in radians per second.
func kick(amount: float) -> void:
	_spin += amount


func _process(delta: float) -> void:
	_spin += (-K * _angle - DAMP * _spin) * delta
	_angle += _spin * delta
	rotation = _angle


func _draw() -> void:
	var ink := SatchelTheme.color(&"ink")
	var line := SatchelTheme.color(&"line")
	var glow := SatchelTheme.color(&"glow")
	var paper := SatchelTheme.color(&"paper")
	var c := centre()
	draw_rect(Rect2(Vector2(c.x - TAB.x * 0.5, 0), TAB + Vector2(0, 4)), ink.darkened(0.1))
	draw_circle(c, RADIUS - 2.0, Color(paper, 0.82))
	draw_arc(c, RADIUS, 0, TAU, 40, line.darkened(0.25), 5.0, true)
	draw_arc(c, RADIUS - 1.0, PI * 1.1, PI * 1.6, 12, (glow if lit else line).lightened(0.35), 2.0, true)
	if lit:
		draw_arc(c, RADIUS + 4.0, 0, TAU, 40, Color(glow, 0.55), 2.0, true)
