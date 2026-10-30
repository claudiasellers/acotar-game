## Height provider and biome map for the Suriel's glade in the western woods
## (Keeper, ch. 13-15): young birch trees near running water (the Thornwater),
## where Feyre sets a double-loop snare baited with a chicken and waits in a
## tree; the naga come out of the reeds downstream.
##
## World contract provider (docs/contracts/world.md §2).
class_name SurielGladeTerrain
extends RefCounted

const BOUNDS := Rect2(-950.0, 450.0, 250.0, 350.0)

## The snare site: an open patch of birch glade 25 m west of the water.
const SNARE_SITE := Vector2(-815.0, 610.0)
## The waiting tree: a sturdy, dense oak within 12 m of the snare (book text).
const WAITING_OAK := Vector2(-823.0, 602.0)
## The naga's backwater: a reed-choked oxbow downstream on the west bank.
const NAGA_BACKWATER := Vector3(-790.0, 735.0, 42.0)

static var _features: WoodsFeatures
static var _detail: FastNoiseLite


static func features() -> WoodsFeatures:
	if _features == null:
		_features = WoodsFeatures.new([
			# A deer track down the west bank, the way Feyre comes in.
			{"kind": &"path", "width": 1.4, "points": WoodsFeatures.meander(PackedVector2Array([
				Vector2(-940, 470), Vector2(-880, 540), Vector2(-835, 600), Vector2(-820, 680), Vector2(-760, 790)]), 5.0, 3.0, 41)},
		], 30.0)
		_detail = WoodsTerrain.make_noise(4101, 0.012, 3)
	return _features


static func river_distance(x: float, z: float) -> float:
	return MacroHeight.distance_to_river(x, z) - MacroHeight.RIVER_HALF_WIDTH


static func height_at(x: float, z: float) -> float:
	var f := features()
	var base := MacroHeight.height_at(x, z)
	var keep := smoothstep(MacroHeight.RIVER_HALF_WIDTH, MacroHeight.RIVER_HALF_WIDTH + MacroHeight.RIVER_BANK, MacroHeight.distance_to_river(x, z))
	var h := _detail.get_noise_2d(x, z) * 2.5
	# The glade is a gentle flat by the water so the snare reads clearly.
	h *= 0.4 + 0.6 * smoothstep(15.0, 45.0, Vector2(x, z).distance_to(SNARE_SITE))
	h += WoodsTerrain.hollow(x, z, Vector2(NAGA_BACKWATER.x, NAGA_BACKWATER.y), NAGA_BACKWATER.z * 1.3, 3.5)
	h *= 1.0 - WoodsTerrain.path_weight(f.distance(&"path", x, z), 2.0) * 0.3
	return base + h * keep


static func texture_at(x: float, z: float) -> Vector3i:
	if river_distance(x, z) < 0.0:
		return Vector3i(WorldHeight.Tex.RIVERBED, WorldHeight.Tex.RIVERBED, 0)
	if features().distance(&"path", x, z) < 0.0:
		return Vector3i(WorldHeight.Tex.PATH, WorldHeight.Tex.SPRING_GRASS, 60)
	match biome_at(x, z):
		&"naga_reeds":
			return Vector3i(WorldHeight.Tex.RIVERBED, WorldHeight.Tex.MOSS, 140)
		&"thornwater_banks":
			return Vector3i(WorldHeight.Tex.MOSS, WorldHeight.Tex.RIVERBED, 60)
	return Vector3i(WorldHeight.Tex.SPRING_GRASS, WorldHeight.Tex.MOSS, 70)


static func biome_at(x: float, z: float) -> StringName:
	var p := Vector2(x, z)
	if p.distance_to(Vector2(NAGA_BACKWATER.x, NAGA_BACKWATER.y)) < NAGA_BACKWATER.z * 1.4:
		return &"naga_reeds"
	if river_distance(x, z) < 14.0:
		return &"thornwater_banks"
	if p.distance_to(SNARE_SITE) < 40.0:
		return &"snare_glade"
	return &"young_birches"


static func dread_at(x: float, z: float) -> float:
	var d := Vector2(x, z).distance_to(Vector2(NAGA_BACKWATER.x, NAGA_BACKWATER.y))
	return 1.0 - smoothstep(NAGA_BACKWATER.z, NAGA_BACKWATER.z + 70.0, d)


static func clearance(x: float, z: float) -> float:
	var d := minf(features().distance(&"path", x, z), river_distance(x, z))
	# Story contract: 12 m walkable around the anchor; room for four naga.
	if Vector2(x, z).distance_to(SNARE_SITE) < 16.0:
		d = 0.0
	return clampf(d / 3.0, 0.0, 1.0)


static func is_water(x: float, z: float) -> bool:
	return river_distance(x, z) < 0.0 or Vector2(x, z).distance_to(Vector2(NAGA_BACKWATER.x, NAGA_BACKWATER.y)) < NAGA_BACKWATER.z * 0.6
