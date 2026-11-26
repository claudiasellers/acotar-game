## Moves a creature or person on the navmesh (T5): a NavigationAgent3D child
## that turns "go to that point" into "head for the next corner". When there is
## no navmesh under the mover or its goal (no region baked yet, out on open
## ground past the tile), it answers the straight line, so today's direct
## steering stays the fallback.
class_name NavMover
extends NavigationAgent3D

const NODE_NAME := "NavMover"
## Goals closer than this go straight (lunges, last steps, nudges).
const MIN_DISTANCE := 2.0
## The mover must be this close to the navmesh to use it.
const ON_MESH := 1.2
## Re-path only when the goal moves this far.
const RETARGET := 0.75

var _goal := Vector3.INF
var _host: Node3D


## The mover on `host`, created on first use.
static func on(host: Node3D) -> NavMover:
	var m := host.get_node_or_null(NODE_NAME) as NavMover
	if m:
		return m
	m = NavMover.new()
	m.name = NODE_NAME
	host.add_child(m)
	return m


func _init() -> void:
	# Corners count as reached within a metre: big bodies (wolves, the beast)
	# can't hug them, and the mesh rides a voxel or two above the floor.
	path_desired_distance = 1.0
	target_desired_distance = 0.6
	path_height_offset = 0.4
	path_max_distance = 3.0
	avoidance_enabled = false


func _ready() -> void:
	_host = get_parent() as Node3D


## World-space direction to steer toward `goal` this frame: to the next path
## corner on the navmesh, or straight at the goal when there is no usable mesh.
func steer(goal: Vector3) -> Vector3:
	var from := _host.global_position
	var straight := goal - from
	straight.y = 0.0
	if straight.length() < MIN_DISTANCE or not has_mesh_at(from):
		return straight
	if _goal == Vector3.INF or _goal.distance_to(goal) > RETARGET:
		_goal = goal
		target_position = goal
	if is_navigation_finished():
		return straight
	get_next_path_position()  # keeps the agent's own path and index current
	var next := next_corner(get_current_navigation_path(), get_current_navigation_path_index(), from, path_desired_distance)
	return next if next.length_squared() > 0.0004 else straight


## Flat direction from `from` to the first corner of `path` ahead of him that
## is more than `reach` away on the ground; ZERO when none is. "Ahead" means
## past the path segment he is on (the one nearest him on the ground, from
## `index` on). The agent counts a corner reached by 3D distance, so on steps,
## where the mover's feet ride the treads and the mesh's corner sits on the
## ramp below, a corner right under him was never reached: he steered at his
## own feet and jittered there (the beast on the manor's front step, L86-29).
## Nor may a corner already behind him count: the path's start, a metre back
## once he has set off, turned him round, step for step, on the manor's front
## steps when the arrival started him there (L86-31).
static func next_corner(path: PackedVector3Array, index: int, from: Vector3, reach: float) -> Vector3:
	var start := maxi(index, 0)
	if start >= path.size():
		return Vector3.ZERO
	var on := start
	var nearest := INF
	for i in range(start, path.size() - 1):
		var d := _ground_distance_to_segment(from, path[i], path[i + 1])
		if d < nearest - 0.001:
			nearest = d
			on = i
	var first := on + 1 if path.size() > 1 else on
	for i in range(first, path.size()):
		var to := path[i] - from
		to.y = 0.0
		if to.length() > reach:
			return to
	return Vector3.ZERO


static func _ground_distance_to_segment(p: Vector3, a: Vector3, b: Vector3) -> float:
	var p2 := Vector2(p.x, p.z)
	var a2 := Vector2(a.x, a.z)
	var b2 := Vector2(b.x, b.z)
	var ab := b2 - a2
	var t := clampf((p2 - a2).dot(ab) / ab.length_squared(), 0.0, 1.0) if ab.length_squared() > 1e-6 else 0.0
	return p2.distance_to(a2 + ab * t)


## True when a baked navmesh lies under `point`.
func has_mesh_at(point: Vector3) -> bool:
	var map := get_navigation_map()
	if not map.is_valid() or NavigationServer3D.map_get_iteration_id(map) == 0:
		return false
	return NavigationServer3D.map_get_closest_point(map, point).distance_to(point) <= ON_MESH


## Path length from the mover to `goal` (straight line when off the mesh).
func path_length_to(goal: Vector3) -> float:
	var map := get_navigation_map()
	var from := _host.global_position
	if not has_mesh_at(from):
		return from.distance_to(goal)
	var path := NavigationServer3D.map_get_path(map, from, goal, true)
	var total := 0.0
	for i in range(1, path.size()):
		total += path[i - 1].distance_to(path[i])
	return total
