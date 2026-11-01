## Bends a humanoid forward at the spine, chest, neck and head on top of
## whatever clip is playing (lane L22): a retch, a flinch, a bow. `amount` 0..1;
## the scene animates it. Sits on the Skeleton3D, after the AnimationPlayer.
class_name HunchModifier
extends SkeletonModifier3D

## Forward bend per bone at amount 1, in degrees (positive bends toward the
## model's face on the Feyre rig shared by the cast).
const BEND := {&"Spine": 18.0, &"Chest": 16.0, &"UpperChest": 10.0, &"Neck": 14.0, &"Head": 12.0}

var amount: float = 0.0
var _bones: Dictionary = {}  # bone index -> radians


static func attach(sk: Skeleton3D) -> HunchModifier:
	var h := HunchModifier.new()
	h.name = "Hunch"
	sk.add_child(h)
	for bone: StringName in BEND:
		var i := sk.find_bone(bone)
		if i >= 0:
			h._bones[i] = deg_to_rad(float(BEND[bone]))
	return h


func _process_modification() -> void:
	if amount <= 0.001:
		return
	var sk := get_skeleton()
	if sk == null:
		return
	for i: int in _bones:
		var q := sk.get_bone_pose_rotation(i)
		sk.set_bone_pose_rotation(i, q * Quaternion(Vector3.RIGHT, float(_bones[i]) * amount))
