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
## `luts=now,deep,green,both` previews the grade's colour ramp (finish plan C1)
## on an in-memory copy of the grade at the eye: deep lowers the dark end
## (the milky glen), green takes the blue cast out of the dark and middle stops
## (the teal Western Woods); files <view>_lut-<variant>.png. Every shot prints
## the ramp's dark stop and the ground's mean colour and hue (the lower band).
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
	"vale_rim": [734.0, 707.0, 1.7, 1000.0, 1000.0, -10.0, 0.5, &"spring", 70.0],  # just past the vale gate (not in its lock)
	"tower_hill": [-1630.0, -650.0, 1.7, -900.0, -300.0, -60.0, 0.4, &"spring", 70.0],
	"western_woods": [-1500.0, 900.0, 1.7, -1700.0, 700.0, 4.0, 0.45, &"spring", 70.0],
	"west_brink": [-1782.0, 180.0, 1.7, -1990.0, 160.0, 40.0, 0.62, &"spring", 70.0],
	"sealed_pass": [-900.0, -1180.0, 1.7, -900.0, -1300.0, 10.0, 0.6, &"spring", 70.0],
	"reaches": [1450.0, -1250.0, 1.7, 1000.0, -1640.0, 10.0, 0.55, &"blight", 70.0],
	# The estate's trees (finish plan D2/E2): a parkland grove on the south
	# lawns, the oaks and birches of the north hills from the deer park, the
	# walled orchard's rows, the pond willows.
	"estate_lawns": [-30.0, 165.0, 1.7, -130.0, 245.0, 4.0, 0.45, &"manor", 70.0],
	"estate_north": [40.0, -300.0, 1.7, -40.0, -470.0, 8.0, 0.45, &"manor", 70.0],
	"estate_orchard": [-160.0, 150.0, 14.0, -250.0, 155.0, 0.0, 0.45, &"manor", 70.0],
	"estate_avenue": [9.0, 285.0, 1.7, 0.0, 60.0, 4.0, 0.45, &"manor", 70.0],
	"estate_air": [0.0, 320.0, 90.0, -60.0, -120.0, 0.0, 0.45, &"manor", 70.0],
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
	var luts: Array = []
	var src := ""
	var forest := ""
	for a: String in args.duplicate():
		if a.begins_with("--perf-"):
			args.erase(a)  # tools/perf/frame_probe.tscn's own settings
		elif a.begins_with("forest="):
			forest = a.substr(7)
			args.erase(a)
		elif a.begins_with("looks="):
			looks = Array(a.substr(6).split(","))
			args.erase(a)
		elif a.begins_with("fogs="):
			fogs = Array(a.substr(5).split(","))
			args.erase(a)
		elif a.begins_with("luts="):
			luts = Array(a.substr(5).split(","))
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
		if forest != "":
			_forest(world, eye, forest)
		for look: String in (looks if not looks.is_empty() else [""]):
			if look != "" and world.terrain != null:
				world.terrain.set(&"assets", assets_by_look[look])
			for fog: String in (fogs if not fogs.is_empty() else [""]):
				if fog != "":
					_apply_fog(world, _grade_at(eye, v[7]) if ingame else v[7], fog)
				for grass: String in (grasses if not grasses.is_empty() else [""]):
					if grass != "":
						_apply_grass(world, grass)
					for lut: String in (luts if not luts.is_empty() else [""]):
						if lut != "":
							_apply_lut(world, _grade_at(eye, v[7]) if ingame else v[7], lut)
						for i in 40:
							await get_tree().process_frame
						var path := "%s/%s%s%s%s%s.png" % [out_dir, id, "" if look == "" else "_" + look,
							"" if fog == "" else "_" + fog, "" if grass == "" else "_grass-" + grass,
							"" if lut == "" else "_lut-" + lut]
						var img := root.get_texture().get_image()
						img.save_png(path)
						print("SHOT %s %s %s %s %s -> %s | grade %s | draw_calls %d | %s" % [id, look, fog, grass, lut, path,
							world.grade.current.id, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
							_colour_read(world.grade.current as GradePreset, img)])
	get_tree().quit(0)


