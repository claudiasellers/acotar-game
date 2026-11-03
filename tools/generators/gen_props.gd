## Places the loose physics props (T5) in the village and the manor grounds:
## a handful of anchor zones per region, a few small clusters per zone
## (a woodpile, a stack of crates by a door, pots by the glass houses), each
## spot checked against the region's own keep-outs. Deterministic (fixed seed).
##   tools/mq/godot.sh -s tools/generators/gen_props.gd
## Writes data/props/placements/<region_id>.tres and prints a count per kind.
extends SceneTree

const SEED := 59

## Village (human realm, world coords): zones around the square and lanes.
## [centre x, centre z, radius, clusters, kinds]
const VILLAGE_ZONES := [
	[380.0, 2250.0, 34.0, 2, [&"crate_village", &"barrel", &"pot_clay", &"bucket"]],
	[300.0, 2272.0, 16.0, 1, [&"firewood_log", &"bucket", &"crate_village"]],  # by the smithy
	[420.0, 2215.0, 30.0, 1, [&"crate_village", &"barrel", &"firewood_log"]],
	[345.0, 2300.0, 30.0, 1, [&"pot_clay", &"bucket", &"firewood_log"]],
]
## Manor grounds (site_plan coords are world coords): service and garden yards.
const MANOR_ZONES := [
	[82.0, -45.0, 8.0, 1, [&"firewood_log", &"bucket", &"crate"]],      # kitchen yard
	[-130.0, 7.0, 18.0, 1, [&"crate", &"bucket", &"firewood_log"]],     # before the stables
	[140.0, -90.0, 22.0, 2, [&"pot_glazed", &"pot_glazed", &"bucket"]], # glass-house fronts
	[-242.0, 150.0, 40.0, 1, [&"crate", &"bucket", &"pot_glazed"]],     # walled orchard
	[0.0, -96.0, 30.0, 1, [&"pot_glazed", &"pot_glazed"]],              # rose-garden steps
]
const PER_CLUSTER := Vector2i(3, 4)
const CLUSTER_RADIUS := 1.8
const SPACING := 0.95

var _rng := RandomNumberGenerator.new()


func _initialize() -> void:
	_rng.seed = SEED
	var village := VillagePlan.new()
	village.generate()
	var village_ok := func(p: Vector2) -> bool:
		return village.ground_ok(p, 0.8) and village.footprint_free(p, Vector2(1.0, 1.0), 0.0, 0.6)
	var manor_ok := func(p: Vector2) -> bool:
		return not ManorSitePlan.is_kept_out(p.x, p.y) and not ManorSitePlan.is_on_path(p.x, p.y) \
				and not ManorSitePlan.STABLES.grow(1.0).has_point(p)
	var total := 0
	total += _write(&"village", VILLAGE_ZONES, village_ok)
	total += _write(&"manor_estate", MANOR_ZONES, manor_ok)
	print("gen_props: %d props" % total)
	quit(0 if total >= 30 and total <= 50 else 1)


func _write(region: StringName, zones: Array, ok: Callable) -> int:
	var placements := PropPlacements.new()
	placements.region_id = region
	var by_id := {}
	var taken: Array[Vector2] = []
	for z: Array in zones:
		var centre := Vector2(z[0], z[1])
		for c in int(z[3]):
			var anchor := _free_spot(centre, float(z[2]), ok, taken, 40)
			if anchor.x == INF:
				continue
			var n := _rng.randi_range(PER_CLUSTER.x, PER_CLUSTER.y)
			var kinds: Array = z[4]
			for k in n:
				var p := anchor if k == 0 else _free_spot(anchor, CLUSTER_RADIUS, ok, taken, 12)
				if p.x == INF:
					continue
				taken.append(p)
				var id: StringName = kinds[(c + k) % kinds.size()]
				if not by_id.has(id):
					var layer := ScatterLayer.new()
					layer.id = id
					layer.tags = PackedStringArray(["prop"])
					by_id[id] = layer
					placements.layers.append(layer)
				(by_id[id] as ScatterLayer).add(Vector3(p.x, WorldHeight.height_at(p.x, p.y), p.y), _rng.randf() * TAU, 1.0)
	var err := ResourceSaver.save(placements, PropPlacements.DIR % region)
	for layer in placements.layers:
		print("  %s %s: %d" % [region, layer.id, layer.count()])
	return placements.count() if err == OK else 0


func _free_spot(centre: Vector2, radius: float, ok: Callable, taken: Array[Vector2], tries: int) -> Vector2:
	for t in tries:
		var a := _rng.randf() * TAU
		var p := centre + Vector2(cos(a), sin(a)) * radius * sqrt(_rng.randf())
		if not ok.call(p):
			continue
		var clear := true
		for q in taken:
			if q.distance_to(p) < SPACING:
				clear = false
				break
		if clear:
			return p
	return Vector2(INF, INF)
