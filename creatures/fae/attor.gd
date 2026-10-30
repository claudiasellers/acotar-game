## The Attor (lore: 04-creatures/attor.md). Under Tamlin's glamour Feyre hears
## it but cannot see it (ch19); once the glamour lifts it has its true form.
## Cue `speaks_of_her`: it turns its head toward the manor and hisses.
class_name Attor
extends StoryActor

signal spoke
## A rasp of breath the audio layer can place in space.
signal breathed(at: Vector3)

@export var breath_interval: float = 2.2

var true_form: GlamourLayer

var _breath_left: float = 1.0
var _t: float = 0.0
var _speaking: float = 0.0


func _ready() -> void:
	if actor_id == &"":
		actor_id = &"attor"
	super._ready()
	DreadField.attach(self, 25.0, 8.0)


func _mount_model(m: Node3D) -> void:
	# Nothing in the glamoured layer: she sees empty garden.
	var unseen := GlamourLayer.new()
	unseen.name = "Glamoured"
	unseen.layer = GlamourLayer.Layer.GLAMOURED
	add_child(unseen)
	true_form = GlamourLayer.new()
	true_form.name = "TrueForm"
	true_form.layer = GlamourLayer.Layer.TRUE_FORM
	add_child(true_form)
	true_form.add_child(m)


func play_cue(cue: StringName) -> void:
	if cue == &"speaks_of_her":
		_speaking = 2.5
		spoke.emit()


func _process(delta: float) -> void:
	_t += delta
	_breath_left -= delta
	if _breath_left <= 0.0:
		_breath_left = breath_interval * (0.8 + 0.4 * randf())
		breathed.emit(global_position + Vector3.UP * 1.5)
	if model:
		_speaking = maxf(_speaking - delta, 0.0)
		model.rotation.x = -0.2 * _speaking / 2.5 + sin(_t * 1.1) * 0.03
		model.rotation.z = sin(_t * 0.7) * 0.04
