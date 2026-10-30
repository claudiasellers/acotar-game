## Every scatter layer of the Manor Estate: forage, keepsakes, flowers, trees.
##
## Deterministic (fixed seeds per layer and zone). tools/manor_estate/gen_grounds.gd
## writes the layers to scatter/<id>.tres (gitignored, R15: rebuilt) and the
## coverage report; the estate loads those .tres, or builds the same layers in
## memory when they are missing. Meshes are never saved: they come from
## ManorLooks at load so the props lane's flora upgrades always show.
##
## Flora come from the Keeper's ingredient catalogue (lore/05-foraging-chemistry/
## ingredients.md); every layer carries a "canon:C" or "canon:X" tag.
class_name ManorScatter
extends RefCounted

const DIR := "res://world/spring_court/manor_estate/scatter/_generated/"
const REGION_ID := &"manor_estate"
const REPORT_PATH := "res://world/spring_court/manor_estate/scatter/_generated/manor_estate_report.json"

## Item colours.
const C_FEATHER_HAWK := Color(0.78, 0.52, 0.36)
const C_FEATHER_OWL := Color(1.0, 0.93, 0.80)

var layers: Dictionary = {}    # id -> ScatterLayer
var _specs: Dictionary


func _init() -> void:
	_specs = specs()


# --- Layer specs ---------------------------------------------------------------

