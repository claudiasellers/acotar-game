## Watches the hostiles near her for wind-ups (health-interactions §3.5 #5:
## no unseen hits). When one that is outside the camera's view starts to wind
## up an attack, `warned` says which side it is on and how long until contact,
## so the HUD's edge can pulse there (L77).
class_name OffscreenWarning
extends Node

## side: -1 hard left .. +1 hard right of the camera, 0 straight behind.
## seconds: until the blow lands (the attack row's windup_s).
signal warned(side: float, seconds: float)

const NODE := "OffscreenWarning"
## Wind-ups further off than this are nobody's business yet.
const RADIUS := 12.0

var player: Node3D
## Creature instance id -> the attack it was winding up when last looked at.
var _seen: Dictionary = {}


static func of(tree: SceneTree) -> OffscreenWarning:
	var found := tree.root.get_node_or_null(NODE) as OffscreenWarning
	if found == null:
		found = OffscreenWarning.new()
		found.name = NODE
		tree.root.add_child(found)
	return found


func _physics_process(_delta: float) -> void:
	watch()


## One look at every hostile near her. Emits `warned` for each wind-up that
## began since the last look and can't be seen.
func watch() -> void:
	var now := {}
	for c in winding(RADIUS):
		var attack := c.winding_up()
		now[c.get_instance_id()] = attack
		if _seen.get(c.get_instance_id(), &"") != attack and not _in_view(c):
			var row := AttackTable.resolve(attack)
			warned.emit(side_of(c.global_position), row.windup_s if row else 0.0)
	_seen = now


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
