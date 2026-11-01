## The naga (ch 15, L26): the first fight that can kill her.
##
## Four come out of the backwater, drawn by the Suriel's scream and her scent,
## one after another. Closer after a poor snare, farther if she scouted the
## stream first (SnarePlan.naga_distance). Running water does not stop them.
##   - Five strikes and she falls: black, then she wakes by the waiting oak
##     and the naga are back in the reeds. Try again (the answers are kept).
##   - Arrows: two wood arrows or one ash arrow kill (naga data).
##   - E with a naga in reach: her boot knife (canon, ch 15).
##   - An arrow into the snare's tether frees the Suriel; it bursts out and
##     staggers every naga near it (canon: she shoots the snare).
##   - After her first kill, a second kill, running 28 m from the snare, or
##     holding on 15 s (and never before 15 s of fighting) brings Tamlin out of the trees: he kills the last two
##     (High Fae form, ch 15) and any others flee. Then fact.naga_escaped; the naga moment raises
##     naga_survived.
class_name NagaAmbush
extends SceneSpace

const NAGA_IDS: Array[StringName] = [&"naga", &"naga_2", &"naga_3", &"naga_4"]
const ATTACK_GAP := 2.0
## Two come at her first; the others hang back in the reeds and join one by
## one (a kill, or this long since the last joined). A hunt, not a swarm.
const FIRST_WAVE := 2
const JOIN_EVERY := 7.0
const STRIKES_TO_FALL := 5
## After a blow lands she has this long before the next can (a stagger, not a stun-lock).
const STRIKE_GRACE := 1.2
const KNIFE_REACH := 2.4
const KNIFE_DAMAGE := 6.0
## A boot knife is close and slow: one stab per this many seconds.
const KNIFE_COOLDOWN := 0.7
const TETHER_REACH := 2.0
const STAGGER_RADIUS := 14.0
const STAGGER_SECONDS := 2.5
const RUN_CLEAR := 28.0
const HOLD_SECONDS := 15.0
## Tamlin is never there sooner than this after the first naga moves.
const TAMLIN_EARLIEST := 12.0
const FALL_SECONDS := 2.5

var snare_at: Vector3 = Vector3.INF
## Toward the reeds the naga come out of (world, flat). Set by Act3Anchors.
var backwater_dir: Vector3 = Vector3.BACK
## Where she wakes after a fall (the waiting oak). Set by Act3Anchors.
var wake_at: Vector3 = Vector3.INF
var ground_fn: Callable = func(p: Vector3) -> float: return WorldHeight.height_at(p.x, p.z)

var naga: Dictionary = {}
var strikes: int = 0
var kills: int = 0
var falls: int = 0
var freed: bool = false
var tamlin_came: bool = false

var _t: float = 0.0
var _cued: int = 0
var _last_join: float = 0.0
var _since_kill: float = -1.0
var _falling: float = -1.0
var _fail: bool = false
var _hooked_player: Node = null
var _knife_cd: float = 0.0
var _grace: float = 0.0
## After a fall: seconds before the naga come again (old ones must be gone).
var _rest: float = 0.0
## Seconds she lies still after she wakes before they come again.
const REST_SECONDS := 4.0


func _init() -> void:
	space_id = &"naga_ambush"
	require_flags = PackedStringArray(["fact.suriel_answered"])
	done_flags = PackedStringArray(["fact.naga_escaped"])
	auto_start = true


func _ready() -> void:
	super._ready()
	EventBus.creature_killed.connect(_on_killed)


func can_start() -> bool:
	return _rest <= 0.0 and super.can_start()


func _physics_process(delta: float) -> void:
	_rest = maxf(0.0, _rest - delta)
	super._physics_process(delta)


func _build_beats() -> Array:
	strikes = 0
	kills = 0
	freed = false
	tamlin_came = false
	_t = 0.0
	_last_join = 0.0
	_knife_cd = 0.0
	_grace = 0.0
	_cued = 0
	_since_kill = -1.0
	_falling = -1.0
	_fail = false
	if snare_at == Vector3.INF:
		snare_at = global_position
	return [
		Beats.mood(&"dread", 0.95, 1.0, 0.2),
		Beats.run(func(_s: SceneSpace) -> void: _spawn_naga(), "spawn naga"),
		Beats.control(StoryControl.Mode.FULL),
		FightBeat.new(),
		Beats.mood(&"dread", 0.3, 2.0),
		Beats.raise("fact.naga_escaped"),
	]


func _spawn_naga() -> void:
	var q := float(WorldState.get_flag("fact.suriel_snare_quality", 0.5))
	var d := SnarePlan.naga_distance(q, bool(WorldState.get_flag("fact.suriel_scouted", false)))
	var base := Vector3(backwater_dir.x, 0.0, backwater_dir.z).normalized()
	if base == Vector3.ZERO:
		base = Vector3.BACK
	var spread := [0.0, 0.7, -0.7, 1.4]
	naga.clear()
	for i in NAGA_IDS.size():
		var at := snare_at + base.rotated(Vector3.UP, spread[i]) * (d + i * 1.5)
		at.y = ground_fn.call(at)
		var xform := Transform3D(Basis.IDENTITY, at).looking_at(Vector3(snare_at.x, at.y, snare_at.z), Vector3.UP)
		var id: StringName = NAGA_IDS[i]
		var node := request_actor(id, xform, func() -> Node3D: return StandIns.figure(String(id)))
		naga[id] = node
		if node.has_signal(&"struck_player") and not node.is_connected(&"struck_player", _on_struck):
			node.connect(&"struck_player", _on_struck)
	_hook_player()


