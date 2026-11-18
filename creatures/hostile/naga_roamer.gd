## A roaming naga of a hostile camp (docs/contracts/hostiles.md). Not the canon
## ambush naga (creatures/fae/naga.gd): this one lives at a site, keeps a day
## (bask at noon, hunt at dusk, nest at night with one on watch), climbs the
## perception ladder before it commits, chases only inside its leash unless it
## has her scent, and is turned by fire. Canon "X": the naga are canon, their
## camps and routines are invented.
class_name NagaRoamer
extends Creature

enum Fight { CHARGE, STRIKE, RECOVER }

## Throat and head hits do this many times an arrow's damage (2 arrows, not 6).
const THROAT_MULT := 3.0
## Fraction of body height above which an arrow counts as a throat/head hit.
const THROAT_HEIGHT := 0.78
## How long a smelled trail lets it run past the leash.
const TRAIL_SECONDS := 6.0
## A quiet brew this strong (BrewEffects.scent_scale at or under it) breaks the trail.
const HUSH_SCALE := 0.5
const FIRE_FLEE_RADIUS := 3.0
const FIRE_BURN_RADIUS := 1.2
const FIRE_FLEE_SECONDS := 6.0
const BURN_DPS := 6.0
const FROST_SLOW_SECONDS := 10.0
const LURE_SECONDS := 20.0
const REPORT_EVERY := 2.0
const FIRE_SCAN := 0.3
## How much of the camp's alert lands on a member's awareness (enough to search).
const CAMP_ALERT := 0.45

@export var strike_reach: float = 1.7
@export var strike_cooldown: float = 1.4
@export var attack_id: StringName = &"naga_bite"

## Set by HostileSite before _ready.
var site: HostileSite
var home: Vector3 = Vector3.INF
var member_index: int = 0

var ladder := HostileLadder.new()
var fight: Fight = Fight.CHARGE
var routine: StringName = &"nest"

var _fight_left: float = 0.0
var _trail_left: float = 0.0
var _flee_left: float = 0.0
var _flee_from: Vector3 = Vector3.ZERO
var _burn_left: float = 0.0
var _lure_at: Vector3 = Vector3.INF
var _lure_left: float = 0.0
var _search_at: Vector3 = Vector3.INF
var _report_left: float = 0.0
var _fire_scan_left: float = 0.0
var _last_awareness: float = 0.0
var _ring_angle: float = 0.0
var _hit_part_name: StringName = &"body"
var _dread: DreadField


func _ready() -> void:
	super._ready()
	if home == Vector3.INF:
		home = global_position
	_ring_angle = float(member_index) * 1.7
	_dread = DreadField.attach(self, 30.0, 10.0)
	senses.sensed.connect(_on_sensed)
	if EventBus.has_signal(&"player_knocked_down"):
		EventBus.connect(&"player_knocked_down", _on_player_down)


## What the day asks of it: bask 10-15, hunt 17-21, nest otherwise.
static func routine_for(hour: float) -> StringName:
	var h := fposmod(hour, 24.0)
	if h >= 10.0 and h < 15.0:
		return &"bask"
	if h >= 17.0 and h < 21.0:
		return &"hunt"
	return &"nest"


## Sight multiplier for a routine; one nesting member keeps watch at full senses.
static func sight_mult(routine_name: StringName, on_watch: bool) -> float:
	match routine_name:
		&"bask":
			return 0.7
		&"nest":
			return 1.0 if on_watch else 0.5
	return 1.0


## The trail holds while she was smelled in the last TRAIL_SECONDS, unless a
## quiet brew has thinned her scent to HUSH_SCALE or less.
static func trail_holds(seconds_left: float, scent_scale: float) -> bool:
	return seconds_left > 0.0 and scent_scale > HUSH_SCALE


## Damage multiplier for where an arrow struck: `height` is above its feet.
static func hit_mult(height: float, body_height: float) -> float:
	return THROAT_MULT if height >= body_height * THROAT_HEIGHT else 1.0


func is_on_watch() -> bool:
	return member_index == 0


func _player() -> Node3D:
	return get_tree().get_first_node_in_group(&"player") as Node3D if is_inside_tree() else null


func _think(delta: float) -> void:
	var player := _player()
	routine = NagaRoamer.routine_for(Clock.hour())
	_tune_senses(player)
	_amplify_while_wary()
	_tick_timers(delta, player)

	if _burn_left > 0.0:
		_burn_left -= delta
		health -= BURN_DPS * delta
		if health <= 0.0:
			die(&"fire")
			return
	_fire_scan_left -= delta
	if _fire_scan_left <= 0.0:
		_fire_scan_left = FIRE_SCAN
		_scan_fire()
	if _flee_left > 0.0:
		_flee_left -= delta
		move_direction = Creature.away_from(global_position, _flee_from) * 10.0
		move_speed = data.run_speed
		gait_hint = &""
		return

	var before := ladder.state
	var now := ladder.step(senses.awareness, delta)
	if now != before:
		_on_ladder_changed(before, now, player)

	if ladder.is_hostile() and player:
		if now == HostileLadder.State.STARTLE:
			move_speed = 0.0
			move_direction = Vector3.ZERO
			face_towards(player.global_position, delta * 3.0)
			return
		if not _may_chase(player.global_position):
			# Past the leash with no scent: it gives her up and goes home,
			# rather than staring from the edge and re-startling every second.
			ladder.give_up()
			senses.awareness = minf(senses.awareness, HostileLadder.CURIOUS_AT)
			_last_awareness = senses.awareness
			fight = Fight.CHARGE
			now = ladder.state
		else:
			_report_left -= delta
			if _report_left <= 0.0:
				_report_left = REPORT_EVERY
				_report(player.global_position)
			_fight(player, delta)
			return

	if _lure_left > 0.0 and _lure_at != Vector3.INF:
		_go_to(_lure_at, data.walk_speed * 1.5, 1.0)
		return
	match now:
		HostileLadder.State.SEARCHING:
			var at := _search_at if _search_at != Vector3.INF else senses.last_stimulus_position
			_go_to(at, data.walk_speed * 2.0, 1.5)
		HostileLadder.State.CURIOUS:
			move_speed = 0.0
			move_direction = Vector3.ZERO
			face_towards(senses.last_stimulus_position, delta)
		HostileLadder.State.LOST:
			_search_at = Vector3.INF
			_go_to(home, data.walk_speed * 1.5, 1.5)
		_:
			_routine(delta)


## Sight follows the routine and her vitals (a hood, a dark cloak); hearing
## follows her noise scale (soft boots). Ranges are set fresh each think.
func _tune_senses(player: Node3D) -> void:
	var sight := NagaRoamer.sight_mult(routine, is_on_watch())
	var hear := 1.0 if routine != &"nest" or is_on_watch() else 0.6
	senses.sight_range = data.sight_range * sight * HostileVitals.sight_scale(player)
	senses.hearing_range = data.hearing_range * hear * HostileVitals.noise_scale(player)


## While wary, any new rise in awareness counts for wary_gain times as much.
func _amplify_while_wary() -> void:
	var rise := senses.awareness - _last_awareness
	if rise > 0.0 and ladder.is_wary():
		senses.awareness = minf(_last_awareness + rise * ladder.sensitivity(), 1.0)
	_last_awareness = senses.awareness


func _tick_timers(delta: float, player: Node3D) -> void:
	_trail_left = maxf(_trail_left - delta, 0.0)
	if player and not NagaRoamer.trail_holds(_trail_left, BrewEffects.scent_scale(player)):
		_trail_left = 0.0
	_lure_left = maxf(_lure_left - delta, 0.0)


func _on_sensed(kind: StringName, _at: Vector3, _strength: float) -> void:
	if kind == &"scent":
		_trail_left = TRAIL_SECONDS


## Chase only inside the leash, unless it is on her scent.
func _may_chase(target: Vector3) -> bool:
	if site == null or not is_instance_valid(site):
		return true
	return site.in_leash(target) or _trail_left > 0.0


func _on_ladder_changed(_from: HostileLadder.State, to: HostileLadder.State, player: Node3D) -> void:
	match to:
		HostileLadder.State.STARTLE:
			_lure_left = 0.0
			if player:
				_report(player.global_position)
				HostileHits.startle(creature_id, 0.15)
		HostileLadder.State.ENGAGED:
			fight = Fight.CHARGE
			_report_left = REPORT_EVERY
		HostileLadder.State.LOST:
			fight = Fight.CHARGE


func _report(at: Vector3) -> void:
	if site and is_instance_valid(site):
		site.report(self, at)


## The camp heard from a member: go and look where she was seen.
func on_camp_alert(at: Vector3) -> void:
	if not alive or ladder.is_hostile():
		return
	_search_at = at
	senses.stimulate(&"alert", at, maxf(CAMP_ALERT - senses.awareness, 0.0) + 0.01)


func _fight(player: Node3D, delta: float) -> void:
	var to := player.global_position - global_position
	var flat := Vector2(to.x, to.z).length()
	gait_hint = &""
	match fight:
		Fight.CHARGE:
			move_direction = to
			move_speed = data.run_speed
			if flat <= strike_reach:
				fight = Fight.STRIKE
				_fight_left = 0.35
		Fight.STRIKE:
			move_speed = 0.0
			move_direction = Vector3.ZERO
			face_towards(player.global_position, delta * 4.0)
			_fight_left -= delta
			if _fight_left <= 0.0:
				if global_position.distance_to(player.global_position) <= strike_reach + 0.6:
					HostileHits.strike(creature_id, attack_id, 1.0, global_position)
				fight = Fight.RECOVER
				_fight_left = strike_cooldown
		Fight.RECOVER:
			# Weave back a step, then come again.
			move_direction = Creature.away_from(global_position, player.global_position).rotated(Vector3.UP, 0.9)
			move_speed = data.walk_speed * 2.0
			_fight_left -= delta
			if _fight_left <= 0.0:
				fight = Fight.CHARGE


