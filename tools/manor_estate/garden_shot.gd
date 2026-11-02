## Probe scene for garden shots (L35): the manor estate lit by the game's own
## manor grade, for tools/shots requests ("scene": "res://tools/manor_estate/garden_shot.tscn").
extends Node3D


func _ready() -> void:
	var estate := (load("res://world/spring_court/manor_estate/manor_estate.tscn") as PackedScene).instantiate() as ManorEstate
	add_child(estate)
	ShotLook.dress(estate)
