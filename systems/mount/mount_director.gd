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
## walked it. A story scene is one that holds StoryControl; the background
## moments that only wait on deeds (the hall marks, the manor map) leave her
## free and never stop the mare (T148).
##
## Getting on and off is one motion (MountMotion, L47-6): a vault up from her
## near side and a slide down it, never a teleport. The whistle is a gesture
## (fingers to her lips) and she answers from where she is with a whinny; called,
## she comes at a gallop with a drift of petals and pulls up side-on, her near
## side to Feyre. Before she knows Feyre's whistle she only answers from the stables.
##
## Controls in the saddle: move steers (light stick walks, full canters),
## sprint gallops, jump leaps, E picks what's in reach from the saddle or,
## with nothing in reach, gets down (hold E to get down anyway).
##
## The bond (MareBond, L47-8) sets how far she hears the whistle and how far
## from the stables she carries Feyre: at the edge she slows, snorts and turns
## for home; whistled from beyond her hearing, only the wind answers. Each new
## step plays a moment when Feyre is next beside her (head lowered to her, a
## nicker, a sparkle) and Feyre's own thought (data/mount/mare_thoughts.tres,
## a dialogue line on the bond fact). From the second step she trots out to meet
## Feyre coming home.
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
const HINT := "Whistle for her with %s, and she'll come."

var data: MountData = DATA
var mare: MareMount
var feyre: Node3D
var riding: bool = false
var pose: RidePose
## Why riding is off at a point, or &"" when it's allowed (for tests and probes).
var last_block: StringName = &""
## Probes and clips steer without input: returns [Vector3 world direction, bool gallop].
var autopilot: Callable

var _e_down: float = -1.0
var _since_look: float = 99.0
var _sweep: float = 0.0
var _inside: Dictionary = {}
var _whistle: AudioStreamPlayer
var _unlock: ActionTrigger
var _wind: AudioStreamPlayer
var _base_fov: float = -1.0
var _cam_tween: Tween
var _steer_frame := SteerFrame.new()
## The vault on or the slide off while it plays (null otherwise).
var motion: MountMotion
var _off_at: Vector3
var _gesture_t: float = -1.0
var _answer_in: float = -1.0
var _far_voice: AudioStreamPlayer3D
var _last_yaw: float = NAN
var _bank: float = 0.0

## Her own key beside her (T; project.godot, R14 OK 2026-11-25): brush,
## treats, dress-up, her page. Not E, which rides.
const TEND_ACTION := &"tend_mount"
## On the pad, hold X this long beside her to tend her instead of mounting (s).
const HOLD_TEND := 0.4
const TEND_HINT := "Press %s beside her to brush her, feed her and dress her up."

var tending: MareTendingView
var _use_held: float = -1.0
var _use_user: Node
## The last interact press came from a pad (hold X tends there).
var _pad_use: bool = false

## The whistle gesture's length (s), and when she answers after it (s).
const GESTURE_TIME := 0.95
const ANSWER_DELAY := 0.55

## Feyre's thoughts on the bond, added to the free-roam dialogue.
const THOUGHTS := "res://data/mount/mare_thoughts.tres"
## A new bond step's moment plays when Feyre is this near her, on foot.
const MOMENT_NEAR := 6.0
## How often the ride checks which region they are in (s).
const REGION_CHECK := 1.0
## The edge of her range: she won't go past it, and the snort repeats only
## after Feyre has come this far back inside.
const EDGE_RESET := 40.0
## How far ahead (m) she smells the blight, and how long (s) she holds off after.
const BLIGHT_LOOK := 6.0
const BALK_HOLD := 1.5
## Coming home from away, she trots out to meet Feyre this far from the stables
## (and not nearer than MEET_NEAR to her).
const MEET_NEAR := 16.0
const MEET_PACE := 5.0

var _moment: int = -1
var _last_ride_at: Vector3 = Vector3.INF
var _region_t: float = 0.0
var _at_edge: bool = false
var _balking: bool = false
var _tips: RideTips
var _balk_t: float = 0.0
var _away: bool = false
var _met: bool = false
var _gust: AudioStreamPlayer


