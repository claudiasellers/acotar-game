## Camera-relative steering, the way shipped third-person games do it (Unity's
## Starter Assets ThirdPersonController, Unreal's third-person template): the
## move keys point her relative to where the camera looks. Two refinements:
## - The player's own look (mouse, right stick) steers live, as in those games,
##   only with the "Turning the camera steers her while moving" setting on. Off
##   (the default, the owner's ask), the keys alone steer her mid-stride.
## - Camera moves the player didn't make (follow-behind while sprinting, story
##   glances, the R recentre) don't steer: the frame is held while the keys stay
##   the same, so the camera swinging behind her can't spiral her into a circle.
##   Pressing a different direction (or letting go) takes the camera's frame
##   again, like the "hold the input frame until the stick changes" rule fixed-
##   and auto-camera games use across camera changes.
## Aiming and drawing (`live`) follow the camera exactly, for strafing a shot.
## Feyre on foot and the mare under her each keep their own frame.
class_name SteerFrame
extends RefCounted

## A new key combination (stick turned this far, radians) takes the camera's frame.
const RESYNC := 0.35

var _held: bool = false
var _yaw: float = 0.0
var _input := Vector2.ZERO
var _auto0: float = 0.0


## The yaw to rotate `input` by this frame. `auto_yaw` is the running total of
## camera turns that must not steer (Feyre.steer_exclusion()); only those are
## taken back out of the camera's yaw.
func yaw(input: Vector2, camera_yaw: float, auto_yaw: float = 0.0, live: bool = false) -> float:
	if input == Vector2.ZERO or live:
		_held = false
		return camera_yaw
	if not _held or absf(input.angle_to(_input)) > RESYNC:
		_held = true
		_input = input
		_auto0 = auto_yaw
	_yaw = wrapf(camera_yaw - (auto_yaw - _auto0), -PI, PI)
	return _yaw


## Forget the held frame (a teleport; a test bot steering by the camera).
func release() -> void:
	_held = false


func is_held() -> bool:
	return _held


## The frame the keys are steering in (meaningful while is_held()).
func held_yaw() -> float:
	return _yaw
