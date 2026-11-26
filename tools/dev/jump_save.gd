## Dev jump into a save slot (T163): writes a real save that loads at the start
## of a story beat, as if everything before it had been played. Run through
## tools/dev/jump_save.sh (or `make jump BEAT=<beat> SLOT=<1-3>`), which runs
## this twice in a scratch data folder and only then copies the save into the
## owner's real one:
##   tools/mq/godot.sh res://tools/dev/jump_save.tscn -- --beat=beast_door --slot=slot_0
##   tools/mq/godot.sh res://tools/dev/jump_save.tscn -- --beat=beast_door --slot=slot_0 --verify
##
## Making: the real game (story/act1/act1_game.tscn) starts a new story in the
## slot and Feyre is put down at the beat's anchor. Once she stands there, in
## one frame, the deeds, lines heard, items and hour of every earlier beat are
## applied in story order, she is placed, and SaveSystem.save_game writes the
## slot. Nothing gets a physics frame in between, so no scene starts early.
## Verifying: the slot is loaded the way the title's Load does it
## (GameSettings.pending_load_slot), the restored story is compared with the
## file, and the beat's own check runs (beast_door: the BeastDoor scene starts).
##
## Beat ids are act1_playtest's (ACCEPTANCE_BEATS). To jump to another beat,
## give the beats before it their effects in BEATS and the beat a "start".
## Prints JUMP_SAVE_WRITTEN <path> / JUMP_VERIFY ok|fail <why>; exit 0 on success.
extends Node

const GAME_SCENE := "res://story/act1/act1_game.tscn"
const EXIT_GRACE := 15.0
const SPAWN_TIMEOUT := 240.0

## In story order. Each beat: what playing it leaves behind ("deeds" raised as
## deeds, "heard" dialogue lines marked heard, "add" and "sell" items, "night"
## the clock moved to night, "rest" her sleep), and, when it can be jumped to,
## "start": {anchor, near (a node under the anchor she stands beside)}.
const BEATS: Array[Dictionary] = [
	{"id": "spawn"},
	{"id": "hunt_to_clearing"},
	{"id": "wolf_kill", "deeds": ["fact.wolf_spotted", "wolf_killed"]},
	{"id": "skin", "add": {&"obj_wolf_pelt": 1}, "deeds": ["fact.wolf_skinned"]},
	{"id": "pelt_sale", "start": {"anchor": &"act1_fur_stall"},
		"sell": [&"obj_wolf_pelt"], "deeds": ["pelt_sold"], "heard": ["d_pelt_sold", "v_silver"]},
	{"id": "evening", "start": {"anchor": &"act1_cottage_door"},
		"deeds": [CottageEvening.TABLE, CottageEvening.FIRE, CottageEvening.CHANGED, CottageEvening.SAT,
			CottageEvening.SUPPER],
		"heard": ["c_home_coin", "c_home_hungry", "d_wolf_killed", "d_wolf_skinned", "d_wolf_wrap", "f_sorry"]},
	{"id": "sleep", "start": {"anchor": &"act1_cottage_interior", "near": &"BedKeepsake"},
		"deeds": ["fact.mother_bed_seen", CottageEvening.SLEPT], "night": true, "rest": true},
	# Just woken from that sleep, by the bed; the beast comes on its own.
	{"id": "beast_door", "start": {"anchor": &"act1_cottage_interior", "near": &"BedKeepsake"}},
]

var beat_id: String = "beast_door"
var slot: String = "slot_0"
var verify: bool = false
var game: Node
var _exit_watchdog: Thread


static func beat_index(id: String) -> int:
	for i in BEATS.size():
		if BEATS[i].id == id:
			return i
	return -1


## The beat ids that can be jumped to.
static func jumpable() -> PackedStringArray:
	var out := PackedStringArray()
	for b: Dictionary in BEATS:
		if b.has("start"):
			out.append(b.id)
	return out


