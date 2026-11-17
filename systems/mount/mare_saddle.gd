## The white mare's saddle and reins (lane L47-8, docs/contracts/mare_bond.md).
## Her model (tools/blender/white_mare.py) was built with a flat seat, gold
## trim and reins that end at the pommel. Dressing her strips those from her
## mesh, hangs the generator-built saddle (tools/blender/mare_saddle.py) on
## her `spine` bone and adds MareReins, which run from her bit to Feyre's hands
## while she rides and lie over the pommel when she doesn't. Bareback takes
## the saddle off. One stripped mesh is shared by every mare (cached).
class_name MareSaddle
extends RefCounted

const SADDLE := "res://systems/mount/models/mare_saddle.gltf"
const NODE := "MareSaddle"
## Surfaces of her own mesh that were the old saddle, dropped whole.
const DROP_SURFACES := ["SaddleSeat", "SaddleCloth"]
## Gold parts reaching back past this (model z, metres; her withers are at
## about -0.6) were the old saddle's trim and stirrups or the old reins. The
## bridle (bit, cheeks, noseband, browband) is all ahead of it and stays.
const BRIDLE_BEHIND := -0.8
## A gold part longer than this along her length is a stretch of the old rein
## (the bridle's straps and rings are all shorter).
const REIN_LONG := 0.3
## The seat's lowest point, the saddle centre, in her model space (mare_saddle.py
## CENTRE_Y). The rider's pelvis sits over it (WhiteHorse.SEAT_OFFSET).
const CENTRE := Vector3(0.0, 1.935, -0.20)

static var _stripped: Dictionary = {}  # source mesh rid -> [ArrayMesh, bits]


## Puts the saddle and reins on `horse` (once; safe to call again).
static func dress(horse: WhiteHorse) -> void:
	if horse == null or horse.model == null:
		return
	var mi := mesh_of(horse)
	var sk := skeleton_of(horse)
	if mi == null or sk == null:
		return
	if not mi.has_meta(&"mare_saddle_stripped"):
		var made := _strip(mi.mesh)
		mi.mesh = made[0]
		mi.set_meta(&"mare_saddle_stripped", true)
		horse.bits = made[1]
	if sk.get_node_or_null(NODE) == null and ResourceLoader.exists(SADDLE):
		var att := BoneAttachment3D.new()
		att.name = NODE
		att.bone_name = &"spine"
		sk.add_child(att)
		var piece := (load(SADDLE) as PackedScene).instantiate() as Node3D
		att.add_child(piece)
		var bone := sk.find_bone(&"spine")
		var model_to_sk := sk.global_transform.affine_inverse() * horse.model.global_transform
		piece.transform = sk.get_bone_global_rest(bone).affine_inverse() * model_to_sk
		for m in piece.find_children("*", "MeshInstance3D", true, false):
			m.add_to_group(CameraFade.NEVER_GROUP)
	if horse.get_node_or_null(^"MareReins") == null:
		var reins := MareReins.new()
		reins.name = "MareReins"
		horse.add_child(reins)
		reins.bind(horse, mi, sk)


## True while the saddle is on her.
static func saddled(horse: WhiteHorse) -> bool:
	var sk := skeleton_of(horse)
	var att := sk.get_node_or_null(NODE) as Node3D if sk else null
	return att != null and att.visible


## Saddle on (true) or bareback (false).
static func set_saddled(horse: WhiteHorse, on: bool) -> void:
	var sk := skeleton_of(horse)
	var att := sk.get_node_or_null(NODE) as Node3D if sk else null
	if att:
		att.visible = on
	if horse:
		horse.bareback = not on


## The saddle's meshes (MareLook recolours their cloth and gold).
static func saddle_meshes(horse: WhiteHorse) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	var sk := skeleton_of(horse)
	var att := sk.get_node_or_null(NODE) if sk else null
	if att:
		for m in att.find_children("*", "MeshInstance3D", true, false):
			out.append(m as MeshInstance3D)
	return out


static func mesh_of(horse: WhiteHorse) -> MeshInstance3D:
	if horse == null or horse.model == null:
		return null
	for m in horse.model.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh and mi.mesh.get_surface_count() > 6 and mi.skin:
			return mi
	return null


static func skeleton_of(horse: WhiteHorse) -> Skeleton3D:
	if horse == null or horse.model == null:
		return null
	var found := horse.model.find_children("*", "Skeleton3D", true, false)
	return null if found.is_empty() else found.front() as Skeleton3D


## [ArrayMesh without the old saddle and reins, bits]: bits is
## [left bit ring centre, right bit ring centre] in mesh space (her left is -X).
static func _strip(src: Mesh) -> Array:
	var key := src.get_rid().get_id()
	if _stripped.has(key):
		return _stripped[key]
	var out := ArrayMesh.new()
	out.resource_name = src.resource_name
	var bits: Array[Vector3] = [Vector3(-0.07, 1.95, -1.6), Vector3(0.07, 1.95, -1.6)]
	for s in src.get_surface_count():
		var mat := src.surface_get_material(s)
		var name := String(mat.resource_name) if mat else ""
		if name in DROP_SURFACES:
			continue
		var arrays := src.surface_get_arrays(s)
		if name == "Gold":
			arrays = _strip_gold(arrays, bits)
		var flags: int = src.surface_get_format(s) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
		out.surface_set_material(out.get_surface_count() - 1, mat)
	if src is ArrayMesh:
		out.custom_aabb = (src as ArrayMesh).custom_aabb
	_stripped[key] = [out, bits]
	return _stripped[key]


## Keeps the bridle's islands of the Gold surface; finds the two bit rings.
static func _strip_gold(arrays: Array, bits: Array[Vector3]) -> Array:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if index.is_empty():
		return arrays
	# Islands: vertices welded by position (flat-shaded parts split their verts).
	var weld := {}
	var parent: Array[int] = []  # an Array, not packed: the lambda below shares it
	parent.resize(verts.size())
	for i in verts.size():
		var k := Vector3i((verts[i] * 1000.0).round())
		if weld.has(k):
			parent[i] = weld[k]
		else:
			weld[k] = i
			parent[i] = i
	var find := func(i: int) -> int:
		while parent[i] != i:
			parent[i] = parent[parent[i]]
			i = parent[i]
		return i
	for t in range(0, index.size(), 3):
		var a: int = find.call(index[t])
		for k in [1, 2]:
			var b: int = find.call(index[t + k])
			if a != b:
				parent[b] = a
	var box := {}
	for i in verts.size():
		var r: int = find.call(i)
		box[r] = (box[r] as AABB).expand(verts[i]) if box.has(r) else AABB(verts[i], Vector3.ZERO)
	var keep := PackedInt32Array()
	var rings: Array[Vector3] = []
	for t in range(0, index.size(), 3):
		var r: int = find.call(index[t])
		var b: AABB = box[r]
		if b.end.z > BRIDLE_BEHIND or b.size.z > REIN_LONG:
			continue
		keep.append(index[t])
		keep.append(index[t + 1])
		keep.append(index[t + 2])
	for r: int in box:
		var b: AABB = box[r]
		var c := b.get_center()
		if b.end.z <= BRIDLE_BEHIND and b.size.x < 0.04 and b.size.y < 0.08 and b.size.z < 0.08 and absf(c.x) > 0.04 and c.z < -1.3:
			rings.append(c)
	rings.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.x < b.x)
	if rings.size() >= 2:
		bits[0] = rings.front()
		bits[1] = rings.back()
	var out := arrays.duplicate()
	out[Mesh.ARRAY_INDEX] = keep
	return out
