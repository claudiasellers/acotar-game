## The beast at the door, ch3-4 (Keeper's chapter spine).
##
## The night after the pelt is sold, once she has had supper and slept
## (CottageEvening): the quiet hour at the fire, her thought of the Treaty, she
## turns to Nesta about Tomas, and the door bursts. The beast (golden, horse-sized, elk-like horns) roars
## "Murderers!". One physical decision window: throw her knife (interact) or her
## sisters' iron bracelets (fire); both glance off his hide (BeastDoorThrow).
## Or freeze. Then he asks who killed the wolf, she confesses, and he gives the
## Treaty's terms: a life for a life, Prythian or die (BeastDoorGuide speaks the
## Keeper's lines; each waits until the last is said). Father begs, is roared
## silent, offers gold; "How much is your daughter's life worth?" She goes;
## he snaps her ash arrow into the fire, and her father says goodbye. The door stays broken (fact.cottage_door_broken, for StateVisibility).
class_name BeastDoor
extends SceneSpace

const GROUP := &"beast_door"
## Where he waits, outside the door, before it breaks.
const OUTSIDE := 3.0

@export var decision_seconds: float = 6.0
## Seconds into "Nesta. About Tomas Mandray" before the door cuts her off.
const TOMAS_CUT := 1.4

var beast: Node3D
var chosen_fact: String = ""
## The scene's words (systems/dialogue/scene_guides/) and what her choice throws.
var guide: BeastDoorGuide
var throw: BeastDoorThrow
var _player_inside: bool = false


func _init() -> void:
	space_id = &"beast_door"
	add_to_group(GROUP)
	# After the evening at home: supper, then the night's sleep (CottageEvening).
	require_flags = PackedStringArray(["wolf_killed", "pelt_sold", CottageEvening.SLEPT])
	done_flags = PackedStringArray(["beast_claim_accepted"])
	night_only = true
	auto_start = true
	# Night comes through her sleep in the ironwood bed, never by coming home.
	shift_time_on_arrival = false


func _ready() -> void:
	super._ready()
	var entry := get_node_or_null(^"Entry") as Area3D
	if entry:
		entry.body_exited.connect(func(body: Node3D) -> void:
			if body.is_in_group(&"player"):
				_player_inside = false
				player_present = false)
	decision_made.connect(func(fact: String) -> void: chosen_fact = fact)
	# Camera and lens for the scene, camera only (lane L22, story/staging/).
	add_child(BeastDoorStaging.new())
	# Moon through the door, the hearth, a rim on him: lights only (lane L55).
	add_child(BeastDoorLighting.new())
	guide = BeastDoorGuide.new()
	add_child(guide)
	throw = BeastDoorThrow.new()
	add_child(throw)


## Tests and the greybox can say Feyre is home without an Entry area.
func set_player_inside(inside: bool) -> void:
	_player_inside = inside
	player_present = inside


func can_start() -> bool:
	return _player_inside and super.can_start()


func _build_beats() -> Array:
	return [
		# The quiet hour at the fire (Keeper, evening 2): the Treaty in her
		# thoughts, then she turns to Nesta about Tomas and the door breaks.
		Beats.cue(&"family", &"gather"),
		Beats.control(StoryControl.Mode.WALK, null),
	] + _line(&"fire", player) + [
		Beats.mood(&"dread", 0.5, 2.0),
		Beats.wait(2.0),
		Beats.run(func(_s: SceneSpace) -> void: guide.say(&"tomas", player()), "Nesta. About Tomas"),
		Beats.wait(TOMAS_CUT),
		Beats.mood(&"dread", 1.0, 0.2, 0.8),
		Beats.run(_break_door, "the door breaks"),
		Beats.raise("fact.cottage_door_broken"),
		Beats.run(func(_s: SceneSpace) -> void:
			StoryControl.hold(self, StoryControl.Mode.LOOK)
			StoryControl.set_focus(beast), "it fills the room"),
		Beats.wait(2.5),
		Beats.cue(&"tamlin_beast", &"accuse"),
		Beats.run(func(_s: SceneSpace) -> void: guide.say(&"accuse", beast), "MURDERERS"),
		Beats.mood(&"dread", 1.0, 0.5, 0.35),
		# The knife is the interact press, which the space reads itself; leaving
		# interact out keeps E from also using the bed behind her.
		Beats.run(func(_s: SceneSpace) -> void:
			StoryControl.hold(self, StoryControl.Mode.LOOK, PackedStringArray(["fire"])), "window"),
		Beats.decision([
			{"action": &"interact", "fact": "fact.beast_door.threw_knife"},
			{"action": &"fire", "fact": "fact.beast_door.threw_bracelets"},
		], decision_seconds, "fact.beast_door.froze"),
		Beats.run(func(_s: SceneSpace) -> void: StoryControl.hold(self, StoryControl.Mode.LOOK), "after the window"),
		ThrowBeat.new(),
		Beats.cue(&"tamlin_beast", &"speak"),
	] + _line(&"who", _beast_node) + _line(&"confess", player) + _line(&"provoked", _beast_node) \
		+ _line(&"deserved", player) + _line(&"life", _beast_node) + [
		Beats.cue(&"father", &"plead"),
	] + _line(&"plead", _father) + [
		Beats.run(func(_s: SceneSpace) -> void:
			SoundDirector.cue(&"beast_roar", beast.global_position if is_instance_valid(beast) else Vector3.INF),
			"a roar cuts him off"),
	] + _line(&"silence", _beast_node) + _line(&"gold", _father) + _line(&"worth", _beast_node) + [
		Beats.raise("beast_claim_accepted"),
	] + _line(&"when", player) + [
		Beats.cue(&"tamlin_beast", &"snap_ash_arrow"),
		Beats.wait(1.5),
		Beats.run(_burn_ash_arrows, "into the fire"),
		Beats.raise("fact.ash_arrow_burned"),
	] + _line(&"now", _beast_node) + _line(&"goodbye", _father)


## A guide beat said by `speaker` (a node getter), then held until it is said.
func _line(beat: StringName, speaker: Callable) -> Array:
	return [
		Beats.run(func(_s: SceneSpace) -> void: guide.say(beat, speaker.call()), "say %s" % beat),
		Beats.until(guide.quiet, "until %s is said" % beat),
	]


func _beast_node() -> Node3D:
	return beast if is_instance_valid(beast) else null


func _father() -> Node3D:
	for n in get_tree().get_nodes_in_group(&"family"):
		if StringName(n.get(&"member_id")) == &"father":
			return n as Node3D
	return null


## Canon: he snaps her ash arrow and throws it in the fire before they go.
func _burn_ash_arrows(_space: SceneSpace) -> void:
	var count := Gameplay.inventory.count(&"arrow_ash")
	if count > 0:
		Gameplay.inventory.remove(&"arrow_ash", count)


func _break_door(_space: SceneSpace) -> void:
	var door := get_node_or_null(^"Door") as Node3D
	if door == null:
		for anchor in get_tree().get_nodes_in_group(&"story_anchor"):
			if StringName(anchor.get_meta(&"anchor_id", anchor.name)) == &"act1_cottage_door":
				door = anchor
				break
	# He comes from outside: a few metres beyond the door (its +Z), facing in,
	# and the break carries him through it into the room (BeastActor.enter_depth).
	var where := door.global_transform if door else global_transform
	if door:
		where.origin += door.global_basis.z * OUTSIDE
	beast = request_actor(&"tamlin_beast", where, StandIns.beast)
	if beast is BeastActor and door:
		# The latch on the door anchor swings the real leaf (break_open).
		var latch := door.get_node_or_null(^"CottageDoorLatch") as Node3D
		(beast as BeastActor).door = latch if latch else door
	EventBus.story_actor_cue.emit(&"tamlin_beast", &"enter")
	WorldDeltas.set_region_value(&"cottage", "door", "broken")


## Home after the sale by day: the evening falls for her (TimeShift) and the
## beast comes; at night it starts straight away (auto_start).
func _on_entry_body_entered(body: Node3D) -> void:
	if body.is_in_group(&"player"):
		_player_inside = true
		player_present = true


## Her choice leaves her hand and glances off him (nothing, if she froze).
class ThrowBeat:
	extends SceneBeat

	func consumes_time() -> bool:
		return true

	func _init() -> void:
		label = "it glances off him"

	func enter(space: SceneSpace) -> void:
		var door := space as BeastDoor
		door.throw.throw_for(door.chosen_fact, door.player(), door.beast)

	func tick(space: SceneSpace, delta: float) -> bool:
		return (space as BeastDoor).throw.advance(delta)
