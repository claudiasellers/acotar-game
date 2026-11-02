## Act II grounds beats for the headless playtest (tools/playtest/act1_playtest.gd
## runs these after manor_arrival). Like the rest of the playtest it only
## presses actions and turns the camera: every deed comes from the game.
##
##   10. first_dinner  walk to the dining table and eat (interact) until
##                     first_dinner_eaten (L24's scene, or the data moment)
##   11. bogge_hunt    walk the border-woods path with Lucien; frozen, keep
##                     her eyes on the elm while the Bogge passes; walk on to
##                     safety without looking back; bogge_survived
##   12. puca_gate     into the garden under her window (night comes to her);
##                     follow her father to the open gate; Tamlin stops her;
##                     look at it until it darts; puca_resisted
class_name Act2GroundsBeats
extends RefCounted

var pt: Node


func _init(playtest: Node) -> void:
	pt = playtest


## Returns false when a beat failed (the run stops there).
func play() -> bool:
	if not await _first_dinner():
		return false
	if pt._beat.id == pt.stop_after:
		return true
	if not await _bogge_hunt():
		return false
	if pt._beat.id == pt.stop_after:
		return true
	return await _puca_gate()


func _first_dinner() -> bool:
	pt._begin("first_dinner", "walk to the dining table, eat (interact) until first_dinner_eaten")
	if WorldState.has_flag("first_dinner_eaten"):
		pt._note("already eaten")
		pt._pass()
		return true
	var table := await _find_anchor(&"manor_dining_table", Vector3(21.0, 0.0, -31.5))
	if table == null:
		pt._fail("no manor_dining_table anchor")
		return false
	await pt._walk_to(table.global_position, 1.5, func() -> bool: return _space_running(&"first_dinner"), 240.0)
	var t := 0.0
	while not WorldState.has_flag("first_dinner_eaten") and t < 90.0:
		await pt._press(&"interact")
		await pt._wait(0.4)
		t += 0.45
	if not WorldState.has_flag("first_dinner_eaten"):
		var space := pt._find_named(&"Moment_first_dinner") as SceneSpace
		pt._fail("never ate (space %s, beat '%s')" % ["running" if space and space.running else "idle",
			space.current_beat_label() if space else "-"])
		return false
	pt._pass()
	return true


func _bogge_hunt() -> bool:
	pt._begin("bogge_hunt", "hunt with Lucien; eyes ahead while the Bogge passes; walk on; bogge_survived")
	var at := Vector3(BorderWoodsTerrain.BOGGE_HUNT.x, 0.0, BorderWoodsTerrain.BOGGE_HUNT.y)
	var anchor := await _find_anchor(&"bogge_hunt_path", at)
	if anchor == null:
		pt._fail("no bogge_hunt_path anchor")
		return false
	var space := await _scene_on(anchor, &"Moment_bogge") as BoggeHunt
	if space == null:
		pt._fail("the bogge moment isn't the coded BoggeHunt")
		return false
	if not await pt._walk_to(anchor.global_position, 3.0, func() -> bool: return space.running, 300.0):
		pt._fail("never reached the hunt path (can_start %s)" % space.can_start())
		return false
	# Walk with Lucien to where he freezes. The scene's first beats (setting
	# out, his line, the journal) come before "reach freeze", so stop on the
	# freeze itself (control drops to LOOK), not on the label changing.
	await pt._walk_to(space.mark(&"freeze"), 2.0, func() -> bool: return not space.running or StoryControl.mode == StoryControl.Mode.LOOK, 60.0)
	# Frozen: stare at the elm, whatever begs behind her.
	var elm := space.mark(&"elm") + Vector3.UP * 3.0
	var t := 0.0
	var worst := 0.0
	while space.running and space.current_beat_label() != "reach safety" and t < 90.0:
		pt._turn_camera_to(elm)
		await pt.get_tree().physics_frame
		t += pt.get_physics_process_delta_time()
		worst = maxf(worst, space.acknowledged)
	pt._note("pass took %.0f s; most real it got: %.2f s of looking; fog %.3f" % [t, worst, space.fog_density()])
	if not space.running:
		pt._fail("the scene ended early (fails %d)" % space.fail_count)
		return false
	await pt._walk_to(space.mark(&"safety"), 2.0, func() -> bool: return not space.running or space.current_beat_label() != "reach safety", 90.0)
	if not await pt._until(func() -> bool: return WorldState.has_flag("bogge_survived"), 20.0):
		pt._fail("no bogge_survived (beat '%s', fails %d)" % [space.current_beat_label(), space.fail_count])
		return false
	pt._note("pleas %s, thoughts %s" % [space.pleas_shown, space.thoughts_shown])
	pt._pass()
	return true


