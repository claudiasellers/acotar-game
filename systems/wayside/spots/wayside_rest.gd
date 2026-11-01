## A painter's rest [X, on-voice per the Keeper]: a seat with a view. Press
## interact and the camera eases round to the view she would paint, and she
## names its colours the way she does (ch 7: "purple so deep it could have
## been black"). The first time, a sketch goes in the book. Coming back just
## frames the view again.
class_name WaysideRest
extends WaysideSpotNode

const EASE_SECONDS := 1.6

var station_id := &"wayside_rest"
var _easing := 0.0
var _feyre: Feyre


func build() -> void:
	add_to_group(&"station")
	add_model(StringName(spot.param("seat", "rock_mossy_b")), Vector3.ZERO, 0.0, float(spot.param("seat_scale", 1.0)))


func use(user: Node) -> void:
	_feyre = user as Feyre
	_easing = EASE_SECONDS
	if not found():
		complete()
	else:
		FindCard.note(get_tree(), String(spot.param("again", "Still worth the looking.")))


func _process(delta: float) -> void:
	update_prompt()
	if _easing <= 0.0 or _feyre == null or not is_instance_valid(_feyre):
		return
	if _feyre.look_input_this_frame:
		_easing = 0.0
		return
	_easing -= delta
	var yaw_err := wrapf(view_yaw(_feyre.global_position) - _feyre.camera_yaw(), -PI, PI)
	var pitch_err := view_pitch(_feyre.global_position) - _feyre.camera_pitch()
	var k := clampf(delta * 3.0, 0.0, 1.0)
	_feyre.nudge_camera(yaw_err * k, pitch_err * k)


## Camera yaw that faces the view from `from` (Feyre's camera convention).
func view_yaw(from: Vector3) -> float:
	var to := spot.target - from
	return atan2(-to.x, -to.z)


func view_pitch(from: Vector3) -> float:
	var to := spot.target - from
	return clampf(atan2(to.y - 1.6, Vector2(to.x, to.z).length()), -0.35, 0.25)
