## Lookdev shots of the Border Woods in the real scene (GPU or lavapipe):
##   godot res://tools/woods/border_look_shot.tscn -- <out_dir> <before|after> [view ...]
## `before` is the region as built. `after` swaps every scattered tree for its
## generator-built model (trees/*.glb) in its palette, turns on the toon bands
## and plum shadow fill on every candy_lit material in the region, and gives
## the water the toon shader. Same cameras both ways.
extends Node

const TREES := "res://world/spring_court/border_woods/trees/"
const LEAF_SHADER := preload("res://world/spring_court/shared/woods_tree_leaf.gdshader")
const BARK_SHADER := preload("res://world/spring_court/shared/woods_tree_bark.gdshader")
const WATER_OLD := preload("res://world/spring_court/shared/woods_water.gdshader")
const WATER_TOON := preload("res://world/spring_court/shared/woods_toon_water.gdshader")
const RAMP := preload("res://data/render/candy_ramp_3band.tres")
const SHADOW_FILL := Color(0.40, 0.26, 0.58, 0.5)
const TREE_RADIUS := 300.0

const ROSE_BARK := ["8A6672", "553A50"]
const PLUM_BARK := ["7A5866", "4A3350"]
const PEARL_BARK := ["E4DCDF", "A99AAE"]
## species: [model, deep, mid, light, bark pair, accent, accent amount, size, leaf spray (optional)]
const SPECIES := {
	&"oak": ["tsd_003", "3A7C70", "6FBF98", "BFEAC4", PLUM_BARK, "", 0.0, 1.1, "lsa1"],
	&"ancient_oak": ["tsa_001", "2F6B66", "5CAB8C", "A7DDB8", PLUM_BARK, "", 0.0, 1.0, "lsa1"],
	&"beech": ["tsd", "6FA88A", "A9D9A6", "F3EDB0", PEARL_BARK, "", 0.0, 1.0, "lsa2"],
	&"elm": ["tsb_008", "3B7C7A", "62B5A0", "AEE3CC", ROSE_BARK, "", 0.0, 1.0],
	&"silver_birch": ["tsc_012", "7FBF9A", "B5E3C0", "FCE9A6", PEARL_BARK, "", 0.0, 1.0, "lsa2"],
	&"crab_apple": ["tsa_006", "E58FB0", "FAD4DC", "FFF6F4", ROSE_BARK, "F4A6C0", 0.15, 1.2, "lsa4"],
	&"wild_cherry": ["tsa_002", "E77FA8", "F4A6C0", "FFE1EA", ROSE_BARK, "", 0.0, 1.15, "lsa4"],
	&"candyfloss_tree": ["tsa_002", "E77FA8", "F4A6C0", "FFE1EA", PEARL_BARK, "", 0.0, 1.15, "lsa2"],
	&"lilac_tree": ["tsb_003", "8E6FD0", "C8A8E9", "EBDCFA", ROSE_BARK, "", 0.0, 1.2],
	&"wisteria_tree": ["tsa_005", "7F8FE0", "A7B5F2", "DCD3FA", PLUM_BARK, "C8A8E9", 0.3, 1.2, "lsa3"],
	&"hawthorn": ["tsb_004", "E9B9CF", "FBF0F2", "FFFFFF", PLUM_BARK, "", 0.0, 1.2],
	&"yew": ["tsb", "2C5A62", "3E6F78", "6FA79C", PLUM_BARK, "", 0.0, 1.0],
	&"magnolia": ["tsb_001", "F0A9B4", "FAD4DC", "FFF3E6", PEARL_BARK, "", 0.0, 1.2],
	&"magnolia_harlequin": ["tsb_007", "B79BE8", "F4C3DC", "FFF1F6", PEARL_BARK, "", 0.0, 1.2],
	&"golden_chain": ["tsd_004", "E6C15C", "FCE9A6", "FFF8D6", ROSE_BARK, "", 0.0, 1.1, "lsa3"],
	&"alder": ["tsa_007", "4F9A82", "7CC29A", "B5E3C0", PLUM_BARK, "", 0.0, 1.0, "lsa2"],
	&"elder": ["tsb_005", "9CCFAE", "E9F5E4", "FFFFFF", ROSE_BARK, "", 0.0, 1.2],
	&"willow": ["tsb_002", "5FAE8E", "9AD6AE", "DDF2C8", PLUM_BARK, "", 0.0, 1.1],
	&"hazel": ["tsd_005", "4F9A82", "7CC29A", "B5E3C0", ROSE_BARK, "", 0.0, 1.0, "lsa1"],
}
## view: [eye xz, look-at xz, eye height, look-at height]
const VIEWS := {
	"road": [Vector2(-46, 1196), Vector2(-70, 1060), 2.2, 4.0],
	"oak": [Vector2(-112, 1128), Vector2(-150, 1080), 2.0, 6.0],
	"dell": [Vector2(-262, 716), Vector2(-300, 680), 2.0, 3.0],
	"glen": [Vector2(-322, 1028), Vector2(-345, 1010), 2.4, 0.5],
	"raised": [Vector2(-100, 1362), Vector2(-150, 1080), 20.0, 4.0],
}

