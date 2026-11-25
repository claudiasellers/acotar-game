## Feyre's third-person camera, kept apart from the controller (T100): the
## rig (CameraRig > pitch > spring arm > Camera3D under her, top level), look
## input, R recentre, follow-behind, story focus drift, and the indoor rules
## that keep the lens in her room, under the beams and off the walls.
##
## Feyre owns it and calls `update()` once per _process after placing the rig
## at her head and reading look input; the rig nodes stay her children, so the
## node layout is what it was before the split. Her public camera API
## (camera_yaw, recenter_camera, room_clearance, ...) forwards here.
class_name FeyreCamera
extends RefCounted

## Metres the arm sits over her right shoulder while she aims, or while a
## scene's focus is at least FAR_FOCUS metres off outdoors.
const AIM_SHOULDER := 0.55
## The same with the bow up and no aim held: the arm is long there, so she is
## moved farther aside and the crosshair and a low target in front of her
## stand clear of her body (HIP_RING_CLEAR_PX in the framing test).
const HIP_SHOULDER := 0.85
## While the bow comes up, is up, and for this long after (real seconds), a
## change of shoulder turns the camera so the middle of the screen stays on
## the same thing in the world: raising the bow never moves her aim.
const AIM_KEEP_S := 0.6
## The nearest (m) that thing is taken to be, so a wall at the lens can't swing the view.
const AIM_KEEP_NEAR := 4.0
const FAR_FOCUS := 12.0
const DEFAULT_PITCH := -0.2094  # -12 degrees
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
## The lens is a ball this wide (m) to the walls (T094): the spring arm sweeps a
## sphere, not a ray, so a wall running beside the arm keeps it this far off, and
## the shoulder offset is swept out from the pivot first, so it never pushes the
## arm's start into or through a wall beside her.
const LENS_RADIUS := 0.2
## How far up (m) a roof still counts as "indoors".
const INDOOR_PROBE := 9.0

var rig: Node3D
var camera: Camera3D
## 0 outdoors .. 1 indoors, eased so doorways don't pop the camera.
var indoor: float = 0.0

var _feyre: Feyre
var _camera_pitch: Node3D
var _spring_arm: SpringArm3D
var _recentering: bool = false
## Highest the camera may sit above its pivot right now (m).
var _indoor_rise: float = INDOOR_RISE
## Arm length the room allows, eased; see room_clearance.
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
## The bow's release kick: degrees of pitch at its peak, real seconds since it
## began (negative when idle), and its rise and fall times.
var _kick_peak: float = 0.0
var _kick_t: float = -1.0
var _kick_rise: float = 0.06
var _kick_fall: float = 0.15
## Real seconds left of AIM_KEEP_S.
var _aim_keep: float = 0.0


## Builds the rig under `feyre` (as her child, named CameraRig).
func _init(feyre: Feyre) -> void:
	_feyre = feyre
	rig = Node3D.new()
	rig.name = "CameraRig"
	rig.top_level = true
	feyre.add_child(rig)
	_camera_pitch = Node3D.new()
	_camera_pitch.rotation.x = DEFAULT_PITCH
	rig.add_child(_camera_pitch)
	_spring_arm = SpringArm3D.new()
	_spring_arm.spring_length = 3.6
	_spring_arm.collision_mask = Feyre.WORLD_MASK
	_spring_arm.margin = 0.2
	var lens := SphereShape3D.new()
	lens.radius = LENS_RADIUS
	_spring_arm.shape = lens
	_spring_arm.add_excluded_object(feyre.get_rid())
	_camera_pitch.add_child(_spring_arm)
	camera = Camera3D.new()
	camera.fov = 70.0
	camera.far = 2000.0
	camera.current = true
	_spring_arm.add_child(camera)
	rig.global_position = feyre.global_position + Vector3.UP * (1.5 + feyre.camera_lift)


