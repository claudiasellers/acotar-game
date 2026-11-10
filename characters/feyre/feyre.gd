## Feyre: third-person movement, sprint with stamina, jumping, ledge
## mantling, a mouse/stick camera that R recentres behind her, plus her
## gameplay components (systems/): the bow, interaction,
## body state, element state, notice moments and wardrobe.
##
## The body is a capsule until her model exists at MODEL_SCENE; then that
## scene is instanced under `model` instead, with no other code changes.
class_name Feyre
extends CharacterBody3D

signal arrow_fired(arrow: Arrow)
signal quiver_changed(count: int)
## For creature hearing: where the bow was released and how loud (0..1).
signal bow_released(at: Vector3, loudness: float)

const MODEL_SCENE := "res://characters/feyre/model/feyre_model.tscn"

const DEFAULT_PITCH := -0.2094  # -12 degrees
const PLAYER_LAYER := 1 << 1
const WORLD_MASK := 1 << 0
## Indoors (a roof or ceiling above her head) the camera stays in the room: it may
## rise at most this far above its pivot (her head height, 1.5 m), which keeps it
## under rafters and low beams that have no collision of their own, and never
## within INDOOR_CEILING_GAP of the ceiling it does hit. The arm is shorter too.
const INDOOR_RISE := 0.7
const INDOOR_CEILING_GAP := 0.35
const INDOOR_ARM := 2.4
## Indoors the arm also stops before a doorway behind her: walking out along the
## arm, the free width side to side (up to 2 * ROOM_REACH) is sampled every
## ROOM_STEP, and where it narrows to a doorway (under ROOM_NARROW of the width where
## she stands, and under ROOM_DOOR_MAX) the camera stops ROOM_MARGIN short of it. So
## it stays in her room in front of the jambs, while a corridor she walks along (as
## narrow behind her as where she is) does not shrink the arm. Pull-in is quick and
## letting out is slow, so it never pops.
const ROOM_REACH := 1.5
const ROOM_STEP := 0.25
const ROOM_NARROW := 0.75
const ROOM_DOOR_MAX := 2.2
const ROOM_MARGIN := 0.2
const ROOM_MIN_ARM := 0.9
const CLOSE_FROM := 1.8
const CLOSE_SHOULDER := 0.35
const ROOM_PULL_IN := 14.0
const ROOM_LET_OUT := 2.5
## How far up (m) a roof still counts as "indoors".
const INDOOR_PROBE := 9.0
## The body swept along a ledge climb: a touch slimmer than her capsule, feet off
## the floor, so what she merely stands on or leans against doesn't count.
const CLIMB_RADIUS := 0.27
const CLIMB_HEIGHT := 1.6
const CLIMB_CENTRE := 0.9

@export var bow: BowData = preload("res://data/bows/hunting_bow.tres")
@export var walk_speed: float = 4.16
@export var run_speed: float = 10.686
@export var sprint_speed: float = 17.03
## Ground acceleration (m/s²) from run speed up to sprint speed. Below run speed
## she gets the full `acceleration`, so Shift + forward breaks straight into a
## run and reaches the sprint in about a quarter of a second.
@export var sprint_acceleration: float = 31.2
@export var aim_speed: float = 2.86
## Ground acceleration toward the target speed, per m/s of that speed (1/s):
## 14 reaches a run from standing in about 0.07 s.
@export var acceleration: float = 14.0
## Ground stop with no keys held (m/s²): about 0.2 s and 1.5 m from a sprint.
@export var braking: float = 78.0
## How fast her running direction swings to a new heading, keeping her speed
## (1/s; Unreal's CharacterMovement GroundFriction, whose template uses 8).
## A turn no longer dips her speed or slides her sideways.
@export var turn_friction: float = 13.0
## Slowest her running direction turns (rad/s): small corrections still land fast.
const TURN_MIN_RATE := 6.5
## A change of direction wider than this (degrees) is a reversal: she plants and
## pushes off the other way instead of running round in a loop.
const PIVOT_ANGLE := 135.0
@export var air_control: float = 0.5
## How far an air jump (2nd, 3rd) swings her drift toward the stick (0..1).
@export var air_jump_redirect: float = 0.65
@export var turn_speed: float = 15.6
@export var max_stamina: float = 100.0
@export var stamina_regen: float = 16.0
@export var stamina_regen_delay: float = 0.8
## Wood arrows in the quiver at the start if it is empty.
@export var starting_arrows: int = 12
@export var max_quiver: int = 30
@export var mouse_sensitivity: float = 0.0025
@export var stick_sensitivity: float = 2.6
## Recentre (R / right stick click) eases the camera toward behind her over
## this many seconds (ease in-out), always the short way round.
@export var recenter_time: float = 0.3
## Most a single R press turns the camera (degrees): a tap is a gentle shift,
## not a swing round to her back while she runs sideways. Tap again for more.
@export var recenter_max_turn: float = 50.0
## With "camera follows while running" on, the camera swings behind her after
## this long without look input.
@export var follow_delay: float = 0.6
@export var follow_speed: float = 2.4

