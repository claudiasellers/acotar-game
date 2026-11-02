## Walks a cast actor (a CastModel, or any Node3D) across the ground for the
## p4 scenes: a fixed pace towards a point, feet on whatever is below (a ray
## from above, else the terrain height), facing where it goes, with the
## model's own walk clip when it has one (feyre_model.play_locomotion).
class_name Act4Walk
extends RefCounted


## Moves `who` one step toward `target` (flat). Returns true once within 0.4 m.
static func step(who: Node3D, target: Vector3, speed: float, delta: float) -> bool:
	if who == null or not is_instance_valid(who):
		return true
	var here := who.global_position
	var to := Vector3(target.x - here.x, 0.0, target.z - here.z)
	var dist := to.length()
	if dist <= 0.4:
		idle(who)
		return true
	var move := to / dist * minf(speed * delta, dist)
	var next := here + move
	next.y = ground(who, next)
	who.global_position = next
	face(who, target)
	if who.has_method(&"play_locomotion") and delta > 0.0:
		who.call(&"play_locomotion", speed, true, delta)
	return false


## Stops the walk clip (idle).
static func idle(who: Node3D) -> void:
	if who and is_instance_valid(who) and who.has_method(&"play_locomotion"):
		who.call(&"play_locomotion", 0.0, true, 0.016)


## Turns `who` (flat) toward a point.
static func face(who: Node3D, at: Vector3) -> void:
	var flat := Vector3(at.x, who.global_position.y, at.z)
	if who.global_position.distance_squared_to(flat) > 0.0004:
		who.look_at(flat, Vector3.UP)


## Ground height under a point: a ray from 6 m above (excluding the player),
## else WorldHeight.
static func ground(from: Node3D, p: Vector3) -> float:
	if from.is_inside_tree():
		var state := from.get_world_3d().direct_space_state
		if state:
			var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 6.0, p + Vector3.DOWN * 30.0)
			q.collision_mask = 1
			var pl := from.get_tree().get_first_node_in_group(&"player")
			if pl is CollisionObject3D:
				q.exclude = [(pl as CollisionObject3D).get_rid()]
			var hit := state.intersect_ray(q)
			if hit:
				return (hit["position"] as Vector3).y
	return WorldHeight.height_at(p.x, p.z)


## The point on the ground under `p` (any Node3D in the tree to ray from;
## null falls back to WorldHeight).
static func ground_point(from: Node3D, p: Vector3) -> Vector3:
	if from == null or not from.is_inside_tree():
		return Vector3(p.x, WorldHeight.height_at(p.x, p.z), p.z)
	return Vector3(p.x, ground(from, p), p.z)


## Sets an actor's feet on the ground where it stands. Returns it.
static func plant(from: Node3D, who: Node3D) -> Node3D:
	if who and is_instance_valid(who):
		who.global_position = ground_point(from, who.global_position)
	return who