## id -> {look, ingredient, tags, wind, draw, shadow}
static func specs() -> Dictionary:
	var s := {}
	# Forage flora (ing_ ids from the lore catalogue).
	_f(s, &"ing_rose_red", [&"flora", &"rose_red"], "C", 0.25)
	_f(s, &"ing_rose_white", [&"flora", &"rose_white"], "C", 0.25)
	_f(s, &"ing_rose_gold", [&"flora", &"rose_gold"], "X", 0.25)
	_f(s, &"ing_lavender", [&"flora", &"lavender"], "X", 0.5)
	_f(s, &"ing_honeysuckle", [&"flora", &"honeysuckle"], "X", 0.3)
	_f(s, &"ing_wisteria", [&"flora", &"wisteria"], "C", 0.3)
	_f(s, &"ing_lilac", [&"flora", &"lilac"], "C", 0.3, 150.0)
	_f(s, &"ing_cherry_blossom", [&"item", &"drift", Color(1.0, 0.72, 0.84)], "X", 0.0, 80.0)
	_f(s, &"ing_elderflower", [&"flora", &"elderflower"], "X", 0.3, 150.0)
	_f(s, &"ing_wild_strawberry", [&"flora", &"wild_strawberry"], "X", 0.2, 80.0)
	_f(s, &"ing_blackberry", [&"flora", &"blackberry"], "X", 0.3)
	_f(s, &"ing_willow_bark", [&"item", &"bark", Color(0.72, 0.56, 0.44)], "C", 0.0, 70.0)
	_f(s, &"ing_wild_hyacinth", [&"flora", &"wild_hyacinth"], "C", 0.6, 100.0)
	_f(s, &"ing_foxglove", [&"flora", &"foxglove"], "C", 0.5)
	_f(s, &"ing_faelight_dandelion", [&"flora", &"faelight_dandelion"], "X", 0.6, 100.0)
	_f(s, &"ing_moss", [&"flora", &"starmoss"], "X", 0.0, 80.0)
	_f(s, &"ing_rose_maze_dew", [&"item", &"dew", Color.WHITE], "X", 0.0, 70.0)
	_f(s, &"ing_honey", [&"item", &"jar", Color.WHITE], "X", 0.0, 70.0)
	_f(s, &"ing_snail_shell", [&"item", &"shell", Color(1.0, 0.92, 0.86)], "X", 0.0, 60.0)
	_f(s, &"ing_hawk_feather", [&"item", &"feather", C_FEATHER_HAWK], "X", 0.0, 60.0)
	_f(s, &"ing_owl_feather", [&"item", &"feather", C_FEATHER_OWL], "X", 0.0, 60.0)
	_f(s, &"ing_trout", [&"item", &"ripple", Color.WHITE], "X", 0.0, 90.0)
	_f(s, &"ing_manor_fruit", [&"item", &"fruit", Color(1.0, 0.45, 0.45)], "C", 0.0, 70.0)
	_f(s, &"ing_madder", [&"item", &"tall_clump", Color(0.9, 0.25, 0.3)], "X", 0.0, 80.0)
	_f(s, &"ing_river_silt", [&"item", &"silt", Color(0.86, 0.66, 0.42)], "X", 0.0, 60.0)
	_f(s, &"ing_crab_apple", [&"item", &"drift", Color(1.0, 0.95, 0.96)], "C", 0.0, 80.0)
	_f(s, &"ing_buttercup", [&"item", &"low_clump", Color(1.0, 0.88, 0.2)], "C", 0.0, 90.0)
	_f(s, &"ing_iris", [&"item", &"tall_clump", Color(0.62, 0.42, 0.95)], "C", 0.0, 90.0)
	_f(s, &"ing_crocus", [&"item", &"low_clump", Color(0.78, 0.55, 1.0)], "C", 0.0, 90.0)
	_f(s, &"ing_glowcap", [&"flora", &"mushroom_glowcap"], "X", 0.0, 80.0)
	# Keepsakes (col_ ids): tagged collectible, sparkle glint.
	_c(s, &"col_pressed_violet", &"violet", Color(0.62, 0.40, 0.95))
	_c(s, &"col_painted_pebble", &"pebble", Color(0.66, 0.82, 1.0))
	_c(s, &"col_lost_ribbon", &"ribbon", Color(1.0, 0.45, 0.65))
	_c(s, &"col_pearl_button", &"button", Color(1.0, 0.97, 0.94))
	_c(s, &"col_glass_marble", &"marble", Color(0.55, 0.95, 0.85))
	_c(s, &"col_tiny_horseshoe", &"horseshoe", Color(0.85, 0.85, 0.95))
	_c(s, &"col_garden_key", &"key", Color(1.0, 0.8, 0.38))
	_c(s, &"col_mask_feather", &"feather", Color(0.30, 0.85, 0.75))
	_c(s, &"col_rose_quartz", &"quartz", Color(1.0, 0.70, 0.80))
	_c(s, &"col_shell_comb", &"comb", Color(1.0, 0.86, 0.80))
	_c(s, &"col_silver_thimble", &"thimble", Color(0.90, 0.90, 1.0))
	_c(s, &"col_gilt_acorn", &"acorn", Color(1.0, 0.78, 0.30))
	# Decoration (no ingredient): flowers, hedges, trees.
	_d(s, &"deco_rose_pink", &"rose_pink", "C", 0.25, 120.0)
	_d(s, &"deco_rose_climbing", &"rose_climbing", "C", 0.2, 150.0)
	_d(s, &"deco_tulip_bed", &"tulip_bed", "C", 0.5, 110.0)
	_d(s, &"deco_peony", &"peony", "C", 0.4, 110.0)
	_d(s, &"deco_forget_me_not", &"forget_me_not", "X", 0.5, 80.0)
	_d(s, &"deco_daisy", &"daisy", "X", 0.5, 80.0)
	_d(s, &"deco_herb_patch", &"herb_patch", "X", 0.3, 90.0)
	_d(s, &"deco_vegetable_row", &"vegetable_row", "C", 0.3, 90.0)
	_d(s, &"deco_fern", &"fern", "X", 0.4, 90.0)
	_d(s, &"deco_reed", &"reed", "X", 0.7, 110.0)
	_d(s, &"deco_water_lily", &"water_lily", "X", 0.0, 110.0)
	_d(s, &"deco_hedge_box", &"hedge_box", "C", 0.0, 160.0)
	_d(s, &"deco_oak", &"oak", "C", 0.15, 450.0, true)
	_d(s, &"deco_birch", &"birch", "C", 0.2, 450.0, true)
	_d(s, &"deco_willow", &"willow", "C", 0.3, 450.0, true)
	_d(s, &"deco_cherry_blossom", &"cherry_blossom", "X", 0.2, 400.0, true)
	_d(s, &"deco_apple_blossom", &"apple_blossom", "C", 0.2, 350.0, true)
	_d(s, &"deco_pear_tree", &"pear_tree", "X", 0.2, 350.0, true)
	return s