var stamina: float = 100.0
var is_aiming: bool = false
## True on frames where the player moved the camera (cancels notice drifts).
var look_input_this_frame: bool = false

var quiver: int:
	get:
		return Gameplay.inventory.arrow_count()
var draw_amount: float:
	get:
		return bow_controller.draw_amount if bow_controller else 0.0
var is_drawing: bool:
	get:
		return bow_controller.is_drawing if bow_controller else false

var bow_controller: BowController
var interactor: Interactor
var body_state: BodyState
var element_state: ElementState
var notice_director: NoticeDirector
var wardrobe_applier: WardrobeApplier
var jump_motor := JumpMotor.new()
## Running total of camera yaw turns the player didn't make (follow-behind,
## story glances, recentre, nudges); SteerFrame takes them out of steering.
var camera_auto_yaw: float = 0.0
## Running total of the player's own camera turns (mouse, right stick) made
## while "Turning the camera steers her while moving" was off.
var camera_look_yaw: float = 0.0
## The move keys steer in this frame, not the live camera (see SteerFrame).
var steer_frame := SteerFrame.new()
var movement_feel: MovementFeel
var is_mantling: bool = false
var _mantle_tween: Tween
var _camera_fade: CameraFade

var model: Node3D
var camera: Camera3D

var _camera_rig: Node3D
## Extra pivot height and arm length (m) for the third-person camera, set by
## whatever carries her (the white mare, MountDirector) and eased back to 0 after.
var camera_lift: float = 0.0
var camera_arm_extra: float = 0.0
var _camera_pitch: Node3D
var _spring_arm: SpringArm3D
var _stamina_cooldown: float = 0.0
var _exhausted: bool = false
var _recentering: bool = false
## 0 outdoors .. 1 indoors, eased so doorways don't pop the camera.
var _indoor: float = 0.0
## Highest the camera may sit above its pivot right now (m).
var _indoor_rise: float = INDOOR_RISE
## Arm length the room allows, eased; see LENS_CLEAR.
var _room_arm: float = 3.6
## Indoors the camera does not collide with furniture (a small box-shaped body that
## carries its own mesh, such as a canopy bed): CameraFade fades it instead, so bed
## drapes never shove the camera in. Walls and anything taller than
## CameraFade.MAX_SIZE still stop it.
var _cam_skip: Array[RID] = []
var _cam_prop_cache: Dictionary = {}
var _recenter_t: float = 0.0
var _recenter_from := Vector2.ZERO
var _recenter_to := Vector2.ZERO
var _since_look: float = 0.0
var _running: bool = false
## Recent spots where she stood on open ground, newest last (wriggle free).
var _safe_spots: Array[Vector3] = []
var _safe_timer: float = 0.0


func _ready() -> void:
	add_to_group(&"player")
	collision_layer = PLAYER_LAYER
	# People and walking creatures block her too (T092); her probes stay world-only.
	collision_mask = WORLD_MASK | ActorBody.LAYER
	floor_snap_length = 0.4
	floor_max_angle = deg_to_rad(50.0)
	stamina = max_stamina
	_build_body()
	_build_camera()
	_build_components()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"pause"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED \
			and StoryControl.can_look():
		var s := mouse_sensitivity * GameSettings.mouse_sensitivity
		_look(event.relative.x * s, event.relative.y * s)
	if event.is_action_pressed(&"camera_recenter") and StoryControl.can_look():
		recenter_camera(deg_to_rad(recenter_max_turn))
	if event.is_action_pressed(&"interact") and StoryControl.can_interact():
		interactor.interact()


