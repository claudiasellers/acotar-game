## Route audit (L23): what can Feyre see, pick or do along the walks between
## hubs? Loads region scenes one at a time headless, waits for their builders,
## collects every point of interest by group, then walks each route in 5 m
## steps and prints the longest stretches with nothing to do.
##   godot --headless -s tools/wayside/route_audit.gd -- [region_id ...]
## Writes the raw points to user://route_audit_points.json so a rerun of just
## the route maths (`-- --cached`) takes seconds.
extends SceneTree

const RUN_SPEED := 10.686
const STEP := 5.0
## A thing counts as "along the way" within this many metres of the line.
const NEAR := 18.0
const LANDMARK_NEAR := 60.0
## A bench, a doe or a sentry reads from further off than a herb.
const WAYSIDE_NEAR := 30.0
const SETTLE_MS := 4000
const MAX_MS := 90000
const CACHE := "user://route_audit_points.json"
const STREAMER := preload("res://core/streaming/world_streamer.gd")

const M := Vector2(0, -28)  # the manor's front door
## [name, waypoints]. Human-realm routes follow HumanRealmLayout's roads and
## paths; Spring Court routes are the straight line a player runs on the map.
var ROUTES := [
	["cottage -> clearing", [Vector2(-150, 2160), Vector2(-200, 2050), Vector2(-300, 1900), Vector2(-380, 1780), Vector2(-360, 1660)]],
	["clearing -> village", [Vector2(-360, 1660), Vector2(-200, 1640), Vector2(100, 1600), Vector2(150, 1950), Vector2(300, 2120), Vector2(380, 2250)]],
	["village -> cottage (road)", [Vector2(380, 2250), Vector2(150, 2230), Vector2(-20, 2200), Vector2(-150, 2160)]],
	["cottage -> workshop (road)", [Vector2(-150, 2160), Vector2(-330, 2230), Vector2(-560, 2240)]],
	["village -> wall gap (road)", [Vector2(380, 2250), Vector2(300, 2120), Vector2(150, 1950), Vector2(0, 1700), Vector2(-80, 1500), Vector2(-100, 1400)]],
	["wall gap -> sentry gate", [Vector2(-100, 1400), Vector2(0, 280)]],
	["sentry gate -> manor (drive)", [Vector2(0, 280), M]],
	["manor -> suriel glade", [M, Vector2(-825, 625)]],
	["manor -> starlight glen", [M, Vector2(-596, -90), Vector2(-790, 12), Vector2(-995, 105), Vector2(-1192, 268)]],
	["manor -> fae village", [M, Vector2(-470, -496), Vector2(-680, -700), Vector2(-790, -748), Vector2(-930, -790)]],
	["manor -> rose spire", [M, Vector2(0, -496), Vector2(-60, -650), Vector2(-320, -660)]],
	["manor -> solstice meadow", [M, Vector2(0, -496), Vector2(-60, -650), Vector2(-142, -822), Vector2(-150, -1060)]],
	["manor -> hill of the rite", [M, Vector2(450, -496), Vector2(572, -640), Vector2(555, -790), Vector2(560, -990), Vector2(620, -1050), Vector2(860, -1140)]],
	["manor -> eastern woods", [M, Vector2(1250, -50)]],
	["manor -> blossom vale", [M, Vector2(560, 302), Vector2(575, 500), Vector2(720, 700), Vector2(1000, 880)]],
	["manor -> fells foot", [M, Vector2(-1300, 900)]],
]

var points: Array = []  # [kind, x, z, label]
var _grid := {}
const CELL := 60.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := Array(OS.get_cmdline_user_args())
	if args.has("--cached") and FileAccess.file_exists(CACHE):
		points = JSON.parse_string(FileAccess.get_file_as_string(CACHE))
	else:
		var defs := STREAMER.find_region_defs("res://data/regions")
		for def: RegionDef in defs:
			var only := args.filter(func(a: String) -> bool: return not a.begins_with("--"))
			if not only.is_empty() and not only.has(String(def.id)):
				continue
			await _scan(def)
		var f := FileAccess.open(CACHE, FileAccess.WRITE)
		f.store_string(JSON.stringify(points))
	if not args.has("--before"):
		_add_wayside()
	_report()
	quit(0)


## The wayside spots count as moments ("--before" leaves them out).
func _add_wayside() -> void:
	for file in DirAccess.get_files_at("res://data/wayside"):
		var route := load("res://data/wayside/" + file.trim_suffix(".remap")) as WaysideRoute
		if route == null:
			continue
		for spot in route.spots:
			points.append(["wayside_" + String(spot.kind), spot.position.x, spot.position.z, String(spot.id)])


