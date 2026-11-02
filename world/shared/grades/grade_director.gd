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
static var _dread_preset: GradePreset
var _from: GradePreset
var _to: GradePreset
var _t := 1.0
var _seconds := 0.0
## While a story swap is in effect, region grades don't override it.
var _story_hold := false
var _region_grade: StringName = &""
## Story mood overlay (EventBus.mood_requested): "dread" drops the light about
## two stops, drains colour and pools low fog (experience bar §1.5); "enchanted_sleep" fades to a soft dark blur (the ride
## north); "calm" eases whatever is on back to 0.
var mood: StringName = &"dread"
var mood_amount := 0.0
var _mood_target := 0.0
var _mood_rate := 1.0
## 0 at midday, 1 with the sun on the horizon: blends in the golden-hour sky.
var golden := 0.0
## Her true sight (L46, ch23): 0 under Tamlin's glamour, eases to 1 once
## `glamour_lifted` rises; every grade then reads richer and clearer.
var sight := 0.0
var _sight_target := 0.0
const SIGHT_SECONDS := 6.0


func _ready() -> void:
	EventBus.grade_swap_requested.connect(_on_grade_swap_requested)
	EventBus.flag_changed.connect(_on_flag_changed)
	_sight_target = 1.0 if WorldState.has_flag(GlamourLayer.FLAG) else 0.0
	sight = _sight_target
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
	if not is_equal_approx(sight, _sight_target):
		sight = move_toward(sight, _sight_target, delta / SIGHT_SECONDS)
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
	var p := with_mood(with_true_sight(base, sight), mood_amount, mood)
	snow_cover_now = p.snow_cover
	magic_now = p.magic
	RenderingServer.global_shader_parameter_set(&"snow_cover", p.snow_cover)
	RenderingServer.global_shader_parameter_set(&"magic_amount", p.magic)
	if environment == null or environment.environment == null:
		return
	var env := environment.environment
	var sky_mat := env.sky.sky_material as ProceduralSkyMaterial if env.sky != null else null
	if sky_mat != null:
		sky_mat.sky_top_color = p.sky_top.lerp(p.golden_sky_top, golden)
		sky_mat.sky_horizon_color = p.sky_horizon.lerp(p.golden_sky_horizon, golden)
		sky_mat.ground_horizon_color = p.ground_horizon
		sky_mat.ground_bottom_color = p.ground_bottom
	env.ambient_light_color = p.ambient_color
	env.ambient_light_energy = p.ambient_energy
	env.fog_light_color = p.fog_color
	env.fog_density = p.fog_density
	env.fog_sky_affect = p.fog_sky_affect
	env.fog_height = p.fog_height
	env.fog_height_density = p.fog_height_density
	env.fog_aerial_perspective = p.fog_aerial_perspective
	env.volumetric_fog_anisotropy = p.volumetric_anisotropy
	env.glow_hdr_threshold = p.glow_hdr_threshold
	env.volumetric_fog_density = p.volumetric_density
	env.volumetric_fog_albedo = p.volumetric_albedo
	env.volumetric_fog_ambient_inject = p.volumetric_ambient_inject
	env.tonemap_exposure = p.exposure
	env.adjustment_enabled = true
	env.adjustment_saturation = p.saturation
	env.adjustment_contrast = p.contrast
	env.adjustment_brightness = p.brightness
	env.adjustment_color_correction = p.lut
	env.glow_intensity = p.glow_intensity
	env.glow_bloom = p.glow_bloom
	if sun != null:
		sun.light_color = p.sun_color.lerp(p.golden_sun_color, golden)
		sun.light_volumetric_fog_energy = p.volumetric_light_energy


## How far a dread request moves the grade: eased out, so a scene asking for
## moderate dread (0.5-0.6) already lands most of the way (about 0.8) and
## bites like full dread does; 0 and 1 are unchanged.
static func dread_weight(dread: float) -> float:
	var d := clampf(dread, 0.0, 1.0)
	return 1.0 - (1.0 - d) * (1.0 - d)


