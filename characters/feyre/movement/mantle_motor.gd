## Feyre's ledge climb, kept apart from the controller (T100): finds a ledge in
## front of her between knee and reach height, checks her body fits the whole
## way up and over, then tweens her onto it past physics.
##
## The owner calls `try_climb()` on a jump press on the ground, or while falling
## and pushing toward a wall; `climbing` is true until the tween lands.
class_name MantleMotor
extends RefCounted

## The body swept along a ledge climb: a touch slimmer than her capsule, feet off
## the floor, so what she merely stands on or leans against doesn't count.
const CLIMB_RADIUS := 0.27
const CLIMB_HEIGHT := 1.6
const CLIMB_CENTRE := 0.9

var climbing: bool = false

var _body: CharacterBody3D
var _forward_of: Node3D
var _tween: Tween


## `body` is the one that climbs; `facing` is the node whose -Z is her front.
func _init(body: CharacterBody3D, facing: Node3D) -> void:
	_body = body
	_forward_of = facing


## Climbs onto a ledge in front of her between knee and reach height.
func try_climb() -> bool:
	var b := _body
	var mask := Feyre.WORLD_MASK
	var space := b.get_world_3d().direct_space_state
	var forward := -_forward_of.global_basis.z
	var chest := b.global_position + Vector3.UP * 1.1
	var wall := space.intersect_ray(PhysicsRayQueryParameters3D.create(
			chest, chest + forward * 0.8, mask, [b.get_rid()]))
	if not wall:
		var knee := b.global_position + Vector3.UP * 0.5
		wall = space.intersect_ray(PhysicsRayQueryParameters3D.create(
				knee, knee + forward * 0.8, mask, [b.get_rid()]))
	if not wall:
		return false
	var probe: Vector3 = wall.position + forward * 0.35 + Vector3.UP * 1.6
	var top := space.intersect_ray(PhysicsRayQueryParameters3D.create(
			probe, probe + Vector3.DOWN * 2.4, mask, [b.get_rid()]))
	if not top or top.normal.dot(Vector3.UP) < 0.7:
		return false
	if RegionGate.owns(wall.collider) or RegionGate.owns(top.collider):
		return false
	var rise: float = top.position.y - b.global_position.y
	if rise < 0.6 or rise > (2.8 if GameSettings.gentle_mode else 2.3):
		return false
	var landing: Vector3 = top.position + forward * 0.25 + Vector3.UP * 0.05
	if not _climb_is_clear(landing):
		return false
	climbing = true
	b.velocity = Vector3.ZERO
	_tween = b.create_tween()
	_tween.tween_property(b, ^"global_position:y", top.position.y + 0.05, 0.28)
	_tween.tween_property(b, ^"global_position", landing, 0.16)
	_tween.finished.connect(func() -> void: climbing = false)
	return true


## Stops a climb in progress (a teleport): its tween would otherwise carry her
## back onto the ledge.
func cancel() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null
	climbing = false


## The climb tweens her straight up and then over, past physics, and the ledge
## ray can start inside a wall and find a floor behind it. So her body is swept
## along both legs first: a climb only happens if she fits the whole way.
func _climb_is_clear(landing: Vector3) -> bool:
	var b := _body
	var shape := CapsuleShape3D.new()
	shape.radius = CLIMB_RADIUS
	shape.height = CLIMB_HEIGHT
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = Feyre.WORLD_MASK
	query.exclude = [b.get_rid()]
	var centre := Vector3.UP * CLIMB_CENTRE
	var start := b.global_position
	var over := Vector3(start.x, landing.y, start.z)
	var space := b.get_world_3d().direct_space_state
	for leg: Array[Vector3] in [[start, over], [over, landing]] as Array[Array]:
		query.transform = Transform3D(Basis.IDENTITY, leg[0] + centre)
		query.motion = leg[1] - leg[0]
		if space.cast_motion(query)[0] < 1.0:
			return false
	return true