## The per-frame camera work, after the rig is at her head and look input is in.
func update(delta: float) -> void:
	var f := _feyre
	_since_look = 0.0 if f.look_input_this_frame else _since_look + delta
	_update_recenter(delta)
	_follow_behind(delta)
	_drift_toward_focus(delta)
	var shake := StoryControl.shake * (0.0 if GameSettings.reduced_effects else 1.0)
	camera.h_offset = randf_range(-0.04, 0.04) * shake
	camera.v_offset = randf_range(-0.03, 0.03) * shake
	_update_kick(delta)
	_update_indoor(delta)
	# Aim held brings the lens in over her shoulder; a draw from the hip only
	# moves her off the middle of the frame, so the arrow's line is clear.
	var bow_up := f.bow_controller != null and f.bow_controller.is_up()
	var precise := f.bow_controller != null and f.bow_controller.is_precise
	var target_length := 1.7 if precise else lerpf(3.6 + f.camera_arm_extra, INDOOR_ARM, indoor)
	# A hostile after her and close: a step back, so she sees what is coming.
	if f.is_inside_tree() and SoftAim.engaged_near(f.get_tree(), f.global_position):
		target_length += SoftAim.PULL_BACK
	_update_room_arm(delta, target_length)
	target_length = minf(target_length, _room_arm)
	# The arm and the shoulder ease on real seconds, so the aim framing
	# arrives as fast inside the Focus hush as outside it.
	var ease := minf(10.0 * TimeScale.real(delta), 1.0)
	_spring_arm.spring_length = lerpf(_spring_arm.spring_length, target_length, ease)
	_clamp_indoor_pitch()
	var shoulder := close_shoulder(_spring_arm.spring_length)
	if precise or _far_focus():
		shoulder = AIM_SHOULDER
	elif bow_up:
		# Scaled to the arm: indoors, on a short arm, the hip offset shrinks to the aim's.
		shoulder = lerpf(AIM_SHOULDER, HIP_SHOULDER, clampf(inverse_lerp(1.7, 3.6, _spring_arm.spring_length), 0.0, 1.0))
	var side := minf(lerpf(_spring_arm.position.x, shoulder, ease), shoulder_clearance(shoulder))
	_aim_keep = AIM_KEEP_S if bow_up else maxf(_aim_keep - TimeScale.real(delta), 0.0)
	if _aim_keep > 0.0:
		_shift_keeping_aim(side)
	else:
		_spring_arm.position.x = side


## Moves the arm to `side` metres over her shoulder and turns the camera so
## its centre line still passes through what it was on. A longer or shorter
## arm slides the lens along that line and needs no turn.
func _shift_keeping_aim(side: float) -> void:
	if is_equal_approx(side, _spring_arm.position.x):
		return
	var from := camera.global_position
	var forward := -camera.global_basis.z
	var on := from + forward * maxf(from.distance_to(aim_point()), AIM_KEEP_NEAR)
	_spring_arm.position.x = side
	# Twice: the turn is about her head, not the lens, so one pass leaves a hair.
	for i in 2:
		var to := on - camera.global_position
		var now := -camera.global_basis.z
		nudge(angle_difference(atan2(-now.x, -now.z), atan2(-to.x, -to.z)), 0.0)


## The bow's release kick: the lens tips up `degrees` over `rise` seconds and
## eases back over `fall`. The aim itself (yaw, pitch) is untouched. Off under
## Reduced Effects.
func kick(degrees: float, rise: float, fall: float) -> void:
	if GameSettings.reduced_effects or degrees <= 0.0:
		return
	_kick_peak = degrees
	_kick_rise = maxf(rise, 0.001)
	_kick_fall = maxf(fall, 0.001)
	_kick_t = 0.0


func _update_kick(delta: float) -> void:
	if _kick_t < 0.0:
		return
	# Real time: a kick in the Focus hush is as quick as any other.
	_kick_t += TimeScale.real(delta)
	var amount := 0.0
	if _kick_t < _kick_rise:
		amount = _kick_t / _kick_rise
	elif _kick_t < _kick_rise + _kick_fall:
		amount = 1.0 - ease((_kick_t - _kick_rise) / _kick_fall, 0.5)
	else:
		_kick_t = -1.0
	camera.rotation.x = deg_to_rad(_kick_peak) * amount


## Eases the camera toward behind her, turning at most `max_turn` radians
## (R / right stick click caps it; teleports recentre fully).
func recenter(max_turn: float = PI) -> void:
	var yaw := rig.rotation.y
	var turn := clampf(angle_difference(yaw, _feyre.model.rotation.y), -max_turn, max_turn)
	_recenter_from = Vector2(yaw, _camera_pitch.rotation.x)
	_recenter_to = Vector2(yaw + turn, DEFAULT_PITCH)
	_recenter_t = 0.0
	_recentering = true


