## A member of the secondary cast or a villager: a Blender model, and where
## the glamour hides something, a second true-form model swapped in when
## `glamour_lifted` rises (two GlamourLayers). Optionally strolls about its
## spawn point. Dialogue and schedules belong to other lanes; they find NPCs
## by group "court_npc" and `npc_id`.
class_name CourtNpc
extends Node3D

const GROUP := &"court_npc"

@export var npc_id: StringName = &""
@export var display_name: String = ""
@export var canon: String = "X"
## What Feyre sees (before the glamour lifts, if there is a true form).
## Empty with a true form: unseen until the glamour lifts, only a ripple.
@export var model_scene: PackedScene
## The shape under the glamour. Empty: the same either way.
@export var true_model_scene: PackedScene
## Metres it wanders from where it was placed; 0 stands still.
@export var wander_radius: float = 0.0
@export var walk_speed: float = 0.8

var glamoured_layer: GlamourLayer
var true_layer: GlamourLayer
var home: Vector3

var _target: Vector3
var _pause: float = 0.0
var _t: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group(GROUP)
	if npc_id == &"":
		npc_id = StringName(name.to_snake_case())
	_rng.seed = hash(npc_id)
	home = global_position if is_inside_tree() else position
	_target = home
	if true_model_scene:
		glamoured_layer = _layer(GlamourLayer.Layer.GLAMOURED, model_scene)
		true_layer = _layer(GlamourLayer.Layer.TRUE_FORM, true_model_scene)
	elif model_scene:
		var m := model_scene.instantiate() as Node3D
		m.name = "Model"
		add_child(m)


func _layer(which: GlamourLayer.Layer, scene: PackedScene) -> GlamourLayer:
	var layer := GlamourLayer.new()
	layer.name = "Glamoured" if which == GlamourLayer.Layer.GLAMOURED else "TrueForm"
	layer.layer = which
	if scene:
		var m := scene.instantiate() as Node3D
		m.name = "Model"
		layer.add_child(m)
	elif which == GlamourLayer.Layer.GLAMOURED:
		# Unseen before the glamour lifts (the house seems near-empty): at most
		# a ripple in the air at the edge of sight.
		var ripple := MeshInstance3D.new()
		ripple.name = "Ripple"
		var capsule := CapsuleMesh.new()
		capsule.radius = 0.28
		capsule.height = 1.75
		ripple.mesh = capsule
		ripple.position.y = 0.9
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://creatures/ambient/unseen_shimmer.gdshader")
		mat.set_shader_parameter(&"strength", 0.18)
		ripple.material_override = mat
		ripple.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		layer.add_child(ripple)
	add_child(layer)
	return layer


## The model on screen right now.
func current_model() -> Node3D:
	for layer in [glamoured_layer, true_layer]:
		if layer and layer.visible:
			return layer.get_node_or_null(^"Model") as Node3D
	return get_node_or_null(^"Model") as Node3D


func _process(delta: float) -> void:
	_t += delta
	var model := current_model()
	if model:
		# Breathing: alive, never a mannequin.
		model.scale = Vector3(1.0, 1.0 + sin(_t * 1.6 + float(_rng.seed % 7)) * 0.006, 1.0)
	if wander_radius <= 0.0:
		return
	if _pause > 0.0:
		_pause -= delta
		return
	var to := _target - global_position
	to.y = 0.0
	if to.length() < 0.2:
		_pause = _rng.randf_range(3.0, 9.0)
		var a := _rng.randf() * TAU
		_target = home + Vector3(cos(a), 0.0, sin(a)) * _rng.randf() * wander_radius
		return
	global_position += to.limit_length(walk_speed * delta)
	rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), clampf(delta * 4.0, 0.0, 1.0))
