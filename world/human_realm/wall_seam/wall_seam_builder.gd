## Builds the ScatterLayers of the wall seam: the mortal side of the Wall, a
## dead-quiet strip villagers avoid (x -900..700, z 1400..1480). Sparse but
## never empty: offerings and ribbons left by the Children of the Blessed,
## warning cairns, bones, a lost boot, the villagers' iron stakes. No birds.
## Snow stops in a line at z = 1400: nothing is placed north of it, and drifts
## bank up against the invisible line.
class_name WallSeamBuilder
extends RefCounted

const SEED := 14001
const GAP := Vector2(WorldMap.WALL_GAP_X, WorldMap.WALL_Z)
## The ride north's last stretch (village north road) to the gap.
const ROAD_IN := Vector2(-80.0, 1500.0)
const GREAT_CAIRN := Vector2(-72.0, 1456.0)
const OFFERING_POST := Vector2(-121.0, 1424.0)
const IRON_POST := Vector2(-86.0, 1432.0)
## The iron stake fence the villagers drove in, across the approach.
const FENCE_Z := 1436.0
const FENCE_X := Vector2(-320.0, 120.0)

var rect: Rect2
var rng := RandomNumberGenerator.new()
var layers: Array[ScatterLayer] = []
var by_id := {}


func _init() -> void:
	rect = HumanRealmLayout.REGION_RECTS[&"wall_seam"]


static func exclusions() -> Array:
	return [
		Vector3(GAP.x - 5.0, GAP.y + 2.0, 2.5), Vector3(GAP.x + 5.0, GAP.y + 2.0, 2.5),
		Vector3(GREAT_CAIRN.x, GREAT_CAIRN.y, 3.0), Vector3(OFFERING_POST.x, OFFERING_POST.y, 1.2),
		Vector3(IRON_POST.x, IRON_POST.y, 1.2),
	]


func build(seed: int = SEED, area: Rect2 = Rect2()) -> Array[ScatterLayer]:
	if area.has_area():
		rect = area.intersection(HumanRealmLayout.REGION_RECTS[&"wall_seam"])
	rng.seed = seed
	layers.clear()
	by_id.clear()
	_make_layers()
	_drifts()
	_dressing()
	_fence()
	_forage()
	_interest()
	var out: Array[ScatterLayer] = []
	for l in layers:
		if l.count() > 0:
			out.append(l)
	return out


func free_ground(p: Vector2, road := 1.0) -> bool:
	return rect.has_point(p) and p.y >= WorldMap.WALL_Z + 0.5 and ForestGenUtil.off_road(p, road) \
		and ForestGenUtil.off_creek(p, 0.5) and ForestGenUtil.off_path(p, 0.2) and ForestGenUtil.clear_of(p, exclusions())


func _add(l: ScatterLayer) -> ScatterLayer:
	layers.append(l)
	by_id[l.id] = l
	return l


func _make_layers() -> void:
	var F := ForestGenUtil.FLORA
	var SP := ForestGenUtil.SEAM_PROPS
	var FP := ForestGenUtil.FOREST_PROPS
	var drift := _add(ForestGenUtil.layer(&"wall_drift", SP % "snow_drift", &"", [], "C", true))
	drift.draw_distance = 250.0
	var snags := _add(ForestGenUtil.tree_layer(&"tree_snag", "tree_dead_snag", "X"))
	snags.wind = 0.05
	for d: Array in [[&"snow_mound", F % "snow_mound", "C"], [&"grass_tuft", F % "winter_grass_tuft", "X"],
			[&"bracken", F % "dead_bracken", "X"], [&"boulder_a", F % "rock_boulder_a", "X"], [&"boulder_c", F % "rock_boulder_c", "X"],
			[&"rock_flat", F % "rock_flat", "X"], [&"stump", F % "stump", "X"]]:
		_add(ForestGenUtil.layer(d[0], d[1], &"", [], d[2], true, 0.3 if d[0] in [&"grass_tuft", &"bracken"] else 0.0))
	for f: Array in [
			[&"iron_filings", SP % "iron_stake", &"ing_iron_filings"],  # rust-flaked stakes: scrape the filings
			[&"flint", F % "flint_nodule", &"ing_flint"], [&"chalk", F % "chalk_lump", &"ing_chalk"],
			[&"ice_moss", F % "ice_moss", &"ing_ice_moss"], [&"juniper", F % "juniper_shrub", &"ing_juniper_berry"],
			[&"rose_briar", F % "wild_rose_briar", &"ing_rose_hip"], [&"blackberry", F % "blackberry_bramble", &"ing_blackberry"],
			[&"hawthorn", F % "hawthorn", &"ing_hawthorn_haw"], [&"blackthorn", F % "blackthorn_sloe", &"ing_sloe"],
			[&"tinder_fungus", F % "tinder_fungus", &"ing_tinder_fungus"], [&"snail_shells", F % "snail_shells", &"ing_snail_shell"],
			[&"red_ochre", F % "red_ochre_rock", &"ing_red_ochre"], [&"wintergreen", F % "wintergreen_patch", &"ing_wintergreen"],
			[&"charcoal", F % "charcoal_lump", &"ing_charcoal"], [&"shed_antler", F % "shed_antler", &"ing_shed_antler"],
			[&"snowdrop", F % "snowdrop_cluster", &"ing_snowdrop"], [&"old_mans_beard", F % "old_mans_beard", &"ing_old_mans_beard"],
		]:
		_add(ForestGenUtil.layer(f[0], f[1], f[2], [], "C" if f[0] == &"shed_antler" else "X", true, 0.15 if f[0] in [&"juniper", &"rose_briar", &"hawthorn", &"blackthorn", &"blackberry"] else 0.0))
	for c: Array in [[&"offering_bundle", SP], [&"frozen_ribbon", FP], [&"pamphlet", FP], [&"bone_token", FP],
			[&"lost_boot", SP], [&"candle_stub", SP], [&"child_mitten", SP], [&"tin_charm", SP]]:
		_add(ForestGenUtil.layer(c[0], c[1] % c[0], &"", ["collectible"], "X"))
	for k: Array in [[&"warning_cairn", "X"], [&"deer_bones", "C"], [&"iron_stake", "X"], [&"tracks_end", "X"], [&"salt_ring", "X"]]:
		var l := _add(ForestGenUtil.layer(k[0], SP % k[0], &"", ["look"], k[1]))
		if k[0] == &"warning_cairn" or k[0] == &"iron_stake":
			l.draw_distance = 160.0


