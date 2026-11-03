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


## Merged meshes by cache key, for builds that come out the same every time
## (the house on each stream-in): the merge itself cost ~2 s per stream-in.
static var _merged_cache: Dictionary = {}


## Same as merge() over several source subtrees at once (e.g. all props of a room).
## With a `cache_key`, the meshes merged the first time are reused after; the
## caller promises the sources are identical each time.
static func merge_sources(sources: Array, target: Node3D, vis_end: float = 0.0, skip: Array = [],
		cache_key: String = "") -> int:
	var candidates := _candidates(sources, skip)
	_merge_candidates(candidates, target, vis_end, cache_key, null)
	return candidates.size()


## merge_sources() across frames: await it.
static func merge_paced(sources: Array, target: Node3D, vis_end: float, skip: Array, cache_key: String,
		pace: BuildPace) -> void:
	await _merge_candidates(_candidates(sources, skip), target, vis_end, cache_key, pace)


static func _candidates(sources: Array, skip: Array) -> Array[MeshInstance3D]:
	var candidates: Array[MeshInstance3D] = []
	for source in sources:
		for node in (source as Node).find_children("*", "MeshInstance3D", true, false):
			var m := node as MeshInstance3D
			if m.mesh != null and not _under_skipped(m, source, skip):
				candidates.append(m)
	return candidates


static func _merge_candidates(candidates: Array[MeshInstance3D], target: Node3D, vis_end: float, cache_key: String,
		pace: BuildPace) -> void:
	var meshes: Array = _merged_cache.get(cache_key, []) if cache_key != "" else []
	if meshes.is_empty():
		await _merge_arrays(candidates, target, meshes, pace)
		if cache_key != "":
			_merged_cache[cache_key] = meshes
	for mesh: ArrayMesh in meshes:
		var out := MeshInstance3D.new()
		out.name = "Merged"
		out.mesh = mesh
		if vis_end > 0.0:
			out.visibility_range_end = vis_end
			out.visibility_range_end_margin = 5.0
		target.add_child(out)
	for mi in candidates:
		mi.get_parent().remove_child(mi)
		mi.free()
		if pace:
			await pace.tick()


## One ArrayMesh per material bucket from `candidates`, in `target`'s space,
## appended to `meshes`.
static func _merge_arrays(candidates: Array[MeshInstance3D], target: Node3D, meshes: Array, pace: BuildPace) -> void:
	var buckets: Dictionary = {}   # key -> [material, verts, normals, colors, uvs, indices]
	var inv := target.global_transform.affine_inverse() if target.is_inside_tree() else _global_xform(target, target).affine_inverse()
	for mi in candidates:
		var placed := inv * _global_xform(mi, target)
		var nbasis := placed.basis.inverse().transposed()
		# A box comes from one cube: its normals and UVs don't change with its size.
		var xform := placed.scaled_local((mi.mesh as BoxMesh).size) if _plain_box(mi.mesh) else placed
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
				var sm := mat as CandyMaterial
				tint = sm.albedo_color
				key = "vc|%.2f|%.2f|%s" % [sm.roughness, sm.metallic, sm.clearcoat_enabled]
			if not buckets.has(key):
				var shared: Material = mat
				if key is String:
					shared = _vertex_material(mat as CandyMaterial, key)
				buckets[key] = [shared, PackedVector3Array(), PackedVector3Array(), PackedColorArray(), PackedVector2Array(), PackedInt32Array()]
			var b: Array = buckets[key]
			var arrays := _arrays_of(mi.mesh, s)
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
		if pace:
			await pace.tick()
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
		meshes.append(mesh)
		if pace:
			await pace.tick()


## Mesh arrays by what they are, not which object holds them. A read comes back
## from the GPU, 2.5 ms each on Metal, and the house has 8,000 of them, nearly
## all boxes and primitives of a few sizes.
static var _arrays: Dictionary = {}
## The same for one-off meshes, by object, until forget(). Holds them so an id
## can't come round again.
static var _mesh_arrays: Dictionary = {}
static var _kept: Array[Mesh] = []


