## Prints the court's terrain habitats (CourtLandHabitats, finish plan P1):
## each region's share of every landform on a 16 m grid, and how long a query
## takes. tools/mq/godot.sh -s tools/court/court_habitat_report.gd [step=16]
extends SceneTree


func _initialize() -> void:
	var step := 16.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("step="):
			step = float(a.substr(5))
	CourtHeight.prewarm()
	var header := "region".rpad(18)
	for n: StringName in CourtLandHabitats.NAMES:
		header += String(n).substr(0, 7).lpad(8)
	header += "   open"
	print(header)
	var t0 := Time.get_ticks_usec()
	var queries := 0
	for id in CourtMap.region_ids():
		var counts := PackedInt32Array()
		counts.resize(CourtLandHabitats.NAMES.size())
		var total := 0
		var open := 0
		for r in CourtMap.rects(id):
			var x := r.position.x + step * 0.5
			while x < r.end.x:
				var z := r.position.y + step * 0.5
				while z < r.end.y:
					if CourtMap.region_at(x, z) == id:
						counts[CourtLandHabitats.form_at(x, z)] += 1
						if CourtLandHabitats.keep_open(x, z):
							open += 1
						total += 1
						queries += 1
					z += step
				x += step
		var line := String(id).rpad(18)
		for c in counts:
			line += ("%.1f" % (100.0 * c / maxf(total, 1.0))).lpad(8)
		line += ("%.1f" % (100.0 * open / maxf(total, 1.0))).lpad(7)
		print(line)
	var us := Time.get_ticks_usec() - t0
	print("%d points, %.1f us per point (form + keep_open)" % [queries, float(us) / maxf(queries, 1.0)])
	print("keep-open zones: %d" % CourtLandHabitats.zones().size())
	quit()
