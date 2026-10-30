## Placeholder Feyre for M0: third-person movement, sprint with stamina,
## jumping, ledge mantling, and a bow that fires real arrows.
##
## The body is a capsule until the art lane delivers her model; everything
## here is built in code so the art can be swapped in under `model` later.
class_name Feyre
extends CharacterBody3D

signal arrow_fired(arrow: Arrow)
signal quiver_changed(count: int)

const PLAYER_LAYER := 1 << 1
const WORLD_MASK := 1 << 0

@export var bow: BowData = preload("res://data/bows/hunting_bow.tres")
@export var walk_speed: float = 3.2
@export var run_speed: float = 5.5
@export var sprint_speed: float = 8.0
@export var aim_speed: float = 2.2
@export var jump_velocity: float = 4.6
@export var acceleration: float = 14.0
@export var air_control: float = 0.35
@export var turn_speed: float = 12.0
@export var max_stamina: float = 100.0
@export var sprint_drain: float = 22.0
@export var stamina_regen: float = 16.0
@export var stamina_regen_delay: float = 0.8
@export var quiver: int = 12
@export var max_quiver: int = 30
@export var mouse_sensitivity: float = 0.0025
@export var stick_sensitivity: float = 2.6

var stamina: float = 100.0
var draw_amount: float = 0.0
var is_drawing: bool = false
var is_aiming: bool = false
var is_mantling: bool = false

var model: Node3D
var camera: Camera3D

var _camera_rig: Node3D
var _camera_pitch: Node3D
var _spring_arm: SpringArm3D
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _stamina_cooldown: float = 0.0
var _exhausted: bool = false


func _ready() -> void:
	add_to_group(&"player")
	collision_layer = PLAYER_LAYER
	collision_mask = WORLD_MASK
	floor_snap_length = 0.4
	floor_max_angle = deg_to_rad(50.0)
	stamina = max_stamina
	_build_body()
	_build_camera()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"pause"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED \
			and StoryControl.can_look():
		_rotate_camera(-event.relative.x * mouse_sensitivity, -event.relative.y * mouse_sensitivity)
	if event.is_action_pressed(&"interact") and StoryControl.can_interact():
		pick_up_nearest_arrow()


func _process(delta: float) -> void:
	_camera_rig.global_position = global_position + Vector3.UP * 1.5
	var look := Input.get_vector(&"look_left", &"look_right", &"look_up", &"look_down")
	if look != Vector2.ZERO and StoryControl.can_look():
		_rotate_camera(-look.x * stick_sensitivity * delta, -look.y * stick_sensitivity * delta)
	_drift_toward_focus(delta)
	var target_length := 1.7 if (is_aiming or is_drawing) else 3.6
	_spring_arm.spring_length = lerpf(_spring_arm.spring_length, target_length, 10.0 * delta)
	var shoulder := 0.55 if (is_aiming or is_drawing) else 0.0
	_spring_arm.position.x = lerpf(_spring_arm.position.x, shoulder, 10.0 * delta)


