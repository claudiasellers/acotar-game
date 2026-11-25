## The opening hunt before the doe (L80; Keeper: ch1 stays "fruitless" until
## the doe). On the doe trail she passes one of her own snares, empty; a
## rabbit grazes a little farther on. Its ears come up when she nocks and it
## bolts at release; it can't be killed or skinned (data/story/act1/
## hare_ch1.tres), and an arrow that finds it drops in the snow, so she always
## gets it back. KeyPrompts names the keys (check, draw, pick up); this node
## only stages the world and her thoughts. No flags, markers or text (R2).
##
## It also makes the stamina bow read: running is free, so the first thing to
## spend it is a held draw or a held breath (Focus). The first time it falls
## under WINDED_AT before the wolf is dead she thinks about her empty belly,
## with the meter draining in front of the player. (Cold and hunger explain
## themselves on their own chips, vitals lane.)
class_name OpeningHunt
extends Node

const SNARE_MESH := "res://world/human_realm/hunting_forest/assets/props/snare.glb"
const RABBIT_SCENE := preload("res://creatures/prey/hare.tscn")
const RABBIT_DATA := preload("res://data/story/act1/hare_ch1.tres")
const THOUGHTS := {
	&"snare": "res://data/guide/onboarding/snare.tres",
	&"rabbit_gone": "res://data/guide/onboarding/rabbit_gone.tres",
	&"winded": "res://data/guide/onboarding/winded.tres",
	&"three_arrows": "res://data/guide/onboarding/three_arrows.tres",
}
const GROUP := &"opening_hunt"
const SNARE_GROUP := &"opening_snare"
const RABBIT_GROUP := &"opening_rabbit"
const STATION_ID := &"snare"
## Metres along the doe trail from its start (Act1Wayfinding.TRAIL_END), and
## to the side of it.
const SNARE_ALONG := 80.0
const SNARE_SIDE := 2.4
const RABBIT_AHEAD := 12.0
## Metres further than RABBIT_AHEAD tried for the rabbit, nearest first.
const RABBIT_TRIES: Array[float] = [0.0, 2.0, -2.0, 4.0]
## Her eye and the rabbit's back above the snow, and how far her line to it
## must clear the ground between them.
const EYE_HEIGHT := 1.5
const RABBIT_SEEN_AT := 0.2
const SEEN_OVER := 0.15
## Albedo luminance above which a surface of the model is its pale coat, and
## above which it is the white of its belly and tail.
const PALE := 0.5
const WHITE := 0.85
const RABBIT_SIDE := 3.5
## Metres either way of SNARE_ALONG tried for the snare, and how much open
## ground round it is enough (a snow-laden fir's boughs reach about 4 m).
const SNARE_TRIES: Array[float] = [0.0, -1.5, 1.5, -3.0, 3.0, -4.5, 4.5]
const SNARE_OPEN := 5.0
## How far a trunk or rock must stand off her line from the snare to the rabbit.
const SIGHT_MARGIN := 3.0
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

static var _snare_spot := Vector2.INF
static var _rabbit_spot := Vector2.INF

var snare: Node3D
var rabbit: Prey
var snare_checked: bool = false
var rabbit_done: bool = false
var winded_shown: bool = false
var arrows_shown: bool = false
var _bolted_for: float = -1.0
var _was_nocked: bool = false
var _release_hooked: bool = false
var _queued: Array[StringName] = []


func _ready() -> void:
	name = "OpeningHunt"
	add_to_group(GROUP)
	SaveSystem.register_provider(SAVE_KEY, self)
	EventBus.creature_hit.connect(_on_creature_hit)


func _exit_tree() -> void:
	SaveSystem.unregister_provider(SAVE_KEY)


func save_state() -> Dictionary:
	return {"snare": snare_checked, "rabbit": rabbit_done, "winded": winded_shown, "arrows": arrows_shown}


func load_state(data: Dictionary) -> void:
	snare_checked = bool(data.get("snare", false))
	rabbit_done = bool(data.get("rabbit", false)) or snare_checked
	winded_shown = bool(data.get("winded", false))
	arrows_shown = bool(data.get("arrows", false))


## Where the snare sits: about SNARE_ALONG metres down the doe trail, to its
## side, at the spot with the most open sky: a fir's boughs over the snare
## swallow her camera as she bends to it.
static func snare_spot() -> Vector2:
	if _snare_spot != Vector2.INF:
		return _snare_spot
	var obstacles := Act1Wayfinding.trail_obstacles(PackedVector2Array([
		_along_trail(SNARE_ALONG - 12.0, 0.0), _along_trail(SNARE_ALONG + RABBIT_AHEAD + 12.0, 0.0)]))
	var best := -1.0
	for along: float in SNARE_TRIES:
		for side: float in [SNARE_SIDE, -SNARE_SIDE]:
			var spot := _along_trail(SNARE_ALONG + along, side)
			var open := _open_round(spot, obstacles)
			if open > best:
				best = open
				_snare_spot = spot
			if open >= SNARE_OPEN:
				return spot
	return _snare_spot