var _masks := {}


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://"
	var mode := args[1] if args.size() > 1 else "before"
	var ids: Array = args.slice(2) if args.size() > 2 else VIEWS.keys()
	var root := get_tree().root
	var size := OS.get_environment("LOOK_SIZE").split("x")
	root.size = Vector2i(int(size[0]), int(size[1])) if size.size() == 2 else Vector2i(1920, 1080)
	Clock.paused = true
	Clock.time_of_day = 0.45
	var world: World = load("res://world/shared/world/world.tscn").instantiate()
	root.add_child(world)
	world.grade.swap_to(&"spring", 0.0)
	var cam := Camera3D.new()
	cam.far = 1500.0
	cam.fov = 60.0
	world.add_child(cam)
	cam.make_current()
	if mode == "lineup":
		await _lineup(world, cam, out)
		get_tree().quit(0)
		return
	var first: Array = VIEWS[ids[0]]
	cam.position = Vector3(first[0].x, 60.0, first[0].y)
	var woods := (load("res://world/spring_court/border_woods/border_woods.tscn") as PackedScene).instantiate() as WoodsRegion
	world.regions.add_child(woods)
	await get_tree().process_frame
	woods.build_now()
	ShotQuality.guard_software_renderer(root, world)
	# Trunks (scattered and hand-placed), so no camera ends up inside a crown.
	var trunks: Array[Vector2] = []
	for l in woods.layers:
		if String(l.id).begins_with("tree_"):
			for j in l.count():
				var tp := l.position_of(j)
				trunks.append(Vector2(tp.x, tp.z))
	for n in woods.find_children("*", "MeshInstance3D", true, false):
		var gp := (n as MeshInstance3D).global_position
		trunks.append(Vector2(gp.x, gp.z))
	if mode == "after":
		_swap_trees(woods, ids)
		_swap_props(woods)
		_toon(world)
	for id: String in ids:
		var v: Array = VIEWS[id]
		var at: Vector2 = v[1]
		var eye: Vector2 = v[0] if OS.get_environment("LOOK_NUDGE") == "0" else _clear_eye(v[0], at, trunks)
		print("EYE %s %s (asked %s)" % [id, eye, v[0]])
		cam.position = Vector3(eye.x, WorldHeight.height_at(eye.x, eye.y) + v[2], eye.y)
		cam.look_at(Vector3(at.x, WorldHeight.height_at(at.x, at.y) + v[3], at.y))
		for i in (12 if ShotQuality.on_lavapipe() else 60):
			await get_tree().process_frame
		var path := "%s/%s_%s.png" % [out, id, mode]
		root.get_texture().get_image().save_png(path)
		var draw := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		var prims := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
		print("SHOT %s -> %s | draw_calls %d prims %d" % [id, path, draw, prims])
	get_tree().quit(0)


## The nearest spot to `eye` (within 14 m) with no trunk inside 8 m and none
## within 4 m of the first 22 m of the line of sight. Same answer in both modes.
func _clear_eye(eye: Vector2, at: Vector2, trunks: Array[Vector2]) -> Vector2:
	var dir := (at - eye).normalized()
	for ring in 8:
		for step in maxi(1, ring * 6):
			var cand := eye + Vector2.from_angle(TAU * step / maxf(1.0, ring * 6.0)) * ring * 2.0
			var ok := true
			for t in trunks:
				var rel := t - cand
				if rel.length() < 8.0:
					ok = false
					break
				var along := rel.dot(dir)
				if along > 0.0 and along < 22.0 and absf(rel.cross(dir)) < 4.0:
					ok = false
					break
			if ok:
				return cand
	return eye


