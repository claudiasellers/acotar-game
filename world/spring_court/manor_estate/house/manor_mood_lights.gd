## The house's candles, chandeliers and hero spots answer the story's dread
## (experience bar §1.5: the light drops two to three stops and the pink world
## leaves; the candles gutter and cool). Listens to EventBus.mood_requested like GradeDirector does, so the
## house dims and cools in step with the grade.
class_name ManorMoodLights
extends Node

## Share of each light's energy left at full dread. The dread grade crushes
## the ambient and takes the exposure down about two stops; the candles and
## hearths only gutter a little, so the house shrinks to warm pools of light
## with deep dark between them (experience bar §1.5: interiors must frighten).
const DIM := 0.85
## Colour the lights burn toward at full dread: low candle and ember orange.
const EMBER := Color(1.0, 0.58, 0.30)

var amount := 0.0
var _target := 0.0
var _rate := 1.0
var _lights: Array[Light3D] = []
var _base: Array = []   # per light: [energy, colour]


func _ready() -> void:
	var bus := get_node_or_null(^"/root/EventBus")
	if bus != null and bus.has_signal(&"mood_requested"):
		bus.connect(&"mood_requested", _on_mood_requested)
	collect.call_deferred()
	set_process(false)


## Remembers every light under the parent (the house) at its calm settings.
func collect() -> void:
	_lights.clear()
	_base.clear()
	if get_parent() == null:
		return
	for l: Light3D in get_parent().find_children("*", "Light3D", true, false):
		_lights.append(l)
		_base.append([l.light_energy, l.light_color])
	apply()


func light_count() -> int:
	return _lights.size()


func apply() -> void:
	for i in _lights.size():
		var l := _lights[i]
		if not is_instance_valid(l):
			continue
		l.light_energy = float(_base[i][0]) * lerpf(1.0, DIM, amount)
		l.light_color = (_base[i][1] as Color).lerp(EMBER, amount * 0.6)


func _process(delta: float) -> void:
	amount = move_toward(amount, _target, _rate * delta)
	apply()
	if is_equal_approx(amount, _target):
		set_process(false)


func _on_mood_requested(mood: StringName, intensity: float, seconds: float) -> void:
	_target = GradeDirector.dread_weight(intensity) if mood == &"dread" else 0.0
	_rate = absf(_target - amount) / maxf(seconds, 0.001)
	set_process(true)
