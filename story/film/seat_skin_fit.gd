## Keeps a sitting figure's clothes over their body (T045). Each garment is
## skinned for standing: a tunic's hem and a trouser's waist hang from the hips
## while the body under them hangs from the thigh, so once the thigh swings
## forward 90 degrees the thigh (and the trousers under a tunic) push out through
## the cloth. Sitting swaps each garment for a copy whose vertices that hug a
## layer under them take that layer's skin weights, so they bend where it bends.
## Standing puts the originals back: the standing look is the authored one.
##
## Layers, innermost out: the body (torso, arms, legs), trousers and shirts,
## tunics and gowns, doublets and vests. A vertex within SHELL of an inner layer
## blends toward the weights of that layer's nearest vertex, fully inside CLOSE.
## Cloth hanging free of the layers under it (a skirt's hem) keeps its own weights.
class_name SeatSkinFit
extends RefCounted

## Skin weights are copied from vertices this close, fully inside CLOSE, fading out by SHELL.
const CLOSE := 0.012
const SHELL := 0.04
## Body surfaces that are a layer to be covered.
const BODY_LAYERS := ["torso", "arms", "legs"]
## Garment name fragments, by layer (1 is worn next to the body). Anything else
## (boots, belts, masks, cloaks, hair) is left as it is.
const LAYER_OF := [["trouser", 1], ["pants", 1], ["legging", 1], ["stocking", 1], ["shift", 1], ["shirt", 1],
	["tunic", 2], ["blouse", 2], ["gown", 2], ["dress", 2], ["smock", 2],
	["doublet", 3], ["waistcoat", 3], ["vest", 3], ["coat", 3]]
const ORIGINAL := &"seat_fit_original"
const FITTED := &"seat_fit_fitted"


## Puts the sitting copies of `skeleton`'s figure's garments on, or the originals back.
static func set_seated(skeleton: Skeleton3D, seated: bool) -> void:
	if skeleton == null or skeleton.find_bone("Hips") < 0:
		return
	var holder := skeleton.get_parent()
	var parts := _parts(holder, skeleton)
	var worn: Array = parts["garments"]
	if not seated:
		for mi: MeshInstance3D in holder.find_children("*", "MeshInstance3D", true, false):
			if mi.has_meta(ORIGINAL):
				var orig: Array = mi.get_meta(ORIGINAL)
				mi.mesh = orig[0]
				mi.skin = orig[1]
				mi.remove_meta(ORIGINAL)
		return
	for entry: Array in worn:
		var mi := entry[0] as MeshInstance3D
		if mi.has_meta(ORIGINAL):
			continue
		var layer := int(entry[1])
		var made: Array = _fitted(mi, layer, skeleton, parts["body"], worn)
		if made.is_empty():
			continue
		mi.set_meta(ORIGINAL, [mi.mesh, mi.skin])
		mi.mesh = made[0]
		mi.skin = made[1]


## Every skinned mesh under `holder` that is a layer: {"body": [[mesh instance, surface], ...], "garments": [[mesh instance, layer], ...]}.
static func _parts(holder: Node, skeleton: Skeleton3D) -> Dictionary:
	var body: Array = []
	var garments: Array = []
	for mi: MeshInstance3D in holder.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null or mi.skin == null or not mi.mesh is ArrayMesh:
			continue
		if mi.get_parent() == skeleton:
			if mi.name == &"Body":
				for s in mi.mesh.get_surface_count():
					if _surface_name(mi.mesh, s) in BODY_LAYERS:
						body.append([mi, s])
			continue
		var label := ("%s %s" % [mi.get_parent().name, mi.name]).to_lower()
		if label.contains("hair"):
			continue
		for pair: Array in LAYER_OF:
			if label.contains(String(pair[0])):
				garments.append([mi, int(pair[1])])
				break
	return {"body": body, "garments": garments}


static func _surface_name(mesh: Mesh, index: int) -> String:
	var mat := mesh.surface_get_material(index)
	if mat != null and mat.resource_name != "":
		return mat.resource_name
	return (mesh as ArrayMesh).surface_get_name(index)


## `mi`'s mesh and skin with its vertices' weights taken from the layers under it,
## or [] when no layer is under it. Cached on the node: the fit is the same every time.
static func _fitted(mi: MeshInstance3D, layer: int, skeleton: Skeleton3D, body: Array, worn: Array) -> Array:
	if mi.has_meta(FITTED):
		return mi.get_meta(FITTED)
	var under := _Pool.new()
	for pair: Array in body:
		under.add(pair[0], pair[1], skeleton)
	for entry: Array in worn:
		if int(entry[1]) < layer:
			var other := entry[0] as MeshInstance3D
			for s in other.mesh.get_surface_count():
				under.add(other, s, skeleton)
	var made: Array = []
	if not under.is_empty():
		under.index()
		made = _rebuilt(mi, skeleton, under)
	mi.set_meta(FITTED, made)
	return made