## Brings the rig with her after a teleport and drops what the old room left
## behind (arm length, furniture exclusions).
func snap_to(pos: Vector3) -> void:
	rig.global_position = pos + Vector3.UP * (1.5 + _feyre.camera_lift)
	_room_arm = 3.6
	if _spring_arm:
		for rid in _cam_skip:
			_spring_arm.remove_excluded_object(rid)
	_cam_skip.clear()


func yaw() -> float:
	return rig.rotation.y


func pitch() -> float:
	return _camera_pitch.rotation.x


## Small camera turn from gameplay (notice moments), in radians.
func nudge(yaw_delta: float, pitch_delta: float) -> void:
	_feyre.camera_auto_yaw += yaw_delta
	_rotate(yaw_delta, pitch_delta)


## Player look input (already scaled); applies the invert settings.
func look(x: float, y: float) -> void:
	var yaw_delta := x * (1.0 if GameSettings.invert_x else -1.0)
	_rotate(yaw_delta, y * (1.0 if GameSettings.invert_y else -1.0))
	if not GameSettings.mouse_steers:
		_feyre.camera_look_yaw += yaw_delta
	_feyre.look_input_this_frame = true
	_recentering = false


## The point in the world under the middle of the screen. A creature the
## centre line passes within Arrow.CATCH_RADIUS of, in front of whatever the
## line itself meets, is what it is on: the arrow would strike it.
func aim_point(max_distance: float = 250.0) -> Vector3:
	var from := camera.global_position
	var to := from - camera.global_basis.z * max_distance
	var skip: Array[RID] = [_feyre.get_rid()]
	var space := _feyre.get_world_3d().direct_space_state
	var result := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, Feyre.WORLD_MASK | Arrow.MASK_TARGETS, skip))
	var body := result.get("collider") as CollisionObject3D
	if body != null and body.collision_layer & Arrow.MASK_TARGETS != 0:
		return result.position
	if result:
		to = result.position
	# From her, not from the lens: nothing beside or behind her is aimed at.
	var start := from + (to - from).normalized() * minf(_spring_arm.spring_length, from.distance_to(to))
	var caught := Arrow.catch_creature(space, start, to, skip)
	return caught.position if caught else to


## True under a roof or in a manor room: BowVisual stows the slung bow.
func is_indoors() -> bool:
	return indoor > 0.5


## Over-the-shoulder offset (m) when a small room holds the arm short: none at
## CLOSE_FROM and longer, CLOSE_SHOULDER at ROOM_MIN_ARM, so she sits off-centre
## instead of filling the middle of the frame.
static func close_shoulder(arm: float) -> float:
	return CLOSE_SHOULDER * clampf((CLOSE_FROM - arm) / (CLOSE_FROM - ROOM_MIN_ARM), 0.0, 1.0)


## How far (m, up to `want`) the arm's start can sit to her right of the pivot with
## the lens ball clear of walls: a sphere swept out from the pivot. Pulling in is
## instant (the caller takes the minimum), so no frame peeks past a wall.
func shoulder_clearance(want: float) -> float:
	if want <= 0.0:
		return 0.0
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _spring_arm.shape
	query.transform = Transform3D(Basis(), _camera_pitch.global_position)
	query.motion = _camera_pitch.global_basis.x * want
	query.collision_mask = _spring_arm.collision_mask
	var skip: Array[RID] = [_feyre.get_rid()]
	skip.append_array(_cam_skip)
	query.exclude = skip
	var safe := _feyre.get_world_3d().direct_space_state.cast_motion(query)
	return want * safe[0]


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


## Camera height above its pivot (m), for tests and tools.
func rise() -> float:
	return camera.global_position.y - rig.global_position.y


## A camera turn the player didn't make: it doesn't steer her (SteerFrame).
func _auto_turn(new_yaw: float) -> void:
	_feyre.camera_auto_yaw += angle_difference(rig.rotation.y, new_yaw)
	rig.rotation.y = new_yaw


## Outdoors, a scene's focus this far off (the doe across the clearing) sits on
## the horizon straight behind her head from a centred camera: the camera
## takes the aim's shoulder so what her eye has found is beside her, in view.
func _far_focus() -> bool:
	var focus := StoryControl.focus
	return focus != null and is_instance_valid(focus) and indoor < 0.5 \
			and focus.global_position.distance_to(rig.global_position) >= FAR_FOCUS


