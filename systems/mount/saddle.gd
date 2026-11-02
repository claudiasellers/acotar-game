## Puts a rider in the white horse's saddle (lane L47): hips on the seat, the
## RidePose on her skeleton (legs on the barrel, feet in the stirrups, hands
## on the reins), facing the way the horse faces. Shared by the mount
## (MountDirector) and the ch5 ride north (story/act1/ride_north.gd), so both
## look the same. Call seat() once, place() every frame, unseat() at the end.
class_name Saddle
extends RefCounted

const HIP_DROP := &"saddle_hip_drop"


static func skeleton_of(rider: Node3D) -> Skeleton3D:
	var model := rider.get(&"model") as Node3D if rider else null
	if model == null:
		return null
	var found := model.find_children("*", "Skeleton3D", true, false)
	return null if found.is_empty() else found.front() as Skeleton3D


static func seat(rider: Node3D) -> RidePose:
	var sk := skeleton_of(rider)
	if sk == null:
		return null
	var pose := RidePose.attach(sk)
	pose.amount = 1.0
	var hips := sk.find_bone(&"Hips")
	var drop := 0.9
	if hips >= 0:
		drop = (sk.global_transform * sk.get_bone_global_rest(hips).origin).y - rider.global_position.y
	rider.set_meta(HIP_DROP, drop)
	return pose


static func place(rider: Node3D, horse: WhiteHorse) -> void:
	if rider == null or horse == null:
		return
	rider.global_position = horse.seat_point() - Vector3.UP * float(rider.get_meta(HIP_DROP, 0.9))
	var model := rider.get(&"model") as Node3D
	if model:
		model.rotation = Vector3(0.0, horse.global_rotation.y, 0.0)


static func unseat(rider: Node3D) -> void:
	var sk := skeleton_of(rider)
	var pose := sk.get_node_or_null(^"RidePose") as RidePose if sk else null
	if pose:
		pose.amount = 0.0
		pose.lean = 0.0
	if rider and rider.has_meta(HIP_DROP):
		rider.remove_meta(HIP_DROP)
