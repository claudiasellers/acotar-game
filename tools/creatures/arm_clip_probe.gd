## Do standing arms go into the body? Stands people in their idle and measures
## how far the hands and forearms sit behind what they should hang beside:
## skirts, hips, tunics, a satchel, a quiver.
##   tools/mq/godot.sh --fixed-fps 60 -s tools/creatures/arm_clip_probe.gd -- [scene or model ...]
## With no arguments it runs Feyre, the cast and every model in
## creatures/models/people. One row per body:
##   depth  metres the worst hand or forearm point is covered by another part
##          of the body or its clothes, looking straight out from the spine
##          (0 = clear)
##   share  how much of the hands and forearms is covered at all (0 to 1)
##   by     the mesh that covers the worst point
## A cloak or hair worn outside the arm covers it too and counts: read a row
## against the same row before a change. Exits 1 over MAX_DEPTH.
extends SceneTree

const MAX_DEPTH := 0.005
## Cover further out than this is something worn over the arm, not a hand in a hip.
const REACH := 0.06
const SAMPLES := 4
const FRAMES_BETWEEN := 75
const MAX_POINTS := 260
const ARM_PARTS: Array[String] = ["LowerArm", "Hand", "Thumb", "Index", "Middle", "Ring", "Little", "forearm_", "hand_"]
## Neither arm nor body: the upper arm lies against the ribs, hair falls over shoulders.
const SKIP_PARTS: Array[String] = ["UpperArm", "Shoulder", "arm_", "clav", "Head", "Neck", "Jaw", "Eye", "Braid", "head", "neck", "hair"]
const CAST: Array[String] = ["res://characters/feyre/feyre.tscn", "res://characters/lucien/lucien_model.tscn",
	"res://characters/tamlin/tamlin_model.tscn", "res://characters/nesta/nesta_model.tscn",
	"res://characters/elain/elain_model.tscn", "res://characters/father/father_model.tscn",
	"res://characters/alis/alis_model.tscn", "res://characters/rhysand/rhysand_model.tscn",
	"res://characters/summer_faerie/summer_faerie_model.tscn"]

var _worst := 0.0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var paths := OS.get_cmdline_user_args()
	if paths.is_empty():
		paths = PackedStringArray(CAST)
		for f in DirAccess.get_files_at("res://creatures/models/people"):
			if f.ends_with(".gltf"):
				paths.append("res://creatures/models/people/" + f)
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = WorldBoundaryShape3D.new()
	floor_body.add_child(shape)
	root.add_child(floor_body)
	print("body depth share by")
	for p in paths:
		await _body(p)
	print("worst depth %.4f (limit %.3f)" % [_worst, MAX_DEPTH])
	quit(1 if _worst > MAX_DEPTH else 0)


func _body(path: String) -> void:
	var body := (load(path) as PackedScene).instantiate() as Node3D
	root.add_child(body)
	var player := body.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if path.get_extension() in ["gltf", "glb"] and player and player.has_animation(&"idle"):
		player.play(&"idle")
	var deepest := 0.0
	var share := 0.0
	var cover := "-"
	for sample in SAMPLES:
		for k in FRAMES_BETWEEN if sample > 0 else 30:
			await physics_frame
			await process_frame
		var found := _depth(body)
		share = maxf(share, found[2])
		if found[0] > deepest:
			deepest = found[0]
			cover = found[1]
	print("%s %.4f %.2f %s" % [path.get_file().get_basename(), deepest, share, cover])
	_worst = maxf(_worst, deepest)
	body.free()


