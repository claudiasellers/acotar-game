## Fades scenery that comes right up against the lens: any small mesh within
## RADIUS of whichever camera is drawing (Feyre's own or a cutscene camera)
## goes see-through, then fades back once the lens moves away. Props such as the
## cottage table, beams and furniture have no collision, so the spring arm can't
## stop for them; this keeps them from filling the frame.
##
## Only meshes no bigger than MAX_SIZE fade (never a room shell, terrain or a
## scatter field) and never Feyre herself. Purely presentational.
##
## With no rendering device (headless: tests, world_smoke, the gate) it does
## nothing at all, unless a test sets `headless_opt_in` before Feyre enters the
## tree; then it looks only at meshes in PROBE_GROUP, never a tree walk.
class_name CameraFade
extends Node

## Tests set this (and clear it after) to run the fade headless.
static var headless_opt_in := false
## Headless opt-in only: the meshes a test offers as candidates.
const PROBE_GROUP := &"camera_fade_probe"

const RADIUS := 0.5
## Largest mesh (longest world AABB side, m) that may fade.
const MAX_SIZE := 3.5
const FADED := 0.85
## Seconds for a full fade in or out.
const FADE_TIME := 0.15

## Meshes currently faded or fading back: instance id -> transparency before we touched it.
var _touched: Dictionary = {}
var _owner_root: Node


func _ready() -> void:
	_owner_root = get_parent()
	if _headless() and not headless_opt_in:
		set_process(false)


static func _headless() -> bool:
	return DisplayServer.get_name() == "headless"


func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null:
		return
	var near := {}
	for g in near_meshes(cam.global_position):
		near[g.get_instance_id()] = g
	var step := delta / FADE_TIME
	for id in near:
		var g: GeometryInstance3D = near[id]
		if not _touched.has(id):
			_touched[id] = g.transparency
		g.transparency = move_toward(g.transparency, maxf(FADED, _touched[id]), step)
	for id in _touched.keys():
		if near.has(id):
			continue
		var g := instance_from_id(id) as GeometryInstance3D
		if g == null:
			_touched.erase(id)
			continue
		var original: float = _touched[id]
		g.transparency = move_toward(g.transparency, original, step)
		if is_equal_approx(g.transparency, original):
			_touched.erase(id)


## Fadeable meshes within RADIUS of `at`.
func near_meshes(at: Vector3) -> Array[GeometryInstance3D]:
	var out: Array[GeometryInstance3D] = []
	for g in _candidates(at):
		if not g.visible or not g.is_visible_in_tree() or g is GPUParticles3D or g is CPUParticles3D:
			continue
		if _owner_root and _owner_root.is_ancestor_of(g):
			continue
		var box := g.global_transform * g.get_aabb()
		if box.size == Vector3.ZERO or maxf(box.size.x, maxf(box.size.y, box.size.z)) > MAX_SIZE:
			continue
		var closest := at.clamp(box.position, box.end)
		if closest.distance_to(at) <= RADIUS:
			out.append(g)
	return out


func _candidates(at: Vector3) -> Array[GeometryInstance3D]:
	var out: Array[GeometryInstance3D] = []
	if _headless():
		# The rendering server keeps no spatial index headless; tests name their meshes.
		for n in get_tree().get_nodes_in_group(PROBE_GROUP):
			if n is GeometryInstance3D:
				out.append(n as GeometryInstance3D)
		return out
	# The scenario's BVH: a 1 m box query, a handful of hits.
	var box := AABB(at - Vector3.ONE * RADIUS, Vector3.ONE * RADIUS * 2.0)
	for id in RenderingServer.instances_cull_aabb(box, get_viewport().world_3d.scenario):
		var g := instance_from_id(id) as GeometryInstance3D
		if g:
			out.append(g)
	return out
