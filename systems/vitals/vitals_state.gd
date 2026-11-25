## Feyre's vitals: health, hits, regen, afflictions (venom, drowsy, roar),
## dread and ease, grabs, hazards and the knockdown. A child of Feyre named
## "Vitals" (feyre.vitals). Plans: plans/feyre-vitals/plan.md §4–9; interface:
## docs/contracts/vitals.md.
##
## Inbound hits arrive only as EventBus signals (player_hit, player_status_applied,
##, player_startled, player_grabbed, player_released).
## The outbound bus signals mirror this node's own signals, which the HUD uses.
class_name VitalsState
extends Node

signal health_changed(health: float, max_health: float, delta: float, source_id: StringName)
## A hit landed. origin is the attacker's position (Vector3.INF = in front).
signal hit_taken(origin: Vector3, damage: float, reaction: StringName)
signal knocked_down(source_id: StringName, cause: StringName)
signal woke(rest_point_id: StringName)
## A status started (magnitude > 0) or ended (magnitude 0).
signal status_changed(tag: StringName, magnitude: float, seconds_left: float)
signal grabbed(source_id: StringName, presses: int)
signal grab_press(presses_left: int)
signal released(source_id: StringName)
signal healed(amount: float)
## An ease moment (the gold edge bloom and petals).
signal ease_moment(amount: float)

const MAX_HEALTH := 100.0
const REGEN_DELAY := 10.0
const REGEN_PER_SECOND := 1.0
const HEAL_SECONDS := 3.0
const IFRAMES_LIGHT := 0.9
const IFRAMES_HEAVY := 1.4
const WAKE_GRACE := 3.0
## Fall, iris and black hold before she comes round.
const DOWN_SECONDS := 4.5
const STORY_FLOOR := 10.0
const GENTLE_DAMAGE := 0.6
const WAKE_HEALTH_SPRING := 70.0
const WAKE_HEALTH_HUMAN := 35.0
const WAKE_HEALTH_GENTLE := 50.0
## 3 game hours (1 game hour = 60 real seconds).
const WAKE_TIME_SKIP := 180.0
const VENOM_CREEP := 0.004
const VENOM_DRAIN_FROM := 0.5
const DROWSY_DECAY := 0.08
const DREAD_RISE := 0.25
const DREAD_FALL := 0.06
const GRAB_PRESS_STAMINA := 12.0
const COLD_EXPOSURE_AT := 0.85
const COLD_EXPOSURE_AFTER := 20.0
## A fall is measured from where she last stood to where she lands, so a jump
## that comes back down to the same ground never hurts, however high it went.
const FALL_SAFE_M := 4.0
const FALL_KNOCKDOWN_M := 16.0
const STUFFED_SECONDS := 180.0
## A full game day.
const WELL_RESTED_SECONDS := 1440.0
const EASE_FIRST := 0.06
const EASE_REPEAT := 0.015
const EASE_REPEATS_PER_DAY := 3
## Phase prefix -> the most ease her arc allows there (plan §9.2).
const EASE_CAPS := {"p0": 0.0, "p1": 0.0, "p2": 0.15, "p3": 0.3, "p4": 0.5, "p5": 0.65,
	"p6": 0.85, "p7": 0.6, "p8": 0.85}
const EASE_DIPS := {"summer_faerie_comforted": 0.08, "fountain_head_found": 0.1, "rhysand_faced": 0.1}
const HUMAN_PHASES: Array[String] = ["p0", "p1", "p7"]

var health: float = MAX_HEALTH
var dread: float = 0.0
var dread_target: float = 0.0
## Slow, saved baseline (0..1).
var ease: float = 0.0
## Fast flash from an ease moment (0..1), decays 0.02/s.
var ease_pulse: float = 0.0
## tag -> {"magnitude", "remaining", "total"} for venom, drowsy, roar_shake.
var afflictions: Dictionary = {}
var well_rested_left: float = 0.0
var stuffed_left: float = 0.0
var is_down: bool = false
## 0..1 through the knockdown (the HUD's stars and iris), then the wake iris.
var down_progress: float = 0.0
var wake_progress: float = 1.0
var grab_source: StringName = &""
var grab_presses_left: int = 0
var grab_presses_total: int = 0
var grab_time_left: float = 0.0
## Most recent hit, for the HUD's hit-direction mark.
var last_hit_origin: Vector3 = Vector3.INF
## Seconds since the last damage.
var since_damage: float = 999.0

