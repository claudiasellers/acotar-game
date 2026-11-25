## Feyre's bow as a component of Feyre (plans/combat/bow-combat-design.md).
##
## Controls, as in other bow games on a PC: press fire (left mouse / right
## trigger) and the bow comes up and the string comes back over
## BowData.draw_time; let go and the arrow flies at full power. Every arrow is
## a full-power arrow: letting go early is remembered, and the arrow leaves the
## moment the draw is complete, so a quick click is a quick shot. Holding keeps
## the string back until she lets go. Aim (right mouse / left trigger) is
## optional: it brings the camera in over her shoulder. Letting go of aim while
## the string is held eases it down and looses nothing: the one way to take a
## shot back. The bow stays in her hands for BowTuning.stay_up_s after the
## last shot.
##
## The arrow goes to the crosshair in the middle of the screen: straight for
## the bow's true range, dropping beyond it (Ballistics). When she is calm it
## goes exactly there. Sway is her body failing her, and only that: a draw held
## too long, no breath, cold or hurt hands. The same offset turns the shot and
## moves the crosshair, so what is seen is where it goes. Focus (hold Shift /
## L3 while raised) slows the world through TimeScale, steadies what sway
## there is and costs stamina.
##
## Reads arrows from Gameplay.inventory's quiver. Wet clothing makes wet
## fletching.
class_name BowController
extends Node

signal arrow_type_changed(arrow_item_id: StringName)
signal bow_changed(bow: BowData)
## She pressed the bow key: the bow now in her hand, changed or not.
signal bow_shown(bow: BowData)
## She tried to make an arrow and couldn't: `why` says what is short, in words.
signal craft_failed(arrow_item_id: StringName, why: String)
## The shot was taken back: the string came down and nothing flew.
signal let_down
## An arrow has seated on the string: on the raise, and again after each
## shot's follow-through. The id is the arrow item on the string.
signal nocked(arrow_item_id: StringName)
## The draw has just reached the anchor.
signal full_draw
## She reached for an arrow with the bow raised and the quiver empty.
signal quiver_empty
signal focus_changed(focused: bool)

const ARROW_DIR := "res://data/arrows"
const BOW_DIR := "res://data/bows"
const TUNING := preload("res://data/bows/bow_tuning.tres")
## The TimeScale request Focus holds.
const SLOW_ID := &"bow_slow"
## The only type drawn automatically when the chosen one runs out. Special
## arrows (ash above all) are never spent by accident.
const FALLBACK_ARROW := &"arrow_wood"
## An aim point nearer the bow than this (m) can't be shot at across her own
## body: the arrow leaves along the camera's line.
const NEAR_AIM := 2.0
## The crosshair dims when the arrow's line stops this far (m) short of it.
const BLOCKED_SHORT := 0.75
## The satchel's quick slots use the D-pad while this is held; the bow's
## D-pad presses wait.
const QUICK_CHORD := SatchelHud.ACTION_CHORD

## item id -> ArrowData, from data/arrows (adding an arrow needs no code).
static var _arrow_data: Dictionary = {}

var feyre: Feyre
var bow: BowData
var tuning: BowTuning = TUNING
## 0..1 progress of the draw. The arrow leaves at 1.
var draw_amount: float = 0.0
## The bow is up and in use: fire or aim is held and the scene allows shooting.
var is_aiming: bool = false
## Put away and kept away (stow()).
var stowed := false
## Aim is held: the camera is in over her shoulder.
var is_precise: bool = false
## Up with an arrow on the string: she can draw, and Focus.
var is_nocked: bool = false
## The string is coming back or held back (fire held, or a shot owed).
var is_drawing: bool = false
## Focus is on: the world is slowed and the sway steadied.
var is_focused: bool = false
var selected: StringName = &"arrow_wood"
## The bow you can see (on her back, up in her hands) and the arrow card.
var visual: BowVisual
var quiver_card: QuiverCard
var reticle: AimReticle

## Game time for the sway wobble (it slows with the world, so Focus looks steady).
var _time: float = 0.0
## Real seconds held at full draw (the trembling arm).
var _held_full: float = 0.0
## Real seconds left of the follow-through before the next draw.
var _recover: float = 0.0
## Aim was held at some point in this draw, so letting go of it takes the shot back.
var _aimed_this_draw: bool = false
## The shot was taken back with fire still down: that press is spent.
var _taken_back: bool = false
## She has let go of the string before the draw was complete (or clicked in
## the follow-through): one arrow is owed, and leaves when the draw is full.
var _owed: bool = false
## An arrow is seated on the string; fire was held last tick.
var _seated: bool = false
var _fire_was_held: bool = false
## Real seconds Focus holds after a Focused release.
var _focus_linger: float = 0.0
## Focus ended (a shot, a hit, no breath) with its key still down: it needs a
## fresh press.
var _focus_used: bool = false


