## Alis's true form under Tamlin's glamour (lore/03-characters/alis.md, canon
## ch24): skin "made from tree bark" that bleaches birch-white when she is
## frightened, wild brown hair, the same brass bird mask. Hangs inside
## alis_model.tscn; while `glamour_lifted` is up it swaps the cast model's
## skin to the bark shader and her neat bun for loose wild curls, and swaps
## back if the flag is cleared (a reload into an earlier save).
##   frighten(1.0) bleaches her, then she colours back over `recover` seconds.
class_name AlisTrueForm
extends Node

const BARK_SHADER := preload("res://characters/alis/true_form/bark_skin.gdshader")
const WILD_HAIR := "res://characters/feyre/hair/soft_curls.glb"
const HAIR_COLOR := Color(0.36, 0.22, 0.13)

## Seconds to colour back after a fright.
@export var recover: float = 4.0

var model: Node3D
var lifted: bool = false
var fright: float = 0.0
var _bark: ShaderMaterial
var _hair_mat: CandyMaterial
var _glamoured: Dictionary = {}  # "head"/"body"/"hair" -> what the model wore


func _ready() -> void:
	model = get_parent() as Node3D
	_bark = ShaderMaterial.new()
	_bark.shader = BARK_SHADER
	_hair_mat = MaterialLibrary.surface()
	_hair_mat.albedo_color = HAIR_COLOR
	_hair_mat.roughness = 0.45
	_hair_mat.rim_enabled = true
	_hair_mat.rim = 0.35
	EventBus.flag_changed.connect(_on_flag_changed)
	# The cast model builds its body in its own _ready (after ours): look next frame.
	_sync.call_deferred()


func _on_flag_changed(flag: String, _value: Variant) -> void:
	if flag == GlamourLayer.FLAG or flag == "":
		_sync()


## Bleaches her birch-white at `amount` (0..1); she colours back on her own.
func frighten(amount: float = 1.0) -> void:
	fright = maxf(fright, clampf(amount, 0.0, 1.0))
	_bark.set_shader_parameter(&"fright", fright)


func _process(delta: float) -> void:
	if fright <= 0.0:
		return
	fright = maxf(0.0, fright - delta / maxf(recover, 0.01))
	_bark.set_shader_parameter(&"fright", fright)


func _sync() -> void:
	if model == null or not is_inside_tree():
		return
	var want := GlamourLayer.is_lifted()
	if want == lifted:
		return
	lifted = want
	if lifted:
		_glamoured["head"] = model.get(&"skin_head_material")
		_glamoured["body"] = model.get(&"skin_body_material")
		_glamoured["hair"] = model.get(&"hair_path")
		_wear(_bark, _bark, WILD_HAIR)
		var hair := model.get(&"hair") as Node3D
		if hair:
			for mi in hair.find_children("*", "MeshInstance3D", true, false):
				(mi as MeshInstance3D).material_override = _hair_mat
			hair.scale = Vector3(1.06, 1.04, 1.08)
	else:
		_wear(_glamoured.get("head"), _glamoured.get("body"), String(_glamoured.get("hair", "")))


func _wear(head: Material, body_mat: Material, hair_path: String) -> void:
	model.set(&"skin_head_material", head)
	model.set(&"skin_body_material", body_mat)
	for mi_name in ["Body", "Body_LOD1"]:
		var mi := model.find_child(mi_name, true, false) as MeshInstance3D
		if mi and model.has_method(&"_apply_skin"):
			model.call(&"_apply_skin", mi)
	if hair_path != "" and model.has_method(&"set_hair"):
		model.call(&"set_hair", hair_path)
