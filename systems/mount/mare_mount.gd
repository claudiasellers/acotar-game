## The white mare in the world (lane L47, docs/contracts/mount.md): a body
## that stands, comes when Feyre whistles, and carries her. Its look is the
## ch5 white horse (creatures/fae/white_horse.tscn) as a child, so the scripted
## ride and the mount are one animal. MountDirector owns when she exists and
## who rides her; this node only moves.
class_name MareMount
extends CharacterBody3D

signal arrived
signal balked
signal used(rider: Node)

enum State { STANDING, COMING, RIDDEN, GOING_HOME }

const HORSE_SCENE := preload("res://creatures/fae/white_horse.tscn")
const LAYER := 1 << 5
const WORLD_MASK := 1 << 0
const CLOPS: Array[AudioStream] = [
	preload("res://systems/mount/sounds/clop_1.wav"),
	preload("res://systems/mount/sounds/clop_2.wav"),
	preload("res://systems/mount/sounds/clop_3.wav"),
]
const SNORT := preload("res://systems/mount/sounds/snort.wav")
const WHINNY := preload("res://systems/mount/sounds/whinny.wav")
const GRAVITY := 22.0

## Interactor shape (systems/interaction/interactor.gd): group "station".
var station_id: StringName = &"white_mare"
var data: MountData
var horse: WhiteHorse
var state: State = State.STANDING
## Ground speed along her heading (m/s).
var speed: float = 0.0
## Rider input for this frame (set by MountDirector): world direction, 0..1 length.
var steer: Vector3 = Vector3.ZERO
var gallop: bool = false
## Where she is going when called (or home).
var goal: Vector3 = Vector3.ZERO
## 0..1, how afraid of the ground ahead she is (DreadField, horror regions).
var dread_ahead: float = 0.0
## Called by MountDirector with the world position to test; returns 0..1.
var dread_probe: Callable

var _voice: AudioStreamPlayer3D
var _hooves: AudioStreamPlayer3D
var _stride: float = 0.0
var _clop_i: int = 0
var _balk_cool: float = 0.0
var _stuck: float = 0.0
var _leap_pending: bool = false


func _init() -> void:
	name = "WhiteMare"
	add_to_group(WallBarrier.GROUP)  # she can't be ridden across the Wall either
	collision_layer = LAYER
	# Riding past people bumps them like a wall (T092).
	collision_mask = WORLD_MASK | ActorBody.LAYER
	floor_snap_length = 0.6
	for z: float in [0.65, -0.65]:
		var shape := CollisionShape3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = 0.4
		cap.height = 1.4
		shape.shape = cap
		shape.position = Vector3(0.0, 0.72, z)
		add_child(shape)


func _ready() -> void:
	if data == null:
		data = load("res://data/mount/white_mare.tres") as MountData
	floor_max_angle = deg_to_rad(data.max_slope)
	horse = HORSE_SCENE.instantiate() as WhiteHorse
	horse.actor_id = &"white_mare"  # never answers the ch5 ride's cues
	add_child(horse)
	_voice = _player("Voice", -4.0)
	_hooves = _player("Hooves", -10.0)
	set_mountable(state != State.RIDDEN)


func _player(n: String, db: float) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.name = n
	p.volume_db = db
	p.unit_size = 8.0
	p.position = Vector3.UP * 1.0
	add_child(p)
	return p


## In the "station" group (E mounts her) only while nobody is riding.
func set_mountable(on: bool) -> void:
	if on and not is_in_group(&"station"):
		add_to_group(&"station")
	elif not on and is_in_group(&"station"):
		remove_from_group(&"station")


## Interactor calls this on E; MountDirector listens through `used`.
func use(user: Node) -> void:
	used.emit(user)


func heading() -> Vector3:
	return -global_basis.z


func call_to(point: Vector3) -> void:
	goal = point
	state = State.COMING
	_stuck = 0.0


func go_home() -> void:
	goal = data.home
	state = State.GOING_HOME


func stand() -> void:
	state = State.STANDING
	steer = Vector3.ZERO
	gallop = false


func neigh() -> void:
	_say(WHINNY)


func snort() -> void:
	_say(SNORT)


func request_leap() -> void:
	_leap_pending = true


func _say(stream: AudioStream) -> void:
	if _voice and _voice.is_inside_tree():
		_voice.stream = stream
		_voice.pitch_scale = randf_range(0.95, 1.06)
		_voice.play()