## Metres from `p` to the nearest trunk or rock (its own radius taken off).
static func _open_round(p: Vector2, obstacles: Array[Vector3]) -> float:
	var open := INF
	for o in obstacles:
		open = minf(open, p.distance_to(Vector2(o.x, o.y)) - o.z)
	return open


## Where the rabbit grazes: about RABBIT_AHEAD metres from the snare, where
## she sees it whole from the snare (no rise of snow in the way) and no
## trunk, bough or rock stands near the line, so the shot she misses is hers.
static func rabbit_spot() -> Vector2:
	if _rabbit_spot != Vector2.INF:
		return _rabbit_spot
	var from := snare_spot()
	var obstacles := Act1Wayfinding.trail_obstacles(PackedVector2Array([
		_along_trail(SNARE_ALONG - 12.0, 0.0), _along_trail(SNARE_ALONG + RABBIT_AHEAD + 16.0, 0.0)]))
	var ahead := (_along_trail(SNARE_ALONG + RABBIT_AHEAD, 0.0) - from).normalized()
	var best := -INF
	for further: float in RABBIT_TRIES:
		for a in 32:
			# The trail's own direction first, out to a quarter turn either way.
			var spot := from + ahead.rotated((a + 1) / 2 * (PI / 32.0) * (1.0 if a % 2 == 0 else -1.0)) \
					* (RABBIT_AHEAD + further)
			var open := minf(Act1Wayfinding.sight_open(from, spot, obstacles), SIGHT_MARGIN)
			var score := open + (SIGHT_MARGIN if _seen_over_snow(from, spot) >= SEEN_OVER else 0.0)
			if score > best:
				best = score
				_rabbit_spot = spot
			if score >= SIGHT_MARGIN * 2.0:
				return spot
	return _rabbit_spot


## How far (m) her line of sight from a to the animal at b clears the snow at
## its lowest: negative when a rise hides it.
static func _seen_over_snow(a: Vector2, b: Vector2) -> float:
	var eye := WorldHeight.height_at(a.x, a.y) + EYE_HEIGHT
	var body := WorldHeight.height_at(b.x, b.y) + RABBIT_SEEN_AT
	var clear := INF
	for i in range(1, 16):
		var t := i / 16.0
		var p := a.lerp(b, t)
		clear = minf(clear, lerpf(eye, body, t) - WorldHeight.height_at(p.x, p.y))
	return clear


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
	_watch_first_nock(feyre)
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
		# Side-on to her, where it shows its whole length.
		var to_her := feyre.global_position - r.global_position
		r.look_at(r.global_position + Vector3(-to_her.z, 0.0, to_her.x), Vector3.UP, true)
	_brown(r)
	r.home = r.global_position
	_bolted_for = -1.0
	return r


## The model's pale winter coat is lost on snow at this range: its light
## surfaces take the brown of this rabbit's data (coat above, belly below).
func _brown(r: Node) -> void:
	for mesh: MeshInstance3D in r.find_children("*", "MeshInstance3D", true, false):
		for i in mesh.get_surface_override_material_count():
			# A BaseMaterial3D or the CandyMaterial an imported model wears: both carry albedo_color.
			var mat := mesh.get_active_material(i)
			var albedo: Variant = mat.get(&"albedo_color") if mat else null
			if not albedo is Color or (albedo as Color).get_luminance() < PALE:
				continue
			var coat := mat.duplicate()
			coat.set(&"albedo_color", RABBIT_DATA.belly_color if (albedo as Color).get_luminance() > WHITE else RABBIT_DATA.coat_color)
			mesh.set_surface_override_material(i, coat)


## Calm until she's close or nocks; ears up on the nock; gone at the release.
func _steer_rabbit(feyre: Feyre, delta: float) -> void:
	if not is_instance_valid(rabbit):
		rabbit = null
		return
	var nocked := feyre.bow_controller != null and feyre.bow_controller.is_nocked
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
	elif _bolted_for >= 0.0:
		# It has run as far as it runs: it doesn't settle where she can walk up to it.
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


## The first arrow she ever puts to the string: what she carries, and which
## one matters (UX review O6). Only while the ash arrow is still hers.
func _watch_first_nock(feyre: Feyre) -> void:
	if arrows_shown or feyre.bow_controller == null or not feyre.bow_controller.is_nocked:
		return
	arrows_shown = true
	if Gameplay.inventory.arrow_count(&"arrow_ash") > 0:
		_think(&"three_arrows")


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
