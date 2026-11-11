## Feyre's white mare (lane L47, docs/contracts/mount.md). One node in the game
## scene (story/act1/act1_game.gd). It decides when the mare exists, puts
## Feyre in the saddle and takes her out, and steers the mare from the
## player's input while she rides.
##
## By deed, no markers (R2): after `first_dinner_eaten` the mare waits saddled
## in the stable yard. Mounting her the first time raises the fact
## `fact.mare_ridden` through an ActionTrigger (never a phase flag); from then
## on the whistle (H, pad share) brings her at a gallop wherever Feyre stands
## outdoors north of the Wall. No riding in story scenes, under a roof, south
## of the Wall, or into dread: she balks at the Bogge's DreadField and won't
## enter the Suriel glade or the naga reeds. Riding never skips a deed
## trigger: every ActionTrigger the mare passes through fires as if Feyre
## walked it.
##
## Controls in the saddle: move steers (light stick walks, full canters),
## sprint gallops, jump leaps, E picks what's in reach from the saddle or,
## with nothing in reach, gets down (hold E to get down anyway).
class_name MountDirector
extends Node

signal mounted
signal dismounted
signal whistled(answered: bool)

const DATA := preload("res://data/mount/white_mare.tres")
const WHISTLE := preload("res://systems/mount/sounds/whistle.wav")
const WIND := preload("res://systems/mount/sounds/wind.wav")
## The gallop is capped (streaming); it is sold with a wider lens and the wind.
const GALLOP_FOV := 12.0
## The chase camera in the saddle: pivot lifted and arm drawn back so the
## camera looks down past Feyre to the mare's neck and ears and the road ahead.
## Eased in on mounting, back to 0 on getting down (Feyre.camera_lift/_arm_extra).
const RIDE_LIFT := 0.8
const RIDE_ARM := 1.6
## The pitch the camera settles to when the player isn't looking around (rad, -18 deg).
const RIDE_PITCH := -0.314
const RIDE_BLEND := 0.6
const ACTION := &"call_mount"
const UNLOCK_AFTER := "first_dinner_eaten"
const RIDDEN_FLAG := "fact.mare_ridden"
## She waits at home only while Feyre is this near the stables.
const HOME_RADIUS := 220.0
## A whistle this near and she simply turns and comes; farther, she arrives from out of sight.
const NEAR_CALL := 110.0
const HOLD_DISMOUNT := 0.35
const LOOK_GRACE := 0.8
const TRIGGER_SWEEP := 0.1
const PROMPT_RADIUS := 3.0
const DELTAS := &"mount"
const HINT := "Whistle for her with H (share on a pad), and she'll come."

var data: MountData = DATA
var mare: MareMount
var feyre: Node3D
var riding: bool = false
var pose: RidePose
## Why riding is off at a point, or &"" when it's allowed (for tests and probes).
var last_block: StringName = &""
## Probes and clips steer without input: returns [Vector3 world direction, bool gallop].
var autopilot: Callable

var _spaces: Dictionary = {}
var _e_down: float = -1.0
var _since_look: float = 99.0
var _sweep: float = 0.0
var _inside: Dictionary = {}
var _whistle: AudioStreamPlayer
var _prompt: Label3D
var _unlock: ActionTrigger
var _wind: AudioStreamPlayer
var _base_fov: float = -1.0
var _cam_tween: Tween
var _steer_frame := SteerFrame.new()


func _ready() -> void:
	name = "MountDirector"
	_ensure_action()
	EventBus.scene_space_started.connect(func(id: StringName) -> void:
		_spaces[id] = true
		if riding:
			dismount())
	EventBus.scene_space_finished.connect(func(id: StringName) -> void: _spaces.erase(id))
	_whistle = AudioStreamPlayer.new()
	_whistle.stream = WHISTLE
	_whistle.volume_db = -6.0
	add_child(_whistle)
	_wind = AudioStreamPlayer.new()
	var loop := WIND.duplicate() as AudioStreamWAV
	loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop.loop_end = loop.data.size() / 2
	_wind.stream = loop
	_wind.volume_db = -60.0
	add_child(_wind)
	_unlock = ActionTrigger.new()
	_unlock.name = "MareRiddenTrigger"
	_unlock.flag = RIDDEN_FLAG
	_unlock.fire_on_body_enter = false
	_unlock.monitoring = false
	add_child(_unlock)


static func _ensure_action() -> void:
	if InputMap.has_action(ACTION):
		return
	InputMap.add_action(ACTION)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_H
	InputMap.action_add_event(ACTION, key)
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_MISC1
	InputMap.action_add_event(ACTION, pad)


