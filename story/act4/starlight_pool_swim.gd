## The pool of starlight (ch 18, L44). A deed, found and not given:
##   1. PICNIC: once the faerie is mourned (summer_faerie_comforted), Tamlin
##      and Lucien have spread the purple blanket on the glen's shore, well
##      away from the pool. Lucien stays on it with the wine.
##   2. Walking up to them starts the scene. Tamlin: "I want to show you
##      something", and the dare [X]: find it before he does. He strolls
##      after her down to the stream; nothing marks the way. The pool hides
##      in the Glimmer Hollow below the falls.
##   3. FOUND: when she reaches the hollow's rim (within RIM_REACH of the
##      water) the light turns pearly (vista). Tamlin catches up: his old
##      haunt as a boy, then "Jump in" (canon order: both before the swim).
##   4. DEED: she jumps or wades into the water (within POOL_IN of its
##      centre, at or under the surface): a splash, starlight clinging to her,
##      and starlight_pool_found through an ActionTrigger. Jumping in early
##      counts the moment he has finished speaking.
##   5. He swims out to her and tells Lucien's history (Keeper: Tamlin tells
##      it here; journal lucien_autumn_history). The afternoon fades to gold
##      and she's set on the bank. No knife (Keeper: no gift in ch 18).
## Canon notes and lines: data/story/act4/starlight_pool_stage.tres.
class_name StarlightPoolSwim
extends Act2Space

## She has found it: this close (flat) to the pool's centre.
const RIM_REACH := 40.0
## In the pool: this close (flat) to the centre (habitat radius 18 m).
const POOL_IN := 15.5
## The picnic is laid out once she is this close to the blanket.
const PICNIC_RANGE := 220.0
const STROLL := 1.6
const CATCH_UP := 4.2
const GRADE_SPARKLE := &"grade_starlight_pool_sparkle"
const GRADE_DAY := &"grade_starlight_glen_day"

## found -> she reached the rim; dared -> his two lines are said.
var found: bool = false
var dared: bool = false
var swum: bool = false
var picnic: Node3D

var _stroll_route: Array[StringName] = []
var _stroll_on: bool = false
var _splash: GPUParticles3D
var _dt: float = 0.0


func _init() -> void:
	stage = load("res://data/story/act4/starlight_pool_stage.tres") as Act2Stage
	arrive_height = 0.0


func _ready() -> void:
	super._ready()
	# The scene starts at the blanket, not at the anchor by the pool.
	arrive_offset = stage.mark(&"blanket")
	arrive_radius = 7.0


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_tend_picnic()


## Tamlin's stroll runs on the scene's own clock (tests drive tick()).
func tick(delta: float) -> void:
	_dt = delta
	if _stroll_on and running:
		var who := actor(&"tamlin")
		if who == null and not _stroll_route.is_empty():
			who = cast(&"tamlin", _stroll_route[0], &"pool")
			Act4Walk.plant(self, who)
		if who and not _stroll_route.is_empty():
			if Act4Walk.step(who, mark(_stroll_route[0]), STROLL, delta):
				_stroll_route.pop_front()
	super.tick(delta)


## The picnic is there while the scene is still to come or running, and is
## packed away after.
func _tend_picnic() -> void:
	var wanted := not done() and _gates_met() and (running or player_within(PICNIC_RANGE, mark(&"blanket")))
	if wanted and picnic == null:
		_lay_picnic()
	elif not wanted and picnic != null and not running:
		picnic.queue_free()
		picnic = null
		dismiss(&"tamlin")
		dismiss(&"lucien")


func done() -> bool:
	return WorldState.has_flag("starlight_pool_found")


func _gates_met() -> bool:
	for flag in require_flags:
		if not WorldState.has_flag(flag):
			return false
	return true


func _lay_picnic() -> void:
	picnic = Act4Props.picnic(self, mark(&"blanket"), mark(&"pool"))
	Act4Walk.plant(self, cast(&"lucien", &"lucien_seat", &"pool"))
	Act4Walk.plant(self, cast(&"tamlin", &"tamlin_wait", &"blanket_view"))


