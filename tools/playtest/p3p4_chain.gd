## The full playtest past Act II (L08): after puca_gate, the same run walks on
## into p3 and p4's painting, playing each lane's own beats in place rather
## than from its dev jump:
##   house:*    p3_house_playtest.gd (L28)    hall marks, map, the beast, wound, mural
##   suriel:*   p3_suriel_playtest.gd (L26)   stream, snare, hide, Suriel, answers, naga
##   faerie:*   p3_faerie_playtest.gd (L29)   the Summer faerie on the hall table (held)
##   starlight_pool                            Tamlin's pool in the glen (data moment)
##   painting:* p4_painting_playtest.gd (L30) studio, gallery, first painting
## Each segment script is instanced as a "chained" child that shares this run's
## game, Feyre, beats and log, so its _run (which loads a dev jump) never runs.
## Its beats are renamed "<segment>:<beat>". Before each one the chain walks her
## to where that lane's jump would have set her down, and lets the clock run
## when the beat needs night. She fetches the Suriel's snare kit herself (the
## kitchen larder's chicken, the potting shed's twine); the faerie's herbs are
## L29's "shelves" beat. Nothing is granted.
## painting:dev_jump_p4 and painting:gallery_seen keep L30's two set-downs (the
## walker can't take stairs); in the chain every deed its jump writes is
## already earned, which painting:travel checks.
## Cloud cost of the whole run (c83ac07-era main): ~8 min wall, ~32 min game.
class_name P3P4Chain
extends RefCounted

const HOUSE := "res://tools/playtest/p3_house_playtest.gd"
const SURIEL := "res://tools/playtest/p3_suriel_playtest.gd"
const FAERIE := "res://tools/playtest/p3_faerie_playtest.gd"
const PAINTING := "res://tools/playtest/p4_painting_playtest.gd"
## The snare kit from the house and grounds (L26-4): a fresh-killed chicken
## from the kitchen larder for the bait, the gardener's twine on the potting
## shed's work table for both loops. Both restock daily.
const CHICKEN := &"ing_dead_chicken"
const TWINE := &"mat_snare_twine"
## House-space walks (x, z; the house sits at the world origin), from the
## study to the kitchen and from the kitchen back to the front doors, along
## L28's door-to-door routes (p3_house_playtest.gd).
const STUDY_TO_KITCHEN := [Vector2(-22.8, -68.5), Vector2(-21.5, -65), Vector2(-15, -65), Vector2(-12, -66), Vector2(-9, -66), Vector2(-9, -67.5),
		Vector2(-1.8, -67.5), Vector2(-1.8, -62.5), Vector2(-1, -59), Vector2(7, -55), Vector2(9, -50),
		Vector2(12, -50), Vector2(40, -50), Vector2(44, -51), Vector2(52, -51), Vector2(52, -57)]
const KITCHEN_TO_DOORS := [Vector2(52, -51), Vector2(44, -51), Vector2(40, -50), Vector2(12, -50),
		Vector2(9, -50), Vector2(7, -54), Vector2(7, -38)]
## Round the east side of the house to the kitchen garden's potting shed
## (Rect2(148, -77, 10, 7), door on its south side, the table at its north end).
const TO_SHED := [Vector2(0, 14), Vector2(100, 14), Vector2(153, -50), Vector2(153, -66), Vector2(153, -71)]

## In play order; the header's acceptance list appends these.
const BEATS: Array[String] = [
	"house:travel", "house:spawn", "house:hall_marks", "house:map_drawn", "house:the_beast",
	"house:to_the_infirmary", "house:wound_dressed", "house:mural",
	"suriel:travel", "suriel:spawn", "suriel:scout_stream", "suriel:set_snare", "suriel:hide_downwind",
	"suriel:suriel_caught", "suriel:answers", "suriel:naga",
	"faerie:travel", "faerie:spawn", "faerie:carried_in", "faerie:shelves", "faerie:triage", "faerie:words", "faerie:hand", "faerie:held",
	"starlight_pool",
	"painting:travel", "painting:spawn", "painting:dev_jump_p4", "painting:studio_open",
	"painting:gallery_opened", "painting:first_painting", "painting:gallery_seen"]

var pt: Node


func _init(playtest: Node) -> void:
	pt = playtest


func play() -> bool:
	for step: Callable in [_house, _suriel, _faerie, _starlight_pool, _painting]:
		if not await step.call():
			return false
		if pt.stop_after != "" and pt.stop_after in _played_since(step):
			return true
	return true


## Beat ids the run has so far (cheap: the list is short).
func _played_since(_step: Callable) -> Array:
	return pt.beats.map(func(b: Dictionary) -> String: return String(b.id))


# --- segments ---------------------------------------------------------------

func _house() -> bool:
	pt._begin("house:travel", "into the house to the front doors (hall_mark_1), at night")
	var a: Node3D = await _reach_anchor(&"hall_mark_1", Vector3(0, 0, -45))
	if a == null:
		return false
	if not await _enter_house(a, 1.2):
		return false
	pt._note("at %s, %s" % [pt._v(pt.feyre.global_position), _clock()])
	pt._pass()
	return await _segment("house", HOUSE)


