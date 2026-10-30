## Fire, wet and cold on anything: Feyre, an arrow, a log, a pelt (build plan
## ElementState). Each is 0..1, and they push on each other:
## - Fire dries wet and drives out cold; wet smothers fire.
## - Cold rises toward a target set by air temperature, wetness and shelter,
##   and falls near heat sources (nodes in group "heat_source" with heat_at()).
## - Exposed things get wet in rain, more slowly in snow.
class_name ElementState
extends Node

signal changed

const HEAT_GROUP := &"heat_source"

@export var exposed: bool = true
## 0..1 protection from cold (clothing, a blanket).
@export var insulation: float = 0.0

var fire: float = 0.0
var wet: float = 0.0
var cold: float = 0.0
## Extra insulation from food effects ("warm"), set by BodyState.
var insulation_bonus: float = 0.0
## Last heat value this node felt (for readers such as the HUD or a cat).
var heat: float = 0.0


func _physics_process(delta: float) -> void:
	var host := get_parent() as Node3D
	var weather := Weather.find(get_tree())
	var temp := weather.temperature_c() if weather else 10.0
	var precip := weather.precipitation if weather else 0.0
	var kind := weather.precipitation_kind if weather else &"rain"
	heat = heat_at(get_tree(), host.global_position) if host else 0.0
	step(delta, temp, precip if exposed else 0.0, kind, heat)


## Advances the state by `delta` seconds. Pure, so tests can drive it.
func step(delta: float, temperature_c: float, precipitation: float, kind: StringName, heat_in: float) -> void:
	var before := Vector3(fire, wet, cold)
	# Wetting.
	var wet_rate := 0.012 if kind == &"rain" else 0.004
	wet += precipitation * wet_rate * delta
	# Drying: heat and fire dry; above freezing things dry slowly on their own.
	wet -= (heat_in * 0.05 + fire * 0.2 + (0.002 if temperature_c > 0.0 else 0.0)) * delta
	# Fire: wet smothers it, it burns down on its own.
	fire -= (wet * 0.5 + 0.08) * delta
	# Cold moves toward its target.
	var target := clampf((6.0 - temperature_c) / 20.0, 0.0, 1.0)
	target += wet * 0.3
	target *= 1.0 - clampf(insulation + insulation_bonus, 0.0, 0.9)
	target -= heat_in + fire
	target = clampf(target, 0.0, 1.0)
	var rate := 0.015 if target > cold else 0.04
	cold = move_toward(cold, target, rate * delta)
	fire = clampf(fire, 0.0, 1.0)
	wet = clampf(wet, 0.0, 1.0)
	if not before.is_equal_approx(Vector3(fire, wet, cold)):
		changed.emit()


func ignite(amount: float = 0.6) -> void:
	if wet > 0.6:
		return
	fire = clampf(fire + amount, 0.0, 1.0)
	changed.emit()


func soak(amount: float = 1.0) -> void:
	wet = clampf(wet + amount, 0.0, 1.0)
	fire = maxf(fire - amount, 0.0)
	changed.emit()


func chill(amount: float = 0.5) -> void:
	cold = clampf(cold + amount, 0.0, 1.0)
	fire = maxf(fire - amount, 0.0)
	changed.emit()


func is_wet() -> bool:
	return wet >= 0.5


## Sum of nearby heat sources, 0..1.
static func heat_at(tree: SceneTree, world_pos: Vector3) -> float:
	if tree == null:
		return 0.0
	var total := 0.0
	for source in tree.get_nodes_in_group(HEAT_GROUP):
		if source.has_method(&"heat_at"):
			total += float(source.heat_at(world_pos))
	return clampf(total, 0.0, 1.0)