## Model lineups: every tree or plant the court plants, in a row on the real
## ground under the real grade, with a 1.7 m post (Feyre) at each end for scale.
## `lineup=trees` stands them 60 m ahead, `lineup=plants` 9 m ahead,
## `lineup=species` / `lineup=builds` the court's leaf-card trees; the
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
	# Tree exploration (owner, 2026-11-10): today's leaf-card oak and birch for
	# reference, then EZ-Tree's trees with their photo leaves and repainted.
	"explore": {"distance": 66.0, "spacing": 10.5, "look": 6.0, "ids": [
		"woods_oak@1", "woods_silver_birch@1", "post",
		"ez:oak_a:photo", "ez:oak_a:painted", "ez:oak_b:painted", "ez:ash_a:photo", "ez:ash_a:painted",
		"ez:ash_b:painted", "ez:aspen_a:painted", "ez:pine_a:painted", "ez:bush_a:painted", "ez:bush_b:painted"]},
	# Exploration 2: the leaf-card oak, EZ-Tree's oak and ash (repainted), and
	# Quaternius' Stylized Nature MegaKit trees and bushes as delivered.
	"explore2": {"distance": 66.0, "spacing": 10.0, "look": 6.0, "ids": [
		"woods_oak@1", "ez:oak_a:painted", "ez:ash_a:painted", "post",
		"scene:qtz/CommonTree_1.gltf:12", "scene:qtz/CommonTree_2.gltf:12", "scene:qtz/CommonTree_3.gltf:14",
		"scene:qtz/CommonTree_4.gltf:14", "scene:qtz/CommonTree_5.gltf:11", "scene:qtz/Pine_1.gltf:12",
		"scene:qtz/Pine_4.gltf:15", "scene:qtz/TwistedTree_1.gltf:15", "scene:qtz/Bush_Common.gltf:2.5",
		"scene:qtz/Bush_Common_Flowers.gltf:2.5"]},
	# One Quaternius tree as delivered, then tinted two ways (owner asked).
	"tint": {"distance": 26.0, "spacing": 13.0, "look": 6.0, "ids": [
		"scene:qtz/CommonTree_3.gltf:13", "scene:qtz/CommonTree_3.gltf:13:spring", "scene:qtz/CommonTree_3.gltf:13:deep"]},
	# The mixed set side by side, all in the court palette.
	"mix": {"distance": 60.0, "spacing": 10.0, "look": 6.0, "ids": [
		"scene:qtz/CommonTree_1.gltf:12:deep", "scene:qtz/CommonTree_3.gltf:14:deep", "scene:qtz/CommonTree_4.gltf:14:deep",
		"scene:qtz/TwistedTree_1.gltf:15:deep", "ez:oak_a:painted", "ez:oak_b:painted", "ez:ash_a:painted",
		"ez:ash_b:painted", "ez:aspen_a:painted", "scene:qtz/Bush_Common.gltf:2.4:deep", "ez:bush_b:painted"]},
	# Finish plan T1: each EZ tree with its photo leaves and bark, then with the
	# painted ones that replace them (assets/trees/ez/), side by side.
	"intake": {"distance": 44.0, "spacing": 9.0, "look": 6.0, "ids": [
		"ez:oak_a:painted", "ez:oak_a:painted:intake", "post", "ez:ash_a:painted", "ez:ash_a:painted:intake", "post",
		"ez:aspen_a:painted", "ez:aspen_a:painted:intake", "post", "ez:pine_a:painted", "ez:pine_a:painted:intake", "post",
		"ez:bush_b:painted", "ez:bush_b:painted:intake"]},
	# Every build in the intake folder, painted textures, Quaternius in the deep tint.
	"intake_all": {"distance": 80.0, "spacing": 9.0, "look": 6.0, "ids": [
		"ez:oak_a:painted:intake", "ez:oak_b:painted:intake", "ez:oak_c:painted:intake", "ez:oak_d:painted:intake",
		"ez:ash_a:painted:intake", "ez:ash_b:painted:intake", "ez:ash_c:painted:intake", "ez:ash_d:painted:intake",
		"ez:aspen_a:painted:intake", "ez:aspen_b:painted:intake", "ez:aspen_c:painted:intake", "ez:aspen_d:painted:intake",
		"ez:pine_a:painted:intake", "ez:pine_b:painted:intake", "ez:pine_c:painted:intake",
		"ez:dead_a:painted:intake", "ez:dead_b:painted:intake", "ez:dead_c:painted:intake",
		"ez:bush_a:painted:intake", "ez:bush_b:painted:intake", "ez:bush_c:painted:intake", "post",
		"scene:qtz/CommonTree_1.gltf:12:deep", "scene:qtz/CommonTree_2.gltf:12:deep", "scene:qtz/CommonTree_3.gltf:14:deep",
		"scene:qtz/CommonTree_4.gltf:14:deep", "scene:qtz/CommonTree_5.gltf:11:deep", "scene:qtz/TwistedTree_1.gltf:15:deep",
		"scene:qtz/TwistedTree_3.gltf:15:deep", "scene:qtz/Pine_1.gltf:12:deep", "scene:qtz/Pine_4.gltf:14:deep",
		"scene:qtz/Bush_Common.gltf:2.4:deep", "scene:qtz/Bush_Common_Flowers.gltf:2.4:deep"]},
	# Finish plan T8: every role of the court's tree set (CourtTreeSet) as the
	# game draws it, a few builds each; roles_green the woods, roles_colour the
	# blossom, autumn and blight. tree_steps: near, mid and far of four builds.
	"roles_green": {"distance": 46.0, "spacing": 6.0, "look": 5.0, "ids": ["set:woods_oak:0", "set:woods_oak:3", "set:woods_oak:5", "set:woods_oak:9", "post", "set:woods_ancient_oak:0", "set:woods_ancient_oak:2", "set:woods_ancient_oak:4", "post", "set:woods_silver_birch:0", "set:woods_silver_birch:3", "post", "set:woods_yew:0", "set:woods_yew:2", "set:woods_yew:5", "post", "set:woods_hawthorn:0", "set:woods_hawthorn:1", "post", "set:woods_elder:0", "set:woods_elder:2"]},
	"roles_colour": {"distance": 46.0, "spacing": 6.0, "look": 4.0, "ids": ["set:woods_wild_cherry:0", "set:woods_wild_cherry:2", "post", "set:woods_crab_apple:0", "set:woods_crab_apple:1", "post", "set:woods_lilac_tree:0", "set:woods_lilac_tree:1", "set:woods_lilac_tree:2", "post", "set:flora_tree_autumn_oak:0", "set:flora_tree_autumn_oak:2", "post", "set:flora_tree_autumn_maple:0", "set:flora_tree_autumn_maple:2", "post", "set:flora_tree_golden_birch:0", "set:flora_tree_golden_birch:2", "post", "set:flora_tree_rowan:0", "set:flora_tree_rowan:1", "post", "set:woods_blighted_tree:0", "set:woods_blighted_tree:5", "post", "set:woods_twisted_dead:2", "set:woods_twisted_dead:7"]},
	"tree_steps": {"distance": 34.0, "spacing": 6.5, "look": 5.0, "ids": ["set:woods_oak:5:0", "set:woods_oak:5:1", "set:woods_oak:5:2", "post", "set:woods_oak:0:0", "set:woods_oak:0:1", "set:woods_oak:0:2", "post", "set:woods_ancient_oak:0:0", "set:woods_ancient_oak:0:1", "set:woods_ancient_oak:0:2", "post", "set:woods_wild_cherry:0:0", "set:woods_wild_cherry:0:1", "set:woods_wild_cherry:0:2"]},
	# The estate's cotton-candy trees, every build (finish plan D2/E2):
	# estate:<species>:<build> is FloraLib.mesh() as the estate draws it.
	"estate_green": {"distance": 60.0, "spacing": 10.0, "look": 6.0, "ids": ["estate:oak:0", "estate:oak:1", "estate:oak:2", "post",
		"estate:birch:0", "estate:birch:1", "estate:birch:2", "post", "estate:willow:0", "estate:willow:1", "estate:willow:2", "post",
		"estate:pear_tree:0", "estate:pear_tree:1", "estate:pear_tree:2"]},
	"estate_blossom": {"distance": 34.0, "spacing": 7.0, "look": 3.5, "ids": ["estate:cherry_blossom:0", "estate:cherry_blossom:1",
		"estate:cherry_blossom:2", "post", "estate:apple_blossom:0", "estate:apple_blossom:1", "estate:apple_blossom:2", "post",
		"estate:crab_apple:0", "estate:crab_apple:1", "estate:crab_apple:2"]},
	# Estate tree options (owner 2026-11-11, "show me an option of both 1 and
	# 2"): today's tree, then option 1 (candy_ez: the court's EZ tree in the
	# estate's colours), then option 2 (hybrid: EZ branches wearing candy puffs).
	"candy_green": {"distance": 58.0, "spacing": 11.0, "look": 6.5, "ids": ["estate:oak:0", "candy_ez:oak", "hybrid:oak", "post",
		"estate:birch:0", "candy_ez:birch", "hybrid:birch"]},
	"candy_blossom": {"distance": 30.0, "spacing": 7.5, "look": 3.2, "ids": ["estate:cherry_blossom:0", "candy_ez:cherry_blossom",
		"hybrid:cherry_blossom", "post", "estate:apple_blossom:0", "candy_ez:apple_blossom", "hybrid:apple_blossom"]},
	# The Quaternius ground plants and flowers (finish plan F1/G1), as delivered.
	"qtz_plants": {"distance": 4.5, "spacing": 0.75, "look": 0.4, "ids": ["scene:/plants/qtz/Grass_Common_Short.gltf:0.35:fit", "scene:/plants/qtz/Grass_Common_Tall.gltf:0.6:fit", "scene:/plants/qtz/Grass_Wispy_Short.gltf:0.4:fit", "scene:/plants/qtz/Grass_Wispy_Tall.gltf:0.7:fit", "scene:/plants/qtz/Clover_1.gltf:0.15:fit", "scene:/plants/qtz/Clover_2.gltf:0.18:fit", "scene:/plants/qtz/Fern_1.gltf:0.8:fit", "scene:/plants/qtz/Flower_3_Single.gltf:0.45:fit", "scene:/plants/qtz/Flower_3_Group.gltf:0.5:fit", "scene:/plants/qtz/Flower_4_Single.gltf:0.45:fit", "scene:/plants/qtz/Flower_4_Group.gltf:0.5:fit", "scene:/plants/qtz/Mushroom_Common.gltf:0.25:fit", "scene:/plants/qtz/Mushroom_Laetiporus.gltf:0.35:fit"]},
	# The re-downloaded Quaternius trees: twisted oaks and pines in the deep tint,
	# the dead trees as delivered.
	"newtrees": {"distance": 70.0, "spacing": 10.0, "look": 6.0, "ids": ["scene:/trees/qtz/TwistedTree_2.gltf:15:deep", "scene:/trees/qtz/TwistedTree_4.gltf:15:deep", "scene:/trees/qtz/TwistedTree_5.gltf:15:deep", "scene:/trees/qtz/Pine_2.gltf:13:deep", "scene:/trees/qtz/Pine_3.gltf:14:deep", "scene:/trees/qtz/Pine_5.gltf:9:deep", "scene:/trees/qtz/DeadTree_1.gltf:11", "scene:/trees/qtz/DeadTree_2.gltf:12", "scene:/trees/qtz/DeadTree_3.gltf:11", "scene:/trees/qtz/DeadTree_4.gltf:10", "scene:/trees/qtz/DeadTree_5.gltf:9"]},
	# Florals test (F1): EZ flowering shrubs among the mixed wood's trees.
	"bloom": {"distance": 11.0, "spacing": 3.0, "look": 1.4, "ids": [
		"ez:rose_a", "ez:rose_b", "ez:wildrose_a", "ez:lilac_a", "ez:hydrangea_a", "ez:hydrangea_b",
		"ez:wildrose_b", "ez:lilac_b"]},
	# The same shrubs further off, with the mixed wood's trees for scale.
	"bloom_far": {"distance": 26.0, "spacing": 5.0, "look": 2.5, "ids": [
		"scene:qtz/CommonTree_3.gltf:12:deep", "ez:rose_a", "ez:wildrose_a", "ez:lilac_a", "ez:hydrangea_a",
		"ez:rose_b", "ez:lilac_b", "ez:wildrose_b", "ez:oak_a:painted"]},
	"builds": {"distance": 62.0, "spacing": 10.0, "look": 6.0, "ids": [
		"woods_oak@0", "woods_oak@1", "woods_oak@2", "woods_oak@3", "woods_oak@4", "post",
		"woods_silver_birch@0", "woods_silver_birch@1", "woods_silver_birch@2", "post",
		"woods_wild_cherry@0", "woods_wild_cherry@1", "woods_wild_cherry@2"]},
}


