## The village's deterministic layout: every building, prop, forage plant and
## keepsake, as ScatterLayers plus the landmark/light/smoke/collision data the
## generator (village_gen.gd) turns into village.tscn. Pure data: no nodes, so
## tests can run it twice and compare.
##
## Lore: lore/02-locations/human-village.md. A poor, hardened, superstitious
## farming and market village near the Wall, in deep winter.
class_name VillagePlan
extends RefCounted

const REGION_ID := &"village"
const SEED := 74120
const CHUNK := 64.0
const ASSET := "res://world/human_realm/village/assets/village_%s.glb"
const FLORA := "res://world/human_realm/shared/assets/flora/%s.glb"
const FLORA_FAR := "res://world/human_realm/shared/assets/flora/%s_far.glb"
const PROPS_MAT := "res://world/human_realm/village/materials/village_props.tres"
const FLORA_MAT := "res://world/shared/materials/stylized_flora.tres"
## Inside this radius of the square is the village proper; beyond is fields.
const CORE_RADIUS := 140.0
const MAX_HOUSES := 18

## Clearance footprint per kind: (width along local X, depth along local Z).
## Front (door) faces local +Z. Matches the Blender scripts' sizes.
const FOOT := {
	&"house_timber": Vector2(7.6, 5.6), &"house_wattle": Vector2(6.2, 4.6),
	&"house_long": Vector2(11.8, 5.2), &"house_croft": Vector2(5.2, 4.2),
	&"shed": Vector2(3.4, 2.8), &"tavern": Vector2(12.4, 8.4),
	&"meeting_hall": Vector2(14.4, 8.4), &"debt_house": Vector2(5.9, 4.5),
	&"barn_abandoned": Vector2(14.2, 9.2), &"mill": Vector2(8.4, 7.4),
	&"smithy": Vector2(7.2, 5.6), &"well": Vector2(2.4, 2.4),
	&"stall": Vector2(3.2, 2.2), &"shrine": Vector2(1.5, 1.1),
	&"pillory": Vector2(1.3, 1.3), &"notice_board": Vector2(2.0, 0.4),
	&"cart": Vector2(3.4, 1.8), &"woodpile": Vector2(2.4, 1.1),
	&"chicken_coop": Vector2(2.1, 1.6), &"haystack": Vector2(2.9, 2.9),
	&"trough": Vector2(2.1, 0.8), &"washing_line": Vector2(6.2, 0.5),
	&"bridge": Vector2(5.6, 20.0), &"barrel": Vector2(0.9, 0.9), &"crate": Vector2(0.8, 0.8),
	&"lantern_post": Vector2(0.3, 0.3),
}
## Kinds that are buildings (the GUT test checks these against roads/creek).
const BUILDING_KINDS := [&"house_timber", &"house_wattle", &"house_long", &"house_croft",
	&"shed", &"tavern", &"meeting_hall", &"debt_house", &"barn_abandoned", &"mill", &"smithy"]

## Collision per kind (local): [centre, size] boxes; a Vector2 size is a
## cylinder (radius, height).
const COLLIDE := {
	&"house_timber": [[Vector3(0, 3.8, 0), Vector3(7.5, 7.6, 5.5)]],
	&"house_wattle": [[Vector3(0, 2.6, 0), Vector3(6.0, 5.2, 4.4)]],
	&"house_long": [[Vector3(0, 2.8, 0), Vector3(10.0, 5.6, 5.0)], [Vector3(5.9, 1.1, 0), Vector3(1.8, 2.2, 3.6)]],
	&"house_croft": [[Vector3(0, 2.2, 0), Vector3(5.0, 4.4, 4.0)]],
	&"shed": [[Vector3(0, 1.2, 0), Vector3(3.2, 2.4, 2.6)]],
	&"tavern": [
		[Vector3(-4.15, 1.9, 3.825), Vector3(3.7, 3.2, 0.35)],
		[Vector3(2.65, 1.9, 3.825), Vector3(6.7, 3.2, 0.35)],
		[Vector3(-1.5, 3.1, 3.825), Vector3(1.6, 0.8, 0.35)],
		[Vector3(0, 1.9, -3.825), Vector3(12.0, 3.2, 0.35)],
		[Vector3(-5.825, 1.9, 0), Vector3(0.35, 3.2, 8.0)],
		[Vector3(5.825, 1.9, 0), Vector3(0.35, 3.2, 8.0)],
		[Vector3(0, 6.25, 0), Vector3(12.4, 5.5, 8.4)],
		[Vector3(3.0, 1.0, -2.2), Vector3(4.4, 1.2, 1.0)],
		[Vector3(-5.2, 1.1, -0.6), Vector3(2.4, 1.4, 1.1)],
	],
	&"meeting_hall": [[Vector3(0, 4.7, 0), Vector3(14.4, 9.4, 8.4)]],
	&"debt_house": [[Vector3(0, 2.2, 0), Vector3(5.6, 4.4, 4.2)]],
	&"barn_abandoned": [[Vector3(0, 4.5, 0), Vector3(14.0, 9.0, 9.0)]],
	&"mill": [[Vector3(0, 4.5, 0), Vector3(8.3, 9.0, 7.3)]],
	&"mill_wheel": [[Vector3(0, 2.6, 0), Vector3(1.4, 5.2, 5.2)]],
	&"smithy": [
		[Vector3(0, 1.5, -2.55), Vector3(7.0, 3.0, 0.4)],
		[Vector3(-3.3, 1.5, 0), Vector3(0.4, 3.0, 5.5)],
		[Vector3(3.3, 1.5, 0), Vector3(0.4, 3.0, 5.5)],
		[Vector3(0, 1.5, 2.6), Vector3(0.3, 3.0, 0.3)],
		[Vector3(0, 4.1, 0), Vector3(7.6, 2.2, 6.6)],
		[Vector3(-1.6, 0.65, -1.6), Vector3(1.8, 1.3, 1.4)],
		[Vector3(0.6, 0.5, -0.2), Vector3(0.8, 1.0, 0.5)],
		[Vector3(4.4, 0.4, 1.2), Vector3(1.8, 0.8, 1.6)],
	],
	&"bridge": [
		[Vector3(0, -0.224, -9), Vector3(4.6, 0.6, 2.05)],
		[Vector3(0, -0.096, -7), Vector3(4.6, 0.6, 2.05)],
		[Vector3(0, 0.000, -5), Vector3(4.6, 0.6, 2.05)],
		[Vector3(0, 0.064, -3), Vector3(4.6, 0.6, 2.05)],
		[Vector3(0, 0.096, -1), Vector3(4.6, 0.6, 2.05)],
		[Vector3(0, 0.096, 1), Vector3(4.6, 0.6, 2.05)],
		[Vector3(0, 0.064, 3), Vector3(4.6, 0.6, 2.05)],
		[Vector3(0, 0.000, 5), Vector3(4.6, 0.6, 2.05)],
		[Vector3(0, -0.096, 7), Vector3(4.6, 0.6, 2.05)],
		[Vector3(0, -0.224, 9), Vector3(4.6, 0.6, 2.05)],
		[Vector3(-2.5, 0.5, 0), Vector3(0.45, 1.2, 20.0)],
		[Vector3(2.5, 0.5, 0), Vector3(0.45, 1.2, 20.0)],
	],
	&"well": [[Vector3(0, 0.5, 0), Vector2(1.1, 1.0)]],
	&"stall": [[Vector3(0, 0.45, 0.55), Vector3(3.1, 0.9, 0.9)]],
	&"shrine": [[Vector3(0, 1.1, 0), Vector3(1.4, 2.2, 1.0)]],
	&"pillory": [[Vector3(0, 1.1, 0), Vector3(1.2, 2.2, 1.2)]],
	&"notice_board": [[Vector3(0, 1.2, 0), Vector3(2.0, 2.4, 0.3)]],
	&"lantern_post": [[Vector3(0, 1.4, 0), Vector3(0.2, 2.8, 0.2)]],
	&"cart": [[Vector3(0, 0.75, 0), Vector3(2.3, 1.5, 1.7)]],
	&"barrel": [[Vector3(0, 0.45, 0), Vector2(0.42, 0.9)]],
	&"crate": [[Vector3(0, 0.37, 0), Vector3(0.8, 0.75, 0.8)]],
	&"woodpile": [[Vector3(0, 0.55, 0), Vector3(2.2, 1.1, 1.0)]],
	&"chicken_coop": [[Vector3(0, 0.8, 0), Vector3(2.0, 1.6, 1.4)]],
	&"haystack": [[Vector3(0, 1.5, 0), Vector2(1.4, 3.0)]],
	&"trough": [[Vector3(0, 0.35, 0), Vector3(2.0, 0.7, 0.7)]],
	&"fence_wattle": [[Vector3(0, 0.6, 0), Vector3(2.5, 1.2, 0.14)]],
	&"fence_rail": [[Vector3(0, 0.6, 0), Vector3(3.0, 1.2, 0.16)]],
	&"stone_wall": [[Vector3(0, 0.6, 0), Vector3(3.0, 1.2, 0.6)]],
	&"tree_oak": [[Vector3(0, 2.0, 0), Vector2(0.45, 4.0)]],
	&"tree_birch": [[Vector3(0, 2.0, 0), Vector2(0.2, 4.0)]],
	&"tree_willow": [[Vector3(0, 1.5, 0), Vector2(0.4, 3.0)]],
	&"tree_snag": [[Vector3(0, 2.0, 0), Vector2(0.3, 4.0)]],
}
## Chimney tops (local) for smoke.
const CHIMNEYS := {
	&"house_timber": Vector3(2.6, 9.6, -0.9), &"house_wattle": Vector3(-2.3, 6.4, -0.6),
	&"house_long": Vector3(-1.5, 7.2, 0.0), &"house_croft": Vector3(2.3, 5.3, 0.0),
	&"tavern": Vector3(4.8, 11.0, -1.5), &"debt_house": Vector3(1.8, 5.9, -0.5),
	&"smithy": Vector3(-1.6, 6.6, -1.9),
}

