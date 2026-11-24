## A roaming naga of a hostile camp (docs/contracts/hostiles.md). Not the canon
## ambush naga (creatures/fae/naga.gd): this one lives at a site, keeps a day
## (bask at noon, hunt at dusk, nest at night with one on watch), climbs the
## perception ladder before it commits, chases only inside its leash unless it
## has her scent, and is turned by fire. Canon "X": the naga are canon, their
## camps and routines are invented.
class_name NagaRoamer
extends Creature

## CHARGE runs at her; CIRCLE keeps 4-6 m off while it has no attack token
## or another holds her; STRIKE winds up a claw or a coil; LUNGE winds up the
## leap, LEAP is the leap; HOLD is the coil around her; RECOVER weaves back.
enum Fight { CHARGE, STRIKE, RECOVER, CIRCLE, LUNGE, LEAP, HOLD }

## The naga's three rows (data/combat/attacks; bestiary §2).
const CLAW := &"naga_claw"
const LUNGE_ATTACK := &"naga_lunge"
const COIL := &"naga_coil"
## The lunge opens from this far, once per engagement (health-interactions §4).
const LUNGE_MIN := 4.0
const LUNGE_MAX := 6.0
## The leap closes the gap in about this long; it lands if she comes within
## reach before it runs out, else it misses.
const LEAP_SECONDS := 0.5
## Without a token it circles her at this distance.
const CIRCLE_MIN := 4.0
const CIRCLE_MAX := 6.0
## The coil: only from behind her. Six presses or three seconds; if she
## doesn't break it, a claw at COIL_FOLLOW_SCALE.
const COIL_PRESSES := 6
const COIL_SECONDS := 3.0
const COIL_FOLLOW_SCALE := 1.5

## How long a smelled trail lets it run past the leash.
const TRAIL_SECONDS := 6.0
## Her scent this thin (Vitals.scent_scale at or under it: a hush draught)
## breaks the trail.
const HUSH_SCALE := 0.5
## Burning ground near it (Creature._step_fire) sends it running this long.
const FIRE_FLEE_SECONDS := 6.0
const FROST_SLOW_SECONDS := 10.0
const LURE_SECONDS := 20.0
const REPORT_EVERY := 2.0
## How much of the camp's alert lands on a member's awareness (enough to search).
const CAMP_ALERT := 0.45

@export var strike_reach: float = 1.7
## Wind-up plus this is one member's ~2.2 s cycle (health-interactions §3.4):
## two tokens land a claw about every 1.1 s, so a camp needs ≥ 4 s to put her down.
@export var strike_cooldown: float = 1.65
@export var attack_id: StringName = CLAW

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
var _lure_at: Vector3 = Vector3.INF
var _lure_left: float = 0.0
var _search_at: Vector3 = Vector3.INF
var _report_left: float = 0.0
var _last_awareness: float = 0.0
var _ring_angle: float = 0.0
var _dread: DreadField
## The row the current wind-up ends in.
var _attack: StringName = &""
var _lunged: bool = false
var _has_token: bool = false
var _hold_left: float = 0.0
var _leap_speed: float = 0.0
var _circle_sign: float = 1.0


func _ready() -> void:
	super._ready()
	if home == Vector3.INF:
		home = global_position
	_ring_angle = float(member_index) * 1.7
	_dread = DreadField.attach(self, 30.0, 10.0)
	senses.sensed.connect(_on_sensed)
	EventBus.player_knocked_down.connect(_on_player_down)
	EventBus.player_released.connect(_on_player_released)
	_circle_sign = 1.0 if member_index % 2 == 0 else -1.0


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


func is_on_watch() -> bool:
	return member_index == 0


func _player() -> Node3D:
	return get_tree().get_first_node_in_group(&"player") as Node3D if is_inside_tree() else null


func _think(delta: float) -> void:
	var player := _player()
	routine = NagaRoamer.routine_for(Clock.hour())
	_tune_senses()
	_amplify_while_wary()
	_tick_timers(delta, player)

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
			_set_fight(Fight.CHARGE)
			now = ladder.state
		else:
			_report_left -= delta
			if _report_left <= 0.0:
				_report_left = REPORT_EVERY
				_report(player.global_position)
			_fight(player, delta)
			return

	if fight != Fight.CHARGE:
		_set_fight(Fight.CHARGE)
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


## Sight and hearing follow the routine (a basker squints, a sleeper half
## hears). Her side (crouch, movement, brews, rain) is CreatureSenses' own.
func _tune_senses() -> void:
	var hear := 1.0 if routine != &"nest" or is_on_watch() else 0.6
	senses.sight_range = data.sight_range * NagaRoamer.sight_mult(routine, is_on_watch())
	senses.hearing_range = data.hearing_range * hear


