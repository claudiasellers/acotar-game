## Pause menu "Return Home": where home is depends on the story phase. In the
## human realm (and when she goes back in p7) it is the cottage at dawn; at
## the Spring Court it is her bedroom in the manor (canon:"X" for the choice).
class_name ReturnHome
extends RefCounted

const HUMAN_REALM := {"region": &"cottage", "anchor": &"opening_cottage_dawn"}
const SPRING_COURT := {"region": &"manor_estate", "anchor": &"feyre_bedroom_window"}
const HUMAN_PHASES: Array[StringName] = [&"", &"p0_winter", &"p1_wolf_and_crossing", &"p7_return_home"]


static func destination(phase_id: StringName) -> Dictionary:
	return HUMAN_REALM if HUMAN_PHASES.has(phase_id) else SPRING_COURT


## Moves Feyre home: straight to the anchor if it is already loaded, else asks
## StoryDirector to travel there, else (greybox, no regions) to `fallback`.
static func go(player: Node3D, fallback: Vector3) -> void:
	var dest := destination(PhaseManager.current_phase)
	var anchor := find_anchor(player.get_tree(), dest.anchor)
	if anchor:
		player.global_position = anchor.global_position + Vector3.UP * 0.1
		_face(player, anchor.global_rotation.y)
	elif WorldStreamer.get_region(dest.region) != null:
		EventBus.travel_requested.emit(dest.region, dest.anchor)
	else:
		player.global_position = fallback
	if player is CharacterBody3D:
		(player as CharacterBody3D).velocity = Vector3.ZERO
	if player.has_method(&"recenter_camera"):
		player.call(&"recenter_camera")


static func find_anchor(tree: SceneTree, anchor_id: StringName) -> Node3D:
	for node in tree.get_nodes_in_group(&"story_anchor"):
		if node is Node3D and StringName(node.get_meta(&"anchor_id", node.name)) == anchor_id:
			return node
	return null


static func _face(player: Node3D, yaw: float) -> void:
	var model := player.get(&"model") as Node3D
	if model:
		model.rotation.y = yaw
