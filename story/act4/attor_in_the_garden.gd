## The Attor in the garden (ch 19, L44). Horror, not combat: she hides.
##   1. By day, once her first painting is done, Tamlin is walking the rose
##      garden's west walk. When she comes up to him the garden goes still
##      (that stillness that means one of the nastier faeries is near): the
##      world withdraws, birdsong stops. Tamlin: "Stay hidden, and no matter
##      what you overhear, don't come out", and he's gone up the walk.
##   2. HIDE: she has HIDE_WINDOW seconds to get into the yew pocket by the
##      arbor herself (Keeper: no push). Out in the open she's found.
##   3. Lucien comes. Something lands (wings, gravel pressed by feet nobody
##      can see) and speaks: a deep, sibilant voice from nowhere (Tamlin's
##      glamour hides it from her and her from it [C ch24]). Mid-way it
##      prowls the walk toward her hedge.
##   4. STILL: while it's there, moving in the hedge rustles. Noise builds
##      with speed (worse when it's close), a hiss warns her, and at NOISE_MAX
##      it has her: fact.attor_detected (permanent) and the scene ends
##      without its deed; she can step out and walk back in to face it again.
##   5. Lucien: "Burn in Hell." Wings, a foul wind through the roses, then
##      silence. Tamlin comes back: "It's gone." -> attor_evaded.
## Lines and marks: data/story/act4/attor_stage.tres.
class_name AttorInTheGarden
extends Act2DreadSpace

const ATTOR_SCENE := "res://creatures/fae/attor.tscn"
const HIDE_WINDOW := 7.0
## The pocket: this close (flat) to the hide mark.
const HIDE_R := 2.3
## Seconds in the open (after the window) before it notices her.
const EXPOSED_MAX := 1.4
## Rustle: speed over STILL_SPEED adds noise; sprinting or jumping adds more.
const STILL_SPEED := 0.6
const NOISE_MAX := 1.0
const NOISE_WARN := 0.45
const NOISE_RATE := 0.5
const NOISE_RUN := 1.8
const NOISE_DECAY := 0.22
const NEAR := 7.0
const NEAR_GAIN := 1.7
const PROWL_SPEED := 1.3
const TAMLIN_STRIDE := 4.6
const PRESENCE_RANGE := 70.0
const HEDGES := [
	# [mark, yaw degrees]: a U of yew round the pocket, open to the house.
	[&"hedge_n", 0.0], [&"hedge_w", 90.0], [&"hedge_e", 90.0],
]

## true while the Attor is there and she has to keep still.
var watching: bool = false
var hidden_in_time: bool = false
var noise: float = 0.0
var exposed: float = 0.0
var detected: bool = false
## Movement reading for tests: returns the speed she moves at (m/s).
var speed_override: Callable
var hedges: Node3D

var _walkers: Dictionary = {}  # actor id -> Array[mark names]
var _walk_speed: Dictionary = {}
var _voice: AudioStreamPlayer3D
var _fx: AudioStreamPlayer3D
var _warned: bool = false
var _step_left: float = 0.0
var _step_side: float = 1.0
var _prev_pos: Vector3 = Vector3.INF
var _dt: float = 0.0


func _init() -> void:
	stage = load("res://data/story/act4/attor_stage.tres") as Act2Stage
	day_only = true
	arrive_height = 0.0


func _ready() -> void:
	super._ready()
	arrive_offset = stage.mark(&"tamlin_idle")
	arrive_radius = 8.0


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_tend_presence()


## Walkers, footfalls and the stillness check run with the scene's own clock
## (tests drive tick() directly).
func tick(delta: float) -> void:
	_dt = delta
	if running:
		for id: StringName in _walkers.keys():
			var route: Array = _walkers[id]
			var who := actor(id)
			if who == null or route.is_empty():
				_walkers.erase(id)
				continue
			if Act4Walk.step(who, mark(route[0]), float(_walk_speed.get(id, 2.0)), delta):
				route.pop_front()
		_footfalls(delta)
		if watching:
			watch(delta)
	if running:
		super.tick(delta)


