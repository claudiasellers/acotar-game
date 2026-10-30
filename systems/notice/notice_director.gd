## Soft, optional camera drifts toward notice points while Feyre is still, and
## a sketch when the player holds the look. Any look input cancels the drift
## for a moment: the player is always in charge.
class_name NoticeDirector
extends Node

signal sketch_made(sketch_id: StringName)

## Degrees per second the camera drifts at most.
const DRIFT_SPEED := 6.0
## Within this angle the look counts as "holding".
const HOLD_ANGLE := 9.0
## Seconds after a look input before drifting resumes.
const INPUT_COOLDOWN := 1.5
const IDLE_SPEED := 0.6

var feyre: Feyre
var current: NoticePoint = null
var hold: float = 0.0

var _cooldown: float = 0.0


func _ready() -> void:
	feyre = get_parent() as Feyre


func _process(delta: float) -> void:
	if feyre == null or feyre.camera == null:
		return
	if feyre.look_input_this_frame:
		_cooldown = INPUT_COOLDOWN
	var idle := Vector2(feyre.velocity.x, feyre.velocity.z).length() < IDLE_SPEED \
			and not feyre.is_drawing and not feyre.is_aiming
	var drift := update(delta, feyre.camera.global_transform, get_tree().get_nodes_in_group(NoticePoint.GROUP), idle)
	if drift != Vector2.ZERO:
		feyre.nudge_camera(drift.x, drift.y)


## Picks the point, advances the hold, and returns the camera drift
## (yaw, pitch radians) for this frame. Pure apart from the sketchbook write.
func update(delta: float, camera: Transform3D, points: Array, idle: bool) -> Vector2:
	_cooldown = maxf(_cooldown - delta, 0.0)
	var best: NoticePoint = null
	var best_angle := 180.0
	for p: NoticePoint in points:
		if Gameplay.sketchbook.has(p.sketch_id):
			continue
		if camera.origin.distance_to(p.global_position) > p.radius:
			continue
		var a := angle_to(camera, p.global_position)
		if a <= p.cone_degrees and a < best_angle:
			best = p
			best_angle = a
	if best != current:
		current = best
		hold = 0.0
	if current == null or not idle:
		hold = 0.0
		return Vector2.ZERO
	if best_angle <= HOLD_ANGLE:
		hold += delta
		if hold >= current.look_seconds:
			if Gameplay.sketchbook.add(current.sketch_id, current.title):
				sketch_made.emit(current.sketch_id)
				Juice.burst(current, &"unlock")
			current = null
			hold = 0.0
			return Vector2.ZERO
	if _cooldown > 0.0:
		return Vector2.ZERO
	return drift_toward(camera, current.global_position, deg_to_rad(DRIFT_SPEED) * delta)


## Angle in degrees between the camera's forward and the point.
static func angle_to(camera: Transform3D, point: Vector3) -> float:
	var forward := -camera.basis.z.normalized()
	var to := (point - camera.origin).normalized()
	return rad_to_deg(forward.angle_to(to))


## Yaw/pitch (radians) moving the view toward the point by at most max_step,
## eased so it slows as it arrives.
static func drift_toward(camera: Transform3D, point: Vector3, max_step: float) -> Vector2:
	var forward := -camera.basis.z.normalized()
	var to := (point - camera.origin).normalized()
	var yaw := atan2(-to.x, -to.z) - atan2(-forward.x, -forward.z)
	yaw = wrapf(yaw, -PI, PI)
	var pitch := asin(clampf(to.y, -1.0, 1.0)) - asin(clampf(forward.y, -1.0, 1.0))
	var ease := clampf(Vector2(yaw, pitch).length() / deg_to_rad(10.0), 0.2, 1.0)
	return Vector2(clampf(yaw, -max_step, max_step), clampf(pitch, -max_step, max_step)) * ease
