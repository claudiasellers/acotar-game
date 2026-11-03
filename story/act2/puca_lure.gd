## The puca (ch10–11, moment `puca`, anchor garden_gate). At night, by the
## hedges under her window, Feyre sees her father: under-dressed for winter,
## stooped on his cane, eyes clear for once, beckoning. He never speaks and
## makes no sound on the gravel. He limps ahead of her toward the open gates
## and the dark beyond them, always just out of reach: the garden itself
## becomes the trap, drawing her off the paths and out.
##
## At the gate Tamlin catches her: "Going somewhere?" ... "Why don't you look
## again?" Only if she does look does it shift: a pale bow and quiver, a
## laden pack, her sisters huddled weeping, her father again, a flawless
## rendering. Tamlin snarls; it shimmers and darts away. Looking is the deed
## (puca_resisted, an ActionTrigger, R2). Walk away from it instead (>45 m)
## and the lure lets her go without the deed; it will be there again.
class_name PucaLure
extends Act2DreadSpace

const PUCA_SCENE := "res://creatures/fae/puca.tscn"
## Seconds of her looking at it for each change of shape.
const LOOK_PER_SHIFT := 1.4
const LOOK_CONE := 25.0
const SHIFTS := 4
const STRAY := 45.0
const GATE_RADIUS := 4.0
## L34-8: the scene also opens from her bedroom at night; he waits below the
## window until she's down with him, and each wait carries a nudge.
const WINDOW_ANCHOR := &"feyre_bedroom_window"
const ROOM_RADIUS := 9.0
const BELOW_WINDOW := Vector3(0.0, 0.0, -9.0)
const NEAR_HIM := 14.0
const NUDGE_AFTER := 15.0
## Seconds on "something moved by the hedges" before she knows him.
const SEE_HIM_AFTER := 2.6

var shifts_seen: Array[StringName] = []
var lost_count: int = 0

var _luring: bool = false
## He showed himself under her window (she was in her room), not by the hedge.
var _from_window: bool = false
var _see_left: float = 0.0
var _looked: float = 0.0


func _ready() -> void:
	super._ready()
	# She sees it from her window: the scene opens across the garden below
	# the house, not only at the gate.
	if stage and stage.has_mark(&"hedge"):
		arrive_offset = stage.mark(&"hedge")
		arrive_radius = 22.0


func _build_beats() -> Array:
	shifts_seen.clear()
	_looked = 0.0
	return [
		Beats.run(func(_s: SceneSpace) -> void: _father_appears(), "father by the hedge"),
		Beats.control(StoryControl.Mode.WALK),
		Beats.run(func(_s: SceneSpace) -> void: _see_him(), "she sees him"),
		Beats.until(func() -> bool: return _see_left <= 0.0, "she knows him"),
		Beats.run(func(_s: SceneSpace) -> void:
			# The window framing was only for finding him: going down through the
			# house to the hedges, the camera is hers again (T067).
			StoryControl.set_focus(null)
			if _from_window:
				aside(&"puca_window"), "my father"),
		nudged(func() -> bool: return _near_him(), &"puca_come_down", NUDGE_AFTER, "she goes down to him"),
		Beats.run(func(_s: SceneSpace) -> void: _lure(), "he limps toward the gates"),
		nudged(func() -> bool: return player_within(GATE_RADIUS, mark(&"gate")), &"puca_beckons", NUDGE_AFTER,
			"follow him to the gate"),
		Beats.run(func(_s: SceneSpace) -> void: _caught(), "Tamlin catches her"),
		Beats.control(StoryControl.Mode.NONE),
		say(&"tamlin_going"),
		Beats.control(StoryControl.Mode.LOOK),
		say(&"tamlin_look_again"),
		LookAgainBeat.new(),
		Beats.wait(1.2),
		Beats.run(func(_s: SceneSpace) -> void: _snarl(), "Tamlin snarls; it darts"),
		Beats.wait(1.0),
		say(&"tamlin_puca"),
		Beats.run(func(_s: SceneSpace) -> void: _after(), "quiet again"),
		Beats.raise("puca_resisted"),
	]


func tick(delta: float) -> void:
	_see_left -= delta
	if running and _luring:
		var p := puca()
		var feyre := player()
		if p and feyre and _strayed(p, feyre):
			_lost()
			return
		if p and p.arrived() and p.lure_target.is_equal_approx(mark(&"gate")):
			p.lure_to(mark(&"beyond"))
	super.tick(delta)


## She has walked away from it (not merely run on ahead toward the gate).
func _strayed(p: Node3D, feyre: Node3D) -> bool:
	var gate := mark(&"gate")
	var apart := Vector2(p.global_position.x - feyre.global_position.x, p.global_position.z - feyre.global_position.z).length()
	var hers := Vector2(gate.x - feyre.global_position.x, gate.z - feyre.global_position.z).length()
	var its := Vector2(gate.x - p.global_position.x, gate.z - p.global_position.z).length()
	return apart > STRAY and hers > its


## She's down on the ground near him (not up at her window).
func _near_him() -> bool:
	var p := puca()
	var feyre := player()
	if p == null or feyre == null:
		return true
	var d := p.global_position - feyre.global_position
	return Vector2(d.x, d.z).length() <= NEAR_HIM and absf(d.y) <= 2.5