## [worst depth, name of the covering mesh, share of points covered] for the body as it stands now.
func _depth(body: Node3D) -> Array:
	var points: Array[Vector3] = []
	var tris: Array[PackedVector3Array] = []
	var names: Array[String] = []
	var centre := Vector3.ZERO
	for node in body.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if not mi.is_visible_in_tree() or mi.mesh == null:
			continue
		var skeleton := mi.get_node_or_null(mi.skeleton) as Skeleton3D
		var hung := _hung_on(mi)
		if skeleton == null and hung == "":
			continue
		if skeleton:
			centre = skeleton.global_transform * skeleton.get_bone_global_pose(maxi(skeleton.find_bone("Hips"), 0)).origin
		for s in mi.mesh.get_surface_count():
			var arrays := mi.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] else PackedInt32Array()
			var placed := PackedVector3Array()
			var kind := PackedByteArray()   # 0 skip, 1 arm, 2 body
			placed.resize(verts.size())
			kind.resize(verts.size())
			if skeleton and arrays[Mesh.ARRAY_BONES]:
				_skin(mi, skeleton, verts, arrays[Mesh.ARRAY_BONES], arrays[Mesh.ARRAY_WEIGHTS], placed, kind)
			else:
				# Something held in the hand (a cane) is not the arm.
				var k := 2 if _kind(hung) == 2 else 0
				for i in verts.size():
					placed[i] = mi.global_transform * verts[i]
					kind[i] = k
			for i in verts.size():
				if kind[i] == 1:
					points.append(placed[i])
			var body_tris := PackedVector3Array()
			for t in range(0, index.size() - 2, 3):
				if kind[index[t]] == 2 and kind[index[t + 1]] == 2 and kind[index[t + 2]] == 2:
					body_tris.append(placed[index[t]])
					body_tris.append(placed[index[t + 1]])
					body_tris.append(placed[index[t + 2]])
			if not body_tris.is_empty():
				tris.append(body_tris)
				names.append(String(mi.name))
	if points.is_empty():
		return [0.0, "-", 0.0]
	var box := AABB(points[0], Vector3.ZERO)
	for p in points:
		box = box.expand(p)
	box = box.grow(REACH)
	var step := maxi(points.size() / MAX_POINTS, 1)
	var deepest := 0.0
	var cover := "-"
	var covered := {}
	for m in tris.size():
		var near := PackedVector3Array()
		var all := tris[m]
		for t in range(0, all.size(), 3):
			if box.intersects(AABB(all[t], Vector3.ZERO).expand(all[t + 1]).expand(all[t + 2])):
				near.append(all[t])
				near.append(all[t + 1])
				near.append(all[t + 2])
		for i in range(0, points.size(), step):
			var p := points[i]
			var out := Vector3(p.x - centre.x, 0.0, p.z - centre.z).normalized()
			for t in range(0, near.size(), 3):
				var hit: Variant = Geometry3D.ray_intersects_triangle(p, out, near[t], near[t + 1], near[t + 2])
				if hit != null:
					var d := ((hit as Vector3) - p).length()
					if d <= REACH:
						covered[i] = true
						if d > deepest:
							deepest = d
							cover = names[m]
	return [deepest, cover, float(covered.size()) / ceilf(float(points.size()) / step)]


## Places every vertex by its bones and sorts it by the bone that holds it most.
func _skin(mi: MeshInstance3D, skeleton: Skeleton3D, verts: PackedVector3Array, bones: PackedInt32Array,
		weights: PackedFloat32Array, placed: PackedVector3Array, kind: PackedByteArray) -> void:
	var per := bones.size() / verts.size()
	var skin := mi.skin
	var count := skin.get_bind_count() if skin else skeleton.get_bone_count()
	var mats: Array[Transform3D] = []
	var kinds := PackedByteArray()
	for b in count:
		var bone := b
		var bind := Transform3D.IDENTITY
		if skin:
			bone = skin.get_bind_bone(b)
			if bone < 0:
				bone = skeleton.find_bone(skin.get_bind_name(b))
			bind = skin.get_bind_pose(b)
		else:
			bind = skeleton.get_bone_global_rest(b).affine_inverse()
		mats.append(skeleton.global_transform * skeleton.get_bone_global_pose(maxi(bone, 0)) * bind)
		kinds.append(_kind(skeleton.get_bone_name(maxi(bone, 0))))
	for i in verts.size():
		var p := Vector3.ZERO
		var most := 0.0
		var lead := 0
		for k in per:
			var w := weights[i * per + k]
			if w <= 0.0:
				continue
			var b := bones[i * per + k]
			p += (mats[b] * verts[i]) * w
			if w > most:
				most = w
				lead = b
		placed[i] = p
		kind[i] = kinds[lead]


static func _kind(bone: String) -> int:
	for part in ARM_PARTS:
		if bone.contains(part):
			return 1
	for part in SKIP_PARTS:
		if bone.contains(part):
			return 0
	return 2


## The bone an unskinned prop hangs on, or "" when it is on none.
static func _hung_on(mi: MeshInstance3D) -> String:
	var n: Node = mi.get_parent()
	while n:
		if n is BoneAttachment3D:
			return (n as BoneAttachment3D).bone_name
		n = n.get_parent()
	return ""
