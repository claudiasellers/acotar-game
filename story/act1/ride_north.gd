## The ride north and the wall crossing, ch5 (Keeper's chapter spine).
##
## Straight after the claim: the cottage fades out and in again on the white
## horse at the start of the ride line (the world lane's WallSeamPath, or this
## space's RidePath child), the beast just ahead of her. He leads all the way
## (escort). She can only look. She smells metal (magic, under the glamour; her
## thought H1_metal) and falls into an enchanted sleep; she wakes as they pass
## through a gate at the seam, into spring: the cold-to-spring grade swap (2 s,
## the single most important visual beat) and wall_crossed. Past the seam the
## horse's road fades out and in again at the manor's sentry gate (canon: she
## arrives at the manor), and they ride up the drive, round the fountain on the
## forecourt's gravel ring, to the front steps. She gets down there, inside
## ManorArrival's door radius, and the beast waits on the steps to lead her in.
## Without a manor_estate region (greybox, tests) she gets down at the end of
## the path.
class_name RideNorth
extends SceneSpace

const GROUP := &"ride_north"
const MANOR := &"manor_estate"
## Just inside the sentry gate, on the drive, and how long to wait in the dark
## for the estate to stream in.
const GATE_INSIDE := 8.0
const LOAD_WAIT_SECONDS := 45.0
## Metres ahead of the horse, along the ride, that the beast keeps.
const LEAD_AHEAD := 4.5
## He runs this much faster than the horse, so he always holds his place.
const LEAD_SPEED_GAIN := 1.2
## The drive rounds the fountain on the forecourt's gravel ring (ManorFrontGarden:
## turf to 15 m, gravel to 25 m) and stops in front of the steps with the
## saddle just outside ManorArrival's door radius, facing along the facade, so
## she gets down (Saddle side, toward the door) inside it and the doors open.
const STOP_OUT := ManorArrival.DOOR_RADIUS + 0.3
const STOP_X := -1.0
## Where the beast waits for her, on the steps: ManorArrival's "beast_steps" mark.
const BEAST_STEPS_OUT := 2.5

@export var ride_speed: float = 6.0
## Metres along the path where the wall is. Negative: use a "Seam" child
## Marker3D, or the middle of the path.
@export var seam_offset: float = -1.0
@export var grade_seconds: float = 2.0
## Fraction of the way to the seam where the magic sleep takes her.
@export var sleep_at: float = 0.45
@export var fade_seconds: float = 1.2

var veil: ColorRect

var path: Path3D
var horse: Node3D
var progress: float = 0.0
var beast: Node3D
var _rider: Node3D
var _beast_walk: float = -1.0


func _init() -> void:
	space_id = &"ride_north"
	require_flags = PackedStringArray(["beast_claim_accepted"])
	done_flags = PackedStringArray(["wall_crossed"])
	auto_start = true
	add_to_group(GROUP)


func _ready() -> void:
	super._ready()
	# Camera and lens for the ride, camera only (lane L22, story/staging/).
	add_child(RideNorthStaging.new())


func path_length() -> float:
	return path.curve.get_baked_length() if path and path.curve else 0.0


func seam_at() -> float:
	if seam_offset >= 0.0:
		return seam_offset
	var seam := get_node_or_null(^"Seam") as Node3D
	if seam and path and path.curve:
		return path.curve.get_closest_offset(path.to_local(seam.global_position))
	return path_length() * 0.5


func _build_beats() -> Array:
	path = _find_path()
	progress = 0.0
	var deadline := [0.0]
	return [
		# From the broken cottage door to the horse, through the dark.
		Beats.control(StoryControl.Mode.NONE, null),
		Beats.run(func(_s: SceneSpace) -> void: _fade(1.0), "fade out"),
		Beats.wait(fade_seconds),
		Beats.run(func(s: SceneSpace) -> void:
			_mount(s)
			WorldStreamer.update_for(_pose_at(0.0).origin)
			deadline[0] = Engine.get_physics_frames() + LOAD_WAIT_SECONDS * Engine.physics_ticks_per_second, "mount"),
		# Only where a streamed region holds the road (none in a greybox or a test).
		Beats.until(func() -> bool:
			return WorldStreamer.region_at(_pose_at(0.0).origin) == null or _ground_under(_rider) \
					or Engine.get_physics_frames() > deadline[0], "until the road is there"),
		Beats.run(func(_s: SceneSpace) -> void: _fade(0.0), "fade in"),
		# The opening shot (staging) is cut once the dark has begun to lift.
		Beats.wait(fade_seconds * 0.25),
		Beats.cue(&"tamlin_beast", &"lead"),
		Beats.control(StoryControl.Mode.LOOK, null),
		RideBeat.new(func() -> float: return seam_at() * sleep_at),
		Beats.cue(&"feyre", &"smell_metal"),
		Beats.run(func(_s: SceneSpace) -> void:
			var d := DialogueDirector.of(get_tree())
			if d:
				d.say_beat(space_id, &"smell_metal"), "the air tastes like metal"),
		Beats.mood(&"enchanted_sleep", 1.0, 2.5),
		Beats.control(StoryControl.Mode.NONE, null),
		RideBeat.new(func() -> float: return seam_at()),
		Beats.run(func(_s: SceneSpace) -> void:
			EventBus.grade_swap_requested.emit(&"spring", grade_seconds)
			EventBus.mood_requested.emit(&"calm", 0.0, grade_seconds), "she wakes at the gate"),
		Beats.control(StoryControl.Mode.LOOK, null),
		Beats.raise("wall_crossed"),
		RideBeat.new(func() -> float: return path_length()),
	] + _to_the_manor() + [
		Beats.run(_dismount, "dismount"),
	]


