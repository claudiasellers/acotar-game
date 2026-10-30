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
	# Each of the three has his own model (fae_people.py: calanmai_1..3).
	var n := 1
	var suffix := String(actor_id).rsplit("_", true, 1)
	if suffix.size() == 2 and suffix[1].is_valid_int():
		n = clampi(int(suffix[1]), 1, 3)
	_figure = (load("res://creatures/models/people/calanmai_%d.gltf" % n) as PackedScene).instantiate() as Node3D
	_figure.name = "Model"
	add_child(_figure)


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
