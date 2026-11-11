## Builds Feyre's crouch clips (crouch_idle, sneak) by retargeting CC0 Mesh2Motion
## motion capture onto her rig, with the same method as her main move set
## (tools/blender/feyre_moves/retarget_moves.py): each mapped bone takes the source
## bone's world-space rotation delta from its rest, P_t = P_s * R_s^-1 * R_t, so her
## own rest shape is kept; the hips take the source pelvis offset scaled by the
## hip-joint height ratio, with horizontal drift removed (clips play in place); every
## frame the feet are grounded (her lowest foot or toe joint sits at its rest height)
## and her knees are kept off the floor. Jaw, eyes, braid and Root stay at rest.
##
##   godot --headless --path . -s tools/generators/feyre_crouch_retarget.gd -- SOURCE_DIR
## SOURCE_DIR holds human-base-animations.glb and human-addon-animations.glb from Mesh2Motion
## (github.com/scottpetrovic/mesh2motion-app, commit
## eef2de986dab53283cb636f860d502d64b8073e7, static/animations/, CC0 1.0).
## Writes characters/feyre/anim/feyre_crouch.res (an AnimationLibrary) and prints
## each clip's length, native ground speed and worst stance-foot slide.
## Deterministic: same source, same output.
extends SceneTree

const TARGET_SCENE := "res://characters/feyre/anim/feyre_moves.glb"
const OUT := "res://characters/feyre/anim/feyre_crouch.res"
const FPS := 30.0
## Knee joints are kept at least this high (m): the kneecap's radius.
const KNEE_FLOOR := 0.07
const SIDES := [["l", "Left"], ["r", "Right"]]

## name, source file, source action, start s, end s (0 = clip end), output frames, loop
const CLIPS := [
	["crouch_idle", "human-base-animations.glb", "Crouch_Idle", 0.0, 0.0, 0, true],
	["sneak", "human-base-animations.glb", "Crouch_Walk", 0.0, 0.0, 0, true],
]

## Degrees: target mean trunk lean from vertical, and how far the head lifts.
## stride: stride warp factor (longer steps at the same cadence, legs re-solved
## with IK); rate: plays the source this much faster (a brisker cadence). Together
## they lift the performer's slow 0.39 m/s creep to a sneak that keeps up with play.
const POSTURE := {
	"crouch_idle": {"lean": 30.0, "head": 28.0},
	"sneak": {"lean": 30.0, "head": 24.0, "stride": 1.5, "rate": 1.6},
}

var _src_rest_world: Dictionary = {}
var _tgt_rest_world: Dictionary = {}


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("usage: -- SOURCE_DIR")
		quit(2)
		return
	var src := _load_gltf(args[0].path_join("human-base-animations.glb"))
	var sources := {}
	var tgt_scene := (load(TARGET_SCENE) as PackedScene).instantiate()
	var tgt_skel := tgt_scene.find_child("Skeleton3D", true, false) as Skeleton3D
	var src_skel := _find_skeleton(src)
	var src_player := _find_player(src)
	var prefix := String(tgt_scene.get_path_to(tgt_skel)) + ":"
	var src_xf := _node_to_root(src_skel, src)
	var tgt_xf := _node_to_root(tgt_skel, tgt_scene)
	_src_rest_world = _rest_world(src_skel, src_xf)
	_tgt_rest_world = _rest_world(tgt_skel, tgt_xf)
	var bones := _bone_map()
	var k := _hip_ratio(src_skel, tgt_skel)
	print("hip ratio K = %.4f" % k)

	var lib := AnimationLibrary.new()
	for spec: Array in CLIPS:
		if not sources.has(spec[1]):
			sources[spec[1]] = _load_gltf(args[0].path_join(spec[1]))
		var source_lib := _find_player(sources[spec[1]]).get_animation_library(&"")
		var anim_src: Animation = source_lib.get_animation(StringName(spec[2]))
		var t0: float = spec[3]
		var t1: float = spec[4] if float(spec[4]) > 0.0 else anim_src.length
		var posture: Dictionary = POSTURE.get(spec[0], {})
		var rate := float(posture.get("rate", 1.0))
		var n: int = spec[5] if int(spec[5]) > 0 else maxi(int(round((t1 - t0) * FPS / rate)), 2)
		var frames := _retarget(anim_src, src_skel, src_xf, tgt_skel, tgt_xf, bones, k, t0, t1, n,
				posture)
		if posture.has("stride"):
			var clamps := _stride_warp(tgt_skel, tgt_xf, frames, float(posture["stride"]))
			print("  stride warp x%.2f, %d clamped legs" % [posture["stride"], clamps])
		if posture.has("stride"):
			var speed := _gait_stats(frames, tgt_skel, tgt_xf).x
			var locked := _lock_feet(tgt_skel, tgt_xf, frames, speed)
			print("  stance lock at %.3f m/s: %d frames" % [speed, locked])
		var anim := _key(frames, tgt_skel, tgt_xf, prefix, n, spec[6])
		var stats := _gait_stats(frames, tgt_skel, tgt_xf)
		anim.set_meta(&"native_speed", stats.x)
		lib.add_animation(StringName(spec[0]), anim)
		print("%s <- %s %.3f-%.3f s: %d frames, %.3f s, native speed %.3f m/s, worst slide %.3f m" % [
				spec[0], spec[2], t0, t1, n, anim.length, stats.x, stats.y])
	var err := ResourceSaver.save(lib, OUT, ResourceSaver.FLAG_COMPRESS)
	print("saved %s (%s)" % [OUT, error_string(err)])
	tgt_scene.free()
	src.free()
	for node: Node in sources.values():
		node.free()
	quit(0 if err == OK else 1)