func _scan(def: RegionDef) -> void:
	var scene := load(def.scene_path) as PackedScene
	if scene == null:
		return
	var t0 := Time.get_ticks_msec()
	var node := scene.instantiate()
	root.add_child(node)
	var last := -1
	var since := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < MAX_MS:
		await process_frame
		var n := _count()
		if n != last:
			last = n
			since = Time.get_ticks_msec()
		elif n > 0 and Time.get_ticks_msec() - since > SETTLE_MS:
			break
	var before := points.size()
	_collect(String(def.id))
	print("scan %-18s %5d points  %5d ms" % [def.id, points.size() - before, Time.get_ticks_msec() - t0])
	node.queue_free()
	await process_frame
	await process_frame


func _count() -> int:
	var n := 0
	for g in [&"forage_field", &"forage", &"landmark", &"notice_point", &"station", &"harvestable", &"creature_spot", &"story_anchor"]:
		n += get_nodes_in_group(g).size()
	return n


func _collect(region: String) -> void:
	for chunk in get_nodes_in_group(&"forage_field"):
		if not chunk is MultiMeshInstance3D:
			continue
		var ing := String(chunk.get_meta(&"ingredient_id", ""))
		var kind := "collectible" if ing.begins_with("col_") else "forage"
		var mm: MultiMesh = (chunk as MultiMeshInstance3D).multimesh
		if mm == null:
			continue
		for i in mm.instance_count:
			var p := ScatterField.instance_position(chunk, i)
			points.append([kind, p.x, p.z, ing])
	for g in [&"forage", &"landmark", &"notice_point", &"station", &"harvestable", &"creature_spot", &"story_anchor"]:
		for n in get_nodes_in_group(g):
			if n is Node3D and (n as Node3D).is_inside_tree():
				var p: Vector3 = (n as Node3D).global_position
				var kind := String(g)
				if g == &"forage":
					var ing := String(n.get(&"ingredient_id")) if &"ingredient_id" in n else ""
					kind = "collectible" if ing.begins_with("col_") else "forage"
				points.append([kind, p.x, p.z, "%s/%s" % [region, n.name]])


func _report() -> void:
	var counts := {}
	for p in points:
		counts[p[0]] = int(counts.get(p[0], 0)) + 1
	print("points by kind: ", counts)
	for i in points.size():
		var key := Vector2i(floori(points[i][1] / CELL), floori(points[i][2] / CELL))
		if not _grid.has(key):
			_grid[key] = []
		_grid[key].append(i)
	print("%-34s %6s %6s %8s %8s %8s %8s %6s" % ["route", "m", "run s", "maxGapAll", "maxGapBeat", "maxGapMoment", "picks/min", "beats"])
	for r in ROUTES:
		var samples := _samples(r[1])
		var length := (samples.size() - 1) * STEP
		var gap_all := 0.0
		var gap_beat := 0.0
		var run_all := 0.0
		var run_beat := 0.0
		var gap_moment := 0.0
		var gap_at := Vector2.ZERO
		var run_moment := 0.0
		var picks := {}
		var beats := {}
		for q: Vector2 in samples:
			var any := false
			var beat := false
			var moment := false
			for i: int in _near(q):
				var p: Array = points[i]
				var d := q.distance_to(Vector2(p[1], p[2]))
				var k: String = p[0]
				if k == "landmark":
					if d < LANDMARK_NEAR:
						beat = true
						moment = true
						beats[i] = true
					continue
				if d > (WAYSIDE_NEAR if k.begins_with("wayside_") else NEAR):
					continue
				any = true
				if k == "forage":
					picks[i] = true
				elif k != "story_anchor":
					beat = true
					if k != "collectible":
						moment = true
					beats[i] = true
			run_all = 0.0 if any else run_all + STEP
			run_beat = 0.0 if beat else run_beat + STEP
			gap_all = maxf(gap_all, run_all)
			gap_beat = maxf(gap_beat, run_beat)
			run_moment = 0.0 if moment else run_moment + STEP
			if run_moment > gap_moment:
				gap_moment = run_moment
				gap_at = q
		var secs := length / RUN_SPEED
		print("%-34s %6.0f %6.0f %7.0fs %7.0fs %7.0fs %8.1f %6d  gap ends (%.0f, %.0f)" % [r[0], length, secs,
				gap_all / RUN_SPEED, gap_beat / RUN_SPEED, gap_moment / RUN_SPEED, picks.size() / maxf(secs / 60.0, 0.01), beats.size(), gap_at.x, gap_at.y])


func _samples(waypoints: Array) -> PackedVector2Array:
	var out := PackedVector2Array([waypoints[0]])
	var carry := 0.0
	for i in waypoints.size() - 1:
		var a: Vector2 = waypoints[i]
		var b: Vector2 = waypoints[i + 1]
		var d := a.distance_to(b)
		var t := STEP - carry
		while t <= d:
			out.append(a.lerp(b, t / d))
			t += STEP
		carry = d - (t - STEP)
	return out


func _near(q: Vector2) -> Array:
	var out := []
	var c := Vector2i(floori(q.x / CELL), floori(q.y / CELL))
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			out.append_array(_grid.get(c + Vector2i(dx, dz), []))
	return out