var player: Node3D
var _iframes: float = 0.0
var _grace: float = 0.0
var _heal_pending: float = 0.0
var _heal_rate: float = 0.0
var _down_left: float = 0.0
var _cold_over: float = 0.0
var _hazard_tick: Dictionary = {}
## Height of the ground she last stood on (-INF until she first stands).
var _stood_y: float = -INF
var _was_on_floor: bool = true
var _mood_sent: Vector2 = Vector2(-1.0, -1.0)
var _mood_clock: float = 0.0
var _ease_seen: Dictionary = {}
var _ease_repeats_today: int = 0
var _active_tags: Dictionary = {}
var _story_control_held: bool = false
var _fell_to: StringName = &""


func _ready() -> void:
	if player == null:
		player = get_parent() as Node3D
	Gameplay.listen(&"player_hit", _on_player_hit)
	Gameplay.listen(&"player_status_applied", _on_status_applied)
	Gameplay.listen(&"player_startled", _on_startled)
	Gameplay.listen(&"player_grabbed", _on_grabbed)
	Gameplay.listen(&"player_released", _on_released)
	Gameplay.listen(&"mood_requested", _on_mood_requested)
	Gameplay.listen(&"celebration_requested", _on_celebration)
	Gameplay.listen(&"deed_performed", _on_deed)
	Gameplay.listen(&"flag_changed", _on_flag_changed)
	Gameplay.listen(&"day_started", func(_d: int) -> void: _ease_repeats_today = 0)
	var save := Gameplay.autoload(&"SaveSystem")
	if save and save.has_method(&"register_provider"):
		save.register_provider("vitals", self)


func _physics_process(delta: float) -> void:
	step(delta)


func step(delta: float) -> void:
	since_damage += delta
	_iframes = maxf(_iframes - delta, 0.0)
	_grace = maxf(_grace - delta, 0.0)
	if is_down:
		_step_down(delta)
		return
	wake_progress = minf(wake_progress + delta / 1.5, 1.0)
	_step_heal(delta)
	_step_afflictions(delta)
	_step_mood(delta)
	_step_derived(delta)
	_step_grab(delta)
	_step_hazards(delta)
	_apply_to_body()


# --- Queries ---------------------------------------------------------------

func health_fraction() -> float:
	return health / MAX_HEALTH


## Walk-it-off regen only reaches this (plan §4.5); food, salves and beds go past it.
func regen_cap() -> float:
	var cap := 50.0 + 20.0 * ease + (10.0 if well_rested_left > 0.0 else 0.0)
	if in_human_realm():
		cap -= 30.0 * _hunger()
	return clampf(cap, 20.0, 90.0)


func max_stamina() -> float:
	return 100.0 + 50.0 * ease


func affliction(tag: StringName) -> float:
	return float(afflictions[tag]["magnitude"]) if afflictions.has(tag) else 0.0


## Nothing lands on her for `seconds` (the sidestep). The one i-frame clock:
## a longer spell already running is kept.
func grant_iframes(seconds: float) -> void:
	_iframes = maxf(_iframes, seconds)


func is_invulnerable() -> bool:
	return is_down or _iframes > 0.0 or _grace > 0.0


func is_grabbed() -> bool:
	return grab_source != &""


func in_human_realm() -> bool:
	var phase := _phase()
	return phase == "" or HUMAN_PHASES.any(func(p: String) -> bool: return phase.begins_with(p + "_"))


