## Headless Act I playthrough: loads the real game scene (story/act1/act1_game.tscn)
## and plays it the way a player would, by pressing actions only (move, sprint,
## jump, aim, fire, cycle_arrow, interact). It never writes a flag (R2): every
## deed has to come out of the game's own ActionTriggers.
##
## Run (from the repo, built files in place: tools/mq/levels.sh ensure):
##   tools/mq/godot.sh --fixed-fps 60 res://tools/playtest/act1_playtest.tscn -- --out=/tmp/act1.json
##     [--stop-after=<beat id>] [--max-wall=<seconds, default 900>] [--settle=<seconds, default 180>]
##
## Acceptance (Act I playable, status.md item 2). The run passes when ALL hold:
##   1. The process exit code is 0. Not 137: that is the shutdown watchdog
##      below, and the log then names what held shutdown ("shutdown suspects").
##   2. The log has "PLAYTEST exit 0", and the report lists these nine beats,
##      each "pass": spawn, hunt_to_clearing, wolf_kill, skin, pelt_sale,
##      sleep, beast_door, crossing, manor_arrival.
##   3. "workarounds" in the report is empty (a workaround patches a game bug).
##   4. final_phase is p2_grounds, and after the ride she stands on the
##      manor estate and walks (manor_arrival checks both).
## Assists ("stuck at ..." lines, "assists" and "assist_causes" in the report)
## are not failures: the walker steers in straight lines and hops 6 m when it
## stalls for 3 s, where a player would steer round. Each names its cause
## (prop <name>, terrain-slope, air, nothing pressing). Watch the count; on
## c552d58 a run takes about 9-10.
##
## Exit codes: 0 pass; 1 a beat failed or needed a workaround; 3 the wall-clock
## cap hit. Before quitting it waits (up to --settle) for region builds,
## streaming loads and the map paint to finish, because their _exit_tree joins
## those tasks. If shutdown still stalls past EXIT_GRACE, a watchdog thread
## kills the process (exit 137) after the report is written.
## Without baked terrain the first load bakes in memory (~3 min in the cloud),
## and she falls through the unbaked manor terrain after the ride.
extends Node

const GAME_SCENE := "res://story/act1/act1_game.tscn"
const STUCK_SECONDS := 3.0
const HOP_METRES := 6.0
const WALK_SPEED_GUESS := 4.0
const EXIT_GRACE := 15.0
const SETTLE_LIMIT := 180.0

var game: Node
var feyre: Feyre
var beats: Array[Dictionary] = []
var events: Array[String] = []
var out_path: String = "user://act1_playtest.json"
## Ends the run after this beat (for quick checks), e.g. --stop-after=spawn.
var stop_after: String = ""
var max_wall: float = 900.0
var settle_limit: float = SETTLE_LIMIT
var _started_at: float = 0.0
var _finished: bool = false
var _exit_watchdog: Thread
var assists: int = 0
var workarounds: Array[String] = []
var assisted_metres: float = 0.0
var _beat: Dictionary = {}
var _hits: Array = []
var _shots: int = 0
var _blocked_shots: int = 0
var _last_landing: Vector3 = Vector3.INF
var _load_seconds: float = 0.0
var _hop_causes: Dictionary = {}
var _shutdown_suspects: PackedStringArray = []


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_path = arg.trim_prefix("--out=")
		elif arg.begins_with("--stop-after="):
			stop_after = arg.trim_prefix("--stop-after=")
		elif arg.begins_with("--settle="):
			settle_limit = float(arg.trim_prefix("--settle="))
		elif arg.begins_with("--max-wall="):
			max_wall = float(arg.trim_prefix("--max-wall="))
	_started_at = Time.get_unix_time_from_system()
	EventBus.deed_performed.connect(func(flag: String) -> void: _log("deed %s" % flag))
	EventBus.phase_changed.connect(func(a: StringName, b: StringName) -> void: _log("phase %s -> %s" % [a, b]))
	EventBus.scene_space_started.connect(func(id: StringName) -> void: _log("space start %s" % id))
	EventBus.scene_space_finished.connect(func(id: StringName) -> void: _log("space end %s" % id))
	EventBus.creature_hit.connect(func(_i: StringName, k: StringName, c: StringName, p: StringName) -> void:
		_hits.append([k, c])
		_log("hit %s by %s (%s)" % [k, c, p]))
	EventBus.creature_killed.connect(func(_i: StringName, k: StringName, c: StringName, _p: Vector3) -> void:
		_log("killed %s by %s" % [k, c]))
	EventBus.creature_harvested.connect(func(_i: StringName, k: StringName, items: PackedStringArray) -> void:
		_log("harvested %s -> %s" % [k, items]))
	EventBus.item_sold.connect(func(id: StringName, coin: int) -> void: _log("sold %s for %d" % [id, coin]))
	EventBus.story_actor_cue.connect(func(a: StringName, c: StringName) -> void: _log("cue %s %s" % [a, c]))
	_run.call_deferred()


