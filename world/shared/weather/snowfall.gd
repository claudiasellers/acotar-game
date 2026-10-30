## Falling snow that follows the camera, scaled by the snow_cover grade and
## SnowPrints.snowfall. Off north of the Wall (petals and sparkles there are
## the Spring Court lanes' ambient effects).
class_name Snowfall
extends GPUParticles3D

@export var max_amount := 6000
@export var area := Vector3(60.0, 24.0, 60.0)
@export var prints: SnowPrints


func _ready() -> void:
	amount = max_amount
	lifetime = 9.0
	preprocess = 9.0
	visibility_aabb = AABB(-area * 0.5 - Vector3(0, 20, 0), area + Vector3(0, 40, 0))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(area.x * 0.5, 1.0, area.z * 0.5)
	pm.direction = Vector3(0.1, -1.0, 0.05)
	pm.spread = 12.0
	pm.initial_velocity_min = 1.0
	pm.initial_velocity_max = 1.8
	pm.gravity = Vector3(0, -0.6, 0)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.6
	pm.scale_min = 0.6
	pm.scale_max = 1.4
	process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.05, 0.05)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.95, 0.97, 1.0, 0.85)
	quad.material = mat
	draw_pass_1 = quad


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	global_position = cam.global_position + Vector3(0.0, area.y * 0.5, 0.0)
	var cover := GradeDirector.snow_cover_now
	var fall := prints.snowfall if prints != null else 0.4
	if fall <= 0.001:
		emitting = false
		return
	var on := cover > 0.05 and cam.global_position.z > WorldMap.WALL_Z - 20.0
	emitting = on
	amount_ratio = clampf(cover * (0.25 + fall), 0.0, 1.0)
