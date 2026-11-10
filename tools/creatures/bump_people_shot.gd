## Feyre walking up to villagers in the real village square, through her own
## camera (T092), for before/after review of people being solid:
##   godot res://tools/creatures/bump_people_shot.tscn -- <out_dir>
## bump_walk_into.png: she walks 3 s straight at a villager standing 3 m ahead.
## bump_lens_inside.png: a second villager stands where her camera hangs behind her.
## bump_shoulder.png: she stands with a villager just off her shoulder, near the
## line from the lens to her. Prints where she stopped.
extends Node

const FEYRE := preload("res://characters/feyre/feyre.tscn")
const NPC := "res://creatures/people/scenes/human_man.tscn"

var _out := "user://bump_people"
var _world: World


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
	var ahead := _npc(_ground(c + Vector3(0.0, 0.0, -3.0)))
	var feyre := FEYRE.instantiate() as Feyre
	_world.add_child(feyre)
	feyre.global_position = c + Vector3.UP * 0.05
	await _settle(2.0)
	Input.action_press(&"move_forward")
	await _settle(3.0)
	Input.action_release(&"move_forward")
	await _settle(0.6)
	var gap := Vector2(feyre.global_position.x - ahead.global_position.x, feyre.global_position.z - ahead.global_position.z).length()
	print("bump: walked from z=%.2f to z=%.2f; villager at z=%.2f; gap %.2f m; passed through: %s" % [
			c.z, feyre.global_position.z, ahead.global_position.z, gap, feyre.global_position.z < ahead.global_position.z])
	await _save(_out + "/bump_walk_into.png")
	# The lens hangs ~3.4 m behind her and ~0.7 m up: a villager standing there.
	var cam := get_viewport().get_camera_3d()
	var behind := _npc(_ground(Vector3(cam.global_position.x, 0.0, cam.global_position.z)))
	await _settle(0.8)
	print("lens: camera at %s, villager behind at %s" % [cam.global_position, behind.global_position])
	await _save(_out + "/bump_lens_inside.png")
	behind.queue_free()
	# Off her shoulder, halfway back to the lens.
	var mid := feyre.global_position.lerp(cam.global_position, 0.45)
	_npc(_ground(mid + Vector3(0.35, 0.0, 0.0)))
	await _settle(0.8)
	await _save(_out + "/bump_shoulder.png")
	get_tree().quit()


func _npc(at: Vector3) -> CourtNpc:
	var npc := (load(NPC) as PackedScene).instantiate() as CourtNpc
	npc.wander_radius = 0.0
	_world.add_child(npc)
	npc.global_position = at
	npc.rotation.y = PI
	return npc


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
