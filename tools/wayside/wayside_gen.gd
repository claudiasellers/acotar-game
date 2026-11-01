## Wayside generator (L23): writes data/wayside/<route>.tres for every walk in
## wayside_routes.gd. A handful of canon set pieces are authored below (the
## pond-faeries, the doe, the drooping lilac, the Silverspring snares, the
## lone sycamore); everything else is placed at a steady cadence along each
## route, a little off the line on alternating sides, from a shuffled bag of
## kinds so no two neighbours are the same. Fixed seed: reruns are identical.
##   godot --headless -s tools/wayside/wayside_gen.gd
extends SceneTree

const ROUTES := preload("res://tools/wayside/wayside_routes.gd")
const OUT_DIR := "res://data/wayside"
const SEED := 2311
## Metres of route with nothing in sight before a spot goes in (≈ 13-18 s at a run).
const CADENCE_MIN := 105.0
const CADENCE_MAX := 145.0
## Generated spots sit this far off the line, alternating sides.
const OFFSET_MIN := 6.0
const OFFSET_MAX := 15.0
## Don't crowd another route's spot (spokes overlap near the manor).
const MIN_SPACING := 40.0
## Leave the start and end alone: the hubs have their own content.
const START_CLEAR := 60.0
const END_CLEAR := 80.0
const MAX_SLOPE_DEG := 22.0
const RIVER_CLEAR := 14.0

const HR := "res://world/human_realm/shared/assets/flora/"

## kind bags (repeats = weight).
const BAG := {
	&"spring_court": [&"nook", &"nook", &"nook", &"vignette", &"vignette", &"vignette", &"rest", &"rest", &"shimmer", &"shimmer"],
	&"human_realm": [&"nook", &"nook", &"vignette", &"vignette", &"rest", &"snare"],
}
const SEATS := {
	&"spring_court": ["fells_overlook_bench", "fae_bench", "rock_mossy_b", "autumn_fallen_log"],
	&"human_realm": [HR + "rock_flat.glb", HR + "log_fallen.glb", HR + "stump.glb"],
}
const SHELLS := {
	&"spring_court": ["rock_mossy_c", "autumn_fallen_log", "rock_mossy_a", "rock_mossy_d"],
	&"human_realm": [HR + "stump.glb", HR + "log_fallen.glb", HR + "rock_boulder_a.glb", HR + "rock_boulder_b.glb"],
}
const CUES := ["lilac", "bunting", "", ""]
## [items, line]. Spring keeps pigments optional (Tamlin supplies paint);
## Act I is where every pigment matters (she has no white paint at all).
const FINDS := {
	&"spring_court": [
		[["col_coin_old"], "An old coin, worn smooth. No face left on it."],
		[["col_old_arrowhead"], "An arrowhead. Someone hunted here, long ago."],
		[["col_feather_kingfisher"], "Kingfisher blue. I could never mix that."],
		[["col_river_glass"], "River glass. Green as the light under the leaves."],
		[["col_stone_quartz"], "A stone with the light caught in it."],
		[["ing_lapis_shard"], "Lapis. Nesta would sell it. I'd grind it for blue."],
		[["ing_madder"], "Madder root. A red worth the digging."],
		[["ing_woad"], "Woad. Blue, if I'm patient with it."],
		[["col_robin_egg_shell"], "A robin's egg, empty. That colour, though."],
		[["col_acorn_carved"], "A carved acorn. Someone's small, careful work."],
		[["col_feather_pheasant", "ing_oak_gall"], "A pheasant feather, and an oak gall for ink."],
		[["col_stone_garnet"], "A garnet in the moss. Like a drop of wine."],
		[["col_snail_spiral"], "A snail shell, a perfect spiral."],
		[["col_silver_leaf"], "A leaf gone silver at the edges."],
	],
	&"human_realm": [
		[["ing_red_ochre"], "Red ochre in the bank cut. Paint, if I had oil."],
		[["ing_charcoal"], "Charcoal. Something to draw with, at least."],
		[["ing_chalk"], "Chalk. The nearest I'll get to white."],
		[["ing_clay"], "Good clay under the snow."],
		[["ing_oak_gall"], "Oak galls. Ink, with a little iron and patience."],
		[["col_old_arrowhead"], "An old arrowhead. Better made than mine."],
		[["col_coin_old"], "A copper, frozen in. That's a loaf, nearly."],
		[["col_horseshoe"], "A thrown shoe. The smith might give a coin for it."],
		[["col_frost_glass"], "Ice like glass, with a leaf caught in it."],
		[["col_snow_owl_down"], "Owl down. Softer than anything we own."],
		[["ing_crow_feather"], "A crow's feather. Fletching, or a quill."],
	],
}
const SPRING_ANIMALS := [
	{"scene": "res://creatures/ambient/scenes/rabbit.tscn", "count": 3, "line": "Rabbits. Fat ones. I don't need to hunt them here."},
	{"scene": "res://creatures/ambient/scenes/squirrel.tscn", "count": 2, "line": "Squirrels, scolding me from the oak."},
	{"scene": "res://creatures/ambient/scenes/songbird_rose.tscn", "count": 3, "line": "A bunting, somewhere. The air smells of hyacinth."},
	{"scene": "res://creatures/ambient/scenes/songbird_blue.tscn", "count": 3, "line": "Birds that colour have no business being real."},
	{"scene": "res://creatures/ambient/scenes/lark.tscn", "count": 2, "line": "A lark going up and up."},
	{"scene": "res://creatures/ambient/scenes/fox.tscn", "count": 1, "line": "A fox. It looked at me like it knew the way."},
]
const WINTER_ANIMALS := [
	{"scene": "res://creatures/ambient/scenes/crow.tscn", "count": 3, "line": "Crows. They always know where the dead things are."},
	{"scene": "res://creatures/ambient/scenes/fox.tscn", "count": 1, "line": "A fox, thin as we are."},
	{"scene": "res://creatures/models/hare.gltf", "count": 1, "graze": true, "line": "A hare, white already. Too far for the bow."},
	{"scene": "res://creatures/models/deer.gltf", "count": 1, "graze": true, "scale": 0.9, "line": "A deer. Too far, and the wind's wrong."},
]
const REST_LINES := {
	&"spring_court": [
		"Viridian. Rose madder. A violet so deep it could be black.",
		"Sap green, and gold where the light comes through. Cerulean above it all.",
		"Cream and blush in the blossom. The shadows are lilac, not grey.",
		"Emerald, then jade, then a blue I don't have a name for.",
		"Butter yellow on the hill. Periwinkle in the distance.",
		"Pearl in the clouds. Moss, and rust, and that pink again.",
		"If I had paints, I'd start with the sky and never finish.",
		"Ochre in the grass, and a cool green where it turns to shade.",
	],
	&"human_realm": [
		"Grey. Grey. And a bruise of lilac where the light gets under the cloud.",
		"Bone white, slate, and the black of the trees. Not one warm colour.",
		"Pewter sky. The snow has blue in it, if you look.",
		"Ash and iron. The only colour is the smoke from the village.",
		"Brown, grey, white. I'd give a week's meat for a red.",
	],
}

