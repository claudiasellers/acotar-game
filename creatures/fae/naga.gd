## Naga (lore: 04-creatures/naga.md): humanoid, serpentine, hateful. They lie
## low in reeds and strike when prey comes close; story cue `attack` sends
## them at Feyre. Ordinary arrows and a knife kill them (canon); kills report
## kind `naga` with the actor id (naga, naga_2...) as creature_id.
class_name Naga
extends Creature

signal struck_player(naga: Node3D)

enum State { LURK, CHARGE, STRIKE, RECOVER }

@export var strike_reach: float = 1.7
@export var strike_cooldown: float = 1.4
## Awareness at which a lurking naga (spawned free in reeds) breaks cover.
@export var ambush_awareness: float = 0.5

var state: State = State.LURK

var _timer: float = 0.0


func _ready() -> void:
	super._ready()
	senses.sensed.connect(func(_k: StringName, _a: Vector3, _s: float) -> void:
		if state == State.LURK and senses.awareness >= ambush_awareness:
			attack())
	if EventBus.has_signal(&"story_actor_cue"):
		EventBus.connect(&"story_actor_cue", _on_cue)
	_crouch(true)


func _on_cue(actor: StringName, cue: StringName) -> void:
	if actor == creature_id and cue == &"attack":
		attack()


func attack() -> void:
	if not alive or state != State.LURK:
		return
	state = State.CHARGE
	_crouch(false)


func _think(delta: float) -> void:
	var player := get_tree().get_first_node_in_group(&"player") as Node3D if is_inside_tree() else null
	match state:
		State.LURK:
			move_speed = 0.0
		State.CHARGE:
			if player == null:
				return
			var to := player.global_position - global_position
			move_direction = to
			move_speed = data.run_speed
			if Vector2(to.x, to.z).length() <= strike_reach:
				state = State.STRIKE
				_timer = 0.35
		State.STRIKE:
			move_speed = 0.0
			if player:
				face_towards(player.global_position, delta * 4.0)
			_timer -= delta
			if _timer <= 0.0:
				_strike(player)
				state = State.RECOVER
				_timer = strike_cooldown
		State.RECOVER:
			# Weave back a step, then come again.
			if player:
				move_direction = Creature.away_from(global_position, player.global_position).rotated(Vector3.UP, 0.9)
			move_speed = data.walk_speed * 2.0
			_timer -= delta
			if _timer <= 0.0:
				state = State.CHARGE


func _on_wounded(_from: Vector3, _cause: StringName) -> void:
	if state == State.LURK:
		attack()


func _strike(player: Node3D) -> void:
	if player == null or global_position.distance_to(player.global_position) > strike_reach + 0.6:
		return
	struck_player.emit(self)
	if EventBus.has_signal(&"player_struck"):
		EventBus.emit_signal(&"player_struck", creature_id, data.kind, 1.0)


func _crouch(low: bool) -> void:
	if model:
		model.position.y = -data.body_height * 0.35 if low else 0.0
		model.rotation.x = -0.5 if low else 0.0
