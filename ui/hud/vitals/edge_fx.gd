## The one full-screen pass for Feyre's screen edges (edge_fx.gdshader). The
## HUD sets `target` values each frame; this eases toward them and feeds the
## shader. `strength` follows the Screen-edge effects setting; the knockdown and
## wake irises ignore it.
class_name VitalsEdgeFx
extends ColorRect

const SHADER := preload("res://ui/hud/vitals/edge_fx.gdshader")
const FROST_SPRING := Color(0.86, 0.90, 1.0)
const FROST_HUMAN := Color(0.92, 0.97, 1.0)
const EASED: Array[StringName] = [&"dread", &"low_health", &"venom", &"cold", &"fae", &"ease", &"heal"]

## uniform -> wanted value.
var target: Dictionary = {}
var _now: Dictionary = {}
var _mat: ShaderMaterial


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	color = Color.WHITE
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	material = _mat


func set_strength(value: float) -> void:
	_mat.set_shader_parameter(&"strength", value)


func set_frost_human(human: bool) -> void:
	var c := FROST_HUMAN if human else FROST_SPRING
	_mat.set_shader_parameter(&"frost_color", Vector3(c.r, c.g, c.b))


func _process(delta: float) -> void:
	var view := get_viewport_rect().size
	_mat.set_shader_parameter(&"aspect", view.x / maxf(view.y, 1.0))
	for key: StringName in target:
		var want := float(target[key])
		var cur := float(_now.get(key, 0.0))
		if EASED.has(key):
			cur = move_toward(cur, want, delta * 0.8)
		else:
			cur = want
		_now[key] = cur
		_mat.set_shader_parameter(key, cur)
	var shown := false
	for key: StringName in _now:
		if key == &"wake":
			shown = shown or float(_now[key]) < 1.0
		elif float(_now[key]) > 0.001:
			shown = true
	visible = shown


func set_hit(direction: Vector2, amount: float) -> void:
	_mat.set_shader_parameter(&"hit_dir", direction)
	target[&"hit_amount"] = amount


func value(key: StringName) -> float:
	return float(_now.get(key, 0.0))