## EZ-Tree previews (world/spring_court/wider/assets/tree_explore): name ->
## [leaf texture, bark texture, height in metres].
const EZ_DIR := "res://world/spring_court/wider/assets/tree_explore/"
const EZ_TREES := {
	"oak_a": ["oak", "oak", 13.0], "oak_b": ["oak", "oak", 16.0], "ash_a": ["ash", "oak", 13.0],
	"ash_b": ["ash", "oak", 9.0], "aspen_a": ["aspen", "birch", 14.0], "pine_a": ["pine", "pine", 13.0],
	"bush_a": ["oak", "oak", 3.0], "bush_b": ["ash", "oak", 2.6],
	# Finish plan T1 (assets/trees/ez/ only).
	"oak_c": ["oak", "oak", 13.0], "oak_d": ["oak", "oak", 17.0], "ash_c": ["ash", "oak", 14.0],
	"ash_d": ["ash", "oak", 10.0], "aspen_b": ["aspen", "birch", 14.0], "aspen_c": ["aspen", "birch", 13.0],
	"aspen_d": ["aspen", "birch", 9.0], "pine_b": ["pine", "pine", 13.0], "pine_c": ["pine", "pine", 10.0],
	"bush_c": ["oak", "oak", 2.4], "dead_a": ["oak", "oak", 12.0], "dead_b": ["ash", "oak", 14.0],
	"dead_c": ["oak", "oak", 9.0],
}
const TREES_EZ := "res://world/spring_court/wider/assets/trees/ez/"
## Florals test (finish plan F1): EZ-Tree shapes wearing painted blossom sprays
## (tools/court/gen_ez_blossoms.py), drawn in their own colours. [spray, height].
const BLOOM_DIR := "res://world/spring_court/wider/assets/tree_explore/bloom/"
const BLOOMS := {
	"rose_a": ["rose", 1.6], "rose_b": ["rose", 1.9], "wildrose_a": ["wildrose", 2.2], "wildrose_b": ["wildrose", 1.8],
	"lilac_a": ["lilac", 4.2], "lilac_b": ["lilac", 3.6], "hydrangea_a": ["hydrangea", 1.4], "hydrangea_b": ["hydrangea", 1.6],
}


