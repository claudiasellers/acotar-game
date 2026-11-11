## Play-test harness (T097): drives the real game scene with real InputEvents,
## frame by frame, the way a player's keyboard, mouse and pad do, and answers
## questions about what the player would see happen. See README.md here.
##
## Every press goes through Input.parse_input_event, so it reaches the game by
## the same road as a real key: the Input singleton's action state (what
## _physics_process polls) and the viewport's _input/_unhandled_input (what
## menus, the whistle and E listen to). Nothing here calls game methods to act;
## it only reads state to check what happened.
##
## Timing is in frames and conditions, never wall-clock: the gate machine is
## shared with heavy jobs. Engine.max_fps is held at 60 while a harness lives,
## so a frame budget is about game time and real-time timers in the game
## (create_timer) take the same number of frames on a fast or slow machine.

extends RefCounted

const GAME_SCENE := "res://story/act1/act1_game.tscn"
const FPS := 60
## Frames to wait for control after the game scene is added (the World loads
## inside the first frames; a busy gate has taken 15+ s).
const BOOT_FRAMES := 60 * 120
const PAD_DEVICE := 0

var test: GutTest
var game: Node3D
var feyre: Feyre
var _held: Dictionary = {}  ## action -> the pressed event we sent
var _stick := Vector2.ZERO
var _look := Vector2.ZERO
var _old_max_fps: int = 0


func _init(gut_test: GutTest) -> void:
	test = gut_test
	_old_max_fps = Engine.max_fps
	Engine.max_fps = FPS


## Undo everything the harness holds: keys up, stick centred, fps restored.
## Call from after_each/after_all.
func dispose() -> void:
	release_all()
	Engine.max_fps = _old_max_fps


# --- booting -----------------------------------------------------------------

## A fresh story, exactly as New Game reaches the game scene. Returns once she
## can move (the opening shot has handed over), or with feyre null on timeout.
func boot_new_game() -> bool:
	reset_story()
	return await _boot()


## Writes `save` (a SaveSystem dictionary) to `slot` and boots the game through
## Continue, the title screen's road. Returns once she can move.
func boot_from_save(slot: String, save: Dictionary) -> bool:
	reset_story()
	DirAccess.make_dir_recursive_absolute(SaveSystem.SAVE_DIR)
	var f := FileAccess.open("%s/%s.json" % [SaveSystem.SAVE_DIR, slot], FileAccess.WRITE)
	f.store_string(JSON.stringify(save))
	f.close()
	return await boot_slot(slot)


## Continue from a slot already on disk (what Load on the title screen does).
func boot_slot(slot: String) -> bool:
	reset_story()
	GameSettings.pending_load_slot = slot
	return await _boot()


func _boot() -> bool:
	game = (load(GAME_SCENE) as PackedScene).instantiate() as Node3D
	test.add_child(game)
	feyre = game.get(&"feyre") as Feyre
	if feyre == null:
		return false
	return await wait_until(func() -> bool: return has_control(), BOOT_FRAMES)


## Frees the game scene and puts the singletons back to a clean slate.
func shutdown() -> void:
	release_all()
	# Unload the streamed regions while the game that owns them still exists.
	reset_story()
	if game and is_instance_valid(game):
		game.queue_free()
		await test.wait_process_frames(2)
	game = null
	feyre = null


static func reset_story() -> void:
	GameSettings.pending_load_slot = ""
	WorldStreamer.track(null)
	WorldStreamer.unload_all()
	WorldState.clear()
	Gameplay.reset()
	StoryControl.release()
	PhaseManager.phase_set = null
	PhaseManager.current_phase = &""


## The player can walk her: physics on, no story mode holding her, not paused.
func has_control() -> bool:
	return feyre != null and is_instance_valid(feyre) and feyre.is_physics_processing() \
			and StoryControl.mode == StoryControl.Mode.FULL and not test.get_tree().paused


## Setup only (never the verb under test): puts her `drop` m above the ground
## at (x, z) and waits until she stands there. Returns whether she landed.
## `from_y` is where the ground search starts down from: indoors, pass a bit
## above the floor, or the roof is "the ground".
func place_on_ground(x: float, z: float, drop: float = 1.0, max_frames: int = 600, from_y: float = 400.0) -> bool:
	feyre.teleport(Vector3(x, feyre.global_position.y + 60.0, z))
	WorldStreamer.update_for(feyre.global_position)
	var y := NAN
	for i in max_frames:
		y = ground_y(x, z, from_y)
		if not is_nan(y):
			break
		await test.wait_physics_frames(1)
	if is_nan(y):
		return false
	feyre.teleport(Vector3(x, y + drop, z))
	return await wait_until(func() -> bool: return feyre.is_on_floor() and flat_speed() < 0.1, 240)


