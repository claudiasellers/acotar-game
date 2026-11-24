## TimeScale is the one writer of Engine.time_scale: named requests, the
## lowest wins. Nothing else in the game sets the clock (dev tools under
## tools/ may, and tests reset it).
extends GutTest

const SKIP := ["res://addons", "res://tests", "res://tools", "res://.lanes", "res://.git", "res://.godot"]
const OWNER := "res://systems/feedback/time_scale.gd"


func after_each() -> void:
	TimeScale.reset()


func test_the_lowest_request_wins_and_release_restores_the_clock() -> void:
	TimeScale.request(&"a", 0.4)
	assert_almost_eq(Engine.time_scale, 0.4, 0.001)
	TimeScale.request(&"b", 0.05)
	assert_almost_eq(Engine.time_scale, 0.05, 0.001)
	TimeScale.release(&"b")
	assert_almost_eq(Engine.time_scale, 0.4, 0.001)
	assert_true(TimeScale.is_requested(&"a"))
	TimeScale.release(&"a")
	assert_eq(Engine.time_scale, 1.0)


func test_only_time_scale_writes_the_engine_clock() -> void:
	var write := RegEx.create_from_string("Engine\\.time_scale\\s*[-+*/]?=[^=]")
	var writers: Array[String] = []
	var scripts := 0
	var dirs: Array[String] = ["res://"]
	while not dirs.is_empty():
		var dir: String = dirs.pop_back()
		for sub in DirAccess.get_directories_at(dir):
			var path := dir.path_join(sub)
			if not path in SKIP:
				dirs.append(path)
		for file in DirAccess.get_files_at(dir):
			var path := dir.path_join(file)
			if not file.ends_with(".gd") or path == OWNER:
				continue
			scripts += 1
			if write.search(FileAccess.get_file_as_string(path)):
				writers.append(path)
	assert_gt(scripts, 300, "the walk covered the game's scripts")
	assert_eq(writers, [] as Array[String], "only TimeScale sets Engine.time_scale")
