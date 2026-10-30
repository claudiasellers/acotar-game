## A single hidden keepsake (col_ or ing_ id). One of a handful per wing, so a
## node is fine here; bulk forage uses MultiMesh fields (R9).
## Contract with the gameplay lane: group "forage", harvest() -> StringName.
class_name ManorKeepsake
extends Node3D

@export var item_id: StringName
@export var secret_id: StringName

var taken: bool = false


func _ready() -> void:
	add_to_group(ManorSitePlan.FORAGE_GROUP)
	if secret_id != &"" and WorldState.has_flag(flag()):
		taken = true
		visible = false


func flag() -> String:
	return "fact.manor.secret_%s" % secret_id


func harvest() -> StringName:
	if taken:
		return &""
	taken = true
	visible = false
	if secret_id != &"":
		WorldState.set_flag(flag())
	return item_id
