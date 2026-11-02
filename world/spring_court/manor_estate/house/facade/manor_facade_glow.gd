## Lights the manor's outer window panes (and darkens the view from inside) as the sun goes down (L42): 0 by day
## (L18-4: no glow at noon), full from just after sunset until dawn.
class_name ManorFacadeGlow
extends Node

## Sun elevation (sin) where the glow starts / is full.
const START := 0.22
const FULL := -0.04

var materials: Array[ShaderMaterial] = []
var _last := -1.0


func _process(_delta: float) -> void:
	if materials.is_empty():
		return
	var clock := get_node_or_null(^"/root/Clock")
	var t: float = clock.time_of_day if clock != null else 0.5
	var g := amount(t)
	if absf(g - _last) > 0.003:
		_last = g
		for m in materials:
			m.set_shader_parameter(&"glow", g)


## Glow for a time of day (0..1, 0.5 = noon), using GradeDirector's sun path.
static func amount(time_of_day: float) -> float:
	var elevation := sin((time_of_day - 0.25) * TAU)
	return 1.0 - smoothstep(FULL, START, elevation)
