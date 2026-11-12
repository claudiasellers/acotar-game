class_name EstateTrees
extends RefCounted
## The estate's trees (wider-court D2/E2). Models from the estate tree-builder
## (tools/blender/estate_tree.py): a skinned trunk and limbs shaped on purpose,
## every limb ending in a cloud of leaf-clump cards (cotton-candy shapes made of
## leaves); the willow is fronds draped from arching limbs. Each species comes
## in several builds (trees/tree_<species>_<a..>.glb, the same recipe from
## another seed) so neighbours differ: ManorScatter hands them out.
##
## A model is one mesh with a surface per part (tree_bark, tree_leaves,
## tree_core, tree_fruit, tree_fronds); each goes on its own material of
## trees/estate_tree.gdshader (leaves, fronds) or estate_tree_solid.gdshader
## (the rest), shared by the species' builds. FloraLib.mesh()
## and FloraLib.builds() route the tree species here.

const DIR := "res://world/spring_court/manor_estate/flora/trees/"
## The leaf-clump cards and the fronds are cut out; wood, hearts and fruit are
## solid, on a shader of their own (a shader that cuts out anywhere is drawn as
## a cut-out everywhere, which cost about 3 ms a frame in the orchard).
const SHADER := DIR + "estate_tree.gdshader"
const SHADER_SOLID := DIR + "estate_tree_solid.gdshader"
## The painted barks are the court's (tools/court/gen_ez_textures.py).
const BARK_DIR := "res://world/spring_court/wider/assets/trees/ez/"
const LETTERS := "abcdefgh"
## The shader's part number per surface (fronds are leaves on the frond picture).
const PARTS := {&"bark": 0, &"leaves": 1, &"core": 2, &"fruit": 3, &"fronds": 1}
const BARK_ROSE := Color(0.56, 0.42, 0.43)
const BARK_WHITE := Color(0.93, 0.91, 0.88)
## Per species: the leaf bands [shadow, mid, light] (for a blossom tree the
## heart's deep and mid tones; its clumps are painted in their own colours),
## and whether it blossoms. docs/tuning.md "Estate tree colours".
const LOOKS := {
	&"oak": [Color(0.30, 0.56, 0.44), Color(0.50, 0.79, 0.56), Color(0.78, 0.95, 0.72), false],
	&"birch": [Color(0.36, 0.62, 0.42), Color(0.60, 0.84, 0.52), Color(0.86, 0.97, 0.66), false],
	&"pear_tree": [Color(0.34, 0.60, 0.40), Color(0.56, 0.80, 0.50), Color(0.82, 0.94, 0.64), false],
	&"willow": [Color(0.33, 0.60, 0.46), Color(0.52, 0.80, 0.52), Color(0.80, 0.95, 0.66), false],
	&"cherry_blossom": [Color(0.80, 0.42, 0.60), Color(0.96, 0.66, 0.80), Color(1.0, 0.9, 0.95), true],
	&"apple_blossom": [Color(0.88, 0.72, 0.76), Color(0.98, 0.9, 0.91), Color(1.0, 0.98, 0.97), true],
	&"crab_apple": [Color(0.9, 0.78, 0.8), Color(0.99, 0.94, 0.94), Color(1.0, 0.99, 0.98), true],
}

## The trunk at chest height, metres (the builder's trunk x the species
## height): the scatter's trunk colliders.
const TRUNK_RADIUS := {&"oak": 0.74, &"willow": 0.5, &"pear_tree": 0.28, &"birch": 0.27, &"cherry_blossom": 0.27,
	&"apple_blossom": 0.25, &"crab_apple": 0.22}

static var _meshes: Dictionary = {}
static var _materials: Dictionary = {}
static var _builds: Dictionary = {}


static func has(species: StringName) -> bool:
	return LOOKS.has(species) and builds(species) > 0


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


## The species' build (wrapped into range), standing on y = 0 at the species height.
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
		# In place: the imported mesh is ours alone, and editing it keeps the importer's LODs.
		for i in found.get_surface_count():
			var src := found.surface_get_material(i)
			var part := StringName(String(src.resource_name).trim_prefix("tree_")) if src != null else &"core"
			found.surface_set_material(i, material(species, part))
	_meshes[key] = found
	return found


## One material per species and part, shared by the species' builds.
static func material(species: StringName, part: StringName) -> ShaderMaterial:
	var key := "%s/%s" % [species, part]
	if _materials.has(key):
		return _materials[key]
	var look: Array = LOOKS[species]
	var m := ShaderMaterial.new()
	var number: int = PARTS.get(part, 2)
	m.shader = load(SHADER if number == 1 else SHADER_SOLID) as Shader
	m.set_shader_parameter(&"part", number)
	var tex := "%spuff_%s.png" % [DIR, species]
	if part == &"bark":
		tex = BARK_DIR + ("bark_birch.png" if species == &"birch" else "bark_oak.png")
	elif part == &"fronds":
		tex = DIR + "frond_willow.png"
	m.set_shader_parameter(&"tex", load(tex))
	m.set_shader_parameter(&"own_colour", bool(look[3]) and part == &"leaves")
	m.set_shader_parameter(&"hanging", part == &"fronds")
	m.set_shader_parameter(&"bark_col", BARK_WHITE if species == &"birch" else BARK_ROSE)
	# the pictures' mean painted values (gen_ez_textures.py BARK_TARGET)
	m.set_shader_parameter(&"bark_mean", 0.582 if species == &"birch" else 0.338)
	m.set_shader_parameter(&"shadow_col", look[0])
	m.set_shader_parameter(&"mid_col", look[1])
	m.set_shader_parameter(&"light_col", look[2])
	m.set_shader_parameter(&"model_height", FloraLib.height_of(species))
	_materials[key] = m
	return m
