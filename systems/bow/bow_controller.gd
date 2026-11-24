## Feyre's bow as a component of Feyre (plans/combat/bow-combat-design.md).
##
## Controls (the BotW-on-PC convention, decided 2026-11-24): hold aim (right
## mouse / left trigger) to raise the bow. Hold fire (left mouse / right
## trigger) to draw the string over BowData.draw_time; release at full draw to
## loose a full-power arrow. Releasing within BowTuning.release_buffer_s of full
## draw still looses (at full draw); releasing earlier lets the string down and
## looses nothing. There are no weak shots. The bow stays raised while aim is
## held, and the next draw can start after the follow-through.
##
## Focus (hold Shift / L3 while drawing) slows the world through TimeScale,
## steadies the sway and costs stamina. Sway is visible: the same offset turns
## the shot and the reticle's ring, so what you see is where it goes.
class_name BowController
extends Node

signal arrow_type_changed(arrow_item_id: StringName)
signal bow_changed(bow: BowData)
## Released too early: the string let down and nothing flew.
signal let_down
signal focus_changed(focused: bool)

const ARROW_DIR := "res://data/arrows"
const BOW_DIR := "res://data/bows"
const TUNING := preload("res://data/bows/bow_tuning.tres")
## The TimeScale request Focus holds.
const SLOW_ID := &"bow_slow"
## The only type drawn automatically when the chosen one runs out. Special
## arrows (ash above all) are never spent by accident.
const FALLBACK_ARROW := &"arrow_wood"
## Horizontal speed (m/s) above which she counts as moving for sway.
const MOVING_SPEED := 0.5

## item id -> ArrowData, from data/arrows (adding an arrow needs no code).
static var _arrow_data: Dictionary = {}

var feyre: Feyre
var bow: BowData
var tuning: BowTuning = TUNING
## 0..1 progress of the draw. A shot always flies at full power.
var draw_amount: float = 0.0
## The bow is up (aim held and the scene allows shooting).
var is_aiming: bool = false
## Up, with an arrow on the string, and fire held (or a buffered release).
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
## 1.0 unsettled, down to tuning.settle_floor when held still.
var _settle: float = 1.0
## Real seconds held at full draw (the trembling arm).
var _held_full: float = 0.0
## Real seconds left of the follow-through before the next draw.
var _recover: float = 0.0
## Released inside the buffer: looses the moment the draw is full.
var _loose_pending: bool = false
## Real seconds Focus holds after a Focused release.
var _focus_linger: float = 0.0
var _last_aim: Vector3 = Vector3.ZERO


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
	EventBus.player_hit.connect(func(_s: StringName, _a: StringName, _sc: float, _o: Vector3) -> void: _end_focus())


func _exit_tree() -> void:
	TimeScale.release(SLOW_ID)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"cycle_arrow"):
		cycle_arrow()
	elif is_aiming and event.is_action_pressed(&"arrow_next"):
		cycle_arrow()
	elif is_aiming and event.is_action_pressed(&"arrow_prev"):
		cycle_arrow(-1)
	elif event.is_action_pressed(&"cycle_bow") and not is_aiming:
		cycle_bow()
	elif event.is_action_pressed(&"craft_arrow"):
		craft_selected()
		arrow_type_changed.emit(selected)


func _physics_process(delta: float) -> void:
	update_bow(delta, Input.is_action_pressed(&"aim"), Input.is_action_pressed(&"fire"),
		Input.is_action_pressed(&"focus"))


## One tick of the bow, separated from input so tests can drive it. `delta` is
## game time; the feel timers run on real time. Returns the arrow loosed this
## tick, if any.
func update_bow(delta: float, aim_held: bool, fire_held: bool, focus_held: bool = false) -> Arrow:
	var real := delta / maxf(Engine.time_scale, 0.01)
	_time += delta
	_recover = maxf(_recover - real, 0.0)
	is_aiming = aim_held and can_shoot()
	if not is_aiming:
		_loose_pending = false
	var want := is_aiming and _available() != &"" and _recover <= 0.0 and (fire_held or _loose_pending)
	draw_amount = minf(draw_amount + delta / maxf(bow.draw_time, 0.001), 1.0) if want else 0.0
	is_drawing = want
	var arrow: Arrow = null
	if is_drawing and not fire_held and not _loose_pending:
		if draw_amount >= 1.0:
			arrow = _loose()
		elif (1.0 - draw_amount) * bow.draw_time <= tuning.release_buffer_s:
			_loose_pending = true
		else:
			_let_down()
	elif _loose_pending and draw_amount >= 1.0:
		arrow = _loose()
	_update_sway(real)
	_update_focus(real, focus_held)
	return arrow


## Story control (story lane autoload) can forbid shooting in anchored scenes.
func can_shoot() -> bool:
	return StoryControl.can_shoot()