## Every status on her now: [{tag, magnitude, seconds_left, total}], danger first.
## Brew buffs come from BodyState.effects; the rest are hers or derived live.
func statuses() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for tag: StringName in afflictions:
		var a: Dictionary = afflictions[tag]
		var timed := tag == &"roar_shake"
		out.append({"tag": tag, "magnitude": float(a.magnitude),
			"seconds_left": float(a.remaining) if timed else -1.0, "total": float(a.total) if timed else -1.0})
	var body := _body()
	if body:
		for tag: StringName in body.effects:
			var e: Dictionary = body.effects[tag]
			out.append({"tag": tag, "magnitude": float(e.magnitude), "seconds_left": float(e.remaining),
				"total": float(e.get("total", e.remaining))})
		out.append(_gauge(&"cold", body.cold))
		out.append(_gauge(&"hunger", body.hunger))
		if body.fae_toll >= 0.3:
			out.append(_live(&"giddy", body.fae_toll))
		if stuffed_left > 0.0:
			out.append({"tag": &"stuffed", "magnitude": 1.0, "seconds_left": stuffed_left, "total": STUFFED_SECONDS})
	if _heal_pending > 0.0:
		out.append({"tag": &"heal", "magnitude": 1.0, "seconds_left": _heal_pending / maxf(_heal_rate, 0.01),
			"total": HEAL_SECONDS})
	if well_rested_left > 0.0:
		out.append({"tag": &"well_rested", "magnitude": 1.0, "seconds_left": well_rested_left, "total": WELL_RESTED_SECONDS})
	if ease_pulse > 0.3:
		out.append(_live(&"at_ease", ease_pulse))
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return StatusRules.sort_key(a.tag) < StatusRules.sort_key(b.tag))
	return out


# --- Inbound ---------------------------------------------------------------

func _on_player_hit(source_id: StringName, attack_id: StringName, scale: float, origin: Vector3) -> void:
	take_hit(source_id, AttackTable.resolve(attack_id), scale, origin)


## Plan §4.2, in order. Returns the damage dealt (0 if the hit was dropped).
func take_hit(source_id: StringName, row: AttackData, scale: float = 1.0, origin: Vector3 = Vector3.INF) -> float:
	if row == null or is_down or _iframes > 0.0 or _grace > 0.0:
		return 0.0
	var damage := row.damage * scale * damage_taken_scale(row.damage_kind)
	var floor_hp := row.floor_hp
	if not row.can_knock_down or (row.damage_kind == &"fall" and _gentle()):
		floor_hp = maxf(floor_hp, 1.0)
	if _story_staged():
		floor_hp = maxf(floor_hp, STORY_FLOOR)
	var before := health
	health = maxf(health - damage, minf(floor_hp, before))
	var dealt := before - health
	if dealt > 0.0:
		since_damage = 0.0
		_heal_pending = 0.0
		_announce_health(-dealt, source_id)
	if row.status_tag != &"":
		apply_status(source_id, row.status_tag, row.status_magnitude, row.status_seconds)
	add_dread(row.dread_spike)
	if row.reaction != &"none":
		last_hit_origin = origin
		hit_taken.emit(origin, dealt, row.reaction)
		_knockback(row, origin)
		_iframes = IFRAMES_HEAVY if row.reaction == &"heavy" else IFRAMES_LIGHT
	if health <= 0.0:
		knock_down(source_id, row.id)
	return dealt


func _on_status_applied(source_id: StringName, tag: StringName, magnitude: float, seconds: float) -> void:
	apply_status(source_id, tag, magnitude, seconds)


func apply_status(_source_id: StringName, tag: StringName, magnitude: float, seconds: float) -> void:
	if magnitude <= 0.0:
		return
	if StatusRules.BREW_TAGS.has(tag):
		var body := _body()
		if body:
			body.add_effect(tag, magnitude, seconds)
		return
	var was := afflictions.has(tag)
	afflictions[tag] = StatusRules.stack(tag, afflictions.get(tag, {}), magnitude, seconds)
	if not was:
		_status_event(tag, float(afflictions[tag].magnitude), seconds)


func clear_status(tag: StringName) -> void:
	if afflictions.erase(tag):
		_status_event(tag, 0.0, 0.0)


func _on_startled(_source_id: StringName, amount: float) -> void:
	add_dread(amount)


func add_dread(amount: float) -> void:
	dread = clampf(dread + amount * dread_gain_scale(), 0.0, 1.0)


