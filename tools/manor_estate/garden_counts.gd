## Headless count of scatter placements per layer inside the garden areas (L35),
## to keep forage counts steady and report what the gardens add.
##   godot --headless res://tools/manor_estate/garden_counts.tscn
extends Node


func _ready() -> void:
	var areas := {"rose_garden": ManorSitePlan.ROSE_GARDEN, "estate": ManorSitePlan.BOUNDS}
	var layers := ManorScatter.build_all()
	var out := {}
	for l in layers:
		var row := {}
		for name: String in areas:
			var r: Rect2 = areas[name]
			var n := 0
			for i in l.count():
				var p := l.position_of(i)
				if r.has_point(Vector2(p.x, p.z)):
					n += 1
			row[name] = n
		out[String(l.id)] = row
	print("GARDEN_COUNTS ", JSON.stringify(out))
	# GARDEN_PROBE="x,z,r": which layers have placements near a point
	var probe := OS.get_environment("GARDEN_PROBE").split(",")
	if probe.size() == 3:
		var at := Vector2(float(probe[0]), float(probe[1]))
		var near := {}
		for l in layers:
			for i in l.count():
				var p := l.position_of(i)
				if Vector2(p.x, p.z).distance_to(at) < float(probe[2]):
					near[String(l.id)] = int(near.get(String(l.id), 0)) + 1
		print("GARDEN_PROBE ", JSON.stringify(near))
	get_tree().quit()