func _run() -> void:
	game = (load(GAME_SCENE) as PackedScene).instantiate()
	add_child(game)
	_load_seconds = Time.get_unix_time_from_system() - _started_at
	_log("game scene loaded in %.1f s (wall)" % _load_seconds)
	await _play()
	if not _finished:
		_release_all()
		_note_shutdown_suspects()
		await _settle(settle_limit)
		_finish(0 if beats.all(func(b: Dictionary) -> bool: return b.status == "pass") else 1)


## Wall-clock cap: a stuck run still writes its report and exits.
func _physics_process(_delta: float) -> void:
	if _finished or Time.get_unix_time_from_system() - _started_at < max_wall:
		return
	if not _beat.is_empty() and _beat.status == "running":
		_fail("wall-clock cap of %.0f s hit" % max_wall)
	_finish(3)


func _finish(code: int) -> void:
	_finished = true
	_release_all()
	_note_shutdown_suspects()
	_write_report()
	_exit_watchdog = Thread.new()
	_exit_watchdog.start(_kill_if_still_running.bind(code))
	print("PLAYTEST exit %d" % code)
	get_tree().quit(code)


## Background work that would make shutdown wait, logged so a slow exit
## names its cause even when only the Mac saw it.
func _note_shutdown_suspects() -> void:
	var suspects: PackedStringArray = []
	if _map_painting():
		suspects.append("WorldMapHud: map paint thread still running (ui/map not baked?)")
	for node in _building_regions():
		suspects.append("%s: region build task still running" % node.name)
	var pending: Variant = WorldStreamer.get(&"_pending")
	if pending is Dictionary and not (pending as Dictionary).is_empty():
		suspects.append("WorldStreamer: %d region loads in flight" % (pending as Dictionary).size())
	_shutdown_suspects = suspects
	_log("shutdown suspects: %s" % (", ".join(suspects) if not suspects.is_empty() else "none"))


func _map_painting() -> bool:
	for node in get_tree().root.find_children("*", "", true, false):
		var thread: Variant = node.get(&"_paint_thread")
		if thread is Thread and (thread as Thread).is_alive():
			return true
	return false


## Regions whose WorkerThreadPool build is still running. Their _exit_tree
## joins that task, so quitting now would make shutdown wait for it.
func _building_regions() -> Array[Node]:
	var out: Array[Node] = []
	for node in get_tree().root.find_children("*", "", true, false):
		for key: StringName in [&"_task", &"_task_id"]:
			var id: Variant = node.get(key)
			if id is int and id >= 0 and not WorkerThreadPool.is_task_completed(id):
				out.append(node)
	return out


## Lets in-flight region builds and loads finish before quitting, so shutdown
## has nothing to join. Bounded; whatever is left is named in the report.
func _settle(limit: float) -> void:
	var t0 := Time.get_unix_time_from_system()
	var busy := func() -> bool:
		var pending: Variant = WorldStreamer.get(&"_pending")
		return not _building_regions().is_empty() or _map_painting() \
				or (pending is Dictionary and not (pending as Dictionary).is_empty())
	if not busy.call():
		return
	while busy.call() and Time.get_unix_time_from_system() - t0 < limit:
		await get_tree().process_frame
	_log("waited %.1f s for region builds to finish before quitting" % (Time.get_unix_time_from_system() - t0))


## Runs off the main thread: if engine shutdown hangs, end the process anyway.
static func _kill_if_still_running(code: int) -> void:
	OS.delay_msec(int(EXIT_GRACE * 1000.0))
	printerr("PLAYTEST shutdown took over %.0f s; killing the process (run exit code was %d)" % [EXIT_GRACE, code])
	OS.kill(OS.get_process_id())


