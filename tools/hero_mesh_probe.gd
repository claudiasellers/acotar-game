## Hero mesh probe (lane L61, render program T4): the technical causes of
## "faceted / toy" models, measured after import.
##
##   tools/mq/godot.sh -s tools/hero_mesh_probe.gd                    # the hero list
##   tools/mq/godot.sh -s tools/hero_mesh_probe.gd -- [-v] res://a.glb # any scenes
##
## Per scene (LOD1 / "far" meshes are skipped: they are for distance), with
## vertices welded by position, for every edge shared by two faces:
##   face   the angle between the two faces' geometric normals (the brief's
##          number: ≤ 20° on organic surfaces reads smooth at 1 m)
##   hard   the jump in the *shading* normals across the edge: 0 when smooth
##          shaded, the full face angle where a surface is flat shaded
##   sag    how far the flat faces stand off the curve they approximate, in mm
##          (edge length × face angle / 8): about 1 mm is one pixel at 1 m at
##          1080p, so this is what a close-up actually shows; thin twigs and
##          fine detail turn sharply but sag almost nothing
## Each is the p95 weighted by edge length, so long visible edges count and
## tiny detail edges barely do. Verdict: smooth when hard ≤ 20° and either
## face ≤ 20° or sag ≤ 2 mm. Also prints the triangle count and whether the
## scene has a Skeleton3D. A report: exit 0 always.
extends SceneTree

const HEROES: PackedStringArray = [
	"res://characters/feyre/model/feyre.glb",
	"res://characters/tamlin/tamlin_model.tscn",
	"res://creatures/models/great_wolf.gltf",
	"res://creatures/models/wolf.gltf",
	"res://creatures/models/fae/suriel.gltf",
	"res://creatures/models/fae/naga.gltf",
	"res://creatures/models/fae/attor.gltf",
	"res://creatures/models/spring/fox.gltf",
	"res://creatures/models/spring/songbird_rose.gltf",
	"res://world/spring_court/shared/models/oak.glb",
	"res://world/spring_court/shared/models/winter_bare.glb",
]
const TARGET_DEG := 20.0
const TARGET_SAG_MM := 2.0

var verbose := false
var _done := false


func _process(_delta: float) -> bool:
	# Autoloads exist only once the tree runs, and some scenes' scripts need them.
	if _done:
		return true
	_done = true
	var paths := PackedStringArray()
	for a in OS.get_cmdline_user_args():
		if a == "-v":
			verbose = true
		else:
			paths.append(a)
	if paths.is_empty():
		paths = HEROES
	print("%-52s %6s %6s %6s %6s %5s %s" % ["scene", "tris", "face", "hard", "sag", "skel", "verdict"])
	for p in paths:
		_probe(p)
	quit(0)
	return false


func _probe(path: String) -> void:
	if not ResourceLoader.exists(path):
		print("%-52s missing" % path)
		return
	var root := (load(path) as PackedScene).instantiate()
	var all := Stats.new()
	var lines: Array[String] = []
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null or mi.name.contains("LOD1") or mi.name == "far":
			continue
		for s in mi.mesh.get_surface_count():
			var st := Stats.new()
			st.add_surface(mi.mesh.surface_get_arrays(s))
			all.merge(st)
			if verbose:
				lines.append("    %-46s %6d %6.1f %6.1f %6.1f" % ["%s/%d" % [mi.name, s], st.tris,
					st.p95(st.face), st.p95(st.hard), st.p95(st.sag)])
	var skel := not root.find_children("*", "Skeleton3D", true, false).is_empty()
	print("%-52s %6d %6.1f %6.1f %6.1f %5s %s" % [path.trim_prefix("res://"), all.tris, all.p95(all.face),
		all.p95(all.hard), all.p95(all.sag), "yes" if skel else "NO", "smooth" if all.smooth() else "FACETED"])
	for line in lines:
		print(line)
	root.free()


## Per-edge measurements of one or more surfaces.
class Stats:
	var tris := 0
	var face := PackedFloat32Array()
	var hard := PackedFloat32Array()
	var sag := PackedFloat32Array()
	var weight := PackedFloat32Array()

	func smooth() -> bool:
		return p95(hard) <= TARGET_DEG and (p95(face) <= TARGET_DEG or p95(sag) <= TARGET_SAG_MM)

	func merge(o: Stats) -> void:
		tris += o.tris
		face.append_array(o.face)
		hard.append_array(o.hard)
		sag.append_array(o.sag)
		weight.append_array(o.weight)

	## The value below which 95% of the total edge length lies.
	func p95(values: PackedFloat32Array) -> float:
		if values.is_empty():
			return 0.0
		var order := range(values.size())
		order.sort_custom(func(i: int, j: int) -> bool: return values[i] < values[j])
		var total := 0.0
		for w in weight:
			total += w
		var acc := 0.0
		for i in order:
			acc += weight[i]
			if acc >= total * 0.95:
				return values[i]
		return values[order[-1]]

	func add_surface(arrays: Array) -> void:
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var nrm: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if idx.is_empty():
			idx.resize(verts.size())
			for i in verts.size():
				idx[i] = i
		# Weld by position so split normals and UV seams don't hide real edges.
		var weld := {}
		var id := PackedInt32Array()
		id.resize(verts.size())
		for i in verts.size():
			var k := Vector3i((verts[i] * 10000.0).round())
			if not weld.has(k):
				weld[k] = weld.size()
			id[i] = weld[k]
		var fn := PackedVector3Array()
		var edges := {}
		var n_tris := idx.size() / 3
		tris += n_tris
		for t in n_tris:
			var a := verts[idx[t * 3]]
			fn.append((verts[idx[t * 3 + 1]] - a).cross(verts[idx[t * 3 + 2]] - a).normalized())
			for e in 3:
				var i0 := idx[t * 3 + e]
				var i1 := idx[t * 3 + (e + 1) % 3]
				var key := Vector2i(mini(id[i0], id[i1]), maxi(id[i0], id[i1]))
				# Per face: its corner indices on this edge, low welded id first.
				var corners := Vector2i(i0, i1) if id[i0] < id[i1] else Vector2i(i1, i0)
				if edges.has(key):
					(edges[key] as Array).append([t, corners])
				else:
					edges[key] = [[t, corners]]
		for key in edges:
			var f: Array = edges[key]
			if f.size() != 2:
				continue
			var na := fn[f[0][0]]
			var nb := fn[f[1][0]]
			if na == Vector3.ZERO or nb == Vector3.ZERO:
				continue
			var ca: Vector2i = f[0][1]
			var cb: Vector2i = f[1][1]
			var ang := na.angle_to(nb)
			var length := verts[ca.x].distance_to(verts[ca.y])
			var jump := 0.0
			if not nrm.is_empty():
				jump = maxf(nrm[ca.x].angle_to(nrm[cb.x]), nrm[ca.y].angle_to(nrm[cb.y]))
			face.append(rad_to_deg(ang))
			hard.append(rad_to_deg(jump))
			sag.append(length * ang / 8.0 * 1000.0)
			weight.append(length)