func _puca_gate() -> bool:
	pt._begin("puca_gate", "night in the garden; follow 'Father' to the gate; Tamlin stops her; look again; puca_resisted")
	# Round the house to the window garden as a player would, not straight
	# through it: the walker steers in lines, and the line from the Bogge's
	# path to the hedge runs through the west wing (ballroom and cellar pit),
	# where she can stall short of the scene's reach.
	for p: Vector2 in _window_garden_route():
		if pt._anchor(&"garden_gate") != null and _near_hedge():
			break
		await pt._walk_to(Vector3(p.x, 0.0, p.y), 3.0, Callable(), 150.0)
	# Wait for the garden to stream in where she stands, by the hedge (the
	# anchor itself is at the north gate, 100 m on).
	var hedge_at := Vector3(ManorSitePlan.PUCA_GARDEN_SPOT.x, 0.0, ManorSitePlan.PUCA_GARDEN_SPOT.y)
	var anchor := await _find_anchor(&"garden_gate", hedge_at)
	if anchor == null:
		pt._fail("no garden_gate anchor")
		return false
	var space := await _scene_on(anchor, &"Moment_puca") as PucaLure
	if space == null:
		pt._fail("the puca moment isn't the coded PucaLure")
		return false
	var hedge := space.mark(&"hedge")
	await pt._walk_to(hedge, 6.0, func() -> bool: return space.running or space.shifting_time, 400.0)
	if not await pt._until(func() -> bool: return space.running, 20.0):
		pt._fail("the puca never came (night %s, can_start %s)" % [Clock.is_night(), space.can_start()])
		return false
	pt._note("night has come (hour %.1f)" % Clock.hour())
	# Follow him.
	await pt._walk_to(space.mark(&"gate"), 2.0, func() -> bool: return space.current_beat_label() != "follow him to the gate" or not space.running, 240.0)
	if not space.running:
		pt._fail("the lure let her go (lost %d)" % space.lost_count)
		return false
	# Look again.
	var t := 0.0
	while space.running and t < 60.0:
		var p := space.puca()
		if p:
			pt._turn_camera_to(p.global_position + Vector3.UP * 1.2)
		await pt.get_tree().physics_frame
		t += pt.get_physics_process_delta_time()
	if not WorldState.has_flag("puca_resisted"):
		pt._fail("no puca_resisted (beat '%s')" % space.current_beat_label())
		return false
	pt._note("shapes: %s" % [space.shifts_seen])
	pt._pass()
	return true


## Outdoor waypoints from the south to the hedges under her window: down the
## lane between the stables and the west wing, then in through the arched
## opening in the window garden's south hedge (ManorRoseGarden._hedges).
## Each waypoint she is already past (north of) is skipped.
func _window_garden_route() -> Array[Vector2]:
	var wing := ManorSitePlan.HOUSE_WEST
	var lane_x := (wing.position.x + ManorSitePlan.STABLES.end.x) * 0.5
	var gap := Vector2(-ManorRoseGarden.SOUTH_OPENING_X, ManorSitePlan.ROSE_GARDEN.end.y - 1.0)
	var route: Array[Vector2] = [Vector2(lane_x, wing.end.y + 30.0), Vector2(lane_x, wing.position.y - 8.0),
		gap + Vector2(0, 6.0), gap - Vector2(0, 6.0)]
	var z: float = pt.feyre.global_position.z
	var ahead: Array[Vector2] = []
	for p in route:
		if p.y < z - 2.0:
			ahead.append(p)
	return ahead


func _near_hedge() -> bool:
	var h := ManorSitePlan.PUCA_GARDEN_SPOT
	return Vector2(pt.feyre.global_position.x - h.x, pt.feyre.global_position.z - h.y).length() < 15.0


func _space_running(id: StringName) -> bool:
	var space := pt._find_named(StringName("Moment_%s" % id)) as SceneSpace
	return space != null and space.running


## The anchor, walking toward where it should be until its region streams in.
func _find_anchor(id: StringName, near: Vector3) -> Node3D:
	var a: Node3D = pt._anchor(id)
	if a:
		return a
	await pt._walk_to(near, 60.0, func() -> bool: return pt._anchor(id) != null, 600.0)
	a = pt._anchor(id)
	if a == null:
		# Her region can still be streaming in (it was unloaded while she was
		# away); stand and wait for it as a player would, and log how long.
		var t0: float = Time.get_unix_time_from_system()
		await pt._until_wall(func() -> bool: return pt._anchor(id) != null, 300.0)
		a = pt._anchor(id)
		if a:
			pt._note("waited %.0f s (wall) at the edge for '%s' to stream in" % [Time.get_unix_time_from_system() - t0, id])
	if a == null:
		var seen: PackedStringArray = []
		for n in pt.get_tree().get_nodes_in_group(&"story_anchor"):
			var m := n as Node3D
			if m and m.global_position.distance_to(near) < 300.0:
				seen.append("%s %s" % [m.get_meta(&"anchor_id", m.name), m.get_path()])
		pt._note("anchors within 300 m of %s: %s; loaded %s, pending %s" % [near, ", ".join(seen) if seen else "none", WorldStreamer.loaded_ids(), WorldStreamer._pending.keys()])
		var mr := WorldStreamer.loaded_root(&"manor_estate")
		if mr:
			pt._note("manor root %s children %s" % [mr.get_path(), mr.get_children().map(func(c: Node) -> String: return c.name)])
	return a


## The scene StoryDirector hangs on an anchor (attached a frame or so after
## the anchor appears; woods regions place anchors in late build jobs).
func _scene_on(anchor: Node3D, node_name: StringName) -> Node:
	var path := NodePath(String(node_name))
	await pt._until(func() -> bool: return is_instance_valid(anchor) and anchor.get_node_or_null(path) != null, 10.0)
	var node: Node = anchor.get_node_or_null(path) if is_instance_valid(anchor) else null
	if node == null:
		pt._note("%s has no %s (children %s)" % [anchor.name, node_name, anchor.get_children().map(func(c: Node) -> String: return String(c.name))])
	return node
