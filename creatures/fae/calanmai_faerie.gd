## One of the three faeries who corner Feyre at the forest's edge on Fire
## Night (story ids high_fae_male, _2, _3; cue flee). The text calls them
## lesser faeries (keeper): taller and leaner than Tamlin, pitch-black eyes
## that don't catch the firelight, slightly pointed teeth, pale too-long
## hands; beautiful, laughing with a low hiss. Unmasked: they came from
## outside the cursed household. They scatter when Rhysand steps in.
class_name CalanmaiFaerie
extends StoryActor

signal fled

@export var flee_speed: float = 7.0
@export var flee_time: float = 3.0

var fleeing: bool = false

var _figure: Node3D
var _flee_left: float = 0.0
var _away: Vector3 = Vector3.FORWARD
var _t: float = 0.0


func _ready() -> void:
	if actor_id == &"":
		actor_id = &"high_fae_male"
	super._ready()
	# A little variety between the three, from the id's suffix.
	var n := String(actor_id).hash() % 3
	var tones: Array[Color] = [Color(0.86, 0.86, 0.88), Color(0.82, 0.84, 0.86), Color(0.88, 0.86, 0.84)]
	var cloth: Array[Color] = [Color(0.16, 0.18, 0.22), Color(0.22, 0.16, 0.20), Color(0.14, 0.20, 0.18)]
	_figure = PlaceholderFigure.build({"height": 2.08, "skin": tones[n], "clothes": cloth[n],
		"hair": Color(0.08, 0.08, 0.1)})
	_figure.scale = Vector3(0.88, 1.0, 0.88)
	add_child(_figure)
	var head := _figure.find_child("Head", true, false) as Node3D
	var black := PlaceholderBody._mat(Color(0.0, 0.0, 0.0))
	black.roughness = 1.0
	for side in [-1.0, 1.0]:
		var eye := PlaceholderBody._sphere(0.026, black)
		eye.position = Vector3(side * 0.045, 0.01, -0.105)
		head.add_child(eye)
	var body := _figure.find_child("Body", true, false) as Node3D
	for side in [-1.0, 1.0]:
		var hand := PlaceholderBody._box(Vector3(0.05, 0.2, 0.03), PlaceholderBody._mat(tones[n]))
		hand.position = Vector3(side * 0.26, 0.8, 0)
		body.add_child(hand)


func play_cue(cue: StringName) -> void:
	if cue == &"flee":
		flee()


func flee() -> void:
	if fleeing:
		return
	fleeing = true
	_flee_left = flee_time
	var player := _player()
	_away = Creature.away_from(global_position, player.global_position) if player else -global_basis.z
	fled.emit()


func _process(delta: float) -> void:
	_t += delta
	if not fleeing:
		# Loose, too-fluid idle.
		_figure.rotation.y = sin(_t * 0.9 + float(get_instance_id() % 7)) * 0.08
		return
	if _flee_left <= 0.0:
		return
	_flee_left -= delta
	global_position += _away * flee_speed * delta
	rotation.y = lerp_angle(rotation.y, atan2(-_away.x, -_away.z), clampf(delta * 10.0, 0.0, 1.0))
	if _flee_left <= 0.0:
		# Gone into the dark beyond the bonfires.
		visible = false
