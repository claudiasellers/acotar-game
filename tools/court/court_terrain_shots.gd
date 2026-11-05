## Bare-terrain views of the wider court (no region content: the land itself,
## stripped of every model), several per run so the World loads once. Needs a
## GPU (the Mac's shot listener):
##   godot res://tools/court/court_terrain_shots.tscn -- <out dir> [view ids...] [regions]
##        [looks=photo,soft,pastel,storybook src=<folder of Poly Haven 1k maps>]
## `regions` also loads the region scenes near each view (models back in).
## `looks` previews ground looks without committing textures: each look is
## packed at run time by tools/court/pack_ground_textures.gd and swapped onto
## the terrain; "photo" is what the game ships. Files: <view>_<look>.png.
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
	var looks: Array = []
	var src := ""
	for a: String in args.duplicate():
		if a.begins_with("looks="):
			looks = Array(a.substr(6).split(","))
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
		for look: String in (looks if not looks.is_empty() else [""]):
			if look != "" and world.terrain != null:
				world.terrain.set(&"assets", assets_by_look[look])
			for i in 40:
				await get_tree().process_frame
			var path := "%s/%s%s.png" % [out_dir, id, "" if look == "" else "_" + look]
			root.get_texture().get_image().save_png(path)
			print("SHOT %s %s -> %s | draw_calls %d" % [id, look, path, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)])
	get_tree().quit(0)


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
