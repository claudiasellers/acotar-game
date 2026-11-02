## Floor the furniture must leave free for the story: every Act II/III stage
## mark (and the walk routes between them), each story anchor, and the few
## scene positions that live in code rather than in a stage file.
##
## Zones are capsules in world XZ on one level: {level, a, b, r}. A point is a
## capsule with a == b. Marks above the floor (table settings, fixtures) and
## seat/table marks (where furniture belongs) are skipped; marks ending in
## "_yaw" are rotations, not places.
class_name ManorKeepClear
extends RefCounted

## Stage file -> the anchor whose frame its marks are in (story/act2/act2_spaces.gd,
## story/act3/act3_anchors.gd and the scripts that load them).
const STAGES := {
	"res://data/story/act2/first_dinner_stage.tres": &"manor_dining_table",
	"res://data/story/act2/manor_arrival_stage.tres": &"manor_dining_table",
	"res://data/story/act2/curtain_trap_stage.tres": &"feyre_bedroom_window",
	"res://data/story/act2/alis_welcome_stage.tres": &"feyre_bedroom_window",
	"res://data/story/act3/house/wound_dressing_stage.tres": &"manor_infirmary",
	"res://data/story/act3/house/study_mural_stage.tres": &"manor_study_mural",
}
## Scene positions fixed in code, world XZ, level 0 (SummerFaerieTriage:
## TABLE_CENTER, NEAR and FRONT_DOORS; the faerie table stands in the hall).
const FIXED := [
	{"level": 0, "a": Vector2(0.0, -35.0), "b": Vector2(0.0, -35.0), "r": 2.6},
	{"level": 0, "a": Vector2(0.0, -35.0), "b": Vector2(0.0, -28.6), "r": 0.9},
]
## Book moments (StoryMoment) spawn their actors at anchor-local "at" points.
const MOMENTS_DIR := "res://data/story/moments/"
## Playtests that walk Feyre through the ground floor along fixed points
## (const arrays of Vector2 in house XZ); furniture keeps their lines clear.
const WALKS := ["res://tools/playtest/p3_house_playtest.gd", "res://tools/playtest/p3p4_chain.gd"]
const WALK_R := 0.5
const JOIN := 20.0
const MARK_R := 0.6
## Anchors whose stages' table and seat marks are furniture the furnisher
## places itself (every meal at the long table, the supper at the kitchen table).
const FURNISHED_ANCHORS := [&"manor_dining_table", &"manor_alis_hiding"]
## The long table and its chairs in manor_dining_table's frame (L29's set, which
## the meals' scenes move and shrink): their marks along it are not floor.
const TABLE_SET := Rect2(-5.6, -7.9, 11.2, 2.8)
## The story's scene registry: coded moments and the extra scenes per anchor
## (every lane adds its stages there, so new scenes are kept clear too).
const SPACES := "res://story/act2/act2_spaces.gd"
## Room round a table or sink that a scene builds at its mark.
const BUILT_R := 1.0
const ROUTE_R := 0.55
const ANCHOR_R := 0.9


static func zones(anchors: Array) -> Array:
	var by_id := {}
	for a in anchors:
		by_id[a.anchor_id] = a
	var out: Array = FIXED.duplicate(true)
	for a in anchors:
		if a.position.y > 0.4:
			continue        # a wall anchor (a painting's place): the furnisher keeps its wall clear
		var p := Vector2(a.position.x, a.position.z)
		out.append({"level": a.level, "a": p, "b": p, "r": ANCHOR_R, "why": String(a.anchor_id)})
	var stages := all_stages()
	for path: String in stages:
		var anchor = by_id.get(stages[path])
		if anchor == null or not ResourceLoader.exists(path):
			continue
		var stage := load(path) as Act2Stage
		if stage == null:
			continue
		var basis := Basis(Vector3.UP, deg_to_rad(anchor.yaw_deg))
		var route := {}
		for key in stage.marks:
			var name := String(key)
			if name.ends_with("_yaw"):
				continue
			var local: Vector3 = stage.marks[key]
			# above the floor (table settings, fixtures) or where a seat or table
			# is meant to stand: not floor to keep clear
			if local.y > 0.4:
				continue
			# at the dinners the table and chairs are the furnisher's own pieces;
			# elsewhere a "table" or "sink" mark is something the scene builds there
			if FURNISHED_ANCHORS.has(stages[path]) and TABLE_SET.has_point(Vector2(local.x, local.z)):
				continue
			if FURNISHED_ANCHORS.has(stages[path]) and (name.contains("seat") or name.contains("chair") or name.contains("table")):
				continue
			var r := MARK_R
			var built := name.contains("table") or name.contains("sink")
			if built:
				r = BUILT_R
			var w: Vector3 = anchor.position + basis * local
			var p := Vector2(w.x, w.z)
			out.append({"level": anchor.level, "a": p, "b": p, "r": r, "built": built,
					"why": "%s:%s" % [path.get_file(), name]})
			if name.length() > 1 and name[0] == "r" and name.substr(1).is_valid_int():
				route[int(name.substr(1))] = p
		var steps := route.keys()
		steps.sort()
		for i in range(1, steps.size()):
			out.append({"level": anchor.level, "a": route[steps[i - 1]], "b": route[steps[i]], "r": ROUTE_R,
					"why": "%s:route" % path.get_file()})
	out.append_array(_moment_spawns(by_id))
	out.append_array(_walks())
	return out