func _loose() -> Arrow:
	var was_focused := is_focused and _focus_linger <= 0.0
	var arrow := release()
	_loose_pending = false
	is_drawing = false
	draw_amount = 0.0
	_held_full = 0.0
	_recover = tuning.follow_through_s
	_settle = maxf(_settle, 0.7)
	if arrow and was_focused:
		_focus_linger = tuning.focus_hold_after_release_s
	return arrow


func _let_down() -> void:
	is_drawing = false
	draw_amount = 0.0
	_held_full = 0.0
	let_down.emit()


func _update_sway(real: float) -> void:
	var aim := Vector3.ZERO
	if feyre.camera:
		aim = -feyre.camera.global_basis.z
	var turn := rad_to_deg(_last_aim.angle_to(aim)) / maxf(real, 0.0001) if _last_aim != Vector3.ZERO else 0.0
	_last_aim = aim
	if not is_drawing:
		_settle = 1.0
		_held_full = 0.0
		return
	if turn > tuning.settle_reset_turn_dps or _moving():
		_settle = minf(_settle + tuning.unsettle_rate * real, 1.0)
	else:
		var speed := tuning.focus_settle_speed if is_focused else 1.0
		var rate := (1.0 - tuning.settle_floor) / maxf(tuning.settle_s, 0.01) * speed
		_settle = maxf(_settle - rate * real, tuning.settle_floor)
	if draw_amount >= 1.0:
		_held_full += real
		if _held_full > tuning.fatigue_after_s:
			feyre.drain_stamina(tuning.hold_drain * real)


func _update_focus(real: float, focus_held: bool) -> void:
	var was := is_focused
	if _focus_linger > 0.0:
		_focus_linger -= real
		is_focused = _focus_linger > 0.0
	else:
		is_focused = is_drawing and focus_held and feyre.stamina > 0.0 and not feyre.is_winded()
		if is_focused:
			feyre.drain_stamina(tuning.focus_drain * (1.0 + tuning.focus_dread_drain * _dread()) * real)
	if is_focused:
		TimeScale.request(SLOW_ID, tuning.focus_scale)
	else:
		TimeScale.release(SLOW_ID)
	if is_focused != was:
		focus_changed.emit(is_focused)


func _end_focus() -> void:
	_focus_linger = 0.0
	if is_focused:
		is_focused = false
		TimeScale.release(SLOW_ID)
		focus_changed.emit(false)


func _dread() -> float:
	return feyre.vitals.dread if feyre.vitals else 0.0


func _moving() -> bool:
	return Vector2(feyre.velocity.x, feyre.velocity.z).length() > MOVING_SPEED


## Degrees of aim sway right now (design doc §5.2).
func sway_degrees() -> float:
	var body := feyre.body_state
	var body_mult := body.sway_multiplier() if body else 1.0
	var tremor := body.tremor_degrees() if body else 0.0
	var fatigue := 1.0
	if _held_full > tuning.fatigue_after_s:
		fatigue = minf(1.0 + (_held_full - tuning.fatigue_after_s) * tuning.fatigue_rate, tuning.fatigue_max)
	var crouched := feyre.crouch != null and feyre.crouch.crouched
	var stance := tuning.stance_still
	if _moving():
		stance = tuning.stance_crouch_walking if crouched else tuning.stance_walking
	elif crouched:
		stance = tuning.stance_crouched
	var breath := 1.0
	if feyre.is_winded():
		breath = tuning.breath_winded
		tremor += tuning.breath_winded_tremor
	elif feyre.stamina < feyre.max_stamina * tuning.breath_low_fraction:
		breath = tuning.breath_low
	var focus := 1.0
	if is_focused:
		focus = tuning.focus_sway_panic if _dread() > tuning.panic_dread else tuning.focus_sway
	return bow.sway_degrees * draw_amount * _settle * fatigue * stance * breath * focus * body_mult + tremor * draw_amount


## Turns `v` by the current sway. The shot and the reticle both go through
## here, so the ring is where the arrow goes.
func sway_offset(v: Vector3) -> Vector3:
	var degrees := sway_degrees()
	if degrees <= 0.0 or v == Vector3.ZERO:
		return v
	var yaw := deg_to_rad(degrees) * (0.75 * sin(_time * 1.3) + 0.25 * sin(_time * 3.1))
	var pitch := deg_to_rad(degrees) * (0.75 * sin(_time * 1.1 + 1.0) + 0.25 * sin(_time * 2.7))
	var right := v.cross(Vector3.UP).normalized()
	if right == Vector3.ZERO:
		right = Vector3.RIGHT
	return v.rotated(Vector3.UP, yaw).rotated(right, pitch)