## The speed she wants this frame, and which way, for the current state.
func _wish() -> Array:
	match state:
		State.RIDDEN:
			var amount := steer.length()
			if amount < 0.08:
				return [0.0, Vector3.ZERO]
			var v := data.gallop_speed if gallop else (data.walk_speed if amount < 0.5 else data.canter_speed)
			return [v, steer.normalized()]
		State.COMING, State.GOING_HOME:
			var to := goal - global_position
			to.y = 0.0
			var d := to.length()
			if d < data.call_stop:
				return [0.0, Vector3.ZERO]
			# Gallop in, ease to a trot and a walk for the last metres.
			var v := clampf(d * 0.9, data.walk_speed, data.gallop_speed * 0.85)
			return [v, to / d]
	return [0.0, Vector3.ZERO]


func _physics_process(delta: float) -> void:
	var wish := _wish()
	var want: float = wish[0]
	var dir: Vector3 = wish[1]
	_balk_cool = maxf(_balk_cool - delta, 0.0)
	# Dread ahead: she refuses to go on (but will turn and go back).
	if dir != Vector3.ZERO and dread_probe.is_valid():
		var ahead: float = dread_probe.call(global_position + heading() * data.balk_probe)
		var here: float = dread_probe.call(global_position)
		dread_ahead = ahead
		if ahead > 0.15 and ahead >= here and dir.dot(heading()) > 0.0:
			want = 0.0
			if _balk_cool <= 0.0:
				_balk_cool = 2.5
				snort()
				if horse and horse.animator:
					horse.animator.balk()
				balked.emit()
	# Turn toward the wished direction; a horse doesn't strafe.
	if dir != Vector3.ZERO:
		var target_yaw := atan2(-dir.x, -dir.z)
		var t := clampf(speed / maxf(data.gallop_speed, 0.1), 0.0, 1.0)
		var rate := lerpf(data.turn_slow, data.turn_fast, t)
		var diff := wrapf(target_yaw - rotation.y, -PI, PI)
		rotation.y += clampf(diff, -rate * delta, rate * delta)
		# Mostly turned away from where she's going: slow down to turn.
		if absf(diff) > 1.4:
			want = minf(want, data.walk_speed)
	var accel := data.acceleration if want > speed else data.braking
	speed = move_toward(speed, want, accel * delta)
	var h := heading() * speed
	velocity.x = h.x
	velocity.z = h.z
	if is_on_floor():
		velocity.y = -1.0
		if _leap_pending and speed >= data.leap_min_speed:
			velocity.y = data.leap_speed
			snort()
	else:
		velocity.y -= GRAVITY * delta
	_leap_pending = false
	move_and_slide()
	# Walled in (a tree, a fence): head-on she pulls up rather than grinding;
	# a glancing touch only costs speed.
	if is_on_wall():
		var n := get_wall_normal()
		n.y = 0.0
		if n.length_squared() > 0.01 and n.normalized().dot(heading()) < -0.6:
			speed = 0.0
		elif speed > 2.0:
			speed *= 0.6
	if state == State.COMING or state == State.GOING_HOME:
		var left := Vector2(goal.x - global_position.x, goal.z - global_position.z).length()
		_stuck = _stuck + delta if (speed < 0.5 and left > data.call_stop) else 0.0
		if left <= data.call_stop and speed < 0.3:
			var was := state
			stand()
			if was == State.COMING:
				arrived.emit()
	if horse:
		horse.speed_override = speed
		if horse.animator:
			horse.animator.may_graze = state == State.STANDING
	_hoofbeats(delta)


## Seconds she has been held up on the way (for the director's fallback).
func stuck_for() -> float:
	return _stuck


func _hoofbeats(delta: float) -> void:
	if speed < 0.5 or not is_on_floor() or _hooves == null:
		_stride = 0.0
		return
	# About one footfall every 1.1 m at a walk, faster gaits stretch it.
	var step := 1.1 if speed < 3.0 else (1.6 if speed < 7.0 else 2.4)
	_stride += speed * delta
	if _stride >= step:
		_stride -= step
		_clop_i = (_clop_i + 1) % CLOPS.size()
		_hooves.stream = CLOPS[_clop_i]
		_hooves.pitch_scale = randf_range(0.92, 1.08)
		_hooves.play()