## The hedge pocket is always there (it's the garden); Tamlin walks the
## west walk while the scene is still to come.
func _tend_presence() -> void:
	if hedges == null and is_inside_tree():
		hedges = Node3D.new()
		hedges.name = "HedgePocket"
		add_child(hedges)
		for h: Array in HEDGES:
			var at := mark(h[0])
			var node := Act4Props.place(hedges, &"yew_hedge", at)
			node.rotation.y = global_rotation.y + deg_to_rad(float(h[1]))
	if running:
		return
	var due := not WorldState.has_flag("attor_evaded") and _gates_met() and _hour_ok() \
			and player_within(PRESENCE_RANGE, mark(&"tamlin_idle"))
	if due and actor(&"tamlin") == null:
		Act4Walk.plant(self, cast(&"tamlin", &"tamlin_idle", &"roses"))
	elif not due and actor(&"tamlin") != null:
		dismiss(&"tamlin")


func _gates_met() -> bool:
	for flag in require_flags:
		if not WorldState.has_flag(flag):
			return false
	return true


func _build_beats() -> Array:
	watching = false
	hidden_in_time = false
	noise = 0.0
	exposed = 0.0
	detected = false
	_warned = false
	_walkers.clear()
	return _flat([
		Beats.run(func(_s: SceneSpace) -> void:
			if actor(&"tamlin") == null:
				Act4Walk.plant(self, cast(&"tamlin", &"tamlin_idle", &"roses"))
			Act4Walk.face(actor(&"tamlin"), mark(&"attor_land")), "tamlin"),
		Beats.mood(&"dread", 0.55, 3.0),
		Beats.run(func(_s: SceneSpace) -> void:
			sound(&"drone", -16.0, 0.85)
			EventBus.face_requested.emit(&"tamlin", &"alert", 0.9, 4.0), "stillness"),
		Beats.wait(2.2),
		say(&"tamlin_stay"),
		Beats.run(func(_s: SceneSpace) -> void:
			_walk(&"tamlin", [&"confront"], TAMLIN_STRIDE)
			sound(&"heartbeat", -14.0), "he's gone"),
		_hide_window(),
		Beats.run(func(_s: SceneSpace) -> void:
			hidden_in_time = true
			watching = true
			Act4Walk.plant(self, cast(&"lucien", &"lucien_in", &"attor_land"))
			_walk(&"lucien", [&"lucien_at"], 3.6), "lucien comes"),
		Beats.wait(2.5),
		Beats.run(func(_s: SceneSpace) -> void: _arrive(), "it lands"),
		Beats.wait(2.6),
		_voiced(&"attor_1"),
		_voiced(&"attor_2"),
		say(&"tamlin_reply"),
		Beats.run(func(_s: SceneSpace) -> void:
			_walk(&"attor", [&"attor_prowl", &"attor_near"], PROWL_SPEED)
			_play(&"chuckle", -6.0), "it prowls"),
		Beats.until(func() -> bool: return not _walkers.has(&"attor"), "it comes close"),
		_voiced(&"attor_3"),
		Beats.wait(1.5),
		Beats.run(func(_s: SceneSpace) -> void: _walk(&"attor", [&"attor_prowl", &"attor_land"], PROWL_SPEED * 1.4), "back"),
		_voiced(&"attor_4"),
		say(&"lucien_burn"),
		Beats.run(func(_s: SceneSpace) -> void: _leave(), "it leaves"),
		Beats.wait(3.0),
		Beats.run(func(_s: SceneSpace) -> void:
			watching = false
			sound(&"heartbeat", -60.0)
			sound(&"drone", -60.0)
			EventBus.mood_requested.emit(&"calm", 0.0, 4.0)
			_walk(&"tamlin", [&"tamlin_round", &"tamlin_back"], 3.4), "silence"),
		Beats.until(func() -> bool: return not _walkers.has(&"tamlin"), "he comes back"),
		Beats.run(func(_s: SceneSpace) -> void:
			Act4Walk.face(actor(&"tamlin"), _feyre_pos())
			EventBus.face_requested.emit(&"tamlin", &"soft", 0.7, 3.0), "his hands"),
		say(&"tamlin_gone"),
		Beats.raise("attor_evaded"),
		Beats.run(func(_s: SceneSpace) -> void:
			dismiss(&"lucien")
			_drop(&"attor"), "after"),
	])


