## Regenerates the woods regions' coverage reports (docs/contracts/world.md §5):
##   godot --headless -s tools/woods/write_woods_reports.gd
## Prints one line per region. Deterministic: same seeds, same numbers.
extends SceneTree

const REGIONS := [&"border_woods", &"eastern_woods", &"suriel_glade"]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for id in REGIONS:
		var scene: PackedScene = load("res://world/spring_court/%s/%s.tscn" % [id, id])
		var region := scene.instantiate() as WoodsRegion
		region.build_terrain_fallback = false
		region.build_ground_cover = false
		region.build_ambient_life = false
		root.add_child(region)
		region.build_now()
		var report := region.coverage_report()
		ScatterReport.save(report, "res://world/spring_court/%s/%s_report.json" % [id, id])
		print("%s %s" % [id, JSON.stringify(report)])
		region.free()
	quit()