## `p` with a story mood applied at `dread` (0..1) strength.
static func with_mood(p: GradePreset, dread: float, kind: StringName = &"dread") -> GradePreset:
	if dread <= 0.0:
		return p
	if kind == &"enchanted_sleep":
		return _sleepy(p, dread)
	# A grade that already is the horror look takes less (or none) of it.
	dread *= p.dread_headroom
	if dread <= 0.0:
		return p
	# §1.5: the pink world leaves. Blend toward the dread preset (horror
	# palette, ~2 stops down, saturation 0.4, dense low fog, no magic, no
	# lilac shadows); snow stays where it lies.
	if _dread_preset == null:
		_dread_preset = load_preset(&"dread")
	var cold := GradePreset.mix(p, _dread_preset, dread_weight(dread))
	cold.id = p.id
	cold.lut = p.lut
	cold.snow_cover = p.snow_cover
	return cold


## `p` as she sees it once the glamour on her senses is gone (canon ch23:
## "richer, clearer", a near-invisible rainbow on the brook, leaf edges
## shimmering): more colour and clarity, a little more bloom and warm light,
## and the world's magic shimmer turned up. Dread still drains it (applied after).
static func with_true_sight(p: GradePreset, amount: float) -> GradePreset:
	if amount <= 0.0:
		return p
	var s := GradePreset.mix(p, p, 0.0)
	s.id = p.id
	s.lut = p.lut
	s.saturation = p.saturation * (1.0 + 0.16 * amount)
	s.contrast = p.contrast * (1.0 + 0.05 * amount)
	s.exposure = p.exposure * (1.0 + 0.04 * amount)
	s.glow_intensity = p.glow_intensity + 0.12 * amount
	s.glow_bloom = p.glow_bloom + 0.03 * amount
	s.ambient_color = p.ambient_color.lerp(Color(1.0, 0.9, 0.86), 0.12 * amount)
	s.fog_density = p.fog_density * (1.0 - 0.25 * amount)
	s.magic = minf(1.0, p.magic + 0.25 * amount)
	return s


func _on_flag_changed(flag: String, _value: Variant) -> void:
	if flag == GlamourLayer.FLAG or flag == "":
		_sight_target = 1.0 if WorldState.has_flag(GlamourLayer.FLAG) else 0.0


static func _sleepy(p: GradePreset, amount: float) -> GradePreset:
	var s := GradePreset.mix(p, p, 0.0)
	s.lut = p.lut
	# A dreamy fade, not a dropout: about 1.3 stops down at full sleep, colour
	# drained and a soft bloom haze, so horse, rider and path still read.
	s.exposure = p.exposure * (1.0 - 0.6 * amount)
	s.saturation = p.saturation * (1.0 - 0.5 * amount)
	s.glow_intensity = p.glow_intensity + 0.9 * amount
	s.glow_bloom = p.glow_bloom + 0.18 * amount
	s.glow_hdr_threshold = lerpf(p.glow_hdr_threshold, 0.7, amount)
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
	var g := golden_amount(elevation)
	if absf(g - golden) > 0.01:
		golden = g
		apply(current)
	var energy := lerpf(current.sun_energy, current.golden_sun_energy, golden)
	sun.light_energy = energy * clampf(elevation * 3.0, 0.04, 1.0)


## Golden-hour weight for a sun elevation (sin of its angle): full at the
## horizon, gone by about 25° up, and fading out again once the sun is down.
static func golden_amount(elevation: float) -> float:
	return (1.0 - smoothstep(0.08, 0.42, elevation)) * smoothstep(-0.2, 0.0, elevation)


## Sun rises in the east at 06:00, highest at noon (tilted south), sets west.
static func sun_rotation(time_of_day: float) -> Vector3:
	var angle := (time_of_day - 0.25) * TAU
	return Vector3(-sin(angle) * deg_to_rad(62.0) - deg_to_rad(4.0), deg_to_rad(90.0) - angle, 0.0)
