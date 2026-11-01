## The beast at the door as the player sees it, staged (lane L22,
## story/staging/beast_door_staging.gd), in the real cottage with the real
## beast and father. Needs a GPU (Mac shots, docs/SHOTS.md):
##   godot res://tools/creatures/beast_door_film_shot.tscn -- <out_dir> [numbers]
## film_sheet.png: six frames, left to right then the second row: the door
## bursts, he fills the room, the throw window (her view), the father's plea,
## the ash arrow snapped, back to her camera.
extends Node

const FEYRE := "res://characters/feyre/feyre.tscn"
const TILE := Vector2i(960, 540)


class FakeBeastSpace:
	extends Node3D
	var running: bool = true
	var space_id: StringName = &"beast_door"
	var beast: Node3D


var _out := "user://beast_door_film"
var _numbers := false
var _sheet: Image
var _frame := 0
var _staging: BeastDoorStaging


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else _out
	_numbers = args.has("numbers")
	DirAccess.make_dir_recursive_absolute(_out)
	Clock.paused = true
	Clock.time_of_day = 0.9
	get_tree().root.size = Vector2i(1920, 1080)
	var world := load("res://world/shared/world/world.tscn").instantiate() as World
	get_tree().root.add_child(world)
	world.grade.swap_to(&"human_winter", 0.0)
	var def := load("res://data/regions/human_realm/cottage.tres") as RegionDef
	world.regions.add_child((load(def.scene_path) as PackedScene).instantiate())
	await _settle(2.0)
	var door := _anchor(&"act1_cottage_door")
	var inside := _anchor(&"act1_cottage_interior")
	if door == null or inside == null:
		push_error("cottage anchors missing")
		get_tree().quit(1)
		return
	var feyre := (load(FEYRE) as PackedScene).instantiate() as Feyre
	world.add_child(feyre)
	# Across the room from the door, toward the hearth.
	var room := inside.get_parent() as Node3D
	feyre.global_position = room.to_global(Vector3(1.4, 0.0, 0.4)) + Vector3.UP * 0.1
	var to_door := door.global_position - feyre.global_position
	feyre.model.rotation.y = atan2(-to_door.x, -to_door.z)
	var rig := feyre.camera.get_parent().get_parent().get_parent() as Node3D
	rig.rotation.y = feyre.model.rotation.y
	var father := (load("res://creatures/family/father.tscn") as PackedScene).instantiate() as Node3D
	world.add_child(father)
	father.global_position = inside.global_position + (inside.global_basis * Vector3(1.4, 0.0, 1.0))
	var space := FakeBeastSpace.new()
	world.add_child(space)
	space.global_transform = inside.global_transform
	var beast := (load("res://creatures/beast/beast_actor.tscn") as PackedScene).instantiate() as Node3D
	world.add_child(beast)
	# As BeastDoor places him (L01-9): outside, facing in; the break carries him in.
	beast.global_transform = door.global_transform
	beast.global_position += door.global_basis.z * 3.0
	var latch := door.get_node_or_null(^"CottageDoorLatch") as Node3D
	(beast as BeastActor).door = latch if latch else door
	space.beast = beast
	var staging := BeastDoorStaging.new()
	space.add_child(staging)
	_staging = staging
	_sheet = Image.create(TILE.x * 3, TILE.y * 2, false, Image.FORMAT_RGB8)
	await _settle(2.5)
	# The beats as BeastDoor plays them.
	StoryControl.set_mode(StoryControl.Mode.WALK)
	StoryControl.shake = 0.8
	EventBus.story_actor_cue.emit(&"tamlin_beast", &"enter")
	await _settle(0.5)
	await _grab("door bursts")
	StoryControl.shake = 0.0
	StoryControl.set_mode(StoryControl.Mode.LOOK)
	StoryControl.set_focus(beast)
	# The low angle waits for him to stop after the break (up to 1.6 s), then blends.
	await _settle(2.4)
	await _grab("fills the room")
	EventBus.story_actor_cue.emit(&"tamlin_beast", &"accuse")
	StoryControl.shake = 0.35
	await _settle(0.6)
	StoryControl.shake = 0.0
	StoryControl.set_mode(StoryControl.Mode.LOOK, PackedStringArray(["fire"]))
	await _settle(1.2)
	await _grab("throw window")
	StoryControl.set_focus(null)
	EventBus.story_actor_cue.emit(&"tamlin_beast", &"speak")
	EventBus.story_actor_cue.emit(&"father", &"plead")
	StoryControl.set_mode(StoryControl.Mode.LOOK)
	await _settle(2.4)
	await _grab("father pleads")
	EventBus.story_actor_cue.emit(&"tamlin_beast", &"snap_ash_arrow")
	await _settle(0.8)
	await _grab("ash arrow snapped")
	EventBus.scene_space_finished.emit(&"beast_door")
	StoryControl.release()
	await _settle(2.0)
	await _grab("back to her")
	if not _numbers:
		_sheet.save_png(_out + "/film_sheet.png")
	get_tree().quit(0)


func _grab(label: String) -> void:
	var cine := Cine.of(get_tree())
	var cam := get_viewport().get_camera_3d()
	var b := _staging
	var beast := b._beast()
	print("  beast at %s facing %s head %s; feyre %s" % [beast.global_position, -beast.global_basis.z, b._head(beast), b._feyre().global_position])
	print("frame %d %s: shot %s, cine %s (%s), bars %.2f, fov %.1f, cam at %s" % [_frame, label,
			_staging.shot_name,
			cine.active, cine.target_kind, cine.bars, cam.fov, cam.global_position])
	if not _numbers:
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		img.resize(TILE.x, TILE.y, Image.INTERPOLATE_LANCZOS)
		_sheet.blit_rect(img, Rect2i(Vector2i.ZERO, TILE), Vector2i((_frame % 3) * TILE.x, (_frame / 3) * TILE.y))
	_frame += 1


func _anchor(id: StringName) -> Node3D:
	for a in get_tree().get_nodes_in_group(&"story_anchor"):
		if StringName(a.get_meta(&"anchor_id", a.name)) == id:
			return a as Node3D
	return null


func _settle(seconds: float) -> void:
	var t0 := Time.get_ticks_msec()
	while (Time.get_ticks_msec() - t0) / 1000.0 < seconds:
		await get_tree().process_frame