func _ready() -> void:
	name = "MountDirector"
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
	if not MareCare.on_care.has(MareBond.on_care):
		MareCare.on_care.append(MareBond.on_care)
	if not EventBus.flag_changed.is_connected(_on_flag):
		EventBus.flag_changed.connect(_on_flag)
	_gust = AudioStreamPlayer.new()
	_gust.stream = WIND
	_gust.volume_db = -14.0
	add_child(_gust)
	_add_thoughts.call_deferred()


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
	mare.used.connect(_on_used)
	return mare


func free_mare() -> void:
	if riding:
		dismount()
	if mare and is_instance_valid(mare):
		mare.queue_free()
	mare = null


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
	if p == null or riding or tending:
		return false
	if motion:
		return false
	_whistle.play()
	_gesture(p)
	last_block = block_reason(p.global_position)
	var ok := last_block == &"" and unlocked()
	if ok and call_distance(p.global_position) > MareBond.hear_range():
		ok = false
		last_block = &"too_far"
		_too_far()
	elif ok and in_blight(p.global_position) and not MareBond.balmed():
		# She hears, but she won't come onto that ground: a far whinny only.
		ok = false
		last_block = &"blight"
		_answer_in = ANSWER_DELAY
	elif ok:
		MareBond.answered()
		_answer(p)
	elif last_block == &"" and available():
		# She doesn't know Feyre's whistle yet: only a far whinny from the stables.
		_answer_in = ANSWER_DELAY
	whistled.emit(ok)
	return ok


## How far the whistle has to carry to her: to her where she stands, or to
## the stables when she's home (not out in the world).
func call_distance(from: Vector3) -> float:
	var at := mare.global_position if mare and is_instance_valid(mare) else data.home
	return Vector2(at.x - from.x, at.z - from.z).length()


## Called from beyond her hearing: nothing comes but the wind (and, the first
## time, Feyre's thought, a dialogue line on TOO_FAR_FACT).
func _too_far() -> void:
	if _gust:
		_gust.play()
	if not WorldState.has_flag(MareBond.TOO_FAR_FACT):
		WorldState.set_flag(MareBond.TOO_FAR_FACT, true)


## A new step of her bond past the first ride (its fact rises): her moment
## plays when Feyre is next by her.
func _on_flag(flag: String, value: Variant) -> void:
	if not WorldState.truthy(value):
		return
	for i in range(2, MareBond.TIERS.size()):
		if String(MareBond.TIERS[i]["fact"]) == flag:
			_moment = i


## Feyre's bond thoughts join the free-roam dialogue (its DEED lines on the facts).
func _add_thoughts() -> void:
	if not is_inside_tree() or not ResourceLoader.exists(THOUGHTS):
		return
	var dd := get_tree().get_first_node_in_group(DialogueDirector.GROUP) as DialogueDirector
	var book := load(THOUGHTS) as DialogueBook
	if dd and book and not dd.by_id.has(book.lines.front().id if not book.lines.is_empty() else &""):
		dd.add_book(book)


## A new step: she lowers her head to Feyre, nickers, and the air sparkles.
func _play_moment(p: Node3D) -> bool:
	if mare == null or not is_instance_valid(mare) or mare.state != MareMount.State.STANDING:
		return false
	if mare.global_position.distance_to(data.home) < 30.0:
		MareBond.balm_off()  # home at the stables: the balm has worn off
	if mare.global_position.distance_to(p.global_position) > MOMENT_NEAR:
		return false
	MareBond.beside()
	if _moment < 0:
		return false
	_moment = -1
	if mare.horse and mare.horse.animator:
		mare.horse.animator.nibble()
	mare.nicker()
	Juice.burst(mare, &"outfit")
	return true


## Fingers to her lips for the whistle (RidePose overrides, on foot).
func _gesture(p: Node3D) -> void:
	var sk := Saddle.skeleton_of(p)
	if sk == null:
		return
	RidePose.attach(sk)
	_gesture_t = 0.0