func _ready() -> void:
	feyre = get_parent() as Feyre
	bow = feyre.bow
	reticle = AimReticle.new(self)
	HudLayout.of(get_tree()).place(reticle, HudLayout.Zone.WORLD, self)
	visual = BowVisual.new(self)
	add_child(visual)
	quiver_card = QuiverCard.new(self)
	add_child(quiver_card)
	if Gameplay.inventory.count(&"bow_%s" % bow.id) == 0:
		Gameplay.inventory.add(&"bow_%s" % bow.id)
	EventBus.player_hit.connect(_on_player_hit)


func _exit_tree() -> void:
	TimeScale.release(SLOW_ID)


## The wheel is read in _input: with the bow raised it is the bow's, before
## anything else can take the scroll.
func _input(event: InputEvent) -> void:
	if not is_up():
		return
	if event.is_action_pressed(&"arrow_next"):
		cycle_arrow()
	elif event.is_action_pressed(&"arrow_prev"):
		cycle_arrow(-1)


func _unhandled_input(event: InputEvent) -> void:
	if stowed or Input.is_action_pressed(QUICK_CHORD):
		return
	if event.is_action_pressed(&"cycle_arrow"):
		cycle_arrow()
	elif event.is_action_pressed(&"cycle_bow") and not is_aiming:
		cycle_bow()
	elif event.is_action_pressed(&"craft_arrow"):
		if craft_selected():
			arrow_type_changed.emit(selected)


func _physics_process(delta: float) -> void:
	# A click shorter than a tick is still a click.
	update_bow(delta, Input.is_action_pressed(&"aim"),
		Input.is_action_pressed(&"fire") or Input.is_action_just_pressed(&"fire"),
		Input.is_action_pressed(&"focus"))


## One tick of the bow, separated from input so tests can drive it. `delta` is
## game time; her own hands (the draw, the follow-through) run on real time,
## so in the Focus hush the world slows and she does not. Returns the arrow
## loosed this tick, if any.
func update_bow(delta: float, aim_held: bool, fire_held: bool, focus_held: bool = false) -> Arrow:
	var real := TimeScale.real(delta)
	_time += delta
	_recover = maxf(_recover - real, 0.0)
	var allowed := can_shoot()
	if not allowed or _available() == &"":
		_owed = false
	elif _fire_was_held and not fire_held and not _taken_back:
		# She has let go of the string: an arrow will fly, now or when the draw is full.
		_owed = true
	if not fire_held:
		_taken_back = false
	elif is_drawing and _aimed_this_draw and not aim_held:
		# Aim let go with the string still held: the shot is taken back.
		_let_down()
		_taken_back = true
		_owed = false
	var drawing_hand := (fire_held and not _taken_back) or _owed
	is_precise = aim_held and allowed
	is_aiming = allowed and (aim_held or drawing_hand)
	is_nocked = is_aiming and _available() != &""
	_note_string(fire_held)
	if drawing_hand and is_aiming and visual:
		# Her draw keeps the bow up a moment for the next arrow; a bow raised
		# only to aim comes down with the aim.
		visual.hold_ready(tuning.stay_up_s)
	var arrow: Arrow = null
	if not is_nocked or _recover > 0.0 or not drawing_hand:
		# Lowered, empty, in the follow-through, or the string not held.
		is_drawing = false
		draw_amount = 0.0
		_held_full = 0.0
		_aimed_this_draw = false
	else:
		is_drawing = true
		_aimed_this_draw = _aimed_this_draw or aim_held
		var before := draw_amount
		draw_amount = minf(draw_amount + real / maxf(bow.draw_time, 0.001), 1.0)
		if draw_amount >= 1.0 and before < 1.0:
			full_draw.emit()
		if _owed and draw_amount >= 1.0:
			arrow = _loose()
			# Nothing is owed now: she is aiming only if something is still held.
			is_aiming = aim_held or fire_held
			is_nocked = is_aiming and _available() != &""
	_update_hold(real)
	_update_focus(real, focus_held)
	return arrow


## The bow is hers to use: not stowed, and the story has not taken it.
func can_shoot() -> bool:
	return not stowed and StoryControl.can_shoot()


