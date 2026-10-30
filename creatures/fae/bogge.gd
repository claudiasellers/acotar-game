## The Bogge (lore: 04-creatures/bogge.md). Never seen: it becomes real only
## if you acknowledge it. On cue `pass_behind` it moves around Feyre, always
## at her back: wherever the camera turns, it is already behind it. The air
## darkens as it comes and it begs, inside her head, for her to look.
## The story lane's gaze check reads this node's global_position.
class_name Bogge
extends StoryActor

signal begged(line_id: StringName)
signal passed

const BEG_LINES: Array[StringName] = [&"bogge_beg_1", &"bogge_beg_2", &"bogge_beg_3", &"bogge_beg_4"]

@export var distance: float = 4.5
@export var pass_seconds: float = 16.0
@export var beg_interval: float = 3.5
## How far round her back it sweeps during the pass (radians, centred behind).
@export var sweep: float = 1.6

var passing: bool = false
var progress: float = 0.0

var _beg_left: float = 1.5
var _beg_index: int = 0
var _fog: FogVolume


func _ready() -> void:
	if actor_id == &"":
		actor_id = &"bogge"
	super._ready()
	# The Bogge's wood is the darkest place in the court (bible §1.5).
	DreadField.attach(self, 45.0, 14.0)
	_fog = FogVolume.new()
	_fog.name = "Dark"
	_fog.size = Vector3(5, 3, 5)
	var mat := FogMaterial.new()
	mat.density = 0.0
	mat.albedo = Color(0.02, 0.02, 0.03)
	_fog.material = mat
	add_child(_fog)


func play_cue(cue: StringName) -> void:
	if cue == &"pass_behind":
		passing = true
		progress = 0.0


## Where it should be: behind the camera, sweeping from one shoulder to the other.
static func behind(camera_pos: Vector3, camera_forward: Vector3, t: float, dist: float, arc: float) -> Vector3:
	var back := -Vector3(camera_forward.x, 0.0, camera_forward.z)
	if back.length_squared() < 0.0001:
		back = Vector3.BACK
	back = back.normalized().rotated(Vector3.UP, lerpf(-arc * 0.5, arc * 0.5, clampf(t, 0.0, 1.0)))
	return camera_pos + back * dist


func _process(delta: float) -> void:
	if not passing:
		return
	progress += delta / pass_seconds
	var camera := get_viewport().get_camera_3d()
	if camera:
		var target := behind(camera.global_position, -camera.global_basis.z, progress, distance, sweep)
		target.y = camera.global_position.y - 0.4
		# It does not drift: it is simply there, wherever her back is.
		global_position = global_position.lerp(target, clampf(delta * 12.0, 0.0, 1.0))
	var swell := sin(clampf(progress, 0.0, 1.0) * PI)
	(_fog.material as FogMaterial).density = 0.6 * swell
	_beg_left -= delta
	if _beg_left <= 0.0:
		_beg_left = beg_interval
		begged.emit(BEG_LINES[_beg_index % BEG_LINES.size()])
		_beg_index += 1
	if progress >= 1.0:
		passing = false
		(_fog.material as FogMaterial).density = 0.0
		passed.emit()
