## A loose cloud of small fliers drawn as one MultiMesh (engineering rule R9:
## no per-instance nodes): butterflies over flowers by day, faelights drifting
## at night. Each one wanders on its own smooth path around the swarm's home,
## and the cloud parts around Feyre when she walks through it.
class_name AmbientSwarm
extends Node3D

const FLUTTER := preload("res://creatures/ambient/ambient_flutter.gdshader")
const GLOW := preload("res://creatures/ambient/ambient_glow.gdshader")
const GROUP := &"ambient_swarm"

## A model whose first mesh is one flier: body along Z, wings out along X.
@export var model_scene: PackedScene
@export var count: int = 40
@export var radius: float = 8.0
@export var min_height: float = 0.3
@export var max_height: float = 2.2
@export var speed: float = 0.6
@export var scale_range: Vector2 = Vector2(0.8, 1.2)
@export var colors: PackedColorArray = PackedColorArray([Color(1.0, 0.72, 0.84)])
@export var glow: float = 0.0
@export var flap_speed: float = 14.0
## Half wingspan of the model, for the flutter shader.
@export var wing_span: float = 0.065
## Fliers keep this far from the player.
@export var shy_distance: float = 1.6
## Beyond this distance from the camera the swarm stops updating and hides.
@export var active_distance: float = 90.0
## Draw each flier as a soft round mote of light instead of a winged mesh
## (faelights, fireflies: warm, soft-edged, never square; bible §2.4).
@export var round_glow: bool = false
@export var glow_size: float = 0.09

## 0 normal, 1 fully withdrawn near horror (DreadField); eased.
var withdrawn: float = 0.0

var multimesh: MultiMesh

var _instance: MultiMeshInstance3D
var _seeds: PackedFloat32Array = PackedFloat32Array()
var _time: float = 0.0
var _update_left: float = 0.0
var _dread_left: float = 0.0
var _withdrawn_target: float = 0.0


func _ready() -> void:
	add_to_group(GROUP)
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = _flier_mesh()
	multimesh.instance_count = count
	_instance = MultiMeshInstance3D.new()
	_instance.name = "Fliers"
	_instance.multimesh = multimesh
	_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_instance.visibility_range_end = active_distance
	var mat := ShaderMaterial.new()
	if round_glow:
		mat.shader = GLOW
		mat.set_shader_parameter(&"glow", maxf(glow, 0.5))
	else:
		mat.shader = FLUTTER
		mat.set_shader_parameter(&"glow", glow)
		mat.set_shader_parameter(&"flap_speed", flap_speed)
		mat.set_shader_parameter(&"wing_span", wing_span)
	_instance.material_override = mat
	add_child(_instance)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(name) ^ count
	_seeds.resize(count * 4)
	for i in count:
		for k in 4:
			_seeds[i * 4 + k] = rng.randf()
		var c: Color = colors[rng.randi() % colors.size()] if not colors.is_empty() else Color.WHITE
		multimesh.set_instance_color(i, c)
	_layout(0.0)


func _process(delta: float) -> void:
	_time += delta
	_dread_left -= delta
	if _dread_left <= 0.0:
		_dread_left = 1.0
		set_withdrawn_target(DreadField.withdrawal_at(get_tree(), global_position))
	if not is_equal_approx(withdrawn, _withdrawn_target):
		withdrawn = move_toward(withdrawn, _withdrawn_target, delta * 0.5)
		multimesh.visible_instance_count = int(round(count * (1.0 - withdrawn)))
	_update_left -= delta
	if _update_left > 0.0:
		return
	_update_left = 1.0 / 30.0
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	if camera and camera.global_position.distance_to(global_position) > active_distance:
		return
	_layout(_time)


## Near horror the fliers thin out and are gone (they never pop: eased).
func set_withdrawn_target(amount: float) -> void:
	_withdrawn_target = clampf(amount, 0.0, 1.0)


## Where flier `i` is at time `t`, relative to the swarm. Smooth Lissajous
## loops, different per flier.
func offset_at(i: int, t: float) -> Vector3:
	var s0 := _seeds[i * 4]
	var s1 := _seeds[i * 4 + 1]
	var s2 := _seeds[i * 4 + 2]
	var s3 := _seeds[i * 4 + 3]
	var w := speed * (0.5 + s1)
	var r := radius * (0.25 + 0.75 * sqrt(s2))
	var x := sin(t * w * 0.37 + s0 * 40.0) * r
	var z := cos(t * w * 0.29 + s3 * 40.0) * r
	var y := lerpf(min_height, max_height, 0.5 + 0.5 * sin(t * w * 0.8 + s1 * 30.0))
	return Vector3(x, y, z)


func _layout(t: float) -> void:
	var player := get_tree().get_first_node_in_group(&"player") as Node3D if is_inside_tree() else null
	var dt := 1.0 / 30.0
	for i in count:
		var p := offset_at(i, t)
		var ahead := offset_at(i, t + dt)
		if player:
			var away := global_transform * p - (player.global_position + Vector3.UP)
			var d := away.length()
			if d < shy_distance and d > 0.001:
				p += away / d * (shy_distance - d)
		var heading := ahead - p
		var b := Basis.IDENTITY
		if heading.length_squared() > 0.000001:
			b = Basis.looking_at(heading.normalized(), Vector3.UP)
		var s := lerpf(scale_range.x, scale_range.y, _seeds[i * 4 + 3])
		multimesh.set_instance_transform(i, Transform3D(b.scaled(Vector3.ONE * s), p))


func _flier_mesh() -> Mesh:
	if round_glow:
		var mote := QuadMesh.new()
		mote.size = Vector2.ONE * glow_size
		return mote
	if model_scene:
		var root := model_scene.instantiate()
		var found := root.find_children("*", "MeshInstance3D", true, false)
		var mesh: Mesh = (found[0] as MeshInstance3D).mesh if not found.is_empty() else null
		root.free()
		if mesh:
			return mesh
	var q := QuadMesh.new()
	q.size = Vector2(0.08, 0.06)
	return q
