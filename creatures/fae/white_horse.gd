## The beast's white horse (ch5): Feyre rides it through the woods to the
## gate. A story actor: scenes mount Feyre at `mount_point` and walk it with
## cues `walk` / `stop`, or call walk_to().
class_name WhiteHorse
extends StoryActor

@export var walk_speed: float = 1.6

var mount_point: Marker3D
var walking: bool = false

var _destination: Vector3
var _t: float = 0.0


func _ready() -> void:
	if actor_id == &"":
		actor_id = &"white_horse"
	super._ready()
	add_to_group(&"mount")
	mount_point = Marker3D.new()
	mount_point.name = "MountPoint"
	mount_point.position = Vector3(0, 1.55, 0.1)
	add_child(mount_point)
	_destination = global_position if is_inside_tree() else position


func play_cue(cue: StringName) -> void:
	match cue:
		&"walk", &"lead":
			walk_to(global_position - global_basis.z * 60.0)
		&"stop":
			walking = false


func walk_to(point: Vector3) -> void:
	_destination = point
	walking = true


func _process(delta: float) -> void:
	_t += delta
	if walking:
		var to := _destination - global_position
		to.y = 0.0
		if to.length() < 0.2:
			walking = false
		else:
			global_position += to.limit_length(walk_speed * delta)
			_turn_towards(_destination, delta * 3.0)
	if model:
		# Breathing, and a slow head nod while walking.
		model.position.y = sin(_t * (6.0 if walking else 1.2)) * (0.025 if walking else 0.008)
