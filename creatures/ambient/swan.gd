## A swan on still water: glides slowly about its patch of pond, bobbing,
## and drifts away (never panics) when Feyre comes too close.
class_name Swan
extends Creature

## Surface height, set by the spawner for on-water entries.
@export var water_level: float = 0.0
@export var wander_radius: float = 10.0
@export var shy_distance: float = 6.0

var home: Vector3
var _target: Vector3
var _pause: float = 0.0
var _bob: float = 0.0


func _ready() -> void:
	super._ready()
	collision_mask = 0
	home = global_position if is_inside_tree() else position
	home.y = water_level
	_target = home
	_bob = randf() * TAU


func _move(delta: float) -> void:
	# On water: no gravity and no floor, just glide at the surface.
	var flat := Vector3(move_direction.x, 0.0, move_direction.z)
	var target := flat.normalized() * move_speed if flat.length_squared() > 0.0001 else Vector3.ZERO
	velocity = velocity.move_toward(target, 1.5 * delta)
	if velocity.length_squared() > 0.01:
		face_towards(global_position + velocity, delta)
	_bob += delta
	global_position += velocity * delta
	global_position.y = water_level + sin(_bob * 1.4) * 0.02


func _think(delta: float) -> void:
	var player := get_tree().get_first_node_in_group(&"player") as Node3D if is_inside_tree() else null
	if player and player.global_position.distance_to(global_position) < shy_distance:
		move_direction = Creature.away_from(global_position, player.global_position)
		move_speed = data.run_speed
		return
	var to := _target - global_position
	to.y = 0.0
	if to.length() < 0.5:
		move_speed = 0.0
		_pause -= delta
		if _pause <= 0.0:
			_pause = randf_range(3.0, 9.0)
			var a := randf() * TAU
			_target = home + Vector3(cos(a), 0.0, sin(a)) * randf() * wander_radius
		return
	move_direction = to
	move_speed = data.walk_speed


func _leave_tracks(_delta: float) -> void:
	pass
