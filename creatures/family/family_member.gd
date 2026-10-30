## Nesta, Elain or their father: their cast model (characters/<id>/<id>_model.tscn,
## a coloured capsule if it is missing) that walks a daily routine from its
## FamilySchedule, so the cottage feels lived in.
##
## Story cues: (&"family", &"gather") sends everyone to the hearth and freezes
## their routines; (&"family", &"release") lets them go back to their day.
class_name FamilyMember
extends Node3D

const GROUP := &"family"
const SPOT_GROUP := &"family_spot"
const MODEL_SCENE := "res://characters/%s/%s_model.tscn"

@export var member_id: StringName = &"nesta"
@export var schedule: FamilySchedule
@export var height: float = 1.68
@export var color: Color = Color(0.45, 0.52, 0.62)
@export var walk_speed: float = 1.1
## Offset from the hearth when the family gathers.
@export var gather_offset: Vector3 = Vector3.ZERO

var scripted: bool = false
var activity: StringName = &"idle"
var target_spot: StringName = &""

var _body: Node3D
var _destination: Vector3
## The cast model when there is one; it plays idle/walk from our ground speed.
var _model: Node3D


func _ready() -> void:
	add_to_group(GROUP)
	_destination = global_position if is_inside_tree() else position
	_build_body()
	if EventBus.has_signal(&"story_actor_cue"):
		EventBus.connect(&"story_actor_cue", _on_cue)


func _process(delta: float) -> void:
	if not scripted and schedule:
		var hour := Clock.hour()
		activity = schedule.activity_at(hour)
		var spot := schedule.spot_at(hour)
		if spot != target_spot:
			target_spot = spot
			var node := find_spot(get_tree(), spot)
			if node:
				_destination = node.global_position
	var to := _destination - global_position
	to.y = 0.0
	var speed := 0.0
	if to.length() > 0.05:
		global_position += to.limit_length(walk_speed * delta)
		rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), 8.0 * delta)
		speed = walk_speed if delta > 0.0 else 0.0
	if _model and _model.has_method(&"play_locomotion"):
		_model.play_locomotion(speed, true, delta)
	_pose()


## Scenes freeze routines while they pose the family.
func set_scripted(value: bool) -> void:
	scripted = value


func go_to(point: Vector3) -> void:
	_destination = point


func _on_cue(actor: StringName, cue: StringName) -> void:
	if actor != GROUP and actor != member_id:
		return
	match cue:
		&"gather":
			set_scripted(true)
			activity = &"gather"
			var hearth := get_tree().get_first_node_in_group(&"hearth") as Node3D
			if hearth:
				go_to(hearth.global_position + gather_offset)
		&"plead":
			# The father limps toward the beast and goes down on his knees.
			set_scripted(true)
			activity = &"plead"
			var beast := get_tree().get_first_node_in_group(&"beast") as Node3D
			if beast:
				go_to(beast.global_position + Creature.away_from(beast.global_position, global_position) * -2.5)
		&"release":
			set_scripted(false)
			target_spot = &""


static func find_spot(tree: SceneTree, spot_id: StringName) -> Node3D:
	if tree == null or spot_id == &"":
		return null
	for node in tree.get_nodes_in_group(SPOT_GROUP):
		if StringName(node.get_meta(&"spot_id", node.name)) == spot_id:
			return node as Node3D
	return null


## Sleeping lies down, sitting activities lower the body, away hides it.
## The cast models have no sit or kneel clips yet: they lie down to sleep,
## bow their head to plead and otherwise stand on their feet.
func _pose() -> void:
	if _body == null:
		return
	visible = activity != &"away"
	if _model:
		_body.rotation.x = -PI * 0.5 if activity == &"sleep" else (0.2 if activity == &"plead" else 0.0)
		_body.position.y = 0.55 if activity == &"sleep" else 0.0
		return
	match activity:
		&"sleep":
			_body.rotation.x = -PI * 0.5
			_body.position.y = 0.55
		&"plead":
			_body.rotation.x = 0.25
			_body.position.y = height * 0.5 - 0.55
		&"carve", &"sit", &"mend", &"eat", &"window":
			_body.rotation.x = 0.0
			_body.position.y = height * 0.5 - 0.35
		_:
			_body.rotation.x = 0.0
			_body.position.y = height * 0.5


func _build_body() -> void:
	var path := MODEL_SCENE % [member_id, member_id]
	if ResourceLoader.exists(path):
		_model = (load(path) as PackedScene).instantiate() as Node3D
		_model.name = "Body"
		_body = _model
		add_child(_model)
		return
	var capsule_body := MeshInstance3D.new()
	_body = capsule_body
	_body.name = "Body"
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.2
	capsule.height = height
	capsule_body.mesh = capsule
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	capsule_body.material_override = mat
	_body.position.y = height * 0.5
	add_child(_body)
	var label := Label3D.new()
	label.text = String(member_id).capitalize()
	label.position.y = height + 0.25
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 28
	label.modulate = Color(1, 1, 1, 0.7)
	add_child(label)
