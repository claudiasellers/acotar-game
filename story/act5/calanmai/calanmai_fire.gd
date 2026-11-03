## A fire that reads as fire up close (L45-6): layered flame cards licking up
## from an ember bed, a few drifting sparks, a thin smoke column and a warm,
## flickering light. The flame is capped per card so a camera at 2 m sees an
## orange-yellow core, not a white blot.
## CalanmaiFire.campfire(): the three's fire in the cave, on its own stone ring
## and logs (art/calanmai/calanmai_campfire.glb). CalanmaiFire.bonfire(): the
## flames for a Calanmai pyre, whose wood is CalanmaiNight's pyre model.
class_name CalanmaiFire
extends Node3D

const FLAME_SHADER := preload("res://story/act5/calanmai/fx/calanmai_flame.gdshader")
const SMOKE_SHADER := preload("res://story/act5/calanmai/fx/calanmai_smoke.gdshader")
const CAMPFIRE_MODEL := &"calanmai_campfire"

## Flame height in metres for size 1 (a campfire's tallest tongue).
const TONGUE := 1.1
## [x, z, width, height, gain] per card, x/z/width/height in size units. The
## first card is the heart; the rest lean out round it and lick lower.
const CARDS := [
	[0.0, 0.0, 0.62, 1.0, 0.62],
	[-0.13, 0.06, 0.42, 0.78, 0.42],
	[0.14, -0.05, 0.40, 0.72, 0.42],
	[0.05, 0.12, 0.30, 0.55, 0.36],
	[-0.06, -0.12, 0.34, 0.5, 0.34],
]

## 1 = a campfire; the pyres burn at about 3.
@export var size: float = 1.0
@export var with_logs: bool = true
## A pyre's flames climb higher than they spread.
@export var height_scale: float = 1.25
@export var light_energy: float = 4.2
@export var light_range: float = 14.0
@export var light_shadows: bool = true

var light: OmniLight3D
var _cards: Array[MeshInstance3D] = []
var _flicker: Tween


static func campfire() -> CalanmaiFire:
	var f := CalanmaiFire.new()
	f.name = "Campfire"
	return f


## A pyre's flames: wider and taller, more tongues, no stone ring of its own.
static func bonfire(scale_m: float = 3.0) -> CalanmaiFire:
	var f := CalanmaiFire.new()
	f.name = "Bonfire"
	f.size = scale_m
	f.with_logs = false
	f.height_scale = 1.8
	f.light_energy = 5.5
	f.light_range = 28.0
	f.light_shadows = false
	return f


func _ready() -> void:
	if with_logs:
		var logs := CalanmaiKit.prop(CAMPFIRE_MODEL)
		if logs:
			add_child(logs)
	_build_flames()
	_build_embers()
	_build_smoke()
	_build_light()


func _build_flames() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(name) ^ int(size * 100.0)
	var rows: Array = CARDS.duplicate()
	if size > 1.5:
		# A pyre burns as a crown of fires round its cone, not one big tongue.
		for k in 8:
			var a := TAU * k / 8.0 + rng.randf_range(-0.2, 0.2)
			rows.append([cos(a) * 0.4, sin(a) * 0.4, 0.34, rng.randf_range(0.45, 0.8), 0.45])
	var base_y := 0.06 if with_logs else 0.25 * size
	for i in rows.size():
		var r: Array = rows[i]
		var quad := QuadMesh.new()
		var w := float(r[2]) * TONGUE * size
		var h := float(r[3]) * TONGUE * size * height_scale
		quad.size = Vector2(w, h)
		quad.center_offset = Vector3(0.0, h * 0.5, 0.0)
		var mat := ShaderMaterial.new()
		mat.shader = FLAME_SHADER
		mat.render_priority = i
		var card := MeshInstance3D.new()
		card.name = "Flame_%d" % i
		card.mesh = quad
		card.material_override = mat
		card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		card.position = Vector3(float(r[0]) * size, base_y, float(r[1]) * size)
		card.set_instance_shader_parameter(&"seed", rng.randf_range(0.0, 9.0) + i)
		card.set_instance_shader_parameter(&"gain", float(r[4]))
		card.custom_aabb = AABB(Vector3(-w, 0.0, -w), Vector3(w * 2.0, h, w * 2.0))
		add_child(card)
		_cards.append(card)


