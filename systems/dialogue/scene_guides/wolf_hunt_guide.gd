## Feyre's inner voice through the ch1 wolf hunt (lane L34-4), so the player
## knows what to look at, what to do and what's about to happen, without a
## marker or a line of objective text (R2). It lives as a child of the
## WolfKill space (one line in wolf_kill.gd) and only listens: the beats, the
## flags and the canon stay with the scene.
##
## Lines (Storykeeper, ch1) are DialogueLine SCENE lines at "wolf_kill.<beat>"
## in data/dialogue/lines/wolf_hunt.tres, spoken through DialogueDirector,
## which keeps its ambient lines quiet while the hunt runs:
##   doe          the camera finds her: what she is worth to the family
##   eyes         golden eyes in the brush (the snow holds), downwind of her
##   size         he creeps out: the size of a pony; a faerie; only ash
##   wait         is he alone? just an animal
##   nudge_draw   only if she has never drawn: the ash arrow, now
##   nudge_loose  only if she still hasn't, once he has the doe: his side
##   wood / miss  a wood arrow stings him; a shot that misses
##   ash          the ash lands and he looks at her: the eye, just in case
##   kill         he should be dead, not dying; just a wolf
## Every beat is said at most once a hunt. The nudges stop for good the moment
## she draws. Her heart beats under the draw while he is alive.
class_name WolfHuntGuide
extends Node

const SCENE := &"wolf_kill"
## Quiet seconds after one beat before the next thought.
const SIZE_AFTER := 1.0
const WAIT_AFTER := 3.5
## Quiet seconds, never having drawn, before each nudge.
const NUDGE_DRAW_AFTER := 7.0
const NUDGE_LOOSE_AFTER := 9.0
## The sound lane's loop (L15 contract): cue on the draw, stop on release.
const HEARTBEAT := &"beast_heartbeat"
const HEARTBEAT_FADE := 1.5

var space: Node
var said: Dictionary = {}
## She has drawn the bow since the wolf showed himself.
var drawn: bool = false
## Quiet seconds since the last beat finished speaking.
var idle: float = 0.0
var heart: bool = false
## Off for tests that drive beats by hand.
var listen_to_bow: bool = true

var _arrows_hooked: bool = false


func _ready() -> void:
	space = get_parent()
	EventBus.scene_space_started.connect(_on_started)
	EventBus.scene_space_finished.connect(_on_finished)
	EventBus.story_actor_cue.connect(_on_cue)
	EventBus.creature_hit.connect(_on_hit)
	EventBus.creature_killed.connect(_on_killed)


func _exit_tree() -> void:
	_stop_heart()
	var d := director()
	if d:
		d.hold(SCENE, false)


func director() -> DialogueDirector:
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group(DialogueDirector.GROUP) as DialogueDirector


func running() -> bool:
	return space != null and bool(space.get(&"running"))


func wolf() -> Node3D:
	var w: Variant = space.get(&"wolf") if space else null
	return w as Node3D if is_instance_valid(w) and w is Node3D else null


## Says `beat` unless it was said this hunt. Returns whether anything was said.
func say(beat: StringName) -> bool:
	if said.has(beat):
		return false
	said[beat] = true
	var d := director()
	if d == null:
		return false
	idle = 0.0
	return not d.say_beat(SCENE, beat).is_empty()


func _on_started(id: StringName) -> void:
	if id != SCENE:
		return
	said.clear()
	drawn = false
	idle = 0.0
	var d := director()
	if d:
		d.hold(SCENE, true)
	_hook_arrows()
	say(&"doe")


func _on_finished(id: StringName) -> void:
	if id != SCENE:
		return
	_stop_heart()
	var d := director()
	if d:
		d.hold(SCENE, false)


func _on_cue(actor: StringName, cue: StringName) -> void:
	if actor == &"great_wolf" and cue == &"stalk" and running():
		say(&"eyes")


func _on_hit(_id: StringName, kind: StringName, cause: StringName, _part: StringName) -> void:
	if not running() or kind != &"great_wolf":
		return
	if cause == &"arrow_ash":
		say(&"ash")
	elif not bool(space.get(&"ash_struck")):
		say(&"wood")


func _on_killed(_id: StringName, kind: StringName, _cause: StringName, _at: Vector3) -> void:
	if running() and kind == &"great_wolf" and bool(space.get(&"ash_struck")):
		_stop_heart()
		say(&"kill")


func _process(delta: float) -> void:
	if not running():
		return
	var d := director()
	var speaking := d != null and d.beat_speaking()
	if listen_to_bow:
		_watch_bow()
	if speaking:
		idle = 0.0
		return
	# Real seconds: the bow's slow draw slows the world, not her thinking.
	idle += delta / maxf(Engine.time_scale, 0.01)
	tick()


## The next thought, from what has been said and how long it's been quiet.
func tick() -> void:
	var w := wolf()
	if w == null or not said.has(&"eyes"):
		return
	var struck := bool(space.get(&"ash_struck")) or bool(space.get(&"wolf_dead"))
	if struck:
		return
	if not said.has(&"size"):
		if idle >= SIZE_AFTER:
			say(&"size")
		return
	if drawn:
		return
	if not said.has(&"wait"):
		if idle >= WAIT_AFTER:
			say(&"wait")
		return
	if not said.has(&"nudge_draw"):
		if idle >= NUDGE_DRAW_AFTER:
			say(&"nudge_draw")
		return
	if not said.has(&"nudge_loose") and idle >= NUDGE_LOOSE_AFTER and _has_the_doe(w):
		say(&"nudge_loose")


## A draw (with the wolf out) ends the nudges for good and starts her heart.
func note_draw(drawing: bool) -> void:
	if drawing and wolf() != null:
		drawn = true
		if not heart and not bool(space.get(&"wolf_dead")):
			heart = true
			SoundDirector.cue(HEARTBEAT)
	elif not drawing and heart:
		_stop_heart()


func _watch_bow() -> void:
	var feyre := get_tree().get_first_node_in_group(&"player")
	var bow: Variant = feyre.get(&"bow_controller") if feyre else null
	if bow is BowController:
		note_draw((bow as BowController).is_drawing)


func _stop_heart() -> void:
	if heart:
		heart = false
		SoundDirector.stop_cue(HEARTBEAT, HEARTBEAT_FADE)


## He has seized her (she's down), so the hide is what's at stake.
func _has_the_doe(_w: Node3D) -> bool:
	var doe: Variant = space.get(&"doe")
	if not is_instance_valid(doe):
		return true
	var alive: Variant = (doe as Node).get(&"alive")
	return alive != null and not bool(alive)


## Arrows that land anywhere but in him are misses, once he's out.
func _hook_arrows() -> void:
	if _arrows_hooked or not is_inside_tree():
		return
	_arrows_hooked = true
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
	if node is Arrow:
		var arrow := node as Arrow
		arrow.hit.connect(func(collider: Node, _at: Vector3) -> void: note_landing(collider))
		arrow.broke.connect(func(_at: Vector3) -> void: note_landing(null))


## Where an arrow ended up: anything but the wolf (or the doe) is a miss.
func note_landing(collider: Node) -> void:
	var w := wolf()
	if not running() or w == null or bool(space.get(&"wolf_dead")):
		return
	if collider != null and (collider == w or w.is_ancestor_of(collider)):
		return
	var doe: Variant = space.get(&"doe")
	if collider != null and is_instance_valid(doe) and (collider == doe or (doe as Node).is_ancestor_of(collider)):
		return
	say(&"miss")
