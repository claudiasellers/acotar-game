## Builds every ScatterLayer of the winter hunting forest (deterministic for a
## seed). hunting_forest_gen.gd saves them and builds the scene around them;
## tests build a small sub-rectangle to check rules and determinism.
##
## Biomes (by layout + noise): dense mixed oak/birch forest (west), pine and
## spruce stands on rises (with rocky outcrops), snowy glades, the old noble
## hunting grounds' parkland (x > 300), the frozen creek's banks, the doe
## clearing, and the walled ash grove (the only ash in the human realm).
class_name HuntingForestBuilder
extends RefCounted


enum Biome { DENSE, RISE, ROCKY, GLADE, PARK, BANK, GROVE, CLEARING }

const SEED := 20481
const GROVE_RADIUS := 40.0  # the ash grove's ring wall
const PARK_X := 300.0       # old hunting grounds' boundary wall line

# Landmark sites (x, z). The layout's named sites plus this region's own.
const LEANTO := Vector2(-560.0, 1880.0)
const SPLIT_OAK := Vector2(-250.0, 1560.0)
const FALL := Vector2(-610.0, 1655.0)
const DEER_STAND := Vector2(590.0, 1630.0)
const HIDE := Vector2(-428.0, 1706.0)
const KEEPER_HUT := Vector2(-636.0, 1556.0)
const FARMSTEAD := Vector2(81.0, 1787.0)
const SHRINE_S := 330.0     # arc length along the ride north (ROADS[1]) for the shrine
## Small falls on the creek where icicles hang (snowmelt water).
const SMALL_FALLS: Array[Vector2] = [Vector2(-790.0, 1560.0), Vector2(-425.0, 1735.0), Vector2(-240.0, 1840.0), Vector2(-60.0, 1945.0)]

var rect: Rect2
var rng := RandomNumberGenerator.new()
var layers: Array[ScatterLayer] = []
var by_id := {}
## Tree anchors by kind: Array of Vector3(x, z, scale).
var trees := {}
## Building / landmark footprints: Vector3(x, z, radius).
var exclusions: Array = []

var _rise := FastNoiseLite.new()
var _clear := FastNoiseLite.new()
var _birch := FastNoiseLite.new()
var _ride: PackedVector2Array


func _init() -> void:
	rect = HumanRealmLayout.REGION_RECTS[&"hunting_forest"]
	_ride = HumanRealmLayout.ROADS[1]


static func bridge_site() -> Array:
	## [point, way direction] of the frozen bridge: where the ride north
	## crosses the creek if it does inside the forest (it doesn't with the
	## current layout: that crossing is in the village region), else where a
	## trail crosses it (Feyre's path first, then the deer trails).
	var rect: Rect2 = HumanRealmLayout.REGION_RECTS[&"hunting_forest"]
	var ways: Array = [HumanRealmLayout.ROADS[1]] + HumanRealmLayout.PATHS
	for way: PackedVector2Array in ways:
		for i in way.size() - 1:
			for j in HumanRealmLayout.CREEK.size() - 1:
				var hit: Variant = Geometry2D.segment_intersects_segment(way[i], way[i + 1], HumanRealmLayout.CREEK[j], HumanRealmLayout.CREEK[j + 1])
				if hit != null and rect.grow(-20.0).has_point(hit):
					return [hit, (way[i + 1] - way[i]).normalized()]
	return [Vector2(-330.0, 1780.0), Vector2(0.0, 1.0)]


static func crossroads() -> Vector2:
	## Where the ride north crosses the long deer trail (PATHS[1]).
	var road := HumanRealmLayout.ROADS[1]
	var trail := HumanRealmLayout.PATHS[1]
	for i in road.size() - 1:
		for j in trail.size() - 1:
			var hit: Variant = Geometry2D.segment_intersects_segment(road[i], road[i + 1], trail[j], trail[j + 1])
			if hit != null:
				return hit
	return Vector2(-40.0, 1615.0)


static func exclusion_circles() -> Array:
	var b: Array = bridge_site()
	var bp: Vector2 = b[0]
	var cr := crossroads()
	return [
		Vector3(HumanRealmLayout.HUNTING_LODGE.x, HumanRealmLayout.HUNTING_LODGE.y, 16.0), Vector3(FARMSTEAD.x, FARMSTEAD.y, 14.0),
		Vector3(LEANTO.x, LEANTO.y, 6.0), Vector3(SPLIT_OAK.x, SPLIT_OAK.y, 4.0), Vector3(FALL.x, FALL.y, 6.0),
		Vector3(DEER_STAND.x, DEER_STAND.y, 3.5), Vector3(HIDE.x, HIDE.y, 2.6), Vector3(KEEPER_HUT.x, KEEPER_HUT.y, 6.0),
		Vector3(bp.x, bp.y, 9.0), Vector3(cr.x, cr.y, 9.0), Vector3(HumanRealmLayout.WAITING_OAK.x, HumanRealmLayout.WAITING_OAK.y, 3.0),
	]


