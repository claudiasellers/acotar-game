## Owns the World scene's look: WorldEnvironment, sky, sun, glow, the
## screen-space bounce light and the shader globals. Blends between GradePresets
## on EventBus.grade_swap_requested (story controls the wall crossing) and on
## RegionGrade areas, and drives the sun from Clock. Nothing else writes the
## game's environment (tests/unit/world/test_one_lighting_authority.gd).
class_name GradeDirector
extends Node

const PRESET_DIR := "res://world/shared/grades/"
const WORLD_SCENE := "res://world/shared/world/world.tscn"

@export var environment: WorldEnvironment
@export var sun: DirectionalLight3D
@export var start_grade: StringName = &"human_winter"
## Node whose position picks the RegionGrade (Feyre or the camera).
@export var focus: Node3D

var current: GradePreset
## Weather mist (T5, SpringWeather): added to the preset's volumetric fog
## density, 0 by default, never above MAX_WEATHER_FOG. Presets stay untouched.
const MAX_WEATHER_FOG := 0.04
var weather_fog := 0.0
## The snow_cover / magic globals as last applied (global shader params can't
## be read back outside the editor).
static var snow_cover_now := 1.0
static var magic_now := 0.0
## Night looks other grades name (GradePreset.night_look) by id, loaded once.
static var _named_looks: Dictionary = {}
var _from: GradePreset
var _to: GradePreset
var _t := 1.0
var _seconds := 0.0
## The one lighting authority (owner, 2026-11-26: one working version, no
## fallbacks). What she sees is decided here, in this order:
## 1. An indoor RegionGrade she is in (the manor rooms) always wins.
## 2. Otherwise the newest story grade still held (EventBus.grade_swap_requested
##    by a source; it lasts until that source sends &"" or leaves the tree).
## 3. Otherwise the highest-priority RegionGrade she is in.
## The mood is the strongest request still held, one per source (until it
## sends calm or leaves the tree), announced on EventBus.mood_changed for
## sound, the HUD and her vitals. Fear never darkens the screen (owner,
## 2026-11-26); only enchanted_sleep has a look.
## Story grades by source id: [source WeakRef, grade], oldest first.
var _holds: Array = []
var _shown: StringName = &""
var _region: RegionGrade
## True while the winning area is an indoor one.
var indoors := false
## Mood requests by source id: [mood, intensity].
var _moods: Dictionary = {}
## The mood in force and its strength, as last announced.
var mood: StringName = &"calm"
var mood_strength := 0.0
## Enchanted sleep (the carriage farewell, the solstice night): a soft, foggy
## fade, eased toward the strongest sleep request.
var sleep_amount := 0.0
var _sleep_target := 0.0
var _sleep_rate := 1.0
## 0 at midday, 1 with the sun on the horizon: blends in the golden-hour sky.
var golden := 0.0
## 0 while the sun is up, 1 once it is below the horizon. Volumetric fog is lit
## only by lights unless it takes the ambient, so at night the sun-lit fog of
## every grade turned into an opaque black wall past ~30 m (the mill void).
var night := 0.0
## How much ambient the volumetric fog takes at full night, at least.
const NIGHT_FOG_INJECT := 0.4
## Her true sight (L46, ch23): 0 under Tamlin's glamour, eases to 1 once
## `glamour_lifted` rises; every grade then reads richer and clearer.
var sight := 0.0
var _sight_target := 0.0
const SIGHT_SECONDS := 6.0
## The one glow in the game (owner, 2026-11-25: "normal", no glow over
## everything). Only real light sources bloom, faintly: flames, lamps,
## faelights, eyes, sparkles (emission well above white). No grade sets glow,
## so the look never hazes in a region, a mood or at night. A sunlit pastel
## peaks near 2.0 raw (sun 1.8 x albedo cap 0.88 + ambient), so it stays crisp
## under THRESHOLD; LUMINANCE_CAP keeps a lamp's hot specular on a glossy table
## from out-blooming the flame itself (additive at 0.6 haloed every highlight).
const GLOW_THRESHOLD := 2.6
const GLOW_INTENSITY := 0.35
const GLOW_LUMINANCE_CAP := 3.5
## Tight halos (levels 2-4), no wide level-5+ haze.
const GLOW_LEVELS := [0.0, 0.6, 1.0, 0.4, 0.0, 0.0, 0.0]
## Soft bounce light (render program T3a, L60): half-resolution SSAO on every
## graphics profile, low-quality half-resolution SSIL (screen-space colour
## bleed) only where it is affordable. The profile is
## GameSettings.shadow_profile_name() ("high", or "mac" on Apple silicon).
## Ambient and reflections come from the sky (world.tscn); the light the lit
## ground throws back up is candy_lit's ground_bounce term. For the Mac perf
## pass, BOUNCE_SSIL=0|1 forces SSIL and BOUNCE_SDFGI=1 turns SDFGI on
## (GradePreset has no GI switch, so no grade turns it off again).
const SSIL_PROFILES: Array[StringName] = [&"high"]
const SSAO_RADIUS := 1.0
const SSAO_INTENSITY := 1.2
const SSIL_RADIUS := 5.0
const SSIL_INTENSITY := 1.0


