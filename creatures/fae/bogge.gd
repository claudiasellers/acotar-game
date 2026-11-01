## The Bogge (lore: 04-creatures/bogge.md). Never seen: it becomes real only
## if you acknowledge it. It passes at Feyre's back, a creeping, leeching
## cold, and begs inside her head for her to look. Look and it gathers: the
## dark around it thickens and its shape comes out of the fog, a hunched
## thing three metres tall with arms to the ground and a cluster of wet,
## lamp-pale eyes (canon:"X": the book never describes it, which is the point).
##
## Story scenes drive it with public calls (docs/contracts/act2.md):
## pass_behind_frame() sweeps it round her back relative to a fixed "ahead";
## follow_behind() keeps it at her back while she walks; set_reveal() is how
## real it has become; manifest() is the lunge when she has looked too long;
## withdraw() lets it go. The cue `pass_behind` still works on its own (it
## then sits behind the camera, whichever way that turns).
class_name Bogge
extends StoryActor

signal begged(line_id: StringName)
signal passed
signal manifested

const BEG_LINES: Array[StringName] = [&"bogge_beg_1", &"bogge_beg_2", &"bogge_beg_3", &"bogge_beg_4"]
const EYE := Color(0.86, 0.9, 0.62)
const MODEL := "res://creatures/models/fae/bogge.gltf"
const FORM_SHADER := preload("res://creatures/fae/bogge_form.gdshader")

## Far enough behind her that the follow camera is never inside its dark.
@export var distance: float = 7.0
@export var pass_seconds: float = 16.0
@export var beg_interval: float = 3.5
## How far round her back it sweeps during the pass (radians, centred behind).
@export var sweep: float = 1.6

enum Mode { IDLE, CAMERA, FRAME, FOLLOW, LUNGE, GONE }

var mode: Mode = Mode.IDLE
var passing: bool = false
var progress: float = 0.0
## How real it is: 0 unseen (a cold patch of darker air), 1 fully there.
var reveal: float = 0.0

var _beg_left: float = 1.5
var _beg_index: int = 0
var _fog: FogVolume
var _form: Node3D
var _mats: Array[ShaderMaterial] = []
var _anim: AnimationPlayer
var _centre: Vector3
var _ahead: Vector3 = Vector3.FORWARD
var _follow: Node3D
var _lunge_to: Vector3
var _t: float = 0.0


func _ready() -> void:
	if actor_id == &"":
		actor_id = &"bogge"
	super._ready()
	# The Bogge's wood is the darkest place in the court (bible §1.5).
	var field := DreadField.attach(self, 45.0, 14.0)
	# Full dread here takes the wood to black (Mac clip L25-6): she must still
	# see the elm she stares at. Just over 0.5 so the one wrong sound plays.
	field.max_intensity = 0.55
	_fog = FogVolume.new()
	_fog.name = "Dark"
	_fog.size = Vector3(3.5, 3.5, 3.5)
	_fog.position.y = 1.8
	var mat := FogMaterial.new()
	mat.density = 0.0
	mat.albedo = Color(0.02, 0.02, 0.03)
	_fog.material = mat
	add_child(_fog)
	if model == null:
		_form = _build_form()
		add_child(_form)
	else:
		_form = model
	_apply_reveal()


func play_cue(cue: StringName) -> void:
	match cue:
		&"pass_behind":
			mode = Mode.CAMERA
			_start_pass()
		&"withdraw":
			withdraw()


## Where it should be: behind the camera, sweeping from one shoulder to the other.
static func behind(camera_pos: Vector3, camera_forward: Vector3, t: float, dist: float, arc: float) -> Vector3:
	var back := -Vector3(camera_forward.x, 0.0, camera_forward.z)
	if back.length_squared() < 0.0001:
		back = Vector3.BACK
	back = back.normalized().rotated(Vector3.UP, lerpf(-arc * 0.5, arc * 0.5, clampf(t, 0.0, 1.0)))
	return camera_pos + back * dist


## Sweeps round behind `centre` relative to a fixed `ahead` (what Lucien told
## her to stare at), so turning round finds it.
func pass_behind_frame(centre: Vector3, ahead: Vector3, seconds: float) -> void:
	_centre = centre
	_ahead = Vector3(ahead.x, 0.0, ahead.z).normalized() if Vector2(ahead.x, ahead.z).length() > 0.001 else Vector3.FORWARD
	pass_seconds = seconds
	mode = Mode.FRAME
	_start_pass()
	global_position = behind(centre, _ahead, 0.0, distance, sweep)


## Keeps at `target`'s back (relative to `ahead`) while she walks away.
func follow_behind(target: Node3D, ahead: Vector3) -> void:
	_follow = target
	_ahead = Vector3(ahead.x, 0.0, ahead.z).normalized()
	mode = Mode.FOLLOW
	passing = true


