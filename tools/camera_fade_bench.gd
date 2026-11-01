## Cost of CameraFade (Feyre's lens fade) in a furnished manor room. Prints numbers only:
##   godot res://tools/camera_fade_bench.tscn            (windowed: the real path)
##   godot --headless res://tools/camera_fade_bench.tscn (headless: the fade must be idle)
## Turns the camera a full circle in the dining hall for FRAMES frames and reports the mean
## frame time, the mean and worst cost of one fade query, and, for scale, one full-tree
## walk (what the headless fallback used to do every frame).
extends Node3D

const FEYRE := "res://characters/feyre/feyre.tscn"
const FRAMES := 300


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Clock.paused = true
	var house := Node3D.new()
	add_child(house)
	ManorHouseBuilder.build(house)
	var idx := ManorHouseIndex.new(ManorHouseBuilder.load_layouts())
	var at := Vector3.ZERO
	for r in idx.interior_rooms():
		if r.id == &"dining_hall":
			var c := r.rect.get_center()
			at = house.to_global(Vector3(c.x - r.rect.size.x * 0.25, ManorHouseBuilder.floor_y(r.level), c.y))
	var feyre := (load(FEYRE) as PackedScene).instantiate() as Feyre
	add_child(feyre)
	feyre.global_position = at + Vector3.UP * 0.1
	for i in 30:
		await get_tree().process_frame
	var fade := feyre.get_node("CameraFade") as CameraFade
	var nodes := get_tree().root.find_children("*", "", true, false).size()
	var t0 := Time.get_ticks_usec()
	var meshes := get_tree().root.find_children("*", "GeometryInstance3D", true, false).size()
	var walk_us := Time.get_ticks_usec() - t0
	var query_total := 0
	var query_worst := 0
	var hits := 0
	var start := Time.get_ticks_usec()
	for i in FRAMES:
		feyre.nudge_camera(TAU / FRAMES, 0.0)
		await get_tree().process_frame
		var q0 := Time.get_ticks_usec()
		hits += fade.near_meshes(feyre.camera.global_position).size()
		var q := Time.get_ticks_usec() - q0
		query_total += q
		query_worst = maxi(query_worst, q)
	var frame_ms := (Time.get_ticks_usec() - start) / 1000.0 / FRAMES
	print("camera_fade_bench %s: %d nodes, %d meshes; fade processing %s; frame %.2f ms mean; fade query %.1f us mean, %d us worst, %d hits; one tree walk %d us" % [
			DisplayServer.get_name(), nodes, meshes, fade.is_processing(), frame_ms,
			float(query_total) / FRAMES, query_worst, hits, walk_us])
	get_tree().quit()
