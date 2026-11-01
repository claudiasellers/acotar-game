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
## when the beat needs night. Where the game gives her no way to carry what the
## jump hands her (the Suriel's snare kit, the faerie's herbs), the chain grants
## it as a WORKAROUND, so the run says what is missing instead of stalling.
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
## What each lane's dev jump hands her (story/act3/dev/p3_jump.gd,
## story/act3/summer/dev/faerie_jump.gd).
const SURIEL_KIT := {&"ing_sinew": 2, &"ing_rabbit": 1, &"ing_salt": 1, &"arrow_ash": 1}
const FAERIE_KIT := {&"ing_yarrow": 2, &"ing_honey": 1, &"ing_fire_lily": 1}

## In play order; the header's acceptance list appends these.
const BEATS: Array[String] = [
	"house:travel", "house:spawn", "house:hall_marks", "house:map_drawn", "house:the_beast",
	"house:to_the_infirmary", "house:wound_dressed", "house:mural",
	"suriel:travel", "suriel:spawn", "suriel:scout_stream", "suriel:set_snare", "suriel:hide_downwind",
	"suriel:suriel_caught", "suriel:answers", "suriel:naga",
	"faerie:travel", "faerie:spawn", "faerie:carried_in", "faerie:triage", "faerie:words", "faerie:hand", "faerie:held",
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
	pt._begin("suriel:travel", "out to the Suriel's glade with what she'd carry from the manor")
	_provide(SURIEL_KIT, "the Suriel snare kit")
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
	_provide(FAERIE_KIT, "the faerie's herbs")
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


## Tops her up to what the lane's dev jump gives, as a workaround naming what
## the game never handed her on the way.
func _provide(kit: Dictionary, what: String) -> void:
	var short: PackedStringArray = []
	for id: StringName in kit:
		var have := Gameplay.inventory.count(id)
		if have < int(kit[id]):
			short.append("%s %d/%d" % [id, have, kit[id]])
	if short.is_empty():
		pt._note("carrying %s already" % what)
		return
	pt._workaround("no in-game source on the way for %s (%s); granted" % [what, ", ".join(short)], func() -> void:
		for id: StringName in kit:
			var have := Gameplay.inventory.count(id)
			if have < int(kit[id]):
				Gameplay.inventory.add(id, int(kit[id]) - have))


func _clock() -> String:
	return "hour %.1f, day %d, night %s" % [Clock.hour(), Clock.day, Clock.is_night()]
