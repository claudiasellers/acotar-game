## Writes the coverage report tools/world_smoke.gd reads (RegionDef.report_path).
## A region generator calls ScatterReport.compute(...) then save(...).
class_name ScatterReport
extends RefCounted

## Size of the "something every ~100 m" cells (R1).
const CELL := 100.0


## `area` is the region's XZ rectangle. An empty cell is a 100 m cell inside
## it with no forage, collectible, landmark or look-at instance.
static func compute(layers: Array[ScatterLayer], area: Rect2, landmarks: int, draw_calls: int) -> Dictionary:
	var types := {}
	var placements := 0
	var cols := ceili(area.size.x / CELL)
	var rows := ceili(area.size.y / CELL)
	var filled := {}
	for layer in layers:
		var interesting := layer.is_forage() or layer.tags.has("collectible") or layer.tags.has("landmark") or layer.tags.has("look")
		if not interesting:
			continue
		types[layer.ingredient_id if layer.is_forage() else layer.id] = true
		placements += layer.count()
		for i in layer.count():
			var p := layer.position_of(i)
			var c := Vector2i(floori((p.x - area.position.x) / CELL), floori((p.z - area.position.y) / CELL))
			filled[c] = true
	var empty := 0
	for cx in cols:
		for cz in rows:
			if not filled.has(Vector2i(cx, cz)):
				empty += 1
	var km2 := area.get_area() / 1_000_000.0
	return {
		"types": types.size(),
		"placements_per_km2": int(round(placements / maxf(km2, 0.0001))),
		"empty_cells": empty,
		"landmarks": landmarks,
		"draw_calls": draw_calls,
	}


static func save(report: Dictionary, path: String) -> Error:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(report, "  ", false) + "\n")
	return OK
