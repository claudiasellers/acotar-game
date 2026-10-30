## World smoke test, run by the build lane on every merge (engineering rules R16).
##
##   godot --headless -s tools/world_smoke.gd            # every world in data/regions/
##   godot --headless -s tools/world_smoke.gd -- human_realm
##
## For each region: instance it with its neighbors, let it run a few frames,
## and fail on any engine error or script error. Then check the region's
## coverage report (RegionDef.report_path) against the R1 density bar and the
## R9 draw-call budget. Exit code 0 = pass, 1 = fail. Prints one line per
## region plus a summary, nothing else.
extends SceneTree

const REGIONS_ROOT := "res://data/regions"
const FRAMES_PER_REGION := 5

## R1 / R9 thresholds. A report value below (or above, for budgets) fails.
const MIN_TYPES := 25
const MIN_PLACEMENTS_PER_KM2 := 300.0
const MAX_EMPTY_CELLS := 0
const MIN_LANDMARKS := 3
const MAX_DRAW_CALLS := 1500

var _errors: PackedStringArray = []


class ErrorCatcher:
	extends Logger
	var sink: PackedStringArray

	func _init(target: PackedStringArray) -> void:
		sink = target

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtrace: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		sink.append("%s (%s:%d %s)" % [rationale if rationale != "" else code, file, line, function])

	func _log_message(_message: String, _error: bool) -> void:
		pass


func _initialize() -> void:
	OS.add_logger(ErrorCatcher.new(_errors))
	_run.call_deferred()


func _run() -> void:
	var worlds := _worlds_to_check()
	var failures := 0
	var checked := 0
	for world in worlds:
		var regions := _load_regions("%s/%s" % [REGIONS_ROOT, world])
		for id in regions:
			checked += 1
			var problems := await _check_region(regions, id)
			if problems.is_empty():
				print("PASS %s/%s" % [world, id])
			else:
				failures += 1
				print("FAIL %s/%s: %s" % [world, id, "; ".join(problems)])
	print("world_smoke: %d regions, %d failed" % [checked, failures])
	quit(1 if failures > 0 else 0)


func _worlds_to_check() -> PackedStringArray:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		return args
	if not DirAccess.dir_exists_absolute(REGIONS_ROOT):
		return PackedStringArray()
	return DirAccess.get_directories_at(REGIONS_ROOT)


func _load_regions(dir_path: String) -> Dictionary:
	var regions := {}
	for file in DirAccess.get_files_at(dir_path):
		var clean := file.trim_suffix(".remap")
		if clean.ends_with(".tres"):
			var res := load("%s/%s" % [dir_path, clean])
			if res is RegionDef:
				regions[String(res.id)] = res
	return regions


func _check_region(regions: Dictionary, id: String) -> PackedStringArray:
	var problems := PackedStringArray()
	var region: RegionDef = regions[id]
	_errors.clear()

	var holder := Node3D.new()
	root.add_child(holder)
	for load_id in [id] + Array(region.neighbors):
		var def: RegionDef = regions.get(load_id)
		if def == null:
			problems.append("neighbor '%s' has no RegionDef" % load_id)
			continue
		var scene := load(def.scene_path) as PackedScene
		if scene == null:
			problems.append("cannot load %s" % def.scene_path)
			continue
		holder.add_child(scene.instantiate())
	for _i in FRAMES_PER_REGION:
		await process_frame
	holder.queue_free()
	await process_frame

	for error in _errors:
		problems.append("error: %s" % error)
	problems.append_array(_check_report(region))
	return problems


func _check_report(region: RegionDef) -> PackedStringArray:
	var problems := PackedStringArray()
	if region.report_path.is_empty() or not FileAccess.file_exists(region.report_path):
		problems.append("no coverage report (RegionDef.report_path)")
		return problems
	var report: Variant = JSON.parse_string(FileAccess.get_file_as_string(region.report_path))
	if not report is Dictionary:
		problems.append("coverage report is not a JSON object")
		return problems
	var r: Dictionary = report
	if int(r.get("types", 0)) < MIN_TYPES:
		problems.append("types %d < %d" % [int(r.get("types", 0)), MIN_TYPES])
	if float(r.get("placements_per_km2", 0.0)) < MIN_PLACEMENTS_PER_KM2:
		problems.append("placements/km2 %.0f < %.0f" % [float(r.get("placements_per_km2", 0.0)), MIN_PLACEMENTS_PER_KM2])
	if int(r.get("empty_cells", 1)) > MAX_EMPTY_CELLS:
		problems.append("empty 100 m cells %d > %d" % [int(r.get("empty_cells", 1)), MAX_EMPTY_CELLS])
	if int(r.get("landmarks", 0)) < MIN_LANDMARKS:
		problems.append("landmarks %d < %d" % [int(r.get("landmarks", 0)), MIN_LANDMARKS])
	if r.has("draw_calls") and int(r["draw_calls"]) > MAX_DRAW_CALLS:
		problems.append("draw calls %d > %d" % [int(r["draw_calls"]), MAX_DRAW_CALLS])
	return problems
