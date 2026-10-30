## Height provider and biome map for the Border Woods: the first sight of the
## Spring Court, between the Wall (z = +1400) and the manor estate (z = +300).
##
## World contract provider (docs/contracts/world.md §2): static height_at and
## texture_at in world metres, registered in height_providers.tres; the
## HeightProvider fades it back to MacroHeight over the outer 64 m. The
## Thornwater is carved by MacroHeight; this adds banks-aware detail.
class_name BorderWoodsTerrain
extends RefCounted

const BOUNDS := Rect2(-700.0, 300.0, 1200.0, 1100.0)

## Named places (centre, radius). Shared with the region scene and tests.
## Keeper corrections: the Ash Grove is in the human realm, so this hollow
## by the Wall is a crocus knoll instead (ch. 18's picnic glen flavour).
const CROCUS_KNOLL := Vector3(-470.0, 1240.0, 75.0)
## Canon rainbow falls (ch. 23) spill off a rock lip into the faelight hollow.
const FALLS_LIP := Vector2(210.0, 668.0)
const FALLS_BLUFF := Vector3(210.0, 638.0, 42.0)
## The willow glen (ch. 23): a great weeping willow over a clear stretch of
## the Thornwater, where the glamour lifts.
const WILLOW_GLEN := Vector2(-345.0, 1010.0)
const FAELIGHT_HOLLOW := Vector3(210.0, 720.0, 95.0)
const BLUEBELL_DELL := Vector3(-300.0, 680.0, 110.0)
const MOONSTONE_RING := Vector3(290.0, 1230.0, 30.0)
const GREAT_OAK := Vector3(-150.0, 1080.0, 40.0)
## The wall-crossing release (experience-bar §1.2): the world lane's frame
## marker wall_crossing_frame looks from here to the Great Oak.
const WALL_FRAME := Vector2(-100, 1362)
## View cones kept clear of trees and shrubs: [from, to, half angle deg, length m].
const VISTAS := [[Vector2(-100, 1362), Vector2(-150, 1080), 20.0, 300.0]]
const WALL_GAP := Vector2(-100.0, 1400.0)
## Story contract anchor bogge_hunt_path (ch. 9-10): on the root path through
## the ancient oaks, looking west down a long clear sightline.
const BOGGE_HUNT := Vector2(-420.0, 1000.0)
const BOGGE_HUNT_LOOK := Vector2(-560.0, 900.0)

static var _features: WoodsFeatures
static var _detail: FastNoiseLite
static var _biome_a: FastNoiseLite
static var _biome_b: FastNoiseLite


static func features() -> WoodsFeatures:
	if _features == null:
		_features = WoodsFeatures.new([
			# The woods road: from the Wall gap Feyre is brought through, north to
			# the manor avenue at (0, 300).
			{"kind": &"road", "width": 5.0, "points": WoodsFeatures.meander(PackedVector2Array([
				WALL_GAP, Vector2(-90, 1300), Vector2(-40, 1180), Vector2(-70, 1040), Vector2(-10, 900),
				Vector2(40, 760), Vector2(10, 600), Vector2(-20, 450), Vector2(0, 300)]), 6.0, 4.0, 11)},
			# Sentries' path along the Wall.
			{"kind": &"path", "width": 2.2, "points": WoodsFeatures.meander(PackedVector2Array([
				Vector2(-690, 1350), Vector2(-450, 1335), Vector2(-100, 1345), Vector2(200, 1330), Vector2(490, 1345)]), 6.0, 3.0, 12)},
			# Root paths through the ancient oaks (deer trails, faerie ways).
			{"kind": &"path", "width": 1.6, "points": WoodsFeatures.meander(PackedVector2Array([
				Vector2(-70, 1040), Vector2(-150, 1060), Vector2(-280, 980), Vector2(-420, 1000), Vector2(-560, 900), Vector2(-680, 860)]), 5.0, 4.0, 13)},
			{"kind": &"path", "width": 1.6, "points": WoodsFeatures.meander(PackedVector2Array([
				Vector2(-10, 900), Vector2(-150, 820), Vector2(-300, 680), Vector2(-450, 600), Vector2(-520, 480)]), 5.0, 4.0, 14)},
			{"kind": &"path", "width": 1.6, "points": WoodsFeatures.meander(PackedVector2Array([
				Vector2(40, 760), Vector2(150, 740), Vector2(210, 720), Vector2(330, 840), Vector2(300, 1000), Vector2(290, 1230), Vector2(420, 1300)]), 5.0, 4.0, 15)},
			{"kind": &"path", "width": 1.4, "points": WoodsFeatures.meander(PackedVector2Array([
				Vector2(-90, 1300), Vector2(-300, 1260), Vector2(-470, 1240)]), 5.0, 3.0, 16)},
		], 40.0)
		_detail = WoodsTerrain.make_noise(2101, 0.006, 4)
		_biome_a = WoodsTerrain.make_noise(2102, 0.0045, 3)
		_biome_b = WoodsTerrain.make_noise(2103, 0.009, 2)
	return _features


