## Generates the Manor Estate grounds scatter and its coverage report (R1/R15).
##   godot --headless res://tools/manor_estate/gen_grounds.tscn
## (a scene, not -s: the estate's scripts use autoloads, which -s does not load).
## Writes world/spring_court/manor_estate/scatter/_generated/<layer>.tres (gitignored, the
## estate rebuilds them in memory when missing) and the coverage report
## world/spring_court/manor_estate/scatter/_generated/manor_estate_report.json, also generated
## and uncommitted: world_smoke reads the freshly built numbers.
extends Node


func _ready() -> void:
	var t := Time.get_ticks_msec()
	var layers := ManorScatter.build_all()
	var build_ms := Time.get_ticks_msec() - t
	ManorScatter.save_all(layers)
	var draws := estimate_draw_calls(layers)
	var report := ScatterReport.compute(layers, ManorSitePlan.BOUNDS, ManorGrounds.LANDMARKS.size(), draws["total"])
	var forage := 0
	var deco := 0
	var types := {}
	var ing := 0
	var col := 0
	var zones := {}
	for l in layers:
		if l.is_forage():
			forage += l.count()
			if not types.has(l.ingredient_id):
				types[l.ingredient_id] = true
				if String(l.ingredient_id).begins_with("ing_"):
					ing += 1
				elif String(l.ingredient_id).begins_with("col_"):
					col += 1
			zones[String(l.id)] = ManorScatter.zones_of(l).size()
		else:
			deco += l.count()
	report["placements"] = forage
	report["ing_types"] = ing
	report["col_types"] = col
	report["decoration_instances"] = deco
	report["layers"] = layers.size()
	report["landmark_names"] = ManorGrounds.LANDMARKS
	report["draw_calls_breakdown"] = draws
	report["zones_per_type"] = zones
	report["scatter_build_ms"] = build_ms
	ScatterReport.save(report, ManorScatter.REPORT_PATH)
	print("manor grounds: ", JSON.stringify(report.duplicate().merged({"zones_per_type": "...", "draw_calls_breakdown": draws}, true)))
	get_tree().quit()


## Draw calls with the whole estate loaded: scatter chunk multimeshes, grounds
## meshes and prop multimeshes, particles, the house, and the terrain chunks.
static func estimate_draw_calls(layers: Array[ScatterLayer]) -> Dictionary:
	var root := Node3D.new()
	ManorGrounds.build(root)
	var grounds := count_draws(root)
	root.free()
	var house_root := Node3D.new()
	ManorHouseBuilder.build(house_root)
	var house := count_draws(house_root)
	house_root.free()
	var b := ManorSitePlan.BOUNDS
	var terrain := ceili(b.size.x / ManorTerrain.CHUNK) * ceili(b.size.y / ManorTerrain.CHUNK)
	var scatter := ManorScatter.chunk_draws(layers)
	var visible := ManorScatter.visible_chunk_draws(layers)
	# total = what the renderer draws from the worst viewpoint (scatter culled by
	# its visibility ranges); all_loaded = every chunk node with nothing culled.
	return {"scatter_chunks_loaded": scatter, "scatter_chunks_visible_max": visible[0], "worst_view": "%d,%d" % [visible[1].x, visible[1].y],
			"grounds": grounds, "house": house, "terrain": terrain,
			"all_loaded": scatter + grounds + house + terrain,
			"total": visible[0] + grounds + house + terrain}


static func count_draws(node: Node) -> int:
	var n := 0
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		n += (node as MeshInstance3D).mesh.get_surface_count()
	elif node is MultiMeshInstance3D and (node as MultiMeshInstance3D).multimesh != null and (node as MultiMeshInstance3D).multimesh.mesh != null:
		n += (node as MultiMeshInstance3D).multimesh.mesh.get_surface_count()
	elif node is GPUParticles3D:
		n += (node as GPUParticles3D).draw_passes
	for c in node.get_children():
		n += count_draws(c)
	return n
