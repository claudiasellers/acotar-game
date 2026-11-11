## The court's tree set (finish plan T1/T2): one CSV row per model with its
## source, licence, triangles (bark and leaves), size and file bytes, written to
## world/spring_court/wider/assets/trees/trees.csv. Fails on a file over 5 MB.
## tools/mq/godot.sh -s tools/court/court_tree_intake.gd
extends SceneTree

const DIR := "res://world/spring_court/wider/assets/trees/"
const MAX_BYTES := 5 * 1024 * 1024
const SOURCES := {
	"qtz": ["Quaternius Stylized Nature MegaKit (free)", "CC0 1.0"],
	"ez": ["EZ-Tree by Daniel Greenheck (tools/court/eztree)", "MIT (code); geometry ours"],
}


func _initialize() -> void:
	var rows: PackedStringArray = ["file,source,licence,tris,bark_tris,leaf_tris,width_m,height_m,bytes"]
	var too_big: PackedStringArray = []
	for sub: String in SOURCES:
		var d := DIR + sub + "/"
		var files := Array(DirAccess.get_files_at(d))
		files.sort()
		for f: String in files:
			var bytes := FileAccess.get_file_as_bytes(d + f).size()
			if bytes > MAX_BYTES:
				too_big.append("%s%s %d" % [sub, f, bytes])
			if not (f.ends_with(".glb") or f.ends_with(".gltf")):
				continue
			var inst := (load(d + f) as PackedScene).instantiate()
			var counts := _count(inst)
			inst.free()
			var model_bytes := bytes
			if f.ends_with(".gltf") and FileAccess.file_exists(d + f.get_basename() + ".bin"):
				model_bytes += FileAccess.get_file_as_bytes(d + f.get_basename() + ".bin").size()
			var aabb: AABB = counts[3]
			rows.append("%s/%s,%s,%s,%d,%d,%d,%.1f,%.1f,%d" % [sub, f, SOURCES[sub][0], SOURCES[sub][1],
				counts[0] + counts[1], counts[0], counts[1], maxf(aabb.size.x, aabb.size.z), aabb.size.y, model_bytes])
	var out := FileAccess.open(DIR + "trees.csv", FileAccess.WRITE)
	out.store_string("\n".join(rows) + "\n")
	out.close()
	print("\n".join(rows))
	if not too_big.is_empty():
		push_error("files over 5 MB: %s" % ", ".join(too_big))
		quit(1)
		return
	quit()


## [bark tris, leaf tris, surfaces, aabb] over every mesh in the scene. A
## surface is leaves when its material's name says so (ez_leaves, Leaves_*).
func _count(root: Node) -> Array:
	var bark := 0
	var leaves := 0
	var aabb := AABB()
	var first := true
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		var xf := _to_root(mi, root)
		var box := xf * mi.mesh.get_aabb()
		aabb = box if first else aabb.merge(box)
		first = false
		for i in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(i)
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
			var tris := (idx.size() if not idx.is_empty() else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
			var mat := mi.mesh.surface_get_material(i)
			var name := String(mat.resource_name).to_lower() if mat != null else ""
			if name.contains("lea") or name.contains("flower") or name.contains("needle"):
				leaves += tris
			else:
				bark += tris
	return [bark, leaves, 0, aabb]


func _to_root(n: Node3D, root: Node) -> Transform3D:
	var xf := n.transform
	var p := n.get_parent()
	while p != null and p != root:
		if p is Node3D:
			xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf
