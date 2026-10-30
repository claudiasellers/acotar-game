## The felt Wall: an Area3D along the line at z = 1400. While a body in group
## "player" is inside, `wall_proximity` runs 0..1 (1 at the line) and
## `proximity_changed` fires when it moves. Nothing story-related happens
## here; the UI lane spins the compass with compass_jitter(), the audio lane
## drops the soundscape by wall_proximity.
class_name WallSenseVolume
extends Area3D

signal proximity_changed(amount: float)

const PLAYER_GROUP := &"player"

@export var wall_z := WorldMap.WALL_Z
## Metres either side of the line over which the Wall is felt.
@export var sense_depth := 30.0
@export var x_min := -900.0
@export var x_max := 700.0

var wall_proximity := 0.0
var _bodies: Array[Node3D] = []


func _ready() -> void:
	monitoring = true
	monitorable = false
	collision_layer = 0
	collision_mask = (1 << 1) | 1  # Feyre's PLAYER_LAYER, plus world bodies
	if get_child_count() == 0:
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(x_max - x_min, 400.0, sense_depth * 2.0)
		cs.shape = box
		cs.position = Vector3((x_min + x_max) * 0.5, 0.0, wall_z) - position
		add_child(cs)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


## 0 at sense_depth metres from the line or more, 1 on it, smooth between.
static func proximity_for(distance: float, depth: float) -> float:
	if depth <= 0.0:
		return 0.0
	var t := 1.0 - clampf(absf(distance) / depth, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


## Compass needle offset in radians for a proximity at time t (seconds):
## still at 0, a wandering half-turn swing at the line.
static func compass_jitter_for(amount: float, t: float) -> float:
	var a := clampf(amount, 0.0, 1.0)
	return a * a * PI * (0.6 * sin(t * 5.1) + 0.3 * sin(t * 13.7 + 1.3) + 0.1 * sin(t * 31.0))


func compass_jitter() -> float:
	return compass_jitter_for(wall_proximity, Time.get_ticks_msec() / 1000.0)


## Feeds a world position in directly (used by _physics_process and tests).
func update_from_position(pos: Vector3) -> void:
	var amount := 0.0
	if pos.x >= x_min - sense_depth and pos.x <= x_max + sense_depth:
		amount = proximity_for(pos.z - wall_z, sense_depth)
	_set_proximity(amount)


func _physics_process(_delta: float) -> void:
	if _bodies.is_empty():
		if wall_proximity != 0.0:
			_set_proximity(0.0)
		return
	var best := 0.0
	for b in _bodies:
		if is_instance_valid(b):
			best = maxf(best, proximity_for(b.global_position.z - wall_z, sense_depth))
	_set_proximity(best)


func _set_proximity(amount: float) -> void:
	if absf(amount - wall_proximity) < 0.005 and not (amount == 0.0 and wall_proximity != 0.0):
		return
	wall_proximity = amount
	proximity_changed.emit(amount)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group(PLAYER_GROUP) and not _bodies.has(body):
		_bodies.append(body)


func _on_body_exited(body: Node3D) -> void:
	_bodies.erase(body)
