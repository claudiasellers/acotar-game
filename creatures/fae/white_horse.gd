## The beast's white horse (ch5): Feyre rides it through the woods to the
## gate. A story actor: scenes mount Feyre at `mount_point` and walk it with
## cues `walk` / `stop`, or call walk_to(). The same animal is Feyre's mount
## after the first dinner (lane L47, systems/mount/): one rigged model,
## tools/blender/white_mare.py, whose gait clips play from how fast it moves,
## however it is moved (its own walk, a scene carrying it, or a rider).
class_name WhiteHorse
extends StoryActor

@export var walk_speed: float = 1.6
## Saddle seat (where a rider's hips sit) from the spine bone, in the horse's
## space: up, and forward (-Z). See tools/blender/white_mare.py and Saddle.
const SEAT_OFFSET := Vector3(0.0, 0.47, -0.2)

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
var _seat: BoneAttachment3D


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
	# She is under the chase camera's line to the rider: never fade her (CameraFade).
	for g in find_children("*", "GeometryInstance3D", true, false):
		g.add_to_group(CameraFade.NEVER_GROUP)


## Where a rider's hips sit, riding the spine bone through each stride.
func seat_point() -> Vector3:
	if _seat == null and model:
		var sks := model.find_children("*", "Skeleton3D", true, false)
		if not sks.is_empty() and (sks.front() as Skeleton3D).find_bone(&"spine") >= 0:
			_seat = BoneAttachment3D.new()
			_seat.name = "Seat"
			_seat.bone_name = "spine"
			(sks.front() as Skeleton3D).add_child(_seat)
	var base := global_position + Vector3.UP * 1.25
	if _seat and _seat.is_inside_tree():
		base = _seat.global_position
	return base + global_basis * SEAT_OFFSET


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