static func _arrays_of(mesh: Mesh, surface: int) -> Array:
	var key := _shape_key(mesh)
	if key != "":
		if not _arrays.has(key):
			var shape := mesh
			if _plain_box(mesh):
				shape = BoxMesh.new()
				shape.size = Vector3.ONE
			_arrays[key] = shape.surface_get_arrays(surface)
		return _arrays[key]
	var id := "%d|%d" % [mesh.get_instance_id(), surface]
	if not _mesh_arrays.has(id):
		remember(mesh, surface, mesh.surface_get_arrays(surface))
	return _mesh_arrays[id]


## Arrays a builder still has in hand when it makes a mesh, so nothing reads them back.
static func remember(mesh: Mesh, surface: int, arrays: Array) -> void:
	_mesh_arrays["%d|%d" % [mesh.get_instance_id(), surface]] = arrays
	_kept.append(mesh)


## Drops the one-off meshes' arrays: a house build's are done with once it has merged.
static func forget() -> void:
	_mesh_arrays.clear()
	_kept.clear()


## SurfaceTool.append_from() without the read. With `surface_data` off, position
## only, for a tool whose vertices have no normals or UVs of their own.
static func append(st: SurfaceTool, mesh: Mesh, xform: Transform3D, surface_data: bool = true) -> void:
	var arrays := _arrays_of(mesh, 0)
	var size := (mesh as BoxMesh).size if _plain_box(mesh) else Vector3.ONE
	var verts: PackedVector3Array = xform.scaled_local(size) * (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array)
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var turn := xform.basis.inverse().transposed()
	for i: int in arrays[Mesh.ARRAY_INDEX]:
		if surface_data:
			st.set_normal((turn * normals[i]).normalized())
			st.set_uv(uvs[i])
		st.add_vertex(verts[i])


## SurfaceTool.commit() that remembers. `into` adds a surface to it.
static func commit(st: SurfaceTool, into: ArrayMesh = null) -> ArrayMesh:
	var mesh := into if into != null else ArrayMesh.new()
	var arrays := st.commit_to_arrays()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	remember(mesh, mesh.get_surface_count() - 1, arrays)
	return mesh


static func _plain_box(mesh: Mesh) -> bool:
	var box := mesh as BoxMesh
	return box != null and box.subdivide_width == 0 and box.subdivide_height == 0 and box.subdivide_depth == 0


## What makes a primitive the one it is, or "" for any other mesh.
static func _shape_key(mesh: Mesh) -> String:
	if _plain_box(mesh):
		return "box"
	if mesh is CylinderMesh:
		var c := mesh as CylinderMesh
		return "cyl|%s|%s|%s|%d|%d|%s|%s" % [c.top_radius, c.bottom_radius, c.height, c.radial_segments, c.rings, c.cap_top, c.cap_bottom]
	if mesh is SphereMesh:
		var c := mesh as SphereMesh
		return "sph|%s|%s|%d|%d|%s" % [c.radius, c.height, c.radial_segments, c.rings, c.is_hemisphere]
	if mesh is PrismMesh:
		var c := mesh as PrismMesh
		return "prism|%s|%s|%d%d%d" % [c.left_to_right, c.size, c.subdivide_width, c.subdivide_height, c.subdivide_depth]
	if mesh is TorusMesh:
		var c := mesh as TorusMesh
		return "tor|%s|%s|%d|%d" % [c.inner_radius, c.outer_radius, c.rings, c.ring_segments]
	return ""


## Plain colour materials fold into one shared vertex-colour material.
static func _is_plain(mat: Material) -> bool:
	var sm := mat as CandyMaterial
	if sm == null or sm.albedo_texture != null or sm.emission_enabled or sm.rim_enabled:
		return false
	return sm.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and not sm.vertex_color_use_as_albedo


static var _vertex_mats: Dictionary = {}

static func _vertex_material(like: CandyMaterial, key: String) -> CandyMaterial:
	if _vertex_mats.has(key):
		return _vertex_mats[key]
	var m := like.duplicate() as CandyMaterial
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