func _process(delta: float) -> void:
	_camera_rig.global_position = global_position + Vector3.UP * (1.5 + camera_lift)
	var look := Input.get_vector(&"look_left", &"look_right", &"look_up", &"look_down")
	if look != Vector2.ZERO and StoryControl.can_look():
		var s := stick_sensitivity * GameSettings.stick_sensitivity * delta
		_look(look.x * s, look.y * s)
	_since_look = 0.0 if look_input_this_frame else _since_look + delta
	_update_recenter(delta)
	_follow_behind(delta)
	_drift_toward_focus(delta)
	var shake := StoryControl.shake * (0.0 if GameSettings.reduced_effects else 1.0)
	camera.h_offset = randf_range(-0.04, 0.04) * shake
	camera.v_offset = randf_range(-0.03, 0.03) * shake
	_update_indoor(delta)
	var target_length := 1.7 if (is_aiming or is_drawing) else lerpf(3.6 + camera_arm_extra, INDOOR_ARM, _indoor)
	_update_room_arm(delta, target_length)
	target_length = minf(target_length, _room_arm)
	_spring_arm.spring_length = lerpf(_spring_arm.spring_length, target_length, 10.0 * delta)
	_clamp_indoor_pitch()
	var shoulder := 0.55 if (is_aiming or is_drawing) else close_shoulder(_spring_arm.spring_length)
	_spring_arm.position.x = lerpf(_spring_arm.position.x, shoulder, 10.0 * delta)
	_update_breath(delta)
	look_input_this_frame = false


