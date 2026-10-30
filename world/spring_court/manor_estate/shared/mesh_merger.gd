## Cuts draw calls by merging many static MeshInstance3Ds into one mesh per
## material (R9). Colliders, lights and anything interactive stay as they are.
class_name ManorMeshMerger
extends RefCounted


## Merges every mergeable MeshInstance3D under `source` into new MeshInstance3Ds
## (one per material) added under `target`, then frees the originals.
## `skip` lists node classes whose subtrees must stay separate (doors that open,
## stations, pickups). Returns the number of meshes merged.
static func merge(source: Node, target: Node3D, vis_end: float = 0.0, skip: Array = []) -> int:
	return merge_sources([source], target, vis_end, skip)


## Same as merge() over several source subtrees at once (e.g. all props of a room).
static func merge_sources(sources: Array, target: Node3D, vis_end: float = 0.0, skip: Array = []) -> int:
	var candidates: Array[MeshInstance3D] = []
	for source in sources:
		for node in (source as Node).find_children("*", "MeshInstance3D", true, false):
			var m := node as MeshInstance3D
			if m.mesh != null and not _under_skipped(m, source, skip):
				candidates.append(m)
	var buckets: Dictionary = {}   # key -> [material, verts, normals, colors, uvs, indices]
	var merged: Array[MeshInstance3D] = []
	var inv := target.global_transform.affine_inverse() if target.is_inside_tree() else _global_xform(target, target).affine_inverse()
	for mi in candidates:
		var xform := inv * _global_xform(mi, target)
		var nbasis := xform.basis.inverse().transposed()
		for s in mi.mesh.get_surface_count():
			if mi.mesh is ArrayMesh and (mi.mesh as ArrayMesh).surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
				continue
			var mat: Material = mi.get_surface_override_material(s)
			if mat == null:
				mat = mi.material_override
			if mat == null:
				mat = mi.mesh.surface_get_material(s)
			var tint := Color.WHITE
			var key: Variant = mat
			if _is_plain(mat):
				var sm := mat as StandardMaterial3D
				tint = sm.albedo_color
				key = "vc|%.2f|%.2f|%s" % [sm.roughness, sm.metallic, sm.clearcoat_enabled]
			if not buckets.has(key):
				var shared: Material = mat
				if key is String:
					shared = _vertex_material(mat as StandardMaterial3D, key)
				buckets[key] = [shared, PackedVector3Array(), PackedVector3Array(), PackedColorArray(), PackedVector2Array(), PackedInt32Array()]
			var b: Array = buckets[key]
			var arrays := mi.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
			var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
			var cols: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
			var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var base: int = (b[1] as PackedVector3Array).size()
			for i in verts.size():
				b[1].append(xform * verts[i])
				b[2].append((nbasis * normals[i]).normalized() if i < normals.size() else Vector3.UP)
				b[3].append(tint * cols[i] if i < cols.size() else tint)
				b[4].append(uvs[i] if i < uvs.size() else Vector2.ZERO)
			if idx.is_empty():
				for i in verts.size():
					b[5].append(base + i)
			else:
				for i in idx:
					b[5].append(base + i)
		merged.append(mi)
	for key in buckets:
		var b: Array = buckets[key]
		if (b[1] as PackedVector3Array).is_empty():
			continue
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = b[1]
		arrays[Mesh.ARRAY_NORMAL] = b[2]
		arrays[Mesh.ARRAY_COLOR] = b[3]
		arrays[Mesh.ARRAY_TEX_UV] = b[4]
		arrays[Mesh.ARRAY_INDEX] = b[5]
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(0, b[0])
		var out := MeshInstance3D.new()
		out.name = "Merged"
		out.mesh = mesh
		if vis_end > 0.0:
			out.visibility_range_end = vis_end
			out.visibility_range_end_margin = 5.0
		target.add_child(out)
	for mi in merged:
		mi.get_parent().remove_child(mi)
		mi.free()
	return merged.size()


## Plain colour materials fold into one shared vertex-colour material.
static func _is_plain(mat: Material) -> bool:
	var sm := mat as StandardMaterial3D
	if sm == null or sm.albedo_texture != null or sm.emission_enabled or sm.rim_enabled:
		return false
	return sm.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and not sm.vertex_color_use_as_albedo


static var _vertex_mats: Dictionary = {}

static func _vertex_material(like: StandardMaterial3D, key: String) -> StandardMaterial3D:
	if _vertex_mats.has(key):
		return _vertex_mats[key]
	var m := like.duplicate() as StandardMaterial3D
	m.albedo_color = Color.WHITE
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	_vertex_mats[key] = m
	return m


static func _under_skipped(node: Node, stop: Node, skip: Array) -> bool:
	var n := node.get_parent()
	while n != null and n != stop:
		for cls in skip:
			if is_instance_of(n, cls):
				return true
		n = n.get_parent()
	return false


## Transform of `node` relative to world, computed from local transforms so it
## also works before the tree is entered.
static func _global_xform(node: Node3D, target: Node3D) -> Transform3D:
	if node.is_inside_tree():
		return node.global_transform
	var x := node.transform
	var p := node.get_parent()
	while p != null and p is Node3D:
		x = (p as Node3D).transform * x
		p = p.get_parent()
	return x