## Puts the bow away and keeps it away (in the saddle), or gives it back.
## Stowed, it comes down on the next tick, the Focus hush ends, and Q, F, B
## and the wheel do nothing.
func stow(away: bool) -> void:
	stowed = away
	if away:
		_focus_linger = 0.0
		if visual:
			visual.ready_timer = 0.0


## Makes `id` the arrow on the string.
func select_arrow(id: StringName) -> void:
	selected = id
	arrow_type_changed.emit(id)


func _loose() -> Arrow:
	var in_focus := is_focused
	var arrow := release()
	_owed = false
	is_drawing = false
	_aimed_this_draw = false
	draw_amount = 0.0
	_held_full = 0.0
	if arrow == null:
		return null
	_recover = tuning.follow_through_s
	if in_focus:
		# The hush holds a moment more, so she sees the arrow leave in it.
		_focus_linger = tuning.focus_hold_after_release_s
		_focus_used = true
	if feyre.camera_control:
		feyre.camera_control.kick(bow.kick_degrees, tuning.kick_rise_s, tuning.kick_fall_s)
	return arrow


## What the string tells whoever listens (sound, the reticle): an arrow
## seating, and her hand finding the quiver empty.
func _note_string(fire_held: bool) -> void:
	var seated := is_nocked and _recover <= 0.0
	if seated and not _seated:
		nocked.emit(_available())
	_seated = seated
	if is_aiming and not is_nocked and fire_held and not _fire_was_held:
		quiver_empty.emit()
	_fire_was_held = fire_held


func _let_down() -> void:
	is_drawing = false
	draw_amount = 0.0
	_held_full = 0.0
	_aimed_this_draw = false
	let_down.emit()


## The bow is in her hands: in use, or still up after the last shot.
func is_up() -> bool:
	return is_aiming or (visual != null and visual.wants_raised())


## The trembling arm: a full draw held past fatigue_after_s costs stamina.
func _update_hold(real: float) -> void:
	if not (is_drawing and draw_amount >= 1.0):
		_held_full = 0.0
		return
	_held_full += real
	if _held_full > tuning.fatigue_after_s:
		feyre.drain_stamina(tuning.hold_drain * real)


func _update_focus(real: float, focus_held: bool) -> void:
	var was := is_focused
	if not focus_held:
		_focus_used = false
	if _focus_linger > 0.0:
		_focus_linger -= real
		is_focused = _focus_linger > 0.0
	else:
		var can := is_nocked and feyre.stamina > 0.0 and not feyre.is_winded()
		if focus_held and not can and was:
			_focus_used = true
		is_focused = focus_held and can and not _focus_used
		if is_focused:
			feyre.drain_stamina(tuning.focus_drain * (1.0 + tuning.focus_dread_drain * _dread()) * real)
	if is_focused:
		TimeScale.request(SLOW_ID, tuning.focus_scale)
	else:
		TimeScale.release(SLOW_ID)
	if is_focused != was:
		focus_changed.emit(is_focused)


## A sidestep keeps the bow up and half the draw (bow design §3).
func sidestepped() -> void:
	draw_amount *= tuning.draw_kept_when_sidestepping
	_held_full = 0.0


## A blow breaks her Focus and costs her half the draw (bow design §5.6).
func _on_player_hit(_source: StringName, _attack: StringName, _scale: float, _origin: Vector3) -> void:
	draw_amount *= tuning.draw_kept_when_hit
	_held_full = 0.0
	_focus_linger = 0.0
	if is_focused:
		_focus_used = true
		is_focused = false
		TimeScale.release(SLOW_ID)
		focus_changed.emit(false)


func _dread() -> float:
	return feyre.vitals.dread if feyre.vitals else 0.0


## How tired her draw arm is from holding at full draw: 0 until
## fatigue_after_s, then rising to 1 at the sway's fatigue_max.
func fatigue() -> float:
	if _held_full <= tuning.fatigue_after_s or tuning.fatigue_max <= 1.0:
		return 0.0
	return minf((_held_full - tuning.fatigue_after_s) * tuning.fatigue_rate / (tuning.fatigue_max - 1.0), 1.0)