## Fade, move horse and rider to the sentry gate, wait for the estate's ground,
## fade in, ride up the drive. Nothing when there's no manor region.
func _to_the_manor() -> Array:
	if WorldStreamer.get_region(MANOR) == null:
		return []
	var deadline := [0.0]
	return [
		Beats.run(func(_s: SceneSpace) -> void: _fade(1.0), "fade out"),
		Beats.wait(fade_seconds),
		Beats.run(func(_s: SceneSpace) -> void:
			path = drive_path()
			progress = 0.0
			_place(0.0)
			_place_beast()
			# Spring was the crossing's; on the estate the manor grade takes over.
			GradeDirector.release_story_holds(get_tree())
			WorldStreamer.update_for(path.global_transform * path.curve.get_point_position(0))
			# Game time (physics frames), not wall time: fixed-fps runs go faster.
			deadline[0] = Engine.get_physics_frames() + LOAD_WAIT_SECONDS * Engine.physics_ticks_per_second, "the sentry gate"),
		Beats.until(func() -> bool:
			return (WorldStreamer.is_ready(MANOR) and _ground_under(_rider)) \
					or Engine.get_physics_frames() > deadline[0], "until the estate is there"),
		Beats.run(func(_s: SceneSpace) -> void: _fade(0.0), "fade in"),
		RideBeat.new(func() -> float: return path_length()),
	]


## The drive from just inside the sentry gate up to the forecourt, round the
## fountain's east side on the gravel ring, to the front steps (see STOP_OUT),
## on the estate's ground. Added under this space.
func drive_path() -> Path3D:
	var drive := get_node_or_null(^"Drive") as Path3D
	if drive == null:
		drive = Path3D.new()
		drive.name = "Drive"
		add_child(drive)
		drive.global_transform = Transform3D.IDENTITY
	var curve := Curve3D.new()
	var centre := ManorSitePlan.FORECOURT_CENTER
	var ring := centre.distance_to(Vector2(ManorSitePlan.FRONT_DOOR.x, ManorSitePlan.FRONT_DOOR.z)) - STOP_OUT
	var from := ManorSitePlan.SENTRY_GATE + Vector2(0.0, -GATE_INSIDE)
	var onto := centre + Vector2(0.0, ring)
	var points: Array[Vector2] = []
	var steps := maxi(2, ceili(from.distance_to(onto) / 8.0))
	for i in steps:
		points.append(from.lerp(onto, float(i) / steps))
	# Anticlockwise from above: south, east, then north to just past the door.
	var end := PI + asin(clampf(-STOP_X / ring, -1.0, 1.0))
	var arc := maxi(4, ceili(ring * end / 4.0))
	for i in arc + 1:
		var a := end * float(i) / arc
		points.append(centre + Vector2(sin(a), cos(a)) * ring)
	for p in points:
		curve.add_point(Vector3(p.x, WorldHeight.height_at(p.x, p.y), p.y))
	drive.curve = curve
	return drive


## Where the beast waits on the front steps (ManorArrival's "beast_steps").
static func beast_steps() -> Vector3:
	var at := ManorSitePlan.FRONT_DOOR + Vector3(0.0, 0.0, BEAST_STEPS_OUT)
	at.y = WorldHeight.height_at(at.x, at.z)
	return at


func _ground_under(node: Node3D) -> bool:
	if node == null or not is_instance_valid(node):
		return true
	var from := node.global_position + Vector3.UP
	return not node.get_world_3d().direct_space_state.intersect_ray(
			PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 6.0, 1)).is_empty()


func _fade(alpha: float) -> void:
	if veil == null or not is_instance_valid(veil):
		var layer := CanvasLayer.new()
		layer.name = "RideVeil"
		layer.layer = UiLayers.VEIL
		veil = ColorRect.new()
		veil.color = Color(0.03, 0.02, 0.05)
		veil.set_anchors_preset(Control.PRESET_FULL_RECT)
		veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
		veil.modulate.a = 0.0
		layer.add_child(veil)
		add_child(layer)
	var tween := veil.create_tween()
	tween.tween_property(veil, ^"modulate:a", alpha, fade_seconds)
	if alpha == 0.0:
		tween.tween_callback(veil.get_parent().queue_free)