## She is standing on something solid near where she should be (not falling
## through the world).
func on_solid_ground() -> bool:
	var from := feyre.global_position + Vector3.UP * 0.5
	var y := ground_y(from.x, from.z, from.y)
	return not is_nan(y) and absf(feyre.global_position.y - y) < 0.6


# --- input -------------------------------------------------------------------

## The event a player's first binding for `action` makes (key, then mouse
## button, then pad button), pressed or not.
static func event_for(action: StringName, pressed: bool) -> InputEvent:
	var events := InputMap.action_get_events(action)
	for kind in [&"key", &"mouse", &"pad"]:
		for e: InputEvent in events:
			if kind == &"key" and e is InputEventKey:
				var k := InputEventKey.new()
				k.physical_keycode = (e as InputEventKey).physical_keycode
				k.keycode = (e as InputEventKey).keycode if (e as InputEventKey).keycode != KEY_NONE \
						else (e as InputEventKey).physical_keycode
				k.pressed = pressed
				return k
			if kind == &"mouse" and e is InputEventMouseButton:
				var m := InputEventMouseButton.new()
				m.button_index = (e as InputEventMouseButton).button_index
				m.pressed = pressed
				m.button_mask = MouseButtonMask.MOUSE_BUTTON_MASK_LEFT if pressed and m.button_index == MOUSE_BUTTON_LEFT else 0
				return m
			if kind == &"pad" and e is InputEventJoypadButton:
				var j := InputEventJoypadButton.new()
				j.device = PAD_DEVICE
				j.button_index = (e as InputEventJoypadButton).button_index
				j.pressed = pressed
				j.pressure = 1.0 if pressed else 0.0
				return j
	return null


## Key down for `action`, held until release().
func hold(action: StringName) -> void:
	var e := event_for(action, true)
	assert(e != null, "no binding for %s" % action)
	_held[action] = e
	Input.parse_input_event(e)


func release(action: StringName) -> void:
	if not _held.has(action):
		return
	_held.erase(action)
	Input.parse_input_event(event_for(action, false))


## A tap: down, `frames` process frames, up, then one frame for it to land.
func press(action: StringName, frames: int = 2) -> void:
	hold(action)
	await test.wait_process_frames(maxi(frames, 1))
	release(action)
	await test.wait_process_frames(1)


## Holds `action` for `frames` physics frames, then lets go.
func hold_for(action: StringName, frames: int) -> void:
	hold(action)
	await test.wait_physics_frames(frames)
	release(action)


func release_all() -> void:
	for action: StringName in _held.keys():
		release(action)
	stick(Vector2.ZERO)
	look_stick(Vector2.ZERO)
	# Belt and braces: nothing pressed outlives a test, whatever went wrong.
	for action in [&"move_forward", &"move_back", &"move_left", &"move_right", &"sprint", &"jump",
			&"aim", &"fire", &"interact"]:
		if InputMap.has_action(action):
			Input.action_release(action)


## The left stick, as a pad sends it: x right, y down (forward is y = -1).
func stick(v: Vector2) -> void:
	if v == _stick:
		return
	_stick = v
	for axis_value: Array in [[JOY_AXIS_LEFT_X, v.x], [JOY_AXIS_LEFT_Y, v.y]]:
		var m := InputEventJoypadMotion.new()
		m.device = PAD_DEVICE
		m.axis = axis_value[0]
		m.axis_value = axis_value[1]
		Input.parse_input_event(m)


## Pushes the stick so she heads for `point` from where the camera looks now
## (what a player does watching the screen). `amount` 1 runs, under 0.5 walks.
func stick_toward(point: Vector3, amount: float = 1.0) -> void:
	var to := point - feyre.global_position
	to.y = 0.0
	if to.length() < 0.01:
		stick(Vector2.ZERO)
		return
	# Feyre moves along Vector3(x, 0, y) rotated by the camera yaw.
	var local := to.normalized().rotated(Vector3.UP, -feyre.camera_yaw())
	stick(Vector2(local.x, local.z) * amount)


