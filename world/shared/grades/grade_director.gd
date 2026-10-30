## Owns the World scene's look: WorldEnvironment, sky, sun and the shader
## globals. Blends between GradePresets on EventBus.grade_swap_requested (story
## controls the wall crossing) and on RegionGrade areas, and drives the sun from
## Clock.
class_name GradeDirector
extends Node

const PRESET_DIR := "res://world/shared/grades/"

@export var environment: WorldEnvironment
@export var sun: DirectionalLight3D
@export var start_grade: StringName = &"human_winter"
## Node whose position picks the RegionGrade (Feyre or the camera).
@export var focus: Node3D

var current: GradePreset
var _from: GradePreset
var _to: GradePreset
var _t := 1.0
var _seconds := 0.0
## While a story swap is in effect, region grades don't override it.
var _story_hold := false
var _region_grade: StringName = &""


func _ready() -> void:
	EventBus.grade_swap_requested.connect(_on_grade_swap_requested)
	current = load_preset(start_grade)
	_from = current
	_to = current
	apply(current)


func _process(delta: float) -> void:
	if _t < 1.0:
		_t = minf(1.0, _t + delta / maxf(_seconds, 0.001))
		var k := _t * _t * (3.0 - 2.0 * _t)
		current = GradePreset.mix(_from, _to, k)
		apply(current)
	_update_region_grade()
	_update_sun()


static func load_preset(id: StringName) -> GradePreset:
	var path := PRESET_DIR + String(id) + ".tres"
	if not ResourceLoader.exists(path):
		push_warning("GradeDirector: no preset '%s'" % id)
		return GradePreset.new()
	return load(path)


## Start a blend from whatever is showing now to `to_grade`.
func swap_to(to_grade: StringName, seconds: float) -> void:
	_from = current
	_to = load_preset(to_grade)
	_seconds = seconds
	_t = 0.0 if seconds > 0.0 else 1.0
	if seconds <= 0.0:
		current = _to
		apply(current)


func is_blending() -> bool:
	return _t < 1.0


func target_id() -> StringName:
	return _to.id


func apply(p: GradePreset) -> void:
	RenderingServer.global_shader_parameter_set(&"snow_cover", p.snow_cover)
	RenderingServer.global_shader_parameter_set(&"magic_amount", p.magic)
	if environment == null or environment.environment == null:
		return
	var env := environment.environment
	var sky_mat := env.sky.sky_material as ProceduralSkyMaterial if env.sky != null else null
	if sky_mat != null:
		sky_mat.sky_top_color = p.sky_top
		sky_mat.sky_horizon_color = p.sky_horizon
		sky_mat.ground_horizon_color = p.ground_horizon
		sky_mat.ground_bottom_color = p.ground_bottom
	env.ambient_light_color = p.ambient_color
	env.ambient_light_energy = p.ambient_energy
	env.fog_light_color = p.fog_color
	env.fog_density = p.fog_density
	env.volumetric_fog_density = p.volumetric_density
	env.volumetric_fog_albedo = p.volumetric_albedo
	env.tonemap_exposure = p.exposure
	env.adjustment_enabled = true
	env.adjustment_saturation = p.saturation
	env.adjustment_contrast = p.contrast
	env.adjustment_brightness = p.brightness
	env.adjustment_color_correction = p.lut
	env.glow_intensity = p.glow_intensity
	env.glow_bloom = p.glow_bloom
	if sun != null:
		sun.light_color = p.sun_color


func _on_grade_swap_requested(to_grade: StringName, seconds: float) -> void:
	_story_hold = true
	_region_grade = &""
	swap_to(to_grade, seconds)


func _update_region_grade() -> void:
	if focus == null or _story_hold or is_blending():
		return
	for node in get_tree().get_nodes_in_group(RegionGrade.GROUP):
		var rg := node as RegionGrade
		if rg.contains(focus.global_position):
			if rg.grade != _region_grade:
				_region_grade = rg.grade
				swap_to(rg.grade, rg.blend_seconds)
			return


## Story swaps hold until the story (or a test) releases them.
func release_story_hold() -> void:
	_story_hold = false


func _update_sun() -> void:
	if sun == null:
		return
	sun.rotation = sun_rotation(Clock.time_of_day)
	var elevation := sin((Clock.time_of_day - 0.25) * TAU)
	sun.light_energy = current.sun_energy * clampf(elevation * 3.0, 0.04, 1.0)


## Sun rises in the east at 06:00, highest at noon (tilted south), sets west.
static func sun_rotation(time_of_day: float) -> Vector3:
	var angle := (time_of_day - 0.25) * TAU
	return Vector3(-sin(angle) * deg_to_rad(62.0) - deg_to_rad(4.0), deg_to_rad(90.0) - angle, 0.0)
