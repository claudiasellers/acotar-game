## Builds one outdoor part of the estate with as few draw calls as possible:
## every solid piece is merged into one mesh per material, every collider goes
## into one StaticBody3D on layer 1, and repeated props become MultiMeshes.
##
## Usage: var b := GroundsBatch.new(parent, "RoseGarden"); b.box(...); b.prop(...); b.flush()
class_name GroundsBatch
extends RefCounted

var root: Node3D
var body: StaticBody3D
var _surfaces: Dictionary = {}     # key -> [SurfaceTool, Material]
var _props: Dictionary = {}        # prop id -> Array[Transform3D]
## Visibility range for merged meshes (0 = always drawn).
var vis_end: float = 0.0


func _init(parent: Node3D, node_name: String) -> void:
	root = Node3D.new()
	root.name = node_name
	parent.add_child(root)
	body = StaticBody3D.new()
	body.name = "Collision"
	body.collision_layer = EstateKit.WORLD_LAYER
	body.collision_mask = 0
	root.add_child(body)


# --- Geometry ----------------------------------------------------------------

## Appends any mesh's first surface, transformed, to the merged mesh of `material`.
func add_mesh(mesh: Mesh, xform: Transform3D, material: Material, key_suffix: String = "") -> void:
	var size := (mesh as BoxMesh).size if ManorMeshMerger._plain_box(mesh) else Vector3.ONE
	add_arrays(ManorMeshMerger._arrays_of(mesh, 0), xform, material, key_suffix, size)


## add_mesh() for arrays in hand (SurfaceTool.commit_to_arrays): a mesh would
## cost a trip to the GPU and back (3,265 of them took 2.8 s on Metal).
func add_arrays(arrays: Array, xform: Transform3D, material: Material, key_suffix: String = "", size: Vector3 = Vector3.ONE) -> void:
	var key := str(material.get_instance_id()) + key_suffix
	if not _surfaces.has(key):
		_surfaces[key] = [_Bucket.new(), material]
	(_surfaces[key][0] as _Bucket).add(arrays, xform, size)


func add_box_shape(xform: Transform3D, size: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.transform = xform
	body.add_child(cs)


func add_cyl_shape(base: Vector3, radius: float, height: float) -> void:
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	cs.shape = shape
	cs.position = base + Vector3.UP * height * 0.5
	body.add_child(cs)


## A box centred at `center`, turned by `yaw` (or a full basis).
func box(center: Vector3, size: Vector3, material: Material, collide: bool = true, yaw: float = 0.0, basis: Variant = null) -> void:
	var b: Basis = basis if basis != null else Basis(Vector3.UP, yaw)
	var mesh := _box_mesh(size)
	var xf := Transform3D(b, center)
	add_mesh(mesh, xf, material)
	if collide:
		add_box_shape(xf, size)


## A box between two points on the ground plane (walls, rails, beams).
func span(a: Vector3, b: Vector3, thickness: float, height: float, material: Material, collide: bool = true) -> void:
	var d := Vector3(b.x - a.x, 0.0, b.z - a.z)
	var length := d.length()
	if length < 0.01:
		return
	var yaw := atan2(-d.z, d.x)
	var center := (a + b) * 0.5 + Vector3.UP * height * 0.5
	box(center, Vector3(length, height, thickness), material, collide, yaw)


func cylinder(base: Vector3, radius: float, height: float, material: Material, collide: bool = true,
		segments: int = 12, top_radius: float = -1.0) -> void:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top_radius < 0.0 else top_radius
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 1
	add_mesh(mesh, Transform3D(Basis(), base + Vector3.UP * height * 0.5), material)
	if collide:
		add_cyl_shape(base, maxf(radius, mesh.top_radius), height)


func sphere(center: Vector3, radius: float, material: Material, height: float = -1.0, hemisphere: bool = false, segments: int = 16) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0 if height < 0.0 else height
	mesh.is_hemisphere = hemisphere
	mesh.radial_segments = segments
	mesh.rings = maxi(segments / 2, 4)
	if hemisphere:
		mesh.height = radius if height < 0.0 else height
	add_mesh(mesh, Transform3D(Basis(), center), material)


func torus(center: Vector3, inner: float, outer: float, material: Material, basis: Basis = Basis()) -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 24
	mesh.ring_segments = 8
	add_mesh(mesh, Transform3D(basis, center), material)


## A gable roof: a prism whose ridge runs along local X, `size` = (length, height, depth).
func gable(center_base: Vector3, size: Vector3, material: Material, yaw: float = 0.0) -> void:
	var mesh := PrismMesh.new()
	mesh.size = Vector3(size.z, size.y, size.x)
	var b := Basis(Vector3.UP, yaw) * Basis(Vector3.UP, PI * 0.5)
	add_mesh(mesh, Transform3D(b, center_base + Vector3.UP * size.y * 0.5), material)


## A cone/spire (pointed cylinder).
func cone(base: Vector3, radius: float, height: float, material: Material, segments: int = 12) -> void:
	cylinder(base, radius, height, material, false, segments, 0.0)


## A ramp: a box tilted to climb `rise` over `run` along local -Z from `bottom_center`.
func ramp(bottom_center: Vector3, width: float, run: float, rise: float, yaw: float, material: Material) -> void:
	var angle := atan2(rise, run)
	var length := sqrt(run * run + rise * rise)
	var b := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, angle)
	var fwd := Basis(Vector3.UP, yaw) * Vector3(0, 0, -1)
	var center := bottom_center + fwd * run * 0.5 + Vector3.UP * (rise * 0.5 - 0.1)
	if material == null:     # collider only (under visual stair treads)
		add_box_shape(Transform3D(b, center), Vector3(width, 0.2, length))
	else:
		box(center, Vector3(width, 0.2, length), material, true, 0.0, b)