## The camera FOV change for the bow right now (MovementFeel adds it).
func fov_offset() -> float:
	if is_focused:
		return tuning.fov_focus
	return tuning.fov_raised if is_aiming else 0.0


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
	if bows.size() < 2:
		return
	var i := bows.map(func(b: BowData) -> StringName: return b.id).find(bow.id)
	equip_bow(bows[(i + 1) % bows.size()].id)
	Juice.burst(feyre, &"pickup")


## Steps to the next (or, with step -1, previous) type she has any of.
func cycle_arrow(step: int = 1) -> void:
	var types := arrow_types()
	var i := types.find(selected)
	for n in range(1, types.size() + 1):
		var next := types[posmod(i + n * step, types.size())]
		if Gameplay.inventory.arrow_count(next) > 0:
			selected = next
			break
	arrow_type_changed.emit(selected)


## Crafts one of the selected arrow type if Feyre has the materials.
func craft_selected() -> bool:
	var recipe := Crafting.recipe(selected)
	if recipe == null:
		return false
	var made := Crafting.craft(recipe, Gameplay.inventory) > 0
	if made:
		Juice.burst(feyre, &"craft")
	return made


## Where the muzzle sits right now.
func muzzle() -> Vector3:
	return feyre.global_position + Vector3.UP * 1.45 - feyre.model.global_basis.z * 0.45


## Where an arrow released now would land before sway (F5): the same
## gravity, drag and wind as the real flight, stepped and ray-checked.
func predict_impact() -> Dictionary:
	var item := _available()
	var d: ArrowData = arrow_data().get(item if item != &"" else FALLBACK_ARROW)
	var wet := feyre.element_state != null and feyre.element_state.is_wet()
	var speed := bow.max_speed * (d.wet_speed_multiplier if wet and d else 1.0)
	var drag := (d.drag * (d.wet_drag_multiplier if wet else 1.0)) if d else 0.0022
	var from := muzzle()
	var wind := get_tree().get_first_node_in_group(&"wind_source")
	return BowController.predict_path(from, (feyre.aim_point() - from).normalized() * speed, drag,
		feyre.get_world_3d().direct_space_state, [feyre.get_rid()], wind)


## A predicted impact point turned by the current sway about the muzzle: where
## the ring is drawn.
func swayed_point(point: Vector3) -> Vector3:
	var from := muzzle()
	return from + sway_offset(point - from)


## Steps a shot through the world until it hits something (or `max_time`).
## Returns {"point", "hit": bool, "time", "collider"}.
static func predict_path(from: Vector3, velocity: Vector3, drag: float, space: PhysicsDirectSpaceState3D,
		exclude: Array[RID] = [], wind_source: Node = null, max_time: float = 3.0, dt: float = 1.0 / 60.0) -> Dictionary:
	var gravity := float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	var p := from
	var v := velocity
	var t := 0.0
	while t < max_time:
		var wind := Vector3.ZERO
		if wind_source and wind_source.has_method(&"wind_at"):
			wind = wind_source.wind_at(p)
		v = Ballistics.step(v, wind, drag, gravity, dt)
		var next := p + v * dt
		if space:
			var query := PhysicsRayQueryParameters3D.create(p, next, Arrow.MASK_WORLD_AND_TARGETS, exclude)
			var hit := space.intersect_ray(query)
			if hit:
				return {"point": hit.position, "hit": true, "time": t, "collider": hit.collider}
		p = next
		t += dt
		if p.y < Arrow.KILL_DEPTH:
			break
	return {"point": p, "hit": false, "time": t, "collider": null}


## Looses one arrow of the chosen type now, swayed, at full speed.
func release() -> Arrow:
	var arrow_item := _available()
	if arrow_item == &"" or Gameplay.inventory.remove(arrow_item, 1) == 0:
		return null
	var from := muzzle()
	var direction := sway_offset((feyre.aim_point() - from).normalized()).normalized()
	var arrow := Arrow.create(arrow_data()[arrow_item])
	feyre.get_parent().add_child(arrow)
	arrow.add_collision_exception_with(feyre)
	var wet := feyre.element_state != null and feyre.element_state.is_wet()
	arrow.launch(from, direction, bow.max_speed, wet)
	if feyre.camera_control:
		feyre.camera_control.kick(bow.kick_degrees)
	feyre.quiver_changed.emit(Gameplay.inventory.arrow_count())
	feyre.arrow_fired.emit(arrow)
	feyre.bow_released.emit(from, bow.loudness)
	return arrow


func _available() -> StringName:
	if Gameplay.inventory.arrow_count(selected) > 0:
		return selected
	if Gameplay.inventory.arrow_count(FALLBACK_ARROW) > 0:
		selected = FALLBACK_ARROW
		return FALLBACK_ARROW
	return &""
