## The puca in the manor garden at night (story ids: puca; cues
## looks_like_father, shift_image). It wears whatever Feyre wants most:
## first her father, then her bow, supplies for home, her sisters. It keeps
## just out of reach and drifts toward the woods so she follows. Between
## shapes its own form shows for a heartbeat: canon X until the keeper says.
##
## Every image is a placeholder (R4); the father and sisters stay so until
## the user designs the main cast.
class_name Puca
extends StoryActor

signal image_changed(image: StringName)

const IMAGES: Array[StringName] = [&"father", &"bow", &"supplies", &"sisters"]
const TRUE_FORM := &"true_form"

## How far ahead of Feyre it keeps, and how fast it drifts.
@export var lure_distance: float = 9.0
@export var drift_speed: float = 0.9
## How long its own shape shows between images.
@export var flicker_time: float = 0.18

var image_index: int = -1
var showing: StringName = &""

var _images: Dictionary = {}
var _flicker_left: float = 0.0
var _t: float = 0.0


func _ready() -> void:
	if actor_id == &"":
		actor_id = &"puca"
	super._ready()
	for id in IMAGES:
		_images[id] = _build_image(id)
	_images[TRUE_FORM] = _build_true_form()
	for id in _images:
		var node := _images[id] as Node3D
		node.name = String(id).to_pascal_case()
		node.visible = false
		add_child(node)
	visible = false


func play_cue(cue: StringName) -> void:
	match cue:
		&"looks_like_father":
			visible = true
			image_index = 0
			_show(IMAGES[0])
		&"shift_image":
			visible = true
			image_index = (image_index + 1) % IMAGES.size()
			_flicker_left = flicker_time
			_show(TRUE_FORM)


func _show(id: StringName) -> void:
	showing = id
	for key in _images:
		(_images[key] as Node3D).visible = key == id
	if id != TRUE_FORM:
		image_changed.emit(id)


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	if _flicker_left > 0.0:
		_flicker_left -= delta
		if _flicker_left <= 0.0:
			_show(IMAGES[image_index])
	var player := _player()
	if player == null:
		return
	# Always just out of reach: back away when she closes, wait when she lags.
	var to := global_position - player.global_position
	to.y = 0.0
	var gap := to.length()
	if gap < lure_distance and gap > 0.01:
		global_position += to / gap * drift_speed * delta * (2.0 if gap < lure_distance * 0.5 else 1.0)
	_turn_towards(player.global_position, delta * 3.0)
	# A slight sway: real things are never quite this still.
	rotation.z = sin(_t * 0.7) * 0.015


func _build_image(id: StringName) -> Node3D:
	match id:
		&"father":
			# Patrick Archeron, as she left him: stooped on his cane by the fire.
			return PlaceholderFigure.build({"height": 1.78, "clothes": Color(0.42, 0.36, 0.30),
				"hair": Color(0.55, 0.50, 0.45), "pointed_ears": false, "stoop": 12.0, "cane": true})
		&"bow":
			var root := Node3D.new()
			var wood := PlaceholderBody._mat(Color(0.48, 0.32, 0.18))
			# An ash bow standing upright: an arc of segments and its string.
			var centre := Vector3(-0.6, 0.85, 0.0)
			var r := 0.9
			for s in 7:
				var a := deg_to_rad(-48.0 + s * 16.0)
				var seg := PlaceholderBody._cylinder(0.02, 0.26, wood)
				seg.position = centre + Vector3(cos(a), sin(a), 0.0) * r
				seg.rotation.z = a
				root.add_child(seg)
			var string := PlaceholderBody._cylinder(0.004, 2.0 * r * sin(deg_to_rad(50.0)), PlaceholderBody._mat(Color(0.9, 0.88, 0.8)))
			string.position = centre + Vector3(r * cos(deg_to_rad(50.0)), 0.0, 0.0)
			root.add_child(string)
			var quiver := PlaceholderBody._cylinder(0.06, 0.6, PlaceholderBody._mat(Color(0.36, 0.24, 0.14)))
			quiver.position = Vector3(0.4, 0.06, 0.25)
			quiver.rotation_degrees.z = 85.0
			root.add_child(quiver)
			return root
		&"supplies":
			var root := Node3D.new()
			var sack := PlaceholderBody._mat(Color(0.78, 0.70, 0.52))
			for i in 3:
				var s := PlaceholderBody._sphere(0.28, sack)
				s.scale = Vector3(1.0, 1.25, 0.9)
				s.position = Vector3(-0.5 + i * 0.5, 0.33, 0.1 * i)
				root.add_child(s)
			var crate := PlaceholderBody._box(Vector3(0.7, 0.5, 0.5), PlaceholderBody._mat(Color(0.55, 0.40, 0.25)))
			crate.position = Vector3(0.2, 0.25, -0.55)
			root.add_child(crate)
			return root
		_:
			var root := Node3D.new()
			var nesta := PlaceholderFigure.build({"height": 1.72, "clothes": Color(0.45, 0.48, 0.62),
				"hair": Color(0.55, 0.38, 0.22), "pointed_ears": false, "robe": true})
			nesta.position.x = -0.45
			root.add_child(nesta)
			var elain := PlaceholderFigure.build({"height": 1.66, "clothes": Color(0.86, 0.72, 0.62),
				"hair": Color(0.85, 0.68, 0.38), "pointed_ears": false, "robe": true})
			elain.position.x = 0.45
			root.add_child(elain)
			return root


## Its own shape, glimpsed: too tall, too thin, pale as a peeled branch, with
## eyes like wet coins. Canon X.
func _build_true_form() -> Node3D:
	var root := PlaceholderFigure.build({"height": 2.3, "skin": Color(0.78, 0.80, 0.74),
		"clothes": Color(0.62, 0.64, 0.58), "hair": Color(0.2, 0.22, 0.2), "stoop": 25.0})
	var eye := StandardMaterial3D.new()
	eye.albedo_color = Color(0.85, 0.85, 0.7)
	eye.emission_enabled = true
	eye.emission = Color(0.9, 0.9, 0.6)
	eye.emission_energy_multiplier = 2.5
	var head := root.find_child("Head", true, false) as Node3D
	for side in [-1.0, 1.0]:
		var e := PlaceholderBody._sphere(0.035, eye)
		e.position = Vector3(side * 0.06, 0.02, -0.13)
		head.add_child(e)
	return root