func _build_embers() -> void:
	var p := GPUParticles3D.new()
	p.name = "Embers"
	p.amount = int(18 * size * size)
	p.lifetime = 2.4
	p.preprocess = 2.4
	p.randomness = 0.5
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-2, 0, -2) * size, Vector3(4, 5, 4) * size)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.18 * size
	pm.direction = Vector3.UP
	pm.spread = 18.0
	pm.initial_velocity_min = 0.5 * size
	pm.initial_velocity_max = 1.3 * size
	pm.gravity = Vector3(0.0, 0.25, 0.0)
	pm.damping_min = 0.2
	pm.damping_max = 0.5
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 1.4
	pm.turbulence_noise_scale = 1.6
	pm.turbulence_influence_min = 0.05
	pm.turbulence_influence_max = 0.15
	pm.scale_min = 0.6
	pm.scale_max = 1.2
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	ramp.colors = PackedColorArray([Color(1.0, 0.72, 0.3, 1.0), Color(1.0, 0.42, 0.1, 0.9), Color(0.6, 0.12, 0.03, 0.0)])
	var rt := GradientTexture1D.new()
	rt.gradient = ramp
	pm.color_ramp = rt
	p.process_material = pm
	var spark := QuadMesh.new()
	spark.size = Vector2(0.022, 0.022) * clampf(size, 1.0, 2.0)
	var mat := MaterialLibrary.surface()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.disable_fog = true
	var dot := GradientTexture2D.new()
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5)
	dot.fill_to = Vector2(1.0, 0.5)
	dot.width = 32
	dot.height = 32
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	dot.gradient = g
	mat.albedo_texture = dot
	spark.material = mat
	p.draw_pass_1 = spark
	p.position.y = (0.15 if with_logs else 0.6) * size
	add_child(p)


func _build_smoke() -> void:
	var p := GPUParticles3D.new()
	p.name = "Smoke"
	p.amount = 16 if size <= 1.5 else 28
	p.lifetime = 5.5
	p.preprocess = 5.5
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-3, 0, -3) * size, Vector3(6, 8, 6) * size)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.08 * size
	pm.direction = Vector3.UP
	pm.spread = 6.0
	pm.initial_velocity_min = 0.45 * size
	pm.initial_velocity_max = 0.7 * size
	pm.gravity = Vector3(0.08, 0.05, 0.03)
	pm.angle_min = -180.0
	pm.angle_max = 180.0
	pm.angular_velocity_min = -12.0
	pm.angular_velocity_max = 12.0
	pm.scale_min = 0.35 * size
	pm.scale_max = 0.55 * size
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.35))
	grow.add_point(Vector2(1.0, 1.0))
	var gt := CurveTexture.new()
	gt.curve = grow
	pm.scale_curve = gt
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.2, 0.6, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.5), Color(1, 1, 1, 0)])
	var ft := GradientTexture1D.new()
	ft.gradient = fade
	pm.color_ramp = ft
	p.process_material = pm
	var puff := QuadMesh.new()
	puff.size = Vector2(1.0, 1.0)
	var mat := ShaderMaterial.new()
	mat.shader = SMOKE_SHADER
	puff.material = mat
	p.draw_pass_1 = puff
	p.position.y = TONGUE * size * height_scale * 0.75 + (0.06 if with_logs else 0.25 * size)
	add_child(p)


func _build_light() -> void:
	if light_energy <= 0.0:
		return   # the owner lights it (CalanmaiNight's pyres breathe their own)
	light = OmniLight3D.new()
	light.name = "FireLight"
	light.light_color = Color(1.0, 0.56, 0.26)
	light.light_energy = light_energy
	light.omni_range = light_range
	light.omni_attenuation = 1.0
	light.shadow_enabled = light_shadows
	# Above the logs, so their shadows don't hide the faces round the fire.
	light.position.y = maxf(1.2 * size, TONGUE * size * height_scale * 0.6)
	add_child(light)
	_flicker = light.create_tween().set_loops()
	_flicker.tween_property(light, ^"light_energy", light_energy * 0.82, 0.21)
	_flicker.tween_property(light, ^"light_energy", light_energy * 1.08, 0.33)
	_flicker.tween_property(light, ^"light_energy", light_energy * 0.94, 0.17)
	_flicker.tween_property(light, ^"light_energy", light_energy, 0.27)