func _on_grabbed(source_id: StringName, break_presses: int, hold_seconds: float) -> void:
	if is_down or is_grabbed():
		return
	var strong := _body().effect(&"strong") if _body() else 0.0
	grab_source = source_id
	grab_presses_total = maxi(break_presses - int(strong / 1.5), 1)
	grab_presses_left = grab_presses_total
	grab_time_left = hold_seconds
	grabbed.emit(source_id, grab_presses_total)


func _on_released(source_id: StringName) -> void:
	if source_id == grab_source:
		_end_grab()


## One mash of interact against a hold. Winded presses do nothing.
func press_break_free() -> void:
	if not is_grabbed():
		return
	if player and player.has_method(&"is_winded") and bool(player.call(&"is_winded")):
		return
	if player and player.has_method(&"drain_stamina"):
		player.call(&"drain_stamina", GRAB_PRESS_STAMINA)
	grab_presses_left -= 1
	grab_press.emit(grab_presses_left)
	if grab_presses_left <= 0:
		var source := grab_source
		_end_grab()
		Gameplay.emit(&"player_released", [source])


func _input(event: InputEvent) -> void:
	if is_grabbed() and event.is_action_pressed(&"interact"):
		press_break_free()
		get_viewport().set_input_as_handled()


func _end_grab() -> void:
	var source := grab_source
	grab_source = &""
	grab_presses_left = 0
	grab_time_left = 0.0
	released.emit(source)


func _on_mood_requested(mood: StringName, intensity: float, _seconds: float) -> void:
	if mood == &"dread":
		dread_target = clampf(intensity, 0.0, 1.0)
	elif mood == &"calm":
		dread_target = 0.0


func _on_celebration(kind: StringName, _at: Vector3) -> void:
	ease_moment_from("celebration:%s" % kind)


func _on_deed(flag: String) -> void:
	ease_moment_from("deed:%s" % flag)


func _on_flag_changed(flag: String, value: Variant) -> void:
	if EASE_DIPS.has(flag) and value and not _ease_seen.has("dip:" + flag):
		_ease_seen["dip:" + flag] = true
		ease = maxf(ease - float(EASE_DIPS[flag]), 0.0)


## A first-time moment raises her ease baseline by 0.06; repeats by 0.015, 3 a day.
func ease_moment_from(key: String) -> void:
	var gain := EASE_FIRST
	if _ease_seen.has(key):
		if _ease_repeats_today >= EASE_REPEATS_PER_DAY:
			return
		_ease_repeats_today += 1
		gain = EASE_REPEAT
	_ease_seen[key] = true
	ease = minf(ease + gain, maxf(ease, ease_cap()))
	ease_pulse = minf(ease_pulse + 0.5, 1.0)
	ease_moment.emit(gain)


func ease_cap() -> float:
	var phase := _phase()
	return float(EASE_CAPS.get(phase.substr(0, 2), 0.85)) if phase != "" else 0.0


# --- Healing and rest --------------------------------------------------------

## Food, salves and brews: heal over 3 s with a petal burst; harm lands as a
## venom-kind hit with no reaction (plan §4.5).
func eat_result(heal: float, harm: float) -> void:
	if heal > 0.0:
		heal_over_time(heal * MAX_HEALTH)
	if harm > 0.0:
		take_hit(&"", AttackTable.resolve(&"food_harm"), harm * MAX_HEALTH)


func heal_over_time(amount: float) -> void:
	_heal_pending += amount
	_heal_rate = _heal_pending / HEAL_SECONDS
	healed.emit(amount)


## A night in a bed: full heal, venom and drowsy cleared, well-rested if she slept well.
func rest(rested: bool) -> void:
	_set_health(MAX_HEALTH, &"")
	clear_status(&"venom")
	clear_status(&"drowsy")
	if rested:
		well_rested_left = WELL_RESTED_SECONDS
		ease_moment_from("rest")


func notify_meal(hunger_after: float) -> void:
	if hunger_after < 0.05:
		if stuffed_left <= 0.0:
			_status_event(&"stuffed", 1.0, STUFFED_SECONDS)
		stuffed_left = STUFFED_SECONDS


# --- Knockdown ---------------------------------------------------------------

