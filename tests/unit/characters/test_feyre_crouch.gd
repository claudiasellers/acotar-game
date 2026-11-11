## Contract for Feyre's crouch (CrouchMotor + the crouch clips in FeyreAnimator):
## a quick eased drop, a sneak that is slow and quiet, a lower camera, and clips on
## her own skeleton with planted feet.
extends GutTest


func test_crouch_toggles_only_on_the_ground() -> void:
	var c := CrouchMotor.new()
	assert_false(c.toggle(false), "no crouching in the air")
	assert_true(c.toggle(true))
	assert_false(c.toggle(true), "a second press stands her up")


func test_drop_is_quick_and_eased() -> void:
	var c := CrouchMotor.new()
	c.set_crouched(true)
	c.step(CrouchMotor.DROP_TIME * 0.25)
	var early := c.amount
	assert_lt(early, 0.25, "eases in (%.2f at a quarter of the drop)" % early)
	var t := CrouchMotor.DROP_TIME * 0.25
	while c.amount < 1.0 and t < 1.0:
		c.step(1.0 / 60.0)
		t += 1.0 / 60.0
	assert_lte(t, 0.3, "fully crouched in %.2f s" % t)
	c.set_crouched(false)
	for i in 30:
		c.step(1.0 / 60.0)
	assert_eq(c.amount, 0.0, "stands back up")


func test_sneak_is_slow_quiet_and_low() -> void:
	var c := CrouchMotor.new()
	c.set_crouched(true)
	c.step(1.0)
	assert_lte(c.limit_speed(10.686), 1.9, "top speed crouched")
	assert_eq(c.limit_speed(1.0), 1.0, "never speeds her up")
	assert_between(c.camera_drop(), 0.35, 0.4, "camera pivot sinks in proportion")
	assert_lte(c.noise_scale(), 0.4)
	assert_lt(c.sight_scale(), 0.6)
	var standing := CrouchMotor.new()
	assert_eq(standing.noise_scale(), 1.0)
	assert_eq(standing.limit_speed(10.686), 10.686)


func test_changed_signal_fires_once_per_stance_change() -> void:
	var c := CrouchMotor.new()
	watch_signals(c)
	c.set_crouched(true)
	c.set_crouched(true)
	c.set_crouched(false)
	assert_signal_emit_count(c, "changed", 2)


func test_crouch_action_is_ctrl_and_pad_b() -> void:
	CrouchMotor.ensure_action()
	assert_true(InputMap.has_action(CrouchMotor.ACTION))
	var key := false
	var pad := false
	for e in InputMap.action_get_events(CrouchMotor.ACTION):
		key = key or (e is InputEventKey and (e as InputEventKey).physical_keycode == KEY_CTRL)
		pad = pad or (e is InputEventJoypadButton and (e as InputEventJoypadButton).button_index == JOY_BUTTON_B)
	assert_true(key and pad)


func test_crouch_clips_are_on_her_skeleton_and_loop() -> void:
	var lib := FeyreAnimator.load_library()
	for clip in FeyreAnimator.CROUCH_CLIPS:
		assert_true(lib.has_animation(clip), String(clip))
		var anim := lib.get_animation(clip)
		assert_eq(anim.loop_mode, Animation.LOOP_LINEAR, String(clip))
		assert_gt(anim.find_track(^"Armature/Skeleton3D:Hips", Animation.TYPE_POSITION_3D), -1)
		assert_gt(anim.find_track(^"Armature/Skeleton3D:LeftUpperLeg", Animation.TYPE_ROTATION_3D), -1)
	# The crouch really is low: the hips sit well under their standing height.
	var stand := lib.get_animation(&"idle")
	var crouch := lib.get_animation(&"crouch_idle")
	var hs: Vector3 = stand.position_track_interpolate(stand.find_track(^"Armature/Skeleton3D:Hips", Animation.TYPE_POSITION_3D), 0.0)
	var hc: Vector3 = crouch.position_track_interpolate(crouch.find_track(^"Armature/Skeleton3D:Hips", Animation.TYPE_POSITION_3D), 0.0)
	assert_lt(hc.length(), hs.length() * 0.8, "crouched hips %.2f vs standing %.2f" % [hc.length(), hs.length()])


