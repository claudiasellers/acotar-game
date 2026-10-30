## The shared senses model (root design doc §4.4): a sight cone with a
## line-of-sight check, hearing of noise events, and scent that only carries
## downwind. Every stimulus raises `awareness` (0 to 1), which decays over time;
## the creature's brain decides what a given awareness means.
class_name CreatureSenses
extends Node3D

signal sensed(kind: StringName, source: Vector3, strength: float)

const GROUP := &"creature_senses"
const WORLD_MASK := 1 << 0
## Wind below this (m/s) counts as calm: scent pools around the source.
const CALM_WIND := 0.4
const TICK := 0.2

@export var sight_range: float = 45.0
@export var fov_degrees: float = 250.0
@export var hearing_range: float = 40.0
@export var scent_range: float = 70.0
## Awareness lost per second when nothing is sensed.
@export var decay: float = 0.12

var awareness: float = 0.0
var last_stimulus_position: Vector3 = Vector3.ZERO
var last_stimulus_kind: StringName = &""
## True while the player is inside the sight cone with a clear line.
var sees_player: bool = false

var _tick_left: float = 0.0

static var _hooked_players: Dictionary = {}


func _ready() -> void:
	add_to_group(GROUP)
	_tick_left = randf() * TICK


func _physics_process(delta: float) -> void:
	awareness = maxf(awareness - decay * delta, 0.0)
	_tick_left -= delta
	if _tick_left > 0.0:
		return
	_tick_left += TICK
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	if player == null:
		sees_player = false
		return
	_hook_player(player)
	_sense_player(player, TICK)


## Feeds a sound into every creature in earshot. Loudness 1.0 is a shout or a
## bird flushing; 0.3 is a careful step.
static func emit_noise(tree: SceneTree, at: Vector3, loudness: float) -> void:
	if tree == null:
		return
	for node in tree.get_nodes_in_group(GROUP):
		(node as CreatureSenses).hear(at, loudness)


func hear(at: Vector3, loudness: float) -> void:
	var strength := hearing_strength(global_position.distance_to(at), loudness, hearing_range)
	if strength > 0.0:
		stimulate(&"sound", at, strength * 0.7)


func stimulate(kind: StringName, at: Vector3, strength: float) -> void:
	if strength <= 0.0:
		return
	awareness = minf(awareness + strength, 1.0)
	last_stimulus_position = at
	last_stimulus_kind = kind
	sensed.emit(kind, at, strength)


func _sense_player(player: Node3D, dt: float) -> void:
	var target := player.global_position + Vector3.UP * 1.2
	var forward := -global_basis.z
	var speed := 0.0
	if player is CharacterBody3D:
		speed = Vector2((player as CharacterBody3D).velocity.x, (player as CharacterBody3D).velocity.z).length()

	sees_player = in_sight_cone(global_position, forward, target, fov_degrees, sight_range) \
			and _line_clear(target, player)
	if sees_player:
		var closeness := 1.0 - global_position.distance_to(target) / sight_range
		# Stillness is the hunter's cover: a motionless Feyre is hard to pick out.
		var motion := 0.3 + 0.7 * clampf(speed / 4.0, 0.0, 1.0)
		stimulate(&"sight", player.global_position, closeness * motion * dt * 2.5)

	if speed > 0.5:
		# Walking is ~0.25 loud, sprinting through snow ~0.8.
		hear(player.global_position, clampf(speed / 10.0, 0.0, 1.0) * dt * 4.0)

	var scent := scent_strength(player.global_position, global_position, wind_at(global_position), scent_range)
	if scent > 0.0:
		stimulate(&"scent", player.global_position, scent * dt * 1.5)


func _line_clear(target: Vector3, player: Node3D) -> bool:
	if not is_inside_tree():
		return false
	var query := PhysicsRayQueryParameters3D.create(global_position, target, WORLD_MASK)
	var owner_body := get_parent() as CollisionObject3D
	if owner_body:
		query.exclude = [owner_body.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.collider == player


## Bow releases and arrow strikes are noise. Hooks the player's signals once.
func _hook_player(player: Node3D) -> void:
	var id := player.get_instance_id()
	if _hooked_players.has(id):
		return
	_hooked_players[id] = true
	var tree := get_tree()
	if player.has_signal(&"bow_released"):
		player.connect(&"bow_released", func(at: Vector3, loudness: float) -> void:
			CreatureSenses.emit_noise(tree, at, loudness))
	elif player.has_signal(&"arrow_fired"):
		player.connect(&"arrow_fired", func(arrow: Node3D) -> void:
			CreatureSenses.emit_noise(tree, arrow.global_position, 0.35))
	if player.has_signal(&"arrow_fired"):
		player.connect(&"arrow_fired", func(arrow: Node3D) -> void:
			if arrow.has_signal(&"hit"):
				arrow.connect(&"hit", func(_c: Node, at: Vector3) -> void:
					CreatureSenses.emit_noise(tree, at, 0.5)))


## Wind from the systems lane's weather (group "wind_source"), calm otherwise.
func wind_at(at: Vector3) -> Vector3:
	if not is_inside_tree():
		return Vector3.ZERO
	var source := get_tree().get_first_node_in_group(&"wind_source")
	if source and source.has_method(&"wind_at"):
		return source.call(&"wind_at", at)
	return Vector3.ZERO


static func in_sight_cone(eye: Vector3, forward: Vector3, target: Vector3, fov: float, sight: float) -> bool:
	var to_target := target - eye
	var distance := to_target.length()
	if distance > sight:
		return false
	if distance < 0.001:
		return true
	var half := deg_to_rad(fov * 0.5)
	return forward.normalized().angle_to(to_target / distance) <= half


## 0 at the edge of earshot, 1 at the source. Louder sounds carry further.
static func hearing_strength(distance: float, loudness: float, hearing: float) -> float:
	var reach := hearing * loudness
	if reach <= 0.0:
		return 0.0
	return clampf(1.0 - distance / reach, 0.0, 1.0)


## How strongly a nose at `nose` smells something at `source`. Scent drifts
## with the wind: strong straight downwind, nothing upwind. In calm air it
## pools in a short radius around the source.
static func scent_strength(source: Vector3, nose: Vector3, wind: Vector3, scent: float) -> float:
	var offset := Vector3(nose.x - source.x, 0.0, nose.z - source.z)
	var distance := offset.length()
	var flat_wind := Vector3(wind.x, 0.0, wind.z)
	var wind_speed := flat_wind.length()
	if wind_speed < CALM_WIND:
		return clampf(1.0 - distance / (scent * 0.25), 0.0, 1.0)
	if distance < 0.001:
		return 1.0
	var alignment := (offset / distance).dot(flat_wind / wind_speed)
	# Only a ~60 degree plume downwind carries scent.
	if alignment < 0.5:
		return 0.0
	var reach := scent * clampf(0.5 + wind_speed / 6.0, 0.5, 1.5)
	return clampf(1.0 - distance / reach, 0.0, 1.0) * remap(alignment, 0.5, 1.0, 0.3, 1.0)
