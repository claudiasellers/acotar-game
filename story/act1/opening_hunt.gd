## The opening hunt before the doe (L80; Keeper: ch1 stays "fruitless" until
## the doe). On the doe trail she passes one of her own snares, empty; a
## rabbit grazes a little farther on. Its ears come up when she nocks and it
## bolts at release; it can't be killed or skinned (data/story/act1/
## hare_ch1.tres), and an arrow that finds it drops in the snow, so she always
## gets it back. KeyPrompts names the keys (check, draw, pick up); this node
## only stages the world and her thoughts. No flags, markers or text (R2).
##
## It also lets her first big sprint read on the HUD: the first time her
## stamina runs low before the wolf, she thinks about her empty belly while
## the stamina bow drains in front of the player.
class_name OpeningHunt
extends Node

const SNARE_MESH := "res://world/human_realm/hunting_forest/assets/props/snare.glb"
const RABBIT_SCENE := preload("res://creatures/prey/hare.tscn")
const RABBIT_DATA := preload("res://data/story/act1/hare_ch1.tres")
const THOUGHTS := {
	&"snare": "res://data/guide/onboarding/snare.tres",
	&"rabbit_gone": "res://data/guide/onboarding/rabbit_gone.tres",
	&"winded": "res://data/guide/onboarding/winded.tres",
}
const SNARE_GROUP := &"opening_snare"
const RABBIT_GROUP := &"opening_rabbit"
const STATION_ID := &"snare"
## Metres along the doe trail from its start (Act1Wayfinding.TRAIL_END), and
## to the side of it.
const SNARE_ALONG := 80.0
const SNARE_SIDE := 2.4
const RABBIT_AHEAD := 20.0
const RABBIT_SIDE := 3.5
## The snare is built once she's this close (inside the terrain's collision ring).
const BUILD_RADIUS := 60.0
## The rabbit ignores her until she's this close or she nocks.
const CALM_UNTIL := 8.0
const NOCK_AWARENESS := 0.35
## Gone this far away, or this long after it bolted, the rabbit leaves.
const GONE_DISTANCE := 45.0
const GONE_SECONDS := 10.0
const WINDED_AT := 0.4
const DONE_FLAG := "fact.wolf_spotted"
const SAVE_KEY := "opening_hunt"

var snare: Node3D
var rabbit: Prey
var snare_checked: bool = false
var rabbit_done: bool = false
var winded_shown: bool = false
var _bolted_for: float = -1.0
var _was_nocked: bool = false
var _release_hooked: bool = false
var _queued: Array[StringName] = []


func _ready() -> void:
	name = "OpeningHunt"
	SaveSystem.register_provider(SAVE_KEY, self)
	EventBus.creature_hit.connect(_on_creature_hit)


func _exit_tree() -> void:
	SaveSystem.unregister_provider(SAVE_KEY)


func save_state() -> Dictionary:
	return {"snare": snare_checked, "rabbit": rabbit_done, "winded": winded_shown}


func load_state(data: Dictionary) -> void:
	snare_checked = bool(data.get("snare", false))
	rabbit_done = bool(data.get("rabbit", false)) or snare_checked
	winded_shown = bool(data.get("winded", false))


## Where the snare sits: SNARE_ALONG metres down the doe trail, to its side.
static func snare_spot() -> Vector2:
	return _along_trail(SNARE_ALONG, SNARE_SIDE)


## Where the rabbit grazes: RABBIT_AHEAD metres past the snare.
static func rabbit_spot() -> Vector2:
	return _along_trail(SNARE_ALONG + RABBIT_AHEAD, -RABBIT_SIDE)


static func _along_trail(metres: float, side: float) -> Vector2:
	var pts := Act1Wayfinding.track_points()
	var walked := 0.0
	for i in range(1, pts.size()):
		var leg := pts[i].distance_to(pts[i - 1])
		if walked + leg >= metres:
			var at := pts[i - 1].lerp(pts[i], (metres - walked) / maxf(leg, 0.001))
			var dir := (pts[i] - pts[i - 1]).normalized()
			return at + Vector2(-dir.y, dir.x) * side
		walked += leg
	return pts[pts.size() - 1]


func _process(delta: float) -> void:
	var feyre := get_tree().get_first_node_in_group(&"player") as Feyre
	if feyre == null or WorldState.has_flag(DONE_FLAG):
		_clear()
		return
	if not _release_hooked:
		_release_hooked = true
		feyre.bow_released.connect(func(at: Vector3, _loudness: float) -> void: on_release(at))
	_watch_winded(feyre)
	var at := Vector2(feyre.global_position.x, feyre.global_position.z)
	if not snare_checked and snare == null and at.distance_to(snare_spot()) <= BUILD_RADIUS:
		snare = _build_snare()
	if rabbit:
		_steer_rabbit(feyre, delta)
	_try_think()


