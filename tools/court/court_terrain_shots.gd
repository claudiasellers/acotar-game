## Bare-terrain views of the wider court (no region content: the land itself,
## stripped of every model), several per run so the World loads once. Needs a
## GPU (the Mac's shot listener):
##   godot res://tools/court/court_terrain_shots.tscn -- <out dir> [view ids...] [regions]
##        [looks=photo,soft,pastel,storybook src=<folder of Poly Haven 1k maps>]
## `regions` also loads the region scenes near each view (models back in).
## `looks` previews ground looks without committing textures: each look is
## packed at run time by tools/court/pack_ground_textures.gd and swapped onto
## the terrain; "photo" is what the game ships. Files: <view>_<look>.png.
## `fogs=now,layered,layered_mist` previews depth hazes (FOGS) on an in-memory
## copy of the view's grade; files <view>[_<look>]_<fog>.png.
## `ingame` uses the grade the game would show at the eye (the RegionGrade of
## the region you stand in, else the view's grade) instead of the view's.
## `grass=now,toned,none` previews the court's grass clumps (GRASS): as they
## are, toned into the ground, or left out; files ..._grass-<variant>.png.
extends Node

## id: [eye x, eye z, eye height over ground, look x, look z, look height, time 0-1, grade, fov]
const VIEWS := {
	# Leaving the estate: the weenies and the triangles that hide what's next.
	"exit_north": [0.0, -480.0, 1.7, -60.0, -900.0, 20.0, 0.45, &"spring", 70.0],
	"exit_west": [-560.0, -90.0, 1.7, -1100.0, -200.0, 40.0, 0.45, &"spring", 70.0],
	"glen_saddle": [-850.0, 30.0, 1.7, -1300.0, 200.0, 0.0, 0.45, &"spring", 70.0],
	"brae_top": [-760.0, -70.0, 1.7, -1400.0, -300.0, 30.0, 0.45, &"spring", 70.0],
	"the_mound": [-1208.0, 270.0, 1.7, -1300.0, 262.0, -6.0, 0.4, &"spring", 70.0],
	"village_pinch": [-700.0, -705.0, 1.7, -930.0, -800.0, 10.0, 0.5, &"spring", 70.0],
	"village_green": [-930.0, -780.0, 1.7, -1250.0, -1500.0, 60.0, 0.5, &"spring", 70.0],
	"plateau_north": [-180.0, -1112.0, 1.7, -250.0, -1300.0, 0.0, 0.7, &"spring", 70.0],
	"plateau_east": [-120.0, -1060.0, 1.7, 870.0, -1140.0, 60.0, 0.7, &"spring", 70.0],
	"rite_way": [555.0, -800.0, 1.7, 620.0, -1055.0, 20.0, 0.72, &"spring", 70.0],
	"rite_trench": [520.0, -986.0, 1.7, 690.0, -982.0, 4.0, 0.72, &"spring", 70.0],
	"rite_crown": [870.0, -1140.0, 1.7, 0.0, -400.0, -60.0, 0.6, &"spring", 70.0],
	"vale_rim": [720.0, 700.0, 1.7, 1000.0, 1000.0, -10.0, 0.5, &"spring", 70.0],
	"tower_hill": [-1630.0, -650.0, 1.7, -900.0, -300.0, -60.0, 0.4, &"spring", 70.0],
	"western_woods": [-1500.0, 900.0, 1.7, -1700.0, 700.0, 4.0, 0.45, &"spring", 70.0],
	"west_brink": [-1782.0, 180.0, 1.7, -1990.0, 160.0, 40.0, 0.62, &"spring", 70.0],
	"sealed_pass": [-900.0, -1180.0, 1.7, -900.0, -1300.0, 10.0, 0.6, &"spring", 70.0],
	"reaches": [1450.0, -1250.0, 1.7, 1000.0, -1640.0, 10.0, 0.55, &"blight", 70.0],
	# From above, to read the whole shape.
	"air_west": [-400.0, 300.0, 420.0, -1300.0, -400.0, 0.0, 0.45, &"spring", 75.0],
	"air_north": [200.0, -300.0, 420.0, 100.0, -1300.0, 0.0, 0.45, &"spring", 75.0],
	"air_vale": [600.0, 300.0, 300.0, 1100.0, 1000.0, 0.0, 0.45, &"spring", 75.0],
}


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := Array(OS.get_cmdline_user_args())
	var out_dir: String = args.pop_front() if not args.is_empty() else "user://court_shots"
	var with_regions := args.has("regions")
	args.erase("regions")
	var ingame := args.has("ingame")
	args.erase("ingame")
	var grasses: Array = []
	var lineup := ""
	var looks: Array = []
	var fogs: Array = []
	var src := ""
	for a: String in args.duplicate():
		if a.begins_with("looks="):
			looks = Array(a.substr(6).split(","))
			args.erase(a)
		elif a.begins_with("fogs="):
			fogs = Array(a.substr(5).split(","))
			args.erase(a)
		elif a.begins_with("lineup="):
			lineup = a.substr(7)
			args.erase(a)
		elif a.begins_with("grass="):
			grasses = Array(a.substr(6).split(","))
			args.erase(a)
		elif a.begins_with("src="):
			src = a.substr(4)
			args.erase(a)
	var assets_by_look := {}
	for look: String in looks:
		assets_by_look[look] = _look_assets(look, src)
	var ids: Array = args if not args.is_empty() else VIEWS.keys()
	DirAccess.make_dir_recursive_absolute(out_dir)
	Clock.paused = true
	var root := get_tree().root
	root.size = Vector2i(1920, 1080)
	var world: World = load("res://world/shared/world/world.tscn").instantiate()
	root.add_child(world)
	ShotQuality.guard_software_renderer(root, world)
	var cam := Camera3D.new()
	cam.far = 4000.0
	world.add_child(cam)
	cam.make_current()
	for id in ids:
		var v: Array = VIEWS[id]
		Clock.time_of_day = v[6]
		world.grade.swap_to(v[7], 0.0)
		var eye := Vector3(v[0], 0.0, v[1])
		eye.y = WorldHeight.height_at(eye.x, eye.z) + float(v[2])
		var at := Vector3(v[3], 0.0, v[4])
		at.y = WorldHeight.height_at(at.x, at.z) + float(v[5])
		cam.fov = v[8]
		cam.position = eye
		cam.look_at(at)
		for r in world.regions.get_children():
			r.queue_free()
		if with_regions:
			for def in _region_defs():
				if Vector2(def.center.x - eye.x, def.center.z - eye.z).length() < def.radius + 300.0:
					var scene: PackedScene = load(def.scene_path)
					if scene != null:
						world.regions.add_child(scene.instantiate())
			await _wait_regions_built(world, 120.0)
		if ingame:
			world.grade.swap_to(_grade_at(eye, v[7]), 0.0)
		if lineup != "":
			_lineup(world, eye, at, lineup, cam)
		for look: String in (looks if not looks.is_empty() else [""]):
			if look != "" and world.terrain != null:
				world.terrain.set(&"assets", assets_by_look[look])
			for fog: String in (fogs if not fogs.is_empty() else [""]):
				if fog != "":
					_apply_fog(world, _grade_at(eye, v[7]) if ingame else v[7], fog)
				for grass: String in (grasses if not grasses.is_empty() else [""]):
					if grass != "":
						_apply_grass(world, grass)
					for i in 40:
						await get_tree().process_frame
					var path := "%s/%s%s%s%s.png" % [out_dir, id, "" if look == "" else "_" + look,
						"" if fog == "" else "_" + fog, "" if grass == "" else "_grass-" + grass]
					root.get_texture().get_image().save_png(path)
					print("SHOT %s %s %s %s -> %s | grade %s | draw_calls %d" % [id, look, fog, grass, path,
						world.grade.current.id, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)])
	get_tree().quit(0)


## Model lineups: every tree or plant the court plants, in a row on the real
## ground under the real grade, with a 1.7 m post (Feyre) at each end for scale.
## `lineup=trees` stands them 60 m ahead, `lineup=plants` 9 m ahead,
## `lineup=tests` the model direction test (M1); the
## camera then stands back from the row at the row's own ground level.
const LINEUPS := {
	"trees": {"distance": 60.0, "spacing": 9.0, "look": 5.0, "ids": [&"woods_ancient_oak", &"woods_oak", &"woods_yew",
		&"woods_silver_birch", &"woods_wild_cherry", &"woods_lilac_tree", &"woods_willow", &"woods_hawthorn",
		&"woods_elder", &"woods_crab_apple", &"flora_tree_rowan", &"flora_tree_autumn_maple"]},
	"plants": {"distance": 9.0, "spacing": 1.6, "look": 0.4, "ids": [&"flora_fern_a", &"flora_fern_b", &"flora_heather_mound",
		&"flora_bush_rose", &"flora_bush_hydrangea", &"flora_carpet_rose", &"flora_carpet_butter",
		&"flora_carpet_periwinkle", &"flora_reeds_bulrush", &"flora_toadstool_ring", &"rock_mossy_a",
		&"woods_fallen_log"]},
	# The leaf-card trees: one of each species, then the five builds of the
	# oak and three of the birch and cherry.
	"species": {"distance": 62.0, "spacing": 10.0, "look": 6.0, "ids": [
		"woods_ancient_oak@0", "woods_oak@0", "woods_silver_birch@0", "woods_wild_cherry@0", "woods_crab_apple@0",
		"woods_lilac_tree@0", "woods_willow@0", "woods_hawthorn@0", "woods_elder@0", "woods_yew@0"]},
	"builds": {"distance": 62.0, "spacing": 10.0, "look": 6.0, "ids": [
		"woods_oak@0", "woods_oak@1", "woods_oak@2", "woods_oak@3", "woods_oak@4", "post",
		"woods_silver_birch@0", "woods_silver_birch@1", "woods_silver_birch@2", "post",
		"woods_wild_cherry@0", "woods_wild_cherry@1", "woods_wild_cherry@2"]},
	# Model direction test M1: today's oak, birch, cherry and yew, then the
	# same four as A (storybook deep) and B (painterly leaf cards), with a
	# post between the groups.
	"tests": {"distance": 62.0, "spacing": 11.0, "look": 6.0, "ids": [
		"now:woods_oak", "now:woods_silver_birch", "now:woods_wild_cherry", "now:woods_yew", "post",
		"a:oak", "a:silver_birch", "a:wild_cherry", "a:yew", "post",
		"b:oak", "b:silver_birch", "b:wild_cherry", "b:yew"]},
}
const TREE_TESTS := "res://world/spring_court/wider/assets/tree_tests/"