var _rng := RandomNumberGenerator.new()
var _placed: Array[Vector2] = []


func _initialize() -> void:
	_rng.seed = SEED
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var total := 0
	for r: Array in ROUTES.ROUTES:
		var route := WaysideRoute.new()
		route.id = r[0]
		route.realm = r[1]
		route.waypoints = PackedVector2Array(r[2])
		route.spots = _authored(route)
		for s in route.spots:
			_placed.append(_flat(s.position))
		route.spots.append_array(_fill(route))
		total += route.spots.size()
		var path := "%s/%s.tres" % [OUT_DIR, route.id]
		var err := ResourceSaver.save(route, path)
		print("%-24s %3d spots %5.0f m %s" % [route.id, route.spots.size(), route.length(), "" if err == OK else "SAVE ERROR %d" % err])
	print("wayside_gen: %d spots on %d routes" % [total, ROUTES.ROUTES.size()])
	quit(0)


# --- Canon set pieces ------------------------------------------------------

func _authored(route: WaysideRoute) -> Array[WaysideSpot]:
	var out: Array[WaysideSpot] = []
	match route.id:
		&"cottage_clearing":
			# The Silverspring grove [C ch 5]: south of the creek's bend on her
			# way into the forest, where the rabbits make their warrens.
			var grove := Vector2(-250.0, 1915.0)
			for i in 6:
				var a := TAU * i / 6.0 + 0.3
				var p := grove + Vector2(cos(a), sin(a)) * _rng.randf_range(10.0, 22.0)
				var s := _spot(&"snare", "%s_snare_%d" % [route.id, i], p, "C?", "ch 5 (the grove south of the big bend in Silverspring Creek)")
				if i == 0:
					s.params["set_line"] = "South of the creek bend. The rabbits make their warrens here."
				out.append(s)
		&"clearing_village":
			for i in 2:
				out.append(_spot(&"snare", "%s_snare_%d" % [route.id, i], Vector2(40.0 + 60.0 * i, 1590.0 + 14.0 * i), "X", "ch 3 (a brace of rabbits)"))
		&"manor_rosewild":
			# The doe she lets "wander on" [C ch 11], in the deer park.
			var doe := _spot(&"vignette", "%s_doe" % route.id, Vector2(30.0, -330.0), "C", "ch 11")
			doe.params = {"scene": "res://creatures/models/deer.gltf", "count": 1, "graze": true, "sketch": "The doe in the deer park"}
			doe.line = "A doe. I let her wander on."
			out.append(doe)
			# The bunting [C ch 7] over a nook by the garden lane.
			var bun := _nook(route, "%s_bunting" % route.id, Vector2(-40.0, -250.0), [["col_wren_feather"], "Followed the bunting. It left me a feather."])
			bun.params["cue"] = "bunting"
			bun.canon = "C?"
			bun.source = "ch 7 (the chirping of a bunting, hyacinth on the breeze)"
			out.append(bun)
		&"manor_fells":
			# The drooping lilac [C ch 9]: cones like cool velvet fingers, and
			# the brush behind it a good hiding place.
			var lilac := _nook(route, "%s_lilac" % route.id, Vector2(-330.0, 260.0), [["ing_lilac", "col_odd_stone"], "Lilac, brushing my cheek. Behind it, a good place to hide."])
			lilac.params["cue"] = "lilac"
			lilac.canon = "C?"
			lilac.source = "ch 9"
			out.append(lilac)
		&"manor_starlight_glen":
			# The pond-faeries [C ch 14]: four shining heads watching from the
			# bright water. Here, a still pool of the Thornwater below the glen.
			var pond := Vector2(-965.0, 100.0)
			var pf := _spot(&"pond_faeries", "%s_pond_faeries" % route.id, pond, "C", "ch 14")
			pf.params = {"water_y": _river_water(pond), "spread": 2.4}
			pf.position.y = _river_water(pond)
			pf.line = "Four heads in the water, watching me. I didn't go any closer."
			out.append(pf)
		&"manor_suriel_glade":
			# The corner shimmer [C ch 14]: only the wind in a lone sycamore
			# on a knoll, on her way to the Suriel.
			var knoll := _highest_near(Vector2(-520.0, 380.0), 60.0)
			var sh := _spot(&"shimmer", "%s_sycamore" % route.id, knoll + Vector2(14.0, 10.0), "C", "ch 14")
			sh.target = _ground3(knoll)
			sh.params = {"tree": "flora_tree_spring_oak", "tree_scale": 1.1, "lifted_line": "Not the wind. Something small and quick, and gone."}
			sh.line = "Only the wind, fluttering the leaves of a lone sycamore."
			out.append(sh)
		&"wall_manor":
			# Sentries on the Wall road [X post; C patrols in shifts, ch 9].
			for i in 3:
				var p := Vector2(-100.0, 1400.0).lerp(Vector2(0.0, 280.0), 0.2 + 0.28 * i) + Vector2(9.0 if i % 2 == 0 else -9.0, 0.0)
				var s := _spot(&"sentry", "%s_sentry_%d" % [route.id, i], p, "X", "ch 9 (sentries patrol in shifts)")
				s.params = {"variant": i}
				s.yaw = PI if i % 2 == 0 else 0.0
				out.append(s)
	out.append_array(_crossings(route))
	return out