func _ready() -> void:
	EventBus.grade_swap_requested.connect(_on_grade_swap_requested)
	EventBus.flag_changed.connect(_on_flag_changed)
	_sight_target = 1.0 if WorldState.has_flag(GlamourLayer.FLAG) else 0.0
	sight = _sight_target
	EventBus.mood_requested.connect(_on_mood_requested)
	current = load_preset(start_grade)
	_shown = start_grade
	_from = current
	_to = current
	GameSettings.shadow_profile_changed.connect(func(_profile: String) -> void: _apply_bounce())
	if environment and environment.environment:
		light_source_glow(environment.environment)
		_apply_bounce()
	apply(current)


func _apply_bounce() -> void:
	if environment == null or environment.environment == null:
		return
	var env := environment.environment
	screen_space_bounce(env, StringName(GameSettings.shadow_profile_name()))
	var force := OS.get_environment("BOUNCE_SSIL")
	if force in ["0", "1"]:
		env.ssil_enabled = force == "1"
	if OS.get_environment("BOUNCE_SDFGI") == "1":
		env.sdfgi_enabled = true


static func ssil_for_profile(profile: StringName) -> bool:
	return profile in SSIL_PROFILES


## Sets `env` to the game's bounce light for a graphics `profile`.
static func screen_space_bounce(env: Environment, profile: StringName) -> void:
	env.ssao_enabled = true
	env.ssao_radius = SSAO_RADIUS
	env.ssao_intensity = SSAO_INTENSITY
	env.ssil_enabled = ssil_for_profile(profile)
	env.ssil_radius = SSIL_RADIUS
	env.ssil_intensity = SSIL_INTENSITY
	# Quality is global to the renderer; these are Godot's project defaults
	# apart from the quality level and half size.
	RenderingServer.environment_set_ssao_quality(RenderingServer.ENV_SSAO_QUALITY_MEDIUM, true, 0.5, 2, 50.0, 300.0)
	RenderingServer.environment_set_ssil_quality(RenderingServer.ENV_SSIL_QUALITY_LOW, true, 0.5, 4, 50.0, 300.0)


## Lights a scene that has no World (a region played or shot on its own) the
## way the game does: the World's own environment and sun, under a director on
## `grade`. Returns the director; set its focus to let RegionGrades pick.
static func light(root: Node3D, grade: StringName = &"manor") -> GradeDirector:
	var world := (load(WORLD_SCENE) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_DISABLED)
	var env := world.get_node("WorldEnvironment") as WorldEnvironment
	var sun := world.get_node("Sun") as DirectionalLight3D
	world.remove_child(env)
	world.remove_child(sun)
	world.free()
	root.add_child(env)
	root.add_child(sun)
	var director := GradeDirector.new()
	director.name = "GradeDirector"
	director.environment = env
	director.sun = sun
	director.start_grade = grade
	root.add_child(director)
	return director