func _hook_player() -> void:
	var p := player()
	if p == null or p == _hooked_player or not p.has_signal(&"arrow_fired"):
		return
	_hooked_player = p
	p.connect(&"arrow_fired", func(arrow: Node3D) -> void:
		if arrow.has_signal(&"hit"):
			arrow.connect(&"hit", func(_c: Node, at: Vector3) -> void: arrow_landed(at)))


## Where an arrow struck; the tether is the snare.
func arrow_landed(at: Vector3) -> void:
	if not running or freed or SurielSnare._flat(at, snare_at) > TETHER_REACH:
		return
	freed = true
	EventBus.story_actor_cue.emit(&"suriel", &"freed")
	StoryControl.shake = 0.35
	for id: StringName in naga:
		var n := naga[id] as Node3D
		if is_instance_valid(n) and SurielSnare._flat(n.global_position, snare_at) <= STAGGER_RADIUS:
			EventBus.story_actor_cue.emit(id, &"stagger")


func _unhandled_input(event: InputEvent) -> void:
	super._unhandled_input(event)
	if running and event.is_action_pressed(&"interact"):
		knife()


## Her boot knife, into the nearest naga in reach. Returns true on a hit.
func knife() -> bool:
	var p := player()
	if p == null or not running:
		return false
	var best: Creature = null
	var best_d := KNIFE_REACH
	for id: StringName in naga:
		var c := naga[id] as Creature
		if c and is_instance_valid(c) and c.alive and c.global_position.distance_to(p.global_position) <= best_d:
			best = c
			best_d = c.global_position.distance_to(p.global_position)
	if best == null or _knife_cd > 0.0:
		return false
	_knife_cd = KNIFE_COOLDOWN
	best.health -= KNIFE_DAMAGE
	EventBus.creature_hit.emit(best.creature_id, best.data.kind, &"knife", &"body")
	if best.health <= 0.0:
		best.die(&"knife")
	else:
		best._on_wounded(p.global_position, &"knife")
		# The blade drives it back a step: room to nock an arrow.
		EventBus.story_actor_cue.emit(best.creature_id, &"stagger")
	return true


func _on_struck(_who: Node3D = null) -> void:
	strike()


## A naga's blow lands on her.
func strike() -> void:
	if not running or _falling >= 0.0 or tamlin_came or _grace > 0.0:
		return
	_grace = STRIKE_GRACE
	strikes += 1
	StoryControl.shake = 0.6
	EventBus.mood_requested.emit(&"dread", 1.0, 0.15)
	if strikes >= STRIKES_TO_FALL:
		_fall()


func _fall() -> void:
	falls += 1
	_falling = FALL_SECONDS
	StoryControl.set_mode(StoryControl.Mode.NONE)
	EventBus.mood_requested.emit(&"dread", 1.0, 0.6)


func _on_killed(_id: StringName, kind: StringName, _cause: StringName, _at: Vector3) -> void:
	if running and kind == &"naga":
		kills += 1
		if _since_kill < 0.0:
			_since_kill = 0.0


func _fight(delta: float) -> bool:
	if _falling >= 0.0:
		_falling -= delta
		if _falling < 0.0:
			_wake()
			return false
		return false
	_t += delta
	_knife_cd = maxf(0.0, _knife_cd - delta)
	_grace = maxf(0.0, _grace - delta)
	if _cued < NAGA_IDS.size():
		var due := _t >= _cued * ATTACK_GAP if _cued < FIRST_WAVE else \
				(_t - _last_join >= JOIN_EVERY or kills >= _cued - FIRST_WAVE + 1)
		if due:
			EventBus.story_actor_cue.emit(NAGA_IDS[_cued], &"attack")
			_cued += 1
			_last_join = _t
	if _since_kill >= 0.0:
		_since_kill += delta
		var p := player()
		var ran := p != null and SurielSnare._flat(p.global_position, snare_at) >= RUN_CLEAR
		if _t >= TAMLIN_EARLIEST and (kills >= 2 or ran or _since_kill >= HOLD_SECONDS):
			_tamlin()
			return true
	return false


func _tamlin() -> void:
	tamlin_came = true
	var p := player()
	var at := (p.global_position if p else snare_at) + Vector3(0.0, 0.0, -4.0)
	request_actor(&"tamlin", Transform3D(Basis.IDENTITY, at), func() -> Node3D: return StandIns.figure("tamlin"))
	EventBus.story_actor_cue.emit(&"tamlin", &"tears_a_throat")
	# Canon (ch 15): he shreds one's neck and brings down the last; any
	# others left slide back to the reeds.
	var torn := 0
	for id: StringName in naga:
		var c := naga[id] as Creature
		if c == null or not is_instance_valid(c) or not c.alive:
			continue
		if torn < 2:
			torn += 1
			c.die(&"tamlin")
		else:
			EventBus.story_actor_cue.emit(id, &"flee")
	StoryControl.shake = 0.0


## She wakes by the oak; the naga are gone back to the reeds. The scene can
## start again once she has stepped out and back (SceneSpace._must_leave).
func _wake() -> void:
	for id: StringName in naga:
		var n := naga[id] as Node3D
		if is_instance_valid(n):
			n.queue_free()
	naga.clear()
	var p := player()
	if p and wake_at != Vector3.INF:
		p.global_position = wake_at + Vector3.UP * 0.3
	_fail = true
	_rest = REST_SECONDS
	running = false
	StoryControl.release()
	EventBus.mood_requested.emit(&"dread", 0.5, 2.0)
	EventBus.scene_space_finished.emit(space_id)


class FightBeat:
	extends SceneBeat

	func _init() -> void:
		label = "naga fight"

	func consumes_time() -> bool:
		return true

	func tick(space: SceneSpace, delta: float) -> bool:
		return (space as NagaAmbush)._fight(delta)