## Waits for her to reach the pocket; at the end of the window, the open is death.
func _hide_window() -> SceneBeat:
	return HideBeat.new()


class HideBeat:
	extends SceneBeat
	var left: float

	func _init() -> void:
		label = "hide"

	func consumes_time() -> bool:
		return true

	func enter(_space: SceneSpace) -> void:
		left = HIDE_WINDOW

	func tick(space: SceneSpace, delta: float) -> bool:
		var s := space as AttorInTheGarden
		if s.in_pocket():
			return true
		left -= delta
		if left <= 0.0:
			s._detected()
		return false


## A line spoken by the voice from nowhere, with the voice sound on it.
func _voiced(line_id: StringName) -> Array:
	return [
		Beats.run(func(_s: SceneSpace) -> void: _speak(true), "voice"),
		say(line_id),
		Beats.run(func(_s: SceneSpace) -> void: _speak(false), "voice off"),
	]


func _flat(list: Array) -> Array:
	var out: Array = []
	for b in list:
		if b is Array:
			out.append_array(b)
		else:
			out.append(b)
	return out


## Feyre is inside the yew pocket, on the ground.
func in_pocket() -> bool:
	var p := player()
	if p == null:
		return false
	var at := mark(&"hide")
	var flat := Vector2(p.global_position.x - at.x, p.global_position.z - at.z).length()
	return flat <= HIDE_R and p.global_position.y < Act4Walk.ground(self, at) + 1.4


## How fast she is moving (m/s, flat).
func feyre_speed(delta: float) -> float:
	if speed_override.is_valid():
		return float(speed_override.call())
	var p := player()
	if p == null:
		return 0.0
	if &"velocity" in p:
		var v: Vector3 = p.get(&"velocity")
		return Vector2(v.x, v.z).length()
	var here := p.global_position
	var s := 0.0 if _prev_pos == Vector3.INF or delta <= 0.0 else (here - _prev_pos).length() / delta
	_prev_pos = here
	return s


## While it's there: the open gives her away; in the pocket, moving rustles.
func watch(delta: float) -> void:
	if detected:
		return
	if not in_pocket():
		exposed += delta
		if exposed >= EXPOSED_MAX:
			_detected()
		return
	exposed = maxf(exposed - delta, 0.0)
	var speed := feyre_speed(delta)
	var rate := 0.0
	if speed > STILL_SPEED:
		rate = NOISE_RUN if speed > 6.0 else NOISE_RATE
	var attor := actor(&"attor")
	if attor and attor.global_position.distance_to(_feyre_pos()) <= NEAR:
		rate *= NEAR_GAIN
	noise = maxf(noise + (rate - (NOISE_DECAY if rate == 0.0 else 0.0)) * delta, 0.0)
	if noise >= NOISE_WARN and not _warned:
		_warned = true
		_play(&"hiss", -4.0)
		StoryControl.shake = 0.15
	elif noise < NOISE_WARN * 0.5:
		_warned = false
	if noise >= NOISE_MAX:
		_detected()


## It has her. Its breath at her ear, wings over her, Tamlin's roar; the
## fact is permanent and the scene ends without its deed.
func _detected() -> void:
	if detected or not running:
		return
	detected = true
	watching = false
	var attor := actor(&"attor")
	if attor == null:
		_arrive()
		attor = actor(&"attor")
	var p := _feyre_pos()
	if attor:
		var side := (attor.global_position - p)
		side.y = 0.0
		attor.global_position = p + (side.normalized() if side.length() > 0.1 else Vector3.FORWARD) * 1.2
	replace_beats([
		Beats.run(func(_s: SceneSpace) -> void:
			_speak(true, 2.0)
			_play(&"shriek", 0.0)
			StoryControl.shake = 0.7
			EventBus.mood_requested.emit(&"dread", 1.0, 0.4)
			veil(0.75, 0.5), "found"),
		Beats.wait(1.4),
		Beats.run(func(_s: SceneSpace) -> void:
			_speak(false)
			_play(&"wings", 2.0)
			_gust_at(p)
			Act4Props.gust_leaves(self, p + Vector3.UP, Vector3.UP), "torn away"),
		Beats.wait(2.0),
		Beats.run(func(_s: SceneSpace) -> void:
			StoryControl.shake = 0.0
			veil(0.0, 1.5)
			_drop(&"attor")
			dismiss(&"lucien")
			abort("fact.attor_detected"), "detected"),
	])


