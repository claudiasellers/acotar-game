## A cutscene's grade laid over the game picture (lane L33): the glamour's
## veil, the bloom when it lifts, gold on every edge, power cooling the light,
## violet static cracking in. Sits under the film's veil and words. Each
## look is a shader uniform (film_grade.gdshader), tweened with `to_param`.
class_name FilmGrade
extends CanvasLayer

const SHADER := preload("res://story/film/film_grade.gdshader")
const PARAMS: Array[StringName] = [&"veil", &"bloom", &"edge_gold", &"cold", &"crack"]

var rect: ColorRect
var material: ShaderMaterial
var _t: float = 0.0
var _tweens: Dictionary = {}


func _init() -> void:
	layer = FilmPlayer.LAYER_INSERT - 1
	name = "FilmGrade"


func _ready() -> void:
	rect = ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	material = ShaderMaterial.new()
	material.shader = SHADER
	rect.material = material
	add_child(rect)
	_refresh()


func _process(delta: float) -> void:
	_t += delta
	material.set_shader_parameter(&"t", _t)


func value(param: StringName) -> float:
	return float(material.get_shader_parameter(param)) if material else 0.0


## Eases one look to `v` over `seconds`.
func to_param(param: StringName, v: float, seconds: float) -> void:
	if _tweens.has(param) and (_tweens[param] as Tween).is_valid():
		(_tweens[param] as Tween).kill()
	if seconds <= 0.0:
		material.set_shader_parameter(param, v)
		_refresh()
		return
	var tw := create_tween()
	tw.tween_method(func(x: float) -> void:
		material.set_shader_parameter(param, x)
		_refresh(), value(param), v, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tweens[param] = tw


## Every look to `v` (0 clears the grade).
func to(v: float, seconds: float) -> void:
	for p in PARAMS:
		to_param(p, v, seconds)


## Nothing on: the overlay is hidden, so it costs nothing.
func _refresh() -> void:
	var any := false
	for p in PARAMS:
		if value(p) > 0.001:
			any = true
	rect.visible = any