## True once the first dinner is eaten: the mare is in the stables.
func available() -> bool:
	return WorldState.has_flag(UNLOCK_AFTER)


## True once Feyre has ridden her: the whistle works.
func unlocked() -> bool:
	return WorldState.has_flag(RIDDEN_FLAG)


## 0..1: how much dread lies at `at` (the DreadFields, the no-ride regions).
func dread_at(at: Vector3) -> float:
	var d := 0.0
	if is_inside_tree():
		d = DreadField.withdrawal_at(get_tree(), at)
	var region := WorldStreamer.region_at(at)
	if region and data.no_ride_regions.has(String(region.id)):
		d = 1.0
	return d


## Why she can't be ridden or called at `at` (&"" when she can).
func block_reason(at: Vector3) -> StringName:
	if not available():
		return &"not_yet"
	if not _spaces.is_empty():
		return &"scene"
	if StoryControl.mode != StoryControl.Mode.FULL:
		return &"story"
	if not WorldMap.is_in_prythian(at) or WorldMap.distance_to_wall(at) < 12.0:
		return &"realm"
	if _roofed(at):
		return &"indoors"
	if dread_at(at) > 0.15:
		return &"dread"
	return &""


func _roofed(at: Vector3) -> bool:
	if not is_inside_tree():
		return false
	var space := get_viewport().world_3d.direct_space_state if get_viewport() and get_viewport().world_3d else null
	if space == null:
		return false
	var from := at + Vector3.UP * 2.6
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.UP * 9.0, 1)
	return not space.intersect_ray(q).is_empty()


func _player() -> Node3D:
	if feyre == null or not is_instance_valid(feyre) or not feyre.is_inside_tree():
		feyre = get_tree().get_first_node_in_group(&"player") as Node3D if is_inside_tree() else null
	return feyre


# ------------------------------------------------------------------ the mare

func spawn_mare(at: Vector3, yaw: float) -> MareMount:
	if mare and is_instance_valid(mare):
		return mare
	mare = MareMount.new()
	mare.data = data
	mare.dread_probe = dread_at
	var parent := get_parent() if get_parent() is Node3D else self
	parent.add_child(mare)
	mare.global_position = at
	mare.rotation.y = yaw
	mare.used.connect(func(user: Node) -> void: mount(user))
	_add_prompt()
	return mare


func free_mare() -> void:
	if riding:
		dismount()
	if mare and is_instance_valid(mare):
		mare.queue_free()
	mare = null
	_prompt = null


## Ground height under (x, z), or NAN with nothing loaded there.
func ground_at(x: float, z: float) -> float:
	if not is_inside_tree() or get_viewport() == null or get_viewport().world_3d == null:
		return NAN
	var space := get_viewport().world_3d.direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, 400.0, z), Vector3(x, -200.0, z), 1))
	return NAN if hit.is_empty() else (hit.position as Vector3).y


## The whistle. Returns true when she answers.
func whistle() -> bool:
	var p := _player()
	if p == null or riding:
		return false
	_whistle.play()
	last_block = block_reason(p.global_position)
	var ok := last_block == &"" and unlocked()
	if ok:
		_answer(p)
	whistled.emit(ok)
	return ok


func _answer(p: Node3D) -> void:
	var beside := p.global_position + _side_of(p) * 2.2
	if mare and is_instance_valid(mare) and mare.global_position.distance_to(p.global_position) <= NEAR_CALL:
		mare.call_to(beside)
		mare.neigh()
		return
	free_mare()
	var start := _out_of_sight(p, data.call_distance)
	spawn_mare(start, atan2(-(beside - start).x, -(beside - start).z))
	mare.call_to(beside)
	mare.neigh()


## Feyre's right, flat (where the mare draws up).
func _side_of(p: Node3D) -> Vector3:
	var yaw: float = p.call(&"camera_yaw") if p.has_method(&"camera_yaw") else p.rotation.y
	return Vector3(cos(yaw), 0.0, -sin(yaw))