func _put(id: StringName, p: Vector2, yaw: float, s: float, lift := 0.0) -> void:
	ForestGenUtil.put(by_id[id], p.x, p.y, yaw, s, lift)


## Snow banked against the invisible line: a continuous run of drifts whose
## flat north face sits on z = 1400 (yaw PI turns the face north).
func _drifts() -> void:
	var x := rect.position.x + 2.0
	while x < rect.end.x - 2.0:
		var p := Vector2(x + rng.randf_range(-0.4, 0.4), WorldMap.WALL_Z + 0.5)
		if rect.has_point(p) and ForestGenUtil.off_road(p, 2.0) and absf(p.x - GAP.x) > 7.0:
			_put(&"wall_drift", p, PI, rng.randf_range(0.85, 1.25), -0.25)
		x += 3.4


func _dressing() -> void:
	# Sparse: a few dead snags (nothing living stands tall here), tufts, mounds, rocks.
	var cells := {&"tree_snag": [26.0, 0.18], &"snow_mound": [14.0, 0.35], &"grass_tuft": [8.0, 0.25],
		&"bracken": [12.0, 0.15], &"boulder_a": [30.0, 0.15], &"boulder_c": [30.0, 0.15], &"rock_flat": [24.0, 0.15], &"stump": [36.0, 0.2]}
	for id: StringName in cells:
		var cell: float = cells[id][0]
		var chance: float = cells[id][1]
		var x := rect.position.x
		while x < rect.end.x:
			var z := rect.position.y
			while z < rect.end.y:
				var p := Vector2(x + rng.randf() * cell, z + rng.randf() * cell)
				var r := rng.randf()
				# Fewer things the nearer the Wall: the strip is emptier at its north edge.
				var near := clampf((p.y - WorldMap.WALL_Z) / 60.0, 0.25, 1.0)
				if r < chance * near and free_ground(p, 2.0) and p.y > WorldMap.WALL_Z + 6.0:
					_put(id, p, rng.randf() * TAU, rng.randf_range(0.7, 1.3), -0.2 if id == &"snow_mound" else 0.0)
				z += cell
			x += cell


## The villagers' iron stakes, a broken line across the approach to the gap,
## a few slanting stakes everywhere else along the strip.
func _fence() -> void:
	var x := FENCE_X.x
	while x < FENCE_X.y:
		var p := Vector2(x + rng.randf_range(-0.3, 0.3), FENCE_Z + rng.randf_range(-1.5, 1.5))
		if free_ground(p, 1.5) and rng.randf() < 0.8:
			_put(&"iron_stake", p, PI + rng.randf_range(-0.3, 0.3), rng.randf_range(0.85, 1.15), -0.1)
		x += 1.6
	x = rect.position.x + 20.0
	while x < rect.end.x:
		var p := Vector2(x + rng.randf_range(-15.0, 15.0), rng.randf_range(1415.0, 1470.0))
		if free_ground(p) and (p.x < FENCE_X.x or p.x > FENCE_X.y):
			for k in rng.randi_range(1, 3):
				var q := p + Vector2(k * 1.5, rng.randf_range(-0.5, 0.5))
				if free_ground(q):
					_put(&"iron_stake", q, PI + rng.randf_range(-0.3, 0.3), rng.randf_range(0.85, 1.15), -0.1)
		x += 55.0