func _play() -> void:
	# 1. Wake at the cottage.
	_begin("spawn", "Feyre stands at the cottage at dawn, controllable")
	if not &"spawned" in game:
		return _fail("%s didn't load as the Act I game (script error?)" % GAME_SCENE)
	if not await _until(func() -> bool: return game.spawned, 30.0):
		return _fail("never spawned")
	feyre = game.feyre
	feyre.interactor.picked.connect(func(id: StringName, n: int) -> void: _log("picked up %s x%d" % [id, n]))
	feyre.interactor.station_used.connect(func(id: StringName) -> void: _log("used station %s" % id))
	feyre.arrow_fired.connect(func(arrow: Node) -> void:
		arrow.broke.connect(func(at: Vector3) -> void: _log("arrow %s BROKE at %s" % [arrow.get(&"arrow_id"), _v(at)]))
		arrow.tree_exiting.connect(func() -> void:
			if not arrow.get(&"stuck"):
				_log("arrow %s gone without landing at %s" % [arrow.get(&"arrow_id"), _v(arrow.global_position)]))
		arrow.hit.connect(func(collider: Node, at: Vector3) -> void:
			_last_landing = at
			_log("arrow %s hit %s at %s" % [arrow.get(&"arrow_id"), collider.name if collider else "nothing", _v(at)])))
	await _until(func() -> bool: return StoryControl.mode == StoryControl.Mode.FULL, 10.0)
	_note("at %s in %s, phase %s, control %s" % [_v(feyre.global_position), _region(), PhaseManager.current_phase, _mode()])
	_pass()
	if _beat.id == stop_after:
		return

	# 2. The hunt: walk into the wolf clearing (WolfKill's Entry).
	_begin("hunt_to_clearing", "walk from the cottage into the wolf clearing; WolfKill starts")
	var clearing := _anchor(&"act1_wolf_clearing")
	if clearing == null:
		await _walk_region(&"hunting_forest")
		clearing = _anchor(&"act1_wolf_clearing")
	if clearing == null:
		return _fail("no act1_wolf_clearing anchor in the loaded world")
	var wolf_kill := clearing.get_node_or_null(^"WolfKill") as WolfKill
	if wolf_kill == null:
		return _fail("no WolfKill space under the clearing anchor")
	_note("clearing at %s, %.0f m away" % [_v(clearing.global_position), _flat(clearing.global_position)])
	await _walk_to(clearing.global_position, 3.0, func() -> bool: return wolf_kill.running)
	if not await _until(func() -> bool: return wolf_kill.running or WorldState.has_flag("wolf_killed"), 5.0):
		return _fail("stood in the clearing; WolfKill never started (Entry area never fired)")
	_pass()
	if _beat.id == stop_after:
		return

	# 3. The wolf: ash arrow first, then anything.
	_begin("wolf_kill", "wolf appears; ash arrow in the side, second arrow kills; wolf_killed")
	if not await _until(func() -> bool: return wolf_kill.wolf != null and StoryControl.mode == StoryControl.Mode.FULL, 15.0):
		return _fail("wolf never appeared or control never returned (beat '%s')" % wolf_kill.current_beat_label())
	var wolf := wolf_kill.wolf
	_note("wolf is %s (%s), %.0f m away, y %.1f over ground %.1f" % [wolf.name, wolf.get_class(), _flat(wolf.global_position),
		wolf.global_position.y, _ground_at(wolf.global_position)])
	var doe: Node3D = wolf_kill.doe
	if doe:
		_note("doe y %.1f over ground %.1f" % [doe.global_position.y, _ground_at(doe.global_position)])
	if wolf.global_position.y < _ground_at(wolf.global_position) - 0.2:
		_note("the wolf spawned under the ground")
		_workaround("lift the wolf onto the ground", func() -> void:
			var w := wolf.global_position
			wolf.global_position = Vector3(w.x, _ground_at(w + Vector3.UP * 50.0) + 0.2, w.z))
	_note("quiver: %s" % _quiver())
	for shot in 14:
		if WorldState.has_flag("wolf_killed"):
			break
		if not is_instance_valid(wolf):
			return _fail("the wolf node was freed before it died")
		if not wolf_kill.ash_struck and Gameplay.inventory.count(&"arrow_ash") == 0:
			if not await _retrieve_arrow(&"ash"):
				return _fail("the only ash arrow missed and can't be picked up again: soft-lock")
		await _select_arrow(&"arrow_ash" if not wolf_kill.ash_struck else &"arrow_wood")
		if _flat(wolf.global_position) > 30.0:
			await _walk_to(wolf.global_position, 22.0, Callable(), 20.0)
		elif _flat(wolf.global_position) < 12.0:
			var away := feyre.global_position - wolf.global_position
			away.y = 0.0
			await _walk_to(wolf.global_position + away.normalized() * 18.0, 1.5, Callable(), 8.0)
		if not await _shoot_at(wolf):
			_note("shot %d: could not shoot (control %s, quiver %s)" % [shot + 1, _mode(), _quiver()])
		elif _last_landing != Vector3.INF and _last_landing.distance_to(feyre.global_position) < 6.0:
			# Something right in front of the bow ate the arrow: side-step like a player would.
			_blocked_shots += 1
			var to := wolf.global_position - feyre.global_position
			var side := Vector3(-to.z, 0, to.x).normalized() * (4.0 if shot % 2 == 0 else -4.0)
			_note("arrow stopped %.1f m from Feyre (line of fire blocked); side-stepping" % _last_landing.distance_to(feyre.global_position))
			await _walk_to(feyre.global_position + side, 1.0, Callable(), 6.0)
		await _wait(1.0)
	_note("shots: %d (%d blocked right in front of her), quiver after: %s" % [_shots, _blocked_shots, _quiver()])
	if not await _until(func() -> bool: return WorldState.has_flag("wolf_killed"), 8.0):
		return _fail("wolf not dead after shooting; hits: %s, beat '%s'" % [_hits, wolf_kill.current_beat_label()])
	_pass()
	if _beat.id == stop_after:
		return

	# 4. Skin him: walk to the carcass, press E.
	_begin("skin", "walk to the wolf and press interact; the pelt comes off (fact.wolf_skinned)")
	await _until(func() -> bool: return StoryControl.can_interact(), 10.0)
	var body_at: Vector3 = wolf.global_position if is_instance_valid(wolf) else clearing.global_position
	await _walk_to(body_at, 1.6, Callable(), 30.0)
	var presses := 0
	while presses < 6 and Gameplay.inventory.count(&"obj_wolf_pelt") == 0:
		await _press(&"interact")
		await _wait(0.5)
		presses += 1
	_note("interact presses to get the pelt: %d" % presses)
	if Gameplay.inventory.count(&"obj_wolf_pelt") == 0:
		return _fail("pressed interact at the wolf; no pelt (harvestables in reach: %d)" % _in_reach(&"harvestable", 2.5))
	await _until(func() -> bool: return WorldState.has_flag("fact.wolf_skinned"), 6.0)
	_pass()
	if _beat.id == stop_after:
		return

	# 5. Sell it at the fur stall in the village.
	_begin("pelt_sale", "walk to the village fur stall, press interact; pelt_sold, phase p1")
	var stall := _anchor(&"act1_fur_stall")
	if stall == null:
		await _walk_region(&"village")
		stall = _anchor(&"act1_fur_stall")
	if stall == null:
		return _fail("no act1_fur_stall anchor")
	_note("stall at %s, %.0f m away" % [_v(stall.global_position), _flat(stall.global_position)])
	await _walk_to(stall.global_position, 1.8)
	await _until(func() -> bool: return StoryControl.can_interact(), 5.0)
	await _press(&"interact")
	if not await _until(func() -> bool: return WorldState.has_flag("pelt_sold"), 8.0):
		return _fail("pressed interact at the stall (%.1f m); pelt_sold never rose" % _flat(stall.global_position))
	await _until(func() -> bool: return PhaseManager.current_phase == &"p1_wolf_and_crossing", 3.0)
	_note("phase %s" % PhaseManager.current_phase)
	_pass()
	if _beat.id == stop_after:
		return

	# 6. Home to sleep the day away.
	_begin("sleep", "walk home, press interact at the ironwood bed; night falls")
	var bed := _find_named(&"BedKeepsake")
	if bed == null:
		await _walk_region(&"cottage")
		bed = _find_named(&"BedKeepsake")
	if bed == null:
		return _fail("no BedKeepsake (CottageBed) in the cottage")
	_note("bed at %s, %.0f m away" % [_v(bed.global_position), _flat(bed.global_position)])
	var door_anchor := _anchor(&"act1_cottage_door")
	var room := _anchor(&"act1_cottage_interior")
	if door_anchor and room:
		var out := door_anchor.global_position - room.global_position
		out.y = 0.0
		await _walk_to(door_anchor.global_position + out.normalized() * 3.0, 1.0)
		await _walk_to(door_anchor.global_position, 0.6, Callable(), 15.0)
	await _walk_to(bed.global_position, 2.0, Callable(), 20.0)
	await _until(func() -> bool: return StoryControl.can_interact(), 5.0)
	await _press(&"interact")
	_note("feyre %s on floor %s; interior anchor %s; bed %s; ground under bed %.1f" % [_v(feyre.global_position), feyre.is_on_floor(),
		_v(room.global_position) if room else "none", _v(bed.global_position), _ground_at(bed.global_position)])
	_note("bed: can_sleep %s, sleeping %s, control %s, %.1f m (3D)" % [bed.call(&"can_sleep"), bed.get(&"sleeping"), _mode(),
		bed.global_position.distance_to(feyre.global_position)])
	if not await _until(func() -> bool: return Clock.is_night(), 8.0):
		return _fail("pressed interact at the bed (%.1f m); still day (%.2f)" % [_flat(bed.global_position), Clock.time_of_day])
	_note("time of day %.2f" % Clock.time_of_day)
	_pass()
	if _beat.id == stop_after:
		return

	# 7. The beast at the door: choose (interact = throw the knife).
	_begin("beast_door", "the beast breaks in; choose; beast_claim_accepted")
	var door := _find_named(&"BeastDoor") as BeastDoor
	if door == null:
		return _fail("no BeastDoor space")
	if not await _until(func() -> bool: return door.running or WorldState.has_flag("beast_claim_accepted"), 15.0):
		return _fail("night, Feyre home, the beast never came (player_inside=%s, can_start=%s)" % [door._player_inside, door.can_start()])
	await _until(func() -> bool: return door.current_beat_label().begins_with("decision"), 20.0)
	await _press(&"interact")
	if not await _until(func() -> bool: return WorldState.has_flag("beast_claim_accepted"), 20.0):
		return _fail("stuck at beat '%s'" % door.current_beat_label())
	_note("choice: %s" % door.chosen_fact)
	_pass()
	if _beat.id == stop_after:
		return

	# 8. The ride north and the wall.
	_begin("crossing", "ride starts by itself; wall_crossed; phase p2_grounds")
	var ride := _find_named(&"RideNorth") as RideNorth
	if ride == null:
		var found := _find_named(&"RideNorth")
		if found:
			_note("a '%s' named RideNorth is in the tree at %s, so Act1Anchors._ensure_ride never made the ride" % [found.get_class(), found.get_path()])
			_workaround("add the RideNorth space under StoryDirector", func() -> void:
				var r := RideNorth.new()
				r.name = "RideNorth"
				StoryDirector.add_child(r))
			ride = StoryDirector.get_node(^"RideNorth") as RideNorth
	if ride == null:
		var names: PackedStringArray = []
		for c in StoryDirector.get_children():
			names.append("%s(%s)" % [c.name, c.get_class()])
		return _fail("no RideNorth; StoryDirector children: %s; wall_crossed %s" % [", ".join(names), WorldState.has_flag("wall_crossed")])
	if not await _until(func() -> bool: return ride.running or WorldState.has_flag("wall_crossed"), 15.0):
		return _fail("ride never started")
	_note("ride path: %s, %.0f m" % [ride.path.get_path() if ride.path else "none", ride.path_length()])
	if not await _until(func() -> bool: return not ride.running, 240.0):
		return _fail("ride never ended (beat '%s', progress %.0f)" % [ride.current_beat_label(), ride.progress])
	if not WorldState.has_flag("wall_crossed"):
		return _fail("ride ended without wall_crossed")
	await _until(func() -> bool: return PhaseManager.current_phase == &"p2_grounds", 3.0)
	if PhaseManager.current_phase != &"p2_grounds":
		return _fail("wall crossed but phase is %s" % PhaseManager.current_phase)
	_pass()
	if _beat.id == stop_after:
		return

	# 9. Arrival at the manor.
	_begin("manor_arrival", "after the ride Feyre is on the manor estate, free to walk")
	await _wait(2.0)
	var manor := WorldStreamer.get_region(&"manor_estate")
	_note("dismounted at %s in %s, control %s" % [_v(feyre.global_position), _region(), _mode()])
	if manor:
		_note("manor_estate centre %.0f m away" % _flat(manor.center))
	if _region() != "manor_estate":
		_note("the ride ends in '%s', not at the manor; walking on" % _region())
		var walked_in := await _walk_to(manor.center, 60.0, func() -> bool: return _region() == "manor_estate", 900.0)
		if not walked_in:
			return _fail("couldn't reach the manor estate on foot from the ride's end (now in %s, %.0f m off)" % [_region(), _flat(manor.center)])
	_note("on the manor estate at %s" % _v(feyre.global_position))
	await _wait(1.0)
	var ground := _ground_at(feyre.global_position + Vector3.UP * 3.0, 3.0)
	if not feyre.is_on_floor() or feyre.global_position.y < ground - 1.0:
		var baked := DirAccess.get_files_at("res://world/shared/terrain/data").size() > 0 \
				if DirAccess.dir_exists_absolute("res://world/shared/terrain/data") else false
		return _fail("not standing after the ride: y %.1f, ground %.1f, on floor %s%s" % [feyre.global_position.y, ground,
			feyre.is_on_floor(), "" if baked else " (no baked terrain here: run tools/mq/levels.sh ensure)"])
	var start := feyre.global_position
	await _walk_to(start + feyre.model.global_basis.z * -15.0, 2.0, Callable(), 10.0)
	_note("walked %.1f m on the estate" % feyre.global_position.distance_to(start))
	_pass()