func knock_down(source_id: StringName, cause: StringName) -> void:
	if is_down:
		return
	is_down = true
	var row := AttackTable.resolve(cause) if AttackTable.has(cause) else null
	_fell_to = row.family if row else &""
	down_progress = 0.0
	_down_left = DOWN_SECONDS
	health = 0.0
	dread = 1.0
	_end_grab()
	var at := player.global_position if player and player.is_inside_tree() else Vector3.ZERO
	knocked_down.emit(source_id, cause)
	Gameplay.emit(&"player_knocked_down", [source_id, cause, at])
	var sc := Gameplay.autoload(&"StoryControl")
	if sc and int(sc.get(&"mode")) == 0:
		sc.call(&"set_mode", 3)
		_story_control_held = true
	if player and "velocity" in player:
		player.set(&"velocity", Vector3.ZERO)


func _step_down(delta: float) -> void:
	_down_left -= delta
	down_progress = clampf(1.0 - _down_left / DOWN_SECONDS, 0.0, 1.0)
	if _down_left <= 0.0:
		wake()


func wake() -> void:
	var gentle := _gentle()
	var point := null if gentle else _nearest_rest_point()
	var rest_id := &""
	if point:
		rest_id = point.rest_id
		if player:
			player.global_position = point.global_position
	if not gentle:
		var clock := Gameplay.autoload(&"Clock")
		if clock:
			clock.call(&"advance", WAKE_TIME_SKIP)
	is_down = false
	down_progress = 0.0
	wake_progress = 0.0
	var wake_hp := WAKE_HEALTH_GENTLE if gentle else (WAKE_HEALTH_HUMAN if in_human_realm() else WAKE_HEALTH_SPRING)
	_set_health(wake_hp, &"")
	if afflictions.has(&"venom"):
		afflictions[&"venom"]["magnitude"] = float(afflictions[&"venom"].magnitude) * 0.5
	clear_status(&"drowsy")
	clear_status(&"roar_shake")
	dread = 0.2
	_grace = WAKE_GRACE
	since_damage = 0.0
	if _story_control_held:
		_story_control_held = false
		var sc := Gameplay.autoload(&"StoryControl")
		if sc:
			sc.call(&"set_mode", 0)
	var at := player.global_position if player and player.is_inside_tree() else Vector3.ZERO
	woke.emit(rest_id)
	Gameplay.emit(&"player_woke", [rest_id, at])
	_count_fall()


func _nearest_rest_point() -> RestPoint:
	if player == null or not player.is_inside_tree():
		return null
	var best: RestPoint = null
	var best_d := INF
	for n in player.get_tree().get_nodes_in_group(RestPoint.GROUP):
		var p := n as RestPoint
		if p == null:
			continue
		var d := p.global_position.distance_squared_to(player.global_position)
		if d < best_d:
			best_d = d
			best = p
	return best


func _count_fall() -> void:
	var ws := Gameplay.autoload(&"WorldState")
	if ws == null:
		return
	ws.call(&"set_flag", "fact.falls.count", int(ws.call(&"get_flag", "fact.falls.count", 0)) + 1)
	if _fell_to != &"":
		var key := "fact.fell_to.%s" % _fell_to
		ws.call(&"set_flag", key, int(ws.call(&"get_flag", key, 0)) + 1)


# --- Modifiers (read by Vitals.*) -------------------------------------------

func damage_taken_scale(_damage_kind: StringName) -> float:
	return GENTLE_DAMAGE if _gentle() else 1.0


func dread_gain_scale() -> float:
	var s := 1.0 - 0.3 * ease
	var body := _body()
	if body and body.effect(&"steady") > 0.0:
		s *= 0.8
	return clampf(s, 0.4, 1.5)


# --- Per-frame ---------------------------------------------------------------

func _step_heal(delta: float) -> void:
	if _heal_pending > 0.0:
		var amount := minf(_heal_rate * delta, _heal_pending)
		_heal_pending -= amount
		_set_health(health + amount, &"")
	elif since_damage >= REGEN_DELAY and affliction(&"venom") < 0.1 and health < regen_cap():
		_set_health(minf(health + REGEN_PER_SECOND * delta, regen_cap()), &"")