func _routine(delta: float) -> void:
	match routine:
		&"hunt":
			var r := site.data.territory_radius * 0.7 if site and is_instance_valid(site) and site.data else 20.0
			var centre := site.global_position if site and is_instance_valid(site) else home
			var target := centre + Vector3(cos(_ring_angle), 0.0, sin(_ring_angle)) * r
			if Vector2(target.x - global_position.x, target.z - global_position.z).length() < 3.0:
				_ring_angle += 0.5
			_go_to(target, data.walk_speed, 0.5)
			gait_hint = &"stalk"
		&"bask":
			_go_to(home, data.walk_speed * 0.6, 2.0)
			gait_hint = &"graze" if move_speed == 0.0 else &""
		_:
			_go_to(home, data.walk_speed, 1.5)
			gait_hint = &""
	if move_speed == 0.0 and is_on_watch() and routine == &"nest":
		rotation.y += delta * 0.25


func _go_to(target: Vector3, speed: float, stop_at: float) -> void:
	var to := target - global_position
	if Vector2(to.x, to.z).length() <= stop_at:
		move_speed = 0.0
		move_direction = Vector3.ZERO
		return
	move_direction = to
	move_speed = speed


## A burning ElementField cell within 3 m sends it fleeing; within 1.2 m it burns.
func _scan_fire() -> void:
	if not is_inside_tree():
		return
	var field := ElementField.find(get_tree())
	if field == null:
		return
	if not _any_burning(field, global_position, FIRE_FLEE_RADIUS):
		return
	if _any_burning(field, global_position, FIRE_BURN_RADIUS):
		_burn_left = maxf(_burn_left, FIRE_SCAN * 2.0)
	# Which side the fire is on: sample four points and run from the hottest.
	var from := global_position
	for dir in [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]:
		var p: Vector3 = global_position + dir * 1.5
		if _any_burning(field, p, 1.5):
			from = p
			break
	_flee_from = from if from != global_position else global_position - global_basis.z
	_flee_left = FIRE_FLEE_SECONDS
	_lure_left = 0.0


static func _any_burning(field: ElementField, at: Vector3, radius: float) -> bool:
	for id in field.cells_near(at, radius):
		if field.is_burning(id):
			return true
	return false


func on_arrow_hit(arrow: Node3D) -> void:
	if not alive:
		return
	var mult := NagaRoamer.hit_mult(arrow.global_position.y - global_position.y, data.body_height)
	_hit_part_name = &"throat" if mult > 1.0 else &"body"
	var arrow_id := Creature.read_arrow_id(arrow)
	if mult > 1.0 and not mortally_wounded and not (arrow_id in data.lethal_arrow_ids):
		# The base hit takes one arrow's damage; the throat adds the rest.
		health = maxf(health - data.arrow_damage * (mult - 1.0), 0.01)
	super.on_arrow_hit(arrow)


func _hit_part(_killing: bool) -> StringName:
	return _hit_part_name


## Frost slows it (Creature slow); a fire arrow in the body sets it burning
## and running. Sleep, barbs and lures are the base's.
func on_arrow_effect(effect: StringName, arrow: Node3D) -> void:
	if not alive:
		return
	match effect:
		&"frost":
			slowed_left = maxf(slowed_left, FROST_SLOW_SECONDS)
		&"fire":
			_burn_left = maxf(_burn_left, 2.0)
			_flee_from = arrow.global_position
			_flee_left = FIRE_FLEE_SECONDS
	super.on_arrow_effect(effect, arrow)


func _on_wounded(from: Vector3, _cause: StringName) -> void:
	senses.stimulate(&"pain", from, 1.0)
	_search_at = from


func _on_lured(at: Vector3) -> void:
	if ladder.is_hostile():
		return
	_lure_at = at
	_lure_left = LURE_SECONDS


func _on_player_down(_source_id: Variant = null, _cause: Variant = null, _at: Variant = null) -> void:
	if not alive or not ladder.is_hostile():
		return
	ladder.give_up()
	senses.awareness = 0.0
	_last_awareness = 0.0
	fight = Fight.CHARGE


func die(cause: StringName) -> void:
	super.die(cause)
	if _dread and is_instance_valid(_dread):
		_dread.queue_free()
		_dread = null