## It has been looked at too long: it is real, and it comes.
func manifest(at: Vector3) -> void:
	_lunge_to = at
	mode = Mode.LUNGE
	set_reveal(1.0)
	if _anim and _anim.has_animation(&"lunge"):
		_anim.play(&"lunge")
	manifested.emit()


func withdraw() -> void:
	mode = Mode.GONE
	passing = false


func set_reveal(amount: float) -> void:
	reveal = clampf(amount, 0.0, 1.0)
	_apply_reveal()


func fog_density() -> float:
	return (_fog.material as FogMaterial).density if _fog else 0.0


func _start_pass() -> void:
	passing = true
	progress = 0.0
	_beg_left = 1.5
	visible = true


func _process(delta: float) -> void:
	_t += delta
	match mode:
		Mode.IDLE:
			return
		Mode.CAMERA:
			var camera := get_viewport().get_camera_3d()
			if camera:
				var target := behind(camera.global_position, -camera.global_basis.z, progress, distance, sweep)
				target.y = camera.global_position.y - 0.4
				# It does not drift: it is simply there, wherever her back is.
				global_position = global_position.lerp(target, clampf(delta * 12.0, 0.0, 1.0))
			_advance_pass(delta)
		Mode.FRAME:
			var target := behind(_centre, _ahead, progress, distance, sweep)
			global_position = global_position.lerp(target, clampf(delta * 4.0, 0.0, 1.0))
			_face(_centre)
			_advance_pass(delta)
		Mode.FOLLOW:
			if _follow and is_instance_valid(_follow):
				var target := _follow.global_position - _ahead * distance
				global_position = global_position.lerp(target, clampf(delta * 2.5, 0.0, 1.0))
				_face(_follow.global_position)
			_beg(delta)
		Mode.LUNGE:
			global_position = global_position.lerp(_lunge_to, clampf(delta * 9.0, 0.0, 1.0))
		Mode.GONE:
			set_reveal(move_toward(reveal, 0.0, delta))
			var mat := _fog.material as FogMaterial
			mat.density = move_toward(mat.density, 0.0, delta * 0.4)
			if reveal <= 0.0 and mat.density <= 0.0:
				visible = false
				mode = Mode.IDLE
			return
	# The dark always hangs round it; the more real it is, the thicker.
	var swell := sin(clampf(progress, 0.0, 1.0) * PI) if mode != Mode.FOLLOW else 0.6
	(_fog.material as FogMaterial).density = 0.35 * swell + 1.6 * reveal
	# It breathes: too slow, too deep.
	if _form:
		var breath := 1.0 + sin(_t * 1.3) * 0.03 * (0.4 + reveal)
		_form.scale = Vector3(1.0 / sqrt(breath), breath, 1.0 / sqrt(breath))


func _advance_pass(delta: float) -> void:
	if not passing:
		return
	progress += delta / maxf(pass_seconds, 0.01)
	_beg(delta)
	if progress >= 1.0:
		passing = false
		progress = 1.0
		passed.emit()


func _beg(delta: float) -> void:
	_beg_left -= delta
	if _beg_left <= 0.0:
		_beg_left = beg_interval
		begged.emit(BEG_LINES[_beg_index % BEG_LINES.size()])
		_beg_index += 1


func _face(point: Vector3) -> void:
	var to := point - global_position
	if Vector2(to.x, to.z).length_squared() > 0.0001:
		rotation.y = atan2(-to.x, -to.z)


func _apply_reveal() -> void:
	for mat in _mats:
		mat.set_shader_parameter(&"reveal", reveal)


## Its shape, should she make it real (tools/blender/bogge.py, canon:"X"):
## bark-hided and gaunt, three metres if it stood, double-jointed arms long
## enough to walk on, legs that fold backwards, claws like split kindling, a
## long jaw of needle teeth and a cluster of lamp-pale eyes. Every surface is
## swapped for the bogge_form shader, which dissolves it by `reveal`.
func _build_form() -> Node3D:
	var root := (load(MODEL) as PackedScene).instantiate() as Node3D
	root.name = "Form"
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i)
			var mat := ShaderMaterial.new()
			mat.shader = FORM_SHADER
			var tag := src.resource_name if src else ""
			if tag == "BoggeEyes":
				mat.set_shader_parameter(&"is_eye", true)
				mat.set_shader_parameter(&"eye_color", EYE)
			elif src is BaseMaterial3D:
				mat.set_shader_parameter(&"albedo", (src as BaseMaterial3D).albedo_color)
				mat.set_shader_parameter(&"roughness", (src as BaseMaterial3D).roughness)
			mi.set_surface_override_material(i, mat)
			_mats.append(mat)
	_anim = root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim and _anim.has_animation(&"idle"):
		_anim.get_animation(&"idle").loop_mode = Animation.LOOP_LINEAR
		_anim.play(&"idle")
	return root