func _scatter(id: StringName, n: int, zmin: float, zmax: float, near_points: Array = [], radius := 0.0) -> void:
	var full: Rect2 = HumanRealmLayout.REGION_RECTS[&"wall_seam"]
	var count := maxi(1, roundi(n * rect.get_area() / full.get_area())) if near_points.is_empty() else n
	var placed := 0
	var tries := 0
	while placed < count and tries < count * 50:
		tries += 1
		var p: Vector2
		if near_points.is_empty():
			p = Vector2(rng.randf_range(rect.position.x, rect.end.x), rng.randf_range(zmin, zmax))
		else:
			var c: Vector2 = near_points[rng.randi() % near_points.size()]
			var a := rng.randf() * TAU
			p = c + Vector2(cos(a), sin(a)) * rng.randf_range(0.5, radius)
		if not free_ground(p, 0.6) or p.y < zmin or p.y > zmax:
			continue
		_put(id, p, rng.randf() * TAU, rng.randf_range(0.85, 1.15))
		placed += 1


func _stake_points() -> Array:
	var out := []
	var l: ScatterLayer = by_id[&"iron_stake"]
	for i in l.count():
		var p := l.position_of(i)
		out.append(Vector2(p.x, p.z))
	return out


func _forage() -> void:
	var z0 := WorldMap.WALL_Z + 3.0
	var z1 := rect.end.y - 0.5
	_scatter(&"iron_filings", 40, z0, z1, _stake_points(), 1.2)
	_scatter(&"flint", 30, z0, z1)
	_scatter(&"chalk", 22, z0, z1)
	_scatter(&"ice_moss", 26, z0, z1)
	_scatter(&"juniper", 30, WorldMap.WALL_Z + 10.0, z1)
	_scatter(&"rose_briar", 18, WorldMap.WALL_Z + 12.0, z1)
	_scatter(&"blackberry", 16, WorldMap.WALL_Z + 20.0, z1)
	# Hawthorn, the old boundary tree, grows along the strip.
	_scatter(&"hawthorn", 30, WorldMap.WALL_Z + 8.0, z1)
	_scatter(&"blackthorn", 16, WorldMap.WALL_Z + 15.0, z1)
	_scatter(&"tinder_fungus", 18, z0, z1, _layer_points(&"tree_snag"), 2.0)
	_scatter(&"old_mans_beard", 14, z0, z1, _layer_points(&"tree_snag"), 3.0)
	_scatter(&"snail_shells", 18, z0, z1)
	_scatter(&"red_ochre", 14, z0, z1)
	_scatter(&"wintergreen", 20, WorldMap.WALL_Z + 10.0, z1)
	_scatter(&"shed_antler", 10, z0, z1)
	_scatter(&"snowdrop", 24, WorldMap.WALL_Z + 15.0, z1)
	# Old watch-fires where villagers kept vigil, back from the line.
	var fires := []
	for i in 6:
		fires.append(Vector2(rect.position.x + (i + 0.5) * rect.size.x / 6.0, 1465.0))
	_scatter(&"charcoal", 24, WorldMap.WALL_Z + 50.0, z1, fires, 3.0)


func _layer_points(id: StringName) -> Array:
	var out := []
	var l: ScatterLayer = by_id[id]
	for i in l.count():
		var p := l.position_of(i)
		out.append(Vector2(p.x, p.z))
	return out


func _interest() -> void:
	var z0 := WorldMap.WALL_Z + 1.5
	var z1 := rect.end.y - 0.5
	# The Children of the Blessed leave their offerings closest to the line.
	var post := [OFFERING_POST, GAP + Vector2(0.0, 6.0)]
	_scatter(&"offering_bundle", 22, z0, WorldMap.WALL_Z + 25.0)
	_scatter(&"offering_bundle", 8, z0, z1, post, 4.0)
	_scatter(&"frozen_ribbon", 24, z0, WorldMap.WALL_Z + 30.0)
	_scatter(&"frozen_ribbon", 8, z0, z1, post, 4.0)
	_scatter(&"candle_stub", 14, z0, z1, post, 3.5)
	_scatter(&"candle_stub", 10, z0, WorldMap.WALL_Z + 20.0)
	_scatter(&"pamphlet", 14, z0, z1)
	_scatter(&"bone_token", 8, z0, z1)
	_scatter(&"lost_boot", 4, z0, WorldMap.WALL_Z + 15.0)
	_scatter(&"child_mitten", 3, z0, z1)
	_scatter(&"tin_charm", 14, WorldMap.WALL_Z + 20.0, z1)
	# Warning cairns every ~70 m along the strip, a little back from the line.
	var x := rect.position.x + 30.0
	while x < rect.end.x:
		var p := Vector2(x + rng.randf_range(-12.0, 12.0), rng.randf_range(1418.0, 1440.0))
		if free_ground(p, 1.5):
			_put(&"warning_cairn", p, rng.randf() * TAU, rng.randf_range(0.8, 1.3))
		x += 70.0
	_scatter(&"deer_bones", 14, z0, z1)
	_scatter(&"salt_ring", 12, WorldMap.WALL_Z + 6.0, z1)
	# Tracks that walk up to the line and turn back: local +Z points north
	# after yaw PI, so the prints approach from the south.
	x = rect.position.x + 15.0
	while x < rect.end.x:
		var p := Vector2(x + rng.randf_range(-20.0, 20.0), WorldMap.WALL_Z + 2.6)
		if free_ground(p):
			_put(&"tracks_end", p, PI + rng.randf_range(-0.4, 0.4), 1.0)
		x += 60.0
