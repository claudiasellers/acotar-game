## prop_kit.lathe's pointed tips face out (L35-9). The fans that close a lathe
## at a zero-radius tip were wound against the rest of the surface, so every
## cone point, finial, raceme and dome crown in the Blender-built models faced
## inward and shaded flat and dark. The models were re-exported with the fix;
## here every such tip in the shipped models must face out.
extends GutTest

const DIRS := ["res://world/spring_court/manor_estate/props/models/", "res://world/spring_court/manor_estate/flora/models/",
		"res://world/spring_court/manor_estate/art/frames/", "res://art/calanmai/", "res://art/dinner/", "res://art/house/",
		"res://story/act4/models/"]
## Models still waiting for their own lane to re-export them (L38's rooms).
const PENDING_REEXPORT := "res://tests/unit/manor_estate/lathe_tips_pending.txt"
## A lathe tip closes at least this many sides; fewer is some other apex.
const MIN_FAN := 5


## Every lathe tip in the mesh: a point closed by a fan of MIN_FAN or more
## triangles whose far corners form a ring round it (all at one distance), the
## point standing clear of the ring's plane. For each, [the side the tip faces,
## the side the surface next to its ring faces], +1 out from the lathe's axis
## or -1 in. A lathe drawn top-down faces in all over, which is fine; the bug
## was a tip facing the other way from the surface it closes. Tips whose ring
## has no clear neighbouring surface (a bare cone) are left out.
static func tip_sides(m: Mesh) -> Array:
	var out := []
	for s in m.get_surface_count():
		var a := m.surface_get_arrays(s)
		var verts: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
		var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
		var tris_at := {}   # snapped position -> [triangle numbers]
		for t in idx.size() / 3:
			for c in 3:
				var k := verts[idx[t * 3 + c]].snapped(Vector3.ONE * 1e-4)
				if not tris_at.has(k):
					tris_at[k] = []
				(tris_at[k] as Array).append(t)
		for k: Vector3 in tris_at:
			var fan: Array = tris_at[k]
			if fan.size() < MIN_FAN:
				continue
			var nb := {}
			var apex_n := Vector3.ZERO
			for t: int in fan:
				for c in 3:
					var vi := idx[t * 3 + c]
					var q := verts[vi].snapped(Vector3.ONE * 1e-4)
					if q == k:
						apex_n += norms[vi]
					else:
						nb[q] = true
			if nb.size() != fan.size():
				continue
			var c0 := Vector3.ZERO
			for q: Vector3 in nb:
				c0 += q
			c0 /= nb.size()
			var r0 := (nb.keys()[0] as Vector3).distance_to(k)
			var even := r0 > 1e-3
			for q: Vector3 in nb:
				even = even and absf(q.distance_to(k) - r0) < r0 * 0.02
			if not even or k.distance_to(c0) < (nb.keys()[0] as Vector3).distance_to(c0) * 0.15:
				continue
			# the surface next to the ring: normals at a ring corner from the
			# triangles that are not part of the fan
			var band := 0.0
			for q: Vector3 in nb:
				var bn := Vector3.ZERO
				for t: int in tris_at[q]:
					if t in fan:
						continue
					for c in 3:
						var vi := idx[t * 3 + c]
						if verts[vi].snapped(Vector3.ONE * 1e-4) == q:
							bn += norms[vi]
				if bn.length() > 1e-4:
					var d := bn.normalized().dot((q - c0).normalized())
					if absf(d) > 0.2:
						band = signf(d)
						break
			if band == 0.0:
				continue
			out.append([signf(apex_n.dot(k - c0)), band])
	return out


static func _lod0(path: String) -> Mesh:
	var scene: PackedScene = load(path)
	var root := scene.instantiate()
	var best: Mesh = null
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if mi.name.ends_with("_lod1") or mi.mesh == null:
			continue
		if best == null or mi.mesh.get_faces().size() > best.get_faces().size():
			best = mi.mesh
	root.free()
	return best


func test_lathe_tips_face_out() -> void:
	var pending := {}
	if FileAccess.file_exists(PENDING_REEXPORT):
		for line in FileAccess.get_file_as_string(PENDING_REEXPORT).split("\n", false):
			pending[line.strip_edges()] = true
	var checked := 0
	var bad := []
	for dir: String in DIRS:
		for f in DirAccess.get_files_at(dir):
			if not f.ends_with(".glb") or pending.has(f.get_basename()):
				continue
			var m := _lod0(dir + f)
			if m == null:
				continue
			var tips := tip_sides(m)
			if tips.is_empty():
				continue
			checked += 1
			for t: Array in tips:
				if t[0] != t[1]:
					bad.append(f)
					break
	gut.p("models with lathe tips checked: %d" % checked)
	assert_gt(checked, 50, "found lathe tips to check")
	assert_eq(bad, [], "lathe tips facing against their surface (re-export with the fixed prop_kit.lathe): %s" % [bad])


## The test's own check: a dome whose crown is wound against its side fails;
## one wound with it passes, whichever way the whole dome faces.
func test_tip_check_catches_a_tip_against_its_surface() -> void:
	for whole: float in [1.0, -1.0]:
		for tip: float in [1.0, -1.0]:
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			var apex := Vector3(0, 1.5, 0)
			for i in 8:
				var a0 := TAU * i / 8
				var a1 := TAU * (i + 1) / 8
				var lo0 := Vector3(cos(a0), 0, sin(a0))
				var lo1 := Vector3(cos(a1), 0, sin(a1))
				var hi0 := lo0 * 0.8 + Vector3(0, 1, 0)
				var hi1 := lo1 * 0.8 + Vector3(0, 1, 0)
				for p: Vector3 in [lo0, hi0, lo1, lo1, hi0, hi1]:
					st.set_normal(Vector3(p.x, 0.3, p.z).normalized() * whole)
					st.add_vertex(p)
				for p: Vector3 in [hi0, apex, hi1]:
					st.set_normal((p - Vector3(0, 1, 0) + Vector3(0, 0.5, 0)).normalized() * whole * tip)
					st.add_vertex(p)
			st.index()
			var tips := tip_sides(st.commit())
			assert_eq(tips.size(), 1)
			if tips.size() == 1:
				assert_eq(tips[0][0] == tips[0][1], tip > 0.0, "dome %s, tip %s" % [whole, tip])
