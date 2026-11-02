## A main-cast model standing about in free roam (lane L34): Tamlin or Lucien
## at the manor. Real models only (characters/<id>/<id>_model.tscn), so the
## playtest's grey-box guard stays clean. It idles, and turns to face Feyre
## while she is near. No collision: it never blocks a door or a deed.
class_name PresenceActor
extends Node3D

const TURN_RADIUS := 6.0

@export var speaker: StringName = &""
var model: Node3D


static func make(speaker_id: StringName, scene: PackedScene) -> PresenceActor:
	var a := PresenceActor.new()
	a.speaker = speaker_id
	a.name = "Cast_%s" % speaker_id
	if scene:
		a.model = scene.instantiate() as Node3D
		a.model.name = "Model"
		a.add_child(a.model)
	return a


func _ready() -> void:
	add_to_group(DialogueDirector.PRESENCE_GROUP)
	set_meta(&"speaker", speaker)


func _process(delta: float) -> void:
	if model and model.has_method(&"play_locomotion"):
		model.call(&"play_locomotion", 0.0, true, delta)
	var feyre := get_tree().get_first_node_in_group(&"player") as Node3D
	if feyre == null:
		return
	var to := feyre.global_position - global_position
	to.y = 0.0
	if to.length() < TURN_RADIUS and to.length() > 0.3:
		rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), 2.5 * delta)
