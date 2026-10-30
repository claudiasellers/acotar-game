## A real arrow: a rigid body that flies on a ballistic arc, turns to face its
## velocity, and sticks into what it hits so it can be pulled back out.
class_name Arrow
extends RigidBody3D

signal hit(collider: Node, at: Vector3)

const LENGTH := 0.75
const LAYER_ARROWS := 1 << 2
const MASK_WORLD_AND_TARGETS := (1 << 0) | (1 << 3)
const STUCK_GROUP := &"stuck_arrows"
const KILL_DEPTH := -100.0

var stuck: bool = false


static func create() -> Arrow:
	var arrow := Arrow.new()
	arrow.name = "Arrow"
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
	wood.albedo_color = Color(0.55, 0.42, 0.28)
	shaft.material_override = wood
	arrow.add_child(shaft)

	var fletching := MeshInstance3D.new()
	var vanes := BoxMesh.new()
	vanes.size = Vector3(0.05, 0.002, 0.12)
	fletching.mesh = vanes
	fletching.position.z = LENGTH * 0.5 - 0.07
	var feather := StandardMaterial3D.new()
	feather.albedo_color = Color(0.85, 0.82, 0.75)
	fletching.material_override = feather
	arrow.add_child(fletching)
	return arrow


func _ready() -> void:
	mass = 0.03
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 2
	collision_layer = LAYER_ARROWS
	collision_mask = MASK_WORLD_AND_TARGETS
	body_entered.connect(_on_body_entered)


func launch(from: Vector3, direction: Vector3, speed: float) -> void:
	global_position = from
	_face(direction)
	linear_velocity = direction.normalized() * speed


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if stuck:
		return
	state.angular_velocity = Vector3.ZERO
	if state.linear_velocity.length_squared() > 1.0:
		var t := state.transform
		t.basis = _basis_facing(state.linear_velocity)
		state.transform = t


func _physics_process(_delta: float) -> void:
	if not stuck and global_position.y < KILL_DEPTH:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if stuck:
		return
	stuck = true
	hit.emit(body, global_position)
	if body.has_method(&"on_arrow_hit"):
		body.on_arrow_hit(self)
	_stick.call_deferred(body)


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