## Build everything inside `area` (default: the whole region).
func build(seed: int = SEED, area: Rect2 = Rect2()) -> Array[ScatterLayer]:
	if area.has_area():
		rect = area
	rng.seed = seed
	_rise.seed = seed + 1
	_rise.frequency = 1.0 / 170.0
	_clear.seed = seed + 2
	_clear.frequency = 1.0 / 110.0
	_birch.seed = seed + 3
	_birch.frequency = 1.0 / 140.0
	exclusions = exclusion_circles()
	layers.clear()
	by_id.clear()
	for k in ["oak", "birch", "pine", "spruce", "snag", "willow", "ash"]:
		trees[k] = []
	_make_layers()
	_trees()
	_hero_oak()
	_walls()
	_shrubs_and_ground()
	_forage()
	_interest()
	var out: Array[ScatterLayer] = []
	for l in layers:
		if l.count() > 0:
			out.append(l)
	return out


# --- biomes ---------------------------------------------------------------

func biome(p: Vector2) -> Biome:
	var dg := p.distance_to(HumanRealmLayout.ASH_GROVE)
	if dg < GROVE_RADIUS - 3.0:
		return Biome.GROVE
	if p.distance_to(HumanRealmLayout.DOE_CLEARING) < 24.0 or p.distance_to(HumanRealmLayout.WAITING_OAK) < 10.0:
		return Biome.CLEARING
	if HumanRealmLayout.distance_to_creek(p) < 14.0:
		return Biome.BANK
	var r := _rise.get_noise_2d(p.x, p.y)
	if r > 0.42:
		return Biome.ROCKY
	if p.x > PARK_X:
		return Biome.PARK
	if r > 0.2:
		return Biome.RISE
	if _clear.get_noise_2d(p.x, p.y) < -0.4:
		return Biome.GLADE
	return Biome.DENSE


func on_grove_wall(p: Vector2) -> bool:
	return absf(p.distance_to(HumanRealmLayout.ASH_GROVE) - GROVE_RADIUS) < 3.0


func on_park_wall(p: Vector2) -> bool:
	return (absf(p.x - PARK_X) < 2.0 and p.y > 1490.0) or (p.x > PARK_X and absf(p.y - 1495.0) < 2.0)


## Free ground for a placed thing (not road, creek, path, building, wall).
func free_ground(p: Vector2, road := 1.0, creek := 0.5, path := 0.3) -> bool:
	return rect.has_point(p) and ForestGenUtil.off_road(p, road) and ForestGenUtil.off_creek(p, creek) and ForestGenUtil.off_path(p, path) \
		and ForestGenUtil.clear_of(p, exclusions) and not on_grove_wall(p) and not on_park_wall(p)


# --- layers ---------------------------------------------------------------

func _add(l: ScatterLayer) -> ScatterLayer:
	layers.append(l)
	by_id[l.id] = l
	return l


