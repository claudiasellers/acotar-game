## The one full-screen pass for Feyre's screen edges (edge_fx.gdshader). The
## HUD sets `target` values each frame; this eases toward them and feeds the
## shader. `strength` follows the Screen-edge effects setting; the knockdown and
## wake irises ignore it.
class_name VitalsEdgeFx
extends ColorRect

const SHADER := preload("res://ui/hud/vitals/edge_fx.gdshader")
const GROUP := &"vitals_edge_fx"
const EASED: Array[StringName] = [&"dread", &"low_health", &"venom", &"cold", &"fae", &"ease", &"heal", &"hidden"]

## uniform -> wanted value.
var target: Dictionary = {}
var _now: Dictionary = {}
var _mat: ShaderMaterial
## Seconds left of the unseen-attack beat, and the seconds it was given.
var _warn_left: float = 0.0
var _warn_for: float = 1.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	color = Color.WHITE
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	material = _mat
	add_to_group(GROUP)
	var paper := JournalTheme.color(&"paper")
	_mat.set_shader_parameter(&"paper_color", Vector3(paper.r, paper.g, paper.b))


func set_strength(value: float) -> void:
	_mat.set_shader_parameter(&"strength", value)


func set_frost_human(human: bool) -> void:
	var c: Color = JournalTheme.VITALS[JournalTheme.Act.HUMAN if human else JournalTheme.Act.SPRING].frost
	_mat.set_shader_parameter(&"frost_color", Vector3(c.r, c.g, c.b))


## An attack she cannot see is winding up: the edge on that side beats until
## it lands. `side` runs -1 (hard left) to 1 (hard right), 0 is behind her.
## Follows the hit marks setting, like the bruise it warns of.
static func warn(tree: SceneTree, side: float, seconds: float) -> void:
	if not bool(GameSettings.get_value(&"hit_marks")):
		return
	for fx: VitalsEdgeFx in tree.get_nodes_in_group(GROUP):
		fx._warn_for = maxf(seconds, 0.05)
		fx._warn_left = fx._warn_for
		fx._mat.set_shader_parameter(&"warn_side", clampf(side, -1.0, 1.0))


func _process(delta: float) -> void:
	_warn_left = maxf(_warn_left - delta, 0.0)
	# Rises as the blow nears.
	target[&"warn"] = (1.0 - 0.6 * _warn_left / _warn_for) if _warn_left > 0.0 else 0.0
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