## A point `dist` metres from Feyre, behind the camera, on open ground she may ride.
func _out_of_sight(p: Node3D, dist: float) -> Vector3:
	var yaw: float = p.call(&"camera_yaw") if p.has_method(&"camera_yaw") else p.rotation.y
	var behind := Vector3(sin(yaw), 0.0, cos(yaw))  # the camera looks along -Z rotated by yaw
	for k in [0, 1, -1, 2, -2, 3, -3]:
		for d: float in [dist, dist * 0.6, dist * 0.35]:
			var dir := behind.rotated(Vector3.UP, k * 0.35)
			var at := p.global_position + dir * d
			var y := ground_at(at.x, at.z)
			if is_nan(y):
				continue
			at.y = y + 0.05
			# Never from the far side of the Wall (T107): she couldn't get through.
			if WorldMap.is_in_prythian(at) != WorldMap.is_in_prythian(p.global_position):
				continue
			if absf(y - p.global_position.y) < d * 0.6 and dread_at(at) <= 0.15 and not _roofed(at):
				return at
	return p.global_position + behind * 6.0


# ------------------------------------------------------------------ saddle

func can_mount() -> bool:
	var p := _player()
	return p != null and not riding and mare != null and block_reason(p.global_position) == &""


func mount(user: Node = null) -> bool:
	var p := _player() if user == null else user as Node3D
	if p == null or mare == null or riding:
		return false
	last_block = block_reason(p.global_position)
	if last_block != &"":
		mare.snort()
		return false
	feyre = p
	riding = true
	var first := not unlocked()
	if p is CharacterBody3D:
		(p as CharacterBody3D).velocity = Vector3.ZERO
		mare.add_collision_exception_with(p)
	p.set_physics_process(false)
	_set_bow(false)
	mare.state = MareMount.State.RIDDEN
	mare.set_mountable(false)
	pose = Saddle.seat(p)
	if pose:
		pose.amount = 0.0
		create_tween().tween_property(pose, ^"amount", 1.0, 0.25)
	_inside.clear()
	_place_rider(0.0)
	_ride_camera(p, true)
	if first:
		_unlock.fire()
		Juice.burst(mare, &"unlock")
		mare.neigh()
	mounted.emit()
	return true


func dismount() -> void:
	if not riding:
		return
	riding = false
	var p := _player()
	if mare and is_instance_valid(mare):
		mare.stand()
		mare.set_mountable(true)
		if p:
			mare.remove_collision_exception_with(p)
	if p:
		var at := _landing(p)
		p.global_position = at
		if p is CharacterBody3D:
			(p as CharacterBody3D).velocity = Vector3.ZERO
		if p.get(&"model") is Node3D and mare:
			(p.get(&"model") as Node3D).rotation = Vector3(0.0, mare.rotation.y, 0.0)
		p.set_physics_process(true)
	_set_bow(true)
	_calm_feel()
	if p:
		Saddle.unseat(p)
		_ride_camera(p, false)
	# Taught once, kept with the world (not a story flag).
	if unlocked() and not WorldDeltas.get_region_value(DELTAS, "whistle_taught", false):
		WorldDeltas.set_region_value(DELTAS, "whistle_taught", true)
		FindCard.note(get_tree(), HINT)
	dismounted.emit()


## Beside the mare on her left (the near side), on the ground, or wherever is free.
func _landing(p: Node3D) -> Vector3:
	if mare == null or not is_instance_valid(mare):
		return p.global_position
	var left := -mare.global_basis.x
	for side: Vector3 in [left, -left, mare.global_basis.z]:
		var at := mare.global_position + side * 1.3
		var y := ground_at(at.x, at.z)
		if not is_nan(y) and absf(y - mare.global_position.y) < 1.2:
			return Vector3(at.x, y + 0.05, at.z)
	return mare.global_position + left * 1.3 + Vector3.UP * 0.3


func _set_bow(on: bool) -> void:
	var p := _player()
	if p == null:
		return
	var bow := p.get(&"bow_controller") as Node
	if bow:
		bow.set_physics_process(on)


## Where her hips sit: the saddle, riding the spine bone through each stride.
func seat_point() -> Vector3:
	if mare == null or mare.horse == null:
		return Vector3.ZERO
	return mare.horse.seat_point()


func _place_rider(_delta: float) -> void:
	var p := _player()
	if p == null or mare == null or mare.horse == null:
		return
	Saddle.place(p, mare.horse)
	if pose:
		var lean := clampf((mare.speed - data.canter_speed * 0.6) / maxf(data.gallop_speed - data.canter_speed * 0.6, 0.1), 0.0, 1.0)
		pose.lean = lerpf(pose.lean, lean, 0.1)


