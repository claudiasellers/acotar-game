## Headless tour of free-roam dialogue (lane L34): loads the real game, then
## sets Feyre down at stops across the realms and phases and logs every line
## spoken and every cast member standing there. It writes flags only to set up
## each stop's phase (a dev jump, like story/act3/dev); the lines it checks
## write nothing but dlg.*.
##
## Run (built files in place: tools/mq/levels.sh ensure):
##   tools/mq/godot.sh --fixed-fps 30 res://tools/dialogue/dialogue_tour.tscn -- --out=/tmp/dialogue_tour.json
## Passes (exit 0) when every stop hears at least `min_lines` lines, has its
## `expect` speakers standing there and speaking, and no presence node is a
## stand-in or carries a primitive mesh.
extends Node

const GAME_SCENE := "res://story/act1/act1_game.tscn"
const PHASES := "res://data/phases/spring_court_phases.tres"
const SETTLE := 12.0

## {name, phase, flags, hour, at (world, or house space with "house"), expect
## (speakers that must speak), walk (points to stroll through, relative to at)}
var stops: Array[Dictionary] = [
	{"name": "cottage", "phase": &"p0_winter", "flags": ["wolf_killed", "fact.wolf_skinned"], "hour": 18.0,
		"anchor": &"act1_cottage_interior", "at": Vector3(1.6, 0.0, 0.4),
		"walk": [Vector3(0, 0, 0), Vector3(1.0, 0, 1.2), Vector3(1.4, 0, -0.8), Vector3(2.0, 0, 0.5)],
		"expect": ["nesta", "elain", "father"]},
	{"name": "village", "phase": &"p0_winter", "flags": ["wolf_killed", "fact.wolf_skinned"], "hour": 11.0,
		"at": Vector3(378.0, 0.0, 2247.0),
		"walk": [Vector3(0, 0, 0), Vector3(-5, 0, -2), Vector3(7, 0, 5), Vector3(9, 0, 16), Vector3(-14, 0, 8)],
		"expect": ["blessed", "villager"]},
	{"name": "grounds", "phase": &"p2_grounds", "flags": ["first_dinner_eaten", "curtain_trap_set"], "hour": 14.0,
		"at": Vector3(-30.0, 0.0, -112.0), "walk": [Vector3(0, 0, 0), Vector3(-3, 0, -4), Vector3(10, 0, -30)],
		"expect": ["lucien"]},
	{"name": "dressing_room", "phase": &"p2_grounds", "flags": ["first_dinner_eaten"], "hour": 9.0, "house": 1,
		"at": Vector3(34.0, 0.0, -64.0), "walk": [Vector3(0, 0, 0), Vector3(1.5, 0, -1.5)], "expect": ["alis"]},
	{"name": "study", "phase": &"p3_house_and_woods",
		"flags": ["first_dinner_eaten", "curtain_trap_set", "bogge_survived", "puca_resisted", "study_mural_seen"],
		"hour": 18.5, "house": 0, "at": Vector3(-13.0, 0.0, -64.0), "walk": [Vector3(0, 0, 0), Vector3(-1, 0, -1.5)],
		"expect": ["tamlin"]},
	{"name": "fae_village", "phase": &"p4_wider_court", "flags": [], "hour": 12.0, "at": Vector3(-940.0, 0.0, -878.0),
		"walk": [Vector3(0, 0, 0), Vector3(-4, 0, 3), Vector3(3, 0, 6), Vector3(0, 0, -6), Vector3(-50, 0, -27),
			Vector3(-112, 0, 25)],
		"expect": ["reveler"]},
	{"name": "fae_village_after_glamour", "phase": &"p6_blight_tightens", "flags": ["glamour_lifted"], "hour": 12.0,
		"at": Vector3(-940.0, 0.0, -878.0), "walk": [Vector3(0, 0, 0)], "expect": ["court_fae"]},
	{"name": "calanmai_hill", "phase": &"p5_calanmai", "flags": [], "hour": 21.0, "at": Vector3(556.0, 0.0, -856.0),
		"walk": [Vector3(0, 0, 0), Vector3(10, 0, -8)], "expect": ["reveler"]},
	{"name": "kitchen_after_glamour", "phase": &"p6_blight_tightens", "flags": ["glamour_lifted"], "hour": 13.0,
		"house": 0, "at": Vector3(47.0, 0.0, -60.0), "walk": [Vector3(0, 0, 0), Vector3(-1.5, 0, 1.5)],
		"expect": ["servant_cook", "alis"]},
	{"name": "solstice", "phase": &"p6_blight_tightens", "flags": ["glamour_lifted"], "hour": 15.0,
		"at": Vector3(-62.0, 0.0, -1038.0), "walk": [Vector3(0, 0, 0), Vector3(-4, 0, 3), Vector3(6, 0, -2)],
		"expect": ["reveler"]},
	{"name": "blighted_reaches", "phase": &"p6_blight_tightens", "flags": ["glamour_lifted"], "hour": 15.0,
		"at": Vector3(300.0, 0.0, -1595.0), "walk": [Vector3(0, 0, 0)], "expect": []},
]