static func _rebuilt(mi: MeshInstance3D, skeleton: Skeleton3D, under: _Pool) -> Array:
	var src := mi.mesh as ArrayMesh
	var skin := mi.skin.duplicate() as Skin
	var bind_of := {}
	for i in skin.get_bind_count():
		bind_of[_bind_name(skin, i, skeleton)] = i
	var out := ArrayMesh.new()
	out.blend_shape_mode = src.blend_shape_mode
	for b in src.get_blend_shape_count():
		out.add_blend_shape(src.get_blend_shape_name(b))
	var changed := false
	for s in src.get_surface_count():
		var arrays := src.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		if bones.is_empty() or verts.is_empty():
			out.add_surface_from_arrays(src.surface_get_primitive_type(s), arrays, src.surface_get_blend_shape_arrays(s))
			_copy_surface(src, out, s)
			continue
		var per := bones.size() / verts.size()
		var rest := _rest_positions(mi, verts, bones, weights, per, skeleton)
		for v in verts.size():
			var hit := under.nearest(rest[v])
			if hit.is_empty() or float(hit[0]) >= SHELL:
				continue
			var t := 1.0 - smoothstep(CLOSE, SHELL, float(hit[0]))
			var blend := {}   # bone name -> weight
			for k in per:
				var w := weights[v * per + k]
				if w > 0.0:
					var nm := _bind_name(mi.skin, bones[v * per + k], skeleton)
					blend[nm] = float(blend.get(nm, 0.0)) + w * (1.0 - t)
			var theirs: Dictionary = hit[1]
			for nm: String in theirs:
				blend[nm] = float(blend.get(nm, 0.0)) + float(theirs[nm]) * t
			var names: Array = blend.keys()
			names.sort_custom(func(a: String, b: String) -> bool: return float(blend[a]) > float(blend[b]))
			var total := 0.0
			for k in mini(per, names.size()):
				total += float(blend[names[k]])
			for k in per:
				if k < names.size():
					var nm: String = names[k]
					if not bind_of.has(nm):
						var at := under.bind_pose(nm)
						bind_of[nm] = skin.get_bind_count()
						skin.add_named_bind(nm, at)
					bones[v * per + k] = int(bind_of[nm])
					weights[v * per + k] = float(blend[nm]) / total
				else:
					bones[v * per + k] = 0
					weights[v * per + k] = 0.0
			changed = true
		arrays[Mesh.ARRAY_BONES] = bones
		arrays[Mesh.ARRAY_WEIGHTS] = weights
		var flags := Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if per == 8 else 0
		out.add_surface_from_arrays(src.surface_get_primitive_type(s), arrays, src.surface_get_blend_shape_arrays(s), {}, flags)
		_copy_surface(src, out, s)
	return [out, skin] if changed else []


static func _copy_surface(src: ArrayMesh, out: ArrayMesh, s: int) -> void:
	out.surface_set_material(s, src.surface_get_material(s))
	out.surface_set_name(s, src.surface_get_name(s))


static func _bind_name(skin: Skin, bind: int, skeleton: Skeleton3D) -> String:
	var bone := skin.get_bind_bone(bind)
	if bone >= 0:
		return skeleton.get_bone_name(bone)
	return skin.get_bind_name(bind)


## Where each vertex stands in the skeleton's space with the skeleton at rest.
static func _rest_positions(mi: MeshInstance3D, verts: PackedVector3Array, bones: PackedInt32Array, weights: PackedFloat32Array, per: int, skeleton: Skeleton3D) -> PackedVector3Array:
	var skin := mi.skin
	var to_rest: Array[Transform3D] = []
	for b in skin.get_bind_count():
		var bone := skeleton.find_bone(_bind_name(skin, b, skeleton))
		to_rest.append((skeleton.get_bone_global_rest(bone) if bone >= 0 else Transform3D.IDENTITY) * skin.get_bind_pose(b))
	var out := PackedVector3Array()
	out.resize(verts.size())
	for v in verts.size():
		var p := Vector3.ZERO
		var sum := 0.0
		for k in per:
			var w := weights[v * per + k]
			if w > 0.0:
				p += w * (to_rest[bones[v * per + k]] * verts[v])
				sum += w
		out[v] = p / sum if sum > 0.0 else verts[v]
	return out


## The vertices of the layers under a garment, in the skeleton's space at rest,
## in a grid of SHELL-wide cells: a position, its weights by bone name.
class _Pool extends RefCounted:
	var points: PackedVector3Array = PackedVector3Array()
	var weights: Array[Dictionary] = []
	var binds: Dictionary = {}   # bone name -> bind pose
	var cells: Dictionary = {}   # Vector3i -> PackedInt32Array

	func is_empty() -> bool:
		return points.is_empty()

	func add(mi: MeshInstance3D, surface: int, skeleton: Skeleton3D) -> void:
		var arrays := (mi.mesh as ArrayMesh).surface_get_arrays(surface)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var wts: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		if bones.is_empty() or verts.is_empty():
			return
		var per := bones.size() / verts.size()
		var rest := SeatSkinFit._rest_positions(mi, verts, bones, wts, per, skeleton)
		for b in mi.skin.get_bind_count():
			binds[SeatSkinFit._bind_name(mi.skin, b, skeleton)] = mi.skin.get_bind_pose(b)
		for v in verts.size():
			var mine := {}
			for k in per:
				var w := wts[v * per + k]
				if w > 0.0:
					var nm := SeatSkinFit._bind_name(mi.skin, bones[v * per + k], skeleton)
					mine[nm] = float(mine.get(nm, 0.0)) + w
			points.append(rest[v])
			weights.append(mine)

	func index() -> void:
		for i in points.size():
			var key := _cell(points[i])
			var members: PackedInt32Array = cells.get(key, PackedInt32Array())
			members.append(i)
			cells[key] = members

	func _cell(p: Vector3) -> Vector3i:
		return Vector3i((p / SeatSkinFit.SHELL).floor())

	func bind_pose(bone_name: String) -> Transform3D:
		return binds.get(bone_name, Transform3D.IDENTITY)

	## [distance, weights] of the nearest vertex within SHELL, or [].
	func nearest(p: Vector3) -> Array:
		var home := _cell(p)
		var best := SeatSkinFit.SHELL
		var found := -1
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				for dz in range(-1, 2):
					var key := home + Vector3i(dx, dy, dz)
					if not cells.has(key):
						continue
					for i: int in cells[key]:
						var d := points[i].distance_to(p)
						if d < best:
							best = d
							found = i
		return [best, weights[found]] if found >= 0 else []