## Stage file -> anchor id: STAGES plus every stage in Act2Spaces (CODED by
## moment, whose anchor is the moment's; EXTRA by anchor).
static func all_stages() -> Dictionary:
	var out := STAGES.duplicate()
	# read as text: loading the registry would compile the story's scenes,
	# which need the autoloads the layout generators run without
	var src := FileAccess.get_file_as_string(SPACES)
	var key := RegEx.create_from_string("^\\t&\"(\\w+)\": ([\\[{])")
	var stage := RegEx.create_from_string("\"stage\": \"(res://[^\"]+)\"")
	var current := &""
	var is_moment := false
	for line in src.split("\n"):
		var k := key.search(line)
		if k != null:
			current = StringName(k.get_string(1))
			is_moment = k.get_string(2) == "{"
		var m := stage.search(line)
		if m == null or current == &"" or out.has(m.get_string(1)):
			continue
		var anchor := current
		if is_moment:
			var mpath := MOMENTS_DIR + String(current) + ".tres"
			if not ResourceLoader.exists(mpath):
				continue
			var mo := load(mpath) as StoryMoment
			if mo == null:
				continue
			anchor = mo.anchor_id
		out[m.get_string(1)] = anchor
	return out


## The playtest walks' straight legs, read from the scripts' route constants.
static func _walks() -> Array:
	var out: Array = []
	var arrays := RegEx.create_from_string("const (\\w+) := \\[((?:[^\\]]|\\n)*?)\\]")
	var vec := RegEx.create_from_string("Vector2\\(([-0-9.]+), ([-0-9.]+)\\)")
	for path: String in WALKS:
		var src := FileAccess.get_file_as_string(path)
		var last := Vector2.INF
		for m in arrays.search_all(src):
			var pts: Array = []
			for v in vec.search_all(m.get_string(2)):
				pts.append(Vector2(float(v.get_string(1)), float(v.get_string(2))))
			if pts.is_empty():
				continue
			# the routes are written in play order: a short hop from the last
			# route's end to this one's start is walked too
			if last != Vector2.INF and last.distance_to(pts[0]) <= JOIN:
				pts.push_front(last)
			last = pts[-1]
			for i in range(1, pts.size()):
				out.append({"level": 0, "a": pts[i - 1], "b": pts[i], "r": WALK_R,
						"why": "%s:%s" % [path.get_file(), m.get_string(1)]})
	return out


## Where the book moments at the house's anchors spawn their actors.
static func _moment_spawns(by_id: Dictionary) -> Array:
	var out: Array = []
	for file in DirAccess.get_files_at(MOMENTS_DIR):
		if not file.ends_with(".tres"):
			continue
		var m := load(MOMENTS_DIR + file) as StoryMoment
		if m == null or not by_id.has(m.anchor_id):
			continue
		var anchor = by_id[m.anchor_id]
		var basis := Basis(Vector3.UP, deg_to_rad(anchor.yaw_deg))
		for step: Dictionary in m.steps:
			if step.get("at") is Vector3 and (step.at as Vector3).y < 0.4:
				var w: Vector3 = anchor.position + basis * (step.at as Vector3)
				var p := Vector2(w.x, w.z)
				out.append({"level": anchor.level, "a": p, "b": p, "r": MARK_R,
						"why": "%s:%s" % [file, step.get("actor", "spawn")]})
	return out


## Distance from point p to the capsule's spine.
static func distance(zone: Dictionary, p: Vector2) -> float:
	var a: Vector2 = zone.a
	var b: Vector2 = zone.b
	var ab := b - a
	var t := 0.0 if ab.length_squared() < 1e-6 else clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)


## True when a world rect on `level` comes within a zone's radius.
static func hits(zones_list: Array, level: int, rect: Rect2) -> Dictionary:
	for z: Dictionary in zones_list:
		if z.level != level:
			continue
		var c := _closest_in_rect(rect, z.a, z.b)
		if distance(z, c) < z.r:
			return z
	return {}


## A point of `rect` close to segment a-b (good enough for small furniture).
static func _closest_in_rect(rect: Rect2, a: Vector2, b: Vector2) -> Vector2:
	var best := rect.get_center()
	var best_d := INF
	for i in 9:
		var t := i / 8.0
		var s := a.lerp(b, t)
		var c := Vector2(clampf(s.x, rect.position.x, rect.end.x), clampf(s.y, rect.position.y, rect.end.y))
		var d := c.distance_to(s)
		if d < best_d:
			best_d = d
			best = c
	return best
