## Finds the real 3D model of a satchel entry: the forage and keepsake glTFs
## the world scatters (art/forage for the human realm, the Spring Court's
## flora and props folders), so the page shows the same thing she picked up.
## Used by the icon renderer (tools/ui/render_item_icons.gd) and by the page's
## hero preview. Loads happen on the calling (main) thread only (F27/F37).
class_name SatchelModel
extends RefCounted

const DIRS: Array[String] = [
	"res://art/forage/",
	"res://world/spring_court/wider/assets/flora/",
	"res://world/spring_court/wider/assets/props/",
]
const EXTS: Array[String] = [".glb", ".gltf"]
## Catalogue id -> model file stem, where the two were named apart.
const STEMS := {
	&"ing_watermint": &"ing_water_mint",
	&"col_blue_jay_feather": &"col_jay_feather",
	&"col_acorn_cap": &"col_acorn_caps",
	&"obj_white_roses": &"ing_rose_white",
}

## A ground pad is at most this tall (m) and at least this many times wider.
const PAD_HEIGHT := 0.06
const PAD_FLATNESS := 3.0
## Never strip below this share of the model's triangles.
const KEEP_AT_LEAST := 0.2
## Greens past this saturation are softened toward the manor palette (only on
## the satchel's own copy of the mesh; the world's models are untouched).
const GREEN_SAT := 0.55
const GREEN_SOFTEN := 0.7
## Berries: a "piece" is at most this share of the model's width; a pile
## keeps at most this many.
const GATHER_PIECE := 0.3
const GATHER_MAX := 9

static var _paths: Dictionary = {}
static var _harvested: Dictionary = {}  # mesh -> its stripped copy
static var _vcol: Material = null


## The model file for an item id, or "" when it has none.
static func path_for(id: StringName) -> String:
	if _paths.has(id):
		return _paths[id]
	var stem := String(STEMS.get(id, ItemCatalog.canonical(id)))
	var found := ""
	for stem_try: String in [stem, String(id)]:
		for dir in DIRS:
			for ext in EXTS:
				if found == "" and ResourceLoader.exists(dir + stem_try + ext):
					found = dir + stem_try + ext
	_paths[id] = found
	return found


static func has_model(id: StringName) -> bool:
	return path_for(id) != ""


## A fresh instance of the model, or null. Main thread only.
static func instance(id: StringName) -> Node3D:
	var path := path_for(id)
	if path == "":
		return null
	var scene := ResourceLoader.load(path) as PackedScene
	if scene == null:
		return null
	var root := scene.instantiate() as Node3D
	for n in root.find_children("*_LOD*", "Node3D", true, false):
		if not String(n.name).ends_with("_LOD0"):
			n.get_parent().remove_child(n)
			n.free()
	harvest(root, id)
	dress(root)
	return root


## Shows what she actually picks, not the patch it grew in: drops the flat
## ground pad (moss mat, leaf pad) things sit on and, for berries and nuts,
## the leafy clumps round them; and softens neon greens. Works on mesh
## islands (connected pieces), so it needs no per-model data.
static func harvest(root: Node3D, id: StringName) -> void:
	var item := ItemCatalog.get_item(id)
	# Berries always come as what's picked; flowers only when they grew on a
	# bush (rose bushes), so a cut stem keeps its leaves.
	var berry := item != null and item.icon == &"berry"
	var flower := item != null and item.icon == &"flower"
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh is ArrayMesh:
			var key := "%s|%s|%s" % [mi.mesh.get_rid().get_id(), berry, flower]
			if not _harvested.has(key):
				_harvested[key] = _strip(mi.mesh as ArrayMesh, berry, flower)
			mi.mesh = _harvested[key]


static func _strip(mesh: ArrayMesh, berry: bool, flower: bool = false) -> ArrayMesh:
	var out := ArrayMesh.new()
	for si in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(si)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if idx.is_empty():
			idx.resize(verts.size())
			for i in verts.size():
				idx[i] = i
		var cols: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
		var isl := _islands(verts, idx)
		var moves := {}
		var drop := _to_drop(isl, verts, idx, cols, berry, moves, flower)
		if not moves.is_empty():
			for i in verts.size():
				if moves.has(isl[i]):
					verts[i] += moves[isl[i]]
			arrays[Mesh.ARRAY_VERTEX] = verts
		var keep := PackedInt32Array()
		for t in idx.size() / 3:
			if not drop.has(isl[idx[t * 3]]):
				keep.append_array([idx[t * 3], idx[t * 3 + 1], idx[t * 3 + 2]])
		if not cols.is_empty():
			arrays[Mesh.ARRAY_COLOR] = _soften(cols)
		arrays = _compact(arrays, keep, verts.size())
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		out.surface_set_material(si, mesh.surface_get_material(si))
	return out