## The sneak plays its feet planted at her sneak speed without frantic cadence.
func test_feyre_sneaks_with_planted_feet() -> void:
	var feyre := (load("res://characters/feyre/feyre.tscn") as PackedScene).instantiate() as Feyre
	add_child_autofree(feyre)
	var a := feyre.model.find_child("FeyreAnimator", true, false) as FeyreAnimator
	assert_true(a.native_speeds.has(&"sneak"))
	var native: float = a.native_speeds[&"sneak"]
	assert_gt(native, 0.5, "sneak native speed %.2f m/s" % native)
	var b := a.crouch_blend(feyre.crouch.sneak_speed)
	assert_almost_eq(b.x, feyre.crouch.sneak_speed, 0.001)
	assert_almost_eq(b.y, feyre.crouch.sneak_speed / native, 0.001, "feet planted")
	assert_lte(b.y, FeyreAnimator.MAX_SCALE)
	assert_eq(a.crouch_blend(0.0), Vector2(0.0, 1.0))


# --- pose sampling helpers (CPU skinning of her clips) --------------------------

const RIG := "res://characters/feyre/anim/feyre_moves.glb"
const CLOAK := "res://characters/feyre/wardrobe/hunter_cloak.glb"


## Skeleton-space global poses of `skel`'s bones at time t of `anim`.
func _pose(skel: Skeleton3D, anim: Animation, t: float) -> Array:
	var local: Array = []
	for i in skel.get_bone_count():
		local.append(skel.get_bone_rest(i))
	for tr in anim.get_track_count():
		var bone := skel.find_bone(String(anim.track_get_path(tr)).get_slice(":", 1))
		if bone < 0:
			continue
		var xf: Transform3D = local[bone]
		if anim.track_get_type(tr) == Animation.TYPE_ROTATION_3D:
			xf.basis = Basis(anim.rotation_track_interpolate(tr, t))
		elif anim.track_get_type(tr) == Animation.TYPE_POSITION_3D:
			xf.origin = anim.position_track_interpolate(tr, t)
		local[bone] = xf
	var g: Array = []
	g.resize(skel.get_bone_count())
	for i in skel.get_bone_count():
		var p := skel.get_bone_parent(i)
		g[i] = (local[i] as Transform3D) if p < 0 else (g[p] as Transform3D) * (local[i] as Transform3D)
	return g


func _to_root(n: Node, root: Node) -> Transform3D:
	var xf := Transform3D.IDENTITY
	while n != null and n != root:
		if n is Node3D:
			xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf


## Lowest skinned cloak vertex (model space, her feet at y = 0) at time t.
func _cloak_low(rig: Skeleton3D, rig_xf: Transform3D, cloak: MeshInstance3D, cloak_xf: Transform3D,
		anim: Animation, t: float) -> float:
	var g := _pose(rig, anim, t)
	var skin := cloak.skin
	var binds: Array[Transform3D] = []
	for k in skin.get_bind_count():
		var bone := rig.find_bone(String(skin.get_bind_name(k)))
		if bone < 0 and skin.get_bind_bone(k) >= 0:
			bone = skin.get_bind_bone(k)
		binds.append(rig_xf * (g[bone] as Transform3D) * skin.get_bind_pose(k))
	var low := INF
	for s in cloak.mesh.get_surface_count():
		var arr := cloak.mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var bones = arr[Mesh.ARRAY_BONES]
		var weights = arr[Mesh.ARRAY_WEIGHTS]
		var per: int = bones.size() / verts.size()
		for v in verts.size():
			var p := Vector3.ZERO
			for j in per:
				var w: float = weights[v * per + j]
				if w > 0.0:
					p += (binds[int(bones[v * per + j])] * verts[v]) * w
			low = minf(low, p.y)
	return low


