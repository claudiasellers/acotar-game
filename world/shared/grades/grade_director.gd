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
## The snow_cover / magic globals as last applied (global shader params can't
## be read back outside the editor).
static var snow_cover_now := 1.0
static var magic_now := 0.0
var _from: GradePreset
var _to: GradePreset
var _t := 1.0
var _seconds := 0.0
## While a story swap is in effect, region grades don't override it.
var _story_hold := false
var _region_grade: StringName = &""
## Story mood overlay (EventBus.mood_requested): "dread" darkens, chills and
## thickens the fog; "enchanted_sleep" fades to a soft dark blur (the ride
## north); "calm" eases whatever is on back to 0.
var mood: StringName = &"dread"
var mood_amount := 0.0
var _mood_target := 0.0
var _mood_rate := 1.0


func _ready() -> void:
	EventBus.grade_swap_requested.connect(_on_grade_swap_requested)
	if EventBus.has_signal(&"mood_requested"):
		EventBus.connect(&"mood_requested", _on_mood_requested)
	current = load_preset(start_grade)
	_from = current
	_to = current
	apply(current)


func _process(delta: float) -> void:
	var dirty := false
	if _t < 1.0:
		_t = minf(1.0, _t + delta / maxf(_seconds, 0.001))
		var k := _t * _t * (3.0 - 2.0 * _t)
		current = GradePreset.mix(_from, _to, k)
		dirty = true
	if not is_equal_approx(mood_amount, _mood_target):
		mood_amount = move_toward(mood_amount, _mood_target, _mood_rate * delta)
		dirty = true
	if dirty:
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


func apply(base: GradePreset) -> void:
	var p := with_mood(base, mood_amount, mood)
	snow_cover_now = p.snow_cover
	magic_now = p.magic
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


## `p` with a story mood applied at `dread` (0..1) strength.
static func with_mood(p: GradePreset, dread: float, kind: StringName = &"dread") -> GradePreset:
	if dread <= 0.0:
		return p
	if kind == &"enchanted_sleep":
		return _sleepy(p, dread)
	var cold := GradePreset.new()
	cold.id = p.id
	for f in GradePreset._FLOATS:
		cold.set(f, p.get(f))
	for c in GradePreset._COLORS:
		cold.set(c, p.get(c))
	cold.lut = p.lut
	cold.saturation = p.saturation * (1.0 - 0.55 * dread)
	cold.exposure = p.exposure * (1.0 - 0.3 * dread)
	cold.contrast = p.contrast * (1.0 + 0.15 * dread)
	cold.fog_density = p.fog_density * (1.0 + 2.5 * dread)
	cold.volumetric_density = p.volumetric_density * (1.0 + 2.0 * dread)
	cold.glow_intensity = p.glow_intensity * (1.0 - 0.6 * dread)
	cold.magic = p.magic * (1.0 - dread)
	var chill := Color(0.42, 0.48, 0.62)
	cold.ambient_color = p.ambient_color.lerp(chill, 0.5 * dread)
	cold.fog_color = p.fog_color.lerp(chill, 0.6 * dread)
	cold.sun_color = p.sun_color.lerp(chill, 0.4 * dread)
	cold.sun_energy = p.sun_energy * (1.0 - 0.5 * dread)
	return cold


static func _sleepy(p: GradePreset, amount: float) -> GradePreset:
	var s := GradePreset.mix(p, p, 0.0)
	s.lut = p.lut
	s.exposure = p.exposure * (1.0 - 0.9 * amount)
	s.saturation = p.saturation * (1.0 - 0.4 * amount)
	s.glow_intensity = p.glow_intensity + 1.2 * amount
	s.glow_bloom = p.glow_bloom + 0.3 * amount
	s.fog_density = p.fog_density * (1.0 + 1.5 * amount)
	return s


func _on_mood_requested(requested: StringName, intensity: float, seconds: float) -> void:
	if requested == &"calm":
		_mood_target = 0.0
	else:
		if requested != mood and mood_amount > 0.0:
			mood_amount = 0.0
		mood = requested
		_mood_target = clampf(intensity, 0.0, 1.0)
	_mood_rate = absf(_mood_target - mood_amount) / maxf(seconds, 0.001)


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