func _make_layers() -> void:
	var F := ForestGenUtil.FLORA
	var P := ForestGenUtil.FOREST_PROPS
	# Trees (decoration; trunk collision is generated in the scene).
	_add(ForestGenUtil.tree_layer(&"tree_oak", "tree_oak_bare", "C"))
	_add(ForestGenUtil.tree_layer(&"tree_birch", "tree_birch", "X"))
	_add(ForestGenUtil.tree_layer(&"tree_pine", "tree_pine", "X"))
	_add(ForestGenUtil.tree_layer(&"tree_spruce", "tree_spruce", "X"))
	_add(ForestGenUtil.tree_layer(&"tree_snag", "tree_dead_snag", "X"))
	_add(ForestGenUtil.tree_layer(&"tree_willow", "tree_willow_pollard", "X"))
	_add(ForestGenUtil.tree_layer(&"tree_ash", "tree_ash", "C"))
	var hero := _add(ForestGenUtil.tree_layer(&"waiting_oak", "tree_waiting_oak", "X"))
	hero.tags.append("landmark")
	hero.draw_distance = 400.0
	hero.impostor_distance = 900.0
	# Walls as instanced runs (one draw per chunk, not one node per stone).
	for w: Array in [[&"ash_wall", "ash_wall_segment", "C"], [&"ash_wall_slump", "ash_wall_slump", "X"], [&"park_wall", "boundary_wall_section", "X"], [&"park_wall_end", "boundary_wall_end", "X"]]:
		var l := _add(ForestGenUtil.layer(w[0], ForestGenUtil.FOREST_ASSETS % w[1], &"", ["wall"], w[2], true))
		l.draw_distance = 350.0
	# Ground cover, shrubs, rocks, wood (decoration).
	for d: Array in [[&"hazel", "hazel_shrub", 0.3], [&"bracken", "dead_bracken", 0.4], [&"grass_tuft", "winter_grass_tuft", 0.5],
			[&"snow_mound", "snow_mound", 0.0], [&"boulder_a", "rock_boulder_a", 0.0], [&"boulder_b", "rock_boulder_b", 0.0],
			[&"boulder_c", "rock_boulder_c", 0.0], [&"rock_flat", "rock_flat", 0.0], [&"scree", "rock_scree", 0.0],
			[&"log_fallen", "log_fallen", 0.0], [&"stump", "stump", 0.0]]:
		var l := _add(ForestGenUtil.layer(d[0], F % d[1], &"", [], "C" if d[0] == &"snow_mound" else "X", true, d[2]))
		if String(d[1]).begins_with("rock_boulder") or d[0] == &"log_fallen":
			l.draw_distance = 180.0
	# Forage: [id, asset, ingredient, canon, wind]
	for f: Array in [
			[&"snowdrop", F % "snowdrop_cluster", &"ing_snowdrop", "X", 0.4],
			[&"blackberry", F % "blackberry_bramble", &"ing_blackberry", "X", 0.25],
			[&"pine_resin", F % "pine_resin_blob", &"ing_pine_resin", "X", 0.0],
			[&"willow_withies", F % "willow_withies", &"ing_willow_bark", "X", 0.4],
			[&"oak_gall", F % "oak_gall_twig", &"ing_oak_gall", "X", 0.2],
			[&"ash_deadfall", F % "ash_deadfall", &"ing_ash_wood", "C", 0.0],
			[&"rose_briar", F % "wild_rose_briar", &"ing_rose_hip", "X", 0.25],
			[&"holly", F % "holly_bush", &"ing_holly_berry", "X", 0.15],
			[&"juniper", F % "juniper_shrub", &"ing_juniper_berry", "X", 0.15],
			[&"blackthorn", F % "blackthorn_sloe", &"ing_sloe", "X", 0.2],
			[&"hawthorn", F % "hawthorn", &"ing_hawthorn_haw", "X", 0.2],
			[&"birch_bark", P % "birch_bark_curl", &"ing_birch_bark", "X", 0.0],
			[&"chaga", F % "chaga_growth", &"ing_chaga", "X", 0.0],
			[&"tinder_fungus", F % "tinder_fungus", &"ing_tinder_fungus", "X", 0.0],
			[&"old_mans_beard", F % "old_mans_beard", &"ing_old_mans_beard", "X", 0.5],
			[&"acorns", F % "acorn_scatter", &"ing_acorn", "C", 0.0],
			[&"hazelnuts", F % "hazelnut_scatter", &"ing_hazelnut", "X", 0.0],
			[&"pine_litter", F % "pine_cone_scatter", &"ing_pine_needles", "X", 0.0],
			[&"frozen_reeds", F % "frozen_reeds", &"ing_frozen_reed", "X", 0.5],
			[&"mistletoe", F % "mistletoe_clump", &"ing_mistletoe", "X", 0.3],
			[&"wintergreen", F % "wintergreen_patch", &"ing_wintergreen", "X", 0.1],
			[&"crow_feather", F % "feather_crow", &"ing_crow_feather", "X", 0.0],
			[&"shed_antler", F % "shed_antler", &"ing_shed_antler", "C", 0.0],
			[&"flint", F % "flint_nodule", &"ing_flint", "X", 0.0],
			[&"chalk", F % "chalk_lump", &"ing_chalk", "X", 0.0],
			[&"red_ochre", F % "red_ochre_rock", &"ing_red_ochre", "X", 0.0],
			[&"charcoal", F % "charcoal_lump", &"ing_charcoal", "X", 0.0],
			[&"clay", F % "clay_lump", &"ing_clay", "X", 0.0],
			[&"icicles", F % "icicle_cluster", &"ing_snowmelt_water", "X", 0.0],
			[&"ice_moss", F % "ice_moss", &"ing_ice_moss", "X", 0.0],
			[&"owl_feather", F % "feather_owl", &"ing_owl_feather", "X", 0.0],
			[&"hawk_feather", F % "feather_hawk", &"ing_hawk_feather", "X", 0.0],
			[&"snail_shells", F % "snail_shells", &"ing_snail_shell", "X", 0.0],
			[&"woad", F % "woad_rosette", &"ing_woad", "X", 0.2],
			[&"madder", F % "madder_patch", &"ing_madder", "X", 0.2],
		]:
		_add(ForestGenUtil.layer(f[0], f[1], f[2], [], f[3], true, f[4]))
	# Keepsakes (collectible) and notice-moments (look).
	for c: Array in [[&"broken_arrow", "X"], [&"lost_button", "X"], [&"horn_fragment", "X"], [&"rusty_spur", "X"],
			[&"bone_token", "X"], [&"pamphlet", "X"], [&"frozen_ribbon", "X"]]:
		_add(ForestGenUtil.layer(c[0], P % c[0], &"", ["collectible"], c[1]))
	for k: Array in [[&"deer_tracks", "C"], [&"hare_tracks", "C"], [&"wolf_tracks", "C"], [&"fox_tracks", "X"],
			[&"barked_trunk", "C"], [&"robin_on_stump", "X"], [&"snare", "X"], [&"antler_rub", "C"]]:
		_add(ForestGenUtil.layer(k[0], P % k[0], &"", ["look"], k[1]))


