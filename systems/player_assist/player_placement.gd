## SaveSystem provider for where Feyre stands, so Continue puts her back where
## she saved. On load she is held still until there is ground under her (the
## region may still be streaming in), then released.
class_name PlayerPlacement
extends RefCounted

const KEY := "player_placement"
const GROUND_WAIT_SECONDS := 15.0

var _player: WeakRef


func _init(player: Node3D) -> void:
	_player = weakref(player)


func save_state() -> Dictionary:
	var p := _player.get_ref() as Node3D
	if p == null:
		return {}
	var model := p.get(&"model") as Node3D
	return {
		"position": [p.global_position.x, p.global_position.y, p.global_position.z],
		"yaw": model.rotation.y if model else 0.0,
	}


func load_state(data: Dictionary) -> void:
	var p := _player.get_ref() as Node3D
	var pos: Array = data.get("position", [])
	if p == null or pos.size() != 3:
		return
	var at := Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
	# The opening (Act1Game) would otherwise move her to the dawn anchor.
	var scene := p.get_tree().current_scene
	if scene and &"spawned" in scene:
		scene.set(&"spawned", true)
	p.global_position = at + Vector3.UP * 0.2
	var model := p.get(&"model") as Node3D
	if model:
		model.rotation.y = float(data.get("yaw", 0.0))
	WorldStreamer.update_for(at)
	p.set_physics_process(false)
	_release_on_ground(p, GROUND_WAIT_SECONDS)


func _release_on_ground(p: Node3D, time_left: float) -> void:
	if not is_instance_valid(p):
		return
	var from := p.global_position + Vector3.UP * 1.0
	var hit := p.get_world_3d().direct_space_state.intersect_ray(
			PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 4.0, 1))
	if not hit.is_empty() or time_left <= 0.0:
		p.set_physics_process(true)
		if p.has_method(&"recenter_camera"):
			p.call(&"recenter_camera")
		return
	p.get_tree().create_timer(0.25).timeout.connect(_release_on_ground.bind(p, time_left - 0.25))