func _physics_process(delta: float) -> void:
	if is_mantling:
		return
	is_aiming = Input.is_action_pressed(&"aim")

	var input := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	if not StoryControl.can_move():
		input = Vector2.ZERO
	var yaw := _camera_rig.rotation.y
	var steer := steer_frame.yaw(input, yaw, steer_exclusion(), is_aiming or is_drawing)
	var direction := Vector3(input.x, 0.0, input.y).rotated(Vector3.UP, steer)
	# Holding sprint runs at sprint_speed until released: stamina no longer limits it.
	var sprinting := Input.is_action_pressed(&"sprint") and direction != Vector3.ZERO \
			and not is_drawing and not is_aiming
	_running = sprinting
	_update_stamina(delta)

	var speed := run_speed
	if is_aiming or is_drawing:
		speed = aim_speed
	elif sprinting:
		speed = sprint_speed
	elif input.length() < 0.5:
		speed = walk_speed
	speed *= Gameplay.inventory.speed_multiplier() * (1.0 + Gameplay.wardrobe.swift() * 0.5)
	if body_state:
		body_state.exertion = 1.0 if sprinting else (0.6 if is_drawing else 0.0)

	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var can_jump := StoryControl.can_move()
	var pressed := Input.is_action_just_pressed(&"jump") and can_jump
	if pressed and is_on_floor() and _try_mantle():
		jump_motor.consume_buffer()
		return
	jump_motor.forgiving = _gentle_mode()
	var jumps_before := jump_motor.jumps_used
	velocity.y = jump_motor.step(delta, is_on_floor(), velocity.y, pressed,
			Input.is_action_pressed(&"jump"), can_jump)
	if jump_motor.jumps_used > maxi(jumps_before, 1) and direction != Vector3.ZERO:
		horizontal = horizontal.lerp(direction * maxf(horizontal.length(), speed), air_jump_redirect)

	horizontal = _ground_or_air(horizontal, direction, speed, sprinting, delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z

	# Gentle Mode catches ledges whichever way she is pushing.
	var reach_input := input.length() > 0.3 if GameSettings.gentle_mode else input.y < -0.3
	if not is_on_floor() and velocity.y < 2.0 and reach_input:
		_try_mantle()

	_turn_model(direction, yaw, delta)
	move_and_slide()
	_remember_safe_spot(delta)


## Eases the camera toward behind her, turning at most `max_turn` radians
## (R / right stick click caps it; teleports recentre fully).
func recenter_camera(max_turn: float = PI) -> void:
	var yaw := _camera_rig.rotation.y
	var turn := clampf(angle_difference(yaw, model.rotation.y), -max_turn, max_turn)
	_recenter_from = Vector2(yaw, _camera_pitch.rotation.x)
	_recenter_to = Vector2(yaw + turn, DEFAULT_PITCH)
	_recenter_t = 0.0
	_recentering = true


## The one way to move her instantly (Return Home, Wriggle Free, a save load, tools):
## stops a ledge climb in progress (its tween would otherwise carry her back onto
## the ledge), zeroes her velocity, and brings the camera and its fade with her.
func teleport(pos: Vector3) -> void:
	if _mantle_tween and _mantle_tween.is_valid():
		_mantle_tween.kill()
	_mantle_tween = null
	is_mantling = false
	velocity = Vector3.ZERO
	steer_frame.release()
	global_position = pos
	_camera_rig.global_position = pos + Vector3.UP * (1.5 + camera_lift)
	_room_arm = 3.6
	if _spring_arm:
		for rid in _cam_skip:
			_spring_arm.remove_excluded_object(rid)
	_cam_skip.clear()
	if _camera_fade:
		_camera_fade.restore_all()


## Pause menu "Wriggle free": hop to the nearest open ground. False if no spot was found.
func wriggle_free() -> bool:
	var spot: Variant = WriggleFree.find_spot(self, _safe_spots)
	if spot == null:
		return false
	teleport(spot)
	recenter_camera()
	Juice.burst(self, &"unlock")
	return true


func camera_yaw() -> float:
	return _camera_rig.rotation.y


func camera_pitch() -> float:
	return _camera_pitch.rotation.x


## Root design doc §4.3: arrows are scarce, so stuck arrows can be collected.
func pick_up_nearest_arrow() -> bool:
	return interactor.pick_up_arrow()


## Adds (or with a negative count removes) wood arrows.
func add_arrows(count: int) -> void:
	if count > 0:
		Gameplay.inventory.add(&"arrow_wood", count)
	elif count < 0:
		Gameplay.inventory.remove(&"arrow_wood", -count)
	quiver_changed.emit(quiver)


func drain_stamina(amount: float) -> void:
	stamina = maxf(stamina - amount, 0.0)
	_stamina_cooldown = stamina_regen_delay
	if stamina <= 0.0:
		_exhausted = true


## Small camera turn from gameplay (notice moments), in radians.
func nudge_camera(yaw_delta: float, pitch_delta: float) -> void:
	camera_auto_yaw += yaw_delta
	_rotate_camera(yaw_delta, pitch_delta)


## The camera turns kept out of her steering while a direction is held
## (SteerFrame): turns the player didn't make, always; the player's own too
## unless "Turning the camera steers her while moving" is on.
func steer_exclusion() -> float:
	return camera_auto_yaw + camera_look_yaw


## A camera turn the player didn't make: it doesn't steer her (SteerFrame).
func _auto_turn(new_yaw: float) -> void:
	camera_auto_yaw += angle_difference(_camera_rig.rotation.y, new_yaw)
	_camera_rig.rotation.y = new_yaw


func aim_point(max_distance: float = 250.0) -> Vector3:
	var from := camera.global_position
	var to := from - camera.global_basis.z * max_distance
	var query := PhysicsRayQueryParameters3D.create(from, to, WORLD_MASK | (1 << 3), [get_rid()])
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result:
		return result.position
	return to


## Gentle Mode (pause menu setting) makes jumps more forgiving.
func _gentle_mode() -> bool:
	var settings := get_node_or_null(^"/root/GameSettings")
	return settings != null and bool(settings.get(&"gentle_mode"))


## Ran dry and has not yet caught her breath (35% back): BowController holds
## slow time off until then.
func is_winded() -> bool:
	return _exhausted


## Stamina now only pays for slow-time aiming (drain_stamina); sprinting is free.
func _update_stamina(delta: float) -> void:
	if _stamina_cooldown > 0.0:
		_stamina_cooldown -= delta
	else:
		var regen := stamina_regen * (body_state.stamina_regen_multiplier() if body_state else 1.0)
		stamina = minf(stamina + regen * delta, max_stamina)
	# After running dry aiming, slow time waits until she has caught her breath.
	if _exhausted and stamina >= max_stamina * 0.35:
		_exhausted = false


## Her horizontal velocity for this frame. With keys held her running
## direction turns toward them at `turn_friction` (exponential, at least
## TURN_MIN_RATE) while keeping her speed, as Unreal's CharacterMovement does,
## so a turn never dips her speed or slides her sideways; a near reversal
## (over PIVOT_ANGLE) plants and pushes off the other way instead. Then the
## speed eases to the target. With no keys she brakes to a stop. In the air
## the same at `air_control` strength: a jump carries her, but she steers.
func _ground_or_air(horizontal: Vector3, direction: Vector3, speed: float, sprinting: bool, delta: float) -> Vector3:
	var grounded := is_on_floor()
	var control := 1.0 if grounded else air_control
	if direction == Vector3.ZERO:
		var brake := braking if grounded else acceleration * run_speed * air_control
		return horizontal.move_toward(Vector3.ZERO, brake * delta)
	var size := horizontal.length()
	var want := atan2(-direction.x, -direction.z)
	var target_speed := speed * minf(direction.length(), 1.0)
	var rate := acceleration * speed * control
	if sprinting and grounded and size >= run_speed * 0.98:
		rate = sprint_acceleration
	var heading := atan2(-horizontal.x, -horizontal.z) if size > 0.5 else want
	var diff := angle_difference(heading, want)
	if absf(diff) >= deg_to_rad(PIVOT_ANGLE):
		# A reversal: plant and push off the other way.
		return horizontal.move_toward(Vector3.FORWARD.rotated(Vector3.UP, want) * target_speed, acceleration * speed * control * delta)
	var turn := maxf(absf(diff) * minf(delta * turn_friction * control, 1.0), TURN_MIN_RATE * control * delta)
	heading += clampf(diff, -turn, turn)
	return Vector3.FORWARD.rotated(Vector3.UP, heading) * move_toward(size, target_speed, rate * delta)


## Faces where she is going (Unreal's "orient rotation to movement"): her
## running direction once she is moving, so her body never runs at an angle
## to her path, else the keys; the camera while aiming or drawing.
func _turn_model(direction: Vector3, camera_yaw: float, delta: float) -> void:
	var target_yaw := model.rotation.y
	var moving := Vector2(velocity.x, velocity.z)
	if is_aiming or is_drawing:
		target_yaw = camera_yaw
	elif moving.length() > 1.0 and (direction != Vector3.ZERO or not is_on_floor()):
		target_yaw = atan2(-moving.x, -moving.y)
	elif direction.length_squared() > 0.01:
		target_yaw = atan2(-direction.x, -direction.z)
	var rate := turn_speed * (2.0 if moving.length() > 1.0 and not (is_aiming or is_drawing) else 1.0)
	model.rotation.y = lerp_angle(model.rotation.y, target_yaw, minf(rate * delta, 1.0))


## Climbs onto a ledge in front of Feyre between knee and reach height.
func _try_mantle() -> bool:
	var space := get_world_3d().direct_space_state
	var forward := -model.global_basis.z
	var chest := global_position + Vector3.UP * 1.1
	var wall := space.intersect_ray(PhysicsRayQueryParameters3D.create(
			chest, chest + forward * 0.8, WORLD_MASK, [get_rid()]))
	if not wall:
		var knee := global_position + Vector3.UP * 0.5
		wall = space.intersect_ray(PhysicsRayQueryParameters3D.create(
				knee, knee + forward * 0.8, WORLD_MASK, [get_rid()]))
	if not wall:
		return false
	var probe: Vector3 = wall.position + forward * 0.35 + Vector3.UP * 1.6
	var top := space.intersect_ray(PhysicsRayQueryParameters3D.create(
			probe, probe + Vector3.DOWN * 2.4, WORLD_MASK, [get_rid()]))
	if not top or top.normal.dot(Vector3.UP) < 0.7:
		return false
	if RegionGate.owns(wall.collider) or RegionGate.owns(top.collider):
		return false
	var rise: float = top.position.y - global_position.y
	if rise < 0.6 or rise > (2.8 if GameSettings.gentle_mode else 2.3):
		return false
	var landing: Vector3 = top.position + forward * 0.25 + Vector3.UP * 0.05
	if not _climb_is_clear(landing):
		return false
	is_mantling = true
	velocity = Vector3.ZERO
	_mantle_tween = create_tween()
	_mantle_tween.tween_property(self, ^"global_position:y", top.position.y + 0.05, 0.28)
	_mantle_tween.tween_property(self, ^"global_position", landing, 0.16)
	_mantle_tween.finished.connect(func() -> void: is_mantling = false)
	return true


## The climb tweens her straight up and then over, past physics, and the ledge
## ray can start inside a wall and find a floor behind it. So her body is swept
## along both legs first: a climb only happens if she fits the whole way.
func _climb_is_clear(landing: Vector3) -> bool:
	var body := CapsuleShape3D.new()
	body.radius = CLIMB_RADIUS
	body.height = CLIMB_HEIGHT
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = body
	query.collision_mask = WORLD_MASK
	query.exclude = [get_rid()]
	var centre := Vector3.UP * CLIMB_CENTRE
	var over := Vector3(global_position.x, landing.y, global_position.z)
	var space := get_world_3d().direct_space_state
	for leg: Array[Vector3] in [[global_position, over], [over, landing]] as Array[Array]:
		query.transform = Transform3D(Basis.IDENTITY, leg[0] + centre)
		query.motion = leg[1] - leg[0]
		if space.cast_motion(query)[0] < 1.0:
			return false
	return true


## During anchored moments the camera eases toward what the scene is about.
func _drift_toward_focus(delta: float) -> void:
	var focus := StoryControl.focus
	if focus == null or not is_instance_valid(focus):
		return
	var to := focus.global_position - _camera_rig.global_position
	if Vector2(to.x, to.z).length() < 0.5:
		return
	var yaw := atan2(-to.x, -to.z)
	_auto_turn(lerp_angle(_camera_rig.rotation.y, yaw, 1.6 * delta))


## Player look input (already scaled); applies the invert settings.
func _look(x: float, y: float) -> void:
	var yaw := x * (1.0 if GameSettings.invert_x else -1.0)
	_rotate_camera(yaw, y * (1.0 if GameSettings.invert_y else -1.0))
	if not GameSettings.mouse_steers:
		camera_look_yaw += yaw
	look_input_this_frame = true
	_recentering = false


func _update_recenter(delta: float) -> void:
	if not _recentering:
		return
	_recenter_t = minf(_recenter_t + delta / maxf(recenter_time, 0.01), 1.0)
	var k := smoothstep(0.0, 1.0, _recenter_t)
	_auto_turn(wrapf(lerpf(_recenter_from.x, _recenter_to.x, k), -PI, PI))
	_camera_pitch.rotation.x = lerpf(_recenter_from.y, _recenter_to.y, k)
	if _recenter_t >= 1.0:
		_recentering = false


## "Camera follows behind while running": a lazy swing back to the frame the keys
## are steering in, once the player stops steering the camera. Aimed at that frame
## and not at her facing, because a fresh key press takes the camera as its frame:
## following her facing, each press turned her and the camera further, a spiral
## with no look input. Off under a roof, where the camera is the player's alone.
func _follow_behind(delta: float) -> void:
	if not GameSettings.camera_follow or not _running or _since_look < follow_delay \
			or StoryControl.focus != null or not steer_frame.is_held():
		return
	_auto_turn(lerp_angle(_camera_rig.rotation.y, steer_frame.held_yaw(),
			follow_speed * (1.0 - _indoor) * delta))


func _remember_safe_spot(delta: float) -> void:
	_safe_timer -= delta
	if _safe_timer > 0.0 or not is_on_floor() or get_floor_normal().y < 0.8:
		return
	_safe_timer = 1.0
	if _safe_spots.is_empty() or _safe_spots.back().distance_to(global_position) > 1.5:
		_safe_spots.append(global_position)
		if _safe_spots.size() > 12:
			_safe_spots.pop_front()


## True under a roof or in a manor room: BowVisual stows the slung bow.
func is_indoors() -> bool:
	return _indoor > 0.5


## Is there a roof over her? Reads the ceiling height straight above the camera
## pivot; manor rooms count whether or not a collider roofs them (ManorIndoors).
func _update_indoor(delta: float) -> void:
	var from := _camera_rig.global_position
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(
			from, from + Vector3.UP * INDOOR_PROBE, WORLD_MASK, [get_rid()]))
	var roofed := not hit.is_empty()
	var ceiling: float = (hit.position as Vector3).y if roofed else ManorIndoors.ceiling_over(get_tree(), from)
	roofed = not is_nan(ceiling)
	if roofed:
		_indoor_rise = clampf(ceiling - from.y - INDOOR_CEILING_GAP, 0.0, INDOOR_RISE)
	_indoor = move_toward(_indoor, 1.0 if roofed else 0.0, delta / 0.3)


