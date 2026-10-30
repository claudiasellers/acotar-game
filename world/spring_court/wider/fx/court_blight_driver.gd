## Drives the per-material `blight` uniform (0 = healthy, 1 = fully blighted) on
## every Spring Court FX material with blight_affect > 0. The story lane calls
## CourtBlightDriver.set_blight(v); wind, snow and magic come from the project
## shader globals (wind_direction, wind_strength, snow_cover, magic_amount) that
## the World scene drives, so this node registers no globals of its own.
## Safe to instance any number of times: state is static and shared.
class_name CourtBlightDriver
extends Node

const MATERIAL_DIR := "res://world/spring_court/wider/fx/materials/"
## Shipped materials that react to blight (blight_affect > 0 is checked at load).
const SHIPPED_MATERIALS: Array[String] = [
	"mat_foliage_default", "mat_foliage_glow", "mat_foliage_blight",
	"mat_prop_default", "mat_prop_pearl", "mat_prop_glitter",
	"mat_water_lake", "mat_water_river", "mat_water_starlight",
	"mat_glint", "mat_terrain_tint",
]

static var _blight: float = 0.0
static var _registry: Array[ShaderMaterial] = []
static var _shipped_loaded: bool = false

## Optional starting value applied when this node enters the tree (-1 = keep).
@export_range(-1.0, 1.0) var initial_blight: float = -1.0


func _ready() -> void:
	CourtBlightDriver.ensure_shipped_registered()
	if initial_blight >= 0.0:
		CourtBlightDriver.set_blight(initial_blight)
	else:
		CourtBlightDriver.set_blight(_blight)


static func set_blight(value: float) -> void:
	_blight = clampf(value, 0.0, 1.0)
	ensure_shipped_registered()
	for mat: ShaderMaterial in _registry:
		if is_instance_valid(mat):
			mat.set_shader_parameter(&"blight", _blight)


static func get_blight() -> float:
	return _blight


## Adds a material (for example a region's duplicate of a shipped one) when its
## blight_affect is above zero. Returns true if it is now registered.
static func register_material(mat: ShaderMaterial) -> bool:
	if mat == null or mat.shader == null:
		return false
	var affect: Variant = mat.get_shader_parameter(&"blight_affect")
	if affect == null:
		affect = RenderingServer.shader_get_parameter_default(mat.shader.get_rid(), &"blight_affect")
	if affect == null or float(affect) <= 0.0:
		return false
	if not _registry.has(mat):
		_registry.append(mat)
	mat.set_shader_parameter(&"blight", _blight)
	return true


static func unregister_material(mat: ShaderMaterial) -> void:
	_registry.erase(mat)


static func registered_count() -> int:
	return _registry.size()


static func ensure_shipped_registered() -> void:
	if _shipped_loaded:
		return
	_shipped_loaded = true
	for mat_id: String in SHIPPED_MATERIALS:
		var path := MATERIAL_DIR + mat_id + ".tres"
		if ResourceLoader.exists(path):
			var mat := load(path) as ShaderMaterial
			register_material(mat)
