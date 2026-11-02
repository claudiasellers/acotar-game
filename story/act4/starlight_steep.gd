## The Starlight Pool as a night station (L44; GAME_DESIGN_PLAN §5 "starlight
## pool at night (steep)"; Keeper: the night use is [X], the swim is by day).
## A CookingStation on the pool's rim with data/stations/starlight_pool.tres
## (night only, fae-safe, steep). Hung on the starlight_pool anchor.
## It also turns the pool's water (mat_water_starlight) from soft daylight
## glitter to dark, clear, star-reflecting water as night falls.
class_name StarlightSteep
extends CookingStation

## Anchor-local: on the rim, nearest the anchor (the stage's "station" mark).
const AT := Vector3(-6.0, 0.0, -12.5)
const WATER := "res://world/spring_court/wider/fx/materials/mat_water_starlight.tres"

var _water: ShaderMaterial
var _night := -1.0


func _init() -> void:
	station = preload("res://data/stations/starlight_pool.tres")
	heat_radius = 0.0
	lit = false


func _ready() -> void:
	super._ready()
	var parent := get_parent() as Node3D
	if parent:
		global_position = Act4Walk.ground_point(parent, parent.to_global(AT)) + Vector3.UP * 0.3
	if ResourceLoader.exists(WATER):
		_water = load(WATER) as ShaderMaterial
	_tint_water()


func _process(_delta: float) -> void:
	_tint_water()


## 0 by day, 1 by night, easing over dusk (19:00-21:00) and dawn (4:30-6:30).
static func night_amount(hour: float) -> float:
	if hour >= 12.0:
		return smoothstep(19.0, 21.0, hour)
	return 1.0 - smoothstep(4.5, 6.5, hour)


func _tint_water() -> void:
	if _water == null:
		return
	var n := night_amount(Clock.hour())
	if absf(n - _night) > 0.005:
		_night = n
		_water.set_shader_parameter(&"night_amount", n)
