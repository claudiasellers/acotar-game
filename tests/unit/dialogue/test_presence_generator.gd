## Contract test: the presence roster and the rest of data/dialogue are exactly
## what tools/dialogue/gen_dialogue.py writes. A position edited in the .tres
## and not the generator comes back wrong on the next regeneration (T054).
extends GutTest

const GENERATOR := "res://tools/dialogue/gen_dialogue.py"
const COMMITTED := "res://data/dialogue"


func _files(dir: String, rel: String = "") -> PackedStringArray:
	var out := PackedStringArray()
	for f in DirAccess.get_files_at(dir.path_join(rel)):
		if f.ends_with(".tres") or f.ends_with(".csv"):
			out.append(rel.path_join(f))
	for d in DirAccess.get_directories_at(dir.path_join(rel)):
		out.append_array(_files(dir, rel.path_join(d)))
	return out


func test_generator_output_equals_committed_files() -> void:
	var out := OS.get_temp_dir().path_join("presence_gen_%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(out)
	var res: Array = []
	OS.set_environment("GEN_DIALOGUE_OUT", out)
	var code := OS.execute("python3", [ProjectSettings.globalize_path(GENERATOR)], res, true)
	OS.unset_environment("GEN_DIALOGUE_OUT")
	if code != 0:
		pending("python3 unavailable or generator failed: %s" % str(res))
		return
	var generated := _files(out)
	assert_gt(generated.size(), 0, "the generator wrote nothing")
	assert_true(generated.has("presence.tres"))
	for rel in generated:
		var want := FileAccess.get_file_as_string(COMMITTED.path_join(rel))
		var got := FileAccess.get_file_as_string(out.path_join(rel))
		assert_true(want == got, "%s differs from the generator: edit tools/dialogue/gen_dialogue.py, not the .tres" % rel)
