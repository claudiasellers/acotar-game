## Normal-play woods probe: runs the real game scene (act1_game) with Feyre
## started in a woods region and WorldStreamer threaded, exactly as in play,
## and prints each woods region's build progress once a second until every
## woods region near her is built (or the limit passes).
##   godot [--headless] res://tools/woods/woods_stream_probe.tscn -- [region] [seconds] [out.png] [x z look_x look_z]
## With a renderer and an out path it also saves what Feyre's camera sees, or,
## given x z look_x look_z, Feyre stands at x z and a camera at her eye
## height looks toward look_x look_z.
## Exit code 0 when every loaded woods region built and has trees, else 1.
extends Node

const GAME := "res://story/act1/act1_game.tscn"

var _game: Node
var _t0 := 0
var _log: FileAccess
## region id -> [seconds, frames] when its first trees showed.
var _first_trees := {}


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var region: StringName = StringName(args[0]) if args.size() > 0 else &"border_woods"
	var limit := float(args[1]) if args.size() > 1 else 120.0
	var out := args[2] if args.size() > 2 else ""
	if OS.has_environment("WOODS_PROBE_LOG"):
		_log = FileAccess.open(OS.get_environment("WOODS_PROBE_LOG"), FileAccess.WRITE)
	_game = (load(GAME) as PackedScene).instantiate()
	_game.set(&"start_region", region)
	_game.set(&"start_anchor", &"")
	_game.set(&"spawn_timeout", 0.5)
	get_tree().root.add_child(_game)
	var spot := Vector4.ZERO
	var has_spot := args.size() > 6
	if has_spot:
		spot = Vector4(float(args[3]), float(args[4]), float(args[5]), float(args[6]))
		var feyre: Node3D = _game.get(&"feyre")
		feyre.global_position = Vector3(spot.x, WorldHeight.height_at(spot.x, spot.y) + 2.0, spot.y)
		WorldStreamer.update_for(feyre.global_position)
	_t0 = Time.get_ticks_msec()
	var ok := false
	var frames := 0
	var next := 0.0
	while true:
		await get_tree().process_frame
		frames += 1
		var s := (Time.get_ticks_msec() - _t0) / 1000.0
		var woods := _woods()
		for w: Node in woods:
			if not _first_trees.has(w.def.region_id) and _trees(w) > 0:
				_first_trees[w.def.region_id] = [snappedf(s, 0.1), frames]
		ok = not woods.is_empty() and woods.all(func(w: Node) -> bool: return w.is_built and _trees(w) > 0)
		if s >= next or ok or s >= limit:
			next = s + 1.0
			var parts := PackedStringArray()
			for w: Node in woods:
				parts.append("%s built=%s jobs=%d task=%d trees=%d" % [w.def.region_id, w.is_built, w.get(&"_jobs").size(), w.get(&"_task_id"), _trees(w)])
			_say("WOODS t=%.1fs frames=%d loaded=%s | %s" % [s, frames, ",".join(WorldStreamer.loaded_ids()), " ; ".join(parts)])
		if ok or s >= limit:
			break
	_say("WOODS_PROBE %s %s after %.1f s, %d frames" % [region, "OK" if ok else "FAIL", (Time.get_ticks_msec() - _t0) / 1000.0, frames])
	_say("WOODS_PROBE first trees (s, frames): %s" % _first_trees)
	var costs := FrameBudget.frame_costs()
	var over := 0
	for c in costs:
		if c > FrameBudget.BUDGET_USEC * 3 / 2:
			over += 1
	_say("WOODS_PROBE frames with build work %d: p50 %d us, p95 %d us, over 6 ms %d, late starts %d" % [costs.size(),
			FrameBudget.frame_quantile(0.5), FrameBudget.frame_quantile(0.95), over, FrameBudget.late_starts])
	_say("WOODS_PROBE budget: jobs run %d, worst frame %d us, slowest job %s %d us, job_max %s" % [FrameBudget.queued_jobs_started,
			FrameBudget.max_frame_usec, FrameBudget.slowest_job, FrameBudget.max_job_usec, FrameBudget.job_max])
	if not out.is_empty() and DisplayServer.get_name() != "headless":
		if has_spot:
			var cam := Camera3D.new()
			cam.far = 1200.0
			cam.fov = 60.0
			_game.add_child(cam)
			cam.global_position = Vector3(spot.x, WorldHeight.height_at(spot.x, spot.y) + 1.7, spot.y)
			cam.look_at(Vector3(spot.z, WorldHeight.height_at(spot.z, spot.w) + 1.2, spot.w))
			cam.make_current()
		for i in 120:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_tree().root.get_texture().get_image().save_png(out)
		_say("WOODS_PROBE shot -> %s" % out)
	get_tree().quit(0 if ok else 1)


func _woods() -> Array[Node]:
	var out: Array[Node] = []
	for id in WorldStreamer.loaded_ids():
		var root := WorldStreamer.loaded_root(StringName(id))
		if root is WoodsRegion:
			out.append(root)
	return out


## Tree instances the region shows (all chunks of its Trees field).
func _trees(w: Node) -> int:
	var field := w.get_node_or_null(^"Trees")
	if field == null:
		return 0
	var n := 0
	for mmi in field.find_children("*", "MultiMeshInstance3D", true, false):
		var mm := (mmi as MultiMeshInstance3D).multimesh
		if mm != null:
			n += mm.visible_instance_count if mm.visible_instance_count >= 0 else mm.instance_count
	return n


## print, and a flushed copy in $WOODS_PROBE_LOG (survives a hang or kill).
func _say(line: String) -> void:
	print(line)
	if _log != null:
		_log.store_line(line)
		_log.flush()