static func _f(s: Dictionary, id: StringName, look: Array, canon: String, wind: float, draw: float = 120.0) -> void:
	s[id] = {"look": look, "ingredient": id, "tags": PackedStringArray(["canon:" + canon]), "wind": wind, "draw": draw, "shadow": false}


static func _c(s: Dictionary, id: StringName, kind: StringName, color: Color) -> void:
	s[id] = {"look": [&"item", kind, color], "ingredient": id, "tags": PackedStringArray(["collectible", "look", "canon:X"]), "wind": 0.0, "draw": 60.0, "shadow": false}


static func _d(s: Dictionary, id: StringName, species: StringName, canon: String, wind: float, draw: float, tree: bool = false) -> void:
	var tags := PackedStringArray(["decoration", "canon:" + canon])
	if tree:
		tags.append("tree")
	s[id] = {"look": [&"flora", species], "ingredient": &"", "tags": tags, "wind": wind, "draw": draw, "shadow": tree}


# --- Putting things down ------------------------------------------------------

func layer(id: StringName) -> ScatterLayer:
	if layers.has(id):
		return layers[id]
	assert(_specs.has(id), "unknown scatter layer %s" % id)
	var spec: Dictionary = _specs[id]
	var l := ScatterLayer.new()
	l.id = id
	l.ingredient_id = spec["ingredient"]
	l.tags = spec["tags"]
	l.wind = spec["wind"]
	l.draw_distance = spec["draw"]
	l.cast_shadow = spec["shadow"]
	var look: Array = spec["look"]
	if look[0] == &"flora" and FloraLib.height_of(look[1]) >= 2.0 and not l.tags.has("tall"):
		l.tags = l.tags.duplicate()
		l.tags.append("tall")
	layers[id] = l
	return l


## Story anchors keep 12 m round them free of tall scatter (story_anchors contract).
const ANCHOR_CLEAR := 12.0
static var _anchors: PackedVector2Array = []


static func near_anchor(x: float, z: float) -> bool:
	if _anchors.is_empty():
		for a in ManorRoseGarden.story_anchors().values():
			_anchors.append(a[0])
	for a in _anchors:
		if a.distance_to(Vector2(x, z)) < ANCHOR_CLEAR:
			return true
	return false


func _blocked(id: StringName, x: float, z: float) -> bool:
	return layer(id).tags.has("tall") and near_anchor(x, z)


## Puts one instance standing on the ground at x/z.
func put(id: StringName, x: float, z: float, yaw: float = 0.0, scale: float = 1.0, lift: float = 0.0) -> void:
	if _blocked(id, x, z):
		return
	layer(id).add(Vector3(x, WorldHeight.height_at(x, z) + lift, z), yaw, scale)


## Puts one instance at an exact world position (on a wall, on water, in a loft).
func put_at(id: StringName, pos: Vector3, yaw: float = 0.0, scale: float = 1.0) -> void:
	if _blocked(id, pos.x, pos.z):
		return
	layer(id).add(pos, yaw, scale)


## Every zone forage uses: the site plan's zones plus the grounds sub-areas.
static func zones() -> Dictionary:
	var z := ManorSitePlan.zones()
	z[&"southeast_park"] = [ManorSitePlan.SOUTHEAST_PARK, &"woodland_edge"]
	z[&"southwest_park"] = [ManorSitePlan.SOUTHWEST_PARK, &"meadow"]
	z[&"east_glade"] = [ManorSitePlan.EAST_GLADE, &"lawn"]
	return z


## Structure footprints scatter avoids (besides ManorSitePlan.keep_out()).
static func footprints() -> Array[Rect2]:
	var out: Array[Rect2] = []
	out.append_array(ManorGlassHouses.footprints())
	out.append_array(ManorKitchenGarden.footprints())
	out.append_array(ManorPond.footprints())
	out.append_array(ManorBelvedere.footprints())
	out.append_array(ManorForecourt.footprints())
	out.append_array(ManorOrchard.footprints())
	out.append(ManorSitePlan.HEDGE_MAZE)   # the maze places its own (cell centres)
	return out