## Sets `env` to the game's light-source-only glow.
static func light_source_glow(env: Environment) -> void:
	env.glow_enabled = true
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.glow_normalized = false
	env.glow_intensity = GLOW_INTENSITY
	env.glow_strength = 1.0
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = GLOW_THRESHOLD
	env.glow_hdr_scale = 2.0
	env.glow_hdr_luminance_cap = GLOW_LUMINANCE_CAP
	for i in GLOW_LEVELS.size():
		env.set_glow_level(i, GLOW_LEVELS[i])


func _process(delta: float) -> void:
	var dirty := false
	if _t < 1.0:
		_t = minf(1.0, _t + delta / maxf(_seconds, 0.001))
		var k := _t * _t * (3.0 - 2.0 * _t)
		current = GradePreset.mix(_from, _to, k)
		dirty = true
	if not is_equal_approx(sleep_amount, _sleep_target):
		sleep_amount = move_toward(sleep_amount, _sleep_target, _sleep_rate * delta)
		dirty = true
	if not is_equal_approx(sight, _sight_target):
		sight = move_toward(sight, _sight_target, delta / SIGHT_SECONDS)
		dirty = true
	if dirty:
		apply(current)
	_update_region_grade()
	_update_sun()


## Mist from the weather, 0..MAX_WEATHER_FOG on top of the grade's own fog.
func set_weather_fog(amount: float) -> void:
	var clamped := clampf(amount, 0.0, MAX_WEATHER_FOG)
	if is_equal_approx(clamped, weather_fog):
		return
	weather_fog = clamped
	if current:
		apply(current)


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
	var p := with_sleep(with_true_sight(with_night(base, night), sight), sleep_amount)
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
	# The World's painted sky (painted_sky.gdshader): same gradient, plus clouds.
	var painted := env.sky.sky_material as ShaderMaterial if env.sky != null else null
	if painted != null:
		painted.set_shader_parameter(&"sky_top_color", p.sky_top.lerp(p.golden_sky_top, golden))
		painted.set_shader_parameter(&"sky_horizon_color", p.sky_horizon.lerp(p.golden_sky_horizon, golden))
		painted.set_shader_parameter(&"ground_horizon_color", p.ground_horizon)
		painted.set_shader_parameter(&"ground_bottom_color", p.ground_bottom)
		painted.set_shader_parameter(&"cloud_cover", p.cloud_cover)
		painted.set_shader_parameter(&"cloud_color", p.cloud_color)
		painted.set_shader_parameter(&"cloud_shade", p.cloud_shade)
	env.ambient_light_color = p.ambient_color
	env.ambient_light_energy = p.ambient_energy
	env.ambient_light_sky_contribution = p.ambient_sky_contribution
	env.tonemap_mode = p.tonemap_mode
	env.fog_light_color = p.fog_color
	env.fog_density = p.fog_density
	env.fog_sky_affect = p.fog_sky_affect
	env.fog_height = p.fog_height
	env.fog_height_density = p.fog_height_density
	env.fog_aerial_perspective = p.fog_aerial_perspective
	env.volumetric_fog_anisotropy = p.volumetric_anisotropy
	env.volumetric_fog_density = p.volumetric_density + weather_fog
	env.volumetric_fog_albedo = p.volumetric_albedo
	env.volumetric_fog_ambient_inject = fog_ambient_inject(p.volumetric_ambient_inject, night)
	env.tonemap_exposure = p.exposure
	env.adjustment_enabled = true
	env.adjustment_saturation = p.saturation
	env.adjustment_contrast = p.contrast
	env.adjustment_brightness = p.brightness
	env.adjustment_color_correction = p.lut
	if sun != null:
		sun.light_color = p.sun_color.lerp(p.golden_sun_color, golden)
		sun.light_volumetric_fog_energy = p.volumetric_light_energy