## Estate option 1 (preview): the court's EZ-Tree build in the estate's
## cotton-candy colours on the court tree shader: mint-sage painted bands for
## the green trees, the painted cherry and apple blossom sprays
## (gen_ez_blossoms.py) for the blossom trees, the estate's rose-taupe bark.
## species: [EZ build, leaf texture (assets/trees/ez/ or CANDY_DIR), bark, mode, palette]
const CANDY_DIR := "res://world/spring_court/manor_estate/flora/explore/"
const CANDY_EZ := {
	&"oak": ["ez_oak_a", "leaf_oak", "oak", 2, [Color(0.29, 0.55, 0.45), Color(0.45, 0.74, 0.50), Color(0.72, 0.90, 0.70)]],
	&"birch": ["ez_aspen_a", "leaf_aspen", "birch", 2, [Color(0.35, 0.62, 0.48), Color(0.57, 0.82, 0.56), Color(0.80, 0.95, 0.74)]],
	&"cherry_blossom": ["ez_ash_b", "blossom_cherry", "oak", 3, []],
	&"apple_blossom": ["ez_ash_d", "blossom_apple", "oak", 3, []],
}


func _candy_ez(sp: StringName) -> Array:
	var spec: Array = CANDY_EZ[sp]
	var inst := (load(TREES_EZ + String(spec[0]) + ".glb") as PackedScene).instantiate()
	var shader := load(CourtTreeSet.SHADER) as Shader
	var leaf_path: String = (CANDY_DIR if int(spec[3]) == 3 else TREES_EZ) + String(spec[1]) + ".png"
	var leaf := ShaderMaterial.new()
	leaf.shader = shader
	leaf.set_shader_parameter(&"mode", int(spec[3]))
	leaf.set_shader_parameter(&"tex", load(leaf_path))
	var pal: Array = spec[4]
	if not pal.is_empty():
		leaf.set_shader_parameter(&"shadow_col", pal[0])
		leaf.set_shader_parameter(&"mid_col", pal[1])
		leaf.set_shader_parameter(&"light_col", pal[2])
	var bark := ShaderMaterial.new()
	bark.shader = shader
	bark.set_shader_parameter(&"mode", 0)
	bark.set_shader_parameter(&"tex", load(TREES_EZ + "bark_%s.png" % spec[2]))
	bark.set_shader_parameter(&"bark_col", Color(0.95, 0.93, 0.90) if sp == &"birch" else Color(0.56, 0.42, 0.43))
	var out := ArrayMesh.new()
	var top := 0.0
	var st := SurfaceTool.new()
	for m: MeshInstance3D in inst.find_children("*", "MeshInstance3D", true, false):
		var xf := _local_to_root(m, inst)
		for i in m.mesh.get_surface_count():
			st.clear()
			st.create_from(m.mesh, i)
			var mat := m.mesh.surface_get_material(i)
			var is_leaf := mat != null and String(mat.resource_name).contains("leaves")
			var arr := st.commit_to_arrays()
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			for k in verts.size():
				verts[k] = xf * verts[k]
				top = maxf(top, verts[k].y)
			arr[Mesh.ARRAY_VERTEX] = verts
			out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			out.surface_set_material(out.get_surface_count() - 1, leaf if is_leaf else bark)
	inst.free()
	leaf.set_shader_parameter(&"model_height", top)
	bark.set_shader_parameter(&"model_height", top)
	return [out, FloraLib.height_of(sp) / maxf(top, 0.01)]