func _tick_gesture(p: Node3D, delta: float) -> void:
	if _gesture_t < 0.0:
		return
	_gesture_t += delta
	var sk := Saddle.skeleton_of(p)
	var pose := sk.get_node_or_null(^"RidePose") as RidePose if sk else null
	if pose == null:
		_gesture_t = -1.0
		return
	var w := MountMotion.seg(_gesture_t, 0.0, 0.22) * (1.0 - MountMotion.seg(_gesture_t, GESTURE_TIME - 0.3, GESTURE_TIME))
	pose.set_override(&"RightUpperArm", 0.55, -0.05, -0.85, w)
	pose.set_override(&"RightLowerArm", 0.35, 0.6, 0.72, w)
	if _gesture_t >= GESTURE_TIME:
		_gesture_t = -1.0
		pose.set_override(&"RightUpperArm", 0, 0, 0, 0.0)
		pose.set_override(&"RightLowerArm", 0, 0, 0, 0.0)


## A whinny from the stables, heard from far off (she isn't coming yet).
func _far_answer() -> void:
	if mare and is_instance_valid(mare) and mare.state != MareMount.State.RIDDEN:
		mare.neigh()
		return
	if _far_voice == null:
		_far_voice = AudioStreamPlayer3D.new()
		_far_voice.stream = MareMount.WHINNY
		_far_voice.unit_size = 60.0
		_far_voice.max_db = -2.0
		_far_voice.volume_db = -4.0
		add_child(_far_voice)
	var y := ground_at(data.home.x, data.home.z)
	_far_voice.global_position = Vector3(data.home.x, (0.0 if is_nan(y) else y) + 1.6, data.home.z)
	_far_voice.play()


func _answer(p: Node3D) -> void:
	var beside := p.global_position + _side_of(p) * 2.2
	if mare and is_instance_valid(mare) and mare.global_position.distance_to(p.global_position) <= NEAR_CALL:
		mare.call_to(beside, p)
		_answer_in = ANSWER_DELAY
		return
	free_mare()
	var start := _out_of_sight(p, data.call_distance)
	spawn_mare(start, atan2(-(beside - start).x, -(beside - start).z))
	mare.call_to(beside, p)
	_answer_in = ANSWER_DELAY


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

## E on her mounts; the keyboard tends with its own key (TEND_ACTION). The pad
## has no free button, so there a tap of X mounts and a hold tends (director,
## 2026-11-25), decided on release or at HOLD_TEND.
func _on_used(user: Node) -> void:
	if riding or motion or tending:
		return
	if not _pad_use or not Input.is_action_pressed(&"interact"):
		mount(user)
		return
	_use_held = 0.0
	_use_user = user


func _tick_use(delta: float) -> void:
	if _use_held < 0.0:
		return
	if Input.is_action_pressed(&"interact"):
		_use_held += delta
		if _use_held >= HOLD_TEND:
			_use_held = -1.0
			if open_tending():
				KeyHints.of(get_tree()).learn(&"tend")
	else:
		_use_held = -1.0
		mount(_use_user)


## Close enough, on foot, to tend her.
func can_tend() -> bool:
	var p := _player()
	if p == null or mare == null or not is_instance_valid(mare) or riding or motion or tending:
		return false
	if mare.state != MareMount.State.STANDING:
		return false
	var d := Vector2(mare.global_position.x - p.global_position.x, mare.global_position.z - p.global_position.z).length()
	return d <= PROMPT_RADIUS


## Opens the tending screen beside her (brush, treats, dress-up). Null if she isn't standing by.
func open_tending() -> MareTendingView:
	var p := _player()
	if p == null or mare == null or riding or motion or tending or mare.state != MareMount.State.STANDING:
		return null
	if block_reason(p.global_position) == &"story":
		return null
	UsePrompt.of(get_tree()).offer(self, "")
	KeyHints.of(get_tree()).hold(self, &"")
	tending = MareTendingView.open(self, mare, p, Gameplay.inventory)
	tending.closed.connect(func() -> void:
		tending = null
		if mare and is_instance_valid(mare):
			mare.refresh_look())
	return tending


func can_mount() -> bool:
	var p := _player()
	return p != null and not riding and mare != null and block_reason(p.global_position) == &""