var rng := RandomNumberGenerator.new()
var rect: Rect2
## id -> ScatterLayer, in creation order.
var layers := {}
## layer id -> collision kind (a COLLIDE key) for layers that collide.
var layer_kind := {}
## Every building/prop that blocks placement: {c: Vector2, h: Vector2 half extents, yaw}.
var blockers: Array[Dictionary] = []
## Buildings placed: {name, kind, layer, pos: Vector2, yaw, y}.
var buildings: Array[Dictionary] = []
## Named landmark nodes: {name, xf: Transform3D, kind, markers: {name: Transform3D (local)}}.
var landmarks: Array[Dictionary] = []
## OmniLights: {name, pos: Vector3, range, energy, color}.
var lights: Array[Dictionary] = []
var smokes: PackedVector3Array = []
## FogVolumes: {name, pos: Vector3, size: Vector3, density}.
var fogs: Array[Dictionary] = []
var _gardens: Array[Rect2] = []
var verbose := false


func generate() -> void:
	rng.seed = SEED
	rect = HumanRealmLayout.REGION_RECTS[REGION_ID]
	_define_layers()
	for step in ["_place_landmarks", "_place_square", "_place_houses", "_place_fence_line",
			"_place_fields", "_place_creek", "_place_village_finds", "_fill_empty_cells"]:
		var t0 := Time.get_ticks_msec()
		call(step)
		if verbose:
			print("  %s: %d ms" % [step, Time.get_ticks_msec() - t0])


func layer_list() -> Array[ScatterLayer]:
	var out: Array[ScatterLayer] = []
	for id: StringName in layers:
		out.append(layers[id])
	return out


# --- layer definitions -------------------------------------------------------

func _def(id: StringName, mesh: String, ingredient: StringName, tags: Array, canon: String,
		dist := 120.0, shadow := true, wind := 0.0, flora := false, far := "", kind: StringName = &"") -> void:
	var l := ScatterLayer.new()
	l.id = id
	l.mesh_path = mesh
	l.ingredient_id = ingredient
	var t := PackedStringArray(tags)
	t.append("canon:" + canon)
	l.tags = t
	l.draw_distance = dist
	l.cast_shadow = shadow
	l.wind = wind
	l.material = load(FLORA_MAT if flora else PROPS_MAT)
	if far != "":
		l.impostor_path = far
	layers[id] = l
	if kind != &"":
		layer_kind[id] = kind


func _a(n: String) -> String:
	return ASSET % n


func _f(n: String) -> String:
	return FLORA % n


func _define_layers() -> void:
	# Landmark buildings (one instance each, tagged landmark).
	_def(&"tavern", _a("tavern"), &"", ["landmark"], "X", 600.0, true, 0.0, false, "", &"tavern")
	_def(&"tavern_interior", _a("tavern_interior"), &"", [], "X", 40.0, false)
	_def(&"meeting_hall", _a("meeting_hall"), &"", ["landmark"], "C", 600.0, true, 0.0, false, "", &"meeting_hall")
	_def(&"debt_house", _a("debt_house"), &"", ["landmark"], "X", 600.0, true, 0.0, false, "", &"debt_house")
	_def(&"barn_abandoned", _a("barn_abandoned"), &"", ["landmark"], "C", 600.0, true, 0.0, false, "", &"barn_abandoned")
	_def(&"mill", _a("mill"), &"", ["landmark"], "X", 600.0, true, 0.0, false, "", &"mill")
	_def(&"mill_wheel", _a("mill_wheel"), &"", [], "X", 400.0, true, 0.0, false, "", &"mill_wheel")
	_def(&"smithy", _a("smithy"), &"", ["landmark"], "X", 600.0, true, 0.0, false, "", &"smithy")
	_def(&"creek_bridge", _a("bridge"), &"", ["landmark"], "X", 400.0, true, 0.0, false, "", &"bridge")
	_def(&"well", _a("well"), &"", ["landmark"], "C", 300.0, true, 0.0, false, "", &"well")
	_def(&"shrine", _a("shrine"), &"", ["landmark"], "X", 200.0, true, 0.0, false, "", &"shrine")
	_def(&"pillory", _a("pillory"), &"", ["landmark"], "X", 200.0, true, 0.0, false, "", &"pillory")
	_def(&"notice_board", _a("notice_board"), &"", ["landmark"], "X", 200.0, true, 0.0, false, "", &"notice_board")
	# Market (canon: the market square where Feyre sells the pelt).
	for c in ["grey", "brown", "blue"]:
		_def(StringName("stall_" + c), _a("stall_" + c), &"", [], "C", 300.0, true, 0.0, false, "", &"stall")
	for g in ["furs", "grain", "salt", "iron"]:
		_def(StringName("goods_" + g), _a("goods_" + g), &"", [], "C", 120.0, false)
	_def(&"goods_pelts", _a("goods_pelts"), &"", ["landmark"], "C", 120.0, false)
	# Houses.
	for k in ["house_timber", "house_wattle", "house_long", "house_croft", "shed"]:
		_def(StringName(k), _a(k), &"", [], "X", 500.0, true, 0.0, false, "", StringName(k))
	# Village props.
	_def(&"fence_wattle", _a("fence_wattle"), &"", [], "X", 150.0, true, 0.0, false, "", &"fence_wattle")
	_def(&"fence_rail", _a("fence_rail"), &"", [], "X", 150.0, true, 0.0, false, "", &"fence_rail")
	_def(&"lantern_post", _a("lantern_post"), &"", [], "X", 200.0, true, 0.0, false, "", &"lantern_post")
	_def(&"woodpile", _a("woodpile"), &"", [], "X", 120.0, true, 0.0, false, "", &"woodpile")
	_def(&"washing_line", _a("washing_line"), &"", ["look"], "X", 120.0, true, 0.0)
	_def(&"cart", _a("cart"), &"", [], "X", 150.0, true, 0.0, false, "", &"cart")
	_def(&"barrel", _a("barrel"), &"", [], "X", 90.0, true, 0.0, false, "", &"barrel")
	_def(&"crate", _a("crate"), &"", [], "X", 90.0, true, 0.0, false, "", &"crate")
	_def(&"chicken_coop", _a("chicken_coop"), &"", [], "X", 120.0, true, 0.0, false, "", &"chicken_coop")
	_def(&"haystack", _a("haystack"), &"", [], "X", 300.0, true, 0.0, false, "", &"haystack")
	_def(&"trough", _a("trough"), &"", [], "X", 90.0, true, 0.0, false, "", &"trough")
	# Village-made forage.
	_def(&"salt_sacks", _a("salt_sack"), &"ing_salt", [], "X", 80.0, false)
	_def(&"iron_filings", _a("iron_filings"), &"ing_iron_filings", [], "X", 60.0, false)
	# Keepsakes (collectible) and notice-moments (look).
	_def(&"dropped_coin", _a("coin"), &"", ["collectible"], "X", 30.0, false)
	_def(&"blessed_pamphlet", _a("pamphlet"), &"", ["collectible"], "C", 30.0, false)
	_def(&"carved_toy", _a("carved_toy"), &"", ["collectible"], "X", 30.0, false)
	_def(&"frozen_ribbon", _a("ribbon"), &"", ["collectible"], "X", 30.0, false)
	_def(&"lost_button", _a("lost_button"), &"", ["collectible"], "X", 25.0, false)
	_def(&"iron_charm", _a("iron_charm"), &"", ["collectible"], "X", 30.0, false)
	_def(&"snowman", _a("snowman"), &"", ["look"], "X", 120.0, true)
	_def(&"cat_curled", _a("cat"), &"", ["look"], "X", 50.0, false)
	_def(&"crow_perched", _a("crow"), &"", ["look"], "X", 60.0, false)
	_def(&"robin_on_post", _a("robin"), &"", ["look"], "X", 40.0, false)
	_def(&"fox_tracks", _a("fox_tracks"), &"", ["look"], "X", 40.0, false)
	_def(&"herb_bundles", _a("herb_bundle"), &"", ["look"], "X", 40.0, false)
	_def(&"shrine_candles", _a("candle_offering"), &"", ["look"], "X", 30.0, false)
	# Flora and found materials from the shared library (worker 1).
	var F := [
		# id, flora mesh, ingredient, dist, shadow, wind, kind
		[&"hedge_hawthorn", "hawthorn", &"ing_hawthorn_haw", 160.0, true, 0.25, &""],
		[&"hedge_blackthorn", "blackthorn_sloe", &"ing_sloe", 160.0, true, 0.25, &""],
		[&"hedge_rose", "wild_rose_briar", &"ing_rose_hip", 140.0, true, 0.3, &""],
		[&"hedge_hazel", "hazel_shrub", &"ing_hazelnut", 160.0, true, 0.3, &""],
		[&"holly", "holly_bush", &"ing_holly_berry", 160.0, true, 0.15, &""],
		[&"bramble", "blackberry_bramble", &"ing_blackberry", 120.0, true, 0.2, &""],
		[&"old_mans_beard", "old_mans_beard", &"ing_old_mans_beard", 80.0, false, 0.4, &""],
		[&"juniper", "juniper_shrub", &"ing_juniper_berry", 140.0, true, 0.15, &""],
		[&"wintergreen", "wintergreen_patch", &"ing_wintergreen", 50.0, false, 0.1, &""],
		[&"snowdrops", "snowdrop_cluster", &"ing_snowdrop", 50.0, false, 0.3, &""],
		[&"woad", "woad_rosette", &"ing_woad", 50.0, false, 0.2, &""],
		[&"madder", "madder_patch", &"ing_madder", 50.0, false, 0.2, &""],
		[&"frozen_reeds", "frozen_reeds", &"ing_frozen_reed", 100.0, false, 0.5, &""],
		[&"acorns", "acorn_scatter", &"ing_acorn", 40.0, false, 0.0, &""],
		[&"oak_galls", "oak_gall_twig", &"ing_oak_gall", 40.0, false, 0.0, &""],
		[&"mistletoe", "mistletoe_clump", &"ing_mistletoe", 50.0, false, 0.1, &""],
		[&"tinder_fungus", "tinder_fungus", &"ing_tinder_fungus", 40.0, false, 0.0, &""],
		[&"charcoal", "charcoal_lump", &"ing_charcoal", 40.0, false, 0.0, &""],
		[&"clay", "clay_lump", &"ing_clay", 40.0, false, 0.0, &""],
		[&"snail_shells", "snail_shells", &"ing_snail_shell", 30.0, false, 0.0, &""],
		[&"flint", "flint_nodule", &"ing_flint", 40.0, false, 0.0, &""],
		[&"chalk", "chalk_lump", &"ing_chalk", 40.0, false, 0.0, &""],
		[&"ice_moss", "ice_moss", &"ing_ice_moss", 40.0, false, 0.0, &""],
		[&"crow_feathers", "feather_crow", &"ing_crow_feather", 30.0, false, 0.2, &""],
		[&"owl_feathers", "feather_owl", &"ing_owl_feather", 30.0, false, 0.2, &""],
		[&"hawk_feathers", "feather_hawk", &"ing_hawk_feather", 30.0, false, 0.2, &""],
		[&"icicles", "icicle_cluster", &"ing_snowmelt_water", 60.0, false, 0.0, &""],
		[&"stone_wall", "stone_wall_section", &"", 200.0, true, 0.0, &"stone_wall"],
		[&"grass_tufts", "winter_grass_tuft", &"", 60.0, false, 0.4, &""],
		[&"dead_bracken", "dead_bracken", &"", 80.0, false, 0.3, &""],
		[&"snow_mounds", "snow_mound", &"", 120.0, false, 0.0, &""],
		[&"stumps", "stump", &"", 100.0, true, 0.0, &""],
		[&"boulders", "rock_boulder_b", &"", 200.0, true, 0.0, &""],
		[&"fallen_logs", "log_fallen", &"", 120.0, true, 0.0, &""],
	]
	for row: Array in F:
		_def(row[0], _f(row[1]), row[2], [], "X", row[3], row[4], row[5], true, "", row[6])
	# Trees (trunk collision per chunk).
	_def(&"tree_oak", _f("tree_oak_bare"), &"", [], "X", 250.0, true, 0.15, true, FLORA_FAR % "tree_oak_bare", &"tree_oak")
	_def(&"tree_birch", _f("tree_birch"), &"ing_birch_bark", [], "X", 250.0, true, 0.2, true, FLORA_FAR % "tree_birch", &"tree_birch")
	_def(&"tree_willow", _f("tree_willow_pollard"), &"ing_willow_bark", [], "X", 250.0, true, 0.2, true, FLORA_FAR % "tree_willow_pollard", &"tree_willow")
	_def(&"tree_snag", _f("tree_dead_snag"), &"", [], "X", 250.0, true, 0.0, true, FLORA_FAR % "tree_dead_snag", &"tree_snag")