## Every flag a jump to `id` sets: the deeds and lines of the beats before it.
static func flags_before(id: String) -> PackedStringArray:
	var out := PackedStringArray()
	for i in maxi(beat_index(id), 0):
		for flag: String in BEATS[i].get("deeds", []):
			out.append(flag)
		for line: String in BEATS[i].get("heard", []):
			out.append("dlg." + line)   # DialogueLine's heard flag
	return out


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--beat="):
			beat_id = arg.trim_prefix("--beat=")
		elif arg.begins_with("--slot="):
			slot = arg.trim_prefix("--slot=")
		elif arg == "--verify":
			verify = true
	if not jumpable().has(beat_id):
		_done(2, "JUMP_VERIFY fail no jump to '%s' yet; beats with a start: %s" % [beat_id, ", ".join(jumpable())])
		return
	if not SaveSystem.SLOTS.has(slot):
		_done(2, "JUMP_VERIFY fail unknown slot '%s' (%s)" % [slot, ", ".join(SaveSystem.SLOTS)])
		return
	(_verify if verify else _make).call_deferred()


# --- making ------------------------------------------------------------------

func _make() -> void:
	var start: Dictionary = BEATS[beat_index(beat_id)].start
	SaveSystem.begin_new(slot)
	SaveSystem.autosave_enabled = false   # the one save is the one written below
	game = (load(GAME_SCENE) as PackedScene).instantiate()
	game.set(&"start_anchor", start.anchor)
	game.set(&"opening_shot", "")
	game.set(&"spawn_timeout", 1.0e9)   # her anchor's region builds in the background
	add_child(game)
	if not await _until(func() -> bool: return bool(game.get(&"spawned")), SPAWN_TIMEOUT):
		return _done(1, "JUMP_VERIFY fail never spawned at %s" % start.anchor)
	var feyre := game.get(&"feyre") as Feyre
	if not await _until(func() -> bool: return feyre.is_physics_processing() and feyre.is_on_floor(), 60.0):
		return _done(1, "JUMP_VERIFY fail not standing at %s: %s" % [start.anchor, feyre.global_position])
	await _frames(10)
	# From here to the save, one frame: nothing reacts between.
	var place := _start_spot(start, feyre)
	for i in beat_index(beat_id):
		_apply(BEATS[i], feyre)
	feyre.teleport(place)
	var err := SaveSystem.save_game(slot)
	if err != OK:
		return _done(1, "JUMP_VERIFY fail save_game: %s" % error_string(err))
	print("jump: phase %s, day %d, time %.3f, at %s, coin %d" % [PhaseManager.current_phase, Clock.day,
		Clock.time_of_day, place, Gameplay.inventory.coin])
	_done(0, "JUMP_SAVE_WRITTEN %s" % ProjectSettings.globalize_path("%s/%s.json" % [SaveSystem.SAVE_DIR, slot]))


func _apply(beat: Dictionary, feyre: Feyre) -> void:
	var adds: Dictionary = beat.get("add", {})
	for item: StringName in adds:
		Gameplay.inventory.add(item, int(adds[item]))
	for item: StringName in beat.get("sell", []):
		Gameplay.inventory.sell(item, Gameplay.inventory.count(item))
	if beat.get("night", false):
		CottageBed.skip_to_night()
	for flag: String in beat.get("deeds", []):
		WorldState.raise_deed(flag)
	for line: String in beat.get("heard", []):
		WorldState.set_flag("dlg." + line)
	if beat.get("rest", false) and feyre.vitals:
		feyre.vitals.rest(false)


## Beside the start's "near" node, on the room side of it; else where she stands.
func _start_spot(start: Dictionary, feyre: Feyre) -> Vector3:
	var anchor := _anchor(start.anchor)
	var near := anchor.find_child(String(start.get("near", "")), true, false) as Node3D \
			if anchor and start.has("near") else null
	if near == null:
		return feyre.global_position
	var to_room := anchor.global_position - near.global_position
	to_room.y = 0.0
	var spot := near.global_position + to_room.normalized() * minf(0.9, to_room.length())
	spot.y = feyre.global_position.y
	return spot


# --- verifying ---------------------------------------------------------------