## The right stick, as a pad sends it (x turns the camera, y tilts it).
func look_stick(v: Vector2) -> void:
	if v == _look:
		return
	_look = v
	for axis_value: Array in [[JOY_AXIS_RIGHT_X, v.x], [JOY_AXIS_RIGHT_Y, v.y]]:
		var m := InputEventJoypadMotion.new()
		m.device = PAD_DEVICE
		m.axis = axis_value[0]
		m.axis_value = axis_value[1]
		Input.parse_input_event(m)


## Turns the camera with the right stick until it faces `point` (within
## `tolerance` radians of yaw). Headless, the mouse is never captured, so the
## stick is how a test looks around. Returns whether it got there.
func look_toward(point: Vector3, tolerance: float = 0.08, max_frames: int = 240) -> bool:
	var ok := false
	for i in max_frames:
		var to := point - feyre.global_position
		var err := angle_difference(feyre.camera_yaw(), atan2(-to.x, -to.z))
		if absf(err) < tolerance:
			ok = true
			break
		# Stick right turns the camera to lower yaw (characters/feyre/feyre.gd _look).
		var push := clampf(-err * 2.0, -1.0, 1.0)
		if absf(push) < 0.3:
			push = 0.3 * signf(push)
		look_stick(Vector2(push, 0.0))
		await test.wait_process_frames(1)
	look_stick(Vector2.ZERO)
	return ok


## Mouse motion, as the mouse sends it (only steers the camera when captured).
func mouse_move(relative: Vector2) -> void:
	var m := InputEventMouseMotion.new()
	m.relative = relative
	m.screen_relative = relative
	Input.parse_input_event(m)


# --- waiting -----------------------------------------------------------------

## Waits process frames until `cond` is true. Returns false if it never was.
func wait_until(cond: Callable, max_frames: int) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		await test.wait_process_frames(1)
	return bool(cond.call())


## Steers her to `point` (flat distance under `radius`) with the stick, at most
## `max_frames` physics frames. With `sprint` she holds Shift on the way.
## Returns whether she got there; the stick is centred either way.
func walk_to(point: Vector3, radius: float = 0.6, max_frames: int = 600, sprint: bool = false,
		amount: float = 1.0) -> bool:
	if sprint:
		hold(&"sprint")
	var ok := false
	for i in max_frames:
		if flat_distance(feyre.global_position, point) < radius:
			ok = true
			break
		stick_toward(point, amount)
		await test.wait_physics_frames(1)
	stick(Vector2.ZERO)
	if sprint:
		release(&"sprint")
	return ok


## Waits until she has stopped (flat speed under 0.1 m/s), at most `max_frames`.
func wait_still(max_frames: int = 90) -> bool:
	return await wait_until(func() -> bool: return flat_speed() < 0.1 and feyre.is_on_floor(), max_frames)


## Engine errors this test raised that contain `text`: marks them handled (so
## GUT doesn't fail the test on them) and returns how many. For a known game
## bug a test reports as pending instead of failing on.
func excuse_errors(text: String) -> int:
	var n := 0
	for e in test.get_errors():
		if not e.handled and e.contains_text(text):
			e.handled = true
			n += 1
	return n


# --- observing ---------------------------------------------------------------

func flat_speed() -> float:
	return Vector2(feyre.velocity.x, feyre.velocity.z).length()


static func flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## The game's node of a type (DialogueDirector, MountDirector, SettingsPanel...).
func child_of(type: Variant) -> Node:
	for child in game.get_children():
		if is_instance_of(child, type):
			return child
	return null


## The nearest node of `group` to her, or null.
func nearest_in_group(group: StringName, max_distance: float = INF) -> Node3D:
	var best: Node3D = null
	var best_d := max_distance
	for n in test.get_tree().get_nodes_in_group(group):
		if n is Node3D and (n as Node3D).is_inside_tree():
			var d := (n as Node3D).global_position.distance_to(feyre.global_position)
			if d < best_d:
				best = n
				best_d = d
	return best


## Ground height under (x, z), or NAN where there is none (layer 1, the world).
func ground_y(x: float, z: float, from_y: float = 400.0) -> float:
	var space := feyre.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, from_y, z), Vector3(x, -200.0, z), 1)
	q.exclude = [feyre.get_rid()]
	var hit := space.intersect_ray(q)
	return NAN if hit.is_empty() else (hit.position as Vector3).y
