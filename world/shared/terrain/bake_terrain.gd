## Bakes the whole map's Terrain3D data from WorldHeight.
##   godot --headless -s world/shared/terrain/bake_terrain.gd
## Writes res://world/shared/terrain/data/ (gitignored). The build lane runs it
## before export; the World scene bakes in memory if the folder is empty.
extends SceneTree

const DATA_DIR := "res://world/shared/terrain/data"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var t0 := Time.get_ticks_msec()
	var terrain := TerrainSetup.make_terrain()
	terrain.data_directory = ""
	root.add_child(terrain)
	await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DATA_DIR))
	var locs := TerrainBaker.region_locations()
	for loc in locs:
		var imgs := TerrainBaker.bake_region(loc)
		TerrainSetup.import_region(terrain, loc, imgs)
		print("baked region %s (%d ms)" % [loc, Time.get_ticks_msec() - t0])
	terrain.data.save_directory(DATA_DIR)
	print("terrain bake: %d regions in %.1f s -> %s" % [locs.size(), (Time.get_ticks_msec() - t0) / 1000.0, DATA_DIR])
	quit(0)
