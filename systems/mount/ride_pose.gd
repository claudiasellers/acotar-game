## Feyre's seat in the saddle (lane L47): legs astride the mare's barrel,
## knees bent, hands forward on the reins, a lean into the gallop. Sits on her
## Skeleton3D after the AnimationTree and aims each bone at a direction in her
## own frame (forward, up, her left), read from the rest pose, so it works on
## the shared cast rig whatever its bone axes. `amount` 0..1 eases it in and out;
## `lean` 0..1 tips the upper body forward; `bank` -1..1 tips it into a turn
## (positive: toward her left). Overrides (set_override) aim single bones on
## top of everything with their own weight, even at amount 0: the swing up
## into the saddle, the slide down, the whistle to her lips (L47-6).
class_name RidePose
extends SkeletonModifier3D

## [bone, child, forward, up, outward]: the bone points from its head toward its
## child along this direction (outward is toward her left for Left* bones).
const AIMS := [
	[&"LeftUpperLeg", &"LeftLowerLeg", 0.25, -0.5, 0.95],
	[&"RightUpperLeg", &"RightLowerLeg", 0.25, -0.5, 0.95],
	[&"LeftLowerLeg", &"LeftFoot", -0.15, -0.92, 0.45],
	[&"RightLowerLeg", &"RightFoot", -0.15, -0.92, 0.45],
	[&"LeftFoot", &"LeftToes", 0.9, -0.25, 0.25],
	[&"RightFoot", &"RightToes", 0.9, -0.25, 0.25],
	[&"LeftUpperArm", &"LeftLowerArm", 0.42, -0.85, 0.22],
	[&"RightUpperArm", &"RightLowerArm", 0.42, -0.85, 0.22],
	[&"LeftLowerArm", &"LeftHand", 0.9, -0.15, -0.38],
	[&"RightLowerArm", &"RightHand", 0.9, -0.15, -0.38],
]
const LEAN_BONES := {&"Spine": 10.0, &"Chest": 8.0, &"Neck": -8.0}
## Into a turn: spine and chest roll toward the inside, the neck keeps the head level.
const BANK_BONES := {&"Spine": 7.0, &"Chest": 5.0, &"Neck": -9.0}
## Parents before children: the order overrides are applied in.
const OVERRIDE_ORDER: Array[StringName] = [&"Hips", &"Spine", &"Chest", &"Neck", &"Head",
	&"LeftUpperLeg", &"RightUpperLeg", &"LeftLowerLeg", &"RightLowerLeg", &"LeftFoot", &"RightFoot",
	&"LeftShoulder", &"RightShoulder", &"LeftUpperArm", &"RightUpperArm", &"LeftLowerArm", &"RightLowerArm",
	&"LeftHand", &"RightHand"]
## Each bone's child, for aiming it.
const CHILD_OF := {&"LeftUpperLeg": &"LeftLowerLeg", &"RightUpperLeg": &"RightLowerLeg",
	&"LeftLowerLeg": &"LeftFoot", &"RightLowerLeg": &"RightFoot", &"LeftFoot": &"LeftToes",
	&"RightFoot": &"RightToes", &"LeftUpperArm": &"LeftLowerArm", &"RightUpperArm": &"RightLowerArm",
	&"LeftLowerArm": &"LeftHand", &"RightLowerArm": &"RightHand", &"Spine": &"Chest", &"Chest": &"Neck",
	&"Neck": &"Head"}

var amount: float = 0.0
var lean: float = 0.0
var bank: float = 0.0
## The skeleton-space frame: x = her forward, y = up, z = her left.
var forward := Vector3.FORWARD
var up := Vector3.UP
var left := Vector3.LEFT
## Height of her hips above her feet in the rest pose (skeleton space, metres).
var hip_height: float = 0.95

var _aims: Array = []  # [bone, child, Vector3 want]
var _lean: Dictionary = {}  # bone -> radians
var _bank: Dictionary = {}  # bone -> radians
var _over: Dictionary = {}  # bone name -> [fwd, up, out, weight]


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
	_bank.clear()
	for bone: StringName in BANK_BONES:
		var i := sk.find_bone(bone)
		if i >= 0:
			_bank[i] = deg_to_rad(float(BANK_BONES[bone]))


## Aims `bone` at a direction in her own frame (forward, up, and out to that
## bone's side: her left for Left* bones, her right for Right* ones), blended
## over whatever else posed it by `weight` 0..1. Weight 0 removes it.
func set_override(bone: StringName, fwd: float, up_amount: float, out: float, weight: float) -> void:
	if weight <= 0.001:
		_over.erase(bone)
	else:
		_over[bone] = [fwd, up_amount, out, minf(weight, 1.0)]


func clear_overrides() -> void:
	_over.clear()


func has_overrides() -> bool:
	return not _over.is_empty()


## The world-free direction an override asks for, in skeleton space.
func override_dir(bone: StringName, fwd: float, up_amount: float, out: float) -> Vector3:
	var side := 1.0 if String(bone).begins_with("Left") else (-1.0 if String(bone).begins_with("Right") else 0.0)
	return (forward * fwd + up * up_amount + left * side * out).normalized()


## The bone each aim drives, for tests.
func driven_bones() -> PackedStringArray:
	var out := PackedStringArray()
	var sk := get_skeleton()
	for a: Array in _aims:
		out.append(sk.get_bone_name(a[0]) if sk else "")
	return out


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	if amount > 0.001:
		_seat_pose(sk)
	if not _over.is_empty():
		_apply_overrides(sk)


func _apply_overrides(sk: Skeleton3D) -> void:
	for bone: StringName in OVERRIDE_ORDER:
		if not _over.has(bone) or not CHILD_OF.has(bone):
			continue
		var o: Array = _over[bone]
		var b := sk.find_bone(bone)
		var c := sk.find_bone(CHILD_OF[bone])
		if b < 0 or c < 0:
			continue
		_aim(sk, b, c, override_dir(bone, o[0], o[1], o[2]), float(o[3]))


func _aim(sk: Skeleton3D, b: int, c: int, target: Vector3, w: float) -> void:
	var g := sk.get_bone_global_pose(b)
	var cur := sk.get_bone_global_pose(c).origin - g.origin
	if cur.length_squared() < 1e-8:
		return
	cur = cur.normalized()
	var want: Vector3 = cur.slerp(target, w).normalized()
	var turn := Quaternion(cur, want) if cur.dot(want) > -0.999 else Quaternion(up, PI)
	var parent := sk.get_bone_parent(b)
	var pg := sk.get_bone_global_pose(parent) if parent >= 0 else Transform3D.IDENTITY
	sk.set_bone_pose_rotation(b, (pg.basis.inverse() * (Basis(turn) * g.basis)).get_rotation_quaternion())


func _seat_pose(sk: Skeleton3D) -> void:
	# Lean: pitch forward about her left axis (in each bone's parent space).
	if lean > 0.001:
		for i: int in _lean:
			var parent := sk.get_bone_parent(i)
			var axis := left
			if parent >= 0:
				axis = (sk.get_bone_global_pose(parent).basis.inverse() * left).normalized()
			var q := sk.get_bone_pose_rotation(i)
			sk.set_bone_pose_rotation(i, Quaternion(axis, float(_lean[i]) * lean * amount) * q)
	# Bank: roll about her forward axis toward the inside of the turn.
	if absf(bank) > 0.001:
		for i: int in _bank:
			var parent := sk.get_bone_parent(i)
			var axis := forward
			if parent >= 0:
				axis = (sk.get_bone_global_pose(parent).basis.inverse() * forward).normalized()
			var q := sk.get_bone_pose_rotation(i)
			sk.set_bone_pose_rotation(i, Quaternion(axis, -float(_bank[i]) * bank * amount) * q)
	# Aims, parents first (the table is ordered that way).
	for a: Array in _aims:
		_aim(sk, a[0], a[1], a[2], amount)