func _step_afflictions(delta: float) -> void:
	for tag: StringName in afflictions.keys():
		var a: Dictionary = afflictions[tag]
		match tag:
			&"venom":
				if float(a.magnitude) >= 0.1:
					a.magnitude = minf(float(a.magnitude) + VENOM_CREEP * delta, 1.0)
			&"drowsy":
				a.magnitude = float(a.magnitude) - DROWSY_DECAY * delta
				if _body() and _body().effect(&"keen") >= 1.0:
					a.magnitude = 0.0
			_:
				a.remaining = float(a.remaining) - delta
				if float(a.remaining) <= 0.0:
					a.magnitude = 0.0
		if float(a.magnitude) <= 0.001:
			clear_status(tag)


func _step_mood(delta: float) -> void:
	if dread < dread_target:
		dread = minf(dread + DREAD_RISE * dread_gain_scale() * delta, dread_target)
	elif dread > dread_target:
		var fall := DREAD_FALL * (2.0 if ease >= 0.5 else 1.0)
		dread = maxf(dread - fall * delta, dread_target)
	ease_pulse = maxf(ease_pulse - 0.02 * delta, 0.0)
	_mood_clock -= delta
	if _mood_clock <= 0.0 and (absf(dread - _mood_sent.x) > 0.02 or absf(ease - _mood_sent.y) > 0.02):
		_mood_clock = 0.1
		_mood_sent = Vector2(dread, ease)
		Gameplay.emit(&"player_mood_changed", [dread, ease])


func _step_derived(delta: float) -> void:
	stuffed_left = maxf(stuffed_left - delta, 0.0)
	well_rested_left = maxf(well_rested_left - delta, 0.0)
	# Start and end events for every live status, so the HUD and audio can pop them.
	var now: Dictionary = {}
	for s in statuses():
		now[s.tag] = s
	for tag: StringName in now:
		if not _active_tags.has(tag):
			Gameplay.emit(&"player_status_changed", [tag, float(now[tag].magnitude), float(now[tag].seconds_left)])
	for tag: StringName in _active_tags:
		if not now.has(tag):
			Gameplay.emit(&"player_status_changed", [tag, 0.0, 0.0])
	_active_tags = now


func _step_grab(delta: float) -> void:
	if not is_grabbed():
		return
	grab_time_left -= delta
	if grab_time_left <= 0.0:
		_end_grab()


func _step_hazards(delta: float) -> void:
	var body := _body()
	if affliction(&"venom") >= VENOM_DRAIN_FROM and _tick(&"venom_drain", delta, 0.5):
		take_hit(&"venom", AttackTable.resolve(&"venom_drain"), 1.0)
	if body:
		_cold_over = _cold_over + delta if body.cold > COLD_EXPOSURE_AT and body.effect(&"warm") < 1.5 else 0.0
		if _cold_over >= COLD_EXPOSURE_AFTER and _tick(&"cold_exposure", delta, 5.0):
			var row := AttackTable.resolve(&"cold_exposure")
			var floor_row := row.duplicate() as AttackData
			floor_row.floor_hp = 15.0 if in_human_realm() else 30.0
			take_hit(&"cold", floor_row)
		var elements: Variant = body.element_state
		if elements and float(elements.fire) > 0.0 and _tick(&"fire", delta, 0.5):
			var cool := clampf(body.effect(&"cool") * 0.25, 0.0, 0.6)
			take_hit(&"fire", AttackTable.resolve(&"fire"), 1.0 - cool)
	_step_fall()


func _step_fall() -> void:
	var body3 := player as CharacterBody3D
	if body3 == null or not body3.is_inside_tree():
		return
	var on_floor := body3.is_on_floor()
	var y := body3.global_position.y
	if on_floor and not _was_on_floor:
		var height := _stood_y - y
		if height > FALL_SAFE_M:
			var row := AttackTable.resolve(&"fall").duplicate() as AttackData
			row.can_knock_down = height > FALL_KNOCKDOWN_M
			if height <= 8.0:
				row.reaction = &"light"
			take_hit(&"fall", row, height - FALL_SAFE_M)
	if on_floor:
		_stood_y = y
	_was_on_floor = on_floor


## A teleport is not a fall: the ground she left stays behind.
func forget_fall() -> void:
	_stood_y = player.global_position.y if player is Node3D and (player as Node3D).is_inside_tree() else -INF
	_was_on_floor = true