func mount(user: Node = null, instant: bool = false) -> bool:
	var p := _player() if user == null else user as Node3D
	if p == null or mare == null or riding or motion:
		return false
	last_block = block_reason(p.global_position)
	if last_block != &"":
		mare.snort()
		return false
	feyre = p
	riding = true
	_tips = RideTips.attach(self)  # the riding keys she hasn't used yet (KeyHints)
	KeyHints.of(get_tree()).hold(self, &"")  # not the tending key while she rides
	UsePrompt.of(get_tree()).offer(self, "")  # and not "E   ride" while she's up
	var first := not unlocked()
	if p is CharacterBody3D:
		(p as CharacterBody3D).velocity = Vector3.ZERO
		mare.add_collision_exception_with(p)
	p.set_physics_process(false)
	_set_bow(false)
	mare.state = MareMount.State.RIDDEN
	mare.set_mountable(false)
	pose = Saddle.seat(p)
	_gesture_t = -1.0
	if pose:
		pose.clear_overrides()
		pose.amount = 0.0
	_inside.clear()
	if not instant and pose and mare.horse:
		motion = MountMotion.new()
		motion.begin_on(p, mare.horse, pose, ground_at)
		motion.tick(0.0)
	else:
		if pose:
			pose.amount = 1.0
		_place_rider(0.0)
	_ride_camera(p, true)
	if first:
		_unlock.fire()
		Juice.burst(mare, &"unlock")
		mare.neigh()
	mounted.emit()
	return true


## Gets her down: the slide off her near side (MountMotion), or at once when
## `instant` (a scene starting, the Wall, a story beat).
func dismount(instant: bool = false) -> void:
	if motion and motion.kind == MountMotion.Kind.OFF:
		if instant:
			motion.restore_mare()
			motion = null
			_finish_dismount(_off_at)
		return
	if not riding:
		return
	riding = false
	if _tips:
		_tips.queue_free()
		_tips = null
	var p := _player()
	if motion:
		motion.restore_mare()
		motion = null
	if mare and is_instance_valid(mare):
		mare.stand()
	if p == null:
		_finish_dismount(Vector3.INF)
		return
	_off_at = _landing(p)
	if instant or pose == null or mare == null or not is_instance_valid(mare) or mare.horse == null:
		_finish_dismount(_off_at)
		return
	_calm_feel()
	motion = MountMotion.new()
	motion.begin_off(p, mare.horse, pose, _off_at)
	motion.tick(0.0)


func _finish_dismount(at: Vector3, face_mare: bool = true) -> void:
	var p := _player()
	if mare and is_instance_valid(mare):
		mare.set_mountable(true)
		if p:
			mare.remove_collision_exception_with(p)
	if p and at != Vector3.INF:
		p.global_position = at
		if p is CharacterBody3D:
			(p as CharacterBody3D).velocity = Vector3.ZERO
		if face_mare and p.get(&"model") is Node3D and mare:
			(p.get(&"model") as Node3D).rotation = Vector3(0.0, mare.rotation.y, 0.0)
		p.set_physics_process(true)
	_set_bow(true)
	_calm_feel()
	MareBond.ride_ended()
	if pose:
		pose.clear_overrides()
	if p:
		Saddle.unseat(p)
		_ride_camera(p, false)
	# Taught once, kept with the world (not a story flag).
	if unlocked() and not WorldDeltas.get_region_value(DELTAS, "whistle_taught", false):
		WorldDeltas.set_region_value(DELTAS, "whistle_taught", true)
		PickupLog.of(get_tree()).note(HINT % KeyPrompt.key(ACTION))
	elif unlocked() and not WorldDeltas.get_region_value(DELTAS, "tend_taught", false):
		WorldDeltas.set_region_value(DELTAS, "tend_taught", true)
		PickupLog.of(get_tree()).note(TEND_HINT % KeyPrompt.key(TEND_ACTION))
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
	var bow := p.get(&"bow_controller") as BowController
	if bow:
		bow.stow(not on)


## Where her hips sit: the saddle, riding the spine bone through each stride.
func seat_point() -> Vector3:
	if mare == null or mare.horse == null:
		return Vector3.ZERO
	return mare.horse.seat_point()