static var _fp_cache: Array[Rect2] = []


static func is_free(x: float, z: float, allow_water: bool = false) -> bool:
	var b := ManorSitePlan.BOUNDS
	if x < b.position.x + 2.0 or x > b.end.x - 2.0 or z < b.position.y + 2.0 or z > b.end.y - 2.0:
		return false
	if ManorSitePlan.is_on_path(x, z):
		return false
	if allow_water:
		return ManorSitePlan.in_pond(x, z, 0.92)
	if ManorSitePlan.is_kept_out(x, z) or ManorSitePlan.in_pond(x, z, 1.12):
		return false
	if _fp_cache.is_empty():
		_fp_cache = footprints()
	var p := Vector2(x, z)
	for r in _fp_cache:
		if r.has_point(p):
			return false
	return true


## Scatters `count` instances over a zone in clusters of `cluster`.
func scatter_zone(id: StringName, zone: StringName, count: int, cluster: int = 4, radius: float = 3.5, scale_range: Vector2 = Vector2(0.8, 1.2)) -> int:
	var z: Array = zones()[zone]
	var rect: Rect2 = z[0]
	var rng := EstateKit.rng("manor_scatter|%s|%s" % [id, zone])
	var water := id == &"ing_trout" or id == &"deco_water_lily"
	var placed := 0
	var tries := 0
	while placed < count and tries < count * 40:
		tries += 1
		var cx := rng.randf_range(rect.position.x, rect.end.x)
		var cz := rng.randf_range(rect.position.y, rect.end.y)
		if not is_free(cx, cz, water):
			continue
		for k in mini(cluster, count - placed):
			var a := rng.randf() * TAU
			var r := sqrt(rng.randf()) * radius if k > 0 else 0.0
			var x := cx + cos(a) * r
			var zz := cz + sin(a) * r
			if not rect.has_point(Vector2(x, zz)) or not is_free(x, zz, water):
				continue
			if water:
				put_at(id, Vector3(x, ManorTerrain.pond_level() + 0.02, zz), rng.randf() * TAU, rng.randf_range(scale_range.x, scale_range.y))
			else:
				put(id, x, zz, rng.randf() * TAU, rng.randf_range(scale_range.x, scale_range.y))
			placed += 1
	return placed


# --- The whole estate ---------------------------------------------------------