func _find_path() -> Path3D:
	var world_path := get_tree().get_first_node_in_group(&"wall_seam_path") as Path3D
	if world_path:
		return world_path
	var named := get_tree().root.find_child("WallSeamPath", true, false) as Path3D
	if named:
		return named
	return get_node_or_null(^"RidePath") as Path3D


func _mount(_space: SceneSpace) -> void:
	# The manor is where the ride ends: it streams in while she rides, not
	# when she reaches its gate beside a neighbour still building.
	if WorldStreamer.get_region(MANOR):
		WorldStreamer.hold(MANOR)
	_rider = player()
	if _rider:
		_rider.set_physics_process(false)
	horse = request_actor(&"white_horse", _pose_at(0.0), StandIns.horse)
	# Seated astride, as on the mount (L47): legs on the barrel, hands on the reins.
	if _rider and horse is WhiteHorse:
		Saddle.seat(_rider)
	_place(0.0)
	# He leads from just ahead, not from the cottage he broke into.
	beast = request_actor(&"tamlin_beast", _pose_at(LEAD_AHEAD), StandIns.beast)
	if beast is BeastActor:
		var actor := beast as BeastActor
		# The cottage is behind them: nothing sends him back to its latch.
		actor.door = null
		_beast_walk = actor.walk_speed
		actor.walk_speed = ride_speed * LEAD_SPEED_GAIN
	_place_beast()


func _dismount(_space: SceneSpace) -> void:
	WorldStreamer.let_go(MANOR)
	if _rider and is_instance_valid(_rider):
		if _rider is CharacterBody3D:
			(_rider as CharacterBody3D).velocity = Vector3.ZERO
		var seated := _rider.has_meta(Saddle.HIP_DROP)
		Saddle.unseat(_rider)
		_rider.global_position += _rider.global_basis.x * 1.2
		if seated and horse and is_instance_valid(horse):
			_rider.global_position.y = horse.global_position.y + 0.1
		_rider.set_physics_process(true)
	# He goes on up to the steps and waits there to lead her in (ManorArrival).
	if beast is BeastActor and is_instance_valid(beast):
		var actor := beast as BeastActor
		if _beast_walk > 0.0:
			actor.walk_speed = _beast_walk
		actor.lead(beast_steps() if WorldStreamer.get_region(MANOR) else actor.global_position)


## World transform `offset` metres along the ride line, facing along it.
func _pose_at(offset: float) -> Transform3D:
	if path == null or path.curve == null or path.curve.point_count < 2:
		return global_transform
	var local := path.curve.sample_baked(offset, true)
	var ahead := path.curve.sample_baked(minf(offset + 1.0, path_length()), true)
	var origin := path.global_transform * local
	var target := path.global_transform * ahead
	var xform := Transform3D(Basis.IDENTITY, origin)
	if not origin.is_equal_approx(target):
		xform = xform.looking_at(Vector3(target.x, origin.y, target.z), Vector3.UP)
	return xform


## Straight onto his place ahead of the horse (after a cut).
func _place_beast() -> void:
	if beast and is_instance_valid(beast):
		beast.global_transform = _pose_at(minf(progress + LEAD_AHEAD, path_length()))
		_escort()


## Keeps him LEAD_AHEAD metres on along the ride; past the drive's end, on
## the steps.
func _escort() -> void:
	if beast == null or not is_instance_valid(beast):
		return
	var ahead := progress + LEAD_AHEAD
	var pose := _pose_at(minf(ahead, path_length()))
	if not (beast is BeastActor):
		beast.global_transform = pose
		return
	var to := pose.origin
	if ahead > path_length():
		# Past the end he keeps ahead of the horse, never under it: on the
		# manor steps, or on along the line's last heading.
		var heading := pose.origin - _pose_at(maxf(path_length() - 1.0, 0.0)).origin
		heading.y = 0.0
		to = beast_steps() if path and path.name == "Drive" \
				else pose.origin + heading.normalized() * (ahead - path_length())
	(beast as BeastActor).lead(to)


func _place(offset: float) -> void:
	var pose := _pose_at(offset)
	if horse and is_instance_valid(horse):
		horse.global_transform = pose
	if _rider and is_instance_valid(_rider):
		if horse is WhiteHorse and _rider.has_meta(Saddle.HIP_DROP):
			Saddle.place(_rider, horse as WhiteHorse)
		else:
			_rider.global_position = pose.origin + Vector3.UP * 1.1


## Rides forward at ride_speed until the offset `until` returns.
class RideBeat:
	extends SceneBeat
	var until: Callable

	func consumes_time() -> bool:
		return true

	func _init(u: Callable) -> void:
		until = u
		label = "ride"

	func tick(space: SceneSpace, delta: float) -> bool:
		var ride := space as RideNorth
		var stop := float(until.call())
		ride.progress = minf(ride.progress + ride.ride_speed * delta, stop)
		ride._place(ride.progress)
		ride._escort()
		return ride.progress >= stop
