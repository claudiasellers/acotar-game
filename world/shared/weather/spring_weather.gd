## Spring Court weather you can see (T5): soft rain showers, morning mist and
## breezy days with gusts that lift a swirl of petals. Runs only while Feyre
## is in a Spring Court region; the human realm keeps WinterWeather and its
## visuals exactly as they are.
## - precipitation: rain streaks round the camera, the shared `ground_wetness`
##   shader global (0 dry .. 1 soaked, rises in a shower, dries slowly) and
##   ElementField.rain (wets what can burn, puts fires out);
## - wind: wind_ms() for the chemistry; gusts above GUST m/s burst petals;
## - mist: GradeDirector.set_weather_fog() (an offset, presets untouched).
## A Weather node in the scene (systems/elements) wins for precipitation and
## wind when there is one. States: spring_clear, spring_showers, spring_mist,
## spring_breeze, from EventBus.weather_requested or one per day.
class_name SpringWeather
extends Node3D

const GROUP := &"spring_weather"
const WETNESS_GLOBAL := &"ground_wetness"
## state: [precipitation 0-1, mist 0-1, base wind m/s]
const STATES := {
	&"spring_clear": [0.0, 0.0, 2.5],
	&"spring_showers": [0.65, 0.25, 4.0],
	&"spring_mist": [0.0, 1.0, 1.0],
	&"spring_breeze": [0.0, 0.0, 6.0],
}
## Day weights: mostly fair, the odd shower, misty mornings, a breezy day.
const DAY_WEIGHTS := {&"spring_clear": 5.0, &"spring_showers": 2.0, &"spring_mist": 2.0, &"spring_breeze": 1.5}
const GUST := 6.0
const GUST_COOLDOWN := 7.0
const WET_RISE := 1.0 / 45.0
const WET_DRY := 1.0 / 150.0
const RAIN_AMOUNT := 1400

var state: StringName = &"spring_clear"
## Eased values, 0..1 (wind in m/s).
var precipitation := 0.0
var mist := 0.0
var base_wind := 2.5
var wetness := 0.0
var active := false

var _target := Vector3(0.0, 0.0, 2.5)
var _ease_rate := 1.0 / 6.0
var _time := 0.0
var _gust_cooldown := 0.0
var _slow_tick := 0.0
var _rain: GPUParticles3D


func _ready() -> void:
	add_to_group(GROUP)
	top_level = true
	ensure_wetness_global()
	if EventBus.has_signal(&"weather_requested"):
		EventBus.weather_requested.connect(request)
	EventBus.day_started.connect(_on_day_started)
	_rain = _make_rain()
	add_child(_rain)


static func ensure_wetness_global() -> void:
	if not RenderingServer.global_shader_parameter_get_list().has(WETNESS_GLOBAL):
		RenderingServer.global_shader_parameter_add(WETNESS_GLOBAL, RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 0.0)


## Switches to a spring state over `seconds`. Ignores other realms' states.
func request(to_state: StringName, seconds: float = 6.0) -> void:
	if not STATES.has(to_state):
		return
	state = to_state
	var v: Array = STATES[to_state]
	_target = Vector3(v[0], v[1], v[2])
	_ease_rate = 1.0 / maxf(seconds, 0.001)


## Wind in m/s here and now (ElementField reads it): the day's breeze plus gusts.
func wind_ms() -> Vector3:
	var weather := Weather.find(get_tree())
	if weather:
		return weather.wind_at(global_position)
	var dir := _wind_dir()
	var gust := maxf(0.0, sin(_time * 0.31) * sin(_time * 0.17 + 1.1)) * base_wind * 0.8
	return dir * (base_wind + gust) if active else Vector3.ZERO


func _process(delta: float) -> void:
	_time += delta
	active = _in_spring()
	var goal := _target if active else Vector3(0.0, 0.0, base_wind)
	var weather := Weather.find(get_tree())
	if weather and active:
		goal.x = weather.precipitation if weather.precipitation_kind == &"rain" else 0.0
	precipitation = move_toward(precipitation, goal.x, _ease_rate * delta)
	mist = move_toward(mist, goal.y, _ease_rate * delta)
	base_wind = move_toward(base_wind, goal.z, _ease_rate * delta * 4.0)
	wetness = step_wetness(wetness, precipitation, delta)
	_update_rain()
	_gust_cooldown -= delta
	if active and _gust_cooldown <= 0.0 and wind_ms().length() >= GUST:
		_gust_cooldown = GUST_COOLDOWN
		petal_gust()
	_slow_tick -= delta
	if _slow_tick <= 0.0:
		_slow_tick = 0.25
		_apply_slow()


