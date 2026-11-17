## Getting on and off the white mare as one motion, not a teleport (lane L47-6,
## docs/contracts/mount.md). The vault on: Feyre steps to the mare's near (left)
## side by the saddle, reaches for the pommel and mane, dips, springs, swings
## her right leg back over the croup and settles into the seat; the mare takes
## her weight with a dip. The slide off: the right leg swings back over, she
## slides down the near side and lands with bent knees. A stylised vault, like
## the stirrups hang at a pony rider's hip on this tall mare [X].
##
## Pure timing and placement: MountDirector ticks it each frame while Feyre's
## own physics is off, then hands over to Saddle.place (on) or her own body (off).
class_name MountMotion
extends RefCounted

enum Kind { ON, OFF }

## Seconds for each motion.
const ON_TIME := 1.3
const OFF_TIME := 0.9
## Where she stands to vault: this far out from the mare's spine, on the near side.
const STAND_OUT := 0.72
## How high over the seat her hips arc on the way up (m).
const ARC_LIFT := 0.14
## Knee dip before the spring and on landing (m of hip drop).
const CROUCH := 0.13
## The saddle's give when her weight lands (m), and the mare's.
const SETTLE_DIP := 0.05
const MARE_DIP := 0.045

var kind: Kind = Kind.ON
var t: float = 0.0
var rider: Node3D
var horse: WhiteHorse
var pose: RidePose
var drop: float = 0.88

var _from: Vector3
var _from_yaw: float
var _stand: Vector3
var _face_yaw: float
var _mare_yaw: float
var _landing: Vector3
var _mare_model_y: float = 0.0
var _last_hips: Vector3 = Vector3.INF
## Largest frame-to-frame hip move so far (m), and the fastest her hips
## travelled (m/s), for the no-teleport test.
var max_hip_step: float = 0.0
var max_hip_speed: float = 0.0