## While wary, any new rise in awareness counts for wary_gain times as much.
func _amplify_while_wary() -> void:
	var rise := senses.awareness - _last_awareness
	if rise > 0.0 and ladder.is_wary():
		senses.awareness = minf(_last_awareness + rise * ladder.sensitivity(), 1.0)
	_last_awareness = senses.awareness


func _tick_timers(delta: float, player: Node3D) -> void:
	_trail_left = maxf(_trail_left - delta, 0.0)
	if player and not NagaRoamer.trail_holds(_trail_left, Vitals.scent_scale(player)):
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
			_set_fight(Fight.CHARGE)
			_lunged = false
			_report_left = REPORT_EVERY
		HostileLadder.State.LOST:
			_set_fight(Fight.CHARGE)
			_lunged = false


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
		Fight.CHARGE, Fight.CIRCLE:
			var held_by_other := _held_by_other(player)
			if not held_by_other and _may_lunge() and flat >= LUNGE_MIN and flat <= LUNGE_MAX \
					and _take_token():
				_lunged = true
				if site and is_instance_valid(site):
					site.claim_lunge()
				_wind_up(Fight.LUNGE, LUNGE_ATTACK)
			elif not held_by_other and flat <= strike_reach and _take_token():
				var coil := StrikeController.is_behind(NagaRoamer.facing_node(player), global_position) \
						and not _is_held(player)
				_wind_up(Fight.STRIKE, COIL if coil else attack_id)
			elif flat <= CIRCLE_MAX and (held_by_other or not _token_free()):
				fight = Fight.CIRCLE
				_circle(player, to, flat, delta)
			else:
				fight = Fight.CHARGE
				move_direction = to
				move_speed = data.run_speed
		Fight.STRIKE:
			_hold_still(player, delta)
			_fight_left -= delta
			if _fight_left <= 0.0:
				# Flat reach, capped in height: a step doesn't save her, a ledge does.
				var in_reach := Creature.within_reach(global_position, player.global_position, strike_reach + 0.6)
				if in_reach and _attack == COIL:
					_coil(player)
				else:
					if in_reach:
						HostileHits.strike(creature_id, _attack, 1.0, global_position)
					_recover()
		Fight.LUNGE:
			_hold_still(player, delta)
			_fight_left -= delta
			if _fight_left <= 0.0:
				fight = Fight.LEAP
				_fight_left = LEAP_SECONDS
				_leap_speed = maxf(flat, LUNGE_MIN) / LEAP_SECONDS * 1.5
		Fight.LEAP:
			move_direction = to
			move_speed = _leap_speed
			_fight_left -= delta
			if Creature.within_reach(global_position, player.global_position, strike_reach):
				HostileHits.strike(creature_id, LUNGE_ATTACK, 1.0, global_position)
				_recover()
			elif _fight_left <= 0.0:
				_recover()
		Fight.HOLD:
			_hold_still(player, delta)
			_hold_left -= delta
			if not _holds_her(player) or _hold_left <= 0.0:
				# Her own timer ends the hold as ours does: that is the failure.
				if _hold_left <= 0.1:
					HostileHits.strike(creature_id, attack_id, COIL_FOLLOW_SCALE, global_position)
				_recover()
		Fight.RECOVER:
			# Weave back a step, then come again.
			move_direction = Creature.away_from(global_position, player.global_position).rotated(Vector3.UP, 0.9)
			move_speed = data.walk_speed * 2.0
			_fight_left -= delta
			if _fight_left <= 0.0:
				_set_fight(Fight.CHARGE)


## The lunge opens a fight: once per engagement, and once per camp until the
## camp calms (HostileSite.claim_lunge), so one naga bursts out, not four.
func _may_lunge() -> bool:
	if _lunged:
		return false
	return site == null or not is_instance_valid(site) or site.lunge_ready()


## The node whose -Z is the way she faces: her model (GroundMotor turns it),
## else the body.
static func facing_node(player: Node3D) -> Node3D:
	var m: Node3D = player.get(&"model") as Node3D if &"model" in player else null
	return m if m and m.is_inside_tree() else player


## Tell to contact for a row: AttackData.windup_s, the one home.
static func windup_of(attack: StringName) -> float:
	var row := AttackTable.resolve(attack)
	return row.windup_s if row else 0.55


func _wind_up(next: Fight, attack: StringName) -> void:
	fight = next
	_attack = attack
	_fight_left = NagaRoamer.windup_of(attack)
	_anim(&"play_attack", [attack])


func _hold_still(player: Node3D, delta: float) -> void:
	move_speed = 0.0
	move_direction = Vector3.ZERO
	face_towards(player.global_position, delta * 4.0)


