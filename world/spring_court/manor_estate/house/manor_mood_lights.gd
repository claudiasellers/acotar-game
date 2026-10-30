## The house's candles, chandeliers and hero spots answer the story's dread
## (experience bar §1.5: the light drops two to three stops and the pink world
## leaves; the candles gutter and cool). Listens to EventBus.mood_requested like GradeDirector does, so the
## house dims and cools in step with the grade.
class_name ManorMoodLights
extends Node

## Share of each light's energy left at full dread. The dread grade already
## takes the exposure down about two stops; the candles only gutter on top.
const DIM := 0.6
## Colour the warm lights cool toward at full dread.
const COLD := Color(0.72, 0.74, 0.95)

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
		l.light_color = (_base[i][1] as Color).lerp(COLD, amount * 0.6)


func _process(delta: float) -> void:
	amount = move_toward(amount, _target, _rate * delta)
	apply()
	if is_equal_approx(amount, _target):
		set_process(false)


func _on_mood_requested(mood: StringName, intensity: float, seconds: float) -> void:
	_target = clampf(intensity, 0.0, 1.0) if mood == &"dread" else 0.0
	_rate = absf(_target - amount) / maxf(seconds, 0.001)
	set_process(true)