func _suriel() -> bool:
	pt._begin("suriel:travel", "a chicken from the kitchen larder, twine from the potting shed, then out to the Suriel's glade")
	if not await _gather_snare_kit():
		return false
	var a: Node3D = await _reach_anchor(&"suriel_snare", _region_center(&"suriel_glade"))
	if a == null:
		return false
	await pt._walk_to(a.global_position, 3.0)
	pt._note("at %s, %s" % [pt._v(pt.feyre.global_position), _clock()])
	pt._pass()
	return await _segment("suriel", SURIEL, func(seg: Node) -> void:
		EventBus.journal_entry_added.connect(func(_id: StringName) -> void:
			if is_instance_valid(seg):
				seg.journal_seen += 1))


func _faerie() -> bool:
	pt._begin("faerie:travel", "home to the entrance hall (manor_window_hide) and wait there for the night")
	var a: Node3D = await _reach_anchor(&"manor_window_hide", Vector3(0, 0, -45))
	if a == null:
		return false
	if not await _enter_house(a, 1.0):
		return false
	var triage := a.get_node_or_null(^"SummerFaerieTriage") as SceneSpace
	if triage == null:
		pt._fail("no SummerFaerieTriage on manor_window_hide")
		return false
	# A whole day at most (24 game minutes), standing by the window.
	var t0: float = pt._sim_seconds()
	if not await pt._until(func() -> bool: return triage.running, Clock.DAY_LENGTH_SECONDS + 60.0):
		pt._fail("the faerie never came (can_start %s, %s)" % [triage.can_start(), _clock()])
		return false
	pt._note("waited %.0f s of game time for the night; %s" % [pt._sim_seconds() - t0, _clock()])
	pt._pass()
	return await _segment("faerie", FAERIE)


func _starlight_pool() -> bool:
	pt._begin("starlight_pool", "to Tamlin's pool in the starlight glen; stay; starlight_pool_found")
	var a: Node3D = await _reach_anchor(&"starlight_pool", _region_center(&"starlight_glen"))
	if a == null:
		return false
	await pt._walk_to(a.global_position, 2.0, func() -> bool: return WorldState.has_flag("starlight_pool_found"))
	pt._release_all()
	if not await pt._until(func() -> bool: return WorldState.has_flag("starlight_pool_found"), 40.0):
		pt._fail("starlight_pool_found never raised (%.1f m from the pool, %s)" % [pt._flat(a.global_position), _clock()])
		return false
	pt._note("phase %s" % PhaseManager.current_phase)
	pt._pass()
	return true


func _painting() -> bool:
	pt._begin("painting:travel", "back to the manor's front doors; the painting room is upstairs")
	var a: Node3D = await _reach_anchor(&"hall_mark_1", Vector3(0, 0, -45))
	if a == null:
		return false
	if not await _enter_house(a, 1.5):
		return false
	var missing := []
	for flag: String in ["starlight_pool_found", "summer_faerie_comforted", "suriel_bound", "naga_survived",
			"tamlin_wound_dressed", "manor_map_drawn", "study_mural_seen"]:
		if not WorldState.has_flag(flag):
			missing.append(flag)
	if not missing.is_empty():
		# The painting segment's dev jump would write these; in the chain they
		# must already have come out of play.
		pt._fail("deeds not earned before the studio: %s" % ", ".join(missing))
		return false
	pt._note("every deed its dev jump writes is already earned; its set-down at the easel stands in for the stairs")
	pt._pass()
	return await _segment("painting", PAINTING)


# --- plumbing ---------------------------------------------------------------

## The manor faces +Z: its front doors open on the forecourt at z ~ -20 and
## the gardens lie behind it. Walking straight at a ground-floor anchor from
## the gardens or the woods takes her through the back of the house, where a
## stuck-hop can set her on the upper floor. Go round to the forecourt and in
## through the front doors, as a player would, then check she is on the
## anchor's floor.
const FORECOURT := Vector3(0, 0, 14)
const PORTICO := Vector3(0, 0, -18)
const ROUND_X := 70.0

func _enter_house(a: Node3D, radius: float) -> bool:
	var p: Vector3 = pt.feyre.global_position
	if p.z < FORECOURT.z - 10.0:
		var side := -ROUND_X
		await pt._walk_to(Vector3(side, 0, minf(p.z, -100.0)), 6.0)
		await pt._walk_to(Vector3(side, 0, FORECOURT.z), 6.0)
	await pt._walk_to(FORECOURT, 4.0)
	await pt._walk_to(PORTICO, 2.0)
	await pt._walk_to(a.global_position, radius)
	var dy: float = pt.feyre.global_position.y - a.global_position.y
	if pt._flat(a.global_position) > radius + 1.0 or absf(dy) > 1.5:
		pt._fail("couldn't stand at %s: %.1f m off, %.1f m above it, at %s" % [a.name, pt._flat(a.global_position), dy, pt._v(pt.feyre.global_position)])
		return false
	return true


