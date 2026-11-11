## Feyre's horizontal movement on the ground and in the air, and which way her
## body faces, kept apart from the controller (T100). Her tuning (run_speed,
## acceleration, braking, turn_friction, air_control, turn_speed) stays on
## Feyre as exports; these read it from her each frame.
class_name GroundMotor
extends RefCounted

## Slowest her running direction turns (rad/s): small corrections still land fast.
const TURN_MIN_RATE := 6.5
## A change of direction wider than this (degrees) is a reversal: she plants and
## pushes off the other way instead of running round in a loop.
const PIVOT_ANGLE := 135.0


## Her horizontal velocity for this frame. With keys held her running
## direction turns toward them at `turn_friction` (exponential, at least
## TURN_MIN_RATE) while keeping her speed, as Unreal's CharacterMovement does,
## so a turn never dips her speed or slides her sideways; a near reversal
## (over PIVOT_ANGLE) plants and pushes off the other way instead. Then the
## speed eases to the target. With no keys she brakes to a stop. In the air
## the same at `air_control` strength: a jump carries her, but she steers.
static func horizontal(f: Feyre, horizontal: Vector3, direction: Vector3, speed: float, sprinting: bool, delta: float) -> Vector3:
	var grounded := f.is_on_floor()
	var control := 1.0 if grounded else f.air_control
	if direction == Vector3.ZERO:
		var brake := f.braking if grounded else f.acceleration * f.run_speed * f.air_control
		return horizontal.move_toward(Vector3.ZERO, brake * delta)
	var size := horizontal.length()
	var want := atan2(-direction.x, -direction.z)
	var target_speed := speed * minf(direction.length(), 1.0)
	var rate := f.acceleration * speed * control
	if sprinting and grounded and size >= f.run_speed * 0.98:
		rate = f.sprint_acceleration
	var heading := atan2(-horizontal.x, -horizontal.z) if size > 0.5 else want
	var diff := angle_difference(heading, want)
	if absf(diff) >= deg_to_rad(PIVOT_ANGLE):
		# A reversal: plant and push off the other way.
		return horizontal.move_toward(Vector3.FORWARD.rotated(Vector3.UP, want) * target_speed, f.acceleration * speed * control * delta)
	var turn := maxf(absf(diff) * minf(delta * f.turn_friction * control, 1.0), TURN_MIN_RATE * control * delta)
	heading += clampf(diff, -turn, turn)
	return Vector3.FORWARD.rotated(Vector3.UP, heading) * move_toward(size, target_speed, rate * delta)


## Faces where she is going (Unreal's "orient rotation to movement"): her
## running direction once she is moving, so her body never runs at an angle
## to her path, else the keys; the camera while aiming or drawing.
static func turn_model(f: Feyre, direction: Vector3, camera_yaw: float, delta: float) -> void:
	var model := f.model
	var aiming := f.is_aiming or f.is_drawing
	var target_yaw := model.rotation.y
	var moving := Vector2(f.velocity.x, f.velocity.z)
	if aiming:
		target_yaw = camera_yaw
	elif moving.length() > 1.0 and (direction != Vector3.ZERO or not f.is_on_floor()):
		target_yaw = atan2(-moving.x, -moving.y)
	elif direction.length_squared() > 0.01:
		target_yaw = atan2(-direction.x, -direction.z)
	var rate := f.turn_speed * (2.0 if moving.length() > 1.0 and not aiming else 1.0)
	model.rotation.y = lerp_angle(model.rotation.y, target_yaw, minf(rate * delta, 1.0))
