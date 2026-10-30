## A real arrow: a rigid body that flies on a ballistic arc with drag and wind,
## turns to face its velocity, and sticks into what it hits so it can be pulled
## back out. Wet fletching flies short; arrows that hit stone can break.
class_name Arrow
extends RigidBody3D

signal hit(collider: Node, at: Vector3)
signal broke(at: Vector3)

const LENGTH := 0.75
const LAYER_ARROWS := 1 << 2
const MASK_WORLD_AND_TARGETS := (1 << 0) | (1 << 3)
const STUCK_GROUP := &"stuck_arrows"
const STONE_GROUP := &"stone"
const KILL_DEPTH := -100.0
const DEFAULT_DATA := preload("res://data/arrows/wood.tres")

var stuck: bool = false
var data: ArrowData = DEFAULT_DATA
## Creatures read this on hit: &"wood" or &"ash" (also set as meta).
var arrow_id: StringName = &"wood"
var wet: bool = false
## Seeded per arrow so breakage is reproducible in tests.
var rng := RandomNumberGenerator.new()

var _wind_source: Node = null
## Where the arrow was last physics frame, for the swept ray check.
var _last_pos: Vector3 = Vector3.INF


static func create(arrow_data: ArrowData = null) -> Arrow:
	var arrow := Arrow.new()
	arrow.name = "Arrow"
	arrow.data = arrow_data if arrow_data else DEFAULT_DATA
	arrow.arrow_id = arrow.data.id
	arrow.set_meta(&"arrow_id", arrow.arrow_id)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.03, 0.03, LENGTH)
	shape.shape = box
	arrow.add_child(shape)

	var shaft := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.006
	cylinder.bottom_radius = 0.006
	cylinder.height = LENGTH
	shaft.mesh = cylinder
	shaft.rotation_degrees.x = 90.0
	var wood := StandardMaterial3D.new()
	wood.albedo_color = arrow.data.shaft_color
	shaft.material_override = wood
	arrow.add_child(shaft)

	var fletching := MeshInstance3D.new()
	var vanes := BoxMesh.new()
	vanes.size = Vector3(0.05, 0.002, 0.12)
	fletching.mesh = vanes
	fletching.position.z = LENGTH * 0.5 - 0.07
	var feather := StandardMaterial3D.new()
	feather.albedo_color = arrow.data.fletching_color
	fletching.material_override = feather
	arrow.add_child(fletching)
	return arrow


func _ready() -> void:
	mass = data.mass
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 2
	collision_layer = LAYER_ARROWS
	collision_mask = MASK_WORLD_AND_TARGETS
	body_entered.connect(_on_body_entered)
	_wind_source = get_tree().get_first_node_in_group(&"wind_source")


func launch(from: Vector3, direction: Vector3, speed: float, is_wet: bool = false) -> void:
	wet = is_wet
	if wet:
		speed *= data.wet_speed_multiplier
	global_position = from
	_last_pos = from
	_face(direction)
	linear_velocity = direction.normalized() * speed


func drag() -> float:
	return data.drag * (data.wet_drag_multiplier if wet else 1.0)


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if stuck:
		return
	state.angular_velocity = Vector3.ZERO
	var wind := Vector3.ZERO
	if _wind_source and is_instance_valid(_wind_source) and _wind_source.has_method(&"wind_at"):
		wind = _wind_source.wind_at(state.transform.origin)
	# Gravity is applied by the engine; drag (against the moving air) here.
	var air := state.linear_velocity - wind
	state.linear_velocity += -drag() * air.length() * air * state.step
	if state.linear_velocity.length_squared() > 1.0:
		var t := state.transform
		t.basis = _basis_facing(state.linear_velocity)
		state.transform = t


func _physics_process(_delta: float) -> void:
	if stuck:
		return
	if global_position.y < KILL_DEPTH:
		queue_free()
		return
	_sweep()


## A ray from last frame's position to the tip now, so a fast arrow can't
## skip through thin colliders or a terrain heightfield (F4) between steps.
func _sweep() -> void:
	var tip := global_position + linear_velocity.normalized() * LENGTH * 0.5
	if _last_pos == Vector3.INF or not is_inside_tree():
		_last_pos = global_position
		return
	var exclude: Array[RID] = [get_rid()]
	for body in get_collision_exceptions():
		exclude.append(body.get_rid())
	var query := PhysicsRayQueryParameters3D.create(_last_pos, tip, collision_mask, exclude)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	_last_pos = global_position
	if hit.is_empty():
		return
	var dir := linear_velocity.normalized()
	global_position = hit.position - dir * LENGTH * 0.35
	linear_velocity = Vector3.ZERO
	_on_body_entered(hit.collider as Node)


func _on_body_entered(body: Node) -> void:
	if stuck:
		return
	stuck = true
	hit.emit(body, global_position)
	if body != null and body.has_method(&"on_arrow_hit"):
		body.on_arrow_hit(self)
	if Arrow.is_stone(body) and rng.randf() < data.stone_break_chance:
		broke.emit(global_position)
		ArrowEffects.apply(self, body, global_position)
		queue_free.call_deferred()
		return
	ArrowEffects.apply(self, body, global_position)
	_stick.call_deferred(body)


static func is_stone(body: Node) -> bool:
	return body != null and (body.is_in_group(STONE_GROUP) or String(body.get_meta(&"surface", "")) == "stone")


func _stick(body: Node) -> void:
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	freeze = true
	collision_layer = 0
	collision_mask = 0
	add_to_group(STUCK_GROUP)
	if body is Node3D and is_instance_valid(body):
		reparent(body, true)


func _face(direction: Vector3) -> void:
	basis = _basis_facing(direction)


static func _basis_facing(direction: Vector3) -> Basis:
	var forward := direction.normalized()
	var up := Vector3.UP if absf(forward.dot(Vector3.UP)) < 0.98 else Vector3.FORWARD
	return Basis.looking_at(forward, up)
