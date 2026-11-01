## People notice Feyre. When she comes within a few metres and in front of
## them, the head turns to her eyes (a LookAtModifier3D on the head bone, with
## human limits) and eases back when she leaves. Works on any skeleton whose
## owner faces -Z: the villagers' rig, the court folk, and the main cast on
## Feyre's rig. Contract: docs/contracts/creature_motion.md.
class_name NoticePlayer
extends Node

const RADIUS := 7.0
## How far behind them she can be and still be noticed (dot of their facing
## with the direction to her).
const FRONT := -0.15
## Feyre's eye height above her origin.
const EYE_HEIGHT := 1.55
const HEAD_BONES: Array[String] = ["head", "Head", "mixamorig:Head"]

var skeleton: Skeleton3D
var body: Node3D
var look: LookAtModifier3D
## 0..1, eased: how much the head is turned to her.
var weight: float = 0.0
## Scenes can stop the noticing (a staged look elsewhere).
var enabled: bool = true

var _target: Node3D


## Adds the head look to `sk` for an owner `owner_body` facing -Z. Null when the
## skeleton has no head bone.
static func attach(sk: Skeleton3D, owner_body: Node3D) -> NoticePlayer:
	if sk == null or owner_body == null:
		return null
	var bone := -1
	for name in HEAD_BONES:
		bone = sk.find_bone(name)
		if bone >= 0:
			break
	if bone < 0:
		return null
	var n := NoticePlayer.new()
	n.name = "NoticePlayer"
	n.skeleton = sk
	n.body = owner_body
	n._target = Node3D.new()
	n._target.name = "NoticeTarget"
	n.add_child(n._target)
	owner_body.add_child(n)
	var look := LookAtModifier3D.new()
	look.name = "NoticeLook"
	look.bone_name = sk.get_bone_name(bone)
	var rest := sk.get_bone_global_rest(bone).basis
	var to_skel := sk.global_basis.inverse() if sk.is_inside_tree() else Basis.IDENTITY
	var front := (to_skel * -owner_body.global_basis.z).normalized() if owner_body.is_inside_tree() else Vector3.FORWARD
	var up := (to_skel * Vector3.UP).normalized()
	look.forward_axis = _bone_axis(rest, front)
	var up_axis := _bone_axis(rest, up)
	look.primary_rotation_axis = [Vector3.AXIS_X, Vector3.AXIS_X, Vector3.AXIS_Y, Vector3.AXIS_Y,
			Vector3.AXIS_Z, Vector3.AXIS_Z][up_axis]
	look.use_secondary_rotation = true
	look.use_angle_limitation = true
	look.symmetry_limitation = true
	look.primary_limit_angle = deg_to_rad(150.0)
	look.primary_damp_threshold = 0.6
	look.secondary_limit_angle = deg_to_rad(60.0)
	look.secondary_damp_threshold = 0.6
	look.duration = 0.35
	look.transition_type = Tween.TRANS_SINE
	look.influence = 0.0
	sk.add_child(look)
	look.target_node = look.get_path_to(n._target)
	n.look = look
	return n


## The skeleton BoneAxis (+X -X +Y -Y +Z -Z) of `basis` closest to `dir`.
static func _bone_axis(basis: Basis, dir: Vector3) -> int:
	var best := 0
	var best_dot := -INF
	for i in 6:
		var axis: Vector3 = basis[i / 2].normalized() * (1.0 if i % 2 == 0 else -1.0)
		var d := axis.dot(dir)
		if d > best_dot:
			best_dot = d
			best = i
	return best


func _process(delta: float) -> void:
	if look == null or not is_instance_valid(skeleton):
		return
	var want := 0.0
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	if enabled and player != null:
		var eye := player.global_position + Vector3.UP * EYE_HEIGHT
		_target.global_position = eye
		var to := eye - body.global_position
		to.y = 0.0
		var facing := -body.global_basis.z
		facing.y = 0.0
		if to.length() < RADIUS and facing.normalized().dot(to.normalized()) > FRONT:
			want = 1.0
	weight = move_toward(weight, want, delta * 1.4)
	look.influence = smoothstep(0.0, 1.0, weight)
