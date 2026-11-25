## Checks the ground under every hostile site (lane L91): no core or home point
## in a river or brook bed, and no home point or camp piece on a slope steeper
## than MAX_SLOPE. Reads WorldHeight only, so it needs no terrain bake.
## The naga's own camps may sit in the water (the marsh, the weir), so the bed
## rule is for the other families.
## Run: tools/mq/godot.sh res://tools/creatures/site_ground_probe.tscn
## Exit 1 lists the sites to move (in tools/creatures/site_layout.py).
extends Node

const SITES_DIR := "res://data/creatures/hostile_sites/"
const MAX_SLOPE := 35.0


func _ready() -> void:
	var bad := 0
	var worst := 0.0
	var names := DirAccess.get_files_at(SITES_DIR)
	for file in names:
		if not file.ends_with(".tres"):
			continue
		var d := load(SITES_DIR + file) as HostileSiteData
		if d == null:
			continue
		var points: Array[Vector2] = [d.core]
		for i in d.count:
			points.append(d.home_point(i))
		for k in 8:
			points.append(d.core + Vector2.from_angle(TAU * k / 8.0) * 12.0)
		var why: Array[String] = []
		var site_worst := 0.0
		for p in points:
			var slope := WorldHeight.slope_at(p.x, p.y)
			site_worst = maxf(site_worst, slope)
			if slope > MAX_SLOPE:
				why.append("%.0f deg at (%.0f, %.0f)" % [slope, p.x, p.y])
			if d.family != &"naga" and WorldHeight.texture_at(p.x, p.y).x == WorldHeight.Tex.RIVERBED:
				why.append("in a bed at (%.0f, %.0f)" % [p.x, p.y])
		worst = maxf(worst, site_worst)
		if site_worst > MAX_SLOPE * 0.85:
			print("steep %s: %.1f deg" % [d.id, site_worst])
		if not why.is_empty():
			bad += 1
			print("BAD %s: %s" % [d.id, ", ".join(why.slice(0, 3))])
	print("ground probe: %d sites, %d bad, steepest %.1f deg" % [names.size(), bad, worst])
	get_tree().quit(1 if bad > 0 else 0)
