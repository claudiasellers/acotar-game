## Probe scene for garden shots (L35): the manor estate with its preview sky
## and sun, for tools/shots requests ("scene": "res://tools/manor_estate/garden_shot.tscn").
## The World scene's grade replaces this lighting in the game.
extends Node3D


func _ready() -> void:
	var estate := (load("res://world/spring_court/manor_estate/manor_estate.tscn") as PackedScene).instantiate() as ManorEstate
	add_child(estate)
	estate._add_preview_environment()