# --- input ------------------------------------------------------------------

func _press(action: StringName) -> void:
	var down := InputEventAction.new()
	down.action = action
	down.pressed = true
	Input.parse_input_event(down)
	await get_tree().physics_frame
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	await get_tree().physics_frame


func _release_all() -> void:
	for a in [&"move_forward", &"sprint", &"fire", &"aim", &"jump"]:
		Input.action_release(a)


func _select_arrow(id: StringName) -> void:
	var bow: Node = feyre.bow_controller
	if bow == null:
		_note("Feyre has no bow component")
		return
	for i in 6:
		if bow.get(&"selected") == id:
			return
		await _press(&"cycle_arrow")
	_note("cycle_arrow never selected %s (selected %s)" % [id, bow.get(&"selected")])


## Turns the camera onto the target (as a mouse would), holds aim and draws.
func _shoot_at(target: Node3D) -> bool:
	Input.action_press(&"aim")
	for i in 180:
		if _turn_camera_to(_lead(target)) < 0.3 and i > 20:
			break
		await get_tree().physics_frame
	if not StoryControl.can_shoot() or Gameplay.inventory.arrow_count() == 0:
		Input.action_release(&"aim")
		return false
	Input.action_press(&"fire")
	for i in 75:
		_turn_camera_to(_lead(target))
		await get_tree().physics_frame
	_last_landing = Vector3.INF
	_shots += 1
	Input.action_release(&"fire")
	await get_tree().physics_frame
	Input.action_release(&"aim")
	await _until(func() -> bool: return _last_landing != Vector3.INF, 2.0)
	var chest := target.global_position + Vector3.UP * 0.9
	if _last_landing == Vector3.INF:
		_note("shot at %.0f m: the arrow never landed" % _flat(target.global_position))
	else:
		var low := chest.y - _last_landing.y
		_note("shot at %.0f m: landed %.1f m from his chest, %.1f m low" % [_flat(target.global_position),
			_last_landing.distance_to(chest), low])

	return true


