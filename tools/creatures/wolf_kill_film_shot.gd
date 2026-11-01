## The wolf kill as the player sees it, staged (lane L22, story/staging/):
## Feyre in the thicket edge, the great wolf on the doe in the real clearing,
## WolfKillStaging running as in the scene. Needs a GPU (Mac shots, docs/SHOTS.md):
##   godot res://tools/creatures/wolf_kill_film_shot.tscn -- <out_dir> [numbers]
## notice.png: the scene's focus on his eyes (tighter lens, half bars).
## ash.png: just after the ash arrow (hit-stop, the look). film_sheet.png:
## eight frames of the kill from the eye shot on (times printed), through
## the low angle, the shoulder shot and the hand-back to her camera.
extends Node

const CLEARING := Vector2(-360.0, 1660.0)  # HumanRealmLayout.DOE_CLEARING
const FEYRE := "res://characters/feyre/feyre.tscn"
const SHEET_TIMES: Array[float] = [0.15, 0.7, 1.6, 3.0, 4.3, 6.5, 8.6, 10.2]
const TILE := Vector2i(960, 540)


## Stands in for the WolfKill space: the staging reads `running` and `wolf`.
class FakeSpace:
	extends Node3D
	var running: bool = true
	var wolf: Node3D


var _out := "user://wolf_kill_film"
var _world: World
var _wolf: GreatWolf
var _feyre: Feyre
var _space: FakeSpace
var _numbers := false


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else _out
	_numbers = args.has("numbers")
	DirAccess.make_dir_recursive_absolute(_out)
	Clock.paused = true
	Clock.time_of_day = 0.42
	get_tree().root.size = Vector2i(1920, 1080)
	_world = load("res://world/shared/world/world.tscn").instantiate() as World
	get_tree().root.add_child(_world)
	var at := _ground(Vector3(CLEARING.x, 0.0, CLEARING.y))
	_world.grade.swap_to(&"human_winter", 0.0)
	for def in _region_defs():
		if Vector2(def.center.x - at.x, def.center.z - at.z).length() < def.radius + 300.0:
			var scene: PackedScene = load(def.scene_path)
			if scene != null:
				_world.regions.add_child(scene.instantiate())
	await _settle(2.0)
	var doe := (load("res://creatures/prey/deer.tscn") as PackedScene).instantiate() as Creature
	_world.add_child(doe)
	doe.global_position = _ground(at + Vector3(0.0, 0.0, -1.9))
	doe.rotation.y = PI * 0.5
	doe.die(&"great_wolf")
	_wolf = (load("res://creatures/wolves/great_wolf.tscn") as PackedScene).instantiate() as GreatWolf
	_world.add_child(_wolf)
	_wolf.global_position = _ground(at)
	_wolf.prey = doe
	_wolf.state = GreatWolf.State.HOLD_PREY
	# Feyre 22 m off his right side, a little ahead, as from the thicket.
	_feyre = (load(FEYRE) as PackedScene).instantiate() as Feyre
	_world.add_child(_feyre)
	var spot := _wolf.global_transform * Vector3(20.0, 0.0, -9.0)
	_feyre.global_position = _ground(spot) + Vector3.UP * 0.1
	_space = FakeSpace.new()
	_world.add_child(_space)
	_space.wolf = _wolf
	_space.add_child(WolfKillStaging.new())
	await _settle(3.0)
	_aim_at(_wolf.global_position + Vector3.UP * 1.0)
	await _settle(0.5)
	# His eyes: the scene's focus.
	StoryControl.set_focus(_wolf)
	await _settle(1.0)
	await _save(_out + "/notice.png")
	StoryControl.set_focus(null)
	await _settle(1.6)
	# The ash arrow in his right side.
	_shoot(_wolf.global_transform * Vector3(0.45, 1.05, 0.15), &"ash")
	await _settle(0.25)
	await _save(_out + "/ash.png")
	await _settle(2.4)
	_aim_at(_wolf.global_position + Vector3.UP * 1.4)
	await _settle(0.5)
	# The second arrow through the eye; the film sheet from here.
	_shoot(_wolf.global_transform * Vector3(0.18, 1.72, -1.55), &"wood")
	var t0 := Time.get_ticks_msec()
	var sheet := Image.create(TILE.x * 4, TILE.y * 2, false, Image.FORMAT_RGB8)
	var cine := Cine.of(get_tree())
	for i in SHEET_TIMES.size():
		while (Time.get_ticks_msec() - t0) / 1000.0 < SHEET_TIMES[i]:
			await get_tree().process_frame
		if not _numbers:
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			img.convert(Image.FORMAT_RGB8)
			img.resize(TILE.x, TILE.y, Image.INTERPOLATE_LANCZOS)
			sheet.blit_rect(img, Rect2i(Vector2i.ZERO, TILE), Vector2i((i % 4) * TILE.x, (i / 4) * TILE.y))
		var staging := _space.get_child(0) as WolfKillStaging
		print("film frame %d at %.2f s: stage %s, cine %s (%s), bars %.2f, fov %.1f, control %d, wolf rate %.2f" % [
			i, (Time.get_ticks_msec() - t0) / 1000.0, staging.stage, cine.active, cine.target_kind,
			cine.bars, get_viewport().get_camera_3d().fov, StoryControl.mode, _wolf.animator.time_scale])
	if not _numbers:
		sheet.save_png(_out + "/film_sheet.png")
	print("camera back to Feyre: ", get_viewport().get_camera_3d() == _feyre.camera)
	get_tree().quit(0)


## Turns Feyre and her camera to `point`, as the player would aim.
func _aim_at(point: Vector3) -> void:
	var to := point - _feyre.global_position
	var yaw := atan2(-to.x, -to.z)
	_feyre.model.rotation.y = yaw
	var rig := _feyre.camera.get_parent().get_parent().get_parent() as Node3D  # CameraRig
	if rig:
		rig.rotation.y = yaw


func _shoot(at: Vector3, id: StringName) -> void:
	var from := _feyre.global_position + Vector3.UP * 1.5
	var arrow := Node3D.new()
	arrow.name = "Arrow_%s" % id
	arrow.set_meta(&"arrow_id", id)
	var shaft := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.008
	mesh.bottom_radius = 0.008
	mesh.height = 0.75
	shaft.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.92, 0.88, 0.8) if id == &"ash" else Color(0.45, 0.32, 0.2)
	shaft.material_override = mat
	shaft.rotation.x = PI * 0.5
	shaft.position.z = 0.25
	arrow.add_child(shaft)
	_world.add_child(arrow)
	arrow.global_position = at
	arrow.look_at(at + (at - from).normalized(), Vector3.UP)
	_wolf.on_arrow_hit(arrow)
	arrow.add_to_group(&"stuck_arrows")
	arrow.reparent(_wolf, true)


func _ground(p: Vector3) -> Vector3:
	return Vector3(p.x, WorldHeight.height_at(p.x, p.z) + 0.05, p.z)


func _settle(seconds: float) -> void:
	var t0 := Time.get_ticks_msec()
	while (Time.get_ticks_msec() - t0) / 1000.0 < seconds:
		await get_tree().process_frame


func _save(path: String) -> void:
	var cine := Cine.of(get_tree())
	print("%s: cine %s (%s), bars %.2f, fov %.1f, wolf rate %.2f" % [path.get_file(), cine.active,
			cine.target_kind, cine.bars, get_viewport().get_camera_3d().fov, _wolf.animator.time_scale])
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
