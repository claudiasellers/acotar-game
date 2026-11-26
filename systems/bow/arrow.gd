## A real arrow: a rigid body that flies straight for its bow's true range and
## then on a ballistic arc with drag and wind (Ballistics), turns to face its
## velocity, and sticks into what it hits so it can be pulled back out. World
## geometry stops its point; a creature is struck if the shaft passes within
## CATCH_RADIUS of its body. Wet fletching flies short; arrows that hit stone can break.
class_name Arrow
extends RigidBody3D

const ArrowModel := preload("res://systems/bow/arrow_model.gd")

signal hit(collider: Node, at: Vector3)
signal broke(at: Vector3)

const LENGTH := 0.75
const LAYER_ARROWS := 1 << 2
const MASK_WORLD_AND_TARGETS := (1 << 0) | (1 << 3)
const MASK_TARGETS := 1 << 3
## How near a creature's body (m) the arrow's line may pass and still strike
## it. The camera's aim point reaches for creatures by the same margin.
const CATCH_RADIUS := 0.15
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
## Seconds in the air, and the straight flight it was loosed with (launch).
var _flown: float = 0.0
var _true_flight_s: float = 0.0
var _gravity_blend_s: float = 0.0
var _gravity: float = 9.8
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

	# One shared ArrowModel mesh (F44): shaft, nock, steel head and vanes, so
	# an arrow in flight or stuck in a wolf is never a primitive grey box.
	var model := MeshInstance3D.new()
	model.name = "ArrowModel"
	model.mesh = ArrowModel.mesh(LENGTH, LENGTH * 0.5, arrow.data.shaft_color, arrow.data.fletching_color, ArrowModel.STEEL)
	arrow.add_child(model)
	return arrow


func _ready() -> void:
	mass = data.mass
	# It touches nothing as a body: the sweep below is the one way it hits.
	collision_layer = LAYER_ARROWS
	collision_mask = 0
	# Gravity is Ballistics' to apply, so the straight part of the flight is straight.
	gravity_scale = 0.0
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	_wind_source = get_tree().get_first_node_in_group(&"wind_source")


## What a hit carries for whatever it strikes (read in on_arrow_hit and
## on_arrow_effect), as meta on the arrow:
##   impact         Vector3, global: where it actually struck
##   impact_normal  Vector3: the surface's normal there
##   direction      Vector3, unit: its flight direction at the hit
##   speed          float, m/s: the speed it left the bow at
##   bow_id         StringName: the BowData that loosed it (&"" if none)
## `true_flight_s` and `gravity_blend_s` are Ballistics.gravity_share's hold
## and blend: the bow gives them; an arrow launched without flies a plain arc.
func launch(from: Vector3, direction: Vector3, speed: float, is_wet: bool = false,
		bow_id: StringName = &"", true_flight_s: float = 0.0, gravity_blend_s: float = 0.0) -> void:
	wet = is_wet
	_flown = 0.0
	_true_flight_s = true_flight_s
	_gravity_blend_s = gravity_blend_s
	if wet:
		speed *= data.wet_speed_multiplier
	set_meta(&"speed", speed)
	set_meta(&"bow_id", bow_id)
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
	_flown += state.step
	state.linear_velocity = Ballistics.step(state.linear_velocity, wind, drag(), _gravity, state.step,
			Ballistics.gravity_share(_flown, _true_flight_s, _gravity_blend_s))
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


## How it hits anything: from last frame's position to the tip now, a ray
## against the world and creatures, so a fast arrow can't skip through thin
## colliders or a terrain heightfield (F4), and a ball CATCH_RADIUS wide against
## creatures alone, so a shot that brushes past a hare's flank is a hit.
## Whichever it meets first is what it strikes.
func _sweep() -> void:
	var tip := global_position + linear_velocity.normalized() * LENGTH * 0.5
	if _last_pos == Vector3.INF or not is_inside_tree():
		_last_pos = global_position
		return
	var exclude: Array[RID] = [get_rid()]
	for body in get_collision_exceptions():
		exclude.append(body.get_rid())
	var space := get_world_3d().direct_space_state
	var from := _last_pos
	_last_pos = global_position
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, tip, MASK_WORLD_AND_TARGETS, exclude))
	var body := hit.get("collider") as CollisionObject3D
	if body == null or body.collision_layer & MASK_TARGETS == 0:
		# Its point found no creature: one it passes close by, before whatever
		# the point did find, is struck all the same.
		var reach := from.distance_to(hit.position) if hit else from.distance_to(tip)
		var caught := Arrow.catch_creature(space, from, from + (tip - from).normalized() * reach, exclude)
		if caught:
			hit = caught
	if hit.is_empty():
		return
	var dir := linear_velocity.normalized()
	_note_impact(hit.position, hit.normal, dir)
	global_position = hit.position - dir * LENGTH * 0.35
	linear_velocity = Vector3.ZERO
	_strike(hit.collider as Node)


## The first creature a ball CATCH_RADIUS wide meets on its way from `from`
## to `to`: {"position" on its body, "normal", "collider"}, or {} if none.
static func catch_creature(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3,
		exclude: Array[RID] = []) -> Dictionary:
	if from.is_equal_approx(to):
		return {}
	var ball := SphereShape3D.new()
	ball.radius = CATCH_RADIUS
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = ball
	query.collision_mask = MASK_TARGETS
	query.exclude = exclude
	query.transform = Transform3D(Basis(), from)
	query.motion = to - from
	var travel := space.cast_motion(query)
	if travel[1] >= 1.0:
		return {}
	# Where the ball rests against the body: a little past the last free spot.
	var at := from + (to - from) * travel[1]
	query.transform = Transform3D(Basis(), at)
	query.motion = Vector3.ZERO
	query.margin = 0.04
	var rest := space.get_rest_info(query)
	if rest.is_empty():
		return {}
	return {"position": rest.point, "normal": rest.normal, "collider": instance_from_id(rest.collider_id)}


func _strike(body: Node) -> void:
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


func _note_impact(at: Vector3, normal: Vector3, direction: Vector3) -> void:
	set_meta(&"impact", at)
	set_meta(&"impact_normal", normal)
	set_meta(&"direction", direction)


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
	ArrowGlimmer.attach(self, body)


func _face(direction: Vector3) -> void:
	basis = _basis_facing(direction)


static func _basis_facing(direction: Vector3) -> Basis:
	var forward := direction.normalized()
	var up := Vector3.UP if absf(forward.dot(Vector3.UP)) < 0.98 else Vector3.FORWARD
	return Basis.looking_at(forward, up)