## Where a practised archer holds: the chest, led for his movement and
## raised for the drop over the flight time.
func _lead(target: Node3D) -> Vector3:
	var chest := target.global_position + Vector3.UP * 0.9
	var speed := float(feyre.bow_controller.bow.max_speed)
	var t := chest.distance_to(feyre.global_position) / maxf(speed, 1.0)
	var vel: Vector3 = target.velocity if target is CharacterBody3D else Vector3.ZERO
	var g := float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	return chest + Vector3(vel.x, 0, vel.z) * t + Vector3.UP * (0.5 * g * t * t)


## Returns the remaining aim error in degrees.
func _turn_camera_to(point: Vector3) -> float:
	var cam := feyre.camera
	var want := (point - cam.global_position).normalized()
	var have := -cam.global_basis.z
	var dyaw := wrapf(atan2(-want.x, -want.z) - atan2(-have.x, -have.z), -PI, PI)
	var dpitch := asin(clampf(want.y, -1, 1)) - asin(clampf(have.y, -1, 1))
	feyre.nudge_camera(dyaw * 0.5, dpitch * 0.5)
	return rad_to_deg(want.angle_to(have))


## Walks to a stuck arrow of this type and presses interact over it.
func _retrieve_arrow(arrow_id: StringName) -> bool:
	for stuck in get_tree().get_nodes_in_group(Arrow.STUCK_GROUP):
		if stuck.get(&"arrow_id") != arrow_id:
			continue
		var at := (stuck as Node3D).global_position
		_note("going to pick up the %s arrow %.0f m away" % [arrow_id, _flat(at)])
		await _walk_to(at, 1.0, Callable(), 30.0)
		await _press(&"interact")
		await _wait(0.3)
		var got := Gameplay.inventory.count(StringName("arrow_%s" % arrow_id)) > 0
		_note("picked it up: %s" % got)
		return got
	_note("no stuck %s arrow in the world (%d stuck arrows)" % [arrow_id, get_tree().get_nodes_in_group(Arrow.STUCK_GROUP).size()])
	return false