## [mesh, scale] for an EZ-Tree preview tree, its leaves photo or repainted.
## intake: the court's set (assets/trees/ez/) with its painted leaf and bark
## textures, in place of the exploration copies and EZ-Tree's photos.
func _ez_tree(name: String, painted: bool, intake := false) -> Array:
	var bloom := BLOOMS.has(name)
	var spec: Array = ["", "oak", BLOOMS[name][1]] if bloom else EZ_TREES[name]
	var dir := BLOOM_DIR if bloom else (TREES_EZ if intake else EZ_DIR)
	var ext := "png" if intake or bloom else "jpg"
	var inst := (load("%sez_%s.glb" % [dir, name]) as PackedScene).instantiate()
	var meshes: Array = inst.find_children("*", "MeshInstance3D", true, false)
	# One ArrayMesh from the bark and leaf meshes (the export keeps them apart).
	var st := SurfaceTool.new()
	var out := ArrayMesh.new()
	var leaf := ShaderMaterial.new()
	leaf.shader = load(EZ_DIR + "ez_leaf.gdshader")
	if bloom:
		leaf.set_shader_parameter(&"leaf_tex", load("%sblossom_%s.png" % [dir, BLOOMS[name][0]]))
	else:
		leaf.set_shader_parameter(&"leaf_tex", load("%sleaf_%s.png" % [dir, spec[0]]))
	leaf.set_shader_parameter(&"painted", 0.0 if bloom else (1.0 if painted else 0.0))
	for k: String in MIX_LEAF:
		leaf.set_shader_parameter(k, MIX_LEAF[k])
	var bark := ShaderMaterial.new()
	bark.shader = load(EZ_DIR + "qtz/qtz_tint.gdshader")
	bark.set_shader_parameter(&"is_leaf", false)
	bark.set_shader_parameter(&"tex", load("%sbark_%s.%s" % [dir, spec[1], ext]))
	bark.set_shader_parameter(&"bark_col", MIX_BARK)
	var aabb := AABB()
	for mi: MeshInstance3D in meshes:
		var m := mi.mesh
		var xf: Transform3D = mi.global_transform if mi.is_inside_tree() else _local_to_root(mi, inst)
		for i in m.get_surface_count():
			st.clear()
			st.create_from(m, i)
			var mat := m.surface_get_material(i)
			var is_leaf := mat != null and String(mat.resource_name).contains("leaves")
			if mat == null:
				is_leaf = String(mi.name).to_lower().contains("lea")
			st.set_material(leaf if is_leaf else bark)
			var arr := st.commit_to_arrays()
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			for k in verts.size():
				verts[k] = xf * verts[k]
				aabb = aabb.expand(verts[k]) if k > 0 or out.get_surface_count() > 0 else AABB(verts[k], Vector3.ZERO)
			arr[Mesh.ARRAY_VERTEX] = verts
			out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			out.surface_set_material(out.get_surface_count() - 1, leaf if is_leaf else bark)
	inst.free()
	return [out, float(spec[2]) / maxf(aabb.size.y, 0.01)]


func _local_to_root(n: Node3D, root: Node) -> Transform3D:
	var xf := n.transform
	var p := n.get_parent()
	while p != null and p != root:
		if p is Node3D:
			xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf


## Court tints for a Quaternius preview tree: leaf green, its sunlit green.
const TINTS := {
	"spring": [Color(0.42, 0.62, 0.30), Color(0.64, 0.78, 0.42)],
	"deep": [Color(0.27, 0.48, 0.30), Color(0.46, 0.64, 0.38)],
}


