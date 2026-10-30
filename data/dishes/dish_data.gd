## A named result the chemistry engine recognises. Unnamed combinations still
## work; they just get a generated name ("Roast hare", "Infusion of snowdrop").
class_name DishData
extends Resource

@export var id: StringName
@export var display_name: String
@export var method: StringName
## Every one of these must be present.
@export var required: Array[StringName] = []
@export_multiline var journal_note: String
