## The move keys steer; the camera only shows the way. The frame the keys
## steer in is the camera's yaw when she starts moving, held while any move key
## (or the stick) stays down, so turning the camera mid-stride never swings her
## path. Letting go of the keys frees it: the next press steers from wherever
## the camera looks then. `live` frames (aiming, drawing) follow the camera,
## so she still strafes around a shot.
##
## Feyre on foot and the mare under her each keep their own frame.
class_name SteerFrame
extends RefCounted

var _held: bool = false
var _yaw: float = 0.0


## The yaw to rotate `input` by this frame.
func yaw(input: Vector2, camera_yaw: float, live: bool = false) -> float:
	if input == Vector2.ZERO or live:
		_held = false
		return camera_yaw
	if not _held:
		_held = true
		_yaw = camera_yaw
	return _yaw


## Forget the held frame (a teleport, a cutscene taking her).
func release() -> void:
	_held = false


func is_held() -> bool:
	return _held