# --- trees ----------------------------------------------------------------

func _trees() -> void:
	var cell := 8.5
	var x := rect.position.x
	while x < rect.end.x:
		var z := rect.position.y
		while z < rect.end.y:
			var p := Vector2(x + rng.randf() * cell, z + rng.randf() * cell)
			var roll := rng.randf()
			var pick := rng.randf()
			var s := rng.randf_range(0.8, 1.25)
			z += cell
			if not free_ground(p, 3.0, 1.2, 1.4):
				continue
			var b := biome(p)
			# Thin out toward the dead-quiet strip by the Wall.
			var edge := clampf((p.y - 1480.0) / 60.0, 0.15, 1.0)
			var kind := ""
			match b:
				Biome.DENSE:
					if roll < 0.92 * edge:
						kind = "oak" if pick < 0.5 + 0.2 * _birch.get_noise_2d(p.x, p.y) else ("birch" if pick < 0.76 else ("pine" if pick < 0.86 else ("spruce" if pick < 0.93 else "snag")))
				Biome.RISE:
					if roll < 0.8 * edge:
						kind = "pine" if pick < 0.46 else ("spruce" if pick < 0.86 else ("birch" if pick < 0.95 else "snag"))
				Biome.ROCKY:
					if roll < 0.4 * edge:
						kind = "pine" if pick < 0.5 else ("spruce" if pick < 0.8 else "snag")
				Biome.GLADE:
					if roll < 0.06:
						kind = "birch" if pick < 0.5 else "snag"
				Biome.PARK:
					if roll < 0.28 * edge:
						kind = "oak" if pick < 0.72 else ("snag" if pick < 0.85 else "birch")
						if kind == "oak":
							s *= 1.2  # the old lords' great oaks
				Biome.BANK:
					if roll < 0.35 * edge:
						kind = "willow" if pick < 0.55 else ("birch" if pick < 0.8 else "oak")
				Biome.GROVE:
					if roll < 0.75:
						kind = "ash"
				Biome.CLEARING:
					pass
			if kind != "":
				trees[kind].append(Vector3(p.x, p.y, s))
		x += cell
	var map := {"oak": &"tree_oak", "birch": &"tree_birch", "pine": &"tree_pine", "spruce": &"tree_spruce",
		"snag": &"tree_snag", "willow": &"tree_willow", "ash": &"tree_ash"}
	for kind: String in map:
		var l: ScatterLayer = by_id[map[kind]]
		for t: Vector3 in trees[kind]:
			ForestGenUtil.put(l, t.x, t.y, rng.randf() * TAU, t.z, -0.15)


func _hero_oak() -> void:
	if rect.has_point(HumanRealmLayout.WAITING_OAK):
		ForestGenUtil.put(by_id[&"waiting_oak"], HumanRealmLayout.WAITING_OAK.x, HumanRealmLayout.WAITING_OAK.y, 2.4, 1.0, -0.2)


# --- walls ----------------------------------------------------------------

## The ash grove ring: 3.6 m runs, skipping the gate (east) and the two
## creek crossings (water grates), one slumped climbable run (north-west).
func grove_wall_angles() -> Dictionary:
	var n := ceili(TAU * GROVE_RADIUS / 3.5)
	var runs: Array[float] = []
	var slump: Array[float] = []
	var crossings := creek_crossings()
	for i in n:
		var a := float(i) / n * TAU
		var arc_to_gate := absf(wrapf(a, -PI, PI)) * GROVE_RADIUS
		if arc_to_gate < 4.0:
			continue
		var skip := false
		for c: float in crossings:
			if absf(wrapf(a - c, -PI, PI)) * GROVE_RADIUS < 6.5:
				skip = true
		if skip:
			continue
		if absf(wrapf(a - deg_to_rad(-125.0), -PI, PI)) * GROVE_RADIUS < 3.6:
			slump.append(a)
		else:
			runs.append(a)
	return {"runs": runs, "slump": slump}


