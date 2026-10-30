## Plant meshes for the estate by species id (roses, hedges, trees, flowers).
## The Blender model for a species when one exists (tools/blender/manor_flora.py,
## vertex-coloured, base at the origin, species height tall), otherwise the
## stylized procedural mesh (flora_shapes.gd). Both draw with the shared foliage
## shader world/shared/shaders/stylized_foliage.gdshader.
## Callers use mesh(), impostor(), height_of() and SPECIES. Meshes stand on y = 0.
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
	# requested by the grounds lane
	&"crocus": [&"flower", 0.2, Color(0.78, 0.62, 1.0)],
	&"buttercup": [&"flower", 0.25, Color(1.0, 0.90, 0.40)],
	&"iris": [&"flower", 0.75, Color(0.62, 0.40, 0.88)],
	&"madder": [&"flower", 0.7, Color(0.45, 0.70, 0.38)],
	&"crab_apple": [&"tree", 6.0, Color(1.0, 0.96, 0.95)],
	&"orchid": [&"flower", 0.5, Color(0.96, 0.66, 0.90)],
}

const FOLIAGE_SHADER := preload("res://world/shared/shaders/stylized_foliage.gdshader")
## Magical species glow softly and sparkle (R3); the rest get a gentle glint.
const GLOW := {&"faelight_dandelion": 1.2, &"mushroom_glowcap": 1.4, &"starmoss": 0.6}
const SPARKLE := {&"faelight_dandelion": 0.9, &"mushroom_glowcap": 0.7, &"starmoss": 0.8, &"rose_gold": 0.3, &"water_lily": 0.3}

## Distance past which scatter should swap trees to impostor().
const IMPOSTOR_DISTANCE := 120.0

static var _cache: Dictionary = {}
static var _impostors: Dictionary = {}


static func has(species: StringName) -> bool:
	return SPECIES.has(species)


static func kind_of(species: StringName) -> StringName:
	return SPECIES.get(species, [&"bush", 1.0, Color.WHITE])[0]


static func height_of(species: StringName) -> float:
	return float(SPECIES.get(species, [&"bush", 1.0, Color.WHITE])[1])


static func mesh(species: StringName) -> Mesh:
	if _cache.has(species):
		return _cache[species]
	var model := PropModels.pair(PropModels.FLORA_DIR + String(species) + ".glb", String(species), foliage_material(species))
	if not model.is_empty():
		_cache[species] = model[0]
		return model[0]
	var e: Array = SPECIES.get(species, [&"bush", 1.0, Color(1.0, 0.7, 0.8)])
	var h: float = e[1]
	var k := PropMeshKit.new()
	FloraShapes.build(k, species, e[0], h, e[2])
	var m := k.to_mesh(Vector3.ZERO, h)
	_cache[species] = m
	return m


## A crossed-card silhouette for trees seen from far away (null for non-trees).
static func impostor(species: StringName) -> Mesh:
	if kind_of(species) != &"tree":
		return null
	if _impostors.has(species):
		return _impostors[species]
	var e: Array = SPECIES[species]
	var h: float = e[1]
	var k := PropMeshKit.new()
	var trunk := FloraShapes.BARK_PALE if species == &"birch" else FloraShapes.BARK
	FloraShapes.impostor(k, h, e[2], trunk, species == &"willow")
	var m := k.to_mesh(Vector3.ZERO, h)
	_impostors[species] = m
	return m


## True when the species draws its Blender model rather than the procedural mesh.
static func is_model(species: StringName) -> bool:
	return ResourceLoader.exists(PropModels.FLORA_DIR + String(species) + ".glb")


## One stylized_foliage material per modelled species (colour from vertex colours,
## sway from height).
static func foliage_material(species: StringName) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = FOLIAGE_SHADER
	m.set_shader_parameter(&"use_vertex_color", true)
	m.set_shader_parameter(&"alpha_scissor", 0.0)
	m.set_shader_parameter(&"flex_height", height_of(species))
	m.set_shader_parameter(&"emission_glow", GLOW.get(species, 0.0))
	m.set_shader_parameter(&"sparkle", SPARKLE.get(species, 0.1))
	var kind := kind_of(species)
	m.set_shader_parameter(&"translucency", 0.45 if kind in [&"flower", &"climber", &"reed"] else 0.3)
	m.resource_name = "flora_" + String(species)
	return m