## Generic zone forage: id -> [[zone, count, cluster], ...]. Structures add
## their own placements (beds, walls, hives, dead ends) in their plant().
const FORAGE := {
	&"ing_rose_red": [[&"south_lawns", 40, 5], [&"walled_orchard", 20, 4], [&"southwest_park", 20, 4], [&"east_glade", 12, 4]],
	&"ing_rose_white": [[&"south_lawns", 30, 5], [&"east_glade", 15, 5], [&"southeast_park", 15, 5]],
	&"ing_rose_gold": [[&"deer_park", 12, 3], [&"east_glade", 9, 3]],
	&"ing_lavender": [[&"west_downs", 120, 8], [&"east_meadow", 60, 8], [&"kitchen_garden", 24, 6], [&"southwest_park", 40, 8]],
	&"ing_honeysuckle": [[&"paddock", 30, 3], [&"west_woods_edge", 24, 4], [&"east_woods_edge", 20, 4], [&"south_lawns", 18, 3]],
	&"ing_wisteria": [[&"stables", 6, 2], [&"east_glade", 8, 2], [&"south_lawns", 8, 2]],
	&"ing_lilac": [[&"rose_garden", 16, 2], [&"south_lawns", 30, 3], [&"deer_park", 20, 3], [&"east_glade", 15, 3]],
	&"ing_cherry_blossom": [[&"deer_park", 20, 4], [&"southeast_park", 16, 4]],
	&"ing_elderflower": [[&"west_downs", 20, 2], [&"north_hills", 30, 2], [&"southeast_park", 20, 2], [&"walled_orchard", 8, 2]],
	&"ing_wild_strawberry": [[&"east_meadow", 80, 8], [&"west_downs", 60, 8], [&"south_lawns", 40, 6], [&"walled_orchard", 30, 6], [&"southeast_park", 40, 6]],
	&"ing_blackberry": [[&"north_hills", 50, 5], [&"west_woods_edge", 40, 5], [&"east_woods_edge", 40, 5], [&"paddock", 20, 4], [&"southwest_park", 30, 5]],
	&"ing_willow_bark": [[&"west_woods_edge", 12, 2], [&"east_woods_edge", 12, 2], [&"southwest_park", 8, 2]],
	&"ing_wild_hyacinth": [[&"north_hills", 150, 10], [&"west_woods_edge", 80, 10], [&"east_woods_edge", 80, 10], [&"deer_park", 60, 10], [&"southeast_park", 60, 10]],
	&"ing_foxglove": [[&"north_hills", 50, 5], [&"west_woods_edge", 30, 5], [&"east_woods_edge", 30, 5], [&"south_lawns", 20, 5]],
	&"ing_faelight_dandelion": [[&"south_lawns", 120, 8], [&"east_meadow", 80, 8], [&"deer_park", 60, 8], [&"west_downs", 60, 8], [&"southwest_park", 40, 8]],
	&"ing_moss": [[&"north_hills", 100, 8], [&"west_woods_edge", 60, 8], [&"east_woods_edge", 60, 8], [&"pond", 30, 6], [&"stables", 8, 4]],
	&"ing_snail_shell": [[&"kitchen_garden", 20, 3], [&"rose_garden", 15, 3], [&"pond", 20, 3], [&"walled_orchard", 12, 3], [&"stables", 8, 2]],
	&"ing_hawk_feather": [[&"paddock", 15, 1], [&"east_meadow", 20, 1], [&"west_downs", 20, 1], [&"deer_park", 15, 1], [&"north_hills", 15, 1]],
	&"ing_owl_feather": [[&"north_hills", 20, 1], [&"walled_orchard", 8, 1], [&"west_woods_edge", 10, 1], [&"east_woods_edge", 10, 1]],
	&"ing_trout": [[&"pond", 30, 1]],
	&"ing_manor_fruit": [[&"kitchen_garden", 15, 2]],
	&"ing_madder": [[&"kitchen_garden", 20, 4], [&"west_downs", 30, 5], [&"east_meadow", 30, 5], [&"paddock", 15, 5]],
	&"ing_river_silt": [],
	&"ing_crab_apple": [[&"deer_park", 20, 4], [&"east_glade", 10, 4]],
	&"ing_buttercup": [[&"east_meadow", 150, 10], [&"west_downs", 120, 10], [&"deer_park", 80, 10], [&"paddock", 60, 10], [&"south_lawns", 60, 10], [&"southeast_park", 60, 10], [&"southwest_park", 60, 10]],
	&"ing_iris": [[&"rose_garden", 20, 5], [&"pond", 40, 5], [&"kitchen_garden", 10, 5]],
	&"ing_crocus": [[&"south_lawns", 150, 10], [&"deer_park", 80, 10], [&"rose_garden", 30, 10], [&"east_meadow", 60, 10], [&"north_hills", 50, 10], [&"east_glade", 30, 10]],
	&"ing_glowcap": [[&"north_hills", 40, 5], [&"west_woods_edge", 30, 5], [&"east_woods_edge", 30, 5]],
	&"col_pressed_violet": [[&"rose_garden", 5, 1], [&"deer_park", 5, 1], [&"east_glade", 4, 1]],
	&"col_painted_pebble": [[&"pond", 6, 1], [&"kitchen_garden", 4, 1], [&"south_lawns", 6, 1], [&"southwest_park", 4, 1]],
	&"col_lost_ribbon": [[&"rose_garden", 4, 1], [&"south_lawns", 5, 1], [&"walled_orchard", 4, 1]],
	&"col_pearl_button": [[&"rose_garden", 4, 1], [&"kitchen_garden", 4, 1], [&"stables", 4, 1]],
	&"col_glass_marble": [[&"south_lawns", 5, 1], [&"pond", 4, 1], [&"southeast_park", 4, 1]],
	&"col_tiny_horseshoe": [[&"stables", 6, 1], [&"paddock", 6, 1], [&"south_lawns", 4, 1], [&"west_downs", 4, 1]],
	&"col_garden_key": [[&"walled_orchard", 3, 1], [&"kitchen_garden", 3, 1]],
	&"col_mask_feather": [[&"rose_garden", 4, 1], [&"deer_park", 4, 1], [&"north_hills", 5, 1], [&"east_meadow", 4, 1]],
	&"col_rose_quartz": [[&"north_hills", 6, 1], [&"east_woods_edge", 5, 1], [&"west_woods_edge", 5, 1], [&"east_meadow", 4, 1]],
	&"col_shell_comb": [[&"pond", 6, 1], [&"southeast_park", 4, 1], [&"west_downs", 4, 1]],
	&"col_silver_thimble": [[&"kitchen_garden", 4, 1], [&"stables", 3, 1], [&"walled_orchard", 3, 1], [&"southwest_park", 4, 1]],
	&"col_gilt_acorn": [[&"deer_park", 5, 1], [&"north_hills", 6, 1], [&"east_woods_edge", 4, 1], [&"west_woods_edge", 4, 1]],
}

