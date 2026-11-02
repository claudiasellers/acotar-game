## The beast's white horse (ch5): Feyre rides it through the woods to the
## gate. A story actor: scenes mount Feyre at `mount_point` and walk it with
## cues `walk` / `stop`, or call walk_to(). The same animal is Feyre's mount
## after the first dinner (lane L47, systems/mount/): one rigged model,
## tools/blender/white_mare.py, whose gait clips play from how fast it moves,
## however it is moved (its own walk, a scene carrying it, or a rider).
class_name WhiteHorse
extends StoryActor

@export var walk_speed: float = 1.6

var mount_point: Marker3D
var walking: bool = false

## Plays idle / walk / trot / gallop from ground speed (null on an unrigged model).
var animator: MareAnimator
## Set by whoever moves the horse to give its speed outright (the mount);
## below zero, the speed is measured from how far it moved this frame.
var speed_override: float = -1.0

var _destination: Vector3
var _t: float = 0.0
var _last: Vector3 = Vector3.INF


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
	animator = MareAnimator.attach(model, self)


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
	if animator:
		var here := global_position
		var measured := 0.0 if _last == Vector3.INF or delta <= 0.0 else Vector2(here.x - _last.x, here.z - _last.z).length() / delta
		_last = here
		# A scene that teleports the horse (a fade) mustn't read as a sprint.
		animator.speed = speed_override if speed_override >= 0.0 else (measured if measured < 40.0 else 0.0)
	elif model:
		# Breathing, and a slow head nod while walking.
		model.position.y = sin(_t * (6.0 if walking else 1.2)) * (0.025 if walking else 0.008)