## A test tree's mesh with its materials: the woods' tree look with the teal
## guard down (the test greens are deep on purpose), and the leaf-card
## shader on B's card surface.
func _test_tree(style: String, species: String) -> Mesh:
	var scene := load("%s%s_%s.glb" % [TREE_TESTS, style, species]) as PackedScene
	var inst := scene.instantiate()
	var src: MeshInstance3D = inst.find_children("*", "MeshInstance3D", true, false)[0]
	var mesh := src.mesh.duplicate() as ArrayMesh
	inst.free()
	var wood := (FloraLibrary.material(&"tree") as ShaderMaterial).duplicate() as ShaderMaterial
	wood.set_shader_parameter(&"lime_guard", 0.15)
	var card := ShaderMaterial.new()
	card.shader = load(TREE_TESTS + "leaf_card.gdshader")
	for i in mesh.get_surface_count():
		# The card surface is the one with card coordinates in UV2 (the glTF
		# placeholder materials arrive without their names).
		var uv2: Variant = mesh.surface_get_arrays(i)[Mesh.ARRAY_TEX_UV2]
		var is_card := false
		if uv2 != null:
			for v: Vector2 in uv2:
				if v.x > 0.5:
					is_card = true
					break
		mesh.surface_set_material(i, card if is_card else wood)
	return mesh