func _tint(inst: Node, which: String) -> void:
	var t: Array = TINTS[which]
	for mi: MeshInstance3D in inst.find_children("*", "MeshInstance3D", true, false):
		for i in mi.mesh.get_surface_count():
			# The glTF lists bark then leaves; the imported materials don't come
			# through as BaseMaterial3D here (wcterrain-26), so go by order and
			# load the pack's textures directly.
			var leaf := i == 1
			var mat := ShaderMaterial.new()
			mat.shader = load(EZ_DIR + "qtz/qtz_tint.gdshader")
			mat.set_shader_parameter(&"is_leaf", leaf)
			mat.set_shader_parameter(&"tex", load(EZ_DIR + ("qtz/Leaves_NormalTree_C.png" if leaf else "qtz/Bark_NormalTree.png")))
			var am := mi.get_active_material(i)
			print("TINT surface %d %s leaf %s" % [i, am.get_class() if am else "null", leaf])
			mat.set_shader_parameter(&"leaf_col", t[0])
			mat.set_shader_parameter(&"leaf_light", t[1])
			mi.set_surface_override_material(i, mat)


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
			elif item.begins_with("scene:") and item.get_slice_count(":") > 3:
				# Tinted: the same mesh the mixed wood draws (_qtz_mesh).
				var q := _qtz_mesh(item.get_slice(":", 1))
				var tm := MeshInstance3D.new()
				tm.mesh = q[0]
				var top := ((q[1] as Transform3D) * (q[0] as Mesh).get_aabb()).end.y
				var sc := float(item.get_slice(":", 2)) / maxf(top, 0.01)
				tm.transform = Transform3D(Basis(Vector3.UP, atan2(fwd.x, fwd.z)).scaled(Vector3.ONE * sc), p) * (q[1] as Transform3D)
				row.add_child(tm)
				continue
			elif item.begins_with("scene:"):
				# A packed model as delivered (its own materials), scaled to a height.
				var inst := (load(_asset_path(item.get_slice(":", 1))) as PackedScene).instantiate() as Node3D
				var top := 0.0
				var wide := 0.0
				for m: MeshInstance3D in inst.find_children("*", "MeshInstance3D", true, false):
					top = maxf(top, m.get_aabb().end.y)
					wide = maxf(wide, maxf(m.get_aabb().size.x, m.get_aabb().size.z))
				# ":fit" sizes a low, wide plant by its largest dimension, not its height.
				var size := maxf(top, wide) if item.ends_with(":fit") else top
				inst.scale = Vector3.ONE * float(item.get_slice(":", 2)) / maxf(size, 0.01)
				if item.get_slice_count(":") > 3 and item.get_slice(":", 3) != "fit":
					_tint(inst, item.get_slice(":", 3))
				inst.position = p
				inst.rotation.y = atan2(fwd.x, fwd.z)
				row.add_child(inst)
				continue
			elif item.begins_with("set:"):
				# The game's own tree: CourtTreeSet's build at a detail step
				# (set:<id>:<build>[:<step>]), already at the id's height.
				var step := int(item.get_slice(":", 3)) if item.get_slice_count(":") > 3 else 0
				mi.mesh = CourtTreeSet.mesh(StringName(item.get_slice(":", 1)), int(item.get_slice(":", 2)), step)
			elif item.begins_with("candy_ez:"):
				var sp := StringName(item.get_slice(":", 1))
				var ce := _candy_ez(sp)
				mi.mesh = ce[0]
				mi.scale = Vector3.ONE * float(ce[1])
			elif item.begins_with("hybrid:"):
				var sp := StringName(item.get_slice(":", 1))
				var hy := PropModels.pair(CANDY_DIR + "hybrid_%s.glb" % sp, "hybrid_%s" % sp, FloraLib.foliage_material(sp))
				mi.mesh = hy[0]
			elif item.begins_with("estate:"):
				mi.mesh = FloraLib.mesh(StringName(item.get_slice(":", 1)), int(item.get_slice(":", 2)))
			elif item.begins_with("ez:"):
				var ez := _ez_tree(item.get_slice(":", 1), item.get_slice(":", 2) == "painted", item.get_slice(":", 3) == "intake")
				mi.mesh = ez[0]
				mi.scale = Vector3.ONE * float(ez[1])
			elif item.begins_with("now:"):
				mi.mesh = CourtAssets.mesh(StringName(item.substr(4)))
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


## A frame-time stress test (plan Track M): a dense wood all round the eye,
## 150 trees a hectare out to 150 m (about a thousand trees, near and far
## meshes switched at the game's own distances), from five species. `forest=old` uses FloraLibrary's
## trees as the estate draws them, `forest=set` the court's tree set (CourtTreeSet) at its three
## detail steps. Run it under tools/perf/frame_probe.tscn for the numbers.
const FOREST_SPECIES := [&"oak", &"silver_birch", &"yew", &"wild_cherry", &"hawthorn"]
const FOREST_RADIUS := 150.0
const FOREST_PER_HA := 150.0


## The mixed wood (owner, 2026-11-10: "a mix of the EZ trees... we don't
## have to stick to one group"): Quaternius and EZ-Tree models in one court
## palette. Deeper green leaves, a soft grey-brown bark, the same on both.
const MIX_LEAF := {"shadow_col": Color(0.17, 0.32, 0.21), "mid_col": Color(0.27, 0.48, 0.30),
	"light_col": Color(0.46, 0.64, 0.38)}