## Over-the-shoulder offset (m) when a small room holds the arm short: none at
## CLOSE_FROM and longer, CLOSE_SHOULDER at ROOM_MIN_ARM, so she sits off-centre
## instead of filling the middle of the frame.
func close_shoulder(arm: float) -> float:
	return CLOSE_SHOULDER * clampf((CLOSE_FROM - arm) / (CLOSE_FROM - ROOM_MIN_ARM), 0.0, 1.0)


## Indoors: the longest arm (up to `want`) whose view-edge whiskers clear the walls.
## Outdoors (_indoor 0) it allows the full arm, as before.
func _update_room_arm(delta: float, want: float) -> void:
	if _indoor < 0.5 and not _cam_skip.is_empty():
		for rid in _cam_skip:
			_spring_arm.remove_excluded_object(rid)
		_cam_skip.clear()
	var allowed := want
	if _indoor > 0.0:
		_cam_ray(_spring_arm.global_position, _spring_arm.global_position + _spring_arm.global_basis.z * (want + 0.3))
		allowed = lerpf(want, room_clearance(want), _indoor)
	var rate := ROOM_PULL_IN if allowed < _room_arm else ROOM_LET_OUT
	_room_arm = lerpf(_room_arm, allowed, minf(1.0, rate * delta))


## How far back (m, up to `want`) the camera can sit along the arm's current
## direction and still be in front of any doorway behind her (see ROOM_REACH).
func room_clearance(want: float) -> float:
	var pivot := _spring_arm.global_position
	var basis := _spring_arm.global_basis
	var here := _free_width(pivot, basis.x)
	var dist := ROOM_STEP
	# A little past the camera too, so a doorway just behind the lens counts.
	while dist <= want + ROOM_STEP:
		var w := _free_width(pivot + basis.z * dist, basis.x)
		if w < here * ROOM_NARROW and w < ROOM_DOOR_MAX:
			return clampf(dist - ROOM_STEP - ROOM_MARGIN, ROOM_MIN_ARM, want)
		dist += ROOM_STEP
	return want


