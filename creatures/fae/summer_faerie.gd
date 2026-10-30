## The Summer Court faerie Tamlin carries in (ch17; keeper, from the text):
## a lesser faerie nearly Tamlin's size, blue-skinned and gangly, long onyx
## hair, glossy black eyes, his wings cut off to black stumps that bleed down
## his back. "She took my wings." Tamlin's magic cannot stop it, and he dies.
##
## Cue: dies. Placeholder body until the user's pass (R4).
class_name SummerFaerie
extends StoryActor

signal died

@export var death_time: float = 3.0

var alive: bool = true

var _figure: Node3D
var _t: float = 0.0


func _ready() -> void:
	if actor_id == &"":
		actor_id = &"summer_faerie"
	super._ready()
	_figure = PlaceholderFigure.build({"height": 2.0, "skin": Color(0.38, 0.55, 0.85),
		"clothes": Color(0.30, 0.45, 0.70), "hair": Color(0.04, 0.04, 0.06)})
	add_child(_figure)
	var head := _figure.find_child("Head", true, false) as Node3D
	var black := PlaceholderBody._mat(Color(0.02, 0.02, 0.03))
	black.roughness = 0.1
	for side in [-1.0, 1.0]:
		var eye := PlaceholderBody._sphere(0.028, black)
		eye.position = Vector3(side * 0.045, 0.01, -0.105)
		head.add_child(eye)
	var body := _figure.find_child("Body", true, false) as Node3D
	var blood := PlaceholderBody._mat(Color(0.32, 0.02, 0.03))
	blood.roughness = 0.25
	for side in [-1.0, 1.0]:
		var stump := PlaceholderBody._cylinder(0.05, 0.12, PlaceholderBody._mat(Color(0.06, 0.05, 0.06)))
		stump.name = "WingStump%s" % ("L" if side < 0 else "R")
		stump.position = Vector3(side * 0.1, 1.35, 0.15)
		stump.rotation_degrees.x = 70.0
		body.add_child(stump)
		var run := PlaceholderBody._box(Vector3(0.07, 0.5, 0.01), blood)
		run.position = Vector3(side * 0.1, 1.08, 0.13)
		body.add_child(run)


func play_cue(cue: StringName) -> void:
	if cue == &"dies":
		die()


func die() -> void:
	if not alive:
		return
	alive = false
	died.emit()
	if not is_inside_tree():
		_figure.rotation.x = PI * 0.5
		return
	# Already laid out on the table: the last breath leaves and he goes slack.
	var tween := create_tween().set_trans(Tween.TRANS_SINE)
	tween.tween_property(_figure, ^"rotation:x", PI * 0.5, death_time * 0.3)
	tween.tween_property(_figure, ^"scale", Vector3(1.0, 0.97, 1.0), death_time * 0.7)


func _process(delta: float) -> void:
	if not alive:
		return
	# Shallow, fast breathing while he bleeds.
	_t += delta
	_figure.scale = Vector3(1.0 + sin(_t * 9.0) * 0.012, 1.0, 1.0 + sin(_t * 9.0) * 0.012)