var game: Node
var feyre: Node3D
var director: DialogueDirector
var presence: CastPresence
var report: Dictionary = {"stops": [], "pass": true}
var _heard: Array = []
var _out := "/tmp/dialogue_tour.json"
## --from=<stop name> starts the tour there (to rerun the tail of a long tour).
var _from := ""
## --only=<stop name> visits just that stop.
var _only := ""


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.trim_prefix("--out=")
		elif a.begins_with("--only="):
			_only = a.trim_prefix("--only=")
		elif a.begins_with("--from="):
			_from = a.trim_prefix("--from=")
	_run.call_deferred()


func _run() -> void:
	game = (load(GAME_SCENE) as PackedScene).instantiate()
	get_tree().root.add_child(game)
	await _wait(SETTLE)
	feyre = get_tree().get_first_node_in_group(&"player") as Node3D
	director = get_tree().get_first_node_in_group(DialogueDirector.GROUP) as DialogueDirector
	presence = game.get_node_or_null(^"CastPresence") as CastPresence
	if feyre == null or director == null or presence == null:
		_finish("missing: feyre %s director %s presence %s" % [feyre != null, director != null, presence != null])
		return
	director.line_spoken.connect(func(id: StringName, speaker: StringName, text: String, _at: Vector3, inner: bool) -> void:
		_heard.append({"id": String(id), "speaker": String(speaker), "text": text, "inner": inner}))
	EventBus.scene_space_started.connect(func(id: StringName) -> void: print("TOUR scene start ", id))
	EventBus.scene_space_finished.connect(func(id: StringName) -> void: print("TOUR scene end ", id))
	var started := _from == ""
	for stop in stops:
		started = started or stop["name"] == _from
		if _only != "" and stop["name"] != _only:
			continue
		if started:
			await _visit(stop)
	_finish("")