## Stepping stones (or a fallen oak, or a footbridge) wherever a Spring
## Court route meets the Thornwater, so the straight run stays a run.
func _crossings(route: WaysideRoute) -> Array[WaysideSpot]:
	var out: Array[WaysideSpot] = []
	if route.realm != &"spring_court":
		return out
	var river := MacroHeight.THORNWATER
	var models := ["stepping_stones", "autumn_fallen_log", "wooden_footbridge_small"]
	var n := 0
	for i in route.waypoints.size() - 1:
		var a := route.waypoints[i]
		var b := route.waypoints[i + 1]
		for j in river.size() - 1:
			var hit: Variant = Geometry2D.segment_intersects_segment(a, b, river[j], river[j + 1])
			if hit == null:
				continue
			var at: Vector2 = hit
			var dir := (b - a).normalized()
			var s := _spot(&"crossing", "%s_crossing_%d" % [route.id, n], at - dir * 13.0, "X", "ch 14 (a stream that takes a running leap)")
			s.target = _ground3(at + dir * 13.0)
			var model: String = models[(hash(String(route.id)) + n) % models.size()]
			s.params = {"model": model, "water_y": _river_water(at), "repeat": model == "stepping_stones", "unit_length": 3.2}
			s.line = ["Dry boots, mostly.", "Better than wading.", "A running leap would have done it. This is nicer."][n % 3]
			out.append(s)
			n += 1
	return out


