## Local weather: temperature, precipitation and wind, driven by Clock.
##
## The world lane drives the values per region (precipitation, base
## temperature); everything else reads them. Creatures, foliage and arrows
## read wind through wind_at() via the "wind_source" group.
class_name Weather
extends Node

const GROUP := &"wind_source"

## Daily mean temperature in °C (human-realm winter is well below freezing).
@export var base_temperature_c: float = -4.0
## Half the day/night swing in °C: warmest mid-afternoon, coldest before dawn.
@export var daily_swing_c: float = 4.0
## 0 = clear, 1 = heavy.
@export_range(0.0, 1.0) var precipitation: float = 0.0
## &"snow" or &"rain".
@export var precipitation_kind: StringName = &"snow"
## Prevailing wind: compass direction it blows TOWARDS, in degrees (0 = -Z).
@export var wind_heading_degrees: float = 60.0
@export var wind_speed: float = 3.0
## Gusts add up to this many m/s on top of the base speed.
@export var gust_strength: float = 2.0
## How far the heading wanders, in degrees.
@export var heading_wander_degrees: float = 25.0

var _time: float = 0.0


func _ready() -> void:
	add_to_group(GROUP)


func _process(delta: float) -> void:
	_time += delta


## Horizontal wind in m/s at a world position.
func wind_at(world_pos: Vector3) -> Vector3:
	return wind_at_time(world_pos, _time)


## Deterministic for tests: same inputs, same wind.
func wind_at_time(world_pos: Vector3, t: float) -> Vector3:
	var wander := sin(t * 0.021) * 0.7 + sin(t * 0.0057 + 1.3) * 0.3
	var heading := deg_to_rad(wind_heading_degrees + wander * heading_wander_degrees)
	var gust := 0.5 + 0.5 * sin(t * 0.37 + world_pos.x * 0.02) * sin(t * 0.23 + world_pos.z * 0.017)
	var speed := wind_speed + gust_strength * gust
	return Vector3(sin(heading), 0.0, -cos(heading)) * speed


## Air temperature in °C now.
func temperature_c() -> float:
	var clock := Gameplay.autoload(&"Clock")
	var tod := float(clock.get(&"time_of_day")) if clock else 0.5
	# Warmest at about 15:00 (0.625), coldest at about 03:00.
	return base_temperature_c + daily_swing_c * cos((tod - 0.625) * TAU)


## Breath shows below about 4 °C.
func is_breath_visible() -> bool:
	return temperature_c() < 4.0


static func find(tree: SceneTree) -> Weather:
	if tree == null:
		return null
	return tree.get_first_node_in_group(GROUP) as Weather
