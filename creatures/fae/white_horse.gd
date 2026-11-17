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
const SEAT_OFFSET := Vector3(0.0, 0.458, -0.225)
## Bareback she sits on the mare's back itself, below the saddle's seat.
const BAREBACK_DROP := 0.06
## Where a rider's hands hold the reins, in her model space riding the spine
## bone (her left hand at -X): low over the pommel, a forearm ahead of the hips.
const REIN_GRIP := Vector3(0.09, 2.15, -0.48)
## Where the reins lie when nobody holds them: over the front of the saddle,
## or on her withers bareback (L47-8).
const REIN_REST := Vector3(0.075, 2.02, -0.53)
const REIN_REST_BAREBACK := Vector3(0.075, 1.93, -0.56)

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
var _seat_sk: Skeleton3D
var _seat_bone: int = -1

## Riding without the saddle (MareSaddle.set_saddled).
var bareback: bool = false
## Her bit rings in mesh space [left, right] (MareSaddle finds them).
var bits: Array[Vector3] = [Vector3(-0.07, 1.95, -1.6), Vector3(0.07, 1.95, -1.6)]
## The hands on the reins [left, right] (world) and the frame they were set
## (Saddle.place sets them every frame a rider sits her).
var rein_hands: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var rein_held_frame: int = -100


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
	# The proper saddle and the reins to the rider's hands (L47-8).
	MareSaddle.dress(self)
	# She is under the chase camera's line to the rider: never fade her (CameraFade).
	for g in find_children("*", "GeometryInstance3D", true, false):
		g.add_to_group(CameraFade.NEVER_GROUP)


## Where a rider's hips sit, riding the spine bone through each stride.
func seat_point() -> Vector3:
	# Read straight from the spine bone's current pose: a BoneAttachment made
	# on first use reports the skeleton's origin until its next update (L47-6).
	if _seat_sk == null and model:
		var sks := model.find_children("*", "Skeleton3D", true, false)
		if not sks.is_empty():
			_seat_sk = sks.front() as Skeleton3D
			_seat_bone = _seat_sk.find_bone(&"spine")
	var base := global_position + Vector3.UP * 1.25
	if _seat_sk and _seat_bone >= 0 and _seat_sk.is_inside_tree():
		base = _seat_sk.global_transform * _seat_sk.get_bone_global_pose(_seat_bone).origin
	return base + global_basis * (SEAT_OFFSET - Vector3.UP * (BAREBACK_DROP if bareback else 0.0))


## A point of her model space (rest pose) where it is now, riding the spine bone.
func on_back(p: Vector3) -> Vector3:
	seat_point()  # finds the skeleton
	if _seat_sk == null or _seat_bone < 0 or not _seat_sk.is_inside_tree():
		return global_transform * p
	var to_sk := _seat_sk.global_transform.affine_inverse() * model.global_transform
	var ride := _seat_sk.get_bone_global_pose(_seat_bone) * _seat_sk.get_bone_global_rest(_seat_bone).affine_inverse()
	return _seat_sk.global_transform * ride * to_sk * p


## Where the rider's left (`left`) or right hand holds the reins now.
func rein_grip(left: bool) -> Vector3:
	var p := REIN_GRIP - Vector3.UP * (BAREBACK_DROP if bareback else 0.0)
	p.x = -p.x if left else p.x
	return on_back(p)


## Where the reins lie on her when nobody holds them.
func rein_rest(left: bool) -> Vector3:
	var p := REIN_REST_BAREBACK if bareback else REIN_REST
	p.x = -p.x if left else p.x
	return on_back(p)


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
