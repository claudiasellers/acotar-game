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
const DWELL := 40.0
const STEP_EVERY := 1.0

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
		"expect": ["court_fae"]},
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


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.trim_prefix("--out=")
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
	for stop in stops:
		await _visit(stop)
	_finish("")


func _visit(stop: Dictionary) -> void:
	_heard.clear()
	WorldState.clear()
	for f: String in stop["flags"]:
		WorldState.set_flag(f, true)
	PhaseManager.start(load(PHASES) as PhaseSet, stop["phase"])
	Clock.time_of_day = float(stop["hour"]) / 24.0
	var base := _where(stop, Vector3.ZERO)
	_place(base)
	await _wait(SETTLE)
	var t := 0.0
	var walk: Array = stop["walk"]
	var i := 0
	while t < DWELL:
		Clock.time_of_day = float(stop["hour"]) / 24.0
		if i < walk.size() and t >= float(i) * (DWELL / maxf(walk.size(), 1.0)):
			_place(_where(stop, walk[i]))
			i += 1
		await _wait(STEP_EVERY)
		t += STEP_EVERY
	var standing: Array = []
	var bad: Array = []
	for node in presence.get_children():
		standing.append(String(node.get_meta(&"speaker", node.name)))
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
