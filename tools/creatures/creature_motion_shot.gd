## The great wolf's hit and death in the real hunting-forest clearing, for
## judging the motion by eye (lane L22). Needs a GPU (Mac shots, docs/SHOTS.md):
##   godot res://tools/creatures/creature_motion_shot.tscn -- <out_dir>
## He stands over the dead doe, head down. The ash arrow takes him in the right
## side (hit.png: the flinch), he turns to the shooter, the second arrow takes
## him in the eye, and he dies. fall_sheet.png is eight frames of the death
## (left to right, top row then bottom; times printed), lying.png where he ends.
## Prints his spine height and the bone each arrow rode.
extends Node

const CLEARING := Vector2(-360.0, 1660.0)  # HumanRealmLayout.DOE_CLEARING
const SHEET_TIMES: Array[float] = [0.2, 0.6, 1.1, 1.6, 2.1, 2.6, 3.4, 6.0]
const TILE := Vector2i(960, 540)

var _out := "user://creature_motion"
var _world: World
var _cam: Camera3D
var _wolf: GreatWolf
## `numbers` (second arg): no pictures, only the printed heights (headless dry run).
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
	var root := get_tree().root
	root.size = Vector2i(1920, 1080)
	_world = load("res://world/shared/world/world.tscn").instantiate() as World
	root.add_child(_world)
	var at := Vector3(CLEARING.x, 0.0, CLEARING.y)
	at.y = WorldHeight.height_at(at.x, at.z)
	_cam = Camera3D.new()
	_cam.fov = 48.0
	_cam.far = 1200.0
	_world.add_child(_cam)
	_cam.global_position = at + Vector3(5.5, 1.4, -4.5)
	_cam.look_at(at + Vector3(0, 0.9, 0))
	_cam.make_current()
	_world.grade.swap_to(&"human_winter", 0.0)
	for def in _region_defs():
		if Vector2(def.center.x - at.x, def.center.z - at.z).length() < def.radius + 300.0:
			var scene: PackedScene = load(def.scene_path)
			if scene != null:
				_world.regions.add_child(scene.instantiate())
	print("world up; regions near the clearing: ", _world.regions.get_child_count())
	await _settle(2.0)
	# The doe lies where he took her; he stands over her, head down.
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
	await _settle(4.0)
	_frame_wolf()
	await _settle(1.5)
	# The ash arrow: his right side, from a shooter off his right shoulder.
	var shooter := _wolf.global_transform * Vector3(9.0, 1.0, -4.0)
	var side := _wolf.global_transform * Vector3(0.45, 1.05, 0.15)
	_shoot(side, shooter, &"ash")
	await _settle(0.22)
	await _save(_out + "/hit.png")
	# He turns to look at the shooter once (no player in this probe, so turn him).
	var yaw := atan2(-(shooter.x - _wolf.global_position.x), -(shooter.z - _wolf.global_position.z))
	var turn := create_tween()
	turn.tween_property(_wolf, ^"rotation:y", yaw, 0.9).set_trans(Tween.TRANS_SINE)
	await _settle(1.6)
	_frame_wolf()
	# The second arrow: through the eye, from the same side.
	var eye := _wolf.global_transform * Vector3(0.18, 1.72, -1.55)
	_shoot(eye, shooter, &"wood")
	var t0 := Time.get_ticks_msec()
	var sheet := Image.create(TILE.x * 4, TILE.y * 2, false, Image.FORMAT_RGB8)
	for i in SHEET_TIMES.size():
		while (Time.get_ticks_msec() - t0) / 1000.0 < SHEET_TIMES[i]:
			await get_tree().process_frame
		if not _numbers:
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			img.convert(Image.FORMAT_RGB8)
			img.resize(TILE.x, TILE.y, Image.INTERPOLATE_LANCZOS)
			sheet.blit_rect(img, Rect2i(Vector2i.ZERO, TILE), Vector2i((i % 4) * TILE.x, (i / 4) * TILE.y))
		print("fall_sheet frame %d at %.2f s: spine %.2f m above ground" % [i, (Time.get_ticks_msec() - t0) / 1000.0, _spine_height()])
	if not _numbers:
		sheet.save_png(_out + "/fall_sheet.png")
	while (Time.get_ticks_msec() - t0) / 1000.0 < _wolf.animator.death_length() + 0.5:
		await get_tree().process_frame
	await _save(_out + "/lying.png")
	print("lying: spine %.2f m above ground, fell to %s flank" % [_spine_height(), "left" if _wolf.animator.fell_to < 0 else "right"])
	for pin in _wolf.find_children("Pin_*", "BoneAttachment3D", true, false):
		print("arrow rides bone ", (pin as BoneAttachment3D).bone_name)
	get_tree().quit(0)


## Camera at his right front, low, so the fall (onto his left flank) shows his
## face, the arrows and the legs going out.
func _frame_wolf() -> void:
	var p := _wolf.global_position
	_cam.global_position = _wolf.global_transform * Vector3(4.6, 1.3, -4.4)
	_cam.global_position.y = maxf(_cam.global_position.y, WorldHeight.height_at(_cam.global_position.x, _cam.global_position.z) + 1.0)
	_cam.look_at(p + Vector3(0, 0.8, 0) + (-_wolf.global_basis.z) * 0.3)


## A visible arrow stuck at `at`, flying from `from`; the creature takes the hit
## and the animator pins the shaft to the nearest bone.
func _shoot(at: Vector3, from: Vector3, id: StringName) -> void:
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


func _spine_height() -> float:
	var sk := _wolf.animator.skeleton
	var p := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("spine")).origin
	return p.y - WorldHeight.height_at(p.x, p.z)


func _ground(p: Vector3) -> Vector3:
	return Vector3(p.x, WorldHeight.height_at(p.x, p.z) + 0.05, p.z)


func _settle(seconds: float) -> void:
	var t0 := Time.get_ticks_msec()
	while (Time.get_ticks_msec() - t0) / 1000.0 < seconds:
		await get_tree().process_frame


func _save(path: String) -> void:
	print("%s: spine %.2f m above ground" % [path.get_file(), _spine_height()])
	if _numbers:
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path)


func _region_defs() -> Array[RegionDef]:
	var out: Array[RegionDef] = []
	for realm in ["human_realm"]:
		var dir := DirAccess.open("res://data/regions/%s" % realm)
		if dir == null:
			continue
		for f in dir.get_files():
			if f.ends_with(".tres"):
				var def := load("res://data/regions/%s/%s" % [realm, f]) as RegionDef
				if def != null:
					out.append(def)
	return out