## In her bedroom, by the window's anchor, on its floor.
func in_her_room() -> bool:
	var room := find_anchor(WINDOW_ANCHOR)
	var feyre := player()
	if room == null or feyre == null:
		return false
	var d := feyre.global_position - room.global_position
	return Vector2(d.x, d.z).length() <= ROOM_RADIUS and absf(d.y) <= 2.5


## On the lawn below her window, on the ground.
func below_her_window() -> Vector3:
	var room := find_anchor(WINDOW_ANCHOR)
	if room == null:
		return mark(&"hedge")
	var at := room.global_transform * BELOW_WINDOW
	at.y = ManorGrounds.ground(at.x, at.z)
	return at


## At night in her room counts as arriving: she sees him from the window.
func _player_here() -> bool:
	return super._player_here() or in_her_room()


func puca() -> Puca:
	return actor(&"puca") as Puca


func _father_appears() -> void:
	_from_window = in_her_room()
	var p := summon(&"puca", PUCA_SCENE, &"hedge", &"house") as Puca
	EventBus.story_actor_cue.emit(&"puca", &"looks_like_father")
	if p:
		if not p.visible:
			p.play_cue(&"looks_like_father")
		if _from_window:
			# Under her window, where she can see him from the glass (ch10-11).
			p.global_position = below_her_window()
			var room := find_anchor(WINDOW_ANCHOR)
			if room:
				p.look_at(Vector3(room.global_position.x, p.global_position.y, room.global_position.z), Vector3.UP)
		if not p.image_changed.is_connected(_on_image):
			p.image_changed.connect(_on_image)
	if _from_window:
		# Watching for Tamlin back from hunting the Bogge, by moonlight (ch10, Keeper).
		aside(&"puca_watch")
	# The garden hushes: no crickets, no fountain, only her boots.
	note_mood()
	EventBus.mood_requested.emit(&"dread", 0.35, 4.0)
	sound(&"drone", -30.0, 0.8)


## From her window: the camera finds him by the hedges.
func _see_him() -> void:
	var p := puca()
	_see_left = SEE_HIM_AFTER if _from_window else 0.0
	if _from_window and p:
		StoryControl.set_focus(p)


## He waits (beckoning) until she has come down to him, then limps off.
func _lure() -> void:
	var p := puca()
	if p:
		# Through the open gate, the only way out of the walled garden.
		p.lure_to(mark(&"gate"))
	_luring = true


func _caught() -> void:
	_luring = false
	var feyre := player()
	var t := cast(&"tamlin", &"gate", &"beyond")
	if t and feyre:
		var side := feyre.global_basis.x if feyre.global_basis.x.length() > 0.1 else Vector3.RIGHT
		t.global_position = feyre.global_position + side * 0.9 + feyre.global_basis.z * 0.4
	EventBus.story_actor_cue.emit(&"tamlin", &"stops_her")
	StoryControl.shake = 0.15
	EventBus.mood_requested.emit(&"dread", 0.6, 0.6)


func _on_image(image: StringName) -> void:
	if running and not _luring:
		shifts_seen.append(image)
	# Her sisters, huddled together, weeping (the sound is canon:"X").
	sound(&"sob", -18.0 if image == &"sisters" else -80.0)


func _snarl() -> void:
	StoryControl.shake = 0.45
	EventBus.mood_requested.emit(&"dread", 0.8, 0.2)
	EventBus.story_actor_cue.emit(&"tamlin", &"snarls")
	var p := puca()
	if p:
		p.dart(mark(&"beyond") - mark(&"gate"))
	sound(&"sob", -80.0)


func _after() -> void:
	StoryControl.shake = 0.0
	sound(&"drone", -80.0)
	EventBus.mood_requested.emit(&"calm", 0.0, 4.0)
	_let_go()


## She walked away from it: it lets her go, no deed; it will come again.
func _lost() -> void:
	_luring = false
	lost_count += 1
	var p := puca()
	if p:
		p.dart(p.global_position - mark(&"gate"))
	_let_go()
	abort("")


## Frees the puca once its dart is over (at once if it isn't darting).
func _let_go() -> void:
	var p := puca()
	if p and p.darting and is_inside_tree():
		p.remove_from_group(&"story_actor_puca")
		p.darted.connect(func() -> void: release_actor(&"puca"), CONNECT_ONE_SHOT)
	else:
		release_actor(&"puca")


## Tamlin: "look again". Each spell of her looking peels one image off it.
class LookAgainBeat:
	extends SceneBeat

	var _shifts: int = 0
	var _held: float = 0.0

	func _init() -> void:
		label = "look again"

	func consumes_time() -> bool:
		return true

	func enter(_space: SceneSpace) -> void:
		_shifts = 0
		_held = 0.0

	func tick(space: SceneSpace, delta: float) -> bool:
		var s := space as PucaLure
		var p := s.puca()
		if p == null:
			return true
		if s.looking_at(p, PucaLure.LOOK_CONE):
			_held += delta
		if _held >= PucaLure.LOOK_PER_SHIFT:
			_held = 0.0
			_shifts += 1
			EventBus.story_actor_cue.emit(&"puca", &"shift_image")
			if p.actor_id != &"puca":
				p.play_cue(&"shift_image")
		return _shifts >= PucaLure.SHIFTS