## Degrees of aim sway right now: none while she is calm and whole. Each of
## these adds its share of the bow's own sway: a draw held too long, low
## breath, and what BodyState reports once it is past ordinary hunger, cold
## and fear (BowTuning.steady_body, steady_tremor); a tremor adds degrees
## outright. Focus steadies all of it.
func sway_degrees() -> float:
	if not is_nocked:
		return 0.0
	var body := feyre.body_state
	var failing := maxf(body.sway_multiplier() - tuning.steady_body, 0.0) if body else 0.0
	var tremor := maxf(body.tremor_degrees() - tuning.steady_tremor, 0.0) if body else 0.0
	failing += fatigue() * (tuning.fatigue_max - 1.0)
	if feyre.is_winded():
		failing += tuning.breath_winded - 1.0
		tremor += tuning.breath_winded_tremor
	elif feyre.stamina < feyre.max_stamina * tuning.breath_low_fraction:
		failing += tuning.breath_low - 1.0
	var focus := 1.0
	if is_focused:
		focus = tuning.focus_sway_panic if _dread() > tuning.panic_dread else tuning.focus_sway
	return (bow.sway_degrees * maxf(failing, 0.0) + tremor) * focus


## The sway right now as a turn of the aim: radians of yaw (x) and pitch (y).
func sway_angles() -> Vector2:
	var degrees := deg_to_rad(sway_degrees())
	if degrees <= 0.0:
		return Vector2.ZERO
	return degrees * Vector2(0.7 * sin(_time * 1.9) + 0.3 * sin(_time * 5.3),
			0.7 * sin(_time * 1.3 + 1.0) + 0.3 * sin(_time * 4.1))


## Turns `v` by the current sway.
func sway_offset(v: Vector3) -> Vector3:
	var turn := sway_angles()
	if turn == Vector2.ZERO or v == Vector3.ZERO:
		return v
	var right := v.cross(Vector3.UP).normalized()
	if right == Vector3.ZERO:
		right = Vector3.RIGHT
	return v.rotated(Vector3.UP, turn.x).rotated(right, turn.y).normalized()


## The camera FOV change for the bow right now (MovementFeel, the one FOV
## owner, adds it).
func fov_offset() -> float:
	if is_focused:
		return tuning.fov_focus
	return tuning.fov_raised if is_precise else 0.0


static func arrow_data() -> Dictionary:
	if _arrow_data.is_empty():
		for file in ResourceLoader.list_directory(ARROW_DIR):
			if file.ends_with(".tres") or file.ends_with(".res"):
				var d := load(ARROW_DIR.path_join(file)) as ArrowData
				if d:
					_arrow_data[d.item_id] = d
	return _arrow_data


static func arrow_types() -> Array[StringName]:
	var types: Array[StringName] = []
	for id: StringName in arrow_data():
		types.append(id)
	types.sort()
	types.erase(FALLBACK_ARROW)
	types.push_front(FALLBACK_ARROW)
	return types


## Bows Feyre owns (inventory items "bow_<id>"), as BowData.
func owned_bows() -> Array[BowData]:
	var out: Array[BowData] = []
	for item_id: StringName in Gameplay.inventory.contents(Inventory.BOWS):
		var path := BOW_DIR.path_join(String(item_id).trim_prefix("bow_") + ".tres")
		if ResourceLoader.exists(path):
			out.append(load(path) as BowData)
	out.sort_custom(func(a: BowData, b: BowData) -> bool: return String(a.id) < String(b.id))
	return out


func equip_bow(bow_id: StringName) -> bool:
	for b in owned_bows():
		if b.id == bow_id:
			bow = b
			feyre.bow = b
			bow_changed.emit(b)
			return true
	return false


func cycle_bow() -> void:
	var bows := owned_bows()
	if bows.size() >= 2:
		var i := bows.map(func(b: BowData) -> StringName: return b.id).find(bow.id)
		equip_bow(bows[(i + 1) % bows.size()].id)
		Juice.burst(feyre, &"pickup")
	bow_shown.emit(bow)


## The next type she has arrows of (`direction` -1 goes back).
func cycle_arrow(direction: int = 1) -> void:
	var types := arrow_types()
	var i := types.find(selected)
	for step in range(1, types.size() + 1):
		var next := types[posmod(i + step * direction, types.size())]
		if Gameplay.inventory.arrow_count(next) > 0:
			selected = next
			break
	arrow_type_changed.emit(selected)


## Crafts one of the selected arrow type if Feyre has the materials.
func craft_selected() -> bool:
	var recipe := Crafting.recipe(selected)
	var made := recipe != null and Crafting.craft(recipe, Gameplay.inventory) > 0
	if made:
		Juice.burst(feyre, &"craft")
	else:
		craft_failed.emit(selected, why_not(recipe))
	return made


## Why `recipe` can't be made right now, for the quiver card: "needs 1 shaft,
## 1 feather", "made at the fletching bench", "no room in the quiver".
static func why_not(recipe: CraftRecipe) -> String:
	if recipe == null:
		return "not something she can make"
	if recipe.station != &"":
		return "made at the %s" % String(recipe.station).replace("_", " ")
	var short := Crafting.missing(recipe, Gameplay.inventory)
	if short.is_empty():
		return "no room in the quiver"
	var parts := PackedStringArray()
	for key: String in short:
		parts.append("%d %s" % [int(short[key]), _input_name(key)])
	return "needs " + ", ".join(parts)


