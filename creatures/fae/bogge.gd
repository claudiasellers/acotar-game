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
const SHADOW := Color(0.015, 0.012, 0.02)
const EYE := Color(0.86, 0.9, 0.62)

@export var distance: float = 4.5
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
var _form_mat: StandardMaterial3D
var _eye_mat: StandardMaterial3D
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
	DreadField.attach(self, 45.0, 14.0)
	_fog = FogVolume.new()
	_fog.name = "Dark"
	_fog.size = Vector3(6, 4, 6)
	_fog.position.y = 1.5
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
	if _form_mat:
		# Even unseen there is something: a darker patch the eye slides off.
		_form_mat.albedo_color.a = lerpf(0.04, 0.97, reveal)
		_form_mat.rim = lerpf(0.0, 0.9, reveal)
	if _eye_mat:
		_eye_mat.albedo_color.a = clampf(reveal * 1.6 - 0.2, 0.0, 1.0)
		_eye_mat.emission_energy_multiplier = lerpf(0.0, 5.0, reveal)


## Its shape, should she make it real: hunched, three metres if it stood,
## arms long enough to walk on, claws like split kindling, and too many eyes
## clustered where a face should be. One oily near-black, wet-rimmed.
func _build_form() -> Node3D:
	var root := Node3D.new()
	root.name = "Form"
	_form_mat = StandardMaterial3D.new()
	_form_mat.albedo_color = Color(SHADOW, 0.04)
	_form_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_form_mat.roughness = 0.25
	_form_mat.metallic = 0.4
	_form_mat.rim_enabled = true
	_form_mat.rim_tint = 0.2
	_form_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_eye_mat = StandardMaterial3D.new()
	_eye_mat.albedo_color = Color(EYE, 0.0)
	_eye_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_eye_mat.emission_enabled = true
	_eye_mat.emission = EYE
	_eye_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# Body: a long torso pitched forward, a hump of shoulder over it.
	var torso := _capsule(0.42, 2.3)
	torso.position = Vector3(0.0, 1.75, -0.35)
	torso.rotation_degrees.x = -38.0
	root.add_child(torso)
	var hump := _sphere(0.55)
	hump.scale = Vector3(1.25, 0.8, 1.0)
	hump.position = Vector3(0.0, 2.55, -0.55)
	root.add_child(hump)
	# Head: small, low and forward, a slit of jaw.
	var head := _sphere(0.24)
	head.name = "Head"
	head.scale = Vector3(0.9, 0.8, 1.3)
	head.position = Vector3(0.0, 2.25, -1.25)
	root.add_child(head)
	var jaw := _box(Vector3(0.36, 0.05, 0.3))
	jaw.position = Vector3(0.0, 2.1, -1.38)
	root.add_child(jaw)
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	for i in 9:
		var eye := MeshInstance3D.new()
		var m := SphereMesh.new()
		var r := rng.randf_range(0.018, 0.04)
		m.radius = r
		m.height = r * 2.0
		m.radial_segments = 8
		m.rings = 4
		eye.mesh = m
		eye.material_override = _eye_mat
		eye.position = Vector3(rng.randf_range(-0.16, 0.16), 2.28 + rng.randf_range(-0.08, 0.12), -1.5 + rng.randf_range(0.0, 0.08))
		root.add_child(eye)
	# Arms: shoulder to elbow up and out, forearm down to the ground ahead.
	for side in [-1.0, 1.0]:
		var upper := _limb(Vector3(side * 0.5, 2.5, -0.6), Vector3(side * 1.05, 1.9, -1.2), 0.09)
		root.add_child(upper)
		var fore := _limb(Vector3(side * 1.05, 1.9, -1.2), Vector3(side * 0.85, 0.1, -1.7), 0.07)
		root.add_child(fore)
		for f in 4:
			var spread := deg_to_rad(-30.0 + f * 20.0)
			var tip := Vector3(side * 0.85, 0.0, -1.7) + Vector3(sin(spread) * 0.5, 0.0, -cos(spread) * 0.5)
			root.add_child(_limb(Vector3(side * 0.85, 0.12, -1.7), tip, 0.018))
		# Legs: folded back like a hare's, thin as stakes.
		var thigh := _limb(Vector3(side * 0.3, 1.0, 0.3), Vector3(side * 0.45, 0.9, 0.95), 0.1)
		root.add_child(thigh)
		var shin := _limb(Vector3(side * 0.45, 0.9, 0.95), Vector3(side * 0.4, 0.0, 0.7), 0.06)
		root.add_child(shin)
	# Rags of itself trailing off into the fog.
	for i in 6:
		var rag := _sphere(0.4)
		rag.scale = Vector3(1.2, 0.25, 1.6)
		rag.position = Vector3(rng.randf_range(-0.7, 0.7), rng.randf_range(0.6, 2.2), rng.randf_range(-0.3, 0.9))
		rag.rotation = Vector3(rng.randf_range(-0.5, 0.5), rng.randf(), rng.randf_range(-0.5, 0.5))
		root.add_child(rag)
	return root


func _capsule(radius: float, height: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := CapsuleMesh.new()
	m.radius = radius
	m.height = height
	m.radial_segments = 12
	m.rings = 4
	mi.mesh = m
	mi.material_override = _form_mat
	return mi


func _sphere(radius: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = 12
	m.rings = 6
	mi.mesh = m
	mi.material_override = _form_mat
	return mi


func _box(size: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = size
	mi.mesh = m
	mi.material_override = _form_mat
	return mi


## A tapering limb from a to b.
func _limb(a: Vector3, b: Vector3, radius: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = radius
	m.bottom_radius = radius * 0.45
	m.height = a.distance_to(b)
	m.radial_segments = 6
	m.rings = 1
	mi.mesh = m
	mi.material_override = _form_mat
	var mid := (a + b) * 0.5
	var dir := (b - a).normalized()
	var basis := Basis.IDENTITY
	if absf(dir.dot(Vector3.UP)) < 0.999:
		var axis := Vector3.UP.cross(dir).normalized()
		basis = Basis(axis, Vector3.UP.angle_to(dir))
	else:
		basis = Basis.IDENTITY if dir.y > 0.0 else Basis(Vector3.RIGHT, PI)
	# Cylinder's +Y runs a->b with the thick end at top: flip so it tapers outward.
	mi.transform = Transform3D(basis * Basis(Vector3.RIGHT, PI), mid)
	return mi
