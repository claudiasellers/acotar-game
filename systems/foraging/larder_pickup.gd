## A larder shelf that hands over one item a day: the manor kitchen's dead
## chicken, the canon bait for the Suriel snare (SnarePlan.bait_score 0.85).
## Same contract as ManorKeepsake (group "forage", harvest() -> StringName),
## but it restocks each morning, so a failed snare can be tried again.
class_name LarderPickup
extends Node3D

const GROUP := &"forage"
const MODEL := "res://art/forage/%s.glb"

@export var item_id: StringName = &"ing_dead_chicken"
## Stocked only once this WorldState flag is set ("" = always). The infirmary's
## wound herbs wait for naga_survived (L29), so they can't be picked up a
## scene early, during L28's wound dressing in the same room.
@export var required_flag: String = ""
## Clock.day it was last taken; -1 = stocked.
var taken_day: int = -1
var _model: Node3D


func _ready() -> void:
	add_to_group(GROUP)
	if _model == null:
		_model = _build_model()
		if _model:
			add_child(_model)
	_refresh()


func _process(_delta: float) -> void:
	_refresh()


func stocked() -> bool:
	if required_flag != "" and not WorldState.has_flag(required_flag):
		return false
	return taken_day < 0 or Clock.day > taken_day


func harvest() -> StringName:
	if not stocked():
		return &""
	taken_day = Clock.day
	_refresh()
	return item_id


func _refresh() -> void:
	visible = stocked()
	set_process(not visible)
	# An empty shelf is not a forage spot: it mustn't shadow a nearer real one.
	if visible and not is_in_group(GROUP):
		add_to_group(GROUP)
	elif not visible and is_in_group(GROUP):
		remove_from_group(GROUP)


func _build_model() -> Node3D:
	var path := MODEL % item_id
	if ResourceLoader.exists(path):
		return (load(path) as PackedScene).instantiate() as Node3D
	# Until the forage-models lane draws one: a small pale bundle on the shelf.
	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.16
	mesh.height = 0.22
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("e9dcc4")
	mi.material_override = mat
	mi.position.y = 0.11
	return mi
