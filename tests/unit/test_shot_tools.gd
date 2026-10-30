extends GutTest
## Layout shot mode, shot requests and numeric checks (tools/shots/).


func test_layout_mode_turns_off_every_expensive_effect() -> void:
	var root := Node3D.new()
	add_child_autofree(root)
	var env := Environment.new()
	env.glow_enabled = true
	env.ssao_enabled = true
	env.ssil_enabled = true
	env.ssr_enabled = true
	env.sdfgi_enabled = true
	env.fog_enabled = true
	env.volumetric_fog_enabled = true
	env.sky = Sky.new()
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	root.add_child(sun)
	var lamp := OmniLight3D.new()
	lamp.shadow_enabled = true
	root.add_child(lamp)
	var sparks := GPUParticles3D.new()
	root.add_child(sparks)
	var probe := ReflectionProbe.new()
	root.add_child(probe)
	var vp := SubViewport.new()
	vp.msaa_3d = Viewport.MSAA_4X
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	vp.use_taa = true
	add_child_autofree(vp)
	ShotQuality.apply(ShotQuality.LAYOUT, vp, root, Vector2i(640, 360))
	assert_eq(vp.size, Vector2i(640, 360))
	assert_eq(vp.msaa_3d, Viewport.MSAA_DISABLED)
	assert_eq(vp.screen_space_aa, Viewport.SCREEN_SPACE_AA_DISABLED)
	assert_false(vp.use_taa)
	for prop in ["glow_enabled", "ssao_enabled", "ssil_enabled", "ssr_enabled", "sdfgi_enabled", "fog_enabled", "volumetric_fog_enabled"]:
		assert_false(env.get(prop), prop)
	assert_eq(env.sky.radiance_size, Sky.RADIANCE_SIZE_32)
	assert_false(sun.shadow_enabled, "sun shadows")
	assert_false(lamp.shadow_enabled, "omni shadows")
	assert_false(sparks.visible, "particles")
	assert_false(probe.visible, "reflection probe")


func test_full_mode_leaves_the_look_alone() -> void:
	var root := Node3D.new()
	add_child_autofree(root)
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	root.add_child(sun)
	var vp := SubViewport.new()
	vp.msaa_3d = Viewport.MSAA_2X
	add_child_autofree(vp)
	ShotQuality.apply(ShotQuality.FULL, vp, root, Vector2i(1920, 1080))
	assert_eq(vp.size, Vector2i(1920, 1080))
	assert_eq(vp.msaa_3d, Viewport.MSAA_2X)
	assert_true(sun.shadow_enabled)


func test_request_fills_defaults_per_quality() -> void:
	var req := ShotRequest.new()
	req.read({"id": "t", "shots": [
		{"name": "a", "eye": [1, 2, 3], "at": [4, 5, 6]},
		{"name": "b", "eye": [0, 0, 0], "at": [1, 0, 0], "quality": "full"},
	]})
	assert_eq(req.errors.size(), 0, ", ".join(req.errors))
	assert_eq(req.shots[0].size, Vector2i(640, 360))
	assert_eq(req.shots[0].settle_draws, 1)
	assert_true(req.shots[0].ground, "world shots sit on the terrain by default")
	assert_eq(req.shots[1].size, Vector2i(1920, 1080))
	assert_eq(req.shots[1].settle_draws, 30)


func test_request_rejects_bad_shots() -> void:
	var req := ShotRequest.new()
	req.read({"quality": "pretty", "shots": [{"name": "x"}, {"name": "a/b", "eye": [0, 0, 0], "at": [1, 0, 0]}],
		"checks": [{"name": "no_kind"}]})
	assert_eq(req.errors.size(), 4, ", ".join(req.errors))


func test_checks_report_positions_bounds_and_overlaps() -> void:
	var root := Node3D.new()
	add_child_autofree(root)
	var a := _box("StairTop", Vector3(0, 3, 0), Vector3(2, 1, 2))
	var b := _box("Landing", Vector3(0, 3.8, 0), Vector3(2, 1, 2))
	var c := _box("Far", Vector3(10, 0, 0), Vector3(1, 1, 1))
	for n in [a, b, c]:
		root.add_child(n)
	c.add_to_group(&"probe_test")
	var pos := ShotChecks.run({"name": "p", "kind": "position", "node": "name:StairTop", "expect": {"y": [2.9, 3.1]}}, root, null, false)
	assert_eq(pos.values.y, 3.0)
	assert_true(pos.ok)
	var box := ShotChecks.run({"name": "b", "kind": "aabb", "node": "Landing"}, root, null, false)
	assert_almost_eq(float(box.values.size_y), 1.0, 0.001)
	var hit := ShotChecks.run({"name": "o", "kind": "overlap", "a": "StairTop", "b": "Landing", "expect": {"overlaps": true}}, root, null, false)
	assert_true(hit.ok)
	assert_almost_eq(float(hit.values.volume), 0.8, 0.001)
	var miss := ShotChecks.run({"name": "o2", "kind": "overlap", "a": "StairTop", "b": "group:probe_test"}, root, null, false)
	assert_false(miss.values.overlaps)
	assert_almost_eq(float(miss.values.gap), sqrt(8.5 * 8.5 + 2.0 * 2.0), 0.01)
	var n := ShotChecks.run({"name": "n", "kind": "count", "type": "MeshInstance3D", "center": [0, 3, 0], "radius": 2, "expect": {"count": 2}}, root, null, false)
	assert_true(n.ok)
	var lost := ShotChecks.run({"name": "l", "kind": "position", "node": "Nope"}, root, null, false)
	assert_false(lost.ok)
	assert_true(lost.has("error"))


func _box(n: String, at: Vector3, size: Vector3) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.name = n
	var mesh := BoxMesh.new()
	mesh.size = size
	m.mesh = mesh
	m.position = at
	return m
