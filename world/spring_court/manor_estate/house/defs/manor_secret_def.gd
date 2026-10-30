## A secret: a hidden keepsake, a lever that opens a secret door, or a hidden spot.
##
## kind "lever": using it raises fact.manor.secret_<secret_id>, which opens every
## ManorDoorDef with that secret_id. kind "keepsake": a hidden collectible
## (item_id col_... or ing_...). kind "discovery": walking in raises the flag.
class_name ManorSecretDef
extends Resource

@export var secret_id: StringName
@export var kind: StringName = &"keepsake"
@export var level: int = 0
## World XZ; y is above the level's floor.
@export var position: Vector3
@export var item_id: StringName
## Look of the lever or hiding place (PropLib id). Empty = small, subtle default.
@export var prop_id: StringName
@export_multiline var notes: String
