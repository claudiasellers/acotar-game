## Feyre's third-person camera indoors (needs a GPU; Mac shots, docs/SHOTS.md):
##   godot res://tools/indoor_camera_shot.tscn -- <out_dir>
## Stands her in the Archeron cottage (after the beast breaks the door) and in the
## manor's dining hall, bedroom and bath, and saves each view at the default pitch
## and with the player looking steeply down. Prints the camera height above her
## head and the ceiling hit, so the clamp can be checked as numbers too.
extends Node3D

const FEYRE := "res://characters/feyre/feyre.tscn"
const COTTAGE := "res://world/human_realm/cottage/cottage.tscn"
const MANOR_ROOMS: Array[StringName] = [&"dining_hall", &"feyre_bedroom", &"feyre_bath"]

var _feyre: Feyre


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://indoor"
	DirAccess.make_dir_recursive_absolute(out)
	Clock.paused = true
	Clock.time_of_day = 0.45
	_light()
	WorldState.set_flag("fact.cottage_door_broken", true)
	var cottage := (load(COTTAGE) as PackedScene).instantiate() as Node3D
	add_child(cottage)
	var spots: Array = []
	var room := cottage.find_child("act1_cottage_interior", true, false) as Node3D
	# On the floor between the beds and the broken door (the marker itself is over the table).
	spots.append(["cottage", room.global_transform * Vector3(-1.6, 0.0, 0.6),
			cottage.find_child("Hearth", true, false).global_position])
	var house := Node3D.new()
	add_child(house)
	house.position = Vector3(0.0, 0.0, 3000.0)
	ManorHouseBuilder.build(house)
	var idx := ManorHouseIndex.new(ManorHouseBuilder.load_layouts())
	for r in idx.interior_rooms():
		if MANOR_ROOMS.has(r.id):
			var c := r.rect.get_center()
			var p := house.to_global(Vector3(c.x, ManorHouseBuilder.floor_y(r.level), c.y))
			# A quarter in from the west wall, clear of a centre table.
			p.x -= r.rect.size.x * 0.25
			spots.append([String(r.id), p, p + Vector3(r.rect.size.x, 0.0, 0.0)])
	_feyre = (load(FEYRE) as PackedScene).instantiate() as Feyre
	add_child(_feyre)
	for s in spots:
		await _shoot(s[0], s[1], s[2], out)
	get_tree().quit()


func _shoot(label: String, at: Vector3, face: Vector3, out: String) -> void:
	_feyre.velocity = Vector3.ZERO
	_feyre.global_position = at + Vector3.UP * 0.1
	var to := face - at
	_feyre.model.rotation.y = atan2(-to.x, -to.z)     # facing `face`, camera behind her
	_feyre.recenter_camera()
	await _settle(1.5)
	_report(label + "_default")
	await _save("%s/%s_default.png" % [out, label])
	_feyre.nudge_camera(0.0, deg_to_rad(-60.0))
	await _settle(1.0)
	_report(label + "_look_down")
	await _save("%s/%s_look_down.png" % [out, label])


func _report(label: String) -> void:
	var pivot := _feyre.global_position + Vector3.UP * 1.5
	var hit := get_world_3d().direct_space_state.intersect_ray(
			PhysicsRayQueryParameters3D.create(pivot, pivot + Vector3.UP * 9.0, Feyre.WORLD_MASK, [_feyre.get_rid()]))
	print("%s: camera %.2f m above her head (%.2f m above her feet), pitch %.1f deg, ceiling %s" % [
			label, _feyre.camera_rise(), _feyre.camera_rise() + 1.5, rad_to_deg(_feyre.camera_pitch()),
			"none" if hit.is_empty() else "%.2f m above her feet" % ((hit.position as Vector3).y - _feyre.global_position.y)])


func _settle(seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		await get_tree().process_frame
		t += get_process_delta_time()


func _save(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path)


func _light() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.6, 0.68)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.35, 0.33, 0.32)
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45.0, 35.0, 0.0)
	sun.light_energy = 0.8
	sun.shadow_enabled = true
	add_child(sun)
