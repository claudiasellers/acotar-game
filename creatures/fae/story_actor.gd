## Shared base for creatures that story scenes stage with cues: listens on
## EventBus.story_actor_cue for its own `actor_id` (e.g. "naga_2"), and
## builds its model from a scene so the art can be swapped.
class_name StoryActor
extends Node3D

signal cued(cue: StringName)

@export var actor_id: StringName = &""
@export var model_scene: PackedScene

var model: Node3D


func _ready() -> void:
	if actor_id == &"":
		actor_id = StringName(name.to_snake_case())
	if model_scene and model == null:
		model = model_scene.instantiate() as Node3D
		model.name = "Model"
		_mount_model(model)
	if EventBus.has_signal(&"story_actor_cue"):
		EventBus.connect(&"story_actor_cue", _on_story_cue)


## Where the model goes; GlamourLayer-wrapped actors override this.
func _mount_model(m: Node3D) -> void:
	add_child(m)


func _on_story_cue(actor: StringName, cue: StringName) -> void:
	if actor != actor_id:
		return
	cued.emit(cue)
	play_cue(cue)


## Override per creature. Unknown cues are ignored (story contract).
func play_cue(_cue: StringName) -> void:
	pass


func _player() -> Node3D:
	return get_tree().get_first_node_in_group(&"player") as Node3D if is_inside_tree() else null


func _turn_towards(point: Vector3, weight: float) -> void:
	var to := point - global_position
	if Vector2(to.x, to.z).length_squared() > 0.0001:
		rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), clampf(weight, 0.0, 1.0))


## Sets emission strength on every emissive surface of the model (eyes).
func set_glow(energy: float) -> void:
	if model == null:
		return
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(i) as StandardMaterial3D
			if mat and mat.emission_enabled:
				mat.emission_energy_multiplier = energy
