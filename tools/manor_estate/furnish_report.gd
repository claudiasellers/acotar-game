## Prints the refurnish numbers for every manor room (ManorFurnishMetrics).
## Run: tools/mq/godot.sh -s tools/manor_estate/furnish_report.gd [-- all]
## Without "all", only the rooms in ManorFurnishMetrics.REFURNISHED.
extends SceneTree


func _init() -> void:
	var all_rooms := OS.get_cmdline_user_args().has("all")
	var ground := load(ManorLayoutDSL.OUT_DIR + "ground.tres") as ManorHouseLayout
	var ctx := ManorFurnishContext.new(ground)
	var stations: Array = ctx.index.stations
	print("room                      area  cover/want  det/need  bare  doors  reach  story  art  open  repeats")
	var fails := 0
	for r in ctx.index.interior_rooms():
		if not all_rooms and not ManorFurnishMetrics.REFURNISHED.has(r.id):
			continue
		var m := ManorFurnishMetrics.measure(r, ctx, stations)
		var bad: bool = not m.ok_coverage or not m.ok_details or not m.repeats.is_empty() or m.blocked_doors > 0 \
				or m.unreachable_doors > 0 or not m.story_hits.is_empty() or (not m.passage and m.bare_cells > 0) or not m.ok_open
		fails += 1 if bad else 0
		print("%s %-24s %5.0f  %4.1f/%-4.1f%%  %3d/%-3d  %2d/%-2d  %4d  %5d  %5d  %3d  %4.1f  %s" % [
			"!" if bad else " ", r.id, m.area, m.coverage * 100.0, m.want_coverage * 100.0, m.details, m.need_details, m.bare_cells, m.cells,
			m.blocked_doors, m.unreachable_doors, m.story_hits.size(), m.art_slots, m.open, ", ".join(m.repeats)])
		if not m.ok_open:
			print("      open floor %.1f m round local %s" % [m.open, m.open_at])
		if bad and not m.passage and m.bare_cells > 0:
			print("      bare (local centres): ", m.bare_list)
		if m.blocked_doors > 0:
			print("      doors blocked by: ", m.blockers)
		for h in m.story_hits:
			print("      story: ", h)
	print("rooms failing the bar: %d" % fails)
	quit()