func _swap_trees(woods: WoodsRegion, ids: Array) -> void:
	var eyes: Array[Vector2] = []
	for id: String in ids:
		eyes.append(VIEWS[id][0])
	(woods.get_node(^"Trees") as Node3D).visible = false
	var holder := Node3D.new()
	holder.name = "LookTrees"
	woods.add_child(holder)
	for l in woods.layers:
		var lid := String(l.id)
		if not lid.begins_with("tree_"):
			continue
		var sp := StringName(lid.trim_prefix("tree_"))
		var cfg: Array = SPECIES.get(sp, SPECIES[&"oak"])
		if not SPECIES.has(sp):
			print("UNMAPPED %s (%d) -> oak" % [sp, l.count()])
		var mesh := _tree_mesh(cfg)
		var old := l.mesh if l.mesh != null else FloraLibrary.mesh(sp)
		var k: float = old.get_aabb().size.y / mesh.get_aabb().size.y * float(cfg[7])
		var xf: Array[Transform3D] = []
		for j in l.count():
			var p := l.position_of(j)
			var near := false
			for e in eyes:
				if Vector2(p.x, p.z).distance_to(e) < TREE_RADIUS:
					near = true
					break
			if near:
				var t := l.transform_of(j)
				xf.append(Transform3D(t.basis.scaled(Vector3.ONE * k), t.origin))
		if xf.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = xf.size()
		for j in xf.size():
			mm.set_instance_transform(j, xf[j])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = String(sp)
		mmi.multimesh = mm
		holder.add_child(mmi)
		print("TREES %s x%d as %s scale %.2f" % [sp, xf.size(), cfg[0], k])


## Hero trees placed one by one (landmarks, clearings) use the same species meshes.
func _swap_props(woods: WoodsRegion) -> void:
	var by_mesh := {}
	for sp: StringName in SPECIES:
		by_mesh[FloraLibrary.mesh(sp)] = sp
	var swapped := 0
	for n in woods.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if not by_mesh.has(mi.mesh):
			continue
		var cfg: Array = SPECIES[by_mesh[mi.mesh]]
		var mesh := _tree_mesh(cfg)
		var k: float = mi.mesh.get_aabb().size.y / mesh.get_aabb().size.y * float(cfg[7])
		mi.mesh = mesh
		mi.material_override = null
		mi.scale *= k
		swapped += 1
	print("PROPS swapped %d" % swapped)


## Every exported model in a row on the meadow, in the game's light.
func _lineup(world: World, cam: Camera3D, out: String) -> void:
	var names: Array[String] = []
	for f in DirAccess.get_files_at(_dir()):
		if f.ends_with(".glb"):
			names.append(f.get_basename())
	names.sort()
	var palettes := [&"oak", &"wild_cherry", &"lilac_tree", &"beech", &"wisteria_tree", &"crab_apple", &"elm", &"magnolia"]
	var per := 8
	var page := 0
	ShotQuality.guard_software_renderer(get_tree().root, world)
	while page * per < names.size():
		var holder := Node3D.new()
		world.add_child(holder)
		var origin := Vector2(-200.0 + page * 0.0, 1300.0)
		for i in per:
			var idx := page * per + i
			if idx >= names.size():
				break
			var cfg: Array = (SPECIES[palettes[idx % palettes.size()]] as Array).duplicate()
			cfg[0] = names[idx]
			cfg.resize(8)
			cfg.append("lsa%d" % (1 + idx % 4))
			var mesh := _tree_mesh(cfg)
			var mi := MeshInstance3D.new()
			mi.mesh = mesh
			var x := origin.x + (i - (per - 1) * 0.5) * 9.0
			mi.position = Vector3(x, WorldHeight.height_at(x, origin.y), origin.y)
			mi.scale = Vector3.ONE * (10.0 / mesh.get_aabb().size.y)
			mi.rotation.y = 0.7
			holder.add_child(mi)
			print("LINEUP page %d slot %d = %s" % [page, i, names[idx]])
		var eye := Vector3(origin.x, WorldHeight.height_at(origin.x, origin.y + 34.0) + 5.0, origin.y + 34.0)
		cam.position = eye
		cam.look_at(Vector3(origin.x, WorldHeight.height_at(origin.x, origin.y) + 5.0, origin.y))
		for i in 6:
			await get_tree().process_frame
		get_tree().root.get_texture().get_image().save_png("%s/lineup_%d.png" % [out, page])
		holder.free()
		page += 1


