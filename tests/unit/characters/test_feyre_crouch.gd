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
	assert_gte(c.camera_drop(), 0.5, "camera pivot sinks")
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