## A flat strip that follows the ground along a polyline (paths, the drive).
func drape_path(points: PackedVector2Array, width: float, material: Material, lift: float = 0.05, step: float = 2.0) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dist := 0.0
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		var seg := a.distance_to(b)
		var n := maxi(1, ceili(seg / step))
		var dir := (b - a) / maxf(seg, 0.001)
		var side := Vector2(-dir.y, dir.x) * width * 0.5
		for k in n:
			var p0 := a.lerp(b, float(k) / n)
			var p1 := a.lerp(b, float(k + 1) / n)
			var v := [p0 - side, p0 + side, p1 + side, p1 - side]
			var verts: Array[Vector3] = []
			for q: Vector2 in v:
				verts.append(Vector3(q.x, WorldHeight.height_at(q.x, q.y) + lift, q.y))
			var u0 := dist + seg * float(k) / n
			var u1 := dist + seg * float(k + 1) / n
			var uvs := [Vector2(0, u0), Vector2(1, u0), Vector2(1, u1), Vector2(0, u1)]
			for idx in [0, 2, 1, 0, 3, 2]:
				st.set_normal(Vector3.UP)
				st.set_uv(uvs[idx] * 0.25)
				st.add_vertex(verts[idx])
		dist += seg
	add_arrays(st.commit_to_arrays(), Transform3D(), material, "|path")


## Like drape_path, for curving walks (L56-3): one continuous ribbon whose
## cross-sections are mitred at every bend, so no wedge of lawn shows
## through on the outside of a curve. Each straight run is subdivided to
## `step` so the ribbon follows the ground.
func drape_ribbon(points: PackedVector2Array, width: float, material: Material, lift: float = 0.08, step: float = 1.0) -> void:
	if points.size() < 2:
		return
	var dense := PackedVector2Array()
	for i in points.size() - 1:
		var n := maxi(1, ceili(points[i].distance_to(points[i + 1]) / step))
		for k in n:
			dense.append(points[i].lerp(points[i + 1], float(k) / n))
	dense.append(points[-1])
	var half := width * 0.5
	var left := PackedVector3Array()
	var right := PackedVector3Array()
	var us := PackedFloat32Array()
	var dist := 0.0
	for i in dense.size():
		var d_in := (dense[i] - dense[maxi(i - 1, 0)]).normalized()
		var d_out := (dense[mini(i + 1, dense.size() - 1)] - dense[i]).normalized()
		if i == 0:
			d_in = d_out
		if i == dense.size() - 1:
			d_out = d_in
		var tangent := (d_in + d_out).normalized()
		var normal := Vector2(-tangent.y, tangent.x)
		# mitre: widen where the walk bends so the edges stay parallel
		var mitre := half / maxf(normal.dot(Vector2(-d_out.y, d_out.x)), 0.5)
		if i > 0:
			dist += dense[i].distance_to(dense[i - 1])
		for sd: float in [-1.0, 1.0]:
			var q := dense[i] + normal * mitre * sd
			var v := Vector3(q.x, WorldHeight.height_at(q.x, q.y) + lift, q.y)
			if sd < 0.0:
				left.append(v)
			else:
				right.append(v)
		us.append(dist)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in dense.size() - 1:
		var v := [left[i], right[i], right[i + 1], left[i + 1]]
		var uvs := [Vector2(0, us[i]), Vector2(1, us[i]), Vector2(1, us[i + 1]), Vector2(0, us[i + 1])]
		for idx in [0, 2, 1, 0, 3, 2]:
			st.set_normal(Vector3.UP)
			st.set_uv(uvs[idx] * 0.25)
			st.add_vertex(v[idx])
	add_mesh(st.commit(), Transform3D(), material, "|path")


