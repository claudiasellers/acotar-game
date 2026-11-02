## Timing probe for the manor façade (L42 dev tool): builds the house headless
## and prints how long the façade plan takes and its piece counts.
## Run: godot --headless --path . -s tools/manor_estate/facade_probe.gd
extends SceneTree


func _init() -> void:
	var t0 := Time.get_ticks_msec()
	var all := ManorHouseIndex.new(ManorHouseBuilder.load_layouts())
	var t1 := Time.get_ticks_msec()
	var runs := ManorFacade.outer_runs(all)
	var t2 := Time.get_ticks_msec()
	print("index %d ms, runs %d in %d ms" % [t1 - t0, runs.size(), t2 - t1])
	var holder := Node3D.new()
	root.add_child(holder)
	var house := ManorHouseBuilder.build(holder)
	var t3 := Time.get_ticks_msec()
	print("house build %d ms, windows %d" % [t3 - t2, (house.get_meta(&"facade_windows", []) as Array).size()])
	var plan := ManorFacade.placements(all, house.get_meta(&"facade_windows", []))
	print("plan %d ms" % [Time.get_ticks_msec() - t3])
	for id in ManorFacade.PIECES:
		print("  %s %d" % [id, (plan[id] as Array).size()])
	print("  panes %d" % (plan.panes as Array).size())
	quit()