const MIX_BARK := Color(0.50, 0.42, 0.36)
const MIX_TINT := "deep"
## [source, weight, height in metres]; qtz/<file> or ez:<name>.
const MIX := [
	["qtz/CommonTree_1.gltf", 3, 12.0], ["qtz/CommonTree_2.gltf", 3, 12.0], ["qtz/CommonTree_3.gltf", 3, 14.0],
	["qtz/CommonTree_4.gltf", 3, 14.0], ["qtz/CommonTree_5.gltf", 3, 11.0], ["qtz/TwistedTree_1.gltf", 1, 15.0],
	["ez:oak_a", 2, 13.0], ["ez:oak_b", 1, 16.0], ["ez:ash_a", 2, 13.0], ["ez:ash_b", 2, 9.0], ["ez:aspen_a", 2, 14.0],
	["qtz/Bush_Common.gltf", 3, 2.4], ["qtz/Bush_Common_Flowers.gltf", 2, 2.4], ["ez:bush_b", 2, 2.6],
]


## [mesh, local transform] for a Quaternius model, tinted into the court palette.
## A lineup path: "/x/y" is under the court's assets, anything else under EZ_DIR.
func _asset_path(sp: String) -> String:
	return ("res://world/spring_court/wider/assets" + sp) if sp.begins_with("/") else EZ_DIR + sp


func _qtz_mesh(file: String) -> Array:
	var inst := (load(_asset_path(file)) as PackedScene).instantiate()
	var tex_dir := _asset_path(file).get_base_dir() + "/"
	var mi: MeshInstance3D = inst.find_children("*", "MeshInstance3D", true, false)[0]
	var xf := _local_to_root(mi, inst)
	var mesh := mi.mesh.duplicate() as Mesh
	inst.free()
	var fam := "Twisted" if file.contains("Twisted") or file.contains("Bush_Common.gltf") else ("Pine" if file.contains("Pine") else "Normal")
	var leaf_tex: String = {"Twisted": "Leaves_TwistedTree_C.png", "Pine": "Leaf_Pine_C.png", "Normal": "Leaves_NormalTree_C.png"}[fam]
	var bark_tex := "Bark_TwistedTree.png" if fam == "Twisted" else "Bark_NormalTree.png"
	var t: Array = TINTS[MIX_TINT]
	for i in mesh.get_surface_count():
		var leaf := i == 1 or mesh.get_surface_count() == 1
		if file.contains("Flowers") and i == 1:
			leaf = true
		var mat := ShaderMaterial.new()
		mat.shader = load(EZ_DIR + "qtz/qtz_tint.gdshader")
		mat.set_shader_parameter(&"is_leaf", leaf)
		mat.set_shader_parameter(&"tex", load(tex_dir + (leaf_tex if leaf else bark_tex)))
		mat.set_shader_parameter(&"leaf_col", t[0])
		mat.set_shader_parameter(&"leaf_light", t[1])
		mat.set_shader_parameter(&"bark_col", MIX_BARK)
		if file.contains("Flowers") and i == 1:
			# The flowering bush's second surface is its blossom.
			mat.set_shader_parameter(&"leaf_col", Color(0.93, 0.80, 0.86))
			mat.set_shader_parameter(&"leaf_light", Color(1.0, 0.94, 0.96))
			mat.set_shader_parameter(&"tex", load(tex_dir + "Flowers.png"))
		mesh.surface_set_material(i, mat)
	return [mesh, xf]


