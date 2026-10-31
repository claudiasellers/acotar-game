## Screenshots of the dressing room screen in the real manor (needs a GPU or lavapipe):
##   godot res://tools/dressing_room_shot.tscn -- <gowns|crowns|vanity|all> [out_dir]
## Feyre walks up to the dressing room's wardrobe (or mirror), opens it and
## tries something on; the capture is after the twirl and sparkles.
extends Node

const ESTATE := "res://world/spring_court/manor_estate/manor_estate.tscn"
const LOOKS := {
	"gowns": {"station": &"wardrobe", "tab": "Gowns", "wear": [&"ball_gown_rose"]},
	"crowns": {"station": &"wardrobe", "tab": "Crowns", "wear": [&"butterfly_gown_lilac", &"flower_crown_rose"]},
	"vanity": {"station": &"dressing_mirror", "tab": "Makeup", "wear": [&"dinner_gown_blush"], "hair": &"crown_braid"},
}


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var which := args[0] if args.size() > 0 else "all"
	var out := args[1] if args.size() > 1 else OS.get_environment("SHOTS_OUT")
	if out == "":
		out = "user://"
	var ids: Array = LOOKS.keys() if which == "all" else [which]
	var estate := (load(ESTATE) as PackedScene).instantiate()
	get_tree().root.add_child(estate)
	get_tree().current_scene = estate
	# The estate spawns her itself when it is the current scene; this probe
	# adds it after, so spawn her the same way.
	if estate.get(&"feyre") == null:
		estate.call(&"_add_preview_environment")
		estate.call(&"_spawn_feyre")
	await _frames(60)
	var feyre := estate.get(&"feyre") as Feyre
	var settle := 4.0 if OS.get_environment("SHOTS_QUALITY") == "look" else 1.0
	for id in ids:
		var look: Dictionary = LOOKS[id]
		_stand_at(feyre, look["station"])
		await _frames(20)
		DressingRoom.open(feyre, look["station"])
		var view := get_tree().root.get_node("DressingRoom/DressingRoomView") as DressingRoomView
		for i in view.tabs.get_tab_count():
			if String(view.tabs.get_tab_control(i).name) == look["tab"]:
				view.tabs.current_tab = i
		if look.has("hair"):
			Gameplay.wardrobe.set_hair(look["hair"])
		for piece: StringName in look["wear"]:
			Gameplay.wardrobe.grant(piece)
			view.wear(piece)
		# Software rendering is slow: wait for the twirl itself, not the clock.
		while view.is_twirling():
			await get_tree().process_frame
		await _seconds(settle)
		# One more sparkle so the capture shows the burst mid-air.
		Juice.burst(feyre.model, &"outfit")
		await _seconds(0.35)
		await RenderingServer.frame_post_draw
		var path := out.path_join("dressing_%s.png" % id)
		get_tree().root.get_texture().get_image().save_png(path)
		print("saved ", path)
		DressingRoom.close_room(feyre)
		await _frames(5)
	get_tree().quit()


## Puts her on the floor just in front of the station, on its open side.
func _stand_at(feyre: Feyre, station_id: StringName) -> void:
	var station: Node3D = null
	for s in get_tree().get_nodes_in_group(&"station"):
		if s.get(&"station_id") == station_id:
			station = s
	if station == null:
		push_error("no %s station" % station_id)
		return
	var space := feyre.get_world_3d().direct_space_state
	var from := station.global_position + Vector3.UP * 0.6
	var best := Vector3.FORWARD
	var room := 0.0
	for i in 8:
		var d := Vector3.FORWARD.rotated(Vector3.UP, i * TAU / 8.0)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + d * 8.0, 1))
		var free := 8.0 if hit.is_empty() else from.distance_to(hit["position"])
		if free > room:
			room = free
			best = d
	var spot := station.global_position + best * 1.3 + Vector3.UP * 1.5
	var floor_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(spot, spot + Vector3.DOWN * 4.0, 1))
	feyre.global_position = floor_hit["position"] if not floor_hit.is_empty() else spot - Vector3.UP * 1.5
	feyre.velocity = Vector3.ZERO


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _seconds(s: float) -> void:
	var until := Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame
