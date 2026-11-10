## A solid body for a person standing or walking in the world (T092): a
## capsule on the actors layer, so Feyre (and the mare she rides) bump into
## people and slide off them like a wall or a prop, instead of walking through.
##
## Attach one under any person's root node (CourtNpc, FamilyMember,
## PresenceActor, StandIns' story figures). It follows its parent, never moves
## anything itself and masks nothing, so people never snag on each other or on
## furniture. Walking creatures put LAYER on their own CharacterBody3D instead.
##
## Feyre's ray probes (ledges, steps, aim) stay world-only, so she never climbs
## onto a head. The navmesh bakes the world layer only, so people leave no holes.
## Nobody ever traps her (a doorway, a corridor, a story mark): after
## SQUEEZE_TIME of her pushing into someone, they let her squeeze past, and are
## solid again once she is clear.
## The camera does not collide with people; CameraFade hides a person whole
## while the lens is inside them (`lens_inside`) and never fades one part by part.
class_name ActorBody
extends AnimatableBody3D

## Layer 7. Feyre, the white mare and walking creatures' bodies use it.
const LAYER := 1 << 6
## Every ActorBody, for CameraFade.
const GROUP := &"actor_body"
## Meta on the person's root: CameraFade leaves everything under it alone.
const ROOT_META := &"actor_body_root"

const RADIUS := 0.3
const HEIGHT := 1.75
## A walker waits this long for Feyre to step out of its way, then walks on.
const YIELD_TIME := 1.5
## Seconds of Feyre pushing into a person before they let her squeeze past.
const SQUEEZE_TIME := 1.0
## Feyre's capsule radius (characters/feyre/feyre.gd _build_body).
const FEYRE_RADIUS := 0.3

var radius: float = RADIUS
var height: float = HEIGHT
var shape_node: CollisionShape3D
var _want_solid: bool = true
## Letting her squeeze past (see SQUEEZE_TIME).
var squeezing: bool = false
var _pushed: float = 0.0
var _unpushed: float = 0.0


## Puts a person-sized capsule under `root` (its feet at root's origin).
static func attach(root: Node3D, body_radius: float = RADIUS, body_height: float = HEIGHT) -> ActorBody:
	var existing := find_on(root)
	if existing:
		return existing
	var body := ActorBody.new()
	body.name = "ActorBody"
	body.radius = body_radius
	body.height = body_height
	root.set_meta(ROOT_META, true)
	root.add_child(body)
	return body


## The ActorBody directly under `root`, or null.
static func find_on(root: Node) -> ActorBody:
	if root == null:
		return null
	for c in root.get_children():
		if c is ActorBody:
			return c as ActorBody
	return null


## True when `node` belongs to a person with an ActorBody (it or an ancestor
## carries ROOT_META).
static func is_actor_part(node: Node) -> bool:
	var n := node
	while n != null:
		if n.has_meta(ROOT_META):
			return true
		n = n.get_parent()
	return false


## For walkers that move themselves: true when Feyre stands in the way
## of a step along `dir` from `from` (within both radii plus a hand's width,
## ahead of the walker). Walkers skip the step while this holds, up to YIELD_TIME.
static func player_blocks(tree: SceneTree, from: Vector3, dir: Vector3, body_radius: float = RADIUS) -> bool:
	if tree == null:
		return false
	var feyre := tree.get_first_node_in_group(&"player") as Node3D
	if feyre == null or not feyre.is_inside_tree():
		return false
	var to := feyre.global_position - from
	to.y = 0.0
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length_squared() < 0.000001:
		return false
	return to.length() < body_radius + 0.3 + 0.12 and to.dot(flat.normalized()) > 0.0


func _init() -> void:
	collision_layer = LAYER
	collision_mask = 0
	sync_to_physics = false
	input_ray_pickable = false


func _ready() -> void:
	add_to_group(GROUP)
	shape_node = CollisionShape3D.new()
	shape_node.name = "Capsule"
	var cap := CapsuleShape3D.new()
	cap.radius = radius
	cap.height = maxf(height, radius * 2.0)
	shape_node.shape = cap
	shape_node.position.y = cap.height * 0.5
	add_child(shape_node)
	_refresh()


## Off while the person is away or lying down. A hidden person is never solid either.
func set_solid(on: bool) -> void:
	_want_solid = on
	_refresh()


func is_solid() -> bool:
	return _want_solid and not squeezing and is_visible_in_tree()


func _physics_process(delta: float) -> void:
	var feyre := get_tree().get_first_node_in_group(&"player") as CharacterBody3D
	if feyre == null:
		return
	var to := feyre.global_position - global_position
	var flat := Vector2(to.x, to.z).length()
	if squeezing:
		if flat > radius + FEYRE_RADIUS + 0.25:
			squeezing = false
			_pushed = 0.0
			_refresh()
		return
	if flat > radius + FEYRE_RADIUS + 0.2:
		_pushed = 0.0
		return
	var pushing := false
	for i in feyre.get_slide_collision_count():
		if feyre.get_slide_collision(i).get_collider() == self:
			pushing = true
			break
	if pushing:
		_pushed += delta
		_unpushed = 0.0
	else:
		_unpushed += delta
		if _unpushed > 0.3:
			_pushed = 0.0
	if _pushed >= SQUEEZE_TIME:
		squeezing = true
		_refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		_refresh()


func _refresh() -> void:
	if shape_node:
		shape_node.set_deferred(&"disabled", not is_solid())


## True when `point` (a camera lens) is inside the capsule, grown by `margin`.
func lens_inside(point: Vector3, margin: float = 0.2) -> bool:
	if not is_solid():
		return false
	var base := global_position + Vector3.UP * radius
	var top := global_position + Vector3.UP * (maxf(height, radius * 2.0) - radius)
	var closest := Geometry3D.get_closest_point_to_segment(point, base, top)
	return closest.distance_to(point) <= radius + margin
