## Every readable mark creatures leave: prints in the snow, blood after a
## wound, snapped twigs. Marks fade with age and are buried faster while snow
## falls, so a fresh trail reads differently from an old one.
##
## One layer lives in the current scene; creatures call TrackLayer.leave().
class_name TrackLayer
extends Node3D

const GROUP := &"track_layer"
const MAX_MARKS := 600

## Seconds of clear weather before a mark is gone.
const LIFETIMES := {
	&"print": 360.0,
	&"blood": 600.0,
	&"twig": 900.0,
}
## Snowfall at 1.0 buries marks this many times faster than clear weather.
const SNOW_BURY_RATE := 5.0

var marks: Array[Dictionary] = []
## Overrides the weather lookup (tests, scripted storms). Negative means look it up.
var snowfall_override: float = -1.0

var _materials: Dictionary = {}
var _meshes: Dictionary = {}


func _ready() -> void:
	add_to_group(GROUP)


func _process(delta: float) -> void:
	step(delta)


## Finds (or makes) the scene's track layer and leaves a mark on it.
static func leave(tree: SceneTree, kind: StringName, at: Vector3, heading: float = 0.0, size: float = 0.09) -> void:
	if tree == null or tree.current_scene == null:
		return
	var layer := tree.get_first_node_in_group(GROUP) as TrackLayer
	if layer == null:
		layer = TrackLayer.new()
		layer.name = "TrackLayer"
		tree.current_scene.add_child(layer)
	layer.add_mark(kind, at, heading, size)


## Visibility (0 to 1) of a mark buried by `burial` seconds-equivalent.
static func visibility(burial: float, lifetime: float) -> float:
	return clampf(1.0 - burial / lifetime, 0.0, 1.0)


## How much burial a mark gains over `delta` seconds of `snowfall` (0 to 1).
static func burial_step(delta: float, snowfall: float) -> float:
	return delta * (1.0 + SNOW_BURY_RATE * clampf(snowfall, 0.0, 1.0))


func add_mark(kind: StringName, at: Vector3, heading: float, size: float) -> Dictionary:
	if marks.size() >= MAX_MARKS:
		_remove(0)
	var mesh := MeshInstance3D.new()
	mesh.mesh = _mesh_for(kind, size)
	mesh.material_override = _material_for(kind)
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.position = at + Vector3.UP * 0.015
	mesh.rotation.y = heading
	if kind == &"twig":
		mesh.rotation.y += randf() * TAU
		mesh.position.y += 0.02
	add_child(mesh)
	var mark := {"kind": kind, "node": mesh, "burial": 0.0, "lifetime": LIFETIMES.get(kind, 300.0), "position": at}
	marks.append(mark)
	return mark


func step(delta: float) -> void:
	var snow := snowfall_override if snowfall_override >= 0.0 else _current_snowfall()
	var gain := burial_step(delta, snow)
	var i := marks.size() - 1
	while i >= 0:
		var mark := marks[i]
		mark.burial += gain
		var vis := visibility(mark.burial, mark.lifetime)
		if vis <= 0.0:
			_remove(i)
		else:
			(mark.node as GeometryInstance3D).transparency = 1.0 - vis
		i -= 1


## Marks within `radius`, freshest first. For a future tracking read/sketch.
func marks_near(at: Vector3, radius: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for mark in marks:
		if (mark.position as Vector3).distance_to(at) <= radius:
			out.append(mark)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.burial < b.burial)
	return out


func _remove(index: int) -> void:
	var node := marks[index].node as Node
	if is_instance_valid(node):
		node.queue_free()
	marks.remove_at(index)


func _current_snowfall() -> float:
	var weather := get_tree().get_first_node_in_group(&"wind_source")
	if weather == null:
		return 0.0
	if weather.has_method(&"snowfall_at"):
		return float(weather.call(&"snowfall_at", global_position))
	var value: Variant = weather.get(&"snowfall")
	return float(value) if value != null else 0.0


func _mesh_for(kind: StringName, size: float) -> Mesh:
	var key := "%s_%.2f" % [kind, size]
	if _meshes.has(key):
		return _meshes[key]
	var mesh: Mesh
	match kind:
		&"twig":
			var box := BoxMesh.new()
			box.size = Vector3(0.012, 0.012, 0.22)
			mesh = box
		&"blood":
			var drop := PlaneMesh.new()
			drop.size = Vector2(size * 1.4, size * 1.1)
			mesh = drop
		_:
			var dent := PlaneMesh.new()
			dent.size = Vector2(size, size * 1.5)
			mesh = dent
	_meshes[key] = mesh
	return mesh


func _material_for(kind: StringName) -> Material:
	if _materials.has(kind):
		return _materials[kind]
	var mat := StandardMaterial3D.new()
	mat.roughness = 1.0
	match kind:
		&"blood":
			mat.albedo_color = Color(0.42, 0.04, 0.05)
			mat.roughness = 0.4
		&"twig":
			mat.albedo_color = Color(0.36, 0.27, 0.18)
		_:
			# A shadowed dent in snow: blue-grey, not black.
			mat.albedo_color = Color(0.58, 0.63, 0.72)
	_materials[kind] = mat
	return mat