## Runs one lane's playtest _play() in this run, sharing its state, and
## renames its beats "<prefix>:<id>". True when all its beats passed.
func _segment(prefix: String, path: String, prepare: Callable = Callable()) -> bool:
	var seg: Node = (load(path) as GDScript).new()
	seg.set(&"chained", true)
	seg.name = "Chain_%s" % prefix
	seg.game = pt.game
	seg.feyre = pt.feyre
	seg.beats = pt.beats
	seg.events = pt.events
	seg.max_wall = INF
	seg.settle_limit = 0.0
	var first: int = pt.beats.size()
	pt.add_child(seg)
	if prepare.is_valid():
		prepare.call(seg)
	await seg._play()
	pt._release_all()
	var ok := true
	for i in range(first, pt.beats.size()):
		var b: Dictionary = pt.beats[i]
		b.id = "%s:%s" % [prefix, b.id]
		if b.get("dev_jump", false):
			b["dev_assist"] = true
		if b.status == "running":
			b.status = "fail"
		ok = ok and b.status == "pass"
	pt._beat = pt.beats[pt.beats.size() - 1] if pt.beats.size() > first else pt._beat
	pt.assists += seg.assists
	pt.assisted_metres += seg.assisted_metres
	pt.workarounds.append_array(seg.workarounds)
	for k: Variant in seg._hop_causes:
		pt._hop_causes[k] = int(pt._hop_causes.get(k, 0)) + int(seg._hop_causes[k])
	seg.queue_free()
	if pt.beats.size() == first:
		pt._log("segment %s played no beats" % prefix)
		return false
	return ok


## Walks toward `near` until the anchor exists (its region streams and builds
## in wall time), then returns it. Fails the current beat when it never shows.
func _reach_anchor(id: StringName, near: Vector3) -> Node3D:
	var a: Node3D = pt._anchor(id)
	if a == null:
		await pt._walk_to(near, 60.0, func() -> bool: return pt._anchor(id) != null, 900.0)
		a = pt._anchor(id)
	if a == null:
		var t0 := Time.get_unix_time_from_system()
		await pt._until_wall(func() -> bool: return pt._anchor(id) != null, 300.0)
		a = pt._anchor(id)
		if a:
			pt._note("waited %.0f s (wall) for '%s' to stream in" % [Time.get_unix_time_from_system() - t0, id])
	if a == null:
		pt._fail("no %s anchor near %s (loaded %s, pending %s)" % [id, near, WorldStreamer.loaded_ids(), WorldStreamer._pending.keys()])
	return a


func _region_center(id: StringName) -> Vector3:
	var r := WorldStreamer.get_region(id)
	return r.center if r else Vector3.ZERO


## The kit the way a player gets it: E at the kitchen's chicken larder, then
## E at the twine on the potting shed's table. Fails the beat (naming what
## was missing) if either pickup isn't there or doesn't land in her bag.
func _gather_snare_kit() -> bool:
	await _walk_house(STUDY_TO_KITCHEN)
	if not await _pick_up(_larder_with(CHICKEN), CHICKEN, "the kitchen's chicken larder"):
		return false
	await _walk_house(KITCHEN_TO_DOORS)
	await pt._walk_to(PORTICO, 2.0)
	await _walk_house(TO_SHED, 2.0)
	if not await _pick_up(pt._find_named(&"SnareTwine"), TWINE, "the potting shed's twine"):
		return false
	pt._note("snare kit: %d loops, baits %s" % [SnarePlan.loops_from(Gameplay.inventory), SnarePlan.baits_in(Gameplay.inventory)])
	return true


func _walk_house(route: Array, radius: float = 1.0) -> void:
	for q: Vector2 in route:
		await pt._walk_to(Vector3(q.x, pt.feyre.global_position.y, q.y), radius)


func _larder_with(item: StringName) -> Node3D:
	var best: Node3D = null
	for n in pt.get_tree().get_nodes_in_group(LarderPickup.GROUP):
		if n is LarderPickup and (n as LarderPickup).item_id == item and (best == null or
				pt._flat((n as Node3D).global_position) < pt._flat(best.global_position)):
			best = n
	return best


func _pick_up(node: Node3D, item: StringName, where: String) -> bool:
	if node == null:
		pt._fail("%s isn't in the world" % where)
		return false
	var before := Gameplay.inventory.count(item)
	var at := node.global_position
	await pt._walk_to(Vector3(at.x, pt.feyre.global_position.y, at.z), 1.2)
	for i in 30:
		pt._turn_camera_to(at)
		await pt.get_tree().physics_frame
	for attempt in 3:
		await pt._press(&"interact")
		if await pt._until(func() -> bool: return Gameplay.inventory.count(item) > before, 1.5):
			pt._note("took %s from %s at %s" % [item, where, pt._v(at)])
			return true
	pt._fail("E at %s gave no %s (%.1f m from it, at %s)" % [where, item, pt._flat(at), pt._v(pt.feyre.global_position)])
	return false


func _clock() -> String:
	return "hour %.1f, day %d, night %s" % [Clock.hour(), Clock.day, Clock.is_night()]