# --- placement helpers ---------------------------------------------------------

## Local (x, z) -> world offset for a yaw (matches Basis(Vector3.UP, yaw)).
static func rot(v: Vector2, yaw: float) -> Vector2:
	return Vector2(v.x * cos(yaw) + v.y * sin(yaw), -v.x * sin(yaw) + v.y * cos(yaw))


static func yaw_toward(from: Vector2, to: Vector2) -> float:
	var d := to - from
	return atan2(d.x, d.y)


static func closest_road_point(p: Vector2) -> Vector2:
	var best := p
	var bd := INF
	for line in HumanRealmLayout.ROADS:
		for i in line.size() - 1:
			var q := Geometry2D.get_closest_point_to_segment(p, line[i], line[i + 1])
			var d := p.distance_to(q)
			if d < bd:
				bd = d
				best = q
	return best


static func closest_creek_point(p: Vector2) -> Vector2:
	var best := p
	var bd := INF
	var c := HumanRealmLayout.CREEK
	for i in c.size() - 1:
		var q := Geometry2D.get_closest_point_to_segment(p, c[i], c[i + 1])
		if p.distance_to(q) < bd:
			bd = p.distance_to(q)
			best = q
	return best


static func in_water(p: Vector2, margin: float) -> bool:
	return HumanRealmLayout.distance_to_creek(p) < HumanRealmLayout.CREEK_HALF_WIDTH + margin \
		or p.distance_to(HumanRealmLayout.MILL_POND) < HumanRealmLayout.MILL_POND_RADIUS + margin


static func _blocks(b: Dictionary, p: Vector2, margin: float) -> bool:
	var l := rot(p - b.c, -b.yaw)
	return absf(l.x) < b.h.x + margin and absf(l.y) < b.h.y + margin


static func obb_overlap(a: Dictionary, b: Dictionary, margin := 0.0) -> bool:
	var axes := [Vector2(cos(a.yaw), -sin(a.yaw)), Vector2(sin(a.yaw), cos(a.yaw)),
		Vector2(cos(b.yaw), -sin(b.yaw)), Vector2(sin(b.yaw), cos(b.yaw))]
	var d: Vector2 = b.c - a.c
	for n: Vector2 in axes:
		var ra: float = a.h.x * absf(axes[0].dot(n)) + a.h.y * absf(axes[1].dot(n))
		var rb: float = b.h.x * absf(axes[2].dot(n)) + b.h.y * absf(axes[3].dot(n))
		if absf(d.dot(n)) > ra + rb + margin:
			return false
	return true


## Sample points over a footprint (world), step <= 1 m.
static func footprint_points(c: Vector2, size: Vector2, yaw: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var nx := maxi(2, ceili(size.x)) + 1
	var nz := maxi(2, ceili(size.y)) + 1
	for i in nx:
		for j in nz:
			var l := Vector2(-size.x / 2 + size.x * i / (nx - 1), -size.y / 2 + size.y * j / (nz - 1))
			pts.append(c + rot(l, yaw))
	return pts


## True when a footprint keeps off roads, water and the region edge.
func footprint_clear(c: Vector2, size: Vector2, yaw: float, road_margin := 0.6, water_margin := 1.5) -> bool:
	var inner := rect.grow(-1.0)
	for p in footprint_points(c, size, yaw):
		if not inner.has_point(p):
			return false
		if HumanRealmLayout.distance_to_road(p) < HumanRealmLayout.ROAD_HALF_WIDTH + road_margin:
			return false
		if in_water(p, water_margin):
			return false
	return true


func footprint_free(c: Vector2, size: Vector2, yaw: float, margin := 1.0) -> bool:
	var me := {c = c, h = size * 0.5, yaw = yaw}
	for b in blockers:
		if obb_overlap(me, b, margin):
			return false
	return true


## A free spot of ground for small things.
func ground_ok(p: Vector2, margin := 0.4, allow_water := false) -> bool:
	if not rect.grow(-0.3).has_point(p):
		return false
	if HumanRealmLayout.distance_to_road(p) < HumanRealmLayout.ROAD_HALF_WIDTH + margin:
		return false
	if not allow_water and in_water(p, margin):
		return false
	for b in blockers:
		if _blocks(b, p, margin):
			return false
	return true


func put(id: StringName, p: Vector2, yaw: float, scale := 1.0, y_off := 0.0) -> void:
	var layer: ScatterLayer = layers[id]
	layer.add(Vector3(p.x, WorldHeight.height_at(p.x, p.y) + y_off, p.y), yaw, scale)


## Lowest ground under a footprint, so nothing floats.
func base_height(c: Vector2, size: Vector2, yaw: float) -> float:
	var h := INF
	for l in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1), Vector2.ZERO]:
		var p := c + rot(l * size * 0.5, yaw)
		h = minf(h, WorldHeight.height_at(p.x, p.y))
	return h - 0.08