# ------------------------------------------------------------------ input and frame

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and (event as InputEventMouseMotion).relative.length() > 0.5:
		_since_look = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(ACTION) and not event.is_echo():
		whistle()
		get_viewport().set_input_as_handled()
		return
	if not riding:
		return
	if event.is_action_pressed(&"interact") and not event.is_echo():
		_e_down = 0.0
		get_viewport().set_input_as_handled()
	elif event.is_action_released(&"interact") and _e_down >= 0.0:
		var held := _e_down
		_e_down = -1.0
		get_viewport().set_input_as_handled()
		if held < HOLD_DISMOUNT:
			_tap_interact()
	elif event.is_action_pressed(&"jump") and mare:
		mare.request_leap()
		get_viewport().set_input_as_handled()


## E in the saddle: pick a flower, an arrow, a carcass in reach; a station
## (a bench, a nook, a snare) means getting down first; nothing means getting down.
func _tap_interact() -> void:
	var p := _player()
	var interactor := p.get(&"interactor") as Interactor if p else null
	if interactor and (interactor.pick_up_arrow() or interactor._harvest() or interactor._forage() or interactor._field()):
		return
	dismount()
	if interactor and _station_near(p):
		interactor.interact.call_deferred()


func _station_near(p: Node3D) -> bool:
	for n in get_tree().get_nodes_in_group(&"station"):
		if n != mare and n is Node3D and (n as Node3D).global_position.distance_to(p.global_position) <= Interactor.REACH:
			return true
	return false


func _process(delta: float) -> void:
	_since_look += delta
	var look := Input.get_vector(&"look_left", &"look_right", &"look_up", &"look_down")
	if look.length() > 0.1:
		_since_look = 0.0
	var p := _player()
	if p == null:
		return
	if riding:
		if _e_down >= 0.0:
			_e_down += delta
			if _e_down >= HOLD_DISMOUNT:
				_e_down = -1.0
				dismount()
				return
		if block_reason(p.global_position) in [&"scene", &"story", &"realm"]:
			dismount()
			return
		_steer()
		_place_rider(delta)
		_speed_feel(p, delta)
		_follow_camera(p, delta)
		return
	_keep_mare(p)
	_update_prompt(p)


func _physics_process(delta: float) -> void:
	if not riding:
		return
	_sweep -= delta
	if _sweep <= 0.0:
		_sweep = TRIGGER_SWEEP
		sweep_triggers()


func _steer() -> void:
	if mare == null:
		return
	if autopilot.is_valid():
		var a: Array = autopilot.call()
		mare.steer = a[0]
		mare.gallop = a[1]
		_steer_frame.release()
		return
	var input := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	var yaw: float = feyre.call(&"camera_yaw") if feyre.has_method(&"camera_yaw") else 0.0
	# Like on foot (SteerFrame): camera-relative, but camera moves the rider didn't make don't steer.
	var auto: float = float(feyre.call(&"steer_exclusion")) if feyre.has_method(&"steer_exclusion") else 0.0
	mare.steer = Vector3(input.x, 0.0, input.y).rotated(Vector3.UP, _steer_frame.yaw(input, yaw, auto))
	mare.gallop = Input.is_action_pressed(&"sprint")


## 0 at a canter, 1 at the full gallop: the lens widens and the wind rises.
func _speed_feel(p: Node3D, delta: float) -> void:
	if mare == null:
		return
	var t := clampf((mare.speed - data.canter_speed * 0.8) / maxf(data.gallop_speed - data.canter_speed * 0.8, 0.1), 0.0, 1.0)
	var cam := p.get(&"camera") as Camera3D
	if cam:
		if _base_fov < 0.0:
			_base_fov = cam.fov
		cam.fov = lerpf(cam.fov, _base_fov + GALLOP_FOV * t, clampf(3.0 * delta, 0.0, 1.0))
	if _wind:
		if t > 0.01 and not _wind.playing:
			_wind.play()
		_wind.volume_db = lerpf(_wind.volume_db, linear_to_db(maxf(t, 0.001)) - 10.0, clampf(4.0 * delta, 0.0, 1.0))


func _calm_feel() -> void:
	var p := _player()
	var cam := p.get(&"camera") as Camera3D if p else null
	if cam and _base_fov > 0.0:
		create_tween().tween_property(cam, ^"fov", _base_fov, 0.4)
	_base_fov = -1.0
	if _wind:
		_wind.stop()
		_wind.volume_db = -60.0


