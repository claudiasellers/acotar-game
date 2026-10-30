## The great wolf of chapter one: Andras, a High Fae sentry in wolf form,
## though nothing here says so. Pony-sized, unnaturally quiet for his size.
## He never notices Feyre: he creeps downwind of the doe, bursts out and seizes
## her neck. The ash arrow in his side makes him drop her, whirl and look at
## Feyre with eerie awareness; he does not run, and her next arrow kills him.
## He dies slowly, his eye on the sky. (Keeper, from the chapter 1 text.)
class_name GreatWolf
extends Creature

signal looked_at_player
signal took_prey(prey: Node3D)

enum State { STALK, RUSH, HOLD_PREY, STARE, RETREAT, DYING }

## The doe he is hunting. Falls back to the nearest node in group "doe".
@export var prey_path: NodePath
## Raised through an ActionTrigger when he dies with ash in him. Empty in the
## real game: the story lane's wolf scene owns `wolf_killed`. The demo sets it.
@export var kill_flag: String = ""
## How long he holds Feyre's eye after the ash goes in.
@export var stare_duration: float = 4.0
@export var strike_distance: float = 9.0
## How long he waits at strike distance before he bursts out: the player's window.
@export var hold_before_rush: float = 8.0
@export var dying_time: float = 2.5

var state: State = State.STALK
var prey: Node3D

var _timer: float = 0.0
var _retreat_to: Vector3
var _trigger: ActionTrigger


func _ready() -> void:
	super._ready()
	if not prey_path.is_empty():
		prey = get_node_or_null(prey_path) as Node3D
	# Fixed on the doe: the player never registers as anything worth turning for.
	senses.decay = 10.0
	if not kill_flag.is_empty():
		_trigger = ActionTrigger.new()
		_trigger.name = "KillTrigger"
		_trigger.flag = kill_flag
		_trigger.fire_on_body_enter = false
		_trigger.monitoring = false
		add_child(_trigger)
	if EventBus.has_signal(&"story_actor_cue"):
		EventBus.connect(&"story_actor_cue", _on_cue)


## Story cues: `stalk` creeps on the nearest doe, `seize_doe` bursts out at
## her, `look_at_feyre` turns him to her (the scene plays it after the ash).
func _on_cue(actor: StringName, cue: StringName) -> void:
	if actor != &"great_wolf" or not alive:
		return
	match cue:
		&"stalk":
			prey = _find_prey()
			state = State.STALK
		&"seize_doe":
			prey = _find_prey()
			state = State.RUSH
		&"look_at_feyre":
			if state != State.STARE:
				state = State.STARE
				_timer = stare_duration
				_set_eye_glow(2.4)
				looked_at_player.emit()


## The ash goes into his side; the arrow that finishes him goes through the eye.
func _hit_part(killing: bool) -> StringName:
	return &"eye" if killing else &"side"


func _on_wounded(from: Vector3, _cause: StringName) -> void:
	if state == State.HOLD_PREY and prey and prey.has_method(&"drop"):
		prey.call(&"drop")
	# He whirls toward whoever shot him, with something too aware in his face.
	state = State.STARE
	_timer = stare_duration
	_set_eye_glow(2.4)
	looked_at_player.emit()
	if not mortally_wounded:
		# Wood only stings. After the look he backs off, then comes back for the doe.
		_retreat_to = global_position + Creature.away_from(global_position, from) * 25.0


func _think(delta: float) -> void:
	if prey == null or not is_instance_valid(prey):
		prey = _find_prey()
	match state:
		State.STALK:
			_stalk(delta)
		State.RUSH:
			if prey == null:
				state = State.STALK
				return
			move_direction = prey.global_position - global_position
			move_speed = data.run_speed
			if global_position.distance_to(prey.global_position) < data.body_length * 0.6:
				if prey.get(&"alive") and prey.has_method(&"die"):
					prey.call(&"die", &"great_wolf")
				state = State.HOLD_PREY
				took_prey.emit(prey)
		State.HOLD_PREY:
			move_speed = 0.0
			if prey:
				face_towards(prey.global_position, delta)
		State.STARE:
			move_speed = 0.0
			var player := _player()
			if player:
				face_towards(player.global_position, delta * 3.0)
			_timer -= delta
			if _timer <= 0.0 and not mortally_wounded:
				_set_eye_glow(data.eye_glow)
				state = State.RETREAT
				_timer = 6.0
		State.RETREAT:
			var to := _retreat_to - global_position
			to.y = 0.0
			move_direction = to
			move_speed = data.run_speed * 0.6 if to.length() > 1.0 else 0.0
			_timer -= delta
			if to.length() <= 1.0 and _timer <= 0.0:
				state = State.STALK
		State.DYING:
			move_speed = 0.0


func _stalk(delta: float) -> void:
	if prey == null:
		move_speed = 0.0
		return
	var to := prey.global_position - global_position
	to.y = 0.0
	if not prey.get(&"alive"):
		state = State.RUSH
		return
	if to.length() > strike_distance:
		_timer = hold_before_rush
		move_direction = to
		# Belly-low creep: slower than a walk, and silent.
		move_speed = data.walk_speed * 0.7
	else:
		move_speed = 0.0
		face_towards(prey.global_position, delta)
		_timer -= delta
		if _timer <= 0.0:
			state = State.RUSH


## He doesn't dodge or run. He sinks, and his eye goes to the sky.
func die(cause: StringName) -> void:
	if not alive:
		return
	state = State.DYING
	if _trigger and cause == &"arrow_ash":
		_trigger.fire()
	var keep := model
	model = null
	super.die(cause)
	model = keep
	if is_inside_tree():
		get_tree().create_timer(dying_time * 0.4).timeout.connect(_fall)
	else:
		_fall()


func _fall() -> void:
	if not is_instance_valid(self) or model == null:
		return
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(model, ^"rotation:z", PI * 0.5, dying_time)
	tween.parallel().tween_property(model, ^"position:y", data.body_width * 0.5, dying_time)
	tween.tween_method(_set_eye_glow, 2.4, 0.0, dying_time * 2.0)


func _player() -> Node3D:
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group(&"player") as Node3D


func _find_prey() -> Node3D:
	if not is_inside_tree():
		return null
	var best: Node3D = null
	var best_d := INF
	for node in get_tree().get_nodes_in_group(&"doe"):
		var n := node as Node3D
		var d := n.global_position.distance_to(global_position)
		if d < best_d:
			best = n
			best_d = d
	return best


func _set_eye_glow(energy: float) -> void:
	if model == null:
		return
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var mats: Array[Material] = [mi.material_override]
		if mi.mesh:
			for i in mi.mesh.get_surface_count():
				mats.append(mi.get_active_material(i))
		for m in mats:
			var mat := m as StandardMaterial3D
			if mat and mat.emission_enabled:
				mat.emission_energy_multiplier = energy
