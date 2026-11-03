## Probe for soft bounce light (render program T3a, L60). Renders one small
## spring-lit set twice, as main had it (sky share 0.6, no ground bounce, old
## SSAO) and with T3a (0.7, bounce 0.35, SSAO 1.0/1.2, SSIL by profile), and
## prints RGB at named points:
##   shaded_cliff  the cliff face turned from the sun (ground bounce, sideways)
##   under_canopy  the underside of a slab overhead (ground bounce, straight up)
##   shaded_top    an upward face in the cliff's shadow (sky tint)
##   lit_top       an upward face in full sun (the lit band: must not change)
##   corner/wall   an inside corner and its wall centre, both in shade
## Needs a renderer (xvfb + lavapipe in the cloud, the GPU on a Mac):
##   xvfb-run -a tools/mq/godot.sh --rendering-driver vulkan res://tools/lighting/bounce_probe.tscn
## (godot.sh passes --headless; for this probe run the engine without it.)
extends Node3D

const GRADE := "res://world/shared/grades/spring.tres"
const SKY_SHADER := "res://world/shared/grades/painted_sky.gdshader"
const GROUND := Color(0.523, 0.548, 0.545)
const BLUSH := Color(0.92, 0.72, 0.76)
const POINTS := {
	&"shaded_cliff": Vector3(0.0, 3.0, 2.02),
	&"under_canopy": Vector3(7.0, 3.73, 1.6),
	&"shaded_top": Vector3(0.0, 0.81, 4.0),
	&"lit_top": Vector3(-7.0, 1.01, 0.5),
	&"corner": Vector3(16.94, 1.5, 0.06),
	&"wall": Vector3(14.5, 1.5, 0.02),
}

var _env: Environment
var _cam: Camera3D
var _mats: Array[ShaderMaterial] = []


func _ready() -> void:
	_build()
	for i in 12:
		await get_tree().process_frame
	var before := await _shoot(0.6, 0.0, 1.5, 1.5, false)
	var after := await _shoot(0.7, 0.35, BounceLight.SSAO_RADIUS, BounceLight.SSAO_INTENSITY, true)
	for key: StringName in POINTS:
		var a: Color = before[key]
		var b: Color = after[key]
		print("PROBE %-13s before %s after %s  luma %+.1f%%" % [key, _fmt(a), _fmt(b), (_luma(b) / maxf(_luma(a), 1e-4) - 1.0) * 100.0])
	var g := load(GRADE) as GradePreset
	# The ground's colour as light leaves it: its albedo under the sun.
	var ground_light := Color(GROUND.r * g.sun_color.r, GROUND.g * g.sun_color.g, GROUND.b * g.sun_color.b)
	print("PROBE hue shift toward sky on shaded_top: %+.4f" % _toward(before[&"shaded_top"], after[&"shaded_top"], g.sky_top))
	print("PROBE hue shift toward ground on under_canopy: %+.4f" % _toward(before[&"under_canopy"], after[&"under_canopy"], ground_light))
	print("PROBE hue shift toward ground on shaded_cliff: %+.4f" % _toward(before[&"shaded_cliff"], after[&"shaded_cliff"], ground_light))
	print("PROBE corner darker than wall centre: %.1f%%" % ((1.0 - _luma(after[&"corner"]) / maxf(_luma(after[&"wall"]), 1e-4)) * 100.0))
	print("PROBE lit_top delta: %.2f%%" % (absf(_luma(after[&"lit_top"]) / maxf(_luma(before[&"lit_top"]), 1e-4) - 1.0) * 100.0))
	get_tree().quit()


func _shoot(sky_share: float, bounce: float, ssao_radius: float, ssao_intensity: float, ssil: bool) -> Dictionary:
	_env.ambient_light_sky_contribution = sky_share
	_env.ssao_radius = ssao_radius
	_env.ssao_intensity = ssao_intensity
	_env.ssil_enabled = ssil
	for m in _mats:
		m.set_shader_parameter(&"ground_bounce", bounce)
	for i in 8:
		await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var dump := OS.get_environment("BOUNCE_PROBE_PNG")
	if not dump.is_empty():
		img.save_png(dump % ("t3a" if ssil else "main"))
	var out := {}
	for key: StringName in POINTS:
		# The window may render smaller than the 1080p logical viewport.
		var px := _cam.unproject_position(POINTS[key]) * Vector2(img.get_size()) / get_viewport().get_visible_rect().size
		out[key] = _sample(img, Vector2i(px))
	return out


