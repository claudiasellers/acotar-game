extends SceneTree
## One-off (render program T2): saves every built-in StandardMaterial3D of the
## given scenes as a CandyMaterial .tres under data/render/scene_materials/ and
## prints "MAP <scene>::<sub id> -> <tres>" for tools/render/patch_scene_materials.py.
##   godot --headless -s tools/render/convert_scene_materials.gd -- <scene.tscn>...

const OUT := "res://data/render/scene_materials/"

var _seen := {}


func _init() -> void:
	for path in OS.get_cmdline_user_args():
		var ps := load(path) as PackedScene
		var root := ps.instantiate()
		_visit_node(root)
		root.free()
	quit()


func _visit_node(n: Node) -> void:
	_visit_object(n, 0)
	for c in n.get_children(true):
		_visit_node(c)


func _visit_object(o: Object, depth: int) -> void:
	if o == null or depth > 4:
		return
	for p in o.get_property_list():
		if p.type != TYPE_OBJECT:
			continue
		var v: Variant = o.get(p.name)
		if v is BaseMaterial3D:
			_convert(v as BaseMaterial3D)
		elif v is Mesh:
			var mesh := v as Mesh
			for s in mesh.get_surface_count():
				var m := mesh.surface_get_material(s)
				if m is BaseMaterial3D:
					_convert(m as BaseMaterial3D)
		elif v is Resource and not (v is Script) and not (v is PackedScene):
			_visit_object(v, depth + 1)


func _convert(m: BaseMaterial3D) -> void:
	var rp := m.resource_path
	if _seen.has(rp) or not rp.contains(".tscn::"):
		return
	_seen[rp] = true
	var scene := rp.get_slice("::", 0).get_file().get_basename()
	var sub := rp.get_slice("::", 1).get_slice("_", 1)
	var out := OUT + "%s_%s.tres" % [scene, sub]
	var c := CandyMaterial.from_base(m)
	c.resource_name = "%s_%s" % [scene, sub]
	var err := ResourceSaver.save(c, out)
	print("MAP %s -> %s (%s)" % [rp, out, error_string(err)])