## During anchored moments the camera eases toward what the scene is about.
func _drift_toward_focus(delta: float) -> void:
	var focus := StoryControl.focus
	if focus == null or not is_instance_valid(focus):
		return
	# With the bow up the aim is hers alone.
	if _feyre.bow_controller != null and _feyre.bow_controller.is_up():
		return
	var to := focus.global_position - rig.global_position
	if Vector2(to.x, to.z).length() < 0.5:
		return
	var yaw_to := atan2(-to.x, -to.z)
	_auto_turn(lerp_angle(rig.rotation.y, yaw_to, 1.6 * delta))


func _update_recenter(delta: float) -> void:
	if not _recentering:
		return
	_recenter_t = minf(_recenter_t + delta / maxf(_feyre.recenter_time, 0.01), 1.0)
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
	var f := _feyre
	if not GameSettings.camera_follow or not f.is_running() or _since_look < f.follow_delay \
			or StoryControl.focus != null or not f.steer_frame.is_held():
		return
	_auto_turn(lerp_angle(rig.rotation.y, f.steer_frame.held_yaw(),
			f.follow_speed * (1.0 - indoor) * delta))


## Is there a roof over her? Reads the ceiling height straight above the camera
## pivot; manor rooms count whether or not a collider roofs them (ManorIndoors).
func _update_indoor(delta: float) -> void:
	var from := rig.global_position
	var hit := _feyre.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(
			from, from + Vector3.UP * INDOOR_PROBE, Feyre.WORLD_MASK, [_feyre.get_rid()]))
	var roofed := not hit.is_empty()
	var ceiling: float = (hit.position as Vector3).y if roofed else ManorIndoors.ceiling_over(_feyre.get_tree(), from)
	roofed = not is_nan(ceiling)
	if roofed:
		_indoor_rise = clampf(ceiling - from.y - INDOOR_CEILING_GAP, 0.0, INDOOR_RISE)
	indoor = move_toward(indoor, 1.0 if roofed else 0.0, delta / 0.3)


## Indoors: the longest arm (up to `want`) whose view-edge whiskers clear the walls.
## Outdoors (indoor 0) it allows the full arm, as before.
func _update_room_arm(delta: float, want: float) -> void:
	if indoor < 0.5 and not _cam_skip.is_empty():
		for rid in _cam_skip:
			_spring_arm.remove_excluded_object(rid)
		_cam_skip.clear()
	var allowed := want
	if indoor > 0.0:
		_cam_ray(_spring_arm.global_position, _spring_arm.global_position + _spring_arm.global_basis.z * (want + 0.3))
		allowed = lerpf(want, room_clearance(want), indoor)
	var rate := ROOM_PULL_IN if allowed < _room_arm else ROOM_LET_OUT
	_room_arm = lerpf(_room_arm, allowed, minf(1.0, rate * delta))


## Free width (m) at `at` along +/- `side`, each way up to ROOM_REACH.
func _free_width(at: Vector3, side: Vector3) -> float:
	var total := 0.0
	for dir: Vector3 in [side, -side]:
		var hit := _cam_ray(at, at + dir * ROOM_REACH)
		total += ROOM_REACH if hit.is_empty() else at.distance_to(hit.position)
	return total


## A camera ray against the world that, indoors, passes through furniture and adds
## each piece it meets to the spring arm's exclusions.
func _cam_ray(from: Vector3, to: Vector3) -> Dictionary:
	var space := _feyre.get_world_3d().direct_space_state
	for i in 4:
		var skip: Array[RID] = [_feyre.get_rid()]
		skip.append_array(_cam_skip)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, Feyre.WORLD_MASK, skip))
		if hit.is_empty() or indoor < 0.5 or not _is_furniture(hit.collider):
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
	if indoor <= 0.0:
		return
	var arm := maxf(_spring_arm.spring_length, 0.1)
	var limit := -asin(clampf(_indoor_rise / arm, 0.0, 1.0))
	# Eased with indoor: outdoors the usual -70 degree limit applies.
	limit = lerpf(deg_to_rad(-70.0), limit, indoor)
	if _camera_pitch.rotation.x < limit:
		_camera_pitch.rotation.x = limit


func _rotate(yaw_delta: float, pitch_delta: float) -> void:
	rig.rotation.y += yaw_delta
	_camera_pitch.rotation.x = clampf(_camera_pitch.rotation.x + pitch_delta, deg_to_rad(-70.0), deg_to_rad(55.0))
