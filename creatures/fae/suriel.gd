## The Suriel (lore: 04-creatures/suriel.md). Not a fight: a source. Caught in
## Feyre's double-loop snare it thrashes, then goes still and answers when she
## comes down from the tree. When the naga are near it screams, and the scream
## carries (it is what draws them, ch15).
##
## Cues: caught, naga_are_coming. The story lane owns `suriel_bound`.
class_name Suriel
extends StoryActor

signal screamed

enum State { SNARED, CAUGHT, SCREAMING }

var state: State = State.SNARED

var _t: float = 0.0


func _ready() -> void:
	if actor_id == &"":
		actor_id = &"suriel"
	super._ready()


func play_cue(cue: StringName) -> void:
	match cue:
		&"caught":
			state = State.CAUGHT
		&"naga_are_coming":
			scream()


func scream() -> void:
	state = State.SCREAMING
	_t = 0.0
	set_glow(4.0)
	screamed.emit()
	if is_inside_tree():
		CreatureSenses.emit_noise(get_tree(), global_position, 1.0)


func _process(delta: float) -> void:
	_t += delta
	if model == null:
		return
	match state:
		State.SNARED:
			# Thrashing against the snare.
			model.rotation.z = sin(_t * 9.0) * 0.12
			model.rotation.x = sin(_t * 6.3) * 0.06
		State.CAUGHT:
			# Still, and turned to her. Milky eyes swirl.
			model.rotation.z = lerpf(model.rotation.z, 0.0, delta * 4.0)
			model.rotation.x = lerpf(model.rotation.x, 0.0, delta * 4.0)
			var player := _player()
			if player:
				_turn_towards(player.global_position, delta * 2.0)
			set_glow(1.5 + 0.6 * sin(_t * 2.2))
		State.SCREAMING:
			model.rotation.x = -0.25 + sin(_t * 40.0) * 0.02
			if _t > 2.5:
				state = State.SNARED
				set_glow(1.5)