func _place_rider(delta: float) -> void:
	var p := _player()
	if p == null or mare == null or mare.horse == null:
		return
	Saddle.place(p, mare.horse)
	# Into a turn both lean: her body to the inside, the mare a little roll.
	var yaw := mare.rotation.y
	var rate := 0.0 if is_nan(_last_yaw) or delta <= 0.0 else wrapf(yaw - _last_yaw, -PI, PI) / delta
	_last_yaw = yaw
	_bank = lerpf(_bank, clampf(rate * mare.speed / 14.0, -1.0, 1.0), clampf(6.0 * delta, 0.0, 1.0))
	if mare.horse.model:
		mare.horse.model.rotation.z = _bank * 0.09
	if pose:
		var lean := clampf((mare.speed - data.canter_speed * 0.6) / maxf(data.gallop_speed - data.canter_speed * 0.6, 0.1), 0.0, 1.0)
		pose.lean = lerpf(pose.lean, lean, 0.1)
		pose.bank = _bank


# ------------------------------------------------------------------ input and frame

func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"interact"):
		_pad_use = event is InputEventJoypadButton
	if event is InputEventMouseMotion and (event as InputEventMouseMotion).relative.length() > 0.5:
		_since_look = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(ACTION) and not event.is_echo():
		whistle()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(TEND_ACTION) and not event.is_echo() and can_tend():
		if open_tending():
			KeyHints.of(get_tree()).learn(&"tend")
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
	if interactor and interactor.pick_up():
		return
	# A station in reach: straight down to use it; otherwise the slide off.
	var station := interactor != null and _station_near(p)
	dismount(station)
	if station:
		interactor.interact.call_deferred()


func _station_near(p: Node3D) -> bool:
	for n in get_tree().get_nodes_in_group(&"station"):
		if n != mare and n is Node3D and (n as Node3D).global_position.distance_to(p.global_position) <= Interactor.REACH:
			return true
	return false


func _process(delta: float) -> void:
	_since_look += delta
	if not get_tree().paused and MareBond.tier() >= 1:
		MarePage.tick(delta)  # her page's hints unlock with play time
	var look := Input.get_vector(&"look_left", &"look_right", &"look_up", &"look_down")
	if look.length() > 0.1:
		_since_look = 0.0
	var p := _player()
	if p == null:
		return
	_tick_gesture(p, delta)
	_tick_use(delta)
	if _answer_in >= 0.0:
		_answer_in -= delta
		if _answer_in < 0.0:
			if unlocked() and mare and is_instance_valid(mare) and mare.state == MareMount.State.COMING:
				mare.neigh()
			else:
				_far_answer()
	if motion:
		if mare:
			mare.steer = Vector3.ZERO
			mare.gallop = false
		if not motion.tick(delta):
			var was := motion.kind
			motion = null
			if was == MountMotion.Kind.OFF:
				_finish_dismount(_off_at, false)
			else:
				_last_yaw = NAN
		elif riding and block_reason(p.global_position) in [&"story", &"realm"]:
			dismount(true)
		return
	if riding:
		if _e_down >= 0.0:
			_e_down += delta
			if _e_down >= HOLD_DISMOUNT:
				_e_down = -1.0
				dismount()
				return
		if block_reason(p.global_position) in [&"story", &"realm"]:
			dismount(true)
			return
		_steer()
		_keep_in_range()
		_keep_off_blight()
		_balk_t -= delta
		_count_ride(delta)
		_place_rider(delta)
		_speed_feel(p, delta)
		_follow_camera(p, delta)
		return
	_last_ride_at = Vector3.INF
	if tending:
		return
	_keep_mare(p)
	_play_moment(p)
	_update_prompt(p)


func _physics_process(delta: float) -> void:
	if not riding or motion:
		return
	_sweep -= delta
	if _sweep <= 0.0:
		_sweep = TRIGGER_SWEEP
		sweep_triggers()


## At the edge of how far she'll carry Feyre she won't go on: she slows,
## snorts and turns for home (MareBond.carry_range, from the stables).
func _keep_in_range() -> void:
	if mare == null:
		return
	var carry := MareBond.carry_range()
	if is_inf(carry):
		return
	var out := mare.global_position - data.home
	out.y = 0.0
	var d := out.length()
	if d < carry - EDGE_RESET:
		_at_edge = false
	if d < carry or d < 1.0:
		return
	out /= d
	var away := mare.steer.dot(out)
	if away > -0.2:
		mare.steer = (mare.steer - out * (away + 0.6)).limit_length(0.45)
		mare.gallop = false
	if not _at_edge:
		_at_edge = true
		mare.snort()
		MareBond.reached_edge()
		MarePage.fail()


