## Feyre: third-person movement, sprint with stamina, jumping, a crouch to
## sneak (CrouchMotor), ledge mantling, a mouse/stick camera that R recentres behind her, plus her
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

const PLAYER_LAYER := 1 << 1
const WORLD_MASK := 1 << 0
## The camera's constants (DEFAULT_PITCH, INDOOR_*, ROOM_*, LENS_RADIUS, ...) live
## in FeyreCamera; the ledge climb's (CLIMB_*) in MantleMotor (T100).
## Alias for T098's room-camera test, which lands in parallel; new code uses FeyreCamera.
const ROOM_PULL_IN := FeyreCamera.ROOM_PULL_IN

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
## The bow is up (BowController: aim held, not spent by a shot).
var is_aiming: bool:
	get:
		return bow_controller.is_aiming if bow_controller else false
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
## The hunter's crouch: Left Ctrl / gamepad B, slower and quieter (CrouchMotor).
var crouch := CrouchMotor.new()
## Running total of camera yaw turns the player didn't make (follow-behind,
## story glances, recentre, nudges); SteerFrame takes them out of steering.
var camera_auto_yaw: float = 0.0
## Running total of the player's own camera turns (mouse, right stick) made
## while "Turning the camera steers her while moving" was off.
var camera_look_yaw: float = 0.0
## The move keys steer in this frame, not the live camera (see SteerFrame).
var steer_frame := SteerFrame.new()
var movement_feel: MovementFeel
## Ledge climbing (MantleMotor); true while a climb tweens her up.
var mantle: MantleMotor
var is_mantling: bool:
	get:
		return mantle.climbing if mantle else false
## The third-person camera: rig, look, recentre, indoor rules (FeyreCamera).
var camera_control: FeyreCamera
var _camera_fade: CameraFade

var model: Node3D
var camera: Camera3D

var _camera_rig: Node3D  # camera_control.rig, kept for her own frame code
## Extra pivot height and arm length (m) for the third-person camera, set by
## whatever carries her (the white mare, MountDirector) and eased back to 0 after.
var camera_lift: float = 0.0
var camera_arm_extra: float = 0.0
var _stamina_cooldown: float = 0.0
var _exhausted: bool = false
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
	mantle = MantleMotor.new(self, model)
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
	if event.is_action_pressed(CrouchMotor.ACTION) and StoryControl.can_move() and not is_mantling:
		crouch.toggle(is_on_floor())
	if event.is_action_pressed(&"interact") and StoryControl.can_interact():
		interactor.interact()


func _process(delta: float) -> void:
	_camera_rig.global_position = global_position + Vector3.UP * (1.5 + camera_lift - crouch.camera_drop())
	var look := Input.get_vector(&"look_left", &"look_right", &"look_up", &"look_down")
	if look != Vector2.ZERO and StoryControl.can_look():
		var s := stick_sensitivity * GameSettings.stick_sensitivity * delta
		_look(look.x * s, look.y * s)
	camera_control.update(delta)
	if _breath:
		_breath.update(delta)
	look_input_this_frame = false


func _physics_process(delta: float) -> void:
	crouch.step(delta)
	if is_mantling:
		crouch.set_crouched(false)
		return

	var input := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	if not StoryControl.can_move():
		input = Vector2.ZERO
	var yaw := _camera_rig.rotation.y
	var steer := steer_frame.yaw(input, yaw, steer_exclusion(), is_aiming or is_drawing)
	var direction := Vector3(input.x, 0.0, input.y).rotated(Vector3.UP, steer)
	# Sprint or jump stands her up from a crouch, and so does a cutscene or a fall.
	if crouch.crouched and (Input.is_action_just_pressed(&"sprint") or Input.is_action_just_pressed(&"jump")
			or not StoryControl.can_move() or (jump_motor.airborne and not is_on_floor())):
		crouch.set_crouched(false)
	# Holding sprint runs at sprint_speed until released: stamina no longer limits it.
	var sprinting := Input.is_action_pressed(&"sprint") and direction != Vector3.ZERO \
			and not is_drawing and not is_aiming and not crouch.crouched
	_running = sprinting
	_update_stamina(delta)

	var speed := run_speed
	if is_aiming or is_drawing:
		speed = aim_speed
	elif sprinting:
		speed = sprint_speed
	elif input.length() < 0.5:
		speed = walk_speed
	speed = crouch.limit_speed(speed)
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

	horizontal = GroundMotor.horizontal(self, horizontal, direction, speed, sprinting, delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z

	# Gentle Mode catches ledges whichever way she is pushing.
	var reach_input := input.length() > 0.3 if GameSettings.gentle_mode else input.y < -0.3
	if not is_on_floor() and velocity.y < 2.0 and reach_input:
		_try_mantle()

	GroundMotor.turn_model(self, direction, yaw, delta)
	move_and_slide()
	_remember_safe_spot(delta)


## Eases the camera toward behind her, turning at most `max_turn` radians
## (R / right stick click caps it; teleports recentre fully).
func recenter_camera(max_turn: float = PI) -> void:
	camera_control.recenter(max_turn)


## The one way to move her instantly (Return Home, Wriggle Free, a save load, tools):
## stops a ledge climb in progress (its tween would otherwise carry her back onto
## the ledge), zeroes her velocity, and brings the camera and its fade with her.
func teleport(pos: Vector3) -> void:
	mantle.cancel()
	velocity = Vector3.ZERO
	steer_frame.release()
	global_position = pos
	camera_control.snap_to(pos)
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
	return camera_control.yaw()


func camera_pitch() -> float:
	return camera_control.pitch()


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
	camera_control.nudge(yaw_delta, pitch_delta)


## The camera turns kept out of her steering while a direction is held
## (SteerFrame): turns the player didn't make, always; the player's own too
## unless "Turning the camera steers her while moving" is on.
func steer_exclusion() -> float:
	return camera_auto_yaw + camera_look_yaw


func aim_point(max_distance: float = 250.0) -> Vector3:
	return camera_control.aim_point(max_distance)


## Sprinting this frame (FeyreCamera's follow-behind swings only while she runs).
func is_running() -> bool:
	return _running


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


## Climbs onto a ledge in front of Feyre between knee and reach height.
func _try_mantle() -> bool:
	return mantle.try_climb()


## Player look input (already scaled); applies the invert settings.
func _look(x: float, y: float) -> void:
	camera_control.look(x, y)


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
	return camera_control.is_indoors()


func close_shoulder(arm: float) -> float:
	return FeyreCamera.close_shoulder(arm)


func shoulder_clearance(want: float) -> float:
	return camera_control.shoulder_clearance(want)


func room_clearance(want: float) -> float:
	return camera_control.room_clearance(want)


## Camera height above its pivot (m), for tests and tools.
func camera_rise() -> float:
	return camera_control.rise()


func _build_components() -> void:
	CrouchMotor.ensure_action()
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


var _breath: FeyreBreath


func _build_breath() -> void:
	_breath = FeyreBreath.new(body_state)
	model.add_child(_breath)


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
	camera_control = FeyreCamera.new(self)
	_camera_rig = camera_control.rig
	camera = camera_control.camera
