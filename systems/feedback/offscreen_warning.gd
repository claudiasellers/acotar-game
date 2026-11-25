## No unseen hits (health-interactions §3.5 #5). When a hostile near her
## starts to wind up an attack from outside the camera's view
## (EventBus.hostile_windup), the HUD's edge on that side beats until it lands
## (VitalsEdgeFx.warn: side -1 hard left .. +1 hard right, 0 straight behind;
## seconds until contact). A wind-up cut short (hostile_windup_cancelled)
## calls the warning off. This is the one caller of that edge.
class_name OffscreenWarning
extends Node

## Wind-ups further off than this are nobody's business yet.
const RADIUS := 12.0

var player: Node3D
## The creature whose unseen wind-up the edge is beating for, or &"".
var _warned: StringName = &""


func _init() -> void:
	name = "OffscreenWarning"


func _ready() -> void:
	Gameplay.listen(&"hostile_windup", _on_windup)
	Gameplay.listen(&"hostile_windup_cancelled", _on_cancelled)


func _on_windup(creature_id: StringName, _kind: StringName, _attack: StringName, at: Vector3, seconds: float) -> void:
	if player == null or not is_inside_tree() or at.distance_to(player.global_position) > RADIUS or in_view(at):
		return
	_warned = creature_id
	VitalsEdgeFx.warn(get_tree(), side_of(at), seconds)


func _on_cancelled(creature_id: StringName) -> void:
	if creature_id == _warned and is_inside_tree():
		_warned = &""
		VitalsEdgeFx.warn(get_tree(), 0.0, 0.0)


## Which side of the view `at` is on: -1 left .. +1 right, 0 straight behind
## (or with no camera to judge by).
func side_of(at: Vector3) -> float:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return 0.0
	var to := at - camera.global_position
	var flat := Vector2(to.dot(camera.global_basis.x), -to.dot(camera.global_basis.z))
	return 0.0 if flat.length() < 0.001 else clampf(flat.normalized().x, -1.0, 1.0)


## Whether the attacker (a point a metre up its body) is on screen.
func in_view(at: Vector3) -> bool:
	var camera := get_viewport().get_camera_3d()
	return camera != null and camera.is_position_in_frustum(at + Vector3.UP)