## Ring angles (radians, x = cos, z = sin) where the creek crosses the wall.
static func creek_crossings() -> Array[float]:
	var out: Array[float] = []
	var inside := false
	var steps := 1440
	var prev_in := false
	for i in steps + 1:
		var a := float(i) / steps * TAU
		var p := HumanRealmLayout.ASH_GROVE + Vector2(cos(a), sin(a)) * GROVE_RADIUS
		inside = HumanRealmLayout.distance_to_creek(p) < HumanRealmLayout.CREEK_HALF_WIDTH + 0.5
		if inside and not prev_in:
			# Walk to the middle of this wet stretch.
			var j := i
			while j < i + steps and HumanRealmLayout.distance_to_creek(HumanRealmLayout.ASH_GROVE + Vector2(cos(float(j) / steps * TAU), sin(float(j) / steps * TAU)) * GROVE_RADIUS) < HumanRealmLayout.CREEK_HALF_WIDTH + 0.5:
				j += 1
			out.append(wrapf((float(i) + float(j)) * 0.5 / steps * TAU, -PI, PI))
		prev_in = inside
	return out


func _walls() -> void:
	var ang := grove_wall_angles()
	for key: String in ["runs", "slump"]:
		var l: ScatterLayer = by_id[&"ash_wall" if key == "runs" else &"ash_wall_slump"]
		for a: float in ang[key]:
			var p := HumanRealmLayout.ASH_GROVE + Vector2(cos(a), sin(a)) * GROVE_RADIUS
			if rect.has_point(p):
				# Local +Z faces the grove's centre, so the buttresses stand outside.
				ForestGenUtil.put(l, p.x, p.y, ForestGenUtil.yaw_facing(-Vector2(cos(a), sin(a))), 1.0, -0.3)
	# The old hunting grounds' boundary wall: x = PARK_X (south to north), then
	# along z = 1495 to the east edge. Gaps where trails cross.
	var lines: Array = [[Vector2(PARK_X, 2044.0), Vector2(PARK_X, 1495.0)], [Vector2(PARK_X, 1495.0), Vector2(rect.end.x - 4.0, 1495.0)]]
	var wall: ScatterLayer = by_id[&"park_wall"]
	var ends: ScatterLayer = by_id[&"park_wall_end"]
	for ln: Array in lines:
		var a: Vector2 = ln[0]
		var b: Vector2 = ln[1]
		var d := (b - a).normalized()
		var n := floori(a.distance_to(b) / 12.0)
		var prev_gap := false
		for i in n:
			var c := a + d * (12.0 * i + 6.0)
			var gap := HumanRealmLayout.distance_to_path(c) < 7.0 or HumanRealmLayout.distance_to_road(c) < 8.0 or (i % 9 == 5)  # trails + slumped breaks
			if gap:
				if not prev_gap and rect.has_point(c):
					ForestGenUtil.put(ends, c.x - d.x * 6.0, c.y - d.y * 6.0, ForestGenUtil.yaw_along(-d), 1.0, -0.2)
				prev_gap = true
				continue
			if prev_gap and rect.has_point(c):
				ForestGenUtil.put(ends, c.x - d.x * 6.0, c.y - d.y * 6.0, ForestGenUtil.yaw_along(d), 1.0, -0.2)
			prev_gap = false
			if rect.has_point(c):
				ForestGenUtil.put(wall, c.x, c.y, ForestGenUtil.yaw_along(d), 1.0, -0.2)


# --- shrubs, ground, rocks, wood -------------------------------------------

func _grid(cell: float, fn: Callable) -> void:
	var x := rect.position.x
	while x < rect.end.x:
		var z := rect.position.y
		while z < rect.end.y:
			var p := Vector2(x + rng.randf() * cell, z + rng.randf() * cell)
			fn.call(p, biome(p) if rect.has_point(p) else Biome.DENSE, rng.randf())
			z += cell
		x += cell


