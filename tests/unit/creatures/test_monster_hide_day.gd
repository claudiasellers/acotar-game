## Standing rule: no world emissives by day before the glamour lifts. The
## monster hide shader glows only through `eye_glow`, which is 0 until a
## creature's code raises it (lane L83).
# gate: when:creatures/materials/*
extends GutTest

const HIDE := preload("res://creatures/materials/monster_hide.gdshader")
const MATERIALS := "res://creatures/materials"


func _emission_lines() -> PackedStringArray:
	var out := PackedStringArray()
	for line in HIDE.code.split("\n"):
		var code := line.get_slice("//", 0)
		if code.contains("EMISSION") and code.contains("="):
			out.append(code.strip_edges())
	return out


func test_the_hide_emits_only_through_eye_glow() -> void:
	var lines := _emission_lines()
	assert_eq(lines.size(), 1, "one place writes EMISSION")
	if lines.size() == 1:
		assert_true(lines[0].begins_with("EMISSION ="), "it is set, never added to: %s" % lines[0])
		assert_true(lines[0].ends_with("* eye_glow;"), "and the whole of it is scaled by eye_glow: %s" % lines[0])


func test_eye_glow_is_zero_until_code_raises_it() -> void:
	assert_true(HIDE.code.contains("instance uniform float eye_glow = 0.0;"), "eye_glow is a per-instance value that starts at 0")
	var probe := MeshInstance3D.new()
	add_child_autofree(probe)
	assert_null(probe.get_instance_shader_parameter(&"eye_glow"), "nothing sets it on a fresh instance")


func test_no_hide_material_carries_its_own_glow() -> void:
	var seen := 0
	for file in DirAccess.get_files_at(MATERIALS):
		if not file.ends_with(".tres"):
			continue
		var mat := load("%s/%s" % [MATERIALS, file]) as ShaderMaterial
		if mat == null or mat.shader != HIDE:
			continue
		seen += 1
		assert_null(mat.get_shader_parameter(&"eye_glow"), "%s leaves eye_glow to the creature's code" % file)
	assert_gt(seen, 0, "at least one creature wears the hide")
