## Feyre's crouch: the hunter's stance, kept apart from the controller so it can be
## tuned and tested on its own (like JumpMotor).
##
## Crouch (Left Ctrl / gamepad B) toggles it on the ground. While crouched she
## sneaks at `sneak_speed`, the camera pivot sinks with her, and she is harder to
## hear and see: `noise_scale()` and `sight_scale()` are the stealth hooks for
## creature senses. Sprinting or jumping stands her up. `amount` eases 0 -> 1 over
## `drop_time` (smoothstep) and drives the pose blend and the camera, so the drop
## reads as one motion.
##
## The owner calls `step()` once per frame; `changed` fires on every stance change,
## and EventBus.player_stance_changed(crouched) too once that signal exists
## (requested from the story/core lane, R14).
class_name CrouchMotor
extends RefCounted

signal changed(crouched: bool)

const ACTION := &"crouch"
## Sneak speed (m/s): about 40% of her walk, quick enough to keep play moving.
const SNEAK_SPEED := 1.8
## Seconds for the drop into the crouch, and for standing back up.
const DROP_TIME := 0.24
const RISE_TIME := 0.2
## How far the camera pivot sinks at full crouch (m), in proportion to a half-crouch.
const CAMERA_DROP := 0.38
## Stealth at full crouch: multipliers on the noise she makes and on how easily
## she is picked out by sight.
const NOISE_CROUCHED := 0.35
const SIGHT_CROUCHED := 0.55

var sneak_speed: float = SNEAK_SPEED
var crouched: bool = false
## 0 standing .. 1 fully crouched, eased.
var amount: float = 0.0

var _t: float = 0.0


## Registers the crouch action (Left Ctrl, gamepad B) when the input map lacks
## it. Like the bow and interaction keys this is added in code (R14); the
## story/core lane can move it into project.godot without changing anything here.
static func ensure_action() -> void:
	if InputMap.has_action(ACTION):
		return
	InputMap.add_action(ACTION)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_CTRL
	InputMap.action_add_event(ACTION, key)
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_B
	InputMap.action_add_event(ACTION, pad)


## Crouches if standing on the ground, stands if crouched. Returns the new stance.
func toggle(on_floor: bool) -> bool:
	if crouched:
		set_crouched(false)
	elif on_floor:
		set_crouched(true)
	return crouched


func set_crouched(value: bool) -> void:
	if value == crouched:
		return
	crouched = value
	changed.emit(crouched)
	if EventBus.has_signal(&"player_stance_changed"):
		EventBus.emit_signal(&"player_stance_changed", crouched)


## Advances the eased blend. Call once per frame.
func step(delta: float) -> void:
	var time := DROP_TIME if crouched else RISE_TIME
	_t = clampf(_t + (delta / time if crouched else -delta / time), 0.0, 1.0)
	amount = smoothstep(0.0, 1.0, _t)


## Her top ground speed this frame given the uncrouched one.
func limit_speed(speed: float) -> float:
	return lerpf(speed, minf(speed, sneak_speed), amount)


func camera_drop() -> float:
	return CAMERA_DROP * amount


func noise_scale() -> float:
	return lerpf(1.0, NOISE_CROUCHED, amount)


func sight_scale() -> float:
	return lerpf(1.0, SIGHT_CROUCHED, amount)