## Free width (m) at `at` along +/- `side`, each way up to ROOM_REACH.
func _free_width(at: Vector3, side: Vector3) -> float:
	var space := get_world_3d().direct_space_state
	var total := 0.0
	for dir: Vector3 in [side, -side]:
		var hit := _cam_ray(at, at + dir * ROOM_REACH)
		total += ROOM_REACH if hit.is_empty() else at.distance_to(hit.position)
	return total


## A camera ray against the world that, indoors, passes through furniture and adds
## each piece it meets to the spring arm's exclusions.
func _cam_ray(from: Vector3, to: Vector3) -> Dictionary:
	var space := get_world_3d().direct_space_state
	for i in 4:
		var skip: Array[RID] = [get_rid()]
		skip.append_array(_cam_skip)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, WORLD_MASK, skip))
		if hit.is_empty() or _indoor < 0.5 or not _is_furniture(hit.collider):
			return hit
		_cam_skip.append(hit.rid)
		_spring_arm.add_excluded_object(hit.rid)
	return {}


func _is_furniture(o: Object) -> bool:
	var body := o as StaticBody3D
	if body == null:
		return false
	var id := body.get_instance_id()
	if not _cam_prop_cache.has(id):
		_cam_prop_cache[id] = _furniture_shape(body)
	return _cam_prop_cache[id]


