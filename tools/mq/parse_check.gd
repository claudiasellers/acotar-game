## Parses GDScript without running it.
##   godot --headless -s tools/mq/parse_check.gd              # every script
##   godot --headless -s tools/mq/parse_check.gd -- a.gd b.gd # just these
## Exit code 0 = all parse. Prints one FAIL line per bad script and a summary.
extends SceneTree

const SKIP := ["res://.godot", "res://.lanes", "res://.tools", "res://addons", "res://tools/mq"]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var paths := PackedStringArray()
	for arg in OS.get_cmdline_user_args():
		paths.append("res://" + arg.trim_prefix("res://"))
	if paths.is_empty():
		paths = _scripts_under("res://")
	var failed := 0
	for path in paths:
		var script := ResourceLoader.load(path, "GDScript", ResourceLoader.CACHE_MODE_IGNORE) as GDScript
		if script == null or not script.can_instantiate():
			print("FAIL %s" % path)
			failed += 1
	print("parse_check: %d scripts, %d failed" % [paths.size(), failed])
	quit(1 if failed > 0 else 0)


func _scripts_under(dir_path: String) -> PackedStringArray:
	var out := PackedStringArray()
	for file in DirAccess.get_files_at(dir_path):
		if file.ends_with(".gd"):
			out.append(dir_path.path_join(file))
	for sub in DirAccess.get_directories_at(dir_path):
		var path := dir_path.path_join(sub)
		if not SKIP.has(path) and not FileAccess.file_exists(path.path_join(".gdignore")):
			out.append_array(_scripts_under(path))
	return out
