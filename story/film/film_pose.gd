## Holds a cast member (or Feyre) in a staged pose for a film (lane L33):
## kneeling, sitting at table, sitting in the grass, crouching, bowed to the
## floor, reaching up. Layered over whatever the body animation is doing, so
## the breathing and the hands keep moving.
##
## The rig is humanoid and every bone points down its +Y to its child (as in
## BowArmPose). A pose is a set of directions, in the skeleton's own space
## (+Z the way the figure faces, +X its left, +Y up), that bones are turned
## toward by the shortest arc, parents first, plus a drop of the hips (as a
## share of the figure's own hip height, so it fits any of the cast). Bones
## a pose leaves out follow their parents. `to(pose, s)` crossfades.
class_name FilmPose
extends SkeletonModifier3D

const POSES := {
	# Upright on both knees, shins flat behind (the kiss in the glen).
	&"kneel": {"drop": 0.5, "back": 0.0, "aims": {
		"LeftUpperLeg": Vector3(0.04, -1.0, 0.06), "RightUpperLeg": Vector3(-0.04, -1.0, 0.06),
		"LeftLowerLeg": Vector3(0.0, -0.08, -1.0), "RightLowerLeg": Vector3(0.0, -0.08, -1.0),
		"LeftFoot": Vector3(0.0, -0.15, -1.0), "RightFoot": Vector3(0.0, -0.15, -1.0)}},
	# Sunk back onto her heels, shoulders down (Rhysand in her head).
	&"kneel_slump": {"drop": 0.7, "back": -0.1, "aims": {
		"LeftUpperLeg": Vector3(0.1, -0.35, 1.0), "RightUpperLeg": Vector3(-0.1, -0.35, 1.0),
		"LeftLowerLeg": Vector3(0.0, -0.2, -1.0), "RightLowerLeg": Vector3(0.0, -0.2, -1.0),
		"LeftFoot": Vector3(0.0, -0.1, -1.0), "RightFoot": Vector3(0.0, -0.1, -1.0),
		"Spine": Vector3(0.0, 1.0, 0.28), "Chest": Vector3(0.0, 1.0, 0.4), "Neck": Vector3(0.0, 1.0, 0.7),
		"LeftUpperArm": Vector3(0.25, -1.0, 0.45), "RightUpperArm": Vector3(-0.25, -1.0, 0.45),
		"LeftLowerArm": Vector3(0.1, -0.7, 1.0), "RightLowerArm": Vector3(-0.1, -0.7, 1.0)}},
	# Forehead to the marble (Tamlin begging).
	&"kneel_bow": {"drop": 0.66, "back": -0.16, "aims": {
		"LeftUpperLeg": Vector3(0.1, -0.3, 1.0), "RightUpperLeg": Vector3(-0.1, -0.3, 1.0),
		"LeftLowerLeg": Vector3(0.0, -0.2, -1.0), "RightLowerLeg": Vector3(0.0, -0.2, -1.0),
		"LeftFoot": Vector3(0.0, -0.1, -1.0), "RightFoot": Vector3(0.0, -0.1, -1.0),
		"Spine": Vector3(0.0, 0.55, 1.0), "Chest": Vector3(0.0, 0.1, 1.0), "UpperChest": Vector3(0.0, -0.2, 1.0),
		"Neck": Vector3(0.0, -0.6, 1.0), "Head": Vector3(0.0, -0.9, 0.5),
		"LeftUpperArm": Vector3(0.3, -0.9, 0.5), "RightUpperArm": Vector3(-0.3, -0.9, 0.5),
		"LeftLowerArm": Vector3(0.05, -0.3, 1.0), "RightLowerArm": Vector3(-0.05, -0.3, 1.0)}},
	# On a dining chair.
	&"sit": {"drop": 0.46, "back": 0.0, "aims": {
		"LeftUpperLeg": Vector3(0.05, -0.08, 1.0), "RightUpperLeg": Vector3(-0.05, -0.08, 1.0),
		"LeftLowerLeg": Vector3(0.0, -1.0, 0.08), "RightLowerLeg": Vector3(0.0, -1.0, 0.08),
		"LeftFoot": Vector3(0.0, -0.4, 1.0), "RightFoot": Vector3(0.0, -0.4, 1.0)}},
	# Slouched in the chair, one leg out (Tamlin pretending not to care).
	&"sit_slouch": {"drop": 0.5, "back": 0.08, "aims": {
		"LeftUpperLeg": Vector3(0.2, -0.05, 1.0), "RightUpperLeg": Vector3(-0.1, 0.0, 1.0),
		"LeftLowerLeg": Vector3(0.1, -1.0, 0.5), "RightLowerLeg": Vector3(0.0, -0.6, 1.0),
		"LeftFoot": Vector3(0.0, -0.3, 1.0), "RightFoot": Vector3(0.0, 0.2, 1.0),
		"Spine": Vector3(0.0, 1.0, -0.25), "Chest": Vector3(0.0, 1.0, -0.1)}},
	# Sitting in the grass, leaning back on the hands (the glen at noon).
	&"sit_ground": {"drop": 0.84, "back": 0.0, "aims": {
		"LeftUpperLeg": Vector3(0.12, -0.12, 1.0), "RightUpperLeg": Vector3(-0.08, -0.12, 1.0),
		"LeftLowerLeg": Vector3(0.05, -0.55, 1.0), "RightLowerLeg": Vector3(0.0, -0.12, 1.0),
		"LeftFoot": Vector3(0.0, 0.4, 1.0), "RightFoot": Vector3(0.0, 0.6, 1.0),
		"Spine": Vector3(0.0, 1.0, -0.4), "Chest": Vector3(0.0, 1.0, -0.2), "Neck": Vector3(0.0, 1.0, 0.25),
		"LeftUpperArm": Vector3(0.35, -1.0, -0.45), "RightUpperArm": Vector3(-0.35, -1.0, -0.45),
		"LeftLowerArm": Vector3(0.2, -1.0, -0.2), "RightLowerArm": Vector3(-0.2, -1.0, -0.2)}},
	# Balanced on the balls of the feet beside someone on the floor (Rhysand).
	&"crouch": {"drop": 0.48, "back": -0.1, "aims": {
		"LeftUpperLeg": Vector3(0.25, 0.25, 1.0), "RightUpperLeg": Vector3(-0.2, 0.1, 1.0),
		"LeftLowerLeg": Vector3(0.05, -1.0, -0.3), "RightLowerLeg": Vector3(0.0, -1.0, -0.45),
		"LeftFoot": Vector3(0.0, -0.5, 1.0), "RightFoot": Vector3(0.0, -0.8, 1.0),
		"Spine": Vector3(0.0, 1.0, 0.35), "Chest": Vector3(0.0, 1.0, 0.2),
		"LeftUpperArm": Vector3(0.2, -0.6, 1.0), "LeftLowerArm": Vector3(0.0, -0.9, 0.6)}},
	# Her right hand up at his face (pulling at the mask).
	&"reach": {"drop": 0.0, "back": 0.0, "aims": {
		"RightUpperArm": Vector3(-0.2, 0.55, 1.0), "RightLowerArm": Vector3(0.05, 0.75, 1.0),
		"RightHand": Vector3(0.0, 0.7, 1.0)}},
	# Kneeling, leaning in close (a kiss on the eyelids).
	&"kneel_lean": {"drop": 0.5, "back": 0.0, "aims": {
		"LeftUpperLeg": Vector3(0.04, -1.0, -0.05), "RightUpperLeg": Vector3(-0.04, -1.0, -0.05),
		"LeftLowerLeg": Vector3(0.0, -0.08, -1.0), "RightLowerLeg": Vector3(0.0, -0.08, -1.0),
		"LeftFoot": Vector3(0.0, -0.15, -1.0), "RightFoot": Vector3(0.0, -0.15, -1.0),
		"Spine": Vector3(0.0, 1.0, 0.3), "Chest": Vector3(0.0, 1.0, 0.42), "Neck": Vector3(0.0, 1.0, 0.55),
		"Head": Vector3(0.0, 1.0, 0.2),
		"LeftUpperArm": Vector3(0.2, -0.5, 1.0), "LeftLowerArm": Vector3(-0.3, 0.4, 1.0)}},
	# The same, kneeling.
	&"kneel_reach": {"drop": 0.5, "back": 0.0, "aims": {
		"LeftUpperLeg": Vector3(0.04, -1.0, 0.06), "RightUpperLeg": Vector3(-0.04, -1.0, 0.06),
		"LeftLowerLeg": Vector3(0.0, -0.08, -1.0), "RightLowerLeg": Vector3(0.0, -0.08, -1.0),
		"LeftFoot": Vector3(0.0, -0.15, -1.0), "RightFoot": Vector3(0.0, -0.15, -1.0),
		"RightUpperArm": Vector3(-0.2, 0.55, 1.0), "RightLowerArm": Vector3(0.05, 0.75, 1.0),
		"RightHand": Vector3(0.0, 0.7, 1.0)}},
	# A fist held low and close: the knife hidden against her skirt.
	&"knife_low": {"drop": 0.0, "back": 0.0, "aims": {
		"RightUpperArm": Vector3(-0.12, -1.0, 0.05), "RightLowerArm": Vector3(-0.05, -0.8, 0.6)}},
	# Back pressed into the curtain, arms flat against it (hiding).
	&"flat_back": {"drop": 0.0, "back": 0.0, "aims": {
		"LeftUpperArm": Vector3(0.35, -1.0, -0.2), "RightUpperArm": Vector3(-0.35, -1.0, -0.2),
		"LeftLowerArm": Vector3(0.2, -1.0, -0.25), "Spine": Vector3(0.0, 1.0, -0.12)}},
	# Packing a satchel on a table: bent forward, both hands at the table.
	&"pack": {"drop": 0.0, "back": 0.0, "aims": {
		"Spine": Vector3(0.0, 1.0, 0.35), "Chest": Vector3(0.0, 1.0, 0.45),
		"LeftUpperArm": Vector3(0.2, -0.7, 0.8), "RightUpperArm": Vector3(-0.2, -0.7, 0.8),
		"LeftLowerArm": Vector3(-0.1, -0.5, 1.0), "RightLowerArm": Vector3(0.1, -0.5, 1.0)}},
}