## True once every `period` seconds while a hazard lasts.
func _tick(key: StringName, delta: float, period: float) -> bool:
	var t := float(_hazard_tick.get(key, period)) + delta
	if t >= period:
		_hazard_tick[key] = 0.0
		return true
	_hazard_tick[key] = t
	return false


## Hands her mood and afflictions to the body (stamina regen, max stamina).
func _apply_to_body() -> void:
	var body := _body()
	if body:
		body.vitals_regen_scale = (1.0 + 0.3 * ease) * (1.0 - 0.3 * dread) * (1.15 if well_rested_left > 0.0 else 1.0)
		body.vitals_sway = 1.0 + 0.5 * dread + affliction(&"roar_shake") + (0.3 if affliction(&"drowsy") >= 0.5 else 0.0)
		body.vitals_tremor = 0.4 * dread + 1.2 * affliction(&"venom")
	if player and "max_stamina" in player:
		player.set(&"max_stamina", max_stamina())


# --- Helpers ----------------------------------------------------------------

func _set_health(value: float, source_id: StringName) -> void:
	var before := health
	health = clampf(value, 0.0, MAX_HEALTH)
	if not is_equal_approx(before, health):
		_announce_health(health - before, source_id)


func _announce_health(delta: float, source_id: StringName) -> void:
	health_changed.emit(health, MAX_HEALTH, delta, source_id)
	Gameplay.emit(&"player_health_changed", [health, MAX_HEALTH, delta, source_id])


func _status_event(tag: StringName, magnitude: float, seconds: float) -> void:
	status_changed.emit(tag, magnitude, seconds)


func _knockback(row: AttackData, origin: Vector3) -> void:
	var body3 := player as CharacterBody3D
	if body3 == null or row.knockback_m <= 0.0:
		return
	var away := -body3.global_transform.basis.z
	if origin != Vector3.INF:
		away = body3.global_position - origin
	away.y = 0.0
	if away.length_squared() < 0.0001:
		away = body3.global_transform.basis.z
	var push := away.normalized() * row.knockback_m * 3.0
	if row.reaction == &"heavy":
		push.y = 1.5
	body3.velocity += push


func _live(tag: StringName, magnitude: float) -> Dictionary:
	return {"tag": tag, "magnitude": magnitude, "seconds_left": -1.0, "total": -1.0}


func _gauge(tag: StringName, magnitude: float) -> Dictionary:
	var g := _live(tag, magnitude)
	g["stage"] = StatusRules.stage(tag, magnitude)
	return g


func _body() -> BodyState:
	return player.get(&"body_state") as BodyState if player else null


func _hunger() -> float:
	var body := _body()
	return body.hunger if body else 0.0


func _phase() -> String:
	var pm := Gameplay.autoload(&"PhaseManager")
	return String(pm.get(&"current_phase")) if pm else ""


func _gentle() -> bool:
	var settings := Gameplay.autoload(&"GameSettings")
	return settings != null and bool(settings.call(&"get_value", &"gentle_mode"))


func _story_staged() -> bool:
	var sc := Gameplay.autoload(&"StoryControl")
	return sc != null and int(sc.get(&"mode")) != 0 and not _story_control_held


# --- Save ---------------------------------------------------------------------

func save_state() -> Dictionary:
	return {"health": health, "ease": ease, "afflictions": afflictions.duplicate(true),
		"well_rested_left": well_rested_left, "ease_seen": _ease_seen.keys()}


func load_state(data: Dictionary) -> void:
	health = clampf(float(data.get("health", MAX_HEALTH)), 1.0, MAX_HEALTH)
	ease = clampf(float(data.get("ease", 0.0)), 0.0, 1.0)
	well_rested_left = float(data.get("well_rested_left", 0.0))
	afflictions.clear()
	var saved: Dictionary = data.get("afflictions", {})
	for tag in saved:
		afflictions[StringName(tag)] = saved[tag]
	_ease_seen.clear()
	for key in data.get("ease_seen", []):
		_ease_seen[String(key)] = true
	# Nothing that held her or was healing her comes across a load.
	if is_grabbed():
		_end_grab()
	_heal_pending = 0.0
