## Lifts Feyre's arms into a bow pose over whatever her body animation is
## doing: the bow arm reaches straight along the aim, the string hand starts at
## the string and comes back to her chin as the draw fills. Two-bone IK per
## arm, solved in skeleton space; `influence` blends it in and out.
##
## The rig is humanoid (bones point down +Y to their child), so each bone is
## turned by the shortest arc from where it points to where it should point,
## which keeps the animation's twist.
class_name BowArmPose
extends SkeletonModifier3D

## World-space aim direction (unit). Set every frame by BowVisual.
var aim_dir: Vector3 = Vector3.FORWARD
## 0 at the string, 1 at full draw (the chin).
var draw: float = 0.0
## Which arm holds the bow. Feyre draws right-handed, so the bow is in her left.
var bow_side: String = "Left"
var draw_side: String = "Right"

var _bones: Dictionary = {}
## Hand positions (world) from the last solve. The skeleton only keeps a
## modified pose until it has drawn, so later reads come from here.
var _bow_hand := Vector3.ZERO
var _string_hand := Vector3.ZERO
var _solved: bool = false


func _ready() -> void:
	influence = 0.0


func _bone(bone_name: String) -> int:
	if not _bones.has(bone_name):
		var sk := get_skeleton()
		_bones[bone_name] = sk.find_bone(bone_name) if sk else -1
	return _bones[bone_name]


func _process_modification_with_delta(_delta: float) -> void:
	var sk := get_skeleton()
	if sk == null or influence <= 0.001:
		_solved = false
		return
	var bow_upper := _bone(bow_side + "UpperArm")
	var bow_lower := _bone(bow_side + "LowerArm")
	var bow_hand := _bone(bow_side + "Hand")
	var str_upper := _bone(draw_side + "UpperArm")
	var str_lower := _bone(draw_side + "LowerArm")
	var str_hand := _bone(draw_side + "Hand")
	var head := _bone("Head")
	if -1 in [bow_upper, bow_lower, bow_hand, str_upper, str_lower, str_hand, head]:
		return
	var to_skel := sk.global_transform.affine_inverse()
	var dir := (to_skel.basis * aim_dir).normalized()
	var up := (to_skel.basis * Vector3.UP).normalized()
	var s_bow := sk.get_bone_global_pose(bow_upper).origin
	var s_str := sk.get_bone_global_pose(str_upper).origin
	var reach := _length(sk, bow_upper, bow_lower) + _length(sk, bow_lower, bow_hand)
	# Bow arm: almost straight down the aim line, elbow turned out and down.
	var outward := (s_bow - s_str).normalized()
	var grip := s_bow + dir * reach * 0.96
	_solve(sk, bow_upper, bow_lower, bow_hand, grip, -up + outward * 0.5)
	# String hand: at the string just behind the grip, back to the chin as the
	# draw fills (the anchor point: under the jaw, beside the mouth).
	var chin := sk.get_bone_global_pose(head).origin - up * 0.07 + dir * 0.06 - outward * 0.04
	var nock := grip - dir * 0.16
	var target := nock.lerp(chin, clampf(draw, 0.0, 1.0))
	_solve(sk, str_upper, str_lower, str_hand, target, -outward + up * 0.6 - dir * 0.4)
	# Hands follow their forearms (no wrist bend from the walk cycle).
	_follow(sk, bow_lower, bow_hand)
	_follow(sk, str_lower, str_hand)
	var to_world := sk.global_transform
	var mix := influence
	_bow_hand = to_world * sk.get_bone_global_pose(bow_hand).origin
	_string_hand = to_world * sk.get_bone_global_pose(str_hand).origin
	_solved = mix > 0.001


## Where the string hand sits right now, in world space (the nock point).
func string_hand_world() -> Vector3:
	if _solved and influence > 0.001:
		return _string_hand
	var sk := get_skeleton()
	var i := _bone(draw_side + "Hand")
	if sk == null or i < 0:
		return Vector3.ZERO
	return sk.global_transform * sk.get_bone_global_pose(i).origin


func bow_hand_world() -> Vector3:
	if _solved and influence > 0.001:
		return _bow_hand
	var sk := get_skeleton()
	var i := _bone(bow_side + "Hand")
	if sk == null or i < 0:
		return Vector3.ZERO
	return sk.global_transform * sk.get_bone_global_pose(i).origin


static func _length(sk: Skeleton3D, a: int, b: int) -> float:
	return sk.get_bone_global_rest(a).origin.distance_to(sk.get_bone_global_rest(b).origin)


## Classic two-bone solve: shoulder at `upper`, elbow at `lower`, wrist at
## `hand`, reaching for `target`, the elbow bending toward `pole`.
func _solve(sk: Skeleton3D, upper: int, lower: int, hand: int, target: Vector3, pole: Vector3) -> void:
	var s := sk.get_bone_global_pose(upper).origin
	var a := _length(sk, upper, lower)
	var b := _length(sk, lower, hand)
	var to_t := target - s
	var d := clampf(to_t.length(), absf(a - b) + 0.001, a + b - 0.001)
	var n := to_t.normalized() if to_t.length() > 0.0001 else Vector3.FORWARD
	var m := pole - n * pole.dot(n)
	if m.length() < 0.0001:
		m = n.cross(Vector3.RIGHT)
	m = m.normalized()
	var cos_a := clampf((a * a + d * d - b * b) / (2.0 * a * d), -1.0, 1.0)
	var elbow := s + n * a * cos_a + m * a * sqrt(1.0 - cos_a * cos_a)
	var wrist := s + n * d
	_point(sk, upper, elbow)
	_point(sk, lower, wrist)


## Turns bone `i` so its +Y points at `at` (the skeleton blends by influence).
func _point(sk: Skeleton3D, i: int, at: Vector3) -> void:
	var pose := sk.get_bone_global_pose(i)
	var from_dir := pose.basis.y.normalized()
	var to_dir := (at - pose.origin).normalized()
	if from_dir.dot(to_dir) > 0.99999:
		return
	var turn := Quaternion(from_dir, to_dir)
	sk.set_bone_global_pose(i, Transform3D(Basis(turn) * pose.basis, pose.origin))


## Lines bone `child` up with `parent`'s direction (a straight wrist).
func _follow(sk: Skeleton3D, parent: int, child: int) -> void:
	var p := sk.get_bone_global_pose(parent)
	var c := sk.get_bone_global_pose(child)
	_point(sk, child, c.origin + p.basis.y.normalized())
