## Base for the P6 scenes (lane L46): Act2Space's staging (marks, lines,
## cast, fades) plus what these chapters need: props from art/p6/, marks
## snapped to the ground outdoors, a gaze test, and day-stamped facts so a
## scene can wait for "the next morning".
class_name Act6Space
extends Act2Space

const PROP_DIR := "res://art/p6/"

## Tests replace how Feyre's view is read: returns [origin, forward].
var gaze_override: Callable
## Props this scene placed (id -> MeshInstance3D).
var props: Dictionary = {}


## The ground under a world point (physics ray from above, then the point).
func snap(p: Vector3, from_above: float = 4.0) -> Vector3:
	if not is_inside_tree():
		return p
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * from_above, p + Vector3.DOWN * 30.0)
	var pl := player()
	if pl is CollisionObject3D:
		q.exclude = [(pl as CollisionObject3D).get_rid()]
	var hit := space.intersect_ray(q)
	return hit.position if not hit.is_empty() else p


## A stage mark on the ground (outdoor marks).
func ground_mark(mark_name: StringName) -> Vector3:
	return snap(mark(mark_name))


## Places a P6 prop (art/p6/<id>.glb, LOD1 past 30 m) at a world point.
func prop(id: StringName, at: Vector3, yaw: float = 0.0, s: float = 1.0) -> MeshInstance3D:
	var pair := PropModels.pair(PROP_DIR + String(id) + ".glb", String(id))
	if pair.is_empty():
		push_warning("Act6Space: no prop %s" % id)
		return null
	var mi := MeshInstance3D.new()
	mi.name = String(id).to_pascal_case()
	mi.mesh = pair[0]
	add_child(mi)
	mi.global_transform = Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s), at)
	if pair[1] != null:
		mi.visibility_range_end = 30.0
		var lod := MeshInstance3D.new()
		lod.name = mi.name + "Lod1"
		lod.mesh = pair[1]
		lod.visibility_range_begin = 30.0
		lod.visibility_range_end = 140.0
		mi.add_child(lod)
	props[id] = mi
	return mi


## Feyre's view: [origin, forward] from the active camera.
func view() -> Array:
	if gaze_override.is_valid():
		return gaze_override.call()
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null:
		return [Vector3.ZERO, Vector3.FORWARD]
	return [cam.global_position, -cam.global_transform.basis.z]


## True while Feyre looks within `cone` degrees of a world point.
func looking_at_point(p: Vector3, cone: float = 14.0) -> bool:
	var v := view()
	var to := p - (v[0] as Vector3)
	if to.length() < 0.01:
		return true
	return rad_to_deg((v[1] as Vector3).angle_to(to.normalized())) <= cone


## A fact stamped with today's day number (WorldState holds the value).
func stamp(fact: String) -> void:
	WorldState.set_flag(fact + ".day", Clock.day)
	raise(fact)


## True once the Clock has passed into a later day than the fact's stamp.
static func day_after(fact: String) -> bool:
	if not WorldState.has_flag(fact):
		return false
	var v: Variant = WorldState.get_flag(fact + ".day")
	return typeof(v) != TYPE_INT or Clock.day > int(v)


## Beat: holds until Feyre has looked at `p` (a Callable giving a world
## point) for `seconds` in total.
func gaze_hold(target: Callable, seconds: float, cone: float = 14.0, label: String = "look") -> SceneBeat:
	return GazeBeat.new(self, target, seconds, cone, label)


class GazeBeat:
	extends SceneBeat
	var space: Act6Space
	var target: Callable
	var seconds: float
	var cone: float
	var held: float = 0.0

	func consumes_time() -> bool:
		return true

	func _init(s: Act6Space, t: Callable, sec: float, c: float, l: String) -> void:
		space = s
		target = t
		seconds = sec
		cone = c
		label = l

	func enter(_s: SceneSpace) -> void:
		held = 0.0

	func tick(_s: SceneSpace, delta: float) -> bool:
		if space.looking_at_point(target.call() as Vector3, cone):
			held += delta
		return held >= seconds


## Takes Feyre to an anchor: at once when it is loaded, else through
## StoryDirector's travel (streams the region in and sets her on the anchor).
func go_to(region_id: StringName, anchor_id: StringName, offset: Vector3 = Vector3.ZERO) -> void:
	var a := find_anchor(anchor_id)
	if a:
		place_feyre(a.global_transform * offset)
	elif WorldStreamer.get_region(region_id) != null:
		EventBus.travel_requested.emit(region_id, anchor_id)


## Beat: waits for an E press within `radius` of a world point (a Callable).
func press_near(at: Callable, radius: float, label: String = "press") -> SceneBeat:
	var base := [-1]
	return Beats.until(func() -> bool:
		if base[0] < 0:
			base[0] = presses()
		if presses() <= base[0]:
			return false
		if player_within(radius, at.call() as Vector3):
			return true
		base[0] = presses()
		return false, label)