func _tree_mesh(cfg: Array) -> ArrayMesh:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	doc.append_from_file(_dir() + String(cfg[0]) + ".glb", state)
	var scene := doc.generate_scene(state)
	var mi := scene.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var mesh := mi.mesh.duplicate() as ArrayMesh
	scene.free()
	for s in mesh.get_surface_count():
		var mat_name := mesh.surface_get_material(s).resource_name if mesh.surface_get_material(s) != null else "bark"
		var m := ShaderMaterial.new()
		if mat_name.begins_with("leaf__"):
			m.shader = LEAF_SHADER
			var mask := mat_name.trim_prefix("leaf__").get_slice(".", 0)
			# Rebuilt crowns take any leaf spray; a species can name its own.
			if mask == "lsa1" and cfg.size() > 8:
				mask = cfg[8]
			m.set_shader_parameter(&"use_mask", mask != "solid")
			if mask != "solid":
				m.set_shader_parameter(&"leaf_mask", _mask(mask))
			m.set_shader_parameter(&"deep_color", Color(cfg[1]))
			m.set_shader_parameter(&"mid_color", Color(cfg[2]))
			m.set_shader_parameter(&"light_color", Color(cfg[3]))
			if cfg[5] != "":
				m.set_shader_parameter(&"accent_color", Color(cfg[5]))
				m.set_shader_parameter(&"accent_amount", cfg[6])
		else:
			m.shader = BARK_SHADER
			m.set_shader_parameter(&"bark_color", Color(cfg[4][0]))
			m.set_shader_parameter(&"foot_color", Color(cfg[4][1]))
		m.set_shader_parameter(&"diffuse_ramp", RAMP)
		m.set_shader_parameter(&"shadow_fill", SHADOW_FILL)
		mesh.surface_set_material(s, m)
	return mesh


## Models folder: LOOK_TREES (an absolute path, for trying exports before they
## are committed) or the region's trees/.
func _dir() -> String:
	var d := OS.get_environment("LOOK_TREES")
	return d if d != "" else ProjectSettings.globalize_path(TREES)


func _mask(id: String) -> Texture2D:
	if not _masks.has(id):
		var img := Image.load_from_file(_dir() + "masks/" + id + ".png")
		img.generate_mipmaps()
		_masks[id] = ImageTexture.create_from_image(img)
	return _masks[id]


## Toon bands and plum shadow fill on every candy_lit material; toon water.
func _toon(root: Node) -> void:
	var seen := {}
	var count := 0
	for n in root.find_children("*", "GeometryInstance3D", true, false):
		var mats: Array[Material] = []
		var g := n as GeometryInstance3D
		if g.material_override != null:
			mats.append(g.material_override)
		var mesh: Mesh = null
		if n is MeshInstance3D:
			mesh = (n as MeshInstance3D).mesh
			for s in (n as MeshInstance3D).get_surface_override_material_count():
				if (n as MeshInstance3D).get_surface_override_material(s) != null:
					mats.append((n as MeshInstance3D).get_surface_override_material(s))
		elif n is MultiMeshInstance3D and (n as MultiMeshInstance3D).multimesh != null:
			mesh = (n as MultiMeshInstance3D).multimesh.mesh
		if mesh != null:
			for s in mesh.get_surface_count():
				if mesh.surface_get_material(s) != null:
					mats.append(mesh.surface_get_material(s))
		for m in mats:
			if seen.has(m) or not (m is ShaderMaterial) or (m as ShaderMaterial).shader == null:
				continue
			seen[m] = true
			var sm := m as ShaderMaterial
			if sm.shader == WATER_OLD:
				sm.shader = WATER_TOON
				count += 1
				continue
			# Flora only: the stand-in ground keeps its own response.
			if not sm.shader.resource_path.get_file().begins_with("woods_f"):
				continue
			for u in sm.shader.get_shader_uniform_list():
				if u.name == "shadow_fill":
					sm.set_shader_parameter(&"diffuse_ramp", RAMP)
					sm.set_shader_parameter(&"shadow_fill", SHADOW_FILL)
					count += 1
					break
	print("TOON materials %d" % count)