func _arrive() -> void:
	var a := summon(&"attor", ATTOR_SCENE, &"attor_land", &"hide")
	if a == null:
		return
	_voice = AudioStreamPlayer3D.new()
	_voice.name = "Voice"
	_voice.stream = AttorAudio.stream(&"voice")
	_voice.unit_size = 6.0
	_voice.max_db = 6.0
	_voice.position = Vector3.UP * 1.7
	a.add_child(_voice)
	_fx = AudioStreamPlayer3D.new()
	_fx.name = "Fx"
	_fx.unit_size = 10.0
	_fx.position = Vector3.UP * 2.5
	a.add_child(_fx)
	_play(&"wings", 0.0)
	_gust_at(a.global_position)


func _leave() -> void:
	var a := actor(&"attor")
	var at := a.global_position if a else mark(&"attor_land")
	_play(&"wings", 3.0)
	_speak(false)
	_play_flat(&"gust", -2.0)
	Act4Props.gust_leaves(self, at + Vector3.UP * 1.5, (_feyre_pos() - at).normalized())
	StoryControl.shake = 0.25
	get_tree().create_timer(1.2).timeout.connect(func() -> void:
		StoryControl.shake = 0.0
		_drop(&"attor"))


func _speak(on: bool, pitch: float = 1.0) -> void:
	if _voice == null or not is_instance_valid(_voice):
		return
	if on:
		_voice.pitch_scale = 0.92 * pitch if pitch != 1.0 else 0.92
		_voice.volume_db = 2.0
		if not _voice.playing:
			_voice.play()
	else:
		_voice.stop()


func _play(id: StringName, db: float) -> void:
	if _fx == null or not is_instance_valid(_fx):
		_play_flat(id, db)
		return
	_fx.stream = AttorAudio.stream(id)
	_fx.volume_db = db
	_fx.play()


## A non-positional one-shot (the wind is everywhere).
func _play_flat(id: StringName, db: float) -> void:
	if not is_inside_tree():
		return
	var p := AudioStreamPlayer.new()
	p.stream = AttorAudio.stream(id)
	p.volume_db = db
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


## Petals and grit whipped off the gravel where the wings beat.
func _gust_at(at: Vector3) -> void:
	Act4Props.gust_leaves(self, at + Vector3.UP * 0.3, Vector3.UP)


## Gravel pressed by feet nobody can see: a crunch and a puff of grit at each
## step while it walks.
func _footfalls(delta: float) -> void:
	if not _walkers.has(&"attor"):
		return
	var a := actor(&"attor")
	if a == null:
		return
	_step_left -= delta
	if _step_left > 0.0:
		return
	_step_left = 0.62
	_step_side = -_step_side
	var at := a.global_position + a.global_basis.x * 0.35 * _step_side
	at.y = Act4Walk.ground(self, at)
	Act4Props.grit_puff(self, at)
	var crunch := AudioStreamPlayer3D.new()
	crunch.stream = load("res://audio/sfx/foot/stone_%d.ogg" % (1 + randi() % 4))
	crunch.pitch_scale = 0.55
	crunch.volume_db = 4.0
	crunch.unit_size = 8.0
	add_child(crunch)
	crunch.global_position = at
	crunch.play()
	crunch.finished.connect(crunch.queue_free)


func _walk(id: StringName, route: Array, speed: float) -> void:
	_walkers[id] = route.duplicate()
	_walk_speed[id] = speed


func _feyre_pos() -> Vector3:
	var p := player()
	return p.global_position if p else global_position


## Takes an actor out of the world, whoever built it (the creatures lane's
## spawner keeps no claim on a story beast once the scene is done with it).
func _drop(id: StringName) -> void:
	var who := actor(id)
	actors.erase(id)
	if who and is_instance_valid(who):
		who.remove_from_group(StringName("story_actor_%s" % id))
		who.queue_free()
