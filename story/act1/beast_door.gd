## The beast at the door, ch3-4 (Keeper's chapter spine).
##
## The night after the pelt is sold, with Feyre home: wind, the fire, then the
## door bursts. The beast (golden, horse-sized, elk-like horns) roars
## "Murderer". One physical decision window: throw her knife (interact) or her
## sisters' iron bracelets (fire); both are useless against it. Or freeze.
## Then life for a life: die, or live in Prythian forever. Father begs. She
## goes. The door stays broken (fact.cottage_door_broken, for StateVisibility).
class_name BeastDoor
extends SceneSpace

@export var decision_seconds: float = 6.0

var beast: Node3D
var chosen_fact: String = ""
var _player_inside: bool = false


func _init() -> void:
	space_id = &"beast_door"
	require_flags = PackedStringArray(["wolf_killed", "pelt_sold"])
	done_flags = PackedStringArray(["beast_claim_accepted"])
	night_only = true
	auto_start = true


func _ready() -> void:
	super._ready()
	var entry := get_node_or_null(^"Entry") as Area3D
	if entry:
		entry.body_exited.connect(func(body: Node3D) -> void:
			if body.is_in_group(&"player"):
				_player_inside = false)
	decision_made.connect(func(fact: String) -> void: chosen_fact = fact)


## Tests and the greybox can say Feyre is home without an Entry area.
func set_player_inside(inside: bool) -> void:
	_player_inside = inside


func can_start() -> bool:
	return _player_inside and super.can_start()


func _build_beats() -> Array:
	return [
		Beats.cue(&"family", &"gather"),
		Beats.control(StoryControl.Mode.WALK, null),
		Beats.mood(&"dread", 0.5, 2.0),
		Beats.wait(2.0),
		Beats.mood(&"dread", 1.0, 0.2, 0.8),
		Beats.run(_break_door, "the door breaks"),
		Beats.raise("fact.cottage_door_broken"),
		Beats.run(func(_s: SceneSpace) -> void:
			StoryControl.set_mode(StoryControl.Mode.LOOK)
			StoryControl.set_focus(beast), "it fills the room"),
		Beats.wait(2.5),
		Beats.cue(&"tamlin_beast", &"accuse"),
		Beats.mood(&"dread", 1.0, 0.5, 0.35),
		Beats.run(func(_s: SceneSpace) -> void:
			StoryControl.set_mode(StoryControl.Mode.LOOK, PackedStringArray(["interact", "fire"])), "window"),
		Beats.decision([
			{"action": &"interact", "fact": "fact.beast_door.threw_knife"},
			{"action": &"fire", "fact": "fact.beast_door.threw_bracelets"},
		], decision_seconds, "fact.beast_door.froze"),
		Beats.cue(&"tamlin_beast", &"speak"),
		Beats.cue(&"father", &"plead"),
		Beats.run(func(_s: SceneSpace) -> void: StoryControl.set_mode(StoryControl.Mode.LOOK), "a life for a life"),
		Beats.wait(4.0),
		Beats.raise("beast_claim_accepted"),
	]


func _break_door(_space: SceneSpace) -> void:
	var door := get_node_or_null(^"Door") as Node3D
	if door == null:
		for anchor in get_tree().get_nodes_in_group(&"story_anchor"):
			if StringName(anchor.get_meta(&"anchor_id", anchor.name)) == &"act1_cottage_door":
				door = anchor
				break
	var where := door.global_transform if door else global_transform
	beast = request_actor(&"tamlin_beast", where, StandIns.beast)
	EventBus.story_actor_cue.emit(&"tamlin_beast", &"enter")
	WorldDeltas.set_region_value(&"cottage", "door", "broken")


func _on_entry_body_entered(body: Node3D) -> void:
	if body.is_in_group(&"player"):
		_player_inside = true
