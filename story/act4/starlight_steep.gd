## The Starlight Pool as a night station (L44; GAME_DESIGN_PLAN §5 "starlight
## pool at night (steep)"; Keeper: the night use is [X], the swim is by day).
## A CookingStation on the pool's rim with data/stations/starlight_pool.tres
## (night only, fae-safe, steep). Hung on the starlight_pool anchor.
class_name StarlightSteep
extends CookingStation

## Anchor-local: on the rim, nearest the anchor (the stage's "station" mark).
const AT := Vector3(-6.0, 0.0, -12.5)


func _init() -> void:
	station = preload("res://data/stations/starlight_pool.tres")
	heat_radius = 0.0
	lit = false


func _ready() -> void:
	super._ready()
	var parent := get_parent() as Node3D
	if parent:
		global_position = Act4Walk.ground_point(parent, parent.to_global(AT)) + Vector3.UP * 0.3