## Her own snare, empty (station "snare": Interactor's E uses it).
func _build_snare() -> Node3D:
	var node := OpeningSnare.new()
	node.name = "OpeningSnare"
	node.hunt = self
	node.add_to_group(SNARE_GROUP)
	node.add_to_group(&"station")
	if ResourceLoader.exists(SNARE_MESH):
		node.add_child((load(SNARE_MESH) as PackedScene).instantiate())
	add_child(node)
	node.global_position = _ground(snare_spot())
	return node


## E on the snare: it's empty. Then a rabbit, a little farther on.
func check_snare() -> void:
	if snare_checked:
		return
	snare_checked = true
	if is_instance_valid(snare):
		snare.remove_from_group(&"station")
	_think(&"snare")
	if not rabbit_done:
		rabbit = _spawn_rabbit()


func _spawn_rabbit() -> Prey:
	var r := RABBIT_SCENE.instantiate() as Prey
	r.data = RABBIT_DATA
	r.name = "OpeningRabbit"
	r.creature_id = &"opening_rabbit"
	r.add_to_group(RABBIT_GROUP)
	add_child(r)
	var spot := rabbit_spot()
	r.global_position = _ground(spot)
	var feyre := get_tree().get_first_node_in_group(&"player") as Node3D
	if feyre:
		r.look_at(Vector3(feyre.global_position.x, r.global_position.y, feyre.global_position.z), Vector3.UP, true)
	r.home = r.global_position
	_bolted_for = -1.0
	return r


## Calm until she's close or nocks; ears up on the nock; gone at the release.
func _steer_rabbit(feyre: Feyre, delta: float) -> void:
	if not is_instance_valid(rabbit):
		rabbit = null
		return
	var nocked := feyre.bow_controller != null and feyre.bow_controller.is_nocked()
	if rabbit.state != Prey.State.FLEE:
		var near := feyre.global_position.distance_to(rabbit.global_position) <= CALM_UNTIL
		if nocked and not _was_nocked:
			rabbit.senses.stimulate(&"sound", feyre.global_position, maxf(NOCK_AWARENESS - rabbit.senses.awareness, 0.01))
		elif not near:
			rabbit.senses.awareness = minf(rabbit.senses.awareness, NOCK_AWARENESS if nocked else 0.2)
	_was_nocked = nocked
	if rabbit.state == Prey.State.FLEE:
		_bolted_for = maxf(_bolted_for, 0.0) + delta
		if _bolted_for >= GONE_SECONDS or feyre.global_position.distance_to(rabbit.global_position) >= GONE_DISTANCE:
			_rabbit_gone()


## Her bow release (hooked on first sight of her): the rabbit bolts.
func on_release(at: Vector3) -> void:
	if rabbit and is_instance_valid(rabbit) and rabbit.state != Prey.State.FLEE:
		rabbit.senses.stimulate(&"sound", at, 1.0)


func _rabbit_gone() -> void:
	_drop_arrows(rabbit)
	rabbit.queue_free()
	rabbit = null
	rabbit_done = true
	_think(&"rabbit_gone")


## An arrow that finds the rabbit falls into the snow beside it.
func _on_creature_hit(id: StringName, _kind: StringName, _cause: StringName, _part: StringName) -> void:
	if id == &"opening_rabbit" and rabbit:
		_drop_arrows.call_deferred(rabbit)


func _drop_arrows(from: Node) -> void:
	if not is_instance_valid(from):
		return
	for child in from.get_children():
		if child is Arrow:
			var spot := (child as Arrow).global_position
			(child as Arrow).reparent(self, true)
			(child as Arrow).global_position = _ground(Vector2(spot.x, spot.z)) + Vector3.UP * 0.08


func _watch_winded(feyre: Feyre) -> void:
	if winded_shown or WorldState.has_flag("wolf_killed"):
		return
	if feyre.stamina < feyre.max_stamina * WINDED_AT:
		winded_shown = true
		_think(&"winded")


func _think(id: StringName) -> void:
	_queued.append(id)
	_try_think()


func _try_think() -> void:
	if _queued.is_empty():
		return
	var journal := get_tree().get_first_node_in_group(GuideSettings.GROUP) as GuideJournal
	if journal == null or journal.mode != GuideSettings.Mode.AUTO:
		_queued.clear()
		return
	if journal.showing or not journal.can_show():
		return
	var thread := load(THOUGHTS[_queued.pop_front()]) as GuideThread
	journal.director.note_progress()
	journal.show_thought(thread, 0, false)


func _clear() -> void:
	if is_instance_valid(snare):
		snare.queue_free()
	snare = null
	if is_instance_valid(rabbit):
		_drop_arrows(rabbit)
		rabbit.queue_free()
	rabbit = null


func _ground(p: Vector2) -> Vector3:
	return Vector3(p.x, WorldHeight.height_at(p.x, p.y) + 0.02, p.y)