func _pick_up_arrows() -> void:
	for stuck in get_tree().get_nodes_in_group(Arrow.STUCK_GROUP):
		if _flat((stuck as Node3D).global_position) < 30.0:
			await _walk_to((stuck as Node3D).global_position, 1.5, Callable(), 15.0)
			await _press(&"interact")


## Stick-walks toward `target` until within `radius` (or `done` says so).
func _walk_to(target: Vector3, radius: float, done: Callable = Callable(), timeout: float = -1.0) -> bool:
	var dist0 := _flat(target)
	if timeout < 0.0:
		timeout = 20.0 + dist0 / WALK_SPEED_GUESS * 2.5
	var t := 0.0
	var last_pos := feyre.global_position
	var last_check := 0.0
	var walked := 0.0
	var hops := 0
	while t < timeout:
		if done.is_valid() and done.call():
			break
		if _flat(target) <= radius:
			break
		var to := target - feyre.global_position
		var want_yaw := atan2(-to.x, -to.z)
		feyre.nudge_camera(wrapf(want_yaw - feyre.camera_yaw(), -PI, PI), 0.0)
		Input.action_press(&"move_forward")
		if feyre.stamina > feyre.max_stamina * 0.5 and _flat(target) > 15.0:
			Input.action_press(&"sprint")
		elif feyre.stamina < feyre.max_stamina * 0.1:
			Input.action_release(&"sprint")
		await get_tree().physics_frame
		var dt := get_physics_process_delta_time()
		t += dt
		walked += feyre.get_real_velocity().length() * dt
		if t - last_check >= STUCK_SECONDS:
			var progress := Vector2(last_pos.x, last_pos.z).distance_to(Vector2(feyre.global_position.x, feyre.global_position.z))
			if progress < 1.0:
				var why := _blocker()
				await _press(&"jump")
				var hop := Vector3(to.x, 0, to.z).normalized() * minf(HOP_METRES, _flat(target))
				var p := feyre.global_position + hop
				p.y = _ground_at(p, 2.5) + 0.3
				feyre.global_position = p
				feyre.velocity = Vector3.ZERO
				_log("    stuck at %s in %s (%s), hopping %.0f m" % [_v(p - hop), _region(), why, hop.length()])
				_hop_causes[why.get_slice(" ", 0)] = int(_hop_causes.get(why.get_slice(" ", 0), 0)) + 1
				hops += 1
				assists += 1
				assisted_metres += hop.length()
			last_pos = feyre.global_position
			last_check = t
		if feyre.global_position.y < -200.0:
			_note("fell out of the world at %s" % _v(feyre.global_position))
			break
	Input.action_release(&"move_forward")
	Input.action_release(&"sprint")
	var arrived: bool = _flat(target) <= radius or (done.is_valid() and bool(done.call()))
	_note("walk %.0f m -> %.1f m left in %.0f s (walked %.0f m, %d stuck hops)%s" % [dist0, _flat(target), t, walked, hops, "" if arrived else " TIMED OUT"])
	if hops > 0:
		_beat["hops"] = int(_beat.get("hops", 0)) + hops
	return arrived


