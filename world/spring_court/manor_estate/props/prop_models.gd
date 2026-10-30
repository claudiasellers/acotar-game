## Loads the Blender models made by tools/blender/manor_props.py and
## manor_flora.py. Each .glb holds "<id>" (LOD0) and "<id>_lod1"; Godot's
## importer also builds mesh LODs, which MultiMesh scatter uses on its own.
## Surfaces get the shared PropFinishes materials. Missing files return null so
## callers can fall back to their stand-in shapes.
class_name PropModels
extends RefCounted

const PROP_DIR := "res://world/spring_court/manor_estate/props/models/"
const FLORA_DIR := "res://world/spring_court/manor_estate/flora/models/"

static var _cache: Dictionary = {}


## [lod0, lod1] meshes for a prop id, or [] when no model exists.
static func prop(id: StringName) -> Array:
	return pair(PROP_DIR + String(id) + ".glb", String(id))


## [lod0, lod1] meshes from a model file, finishes applied, or [] if missing.
static func pair(path: String, node_name: String, finish_override: Material = null) -> Array:
	if _cache.has(path):
		return _cache[path]
	var out: Array = []
	if ResourceLoader.exists(path):
		var scene := (load(path) as PackedScene).instantiate()
		var lod0 := _mesh(scene, node_name)
		if lod0 != null:
			var lod1 := _mesh(scene, node_name + "_lod1")
			out = [_finished(lod0, finish_override), _finished(lod1, finish_override) if lod1 else null]
		scene.free()
	_cache[path] = out
	return out


## The importer turns name suffixes into node types ("spinning_wheel" becomes a
## VehicleWheel3D holding the mesh), so match MeshInstance3Ds by their own name
## or, failing that, by the name of the node that wraps them.
static func _mesh(scene: Node, node_name: String) -> Mesh:
	var lod1 := node_name.ends_with("_lod1")
	for n: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		if n.name == node_name:
			return n.mesh
	for n: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		if String(n.name).ends_with("_lod1") == lod1 and n.get_parent() != scene:
			return n.mesh
	return null


## Puts every surface of `mesh` on its shared finish material (in place: the
## imported mesh is ours alone, and editing it keeps the importer's LODs).
static func _finished(m: Mesh, finish_override: Material) -> Mesh:
	for i in m.get_surface_count():
		var src := m.surface_get_material(i)
		var surface := StringName(src.resource_name) if src != null else &"opaque"
		m.surface_set_material(i, finish_override if finish_override != null else PropFinishes.material(surface))
	return m


static func tri_count(m: Mesh) -> int:
	var n := 0
	for i in m.get_surface_count():
		n += (m.surface_get_arrays(i)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	return n
