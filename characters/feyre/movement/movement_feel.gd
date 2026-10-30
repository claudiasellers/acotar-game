## The juice on top of Feyre's movement: squash and stretch on take-off and
## landing, a lean into turns and acceleration, a camera FOV kick while she
## sprints, and the triple jump's flourish: a front flip with a glitter trail
## and a sparkle burst (R3).
##
## Purely presentational: it reads her velocity and JumpMotor signals and
## never changes how she moves.
class_name MovementFeel
extends Node

## Extra camera FOV (degrees) at full sprint speed.
const SPRINT_FOV := 9.0
## Max lean (radians) into a turn, and forward lean at full acceleration.
const MAX_ROLL := 0.20
const MAX_PITCH := 0.10
const LEAN_SMOOTH := 8.0
## Landing squash per m/s of impact speed, capped.
const LAND_SQUASH_PER_SPEED := 0.018
const MAX_LAND_SQUASH := 0.22
## The triple jump's front flip: seconds for the full turn, pivoting at her middle.
const FLIP_TIME := 0.62
const FLIP_PIVOT := Vector3(0.0, 0.95, 0.0)

## Squash/stretch scale of her body (tweened).
var squash_scale := Vector3.ONE

var _feyre: Feyre
var _body: Node3D
var _base_fov: float = 70.0
var _last_yaw: float = 0.0
var _last_speed: float = 0.0
var _roll: float = 0.0
var _pitch: float = 0.0
var _squash: Tween
var _trail: GPUParticles3D
## Worn wardrobe meshes live beside her body (WardrobeApplier pins them to the
## skeleton's transform once), so they are re-pinned whenever the body moves.
var _worn: Array[MeshInstance3D] = []
var _skeleton: Skeleton3D
## Progress of the triple-jump flip, 0..1; negative when not flipping.
var _flip: float = -1.0


func _ready() -> void:
	_feyre = get_parent() as Feyre
	if _feyre == null:
		return
	_body = _feyre.model.get_child(0) as Node3D if _feyre.model.get_child_count() > 0 else _feyre.model
	_base_fov = _feyre.camera.fov
	_last_yaw = _feyre.model.rotation.y
	_feyre.jump_motor.jumped.connect(_on_jumped)
	_feyre.jump_motor.landed.connect(_on_landed)
	_build_trail()
	_skeleton = _body.find_child("Skeleton3D", true, false) as Skeleton3D
	Gameplay.wardrobe.changed.connect(_find_worn.call_deferred)
	_find_worn.call_deferred()


func _process(delta: float) -> void:
	if _feyre == null or delta <= 0.0:
		return
	var v := _feyre.velocity
	var speed := Vector2(v.x, v.z).length()
	var over_run := clampf((speed - _feyre.run_speed) / maxf(_feyre.sprint_speed - _feyre.run_speed, 0.01), 0.0, 1.0)
	_feyre.camera.fov = lerpf(_feyre.camera.fov, _base_fov + SPRINT_FOV * over_run, 6.0 * delta)

	var yaw := _feyre.model.rotation.y
	var yaw_rate := wrapf(yaw - _last_yaw, -PI, PI) / delta
	_last_yaw = yaw
	var accel := (speed - _last_speed) / delta
	_last_speed = speed
	var grounded := _feyre.is_on_floor()
	var target_roll := clampf(-yaw_rate * speed * 0.012, -MAX_ROLL, MAX_ROLL) if grounded else 0.0
	var target_pitch := clampf(-accel * 0.008, -MAX_PITCH, MAX_PITCH) if grounded else 0.0
	_roll = lerpf(_roll, target_roll, LEAN_SMOOTH * delta)
	_pitch = lerpf(_pitch, target_pitch, LEAN_SMOOTH * delta)
	var flip_angle := 0.0
	if _flip >= 0.0:
		_flip = minf(_flip + delta / FLIP_TIME, 1.0)
		# Ease in-out so the tuck reads at the top of the arc.
		flip_angle = -TAU * (0.5 - 0.5 * cos(PI * _flip))
		if _flip >= 1.0 or not _feyre.jump_motor.airborne:
			_flip = -1.0
			flip_angle = 0.0
	var turn := Basis(Vector3.RIGHT, flip_angle)
	var basis := turn * Basis.from_euler(Vector3(_pitch, 0.0, _roll)) * Basis.from_scale(squash_scale)
	var body_xform := Transform3D(basis, FLIP_PIVOT - turn * FLIP_PIVOT)
	if not body_xform.is_equal_approx(_body.transform):
		_body.transform = body_xform
		_pin_worn()

	if _trail and _trail.emitting and not _feyre.jump_motor.airborne:
		_trail.emitting = false