func _visit(stop: Dictionary) -> void:
	_heard.clear()
	WorldState.clear()
	for f: String in stop["flags"]:
		WorldState.set_flag(f, true)
	# Walk the ladder so every earlier phase's regions are unlocked too, as
	# in play (a bare start() unlocks only the target phase's own).
	var ladder := ["p0_winter", "p1_wolf_and_crossing", "p2_grounds", "p3_house_and_woods", "p4_wider_court",
		"p5_calanmai", "p6_blight_tightens"]
	PhaseManager.start(load(PHASES) as PhaseSet, &"p0_winter")
	for id: String in ladder.slice(1, ladder.find(String(stop["phase"])) + 1):
		PhaseManager._enter_phase(StringName(id))
	Clock.time_of_day = float(stop["hour"]) / 24.0
	var base := _where(stop, Vector3.ZERO)
	_place(base)
	# Wait for her region to stream in (wide-court regions take a while in the cloud).
	var waited := 0.0
	var here := WorldStreamer.region_at(base)
	while here and not WorldStreamer.loaded_ids().has(String(here.id)) and waited < 60.0:
		await _wait(2.0)
		waited += 2.0
		_place(base)
	print("TOUR %s: region %s loaded after %.0f s" % [stop["name"], here.id if here else &"?", waited])
	base = _where(stop, Vector3.ZERO)
	_place(base)
	await _wait(SETTLE)
	# Let the stop's set-up deeds have their say before walking up to people.
	var drain := 0.0
	while not director._deed_queue.is_empty() and drain < 90.0:
		await _wait(2.0)
		drain += 2.0
	var walk: Array = stop["walk"]
	for w: Vector3 in walk:
		Clock.time_of_day = float(stop["hour"]) / 24.0
		_place(_where(stop, w))
		await _wait(6.0)
	# Then up to each person standing nearby, the way a player wanders over.
	for node in presence.get_children():
		if not is_instance_valid(node):
			continue
		var n3 := node as Node3D
		if n3 == null or n3.global_position.distance_to(base) > 70.0:
			continue
		Clock.time_of_day = float(stop["hour"]) / 24.0
		var front := n3.global_transform.basis.z.normalized() * -2.5
		if stop.has("anchor"):
			# Indoors, from the room's side of them (they may face a wall).
			var mid := _where(stop, Vector3.ZERO) - n3.global_position
			front = Vector3(mid.x, 0.0, mid.z).normalized() * 2.0
		_place(n3.global_position + Vector3(front.x, 0.0, front.z))
		# And looks at them: the family speaks only face to face (L34-5).
		await _face(n3, 12.0)
	var standing: Array = []
	var bad: Array = []
	for node in presence.get_children():
		if not is_instance_valid(node):
			continue
		standing.append(String(node.get_meta(&"speaker", node.name)))
		var at3 := (node as Node3D).global_position if node is Node3D else Vector3.ZERO
		if stop.has("anchor") and presence._find_anchor(stop["anchor"]):
			at3 = presence._find_anchor(stop["anchor"]).global_transform.affine_inverse() * at3
		print("TOUR   %s at %s" % [node.name, at3])
		bad.append_array(_primitives(node))
	var speakers := {}
	for h in _heard:
		speakers[h["speaker"]] = true
	var missing: Array = []
	for e: String in stop["expect"]:
		var hit := speakers.has(e)
		if not hit:
			for s: String in speakers:
				if DialogueRules.keys_for(StringName(s)).has(e) or DialogueRules.group_of(s) == e:
					hit = true
		if not hit:
			missing.append(e)
	var ok: bool = _heard.size() >= 2 and missing.is_empty() and bad.is_empty() \
			and PhaseManager.current_phase == stop["phase"]
	var entry := {"stop": stop["name"], "phase": String(PhaseManager.current_phase), "region": String(director.region_id),
		"room": String(director.room_id), "lines": _heard.duplicate(), "standing": standing, "missing": missing,
		"primitives": bad, "pass": ok}
	report["stops"].append(entry)
	if not ok:
		report["pass"] = false
	print("TOUR mode %d loaded %s" % [StoryControl.mode, WorldStreamer.loaded_ids()])
	print("TOUR %s %s: %d lines, standing %s, missing %s, primitives %d" % [
		"pass" if ok else "FAIL", stop["name"], _heard.size(), standing, missing, bad.size()])
	for h in _heard:
		print("   [%s] %s" % [h["speaker"], h["text"]])


func _where(stop: Dictionary, offset: Vector3) -> Vector3:
	var at: Vector3 = stop["at"] + offset
	if stop.has("anchor"):
		var anchor := presence._find_anchor(stop["anchor"])
		return anchor.global_transform * at if anchor else at
	if stop.has("house"):
		var house := presence._find_house()
		var local := Vector3(at.x, ManorHouseBuilder.floor_y(int(stop["house"])), at.z)
		return house.to_global(local) if house else local
	return Vector3(at.x, WorldHeight.height_at(at.x, at.z), at.z)


func _place(at: Vector3) -> void:
	WorldStreamer.update_for(at)
	PlayerPlacement.new(feyre).load_state({"position": [at.x, at.y + 0.3, at.z]})


func _primitives(node: Node) -> Array:
	var out: Array = []
	if String(node.name).begins_with("StandIn_"):
		out.append(str(node.get_path()))
	if node is MeshInstance3D and (node as MeshInstance3D).mesh is PrimitiveMesh and (node as MeshInstance3D).is_visible_in_tree():
		out.append(str(node.get_path()))
	for c in node.get_children():
		out.append_array(_primitives(c))
	return out


## Turns her camera to `node` for `seconds`, as a player looks at who's there.
func _face(node: Node3D, seconds: float) -> void:
	var t := 0.0
	while t < seconds and is_instance_valid(node):
		var cam: Camera3D = feyre.get(&"camera")
		if cam and feyre.has_method(&"nudge_camera"):
			var want := (node.global_position + Vector3.UP * 1.5 - cam.global_position).normalized()
			var have := -cam.global_basis.z
			var dyaw := wrapf(atan2(-want.x, -want.z) - atan2(-have.x, -have.z), -PI, PI)
			var dpitch := asin(clampf(want.y, -1, 1)) - asin(clampf(have.y, -1, 1))
			feyre.call(&"nudge_camera", dyaw * 0.5, dpitch * 0.5)
		await get_tree().process_frame
		t += get_process_delta_time()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _finish(error: String) -> void:
	if error != "":
		report["pass"] = false
		report["error"] = error
		print("TOUR error: ", error)
	var f := FileAccess.open(_out, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(report, "  "))
	print("TOUR exit %d" % (0 if report["pass"] else 1))
	get_tree().quit(0 if report["pass"] else 1)