## The ground gets wet in rain and dries slowly after. Pure, for tests.
static func step_wetness(wet: float, precip: float, delta: float) -> float:
	if precip > 0.01:
		return move_toward(wet, clampf(precip * 1.4, 0.0, 1.0), WET_RISE * delta)
	return maxf(wet - WET_DRY * delta, 0.0)


## A swirl of petals carried on the gust, round the camera (R3).
func petal_gust() -> GPUParticles3D:
	var cam := get_viewport().get_camera_3d() if get_viewport() else null
	if cam == null:
		return null
	var dir := _wind_dir()
	var p := GPUParticles3D.new()
	p.one_shot = true
	p.amount = 48
	p.lifetime = 4.5
	p.explosiveness = 0.6
	p.draw_pass_1 = _petal_mesh()
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(4, 2, 4)
	m.direction = dir + Vector3.UP * 0.15
	m.spread = 25.0
	m.initial_velocity_min = 3.0
	m.initial_velocity_max = 6.0
	m.gravity = Vector3(0, -0.5, 0)
	m.angular_velocity_min = -180.0
	m.angular_velocity_max = 180.0
	m.turbulence_enabled = true
	m.turbulence_noise_strength = 1.2
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.8, 0.88))
	ramp.add_point(0.5, Color(1.0, 0.68, 0.8))
	ramp.set_color(1, Color(0.85, 0.78, 1.0, 0.0))
	var tex := GradientTexture1D.new()
	tex.gradient = ramp
	m.color_ramp = tex
	p.process_material = m
	p.visibility_aabb = AABB(Vector3(-20, -6, -20), Vector3(40, 14, 40))
	add_child(p)
	p.global_position = cam.global_position - dir * 6.0 + Vector3.UP * 1.0
	p.emitting = true
	p.finished.connect(p.queue_free)
	return p


func _apply_slow() -> void:
	RenderingServer.global_shader_parameter_set(WETNESS_GLOBAL, wetness)
	var field := ElementField.find(get_tree())
	if field:
		field.rain = precipitation if active else 0.0
	var grades := get_tree().get_first_node_in_group(&"world")
	var director := grades.get_node_or_null(^"GradeDirector") if grades else null
	if director and director.has_method(&"set_weather_fog"):
		director.call(&"set_weather_fog", mist * GradeDirector.MAX_WEATHER_FOG if active else 0.0)


func _update_rain() -> void:
	var cam := get_viewport().get_camera_3d() if get_viewport() else null
	var on := active and precipitation > 0.02 and cam != null
	_rain.emitting = on
	if not on:
		return
	_rain.amount_ratio = clampf(precipitation, 0.05, 1.0)
	_rain.global_position = cam.global_position + Vector3.UP * 12.0 + _wind_dir() * -2.0


func _in_spring() -> bool:
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	var streamer := Gameplay.autoload(&"WorldStreamer")
	if player == null or streamer == null:
		return false
	var def: RegionDef = streamer.region_at(player.global_position)
	return def != null and def.scene_path.contains("/spring_court/")


func _wind_dir() -> Vector3:
	var world := get_tree().get_first_node_in_group(&"world")
	var driver := world.get_node_or_null(^"WindDriver") as WindDriver if world else null
	var w := driver.current if driver else Vector3(1, 0, 0.3)
	w.y = 0.0
	return w.normalized() if w.length_squared() > 0.0001 else Vector3(1, 0, 0)


func _on_day_started(day: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(day * 7919 + 59)
	var total := 0.0
	for w: float in DAY_WEIGHTS.values():
		total += w
	var pick := rng.randf() * total
	for s: StringName in DAY_WEIGHTS:
		pick -= float(DAY_WEIGHTS[s])
		if pick <= 0.0:
			request(s, 20.0)
			return


func _make_rain() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "Rain"
	p.amount = RAIN_AMOUNT
	p.lifetime = 0.9
	p.emitting = false
	var streak := QuadMesh.new()
	streak.size = Vector2(0.018, 0.45)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.86, 0.9, 1.0, 0.32)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.roughness = 0.2
	streak.material = mat
	p.draw_pass_1 = streak
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(18, 1, 18)
	m.direction = Vector3.DOWN
	m.spread = 4.0
	m.initial_velocity_min = 14.0
	m.initial_velocity_max = 17.0
	m.gravity = Vector3(0, -9.8, 0)
	p.process_material = m
	p.visibility_aabb = AABB(Vector3(-20, -20, -20), Vector3(40, 24, 40))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


static var _petal: QuadMesh


static func _petal_mesh() -> QuadMesh:
	if _petal == null:
		_petal = QuadMesh.new()
		_petal.size = Vector2(0.07, 0.05)
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.vertex_color_use_as_albedo = true
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		mat.roughness = 0.6
		_petal.material = mat
	return _petal
