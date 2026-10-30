## Bakes the painted world map and the scatter landmark table (R8, R15):
##   godot --headless --path . -s tools/generators/world_map.gd
## Writes ui/map/_generated/world_map.res, a MapBake (git-ignored;
## `make generate` rebuilds them). Sorts after woods_scatter.gd, so the
## woods' generated scatter is already there for the canopy.
extends SceneTree

# Preloaded by path, not by class name: `make update` runs generators before
# the import that registers new classes.
const MapArt := preload("res://ui/map/map_art.gd")
const MapBake := preload("res://ui/map/map_bake.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var t0 := Time.get_ticks_msec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MapArt.OUT_DIR))
	var bake := MapBake.new()
	bake.metres_per_pixel = MapArt.BAKE_METRES_PER_PIXEL
	bake.image = MapArt.build(MapArt.BAKE_METRES_PER_PIXEL)
	bake.landmarks = MapArt.scatter_landmarks()
	var err := ResourceSaver.save(bake, MapArt.BAKE_PATH, ResourceSaver.FLAG_COMPRESS)
	if err != OK:
		push_error("world_map: could not save %s (%s)" % [MapArt.BAKE_PATH, error_string(err)])
		quit(1)
		return
	var image := bake.image
	var landmarks := bake.landmarks
	print("world_map: %dx%d px at %.0f m/px, %d scatter landmarks, %.1f s -> %s" % [
		image.get_width(), image.get_height(), MapArt.BAKE_METRES_PER_PIXEL,
		landmarks.size(), (Time.get_ticks_msec() - t0) / 1000.0, MapArt.OUT_DIR])
	quit(0)