func _shrubs_and_ground() -> void:
	_grid(13.0, func(p: Vector2, b: Biome, r: float) -> void:
		if free_ground(p, 1.5, 1.0, 0.8) and b == Biome.DENSE and r < 0.28:
			ForestGenUtil.put(by_id[&"hazel"], p.x, p.y, rng.randf() * TAU, rng.randf_range(0.8, 1.3)))
	_grid(9.0, func(p: Vector2, b: Biome, r: float) -> void:
		if free_ground(p, 1.0, 0.6, 0.5) and b in [Biome.GLADE, Biome.PARK, Biome.BANK, Biome.CLEARING, Biome.DENSE] and r < (0.3 if b != Biome.DENSE else 0.08):
			ForestGenUtil.put(by_id[&"bracken"], p.x, p.y, rng.randf() * TAU, rng.randf_range(0.7, 1.3)))
	_grid(7.0, func(p: Vector2, b: Biome, r: float) -> void:
		if free_ground(p, 0.6, 0.6, 0.3) and b in [Biome.GLADE, Biome.PARK, Biome.CLEARING, Biome.BANK] and r < 0.45:
			ForestGenUtil.put(by_id[&"grass_tuft"], p.x, p.y, rng.randf() * TAU, rng.randf_range(0.7, 1.4)))
	_grid(18.0, func(p: Vector2, _b: Biome, r: float) -> void:
		if free_ground(p, 1.5, 1.0, 0.8) and r < 0.35:
			ForestGenUtil.put(by_id[&"snow_mound"], p.x, p.y, rng.randf() * TAU, rng.randf_range(0.8, 1.8), -0.2))
	var boulders := [&"boulder_a", &"boulder_b", &"boulder_c"]
	_grid(9.0, func(p: Vector2, b: Biome, r: float) -> void:
		if not free_ground(p, 2.0, 1.5, 1.0):
			return
		var chance := 0.45 if b == Biome.ROCKY else (0.06 if b in [Biome.RISE, Biome.BANK] else 0.015)
		if r < chance:
			ForestGenUtil.put(by_id[boulders[rng.randi() % 3]], p.x, p.y, rng.randf() * TAU, rng.randf_range(0.6, 1.6), -0.3)
		elif b == Biome.ROCKY and r < 0.65:
			ForestGenUtil.put(by_id[&"scree" if r < 0.55 else &"rock_flat"], p.x, p.y, rng.randf() * TAU, rng.randf_range(0.7, 1.3)))
	_grid(16.0, func(p: Vector2, b: Biome, r: float) -> void:
		if not free_ground(p, 2.0, 1.0, 1.0):
			return
		if b in [Biome.DENSE, Biome.RISE, Biome.BANK] and r < 0.14:
			ForestGenUtil.put(by_id[&"log_fallen"], p.x, p.y, rng.randf() * TAU, rng.randf_range(0.8, 1.3), -0.1)
		elif b != Biome.GROVE and r > 0.9:
			ForestGenUtil.put(by_id[&"stump"], p.x, p.y, rng.randf() * TAU, rng.randf_range(0.8, 1.2)))
	# The woodcutter felled around his lean-to.
	for i in 14:
		var a := rng.randf() * TAU
		var p := LEANTO + Vector2(cos(a), sin(a)) * rng.randf_range(7.0, 22.0)
		if free_ground(p, 1.5, 1.0, 0.8):
			ForestGenUtil.put(by_id[&"stump"], p.x, p.y, rng.randf() * TAU, rng.randf_range(0.8, 1.3))


# --- forage ---------------------------------------------------------------

func _ok(p: Vector2) -> bool:
	return free_ground(p, 0.6, 0.3, 0.2)


## Place up to n instances; `pick` returns Vector4(x, z, lift, scale) or null.
func _place(id: StringName, n: int, pick: Callable) -> void:
	var l: ScatterLayer = by_id[id]
	var placed := 0
	var tries := 0
	while placed < n and tries < n * 40:
		tries += 1
		var r: Variant = pick.call()
		if r == null:
			continue
		var v: Vector4 = r
		if not _ok(Vector2(v.x, v.y)):
			continue
		ForestGenUtil.put(l, v.x, v.y, rng.randf() * TAU, v.w, v.z)
		placed += 1


func _scale_n(n: int) -> int:
	## Counts are for the whole region; a sub-rect build scales them down.
	var full: Rect2 = HumanRealmLayout.REGION_RECTS[&"hunting_forest"]
	return maxi(1, roundi(n * rect.get_area() / full.get_area()))


func _in(biomes: Array, s_min := 0.8, s_max := 1.2) -> Callable:
	return func() -> Variant:
		var p := Vector2(rng.randf_range(rect.position.x, rect.end.x), rng.randf_range(rect.position.y, rect.end.y))
		if not biomes.has(biome(p)):
			return null
		return Vector4(p.x, p.y, 0.0, rng.randf_range(s_min, s_max))


func _at_tree(kind: String, r_min: float, r_max: float, lift_min: float, lift_max: float, s := 1.0) -> Callable:
	return func() -> Variant:
		var list: Array = trees[kind]
		if list.is_empty():
			return null
		var t: Vector3 = list[rng.randi() % list.size()]
		var a := rng.randf() * TAU
		var d := rng.randf_range(r_min, r_max) * t.z
		return Vector4(t.x + cos(a) * d, t.y + sin(a) * d, rng.randf_range(lift_min, lift_max) * t.z, s * rng.randf_range(0.85, 1.15))