## What stopped her: the body she's pressing against, or the slope under her.
## The first word is the kind (prop, terrain-slope, terrain, air, nothing).
func _blocker() -> String:
	var floor_deg := rad_to_deg(feyre.get_floor_normal().angle_to(Vector3.UP)) if feyre.is_on_floor() else -1.0
	for i in feyre.get_slide_collision_count():
		var c := feyre.get_slide_collision(i)
		var n := c.get_normal()
		if n.y > 0.7:
			continue  # the floor itself
		var body := c.get_collider() as Node
		var body_name := String(body.name) if body else "?"
		if body and body.get_class() == "Terrain3D":
			return "terrain-slope %.0f deg wall, floor %.0f deg" % [rad_to_deg(n.angle_to(Vector3.UP)), floor_deg]
		return "prop %s (%s)" % [body_name, String(body.get_parent().name) if body and body.get_parent() else "-"]
	if not feyre.is_on_floor():
		return "air"
	return "nothing pressing, floor %.0f deg" % floor_deg


func _walk_region(id: StringName) -> void:
	var region := WorldStreamer.get_region(id)
	if region:
		await _walk_to(region.center, 20.0)


func _ground_at(p: Vector3, from_above: float = 60.0) -> float:
	var space := feyre.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * from_above, p + Vector3.DOWN * 200.0, 1, [feyre.get_rid()])
	var hit := space.intersect_ray(q)
	return (hit.position as Vector3).y if hit else p.y


