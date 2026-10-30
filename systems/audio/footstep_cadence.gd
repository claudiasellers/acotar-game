## Turns Feyre's ground travel into footfalls. Stride length grows with speed
## (walk ~0.75 m, run ~1.4 m, sprint ~2 m per step), so steps keep pace with
## the stride-warped gaits without reading the animation.
class_name FootstepCadence
extends RefCounted

const MIN_SPEED := 0.4

var _travel: float = 0.0


static func stride_length(speed: float) -> float:
	return clampf(0.55 + speed * 0.15, 0.6, 2.1)


## Distance moved this frame on the ground; returns true when a foot lands.
func advance(distance: float, speed: float, on_floor: bool) -> bool:
	if not on_floor or speed < MIN_SPEED:
		_travel = minf(_travel, stride_length(speed) * 0.5)
		return false
	_travel += distance
	var stride := stride_length(speed)
	if _travel >= stride:
		_travel = fmod(_travel, stride)
		return true
	return false


## Louder for faster gaits: walk -6 dB, sprint 0 dB.
static func loudness_db(speed: float) -> float:
	return lerpf(-6.0, 0.0, clampf((speed - 1.5) / 8.0, 0.0, 1.0))