## True on the ground she won't set a hoof on without the balm (the Blighted
## Reaches: the smell of what's loose there, Keeper 2026-11-18).
func in_blight(at: Vector3) -> bool:
	var region := WorldStreamer.region_at(at)
	return region != null and region.id == MareBond.BLIGHT_REGION


## At the blight she plants her feet and backs off, ears flat, as horses do at
## the Bogge (ch 9-10), unless the sweetbalm masks the smell.
func _keep_off_blight() -> void:
	if mare == null or MareBond.balmed():
		_balking = false
		return
	var at := mare.global_position
	var ahead := at + Vector3(mare.steer.x, 0.0, mare.steer.z).normalized() * BLIGHT_LOOK
	if not in_blight(ahead) and not in_blight(at):
		if _balking and _balk_t <= 0.0:
			_balking = false
		return
	var region := WorldStreamer.region_at(ahead if in_blight(ahead) else at)
	var out := at - region.center
	out.y = 0.0
	out = out.normalized() if out.length() > 0.1 else -mare.heading()
	mare.steer = out * 0.35
	mare.gallop = false
	_balk_t = BALK_HOLD
	if not _balking:
		_balking = true
		mare.snort()
		MareBond.balked()
		MarePage.fail()


## Distance ridden together and the regions they reach (the bond's deeds).
func _count_ride(delta: float) -> void:
	if mare == null:
		return
	var at := mare.global_position
	if _last_ride_at != Vector3.INF:
		var step := Vector2(at.x - _last_ride_at.x, at.z - _last_ride_at.z).length()
		if step < 30.0:  # a jump, not a ride
			MareBond.ride(step, mare.horse != null and mare.horse.bareback)
			if in_blight(at):
				MareBond.blight_ride(step)
	_last_ride_at = at
	_region_t -= delta
	if _region_t <= 0.0:
		_region_t = REGION_CHECK
		var region := WorldStreamer.region_at(at)
		if region:
			MareBond.reach_region(region.id)


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
	if EventBus.flag_changed.is_connected(_on_flag):
		EventBus.flag_changed.disconnect(_on_flag)
	MareCare.on_care.erase(MareBond.on_care)
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
		elif _away and not _met:
			_meet(p, far)
		return
	if p.global_position.distance_to(data.home) > HOME_RADIUS + 20.0:
		_away = true
		_met = false
	if p.global_position.distance_to(data.home) <= HOME_RADIUS:
		var y := ground_at(data.home.x, data.home.z)
		if not is_nan(y):
			spawn_mare(Vector3(data.home.x, y + 0.05, data.home.z), data.home_yaw)


## Feyre coming home from away: from the second step, the mare trots out to meet her.
func _meet(p: Node3D, far: float) -> void:
	if MareBond.tier() < 2 or mare.state != MareMount.State.STANDING or block_reason(p.global_position) != &"":
		return
	if mare.global_position.distance_to(data.home) > 30.0:
		_met = true  # she isn't at home: nothing to meet from
		return
	if far < MEET_NEAR or far > minf(MareBond.hear_range(), HOME_RADIUS):
		return
	_met = true
	_away = false
	mare.call_to(p.global_position + _side_of(p) * 2.2, p, MEET_PACE)
	mare.nicker()


## "E   ride": said by the one use prompt while she stands by the mare.
func _update_prompt(p: Node3D) -> void:
	if mare == null or not is_instance_valid(mare):
		return
	var d := Vector2(mare.global_position.x - p.global_position.x, mare.global_position.z - p.global_position.z).length()
	var on := d <= PROMPT_RADIUS and mare.state == MareMount.State.STANDING and not riding and not tending
	UsePrompt.of(get_tree()).offer(self, "ride" if on else "")
	# Her own key, named beside the ride prompt until she's used it (KeyHints).
	KeyHints.of(get_tree()).hold(self, &"tend" if on and unlocked() else &"")