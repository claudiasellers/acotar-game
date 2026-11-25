extends GutTest
## One glow in the game, on real light sources only (owner, 2026-11-25:
## "normal", no glow over everything). GradeDirector sets it; no grade, mood
## or time of day changes it, and a sunlit pastel stays under its threshold.

const ALBEDO_CAP := 0.88   # EstateKit whites and gravel (L18-4)


func _director_on(env: Environment) -> GradeDirector:
	var we := WorldEnvironment.new()
	we.environment = env
	add_child_autofree(we)
	var d := GradeDirector.new()
	d.environment = we
	d.start_grade = &"spring"
	add_child_autofree(d)
	return d


func test_the_director_sets_a_light_source_only_glow() -> void:
	var env := Environment.new()
	env.glow_bloom = 0.3
	env.glow_hdr_threshold = 0.5
	_director_on(env)
	assert_true(env.glow_enabled)
	assert_eq(env.glow_bloom, 0.0, "no bloom wash over everything")
	assert_eq(env.glow_hdr_threshold, GradeDirector.GLOW_THRESHOLD)
	assert_eq(env.get_glow_level(4), 0.0, "no wide haze level")
	assert_eq(env.get_glow_level(5), 0.0)
	assert_eq(env.get_glow_level(6), 0.0)


func test_no_grade_mood_or_night_moves_the_glow() -> void:
	var env := Environment.new()
	var d := _director_on(env)
	var dir := DirAccess.open(GradeDirector.PRESET_DIR)
	for f in dir.get_files():
		if not f.ends_with(".tres"):
			continue
		var id := StringName(f.get_basename())
		d.swap_to(id, 0.0)
		for mood: StringName in [&"dread", &"enchanted_sleep"]:
			d.mood = mood
			d.mood_amount = 1.0
			d.night = 1.0
			d.sight = 1.0
			d.apply(d.current)
			assert_eq(env.glow_intensity, GradeDirector.GLOW_INTENSITY, "%s %s" % [id, mood])
			assert_eq(env.glow_hdr_threshold, GradeDirector.GLOW_THRESHOLD, "%s %s" % [id, mood])
			assert_eq(env.glow_bloom, 0.0, "%s %s" % [id, mood])
		d.mood_amount = 0.0
		d.night = 0.0


func test_a_sunlit_pastel_never_reaches_the_threshold() -> void:
	var dir := DirAccess.open(GradeDirector.PRESET_DIR)
	for f in dir.get_files():
		if not f.ends_with(".tres"):
			continue
		var p := GradeDirector.load_preset(StringName(f.get_basename()))
		var lit := (p.sun_energy + p.ambient_energy) * ALBEDO_CAP
		assert_lt(lit, GradeDirector.GLOW_THRESHOLD, "%s: a sunlit white stays crisp" % p.id)