func _find_worn() -> void:
	_worn.clear()
	if _skeleton == null:
		return
	for child in _feyre.model.get_children():
		if child == _body:
			continue
		for mi in child.find_children("*", "MeshInstance3D", true, false):
			if (mi as MeshInstance3D).skin != null:
				_worn.append(mi)
	_pin_worn()


func _pin_worn() -> void:
	for mi in _worn:
		if is_instance_valid(mi):
			mi.global_transform = _skeleton.global_transform


func _on_jumped(index: int) -> void:
	# Quick crouch-and-spring: squash, then stretch upward, then settle.
	var stretch := 0.08 + 0.04 * index
	_play_squash([
		[Vector3(1.08, 0.88, 1.08), 0.05],
		[Vector3(1.0 - stretch * 0.5, 1.0 + stretch, 1.0 - stretch * 0.5), 0.10],
		[Vector3.ONE, 0.25],
	])
	if index == 3:
		_flip = 0.0
		Juice.burst(_feyre.model, &"unlock", Vector3.ZERO, 1.25)
		if _trail:
			_trail.restart()
			_trail.emitting = true


func _on_landed(impact_speed: float, index: int) -> void:
	var s := minf(impact_speed * LAND_SQUASH_PER_SPEED, MAX_LAND_SQUASH)
	if index == 3:
		s = MAX_LAND_SQUASH
		Juice.burst(_feyre.model, &"pickup", Vector3.ZERO, 1.5)
	if s < 0.03:
		return
	_play_squash([
		[Vector3(1.0 + s * 0.6, 1.0 - s, 1.0 + s * 0.6), 0.06],
		[Vector3.ONE, 0.3],
	])


func _play_squash(steps: Array) -> void:
	if _squash and _squash.is_valid():
		_squash.kill()
	_squash = create_tween()
	for i in steps.size():
		var step: Array = steps[i]
		var t := _squash.tween_property(self, ^"squash_scale", step[0], step[1])
		if i == steps.size() - 1:
			t.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		else:
			t.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## A ribbon of pastel glitter behind her while the third jump flies.
func _build_trail() -> void:
	_trail = GPUParticles3D.new()
	_trail.name = "FlourishTrail"
	_trail.amount = 48
	_trail.lifetime = 0.7
	_trail.emitting = false
	_trail.local_coords = false
	_trail.position = Vector3(0, 1.0, 0)
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.35
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 60.0
	mat.initial_velocity_min = 0.2
	mat.initial_velocity_max = 0.6
	mat.gravity = Vector3(0, -0.6, 0)
	mat.scale_min = 0.5
	mat.scale_max = 1.2
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.85, 0.95, 1.0))
	grad.add_point(0.5, Color(0.85, 0.8, 1.0, 0.9))
	grad.set_color(grad.get_point_count() - 1, Color(1.0, 0.95, 0.7, 0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = grad
	mat.color_ramp = ramp
	_trail.process_material = mat
	var quad := QuadMesh.new()
	quad.size = Vector2(0.06, 0.06)
	var pm := StandardMaterial3D.new()
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	pm.vertex_color_use_as_albedo = true
	pm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	quad.material = pm
	_trail.draw_pass_1 = quad
	_feyre.model.add_child(_trail)