## Decoration over open ground: id -> [[zone, count, cluster], ...].
const DECO := {
	&"deco_daisy": [[&"south_lawns", 260, 12], [&"deer_park", 120, 12], [&"east_meadow", 100, 12], [&"southwest_park", 80, 12], [&"southeast_park", 80, 12]],
	&"deco_forget_me_not": [[&"west_downs", 120, 12], [&"east_meadow", 100, 12], [&"pond", 60, 10], [&"north_hills", 80, 10]],
	&"deco_tulip_bed": [[&"south_lawns", 90, 10], [&"east_glade", 50, 10]],
	&"deco_fern": [[&"north_hills", 200, 6], [&"west_woods_edge", 90, 6], [&"east_woods_edge", 90, 6], [&"southeast_park", 50, 6]],
	&"deco_oak": [[&"north_hills", 170, 3], [&"deer_park", 26, 1], [&"south_lawns", 14, 1], [&"west_woods_edge", 50, 3], [&"east_woods_edge", 50, 3], [&"southwest_park", 30, 3], [&"southeast_park", 34, 3]],
	&"deco_birch": [[&"north_hills", 150, 4], [&"east_meadow", 22, 2], [&"west_woods_edge", 50, 4], [&"east_woods_edge", 50, 4], [&"southeast_park", 26, 3], [&"west_downs", 16, 2]],
	&"deco_apple_blossom": [[&"south_lawns", 14, 1], [&"deer_park", 10, 1], [&"east_glade", 8, 1]],
	&"deco_cherry_blossom": [[&"deer_park", 10, 1], [&"southwest_park", 16, 2], [&"east_glade", 8, 1]],
}

## Multipliers on the zone counts above (instances are cheap; chunks cost draws).
const FORAGE_DENSITY := 1.8
const DECO_DENSITY := 1.4

## Types that stay in fewer than 3 zones on purpose (each with its reason).
const FEW_ZONES_OK := {
	&"ing_trout": "fish only live in the pond",
	&"ing_river_silt": "silt only gathers on the pond shore",
}


static func build_all() -> Array[ScatterLayer]:
	_fp_cache.clear()
	var sb := ManorScatter.new()
	# Structures plant first: beds, borders, walls, hives, avenue, orchard rows.
	ManorForecourt.plant(sb)
	ManorTerraceBuilder.plant(sb)
	ManorRoseGarden.plant(sb)
	ManorHedgeMaze.plant(sb)
	ManorGlassHouses.plant(sb)
	ManorKitchenGarden.plant(sb)
	ManorStables.plant(sb)
	ManorPond.plant(sb)
	ManorOrchard.plant(sb)
	ManorBelvedere.plant(sb)
	for id: StringName in FORAGE:
		var mult := FORAGE_DENSITY if String(id).begins_with("ing_") else 1.0
		for e in FORAGE[id]:
			sb.scatter_zone(id, e[0], roundi(e[1] * mult), e[2])
	for id: StringName in DECO:
		var tree := (sb._specs[id]["tags"] as PackedStringArray).has("tree")
		for e in DECO[id]:
			sb.scatter_zone(id, e[0], e[1] if tree else roundi(e[1] * DECO_DENSITY), e[2], 9.0 if tree else 4.0, Vector2(0.75, 1.25))
	sb.fill_empty_cells()
	var out: Array[ScatterLayer] = []
	var ids := sb.layers.keys()
	ids.sort()
	for id in ids:
		var l: ScatterLayer = sb.layers[id]
		l.mesh = ManorLooks.mesh_for(sb._specs[id]["look"])
		out.append(l)
	return out


## Any 100 m cell left without an interactable gets a crocus patch and a keepsake-free forage.
func fill_empty_cells() -> void:
	var area := ManorSitePlan.BOUNDS
	var filled := {}
	for id in layers:
		var l: ScatterLayer = layers[id]
		if not (l.is_forage() or l.tags.has("collectible")):
			continue
		for i in l.count():
			var p := l.position_of(i)
			filled[Vector2i(floori((p.x - area.position.x) / ScatterReport.CELL), floori((p.z - area.position.y) / ScatterReport.CELL))] = true
	var rng := EstateKit.rng("manor_scatter|fill")
	for cx in ceili(area.size.x / ScatterReport.CELL):
		for cz in ceili(area.size.y / ScatterReport.CELL):
			if filled.has(Vector2i(cx, cz)):
				continue
			var x0 := area.position.x + cx * ScatterReport.CELL
			var z0 := area.position.y + cz * ScatterReport.CELL
			var placed := 0
			for t in 200:
				var x := x0 + rng.randf_range(4.0, 96.0)
				var z := z0 + rng.randf_range(4.0, 96.0)
				if is_free(x, z):
					put(&"ing_crocus", x, z, rng.randf() * TAU, 1.0)
					placed += 1
					if placed >= 6:
						break


# --- Load / save --------------------------------------------------------------

static func layer_path(id: StringName) -> String:
	return DIR + String(id) + ".tres"


## Loads the generated layers, or builds them in memory if any are missing.
static func load_or_build() -> Array[ScatterLayer]:
	var s := specs()
	var out: Array[ScatterLayer] = []
	var index_path := DIR + "layers.txt"
	if FileAccess.file_exists(index_path):
		var ids := FileAccess.get_file_as_string(index_path).split("\n", false)
		for id in ids:
			var path := layer_path(StringName(id))
			if not ResourceLoader.exists(path) or not s.has(StringName(id)):
				out.clear()
				break
			var l := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as ScatterLayer
			l.mesh = ManorLooks.mesh_for(s[StringName(id)]["look"])
			out.append(l)
		if not out.is_empty():
			return out
	return build_all()


static func save_all(list: Array[ScatterLayer]) -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	var ids := PackedStringArray()
	for l in list:
		var copy := l.duplicate() as ScatterLayer
		copy.mesh = null
		ResourceSaver.save(copy, layer_path(l.id))
		ids.append(String(l.id))
	var f := FileAccess.open(DIR + "layers.txt", FileAccess.WRITE)
	f.store_string("\n".join(ids) + "\n")


const CHUNK := 64.0
const WIDE_CHUNK := 128.0
const SPARSE_PER_CHUNK := 12


## Trees and sparse layers (fewer than SPARSE_PER_CHUNK instances per 64 m chunk) go in a
## second field with 128 m chunks, so a lone feather is not a draw call of its own.
static func chunk_size_for(l: ScatterLayer) -> float:
	if l.tags.has("tree"):
		return WIDE_CHUNK
	var keys := {}
	for i in l.count():
		var p := l.position_of(i)
		keys[Vector2i(floori(p.x / CHUNK), floori(p.z / CHUNK))] = true
	return WIDE_CHUNK if l.count() < keys.size() * SPARSE_PER_CHUNK else CHUNK