func _near(points: Array, r_min: float, r_max: float, s := 1.0) -> Callable:
	return func() -> Variant:
		if points.is_empty():
			return null
		var c: Vector2 = points[rng.randi() % points.size()]
		var a := rng.randf() * TAU
		var d := rng.randf_range(r_min, r_max)
		return Vector4(c.x + cos(a) * d, c.y + sin(a) * d, 0.0, s * rng.randf_range(0.8, 1.2))


func _along(lines: Array, off_min: float, off_max: float, s := 1.0) -> Callable:
	return func() -> Variant:
		var line: PackedVector2Array = lines[rng.randi() % lines.size()]
		var at := ForestGenUtil.along(line, rng.randf() * ForestGenUtil.polyline_length(line))
		var p: Vector2 = at[0]
		var d: Vector2 = at[1]
		var side := Vector2(-d.y, d.x) * (1.0 if rng.randf() < 0.5 else -1.0)
		var q := p + side * rng.randf_range(off_min, off_max)
		return Vector4(q.x, q.y, 0.0, s * rng.randf_range(0.8, 1.2))


func _forage() -> void:
	var creek := [HumanRealmLayout.CREEK]
	var edges := [Biome.GLADE, Biome.CLEARING, Biome.PARK, Biome.BANK]
	_place(&"snowdrop", _scale_n(320), _in([Biome.GLADE, Biome.CLEARING, Biome.BANK, Biome.PARK, Biome.GROVE]))
	_place(&"blackberry", _scale_n(140), _along(HumanRealmLayout.PATHS, 2.0, 7.0))
	_place(&"blackberry", _scale_n(90), _in([Biome.GLADE, Biome.BANK]))
	_place(&"pine_resin", _scale_n(180), _at_tree("pine", 0.3, 0.38, 0.8, 1.6))
	_place(&"willow_withies", _scale_n(110), _at_tree("willow", 0.6, 2.0, 0.0, 0.0))
	_place(&"oak_gall", _scale_n(160), _at_tree("oak", 0.6, 3.0, 0.0, 0.0))  # galled twigs blown down under their oak
	_place(&"ash_deadfall", _scale_n(50), _near([HumanRealmLayout.ASH_GROVE], 2.0, GROVE_RADIUS - 4.0))
	_place(&"rose_briar", _scale_n(150), _in([Biome.GLADE, Biome.PARK, Biome.CLEARING]))
	_place(&"holly", _scale_n(260), _in([Biome.DENSE, Biome.BANK], 0.8, 1.3))
	_place(&"juniper", _scale_n(170), _in([Biome.RISE, Biome.ROCKY, Biome.PARK], 0.8, 1.3))
	_place(&"blackthorn", _scale_n(70), _along([HumanRealmLayout.ROADS[1]], 4.0, 9.0))
	_place(&"blackthorn", _scale_n(60), _in([Biome.PARK, Biome.GLADE]))
	_place(&"hawthorn", _scale_n(130), _in([Biome.PARK, Biome.GLADE, Biome.CLEARING], 0.9, 1.3))
	_place(&"birch_bark", _scale_n(220), _at_tree("birch", 0.25, 0.6, 0.0, 0.0))
	_place(&"chaga", _scale_n(70), _at_tree("birch", 0.3, 1.2, 0.0, 0.0))
	_place(&"chaga", _scale_n(40), _near(_points(&"log_fallen"), 0.0, 1.5))  # chaga stands on its log
	_place(&"tinder_fungus", _scale_n(120), _at_tree("snag", 0.25, 0.32, 0.6, 1.6))
	_place(&"old_mans_beard", _scale_n(120), _at_tree("oak", 0.8, 3.0, 0.0, 0.0))  # a fallen twig with its lichen
	_place(&"old_mans_beard", _scale_n(80), _at_tree("spruce", 0.6, 2.5, 0.0, 0.0))
	_place(&"acorns", _scale_n(260), _at_tree("oak", 1.0, 3.5, 0.0, 0.0))
	_place(&"hazelnuts", _scale_n(170), _near(_points(&"hazel"), 0.6, 2.0))
	_place(&"pine_litter", _scale_n(240), _at_tree("pine", 0.8, 3.0, 0.0, 0.0))
	_place(&"pine_litter", _scale_n(120), _at_tree("spruce", 0.8, 3.0, 0.0, 0.0))
	_place(&"frozen_reeds", _scale_n(260), _along(creek, HumanRealmLayout.CREEK_HALF_WIDTH + 0.6, HumanRealmLayout.CREEK_HALF_WIDTH + 3.5))
	_place(&"mistletoe", _scale_n(90), _at_tree("oak", 0.8, 3.5, 0.0, 0.0))  # clumps the wind tore out of the crowns
	_place(&"wintergreen", _scale_n(240), _in([Biome.DENSE, Biome.RISE]))
	_place(&"crow_feather", _scale_n(80), _in(edges))
	_place(&"shed_antler", _scale_n(30), _in([Biome.CLEARING, Biome.GLADE, Biome.PARK]))
	_place(&"shed_antler", _scale_n(25), _along(HumanRealmLayout.PATHS.slice(1), 1.5, 6.0))
	_place(&"flint", _scale_n(90), _in([Biome.ROCKY]))
	_place(&"chalk", _scale_n(70), _in([Biome.ROCKY, Biome.RISE]))
	_place(&"red_ochre", _scale_n(45), _in([Biome.ROCKY]))
	_place(&"clay", _scale_n(80), _along(creek, HumanRealmLayout.CREEK_HALF_WIDTH + 0.5, HumanRealmLayout.CREEK_HALF_WIDTH + 2.2))
	_place(&"ice_moss", _scale_n(140), _along(creek, HumanRealmLayout.CREEK_HALF_WIDTH + 0.6, 12.0))
	_place(&"snail_shells", _scale_n(60), _along(creek, HumanRealmLayout.CREEK_HALF_WIDTH + 1.0, 6.0))
	_place(&"owl_feather", _scale_n(45), _at_tree("oak", 1.0, 4.0, 0.0, 0.0))
	_place(&"hawk_feather", _scale_n(40), _in([Biome.PARK, Biome.GLADE, Biome.ROCKY]))
	_place(&"woad", _scale_n(70), _in([Biome.PARK]))
	_place(&"madder", _scale_n(50), _in([Biome.PARK, Biome.GLADE]))
	# Charcoal where fire has been: the lean-to's dead fire, the split oak, the lodge hearth.
	var burnt: Array = [LEANTO + Vector2(0.4, 2.6), SPLIT_OAK, HumanRealmLayout.HUNTING_LODGE + Vector2(-9.0, 3.0), FARMSTEAD]
	_place(&"charcoal", mini(_scale_n(40), 40), _near(burnt, 3.0, 9.0))
	# Icicles at the creek's small falls and the frozen fall.
	var falls: Array = SMALL_FALLS.duplicate()
	falls.append(FALL)
	_place(&"icicles", mini(_scale_n(60), 60), _near(falls, 3.6, 8.0))