## Keeps only the vertices the kept triangles use, so bounds fit what's left.
static func _compact(arrays: Array, keep: PackedInt32Array, count: int) -> Array:
	var remap := PackedInt32Array()
	remap.resize(count)
	remap.fill(-1)
	var order := PackedInt32Array()
	for v in keep:
		if remap[v] < 0:
			remap[v] = order.size()
			order.append(v)
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	for slot in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_COLOR, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2]:
		var src = arrays[slot]
		if src == null or src.size() != count:
			continue
		var dst = src.duplicate()
		dst.resize(order.size())
		for i in order.size():
			dst[i] = src[order[i]]
		out[slot] = dst
	var tan = arrays[Mesh.ARRAY_TANGENT]
	if tan != null and tan.size() == count * 4:
		var t := PackedFloat32Array()
		t.resize(order.size() * 4)
		for i in order.size():
			for j in 4:
				t[i * 4 + j] = tan[order[i] * 4 + j]
		out[Mesh.ARRAY_TANGENT] = t
	var idx := PackedInt32Array()
	idx.resize(keep.size())
	for i in keep.size():
		idx[i] = remap[keep[i]]
	out[Mesh.ARRAY_INDEX] = idx
	return out


## Island id per vertex: vertices joined by a triangle or sharing a position.
static func _islands(verts: PackedVector3Array, idx: PackedInt32Array) -> PackedInt32Array:
	var parent := PackedInt32Array()
	parent.resize(verts.size())
	for i in verts.size():
		parent[i] = i
	var seen := {}
	for i in verts.size():
		var k := verts[i].snapped(Vector3.ONE * 0.00001)
		if seen.has(k):
			_union(parent, i, seen[k])
		else:
			seen[k] = i
	for t in idx.size() / 3:
		_union(parent, idx[t * 3], idx[t * 3 + 1])
		_union(parent, idx[t * 3], idx[t * 3 + 2])
	for i in verts.size():
		parent[i] = _find(parent, i)
	return parent


static func _find(parent: PackedInt32Array, x: int) -> int:
	while parent[x] != x:
		parent[x] = parent[parent[x]]
		x = parent[x]
	return x


static func _union(parent: PackedInt32Array, a: int, b: int) -> void:
	var ra := _find(parent, a)
	var rb := _find(parent, b)
	if ra != rb:
		parent[ra] = rb


## Which islands to drop: a flat pad under everything else, and for berries
## the big green clumps, as long as enough of the thing remains.
static func _to_drop(isl: PackedInt32Array, verts: PackedVector3Array, idx: PackedInt32Array,
		cols: PackedColorArray, berry: bool, moves: Dictionary = {}, flower: bool = false) -> Dictionary:
	var info := {}  # island -> {box, tris, col, n}
	var total := 0
	for t in idx.size() / 3:
		var r := isl[idx[t * 3]]
		if not info.has(r):
			info[r] = {"box": AABB(verts[idx[t * 3]], Vector3.ZERO), "tris": 0, "col": Color(0, 0, 0, 0), "n": 0}
		var d: Dictionary = info[r]
		for j in 3:
			var v := idx[t * 3 + j]
			d.box = (d.box as AABB).expand(verts[v])
			if not cols.is_empty():
				d.col = (d.col as Color) + cols[v]
				d.n += 1
		d.tris += 1
		total += 1
	var min_y := INF
	for r in info:
		min_y = minf(min_y, (info[r].box as AABB).position.y)
	var drop := {}
	var dropped := 0
	for r in info:
		var b: AABB = info[r].box
		var foot := maxf(b.size.x, b.size.z)
		var flat := b.size.y <= PAD_HEIGHT and foot >= b.size.y * PAD_FLATNESS
		var at_bottom := b.position.y <= min_y + 0.02
		var under := false
		for o in info:
			var ob: AABB = info[o].box
			if o != r and ob.position.y >= b.position.y + b.size.y * 0.4 \
					and Rect2(b.position.x, b.position.z, b.size.x, b.size.z).intersects(Rect2(ob.position.x, ob.position.z, ob.size.x, ob.size.z)):
				under = true
				break
		if flat and at_bottom and under:
			drop[r] = true
			dropped += int(info[r].tris)
	if total - dropped < total * KEEP_AT_LEAST:
		drop = {}
	if berry or (flower and _bushy(info)):
		_gather(info, drop, total, moves)
	return drop


## A bush: one green island that is both wide and tall for the whole model.
static func _bushy(info: Dictionary) -> bool:
	var all_box := AABB()
	var first := true
	for r in info:
		all_box = info[r].box if first else all_box.merge(info[r].box)
		first = false
	var extent := maxf(all_box.size.x, all_box.size.z)
	for r in info:
		if int(info[r].n) == 0:
			continue
		var b: AABB = info[r].box
		var c: Color = info[r].col / float(info[r].n)
		if c.g > c.r * 1.2 and c.g > c.b * 1.2 and maxf(b.size.x, b.size.z) >= extent * 0.45 \
				and b.size.y >= extent * 0.25:
			return true
	return false


## Berries, nuts and hips: what she picks is the fruit, not the bush. Takes
## the biggest group of small same-coloured pieces (with the caps and stalks
## touching them), drops the rest, and draws them together into a small pile
## when they were spread over a whole bush. `moves` gets island -> offset.
static func _gather(info: Dictionary, drop: Dictionary, total: int, moves: Dictionary) -> void:
	var all_box := AABB()
	var first := true
	for r in info:
		all_box = info[r].box if first else all_box.merge(info[r].box)
		first = false
	var extent := maxf(all_box.size.x, all_box.size.z)
	var groups: Array = []  # [{col, members, tris}]
	for r in info:
		var b: AABB = info[r].box
		if drop.has(r) or int(info[r].n) == 0 or maxf(b.size.x, b.size.z) > extent * GATHER_PIECE:
			continue
		var c: Color = info[r].col / float(info[r].n)
		if c.g > c.r * 1.2 and c.g > c.b * 1.2:
			continue  # leaves
		var home: Dictionary = {}
		for g: Dictionary in groups:
			var gc: Color = g.col
			if Vector3(gc.r - c.r, gc.g - c.g, gc.b - c.b).length() < 0.18:
				home = g
				break
		if home.is_empty():
			home = {"col": c, "members": [], "tris": 0}
			groups.append(home)
		(home.members as Array).append(r)
		home.tris = int(home.tris) + int(info[r].tris)
	var best: Dictionary = {}
	for g: Dictionary in groups:
		if (g.members as Array).size() >= 2 and (best.is_empty() or int(g.tris) > int(best.tris)):
			best = g
	if best.is_empty() or int(best.tris) < total * 0.08:
		return
	var members: Array = best.members
	# The centre of the group, and the GATHER_MAX pieces nearest it.
	var centre := Vector3.ZERO
	for r in members:
		centre += (info[r].box as AABB).get_center()
	centre /= members.size()
	members.sort_custom(func(a: int, b: int) -> bool:
		return (info[a].box as AABB).get_center().distance_to(centre) < (info[b].box as AABB).get_center().distance_to(centre))
	members = members.slice(0, GATHER_MAX)
	# Caps, stalks and calyxes touching a kept piece go with it.
	var owner := {}
	for r in members:
		owner[r] = r
	for r in info:
		if owner.has(r) or drop.has(r):
			continue
		var b: AABB = info[r].box
		if maxf(b.size.x, b.size.z) > extent * GATHER_PIECE:
			continue
		for m in members:
			if (info[m].box as AABB).grow(0.004).intersects(b):
				owner[r] = m
				break
	for r in info:
		if not owner.has(r):
			drop[r] = true
	# Draw spread-out pieces into a pile, resting at the lowest one's height.
	var size := 0.0
	var floor_y := INF
	var spread := 0.0
	for r in members:
		var b: AABB = info[r].box
		size += maxf(b.size.x, b.size.z)
		floor_y = minf(floor_y, b.position.y)
		spread = maxf(spread, Vector2(b.get_center().x - centre.x, b.get_center().z - centre.z).length())
	size /= members.size()
	if spread <= size * 2.5:
		return
	var k := size * 1.6 / spread
	for r in members:
		var b: AABB = info[r].box
		var c := b.get_center()
		var flat := Vector3(c.x - centre.x, 0, c.z - centre.z)
		moves[r] = flat * (k - 1.0) + Vector3(0, floor_y - b.position.y, 0)
	for r in owner:
		if owner[r] != r:
			moves[r] = moves.get(owner[r], Vector3.ZERO)


static func _soften(cols: PackedColorArray) -> PackedColorArray:
	var out := cols.duplicate()
	for i in out.size():
		var c := out[i]
		var h := c.h
		if h > 0.17 and h < 0.47 and c.s > GREEN_SAT:
			# Toward sage: less saturated, a touch darker and bluer.
			out[i] = Color.from_hsv(lerpf(h, 0.36, 0.3), c.s * GREEN_SOFTEN, c.v * 0.92, c.a)
	return out


## The generators bake colour into COLOR_0 and the importer leaves it off
## (the world draws them through its own court shaders, which lean on world
## globals such as snow and magic). Off the world, one shared material does
## the colour: vertex colour as albedo, soft sheen, a warm rim (R3).
static func dress(root: Node3D) -> void:
	if _vcol == null:
		var std := MaterialLibrary.surface()
		std.resource_name = "satchel_vcol"
		std.vertex_color_use_as_albedo = true
		std.roughness = 0.6
		std.cull_mode = BaseMaterial3D.CULL_DISABLED
		std.rim_enabled = true
		std.rim = 0.3
		std.rim_tint = 0.7
		_vcol = std
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh is ArrayMesh and _has_colours(mi.mesh as ArrayMesh):
			mi.material_override = _vcol


static func _has_colours(mesh: ArrayMesh) -> bool:
	for s in mesh.get_surface_count():
		if mesh.surface_get_format(s) & Mesh.ARRAY_FORMAT_COLOR:
			return true
	return false


## The combined bounds of every mesh under `root`, in root's space.
static func bounds(root: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null or not mi.visible:
			continue
		var xf := root.global_transform.affine_inverse() * mi.global_transform \
				if root.is_inside_tree() else _local_xf(root, mi)
		var b := xf * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


static func _local_xf(root: Node3D, node: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != root:
		if n is Node3D:
			xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf
