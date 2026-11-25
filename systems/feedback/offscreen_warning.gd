## Watches the hostiles near her for wind-ups (health-interactions §3.5 #5:
## no unseen hits). When one that is outside the camera's view starts to wind
## up an attack, the HUD's edge on that side beats until it lands
## (VitalsEdgeFx.warn: side -1 hard left .. +1 hard right, 0 straight behind;
## seconds until contact, the attack row's windup_s). A wind-up cut short (a
## stagger, a kill) calls the warning off.
class_name OffscreenWarning
extends Node

## Wind-ups further off than this are nobody's business yet.
const RADIUS := 12.0

var player: Node3D
## Creature instance id -> the attack it was winding up when last looked at.
var _seen: Dictionary = {}
## Creature instance id -> game seconds its warned blow lands at.
var _warned: Dictionary = {}
var _clock: float = 0.0


func _init() -> void:
	name = "OffscreenWarning"


func _physics_process(delta: float) -> void:
	watch(delta)


## One look at every hostile near her: warns of each wind-up that began since
## the last look and can't be seen, and calls off one that stopped early.
func watch(delta: float = 0.0) -> void:
	_clock += delta
	var now := {}
	for c in winding(RADIUS):
		var id := c.get_instance_id()
		var attack := c.winding_up()
		now[id] = attack
		if _seen.get(id, &"") != attack and not _in_view(c):
			var row := AttackTable.resolve(attack)
			var seconds := row.windup_s if row else 0.0
			_warned[id] = _clock + seconds
			warn(side_of(c.global_position), seconds)
	for id: int in _warned.keys():
		if now.has(id):
			continue
		# Gone quiet well before its blow was due: it was stopped.
		if _clock < float(_warned[id]) - 0.1:
			warn(0.0, 0.0)
		_warned.erase(id)
	_seen = now


## The one call to the HUD's edge.
func warn(side: float, seconds: float) -> void:
	VitalsEdgeFx.warn(get_tree(), side, seconds)


## The living creatures within `radius` of her that are winding up an attack.
func winding(radius: float) -> Array[Creature]:
	var out: Array[Creature] = []
	var her := _her()
	if her == null:
		return out
	for node in get_tree().get_nodes_in_group(Creature.GROUP):
		var c := node as Creature
		if c and c.alive and c.winding_up() != &"" and c.global_position.distance_to(her.global_position) <= radius:
			out.append(c)
	return out


## Which side of the view `at` is on: -1 left .. +1 right, 0 straight behind
## (or with no camera to judge by).
func side_of(at: Vector3) -> float:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return 0.0
	var to := at - camera.global_position
	var flat := Vector2(to.dot(camera.global_basis.x), -to.dot(camera.global_basis.z))
	return 0.0 if flat.length() < 0.001 else clampf(flat.normalized().x, -1.0, 1.0)


func _in_view(c: Creature) -> bool:
	var camera := get_viewport().get_camera_3d()
	return camera != null and camera.is_position_in_frustum(c.global_position + Vector3.UP * c.data.body_height * 0.5)


func _her() -> Node3D:
	if player == null or not is_instance_valid(player) or not player.is_inside_tree():
		player = get_tree().get_first_node_in_group(&"player") as Node3D
	return player