func _lineup(world: World, eye: Vector3, at: Vector3, which: String, cam: Camera3D) -> void:
	var spec: Dictionary = LINEUPS[which]
	var fwd := Vector3(at.x - eye.x, 0.0, at.z - eye.z).normalized()
	var side := fwd.cross(Vector3.UP).normalized()
	var ids: Array = spec["ids"]
	var row := Node3D.new()
	row.name = "Lineup"
	world.add_child(row)
	var n := ids.size() + 2
	for i in n:
		var p := eye + fwd * float(spec["distance"]) + side * (float(i) - float(n - 1) * 0.5) * float(spec["spacing"])
		p.y = WorldHeight.height_at(p.x, p.z)
		var mi := MeshInstance3D.new()
		if i == 0 or i == n - 1:
			var post := CylinderMesh.new()
			post.top_radius = 0.12
			post.bottom_radius = 0.12
			post.height = 1.7
			mi.mesh = post
			p.y += 0.85
		else:
			var item := String(ids[i - 1])
			if item == "post":
				var post := CylinderMesh.new()
				post.top_radius = 0.12
				post.bottom_radius = 0.12
				post.height = 1.7
				mi.mesh = post
				p.y += 0.85
			elif item.begins_with("now:"):
				mi.mesh = CourtAssets.mesh(StringName(item.substr(4)))
			elif item.contains(":"):
				mi.mesh = _test_tree(item.get_slice(":", 0), item.get_slice(":", 1))
			else:
				mi.mesh = CourtAssets.mesh(StringName(item))  # as the court's scatter draws it
		mi.position = p
		mi.rotation.y = atan2(fwd.x, fwd.z)
		row.add_child(mi)
	var d := float(spec["distance"])
	var centre := eye + fwd * d
	centre.y = WorldHeight.height_at(centre.x, centre.z)
	var back := centre - fwd * d
	cam.position = Vector3(back.x, maxf(centre.y + 1.7 + d * 0.06, WorldHeight.height_at(back.x, back.z) + 1.7), back.z)
	cam.look_at(centre + Vector3.UP * float(spec["look"]))
	print("LINEUP %s: %s" % [which, ", ".join(ids.map(func(x): return String(x)))])


## Depth hazes for the preview: fog field -> value. "layered": a cool
## lilac-blue haze darker than the pink horizon, so far land stays land
## (background), aerial perspective low so it doesn't take the sky's colour.
## "layered_mist" adds low valley mist between the ridges (midground).
const FOGS := {
	"now": {},
	"layered": {"fog_color": Color(0.70, 0.74, 0.96), "fog_density": 0.0011, "fog_aerial_perspective": 0.1,
		"fog_sky_affect": 0.1, "volumetric_albedo": Color(0.85, 0.86, 1.0)},
	"layered_mist": {"fog_color": Color(0.70, 0.74, 0.96), "fog_density": 0.0011, "fog_aerial_perspective": 0.1,
		"fog_sky_affect": 0.1, "volumetric_albedo": Color(0.85, 0.86, 1.0), "fog_height": 30.0, "fog_height_density": 0.045},
}


## The grade the game shows at `eye`: the RegionGrade there, else `fallback`.
func _grade_at(eye: Vector3, fallback: StringName) -> StringName:
	for node in get_tree().get_nodes_in_group(RegionGrade.GROUP):
		var rg := node as RegionGrade
		if rg.contains(eye):
			return rg.grade
	return fallback


## The court's grass clumps, and the "toned" look: darker, greener and without
## the warm rim, so a tuft reads as a little sunlit grass on the storybook
## ground instead of a pale neon sprite.
const GRASS := [&"flora_grass_clump_a", &"flora_grass_clump_b", &"flora_grass_clump_c"]
const GRASS_TONED := {"albedo": Color(0.40, 0.60, 0.36), "saturation_boost": 1.0,
	"rim_strength": 0.15, "backlight_strength": 0.3, "translucency": 0.15}
