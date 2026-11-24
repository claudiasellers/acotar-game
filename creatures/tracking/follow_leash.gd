## Keeps a creature Feyre is following from getting away from her
## (plans/hostile-fae/health-interactions.md §3.6, rule 1). It reads her
## position, not a home point, and only ever writes the creature's
## move_direction, move_speed and gait_hint, after its brain has thought.
##
## Past SOFT of the leash the creature stops widening the gap: it picks a spot
## on the RING nearer her that her camera can't see, walks there and holds
## until where its brain wants to go is back within her reach. Seen on the way, it stands
## still, so she never watches it turn round. If she outruns it, it gallops
## while unseen, and at the leash's end it is set down on a hidden spot.
##
## A wounded animal (bed mode) does none of that: at the edge it beds down.
##
## The leash arms the first time she comes within SOFT of it, so a creature
## she is still walking up to is left alone.
class_name FollowLeash
extends Node

## Fractions of the leash: where it stops widening the gap, where it comes
## back to, where it starts to hurry (unseen) and where it is set down.
const SOFT := 0.8
const RING := 0.6
const HURRY := 0.9
const HARD := 0.97
## Seconds between looks for a better hidden spot while it returns.
const REPICK_S := 0.5
## Angles (degrees) off the line from her to it, tried in order for a spot.
const SPOT_ANGLES: Array[float] = [0.0, 25.0, -25.0, 50.0, -50.0, 80.0, -80.0, 120.0, -120.0, 160.0, -160.0]

var creature: Creature
var metres: float = 50.0
## Only once she has wounded it (CreatureData.leash_wounded_only).
var wounded_only: bool = false
## The brain turns the leash off for a while (the wolf over his kill).
var paused: bool = false
var armed: bool = false
## It is on its way back, or holding at the edge.
var engaged: bool = false
var holding: bool = false

var _goal: Vector3
var _repick: float = 0.0


## The creature's leash, made on first use. `metres` <= 0 keeps the length.
static func on(c: Creature, length: float = 0.0) -> FollowLeash:
	if c.leash == null:
		c.leash = FollowLeash.new()
		c.leash.name = "FollowLeash"
		c.leash.creature = c
		c.add_child(c.leash)
	if length > 0.0:
		c.leash.metres = length
	return c.leash


## Whether her camera can see `point`: in the frustum with nothing solid in
## the way. False with no camera.
static func in_view(from: Node3D, point: Vector3) -> bool:
	if from == null or not from.is_inside_tree():
		return false
	var cam := from.get_viewport().get_camera_3d()
	if cam == null or not cam.is_position_in_frustum(point):
		return false
	var query := PhysicsRayQueryParameters3D.create(cam.global_position, point, Creature.WORLD_MASK)
	var hit := from.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or (hit.position as Vector3).distance_to(point) < 1.0


## Whether she can see the creature: the middle of its body.
static func sees(c: Creature) -> bool:
	return in_view(c, c.global_position + Vector3.UP * c.data.body_height * 0.6)


func applies() -> bool:
	if creature == null or not creature.alive or paused or metres <= 0.0:
		return false
	return not wounded_only or creature.bleeding > 0.0 or creature.health < creature.data.max_health


## Called by Creature after its brain: bends this frame's motion if it must.
func steer(delta: float) -> void:
	var her := _followed()
	if her == null or not applies():
		engaged = false
		holding = false
		return
	var c := creature
	var to_her := her.global_position - c.global_position
	to_her.y = 0.0
	var d := to_her.length()
	if not armed:
		armed = wounded_only or d <= metres * SOFT
		if not armed:
			return
	# Standing, or on its way to somewhere still within reach of her: its
	# own business, and the end of any holding back.
	var idle := c.move_speed <= 0.0
	var heading_in := not idle and _flat(c.global_position + c.move_direction - her.global_position).length() < metres * SOFT
	if c.has_method(&"bed_down"):
		if d >= metres * SOFT and not heading_in:
			c.call(&"bed_down")
			c.move_speed = 0.0
			c.move_direction = Vector3.ZERO
		return
	if heading_in:
		engaged = false
		holding = false
		return
	if not engaged:
		if d < metres * SOFT:
			return
		engaged = true
		holding = false
		_repick = 0.0
	if holding:
		if d < metres * SOFT:
			if idle:
				engaged = false
				holding = false
			else:
				c.move_speed = 0.0
				c.move_direction = Vector3.ZERO
			return
		holding = false
		_repick = 0.0
	_repick -= delta
	if _repick <= 0.0:
		_repick = REPICK_S
		_goal = _hidden_spot(her)
	var seen := FollowLeash.sees(c)
	if d >= metres * HARD and not seen and _set_down(her):
		return
	var to_goal := _flat(_goal - c.global_position)
	if d <= metres * RING or to_goal.length() < 2.0:
		holding = true
		c.move_speed = 0.0
		c.move_direction = Vector3.ZERO
		return
	c.gait_hint = &""
	if seen and d < metres:
		# Watched: he stands where he is rather than be seen coming back.
		c.move_speed = 0.0
		c.move_direction = Vector3.ZERO
		return
	c.move_direction = to_goal
	c.move_speed = c.data.run_speed if d >= metres * HURRY and not seen else c.data.walk_speed


## A spot on the ring round her that her camera can't see, nearest the line
## from her to the creature; behind her camera if every one is in view.
func _hidden_spot(her: Node3D) -> Vector3:
	var out := _flat(creature.global_position - her.global_position)
	out = out.normalized() if out.length_squared() > 0.0001 else Vector3.FORWARD
	var chest := Vector3.UP * creature.data.body_height * 0.6
	for degrees in SPOT_ANGLES:
		var spot := her.global_position + out.rotated(Vector3.UP, deg_to_rad(degrees)) * metres * RING
		spot.y = creature.global_position.y
		if not FollowLeash.in_view(creature, spot + chest):
			return spot
	var cam := creature.get_viewport().get_camera_3d()
	var back := _flat(cam.global_basis.z).normalized() if cam else out
	var behind := her.global_position + back * metres * RING
	behind.y = creature.global_position.y
	return behind


## She has outrun it and can't see it: put it on the hidden spot, on the
## ground. False (nothing moved) when the spot has no ground or is in view.
func _set_down(her: Node3D) -> bool:
	var spot := _hidden_spot(her)
	var space := creature.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(spot + Vector3.UP * 40.0, spot + Vector3.DOWN * 40.0, Creature.WORLD_MASK)
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return false
	var ground: Vector3 = hit.position
	if FollowLeash.in_view(creature, ground + Vector3.UP * creature.data.body_height * 0.6):
		return false
	creature.global_position = ground + Vector3.UP * 0.05
	creature.velocity = Vector3.ZERO
	creature.move_speed = 0.0
	creature.move_direction = Vector3.ZERO
	_goal = creature.global_position
	holding = true
	return true


func _followed() -> Node3D:
	if creature == null or not creature.is_inside_tree():
		return null
	return creature.get_tree().get_first_node_in_group(&"player") as Node3D


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
