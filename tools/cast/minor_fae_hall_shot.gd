## The masked household and the sentries in the manor's entrance hall after the
## glamour lifts (lane L48 milestone still; needs a GPU, Mac shots, docs/SHOTS.md):
##   shot hall res://tools/cast/minor_fae_hall_shot.tscn {out}
## Builds the house as tools/indoor_camera_shot.gd does, raises glamour_lifted,
## stands the footman, maid and cook (their true forms) and both sentries in
## the hall in front of Feyre, and saves the view behind her and a closer one.
## Prints which model each figure shows, so "no mannequin" is a number too.
extends Node3D

const FEYRE := "res://characters/feyre/feyre.tscn"
const PEOPLE := "res://creatures/people/scenes/%s.tscn"
## id, metres to her right, metres ahead, facing back at her
const CAST := [["servant_footman", -1.4, 4.0], ["servant_maid", 0.2, 5.2], ["servant_cook", 1.6, 4.2],
		["sentry_1", -2.8, 6.4], ["sentry_2", 2.9, 6.6]]

var _feyre: Feyre


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://minor_fae_hall"
	DirAccess.make_dir_recursive_absolute(out)
	Clock.paused = true
	Clock.time_of_day = 0.45
	_light()
	WorldState.set_flag("glamour_lifted", true)
	var house := Node3D.new()
	add_child(house)
	ManorHouseBuilder.build(house)
	var idx := ManorHouseIndex.new(ManorHouseBuilder.load_layouts())
	var hall: Variant = null
	for r in idx.interior_rooms():
		if r.id == &"entrance_hall":
			hall = r
	if hall == null:
		push_error("no entrance_hall")
		get_tree().quit(1)
		return
	var c: Vector2 = hall.rect.get_center()
	var floor_y := ManorHouseBuilder.floor_y(hall.level)
	var long_x: bool = hall.rect.size.x >= hall.rect.size.y
	var fwd := Vector3(1, 0, 0) if long_x else Vector3(0, 0, 1)
	var right := fwd.cross(Vector3.UP)
	var reach: float = (hall.rect.size.x if long_x else hall.rect.size.y) * 0.5
	var at := house.to_global(Vector3(c.x, floor_y, c.y)) - fwd * (reach - 1.5)
	_feyre = (load(FEYRE) as PackedScene).instantiate() as Feyre
	add_child(_feyre)
	for row in CAST:
		var npc := (load(PEOPLE % row[0]) as PackedScene).instantiate() as CourtNpc
		npc.wander_radius = 0.0
		add_child(npc)
		npc.global_position = at + right * float(row[1]) + fwd * float(row[2])
		npc.look_at(at, Vector3.UP)
		var m := npc.current_model()
		var shown := "nothing"
		if m != null:
			shown = m.scene_file_path.get_file() if m.scene_file_path != "" else String(m.name)
		print("%s shows %s" % [row[0], shown])
	_feyre.velocity = Vector3.ZERO
	_feyre.global_position = at + Vector3.UP * 0.1
	_feyre.model.rotation.y = atan2(-fwd.x, -fwd.z)
	_feyre.recenter_camera()
	await _settle(2.0)
	await _save("%s/hall_household.png" % out)
	_feyre.global_position = at + fwd * 2.2 + Vector3.UP * 0.1
	_feyre.recenter_camera()
	await _settle(1.5)
	await _save("%s/hall_household_close.png" % out)
	get_tree().quit()


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
	env.environment.ambient_light_color = Color(0.42, 0.38, 0.40)
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment.glow_enabled = true
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45.0, 35.0, 0.0)
	sun.light_energy = 0.8
	sun.shadow_enabled = true
	add_child(sun)