## Place a building/prop with a footprint, register it as a blocker.
func put_block(id: StringName, kind: StringName, c: Vector2, yaw: float, name := "") -> Dictionary:
	var size: Vector2 = FOOT[kind]
	var y := base_height(c, size, yaw)
	(layers[id] as ScatterLayer).add(Vector3(c.x, y, c.y), yaw, 1.0)
	blockers.append({c = c, h = size * 0.5, yaw = yaw})
	var rec := {name = name, kind = kind, layer = id, pos = c, yaw = yaw, y = y}
	if kind in BUILDING_KINDS:
		buildings.append(rec)
		if CHIMNEYS.has(kind):
			var ch: Vector3 = CHIMNEYS[kind]
			var o := rot(Vector2(ch.x, ch.z), yaw)
			smokes.append(Vector3(c.x + o.x, y + ch.y + 0.2, c.y + o.y))
	return rec


## Try a footprint at `c`; if it hits a road/water/blocker, walk it away from
## the nearest road up to `tries` metres. Returns [pos, yaw] or [] on failure.
func resolve(kind: StringName, c: Vector2, face: Callable, tries := 40, road_margin := 0.6) -> Array:
	var size: Vector2 = FOOT[kind]
	var p := c
	for i in tries:
		var yaw: float = face.call(p)
		if footprint_clear(p, size, yaw, road_margin) and footprint_free(p, size, yaw):
			return [p, yaw]
		var q := closest_road_point(p)
		var dir := p - q
		if dir.length() < 0.01:
			dir = Vector2(1, 0.3)
		if HumanRealmLayout.distance_to_road(p) > size.length() * 0.5 + 4.0:
			dir = p - closest_creek_point(p)
		p += dir.normalized() * 1.0
	return []


func _face_road(p: Vector2) -> float:
	return yaw_toward(p, closest_road_point(p))


func _landmark(name: String, rec: Dictionary, markers := {}) -> void:
	var xf := Transform3D(Basis(Vector3.UP, rec.yaw), Vector3(rec.pos.x, rec.y, rec.pos.y))
	landmarks.append({name = name, kind = rec.kind, xf = xf, markers = markers})


func _light(name: String, p: Vector3, rng_m: float, energy: float, col := Color(1.0, 0.68, 0.38)) -> void:
	lights.append({name = name, pos = p, range = rng_m, energy = energy, color = col})


func _local_to_world(rec: Dictionary, l: Vector3) -> Vector3:
	var o := rot(Vector2(l.x, l.z), rec.yaw)
	return Vector3(rec.pos.x + o.x, rec.y + l.y, rec.pos.y + o.y)


# --- landmarks ------------------------------------------------------------------

func _place_landmarks() -> void:
	var L := HumanRealmLayout
	var sq: Vector2 = L.VILLAGE_SQUARE
	var face_road := Callable(self, "_face_road")
	var face_square := func(p: Vector2) -> float: return yaw_toward(p, sq)

	# The mill by the pond: its wheel frozen in the creek just below the pond.
	_place_mill()
	_place_bridge()

	var r := resolve(&"tavern", L.TAVERN, face_road)
	var tav := put_block(&"tavern", &"tavern", r[0], r[1], "Tavern")
	(layers[&"tavern_interior"] as ScatterLayer).add(Vector3(tav.pos.x, tav.y, tav.pos.y), tav.yaw, 1.0)
	_landmark("Tavern", tav, {
		"TavernDoor": Transform3D(Basis.IDENTITY, Vector3(-1.5, 0.3, 4.8)),
		"TavernInterior": Transform3D(Basis.IDENTITY, Vector3(-1.0, 0.45, 0.5)),
		"TavernHearth": Transform3D(Basis.IDENTITY, Vector3(-4.2, 0.45, -0.6)),
		"TavernBar": Transform3D(Basis.IDENTITY, Vector3(3.0, 0.45, -1.2)),
	})
	for wx in [-4.4, 1.2, 3.8]:
		_light("TavernWindow", _local_to_world(tav, Vector3(wx, 2.0, 4.8)), 5.0, 1.2)
	_light("TavernHearthGlow", _local_to_world(tav, Vector3(-4.3, 1.0, -0.6)), 7.0, 2.2, Color(1.0, 0.55, 0.25))
	_light("TavernRoom", _local_to_world(tav, Vector3(1.0, 2.6, 0.0)), 8.0, 1.0)
	_light("TavernSign", _local_to_world(tav, Vector3(-3.3, 3.0, 5.6)), 4.0, 0.6)

	r = resolve(&"meeting_hall", L.MEETING_HALL, face_square)
	var hall := put_block(&"meeting_hall", &"meeting_hall", r[0], r[1], "MeetingHall")
	_landmark("MeetingHall", hall, {
		"PreacherSpot": Transform3D(Basis.IDENTITY, Vector3(0, 1.2, 5.6)),
		"CongregationSpot": Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0.0, 10.0)),
	})

	r = resolve(&"debt_house", L.DEBT_FAMILY_HOUSE, face_road)
	var debt := put_block(&"debt_house", &"debt_house", r[0], r[1], "DebtFamilyHouse")
	_landmark("DebtFamilyHouse", debt, {"DebtHouseDoor": Transform3D(Basis.IDENTITY, Vector3(-1.4, 0.0, 3.2))})

	r = resolve(&"barn_abandoned", L.ABANDONED_BARN, face_road)
	var barn := put_block(&"barn_abandoned", &"barn_abandoned", r[0], r[1], "AbandonedBarn")
	_landmark("AbandonedBarn", barn, {
		"BarnDoorSpot": Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, 6.0)),
		"IsaacMeetSpot": Transform3D(Basis.IDENTITY, Vector3(-3.0, 0.0, 6.5)),
	})
	fogs.append({name = "BarnMist", pos = Vector3(barn.pos.x, barn.y + 1.5, barn.pos.y), size = Vector3(40, 4, 40), density = 0.6})

	r = resolve(&"smithy", Vector2(300.0, 2272.0), face_road)
	var smithy := put_block(&"smithy", &"smithy", r[0], r[1], "Smithy")
	_landmark("Smithy", smithy, {"SmithSpot": Transform3D(Basis.IDENTITY, Vector3(0.6, 0.0, 0.8))})
	_light("ForgeGlow", _local_to_world(smithy, Vector3(-1.6, 1.4, -1.0)), 6.0, 2.0, Color(1.0, 0.45, 0.15))
	# Iron filings at the anvil and forge (village smithy only), charcoal by the heap.
	for l in [Vector2(1.0, 0.6), Vector2(0.0, 0.9), Vector2(-0.6, 0.2), Vector2(1.6, 0.0), Vector2(-2.4, 1.6), Vector2(2.4, 1.8)]:
		var p: Vector2 = smithy.pos + rot(l, smithy.yaw)
		put(&"iron_filings", p, rng.randf() * TAU, 1.0, 0.12)
	for i in 8:
		var p: Vector2 = smithy.pos + rot(Vector2(4.4 + rng.randf_range(-1.6, 1.6), 1.2 + rng.randf_range(1.0, 2.4)), smithy.yaw)
		if ground_ok(p, 0.1):
			put(&"charcoal", p, rng.randf() * TAU, rng.randf_range(0.8, 1.2))

	r = resolve(&"shrine", Vector2(323.0, 2147.0), face_road)
	var shrine := put_block(&"shrine", &"shrine", r[0], r[1], "Shrine")
	_landmark("Shrine", shrine, {"ShrineSpot": Transform3D(Basis.IDENTITY, Vector3(0, 0, 1.5))})
	put(&"shrine_candles", shrine.pos + rot(Vector2(-0.2, 0.75), shrine.yaw), shrine.yaw, 1.0, 0.0)
	for i in 14:
		var a := rng.randf() * TAU
		var p: Vector2 = shrine.pos + Vector2(cos(a), sin(a)) * rng.randf_range(1.4, 4.5)
		if ground_ok(p, 0.2):
			put(&"snowdrops", p, rng.randf() * TAU, rng.randf_range(0.8, 1.2))
	put(&"iron_charm", shrine.pos + rot(Vector2(0.9, 0.9), shrine.yaw), rng.randf() * TAU)


## The ride-north road (ROADS[1]) crosses the creek: a stone bridge, deck at road height.
func _place_bridge() -> void:
	var road: PackedVector2Array = HumanRealmLayout.ROADS[1]
	var c := HumanRealmLayout.CREEK
	for i in road.size() - 1:
		for j in c.size() - 1:
			var hit: Variant = Geometry2D.segment_intersects_segment(road[i], road[i + 1], c[j], c[j + 1])
			if hit == null or not rect.has_point(hit):
				continue
			var p: Vector2 = hit
			var dir := (road[i + 1] - road[i]).normalized()
			var yaw := atan2(dir.x, dir.y)
			var e0 := p - dir * 10.0
			var e1 := p + dir * 10.0
			var y := maxf(WorldHeight.height_at(e0.x, e0.y), WorldHeight.height_at(e1.x, e1.y)) + 0.02
			(layers[&"creek_bridge"] as ScatterLayer).add(Vector3(p.x, y, p.y), yaw, 1.0)
			blockers.append({c = p, h = FOOT[&"bridge"] * 0.5, yaw = yaw})
			landmarks.append({name = "CreekBridge", kind = &"bridge", xf = Transform3D(Basis(Vector3.UP, yaw), Vector3(p.x, y, p.y)), markers = {
				"BridgeMid": Transform3D(Basis.IDENTITY, Vector3(0, 0.4, 0)),
			}})
			for k in 8:
				put(&"icicles", p + rot(Vector2(rng.randf_range(-2.0, 2.0), rng.randf_range(-3.5, 3.5)), yaw), rng.randf() * TAU, 0.9, -0.3)


func _place_mill() -> void:
	var L := HumanRealmLayout
	var a: Vector2 = L.CREEK[L.CREEK.size() - 2]
	var b: Vector2 = L.CREEK[L.CREEK.size() - 1]
	var t := 0.0
	var q := a
	while t < 1.0:
		q = a.lerp(b, t)
		if q.distance_to(L.MILL_POND) > L.MILL_POND_RADIUS + 11.0:
			break
		t += 0.01
	var flow := (b - a).normalized()
	var n := Vector2(-flow.y, flow.x)
	if (L.MILL - q).dot(n) < 0.0:
		n = -n
	# Local -X (the axle side) points from the mill toward the creek.
	var yaw := atan2(-n.y, -n.x)
	var wheel_c := q + n * 1.8
	var mill_c := q + n * 7.6
	while not footprint_clear(mill_c, FOOT[&"mill"], yaw, 0.6, 0.3) and mill_c.distance_to(q) < 20.0:
		mill_c += n * 0.5
	var mill := put_block(&"mill", &"mill", mill_c, yaw, "Mill")
	var wy := WorldHeight.height_at(wheel_c.x, wheel_c.y) - 0.25
	(layers[&"mill_wheel"] as ScatterLayer).add(Vector3(wheel_c.x, wy, wheel_c.y), yaw, 1.0)
	_landmark("Mill", mill, {"MillDoor": Transform3D(Basis.IDENTITY, Vector3(-1.5, 0.0, 4.6))})
	landmarks.append({name = "MillWheel", kind = &"mill_wheel", xf = Transform3D(Basis(Vector3.UP, yaw), Vector3(wheel_c.x, wy, wheel_c.y)), markers = {}})
	fogs.append({name = "MillPondMist", pos = Vector3(L.MILL_POND.x, WorldHeight.height_at(L.MILL_POND.x, L.MILL_POND.y) + 0.8, L.MILL_POND.y), size = Vector3(70, 2.5, 70), density = 0.8})
	for i in 6:
		put(&"icicles", wheel_c + rot(Vector2(rng.randf_range(-0.8, 0.8), rng.randf_range(-2.5, 2.5)), yaw), rng.randf() * TAU, rng.randf_range(0.8, 1.3), -0.2)
	for i in 4:
		var p := mill_c + rot(Vector2(rng.randf_range(-4.6, 4.6), -4.2), yaw)
		if ground_ok(p, 0.0):
			put(&"ice_moss", p, rng.randf() * TAU)


# --- market square --------------------------------------------------------------

func _place_square() -> void:
	var sq := HumanRealmLayout.VILLAGE_SQUARE
	var at := func(deg: float, r: float) -> Vector2: return sq + Vector2(cos(deg_to_rad(deg)), sin(deg_to_rad(deg))) * r

	var wp: Vector2 = at.call(110.0, 7.0)
	var well := put_block(&"well", &"well", wp, 0.4, "VillageWell")
	_landmark("VillageWell", well)
	var tp: Vector2 = wp + Vector2(2.9, 0.4)
	put_block(&"trough", &"trough", tp, 0.4 + PI / 2)
	for i in 4:
		put(&"icicles", tp + Vector2(rng.randf_range(-0.4, 0.4), rng.randf_range(-1.2, 1.2)), rng.randf() * TAU, 0.8)
	landmarks.append({name = "VillageSquare", kind = &"", xf = Transform3D(Basis.IDENTITY, Vector3(sq.x, WorldHeight.height_at(sq.x, sq.y), sq.y)), markers = {
		"SquareCentre": Transform3D.IDENTITY,
	}})

	# Stalls in an arc on the south side, facing the well.
	var stalls := [
		[&"stall_grey", &"goods_iron"], [&"stall_blue", &"goods_salt"], [&"stall_brown", &"goods_pelts"],
		[&"stall_grey", &"goods_grain"], [&"stall_blue", &"goods_furs"], [&"stall_brown", &"goods_grain"],
	]
	for i in stalls.size():
		var p: Vector2 = at.call(64.0 + i * 20.0, 20.0)
		var yaw := yaw_toward(p, sq)
		var rec := put_block(stalls[i][0], &"stall", p, yaw)
		(layers[stalls[i][1]] as ScatterLayer).add(Vector3(p.x, rec.y, p.y), yaw, 1.0)
		# Dried herbs hung from the awning, a dropped coin in the slush.
		put(&"herb_bundles", p + rot(Vector2(rng.randf_range(-1.2, 1.2), -0.9), yaw), rng.randf() * TAU, 1.0, 1.55)
		put(&"dropped_coin", p + rot(Vector2(rng.randf_range(-1.5, 1.5), 1.6 + rng.randf()), yaw), rng.randf() * TAU, 1.0, 0.02)
		for k in 2:
			var cp: Vector2 = p + rot(Vector2((1.0 if k == 0 else -1.0) * rng.randf_range(2.0, 2.6), rng.randf_range(-0.6, 0.4)), yaw)
			if ground_ok(cp, 0.1):
				put_block(&"crate" if (i + k) % 2 == 0 else &"barrel", &"crate" if (i + k) % 2 == 0 else &"barrel", cp, rng.randf() * TAU)
		if stalls[i][1] == &"goods_salt":
			for k in 5:
				var sp: Vector2 = p + rot(Vector2(rng.randf_range(-1.4, 1.4), rng.randf_range(-1.3, -0.6)), yaw)
				put(&"salt_sacks", sp, rng.randf() * TAU, rng.randf_range(0.9, 1.1))
		if stalls[i][1] == &"goods_pelts":
			_landmark("PeltTraderStall", rec, {
				"PeltTraderSpot": Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, -0.3)),
				"PeltCustomerSpot": Transform3D(Basis(Vector3.UP, PI), Vector3(0.0, 0.0, 1.7)),
			})
	# Salt elsewhere: in the tavern's yard and at the smithy (village only).
	for b in buildings:
		if b.kind == &"tavern":
			for k in 3:
				put(&"salt_sacks", b.pos + rot(Vector2(6.8, -2.0 + k * 0.7), b.yaw), rng.randf() * TAU)

	# Pillory and notice board on the north side, lanterns around the edge.
	var pp: Vector2 = at.call(-100.0, 17.0)
	var pil := put_block(&"pillory", &"pillory", pp, yaw_toward(pp, sq))
	_landmark("Pillory", pil)
	var np: Vector2 = at.call(-75.0, 14.0)
	var nb := put_block(&"notice_board", &"notice_board", np, yaw_toward(np, sq))
	_landmark("NoticeBoard", nb, {"ReadSpot": Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0, 1.2))})
	put(&"blessed_pamphlet", np + rot(Vector2(0.6, 0.8), nb.yaw), rng.randf() * TAU)
	var n_lamps := 0
	for deg in range(0, 360, 30):
		var lp: Vector2 = at.call(float(deg) + 8.0, 27.0)
		if ground_ok(lp, 0.5):
			_lantern(lp, yaw_toward(lp, sq))
			n_lamps += 1
	# Pamphlets the Children left on the square and at the hall steps.
	for k in 6:
		var p: Vector2 = at.call(rng.randf_range(0, 360), rng.randf_range(9.0, 26.0))
		if ground_ok(p, 0.1):
			put(&"blessed_pamphlet", p, rng.randf() * TAU)
	for b in buildings:
		if b.kind == &"meeting_hall":
			for k in 4:
				put(&"blessed_pamphlet", b.pos + rot(Vector2(rng.randf_range(-3.0, 3.0), rng.randf_range(6.4, 9.0)), b.yaw), rng.randf() * TAU)
			for k in 10:
				var p: Vector2 = b.pos + rot(Vector2(rng.randf_range(-7.5, 7.5), rng.randf_range(-6.5, -4.8)), b.yaw)
				if ground_ok(p, 0.1):
					put(&"snowdrops", p, rng.randf() * TAU, rng.randf_range(0.8, 1.1))
	# Carts and loose barrels/crates about the square.
	for k in 3:
		var p: Vector2 = at.call(rng.randf_range(0, 360), rng.randf_range(30.0, 38.0))
		var yaw := rng.randf() * TAU
		if footprint_clear(p, FOOT[&"cart"], yaw, 0.3) and footprint_free(p, FOOT[&"cart"], yaw, 0.5):
			put_block(&"cart", &"cart", p, yaw)


## Lantern post at p with a light, facing `yaw`.
func _lantern(p: Vector2, yaw: float) -> void:
	var rec := {pos = p, yaw = yaw + PI / 2, y = WorldHeight.height_at(p.x, p.y)}
	(layers[&"lantern_post"] as ScatterLayer).add(Vector3(p.x, rec.y, p.y), rec.yaw, 1.0)
	blockers.append({c = p, h = Vector2(0.15, 0.15), yaw = 0.0})
	if lights.size() < 18:
		_light("Lantern", _local_to_world(rec, Vector3(0.55, 2.3, 0.0)), 6.0, 0.9)


# --- houses ---------------------------------------------------------------------

func _place_houses() -> void:
	var sq := HumanRealmLayout.VILLAGE_SQUARE
	var cands: Array = []
	for line in HumanRealmLayout.ROADS:
		for i in line.size() - 1:
			var a := line[i]
			var b := line[i + 1]
			var seg := b - a
			var n := Vector2(-seg.y, seg.x).normalized()
			var step := 0.0
			while step < seg.length():
				var base := a + seg.normalized() * step
				for side in [-1.0, 1.0]:
					var c: Vector2 = base + n * side * rng.randf_range(10.0, 13.0)
					if rect.grow(-6.0).has_point(c) and c.distance_to(sq) > 30.0:
						cands.append([c.distance_to(sq) + rng.randf_range(0.0, 60.0), c])
				step += rng.randf_range(17.0, 24.0)
	cands.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0])
	var kinds := [&"house_wattle", &"house_croft", &"house_timber", &"house_long", &"house_wattle", &"house_croft", &"house_timber"]
	var count := 0
	for cand: Array in cands:
		if count >= MAX_HOUSES:
			break
		var c: Vector2 = cand[1]
		var kind: StringName = kinds[rng.randi() % kinds.size()]
		var yaw := _face_road(c) + rng.randf_range(-0.08, 0.08)
		var size: Vector2 = FOOT[kind]
		if not footprint_clear(c, size, yaw, 0.8, HumanRealmLayout.CREEK_BANK) or not footprint_free(c, size, yaw, 3.0):
			continue
		var rec := put_block(kind, kind, c, yaw)
		count += 1
		_dress_house(rec)


func _dress_house(h: Dictionary) -> void:
	var size: Vector2 = FOOT[h.kind]
	var yaw: float = h.yaw
	var back := rot(Vector2(0, -1), yaw)
	# A shed behind, sometimes.
	if rng.randf() < 0.5:
		var sp: Vector2 = h.pos + rot(Vector2(rng.randf_range(-size.x * 0.4, size.x * 0.4), -size.y / 2 - 3.2), yaw)
		if footprint_clear(sp, FOOT[&"shed"], yaw, 0.6) and footprint_free(sp, FOOT[&"shed"], yaw, 0.6):
			put_block(&"shed", &"shed", sp, yaw)
	# Woodpile against a gable end, a barrel by the door.
	var side := 1.0 if rng.randf() < 0.5 else -1.0
	var wp: Vector2 = h.pos + rot(Vector2(side * (size.x / 2 + 1.0), rng.randf_range(-1.0, 1.0)), yaw)
	if footprint_clear(wp, FOOT[&"woodpile"], yaw + PI / 2, 0.4) and footprint_free(wp, FOOT[&"woodpile"], yaw + PI / 2, 0.2):
		put_block(&"woodpile", &"woodpile", wp, yaw + PI / 2)
		if rng.randf() < 0.5:
			put(&"charcoal", wp + rot(Vector2(0, 1.4), yaw), rng.randf() * TAU)
		if rng.randf() < 0.3:
			put(&"cat_curled", wp, rng.randf() * TAU, 1.0, 1.1)
	var bp: Vector2 = h.pos + rot(Vector2(-side * (size.x / 2 - 0.6), size.y / 2 + 0.7), yaw)
	if ground_ok(bp, 0.3):
		put_block(&"barrel", &"barrel", bp, rng.randf() * TAU)
	# Snow piled against the walls, icicle meltwater by the eaves.
	for k in 3:
		var mp: Vector2 = h.pos + rot(Vector2(rng.randf_range(-size.x / 2, size.x / 2), (size.y / 2 + 0.6) * (1.0 if k == 0 else -1.0)), yaw)
		if ground_ok(mp, 0.0):
			put(&"snow_mounds", mp, rng.randf() * TAU, rng.randf_range(0.6, 1.1))
	var ip: Vector2 = h.pos + rot(Vector2(rng.randf_range(-size.x / 2, size.x / 2), size.y / 2 + 0.8), yaw)
	if ground_ok(ip, 0.0):
		put(&"icicles", ip, rng.randf() * TAU, rng.randf_range(0.7, 1.0))
	if rng.randf() < 0.22:
		var cp: Vector2 = h.pos + rot(Vector2(side * -(size.x / 2 + 2.2), size.y / 2 + 1.5), yaw)
		if footprint_clear(cp, FOOT[&"cart"], yaw + PI / 2, 0.4) and footprint_free(cp, FOOT[&"cart"], yaw + PI / 2, 0.3):
			put_block(&"cart", &"cart", cp, yaw + PI / 2)
	if rng.randf() < 0.35:
		put(&"iron_charm", h.pos + rot(Vector2(rng.randf_range(-1.5, 1.5), size.y / 2 + 1.2), yaw), rng.randf() * TAU)
	# The garden behind: wattle hurdles, dye plants, a coop, a washing line.
	var gc: Vector2 = h.pos + back * (size.y / 2 + 7.0)
	var gw := maxf(size.x + 2.0, 8.0)
	var gd := 7.5
	if not footprint_clear(gc, Vector2(gw, gd), yaw, 0.6) or not footprint_free(gc, Vector2(gw, gd), yaw, 0.5):
		return
	var n_x := int(gw / 2.5)
	var n_z := int(gd / 2.5)
	for i in n_x:
		var l := Vector2(-gw / 2 + 1.25 + i * 2.5, -gd / 2)
		_fence(&"fence_wattle", gc + rot(l, yaw), yaw)
	for sx in [-1.0, 1.0]:
		for j in n_z:
			var l := Vector2(sx * gw / 2, -gd / 2 + 1.25 + j * 2.5)
			_fence(&"fence_wattle", gc + rot(l, yaw), yaw + PI / 2)
	for k in rng.randi_range(2, 4):
		put(&"woad" if k % 2 == 0 else &"madder", gc + rot(Vector2(rng.randf_range(-gw / 2 + 1, gw / 2 - 1), rng.randf_range(-gd / 2 + 1, gd / 2 - 1)), yaw), rng.randf() * TAU, rng.randf_range(0.8, 1.2))
	for k in rng.randi_range(1, 3):
		put(&"snowdrops", gc + rot(Vector2(rng.randf_range(-gw / 2 + 1, gw / 2 - 1), rng.randf_range(-gd / 2 + 0.6, -gd / 2 + 1.4)), yaw), rng.randf() * TAU)
	if rng.randf() < 0.4:
		put(&"holly", gc + rot(Vector2(gw / 2 - 1.0, -gd / 2 + 1.0), yaw), rng.randf() * TAU, rng.randf_range(0.8, 1.1))
	if rng.randf() < 0.35:
		var cp := gc + rot(Vector2(-gw / 2 + 1.6, -gd / 2 + 1.4), yaw)
		put_block(&"chicken_coop", &"chicken_coop", cp, yaw)
		for k in 3:
			put(&"hawk_feathers" if k == 0 else &"crow_feathers", cp + Vector2(rng.randf_range(-2, 2), rng.randf_range(-2, 2)), rng.randf() * TAU)
	elif rng.randf() < 0.5:
		var lp := gc + rot(Vector2(0, 0.5), yaw)
		(layers[&"washing_line"] as ScatterLayer).add(Vector3(lp.x, WorldHeight.height_at(lp.x, lp.y), lp.y), yaw, 1.0)
		if rng.randf() < 0.6:
			put(&"frozen_ribbon", lp + rot(Vector2(rng.randf_range(-2.5, 2.5), 0.8), yaw), rng.randf() * TAU)
	if rng.randf() < 0.35:
		var sp: Vector2 = h.pos + rot(Vector2(side * -(size.x / 2 + 3.0), size.y / 2 + 3.5), yaw)
		if ground_ok(sp, 0.6):
			put(&"snowman", sp, rng.randf() * TAU, rng.randf_range(0.85, 1.1))
			put(&"carved_toy", sp + Vector2(rng.randf_range(-1.5, 1.5), rng.randf_range(-1.5, 1.5)), rng.randf() * TAU)
	if rng.randf() < 0.5:
		put(&"robin_on_post", gc + rot(Vector2(-gw / 2, -gd / 2), yaw), rng.randf() * TAU, 1.0, 1.25)
	blockers.append({c = gc, h = Vector2(gw, gd) * 0.5, yaw = yaw})
	_gardens.append(Rect2(gc - Vector2(gw, gd) * 0.5, Vector2(gw, gd)))


func _fence(id: StringName, p: Vector2, yaw: float) -> void:
	if HumanRealmLayout.distance_to_road(p) < HumanRealmLayout.ROAD_HALF_WIDTH + 1.6 or in_water(p, 1.0):
		return
	(layers[id] as ScatterLayer).add(Vector3(p.x, WorldHeight.height_at(p.x, p.y) - 0.05, p.y), yaw, 1.0)


# --- the fence line toward the forest, fields and hedgerows ------------------------

func _place_fence_line() -> void:
	var z := rect.position.y + 6.0
	var x := rect.position.x + 3.0
	while x < rect.end.x - 3.0:
		var p := Vector2(x, z + sin(x * 0.05) * 1.5)
		if ground_ok(p, 1.4):
			_fence(&"fence_rail", p, 0.0)
			var r := rng.randf()
			if r < 0.07:
				put(&"crow_perched", p + Vector2(1.5, 0), rng.randf() * TAU, 1.0, 1.3)
			elif r < 0.10:
				put(&"robin_on_post", p + Vector2(-1.5, 0), rng.randf() * TAU, 1.0, 1.3)
			elif r < 0.22:
				put(&"crow_feathers", p + Vector2(rng.randf_range(-1.5, 1.5), rng.randf_range(1.0, 3.0)), rng.randf() * TAU)
		x += 3.0
	# Birch and juniper on the rough strip by the fence, toward the forest.
	for i in 40:
		var p := Vector2(rng.randf_range(rect.position.x + 4, rect.end.x - 4), rng.randf_range(z + 4.0, z + 30.0))
		if ground_ok(p, 2.0):
			if i % 3 == 0:
				put(&"tree_birch", p, rng.randf() * TAU, rng.randf_range(0.8, 1.15))
				blockers.append({c = p, h = Vector2(0.6, 0.6), yaw = 0.0})
			else:
				put(&"juniper", p, rng.randf() * TAU, rng.randf_range(0.7, 1.2))


func _outskirts(p: Vector2) -> bool:
	return p.distance_to(HumanRealmLayout.VILLAGE_SQUARE) > CORE_RADIUS and p.y > rect.position.y + 36.0


func _place_fields() -> void:
	var xs: Array[float] = []
	var zs: Array[float] = []
	var x := rect.position.x + 15.0
	while x < rect.end.x:
		xs.append(x)
		x += rng.randf_range(70.0, 95.0)
	var z := rect.position.y + 45.0
	while z < rect.end.y:
		zs.append(z)
		z += rng.randf_range(60.0, 80.0)
	# Edges of the field grid: hedge, stone wall, or open.
	for i in xs.size():
		for j in zs.size() - 1:
			_field_edge(Vector2(xs[i], zs[j]), Vector2(xs[i], zs[j + 1]))
	for j in zs.size():
		for i in xs.size() - 1:
			_field_edge(Vector2(xs[i], zs[j]), Vector2(xs[i + 1], zs[j]))
	# Field interiors.
	for i in xs.size() - 1:
		for j in zs.size() - 1:
			_field_interior(Rect2(xs[i], zs[j], xs[i + 1] - xs[i], zs[j + 1] - zs[j]))


func _field_edge(a: Vector2, b: Vector2) -> void:
	var r := rng.randf()
	var kind := "hedge" if r < 0.6 else ("wall" if r < 0.85 else "open")
	var seg := b - a
	var dir := seg.normalized()
	var n := Vector2(-dir.y, dir.x)
	var yaw := atan2(dir.x, dir.y) + PI / 2
	var t := 0.0
	var oak_at := rng.randf_range(10.0, seg.length() - 10.0) if rng.randf() < 0.6 else -1.0
	while t < seg.length():
		var p := a + dir * t + n * sin(t * 0.07 + a.x) * 1.2
		if _outskirts(p) and ground_ok(p, 1.2):
			if kind == "hedge":
				_hedge_plant(p, n)
				if oak_at >= 0.0 and absf(t - oak_at) < 1.2:
					_oak(p + n * 0.5)
			elif kind == "wall":
				put(&"stone_wall", p, yaw, 1.0)
				var q := rng.randf()
				if q < 0.12:
					put(&"snail_shells", p + n * 0.8, rng.randf() * TAU)
				elif q < 0.27:
					put(&"ice_moss", p + n * -0.7, rng.randf() * TAU)
				elif q < 0.31:
					put(&"chalk", p + n * 1.0, rng.randf() * TAU)
		t += 2.9 if kind == "wall" else rng.randf_range(1.8, 2.6)


func _hedge_plant(p: Vector2, n: Vector2) -> void:
	var r := rng.randf()
	var id: StringName
	if r < 0.26: id = &"hedge_hawthorn"
	elif r < 0.46: id = &"hedge_blackthorn"
	elif r < 0.61: id = &"hedge_rose"
	elif r < 0.71: id = &"hedge_hazel"
	elif r < 0.79: id = &"holly"
	elif r < 0.89: id = &"bramble"
	else: id = &"dead_bracken"
	put(id, p, rng.randf() * TAU, rng.randf_range(0.8, 1.25))
	var q := rng.randf()
	var side := 1.0 if rng.randf() < 0.5 else -1.0
	if q < 0.10:
		put(&"wintergreen", p + n * side * rng.randf_range(1.0, 1.8), rng.randf() * TAU)
	elif q < 0.15:
		put(&"old_mans_beard", p, rng.randf() * TAU, 1.0, rng.randf_range(0.6, 1.4))
	elif q < 0.18 and id == &"hedge_hazel":
		put(&"crow_feathers", p + n * side * 1.5, rng.randf() * TAU)


func _oak(p: Vector2) -> void:
	put(&"tree_oak", p, rng.randf() * TAU, rng.randf_range(0.85, 1.2))
	blockers.append({c = p, h = Vector2(0.8, 0.8), yaw = 0.0})
	for k in 3:
		var q := p + Vector2(rng.randf_range(-4, 4), rng.randf_range(-4, 4))
		if ground_ok(q, 0.3):
			put(&"acorns", q, rng.randf() * TAU)
	var g := p + Vector2(rng.randf_range(-3, 3), rng.randf_range(-3, 3))
	if ground_ok(g, 0.3):
		put(&"oak_galls", g, rng.randf() * TAU)
	if rng.randf() < 0.6:
		var m := p + Vector2(rng.randf_range(-3, 3), rng.randf_range(-3, 3))
		if ground_ok(m, 0.3):
			put(&"mistletoe", m, rng.randf() * TAU)


func _field_interior(cell: Rect2) -> void:
	var c := cell.get_center()
	if not _outskirts(c):
		return
	var rnd := func() -> Vector2: return Vector2(rng.randf_range(cell.position.x + 4, cell.end.x - 4), rng.randf_range(cell.position.y + 4, cell.end.y - 4))
	if rng.randf() < 0.45:
		var hp: Vector2 = rnd.call()
		if footprint_clear(hp, FOOT[&"haystack"], 0.0, 1.0) and footprint_free(hp, FOOT[&"haystack"], 0.0, 1.0):
			put_block(&"haystack", &"haystack", hp, rng.randf() * TAU)
			if rng.randf() < 0.5:
				put(&"crow_perched", hp, rng.randf() * TAU, 1.0, 3.3)
	for k in 14:
		var p: Vector2 = rnd.call()
		if ground_ok(p, 0.5):
			put(&"grass_tufts", p, rng.randf() * TAU, rng.randf_range(0.7, 1.3))
	for k in 3:
		var p: Vector2 = rnd.call()
		if ground_ok(p, 0.5):
			put(&"snow_mounds", p, rng.randf() * TAU, rng.randf_range(0.8, 1.6))
	var finds := [[&"flint", 2], [&"crow_feathers", 1], [&"fox_tracks", 1]]
	for f: Array in finds:
		for k in f[1]:
			var p: Vector2 = rnd.call()
			if ground_ok(p, 0.5) and rng.randf() < 0.8:
				put(f[0], p, rng.randf() * TAU)
	if rng.randf() < 0.3:
		var p: Vector2 = rnd.call()
		if ground_ok(p, 0.5):
			put(&"hawk_feathers", p, rng.randf() * TAU)
	if rng.randf() < 0.5:
		var p: Vector2 = rnd.call()
		if ground_ok(p, 1.0):
			put(&"stumps", p, rng.randf() * TAU, rng.randf_range(0.8, 1.2))
			put(&"tinder_fungus", p, rng.randf() * TAU, 1.0, 0.35)
	if rng.randf() < 0.3:
		var p: Vector2 = rnd.call()
		if ground_ok(p, 1.5):
			put(&"boulders", p, rng.randf() * TAU, rng.randf_range(0.6, 1.0))
			put(&"ice_moss", p + Vector2(1.2, 0.3), rng.randf() * TAU)


# --- the frozen creek and the mill pond ----------------------------------------------

