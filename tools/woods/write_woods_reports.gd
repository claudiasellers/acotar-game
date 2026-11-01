## Regenerates the woods regions' coverage reports (docs/contracts/world.md §5):
##   godot --headless -s tools/woods/write_woods_reports.gd
## Writes world/spring_court/<id>/_generated/<id>_report.json (git-ignored; the
## woods_reports recipe in tools/mq/generated.conf runs it after woods_scatter,
## so world_smoke reads numbers from the merged tree).
## Prints one line per region. Deterministic: same seeds, same numbers, in
## any build order. `-- --dry-run [region ...]` builds those regions in that
## order and only prints (tests/integration/test_woods_build_order.gd).
extends SceneTree

const REGIONS := [&"border_woods", &"eastern_woods", &"suriel_glade"]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var dry := args.has("--dry-run")
	var order: Array = REGIONS
	if args.size() > (1 if dry else 0):
		order = Array(args).filter(func(a: String) -> bool: return a != "--dry-run")
	for id in order:
		var scene: PackedScene = load("res://world/spring_court/%s/%s.tscn" % [id, id])
		var region := scene.instantiate() as WoodsRegion
		region.build_terrain_fallback = false
		region.build_ground_cover = false
		region.build_ambient_life = false
		region.use_cache = not dry  # the test measures generation, not a baked cache
		root.add_child(region)
		region.build_now()
		var report := region.coverage_report()
		if not dry:
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://world/spring_court/%s/_generated" % id))
			ScatterReport.save(report, "res://world/spring_court/%s/_generated/%s_report.json" % [id, id])
		print("%s %s" % [id, JSON.stringify(report)])
		region.free()
	quit()