## The townsfolk rig (creatures/models/people): its bones by their humanoid
## names. It faces -Z in its own space, so its directions turn half round.
const PEOPLE_BONES := {"Hips": "pelvis", "Spine": "spine", "Chest": "chest", "Neck": "neck",
	"Head": "head", "LeftUpperArm": "arm_l", "LeftLowerArm": "forearm_l", "LeftHand": "hand_l",
	"RightUpperArm": "arm_r", "RightLowerArm": "forearm_r", "RightHand": "hand_r",
	"LeftUpperLeg": "upper_leg_l", "LeftLowerLeg": "lower_leg_l", "LeftFoot": "paw_leg_l",
	"RightUpperLeg": "upper_leg_r", "RightLowerLeg": "lower_leg_r", "RightFoot": "paw_leg_r"}

var pose: StringName = &""
var _people: int = -1   # -1 not looked yet, 0 humanoid, 1 townsfolk
var _from: Dictionary = {}
var _to: Dictionary = {}
var _mix: float = 1.0
var _tween: Tween
var _bones: Dictionary = {}
## Where the head is as drawn (this pose blended in), in the skeleton's space.
## Outside the modification pass the skeleton answers with the animated pose,
## not the posed one: a sitting figure's head reads a metre too high.
var head_local: Vector3
var has_head: bool = false
## Where the hips are as drawn, in the skeleton's space (the head's reason).
var hips_local: Vector3
var has_hips: bool = false


## The FilmPose on `figure`'s skeleton, made on first use. Null when it has none.
static func on(figure: Node) -> FilmPose:
	if figure == null:
		return null
	var found := figure.find_children("*", "FilmPose", true, false)
	if not found.is_empty():
		return found[0] as FilmPose
	var sks := figure.find_children("*", "Skeleton3D", true, false)
	if sks.is_empty():
		return null
	var p := FilmPose.new()
	p.name = "FilmPose"
	p.influence = 0.0
	(sks[0] as Skeleton3D).add_child(p)
	return p


## Crossfades into `pose_name` over `seconds` (&"" lets the body go free).
func to(pose_name: StringName, seconds: float = 0.6) -> void:
	var target: Dictionary = POSES.get(pose_name, {})
	_from = _current()
	_to = target
	pose = pose_name
	_mix = 0.0
	if _tween:
		_tween.kill()
	var start_influence := influence
	var end_influence := 0.0 if target.is_empty() else 1.0
	if seconds <= 0.0:
		_mix = 1.0
		influence = end_influence
		if target.is_empty():
			_from = {}
		return
	_tween = create_tween().set_parallel()
	_tween.tween_property(self, ^"_mix", 1.0, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if end_influence != start_influence:
		_tween.tween_property(self, ^"influence", end_influence, seconds)


## What the pose is right now (mid-blend included), as a pose dictionary.
func _current() -> Dictionary:
	if _from.is_empty() or _mix >= 1.0:
		return _to
	if _to.is_empty():
		return _from
	return _blend(_from, _to, _mix)


static func _blend(a: Dictionary, b: Dictionary, k: float) -> Dictionary:
	var aims := {}
	var aa: Dictionary = a.get("aims", {})
	var ba: Dictionary = b.get("aims", {})
	for bone in aa.keys() + ba.keys():
		if aa.has(bone) and ba.has(bone):
			aims[bone] = (aa[bone] as Vector3).normalized().slerp((ba[bone] as Vector3).normalized(), k)
		elif ba.has(bone):
			aims[bone] = ba[bone]
		elif k < 0.5:
			aims[bone] = aa[bone]
	return {"drop": lerpf(float(a.get("drop", 0.0)), float(b.get("drop", 0.0)), k),
		"back": lerpf(float(a.get("back", 0.0)), float(b.get("back", 0.0)), k), "aims": aims}


func _bone(sk: Skeleton3D, bone_name: String) -> int:
	if _people < 0:
		_people = 1 if sk.find_bone("Hips") < 0 and sk.find_bone("pelvis") >= 0 else 0
	if not _bones.has(bone_name):
		if _people == 1:
			_bones[bone_name] = sk.find_bone(String(PEOPLE_BONES.get(bone_name, "-")))
		else:
			_bones[bone_name] = sk.find_bone(bone_name)
	return _bones[bone_name]


## A pose direction (figure faces +Z) in this skeleton's own space.
func _dir(v: Vector3) -> Vector3:
	return Vector3(-v.x, v.y, -v.z) if _people == 1 else v


func _process_modification_with_delta(_delta: float) -> void:
	var sk := get_skeleton()
	has_head = false
	has_hips = false
	if sk == null or influence <= 0.001:
		return
	var p := _current()
	if p.is_empty():
		return
	var head := _bone(sk, "Head")
	var head_was := sk.get_bone_global_pose(head).origin if head >= 0 else Vector3.ZERO
	var hips := _bone(sk, "Hips")
	if hips >= 0:
		var hp := sk.get_bone_global_pose(hips)
		var h := sk.get_bone_global_rest(hips).origin.y
		var o := hp.origin + _dir(Vector3(0.0, -float(p.get("drop", 0.0)), float(p.get("back", 0.0)))) * h
		sk.set_bone_global_pose(hips, Transform3D(hp.basis, o))
		hips_local = hp.origin.lerp(o, influence)
		has_hips = true
	var aims: Dictionary = p.get("aims", {})
	var order: Array = []
	for bone_name in aims.keys():
		var i := _bone(sk, String(bone_name))
		if i >= 0:
			order.append([i, aims[bone_name]])
	order.sort_custom(func(x: Array, y: Array) -> bool: return int(x[0]) < int(y[0]))
	for entry in order:
		var i := int(entry[0])
		var pose_now := sk.get_bone_global_pose(i)
		var from_dir := pose_now.basis.y.normalized()
		var to_dir := _dir(entry[1] as Vector3).normalized()
		if from_dir.dot(to_dir) > 0.99999 or from_dir.dot(to_dir) < -0.99999:
			continue
		sk.set_bone_global_pose(i, Transform3D(Basis(Quaternion(from_dir, to_dir)) * pose_now.basis, pose_now.origin))
	if head >= 0:
		head_local = head_was.lerp(sk.get_bone_global_pose(head).origin, influence)
		has_head = true