func _place_creek() -> void:
	var L := HumanRealmLayout
	var c := L.CREEK
	for i in c.size() - 1:
		var a := c[i]
		var b := c[i + 1]
		var seg := b - a
		var dir := seg.normalized()
		var n := Vector2(-dir.y, dir.x)
		var t := 0.0
		while t < seg.length():
			var base := a + dir * t
			if rect.grow(-1.0).has_point(base):
				for side in [-1.0, 1.0]:
					var bank: Vector2 = base + n * side * rng.randf_range(L.CREEK_HALF_WIDTH + 0.3, L.CREEK_HALF_WIDTH + 2.2)
					if rng.randf() < 0.7 and ground_ok(bank, 0.3, true) and not in_water(bank, 0.2):
						put(&"frozen_reeds", bank, rng.randf() * TAU, rng.randf_range(0.8, 1.3), -0.05)
					if rng.randf() < 0.12 and ground_ok(bank, 0.3, true) and not in_water(bank, 0.2):
						put(&"clay", bank + n * side * 0.6, rng.randf() * TAU)
					if rng.randf() < 0.18:
						var wp: Vector2 = base + n * side * (L.CREEK_HALF_WIDTH + L.CREEK_BANK + 1.0)
						if ground_ok(wp, 1.5):
							put(&"tree_willow", wp, rng.randf() * TAU, rng.randf_range(0.85, 1.15))
							blockers.append({c = wp, h = Vector2(0.7, 0.7), yaw = 0.0})
					if rng.randf() < 0.05:
						var tp: Vector2 = base + n * side * (L.CREEK_HALF_WIDTH + 4.0)
						if ground_ok(tp, 0.5):
							put(&"fox_tracks", tp, atan2(dir.x, dir.y) + PI / 2)
			t += rng.randf_range(3.5, 6.0)
	# Reeds and clay ringing the pond.
	for k in 70:
		var a := k / 70.0 * TAU
		var p := L.MILL_POND + Vector2(cos(a), sin(a)) * (L.MILL_POND_RADIUS + rng.randf_range(0.4, 3.0))
		if ground_ok(p, 0.1, true) and not in_water(p, 0.2):
			put(&"frozen_reeds" if k % 5 != 0 else &"clay", p, rng.randf() * TAU, rng.randf_range(0.8, 1.3))


# --- the village's lanes, the barn's waste ground, loose finds ------------------------

func _place_village_finds() -> void:
	var sq := HumanRealmLayout.VILLAGE_SQUARE
	# The barn: overrun with brambles, an owl lives in it, a fox comes by.
	for b in buildings:
		if b.kind != &"barn_abandoned":
			continue
		for k in 26:
			var p: Vector2 = b.pos + rot(Vector2(rng.randf_range(-11, 11), rng.randf_range(-9, 9)), b.yaw)
			if ground_ok(p, 0.4):
				put(&"bramble" if k % 3 != 2 else &"dead_bracken", p, rng.randf() * TAU, rng.randf_range(0.8, 1.3))
		for k in 5:
			var p: Vector2 = b.pos + rot(Vector2(rng.randf_range(-7, 7), rng.randf_range(4.9, 7.5)), b.yaw)
			if ground_ok(p, 0.1):
				put(&"owl_feathers", p, rng.randf() * TAU)
		for k in 3:
			var p: Vector2 = b.pos + rot(Vector2(rng.randf_range(-8, 8), rng.randf_range(-8, -5.2)), b.yaw)
			if ground_ok(p, 0.6):
				put(&"stumps", p, rng.randf() * TAU)
				put(&"tinder_fungus", p, rng.randf() * TAU, 1.0, 0.35)
		put(&"fox_tracks", b.pos + rot(Vector2(-6, 6.5), b.yaw), b.yaw + 0.4)
		put(&"crow_perched", b.pos + rot(Vector2(-4.0, 0.0), b.yaw), rng.randf() * TAU, 1.0, 9.0)
		put(&"frozen_ribbon", b.pos + rot(Vector2(-2.5, 5.4), b.yaw), rng.randf() * TAU)
		put(&"tree_snag", b.pos + rot(Vector2(10.5, 3.0), b.yaw), rng.randf() * TAU, 1.1)
		put(&"fallen_logs", b.pos + rot(Vector2(-10.0, -2.0), b.yaw), rng.randf() * TAU)
	# Lane edges in the core: buttons, coins, pamphlets, ribbons, cats, crows, tufts.
	var core_finds := [[&"lost_button", 10], [&"dropped_coin", 6], [&"blessed_pamphlet", 6], [&"frozen_ribbon", 4],
		[&"cat_curled", 4], [&"crow_perched", 4], [&"snowman", 3], [&"carved_toy", 3], [&"iron_charm", 4]]
	for f: Array in core_finds:
		var placed := 0
		var tries := 0
		while placed < f[1] and tries < 200:
			tries += 1
			var p := sq + Vector2(rng.randf_range(-CORE_RADIUS, CORE_RADIUS), rng.randf_range(-CORE_RADIUS, CORE_RADIUS))
			var d := HumanRealmLayout.distance_to_road(p)
			if d > HumanRealmLayout.ROAD_HALF_WIDTH + 0.6 and d < HumanRealmLayout.ROAD_HALF_WIDTH + 5.0 and ground_ok(p, 0.3):
				put(f[0], p, rng.randf() * TAU, 1.0, 0.02)
				placed += 1
	for k in 160:
		var p := sq + Vector2(rng.randf_range(-CORE_RADIUS, CORE_RADIUS), rng.randf_range(-CORE_RADIUS, CORE_RADIUS))
		if p.distance_to(sq) > 34.0 and ground_ok(p, 0.6):
			put(&"grass_tufts" if k % 4 != 0 else &"snow_mounds", p, rng.randf() * TAU, rng.randf_range(0.6, 1.1))
	for k in 20:
		var p := sq + Vector2(rng.randf_range(-CORE_RADIUS, CORE_RADIUS), rng.randf_range(-CORE_RADIUS, CORE_RADIUS))
		if p.distance_to(sq) > 40.0 and ground_ok(p, 1.0):
			put(&"bramble" if k % 2 == 0 else &"wintergreen", p, rng.randf() * TAU, rng.randf_range(0.7, 1.1))


## Every 100 m cell of the rect gets at least one forage/collectible/look find.
func _fill_empty_cells() -> void:
	var fill := [&"wintergreen", &"flint", &"crow_feathers", &"snail_shells"]
	var cols := ceili(rect.size.x / ScatterReport.CELL)
	var rows := ceili(rect.size.y / ScatterReport.CELL)
	for cx in cols:
		for cz in rows:
			var cell := Rect2(rect.position + Vector2(cx, cz) * ScatterReport.CELL, Vector2.ONE * ScatterReport.CELL).intersection(rect)
			var have := 0
			for l: ScatterLayer in layer_list():
				if not (l.is_forage() or l.tags.has("collectible") or l.tags.has("look") or l.tags.has("landmark")):
					continue
				for i in l.count():
					var p := l.position_of(i)
					if cell.has_point(Vector2(p.x, p.z)):
						have += 1
			var want := 3 - have
			var tries := 0
			while want > 0 and tries < 300:
				tries += 1
				var p := Vector2(rng.randf_range(cell.position.x, cell.end.x), rng.randf_range(cell.position.y, cell.end.y))
				if ground_ok(p, 0.5):
					put(fill[(cx + cz + want) % fill.size()], p, rng.randf() * TAU)
					want -= 1


# --- report ---------------------------------------------------------------------

## Honest draw-call estimate: the worst viewpoint (20 m grid over the rect) of
## MultiMesh chunk draws within each layer's draw distance (doubled for shadow
## casters), far impostor chunks, and smoke emitters.
func estimate_draw_calls() -> int:
	var chunks := {}  # layer id -> {Vector2i: true}
	for id: StringName in layers:
		var l: ScatterLayer = layers[id]
		var set := {}
		for i in l.count():
			var p := l.position_of(i)
			set[Vector2i(floori(p.x / CHUNK), floori(p.z / CHUNK))] = true
		chunks[id] = set
	var worst := 0
	var x := rect.position.x
	while x <= rect.end.x:
		var z := rect.position.y
		while z <= rect.end.y:
			var v := Vector2(x, z)
			var n := 0
			for id: StringName in layers:
				var l: ScatterLayer = layers[id]
				for k: Vector2i in chunks[id]:
					var cr := Rect2(Vector2(k) * CHUNK, Vector2.ONE * CHUNK)
					var d := v.distance_to(v.clamp(cr.position, cr.end))
					if d <= l.draw_distance:
						n += 2 if l.cast_shadow else 1
					elif l.impostor_path != "" and d <= l.impostor_distance:
						n += 1
			for s in smokes:
				if v.distance_to(Vector2(s.x, s.z)) < 300.0:
					n += 1
			worst = maxi(worst, n)
			z += 20.0
		x += 20.0
	return worst


func landmark_count() -> int:
	return landmarks.size()


func report() -> Dictionary:
	return ScatterReport.compute(layer_list(), rect, landmark_count(), estimate_draw_calls())