func _physics_process(delta: float) -> void:
	if is_mantling:
		return
	is_aiming = Input.is_action_pressed(&"aim")
	_update_bow(delta)

	var input := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	if not StoryControl.can_move():
		input = Vector2.ZERO
	var yaw := _camera_rig.rotation.y
	var direction := Vector3(input.x, 0.0, input.y).rotated(Vector3.UP, yaw)
	var sprinting := Input.is_action_pressed(&"sprint") and direction != Vector3.ZERO \
			and not _exhausted and not is_drawing and not is_aiming
	_update_stamina(delta, sprinting)

	var speed := run_speed
	if is_aiming or is_drawing:
		speed = aim_speed
	elif sprinting:
		speed = sprint_speed
	elif input.length() < 0.5:
		speed = walk_speed

	if not is_on_floor():
		velocity.y -= _gravity * delta
	elif Input.is_action_just_pressed(&"jump") and StoryControl.can_move():
		if not _try_mantle():
			velocity.y = jump_velocity

	var control := acceleration if is_on_floor() else acceleration * air_control
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	horizontal = horizontal.move_toward(direction * speed, control * speed * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z

	if not is_on_floor() and velocity.y < 2.0 and input.y < -0.3:
		_try_mantle()

	_turn_model(direction, yaw, delta)
	move_and_slide()


## Root design doc §4.3: arrows are scarce, so stuck arrows can be collected.
func pick_up_nearest_arrow(reach: float = 2.5) -> bool:
	if quiver >= max_quiver:
		return false
	var nearest: Node3D = null
	var best := reach
	for arrow in get_tree().get_nodes_in_group(Arrow.STUCK_GROUP):
		var d := global_position.distance_to((arrow as Node3D).global_position)
		if d < best:
			best = d
			nearest = arrow
	if nearest == null:
		return false
	nearest.queue_free()
	add_arrows(1)
	return true


func add_arrows(count: int) -> void:
	quiver = clampi(quiver + count, 0, max_quiver)
	quiver_changed.emit(quiver)


func aim_point(max_distance: float = 250.0) -> Vector3:
	var from := camera.global_position
	var to := from - camera.global_basis.z * max_distance
	var query := PhysicsRayQueryParameters3D.create(from, to, WORLD_MASK | (1 << 3), [get_rid()])
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result:
		return result.position
	return to


func _update_bow(delta: float) -> void:
	if Input.is_action_pressed(&"fire") and quiver > 0:
		is_drawing = true
		draw_amount = minf(draw_amount + delta / bow.draw_time, 1.0)
	elif is_drawing:
		_release_arrow()
		is_drawing = false
		draw_amount = 0.0


func _release_arrow() -> void:
	if quiver <= 0:
		return
	var muzzle := global_position + Vector3.UP * 1.45 - model.global_basis.z * 0.45
	var direction := (aim_point() - muzzle).normalized()
	var arrow := Arrow.create()
	get_tree().current_scene.add_child(arrow)
	arrow.add_collision_exception_with(self)
	arrow.launch(muzzle, direction, lerpf(bow.min_speed, bow.max_speed, draw_amount))
	add_arrows(-1)
	arrow_fired.emit(arrow)


func _update_stamina(delta: float, sprinting: bool) -> void:
	if sprinting:
		stamina = maxf(stamina - sprint_drain * delta, 0.0)
		_stamina_cooldown = stamina_regen_delay
		if stamina <= 0.0:
			_exhausted = true
	elif _stamina_cooldown > 0.0:
		_stamina_cooldown -= delta
	else:
		stamina = minf(stamina + stamina_regen * delta, max_stamina)
	# Feyre has to catch her breath before sprinting again.
	if _exhausted and stamina >= max_stamina * 0.35:
		_exhausted = false


func _turn_model(direction: Vector3, camera_yaw: float, delta: float) -> void:
	var target_yaw := model.rotation.y
	if is_aiming or is_drawing:
		target_yaw = camera_yaw
	elif direction.length_squared() > 0.01:
		target_yaw = atan2(-direction.x, -direction.z)
	model.rotation.y = lerp_angle(model.rotation.y, target_yaw, turn_speed * delta)


## Climbs onto a ledge in front of Feyre between knee and reach height.
func _try_mantle() -> bool:
	var space := get_world_3d().direct_space_state
	var forward := -model.global_basis.z
	var chest := global_position + Vector3.UP * 1.1
	var wall := space.intersect_ray(PhysicsRayQueryParameters3D.create(
			chest, chest + forward * 0.8, WORLD_MASK, [get_rid()]))
	if not wall:
		var knee := global_position + Vector3.UP * 0.5
		wall = space.intersect_ray(PhysicsRayQueryParameters3D.create(
				knee, knee + forward * 0.8, WORLD_MASK, [get_rid()]))
	if not wall:
		return false
	var probe: Vector3 = wall.position + forward * 0.35 + Vector3.UP * 1.6
	var top := space.intersect_ray(PhysicsRayQueryParameters3D.create(
			probe, probe + Vector3.DOWN * 2.4, WORLD_MASK, [get_rid()]))
	if not top or top.normal.dot(Vector3.UP) < 0.7:
		return false
	var rise: float = top.position.y - global_position.y
	if rise < 0.6 or rise > 2.3:
		return false
	is_mantling = true
	velocity = Vector3.ZERO
	var tween := create_tween()
	tween.tween_property(self, ^"global_position:y", top.position.y + 0.05, 0.28)
	var landing: Vector3 = top.position + forward * 0.25 + Vector3.UP * 0.05
	tween.tween_property(self, ^"global_position", landing, 0.16)
	tween.finished.connect(func() -> void: is_mantling = false)
	return true


## During anchored moments the camera eases toward what the scene is about.
func _drift_toward_focus(delta: float) -> void:
	var focus := StoryControl.focus
	if focus == null or not is_instance_valid(focus):
		return
	var to := focus.global_position - _camera_rig.global_position
	if Vector2(to.x, to.z).length() < 0.5:
		return
	var yaw := atan2(-to.x, -to.z)
	_camera_rig.rotation.y = lerp_angle(_camera_rig.rotation.y, yaw, 1.6 * delta)


func _rotate_camera(yaw_delta: float, pitch_delta: float) -> void:
	_camera_rig.rotation.y += yaw_delta
	_camera_pitch.rotation.x = clampf(_camera_pitch.rotation.x + pitch_delta, deg_to_rad(-70.0), deg_to_rad(55.0))


func _build_body() -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.7
	shape.shape = capsule
	shape.position.y = 0.85
	add_child(shape)

	model = Node3D.new()
	model.name = "Model"
	add_child(model)

	var cloak := StandardMaterial3D.new()
	cloak.albedo_color = Color(0.36, 0.30, 0.24)
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(0.92, 0.78, 0.66)

	var body_mesh := MeshInstance3D.new()
	var body_capsule := CapsuleMesh.new()
	body_capsule.radius = 0.26
	body_capsule.height = 1.45
	body_mesh.mesh = body_capsule
	body_mesh.position.y = 0.73
	body_mesh.material_override = cloak
	model.add_child(body_mesh)

	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.13
	sphere.height = 0.26
	head.mesh = sphere
	head.position.y = 1.58
	head.material_override = skin
	model.add_child(head)

	# A nose so it is obvious which way she faces.
	var nose := MeshInstance3D.new()
	var nose_box := BoxMesh.new()
	nose_box.size = Vector3(0.04, 0.05, 0.08)
	nose.mesh = nose_box
	nose.position = Vector3(0.0, 1.58, -0.14)
	nose.material_override = skin
	model.add_child(nose)


func _build_camera() -> void:
	_camera_rig = Node3D.new()
	_camera_rig.name = "CameraRig"
	_camera_rig.top_level = true
	add_child(_camera_rig)
	_camera_pitch = Node3D.new()
	_camera_pitch.rotation.x = deg_to_rad(-12.0)
	_camera_rig.add_child(_camera_pitch)
	_spring_arm = SpringArm3D.new()
	_spring_arm.spring_length = 3.6
	_spring_arm.collision_mask = WORLD_MASK
	_spring_arm.margin = 0.2
	_spring_arm.add_excluded_object(get_rid())
	_camera_pitch.add_child(_spring_arm)
	camera = Camera3D.new()
	camera.fov = 70.0
	camera.far = 2000.0
	camera.current = true
	_spring_arm.add_child(camera)
	_camera_rig.global_position = global_position + Vector3.UP * 1.5
