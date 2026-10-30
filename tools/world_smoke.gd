## World smoke test, run by the build lane on every merge (engineering rules R16).
##
##   godot --headless -s tools/world_smoke.gd            # every region
##   godot --headless -s tools/world_smoke.gd -- spring_court
##   godot --headless -s tools/world_smoke.gd -- --changed-since=origin/main
##     strict only for regions this branch adds or changes (their RegionDef,
##     scene folder or report differ from the ref); others print WARN and do
##     not fail the run.
##
## Finds every RegionDef under data/regions/ at any depth, and every region
## scene on the contract path world/<realm>/<id>/<id>.tscn. A scene with no
## RegionDef fails (WorldStreamer could never stream it).
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


var _changed: PackedStringArray = []
var _scoped: bool = false


func _run() -> void:
	var only := PackedStringArray()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--changed-since="):
			_scoped = true
			_changed = _changed_paths(arg.trim_prefix("--changed-since="))
		else:
			only.append(arg)
	var regions := _discover_regions(only)
	var orphans := _orphan_scenes(regions, only)
	var failures := 0
	for id in regions:
		var problems := await _check_region(regions, id)
		var region: RegionDef = regions[id]
		var touched := _touched([region.resource_path, region.scene_path.get_base_dir(), region.report_path])
		failures += _report(region.get_meta(&"realm", "?"), id, problems, touched)
	# Region scenes on the contract path with no RegionDef: still load them,
	# and fail them, because WorldStreamer can never stream them.
	for scene_path in orphans:
		var problems := PackedStringArray(["no RegionDef in data/regions/ for %s" % scene_path])
		problems.append_array(await _load_scenes([scene_path]))
		failures += _report(scene_path.get_base_dir().get_base_dir().get_file(), scene_path.get_file().get_basename(),
				problems, _touched([scene_path.get_base_dir()]))
	print("world_smoke: %d regions, %d failed" % [regions.size() + orphans.size(), failures])
	quit(1 if failures > 0 else 0)


func _report(realm: String, id: String, problems: PackedStringArray, touched: bool = true) -> int:
	if problems.is_empty():
		print("PASS %s/%s" % [realm, id])
		return 0
	if not touched:
		print("WARN %s/%s (not changed on this branch): %s" % [realm, id, "; ".join(problems)])
		return 0
	print("FAIL %s/%s: %s" % [realm, id, "; ".join(problems)])
	return 1


## Repo paths (res://...) changed between `ref` and HEAD.
func _changed_paths(ref: String) -> PackedStringArray:
	var out: Array = []
	var code := OS.execute("git", ["-C", ProjectSettings.globalize_path("res://"), "diff", "--name-only", "%s...HEAD" % ref], out)
	var paths := PackedStringArray()
	if code != 0:
		print("WARN cannot diff against %s; checking every region strictly" % ref)
		_scoped = false
		return paths
	for line in String(out[0]).split("\n", false):
		paths.append("res://" + line.strip_edges())
	return paths


## True when the run is not scoped, or any changed file is one of `paths` or under it.
func _touched(paths: Array) -> bool:
	if not _scoped:
		return true
	for changed in _changed:
		for path: String in paths:
			if path != "" and (changed == path or changed.begins_with(path + "/")):
				return true
	return false


## Every RegionDef anywhere under data/regions/ (any depth), keyed by id.
## `only` limits to realms (first folder under data/regions/) when given.
func _discover_regions(only: PackedStringArray) -> Dictionary:
	var regions := {}
	for path in _files_under(REGIONS_ROOT, ".tres"):
		var realm := path.trim_prefix(REGIONS_ROOT + "/").get_slice("/", 0)
		if not only.is_empty() and not only.has(realm):
			continue
		# Cheap header check: data/regions also holds big layout resources.
		var head := FileAccess.get_file_as_string(path).substr(0, 200)
		if not head.contains('script_class="RegionDef"'):
			continue
		var res := load(path)
		if res is RegionDef:
			if regions.has(String(res.id)):
				print("FAIL %s: duplicate region id '%s'" % [path, res.id])
			res.set_meta(&"realm", realm)
			regions[String(res.id)] = res
	return regions


## Region scenes on the contract path world/<realm>/<id>/<id>.tscn that no
## RegionDef points at.
func _orphan_scenes(regions: Dictionary, only: PackedStringArray) -> PackedStringArray:
	var claimed := {}
	for region: RegionDef in regions.values():
		claimed[region.scene_path] = true
	var orphans := PackedStringArray()
	for realm in ["human_realm", "spring_court"]:
		if not only.is_empty() and not only.has(realm):
			continue
		var realm_dir := "res://world/%s" % realm
		if not DirAccess.dir_exists_absolute(realm_dir):
			continue
		for id in DirAccess.get_directories_at(realm_dir):
			var scene_path := "%s/%s/%s.tscn" % [realm_dir, id, id]
			if FileAccess.file_exists(scene_path) and not claimed.has(scene_path):
				orphans.append(scene_path)
	return orphans


func _files_under(dir_path: String, suffix: String) -> PackedStringArray:
	var out := PackedStringArray()
	if not DirAccess.dir_exists_absolute(dir_path):
		return out
	for file in DirAccess.get_files_at(dir_path):
		var clean := file.trim_suffix(".remap")
		if clean.ends_with(suffix):
			out.append("%s/%s" % [dir_path, clean])
	for sub in DirAccess.get_directories_at(dir_path):
		out.append_array(_files_under("%s/%s" % [dir_path, sub], suffix))
	return out


## Instances scenes together for a few frames; returns the errors raised.
func _load_scenes(paths: Array) -> PackedStringArray:
	var problems := PackedStringArray()
	_errors.clear()
	var holder := Node3D.new()
	root.add_child(holder)
	for path in paths:
		var scene := load(path) as PackedScene
		if scene == null:
			problems.append("cannot load %s" % path)
			continue
		holder.add_child(scene.instantiate())
	for _i in FRAMES_PER_REGION:
		await process_frame
	holder.queue_free()
	await process_frame
	for error in _errors:
		problems.append("error: %s" % error)
	return problems


func _check_region(regions: Dictionary, id: String) -> PackedStringArray:
	var problems := PackedStringArray()
	var region: RegionDef = regions[id]
	var paths: Array = []
	for load_id in [id] + Array(region.neighbors):
		var def: RegionDef = regions.get(load_id)
		if def == null:
			problems.append("neighbor '%s' has no RegionDef" % load_id)
		else:
			paths.append(def.scene_path)
	problems.append_array(await _load_scenes(paths))
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
