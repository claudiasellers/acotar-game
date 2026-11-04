## Stills of Feyre's bedroom curtains before and after the curtain trap strips
## their trimmings (T077):  godot res://tools/curtain_strip_shot.tscn -- [out_dir]
## Writes curtains_before.png, curtains_one.png (the middle window stripped)
## and curtains_after.png (all of them), by day and at night.
extends Node

const ESTATE := "res://world/spring_court/manor_estate/manor_estate.tscn"


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else OS.get_environment("SHOTS_OUT")
	if out == "":
		out = "user://"
	DirAccess.make_dir_recursive_absolute(out)
	var estate := (load(ESTATE) as PackedScene).instantiate()
	get_tree().root.add_child(estate)
	get_tree().current_scene = estate
	if estate.get(&"feyre") == null:
		ShotLook.dress(estate, &"manor_interior")
	Clock.paused = true
	var holder: Node3D
	var give_up := Time.get_ticks_msec() + 240000
	while holder == null and Time.get_ticks_msec() < give_up:
		await _seconds(1.0)
		var room := get_tree().root.find_child("feyre_bedroom", true, false)
		if room:
			holder = room.get_node_or_null(^"Curtains") as Node3D
	if holder == null:
		print("probe: no bedroom Curtains holder")
		get_tree().quit(1)
		return
	var mid := Vector3.ZERO
	for w in holder.get_children():
		var d := w.get_node(^"Dressed") as MeshInstance3D
		mid += (d.global_transform * d.get_aabb()).get_center()
		print("probe: %s at %s" % [w.name, (d.global_transform * d.get_aabb()).get_center()])
	mid /= holder.get_child_count()
	var cam := Camera3D.new()
	cam.fov = 75.0
	estate.add_child(cam)
	cam.make_current()
	cam.global_position = mid + Vector3(0, 0.1, 6.5)
	cam.look_at(mid + Vector3(0, -0.2, 0))
	await _seconds(4.0 if OS.get_environment("SHOTS_QUALITY") == "look" else 1.0)
	for night in [false, true]:
		Clock.from_dict({"time_of_day": (22.5 if night else 11.0) / 24.0, "day": 2})
		for stage in ["before", "one", "after"]:
			for i in holder.get_child_count():
				var off: bool = stage == "after" or (stage == "one" and i == 1)
				(holder.get_child(i).get_node(^"Dressed") as Node3D).visible = not off
				(holder.get_child(i).get_node(^"Stripped") as Node3D).visible = off
			await _seconds(2.5 if night else 1.5)
			var still := "curtains_%s%s" % [stage, "_night" if night else ""]
			if DisplayServer.get_name() == "headless":
				print("still %s (headless: not drawn)" % still)
				continue
			await RenderingServer.frame_post_draw
			var img := get_tree().root.get_texture().get_image()
			if img != null and not img.is_empty():
				img.save_png(out.path_join(still + ".png"))
				print("saved %s.png" % still)
	get_tree().quit()


func _seconds(s: float) -> void:
	var until := Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame
