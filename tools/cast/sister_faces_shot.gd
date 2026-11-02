## Face close-ups of Nesta and Elain in the real cottage region (L37 proof; needs
## a GPU: Mac shots, docs/SHOTS.md):
##   godot res://tools/cast/sister_faces_shot.tscn -- <out_dir>
## Loads the World with the cottage region as the game does, stands the two
## sisters (their real FamilyMember scenes, routines frozen) in the yard by
## the door in late-morning light, and writes:
##   faces_front.png  both faces, straight on
##   nesta_face.png / elain_face.png  each face, three-quarter, close
##   sisters_inside.png  the two of them by the hearth, the cottage's own light
extends Node

const SIZE := Vector2i(1920, 1080)

var _out := "user://sister_faces"
var _cam: Camera3D


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else OS.get_environment("SHOTS_OUT")
	if _out == "":
		_out = "user://sister_faces"
	DirAccess.make_dir_recursive_absolute(_out)
	Clock.paused = true
	Clock.time_of_day = 10.5 / 24.0
	get_tree().root.size = SIZE
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
	var nesta := _sister(world, &"nesta")
	var elain := _sister(world, &"elain")
	_cam = Camera3D.new()
	_cam.fov = 30.0
	world.add_child(_cam)
	_cam.current = true
	# Outside: 3 m out from the door, side by side, facing away from the house.
	var out_dir := door.global_basis.z
	out_dir.y = 0.0
	out_dir = out_dir.normalized()
	var side := out_dir.cross(Vector3.UP).normalized()
	var spot := door.global_position + out_dir * 3.0
	_stand(nesta, spot + side * 0.45, out_dir)
	_stand(elain, spot - side * 0.45, out_dir)
	await _settle(2.0)
	var hn := _head(nesta)
	var he := _head(elain)
	var mid := (hn + he) * 0.5
	_look(mid + out_dir * 2.1, mid)
	await _snap("faces_front.png")
	_look(hn + (out_dir * 0.80 + side * 0.45).normalized() * 0.80, hn + Vector3.DOWN * 0.01)
	await _snap("nesta_face.png")
	_look(he + (out_dir * 0.80 - side * 0.45).normalized() * 0.80, he + Vector3.DOWN * 0.01)
	await _snap("elain_face.png")
	# Inside by the hearth, in the cottage's own light.
	var room := inside.global_position
	var in_dir := (room - door.global_position)
	in_dir.y = 0.0
	in_dir = in_dir.normalized()
	var in_side := in_dir.cross(Vector3.UP).normalized()
	_stand(nesta, room + in_side * 0.4, -in_dir)
	_stand(elain, room - in_side * 0.4, -in_dir)
	await _settle(1.0)
	var c := (_head(nesta) + _head(elain)) * 0.5
	_look(c - in_dir * 1.6, c)
	await _snap("sisters_inside.png")
	print("sister_faces: nesta head %s elain head %s" % [hn, he])
	get_tree().quit()


func _sister(world: Node3D, id: StringName) -> FamilyMember:
	var m := (load("res://creatures/family/%s.tscn" % id) as PackedScene).instantiate() as FamilyMember
	m.schedule = null
	world.add_child(m)
	m.set_scripted(true)
	return m


func _stand(m: FamilyMember, at: Vector3, facing: Vector3) -> void:
	m.global_position = at
	m.go_to(at)
	m.rotation.y = atan2(-facing.x, -facing.z)   # a FamilyMember faces its -Z, as when it walks


func _head(m: FamilyMember) -> Vector3:
	for sk: Skeleton3D in m.find_children("*", "Skeleton3D", true, false):
		var i := sk.find_bone("Head")
		if i >= 0:
			return sk.to_global(sk.get_bone_global_pose(i).origin) + Vector3.UP * 0.07
	return m.global_position + Vector3.UP * (m.height - 0.1)


func _look(from: Vector3, at: Vector3) -> void:
	_cam.global_position = from
	_cam.look_at(at, Vector3.UP)


func _snap(name: String) -> void:
	await _settle(0.6)
	await RenderingServer.frame_post_draw
	get_tree().root.get_texture().get_image().save_png(_out.path_join(name))
	print("wrote ", name)


func _settle(seconds: float) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		await get_tree().process_frame
	for i in 3:
		await get_tree().process_frame


func _anchor(id: StringName) -> Node3D:
	for a in get_tree().get_nodes_in_group(&"story_anchor"):
		if StringName(a.get_meta(&"anchor_id", a.name)) == id:
			return a as Node3D
	return null
