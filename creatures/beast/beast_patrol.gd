## Tamlin's beast walking the borders at night: region lanes drop one of these
## where the court's edge needs watching and add Marker3D children as the
## route. He appears between `start_hour` and `end_hour` (wrapping midnight),
## unless a story flag says he is elsewhere. Seen from a window or the woods,
## a shape too big to be anything else.
class_name BeastPatrol
extends Node3D

const BEAST := preload("res://creatures/beast/beast_actor.tscn")

@export var start_hour: float = 21.0
@export var end_hour: float = 4.0
## He is off patrol while any of these flags is set (e.g. the story's own
## beast scene is running, or the court has gone Under the Mountain).
@export var forbid_flags: PackedStringArray = PackedStringArray()

var beast: BeastActor

var _check_left: float = 0.0


func _ready() -> void:
	beast = BEAST.instantiate() as BeastActor
	# Distinct id: the story lane's cues for tamlin_beast never reach the patrol.
	beast.actor_id = &"tamlin_beast_patrol"
	beast.walk_speed = 1.1
	add_child(beast)
	if not route().is_empty():
		beast.global_position = route()[0]
	refresh()


func _process(delta: float) -> void:
	_check_left -= delta
	if _check_left <= 0.0:
		_check_left = 5.0
		refresh()


func route() -> PackedVector3Array:
	var points := PackedVector3Array()
	for child in get_children():
		if child is Marker3D:
			points.append((child as Marker3D).global_position)
	return points


func on_duty(hour: float, has_flag: Callable) -> bool:
	for flag in forbid_flags:
		if has_flag.call(flag):
			return false
	var entry := SpawnEntry.new()
	entry.start_hour = start_hour
	entry.end_hour = end_hour
	return entry.active_at(hour)


func refresh() -> void:
	var duty := on_duty(Clock.hour(), WorldState.has_flag)
	if duty and beast.stage != BeastActor.Stage.PATROL:
		beast.patrol(route())
	elif not duty and beast.stage == BeastActor.Stage.PATROL:
		beast.stage = BeastActor.Stage.GONE
		beast.visible = false