## A flat disc or ellipse at height y (water surfaces, paving).
func disc(center: Vector3, radii: Vector2, material: Material, segments: int = 48) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in segments:
		var a0 := TAU * i / segments
		var a1 := TAU * (i + 1) / segments
		var p := [Vector3.ZERO, Vector3(cos(a1) * radii.x, 0, sin(a1) * radii.y), Vector3(cos(a0) * radii.x, 0, sin(a0) * radii.y)]
		for v: Vector3 in p:
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(v.x, v.z) * 0.1)
			st.add_vertex(center + v)
	add_arrays(st.commit_to_arrays(), Transform3D(), material, "|path")


# --- Props -------------------------------------------------------------------

## A catalogue prop standing at `pos` (world), turned by `yaw`, uniform `scale`.
func prop(id: StringName, pos: Vector3, yaw: float = 0.0, scale: float = 1.0) -> void:
	if not _props.has(id):
		_props[id] = []
	(_props[id] as Array).append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scale), pos))


## A prop with a whole transform of its own, e.g. sheared so that a run of
## pergola bays climbs a slope with its posts still plumb.
func prop_xform(id: StringName, xform: Transform3D) -> void:
	if not _props.has(id):
		_props[id] = []
	(_props[id] as Array).append(xform)


## A prop standing on the ground at x/z.
func prop_on_ground(id: StringName, x: float, z: float, yaw: float = 0.0, scale: float = 1.0, lift: float = 0.0) -> void:
	prop(id, Vector3(x, WorldHeight.height_at(x, z) + lift, z), yaw, scale)


func prop_count(id: StringName = &"") -> int:
	if id != &"":
		return (_props.get(id, []) as Array).size()
	var n := 0
	for k in _props:
		n += (_props[k] as Array).size()
	return n


# --- Finish ------------------------------------------------------------------

## Commits merged meshes and prop multimeshes as nodes under root.
func flush() -> Node3D:
	finish(null)
	return root


## flush(), across frames with a `pace`: await it.
func finish(pace: BuildPace) -> void:
	var i := 0
	for key in _surfaces:
		var bucket: _Bucket = _surfaces[key][0]
		var mi := MeshInstance3D.new()
		mi.name = "Mesh_%d" % i
		mi.mesh = bucket.commit()
		mi.material_override = _surfaces[key][1]
		if vis_end > 0.0:
			mi.visibility_range_end = vis_end
		root.add_child(mi)
		i += 1
		if pace:
			await pace.tick()
	_surfaces.clear()
	for id: StringName in _props:
		_flush_prop(id, _props[id])
		if pace:
			await pace.tick()
	_props.clear()
	if body.get_child_count() == 0:
		body.free()