var _grass_restore := {}


func _apply_grass(world: World, variant: String) -> void:
	var meshes := {}
	for id: StringName in GRASS:
		meshes[CourtAssets.mesh(id)] = id
		meshes[CourtAssets.mesh(id, true)] = id
	var toned: ShaderMaterial = null
	if variant == "toned":
		toned = (CourtAssets.material_for(GRASS[0]) as ShaderMaterial).duplicate() as ShaderMaterial
		for k: String in GRASS_TONED:
			toned.set_shader_parameter(k, GRASS_TONED[k])
	var n := 0
	for node in world.find_children("*", "MultiMeshInstance3D", true, false):
		var mmi := node as MultiMeshInstance3D
		if mmi.multimesh == null or not meshes.has(mmi.multimesh.mesh):
			continue
		if not _grass_restore.has(mmi):
			_grass_restore[mmi] = mmi.material_override
		mmi.visible = variant != "none"
		mmi.material_override = toned if toned != null else _grass_restore[mmi]
		n += 1
	print("GRASS %s on %d chunks" % [variant, n])


func _apply_fog(world: World, grade: StringName, fog: String) -> void:
	var p := (GradeDirector.load_preset(grade) as GradePreset).duplicate() as GradePreset
	for k: String in FOGS[fog]:
		p.set(k, FOGS[fog][k])
	world.grade.current = p
	world.grade.set(&"_to", p)
	world.grade.set(&"_t", 1.0)
	world.grade.apply(p)


## Terrain3D assets with the court's photo slots packed in `look` (every slot
## as uncompressed, mipmapped RGBA so the texture arrays match).
func _look_assets(look: String, src: String) -> Resource:
	var dir := "user://court_looks/%s" % look
	if look != "photo":
		DirAccess.make_dir_recursive_absolute(dir)
		var packer := GroundTexturePacker.new(look, dir)
		for slot: String in GroundTexturePacker.SOURCES:
			packer.pack(src, slot)
	var assets: Resource = ClassDB.instantiate(&"Terrain3DAssets")
	for i in TerrainSetup.TEXTURES.size():
		var stem: String = TerrainSetup.TEXTURES[i][0]
		var tex: Resource = ClassDB.instantiate(&"Terrain3DTextureAsset")
		tex.set(&"name", stem)
		for kind in ["albedo", "normal"]:
			var img: Image = null
			var own := "%s/%s_%s.png" % [dir, stem, kind]
			if look != "photo" and FileAccess.file_exists(own):
				img = Image.load_from_file(own)
			else:
				var res := ProjectSettings.globalize_path("%s/%s_%s.png" % [TerrainSetup.TEXTURE_DIR, stem, kind])
				if FileAccess.file_exists(res):
					img = Image.load_from_file(res)
			if img == null:
				continue
			if img.is_compressed():
				img.decompress()
			img.convert(Image.FORMAT_RGBA8)
			img.generate_mipmaps()
			tex.set(&"%s_texture" % kind, ImageTexture.create_from_image(img))
		tex.set(&"uv_scale", TerrainSetup.TEXTURES[i][1])
		assets.call(&"set_texture_asset", i, tex)
	return assets


func _region_defs() -> Array[RegionDef]:
	var out: Array[RegionDef] = []
	var dir := DirAccess.open("res://data/regions/spring_court")
	if dir != null:
		for f in dir.get_files():
			if f.ends_with(".tres") and not f.ends_with("_biomes.tres"):
				var def := load("res://data/regions/spring_court/" + f) as RegionDef
				if def != null:
					out.append(def)
	return out


func _wait_regions_built(world: World, cap_s: float) -> void:
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < int(cap_s * 1000.0):
		var pending := 0
		for r in world.regions.get_children():
			if &"is_built" in r and not bool(r.get(&"is_built")):
				pending += 1
		if pending == 0:
			return
		await get_tree().process_frame
