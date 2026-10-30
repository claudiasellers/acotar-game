## A steady breeze for the hunt demo, used only when no real weather exists.
extends Node

@export var wind: Vector3 = Vector3(2.5, 0.0, 0.0)


func _ready() -> void:
	add_to_group(&"wind_source")


func wind_at(_at: Vector3) -> Vector3:
	return wind
