## The ride north and the wall crossing (lore: the-wall.md).
##
## Straight after the claim: Feyre rides with the beast along the ride line
## (the world lane's WallSeamPath, or this space's own RidePath child). She
## can only look. At the seam the story asks for the cold-to-spring grade
## swap (2 s, the single most important visual beat) and raises
## wall_crossed. She rides on into the Border Woods and gets down.
class_name RideNorth
extends SceneSpace

@export var ride_speed: float = 6.0
## Metres along the path where the wall is. Negative: use a "Seam" child
## Marker3D, or the middle of the path.
@export var seam_offset: float = -1.0
@export var grade_seconds: float = 2.0

var path: Path3D
var horse: Node3D
var progress: float = 0.0
var _rider: Node3D


func _init() -> void:
	space_id = &"ride_north"
	require_flags = PackedStringArray(["beast_claim_accepted"])
	done_flags = PackedStringArray(["wall_crossed"])
	auto_start = true


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
		RideBeat.new(func() -> float: return seam_at()),
		Beats.run(func(_s: SceneSpace) -> void:
			EventBus.grade_swap_requested.emit(&"spring", grade_seconds), "grade swap"),
		Beats.raise("wall_crossed"),
		RideBeat.new(func() -> float: return path_length()),
		Beats.run(_dismount, "dismount"),
		Beats.cue(&"tamlin_beast", &"leave"),
	]


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
	horse = request_actor(&"horse", _pose_at(0.0), StandIns.horse)


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