## Eases Feyre's camera out to the riding frame (`on`) or back to her own.
func _ride_camera(p: Node, on: bool) -> void:
	if p == null or not (&"camera_lift" in p and &"camera_arm_extra" in p):
		return
	if _cam_tween:
		_cam_tween.kill()
	_cam_tween = create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_cam_tween.tween_property(p, ^"camera_lift", RIDE_LIFT if on else 0.0, RIDE_BLEND)
	_cam_tween.tween_property(p, ^"camera_arm_extra", RIDE_ARM if on else 0.0, RIDE_BLEND)


func _exit_tree() -> void:
	# Never leave her camera lifted if the director goes while she rides.
	var p := _player()
	if riding and p and &"camera_lift" in p:
		p.set(&"camera_lift", 0.0)
		p.set(&"camera_arm_extra", 0.0)


## While she rides and the player isn't steering the camera, it swings in behind
## and settles to the riding pitch. It only ever returns to the yaw the keys steer in.
func _follow_camera(p: Node3D, delta: float) -> void:
	if mare == null or _since_look < LOOK_GRACE or not p.has_method(&"nudge_camera"):
		return
	if p.has_method(&"camera_pitch"):
		var dp := RIDE_PITCH - float(p.call(&"camera_pitch"))
		p.call(&"nudge_camera", 0.0, dp * clampf(1.5 * delta, 0.0, 1.0))
	# Aimed at the frame the keys steer in, not the mare's facing: a fresh press
	# takes the camera as its frame, so following her facing stacked every turn
	# into a spiral with no look input (as on foot, T037).
	if mare.speed < 3.0 or not _steer_frame.is_held():
		return
	var diff := wrapf(_steer_frame.held_yaw() - float(p.call(&"camera_yaw")), -PI, PI)
	p.call(&"nudge_camera", diff * clampf(2.2 * delta, 0.0, 1.0), 0.0)


## Fires every ActionTrigger the mare and rider pass through that Feyre's own
## body didn't touch (she sits a metre up; low trigger volumes would miss her).
func sweep_triggers() -> int:
	var p := _player()
	if p == null or mare == null or not mare.is_inside_tree():
		return 0
	var shape := CapsuleShape3D.new()
	shape.radius = 0.6
	shape.height = 2.6
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = Transform3D(Basis.IDENTITY, mare.global_position + Vector3.UP * 1.3)
	q.collide_with_areas = true
	q.collide_with_bodies = false
	q.collision_mask = 0xFFFFFFFF
	var now := {}
	var fired := 0
	for hit: Dictionary in mare.get_world_3d().direct_space_state.intersect_shape(q, 64):
		var t := hit.get("collider") as ActionTrigger
		if t == null or not t.fire_on_body_enter:
			continue
		now[t.get_instance_id()] = true
		if _inside.has(t.get_instance_id()):
			continue
		if t.required_group != &"" and not p.is_in_group(t.required_group):
			continue
		if p is PhysicsBody3D and t.overlaps_body(p):
			continue
		if not (t.once and t.fired):
			t.fire()
			fired += 1
	_inside = now
	return fired


func _keep_mare(p: Node3D) -> void:
	if not available() or not WorldMap.is_in_prythian(p.global_position):
		if mare and is_instance_valid(mare):
			free_mare()
		return
	if mare and is_instance_valid(mare):
		var far := mare.global_position.distance_to(p.global_position)
		if mare.state == MareMount.State.STANDING and far > data.stray_distance:
			free_mare()  # she has gone home to the stables
		elif mare.state == MareMount.State.COMING and mare.stuck_for() > 3.0:
			mare.global_position = _out_of_sight(p, 8.0)
		return
	if p.global_position.distance_to(data.home) <= HOME_RADIUS:
		var y := ground_at(data.home.x, data.home.z)
		if not is_nan(y):
			spawn_mare(Vector3(data.home.x, y + 0.05, data.home.z), data.home_yaw)


func _add_prompt() -> void:
	_prompt = Label3D.new()
	_prompt.text = "E"
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.no_depth_test = true
	_prompt.font_size = 40
	_prompt.outline_size = 10
	_prompt.modulate = Color(1.0, 0.96, 0.86, 0.9)
	_prompt.outline_modulate = Color(0.42, 0.3, 0.45, 0.8)
	_prompt.position = Vector3.UP * 2.3
	_prompt.visible = false
	mare.add_child(_prompt)


func _update_prompt(p: Node3D) -> void:
	if _prompt == null or not is_instance_valid(_prompt) or mare == null:
		return
	var d := Vector2(mare.global_position.x - p.global_position.x, mare.global_position.z - p.global_position.z).length()
	_prompt.visible = d <= PROMPT_RADIUS and mare.state == MareMount.State.STANDING