static func _furniture_shape(body: StaticBody3D) -> bool:
	var shapes := 0
	var scale := body.global_basis.get_scale()
	for owner_id in body.get_shape_owners():
		for i in body.shape_owner_get_shape_count(owner_id):
			var box := body.shape_owner_get_shape(owner_id, i) as BoxShape3D
			if box == null:
				return false
			var size := box.size * scale
			if maxf(size.x, maxf(size.y, size.z)) > CameraFade.MAX_SIZE:
				return false
			shapes += 1
	return shapes > 0 and not body.find_children("*", "GeometryInstance3D", true, false).is_empty()


## Indoors, the downward look is limited so the camera (pivot + arm * sin(pitch))
## never rises past `_indoor_rise`: under the beams, never up in the rafters.
func _clamp_indoor_pitch() -> void:
	if _indoor <= 0.0:
		return
	var arm := maxf(_spring_arm.spring_length, 0.1)
	var limit := -asin(clampf(_indoor_rise / arm, 0.0, 1.0))
	# Eased with _indoor: outdoors the usual -70 degree limit applies.
	limit = lerpf(deg_to_rad(-70.0), limit, _indoor)
	if _camera_pitch.rotation.x < limit:
		_camera_pitch.rotation.x = limit


## Camera height above its pivot (m), for tests and tools.
func camera_rise() -> float:
	return camera.global_position.y - _camera_rig.global_position.y


func _rotate_camera(yaw_delta: float, pitch_delta: float) -> void:
	_camera_rig.rotation.y += yaw_delta
	_camera_pitch.rotation.x = clampf(_camera_pitch.rotation.x + pitch_delta, deg_to_rad(-70.0), deg_to_rad(55.0))


func _build_components() -> void:
	if Gameplay.inventory.arrow_count() == 0 and starting_arrows > 0:
		Gameplay.inventory.add(&"arrow_wood", starting_arrows)
	Gameplay.register_save_providers()
	element_state = ElementState.new()
	element_state.name = "ElementState"
	element_state.insulation = Gameplay.wardrobe.warmth()
	add_child(element_state)
	Gameplay.wardrobe.changed.connect(func() -> void: element_state.insulation = Gameplay.wardrobe.warmth())
	body_state = BodyState.new()
	body_state.name = "BodyState"
	body_state.element_state = element_state
	add_child(body_state)
	bow_controller = BowController.new()
	bow_controller.name = "BowController"
	add_child(bow_controller)
	interactor = Interactor.new()
	interactor.name = "Interactor"
	add_child(interactor)
	notice_director = NoticeDirector.new()
	notice_director.name = "NoticeDirector"
	add_child(notice_director)
	wardrobe_applier = WardrobeApplier.new()
	wardrobe_applier.name = "WardrobeApplier"
	add_child(wardrobe_applier)
	movement_feel = MovementFeel.new()
	movement_feel.name = "MovementFeel"
	add_child(movement_feel)
	# Props with no collision (tables, beams) fade when a lens comes right up to them.
	_camera_fade = CameraFade.new()
	_camera_fade.name = "CameraFade"
	add_child(_camera_fade)
	_build_breath()


