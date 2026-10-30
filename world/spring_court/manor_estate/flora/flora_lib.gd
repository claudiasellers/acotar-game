## Plant meshes for the estate by species id (roses, hedges, trees, flowers).
## Owned by the props lane: replace the stand-in shapes with real stylized
## procedural (or Blender) meshes using world/shared/shaders/stylized_foliage.gdshader.
## Callers only use mesh(), height_of() and SPECIES, so the look can change freely.
class_name FloraLib
extends RefCounted

## species id -> [kind, height in metres, colour]. kind: tree, bush, flower, climber, groundcover, reed, aquatic.
const SPECIES := {
	&"rose_red": [&"bush", 1.2, Color(0.95, 0.22, 0.38)],
	&"rose_white": [&"bush", 1.2, Color(1.0, 0.96, 0.95)],
	&"rose_gold": [&"bush", 1.2, Color(1.0, 0.80, 0.30)],
	&"rose_pink": [&"bush", 1.1, Color(1.0, 0.60, 0.75)],
	&"rose_climbing": [&"climber", 3.0, Color(0.98, 0.45, 0.62)],
	&"hedge_box": [&"bush", 2.6, Color(0.30, 0.66, 0.36)],
	&"lavender": [&"flower", 0.6, Color(0.70, 0.55, 0.95)],
	&"foxglove": [&"flower", 1.3, Color(0.92, 0.50, 0.80)],
	&"wild_hyacinth": [&"flower", 0.35, Color(0.50, 0.55, 1.0)],
	&"honeysuckle": [&"climber", 2.2, Color(1.0, 0.90, 0.60)],
	&"elderflower": [&"bush", 2.8, Color(1.0, 0.98, 0.88)],
	&"wild_strawberry": [&"groundcover", 0.2, Color(0.95, 0.25, 0.30)],
	&"blackberry": [&"bush", 1.4, Color(0.35, 0.20, 0.45)],
	&"wisteria": [&"climber", 3.5, Color(0.78, 0.65, 1.0)],
	&"lilac": [&"bush", 2.6, Color(0.82, 0.68, 1.0)],
	&"faelight_dandelion": [&"flower", 0.3, Color(1.0, 0.98, 0.70)],
	&"starmoss": [&"groundcover", 0.08, Color(0.55, 0.90, 0.75)],
	&"willow": [&"tree", 11.0, Color(0.55, 0.82, 0.45)],
	&"oak": [&"tree", 16.0, Color(0.40, 0.70, 0.35)],
	&"cherry_blossom": [&"tree", 7.0, Color(1.0, 0.75, 0.86)],
	&"apple_blossom": [&"tree", 6.0, Color(1.0, 0.90, 0.92)],
	&"pear_tree": [&"tree", 7.0, Color(0.70, 0.88, 0.50)],
	&"birch": [&"tree", 13.0, Color(0.70, 0.90, 0.50)],
	&"reed": [&"reed", 1.8, Color(0.62, 0.80, 0.42)],
	&"water_lily": [&"aquatic", 0.1, Color(1.0, 0.75, 0.88)],
	&"tulip_bed": [&"flower", 0.45, Color(1.0, 0.45, 0.55)],
	&"peony": [&"flower", 0.8, Color(1.0, 0.65, 0.78)],
	&"forget_me_not": [&"flower", 0.25, Color(0.55, 0.70, 1.0)],
	&"daisy": [&"flower", 0.25, Color(1.0, 1.0, 0.95)],
	&"herb_patch": [&"flower", 0.5, Color(0.50, 0.80, 0.45)],
	&"vegetable_row": [&"flower", 0.5, Color(0.45, 0.78, 0.35)],
	&"fern": [&"groundcover", 0.8, Color(0.35, 0.70, 0.38)],
	&"mushroom_glowcap": [&"groundcover", 0.15, Color(0.70, 0.95, 1.0)],
}

static var _cache: Dictionary = {}


static func has(species: StringName) -> bool:
	return SPECIES.has(species)


static func height_of(species: StringName) -> float:
	return float(SPECIES.get(species, [&"bush", 1.0, Color.WHITE])[1])


static func mesh(species: StringName) -> Mesh:
	if _cache.has(species):
		return _cache[species]
	var e: Array = SPECIES.get(species, [&"bush", 1.0, Color(1.0, 0.7, 0.8)])
	var h: float = e[1]
	var m: Mesh
	match e[0]:
		&"tree":
			var s := SphereMesh.new()
			s.radius = h * 0.32
			s.height = h * 0.55
			m = s
		&"reed", &"flower":
			var c := CylinderMesh.new()
			c.top_radius = h * 0.25
			c.bottom_radius = h * 0.12
			c.height = h
			m = c
		&"groundcover", &"aquatic":
			var c2 := CylinderMesh.new()
			c2.top_radius = maxf(h * 3.0, 0.3)
			c2.bottom_radius = maxf(h * 3.0, 0.3)
			c2.height = maxf(h, 0.05)
			m = c2
		_:
			var b := SphereMesh.new()
			b.radius = h * 0.5
			b.height = h
			m = b
	m.surface_set_material(0, EstateKit.mat(e[2], 0.6))
	_cache[species] = m
	return m