# --- waiting and lookup -------------------------------------------------------

## Patches past a known blocker so the later beats still get played. Every
## use is logged and marks the beat; the report counts them.
func _workaround(what: String, fix: Callable) -> void:
	_beat["workarounds"] = _beat.get("workarounds", []) + [what]
	workarounds.append("%s: %s" % [_beat.id, what])
	_note("WORKAROUND: " + what)
	fix.call()


func _wait(seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()


func _until(cond: Callable, seconds: float) -> bool:
	var t := 0.0
	while t < seconds:
		if cond.call():
			return true
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	return bool(cond.call())


func _anchor(id: StringName) -> Node3D:
	for a in get_tree().get_nodes_in_group(&"story_anchor"):
		if StringName(a.get_meta(&"anchor_id", a.name)) == id:
			return a as Node3D
	return null


func _find_named(node_name: StringName) -> Node3D:
	return get_tree().root.find_child(String(node_name), true, false) as Node3D


func _in_reach(group: StringName, reach: float) -> int:
	var n := 0
	for node in get_tree().get_nodes_in_group(group):
		if node is Node3D and (node as Node3D).global_position.distance_to(feyre.global_position) <= reach:
			n += 1
	return n


func _flat(p: Vector3) -> float:
	return Vector2(p.x, p.z).distance_to(Vector2(feyre.global_position.x, feyre.global_position.z))


func _region() -> String:
	var r := WorldStreamer.region_at(feyre.global_position)
	return String(r.id) if r else "none"


func _mode() -> String:
	return StoryControl.Mode.keys()[StoryControl.mode]


func _quiver() -> String:
	var parts: PackedStringArray = []
	for id in [&"arrow_wood", &"arrow_ash"]:
		parts.append("%s=%d" % [id, Gameplay.inventory.count(id)])
	return ", ".join(parts)


func _v(p: Vector3) -> String:
	return "(%.0f, %.0f, %.0f)" % [p.x, p.y, p.z]


# --- report -------------------------------------------------------------------

func _sim_seconds() -> float:
	return Engine.get_physics_frames() / float(Engine.physics_ticks_per_second)


func _log(line: String) -> void:
	var entry := "[%7.1f s] %s" % [_sim_seconds(), line]
	events.append(entry)
	print("PLAYTEST ", entry)


func _begin(id: String, goal: String) -> void:
	_beat = {"id": id, "goal": goal, "status": "running", "notes": [],
		"sim_start": _sim_seconds(), "wall_start": Time.get_unix_time_from_system()}
	beats.append(_beat)
	_log("BEAT %s: %s" % [id, goal])


func _note(text: String) -> void:
	_beat.notes.append(text)
	_log("  %s" % text)


func _close(status: String) -> void:
	_beat.status = status
	_beat["sim_seconds"] = snappedf(_sim_seconds() - _beat.sim_start, 0.1)
	_beat["wall_seconds"] = snappedf(Time.get_unix_time_from_system() - _beat.wall_start, 0.1)
	_beat.erase("sim_start")
	_beat.erase("wall_start")
	_log("BEAT %s %s (%.1f s game, %.1f s wall)" % [_beat.id, status.to_upper(), _beat.sim_seconds, _beat.wall_seconds])


func _pass() -> void:
	_close("pass" if not _beat.has("workarounds") else "pass_with_workaround")


func _fail(why: String) -> void:
	_note("FAIL: " + why)
	_close("fail")


func _write_report() -> void:
	var report := {
		"commit": OS.get_environment("PLAYTEST_COMMIT"),
		"load_seconds": snappedf(_load_seconds, 0.1),
		"total_wall_seconds": snappedf(Time.get_unix_time_from_system() - _started_at, 0.1),
		"beats": beats,
		"assists": assists,
		"workarounds": workarounds,
		"assisted_metres": snappedf(assisted_metres, 0.1),
		"assist_causes": _hop_causes,
		"shutdown_suspects": _shutdown_suspects,
		"final_phase": String(PhaseManager.current_phase),
		"flags": WorldState._flags.keys(),
		"events": events,
	}
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(report, "  "))
	print("PLAYTEST report -> %s" % out_path)
