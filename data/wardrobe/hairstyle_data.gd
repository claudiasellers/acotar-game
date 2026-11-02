## A hairstyle (root doc §4.6): loose, braid, hunter's knot, flower crown, wet.
class_name HairstyleData
extends Resource

@export var id: StringName
@export var display_name: String
@export_file("*.glb", "*.gltf", "*.tscn") var mesh_path: String = ""
## Hides the head slot piece when true (a crown style brings its own flowers).
@export var occupies_head: bool = false
@export var canon: String = "X"
## A story deed that has to be done before the style shows in the dressing
## room ("" = always there). The Calanmai crown waits for calanmai_attended.
@export var require_flag: String = ""


func unlocked() -> bool:
	return require_flag == "" or WorldState.has_flag(require_flag)
