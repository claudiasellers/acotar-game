## Look shots for the great wolf and the doe (lane L43, quality audit B7), in
## the real doe clearing at the hunt's light (human_winter grade, 0.42 day).
## Needs a GPU (Mac shots, docs/contracts/shots.md):
##   godot res://tools/creatures/wolf_look_shot.tscn -- <out_dir> [numbers]
## hunt.png: the wolf stalking the doe from the side at ~9 m (the audit's view).
## face.png: his head three-quarter close, the snarl (Faces "lunge") open.
## doe.png: the doe at ~4 m. Also prints the draw calls the wolf adds.
extends Node

const CLEARING := Vector2(-360.0, 1660.0)  # HumanRealmLayout.DOE_CLEARING

var _out := "user://wolf_look_shot"
var _numbers := false
var _cam: Camera3D


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else _out
	_numbers = args.has("numbers")
	var studio := args.has("studio")  # cloud iteration: the grade and sky, no regions
	DirAccess.make_dir_recursive_absolute(_out)
	Clock.paused = true
	Clock.time_of_day = 0.42
	get_tree().root.size = Vector2i(1920, 1080)
	var world := load("res://world/shared/world/world.tscn").instantiate() as World
	get_tree().root.add_child(world)
	var at := _ground(Vector3(CLEARING.x, 0.0, CLEARING.y))
	world.grade.swap_to(&"human_winter", 0.0)
	for def in ([] as Array[RegionDef]) if studio else _region_defs():
		if Vector2(def.center.x - at.x, def.center.z - at.z).length() < def.radius + 300.0:
			var scene: PackedScene = load(def.scene_path)
			if scene != null:
				world.regions.add_child(scene.instantiate())
	if studio:
		var snow := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(200, 200)
		snow.mesh = plane
		var white := StandardMaterial3D.new()
		white.albedo_color = Color(0.93, 0.94, 0.97)
		snow.material_override = white
		world.add_child(snow)
		snow.global_position = at - Vector3(0.0, 0.05, 0.0)
		var floor_body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		shape.shape = WorldBoundaryShape3D.new()
		floor_body.add_child(shape)
		world.add_child(floor_body)
		floor_body.global_position = snow.global_position
	await _settle(2.0)
	for wk in get_tree().root.find_children("*", "WolfKill", true, false):
		wk.queue_free()
	var doe := (load("res://creatures/prey/deer.tscn") as PackedScene).instantiate() as Creature
	world.add_child(doe)
	doe.global_position = _ground(at + Vector3(0.0, 0.0, -4.0))
	doe.rotation.y = PI * 0.5
	doe.set_physics_process(false)
	var wolf := (load("res://creatures/wolves/great_wolf.tscn") as PackedScene).instantiate() as GreatWolf
	world.add_child(wolf)
	wolf.global_position = _ground(at)
	wolf.prey = doe
	# Frozen where he's put: a moving body can drop through terrain whose
	# collision hasn't streamed in yet, and the cameras would follow him down.
	wolf.set_physics_process(false)
	_cam = Camera3D.new()
	_cam.fov = 50.0
	world.add_child(_cam)
	_cam.make_current()
	await _settle(4.0)
	var tris := 0
	for mi: MeshInstance3D in wolf.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			tris += mi.mesh.surface_get_array_index_len(s) / 3
	# The hunt view: side on, as the audit framed it.
	_look(wolf.global_transform * Vector3(9.0, 1.6, -1.5), wolf.global_transform * Vector3(0.0, 0.9, -1.2))
	await _settle(1.5)
	var with_wolf := _draw_calls()
	wolf.visible = false
	await _settle(0.3)
	var without := _draw_calls()
	wolf.visible = true
	await _settle(0.3)
	print("wolf: tris %d, draw calls in frame %d with / %d without = +%d" % [tris, with_wolf, without, with_wolf - without])
	await _save(_out + "/hunt.png")
	# His face, three-quarter, snarling.
	# The lunge face (L36-3's preset), set on the SnarlModifier directly since
	# the face only ticks with physics.
	for snarl in wolf.find_children("Snarl", "", true, false):
		if snarl is SnarlModifier:
			(snarl as SnarlModifier).weights = {&"jaw_open": 1.0, &"ears_back": 1.0, &"head_low": 0.3}
	var sk := wolf.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var head := sk.global_transform * sk.get_bone_global_pose(sk.find_bone(&"muzzle")).origin
	_look(head + wolf.global_basis * Vector3(1.3, 0.25, -1.6), head + Vector3.DOWN * 0.05)
	await _settle(1.5)
	await _save(_out + "/face.png")
	# The doe.
	wolf.visible = false
	_look(doe.global_position + Vector3(-2.2, 1.3, 3.0), doe.global_position + Vector3(0.0, 0.7, 0.0))
	await _settle(1.0)
	await _save(_out + "/doe.png")
	get_tree().quit(0)


func _look(from: Vector3, to: Vector3) -> void:
	_cam.global_position = from
	_cam.look_at(to, Vector3.UP)


func _draw_calls() -> int:
	return RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)


func _ground(p: Vector3) -> Vector3:
	return Vector3(p.x, WorldHeight.height_at(p.x, p.z) + 0.05, p.z)


func _settle(seconds: float) -> void:
	var t0 := Time.get_ticks_msec()
	while (Time.get_ticks_msec() - t0) / 1000.0 < seconds:
		await get_tree().process_frame


func _save(path: String) -> void:
	if _numbers:
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)


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