## The estate's two ScatterFields (64 m and 128 m chunks), plus one StaticBody
## of tree-trunk colliders. Returns the 64 m field.
static func add_field(parent: Node3D, list: Array[ScatterLayer] = []) -> ScatterField:
	if list.is_empty():
		list = load_or_build()
	var near: Array[ScatterLayer] = []
	var wide: Array[ScatterLayer] = []
	for l in list:
		if chunk_size_for(l) == CHUNK:
			near.append(l)
		else:
			wide.append(l)
	var field := ScatterField.new()
	field.name = "ScatterField"
	field.region_id = REGION_ID
	field.layers = near
	field.chunk_size = CHUNK
	parent.add_child(field)
	var wide_field := ScatterField.new()
	wide_field.name = "ScatterFieldWide"
	wide_field.region_id = REGION_ID
	wide_field.layers = wide
	wide_field.chunk_size = WIDE_CHUNK
	parent.add_child(wide_field)
	var trunks := StaticBody3D.new()
	trunks.name = "TreeTrunks"
	trunks.collision_layer = EstateKit.WORLD_LAYER
	trunks.collision_mask = 0
	var shape := CylinderShape3D.new()
	shape.radius = 0.45
	shape.height = 4.0
	for l in list:
		if not l.tags.has("tree"):
			continue
		for i in l.count():
			var cs := CollisionShape3D.new()
			cs.shape = shape
			cs.position = l.position_of(i) + Vector3.UP * 2.0
			trunks.add_child(cs)
	parent.add_child(trunks)
	return field


## Distinct zones a layer's instances fall in.
static func zones_of(l: ScatterLayer) -> PackedStringArray:
	var z := zones()
	var out := PackedStringArray()
	for i in l.count():
		var p := l.position_of(i)
		var q := Vector2(p.x, p.z)
		for id: StringName in z:
			if not out.has(String(id)) and (z[id][0] as Rect2).has_point(q):
				out.append(String(id))
	return out


## Estimated draw calls of the scatter: one per chunk multimesh (and impostor).
static func chunk_draws(list: Array[ScatterLayer], fixed_chunk: float = 0.0) -> int:
	var n := 0
	for l in list:
		var chunk_size := fixed_chunk if fixed_chunk > 0.0 else chunk_size_for(l)
		var keys := {}
		for i in l.count():
			var p := l.position_of(i)
			keys[Vector2i(floori(p.x / chunk_size), floori(p.z / chunk_size))] = true
		n += keys.size() * (2 if l.impostor_mesh != null else 1)
	return n


## Scatter draw calls actually drawn from the worst viewpoint in the estate:
## chunks beyond a layer's draw_distance (plus half a chunk diagonal) are
## culled by their visibility range. Viewpoints on a 50 m grid; returns [max, at].
static func visible_chunk_draws(list: Array[ScatterLayer]) -> Array:
	var centers := []    # per layer: [draw distance, PackedVector2Array of chunk centres]
	for l in list:
		var chunk_size := chunk_size_for(l)
		var keys := {}
		for i in l.count():
			var p := l.position_of(i)
			keys[Vector2i(floori(p.x / chunk_size), floori(p.z / chunk_size))] = true
		var pts := PackedVector2Array()
		for k: Vector2i in keys:
			pts.append(Vector2((k.x + 0.5) * chunk_size, (k.y + 0.5) * chunk_size))
		centers.append([l.draw_distance + chunk_size * 0.71, pts])
	var b := ManorSitePlan.BOUNDS
	var best := 0
	var at := Vector2.ZERO
	var x := b.position.x
	while x <= b.end.x:
		var z := b.position.y
		while z <= b.end.y:
			var v := Vector2(x, z)
			var n := 0
			for c in centers:
				var r: float = c[0]
				for p: Vector2 in c[1]:
					if p.distance_to(v) <= r:
						n += 1
			if n > best:
				best = n
				at = v
			z += 50.0
		x += 50.0
	return [best, at]
