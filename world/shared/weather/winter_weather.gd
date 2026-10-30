## Human-realm weather states, eased over time: clear, snow_light, snow_heavy,
## snow_slow (big slow flakes under a grey sky), snow_pause (the air holds
## still). Listens to EventBus.weather_requested from the story lane and
## otherwise wanders on its own with Clock days.
class_name WinterWeather
extends Node

## state: [snowfall 0-1, flake scale, fall speed, wind multiplier]
const STATES := {
	&"clear": [0.0, 1.0, 1.0, 0.6],
	&"snow_light": [0.3, 1.0, 1.0, 1.0],
	&"snow_heavy": [1.0, 1.0, 1.6, 2.2],
	&"snow_slow": [0.45, 2.4, 0.45, 0.3],
	&"snow_pause": [0.0, 2.4, 0.1, 0.0],
}

@export var prints: SnowPrints
@export var snowfall_node: Snowfall
@export var wind: WindDriver

var state: StringName = &"snow_light"
var values := PackedFloat32Array([0.3, 1.0, 1.0, 1.0])
var _from := PackedFloat32Array([0.3, 1.0, 1.0, 1.0])
var _t := 1.0
var _seconds := 1.0


func _ready() -> void:
	if EventBus.has_signal(&"weather_requested"):
		EventBus.connect(&"weather_requested", request)
	EventBus.day_started.connect(_on_day_started)


func request(to_state: StringName, seconds: float = 4.0) -> void:
	if not STATES.has(to_state):
		push_warning("WinterWeather: unknown state %s" % to_state)
		return
	_from = values.duplicate()
	state = to_state
	_seconds = maxf(seconds, 0.001)
	_t = 0.0


func _process(delta: float) -> void:
	if _t < 1.0:
		_t = minf(1.0, _t + delta / _seconds)
		var target: Array = STATES[state]
		for i in 4:
			values[i] = lerpf(_from[i], float(target[i]), _t)
	if prints != null:
		prints.snowfall = values[0]
	if wind != null:
		wind.default_strength = 0.35 * values[3]
	if snowfall_node != null and snowfall_node.process_material is ParticleProcessMaterial:
		var pm := snowfall_node.process_material as ParticleProcessMaterial
		pm.scale_min = 0.6 * values[1]
		pm.scale_max = 1.4 * values[1]
		snowfall_node.speed_scale = values[2]


func _on_day_started(day: int) -> void:
	var cycle: Array[StringName] = [&"snow_light", &"clear", &"snow_heavy", &"snow_light", &"clear"]
	request(cycle[day % cycle.size()], 30.0)
