## The white mare's reins (lane L47-8): a gold strap from each bit ring to
## Feyre's hand while she rides (RidePose reaches her hands to the same grip
## points, so the rein ends in her fist), or lying over the front of the saddle
## (the withers, bareback) when nobody holds them. Redrawn when the mare's
## skeleton updates, so the bit end rides her head through every stride.
class_name MareReins
extends MeshInstance3D

const RADIUS := 0.011
const SIDES := 6
const SEGMENTS := 10
## How far the strap sags at its middle: held (a light contact) and slack.
const SAG_HELD := 0.07
const SAG_SLACK := 0.16
## The holding hands are fresh for this many frames (Saddle.place sets them every frame).
const HELD_FRAMES := 2

## The strap's look (MareLook gives it the tack colour).
var strap: Material

var _horse: WhiteHorse
var _mi: MeshInstance3D
var _sk: Skeleton3D
var _muzzle: int = -1
var _bind: Transform3D = Transform3D.IDENTITY
var _im := ImmediateMesh.new()
var _sag: float = SAG_SLACK


func bind(horse: WhiteHorse, mi: MeshInstance3D, sk: Skeleton3D) -> void:
	_horse = horse
	_mi = mi
	_sk = sk
	top_level = true
	mesh = _im
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_to_group(CameraFade.NEVER_GROUP)
	_muzzle = sk.find_bone(&"muzzle")
	if mi.skin:
		for i in mi.skin.get_bind_count():
			if mi.skin.get_bind_name(i) == &"muzzle" or (mi.skin.get_bind_bone(i) == _muzzle and _muzzle >= 0):
				_bind = mi.skin.get_bind_pose(i)
				break
	for i in mi.mesh.get_surface_count():
		var m := mi.mesh.surface_get_material(i)
		if m and String(m.resource_name) == "Gold":
			strap = m
	sk.skeleton_updated.connect(redraw)


## Where the bit ring on her left (`left`) or right sits now (world).
func bit(left: bool) -> Vector3:
	var p: Vector3 = _horse.bits[0 if left else 1]
	if _sk == null or _muzzle < 0:
		return _horse.global_transform * p
	return _sk.global_transform * (_sk.get_bone_global_pose(_muzzle) * _bind) * p


func held() -> bool:
	return _horse != null and Engine.get_process_frames() - _horse.rein_held_frame <= HELD_FRAMES


func redraw() -> void:
	if _horse == null or not is_inside_tree() or not _horse.is_visible_in_tree():
		return
	global_transform = Transform3D.IDENTITY
	var holding := held()
	_sag = lerpf(_sag, SAG_HELD if holding else SAG_SLACK, 0.2)
	_im.clear_surfaces()
	_im.surface_begin(Mesh.PRIMITIVE_TRIANGLES, strap)
	for left: bool in [true, false]:
		var a := bit(left)
		var b: Vector3 = (_horse.rein_hands[0 if left else 1] if holding else _horse.rein_rest(left))
		_strap(a, b)
	_im.surface_end()


## One sagging strap from `a` to `b`, as a smooth tube.
func _strap(a: Vector3, b: Vector3) -> void:
	var pts: Array[Vector3] = []
	for k in SEGMENTS + 1:
		var t := float(k) / SEGMENTS
		pts.append(a.lerp(b, t) + Vector3.DOWN * _sag * 4.0 * t * (1.0 - t))
	var rings: Array = []
	for k in pts.size():
		var along := (pts[mini(k + 1, pts.size() - 1)] - pts[maxi(k - 1, 0)]).normalized()
		var side := along.cross(Vector3.UP)
		if side.length_squared() < 1e-6:
			side = along.cross(Vector3.RIGHT)
		side = side.normalized()
		var up := side.cross(along).normalized()
		var ring: Array[Vector3] = []
		for s in SIDES:
			var ang := TAU * s / SIDES
			ring.append(side * cos(ang) + up * sin(ang))
		rings.append(ring)
	for k in pts.size() - 1:
		var r0: Array[Vector3] = rings[k]
		var r1: Array[Vector3] = rings[k + 1]
		for s in SIDES:
			var s2 := (s + 1) % SIDES
			_vert(pts[k], r0[s])
			_vert(pts[k + 1], r1[s])
			_vert(pts[k + 1], r1[s2])
			_vert(pts[k], r0[s])
			_vert(pts[k + 1], r1[s2])
			_vert(pts[k], r0[s2])


func _vert(centre: Vector3, n: Vector3) -> void:
	_im.surface_set_normal(n)
	_im.surface_add_vertex(centre + n * RADIUS)
