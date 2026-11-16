class_name CourtGreatTrees
extends RefCounted
## The court's great trees (docs/lanes/court-planting-by-place.md, "Assets we do
## not have"): the trees the places need and the game lacked, each designed
## from what the book says of it. They are grown by the estate's tree-builder
## (tools/blender/estate_tree.py, COURT) and drawn with the estate trees'
## shaders, so they stand beside the manor's trees as family; the models are
## the court's own (assets/trees/great/tree_<species>_<a..>.glb).
##
## A model is one mesh with a surface per part (tree_bark, tree_leaves,
## tree_core), as EstateTrees' are.

const DIR := "res://world/spring_court/wider/assets/trees/great/"
const LETTERS := "abcdefgh"
## species -> height (m, the builder's COURT table), leaf bands [shadow, mid,
## light], the leaf-clump picture, the bark picture with its tint and painted
## mean, and the trunk's radius at chest height (m) for colliders.
const TREES := {
	# book ch 14: a ring of white birches "tall and straight as pillars"
	&"pillar_birch": {"height": 18.0,
		"bands": [Color(0.36, 0.62, 0.42), Color(0.60, 0.84, 0.52), Color(0.86, 0.97, 0.66)],
		"puff": "res://world/spring_court/manor_estate/flora/trees/puff_birch.png",
		"bark": "res://world/spring_court/wider/assets/trees/ez/bark_birch.png",
		"bark_col": Color(0.93, 0.91, 0.88), "bark_mean": 0.582, "trunk": 0.225},
	# The knolls' trees (the glen: one to a knoll, and you find your way by them).
	# the great oak: grown alone on a hilltop, wider than tall
	&"great_oak": {"height": 24.0,
		"bands": [Color(0.30, 0.56, 0.44), Color(0.50, 0.79, 0.56), Color(0.78, 0.95, 0.72)],
		"puff": "res://world/spring_court/manor_estate/flora/trees/puff_oak.png",
		"bark": "res://world/spring_court/wider/assets/trees/ez/bark_oak.png",
		"bark_col": Color(0.56, 0.42, 0.43), "bark_mean": 0.338, "trunk": 1.2},
	# book ch 6: a lone sycamore on a knoll. A grey bole, a tall full dome, a yellower green
	&"great_sycamore": {"height": 26.0,
		"bands": [Color(0.34, 0.58, 0.36), Color(0.57, 0.81, 0.46), Color(0.85, 0.96, 0.60)],
		"puff": "res://world/spring_court/manor_estate/flora/trees/puff_oak.png",
		"bark": "res://world/spring_court/wider/assets/trees/ez/bark_birch.png",
		"bark_col": Color(0.74, 0.71, 0.74), "bark_mean": 0.582, "trunk": 1.04},
	# the old thorn, white with may, and the thorn bush that stands between the grass and the crowns
	&"old_thorn": {"height": 7.5, "blossom": true,
		"bands": [Color(0.86, 0.80, 0.80), Color(0.98, 0.95, 0.94), Color(1.0, 0.99, 0.98)],
		"puff": "res://world/spring_court/manor_estate/flora/trees/puff_crab_apple.png",
		"bark": "res://world/spring_court/wider/assets/trees/ez/bark_oak.png",
		"bark_col": Color(0.50, 0.40, 0.42), "bark_mean": 0.338, "trunk": 0.41},
	&"thorn_bush": {"height": 3.4, "blossom": true,
		"bands": [Color(0.86, 0.80, 0.80), Color(0.98, 0.95, 0.94), Color(1.0, 0.99, 0.98)],
		"puff": "res://world/spring_court/manor_estate/flora/trees/puff_crab_apple.png",
		"bark": "res://world/spring_court/wider/assets/trees/ez/bark_oak.png",
		"bark_col": Color(0.50, 0.40, 0.42), "bark_mean": 0.338, "trunk": 0.17},
}

static var _meshes: Dictionary = {}
static var _materials: Dictionary = {}
static var _builds: Dictionary = {}


static func has(species: StringName) -> bool:
	return TREES.has(species) and builds(species) > 0


## How many builds the species has (tree_<species>_a.glb, _b, ...).
static func builds(species: StringName) -> int:
	if not _builds.has(species):
		var n := 0
		while n < LETTERS.length() and ResourceLoader.exists(path(species, n)):
			n += 1
		_builds[species] = n
	return _builds[species]


static func path(species: StringName, build: int) -> String:
	return "%stree_%s_%s.glb" % [DIR, species, LETTERS[build]]


static func height_of(species: StringName) -> float:
	return float(TREES[species]["height"])


## The species' build (wrapped into range), standing on y = 0 at its height.
static func mesh(species: StringName, build: int = 0) -> Mesh:
	var n := builds(species)
	if n == 0:
		return null
	var key := path(species, posmod(build, n))
	if _meshes.has(key):
		return _meshes[key]
	var scene := (load(key) as PackedScene).instantiate()
	var found: Mesh = null
	for mi: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		found = mi.mesh
		break
	scene.free()
	if found != null:
		for i in found.get_surface_count():
			var src := found.surface_get_material(i)
			var part := StringName(String(src.resource_name).trim_prefix("tree_")) if src != null else &"core"
			found.surface_set_material(i, material(species, part))
	_meshes[key] = found
	return found


## One material per species and part, shared by the species' builds: the
## estate trees' shaders (cut-out for the leaf clumps, solid for the rest).
static func material(species: StringName, part: StringName) -> ShaderMaterial:
	var key := "%s/%s" % [species, part]
	if _materials.has(key):
		return _materials[key]
	var t: Dictionary = TREES[species]
	var number: int = EstateTrees.PARTS.get(part, 2)
	var m := ShaderMaterial.new()
	m.shader = load(EstateTrees.SHADER if number == 1 else EstateTrees.SHADER_SOLID) as Shader
	m.set_shader_parameter(&"part", number)
	m.set_shader_parameter(&"tex", load(String(t["bark"]) if part == &"bark" else String(t["puff"])))
	# a blossom tree's clumps are painted in their own colours (as the estate's are)
	m.set_shader_parameter(&"own_colour", bool(t.get("blossom", false)) and part == &"leaves")
	m.set_shader_parameter(&"hanging", false)
	m.set_shader_parameter(&"bark_col", t["bark_col"])
	m.set_shader_parameter(&"bark_mean", t["bark_mean"])
	var bands: Array = t["bands"]
	m.set_shader_parameter(&"shadow_col", bands[0])
	m.set_shader_parameter(&"mid_col", bands[1])
	m.set_shader_parameter(&"light_col", bands[2])
	m.set_shader_parameter(&"model_height", float(t["height"]))
	_materials[key] = m
	return m