## The hunter's cloak never sinks through the floor while she crouches or sneaks.
func test_cloak_hem_stays_above_the_floor() -> void:
	var lib := FeyreAnimator.load_library()
	var rig_scene := (load(RIG) as PackedScene).instantiate()
	var rig := rig_scene.find_child("Skeleton3D", true, false) as Skeleton3D
	var cloak_scene := (load(CLOAK) as PackedScene).instantiate()
	var cloak: MeshInstance3D = null
	for mi in cloak_scene.find_children("*", "MeshInstance3D", true, false):
		if (mi as MeshInstance3D).skin != null:
			cloak = mi
	assert_not_null(cloak, "cloak mesh is skinned")
	var rest_low := INF
	for clip in [&"idle"] + FeyreAnimator.CROUCH_CLIPS:
		var anim := lib.get_animation(clip)
		var low := INF
		for f in 20:
			low = minf(low, _cloak_low(rig, _to_root(rig, rig_scene), cloak, Transform3D.IDENTITY, anim, anim.length * f / 20.0))
		if clip == &"idle":
			rest_low = low
			continue
		gut.p("%s: lowest cloak vertex %.3f m (standing %.3f)" % [clip, low, rest_low])
		assert_gte(low, -0.01, "%s cloak hem above the floor" % clip)
	rig_scene.free()
	cloak_scene.free()


## The sneak is a half-crouch, not a knee-shuffle: hips at least 0.6 of standing,
## knees clear of the floor, trunk lean at most 35 degrees, all cycle long.
func test_sneak_is_a_half_crouch() -> void:
	var lib := FeyreAnimator.load_library()
	var rig_scene := (load(RIG) as PackedScene).instantiate()
	var rig := rig_scene.find_child("Skeleton3D", true, false) as Skeleton3D
	var xf := _to_root(rig, rig_scene)
	var hips := rig.find_bone("Hips")
	var stand := (xf * rig.get_bone_global_rest(hips)).origin.y
	var anim := lib.get_animation(&"sneak")
	var low_hips := INF
	var low_knee := INF
	var lean := 0.0
	for f in 30:
		var g := _pose(rig, anim, anim.length * f / 30.0)
		var h := (xf * (g[hips] as Transform3D)).origin
		low_hips = minf(low_hips, h.y / stand)
		for b in ["LeftLowerLeg", "RightLowerLeg"]:
			low_knee = minf(low_knee, (xf * (g[rig.find_bone(b)] as Transform3D)).origin.y)
		var neck := (xf * (g[rig.find_bone("Neck")] as Transform3D)).origin
		lean = maxf(lean, rad_to_deg((neck - h).angle_to(Vector3.UP)))
	gut.p("sneak: hips >= %.2f of standing, knees >= %.3f m, lean <= %.1f deg" % [low_hips, low_knee, lean])
	assert_gte(low_hips, 0.6)
	assert_gte(low_knee, 0.12)
	assert_lte(lean, 35.0)
	rig_scene.free()


## Played at her sneak speed, a planted foot (ankle within 2 cm of its rest
## height) slips at most 3 cm from a treadmill moving at that speed.
func test_sneak_planted_foot_slips_under_3cm() -> void:
	var lib := FeyreAnimator.load_library()
	var rig_scene := (load(RIG) as PackedScene).instantiate()
	var rig := rig_scene.find_child("Skeleton3D", true, false) as Skeleton3D
	var xf := _to_root(rig, rig_scene)
	var anim := lib.get_animation(&"sneak")
	var native: float = anim.get_meta(&"native_speed")
	var rate := CrouchMotor.SNEAK_SPEED / native
	var dt := 1.0 / 30.0
	var n := int(round(anim.length / dt))
	var worst := 0.0
	for side in ["Left", "Right"]:
		var foot := rig.find_bone(side + "Foot")
		var rest_y := (xf * rig.get_bone_global_rest(foot)).origin.y
		var toes := (xf * rig.get_bone_global_rest(rig.find_bone(side + "Toes"))).origin
		var fwd := toes - (xf * rig.get_bone_global_rest(foot)).origin
		fwd.y = 0.0
		fwd = fwd.normalized()
		var start := -1.0
		var steps := 0
		for f in n * 2:
			var p := (xf * (_pose(rig, anim, fmod(f * dt, anim.length)) [foot] as Transform3D)).origin
			if p.y - rest_y < 0.02:
				var along := p.dot(fwd)
				if start < -0.5:
					start = along
					steps = 0
				# On the ground the world moves past at her speed: game time = clip time / rate.
				var slip := absf(along - (start - CrouchMotor.SNEAK_SPEED * steps * dt / rate))
				worst = maxf(worst, slip)
				steps += 1
			else:
				start = -1.0
	gut.p("sneak worst planted-foot slip %.3f m at %.2f m/s (x%.2f)" % [worst, CrouchMotor.SNEAK_SPEED, rate])
	assert_lte(worst, 0.03)
	rig_scene.free()