## `p` as the sun goes down: blended toward its night look (GradePreset.
## night_look) by `night_weight`; unchanged for grades without one.
static func with_night(p: GradePreset, night_weight: float) -> GradePreset:
	if p.night_look == &"" or night_weight <= 0.0:
		return p
	if not _named_looks.has(p.night_look):
		_named_looks[p.night_look] = load_preset(p.night_look)
	var dark := GradePreset.mix(p, _named_looks[p.night_look], clampf(night_weight, 0.0, 1.0))
	dark.id = p.id
	dark.lut = p.lut
	dark.tonemap_mode = p.tonemap_mode
	dark.night_look = p.night_look
	return dark


## `p` as she sees it once the glamour on her senses is gone (canon ch23:
## "richer, clearer", a near-invisible rainbow on the brook, leaf edges
## shimmering): more colour and clarity, a little more warm light,
## and the world's magic shimmer turned up.
static func with_true_sight(p: GradePreset, amount: float) -> GradePreset:
	if amount <= 0.0:
		return p
	var s := GradePreset.mix(p, p, 0.0)
	s.id = p.id
	s.lut = p.lut
	s.saturation = p.saturation * (1.0 + 0.16 * amount)
	s.contrast = p.contrast * (1.0 + 0.05 * amount)
	s.exposure = p.exposure * (1.0 + 0.04 * amount)
	s.ambient_color = p.ambient_color.lerp(Color(1.0, 0.9, 0.86), 0.12 * amount)
	s.fog_density = p.fog_density * (1.0 - 0.25 * amount)
	s.magic = minf(1.0, p.magic + 0.25 * amount)
	return s


func _on_flag_changed(flag: String, _value: Variant) -> void:
	if flag == GlamourLayer.FLAG or flag == "":
		_sight_target = 1.0 if WorldState.has_flag(GlamourLayer.FLAG) else 0.0


## `p` as she drifts into enchanted sleep, `amount` 0..1.
static func with_sleep(p: GradePreset, amount: float) -> GradePreset:
	if amount <= 0.0:
		return p
	var s := GradePreset.mix(p, p, 0.0)
	s.lut = p.lut
	# A dreamy fade, not a dropout: about 1.3 stops down at full sleep, colour
	# drained and a thicker fog, so horse, rider and path still read.
	s.exposure = p.exposure * (1.0 - 0.6 * amount)
	s.saturation = p.saturation * (1.0 - 0.5 * amount)
	s.fog_density = p.fog_density * (1.0 + 1.5 * amount)
	return s


func _on_mood_requested(source: Object, requested: StringName, intensity: float, seconds: float) -> void:
	if source == null and requested == &"calm":
		_moods.clear()   # a load or a reset: every request ends
	else:
		var key := source.get_instance_id() if source != null else 0
		if requested == &"calm" or intensity <= 0.0:
			_moods.erase(key)
		else:
			_moods[key] = [requested, clampf(intensity, 0.0, 1.0)]
			# A scene that ends without calm takes its fear with it.
			var drop := _drop_mood.bind(key)
			if source is Node and not (source as Node).tree_exiting.is_connected(drop):
				(source as Node).tree_exiting.connect(drop, CONNECT_ONE_SHOT)
	_resolve_mood(seconds)


func _drop_mood(key: int) -> void:
	if _moods.erase(key):
		_resolve_mood(2.0)


## The strongest request is the mood; the strongest sleep request is the fade.
func _resolve_mood(seconds: float) -> void:
	var best_mood := &"calm"
	var best := 0.0
	var sleep := 0.0
	for key: int in _moods:
		var r: Array = _moods[key]
		if float(r[1]) > best:
			best = r[1]
			best_mood = r[0]
		if r[0] == &"enchanted_sleep":
			sleep = maxf(sleep, r[1])
	_sleep_target = sleep
	_sleep_rate = absf(_sleep_target - sleep_amount) / maxf(seconds, 0.001)
	if best_mood == mood and is_equal_approx(best, mood_strength):
		return
	mood = best_mood
	mood_strength = best
	EventBus.mood_changed.emit(mood, mood_strength, seconds)


