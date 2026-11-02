## Ground paint that follows the trees (lane L32): a woods biome used to paint
## all of its ground forest floor, so the open meadow LandscapeLayout leaves
## between groves read as bare brown dirt from a distance. Here the floor
## paint fades with the same stand map the trees are placed from: leaf litter
## under the groves, grass (or moss) out in the open, feathered through the
## edge band, and none where the trees are kept out (view cones, clearing
## floors, path verges). Pure and deterministic; safe from the terrain
## baker's threads.
## Loaded by path (no class_name), like LandscapeLayout.
extends RefCounted

const LandscapeLayout := preload("res://world/spring_court/shared/landscape_layout.gd")
const DEF := "res://data/regions/spring_court/%s_biomes.tres"
## Overlay blend (0-255) out in the open: the overlay all but covers the floor.
const OPEN_BLEND := 235.0

static var _lock := Mutex.new()
## region id -> {layout, open: {biome id: open share}}
static var _cache := {}


## How far inside a grove (x, z) is, 0 open .. 1 under canopy, for `biome`
## of woods region `region` (its WoodsRegionDef's seed and tree density).
static func grove(region: String, biome: StringName, x: float, z: float) -> float:
	var c := _region(region)
	if c.is_empty() or not (c["open"] as Dictionary).has(biome):
		return 1.0
	var def: WoodsRegionDef = c["def"]
	# Where WoodsScatter keeps trees out, the litter goes too: the view cones
	# (the wall-crossing reveal), clearing floors and path verges.
	if WoodsComposition.in_vista(def, x, z):
		return 0.0
	var u := LandscapeLayout.stand_at(c["layout"], x, z)
	var g: float = LandscapeLayout.zone(u, c["open"][biome])["grove"]
	var glade := WoodsComposition.clearing_at(def, x, z, 1.4)
	if not glade.is_empty():
		g *= LandscapeLayout.clearing_factor(Vector2(x, z).distance_to(glade["center"]), float(glade["radius"]))
	return g * LandscapeLayout.path_factor(WoodsComposition.path_distance(def, x, z))


## The biome's own paint (floor base, `overlay`, `floor_blend`) under the
## canopy, the overlay almost alone in the open.
static func paint(region: String, biome: StringName, x: float, z: float, floor_tex: int, overlay: int,
		floor_blend: int) -> Vector3i:
	var g := grove(region, biome, x, z)
	return Vector3i(floor_tex, overlay, int(roundf(lerpf(OPEN_BLEND, float(floor_blend), g))))


static func _region(region: String) -> Dictionary:
	_lock.lock()
	var c: Variant = _cache.get(region)
	if c == null:
		c = {}
		var def := load(DEF % region) as WoodsRegionDef
		if def != null:
			var open := {}
			for b in def.biomes:
				# Same open share WoodsScatter places the trees with.
				open[b.id] = 0.05 if WoodsComposition.is_horror(b) else LandscapeLayout.open_share(b.tree_density)
			c = {"layout": LandscapeLayout.make(def.seed, def.provider.BOUNDS), "open": open, "def": def}
		_cache[region] = c
	_lock.unlock()
	return c
