## Where the horror is, the court withdraws (experience bar §1.5): butterflies,
## faelights and songbirds go, the grade drops into "dread" as Feyre nears,
## and once she is inside, a single wrong sound. Put one on the Bogge, the
## naga, the Attor, wolves, or (as dread_field.tscn) a blighted place.
##
## Fields never touch other nodes: swarms and birds ask `withdrawal_at()`,
## and the grade director hears EventBus.mood_requested.
class_name DreadField
extends Node3D

signal wrong_sound(at: Vector3)

const GROUP := &"dread_field"
const TICK := 0.25

## Mood reaches full strength inside `inner` and fades out at `radius`.
@export var radius: float = 30.0
@export var inner: float = 10.0
## Ambient life is gone within radius * this, regardless of where Feyre is.
@export var withdraw_scale: float = 1.6
@export var max_intensity: float = 1.0
## Seconds after she enters before the one wrong sound (a snap, a breath).
@export var wrong_sound_delay: Vector2 = Vector2(1.2, 2.6)
@export var wrong_sound_stream: AudioStream

## This field's current pull on the mood, 0 to 1.
var level: float = 0.0
var inside: bool = false

var _tick_left: float = 0.0
var _sound_left: float = -1.0
var _rng := RandomNumberGenerator.new()

## Combined mood from every field, and what was last sent to the grade.
static var _levels: Dictionary = {}
static var _sent: float = 0.0


## Adds a field to a creature. Returns it.
static func attach(owner_node: Node3D, field_radius: float, field_inner: float) -> DreadField:
	var field := DreadField.new()
	field.name = "DreadField"
	field.radius = field_radius
	field.inner = field_inner
	owner_node.add_child(field)
	return field


## How far ambient life has withdrawn at `at`, 0 (none) to 1 (gone).
static func withdrawal_at(tree: SceneTree, at: Vector3) -> float:
	if tree == null:
		return 0.0
	var best := 0.0
	for node in tree.get_nodes_in_group(GROUP):
		var f := node as DreadField
		if f == null or not f.is_visible_in_tree():
			continue
		var reach := f.radius * f.withdraw_scale
		best = maxf(best, falloff(f.global_position.distance_to(at), reach * 0.6, reach))
	# The world lanes' "no birds" volumes (no birdsong near the wall): boxes.
	for node in tree.get_nodes_in_group(&"no_birds_zone"):
		for shape in (node as Node).find_children("*", "CollisionShape3D", true, false):
			var cs := shape as CollisionShape3D
			var box := cs.shape as BoxShape3D
			if box and AABB(-box.size * 0.5, box.size).has_point(cs.global_transform.affine_inverse() * at):
				return 1.0
	return best


## 1 inside `near`, 0 beyond `far`, smooth between.
static func falloff(distance: float, near: float, far: float) -> float:
	if distance <= near:
		return 1.0
	if distance >= far:
		return 0.0
	return 1.0 - smoothstep(near, far, distance)


func _ready() -> void:
	add_to_group(GROUP)
	_rng.seed = get_instance_id()


func _exit_tree() -> void:
	_levels.erase(get_instance_id())
	_send_mood()


func _process(delta: float) -> void:
	if _sound_left >= 0.0:
		_sound_left -= delta
		if _sound_left < 0.0:
			_play_wrong_sound()
	_tick_left -= delta
	if _tick_left > 0.0:
		return
	_tick_left = TICK
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	update_level(player.global_position if player and is_visible_in_tree() else Vector3.INF)


func update_level(player_at: Vector3) -> void:
	var d := INF if player_at == Vector3.INF else global_position.distance_to(player_at)
	level = falloff(d, inner, radius) * max_intensity
	var now_inside := level > 0.5
	if now_inside and not inside:
		_sound_left = _rng.randf_range(wrong_sound_delay.x, wrong_sound_delay.y)
	inside = now_inside
	if level > 0.0:
		_levels[get_instance_id()] = level
	else:
		_levels.erase(get_instance_id())
	_send_mood()


static func _send_mood() -> void:
	var total := 0.0
	for v in _levels.values():
		total = maxf(total, v)
	if absf(total - _sent) < 0.08 and not (total == 0.0 and _sent > 0.0):
		return
	if total <= 0.0:
		EventBus.mood_requested.emit(&"calm", 0.0, 2.5)
	else:
		EventBus.mood_requested.emit(&"dread", total, 1.5)
	_sent = total


func _play_wrong_sound() -> void:
	wrong_sound.emit(global_position)
	if wrong_sound_stream and is_inside_tree():
		var player := AudioStreamPlayer3D.new()
		player.stream = wrong_sound_stream
		player.unit_size = 6.0
		add_child(player)
		player.play()
		player.finished.connect(player.queue_free)
