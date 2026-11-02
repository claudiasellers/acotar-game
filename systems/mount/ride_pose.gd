## Feyre's seat in the saddle (lane L47): legs astride the mare's barrel,
## knees bent, hands forward on the reins, a lean into the gallop. Sits on her
## Skeleton3D after the AnimationTree and aims each bone at a direction in her
## own frame (forward, up, her left), read from the rest pose, so it works on
## the shared cast rig whatever its bone axes. `amount` 0..1 eases it in and out;
## `lean` 0..1 tips the upper body forward; `bounce` is the gait's lift (m).
class_name RidePose
extends SkeletonModifier3D

## [bone, child, forward, up, outward]: the bone points from its head toward its
## child along this direction (outward is toward her left for Left* bones).
const AIMS := [
	[&"LeftUpperLeg", &"LeftLowerLeg", 0.62, -0.42, 0.66],
	[&"RightUpperLeg", &"RightLowerLeg", 0.62, -0.42, 0.66],
	[&"LeftLowerLeg", &"LeftFoot", -0.12, -0.97, 0.2],
	[&"RightLowerLeg", &"RightFoot", -0.12, -0.97, 0.2],
	[&"LeftFoot", &"LeftToes", 0.9, -0.25, 0.25],
	[&"RightFoot", &"RightToes", 0.9, -0.25, 0.25],
	[&"LeftUpperArm", &"LeftLowerArm", 0.42, -0.85, 0.22],
	[&"RightUpperArm", &"RightLowerArm", 0.42, -0.85, 0.22],
	[&"LeftLowerArm", &"LeftHand", 0.9, -0.15, -0.38],
	[&"RightLowerArm", &"RightHand", 0.9, -0.15, -0.38],
]
const LEAN_BONES := {&"Spine": 10.0, &"Chest": 8.0, &"Neck": -8.0}

var amount: float = 0.0
var lean: float = 0.0
## The skeleton-space frame: x = her forward, y = up, z = her left.
var forward := Vector3.FORWARD
var up := Vector3.UP
var left := Vector3.LEFT
## Height of her hips above her feet in the rest pose (skeleton space, metres).
var hip_height: float = 0.95

var _aims: Array = []  # [bone, child, Vector3 want]
var _lean: Dictionary = {}  # bone -> radians


static func attach(sk: Skeleton3D) -> RidePose:
	var existing := sk.get_node_or_null(^"RidePose") as RidePose
	if existing:
		return existing
	var r := RidePose.new()
	r.name = "RidePose"
	sk.add_child(r)
	r._read_frame(sk)
	return r


func _read_frame(sk: Skeleton3D) -> void:
	var hips := sk.find_bone(&"Hips")
	var head := sk.find_bone(&"Head")
	var lul := sk.find_bone(&"LeftUpperLeg")
	var rul := sk.find_bone(&"RightUpperLeg")
	var foot := sk.find_bone(&"LeftFoot")
	var toes := sk.find_bone(&"LeftToes")
	if mini(mini(hips, head), mini(mini(lul, rul), mini(foot, toes))) < 0:
		return
	var p := func(i: int) -> Vector3: return sk.get_bone_global_rest(i).origin
	up = (p.call(head) - p.call(hips)).normalized()
	left = (p.call(lul) - p.call(rul))
	left = (left - up * left.dot(up)).normalized()
	forward = up.cross(left).normalized()
	var toe_dir: Vector3 = p.call(toes) - p.call(foot)
	if toe_dir.dot(forward) < 0.0:
		forward = -forward
		left = -left
	hip_height = (p.call(hips) - p.call(foot)).dot(up)
	_aims.clear()
	for a: Array in AIMS:
		var b := sk.find_bone(a[0])
		var c := sk.find_bone(a[1])
		if b < 0 or c < 0:
			continue
		var side := 1.0 if String(a[0]).begins_with("Left") else -1.0
		var want: Vector3 = (forward * float(a[2]) + up * float(a[3]) + left * side * float(a[4])).normalized()
		_aims.append([b, c, want])
	_lean.clear()
	for bone: StringName in LEAN_BONES:
		var i := sk.find_bone(bone)
		if i >= 0:
			_lean[i] = deg_to_rad(float(LEAN_BONES[bone]))


## The bone each aim drives, for tests.
func driven_bones() -> PackedStringArray:
	var out := PackedStringArray()
	var sk := get_skeleton()
	for a: Array in _aims:
		out.append(sk.get_bone_name(a[0]) if sk else "")
	return out


func _process_modification() -> void:
	if amount <= 0.001:
		return
	var sk := get_skeleton()
	if sk == null:
		return
	# Lean: pitch forward about her left axis (in each bone's parent space).
	if lean > 0.001:
		for i: int in _lean:
			var parent := sk.get_bone_parent(i)
			var axis := left
			if parent >= 0:
				axis = (sk.get_bone_global_pose(parent).basis.inverse() * left).normalized()
			var q := sk.get_bone_pose_rotation(i)
			sk.set_bone_pose_rotation(i, Quaternion(axis, float(_lean[i]) * lean * amount) * q)
	# Aims, parents first (the table is ordered that way).
	for a: Array in _aims:
		var b: int = a[0]
		var c: int = a[1]
		var g := sk.get_bone_global_pose(b)
		var child := sk.get_bone_global_pose(c)
		var cur := child.origin - g.origin
		if cur.length_squared() < 1e-8:
			continue
		cur = cur.normalized()
		var want: Vector3 = cur.slerp(a[2], amount).normalized()
		var turn := Quaternion(cur, want) if cur.dot(want) > -0.999 else Quaternion(up, PI)
		var parent := sk.get_bone_parent(b)
		var pg := sk.get_bone_global_pose(parent) if parent >= 0 else Transform3D.IDENTITY
		var new_global := Basis(turn) * g.basis
		sk.set_bone_pose_rotation(b, (pg.basis.inverse() * new_global).get_rotation_quaternion())