# --- Cadence fill ----------------------------------------------------------

func _fill(route: WaysideRoute) -> Array[WaysideSpot]:
	var out: Array[WaysideSpot] = []
	var samples: PackedVector2Array = ROUTES.samples(Array(route.waypoints), 1.0)
	var length := float(samples.size() - 1)
	var bag: Array = []
	var last_kind := &""
	var side := 1.0
	var n := 0
	# Walk the route a metre at a time; once it has gone `want` metres with no
	# spot (this route's or a neighbour's) within SEEN, place one here.
	var since := 0.0
	var want := _rng.randf_range(CADENCE_MIN, CADENCE_MAX)
	for i in samples.size():
		var p := samples[i]
		since = 0.0 if _seen(p) else since + 1.0
		if since < want or i < START_CLEAR or i > length - END_CLEAR:
			continue
		var dir := (samples[mini(i + 1, samples.size() - 1)] - samples[maxi(i - 1, 0)]).normalized()
		var normal := Vector2(-dir.y, dir.x) * side
		side = -side
		var spot_pos := Vector2.INF
		for attempt in 8:
			var q := p + normal * _rng.randf_range(OFFSET_MIN, OFFSET_MAX) * (1.0 if attempt % 2 == 0 else -1.0) + dir * _rng.randf_range(0.0, 10.0)
			if _ok(q, route.realm) and not _crowded(q):
				spot_pos = q
				break
		if spot_pos == Vector2.INF:
			continue
		if bag.is_empty():
			bag = BAG[route.realm].duplicate()
			_shuffle(bag)
		var kind: StringName = bag.pop_back()
		if kind == last_kind and not bag.is_empty():
			bag.push_front(kind)
			kind = bag.pop_back()
		last_kind = kind
		var id := "%s_%02d_%s" % [route.id, n, kind]
		out.append(_make(kind, id, route, spot_pos, samples[samples.size() - 1]))
		_placed.append(spot_pos)
		n += 1
		since = 0.0
		want = _rng.randf_range(CADENCE_MIN, CADENCE_MAX)
	return out


func _make(kind: StringName, id: String, route: WaysideRoute, p: Vector2, goal: Vector2) -> WaysideSpot:
	var realm := route.realm
	match kind:
		&"nook":
			var finds: Array = FINDS[realm]
			return _nook(route, id, p, finds[_rng.randi() % finds.size()])
		&"rest":
			var top := _highest_near(p, 18.0)
			if not _ok(top, realm):
				top = p
			var s := _spot(&"rest", id, top, "X", "Keeper: on-voice (she names colours, ch 7)")
			# The view: where she's going, lifted to the skyline.
			var g := _ground3(goal)
			s.target = g + Vector3.UP * 12.0
			s.yaw = atan2(goal.x - top.x, goal.y - top.y)
			var seats: Array = SEATS[realm]
			s.params = {"seat": seats[_rng.randi() % seats.size()], "sketch": "A view on the way to %s" % _place_name(route)}
			var lines: Array = REST_LINES[realm]
			s.line = lines[_rng.randi() % lines.size()]
			return s
		&"vignette":
			var pool: Array = SPRING_ANIMALS if realm == &"spring_court" else WINTER_ANIMALS
			var a: Dictionary = pool[_rng.randi() % pool.size()]
			var s := _spot(&"vignette", id, p, "X", "")
			s.params = a.duplicate()
			s.params.erase("line")
			s.params["sketch"] = "Watching %s" % String(a["scene"]).get_file().get_basename().replace("_", " ")
			s.line = a["line"]
			return s
		&"shimmer":
			var knoll := _highest_near(p, 40.0)
			var s := _spot(&"shimmer", id, p, "C", "ch 14 (the shimmer in the corner of her eye)")
			var by_water := MacroHeight.distance_to_river(p.x, p.y) < 80.0
			s.target = _ground3(knoll)
			if by_water:
				s.line = "Only sunlight, dancing on the stream."
				s.params = {"lifted_line": "Not the light. Something small, and quick, and gone."}
			else:
				s.line = "Only the wind in the leaves."
				s.params = {"tree": "flora_tree_spring_oak", "lifted_line": "Not the wind. Something small, and quick, and gone."}
			return s
		&"snare":
			return _spot(&"snare", id, p, "X", "ch 3 (a brace of rabbits)")
	return _spot(kind, id, p, "X", "")