func _verify() -> void:
	var path := "%s/%s.json" % [SaveSystem.SAVE_DIR, slot]
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not saved is Dictionary:
		return _done(1, "JUMP_VERIFY fail %s won't read" % ProjectSettings.globalize_path(path))
	var loaded := [false]
	EventBus.game_loaded.connect(func(_s: String) -> void: loaded[0] = true, CONNECT_ONE_SHOT)
	GameSettings.pending_load_slot = slot   # what the title's Load sets
	game = (load(GAME_SCENE) as PackedScene).instantiate()
	add_child(game)
	if not await _until(func() -> bool: return loaded[0], SPAWN_TIMEOUT):
		return _done(1, "JUMP_VERIFY fail the slot never finished loading")
	var feyre := game.get(&"feyre") as Feyre
	if not await _until(func() -> bool: return feyre.is_physics_processing() and feyre.is_on_floor(), 60.0):
		return _done(1, "JUMP_VERIFY fail not standing after the load: %s" % feyre.global_position)
	var why := _story_differs(saved)
	if why != "":
		return _done(1, "JUMP_VERIFY fail " + why)
	var at := PlayerPlacement.saved_position(saved.providers.get(PlayerPlacement.KEY, {}))
	if at.distance_to(feyre.global_position) > 1.5:
		return _done(1, "JUMP_VERIFY fail she stands at %s, saved at %s" % [feyre.global_position, at])
	why = await _beat_check(feyre)
	if why != "":
		return _done(1, "JUMP_VERIFY fail " + why)
	_done(0, "JUMP_VERIFY ok %s in %s: phase %s, day %d, time %.3f" % [beat_id, slot, PhaseManager.current_phase,
		Clock.day, Clock.time_of_day])


## The restored story against the file: every saved flag, the phase, the day.
func _story_differs(saved: Dictionary) -> String:
	var flags: Dictionary = saved.world_state.get("flags", {})
	for flag: String in flags:
		if WorldState.get_flag(flag) != flags[flag]:
			return "flag %s is %s after the load, %s in the save" % [flag, WorldState.get_flag(flag), flags[flag]]
	for flag in flags_before(beat_id):
		if not WorldState.has_flag(flag):
			return "flag %s from before %s is missing" % [flag, beat_id]
	if String(PhaseManager.current_phase) != String(saved.phase.get("phase", "")):
		return "phase %s after the load, %s in the save" % [PhaseManager.current_phase, saved.phase.get("phase")]
	if Clock.day != int(saved.clock.get("day", -1)):
		return "day %d after the load, %d in the save" % [Clock.day, int(saved.clock.get("day", -1))]
	return ""


## What makes it the beat's start, once loaded. "" when it holds.
func _beat_check(_feyre: Feyre) -> String:
	match beat_id:
		"beast_door":
			if not Clock.is_night():
				return "not night (%.3f)" % Clock.time_of_day
			var door := get_tree().get_first_node_in_group(BeastDoor.GROUP) as BeastDoor
			if door == null:
				return "no BeastDoor in the cottage"
			if not await _until(func() -> bool: return door.running, 30.0):
				return "the beast never came (inside %s, can_start %s)" % [door.get(&"_player_inside"), door.can_start()]
			print("jump: BeastDoor running, beat '%s'" % door.current_beat_label())
			if WorldState.has_flag("fact.cottage_door_broken") or WorldState.has_flag("beast_claim_accepted"):
				return "the door scene was already past its start"
	return ""


# --- helpers -----------------------------------------------------------------

func _anchor(id: StringName) -> Node3D:
	for a in get_tree().get_nodes_in_group(&"story_anchor"):
		if StringName(a.get_meta(&"anchor_id", a.name)) == id:
			return a as Node3D
	return null


func _until(cond: Callable, seconds: float) -> bool:
	var t0 := Time.get_ticks_msec()
	while not cond.call():
		if Time.get_ticks_msec() - t0 > seconds * 1000.0:
			return false
		await get_tree().physics_frame
	return true


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _done(code: int, line: String) -> void:
	if code == 0:
		print(line)
	else:
		printerr(line)
	_exit_watchdog = Thread.new()
	_exit_watchdog.start(_kill_if_still_running.bind(code))
	get_tree().quit(code)


## Runs off the main thread: region builds can make shutdown wait; end anyway.
static func _kill_if_still_running(code: int) -> void:
	OS.delay_msec(int(EXIT_GRACE * 1000.0))
	printerr("jump: shutdown took over %.0f s; killing the process (exit code was %d)" % [EXIT_GRACE, code])
	OS.kill(OS.get_process_id())