func _load_gltf(path: String) -> Node:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_file(path, state)
	assert(err == OK, "cannot read %s" % path)
	return doc.generate_scene(state, 30.0)


func _find_skeleton(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n
	for c in n.get_children():
		var s := _find_skeleton(c)
		if s:
			return s
	return null


func _find_player(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var p := _find_player(c)
		if p:
			return p
	return null


## The node's transform relative to the scene root (the scenes are not in a tree).
func _node_to_root(n: Node3D, root: Node) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur: Node = n
	while cur != null and cur != root:
		if cur is Node3D:
			xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	if root is Node3D:
		xf = (root as Node3D).transform * xf
	return xf


func _rest_world(skel: Skeleton3D, xf: Transform3D) -> Dictionary:
	var out := {}
	for i in skel.get_bone_count():
		out[skel.get_bone_name(i)] = xf * skel.get_bone_global_rest(i)
	return out


## Target bone -> source bone (the inverse of retarget_moves.py's bone_map).
func _bone_map() -> Dictionary:
	var m := {"Hips": "pelvis", "Spine": "spine_01", "Chest": "spine_02", "UpperChest": "spine_03",
			"Neck": "neck_01", "Head": "head"}
	for pair: Array in SIDES:
		var s: String = pair[0]
		var side: String = pair[1]
		for ab: Array in [["clavicle", "Shoulder"], ["upperarm", "UpperArm"], ["lowerarm", "LowerArm"],
				["hand", "Hand"], ["thigh", "UpperLeg"], ["calf", "LowerLeg"], ["foot", "Foot"], ["ball", "Toes"]]:
			m[side + ab[1]] = "%s_%s" % [ab[0], s]
		var segs := ["Metacarpal", "Proximal", "Distal"]
		for i in 3:
			m[side + "Thumb" + segs[i]] = "thumb_%02d_%s" % [i + 1, s]
		for ab: Array in [["index", "Index"], ["middle", "Middle"], ["ring", "Ring"], ["pinky", "Little"]]:
			var fsegs := ["Proximal", "Intermediate", "Distal"]
			for i in 3:
				m[side + ab[1] + fsegs[i]] = "%s_%02d_%s" % [ab[0], i + 1, s]
	return m


func _hip_ratio(src: Skeleton3D, tgt: Skeleton3D) -> float:
	var hs: float = (_src_rest_world["thigh_l"] as Transform3D).origin.y
	var ht: float = (_tgt_rest_world["LeftUpperLeg"] as Transform3D).origin.y
	return ht / hs


## Local poses of the source skeleton at time t (rest where a bone has no track).
func _sample_source(anim: Animation, skel: Skeleton3D, t: float) -> Array:
	var locals: Array = []
	for i in skel.get_bone_count():
		locals.append(skel.get_bone_rest(i))
	for tr in anim.get_track_count():
		var path := String(anim.track_get_path(tr))
		var bone := skel.find_bone(path.get_slice(":", 1))
		if bone < 0:
			continue
		var xf: Transform3D = locals[bone]
		match anim.track_get_type(tr):
			Animation.TYPE_ROTATION_3D:
				xf.basis = Basis(anim.rotation_track_interpolate(tr, t)).scaled(xf.basis.get_scale())
			Animation.TYPE_POSITION_3D:
				xf.origin = anim.position_track_interpolate(tr, t)
		locals[bone] = xf
	return locals


func _globals(skel: Skeleton3D, xf: Transform3D, locals: Array) -> Array:
	var g: Array = []
	g.resize(skel.get_bone_count())
	for i in skel.get_bone_count():
		var p := skel.get_bone_parent(i)
		g[i] = (xf if p < 0 else g[p] as Transform3D) * (locals[i] as Transform3D)
	return g


## One entry per output frame: target local transforms (rotation + position).
func _retarget(anim: Animation, src: Skeleton3D, src_xf: Transform3D, tgt: Skeleton3D,
		tgt_xf: Transform3D, bones: Dictionary, k: float, t0: float, t1: float, n: int,
		posture: Dictionary) -> Array:
	var rots: Array = []
	var hip_offsets: Array[Vector3] = []
	for f in n:
		var t := t0 + (t1 - t0) * float(f) / float(n)
		var sg := _globals(src, src_xf, _sample_source(anim, src, t))
		var world_rot: Array = []
		world_rot.resize(tgt.get_bone_count())
		for i in tgt.get_bone_count():
			var name := tgt.get_bone_name(i)
			var p := tgt.get_bone_parent(i)
			var parent_rot: Quaternion = tgt_xf.basis.get_rotation_quaternion() if p < 0 else world_rot[p]
			var rot: Quaternion
			if bones.has(name) and src.find_bone(bones[name]) >= 0:
				var sb := src.find_bone(bones[name])
				var ps := (sg[sb] as Transform3D).basis.get_rotation_quaternion()
				var rs := (_src_rest_world[bones[name]] as Transform3D).basis.get_rotation_quaternion()
				var rt := (_tgt_rest_world[name] as Transform3D).basis.get_rotation_quaternion()
				rot = (ps * rs.inverse() * rt).normalized()
			else:
				rot = (parent_rot * tgt.get_bone_rest(i).basis.get_rotation_quaternion()).normalized()
			world_rot[i] = rot
		var pelvis := src.find_bone("pelvis")
		hip_offsets.append(((sg[pelvis] as Transform3D).origin
				- (_src_rest_world["pelvis"] as Transform3D).origin) * k)
		rots.append(world_rot)
	_posture(tgt, tgt_xf, rots, posture)
	var frames: Array = []
	for world_rot: Array in rots:
		frames.append(_locals(tgt, tgt_xf, world_rot))
	# In place: remove the linear horizontal drift between the first and last frame.
	var drift := hip_offsets[n - 1] - hip_offsets[0]
	drift.y = 0.0
	var hips := tgt.find_bone("Hips")
	var hips_parent := tgt.get_bone_parent(hips)
	for f in n:
		var off := hip_offsets[f] - drift * float(f) / float(maxi(n - 1, 1))
		var parent_world: Transform3D = tgt_xf if hips_parent < 0 else _globals(tgt, tgt_xf, frames[f])[hips_parent]
		var hips_world := (_tgt_rest_world["Hips"] as Transform3D).origin + off
		var local: Array = frames[f]
		var hx: Transform3D = local[hips]
		hx.origin = parent_world.affine_inverse() * hips_world
		local[hips] = hx
		_ground(tgt, tgt_xf, local, hips, hips_parent)
	return frames


func _locals(tgt: Skeleton3D, tgt_xf: Transform3D, world_rot: Array) -> Array:
	var local: Array = []
	local.resize(tgt.get_bone_count())
	for i in tgt.get_bone_count():
		var p := tgt.get_bone_parent(i)
		var parent_rot: Quaternion = tgt_xf.basis.get_rotation_quaternion() if p < 0 else world_rot[p]
		local[i] = Transform3D(Basis(parent_rot.inverse() * (world_rot[i] as Quaternion)),
				tgt.get_bone_rest(i).origin)
	return local


## Posture pass: the performer crouches hunched with her face to the floor; Feyre
## is a huntress watching her quarry. The clip's mean trunk lean (hips to neck,
## from vertical) is rotated to `lean` degrees, spread over Spine, Chest and
## UpperChest (frame-to-frame motion kept, arms ride with the chest), then the head
## and neck lift `head` degrees so her eyes come up off the ground.
func _posture(tgt: Skeleton3D, tgt_xf: Transform3D, rots: Array, posture: Dictionary) -> void:
	if posture.is_empty():
		return
	var hips := tgt.find_bone("Hips")
	var neck := tgt.find_bone("Neck")
	var trunk := Vector3.ZERO
	for world_rot: Array in rots:
		var g := _globals(tgt, tgt_xf, _locals(tgt, tgt_xf, world_rot))
		trunk += ((g[neck] as Transform3D).origin - (g[hips] as Transform3D).origin).normalized()
	trunk = trunk.normalized()
	var lean := rad_to_deg(trunk.angle_to(Vector3.UP))
	var axis := trunk.cross(Vector3.UP).normalized()
	var fix := deg_to_rad(lean - float(posture.get("lean", lean)))
	var head := deg_to_rad(float(posture.get("head", 0.0)))
	print("  posture: mean lean %.1f deg -> %.1f, head +%.1f" % [lean, lean - rad_to_deg(fix), rad_to_deg(head)])
	var share := {"Spine": 0.4, "Chest": 0.75, "UpperChest": 1.0}
	var neck_share := {"Neck": 0.4, "Head": 1.0}
	for world_rot: Array in rots:
		for i in tgt.get_bone_count():
			var angle := 0.0
			var b := i
			# The deepest spine/neck ancestor (or self) decides the share.
			while b >= 0:
				var bn := tgt.get_bone_name(b)
				if share.has(bn) or neck_share.has(bn):
					break
				b = tgt.get_bone_parent(b)
			if b < 0:
				continue
			var bname := tgt.get_bone_name(b)
			if neck_share.has(bname):
				angle = fix + head * float(neck_share[bname])
			else:
				angle = fix * float(share[bname])
			world_rot[i] = (Quaternion(axis, angle) * (world_rot[i] as Quaternion)).normalized()


## Shifts the hips vertically so her lowest foot or toe joint sits at its rest
## height (feet on the floor, no floating or sinking) and neither knee goes under
## the floor.
func _ground(tgt: Skeleton3D, tgt_xf: Transform3D, local: Array, hips: int, hips_parent: int) -> void:
	var g := _globals(tgt, tgt_xf, local)
	var lift := INF
	for b in ["LeftFoot", "RightFoot", "LeftToes", "RightToes"]:
		var i := tgt.find_bone(b)
		var sink := (g[i] as Transform3D).origin.y - (_tgt_rest_world[b] as Transform3D).origin.y
		lift = minf(lift, sink)
	var shift := -lift
	for b in ["LeftLowerLeg", "RightLowerLeg"]:
		var y := (g[tgt.find_bone(b)] as Transform3D).origin.y + shift
		if y < KNEE_FLOOR:
			shift += KNEE_FLOOR - y
	var parent_world: Transform3D = tgt_xf if hips_parent < 0 else g[hips_parent]
	var hx: Transform3D = local[hips]
	var world := parent_world * hx.origin + Vector3.UP * shift
	hx.origin = parent_world.affine_inverse() * world
	local[hips] = hx


## Her facing in the scene (horizontal, from heel to toes at rest).
func _forward() -> Vector3:
	var d := (_tgt_rest_world["LeftToes"] as Transform3D).origin - (_tgt_rest_world["LeftFoot"] as Transform3D).origin
	d.y = 0.0
	return d.normalized()


## Longer stride at the same cadence (port of retarget_moves.py stride_warp): each
## ankle's fore-aft distance from its clip mean, relative to the hips, is scaled by k
## and the leg re-solved with two-bone IK (foot orientation kept), then the frame is
## re-grounded. Returns how many leg solves had to clamp at full reach.
func _stride_warp(tgt: Skeleton3D, tgt_xf: Transform3D, frames: Array, k: float) -> int:
	var fwd := _forward()
	var hips := tgt.find_bone("Hips")
	var clamps := 0
	for side in ["Left", "Right"]:
		var foot := tgt.find_bone(side + "Foot")
		var rel: Array[float] = []
		var mean := 0.0
		for local: Array in frames:
			var g := _globals(tgt, tgt_xf, local)
			var d := ((g[foot] as Transform3D).origin - (g[hips] as Transform3D).origin).dot(fwd)
			rel.append(d)
			mean += d
		mean /= float(frames.size())
		for f in frames.size():
			if not _solve_leg(tgt, tgt_xf, frames[f], side, fwd * (k - 1.0) * (rel[f] - mean)):
				clamps += 1
	for local: Array in frames:
		_ground(tgt, tgt_xf, local, hips, tgt.get_bone_parent(hips))
	return clamps


## Contact: a foot whose ankle is within this of its rest height (heel down; a
## foot rolling up onto its toes is lifting off and is left free).
const CONTACT := 0.02
const LOCK_EASE := 3


## Height of a side's ankle above its rest height.
func _foot_sink(tgt: Skeleton3D, g: Array, side: String) -> float:
	var b := side + "Foot"
	return (g[tgt.find_bone(b)] as Transform3D).origin.y - (_tgt_rest_world[b] as Transform3D).origin.y


## Stance-foot lock (as in retarget_moves.py): while a foot is on the ground its
## ankle is pinned to a treadmill moving back at `speed` from where it touched down,
## eased out over the last LOCK_EASE frames before lift-off, so with speed_scale = game speed / native speed the planted
## foot does not skate. Returns the number of locked frames.
func _lock_feet(tgt: Skeleton3D, tgt_xf: Transform3D, frames: Array, speed: float) -> int:
	var fwd := _forward()
	var count := 0
	for w: Array in _stances(tgt, tgt_xf, frames):
		var pts: Array = w[1]
		var idx: Array = w[2]
		# The treadmill starts where the foot touches down (no jump at contact).
		var c: float = pts[0]
		for j in pts.size():
			var ease := minf(1.0, float(pts.size() - j) / float(LOCK_EASE))
			var target := c - speed * float(j) / FPS
			_solve_leg(tgt, tgt_xf, frames[idx[j]], w[0], fwd * (target - (pts[j] as float)) * ease)
			count += 1
	var hips := tgt.find_bone("Hips")
	for local: Array in frames:
		_ground(tgt, tgt_xf, local, hips, tgt.get_bone_parent(hips))
	return count


## Moves the ankle by `offset`: two-bone IK, the knee stays in its plane, the foot
## keeps its world orientation. False if the leg had to clamp at full reach.
func _solve_leg(tgt: Skeleton3D, tgt_xf: Transform3D, local: Array, side: String, offset: Vector3) -> bool:
	var up := tgt.find_bone(side + "UpperLeg")
	var lo := tgt.find_bone(side + "LowerLeg")
	var ft := tgt.find_bone(side + "Foot")
	var g := _globals(tgt, tgt_xf, local)
	var hip := (g[up] as Transform3D).origin
	var knee := (g[lo] as Transform3D).origin
	var ankle := (g[ft] as Transform3D).origin
	var l1 := knee.distance_to(hip)
	var l2 := ankle.distance_to(knee)
	var d_vec := ankle + offset - hip
	var ok := d_vec.length() <= 0.9995 * (l1 + l2)
	var d := clampf(d_vec.length(), absf(l1 - l2) + 1e-4, 0.9995 * (l1 + l2))
	var dirn := d_vec.normalized()
	var goal := hip + dirn * d
	var pole := (knee - hip) - dirn * (knee - hip).dot(dirn)
	pole = pole.normalized() if pole.length() > 1e-6 else _forward()
	var a := (l1 * l1 - l2 * l2 + d * d) / (2.0 * d)
	var knee_new := hip + dirn * a + pole * sqrt(maxf(l1 * l1 - a * a, 0.0))
	var r1 := Quaternion((knee - hip).normalized(), (knee_new - hip).normalized())
	var w_up := r1 * (g[up] as Transform3D).basis.get_rotation_quaternion()
	var r2 := Quaternion((r1 * (ankle - knee)).normalized(), (goal - knee_new).normalized())
	var w_lo := r2 * r1 * (g[lo] as Transform3D).basis.get_rotation_quaternion()
	var w_ft := (g[ft] as Transform3D).basis.get_rotation_quaternion()
	var parent_rot := (g[tgt.get_bone_parent(up)] as Transform3D).basis.get_rotation_quaternion()
	_set_rot(local, up, (parent_rot.inverse() * w_up).normalized())
	_set_rot(local, lo, (w_up.inverse() * w_lo).normalized())
	_set_rot(local, ft, (w_lo.inverse() * w_ft).normalized())
	return ok


func _set_rot(local: Array, bone: int, q: Quaternion) -> void:
	var xf: Transform3D = local[bone]
	xf.basis = Basis(q)
	local[bone] = xf


func _key(frames: Array, tgt: Skeleton3D, tgt_xf: Transform3D, prefix: String, n: int,
		loop: bool) -> Animation:
	var anim := Animation.new()
	anim.length = float(n) / FPS
	anim.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	var hips := tgt.find_bone("Hips")
	var pos_track := anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(pos_track, NodePath(prefix + "Hips"))
	for i in tgt.get_bone_count():
		var tr := anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(tr, NodePath(prefix + tgt.get_bone_name(i)))
		var count := n + (1 if loop else 0)
		for f in count:
			var local: Transform3D = frames[f % n][i]
			anim.rotation_track_insert_key(tr, float(f) / FPS, local.basis.get_rotation_quaternion())
			if i == hips:
				anim.position_track_insert_key(pos_track, float(f) / FPS, local.origin)
	return anim


## (native ground speed, worst stance slide). Per foot, each contact window (ankle
## within CONTACT of rest) is a stance; the native speed is the mean
## backward speed of the planted ankles, and the slide is the largest distance a
## planted ankle strays from a treadmill moving at that speed from its touch-down.
func _gait_stats(frames: Array, tgt: Skeleton3D, tgt_xf: Transform3D) -> Vector2:
	var wins := _stances(tgt, tgt_xf, frames)
	var fwd := _forward()
	var dist := 0.0
	var time := 0.0
	for w: Array in wins:
		var pts: Array = w[1]
		if pts.size() < 2:
			continue
		dist += (pts[0] as float) - (pts[pts.size() - 1] as float)
		time += float(pts.size() - 1) / FPS
	if time <= 0.0 or dist / time < 0.05:
		return Vector2.ZERO
	var speed := dist / time
	var worst := 0.0
	for w: Array in wins:
		var pts: Array = w[1]
		# The treadmill starts where the foot touches down (no jump at contact).
		var c: float = pts[0]
		for j in pts.size():
			worst = maxf(worst, absf((pts[j] as float) - (c - speed * float(j) / FPS)))
	return Vector2(speed, worst)


## Contact windows on the loop: [[side, [ankle position along her facing, ...],
## [frame indices]], ...].
func _stances(tgt: Skeleton3D, tgt_xf: Transform3D, frames: Array) -> Array:
	var fwd := _forward()
	var n := frames.size()
	var out: Array = []
	var gs: Array = []
	for local: Array in frames:
		gs.append(_globals(tgt, tgt_xf, local))
	for side in ["Left", "Right"]:
		var foot := tgt.find_bone(side + "Foot")
		var on: Array[bool] = []
		for g: Array in gs:
			on.append(_foot_sink(tgt, g, side) < CONTACT)
		var start := on.find(false)
		if start < 0:
			continue
		var f := 0
		while f < n:
			if not on[(start + f) % n]:
				f += 1
				continue
			var idx: Array[int] = []
			var pts: Array[float] = []
			while f < n and on[(start + f) % n]:
				var i := (start + f) % n
				idx.append(i)
				pts.append(((gs[i] as Array)[foot] as Transform3D).origin.dot(fwd))
				f += 1
			out.append([side, pts, idx])
	return out