func _build() -> void:
	var g := load(GRADE) as GradePreset
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load(SKY_SHADER)
	sky_mat.set_shader_parameter(&"sky_top_color", g.sky_top)
	sky_mat.set_shader_parameter(&"sky_horizon_color", g.sky_horizon)
	sky_mat.set_shader_parameter(&"ground_horizon_color", g.ground_horizon)
	sky_mat.set_shader_parameter(&"ground_bottom_color", g.ground_bottom)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	_env = Environment.new()
	_env.background_mode = Environment.BG_SKY
	_env.sky = sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_env.ambient_light_color = g.ambient_color
	_env.ambient_light_energy = g.ambient_energy
	_env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	_env.tonemap_mode = Environment.TONE_MAPPER_ACES
	_env.ssao_enabled = true
	var we := WorldEnvironment.new()
	we.environment = _env
	add_child(we)
	RenderingServer.environment_set_ssil_quality(RenderingServer.ENV_SSIL_QUALITY_LOW, true, 0.5, 4, 50.0, 300.0)

	var sun := DirectionalLight3D.new()
	sun.light_color = g.sun_color
	sun.light_energy = g.sun_energy
	sun.shadow_enabled = true
	# 35 degrees up, from behind the cliff (-z), a little to the left.
	sun.rotation_degrees = Vector3(-35.0, 165.0, 0.0)
	add_child(sun)

	_box(Vector3(60.0, 0.2, 60.0), Vector3(0.0, -0.1, 0.0), GROUND)       # ground
	_box(Vector3(4.0, 6.0, 4.0), Vector3(0.0, 3.0, 0.0), BLUSH)           # cliff
	_box(Vector3(2.0, 0.8, 2.0), Vector3(0.0, 0.4, 4.0), BLUSH)           # low block in its shadow
	_box(Vector3(0.3, 3.75, 0.3), Vector3(7.0, 1.875, 0.0), BLUSH)        # canopy post
	_box(Vector3(4.0, 0.5, 4.0), Vector3(7.0, 4.0, 0.0), BLUSH)           # canopy
	_box(Vector3(3.0, 1.0, 3.0), Vector3(-7.0, 0.5, 0.0), BLUSH)          # sunlit block
	_box(Vector3(4.0, 3.0, 0.1), Vector3(15.0, 1.5, -0.05), BLUSH)        # corner: back wall
	_box(Vector3(0.1, 3.0, 4.0), Vector3(17.05, 1.5, 2.0), BLUSH)         # corner: side wall

	_cam = Camera3D.new()
	_cam.fov = 70.0
	add_child(_cam)
	_cam.look_at_from_position(Vector3(4.0, 2.2, 16.0), Vector3(4.0, 2.0, 0.0))


func _box(size: Vector3, at: Vector3, color: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := CandyMaterial.new()
	mat.albedo_color = color
	mat.roughness = 0.8
	_mats.append(mat)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = at
	add_child(mi)


## Mean of a 5x5 block, so one noisy pixel doesn't decide a check.
static func _sample(img: Image, at: Vector2i) -> Color:
	var s := Vector3.ZERO
	var n := 0
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var p := at + Vector2i(dx, dy)
			if p.x < 0 or p.y < 0 or p.x >= img.get_width() or p.y >= img.get_height():
				continue
			var c := img.get_pixelv(p)
			s += Vector3(c.r, c.g, c.b)
			n += 1
	s /= maxf(n, 1)
	return Color(s.x, s.y, s.z)


static func _luma(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b


## How far the change a -> b leans toward `target`'s hue: the change in chroma
## (colour minus its grey) projected on the target's chroma direction.
static func _toward(a: Color, b: Color, target: Color) -> float:
	var ca := Vector3(a.r, a.g, a.b) - Vector3.ONE * _luma(a)
	var cb := Vector3(b.r, b.g, b.b) - Vector3.ONE * _luma(b)
	var ct := (Vector3(target.r, target.g, target.b) - Vector3.ONE * _luma(target)).normalized()
	return (cb - ca).dot(ct)


static func _fmt(c: Color) -> String:
	return "(%.3f, %.3f, %.3f)" % [c.r, c.g, c.b]