func _build_beats() -> Array:
	found = false
	dared = false
	swum = false
	_stroll_on = false
	var out: Array = [
		Beats.run(func(_s: SceneSpace) -> void:
			if picnic == null:
				_lay_picnic(), "picnic"),
		say(&"tamlin_show"),
		say(&"tamlin_dare"),
		Beats.run(func(_s: SceneSpace) -> void:
			_stroll_route = [&"trail_1", &"trail_2", &"trail_3", &"tamlin_rim"]
			_stroll_on = true, "tamlin strolls"),
		Beats.until(func() -> bool: return _in_reach(RIM_REACH), "find the pool"),
		Beats.run(func(_s: SceneSpace) -> void:
			found = true
			EventBus.grade_swap_requested.emit(GRADE_SPARKLE, 2.5)
			EventBus.celebration_requested.emit(&"vista", mark(&"pool"))
			delight(&"unlock", &"pool"), "found"),
		Beats.until(func() -> bool: return _tamlin_caught_up(), "tamlin catches up"),
		say(&"tamlin_haunt"),
		say(&"tamlin_jump"),
		Beats.run(func(_s: SceneSpace) -> void: dared = true, "dared"),
		Beats.until(func() -> bool: return in_pool(), "into the water"),
		Beats.run(func(_s: SceneSpace) -> void: _splash_in(), "splash"),
		Beats.raise("starlight_pool_found"),
		Beats.run(func(_s: SceneSpace) -> void:
			swum = true
			EventBus.celebration_requested.emit(&"deed", _feyre_pos())
			_swim_out(), "he swims out"),
		Beats.wait(1.5),
		say(&"tamlin_lucien_1"),
		say(&"tamlin_lucien_2"),
		say(&"tamlin_lucien_3"),
		Beats.run(func(_s: SceneSpace) -> void:
			EventBus.journal_entry_added.emit(&"lucien_autumn_history"), "journal"),
		Beats.wait(2.0),
	]
	out.append_array(fade_time(17.25 / 24.0, func() -> void:
		place_feyre(Act4Walk.ground_point(self, mark(&"bank")))
		var t := actor(&"tamlin")
		if t:
			t.global_position = Act4Walk.ground_point(self, mark(&"tamlin_bank"))
			Act4Walk.face(t, _feyre_pos())
		EventBus.grade_swap_requested.emit(GRADE_DAY, 3.0), "golden hour"))
	out.append(say(&"tamlin_after"))
	return out


func _feyre_pos() -> Vector3:
	var p := player()
	return p.global_position if p else global_position


func _in_reach(r: float) -> bool:
	var p := player()
	if p == null:
		return false
	var c := mark(&"pool")
	return Vector2(p.global_position.x - c.x, p.global_position.z - c.z).length() <= r


## Feyre is in the water: inside the pool and not standing above its surface.
func in_pool() -> bool:
	if not _in_reach(POOL_IN):
		return false
	var p := player()
	var level := water_level()
	return is_nan(level) or p.global_position.y <= level + 0.25


## The pool's surface height (NaN when the court has no basin here).
func water_level() -> float:
	var c := mark(&"pool")
	var best := NAN
	var best_d := INF
	for lake in CourtHeight.lakes():
		var d := Vector2(c.x, c.z).distance_to(lake["center"])
		if d < float(lake["radius"]) + 4.0 and d < best_d:
			best_d = d
			best = float(lake["level"])
	return best


## He walks on (and jogs once she has found it) until he is beside her.
func _tamlin_caught_up() -> bool:
	var who := actor(&"tamlin")
	if who == null:
		return true
	var p := player()
	if p == null:
		return true
	_stroll_on = false
	var to := p.global_position + (who.global_position - p.global_position).normalized() * 2.2
	if Act4Walk.step(who, to, CATCH_UP, _dt):
		Act4Walk.face(who, p.global_position)
		return true
	return false


func _splash_in() -> void:
	var at := _feyre_pos()
	var level := water_level()
	if not is_nan(level):
		at.y = level
	Juice.burst(null, &"outfit", at + Vector3.UP * 0.4)
	if is_inside_tree():
		_splash = Act4Props.splash(self, at)
		Act4Props.cling_sparkles(player())


func _swim_out() -> void:
	var who := actor(&"tamlin")
	if who == null:
		return
	var p := _feyre_pos()
	var level := water_level()
	var c := mark(&"pool")
	var out := p + (c - p).normalized() * 2.5
	out.y = (level - 1.15) if not is_nan(level) else p.y
	who.global_position = out
	Act4Walk.face(who, p)
	Act4Walk.idle(who)
