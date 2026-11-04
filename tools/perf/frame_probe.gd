## Frame budget probe (program brief T1). Runs one canonical shot scene as its
## child and records what the renderer did over the last WINDOW drawn frames
## before the scene quits (shot scenes settle ~30 frames, then save and quit).
## Use the wrapper, which loops over tools/shots/canonical.txt:
##   tools/perf/frame_pass.sh            (make perf)
## Direct form (env carries the probe's own settings; user args go to the scene):
##   PERF_SCENE=res://tools/world_shot.tscn PERF_NAME=cottage PERF_CSV=/tmp/x.csv \
##     godot --path . res://tools/perf/frame_probe.tscn -- cottage_snow /tmp/c.png
## The Mac shot listener can't set env, so the same settings also come as user
## args after the scene's own (the scene ignores them): --perf-scene=res://…
## --perf-name=<name> --perf-csv=<path>. The PERF line on stdout is the result.
## Frame times are real only on a real GPU (the Mac). On lavapipe the counts
## (draw calls, primitives, objects, materials) are still exact.
extends Node

const WINDOW := 30
const CENSUS_EVERY := 20
const HEADER := "date,commit,device,renderer,name,frames,frame_ms_median,frame_ms_p95,gpu_ms_median,cpu_ms_median,draw_calls,primitives,objects,vram_mb,texture_mb,buffer_mb,shaders,standard_materials,shader_materials,status"

var _name: String = ""
var _csv: String = ""
var _vp: RID
var _last_drawn: int = -1
var _last_usec: int = 0
var _samples: Array[Dictionary] = []
var _census := {"shaders": 0, "standard": 0, "shader_materials": 0}
var _drawn: int = 0
var _status: String = "ok"
var _written: bool = false


func _ready() -> void:
	_name = OS.get_environment("PERF_NAME")
	_csv = OS.get_environment("PERF_CSV")
	var scene_path := OS.get_environment("PERF_SCENE")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--perf-scene="):
			scene_path = a.trim_prefix("--perf-scene=")
		elif a.begins_with("--perf-name="):
			_name = a.trim_prefix("--perf-name=")
		elif a.begins_with("--perf-csv="):
			_csv = a.trim_prefix("--perf-csv=")
	_vp = get_viewport().get_viewport_rid()
	# Uncapped, or every frame reads as the 16.7 ms vsync interval.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	RenderingServer.viewport_set_measure_render_time(_vp, true)
	var timeout := OS.get_environment("PERF_TIMEOUT")
	get_tree().create_timer(float(timeout) if timeout.is_valid_float() else 900.0).timeout.connect(_on_timeout)
	var packed := load(scene_path) as PackedScene
	if packed == null:
		_status = "no_scene"
		get_tree().quit(1)
		return
	add_child.call_deferred(packed.instantiate())


func _process(_delta: float) -> void:
	var drawn := Engine.get_frames_drawn()
	if drawn == _last_drawn:
		return
	var now := Time.get_ticks_usec()
	if _last_drawn >= 0:
		_samples.append({
			"frame_ms": float(now - _last_usec) / 1000.0,
			"gpu_ms": RenderingServer.viewport_get_measured_render_time_gpu(_vp),
			"cpu_ms": RenderingServer.viewport_get_measured_render_time_cpu(_vp),
			"draw_calls": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			"primitives": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
			"objects": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
			"vram": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED),
			"tex": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED),
			"buf": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_BUFFER_MEM_USED),
		})
		if _samples.size() > WINDOW:
			_samples.pop_front()
	_last_drawn = drawn
	_last_usec = now
	_drawn += 1
	if _drawn % CENSUS_EVERY == 0:
		_census = material_census(get_tree().root)


## Distinct shaders and material kinds on every visible geometry in the tree.
static func material_census(root: Node) -> Dictionary:
	var shaders := {}
	var standard := {}
	var shader_mats := {}
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		var g := n as GeometryInstance3D
		if g == null or not g.is_visible_in_tree():
			continue
		var mats: Array[Material] = []
		if g.material_override != null:
			mats.append(g.material_override)
		var mesh: Mesh = null
		if g is MeshInstance3D:
			var mi := g as MeshInstance3D
			mesh = mi.mesh
			for i in mi.get_surface_override_material_count():
				if mi.get_surface_override_material(i) != null:
					mats.append(mi.get_surface_override_material(i))
		elif g is MultiMeshInstance3D and (g as MultiMeshInstance3D).multimesh != null:
			mesh = (g as MultiMeshInstance3D).multimesh.mesh
		if mesh != null:
			for i in mesh.get_surface_count():
				if mesh.surface_get_material(i) != null:
					mats.append(mesh.surface_get_material(i))
		for m in mats:
			var cur: Material = m
			while cur != null:
				if cur is ShaderMaterial:
					shader_mats[cur.get_instance_id()] = true
					var sh := (cur as ShaderMaterial).shader
					if sh != null:
						shaders[sh.get_rid()] = true
				elif cur is BaseMaterial3D:
					standard[cur.get_instance_id()] = true
				cur = cur.next_pass
	return {"shaders": shaders.size(), "standard": standard.size(), "shader_materials": shader_mats.size()}


static func median(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var v := values.duplicate()
	v.sort()
	return v[v.size() / 2]


static func percentile(values: Array[float], p: float) -> float:
	if values.is_empty():
		return 0.0
	var v := values.duplicate()
	v.sort()
	return v[clampi(int(ceil(p * v.size())) - 1, 0, v.size() - 1)]


func _column(key: String) -> Array[float]:
	var out: Array[float] = []
	for s in _samples:
		out.append(float(s[key]))
	return out


func row() -> String:
	var mb := 1.0 / (1024.0 * 1024.0)
	var renderer := str(ProjectSettings.get_setting_with_override(&"rendering/renderer/rendering_method"))
	var cols: Array[String] = [
		Time.get_datetime_string_from_system(true), OS.get_environment("PERF_COMMIT"),
		RenderingServer.get_video_adapter_name().replace(",", " "), renderer, _name, str(_samples.size()),
		"%.2f" % median(_column("frame_ms")), "%.2f" % percentile(_column("frame_ms"), 0.95),
		"%.2f" % median(_column("gpu_ms")), "%.2f" % median(_column("cpu_ms")),
		"%d" % median(_column("draw_calls")), "%d" % median(_column("primitives")), "%d" % median(_column("objects")),
		"%.0f" % (median(_column("vram")) * mb), "%.0f" % (median(_column("tex")) * mb), "%.0f" % (median(_column("buf")) * mb),
		str(_census.shaders), str(_census.standard), str(_census.shader_materials),
		_status if not _samples.is_empty() else "no_frames",
	]
	return ",".join(cols)


func _on_timeout() -> void:
	_status = "timeout"
	get_tree().quit(3)


func _exit_tree() -> void:
	if _written or _csv.is_empty():
		return
	_written = true
	var exists := FileAccess.file_exists(_csv)
	var f := FileAccess.open(_csv, FileAccess.READ_WRITE if exists else FileAccess.WRITE)
	if f == null:
		printerr("frame_probe: cannot write %s" % _csv)
		return
	if exists:
		f.seek_end()
	else:
		f.store_line(HEADER)
	var line := row()
	f.store_line(line)
	print("PERF " + line)
