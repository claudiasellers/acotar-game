## Height provider and biome map for the Eastern Woods: deep woods east of the
## manor where the Suriel, the naga and the Bogge are (book scenes).
##
## World contract provider (docs/contracts/world.md §2): static height_at and
## texture_at in world metres; the HeightProvider fades it back to
## MacroHeight over the outer 64 m.
##
## Book note (Keeper): the Bogge is met here on a hunt with Lucien (ch. 10,
## flag bogge_survived) and begs inside her head to be looked at.
##
## dread_at() is the deliberate tip from storybook-pretty into horror: 0 in
## the pretty woods, 1 inside Bogge territory and the naga reeds, with a
## readable ~140 m transition band (trees thin and grey, colour drains, birds
## stop). Scenes drive fog, sound and foliage blight from it.
class_name EasternWoodsTerrain
extends RefCounted

const BOUNDS := Rect2(650.0, -650.0, 1200.0, 1200.0)

const STREAM_GLEN := Vector3(1060.0, -190.0, 55.0)
const BOGGE_HEART := Vector3(1560.0, -430.0, 210.0)
const REED_MARSH := Vector3(1180.0, 330.0, 150.0)
const PUCA_EDGE_X := 760.0
const BLIGHT_X := 1690.0
const DREAD_BAND := 140.0

static var _features: WoodsFeatures
static var _detail: FastNoiseLite
static var _biome_a: FastNoiseLite
static var _biome_b: FastNoiseLite


static func features() -> WoodsFeatures:
	if _features == null:
		_features = WoodsFeatures.new([
			# The stream: comes down from the north-east hills, runs past the
			# Suriel glen, spreads into shallows and sinks into the reed marsh.
			{"kind": &"stream", "width": 7.0, "depth": 1.8, "points": WoodsFeatures.meander(PackedVector2Array([
				Vector2(1330, -650), Vector2(1250, -520), Vector2(1150, -400), Vector2(1090, -260), Vector2(1110, -150),
				Vector2(1040, -20), Vector2(1000, 120), Vector2(1080, 230), Vector2(1180, 330)]), 5.0, 7.0, 31)},
			# A side rill out of Bogge territory: black water.
			{"kind": &"stream", "width": 3.0, "depth": 1.0, "points": WoodsFeatures.meander(PackedVector2Array([
				Vector2(1600, -330), Vector2(1450, -300), Vector2(1300, -330), Vector2(1170, -380)]), 5.0, 5.0, 32)},
			# Hunters' and sentries' tracks.
			{"kind": &"path", "width": 2.0, "points": WoodsFeatures.meander(PackedVector2Array([
				Vector2(650, 100), Vector2(760, 60), Vector2(880, -40), Vector2(990, -150), Vector2(1060, -190)]), 6.0, 4.0, 33)},
			{"kind": &"path", "width": 1.6, "points": WoodsFeatures.meander(PackedVector2Array([
				Vector2(880, -40), Vector2(900, -260), Vector2(960, -450), Vector2(1100, -600)]), 6.0, 4.0, 34)},
			{"kind": &"path", "width": 1.6, "points": WoodsFeatures.meander(PackedVector2Array([
				Vector2(760, 60), Vector2(850, 250), Vector2(1000, 330), Vector2(1080, 420), Vector2(1250, 480)]), 6.0, 4.0, 35)},
			# A path that leads where no one should go.
			{"kind": &"path", "width": 1.4, "points": WoodsFeatures.meander(PackedVector2Array([
				Vector2(1110, -150), Vector2(1260, -200), Vector2(1400, -330), Vector2(1560, -430)]), 6.0, 5.0, 36)},
		], 40.0)
		_detail = WoodsTerrain.make_noise(3101, 0.005, 4)
		_biome_a = WoodsTerrain.make_noise(3102, 0.004, 3)
		_biome_b = WoodsTerrain.make_noise(3103, 0.008, 2)
	return _features


static func height_at(x: float, z: float) -> float:
	var f := features()
	var base := MacroHeight.height_at(x, z)
	var h := _detail.get_noise_2d(x, z) * 9.0 + _detail.get_noise_2d(x * 2.7, z * 2.7) * 1.5
	# The glen is a grassy bowl by the water.
	h += WoodsTerrain.hollow(x, z, Vector2(STREAM_GLEN.x, STREAM_GLEN.y), STREAM_GLEN.z * 1.6, 3.0)
	# The marsh sits low so water spreads through the reeds.
	h += WoodsTerrain.hollow(x, z, Vector2(REED_MARSH.x, REED_MARSH.y), REED_MARSH.z * 1.3, 7.0)
	# Bogge territory: broken, gullied ground.
	var bogge := 1.0 - smoothstep(BOGGE_HEART.z * 0.6, BOGGE_HEART.z * 1.3, Vector2(x, z).distance_to(Vector2(BOGGE_HEART.x, BOGGE_HEART.y)))
	h += absf(_detail.get_noise_2d(x * 4.0, z * 4.0)) * -4.0 * bogge
	var stream := f.query(&"stream", x, z)
	h += WoodsTerrain.channel(stream.x, stream.y, 7.0)
	var path := WoodsTerrain.path_weight(f.distance(&"path", x, z), 2.0)
	h *= 1.0 - path * 0.3
	return base + h


