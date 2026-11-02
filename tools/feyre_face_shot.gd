## Close-ups of Feyre's face in the real manor (needs a GPU or lavapipe):
##   godot res://tools/feyre_face_shot.tscn -- [out_dir]
## Writes face_vanity.png (the vanity screen, no makeup chosen: her natural look),
## face_vanity_close.png (camera at her face by the mirror) and face_drive_front.png /
## face_drive_34.png (daylight on the manor drive, front and three-quarter), face_drive_back.png
## (her hair from behind), face_glare.png and face_mask_smile.png (expressions, lane L36),
## and face_vanity_back.png (the crown braid from behind).
extends Node

const ESTATE := "res://world/spring_court/manor_estate/manor_estate.tscn"


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else OS.get_environment("SHOTS_OUT")
	if out == "":
		out = "user://"
	var estate := (load(ESTATE) as PackedScene).instantiate()
	get_tree().root.add_child(estate)
	get_tree().current_scene = estate
	if estate.get(&"feyre") == null:
		ShotLook.dress(estate, &"manor_interior")
		estate.call(&"_spawn_feyre")
	await _frames(60)
	var feyre := estate.get(&"feyre") as Feyre
	var settle := 4.0 if OS.get_environment("SHOTS_QUALITY") == "look" else 1.0
	# the slung bow and quiver cross the lens this close; hide them
	for n in feyre.find_children("*", "Node3D", true, false):
		var low := String(n.name).to_lower()
		if low.contains("bow") or low.contains("quiver") or low.contains("arrow"):
			(n as Node3D).visible = false
	var drive_pos := feyre.global_position
	var drive_rot := feyre.rotation

	# Daylight on the drive first, in her own clothes.
	await _seconds(settle)
	await _close_up(feyre, 0.0, out.path_join("face_drive_front.png"))
	await _close_up(feyre, 32.0, out.path_join("face_drive_34.png"))
	await _close_up(feyre, 180.0, out.path_join("face_drive_back.png"), 0.95)
	var face: Node = feyre.find_child("FaceDriver", true, false)   # under her model scene
	if face != null:
		for e: StringName in [&"glare", &"mask_smile"]:
			face.call(&"express", e, 1.0, 30.0)
			await _seconds(1.0)
			await _close_up(feyre, 12.0, out.path_join("face_%s.png" % e))
		face.call(&"clear")
		await _seconds(0.5)
	# A/B for the skin shader's terms (diagnostic): no subsurface, then no rim
	var head_mat: ShaderMaterial = null
	for c in feyre.model.get_children():
		if c.get(&"skin_head_material") != null:
			head_mat = c.get(&"skin_head_material")
	if head_mat != null and args.size() > 1 and args[1] == "ab":
		var sss: Variant = head_mat.get_shader_parameter("subsurface")
		head_mat.set_shader_parameter("subsurface", 0.0)
		await _close_up(feyre, 0.0, out.path_join("face_drive_front_nosss.png"))
		head_mat.set_shader_parameter("subsurface", 0.25 if sss == null else sss)
		head_mat.set_shader_parameter("natural_brows_amount", 0.0)
		await _close_up(feyre, 0.0, out.path_join("face_drive_front_nobrows.png"))
		head_mat.set_shader_parameter("natural_brows_amount", 0.8)

	# The vanity: open the mirror on the Makeup tab with nothing chosen.
	_stand_at(feyre, &"dressing_mirror")
	await _frames(20)
	Gameplay.wardrobe.clear_makeup()
	Gameplay.wardrobe.set_hair(&"crown_braid")
	DressingRoom.open(feyre, &"dressing_mirror")
	var view := get_tree().root.get_node("DressingRoom/DressingRoomView") as DressingRoomView
	for i in view.tabs.get_tab_count():
		if String(view.tabs.get_tab_control(i).name) == "Makeup":
			view.tabs.current_tab = i
	await _seconds(settle)
	await _save(out.path_join("face_vanity.png"))
	DressingRoom.close_room(feyre)
	await _frames(10)
	await _close_up(feyre, 20.0, out.path_join("face_vanity_close.png"))
	await _close_up(feyre, 160.0, out.path_join("face_vanity_back.png"), 0.95)
	feyre.global_position = drive_pos
	feyre.rotation = drive_rot
	get_tree().quit()


## A camera `dist` m in front of her face (turned `yaw` degrees round her), aimed at her eyes.
func _close_up(feyre: Feyre, yaw: float, path: String, dist: float = 0.62) -> void:
	var sk := feyre.find_child("Skeleton3D", true, false) as Skeleton3D
	var xf := sk.global_transform
	var head := xf * sk.get_bone_global_pose(sk.find_bone("Head")).origin
	var eye_l := xf * sk.get_bone_global_pose(sk.find_bone("LeftEye")).origin
	var eye_r := xf * sk.get_bone_global_pose(sk.find_bone("RightEye")).origin
	var eyes := (eye_l + eye_r) * 0.5
	var fwd := eyes - head
	fwd.y = 0.0
	fwd = fwd.normalized().rotated(Vector3.UP, deg_to_rad(yaw))
	var cam := Camera3D.new()
	cam.fov = 30.0
	get_tree().root.add_child(cam)
	cam.global_position = eyes + fwd * dist - Vector3.UP * 0.035
	cam.look_at(eyes - Vector3.UP * 0.04, Vector3.UP)
	cam.make_current()
	await _frames(30)
	await _save(path)
	cam.queue_free()
	await _frames(2)


func _save(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_tree().root.get_texture().get_image().save_png(path)
	print("saved ", path)


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
	# face the mirror so the close-up sees her face lit by the room
	var to_station := station.global_position - feyre.global_position
	feyre.rotation.y = atan2(-to_station.x, -to_station.z)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _seconds(s: float) -> void:
	var until := Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame
