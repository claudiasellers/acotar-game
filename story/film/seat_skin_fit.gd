## Keeps a sitting figure's body and trousers from poking through the clothes
## over them (T045). Garments are skinned for standing: a tunic's hem hangs from
## the hips while the thigh under it swings forward 90 degrees, so the buttock
## and the thigh's top push out through the cloth in patches of skin and trouser.
## Cloth can't follow, so while sitting the figure's layers lose the triangles
## that sit under cloth, and the cloth shows whole. Standing puts the originals
## back, so the standing look is the authored one.
##
## Layers, innermost out: the body (torso, legs), trousers and shirts, tunics and
## gowns, doublets and vests. A triangle goes only when all three corners are buried:
## an outer layer's vertex lies in front of each along its normal, in the rest pose.
## What shows through an opening (a neckline's chest, a sleeve's wrist) has nothing
## in front of it, so it stays.
##
## Feyre is left alone: her wardrobe already hides the body regions each piece
## covers, and the base layer under it is hers (BaseLayer). Her trousers show through
## her tunic standing as well as sitting, which is a fault of the pair, not of the pose.
class_name SeatSkinFit
extends RefCounted

## How far in front of a vertex cloth counts as covering it, and the widest cone (cosine) it may sit in.
const REACH := 0.08
const COVER_COS := 0.3
## Body surfaces that lie under the clothes. Arms and hands are drawn as they are.
const BODY_LAYERS := ["torso", "legs"]
## Garment name fragments, by layer (1 is worn next to the body). Anything else
## (boots, belts, masks, cloaks, hair) is left as it is, and covers nothing.
const LAYER_OF := [["trouser", 1], ["pants", 1], ["legging", 1], ["stocking", 1], ["shift", 1], ["shirt", 1],
	["tunic", 2], ["blouse", 2], ["gown", 2], ["dress", 2], ["smock", 2],
	["doublet", 3], ["waistcoat", 3], ["vest", 3], ["coat", 3]]
const ORIGINAL := &"seat_fit_original"
const FITTED := &"seat_fit_fitted"


## Puts the sitting copies of `skeleton`'s figure's meshes on, or the originals back.
static func set_seated(skeleton: Skeleton3D, seated: bool) -> void:
	if skeleton == null or skeleton.find_bone("Hips") < 0:
		return
	var holder := _figure_root(skeleton)
	if holder.find_child("BaseLayer", true, false) != null:
		return
	if not seated:
		for mi: MeshInstance3D in holder.find_children("*", "MeshInstance3D", true, false):
			if mi.has_meta(ORIGINAL):
				mi.mesh = mi.get_meta(ORIGINAL)
				mi.remove_meta(ORIGINAL)
		return
	var parts := _parts(holder, skeleton)
	var outer_pool: Dictionary = {}   # layer -> _Pool of the vertices of every layer outside it
	for mi: MeshInstance3D in parts["inner"].keys():
		if mi.has_meta(ORIGINAL):
			continue
		var layer: int = parts["inner"][mi]
		if not outer_pool.has(layer):
			var pool := _Pool.new()
			for other: MeshInstance3D in parts["garments"].keys():
				if int(parts["garments"][other]) > layer:
					for s in other.mesh.get_surface_count():
						pool.add(other, s, skeleton)
			pool.index()
			outer_pool[layer] = pool
		var made: ArrayMesh = _fitted(mi, outer_pool[layer], skeleton, parts["surfaces"].get(mi, []))
		if made != null:
			mi.set_meta(ORIGINAL, mi.mesh)
			mi.mesh = made


## The node the figure's meshes hang under: three levels up from the skeleton (the glb, the
## model, what the wardrobe's "Worn" node hangs on), no further than a character body.
static func _figure_root(skeleton: Skeleton3D) -> Node:
	var at: Node = skeleton
	for i in 3:
		var up := at.get_parent()
		if up == null or up is CharacterBody3D or up == skeleton.get_tree().root:
			break
		at = up
	return at


## The figure's skinned meshes: {"garments": {mesh instance: layer}, "inner": {mesh
## instance: the layer it is under}, "surfaces": {body mesh instance: [its covered surfaces]}}.
## The body is layer 0 and is `inner` only; a garment is both, unless it is the outermost.
static func _parts(holder: Node, skeleton: Skeleton3D) -> Dictionary:
	var garments := {}
	var inner := {}
	var surfaces := {}
	var top := 0
	for mi: MeshInstance3D in holder.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null or mi.skin == null or not mi.mesh is ArrayMesh or mi.get_node_or_null(mi.skeleton) != skeleton:
			continue
		if mi.get_parent() == skeleton:
			if mi.name == &"Body" or mi.name == &"Body_LOD1":
				var covered: Array = []
				for s in mi.mesh.get_surface_count():
					if _surface_name(mi.mesh, s) in BODY_LAYERS:
						covered.append(s)
				surfaces[mi] = covered
				inner[mi] = 0
			continue
		var label := ("%s %s" % [mi.get_parent().name, mi.name]).to_lower()
		if label.contains("hair"):
			continue
		for pair: Array in LAYER_OF:
			if label.contains(String(pair[0])):
				garments[mi] = int(pair[1])
				inner[mi] = int(pair[1])
				top = maxi(top, int(pair[1]))
				break
	for mi: MeshInstance3D in inner.keys():
		if int(inner[mi]) >= top:   # nothing outside the outermost layer
			inner.erase(mi)
	return {"garments": garments, "inner": inner, "surfaces": surfaces}


static func _surface_name(mesh: Mesh, index: int) -> String:
	var mat := mesh.surface_get_material(index)
	if mat != null and mat.resource_name != "":
		return mat.resource_name
	return (mesh as ArrayMesh).surface_get_name(index)


## `mi`'s mesh without the triangles buried under `outer`, or null when none are.
## `only` lists the surfaces to look at (all of them when empty). Cached on the node:
## the fit is the same every time.
static func _fitted(mi: MeshInstance3D, outer: _Pool, skeleton: Skeleton3D, only: Array) -> ArrayMesh:
	if mi.has_meta(FITTED):
		return mi.get_meta(FITTED)
	var src := mi.mesh as ArrayMesh
	var out := ArrayMesh.new()
	out.blend_shape_mode = src.blend_shape_mode
	for b in src.get_blend_shape_count():
		out.add_blend_shape(src.get_blend_shape_name(b))
	var dropped := 0
	for s in src.get_surface_count():
		var arrays := src.surface_get_arrays(s)
		var flags := src.surface_get_format(s) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
		if only.is_empty() or only.has(s):
			dropped += _drop_buried(mi, arrays, outer, skeleton)
		out.add_surface_from_arrays(src.surface_get_primitive_type(s), arrays, src.surface_get_blend_shape_arrays(s), {}, flags)
		out.surface_set_material(s, src.surface_get_material(s))
		out.surface_set_name(s, src.surface_get_name(s))
	var made: ArrayMesh = out if dropped > 0 else null
	mi.set_meta(FITTED, made)
	return made


## Takes the buried triangles out of `arrays`' index list; how many went.
static func _drop_buried(mi: MeshInstance3D, arrays: Array, outer: _Pool, skeleton: Skeleton3D) -> int:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if verts.is_empty() or norms.size() != verts.size() or bones.is_empty() or index.is_empty():
		return 0
	var rest := _rest_frames(mi, verts, norms, bones, weights, bones.size() / verts.size(), skeleton)
	var buried := PackedByteArray()
	buried.resize(verts.size())
	for v in verts.size():
		buried[v] = 1 if outer.covers(rest[0][v], rest[1][v]) else 0
	var kept := PackedInt32Array()
	for t in range(0, index.size() - 2, 3):
		if buried[index[t]] == 0 or buried[index[t + 1]] == 0 or buried[index[t + 2]] == 0:
			kept.append_array(index.slice(t, t + 3))
	var dropped := (index.size() - kept.size()) / 3
	if kept.is_empty():   # a surface needs an index list: one degenerate triangle draws nothing
		kept = PackedInt32Array([0, 0, 0])
	arrays[Mesh.ARRAY_INDEX] = kept
	return dropped


static func _bind_name(skin: Skin, bind: int, skeleton: Skeleton3D) -> String:
	var bone := skin.get_bind_bone(bind)
	if bone >= 0:
		return skeleton.get_bone_name(bone)
	return skin.get_bind_name(bind)


## [positions, normals] of each vertex in the skeleton's space with the skeleton at rest.
static func _rest_frames(mi: MeshInstance3D, verts: PackedVector3Array, norms: PackedVector3Array, bones: PackedInt32Array, weights: PackedFloat32Array, per: int, skeleton: Skeleton3D) -> Array:
	var skin := mi.skin
	var to_rest: Array[Transform3D] = []
	for b in skin.get_bind_count():
		var bone := skeleton.find_bone(_bind_name(skin, b, skeleton))
		to_rest.append((skeleton.get_bone_global_rest(bone) if bone >= 0 else Transform3D.IDENTITY) * skin.get_bind_pose(b))
	var at := PackedVector3Array()
	var facing := PackedVector3Array()
	at.resize(verts.size())
	facing.resize(verts.size())
	for v in verts.size():
		var p := Vector3.ZERO
		var n := Vector3.ZERO
		var sum := 0.0
		for k in per:
			var w := weights[v * per + k]
			if w > 0.0:
				var m := to_rest[bones[v * per + k]]
				p += w * (m * verts[v])
				if v < norms.size():
					n += w * (m.basis * norms[v])
				sum += w
		at[v] = p / sum if sum > 0.0 else verts[v]
		facing[v] = n.normalized()
	return [at, facing]


## The vertices of the layers outside a mesh, in the skeleton's space at rest, in a
## grid of REACH-wide cells.
class _Pool extends RefCounted:
	var points: PackedVector3Array = PackedVector3Array()
	var cells: Dictionary = {}   # Vector3i -> PackedInt32Array

	func add(mi: MeshInstance3D, surface: int, skeleton: Skeleton3D) -> void:
		var arrays := (mi.mesh as ArrayMesh).surface_get_arrays(surface)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		if bones.is_empty() or verts.is_empty():
			return
		var frames := SeatSkinFit._rest_frames(mi, verts, PackedVector3Array(), bones, arrays[Mesh.ARRAY_WEIGHTS], bones.size() / verts.size(), skeleton)
		points.append_array(frames[0])

	func index() -> void:
		for i in points.size():
			var key := _cell(points[i])
			var members: PackedInt32Array = cells.get(key, PackedInt32Array())
			members.append(i)
			cells[key] = members

	func _cell(p: Vector3) -> Vector3i:
		return Vector3i((p / SeatSkinFit.REACH).floor())

	## Whether one of these vertices lies in front of `p` along `facing`, within REACH.
	func covers(p: Vector3, facing: Vector3) -> bool:
		var home := _cell(p)
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				for dz in range(-1, 2):
					var key := home + Vector3i(dx, dy, dz)
					if not cells.has(key):
						continue
					for i: int in cells[key]:
						var d := points[i] - p
						var len := d.length()
						if len < SeatSkinFit.REACH and len > 0.0001 and d.dot(facing) > SeatSkinFit.COVER_COS * len:
							return true
		return false
