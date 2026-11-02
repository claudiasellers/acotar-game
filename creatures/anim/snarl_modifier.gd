## A wolf's face on its bones (lane L36-3, docs/contracts/faces.md): the jaw
## drops, the ears pin back or prick forward and the head sinks, on top of
## whatever clip is playing.  The wolf rigs (tools/blender/creature_rig.py)
## carry head, jaw, ear_l and ear_r but no lips, so the snarl is jaw, ears and
## carriage; the teeth are modelled bared.  CreatureFace sets `weights`.
## Sits on the Skeleton3D after the AnimationTree, like HunchModifier.
class_name SnarlModifier
extends SkeletonModifier3D

## Each channel at weight 1, in degrees about the bone's own X axis, and which
## way (in the skeleton's space: the model faces -Z) the bone's tip must go.
const CHANNELS := {
	&"jaw_open": [[&"jaw", 32.0, Vector3.DOWN]],
	&"ears_back": [[&"ear_l", 60.0, Vector3.BACK], [&"ear_r", 60.0, Vector3.BACK]],
	&"ears_up": [[&"ear_l", 18.0, Vector3.FORWARD], [&"ear_r", 18.0, Vector3.FORWARD]],
	&"head_low": [[&"head", 16.0, Vector3.DOWN], [&"neck", 8.0, Vector3.DOWN]],
}

## Channel name -> weight 0..1.
var weights: Dictionary = {}
## Channel -> [[bone index, signed radians], ...], resolved from the rest pose.
var _moves: Dictionary = {}


## Adds the modifier when the skeleton has a jaw; null otherwise.
static func attach(sk: Skeleton3D) -> SnarlModifier:
	if sk == null or sk.find_bone(&"jaw") < 0:
		return null
	var m := SnarlModifier.new()
	m.name = "Snarl"
	for ch: StringName in CHANNELS:
		var moves: Array = []
		for spec: Array in CHANNELS[ch]:
			var i := sk.find_bone(spec[0] as StringName)
			if i >= 0:
				moves.append([i, deg_to_rad(float(spec[1])) * _sign_for(sk, i, spec[2] as Vector3)])
		m._moves[ch] = moves
	sk.add_child(m)
	return m


## Which way round the bone's X axis sends its tip (+Y) toward `want`: rigs differ
## in roll, so the sign is read from the rest pose rather than assumed.
static func _sign_for(sk: Skeleton3D, bone: int, want: Vector3) -> float:
	var b := sk.get_bone_global_rest(bone).basis
	var plus := (b * Basis(Vector3.RIGHT, 0.3)) * Vector3.UP
	var minus := (b * Basis(Vector3.RIGHT, -0.3)) * Vector3.UP
	return 1.0 if plus.dot(want) >= minus.dot(want) else -1.0


## The signed angle a channel applies to a bone at weight 1 (for tests).
func angle_of(channel: StringName, bone: int) -> float:
	for mv: Array in _moves.get(channel, []):
		if int(mv[0]) == bone:
			return float(mv[1])
	return 0.0


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	for ch: StringName in _moves:
		var w := float(weights.get(ch, 0.0))
		if w <= 0.001:
			continue
		for mv: Array in _moves[ch]:
			var i := int(mv[0])
			sk.set_bone_pose_rotation(i, sk.get_bone_pose_rotation(i) * Quaternion(Vector3.RIGHT, float(mv[1]) * w))
