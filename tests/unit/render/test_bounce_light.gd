extends GutTest
## Contract for soft bounce light (render program T3a, L60): outdoor grades take
## 70% of their ambient from the sky, candy_lit throws the ground's light back
## up at 0.35 by default, and SSIL follows the graphics profile.
# gate: when:world/shared/grades/*,world/shared/world/*,world/shared/shaders/candy_lit*,systems/settings/*

const GRADES := "res://world/shared/grades/"
## Closed rooms keep their own GI-led ambient (T043, the owner's look).
const INTERIOR_GRADES: Array[StringName] = [&"manor_interior"]


func test_outdoor_grades_take_their_ambient_from_the_sky() -> void:
	var checked := 0
	for f in DirAccess.get_files_at(GRADES):
		if not f.ends_with(".tres"):
			continue
		var p := load(GRADES + f) as GradePreset
		if p == null or p.id in INTERIOR_GRADES:
			continue
		assert_almost_eq(p.ambient_sky_contribution, 0.7, 0.001, "%s: sky share of the ambient" % f)
		checked += 1
	assert_gt(checked, 15, "the outdoor grades were all read")
	# world.tscn is read as text: loading the World waits on the terrain bake.
	var env := FileAccess.get_file_as_string("res://world/shared/world/world.tscn")
	assert_true(env.contains("ambient_light_source = 3"), "World ambient comes from the sky")
	assert_true(env.contains("ambient_light_sky_contribution = 0.7"))
	assert_true(env.contains("reflected_light_source = 2"), "reflections come from the sky")


func test_candy_lit_throws_the_ground_light_back_up() -> void:
	var code := FileAccess.get_file_as_string("res://world/shared/shaders/candy_lit.gdshaderinc")
	assert_true(code.contains("#define CANDY_BOUNCE_DEFAULT 0.35"), "ground_bounce defaults to 0.35")
	assert_true(code.contains("uniform float ground_bounce : hint_range(0.0, 1.0) = CANDY_BOUNCE_DEFAULT;"))
	assert_true(code.contains("LIGHT_IS_DIRECTIONAL"), "only the sun and moon bounce off the ground")
	assert_false(code.contains("EMISSION"), "bounce is light, never emission")


func test_ssil_follows_the_profile() -> void:
	var env := Environment.new()
	BounceLight.apply(env, &"high")
	assert_true(env.ssil_enabled, "high profile: SSIL on")
	assert_true(env.ssao_enabled)
	assert_almost_eq(env.ssao_radius, 1.0, 0.001)
	assert_almost_eq(env.ssao_intensity, 1.2, 0.001)
	BounceLight.apply(env, &"mac")
	assert_false(env.ssil_enabled, "Mac profile: SSIL off")
	assert_true(env.ssao_enabled, "SSAO stays on every profile")

	var we := WorldEnvironment.new()
	we.environment = Environment.new()
	var node := BounceLight.new()
	node.environment = we
	add_child_autofree(we)
	add_child_autofree(node)
	var before: String = GameSettings.shadow_profile
	GameSettings.shadow_profile = "mac"
	assert_false(we.environment.ssil_enabled, "switching to mac turns SSIL off")
	GameSettings.shadow_profile = "high"
	assert_true(we.environment.ssil_enabled, "switching to high turns it on")
	GameSettings.shadow_profile = before
