## Measures how fast a gait clip walks: the ground speed (m/s) at which its
## planted feet stand still. Read from the clip itself, so no clip needs a
## hand-kept "authored speed" beside it (docs/contracts/creature_motion.md).
##
## It follows each foot bone through the clip (its own tracks and its parents',
## rest pose where a bone has no track), takes the stretch where the foot is at
## its lowest as the stance, and returns the median speed the foot moves back
## under the body there. In-place clips only.
class_name GaitMeter
extends RefCounted

const SAMPLES := 64
## A foot is down while it is within this of its lowest point (m).
const DOWN_BAND := 0.008

## Animation -> native speed; clips are shared by every instance of a model.
static var _cache: Dictionary = {}


## Native ground speed of `clip` for the feet `foot_bones`, or 0 when the feet
## never plant or never move (an idle, a pose).
static func native_speed(clip: Animation, skeleton: Skeleton3D, foot_bones: Array[StringName]) -> float:
	if clip == null or skeleton == null:
		return 0.0
	if _cache.has(clip):
		return _cache[clip]
	var speeds: Array[float] = []
	for foot in foot_bones:
		var bone := skeleton.find_bone(foot)
		if bone >= 0:
			speeds.append_array(_stance_speeds(clip, skeleton, bone))
	# The median: the samples at either end of a stance, where the foot is still
	# landing or already rolling off, don't pull it.
	speeds.sort()
	var native := 0.0 if speeds.is_empty() else speeds[speeds.size() / 2]
	_cache[clip] = native
	return native


## The foot's speed over the ground of its own body at every sample where it is down.
static func _stance_speeds(clip: Animation, skeleton: Skeleton3D, bone: int) -> Array[float]:
	# The chain from the root down to the foot, and each bone's tracks.
	var chain: Array[int] = []
	var b := bone
	while b >= 0:
		chain.push_front(b)
		b = skeleton.get_bone_parent(b)
	var tracks: Array = []
	for link in chain:
		tracks.append(_tracks_of(clip, skeleton.get_bone_name(link)))
	var points: Array[Vector3] = []
	var low := INF
	for i in SAMPLES + 1:
		var t := clip.length * float(i) / float(SAMPLES)
		var xf := Transform3D.IDENTITY
		for k in chain.size():
			var rest := skeleton.get_bone_rest(chain[k])
			var found: Dictionary = tracks[k]
			var pos: Vector3 = clip.position_track_interpolate(found.pos, t) if found.pos >= 0 else rest.origin
			var rot: Quaternion = clip.rotation_track_interpolate(found.rot, t) if found.rot >= 0 else rest.basis.get_rotation_quaternion()
			var size: Vector3 = clip.scale_track_interpolate(found.size, t) if found.size >= 0 else rest.basis.get_scale()
			xf = xf * Transform3D(Basis(rot).scaled_local(size), pos)
		points.append(xf.origin)
		low = minf(low, xf.origin.y)
	var out: Array[float] = []
	var dt := clip.length / float(SAMPLES)
	for i in range(1, points.size()):
		if points[i].y < low + DOWN_BAND and points[i - 1].y < low + DOWN_BAND:
			out.append(Vector2(points[i].x - points[i - 1].x, points[i].z - points[i - 1].z).length() / dt)
	return out


static func _tracks_of(clip: Animation, bone_name: String) -> Dictionary:
	var found := {pos = -1, rot = -1, size = -1}
	for t in clip.get_track_count():
		var path := clip.track_get_path(t)
		if path.get_subname_count() == 0 or path.get_subname(path.get_subname_count() - 1) != bone_name:
			continue
		match clip.track_get_type(t):
			Animation.TYPE_POSITION_3D:
				found.pos = t
			Animation.TYPE_ROTATION_3D:
				found.rot = t
			Animation.TYPE_SCALE_3D:
				found.size = t
	return found