static func smooth(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


## 0..1 over [a, b], smoothstepped.
static func seg(x: float, a: float, b: float) -> float:
	return smooth((x - a) / maxf(b - a, 1e-4))


## 0 -> 1 -> 0 over [a, b], peaking in the middle.
static func bell(x: float, a: float, b: float) -> float:
	if x <= a or x >= b:
		return 0.0
	return sin(PI * (x - a) / (b - a))


static func yaw_of(dir: Vector3) -> float:
	return atan2(-dir.x, -dir.z)


func duration() -> float:
	return ON_TIME if kind == Kind.ON else OFF_TIME


func done() -> bool:
	return t >= duration()


## Sets up the vault on. `landing` is ignored; `ground_y` gives the ground under a point.
func begin_on(p_rider: Node3D, p_horse: WhiteHorse, p_pose: RidePose, ground_y: Callable) -> void:
	kind = Kind.ON
	_begin(p_rider, p_horse, p_pose)
	var mare_body := p_horse.get_parent() as Node3D if p_horse.get_parent() is Node3D else p_horse
	var left := -mare_body.global_basis.x
	left.y = 0.0
	left = left.normalized()
	var seat := p_horse.seat_point()
	_stand = Vector3(seat.x, mare_body.global_position.y, seat.z) + left * STAND_OUT
	var gy: float = ground_y.call(_stand.x, _stand.z) if ground_y.is_valid() else NAN
	if not is_nan(gy):
		_stand.y = gy + 0.02
	# She faces the mare's shoulder, half turned to the front.
	var fwd := -mare_body.global_basis.z
	fwd.y = 0.0
	_face_yaw = yaw_of((-left * 0.75 + fwd.normalized() * 0.65).normalized())


## Sets up the slide off to `landing` (ground, beside the near side).
func begin_off(p_rider: Node3D, p_horse: WhiteHorse, p_pose: RidePose, landing: Vector3) -> void:
	kind = Kind.OFF
	_begin(p_rider, p_horse, p_pose)
	_landing = landing
	var mare_body := p_horse.get_parent() as Node3D if p_horse.get_parent() is Node3D else p_horse
	var left := -mare_body.global_basis.x
	left.y = 0.0
	var fwd := -mare_body.global_basis.z
	fwd.y = 0.0
	_face_yaw = yaw_of((-left.normalized() * 0.6 + fwd.normalized() * 0.8).normalized())


func _begin(p_rider: Node3D, p_horse: WhiteHorse, p_pose: RidePose) -> void:
	rider = p_rider
	horse = p_horse
	pose = p_pose
	t = 0.0
	max_hip_step = 0.0
	max_hip_speed = 0.0
	_last_hips = Vector3.INF
	drop = float(rider.get_meta(Saddle.HIP_DROP, 0.88))
	_from = rider.global_position
	var model := rider.get(&"model") as Node3D
	_from_yaw = model.global_rotation.y if model else rider.global_rotation.y
	_mare_yaw = horse.global_rotation.y
	_mare_model_y = horse.model.position.y if horse.model else 0.0


## Advances the motion and places her. True while it still runs.
func tick(delta: float) -> bool:
	if rider == null or horse == null or not is_instance_valid(rider) or not is_instance_valid(horse):
		return false
	t = minf(t + delta, duration())
	_mare_yaw = horse.global_rotation.y
	var hips: Vector3
	var yaw: float
	if kind == Kind.ON:
		var r := _on(t)
		hips = r[0]
		yaw = r[1]
	else:
		var r := _off(t)
		hips = r[0]
		yaw = r[1]
	rider.global_position = hips - Vector3.UP * drop
	var model := rider.get(&"model") as Node3D
	if model:
		model.global_rotation = Vector3(0.0, yaw, 0.0)
	if _last_hips != Vector3.INF:
		max_hip_step = maxf(max_hip_step, hips.distance_to(_last_hips))
		if delta > 0.0:
			max_hip_speed = maxf(max_hip_speed, hips.distance_to(_last_hips) / delta)
	_last_hips = hips
	if done() and pose:
		pose.clear_overrides()
	return not done()


func _stand_hips(at: Vector3, crouch: float) -> Vector3:
	return at + Vector3.UP * (drop - crouch)


## The vault on: [hips, yaw] at time `x` (s).
func _on(x: float) -> Array:
	var seat := horse.seat_point()
	var u := x / ON_TIME
	# 0..0.26 step in and reach; 0.26..0.36 dip; 0.36..0.66 spring and swing; 0.66..1 settle.
	var step := seg(u, 0.0, 0.26)
	var crouch := CROUCH * seg(u, 0.18, 0.34) * (1.0 - seg(u, 0.36, 0.46))
	var ground_hips := _stand_hips(_from.lerp(_stand, step), crouch)
	var hips := ground_hips
	var yaw := lerp_angle(_from_yaw, _face_yaw, seg(u, 0.0, 0.22))
	var rise := seg(u, 0.36, 0.66)
	if u > 0.36:
		var a := _stand_hips(_stand, crouch)
		var top := maxf(a.y, seat.y) + ARC_LIFT
		# Quadratic arc: up past the seat's height beside her, then in over it.
		var ctrl := Vector3(lerpf(a.x, seat.x, 0.3), top, lerpf(a.z, seat.z, 0.3))
		var s := rise
		hips = a.lerp(ctrl, s).lerp(ctrl.lerp(seat, s), s)
		yaw = lerp_angle(_face_yaw, _mare_yaw, seg(u, 0.4, 0.7))
	if u >= 0.66:
		hips = seat - Vector3.UP * SETTLE_DIP * bell(u, 0.66, 0.92)
		yaw = _mare_yaw
	# The mare takes her weight.
	if horse.model:
		horse.model.position.y = _mare_model_y - MARE_DIP * bell(u, 0.64, 0.95)
	if pose:
		pose.amount = seg(u, 0.5, 0.72)
		var reach := seg(u, 0.05, 0.25) * (1.0 - seg(u, 0.62, 0.8))
		# Hands up to the pommel and mane, then pushing down as she rises over.
		var push := seg(u, 0.38, 0.55)
		for arm: StringName in [&"LeftUpperArm", &"RightUpperArm"]:
			pose.set_override(arm, lerpf(0.75, 0.35, push), lerpf(0.45, -0.9, push), lerpf(0.05, 0.22, push), reach)
		for arm: StringName in [&"LeftLowerArm", &"RightLowerArm"]:
			pose.set_override(arm, lerpf(0.9, 0.5, push), lerpf(0.25, -0.75, push), -0.15, reach)
		# The dip: knees bend.
		var dip := seg(u, 0.16, 0.32) * (1.0 - seg(u, 0.36, 0.48))
		var swing := bell(u, 0.38, 0.74)
		var tuck := bell(u, 0.36, 0.7)
		pose.set_override(&"RightUpperLeg", lerpf(0.55, -0.55, swing), lerpf(-0.85, 0.35, swing), lerpf(0.1, 0.85, swing), maxf(dip, swing))
		pose.set_override(&"RightLowerLeg", lerpf(-0.45, -0.75, swing), lerpf(-0.9, -0.1, swing), lerpf(0.0, 0.55, swing), maxf(dip, swing))
		pose.set_override(&"LeftUpperLeg", lerpf(0.55, 0.8, tuck), lerpf(-0.85, -0.35, tuck), lerpf(0.1, 0.5, tuck), maxf(dip, tuck))
		pose.set_override(&"LeftLowerLeg", lerpf(-0.45, -0.3, tuck), -0.9, 0.15, maxf(dip, tuck))
	return [hips, yaw]


## The slide off: [hips, yaw] at time `x` (s).
func _off(x: float) -> Array:
	var seat := horse.seat_point()
	var u := x / OFF_TIME
	var land := _stand_hips(_landing, CROUCH * 1.4 * bell(u, 0.45, 1.0))
	var hips := seat
	var yaw := _mare_yaw
	# 0..0.18 shift and lift the leg; 0.18..0.6 over and down; 0.6..1 land and rise.
	if u > 0.14:
		var s := seg(u, 0.14, 0.6)
		var ctrl := Vector3(lerpf(seat.x, _landing.x, 0.55), seat.y + 0.12, lerpf(seat.z, _landing.z, 0.55))
		var end := land
		hips = seat.lerp(ctrl, s).lerp(ctrl.lerp(end, s), s)
		yaw = lerp_angle(_mare_yaw, _face_yaw, seg(u, 0.15, 0.55))
	if u >= 0.6:
		hips = land
		yaw = lerp_angle(_face_yaw, _mare_yaw + 0.35, seg(u, 0.7, 1.0))
	if horse.model:
		horse.model.position.y = _mare_model_y + 0.03 * bell(u, 0.4, 0.75)
	if pose:
		pose.amount = 1.0 - seg(u, 0.25, 0.6)
		var swing := bell(u, 0.05, 0.55)
		pose.set_override(&"RightUpperLeg", -0.55, 0.3, 0.85, swing)
		pose.set_override(&"RightLowerLeg", -0.7, -0.15, 0.55, swing)
		var hold := seg(u, 0.05, 0.2) * (1.0 - seg(u, 0.55, 0.75))
		for arm: StringName in [&"LeftUpperArm", &"RightUpperArm"]:
			pose.set_override(arm, 0.45, -0.75, 0.2, hold)
		var bend := bell(u, 0.55, 1.0)
		for leg: StringName in [&"LeftUpperLeg", &"RightUpperLeg"]:
			if leg == &"RightUpperLeg" and swing > bend:
				continue
			pose.set_override(leg, 0.55, -0.85, 0.12, bend)
		for leg: StringName in [&"LeftLowerLeg", &"RightLowerLeg"]:
			if leg == &"RightLowerLeg" and swing > bend:
				continue
			pose.set_override(leg, -0.45, -0.9, 0.0, bend)
	return [hips, yaw]


## Puts the mare's model back where it was (if the motion is cut short).
func restore_mare() -> void:
	if horse and is_instance_valid(horse) and horse.model:
		horse.model.position.y = _mare_model_y
