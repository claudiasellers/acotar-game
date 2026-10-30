## The ride north and the wall crossing, ch5 (Keeper's chapter spine).
##
## Straight after the claim: Feyre rides the beast's white horse through the
## woods along the ride line (the world lane's WallSeamPath, or this space's
## RidePath child). She can only look. She smells metal (magic, under the
## glamour) and falls into an enchanted sleep; she wakes as they pass through
## a gate at the seam, into spring: the cold-to-spring grade swap (2 s, the
## single most important visual beat) and wall_crossed. Past the seam the
## horse's road fades out and in again at the manor's sentry gate (canon: she
## arrives at the manor), and they ride up the drive to where the house first
## shows (ManorSitePlan.SPAWN) before she gets down. Without a manor_estate
## region (greybox, tests) she gets down at the end of the path.
class_name RideNorth
extends SceneSpace

const GROUP := &"ride_north"
const MANOR := &"manor_estate"
## Just inside the sentry gate, on the drive, and how long to wait in the dark
## for the estate to stream in.
const GATE_INSIDE := 8.0
const LOAD_WAIT_SECONDS := 20.0

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
var _rider: Node3D


func _init() -> void:
	space_id = &"ride_north"
	require_flags = PackedStringArray(["beast_claim_accepted"])
	done_flags = PackedStringArray(["wall_crossed"])
	auto_start = true
	add_to_group(GROUP)


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
	return [
		Beats.run(_mount, "mount"),
		Beats.cue(&"tamlin_beast", &"lead"),
		Beats.control(StoryControl.Mode.LOOK, null),
		RideBeat.new(func() -> float: return seam_at() * sleep_at),
		Beats.cue(&"feyre", &"smell_metal"),
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
		Beats.cue(&"tamlin_beast", &"leave"),
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
			WorldStreamer.update_for(path.global_transform * path.curve.get_point_position(0))
			# Game time (physics frames), not wall time: fixed-fps runs go faster.
			deadline[0] = Engine.get_physics_frames() + LOAD_WAIT_SECONDS * Engine.physics_ticks_per_second, "the sentry gate"),
		Beats.until(func() -> bool:
			return (WorldStreamer.is_loaded(MANOR) and _ground_under(_rider)) \
					or Engine.get_physics_frames() > deadline[0], "until the estate is there"),
		Beats.run(func(_s: SceneSpace) -> void: _fade(0.0), "fade in"),
		RideBeat.new(func() -> float: return path_length()),
	]


## The drive from just inside the sentry gate to where the house first shows,
## on the estate's ground. Added under this space.
func drive_path() -> Path3D:
	var drive := get_node_or_null(^"Drive") as Path3D
	if drive == null:
		drive = Path3D.new()
		drive.name = "Drive"
		add_child(drive)
		drive.global_transform = Transform3D.IDENTITY
	var curve := Curve3D.new()
	var from := ManorSitePlan.SENTRY_GATE + Vector2(0.0, -GATE_INSIDE)
	var to := Vector2(ManorSitePlan.SPAWN.x, ManorSitePlan.SPAWN.z)
	var steps := maxi(2, ceili(from.distance_to(to) / 8.0))
	for i in steps + 1:
		var p := from.lerp(to, float(i) / steps)
		curve.add_point(Vector3(p.x, WorldHeight.height_at(p.x, p.y), p.y))
	drive.curve = curve
	return drive


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
		layer.layer = 30
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
	_rider = player()
	if _rider:
		_rider.set_physics_process(false)
	horse = request_actor(&"white_horse", _pose_at(0.0), StandIns.horse)


func _dismount(_space: SceneSpace) -> void:
	if _rider and is_instance_valid(_rider):
		if _rider is CharacterBody3D:
			(_rider as CharacterBody3D).velocity = Vector3.ZERO
		_rider.global_position += _rider.global_basis.x * 1.2
		_rider.set_physics_process(true)


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


func _place(offset: float) -> void:
	var pose := _pose_at(offset)
	if horse and is_instance_valid(horse):
		horse.global_transform = pose
	if _rider and is_instance_valid(_rider):
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
		return ride.progress >= stop
