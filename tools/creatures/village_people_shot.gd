## The village and market people standing in the real village square at village eye
## height (lane L52), for before/after review of their models:
##   godot res://tools/creatures/village_people_shot.tscn -- <out_dir>
## Writes village_people.png (all seven in a row, 7 m back) and village_people_close.png
## (the three nearest the camera, 3.2 m back). Ids missing from the build are skipped.
extends Node

const IDS := ["human_woman", "human_man", "human_elder", "mercenary", "human_youth", "peddler", "blessed"]

var _out := "user://village_people"
var _world: World
var _cam: Camera3D


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else _out
	DirAccess.make_dir_recursive_absolute(_out)
	Clock.paused = true
	Clock.time_of_day = 0.45
	var root := get_tree().root
	root.size = Vector2i(1920, 1080)
	_world = load("res://world/shared/world/world.tscn").instantiate() as World
	root.add_child(_world)
	var sq := HumanRealmLayout.VILLAGE_SQUARE
	var c := _ground(Vector3(sq.x, 0.0, sq.y))
	_world.grade.swap_to(&"human_winter", 0.0)
	for def in _region_defs():
		if Vector2(def.center.x - c.x, def.center.z - c.z).length() < def.radius + 200.0:
			var scene: PackedScene = load(def.scene_path)
			if scene != null:
				_world.regions.add_child(scene.instantiate())
	_cam = Camera3D.new()
	_cam.fov = 45.0
	_cam.far = 900.0
	_world.add_child(_cam)
	_cam.make_current()
	var placed := 0
	for i in IDS.size():
		if not ResourceLoader.exists("res://creatures/people/scenes/%s.tscn" % IDS[i]):
			continue
		var npc := (load("res://creatures/people/scenes/%s.tscn" % IDS[i]) as PackedScene).instantiate() as CourtNpc
		npc.wander_radius = 0.0
		_world.add_child(npc)
		npc.global_position = _ground(c + Vector3(-4.2 + 1.4 * i, 0.0, 0.0))
		npc.rotation.y = PI    # the people face -Z; turn them to the camera
		placed += 1
	print("placed ", placed, " villagers at ", c)
	await _settle(2.5)
	_cam.global_position = c + Vector3(0.0, 1.6, 7.0)
	_cam.look_at(c + Vector3(0.0, 1.0, 0.0))
	await _settle(0.5)
	await _save(_out + "/village_people.png")
	_cam.global_position = c + Vector3(0.0, 1.55, 3.2)
	_cam.look_at(c + Vector3(0.0, 1.15, 0.0))
	await _settle(0.5)
	await _save(_out + "/village_people_close.png")
	get_tree().quit()


func _ground(p: Vector3) -> Vector3:
	return Vector3(p.x, WorldHeight.height_at(p.x, p.z), p.z)


func _settle(seconds: float) -> void:
	var t0 := Time.get_ticks_msec()
	while (Time.get_ticks_msec() - t0) / 1000.0 < seconds:
		await get_tree().process_frame


func _save(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("wrote ", path)


func _region_defs() -> Array[RegionDef]:
	var out: Array[RegionDef] = []
	var dir := DirAccess.open("res://data/regions/human_realm")
	if dir == null:
		return out
	for f in dir.get_files():
		if f.ends_with(".tres"):
			var def := load("res://data/regions/human_realm/" + f) as RegionDef
			if def != null:
				out.append(def)
	return out
