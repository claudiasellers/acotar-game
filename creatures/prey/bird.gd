## Ground birds: peck about, and when startled flush upward in a clatter that
## alarms every animal nearby, then settle again further off.
class_name Bird
extends Creature

enum State { PECK, FLY, LAND }

## Loudness of the flush, heard by other creatures (1.0 carries full hearing range).
const FLUSH_LOUDNESS := 1.0
const FLIGHT_HEIGHT := 9.0

var state: State = State.PECK
var flight_target: Vector3

var _peck_timer: float = 0.0
## Near horror (DreadField) songbirds are simply gone; crows stay.
var hushed: bool = false
var _dread_left: float = 0.0
var _flap: float = 0.0
var _head_down: bool = false
## The model's skeleton (lane L61): head and wings are skinned to bones
## "head", "wing_l" and "wing_r". Null for an old unrigged model, whose Head,
## WingL and WingR are plain child nodes.
var _skeleton: Skeleton3D


func _ready() -> void:
	super._ready()
	senses.sensed.connect(_on_sensed)
	if model:
		var found := model.find_children("*", "Skeleton3D", true, false)
		_skeleton = found[0] as Skeleton3D if not found.is_empty() else null


func _on_sensed(_kind: StringName, at: Vector3, _strength: float) -> void:
	if state == State.PECK and senses.awareness >= data.startle_threshold:
		flush(at)


func _on_wounded(from: Vector3, _cause: StringName) -> void:
	flush(from)


## Takes off away from `threat` and alarms everything in earshot.
func flush(threat: Vector3) -> void:
	if state != State.PECK:
		return
	state = State.FLY
	var away := Creature.away_from(global_position, threat).rotated(Vector3.UP, randf_range(-0.6, 0.6))
	flight_target = global_position + away * data.flee_distance
	velocity = away * 3.0 + Vector3.UP * 6.0
	if is_inside_tree():
		CreatureSenses.emit_noise(get_tree(), global_position, FLUSH_LOUDNESS)


func _physics_process(delta: float) -> void:
	_dread_left -= delta
	if _dread_left <= 0.0 and alive and data.kind != &"crow":
		_dread_left = 1.0
		hush(DreadField.withdrawal_at(get_tree(), global_position) > 0.5)
	if hushed:
		return
	if not alive:
		# Fall to the ground when shot out of the air.
		if not is_on_floor():
			velocity.y -= 9.8 * delta
			move_and_slide()
		return
	match state:
		State.PECK:
			super._physics_process(delta)
		State.FLY, State.LAND:
			_fly(delta)


func hush(on: bool) -> void:
	hushed = on
	visible = not on
	collision_layer = 0 if on else Creature.TARGET_LAYER


func _think(delta: float) -> void:
	move_speed = 0.0
	_peck_timer -= delta
	if _peck_timer <= 0.0:
		_peck_timer = randf_range(0.6, 2.5)
		_head_down = not _head_down
		_swing(&"Head", &"head", Vector3.RIGHT, -0.6 if _head_down else 0.0)
		rotation.y += randf_range(-1.0, 1.0)


func _fly(delta: float) -> void:
	var to := flight_target - global_position
	var flat := Vector3(to.x, 0.0, to.z)
	var desired := flat.normalized() * data.run_speed
	if state == State.FLY:
		desired.y = clampf(FLIGHT_HEIGHT - _height_above_start(), -2.0, 4.0)
		if flat.length() < 6.0:
			state = State.LAND
	else:
		desired = flat.normalized() * data.walk_speed * 2.0 + Vector3.DOWN * 3.0
	velocity = velocity.move_toward(desired, 12.0 * delta)
	face_towards(global_position + flat, delta)
	_flap += delta * 22.0
	_swing(&"WingL", &"wing_l", Vector3.BACK, sin(_flap) * 0.9)
	_swing(&"WingR", &"wing_r", Vector3.BACK, -sin(_flap) * 0.9)
	move_and_slide()
	if state == State.LAND and is_on_floor():
		state = State.PECK
		senses.awareness = 0.0


## Turns a part by `angle` about a model-space axis through its joint: the
## bone when the model is skinned, else the part's own node (rotation.x for
## RIGHT, rotation.z for BACK, as before).
func _swing(part: StringName, bone: StringName, axis: Vector3, angle: float) -> void:
	if _skeleton:
		var i := _skeleton.find_bone(bone)
		if i < 0:
			return
		var g := _skeleton.get_bone_global_rest(i).basis.orthonormalized()
		var rest := _skeleton.get_bone_rest(i).basis.get_rotation_quaternion()
		_skeleton.set_bone_pose_rotation(i, rest * Quaternion((g.inverse() * axis).normalized(), angle))
		return
	var node := model.get_node_or_null(NodePath(part)) as Node3D
	if node == null:
		return
	if axis == Vector3.RIGHT:
		node.rotation.x = angle
	else:
		node.rotation.z = angle


func _height_above_start() -> float:
	return global_position.y - (flight_target.y)