## "tag:fletching" -> "fletching"; an item id -> its name, lower case.
static func _input_name(key: String) -> String:
	if key.begins_with("tag:"):
		return key.substr(4).replace("_", " ")
	var item := ItemCatalog.get_item(StringName(key))
	return item.display_name.to_lower() if item else key.replace("_", " ")


## Where the muzzle sits right now.
func muzzle() -> Vector3:
	return feyre.global_position + Vector3.UP * 1.45 - feyre.model.global_basis.z * 0.45


## The direction an arrow loosed this instant would leave the bow: from the
## bow to the point under the crosshair, turned by the sway, then by soft aim
## on a pad. The crosshair shows the same sway, so it is where the arrow goes.
func shot_direction() -> Vector3:
	var from := muzzle()
	var forward := -feyre.camera.global_basis.z
	var to := feyre.aim_point() - from
	var aim := forward if to.length() < NEAR_AIM or to.dot(forward) <= 0.0 else to.normalized()
	return SoftAim.bend(get_tree(), from, aim, sway_offset(aim))


## Something stands between the bow and the point under the crosshair (a
## trunk beside her, a rock at her knee): the arrow would stop short of it.
func line_blocked() -> bool:
	var from := muzzle()
	var to := feyre.aim_point()
	var query := PhysicsRayQueryParameters3D.create(from, to, Feyre.WORLD_MASK, [feyre.get_rid()])
	var hit := feyre.get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and (hit.position as Vector3).distance_to(to) > BLOCKED_SHORT


## Seconds an arrow from this bow flies dead straight (Ballistics.gravity_share's hold).
func true_flight_s() -> float:
	return bow.true_range / maxf(bow.max_speed, 0.001)


## Steps a shot through the world until it hits something (or `max_time`),
## as the arrow itself flies: `true_flight_s` and `gravity_blend_s` are
## Arrow.launch's. Returns {"point", "hit": bool, "time", "collider"}.
static func predict_path(from: Vector3, velocity: Vector3, drag: float, space: PhysicsDirectSpaceState3D,
		exclude: Array[RID] = [], wind_source: Node = null, max_time: float = 3.0, dt: float = 1.0 / 60.0,
		true_flight_s: float = 0.0, gravity_blend_s: float = 0.0) -> Dictionary:
	var gravity := float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	var p := from
	var v := velocity
	var t := 0.0
	while t < max_time:
		var wind := Vector3.ZERO
		if wind_source and wind_source.has_method(&"wind_at"):
			wind = wind_source.wind_at(p)
		t += dt
		v = Ballistics.step(v, wind, drag, gravity, dt, Ballistics.gravity_share(t, true_flight_s, gravity_blend_s))
		var next := p + v * dt
		if space:
			var query := PhysicsRayQueryParameters3D.create(p, next, Arrow.MASK_WORLD_AND_TARGETS, exclude)
			var hit := space.intersect_ray(query)
			if hit:
				return {"point": hit.position, "hit": true, "time": t, "collider": hit.collider}
		p = next
		if p.y < Arrow.KILL_DEPTH:
			break
	return {"point": p, "hit": false, "time": t, "collider": null}


## Looses the nocked arrow, at the bow's full speed.
func release() -> Arrow:
	var arrow_item := _available()
	if arrow_item == &"" or Gameplay.inventory.remove(arrow_item, 1) == 0:
		return null
	var muzzle := muzzle()
	var direction := shot_direction()
	var arrow := Arrow.create(arrow_data()[arrow_item])
	feyre.get_parent().add_child(arrow)
	arrow.add_collision_exception_with(feyre)
	var wet := feyre.element_state != null and feyre.element_state.is_wet()
	arrow.launch(muzzle, direction, bow.max_speed, wet, bow.id, true_flight_s(), tuning.gravity_blend_s)
	feyre.quiver_changed.emit(Gameplay.inventory.arrow_count())
	feyre.arrow_fired.emit(arrow)
	feyre.bow_released.emit(muzzle, bow.loudness)
	return arrow


func _available() -> StringName:
	if Gameplay.inventory.arrow_count(selected) > 0:
		return selected
	if Gameplay.inventory.arrow_count(FALLBACK_ARROW) > 0:
		selected = FALLBACK_ARROW
		return FALLBACK_ARROW
	return &""