static func height_at(x: float, z: float) -> float:
	var f := features()
	var base := MacroHeight.height_at(x, z)
	# Keep the river bed and its banks as MacroHeight carved them.
	var river := river_distance(x, z)
	var keep := smoothstep(MacroHeight.RIVER_HALF_WIDTH, MacroHeight.RIVER_HALF_WIDTH + MacroHeight.RIVER_BANK, river)
	var h := _detail.get_noise_2d(x, z) * 7.0 + _detail.get_noise_2d(x * 3.1, z * 3.1) * 1.2
	h -= WoodsTerrain.hollow(x, z, Vector2(CROCUS_KNOLL.x, CROCUS_KNOLL.y), CROCUS_KNOLL.z * 1.4, 6.0)
	# The falls' bluff: a flat-topped rock shelf with a steep south face.
	var bluff := Vector2(x, z).distance_to(Vector2(FALLS_BLUFF.x, FALLS_BLUFF.y)) / FALLS_BLUFF.z
	h += 13.0 * (1.0 - smoothstep(0.75, 1.0, bluff))
	h += WoodsTerrain.hollow(x, z, Vector2(FAELIGHT_HOLLOW.x, FAELIGHT_HOLLOW.y), FAELIGHT_HOLLOW.z * 1.3, 6.0)
	h += WoodsTerrain.hollow(x, z, Vector2(BLUEBELL_DELL.x, BLUEBELL_DELL.y), BLUEBELL_DELL.z * 1.2, 3.5)
	# A low rise for the great oak and the moonstone ring.
	h -= WoodsTerrain.hollow(x, z, Vector2(GREAT_OAK.x, GREAT_OAK.y), 90.0, 4.0)
	h -= WoodsTerrain.hollow(x, z, Vector2(MOONSTONE_RING.x, MOONSTONE_RING.y), 70.0, 5.0)
	# Roads and paths ease the local bumps so they read as worn ground.
	var road := WoodsTerrain.path_weight(f.distance(&"road", x, z), 4.0)
	var path := WoodsTerrain.path_weight(f.distance(&"path", x, z), 2.0) * 0.6
	h *= 1.0 - maxf(road * 0.6, path * 0.35)
	return base + h * keep


## Signed distance to the Thornwater's water edge (negative in the water).
static func river_distance(x: float, z: float) -> float:
	return MacroHeight.distance_to_river(x, z) - MacroHeight.RIVER_HALF_WIDTH


## Ground paint for Terrain3D: (base slot, overlay slot, blend).
static func texture_at(x: float, z: float) -> Vector3i:
	var f := features()
	if river_distance(x, z) < 0.0:
		return Vector3i(WorldHeight.Tex.RIVERBED, WorldHeight.Tex.RIVERBED, 0)
	var road := f.distance(&"road", x, z)
	if road < 1.0 or f.distance(&"path", x, z) < 0.0:
		return Vector3i(WorldHeight.Tex.PATH, WorldHeight.Tex.FOREST_FLOOR, 60)
	match biome_at(x, z):
		&"ancient_oak_wood", &"faelight_hollow":
			return Vector3i(WorldHeight.Tex.MOSS, WorldHeight.Tex.FOREST_FLOOR, 90)
		&"spring_woodland":
			return Vector3i(WorldHeight.Tex.FOREST_FLOOR, WorldHeight.Tex.SPRING_GRASS, 110)
		&"brook":
			return Vector3i(WorldHeight.Tex.MOSS, WorldHeight.Tex.RIVERBED, 70)
	return Vector3i(WorldHeight.Tex.SPRING_GRASS, WorldHeight.Tex.MOSS, 40)


## Which biome is at (x, z). Ids match the WoodsBiome resources in
## data/regions/spring_court/border_woods.tres.
static func biome_at(x: float, z: float) -> StringName:
	var f := features()
	var p := Vector2(x, z)
	if river_distance(x, z) < 12.0:
		return &"brook"
	if z > 1315.0:
		return &"wall_verge"
	if p.distance_to(Vector2(CROCUS_KNOLL.x, CROCUS_KNOLL.y)) < CROCUS_KNOLL.z:
		return &"crocus_knoll"
	if p.distance_to(Vector2(FAELIGHT_HOLLOW.x, FAELIGHT_HOLLOW.y)) < FAELIGHT_HOLLOW.z:
		return &"faelight_hollow"
	if p.distance_to(Vector2(MOONSTONE_RING.x, MOONSTONE_RING.y)) < MOONSTONE_RING.z * 2.0:
		return &"foxglove_clearing"
	if p.distance_to(Vector2(BLUEBELL_DELL.x, BLUEBELL_DELL.y)) < BLUEBELL_DELL.z:
		return &"bluebell_glade"
	var a := _biome_a.get_noise_2d(x, z)
	var b := _biome_b.get_noise_2d(x, z)
	if z < 470.0 + b * 60.0:
		return &"rose_brake"
	if a > 0.18:
		return &"ancient_oak_wood"
	if a < -0.25:
		return &"bluebell_glade"
	if b > 0.32:
		return &"foxglove_clearing"
	if b < -0.38:
		return &"rose_brake"
	return &"spring_woodland"


## 0 on roads, paths and water; 1 on open ground. Trees need > 0.9.
static func clearance(x: float, z: float) -> float:
	var f := features()
	var d := minf(f.distance(&"road", x, z) - 1.0, minf(f.distance(&"path", x, z), river_distance(x, z)))
	if Vector2(x, z).distance_to(BOGGE_HUNT) < 14.0:
		d = 0.0
	return clampf(d / 3.0, 0.0, 1.0)


## True where the ground is under water (brook bed).
static func is_water(x: float, z: float) -> bool:
	return river_distance(x, z) < 0.0