static func texture_at(x: float, z: float) -> Vector3i:
	var f := features()
	if f.distance(&"stream", x, z) < 0.0:
		return Vector3i(WorldHeight.Tex.RIVERBED, WorldHeight.Tex.RIVERBED, 0)
	if f.distance(&"path", x, z) < 0.0:
		return Vector3i(WorldHeight.Tex.PATH, WorldHeight.Tex.FOREST_FLOOR, 60)
	match biome_at(x, z):
		&"bogge_territory", &"dread_margin":
			return Vector3i(WorldHeight.Tex.FOREST_FLOOR, WorldHeight.Tex.BLIGHT, 150)
		&"blight_edge":
			return Vector3i(WorldHeight.Tex.BLIGHT, WorldHeight.Tex.SPRING_GRASS, 80)
		&"reed_marsh":
			return Vector3i(WorldHeight.Tex.RIVERBED, WorldHeight.Tex.MOSS, 120)
		&"deep_wood", &"beech_hall", &"fern_hollow":
			return Vector3i(WorldHeight.Tex.FOREST_FLOOR, WorldHeight.Tex.MOSS, 100)
		&"stream_shallows":
			return Vector3i(WorldHeight.Tex.MOSS, WorldHeight.Tex.RIVERBED, 70)
	return Vector3i(WorldHeight.Tex.SPRING_GRASS, WorldHeight.Tex.MOSS, 40)


static func dread_at(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var bogge := 1.0 - smoothstep(BOGGE_HEART.z, BOGGE_HEART.z + DREAD_BAND, p.distance_to(Vector2(BOGGE_HEART.x, BOGGE_HEART.y)))
	var reeds := 1.0 - smoothstep(REED_MARSH.z * 0.7, REED_MARSH.z * 0.7 + DREAD_BAND * 0.7, p.distance_to(Vector2(REED_MARSH.x, REED_MARSH.y)))
	return maxf(bogge, reeds * 0.85)


## The blight's grip, 0..1, strongest along the eastern border.
static func blight_at(x: float, z: float) -> float:
	features()
	return smoothstep(BLIGHT_X - 120.0, BLIGHT_X + 60.0, x + _biome_b.get_noise_2d(x, z) * 50.0)


static func biome_at(x: float, z: float) -> StringName:
	var f := features()
	var p := Vector2(x, z)
	var stream := f.distance(&"stream", x, z)
	var to_bogge := p.distance_to(Vector2(BOGGE_HEART.x, BOGGE_HEART.y))
	var to_marsh := p.distance_to(Vector2(REED_MARSH.x, REED_MARSH.y))
	if to_marsh < REED_MARSH.z:
		return &"reed_marsh"
	if to_bogge < BOGGE_HEART.z:
		return &"bogge_territory"
	if to_bogge < BOGGE_HEART.z + DREAD_BAND:
		return &"dread_margin"
	if p.distance_to(Vector2(STREAM_GLEN.x, STREAM_GLEN.y)) < STREAM_GLEN.z:
		return &"stream_glen"
	if stream < 9.0:
		return &"stream_shallows"
	if blight_at(x, z) > 0.5:
		return &"blight_edge"
	if x < PUCA_EDGE_X + _biome_b.get_noise_2d(x, z) * 40.0:
		return &"woods_edge"
	var a := _biome_a.get_noise_2d(x, z)
	if a > 0.22:
		return &"beech_hall"
	if a < -0.3:
		return &"fern_hollow"
	return &"deep_wood"


static func clearance(x: float, z: float) -> float:
	var f := features()
	var d := minf(f.distance(&"path", x, z), f.distance(&"stream", x, z))
	return clampf(d / 3.0, 0.0, 1.0)


static func is_water(x: float, z: float) -> bool:
	if features().distance(&"stream", x, z) < 0.0:
		return true
	return Vector2(x, z).distance_to(Vector2(REED_MARSH.x, REED_MARSH.y)) < REED_MARSH.z * 0.55
