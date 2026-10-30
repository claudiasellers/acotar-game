## Deer and hares: graze and wander near home, look up when something seems
## off, bolt away from it when sure. Hares jink while they run.
class_name Prey
extends Creature

enum State { GRAZE, ALERT, FLEE }

## How far from home it wanders while grazing.
@export var home_radius: float = 18.0

var state: State = State.GRAZE
var home: Vector3

var _graze_timer: float = 0.0
var _wander_target: Vector3
var _flee_from: Vector3
var _flee_travelled: float = 0.0
var _alert_timer: float = 0.0
var _jink_phase: float = 0.0


func _ready() -> void:
	super._ready()
	home = global_position if is_inside_tree() else position
	_wander_target = home
	senses.sensed.connect(_on_sensed)


## Pure state rule shared by every prey species.
static func next_state(current: State, awareness: float, alert_at: float, startle_at: float) -> State:
	if awareness >= startle_at:
		return State.FLEE
	if current == State.FLEE:
		return State.FLEE
	if awareness >= alert_at:
		return State.ALERT
	if current == State.ALERT and awareness > alert_at * 0.4:
		return State.ALERT
	return State.GRAZE


func _on_sensed(_kind: StringName, _at: Vector3, _strength: float) -> void:
	var next := next_state(state, senses.awareness, data.alert_threshold, data.startle_threshold)
	if next == State.FLEE and state != State.FLEE:
		_start_flee(senses.last_stimulus_position)
	elif next == State.ALERT and state == State.GRAZE:
		state = State.ALERT
		_alert_timer = 0.0


func _on_wounded(from: Vector3, _cause: StringName) -> void:
	senses.awareness = 1.0
	_start_flee(from)


## Calm prey wander over to the lure's scent; frightened ones ignore it.
func _on_lured(at: Vector3) -> void:
	if state == State.FLEE:
		return
	state = State.GRAZE
	_wander_target = at
	_graze_timer = 0.0


func _start_flee(threat: Vector3) -> void:
	state = State.FLEE
	_flee_from = threat
	_flee_travelled = 0.0
	_jink_phase = randf() * TAU


func _think(delta: float) -> void:
	match state:
		State.GRAZE:
			_graze(delta)
		State.ALERT:
			move_speed = 0.0
			move_direction = Vector3.ZERO
			face_towards(senses.last_stimulus_position, delta)
			_alert_timer += delta
			if senses.awareness < data.alert_threshold * 0.4 and _alert_timer > 1.5:
				state = State.GRAZE
		State.FLEE:
			_flee(delta)


func _graze(delta: float) -> void:
	_graze_timer -= delta
	var to := _wander_target - global_position
	to.y = 0.0
	if to.length() < 0.8:
		move_speed = 0.0
		if _graze_timer <= 0.0:
			# Head down for a while, then drift somewhere new near home.
			_graze_timer = randf_range(4.0, 12.0)
			var a := randf() * TAU
			_wander_target = home + Vector3(cos(a), 0.0, sin(a)) * randf() * home_radius
	elif _graze_timer <= 0.0:
		move_speed = data.walk_speed
	move_direction = to


func _flee(delta: float) -> void:
	var dir := Creature.away_from(global_position, _flee_from)
	if data.zigzag > 0.0:
		_jink_phase += delta * 5.0
		dir = dir.rotated(Vector3.UP, sin(_jink_phase) * data.zigzag)
	move_direction = dir
	move_speed = data.run_speed * (0.75 if bleeding > 0.0 else 1.0)
	_flee_travelled += Vector2(velocity.x, velocity.z).length() * delta
	if _flee_travelled >= data.flee_distance:
		# Settle where it stopped; this is its home now.
		home = global_position
		_wander_target = home
		state = State.ALERT
		_alert_timer = 0.0
		senses.awareness = data.alert_threshold