func _forest(world: World, eye: Vector3, kind: String) -> void:
	if kind == "mix":
		_mixed_wood(world, eye)
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var buckets := {}
	var n := int(PI * FOREST_RADIUS * FOREST_RADIUS / 10000.0 * FOREST_PER_HA)
	for i in n:
		var r := sqrt(rng.randf()) * FOREST_RADIUS
		if r < 7.0:
			continue
		var a := rng.randf() * TAU
		var p := Vector3(eye.x + cos(a) * r, 0.0, eye.z + sin(a) * r)
		p.y = WorldHeight.height_at(p.x, p.z)
		var sp: StringName = FOREST_SPECIES[rng.randi() % FOREST_SPECIES.size()]
		# set: the court's tree set (CourtTreeSet), its builds and its three
		# detail steps at the game's own distances; old: FloraLibrary's trees.
		var nb := CourtTreeSet.builds(StringName("woods_" + String(sp))) if kind == "set" else 0
		var v := rng.randi() % nb if nb > 0 else 0
		var step := 0 if r < CourtTreeSet.NEAR else (1 if r < 260.0 else 2)
		if kind != "set" or nb == 0:
			step = 2 if r > 260.0 else 0
		var key := "%s@%d@%d" % [sp, v, step]
		if not buckets.has(key):
			buckets[key] = []
		buckets[key].append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.85, 1.2)), p))
	var total := 0
	for key: String in buckets:
		var sp := StringName(key.get_slice("@", 0))
		var step := int(key.get_slice("@", 2))
		var far := step == 2
		var mesh: Mesh
		if kind == "set" and CourtTreeSet.builds(StringName("woods_" + String(sp))) > 0:
			mesh = CourtTreeSet.mesh(StringName("woods_" + String(sp)), int(key.get_slice("@", 1)), step)
		else:
			mesh = FloraLibrary.far_mesh(sp) if far else FloraLibrary.mesh(sp)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		var xs: Array = buckets[key]
		mm.instance_count = xs.size()
		for i in xs.size():
			mm.set_instance_transform(i, xs[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		world.add_child(mmi)
		total += xs.size()
	print("FOREST %s: %d trees in %d batches" % [kind, total, buckets.size()])


func _mixed_wood(world: World, eye: Vector3) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var models := []
	var total_w := 0
	for m: Array in MIX:
		var mesh: Mesh
		var base := Transform3D()
		var unit := 1.0
		if String(m[0]).begins_with("ez:"):
			var ez := _ez_tree(String(m[0]).substr(3), true)
			mesh = ez[0]
			unit = float(ez[1]) / float(EZ_TREES[String(m[0]).substr(3)][2])
		else:
			var q := _qtz_mesh(m[0])
			mesh = q[0]
			base = q[1]
			var top := (base * mesh.get_aabb()).end.y
			unit = 1.0 / maxf(top, 0.01)
		models.append({"mesh": mesh, "base": base, "unit": unit, "h": float(m[2]), "xs": []})
		total_w += int(m[1])
	var n := int(PI * 120.0 * 120.0 / 10000.0 * 120.0)
	for i in n:
		var r := sqrt(rng.randf()) * 120.0
		if r < 8.0:
			continue
		var a := rng.randf() * TAU
		var p := Vector3(eye.x + cos(a) * r, 0.0, eye.z + sin(a) * r)
		p.y = WorldHeight.height_at(p.x, p.z)
		var pick := rng.randi() % total_w
		var k := 0
		while pick >= int(MIX[k][1]):
			pick -= int(MIX[k][1])
			k += 1
		var md: Dictionary = models[k]
		var sc := float(md["h"]) * float(md["unit"]) * rng.randf_range(0.8, 1.2)
		md["xs"].append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * sc), p) * (md["base"] as Transform3D))
	var count := 0
	for md: Dictionary in models:
		var xs: Array = md["xs"]
		if xs.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = md["mesh"]
		mm.instance_count = xs.size()
		for i in xs.size():
			mm.set_instance_transform(i, xs[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		world.add_child(mmi)
		count += xs.size()
	print("FOREST mix: %d trees and bushes from %d models" % [count, models.size()])


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


## The grade's ramp with the dark end lowered and/or the blue cast taken out.
## deep: dark stop x LUT_DEEP (about 0.1 to 0.03); green: the dark and middle
## stops' blue no higher than their red/green mean.
const LUT_DEEP := 0.3


func _apply_lut(world: World, grade: StringName, variant: String) -> void:
	var p := (GradeDirector.load_preset(grade) as GradePreset).duplicate() as GradePreset
	var gt := p.lut as GradientTexture1D
	if variant != "now" and gt != null and gt.gradient != null:
		var g := gt.gradient.duplicate() as Gradient
		var cols := g.colors
		for i in mini(cols.size(), 2):
			var c := cols[i]
			if variant == "deep" or variant == "both":
				c = c * LUT_DEEP if i == 0 else c
			if variant == "green" or variant == "both":
				c.b = minf(c.b, (c.r + c.g) * 0.5)
			c.a = 1.0
			cols[i] = c
		g.colors = cols
		var out := GradientTexture1D.new()
		out.gradient = g
		out.width = gt.width
		p.lut = out
	world.grade.current = p
	world.grade.set(&"_to", p)
	world.grade.set(&"_t", 1.0)
	world.grade.apply(p)


## "lut dark (r,g,b) | ground (r,g,b) hue h": the ramp's dark stop, and the
## mean colour of the frame's lower fifth (the ground underfoot) with its hue.
func _colour_read(p: GradePreset, img: Image) -> String:
	var dark := "none"
	var gt := p.lut as GradientTexture1D if p != null else null
	if gt != null and gt.gradient != null:
		var c := gt.gradient.colors[0]
		dark = "(%.3f,%.3f,%.3f)" % [c.r, c.g, c.b]
	var sum := Color(0, 0, 0)
	var n := 0
	var w := img.get_width()
	var h := img.get_height()
	for y in range(int(h * 0.8), h, 4):
		for x in range(0, w, 4):
			var c := img.get_pixel(x, y)
			sum += Color(c.r, c.g, c.b, 0.0)
			n += 1
	var m := Color(sum.r / n, sum.g / n, sum.b / n)
	return "lut dark %s | ground (%.3f,%.3f,%.3f) hue %.0f" % [dark, m.r, m.g, m.b, m.h * 360.0]


## Terrain3D assets with the court's photo slots packed in `look` (every slot
## as uncompressed, mipmapped RGBA so the texture arrays match).
## Moss looks (finish plan C1): the Western Woods' teal is its ground, 93% the
## moss slot (hue 160, the spring grass is 127), not the grade's ramp. These
## keep the committed textures and turn only the moss albedo's hue to this many
## degrees (value and saturation kept), so the fix can be judged in place.
const MOSS_LOOKS := {"moss_green": 128.0, "moss_olive": 110.0}


func _moss_recolour(img: Image, hue_deg: float) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			img.set_pixel(x, y, Color.from_hsv(hue_deg / 360.0, c.s, c.v, c.a))


func _look_assets(look: String, src: String) -> Resource:
	var dir := "user://court_looks/%s" % look
	var moss_hue: float = MOSS_LOOKS.get(look, -1.0)
	if moss_hue >= 0.0:
		look = "photo"  # the committed textures, but for the moss
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
			if moss_hue >= 0.0 and stem == "moss" and kind == "albedo":
				_moss_recolour(img, moss_hue)
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