var _breath: GPUParticles3D
var _breath_phase: float = 0.0


## Visible breath in the cold (root doc §4.8): faster and bigger when she is
## cold, hungry or working hard.
func _build_breath() -> void:
	_breath = GPUParticles3D.new()
	_breath.name = "Breath"
	_breath.amount = 10
	_breath.lifetime = 1.4
	_breath.emitting = false
	_breath.position = Vector3(0, 1.55, -0.16)
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 0.2, -1)
	mat.spread = 18.0
	mat.initial_velocity_min = 0.25
	mat.initial_velocity_max = 0.45
	mat.gravity = Vector3(0, 0.08, 0)
	mat.scale_min = 0.6
	mat.scale_max = 1.4
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 0.35))
	grad.set_color(1, Color(1, 1, 1, 0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = grad
	mat.color_ramp = ramp
	_breath.process_material = mat
	var puff := QuadMesh.new()
	puff.size = Vector2(0.12, 0.12)
	var pm := MaterialLibrary.surface()
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pm.vertex_color_use_as_albedo = true
	pm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	puff.material = pm
	_breath.draw_pass_1 = puff
	model.add_child(_breath)


func _update_breath(delta: float) -> void:
	if _breath == null or body_state == null:
		return
	var weather := Weather.find(get_tree())
	var visible_breath := weather != null and weather.is_breath_visible()
	_breath_phase = fmod(_breath_phase + delta * body_state.breath_rate(), 1.0)
	# Exhale for the first 40% of each breath.
	_breath.emitting = visible_breath and _breath_phase < 0.4
	_breath.amount_ratio = body_state.breath_intensity()


func _build_body() -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.7
	shape.shape = capsule
	shape.position.y = 0.85
	add_child(shape)

	model = Node3D.new()
	model.name = "Model"
	add_child(model)
	if ResourceLoader.exists(MODEL_SCENE):
		model.add_child((load(MODEL_SCENE) as PackedScene).instantiate())
		return

	var cloak := MaterialLibrary.surface()
	cloak.albedo_color = Color(0.36, 0.30, 0.24)
	var skin := MaterialLibrary.surface()
	skin.albedo_color = Color(0.92, 0.78, 0.66)

	var body_mesh := MeshInstance3D.new()
	var body_capsule := CapsuleMesh.new()
	body_capsule.radius = 0.26
	body_capsule.height = 1.45
	body_mesh.mesh = body_capsule
	body_mesh.position.y = 0.73
	body_mesh.material_override = cloak
	model.add_child(body_mesh)

	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.13
	sphere.height = 0.26
	head.mesh = sphere
	head.position.y = 1.58
	head.material_override = skin
	model.add_child(head)

	# A nose so it is obvious which way she faces.
	var nose := MeshInstance3D.new()
	var nose_box := BoxMesh.new()
	nose_box.size = Vector3(0.04, 0.05, 0.08)
	nose.mesh = nose_box
	nose.position = Vector3(0.0, 1.58, -0.14)
	nose.material_override = skin
	model.add_child(nose)


func _build_camera() -> void:
	_camera_rig = Node3D.new()
	_camera_rig.name = "CameraRig"
	_camera_rig.top_level = true
	add_child(_camera_rig)
	_camera_pitch = Node3D.new()
	_camera_pitch.rotation.x = DEFAULT_PITCH
	_camera_rig.add_child(_camera_pitch)
	_spring_arm = SpringArm3D.new()
	_spring_arm.spring_length = 3.6
	_spring_arm.collision_mask = WORLD_MASK
	_spring_arm.margin = 0.2
	_spring_arm.add_excluded_object(get_rid())
	_camera_pitch.add_child(_spring_arm)
	camera = Camera3D.new()
	camera.fov = 70.0
	camera.far = 2000.0
	camera.current = true
	_spring_arm.add_child(camera)
	_camera_rig.global_position = global_position + Vector3.UP * (1.5 + camera_lift)