func _flush_prop(id: StringName, xforms: Array) -> void:
	var template := PropLib.build(id)
	var parts := []
	for mi in template.find_children("*", "MeshInstance3D", true, false):
		parts.append([mi, _relative(template, mi)])
	var shapes := []
	for cs in template.find_children("*", "CollisionShape3D", true, false):
		shapes.append([cs.shape, _relative(template, cs)])
	var p := 0
	for part in parts:
		var src: MeshInstance3D = part[0]
		var rel: Transform3D = part[1]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = src.mesh
		mm.instance_count = xforms.size()
		for j in xforms.size():
			mm.set_instance_transform(j, (xforms[j] as Transform3D) * rel)
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "%s_%d" % [id, p]
		mmi.multimesh = mm
		mmi.material_override = src.material_override
		mmi.cast_shadow = src.cast_shadow
		root.add_child(mmi)
		p += 1
	for s in shapes:
		var shape: Shape3D = s[0]
		var rel: Transform3D = s[1]
		for xf: Transform3D in xforms:
			var sc := xf.basis.get_scale().x
			var cs := CollisionShape3D.new()
			if absf(sc - 1.0) > 0.01 and shape is BoxShape3D:
				var bs := BoxShape3D.new()
				bs.size = (shape as BoxShape3D).size * sc
				cs.shape = bs
			else:
				cs.shape = shape
			var t := xf * rel
			cs.transform = Transform3D(t.basis.orthonormalized(), t.origin)
			body.add_child(cs)
	template.free()


static func _relative(top: Node, node: Node3D) -> Transform3D:
	var t := node.transform
	var p := node.get_parent()
	while p != null and p != top:
		if p is Node3D:
			t = (p as Node3D).transform * t
		p = p.get_parent()
	return t


## One merged surface, gathered in packed arrays. A piece missing a channel
## others have gets SurfaceTool's defaults, as append_from() gave it.
class _Bucket:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var tangents := PackedFloat32Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()

	func add(arrays: Array, xform: Transform3D, size: Vector3) -> void:
		var base := verts.size()
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		verts.append_array(xform.scaled_local(size) * v)
		_add_normals(arrays[Mesh.ARRAY_NORMAL], v.size(), xform)
		_add_tangents(arrays[Mesh.ARRAY_TANGENT], v.size(), xform.basis, base)
		var uv: Variant = arrays[Mesh.ARRAY_TEX_UV]
		if uv != null:
			uvs.resize(base)
			uvs.append_array(uv)
		var col: Variant = arrays[Mesh.ARRAY_COLOR]
		if col != null:
			var have := colors.size()
			colors.resize(base)
			for i in range(have, base):
				colors[i] = Color.BLACK
			colors.append_array(col)
		var idx: Variant = arrays[Mesh.ARRAY_INDEX]
		if idx == null:
			for i in v.size():
				indices.append(base + i)
		else:
			for i: int in idx:
				indices.append(base + i)

	func _add_normals(n: Variant, count: int, xform: Transform3D) -> void:
		if n == null:
			normals.resize(normals.size() + count)
			return
		var turn := xform.basis.inverse().transposed()
		var src: PackedVector3Array = n
		if turn.is_conformal() and is_equal_approx(turn.get_scale().x, 1.0):
			normals.append_array(Transform3D(turn, Vector3.ZERO) * src)
			return
		for x in src:
			normals.append((turn * x).normalized())

	func _add_tangents(t: Variant, count: int, b: Basis, base: int) -> void:
		if t == null:
			if not tangents.is_empty():
				_pad_tangents(base + count)
			return
		_pad_tangents(base)
		var src: PackedFloat32Array = t
		for i in count:
			var d := (b * Vector3(src[i * 4], src[i * 4 + 1], src[i * 4 + 2])).normalized()
			tangents.append_array([d.x, d.y, d.z, src[i * 4 + 3]])

	func _pad_tangents(vertices: int) -> void:
		while tangents.size() < vertices * 4:
			tangents.append_array([0.0, 0.0, 0.0, 1.0])

	func commit() -> ArrayMesh:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_INDEX] = indices
		if not tangents.is_empty():
			_pad_tangents(verts.size())
			arrays[Mesh.ARRAY_TANGENT] = tangents
		if not uvs.is_empty():
			uvs.resize(verts.size())
			arrays[Mesh.ARRAY_TEX_UV] = uvs
		if not colors.is_empty():
			colors.resize(verts.size())
			arrays[Mesh.ARRAY_COLOR] = colors
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return mesh


static var _box_cache: Dictionary = {}


static func _box_mesh(size: Vector3) -> BoxMesh:
	var key := "%.3f|%.3f|%.3f" % [size.x, size.y, size.z]
	if _box_cache.has(key):
		return _box_cache[key]
	var m := BoxMesh.new()
	m.size = size
	_box_cache[key] = m
	return m