func _points(id: StringName) -> Array:
	var out := []
	var l: ScatterLayer = by_id[id]
	for i in l.count():
		var p := l.position_of(i)
		out.append(Vector2(p.x, p.z))
	return out


# --- keepsakes and notice-moments ------------------------------------------

func _interest() -> void:
	var trails := HumanRealmLayout.PATHS.slice(1)
	var ride := [HumanRealmLayout.ROADS[1]]
	_place(&"broken_arrow", _scale_n(14), _in([Biome.DENSE, Biome.GLADE, Biome.CLEARING, Biome.PARK]))
	_place(&"lost_button", _scale_n(10), _along([HumanRealmLayout.PATHS[0]] + ride, 1.5, 5.0))
	_place(&"horn_fragment", _scale_n(8), _in([Biome.PARK]))
	_place(&"rusty_spur", _scale_n(8), _near([HumanRealmLayout.HUNTING_LODGE, DEER_STAND], 16.5, 35.0))
	_place(&"bone_token", _scale_n(10), _in([Biome.DENSE, Biome.RISE, Biome.BANK]))
	_place(&"pamphlet", _scale_n(14), _along(ride, 3.5, 9.0))
	_place(&"frozen_ribbon", _scale_n(12), _along(ride, 4.0, 10.0))
	_place(&"deer_tracks", _scale_n(150), _along(trails, 0.0, 2.5))
	_place(&"deer_tracks", _scale_n(40), _near([HumanRealmLayout.DOE_CLEARING], 0.0, 22.0))
	_place(&"hare_tracks", _scale_n(140), _in([Biome.GLADE, Biome.PARK, Biome.CLEARING, Biome.BANK, Biome.DENSE]))
	_place(&"wolf_tracks", mini(_scale_n(14), 14), _near([HumanRealmLayout.DOE_CLEARING, HumanRealmLayout.WAITING_OAK, Vector2(-520.0, 1640.0)], 6.0, 40.0))
	_place(&"fox_tracks", _scale_n(70), _in([Biome.DENSE, Biome.GLADE, Biome.PARK, Biome.RISE]))
	_place(&"barked_trunk", _scale_n(70), _along(trails, 2.0, 6.0))
	_place(&"robin_on_stump", _scale_n(28), _near(_points(&"stump"), 0.0, 0.1))
	_place(&"snare", _scale_n(36), _along(trails, 1.0, 2.5))
	_place(&"antler_rub", _scale_n(32), _in([Biome.DENSE, Biome.PARK, Biome.GLADE]))
