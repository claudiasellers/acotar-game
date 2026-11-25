## Monster weapons and camp gear lined up beside Feyre (1.7 m), in the game's
## own shading, so size and look can be judged (lane L88). Renders in the cloud:
##   xvfb-run -a godot --path . res://tools/monster_gear/gear_shot.tscn -- <out_dir> <weapons|camp|hands> [family]
## weapons: every weapon standing on its butt in a row, the worn one behind it.
## camp: the camp gear in a row. hands: one in her hand and one in a gloamer's.
extends Node

const SIZE := Vector2i(2880, 1620)
const FEYRE := "res://characters/feyre/model/feyre_model.tscn"
const GLOAMER := "res://creatures/models/fae/gloamer.gltf"
const GEAR := "res://art/monster_gear/"
const FOV := 33.0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://gear_shot"
	var mode := args[1] if args.size() > 1 else "weapons"
	var family := args[2] if args.size() > 2 else ""
	DirAccess.make_dir_recursive_absolute(out)
	get_tree().root.size = SIZE
	var cam := _stage()
	var feyre := (load(FEYRE) as PackedScene).instantiate() as Node3D
	add_child(feyre)
	var rows: Array = JSON.parse_string(FileAccess.get_file_as_string(GEAR + "monster_gear_manifest.json"))["assets"]
	var lo := -0.5
	var hi := 0.5
	var top := 1.8
	if mode == "hands":
		await _hold(feyre, "RightHand", "wpn_gloamer_hookknife")
		if ResourceLoader.exists(GLOAMER):
			var g := (load(GLOAMER) as PackedScene).instantiate() as Node3D
			add_child(g)
			g.position = Vector3(-1.1, 0.0, 0.0)
			var anim := g.find_child("AnimationPlayer", true, false) as AnimationPlayer
			if anim != null and anim.has_animation(&"idle"):
				anim.play(&"idle")
				anim.seek(0.0, true)
				anim.pause()
			await _hold(g, "hand_r", "wpn_gloamer_knuckleclub")
		lo = -1.8
		hi = 0.8
	else:
		var x := -0.7
		for row: Dictionary in rows:
			if row["group"] != ("weapon" if mode == "weapons" else "camp") or (family != "" and row["family"] != family):
				continue
			var m := gear(row["id"])
			add_child(m)
			var size: Array = row["size_m"]
			if mode == "weapons":
				var wide := maxf(float(size[2]), 0.3)
				x -= wide * 0.5 + 0.12
				var cord := m.find_child(String(row["id"]) + "_cord", true, false) as Node3D
				var butt := -(m.find_child(String(row["id"]), true, false) as MeshInstance3D).get_aabb().position.y
				if cord != null:
					cord.rotation.x = PI
					butt = 0.95
				m.rotation.y = -PI * 0.5
				m.position = Vector3(x, maxf(butt, 0.02), 0.0)
				var worn := m.find_child(String(row["id"]) + "_worn", true, false) as Node3D
				if worn != null:
					worn.visible = true
					worn.position = Vector3(-0.4, 0.0, 0.22)
				x -= wide * 0.5 + 0.2
				top = maxf(top, float(size[1]) + 0.1)
			else:
				var wide := float(size[0])
				x -= wide * 0.5 + 0.25
				# a hanging piece is shown hung, its lowest point at knee height
				var lift := (float(size[1]) + 0.4) if row.get("hangs", false) else 0.0
				m.position = Vector3(x, lift, 0.0)
				x -= wide * 0.5 + 0.25
				top = maxf(top, float(size[1]) + lift + 0.1)
		lo = x
	var mid := (lo + hi) * 0.5
	var dist := maxf((hi - lo) * 0.5 / tan(deg_to_rad(27.0)), top * 0.55 / tan(deg_to_rad(FOV * 0.5))) * 1.02
	cam.fov = FOV
	cam.global_position = Vector3(mid, top * 0.5 + dist * 0.14, -dist)
	cam.look_at(Vector3(mid, top * 0.45, 0.0))
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 800:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png("%s/monster_gear_%s%s.png" % [out, mode, ("_" + family) if family != "" else ""])
	get_tree().quit()


## One gear model as the game shows it: the finish shader on, LOD1 and the worn
## mesh hidden.
static func gear(id: String) -> Node3D:
	var m := (load(GEAR + id + ".glb") as PackedScene).instantiate() as Node3D
	for mi: MeshInstance3D in m.find_children("*", "MeshInstance3D", true, false):
		if String(mi.name).ends_with("_lod1") or String(mi.name).ends_with("_worn"):
			mi.visible = false
		for s in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(s)
			if mat != null and (mat.resource_name == "opaque" or mat.resource_name == "clear"):
				mi.set_surface_override_material(s, PropFinishes.material(StringName(mat.resource_name)))
	return m


func _hold(body: Node3D, bone: String, id: String) -> void:
	var sk := body.find_child("Skeleton3D", true, false) as Skeleton3D
	if sk == null or sk.find_bone(bone) < 0:
		push_warning("gear_shot: no bone %s" % bone)
		return
	var at := BoneAttachment3D.new()
	sk.add_child(at)
	at.bone_name = bone
	var hold := Node3D.new()
	at.add_child(hold)
	hold.add_child(gear(id))
	# held out in front, edge forward and down, at the model's true size
	hold.top_level = true
	await get_tree().process_frame
	await get_tree().process_frame
	var up := Vector3(0.0, 0.75, -0.66).normalized()
	var edge := Vector3(0.0, -0.66, -0.75)
	hold.global_transform = Transform3D(Basis(up.cross(-edge), up, -edge), at.global_position + up * 0.02)


func _stage() -> Camera3D:
	var env := Environment.new()
	var sky := Sky.new()
	var mat := ProceduralSkyMaterial.new()
	mat.sky_top_color = Color(0.35, 0.5, 0.72)
	mat.sky_horizon_color = Color(0.72, 0.78, 0.8)
	mat.ground_bottom_color = Color(0.12, 0.14, 0.1)
	mat.ground_horizon_color = Color(0.5, 0.55, 0.5)
	sky.sky_material = mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.93, 0.82)
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	add_child(sun)
	sun.rotation = Vector3(deg_to_rad(-42.0), deg_to_rad(205.0), 0.0)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60.0, 60.0)
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.2, 0.26, 0.16)
	plane.material = gm
	ground.mesh = plane
	add_child(ground)
	var cam := Camera3D.new()
	add_child(cam)
	cam.make_current()
	return cam