## A story grade from `source`, held until the source sends &"" or leaves the
## tree. Indoors the rooms still win.
## A null source's &"" ends every hold (a load or a reset).
func _on_grade_swap_requested(source: Object, to_grade: StringName, seconds: float) -> void:
	if source == null:
		_holds.clear()
		_retarget(seconds)
		return
	_drop_hold(source)
	if to_grade != &"":
		_holds.append([weakref(source), to_grade])
		var left := _on_hold_source_left.bind(source)
		if source is Node and not (source as Node).tree_exiting.is_connected(left):
			(source as Node).tree_exiting.connect(left, CONNECT_ONE_SHOT)
	_retarget(seconds)


func _on_hold_source_left(source: Object) -> void:
	_drop_hold(source)
	_retarget(2.0)


func _drop_hold(source: Object) -> void:
	for i in range(_holds.size() - 1, -1, -1):
		var held: Object = (_holds[i][0] as WeakRef).get_ref()
		if held == null or held == source:
			_holds.remove_at(i)


func _update_region_grade() -> void:
	if focus == null or is_blending():
		return
	_retarget(-1.0)


## Picks what she should see now (see the order at the top) and blends to it.
## seconds < 0 uses the areas' own blend times.
func _retarget(seconds: float) -> void:
	_drop_hold(null)
	var rg: RegionGrade = null
	if focus != null:
		for node in get_tree().get_nodes_in_group(RegionGrade.GROUP):
			var here := node as RegionGrade
			if (rg == null or here.priority > rg.priority) and here.contains(focus.global_position):
				rg = here
	indoors = rg != null and rg.indoor
	var want: StringName = _shown
	var blend := seconds
	if indoors or (_holds.is_empty() and rg != null):
		want = rg.grade
		if blend < 0.0:
			var leaving := _region.leave_seconds if is_instance_valid(_region) else 0.0
			blend = leaving if leaving > 0.0 else rg.blend_seconds
		_region = rg
	elif not _holds.is_empty():
		want = _holds.back()[1]
		_region = null
	if want != _shown and want != &"":
		_shown = want
		swap_to(want, maxf(blend, 0.0))


func _update_sun() -> void:
	if sun == null:
		return
	sun.rotation = sun_rotation(Clock.time_of_day)
	var elevation := sin((Clock.time_of_day - 0.25) * TAU)
	var g := golden_amount(elevation)
	var n := night_amount(elevation)
	if absf(g - golden) > 0.01 or absf(n - night) > 0.01:
		golden = g
		night = n
		apply(current)
	var energy := lerpf(current.sun_energy, current.golden_sun_energy, golden)
	sun.light_energy = energy * clampf(elevation * 3.0, 0.04, 1.0)


## Golden-hour weight for a sun elevation (sin of its angle): full at the
## horizon, gone by about 25° up, and fading out again once the sun is down.
static func golden_amount(elevation: float) -> float:
	return (1.0 - smoothstep(0.08, 0.42, elevation)) * smoothstep(-0.2, 0.0, elevation)


## Night weight for a sun elevation: 0 in daylight, 1 once the sun is down.
static func night_amount(elevation: float) -> float:
	return 1.0 - smoothstep(-0.12, 0.1, elevation)


## The volumetric fog's ambient take: the grade's own by day, and at night at
## least NIGHT_FOG_INJECT, so the fog glows with the night ambient instead of
## going black with the sun.
static func fog_ambient_inject(grade_inject: float, night_weight: float) -> float:
	return lerpf(grade_inject, maxf(grade_inject, NIGHT_FOG_INJECT), clampf(night_weight, 0.0, 1.0))


## Sun rises in the east at 06:00, highest at noon (tilted south), sets west.
static func sun_rotation(time_of_day: float) -> Vector3:
	var angle := (time_of_day - 0.25) * TAU
	return Vector3(-sin(angle) * deg_to_rad(62.0) - deg_to_rad(4.0), deg_to_rad(90.0) - angle, 0.0)