## No token: keep 4-6 m off and pace round her, facing her.
func _circle(player: Node3D, to: Vector3, flat: float, delta: float) -> void:
	var radial := Vector3(to.x, 0.0, to.z) / maxf(flat, 0.001)
	var tangent := radial.cross(Vector3.UP) * _circle_sign
	var pull := 0.0
	if flat < CIRCLE_MIN:
		pull = -1.0
	elif flat > CIRCLE_MAX - 0.5:
		pull = 1.0
	move_direction = tangent + radial * pull
	move_speed = data.walk_speed * 1.5
	face_towards(player.global_position, delta * 3.0)
	gait_hint = &"stalk"


## The coil closes: Vitals takes the hold (one at a time) and we keep it until
## she breaks it, cuts it, or her time runs out.
func _coil(player: Node3D) -> void:
	EventBus.player_grabbed.emit(creature_id, COIL_PRESSES, COIL_SECONDS)
	if not _holds_her(player):
		_recover()
		return
	fight = Fight.HOLD
	_hold_left = COIL_SECONDS


func _recover() -> void:
	_set_fight(Fight.RECOVER)
	_fight_left = strike_cooldown


## The strike or lunge it is telegraphing, until contact.
func winding_up() -> StringName:
	return _attack if alive and (fight == Fight.STRIKE or fight == Fight.LUNGE) else &""


## Every fight change goes through here so the token and a hold never outlive
## the move that took them. The token is kept through the recovery: a member's
## whole cycle is one turn.
func _set_fight(next: Fight) -> void:
	if fight == Fight.HOLD and next != Fight.HOLD:
		_free_her()
	if next == Fight.CHARGE or next == Fight.CIRCLE:
		_release_token()
	fight = next


func _take_token() -> bool:
	if _has_token:
		return true
	if site == null or not is_instance_valid(site):
		_has_token = true
	else:
		_has_token = site.take_token(self)
	return _has_token


func _token_free() -> bool:
	return _has_token or site == null or not is_instance_valid(site) or site.tokens_free() > 0


func _release_token() -> void:
	if _has_token and site and is_instance_valid(site):
		site.release_token(self)
	_has_token = false


func has_token() -> bool:
	return _has_token


func _is_held(player: Node3D) -> bool:
	var v := Vitals.of(player)
	return v != null and v.is_grabbed()


func _holds_her(player: Node3D) -> bool:
	var v := Vitals.of(player)
	return v != null and v.is_grabbed() and v.grab_source == creature_id


## Another holds her: the rest hold off (health-interactions §5.4).
func _held_by_other(player: Node3D) -> bool:
	var v := Vitals.of(player)
	return v != null and v.is_grabbed() and v.grab_source != creature_id


## We let go (stagger, sleep, death): she is free at once.
func _free_her() -> void:
	var player := _player()
	if player and _holds_her(player):
		EventBus.player_released.emit(creature_id)


func _on_player_released(source_id: StringName) -> void:
	if source_id == creature_id and fight == Fight.HOLD and alive:
		# She broke the coil or cut it: it reels back.
		fight = Fight.RECOVER
		_fight_left = strike_cooldown


func _anim(method: StringName, args: Array) -> void:
	if animator and animator.has_method(method):
		animator.callv(method, args)


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


## Burning ground or a fire arrow (Creature._step_fire): it runs from the flame.
func _on_fire_near(from: Vector3) -> void:
	_set_fight(Fight.CHARGE)
	_flee_from = from
	_flee_left = FIRE_FLEE_SECONDS
	_lure_left = 0.0


## A bow bash or a knife wound: the strike it was winding up is lost, and
## when it has its feet again it backs off before it comes again.
func stagger(seconds: float) -> void:
	if not alive:
		return
	if fight != Fight.RECOVER:
		if fight == Fight.STRIKE or fight == Fight.LUNGE or fight == Fight.LEAP:
			_anim(&"cancel_attack", [])
		_recover()
	super.stagger(seconds)


## Frost slows it (Creature slow). Fire, sleep, barbs and lures are the base's.
## Asleep, it lets her go.
func on_arrow_effect(effect: StringName, arrow: Node3D) -> void:
	if not alive:
		return
	if effect == &"sleep" and fight != Fight.CHARGE:
		_set_fight(Fight.CHARGE)
	if effect == &"frost":
		slowed_left = maxf(slowed_left, FROST_SLOW_SECONDS)
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
	_set_fight(Fight.CHARGE)


func die(cause: StringName) -> void:
	_set_fight(Fight.CHARGE)
	super.die(cause)
	if _dread and is_instance_valid(_dread):
		_dread.queue_free()
		_dread = null
