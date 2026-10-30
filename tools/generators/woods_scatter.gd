## Bakes each woods region's scatter and terrain stand-in into
## world/spring_court/<id>/_generated/woods_cache.res (git-ignored, R15), so
## streaming a region in only loads data. Run by `make update`:
##   godot --headless -s tools/generators/woods_scatter.gd
## Deterministic: same seeds and terrain, same cache. A region whose inputs
## changed since the bake sees a fingerprint mismatch and generates instead.
extends SceneTree

const REGIONS := [&"border_woods", &"eastern_woods", &"suriel_glade"]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var failed := false
	for id: StringName in REGIONS:
		var scene: PackedScene = load("res://world/spring_court/%s/%s.tscn" % [id, id])
		var region := scene.instantiate() as WoodsRegion
		var def := region.def
		region.free()
		var t := Time.get_ticks_msec()
		var cache := WoodsRegion.generate_cache(def, WoodsScatterCache.fingerprint_for(def))
		var path := WoodsScatterCache.path_for(id)
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
		var err := ResourceSaver.save(cache, path, ResourceSaver.FLAG_COMPRESS)
		if err != OK:
			push_error("woods_scatter: could not save %s (%s)" % [path, error_string(err)])
			failed = true
		else:
			print("woods_scatter: %s baked in %d ms" % [id, Time.get_ticks_msec() - t])
	quit(1 if failed else 0)
