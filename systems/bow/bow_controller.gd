## The hunting bow (root doc §4.3) as a component of Feyre: draw, sway,
## slow time while stamina lasts, choose an arrow type, release, craft.
##
## Reads arrows from Gameplay.inventory's quiver. Body state adds sway and
## bow-hand tremor; wet clothing makes wet fletching.
class_name BowController
extends Node

signal arrow_type_changed(arrow_item_id: StringName)

## Time scale while drawing and aiming with stamina left.
const SLOW_TIME_SCALE := 0.4
## Stamina per real second while time is slowed.
const SLOW_TIME_DRAIN := 28.0
## Draw needed before time slows.
const SLOW_TIME_MIN_DRAW := 0.35
const ARROW_TYPES: Array[StringName] = [&"arrow_wood", &"arrow_ash"]
const ARROW_DATA := {
	&"arrow_wood": preload("res://data/arrows/wood.tres"),
	&"arrow_ash": preload("res://data/arrows/ash.tres"),
}
## Noise a release makes, for creature hearing (0..1).
const RELEASE_LOUDNESS := 0.45

var feyre: Feyre
var bow: BowData
var draw_amount: float = 0.0
var is_drawing: bool = false
var selected: StringName = &"arrow_wood"
var slowing: bool = false

var _time: float = 0.0


func _ready() -> void:
	feyre = get_parent() as Feyre
	bow = feyre.bow
	_ensure_actions()


func _exit_tree() -> void:
	if slowing:
		Engine.time_scale = 1.0


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"cycle_arrow"):
		cycle_arrow()
	elif event.is_action_pressed(&"craft_arrow"):
		craft_selected()


func _physics_process(delta: float) -> void:
	_time += delta
	update_draw(delta, Input.is_action_pressed(&"fire"), Input.is_action_pressed(&"aim"))


## Draw/release logic, separated from input so tests can drive it.
func update_draw(delta: float, fire_held: bool, aiming: bool) -> void:
	if fire_held and can_shoot() and _available() != &"":
		is_drawing = true
		draw_amount = minf(draw_amount + delta / bow.draw_time, 1.0)
	elif is_drawing:
		release()
		is_drawing = false
		draw_amount = 0.0
	_update_slow_time(delta, aiming)


## Story control (story lane autoload) can forbid shooting in anchored scenes.
func can_shoot() -> bool:
	var control := Gameplay.autoload(&"StoryControl")
	if control and control.has_method(&"can_shoot"):
		return bool(control.can_shoot())
	return true


static func slow_time_scale(drawing: bool, aiming: bool, stamina: float, draw: float) -> float:
	if drawing and aiming and stamina > 0.0 and draw >= SLOW_TIME_MIN_DRAW:
		return SLOW_TIME_SCALE
	return 1.0


func _update_slow_time(delta: float, aiming: bool) -> void:
	var scale := slow_time_scale(is_drawing, aiming, feyre.stamina, draw_amount)
	slowing = scale < 1.0
	if slowing:
		# delta is scaled game time; drain in real seconds.
		feyre.drain_stamina(SLOW_TIME_DRAIN * delta / maxf(Engine.time_scale, 0.01))
	if not is_equal_approx(Engine.time_scale, scale):
		Engine.time_scale = scale


func cycle_arrow() -> void:
	var i := ARROW_TYPES.find(selected)
	for step in range(1, ARROW_TYPES.size() + 1):
		var next := ARROW_TYPES[(i + step) % ARROW_TYPES.size()]
		if Gameplay.inventory.arrow_count(next) > 0:
			selected = next
			break
	arrow_type_changed.emit(selected)


## Crafts one of the selected arrow type if Feyre has the materials.
func craft_selected() -> bool:
	var made := Crafting.craft(Crafting.recipe(selected), Gameplay.inventory) > 0
	if made:
		Juice.burst(feyre, &"craft")
	return made


## Degrees of aim error right now (bow sway grows with draw, body state on top).
func sway_degrees() -> float:
	var body := feyre.body_state
	var mult := body.sway_multiplier() if body else 1.0
	var tremor := body.tremor_degrees() if body else 0.0
	return bow.sway_degrees * draw_amount * mult + tremor


func release() -> Arrow:
	var arrow_item := _available()
	if arrow_item == &"" or Gameplay.inventory.remove(arrow_item, 1) == 0:
		return null
	var muzzle := feyre.global_position + Vector3.UP * 1.45 - feyre.model.global_basis.z * 0.45
	var direction := (feyre.aim_point() - muzzle).normalized()
	direction = _apply_sway(direction, sway_degrees())
	var arrow := Arrow.create(ARROW_DATA[arrow_item])
	feyre.get_parent().add_child(arrow)
	arrow.add_collision_exception_with(feyre)
	var wet := feyre.element_state != null and feyre.element_state.is_wet()
	arrow.launch(muzzle, direction, lerpf(bow.min_speed, bow.max_speed, draw_amount), wet)
	feyre.quiver_changed.emit(Gameplay.inventory.arrow_count())
	feyre.arrow_fired.emit(arrow)
	feyre.bow_released.emit(muzzle, RELEASE_LOUDNESS)
	return arrow


func _available() -> StringName:
	if Gameplay.inventory.arrow_count(selected) > 0:
		return selected
	for t in ARROW_TYPES:
		# Never fall through to the ash arrow by accident: it is precious.
		if t != &"arrow_ash" and Gameplay.inventory.arrow_count(t) > 0:
			selected = t
			return t
	return &""


func _apply_sway(direction: Vector3, degrees: float) -> Vector3:
	if degrees <= 0.0:
		return direction
	var yaw := deg_to_rad(degrees) * (0.7 * sin(_time * 1.9) + 0.3 * sin(_time * 5.3))
	var pitch := deg_to_rad(degrees) * (0.7 * sin(_time * 1.3 + 1.0) + 0.3 * sin(_time * 4.1))
	var right := direction.cross(Vector3.UP).normalized()
	return direction.rotated(Vector3.UP, yaw).rotated(right, pitch).normalized()


func _ensure_actions() -> void:
	for pair in [[&"cycle_arrow", KEY_Q, JOY_BUTTON_DPAD_RIGHT], [&"craft_arrow", KEY_R, JOY_BUTTON_DPAD_UP]]:
		if InputMap.has_action(pair[0]):
			continue
		InputMap.add_action(pair[0])
		var key := InputEventKey.new()
		key.physical_keycode = pair[1]
		InputMap.action_add_event(pair[0], key)
		var pad := InputEventJoypadButton.new()
		pad.button_index = pair[2]
		InputMap.action_add_event(pair[0], pad)
