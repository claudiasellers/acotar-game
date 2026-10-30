## Puts creature actors into the world when the story lane's scene spaces ask
## for them (EventBus.story_spawn_requested), and forwards their cues.
## Add one to any scene or region that hosts a story beat.
class_name StorySpawner
extends Node

const SCENES := {
	&"great_wolf": preload("res://creatures/wolves/great_wolf.tscn"),
	&"doe": preload("res://creatures/prey/deer.tscn"),
	&"deer": preload("res://creatures/prey/deer.tscn"),
	&"hare": preload("res://creatures/prey/hare.tscn"),
	&"wolf": preload("res://creatures/wolves/wolf.tscn"),
	&"tamlin_beast": preload("res://creatures/beast/beast_actor.tscn"),
	&"suriel": preload("res://creatures/fae/suriel.tscn"),
	&"naga": preload("res://creatures/fae/naga.tscn"),
	&"bogge": preload("res://creatures/fae/bogge.tscn"),
	&"attor": preload("res://creatures/fae/attor.tscn"),
	&"white_horse": preload("res://creatures/fae/white_horse.tscn"),
}


## "naga_3" -> "naga": a numeric suffix is another of the same kind.
static func base_kind(spawn_id: StringName) -> StringName:
	var parts := String(spawn_id).rsplit("_", true, 1)
	if parts.size() == 2 and parts[1].is_valid_int():
		return StringName(parts[0])
	return spawn_id

var spawned: Dictionary = {}


func _ready() -> void:
	if EventBus.has_signal(&"story_spawn_requested"):
		EventBus.connect(&"story_spawn_requested", spawn)


## Spawns (or moves, if already present) the actor for `spawn_id`.
func spawn(spawn_id: StringName, at: Transform3D) -> Node3D:
	var kind := base_kind(spawn_id)
	if not SCENES.has(kind):
		return null
	var existing := spawned.get(spawn_id) as Node3D
	if existing and is_instance_valid(existing):
		existing.global_transform = at
		existing.add_to_group(StringName("story_actor_%s" % spawn_id))
		return existing
	var actor := (SCENES[kind] as PackedScene).instantiate() as Node3D
	actor.name = String(spawn_id).to_pascal_case()
	# Cues and kill reports address the actor by its full id (naga_2).
	if &"actor_id" in actor:
		actor.set(&"actor_id", spawn_id)
	if &"creature_id" in actor:
		actor.set(&"creature_id", spawn_id)
	if spawn_id == &"doe":
		actor.add_to_group(&"doe")
	# The story lane checks this group right after its emit to know we answered.
	actor.add_to_group(StringName("story_actor_%s" % spawn_id))
	var parent := get_tree().current_scene if get_tree().current_scene else get_parent()
	parent.add_child(actor)
	actor.global_transform = at
	if actor is BeastActor:
		# The door the beast comes through is the spawn point's forward face.
		(actor as BeastActor).visible = true
	spawned[spawn_id] = actor
	return actor