func _nook(route: WaysideRoute, id: String, p: Vector2, find: Array) -> WaysideSpot:
	var s := _spot(&"nook", id, p, "X", "Keeper: hidden nooks fine; never a mask")
	s.items = PackedStringArray(find[0])
	s.line = find[1]
	var shells: Array = SHELLS[route.realm]
	s.params = {"shell": shells[_rng.randi() % shells.size()], "shell_scale": _rng.randf_range(0.9, 1.2)}
	if route.realm == &"spring_court":
		s.params["cue"] = CUES[_rng.randi() % CUES.size()]
	s.yaw = _rng.randf_range(-PI, PI)
	return s


func _spot(kind: StringName, id: String, p: Vector2, canon: String, source: String) -> WaysideSpot:
	var s := WaysideSpot.new()
	s.kind = kind
	s.id = StringName(id)
	s.position = _ground3(p)
	s.target = s.position
	s.canon = canon
	s.source = source
	return s


# --- Placement rules -------------------------------------------------------

func _ok(p: Vector2, realm: StringName) -> bool:
	if not WorldMap.MAP_RECT.has_point(p):
		return false
	if WorldHeight.slope_at(p.x, p.y) > MAX_SLOPE_DEG:
		return false
	if realm == &"spring_court":
		if MacroHeight.distance_to_river(p.x, p.y) < RIVER_CLEAR:
			return false
		for r: Rect2 in _estate_keepout():
			if r.has_point(p):
				return false
		# Keep clear of the Wall seam and the drive.
		if p.y > WorldMap.WALL_Z - 40.0:
			return false
	else:
		if HumanRealmLayout.distance_to_creek(p) < 8.0 or HumanRealmLayout.distance_to_road(p) < 6.0:
			return false
		for c: Vector2 in [HumanRealmLayout.VILLAGE_SQUARE]:
			if p.distance_to(c) < 140.0:
				return false
		for c: Vector2 in [HumanRealmLayout.COTTAGE, HumanRealmLayout.WORKSHOP, HumanRealmLayout.BURNT_ESTATE, HumanRealmLayout.DOE_CLEARING]:
			if p.distance_to(c) < 45.0:
				return false
		if p.y < WorldMap.WALL_Z + 40.0:
			return false
	return true


func _estate_keepout() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for r: Rect2 in [ManorSitePlan.HOUSE_MAIN, ManorSitePlan.HOUSE_SERVICE, ManorSitePlan.HOUSE_WEST,
			ManorSitePlan.TERRACE, ManorSitePlan.ROSE_GARDEN, ManorSitePlan.HEDGE_MAZE,
			ManorSitePlan.GLASS_HOUSES, ManorSitePlan.KITCHEN_GARDEN, ManorSitePlan.STABLES,
			ManorSitePlan.PADDOCK, ManorSitePlan.WALLED_ORCHARD]:
		out.append(r.grow(10.0))
	var pond := Rect2(ManorSitePlan.POND_CENTER - ManorSitePlan.POND_RADII, ManorSitePlan.POND_RADII * 2.0)
	out.append(pond.grow(8.0))
	# The drive and its kerbs.
	out.append(Rect2(-12.0, 20.0, 24.0, 290.0))
	return out


## A spot reads from the route within this many metres.
const SEEN := 26.0


func _seen(p: Vector2) -> bool:
	for q in _placed:
		if p.distance_to(q) < SEEN:
			return true
	return false


func _crowded(p: Vector2) -> bool:
	for q in _placed:
		if p.distance_to(q) < MIN_SPACING:
			return true
	return false


func _highest_near(p: Vector2, radius: float) -> Vector2:
	var best := p
	var best_h := WorldHeight.height_at(p.x, p.y)
	for k in 24:
		var a := TAU * k / 24.0
		for r in [radius * 0.5, radius]:
			var q: Vector2 = p + Vector2(cos(a), sin(a)) * r
			var h := WorldHeight.height_at(q.x, q.y)
			if h > best_h and WorldHeight.slope_at(q.x, q.y) < MAX_SLOPE_DEG:
				best = q
				best_h = h
	return best


func _river_water(p: Vector2) -> float:
	return MacroHeight.land_height_at(p.x, p.y) - MacroHeight.RIVER_DEPTH + 1.4


func _ground3(p: Vector2) -> Vector3:
	return Vector3(p.x, WorldHeight.height_at(p.x, p.y), p.y)


func _flat(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


func _place_name(route: WaysideRoute) -> String:
	var s := String(route.id)
	var parts := s.split("_", false, 1)
	return parts[1].replace("_", " ") if parts.size() > 1 else s


func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := _rng.randi() % (i + 1)
		var t: Variant = a[i]
		a[i] = a[j]
		a[j] = t
