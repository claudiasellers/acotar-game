## Feyre's hands for loose props (T5). Added as a child of the player body on
## first need (PropField does it when props wake), so no player file changes.
## - Shove: walking into a prop pushes it (impulses from her slide contacts).
## - Lift: interact on a prop (Prop.use) picks it up with a sparkle + chime + bounce.
## - While carrying, interact is hers: tap throws, hold (0.35 s) sets it down
##   gently in front, on top of whatever is there, so props stack.
class_name PropCarrier
extends Node

signal picked_up(prop: Prop)
signal released(prop: Prop, thrown: bool)

const NODE_NAME := "PropCarrier"
## Carry pose relative to her feet: forward of the chest.
const HOLD_UP := 1.05
const HOLD_FORWARD := 0.4
const HOLD_SMOOTH := 18.0
## Throw: horizontal and upward speed for a mass-8 prop; lighter flies further.
const THROW_SPEED := 6.0
const THROW_UP := 3.6
const THROW_REF_MASS := 8.0
## Hold interact this long to set down instead of throwing.
const PLACE_HOLD := 0.35
## Push: acceleration given to a mass-25-or-lighter prop, top speed of a shove.
const PUSH_ACCEL := 30.0
const PUSH_REF_MASS := 25.0
const PUSH_MAX_SPEED := 3.6
## How long a released prop ignores her (so a throw never bonks her).
const IGNORE_SECONDS := 0.35

var body: Node3D
var carrying: Prop
var _press_ms: int = -1


## The carrier on `holder`, created on first use.
static func for_body(holder: Node3D) -> PropCarrier:
	if holder == null:
		return null
	var existing := holder.get_node_or_null(NODE_NAME) as PropCarrier
	if existing:
		return existing
	var c := PropCarrier.new()
	c.name = NODE_NAME
	holder.add_child(c)
	return c


func _ready() -> void:
	body = get_parent() as Node3D
	# After the body's own physics step, so its slide contacts are this frame's.
	process_physics_priority = 10


## Where she faces: her model's forward (-Z), else the body's.
func facing() -> Vector3:
	var node: Node3D = body
	if body and &"model" in body and body.get(&"model") is Node3D:
		node = body.get(&"model")
	var f := -node.global_basis.z if node else Vector3.FORWARD
	f.y = 0.0
	return f.normalized() if f.length_squared() > 0.0001 else Vector3.FORWARD


func pick_up(prop: Prop) -> bool:
	if carrying or prop == null or prop.carried or not prop.data.carryable:
		return false
	carrying = prop
	prop.carried = true
	prop.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	prop.freeze = true
	prop.collision_layer = 0
	if body is PhysicsBody3D:
		prop.add_collision_exception_with(body)
	Juice.burst(prop.mesh_instance, &"pickup", Vector3.ZERO, 1.0)
	if body:
		Juice.bounce(body, 0.06)
	picked_up.emit(prop)
	return true


## Throws what she holds: forward and up, plus her own run speed.
func throw() -> Prop:
	var prop := _let_go()
	if prop == null:
		return null
	var k := clampf(THROW_REF_MASS / maxf(prop.mass, 0.1), 0.6, 1.25)
	var carry_v := Vector3.ZERO
	if body is CharacterBody3D:
		carry_v = (body as CharacterBody3D).velocity
		carry_v.y = 0.0
	prop.linear_velocity = facing() * THROW_SPEED * k + Vector3.UP * THROW_UP * sqrt(k) + carry_v
	prop.angular_velocity = facing().cross(Vector3.UP) * -1.5
	released.emit(prop, true)
	return prop


## Sets it down in front of her, resting on whatever is there (stacking).
func place() -> Prop:
	var prop := carrying
	if prop == null:
		return null
	var front := body.global_position + facing() * (HOLD_FORWARD + prop.radius() + 0.25)
	var ground := _surface_below(front + Vector3.UP * 2.5, prop)
	_let_go()
	prop.global_position = Vector3(front.x, ground + 0.02, front.z)
	prop.linear_velocity = Vector3.ZERO
	prop.angular_velocity = Vector3.ZERO
	released.emit(prop, false)
	return prop


func _let_go() -> Prop:
	var prop := carrying
	if prop == null:
		return null
	carrying = null
	if not is_instance_valid(prop):
		return null
	prop.carried = false
	prop.collision_layer = Prop.WORLD_LAYER
	prop.freeze = false
	prop.sleeping = false
	if body is PhysicsBody3D:
		var b := body as PhysicsBody3D
		get_tree().create_timer(IGNORE_SECONDS).timeout.connect(func() -> void:
			if is_instance_valid(prop) and is_instance_valid(b):
				prop.remove_collision_exception_with(b))
	return prop


func _surface_below(from: Vector3, ignore: Prop) -> float:
	var space := body.get_world_3d().direct_space_state if body and body.is_inside_tree() else null
	if space == null:
		return from.y - 2.5
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 6.0, Prop.WORLD_LAYER)
	var ex: Array[RID] = [ignore.get_rid()]
	if body is CollisionObject3D:
		ex.append((body as CollisionObject3D).get_rid())
	q.exclude = ex
	var hit := space.intersect_ray(q)
	return float(hit.position.y) if hit else from.y - 2.5


func _unhandled_input(event: InputEvent) -> void:
	if carrying == null or not event.is_action(&"interact"):
		return
	get_viewport().set_input_as_handled()
	if event.is_pressed() and not event.is_echo():
		_press_ms = Time.get_ticks_msec()
	elif event.is_released() and _press_ms >= 0:
		var held := (Time.get_ticks_msec() - _press_ms) / 1000.0
		_press_ms = -1
		if held >= PLACE_HOLD:
			place()
		else:
			throw()


func _physics_process(delta: float) -> void:
	if carrying:
		if not is_instance_valid(carrying):
			carrying = null
		else:
			_hold(delta)
	push_contacts(delta)


func _hold(delta: float) -> void:
	var f := facing()
	var target := body.global_position + Vector3.UP * HOLD_UP + f * (HOLD_FORWARD + carrying.radius()) \
			- Vector3.UP * carrying.data.half_height()
	var xf := carrying.global_transform
	xf.origin = xf.origin.lerp(target, clampf(HOLD_SMOOTH * delta, 0.0, 1.0))
	var yaw := atan2(-f.x, -f.z)
	xf.basis = xf.basis.slerp(Basis(Vector3.UP, yaw), clampf(10.0 * delta, 0.0, 1.0)).orthonormalized()
	carrying.global_transform = xf


## Shoves every prop her last move_and_slide ran into.
func push_contacts(delta: float) -> int:
	var cb := body as CharacterBody3D
	if cb == null:
		return 0
	var pushed := 0
	for i in cb.get_slide_collision_count():
		var hit := cb.get_slide_collision(i)
		var prop := hit.get_collider() as Prop
		if prop == null or prop.carried:
			continue
		var dir := -hit.get_normal()
		dir.y = 0.0
		if dir.length_squared() < 0.01:
			continue  # standing on it
		push(prop, dir.normalized(), delta)
		pushed += 1
	return pushed


## One frame of shove along `dir`: light props skid, heavy ones barely creep.
static func push(prop: Prop, dir: Vector3, delta: float) -> void:
	var along := prop.linear_velocity.dot(dir)
	if along >= PUSH_MAX_SPEED:
		return
	var accel := PUSH_ACCEL * clampf(PUSH_REF_MASS / maxf(prop.mass, 0.1), 0.15, 1.0)
	prop.sleeping = false
	prop.apply_central_impulse(dir * prop.mass * accel * delta)
